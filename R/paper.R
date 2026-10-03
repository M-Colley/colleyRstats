#' LaTeX preamble required by the report functions
#'
#' All report functions emit LaTeX text that relies on a small set of custom
#' commands. This helper prints the complete set, ready to paste into a
#' manuscript preamble, or writes it to a file that can be included with
#' \code{\\input{}} (or renamed to \code{.sty} and loaded via
#' \code{\\usepackage}).
#'
#' @param path Optional path of a \code{.tex} file to write the definitions to.
#'   If the path ends in \code{.sty}, a \code{\\ProvidesPackage} header is added
#'   so it can be uploaded to Overleaf and loaded with
#'   \code{\\usepackage{colleyRstats}} (see also [use_colleyrstats_sty()]).
#'
#' @return Invisibly returns the macro definitions as a character vector;
#'   the text is also emitted via \code{message()}.
#' @export
#'
#' @examples
#' latex_preamble()
latex_preamble <- function(path = NULL) {
  as_sty <- !is.null(path) && grepl("\\.sty$", path, ignore.case = TRUE)
  macros <- if (as_sty) {
    # \ProvidesPackage must carry the file's own name, or LaTeX warns
    # "You have requested package `x', but the package provides `colleyRstats'"
    .colley_sty_lines(sub("\\.sty$", "", basename(path), ignore.case = TRUE))
  } else {
    c("% colleyRstats: LaTeX commands required by the report functions", .colley_macro_lines())
  }

  message(paste(macros, collapse = "\n"))
  if (!is.null(path)) {
    # Write verbatim: these ARE the macro definitions, so they must never be run
    # through the plain-mode macro expander that .write_tex() applies.
    dir <- dirname(path)
    if (!dir.exists(dir)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    writeLines(paste(macros, collapse = "\n"), con = path)
    message("Wrote preamble to '", path, "'.")
  }
  invisible(macros)
}


# Internal: the single source of truth for the report macros. Both
# latex_preamble() and the shipped inst/colleyRstats.sty derive from this, so
# they can never drift apart (a test asserts the .sty matches).
.colley_macro_lines <- function() {
  c(
    "\\newcommand{\\F}[3]{$F({#1},{#2})={#3}$}",
    "\\newcommand{\\p}{\\textit{p=}}",
    "\\newcommand{\\pminor}{\\textit{p$<$}}",
    "\\newcommand{\\padj}{\\textit{p$_{adj}$=}}",
    "\\newcommand{\\padjminor}{\\textit{p$_{adj}<$}}",
    "\\newcommand{\\m}{\\textit{M=}}",
    "\\newcommand{\\sd}{\\textit{SD=}}",
    "\\newcommand{\\df}{\\textit{df=}}",
    "\\newcommand{\\chisq}{$\\chi^2$}",
    "\\newcommand{\\mdn}{\\textit{Mdn=}}",
    "\\newcommand{\\iqr}{\\textit{IQR=}}",
    "\\newcommand{\\rankbiserial}[1]{$r_{rb} = #1$}",
    "\\newcommand{\\effectsize}{\\textit{r=}}"
  )
}

# Internal: the macro lines wrapped as a LaTeX package (colleyRstats.sty, or
# <name>.sty when latex_preamble() writes it under another name).
.colley_sty_lines <- function(name = "colleyRstats") {
  c(
    paste0("% ", name, ".sty -- macros required by the colleyRstats report functions."),
    paste0("% Upload to Overleaf and load with \\usepackage{", name, "}."),
    "\\NeedsTeXFormat{LaTeX2e}",
    paste0("\\ProvidesPackage{", name, "}[colleyRstats reporting macros]"),
    .colley_macro_lines(),
    "\\endinput"
  )
}


#' Save a plot with publication-ready defaults
#'
#' Saves a ggplot with sizes matching common two-column conference/journal
#' layouts (e.g., ACM): a single-column figure is 3.33 in wide, a full-width
#' figure 7 in. On Windows and Linux, PDFs are rendered with
#' \code{grDevices::cairo_pdf} so that fonts are embedded and unicode glyphs
#' survive; on macOS the default pdf device is used instead, because R's
#' cairo on macOS is known to crash some setups (e.g., GitHub Actions
#' runners) and the macOS device handles fonts well on its own.
#'
#' @param plot The plot to save (defaults to the last plot displayed).
#' @param filename Output path; the extension selects the device
#'   (\code{.pdf} is recommended for LaTeX).
#' @param columns 1 for a single-column figure, 2 for a full-width figure.
#'   Ignored when \code{width} is given.
#' @param width Figure width in inches; overrides \code{columns}.
#' @param height Figure height in inches. Defaults to 2/3 of the width.
#' @param base_size Base font size in points for the saved figure, applied via
#'   [colley_theme()] sizing on top of whatever theme the plot carries. The
#'   default \code{NULL} derives it from \code{width}, so a 3.33 in figure gets
#'   about 7 pt and a 7 in figure about 9 pt -- close to the body text of a
#'   typical two-column paper, which is what makes a figure legible at 100\%
#'   rather than only when zoomed. Pass a number to choose it yourself, or
#'   \code{NA} to leave the plot's own text sizes untouched.
#' @param dpi Resolution for raster output. Default 300.
#' @param device Graphics device passed to [ggplot2::ggsave()]. The default
#'   \code{NULL} selects it automatically as described above; pass e.g.
#'   \code{grDevices::cairo_pdf} explicitly to override.
#'
#' @return Invisibly returns \code{filename}.
#' @export
#'
#' @examples
#' \donttest{
#' p <- ggplot2::ggplot(mtcars, ggplot2::aes(factor(cyl), mpg)) +
#'   ggplot2::geom_boxplot()
#' save_paper_figure(p, file.path(tempdir(), "cyl-mpg.pdf"), columns = 1)
#' }
save_paper_figure <- function(plot = ggplot2::last_plot(), filename, columns = 1, width = NULL, height = NULL, base_size = NULL, dpi = 300, device = NULL) {
  not_empty(filename)

  # `columns` only matters when it decides the width; documented as ignored
  # otherwise, so it is validated only then.
  if (is.null(width)) {
    if (length(columns) != 1L || !columns %in% c(1, 2)) {
      stop("`columns` must be 1 (single column) or 2 (full width).")
    }
    width <- if (columns == 1) 3.33 else 7
  }
  if (is.null(height)) {
    height <- width * 2 / 3
  }

  # Type size is decided HERE, together with the width, because this is the only
  # place that knows how large the figure will physically be. A theme carrying
  # absolute point sizes cannot know, so it produces text that is correct on one
  # canvas and unreadable on another.
  if (is.null(base_size)) {
    base_size <- figure_base_size(width)
  }
  if (!all(is.na(base_size))) {
    plot <- .resize_figure(plot, base_size)
  }

  dir <- dirname(filename)
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  }

  # cairo_pdf gives embedded fonts and proper unicode on Windows/Linux, but
  # R's cairo on macOS can corrupt memory and crash the session (observed as
  # segfaults on GitHub Actions macOS runners), so it is never auto-selected
  # there; macOS' own pdf device handles fonts well.
  is_pdf <- grepl("\\.pdf$", filename, ignore.case = TRUE)
  if (is.null(device) && is_pdf) {
    use_cairo <- isTRUE(capabilities("cairo")[[1]]) &&
      !identical(Sys.info()[["sysname"]], "Darwin")
    if (use_cairo) {
      device <- grDevices::cairo_pdf
    }
  }

  if (is.null(device)) {
    ggplot2::ggsave(
      filename = filename, plot = plot,
      width = width, height = height, units = "in", dpi = dpi
    )
  } else {
    ggplot2::ggsave(
      filename = filename, plot = plot, device = device,
      width = width, height = height, units = "in", dpi = dpi
    )
  }

  message(
    "Saved figure to '", filename, "' (", width, " x ", height, " in",
    if (!all(is.na(base_size))) paste0(", base font ", base_size, " pt") else "",
    ")."
  )
  invisible(filename)
}


