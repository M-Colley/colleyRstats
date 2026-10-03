# Ensure input is not empty

Stops execution if x is NULL, empty, contains only NAs, or is a data
frame without rows.

## Usage

``` r
not_empty(x, msg = NULL)
```

## Arguments

- x:

  The object to check

- msg:

  The error message to display. The default names the offending
  argument, e.g. `` "`data` must not be empty." ``.

## Value

Invisible TRUE if valid.
