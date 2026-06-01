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
    "NPAV found a significant"
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
  plt <- ggstatsplot::ggbetweenstats(mtcars, am, mpg)
  expect_message(
    reportggstatsplotPostHoc(data = mtcars, p = plt, iv = "am", dv = "mpg"),
    "post-hoc test"
  )
})

test_that("reportDunnTest and reportDunnTestTable handle significant findings", {
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
