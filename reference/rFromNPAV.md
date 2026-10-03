# Calculation based on Rosenthal's formula (1994). N stands for the *number of measurements*.

Computes \\r = \|z\| / \sqrt{N}\\ with \\z = \Phi^{-1}(p/2)\\ for a
two-sided p-value, or \\z = \Phi^{-1}(p)\\ for a one-sided one
(`alternative = "less"` or `"greater"`).

## Usage

``` r
rFromNPAV(pvalue, N, alternative = "two.sided", df1 = NULL)
```

## Arguments

- pvalue:

  p value

- N:

  number of measurements in the experiment

- alternative:

  `"two.sided"` (default), `"less"` or `"greater"`: the alternative of
  the test that produced `pvalue`.

- df1:

  optional numerator degrees of freedom of the \\F\\ test that produced
  `pvalue`; a value above 1 triggers a warning (see Details).

## Value

Invisibly returns a list with components:

- `r`: effect size as a numeric scalar.

- `z`: corresponding z-statistic.

- `text`: LaTeX-formatted character string that is also sent to the
  console.

## Details

The conversion is defined for *focused* tests with a single degree of
freedom (Rosenthal, 1994). The p-value of an \\F\\ test with one
numerator degree of freedom equals the two-sided p-value of the matching
\\t\\ test, so the default is right for such effects. An omnibus \\F\\
test with more than one numerator degree of freedom – a main effect of a
three-level factor, say – has no single direction and no \\z\\
equivalent: its p-value converts to a number, but not to the effect size
\\r\\ of anything. Pass `df1` to be warned in that case, and report
partial eta squared for such effects instead (as
[`reportNPAV()`](https://m-colley.github.io/colleyRstats/reference/reportNPAV.md)
and
[`reportART()`](https://m-colley.github.io/colleyRstats/reference/reportART.md)
do).

Necessary LaTeX command: `\newcommand{\effectsize}{\textit{r=}}`

## References

Rosenthal, R. (1994). Parametric measures of effect size. In H. Cooper &
L. V. Hedges (Eds.), *The handbook of research synthesis* (pp. 231–244).
Russell Sage Foundation.

## Examples

``` r
rFromNPAV(0.02, N = 180)
#> \effectsize{0.173}, Z=-2.33
```
