# Internal: warn when custom x-axis labels cannot match the number of factor
# levels -- scale_x_discrete() would then silently mislabel or drop categories,
# which is easy to miss in a final figure.
.check_xlabels <- function(data, x, xlabels) {
  if (is.null(xlabels) || length(xlabels) == 0) {
    return(invisible(NULL))
  }
  n_levels <- length(unique(stats::na.omit(as.character(data[[x]]))))
  if (length(xlabels) != n_levels) {
    warning(
      "`xlabels` has length ", length(xlabels), " but `", x, "` has ",
      n_levels, " observed level", if (n_levels == 1) "" else "s",
      "; the axis labels may not line up with the groups.",
      call. = FALSE
    )
  }
  invisible(NULL)
}


#' Function to define a plot, either showing the main or interaction effect in bold.
#'
#' @param data the data frame
#' @param x factor shown on the x-axis
#' @param y dependent variable
#' @param fillColourGroup group to color
#' @param ytext label for y-axis
#' @param xtext label for x-axis
#' @param legendPos position for legend
#' @param legendHeading custom heading for legend
#' @param shownEffect either "main" or "interaction"
#' @param effectLegend TRUE: show legend for effect (Default: FALSE)
#' @param effectDescription custom label for effect
#' @param xLabelsOverwrite custom labels for x-axis
#' @param useLatexMarkup use latex font and markup
#' @param numberColors number of colors
#'
#' @return a plot
#' @export
#'
#' @examples
#' \donttest{
#' set.seed(123)
#' main_df <- data.frame(
#'   strategy    = factor(rep(c("A", "B"), each = 20)),
#'   Emotion     = factor(rep(c("Happy", "Sad"), times = 20)),
#'   trust_mean  = rnorm(40, mean = 5, sd = 1)
#' )
#'
#' generateEffectPlot(
#'   data = main_df,
#'   x = "strategy",
#'   y = "trust_mean",
#'   fillColourGroup = "Emotion",
#'   ytext = "Trust",
#'   xtext = "Strategy",
#'   legendPos = c(0.1, 0.23)
#' )
#' }
generateEffectPlot <- function(data,
                               x,
                               y,
                               fillColourGroup,
                               ytext = "testylab",
                               xtext = "testxlab",
                               legendPos = c(0.1, 0.23),
                               legendHeading = NULL,
                               shownEffect = "main",
                               effectLegend = FALSE,
                               effectDescription = NULL,
                               xLabelsOverwrite = NULL,
                               useLatexMarkup = FALSE,
                               numberColors = 6) {
  not_empty(data)
  not_empty(x)
  not_empty(y)
  not_empty(fillColourGroup)
  not_empty(shownEffect)
  .check_columns(data, c(x, y, fillColourGroup))
  .check_xlabels(data, x, xLabelsOverwrite)

  p <- data |>
    ggplot2::ggplot() +
    ggplot2::aes(
      x = !!rlang::sym(x),
      y = !!rlang::sym(y),
      fill = !!rlang::sym(fillColourGroup),
      colour = !!rlang::sym(fillColourGroup),
      group = !!rlang::sym(fillColourGroup)
    ) +
    see::scale_colour_see() +
    ggplot2::labs(y = ytext) +
    ggplot2::labs(x = xtext) +
    ggplot2::theme(
      legend.position = "inside",
      legend.position.inside = legendPos,
      # rel(), not an absolute size: an absolute value here would survive the
      # rescaling save_paper_figure() applies and land a 14 pt title on a
      # 3.33 in figure.
      legend.title = ggplot2::element_text(
        face = "bold", color = "black", size = ggplot2::rel(0.9)
      )
    ) +

    # Points for each group
    ggplot2::stat_summary(
      fun = mean,
      geom = "point",
      size = 5
    ) +

    # Error bars
    ggplot2::stat_summary(
      fun.data = "mean_cl_boot",
      geom = "errorbar",
      width = .5,
      position = ggplot2::position_dodge(width = 0.05),
      alpha = 0.5
    ) +

    # Ensure consistent order of legends
    ggplot2::guides(
      colour = ggplot2::guide_legend(order = 1),
      fill   = ggplot2::guide_legend(order = 1),
      shape  = ggplot2::guide_legend(order = 2)
    )

  # Legend heading
  if (!is.null(legendHeading) && nzchar(legendHeading)) {
    p <- p + ggplot2::labs(
      color = legendHeading,
      fill  = legendHeading
    )
  }

  # Overwrite x-axis labels
  if (!is.null(xLabelsOverwrite)) {
    p <- p +
      ggplot2::scale_x_discrete(
        name = xtext,
        labels = xLabelsOverwrite
      )
  }

  # Latex extension
  if (useLatexMarkup) {
    if (!requireNamespace("ggtext", quietly = TRUE)) {
      stop("Package 'ggtext' is required for `useLatexMarkup = TRUE`. Please install it.")
    }
    p <- p + ggplot2::theme(
      legend.text = ggplot2::element_text(
        family = "sans",
        size = 17,
        color = "#000000"
      ),
      axis.title.x = ggplot2::element_text(
        family = "sans",
        face = "bold",
        size = 18,
        color = "#000000"
      ),
      axis.title.y = ggtext::element_markdown( # Enables usage of e.g. "**Bold Text**" or unicode
        family = "sans",
        size = 18,
        color = "#000000"
      ),
      axis.text.x = ggplot2::element_text(
        family = "sans",
        size = 17,
        color = "#000000"
      ),
      axis.text.y = ggplot2::element_text(
        family = "sans",
        size = 17,
        color = "#000000"
      )
    )
  }


  # Main / Interaction Effect visualization
  if (is.null(effectDescription) || !nzchar(effectDescription)) {
    effectDescription <- paste("Mean of", xtext)
  }

  if (shownEffect == "main") {
    p <- p +
      ggplot2::stat_summary(
        fun = mean,
        geom = "line",
        linewidth = 2,
        ggplot2::aes(group = 1),
        show.legend = FALSE
      ) +
      ggplot2::stat_summary(
        fun = mean,
        geom = "point",
        size = 6,
        ggplot2::aes(group = 1, shape = effectDescription),
        show.legend = effectLegend
      ) +
      ggplot2::scale_shape_manual(
        name = "Main Effect",
        values = setNames(16, effectDescription) # 16 = shape code for solid dot
      ) +
      ggplot2::stat_summary(
        fun = mean,
        geom = "line",
        linetype = "dashed",
        linewidth = 1,
        show.legend = FALSE
      )
  } else if (shownEffect == "interaction") {
    p <- p +
      ggplot2::stat_summary(
        fun = mean,
        geom = "line",
        linetype = "dashed",
        linewidth = 1,
        ggplot2::aes(group = 1),
        show.legend = FALSE
      ) +
      ggplot2::stat_summary(
        fun = mean,
        geom = "point",
        size = 6,
        ggplot2::aes(group = 1, shape = effectDescription),
        show.legend = effectLegend
      ) +
      ggplot2::scale_shape_manual(
        name = "",
        values = setNames(16, effectDescription) # 16 = shape code for solid dot
      ) +
      ggplot2::stat_summary(
        fun = mean,
        geom = "line",
        linewidth = 2,
        show.legend = FALSE
      )
  } else {
    stop("ERROR: wrong effect defined for visualization.")
  }

  return(p)
}


