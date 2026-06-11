#' Analyze one dependent variable and produce everything a paper needs
#'
#' One-call pipeline for a single dependent variable: checks the assumptions
#' (producing a ready-made methods sentence via [assumption_methods_text()]),
#' builds the matching \pkg{ggstatsplot} figure with automatic
#' parametric/non-parametric selection, reports the omnibus test via
#' [reportggstatsplot()], and -- for more than two groups -- reports the
#' significant post-hoc comparisons via [reportggstatsplotPostHoc()].
#'
#' @param data the data frame
#' @param dv the dependent variable (column name as string)
#' @param iv the independent variable (column name as string); coerced to a
#'   factor if it is not one already
#' @param design \code{"between"} for between-subjects data (default) or
#'   \code{"within"} for repeated measures
#' @param ylab label for the dependent variable; defaults to \code{dv}
#' @param xlabels optional labels for the x-axis
#' @param plotType either "box", "violin", or "boxviolin" (default)
#' @param sink_to optional path of a \code{.tex} file; the methods sentence,
#'   omnibus result, and post-hoc sentences are written there so a manuscript
#'   can \code{\\input{}} them
#'
#' @return Invisibly returns a list with components \code{plot} (the ggplot),
#'   \code{methods} (assumption-check sentence), \code{text} (omnibus result),
#'   \code{posthoc} (post-hoc sentences, or \code{NULL} for two groups), and
#'   \code{sentences} (all text combined, in manuscript order).
#' @export
#'
#' @examples
#' \donttest{
#' result <- analyze_and_report(mtcars, dv = "mpg", iv = "cyl")
#' result$plot
#' }
analyze_and_report <- function(data, dv, iv, design = c("between", "within"), ylab = dv, xlabels = NULL, plotType = "boxviolin", sink_to = NULL) {
  not_empty(data)
  not_empty(dv)
  not_empty(iv)
  design <- match.arg(design)
  stopifnot(dv %in% names(data), iv %in% names(data))

  if (!is.factor(data[[iv]])) {
    data[[iv]] <- as.factor(data[[iv]])
  }

  methods_note <- assumption_methods_text(
    data,
    x = iv, y = dv,
    include_homogeneity = design == "between"
  )

  plot <- if (design == "within") {
    ggwithinstatsWithPriorNormalityCheck(
      data = data, x = iv, y = dv, ylab = ylab,
      xlabels = xlabels, plotType = plotType
    )
  } else {
    ggbetweenstatsWithPriorNormalityCheck(
      data = data, x = iv, y = dv, ylab = ylab,
      xlabels = xlabels, plotType = plotType
    )
  }

  text <- reportggstatsplot(plot, iv = iv, dv = dv)

  # With two groups ggstatsplot produces no pairwise comparisons (the omnibus
  # test already is the comparison), so post-hocs are only meaningful for 3+.
  posthoc <- NULL
  if (nlevels(data[[iv]]) > 2) {
    posthoc <- reportggstatsplotPostHoc(data = data, p = plot, iv = iv, dv = dv)
  }

  sentences <- c(methods_note, text, posthoc)
  if (!is.null(sink_to)) {
    .write_tex(sentences, sink_to)
  }

  invisible(list(
    plot = plot,
    methods = methods_note,
    text = text,
    posthoc = posthoc,
    sentences = sentences
  ))
}


#' Analyze and report several dependent variables at once
#'
#' Runs [analyze_and_report()] for each dependent variable (e.g., all
#' questionnaire scales of a study) and additionally returns a summary table
#' of the omnibus tests with Holm-adjusted p-values across the dependent
#' variables, plus -- when \pkg{patchwork} is installed -- a combined figure.
#'
#' @param data the data frame
#' @param dvs character vector of dependent variable column names
#' @param iv the independent variable (column name as string)
#' @param design \code{"between"} (default) or \code{"within"}
#' @param labels optional named character vector mapping a dv name to its
#'   axis label, e.g. \code{c(tlx_mental = "Mental Demand")}
#' @param xlabels optional labels for the x-axis, passed to every plot
#' @param plotType either "box", "violin", or "boxviolin" (default)
#' @param sink_dir optional directory; each dv's sentences are written to
#'   \code{<sink_dir>/<dv>.tex} so a manuscript can \code{\\input{}} them
#'
#' @return Invisibly returns a list with components \code{results} (named list
#'   of [analyze_and_report()] results), \code{summary} (data frame with one
#'   row per dv: method, statistic, p.value, and Holm-adjusted \code{p.holm}),
#'   and \code{combined_plot} (a patchwork figure, or \code{NULL} when
#'   patchwork is not installed).
#' @export
#'
#' @examples
#' \donttest{
#' out <- report_all(mtcars, dvs = c("mpg", "disp"), iv = "cyl")
#' out$summary
#' }
report_all <- function(data, dvs, iv, design = c("between", "within"), labels = NULL, xlabels = NULL, plotType = "boxviolin", sink_dir = NULL) {
  not_empty(data)
  not_empty(dvs)
  not_empty(iv)
  design <- match.arg(design)
  stopifnot(all(dvs %in% names(data)))

  results <- lapply(dvs, function(dv) {
    ylab <- if (!is.null(labels) && dv %in% names(labels)) labels[[dv]] else dv
    sink_to <- if (!is.null(sink_dir)) file.path(sink_dir, paste0(dv, ".tex")) else NULL
    analyze_and_report(
      data,
      dv = dv, iv = iv, design = design, ylab = ylab,
      xlabels = xlabels, plotType = plotType, sink_to = sink_to
    )
  })
  names(results) <- dvs

  # Summary of the omnibus tests, with Holm correction *across* the dependent
  # variables (the per-dv p-values are unadjusted in this respect).
  summary_df <- do.call(rbind, lapply(dvs, function(dv) {
    st <- ggstatsplot::extract_stats(results[[dv]]$plot)$subtitle_data
    data.frame(
      dv = dv,
      method = as.character(st$method[1]),
      statistic = as.numeric(st$statistic[1]),
      p.value = as.numeric(st$p.value[1]),
      stringsAsFactors = FALSE
    )
  }))
  summary_df$p.holm <- stats::p.adjust(summary_df$p.value, method = "holm")
  rownames(summary_df) <- NULL

  combined_plot <- NULL
  if (requireNamespace("patchwork", quietly = TRUE)) {
    combined_plot <- patchwork::wrap_plots(lapply(results, function(r) r$plot))
  } else {
    message("Install the 'patchwork' package to also receive a combined figure.")
  }

  invisible(list(
    results = results,
    summary = summary_df,
    combined_plot = combined_plot
  ))
}
