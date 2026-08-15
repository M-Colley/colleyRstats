# This function normalizes the values in a vector to the range \[new_min, new_max\] based on their original range \[old_min, old_max\].

This function normalizes the values in a vector to the range \[new_min,
new_max\] based on their original range \[old_min, old_max\].

## Usage

``` r
normalize(x_vector, old_min, old_max, new_min, new_max)
```

## Arguments

- x_vector:

  A numeric vector that you want to normalize.

- old_min:

  The minimum value in the original scale of the data.

- old_max:

  The maximum value in the original scale of the data.

- new_min:

  The minimum value in the new scale to which you want to normalize the
  data.

- new_max:

  The maximum value in the new scale to which you want to normalize the
  data.

## Value

A numeric vector with the normalized values.

## Examples

``` r
normalize(c(1, 2, 3, 4, 5), 1, 5, 0, 1)
#> [1] 0.00 0.25 0.50 0.75 1.00
```
