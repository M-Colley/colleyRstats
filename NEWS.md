# colleyRstats 0.2.0

## NEW FEATURES

### Questionnaire scoring

- New `score_questionnaire()` applies a published instrument's own scoring key to raw item columns: reverse-coding, the recoding it prescribes (centring a semantic differential to -3..+3, zero-basing the SUS), its subscale structure, and its published weights or multipliers. Ten instruments ship: **NASA-TLX** (raw/RTLX), **SUS** with the Lewis & Sauro usability/learnability subscales, **UEQ-S**, the full 26-item **UEQ**, **TiA** (Körber), **AttrakDiff 2**, **IPQ**, **SSQ** (with the Kennedy et al. weights and its overlapping subscales), **FMS** and **MISC**. The scoring is checked against published reference values in the test suite: the SUS anchors (100/0/50), the SSQ weighting (21 raw on each subscale gives 200.34/159.18/292.32, total 235.62), the TLX rescale from any sheet onto 0-100, and the UEQ's balanced polarity, where answering the positive pole of all 26 pairs must give +3 on all six scales.
- `scale =` declares the response range a survey actually used, so a 21-point TLX sheet, a 20-point slider and a 0-100 slider all score onto the conventional 0-100. Responses outside the declared range are an error, not a silent rescale.
- `min_valid =` governs incomplete responses. The default scores only complete subscales and returns `NA` otherwise -- no silent imputation. Relaxing it scales a sum-scored instrument up proportionally so it stays on its published range.
- A standing **caution prints in the console**, not only in the help pages: item numbers, order and polarity depend on how a questionnaire was administered, this package applies the *published* key, and a mismatch produces plausible numbers rather than an error -- so any figure must be double-checked before it goes into a paper. It appears from `score_questionnaire()` (once per distinct mapping per session, alongside the mapping itself), and from `check_questionnaire()`, `questionnaire_items()` and `score_reliability()` every time. The wording lives in one place, so the console text and the help pages cannot drift apart. Silence the repeated note in a pipeline with `options(colleyRstats.quiet_questionnaires = TRUE)`; that quiets the note, not the errors.
- New `check_questionnaire()` prints the mapping that will be used -- which column supplies which item, its subscale, whether it is reverse-coded, and the observed range of each column -- along with the instrument's scoring notes. This is the guard against the failure mode that motivates the whole feature: item order and polarity belong to the sheet a study actually administered, so a shifted or re-ordered survey export scores silently, plausibly, and wrongly. `score_questionnaire()` also attaches the mapping as an attribute and announces it once per session.
- New `score_reliability()` gives Cronbach's alpha (and McDonald's omega where 'psych' is installed) per subscale, computed on the same recoded matrix that is aggregated -- so a negative alpha means a real problem rather than a forgotten reversal, and it warns when one appears.
- New `define_questionnaire()` registers a lab-specific, translated or shortened instrument, which then behaves exactly like a built-in one. Put it in a project's setup script and every analysis in that project scores it identically.
- New `reverse_code(x, min, max)` flips a response scale using the *possible* range rather than the observed one, and warns about out-of-range values. Taking the endpoints from the data is the classic reverse-coding bug: if nobody picked the lowest option, every flipped response is off by a point.
- New `summarize_sickness()` reduces a repeated single-item sickness rating (FMS, MISC) to the measures those studies actually analyse: peak, mean, final value, trapezoidal area under the curve, the time-weighted mean, and time to a threshold.
- New `list_questionnaires()` and `questionnaire_items()` describe the registry and one instrument's items.

### Fitting the recommended model

