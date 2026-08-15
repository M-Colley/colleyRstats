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

test_that("set_options is deprecated and warns rather than doing nothing quietly", {
  expect_warning(
    colleyRstats_setup(
      set_options = TRUE,
      set_theme = FALSE,
      set_conflicts = FALSE,
      print_citation = FALSE,
      verbose = TRUE
    ),
    "deprecated"
  )

  # The warning is not gated on `verbose`: that argument governs informational
  # chatter, not deprecation notices.
  expect_warning(
    colleyRstats_setup(
      set_options = TRUE,
      set_theme = FALSE,
      set_conflicts = FALSE,
      print_citation = FALSE,
      verbose = FALSE
    ),
    "deprecated"
  )
})


test_that("colleyRstats_setup prints the citation on request", {
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


test_that("conflict preferences are opt-in", {
  # The default is the fix: switching conflicted on rewires library() for the
  # whole session, which is not something a setup helper may do behind the
  # caller's back.
  expect_false(formals(colleyRstats_setup)$set_conflicts)
})


test_that("colleyRstats_setup() leaves library() alone by default", {
  skip_if_not_installed("conflicted")

  # This one can run in-process precisely because of the fix: with the default,
  # the call must not activate conflicted. Should that ever regress, these
  # expectations fail -- and the on.exit puts the search path back, so the rest
  # of the suite is not left running under conflicted's library() shims.
  on.exit(
    if (".conflicts" %in% search()) detach(".conflicts", character.only = TRUE),
    add = TRUE
  )

  colleyRstats_setup(set_theme = FALSE, print_citation = FALSE, verbose = FALSE)

  expect_false(".conflicts" %in% search())
  expect_true(identical(library, base::library))
  expect_true(identical(require, base::require))
})


test_that("a meta-package still attaches after colleyRstats_setup()", {
  # The reported defect: `library(colleyRstats); colleyRstats_setup();
  # library(easystats)` died on the third line because conflicted's library()
  # shim feeds `quietly` to easystats' .onAttach as an unevaluable symbol.
  # Meta-packages attach their constituents from .onAttach, so this is the
  # shape that breaks; easystats is the case that was reported.
  skip_on_cran()
  skip_if_not_installed("easystats")

  res <- run_in_fresh_r(c(
    "suppressPackageStartupMessages(library(colleyRstats))",
    "colleyRstats_setup(set_theme = FALSE, print_citation = FALSE, verbose = FALSE)",
    "ok <- tryCatch({",
    "  suppressPackageStartupMessages(library(easystats))",
    '  "yes"',
    '}, error = function(e) paste("no -", conditionMessage(e)))',
    'cat("attached:", ok, "\\n")',
    'cat("easystats_on_path:", "package:easystats" %in% search(), "\\n")'
  ))
  skip_unless_subprocess(res)

  expect_equal(res$status, 0L)
  expect_match(res$output, "attached: yes", fixed = TRUE)
  expect_match(res$output, "easystats_on_path: TRUE", fixed = TRUE)
  # The historical failure signature, so a regression cannot hide behind a
  # differently worded pass.
  expect_false(grepl("object 'quietly' not found", res$output, fixed = TRUE))
})


test_that("set_conflicts = TRUE still installs the documented preferences", {
  # The other half of the fix: making the hazard opt-in must not quietly turn
  # the feature off for the people who opt in.
  skip_on_cran()
  skip_if_not_installed("conflicted")
  skip_if_not_installed("dplyr")

  res <- run_in_fresh_r(c(
    "suppressPackageStartupMessages(library(colleyRstats))",
    "suppressPackageStartupMessages(library(dplyr))",
    "colleyRstats_setup(set_conflicts = TRUE, set_theme = FALSE,",
    "                   print_citation = FALSE, verbose = FALSE)",
    'cat("conflicts_attached:", ".conflicts" %in% search(), "\\n")',
    'cat("conflicts_in_front:", identical(search()[2], ".conflicts"), "\\n")',
    'e <- as.environment(".conflicts")',
    # filter and lag are both in the preference list and both genuinely
    # ambiguous here (dplyr vs stats), so conflicted has to resolve them.
    'cat("filter_is_dplyr:",',
    '    identical(get0("filter", envir = e, inherits = FALSE), dplyr::filter), "\\n")',
    'cat("lag_is_dplyr:",',
    '    identical(get0("lag", envir = e, inherits = FALSE), dplyr::lag), "\\n")'
  ))
  skip_unless_subprocess(res)

  expect_equal(res$status, 0L)
  expect_match(res$output, "conflicts_attached: TRUE", fixed = TRUE)
  expect_match(res$output, "conflicts_in_front: TRUE", fixed = TRUE)
  expect_match(res$output, "filter_is_dplyr: TRUE", fixed = TRUE)
  expect_match(res$output, "lag_is_dplyr: TRUE", fixed = TRUE)
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
