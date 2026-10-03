test_that("normalize scales values correctly", {
  # Test standard scaling 1-5 to 0-1
  input <- c(1, 2, 3, 4, 5)
  output <- normalize(input, 1, 5, 0, 1)

  expect_equal(output, c(0, 0.25, 0.5, 0.75, 1))

  # Test with single value
  expect_equal(normalize(10, 0, 100, 0, 1), 0.1)
})

test_that("normalize rejects a zero-width input range", {
  expect_error(normalize(1:5, 2, 2, 0, 1), "must differ")
})

test_that("replace_values leaves untouched numeric columns bit-identical", {
  df <- data.frame(
    label = c("bad", "good"),
    value = c(pi, exp(1))
  )

  result <- replace_values(df, to_replace = "bad", replace_with = "worse")

  expect_equal(result$label, c("worse", "good"))
  # A character round-trip would lose the last digits of precision
  expect_identical(result$value, df$value)
})

test_that("replace_values only modifies matching numeric entries", {
  df <- data.frame(code = c(99, 1.5, 99), keep = c(pi, pi, pi))

  result <- replace_values(df, to_replace = "99", replace_with = "0")

  expect_equal(result$code, c(0, 1.5, 0))
  expect_identical(result$keep, df$keep)
})

test_that(".p_to_asterisk follows APA boundaries", {
  expect_identical(
    colleyRstats:::.p_to_asterisk(c(0.0005, 0.001, 0.005, 0.01, 0.03, 0.05, 0.5, NA)),
    c("***", "**", "**", "*", "*", NA, NA, NA)
  )
})

test_that("rFromWilcoxAdjusted caps adjusted p-values at 1", {
  withr::local_options(lifecycle_verbosity = "quiet")
  fake_w <- list(p.value = 0.9, data.name = "fake data")

  expect_message(result <- rFromWilcoxAdjusted(fake_w, N = 20, adjustFactor = 5), "Effect Size")
  expect_false(is.nan(result$r))
  expect_equal(result$z, qnorm(0.5))
})

test_that("replace_values swaps items correctly", {
  df <- data.frame(a = c("bad", "good", "bad"), b = 1:3)

  # Replace 'bad' with 'worse'
  result <- replace_values(df, "bad", "worse")

  expect_equal(result$a, c("worse", "good", "worse"))
  expect_equal(result$b, 1:3) # Ensure other columns are untouched
})

test_that("replace_values errors on mismatched replacement lengths", {
  df <- data.frame(a = c("bad", "good", "bad"), b = 1:3)

  expect_error(
    replace_values(df, to_replace = c("bad", "good"), replace_with = "worse"),
    "Length of 'to_replace' and 'replace_with' must be the same."
  )
})



test_that("check_normality_by_group identifies distributions", {
  # Create perfect normal data
  set.seed(123)
  df_normal <- data.frame(
    group = rep(c("A", "B"), each = 20),
    value = rnorm(40)
  )

  # Should return TRUE (it uses Shapiro-Wilk internally)
  # Note: shapiro test is sensitive, so we expect TRUE for perfect normal data
  expect_true(check_normality_by_group(df_normal, "group", "value"))
})

test_that("a constant group alone makes check_normality_by_group return FALSE", {
  # Group B is as normal as 20 values can be, so the FALSE can only come from
  # group A, which has no variance and therefore cannot be tested. (This test
  # used to pair the constant group with a discrete uniform B -- Shapiro-Wilk
  # p = .035 -- so B, not the constant group, decided the outcome.)
  df_const <- data.frame(
    group = rep(c("A", "B"), each = 20),
    value = c(rep(1, 20), qnorm(ppoints(20)))
  )

  res <- check_normality_by_group(df_const, "group", "value")
  tests <- attr(res, "tests")

  expect_false(res)
  expect_identical(attr(res, "untestable"), "A")
  expect_false(tests$testable[tests$group == "A"])
  expect_gt(tests$p_value[tests$group == "B"], 0.5)
})

test_that("a non-normal group makes check_normality_by_group return FALSE", {
  df_skew <- data.frame(
    group = rep(c("A", "B"), each = 30),
    value = c(qnorm(ppoints(30)), qexp(ppoints(30))^2)
  )

  res <- check_normality_by_group(df_skew, "group", "value")
  tests <- attr(res, "tests")

  expect_false(res)
  expect_length(attr(res, "untestable"), 0)
  expect_lt(tests$p_adjusted[tests$group == "B"], 0.05)
  expect_gt(tests$p_value[tests$group == "A"], 0.5)
})

test_that("check_normality_by_group warns and returns logical for large groups", {
  set.seed(456)
  df_large <- data.frame(
    group = c(rep("A", 5001), rep("B", 10)),
    value = c(rnorm(5001), rnorm(10))
  )

  expect_warning(
    result <- check_normality_by_group(df_large, "group", "value"),
    "n > 5000"
  )
  expect_true(is.logical(result))
})

test_that("not_empty throws error on NULL or NA", {
  expect_error(not_empty(NULL))
  expect_error(not_empty(NA))
  expect_true(not_empty(5))
})

test_that("not_empty names the offending argument in its default message", {
  my_input <- NULL
  expect_error(not_empty(my_input), "`my_input` must not be empty")
  # An explicit message still wins
  expect_error(not_empty(NULL, msg = "custom message"), "custom message")
})

test_that("column checks name the missing column and list available ones", {
  df <- data.frame(group = rep(c("A", "B"), each = 5), value = rnorm(10))

  expect_error(
    check_normality_by_group(df, "grp", "value"),
    "'grp' not found in `data`"
  )
  expect_error(
    check_normality_by_group(df, "group", "typo"),
    "Available columns: group, value"
  )
  expect_error(
    reportMeanAndSD(df, iv = "group", dv = "nope"),
    "'nope' not found"
  )
  expect_error(
    checkAssumptionsForAnova(df, y = "value", factors = c("group", "missing1")),
    "'missing1' not found"
  )
})

test_that("add_pareto columns validate objective columns", {
  skip_if_not_installed("emoa")

  df <- data.frame(trust = c(1, 2), label = c("a", "b"))

  expect_error(
    add_pareto_emoa_column(df, objectives = c("trust", "comfort")),
    "'comfort' not found"
  )
  expect_error(
    add_pareto_emoa_column(df, objectives = c("trust", "label")),
    "must be numeric"
  )
})

test_that("remove_outliers_REI accepts a character vector of variables", {
  df <- data.frame(var1 = c(1, 2, 3, 4), var2 = c(1, 3, 3, 5), other = c(9, 9, 9, 9))

  res_vector <- remove_outliers_REI(df, header = TRUE, variables = c("var1", "var2"))
  res_string <- remove_outliers_REI(df, header = TRUE, variables = "var1,var2")

  expect_identical(res_vector$REI, res_string$REI)
})

