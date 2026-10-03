# Methods-section sentence justifying the test selection

Runs
[`check_normality_by_group()`](https://m-colley.github.io/colleyRstats/reference/check_normality_by_group.md)
(and optionally a test for homogeneity of variances) and turns the
outcome into a ready-made methods-section sentence that says what was
tested and reports the statistic the decision rests on. This is the
justification reviewers expect next to the choice of a parametric or
non-parametric test.

## Usage

``` r
assumption_methods_text(
  data,
  x,
  y,
  include_homogeneity = FALSE,
  subject = NULL
)
```

## Arguments

- data:

  the data frame

- x:

  the grouping variable (column name as string)

- y:

  the dependent variable (column name as string)

- include_homogeneity:

  whether to also report the homogeneity-of-variance test run by
  [`check_homogeneity_by_group()`](https://m-colley.github.io/colleyRstats/reference/check_homogeneity_by_group.md)
  (named as that function reports it: the Brown-Forsythe, i.e.
  median-centred Levene's, test). Between subjects only: with `subject`
  given it is skipped with a message, because equal variances across
  conditions are not an assumption of a repeated-measures analysis (its
  counterpart, sphericity, is tested and corrected by the ANOVA itself).
  Default `FALSE`.

- subject:

  the participant-ID column for a within-subjects design, as a string;
  `NULL` (default) for a between-subjects design. Passed to
  [`check_normality_by_group()`](https://m-colley.github.io/colleyRstats/reference/check_normality_by_group.md).

## Value

Invisibly returns the sentence(s) as a single string; the text is also
emitted via [`message()`](https://rdrr.io/r/base/message.html).

## Details

The sentence follows the check exactly:

- **Between subjects**: one Shapiro–Wilk test per group, Holm-corrected
  across the groups; the adjusted p-values are labelled \\p\_{Holm}\\. A
  rejection names the group(s) with their \\W\\ and p; otherwise the
  group with the smallest p is reported.

- **Within subjects** (`subject` given): one test on the paired
  differences (two conditions) or on the residuals of the additive
  participant + condition model (more conditions). Participants excluded
  for lacking a condition are counted in the text.

- A group that could not be tested (fewer than three values, or all
  values identical – e.g. everyone ticked the top of a rating scale) is
  named and stated to have been treated as non-normal, which sends the
  analysis to the non-parametric branch.

p-values are printed so that rounding never moves them across .05, .01
or .10, and all statistics are plain LaTeX math (no custom macros
needed).

## Examples

``` r
set.seed(1)
d <- data.frame(g = rep(c("A", "B"), each = 20), v = rnorm(40))
assumption_methods_text(d, x = "g", y = "v")
#> Shapiro--Wilk tests in each of the 2 groups of g (Holm-corrected for 2 tests) indicated no significant deviation from normality (smallest $p$: $W = 0.95$, $p_{\mathrm{Holm}} = 0.625$ for group A); therefore, parametric tests were used.

# within subjects: the paired differences are tested
d$id <- rep(1:20, times = 2)
assumption_methods_text(d, x = "g", y = "v", subject = "id")
#> A Shapiro--Wilk test on the within-participant differences between the two levels of g ($n = 20$) indicated no significant deviation from normality ($W = 0.95$, $p = 0.408$); therefore, parametric tests were used.
```
