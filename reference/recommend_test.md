# Recommend a principled analysis for one outcome

Works out, from the data alone, which statistical model is appropriate
for a given outcome and set of predictors, and – crucially – *why*. The
decision follows a transparent three-question tree:

1.  **What is the outcome's measurement scale?** (via
    [`classify_outcome()`](https://m-colley.github.io/colleyRstats/reference/classify_outcome.md):
    continuous, ordinal, binary, count, nominal.) This fixes the model
    family.

2.  **Are the observations independent or clustered?** A
    repeated-measures / clustered design (a `cluster` id is supplied, or
    `design = "within"`) needs random effects, i.e. a *mixed* model.

3.  **For a continuous outcome, do the parametric assumptions hold?**
    Group-wise normality (Shapiro–Wilk) and, for between-subjects
    designs, homogeneity of variance (Levene) decide between a
    parametric test and a non-parametric / rank-based alternative.

## Usage

``` r
recommend_test(
  data,
  outcome,
  predictors = NULL,
  cluster = NULL,
  design = c("auto", "between", "within"),
  outcome_type = c("auto", "continuous", "ordinal", "binary", "count", "nominal"),
  ordinal_max_levels = 7L
)

recommend_analysis(
  data,
  outcome,
  predictors = NULL,
  cluster = NULL,
  design = c("auto", "between", "within"),
  outcome_type = c("auto", "continuous", "ordinal", "binary", "count", "nominal"),
  ordinal_max_levels = 7L
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

  One of `"auto"` (default; clustered when `cluster` is given),
  `"between"`, or `"within"`.

- outcome_type:

  One of `"auto"` (default; use
  [`classify_outcome()`](https://m-colley.github.io/colleyRstats/reference/classify_outcome.md))
  or an explicit `"continuous"`, `"ordinal"`, `"binary"`, `"count"`,
  `"nominal"` to override the automatic classification.

- ordinal_max_levels:

  Passed to
  [`classify_outcome()`](https://m-colley.github.io/colleyRstats/reference/classify_outcome.md).
  Default 7.

## Value

An object of class `"colley_recommendation"` (a list) with components
including `outcome_type`, `clustered`, `family`, `recommendation`
(human-readable label), `model_function` (the R function to call, e.g.
`"ordinal::clmm"`), `reporter` (the matching colleyRstats reporter),
`fit_call` (a ready-to-edit call as a string), `alternatives`,
`rationale`, and `methods_text` (an APA-style sentence). A `print`
method summarises it.

## Details

The recommendation therefore ranges over ordinary ANOVA / t-tests,
rank-based methods (Kruskal–Wallis + Dunn, Wilcoxon, the Aligned Rank
Transform, nparLD), generalized linear models, cumulative link models,
and their mixed-model counterparts – linear mixed models (LMM),
generalized linear mixed models (GLMM, `lme4`/`glmmTMB`) and cumulative
link mixed models (CLMM, `ordinal`).

## Naming

`recommend_test()` is the canonical name. `recommend_analysis()` is an
alias for the same function object, kept for backward compatibility.

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
#>   Predictors     : cond
#>   Design         : within (cluster: id)
#>   Recommendation : Cumulative Link Mixed Model (CLMM)
#>   Family         : cumulative link (logit)
#>   Fit with       : ordinal::clmm(rating ~ cond + (1 | id), data = your_data)  # outcome must be an ordered factor
#>   Report with    : reportCLMM()
#>   Alternative(s) : nparLD (rank-based repeated measures) if proportional odds is untenable
#>   Rationale      : the outcome is ordinal and the observations are clustered, so an ordinal (proportional-odds) model with a random effect is appropriate
# Continuous, between-subjects -> ANOVA or its rank-based fallback
recommend_test(d, outcome = "score", predictors = "cond")
#> <colleyRstats analysis recommendation>
#>   Outcome        : score (continuous)
#>   Predictors     : cond
#>   Design         : between
#>   Normality      : not rejected
#>   Homogeneity    : not rejected
#>   Recommendation : One-way ANOVA (parametric)
#>   Family         : gaussian
#>   Fit with       : ggbetweenstatsWithPriorNormalityCheck(data = your_data, x = "cond", y = "score")
#>   Report with    : reportggstatsplot()
#>   Alternative(s) : none needed
#>   Rationale      : the outcome is continuous and normally distributed with homogeneous variances, so a parametric ANOVA is appropriate
```
