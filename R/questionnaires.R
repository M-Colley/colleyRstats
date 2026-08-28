# Scoring for standardised questionnaires.
#
# Turning raw item columns into subscale scores is the most repeated -- and most
# quietly error-prone -- step of a user study: every project re-implements the
# same reverse-coding and averaging by hand, and a single mis-numbered item
# silently changes every result downstream. The instruments live as data in
# questionnaire-defs.R; everything here is the machinery that applies them, plus
# the affordances (check_questionnaire(), the mapping attribute, the one-time
# session note) that make a mis-mapping visible instead of silent.


# Internal: user-registered instruments, overlaid on the built-in registry.
.q_user <- new.env(parent = emptyenv())

# Internal: which instruments have already announced themselves this session.
.q_announced <- new.env(parent = emptyenv())


# Internal: the full registry, built-ins first so a define_questionnaire() call
# with an existing key shadows the shipped definition rather than duplicating it.
.q_registry <- function() {
  reg <- .q_builtin()
  for (key in ls(.q_user)) {
    reg[[key]] <- get(key, envir = .q_user)
  }
  reg
}


# Internal: look one instrument up, with an error that lists what is available.
.q_get <- function(instrument) {
  not_empty(instrument)
  key <- tolower(gsub("[^A-Za-z0-9]+", "_", as.character(instrument)[1]))
  reg <- .q_registry()
  if (!key %in% names(reg)) {
    stop(
      "Unknown questionnaire '", instrument, "'. Available: ",
      paste(sort(names(reg)), collapse = ", "),
      ". Register your own with define_questionnaire().",
      call. = FALSE
    )
  }
  reg[[key]]
}


# Internal: the subscales an item loads on. Most items load on exactly one; the
# SSQ has seven items that load on two, written "Nausea,Oculomotor".
.q_subscales <- function(x) {
  lapply(strsplit(as.character(x), ",", fixed = TRUE), trimws)
}


# Internal: every subscale of a definition, in order of first appearance (which
# is the order the published scoring key lists them in).
.q_subscale_names <- function(def) {
  unique(unlist(.q_subscales(def$items$subscale), use.names = FALSE))
}


# Internal: a syntactic, still-readable column name for a subscale.
.q_colname <- function(x) {
  x <- gsub("[[:space:]]*[-/][[:space:]]*", "_", x)
  x <- gsub("[[:space:]]+", "_", trimws(x))
  make.names(x)
}


# Internal: what the overall-score column is called. Instruments whose overall
# score has an established name in the literature use it, so a column reads
# `RTLX` rather than a generic `Total`.
.q_total_name <- function(def) {
  if (!is.null(def$total_name)) {
    return(def$total_name)
  }
  switch(def$key,
    nasa_tlx = "RTLX",
    ueq_s = "Overall",
    "Total"
  )
}


# Internal: one item column -> the numbers the respondents actually chose.
#
# Survey exports and SPSS files routinely deliver items as factors, and which
# response a factor level stands for is NOT its position: read.csv(
# stringsAsFactors = TRUE), factor() and droplevels() all order levels by
# collation over the values that happen to be present, so factor(c("3", "1"))
# has "3" at position 1, and a level nobody picked is missing entirely. Reading
# the position would shift responses silently and differently in each column.
# Use the labels whenever they are numbers; fall back to the level order only
# for an ORDERED factor, where that order is the response order by construction;
# and refuse an unordered factor of text labels rather than guess at it.
.q_as_numeric <- function(v, column) {
  if (is.numeric(v) || is.logical(v)) {
    return(as.numeric(v))
  }

  if (is.factor(v)) {
    label_values <- suppressWarnings(as.numeric(levels(v)))
    if (!anyNA(label_values)) {
      return(label_values[as.integer(v)])
    }
    if (is.ordered(v)) {
      return(as.numeric(as.integer(v)))
    }
    stop(
      "Item column '", column, "' is an unordered factor whose levels are not ",
      "numbers (", paste0("'", utils::head(levels(v), 3), "'", collapse = ", "),
      if (nlevels(v) > 3) ", ..." else "", "). Its level order is collation ",
      "order, not response order, so scoring it would be a guess. Convert it ",
      "first -- factor(x, levels = c(...), ordered = TRUE) if the labels are ",
      "response options in order, or recode it to numbers.",
      call. = FALSE
    )
  }

  suppressWarnings(as.numeric(v))
}


# Internal: order "item2" before "item10". Survey exports name item columns with
# an unpadded index, which sorts lexically into 1, 10, 11, 2 -- and a positional
# mapping built from that order silently scores the wrong items.
.natural_order <- function(x) {
  # The index is the LAST run of digits in the name, wherever it sits.
  # Requiring it at the very end would miss the shapes survey tools actually
  # emit -- LimeSurvey "SUS[1]", Qualtrics "Q1_1_TEXT", "sus_1r" -- and fall
  # silently back to the lexical order this function exists to avoid.
  has_num <- grepl("[0-9]", x)
  num <- suppressWarnings(as.numeric(sub("^.*?([0-9]+)[^0-9]*$", "\\1", x)))
  # The stem is the name with that last digit run removed, so items of one
  # instrument stay together and only their indices order them.
  stem <- sub("^(.*?)([0-9]+)([^0-9]*)$", "\\1\\3", x)
  stem[!has_num] <- x[!has_num]
  num[!has_num | is.na(num)] <- Inf
  order(stem, num, x)
}