- New `fit_recommended()` carries `recommend_test()` through to a fitted model. It coerces the outcome and predictors into the classes the model family needs (announcing each coercion, since turning a numeric rating into an ordered factor changes what is estimated), builds the random-effect term for a clustered design, fits, computes pairwise post-hoc contrasts with the machinery that matches the fit, and produces the manuscript sentence via this package's reporter for that family. It covers cumulative link models with and without random effects, linear and generalized linear mixed models, GLMs, the aligned rank transform, nparLD, multinomial regression, and the classical ANOVA / Welch / Kruskal-Wallis / Wilcoxon tests.
- The point is that the test justified in the methods section and the model actually run come from one call on one data frame, so they cannot drift apart -- the failure mode of a workflow where `recommend_test()` prints advice that is then re-typed by hand.
- `outcome_type =` overrides the automatic classification. This matters more than it sounds: an outcome whose scores stay whole numbers is taken for a count and fitted with a Poisson model. That catches the six raw NASA-TLX subscales, a single MISC rating, and item-level ratings; SUS and RTLX escape it only because their multipliers and means make them fractional.

### Pareto fronts in the direction you actually optimise

- `add_pareto_moocore_column()` and `add_pareto_emoa_column()` gain `maximise`. Both minimised unconditionally: `moocore::is_nondominated()` was called with its `maximise = FALSE` default and `emoa::is_dominated()` has no direction argument at all. Since trust, acceptance, perceived safety and most other rating-scale objectives are *maximised*, using them meant passing negated copies of your own columns and remembering to negate them everywhere else too. Pass `maximise = TRUE`, or a logical vector with one entry per objective for a mixed problem (`c(TRUE, TRUE, FALSE)` to maximise two and minimise a workload score). The default stays `FALSE`, so existing results are unchanged.
- The length of `maximise` is validated. `moocore::is_nondominated()` accepts three flags for two objectives and quietly uses the first two, which would produce a plausible, wrong front; passing the wrong number here is an error naming the objectives instead.
- A test asserts the two backends agree on the same front under every direction setting, and that `maximise = TRUE` matches the negate-your-columns workaround it replaces.

### Starting a study

- New `use_study_project()` scaffolds a study analysis as a reproducible pipeline: a 'targets' pipeline that recomputes only what changed, R scripts split along the stages every user study goes through (read, clean, score, model, plot), a Quarto report, a directory the generated LaTeX lands in so a manuscript `\input{}`s the numbers instead of having them re-typed, `renv` for version pinning, and a `.gitignore` that keeps generated output out of the repository.
- It ships synthetic example data with a column per item of every instrument named, so a freshly scaffolded project runs end to end before any real data exists. The generated `OUTCOMES` and `OUTCOME_TYPES` vectors are derived by scoring a dummy row through the real code path, so the scaffold cannot name a column that `score_questionnaire()` does not produce.
- It never overwrites an existing file unless asked, so it can be re-run on a live project to pick up new pieces.

## DOCUMENTATION

- New `vignette("scoring-questionnaires")` covers the scoring key, verifying a mapping before trusting it, incomplete responses, reliability, registering your own instrument, and the sickness time course.
- The `pkgdown` reference index gains **Questionnaires** and **Starting a study** sections.

# colleyRstats 0.1.6

## BUG FIXES

- `reportNparLD()` announced "no significant effects" for every model fitted with 'nparLD' 2.3.0, however strong the effect actually was. That release rewrote the object `nparLD::nparLD()` returns: it now has class `nparld_fit` and carries the ANOVA-type statistic in `$ATS`, where earlier versions used `$ANOVA.test`. Asking for the old name yielded `NULL`, and `as.data.frame(NULL)` is a table with no rows -- which the code that followed could not tell apart from a table in which nothing crossed p < .05. A toy fit with ATS = 92.8 and p < 1e-10 was reported as effect-free. Both layouts are now recognised, and an object carrying neither raises an error instead of silently reporting nothing.
- The example on `?reportNparLD` passed `description = FALSE` to `nparLD::nparLD()`. 'nparLD' 2.3.0 dropped that argument, so `R CMD check --run-donttest` failed on CRAN with `unused argument (description = FALSE)`. The call now uses only arguments both versions accept, and the toy data carries a trend over time so the example demonstrates a reported sentence rather than the no-effect message.