test_that("na.zero replaces NA values with zero", {
  expect_equal(na.zero(c(NA, 1, NA, 2)), c(0, 1, 0, 2))
})

test_that("%!in% negates %in% membership", {
  expect_true("a" %!in% c("b", "c"))
  expect_false("a" %!in% c("a", "b"))
})

test_that("pathPrep normalizes Windows paths and uses custom clipboard functions", {
  captured <- NULL
  read_fn <- function() "C:\\Temp\\File.txt"
  write_fn <- function(x) {
    captured <<- x
    invisible(NULL)
  }

  result <- pathPrep(path = "clipboard", read_fn = read_fn, write_fn = write_fn)

  expect_equal(result, "C:/Temp/File.txt")
  expect_equal(captured, "C:/Temp/File.txt")

  expect_equal(pathPrep("D:\\Data\\Report.csv", read_fn = read_fn, write_fn = write_fn), "D:/Data/Report.csv")
})

test_that("stat_sum_df returns a ggplot2 layer", {
  mean_fun <- function(x) {
    m <- mean(x, na.rm = TRUE)
    data.frame(y = m, ymin = m, ymax = m)
  }
  layer <- stat_sum_df(mean_fun)
  expect_true(inherits(layer, "LayerInstance"))
})

test_that("n_fun returns median and label", {
  result <- n_fun(c(1, 2, 3, 4))
  expect_equal(result$y, 2.5)
  expect_equal(result$label, "n = 4")
})

test_that("check_homogeneity_by_group handles missing rstatix", {
  df <- data.frame(group = rep(c("A", "B"), each = 5), value = rnorm(10))
  if (requireNamespace("rstatix", quietly = TRUE)) {
    expect_true(is.logical(check_homogeneity_by_group(df, "group", "value")))
  } else {
    expect_warning(
      result <- check_homogeneity_by_group(df, "group", "value"),
      "rstatix"
    )
    expect_false(result)
  }
})

test_that("rFromWilcox produces effect size output", {
  set.seed(1)
  df <- data.frame(group = rep(c("A", "B"), each = 10), value = rnorm(20))
  w <- stats::wilcox.test(value ~ group, data = df, exact = FALSE)

  expect_message(result <- rFromWilcox(w, N = nrow(df)), "Effect Size")
  expect_true(all(c("r", "z", "text") %in% names(result)))
})

test_that("rFromWilcoxAdjusted produces adjusted effect size output", {
  withr::local_options(lifecycle_verbosity = "quiet")
  set.seed(1)
  df <- data.frame(group = rep(c("A", "B"), each = 10), value = rnorm(20))
  w <- stats::wilcox.test(value ~ group, data = df, exact = FALSE)

  expect_message(result <- rFromWilcoxAdjusted(w, N = nrow(df), adjustFactor = 2), "Effect Size")
  expect_true(all(c("r", "z", "text") %in% names(result)))
})

test_that("rFromNPAV produces latex-friendly effect size output", {
  expect_message(result <- rFromNPAV(0.02, N = 180), "\\\\effectsize")
  expect_true(all(c("r", "z", "text") %in% names(result)))
})

test_that("debug_contr_error summarizes factor levels", {
  dat <- data.frame(
    group = factor(rep(letters[1:3], each = 2)),
    score = rnorm(6)
  )

  result <- debug_contr_error(dat)
  expect_true(is.list(result))
  expect_true(all(c("nlevels", "levels") %in% names(result)))

  expect_error(debug_contr_error(dat, subset_vec = c(TRUE, FALSE)))
  expect_error(debug_contr_error(dat, subset_vec = c(0, 10)))
})

test_that("checkAssumptionsForAnova reports parametric guidance", {
  # The previous data -- normal quantiles between the 10th and 90th
  # percentiles -- have light-tailed residuals (Shapiro-Wilk p = .007), and the
  # pattern "parametric ANOVA" also matched "non-parametric ANOVA", so this
  # test passed on the opposite advice.
  set.seed(2)
  main_df <- data.frame(
    tlx_mental = rnorm(40),
    Video = factor(rep(c("A", "B"), each = 20)),
    DriverPosition = factor(rep(c("Left", "Right"), times = 20))
  )

  expect_message(
    checkAssumptionsForAnova(main_df, y = "tlx_mental", factors = c("Video", "DriverPosition")),
    "^You may take parametric ANOVA"
  )
})

test_that("reshape_data writes a reshaped Excel file", {
  skip_if_not_installed("readxl")
  skip_if_not_installed("writexl")

  toy <- data.frame(
    ID = c(1, 2),
    videoinfo1 = c("marker", "marker"),
    A = c(10, 11),
    videoinfo2 = c("marker", "marker"),
    B = c(20, 21),
    stringsAsFactors = FALSE
  )

  tmp_in <- tempfile(fileext = ".xlsx")
  tmp_out <- tempfile(fileext = ".xlsx")
  writexl::write_xlsx(toy, tmp_in)

  reshape_data(
    input_filepath = tmp_in,
    marker = "videoinfo",
    id_col = "ID",
    output_filepath = tmp_out
  )

  expect_true(file.exists(tmp_out) || any(grepl(paste0("^", tmp_out), list.files(dirname(tmp_out), full.names = TRUE))))
})

test_that("add_pareto_emoa_column marks pareto front points", {
  skip_if_not_installed("emoa")

  data <- data.frame(
    trust = c(1, 2, 3),
    predictability = c(3, 2, 1)
  )

  result <- add_pareto_emoa_column(data, objectives = c("trust", "predictability"))
  expect_true("PARETO_EMOA" %in% names(result))
  expect_equal(nrow(result), 3)
})

test_that("add_pareto_emoa_column excludes dominated points (minimization)", {
  skip_if_not_installed("emoa")

  data <- data.frame(
    trust = c(1, 2, 3, 3),
    predictability = c(3, 2, 1, 3)
  )

  result <- add_pareto_emoa_column(data, objectives = c("trust", "predictability"))
  # (3, 3) is dominated by every other point; the trade-off points remain
  expect_equal(result$PARETO_EMOA, c(TRUE, TRUE, TRUE, FALSE))

  # Single row is trivially on the front
  single <- add_pareto_emoa_column(data[1, ], objectives = c("trust", "predictability"))
  expect_true(single$PARETO_EMOA)
})

test_that("reshape_data rejects sections with unequal column counts", {
  skip_if_not_installed("readxl")
  skip_if_not_installed("writexl")

  toy <- data.frame(
    ID = c(1, 2),
    videoinfo1 = c("marker", "marker"),
    A = c(10, 11),
    B = c(12, 13),
    videoinfo2 = c("marker", "marker"),
    C = c(20, 21),
    stringsAsFactors = FALSE
  )

  tmp_in <- tempfile(fileext = ".xlsx")
  tmp_out <- tempfile(fileext = ".xlsx")
  writexl::write_xlsx(toy, tmp_in)

  expect_error(
    reshape_data(
      input_filepath = tmp_in,
      marker = "videoinfo",
      id_col = "ID",
      output_filepath = tmp_out
    ),
    "same number of columns"
  )
})

