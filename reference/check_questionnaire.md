# Show how a questionnaire will be scored, before scoring it

Prints the mapping
[`score_questionnaire()`](https://m-colley.github.io/colleyRstats/reference/score_questionnaire.md)
would use – which column supplies which item, which subscale it loads
on, whether it is reverse-coded – along with the observed range of each
column and the instrument's scoring notes. Run it once per study: it is
the cheapest available check against the failure mode in which a shifted
survey export produces perfectly plausible, wrong scores.

## Usage

``` r
check_questionnaire(
  data,
  instrument,
  items = NULL,
  prefix = NULL,
  scale = NULL,
  reverse_items = NULL,
  unreverse_items = NULL
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

- unreverse_items:

  Optional items the scoring key reverses that should *not* be reversed,
  because the export already stored them reverse-coded. Naming an item
  the key does not reverse is an error.

## Value

Invisibly, a data frame with one row per item: the item number and code,
the column it maps to, its subscale, whether it is reverse-coded, and
the observed minimum, maximum and number of missing values of that
column.

## Details

Problems that
[`score_questionnaire()`](https://m-colley.github.io/colleyRstats/reference/score_questionnaire.md)
would stop on (a column that is not numeric, responses outside the
assumed range) are reported here as warnings instead, together with the
warnings scoring would raise (a coding that looks shifted, an item named
in `reverse_items` that the key already reverses), so the check can
explain them rather than abort.

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

So: run `check_questionnaire()` once per instrument per study and read
the mapping it prints, and double-check any figure before it goes into a
paper. The mapping used is also attached to the result as the
`"mapping"` attribute, and summarised in a console note the first time
each distinct mapping is scored in a session (silence it with
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

[`score_questionnaire()`](https://m-colley.github.io/colleyRstats/reference/score_questionnaire.md),
[`questionnaire_items()`](https://m-colley.github.io/colleyRstats/reference/questionnaire_items.md)

## Examples

``` r
set.seed(1)
d <- as.data.frame(matrix(sample(1:5, 10 * 4, TRUE), nrow = 4))
names(d) <- paste0("sus_", 1:10)
check_questionnaire(d, "sus", prefix = "sus_")
#> System Usability Scale (SUS) -- Brooke (1996), Usability Evaluation in Industry; Lewis & Sauro (2009), HCII
#> CAUTION: item numbers, order and polarity depend on how the questionnaire
#> was administered -- survey tools renumber items, translations reorder them,
#> and short forms drop them. This package applies the PUBLISHED key. If your
#> sheet differed, the scores will be wrong without any error being raised.
#> Check the mapping against the survey your participants actually saw, and
#> double-check any number before it goes into a paper.
#> Assumed response range: 1-5 (the instrument's own; pass `scale` if your survey differed)
#> Observed responses: 1 to 5
#> 
#> Item mapping (verify against the survey your participants saw):
#>  item  code column     subscale reverse observed_min observed_max n_missing
#>     1  sus1  sus_1    Usability   FALSE            1            4         0
#>     2  sus2  sus_2    Usability    TRUE            2            5         0
#>     3  sus3  sus_3    Usability   FALSE            1            5         0
#>     4  sus4  sus_4 Learnability    TRUE            1            5         0
#>     5  sus5  sus_5    Usability   FALSE            1            5         0
#>     6  sus6  sus_6    Usability    TRUE            1            5         0
#>     7  sus7  sus_7    Usability   FALSE            1            4         0
#>     8  sus8  sus_8    Usability    TRUE            2            4         0
#>     9  sus9  sus_9    Usability   FALSE            1            4         0
#>    10 sus10 sus_10 Learnability    TRUE            1            4         0
#> 
#> Notes:
#>   - The SUS score is the sum of the ten recoded items multiplied by 2.5, giving 0-100. That is a percentage of the maximum, NOT a percentile: the mean SUS across studies is about 68, so 68 is average rather than poor.
#>   - Usability (8 items, x 3.125) and Learnability (2 items, x 12.5) follow Lewis & Sauro (2009) and are likewise on 0-100. The two are strongly correlated; report them only if the study has a reason to separate them.
#>   - Missing items: Brooke (1996) instructs a respondent who cannot answer an item to mark the centre point of the scale, so when `min_valid` < 1 lets an incomplete row be scored, each missing item counts as the centre (3 on 1-5). One missing item in an otherwise perfect response therefore gives 95, not 100. Pass impute = "prorate" to scale up from the answered items instead, and say which rule you used.
#>   - Learnability has only two items. score_reliability() reports the Spearman-Brown coefficient for it, which Eisinga, te Grotenhuis & Pelzer (2013) recommend over alpha for two-item scales.
```
