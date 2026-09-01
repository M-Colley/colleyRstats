# Report ART contrasts (art.con) as a LaTeX table. Customizable with sensible defaults. Companion to [`reportDunnTestTable()`](https://m-colley.github.io/colleyRstats/reference/reportDunnTestTable.md).

Required commands in LaTeX:
`\newcommand{\padjminor}{\textit{p$_{adj}<$}}`
`\newcommand{\padj}{\textit{p$_{adj}$=}}`
`\newcommand{\rankbiserial}[1]{$r_{rb} = #1$}`

## Usage

``` r
reportArtConTable(
  ac,
  data,
  iv = "testiv",
  dv = "testdv",
  paired = FALSE,
  id = NULL,
  orderByP = FALSE,
  numberDigitsForPValue = 4,
  latexSize = "small",
  orderText = TRUE,
  style = c("hline", "booktabs"),
  sink_to = NULL
)

report_art_con_table(
  ac,
  data,
  iv = "testiv",
  dv = "testdv",
  paired = FALSE,
  id = NULL,
  orderByP = FALSE,
  numberDigitsForPValue = 4,
  latexSize = "small",
  orderText = TRUE,
  style = c("hline", "booktabs"),
  sink_to = NULL
)
```

## Arguments

- ac:

  the contrast object returned by
  [`ARTool::art.con()`](https://rdrr.io/pkg/ARTool/man/art.con.html) (or
  its [`summary()`](https://rdrr.io/r/base/summary.html))

- data:

  the raw data frame used to fit the model

- iv:

  independent variable (the contrasted factor)

- dv:

  dependent variable

- paired:

  whether to compute the rank-biserial effect size for paired
  (within-subjects) data. Defaults to `FALSE`. When `TRUE`, `id` is
  required.

- id:

  the subject/pairing column, used only when `paired = TRUE`. Replicate
  trials per subject and condition are averaged before pairing.

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

  table rule style: `"hline"` (default) or `"booktabs"`
  (`\toprule`/`\midrule`/`\bottomrule`; needs `\usepackage{booktabs}`).

- sink_to:

  optional path of a `.tex` file to write the table to, so a manuscript
  can `\input{}` it

## Value

Invisibly returns the rendered LaTeX table as a string (or `NULL` when
xtable is unavailable); the table is also printed.

## Naming

`report_art_con_table()` is the spelling used throughout the
documentation and the one to prefer in new code: the `report_*` /
`plot_*` / `check_*` prefixes make the API discoverable through
autocomplete.

`reportArtConTable()` **\[superseded\]** is the original name. Both
names refer to the same function object, so they are entirely
interchangeable; the original remains fully supported and is not
scheduled for removal, and existing scripts keep working unchanged.

## Examples

``` r
# \donttest{
if (requireNamespace("ARTool", quietly = TRUE) &&
  requireNamespace("emmeans", quietly = TRUE)) {
  set.seed(123)
  n <- 20
  df <- data.frame(
    UserID = factor(rep(seq_len(n), times = 3)),
    mode   = factor(rep(c("Hand", "Eye", "Both"), each = n)),
    prime  = factor(rep(rep(c("A", "B"), each = n / 2), times = 3))
  )
  df$score <- as.numeric(df$mode) * 2 + stats::rnorm(nrow(df))

  m  <- ARTool::art(score ~ mode * prime + Error(UserID / mode), data = df)
  ac <- ARTool::art.con(m, ~ mode, adjust = "holm")
  reportArtConTable(ac, data = df, iv = "mode", dv = "score", paired = TRUE, id = "UserID")
}
#> NOTE: Results may be misleading due to involvement in interactions
#> % latex table generated in R 4.6.1 by xtable 1.8-8 package
#> % Tue Sep  1 17:02:31 2026
#> \begin{table}[ht]
#> \centering
#> \caption{Post-hoc ART contrasts for independent variable \mode and dependent variable \score. Positive t-values mean that the first-named level is sig. higher than the second-named (on the aligned-rank scale). For negative t-values, the opposite is true. Effect size reported as rank-biserial correlation (r).} 
#> \label{tab:artcon-mode-score}
#> \begingroup\small
#> \begin{tabular}{lrrll}
#>   \hline
#> Comparison & t & df & p-adjusted & r \\ 
#>   \hline
#> Both - Eye & -6.64 & 36 & $<$0.001 & 0.97 \\ 
#>   Both - Hand & -13.95 & 36 & $<$0.001 & 1.00 \\ 
#>   Eye - Hand & -7.31 & 36 & $<$0.001 & 1.00 \\ 
#>    \hline
#> \end{tabular}
#> \endgroup
#> \end{table}
# }
```
