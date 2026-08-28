# Internal consistency of a questionnaire's subscales

Cronbach's alpha per subscale, computed on the same recoded item matrix
that
[`score_questionnaire()`](https://m-colley.github.io/colleyRstats/reference/score_questionnaire.md)
aggregates – so reverse-coded items are already flipped, and a negative
alpha means a genuine problem rather than a forgotten reversal.
McDonald's omega is added when psych is installed, and is the
better-behaved statistic when a subscale's items are not equally good
indicators.

## Usage

``` r
score_reliability(
  data,
  instrument,
  items = NULL,
  prefix = NULL,
  scale = NULL,
  reverse_items = NULL,
  verbose = TRUE
)
```

## Arguments

- data:

  A data frame with one row per respondent (or per respondent and
  condition) and one column per item.

- instrument:

  Instrument key, e.g. `"sus"`, `"nasa_tlx"`, `"ueq_s"`, `"tia"`,
  `"ssq"`. See
  [`list_questionnaires()`](https://m-colley.github.io/colleyRstats/reference/list_questionnaires.md).

- items:

  Optional. Either the item columns in the instrument's own order, or a
  character vector *named* after the item codes
  (`c(mental = "tlx_md", effort = "tlx_ef", ...)`), which is order-proof
  and the safer choice for a survey export you did not lay out yourself.

- prefix:

  Optional column-name prefix selecting the item columns, e.g. `"sus_"`.
  Matching columns are sorted numerically, so `sus_2` comes before
  `sus_10`. Must select exactly as many columns as the instrument has
  items.

- scale:

  Optional two-element vector giving the response range your survey
  used, e.g. `c(1, 21)` for the 21-point NASA-TLX sheet or `c(0, 4)` for
  a zero-based SUS. Responses are rescaled onto the instrument's own
  range before scoring. Defaults to the instrument's range; responses
  outside it are an error rather than a silent rescale.

- reverse_items:

  Optional items to *toggle* the reverse-coding of, given as item
  numbers or item codes. Naming an item the scoring key already reverses
  un-reverses it, which is what an export that stores a pair the other
  way round needs.

- verbose:

  Logical. If `TRUE` (default), emit the one-time mapping message
  described above.

## Value

A data frame with one row per subscale: the number of items, the number
of complete cases it was computed on, `alpha`, `omega` (`NA` without
psych), and the mean inter-item correlation. Subscales of a single item
yield `NA` – internal consistency is not defined for them.

## Caution – verify the mapping against your own survey

**Item numbers, item order and item polarity are properties of the sheet
a study actually administered, not of the instrument in the abstract.**
Survey tools renumber items, translations reorder them, short forms drop
them from the middle, and semantic differentials get printed with the
poles the other way round.

This package applies each instrument's **published** scoring key, which
is the right default and is still only a default. If the sheet your
participants saw differed, the scores will be wrong – and wrong quietly,
because a mismatched mapping raises no error and produces entirely
plausible numbers.

So: run
[`check_questionnaire()`](https://m-colley.github.io/colleyRstats/reference/check_questionnaire.md)
once per instrument per study and read the mapping it prints, and
double-check any figure before it goes into a paper. The mapping used is
also attached to the result as the `"mapping"` attribute, and summarised
in a console note the first time each distinct mapping is scored in a
session (silence it with
`options(colleyRstats.quiet_questionnaires = TRUE)`).

A named `items` argument (`items = c(mental = "tlx_md", ...)`) removes
the positional assumption altogether and is the safer choice for an
export you did not lay out yourself.

## See also

[`score_questionnaire()`](https://m-colley.github.io/colleyRstats/reference/score_questionnaire.md)

## Examples

``` r
set.seed(3)
trait <- rnorm(60)
d <- as.data.frame(lapply(1:10, function(i) {
  round(pmin(pmax(3 + trait + rnorm(60, sd = 0.6), 1), 5))
}))
names(d) <- paste0("sus_", 1:10)
# Items 2, 4, 6, 8, 10 are negatively worded on the real SUS, so flip them
d[paste0("sus_", c(2, 4, 6, 8, 10))] <- 6 - d[paste0("sus_", c(2, 4, 6, 8, 10))]
score_reliability(d, "sus", prefix = "sus_")
#>       subscale n_items n_complete     alpha     omega mean_item_cor
#> 1    Usability       8         60 0.9335244 0.9351592     0.6401712
#> 2 Learnability       2         60 0.7700840        NA     0.6274786
```
