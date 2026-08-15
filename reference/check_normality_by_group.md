# Check normality for groups

Check normality for groups

## Usage

``` r
check_normality_by_group(data, x, y)
```

## Arguments

- data:

  the data frame

- x:

  the x column

- y:

  the y column

## Value

TRUE if all groups are normal, FALSE otherwise. The per-group
Shapiro-Wilk statistics are attached as a data frame in the `"tests"`
attribute (columns: group, `W`, `p_value`), e.g. for use in a methods
section via
[`assumption_methods_text()`](https://m-colley.github.io/colleyRstats/reference/assumption_methods_text.md).
For groups with more than 5000 non-missing values, Shapiro-Wilk is
computed on a random sample of 5000 observations (a warning is emitted);
the returned value still reflects that sampled test. Because the sample
is drawn randomly, results for such large groups are not reproducible
unless a seed is set beforehand.