test_that("remove_outliers_REI calculates REI and flags", {
  df <- data.frame(var1 = c(1, 2, 3, 3), var2 = c(1, 3, 4, 3), var3 = c(1, 2, 5, 3))
  result <- remove_outliers_REI(df, header = FALSE, variables = "", range = c(1, 5))

  expect_true(all(c("REI", "Percentile", "Suspicious") %in% names(result)))
  expect_equal(nrow(result), nrow(df))
})

test_that("remove_outliers_REI validates inputs", {
  df <- data.frame(var1 = c(1, 2, 3))

  expect_error(
    remove_outliers_REI(df, header = TRUE, variables = ""),
    "Please input variables to consider!"
  )

  expect_error(
    remove_outliers_REI(df, header = FALSE, variables = "", range = c(1, 5)),
    "Not enough columns found with the given phrase."
  )
})

test_that("remove_outliers_REI validates and applies the range argument", {
  df <- data.frame(var1 = c(1, 2, 3), var2 = c(2, 3, 4))

  expect_error(
    remove_outliers_REI(df, header = FALSE, variables = "", range = 1),
    "length 2"
  )
  expect_error(
    remove_outliers_REI(df, header = FALSE, variables = "", range = c(5, 1)),
    "length 2"
  )

  df_out_of_range <- data.frame(var1 = c(1, 2, 99), var2 = c(1, 3, 4))
  expect_warning(
    remove_outliers_REI(df_out_of_range, header = FALSE, variables = "", range = c(1, 5)),
    "outside the declared Likert"
  )
})

test_that("remove_outliers_REI tolerates missing responses", {
  df <- data.frame(var1 = c(1, 2, NA), var2 = c(2, 3, 4), var3 = c(1, 1, 2))
  result <- remove_outliers_REI(df, header = FALSE, variables = "", range = c(1, 5))

  expect_false(any(is.na(result$REI)))
})

test_that(".fmt_df keeps whole degrees of freedom whole and rounds fractional ones", {
  # Integer dfs must not gain decimals...
  expect_equal(.fmt_df(2), "2")
  expect_equal(.fmt_df(108), "108")
  # ...Kenward-Roger floating-point noise must not leak into the text...
  expect_equal(.fmt_df(180.000000000002), "180")
  # ...and Greenhouse-Geisser / Welch dfs are rounded for display.
  expect_equal(.fmt_df(1.80875305770353), "1.81")
  expect_equal(.fmt_df(66.9238631350305), "66.92")
  # Non-numeric placeholders (e.g. "$\\infty$") pass through untouched.
  expect_equal(.fmt_df("$\\infty$"), "$\\infty$")
})

test_that(".f_values finds the F column whatever anova() named it", {
  # between-only (lm) ART fits name it "F value"...
  lm_tbl <- data.frame(`F value` = c(6.12, 5.01), check.names = FALSE)
  expect_equal(.f_values(lm_tbl), c(6.12, 5.01))
  # ...mixed (lmer) fits name it "F"
  lmer_tbl <- data.frame(F = c(7.55, 0.32), check.names = FALSE)
  expect_equal(.f_values(lmer_tbl), c(7.55, 0.32))
  # a table with neither yields NULL rather than erroring
  expect_null(.f_values(data.frame(Df = 1)))
})

test_that(".indefinite_article matches how the following word is read", {
  expect_equal(.indefinite_article("ANOVA"), "An")
  expect_equal(.indefinite_article("RM-ANOVA"), "An")
  expect_equal(.indefinite_article("MANOVA"), "An")
  expect_equal(.indefinite_article("F test"), "An") # spoken "eff"
  expect_equal(.indefinite_article("Friedman rank sum test"), "A")
  expect_equal(.indefinite_article("Wilcoxon signed rank test"), "A")
  expect_equal(.indefinite_article("Games-Howell"), "A")
  expect_equal(.indefinite_article(""), "A")
})

test_that(".indefinite_article hears the consonant in a vowel-initial word", {
  # "One-way analysis of means" is what statsExpressions calls a Welch ANOVA,
  # and it used to be reported as "An One-way analysis of means ...".
  expect_equal(.indefinite_article("One-way analysis of means"), "A")
  expect_equal(.indefinite_article("One-way analysis of means (not assuming equal variances)"), "A")
  expect_equal(.indefinite_article("One-sample t-test"), "A")
  expect_equal(.indefinite_article("once-corrected estimate"), "A")
  # the other "yoo" openings
  expect_equal(.indefinite_article("unique variance decomposition"), "A")
  expect_equal(.indefinite_article("uniform prior"), "A")
  expect_equal(.indefinite_article("European sample"), "A")
  expect_equal(.indefinite_article("usual approximation"), "A")

  # the words those rules must not swallow: these really are vowel-sounded
  expect_equal(.indefinite_article("unpaired Wilcoxon rank sum test"), "An")
  expect_equal(.indefinite_article("unadjusted p-value"), "An")
  expect_equal(.indefinite_article("uninformative prior"), "An")
  expect_equal(.indefinite_article("unidentified model"), "An")
  expect_equal(.indefinite_article("unimportant difference"), "An")
  expect_equal(.indefinite_article("onerous assumption"), "An")
  expect_equal(.indefinite_article("ordinal outcome"), "An")
})

test_that(".posthoc_test_phrase names the test and its correction", {
  # the names ggstatsplot actually reports across type/design combinations
  expect_equal(
    .posthoc_test_phrase("Games-Howell", "Holm"),
    "A Games-Howell post-hoc test (Holm-adjusted)"
  )
  expect_equal(
    .posthoc_test_phrase("Dunn", "Bonferroni"),
    "A Dunn post-hoc test (Bonferroni-adjusted)"
  )
  expect_equal(
    .posthoc_test_phrase("Yuen's trimmed means", "FDR"),
    "A Yuen's trimmed means post-hoc test (FDR-adjusted)"
  )
  expect_equal(
    .posthoc_test_phrase("Durbin-Conover", "Holm"),
    "A Durbin-Conover post-hoc test (Holm-adjusted)"
  )
  # the article follows how the name is read
  expect_equal(
    .posthoc_test_phrase("ANOVA-based", "Holm"),
    "An ANOVA-based post-hoc test (Holm-adjusted)"
  )
})

