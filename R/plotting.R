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


# Internal: every within-subjects entry point needs to know which rows belong to
# the same participant. ggstatsplot will happily run without that information and
# pair the k-th row of one condition with the k-th row of the next -- so a data
# frame sorted by anything other than participant, or a single participant
# missing one condition, silently pairs the wrong observations and yields a
# confident, wrong test. The argument is therefore required, not defaulted.
.require_subject <- function(subject) {
  if (is.null(subject) || length(subject) == 0L ||
      (length(subject) == 1L && (is.na(subject) || !nzchar(subject)))) {
    stop(
      "`subject` is required for a within-subjects (repeated-measures) analysis: ",
      "name the participant-ID column, e.g. subject = \"participant\". ",
      "Without it, observations would be paired by row order.",
      call. = FALSE
    )
  }
  if (!is.character(subject) || length(subject) != 1L) {
    stop("`subject` must be a single column name (a string).", call. = FALSE)
  }
  invisible(TRUE)
}


# Internal: the complete-case data a paired analysis can actually use, as
# decided by .complete_within() (utils.R) -- the rule the normality check, the
# post-hoc descriptives and the assumption advice share -- with each exclusion
# announced. The normality check, the figure and the pairwise tests all run on
# this one data set, so they cannot disagree about who was analysed. The
# condition column comes back as a factor, so numeric condition codes (1, 2, 3)
# are treated as categories.
.prepare_within_data <- function(data, x, y, subject) {
  .check_columns(data, c(x, y, subject))
  if (length(unique(c(x, y, subject))) < 3L) {
    stop("`x`, `y` and `subject` must name three different columns.", call. = FALSE)
  }
  kept <- .complete_within(data, subject, x, y,
                           context = paste0("Within-subjects analysis of '", y, "': "))
  d <- kept$data
  d[[x]] <- droplevels(as.factor(d[[x]]))
  if (is.factor(d[[subject]])) {
    d[[subject]] <- droplevels(d[[subject]])
  }

  if (nlevels(d[[x]]) < 2L) {
    stop("A within-subjects analysis of '", y, "' needs at least two conditions of '", x,
         "' with data.", call. = FALSE)
  }
  if (kept$n_subjects < 2L) {
    stop("Fewer than two participants have a value of '", y, "' in every condition of '", x,
         "'; a paired analysis is not possible.", call. = FALSE)
  }
  list(data = d, dropped_subjects = kept$dropped_subjects)
}


# Internal: the between-subjects counterpart -- complete cases on x and y, and
# the grouping column as a factor on a copy, so numeric condition codes are
# groups rather than a covariate.
.prepare_between_data <- function(data, x, y) {
  d <- data[!is.na(data[[x]]) & !is.na(data[[y]]), , drop = FALSE]
  d[[x]] <- droplevels(as.factor(d[[x]]))
  d
}


# Internal: ggstatsplot is handed a copy holding only the analysed columns,
# under syntactic names. Its tests cope with a column called "Mental Demand",
# but the Bayes-factor caption does not: 'BayesFactor' rebuilds a model frame,
# fails on the non-syntactic name, and ggstatsplot drops the caption without a
# word. The names never reach the figure -- the wrappers set the axis titles
# from `ylab`/`xlabels` -- so renaming loses nothing.
.ggstats_frame <- function(data, cols) {
  new_names <- make.unique(make.names(unname(cols)))
  out <- as.data.frame(data)[, unname(cols), drop = FALSE]
  names(out) <- new_names
  list(data = out, names = stats::setNames(new_names, names(cols)))
}


# Internal: ggstatsplot 0.12.0 removed `plot.type`, so passing it now lands in
# `...` and is ignored -- every figure became a box-violin plot whatever was
# asked for. ggstatsplot always draws both geoms; its documented way to remove
# one is to give it zero width and no outline, which is what this does.
.plot_type_args <- function(plotType) {
  if (!is.character(plotType) || length(plotType) != 1L ||
      !plotType %in% c("boxviolin", "box", "violin")) {
    stop("`plotType` must be one of \"boxviolin\", \"box\" or \"violin\".", call. = FALSE)
  }
  hidden <- list(width = 0, linewidth = 0, colour = NA, na.rm = TRUE)
  switch(plotType,
    boxviolin = list(),
    box = list(violin.args = hidden),
    violin = list(boxplot.args = hidden)
  )
}


# Internal: ggstatsplot 0.12.0 replaced `pairwise.comparisons = TRUE/FALSE` with
# `pairwise.display`; the old argument fell into `...` and the brackets were
# shown whatever `showPairwiseComp` said.
.pairwise_display <- function(showPairwiseComp) {
  if (!is.logical(showPairwiseComp) || length(showPairwiseComp) != 1L || is.na(showPairwiseComp)) {
    stop("`showPairwiseComp` must be TRUE or FALSE.", call. = FALSE)
  }
  if (showPairwiseComp) "significant" else "none"
}


