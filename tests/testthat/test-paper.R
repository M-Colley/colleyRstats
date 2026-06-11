test_that("latex_preamble emits every macro the reporters use", {
  macros <- suppressMessages(latex_preamble())

  required <- c(
    "\\F", "\\p", "\\pminor", "\\padj", "\\padjminor",
    "\\m", "\\sd", "\\df", "\\chisq", "\\rankbiserial", "\\effectsize"
  )
  for (cmd in required) {
    expect_true(
      any(grepl(paste0("\\newcommand{", cmd, "}"), macros, fixed = TRUE)),
      label = paste("definition for", cmd)
    )
  }
})

test_that("latex_preamble writes the macros to a file", {
  path <- file.path(tempdir(), "preamble-test", "macros.tex")
  suppressMessages(latex_preamble(path))

  expect_true(file.exists(path))
  expect_true(any(grepl("\\rankbiserial", readLines(path), fixed = TRUE)))
  unlink(dirname(path), recursive = TRUE)
})

test_that("formatters honor the APA leading-zero option", {
  old <- options(colleyRstats.leading_zero = FALSE)
  on.exit(options(old), add = TRUE)

  expect_equal(colleyRstats:::.fmt_bounded(0.033, 3), ".033")
  expect_equal(colleyRstats:::.fmt_bounded(-0.5), "-.50")
  expect_equal(colleyRstats:::.fmt_p_macro(0.033), "\\p{.033}")
  expect_equal(colleyRstats:::.fmt_p_macro(0.0001), "\\pminor{.001}")
  # Unbounded statistics (means, F values) keep their leading zero
  expect_equal(colleyRstats:::.fmt_num(0.5), "0.50")

  options(colleyRstats.leading_zero = TRUE)
  expect_equal(colleyRstats:::.fmt_bounded(0.033, 3), "0.033")
  expect_equal(colleyRstats:::.fmt_p_macro(0.033), "\\p{0.033}")
})

test_that(".fmt_p_macro supports the adjusted-p macros", {
  expect_equal(colleyRstats:::.fmt_p_macro(0.02, macro = "padj", minor_macro = "padjminor"), "\\padj{0.020}")
  expect_equal(colleyRstats:::.fmt_p_macro(0.0002, macro = "padj", minor_macro = "padjminor"), "\\padjminor{0.001}")
})

test_that("sink_to writes all reported sentences to a .tex file", {
  model <- data.frame(
    Effect = c("Video", "gesture:eHMI"),
    Df = c(1, 1),
    `F value` = c(6.12, 5.01),
    `Pr(>F)` = c(0.033, 0.045),
    Df.res = c(10, 10),
    check.names = FALSE
  )

  path <- file.path(tempdir(), "sink-test", "results.tex")
  suppressMessages(reportART(model, dv = "mental demand", sink_to = path))

  expect_true(file.exists(path))
  content <- paste(readLines(path), collapse = "\n")
  expect_match(content, "Video")
  expect_match(content, "gesture")
  unlink(dirname(path), recursive = TRUE)
})

test_that("reportDunnTest invisibly returns its sentences", {
  skip_if_not_installed("FSA")

  d <- FSA::dunnTest(Sepal.Length ~ Species, data = iris, method = "holm")
  result <- suppressMessages(reportDunnTest(d, data = iris, iv = "Species", dv = "Sepal.Length"))

  expect_true(is.character(result))
  expect_gt(length(result), 0)
  expect_match(result[1], "post-hoc test")
})

test_that("save_paper_figure writes a file with column presets", {
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(factor(cyl), mpg)) +
    ggplot2::geom_boxplot()

  path <- file.path(tempdir(), "fig-test", "fig.pdf")
  suppressMessages(save_paper_figure(p, path, columns = 1))
  expect_true(file.exists(path))
  unlink(dirname(path), recursive = TRUE)

  expect_error(save_paper_figure(p, "x.pdf", columns = 3), "must be 1")
})

test_that("assumption_methods_text justifies parametric and non-parametric choices", {
  # Deterministically normal data (normal quantiles)
  d_normal <- data.frame(
    g = rep(c("A", "B"), each = 20),
    v = rep(qnorm(seq(0.05, 0.95, length.out = 20)), times = 2)
  )
  expect_message(
    txt <- assumption_methods_text(d_normal, x = "g", y = "v"),
    "parametric tests were used"
  )
  expect_match(txt, "Shapiro--Wilk", fixed = TRUE)

  # Deterministically skewed data
  d_skew <- data.frame(
    g = rep(c("A", "B"), each = 20),
    v = rep((1:20)^4, times = 2)
  )
  txt_skew <- suppressMessages(assumption_methods_text(d_skew, x = "g", y = "v"))
  expect_match(txt_skew, "non-parametric tests were used")
  expect_match(txt_skew, "W =", fixed = TRUE)
})

