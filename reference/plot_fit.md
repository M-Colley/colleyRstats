# Plot observations with the tests from a fitted analysis

Draws the analyzed observations and annotates them with the model and
omnibus tests stored by
[`fit_recommended()`](https://m-colley.github.io/colleyRstats/reference/fit_recommended.md).
No model, assumption check or significance test is run while building
the figure. The annotations therefore describe the same fit as the
manuscript sentences.

## Usage

``` r
plot_fit(fit, x = NULL, ylab = NULL, xlabels = NULL, show_test = TRUE)
```

## Arguments

- fit:

  A `colley_fit` returned by
  [`fit_recommended()`](https://m-colley.github.io/colleyRstats/reference/fit_recommended.md).

- x:

  Predictor column to display. Defaults to the first predictor; an
  intercept-only fit is displayed as one group.

- ylab:

  Outcome axis label. Defaults to the outcome column name.

- xlabels:

  Optional labels for a categorical predictor, in factor order.

- show_test:

  Logical. Include the stored omnibus statistics in the subtitle. The
  model name is always shown.

## Value

A ggplot object. It can be saved with
[`save_paper_figure()`](https://m-colley.github.io/colleyRstats/reference/save_paper_figure.md)
or combined with other plots using patchwork.

## Details

For a categorical predictor and a numeric continuous/count outcome,
repeated observations are averaged per cluster and predictor level for
display. These are descriptive means, not model predictions or
confidence intervals. Ordinal, binary and nominal responses are shown as
counts of observed responses without averaging categories. Numeric
predictors are shown as scatterplots. Other predictors remain in the
fitted model whose tests are printed in the subtitle.

## See also

[`fit_recommended()`](https://m-colley.github.io/colleyRstats/reference/fit_recommended.md)

## Examples

``` r
# \donttest{
fit <- fit_recommended(iris, "Sepal.Length", "Species",
                       outcome_type = "continuous", verbose = FALSE)
plot_fit(fit)

# }
```
