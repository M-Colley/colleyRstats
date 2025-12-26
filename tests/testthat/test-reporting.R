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
    "NPVA found a significant"
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
  skip_if_not_installed("ggstatsplot")

  plt <- ggstatsplot::ggbetweenstats(mtcars, am, mpg)
  expect_message(
    reportggstatsplot(plt, iv = "am", dv = "mpg"),
    "found"
  )
})

test_that("reportggstatsplotPostHoc reports significant differences", {
  skip_if_not_installed("ggstatsplot")

  plt <- ggstatsplot::ggbetweenstats(mtcars, am, mpg)
  expect_message(
    reportggstatsplotPostHoc(data = mtcars, p = plt, iv = "am", dv = "mpg"),
    "post-hoc test"
  )
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
