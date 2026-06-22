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
    "main effect of .*Video on mental demand"
  )
  expect_message(
    reportART(model[2, , drop = FALSE], dv = "mental demand"),
    "interaction effect of .*gesture"
  )
})

test_that("reportNparLD reports significant effects", {
  model <- list(
    ANOVA.test = data.frame(
      Statistic = c(4.2, NA),
      df = c(1, 10),
      `p-value` = c(0.02, NA),
      RTE = c(0.6, NA),
      check.names = FALSE
    )
  )
  rownames(model$ANOVA.test) <- c("Time", "Residuals")

  expect_message(
    reportNparLD(model, dv = "TLX1"),
    "nparLD analysis found a significant"
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

test_that("reportMeanAndSD emits formatted output", {
  example_data <- data.frame(
    Condition = rep(c("A", "B"), each = 5),
    TLX1 = rnorm(10)
  )

  expect_message(
    reportMeanAndSD(example_data, iv = "Condition", dv = "TLX1"),
    "%A"
  )
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