#' Generate a Multi-objective Optimization Plot
#'
#' This function generates a multi-objective optimization plot using `ggplot2`. The plot visualizes the relationship between the `x` and `y` variables, grouping and coloring by a fill variable, with the option to customize legend position, labels, and annotation of sampling and optimization phases.
#' Appropriate if you use https://github.com/Pascal-Jansen/Bayesian-Optimization-for-Unity in version 1.1.0 or higher.
#'
#' @param data A data frame containing the data to be plotted.
#' @param x A string representing the column name in `data` to be used for the x-axis. Can be either numeric or factor. Default is `"Iteration"`.
#' @param y A string representing the column name in `data` to be used for the y-axis. This should be a numeric variable.
#' @param phaseCol the name of the column for the color of the phase (sampling or optimization)
#' @param fillColourGroup A string representing the column name in `data` that defines the fill color grouping for the plot. Default is `"ConditionID"`.
#' @param ytext A custom label for the y-axis. If not provided, the y-axis label will be the title-cased version of `y`.
#' @param legendPos A numeric vector of length 2 specifying the position of the legend inside the plot. Default is `c(0.65, 0.85)`.
#' @param labelPosFormulaY A string specifying the vertical position of the polynomial equation label in the plot. Acceptable values are `"top"`, `"center"`, or `"bottom"`. Default is `"top"`.
#' @param labelPosFormulaX A string specifying the position of the polynomial equation label in the plot. Acceptable values are `"left"`, `"center"`, or `"right"`. Default is `"left"`.
#' @param horizontalLinePosY A numeric value of the y-coordinate where the "sampling" and "optimization" line should be drawn. Default is `0.75`
#' @param horizontalLineDistToText A numeric value of the y-coordinate where the "sampling" and "optimization" text should be drawn below the line. Default is `0.3`
#' @param fillLabels An optional named character vector mapping raw factor levels to display labels for the fill/colour legend (e.g. \code{c("value_only" = "Value Only", "llm_only" = "LLM Only")}). If \code{NULL} (default), the original factor levels are used as-is.
#' @param annotationTextSize numeric. The font size for embedded text annotations inside the plot (e.g., "Sampling", "Optimization" labels, and the regression equations). Default is `5.0`.
#'
#' @return A `ggplot` object representing the multi-objective optimization plot, ready to be rendered.
#' @export
#'
#' @examples
#' library(ggplot2)
#' library(ggpmisc)
#'
#' # Example with numeric x-axis
#' df <- data.frame(
#'   x = 1:20,
#'   y = rnorm(20),
#'   ConditionID = rep(c("A", "B"), 10),
#'   Phase = rep(c("Sampling", "Optimization"), 10)
#' )
#' generateMoboPlot2(data = df, x = "x", y = "y")
generateMoboPlot2 <- function(data, x = "Iteration", y, phaseCol = "Phase", fillColourGroup = "ConditionID", ytext, legendPos = c(0.65, 0.85), labelPosFormulaY = "top", labelPosFormulaX = "left", horizontalLinePosY = 0.75, horizontalLineDistToText = 0.3, fillLabels = NULL, annotationTextSize = 5) {
  not_empty(data)
  not_empty(x)
  not_empty(y)
  not_empty(fillColourGroup)
  # fillColourGroup = "" means "no grouping" (see below), so it is only
  # validated as a column when actually used.
  .check_columns(data, c(x, y, phaseCol))
  if (is.character(fillColourGroup) && nzchar(fillColourGroup)) {
    .check_columns(data, fillColourGroup)
  }

  # as default, just add the y variable in Title caps
  if (missing(ytext)) {
    ytext <- stringr::str_to_title(y)
  }

  # Convert the iteration axis robustly: a factor's storage codes are not its
  # numeric labels, so route factors through character first.
  x_numeric <- if (is.factor(data[[x]])) as.numeric(as.character(data[[x]])) else as.numeric(data[[x]])
  # Match phase labels case-insensitively so "Sampling"/"sampling" both work.
  phase <- tolower(as.character(data[[phaseCol]]))
  if (!any(phase == "sampling", na.rm = TRUE) || !any(phase == "optimization", na.rm = TRUE)) {
    stop(
      "Column '", phaseCol,
      "' must contain both 'sampling' and 'optimization' rows (case-insensitive)."
    )
  }
  numberSamplingSteps <- max(x_numeric[phase == "sampling"], na.rm = TRUE)
  numberOptimizations <- max(x_numeric[phase == "optimization"], na.rm = TRUE) - numberSamplingSteps

  maxIteration <- numberSamplingSteps + numberOptimizations


  y_sym <- rlang::sym(y)
  x_sym <- rlang::sym(x)

  p <- data |>
    ggplot2::ggplot(ggplot2::aes(x = !!x_sym, y = !!y_sym)) +
    ggplot2::labs(y = ytext) +
    ggplot2::labs(x = "Iteration") +
    ggplot2::theme(legend.position = "inside", legend.position.inside = legendPos) +
    ggplot2::stat_summary(fun = base::mean, geom = "point", size = 4.0, alpha = 0.9) +
    ggplot2::stat_summary(fun = base::mean, geom = "line", linewidth = 1, alpha = 0.3) +
    ggplot2::stat_summary(
      fun.data = "mean_cl_boot", geom = "errorbar",
      width = 0.5, position = ggplot2::position_dodge(width = 0.1), alpha = 0.5
    ) +
    ggplot2::annotate("text", x = numberSamplingSteps / 2.0, y = horizontalLinePosY - horizontalLineDistToText, label = "Sampling", size = annotationTextSize, fontface = "bold") +
    # annotate() draws the guide lines exactly once; mapping these constants
    # inside aes() would draw one overlapping segment per data row.
    ggplot2::annotate(
      "segment",
      x = 0, y = horizontalLinePosY,
      xend = numberSamplingSteps + 0.2, yend = horizontalLinePosY,
      linetype = "dashed", color = "black"
    ) +
    ggplot2::annotate("text",
      x = numberOptimizations / 2.0 + numberSamplingSteps,
      y = horizontalLinePosY - horizontalLineDistToText, label = "Optimization",
      size = annotationTextSize, fontface = "bold"
    ) +
    ggplot2::annotate(
      "segment",
      x = numberSamplingSteps + 0.8, y = horizontalLinePosY,
      xend = maxIteration, yend = horizontalLinePosY,
      color = "black"
    ) +
    ggpmisc::stat_poly_eq(ggpmisc::use_label(c("eq", "R2")), label.y = labelPosFormulaY, label.x = labelPosFormulaX, size = annotationTextSize) +
    ggpmisc::stat_poly_line(fullrange = FALSE, alpha = 0.1, linetype = "dashed", linewidth = 0.5) +
    ggplot2::geom_vline(
      xintercept = numberSamplingSteps + 0.5,
      linetype = "dashed", color = "black", alpha = 0.5
    )

  if (is.character(fillColourGroup) && nzchar(fillColourGroup)) {
    f_sym <- rlang::sym(fillColourGroup)
    p <- p +
      ggplot2::aes(fill = !!f_sym, colour = !!f_sym, group = !!f_sym) +
      see::scale_fill_see(labels  = if (!is.null(fillLabels)) fillLabels else ggplot2::waiver()) +
      see::scale_color_see(labels  = if (!is.null(fillLabels)) fillLabels else ggplot2::waiver())
  } else {
    p <- p + ggplot2::aes(group = 1)
  }
  return(p)
}