test_that("assumption_methods_text can include Levene's test", {
  skip_if_not_installed("rstatix")

  set.seed(7)
  d <- data.frame(
    g = factor(rep(c("A", "B"), each = 20)),
    v = rnorm(40)
  )
  txt <- suppressMessages(assumption_methods_text(d, x = "g", y = "v", include_homogeneity = TRUE))
  expect_match(txt, "Levene")
})

test_that("cite_methods prints boilerplate and BibTeX", {
  skip_if_not_installed("ARTool")

  out <- suppressMessages(cite_methods("art"))
  expect_true(any(grepl("Aligned Rank Transform", out)))
  expect_true(any(grepl("^@", out)))

  out_plain <- suppressMessages(cite_methods("art", bibtex = FALSE))
  expect_false(any(grepl("^@", out_plain)))

  expect_error(cite_methods("nosuchmethod"), "Unknown method")
})

test_that("analyze_and_report runs the full single-dv pipeline", {
  result <- suppressMessages(suppressWarnings(
    analyze_and_report(mtcars, dv = "mpg", iv = "cyl")
  ))

  expect_named(result, c("plot", "methods", "text", "posthoc", "sentences"))
  expect_s3_class(result$plot, "ggplot")
  expect_match(result$methods, "Shapiro--Wilk", fixed = TRUE)
  expect_match(result$text, "found")
  # cyl has 3 levels with strong differences, so post-hocs must be present
  expect_gt(length(result$posthoc), 0)
  expect_gte(length(result$sentences), 3)
})

test_that("analyze_and_report writes the combined sentences via sink_to", {
  path <- file.path(tempdir(), "pipeline-test", "mpg.tex")
  suppressMessages(suppressWarnings(
    analyze_and_report(mtcars, dv = "mpg", iv = "cyl", sink_to = path)
  ))

  expect_true(file.exists(path))
  content <- paste(readLines(path), collapse = "\n")
  expect_match(content, "Shapiro--Wilk", fixed = TRUE)
  expect_match(content, "found")
  unlink(dirname(path), recursive = TRUE)
})

test_that("report_all batches DVs with a Holm-adjusted summary", {
  out <- suppressMessages(suppressWarnings(
    report_all(mtcars, dvs = c("mpg", "hp"), iv = "cyl")
  ))

  expect_named(out, c("results", "summary", "combined_plot"))
  expect_named(out$results, c("mpg", "hp"))
  expect_equal(nrow(out$summary), 2)
  expect_true(all(c("dv", "method", "statistic", "p.value", "p.holm") %in% names(out$summary)))
  # Holm-adjusted p-values can never be smaller than the raw ones
  expect_true(all(out$summary$p.holm >= out$summary$p.value))

  if (requireNamespace("patchwork", quietly = TRUE)) {
    expect_s3_class(out$combined_plot, "ggplot")
  } else {
    expect_null(out$combined_plot)
  }
})

test_that("snake_case aliases point to the original functions", {
  expect_identical(report_art, reportART)
  expect_identical(report_dunn_test, reportDunnTest)
  expect_identical(report_ggstatsplot, reportggstatsplot)
  expect_identical(check_assumptions_anova, checkAssumptionsForAnova)
  expect_identical(plot_between_stats, ggbetweenstatsWithPriorNormalityCheck)
  expect_identical(plot_within_stats_asterisk, ggwithinstatsWithPriorNormalityCheckAsterisk)
})

test_that("check functions expose their statistics as attributes", {
  set.seed(11)
  d <- data.frame(g = rep(c("A", "B"), each = 20), v = rnorm(40))

  normal <- check_normality_by_group(d, "g", "v")
  tests <- attr(normal, "tests")
  expect_s3_class(tests, "data.frame")
  expect_true(all(c("W", "p_value") %in% names(tests)))
  expect_equal(nrow(tests), 2)

  skip_if_not_installed("rstatix")
  homog <- check_homogeneity_by_group(d, "g", "v")
  lev <- attr(homog, "test")
  expect_s3_class(lev, "data.frame")
  expect_true(all(c("df1", "df2", "statistic", "p") %in% names(lev)))
})
