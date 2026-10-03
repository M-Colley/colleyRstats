# Report a (generalized) linear mixed model in LaTeX/APA style

Turns a fitted mixed model into ready-to-paste manuscript sentences:
first a Type III omnibus test per model term (main effects and
interactions), then one sentence per fixed-effect coefficient with its
estimate (or odds / incidence-rate ratio), confidence interval, test
statistic and p-value. Works with linear mixed models
([`lme4::lmer`](https://rdrr.io/pkg/lme4/man/lmer.html),
[`lmerTest::lmer`](https://rdrr.io/pkg/lmerTest/man/lmer.html)),
generalized linear mixed models
([`lme4::glmer`](https://rdrr.io/pkg/lme4/man/glmer.html),
[`glmmTMB::glmmTMB`](https://rdrr.io/pkg/glmmTMB/man/glmmTMB.html)) and,
for convenience, ordinary `lm`, `glm` and
[`MASS::glm.nb`](https://rdrr.io/pkg/MASS/man/glm.nb.html) fits.

## Usage

``` r
reportGLMM(
  model,
  dv = "Testdependentvariable",
  exponentiate = "auto",
  include_intercept = FALSE,
  conf_level = 0.95,
  write_to_clipboard = FALSE,
  sink_to = NULL,
  omnibus = TRUE
)

report_glmm(
  model,
  dv = "Testdependentvariable",
  exponentiate = "auto",
  include_intercept = FALSE,
  conf_level = 0.95,
  write_to_clipboard = FALSE,
  sink_to = NULL,
  omnibus = TRUE
)
```

## Arguments

- model:

  A fitted model (`lmer`, `glmer`, `glmmTMB`, `lm`, `glm`, or `glm.nb`).

- dv:

  Name of the dependent variable, used in the sentence text.

- exponentiate:

  `"auto"` (default; exponentiate for logit-link binomial and log-link
  count families), or `TRUE`/`FALSE` to force it.

- include_intercept:

  Whether to also report the intercept. Default `FALSE`.

- conf_level:

  Confidence level for the intervals. Default 0.95.

- write_to_clipboard:

  Whether to copy the sentences to the clipboard.

- sink_to:

  Optional path of a `.tex` file to write the sentences to, so a
  manuscript can `\input{}` them.

- omnibus:

  Logical. Report the Type III omnibus test of every model term before
  the coefficients. Default `TRUE`; needs lmerTest (linear mixed models)
  or emmeans (all other models).

## Value

Invisibly returns the reported sentence(s) as a character vector; the
text is also emitted via
[`message()`](https://rdrr.io/r/base/message.html).

## Details

**Omnibus tests.** With treatment (dummy) coding – R's default – a
coefficient such as `aa2` in `y ~ a * b` is the a2 - a1 difference *at
the reference level of b*, not "the effect of a", and a factor with
three or more levels has no single coefficient at all. The omnibus tests
answer the questions a results section asks: for linear mixed models,
lmerTest's Type III \\F\\-tests with Satterthwaite's degrees of freedom;
for all other models,
[`emmeans::joint_tests()`](https://rvlenth.github.io/emmeans/reference/joint_tests.html)
(Type III Wald \\F\\ for `lm`, Wald \\\chi^2\\ otherwise). Both are
independent of the contrast coding. The coefficient sentences that
follow are labelled as what they are, e.g. "the contrast a2 vs. a1 of a
(at b = b1)", "the slope of age (at cond = A)".

**Degrees of freedom.** Coefficient \\t\\-tests of linear mixed models
use Satterthwaite's degrees of freedom (lmerTest; the asymptotic normal
approximation when it is not installed), and the sentence says so –
never the residual degrees of freedom.

**Effect labels.** Coefficients are exponentiated automatically only
where the ratio has a name: odds ratios (OR) for a logit link, risk
ratios (RR) for a binomial log link, incidence-rate ratios (IRR) for a
log-link count family (Poisson, negative binomial). Other links (probit,
cloglog, identity) report the raw coefficient and name the link. Only
the conditional-mean (location) coefficients are reported:
zero-inflation, dispersion and scale parameters are not predictor
effects on the mean.

The reported statistics rely on the parameters package. The LaTeX output
uses the `\p`/`\pminor` and `\F` macros from
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
#> A linear mixed model was fitted for reaction time. Model terms were tested with Type III $F$-tests and coefficients with $t$-tests, using Satterthwaite's degrees of freedom. Coefficients are treatment contrasts against each factor's reference level.
#> The main effect of \textit{Days} on reaction time was significant (\F{1}{161}{169.40}, \pminor{0.001}).
#> The slope of \textit{Days} on reaction time was significant ($b = 10.47$, 95\% CI $[8.88, 12.06]$, $t(161) = 13.02$, \pminor{0.001}).
# }
```