# Internal: the one ggstatsplot call behind all four wrappers, so they share
# the test, the centrality measure and the styling.
#
# `centrality.type` follows `type`: a non-parametric test is accompanied by
# medians, a parametric one by means. (It used to be fixed at "parametric",
# which printed means next to a Friedman or Kruskal-Wallis test.)
.ggstats_plot <- function(design, frame, type, ylab, pairwise_display, plotType) {
  nm <- frame$names
  args <- c(
    list(
      data = frame$data, x = nm[["x"]], y = nm[["y"]],
      type = type, centrality.type = type,
      ylab = ylab, xlab = "",
      pairwise.display = pairwise_display,
      p.adjust.method = "holm",
      centrality.point.args = list(size = 5, alpha = 0.5, color = "darkblue"),
      palette = "pals::glasbey",
      ggplot.component = list(
        ggplot2::theme(
          # No absolute `text` size here: it would override whatever base_size
          # the caller set for the figure, which is the one thing that has to
          # follow the output width. Only the emphasis is stated.
          plot.subtitle = ggplot2::element_text(size = ggplot2::rel(1), face = "bold")
        )
      ),
      # Derived from the active theme rather than fixed: ggsignif measures text
      # in millimetres, so a constant here is a constant physical size no
      # matter how small the figure is drawn.
      ggsignif.args = list(textsize = .signif_text_mm(), tip_length = 0.01)
    ),
    .plot_type_args(plotType)
  )
  if (design == "within") {
    # Pair by participant, never by row order (see .require_subject()).
    args$subject.id <- nm[["subject"]]
    rlang::exec(ggstatsplot::ggwithinstats, !!!args)
  } else {
    rlang::exec(ggstatsplot::ggbetweenstats, !!!args)
  }
}


# Internal: parametric if the assumption check passed, else non-parametric.
# (ifelse() would copy the check's attributes onto the result.)
.normality_type <- function(is_normal) {
  if (isTRUE(is_normal)) "parametric" else "nonparametric"
}


# Internal: the comparisons the asterisk variants draw, from the same test,
# pairing and correction as the figure they are drawn on.
#
# * Two conditions: ggstatsplot runs no post-hoc test, and its omnibus test (in
#   the subtitle) *is* the comparison. Re-testing the pair with the post-hoc
#   machinery would put a Dunn or Durbin-Conover p-value above a subtitle that
#   reports a Wilcoxon test -- two different p-values for one comparison in one
#   figure, which can sit on opposite sides of .05.
# * More conditions: statsExpressions::pairwise_comparisons() with the
#   arguments ggstatsplot itself uses, including the participant ID, so the
#   brackets show exactly the comparisons ggstatsplot would have computed.
.asterisk_comparisons <- function(p, frame, type, paired) {
  nm <- frame$names
  d <- frame$data
  xs <- nm[["x"]]
  ys <- nm[["y"]]
  lv <- levels(d[[xs]])

  if (length(lv) == 2L) {
    omnibus <- ggstatsplot::extract_stats(p)$subtitle_data
    tab <- data.frame(group1 = lv[1L], group2 = lv[2L], p.value = omnibus$p.value[1L],
                      stringsAsFactors = FALSE)
  } else {
    sid <- if (paired) rlang::sym(nm[["subject"]]) else NULL
    tab <- statsExpressions::pairwise_comparisons(
      data = d, x = !!xs, y = !!ys, subject.id = !!sid,
      type = type, paired = paired, p.adjust.method = "holm"
    )
  }

  tab |>
    dplyr::mutate(groups = purrr::pmap(.l = list(group1, group2), .f = c)) |>
    dplyr::arrange(group1) |>
    dplyr::mutate(asterisk_label = .p_to_asterisk(p.value)) |>
    dplyr::filter(!is.na(asterisk_label))
}


