#' @section Caution -- verify the mapping against your own survey:
#' **Item numbers, item order and item polarity are properties of the sheet a
#' study actually administered, not of the instrument in the abstract.** Survey
#' tools renumber items, translations reorder them, short forms drop them from
#' the middle, and semantic differentials get printed with the poles the other
#' way round.
#'
#' This package applies each instrument's **published** scoring key, which is the
#' right default and is still only a default. If the sheet your participants saw
#' differed, the scores will be wrong -- and wrong quietly, because a mismatched
#' mapping raises no error and produces entirely plausible numbers.
#'
#' So: run [check_questionnaire()] once per instrument per study and read the
#' mapping it prints, and double-check any figure before it goes into a paper.
#' The mapping used is also attached to the result as the `"mapping"` attribute,
#' and summarised in a console note the first time each distinct mapping is
#' scored in a session (silence it with
#' `options(colleyRstats.quiet_questionnaires = TRUE)`).
#'
#' A named `items` argument (`items = c(mental = "tlx_md", ...)`) removes the
#' positional assumption altogether and is the safer choice for an export you
#' did not lay out yourself. A `prefix` maps columns by what their names say
#' -- an item code or label, or one item number per column running 1 to the
#' number of items -- never by sort order, and stops when the names do not
#' identify the items. Note that the `attrakdiff` key is blocked by dimension
#' with the negative pole first; data stored as answered on the official
#' AttrakDiff sheet belong to `attrakdiff_official`.
