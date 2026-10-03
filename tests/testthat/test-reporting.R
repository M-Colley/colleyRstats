test_that("reportNPAV emits deprecation warning and reports results", {
  model <- data.frame(
    Df = c(1, 1, 10),
    `F value` = c(6.12, 5.01, NA),
    `Pr(>F)` = c(0.033, 0.045, NA),
    check.names = FALSE
  )
  rownames(model) <- c("Video", "gesture:eHMI", "Residuals")

  expect_warning(
    reportNPAV(model, dv = "mental workload"),
    "deprecated"
  )
})

test_that("reportART reports significant effects", {
  model <- data.frame(
    Effect = c("Video", "gesture:eHMI"),
    Df = c(1, 1),
    `F value` = c(6.12, 5.01),
    `Pr(>F)` = c(0.033, 0.045),
    Df.res = c(10, 10),
    check.names = FALSE
  )

  expect_message(
    reportART(model, dv = "mental demand"),
    "ART found a significant"
  )
})

test_that("reportART reports no significant effects when appropriate", {
  model <- data.frame(
    Effect = "Video",
    Df = 1,
    `F value` = 0.2,
    `Pr(>F)` = 0.8,
    Df.res = 10,
    check.names = FALSE
  )

  expect_message(
    reportART(model, dv = "mental demand"),
    "no significant effects on mental demand"
  )
})

test_that("reportART distinguishes main and interaction effects", {
  model <- data.frame(
    Effect = c("Video", "gesture:eHMI"),
    Df = c(1, 1),
    `F value` = c(6.12, 5.01),
    `Pr(>F)` = c(0.033, 0.045),
    Df.res = c(10, 10),
    check.names = FALSE
  )

  expect_message(
    reportART(model[1, , drop = FALSE], dv = "mental demand"),
    "main effect of .*Video\\{\\} on mental demand"
  )
  expect_message(
    reportART(model[2, , drop = FALSE], dv = "mental demand"),
    "interaction effect of .*gesture"
  )
})

test_that("reportNparLD reports significant effects", {
  # The table nparLD returns carries Statistic, df and p-value only. This
  # fixture used to add an RTE column that no real fit has, exercising a branch
  # that emitted ", $RTE=0.60" with no closing "$" (pdflatex: "Missing $").
  model <- list(
    ANOVA.test = data.frame(
      Statistic = c(4.2, NA),
      df = c(1, 10),
      `p-value` = c(0.02, NA),
      check.names = FALSE
    )
  )
  rownames(model$ANOVA.test) <- c("Time", "Residuals")

  expect_message(
    result <- reportNparLD(model, dv = "TLX1"),
    "nparLD analysis found a significant"
  )
  expect_false(grepl("RTE", result, fixed = TRUE))
})

test_that("reportNparLD reads the ANOVA-type statistic from an nparLD 2.3.0 fit", {
  # nparLD 2.3.0 moved the table from `$ANOVA.test` to `$ATS`. Reading only the
  # old name turned every fit from that version into "no significant effects",
  # however large the statistic was.
  ats <- matrix(
    c(92.78, 1.69, 1e-08),
    nrow = 1,
    dimnames = list("Time", c("Statistic", "df", "p-value"))
  )
  model <- structure(list(ATS = ats, WTS = ats), class = "nparld_fit")

  expect_message(
    reportNparLD(model, dv = "TLX1"),
    "nparLD analysis found a significant main effect of .*Time\\{\\} on TLX1"
  )
})

test_that("reportNparLD rejects an object carrying no nparLD result table", {
  expect_error(
    reportNparLD(list(something = 1), dv = "TLX1"),
    "does not look like an nparLD model"
  )
})

test_that("reportNparLD reports a real nparLD fit", {
  skip_if_not_installed("nparLD")

  set.seed(123)
  d <- data.frame(
    Subject = factor(rep(1:10, each = 3)),
    Time    = factor(rep(c("T1", "T2", "T3"), times = 10)),
    TLX1    = rep(c(45, 52, 61), times = 10) + stats::rnorm(30, sd = 4)
  )

  # `nparLD()` describes the design on stdout in versions before 2.3.0.
  utils::capture.output(
    model <- nparLD::nparLD(TLX1 ~ Time, data = d, subject = "Subject")
  )

  expect_message(
    suppressWarnings(reportNparLD(model, dv = "TLX1")),
    "nparLD analysis found a significant main effect of .*Time\\{\\} on TLX1"
  )
})

test_that("reportART invisibly returns one sentence per significant effect", {
  model <- data.frame(
    Effect = c("Video", "gesture:eHMI"),
    Df = c(1, 1),
    `F value` = c(6.12, 5.01),
    `Pr(>F)` = c(0.033, 0.045),
    Df.res = c(10, 10),
    check.names = FALSE
  )

  # Both effects must survive (the clipboard used to keep only the last one)
  result <- suppressMessages(reportART(model, dv = "mental demand"))
  expect_length(result, 2)
  expect_match(result[1], "Video")
  expect_match(result[2], "gesture")
})

test_that("reportART reads the F statistic from a mixed-model anova table", {
  # anova() on an ARTool model names this column "F value" for a between-only
  # (lm) fit but plain "F" for a mixed (lmer) one. Reading only `F value` left
  # the statistic and the effect size out of every mixed-model sentence.
  model <- data.frame(
    Term = "condition",
    F = 7.5460634,
    Df = 3,
    Df.res = 108,
    `Pr(>F)` = 0.0001247,
    check.names = FALSE
  )

  result <- suppressMessages(reportART(model, dv = "TiA"))
  expect_match(result, "\\\\F\\{3\\}\\{108\\}\\{7\\.55\\}") # F value present
  expect_match(result, "eta_\\{p\\}\\^\\{2\\}") # effect size derived from it
})

test_that("reportART always closes the statistics parenthesis", {
  # The ")" used to be appended only when an effect size could be computed, so
  # sentences without one shipped unbalanced parentheses into LaTeX.
  model <- data.frame(
    Term = "condition",
    F = 7.55,
    Df = 3,
    Df.res = NA_real_, # blocks F_to_eta2 -> no effect size text
    `Pr(>F)` = 0.001,
    check.names = FALSE
  )

  result <- suppressMessages(reportART(model, dv = "TiA"))
  expect_equal(
    lengths(regmatches(result, gregexpr("(", result, fixed = TRUE))),
    lengths(regmatches(result, gregexpr(")", result, fixed = TRUE)))
  )
})

test_that("reportART rounds fractional degrees of freedom", {
  # Kenward-Roger dfs carry floating-point noise (180.000000000002)
  model <- data.frame(
    Term = "uncertainty",
    F = 6.5375,
    Df = 2,
    Df.res = 180.000000000002,
    `Pr(>F)` = 0.00182,
    check.names = FALSE
  )

  result <- suppressMessages(reportART(model, dv = "TiA"))
  expect_match(result, "\\\\F\\{2\\}\\{180\\}\\{6\\.54\\}")
})

test_that("reportggstatsplot recognizes the unpaired Wilcoxon rank sum test", {
  plt <- ggstatsplot::ggbetweenstats(mtcars, am, mpg, type = "np")

  # statsExpressions labels this "Wilcoxon rank sum test"; the W statistic
  # must be reported instead of falling through to the generic format
  expect_message(
    reportggstatsplot(plt, iv = "am", dv = "mpg"),
    "\\(W="
  )
})

test_that("latexify_report formats output as LaTeX", {
  input <- paste(
    "Model summary:",
    "- significant effect (R2=0.5)",
    "- non-significant effect",
    "Standardized parameters were obtained by fitting the model",
    "Rhat ~ 1",
    sep = "\n"
  )

  out <- latexify_report(
    input,
    print_result = FALSE,
    only_sig = TRUE,
    remove_std = TRUE,
    itemize = TRUE
  )

  expect_true(grepl("\\\\begin\\{itemize\\}", out))
  expect_true(grepl("\\$R\\^2\\$", out))
  expect_false(grepl("non-significant", out))
  expect_true(grepl("\\$\\\\hat\\{R\\}\\$", out))
})

