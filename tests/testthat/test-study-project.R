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

  tex <- env$write_manuscript_tex(results)
  expect_true(all(file.exists(tex)))
  expect_true(any(grepl("SUS", readLines(file.path("paper", "generated", "SUS.tex")))))

  # Figures use the fitted tests, and their analyzed rows, rather than another
  # test selected independently by a plotting wrapper.
  plots <- env$make_plots(results)
  expect_identical(names(plots), names(results$fits))
  expect_match(plots$SUS$labels$subtitle, results$fits$SUS$recommendation$recommendation, fixed = TRUE)
  figures <- suppressWarnings(suppressMessages(env$make_figures(plots)))
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


test_that("the generated report reads the plots cached by the pipeline", {
  path <- scaffold()
  figures <- readLines(file.path(path, "R", "figures.R"))
  report <- readLines(file.path(path, "report", "report.qmd"))
  pipeline <- readLines(file.path(path, "_targets.R"))

  expect_true(any(grepl("plot_fit(results$fits[[dv]]", figures, fixed = TRUE)))
  expect_true(any(grepl("tar_target(plots, make_plots(results))", pipeline, fixed = TRUE)))
  expect_true(any(grepl("make_figures(plots)", pipeline, fixed = TRUE)))
  expect_true(any(grepl("plots <- tar_read(plots, store = store)", report, fixed = TRUE)))
  expect_true(any(grepl("print(plots[[dv]])", report, fixed = TRUE)))
  expect_false(any(grepl("\"participant\"", report, fixed = TRUE)))
})


test_that("the generated figures follow a between-subjects design (CLUSTER <- NULL)", {
  skip_on_cran()
  path <- scaffold(questionnaires = "sus")
  withr::local_dir(path)
  env <- new.env(parent = globalenv())
  for (f in list.files("R", full.names = TRUE)) sys.source(f, envir = env)
  scored <- suppressMessages(env$score_scales(env$prepare_study(env$read_study("data-raw/example-study.csv"))))

  # one row per participant, the conditions spread across participants: a
  # between-subjects study
  ids <- unique(as.character(scored$participant))
  conds <- unique(as.character(scored$condition))
  pick <- conds[(seq_along(ids) - 1L) %% length(conds) + 1L]
  between <- scored[paste(scored$participant, scored$condition) %in% paste(ids, pick), , drop = FALSE]
  expect_false(anyDuplicated(between$participant) > 0)
  env$CLUSTER <- NULL
  results <- suppressWarnings(suppressMessages(env$run_models(between)))
  plots <- env$make_plots(results)
  figures <- suppressWarnings(suppressMessages(env$make_figures(plots)))
  expect_true(all(file.exists(figures)))

  # Declaring clusters with repeated trials averages only for display; the
  # plotted test is still the test of the fitted mixed model.
  env$CLUSTER <- "participant"
  env$OUTCOMES <- "completion_time"
  set.seed(91)
  repeated <- between[rep(seq_len(nrow(between)), each = 5), ]
  repeated$completion_time <- repeated$completion_time + rnorm(nrow(repeated), sd = 0.3)
  results <- suppressWarnings(suppressMessages(env$run_models(repeated)))
  p <- env$plot_outcome(results, "completion_time")
  expect_s3_class(p, "ggplot")
  expect_equal(nrow(p$data), nrow(between))
  expect_match(p$labels$subtitle, results$fits$completion_time$recommendation$recommendation, fixed = TRUE)
})


test_that("individual and combined figures reuse each outcome plot", {
  skip_if_not_installed("patchwork")
  path <- scaffold(questionnaires = character(0))
  env <- new.env(parent = globalenv())
  for (f in list.files(file.path(path, "R"), full.names = TRUE)) sys.source(f, envir = env)
  calls <- character(0)
  env$plot_outcome <- function(results, dv) {
    calls <<- c(calls, dv)
    ggplot2::ggplot(data.frame(x = 1, y = 1), ggplot2::aes(x, y)) + ggplot2::geom_point()
  }
  saved <- list()
  env$save_paper_figure <- function(plot, filename, ...) {
    saved[[basename(filename)]] <<- plot
    writeLines("saved", filename)
  }
  results <- list(fits = list(first = list(), second = list()))
  plots <- env$make_plots(results)
  files <- env$make_figures(plots, dir = file.path(path, "output", "figures"))
  expect_identical(calls, c("first", "second"))
  expect_identical(saved[["first.pdf"]], plots$first)
  expect_identical(saved[["second.pdf"]], plots$second)
  expect_s3_class(saved[["all-scales.pdf"]], "patchwork")
  expect_true(all(file.exists(files)))
})


test_that("manuscript descriptives use each outcome's final analyzed sample", {
  path <- scaffold(questionnaires = character(0))
  env <- new.env(parent = globalenv())
  for (f in list.files(file.path(path, "R"), full.names = TRUE)) sys.source(f, envir = env)
  described <- list()
  env$report_mean_sd <- function(data, dv, iv) {
    described[[dv]] <<- data
    "descriptives"
  }
  first <- data.frame(condition = factor(c("A", "B")), first = c(1, 2))
  second <- data.frame(condition = factor(c("A", "A", "B")), second = c(3, 4, 5))
  results <- list(fits = list(
    first = list(data = first, sentences = "first test"),
    second = list(data = second, sentences = "second test")
  ))
  files <- env$write_manuscript_tex(results, dir = file.path(path, "paper", "generated"))
  expect_identical(described$first, first)
  expect_identical(described$second, second)
  expect_true(all(file.exists(files)))
  ordinal <- list(data = data.frame(condition = factor(c("A", "A", "B"), levels = c("A", "B", "C")),
                                    rating = ordered(c("low", "high", "high"), levels = c("low", "high"))),
                  recommendation = list(outcome_type = "ordinal"))
  expect_no_warning(text <- env$describe_outcome(ordinal, "rating"))
  expect_length(text, 2L)
  expect_match(text[[1]], "low ($n = 1$)", fixed = TRUE)
  expect_match(text[[1]], "high ($n = 1$)", fixed = TRUE)
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