# Internal: work out which columns of `data` hold the instrument's items, in the
# instrument's own order. Three ways in, most explicit first.
.q_resolve_items <- function(data, def, items = NULL, prefix = NULL) {
  n <- nrow(def$items)
  codes <- def$items$code

  if (!is.null(items)) {
    # setNames, not as.character(): as.character() drops the names attribute, so
    # coercing first would make the named branch below unreachable and silently
    # map every named vector positionally -- the exact failure the named form
    # exists to prevent.
    items <- stats::setNames(as.character(items), names(items))
    if (!is.null(names(items)) && all(nzchar(names(items)))) {
      missing_codes <- setdiff(codes, names(items))
      if (length(missing_codes) > 0) {
        stop(
          "`items` is named, so it must name every item of ", def$name, ". Missing: ",
          paste(missing_codes, collapse = ", "), ".",
          call. = FALSE
        )
      }
      cols <- unname(items[codes])
    } else {
      if (length(items) != n) {
        stop(
          def$name, " has ", n, " items, but `items` supplies ", length(items),
          " column", if (length(items) == 1) "" else "s",
          ". Give them in the instrument's own order (see questionnaire_items('",
          def$key, "')), or name them after the item codes.",
          call. = FALSE
        )
      }
      cols <- items
    }
    .check_columns(data, cols)
    return(cols)
  }

  if (!is.null(prefix)) {
    # startsWith(), not grep("^..."): `prefix` is documented as a column-name
    # prefix, and survey exports routinely contain regex metacharacters
    # ("SUS[1]", "Q1(a)") that would either abort with a raw regex error or
    # over-match and score the wrong columns.
    hits <- names(data)[startsWith(names(data), prefix)]
    if (length(hits) != n) {
      stop(
        "Prefix '", prefix, "' matches ", length(hits), " column",
        if (length(hits) == 1) "" else "s",
        " (", paste(hits, collapse = ", "), "), but ", def$name, " has ", n,
        ". Pass `items` explicitly if the prefix cannot select exactly the item columns.",
        call. = FALSE
      )
    }
    return(hits[.natural_order(hits)])
  }

  # Last resort: the item codes themselves, bare or prefixed with the key.
  for (candidate in list(codes, paste0(def$key, "_", codes))) {
    if (all(candidate %in% names(data))) {
      return(candidate)
    }
  }

  stop(
    "Could not find the ", n, " item columns of ", def$name, " in the data. ",
    "Pass `prefix = ` (e.g. prefix = \"", def$key, "_\"), or `items = ` with the ",
    "columns in the instrument's order. See questionnaire_items('", def$key, "').",
    call. = FALSE
  )
}


# Internal: linear rescale from one closed range onto another.
.q_rescale <- function(x, from, to) {
  if (isTRUE(all.equal(from, to))) {
    return(x)
  }
  to[1] + (x - from[1]) * (to[2] - to[1]) / (from[2] - from[1])
}


# Internal: raw item columns -> the numeric matrix the aggregators consume.
# Rescales onto the instrument's own response range, reverses the items the
# scoring key marks, then applies the instrument's recoding (centring for
# semantic differentials, zero-basing for the SUS).
.q_prepare <- function(data, def, cols, scale = NULL, reverse_items = NULL) {
  x <- as.matrix(as.data.frame(
    Map(.q_as_numeric, data[cols], cols),
    stringsAsFactors = FALSE
  ))
  colnames(x) <- cols

  observed <- suppressWarnings(range(x, na.rm = TRUE))
  if (any(!is.finite(observed))) {
    stop("None of the item columns of ", def$name, " hold usable numbers.", call. = FALSE)
  }

  from <- if (is.null(scale)) def$scale else as.numeric(scale)
  if (length(from) != 2 || !all(is.finite(from)) || from[1] >= from[2]) {
    stop("`scale` must be two increasing finite numbers, e.g. c(1, 7).", call. = FALSE)
  }

  if (observed[1] < from[1] || observed[2] > from[2]) {
    stop(
      "Responses run from ", .fmt_num(observed[1]), " to ", .fmt_num(observed[2]),
      ", outside the assumed response range ", from[1], "-", from[2],
      ". Pass `scale = c(min, max)` to declare the range your survey actually used.",
      call. = FALSE
    )
  }

  x <- .q_rescale(x, from, def$scale)

  rev_flag <- def$items$reverse
  if (!is.null(reverse_items)) {
    idx <- .q_match_items(def, reverse_items)
    # Toggle rather than set, so naming an item the key already reverses undoes
    # it -- which is what a survey that stored a pair the other way round needs.
    rev_flag[idx] <- !rev_flag[idx]
  }
  if (any(rev_flag)) {
    x[, rev_flag] <- def$scale[1] + def$scale[2] - x[, rev_flag]
  }

  x <- switch(def$recode,
    none = x,
    center = x - mean(def$scale),
    zero_base = x - def$scale[1],
    stop("Unknown recode '", def$recode, "' in instrument '", def$key, "'.", call. = FALSE)
  )

  attr(x, "reverse") <- rev_flag
  x
}


# Internal: resolve item references (numbers, codes, or column names) to
# positions in the definition.
.q_match_items <- function(def, which) {
  if (is.numeric(which)) {
    bad <- setdiff(which, def$items$item)
    if (length(bad) > 0) {
      stop(
        def$name, " has items 1-", nrow(def$items), "; got ",
        paste(bad, collapse = ", "), ".",
        call. = FALSE
      )
    }
    return(as.integer(which))
  }
  which <- as.character(which)
  idx <- match(tolower(which), tolower(def$items$code))
  if (anyNA(idx)) {
    stop(
      "No item of ", def$name, " is called ",
      paste0("'", which[is.na(idx)], "'", collapse = ", "),
      ". Item codes: ", paste(def$items$code, collapse = ", "), ".",
      call. = FALSE
    )
  }
  idx
}


