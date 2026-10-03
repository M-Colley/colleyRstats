scaffold <- function(...) {
  path <- withr::local_tempdir(.local_envir = parent.frame())
  suppressMessages(use_study_project(path, renv = FALSE, quiet = TRUE, ...))
  path
}


test_that("use_study_project writes a complete project", {
  path <- scaffold(name = "Test Study", questionnaires = c("nasa_tlx", "sus"))

  expect_true(all(file.exists(file.path(path, c(
    "_targets.R", "README.md", ".gitignore",
    "R/read.R", "R/prepare.R", "R/analysis.R", "R/figures.R",
    "report/report.qmd",
    "data-raw/example-study.csv", "data-raw/README.md",
    "paper/colleyRstats.sty", "paper/generated/README.md",
    "output/figures/README.md"
  )))))
})


test_that("every generated R file parses", {
  path <- scaffold(questionnaires = c("ueq_s", "tia"))

  for (f in c("_targets.R", "R/read.R", "R/prepare.R", "R/analysis.R", "R/figures.R")) {
    expect_silent(parse(file.path(path, f)))
  }
})


test_that("the generated pipeline runs end to end on its own example data", {
  skip_if_not_installed("lme4")
  skip_if_not_installed("parameters")
  skip_on_cran()
  path <- scaffold(questionnaires = "sus")

  withr::local_dir(path)
  env <- new.env(parent = globalenv())
  for (f in list.files("R", full.names = TRUE)) sys.source(f, envir = env)

  raw <- env$read_study("data-raw/example-study.csv")
  scored <- suppressMessages(env$score_scales(env$prepare_study(raw)))

  # The scoring step must produce exactly the columns the analysis step names.
  expect_true(all(setdiff(env$OUTCOMES, "completion_time") %in% names(scored)))
  expect_true(all(scored$SUS >= 0 & scored$SUS <= 100))

  results <- suppressWarnings(suppressMessages(env$run_models(scored)))
  expect_equal(nrow(results$summary), length(env$OUTCOMES))

  tex <- env$write_manuscript_tex(results, scored)
  expect_true(all(file.exists(tex)))
  expect_true(any(grepl("SUS", readLines(file.path("paper", "generated", "SUS.tex")))))

  # The figure stage too: its within-subject plots need the participant column.
  figures <- suppressWarnings(suppressMessages(env$make_figures(scored)))
  expect_true(all(file.exists(figures)))
})


test_that("questionnaire scores are declared, so they are not modelled as counts", {
  path <- scaffold(questionnaires = c("nasa_tlx", "misc"))
  analysis <- readLines(file.path(path, "R", "analysis.R"))

  expect_true(any(grepl('RTLX = "continuous"', analysis, fixed = TRUE)))
  # MISC is a single item with labelled, unevenly spaced steps.
  expect_true(any(grepl('MISC = "ordinal"', analysis, fixed = TRUE)))
})


test_that("the example data carries a column per item of every named instrument", {
  path <- scaffold(questionnaires = c("ueq_s", "sus"))
  raw <- utils::read.csv(file.path(path, "data-raw", "example-study.csv"))

  expect_equal(sum(grepl("^ueq_s_", names(raw))), 8L)
  expect_equal(sum(grepl("^sus_", names(raw))), 10L)
  expect_true(all(c("participant", "condition", "completion_time") %in% names(raw)))
  # Deterministic, so a re-scaffold does not churn the example pipeline's output.
  again <- scaffold(questionnaires = c("ueq_s", "sus"))
  expect_identical(raw, utils::read.csv(file.path(again, "data-raw", "example-study.csv")))
})


test_that("scaffolding twice does not overwrite edited files", {
  path <- withr::local_tempdir()
  suppressMessages(use_study_project(path, renv = FALSE, quiet = TRUE))
  writeLines("# edited by hand", file.path(path, "R", "prepare.R"))

  suppressMessages(use_study_project(path, renv = FALSE, quiet = TRUE))
  expect_equal(readLines(file.path(path, "R", "prepare.R")), "# edited by hand")

  suppressMessages(use_study_project(path, renv = FALSE, quiet = TRUE, overwrite = TRUE))
  expect_true(length(readLines(file.path(path, "R", "prepare.R"))) > 1)
})


test_that("an unknown instrument stops before anything is written", {
  path <- withr::local_tempdir()

  expect_error(
    use_study_project(path, questionnaires = c("sus", "nope"), renv = FALSE, quiet = TRUE),
    "Unknown questionnaire"
  )
  expect_false(file.exists(file.path(path, "_targets.R")))
})


test_that("the LaTeX macros the generated sentences need ship with the project", {
  path <- scaffold()
  sty <- readLines(file.path(path, "paper", "colleyRstats.sty"))

  expect_true(any(grepl("ProvidesPackage{colleyRstats}", sty, fixed = TRUE)))
  expect_true(any(grepl("newcommand{\\p}", sty, fixed = TRUE)))
})


# -------------------------------------------------------------------------
# Regressions
# -------------------------------------------------------------------------

run_scoring <- function(path) {
  env <- new.env(parent = globalenv())
  for (f in list.files(file.path(path, "R"), full.names = TRUE)) sys.source(f, envir = env)
  raw <- utils::read.csv(file.path(path, "data-raw", "example-study.csv"))
  env$scored <- suppressMessages(env$score_scales(env$prepare_study(raw)))
  env
}


