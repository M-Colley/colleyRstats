# Changelog

## colleyRstats 0.1.5 (development)

### BUG FIXES

- [`colleyRstats_setup()`](https://m-colley.github.io/colleyRstats/reference/colleyRstats_setup.md)
  made it impossible to attach a meta-package afterwards.
  [`library(colleyRstats)`](https://github.com/M-Colley/colleyRstats),
  [`colleyRstats_setup()`](https://m-colley.github.io/colleyRstats/reference/colleyRstats_setup.md),
  [`library(easystats)`](https://easystats.github.io/easystats/) died on
  the third line with
  `.onAttach failed in attachNamespace() for 'easystats': object 'quietly' not found`,
  which broke every downstream analysis script that opens that way. The
  cause was the `set_conflicts = TRUE` default:
  [`conflicted::conflict_prefer()`](https://conflicted.r-lib.org/reference/conflict_prefer.html)
  does not merely record a preference, it *activates* `conflicted`,
  which attaches a `.conflicts` environment carrying its own
  [`library()`](https://rdrr.io/r/base/library.html) and
  [`require()`](https://rdrr.io/r/base/library.html) shims. Every later
  attach in the session then went through those shims, which forward
  `quietly` and `verbose` into
  [`base::library()`](https://rdrr.io/r/base/library.html) as
  unevaluated symbols; a package whose `.onAttach` inspects the calling
  [`library()`](https://rdrr.io/r/base/library.html) frame –
  meta-packages do this to decide whether to print their banner –
  evaluated those symbols in a frame that does not bind them, and the
  attach failed outright. `set_conflicts` now defaults to `FALSE`, so
  nothing takes over [`library()`](https://rdrr.io/r/base/library.html)
  unless it is asked to. The preference list is unchanged and still
  takes effect when you opt in.

- Preferences that fail to register are no longer discarded silently.
  The [`try()`](https://rdrr.io/r/base/try.html) around the loop existed
  so that one unsettable preference could not abort the rest, but it
  also swallowed the fact that it had failed; with `verbose = TRUE` the
  failures are now named.

- Figures saved at the column presets came out unreadable.
  [`colleyRstats_setup()`](https://m-colley.github.io/colleyRstats/reference/colleyRstats_setup.md)
  set text sizes in **absolute** points (axis text 17 pt, axis titles 20
  pt, plot titles 28 pt, strip text 22 pt) while
  `save_paper_figure(columns = 1)` writes a **3.33 x 2.22 in** PDF.
  Points do not shrink with the canvas, so on a single-column figure the
  type came out about three times what fits: axis titles ran off the
  page entirely, and three-level factor labels such as
  `demonstration`/`language`/`reward` overprinted into an unreadable
  smear. Type size is now derived from the width the figure is actually
  written at.

- [`generateEffectPlot()`](https://m-colley.github.io/colleyRstats/reference/generateEffectPlot.md)
  fixed its legend title at 14 pt, and the four `ggstatsplot` wrappers
  fixed `text` at 16 pt and `plot.subtitle` at 17 pt. These absolute
  values overrode whatever theme the caller had chosen, so they survived
  any attempt to scale a figure down. They are now relative to the
  theme.

- Significance-bracket labels were fixed at 4 mm (about 11 pt).
  `ggsignif` measures text in millimetres while themes measure it in
  points, so the label kept its physical size no matter how small the
  figure was drawn and ended up larger than the axis text beside it.
  Bracket text now follows the active theme; at the historical 17 pt
  base it is still 4 mm, so existing figures do not shift.

### NEW FEATURES

- New `colley_theme(base_size, base_family)`, the package theme as a
  function. Every text element is a multiple of `base_size` rather than
  an absolute point size, so one theme serves a journal column, a
  full-width figure and a slide – only the number changes. The
  multipliers are axis titles 1.15, axis text 1.0, plot title 1.65,
  subtitle 1.0, caption 0.8, legend text 0.9, strip text 1.3.
- New `figure_base_size(width)`, the rule that turns a figure width into
  a type size: 3.33 in gives 7 pt and 7 in gives 9 pt, interpolated
  between and clamped outside. Exported so the choice is inspectable
  rather than buried.
- [`save_paper_figure()`](https://m-colley.github.io/colleyRstats/reference/save_paper_figure.md)
  gains `base_size`. The default `NULL` derives it from the width, which
  is the fix above; pass a number to choose it, or `NA` to leave the
  plot’s own text sizes untouched. The confirmation message now names
  the size used.
- [`colleyRstats_setup()`](https://m-colley.github.io/colleyRstats/reference/colleyRstats_setup.md)
  gains `base_size` (default 17), passed through to
  [`colley_theme()`](https://m-colley.github.io/colleyRstats/reference/colley_theme.md).
- A `pkgdown` site (`_pkgdown.yml` plus a deploy workflow) puts the 56
  help topics into a grouped reference index – session setup, pipelines,
  test selection, assumptions, plots, reporting, effect sizes, LaTeX
  output, data preparation – instead of one alphabetical wall.

### DOCUMENTATION

- The README and
  [`vignette("getting-started")`](https://m-colley.github.io/colleyRstats/articles/getting-started.md)
  now show the session-setup pattern, including where
  [`colleyRstats_setup()`](https://m-colley.github.io/colleyRstats/reference/colleyRstats_setup.md)
  belongs relative to your
  [`library()`](https://rdrr.io/r/base/library.html) calls and what
  happens if it goes first. Neither had covered this, which is how the
  `conflicted` defect above reached three downstream analysis
  repositories.
- The `snake_case` spellings
  ([`report_art()`](https://m-colley.github.io/colleyRstats/reference/reportART.md),
  [`plot_effect()`](https://m-colley.github.io/colleyRstats/reference/generateEffectPlot.md),
  [`check_assumptions_anova()`](https://m-colley.github.io/colleyRstats/reference/checkAssumptionsForAnova.md),
  …) are now stated to be the canonical ones, and the documentation uses
  them throughout: README, vignettes, and the `pkgdown` reference index.
  Every affected help page gained a **Naming** section saying which
  spelling to prefer and that the other is not going away. Previously
  the aliases file described `snake_case` as the discoverable API while
  the README taught `camelCase` exclusively, and nothing told a reader
  which to use.

### BACKWARD COMPATIBILITY

- The `camelCase` function names
  ([`reportART()`](https://m-colley.github.io/colleyRstats/reference/reportART.md),
  [`generateEffectPlot()`](https://m-colley.github.io/colleyRstats/reference/generateEffectPlot.md),
  and the rest) are now marked **superseded**. Nothing changes at
  runtime: they are the same function objects, they emit no warnings,
  and they are not scheduled for removal. Only the documentation’s
  recommendation has changed.
- `colleyRstats_setup(set_options = TRUE)` now emits a deprecation
  warning instead of an easily missed message, and the warning is no
  longer suppressed by `verbose = FALSE`. The argument has had no effect
  since global [`options()`](https://rdrr.io/r/base/options.html)
  handling was removed for CRAN compliance; `set_options = FALSE` is
  unaffected.
- [`colleyRstats_setup()`](https://m-colley.github.io/colleyRstats/reference/colleyRstats_setup.md)
  no longer sets `conflicted` preferences by default. Pass
  `set_conflicts = TRUE` for them, and place that call **after** every
  [`library()`](https://rdrr.io/r/base/library.html) call in the script
  rather than before. That ordering is a requirement – once `conflicted`
  is active, attaching a meta-package fails – and it is also where the
  preferences do most good, since `conflicted` resolves only those names
  that are ambiguous among the packages attached at the time.
- [`colleyRstats_setup()`](https://m-colley.github.io/colleyRstats/reference/colleyRstats_setup.md)
  with no arguments produces the same text sizes as before: the default
  `base_size = 17` reproduces the previous absolute values exactly (17 /
  19.55 / 28.05 / 15.3 / 22.1 pt), and there is a regression test
  pinning them.
- Figures written through
  [`save_paper_figure()`](https://m-colley.github.io/colleyRstats/reference/save_paper_figure.md)
  **do** change, which is the point of the fix – they become legible at
  the size they are placed at. To keep a figure exactly as it was, pass
  `base_size = NA`.
- Because the theme is now built as `see::theme_lucid(base_size = ...)`
  rather than `theme_lucid()` with sizes overridden on top, margins and
  spacing scale with the text instead of staying at the 11 pt defaults.
  This is part of why elements used to collide.

## colleyRstats 0.1.4

CRAN release: 2026-07-25

### BUG FIXES

- [`reportART()`](https://m-colley.github.io/colleyRstats/reference/reportART.md)
  reported no F statistic and no effect size for **mixed** ART models.
  [`stats::anova()`](https://rdrr.io/r/stats/anova.html) names the F
  column `F value` for a between-only (`lm`) fit but plain `F` for a
  mixed (`lmer`) one, and only the former was read – so every model
  containing a random term (`+ (1 | participant)`, i.e. any
  within-subjects design) produced `\F{3}{108}{}` with the statistic
  missing, silently dropped the partial eta-squared, and left the
  opening parenthesis unclosed. The F column is now resolved by
  whichever name it carries.
- [`reportART()`](https://m-colley.github.io/colleyRstats/reference/reportART.md)
  now always closes the statistics parenthesis. It was appended only
  when an effect size could be computed, so sentences without one
  shipped unbalanced parentheses into LaTeX.
- [`reportggstatsplotPostHoc()`](https://m-colley.github.io/colleyRstats/reference/reportggstatsplotPostHoc.md)
  emitted a stray `)` after the p-value:
  `... (\m{3.8}, \sd{1.6}); \padj{0.001}).` The mean/SD parenthetical
  closed too early, leaving the p-value outside the parentheses it
  belongs to and the sentence unbalanced. It now reads
  `... (\m{3.8}, \sd{1.6}; \padj{0.001}).`, matching
  [`reportArtCon()`](https://m-colley.github.io/colleyRstats/reference/reportArtCon.md).
- Degrees of freedom are formatted for display. Greenhouse-Geisser
  corrected, Kenward-Roger and Welch dfs are fractional and were pasted
  at full double precision,
  e.g. `\F{1.80875305770353}{66.9238631350305}{0.11}` and
  `F(2, 180.000000000002)`. Whole dfs stay whole; fractional ones are
  rounded to two decimals.
- [`reportggstatsplot()`](https://m-colley.github.io/colleyRstats/reference/reportggstatsplot.md)
  chooses the indefinite article from the method name, so it reads “An
  ANOVA …” rather than “A ANOVA …”.

### DOCUMENTATION

- Updated the Datanovia ANOVA-assumptions link, which had moved (README
  and the
  [`check_assumptions_anova()`](https://m-colley.github.io/colleyRstats/reference/checkAssumptionsForAnova.md)
  guidance message).

## colleyRstats 0.1.3

CRAN release: 2026-07-16

### NEW FEATURES

- New vignette “Analyzing a typical user study”
  ([`vignette("analyzing-a-user-study")`](https://m-colley.github.io/colleyRstats/articles/analyzing-a-user-study.md)):
  a complete walkthrough from raw within-subjects data to
  manuscript-ready figures and LaTeX text.
- Friendlier errors everywhere a column name is passed: plotting and
  reporting functions now validate
  `x`/`y`/`iv`/`dv`/`factors`/`objectives` up front and report which
  column is missing plus the available columns, instead of failing later
  with a cryptic dplyr/rlang error.
- The plot wrappers warn when `xlabels` does not match the number of
  observed groups (previously the axis labels silently misaligned).
- [`not_empty()`](https://m-colley.github.io/colleyRstats/reference/not_empty.md)
  now names the offending argument in its default error message.
- [`remove_outliers_REI()`](https://m-colley.github.io/colleyRstats/reference/remove_outliers_REI.md)
  accepts `variables` as a character vector (e.g. `c("var1", "var2")`)
  in addition to the comma-separated string.
- [`add_pareto_emoa_column()`](https://m-colley.github.io/colleyRstats/reference/add_pareto_emoa_column.md)
  /
  [`add_pareto_moocore_column()`](https://m-colley.github.io/colleyRstats/reference/add_pareto_moocore_column.md)
  verify that the objective columns exist and are numeric.

### BUG FIXES

- [`?replace_values`](https://m-colley.github.io/colleyRstats/reference/replace_values.md)
  works again: a malformed roxygen `@name` tag had redirected its
  documentation to a stray `data-the-data-frame` help page.
- [`reportArtCon()`](https://m-colley.github.io/colleyRstats/reference/reportArtCon.md)
  now escapes the dependent variable and condition names for LaTeX and
  renders the IV via the same name-macro policy as
  [`reportDunnTest()`](https://m-colley.github.io/colleyRstats/reference/reportDunnTest.md);
  previously names with underscores produced uncompilable LaTeX.
- The
  [`reshape_data()`](https://m-colley.github.io/colleyRstats/reference/reshape_data.md)
  example was not runnable
  ([`requireNamespace()`](https://rdrr.io/r/base/ns-load.html) was
  called with a vector and a misspelled package name).
- [`latex_preamble()`](https://m-colley.github.io/colleyRstats/reference/latex_preamble.md)
  no longer documents its `path` argument twice;
  [`rFromNPAV()`](https://m-colley.github.io/colleyRstats/reference/rFromNPAV.md)’s
  documentation block is no longer split by a stray comment line.
- [`reportNPAV()`](https://m-colley.github.io/colleyRstats/reference/reportNPAV.md)
  no longer refers to the non-existent `reportNPAVChi()` when the input
  lacks a `Pr(>F)` column.
- README: removed the section documenting the non-existent
  `reportNPAVChi()`, refreshed the stale
  [`reportNPAV()`](https://m-colley.github.io/colleyRstats/reference/reportNPAV.md)
  deprecation date, fixed the double
  [`anova()`](https://rdrr.io/r/stats/anova.html) call in the
  [`reportART()`](https://m-colley.github.io/colleyRstats/reference/reportART.md)
  example, and documented the newer API (recommend_test, pipelines,
  Overleaf output) and all vignettes.

### PERFORMANCE

- [`ggwithinstatsWithPriorNormalityCheck()`](https://m-colley.github.io/colleyRstats/reference/ggwithinstatsWithPriorNormalityCheck.md)
  no longer runs an unused Levene test (the asterisk variant was already
  fixed in 0.1.0).

## colleyRstats 0.1.2

CRAN release: 2026-07-06

### NEW FEATURES

- Principled model selection:
  [`classify_outcome()`](https://m-colley.github.io/colleyRstats/reference/classify_outcome.md)
  determines a variable’s measurement scale (continuous, ordinal,
  binary, count, nominal) and
  [`recommend_test()`](https://m-colley.github.io/colleyRstats/reference/recommend_test.md)
  turns scale x clustering x assumption checks into a concrete
  recommendation – including mixed models – with the matching reporter,
  a ready-to-edit fit call, a rationale, and an APA-style methods
  sentence.
- Mixed-model reporters:
  [`reportGLMM()`](https://m-colley.github.io/colleyRstats/reference/reportGLMM.md)
  (lme4 / glmmTMB / lm / glm; odds and incidence-rate ratios are chosen
  automatically from the family) and
  [`reportCLMM()`](https://m-colley.github.io/colleyRstats/reference/reportCLMM.md)
  (ordinal::clmm / clm).
- Overleaf-oriented output layer:
  [`use_colleyrstats_sty()`](https://m-colley.github.io/colleyRstats/reference/use_colleyrstats_sty.md)
  ships the macro package,
  [`emit_name_macros()`](https://m-colley.github.io/colleyRstats/reference/emit_name_macros.md)
  /
  [`define_result_macro()`](https://m-colley.github.io/colleyRstats/reference/define_result_macro.md)
  generate `\newcommand` stubs and single-source-of-truth result macros,
  [`expand_latex_macros()`](https://m-colley.github.io/colleyRstats/reference/expand_latex_macros.md)
  – with `options(colleyRstats.macros = FALSE)` – expands everything to
  plain math, and
  [`emit_overleaf()`](https://m-colley.github.io/colleyRstats/reference/emit_overleaf.md)
  bundles a whole analysis into a compilable Overleaf project.
- [`latex_escape()`](https://m-colley.github.io/colleyRstats/reference/latex_escape.md)
  escapes LaTeX special characters in user-supplied names.
- New vignettes: “Choosing the right test (and mixed models)” and “From
  R to Overleaf: publication-ready output”.

### DEPENDENCIES

- Lowered several minimum version requirements for broader
  compatibility.

## colleyRstats 0.1.1

CRAN release: 2026-06-22

### BUG FIXES

- adjustment of the post-hoc test due to changes in the `ggstatsplot`
  implementation

## colleyRstats 0.1.0

CRAN release: 2026-06-11

### NEW FEATURES

- [`analyze_and_report()`](https://m-colley.github.io/colleyRstats/reference/analyze_and_report.md):
  one-call pipeline per dependent variable – assumption checks with a
  ready-made methods sentence, the matching ggstatsplot figure
  (automatic parametric/non-parametric selection), the omnibus result,
  and post-hoc comparisons.
- [`report_all()`](https://m-colley.github.io/colleyRstats/reference/report_all.md):
  runs
  [`analyze_and_report()`](https://m-colley.github.io/colleyRstats/reference/analyze_and_report.md)
  over many dependent variables (e.g., all questionnaire scales of a
  study), returns a summary table with Holm-adjusted omnibus p-values
  across the DVs, and a combined figure when `patchwork` is installed.
- [`latex_preamble()`](https://m-colley.github.io/colleyRstats/reference/latex_preamble.md):
  prints (or writes to a file) the complete set of LaTeX `\newcommand`
  definitions required by the report functions – no more hunting through
  individual help pages.
- All report functions accept `sink_to` to write their output to a
  `.tex` file, so manuscripts can `\input{}` the results and stay up to
  date when the analysis is re-run. They all also invisibly return their
  text for programmatic use (e.g., inline in Quarto/R Markdown).
- [`save_paper_figure()`](https://m-colley.github.io/colleyRstats/reference/save_paper_figure.md):
  saves plots with publication presets (ACM-style single-column 3.33 in
  / full-width 7 in). PDFs use Cairo for embedded fonts on
  Windows/Linux; on macOS the default pdf device is used because R’s
  cairo there can crash the session (observed as segfaults on GitHub
  Actions macOS runners). A `device` argument allows overriding.
- [`assumption_methods_text()`](https://m-colley.github.io/colleyRstats/reference/assumption_methods_text.md):
  turns the Shapiro-Wilk (and optionally Levene) checks into the
  methods-section justification sentence reviewers expect, including the
  test statistics.
  [`check_normality_by_group()`](https://m-colley.github.io/colleyRstats/reference/check_normality_by_group.md)
  and
  [`check_homogeneity_by_group()`](https://m-colley.github.io/colleyRstats/reference/check_homogeneity_by_group.md)
  now attach their test statistics as attributes.
- [`cite_methods()`](https://m-colley.github.io/colleyRstats/reference/cite_methods.md):
  prints methods boilerplate plus the BibTeX entries for the packages
  behind the analyses (ART, Dunn, nparLD, ggstatsplot, effectsize).
- Consistent snake_case aliases with discoverable prefixes for the whole
  API (e.g.,
  [`report_art()`](https://m-colley.github.io/colleyRstats/reference/reportART.md),
  [`report_dunn_test()`](https://m-colley.github.io/colleyRstats/reference/reportDunnTest.md),
  [`plot_between_stats()`](https://m-colley.github.io/colleyRstats/reference/ggbetweenstatsWithPriorNormalityCheck.md),
  [`check_assumptions_anova()`](https://m-colley.github.io/colleyRstats/reference/checkAssumptionsForAnova.md)).
  The original names remain fully supported.
- New option `options(colleyRstats.leading_zero = FALSE)` for APA-style
  p-values and effect sizes without the leading zero (e.g., `p=.033`).
- Significance brackets in the asterisk plot helpers are now stacked
  relative to the data range, so the layout works for any
  dependent-variable scale (1-7 Likert and 0-100 TLX alike).

### BUG FIXES

- [`reportggstatsplot()`](https://m-colley.github.io/colleyRstats/reference/reportggstatsplot.md)
  now recognizes the unpaired non-parametric test (“Wilcoxon rank sum
  test”, reported with its W statistic); previously such results fell
  through to a generic fallback format. The signed-rank (paired) variant
  keeps the V statistic. The p-value is also compared before rounding,
  so e.g. p = 0.0009 is reported as “p \< 0.001” again.
- [`reportNPAV()`](https://m-colley.github.io/colleyRstats/reference/reportNPAV.md),
  [`reportART()`](https://m-colley.github.io/colleyRstats/reference/reportART.md),
  and
  [`reportNparLD()`](https://m-colley.github.io/colleyRstats/reference/reportNparLD.md)
  with `write_to_clipboard = TRUE` now write all significant effects to
  the clipboard at once; previously each effect overwrote the previous
  one and only the last sentence survived. These functions now also
  invisibly return the reported sentences.
- The asterisk plot helpers
  ([`ggbetweenstatsWithPriorNormalityCheckAsterisk()`](https://m-colley.github.io/colleyRstats/reference/ggbetweenstatsWithPriorNormalityCheckAsterisk.md),
  [`ggwithinstatsWithPriorNormalityCheckAsterisk()`](https://m-colley.github.io/colleyRstats/reference/ggwithinstatsWithPriorNormalityCheckAsterisk.md))
  no longer drop significant comparisons whose adjusted p-value is
  exactly 0.01 or 0.001.
- [`replace_values()`](https://m-colley.github.io/colleyRstats/reference/replace_values.md)
  no longer round-trips untouched numeric columns through
  [`as.character()`](https://rdrr.io/r/base/character.html), which
  silently truncated values to 15 significant digits.
- [`reportggstatsplotPostHoc()`](https://m-colley.github.io/colleyRstats/reference/reportggstatsplotPostHoc.md)
  handles missing values in the dependent variable (`na.rm = TRUE`) and
  falls back to the raw level name when a `label_mappings` entry is
  missing instead of producing malformed text.
- [`reportNparLD()`](https://m-colley.github.io/colleyRstats/reference/reportNparLD.md)
  output now correctly says “nparLD analysis” instead of “NPAV”, and the
  required `\df` LaTeX command is documented.
- [`reportDunnTestTable()`](https://m-colley.github.io/colleyRstats/reference/reportDunnTestTable.md)
  and
  [`reportArtConTable()`](https://m-colley.github.io/colleyRstats/reference/reportArtConTable.md):
  `orderByP = TRUE` now takes precedence over the default alphabetical
  ordering instead of being silently undone by it.
- Partial eta squared in
  [`reportART()`](https://m-colley.github.io/colleyRstats/reference/reportART.md)/[`reportNPAV()`](https://m-colley.github.io/colleyRstats/reference/reportNPAV.md)
  is now computed from the unrounded F statistic.
- [`rFromWilcoxAdjusted()`](https://m-colley.github.io/colleyRstats/reference/rFromWilcoxAdjusted.md)
  caps the adjusted p-value at 1, avoiding `NaN` results.
- [`generateMoboPlot2()`](https://m-colley.github.io/colleyRstats/reference/generateMoboPlot2.md)
  stops with a clear error when the phase column lacks
  “sampling”/“optimization” rows instead of producing `-Inf` positions.
- [`normalize()`](https://m-colley.github.io/colleyRstats/reference/normalize.md)
  rejects a zero-width input range instead of returning `Inf`/`NaN`.
- [`remove_outliers_REI()`](https://m-colley.github.io/colleyRstats/reference/remove_outliers_REI.md)
  now actually uses its `range` argument (validation plus an
  out-of-range warning) and ignores `NA` responses when tallying instead
  of poisoning row counts.
- [`reshape_data()`](https://m-colley.github.io/colleyRstats/reference/reshape_data.md)
  reports a clear error when marker-delimited sections have unequal
  column counts.
- [`checkAssumptionsForAnova()`](https://m-colley.github.io/colleyRstats/reference/checkAssumptionsForAnova.md)
  distinguishes “normality could not be assessed” from “normality
  violated” and uses a consistent p \< 0.05 boundary.
- Effect-size failures in the Dunn/ART post-hoc reporters now emit a
  warning instead of being silently swallowed.
- The four `gg*WithPriorNormalityCheck*()` wrappers now pass the palette
  in the `"pals::glasbey"` format required by current ggstatsplot; the
  deprecated `package=`/`palette=` pair was being ignored with a
  warning, so plots silently used the default palette instead of
  glasbey.

### PERFORMANCE

- [`add_pareto_emoa_column()`](https://m-colley.github.io/colleyRstats/reference/add_pareto_emoa_column.md)
  uses
  [`emoa::is_dominated()`](https://rdrr.io/pkg/emoa/man/dom_op.html)
  directly instead of matching rows against the Pareto front with
  floating-point equality (was O(front size x rows)).
- The mobo plots draw their annotation segments once via
  [`annotate()`](https://ggplot2.tidyverse.org/reference/annotate.html)
  instead of once per data row.
- [`ggwithinstatsWithPriorNormalityCheckAsterisk()`](https://m-colley.github.io/colleyRstats/reference/ggwithinstatsWithPriorNormalityCheckAsterisk.md)
  no longer runs an unused Levene test.

### DEPENDENCIES

- Reduced hard dependencies: ARTool, car, clipr, conflicted, FSA,
  ggtext, readxl, report, rstatix, writexl, and xtable moved from
  Imports to Suggests (functions that need them check at runtime and
  degrade gracefully or stop with an informative message). `car` is no
  longer used by the package code at all.
- ggplot2 moved from Imports to Depends: the ggproto stats of ggpmisc
  0.7.0/ggpp 0.6.0 resolve their parent classes via the search path, so
  [`generateMoboPlot()`](https://m-colley.github.io/colleyRstats/reference/generateMoboPlot.md)/[`generateMoboPlot2()`](https://m-colley.github.io/colleyRstats/reference/generateMoboPlot2.md)
  fail with “object ‘Stat’ not found” whenever ggplot2 is not attached.
  Attaching colleyRstats now attaches ggplot2 as well.

### MISC

- Removed the duplicate `inst/WORDLIST.txt` and the redundant
  `tests.yml` CI workflow (R-CMD-check already runs the tests).

## colleyRstats 0.0.5

### MINOR CHANGES

- new function
  [`add_pareto_moocore_column()`](https://m-colley.github.io/colleyRstats/reference/add_pareto_moocore_column.md).
  Should be less buggy than the one from `emoa`

## colleyRstats 0.0.4

CRAN release: 2026-05-03

### MINOR CHANGES

- exposed new parameters for
  [`generateMoboPlot2()`](https://m-colley.github.io/colleyRstats/reference/generateMoboPlot2.md).

## colleyRstats 0.0.3

CRAN release: 2026-04-24

### MINOR CHANGES

- Fixed documentation defaults for
  [`colleyRstats_setup()`](https://m-colley.github.io/colleyRstats/reference/colleyRstats_setup.md)
  and
  [`generateMoboPlot2()`](https://m-colley.github.io/colleyRstats/reference/generateMoboPlot2.md).
- Made
  [`generateMoboPlot2()`](https://m-colley.github.io/colleyRstats/reference/generateMoboPlot2.md)
  default to `fillColourGroup = "ConditionID"` so the documented default
  works out of the box.
- Simplified the GitHub Actions test workflow to install dependencies
  from package metadata.
- Expanded tests for plotting and reporting behavior.
- Added a getting-started vignette and linked it from the README.

## colleyRstats 0.0.2

CRAN release: 2026-01-08

### MINOR CHANGES

- Updated all links, added GitHub reference.
