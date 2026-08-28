# Fit the model that the data call for, and report it

Runs
[`recommend_test()`](https://m-colley.github.io/colleyRstats/reference/recommend_test.md)
to choose an analysis, then actually fits it: coerces the outcome and
predictors into the classes that model family needs, builds the
random-effect term for a repeated-measures design, fits, computes
pairwise post-hoc contrasts with the matching machinery, and produces
the APA/LaTeX sentence via this package's reporter for that model
family.

## Usage

``` r
fit_recommended(
  data,
  outcome,
  predictors = NULL,
  cluster = NULL,
  design = c("auto", "between", "within"),
  outcome_type = c("auto", "continuous", "ordinal", "binary", "count", "nominal"),
  ordinal_max_levels = 7L,
  interaction = TRUE,
  contrasts = TRUE,
  adjust = "holm",
  sink_to = NULL,
  verbose = TRUE
)
```

## Arguments

- data:

  The data frame.

- outcome:

  The dependent variable (column name as string).

- predictors:

  Character vector of independent variable column names.

- cluster:

  Optional column identifying the subject or cluster for
  repeated-measures data – the random-effect grouping factor.

- design:

  One of `"auto"` (default; clustered when `cluster` is given),
  `"between"`, or `"within"`.

- outcome_type:

  `"auto"` (default; use
  [`classify_outcome()`](https://m-colley.github.io/colleyRstats/reference/classify_outcome.md))
  or an explicit `"continuous"`, `"ordinal"`, `"binary"`, `"count"`,
  `"nominal"` to override the classification. Pass it when the automatic
  choice is wrong – a 1-7 Likert item and a small count are genuinely
  ambiguous from the data alone.

- ordinal_max_levels:

  Passed to
  [`classify_outcome()`](https://m-colley.github.io/colleyRstats/reference/classify_outcome.md).
  Default 7.

- interaction:

  Logical. With more than one predictor, fit the full factorial model
  (`TRUE`, default) or main effects only (`FALSE`).

- contrasts:

  Logical. Compute pairwise post-hoc contrasts between the levels of the
  grouping predictors. Default `TRUE`.

- adjust:

  Multiplicity adjustment for those contrasts, passed to emmeans or
  ARTool. Default `"holm"`.

- sink_to:

  Optional path of a `.tex` file; the methods sentence and the result
  sentence are written there so a manuscript can `\input{}` them.

- verbose:

  Logical. If `TRUE` (default), report every coercion and the model
  being fitted.

## Value

An object of class `"colley_fit"`: a list with `recommendation` (the
[`recommend_test()`](https://m-colley.github.io/colleyRstats/reference/recommend_test.md)
object), `model` (the fitted object), `engine`, `emmeans` and
`contrasts` (or `NULL`), `methods` and `text` (manuscript sentences),
and `sentences` (both, in manuscript order). A `print` method summarises
it.

## Details

The point is that the test you justify in the methods section and the
model you actually ran are produced by the same call, from the same
data, and therefore cannot drift apart – the failure mode of a pipeline
where
[`recommend_test()`](https://m-colley.github.io/colleyRstats/reference/recommend_test.md)
prints advice that someone then re-types by hand.

## What it can fit

Cumulative link models with and without random effects (ordinal),
generalized and linear mixed models (lme4, lmerTest), GLMs, the aligned
rank transform (ARTool), rank-based repeated measures (nparLD),
multinomial regression (nnet), and the classical ANOVA / Welch /
Kruskal-Wallis / Wilcoxon tests. Model packages live in `Suggests`: a
branch you use needs its package installed, and says which one if it is
not.

## See also

[`recommend_test()`](https://m-colley.github.io/colleyRstats/reference/recommend_test.md)
for the choice alone,
[`analyze_and_report()`](https://m-colley.github.io/colleyRstats/reference/analyze_and_report.md)
for the figure-plus-sentence path through ggstatsplot.

## Examples

``` r
# \donttest{
set.seed(1)
d <- data.frame(
  id = factor(rep(1:20, each = 3)),
  cond = factor(rep(c("A", "B", "C"), times = 20)),
  score = rnorm(60)
)
if (requireNamespace("lme4", quietly = TRUE)) {
  fit <- fit_recommended(d, outcome = "score", predictors = "cond", cluster = "id")
  fit
}
#> Registered S3 method overwritten by 'lme4':
#>   method           from
#>   na.action.merMod car 
#> Fitting: Linear Mixed Model (LMM) / parametric within-subjects via lme4::lmer().
#> boundary (singular) fit: see help('isSingular')
#> <colleyRstats fitted analysis>
#>   Outcome     : score (continuous)
#>   Model       : Linear Mixed Model (LMM) / parametric within-subjects [lmer]
#>   Contrasts   : available in $contrasts
#>   Reported as :
#>     A linear mixed model was fitted for score.
#>     The effect of \textit{condB} on score was not significant ($b = 0.05$, 95\% CI $[-0.49, 0.60]$, $t(55) = 0.20$, \p{0.843}).
#>     The effect of \textit{condC} on score was not significant ($b = -0.12$, 95\% CI $[-0.67, 0.43]$, $t(55) = -0.42$, \p{0.673}).
#> 
#> Linear mixed model fit by REML. t-tests use Satterthwaite's method [
#> lmerModLmerTest]
#> Formula: fml
#>    Data: data
#> 
#> REML criterion at convergence: 154.5
#> 
#> Scaled residuals: 
#>      Min       1Q   Median       3Q      Max 
#> -2.76544 -0.52581 -0.06196  0.65191  2.07343 
#> 
#> Random effects:
#>  Groups   Name        Variance Std.Dev.
#>  id       (Intercept) 0.0000   0.000   
#>  Residual             0.7516   0.867   
#> Number of obs: 60, groups:  id, 20
#> 
#> Fixed effects:
#>             Estimate Std. Error       df t value Pr(>|t|)
#> (Intercept)  0.12824    0.19386 57.00000   0.662    0.511
#> condB        0.05458    0.27416 57.00000   0.199    0.843
#> condC       -0.11646    0.27416 57.00000  -0.425    0.673
#> 
#> Correlation of Fixed Effects:
#>       (Intr) condB 
#> condB -0.707       
#> condC -0.707  0.500
#> optimizer (nloptwrap) convergence code: 0 (OK)
#> boundary (singular) fit: see help('isSingular')
#> 
# }
```
