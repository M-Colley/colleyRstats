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
