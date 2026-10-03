# Check normality for groups

Decides between a parametric and a non-parametric analysis from
Shapiro-Wilk tests, testing the quantity the parametric test actually
assumes to be normal.

## Usage

``` r
check_normality_by_group(data, x, y, subject = NULL, p_adjust = "holm")
```

## Arguments

- data:

  the data frame

- x:

  the grouping (condition) column, as a string

- y:

  the outcome column, as a string

- subject:

  the participant-ID column for a within-subjects design, as a string;
  `NULL` (default) for a between-subjects design.

- p_adjust:

  multiplicity correction across groups, passed to
  [`stats::p.adjust()`](https://rdrr.io/r/stats/p.adjust.html). Default
  `"holm"`; only used between subjects.

## Value

`TRUE` if no test rejects normality and every group could be tested,
`FALSE` otherwise. Attributes:

- `tests`:

  data frame with columns `group` (the condition, or `"differences"` /
  `"residuals"` within subjects), `n`, `W`, `p_value`, `p_adjusted` and
  `testable`, e.g. for
  [`assumption_methods_text()`](https://m-colley.github.io/colleyRstats/reference/assumption_methods_text.md).

- `method`:

  `"groupwise"`, `"differences"` or `"residuals"`.

- `p_adjust`:

  the correction applied (`"none"` for a single test).

- `untestable`:

  the groups that could not be tested.

- `dropped_subjects`:

  within subjects: the participants left out for lacking a condition.

For a group with more than 5000 values, Shapiro-Wilk is computed on a
random sample of 5000 (a warning is emitted), so the result is only
reproducible with a seed set beforehand.

## Details

- **Between subjects** (`subject = NULL`): one test per group, with the
  p-values corrected for the number of groups (`p_adjust`, Holm by
  default). Without the correction, six perfectly normal groups would
  send about one analysis in four to the non-parametric branch by chance
  alone.

- **Within subjects** (`subject` given): a paired t-test assumes the
  *differences* are normal, and a repeated-measures ANOVA the
  *residuals* after removing participant and condition effects – not the
  raw scores per condition, which also carry the between-participant
  spread. With two conditions the per-participant differences are
  tested; with more, the residuals of the additive model
  `y ~ x + subject`. Participants lacking any condition are left out
  (they cannot enter a paired analysis), and more than one row per
  participant and condition is an error.

A group that cannot be tested – fewer than three values, or no variance
at all, as in a rating scale where everyone ticked the top box – counts
as **not** normal, so the decision errs towards the non-parametric test
rather than letting an untestable group pass silently.

Testing assumptions with significance tests has well-known limits (low
power in small samples, trivial deviations flagged in large ones);
report the check, and treat it as one input to the choice rather than
the whole of it.

## Examples

``` r
set.seed(1)
d <- data.frame(id = rep(1:20, 2), cond = rep(c("A", "B"), each = 20))
d$score <- rnorm(40, mean = ifelse(d$cond == "A", 5, 6))
check_normality_by_group(d, "cond", "score")                  # between
#> [1] TRUE
#> attr(,"tests")
#>   group  n         W   p_value p_adjusted testable
#> 1     A 20 0.9532694 0.4194558  0.6253101     TRUE
#> 2     B 20 0.9461695 0.3126550  0.6253101     TRUE
#> attr(,"method")
#> [1] "groupwise"
#> attr(,"p_adjust")
#> [1] "holm"
#> attr(,"untestable")
#> character(0)
check_normality_by_group(d, "cond", "score", subject = "id")  # within
#> [1] TRUE
#> attr(,"tests")
#>         group  n         W   p_value p_adjusted testable
#> 1 differences 20 0.9525815 0.4079824  0.4079824     TRUE
#> attr(,"method")
#> [1] "differences"
#> attr(,"p_adjust")
#> [1] "none"
#> attr(,"untestable")
#> character(0)
#> attr(,"dropped_subjects")
#> character(0)
```