#' Generate a Multi-objective Optimization Plot
#'
#' This function generates a multi-objective optimization plot using `ggplot2`. The plot visualizes the relationship between the `x` and `y` variables, grouping and coloring by a fill variable, with the option to customize legend position, labels, and annotation of sampling and optimization phases.
#'
#' @param data A data frame containing the data to be plotted.
#' @param x A string representing the column name in `data` to be used for the x-axis. Can be either numeric or factor.
#' @param y A string representing the column name in `data` to be used for the y-axis. This should be a numeric variable.
#' @param fillColourGroup A string representing the column name in `data` that defines the fill color grouping for the plot. Default is `"ConditionID"`.
#' @param ytext A custom label for the y-axis. If not provided, the y-axis label will be the title-cased version of `y`.
#' @param legendPos A numeric vector of length 2 specifying the position of the legend inside the plot. Default is `c(0.65, 0.85)`.
#' @param numberSamplingSteps An integer specifying the number of initial sampling steps before the optimization phase begins. Default is 5.
#' @param labelPosFormulaY A string specifying the vertical position of the polynomial equation label in the plot. Acceptable values are `"top"`, `"center"`, or `"bottom"`. Default is `"top"`.
#' @param verticalLinePosY A numeric value of the y-coordinate where the "sampling" and "optimization" line should be drawn.
#'
#' @return A `ggplot` object representing the multi-objective optimization plot, ready to be rendered.
#' @export
#'
#' @examples
#' library(ggplot2)
#' library(ggpmisc)
#'
#' # Example with numeric x-axis
#' df <- data.frame(
#'   x = 1:20,
#'   y = rnorm(20),
#'   ConditionID = rep(c("A", "B"), 10)
#' )
#' generateMoboPlot(df, x = "x", y = "y")
#'
#' # Example with factor x-axis
#' df <- data.frame(
#'   x = factor(rep(1:5, each = 4)),
#'   y = rnorm(20),
#'   ConditionID = rep(c("A", "B"), 10)
#' )
#' generateMoboPlot(df, x = "x", y = "y", numberSamplingSteps = 3)
generateMoboPlot <- function(data, x, y, fillColourGroup = "ConditionID", ytext, legendPos = c(0.65, 0.85), numberSamplingSteps = 5, labelPosFormulaY = "top", verticalLinePosY = 0.75) {
  not_empty(data)
  not_empty(x)
  not_empty(y)
  not_empty(fillColourGroup)
  .check_columns(data, c(x, y, fillColourGroup))

  # as default, just add the y variable in Title caps
  if (missing(ytext)) {
    ytext <- stringr::str_to_title(y)
  }

  # A factor's storage codes are not its numeric labels; route factors through
  # character first so e.g. levels c(10, 20, 30) are not read as c(1, 2, 3).
  x_numeric <- if (is.factor(data[[x]])) as.numeric(as.character(data[[x]])) else as.numeric(data[[x]])
  maxIteration <- max(x_numeric, na.rm = TRUE)
  numberOptimizations <- maxIteration - numberSamplingSteps

  p <- data |> ggplot2::ggplot() +
    ggplot2::aes(
      x = !!rlang::sym(x),
      y = !!rlang::sym(y),
      fill = !!rlang::sym(fillColourGroup),
      colour = !!rlang::sym(fillColourGroup),
      group = !!rlang::sym(fillColourGroup)
    ) +
    see::scale_fill_see() +
    see::scale_color_see() +
    ggplot2::labs(y = ytext) +
    ggplot2::theme(legend.position = "inside", legend.position.inside = legendPos) +
    ggplot2::labs(x = "Iteration") +
    ggplot2::stat_summary(fun = mean, geom = "point", size = 4.0, alpha = 0.9) +
    ggplot2::stat_summary(fun = mean, geom = "line", linewidth = 1, alpha = 0.3) +
    ggplot2::stat_summary(
      fun.data = "mean_cl_boot",
      geom = "errorbar",
      width = .5,
      position = ggplot2::position_dodge(width = 0.1),
      alpha = 0.5
    ) +
    ggplot2::annotate("text", x = numberSamplingSteps / 2.0, y = verticalLinePosY - 0.2, label = "Sampling") +
    # annotate() draws the guide lines exactly once; mapping these constants
    # inside aes() would draw one overlapping segment per data row.
    ggplot2::annotate(
      "segment",
      x = 0,
      y = verticalLinePosY,
      xend = numberSamplingSteps + 0.2,
      yend = verticalLinePosY,
      linetype = "dashed",
      color = "black"
    ) +
    ggplot2::annotate(
      "text",
      x = numberOptimizations / 2.0 + numberSamplingSteps,
      y = verticalLinePosY - 0.2,
      label = "Optimization"
    ) +
    ggplot2::annotate(
      "segment",
      x = numberSamplingSteps + 0.8,
      y = verticalLinePosY,
      xend = maxIteration,
      yend = verticalLinePosY,
      color = "black"
    ) +
    ggpmisc::stat_poly_eq(ggpmisc::use_label(c("eq", "R2")), label.y = labelPosFormulaY) +
    ggpmisc::stat_poly_line(fullrange = FALSE, alpha = 0.1, linetype = "dashed", linewidth = 0.5) +
    ggplot2::geom_vline(
      xintercept = numberSamplingSteps + 0.5,
      linetype = "dashed",
      color = "black",
      alpha = 0.5
    )

  return(p)
}


