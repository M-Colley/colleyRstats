# Check the assumptions for an ANOVA with a variable number of factors: Normality and Homogeneity of variance assumption.

Check the assumptions for an ANOVA with a variable number of factors:
Normality and Homogeneity of variance assumption.

## Usage

``` r
checkAssumptionsForAnova(data, y, factors)

check_assumptions_anova(data, y, factors)
```

## Arguments

- data:

  the data frame

- y:

  The dependent variable for which assumptions should be checked

- factors:

  A character vector of factor names

## Value

A message indicating whether to use parametric or non-parametric ANOVA

## Naming

`check_assumptions_anova()` is the spelling used throughout the
documentation and the one to prefer in new code: the `report_*` /
`plot_*` / `check_*` prefixes make the API discoverable through
autocomplete.

`checkAssumptionsForAnova()` **\[superseded\]** is the original name.
Both names refer to the same function object, so they are entirely
interchangeable; the original remains fully supported and is not
scheduled for removal, and existing scripts keep working unchanged.

## Examples

``` r
# \donttest{
set.seed(123)

main_df <- data.frame(
  tlx_mental      = rnorm(40),
  Video           = factor(rep(c("A", "B"), each = 20)),
  DriverPosition  = factor(rep(c("Left", "Right"), times = 20))
)

checkAssumptionsForAnova(
  data    = main_df,
  y       = "tlx_mental",
  factors = c("Video", "DriverPosition")
)
#> You may take parametric ANOVA (function anova_test). See https://www.datanovia.com/learn/biostatistics/anova/anova-in-r#check-assumptions-1 for more information.
# }
```