## NEW FEATURES

- New `animate_mobo2()`, the video counterpart of `generateMoboPlot2()`. It draws one frame per iteration and encodes them with `av`, so an optimisation run can be shown building up rather than only in its finished state; the file extension picks the container (`.mp4`, `.gif`, `.mov`, ...). The plot is built once from the complete data and each frame only hides rows, which is what keeps the axes, the sampling/optimisation guides and the legend still while the points, intervals, fitted line and its equation move. It is also the only way the early frames can be drawn: `generateMoboPlot2()` requires both phases to be present, and the first iterations are all sampling. `av` is a `Suggests`, so nothing changes for installations that do not want it.

# colleyRstats 0.1.5

## BUG FIXES

- `colleyRstats_setup()` made it impossible to attach a meta-package afterwards. `library(colleyRstats)`, `colleyRstats_setup()`, `library(easystats)` died on the third line with `.onAttach failed in attachNamespace() for 'easystats': object 'quietly' not found`, which broke every downstream analysis script that opens that way. The cause was the `set_conflicts = TRUE` default: `conflicted::conflict_prefer()` does not merely record a preference, it *activates* `conflicted`, which attaches a `.conflicts` environment carrying its own `library()` and `require()` shims. Every later attach in the session then went through those shims, which forward `quietly` and `verbose` into `base::library()` as unevaluated symbols; a package whose `.onAttach` inspects the calling `library()` frame -- meta-packages do this to decide whether to print their banner -- evaluated those symbols in a frame that does not bind them, and the attach failed outright. `set_conflicts` now defaults to `FALSE`, so nothing takes over `library()` unless it is asked to. The preference list is unchanged and still takes effect when you opt in.
- Preferences that fail to register are no longer discarded silently. The `try()` around the loop existed so that one unsettable preference could not abort the rest, but it also swallowed the fact that it had failed; with `verbose = TRUE` the failures are now named.

- Figures saved at the column presets came out unreadable. `colleyRstats_setup()` set text sizes in **absolute** points (axis text 17 pt, axis titles 20 pt, plot titles 28 pt, strip text 22 pt) while `save_paper_figure(columns = 1)` writes a **3.33 x 2.22 in** PDF. Points do not shrink with the canvas, so on a single-column figure the type came out about three times what fits: axis titles ran off the page entirely, and three-level factor labels such as `demonstration`/`language`/`reward` overprinted into an unreadable smear. Type size is now derived from the width the figure is actually written at.
- `generateEffectPlot()` fixed its legend title at 14 pt, and the four `ggstatsplot` wrappers fixed `text` at 16 pt and `plot.subtitle` at 17 pt. These absolute values overrode whatever theme the caller had chosen, so they survived any attempt to scale a figure down. They are now relative to the theme.
- Significance-bracket labels were fixed at 4 mm (about 11 pt). `ggsignif` measures text in millimetres while themes measure it in points, so the label kept its physical size no matter how small the figure was drawn and ended up larger than the axis text beside it. Bracket text now follows the active theme; at the historical 17 pt base it is still 4 mm, so existing figures do not shift.

## NEW FEATURES

- New `colley_theme(base_size, base_family)`, the package theme as a function. Every text element is a multiple of `base_size` rather than an absolute point size, so one theme serves a journal column, a full-width figure and a slide -- only the number changes. The multipliers are axis titles 1.15, axis text 1.0, plot title 1.65, subtitle 1.0, caption 0.8, legend text 0.9, strip text 1.3.
- New `figure_base_size(width)`, the rule that turns a figure width into a type size: 3.33 in gives 7 pt and 7 in gives 9 pt, interpolated between and clamped outside. Exported so the choice is inspectable rather than buried.
- `save_paper_figure()` gains `base_size`. The default `NULL` derives it from the width, which is the fix above; pass a number to choose it, or `NA` to leave the plot's own text sizes untouched. The confirmation message now names the size used.
- `colleyRstats_setup()` gains `base_size` (default 17), passed through to `colley_theme()`.
- A `pkgdown` site (`_pkgdown.yml` plus a deploy workflow) puts the 56 help topics into a grouped reference index -- session setup, pipelines, test selection, assumptions, plots, reporting, effect sizes, LaTeX output, data preparation -- instead of one alphabetical wall.