test_that("reportMeanAndSD emits typeset text, not LaTeX comments", {
  # Every line used to start with "%", so a manuscript that \input{} the file
  # typeset nothing; level names were not escaped and newlines were doubled.
  example_data <- data.frame(
    Condition = rep(c("A", "tlx_B"), each = 5),
    TLX1 = c(1:5, 6:10)
  )

  expect_message(
    result <- reportMeanAndSD(example_data, iv = "Condition", dv = "TLX1"),
    "^A: \\\\m\\{3\\.00\\}, \\\\sd\\{1\\.58\\}"
  )
  expect_equal(result, c(
    "A: \\m{3.00}, \\sd{1.58}",
    "tlx\\_B: \\m{8.00}, \\sd{1.58}"
  ))
  expect_false(any(startsWith(result, "%")))
  expect_false(any(grepl("\n", result, fixed = TRUE)))

  path <- withr::local_tempfile(fileext = ".tex")
  suppressMessages(reportMeanAndSD(example_data, iv = "Condition", dv = "TLX1", sink_to = path))
  expect_equal(
    readLines(path),
    c("A: \\m{3.00}, \\sd{1.58};", "tlx\\_B: \\m{8.00}, \\sd{1.58}.")
  )

  # the old comment form stays available on request
  comment <- suppressMessages(
    reportMeanAndSD(example_data, iv = "Condition", dv = "TLX1", as_comment = TRUE)
  )
  expect_true(all(startsWith(comment, "%")))
})

test_that("reportggstatsplot reports results", {
  plt <- ggstatsplot::ggbetweenstats(mtcars, am, mpg)
  expect_message(
    reportggstatsplot(plt, iv = "am", dv = "mpg"),
    "found"
  )
})

test_that("reportggstatsplotPostHoc reports significant differences", {
  # A 3-level factor (cyl) is required: with only two groups ggstatsplot emits
  # no pairwise comparisons (see the note on the NA test below), so `am` would
  # yield "No pairwise comparison data found" instead of a post-hoc sentence.
  plt <- ggstatsplot::ggbetweenstats(mtcars, cyl, mpg)
  expect_message(
    reportggstatsplotPostHoc(data = mtcars, p = plt, iv = "cyl", dv = "mpg"),
    "post-hoc test"
  )
})

test_that("reportggstatsplotPostHoc names the post-hoc test from the `test` column", {
  # Drive the function with a controlled pairwise table so the reported test
  # name is independent of ggstatsplot's version-specific defaults.
  pwc <- data.frame(
    group1 = "A", group2 = "B",
    p.value = 0.01, test = "Games-Howell",
    stringsAsFactors = FALSE
  )
  fake_plot <- structure(list(dummy = TRUE), pairwise_comparisons_data = pwc)
  df <- data.frame(grp = c("A", "A", "B", "B"), val = c(5, 6, 1, 2))

  expect_message(
    reportggstatsplotPostHoc(df, fake_plot, iv = "grp", dv = "val"),
    "Games-Howell post-hoc test"
  )
})

# A pairwise table as `ggstatsplot` attaches it: `test` names the post-hoc
# test, `p.adjust.method` the multiplicity correction.
fake_pwc_plot <- function(test = NULL, p.adjust.method = NULL, p.value = 0.01) {
  pwc <- data.frame(
    group1 = "A", group2 = "B", p.value = p.value,
    stringsAsFactors = FALSE
  )
  if (!is.null(test)) pwc$test <- test
  if (!is.null(p.adjust.method)) pwc$p.adjust.method <- p.adjust.method
  structure(list(dummy = TRUE), pairwise_comparisons_data = pwc)
}

test_that("reportggstatsplotPostHoc names the multiplicity correction", {
  df <- data.frame(grp = c("A", "A", "B", "B"), val = c(5, 6, 1, 2))

  expect_message(
    reportggstatsplotPostHoc(
      df, fake_pwc_plot("Games-Howell", "Holm"),
      iv = "grp", dv = "val"
    ),
    "Games-Howell post-hoc test \\(Holm-adjusted\\)"
  )
  expect_message(
    reportggstatsplotPostHoc(
      df, fake_pwc_plot("Dunn", "Bonferroni"),
      iv = "grp", dv = "val"
    ),
    "Dunn post-hoc test \\(Bonferroni-adjusted\\)"
  )
})

test_that("reportggstatsplotPostHoc does not label an uncorrected p as p_adj", {
  # `p.adjust.method = "None"` means the table carries raw p-values; calling
  # them p_adj in a manuscript claims a correction that was never applied.
  df <- data.frame(grp = c("A", "A", "B", "B"), val = c(5, 6, 1, 2))

  result <- suppressMessages(
    reportggstatsplotPostHoc(
      df, fake_pwc_plot("Games-Howell", "None"),
      iv = "grp", dv = "val"
    )
  )

  expect_match(result, "\\\\p\\{")
  expect_false(grepl("padj", result, fixed = TRUE))
  # nothing to name, so no correction parenthetical either
  expect_false(grepl("adjusted", result, fixed = TRUE))
})

test_that("reportggstatsplotPostHoc names the test when nothing is significant", {
  # This branch used to say "A post-hoc test found no significant differences"
  # regardless of which test had actually been run.
  df <- data.frame(grp = c("A", "A", "B", "B"), val = c(5, 6, 1, 2))

  expect_message(
    reportggstatsplotPostHoc(
      df, fake_pwc_plot("Dunn", "Holm", p.value = 0.9),
      iv = "grp", dv = "val"
    ),
    "Dunn post-hoc test \\(Holm-adjusted\\) found no significant differences"
  )
})

test_that("reportggstatsplotPostHoc stays generic without the naming columns", {
  # An older ggstatsplot, or a hand-built table: no claim can be made about
  # which test ran, and p_adj stays the default it has always been.
  df <- data.frame(grp = c("A", "A", "B", "B"), val = c(5, 6, 1, 2))

  result <- suppressMessages(
    reportggstatsplotPostHoc(df, fake_pwc_plot(), iv = "grp", dv = "val")
  )

  expect_match(result, "^A post-hoc test found that ")
  expect_match(result, "\\\\padj\\{")
})

# Note: with only two groups ggstatsplot emits no pairwise comparisons, so a
# 3-level factor (cyl) is needed to exercise the post-hoc reporting path.
test_that("reportggstatsplotPostHoc tolerates NA in the dependent variable", {
  data_with_na <- mtcars
  data_with_na$mpg[1] <- NA

  plt <- ggstatsplot::ggbetweenstats(data_with_na, cyl, mpg)

  # mean()/sd() without na.rm used to yield NA and crash the direction check
  expect_message(
    reportggstatsplotPostHoc(data = data_with_na, p = plt, iv = "cyl", dv = "mpg"),
    "significantly higher"
  )
})

test_that("reportggstatsplotPostHoc balances parentheses and keeps p inside them", {
  # The second mean/SD parenthetical used to close before the p-value and then
  # gain a second ")" afterwards, giving "...\\sd{1.62}); \\padj{0.001})." --
  # unbalanced, with the p-value sitting outside its own parentheses.
  pwc <- data.frame(
    group1 = "A", group2 = "B",
    p.value = 0.01, test = "Games-Howell",
    stringsAsFactors = FALSE
  )
  fake_plot <- structure(list(dummy = TRUE), pairwise_comparisons_data = pwc)
  df <- data.frame(grp = c("A", "A", "B", "B"), val = c(5, 6, 1, 2))

  result <- suppressMessages(
    reportggstatsplotPostHoc(df, fake_plot, iv = "grp", dv = "val")
  )

  expect_equal(
    lengths(regmatches(result, gregexpr("(", result, fixed = TRUE))),
    lengths(regmatches(result, gregexpr(")", result, fixed = TRUE)))
  )
  # p-value must be inside the trailing parenthetical, not after it
  expect_match(result, "\\\\sd\\{[^}]*\\}; \\\\padj\\{[^}]*\\}\\)")
  expect_false(grepl("\\}\\); \\\\padj", result))
})

