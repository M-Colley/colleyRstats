# Overleaf-oriented output helpers: ship the macro package into a project,
# generate variable-name macro stubs, define auto-syncing result macros, and
# bundle a whole analysis into an Overleaf-ready folder.


#' Write colleyRstats.sty into a project (for Overleaf)
#'
#' Copies the \pkg{colleyRstats} LaTeX macro package next to your manuscript so
#' the report output compiles with a single \code{\\usepackage{colleyRstats}}
#' -- no need to paste [latex_preamble()] into the preamble. Upload the written
#' \code{colleyRstats.sty} to your Overleaf project (or keep it in the same
#' folder as \code{main.tex}).
#'
#' @param dir Directory to write \code{colleyRstats.sty} into. Default the
#'   current working directory.
#' @param overwrite Overwrite an existing file? Default \code{FALSE}.
#'
#' @return Invisibly, the path to the written \code{.sty} file.
#' @export
#' @examples
#' use_colleyrstats_sty(tempdir(), overwrite = TRUE)
use_colleyrstats_sty <- function(dir = ".", overwrite = FALSE) {
  not_empty(dir)
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  }
  path <- file.path(dir, "colleyRstats.sty")
  if (file.exists(path) && !isTRUE(overwrite)) {
    stop("'", path, "' already exists; pass overwrite = TRUE to replace it.", call. = FALSE)
  }
  writeLines(.colley_sty_lines(), con = path)
  message("Wrote '", path, "'. Add \\usepackage{colleyRstats} to your document.")
  invisible(path)
}


# Internal: turn an arbitrary label into a valid (letters-only) LaTeX command
# name, e.g. "tlx_mental (T1)" -> "tlxMentalT1"... but digits are illegal in
# command names, so they are dropped too -> "tlxMentalT". CamelCases at every
# non-letter boundary.
.latex_cmd_name <- function(x) {
  x <- as.character(x)
  vapply(x, function(s) {
    parts <- strsplit(s, "[^A-Za-z]+")[[1]]
    parts <- parts[nzchar(parts)]
    if (length(parts) == 0) {
      return("result")
    }
    first <- parts[1]
    rest <- if (length(parts) > 1) {
      paste0(toupper(substring(parts[-1], 1, 1)), substring(parts[-1], 2))
    } else {
      character(0)
    }
    paste0(c(first, rest), collapse = "")
  }, character(1), USE.NAMES = FALSE)
}


