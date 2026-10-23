test_that("fit plots reuse stored inference and analyzed rows without testing again", {
  set.seed(82)
  d <- data.frame(condition = factor(rep(c("A", "B"), each = 25)), y = rnorm(50))
  d$y[1] <- NA_real_
  fit <- suppressMessages(fit_recommended(d, "y", "condition", outcome_type = "continuous", verbose = FALSE))
  expect_true(nrow(fit$anova) > 0L)
  # An obviously different stored result makes independent re-testing visible.
  fit$anova$p[1] <- 0.0496
  local_mocked_bindings(
    recommend_test = function(...) stop("must not select another test"),
    .omnibus_table = function(...) stop("must not compute another test"),
    check_normality_by_group = function(...) stop("must not check assumptions again")
  )
  p <- plot_fit(fit, xlabels = c("Control", "Treatment"), ylab = "Measured score")
  expect_s3_class(p, "ggplot")
  expect_equal(nrow(p$data), 49L)
  expect_match(p$labels$subtitle, fit$recommendation$recommendation, fixed = TRUE)
  expect_match(p$labels$subtitle, "p = 0.0496", fixed = TRUE)
  expect_equal(nrow(ggplot2::layer_data(p, 2)), 49L)
  expect_identical(ggplot2::ggplot_build(p)$layout$panel_params[[1]]$x$get_labels(),
                   c("Control", "Treatment"))
  expect_identical(p$labels$y, "Measured score")
  expect_false(grepl("p =", plot_fit(fit, show_test = FALSE)$labels$subtitle, fixed = TRUE))
})


test_that("plots distinguish unavailable inference from a nonsignificant result", {
  set.seed(12)
  d <- data.frame(condition = factor(rep(c("A", "B"), each = 20)), y = rnorm(40))
  fit <- suppressMessages(fit_recommended(d, "y", "condition", outcome_type = "continuous", verbose = FALSE))
  stored <- fit$anova

  # A saved analysis may have no omnibus table (for an unsupported test) or an
  # unestimable p-value. Neither should become an invented test of the plot.
  local_mocked_bindings(.omnibus_table = function(...) stop("must not compute another test"))
  for (table in list(NULL, stored[FALSE, , drop = FALSE])) {
    fit$anova <- table
    p <- plot_fit(fit)
    expect_match(p$labels$subtitle, "No omnibus test was available.", fixed = TRUE)
    expect_false(grepl("p =|p <", p$labels$subtitle))
    expect_false(grepl("Tests are from the fitted model", p$labels$caption, fixed = TRUE))
    expect_equal(nrow(p$data), nrow(fit$data))
  }
  fit$anova <- stored
  fit$anova$p[] <- NA_real_
  p <- plot_fit(fit)
  expect_match(p$labels$subtitle, "p unavailable", fixed = TRUE)
  expect_false(grepl("p =|p <", p$labels$subtitle))
  expect_match(p$labels$subtitle, colleyRstats:::.fmt_num(stored$statistic[[1]]), fixed = TRUE)
})


test_that("plots retain a failed model's convergence caution", {
  d <- data.frame(time = seq(-10, 10, length.out = 200))
  d$response <- as.integer(d$time > 0)
  fit <- suppressWarnings(suppressMessages(fit_recommended(d, "response", "time",
    outcome_type = "binary", contrasts = FALSE, verbose = FALSE)))
  expect_false(fit$converged)
  p <- plot_fit(fit)
  expect_match(gsub("[[:space:]]+", " ", p$labels$caption),
               "The model did not converge cleanly.", fixed = TRUE)
  expect_identical(p$data$.y, fit$data$response)
  expect_equal(sum(ggplot2::layer_data(p, 1)$n), nrow(fit$data))
})


test_that("clustered fit plots display cluster means without changing inference", {
  skip_if_not_installed("lme4")
  set.seed(7)
  d <- expand.grid(trial = 1:3, condition = factor(c("A", "B")), id = factor(1:12))
  d$y <- rnorm(12)[as.integer(d$id)] + as.integer(d$condition) + rnorm(nrow(d))
  fit <- suppressWarnings(suppressMessages(fit_recommended(d, "y", "condition", cluster = "id",
    outcome_type = "continuous", random_slopes = character(0), verbose = FALSE)))
  p <- plot_fit(fit)
  expect_equal(nrow(p$data), 24L)
  expect_equal(sort(p$data$.y), sort(stats::aggregate(y ~ condition + id, data = fit$data, mean)$y))
  expect_match(p$labels$caption, "cluster means", fixed = TRUE)
  expect_match(p$labels$subtitle, fit$recommendation$recommendation, fixed = TRUE)
})


test_that("ordinal fit plots preserve response categories instead of averaging them", {
  skip_if_not_installed("ordinal")
  set.seed(31)
  d <- data.frame(condition = factor(rep(c("A", "B"), each = 40)),
                  y = ordered(sample(c("low", "medium", "high"), 80, TRUE),
                              levels = c("low", "medium", "high")))
  fit <- suppressMessages(fit_recommended(d, "y", "condition", contrasts = FALSE, verbose = FALSE))
  p <- plot_fit(fit)
  expect_identical(p$data$.y, fit$data$y)
  expect_equal(sum(ggplot2::layer_data(p, 1)$n), nrow(fit$data))
})


test_that("numeric predictors stay numeric and fit plots validate their arguments", {
  set.seed(23)
  d <- data.frame(time = seq_len(35), y = rnorm(35))
  fit <- suppressMessages(fit_recommended(d, "y", "time", outcome_type = "continuous", verbose = FALSE))
  expect_identical(plot_fit(fit)$data$.x, fit$data$time)
  expect_error(plot_fit(fit, x = "missing"), "fitted predictors")
  expect_error(plot_fit(fit, xlabels = letters[1:3]), "one label")
  expect_error(plot_fit(fit, show_test = NA), "TRUE or FALSE")
  expect_error(plot_fit(list()), "colley_fit")
  fit$data <- NULL
  expect_error(plot_fit(fit), "refit")
})