test_that(".posthoc_test_phrase claims nothing it was not told", {
  expect_equal(.posthoc_test_phrase(), "A post-hoc test")
  expect_equal(.posthoc_test_phrase(NA_character_, NA_character_), "A post-hoc test")
  expect_equal(.posthoc_test_phrase("Dunn"), "A Dunn post-hoc test")
  # "None" is an answer -- it means no correction, so none is named
  expect_equal(.posthoc_test_phrase("Dunn", "None"), "A Dunn post-hoc test")
  expect_equal(.posthoc_test_phrase("Dunn", "none"), "A Dunn post-hoc test")
  # a factor column must yield its label, not its integer code
  expect_equal(
    .posthoc_test_phrase(factor("Dunn", levels = c("Games-Howell", "Dunn"))),
    "A Dunn post-hoc test"
  )
  # test names reach LaTeX, so they are escaped
  expect_equal(.posthoc_test_phrase("Brunner_Munzel"), "A Brunner\\_Munzel post-hoc test")
})

test_that(".adjustment_is_none only answers when it was told something", {
  expect_true(.adjustment_is_none("None"))
  expect_true(.adjustment_is_none("none"))
  expect_false(.adjustment_is_none("Holm"))
  expect_false(.adjustment_is_none(NULL)) # absent column is not a claim
})

# -------------------------------------------------------------------------
# Pareto front direction
# -------------------------------------------------------------------------

# Four points in two objectives. Maximising both, (1,3), (2,2) and (3,1) are all
# non-dominated and (2,1) is dominated. Minimising both, the answer is the
# mirror image: (1,3) and (2,1) survive.
pareto_df <- function() {
  data.frame(a = c(1, 2, 3, 2), b = c(3, 2, 1, 1))
}


test_that("add_pareto_moocore_column minimises by default", {
  skip_if_not_installed("moocore")

  out <- add_pareto_moocore_column(pareto_df(), c("a", "b"))

  expect_equal(out$PARETO_MOOCORE, c(TRUE, FALSE, FALSE, TRUE))
})


test_that("add_pareto_moocore_column can maximise", {
  skip_if_not_installed("moocore")

  out <- add_pareto_moocore_column(pareto_df(), c("a", "b"), maximise = TRUE)

  expect_equal(out$PARETO_MOOCORE, c(TRUE, TRUE, TRUE, FALSE))
})


test_that("add_pareto_emoa_column can maximise, and agrees with moocore", {
  skip_if_not_installed("emoa")
  skip_if_not_installed("moocore")
  d <- pareto_df()

  expect_equal(
    add_pareto_emoa_column(d, c("a", "b"))$PARETO_EMOA,
    c(TRUE, FALSE, FALSE, TRUE)
  )
  expect_equal(
    add_pareto_emoa_column(d, c("a", "b"), maximise = TRUE)$PARETO_EMOA,
    c(TRUE, TRUE, TRUE, FALSE)
  )
  # The two backends must not disagree about the same front.
  set.seed(9)
  big <- data.frame(x = runif(40), y = runif(40), z = runif(40))
  objs <- c("x", "y", "z")
  for (m in list(FALSE, TRUE, c(TRUE, FALSE, TRUE))) {
    expect_equal(
      add_pareto_emoa_column(big, objs, maximise = m)$PARETO_EMOA,
      add_pareto_moocore_column(big, objs, maximise = m)$PARETO_MOOCORE,
      info = paste("maximise =", paste(m, collapse = ","))
    )
  }
})


test_that("a per-objective direction is honoured", {
  skip_if_not_installed("moocore")
  d <- pareto_df()

  # Maximise a, minimise b: only (3,1) is non-dominated.
  out <- add_pareto_moocore_column(d, c("a", "b"), maximise = c(TRUE, FALSE))

  expect_equal(out$PARETO_MOOCORE, c(FALSE, FALSE, TRUE, FALSE))
})


test_that("passing negated columns is equivalent to maximise = TRUE", {
  skip_if_not_installed("moocore")
  # The workaround this argument replaces must give the same answer.
  d <- pareto_df()
  negated <- data.frame(a = -d$a, b = -d$b)

  expect_equal(
    add_pareto_moocore_column(d, c("a", "b"), maximise = TRUE)$PARETO_MOOCORE,
    add_pareto_moocore_column(negated, c("a", "b"))$PARETO_MOOCORE
  )
})


test_that("a wrong-length maximise is rejected rather than silently truncated", {
  skip_if_not_installed("moocore")
  # moocore::is_nondominated() itself accepts three flags for two objectives and
  # quietly uses the first two, which would produce a plausible, wrong front.
  d <- pareto_df()

  expect_error(
    add_pareto_moocore_column(d, c("a", "b"), maximise = c(TRUE, FALSE, TRUE)),
    "3 entries but there are 2 objectives"
  )
  expect_error(
    add_pareto_emoa_column(d, c("a", "b"), maximise = c(TRUE, FALSE, TRUE)),
    "3 entries but there are 2 objectives"
  )
  expect_error(add_pareto_moocore_column(d, c("a", "b"), maximise = NA), "no NAs")
  expect_error(add_pareto_moocore_column(d, c("a", "b"), maximise = "yes"), "must be TRUE or FALSE")
})


test_that("the single-row shortcut still validates the direction", {
  skip_if_not_installed("moocore")
  one <- data.frame(a = 1, b = 2)

  expect_error(
    add_pareto_moocore_column(one, c("a", "b"), maximise = c(TRUE, FALSE, TRUE)),
    "3 entries"
  )
  expect_true(add_pareto_moocore_column(one, c("a", "b"), maximise = TRUE)$PARETO_MOOCORE)
})


# -------------------------------------------------------------------------
# Shared p-value / LaTeX-name helpers
# -------------------------------------------------------------------------

test_that(".fmt_p_number never rounds a p-value across a significance boundary", {
  expect_identical(
    .fmt_p_number(c(0.0496, 0.04996, 0.00996, 0.0995, 0.0501)),
    c("0.0496", "0.04996", "0.00996", "0.0995", "0.050")
  )
  # ordinary values keep three decimals, NA stays NA
  expect_identical(.fmt_p_number(c(0.234, NA)), c("0.234", NA_character_))
})

test_that(".fmt_p_macro uses the boundary-safe number and the minor macro", {
  expect_identical(.fmt_p_macro(0.0496), "\\p{0.0496}")
  expect_identical(.fmt_p_macro(0.0004), "\\pminor{0.001}")
  expect_identical(.fmt_p_macro(0.02, macro = "padj", minor_macro = "padjminor"), "\\padj{0.020}")
  expect_identical(.fmt_p_macro(NA), "\\p{NA}")
})

test_that("a p-value just below .05 gets a star and is printed below .05", {
  # The asterisk and the printed value must tell the same story: "0.050" next
  # to a "*" reads as a significant result at p = .05.
  expect_identical(.p_to_asterisk(0.04996), "*")
  expect_identical(.fmt_p_macro(0.04996), "\\p{0.04996}")
})

