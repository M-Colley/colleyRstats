# Summarise a motion-sickness time course

Repeated single-item sickness ratings (FMS, MISC) are collected once a
minute and then, almost always, reduced to a handful of per-participant
numbers before they are analysed. This produces those numbers: peak,
mean, final rating, the area under the rating curve, and when a
threshold was first crossed.

## Usage

``` r
summarize_sickness(data, value, id, time = NULL, by = NULL, threshold = NULL)
```

## Arguments

- data:

  A data frame in long format: one row per rating.

- value:

  Column holding the rating.

- id:

  Column identifying the participant (and, with `by`, the condition).

- time:

  Optional column holding the time of the rating, in whatever unit the
  study used. Needed for a meaningful area under the curve and for
  time-to-threshold; without it, the rating index is used and `auc` is
  reported in rating-steps.

- by:

  Optional further grouping columns, e.g. the experimental condition.

- threshold:

  Optional rating at or above which a participant counts as affected,
  e.g. `6` for MISC (nausea) or `10` for FMS.

## Value

A data frame with one row per participant (and `by` group): `n` ratings,
`peak`, `mean`, `final`, `auc` (trapezoidal), `auc_rate` (the AUC
divided by the observed duration, i.e. the time-weighted mean rating),
and – with `threshold` – `reached` and `time_to_threshold`.

## See also

[`score_questionnaire()`](https://m-colley.github.io/colleyRstats/reference/score_questionnaire.md)
for the single-measurement instruments

## Examples

``` r
d <- data.frame(
  pid = rep(c("p1", "p2"), each = 5),
  minute = rep(0:4, 2),
  fms = c(0, 1, 3, 6, 8, 0, 0, 1, 1, 2)
)
summarize_sickness(d, value = "fms", id = "pid", time = "minute", threshold = 5)
#>   pid n peak mean final auc auc_rate reached time_to_threshold
#> 1  p1 5    8  3.6     8  14     3.50    TRUE                 3
#> 2  p2 5    2  0.8     2   3     0.75   FALSE                NA
```
