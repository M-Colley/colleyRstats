# Report a cumulative link (mixed) model in LaTeX/APA style

Reporter for ordinal proportional-odds models fitted with ordinal:
cumulative link mixed models
([`ordinal::clmm`](https://rdrr.io/pkg/ordinal/man/clmm.html)) and their
fixed-effects counterpart
([`ordinal::clm`](https://rdrr.io/pkg/ordinal/man/clm.html)). Each
location (predictor) effect is reported as an odds ratio – the
multiplicative change in the odds of being in a higher outcome category
for a one-unit increase in the predictor – with its confidence interval,
z statistic and p-value. The threshold (cut-point) coefficients are
omitted, as is conventional.

## Usage

``` r
reportCLMM(
  model,
  dv = "Testdependentvariable",
  exponentiate = "auto",
  conf_level = 0.95,
  write_to_clipboard = FALSE,
  sink_to = NULL
)

report_clmm(
  model,
  dv = "Testdependentvariable",
  exponentiate = "auto",
  conf_level = 0.95,
  write_to_clipboard = FALSE,
  sink_to = NULL
)
```

## Arguments

- model:

  A fitted [`ordinal::clmm`](https://rdrr.io/pkg/ordinal/man/clmm.html)
  or [`ordinal::clm`](https://rdrr.io/pkg/ordinal/man/clm.html) model.

- dv:

  Name of the (ordinal) dependent variable, used in the sentence text.

- exponentiate:

  `"auto"` (default; report odds ratios) or `TRUE`/`FALSE` to force it.
  `FALSE` reports raw log-odds.

- conf_level:

  Confidence level for the intervals. Default 0.95.

- write_to_clipboard:

  Whether to copy the sentences to the clipboard.

- sink_to:

  Optional path of a `.tex` file to write the sentences to.

## Value

Invisibly returns the reported sentence(s) as a character vector; the
text is also emitted via
[`message()`](https://rdrr.io/r/base/message.html).

## Details

The threshold (cut-point) parameters are never reported, so unlike
[`reportGLMM()`](https://m-colley.github.io/colleyRstats/reference/reportGLMM.md)
this reporter has no `include_intercept` argument.

## Naming

`report_clmm()` is the spelling used throughout the documentation and
the one to prefer in new code: the `report_*` / `plot_*` / `check_*`
prefixes make the API discoverable through autocomplete.

`reportCLMM()` **\[superseded\]** is the original name. Both names refer
to the same function object, so they are entirely interchangeable; the
original remains fully supported and is not scheduled for removal, and
existing scripts keep working unchanged.

## Examples

``` r
# \donttest{
if (requireNamespace("ordinal", quietly = TRUE) &&
  requireNamespace("parameters", quietly = TRUE)) {
  m <- ordinal::clmm(rating ~ temp + contact + (1 | judge), data = ordinal::wine)
  reportCLMM(m, dv = "wine rating")
}
#> A cumulative link mixed model was fitted for wine rating.
#> The effect of \textit{tempwarm} on wine rating was significant ($OR = 21.39$, 95\% CI $[6.66, 68.71]$, $z = 5.14$, \pminor{0.001}).
#> The effect of \textit{contactyes} on wine rating was significant ($OR = 6.26$, 95\% CI $[2.29, 17.11]$, $z = 3.58$, \pminor{0.001}).
# }
```
