# Classify the measurement scale of an outcome variable

Decides how a dependent variable should be modelled by inspecting its
type and distribution of values. The measurement scale is the first
branch of a principled model choice: it dictates the *family* (Gaussian,
binomial, Poisson, cumulative-link) before any distributional assumption
is checked.

## Usage

``` r
classify_outcome(y, ordinal_max_levels = 7L)
```

## Arguments

- y:

  The outcome vector.

- ordinal_max_levels:

  Integer. Integer-valued numerics with at most this many distinct
  values are treated as ordinal (Likert-like). Default 7.

## Value

A single string, one of `"continuous"`, `"ordinal"`, `"binary"`,
`"count"`, or `"nominal"`.

## Details

The rules are deliberately simple and transparent:

- ordered factor \\\rightarrow\\ `"ordinal"`;

- logical, a two-level factor, or a numeric/character with exactly two
  distinct values \\\rightarrow\\ `"binary"`;

- unordered factor/character with more than two levels \\\rightarrow\\
  `"nominal"`;

- integer-valued numeric with at most `ordinal_max_levels` distinct
  values (a Likert-type item) \\\rightarrow\\ `"ordinal"`;

- non-negative integer-valued numeric with more distinct values
  \\\rightarrow\\ `"count"`;

- any other numeric \\\rightarrow\\ `"continuous"`.

The heuristics can never be perfect (a 1–7 Likert item and a small count
are genuinely ambiguous); pass an explicit `outcome_type` to
[`recommend_test()`](https://m-colley.github.io/colleyRstats/reference/recommend_test.md)
when you want to override them.

## Examples

``` r
classify_outcome(rnorm(50)) # "continuous"
#> [1] "continuous"
classify_outcome(factor(sample(1:5, 50, TRUE), ordered = TRUE)) # "ordinal"
#> [1] "ordinal"
classify_outcome(sample(0:1, 50, TRUE)) # "binary"
#> [1] "binary"
classify_outcome(rpois(50, 3)) # "count"
#> [1] "count"
```
