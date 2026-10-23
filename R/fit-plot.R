#' Plot observations with the tests from a fitted analysis
#'
#' Draws the analyzed observations and annotates them with the model and
#' omnibus tests stored by [fit_recommended()]. No model, assumption check or
#' significance test is run while building the figure. The annotations therefore
#' describe the same fit as the manuscript sentences.
#'
#' For a categorical predictor and a numeric continuous/count outcome, repeated
#' observations are averaged per cluster and predictor level for display. These
#' are descriptive means, not model predictions or confidence intervals. Ordinal,
#' binary and nominal responses are shown as counts of observed responses without
#' averaging categories. Numeric predictors are shown as scatterplots. Other
#' predictors remain in the fitted model whose tests are printed in the subtitle.
#'
#' @param fit A \code{colley_fit} returned by [fit_recommended()].
#' @param x Predictor column to display. Defaults to the first predictor; an
#'   intercept-only fit is displayed as one group.
#' @param ylab Outcome axis label. Defaults to the outcome column name.
#' @param xlabels Optional labels for a categorical predictor, in factor order.
#' @param show_test Logical. Include the stored omnibus statistics in the
#'   subtitle. The model name is always shown.
#'
#' @return A ggplot object. It can be saved with [save_paper_figure()] or combined
#'   with other plots using \pkg{patchwork}.
#' @export
#' @seealso [fit_recommended()]
#' @examples
#' \donttest{
#' fit <- fit_recommended(iris, "Sepal.Length", "Species",
#'                        outcome_type = "continuous", verbose = FALSE)
#' plot_fit(fit)
#' }
plot_fit <- function(fit, x = NULL, ylab = NULL, xlabels = NULL, show_test = TRUE) {
  if (!inherits(fit, "colley_fit")) {
    stop("`fit` must be a colley_fit returned by fit_recommended().", call. = FALSE)
  }
  if (!is.data.frame(fit$data) || nrow(fit$data) == 0L) {
    stop("`fit` has no analyzed data; refit it with colleyRstats >= 0.3.1.", call. = FALSE)
  }
  if (!is.logical(show_test) || length(show_test) != 1L || is.na(show_test)) {
    stop("`show_test` must be TRUE or FALSE.", call. = FALSE)
  }
  rec <- fit$recommendation
  outcome <- rec$outcome
  if (is.null(x) && length(rec$predictors) > 0L) x <- rec$predictors[[1L]]
  if (!is.null(x) && (!is.character(x) || length(x) != 1L ||
                     is.na(x) || !x %in% rec$predictors)) {
    stop("`x` must name one of the fitted predictors.", call. = FALSE)
  }
  .check_columns(fit$data, c(outcome, x))
  data <- as.data.frame(fit$data)
  d <- data.frame(.y = data[[outcome]])
  d$.x <- if (is.null(x)) factor(rep("All observations", nrow(d))) else data[[x]]
  categorical <- is.null(x) || is.factor(d$.x) || is.character(d$.x) || is.logical(d$.x)
  if (categorical) d$.x <- droplevels(as.factor(d$.x))
  categorical_outcome <- rec$outcome_type %in% c("ordinal", "binary", "nominal") ||
    !is.numeric(d$.y)
  averaged <- FALSE
  if (categorical && !categorical_outcome && isTRUE(rec$clustered) &&
      !is.null(rec$cluster)) {
    .check_columns(data, rec$cluster)
    d <- stats::aggregate(d[".y"], by = list(.x = d$.x, .cluster = data[[rec$cluster]]),
                          FUN = mean)
    averaged <- TRUE
  }
  p <- ggplot2::ggplot(d, ggplot2::aes(x = !!rlang::sym(".x"), y = !!rlang::sym(".y")))
  if (categorical_outcome) {
    p <- p + ggplot2::geom_count(alpha = 0.65) +
      ggplot2::scale_size_area(name = "Observations", max_size = 6)
  } else if (categorical) {
    p <- p + ggplot2::geom_boxplot(width = 0.5, outlier.shape = NA, alpha = 0.15) +
      ggplot2::geom_point(size = 1.3, alpha = 0.65,
        position = ggplot2::position_jitter(width = 0.08, height = 0, seed = 1L))
  } else {
    p <- p + ggplot2::geom_point(size = 1.3, alpha = 0.65)
  }
  if (!is.null(xlabels)) {
    if (!categorical || length(xlabels) != nlevels(d$.x)) {
      stop("`xlabels` must supply one label per categorical predictor level.", call. = FALSE)
    }
    p <- p + ggplot2::scale_x_discrete(labels = xlabels)
  }
  subtitle <- rec$recommendation
  if (isTRUE(show_test)) {
    subtitle <- paste(c(subtitle, .fit_plot_tests(fit$anova)), collapse = "\n")
  }
  caption <- if (categorical_outcome) {
    "Point sizes show counts of analyzed responses."
  } else if (averaged) {
    "Points show cluster means for each displayed level."
  } else {
    "Points show analyzed observations."
  }
  if (isTRUE(show_test) && !is.null(fit$anova) && nrow(fit$anova) > 0L) {
    caption <- paste(caption, "Tests are from the fitted model.")
  }
  if (identical(fit$converged, FALSE)) caption <- paste(caption, "The model did not converge cleanly.")
  p + ggplot2::labs(x = if (is.null(x)) "" else x,
    y = if (is.null(ylab)) outcome else ylab,
    subtitle = paste(stringr::str_wrap(strsplit(subtitle, "\n", fixed = TRUE)[[1L]],
                                      width = 45), collapse = "\n"),
    caption = stringr::str_wrap(caption, width = 45))
}


# Stored test rows are formatted directly, rather than extracted from or fitted
# to the displayed (possibly aggregated) observations.
.fit_plot_tests <- function(tests) {
  if (is.null(tests) || nrow(tests) == 0L) return("No omnibus test was available.")
  vapply(seq_len(nrow(tests)), function(i) {
    row <- tests[i, , drop = FALSE]
    label <- if (row$stat_name == "chisq") "chi-squared" else row$stat_name
    dfs <- c(row$df1, row$df2)
    dfs <- dfs[!is.na(dfs)]
    if (length(dfs)) label <- paste0(label, "(", paste(vapply(dfs, .fmt_df, character(1)), collapse = ", "), ")")
    p <- if (is.na(row$p)) {
      "p unavailable"
    } else if (row$p < 0.001) {
      "p < 0.001"
    } else {
      paste0("p = ", .fmt_p_number(row$p))
    }
    paste0(row$term, ": ", label, " = ", .fmt_num(row$statistic), ", ", p)
  }, character(1))
}