# Internal: aggregate one block of item columns per row, honouring `min_valid`.
# Sums are scaled up proportionally when items are missing but the row still
# clears the threshold, which is equivalent to imputing the respondent's own
# mean and keeps a sum-scored instrument on its published range.
.rowagg <- function(x, fun = c("mean", "sum"), min_valid = 1) {
  fun <- match.arg(fun)
  if (is.null(dim(x))) {
    x <- matrix(x, ncol = 1L)
  }
  k <- ncol(x)
  n_valid <- rowSums(!is.na(x))
  needed <- max(1L, ceiling(min_valid * k))

  out <- rowMeans(x, na.rm = TRUE)
  if (identical(fun, "sum")) {
    out <- out * k
  }
  out[n_valid < needed] <- NA_real_
  out
}


# Internal: the default aggregator -- one column per subscale, plus the
# instrument's overall score when it defines one.
.q_aggregate_default <- function(x, def, min_valid = 1) {
  memberships <- .q_subscales(def$items$subscale)
  subs <- .q_subscale_names(def)

  out <- lapply(subs, function(s) {
    cols <- vapply(memberships, function(m) s %in% m, logical(1))
    .rowagg(x[, cols, drop = FALSE], "mean", min_valid)
  })
  names(out) <- .q_colname(subs)
  out <- as.data.frame(out, stringsAsFactors = FALSE)

  if (!is.null(def$total)) {
    total_col <- .q_colname(.q_total_name(def))
    if (total_col %in% names(out)) {
      stop(
        "Instrument '", def$key, "' has a subscale that resolves to the same ",
        "column name as its overall score ('", total_col,
        "'), so the subscale would be overwritten. Rename the subscale, or pass ",
        "a different total_name to define_questionnaire().",
        call. = FALSE
      )
    }
    out[[total_col]] <- .rowagg(x, def$total, min_valid)
  }
  out
}


# Internal: SUS. Items are already zero-based (0-4) by .q_prepare(), so the
# published multipliers apply directly and every column lands on 0-100.
.q_aggregate_sus <- function(x, def, min_valid = 1) {
  memberships <- unlist(.q_subscales(def$items$subscale), use.names = FALSE)
  data.frame(
    SUS = .rowagg(x, "sum", min_valid) * 2.5,
    Usability = .rowagg(x[, memberships == "Usability", drop = FALSE], "sum", min_valid) * 3.125,
    Learnability = .rowagg(x[, memberships == "Learnability", drop = FALSE], "sum", min_valid) * 12.5
  )
}


# Internal: SSQ. The three subscales overlap, and the total is computed from the
# UNWEIGHTED subscale sums before the weights are applied -- not from the
# weighted ones, and not from all sixteen items.
.q_aggregate_ssq <- function(x, def, min_valid = 1) {
  memberships <- .q_subscales(def$items$subscale)
  raw <- function(s) {
    cols <- vapply(memberships, function(m) s %in% m, logical(1))
    .rowagg(x[, cols, drop = FALSE], "sum", min_valid)
  }
  n <- raw("Nausea")
  o <- raw("Oculomotor")
  d <- raw("Disorientation")

  data.frame(
    Nausea = n * 9.54,
    Oculomotor = o * 7.58,
    Disorientation = d * 13.92,
    Total = (n + o + d) * 3.74
  )
}


# Internal: the standing caution, in one place so the wording cannot drift
# between the functions that show it.
#
# This is not boilerplate. A questionnaire in the abstract has no item order:
# the numbering, the wording and the polarity all belong to the sheet a
# particular study put in front of its participants. Survey tools renumber,
# translators reorder, and a shortened form drops items from the middle. The
# definitions here reproduce the published form, which is the right default and
# is still only a default. A mismatch does not error -- it produces plausible
# numbers that are wrong, which is the one failure mode worth shouting about.
.q_caution <- function() {
  c(
    "CAUTION: item numbers, order and polarity depend on how the questionnaire",
    "was administered -- survey tools renumber items, translations reorder them,",
    "and short forms drop them. This package applies the PUBLISHED key. If your",
    "sheet differed, the scores will be wrong without any error being raised.",
    "Check the mapping against the survey your participants actually saw, and",
    "double-check any number before it goes into a paper."
  )
}


# Internal: emit the caution as its own block, so it reads as a caution rather
# than as the tail of a status line.
.q_message_caution <- function() {
  message(paste(.q_caution(), collapse = "\n"))
  invisible(NULL)
}


# Internal: say once per session what mapping an instrument is being scored
# with. Silent scoring is exactly how a mis-numbered item survives to the paper.
.q_announce <- function(def, cols, rev_flag, verbose = TRUE) {
  if (!isTRUE(verbose) || isTRUE(getOption("colleyRstats.quiet_questionnaires", FALSE))) {
    return(invisible(NULL))
  }
  # Key the "already said this" memo on the mapping, not just the instrument:
  # scoring the same instrument a second time with different columns or a
  # different reversal is exactly when the mapping needs saying again.
  signature <- paste(c(def$key, cols, as.integer(rev_flag)), collapse = "\r")
  if (identical(.q_announced[[def$key]], signature)) {
    return(invisible(NULL))
  }
  assign(def$key, signature, envir = .q_announced)

  reversed <- def$items$code[rev_flag]
  message(
    "Scoring ", def$name, " from ", length(cols), " columns (",
    cols[1], " ... ", cols[length(cols)], "); ",
    if (length(reversed)) {
      paste0("reverse-coded: ", paste(reversed, collapse = ", "), ".")
    } else {
      "no items reverse-coded."
    }
  )
  .q_message_caution()
  message(
    "  See the full mapping with check_questionnaire(data, \"", def$key, "\", ...); ",
    "silence this note with options(colleyRstats.quiet_questionnaires = TRUE)."
  )
  invisible(NULL)
}


