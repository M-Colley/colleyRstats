# Figures.
#
# save_paper_figure() sizes a figure's type to the column width it will be
# printed at, so a single-column figure is legible at 100% instead of only when
# zoomed -- the most common reason a reviewer calls a figure unreadable.

# One descriptive figure for each fitted outcome. plot_fit() takes the analyzed
# rows and test statistics from that exact model, including its exclusions and
# random effects. It runs no new model or significance test on the plotted data.
plot_outcome <- function(results, dv, x = PREDICTORS[[1]]) {
  plot_fit(results$fits[[dv]], x = x, ylab = dv)
}

# Build once. The pipeline stores these objects for both the saved figures and
# the Quarto report, so a combined figure does not repeat every plotting call.
make_plots <- function(results) {
  outcomes <- names(results$fits)
  plots <- lapply(outcomes, function(dv) plot_outcome(results, dv))
  names(plots) <- outcomes
  plots
}

make_figures <- function(plots, dir = "output/figures") {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  outcomes <- names(plots)
  paths <- character(0)

  for (dv in outcomes) {
    path <- file.path(dir, paste0(gsub("[^A-Za-z0-9]+", "-", dv), ".pdf"))
    save_paper_figure(plots[[dv]], path, columns = 1)
    paths <- c(paths, path)
  }

  # One combined figure for the scored scales, which is usually what a
  # two-column paper has room for. Three panels per row, and the height grows
  # with the rows, so a long questionnaire battery still gets legible panels
  # instead of a page too small to draw on.
  if (requireNamespace("patchwork", quietly = TRUE) && length(outcomes) > 1) {
    combined <- patchwork::wrap_plots(plots, ncol = 3)
    path <- file.path(dir, "all-scales.pdf")
    save_paper_figure(combined, path, columns = 2,
                      base_size = figure_base_size(7 / min(3, length(outcomes))),
                      height = max(3, 2.6 * ceiling(length(outcomes) / 3)))
    paths <- c(paths, path)
  }

  paths
}
