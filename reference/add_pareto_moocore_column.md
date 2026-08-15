# Add `PARETO_MOOCORE` Column to a Data Frame

This function calculates the Pareto front using moocore for a given set
of objectives in a data frame and adds a new column, `PARETO_MOOCORE`,
which indicates whether each row in the data frame belongs to the Pareto
front.

## Usage

``` r
add_pareto_moocore_column(data, objectives)
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
column, `PARETO_MOOCORE`, which is `TRUE` for rows that are on the
Pareto front and `FALSE` otherwise.

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
main_df <- add_pareto_moocore_column(data = main_df, objectives)
head(main_df)
#>        trust predictability perceivedSafety    Comfort PARETO_MOOCORE
#> 1 0.68016292      0.4611865       0.8251994 0.44670247          FALSE
#> 2 0.49884561      0.3152418       0.2738182 0.37151118           TRUE
#> 3 0.64167935      0.1746759       0.5700450 0.02806097           TRUE
#> 4 0.66028435      0.5315735       0.3357191 0.46598719          FALSE
#> 5 0.09602416      0.4936370       0.5962628 0.39003139           TRUE
#> 6 0.76560016      0.7793086       0.1915180 0.02006522           TRUE
```