#' Score a standardised questionnaire
#'
#' Turns the raw item columns of a published questionnaire into its subscale
#' scores, applying that instrument's own scoring key: reverse-coding, any
#' recoding it prescribes (centring a semantic differential to \eqn{-3..+3},
#' zero-basing the SUS), the subscale structure, and the published weights or
#' multipliers. Supported instruments are listed by [list_questionnaires()];
#' register your own with [define_questionnaire()].
#'
#' @param data A data frame with one row per respondent (or per respondent and
#'   condition) and one column per item.
#' @param instrument Instrument key, e.g. \code{"sus"}, \code{"nasa_tlx"},
#'   \code{"ueq_s"}, \code{"tia"}, \code{"ssq"}. See [list_questionnaires()].
#' @param items Optional. Either the item columns in the instrument's own order,
#'   or a character vector \emph{named} after the item codes
#'   (\code{c(mental = "tlx_md", effort = "tlx_ef", ...)}), which is order-proof
#'   and the safer choice for a survey export you did not lay out yourself.
#' @param prefix Optional column-name prefix selecting the item columns, e.g.
#'   \code{"sus_"}. Matching columns are sorted numerically, so \code{sus_2}
#'   comes before \code{sus_10}. Must select exactly as many columns as the
#'   instrument has items.
#' @param scale Optional two-element vector giving the response range your
#'   survey used, e.g. \code{c(1, 21)} for the 21-point NASA-TLX sheet or
#'   \code{c(0, 4)} for a zero-based SUS. Responses are rescaled onto the
#'   instrument's own range before scoring. Defaults to the instrument's range;
#'   responses outside it are an error rather than a silent rescale.
#' @param reverse_items Optional items to \emph{toggle} the reverse-coding of,
#'   given as item numbers or item codes. Naming an item the scoring key already
#'   reverses un-reverses it, which is what an export that stores a pair the
#'   other way round needs.
#' @param min_valid Minimum proportion of a subscale's items that must be
#'   answered for a score to be produced. The default \code{1} scores only
#'   complete subscales and returns \code{NA} otherwise -- no silent imputation.
#'   Relax it (e.g. \code{0.8}) to score partially complete responses, in which
#'   case a subscale is the mean of the items present, and a sum-scored
#'   instrument is scaled up proportionally so it stays on its published range.
#' @param append Logical. If \code{TRUE}, return \code{data} with the score
#'   columns added; if \code{FALSE} (default), return only the scores.
#' @param prefix_out Optional string prefixed to every score column, useful when
#'   the same instrument is scored more than once per row (pre/post, or one
#'   block per condition).
#' @param verbose Logical. If \code{TRUE} (default), emit the one-time mapping
#'   message described above.
#'
#' @return A data frame with one row per row of \code{data} and one column per
#'   subscale, plus the instrument's overall score where it defines one. The
#'   instrument definition and the resolved column mapping are attached as the
#'   \code{"instrument"} and \code{"mapping"} attributes.
#' @export
#' @template questionnaire-caution
#' @seealso [check_questionnaire()] to verify the mapping,
#'   [score_reliability()] for internal consistency,
#'   [questionnaire_items()] for the item list,
#'   [define_questionnaire()] to add an instrument.
#'
#' @examples
#' set.seed(42)
#' sus_raw <- as.data.frame(matrix(sample(1:5, 10 * 6, TRUE), nrow = 6))
#' names(sus_raw) <- paste0("sus_", 1:10)
#'
#' score_questionnaire(sus_raw, "sus", prefix = "sus_")
#'
#' # A 21-point NASA-TLX sheet, scored onto the conventional 0-100
#' tlx <- data.frame(
#'   mental = c(14, 3), physical = c(2, 1), temporal = c(11, 4),
#'   performance = c(6, 2), effort = c(13, 5), frustration = c(9, 1)
#' )
#' score_questionnaire(tlx, "nasa_tlx", scale = c(1, 21))
score_questionnaire <- function(data, instrument, items = NULL, prefix = NULL,
                                scale = NULL, reverse_items = NULL,
                                min_valid = 1, append = FALSE,
                                prefix_out = NULL, verbose = TRUE) {
  not_empty(data)
  if (!is.data.frame(data)) {
    stop("`data` must be a data frame.", call. = FALSE)
  }
  if (!is.numeric(min_valid) || length(min_valid) != 1 || min_valid <= 0 || min_valid > 1) {
    stop("`min_valid` must be a single number greater than 0 and at most 1.", call. = FALSE)
  }

  def <- .q_get(instrument)
  cols <- .q_resolve_items(data, def, items = items, prefix = prefix)
  x <- .q_prepare(data, def, cols, scale = scale, reverse_items = reverse_items)
  rev_flag <- attr(x, "reverse")

  .q_announce(def, cols, rev_flag, verbose = verbose)

  aggregate_fun <- if (is.null(def$aggregate)) .q_aggregate_default else def$aggregate
  scores <- aggregate_fun(x, def, min_valid = min_valid)
  scores <- as.data.frame(scores, stringsAsFactors = FALSE)
  rownames(scores) <- NULL

  if (!is.null(prefix_out)) {
    names(scores) <- paste0(prefix_out, names(scores))
  }

  mapping <- data.frame(
    item = def$items$item,
    code = def$items$code,
    column = cols,
    subscale = def$items$subscale,
    reverse = rev_flag,
    stringsAsFactors = FALSE
  )

  if (isTRUE(append)) {
    clash <- intersect(names(scores), names(data))
    if (length(clash) > 0) {
      stop(
        "Score column", if (length(clash) > 1) "s" else "", " ",
        paste0("'", clash, "'", collapse = ", "),
        " already exist in `data`. Pass `prefix_out` to disambiguate.",
        call. = FALSE
      )
    }
    out <- dplyr::bind_cols(data, scores)
  } else {
    out <- scores
  }

  attr(out, "instrument") <- def$key
  attr(out, "mapping") <- mapping
  out
}


