# Choosing the right test (and mixed models)

``` r

library(colleyRstats)
#> Loading required package: ggplot2
#> Registered S3 methods overwritten by 'ggpp':
#>   method                  from   
#>   heightDetails.titleGrob ggplot2
#>   widthDetails.titleGrob  ggplot2
```

Picking a statistical test is not a matter of taste: it follows from
properties of the data. `colleyRstats` makes that reasoning explicit.
This vignette walks through the decision helpers and then shows how to
fit and report the models they recommend.

## The idea: scale x dependence x assumptions

A principled model choice is the product of three questions, in order:

1.  **What is the outcome’s measurement scale?** This fixes the model
    *family* (Gaussian, binomial, Poisson, cumulative-link) before
    anything else.
2.  **Are the observations independent or clustered?** Repeated measures
    or any grouped structure needs random effects, i.e. a *mixed* model.
3.  **For a continuous outcome, do the parametric assumptions hold?**
    Normality of the residuals of the model that would be fitted (and,
    between subjects, homogeneity of variance across all design cells)
    decides between a parametric and a rank-based method.

[`classify_outcome()`](https://m-colley.github.io/colleyRstats/reference/classify_outcome.md)
answers the first question. It maps a variable to one of `"continuous"`,
`"ordinal"`, `"binary"`, `"count"`, or `"nominal"` using simple,
transparent rules (ordered factor -\> ordinal; values coded 0/1, a
logical or a two-level factor -\> binary; a few-valued integer -\>
ordinal/Likert; whole numbers in steps of 5 within 0-100, such as raw
NASA-TLX, -\> continuous; any other non-negative integer with more
values -\> count, announced with a message so you can override it;
anything else numeric -\> continuous).

``` r

set.seed(1)
n_id <- 24
d <- data.frame(
  id   = factor(rep(seq_len(n_id), each = 3)),
  cond = factor(rep(c("A", "B", "C"), times = n_id))
)

# Give condition a genuine effect so the example models are well identified.
step <- c(A = 0, B = 1.3, C = 2.4)[as.character(d$cond)]
d$score   <- as.numeric(step + rnorm(nrow(d)))
d$rating  <- ordered(pmin(5L, pmax(1L, round(step + rnorm(nrow(d), sd = 0.7) + 2))))
d$correct <- rbinom(nrow(d), 1, plogis(step - 1))

classify_outcome(d$score)    # continuous
#> [1] "continuous"
classify_outcome(d$rating)   # ordinal (ordered factor)
#> [1] "ordinal"
classify_outcome(d$correct)  # binary (coded 0/1)
#> [1] "binary"
```

Getting the scale right matters because it, not the analyst’s habit,
dictates the family: a 1-5 rating is not an interval score, and a 0/1
accuracy is not Gaussian. When a heuristic is genuinely ambiguous (a
wide Likert item versus a small count) you can override it via the
`outcome_type` argument of
[`recommend_test()`](https://m-colley.github.io/colleyRstats/reference/recommend_test.md).

## `recommend_test()` as the decision helper

[`recommend_test()`](https://m-colley.github.io/colleyRstats/reference/recommend_test.md)
runs all three questions and returns a `"colley_recommendation"` object.
It carries the fields that let you act on the advice: `recommendation`
(a human-readable label), `model_function` (the R function to call),
`reporter` (the matching colleyRstats reporter), `fit_call` (a
ready-to-edit call), `rationale` (why), and `methods_text` (an APA-style
sentence). A `print` method summarises it.

The same outcome routes to different models depending on scale and
dependence. An **ordinal** outcome measured repeatedly within `id` gives
a cumulative link mixed model (CLMM):

``` r

rec_clmm <- recommend_test(d, outcome = "rating", predictors = "cond", cluster = "id")
rec_clmm
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
```

A **binary** outcome with the same clustering gives a binomial
generalized linear mixed model (GLMM):

``` r

rec_glmm <- recommend_test(d, outcome = "correct", predictors = "cond", cluster = "id")
rec_glmm
#> <colleyRstats analysis recommendation>
#>   Outcome        : correct (binary)
#>   Predictors     : cond (categorical, within)
#>   Design         : within (cluster: id)
#>   Random effects : (1 | id)
#>   Recommendation : Generalized Linear Mixed Model (GLMM), binomial
#>   Family         : binomial (logit)
#>   Fit with       : lme4::glmer(correct ~ cond + (1 | id), data = your_data, family = binomial)
#>   Report with    : reportGLMM()
#>   Alternative(s) : glmmTMB::glmmTMB(..., family = binomial) for more flexible random structures
#>   Rationale      : the outcome is binary and the observations are clustered, so a mixed-effects logistic regression is appropriate
```

A **continuous** outcome compared **between** subjects (no `cluster`)
triggers the assumption checks and lands on ANOVA or its rank-based
fallback:

``` r

rec_anova <- recommend_test(d, outcome = "score", predictors = "cond")
#> Registered S3 method overwritten by 'car':
#>   method           from
#>   na.action.merMod lme4
rec_anova
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

Each recommendation also exposes machine-usable fields and a paste-ready
methods sentence:

``` r

rec_clmm$model_function
#> [1] "ordinal::clmm"
rec_clmm$reporter
#> [1] "reportCLMM"
rec_clmm$fit_call
#> [1] "ordinal::clmm(rating ~ cond + (1 | id), data = your_data)  # outcome must be an ordered factor"
cat(rec_glmm$methods_text)
#> The outcome `correct` is binary, and the observations are clustered within `id` (24 clusters, 72 observations). A Generalized Linear Mixed Model (GLMM), binomial (`lme4::glmer`) is therefore recommended; report it with `reportGLMM()`.
```

## Fitting and reporting the recommended models

Once a model is fitted, the reporters turn it into manuscript-ready
LaTeX/APA sentences. Each model term first gets a Type III omnibus test
(Satterthwaite F for linear mixed models, a Wald chi-square otherwise) –
the test that answers “does condition matter?” for a factor with any
number of levels. The coefficients follow, each labelled as what a
treatment-coded coefficient is: a contrast against the reference level
(“B vs. A of cond”), and in a model with an interaction, a contrast at
the reference level of the other factor. Each comes with the effect
size, its confidence interval, the test statistic, and the p-value;
linear mixed models use Satterthwaite degrees of freedom.
[`reportGLMM()`](https://m-colley.github.io/colleyRstats/reference/reportGLMM.md)
handles [`lme4::lmer`](https://rdrr.io/pkg/lme4/man/lmer.html) /
[`lme4::glmer`](https://rdrr.io/pkg/lme4/man/glmer.html) /
[`glmmTMB::glmmTMB`](https://rdrr.io/pkg/glmmTMB/man/glmmTMB.html) and
plain `lm`/`glm`;
[`reportCLMM()`](https://m-colley.github.io/colleyRstats/reference/reportCLMM.md)
handles [`ordinal::clmm`](https://rdrr.io/pkg/ordinal/man/clmm.html) /
[`ordinal::clm`](https://rdrr.io/pkg/ordinal/man/clm.html). The
reporters pick the effect-size scale from the family and link: **odds
ratios** for logit links (binomial and cumulative-link models),
**incidence-rate ratios** for log-link counts, and raw coefficients
(`b`) with the link named otherwise, e.g. for Gaussian or probit fits.

The fits below require **lme4**, **ordinal**, and **parameters** (all in
Suggests), so the chunk is guarded by `has_mixed`; the vignette still
builds without them.

For the **ordinal** recommendation, fit the CLMM and report it with
[`reportCLMM()`](https://m-colley.github.io/colleyRstats/reference/reportCLMM.md).
Because the family is cumulative-link, the effects are reported as odds
ratios (the multiplicative change in the odds of a higher rating):

``` r

m_clmm <- ordinal::clmm(rating ~ cond + (1 | id), data = d)
reportCLMM(m_clmm, dv = "rating")
#> A cumulative link mixed model (logit link) was fitted for rating. Model terms were tested with Type III Wald $\chi^2$ tests. Coefficients are reported as odds ratios (OR) and are treatment contrasts against each factor's reference level.
#> The main effect of \textit{cond} on rating was significant ($\chi^2(2) = 30.60$, \pminor{0.001}).
#> The contrast \textit{B} vs.\ \textit{A} of \textit{cond} on rating was significant ($OR = 309.89$, 95\% CI $[26.21, 3663.95]$, $z = 4.55$, \pminor{0.001}).
#> The contrast \textit{C} vs.\ \textit{A} of \textit{cond} on rating was significant ($OR = 10085.81$, 95\% CI $[384.38, 264641.13]$, $z = 5.53$, \pminor{0.001}).
```

For the **binary** recommendation, fit the binomial GLMM and report it
with
[`reportGLMM()`](https://m-colley.github.io/colleyRstats/reference/reportGLMM.md);
the binomial family is likewise exponentiated to odds ratios, with a `z`
statistic:

``` r

m_glmm <- lme4::glmer(correct ~ cond + (1 | id), data = d, family = binomial)
#> boundary (singular) fit: see help('isSingular')
reportGLMM(m_glmm, dv = "accuracy")
#> A generalized linear mixed model (binomial family, logit link) was fitted for accuracy. Model terms were tested with Type III Wald $\chi^2$ tests. Coefficients are reported as odds ratios (OR) and are treatment contrasts against each factor's reference level.
#> The main effect of \textit{cond} on accuracy was significant ($\chi^2(2) = 9.44$, \p{0.009}).
#> The contrast \textit{B} vs.\ \textit{A} of \textit{cond} on accuracy was not significant ($OR = 2.80$, 95\% CI $[0.87, 9.06]$, $z = 1.72$, \p{0.086}).
#> The contrast \textit{C} vs.\ \textit{A} of \textit{cond} on accuracy was significant ($OR = 7.60$, 95\% CI $[2.07, 27.89]$, $z = 3.06$, \p{0.002}).
```

[`reportGLMM()`](https://m-colley.github.io/colleyRstats/reference/reportGLMM.md)
also covers **Gaussian** mixed and ordinary models. Here a linear mixed
model is reported on the raw coefficient scale, with `b` and a `t(df)`
statistic rather than an odds ratio – the reporter adapts the wording to
the family automatically:

``` r

m_lmm <- lme4::lmer(score ~ cond + (1 | id), data = d)
#> boundary (singular) fit: see help('isSingular')
reportGLMM(m_lmm, dv = "score")
#> A linear mixed model was fitted for score. Model terms were tested with Type III $F$-tests and coefficients with $t$-tests, using Satterthwaite's degrees of freedom. Coefficients are treatment contrasts against each factor's reference level.
#> The main effect of \textit{cond} on score was significant (\F{2}{69}{34.03}, \pminor{0.001}).
#> The contrast \textit{B} vs.\ \textit{A} of \textit{cond} on score was significant ($b = 1.28$, 95\% CI $[0.74, 1.81]$, $t(69) = 4.77$, \pminor{0.001}).
#> The contrast \textit{C} vs.\ \textit{A} of \textit{cond} on score was significant ($b = 2.20$, 95\% CI $[1.67, 2.73]$, $t(69) = 8.21$, \pminor{0.001}).
```

Both reporters return the sentences invisibly (and emit them via
[`message()`](https://rdrr.io/r/base/message.html)), and can optionally
copy to the clipboard (`write_to_clipboard = TRUE`) or write a `.tex`
file to `\input{}` in a manuscript (`sink_to =`). The LaTeX uses the
`\p` / `\pminor` macros from
[`latex_preamble()`](https://m-colley.github.io/colleyRstats/reference/latex_preamble.md).

## Next steps

- Override an ambiguous scale with
  `recommend_test(..., outcome_type = ...)`.
- For non-parametric routes surfaced by the continuous branch, see
  [`reportDunnTest()`](https://m-colley.github.io/colleyRstats/reference/reportDunnTest.md),
  [`reportArtCon()`](https://m-colley.github.io/colleyRstats/reference/reportArtCon.md),
  and
  [`reportNparLD()`](https://m-colley.github.io/colleyRstats/reference/reportNparLD.md).
- Use `rec$methods_text` as a first draft of the Methods paragraph.
