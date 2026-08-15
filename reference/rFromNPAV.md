# Calculation based on Rosenthal's formula (1994). N stands for the *number of measurements*.

Necessary LaTeX command: `\newcommand{\effectsize}{\textit{r=}}`

## Usage

``` r
rFromNPAV(pvalue, N)
```

## Arguments

- pvalue:

  p value

- N:

  number of measurements in the experiment

## Value

Invisibly returns a list with components:

- `r`: effect size as a numeric scalar.

- `z`: corresponding z-statistic.

- `text`: LaTeX-formatted character string that is also sent to the
  console.

## Examples

``` r
rFromNPAV(0.02, N = 180)
#> \effectsize{0.173}, Z=-2.33
```
