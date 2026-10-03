# Check homogeneity of variances across groups

Runs the **Brown-Forsythe test**: Levene's test computed on the absolute
deviations from each group's *median* rather than its mean
([`rstatix::levene_test()`](https://rpkgs.datanovia.com/rstatix/reference/levene_test.html)'s
default, `center = median`). The median-centred version keeps close to
its nominal error rate when the data are skewed or heavy-tailed, as
rating-scale data often are, where Levene's mean-centred original
rejects too often (Brown & Forsythe, 1974). Report it under that name;
the `"method"` attribute carries it, e.g. for
[`assumption_methods_text()`](https://m-colley.github.io/colleyRstats/reference/assumption_methods_text.md).

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

TRUE if the test is non-significant (p \>= .05), FALSE otherwise.
Attributes: `"test"`, the test result (columns `df1`, `df2`,
`statistic`, `p`); `"method"`, the name of the test that was run
(`"Brown-Forsythe test (median-centred Levene's test)"`).

## Details

The grouping column is treated as a factor whatever its type, so numeric
condition codes (1, 2, 3) define groups rather than a covariate, and
non-syntactic column names such as `"Mental Demand"` work.

## References

Brown, M. B., & Forsythe, A. B. (1974). Robust tests for the equality of
variances. *Journal of the American Statistical Association, 69*(346),
364–367.
[doi:10.1080/01621459.1974.10482955](https://doi.org/10.1080/01621459.1974.10482955)
