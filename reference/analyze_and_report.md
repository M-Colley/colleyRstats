# Analyze one dependent variable and produce everything a paper needs

One-call pipeline for a single dependent variable: checks the
assumptions (producing a ready-made methods sentence via
[`assumption_methods_text()`](https://m-colley.github.io/colleyRstats/reference/assumption_methods_text.md)),
builds the matching ggstatsplot figure with automatic
parametric/non-parametric selection, reports the omnibus test via
[`reportggstatsplot()`](https://m-colley.github.io/colleyRstats/reference/reportggstatsplot.md),
and – for more than two groups – reports the significant post-hoc
comparisons via
[`reportggstatsplotPostHoc()`](https://m-colley.github.io/colleyRstats/reference/reportggstatsplotPostHoc.md).

## Usage

``` r
analyze_and_report(
  data,
  dv,
  iv,
  design = c("between", "within"),
  ylab = dv,
  xlabels = NULL,
  plotType = "boxviolin",
  sink_to = NULL,
  subject = NULL
)
```

## Arguments

- data:

  the data frame (long format for `design = "within"`: one row per
  participant and condition)

- dv:

  the dependent variable (column name as string)

- iv:

  the independent variable (column name as string); treated as a factor,
  so numeric condition codes are categories

- design:

  `"between"` for between-subjects data (default) or `"within"` for
  repeated measures

- ylab:

  label for the dependent variable; defaults to `dv`

- xlabels:

  optional labels for the x-axis

- plotType:

  either "box", "violin", or "boxviolin" (default)

- sink_to:

  optional path of a `.tex` file; the methods sentence, omnibus result,
  and post-hoc sentences are written there so a manuscript can
  `\input{}` them

- subject:

  the participant-ID column (a string). Required for
  `design = "within"`, where it pairs the observations; without it they
  would be paired by row order. For `design = "between"` it is optional
  and only used to check that no participant contributes more than one
  row, which a between-subjects test would wrongly treat as independent
  observations.

## Value

Invisibly returns a list with components `plot` (the ggplot), `methods`
(assumption-check sentence), `text` (omnibus result), `posthoc`
(post-hoc sentences, or `NULL` for two groups), and `sentences` (all
text combined, in manuscript order).

## Details

Every part of the output is computed from one data set: the rows with
both `dv` and `iv` observed and, for `design = "within"`, only the
participants measured in every condition (the others are dropped with a
message naming them; more than one row per participant and condition is
an error). The methods sentence, the test, the figure and the means
quoted in the post-hoc sentences therefore all describe the same
participants.

## Examples

``` r
# \donttest{
result <- analyze_and_report(mtcars, dv = "mpg", iv = "cyl")
#> Shapiro--Wilk tests in each of the 3 groups of cyl (Holm-corrected for 3 tests) indicated no significant deviation from normality (smallest $p$: $W = 0.91$, $p_{\mathrm{Holm}} = 0.782$ for group 4); therefore, parametric tests were used. Brown-Forsythe test (median-centred Levene's test) indicated unequal variances ($F(2, 29) = 5.51$, $p = 0.009$); Welch-corrected statistics were used where applicable.
#> A One-way analysis of means (not assuming equal variances) found a significant effect of \cyl{} on mpg (\F{2}{18.03}{31.62}, \pminor{0.001}, $\omega^{2}$ = 0.74). 
#> A Games-Howell post-hoc test (Holm-adjusted) found that 4 was significantly higher (\m{26.66}, \sd{4.51}) in terms of mpg compared to 6 (\m{19.74}, \sd{1.45}; \padj{0.001}). 
#> A Games-Howell post-hoc test (Holm-adjusted) found that 4 was significantly higher (\m{26.66}, \sd{4.51}) in terms of mpg compared to 8 (\m{15.10}, \sd{2.56}; \padjminor{0.001}). 
#> A Games-Howell post-hoc test (Holm-adjusted) found that 6 was significantly higher (\m{19.74}, \sd{1.45}) in terms of mpg compared to 8 (\m{15.10}, \sd{2.56}; \padjminor{0.001}). 
result$plot


# Repeated measures: name the participant column
set.seed(1)
rm_df <- data.frame(
  participant = rep(1:15, times = 3),
  condition   = rep(c("A", "B", "C"), each = 15)
)
rm_df$score <- rnorm(45, mean = c(A = 5, B = 6, C = 7)[rm_df$condition])
analyze_and_report(rm_df, dv = "score", iv = "condition",
                   design = "within", subject = "participant")
#> A Shapiro--Wilk test on the residuals of the additive model with participant and condition as factors ($n = 45$) indicated no significant deviation from normality ($W = 0.98$, $p = 0.481$); therefore, parametric tests were used.
#> An ANOVA estimation for factorial designs using 'afex' found a significant effect of \condition{} on score (\F{1.94}{27.18}{15.80}, \pminor{0.001}, $\omega_{p}^{2}$ = 0.45). 
#> A Student's t post-hoc test (Holm-adjusted) found that B was significantly higher (\m{6.06}, \sd{0.86}) in terms of score compared to A (\m{5.10}, \sd{1.02}; \padj{0.021}). 
#> A Student's t post-hoc test (Holm-adjusted) found that C was significantly higher (\m{7.09}, \sd{0.72}) in terms of score compared to A (\m{5.10}, \sd{1.02}; \padjminor{0.001}). 
#> A Student's t post-hoc test (Holm-adjusted) found that C was significantly higher (\m{7.09}, \sd{0.72}) in terms of score compared to B (\m{6.06}, \sd{0.86}; \padj{0.021}). 
# }
```
