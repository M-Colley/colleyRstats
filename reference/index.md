# Package index

## Session setup

Configure a session once, at the top of a script. See
[`vignette("getting-started")`](https://m-colley.github.io/colleyRstats/articles/getting-started.md)
for where the call belongs.

- [`colleyRstats_setup()`](https://m-colley.github.io/colleyRstats/reference/colleyRstats_setup.md)
  : Configure Global R Environment for colleyRstats
- [`colley_theme()`](https://m-colley.github.io/colleyRstats/reference/colley_theme.md)
  : The colleyRstats ggplot2 theme

## One-call pipelines

Go from a data frame to a figure and manuscript-ready sentences in a
single call, for one dependent variable or many.

- [`analyze_and_report()`](https://m-colley.github.io/colleyRstats/reference/analyze_and_report.md)
  : Analyze one dependent variable and produce everything a paper needs
- [`report_all()`](https://m-colley.github.io/colleyRstats/reference/report_all.md)
  : Analyze and report several dependent variables at once
- [`emit_overleaf()`](https://m-colley.github.io/colleyRstats/reference/emit_overleaf.md)
  : Bundle an analysis into an Overleaf-ready folder

## Choosing a test

Inspect the data and get the matching model, with a fit call and a
methods sentence you can edit.

- [`recommend_test()`](https://m-colley.github.io/colleyRstats/reference/recommend_test.md)
  [`recommend_analysis()`](https://m-colley.github.io/colleyRstats/reference/recommend_test.md)
  : Recommend a principled analysis for one outcome
- [`classify_outcome()`](https://m-colley.github.io/colleyRstats/reference/classify_outcome.md)
  : Classify the measurement scale of an outcome variable
- [`assumption_methods_text()`](https://m-colley.github.io/colleyRstats/reference/assumption_methods_text.md)
  : Methods-section sentence justifying the test selection
- [`cite_methods()`](https://m-colley.github.io/colleyRstats/reference/cite_methods.md)
  : Citations and methods boilerplate for the analyses used

## Checking assumptions

- [`checkAssumptionsForAnova()`](https://m-colley.github.io/colleyRstats/reference/checkAssumptionsForAnova.md)
  [`check_assumptions_anova()`](https://m-colley.github.io/colleyRstats/reference/checkAssumptionsForAnova.md)
  : Check the assumptions for an ANOVA with a variable number of
  factors: Normality and Homogeneity of variance assumption.
- [`check_normality_by_group()`](https://m-colley.github.io/colleyRstats/reference/check_normality_by_group.md)
  : Check normality for groups
- [`check_homogeneity_by_group()`](https://m-colley.github.io/colleyRstats/reference/check_homogeneity_by_group.md)
  : Check homogeneity of variances across groups
- [`debug_contr_error()`](https://m-colley.github.io/colleyRstats/reference/debug_contr_error.md)
  : Debug contrast errors in ANOVA-like models

## Plots

`ggstatsplot` wrappers that pick the parametric or non-parametric test
for you, effect plots, and multi-objective optimisation plots.

- [`ggbetweenstatsWithPriorNormalityCheck()`](https://m-colley.github.io/colleyRstats/reference/ggbetweenstatsWithPriorNormalityCheck.md)
  [`plot_between_stats()`](https://m-colley.github.io/colleyRstats/reference/ggbetweenstatsWithPriorNormalityCheck.md)
  :

  Check the data's distribution. If non-normal, take the non-parametric
  variant of *ggbetweenstats*. x and y have to be in parentheses, e.g.,
  "ConditionID".

- [`ggbetweenstatsWithPriorNormalityCheckAsterisk()`](https://m-colley.github.io/colleyRstats/reference/ggbetweenstatsWithPriorNormalityCheckAsterisk.md)
  [`plot_between_stats_asterisk()`](https://m-colley.github.io/colleyRstats/reference/ggbetweenstatsWithPriorNormalityCheckAsterisk.md)
  :

  Check the data's distribution. If non-normal, take the non-parametric
  variant of *ggbetweenstats*. x and y have to be in parentheses, e.g.,
  "ConditionID".

- [`ggwithinstatsWithPriorNormalityCheck()`](https://m-colley.github.io/colleyRstats/reference/ggwithinstatsWithPriorNormalityCheck.md)
  [`plot_within_stats()`](https://m-colley.github.io/colleyRstats/reference/ggwithinstatsWithPriorNormalityCheck.md)
  :

  Check the data's distribution. If non-normal, take the non-parametric
  variant of *ggwithinstats*. x and y have to be in parentheses, e.g.,
  "ConditionID".

- [`ggwithinstatsWithPriorNormalityCheckAsterisk()`](https://m-colley.github.io/colleyRstats/reference/ggwithinstatsWithPriorNormalityCheckAsterisk.md)
  [`plot_within_stats_asterisk()`](https://m-colley.github.io/colleyRstats/reference/ggwithinstatsWithPriorNormalityCheckAsterisk.md)
  :

  Check the data's distribution. If non-normal, take the non-parametric
  variant of *ggwithinstats*. x and y have to be in parentheses, e.g.,
  "ConditionID". Add Asterisks instead of p-values.

- [`generateEffectPlot()`](https://m-colley.github.io/colleyRstats/reference/generateEffectPlot.md)
  [`plot_effect()`](https://m-colley.github.io/colleyRstats/reference/generateEffectPlot.md)
  : Function to define a plot, either showing the main or interaction
  effect in bold.

- [`generateMoboPlot()`](https://m-colley.github.io/colleyRstats/reference/generateMoboPlot.md)
  [`plot_mobo()`](https://m-colley.github.io/colleyRstats/reference/generateMoboPlot.md)
  : Generate a Multi-objective Optimization Plot

- [`generateMoboPlot2()`](https://m-colley.github.io/colleyRstats/reference/generateMoboPlot2.md)
  [`plot_mobo2()`](https://m-colley.github.io/colleyRstats/reference/generateMoboPlot2.md)
  : Generate a Multi-objective Optimization Plot

- [`animate_mobo2()`](https://m-colley.github.io/colleyRstats/reference/animate_mobo2.md)
  : Animate a Multi-objective Optimization Plot

- [`stat_sum_df()`](https://m-colley.github.io/colleyRstats/reference/stat_sum_df.md)
  : Generating the sum and adding a crossbar.

- [`n_fun()`](https://m-colley.github.io/colleyRstats/reference/n_fun.md)
  : Build a median/size label for plot annotations

## Saving figures

Publication presets that size a figure’s type to the width it is written
at.

- [`save_paper_figure()`](https://m-colley.github.io/colleyRstats/reference/save_paper_figure.md)
  : Save a plot with publication-ready defaults
- [`figure_base_size()`](https://m-colley.github.io/colleyRstats/reference/figure_base_size.md)
  : Base font size for a figure of a given width

## Reporting results

APA-compliant, LaTeX-ready sentences and tables for each model family.

- [`reportART()`](https://m-colley.github.io/colleyRstats/reference/reportART.md)
  [`report_art()`](https://m-colley.github.io/colleyRstats/reference/reportART.md)
  :

  Generate the Latex-text based on the ARTool (see
  <https://github.com/mjskay/ARTool>). The ART result must be piped into
  an anova(). Only significant main and interaction effects are
  reported. P-values are rounded for the third digit. Attention: Effect
  sizes are not calculated! Attention: the independent variables of the
  formula and the term specifying the participant must be factors (i.e.,
  use as.factor()).

- [`reportArtCon()`](https://m-colley.github.io/colleyRstats/reference/reportArtCon.md)
  [`report_art_con()`](https://m-colley.github.io/colleyRstats/reference/reportArtCon.md)
  : Report significant ART contrasts (art.con) as LaTeX text

- [`reportArtConTable()`](https://m-colley.github.io/colleyRstats/reference/reportArtConTable.md)
  [`report_art_con_table()`](https://m-colley.github.io/colleyRstats/reference/reportArtConTable.md)
  :

  Report ART contrasts (art.con) as a LaTeX table. Customizable with
  sensible defaults. Companion to
  [`reportDunnTestTable()`](https://m-colley.github.io/colleyRstats/reference/reportDunnTestTable.md).

- [`reportCLMM()`](https://m-colley.github.io/colleyRstats/reference/reportCLMM.md)
  [`report_clmm()`](https://m-colley.github.io/colleyRstats/reference/reportCLMM.md)
  : Report a cumulative link (mixed) model in LaTeX/APA style

- [`reportGLMM()`](https://m-colley.github.io/colleyRstats/reference/reportGLMM.md)
  [`report_glmm()`](https://m-colley.github.io/colleyRstats/reference/reportGLMM.md)
  : Report a (generalized) linear mixed model in LaTeX/APA style

- [`reportDunnTest()`](https://m-colley.github.io/colleyRstats/reference/reportDunnTest.md)
  [`report_dunn_test()`](https://m-colley.github.io/colleyRstats/reference/reportDunnTest.md)
  :

  Report dunnTest as text. Required commands in LaTeX:
  `\newcommand{\padjminor}{\textit{p$_{adj}<$}}`
  `\newcommand{\padj}{\textit{p$_{adj}$=}}`
  `\newcommand{\rankbiserial}[1]{$r_{rb} = #1$}`

- [`reportDunnTestTable()`](https://m-colley.github.io/colleyRstats/reference/reportDunnTestTable.md)
  [`report_dunn_test_table()`](https://m-colley.github.io/colleyRstats/reference/reportDunnTestTable.md)
  :

  report Dunn test as a table. Customizable with sensible defaults.
  Required commands in LaTeX:
  `\newcommand{\padjminor}{\textit{p$_{adj}<$}}`
  `\newcommand{\padj}{\textit{p$_{adj}$=}}`
  `\newcommand{\rankbiserial}[1]{$r_{rb} = #1$}`

- [`reportggstatsplot()`](https://m-colley.github.io/colleyRstats/reference/reportggstatsplot.md)
  [`report_ggstatsplot()`](https://m-colley.github.io/colleyRstats/reference/reportggstatsplot.md)
  : Report statistical details for ggstatsplot.

- [`reportggstatsplotPostHoc()`](https://m-colley.github.io/colleyRstats/reference/reportggstatsplotPostHoc.md)
  [`report_ggstatsplot_posthoc()`](https://m-colley.github.io/colleyRstats/reference/reportggstatsplotPostHoc.md)
  : Report significant post-hoc pairwise comparisons

- [`reportMeanAndSD()`](https://m-colley.github.io/colleyRstats/reference/reportMeanAndSD.md)
  [`report_mean_sd()`](https://m-colley.github.io/colleyRstats/reference/reportMeanAndSD.md)
  : Report the mean and standard deviation of a dependent variable for
  all levels of an independent variable rounded to the 2nd digit.

- [`reportNparLD()`](https://m-colley.github.io/colleyRstats/reference/reportNparLD.md)
  [`report_nparld()`](https://m-colley.github.io/colleyRstats/reference/reportNparLD.md)
  :

  Report the model produced by nparLD. The model provided must be the
  model generated by the command 'nparLD'
  [`nparLD`](https://rdrr.io/pkg/nparLD/man/nparLD.html) (see
  <https://CRAN.R-project.org/package=nparLD>).

- [`reportNPAV()`](https://m-colley.github.io/colleyRstats/reference/reportNPAV.md)
  :

  Generate the Latex-text based on the NPAV by Lüpsen (see
  <https://www.uni-koeln.de/~luepsen/R/>). Only significant main and
  interaction effects are reported. P-values are rounded for the third
  digit and partial eta squared values are provided when possible.
  Attention: the independent variables of the formula and the term
  specifying the participant must be factors (i.e., use as.factor()).

## Effect sizes

- [`rFromWilcox()`](https://m-colley.github.io/colleyRstats/reference/rFromWilcox.md)
  :

  Calculation based on Rosenthal's formula (1994). N stands for the
  *number of measurements*.

- [`rFromWilcoxAdjusted()`](https://m-colley.github.io/colleyRstats/reference/rFromWilcoxAdjusted.md)
  : rFromWilcoxAdjusted

- [`rFromNPAV()`](https://m-colley.github.io/colleyRstats/reference/rFromNPAV.md)
  :

  Calculation based on Rosenthal's formula (1994). N stands for the
  *number of measurements*.

## LaTeX and Overleaf output

Getting the generated text into a document that compiles immediately.

- [`latex_preamble()`](https://m-colley.github.io/colleyRstats/reference/latex_preamble.md)
  : LaTeX preamble required by the report functions

- [`latex_escape()`](https://m-colley.github.io/colleyRstats/reference/latex_escape.md)
  : Escape LaTeX special characters in plain text

- [`latexify_report()`](https://m-colley.github.io/colleyRstats/reference/latexify_report.md)
  :

  Transform text from
  [`report::report()`](https://easystats.github.io/report/reference/report.html)
  into LaTeX-friendly output.

- [`expand_latex_macros()`](https://m-colley.github.io/colleyRstats/reference/expand_latex_macros.md)
  : Expand the colleyRstats LaTeX macros to plain standard LaTeX

- [`define_result_macro()`](https://m-colley.github.io/colleyRstats/reference/define_result_macro.md)
  : Define a named LaTeX macro for a single result (single source of
  truth)

- [`emit_name_macros()`](https://m-colley.github.io/colleyRstats/reference/emit_name_macros.md)
  : Generate \newcommand stubs for variable/factor names

- [`use_colleyrstats_sty()`](https://m-colley.github.io/colleyRstats/reference/use_colleyrstats_sty.md)
  : Write colleyRstats.sty into a project (for Overleaf)

## Data preparation

- [`reshape_data()`](https://m-colley.github.io/colleyRstats/reference/reshape_data.md)
  : Reshape Excel Data Based on Custom Markers and Include Custom ID
  Column

- [`replace_values()`](https://m-colley.github.io/colleyRstats/reference/replace_values.md)
  : Replace values across a data frame

- [`remove_outliers_REI()`](https://m-colley.github.io/colleyRstats/reference/remove_outliers_REI.md)
  : Flag suspicious survey responses via the Response Entropy Index
  (REI)

- [`normalize()`](https://m-colley.github.io/colleyRstats/reference/normalize.md)
  : This function normalizes the values in a vector to the range
  \[new_min, new_max\] based on their original range \[old_min,
  old_max\].

- [`na.zero()`](https://m-colley.github.io/colleyRstats/reference/na.zero.md)
  : Replace NA values with zero

- [`add_pareto_emoa_column()`](https://m-colley.github.io/colleyRstats/reference/add_pareto_emoa_column.md)
  :

  Add `PARETO_EMOA` Column to a Data Frame

- [`add_pareto_moocore_column()`](https://m-colley.github.io/colleyRstats/reference/add_pareto_moocore_column.md)
  :

  Add `PARETO_MOOCORE` Column to a Data Frame

## Small utilities

- [`not_in()`](https://m-colley.github.io/colleyRstats/reference/not_in.md)
  [`` `%!in%` ``](https://m-colley.github.io/colleyRstats/reference/not_in.md)
  :

  Negate `%in%` membership

- [`not_empty()`](https://m-colley.github.io/colleyRstats/reference/not_empty.md)
  : Ensure input is not empty

- [`pathPrep()`](https://m-colley.github.io/colleyRstats/reference/pathPrep.md)
  : Convert Windows paths to R-friendly format
