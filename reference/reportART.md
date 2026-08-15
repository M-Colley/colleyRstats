# Generate the Latex-text based on the ARTool (see <https://github.com/mjskay/ARTool>). The ART result must be piped into an anova(). Only significant main and interaction effects are reported. P-values are rounded for the third digit. Attention: Effect sizes are not calculated! Attention: the independent variables of the formula and the term specifying the participant must be factors (i.e., use as.factor()).

To easily copy and paste the results to your manuscript, the following
commands must be defined in Latex:
`\newcommand{\F}[3]{$F({#1},{#2})={#3}$}` `\newcommand{\p}{\textit{p=}}`
`\newcommand{\pminor}{\textit{p$<$}}`

## Usage

``` r
reportART(
  model,
  dv = "Testdependentvariable",
  write_to_clipboard = FALSE,
  sink_to = NULL
)

report_art(
  model,
  dv = "Testdependentvariable",
  write_to_clipboard = FALSE,
  sink_to = NULL
)
```

## Arguments

- model:

  the model of the art

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

## Naming

`report_art()` is the spelling used throughout the documentation and the
one to prefer in new code: the `report_*` / `plot_*` / `check_*`
prefixes make the API discoverable through autocomplete.

`reportART()` **\[superseded\]** is the original name. Both names refer
to the same function object, so they are entirely interchangeable; the
original remains fully supported and is not scheduled for removal, and
existing scripts keep working unchanged.

## Examples

``` r
# \donttest{
if (requireNamespace("ARTool", quietly = TRUE)) {
  set.seed(123)

  main_df <- data.frame(
    tlx_mental = stats::rnorm(80),
    Video      = factor(rep(c("A", "B"), each = 40)),
    gesture    = factor(rep(c("G1", "G2"), times = 40)),
    eHMI       = factor(rep(c("On", "Off"), times = 40)),
    UserID     = factor(rep(1:20, each = 4))
  )

  art_model <- ARTool::art(
    tlx_mental ~ Video * gesture * eHMI +
      Error(UserID / (gesture * eHMI)),
    data = main_df
  )

  model_anova <- stats::anova(art_model)
  reportART(model_anova, dv = "mental demand")
}
#> Warning: Error() model is singular
#> Warning: Error() model is singular
#> Warning: Error() model is singular
#> Warning: Error() model is singular
#> Warning: Error() model is singular
#> Warning: Error() model is singular
#> Warning: Error() model is singular
#> The ART found no significant effects on mental demand. 
# }
```
