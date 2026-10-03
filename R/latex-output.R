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


# Internal: an arbitrary label transliterated to ASCII where the platform can
# ("Zufriedenheit_ä" -> "Zufriedenheit_a"), so neither a command name nor a file
# name silently loses a letter. Anything iconv cannot map stays a non-ASCII
# character, which the callers then treat as a separator.
.ascii_label <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  out <- suppressWarnings(iconv(enc2utf8(x), "UTF-8", "ASCII//TRANSLIT", sub = ""))
  out[is.na(out)] <- x[is.na(out)]
  out
}

.DIGIT_WORDS <- c("Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine")

# Internal: turn an arbitrary label into a letters-only LaTeX command name,
# camel-casing at every boundary: "tlx_mental (T1)" -> "tlxMentalTOne". Digits
# are illegal in a command name, but dropping them (as this function used to)
# maps "tlx_1" and "tlx_2" -- or "Q1" and "Q2" -- onto the same command, so the
# second result silently replaced the first. Each digit is spelled out instead.
# Whether the result is safe to define is a separate question, answered by
# .latex_name_ok(): "p" passes this function unchanged but is the package's own
# \p.
.latex_cmd_name <- function(x) {
  vapply(.ascii_label(x), function(s) {
    s <- gsub("([0-9])", " \\1 ", s, perl = TRUE)
    parts <- strsplit(s, "[^A-Za-z0-9]+", perl = TRUE)[[1]]
    parts <- parts[nzchar(parts)]
    if (length(parts) == 0) {
      return("result")
    }
    digit <- grepl("^[0-9]$", parts)
    parts[digit] <- .DIGIT_WORDS[as.integer(parts[digit]) + 1L]
    if (digit[1]) parts[1] <- tolower(parts[1])
    rest <- parts[-1]
    rest <- paste0(toupper(substring(rest, 1, 1)), substring(rest, 2))
    paste0(c(parts[1], rest), collapse = "")
  }, character(1), USE.NAMES = FALSE)
}

# Internal: the names of the colleyRstats stat macros, read from their single
# source of truth so this list can never fall behind it.
.colley_macro_names <- function() {
  lines <- .colley_macro_lines()
  regmatches(lines, regexpr("(?<=\\\\newcommand\\{\\\\)[A-Za-z]+", lines, perl = TRUE))
}

# Windows cannot create a file with one of these names, whatever the extension.
.WINDOWS_DEVICE_NAMES <- c("con", "prn", "aux", "nul", paste0("com", 1:9), paste0("lpt", 1:9))

# Internal: make `x` unique ignoring case ("Q", "Q-2", "Q-3"), because the
# file systems of Windows and macOS do: "MPG.tex" and "mpg.tex" are one file
# there.
.make_unique_nocase <- function(x) {
  seen <- character(0)
  for (i in seq_along(x)) {
    cand <- x[i]
    k <- 1L
    while (tolower(cand) %in% seen) {
      k <- k + 1L
      cand <- paste0(x[i], "-", k)
    }
    x[i] <- cand
    seen <- c(seen, tolower(cand))
  }
  x
}

# Internal: file base names (no extension) for labels such as section keys.
# Unlike a command name a file name may keep its digits, so "Q1" and "Q2" stay
# "Q1" and "Q2" -- deriving file names from .latex_cmd_name() used to send both
# to "Q.tex", one overwriting the other. Only ASCII letters, digits and "-"
# survive: those are safe in \input and \includegraphics on every TeX engine,
# whereas a space, a second dot (taken as the extension by graphicx) or "#"/"%"
# are not. Empty results fall back to "<fallback><position>", Windows device
# names get a suffix, and the names are made unique.
.latex_file_name <- function(x, fallback = "section") {
  out <- gsub("[^A-Za-z0-9]+", "-", .ascii_label(x), perl = TRUE)
  out <- gsub("^-+|-+$", "", out)
  empty <- !nzchar(out)
  out[empty] <- paste0(fallback, which(empty))
  device <- tolower(out) %in% .WINDOWS_DEVICE_NAMES
  out[device] <- paste0(out[device], "-file")
  .make_unique_nocase(out)
}


