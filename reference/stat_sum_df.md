# Generating the sum and adding a crossbar.

Generating the sum and adding a crossbar.

## Usage

``` r
stat_sum_df(fun, geom = "crossbar", ...)
```

## Arguments

- fun:

  function

- geom:

  geom to be shown

- ...:

  Additional arguments passed to stat_summary

## Value

A `ggplot2` layer that can be added to a ggplot object.

## Examples

``` r
# \donttest{
  # Simple summary function: use the mean as y, ymin, and ymax
  mean_fun <- function(x) {
    m <- mean(x, na.rm = TRUE)
    data.frame(y = m, ymin = m, ymax = m)
  }

  ggplot2::ggplot(mtcars, ggplot2::aes(x = factor(cyl), y = mpg)) +
    stat_sum_df(mean_fun)

# }
```