test_that("reportggstatsplot rounds Greenhouse-Geisser degrees of freedom", {
  # A within-subjects parametric ANOVA is GG-corrected, so its dfs are
  # fractional. They used to be pasted at full double precision, e.g.
  # \F{1.80875305770353}{66.9238631350305}{0.11}.
  set.seed(42)
  df <- data.frame(
    id = factor(rep(1:20, times = 3)),
    condition = factor(rep(c("A", "B", "C"), each = 20)),
    score = c(stats::rnorm(20), stats::rnorm(20, 0.4), stats::rnorm(20, 0.8))
  )
  plt <- ggstatsplot::ggwithinstats(df, condition, score, type = "parametric")

  result <- suppressMessages(reportggstatsplot(plt, iv = "condition", dv = "score"))

  # whatever the dfs are, they must not be printed with runaway precision
  dfs <- unlist(regmatches(result, gregexpr("[0-9]+\\.[0-9]+", result)))
  expect_true(all(nchar(sub(".*\\.", "", dfs)) <= 3))
})

test_that("reportggstatsplotPostHoc falls back to raw levels for unmapped labels", {
  plt <- ggstatsplot::ggbetweenstats(mtcars, cyl, mpg)

  # Mapping only covers "4"; the other levels must fall back to their raw
  # level names instead of silently vanishing from the sentence
  expect_message(
    reportggstatsplotPostHoc(
      data = mtcars, p = plt, iv = "cyl", dv = "mpg",
      label_mappings = list("4" = "FourCyl")
    ),
    "FourCyl.*compared to (6|8)"
  )
})

test_that("reportDunnTestTable orderByP takes precedence over orderText", {
  set.seed(42)
  data <- data.frame(
    g = factor(rep(c("A", "B", "C"), each = 10)),
    v = c(rnorm(10), rnorm(10, 3), rnorm(10, 6))
  )
  d <- list(res = data.frame(
    Comparison = c("A - B", "B - C"),
    Z = c(2.5, 3.5),
    P.adj = c(0.04, 0.002),
    stringsAsFactors = FALSE
  ))

  out <- utils::capture.output(
    reportDunnTestTable(d, data = data, iv = "g", dv = "v", orderByP = TRUE)
  )

  pos_ab <- grep("A - B", out, fixed = TRUE)
  pos_bc <- grep("B - C", out, fixed = TRUE)
  expect_length(pos_ab, 1)
  expect_length(pos_bc, 1)
  # smaller p-value must come first despite orderText's default alphabetical sort
  expect_lt(pos_bc, pos_ab)
})

test_that("reportDunnTest and reportDunnTestTable handle significant findings", {
  skip_if_not_installed("FSA")

  d <- FSA::dunnTest(Sepal.Length ~ Species,
    data = iris,
    method = "holm"
  )

  expect_message(
    reportDunnTest(d, data = iris, iv = "Species", dv = "Sepal.Length"),
    "post-hoc test"
  )

  expect_error(
    reportDunnTestTable(d, data = iris, iv = "Species", dv = "Sepal.Length"),
    NA
  )
})

test_that("reportDunnTestTable can compute the Dunn test internally", {
  skip_if_not_installed("FSA")

  expect_error(
    reportDunnTestTable(d = NULL, data = iris, iv = "Species", dv = "Sepal.Length"),
    NA
  )
})

# Build a small within-subjects data set with a strong factor effect so that
# the ART contrasts are reliably significant.
make_art_con <- function() {
  set.seed(123)
  n <- 20
  df <- data.frame(
    UserID = factor(rep(seq_len(n), times = 3)),
    mode   = factor(rep(c("Hand", "Eye", "Both"), each = n)),
    prime  = factor(rep(rep(c("A", "B"), each = n / 2), times = 3))
  )
  df$score <- as.numeric(df$mode) * 2 + stats::rnorm(nrow(df))

  m <- ARTool::art(score ~ mode * prime + Error(UserID / mode), data = df)
  list(ac = ARTool::art.con(m, ~ mode, adjust = "holm"), data = df)
}

test_that("reportArtCon and reportArtConTable handle significant findings", {
  skip_if_not_installed("ARTool")
  skip_if_not_installed("emmeans")

  fit <- make_art_con()

  expect_message(
    reportArtCon(fit$ac, data = fit$data, iv = "mode", dv = "score", paired = TRUE, id = "UserID"),
    "post-hoc test"
  )

  expect_error(
    reportArtConTable(fit$ac, data = fit$data, iv = "mode", dv = "score", paired = TRUE, id = "UserID"),
    NA
  )
})

test_that("reportArtConTable computes a paired rank-biserial effect size", {
  skip_if_not_installed("ARTool")
  skip_if_not_installed("emmeans")

  fit <- make_art_con()

  # Capture the printed LaTeX table and confirm the effect-size column is
  # populated (not NA) when a valid pairing id is supplied.
  out <- utils::capture.output(
    reportArtConTable(fit$ac, data = fit$data, iv = "mode", dv = "score", paired = TRUE, id = "UserID")
  )
  r_rows <- grep("&", out, value = TRUE)
  expect_true(length(r_rows) > 0)
  expect_false(any(grepl("NA", out)))
})

test_that("reportArtCon accepts a summarised contrast object", {
  skip_if_not_installed("ARTool")
  skip_if_not_installed("emmeans")

  fit <- make_art_con()

  expect_message(
    reportArtCon(summary(fit$ac), data = fit$data, iv = "mode", dv = "score"),
    "post-hoc test"
  )
})

test_that("reportArtCon reports no significant differences when appropriate", {
  skip_if_not_installed("ARTool")
  skip_if_not_installed("emmeans")

  set.seed(7)
  n <- 20
  df <- data.frame(
    UserID = factor(rep(seq_len(n), times = 3)),
    mode   = factor(rep(c("Hand", "Eye", "Both"), each = n)),
    prime  = factor(rep(rep(c("A", "B"), each = n / 2), times = 3))
  )
  # No mode effect -> contrasts should be non-significant
  df$score <- stats::rnorm(nrow(df))

  m <- ARTool::art(score ~ mode * prime + Error(UserID / mode), data = df)
  ac <- ARTool::art.con(m, ~ mode, adjust = "holm")

  expect_message(
    reportArtCon(ac, data = df, iv = "mode", dv = "score"),
    "no significant differences"
  )
})

test_that(".effect_size_tex names the effect size that the test actually produced", {
  es <- colleyRstats:::.effect_size_tex

  # The bug this guards: every branch of reportggstatsplot() used to paste
  # ", r=", so a Hedges' g of -1.38 was reported as a correlation -- a value
  # outside the range r can take.
  expect_equal(es("Hedges' g", -1.3812), "$g_{Hedges}$ = -1.38")
  expect_equal(es("Cohen's d", 0.8), "$d_{Cohen}$ = 0.80")
  expect_equal(es("r (rank biserial)", 0.94), "\\rankbiserial{0.94}")
  expect_equal(es("Kendall's W", 0.0625), "$W_{Kendall}$ = 0.06")
  expect_equal(es("Epsilon2 (rank)", 0.086), "$\\epsilon_{ordinal}^{2}$ = 0.09")
  expect_equal(es("Cramer's V", 0.3), "$V_{Cramer}$ = 0.30")

  # "(partial)" must not be swallowed by the plain entry of the same family.
  expect_equal(es("Eta2 (partial)", 0.16), "$\\eta_{p}^{2}$ = 0.16")
  expect_equal(es("Eta2", 0.16), "$\\eta^{2}$ = 0.16")
  expect_equal(es("Omega2 (partial)", 0.04), "$\\omega_{p}^{2}$ = 0.04")
  expect_equal(es("Omega2", 0.06), "$\\omega^{2}$ = 0.06")

  # The robust tests return long descriptive names; print them rather than
  # guessing at a symbol.
  expect_equal(
    es("Explanatory measure of effect size", 0.378),
    "Explanatory measure of effect size = 0.38"
  )

  # Nothing to report is nothing printed, not "NA".
  expect_equal(es("Hedges' g", NA_real_), "")
  expect_equal(es("Hedges' g", NULL), "")
})