#' Generate \\newcommand stubs for variable/factor names
#'
#' The report functions can emit variable and factor-level names as LaTeX
#' commands (e.g. \code{\\Video}) so their typography is controlled centrally.
#' This writes the matching \code{\\newcommand} definitions so those commands are
#' never undefined -- the classic "Undefined control sequence" that stops an
#' Overleaf build. A name gets a macro only when it can safely become a new
#' command: letters only, and not already a LaTeX command. \code{time},
#' \code{L} or \code{small}, for instance, are TeX/LaTeX commands already, so
#' \code{\\newcommand{\\time}} would stop the build ("Command \\time already
#' defined") and redefining them would break LaTeX itself; names starting with
#' \code{end} are refused by LaTeX too. Such names are skipped with a warning,
#' and the reporters emit them as escaped plain text instead.
#'
#' @param vars Character vector of variable/level names (e.g. the columns you
#'   pass as \code{iv}/\code{dv}), or a named character vector / list mapping a
#'   name to the display label it should expand to (unnamed elements are their
#'   own label).
#' @param path Optional \code{.tex}/\code{.sty} path to write the definitions to.
#' @param labels Optional named character vector mapping a name to its display
#'   label (overrides names taken from \code{vars}).
#'
#' @return Invisibly, the \code{\\newcommand} lines as a character vector (one
#'   per distinct name); also emitted via \code{message()}.
#' @export
#' @examples
#' emit_name_macros(c("Video", "DriverPosition"))
#' emit_name_macros(c(tlxMental = "TLX Mental Demand"))
emit_name_macros <- function(vars, path = NULL, labels = NULL) {
  not_empty(vars)
  nm <- names(vars)
  vals <- as.character(unlist(vars))
  keys <- vals
  if (!is.null(nm)) {
    # per element: c(tlxMental = "TLX Mental Demand", "Video") names the first
    # and lets the second stand for itself
    named <- !is.na(nm) & nzchar(nm)
    keys[named] <- nm[named]
  }
  if (!is.null(labels)) {
    override <- keys %in% names(labels)
    vals[override] <- unlist(labels[keys[override]])
  }

  syntax_ok <- grepl("^[A-Za-z]+$", keys)
  if (any(!syntax_ok)) {
    warning(
      "Skipped name(s) that are not valid LaTeX commands (letters only): ",
      paste(keys[!syntax_ok], collapse = ", "),
      ". The reporters emit these as escaped plain text instead.",
      call. = FALSE
    )
  }
  reserved <- syntax_ok & !.latex_name_ok(keys)
  if (any(reserved)) {
    warning(
      "Skipped name(s) that are already LaTeX commands (or start with \"end\", ",
      "which LaTeX reserves): ", paste(keys[reserved], collapse = ", "),
      ". \\newcommand would stop the build (\"Command ... already defined\"), and ",
      "redefining them would change what LaTeX itself means by them. The ",
      "reporters emit these names as escaped plain text instead.",
      call. = FALSE
    )
  }
  keep <- syntax_ok & !reserved
  keys <- keys[keep]
  vals <- vals[keep]

  # A second \newcommand for the same name is itself a compile error, which a
  # factor level shared by two variables would otherwise produce.
  dup <- duplicated(keys)
  if (any(dup)) {
    clash <- unique(keys[dup][vals[dup] != vals[match(keys[dup], keys)]])
    if (length(clash) > 0) {
      warning(
        "Name(s) given more than once with different labels: ",
        paste(clash, collapse = ", "), ". Kept the first label for each.",
        call. = FALSE
      )
    }
    keys <- keys[!dup]
    vals <- vals[!dup]
  }
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
#' for reproducible manuscripts. The \code{name} is sanitised to a letters-only
#' LaTeX command name: other characters start a new camel-case word and digits
#' are spelled out, so \code{"tlx_1"} and \code{"tlx_2"} become \code{\\tlxOne}
#' and \code{\\tlxTwo} rather than colliding. A name that would redefine an
#' existing LaTeX or \pkg{colleyRstats} command (e.g. \code{"p"}, which is the
#' package's own \code{\\p}, or \code{"time"}) is refused with an error that
#' suggests an alternative.
#'
#' @param name A label for the result, e.g. \code{"tlx_mental_omnibus"} (becomes
#'   \code{\\tlxMentalOmnibus}).
#' @param value The rendered result string, e.g. \code{"F(2, 57) = 4.50, p = .02"}.
#'   It is inserted verbatim (already-formatted LaTeX), not escaped. Several
#'   strings are joined with spaces, and line breaks become spaces, so each
#'   definition occupies exactly one line.
#' @param path Optional \code{.tex} path. When it already exists, the
#'   definition is added to it (so many results can accumulate in one file); a
#'   definition of the same command already in the file is replaced rather than
#'   duplicated, because a second \code{\\newcommand} for one name stops the
#'   build. Each line ends in a \code{\%} comment naming the label it came
#'   from, so that a different label mapping to the same command (\code{"tlx1"}
#'   and \code{"tlx_1"} are both \code{\\tlxOne}) is reported when it replaces
#'   the other's result.
#'
#' @return Invisibly, a named character scalar: the \code{\\newcommand} line,
#'   named by the generated command. Also emitted via \code{message()}.
#' @export
#' @examples
#' define_result_macro("tlx_mental_omnibus", "F(2, 57) = 4.50, p = .02")
define_result_macro <- function(name, value, path = NULL) {
  not_empty(name)
  if (length(name) != 1L) {
    stop("`name` must be a single string.", call. = FALSE)
  }
  cmd <- .latex_cmd_name(name)
  if (!.latex_name_ok(cmd)) {
    suggestion <- paste0("result", toupper(substring(cmd, 1, 1)), substring(cmd, 2))
    stop(
      "define_result_macro(): the name '", name, "' becomes \\", cmd,
      ", which is already a LaTeX or colleyRstats command (or starts with \"end\", ",
      "which LaTeX reserves); \\newcommand{\\", cmd, "} would stop the build ",
      "(\"Command \\", cmd, " already defined\"). Use a more specific name, e.g. '",
      suggestion, "'.",
      call. = FALSE
    )
  }
  value <- gsub("[\r\n]+", " ", paste(as.character(value), collapse = " "))
  label <- gsub("[\r\n]+", " ", as.character(name))
  line <- paste0("\\newcommand{\\", cmd, "}{", value, "}% ", label)
  message(line)
  if (!is.null(path)) {
    dir <- dirname(path)
    if (!dir.exists(dir)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    lines <- if (file.exists(path)) readLines(path, warn = FALSE) else character(0)
    defines <- grepl(
      paste0("^\\s*\\\\(?:newcommand|renewcommand|providecommand)\\*?\\s*\\{?\\\\", cmd, "(?![A-Za-z])"),
      lines, perl = TRUE
    )
    if (any(defines)) {
      old_label <- sub("^.*\\}% ", "", lines[defines][1])
      if (grepl("\\}% ", lines[defines][1]) && !identical(old_label, label)) {
        warning(
          "define_result_macro(): \\", cmd, " in '", path, "' held the result for '",
          old_label, "'; it now holds the result for '", label, "'. Use labels that ",
          "differ in their letters or digits to keep both.",
          call. = FALSE
        )
      }
      first <- which(defines)[1]
      lines[first] <- line
      extra <- setdiff(which(defines), first)
      if (length(extra) > 0) lines <- lines[-extra]
    } else {
      lines <- c(lines, line)
    }
    writeLines(lines, con = path)
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


# Internal: the names of all "\Name" control sequences (letters only) in `text`.
.control_words <- function(text) {
  toks <- unlist(regmatches(text, gregexpr("\\\\[A-Za-z]+", text)))
  unique(sub("^\\\\", "", toks))
}

# Internal: the author's name macros in `text` (\Video, \DriverPosition): every
# control word that is neither a colleyRstats stat macro nor an existing LaTeX
# command. Existing commands (\times, \chi, \textit, and \time or \L, which
# .tex_name() never emits but an author's text may contain) are left out: a
# stub for them could only ever be a no-op, and a name beginning with "end" is
# refused by \providecommand outright.
.name_macro_tokens <- function(text) {
  toks <- setdiff(.control_words(text), .colley_macro_names())
  toks[.latex_name_ok(toks)]
}

# Internal: a \providecommand{\Name}{Name} stub for every name macro in the
# text. \providecommand defines a command only when it is undefined, so an
# author's own definition of \Video wins, while the generated standalone
# document never stops with "Undefined control sequence".
.name_command_stubs <- function(text) {
  toks <- .name_macro_tokens(text)
  if (length(toks) == 0) {
    return(character(0))
  }
  paste0("\\providecommand{\\", toks, "}{", toks, "}")
}

# Internal: "\cyl on mpg" typesets as "cylon mpg", because TeX ends a control
# word at the first non-letter and then skips the spaces after it. Writing
# "\cyl{} on" keeps the space and means the same thing otherwise. Applied to the
# name macros only: the stat macros always take a braced argument.
.protect_macro_spaces <- function(text, names) {
  for (nm in names) {
    text <- gsub(paste0("\\\\", nm, "(?=\\s)"), paste0("\\\\", nm, "{}"), text, perl = TRUE)
  }
  text
}

# Internal: \providecommand definitions for the colleyRstats macros still left
# in plain-mode text. expand_latex_macros() rewrites every macro whose
# arguments are brace-free, which is all the reporters produce; a hand-written
# "\m{\textit{x}}" is not, and would otherwise be an undefined command in a
# project that ships no colleyRstats.sty.
.leftover_macro_definitions <- function(text) {
  lines <- .colley_macro_lines()
  defined <- sub("^\\\\newcommand\\{\\\\([A-Za-z]+)\\}.*$", "\\1", lines)
  left <- lines[defined %in% .control_words(text)]
  sub("^\\\\newcommand", "\\\\providecommand", left)
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
#' Section keys become file names with only letters, digits and hyphens kept
#' (\code{"tlx_1"} is written to \code{sections/tlx-1.tex}); keys that would
#' share a file name -- including names differing only in case, which Windows
#' and macOS treat as one file -- get a numbered suffix, so no section can
#' overwrite another. The keys themselves are escaped with [latex_escape()]
#' wherever they are typeset (headings, captions). Name macros in the text
#' (\code{\\Video}) get \code{\\providecommand} stubs in \code{names.tex}, and a
#' \code{{}} where a space follows them, because TeX would otherwise swallow
#' that space ("\code{\\cyl on}" typesets as "cylon").
#'
#' @param x What to emit. Accepts a [report_all()] result (one section per
#'   dependent variable, with figures), an [analyze_and_report()] result, a
#'   named list of sentence vectors, or a single character vector.
#' @param dir Output directory (created if needed).
#' @param figures Whether to save figures for sections that carry a plot.
#'   Default \code{TRUE}.
#' @param methods Methods to cite (passed to [cite_methods()]) for
#'   \code{references.bib}; \code{NULL} to skip the bibliography. Every entry is
#'   listed via \code{\\nocite{*}}, since the generated text cites nothing and
#'   BibTeX writes an empty bibliography without a citation. When none of the
#'   methods can be cited (their packages are not installed), no
#'   \code{references.bib} is written, with a warning.
#' @param title Title used in the generated \code{main.tex}. Default
#'   \code{"Results"}.
#' @param plain Whether to expand the colleyRstats macros to plain LaTeX (so no
#'   \code{.sty} / \code{\\usepackage} is needed). Default \code{NULL} follows
#'   \code{getOption("colleyRstats.macros")} (i.e. plain when that is
#'   \code{FALSE}).
#' @param columns Figure width preset passed to [save_paper_figure()]. A
#'   single-column figure is included at its natural size, because
#'   [save_paper_figure()] chose its type size for exactly that width (scaling
#'   it to the line width would enlarge the text with it); a full-width figure
#'   (\code{columns = 2}) goes into a \code{figure*} at \code{\\textwidth}.
#' @param overwrite Overwrite existing files in \code{dir}? Default
#'   \code{FALSE}: if any file the project consists of already exists, nothing
#'   is written.
#'
#' @return Invisibly, a list with the paths written (\code{dir}, \code{main},
#'   \code{results}, \code{sections}, \code{figures}, \code{bib}, \code{sty},
#'   \code{names}); \code{bib}, \code{sty} and \code{names} are \code{NULL}
#'   when the file was not needed.
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
  if (length(columns) != 1L || !columns %in% c(1, 2)) {
    stop("`columns` must be 1 (single column) or 2 (full width).", call. = FALSE)
  }

  plain <- if (is.null(plain)) !isTRUE(getOption("colleyRstats.macros", TRUE)) else isTRUE(plain)

  # ---- 1. compose the whole project in memory ------------------------------
  # Nothing is written until every target path is known and checked, so a
  # refusal to overwrite leaves no half-written project behind.
  keys <- names(sections)
  if (is.null(keys)) keys <- rep("", length(sections))
  keys[is.na(keys)] <- ""
  keys[!nzchar(keys)] <- paste0("section", which(!nzchar(keys)))
  bases <- .latex_file_name(keys)

  bodies <- vapply(sections, function(sec) {
    paste(as.character(sec$sentences), collapse = "\n")
  }, character(1), USE.NAMES = FALSE)
  if (plain) bodies <- expand_latex_macros(bodies)
  name_macros <- .name_macro_tokens(bodies)
  bodies <- .protect_macro_spaces(bodies, name_macros)
  stubs <- .name_command_stubs(bodies)
  if (plain) stubs <- c(stubs, .leftover_macro_definitions(bodies))

  want_fig <- isTRUE(figures) &
    vapply(sections, function(sec) inherits(sec$plot, "ggplot"), logical(1), USE.NAMES = FALSE)

  entries <- character(0)
  if (!is.null(methods) && length(methods) > 0) {
    entries <- suppressMessages(cite_methods(methods, bibtex = TRUE))
    entries <- entries[!grepl("^% ", entries)] # drop the "% pkg: note" comment lines
    if (!any(grepl("^@", entries))) {
      # an empty references.bib gives an empty thebibliography environment,
      # which older LaTeX kernels reject outright
      warning(
        "None of the methods (", paste(methods, collapse = ", "), ") could be cited ",
        "-- are their packages installed? No references.bib was written.",
        call. = FALSE
      )
      entries <- character(0)
    }
  }

  paths <- list(
    sty = if (!plain) file.path(dir, "colleyRstats.sty"),
    sections = file.path(dir, "sections", paste0(bases, ".tex")),
    figures = file.path(dir, "figures", paste0(bases, ".pdf")),
    bib = if (length(entries) > 0) file.path(dir, "references.bib"),
    names = if (length(stubs) > 0) file.path(dir, "names.tex"),
    results = file.path(dir, "results.tex"),
    main = file.path(dir, "main.tex")
  )
  if (!isTRUE(overwrite)) {
    planned <- c(paths$sty, paths$sections, paths$figures[want_fig], paths$bib,
                 paths$names, paths$results, paths$main)
    existing <- planned[file.exists(planned)]
    if (length(existing) > 0) {
      stop(
        paste0("'", existing, "'", collapse = ", "),
        if (length(existing) == 1) " already exists" else " already exist",
        "; pass overwrite = TRUE. Nothing was written.",
        call. = FALSE
      )
    }
  }

  # ---- 2. write ------------------------------------------------------------
  dir.create(file.path(dir, "sections"), recursive = TRUE, showWarnings = FALSE)
  written <- list(dir = dir, sections = character(0), figures = character(0),
                  main = NULL, results = NULL, bib = NULL, sty = NULL, names = NULL)

  # the macro package (unless macros are expanded inline)
  if (!plain) {
    writeLines(.colley_sty_lines(), con = paths$sty)
    written$sty <- paths$sty
  }

  results_body <- c(
    if (length(stubs) > 0) "\\input{names}",
    paste0("\\section*{", latex_escape(title), "}")
  )
  for (i in seq_along(sections)) {
    writeLines(bodies[i], con = paths$sections[i])
    written$sections <- c(written$sections, paths$sections[i])
    results_body <- c(
      results_body,
      paste0("\\subsection*{", latex_escape(keys[i]), "}"),
      paste0("\\input{sections/", bases[i], "}")
    )

    if (want_fig[i]) {
      fp <- paths$figures[i]
      ok <- tryCatch({
        suppressMessages(save_paper_figure(sections[[i]]$plot, fp, columns = columns))
        TRUE
      }, error = function(e) {
        warning("Could not save figure for section '", keys[i], "': ", conditionMessage(e), call. = FALSE)
        FALSE
      })
      if (ok) {
        written$figures <- c(written$figures, fp)
        env <- if (columns == 2) "figure*" else "figure"
        graphic <- if (columns == 2) {
          paste0("\\includegraphics[width=\\textwidth]{figures/", bases[i], "}")
        } else {
          paste0("\\includegraphics{figures/", bases[i], "}")
        }
        results_body <- c(
          results_body,
          paste0("\\begin{", env, "}[ht]"),
          "\\centering",
          graphic,
          paste0("\\caption{", latex_escape(keys[i]), "}"),
          paste0("\\label{fig:", bases[i], "}"),
          paste0("\\end{", env, "}")
        )
      }
    }
  }

  if (!is.null(paths$bib)) {
    writeLines(entries, con = paths$bib)
    written$bib <- paths$bib
  }

  # stubs so any \Video-style command in the text is defined
  if (!is.null(paths$names)) {
    writeLines(c("% Auto-generated \\providecommand stubs for variable/level names.", stubs),
               con = paths$names)
    written$names <- paths$names
  }

  writeLines(results_body, con = paths$results)
  written$results <- paths$results

  # main.tex -- a minimal, self-contained, compilable document
  main <- paths$main
  preamble_pkg <- if (!plain) "\\usepackage{colleyRstats}" else "% (macros expanded inline; no colleyRstats.sty needed)"
  bib_lines <- if (!is.null(written$bib)) {
    c(
      # the generated text contains no \cite, and without one BibTeX writes an
      # empty bibliography ("I found no \citation commands")
      "\\nocite{*}",
      "\\bibliographystyle{plain}",
      "\\bibliography{references}"
    )
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
    "\\author{}", # \maketitle warns "No \author given" otherwise
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
