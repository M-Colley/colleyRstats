# Calculation based on Rosenthal's formula (1994). N stands for the *number of measurements*.

Calculation based on Rosenthal's formula (1994). N stands for the
*number of measurements*.

## Usage

``` r
rFromWilcox(wilcoxModel, N)
```

## Arguments

- wilcoxModel:

  the Wilcox model

- N:

  number of measurements in the experiment

## Value

Invisibly returns a list with components:

- `r`: effect size as a numeric scalar.

- `z`: corresponding z-statistic.

- `text`: character string that is also sent to the console.

## Examples

``` r
set.seed(1)
d <- data.frame(
  group = rep(c("A", "B"), each = 10),
  value = rnorm(20)
)
w <- stats::wilcox.test(value ~ group, data = d, exact = FALSE)
rFromWilcox(w, N = nrow(d))
#> value by group Effect Size, r = 0.177, z = -0.794
```
