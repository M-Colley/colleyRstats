# Score a standardised questionnaire

Turns the raw item columns of a published questionnaire into its
subscale scores, applying that instrument's own scoring key:
reverse-coding, any recoding it prescribes (centring a semantic
differential to \\-3..+3\\, zero-basing the SUS), the subscale
structure, and the published weights or multipliers. Supported
instruments are listed by
[`list_questionnaires()`](https://m-colley.github.io/colleyRstats/reference/list_questionnaires.md);
register your own with
[`define_questionnaire()`](https://m-colley.github.io/colleyRstats/reference/define_questionnaire.md).

## Usage

``` r
score_questionnaire(
  data,
  instrument,
  items = NULL,
  prefix = NULL,
  scale = NULL,
  reverse_items = NULL,
  min_valid = 1,
  append = FALSE,
  prefix_out = NULL,
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

- min_valid:

  Minimum proportion of a subscale's items that must be answered for a
  score to be produced. The default `1` scores only complete subscales
  and returns `NA` otherwise – no silent imputation. Relax it (e.g.
  `0.8`) to score partially complete responses, in which case a subscale
  is the mean of the items present, and a sum-scored instrument is
  scaled up proportionally so it stays on its published range.

- append:

  Logical. If `TRUE`, return `data` with the score columns added; if
  `FALSE` (default), return only the scores.

- prefix_out:

  Optional string prefixed to every score column, useful when the same
  instrument is scored more than once per row (pre/post, or one block
  per condition).

- verbose:

  Logical. If `TRUE` (default), emit the one-time mapping message
  described above.

## Value

A data frame with one row per row of `data` and one column per subscale,
plus the instrument's overall score where it defines one. The instrument
definition and the resolved column mapping are attached as the
`"instrument"` and `"mapping"` attributes.

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

[`check_questionnaire()`](https://m-colley.github.io/colleyRstats/reference/check_questionnaire.md)
to verify the mapping,
[`score_reliability()`](https://m-colley.github.io/colleyRstats/reference/score_reliability.md)
for internal consistency,
[`questionnaire_items()`](https://m-colley.github.io/colleyRstats/reference/questionnaire_items.md)
for the item list,
[`define_questionnaire()`](https://m-colley.github.io/colleyRstats/reference/define_questionnaire.md)
to add an instrument.

## Examples

``` r
set.seed(42)
sus_raw <- as.data.frame(matrix(sample(1:5, 10 * 6, TRUE), nrow = 6))
names(sus_raw) <- paste0("sus_", 1:10)

score_questionnaire(sus_raw, "sus", prefix = "sus_")
#> Scoring System Usability Scale (SUS) from 10 columns (sus_1 ... sus_10); reverse-coded: sus2, sus4, sus6, sus8, sus10.
#> CAUTION: item numbers, order and polarity depend on how the questionnaire
#> was administered -- survey tools renumber items, translations reorder them,
#> and short forms drop them. This package applies the PUBLISHED key. If your
#> sheet differed, the scores will be wrong without any error being raised.
#> Check the mapping against the survey your participants actually saw, and
#> double-check any number before it goes into a paper.
#>   See the full mapping with check_questionnaire(data, "sus", ...); silence this note with options(colleyRstats.quiet_questionnaires = TRUE).
#>    SUS Usability Learnability
#> 1 60.0    56.250         75.0
#> 2 67.5    68.750         62.5
#> 3 40.0    46.875         12.5
#> 4 25.0    31.250          0.0
#> 5 40.0    40.625         37.5
#> 6 40.0    34.375         62.5

# A 21-point NASA-TLX sheet, scored onto the conventional 0-100
tlx <- data.frame(
  mental = c(14, 3), physical = c(2, 1), temporal = c(11, 4),
  performance = c(6, 2), effort = c(13, 5), frustration = c(9, 1)
)
score_questionnaire(tlx, "nasa_tlx", scale = c(1, 21))
#> Scoring NASA Task Load Index, raw (RTLX) from 6 columns (mental ... frustration); no items reverse-coded.
#> CAUTION: item numbers, order and polarity depend on how the questionnaire
#> was administered -- survey tools renumber items, translations reorder them,
#> and short forms drop them. This package applies the PUBLISHED key. If your
#> sheet differed, the scores will be wrong without any error being raised.
#> Check the mapping against the survey your participants actually saw, and
#> double-check any number before it goes into a paper.
#>   See the full mapping with check_questionnaire(data, "nasa_tlx", ...); silence this note with options(colleyRstats.quiet_questionnaires = TRUE).
#>   Mental_Demand Physical_Demand Temporal_Demand Performance Effort Frustration
#> 1            65               5              50          25     60          40
#> 2            10               0              15           5     20           0
#>        RTLX
#> 1 40.833333
#> 2  8.333333
```
