# Check the data's distribution. If non-normal, take the non-parametric variant of *ggbetweenstats*. x and y have to be in parentheses, e.g., "ConditionID".

For independent groups: one row per participant. If the group-wise
normality check
([`check_normality_by_group()`](https://m-colley.github.io/colleyRstats/reference/check_normality_by_group.md))
passes, ggstatsplot runs Welch's t-test (two groups) or Welch's one-way
ANOVA with Games-Howell post-hoc tests and labels the means; none of
these assume equal variances, which is why no Levene test is run.
Otherwise it runs a Wilcoxon rank-sum (Mann-Whitney) or Kruskal-Wallis
test with Dunn post-hoc tests and labels the medians. Post-hoc p-values
are Holm-adjusted. Rows without a group or an outcome are dropped, and
the grouping column is treated as a factor, so numeric condition codes
are categories.

## Usage

``` r
ggbetweenstatsWithPriorNormalityCheck(
  data,
  x,
  y,
  ylab,
  xlabels = NULL,
  showPairwiseComp = TRUE,
  plotType = "boxviolin"
)

plot_between_stats(
  data,
  x,
  y,
  ylab,
  xlabels = NULL,
  showPairwiseComp = TRUE,
  plotType = "boxviolin"
)
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

- showPairwiseComp:

  whether to show the significant pairwise comparisons (`TRUE`, default)
  or none (`FALSE`). With `FALSE` no pairwise table is computed either,
  so
  [`reportggstatsplotPostHoc()`](https://m-colley.github.io/colleyRstats/reference/reportggstatsplotPostHoc.md)
  has nothing to report from the plot.

- plotType:

  either "box", "violin", or "boxviolin" (default)

## Value

A `ggplot` object produced by
[`ggstatsplot::ggbetweenstats`](https://www.indrapatil.com/ggstatsplot/reference/ggbetweenstats.html),
which can be printed or further modified with `+`.

## Naming

`plot_between_stats()` is the spelling used throughout the documentation
and the one to prefer in new code: the `report_*` / `plot_*` / `check_*`
prefixes make the API discoverable through autocomplete.

`ggbetweenstatsWithPriorNormalityCheck()` **\[superseded\]** is the
original name. Both names refer to the same function object, so they are
entirely interchangeable; the original remains fully supported and is
not scheduled for removal, and existing scripts keep working unchanged.

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


ggbetweenstatsWithPriorNormalityCheck(
  data = main_df,
  x = "CondID",
  y = "tlx_mental", ylab = "Mental Demand",
  xlabels = labels_xlab,
  showPairwiseComp = TRUE
)
#> Scale for x is already present.
#> Adding another scale for x, which will replace the existing scale.

# }
```
