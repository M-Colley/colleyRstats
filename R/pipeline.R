#' Analyze one dependent variable and produce everything a paper needs
#'
#' One-call pipeline for a single dependent variable: checks the assumptions
#' (producing a ready-made methods sentence via [assumption_methods_text()]),
#' builds the matching \pkg{ggstatsplot} figure with automatic
#' parametric/non-parametric selection, reports the omnibus test via
#' [reportggstatsplot()], and -- for more than two groups -- reports the
#' significant post-hoc comparisons via [reportggstatsplotPostHoc()].
#'
#' Every part of the output is computed from one data set: the rows with both
#' \code{dv} and \code{iv} observed and, for \code{design = "within"}, only
#' the participants measured in every condition (the others are dropped with a
#' message naming them; more than one row per participant and condition is an
#' error). The methods sentence, the test, the figure and the means quoted in
#' the post-hoc sentences therefore all describe the same participants.
#'
#' @param data the data frame (long format for \code{design = "within"}: one
#'   row per participant and condition)
#' @param dv the dependent variable (column name as string)
#' @param iv the independent variable (column name as string); treated as a
#'   factor, so numeric condition codes are categories
#' @param design \code{"between"} for between-subjects data (default) or
#'   \code{"within"} for repeated measures
#' @param ylab label for the dependent variable; defaults to \code{dv}
#' @param xlabels optional labels for the x-axis
#' @param plotType either "box", "violin", or "boxviolin" (default)
#' @param sink_to optional path of a \code{.tex} file; the methods sentence,
#'   omnibus result, and post-hoc sentences are written there so a manuscript
#'   can \code{\\input{}} them
#' @param subject the participant-ID column (a string). Required for
#'   \code{design = "within"}, where it pairs the observations; without it they
#'   would be paired by row order. For \code{design = "between"} it is
#'   optional and only used to check that no participant contributes more than
#'   one row, which a between-subjects test would wrongly treat as independent
#'   observations.
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
#'
#' # Repeated measures: name the participant column
#' set.seed(1)
#' rm_df <- data.frame(
#'   participant = rep(1:15, times = 3),
#'   condition   = rep(c("A", "B", "C"), each = 15)
#' )
#' rm_df$score <- rnorm(45, mean = c(A = 5, B = 6, C = 7)[rm_df$condition])
#' analyze_and_report(rm_df, dv = "score", iv = "condition",
#'                    design = "within", subject = "participant")
#' }
analyze_and_report <- function(data, dv, iv, design = c("between", "within"), ylab = dv, xlabels = NULL, plotType = "boxviolin", sink_to = NULL, subject = NULL) {
  not_empty(data)
  not_empty(dv)
  not_empty(iv)
  design <- match.arg(design)
  if (design == "within") {
    .require_subject(subject)
  }
  .check_columns(data, c(dv, iv, subject))

  # One complete-case data set for every step below (see Details).
  if (design == "within") {
    data <- .prepare_within_data(data, iv, dv, subject)$data
  } else {
    data <- .prepare_between_data(data, iv, dv)
    if (!is.null(subject)) {
      .check_one_row_per_subject(data, subject, dv)
      # A between-subjects analysis has no use for the ID beyond that check.
      subject <- NULL
    }
  }

  methods_note <- assumption_methods_text(
    data,
    x = iv, y = dv,
    include_homogeneity = design == "between",
    subject = subject
  )

  plot <- if (design == "within") {
    ggwithinstatsWithPriorNormalityCheck(
      data = data, x = iv, y = dv, ylab = ylab,
      xlabels = xlabels, plotType = plotType, subject = subject
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
  # Counted on the analysed data: a level whose every value is missing, or
  # that vanished with the dropped participants, is not a group.
  posthoc <- NULL
  if (nlevels(droplevels(data[[iv]])) > 2) {
    posthoc <- reportggstatsplotPostHoc(data = data, p = plot, iv = iv, dv = dv, subject = subject)
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


# Internal: a between-subjects test treats every row as an independent
# participant. If the ID column shows someone contributing several rows, the
# design is (at least partly) within-subjects, and testing it as between would
# inflate the sample size -- pseudo-replication.
.check_one_row_per_subject <- function(data, subject, dv) {
  ids <- data[[subject]][!is.na(data[[subject]])]
  repeated <- unique(ids[duplicated(ids)])
  if (length(repeated) > 0L) {
    stop(
      "Participants contribute more than one row of '", dv, "' (e.g. ",
      .format_ids(repeated, max_shown = 3L), " in '", subject, "'), but design = \"between\" ",
      "treats every row as an independent participant. Use design = \"within\" for repeated ",
      "measures, or aggregate to one row per participant first.",
      call. = FALSE
    )
  }
  invisible(TRUE)
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
#' @param subject the participant-ID column (a string); required for
#'   \code{design = "within"}. See [analyze_and_report()].
#'
#' @details Each dependent variable is analysed on its own complete cases (see
#'   [analyze_and_report()]), so in a within-subjects design a participant
#'   missing one rating is left out of that dependent variable only. The
#'   \code{p.holm} column corrects the omnibus p-values for the number of
#'   dependent variables; the per-dv sentences report the uncorrected ones.
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
report_all <- function(data, dvs, iv, design = c("between", "within"), labels = NULL, xlabels = NULL, plotType = "boxviolin", sink_dir = NULL, subject = NULL) {
  not_empty(data)
  not_empty(dvs)
  not_empty(iv)
  design <- match.arg(design)
  # Fail before the first dependent variable is analysed, not after.
  if (design == "within") {
    .require_subject(subject)
  }
  .check_columns(data, c(dvs, iv, subject))

  results <- lapply(dvs, function(dv) {
    ylab <- if (!is.null(labels) && dv %in% names(labels)) labels[[dv]] else dv
    sink_to <- if (!is.null(sink_dir)) file.path(sink_dir, paste0(dv, ".tex")) else NULL
    analyze_and_report(
      data,
      dv = dv, iv = iv, design = design, ylab = ylab,
      xlabels = xlabels, plotType = plotType, sink_to = sink_to,
      subject = subject
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