#' Animate a Multi-objective Optimization Plot
#'
#' Renders [generateMoboPlot2()] one iteration at a time and encodes the frames
#' into a video, so a talk or a supplement can show an optimisation run building
#' up rather than only its end state. Frame *i* is the same plot restricted to
#' the data up to iteration *i*: the mean points, their bootstrapped intervals,
#' the fitted line and its equation all move as the run proceeds.
#'
#' The plot is built once from the complete data, and a frame only ever hides
#' rows. That is what keeps the axes, the sampling/optimisation guides and the
#' legend still while the data grows -- and it is also the only way the early
#' frames can be drawn at all, since [generateMoboPlot2()] requires both phases
#' to be present and the first iterations are all sampling.
#'
#' @param data A data frame holding the run, as for [generateMoboPlot2()].
#' @param x A string naming the iteration column in `data`. Default
#'   `"Iteration"`.
#' @param y A string naming the objective column in `data`.
#' @param filename Path of the video to write. Its extension chooses the container:
#'   `.mp4`, `.gif`, `.mov`, `.webm` -- whatever the `av` package's FFmpeg build
#'   can encode.
#' @param ... Further arguments for [generateMoboPlot2()], e.g. `phaseCol`,
#'   `fillColourGroup`, `ytext`, `legendPos`, `fillLabels`.
#' @param fps Frames per second. One frame is drawn per iteration, so this is
#'   equally the number of iterations shown per second. Default 5.
#' @param end_pause Seconds to hold the final frame, so the finished plot can be
#'   read before the video ends or loops. Default 2; use 0 for no hold.
#' @param width,height Frame size in inches. Default 8 x 5.
#' @param dpi Resolution. Default 150, so the default frame is 1200 x 750 px.
#' @param label_iterations Whether to caption each frame with the iteration it
#'   shows. Default `TRUE`, which writes the plot's subtitle.
#'
#' @return Invisibly returns `filename`.
#' @seealso [generateMoboPlot2()] for the static plot.
#' @export
#'
#' @examples \donttest{
#' # Kept deliberately tiny: every frame is a full ggplot render, so the cost
#' # of the example is set by the number of iterations, not by the frame size.
#' if (requireNamespace("av", quietly = TRUE)) {
#'   set.seed(42)
#'   df <- data.frame(
#'     Iteration   = rep(1:3, each = 4),
#'     ConditionID = rep(rep(c("A", "B"), each = 2), 3),
#'     Phase       = rep(c("Sampling", "Optimization"), times = c(2 * 4, 4))
#'   )
#'   df$score <- 0.3 + 0.05 * df$Iteration + stats::rnorm(nrow(df), sd = 0.05)
#'
#'   animate_mobo2(
#'     df,
#'     y = "score", ytext = "Score",
#'     filename = file.path(tempdir(), "mobo.mp4"),
#'     width = 4, height = 2.5, dpi = 96, end_pause = 0
#'   )
#' }
#' }
animate_mobo2 <- function(data, x = "Iteration", y, filename, ..., fps = 5, end_pause = 2,
                          width = 8, height = 5, dpi = 150, label_iterations = TRUE) {
  not_empty(data)
  not_empty(x)
  not_empty(y)
  not_empty(filename)

  if (!requireNamespace("av", quietly = TRUE)) {
    stop("Package 'av' is required to encode the video. Please install it.", call. = FALSE)
  }
  for (arg in c("fps", "width", "height", "dpi")) {
    value <- get(arg)
    if (!is.numeric(value) || length(value) != 1L || is.na(value) || value <= 0) {
      stop("`", arg, "` must be a single positive number.", call. = FALSE)
    }
  }
  if (!is.numeric(end_pause) || length(end_pause) != 1L || is.na(end_pause) || end_pause < 0) {
    stop("`end_pause` must be a single non-negative number (seconds).", call. = FALSE)
  }

  # Built from the COMPLETE data: this is what fixes the scales, the phase
  # guides and the legend for every frame. See the details in the help page.
  p <- generateMoboPlot2(data = data, x = x, y = y, ...)

  # The ranges are read back off the built plot rather than off the data, so
  # that the errorbar whiskers and the annotations stay inside the frame.
  panel <- ggplot2::ggplot_build(p)$layout$panel_params[[1]]
  p <- p + ggplot2::coord_cartesian(
    xlim = panel$x.range, ylim = panel$y.range, expand = FALSE
  )

  x_numeric <- if (is.factor(data[[x]])) as.numeric(as.character(data[[x]])) else as.numeric(data[[x]])
  iterations <- sort(unique(x_numeric[!is.na(x_numeric)]))
  if (length(iterations) < 2L) {
    stop("`data` must cover at least two iterations to animate.", call. = FALSE)
  }

  # H.264 refuses odd pixel dimensions, so the frame is rounded to an even
  # number of pixels. The rounding has to happen in pixels and the device has to
  # be opened in pixels: handing ggsave() the equivalent size in inches leaves
  # the count to a floating-point multiplication, and 316/150 in at 150 dpi
  # comes back as 315 px, which FFmpeg then refuses to encode.
  width_px <- 2 * round(width * dpi / 2)
  height_px <- 2 * round(height * dpi / 2)

  frame_dir <- tempfile("colleyRstats-mobo-")
  dir.create(frame_dir)
  on.exit(unlink(frame_dir, recursive = TRUE), add = TRUE)

  message("Rendering ", length(iterations), " frames ...")

  last <- iterations[length(iterations)]
  frames <- vapply(seq_along(iterations), function(i) {
    frame <- p
    frame$data <- data[!is.na(x_numeric) & x_numeric <= iterations[i], , drop = FALSE]
    if (isTRUE(label_iterations)) {
      frame <- frame + ggplot2::labs(
        subtitle = paste0("Iteration ", iterations[i], " / ", last)
      )
    }
    path <- file.path(frame_dir, sprintf("frame-%05d.png", i))
    grDevices::png(path, width = width_px, height = height_px, res = dpi, bg = "white")
    on.exit(grDevices::dev.off(), add = TRUE)
    # The first frames hold too few points for the fit and for the bootstrapped
    # interval, and ggplot2 says so once per frame. That is noise here, not news.
    suppressWarnings(suppressMessages(print(frame)))
    path
  }, character(1))

  # Repeating the last frame is what holds it on screen: the video is encoded at
  # a fixed frame rate, so there is no per-frame duration to lengthen instead.
  if (end_pause > 0) {
    frames <- c(frames, rep(frames[length(frames)], max(1L, round(end_pause * fps))))
  }

  out_dir <- dirname(filename)
  if (!dir.exists(out_dir)) {
    dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  }
  av::av_encode_video(frames, output = filename, framerate = fps, verbose = FALSE)

  message(
    "Saved animation to '", filename, "' (", length(iterations), " iterations at ",
    fps, " fps, ", width_px, " x ", height_px, " px)."
  )
  invisible(filename)
}


