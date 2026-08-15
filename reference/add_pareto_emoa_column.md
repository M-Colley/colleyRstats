# Add `PARETO_EMOA` Column to a Data Frame

This function calculates the Pareto front using emoa for a given set of
objectives in a data frame and adds a new column, `PARETO_EMOA`, which
indicates whether each row in the data frame belongs to the Pareto
front.

## Usage

``` r
add_pareto_emoa_column(data, objectives)
```

## Arguments

- data:

  A data frame containing the data, including the objective columns.

- objectives:

  A character vector specifying the names of the objective columns in
  `data`. These columns should be numeric and will be used to calculate
  the Pareto front.

## Value

A data frame with the same columns as `data`, along with an additional
column, `PARETO_EMOA`, which is `TRUE` for rows that are on the Pareto
front and `FALSE` otherwise.

## Examples

``` r
# Define objective columns
objectives <- c("trust", "predictability", "perceivedSafety", "Comfort")

# Example data frame
main_df <- data.frame(
  trust = runif(10),
  predictability = runif(10),
  perceivedSafety = runif(10),
  Comfort = runif(10)
)

# Add the Pareto front column
main_df <- add_pareto_emoa_column(data = main_df, objectives)
head(main_df)
#>         trust predictability perceivedSafety    Comfort PARETO_EMOA
#> 1 0.080750138     0.87460066       0.2898923 0.03123033        TRUE
#> 2 0.834333037     0.17494063       0.6783804 0.22556253        TRUE
#> 3 0.600760886     0.03424133       0.7353196 0.30083081        TRUE
#> 4 0.157208442     0.32038573       0.1959567 0.63646561        TRUE
#> 5 0.007399441     0.40232824       0.9805397 0.47902455        TRUE
#> 6 0.466393497     0.19566983       0.7415215 0.43217126        TRUE
```
