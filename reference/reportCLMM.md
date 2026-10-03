# Report a cumulative link (mixed) model in LaTeX/APA style

Reporter for ordinal proportional-odds models fitted with ordinal:
cumulative link mixed models
([`ordinal::clmm`](https://rdrr.io/pkg/ordinal/man/clmm.html)) and their
fixed-effects counterpart
([`ordinal::clm`](https://rdrr.io/pkg/ordinal/man/clm.html)). Each model
term is first tested with a Type III Wald \\\chi^2\\ test
([`emmeans::joint_tests()`](https://rvlenth.github.io/emmeans/reference/joint_tests.html),
independent of the contrast coding); each location coefficient is then
reported – as an odds ratio for the logit link (the multiplicative
change in the odds of being in a higher outcome category), as the raw
coefficient with the link named otherwise – with its confidence
interval, z statistic and p-value, labelled as the contrast it is (see
[`reportGLMM()`](https://m-colley.github.io/colleyRstats/reference/reportGLMM.md)).

## Usage

``` r
reportCLMM(
  model,
  dv = "Testdependentvariable",
  exponentiate = "auto",
  conf_level = 0.95,
  write_to_clipboard = FALSE,
  sink_to = NULL,
  omnibus = TRUE
)

report_clmm(
  model,
  dv = "Testdependentvariable",
  exponentiate = "auto",
  conf_level = 0.95,
  write_to_clipboard = FALSE,
  sink_to = NULL,
  omnibus = TRUE
)
```

## Arguments

- model:

  A fitted [`ordinal::clmm`](https://rdrr.io/pkg/ordinal/man/clmm.html)
  or [`ordinal::clm`](https://rdrr.io/pkg/ordinal/man/clm.html) model.

- dv:

  Name of the (ordinal) dependent variable, used in the sentence text.

- exponentiate:

  `"auto"` (default; odds ratios for the logit link, raw coefficients
  for probit, cloglog and other links) or `TRUE`/`FALSE` to force it.
  `FALSE` reports raw log-odds.

- conf_level:

  Confidence level for the intervals. Default 0.95.

- write_to_clipboard:

  Whether to copy the sentences to the clipboard.

- sink_to:

  Optional path of a `.tex` file to write the sentences to.

- omnibus:

  Logical. Report the Type III omnibus test of every model term before
  the coefficients. Default `TRUE`; needs emmeans.

## Value

Invisibly returns the reported sentence(s) as a character vector; the
text is also emitted via
[`message()`](https://rdrr.io/r/base/message.html).

## Details

Only the location coefficients are reported: the thresholds (cut-points,
including the `threshold.1`/`spacing` parameters of equidistant
thresholds), scale effects and nominal effects are not predictor effects
on the location, so unlike
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
#> A cumulative link mixed model (logit link) was fitted for wine rating. Model terms were tested with Type III Wald $\chi^2$ tests. Coefficients are reported as odds ratios (OR) and are treatment contrasts against each factor's reference level.
#> The main effect of \textit{temp} on wine rating was significant ($\chi^2(1) = 26.47$, \pminor{0.001}).
#> The main effect of \textit{contact} on wine rating was significant ($\chi^2(1) = 12.82$, \pminor{0.001}).
#> The contrast \textit{warm} vs.\ \textit{cold} of \textit{temp} on wine rating was significant ($OR = 21.39$, 95\% CI $[6.66, 68.71]$, $z = 5.14$, \pminor{0.001}).
#> The contrast \textit{yes} vs.\ \textit{no} of \textit{contact} on wine rating was significant ($OR = 6.26$, 95\% CI $[2.29, 17.11]$, $z = 3.58$, \pminor{0.001}).
# }
```