#' Check the data's distribution. If non-normal, take the non-parametric variant of *ggwithinstats*.
#' x and y have to be in parentheses, e.g., "ConditionID".
#'
#' @param data the data frame
#' @param x the independent variable, most likely "ConditionID"
#' @param y the dependent variable under investigation
#' @param ylab label to be shown for the dependent variable
#' @param xlabels labels to be used for the x-axis
#' @param showPairwiseComp whether to show pairwise comparisons, TRUE as default
#' @param plotType either "box", "violin", or "boxviolin" (default)
#'
#' @return A \code{ggplot} object produced by \code{ggstatsplot::ggwithinstats} with additional significance annotations, which can be printed or modified.
#' @export
#'
#' @examples \donttest{
#'
#' #'   set.seed(123)
#'
#' # Toy within-subject style data
#' main_df <- data.frame(
#'   Participant = factor(rep(1:20, each = 3)),
#'   CondID      = factor(rep(c("A", "B", "C"), times = 20)),
#'   tlx_mental  = rnorm(60, mean = 50, sd = 10)
#' )
#'
#' # Custom x-axis labels
#' labels_xlab <- c("Condition A", "Condition B", "Condition C")
#'
#'
#' ggwithinstatsWithPriorNormalityCheck(
#'   data = main_df,
#'   x = "CondID", y = "tlx_mental",
#'   ylab = "Mental Demand",
#'   xlabels = labels_xlab,
#'   showPairwiseComp = TRUE
#' )
#' }
ggwithinstatsWithPriorNormalityCheck <- function(data, x, y, ylab, xlabels = NULL, showPairwiseComp = TRUE, plotType = "boxviolin") {
  not_empty(data)
  not_empty(x)
  not_empty(y)
  not_empty(ylab)
  .check_columns(data, c(x, y))
  .check_xlabels(data, x, xlabels)

  is_normal <- check_normality_by_group(data, x, y)
  type <- ifelse(is_normal, "p", "np")

  # No Levene check here: ggwithinstats() (repeated measures) takes no
  # var.equal argument, so computing it would be wasted work.

  plot <- ggstatsplot::ggwithinstats(
    data = data, x = !!x, y = !!y, type = type, centrality.type = "p", ylab = ylab, xlab = "", pairwise.comparisons = showPairwiseComp,
    centrality.point.args = list(size = 5, alpha = 0.5, color = "darkblue"), palette = "pals::glasbey",
    plot.type = plotType,
    p.adjust.method = "holm",
    ggplot.component = list(
      ggplot2::theme(
        # No absolute `text` size here: it would override whatever base_size
        # the caller set for the figure, which is the one thing that has to
        # follow the output width. Only the emphasis is stated.
        plot.subtitle = ggplot2::element_text(size = ggplot2::rel(1), face = "bold")
      )
    ),
    # Derived from the active theme rather than fixed: ggsignif measures text in
    # millimetres, so a constant here is a constant physical size no matter how
    # small the figure is drawn.
    ggsignif.args = list(textsize = .signif_text_mm(), tip_length = 0.01)
  )

  # Only apply custom xlabels if they are provided
  if (!is.null(xlabels) && length(xlabels) > 0) {
    plot <- plot + ggplot2::scale_x_discrete(labels = xlabels)
  }

  return(plot)
}


