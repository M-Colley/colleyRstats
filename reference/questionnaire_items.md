# The items of one questionnaire

The items of one questionnaire

## Usage

``` r
questionnaire_items(instrument, notes = TRUE)
```

## Arguments

- instrument:

  Instrument key, e.g. `"tia"`. See
  [`list_questionnaires()`](https://m-colley.github.io/colleyRstats/reference/list_questionnaires.md).

- notes:

  Logical. If `TRUE` (default), also emit the instrument's scoring notes
  – how the overall score is formed, what its range means, and where its
  published form is known to vary between administrations.

## Value

Invisibly, a data frame with one row per item: number, code, wording,
subscale, and whether the scoring key reverses it.

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
export you did not lay out yourself. A `prefix` maps columns by what
their names say – an item code or label, or one item number per column
running 1 to the number of items – never by sort order, and stops when
the names do not identify the items. Note that the `attrakdiff` key is
blocked by dimension with the negative pole first; data stored as
answered on the official AttrakDiff sheet belong to
`attrakdiff_official`.

## See also

[`check_questionnaire()`](https://m-colley.github.io/colleyRstats/reference/check_questionnaire.md),
[`score_questionnaire()`](https://m-colley.github.io/colleyRstats/reference/score_questionnaire.md)

## Examples

``` r
questionnaire_items("ueq_s")
#> User Experience Questionnaire, short form (UEQ-S) -- Schrepp, Hinderks & Thomaschewski (2017), IJIMAI 4(6)
#> Response range 1-7; 8 items in 2 subscales.
#> CAUTION: item numbers, order and polarity depend on how the questionnaire
#> was administered -- survey tools renumber items, translations reorder them,
#> and short forms drop them. This package applies the PUBLISHED key. If your
#> sheet differed, the scores will be wrong without any error being raised.
#> Check the mapping against the survey your participants actually saw, and
#> double-check any number before it goes into a paper.
#>   - Items are centred to -3 (most negative) .. +3 (most positive); the overall score is the mean of all eight. Values above +0.8 are conventionally read as a positive evaluation, below -0.8 as a negative one.
#>   - Unlike the full UEQ, the UEQ-S fixes the polarity: all eight pairs are printed with the negative term on the LEFT, i.e. at the low response value, so no item is reverse-scored. Pass reverse_items only if your own survey tool stored a pair the other way round.
#>  item  code                         label          subscale reverse
#>     1 ueqs1      obstructive - supportive Pragmatic Quality   FALSE
#>     2 ueqs2            complicated - easy Pragmatic Quality   FALSE
#>     3 ueqs3       inefficient - efficient Pragmatic Quality   FALSE
#>     4 ueqs4             confusing - clear Pragmatic Quality   FALSE
#>     5 ueqs5             boring - exciting   Hedonic Quality   FALSE
#>     6 ueqs6 not interesting - interesting   Hedonic Quality   FALSE
#>     7 ueqs7      conventional - inventive   Hedonic Quality   FALSE
#>     8 ueqs8          usual - leading edge   Hedonic Quality   FALSE
```