#' Show how a questionnaire will be scored, before scoring it
#'
#' Prints the mapping [score_questionnaire()] would use -- which column supplies
#' which item, which subscale it loads on, whether it is reverse-coded -- along
#' with the observed range of each column and the instrument's scoring notes.
#' Run it once per study: it is the cheapest available check against the failure
#' mode in which a shifted survey export produces perfectly plausible, wrong
#' scores.
#'
#' @inheritParams score_questionnaire
#'
#' @return Invisibly, a data frame with one row per item: the item number and
#'   code, the column it maps to, its subscale, whether it is reverse-coded, and
#'   the observed minimum, maximum and number of missing values of that column.
#' @export
#' @template questionnaire-caution
#' @seealso [score_questionnaire()], [questionnaire_items()]
#'
#' @examples
#' set.seed(1)
#' d <- as.data.frame(matrix(sample(1:5, 10 * 4, TRUE), nrow = 4))
#' names(d) <- paste0("sus_", 1:10)
#' check_questionnaire(d, "sus", prefix = "sus_")
check_questionnaire <- function(data, instrument, items = NULL, prefix = NULL,
                                scale = NULL, reverse_items = NULL) {
  not_empty(data)
  def <- .q_get(instrument)
  cols <- .q_resolve_items(data, def, items = items, prefix = prefix)

  rev_flag <- def$items$reverse
  if (!is.null(reverse_items)) {
    idx <- .q_match_items(def, reverse_items)
    rev_flag[idx] <- !rev_flag[idx]
  }

  # A column this cannot convert is a finding to report, not a reason to abort
  # the very check that would explain it.
  raw <- Map(function(v, nm) {
    tryCatch(.q_as_numeric(v, nm), error = function(e) rep(NA_real_, length(v)))
  }, data[cols], cols)

  # min/max over an all-NA column reduce over an empty vector and return
  # Inf/-Inf; report the absence as NA, which is what the column shows.
  span <- function(v, f) if (all(is.na(v))) NA_real_ else suppressWarnings(f(v, na.rm = TRUE))

  out <- data.frame(
    item = def$items$item,
    code = def$items$code,
    column = cols,
    subscale = def$items$subscale,
    reverse = rev_flag,
    observed_min = vapply(raw, span, numeric(1), f = min),
    observed_max = vapply(raw, span, numeric(1), f = max),
    n_missing = vapply(raw, function(v) sum(is.na(v)), integer(1)),
    stringsAsFactors = FALSE
  )
  rownames(out) <- NULL

  assumed <- if (is.null(scale)) def$scale else as.numeric(scale)
  message(def$name, " -- ", def$reference)
  .q_message_caution()
  message(
    "Assumed response range: ", assumed[1], "-", assumed[2],
    if (is.null(scale)) " (the instrument's own; pass `scale` if your survey differed)" else " (from `scale`)",
    if (!identical(as.numeric(assumed), as.numeric(def$scale))) {
      paste0(", rescaled to ", def$scale[1], "-", def$scale[2], " for scoring")
    } else {
      ""
    }
  )

  observed <- if (all(is.na(out$observed_min))) {
    c(NA_real_, NA_real_)
  } else {
    suppressWarnings(c(min(out$observed_min, na.rm = TRUE), max(out$observed_max, na.rm = TRUE)))
  }
  if (all(is.finite(observed)) && (observed[1] < assumed[1] || observed[2] > assumed[2])) {
    warning(
      "Responses run from ", observed[1], " to ", observed[2],
      ", outside the assumed range ", assumed[1], "-", assumed[2],
      ". score_questionnaire() will stop until `scale` matches the data.",
      call. = FALSE
    )
  }

  message("\nItem mapping (verify against the survey your participants saw):")
  print(out, row.names = FALSE)

  if (length(def$notes) > 0) {
    message("\nNotes:")
    for (note in def$notes) {
      message("  - ", note)
    }
  }
  invisible(out)
}


#' List the questionnaires this package can score
#'
#' @return A data frame with one row per instrument: its key (the value to pass
#'   as \code{instrument}), full name, number of items, number of subscales, the
#'   response range it assumes, the direction a high score means, and its
#'   reference.
#' @export
#' @seealso [questionnaire_items()], [score_questionnaire()],
#'   [define_questionnaire()]
#'
#' @examples
#' list_questionnaires()
list_questionnaires <- function() {
  reg <- .q_registry()
  out <- do.call(rbind, lapply(reg, function(def) {
    data.frame(
      key = def$key,
      name = def$name,
      n_items = nrow(def$items),
      n_subscales = length(.q_subscale_names(def)),
      scale = paste0(def$scale[1], "-", def$scale[2]),
      higher_is = if (is.na(def$higher)) "" else def$higher,
      reference = def$reference,
      stringsAsFactors = FALSE
    )
  }))
  out <- out[order(out$key), , drop = FALSE]
  rownames(out) <- NULL
  out
}


