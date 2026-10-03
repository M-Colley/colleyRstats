# Internal consistency of a questionnaire's subscales

Cronbach's alpha per subscale – and for the whole scale, where the
instrument defines an overall score (the SUS, the SSQ Total, RTLX, the
UEQ-S Overall) – computed on the same recoded item matrix that
[`score_questionnaire()`](https://m-colley.github.io/colleyRstats/reference/score_questionnaire.md)
aggregates. Reverse-coded items are therefore already flipped, and a
negative alpha means a genuine problem rather than a forgotten reversal.

## Usage

``` r
score_reliability(
  data,
  instrument,
  items = NULL,
  prefix = NULL,
  scale = NULL,
  reverse_items = NULL,
  verbose = TRUE,
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

- verbose:

  Logical. If `TRUE` (default), emit the one-time mapping message
  described above.

- unreverse_items:

  Optional items the scoring key reverses that should *not* be reversed,
  because the export already stored them reverse-coded. Naming an item
  the key does not reverse is an error.

## Value

A data frame with one row per subscale, plus a final row named after the
overall score where the instrument defines one: the number of items, the
number of complete cases it was computed on, `alpha`, `omega` (omega
total), `spearman_brown` (two-item scales only), the mean inter-item
correlation, and a `note` saying why a coefficient is missing (a single
item, two items, too few complete responses, psych not installed, or the
reason the factor solution failed). Subscales of a single item yield
`NA` – internal consistency is not defined for them.

## Details

McDonald's omega (total) is added when psych is installed. It is
computed from an unrotated one-factor solution
(`psych::fa(nfactors = 1, rotate = "none")`) as \\1 - \sum u^2 / \sum
R\\, which is the `omega.tot` that `psych::omega(nfactors = 1)` reports,
without that function's dependence on GPArotation and without its
automatic flipping of negatively loading items – which would hide
exactly the reverse-coding error this function is meant to expose. Omega
needs at least three items; for two-item scales it is not identified.

For two-item scales (the SUS Learnability scale, three TiA subscales)
the Spearman-Brown coefficient \\2r / (1 + r)\\ is reported as well,
which Eisinga, te Grotenhuis & Pelzer (2013) recommend over alpha: alpha
underestimates the reliability of a two-item scale whenever the two item
variances differ.

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

## References

Eisinga, R., te Grotenhuis, M., & Pelzer, B. (2013). The reliability of
a two-item scale: Pearson, Cronbach, or Spearman-Brown? *International
Journal of Public Health, 58*(4), 637–642.
[doi:10.1007/s00038-012-0416-3](https://doi.org/10.1007/s00038-012-0416-3)

McDonald, R. P. (1999). *Test theory: A unified treatment*. Erlbaum.

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
#>       subscale n_items n_complete     alpha     omega spearman_brown
#> 1    Usability       8         60 0.9335244 0.9351592             NA
#> 2 Learnability       2         60 0.7700840        NA      0.7711052
#> 3          SUS      10         60 0.9441290 0.9451309             NA
#>   mean_item_cor
#> 1     0.6401712
#> 2     0.6274786
#> 3     0.6307151
#>                                                                               note
#> 1                                                                                 
#> 2 two items: report spearman_brown (Eisinga et al., 2013); omega is not identified
#> 3                                                                                 
```
