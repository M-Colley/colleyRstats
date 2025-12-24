test_that("normalize scales values correctly", {
  # Test standard scaling 1-5 to 0-1
  input <- c(1, 2, 3, 4, 5)
  output <- normalize(input, 1, 5, 0, 1)

  expect_equal(output, c(0, 0.25, 0.5, 0.75, 1))

  # Test with single value
  expect_equal(normalize(10, 0, 100, 0, 1), 0.1)
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

test_that("not_empty throws error on NULL or NA", {
  expect_error(not_empty(NULL))
  expect_error(not_empty(NA))
  expect_true(not_empty(5))
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
  skip_if_not_installed("rstatix")
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
