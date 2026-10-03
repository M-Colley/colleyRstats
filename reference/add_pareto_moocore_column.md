# Add `PARETO_MOOCORE` Column to a Data Frame

This function calculates the Pareto front using moocore for a given set
of objectives in a data frame and adds a new column, `PARETO_MOOCORE`,
which indicates whether each row in the data frame belongs to the Pareto
front.

## Usage

``` r
add_pareto_moocore_column(data, objectives, maximise = FALSE)
```

## Arguments

- data:

  A data frame containing the data, including the objective columns.

- objectives:

  A character vector specifying the names of the objective columns in
  `data`. These columns should be numeric and will be used to calculate
  the Pareto front.

- maximise:

  Direction of optimisation, passed through to
  [`moocore::is_nondominated()`](https://multi-objective.github.io/moocore/r/reference/nondominated.html).
  `FALSE` (the default) treats every objective as one to be *minimised*.
  Pass `TRUE` when larger is better for every objective – as it is for
  trust, acceptance, perceived safety and most other rating-scale
  outcomes – or a logical vector with one entry per objective for a
  mixed problem, e.g. `c(TRUE, TRUE, FALSE)` to maximise the first two
  and minimise the third. This removes the need to pass negated copies
  of your own columns.

## Value

A data frame with the same columns as `data`, along with an additional
column, `PARETO_MOOCORE`, which is `TRUE` for rows that are on the
Pareto front and `FALSE` otherwise. Identical rows share one verdict:
every copy of a non-dominated point is kept (`keep_weakly = TRUE`), as
in
[`add_pareto_emoa_column()`](https://m-colley.github.io/colleyRstats/reference/add_pareto_emoa_column.md),
where
[`moocore::is_nondominated()`](https://multi-objective.github.io/moocore/r/reference/nondominated.html)
on its own would mark only the first copy. Rows with a missing objective
value get `NA`, with a warning, and the front is computed from the
complete rows.

## See also

[`add_pareto_emoa_column()`](https://m-colley.github.io/colleyRstats/reference/add_pareto_emoa_column.md),
which answers the same question via emoa and accepts the same `maximise`
argument.

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

# Add the Pareto front column (minimising, the default)
main_df <- add_pareto_moocore_column(data = main_df, objectives)
head(main_df)
#>        trust predictability perceivedSafety    Comfort PARETO_MOOCORE
#> 1 0.68016292      0.4611865       0.8251994 0.44670247          FALSE
#> 2 0.49884561      0.3152418       0.2738182 0.37151118           TRUE
#> 3 0.64167935      0.1746759       0.5700450 0.02806097           TRUE
#> 4 0.66028435      0.5315735       0.3357191 0.46598719          FALSE
#> 5 0.09602416      0.4936370       0.5962628 0.39003139           TRUE
#> 6 0.76560016      0.7793086       0.1915180 0.02006522           TRUE

# All four objectives are ratings where higher is better
main_df <- add_pareto_moocore_column(main_df, objectives, maximise = TRUE)

# Mixed: maximise the ratings, minimise a workload score
main_df$workload <- runif(10)
main_df <- add_pareto_moocore_column(
  main_df,
  c(objectives, "workload"),
  maximise = c(TRUE, TRUE, TRUE, TRUE, FALSE)
)
```
