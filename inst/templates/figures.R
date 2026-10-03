# Figures.
#
# save_paper_figure() sizes a figure's type to the column width it will be
# printed at, so a single-column figure is legible at 100% instead of only when
# zoomed -- the most common reason a reviewer calls a figure unreadable.

make_figures <- function(data, dir = "output/figures") {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  outcomes <- intersect(OUTCOMES, names(data))
  paths <- character(0)

  for (dv in outcomes) {
    # plot_within_stats() picks the parametric or non-parametric test from a
    # prior normality check and annotates the figure with the one it used, so
    # the figure and the reported test cannot disagree. `subject` names the
    # participant column (CLUSTER, in analysis.R), which pairs each person's
    # observations across conditions -- a within-subjects test needs it.
    p <- plot_within_stats(
      data = data,
      x = PREDICTORS[[1]],
      y = dv,
      ylab = dv,
      subject = CLUSTER
    )

    path <- file.path(dir, paste0(gsub("[^A-Za-z0-9]+", "-", dv), ".pdf"))
    save_paper_figure(p, path, columns = 1)
    paths <- c(paths, path)
  }

  # One combined figure for the scored scales, which is usually what a
  # two-column paper has room for.
  if (requireNamespace("patchwork", quietly = TRUE) && length(outcomes) > 1) {
    combined <- patchwork::wrap_plots(lapply(outcomes, function(dv) {
      plot_within_stats(data = data, x = PREDICTORS[[1]], y = dv, ylab = dv, subject = CLUSTER)
    }))
    path <- file.path(dir, "all-scales.pdf")
    save_paper_figure(combined, path, columns = 2, height = 6)
    paths <- c(paths, path)
  }

  paths
}