#' The items of one questionnaire
#'
#' @param instrument Instrument key, e.g. \code{"tia"}. See
#'   [list_questionnaires()].
#' @param notes Logical. If \code{TRUE} (default), also emit the instrument's
#'   scoring notes -- how the overall score is formed, what its range means, and
#'   where its published form is known to vary between administrations.
#'
#' @return Invisibly, a data frame with one row per item: number, code, wording,
#'   subscale, and whether the scoring key reverses it.
#' @export
#' @template questionnaire-caution
#' @seealso [check_questionnaire()], [score_questionnaire()]
#'
#' @examples
#' questionnaire_items("ueq_s")
questionnaire_items <- function(instrument, notes = TRUE) {
  def <- .q_get(instrument)
  if (isTRUE(notes)) {
    message(def$name, " -- ", def$reference)
    message(
      "Response range ", def$scale[1], "-", def$scale[2], "; ",
      nrow(def$items), " items in ", length(.q_subscale_names(def)), " subscale",
      if (length(.q_subscale_names(def)) == 1) "" else "s", "."
    )
    .q_message_caution()
    for (note in def$notes) {
      message("  - ", note)
    }
  }
  out <- def$items
  rownames(out) <- NULL
  print(out, row.names = FALSE)
  invisible(out)
}


#' Register your own questionnaire
#'
#' Adds an instrument to the registry so that [score_questionnaire()],
#' [check_questionnaire()] and [score_reliability()] handle it exactly like a
#' built-in one. Use it for a lab-specific scale, a translated or shortened
#' form, or a published instrument this package does not ship -- and put the
#' call in a project's setup script so every analysis in that project scores it
#' the same way.
#'
#' @param key Short identifier, used as the \code{instrument} argument.
#' @param name Full name of the instrument, shown in messages and listings.
#' @param scale Two-element vector giving the response range, e.g.
#'   \code{c(1, 7)}.
#' @param subscale Character vector, one entry per item, naming the subscale
#'   that item loads on. Use a comma-separated string
#'   (\code{"Nausea,Oculomotor"}) for an item that loads on two.
#' @param code Optional short code per item, used to refer to items in
#'   \code{reverse_items} and in a named \code{items} mapping. Defaults to
#'   \code{item1}, \code{item2}, ...
#' @param label Optional item wording, one entry per item.
#' @param reverse Optional item numbers that are reverse-scored.
#' @param recode One of \code{"none"} (default), \code{"center"} (subtract the
#'   midpoint, giving the \eqn{-3..+3} coding of a 7-point semantic
#'   differential), or \code{"zero_base"} (subtract the minimum).
#' @param total How to form an overall score across all items: \code{"mean"},
#'   \code{"sum"}, or \code{NULL} (default) for none -- which is the honest
#'   choice for a multidimensional instrument whose authors define no total.
#' @param total_name Column name for that overall score. Default
#'   \code{"Total"}.
#' @param reference Optional citation, shown alongside the instrument.
#' @param higher Optional one-word note on what a high score means, e.g.
#'   \code{"better"} or \code{"worse"}.
#' @param notes Optional character vector of scoring notes.
#'
#' @return Invisibly, the instrument definition.
#' @export
#' @template questionnaire-caution
#' @seealso [list_questionnaires()], [score_questionnaire()]
#'
#' @examples
#' define_questionnaire(
#'   key = "acceptance",
#'   name = "Van der Laan acceptance scale",
#'   reference = "Van der Laan, Heino & De Waard (1997), Transp. Res. C 5(1)",
#'   scale = c(-2, 2),
#'   subscale = c(
#'     "Usefulness", "Satisfying", "Usefulness", "Satisfying", "Usefulness",
#'     "Satisfying", "Usefulness", "Satisfying", "Usefulness"
#'   ),
#'   label = c(
#'     "useful - useless", "pleasant - unpleasant", "bad - good",
#'     "nice - annoying", "effective - superfluous", "irritating - likeable",
#'     "assisting - worthless", "undesirable - desirable", "raising alertness - sleep-inducing"
#'   ),
#'   reverse = c(1, 2, 4, 5, 7, 9),
#'   higher = "better"
#' )
#' list_questionnaires()[1, ]
define_questionnaire <- function(key, name, scale, subscale, code = NULL,
                                 label = NULL, reverse = integer(0),
                                 recode = c("none", "center", "zero_base"),
                                 total = NULL, total_name = "Total",
                                 reference = NA_character_,
                                 higher = NA_character_, notes = character()) {
  not_empty(key)
  not_empty(name)
  not_empty(subscale)
  recode <- match.arg(recode)

  n <- length(subscale)
  if (is.null(code)) code <- paste0("item", seq_len(n))
  if (is.null(label)) label <- code
  if (length(scale) != 2 || !all(is.finite(scale)) || scale[1] >= scale[2]) {
    stop("`scale` must be two increasing finite numbers, e.g. c(1, 7).", call. = FALSE)
  }
  if (!is.null(total) && !total %in% c("mean", "sum")) {
    stop("`total` must be \"mean\", \"sum\", or NULL.", call. = FALSE)
  }
  if (length(code) != n || length(label) != n) {
    stop(
      "`subscale`, `code` and `label` must have one entry per item; got ",
      n, ", ", length(code), " and ", length(label), ".",
      call. = FALSE
    )
  }
  if (anyDuplicated(code) > 0) {
    stop(
      "`code` must be unique; duplicated: ",
      paste0("'", unique(code[duplicated(code)]), "'", collapse = ", "), ".",
      call. = FALSE
    )
  }
  if (any(!nzchar(trimws(subscale)))) {
    stop("Every item needs a non-empty `subscale`.", call. = FALSE)
  }

  # Distinct subscale names that clean to the same column name would collide in
  # the scored output, where as.data.frame() would silently disambiguate them to
  # `A_B` and `A_B.1` -- two columns nothing identifies. Same for a subscale that
  # collides with the overall-score column.
  subs <- unique(unlist(lapply(strsplit(subscale, ",", fixed = TRUE), trimws)))
  cleaned <- .q_colname(subs)
  if (anyDuplicated(cleaned) > 0) {
    clash <- unique(cleaned[duplicated(cleaned)])
    stop(
      "These subscales differ but resolve to the same score column: ",
      paste0("'", subs[cleaned %in% clash], "'", collapse = ", "),
      " (all become '", clash[1], "'). Rename them so the scored columns stay distinct.",
      call. = FALSE
    )
  }
  if (!is.null(total) && .q_colname(total_name) %in% cleaned) {
    stop(
      "`total_name` ('", total_name, "') resolves to the same column as the subscale '",
      subs[cleaned == .q_colname(total_name)][1],
      "', so the subscale would be overwritten by the overall score.",
      call. = FALSE
    )
  }

  key <- tolower(gsub("[^A-Za-z0-9]+", "_", as.character(key)[1]))
  def <- .q_def(
    key = key, name = name, reference = reference, scale = as.numeric(scale),
    code = code, label = label, subscale = subscale, reverse = reverse,
    recode = recode, total = total, higher = higher, notes = notes
  )
  def$total_name <- total_name

  assign(key, def, envir = .q_user)
  # A redefinition must be able to announce its new mapping.
  if (!is.null(.q_announced[[key]])) {
    rm(list = key, envir = .q_announced)
  }
  invisible(def)
}


