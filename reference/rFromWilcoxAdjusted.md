# Effect size r from a multiplicity-inflated Wilcoxon p-value (deprecated)

**\[deprecated\]**

This function is deprecated because the quantity it returns is not an
effect size. It multiplies the p-value by `adjustFactor` before
converting it to \\r\\, which shrinks \\r\\ towards zero as the number
of comparisons grows (\\r = 0.34\\ becomes 0.21 with six comparisons and
0 with forty) although the effect itself is unchanged. Multiplicity
corrections belong to the p-values, which decide significance; an effect
size describes the magnitude of one comparison and is reported
unadjusted. Adjust the p-values with
[`stats::p.adjust()`](https://rdrr.io/r/stats/p.adjust.html) and compute
\\r\\ with
[`rFromWilcox()`](https://m-colley.github.io/colleyRstats/reference/rFromWilcox.md).
The old value is still returned for compatibility.

## Usage

``` r
rFromWilcoxAdjusted(wilcoxModel, N, adjustFactor)
```

## Arguments

- wilcoxModel:

  the Wilcox model; its `alternative` is taken into account as in
  [`rFromWilcox()`](https://m-colley.github.io/colleyRstats/reference/rFromWilcox.md).

- N:

  number of measurements in the experiment

- adjustFactor:

  the factor the p-value is multiplied by (the number of comparisons).

## Value

Invisibly returns a list with components:

- `r`: the shrunken "effect size" as a numeric scalar.

- `z`: the z-statistic of the inflated p-value.

- `text`: character string that is also sent to the console.

## Examples

``` r
# \donttest{
set.seed(1)
d <- data.frame(
  group = rep(c("A", "B"), each = 10),
  value = rnorm(20)
)
w <- stats::wilcox.test(value ~ group, data = d, exact = FALSE)
# Instead of rFromWilcoxAdjusted(w, N = nrow(d), adjustFactor = 2):
stats::p.adjust(w$p.value, method = "bonferroni", n = 2)
#> [1] 0.8547106
rFromWilcox(w, N = nrow(d))
#> value by group Effect Size, r = 0.177, z = -0.794
# }
```
