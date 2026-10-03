# Scaffolding a study analysis as a reproducible pipeline.
#
# The per-study cost that a package of functions cannot remove is the project
# itself: deciding where raw data lives, which script produces which figure, how
# a number gets from R into the manuscript, and how a co-author reproduces it a
# year later. use_study_project() writes that structure once, wired to the
# functions in this package, so a new study starts from a working pipeline
# rather than an empty directory -- and so every study in a group has the same
# shape, which is what makes a student's analysis reviewable at all.


# Internal: read a template shipped in inst/templates and fill in {{ ... }}.
.tmpl <- function(name, values = list()) {
  path <- system.file("templates", name, package = "colleyRstats")
  if (!nzchar(path)) {
    stop("Template '", name, "' is missing from the installed package.", call. = FALSE)
  }
  txt <- readLines(path, warn = FALSE)
  for (key in names(values)) {
    txt <- gsub(paste0("{{", key, "}}"), values[[key]], txt, fixed = TRUE)
  }
  txt
}


# Internal: write a file unless it exists, reporting what happened. Never
# overwrites: scaffolding is run on live projects to pick up new pieces, and
# silently replacing an edited _targets.R would destroy real work.
.write_project_file <- function(lines, path, overwrite = FALSE, quiet = FALSE) {
  dir <- dirname(path)
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  }
  if (file.exists(path) && !overwrite) {
    if (!quiet) message("  skipped (exists): ", path)
    return(invisible(FALSE))
  }
  writeLines(lines, con = path)
  if (!quiet) message("  wrote: ", path)
  invisible(TRUE)
}


