# Recommend a principled analysis for one outcome

Works out, from the data alone, which statistical model is appropriate
for a given outcome and set of predictors, and – crucially – *why*. The
decision follows a transparent three-question tree:

1.  **What is the outcome's measurement scale?** (via
    [`classify_outcome()`](https://m-colley.github.io/colleyRstats/reference/classify_outcome.md):
    continuous, ordinal, binary, count, nominal.) This fixes the model
    family. A count is checked for over-dispersion
    ([`performance::check_overdispersion()`](https://easystats.github.io/performance/reference/check_overdispersion.html),
    Pearson \\\chi^2\\/df); an over-dispersed count is modelled as
    negative binomial (`glmmTMB::glmmTMB(family = nbinom2)` when
    clustered,
    [`MASS::glm.nb()`](https://rdrr.io/pkg/MASS/man/glm.nb.html)
    otherwise).

2.  **Are the observations independent or clustered?** A `cluster`
    column in which some cluster contributes several rows makes the
    design clustered, whatever `design` says: the cluster then needs a
    random effect, i.e. a *mixed* model. For a categorical predictor
    that varies within clusters and whose levels are replicated within a
    cluster, by-cluster random slopes are added (Barr et al., 2013);
    [`fit_recommended()`](https://m-colley.github.io/colleyRstats/reference/fit_recommended.md)
    simplifies the structure when the fit is singular.

3.  **For a continuous outcome, do the parametric assumptions hold?** A
    Shapiro–Wilk test on the residuals of the model that would be fitted
    (all predictors, their interactions and the random effects) and, for
    between-subjects designs, a Brown–Forsythe test (Levene's test
    centred on the median) across all design cells decide between a
    parametric model and a rank-based alternative.

## Usage

``` r
recommend_test(
  data,
  outcome,
  predictors = NULL,
  cluster = NULL,
  design = c("auto", "between", "within"),
  outcome_type = c("auto", "continuous", "ordinal", "binary", "count", "nominal"),
  ordinal_max_levels = 7L,
  factors = NULL
)

recommend_analysis(
  data,
  outcome,
  predictors = NULL,
  cluster = NULL,
  design = c("auto", "between", "within"),
  outcome_type = c("auto", "continuous", "ordinal", "binary", "count", "nominal"),
  ordinal_max_levels = 7L,
  factors = NULL
)
```

## Arguments

- data:

  The data frame.

- outcome:

  The dependent variable (column name as string).

- predictors:

  Optional character vector of predictor (independent variable) column
  names.

- cluster:

  Optional column name identifying the subject/cluster for
  repeated-measures or otherwise non-independent data (the random-effect
  grouping factor).

- design:

  One of `"auto"` (default; clustered when some `cluster` has several
  rows), `"between"`, or `"within"`. Repeated rows per cluster are
  modelled with a random effect even with `"between"` – ignoring them
  would be pseudo-replication.

- outcome_type:

  One of `"auto"` (default; use
  [`classify_outcome()`](https://m-colley.github.io/colleyRstats/reference/classify_outcome.md))
  or an explicit `"continuous"`, `"ordinal"`, `"binary"`, `"count"`,
  `"nominal"` to override the automatic classification.

- ordinal_max_levels:

  Passed to
  [`classify_outcome()`](https://m-colley.github.io/colleyRstats/reference/classify_outcome.md).
  Default 7.

- factors:

  Optional character vector naming the numeric predictors that are
  categorical (condition codes). `NULL` (default) decides from the data:
  a numeric predictor is categorical only when it looks like codes – at
  most 10 consecutive whole numbers starting at 0 or 1, each observed at
  least twice (and for at least two clusters). Factor, character and
  logical predictors are always categorical; `factors = character(0)`
  keeps every numeric predictor numeric.

## Value

An object of class `"colley_recommendation"` (a list) with components
including `outcome_type`, `clustered`, `design` (`"between"`,
`"within"`, `"mixed"`, or `"between (clustered)"` for between-cluster
predictors with repeated rows per cluster), `n_obs` (complete rows),
`categorical` (which predictors are categorical), `within` (which
categorical predictors vary within clusters), `random` (the
random-effect structure), `family`, `assumptions` (normality and
homogeneity results with their test statistics), `dispersion` (for
counts), `recommendation` (human-readable label), `model_function` (the
R function to call, e.g. `"ordinal::clmm"`), `reporter` (the matching
colleyRstats reporter), `fit_call` (a ready-to-edit call as a string),
`alternatives`, `rationale`, `methods_text` (an APA-style sentence) and
`methods_tex` (the same, escaped for LaTeX). A `print` method summarises
it.

## Details

The recommendation ranges over ordinary ANOVA (Type III sums of squares
for factorial designs, via afex), heteroscedasticity-robust (HC3) ANOVA,
Welch tests, rank-based methods (Kruskal–Wallis + Dunn, Wilcoxon, the
Aligned Rank Transform, nparLD), generalized linear models, cumulative
link models, multinomial models, and their mixed-model counterparts –
linear mixed models (LMM), generalized linear mixed models (GLMM,
`lme4`/`glmmTMB`), cumulative link mixed models (CLMM, `ordinal`) and
multinomial mixed models
([`mclogit::mblogit`](https://melff.github.io/mclogit/reference/mblogit.html)).
Only models that can actually be fitted to the design are recommended:
continuous covariates take the (mixed) regression route, because ART and
nparLD accept only categorical predictors; ART is used only for
all-factor full-factorial models; nparLD only for a single
within-subject factor.

## Naming

`recommend_test()` is the canonical name. `recommend_analysis()` is an
alias for the same function object, kept for backward compatibility.

## References

Barr, D. J., Levy, R., Scheepers, C., & Tily, H. J. (2013). Random
effects structure for confirmatory hypothesis testing: Keep it maximal.
*Journal of Memory and Language, 68*(3), 255–278.

## Examples

``` r
set.seed(1)
d <- data.frame(
  id    = factor(rep(1:20, each = 3)),
  cond  = factor(rep(c("A", "B", "C"), times = 20)),
  score = rnorm(60),
  rating = factor(sample(1:5, 60, TRUE), ordered = TRUE)
)
# Ordinal outcome measured repeatedly within subject -> CLMM
recommend_test(d, outcome = "rating", predictors = "cond", cluster = "id")
#> <colleyRstats analysis recommendation>
#>   Outcome        : rating (ordinal)
#>   Predictors     : cond (categorical, within)
#>   Design         : within (cluster: id)
#>   Random effects : (1 | id)
#>   Recommendation : Cumulative Link Mixed Model (CLMM)
#>   Family         : cumulative link (logit)
#>   Fit with       : ordinal::clmm(rating ~ cond + (1 | id), data = your_data)  # outcome must be an ordered factor
#>   Report with    : reportCLMM()
#>   Alternative(s) : nparLD (rank-based repeated measures) if proportional odds is untenable
#>   Rationale      : the outcome is ordinal and the observations are clustered, so an ordinal (proportional-odds) model with random effects is appropriate
# Continuous, between-subjects -> ANOVA or its rank-based fallback
recommend_test(d, outcome = "score", predictors = "cond")
#> <colleyRstats analysis recommendation>
#>   Outcome        : score (continuous)
#>   Predictors     : cond (categorical)
#>   Design         : between
#>   Normality      : not rejected (residuals)
#>   Homogeneity    : not rejected (Brown-Forsythe, all cells)
#>   Recommendation : One-way ANOVA (parametric)
#>   Family         : gaussian
#>   Fit with       : stats::aov(score ~ cond, data = your_data)
#>   Alternative(s) : ggbetweenstatsWithPriorNormalityCheck() for the figure with the omnibus test
#>   Rationale      : the outcome is continuous, its residuals are approximately normal and the variances are homogeneous across the design cells, so a parametric ANOVA is appropriate
```