#' Base font size for a figure of a given width
#'
#' The rule [save_paper_figure()] uses to pick a type size from a figure width.
#' Text in a figure should read at roughly the body-text size of the document
#' the figure is placed in; since a figure is usually placed at 100\%, that
#' means the type size has to follow the physical width. The rule is calibrated
#' so that the two standard widths land on sensible values: 3.33 in (a
#' two-column journal column) gives 7 pt and 7 in (full text width) gives 9 pt,
#' with linear interpolation between and clamping outside.
#'
#' @param width Figure width in inches.
#' @param min_size,max_size Bounds, so that very small or very large figures
#'   still get a usable size. Defaults 6 and 12 points.
#'
#' @return A single number: the base font size in points.
#' @export
#'
#' @examples
#' figure_base_size(3.33)  # 7
#' figure_base_size(7)     # 9
figure_base_size <- function(width, min_size = 6, max_size = 12) {
  if (!is.numeric(width) || length(width) != 1L || is.na(width) || width <= 0) {
    stop("`width` must be a single positive number (inches).")
  }
  size <- 5.19 + 0.545 * width
  max(min_size, min(max_size, round(size, 1)))
}


#' Methods-section sentence justifying the test selection
#'
#' Runs [check_normality_by_group()] (and optionally a test for homogeneity of
#' variances) and turns the outcome into a ready-made methods-section sentence
#' that says what was tested and reports the statistic the decision rests on.
#' This is the justification reviewers expect next to the choice of a
#' parametric or non-parametric test.
#'
#' The sentence follows the check exactly:
#' * **Between subjects**: one Shapiro--Wilk test per group, Holm-corrected
#'   across the groups; the adjusted p-values are labelled
#'   \eqn{p_{Holm}}{p_Holm}. A rejection names the group(s) with their
#'   \eqn{W} and p; otherwise the group with the smallest p is reported.
#' * **Within subjects** (\code{subject} given): one test on the paired
#'   differences (two conditions) or on the residuals of the additive
#'   participant + condition model (more conditions). Participants excluded for
#'   lacking a condition are counted in the text.
#' * A group that could not be tested (fewer than three values, or all values
#'   identical -- e.g. everyone ticked the top of a rating scale) is named and
#'   stated to have been treated as non-normal, which sends the analysis to the
#'   non-parametric branch.
#'
#' p-values are printed so that rounding never moves them across .05, .01 or
#' .10, and all statistics are plain LaTeX math (no custom macros needed).
#'
#' @param data the data frame
#' @param x the grouping variable (column name as string)
#' @param y the dependent variable (column name as string)
#' @param include_homogeneity whether to also report the homogeneity-of-variance
#'   test run by [check_homogeneity_by_group()] (named as that function reports
#'   it: the Brown-Forsythe, i.e. median-centred Levene's, test). Between
#'   subjects only: with \code{subject} given it is skipped with a message,
#'   because equal variances across conditions are not an assumption of a
#'   repeated-measures analysis (its counterpart, sphericity, is tested and
#'   corrected by the ANOVA itself). Default \code{FALSE}.
#' @param subject the participant-ID column for a within-subjects design, as a
#'   string; \code{NULL} (default) for a between-subjects design. Passed to
#'   [check_normality_by_group()].
#'
#' @return Invisibly returns the sentence(s) as a single string; the text is
#'   also emitted via \code{message()}.
#' @export
#'
#' @examples
#' set.seed(1)
#' d <- data.frame(g = rep(c("A", "B"), each = 20), v = rnorm(40))
#' assumption_methods_text(d, x = "g", y = "v")
#'
#' # within subjects: the paired differences are tested
#' d$id <- rep(1:20, times = 2)
#' assumption_methods_text(d, x = "g", y = "v", subject = "id")
assumption_methods_text <- function(data, x, y, include_homogeneity = FALSE, subject = NULL) {
  not_empty(data)
  not_empty(x)
  not_empty(y)

  normal <- check_normality_by_group(data, x, y, subject = subject)
  sentences <- .normality_sentence(normal, x)

  if (isTRUE(include_homogeneity) && !is.null(subject)) {
    # A variance test across conditions treats them as independent groups, and
    # its "unequal variances" verdict would add a Welch clause that has no
    # meaning for repeated measures.
    message("assumption_methods_text(): `include_homogeneity` is ignored for a within-subjects ",
            "design (`subject` given): equal variances across conditions are not an assumption ",
            "of a repeated-measures analysis.")
  } else if (isTRUE(include_homogeneity)) {
    homogeneous <- check_homogeneity_by_group(data, x, y)
    sentences <- c(sentences, .homogeneity_sentence(homogeneous, parametric = isTRUE(as.logical(normal))))
  }

  out <- paste(sentences, collapse = " ")
  message(out)
  invisible(out)
}