test_that(".effect_size_tex drops the leading zero only where APA allows it", {
  es <- colleyRstats:::.effect_size_tex
  withr::local_options(colleyRstats.leading_zero = FALSE)

  # eta^2 and r are bounded within [-1, 1], so ".16" is unambiguous.
  expect_equal(es("Eta2 (partial)", 0.16), "$\\eta_{p}^{2}$ = .16")
  expect_equal(es("r (rank biserial)", 0.94), "\\rankbiserial{.94}")

  # Hedges' g and Cohen's d are not bounded, so they keep the leading zero.
  expect_equal(es("Hedges' g", 0.85), "$g_{Hedges}$ = 0.85")
  expect_equal(es("Cohen's d", 0.85), "$d_{Cohen}$ = 0.85")
})

test_that("reportggstatsplot labels a t-test effect size as Hedges' g, not r", {
  set.seed(42)
  df <- data.frame(
    id = factor(rep(1:20, times = 2)),
    condition = factor(rep(c("A", "B"), each = 20)),
    score = c(stats::rnorm(20), stats::rnorm(20, 1.5))
  )
  plt <- ggstatsplot::ggwithinstats(df, condition, score, type = "parametric")

  result <- suppressMessages(reportggstatsplot(plt, iv = "condition", dv = "score"))

  expect_match(result, "g_{Hedges}", fixed = TRUE)
  expect_false(grepl(", r=", result, fixed = TRUE))
})

test_that("reportggstatsplot keeps the rank-biserial macro for a Wilcoxon test", {
  set.seed(42)
  df <- data.frame(
    id = factor(rep(1:20, times = 2)),
    condition = factor(rep(c("A", "B"), each = 20)),
    score = c(stats::rnorm(20), stats::rnorm(20, 1.5))
  )
  plt <- ggstatsplot::ggwithinstats(df, condition, score, type = "nonparametric")

  result <- suppressMessages(reportggstatsplot(plt, iv = "condition", dv = "score"))

  expect_match(result, "\\rankbiserial{", fixed = TRUE)
  expect_match(result, "(V=", fixed = TRUE)
})

test_that("reportggstatsplot names Kendall's W for Friedman and Epsilon2 for Kruskal-Wallis", {
  set.seed(42)
  df <- data.frame(
    id = factor(rep(1:20, times = 3)),
    condition = factor(rep(c("A", "B", "C"), each = 20)),
    score = c(stats::rnorm(20), stats::rnorm(20, 1.2), stats::rnorm(20, 2.4))
  )

  friedman <- suppressMessages(reportggstatsplot(
    ggstatsplot::ggwithinstats(df, condition, score, type = "nonparametric"),
    iv = "condition", dv = "score"
  ))
  expect_match(friedman, "W_{Kendall}", fixed = TRUE)

  kruskal <- suppressMessages(reportggstatsplot(
    ggstatsplot::ggbetweenstats(df, condition, score, type = "nonparametric"),
    iv = "condition", dv = "score"
  ))
  expect_match(kruskal, "epsilon", fixed = TRUE)

  expect_false(grepl(", r=", friedman, fixed = TRUE))
  expect_false(grepl(", r=", kruskal, fixed = TRUE))
})

test_that("reportggstatsplot names the ANOVA effect size instead of calling it r", {
  set.seed(42)
  df <- data.frame(
    condition = factor(rep(c("A", "B", "C"), each = 20)),
    score = c(stats::rnorm(20), stats::rnorm(20, 1.2), stats::rnorm(20, 2.4))
  )
  plt <- ggstatsplot::ggbetweenstats(df, condition, score, type = "parametric")

  result <- suppressMessages(reportggstatsplot(plt, iv = "condition", dv = "score"))

  expect_match(result, "\\F{", fixed = TRUE)
  expect_match(result, "omega", fixed = TRUE)
  expect_false(grepl(", r=", result, fixed = TRUE))
})


# ---- Regression tests for the 0.3.0 reporting fixes --------------------------

# Compile a LaTeX fragment with the package's own preamble -- the single source
# of truth for the report macros -- plus \providecommand stubs for any name
# macro (\UX, \mode, ...), as emit_overleaf() writes them. Skipped where no
# pdflatex is installed.
expect_compiles <- function(body) {
  skip_on_cran()
  skip_if(!nzchar(Sys.which("pdflatex")), "pdflatex is not available")
  body <- paste(body, collapse = "\n\n")
  toks <- unique(regmatches(body, gregexpr("\\\\[A-Za-z]+", body))[[1]])
  stubs <- sprintf("\\providecommand{%s}{%s}", toks, sub("^\\\\", "", toks))
  dir <- tempfile("colley-tex-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  writeLines(
    c(
      "\\documentclass{article}", "\\usepackage{booktabs}",
      colleyRstats:::.colley_macro_lines(), stubs,
      "\\begin{document}", body, "\\end{document}"
    ),
    file.path(dir, "doc.tex")
  )
  log <- suppressWarnings(system2(
    "pdflatex",
    c(
      "-interaction=nonstopmode", "-halt-on-error",
      paste0("-output-directory=", dir), file.path(dir, "doc.tex")
    ),
    stdout = TRUE, stderr = TRUE
  ))
  status <- attr(log, "status")
  ok <- is.null(status) || identical(as.integer(status), 0L)
  expect(ok, paste(
    c("pdflatex failed:", grep("^!|^l\\.[0-9]", log, value = TRUE)),
    collapse = "\n"
  ))
  invisible(ok)
}

# Level A: 26 ones plus four large outliers. Its mean (10.87) is the largest of
# the three, yet its mean rank is by far the smallest -- Dunn's Z for "A - B"
# is -4.40. Every post-hoc reporter used to call A "significantly higher".
skewed_three_groups <- function() {
  set.seed(1)
  data.frame(
    g = factor(rep(c("A", "B", "C"), each = 30)),
    v = c(
      rep(1, 26), 60, 70, 80, 90,
      stats::rnorm(30, 5, 0.5), stats::rnorm(30, 5.2, 0.5)
    )
  )
}

# FSA 0.10 prints its result while computing it.
quiet_dunn <- function(...) {
  out <- NULL
  utils::capture.output(out <- suppressMessages(FSA::dunnTest(...)))
  out
}

# One factor whose levels emmeans rewrites in contrast labels.
art_con_with_levels <- function(levs, adjust = "holm") {
  set.seed(123)
  n <- 20
  df <- data.frame(
    UserID = factor(rep(seq_len(n), times = 3)),
    mode = factor(rep(levs, each = n), levels = levs)
  )
  df$score <- as.numeric(df$mode) * 2 + stats::rnorm(nrow(df))
  m <- ARTool::art(score ~ mode + Error(UserID), data = df)
  list(ac = ARTool::art.con(m, ~mode, adjust = adjust), data = df)
}

test_that("reportDunnTest takes the direction from Z, not from the means", {
  skip_if_not_installed("FSA")
  df <- skewed_three_groups()
  d <- quiet_dunn(v ~ g, data = df, method = "holm")
  # the scenario: the test and the means point in opposite directions
  expect_lt(d$res$Z[d$res$Comparison == "A - B"], 0)
  expect_gt(mean(df$v[df$g == "A"]), mean(df$v[df$g == "B"]))

  result <- suppressMessages(reportDunnTest(d, data = df, iv = "g", dv = "v"))

  # before: "... for the g A was significantly higher (\m{10.87}, \sd{25.92}) ..."
  expect_false(any(grepl("A was significantly higher", result, fixed = TRUE)))
  expect_length(result, 2)
  # descriptives match the rank-based test: medians and IQRs
  expect_match(
    result[1],
    "g B was significantly higher (\\mdn{5.13}, \\iqr{0.57}) than for A (\\mdn{1.00}, \\iqr{0.00}; ",
    fixed = TRUE
  )
  expect_match(result[2], "g C was significantly higher (\\mdn{5.17}", fixed = TRUE)
})

test_that("reportDunnTest warns when forced means contradict the test", {
  skip_if_not_installed("FSA")
  df <- skewed_three_groups()
  d <- quiet_dunn(v ~ g, data = df, method = "holm")

  warnings <- testthat::capture_warnings(
    result <- suppressMessages(
      reportDunnTest(d, data = df, iv = "g", dv = "v", descriptives = "mean")
    )
  )
  expect_length(warnings, 2)
  expect_match(warnings, "order them the other way round", all = TRUE)
  # the sentence still follows the test
  expect_match(result[1], "g B was significantly higher (\\m{5.04}, \\sd{0.46})", fixed = TRUE)
})