# Internal: draw the significant comparisons as asterisk brackets.
.add_asterisk_brackets <- function(p, df, yvals) {
  # Only add asterisks if there are significant differences
  if (nrow(df) == 0L) {
    return(p)
  }
  # Stack the brackets above the largest observed value, spaced relative to
  # the data range so the layout works for any dependent-variable scale
  # (e.g. 1-7 Likert and 0-100 TLX alike). df only contains significant
  # comparisons at this point, so no NA handling is needed.
  y_max <- max(yvals, na.rm = TRUE)
  y_span <- y_max - min(yvals, na.rm = TRUE)
  step <- if (y_span > 0) 0.05 * y_span else 0.25
  y_positions_asterisks <- y_max + step * seq_len(nrow(df))

  p + ggsignif::geom_signif(
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


# Internal: unweighted marginal means -- for each level of `x`, the mean of
# the cell means across `group`. Averaging the raw observations instead weights
# each cell by its size, so in an unbalanced design the "main effect" line
# tracks whichever group happens to have more participants (9 vs 1 where the
# cell means average 5 vs 5).
.unweighted_marginal_means <- function(data, x, y, group) {
  cells <- stats::aggregate(
    list(.mean = data[[y]]),
    by = list(.x = data[[x]], .g = data[[group]]),
    FUN = mean
  )
  n_x <- length(unique(data[[x]]))
  n_g <- length(unique(data[[group]]))
  if (nrow(cells) < n_x * n_g) {
    warning(
      "Not every combination of '", x, "' and '", group, "' has data; the main-effect ",
      "line averages only the cells that do, so its levels are not based on the same groups.",
      call. = FALSE
    )
  }
  marg <- stats::aggregate(list(.mean = cells$.mean), by = list(.x = cells$.x), FUN = mean)
  out <- data.frame(marg$.x, marg$.mean)
  names(out) <- c(x, y)
  out
}


# Internal: within-subject confidence intervals for each x-by-group cell
# (Cousineau, 2005, with the Morey, 2008, correction). Each participant's
# scores are centred on their own mean and moved to the grand mean, which
# removes the between-participant spread that a within-subject comparison does
# not depend on; the variance of the normalised scores is then inflated by
# M / (M - 1), M being the number of within-subject conditions, to undo the
# downward bias the centring introduces. A factor that does not vary within
# participants (a mixed design) is respected by normalising within its groups.
#
# Returns NULL (with a message) when neither factor varies within participants,
# so the caller can fall back to the between-subject interval.
.cousineau_morey_ci <- function(data, x, y, group, subject, conf.level = 0.95) {
  d <- data[!is.na(data[[x]]) & !is.na(data[[y]]) & !is.na(data[[group]]) &
              !is.na(data[[subject]]), , drop = FALSE]
  sid <- as.character(d[[subject]])
  factors <- unique(c(x, group))
  varies <- vapply(factors, function(f) {
    any(tapply(as.character(d[[f]]), sid, function(v) length(unique(v))) > 1L)
  }, logical(1))
  within <- factors[varies]
  between <- factors[!varies]
  if (length(within) == 0L) {
    message("Neither '", x, "' nor '", group, "' varies within participants ('", subject,
            "'); showing between-subject intervals.")
    return(NULL)
  }

  # One row per participant and within-subject condition, and only the
  # participants observed in all of them -- the rule every within-subjects
  # entry point shares. A between-subject `group` is constant within each
  # participant, so a participant's cells are fixed by the within factors alone.
  d <- .complete_within(d, subject, within, y,
                        context = paste0("Within-subject intervals for '", y, "': "))$data
  sid <- as.character(d[[subject]])
  M <- nlevels(interaction(d[within], drop = TRUE, sep = "\r"))

  between_key <- if (length(between) > 0L) {
    interaction(d[between], drop = TRUE, sep = "\r")
  } else {
    factor(rep("all", nrow(d)))
  }
  normalised <- d[[y]] - stats::ave(d[[y]], sid) + stats::ave(d[[y]], between_key)

  rows <- split(seq_len(nrow(d)), interaction(d[[x]], d[[group]], drop = TRUE, sep = "\r"))
  first <- vapply(rows, function(i) i[1L], integer(1))
  n <- lengths(rows)
  m <- vapply(rows, function(i) mean(d[[y]][i]), numeric(1))
  s <- vapply(rows, function(i) if (length(i) > 1L) stats::sd(normalised[i]) else NA_real_,
              numeric(1))
  se <- s / sqrt(n) * sqrt(M / (M - 1))
  half <- stats::qt((1 + conf.level) / 2, df = pmax(n - 1, 1)) * se

  ci <- data.frame(d[[x]][first], d[[group]][first], m, m - half, m + half)
  names(ci) <- c(x, group, y, ".lower", ".upper")
  rownames(ci) <- NULL
  list(ci = ci, data = d)
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
#' @param numberColors `r lifecycle::badge("deprecated")` Never had any
#'   effect: the colours come from [see::scale_colour_see()], which uses one
#'   colour per group. Passing it warns.
#' @param subject optional participant-ID column (a string). Give it when
#'   `x` and/or `fillColourGroup` vary within participants, to get
#'   within-subject error bars (see Details). Default \code{NULL}.
#'
#' @details
#' **Points and lines.** The small points and the dashed (main) or bold
#' (interaction) per-group lines are the cell means. The bold main-effect line
#' and its large points are the *unweighted* marginal means of `x`: for each
#' level of `x`, the mean of the cell means across `fillColourGroup`. That is
#' the quantity a main effect in a factorial ANOVA is about; the mean of the
#' raw observations would weight each cell by its size and, in an unbalanced
#' design, follow whichever group happens to be larger.
#'
#' **Error bars** are 95\% confidence intervals of each cell mean:
#' * `subject = NULL` (default): nonparametric bootstrap intervals
#'   ([ggplot2::mean_cl_boot()], requires 'Hmisc'). These treat every
#'   observation as independent, i.e. they are **between-subject** intervals.
#'   That is right for between-subject factors, but for a factor that varies
#'   within participants they include the between-participant spread a
#'   within-subject comparison does not depend on, and look misleadingly wide.
#' * `subject` given: **within-subject** intervals after Cousineau (2005), with
#'   the Morey (2008) correction. Each participant's scores are centred on
#'   their own mean, the variance of the normalised scores is inflated by
#'   \eqn{M/(M-1)} (\eqn{M} = number of within-subject conditions), and a
#'   factor that does not vary within participants is respected by normalising
#'   within its groups. Participants without a value in every within-subject
#'   condition are dropped (with a message), and more than one row per
#'   participant and cell is an error.
#'
#' Either way, the intervals describe single means, not differences between
#' them; overlapping bars do not by themselves imply a non-significant
#' difference.
#'
#' @references
#' Cousineau, D. (2005). Confidence intervals in within-subject designs: A
#' simpler solution to Loftus and Masson's method. *Tutorials in Quantitative
#' Methods for Psychology, 1*(1), 42--45.
#'
#' Morey, R. D. (2008). Confidence intervals from normalized data: A correction
#' to Cousineau (2005). *Tutorials in Quantitative Methods for Psychology,
#' 4*(2), 61--64.
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
                               numberColors = lifecycle::deprecated(),
                               subject = NULL) {
  not_empty(data)
  not_empty(x)
  not_empty(y)
  not_empty(fillColourGroup)
  not_empty(shownEffect)
  if (lifecycle::is_present(numberColors)) {
    lifecycle::deprecate_warn(
      when = "0.2.1",
      what = "generateEffectPlot(numberColors)",
      details = paste(
        "It never had any effect: the colours come from see::scale_colour_see(),",
        "which uses one colour per group."
      )
    )
  }
  .check_columns(data, c(x, y, fillColourGroup, subject))
  if (!shownEffect %in% c("main", "interaction")) {
    stop("ERROR: wrong effect defined for visualization.")
  }
  .check_xlabels(data, x, xLabelsOverwrite)

  # Error bars: between-subject bootstrap by default, within-subject
  # (Cousineau-Morey) when the participant is known -- see Details. With a
  # subject, every layer is drawn from the same complete-participant data.
  ci <- NULL
  if (!is.null(subject)) {
    cm <- .cousineau_morey_ci(data, x, y, fillColourGroup, subject)
    if (!is.null(cm)) {
      ci <- cm$ci
      data <- cm$data
    }
  }
  data <- data[!is.na(data[[x]]) & !is.na(data[[y]]) & !is.na(data[[fillColourGroup]]), ,
               drop = FALSE]
  marginal <- .unweighted_marginal_means(data, x, y, fillColourGroup)

  error_bars <- if (is.null(ci)) {
    ggplot2::stat_summary(
      fun.data = "mean_cl_boot",
      geom = "errorbar",
      width = .5,
      position = ggplot2::position_dodge(width = 0.05),
      alpha = 0.5
    )
  } else {
    ggplot2::geom_errorbar(
      data = ci,
      mapping = ggplot2::aes(ymin = .data$.lower, ymax = .data$.upper),
      width = .5,
      position = ggplot2::position_dodge(width = 0.05),
      alpha = 0.5
    )
  }

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

    # Points for each group (cell means)
    ggplot2::stat_summary(
      fun = mean,
      geom = "point",
      size = 5
    ) +

    # Error bars (see Details for which interval)
    error_bars +

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

  # The marginal (main-effect) layers are drawn from the precomputed unweighted
  # marginal means, not from stat_summary(aes(group = 1)): the latter averages
  # the raw rows and so weights each cell by its size (see Details).
  marginal_aes <- ggplot2::aes(x = .data[[x]], y = .data[[y]], group = 1)
  marginal_point_aes <- ggplot2::aes(
    x = .data[[x]], y = .data[[y]], group = 1, shape = !!effectDescription
  )

  if (shownEffect == "main") {
    p <- p +
      ggplot2::geom_line(
        data = marginal,
        mapping = marginal_aes,
        inherit.aes = FALSE,
        linewidth = 2,
        show.legend = FALSE
      ) +
      ggplot2::geom_point(
        data = marginal,
        mapping = marginal_point_aes,
        inherit.aes = FALSE,
        size = 6,
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
  } else {
    p <- p +
      ggplot2::geom_line(
        data = marginal,
        mapping = marginal_aes,
        inherit.aes = FALSE,
        linetype = "dashed",
        linewidth = 1,
        show.legend = FALSE
      ) +
      ggplot2::geom_point(
        data = marginal,
        mapping = marginal_point_aes,
        inherit.aes = FALSE,
        size = 6,
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
  }

  return(p)
}


# Internal: the iteration column as numbers. A factor (or character) column is
# accepted as long as its labels are numbers, and is converted through its
# labels -- a factor's storage codes are not its labels. The plots then use a
# continuous axis: a factor is otherwise drawn at positions 1, 2, 3, ... whatever
# its labels say, while the phase guides are placed at the iteration *values*,
# so with iterations 10, 20, ... (or 0, 1, ...) the guides landed away from the
# data and the fitted line's equation was in units of factor position.
.iteration_numeric <- function(data, x) {
  v <- data[[x]]
  out <- if (is.numeric(v)) v else suppressWarnings(as.numeric(as.character(v)))
  bad <- !is.na(v) & is.na(out)
  if (any(bad)) {
    stop(
      "`", x, "` must hold iteration numbers: numeric, or a factor/character whose labels ",
      "are numbers (found '", as.character(v[bad][1L]), "').",
      call. = FALSE
    )
  }
  out
}


# Internal: positions of the sampling/optimisation guides, in iteration units.
# For the usual iterations 1, 2, 3, ... these reproduce the historical layout
# exactly (sampling guide from 0 to S + 0.2, boundary at S + 0.5, optimisation
# guide from S + 0.8); for other spacings or starting points they scale with
# the actual iteration values instead of assuming 1-based, unit steps.
.mobo_guides <- function(x_numeric, last_sampling, last_iteration, integer_breaks = FALSE) {
  its <- sort(unique(x_numeric[!is.na(x_numeric)]))
  step <- if (length(its) > 1L) min(diff(its)) else 1
  after <- its[its > last_sampling]
  gap <- if (length(after) > 0L) after[1L] - last_sampling else step
  start <- its[1L] - step
  list(
    sampling_start = start,
    sampling_end = last_sampling + 0.2 * gap,
    sampling_label = (start + last_sampling) / 2,
    boundary = last_sampling + 0.5 * gap,
    optimization_start = last_sampling + 0.8 * gap,
    optimization_label = (last_sampling + last_iteration) / 2,
    last_iteration = last_iteration,
    # Iterations are whole numbers; a factor axis used to label each of them,
    # so keep the continuous axis from inventing "2.5".
    x_scale = if (integer_breaks) {
      ggplot2::scale_x_continuous(breaks = function(lims) {
        b <- pretty(lims)
        b[abs(b - round(b)) < 1e-8]
      })
    }
  )
}


#' Generate a Multi-objective Optimization Plot
#'
#' This function generates a multi-objective optimization plot using `ggplot2`. The plot visualizes the relationship between the `x` and `y` variables, grouping and coloring by a fill variable, with the option to customize legend position, labels, and annotation of sampling and optimization phases.
#' Appropriate if you use https://github.com/Pascal-Jansen/Bayesian-Optimization-for-Unity in version 1.1.0 or higher.
#'
#' @param data A data frame containing the data to be plotted.
#' @param x A string representing the column name in `data` to be used for the x-axis. Can be either numeric or a factor whose labels are numbers; it is plotted on a continuous axis either way, so the data, the phase guides and the fitted equation all refer to the iteration values (not to factor positions). Default is `"Iteration"`.
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

  # The iteration axis is plotted as a number, whatever class it arrived in
  # (see .iteration_numeric()), so that the data, the phase guides and the
  # fitted line all share one coordinate system.
  x_numeric <- .iteration_numeric(data, x)
  x_was_numeric <- is.numeric(data[[x]])
  data[[x]] <- x_numeric
  # Match phase labels case-insensitively so "Sampling"/"sampling" both work.
  phase <- tolower(as.character(data[[phaseCol]]))
  if (!any(phase == "sampling", na.rm = TRUE) || !any(phase == "optimization", na.rm = TRUE)) {
    stop(
      "Column '", phaseCol,
      "' must contain both 'sampling' and 'optimization' rows (case-insensitive)."
    )
  }
  guides <- .mobo_guides(
    x_numeric,
    last_sampling = max(x_numeric[phase %in% "sampling"], na.rm = TRUE),
    last_iteration = max(x_numeric[phase %in% "optimization"], na.rm = TRUE),
    integer_breaks = !x_was_numeric
  )


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
    ggplot2::annotate("text", x = guides$sampling_label, y = horizontalLinePosY - horizontalLineDistToText, label = "Sampling", size = annotationTextSize, fontface = "bold") +
    # annotate() draws the guide lines exactly once; mapping these constants
    # inside aes() would draw one overlapping segment per data row.
    ggplot2::annotate(
      "segment",
      x = guides$sampling_start, y = horizontalLinePosY,
      xend = guides$sampling_end, yend = horizontalLinePosY,
      linetype = "dashed", color = "black"
    ) +
    ggplot2::annotate("text",
      x = guides$optimization_label,
      y = horizontalLinePosY - horizontalLineDistToText, label = "Optimization",
      size = annotationTextSize, fontface = "bold"
    ) +
    ggplot2::annotate(
      "segment",
      x = guides$optimization_start, y = horizontalLinePosY,
      xend = guides$last_iteration, yend = horizontalLinePosY,
      color = "black"
    ) +
    ggpmisc::stat_poly_eq(ggpmisc::use_label(c("eq", "R2")), label.y = labelPosFormulaY, label.x = labelPosFormulaX, size = annotationTextSize) +
    ggpmisc::stat_poly_line(fullrange = FALSE, alpha = 0.1, linetype = "dashed", linewidth = 0.5) +
    ggplot2::geom_vline(
      xintercept = guides$boundary,
      linetype = "dashed", color = "black", alpha = 0.5
    ) +
    guides$x_scale

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
#' @param x A string representing the column name in `data` to be used for the x-axis. Can be either numeric or a factor whose labels are numbers; it is plotted on a continuous axis either way, so the data, the phase guides and the fitted equation all refer to the iteration values (not to factor positions).
#' @param y A string representing the column name in `data` to be used for the y-axis. This should be a numeric variable.
#' @param fillColourGroup A string representing the column name in `data` that defines the fill color grouping for the plot. Default is `"ConditionID"`.
#' @param ytext A custom label for the y-axis. If not provided, the y-axis label will be the title-cased version of `y`.
#' @param legendPos A numeric vector of length 2 specifying the position of the legend inside the plot. Default is `c(0.65, 0.85)`.
#' @param numberSamplingSteps An integer specifying the number of initial sampling steps before the optimization phase begins, counted in distinct iterations from the first one (so it also works when iterations start at 0 or are spaced by more than 1). Must be smaller than the number of iterations. Default is 5.
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
#' \donttest{
#' # Example with factor x-axis
#' df <- data.frame(
#'   x = factor(rep(1:5, each = 4)),
#'   y = rnorm(20),
#'   ConditionID = rep(c("A", "B"), 10)
#' )
#' generateMoboPlot(df, x = "x", y = "y", numberSamplingSteps = 3)
#' }
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

  # Plotted as numbers whatever the class (see .iteration_numeric()).
  x_numeric <- .iteration_numeric(data, x)
  x_was_numeric <- is.numeric(data[[x]])
  data[[x]] <- x_numeric

  # `numberSamplingSteps` counts iterations; the guides need the iteration
  # *value* that ends the sampling phase. For iterations 1, 2, 3, ... the two
  # coincide, which is what the code used to assume.
  its <- sort(unique(x_numeric[!is.na(x_numeric)]))
  if (!is.numeric(numberSamplingSteps) || length(numberSamplingSteps) != 1L ||
      is.na(numberSamplingSteps) || numberSamplingSteps != round(numberSamplingSteps) ||
      numberSamplingSteps < 1 || numberSamplingSteps >= length(its)) {
    stop(
      "`numberSamplingSteps` must be a whole number between 1 and ", length(its) - 1L,
      " (the data cover ", length(its), " iterations).",
      call. = FALSE
    )
  }
  guides <- .mobo_guides(
    x_numeric,
    last_sampling = its[numberSamplingSteps],
    last_iteration = its[length(its)],
    integer_breaks = !x_was_numeric
  )

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
    ggplot2::annotate("text", x = guides$sampling_label, y = verticalLinePosY - 0.2, label = "Sampling") +
    # annotate() draws the guide lines exactly once; mapping these constants
    # inside aes() would draw one overlapping segment per data row.
    ggplot2::annotate(
      "segment",
      x = guides$sampling_start,
      y = verticalLinePosY,
      xend = guides$sampling_end,
      yend = verticalLinePosY,
      linetype = "dashed",
      color = "black"
    ) +
    ggplot2::annotate(
      "text",
      x = guides$optimization_label,
      y = verticalLinePosY - 0.2,
      label = "Optimization"
    ) +
    ggplot2::annotate(
      "segment",
      x = guides$optimization_start,
      y = verticalLinePosY,
      xend = guides$last_iteration,
      yend = verticalLinePosY,
      color = "black"
    ) +
    ggpmisc::stat_poly_eq(ggpmisc::use_label(c("eq", "R2")), label.y = labelPosFormulaY) +
    ggpmisc::stat_poly_line(fullrange = FALSE, alpha = 0.1, linetype = "dashed", linewidth = 0.5) +
    ggplot2::geom_vline(
      xintercept = guides$boundary,
      linetype = "dashed",
      color = "black",
      alpha = 0.5
    ) +
    guides$x_scale

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

  # Frames subset the plot's own data, in which generateMoboPlot2() has already
  # turned a factor iteration column into numbers; subsetting the caller's
  # `data` instead would hand a factor to the continuous x scale.
  data <- p$data
  x_numeric <- data[[x]]
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
#' Observations are paired by the participant ID in `subject`, never by row
#' order. Before anything is computed, rows without a condition, outcome or ID
#' are dropped, participants lacking any condition are left out (with a message
#' saying how many and which), and more than one row per participant and
#' condition is an error -- aggregate repeated trials first. The normality
#' check ([check_normality_by_group()] with `subject`, i.e. on the paired
#' differences or on the residuals of the repeated-measures model), the figure
#' and the pairwise tests all use this same data. The condition column is
#' treated as a factor, so numeric condition codes are categories.
#'
#' If the check passes, ggstatsplot runs a paired t-test (two conditions) or a
#' repeated-measures ANOVA with paired Student's t post-hoc tests, and labels
#' the means; otherwise a Wilcoxon signed-rank or Friedman test with
#' Durbin-Conover post-hoc tests, and labels the medians. Post-hoc p-values are
#' Holm-adjusted.
#'
#' @param data the data frame, in long format (one row per participant and
#'   condition)
#' @param x the independent variable, most likely "ConditionID"
#' @param y the dependent variable under investigation
#' @param ylab label to be shown for the dependent variable
#' @param xlabels labels to be used for the x-axis
#' @param showPairwiseComp whether to show the significant pairwise comparisons
#'   (\code{TRUE}, default) or none (\code{FALSE}). With \code{FALSE} no
#'   pairwise table is computed either, so [reportggstatsplotPostHoc()] has
#'   nothing to report from the plot.
#' @param plotType either "box", "violin", or "boxviolin" (default)
#' @param subject the participant-ID column, as a string (e.g.
#'   \code{"participant"}). Required. It is the last argument so that existing
#'   positional calls keep their meaning.
#'
#' @return A \code{ggplot} object produced by \code{ggstatsplot::ggwithinstats} with additional significance annotations, which can be printed or modified.
#' @export
#'
#' @examples \donttest{
#'
#' set.seed(123)
#'
#' # Toy within-subject data: every participant sees every condition
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
#'   showPairwiseComp = TRUE,
#'   subject = "Participant"
#' )
#' }
ggwithinstatsWithPriorNormalityCheck <- function(data, x, y, ylab, xlabels = NULL, showPairwiseComp = TRUE, plotType = "boxviolin", subject) {
  not_empty(data)
  not_empty(x)
  not_empty(y)
  not_empty(ylab)
  if (missing(subject)) subject <- NULL
  .require_subject(subject)
  .check_columns(data, c(x, y, subject))
  pairwise_display <- .pairwise_display(showPairwiseComp)
  .plot_type_args(plotType) # validated before the tests run

  data <- .prepare_within_data(data, x, y, subject)$data
  .check_xlabels(data, x, xlabels)

  # Normality of what the paired test assumes to be normal: the differences
  # (two conditions) or the residuals of y ~ x + subject (more). No Levene
  # check: a repeated-measures design has no use for it.
  type <- .normality_type(check_normality_by_group(data, x, y, subject = subject))

  frame <- .ggstats_frame(data, c(x = x, y = y, subject = subject))
  plot <- .ggstats_plot("within", frame, type, ylab, pairwise_display, plotType)

  # Only apply custom xlabels if they are provided
  if (!is.null(xlabels) && length(xlabels) > 0) {
    plot <- plot + ggplot2::scale_x_discrete(labels = xlabels)
  }

  plot
}


#' Check the data's distribution. If non-normal, take the non-parametric variant of *ggbetweenstats*.
#' x and y have to be in parentheses, e.g., "ConditionID".
#'
#' For independent groups: one row per participant. If the group-wise
#' normality check ([check_normality_by_group()]) passes, ggstatsplot runs
#' Welch's t-test (two groups) or Welch's one-way ANOVA with Games-Howell
#' post-hoc tests and labels the means; none of these assume equal variances,
#' which is why no Levene test is run. Otherwise it runs a Wilcoxon rank-sum
#' (Mann-Whitney) or Kruskal-Wallis test with Dunn post-hoc tests and labels
#' the medians. Post-hoc p-values are Holm-adjusted. Rows without a group or an
#' outcome are dropped, and the grouping column is treated as a factor, so
#' numeric condition codes are categories.
#'
#' @param data the data frame
#' @param x the independent variable, most likely "ConditionID"
#' @param y the dependent variable under investigation
#' @param ylab label to be shown for the dependent variable
#' @param xlabels labels to be used for the x-axis
#' @param showPairwiseComp whether to show the significant pairwise comparisons
#'   (\code{TRUE}, default) or none (\code{FALSE}). With \code{FALSE} no
#'   pairwise table is computed either, so [reportggstatsplotPostHoc()] has
#'   nothing to report from the plot.
#' @param plotType either "box", "violin", or "boxviolin" (default)
#'
#' @return A \code{ggplot} object produced by \code{ggstatsplot::ggbetweenstats}, which can be printed or further modified with \code{+}.
#' @export
#'
#' @examples \donttest{
#'
#' set.seed(123)
#'
#' # Toy between-subject data: each participant sees one condition
#' main_df <- data.frame(
#'   CondID      = factor(rep(c("A", "B", "C"), each = 20)),
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
  pairwise_display <- .pairwise_display(showPairwiseComp)
  .plot_type_args(plotType) # validated before the tests run

  data <- .prepare_between_data(data, x, y)
  .check_xlabels(data, x, xlabels)

  type <- .normality_type(check_normality_by_group(data, x, y))

  # No Levene test: ggstatsplot >= 1.0.0 no longer takes `var.equal` and always
  # uses the Welch statistics and Games-Howell post-hocs, so its result could
  # not change the analysis (it used to be passed, and silently ignored).
  frame <- .ggstats_frame(data, c(x = x, y = y))
  plot <- .ggstats_plot("between", frame, type, ylab, pairwise_display, plotType)

  if (!is.null(xlabels) && length(xlabels) > 0) {
    plot <- plot + ggplot2::scale_x_discrete(labels = xlabels)
  }

  plot
}


#' Check the data's distribution. If non-normal, take the non-parametric variant of *ggbetweenstats*.
#' x and y have to be in parentheses, e.g., "ConditionID".
#'
#' As [ggbetweenstatsWithPriorNormalityCheck()], but the significant
#' comparisons are drawn as asterisk brackets (*** p < .001, ** p < .01,
#' * p < .05) instead of p-values. The brackets come from the same test as the
#' figure: with two groups, the omnibus test in the subtitle (ggstatsplot runs
#' no post-hoc test then, and a second test of the same pair could disagree
#' with it); with more, the Holm-adjusted Games-Howell (parametric) or Dunn
#' (non-parametric) tests ggstatsplot itself would compute.
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
#' # Toy between-subject data: each participant sees one condition
#' main_df <- data.frame(
#'   CondID      = factor(rep(c("A", "B", "C"), each = 20)),
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
  .plot_type_args(plotType) # validated before the tests run

  data <- .prepare_between_data(data, x, y)
  .check_xlabels(data, x, xlabels)

  type <- .normality_type(check_normality_by_group(data, x, y))

  # No Levene test (see ggbetweenstatsWithPriorNormalityCheck()).
  frame <- .ggstats_frame(data, c(x = x, y = y))
  p <- .ggstats_plot("between", frame, type, ylab, "none", plotType) +
    ggplot2::scale_x_discrete(labels = xlabels)

  df <- .asterisk_comparisons(p, frame, type, paired = FALSE)
  .add_asterisk_brackets(p, df, data[[y]])
}

#' Check the data's distribution. If non-normal, take the non-parametric variant of *ggwithinstats*.
#' x and y have to be in parentheses, e.g., "ConditionID". Add Asterisks instead of p-values.
#'
#' As [ggwithinstatsWithPriorNormalityCheck()] -- including pairing by
#' `subject` and dropping participants who lack a condition -- but the
#' significant comparisons are drawn as asterisk brackets (*** p < .001,
#' ** p < .01, * p < .05) instead of p-values. The brackets come from the same
#' test as the figure: with two conditions, the omnibus paired test in the
#' subtitle; with more, the Holm-adjusted paired Student's t (parametric) or
#' Durbin-Conover (non-parametric) tests ggstatsplot itself would compute,
#' paired by participant.
#'
#' @param data the data frame, in long format (one row per participant and
#'   condition)
#' @param x the independent variable, most likely "ConditionID"
#' @param y the dependent variable under investigation
#' @param ylab label to be shown for the dependent variable
#' @param xlabels labels to be used for the x-axis
#' @param plotType either "box", "violin", or "boxviolin" (default)
#' @param subject the participant-ID column, as a string (e.g.
#'   \code{"participant"}). Required. It is the last argument so that existing
#'   positional calls keep their meaning.
#'
#' @return A \code{ggplot} object produced by \code{ggstatsplot::ggwithinstats}
#'   with additional significance annotations, which can be printed or modified.
#' @export
#'
#' @examples \donttest{
#'
#' set.seed(123)
#'
#' # Toy within-subject data: every participant sees every condition
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
#'   ylab = "Mental Demand", xlabels = labels_xlab,
#'   subject = "Participant"
#' )
#' }
ggwithinstatsWithPriorNormalityCheckAsterisk <- function(data, x, y, ylab, xlabels, plotType = "boxviolin", subject) {
  not_empty(data)
  not_empty(x)
  not_empty(y)
  not_empty(ylab)
  not_empty(xlabels)
  if (missing(subject)) subject <- NULL
  .require_subject(subject)
  .check_columns(data, c(x, y, subject))
  .plot_type_args(plotType) # validated before the tests run

  data <- .prepare_within_data(data, x, y, subject)$data
  .check_xlabels(data, x, xlabels)

  type <- .normality_type(check_normality_by_group(data, x, y, subject = subject))

  frame <- .ggstats_frame(data, c(x = x, y = y, subject = subject))
  p <- .ggstats_plot("within", frame, type, ylab, "none", plotType) +
    ggplot2::scale_x_discrete(labels = xlabels)

  df <- .asterisk_comparisons(p, frame, type, paired = TRUE)
  .add_asterisk_brackets(p, df, data[[y]])
}