# Internal: a p-value as inline math, "$p = 0.012$" or "$p < 0.001$", with the
# subscripted label of an adjusted p ("p_{\mathrm{Holm}}") where one applies.
.p_math <- function(p, label = "p") {
  vapply(p, function(pv) {
    if (is.na(pv)) {
      paste0("$", label, "$ not available")
    } else if (pv < 0.001) {
      paste0("$", label, " < ", .fmt_bounded(0.001, 3), "$")
    } else {
      paste0("$", label, " = ", .fmt_p_number(pv, 3), "$")
    }
  }, character(1), USE.NAMES = FALSE)
}

# Internal: Shapiro-Wilk W for display. W lies in (0, 1], so APA drops the
# leading zero (via .fmt_bounded()); a W of 0.996 is shown with a third decimal
# rather than rounded up to "1.00", which would read as a perfect fit.
.fmt_w <- function(w) {
  vapply(w, function(wv) {
    d <- 2
    while (d < 4 && !is.na(wv) && wv < 1 && round(wv, d) >= 1) d <- d + 1
    .fmt_bounded(wv, d)
  }, character(1), USE.NAMES = FALSE)
}

# Internal: "A and B", "A, B, and C".
.and_list <- function(x) {
  n <- length(x)
  if (n <= 1) return(paste(x, collapse = ""))
  if (n == 2) return(paste(x, collapse = " and "))
  paste0(paste(x[-n], collapse = ", "), ", and ", x[n])
}