test_that("reportDunnTest flags data that disagree with the test's Z", {
  skip_if_not_installed("FSA")
  df <- skewed_three_groups()
  d <- quiet_dunn(v ~ g, data = df, method = "holm")
  swapped <- df
  swapped$g <- factor(c(A = "B", B = "A", C = "C")[as.character(df$g)])

  warnings <- testthat::capture_warnings(
    suppressMessages(reportDunnTest(d, data = swapped, iv = "g", dv = "v"))
  )
  expect_true(any(grepl("disagrees with the mean ranks", warnings, fixed = TRUE)))
})

test_that("reportDunnTest does not label uncorrected p-values as adjusted", {
  skip_if_not_installed("FSA")
  df <- skewed_three_groups()

  holm <- suppressMessages(reportDunnTest(
    quiet_dunn(v ~ g, data = df, method = "holm"),
    data = df, iv = "g", dv = "v"
  ))
  expect_match(holm, "^A Dunn post-hoc test \\(Holm-adjusted\\) found that ")
  expect_match(holm, "\\padjminor{0.001}", fixed = TRUE)

  none <- suppressMessages(reportDunnTest(
    quiet_dunn(v ~ g, data = df, method = "none"),
    data = df, iv = "g", dv = "v"
  ))
  expect_match(none, "^A Dunn post-hoc test found that ")
  expect_match(none, "\\pminor{0.001}", fixed = TRUE)
  expect_false(any(grepl("padj", none, fixed = TRUE)))
  expect_false(any(grepl("adjusted", none, fixed = TRUE)))
})

test_that("reportDunnTestTable heads uncorrected p-values 'p' and names the correction", {
  skip_if_not_installed("FSA")
  skip_if_not_installed("xtable")
  df <- skewed_three_groups()

  none <- utils::capture.output(suppressMessages(reportDunnTestTable(
    quiet_dunn(v ~ g, data = df, method = "none"),
    data = df, iv = "g", dv = "v"
  )))
  expect_true(any(grepl("Comparison & Z & p & r", none, fixed = TRUE)))
  expect_false(any(grepl("p-adjusted", none, fixed = TRUE)))
  expect_true(any(grepl("not adjusted for multiple comparisons", none, fixed = TRUE)))

  holm <- utils::capture.output(suppressMessages(reportDunnTestTable(
    quiet_dunn(v ~ g, data = df, method = "holm"),
    data = df, iv = "g", dv = "v"
  )))
  expect_true(any(grepl("Comparison & Z & p-adjusted & r", holm, fixed = TRUE)))
  expect_true(any(grepl("p-values are Holm-adjusted", holm, fixed = TRUE)))
  # the caption states the direction in terms of what Dunn compares
  expect_true(any(grepl("first-named level has the higher mean rank", holm, fixed = TRUE)))
  expect_compiles(holm)
})

test_that("reportDunnTestTable never rounds a p-value across .05", {
  set.seed(42)
  data <- data.frame(
    g = factor(rep(c("A", "B"), each = 10)),
    v = c(stats::rnorm(10), stats::rnorm(10, 3))
  )
  d <- list(res = data.frame(
    Comparison = "A - B", Z = -1.96, P.adj = 0.04996, stringsAsFactors = FALSE
  ))
  out <- utils::capture.output(suppressMessages(
    reportDunnTestTable(d, data = data, iv = "g", dv = "v")
  ))
  # formatC() printed "0.0500" -- a "significant" row showing p = .05
  expect_true(any(grepl("0.04996", out, fixed = TRUE)))
  expect_false(any(grepl("0.0500 ", out, fixed = TRUE)))
})

test_that("reportDunnTest computes the effect size for a dv name with spaces", {
  skip_if_not_installed("FSA")
  df <- skewed_three_groups()
  names(df)[2] <- "Mental Demand"
  d <- quiet_dunn(`Mental Demand` ~ g, data = df, method = "holm")

  expect_no_warning(
    result <- suppressMessages(reportDunnTest(d, data = df, iv = "g", dv = "Mental Demand"))
  )
  expect_match(result, "\\rankbiserial{0.73}", fixed = TRUE)
})

test_that("reportArtCon takes the direction from the contrast estimate", {
  skip_if_not_installed("ARTool")
  skip_if_not_installed("emmeans")
  df <- skewed_three_groups()
  m <- ARTool::art(v ~ g, data = df)
  ac <- ARTool::art.con(m, ~g, adjust = "holm")
  expect_lt(summary(ac)$estimate[1], 0) # A - B: A lower on the aligned ranks

  result <- suppressMessages(reportArtCon(ac, data = df, iv = "g", dv = "v"))
  expect_false(any(grepl("A was significantly higher", result, fixed = TRUE)))
  expect_match(
    result[1],
    "^An ART-C post-hoc test \\(Holm-adjusted\\) found that v for the g B was significantly higher \\(\\\\mdn\\{5\\.13\\}"
  )

  warnings <- testthat::capture_warnings(suppressMessages(
    reportArtCon(ac, data = df, iv = "g", dv = "v", descriptives = "mean")
  ))
  expect_match(warnings, "order them the other way round", all = TRUE)
})

test_that("reportArtCon handles levels that emmeans rewrites in its labels", {
  skip_if_not_installed("ARTool")
  skip_if_not_installed("emmeans")

  # numeric-looking levels are labelled "mode1 - mode2"
  num <- art_con_with_levels(c("1", "2", "3"))
  expect_match(as.character(summary(num$ac)$contrast[1]), "mode1 - mode2", fixed = TRUE)
  result <- suppressMessages(reportArtCon(num$ac, data = num$data, iv = "mode", dv = "score"))
  expect_match(result, "\\\\mode\\{\\} 3 was significantly higher", all = FALSE)

  # levels containing - + * / are parenthesised: "Both - (Hand-only)"
  hyph <- art_con_with_levels(c("Both", "Hand-only", "Eye+Hand"))
  expect_true(any(grepl("(Hand-only)", summary(hyph$ac)$contrast, fixed = TRUE)))
  # used to fail with "missing value where TRUE/FALSE needed"
  result <- suppressMessages(reportArtCon(
    hyph$ac, data = hyph$data, iv = "mode", dv = "score", paired = TRUE, id = "UserID"
  ))
  expect_match(result[2], "Eye+Hand was significantly higher", fixed = TRUE)
  expect_match(result[2], "than for Both (", fixed = TRUE)

  # the summary (no contrast coefficients) is matched by label instead
  expect_no_error(suppressMessages(
    reportArtCon(summary(hyph$ac), data = hyph$data, iv = "mode", dv = "score")
  ))

  # the table used to fill r with NA for these levels
  out <- utils::capture.output(suppressMessages(reportArtConTable(
    hyph$ac, data = hyph$data, iv = "mode", dv = "score", paired = TRUE, id = "UserID"
  )))
  rows <- grep("Hand", out, value = TRUE)
  expect_length(grep(" & ", rows), 3)
  expect_false(any(grepl("NA", rows, fixed = TRUE)))
})

test_that("reportArtCon refuses contrasts that are not over the single factor iv", {
  skip_if_not_installed("ARTool")
  skip_if_not_installed("emmeans")
  set.seed(123)
  n <- 20
  df <- data.frame(
    UserID = factor(rep(seq_len(n), times = 3)),
    mode = factor(rep(c("Hand", "Eye", "Both"), each = n)),
    prime = factor(rep(rep(c("A", "B"), each = n / 2), times = 3))
  )
  df$score <- as.numeric(df$mode) * 2 + stats::rnorm(nrow(df))
  m <- ARTool::art(score ~ mode * prime + Error(UserID / mode), data = df)
  ac <- suppressMessages(ARTool::art.con(m, "mode:prime", adjust = "holm"))

  # (emmeans itself warns while computing the df of these cell contrasts)
  expect_error(
    suppressWarnings(suppressMessages(reportArtCon(ac, data = df, iv = "mode", dv = "score"))),
    "does not compare two levels"
  )
})