#' Scaffold a reproducible study analysis
#'
#' Writes a complete, runnable analysis project: a \pkg{targets} pipeline that
#' recomputes only what changed, R scripts split along the stages every user
#' study goes through (read, clean, score, model, plot), a Quarto report, and a
#' directory the generated LaTeX lands in so a manuscript can \code{\\input{}}
#' the numbers instead of having them re-typed.
#'
#' The generated pipeline is wired to this package: scoring goes through
#' [score_questionnaire()], model choice and fitting through
#' [fit_recommended()], sentences and tables through the \code{report_*}
#' functions, and figures through [save_paper_figure()]. It runs as written
#' against the example data it ships with, so the first thing you do in a new
#' project is see a green pipeline, then replace the example data with yours.
#'
#' @section Why a pipeline rather than a script:
#' A study analysis is re-run many times -- after a data fix, after a reviewer
#' asks for one more contrast, after a co-author changes a factor label. With a
#' script, that means re-running everything and hoping nothing stale is left in
#' the workspace; \pkg{targets} tracks which step depends on what and recomputes
#' only the affected ones, which also means the pipeline is a machine-checkable
#' record of how each number was produced.
#'
#' @param path Directory to create the project in. Created if it does not exist.
#' @param name Project name, used in the README and the report title. Defaults
#'   to the directory name.
#' @param questionnaires Character vector of instrument keys the study uses,
#'   e.g. \code{c("nasa_tlx", "sus")}. The scoring script is generated with one
#'   call per instrument. See [list_questionnaires()].
#' @param renv Logical. Initialise \pkg{renv} in the project, pinning the
#'   package versions this analysis was run with -- which is what makes the
#'   project still run in three years, and what makes it a usable open-science
#'   artifact. Default \code{FALSE}: initialising discovers every package the
#'   scripts use and installs it into a project library, which can mean
#'   network downloads, so it is opt-in. With \code{TRUE}, \code{renv::init()}
#'   runs in a separate R process (via \pkg{callr} when installed, otherwise
#'   \code{Rscript}), because activating a project rewrites the calling
#'   session's library paths, environment variables (\code{R_LIBS_USER},
#'   \code{PATH}, \code{RENV_PATHS_*}), repository options and sandbox; your
#'   current session is left exactly as it was. Run \code{renv::init()}
#'   yourself later to opt in after the fact.
#' @param git Logical. Write a \code{.gitignore} suited to an R analysis
#'   project. Default \code{TRUE}.
#' @param overwrite Logical. Replace files that already exist. Default
#'   \code{FALSE}, so running this on a live project adds missing pieces without
#'   touching your work.
#' @param quiet Logical. Suppress the per-file messages.
#'
#' @return Invisibly, the normalised project path.
#' @export
#' @seealso [score_questionnaire()], [fit_recommended()], [save_paper_figure()],
#'   [emit_overleaf()]
#'
#' @examples
#' \donttest{
#' project <- file.path(tempdir(), "driving-study")
#' use_study_project(project, questionnaires = c("nasa_tlx", "sus"), renv = FALSE)
#' list.files(project, recursive = TRUE)
#' }
use_study_project <- function(path, name = NULL,
                              questionnaires = c("nasa_tlx", "sus"),
                              renv = FALSE,
                              git = TRUE, overwrite = FALSE, quiet = FALSE) {
  not_empty(path)
  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  if (is.null(name)) name <- basename(path)

  # Fail before writing anything if an instrument is misspelled: a scaffold that
  # half-writes a project is worse than one that refuses.
  for (q in questionnaires) .q_get(q)

  values <- list(
    name = name,
    date = format(Sys.Date()),
    scoring = paste(.scaffold_scoring(questionnaires), collapse = "\n"),
    outcomes = paste(.scaffold_outcomes(questionnaires), collapse = "\n"),
    outcome_types = paste(.scaffold_outcome_types(questionnaires), collapse = "\n"),
    instruments = paste(questionnaires, collapse = ", ")
  )

  if (!quiet) message("Creating study project '", name, "' in ", path)

  files <- list(
    "_targets.R" = "_targets.R",
    "R/read.R" = "read.R",
    "R/prepare.R" = "prepare.R",
    "R/analysis.R" = "analysis.R",
    "R/figures.R" = "figures.R",
    "report/report.qmd" = "report.qmd",
    "README.md" = "README.md"
  )
  for (target in names(files)) {
    .write_project_file(
      .tmpl(files[[target]], values),
      file.path(path, target),
      overwrite = overwrite, quiet = quiet
    )
  }

  if (isTRUE(git)) {
    .write_project_file(
      .tmpl("gitignore", values), file.path(path, ".gitignore"),
      overwrite = overwrite, quiet = quiet
    )
  }

  # An example dataset so the pipeline runs before any real data exists. It
  # carries exactly the columns the generated scripts expect.
  .write_project_file(
    .scaffold_example_csv(questionnaires),
    file.path(path, "data-raw", "example-study.csv"),
    overwrite = overwrite, quiet = quiet
  )

  .write_project_file(
    c(
      "# Raw data",
      "",
      "The study export exactly as it came out of the survey tool or the",
      "simulator. Nothing in here is ever edited by hand: a correction belongs",
      "in `R/prepare.R`, where it is visible and reviewable.",
      "",
      "`example-study.csv` is synthetic, and only exists so the pipeline runs",
      "before any real data does. Delete it once yours is in place."
    ),
    file.path(path, "data-raw", "README.md"),
    overwrite = overwrite, quiet = quiet
  )

  for (d in c("paper/generated", "output/figures")) {
    dir.create(file.path(path, d), recursive = TRUE, showWarnings = FALSE)
    .write_project_file(
      c(
        "# Generated by the pipeline -- do not edit by hand.",
        "# Everything here is reproduced by `targets::tar_make()`."
      ),
      file.path(path, d, "README.md"),
      overwrite = overwrite, quiet = quiet
    )
  }

  # The LaTeX macros the report_* sentences rely on, so the manuscript compiles
  # the moment it \input{}s a generated file. latex_preamble() echoes the whole
  # style file as it writes it, which is useful at the console and noise here.
  sty <- file.path(path, "paper", "colleyRstats.sty")
  if (file.exists(sty) && !overwrite) {
    if (!quiet) message("  skipped (exists): ", sty)
  } else {
    suppressMessages(latex_preamble(sty))
    if (!quiet) message("  wrote: ", sty)
  }

  if (isTRUE(renv)) {
    if (!requireNamespace("renv", quietly = TRUE)) {
      warning("`renv = TRUE` but the 'renv' package is not installed; skipping.", call. = FALSE)
    } else if (file.exists(file.path(path, "renv", "activate.R")) && !overwrite) {
      # init() writes renv/activate.R but not necessarily a lockfile, so the
      # lockfile is the wrong thing to test for "already initialised".
      if (!quiet) message("  skipped (exists): ", file.path(path, "renv"))
    } else {
      if (!quiet) message("  initialising renv in a separate R process (this takes a moment)")
      .renv_init_subprocess(path, quiet = quiet)
    }
  }

  if (!quiet) {
    message(
      "\nDone. Next:\n",
      "  1. setwd(\"", path, "\")\n",
      "  2. targets::tar_make()            # runs end to end on the example data\n",
      "  3. replace data-raw/example-study.csv with yours, then edit R/read.R\n",
      "  4. targets::tar_visnetwork()      # see what is out of date\n"
    )
  }
  invisible(path)
}


