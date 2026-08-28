# Reverse-code responses

Flips a response scale so that a negatively worded item points the same
way as the rest of its subscale: `min + max - x`.

## Usage

``` r
reverse_code(x, min, max)
```

## Arguments

- x:

  Numeric responses.

- min, max:

  The endpoints of the response scale the item was answered on – the
  *possible* range, not the observed one. Taking them from the data is
  the classic reverse-coding bug: if nobody picked 1, the flip is off by
  a point for every respondent.

## Value

`x`, reverse-coded, with `NA` preserved.

## Examples

``` r
reverse_code(c(1, 3, 5, NA), min = 1, max = 5)
#> [1]  5  3  1 NA
```
