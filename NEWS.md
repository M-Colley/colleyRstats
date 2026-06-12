# colleyRstats 0.1.0

## NEW FEATURES

- `analyze_and_report()`: one-call pipeline per dependent variable -- assumption checks with a ready-made methods sentence, the matching ggstatsplot figure (automatic parametric/non-parametric selection), the omnibus result, and post-hoc comparisons.
- `report_all()`: runs `analyze_and_report()` over many dependent variables (e.g., all questionnaire scales of a study), returns a summary table with Holm-adjusted omnibus p-values across the DVs, and a combined figure when `patchwork` is installed.
- `latex_preamble()`: prints (or writes to a file) the complete set of LaTeX `\newcommand` definitions required by the report functions -- no more hunting through individual help pages.
- All report functions accept `sink_to` to write their output to a `.tex` file, so manuscripts can `\input{}` the results and stay up to date when the analysis is re-run. They all also invisibly return their text for programmatic use (e.g., inline in Quarto/R Markdown).
- `save_paper_figure()`: saves plots with publication presets (ACM-style single-column 3.33 in / full-width 7 in). PDFs use Cairo for embedded fonts on Windows/Linux; on macOS the default pdf device is used because R's cairo there can crash the session (observed as segfaults on GitHub Actions macOS runners). A `device` argument allows overriding.
- `assumption_methods_text()`: turns the Shapiro-Wilk (and optionally Levene) checks into the methods-section justification sentence reviewers expect, including the test statistics. `check_normality_by_group()` and `check_homogeneity_by_group()` now attach their test statistics as attributes.
- `cite_methods()`: prints methods boilerplate plus the BibTeX entries for the packages behind the analyses (ART, Dunn, nparLD, ggstatsplot, effectsize).
- Consistent snake_case aliases with discoverable prefixes for the whole API (e.g., `report_art()`, `report_dunn_test()`, `plot_between_stats()`, `check_assumptions_anova()`). The original names remain fully supported.
- New option `options(colleyRstats.leading_zero = FALSE)` for APA-style p-values and effect sizes without the leading zero (e.g., `p=.033`).
- Significance brackets in the asterisk plot helpers are now stacked relative to the data range, so the layout works for any dependent-variable scale (1-7 Likert and 0-100 TLX alike).

## BUG FIXES

- `reportggstatsplot()` now recognizes the unpaired non-parametric test ("Wilcoxon rank sum test", reported with its W statistic); previously such results fell through to a generic fallback format. The signed-rank (paired) variant keeps the V statistic. The p-value is also compared before rounding, so e.g. p = 0.0009 is reported as "p < 0.001" again.
- `reportNPAV()`, `reportART()`, and `reportNparLD()` with `write_to_clipboard = TRUE` now write all significant effects to the clipboard at once; previously each effect overwrote the previous one and only the last sentence survived. These functions now also invisibly return the reported sentences.
- The asterisk plot helpers (`ggbetweenstatsWithPriorNormalityCheckAsterisk()`, `ggwithinstatsWithPriorNormalityCheckAsterisk()`) no longer drop significant comparisons whose adjusted p-value is exactly 0.01 or 0.001.
- `replace_values()` no longer round-trips untouched numeric columns through `as.character()`, which silently truncated values to 15 significant digits.
- `reportggstatsplotPostHoc()` handles missing values in the dependent variable (`na.rm = TRUE`) and falls back to the raw level name when a `label_mappings` entry is missing instead of producing malformed text.
- `reportNparLD()` output now correctly says "nparLD analysis" instead of "NPAV", and the required `\df` LaTeX command is documented.
- `reportDunnTestTable()` and `reportArtConTable()`: `orderByP = TRUE` now takes precedence over the default alphabetical ordering instead of being silently undone by it.
- Partial eta squared in `reportART()`/`reportNPAV()` is now computed from the unrounded F statistic.
- `rFromWilcoxAdjusted()` caps the adjusted p-value at 1, avoiding `NaN` results.
- `generateMoboPlot2()` stops with a clear error when the phase column lacks "sampling"/"optimization" rows instead of producing `-Inf` positions.
- `normalize()` rejects a zero-width input range instead of returning `Inf`/`NaN`.
- `remove_outliers_REI()` now actually uses its `range` argument (validation plus an out-of-range warning) and ignores `NA` responses when tallying instead of poisoning row counts.
- `reshape_data()` reports a clear error when marker-delimited sections have unequal column counts.
- `checkAssumptionsForAnova()` distinguishes "normality could not be assessed" from "normality violated" and uses a consistent p < 0.05 boundary.
- Effect-size failures in the Dunn/ART post-hoc reporters now emit a warning instead of being silently swallowed.
- The four `gg*WithPriorNormalityCheck*()` wrappers now pass the palette in the `"pals::glasbey"` format required by current ggstatsplot; the deprecated `package=`/`palette=` pair was being ignored with a warning, so plots silently used the default palette instead of glasbey.

## PERFORMANCE

- `add_pareto_emoa_column()` uses `emoa::is_dominated()` directly instead of matching rows against the Pareto front with floating-point equality (was O(front size x rows)).
- The mobo plots draw their annotation segments once via `annotate()` instead of once per data row.
- `ggwithinstatsWithPriorNormalityCheckAsterisk()` no longer runs an unused Levene test.

## DEPENDENCIES

- Reduced hard dependencies: ARTool, car, clipr, conflicted, FSA, ggtext, readxl, report, rstatix, writexl, and xtable moved from Imports to Suggests (functions that need them check at runtime and degrade gracefully or stop with an informative message). `car` is no longer used by the package code at all.
- ggplot2 moved from Imports to Depends: the ggproto stats of ggpmisc 0.7.0/ggpp 0.6.0 resolve their parent classes via the search path, so `generateMoboPlot()`/`generateMoboPlot2()` fail with "object 'Stat' not found" whenever ggplot2 is not attached. Attaching colleyRstats now attaches ggplot2 as well.

## MISC

- Removed the duplicate `inst/WORDLIST.txt` and the redundant `tests.yml` CI workflow (R-CMD-check already runs the tests).


# colleyRstats 0.0.5

## MINOR CHANGES

- new function `add_pareto_moocore_column()`. Should be less buggy than the one from `emoa`


# colleyRstats 0.0.4

## MINOR CHANGES

- exposed new parameters for `generateMoboPlot2()`.

# colleyRstats 0.0.3

## MINOR CHANGES

- Fixed documentation defaults for `colleyRstats_setup()` and `generateMoboPlot2()`.
- Made `generateMoboPlot2()` default to `fillColourGroup = "ConditionID"` so the documented default works out of the box.
- Simplified the GitHub Actions test workflow to install dependencies from package metadata.
- Expanded tests for plotting and reporting behavior.
- Added a getting-started vignette and linked it from the README.

# colleyRstats 0.0.2


## MINOR CHANGES

- Updated all links, added GitHub reference.
