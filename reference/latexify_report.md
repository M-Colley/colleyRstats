# Transform text from `report::report()` into LaTeX-friendly output.

This function transforms the text output from
[`report::report()`](https://easystats.github.io/report/reference/report.html)
by performing several substitutions to prepare the text for LaTeX
typesetting. In particular, it replaces instances of `R2`, `%`, and `~`
with the corresponding LaTeX code. Additionally, it provides options to:

- Omit bullet items marked as "non-significant" (when
  `only_sig = TRUE`).

- Remove a concluding note about standardized parameters (when
  `remove_std = TRUE`).

- Wrap bullet items in a LaTeX `itemize` environment or leave them as
  plain text (controlled by `itemize`).

## Usage

``` r
latexify_report(
  x,
  print_result = TRUE,
  only_sig = FALSE,
  remove_std = FALSE,
  itemize = TRUE
)
```

## Arguments

- x:

  Character vector or a single string containing the report text.

- print_result:

  Logical. If `TRUE` (default), the formatted text is printed to the
  console.

- only_sig:

  Logical. If `TRUE`, bullet items containing "non-significant" are
  omitted. Default is `FALSE`.

- remove_std:

  Logical. If `TRUE`, the final standardized parameters note is removed.
  Default is `FALSE`.

- itemize:

  Logical. If `TRUE` (default), bullet items are wrapped in a LaTeX
  `itemize` environment; otherwise the bullet markers are simply
  removed.

## Value

A single string with the LaTeX-friendly formatted report text.

## Examples

``` r
# \donttest{
if (requireNamespace("report", quietly = TRUE)) {
  # Simple linear model on the iris dataset
  model <- stats::lm(
    Sepal.Length ~ Sepal.Width + Petal.Length,
    data = datasets::iris
  )

  # Format the report output, showing only significant items, removing the
  # standard note, and wrapping bullet items in an itemize environment.
  report_text <- try(report::report(model), silent = TRUE)
  if (!inherits(report_text, "try-error")) {
    latexify_report(
      report_text,
      only_sig = TRUE,
      remove_std = TRUE,
      itemize = TRUE
    )
  }
}
#> We fitted a linear model (estimated using OLS) to predict Sepal.Length with Sepal.Width and Petal.Length (formula: Sepal.Length $\sim$ Sepal.Width + Petal.Length). The model explains a statistically significant and substantial proportion of variance ($R^2$ = 0.84, F(2, 147) = 386.39, p < .001, adj. $R^2$ = 0.84). The model's intercept, corresponding to Sepal.Width = 0 and Petal.Length = 0, is at 2.25 (95\% CI [1.76, 2.74], t(147) = 9.07, p < .001). Within this model:
#> 
#> \begin{itemize}
#> \item The effect of Sepal Width is statistically significant and positive (beta = 0.60, 95\% CI [0.46, 0.73], t(147) = 8.59, p < .001; Std. beta = 0.31, 95\% CI [0.24, 0.39])
#> \item The effect of Petal Length is statistically significant and positive (beta = 0.47, 95\% CI [0.44, 0.51], t(147) = 27.57, p < .001; Std. beta = 1.01, 95\% CI [0.93, 1.08])
#> \end{itemize}
#> 
# }
```
