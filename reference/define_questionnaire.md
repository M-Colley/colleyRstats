# Register your own questionnaire

Adds an instrument to the registry so that
[`score_questionnaire()`](https://m-colley.github.io/colleyRstats/reference/score_questionnaire.md),
[`check_questionnaire()`](https://m-colley.github.io/colleyRstats/reference/check_questionnaire.md)
and
[`score_reliability()`](https://m-colley.github.io/colleyRstats/reference/score_reliability.md)
handle it exactly like a built-in one. Use it for a lab-specific scale,
a translated or shortened form, or a published instrument this package
does not ship – and put the call in a project's setup script so every
analysis in that project scores it the same way.

## Usage

``` r
define_questionnaire(
  key,
  name,
  scale,
  subscale,
  code = NULL,
  label = NULL,
  reverse = integer(0),
  recode = c("none", "center", "zero_base"),
  total = NULL,
  total_name = "Total",
  reference = NA_character_,
  higher = NA_character_,
  notes = character(),
  integer_responses = TRUE
)
```

## Arguments

- key:

  Short identifier, used as the `instrument` argument.

- name:

  Full name of the instrument, shown in messages and listings.

- scale:

  Two-element vector giving the response range, e.g. `c(1, 7)`.

- subscale:

  Character vector, one entry per item, naming the subscale that item
  loads on. Use a comma-separated string (`"Nausea,Oculomotor"`) for an
  item that loads on two.

- code:

  Optional short code per item, used to refer to items in
  `reverse_items` and in a named `items` mapping. Defaults to `item1`,
  `item2`, ...

- label:

  Optional item wording, one entry per item.

- reverse:

  Optional items that are reverse-scored, as item numbers (`c(2, 4)`) or
  item codes (`c("item2", "item4")`).

- recode:

  One of `"none"` (default), `"center"` (subtract the midpoint, giving
  the \\-3..+3\\ coding of a 7-point semantic differential), or
  `"zero_base"` (subtract the minimum).

- total:

  How to form an overall score across all items: `"mean"`, `"sum"`, or
  `NULL` (default) for none – which is the honest choice for a
  multidimensional instrument whose authors define no total.

- total_name:

  Column name for that overall score. Default `"Total"`.

- reference:

  Optional citation, shown alongside the instrument.

- higher:

  Optional one-word note on what a high score means, e.g. `"better"` or
  `"worse"`.

- notes:

  Optional character vector of scoring notes.

- integer_responses:

  Logical. `TRUE` (default) for an instrument answered in whole scale
  points (Likert items, semantic differentials): fractional responses
  then draw a warning, and a coding that looks shifted against `scale`
  is checked for. Set `FALSE` for a visual-analogue scale or slider.

## Value

Invisibly, the instrument definition.

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

[`list_questionnaires()`](https://m-colley.github.io/colleyRstats/reference/list_questionnaires.md),
[`score_questionnaire()`](https://m-colley.github.io/colleyRstats/reference/score_questionnaire.md)

## Examples

``` r
define_questionnaire(
  key = "acceptance",
  name = "Van der Laan acceptance scale",
  reference = "Van der Laan, Heino & De Waard (1997), Transp. Res. C 5(1)",
  scale = c(-2, 2),
  subscale = c(
    "Usefulness", "Satisfying", "Usefulness", "Satisfying", "Usefulness",
    "Satisfying", "Usefulness", "Satisfying", "Usefulness"
  ),
  label = c(
    "useful - useless", "pleasant - unpleasant", "bad - good",
    "nice - annoying", "effective - superfluous", "irritating - likeable",
    "assisting - worthless", "undesirable - desirable", "raising alertness - sleep-inducing"
  ),
  reverse = c(1, 2, 4, 5, 7, 9),
  higher = "better"
)
list_questionnaires()[1, ]
#>          key                          name n_items n_subscales scale higher_is
#> 1 acceptance Van der Laan acceptance scale       9           2  -2-2    better
#>                                                    reference
#> 1 Van der Laan, Heino & De Waard (1997), Transp. Res. C 5(1)
```