# Internal: the normality part of assumption_methods_text(), built from the
# attributes of check_normality_by_group().
.normality_sentence <- function(normal, x) {
  tests <- attr(normal, "tests")
  if (is.null(tests) || nrow(tests) == 0) {
    return("Normality could not be assessed; non-parametric tests were used as a precaution.")
  }
  method <- attr(normal, "method")
  if (is.null(method)) method <- "groupwise"
  adjust <- attr(normal, "p_adjust")
  adjusted <- !is.null(adjust) && !identical(adjust, "none")
  adjust_name <- if (adjusted) {
    switch(tolower(adjust),
      holm = "Holm", bonferroni = "Bonferroni", hochberg = "Hochberg",
      hommel = "Hommel", bh = , fdr = "BH", by = "BY", adjust
    )
  }
  p_label <- if (adjusted) paste0("p_{\\mathrm{", adjust_name, "}}") else "p"
  x_tex <- latex_escape(x)

  testable <- tests[tests$testable %in% TRUE, , drop = FALSE]
  untestable <- tests[!(tests$testable %in% TRUE), , drop = FALSE]
  p_used <- if (adjusted) testable$p_adjusted else testable$p_value
  stat <- function(i) paste0("$W = ", .fmt_w(testable$W[i]), "$, ", .p_math(p_used[i], p_label))
  group <- function(g) paste("group", latex_escape(g))
  reason <- function(n) ifelse(n < 3, "fewer than three values", "all values identical")

  # what was tested, as the subject of the sentence
  what <- switch(method,
    differences = paste0(
      "A Shapiro--Wilk test on the within-participant differences between the two levels of ",
      x_tex, " ($n = ", tests$n[1], "$)"
    ),
    residuals = paste0(
      "A Shapiro--Wilk test on the residuals of the additive model with participant and ",
      x_tex, " as factors ($n = ", tests$n[1], "$)"
    ),
    {
      k <- nrow(tests)
      paste0(
        if (k == 1) paste0("A Shapiro--Wilk test in the only group of ", x_tex)
        else paste0("Shapiro--Wilk tests in each of the ", k, " groups of ", x_tex),
        if (!adjusted) {
          ""
        } else if (nrow(testable) < k) {
          paste0(" (", adjust_name, "-corrected across the ", nrow(testable), " testable groups)")
        } else {
          paste0(" (", adjust_name, "-corrected for ", k, " tests)")
        }
      )
    }
  )
  # (within subjects there is a single test, so an untestable one leaves
  # nothing testable and is handled below)
  untestable_clause <- if (nrow(untestable) == 0) {
    ""
  } else {
    paste0(
      .and_list(paste0(group(untestable$group), " (", reason(untestable$n), ")")),
      if (nrow(untestable) == 1) " could not be tested and was" else " could not be tested and were",
      " therefore treated as non-normal"
    )
  }

  dropped <- attr(normal, "dropped_subjects")
  dropped_note <- if (length(dropped) > 0) {
    paste0(
      " Participants without a value in every level of ", x_tex,
      " ($n = ", length(dropped), "$) were excluded from this check."
    )
  } else {
    ""
  }

  sentence <- if (nrow(testable) == 0) {
    target <- if (method == "differences") "the within-participant differences" else "the model residuals"
    paste0(
      "Normality could not be assessed with Shapiro--Wilk tests, because ",
      if (method == "groupwise") {
        .and_list(paste0(group(untestable$group), " (", reason(untestable$n), ")"))
      } else {
        paste0(target, " (", reason(untestable$n[1]), ")")
      },
      " could not be tested; non-parametric tests were used as a precaution."
    )
  } else {
    rejected <- which(p_used < 0.05)
    if (length(rejected) > 0) {
      evidence <- if (method == "groupwise") {
        paste0(" for ", .and_list(paste0(group(testable$group[rejected]), " (", stat(rejected), ")")))
      } else {
        paste0(" (", stat(1), ")")
      }
      paste0(
        what, " indicated a significant deviation from normality", evidence,
        if (nzchar(untestable_clause)) paste0(", and ", untestable_clause) else "",
        "; therefore, non-parametric tests were used."
      )
    } else {
      lowest <- which.min(p_used)
      evidence <- if (method == "groupwise" && nrow(testable) > 1) {
        paste0(" (smallest $p$: ", stat(lowest), " for ", group(testable$group[lowest]), ")")
      } else if (method == "groupwise") {
        paste0(" (", stat(lowest), " for ", group(testable$group[lowest]), ")")
      } else {
        paste0(" (", stat(1), ")")
      }
      if (nzchar(untestable_clause)) {
        paste0(
          what, " indicated no significant deviation from normality", evidence,
          ", but ", untestable_clause, "; therefore, non-parametric tests were used."
        )
      } else {
        paste0(
          what, " indicated no significant deviation from normality", evidence,
          "; therefore, parametric tests were used."
        )
      }
    }
  }
  paste0(sentence, dropped_note)
}

