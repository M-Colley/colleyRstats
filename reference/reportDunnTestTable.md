# report Dunn test as a table. Customizable with sensible defaults. Required commands in LaTeX: `\newcommand{\padjminor}{\textit{p$_{adj}<$}}` `\newcommand{\padj}{\textit{p$_{adj}$=}}` `\newcommand{\rankbiserial}[1]{$r_{rb} = #1$}`

report Dunn test as a table. Customizable with sensible defaults.
Required commands in LaTeX:
`\newcommand{\padjminor}{\textit{p$_{adj}<$}}`
`\newcommand{\padj}{\textit{p$_{adj}$=}}`
`\newcommand{\rankbiserial}[1]{$r_{rb} = #1$}`

## Usage

``` r
reportDunnTestTable(
  d = NULL,
  data,
  iv = "testiv",
  dv = "testdv",
  orderByP = FALSE,
  numberDigitsForPValue = 4,
  latexSize = "small",
  orderText = TRUE,
  style = c("hline", "booktabs"),
  sink_to = NULL
)

report_dunn_test_table(
  d = NULL,
  data,
  iv = "testiv",
  dv = "testdv",
  orderByP = FALSE,
  numberDigitsForPValue = 4,
  latexSize = "small",
  orderText = TRUE,
  style = c("hline", "booktabs"),
  sink_to = NULL
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

- orderByP:

  whether to order by the p value

- numberDigitsForPValue:

  the number of digits to show

- latexSize:

  which size for the text

- orderText:

  whether to order the comparisons alphabetically; ignored when
  `orderByP = TRUE`

- style:

  table rule style: `"hline"` (default, classic `\hline` rules) or
  `"booktabs"` (journal-standard `\toprule`/`\midrule`/`\bottomrule`;
  needs `\usepackage{booktabs}`).

- sink_to:

  optional path of a `.tex` file to write the table to, so a manuscript
  can `\input{}` it

## Value

Invisibly returns the rendered LaTeX table as a string (or `NULL` when
xtable is unavailable); the table is also printed.

## Naming

`report_dunn_test_table()` is the spelling used throughout the
documentation and the one to prefer in new code: the `report_*` /
`plot_*` / `check_*` prefixes make the API discoverable through
autocomplete.

`reportDunnTestTable()` **\[superseded\]** is the original name. Both
names refer to the same function object, so they are entirely
interchangeable; the original remains fully supported and is not
scheduled for removal, and existing scripts keep working unchanged.

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
  reportDunnTestTable(d,
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
#> % latex table generated in R 4.6.1 by xtable 1.8-8 package
#> % Fri Aug 28 07:57:18 2026
#> \begin{table}[ht]
#> \centering
#> \caption{Post-hoc comparisons for independent variable \Species and dependent variable Sepal.Length. Positive Z-values mean that the first-named level is sig. higher than the second-named. For negative Z-values, the opposite is true. Effect size reported as rank-biserial correlation (r).} 
#> \label{tab:posthoc-Species-Sepal.Length}
#> \begingroup\small
#> \begin{tabular}{lrll}
#>   \hline
#> Comparison & Z & p-adjusted & r \\ 
#>   \hline
#> setosa - versicolor & -6.1063 & $<$0.001 & 0.87 \\ 
#>   setosa - virginica & -9.7418 & $<$0.001 & 0.97 \\ 
#>   versicolor - virginica & -3.6355 & $<$0.001 & 0.58 \\ 
#>    \hline
#> \end{tabular}
#> \endgroup
#> \end{table}
# }
```