test_that("instruments whose prefixes overlap still scaffold a runnable project", {
  # "ueq_" also matches every ueq_s_* column, so a bare prefix selects 34
  # columns where the UEQ has 26 and score_questionnaire() aborts.
  path <- scaffold(questionnaires = c("ueq", "ueq_s"))

  env <- run_scoring(path)

  expect_true(all(setdiff(env$OUTCOMES, "completion_time") %in% names(env$scored)))
})


test_that("instruments that score a column of the same name are disambiguated", {
  # AttrakDiff and UEQ-S both produce Pragmatic_Quality; without a prefix the
  # second append(TRUE) aborts and OUTCOMES lists the name twice.
  path <- scaffold(questionnaires = c("attrakdiff", "ueq_s"))

  env <- run_scoring(path)

  expect_equal(anyDuplicated(env$OUTCOMES), 0L)
  expect_true(all(setdiff(env$OUTCOMES, "completion_time") %in% names(env$scored)))
})


test_that("every instrument scaffolds into one runnable project", {
  path <- scaffold(questionnaires = list_questionnaires()$key)

  # No warnings either: the example data must not trip the coding checks
  # (an unused scale end, fractional responses) that real data are held to.
  expect_no_warning(env <- run_scoring(path))

  expect_equal(anyDuplicated(env$OUTCOMES), 0L)
  expect_true(all(setdiff(env$OUTCOMES, "completion_time") %in% names(env$scored)))
})


test_that("a behaviour-only study with no questionnaires scaffolds", {
  path <- scaffold(questionnaires = character(0))

  env <- run_scoring(path)

  expect_identical(env$OUTCOMES, "completion_time")
  expect_true(file.exists(file.path(path, "_targets.R")))
})


test_that("scaffolding leaves the caller's RNG state alone", {
  # The example data is seeded so it is reproducible; that seed must not escape
  # into the session and silently change every later random draw.
  set.seed(99)
  before <- stats::runif(1)

  set.seed(99)
  path <- withr::local_tempdir()
  suppressMessages(use_study_project(path, questionnaires = "sus", renv = FALSE, quiet = TRUE))

  expect_equal(stats::runif(1), before)
})


test_that("renv is opt-in, and runs outside the calling session", {
  # Initialising renv installs every package the scripts use into a project
  # library -- network access, minutes of work -- so it must not happen just
  # because renv is installed.
  expect_false(formals(use_study_project)$renv)

  skip_if_not_installed("renv")
  called <- NULL
  local_mocked_bindings(.renv_init_subprocess = function(path, quiet = FALSE) {
    called <<- path
    invisible(TRUE)
  })
  # renv::init() in this session would rewrite .libPaths(), R_LIBS_USER, PATH
  # and options(repos); the scaffold must hand it to a child process instead.
  before <- list(
    libs = .libPaths(), repos = getOption("repos"),
    r_libs_user = Sys.getenv("R_LIBS_USER"), path = Sys.getenv("PATH"),
    wd = getwd()
  )
  project <- withr::local_tempdir()
  suppressMessages(use_study_project(project, renv = TRUE, quiet = TRUE))

  expect_equal(called, normalizePath(project, winslash = "/"))
  expect_equal(
    list(
      libs = .libPaths(), repos = getOption("repos"),
      r_libs_user = Sys.getenv("R_LIBS_USER"), path = Sys.getenv("PATH"),
      wd = getwd()
    ),
    before
  )
})


test_that("the generated figures pass the participant column to within-subject plots", {
  # plot_within_stats() requires `subject` to pair observations across
  # conditions; a call without it would not run.
  path <- scaffold()
  figures <- readLines(file.path(path, "R", "figures.R"))
  report <- readLines(file.path(path, "report", "report.qmd"))

  code <- grep("^[[:space:]]*#", c(figures, report), value = TRUE, invert = TRUE)
  calls <- grep("plot_within_stats(", code, fixed = TRUE, value = TRUE)
  expect_length(calls, 3L)
  expect_equal(sum(grepl("subject = CLUSTER", figures, fixed = TRUE)), 2L)
  expect_true(any(grepl("subject = \"participant\"", report, fixed = TRUE)))
})


test_that("a text label in an exported item column stops the pipeline with a fix", {
  # read.csv() turns a column with one "Strongly agree" into text. Scoring used
  # to make that cell NA and carry on; the pipeline must stop and say why.
  path <- scaffold(questionnaires = "sus")
  csv <- file.path(path, "data-raw", "example-study.csv")
  raw <- utils::read.csv(csv, stringsAsFactors = FALSE)
  raw$sus_3[1] <- "Strongly agree"
  utils::write.csv(raw, csv, row.names = FALSE)

  env <- new.env(parent = globalenv())
  for (f in list.files(file.path(path, "R"), full.names = TRUE)) sys.source(f, envir = env)
  clean <- env$prepare_study(env$read_study(csv))

  expect_error(suppressMessages(env$score_scales(clean)), "'Strongly agree'.*Recode")
  # The template points at where the recoding belongs.
  expect_true(any(grepl("must be numbers", readLines(file.path(path, "R", "prepare.R")))))
})


test_that("the example data carries signal through reverse-coded instruments", {
  # Adding the same effect to every raw item makes it cancel after reverse
  # coding, which left the scaffolded SUS with no variance and greeted a new
  # user with a singular-fit warning on the first tar_make().
  path <- scaffold(questionnaires = "sus")

  env <- run_scoring(path)
  by_condition <- tapply(env$scored$SUS, env$scored$condition, mean)
  by_participant <- tapply(env$scored$SUS, env$scored$participant, mean)

  expect_gt(diff(range(by_condition)), 5)
  expect_gt(stats::sd(by_participant), 1)
})
