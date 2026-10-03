# Check the data's distribution. If non-normal, take the non-parametric variant of *ggwithinstats*. x and y have to be in parentheses, e.g., "ConditionID".

Observations are paired by the participant ID in `subject`, never by row
order. Before anything is computed, rows without a condition, outcome or
ID are dropped, participants lacking any condition are left out (with a
message saying how many and which), and more than one row per
participant and condition is an error – aggregate repeated trials first.
The normality check
([`check_normality_by_group()`](https://m-colley.github.io/colleyRstats/reference/check_normality_by_group.md)
with `subject`, i.e. on the paired differences or on the residuals of
the repeated-measures model), the figure and the pairwise tests all use
this same data. The condition column is treated as a factor, so numeric
condition codes are categories.

## Usage

``` r
ggwithinstatsWithPriorNormalityCheck(
  data,
  x,
  y,
  ylab,
  xlabels = NULL,
  showPairwiseComp = TRUE,
  plotType = "boxviolin",
  subject
)

plot_within_stats(
  data,
  x,
  y,
  ylab,
  xlabels = NULL,
  showPairwiseComp = TRUE,
  plotType = "boxviolin",
  subject
)
```

## Arguments

- data:

  the data frame, in long format (one row per participant and condition)

- x:

  the independent variable, most likely "ConditionID"

- y:

  the dependent variable under investigation

- ylab:

  label to be shown for the dependent variable

- xlabels:

  labels to be used for the x-axis

- showPairwiseComp:

  whether to show the significant pairwise comparisons (`TRUE`, default)
  or none (`FALSE`). With `FALSE` no pairwise table is computed either,
  so
  [`reportggstatsplotPostHoc()`](https://m-colley.github.io/colleyRstats/reference/reportggstatsplotPostHoc.md)
  has nothing to report from the plot.

- plotType:

  either "box", "violin", or "boxviolin" (default)

- subject:

  the participant-ID column, as a string (e.g. `"participant"`).
  Required. It is the last argument so that existing positional calls
  keep their meaning.

## Value

A `ggplot` object produced by
[`ggstatsplot::ggwithinstats`](https://www.indrapatil.com/ggstatsplot/reference/ggwithinstats.html)
with additional significance annotations, which can be printed or
modified.

## Details

If the check passes, ggstatsplot runs a paired t-test (two conditions)
or a repeated-measures ANOVA with paired Student's t post-hoc tests, and
labels the means; otherwise a Wilcoxon signed-rank or Friedman test with
Durbin-Conover post-hoc tests, and labels the medians. Post-hoc p-values
are Holm-adjusted.

## Naming

`plot_within_stats()` is the spelling used throughout the documentation
and the one to prefer in new code: the `report_*` / `plot_*` / `check_*`
prefixes make the API discoverable through autocomplete.

`ggwithinstatsWithPriorNormalityCheck()` **\[superseded\]** is the
original name. Both names refer to the same function object, so they are
entirely interchangeable; the original remains fully supported and is
not scheduled for removal, and existing scripts keep working unchanged.

## Examples

``` r
# \donttest{

set.seed(123)

# Toy within-subject data: every participant sees every condition
main_df <- data.frame(
  Participant = factor(rep(1:20, each = 3)),
  CondID      = factor(rep(c("A", "B", "C"), times = 20)),
  tlx_mental  = rnorm(60, mean = 50, sd = 10)
)

# Custom x-axis labels
labels_xlab <- c("Condition A", "Condition B", "Condition C")


ggwithinstatsWithPriorNormalityCheck(
  data = main_df,
  x = "CondID", y = "tlx_mental",
  ylab = "Mental Demand",
  xlabels = labels_xlab,
  showPairwiseComp = TRUE,
  subject = "Participant"
)
#> Scale for x is already present.
#> Adding another scale for x, which will replace the existing scale.

# }
```
