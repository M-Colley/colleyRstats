# rFromWilcoxAdjusted

rFromWilcoxAdjusted

## Usage

``` r
rFromWilcoxAdjusted(wilcoxModel, N, adjustFactor)
```

## Arguments

- wilcoxModel:

  the Wilcox model

- N:

  number of measurements in the experiment

- adjustFactor:

  ad adjustment factor

## Value

Invisibly returns a list with components:

- `r`: adjusted effect size as a numeric scalar.

- `z`: adjusted z-statistic.

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
rFromWilcoxAdjusted(w, N = nrow(d), adjustFactor = 2)
#> value by group Effect Size, r = 0.041, z = -0.183
# }
```
