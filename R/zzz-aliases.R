# snake_case names with report_*/plot_*/check_* prefixes, which are the
# canonical spellings: they are what the documentation uses and what to reach
# for in new code, because the prefixes make the API discoverable through
# autocomplete. The original camelCase names are superseded but remain fully
# supported and are not scheduled for removal -- both names point at the same
# function object, so nothing is lost by keeping them.
#
# The canonical function definitions still live in the files named after the
# original spellings; only the naming guidance is stated here, through the
# shared man-roxygen/naming.R template. This file is named zzz-aliases.R so it
# is collated after the files that define those functions.

#' @rdname reportART
#' @templateVar canonical report_art
#' @templateVar superseded reportART
#' @template naming
#' @export
report_art <- reportART

#' @rdname reportNparLD
#' @templateVar canonical report_nparld
#' @templateVar superseded reportNparLD
#' @template naming
#' @export
report_nparld <- reportNparLD

#' @rdname reportMeanAndSD
#' @templateVar canonical report_mean_sd
#' @templateVar superseded reportMeanAndSD
#' @template naming
#' @export
report_mean_sd <- reportMeanAndSD

#' @rdname reportggstatsplot
#' @templateVar canonical report_ggstatsplot
#' @templateVar superseded reportggstatsplot
#' @template naming
#' @export
report_ggstatsplot <- reportggstatsplot

#' @rdname reportggstatsplotPostHoc
#' @templateVar canonical report_ggstatsplot_posthoc
#' @templateVar superseded reportggstatsplotPostHoc
#' @template naming
#' @export
report_ggstatsplot_posthoc <- reportggstatsplotPostHoc

#' @rdname reportDunnTest
#' @templateVar canonical report_dunn_test
#' @templateVar superseded reportDunnTest
#' @template naming
#' @export
report_dunn_test <- reportDunnTest

#' @rdname reportDunnTestTable
#' @templateVar canonical report_dunn_test_table
#' @templateVar superseded reportDunnTestTable
#' @template naming
#' @export
report_dunn_test_table <- reportDunnTestTable

#' @rdname reportArtCon
#' @templateVar canonical report_art_con
#' @templateVar superseded reportArtCon
#' @template naming
#' @export
report_art_con <- reportArtCon

#' @rdname reportArtConTable
#' @templateVar canonical report_art_con_table
#' @templateVar superseded reportArtConTable
#' @template naming
#' @export
report_art_con_table <- reportArtConTable

#' @rdname checkAssumptionsForAnova
#' @templateVar canonical check_assumptions_anova
#' @templateVar superseded checkAssumptionsForAnova
#' @template naming
#' @export
check_assumptions_anova <- checkAssumptionsForAnova

#' @rdname reportGLMM
#' @templateVar canonical report_glmm
#' @templateVar superseded reportGLMM
#' @template naming
#' @export
report_glmm <- reportGLMM

#' @rdname reportCLMM
#' @templateVar canonical report_clmm
#' @templateVar superseded reportCLMM
#' @template naming
#' @export
report_clmm <- reportCLMM

#' @rdname recommend_test
#'
#' @section Naming:
#' `recommend_test()` is the canonical name. `recommend_analysis()` is an alias
#' for the same function object, kept for backward compatibility.
#' @export
recommend_analysis <- recommend_test

#' @rdname generateEffectPlot
#' @templateVar canonical plot_effect
#' @templateVar superseded generateEffectPlot
#' @template naming
#' @export
plot_effect <- generateEffectPlot

#' @rdname generateMoboPlot
#' @templateVar canonical plot_mobo
#' @templateVar superseded generateMoboPlot
#' @template naming
#' @export
plot_mobo <- generateMoboPlot

#' @rdname generateMoboPlot2
#' @templateVar canonical plot_mobo2
#' @templateVar superseded generateMoboPlot2
#' @template naming
#' @export
plot_mobo2 <- generateMoboPlot2

#' @rdname ggwithinstatsWithPriorNormalityCheck
#' @templateVar canonical plot_within_stats
#' @templateVar superseded ggwithinstatsWithPriorNormalityCheck
#' @template naming
#' @export
plot_within_stats <- ggwithinstatsWithPriorNormalityCheck

#' @rdname ggbetweenstatsWithPriorNormalityCheck
#' @templateVar canonical plot_between_stats
#' @templateVar superseded ggbetweenstatsWithPriorNormalityCheck
#' @template naming
#' @export
plot_between_stats <- ggbetweenstatsWithPriorNormalityCheck

#' @rdname ggbetweenstatsWithPriorNormalityCheckAsterisk
#' @templateVar canonical plot_between_stats_asterisk
#' @templateVar superseded ggbetweenstatsWithPriorNormalityCheckAsterisk
#' @template naming
#' @export
plot_between_stats_asterisk <- ggbetweenstatsWithPriorNormalityCheckAsterisk

#' @rdname ggwithinstatsWithPriorNormalityCheckAsterisk
#' @templateVar canonical plot_within_stats_asterisk
#' @templateVar superseded ggwithinstatsWithPriorNormalityCheckAsterisk
#' @template naming
#' @export
plot_within_stats_asterisk <- ggwithinstatsWithPriorNormalityCheckAsterisk
