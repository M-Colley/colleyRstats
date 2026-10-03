# Report dunnTest as text

Reports the significant comparisons of an
[`FSA::dunnTest()`](https://fishr-core-team.github.io/FSA/reference/dunnTest.html)
result as sentences such as "A Dunn post-hoc test (Holm-adjusted) found
that ... for the Species virginica was significantly higher (Mdn=...,
IQR=...) than for setosa (Mdn=..., IQR=...; p_adj\<.001, r_rb=...)". The
multiplicity correction is read from the test object; with
`method = "none"` the p-values are uncorrected and are emitted as
`\p{}`/`\pminor{}`, not as \\p\_{adj}\\.

## Usage

``` r
reportDunnTest(
  d,
  data,
  iv = "testiv",
  dv = "testdv",
  sink_to = NULL,
  descriptives = c("auto", "mean", "median", "trimmed")
)

report_dunn_test(
  d,
  data,
  iv = "testiv",
  dv = "testdv",
  sink_to = NULL,
  descriptives = c("auto", "mean", "median", "trimmed")
)
```

## Arguments

- d:

  the dunn test object

- data:

  the data frame

- iv:

  independent variable

- dv:

  dependent variable

- sink_to:

  optional path of a `.tex` file to write the sentences to, so a
  manuscript can `\input{}` them

- descriptives:

  which descriptives to print beside each level: `"auto"` (default,
  median and IQR for this rank-based test), `"mean"`, `"median"` or
  `"trimmed"` (20% trimmed mean and 20% winsorized SD).

## Value

Invisibly returns the reported sentence(s) as a character vector; the
text is also emitted via
[`message()`](https://rdrr.io/r/base/message.html).

## Details

Which level is "higher" follows the sign of the test's \\Z\\ (FSA labels
a comparison "A - B"; \\Z \> 0\\ means A has the higher mean rank).
Until 0.3.0 it followed the raw means, which can point the other way:
with a few large outliers a level can have the larger mean but the
significantly lower mean rank. As a consistency check, the mean ranks
are recomputed from `data` and a warning is given when they disagree
with \\Z\\ (i.e. when `data` is not the data the test was computed on).

By default (`descriptives = "auto"`) each level is described by its
median and IQR, the location measure that matches a rank-based test;
`"mean"` restores *M*/*SD* and warns where the means order two levels
against the test.

Required commands in LaTeX (all part of
[`latex_preamble()`](https://m-colley.github.io/colleyRstats/reference/latex_preamble.md)):
`\padj`, `\padjminor`, `\p`, `\pminor`, `\mdn`, `\iqr`, `\m`, `\sd` and
`\newcommand{\rankbiserial}[1]{$r_{rb} = #1$}`.

## Naming

`report_dunn_test()` is the spelling used throughout the documentation
and the one to prefer in new code: the `report_*` / `plot_*` / `check_*`
prefixes make the API discoverable through autocomplete.

`reportDunnTest()` **\[superseded\]** is the original name. Both names
refer to the same function object, so they are entirely interchangeable;
the original remains fully supported and is not scheduled for removal,
and existing scripts keep working unchanged.

## Examples

``` r
# \donttest{
if (requireNamespace("FSA", quietly = TRUE)) {
  # Use built-in iris data
  data(iris)

  # Dunn test on Sepal.Length by Species
  d <- FSA::dunnTest(Sepal.Length ~ Species,
    data   = iris,
    method = "holm"
  )

  # Report the Dunn test
  reportDunnTest(d,
    data = iris,
    iv   = "Species",
    dv   = "Sepal.Length"
  )
}
#>   Kruskal-Wallis rank sum test
#> 
#> data: x and g
#> Kruskal-Wallis chi-squared = 96.9374, df = 2, p-value = 0
#> 
#>                       Dunn's Pairwise Comparison of x by g                      
#>                                      (Holm)                                     
#> 
#> Col Mean-│
#> Row Mean │     setosa   versicol
#> ─────────┼──────────────────────
#> versicol │  -6.106326
#>          │     0.0000*
#>          │
#> virginic │  -9.741784  -3.635458
#>          │     0.0000*    0.0003*
#> 
#> FWER = 0.05
#> Reject Ho if adjusted p ≤ FWER with stopping rule, where (unadjusted) p = Pr(|Z| ≥ |z|)
#> A Dunn post-hoc test (Holm-adjusted) found that Sepal.Length for the \Species{} versicolor was significantly higher (\mdn{5.90}, \iqr{0.70}) than for setosa (\mdn{5.00}, \iqr{0.40}; \padjminor{0.001}, \rankbiserial{0.87}). 
#> A Dunn post-hoc test (Holm-adjusted) found that Sepal.Length for the \Species{} virginica was significantly higher (\mdn{6.50}, \iqr{0.67}) than for setosa (\mdn{5.00}, \iqr{0.40}; \padjminor{0.001}, \rankbiserial{0.97}) and versicolor (\mdn{5.90}, \iqr{0.70}; \padjminor{0.001}, \rankbiserial{0.58}). 
# }
```
