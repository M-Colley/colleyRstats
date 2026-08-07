test_that("colleyRstats_setup runs without side effects when disabled", {
  expect_silent(
    colleyRstats_setup(
      set_options = FALSE,
      set_theme = FALSE,
      set_conflicts = FALSE,
      print_citation = FALSE,
      verbose = FALSE
    )
  )
})

test_that("colleyRstats_setup emits messages for options and citation", {
  expect_message(
    colleyRstats_setup(
      set_options = TRUE,
      set_theme = FALSE,
      set_conflicts = FALSE,
      print_citation = FALSE,
      verbose = TRUE
    ),
    "deprecated"
  )

  expect_message(
    colleyRstats_setup(
      set_options = FALSE,
      set_theme = FALSE,
      set_conflicts = FALSE,
      print_citation = TRUE,
      verbose = FALSE
    ),
    "please cite"
  )
})


test_that("colley_theme scales every text element with base_size", {
  skip_if_not_installed("see")

  small <- colley_theme(base_size = 8)
  large <- colley_theme(base_size = 16)

  expect_s3_class(small, "theme")
  expect_equal(small$text$size, 8)
  expect_equal(large$text$size, 16)

  # The point of the fix: sizes are relative, so doubling base_size doubles
  # every derived element rather than leaving absolute points behind.
  for (el in c("axis.title", "axis.text", "plot.title", "plot.subtitle",
               "legend.text", "strip.text")) {
    ratio <- colleyRstats:::.COLLEY_TEXT_RATIOS[[el]]
    expect_s3_class(small[[el]]$size, "rel")
    expect_equal(as.numeric(small[[el]]$size), ratio, info = el)
  }
})


test_that("colley_theme keeps the legend-title convention and rejects bad input", {
  skip_if_not_installed("see")

  expect_s3_class(colley_theme()$legend.title, "element_blank")
  expect_error(colley_theme(base_size = 0), "positive")
  expect_error(colley_theme(base_size = c(8, 9)), "single")
  expect_error(colley_theme(base_size = "big"), "single positive")
})


test_that("colleyRstats_setup applies base_size to the session theme", {
  skip_if_not_installed("see")

  old <- ggplot2::theme_get()
  on.exit(ggplot2::theme_set(old), add = TRUE)

  colleyRstats_setup(
    set_options = FALSE, set_theme = TRUE, base_size = 9,
    set_conflicts = FALSE, print_citation = FALSE, verbose = FALSE
  )
  expect_equal(ggplot2::theme_get()$text$size, 9)
})


test_that("the default base_size reproduces the pre-0.1.5 absolute sizes", {
  skip_if_not_installed("see")

  # Regression guard: existing scripts that never mention base_size must keep
  # the sizes they had before the theme became relative.
  th <- colley_theme()
  base <- th$text$size
  expect_equal(base, 17)
  expect_equal(base * as.numeric(th$axis.title$size), 19.55, tolerance = 1e-8)
  expect_equal(base * as.numeric(th$axis.text$size), 17)
  expect_equal(base * as.numeric(th$plot.title$size), 28.05, tolerance = 1e-8)
  expect_equal(base * as.numeric(th$legend.text$size), 15.3, tolerance = 1e-8)
  expect_equal(base * as.numeric(th$strip.text$size), 22.1, tolerance = 1e-8)
})


test_that("signif annotation size follows the active theme", {
  skip_if_not_installed("see")

  old <- ggplot2::theme_get()
  on.exit(ggplot2::theme_set(old), add = TRUE)

  ggplot2::theme_set(colley_theme(base_size = 17))
  big <- colleyRstats:::.signif_text_mm()
  ggplot2::theme_set(colley_theme(base_size = 8))
  small <- colleyRstats:::.signif_text_mm()

  expect_lt(small, big)
  # At the historical base of 17 pt this must still be the 4 mm that used to be
  # hard-coded, so existing figures do not shift.
  expect_equal(big, 4, tolerance = 0.05)
})