#' Check the data's distribution. If non-normal, take the non-parametric variant of *ggbetweenstats*.
#' x and y have to be in parentheses, e.g., "ConditionID".
#'
#' @param data the data frame
#' @param x the independent variable, most likely "ConditionID"
#' @param y the dependent variable under investigation
#' @param ylab label to be shown for the dependent variable
#' @param xlabels labels to be used for the x-axis
#' @param showPairwiseComp whether to show pairwise comparisons, TRUE as default
#' @param plotType either "box", "violin", or "boxviolin" (default)
#'
#' @return A \code{ggplot} object produced by \code{ggstatsplot::ggbetweenstats}, which can be printed or further modified with \code{+}.
#' @export
#'
#' @examples \donttest{
#'
#' set.seed(123)
#'
#' # Toy within-subject style data
#' main_df <- data.frame(
#'   Participant = factor(rep(1:20, each = 3)),
#'   CondID      = factor(rep(c("A", "B", "C"), times = 20)),
#'   tlx_mental  = rnorm(60, mean = 50, sd = 10)
#' )
#'
#' # Custom x-axis labels
#' labels_xlab <- c("Condition A", "Condition B", "Condition C")
#'
#'
#' ggbetweenstatsWithPriorNormalityCheck(
#'   data = main_df,
#'   x = "CondID",
#'   y = "tlx_mental", ylab = "Mental Demand",
#'   xlabels = labels_xlab,
#'   showPairwiseComp = TRUE
#' )
#' }
ggbetweenstatsWithPriorNormalityCheck <- function(data, x, y, ylab, xlabels = NULL, showPairwiseComp = TRUE, plotType = "boxviolin") {
  not_empty(data)
  not_empty(x)
  not_empty(y)
  not_empty(ylab)
  .check_columns(data, c(x, y))
  .check_xlabels(data, x, xlabels)

  is_normal <- check_normality_by_group(data, x, y)
  type <- ifelse(is_normal, "p", "np")

  # homogeneity of variances: Levene
  group_all_data_equal <- check_homogeneity_by_group(data, x, y)

  # if one group_all_data_equal then we use the var.equal = TRUE, see here: https://github.com/IndrajeetPatil/ggstatsplot/issues/880
  plot <- ggstatsplot::ggbetweenstats(
    data = data, x = !!x, y = !!y, type = type, centrality.type = "p", ylab = ylab, xlab = "", pairwise.comparisons = showPairwiseComp, var.equal = group_all_data_equal,
    centrality.point.args = list(size = 5, alpha = 0.5, color = "darkblue"), palette = "pals::glasbey", plot.type = plotType,
    p.adjust.method = "holm",
    ggplot.component = list(
      ggplot2::theme(
        # No absolute `text` size here: it would override whatever base_size
        # the caller set for the figure, which is the one thing that has to
        # follow the output width. Only the emphasis is stated.
        plot.subtitle = ggplot2::element_text(size = ggplot2::rel(1), face = "bold")
      )
    ),
    # Derived from the active theme rather than fixed: ggsignif measures text in
    # millimetres, so a constant here is a constant physical size no matter how
    # small the figure is drawn.
    ggsignif.args = list(textsize = .signif_text_mm(), tip_length = 0.01)
  )

  if (!is.null(xlabels) && length(xlabels) > 0) {
    plot <- plot + ggplot2::scale_x_discrete(labels = xlabels)
  }

  plot
}