test_that("reportArtCon and its table do not label uncorrected p-values as adjusted", {
  skip_if_not_installed("ARTool")
  skip_if_not_installed("emmeans")
  skip_if_not_installed("xtable")
  fit <- art_con_with_levels(c("Hand", "Eye", "Both"), adjust = "none")

  result <- suppressMessages(reportArtCon(fit$ac, data = fit$data, iv = "mode", dv = "score"))
  expect_match(result, "^An ART-C post-hoc test found that ")
  expect_false(any(grepl("padj", result, fixed = TRUE)))
  expect_match(result, "\\pminor{0.001}", fixed = TRUE)

  out <- utils::capture.output(suppressMessages(
    reportArtConTable(fit$ac, data = fit$data, iv = "mode", dv = "score")
  ))
  expect_true(any(grepl("Comparison & t & df & p & r", out, fixed = TRUE)))
  expect_false(any(grepl("p-adjusted", out, fixed = TRUE)))
  expect_true(any(grepl("not adjusted for multiple comparisons", out, fixed = TRUE)))

  holm <- art_con_with_levels(c("Hand", "Eye", "Both"), adjust = "holm")
  result <- suppressMessages(reportArtCon(holm$ac, data = holm$data, iv = "mode", dv = "score"))
  expect_match(result, "^An ART-C post-hoc test \\(Holm-adjusted\\) found that ")
  expect_compiles(result)
})

test_that("reportArtConTable prints fractional df and names a z statistic", {
  skip_if_not_installed("ARTool")
  skip_if_not_installed("emmeans")
  skip_if_not_installed("lme4")
  skip_if_not_installed("xtable")
  set.seed(5)
  n <- 12
  dd <- data.frame(
    UserID = factor(rep(seq_len(n), times = 3)),
    mode = factor(rep(c("Hand", "Eye", "Both"), each = n))
  )
  dd$score <- as.numeric(dd$mode) * 2 + stats::rnorm(nrow(dd)) + rep(stats::rnorm(n), 3)
  dd <- dd[-c(3, 17, 30), ]

  # Kenward-Roger df of an unbalanced mixed ART model: 19.29, printed as "19"
  m <- suppressMessages(ARTool::art(score ~ mode + (1 | UserID), data = dd))
  ac <- suppressMessages(ARTool::art.con(m, ~mode, adjust = "holm"))
  kr_df <- summary(ac)$df[1]
  expect_false(kr_df == round(kr_df))
  out <- utils::capture.output(suppressMessages(
    reportArtConTable(ac, data = dd, iv = "mode", dv = "score")
  ))
  expect_true(any(grepl(paste0(" & ", round(kr_df, 2), " & "), out, fixed = TRUE)))

  # an emmeans contrast with asymptotic df carries z ratios: header "z", no df
  fit <- lme4::lmer(score ~ mode + (1 | UserID), data = dd)
  zc <- emmeans::contrast(
    emmeans::emmeans(fit, ~mode, lmer.df = "asymptotic"), "pairwise", adjust = "holm"
  )
  out_z <- utils::capture.output(suppressMessages(
    reportArtConTable(zc, data = dd, iv = "mode", dv = "score")
  ))
  expect_true(any(grepl("Comparison & z & p-adjusted & r", out_z, fixed = TRUE)))
  expect_true(any(grepl("Positive z-values", out_z, fixed = TRUE)))
  expect_compiles(out_z)
})

test_that("reportNparLD writes a compilable F(df, infinity) with the fractional ATS df", {
  skip_if_not_installed("nparLD")
  set.seed(123)
  d <- data.frame(
    Subject = factor(rep(1:10, each = 3)),
    Time = factor(rep(c("T1", "T2", "T3"), times = 10)),
    TLX1 = rep(c(45, 52, 61), times = 10) + stats::rnorm(30, sd = 4)
  )
  utils::capture.output(
    model <- nparLD::nparLD(TLX1 ~ Time, data = d, subject = "Subject")
  )
  ats_df <- as.data.frame(colleyRstats:::.nparld_anova_table(model))$df[1]
  expect_false(ats_df == round(ats_df))

  result <- suppressMessages(reportNparLD(model, dv = "tlx_mental"))
  # was "\F{2}{$\infty$}{...}": a rounded df, and nested math inside \F
  expect_match(result, paste0("\\F{", round(ats_df, 2), "}{\\infty}{"), fixed = TRUE)
  expect_false(grepl("$\\infty$", result, fixed = TRUE))
  expect_match(result, "on tlx\\_mental", fixed = TRUE)
  expect_compiles(result)
})

test_that("reportNparLD escapes the dv in its no-effects message", {
  model <- list(ANOVA.test = data.frame(
    Statistic = 0.4, df = 1.9, `p-value` = 0.6, check.names = FALSE
  ))
  rownames(model$ANOVA.test) <- "Time"
  expect_message(
    reportNparLD(model, dv = "tlx_mental"),
    "no significant effects on tlx\\\\_mental"
  )
})

test_that("reportNparLD labels terms by ':' and renders each factor safely", {
  ats <- matrix(
    c(12.3, 1.7, 1e-05, 8.2, 1.4, 0.001),
    nrow = 2, byrow = TRUE,
    dimnames = list(c("UX", "Video_Type:trial2"), c("Statistic", "df", "p-value"))
  )
  model <- structure(list(ATS = ats), class = "nparld_fit")
  result <- suppressMessages(reportNparLD(model, dv = "X position"))
  expect_match(result[1], "main effect of \\UX{} on X position", fixed = TRUE)
  expect_match(result[2], "interaction effect of Video\\_Type $\\times$ trial2 on X position", fixed = TRUE)
  expect_compiles(result)
})

test_that("reportART decides interaction from ':' and renders each factor safely", {
  # A main effect called UX was reported as an interaction (it contains a
  # capital X), a dv "X position" became "on $\times$ \ position", and
  # Video_Type / trial2 were emitted as un-compilable \Video_Type / \trial2.
  model <- data.frame(
    Term = c("UX", "Video_Type:trial2", "time"),
    F = c(9, 7, 6), Df = c(1, 2, 1), Df.res = c(38, 76.5, 38),
    `Pr(>F)` = c(0.004, 0.0016, 0.02),
    check.names = FALSE
  )
  result <- suppressMessages(reportART(model, dv = "X position"))

  expect_match(result[1], "main effect of \\UX{} on X position", fixed = TRUE)
  expect_match(
    result[2],
    "interaction effect of Video\\_Type $\\times$ trial2 on X position (\\F{2}{76.5}{7.00}",
    fixed = TRUE
  )
  # `time` is the TeX primitive \time: it must come out as text
  expect_match(result[3], "main effect of time on X position", fixed = TRUE)
  expect_false(any(grepl("\\Video_Type", result, fixed = TRUE)))
  expect_compiles(result)
})

test_that("reportART reports a real ART anova with underscores in factor names", {
  skip_if_not_installed("ARTool")
  set.seed(123)
  d <- data.frame(
    y = stats::rnorm(80),
    Video_Type = factor(rep(c("A", "B"), each = 40)),
    UX = factor(rep(c("G1", "G2"), times = 40)),
    UserID = factor(rep(1:20, each = 4))
  )
  d$y <- d$y + (d$UX == "G2") * 1.5 + (d$Video_Type == "B") * (d$UX == "G2") * 1.5
  a <- stats::anova(ARTool::art(y ~ Video_Type * UX + Error(UserID / UX), data = d))

  result <- suppressMessages(reportART(a, dv = "tlx_mental"))
  expect_match(result, "main effect of Video\\_Type on", fixed = TRUE, all = FALSE)
  expect_match(result, "main effect of \\UX{} on", fixed = TRUE, all = FALSE)
  expect_match(result, "interaction effect of Video\\_Type $\\times$ \\UX{} on", fixed = TRUE, all = FALSE)
  expect_compiles(result)
})

