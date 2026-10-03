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
  verbose = TRUE,
  unreverse_items = NULL,
  impute = c("default", "prorate", "midpoint")
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
  Must select exactly as many columns as the instrument has items. The
  columns are then matched to items *by their names*, never by sort
  order: either what follows the prefix is the item's code, label or
  (for a single-item subscale) subscale name, compared without case or
  punctuation (`tlx_mental`, `tlx_Mental_Demand`, `tia_rc1`, `ipq_SP2`);
  or it carries one item number per column, and those numbers are
  exactly `1..n` (`sus_2`, `SUS[2]`, `Q5_2`; in `SUS_2_1` the number
  that varies across the columns is the item). Anything else – numbering
  from 0, numbers that do not run `1..n`, names that only partly match –
  is an error asking for a named `items` mapping, rather than a guess.

- scale:

  Optional two-element vector giving the response range your survey
  used, e.g. `c(1, 21)` for the 21-point NASA-TLX sheet or `c(0, 4)` for
  a zero-based SUS. Responses are rescaled onto the instrument's own
  range before scoring. Defaults to the instrument's range; responses
  outside it are an error rather than a silent rescale. Without `scale`,
  a coding that fits the range but looks shifted against it draws a
  warning (see Details); passing `scale` explicitly confirms the coding
  and silences it.

- reverse_items:

  Optional items to reverse-code in addition to the scoring key's own,
  given as item numbers or item codes – for a survey that printed a pair
  the other way round. For backward compatibility it *toggles*: naming
  an item the key already reverses un-reverses it, and because passing
  an instrument's own reverse set (e.g. `c(2, 4, 6, 8, 10)` for the SUS)
  is a common mistake that would do exactly that, it raises a warning.
  Use `unreverse_items` to undo a key reversal on purpose.

- min_valid:

  Minimum proportion of a subscale's items that must be answered for a
  score to be produced. The default `1` scores only complete subscales
  and returns `NA` otherwise – no silent imputation. Relax it (e.g.
  `0.8`) to score partially complete responses; how the missing items
  are then completed is set by `impute`.

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

- unreverse_items:

  Optional items the scoring key reverses that should *not* be reversed,
  because the export already stored them reverse-coded. Naming an item
  the key does not reverse is an error.

- impute:

  How the missing items of a row that clears `min_valid` are completed.
  `"default"` applies the instrument's published rule: for the SUS, each
  missing item counts as the scale's centre point, as Brooke (1996)
  instructs respondents who cannot answer an item; for every other
  instrument, a subscale is the mean of the items present (a summed
  score is scaled up proportionally, so it stays on its published
  range). `"prorate"` uses the mean of the items present everywhere, and
  `"midpoint"` the scale centre everywhere. Irrelevant with the default
  `min_valid = 1`.

## Value

A data frame with one row per row of `data` and one column per subscale,
plus the instrument's overall score where it defines one. The instrument
definition and the resolved column mapping are attached as the
`"instrument"` and `"mapping"` attributes.

## Details

Item columns must hold numbers. Factors are read by their labels when
the labels are numbers, and by level order only when the factor is
ordered. Text that is not a number (`"Strongly agree"`,
`"5 - Strongly agree"`, a decimal comma) is an error naming the values,
because converting it would silently turn responses into missing values;
blank cells are missing. A fractional response on an instrument answered
in whole scale points draws a warning.

The scoring message reports the observed response range next to the
assumed one. Without an explicit `scale`, three codings that fit the
assumed range but look shifted draw a warning: NASA-TLX responses that
never exceed 21 on the 0–100 scale (the 21-point sheet); and, for
multi-item whole-point instruments with at least five respondents, no
response at 0 on a zero-based scale (a 1-based export, e.g. IPQ 1–7) or
no response at the top of a one-based scale (a 0-based export, e.g. SUS
0–4).

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
#> Scoring System Usability Scale (SUS) from 10 columns (sus_1 ... sus_10, matched by item number); responses observed 1 to 5 on the assumed range 1 to 5; reverse-coded: sus2, sus4, sus6, sus8, sus10.
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
#> Scoring NASA Task Load Index, raw (RTLX) from 6 columns (mental ... frustration, matched by item code); responses observed 1 to 14 on the assumed range 1 to 21; no items reverse-coded.
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
