# Analyze and report several dependent variables at once

Runs
[`analyze_and_report()`](https://m-colley.github.io/colleyRstats/reference/analyze_and_report.md)
for each dependent variable (e.g., all questionnaire scales of a study)
and additionally returns a summary table of the omnibus tests with
Holm-adjusted p-values across the dependent variables, plus – when
patchwork is installed – a combined figure.

## Usage

``` r
report_all(
  data,
  dvs,
  iv,
  design = c("between", "within"),
  labels = NULL,
  xlabels = NULL,
  plotType = "boxviolin",
  sink_dir = NULL,
  subject = NULL
)
```

## Arguments

- data:

  the data frame

- dvs:

  character vector of dependent variable column names

- iv:

  the independent variable (column name as string)

- design:

  `"between"` (default) or `"within"`

- labels:

  optional named character vector mapping a dv name to its axis label,
  e.g. `c(tlx_mental = "Mental Demand")`

- xlabels:

  optional labels for the x-axis, passed to every plot

- plotType:

  either "box", "violin", or "boxviolin" (default)

- sink_dir:

  optional directory; each dv's sentences are written to
  `<sink_dir>/<dv>.tex` so a manuscript can `\input{}` them

- subject:

  the participant-ID column (a string); required for
  `design = "within"`. See
  [`analyze_and_report()`](https://m-colley.github.io/colleyRstats/reference/analyze_and_report.md).

## Value

Invisibly returns a list with components `results` (named list of
[`analyze_and_report()`](https://m-colley.github.io/colleyRstats/reference/analyze_and_report.md)
results), `summary` (data frame with one row per dv: method, statistic,
p.value, and Holm-adjusted `p.holm`), and `combined_plot` (a patchwork
figure, or `NULL` when patchwork is not installed).

## Details

Each dependent variable is analysed on its own complete cases (see
[`analyze_and_report()`](https://m-colley.github.io/colleyRstats/reference/analyze_and_report.md)),
so in a within-subjects design a participant missing one rating is left
out of that dependent variable only. The `p.holm` column corrects the
omnibus p-values for the number of dependent variables; the per-dv
sentences report the uncorrected ones.

## Examples

``` r
# \donttest{
out <- report_all(mtcars, dvs = c("mpg", "disp"), iv = "cyl")
#> Shapiro--Wilk tests in each of the 3 groups of cyl (Holm-corrected for 3 tests) indicated no significant deviation from normality (smallest $p$: $W = 0.91$, $p_{\mathrm{Holm}} = 0.782$ for group 4); therefore, parametric tests were used. Brown-Forsythe test (median-centred Levene's test) indicated unequal variances ($F(2, 29) = 5.51$, $p = 0.009$); Welch-corrected statistics were used where applicable.
#> A One-way analysis of means (not assuming equal variances) found a significant effect of \cyl{} on mpg (\F{2}{18.03}{31.62}, \pminor{0.001}, $\omega^{2}$ = 0.74). 
#> A Games-Howell post-hoc test (Holm-adjusted) found that 4 was significantly higher (\m{26.66}, \sd{4.51}) in terms of mpg compared to 6 (\m{19.74}, \sd{1.45}; \padj{0.001}). 
#> A Games-Howell post-hoc test (Holm-adjusted) found that 4 was significantly higher (\m{26.66}, \sd{4.51}) in terms of mpg compared to 8 (\m{15.10}, \sd{2.56}; \padjminor{0.001}). 
#> A Games-Howell post-hoc test (Holm-adjusted) found that 6 was significantly higher (\m{19.74}, \sd{1.45}) in terms of mpg compared to 8 (\m{15.10}, \sd{2.56}; \padjminor{0.001}). 
#> Shapiro--Wilk tests in each of the 3 groups of cyl (Holm-corrected for 3 tests) indicated no significant deviation from normality (smallest $p$: $W = 0.80$, $p_{\mathrm{Holm}} = 0.129$ for group 6); therefore, parametric tests were used. Brown-Forsythe test (median-centred Levene's test) did not indicate unequal variances ($F(2, 29) = 3.29$, $p = 0.052$).
#> A One-way analysis of means (not assuming equal variances) found a significant effect of \cyl{} on disp (\F{2}{14.89}{76.89}, \pminor{0.001}, $\omega^{2}$ = 0.89). 
#> A Games-Howell post-hoc test (Holm-adjusted) found that 6 was significantly higher (\m{183.31}, \sd{41.56}) in terms of disp compared to 4 (\m{105.14}, \sd{26.87}; \padj{0.004}). 
#> A Games-Howell post-hoc test (Holm-adjusted) found that 8 was significantly higher (\m{353.10}, \sd{67.77}) in terms of disp compared to 4 (\m{105.14}, \sd{26.87}; \padjminor{0.001}). 
#> A Games-Howell post-hoc test (Holm-adjusted) found that 8 was significantly higher (\m{353.10}, \sd{67.77}) in terms of disp compared to 6 (\m{183.31}, \sd{41.56}; \padjminor{0.001}). 
out$summary
#>     dv                                                   method statistic
#> 1  mpg One-way analysis of means (not assuming equal variances)  31.62424
#> 2 disp One-way analysis of means (not assuming equal variances)  76.89164
#>        p.value       p.holm
#> 1 1.270809e-06 1.270809e-06
#> 2 1.422939e-08 2.845878e-08
# }
```