#' Reverse-code responses
#'
#' Flips a response scale so that a negatively worded item points the same way
#' as the rest of its subscale: \code{min + max - x}.
#'
#' @param x Numeric responses.
#' @param min,max The endpoints of the response scale the item was answered on
#'   -- the \emph{possible} range, not the observed one. Taking them from the
#'   data is the classic reverse-coding bug: if nobody picked 1, the flip is
#'   off by a point for every respondent.
#'
#' @return \code{x}, reverse-coded, with \code{NA} preserved.
#' @export
#'
#' @examples
#' reverse_code(c(1, 3, 5, NA), min = 1, max = 5)
reverse_code <- function(x, min, max) {
  not_empty(x)
  if (length(min) != 1 || length(max) != 1 || !is.finite(min) || !is.finite(max) || min >= max) {
    stop("`min` and `max` must be single finite numbers with min < max.", call. = FALSE)
  }
  x <- suppressWarnings(as.numeric(x))
  out_of_range <- !is.na(x) & (x < min | x > max)
  if (any(out_of_range)) {
    warning(
      sum(out_of_range), " value", if (sum(out_of_range) == 1) "" else "s",
      " lie outside the stated scale ", min, "-", max,
      "; the reverse-coding of those is meaningless.",
      call. = FALSE
    )
  }
  min + max - x
}


#' Internal consistency of a questionnaire's subscales
#'
#' Cronbach's alpha per subscale, computed on the same recoded item matrix that
#' [score_questionnaire()] aggregates -- so reverse-coded items are already
#' flipped, and a negative alpha means a genuine problem rather than a forgotten
#' reversal. McDonald's omega is added when \pkg{psych} is installed, and is the
#' better-behaved statistic when a subscale's items are not equally good
#' indicators.
#'
#' @inheritParams score_questionnaire
#'
#' @return A data frame with one row per subscale: the number of items, the
#'   number of complete cases it was computed on, \code{alpha}, \code{omega}
#'   (\code{NA} without \pkg{psych}), and the mean inter-item correlation.
#'   Subscales of a single item yield \code{NA} -- internal consistency is not
#'   defined for them.
#' @export
#' @template questionnaire-caution
#' @seealso [score_questionnaire()]
#'
#' @examples
#' set.seed(3)
#' trait <- rnorm(60)
#' d <- as.data.frame(lapply(1:10, function(i) {
#'   round(pmin(pmax(3 + trait + rnorm(60, sd = 0.6), 1), 5))
#' }))
#' names(d) <- paste0("sus_", 1:10)
#' # Items 2, 4, 6, 8, 10 are negatively worded on the real SUS, so flip them
#' d[paste0("sus_", c(2, 4, 6, 8, 10))] <- 6 - d[paste0("sus_", c(2, 4, 6, 8, 10))]
#' score_reliability(d, "sus", prefix = "sus_")
score_reliability <- function(data, instrument, items = NULL, prefix = NULL,
                              scale = NULL, reverse_items = NULL,
                              verbose = TRUE) {
  not_empty(data)
  def <- .q_get(instrument)
  cols <- .q_resolve_items(data, def, items = items, prefix = prefix)
  x <- .q_prepare(data, def, cols, scale = scale, reverse_items = reverse_items)

  # Alpha is computed from the same mapping the scores are, so it carries the
  # same caveat: a wrong item order gives a wrong alpha just as quietly.
  .q_announce(def, cols, attr(x, "reverse"), verbose = verbose)

  memberships <- .q_subscales(def$items$subscale)
  subs <- .q_subscale_names(def)

  out <- do.call(rbind, lapply(subs, function(s) {
    keep <- vapply(memberships, function(m) s %in% m, logical(1))
    block <- x[, keep, drop = FALSE]
    block <- block[stats::complete.cases(block), , drop = FALSE]
    k <- ncol(block)
    n <- nrow(block)

    alpha <- NA_real_
    mic <- NA_real_
    if (k >= 2 && n >= 3) {
      item_var <- apply(block, 2, stats::var)
      total_var <- stats::var(rowSums(block))
      if (is.finite(total_var) && total_var > 0) {
        alpha <- (k / (k - 1)) * (1 - sum(item_var) / total_var)
      }
      cm <- suppressWarnings(stats::cor(block))
      mic <- mean(cm[upper.tri(cm)], na.rm = TRUE)
    }

    omega <- NA_real_
    if (k >= 3 && n >= 3 && requireNamespace("psych", quietly = TRUE)) {
      omega <- tryCatch(
        suppressWarnings(suppressMessages(psych::omega(block, nfactors = 1, plot = FALSE)$omega.tot)),
        error = function(e) NA_real_
      )
    }

    data.frame(
      subscale = s, n_items = k, n_complete = n,
      alpha = alpha, omega = as.numeric(omega)[1], mean_item_cor = mic,
      stringsAsFactors = FALSE
    )
  }))
  rownames(out) <- NULL

  if (any(!is.na(out$alpha) & out$alpha < 0)) {
    warning(
      "A negative alpha means the items of a subscale do not point the same way. ",
      "Check the reverse-coding with check_questionnaire() before reporting.",
      call. = FALSE
    )
  }
  out
}


