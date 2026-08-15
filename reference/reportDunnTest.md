# Report dunnTest as text. Required commands in LaTeX: `\newcommand{\padjminor}{\textit{p$_{adj}<$}}` `\newcommand{\padj}{\textit{p$_{adj}$=}}` `\newcommand{\rankbiserial}[1]{$r_{rb} = #1$}`

Report dunnTest as text. Required commands in LaTeX:
`\newcommand{\padjminor}{\textit{p$_{adj}<$}}`
`\newcommand{\padj}{\textit{p$_{adj}$=}}`
`\newcommand{\rankbiserial}[1]{$r_{rb} = #1$}`

## Usage

``` r
reportDunnTest(d, data, iv = "testiv", dv = "testdv", sink_to = NULL)

report_dunn_test(d, data, iv = "testiv", dv = "testdv", sink_to = NULL)
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

## Value

Invisibly returns the reported sentence(s) as a character vector; the
text is also emitted via
[`message()`](https://rdrr.io/r/base/message.html).

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
#> Registered S3 methods overwritten by 'FSA':
#>   method       from
#>   confint.boot car 
#>   hist.boot    car 
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
#> A post-hoc test found that Sepal.Length for the \Species versicolor was significantly higher (\m{5.94}, \sd{0.52}) than for setosa (\m{5.01}, \sd{0.35}; \padjminor{0.001}, \rankbiserial{0.87}). 
#> A post-hoc test found that Sepal.Length for the \Species virginica was significantly higher (\m{6.59}, \sd{0.64}) than for setosa (\m{5.01}, \sd{0.35}; \padjminor{0.001}, \rankbiserial{0.97}) and versicolor (\m{5.94}, \sd{0.52}; \padjminor{0.001}, \rankbiserial{0.58}). 
# }
```