# Internal: the homogeneity-of-variance part of assumption_methods_text(). The
# test is named as check_homogeneity_by_group() reports it (its "method"
# attribute; rstatix's levene_test() centres on the median, i.e. the
# Brown--Forsythe variant). A result without that attribute is described
# generically rather than given a name it may not deserve.
.homogeneity_sentence <- function(homogeneous, parametric) {
  lev <- attr(homogeneous, "test")
  if (is.null(lev) || nrow(lev) == 0 || is.na(lev$p[1])) {
    return(character(0))
  }
  test_name <- attr(homogeneous, "method")
  test_name <- if (is.null(test_name) || !nzchar(test_name[1])) {
    "a test of homogeneity of variance"
  } else {
    latex_escape(test_name[1])
  }
  test_name <- paste0(toupper(substring(test_name, 1, 1)), substring(test_name, 2))
  stats <- paste0(
    "$F(", .fmt_df(lev$df1[1]), ", ", .fmt_df(lev$df2[1]), ") = ",
    .fmt_num(lev$statistic[1]), "$, ", .p_math(lev$p[1])
  )
  if (isTRUE(as.logical(homogeneous))) {
    paste0(test_name, " did not indicate unequal variances (", stats, ").")
  } else {
    paste0(
      test_name, " indicated unequal variances (", stats, ")",
      # Welch's correction is a property of the parametric tests; claiming it
      # for a rank-based analysis would describe something that did not happen
      if (parametric) "; Welch-corrected statistics were used where applicable" else "",
      "."
    )
  }
}


