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