test_that(".tex_name makes a macro only of names that can safely become one", {
  withr::local_options(colleyRstats.name_macros = TRUE)
  expect_identical(
    .tex_name(c("Video", "time", "L", "small", "endurance", "tlx_mental", "sd")),
    c("\\Video{}", "time", "L", "small", "endurance", "tlx\\_mental", "sd")
  )
  withr::local_options(colleyRstats.name_macros = FALSE)
  expect_identical(.tex_name("Video"), "Video")
})

test_that(".bt quotes non-syntactic names for formulas and leaves others alone", {
  expect_identical(.bt("Mental Demand"), "`Mental Demand`")
  expect_identical(.bt(c("score", "tlx-mental")), c("score", "`tlx-mental`"))
  f <- stats::reformulate(.bt("Condition ID"), response = .bt("Mental Demand"))
  expect_identical(all.vars(f), c("Mental Demand", "Condition ID"))
})

test_that("expand_latex_macros expands \\mdn and \\iqr", {
  expect_identical(
    expand_latex_macros("(\\mdn{3.00}, \\iqr{1.50}, \\m{2.00})"),
    "($Mdn = 3.00$, $IQR = 1.50$, $M = 2.00$)"
  )
})

# -------------------------------------------------------------------------
# check_normality_by_group: between and within subjects
# -------------------------------------------------------------------------

test_that("between subjects, the per-group p-values are Holm-adjusted", {
  set.seed(11)
  d <- data.frame(g = rep(c("A", "B", "C"), each = 15), y = rnorm(45))

  res <- check_normality_by_group(d, "g", "y")
  tests <- attr(res, "tests")

  expect_identical(attr(res, "method"), "groupwise")
  expect_identical(attr(res, "p_adjust"), "holm")
  expect_true(all(tests$p_adjusted >= tests$p_value))
  expect_equal(tests$p_adjusted, stats::p.adjust(tests$p_value, "holm"))
})

test_that("a group of two values cannot be tested and counts as not normal", {
  d <- data.frame(g = c(rep("A", 15), "B", "B"), y = c(qnorm(ppoints(15)), 1, 2))

  res <- check_normality_by_group(d, "g", "y")

  expect_false(res)
  expect_identical(attr(res, "untestable"), "B")
})

test_that("a factor outcome is tested on its labels, not its level codes", {
  # Levels 1, 2, 3, 5: as.numeric() on the factor would test 1, 2, 3, 4.
  vals <- c(1, 1, 2, 2, 3, 3, 5, 5, 5, 5, 1, 2, 2, 3, 3, 3, 5, 5, 5, 1)
  d <- data.frame(g = rep(c("A", "B"), each = 10), y = factor(vals), y_num = vals)

  expect_equal(
    attr(check_normality_by_group(d, "g", "y"), "tests"),
    attr(check_normality_by_group(d, "g", "y_num"), "tests")
  )
})

within_df <- function(k = 2, n = 12, seed = 21) {
  set.seed(seed)
  d <- expand.grid(id = seq_len(n), cond = LETTERS[seq_len(k)])
  d$score <- rnorm(n, sd = 3)[d$id] + as.numeric(d$cond) + rnorm(nrow(d))
  d
}

test_that("within subjects with two conditions, the differences are tested", {
  d <- within_df(k = 2)

  res <- check_normality_by_group(d, "cond", "score", subject = "id")
  tests <- attr(res, "tests")
  diffs <- d$score[d$cond == "B"] - d$score[d$cond == "A"]

  expect_identical(attr(res, "method"), "differences")
  expect_identical(tests$group, "differences")
  expect_equal(tests$W, unname(stats::shapiro.test(diffs)$statistic))
})

test_that("within subjects with three conditions, the residuals are tested", {
  d <- within_df(k = 3)

  res <- check_normality_by_group(d, "cond", "score", subject = "id")
  tests <- attr(res, "tests")
  fit <- stats::lm(score ~ cond + factor(id), data = d)

  expect_identical(attr(res, "method"), "residuals")
  expect_equal(tests$W, unname(stats::shapiro.test(stats::residuals(fit))$statistic))
})

test_that("participants lacking a condition are dropped and reported", {
  d <- within_df(k = 3)
  d <- d[!(d$id == 4 & d$cond == "B"), ]
  d$score[d$id == 7 & d$cond == "C"] <- NA

  res <- check_normality_by_group(d, "cond", "score", subject = "id")

  expect_setequal(attr(res, "dropped_subjects"), c("4", "7"))
  expect_identical(attr(res, "tests")$n, 10L * 3L)
})

test_that("unused levels of a factor participant ID are not reported as dropped", {
  d <- within_df(k = 2, n = 6)
  d$id <- factor(d$id, levels = 1:8) # 7 and 8 have no rows at all

  res <- check_normality_by_group(d, "cond", "score", subject = "id")

  expect_length(attr(res, "dropped_subjects"), 0)
})

test_that("more than one row per participant and condition is an error", {
  d <- within_df(k = 2)
  expect_error(
    check_normality_by_group(rbind(d, d[1, ]), "cond", "score", subject = "id"),
    "More than one row per participant"
  )
})

test_that("the within-subjects result does not depend on row order", {
  d <- within_df(k = 3)
  set.seed(5)
  # three conditions (residuals) and two (differences)
  for (k_df in list(d, d[d$cond != "C", ])) {
    shuffled <- k_df[sample(nrow(k_df)), ]
    expect_equal(
      check_normality_by_group(k_df, "cond", "score", subject = "id"),
      check_normality_by_group(shuffled, "cond", "score", subject = "id")
    )
  }
})

# -------------------------------------------------------------------------
# check_homogeneity_by_group
# -------------------------------------------------------------------------

test_that("check_homogeneity_by_group handles spaces and numeric condition codes", {
  skip_if_not_installed("rstatix")
  set.seed(2)
  d <- data.frame(`Mental Demand` = rnorm(30), cond = rep(1:3, 10), check.names = FALSE)
  d$cond_f <- factor(d$cond)

  # used to fail with "unexpected symbol" (the space) and "not appropriate with
  # quantitative explanatory variables" (the numeric codes)
  res_num <- check_homogeneity_by_group(d, "cond", "Mental Demand")
  res_fac <- check_homogeneity_by_group(d, "cond_f", "Mental Demand")

  expect_true(is.logical(res_num))
  expect_identical(attr(res_num, "test"), attr(res_fac, "test"))
  expect_identical(attr(res_num, "test")$df1, 2L)
})

test_that("check_homogeneity_by_group names the Brown-Forsythe test it runs", {
  skip_if_not_installed("rstatix")
  skip_if_not_installed("car")
  set.seed(3)
  d <- data.frame(g = rep(c("A", "B", "C"), each = 12), y = rexp(36))

  res <- check_homogeneity_by_group(d, "g", "y")

  expect_identical(attr(res, "method"), "Brown-Forsythe test (median-centred Levene's test)")
  # ... and the statistic really is the median-centred one
  bf <- car::leveneTest(y ~ factor(g), data = d, center = stats::median)
  expect_equal(attr(res, "test")$statistic, bf[["F value"]][1])
})