#' Check the data's distribution. If non-normal, take the non-parametric variant of *ggbetweenstats*.
#' x and y have to be in parentheses, e.g., "ConditionID".
#'
#' @param data the data frame
#' @param x the independent variable, most likely "ConditionID"
#' @param y the dependent variable under investigation
#' @param ylab label to be shown for the dependent variable
#' @param xlabels labels to be used for the x-axis
#' @param plotType either "box", "violin", or "boxviolin" (default)
#'
#' @return A \code{ggplot} object produced by \code{ggstatsplot::ggbetweenstats}
#'   with additional significance annotations, which can be printed or modified.
#' @export
#'
#' @examples \donttest{
#'
#' set.seed(123)
#'
#' # Toy within-subject style data
#' main_df <- data.frame(
#'   Participant = factor(rep(1:20, each = 3)),
#'   CondID      = factor(rep(c("A", "B", "C"), times = 20)),
#'   tlx_mental  = rnorm(60, mean = 50, sd = 10)
#' )
#'
#' # Custom x-axis labels
#' labels_xlab <- c("Condition A", "Condition B", "Condition C")
#'
#'
#' ggbetweenstatsWithPriorNormalityCheckAsterisk(
#'   data = main_df,
#'   x = "CondID", y = "tlx_mental", ylab = "Mental Demand", xlabels = labels_xlab
#' )
#' }
ggbetweenstatsWithPriorNormalityCheckAsterisk <- function(data, x, y, ylab, xlabels, plotType = "boxviolin") {
  not_empty(data)
  not_empty(x)
  not_empty(y)
  not_empty(ylab)
  not_empty(xlabels)
  .check_columns(data, c(x, y))
  .check_xlabels(data, x, xlabels)

  is_normal <- check_normality_by_group(data, x, y)
  type <- ifelse(is_normal, "p", "np")

  # homogeneity of variances: Levene
  group_all_data_equal <- check_homogeneity_by_group(data, x, y)

  # Calculate pairwise comparisons
  df <- statsExpressions::pairwise_comparisons(data = data, x = !!x, y = !!y, type = type, paired = FALSE, p.adjust.method = "holm") |>
    dplyr::mutate(groups = purrr::pmap(.l = list(group1, group2), .f = c)) |>
    dplyr::arrange(group1) |>
    dplyr::mutate(asterisk_label = .p_to_asterisk(p.value)) |>
    dplyr::filter(!is.na(asterisk_label))

  # Create the base plot
  p <- ggstatsplot::ggbetweenstats(
    data = data, x = !!x, y = !!y, type = type, centrality.type = "p", ylab = ylab, xlab = "", pairwise.display = "none", var.equal = group_all_data_equal,
    centrality.point.args = list(size = 5, alpha = 0.5, color = "darkblue"), palette = "pals::glasbey", plot.type = plotType,
    p.adjust.method = "holm",
    ggplot.component = list(
      ggplot2::theme(
        # No absolute `text` size here: it would override whatever base_size
        # the caller set for the figure, which is the one thing that has to
        # follow the output width. Only the emphasis is stated.
        plot.subtitle = ggplot2::element_text(size = ggplot2::rel(1), face = "bold")
      )
    ),
    # Derived from the active theme rather than fixed: ggsignif measures text in
    # millimetres, so a constant here is a constant physical size no matter how
    # small the figure is drawn.
    ggsignif.args = list(textsize = .signif_text_mm(), tip_length = 0.01)
  ) + ggplot2::scale_x_discrete(labels = xlabels)

  # Only add asterisks if there are significant differences
  if (nrow(df) > 0) {
    # Stack the brackets above the largest observed value, spaced relative to
    # the data range so the layout works for any dependent-variable scale
    # (e.g. 1-7 Likert and 0-100 TLX alike). df only contains significant
    # comparisons at this point, so no NA handling is needed.
    y_max <- max(data[[y]], na.rm = TRUE)
    y_span <- y_max - min(data[[y]], na.rm = TRUE)
    step <- if (y_span > 0) 0.05 * y_span else 0.25
    y_positions_asterisks <- y_max + step * seq_len(nrow(df))

    p <- p + ggsignif::geom_signif(
      comparisons = df$groups,
      map_signif_level = TRUE,
      annotations = df$asterisk_label,
      y_position = y_positions_asterisks,
      size = 0.45, # 0.5 is default
      textsize = .signif_text_mm(), # follows the theme; 3.88 mm is the default
      fontface = "bold",
      test = NULL,
      na.rm = TRUE
    )
  }

  return(p)
}

