# Report a (generalized) linear mixed model in LaTeX/APA style

Turns a fitted mixed model into ready-to-paste manuscript sentences, one
per fixed-effect term, with the coefficient (or odds/incidence-rate
ratio for non-Gaussian families), its confidence interval, the test
statistic, and the p-value. Works with linear mixed models
([`lme4::lmer`](https://rdrr.io/pkg/lme4/man/lmer.html)), generalized
linear mixed models
([`lme4::glmer`](https://rdrr.io/pkg/lme4/man/glmer.html),
[`glmmTMB::glmmTMB`](https://rdrr.io/pkg/glmmTMB/man/glmmTMB.html)) and,
for convenience, ordinary `lm`/`glm` fits. Coefficients are
exponentiated automatically for binomial (odds ratios) and
Poisson/negative- binomial (incidence-rate ratios) families.

## Usage

``` r
reportGLMM(
  model,
  dv = "Testdependentvariable",
  exponentiate = "auto",
  include_intercept = FALSE,
  conf_level = 0.95,
  write_to_clipboard = FALSE,
  sink_to = NULL
)

report_glmm(
  model,
  dv = "Testdependentvariable",
  exponentiate = "auto",
  include_intercept = FALSE,
  conf_level = 0.95,
  write_to_clipboard = FALSE,
  sink_to = NULL
)
```

## Arguments

- model:

  A fitted model (`lmer`, `glmer`, `glmmTMB`, `lm`, or `glm`).

- dv:

  Name of the dependent variable, used in the sentence text.

- exponentiate:

  `"auto"` (default; exponentiate for binomial and count families), or
  `TRUE`/`FALSE` to force it.

- include_intercept:

  Whether to also report the intercept. Default `FALSE`.

- conf_level:

  Confidence level for the intervals. Default 0.95.

- write_to_clipboard:

  Whether to copy the sentences to the clipboard.

- sink_to:

  Optional path of a `.tex` file to write the sentences to, so a
  manuscript can `\input{}` them.

## Value

Invisibly returns the reported sentence(s) as a character vector; the
text is also emitted via
[`message()`](https://rdrr.io/r/base/message.html).

## Details

The reported statistics rely on the parameters package. The LaTeX output
uses the `\p`/`\pminor` macros from
[`latex_preamble()`](https://m-colley.github.io/colleyRstats/reference/latex_preamble.md).

## Naming

`report_glmm()` is the spelling used throughout the documentation and
the one to prefer in new code: the `report_*` / `plot_*` / `check_*`
prefixes make the API discoverable through autocomplete.

`reportGLMM()` **\[superseded\]** is the original name. Both names refer
to the same function object, so they are entirely interchangeable; the
original remains fully supported and is not scheduled for removal, and
existing scripts keep working unchanged.

## Examples

``` r
# \donttest{
if (requireNamespace("lme4", quietly = TRUE) &&
  requireNamespace("parameters", quietly = TRUE)) {
  m <- lme4::lmer(Reaction ~ Days + (1 | Subject), data = lme4::sleepstudy)
  reportGLMM(m, dv = "reaction time")
}
#> A linear mixed model was fitted for reaction time.
#> The effect of \textit{Days} on reaction time was significant ($b = 10.47$, 95\% CI $[8.88, 12.05]$, $t(176) = 13.02$, \pminor{0.001}).
# }
```
