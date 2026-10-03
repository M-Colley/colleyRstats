# Fit the model that the data call for, and report it

Runs
[`recommend_test()`](https://m-colley.github.io/colleyRstats/reference/recommend_test.md)
to choose an analysis, then actually fits it: coerces the outcome and
predictors into the classes that model family needs, builds the
random-effect structure for a repeated-measures design, fits, computes
post-hoc contrasts with the matching machinery, and produces the
APA/LaTeX sentence via this package's reporter for that model family.

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
  verbose = TRUE,
  factors = NULL
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

  One of `"auto"` (default; clustered when some `cluster` has several
  rows), `"between"`, or `"within"`.

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
  (`TRUE`, default) or main effects only (`FALSE`). The aligned rank
  transform always needs the full model, so `FALSE` is refused on that
  route.

- contrasts:

  Logical. Compute post-hoc contrasts between the levels of the
  categorical predictors. Default `TRUE`.

- adjust:

  Multiplicity adjustment for those contrasts, passed to emmeans or
  ARTool. Default `"holm"`.

- sink_to:

  Optional path of a `.tex` file; the methods sentence and the result
  sentence are written there (LaTeX-escaped) so a manuscript can
  `\input{}` them.

- verbose:

  Logical. If `TRUE` (default), report every coercion, the model being
  fitted, and every simplification of the random effects.

- factors:

  Optional character vector naming the numeric predictors that are
  categorical (condition codes); see
  [`recommend_test()`](https://m-colley.github.io/colleyRstats/reference/recommend_test.md).
  `NULL` (default) decides from the data, and every resulting coercion
  is announced.

## Value

An object of class `"colley_fit"`: a list with `recommendation` (the
[`recommend_test()`](https://m-colley.github.io/colleyRstats/reference/recommend_test.md)
object, updated to record the function, call and random effects actually
used), `formula`, `model` (the fitted object), `engine`,
`model_function` (the function actually called, e.g.
`"lmerTest::lmer"`), `random` (the random-effects term kept), `singular`
and `converged` (flags), `anova` (the omnibus table: term, df1, df2,
statistic, stat_name, p), `emmeans` (a named list of the estimated
marginal means grids) and `contrasts` (a data frame with one row per
comparison: `term`, `by`, `contrast`, `estimate`, `scale`, `SE`, `df`,
confidence limits, `statistic`, `p.value`, `adjust`; or `NULL`),
`methods` (plain text), `methods_tex` (LaTeX-escaped), `text` (result
sentences, LaTeX), and `sentences` (`methods_tex` and `text`, in
manuscript order – what `sink_to` writes). A `print` method summarises
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
generalized and linear mixed models (lme4, lmerTest, glmmTMB for
negative-binomial counts), Poisson, negative-binomial (MASS) and
logistic GLMs, Type III factorial ANOVA (afex, or car),
heteroscedasticity-robust (HC3) factorial ANOVA (car), the aligned rank
transform (ARTool), rank-based repeated measures (nparLD), multinomial
regression (nnet) and its mixed counterpart (mclogit), and the classical
one-way ANOVA / Welch / Kruskal-Wallis / Wilcoxon tests. Model packages
live in `Suggests`: a branch you use needs its package installed, and
says which one if it is not.

## Random effects

A repeated-measures model starts from the maximal random-effects
structure the design supports (Barr et al., 2013): by-cluster random
slopes for every within-cluster factor whose levels are replicated
within a cluster, and the interaction slope when there are several
trials per cluster and cell. When that fit is singular or does not
converge, the structure is simplified step by step down to random
intercepts; what was dropped, and why, is announced and written into
`$methods`. A singular final fit is flagged in `$singular`.

## Post-hoc contrasts

Each categorical predictor gets its own family of pairwise comparisons
of its marginal means (averaged over the other factors), adjusted with
`adjust` within that family. Simple effects – one factor compared within
each level of the others – are added only for interactions that are in
the model and significant in the Type III omnibus test.

## References

Barr, D. J., Levy, R., Scheepers, C., & Tily, H. J. (2013). Random
effects structure for confirmatory hypothesis testing: Keep it maximal.
*Journal of Memory and Language, 68*(3), 255–278.

Matuschek, H., Kliegl, R., Vasishth, S., Baayen, H., & Bates, D. (2017).
Balancing Type I error and power in linear mixed models. *Journal of
Memory and Language, 94*, 305–315.

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
#> Fitted: Linear Mixed Model (LMM) -- lmerTest::lmer(score ~ cond + (1 | id), data = your_data)
#> <colleyRstats fitted analysis>
#>   Outcome     : score (continuous)
#>   Model       : Linear Mixed Model (LMM) [lmer]
#>   Fitted with : lmerTest::lmer(score ~ cond + (1 | id), data = your_data)
#>   Random      : (1 | id)  (singular fit)
#>   Contrasts   : 3 comparison(s) in $contrasts
#>   Reported as :
#>     A linear mixed model was fitted for score. Model terms were tested with Type III $F$-tests and coefficients with $t$-tests, using Satterthwaite's degrees of freedom. Coefficients are treatment contrasts against each factor's reference level.
#>     The main effect of \textit{cond} on score was not significant (\F{2}{57}{0.20}, \p{0.817}).
#>     The contrast \textit{B} vs.\ \textit{A} of \textit{cond} on score was not significant ($b = 0.05$, 95\% CI $[-0.49, 0.60]$, $t(57) = 0.20$, \p{0.843}).
#>     The contrast \textit{C} vs.\ \textit{A} of \textit{cond} on score was not significant ($b = -0.12$, 95\% CI $[-0.67, 0.43]$, $t(57) = -0.42$, \p{0.673}).
#> 
#> Omnibus tests:
#>  term df1 df2 statistic     p
#>  cond   2  57  F = 0.20 0.817
#> 
#> Linear mixed model fit by REML. t-tests use Satterthwaite's method [
#> lmerModLmerTest]
#> Formula: score ~ cond + (1 | id)
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
