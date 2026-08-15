# Convert Windows paths to R-friendly format

Convert Windows paths to R-friendly format

## Usage

``` r
pathPrep(path = "clipboard", read_fn = NULL, write_fn = NULL)
```

## Arguments

- path:

  Path to convert or the string "clipboard" to read from the clipboard.

- read_fn:

  Optional custom function to read from the clipboard.

- write_fn:

  Optional custom function to write to the clipboard.

## Value

A normalized path string.