test_that("check_homogeneity_by_group ignores the grouping of a grouped tibble", {
  skip_if_not_installed("rstatix")
  set.seed(4)
  d <- data.frame(block = rep(c("x", "y"), 18), g = rep(c("A", "B", "C"), each = 12), y = rnorm(36))

  expect_identical(
    attr(check_homogeneity_by_group(dplyr::group_by(d, block), "g", "y"), "test"),
    attr(check_homogeneity_by_group(d, "g", "y"), "test")
  )
})

# -------------------------------------------------------------------------
# checkAssumptionsForAnova
# -------------------------------------------------------------------------

test_that("checkAssumptionsForAnova treats numeric condition codes as a factor", {
  skip_if_not_installed("rstatix")
  # Means 0, 10, 0: as a linear covariate the codes leave bimodal residuals and
  # the old code advised the non-parametric test; as a factor all is normal.
  d <- data.frame(y = c(qnorm(ppoints(20)), qnorm(ppoints(20)) + 10, qnorm(ppoints(20))),
                  g = rep(1:3, each = 20))
  d_f <- transform(d, g = factor(g))

  res_num <- suppressMessages(checkAssumptionsForAnova(d, "y", "g"))
  res_fac <- suppressMessages(checkAssumptionsForAnova(d_f, "y", "g"))

  expect_true(attr(res_num, "parametric"))
  expect_identical(as.character(res_num), as.character(res_fac))
})

test_that("checkAssumptionsForAnova names the tests it ran", {
  skip_if_not_installed("rstatix")
  set.seed(2)
  d <- data.frame(
    tlx_mental = rnorm(40),
    Video = factor(rep(c("A", "B"), each = 20)),
    DriverPosition = factor(rep(c("Left", "Right"), times = 20))
  )

  expect_message(
    res <- checkAssumptionsForAnova(d, "tlx_mental", c("Video", "DriverPosition")),
    "^You may take parametric ANOVA.*Shapiro-Wilk on the residuals of tlx_mental ~ Video \\* DriverPosition.*Brown-Forsythe"
  )
  expect_true(attr(res, "parametric"))
  expect_identical(attr(res, "design"), "between")
  expect_named(attr(res, "method"), c("residuals", "groupwise", "homogeneity"))
  expect_identical(nrow(attr(res, "groupwise")), 4L)
  expect_identical(attr(res, "homogeneity")$df1, 3L)
})

test_that("checkAssumptionsForAnova reports an untestable cell instead of crashing", {
  skip_if_not_installed("rstatix")
  set.seed(4)
  # unbalanced 2 x 2 whose a2:b2 cell has only two observations
  d <- data.frame(
    y = rnorm(12),
    a = factor(rep(c("a1", "a2"), each = 6)),
    b = factor(c(rep("b1", 3), rep("b2", 3), rep("b1", 4), rep("b2", 2)))
  )

  expect_message(
    res <- checkAssumptionsForAnova(d, "y", c("a", "b")),
    "could not be assessed for cell\\(s\\) a2:b2"
  )
  expect_false(attr(res, "parametric"))
  gw <- attr(res, "groupwise")
  expect_false(gw$testable[gw$group == "a2:b2"])
})

test_that("checkAssumptionsForAnova tests within-subject residuals when given a subject", {
  skip_if_not_installed("rstatix")
  set.seed(5)
  # Participants fall into two clusters far apart: the raw scores (and the
  # residuals of a model without participants) are bimodal, the residuals after
  # removing each participant's level are normal.
  d <- expand.grid(id = 1:20, A = c("a1", "a2"), B = c("b1", "b2", "b3"))
  offset <- rep(c(-10, 10), each = 10)
  d$y <- offset[d$id] + as.numeric(d$A) + rnorm(nrow(d))

  res_within <- suppressMessages(checkAssumptionsForAnova(d, "y", c("A", "B"), subject = "id"))
  res_between <- suppressMessages(checkAssumptionsForAnova(d, "y", c("A", "B")))

  expect_true(attr(res_within, "parametric"))
  expect_identical(attr(res_within, "design"), "within")
  expect_match(attr(res_within, "method")[["residuals"]], "y ~ A \\* B \\+ id")
  expect_null(attr(res_within, "homogeneity")) # sphericity, not Levene
  expect_match(res_within, "sphericity")
  expect_false(attr(res_between, "parametric"))

  expect_error(
    checkAssumptionsForAnova(rbind(d, d[1, ]), "y", c("A", "B"), subject = "id"),
    "More than one row per participant"
  )
})

test_that("checkAssumptionsForAnova checks between factors of a mixed design per within cell", {
  skip_if_not_installed("rstatix")
  set.seed(6)
  d <- expand.grid(id = 1:16, time = c("t1", "t2", "t3"))
  d$group <- ifelse(d$id <= 8, "g1", "g2")
  d$`Mental Demand` <- rnorm(16)[d$id] + rnorm(nrow(d))

  res <- suppressMessages(
    checkAssumptionsForAnova(d, "Mental Demand", c("group", "time"), subject = "id")
  )

  expect_identical(attr(res, "design"), "mixed")
  hom <- attr(res, "homogeneity")
  expect_identical(hom$cell, c("t1", "t2", "t3"))
  expect_equal(hom$p_adjusted, stats::p.adjust(hom$p, "holm"))
})

# -------------------------------------------------------------------------
# debug_contr_error
# -------------------------------------------------------------------------

test_that("debug_contr_error drops the unobserved levels of every factor", {
  # A character column before the factor shifted `fctr[-ind1]` by one, so the
  # factor itself escaped droplevels() and its empty level "b" counted.
  dat <- data.frame(
    id = 1:4,
    ch = c("x", "y", "x", "y"),
    f = factor(rep("a", 4), levels = c("a", "b"))
  )

  res <- debug_contr_error(dat)

  expect_identical(res$nlevels[["f"]], 1L)
  expect_identical(res$levels$f, "a")
  expect_identical(res$nlevels[["ch"]], 2L)
})

test_that("debug_contr_error accepts ordered factors and date-times", {
  dat <- data.frame(
    o = factor(c("lo", "hi", "lo"), levels = c("lo", "mid", "hi"), ordered = TRUE),
    t = as.POSIXct(c("2020-01-01", "2020-01-02", "2020-01-03"), tz = "UTC")
  )
  expect_identical(debug_contr_error(dat)$nlevels[["o"]], 2L)
})

# -------------------------------------------------------------------------
# Pareto fronts: ties and missing values
# -------------------------------------------------------------------------

