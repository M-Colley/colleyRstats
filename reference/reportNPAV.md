# Generate the Latex-text based on the NPAV by Lüpsen (see <https://www.uni-koeln.de/~luepsen/R/>). Only significant main and interaction effects are reported. P-values are rounded for the third digit and partial eta squared values are provided when possible. Attention: the independent variables of the formula and the term specifying the participant must be factors (i.e., use as.factor()).

Deprecated: `reportNPAV()` will be removed in a future release. Use
[`reportART()`](https://m-colley.github.io/colleyRstats/reference/reportART.md)
with ARTool instead.

## Usage

``` r
reportNPAV(
  model,
  dv = "Testdependentvariable",
  write_to_clipboard = FALSE,
  sink_to = NULL
)
```

## Arguments

- model:

  the model of the np.anova

- dv:

  the name of the dependent variable that should be reported

- write_to_clipboard:

  whether to write to the clipboard

- sink_to:

  optional path of a `.tex` file to write the sentences to, so a
  manuscript can `\input{}` them

## Value

Invisibly returns the reported sentence(s) as a character vector; the
text is also emitted via
[`message()`](https://rdrr.io/r/base/message.html).

## Details

To easily copy and paste the results to your manuscript, the following
commands must be defined in Latex:
`\newcommand{\F}[3]{$F({#1},{#2})={#3}$}` `\newcommand{\p}{\textit{p=}}`
`\newcommand{\pminor}{\textit{p$<$}}`

## Examples

``` r
model <- data.frame(
  Df = c(1, 1, 10),
  `F value` = c(6.12, 5.01, NA),
  `Pr(>F)` = c(0.033, 0.045, NA),
  check.names = FALSE
)
rownames(model) <- c("Video", "gesture:eHMI", "Residuals")
reportNPAV(model, dv = "mental workload")
#> Warning: reportNPAV() is deprecated and will be removed in a future release. Use reportART() with ARTool instead.
#> The NPAV found a significant main effect of \Video on mental workload (\F{1}{10}{6.12}, \p{0.033}), $\eta_{p}^{2}$=0.38 [0.02, 1.00]. 
#> The NPAV found a significant interaction effect of \gesture $\times$ \eHMI on mental workload (\F{1}{10}{5.01}, \p{0.045}), $\eta_{p}^{2}$=0.33 [0.00, 1.00]. 
```
