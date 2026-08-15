# Debug contrast errors in ANOVA-like models

Debug contrast errors in ANOVA-like models

## Usage

``` r
debug_contr_error(dat, subset_vec = NULL)
```

## Arguments

- dat:

  A data frame of predictors.

- subset_vec:

  Optional logical or numeric index vector used to subset rows before
  checks.

## Value

A list with two elements:

- nlevels:

  Integer vector giving the number of levels for each factor variable in
  `dat`.

- levels:

  List of factor level labels for each factor variable in `dat`.

## Examples

``` r
# \donttest{
dat <- data.frame(
  group = factor(rep(letters[1:3], each = 3)),
  score = rnorm(9)
)

debug_contr_error(dat = dat)
#> $nlevels
#> group 
#>     3 
#> 
#> $levels
#> $levels$group
#> [1] "a" "b" "c"
#> 
#> 
# }
```