#' Citations and methods boilerplate for the analyses used
#'
#' Prints a ready-made methods phrase plus the BibTeX entries for the R
#' packages behind the requested analysis methods, so a manuscript's methods
#' section and bibliography can be filled in one step.
#'
#' @param methods Character vector of analysis methods to cite. Any of
#'   \code{"art"} (Aligned Rank Transform via ARTool), \code{"dunn"} (Dunn's
#'   test via FSA), \code{"nparld"} (nparLD), \code{"ggstatsplot"},
#'   \code{"effectsize"}, and \code{"colleyrstats"} (this package).
#' @param bibtex whether to include the BibTeX entries. Default \code{TRUE}.
#'
#' @return Invisibly returns the generated lines as a character vector; the
#'   text is also emitted via \code{message()}. Methods whose package is not
#'   installed are skipped with a message. Every BibTeX entry gets a citation
#'   key -- the package name, with \code{-2}, \code{-3}, ... for a package's
#'   further entries -- because R's citation entries carry none, and BibTeX
#'   keeps only the first of several keyless entries ("Repeated entry"). The
#'   methods phrase then cites those keys (\code{\\cite{ARTool,ARTool-2}}).
#' @export
#'
#' @examples
#' cite_methods("ggstatsplot", bibtex = FALSE)
cite_methods <- function(methods = c("ggstatsplot", "effectsize"), bibtex = TRUE) {
  not_empty(methods)

  catalog <- list(
    art = list(
      package = "ARTool",
      note = "We used the Aligned Rank Transform (ART) for nonparametric factorial analyses."
    ),
    dunn = list(
      package = "FSA",
      note = "Significant omnibus effects were followed up with Dunn's post-hoc tests."
    ),
    nparld = list(
      package = "nparLD",
      note = "We used nonparametric analysis of longitudinal data (nparLD) for the repeated-measures designs."
    ),
    ggstatsplot = list(
      package = "ggstatsplot",
      note = "Statistical tests and visualizations were produced with ggstatsplot."
    ),
    effectsize = list(
      package = "effectsize",
      note = "Effect sizes were computed with the effectsize package."
    ),
    colleyrstats = list(
      package = "colleyRstats",
      note = "Statistical reporting was streamlined with colleyRstats."
    )
  )

  # A method named twice ("art", "ART") would otherwise be cited twice, with a
  # second set of BibTeX entries under the same keys.
  methods <- unique(tolower(methods))
  unknown <- setdiff(methods, names(catalog))
  if (length(unknown) > 0) {
    stop(
      "Unknown method(s): ", paste(unknown, collapse = ", "),
      ". Available: ", paste(names(catalog), collapse = ", "), "."
    )
  }

  out <- character(0)
  for (m in methods) {
    entry <- catalog[[m]]
    if (!requireNamespace(entry$package, quietly = TRUE)) {
      message("Package '", entry$package, "' is not installed; skipping its citation.")
      next
    }

    bib <- NULL
    if (isTRUE(bibtex)) {
      cit <- tryCatch(utils::citation(entry$package), error = function(e) NULL)
      if (!is.null(cit)) {
        bib <- .bibtex_with_keys(cit, entry$package)
      }
    }
    note <- entry$note
    if (!is.null(bib) && length(bib$keys) > 0) {
      note <- paste0(sub("\\.$", "", note), "~\\cite{", paste(bib$keys, collapse = ","), "}.")
    }
    out <- c(out, paste0("% ", entry$package, ": ", note))
    if (!is.null(bib)) {
      out <- c(out, bib$lines, "")
    }
  }

  message(paste(out, collapse = "\n"))
  invisible(out)
}

# Internal: a citation as BibTeX lines, each entry with a key. toBibtex() writes
# "@Article{," for an entry without one, which is every entry R builds from a
# package's CITATION file or DESCRIPTION; BibTeX then reports "Repeated entry"
# for the second such entry in a file and drops it. Keys an entry already has
# are kept.
.bibtex_with_keys <- function(cit, package) {
  lines <- as.character(utils::toBibtex(cit))
  heads <- grep("^@[A-Za-z]+\\{", lines)
  keys <- character(length(heads))
  for (j in seq_along(heads)) {
    existing <- trimws(sub("^@[A-Za-z]+\\{([^,]*),.*$", "\\1", lines[heads[j]]))
    key <- if (nzchar(existing)) existing else if (j == 1) package else paste0(package, "-", j)
    lines[heads[j]] <- paste0(sub("^(@[A-Za-z]+\\{)[^,]*,.*$", "\\1", lines[heads[j]]), key, ",")
    keys[j] <- key
  }
  list(lines = lines, keys = keys)
}
