# Escape LaTeX special characters in plain text

Makes an arbitrary string safe to drop into a LaTeX document by escaping
the characters that would otherwise be interpreted as markup
(`\ { } $ & # _ % ~ ^ < >`). Use it on variable names, factor-level
labels, captions – anything user-supplied that reaches the `.tex`. This
is what prevents a dependent variable called `tlx_mental` from producing
an un-compilable `tlx_mental` (a subscript error) in Overleaf.

## Usage

``` r
latex_escape(x)
```

## Arguments

- x:

  A character vector (or something coercible to one).

## Value

A character vector with LaTeX specials escaped; `NA` is preserved.

## Examples

``` r
latex_escape("tlx_mental")
#> [1] "tlx\\_mental"
latex_escape("cost (%) & margin")
#> [1] "cost (\\%) \\& margin"
```
