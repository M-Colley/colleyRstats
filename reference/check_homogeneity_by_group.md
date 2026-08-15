# Check homogeneity of variances across groups

Check homogeneity of variances across groups

## Usage

``` r
check_homogeneity_by_group(data, x, y)
```

## Arguments

- data:

  the data frame

- x:

  the grouping variable (column name as string)

- y:

  the dependent variable (column name as string)

## Value

TRUE if Levene's test is non-significant (p \>= .05), FALSE otherwise.
The Levene test result (columns `df1`, `df2`, `statistic`, `p`) is
attached in the `"test"` attribute, e.g. for use in a methods section
via
[`assumption_methods_text()`](https://m-colley.github.io/colleyRstats/reference/assumption_methods_text.md).