# Internal: initialise renv for `path` in a fresh R process.
#
# renv::init() activates the project in the session that calls it, and
# activation is not only setwd() and .libPaths(): it sets R_LIBS_USER,
# R_LIBS_SITE and PATH, RENV_PATHS_* and the sandbox, and options(repos). An
# earlier version restored the working directory and library paths afterwards
# and left the rest changed, so one scaffolding call quietly reconfigured the
# user's session. A child process takes all of that with it when it exits.
#
# Not bare: renv discovers what the generated scripts use and writes a lockfile,
# which is the whole point of pinning. A bare init leaves an empty library and
# no renv.lock, so the project could not run its own pipeline.
.renv_init_subprocess <- function(path, quiet = FALSE) {
  init <- function(project) {
    renv::init(project = project, restart = FALSE)
    invisible(TRUE)
  }

  if (requireNamespace("callr", quietly = TRUE)) {
    ok <- tryCatch(
      {
        callr::r(init, args = list(project = path), show = !quiet)
        TRUE
      },
      error = function(e) {
        warning(
          "renv initialisation in a separate R process failed: ", conditionMessage(e),
          " The project itself was written; run renv::init() inside it to retry.",
          call. = FALSE
        )
        FALSE
      }
    )
    return(invisible(ok))
  }

  # Without callr: a script file rather than `Rscript -e`, so the project path
  # never has to survive shell quoting on any platform.
  script <- tempfile(fileext = ".R")
  on.exit(unlink(script), add = TRUE)
  writeLines(
    sprintf("renv::init(project = %s, restart = FALSE)", deparse(path)),
    script
  )
  rscript <- file.path(
    R.home("bin"),
    if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"
  )
  status <- system2(
    rscript, shQuote(script),
    stdout = if (quiet) FALSE else "", stderr = if (quiet) FALSE else ""
  )
  if (!identical(as.integer(status), 0L)) {
    warning(
      "renv initialisation in a separate R process failed (exit status ", status,
      "). The project itself was written; run renv::init() inside it to retry.",
      call. = FALSE
    )
  }
  invisible(identical(as.integer(status), 0L))
}


# Internal: which instruments cannot be selected by a bare "<key>_" prefix
# because another instrument's columns start with the same string. Scaffolding
# both `ueq` and `ueq_s` is the real case: "ueq_" matches all 34 columns.
.scaffold_ambiguous <- function(questionnaires) {
  vapply(questionnaires, function(q) {
    any(startsWith(paste0(setdiff(questionnaires, q), "_"), paste0(q, "_")))
  }, logical(1))
}


# Internal: which instruments need their score columns prefixed because another
# instrument produces a column of the same name. AttrakDiff and UEQ-S both score
# a "Pragmatic_Quality"; without a prefix the second append would abort.
.scaffold_needs_prefix <- function(questionnaires) {
  cols <- lapply(questionnaires, .scaffold_raw_columns)
  names(cols) <- questionnaires
  all_cols <- unlist(cols, use.names = FALSE)
  clashing <- unique(all_cols[duplicated(all_cols)])
  vapply(cols, function(cc) any(cc %in% clashing), logical(1))
}


