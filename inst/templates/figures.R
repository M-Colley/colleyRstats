# Figures.
#
# save_paper_figure() sizes a figure's type to the column width it will be
# printed at, so a single-column figure is legible at 100% instead of only when
# zoomed -- the most common reason a reviewer calls a figure unreadable.

# One figure for one outcome, following the design declared in analysis.R.
# plot_within_stats() / plot_between_stats() pick the parametric or
# non-parametric test from a prior normality check and annotate the figure with
# the one they used, so the figure and the reported test cannot disagree.
#
# A condition that varies within participants (CLUSTER) is plotted as a
# within-subjects comparison: `subject` pairs each participant's observations
# across conditions, which a paired test needs. Otherwise the conditions are
# independent groups. Either way a participant's repeated trials are averaged
# first: the paired plot needs one value per participant and condition, and in
# the between-subjects plot repeated rows of one person are not independent
# observations. With CLUSTER <- NULL every row is taken as its own participant.
plot_outcome <- function(data, dv, x = PREDICTORS[[1]], cluster = CLUSTER) {
  if (is.null(cluster)) {
    return(plot_between_stats(data = data, x = x, y = dv, ylab = dv))
  }
  cells <- stats::aggregate(
    data[dv], by = data[c(cluster, x)],
    FUN = function(v) if (all(is.na(v))) NA_real_ else mean(v, na.rm = TRUE)
  )
  within <- any(tapply(as.character(cells[[x]]), cells[[cluster]],
                       function(v) length(unique(v)) > 1L))
  if (within) {
    plot_within_stats(data = cells, x = x, y = dv, ylab = dv, subject = cluster)
  } else {
    plot_between_stats(data = cells, x = x, y = dv, ylab = dv)
  }
}

make_figures <- function(data, dir = "output/figures") {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  outcomes <- intersect(OUTCOMES, names(data))
  paths <- character(0)

  for (dv in outcomes) {
    path <- file.path(dir, paste0(gsub("[^A-Za-z0-9]+", "-", dv), ".pdf"))
    save_paper_figure(plot_outcome(data, dv), path, columns = 1)
    paths <- c(paths, path)
  }

  # One combined figure for the scored scales, which is usually what a
  # two-column paper has room for. Three panels per row, and the height grows
  # with the rows, so a long questionnaire battery still gets legible panels
  # instead of a page too small to draw on.
  if (requireNamespace("patchwork", quietly = TRUE) && length(outcomes) > 1) {
    combined <- patchwork::wrap_plots(lapply(outcomes, function(dv) plot_outcome(data, dv)), ncol = 3)
    path <- file.path(dir, "all-scales.pdf")
    save_paper_figure(combined, path, columns = 2,
                      height = max(3, 2.6 * ceiling(length(outcomes) / 3)))
    paths <- c(paths, path)
  }

  paths
}