## DOCUMENTATION

- The README and `vignette("getting-started")` now show the session-setup pattern, including where `colleyRstats_setup()` belongs relative to your `library()` calls and what happens if it goes first. Neither had covered this, which is how the `conflicted` defect above reached three downstream analysis repositories.
- The `snake_case` spellings (`report_art()`, `plot_effect()`, `check_assumptions_anova()`, ...) are now stated to be the canonical ones, and the documentation uses them throughout: README, vignettes, and the `pkgdown` reference index. Every affected help page gained a **Naming** section saying which spelling to prefer and that the other is not going away. Previously the aliases file described `snake_case` as the discoverable API while the README taught `camelCase` exclusively, and nothing told a reader which to use.

## BACKWARD COMPATIBILITY

- The `camelCase` function names (`reportART()`, `generateEffectPlot()`, and the rest) are now marked **superseded**. Nothing changes at runtime: they are the same function objects, they emit no warnings, and they are not scheduled for removal. Only the documentation's recommendation has changed.
- `colleyRstats_setup(set_options = TRUE)` now emits a deprecation warning instead of an easily missed message, and the warning is no longer suppressed by `verbose = FALSE`. The argument has had no effect since global `options()` handling was removed for CRAN compliance; `set_options = FALSE` is unaffected.
- `colleyRstats_setup()` no longer sets `conflicted` preferences by default. Pass `set_conflicts = TRUE` for them, and place that call **after** every `library()` call in the script rather than before. That ordering is a requirement -- once `conflicted` is active, attaching a meta-package fails -- and it is also where the preferences do most good, since `conflicted` resolves only those names that are ambiguous among the packages attached at the time.
- `colleyRstats_setup()` with no arguments produces the same text sizes as before: the default `base_size = 17` reproduces the previous absolute values exactly (17 / 19.55 / 28.05 / 15.3 / 22.1 pt), and there is a regression test pinning them.
- Figures written through `save_paper_figure()` **do** change, which is the point of the fix -- they become legible at the size they are placed at. To keep a figure exactly as it was, pass `base_size = NA`.
- Because the theme is now built as `see::theme_lucid(base_size = ...)` rather than `theme_lucid()` with sizes overridden on top, margins and spacing scale with the text instead of staying at the 11 pt defaults. This is part of why elements used to collide.

# colleyRstats 0.1.4

## BUG FIXES

- `reportART()` reported no F statistic and no effect size for **mixed** ART models. `stats::anova()` names the F column `F value` for a between-only (`lm`) fit but plain `F` for a mixed (`lmer`) one, and only the former was read -- so every model containing a random term (`+ (1 | participant)`, i.e. any within-subjects design) produced `\F{3}{108}{}` with the statistic missing, silently dropped the partial eta-squared, and left the opening parenthesis unclosed. The F column is now resolved by whichever name it carries.
- `reportART()` now always closes the statistics parenthesis. It was appended only when an effect size could be computed, so sentences without one shipped unbalanced parentheses into LaTeX.
- `reportggstatsplotPostHoc()` emitted a stray `)` after the p-value: `... (\m{3.8}, \sd{1.6}); \padj{0.001}).` The mean/SD parenthetical closed too early, leaving the p-value outside the parentheses it belongs to and the sentence unbalanced. It now reads `... (\m{3.8}, \sd{1.6}; \padj{0.001}).`, matching `reportArtCon()`.
- Degrees of freedom are formatted for display. Greenhouse-Geisser corrected, Kenward-Roger and Welch dfs are fractional and were pasted at full double precision, e.g. `\F{1.80875305770353}{66.9238631350305}{0.11}` and `F(2, 180.000000000002)`. Whole dfs stay whole; fractional ones are rounded to two decimals.
- `reportggstatsplot()` chooses the indefinite article from the method name, so it reads "An ANOVA ..." rather than "A ANOVA ...".