# Internal: the score columns one instrument produces, unprefixed.
.scaffold_raw_columns <- function(q) {
  def <- .q_get(q)
  # The top scale point is a valid response on every instrument; the midpoint
  # is not (the SSQ's 0-3 has no 1.5), and scoring one would warn. (The bottom
  # would trip the NASA-TLX check for 1-21 data scored as 0-100.)
  dummy <- as.data.frame(matrix(def$scale[2], nrow = 1, ncol = nrow(def$items)))
  names(dummy) <- def$items$code
  names(score_questionnaire(dummy, q, items = def$items$code, verbose = FALSE))
}


# Internal: one score_questionnaire() call per instrument the study uses, wired
# to the column naming the example data actually uses, so the generated script
# runs as written.
.scaffold_scoring <- function(questionnaires) {
  if (length(questionnaires) == 0) {
    return("  # No questionnaires in this study; scores come from the logged measures.")
  }

  ambiguous <- .scaffold_ambiguous(questionnaires)
  prefixed <- .scaffold_needs_prefix(questionnaires)

  unlist(lapply(questionnaires, function(q) {
    def <- .q_get(q)
    n <- nrow(def$items)

    # A bare prefix would over-match, so name the columns exactly.
    selector <- if (ambiguous[[q]]) {
      paste0("    items = paste0(\"", q, "_\", 1:", n, "),")
    } else {
      paste0("    prefix = \"", q, "_\",")
    }
    check_arg <- if (ambiguous[[q]]) {
      paste0("items = paste0(\"", q, "_\", 1:", n, ")")
    } else {
      paste0("prefix = \"", q, "_\"")
    }
    prefix_out <- if (prefixed[[q]]) {
      paste0("    prefix_out = \"", q, "_\",")
    } else {
      NULL
    }

    c(
      paste0("  # ", def$name, " -- ", def$reference),
      paste0("  # Verify the mapping once: check_questionnaire(data, \"", q, "\", ", check_arg, ")"),
      if (prefixed[[q]]) {
        paste0("  # Another instrument here scores a column of the same name, so these are prefixed.")
      },
      paste0("  data <- score_questionnaire("),
      paste0("    data, \"", q, "\","),
      selector,
      prefix_out,
      paste0("    append = TRUE"),
      paste0("  )"),
      ""
    )
  }))
}


# Internal: the score columns each instrument produces, and how each should be
# modelled. Derived by scoring a dummy row through the real code path, so the
# scaffold cannot name a column that score_questionnaire() does not produce.
.scaffold_score_columns <- function(questionnaires) {
  if (length(questionnaires) == 0) {
    return(stats::setNames(character(0), character(0)))
  }
  prefixed <- .scaffold_needs_prefix(questionnaires)

  out <- lapply(questionnaires, function(q) {
    def <- .q_get(q)
    cols <- .scaffold_raw_columns(q)
    # Must match what .scaffold_scoring() emits, or OUTCOMES would name columns
    # the pipeline never creates.
    if (prefixed[[q]]) {
      cols <- paste0(q, "_", cols)
    }

    # A single-item scale with few steps is genuinely ordinal (MISC's labelled
    # 0-10 steps are not evenly spaced). A summed or averaged multi-item scale
    # is conventionally analysed as continuous.
    type <- if (nrow(def$items) == 1L && diff(def$scale) <= 10) "ordinal" else "continuous"
    stats::setNames(rep(type, length(cols)), cols)
  })
  unlist(out)
}


# Internal: the OUTCOMES vector of the generated analysis script.
.scaffold_outcomes <- function(questionnaires) {
  entries <- c(names(.scaffold_score_columns(questionnaires)), "completion_time")
  paste0("  \"", entries, "\"", c(rep(",", length(entries) - 1L), ""))
}