test_that("both Pareto backends keep every copy of a tied non-dominated point", {
  skip_if_not_installed("emoa")
  skip_if_not_installed("moocore")
  # Rows 1 and 2 are identical and non-dominated; moocore's default
  # keep_weakly = FALSE marked only the first of them.
  tie <- data.frame(a = c(1, 1, 2, 3), b = c(1, 1, 0.5, 3))

  emoa_front <- add_pareto_emoa_column(tie, c("a", "b"))$PARETO_EMOA
  moocore_front <- add_pareto_moocore_column(tie, c("a", "b"))$PARETO_MOOCORE

  expect_identical(moocore_front, c(TRUE, TRUE, TRUE, FALSE))
  expect_identical(emoa_front, moocore_front)

  # rating-scale data are full of ties; the two must agree on them too
  set.seed(12)
  likert <- data.frame(x = sample(1:5, 60, TRUE), y = sample(1:5, 60, TRUE), z = sample(1:5, 60, TRUE))
  for (m in list(FALSE, TRUE, c(TRUE, FALSE, TRUE))) {
    expect_identical(
      add_pareto_emoa_column(likert, c("x", "y", "z"), maximise = m)$PARETO_EMOA,
      add_pareto_moocore_column(likert, c("x", "y", "z"), maximise = m)$PARETO_MOOCORE
    )
  }
})

test_that("add_pareto_emoa_column accepts integer rating columns", {
  skip_if_not_installed("emoa")
  # emoa's C code rejected an integer matrix ("not a real matrix")
  d <- data.frame(a = c(1L, 2L, 3L, 2L), b = c(3L, 2L, 1L, 1L))
  expect_identical(add_pareto_emoa_column(d, c("a", "b"))$PARETO_EMOA, c(TRUE, FALSE, FALSE, TRUE))
})

test_that("the moocore fallback without keep_weakly keeps ties too", {
  skip_if_not_installed("moocore")
  m <- matrix(c(1, 1, 2, 3, 1, 1, 0.5, 3), ncol = 2)
  original <- moocore::is_nondominated
  local_mocked_bindings(
    # an old moocore: no keep_weakly argument, only the first copy survives
    is_nondominated = function(x, maximise = FALSE) {
      original(x, maximise = maximise, keep_weakly = FALSE)
    },
    .package = "moocore"
  )
  expect_false("keep_weakly" %in% names(formals(moocore::is_nondominated)))
  expect_identical(.moocore_nondominated(m, c(FALSE, FALSE)), c(TRUE, TRUE, TRUE, FALSE))
})

test_that("rows with a missing objective get NA and do not distort the front", {
  skip_if_not_installed("emoa")
  skip_if_not_installed("moocore")
  d <- data.frame(a = c(1, NA, 3, 2), b = c(3, 2, 1, 1))

  expect_warning(
    emoa_front <- add_pareto_emoa_column(d, c("a", "b"))$PARETO_EMOA,
    "missing objective"
  )
  expect_warning(
    moocore_front <- add_pareto_moocore_column(d, c("a", "b"))$PARETO_MOOCORE,
    "missing objective"
  )
  # among the complete rows, (1,3) and (2,1) are non-dominated; emoa used to
  # report (1,3) as dominated because of the NA row
  expect_identical(emoa_front, c(TRUE, NA, FALSE, TRUE))
  expect_identical(moocore_front, emoa_front)
})

# -------------------------------------------------------------------------
# remove_outliers_REI
# -------------------------------------------------------------------------

test_that("the REI is computed over the items a respondent answered", {
  # The same answer distribution -- each of five options equally often --
  # must give the same entropy whether 10 items were answered or 5.
  items <- rbind(
    c(1, 1, 2, 2, 3, 3, 4, 4, 5, 5),
    c(1, 2, 3, 4, 5, NA, NA, NA, NA, NA),
    c(1, 1, 1, 1, 1, 1, 1, 1, 2, 2)
  )
  d <- as.data.frame(items)

  res <- remove_outliers_REI(d, header = FALSE)

  expect_equal(res$REI[1], log10(5))
  expect_equal(res$REI[2], res$REI[1])
  expect_equal(res$REI[3], -(0.8 * log10(0.8) + 0.2 * log10(0.2)))
})

test_that("a respondent without any answer gets NA, not the minimum REI", {
  d <- data.frame(q1 = c(1, 2, NA, 4), q2 = c(1, 3, NA, 4), q3 = c(2, 4, NA, 4))
  res <- remove_outliers_REI(d, header = FALSE)

  expect_true(is.na(res$REI[3]))
  expect_true(is.na(res$Suspicious[3]))
  expect_false(anyNA(res$REI[-3]))
})

test_that("remove_outliers_REI selects variables by exact name", {
  d <- data.frame(
    `G01Q01[SQ001]` = c(1, 2, 3, 3), `G01Q01[SQ002]` = c(1, 3, 3, 5),
    q.1 = c(1, 2, 2, 4), q.2 = c(2, 2, 5, 4), qx1 = c(5, 5, 5, 5),
    check.names = FALSE
  )

  # brackets used to be read as a regex character class: no column matched
  res <- remove_outliers_REI(d, header = TRUE, variables = c("G01Q01[SQ001]", "G01Q01[SQ002]"))
  expect_identical(setdiff(names(res), c("REI", "Percentile", "Suspicious")),
                   c("G01Q01[SQ001]", "G01Q01[SQ002]"))

  # "q.1" used to match "qx1" as well
  res_dot <- remove_outliers_REI(d, header = TRUE, variables = "q.1,q.2")
  expect_false("qx1" %in% names(res_dot))

  expect_warning(
    remove_outliers_REI(d, header = TRUE, variables = c("q.1", "q.2", "nope")),
    "not found in `df` and ignored: 'nope'"
  )
})

test_that("remove_outliers_REI flags nobody when every REI is the same", {
  d <- data.frame(q1 = c(1, 1, 1), q2 = c(2, 2, 2), q3 = c(1, 1, 1))

  expect_warning(res <- remove_outliers_REI(d, header = FALSE), "same REI")
  expect_true(all(is.na(res$Percentile)))
  expect_identical(res$Suspicious, c("No", "No", "No"))
})

test_that("remove_outliers_REI warns about non-response columns with header = FALSE", {
  d <- data.frame(
    pid = c("p1", "p2", "p3", "p4"),
    q1 = c(1, 2, 3, 3), q2 = c(1, 3, 4, 3), q3 = c(1, 2, 5, 3)
  )
  expect_warning(remove_outliers_REI(d, header = FALSE), "Non-numeric column 'pid'")

  d_num_id <- transform(d, pid = c(101, 102, 103, 104))
  expect_warning(
    remove_outliers_REI(d_num_id, header = FALSE, range = c(1, 5)),
    "outside the declared Likert `range` \\[1, 5\\] were found in 'pid'"
  )

  # selecting the items explicitly is silent
  expect_silent(remove_outliers_REI(d, header = TRUE, variables = c("q1", "q2", "q3")))
})

# -------------------------------------------------------------------------
# Effect sizes from p-values
# -------------------------------------------------------------------------