#' Generate \\newcommand stubs for variable/factor names
#'
#' The report functions can emit variable and factor-level names as LaTeX
#' commands (e.g. \code{\\Video}) so their typography is controlled centrally.
#' This writes the matching \code{\\newcommand} definitions so those commands are
#' never undefined -- the classic "Undefined control sequence" that stops an
#' Overleaf build. Only names that are valid LaTeX command names (letters only)
#' get a macro; others are reported as skipped (the reporters emit those as
#' escaped plain text instead).
#'
#' @param vars Character vector of variable/level names (e.g. the columns you
#'   pass as \code{iv}/\code{dv}), or a named character vector / list mapping a
#'   name to the display label it should expand to.
#' @param path Optional \code{.tex}/\code{.sty} path to write the definitions to.
#' @param labels Optional named character vector mapping a name to its display
#'   label (overrides names taken from \code{vars}).
#'
#' @return Invisibly, the \code{\\newcommand} lines as a character vector; also
#'   emitted via \code{message()}.
#' @export
#' @examples
#' emit_name_macros(c("Video", "DriverPosition"))
#' emit_name_macros(c(tlxMental = "TLX Mental Demand"))
emit_name_macros <- function(vars, path = NULL, labels = NULL) {
  not_empty(vars)
  nm <- names(vars)
  vals <- as.character(unlist(vars))
  keys <- if (!is.null(nm) && all(nzchar(nm))) nm else vals
  if (!is.null(labels)) {
    override <- keys %in% names(labels)
    vals[override] <- unlist(labels[keys[override]])
  }

  valid <- grepl("^[A-Za-z]+$", keys)
  if (any(!valid)) {
    warning(
      "Skipped name(s) that are not valid LaTeX commands (letters only): ",
      paste(keys[!valid], collapse = ", "),
      ". The reporters emit these as escaped plain text instead.",
      call. = FALSE
    )
  }
  keys <- keys[valid]
  vals <- vals[valid]
  if (length(keys) == 0) {
    return(invisible(character(0)))
  }

  lines <- paste0("\\newcommand{\\", keys, "}{", latex_escape(vals), "}")
  message(paste(lines, collapse = "\n"))
  if (!is.null(path)) {
    dir <- dirname(path)
    if (!dir.exists(dir)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    writeLines(lines, con = path)
    message("Wrote name macros to '", path, "'.")
  }
  invisible(lines)
}


#' Define a named LaTeX macro for a single result (single source of truth)
#'
#' Emits \code{\\newcommand{\\<name>}{<value>}} so you can write \code{\\<name>}
#' in your prose and have it always reflect the latest analysis -- re-run the R
#' code and the number updates everywhere it is referenced, the gold standard
#' for reproducible manuscripts. The \code{name} is sanitised to a valid
#' letters-only LaTeX command name.
#'
#' @param name A label for the result, e.g. \code{"tlx_mental_omnibus"} (becomes
#'   \code{\\tlxMentalOmnibus}).
#' @param value The rendered result string, e.g. \code{"F(2, 57) = 4.50, p = .02"}.
#'   It is inserted verbatim (already-formatted LaTeX), not escaped.
#' @param path Optional \code{.tex} path. When supplied and it already exists,
#'   the definition is appended (so many results can accumulate in one file).
#'
#' @return Invisibly, a named character scalar: the \code{\\newcommand} line,
#'   named by the generated command. Also emitted via \code{message()}.
#' @export
#' @examples
#' define_result_macro("tlx_mental_omnibus", "F(2, 57) = 4.50, p = .02")
define_result_macro <- function(name, value, path = NULL) {
  not_empty(name)
  cmd <- .latex_cmd_name(name)
  line <- paste0("\\newcommand{\\", cmd, "}{", value, "}")
  message(line)
  if (!is.null(path)) {
    dir <- dirname(path)
    if (!dir.exists(dir)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    if (file.exists(path)) {
      cat(line, "\n", file = path, sep = "", append = TRUE)
    } else {
      writeLines(line, con = path)
    }
  }
  invisible(stats::setNames(line, cmd))
}


# Internal: coerce the many things a user might pass to emit_overleaf() into a
# uniform list of sections: name -> list(sentences = <chr>, plot = <ggplot|NULL>).
.as_overleaf_sections <- function(x) {
  pick <- function(a, b) if (!is.null(a)) a else b
  # a report_all() result
  if (is.list(x) && !is.null(x$results) && is.list(x$results)) {
    return(lapply(x$results, function(r) {
      list(sentences = pick(r$sentences, r$text), plot = r$plot)
    }))
  }
  # a single analyze_and_report() result
  if (is.list(x) && !is.null(x$sentences)) {
    return(list(result = list(sentences = x$sentences, plot = x$plot)))
  }
  # a named list of character vectors (or a single character vector)
  if (is.character(x)) {
    return(list(result = list(sentences = x, plot = NULL)))
  }
  if (is.list(x)) {
    nm <- names(x)
    if (is.null(nm) || any(!nzchar(nm))) {
      stop("`x` must be a named list of sentence vectors (or a report_all()/analyze_and_report() result).", call. = FALSE)
    }
    return(lapply(x, function(el) {
      if (is.list(el)) list(sentences = pick(el$sentences, el$text), plot = el$plot) else list(sentences = as.character(el), plot = NULL)
    }))
  }
  stop("Unsupported input to emit_overleaf().", call. = FALSE)
}


# Internal: for every "\Name" control sequence in the text that is NOT one of
# the built-in colleyRstats stat macros, emit a \providecommand{\Name}{Name}
# stub. \providecommand only defines a command that is currently undefined, so
# real LaTeX commands (\times, \chi, ...) are left untouched while an author's
# name macros (\Video, \DriverPosition) never trigger "Undefined control
# sequence" in the generated standalone document.
.name_command_stubs <- function(text) {
  known <- c("F", "p", "pminor", "padj", "padjminor", "m", "sd", "df", "chisq", "rankbiserial", "effectsize")
  toks <- unlist(regmatches(text, gregexpr("\\\\[A-Za-z]+", text)))
  if (length(toks) == 0) {
    return(character(0))
  }
  toks <- unique(sub("^\\\\", "", toks))
  toks <- setdiff(toks, known)
  if (length(toks) == 0) {
    return(character(0))
  }
  paste0("\\providecommand{\\", toks, "}{", toks, "}")
}


#' Bundle an analysis into an Overleaf-ready folder
#'
#' Writes everything a manuscript needs into one directory you can drag into
#' Overleaf and compile immediately: a \code{main.tex} that already
#' \code{\\input}s the results, one \code{.tex} per result section, the figures,
#' a \code{references.bib}, and -- unless macros are expanded inline --
#' \code{colleyRstats.sty}. This is the one-call end of the "R analysis to
#' compiled PDF" pipeline.
#'
#' @param x What to emit. Accepts a [report_all()] result (one section per
#'   dependent variable, with figures), an [analyze_and_report()] result, a
#'   named list of sentence vectors, or a single character vector.
#' @param dir Output directory (created if needed).
#' @param figures Whether to save figures for sections that carry a plot.
#'   Default \code{TRUE}.
#' @param methods Methods to cite (passed to [cite_methods()]) for
#'   \code{references.bib}; \code{NULL} to skip the bibliography.
#' @param title Title used in the generated \code{main.tex}. Default
#'   \code{"Results"}.
#' @param plain Whether to expand the colleyRstats macros to plain LaTeX (so no
#'   \code{.sty} / \code{\\usepackage} is needed). Default \code{NULL} follows
#'   \code{getOption("colleyRstats.macros")} (i.e. plain when that is
#'   \code{FALSE}).
#' @param columns Figure width preset passed to [save_paper_figure()].
#' @param overwrite Overwrite existing files in \code{dir}? Default \code{FALSE}.
#'
#' @return Invisibly, a list with the paths written (\code{dir}, \code{main},
#'   \code{results}, \code{sections}, \code{figures}, \code{bib}, \code{sty}).
#' @export
#' @examples
#' \donttest{
#' out <- report_all(mtcars, dvs = c("mpg", "disp"), iv = "cyl")
#' emit_overleaf(out, dir = file.path(tempdir(), "paper"), overwrite = TRUE)
#' }
emit_overleaf <- function(x, dir, figures = TRUE, methods = c("ggstatsplot", "effectsize"),
                          title = "Results", plain = NULL, columns = 1, overwrite = FALSE) {
  not_empty(dir)
  sections <- .as_overleaf_sections(x)
  if (length(sections) == 0) stop("Nothing to emit: no sections found in `x`.", call. = FALSE)

  plain <- if (is.null(plain)) !isTRUE(getOption("colleyRstats.macros", TRUE)) else isTRUE(plain)

  sec_dir <- file.path(dir, "sections")
  fig_dir <- file.path(dir, "figures")
  dir.create(sec_dir, recursive = TRUE, showWarnings = FALSE)
  guard <- function(p) if (file.exists(p) && !isTRUE(overwrite)) {
    stop("'", p, "' already exists; pass overwrite = TRUE.", call. = FALSE)
  }

  written <- list(dir = dir, sections = character(0), figures = character(0),
                  main = NULL, results = NULL, bib = NULL, sty = NULL)

  # 1. the macro package (unless macros are expanded inline)
  if (!plain) {
    sty <- file.path(dir, "colleyRstats.sty")
    guard(sty)
    writeLines(.colley_sty_lines(), con = sty)
    written$sty <- sty
  }

  results_body <- paste0("\\section*{", latex_escape(title), "}")
  keys <- names(sections)
  if (is.null(keys)) keys <- paste0("section", seq_along(sections))
  all_bodies <- character(0)

  for (i in seq_along(sections)) {
    key <- keys[[i]]
    sec <- sections[[i]]
    base <- .latex_cmd_name(key)
    if (!nzchar(base)) base <- paste0("section", i)

    # section .tex (macros expanded when plain)
    body <- paste(sec$sentences, collapse = "\n")
    if (plain) body <- expand_latex_macros(body)
    all_bodies <- c(all_bodies, body)
    sp <- file.path(sec_dir, paste0(base, ".tex"))
    guard(sp)
    writeLines(body, con = sp)
    written$sections <- c(written$sections, sp)

    results_body <- c(
      results_body,
      paste0("\\subsection*{", latex_escape(key), "}"),
      paste0("\\input{sections/", base, "}")
    )

    # optional figure
    if (isTRUE(figures) && !is.null(sec$plot) && inherits(sec$plot, "ggplot")) {
      fp <- file.path(fig_dir, paste0(base, ".pdf"))
      dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
      guard(fp)
      ok <- tryCatch({
        suppressMessages(save_paper_figure(sec$plot, fp, columns = columns))
        TRUE
      }, error = function(e) {
        warning("Could not save figure for section '", key, "': ", conditionMessage(e), call. = FALSE)
        FALSE
      })
      if (ok) {
        written$figures <- c(written$figures, fp)
        results_body <- c(
          results_body,
          "\\begin{figure}[ht]\\centering",
          paste0("\\includegraphics[width=\\linewidth]{figures/", base, "}"),
          paste0("\\caption{", latex_escape(key), "}\\end{figure}")
        )
      }
    }
  }

  # 2. references.bib
  if (!is.null(methods) && length(methods) > 0) {
    bib <- file.path(dir, "references.bib")
    guard(bib)
    entries <- tryCatch(suppressMessages(cite_methods(methods, bibtex = TRUE)),
                        error = function(e) character(0))
    entries <- entries[!grepl("^% ", entries)] # drop the "% pkg: note" comment lines
    writeLines(entries, con = bib)
    written$bib <- bib
  }

  # 3. name-macro stubs so any \Video-style command in the text is defined
  stubs <- .name_command_stubs(paste(all_bodies, collapse = "\n"))
  if (length(stubs) > 0) {
    names_tex <- file.path(dir, "names.tex")
    guard(names_tex)
    writeLines(c("% Auto-generated \\providecommand stubs for variable/level names.", stubs), con = names_tex)
    written$names <- names_tex
    results_body <- c("\\input{names}", results_body)
  }

  # 4. results.tex
  results <- file.path(dir, "results.tex")
  guard(results)
  writeLines(results_body, con = results)
  written$results <- results

  # 5. main.tex -- a minimal, self-contained, compilable document
  main <- file.path(dir, "main.tex")
  guard(main)
  preamble_pkg <- if (!plain) "\\usepackage{colleyRstats}" else "% (macros expanded inline; no colleyRstats.sty needed)"
  bib_lines <- if (!is.null(written$bib)) {
    c("\\bibliographystyle{plain}", "\\bibliography{references}")
  } else {
    character(0)
  }
  main_body <- c(
    "\\documentclass{article}",
    "\\usepackage{graphicx}",
    "\\usepackage{booktabs}",
    "\\usepackage[margin=1in]{geometry}",
    preamble_pkg,
    paste0("\\title{", latex_escape(title), "}"),
    "\\begin{document}",
    "\\maketitle",
    "\\input{results}",
    bib_lines,
    "\\end{document}"
  )
  writeLines(main_body, con = main)
  written$main <- main

  message("Wrote an Overleaf-ready project to '", dir, "' (", length(sections),
    " section", if (length(sections) == 1) "" else "s",
    if (plain) "; macros expanded inline)." else "; \\usepackage{colleyRstats}).")
  invisible(written)
}
