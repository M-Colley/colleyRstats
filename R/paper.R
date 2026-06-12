#' LaTeX preamble required by the report functions
#'
#' All report functions emit LaTeX text that relies on a small set of custom
#' commands. This helper prints the complete set, ready to paste into a
#' manuscript preamble, or writes it to a file that can be included with
#' \code{\\input{}} (or renamed to \code{.sty} and loaded via
#' \code{\\usepackage}).
#'
#' @param path Optional path of a \code{.tex} file to write the definitions to.
#'
#' @return Invisibly returns the macro definitions as a character vector;
#'   the text is also emitted via \code{message()}.
#' @export
#'
#' @examples
#' latex_preamble()
latex_preamble <- function(path = NULL) {
  macros <- c(
    "% colleyRstats: LaTeX commands required by the report functions",
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

  message(paste(macros, collapse = "\n"))
  if (!is.null(path)) {
    .write_tex(macros, path)
  }
  invisible(macros)
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
save_paper_figure <- function(plot = ggplot2::last_plot(), filename, columns = 1, width = NULL, height = NULL, dpi = 300, device = NULL) {
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

  message("Saved figure to '", filename, "' (", width, " x ", height, " in).")
  invisible(filename)
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
