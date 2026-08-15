# Replace values across a data frame

Replace all occurrences of given values in all columns of a data frame.
Factor levels are preserved (and extended by the replacement values),
and numeric/logical columns are only touched where a value actually
matches, so unrelated entries keep their exact binary representation.

## Usage

``` r
replace_values(data, to_replace, replace_with)
```

## Arguments

- data:

  The input data frame to be modified.

- to_replace:

  A vector of values to be replaced within the data frame. This must be
  the same length as `replace_with`.

- replace_with:

  A vector of corresponding replacement values. This must be the same
  length as `to_replace`.

## Value

Modified data frame with specified values replaced.

## Examples

``` r
# \donttest{
data <- data.frame(
  q1 = c("neg2", "neg1", "0"),
  q2 = c("1", "neg2", "neg1")
)

replace_values(
  data,
  to_replace = c("neg2", "neg1"),
  replace_with = c("-2", "-1")
)
#>   q1 q2
#> 1 -2  1
#> 2 -1 -2
#> 3  0 -1
# }
```
