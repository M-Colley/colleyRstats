# Consistent snake_case aliases with report_*/plot_*/check_* prefixes, so the
# API is discoverable through autocomplete. The original camelCase names remain
# fully supported; both names point to the same function object.
#
# This file is named zzz-aliases.R so it is collated after the files that
# define the canonical functions.

#' @rdname reportART
#' @export
report_art <- reportART

#' @rdname reportNparLD
#' @export
report_nparld <- reportNparLD

#' @rdname reportMeanAndSD
#' @export
report_mean_sd <- reportMeanAndSD

#' @rdname reportggstatsplot
#' @export
report_ggstatsplot <- reportggstatsplot

#' @rdname reportggstatsplotPostHoc
#' @export
report_ggstatsplot_posthoc <- reportggstatsplotPostHoc

#' @rdname reportDunnTest
#' @export
report_dunn_test <- reportDunnTest

#' @rdname reportDunnTestTable
#' @export
report_dunn_test_table <- reportDunnTestTable

#' @rdname reportArtCon
#' @export
report_art_con <- reportArtCon

#' @rdname reportArtConTable
#' @export
report_art_con_table <- reportArtConTable

#' @rdname checkAssumptionsForAnova
#' @export
check_assumptions_anova <- checkAssumptionsForAnova

#' @rdname generateEffectPlot
#' @export
plot_effect <- generateEffectPlot

#' @rdname generateMoboPlot
#' @export
plot_mobo <- generateMoboPlot

#' @rdname generateMoboPlot2
#' @export
plot_mobo2 <- generateMoboPlot2

#' @rdname ggwithinstatsWithPriorNormalityCheck
#' @export
plot_within_stats <- ggwithinstatsWithPriorNormalityCheck

#' @rdname ggbetweenstatsWithPriorNormalityCheck
#' @export
plot_between_stats <- ggbetweenstatsWithPriorNormalityCheck

#' @rdname ggbetweenstatsWithPriorNormalityCheckAsterisk
#' @export
plot_between_stats_asterisk <- ggbetweenstatsWithPriorNormalityCheckAsterisk

#' @rdname ggwithinstatsWithPriorNormalityCheckAsterisk
#' @export
plot_within_stats_asterisk <- ggwithinstatsWithPriorNormalityCheckAsterisk