## DOCUMENTATION

- Updated the Datanovia ANOVA-assumptions link, which had moved (README and the `check_assumptions_anova()` guidance message).

# colleyRstats 0.1.3

## NEW FEATURES

- New vignette "Analyzing a typical user study" (`vignette("analyzing-a-user-study")`): a complete walkthrough from raw within-subjects data to manuscript-ready figures and LaTeX text.
- Friendlier errors everywhere a column name is passed: plotting and reporting functions now validate `x`/`y`/`iv`/`dv`/`factors`/`objectives` up front and report which column is missing plus the available columns, instead of failing later with a cryptic dplyr/rlang error.
- The plot wrappers warn when `xlabels` does not match the number of observed groups (previously the axis labels silently misaligned).
- `not_empty()` now names the offending argument in its default error message.
- `remove_outliers_REI()` accepts `variables` as a character vector (e.g. `c("var1", "var2")`) in addition to the comma-separated string.
- `add_pareto_emoa_column()` / `add_pareto_moocore_column()` verify that the objective columns exist and are numeric.

## BUG FIXES

- `?replace_values` works again: a malformed roxygen `@name` tag had redirected its documentation to a stray `data-the-data-frame` help page.
- `reportArtCon()` now escapes the dependent variable and condition names for LaTeX and renders the IV via the same name-macro policy as `reportDunnTest()`; previously names with underscores produced uncompilable LaTeX.
- The `reshape_data()` example was not runnable (`requireNamespace()` was called with a vector and a misspelled package name).
- `latex_preamble()` no longer documents its `path` argument twice; `rFromNPAV()`'s documentation block is no longer split by a stray comment line.
- `reportNPAV()` no longer refers to the non-existent `reportNPAVChi()` when the input lacks a `Pr(>F)` column.
- README: removed the section documenting the non-existent `reportNPAVChi()`, refreshed the stale `reportNPAV()` deprecation date, fixed the double `anova()` call in the `reportART()` example, and documented the newer API (recommend_test, pipelines, Overleaf output) and all vignettes.

## PERFORMANCE

- `ggwithinstatsWithPriorNormalityCheck()` no longer runs an unused Levene test (the asterisk variant was already fixed in 0.1.0).

# colleyRstats 0.1.2

## NEW FEATURES

- Principled model selection: `classify_outcome()` determines a variable's measurement scale (continuous, ordinal, binary, count, nominal) and `recommend_test()` turns scale x clustering x assumption checks into a concrete recommendation -- including mixed models -- with the matching reporter, a ready-to-edit fit call, a rationale, and an APA-style methods sentence.
- Mixed-model reporters: `reportGLMM()` (lme4 / glmmTMB / lm / glm; odds and incidence-rate ratios are chosen automatically from the family) and `reportCLMM()` (ordinal::clmm / clm).
- Overleaf-oriented output layer: `use_colleyrstats_sty()` ships the macro package, `emit_name_macros()` / `define_result_macro()` generate `\newcommand` stubs and single-source-of-truth result macros, `expand_latex_macros()` -- with `options(colleyRstats.macros = FALSE)` -- expands everything to plain math, and `emit_overleaf()` bundles a whole analysis into a compilable Overleaf project.
- `latex_escape()` escapes LaTeX special characters in user-supplied names.
- New vignettes: "Choosing the right test (and mixed models)" and "From R to Overleaf: publication-ready output".

## DEPENDENCIES

- Lowered several minimum version requirements for broader compatibility.

# colleyRstats 0.1.1

## BUG FIXES
- adjustment of the post-hoc test due to changes in the `ggstatsplot` implementation

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