test_that("reportNPAV labels terms by ':' and escapes the dv", {
  model <- data.frame(
    Df = c(1, 1, 10), `F value` = c(6.12, 5.01, NA), `Pr(>F)` = c(0.033, 0.045, NA),
    check.names = FALSE
  )
  rownames(model) <- c("UX", "Video_Type:trial2", "Residuals")
  result <- suppressWarnings(suppressMessages(reportNPAV(model, dv = "tlx_mental")))
  expect_match(result[1], "main effect of \\UX{} on tlx\\_mental", fixed = TRUE)
  expect_match(result[2], "interaction effect of Video\\_Type $\\times$ trial2", fixed = TRUE)
  expect_compiles(result)

  none <- data.frame(Df = c(1, 10), `F value` = c(0.1, NA), `Pr(>F)` = c(0.8, NA), check.names = FALSE)
  rownames(none) <- c("UX", "Residuals")
  expect_message(
    suppressWarnings(reportNPAV(none, dv = "tlx_mental")),
    "no significant effects on tlx\\\\_mental"
  )
})

test_that("reportART and reportNPAV give a two-sided 95% CI for partial eta squared", {
  # F_to_eta2() defaults to a one-sided interval whose upper bound is always 1;
  # it was printed as "95% CI: [0.02, 1.00]".
  es <- as.data.frame(effectsize::F_to_eta2(9, 1, 38, ci = 0.95, alternative = "two.sided"))
  expected <- sprintf("95\\%% CI: [%.2f, %.2f]", es$CI_low, es$CI_high)

  model <- data.frame(
    Term = "UX", F = 9, Df = 1, Df.res = 38, `Pr(>F)` = 0.004, check.names = FALSE
  )
  art <- suppressMessages(reportART(model, dv = "TiA"))
  expect_match(art, expected, fixed = TRUE)
  expect_false(grepl("1.00]", art, fixed = TRUE))

  npav <- data.frame(Df = c(1, 38), `F value` = c(9, NA), `Pr(>F)` = c(0.004, NA), check.names = FALSE)
  rownames(npav) <- c("UX", "Residuals")
  npav_out <- suppressWarnings(suppressMessages(reportNPAV(npav, dv = "TiA")))
  expect_match(npav_out, expected, fixed = TRUE)
})

test_that("reportggstatsplotPostHoc writes the dv as text, never as a macro", {
  # .tex_name("v") used to give \v -- the hacek accent -- and "Workload" became
  # a \Workload macro, unlike every other reporter.
  df <- data.frame(grp = c("A", "A", "B", "B"), v = c(5, 6, 1, 2), Workload = c(5, 6, 1, 2))
  plot <- fake_pwc_plot("Games-Howell", "Holm")

  v <- suppressMessages(reportggstatsplotPostHoc(df, plot, iv = "grp", dv = "v"))
  expect_match(v, "in terms of v compared to", fixed = TRUE)
  expect_false(grepl("\\v", v, fixed = TRUE))

  w <- suppressMessages(reportggstatsplotPostHoc(df, plot, iv = "grp", dv = "Workload"))
  expect_match(w, "in terms of Workload compared to", fixed = TRUE)
})

test_that("reportggstatsplotPostHoc overwrites sink_to when nothing is significant", {
  # It returned before writing, so the manuscript kept an earlier run's
  # significant result.
  df <- data.frame(grp = c("A", "A", "B", "B"), val = c(5, 6, 1, 2))
  path <- withr::local_tempfile(fileext = ".tex")
  writeLines("A post-hoc test found that A was significantly higher.", path)

  result <- suppressMessages(reportggstatsplotPostHoc(
    df, fake_pwc_plot("Games-Howell", "Holm", p.value = 0.4),
    iv = "grp", dv = "val", sink_to = path
  ))
  expect_equal(readLines(path), result)
  expect_match(result, "found no significant differences for val")
})

test_that("reportggstatsplotPostHoc takes a Dunn direction from mean ranks", {
  df <- skewed_three_groups()
  plt <- ggstatsplot::ggbetweenstats(df, g, v, type = "nonparametric")

  result <- suppressMessages(reportggstatsplotPostHoc(df, plt, iv = "g", dv = "v"))
  expect_false(any(grepl("that A was significantly higher", result, fixed = TRUE)))
  expect_true(any(grepl(
    "that B was significantly higher (\\mdn{5.13}, \\iqr{0.57}) in terms of v compared to A (\\mdn{1.00}",
    result,
    fixed = TRUE
  )))
  expect_compiles(result)
})

test_that("reportggstatsplotPostHoc takes a Durbin-Conover direction from within-participant ranks", {
  # B exceeds A within every participant but one, whose A is an outlier of
  # 100: the mean of A is larger, but A ranks below B in 14 of 15 blocks.
  set.seed(11)
  n <- 15
  base <- stats::rnorm(n)
  d <- data.frame(
    id = factor(rep(seq_len(n), times = 3)),
    cond = factor(rep(c("A", "B", "C"), each = n)),
    y = c(base, base + 0.3 + stats::runif(n, 0, 0.1), base + 2 + stats::runif(n, 0, 0.1))
  )
  d$y[d$id == 1 & d$cond == "A"] <- 100
  expect_gt(mean(d$y[d$cond == "A"]), mean(d$y[d$cond == "B"]))
  plt <- ggstatsplot::ggwithinstats(d, cond, y, subject.id = id, type = "nonparametric")

  result <- suppressMessages(reportggstatsplotPostHoc(d, plt, iv = "cond", dv = "y", subject = "id"))
  expect_match(result[1], "^A Durbin-Conover post-hoc test")
  expect_true(any(grepl("that B was significantly higher (\\mdn{", result, fixed = TRUE)))
  expect_false(any(grepl("that A was significantly higher", result, fixed = TRUE)))

  # without `subject`, observations are paired by row order (as ggwithinstats
  # does without subject.id) and the user is told so
  expect_warning(
    suppressMessages(reportggstatsplotPostHoc(d, plt, iv = "cond", dv = "y")),
    "paired by their row order"
  )
})

test_that("reportggstatsplotPostHoc describes Yuen's test with trimmed means", {
  set.seed(42)
  df <- data.frame(
    condition = factor(rep(c("A", "B", "C"), each = 20)),
    score = c(stats::rnorm(20), stats::rnorm(20, 0.8), stats::rnorm(20, 1.6))
  )
  plt <- ggstatsplot::ggbetweenstats(df, condition, score, type = "robust")
  result <- suppressMessages(reportggstatsplotPostHoc(df, plt, iv = "condition", dv = "score"))

  trimmed_c <- mean(df$score[df$condition == "C"], trim = 0.2)
  expect_match(result, "^A Yuen's trimmed means post-hoc test")
  expect_match(result[1], paste0("that C was significantly higher ($M_{t}$=", sprintf("%.2f", trimmed_c)), fixed = TRUE)
  expect_compiles(result)
})

test_that("reportggstatsplotPostHoc describes only the participants ggwithinstats tested", {
  # Participant 1 lacks C, so ggwithinstats() drops them -- including their
  # outlying A of 40. Means over all rows put A above B (2.38 vs 0.91) although
  # the paired test, on the remaining 14, finds B higher.
  set.seed(12)
  n <- 15
  w <- data.frame(
    id = factor(rep(seq_len(n), times = 3)),
    cond = factor(rep(c("A", "B", "C"), each = n))
  )
  w$y <- rep(stats::rnorm(n), 3) +
    c(stats::rnorm(n, 0, 0.5), stats::rnorm(n, 1.5, 0.5), stats::rnorm(n, 3, 0.5))
  w$y[w$id == 1 & w$cond == "A"] <- 40
  w$y[w$id == 1 & w$cond == "C"] <- NA
  plt <- ggstatsplot::ggwithinstats(w, cond, y, subject.id = id, type = "parametric")

  result <- suppressMessages(
    reportggstatsplotPostHoc(w, plt, iv = "cond", dv = "y", subject = "id")
  )
  complete <- w[w$id != "1", ]
  m_a <- sprintf("%.2f", mean(complete$y[complete$cond == "A"]))
  m_b <- sprintf("%.2f", mean(complete$y[complete$cond == "B"]))
  expect_match(
    result[1],
    paste0("that B was significantly higher (\\m{", m_b, "}"),
    fixed = TRUE
  )
  expect_match(result[1], paste0("compared to A (\\m{", m_a, "}"), fixed = TRUE)

  # without `subject` the mismatch is flagged
  expect_warning(
    suppressMessages(reportggstatsplotPostHoc(w, plt, iv = "cond", dv = "y")),
    "Pass `subject`"
  )

  # one row per participant and level is required
  dup <- rbind(w, w[1, ])
  expect_error(
    suppressMessages(reportggstatsplotPostHoc(dup, plt, iv = "cond", dv = "y", subject = "id")),
    "one row per participant"
  )
})

