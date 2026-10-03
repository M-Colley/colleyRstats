# Changelog

## colleyRstats 0.3.0

This release fixes a set of defects that could put a wrong number, a
wrong direction or a wrong label into a manuscript without any error.
**Re-run within-subjects analyses, post-hoc sentences from rank-based
tests, mixed-model reports and `prefix =` questionnaire scoring made
with earlier versions.**

### BREAKING CHANGES

- [`ggwithinstatsWithPriorNormalityCheck()`](https://m-colley.github.io/colleyRstats/reference/ggwithinstatsWithPriorNormalityCheck.md)
  /
  [`plot_within_stats()`](https://m-colley.github.io/colleyRstats/reference/ggwithinstatsWithPriorNormalityCheck.md),
  the asterisk variant, and
  [`analyze_and_report()`](https://m-colley.github.io/colleyRstats/reference/analyze_and_report.md)
  /
  [`report_all()`](https://m-colley.github.io/colleyRstats/reference/report_all.md)
  with `design = "within"` require a new `subject =` argument naming the
  participant column. Without it, `ggstatsplot` paired the k-th row of
  each condition: shuffling one condition’s rows moved p from 3e-7 to
  0.30, and one participant missing a condition shifted every later
  pair. Participants lacking a condition are now dropped with a message
  naming them, and more than one row per participant and condition is an
  error (aggregate repeated trials first). `subject` is the last
  argument, so existing positional calls are not silently remapped.
- R (\>= 4.3.0) is required: the declared `ggstatsplot` (\>= 1.0.0) and
  `statsExpressions` (\>= 2.0.0) need it, so the previous R (\>= 4.2.0)
  could not be satisfied. `ggplot2` (\>= 3.5.0) is required for the
  inside-legend placement used by the themes and plots.
- [`score_questionnaire()`](https://m-colley.github.io/colleyRstats/reference/score_questionnaire.md)
  stops with an error when an item column holds text (“Strongly agree”,
  “5 - Strongly agree”, “2,5”), names duplicate columns, or gets a
  `prefix` whose column names do not identify the items. All three used
  to score silently and wrongly.
- [`use_study_project()`](https://m-colley.github.io/colleyRstats/reference/use_study_project.md)
  no longer initialises renv by default; pass `renv = TRUE`, which now
  runs
  [`renv::init()`](https://rstudio.github.io/renv/reference/init.html)
  in a separate R process so the calling session’s library paths,
  environment variables and options are untouched.
- [`not_empty()`](https://m-colley.github.io/colleyRstats/reference/not_empty.md)
  rejects a data frame without rows.

### BUG FIXES

#### Within-subjects analyses

- [`check_normality_by_group()`](https://m-colley.github.io/colleyRstats/reference/check_normality_by_group.md)
  gains `subject =` and then tests what a repeated-measures analysis
  assumes to be normal: the per-participant differences (two conditions)
  or the residuals of `y ~ condition + participant` (more), not the raw
  scores per condition. Between subjects, the per-group p-values are now
  Holm-corrected (six normal groups used to send about one analysis in
  four to the non-parametric branch), and a group that cannot be tested
  – fewer than three values, or a rating item at ceiling – counts as
  non-normal instead of passing silently.
- [`assumption_methods_text()`](https://m-colley.github.io/colleyRstats/reference/assumption_methods_text.md)
  gains `subject` and describes the check that was actually run, names
  untestable groups, labels adjusted p-values as such, and names the
  variance test as run (Brown-Forsythe, the median-centred Levene test
  `rstatix` uses). With `subject`, `include_homogeneity` is ignored with
  a message: equal variances across conditions are not a
  repeated-measures assumption, and the Welch clause it could add has no
  meaning there.
- [`checkAssumptionsForAnova()`](https://m-colley.github.io/colleyRstats/reference/checkAssumptionsForAnova.md)
  treats every factor as categorical (numeric condition codes were
  fitted as one linear covariate, so identical data got opposite advice
  depending on the coding), Holm-corrects its per-cell tests, reports
  cells too small to test instead of crashing, and gains `subject =` to
  test the residuals a repeated-measures ANOVA assumes.
- With a single two-level within-subject factor,
  [`checkAssumptionsForAnova()`](https://m-colley.github.io/colleyRstats/reference/checkAssumptionsForAnova.md)
  and
  [`recommend_test()`](https://m-colley.github.io/colleyRstats/reference/recommend_test.md)
  test the per-participant differences, as
  [`check_normality_by_group()`](https://m-colley.github.io/colleyRstats/reference/check_normality_by_group.md)
  does, rather than the model residuals: each participant’s two
  residuals are mirror images, a symmetrised sample in which
  Shapiro-Wilk missed skewed differences about half the time.
- Every within-subjects entry point – the plot wrappers,
  [`check_normality_by_group()`](https://m-colley.github.io/colleyRstats/reference/check_normality_by_group.md),
  [`checkAssumptionsForAnova()`](https://m-colley.github.io/colleyRstats/reference/checkAssumptionsForAnova.md),
  the post-hoc descriptives and
  [`generateEffectPlot()`](https://m-colley.github.io/colleyRstats/reference/generateEffectPlot.md)’s
  within-subject intervals – now decides who is analysed by one shared
  rule (one row per participant and condition; participants lacking a
  condition are left out), so the methods sentence, the test, the figure
  and the descriptives always describe the same participants.
- [`generateEffectPlot()`](https://m-colley.github.io/colleyRstats/reference/generateEffectPlot.md)’s
  main-effect line uses unweighted marginal means (it drew 9 vs 1 where
  the cell means average 5 vs 5 in an unbalanced design); a new
  `subject` gives within-subject (Cousineau-Morey) intervals matching
  `afex`.

#### Post-hoc and omnibus sentences

- [`reportDunnTest()`](https://m-colley.github.io/colleyRstats/reference/reportDunnTest.md),
  [`reportArtCon()`](https://m-colley.github.io/colleyRstats/reference/reportArtCon.md)
  and
  [`reportggstatsplotPostHoc()`](https://m-colley.github.io/colleyRstats/reference/reportggstatsplotPostHoc.md)
  decided which level “was significantly higher” from the raw means,
  which contradicts a rank-based test exactly when outliers or skew made
  one necessary: a Dunn test with Z = -4.05 was reported as “A was
  significantly higher (M = 10.87)”. The direction now comes from the
  test (sign of Z, the ART-C estimate, mean ranks, within-participant
  rank sums, or trimmed means), and the descriptives match it by default
  – `\mdn{}`/`\iqr{}` for rank-based tests – via a new `descriptives`
  argument, with a warning when forced means would contradict the test.
- Dunn and ART-C results computed without a correction were labelled
  $`p_{adj}`$ and “p-adjusted”; they now use `\p{}` and “p”, and the
  sentences name the test and the correction (“A Dunn post-hoc test
  (Holm-adjusted) found …”).
- [`reportArtCon()`](https://m-colley.github.io/colleyRstats/reference/reportArtCon.md)
  crashed (and
  [`reportArtConTable()`](https://m-colley.github.io/colleyRstats/reference/reportArtConTable.md)
  printed NA effect sizes) for numeric-looking levels or levels
  containing `-`, `+`, `*` or `/`, which emmeans rewrites in its labels.
- The partial eta squared “95% CI” of
  [`reportART()`](https://m-colley.github.io/colleyRstats/reference/reportART.md)
  and
  [`reportNPAV()`](https://m-colley.github.io/colleyRstats/reference/reportNPAV.md)
  was one-sided (upper bound always 1.00); it is now two-sided.
- [`reportggstatsplotPostHoc()`](https://m-colley.github.io/colleyRstats/reference/reportggstatsplotPostHoc.md)
  gains `subject`, so its descriptives describe the participants
  [`ggwithinstats()`](https://www.indrapatil.com/ggstatsplot/reference/ggwithinstats.html)
  tested; it writes `sink_to` when nothing is significant, so a stale
  significant result no longer survives in the manuscript; and it
  refuses Bayesian tables instead of calling them non-significant.
  [`reportggstatsplot()`](https://m-colley.github.io/colleyRstats/reference/reportggstatsplot.md)
  reports Bayes factors and Yuen’s t(df), and no longer writes “An A
  heteroscedastic …”.
- p-values are never rounded across .10, .05 or .01: p = 0.0496 used to
  print as “p = .050” inside a sentence calling the result significant.
  Beyond eight digits they are truncated (0.0499999999 prints as
  0.04999999).
- [`reportggstatsplotPostHoc()`](https://m-colley.github.io/colleyRstats/reference/reportggstatsplotPostHoc.md)
  warns whenever a within-subjects plot is reported without `subject`
  (equal row counts per level do not show that every participant is
  complete); its direction warning under `descriptives = "auto"` no
  longer recommends the setting already in use. Between-subjects Yuen
  plots are no longer mistaken for within-subjects ones (“independent
  samples” contains “dependent samples”). Bayes factors below 1 keep two
  significant digits (0.014, not 0.01).

#### Mixed models, `recommend_test()` and `fit_recommended()`

- [`reportGLMM()`](https://m-colley.github.io/colleyRstats/reference/reportGLMM.md)
  reported linear mixed models with the residual df: t(116), p = .030
  where lmerTest’s Satterthwaite test gives t(10), p = .053. LMM
  coefficients now use Satterthwaite df, and the sentence says so.
- [`reportGLMM()`](https://m-colley.github.io/colleyRstats/reference/reportGLMM.md)
  /
  [`reportCLMM()`](https://m-colley.github.io/colleyRstats/reference/reportCLMM.md)
  report a Type III omnibus test for every model term (Satterthwaite F
  for LMMs, Wald chi-square via
  [`emmeans::joint_tests()`](https://rvlenth.github.io/emmeans/reference/joint_tests.html)
  otherwise) before the coefficients, which are labelled as the
  treatment contrasts they are (“B vs. A of cond, at b = b1”) instead of
  “the effect of condB” – in a model with an interaction that
  coefficient is a simple effect, and a 2x2 example had read
  “significant, p \< .001” where the Type III test gave p = .26. New
  argument `omnibus = TRUE`.
- Odds-ratio and IRR labels follow the link (a probit model printed
  “OR”); thresholds, scale effects and zero-inflation coefficients are
  no longer reported as predictor effects.
- Count outcomes are checked for over-dispersion and fitted as negative
  binomial when needed (Poisson had given p = .037 where the
  negative-binomial model gives p = .43).
  [`classify_outcome()`](https://m-colley.github.io/colleyRstats/reference/classify_outcome.md)
  no longer silently treats bounded scores as counts (raw NASA-TLX in
  steps of 5 is continuous, and every count classification is announced)
  or a two-valued non-0/1 item as binary.
- [`recommend_test()`](https://m-colley.github.io/colleyRstats/reference/recommend_test.md)
  tests normality on the residuals of the model it recommends and
  homogeneity across all design cells; recommends HC3-robust Type III
  ANOVA instead of a one-way Welch test for heteroscedastic factorial
  designs; and only recommends models that can be fitted (no ART with
  covariates, no nparLD without a within factor). A clustered nominal
  outcome is fitted with
  [`mclogit::mblogit()`](https://melff.github.io/mclogit/reference/mblogit.html)
  instead of a `multinom()` that ignored the clustering.
- In a model with a numeric covariate, the omnibus test of a factor is
  taken at the covariate’s mean. Type III tests are independent of how
  factors are coded but not of where the covariate is zero: in
  `y ~ cond * age`, the “main effect of cond” was the effect at age 0 –
  reported as F = 0.11, p = .74 next to post-hoc contrasts with p \<
  .001 for the same effect at the mean age. The tests now equal those of
  the model with the covariate centred, for linear mixed models as for
  GLM(M)s.
- [`fit_recommended()`](https://m-colley.github.io/colleyRstats/reference/fit_recommended.md)
  fits every engine on the same complete cases (ART, nparLD and
  `mblogit` refused data with a missing value), turns a nominal outcome
  stored as text into a factor (`mblogit` refused it), fits nparLD on
  the participants observed in every condition instead of recommending a
  model it then could not fit, writes ART sentences with plain factor
  names (a factor called `B` became the undefined `\B{}`), and handles
  an intercept-only model. ART-C simple effects read their cells from
  the contrast coefficients rather than by splitting labels, so levels
  such as “low - fast” or “b,1” no longer make them fail; the methods
  text describes simple effects only when they were computed, and names
  the correction actually applied (ART-C simple effects fall back from
  Tukey to Holm). The Kruskal-Wallis route runs the Dunn’s test its
  methods sentence names. Declaring a three-valued outcome binary warns
  that the binomial model compares the first value with all the others.
- [`fit_recommended()`](https://m-colley.github.io/colleyRstats/reference/fit_recommended.md)
  uses order-independent Type III sums of squares for unbalanced
  between-subjects factorials (Type I gave F = 2.03 or 0.14 depending on
  predictor order); fits by-participant random slopes when trials repeat
  within a condition, simplifying them when the fit is singular;
  computes post-hoc contrasts per factor, with simple effects only for a
  significant interaction in the model; no longer turns a numeric
  covariate with few values into a factor (new `factors =` argument
  declares categorical predictors); handles column names with spaces;
  records singular and non-converged fits and the function actually
  called; and escapes its LaTeX methods sentence.

#### Questionnaire scoring

- `score_questionnaire(prefix =)` matched columns to items by sort
  order: NASA-TLX Mental Demand was filled from the Effort column, TiA
  and IPQ reversals landed on the wrong items, AttrakDiff PQ and ATT
  swapped, and `SUS_10_1` was read as item 2. Columns are now matched by
  name or by an unambiguous item number running 1..n.

- The scoring message shows the observed response range; NASA-TLX data
  that never exceed 21 (other than the 0-100 sheet’s own steps of 5),
  and responses that fill exactly the assumed range shifted by one point
  (an IPQ exported 1-7, a SUS exported 0-4), draw a warning unless
  `scale` is given. An unused scale end alone does not: nobody choosing
  the top of a 7-point scale is unremarkable in a small sample.

- An item column stored as a factor that mixes numeric and text levels
  (`"0"`-`"3"` plus `"no answer"`) is refused, naming the text levels,
  instead of being scored by level position – which put every SSQ answer
  one point too high and doubled the Total. Blank factor levels are
  missing responses, as blank text cells are.
  [`define_questionnaire()`](https://m-colley.github.io/colleyRstats/reference/define_questionnaire.md)
  refuses a missing subscale.

- `reverse_items` warns when it un-reverses an item the published key
  already reverses (passing `c(2, 4, 6, 8, 10)` for the SUS gave a
  perfect respondent 50); new `unreverse_items` does that on purpose.

- With `min_valid < 1`, missing SUS items count as the centre point, as
  Brooke (1996) instructs; new `impute =` chooses the rule explicitly.

- [`score_reliability()`](https://m-colley.github.io/colleyRstats/reference/score_reliability.md)
  adds a whole-scale row, a Spearman-Brown coefficient for two-item
  scales, and a `note` column; omega comes from an unrotated one-factor
  solution, so it no longer silently returns `NA` without ‘GPArotation’.

- The scaffolded figures follow the design declared in `analysis.R`:
  with `CLUSTER <- NULL`, or a condition that does not vary within
  participants, they are between-subjects plots (`make_figures()` used
  to stop with “`subject` is required”), and repeated trials are
  averaged per participant first. The report draws the same figures by
  reusing the pipeline’s own `plot_outcome()` instead of hard-coding
  column names, and the combined figure grows with the number of
  outcomes instead of failing for a long questionnaire battery.

#### Utilities

- [`rFromWilcox()`](https://m-colley.github.io/colleyRstats/reference/rFromWilcox.md)
  and
  [`rFromNPAV()`](https://m-colley.github.io/colleyRstats/reference/rFromNPAV.md)
  no longer halve one-sided p-values, which overstated r;
  [`rFromNPAV()`](https://m-colley.github.io/colleyRstats/reference/rFromNPAV.md)
  warns for omnibus F tests with more than one numerator df.
- [`remove_outliers_REI()`](https://m-colley.github.io/colleyRstats/reference/remove_outliers_REI.md)
  takes proportions over the items each respondent answered, as
  Tawa (2021) defines the index; matches `variables` by exact name
  rather than as regular expressions; and flags nobody, instead of
  everybody, when all indices are equal.
- [`add_pareto_moocore_column()`](https://m-colley.github.io/colleyRstats/reference/add_pareto_moocore_column.md)
  and
  [`add_pareto_emoa_column()`](https://m-colley.github.io/colleyRstats/reference/add_pareto_emoa_column.md)
  agree on tied points (moocore kept only the first copy); emoa accepts
  integer columns; rows with a missing objective get `NA`.
- [`check_homogeneity_by_group()`](https://m-colley.github.io/colleyRstats/reference/check_homogeneity_by_group.md)
  and the plot wrappers accept column names with spaces and numeric
  condition codes.
  [`debug_contr_error()`](https://m-colley.github.io/colleyRstats/reference/debug_contr_error.md)
  reported unobserved factor levels as real when a character column came
  first.
  [`reshape_data()`](https://m-colley.github.io/colleyRstats/reference/reshape_data.md)
  stacked the columns before the first marker as a data slice.

### LATEX OUTPUT

- Variable names that are already LaTeX commands (`time`, `L`, `small`,
  `value`, …) are written as text instead of `\time` (a compile error),
  `\L` (the letter Ł) or `\small` (a font switch). The list of reserved
  names is generated from TeX itself (`data-raw/latex_reserved.R`). Name
  macros are written as `\Name{}`, so TeX no longer swallows the
  following space (“cylon mpg”).
- [`reportNparLD()`](https://m-colley.github.io/colleyRstats/reference/reportNparLD.md)
  output did not compile (nested math in `\F{..}{$\infty$}{..}`),
  rounded the ATS df to an integer, and promised a relative treatment
  effect that real fits never carry.
  [`reportART()`](https://m-colley.github.io/colleyRstats/reference/reportART.md),
  [`reportNPAV()`](https://m-colley.github.io/colleyRstats/reference/reportNPAV.md)
  and
  [`reportNparLD()`](https://m-colley.github.io/colleyRstats/reference/reportNparLD.md)
  decided “interaction” by searching for a capital X (a main effect `UX`
  became an interaction) and emitted names like `Video_Type` as
  uncompilable macros.
- [`emit_overleaf()`](https://m-colley.github.io/colleyRstats/reference/emit_overleaf.md)
  no longer lets sections overwrite each other (`Q1` and `Q2` both
  became `Q.tex`), checks every path before writing anything, and
  produces a non-empty bibliography (`\nocite{*}`, and
  [`cite_methods()`](https://m-colley.github.io/colleyRstats/reference/cite_methods.md)
  now gives each BibTeX entry a key).
  [`define_result_macro()`](https://m-colley.github.io/colleyRstats/reference/define_result_macro.md)
  spells digits out (`tlx_1` becomes `\tlxOne`), refuses names that
  would redefine a command, and replaces an existing definition instead
  of duplicating it.
  [`cite_methods()`](https://m-colley.github.io/colleyRstats/reference/cite_methods.md)
  cites a method named twice (`c("art", "ART")`) only once.
- [`reportMeanAndSD()`](https://m-colley.github.io/colleyRstats/reference/reportMeanAndSD.md)
  wrote only LaTeX comments, and
  [`latexify_report()`](https://m-colley.github.io/colleyRstats/reference/latexify_report.md)
  left `_ & # ^ < >` unescaped.
- New `\mdn{}` and `\iqr{}` macros in
  [`latex_preamble()`](https://m-colley.github.io/colleyRstats/reference/latex_preamble.md)
  and `colleyRstats.sty`; re-copy the `.sty` into existing Overleaf
  projects with `use_colleyrstats_sty(overwrite = TRUE)`.

### NEW FEATURES

- New questionnaire key `attrakdiff_official`: the AttrakDiff 2 word
  pairs in the order and with the poles of the administered sheet. The
  existing `attrakdiff` key (blocked by dimension, negative pole first)
  is unchanged.
- `showPairwiseComp` and `plotType` work again (ignored since
  ‘ggstatsplot’ 0.12.0); non-parametric figures label medians; two-group
  asterisk brackets use the test shown in the subtitle.
- A factor iteration axis in
  [`generateMoboPlot()`](https://m-colley.github.io/colleyRstats/reference/generateMoboPlot.md)
  /
  [`generateMoboPlot2()`](https://m-colley.github.io/colleyRstats/reference/generateMoboPlot2.md)
  lines up with its phase guides and fitted equation.
  `numberSamplingSteps` counts iteration steps from the first iteration,
  so an iteration missing from the log no longer moves the sampling
  boundary, and a value covering every iteration warns instead of
  stopping.

### DEPRECATIONS

- [`rFromWilcoxAdjusted()`](https://m-colley.github.io/colleyRstats/reference/rFromWilcoxAdjusted.md)
  is deprecated: inflating p by the number of comparisons shrank r (0.34
  to 0.21 with six comparisons) although the effect was unchanged.
  Effect sizes are not multiplicity-adjusted; use
  [`rFromWilcox()`](https://m-colley.github.io/colleyRstats/reference/rFromWilcox.md).
- `generateEffectPlot(numberColors =)` is deprecated; it was never used.

### PACKAGING

- Removed ten suggested packages that nothing used, and the unused
  `roxyglobals` configuration. Added ‘callr’, ‘MASS’, ‘mclogit’,
  ‘performance’ and ‘WRS2’ to Suggests.
- CI also checks on the previous R release. The spell-check workflow
  passes again.

## colleyRstats 0.2.1

### NEW FEATURES

- [`reportggstatsplotPostHoc()`](https://m-colley.github.io/colleyRstats/reference/reportggstatsplotPostHoc.md)
  names the post-hoc test it is reporting, and the multiplicity
  correction that produced the p-value: “A Games-Howell post-hoc test
  (Holm-adjusted) found that …”. Both are read from the pairwise table
  ‘ggstatsplot’ attaches to the plot rather than assumed, because which
  test ran is not something a reader can infer from the call: `type` and
  the between/within distinction select between Games-Howell, Dunn,
  Durbin-Conover, Student’s t and Yuen’s trimmed means, and
  ‘ggstatsplot’ may change its defaults between releases. A sentence
  that says only “A post-hoc test found that …” is therefore not
  reproducible, and the methods section it lands in cannot be written
  from it ([\#31](https://github.com/M-Colley/colleyRstats/issues/31)).
- The same naming reaches the branch where nothing is significant, which
  previously reported “A post-hoc test found no significant differences”
  whatever had been run.
- Where the plot reports `p.adjust.method = "None"`, the p-values are
  uncorrected and are now emitted with `\p{}` / `\pminor{}` instead of
  `\padj{}` / `\padjminor{}`. Labelling a raw p-value $`p_{adj}`$ claims
  a correction that was never applied. Both macros are already part of
  [`latex_preamble()`](https://m-colley.github.io/colleyRstats/reference/latex_preamble.md)
  and the shipped `colleyRstats.sty`, so no preamble changes are needed.
  A plot whose table carries no `p.adjust.method` column says nothing
  either way and keeps the `\padj{}` macros it has always used.

### BUG FIXES

- [`reportggstatsplot()`](https://m-colley.github.io/colleyRstats/reference/reportggstatsplot.md)
  opened a Welch ANOVA sentence with “An One-way analysis of means …”.
  The article was chosen from the first letter of the method name, and
  “One” is a vowel letter read as a consonant (“wun”). It is now chosen
  from how the name is spoken, which also covers the “yoo” openings (“a
  unique …”, “a European …”). The “un-” prefix is deliberately
  untouched, so “an unpaired Wilcoxon rank sum test” is unchanged.

### DOCUMENTATION

- Six terms used in the 0.2.0 changelog – a statistician’s name, a
  package name, a file extension and the package’s usual British
  spelling – were added to `inst/WORDLIST`, so the spell-check workflow
  passes again.

## colleyRstats 0.2.0

CRAN release: 2026-09-02

### NEW FEATURES

#### Questionnaire scoring

- New
  [`score_questionnaire()`](https://m-colley.github.io/colleyRstats/reference/score_questionnaire.md)
  applies a published instrument’s own scoring key to raw item columns:
  reverse-coding, the recoding it prescribes (centring a semantic
  differential to -3..+3, zero-basing the SUS), its subscale structure,
  and its published weights or multipliers. Ten instruments ship:
  **NASA-TLX** (raw/RTLX), **SUS** with the Lewis & Sauro
  usability/learnability subscales, **UEQ-S**, the full 26-item **UEQ**,
  **TiA** (Körber), **AttrakDiff 2**, **IPQ**, **SSQ** (with the Kennedy
  et al. weights and its overlapping subscales), **FMS** and **MISC**.
  The scoring is checked against published reference values in the test
  suite: the SUS anchors (100/0/50), the SSQ weighting (21 raw on each
  subscale gives 200.34/159.18/292.32, total 235.62), the TLX rescale
  from any sheet onto 0-100, and the UEQ’s balanced polarity, where
  answering the positive pole of all 26 pairs must give +3 on all six
  scales.
- `scale =` declares the response range a survey actually used, so a
  21-point TLX sheet, a 20-point slider and a 0-100 slider all score
  onto the conventional 0-100. Responses outside the declared range are
  an error, not a silent rescale.
- `min_valid =` governs incomplete responses. The default scores only
  complete subscales and returns `NA` otherwise – no silent imputation.
  Relaxing it scales a sum-scored instrument up proportionally so it
  stays on its published range.
- A standing **caution prints in the console**, not only in the help
  pages: item numbers, order and polarity depend on how a questionnaire
  was administered, this package applies the *published* key, and a
  mismatch produces plausible numbers rather than an error – so any
  figure must be double-checked before it goes into a paper. It appears
  from
  [`score_questionnaire()`](https://m-colley.github.io/colleyRstats/reference/score_questionnaire.md)
  (once per distinct mapping per session, alongside the mapping itself),
  and from
  [`check_questionnaire()`](https://m-colley.github.io/colleyRstats/reference/check_questionnaire.md),
  [`questionnaire_items()`](https://m-colley.github.io/colleyRstats/reference/questionnaire_items.md)
  and
  [`score_reliability()`](https://m-colley.github.io/colleyRstats/reference/score_reliability.md)
  every time. The wording lives in one place, so the console text and
  the help pages cannot drift apart. Silence the repeated note in a
  pipeline with `options(colleyRstats.quiet_questionnaires = TRUE)`;
  that quiets the note, not the errors.
- New
  [`check_questionnaire()`](https://m-colley.github.io/colleyRstats/reference/check_questionnaire.md)
  prints the mapping that will be used – which column supplies which
  item, its subscale, whether it is reverse-coded, and the observed
  range of each column – along with the instrument’s scoring notes. This
  is the guard against the failure mode that motivates the whole
  feature: item order and polarity belong to the sheet a study actually
  administered, so a shifted or re-ordered survey export scores
  silently, plausibly, and wrongly.
  [`score_questionnaire()`](https://m-colley.github.io/colleyRstats/reference/score_questionnaire.md)
  also attaches the mapping as an attribute and announces it once per
  session.
- New
  [`score_reliability()`](https://m-colley.github.io/colleyRstats/reference/score_reliability.md)
  gives Cronbach’s alpha (and McDonald’s omega where ‘psych’ is
  installed) per subscale, computed on the same recoded matrix that is
  aggregated – so a negative alpha means a real problem rather than a
  forgotten reversal, and it warns when one appears.
- New
  [`define_questionnaire()`](https://m-colley.github.io/colleyRstats/reference/define_questionnaire.md)
  registers a lab-specific, translated or shortened instrument, which
  then behaves exactly like a built-in one. Put it in a project’s setup
  script and every analysis in that project scores it identically.
- New `reverse_code(x, min, max)` flips a response scale using the
  *possible* range rather than the observed one, and warns about
  out-of-range values. Taking the endpoints from the data is the classic
  reverse-coding bug: if nobody picked the lowest option, every flipped
  response is off by a point.
- New
  [`summarize_sickness()`](https://m-colley.github.io/colleyRstats/reference/summarize_sickness.md)
  reduces a repeated single-item sickness rating (FMS, MISC) to the
  measures those studies actually analyse: peak, mean, final value,
  trapezoidal area under the curve, the time-weighted mean, and time to
  a threshold.
- New
  [`list_questionnaires()`](https://m-colley.github.io/colleyRstats/reference/list_questionnaires.md)
  and
  [`questionnaire_items()`](https://m-colley.github.io/colleyRstats/reference/questionnaire_items.md)
  describe the registry and one instrument’s items.

#### Fitting the recommended model

- New
  [`fit_recommended()`](https://m-colley.github.io/colleyRstats/reference/fit_recommended.md)
  carries
  [`recommend_test()`](https://m-colley.github.io/colleyRstats/reference/recommend_test.md)
  through to a fitted model. It coerces the outcome and predictors into
  the classes the model family needs (announcing each coercion, since
  turning a numeric rating into an ordered factor changes what is
  estimated), builds the random-effect term for a clustered design,
  fits, computes pairwise post-hoc contrasts with the machinery that
  matches the fit, and produces the manuscript sentence via this
  package’s reporter for that family. It covers cumulative link models
  with and without random effects, linear and generalized linear mixed
  models, GLMs, the aligned rank transform, nparLD, multinomial
  regression, and the classical ANOVA / Welch / Kruskal-Wallis /
  Wilcoxon tests.
- The point is that the test justified in the methods section and the
  model actually run come from one call on one data frame, so they
  cannot drift apart – the failure mode of a workflow where
  [`recommend_test()`](https://m-colley.github.io/colleyRstats/reference/recommend_test.md)
  prints advice that is then re-typed by hand.
- `outcome_type =` overrides the automatic classification. This matters
  more than it sounds: an outcome whose scores stay whole numbers is
  taken for a count and fitted with a Poisson model. That catches the
  six raw NASA-TLX subscales, a single MISC rating, and item-level
  ratings; SUS and RTLX escape it only because their multipliers and
  means make them fractional.

#### Pareto fronts in the direction you actually optimise

- [`add_pareto_moocore_column()`](https://m-colley.github.io/colleyRstats/reference/add_pareto_moocore_column.md)
  and
  [`add_pareto_emoa_column()`](https://m-colley.github.io/colleyRstats/reference/add_pareto_emoa_column.md)
  gain `maximise`. Both minimised unconditionally:
  [`moocore::is_nondominated()`](https://multi-objective.github.io/moocore/r/reference/nondominated.html)
  was called with its `maximise = FALSE` default and
  [`emoa::is_dominated()`](https://rdrr.io/pkg/emoa/man/dom_op.html) has
  no direction argument at all. Since trust, acceptance, perceived
  safety and most other rating-scale objectives are *maximised*, using
  them meant passing negated copies of your own columns and remembering
  to negate them everywhere else too. Pass `maximise = TRUE`, or a
  logical vector with one entry per objective for a mixed problem
  (`c(TRUE, TRUE, FALSE)` to maximise two and minimise a workload
  score). The default stays `FALSE`, so existing results are unchanged.
- The length of `maximise` is validated.
  [`moocore::is_nondominated()`](https://multi-objective.github.io/moocore/r/reference/nondominated.html)
  accepts three flags for two objectives and quietly uses the first two,
  which would produce a plausible, wrong front; passing the wrong number
  here is an error naming the objectives instead.
- A test asserts the two backends agree on the same front under every
  direction setting, and that `maximise = TRUE` matches the
  negate-your-columns workaround it replaces.

#### Starting a study

- New
  [`use_study_project()`](https://m-colley.github.io/colleyRstats/reference/use_study_project.md)
  scaffolds a study analysis as a reproducible pipeline: a ‘targets’
  pipeline that recomputes only what changed, R scripts split along the
  stages every user study goes through (read, clean, score, model,
  plot), a Quarto report, a directory the generated LaTeX lands in so a
  manuscript `\input{}`s the numbers instead of having them re-typed,
  `renv` for version pinning, and a `.gitignore` that keeps generated
  output out of the repository.
- It ships synthetic example data with a column per item of every
  instrument named, so a freshly scaffolded project runs end to end
  before any real data exists. The generated `OUTCOMES` and
  `OUTCOME_TYPES` vectors are derived by scoring a dummy row through the
  real code path, so the scaffold cannot name a column that
  [`score_questionnaire()`](https://m-colley.github.io/colleyRstats/reference/score_questionnaire.md)
  does not produce.
- It never overwrites an existing file unless asked, so it can be re-run
  on a live project to pick up new pieces.

### BUG FIXES

- [`reportggstatsplot()`](https://m-colley.github.io/colleyRstats/reference/reportggstatsplot.md)
  named every effect size `r`. Each branch pasted a literal `, r=`, but
  only the rank-based tests actually produce an *r*: a t-test yields
  Hedges’ g, an ANOVA Omega2, a Friedman test Kendall’s W, a
  Kruskal-Wallis Epsilon2 (rank). The sentence therefore put a wrong
  statistic name in the manuscript, and for the standardised mean
  differences an impossible one – a paired t-test on 16 pairs emitted
  `r=-1.38`, a correlation outside the range *r* can take. The reporter
  now reads the effect-size name that statsExpressions supplies in the
  `effectsize` column of
  [`extract_stats()`](https://www.indrapatil.com/ggstatsplot/reference/extract_stats.html)
  and renders the matching symbol ($`g_{Hedges}`$, $`d_{Cohen}`$,
  $`\eta_{p}^{2}`$, $`\omega_{p}^{2}`$, $`\epsilon_{ordinal}^{2}`$,
  $`W_{Kendall}`$, $`V_{Cramer}`$), keeping the existing
  `\rankbiserial{}` macro where the effect size really is a
  rank-biserial correlation, so this reporter and
  [`reportArtCon()`](https://m-colley.github.io/colleyRstats/reference/reportArtCon.md)
  stay consistent and no LaTeX preamble changes. Names it does not
  recognise – the robust tests return long descriptive ones – are
  printed verbatim rather than guessed at. **Any .tex generated by this
  function before 0.2.0 needs its effect-size label checked.**

- The same values were formatted with the internal bounded-statistic
  formatter, which drops the leading zero under
  `options(colleyRstats.leading_zero = FALSE)`. That is APA-correct only
  for statistics bounded within \[-1, 1\]. Hedges’ g and Cohen’s d are
  unbounded and now keep their leading zero.

- [`save_paper_figure()`](https://m-colley.github.io/colleyRstats/reference/save_paper_figure.md)
  resized only the last panel of a multi-panel figure. It applied the
  type size with `plot + .resize_theme(base_size)`, and on a
  **patchwork** object `+` modifies the last plot only – so a
  seven-panel grid came out with six panels at whatever size they were
  built with and one at the figure size, which reads as a single
  oversized panel. Resizing now dispatches on the object: `&` for a
  patchwork, so it reaches every panel, `+` for a single plot as before.
  A test asserts every panel of a grid ends up at one size. \##
  DOCUMENTATION

- New
  [`vignette("scoring-questionnaires")`](https://m-colley.github.io/colleyRstats/articles/scoring-questionnaires.md)
  covers the scoring key, verifying a mapping before trusting it,
  incomplete responses, reliability, registering your own instrument,
  and the sickness time course.

- The `pkgdown` reference index gains **Questionnaires** and **Starting
  a study** sections.

## colleyRstats 0.1.6

CRAN release: 2026-08-25

### BUG FIXES

- [`reportNparLD()`](https://m-colley.github.io/colleyRstats/reference/reportNparLD.md)
  announced “no significant effects” for every model fitted with
  ‘nparLD’ 2.3.0, however strong the effect actually was. That release
  rewrote the object
  [`nparLD::nparLD()`](https://rdrr.io/pkg/nparLD/man/nparLD.html)
  returns: it now has class `nparld_fit` and carries the ANOVA-type
  statistic in `$ATS`, where earlier versions used `$ANOVA.test`. Asking
  for the old name yielded `NULL`, and `as.data.frame(NULL)` is a table
  with no rows – which the code that followed could not tell apart from
  a table in which nothing crossed p \< .05. A toy fit with ATS = 92.8
  and p \< 1e-10 was reported as effect-free. Both layouts are now
  recognised, and an object carrying neither raises an error instead of
  silently reporting nothing.
- The example on
  [`?reportNparLD`](https://m-colley.github.io/colleyRstats/reference/reportNparLD.md)
  passed `description = FALSE` to
  [`nparLD::nparLD()`](https://rdrr.io/pkg/nparLD/man/nparLD.html).
  ‘nparLD’ 2.3.0 dropped that argument, so `R CMD check --run-donttest`
  failed on CRAN with `unused argument (description = FALSE)`. The call
  now uses only arguments both versions accept, and the toy data carries
  a trend over time so the example demonstrates a reported sentence
  rather than the no-effect message.

### NEW FEATURES

- New
  [`animate_mobo2()`](https://m-colley.github.io/colleyRstats/reference/animate_mobo2.md),
  the video counterpart of
  [`generateMoboPlot2()`](https://m-colley.github.io/colleyRstats/reference/generateMoboPlot2.md).
  It draws one frame per iteration and encodes them with `av`, so an
  optimisation run can be shown building up rather than only in its
  finished state; the file extension picks the container (`.mp4`,
  `.gif`, `.mov`, …). The plot is built once from the complete data and
  each frame only hides rows, which is what keeps the axes, the
  sampling/optimisation guides and the legend still while the points,
  intervals, fitted line and its equation move. It is also the only way
  the early frames can be drawn:
  [`generateMoboPlot2()`](https://m-colley.github.io/colleyRstats/reference/generateMoboPlot2.md)
  requires both phases to be present, and the first iterations are all
  sampling. `av` is a `Suggests`, so nothing changes for installations
  that do not want it.

## colleyRstats 0.1.5

CRAN release: 2026-08-19

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
