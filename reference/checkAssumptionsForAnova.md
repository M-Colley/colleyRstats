# Check the assumptions for an ANOVA with a variable number of factors: Normality and Homogeneity of variance assumption.

Checks the normality and variance assumptions of a factorial ANOVA and
recommends the parametric or the non-parametric analysis. Every factor
is treated as categorical – numeric condition codes (1, 2, 3) included,
which [`stats::lm()`](https://rdrr.io/r/stats/lm.html) would otherwise
fit as a single linear covariate – and the message names the tests that
were run and their results.

## Usage

``` r
checkAssumptionsForAnova(data, y, factors, subject = NULL)

check_assumptions_anova(data, y, factors, subject = NULL)
```

## Arguments

- data:

  the data frame

- y:

  The dependent variable for which assumptions should be checked

- factors:

  A character vector of factor names

- subject:

  the participant-ID column for a design with within-subject factors, as
  a string; `NULL` (default) for a between-subjects design.

## Value

The guidance text (also emitted as a message), invisibly, with
attributes:

- `parametric`:

  `TRUE` if every check passed.

- `design`:

  `"between"`, `"within"` or `"mixed"`.

- `method`:

  named character vector naming the tests run (`residuals`, `groupwise`,
  `homogeneity`).

- `residuals`:

  the Shapiro-Wilk result on the model residuals (columns as in
  [`check_normality_by_group()`](https://m-colley.github.io/colleyRstats/reference/check_normality_by_group.md)'s
  `tests`).

- `groupwise`:

  between subjects: the per-cell Shapiro-Wilk results with Holm-adjusted
  p-values; `NULL` otherwise.

- `homogeneity`:

  the Brown-Forsythe result(s) (`df1`, `df2`, `statistic`, `p`,
  `p_adjusted`), or `NULL` when no between-subject factor exists.

## Details

- **Between subjects** (`subject = NULL`, the default): a Shapiro-Wilk
  test on the residuals of the linear model `y ~ A * B * ...`; a
  Shapiro-Wilk test within every cell of the design, Holm-corrected
  across the cells (as in
  [`check_normality_by_group()`](https://m-colley.github.io/colleyRstats/reference/check_normality_by_group.md));
  and the Brown-Forsythe test (median-centred Levene's test) across the
  cells. This assumes one row per participant: a within-subject factor
  analysed this way is tested on residuals that still contain each
  participant's overall level, so pass `subject` for repeated measures.

- **Within subjects or mixed** (`subject` given): a Shapiro-Wilk test on
  the residuals of `y ~ A * B * ... + subject`, with the participant as
  a fixed factor – the residuals after removing each participant's
  overall level, which is what a repeated-measures ANOVA assumes to be
  normal. The raw scores per cell are not tested, as they also carry the
  between-participant spread. Variance homogeneity is checked only for
  between-subject factors (those constant within a participant), with
  the Brown-Forsythe test across their groups at each combination of the
  within-subject factors (Holm-corrected). For within-subject factors
  the corresponding assumption is sphericity, which
  [`rstatix::anova_test()`](https://rpkgs.datanovia.com/rstatix/reference/anova_test.html)
  tests (Mauchly) and corrects (Greenhouse-Geisser) itself. More than
  one row per participant and cell is an error: aggregate repeated
  trials first.

A residual set or cell that cannot be tested – fewer than three values,
or no variance – counts as **not** normal, so the advice errs towards
the non-parametric analysis. Rows with a missing value in `y`, `factors`
or `subject` are left out.

## Naming

`check_assumptions_anova()` is the spelling used throughout the
documentation and the one to prefer in new code: the `report_*` /
`plot_*` / `check_*` prefixes make the API discoverable through
autocomplete.

`checkAssumptionsForAnova()` **\[superseded\]** is the original name.
Both names refer to the same function object, so they are entirely
interchangeable; the original remains fully supported and is not
scheduled for removal, and existing scripts keep working unchanged.

## Examples

``` r
# \donttest{
set.seed(123)

main_df <- data.frame(
  tlx_mental      = rnorm(40),
  Video           = factor(rep(c("A", "B"), each = 20)),
  DriverPosition  = factor(rep(c("Left", "Right"), times = 20))
)

checkAssumptionsForAnova(
  data    = main_df,
  y       = "tlx_mental",
  factors = c("Video", "DriverPosition")
)
#> You may take parametric ANOVA (function anova_test). Checks: Shapiro-Wilk on the residuals of tlx_mental ~ Video * DriverPosition: W = 0.988, p = 0.949; Shapiro-Wilk test per cell (Holm-adjusted): no cell deviates; Brown-Forsythe test (median-centred Levene's test): F(3, 36) = 0.54, p = 0.661. See https://www.datanovia.com/learn/biostatistics/anova/anova-in-r#check-assumptions-1 for more information.

# The same two factors measured within each of 10 participants
within_df <- expand.grid(
  id             = 1:10,
  Video          = c("A", "B"),
  DriverPosition = c("Left", "Right")
)
within_df$tlx_mental <- rnorm(10)[within_df$id] + rnorm(40)
checkAssumptionsForAnova(
  data    = within_df,
  y       = "tlx_mental",
  factors = c("Video", "DriverPosition"),
  subject = "id"
)
#> You may take parametric ANOVA (function anova_test). Checks: Shapiro-Wilk on the residuals of tlx_mental ~ Video * DriverPosition + id: W = 0.988, p = 0.941; sphericity of the within-subject factor(s) Video, DriverPosition is tested (Mauchly) and corrected (Greenhouse-Geisser) by rstatix::anova_test(). See https://www.datanovia.com/learn/biostatistics/anova/anova-in-r#check-assumptions-1 for more information.
# }
```
