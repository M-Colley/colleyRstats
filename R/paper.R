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
    .colley_sty_lines()
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
    "\\newcommand{\\rankbiserial}[1]{$r_{rb} = #1$}",
    "\\newcommand{\\effectsize}{\\textit{r=}}"
  )
}

# Internal: the macro lines wrapped as a LaTeX package (colleyRstats.sty).
.colley_sty_lines <- function() {
  c(
    "% colleyRstats.sty -- macros required by the colleyRstats report functions.",
    "% Upload to Overleaf and load with \\usepackage{colleyRstats}.",
    "\\NeedsTeXFormat{LaTeX2e}",
    "\\ProvidesPackage{colleyRstats}[colleyRstats reporting macros]",
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
  if (!columns %in% c(1, 2)) {
    stop("`columns` must be 1 (single column) or 2 (full width).")
  }

  if (is.null(width)) {
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
    plot <- plot + .resize_theme(base_size)
    # .resize_theme() leaves legend.title alone so that it cannot undo the
    # element_blank() colley_theme() sets. Where a plot does ask for a legend
    # title, it still has to be scaled, or it keeps whatever absolute size the
    # plotting wrapper gave it.
    if (!inherits(.plot_theme_element(plot, "legend.title"), "element_blank")) {
      plot <- plot + ggplot2::theme(
        legend.title = ggplot2::element_text(
          size = base_size * .COLLEY_TEXT_RATIOS[["axis.text"]]
        )
      )
    }
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
#' Runs the group-wise Shapiro-Wilk normality check (and optionally Levene's
#' test for homogeneity of variances) and turns the outcome into a ready-made
#' methods-section sentence, including the relevant statistics. This is the
#' justification reviewers expect next to the choice of a parametric or
#' non-parametric test.
#'
#' @param data the data frame
#' @param x the grouping variable (column name as string)
#' @param y the dependent variable (column name as string)
#' @param include_homogeneity whether to also report Levene's test. Useful for
#'   between-subjects designs. Default \code{FALSE}.
#'
#' @return Invisibly returns the sentence(s) as a single string; the text is
#'   also emitted via \code{message()}.
#' @export
#'
#' @examples
#' set.seed(1)
#' d <- data.frame(g = rep(c("A", "B"), each = 20), v = rnorm(40))
#' assumption_methods_text(d, x = "g", y = "v")
assumption_methods_text <- function(data, x, y, include_homogeneity = FALSE) {
  not_empty(data)
  not_empty(x)
  not_empty(y)

  normal <- check_normality_by_group(data, x, y)
  tests <- attr(normal, "tests")

  if (is.null(tests) || all(is.na(tests$p_value))) {
    sentences <- "Group-wise normality could not be assessed (e.g., too few observations per group); non-parametric tests were used as a precaution."
  } else if (isTRUE(normal)) {
    sentences <- "Shapiro--Wilk tests indicated no significant deviation from normality in any group (all $p \\geq 0.05$); therefore, parametric tests were used."
  } else {
    worst <- tests[which.min(tests$p_value), ]
    p_txt <- if (worst$p_value < 0.001) "$p < 0.001$" else paste0("$p = ", .fmt_bounded(worst$p_value, 3), "$")
    sentences <- paste0(
      "Shapiro--Wilk tests indicated a significant deviation from normality for at least one group (minimum $W = ",
      .fmt_bounded(worst$W), "$, ", p_txt,
      "); therefore, non-parametric tests were used."
    )
  }

  if (isTRUE(include_homogeneity)) {
    homogeneous <- check_homogeneity_by_group(data, x, y)
    lev <- attr(homogeneous, "test")
    if (!is.null(lev) && !is.na(lev$p[1])) {
      lev_stats <- paste0(
        "$F(", lev$df1[1], ", ", lev$df2[1], ") = ", .fmt_num(lev$statistic[1]), "$, ",
        if (lev$p[1] < 0.001) "$p < 0.001$" else paste0("$p = ", .fmt_bounded(lev$p[1], 3), "$")
      )
      sentences <- c(
        sentences,
        if (isTRUE(as.logical(homogeneous))) {
          paste0("Levene's test indicated homogeneity of variances (", lev_stats, ").")
        } else {
          paste0("Levene's test indicated unequal variances (", lev_stats, "); Welch-corrected statistics were used where applicable.")
        }
      )
    }
  }

  out <- paste(sentences, collapse = " ")
  message(out)
  invisible(out)
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
#'   installed are skipped with a message.
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

  methods <- tolower(methods)
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

    out <- c(out, paste0("% ", entry$package, ": ", entry$note))
    if (isTRUE(bibtex)) {
      cit <- tryCatch(utils::citation(entry$package), error = function(e) NULL)
      if (!is.null(cit)) {
        out <- c(out, as.character(utils::toBibtex(cit)), "")
      }
    }
  }

  message(paste(out, collapse = "\n"))
  invisible(out)
}
