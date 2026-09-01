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
  sink_dir = NULL
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

## Value

Invisibly returns a list with components `results` (named list of
[`analyze_and_report()`](https://m-colley.github.io/colleyRstats/reference/analyze_and_report.md)
results), `summary` (data frame with one row per dv: method, statistic,
p.value, and Holm-adjusted `p.holm`), and `combined_plot` (a patchwork
figure, or `NULL` when patchwork is not installed).

## Examples

``` r
# \donttest{
out <- report_all(mtcars, dvs = c("mpg", "disp"), iv = "cyl")
#> Shapiro--Wilk tests indicated no significant deviation from normality in any group (all $p \geq 0.05$); therefore, parametric tests were used. Levene's test indicated unequal variances ($F(2, 29) = 5.51$, $p = 0.009$); Welch-corrected statistics were used where applicable.
#> A One-way analysis of means (not assuming equal variances) found a significant effect of \cyl on mpg (\F{2}{18.03}{31.62}, \pminor{0.001}, $\omega^{2}$ = 0.74). 
#> A Games-Howell post-hoc test (Holm-adjusted) found that 4 was significantly higher (\m{26.66}, \sd{4.51}) in terms of \mpg compared to 6 (\m{19.74}, \sd{1.45}; \padj{0.001}). 
#> A Games-Howell post-hoc test (Holm-adjusted) found that 4 was significantly higher (\m{26.66}, \sd{4.51}) in terms of \mpg compared to 8 (\m{15.10}, \sd{2.56}; \padjminor{0.001}). 
#> A Games-Howell post-hoc test (Holm-adjusted) found that 6 was significantly higher (\m{19.74}, \sd{1.45}) in terms of \mpg compared to 8 (\m{15.10}, \sd{2.56}; \padjminor{0.001}). 
#> Shapiro--Wilk tests indicated a significant deviation from normality for at least one group (minimum $W = 0.80$, $p = 0.043$); therefore, non-parametric tests were used. Levene's test indicated homogeneity of variances ($F(2, 29) = 3.29$, $p = 0.052$).
#> A Kruskal-Wallis rank sum test found a significant effect of \cyl on disp (\chisq(2)=26.68, \pminor{0.001}, $\epsilon_{ordinal}^{2}$ = 0.86). 
#> A Dunn post-hoc test (Holm-adjusted) found that 8 was significantly higher (\m{353.10}, \sd{67.77}) in terms of \disp compared to 4 (\m{105.14}, \sd{26.87}; \padjminor{0.001}). 
#> A Dunn post-hoc test (Holm-adjusted) found that 8 was significantly higher (\m{353.10}, \sd{67.77}) in terms of \disp compared to 6 (\m{183.31}, \sd{41.56}; \padj{0.028}). 
out$summary
#>     dv                                                   method statistic
#> 1  mpg One-way analysis of means (not assuming equal variances)  31.62424
#> 2 disp                             Kruskal-Wallis rank sum test  26.67893
#>        p.value       p.holm
#> 1 1.270809e-06 2.541619e-06
#> 2 1.609696e-06 2.541619e-06
# }
```
