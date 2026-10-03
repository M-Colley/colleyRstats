# Check the data's distribution. If non-normal, take the non-parametric variant of *ggbetweenstats*. x and y have to be in parentheses, e.g., "ConditionID".

As
[`ggbetweenstatsWithPriorNormalityCheck()`](https://m-colley.github.io/colleyRstats/reference/ggbetweenstatsWithPriorNormalityCheck.md),
but the significant comparisons are drawn as asterisk brackets (\*\*\* p
\< .001, \*\* p \< .01,

- p \< .05) instead of p-values. The brackets come from the same test as
  the figure: with two groups, the omnibus test in the subtitle
  (ggstatsplot runs no post-hoc test then, and a second test of the same
  pair could disagree with it); with more, the Holm-adjusted
  Games-Howell (parametric) or Dunn (non-parametric) tests ggstatsplot
  itself would compute.

## Usage

``` r
ggbetweenstatsWithPriorNormalityCheckAsterisk(
  data,
  x,
  y,
  ylab,
  xlabels,
  plotType = "boxviolin"
)

plot_between_stats_asterisk(data, x, y, ylab, xlabels, plotType = "boxviolin")
```

## Arguments

- data:

  the data frame

- x:

  the independent variable, most likely "ConditionID"

- y:

  the dependent variable under investigation

- ylab:

  label to be shown for the dependent variable

- xlabels:

  labels to be used for the x-axis

- plotType:

  either "box", "violin", or "boxviolin" (default)

## Value

A `ggplot` object produced by
[`ggstatsplot::ggbetweenstats`](https://www.indrapatil.com/ggstatsplot/reference/ggbetweenstats.html)
with additional significance annotations, which can be printed or
modified.

## Naming

`plot_between_stats_asterisk()` is the spelling used throughout the
documentation and the one to prefer in new code: the `report_*` /
`plot_*` / `check_*` prefixes make the API discoverable through
autocomplete.

`ggbetweenstatsWithPriorNormalityCheckAsterisk()` **\[superseded\]** is
the original name. Both names refer to the same function object, so they
are entirely interchangeable; the original remains fully supported and
is not scheduled for removal, and existing scripts keep working
unchanged.

## Examples

``` r
# \donttest{

set.seed(123)

# Toy between-subject data: each participant sees one condition
main_df <- data.frame(
  CondID      = factor(rep(c("A", "B", "C"), each = 20)),
  tlx_mental  = rnorm(60, mean = 50, sd = 10)
)

# Custom x-axis labels
labels_xlab <- c("Condition A", "Condition B", "Condition C")


ggbetweenstatsWithPriorNormalityCheckAsterisk(
  data = main_df,
  x = "CondID", y = "tlx_mental", ylab = "Mental Demand", xlabels = labels_xlab
)
#> Scale for x is already present.
#> Adding another scale for x, which will replace the existing scale.

# }
```
