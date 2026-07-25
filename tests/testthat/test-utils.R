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

  # Create obviously non-normal data (e.g., all identical values or extreme skew)
  df_skew <- data.frame(
    group = rep(c("A", "B"), each = 20),
    value = rep(1:5, 8) # Uniform-ish / discrete
  )
  # Modify one group to be extremely non-normal (constant)
  df_skew$value[df_skew$group == "A"] <- 1

  # Should return FALSE because variance is 0 or distribution is flat
  expect_false(check_normality_by_group(df_skew, "group", "value"))
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
  df <- data.frame(var1 = c(1, 2, 3), var2 = c(2, 3, 4), other = c(9, 9, 9))

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
  base_values <- qnorm(seq(0.1, 0.9, length.out = 10))
  main_df <- data.frame(
    tlx_mental = rep(base_values, times = 4),
    Video = factor(rep(c("A", "B"), each = 20)),
    DriverPosition = factor(rep(c("Left", "Right"), times = 20))
  )

  expect_message(
    checkAssumptionsForAnova(main_df, y = "tlx_mental", factors = c("Video", "DriverPosition")),
    "parametric ANOVA"
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
  df <- data.frame(var1 = c(1, 2, 3), var2 = c(2, 3, 4))
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

  df_out_of_range <- data.frame(var1 = c(1, 2, 99), var2 = c(2, 3, 4))
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