# Internal: the OUTCOME_TYPES vector. Without it, fit_recommended() classifies a
# 0-100 questionnaire subscale as a count -- its values are non-negative whole
# numbers -- and fits a Poisson model to a rating scale.
.scaffold_outcome_types <- function(questionnaires) {
  types <- .scaffold_score_columns(questionnaires)
  if (length(types) == 0) {
    # A behaviour-only study is a legitimate design; rep(",", -1) is not.
    return("  # (no questionnaire scores in this study)")
  }
  paste0(
    "  ", names(types), " = \"", unname(types), "\"",
    c(rep(",", length(types) - 1L), "")
  )
}


# Internal: a small example dataset with the columns the generated scripts
# expect -- a within-subjects study of three conditions -- plus item columns for
# each instrument, so tar_make() succeeds on a freshly scaffolded project.
.scaffold_example_csv <- function(questionnaires) {
  n_participants <- 12L
  conditions <- c("baseline", "ambient", "explicit")

  grid <- expand.grid(
    condition = conditions,
    participant = seq_len(n_participants),
    stringsAsFactors = FALSE
  )
  grid <- grid[order(grid$participant), c("participant", "condition")]
  n <- nrow(grid)

  # Deterministic pseudo-random responses: a scaffold that produces different
  # numbers on every call would make the example pipeline's own output churn.
  # Seeding is what makes the example data reproducible, but the seed belongs to
  # the scaffold, not to the caller's session: without this, scaffolding in the
  # middle of a script silently resets the user's RNG and every later draw
  # changes.
  if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    old_seed <- get(".Random.seed", envir = globalenv(), inherits = FALSE)
    on.exit(assign(".Random.seed", old_seed, envir = globalenv()), add = TRUE)
  } else {
    on.exit(
      suppressWarnings(rm(".Random.seed", envir = globalenv())),
      add = TRUE
    )
  }
  set.seed(20240101L)
  cond_effect <- stats::setNames(c(0, 0.4, 0.8), conditions)

  # Participants differ from one another, not just from condition to condition.
  # Without that between-participant variance the random intercept of the mixed
  # model the pipeline fits is estimated at zero, and the example project greets
  # a new user with a singular-fit warning on its very first run.
  person <- stats::setNames(stats::rnorm(n_participants, 0, 1), seq_len(n_participants))
  person_offset <- person[as.character(grid$participant)]

  cols <- list(
    participant = grid$participant,
    condition = grid$condition,
    completion_time = round(
      30 - 4 * cond_effect[grid$condition] + 3 * person_offset + stats::rnorm(n, 0, 1.5), 2
    )
  )

  for (q in questionnaires) {
    def <- .q_get(q)
    lo <- def$scale[1]
    hi <- def$scale[2]
    mid <- (lo + hi) / 2
    span <- hi - lo
    for (i in seq_len(nrow(def$items))) {
      # Apply the effects in the direction the item is SCORED in. A reverse-coded
      # item gets its sign flipped back during scoring, so adding the same effect
      # to every raw item makes the condition and participant effects cancel in
      # any balanced instrument -- the SUS reverses 5 of 10, which left the
      # scaffolded example with no signal and a singular-fit warning on its very
      # first run.
      direction <- if (isTRUE(def$items$reverse[i])) -1 else 1
      raw <- mid + direction * (
        cond_effect[grid$condition] * span / 6 + person_offset * span / 10
      ) + stats::rnorm(n, 0, span / 12)
      cols[[paste0(q, "_", i)]] <- pmin(pmax(round(raw), lo), hi)
    }

    # Real responses of a whole study reach both ends of a rating scale, and
    # score_questionnaire() warns when one end is never used, because that is
    # what a shifted coding looks like (an IPQ exported 1-7, a SUS exported
    # 0-4). Synthetic data drawn around the midpoint can miss an end, which
    # would greet a new project with that warning; give the first respondent's
    # first item each endpoint once instead.
    item_cols <- paste0(q, "_", seq_len(nrow(def$items)))
    values <- unlist(cols[item_cols], use.names = FALSE)
    if (!any(values == lo)) cols[[item_cols[1]]][1] <- lo
    if (!any(values == hi)) cols[[item_cols[1]]][2] <- hi
  }

  df <- as.data.frame(cols, stringsAsFactors = FALSE)
  utils::capture.output(utils::write.csv(df, row.names = FALSE))
}