#' Check the data's distribution. If non-normal, take the non-parametric variant of *ggwithinstats*.
#' x and y have to be in parentheses, e.g., "ConditionID". Add Asterisks instead of p-values.
#'
#' @param data the data frame
#' @param x the independent variable, most likely "ConditionID"
#' @param y the dependent variable under investigation
#' @param ylab label to be shown for the dependent variable
#' @param xlabels labels to be used for the x-axis
#' @param plotType either "box", "violin", or "boxviolin" (default)
#'
#' @return A \code{ggplot} object produced by \code{ggstatsplot::ggwithinstats}
#'   with additional significance annotations, which can be printed or modified.
#' @export
#'
#' @examples \donttest{
#'
#' set.seed(123)
#'
#' # Toy within-subject style data
#' main_df <- data.frame(
#'   Participant = factor(rep(1:20, each = 3)),
#'   CondID      = factor(rep(c("A", "B", "C"), times = 20)),
#'   tlx_mental  = rnorm(60, mean = 50, sd = 10)
#' )
#'
#' # Custom x-axis labels
#' labels_xlab <- c("Condition A", "Condition B", "Condition C")
#'
#'
#' ggwithinstatsWithPriorNormalityCheckAsterisk(
#'   data = main_df,
#'   x = "CondID", y = "tlx_mental",
#'   ylab = "Mental Demand", xlabels = labels_xlab
#' )
#' }
ggwithinstatsWithPriorNormalityCheckAsterisk <- function(data, x, y, ylab, xlabels, plotType = "boxviolin") {
  not_empty(data)
  not_empty(x)
  not_empty(y)
  not_empty(ylab)
  not_empty(xlabels)
  .check_columns(data, c(x, y))
  .check_xlabels(data, x, xlabels)

  is_normal <- check_normality_by_group(data, x, y)
  type <- ifelse(is_normal, "p", "np")

  # No Levene check here: ggwithinstats() (repeated measures) takes no
  # var.equal argument, so computing it would be wasted work.

  df <- statsExpressions::pairwise_comparisons(data = data, x = !!x, y = !!y, type = type, paired = TRUE, p.adjust.method = "holm") |>
    dplyr::mutate(groups = purrr::pmap(.l = list(group1, group2), .f = c)) |>
    dplyr::arrange(group1) |>
    dplyr::mutate(asterisk_label = .p_to_asterisk(p.value)) |>
    dplyr::filter(!is.na(asterisk_label))

  p <- ggstatsplot::ggwithinstats(
    data = data, x = !!x, y = !!y, type = type, centrality.type = "p", ylab = ylab, xlab = "", pairwise.display = "none",
    centrality.point.args = list(size = 5, alpha = 0.5, color = "darkblue"), palette = "pals::glasbey", plot.type = plotType,
    p.adjust.method = "holm",
    ggplot.component = list(
      ggplot2::theme(
        # No absolute `text` size here: it would override whatever base_size
        # the caller set for the figure, which is the one thing that has to
        # follow the output width. Only the emphasis is stated.
        plot.subtitle = ggplot2::element_text(size = ggplot2::rel(1), face = "bold")
      )
    ),
    # Derived from the active theme rather than fixed: ggsignif measures text in
    # millimetres, so a constant here is a constant physical size no matter how
    # small the figure is drawn.
    ggsignif.args = list(textsize = .signif_text_mm(), tip_length = 0.01)
  ) + ggplot2::scale_x_discrete(labels = xlabels)

  # Only add asterisks if there are significant differences
  if (nrow(df) > 0) {
    # Stack the brackets above the largest observed value, spaced relative to
    # the data range so the layout works for any dependent-variable scale
    # (e.g. 1-7 Likert and 0-100 TLX alike). df only contains significant
    # comparisons at this point, so no NA handling is needed.
    y_max <- max(data[[y]], na.rm = TRUE)
    y_span <- y_max - min(data[[y]], na.rm = TRUE)
    step <- if (y_span > 0) 0.05 * y_span else 0.25
    y_positions_asterisks <- y_max + step * seq_len(nrow(df))

    p <- p + ggsignif::geom_signif(
      comparisons = df$groups,
      map_signif_level = TRUE,
      annotations = df$asterisk_label,
      y_position = y_positions_asterisks,
      size = 0.45, # 0.5 is default
      textsize = .signif_text_mm(), # follows the theme; 3.88 mm is the default
      fontface = "bold",
      test = NULL,
      na.rm = TRUE
    )
  }

  return(p)
}