test_that("rFromWilcoxAdjusted is deprecated but keeps its old value", {
  set.seed(1)
  d <- data.frame(group = rep(c("A", "B"), each = 15), value = c(rnorm(15, 0.6), rnorm(15)))
  w <- stats::wilcox.test(value ~ group, data = d, exact = FALSE)

  lifecycle::expect_deprecated(
    res <- suppressMessages(rFromWilcoxAdjusted(w, N = 30, adjustFactor = 6))
  )
  expect_equal(res$r, abs(qnorm(min(w$p.value * 6, 1) / 2)) / sqrt(30))
  # which is smaller than the effect size it pretends to adjust
  expect_lt(res$r, suppressMessages(rFromWilcox(w, N = 30))$r)
})

test_that("rFromWilcox does not halve a one-sided p-value", {
  set.seed(1)
  x <- rnorm(15, 0.6)
  y <- rnorm(15)
  w_two <- stats::wilcox.test(x, y, exact = FALSE)
  w_one <- stats::wilcox.test(x, y, exact = FALSE, alternative = "greater")

  r_two <- suppressMessages(rFromWilcox(w_two, N = 30))
  r_one <- suppressMessages(rFromWilcox(w_one, N = 30))

  expect_equal(r_one$z, qnorm(w_one$p.value))
  # both p-values describe the same |z|, so r must not change
  expect_equal(r_one$r, r_two$r)

  withr::local_options(lifecycle_verbosity = "quiet")
  r_adj <- suppressMessages(rFromWilcoxAdjusted(w_one, N = 30, adjustFactor = 1))
  expect_equal(r_adj$r, r_two$r)
})

test_that("rFromNPAV honours a one-sided alternative and warns for omnibus F tests", {
  r_two <- suppressMessages(rFromNPAV(0.04, N = 100))
  r_one <- suppressMessages(rFromNPAV(0.02, N = 100, alternative = "greater"))
  expect_equal(r_one$r, r_two$r)
  expect_equal(r_one$z, qnorm(0.02))

  expect_warning(
    suppressMessages(rFromNPAV(0.02, N = 180, df1 = 2)),
    "single-df"
  )
  expect_no_warning(suppressMessages(rFromNPAV(0.02, N = 180, df1 = 1)))
})

# -------------------------------------------------------------------------
# not_empty and reshape_data
# -------------------------------------------------------------------------

test_that("not_empty rejects a data frame without rows", {
  zero_rows <- data.frame(a = numeric(0), b = character(0))
  expect_error(not_empty(zero_rows), "`zero_rows` must not be empty")
  expect_error(not_empty(tibble::tibble(a = numeric(0))), "must not be empty")
  expect_true(not_empty(data.frame(a = 1)))
})

test_that("reshape_data repeats the columns before the first marker", {
  skip_if_not_installed("readxl")
  skip_if_not_installed("writexl")

  # "age" precedes the first marker: it belongs to the participant, and used to
  # be stacked as a slice (renaming every rating column "age").
  toy <- data.frame(
    ID = c(1, 2),
    age = c(30, 40),
    videoinfo1 = c("marker", "marker"),
    rating = c(10, 11),
    videoinfo2 = c("marker", "marker"),
    rating2 = c(20, 21),
    stringsAsFactors = FALSE
  )
  tmp_in <- tempfile(fileext = ".xlsx")
  tmp_out <- tempfile(fileext = ".xlsx")
  writexl::write_xlsx(toy, tmp_in)

  reshape_data(tmp_in, marker = "videoinfo", id_col = "ID", output_filepath = tmp_out)
  out <- as.data.frame(readxl::read_excel(tmp_out))

  expect_identical(names(out), c("ID", "age", "rating"))
  expect_equal(out$ID, c(1, 2, 1, 2))
  expect_equal(out$age, c(30, 40, 30, 40))
  expect_equal(out$rating, c(10, 11, 20, 21))
})


test_that("every within-subjects entry point analyses the same participants", {
  # One shared rule (.complete_within) decides who is analysed; before 0.3.0
  # each entry point had its own copy, and checkAssumptionsForAnova() kept
  # participants the others dropped.
  set.seed(5)
  d <- data.frame(id = rep(1:12, each = 3), cond = rep(c("A", "B", "C"), 12))
  d$y <- rnorm(12)[d$id] + rnorm(36)
  d$y[d$id == 2 & d$cond == "B"] <- NA       # a missing outcome
  d <- d[!(d$id == 5 & d$cond == "C"), ]     # a missing row
  d$id[d$id == 9 & d$cond == "A"] <- NA      # a row without an ID
  expected <- setdiff(as.character(1:12), c("2", "5", "9"))

  norm <- check_normality_by_group(d, "cond", "y", subject = "id")
  expect_setequal(attr(norm, "dropped_subjects"), c("2", "5", "9"))
  expect_equal(attr(norm, "tests")$n, length(expected) * 3)

  prep <- suppressMessages(.prepare_within_data(d, "cond", "y", "id"))
  expect_setequal(unique(as.character(prep$data$id)), expected)
  expect_setequal(prep$dropped_subjects, c("2", "5", "9"))

  post <- .posthoc_sample(d, "cond", "y", subject = "id")
  expect_setequal(unique(post$.block), expected)

  advice <- suppressMessages(checkAssumptionsForAnova(d, "y", "cond", subject = "id"))
  expect_equal(attr(advice, "residuals")$n, length(expected) * 3)
})

test_that(".fmt_p_number truncates when 8 digits still round onto a boundary", {
  expect_identical(.fmt_p_number(0.0499999999), "0.04999999")
  expect_identical(.fmt_p_number(0.00999999999), "0.00999999")
  expect_identical(.fmt_p_number(0.05), "0.050")
})

test_that("a two-level within factor is checked on the differences, not mirrored residuals", {
  # Each participant's two residuals of y ~ cond + id are +e and -e: a
  # symmetrised sample that hides the skew of the differences.
  set.seed(2)
  n <- 30
  d <- data.frame(id = rep(1:n, 2), cond = rep(c("A", "B"), each = n))
  base <- rnorm(n)
  d$y <- c(base, base + rexp(n))
  advice <- suppressMessages(checkAssumptionsForAnova(d, "y", "cond", subject = "id"))
  expect_match(attr(advice, "method")[["residuals"]], "per-participant differences")
  expect_false(attr(advice, "parametric"))
  diffs <- .paired_differences(d, "y", "cond", "id")
  expect_equal(unname(diffs), d$y[d$cond == "B"] - d$y[d$cond == "A"])
  expect_equal(attr(advice, "residuals")$W, unname(stats::shapiro.test(diffs)$statistic))
  # the same test as check_normality_by_group()
  norm <- check_normality_by_group(d, "cond", "y", subject = "id")
  expect_equal(attr(norm, "tests")$W, attr(advice, "residuals")$W)
})