#' Summarise a motion-sickness time course
#'
#' Repeated single-item sickness ratings (FMS, MISC) are collected once a minute
#' and then, almost always, reduced to a handful of per-participant numbers
#' before they are analysed. This produces those numbers: peak, mean, final
#' rating, the area under the rating curve, and when a threshold was first
#' crossed.
#'
#' @param data A data frame in long format: one row per rating.
#' @param value Column holding the rating.
#' @param id Column identifying the participant (and, with \code{by}, the
#'   condition).
#' @param time Optional column holding the time of the rating, in whatever unit
#'   the study used. Needed for a meaningful area under the curve and for
#'   time-to-threshold; without it, the rating index is used and \code{auc} is
#'   reported in rating-steps.
#' @param by Optional further grouping columns, e.g. the experimental condition.
#' @param threshold Optional rating at or above which a participant counts as
#'   affected, e.g. \code{6} for MISC (nausea) or \code{10} for FMS.
#'
#' @return A data frame with one row per participant (and \code{by} group):
#'   \code{n} ratings, \code{peak}, \code{mean}, \code{final}, \code{auc}
#'   (trapezoidal), \code{auc_rate} (the AUC divided by the observed duration,
#'   i.e. the time-weighted mean rating), and -- with \code{threshold} --
#'   \code{reached} and \code{time_to_threshold}.
#' @export
#' @seealso [score_questionnaire()] for the single-measurement instruments
#'
#' @examples
#' d <- data.frame(
#'   pid = rep(c("p1", "p2"), each = 5),
#'   minute = rep(0:4, 2),
#'   fms = c(0, 1, 3, 6, 8, 0, 0, 1, 1, 2)
#' )
#' summarize_sickness(d, value = "fms", id = "pid", time = "minute", threshold = 5)
summarize_sickness <- function(data, value, id, time = NULL, by = NULL,
                               threshold = NULL) {
  not_empty(data)
  not_empty(value)
  not_empty(id)
  .check_columns(data, c(value, id, time, by))

  group_cols <- c(id, by)
  keys <- interaction(data[group_cols], drop = TRUE, sep = "\r")

  out <- do.call(rbind, lapply(split(seq_len(nrow(data)), keys), function(rows) {
    block <- data[rows, , drop = FALSE]
    v <- .q_as_numeric(block[[value]], value)
    t <- if (is.null(time)) seq_along(v) else .q_as_numeric(block[[time]], time)

    ord <- order(t)
    v <- v[ord]
    t <- t[ord]
    keep <- !is.na(v) & !is.na(t)
    v <- v[keep]
    t <- t[keep]

    auc <- NA_real_
    auc_rate <- NA_real_
    if (length(v) >= 2) {
      # Trapezoidal rule: the rating is taken to change linearly between two
      # samples, which is the standard reduction for minute-by-minute FMS.
      auc <- sum(diff(t) * (utils::head(v, -1) + utils::tail(v, -1)) / 2)
      span <- t[length(t)] - t[1]
      if (span > 0) auc_rate <- auc / span
    }

    row <- data.frame(
      block[1, group_cols, drop = FALSE],
      n = length(v),
      peak = if (length(v)) max(v) else NA_real_,
      mean = if (length(v)) mean(v) else NA_real_,
      final = if (length(v)) v[length(v)] else NA_real_,
      auc = auc,
      auc_rate = auc_rate,
      stringsAsFactors = FALSE
    )

    if (!is.null(threshold)) {
      hit <- which(v >= threshold)
      # A participant with no usable rating has not been shown to be unaffected;
      # reporting FALSE would pull an incidence rate down with them in it.
      row$reached <- if (length(v) == 0) NA else length(hit) > 0
      row$time_to_threshold <- if (length(hit)) t[hit[1]] else NA_real_
    }
    row
  }))

  rownames(out) <- NULL
  out[do.call(order, out[group_cols]), , drop = FALSE]
}
