# Calculation based on Rosenthal's formula (1994). N stands for the *number of measurements*.

Computes \\r = \|z\| / \sqrt{N}\\, recovering \\z\\ from the test's
p-value. A two-sided p-value splits its probability over both tails, so
\\z = \Phi^{-1}(p/2)\\; a one-sided test (`alternative = "less"` or
`"greater"`, read from the test object) has it all in one tail, so \\z =
\Phi^{-1}(p)\\. Halving a one-sided p-value, as this function did before
0.3.0, overstates \\\|z\|\\ and therefore \\r\\.

## Usage

``` r
rFromWilcox(wilcoxModel, N)
```

## Arguments

- wilcoxModel:

  the Wilcox model (an `htest` object from
  [`stats::wilcox.test()`](https://rdrr.io/r/stats/wilcox.test.html));
  its `alternative` is taken into account.

- N:

  number of measurements in the experiment

## Value

Invisibly returns a list with components:

- `r`: effect size as a numeric scalar.

- `z`: corresponding z-statistic.

- `text`: character string that is also sent to the console.

## Details

\\r\\ is returned as a magnitude (non-negative); read the direction of
the effect from the data. With an exact p-value (small samples without
ties) the recovered \\z\\ is the normal deviate matching that p-value
rather than the test's normal-approximation statistic.

## References

Rosenthal, R. (1994). Parametric measures of effect size. In H. Cooper &
L. V. Hedges (Eds.), *The handbook of research synthesis* (pp. 231–244).
Russell Sage Foundation.

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