test_that("reportggstatsplotPostHoc ignores `subject` for a between-subjects design", {
  df <- data.frame(
    pid = factor(1:4), grp = c("A", "A", "B", "B"), val = c(5, 6, 1, 2)
  )
  expect_message(
    result <- reportggstatsplotPostHoc(
      df, fake_pwc_plot("Games-Howell", "Holm"),
      iv = "grp", dv = "val", subject = "pid"
    ),
    "between-subjects"
  )
  expect_match(result, "A was significantly higher (\\m{5.50}", fixed = TRUE)
})

test_that("reportggstatsplotPostHoc refuses Bayesian pairwise tables", {
  # They carry Bayes factors and no p.value column, which used to be read as
  # "no significant differences".
  set.seed(42)
  df <- data.frame(
    condition = factor(rep(c("A", "B", "C"), each = 20)),
    score = c(stats::rnorm(20), stats::rnorm(20, 0.8), stats::rnorm(20, 1.6))
  )
  plt <- ggstatsplot::ggbetweenstats(df, condition, score, type = "bayes")
  expect_error(
    reportggstatsplotPostHoc(df, plt, iv = "condition", dv = "score"),
    "Bayes factors, not p-values"
  )
})

test_that("reportggstatsplot reports a Bayes factor for type = 'bayes'", {
  # .fmt_p_macro(NULL) failed with "argument is of length zero".
  set.seed(42)
  df <- data.frame(
    condition = factor(rep(c("A", "B", "C"), each = 20)),
    score = c(stats::rnorm(20), stats::rnorm(20, 0.8), stats::rnorm(20, 1.6))
  )
  plt <- ggstatsplot::ggbetweenstats(df, condition, score, type = "bayes")
  bf <- ggstatsplot::extract_stats(plt)$subtitle_data$bf10[1]

  result <- suppressMessages(reportggstatsplot(plt, iv = "condition", dv = "score"))
  expect_match(result, "$\\mathrm{BF}_{10} = ", fixed = TRUE)
  expect_match(
    result,
    paste("found", as.character(effectsize::interpret_bf(bf, rules = "jeffreys1961")), "an effect of"),
    fixed = TRUE
  )
  expect_compiles(result)
})

test_that("reportggstatsplot reports Yuen's trimmed-means test as t(df)", {
  # It fell through to "(statistic=-2.73, ...)" and dropped df.error.
  set.seed(42)
  df <- data.frame(
    condition = factor(rep(c("A", "B"), each = 20)),
    score = c(stats::rnorm(20), stats::rnorm(20, 1.2))
  )
  plt <- ggstatsplot::ggbetweenstats(df, condition, score, type = "robust")
  st <- ggstatsplot::extract_stats(plt)$subtitle_data

  result <- suppressMessages(reportggstatsplot(plt, iv = "condition", dv = "score"))
  expect_match(result, paste0("(t(", round(st$df.error, 2), ")="), fixed = TRUE)
  expect_false(grepl("statistic=", result, fixed = TRUE))
})

test_that("reportggstatsplot does not double the article of a method name", {
  set.seed(42)
  df <- data.frame(
    condition = factor(rep(c("A", "B", "C"), each = 20)),
    score = c(stats::rnorm(20), stats::rnorm(20, 0.8), stats::rnorm(20, 1.6))
  )
  plt <- ggstatsplot::ggbetweenstats(df, condition, score, type = "robust")
  result <- suppressMessages(reportggstatsplot(plt, iv = "condition", dv = "score"))
  # statsExpressions names it "A heteroscedastic one-way ANOVA for trimmed means"
  expect_match(result, "^A heteroscedastic one-way ANOVA for trimmed means found")
  expect_false(grepl("^An? A ", result))
})

test_that("latexify_report escapes every LaTeX special it does not convert", {
  input <- paste(
    "We fitted a model to predict tlx_mental with cond_type (formula: tlx_mental ~ cond_type).",
    "- The effect of cond_type [b] is significant (p < .001, R2 > 0.5) & large: 100% #1, x^2",
    sep = "\n"
  )
  out <- latexify_report(input, print_result = FALSE)

  expect_match(out, "predict tlx\\_mental with cond\\_type", fixed = TRUE)
  expect_match(out, "tlx\\_mental $\\sim$ cond\\_type", fixed = TRUE)
  expect_match(out, "(p $<$ .001, $R^2$ $>$ 0.5) \\& large: 100\\% \\#1, x\\textasciicircum{}2", fixed = TRUE)
  expect_match(out, "\\item The effect", fixed = TRUE)
  expect_compiles(out)
})

test_that("latexify_report output of a real report() compiles", {
  skip_if_not_installed("report")
  set.seed(3)
  d <- data.frame(
    tlx_mental = stats::rnorm(40),
    cond_type = factor(rep(c("a", "b"), 20))
  )
  txt <- report::report(stats::lm(tlx_mental ~ cond_type, data = d))
  out <- latexify_report(txt, print_result = FALSE)
  expect_false(grepl("tlx_mental", out, fixed = TRUE))
  expect_match(out, "tlx\\_mental", fixed = TRUE)
  expect_compiles(out)
})

test_that("post-hoc tables use a \\label key that LaTeX accepts", {
  expect_equal(
    colleyRstats:::.table_label("tab:posthoc", "Species", "cost%#"),
    "tab:posthoc-Species-cost--"
  )
  expect_equal(
    colleyRstats:::.table_label("tab:artcon", "mode", "Sepal.Length"),
    "tab:artcon-mode-Sepal.Length"
  )
})


test_that(".ggstatsplot_is_within does not read 'independent samples' as within", {
  set.seed(4)
  d <- data.frame(g = rep(c("a", "b"), each = 20), v = c(rnorm(20), rnorm(20, 1)))
  p <- ggstatsplot::ggbetweenstats(d, g, v, type = "robust")
  expect_match(ggstatsplot::extract_stats(p)$subtitle_data$method[1], "independent", ignore.case = TRUE)
  expect_false(.ggstatsplot_is_within(p))
})

test_that("Bayes factors below 1 keep two significant digits", {
  expect_identical(.fmt_bf(0.014), "0.014")
  expect_identical(.fmt_bf(0.05), "0.050")
  expect_identical(.fmt_bf(0.5), "0.50")
  expect_identical(.fmt_bf(3.2), "3.20")
})

test_that("the direction warning only recommends 'auto' when descriptives were forced", {
  desc <- data.frame(loc = c(1, 2), row.names = c("A", "B"))
  expect_warning(
    .check_descriptive_direction(desc, "A", "B", TRUE, "mean", "Dunn test", forced = TRUE),
    "descriptives = \"auto\"", fixed = TRUE
  )
  w <- tryCatch(
    .check_descriptive_direction(desc, "A", "B", TRUE, "median", "Dunn test", forced = FALSE),
    warning = function(w) conditionMessage(w)
  )
  expect_match(w, "conventionally accompany")
  expect_no_match(w, "descriptives = \"auto\"", fixed = TRUE)
})

test_that("reportggstatsplotPostHoc warns on a within plot without subject, even with equal counts", {
  set.seed(9)
  n <- 15
  d <- data.frame(id = rep(1:n, 3), cond = rep(c("A", "B", "C"), each = n))
  d$y <- rnorm(n, 0, 2)[d$id] + c(0, 2, 4)[as.integer(factor(d$cond))] + rnorm(3 * n, 0, 0.5)
  p <- ggstatsplot::ggwithinstats(d, cond, y, subject.id = id, type = "p")
  expect_warning(
    suppressMessages(reportggstatsplotPostHoc(d, p, iv = "cond", dv = "y")),
    "no `subject` was given", fixed = TRUE
  )
  expect_no_warning(
    suppressMessages(reportggstatsplotPostHoc(d, p, iv = "cond", dv = "y", subject = "id"))
  )
})