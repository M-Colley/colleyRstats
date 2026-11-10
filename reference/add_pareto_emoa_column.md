# Add `PARETO_EMOA` Column to a Data Frame

This function calculates the Pareto front using emoa for a given set of
objectives in a data frame and adds a new column, `PARETO_EMOA`, which
indicates whether each row in the data frame belongs to the Pareto
front.

## Usage

``` r
add_pareto_emoa_column(data, objectives, maximise = FALSE)
```

## Arguments

- data:

  A data frame containing the data, including the objective columns.

- objectives:

  A character vector specifying the names of the objective columns in
  `data`. These columns should be numeric and will be used to calculate
  the Pareto front.

- maximise:

  Direction of optimisation. `FALSE` (the default) treats every
  objective as one to be *minimised*, which is what emoa does natively.
  Pass `TRUE` when larger is better for every objective – as it is for
  trust, acceptance, perceived safety and most other rating-scale
  outcomes – or a logical vector with one entry per objective for a
  mixed problem, e.g. `c(TRUE, TRUE, FALSE)` to maximise the first two
  and minimise the third. Objectives flagged `TRUE` are negated
  internally, so you no longer need to pass negated copies of your own
  columns.

## Value

A data frame with the same columns as `data`, along with an additional
column, `PARETO_EMOA`, which is `TRUE` for rows that are on the Pareto
front and `FALSE` otherwise. Identical rows share one verdict (a copy of
a non-dominated point is non-dominated too), as in
[`add_pareto_moocore_column()`](https://m-colley.github.io/colleyRstats/reference/add_pareto_moocore_column.md).
Rows with a missing objective value get `NA`, with a warning, and the
front is computed from the complete rows.

## See also

[`add_pareto_moocore_column()`](https://m-colley.github.io/colleyRstats/reference/add_pareto_moocore_column.md),
which answers the same question via moocore and accepts the same
`maximise` argument.

## Examples

``` r
if (requireNamespace("emoa", quietly = TRUE)) {
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
  main_df <- add_pareto_emoa_column(data = main_df, objectives)
  head(main_df)

  # All four objectives are ratings where higher is better
  main_df <- add_pareto_emoa_column(main_df, objectives, maximise = TRUE)
}
```
