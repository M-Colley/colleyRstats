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
# SSQ has five items that load on two, written "Nausea,Oculomotor".
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


# Internal: does the instrument define an overall score? A `total` rule implies
# one; instruments scored by a custom aggregator (SUS, SSQ) declare it.
.q_has_overall <- function(def) {
  !is.null(def$total) || isTRUE(def$overall)
}


# Internal: validate a response range wherever one is accepted. A single number
# or a reversed pair would otherwise surface later as "range 5-NA" or as a
# rescale onto a negative span, both of which score without complaint.
.q_check_scale <- function(scale, arg = "scale") {
  if (!is.numeric(scale) || length(scale) != 2 || anyNA(scale) ||
    !all(is.finite(scale)) || scale[1] >= scale[2]) {
    stop(
      "`", arg, "` must be two increasing finite numbers, e.g. c(1, 7); got ",
      paste(deparse(scale), collapse = ""), ".",
      call. = FALSE
    )
  }
  as.numeric(scale)
}


# Internal: the scale centre on the RECODED metric the aggregators see. Reverse-
# coding maps the centre onto itself, so one value serves every item.
.q_centre <- function(def) {
  mid <- mean(def$scale)
  switch(def$recode,
    none = mid,
    center = 0,
    zero_base = mid - def$scale[1],
    stop("Unknown recode '", def$recode, "' in instrument '", def$key, "'.", call. = FALSE)
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
#
# Text columns get the same treatment. as.numeric() turns "Strongly agree",
# "5 - Strongly agree" and the decimal-comma "2,5" into NA without complaint,
# and with `min_valid` < 1 the row is then scored over the remaining items as if
# the participant had skipped one. A blank cell is a missing response; any other
# value that is not a number stops scoring, naming the values.
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
    bad_levels <- levels(v)[is.na(label_values)]
    stop(
      "Item column '", column, "' is an unordered factor whose levels are not ",
      "numbers (", paste0("'", utils::head(bad_levels, 3), "'", collapse = ", "),
      if (length(bad_levels) > 3) ", ..." else "", "). Its level order is collation ",
      "order, not response order, so scoring it would be a guess. Convert it ",
      "first -- factor(x, levels = c(...), ordered = TRUE) if the labels are ",
      "response options in order, or recode it to numbers.",
      call. = FALSE
    )
  }

  if (is.character(v)) {
    txt <- trimws(v)
    txt[txt %in% c("", "NA")] <- NA_character_
    out <- suppressWarnings(as.numeric(txt))
    bad <- !is.na(txt) & is.na(out)
    if (any(bad)) {
      stop(.q_unparseable_message(column, unique(txt[bad])), call. = FALSE)
    }
    return(out)
  }

  # Dates, times and difftimes have a numeric value as.numeric() recovers; any
  # other type that loses values in the conversion is refused the same way.
  out <- suppressWarnings(as.numeric(v))
  bad <- !is.na(v) & is.na(out)
  if (any(bad)) {
    stop(.q_unparseable_message(column, unique(as.character(v[bad]))), call. = FALSE)
  }
  out
}


# Internal: why a column could not be read as numbers, and how to fix it. The
# remedy depends on what the text looks like, so say the one that applies.
.q_unparseable_message <- function(column, values) {
  shown <- utils::head(values, 5)
  hints <- character()
  if (any(grepl("^[[:space:]]*-?[0-9]+,[0-9]+[[:space:]]*$", values))) {
    hints <- c(hints, paste0(
      "decimal commas (\"2,5\"): read the file with read.csv2() or ",
      "read.csv(dec = \",\"), or convert with as.numeric(sub(\",\", \".\", x))"
    ))
  }
  if (any(grepl("^[[:space:]]*-?[0-9]+[^0-9,.]", values))) {
    hints <- c(hints, paste0(
      "a number followed by its label (\"5 - Strongly agree\"): keep the number with ",
      "as.numeric(sub(\"^[[:space:]]*(-?[0-9]+).*$\", \"\\\\1\", x)) -- after checking ",
      "that the number is the response code you expect"
    ))
  }
  if (length(hints) == 0) {
    hints <- paste0(
      "response labels (\"Strongly agree\"): recode them to their scale values, e.g. ",
      "unname(c(\"Strongly disagree\" = 1, ..., \"Strongly agree\" = 5)[x]), or export ",
      "numeric codes from the survey tool"
    )
  }
  paste0(
    "Column '", column, "' holds values that are not numbers: ",
    paste0("'", shown, "'", collapse = ", "),
    if (length(values) > length(shown)) paste0(", ... (", length(values), " distinct)") else "",
    ". Converting them would silently turn those responses into missing values ",
    "and score the remaining items as if they had been skipped. Recode the column ",
    "to numbers first. For ", paste(hints, collapse = "; for "), "."
  )
}


# Internal: the one item index carried by each column-name remainder, or NULL
# when there is no such index.
#
# The index is a run of digits. When a remainder carries several runs --
# Qualtrics "5_3" (block 5, item 3), or "3_1" from an export that numbers every
# column "SUS_<item>_1" -- the index is the one run that varies across the
# columns while every other run stays constant. Anything else (no digits, a
# different number of runs per column, or two runs that both vary, as in a grid
# of items x conditions) has no unambiguous index, and guessing one is how the
# old sort-by-name mapping filled Mental Demand from the Effort column.
.q_item_index <- function(rem) {
  runs <- regmatches(rem, gregexpr("[0-9]+", rem))
  counts <- lengths(runs)
  if (any(counts == 0L) || length(unique(counts)) != 1L) {
    return(NULL)
  }
  m <- matrix(as.numeric(unlist(runs, use.names = FALSE)), ncol = counts[1], byrow = TRUE)
  if (ncol(m) == 1L) {
    return(m[, 1])
  }
  varying <- apply(m, 2, function(col) length(unique(col)) > 1L)
  if (sum(varying) != 1L) {
    return(NULL)
  }
  m[, varying]
}


# Internal: normalise a name for matching -- case and punctuation are not
# information in a column name ("Mental_Demand", "mental demand", "MENTAL.DEMAND").
.q_norm <- function(x) {
  gsub("[^a-z0-9]", "", tolower(as.character(x)))
}


# Internal: map the remainders of prefixed column names onto items BY NAME:
# first against the item codes, then against the item labels and the names of
# single-item subscales (the NASA-TLX's "Mental Demand"). Returns, for each
# remainder, the item number it names, or NA when it names none unambiguously.
.q_match_by_name <- function(rem, def) {
  key <- .q_norm(rem)
  codes <- .q_norm(def$items$code)
  memberships <- .q_subscales(def$items$subscale)
  subs <- vapply(memberships, function(m) if (length(m) == 1L) m else NA_character_, character(1))
  sub_size <- table(unlist(memberships, use.names = FALSE))
  subs[!is.na(subs) & sub_size[subs] != 1L] <- NA_character_

  vapply(key, function(k) {
    hit <- which(codes == k)
    if (length(hit) == 0L) {
      hit <- which(.q_norm(def$items$label) == k | (!is.na(subs) & .q_norm(subs) == k))
    }
    if (length(hit) == 1L) hit else NA_integer_
  }, integer(1), USE.NAMES = FALSE)
}


# Internal: work out which columns of `data` hold the instrument's items, in the
# instrument's own order. Three ways in, most explicit first. The result carries
# a "matched_by" attribute saying how, for the scoring message.
.q_resolve_items <- function(data, def, items = NULL, prefix = NULL) {
  cols <- .q_resolve_items_impl(data, def, items = items, prefix = prefix)
  how <- attr(cols, "matched_by")
  cols <- as.character(cols)

  # One column cannot answer two items. rep("sus_1", 10) would otherwise score a
  # single column ten times, against ten different scoring rules.
  if (anyDuplicated(cols) > 0) {
    dup <- unique(cols[duplicated(cols)])
    stop(
      "Each item of ", def$name, " needs its own column, but ",
      paste0("'", dup, "'", collapse = ", "), " ",
      if (length(dup) == 1) "is" else "are", " given for more than one item.",
      call. = FALSE
    )
  }
  attr(cols, "matched_by") <- how
  cols
}


.q_resolve_items_impl <- function(data, def, items = NULL, prefix = NULL) {
  n <- nrow(def$items)
  codes <- def$items$code

  if (!is.null(items)) {
    # setNames, not as.character(): as.character() drops the names attribute, so
    # coercing first would make the named branch below unreachable and silently
    # map every named vector positionally -- the exact failure the named form
    # exists to prevent.
    items <- stats::setNames(as.character(items), names(items))
    # Partly named is neither mapping: the named entries would be ignored and the
    # whole vector applied by position. Duplicated names would keep only the
    # first column given for that item.
    if (!is.null(names(items)) && any(nzchar(names(items))) && !all(nzchar(names(items)))) {
      stop(
        "`items` is partly named. Name every entry after its item code, or none ",
        "(then the columns are taken in the instrument's own order).",
        call. = FALSE
      )
    }
    if (!is.null(names(items)) && anyDuplicated(names(items)) > 0) {
      stop(
        "`items` names ", paste0("'", unique(names(items)[duplicated(names(items))]), "'", collapse = ", "),
        " more than once; each item code needs exactly one column.",
        call. = FALSE
      )
    }
    if (!is.null(names(items)) && all(nzchar(names(items)))) {
      missing_codes <- setdiff(codes, names(items))
      if (length(missing_codes) > 0) {
        stop(
          "`items` is named, so it must name every item of ", def$name, ". Missing: ",
          paste(missing_codes, collapse = ", "), ".",
          call. = FALSE
        )
      }
      unknown <- setdiff(names(items), codes)
      if (length(unknown) > 0) {
        stop(
          "`items` names ", paste0("'", unknown, "'", collapse = ", "),
          ", which ", if (length(unknown) == 1) "is not an item code" else "are not item codes",
          " of ", def$name, ". Item codes: ", paste(codes, collapse = ", "), ".",
          call. = FALSE
        )
      }
      cols <- unname(items[codes])
      how <- "item code (named `items`)"
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
      cols <- unname(items)
      how <- "position in `items`"
    }
    .check_columns(data, cols)
    attr(cols, "matched_by") <- how
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
    cols <- .q_map_prefixed(hits, substring(hits, nchar(prefix) + 1L), def, prefix)
    return(cols)
  }

  # Last resort: the item codes themselves, bare or prefixed with the key.
  for (candidate in list(codes, paste0(def$key, "_", codes))) {
    if (all(candidate %in% names(data))) {
      attr(candidate, "matched_by") <- "item code"
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


# Internal: put the columns a prefix selected into the instrument's item order.
#
# Sorting the names is not a mapping. "tlx_effort" sorts before "tlx_mental",
# "tia_pro1" before "tia_rc1", and "SUS_10_1" before "SUS_2_1", so a sort fills
# items from the wrong columns -- and, worse, applies the reversals to the wrong
# items -- while every score stays plausible. So the names have to SAY which item
# they hold, in one of two ways, or scoring stops:
#   1. by name: what follows the prefix is an item code (or the item's label, or
#      the name of a single-item subscale), compared without case or
#      punctuation -- "tlx_Mental_Demand", "ipq_SP2", "ad_hqs3";
#   2. by number: what follows the prefix carries one distinct item index each
#      (see .q_item_index()), and the indices are exactly 1..n. An export that
#      numbers from 0, or numbers within a longer block (11-20), is not
#      silently shifted onto 1..n: which item "0" is, is a guess.
.q_map_prefixed <- function(hits, rem, def, prefix) {
  n <- nrow(def$items)
  if (n == 1L) {
    attr(hits, "matched_by") <- "prefix (single item)"
    return(hits)
  }

  by_name <- .q_match_by_name(rem, def)
  if (!anyNA(by_name) && setequal(by_name, seq_len(n))) {
    cols <- hits[match(seq_len(n), by_name)]
    attr(cols, "matched_by") <- "item name"
    return(cols)
  }

  idx <- if (all(is.na(by_name))) .q_item_index(rem) else NULL
  if (!is.null(idx) && setequal(idx, seq_len(n)) && !anyDuplicated(idx)) {
    cols <- hits[match(seq_len(n), idx)]
    attr(cols, "matched_by") <- "item number"
    return(cols)
  }

  why <- if (any(!is.na(by_name))) {
    paste0(
      "only some of them name an item (",
      paste0("'", hits[!is.na(by_name)], "' = ", def$items$code[by_name[!is.na(by_name)]], collapse = ", "),
      ")"
    )
  } else if (!is.null(idx)) {
    paste0(
      "their item numbers are ", paste(sort(idx), collapse = ", "),
      " rather than 1-", n, " once each"
    )
  } else {
    paste0(
      "what follows the prefix neither matches the item codes (",
      paste(utils::head(def$items$code, 4), collapse = ", "),
      if (n > 4) ", ..." else "", ") nor carries one distinct item number per column"
    )
  }
  stop(
    "Prefix '", prefix, "' selects ", n, " columns (", paste(hits, collapse = ", "),
    "), but ", why, ", so which column holds which item of ", def$name,
    " cannot be read from the names. Sorting them would be a guess that silently ",
    "scores the wrong items. Pass `items` named by item code instead, e.g. items = c(",
    paste0(def$items$code[1:2], " = \"", hits[1:2], "\"", collapse = ", "),
    ", ...) -- see questionnaire_items('", def$key, "') for the codes.",
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


# Internal: which items to reverse-code, from the scoring key and the caller's
# adjustments.
#
# `reverse_items` TOGGLES, which predates `unreverse_items` and is kept so that
# existing scripts score as they did. But tutorials routinely pass an
# instrument's own reverse set ("reverse_items = c(2, 4, 6, 8, 10)" for the SUS)
# in the belief that it declares the reversed items -- and toggling then
# UN-reverses all five, so a perfect respondent scores 50. A one-time note
# cannot carry that, so it is a warning, pointing at `unreverse_items` for the
# rare export that genuinely stored those items pre-reversed.
.q_reverse_flags <- function(def, reverse_items = NULL, unreverse_items = NULL) {
  key_flag <- def$items$reverse
  rev_flag <- key_flag

  un_idx <- integer(0)
  if (!is.null(unreverse_items)) {
    un_idx <- unique(.q_match_items(def, unreverse_items))
    not_reversed <- un_idx[!key_flag[un_idx]]
    if (length(not_reversed) > 0) {
      stop(
        "`unreverse_items` names ", paste(def$items$code[not_reversed], collapse = ", "),
        ", which the scoring key of ", def$name, " does not reverse, so there is ",
        "nothing to undo. Items the key reverses: ",
        if (any(key_flag)) paste(def$items$code[key_flag], collapse = ", ") else "none",
        ". To reverse an item the key leaves alone, use `reverse_items`.",
        call. = FALSE
      )
    }
    rev_flag[un_idx] <- FALSE
  }

  if (!is.null(reverse_items)) {
    idx <- unique(.q_match_items(def, reverse_items))
    both <- intersect(idx, un_idx)
    if (length(both) > 0) {
      stop(
        "Item", if (length(both) > 1) "s " else " ",
        paste(def$items$code[both], collapse = ", "),
        " cannot be in both `reverse_items` and `unreverse_items`.",
        call. = FALSE
      )
    }
    already <- idx[key_flag[idx]]
    if (length(already) > 0) {
      whole_set <- setequal(already, which(key_flag)) && setequal(idx, which(key_flag))
      warning(
        "`reverse_items` names ", paste(def$items$code[already], collapse = ", "),
        if (whole_set) {
          paste0(" -- exactly the items the published key of ", def$name, " already reverses")
        } else {
          paste0(", which the published key of ", def$name, " already reverses")
        },
        ". `reverse_items` TOGGLES, so ", if (length(already) == 1) "this item is" else "these items are",
        " now UN-reversed and scored as if worded in the scale's direction. If you meant ",
        "to list the instrument's reversed items, drop them from `reverse_items`: the key ",
        "already applies them. If your export really stored them pre-reversed, say so ",
        "with `unreverse_items`, which does the same without this warning.",
        call. = FALSE
      )
    }
    rev_flag[idx] <- !rev_flag[idx]
  }
  rev_flag
}


# Internal: warnings for a response coding that fits the assumed range but looks
# shifted against it. The range check only catches values OUTSIDE the range;
# these catch the quieter case in which nobody happened to choose the one scale
# point that would have fallen outside it.
#
#   * NASA-TLX: every response at or below 21 on the 0-100 scale is the
#     signature of the 21-point paper sheet (or a 20-point slider). Scored as
#     0-100 it understates workload about five-fold.
#   * A zero-based instrument (IPQ 0-6, SSQ 0-3) on which NOBODY chose 0, across
#     every item and respondent, is what a 1-based export (1-7, 1-4) looks like
#     when nobody chose the top point. Every response is then one point too
#     high, and every reversal is off by two.
#   * A one-based instrument (SUS 1-5, UEQ 1-7, TiA 1-5) on which NOBODY chose
#     the top point is what a 0-based export (0-4, 0-6) looks like when nobody
#     chose 0.
#
# Both general rules need several respondents and a multi-item, whole-point
# instrument -- with one row, or a single item such as the FMS, an unused end
# of the scale is unremarkable. They are only ever warnings, and an explicit
# `scale` (which the caller has therefore thought about) silences them.
.q_coding_warnings <- function(def, x, from, scale_supplied) {
  if (isTRUE(scale_supplied)) {
    return(character())
  }
  observed <- suppressWarnings(range(x, na.rm = TRUE))
  if (any(!is.finite(observed))) {
    return(character())
  }
  obs_txt <- paste0(.q_fmt_value(observed[1]), " to ", .q_fmt_value(observed[2]))
  out <- character()

  if (identical(def$key, "nasa_tlx") && observed[2] <= 21) {
    out <- c(out, paste0(
      def$name, ": responses run only from ", .q_fmt_value(observed[1]), " to ",
      .q_fmt_value(observed[2]), ", although the assumed range is ",
      from[1], "-", from[2], ". That is the signature of the 21-point paper sheet or a ",
      "20-point slider; scored as 0-100 it understates workload about five-fold. Pass ",
      "scale = c(1, 21) (or c(1, 20)) if so, or scale = c(0, 100) to confirm the data ",
      "really are on 0-100 and silence this warning."
    ))
  }

  x <- as.matrix(x)
  n_respondents <- sum(rowSums(!is.na(x)) > 0)
  if (isTRUE(def$integer) && nrow(def$items) > 1L && n_respondents >= 5L) {
    if (from[1] == 0 && observed[1] > 0) {
      out <- c(out, paste0(
        def$name, ": no respondent chose ", from[1], " on any item (responses run ",
        obs_txt, " on the assumed range ", from[1], "-", from[2], "). If the survey ",
        "coded this scale ", from[1] + 1, "-", from[2] + 1, ", every response is one point ",
        "too high and the reverse-coded items are wrong; pass scale = c(",
        from[1] + 1, ", ", from[2] + 1, "). If ", from[1], "-", from[2], " is right, pass ",
        "scale = c(", from[1], ", ", from[2], ") to confirm and silence this warning."
      ))
    }
    if (from[1] == 1 && observed[2] < from[2]) {
      out <- c(out, paste0(
        def$name, ": no respondent chose ", from[2], " on any item (responses run ",
        obs_txt, " on the assumed range ", from[1], "-", from[2], "). If the survey ",
        "coded this scale ", from[1] - 1, "-", from[2] - 1, ", every response is one point ",
        "too low and the reverse-coded items are wrong; pass scale = c(",
        from[1] - 1, ", ", from[2] - 1, "). If ", from[1], "-", from[2], " is right, pass ",
        "scale = c(", from[1], ", ", from[2], ") to confirm and silence this warning."
      ))
    }
  }
  out
}


# Internal: a response value for a message -- whole numbers without decimals.
.q_fmt_value <- function(x) {
  ifelse(abs(x - round(x)) < 1e-9, format(round(x)), .fmt_num(x))
}


# Internal: raw item columns -> the numeric matrix the aggregators consume.
# Rescales onto the instrument's own response range, reverses the items the
# scoring key marks, then applies the instrument's recoding (centring for
# semantic differentials, zero-basing for the SUS).
.q_prepare <- function(data, def, cols, scale = NULL, reverse_items = NULL,
                       unreverse_items = NULL) {
  x <- as.matrix(as.data.frame(
    Map(.q_as_numeric, data[cols], cols),
    stringsAsFactors = FALSE
  ))
  colnames(x) <- cols

  observed <- suppressWarnings(range(x, na.rm = TRUE))
  if (any(!is.finite(observed))) {
    stop("None of the item columns of ", def$name, " hold usable numbers.", call. = FALSE)
  }

  from <- if (is.null(scale)) def$scale else .q_check_scale(scale)

  if (observed[1] < from[1] || observed[2] > from[2]) {
    stop(
      "Responses run from ", .fmt_num(observed[1]), " to ", .fmt_num(observed[2]),
      ", outside the assumed response range ", from[1], "-", from[2],
      ". Pass `scale = c(min, max)` to declare the range your survey actually used.",
      call. = FALSE
    )
  }

  for (w in .q_coding_warnings(def, x, from, scale_supplied = !is.null(scale))) {
    warning(w, call. = FALSE)
  }

  # A Likert or semantic-differential response is a whole scale point. A
  # fractional value there is an averaged, imputed or mis-exported column, and
  # scoring it as a response would hide that.
  if (isTRUE(def$integer) && all(from == round(from))) {
    fractional <- !is.na(x) & abs(x - round(x)) > 1e-8
    if (any(fractional)) {
      bad_cols <- cols[colSums(fractional) > 0]
      warning(
        def$name, " is answered in whole scale points, but ",
        paste0("'", utils::head(bad_cols, 4), "'", collapse = ", "),
        if (length(bad_cols) > 4) ", ..." else "", " hold",
        if (length(bad_cols) == 1) "s" else "", " fractional values (e.g. ",
        .fmt_num(x[fractional][1]), "). Check that these are raw responses rather than ",
        "averaged or imputed ones before scoring them.",
        call. = FALSE
      )
    }
  }

  x <- .q_rescale(x, from, def$scale)

  rev_flag <- .q_reverse_flags(def, reverse_items, unreverse_items)
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
  attr(x, "observed") <- observed
  attr(x, "assumed") <- from
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
# When items are missing but the row still clears the threshold, they are
# completed in one of two ways:
#   fill = NULL    proration: the mean of the items present, with sums scaled
#                  up proportionally -- equivalent to imputing the respondent's
#                  own mean, and keeps a sum-scored instrument on its range;
#   fill = <value> each missing item counts as that value, e.g. the scale
#                  centre, which is Brooke's (1996) instruction for the SUS.
.rowagg <- function(x, fun = c("mean", "sum"), min_valid = 1, fill = NULL) {
  fun <- match.arg(fun)
  if (is.null(dim(x))) {
    x <- matrix(x, ncol = 1L)
  }
  k <- ncol(x)
  n_valid <- rowSums(!is.na(x))
  # The tolerance keeps floating-point noise from demanding one item more than
  # asked: (1 - 0.3) * 10 is 7.000000000000001, whose ceiling is 8.
  needed <- max(1L, ceiling(min_valid * k - 1e-9))

  if (is.null(fill)) {
    out <- rowMeans(x, na.rm = TRUE)
  } else {
    x[is.na(x)] <- fill
    out <- rowMeans(x)
  }
  if (identical(fun, "sum")) {
    out <- out * k
  }
  out[n_valid < needed] <- NA_real_
  out
}


# Internal: the default aggregator -- one column per subscale, plus the
# instrument's overall score when it defines one.
.q_aggregate_default <- function(x, def, min_valid = 1, fill = NULL) {
  memberships <- .q_subscales(def$items$subscale)
  subs <- .q_subscale_names(def)

  out <- lapply(subs, function(s) {
    cols <- vapply(memberships, function(m) s %in% m, logical(1))
    .rowagg(x[, cols, drop = FALSE], "mean", min_valid, fill)
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
    out[[total_col]] <- .rowagg(x, def$total, min_valid, fill)
  }
  out
}


# Internal: SUS. Items are already zero-based (0-4) by .q_prepare(), so the
# published multipliers apply directly and every column lands on 0-100. With
# the default `fill` (the centre, 2 on 0-4) a missing item is scored as Brooke
# (1996) tells respondents to mark it.
.q_aggregate_sus <- function(x, def, min_valid = 1, fill = NULL) {
  memberships <- unlist(.q_subscales(def$items$subscale), use.names = FALSE)
  data.frame(
    SUS = .rowagg(x, "sum", min_valid, fill) * 2.5,
    Usability = .rowagg(x[, memberships == "Usability", drop = FALSE], "sum", min_valid, fill) * 3.125,
    Learnability = .rowagg(x[, memberships == "Learnability", drop = FALSE], "sum", min_valid, fill) * 12.5
  )
}


# Internal: SSQ. The three subscales overlap, and the total is computed from the
# UNWEIGHTED subscale sums before the weights are applied -- not from the
# weighted ones, and not from all sixteen items.
.q_aggregate_ssq <- function(x, def, min_valid = 1, fill = NULL) {
  memberships <- .q_subscales(def$items$subscale)
  raw <- function(s) {
    cols <- vapply(memberships, function(m) s %in% m, logical(1))
    .rowagg(x[, cols, drop = FALSE], "sum", min_valid, fill)
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
.q_announce <- function(def, cols, rev_flag, verbose = TRUE, observed = NULL,
                        assumed = NULL, matched_by = NULL) {
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
    "Scoring ", def$name, " from ", length(cols),
    if (length(cols) == 1) " column (" else " columns (",
    if (length(cols) == 1) cols else paste0(cols[1], " ... ", cols[length(cols)]),
    if (!is.null(matched_by)) paste0(", matched by ", matched_by) else "", "); ",
    # The observed range is the cheapest check that the coding is the assumed
    # one: "responses 1 to 21 on the assumed range 0 to 100" reads as wrong at
    # once. "to", not "-", so a range like -2 to 2 stays legible.
    if (!is.null(observed) && !is.null(assumed)) {
      paste0(
        "responses observed ", .q_fmt_value(observed[1]), " to ", .q_fmt_value(observed[2]),
        " on the assumed range ", assumed[1], " to ", assumed[2], "; "
      )
    } else {
      ""
    },
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
#'   \code{"sus_"}. Must select exactly as many columns as the instrument has
#'   items. The columns are then matched to items \emph{by their names}, never
#'   by sort order: either what follows the prefix is the item's code, label or
#'   (for a single-item subscale) subscale name, compared without case or
#'   punctuation (\code{tlx_mental}, \code{tlx_Mental_Demand}, \code{tia_rc1},
#'   \code{ipq_SP2}); or it carries one item number per column, and those
#'   numbers are exactly \code{1..n} (\code{sus_2}, \code{SUS[2]},
#'   \code{Q5_2}; in \code{SUS_2_1} the number that varies across the columns
#'   is the item). Anything else -- numbering from 0, numbers that do not run
#'   \code{1..n}, names that only partly match -- is an error asking for a
#'   named \code{items} mapping, rather than a guess.
#' @param scale Optional two-element vector giving the response range your
#'   survey used, e.g. \code{c(1, 21)} for the 21-point NASA-TLX sheet or
#'   \code{c(0, 4)} for a zero-based SUS. Responses are rescaled onto the
#'   instrument's own range before scoring. Defaults to the instrument's range;
#'   responses outside it are an error rather than a silent rescale. Without
#'   \code{scale}, a coding that fits the range but looks shifted against it
#'   draws a warning (see Details); passing \code{scale} explicitly confirms
#'   the coding and silences it.
#' @param reverse_items Optional items to reverse-code in addition to the
#'   scoring key's own, given as item numbers or item codes -- for a survey that
#'   printed a pair the other way round. For backward compatibility it
#'   \emph{toggles}: naming an item the key already reverses un-reverses it,
#'   and because passing an instrument's own reverse set (e.g.
#'   \code{c(2, 4, 6, 8, 10)} for the SUS) is a common mistake that would do
#'   exactly that, it raises a warning. Use \code{unreverse_items} to undo a
#'   key reversal on purpose.
#' @param min_valid Minimum proportion of a subscale's items that must be
#'   answered for a score to be produced. The default \code{1} scores only
#'   complete subscales and returns \code{NA} otherwise -- no silent imputation.
#'   Relax it (e.g. \code{0.8}) to score partially complete responses; how the
#'   missing items are then completed is set by \code{impute}.
#' @param append Logical. If \code{TRUE}, return \code{data} with the score
#'   columns added; if \code{FALSE} (default), return only the scores.
#' @param prefix_out Optional string prefixed to every score column, useful when
#'   the same instrument is scored more than once per row (pre/post, or one
#'   block per condition).
#' @param verbose Logical. If \code{TRUE} (default), emit the one-time mapping
#'   message described above.
#' @param unreverse_items Optional items the scoring key reverses that should
#'   \emph{not} be reversed, because the export already stored them
#'   reverse-coded. Naming an item the key does not reverse is an error.
#' @param impute How the missing items of a row that clears \code{min_valid}
#'   are completed. \code{"default"} applies the instrument's published rule:
#'   for the SUS, each missing item counts as the scale's centre point, as
#'   Brooke (1996) instructs respondents who cannot answer an item; for every
#'   other instrument, a subscale is the mean of the items present (a summed
#'   score is scaled up proportionally, so it stays on its published range).
#'   \code{"prorate"} uses the mean of the items present everywhere, and
#'   \code{"midpoint"} the scale centre everywhere. Irrelevant with the default
#'   \code{min_valid = 1}.
#'
#' @details
#' Item columns must hold numbers. Factors are read by their labels when the
#' labels are numbers, and by level order only when the factor is ordered. Text
#' that is not a number (\code{"Strongly agree"}, \code{"5 - Strongly agree"},
#' a decimal comma) is an error naming the values, because converting it would
#' silently turn responses into missing values; blank cells are missing. A
#' fractional response on an instrument answered in whole scale points draws a
#' warning.
#'
#' The scoring message reports the observed response range next to the assumed
#' one. Without an explicit \code{scale}, three codings that fit the assumed
#' range but look shifted draw a warning: NASA-TLX responses that never exceed
#' 21 on the 0--100 scale (the 21-point sheet); and, for multi-item whole-point
#' instruments with at least five respondents, no response at 0 on a zero-based
#' scale (a 1-based export, e.g. IPQ 1--7) or no response at the top of a
#' one-based scale (a 0-based export, e.g. SUS 0--4).
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
                                prefix_out = NULL, verbose = TRUE,
                                unreverse_items = NULL,
                                impute = c("default", "prorate", "midpoint")) {
  not_empty(data)
  if (!is.data.frame(data)) {
    stop("`data` must be a data frame.", call. = FALSE)
  }
  if (!is.numeric(min_valid) || length(min_valid) != 1 || min_valid <= 0 || min_valid > 1) {
    stop("`min_valid` must be a single number greater than 0 and at most 1.", call. = FALSE)
  }
  impute <- match.arg(impute)

  def <- .q_get(instrument)
  cols <- .q_resolve_items(data, def, items = items, prefix = prefix)
  matched_by <- attr(cols, "matched_by")
  cols <- as.character(cols)
  x <- .q_prepare(
    data, def, cols,
    scale = scale, reverse_items = reverse_items, unreverse_items = unreverse_items
  )
  rev_flag <- attr(x, "reverse")

  .q_announce(
    def, cols, rev_flag,
    verbose = verbose, observed = attr(x, "observed"),
    assumed = attr(x, "assumed"), matched_by = matched_by
  )

  rule <- if (identical(impute, "default")) def$missing else impute
  if (is.null(rule)) rule <- "prorate"
  fill <- if (identical(rule, "midpoint")) .q_centre(def) else NULL

  aggregate_fun <- if (is.null(def$aggregate)) .q_aggregate_default else def$aggregate
  scores <- aggregate_fun(x, def, min_valid = min_valid, fill = fill)
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
#' @details
#' Problems that [score_questionnaire()] would stop on (a column that is not
#' numeric, responses outside the assumed range) are reported here as warnings
#' instead, together with the warnings scoring would raise (a coding that looks
#' shifted, an item named in \code{reverse_items} that the key already
#' reverses), so the check can explain them rather than abort.
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
                                scale = NULL, reverse_items = NULL,
                                unreverse_items = NULL) {
  not_empty(data)
  def <- .q_get(instrument)
  if (!is.null(scale)) scale <- .q_check_scale(scale)
  cols <- as.character(.q_resolve_items(data, def, items = items, prefix = prefix))

  rev_flag <- .q_reverse_flags(def, reverse_items, unreverse_items)

  # A column this cannot convert is a finding to report, not a reason to abort
  # the very check that would explain it -- but it is reported, not just shown
  # as a column of missing values.
  raw <- Map(function(v, nm) {
    tryCatch(.q_as_numeric(v, nm), error = function(e) {
      warning(conditionMessage(e), call. = FALSE)
      rep(NA_real_, length(v))
    })
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

  assumed <- if (is.null(scale)) def$scale else scale
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
  if (all(is.finite(observed))) {
    message(
      "Observed responses: ", .q_fmt_value(observed[1]), " to ", .q_fmt_value(observed[2])
    )
  }
  if (all(is.finite(observed)) && (observed[1] < assumed[1] || observed[2] > assumed[2])) {
    warning(
      "Responses run from ", observed[1], " to ", observed[2],
      ", outside the assumed range ", assumed[1], "-", assumed[2],
      ". score_questionnaire() will stop until `scale` matches the data.",
      call. = FALSE
    )
  } else if (all(is.finite(observed))) {
    raw_matrix <- do.call(cbind, raw)
    for (w in .q_coding_warnings(def, raw_matrix, assumed, scale_supplied = !is.null(scale))) {
      warning(w, call. = FALSE)
    }
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
#' @param reverse Optional items that are reverse-scored, as item numbers
#'   (\code{c(2, 4)}) or item codes (\code{c("item2", "item4")}).
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
#' @param integer_responses Logical. \code{TRUE} (default) for an instrument
#'   answered in whole scale points (Likert items, semantic differentials):
#'   fractional responses then draw a warning, and a coding that looks shifted
#'   against \code{scale} is checked for. Set \code{FALSE} for a visual-analogue
#'   scale or slider.
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
                                 higher = NA_character_, notes = character(),
                                 integer_responses = TRUE) {
  not_empty(key)
  not_empty(name)
  not_empty(subscale)
  recode <- match.arg(recode)

  n <- length(subscale)
  if (is.null(code)) code <- paste0("item", seq_len(n))
  if (is.null(label)) label <- code
  scale <- .q_check_scale(scale)
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
  # Unique ignoring case: items are looked up case-insensitively (reverse_items
  # = "A1"), and "a1"/"A1" would silently resolve to whichever came first.
  if (anyDuplicated(tolower(code)) > 0) {
    stop(
      "`code` must be unique (ignoring case); duplicated: ",
      paste0("'", unique(code[duplicated(tolower(code))]), "'", collapse = ", "), ".",
      call. = FALSE
    )
  }
  if (any(!nzchar(trimws(subscale)))) {
    stop("Every item needs a non-empty `subscale`.", call. = FALSE)
  }
  reverse <- .q_def_reverse(reverse, code)

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
    recode = recode, total = total, higher = higher, notes = notes,
    integer = isTRUE(integer_responses)
  )
  def$total_name <- total_name

  assign(key, def, envir = .q_user)
  # A redefinition must be able to announce its new mapping.
  if (!is.null(.q_announced[[key]])) {
    rm(list = key, envir = .q_announced)
  }
  invisible(def)
}


# Internal: `reverse` of define_questionnaire() -> item numbers. Codes are
# accepted because they are what the rest of the API uses to name items; any
# other value is refused with the valid choices, rather than by an assertion
# that names neither the argument nor the problem.
.q_def_reverse <- function(reverse, code) {
  n <- length(code)
  if (length(reverse) == 0) {
    return(integer(0))
  }
  if (is.character(reverse)) {
    idx <- match(tolower(reverse), tolower(code))
    if (anyNA(idx)) {
      stop(
        "`reverse` names ", paste0("'", reverse[is.na(idx)], "'", collapse = ", "),
        ", which ", if (sum(is.na(idx)) == 1) "is not an item code" else "are not item codes",
        ". Give item numbers (1-", n, ") or codes: ", paste(code, collapse = ", "), ".",
        call. = FALSE
      )
    }
    return(sort(unique(idx)))
  }
  if (!is.numeric(reverse) || anyNA(reverse) || any(reverse != round(reverse)) ||
    any(reverse < 1 | reverse > n)) {
    stop(
      "`reverse` must give item numbers between 1 and ", n, " (or item codes); got ",
      paste(reverse, collapse = ", "), ".",
      call. = FALSE
    )
  }
  sort(unique(as.integer(reverse)))
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
#' Cronbach's alpha per subscale -- and for the whole scale, where the
#' instrument defines an overall score (the SUS, the SSQ Total, RTLX, the UEQ-S
#' Overall) -- computed on the same recoded item matrix that
#' [score_questionnaire()] aggregates. Reverse-coded items are therefore already
#' flipped, and a negative alpha means a genuine problem rather than a forgotten
#' reversal.
#'
#' McDonald's omega (total) is added when \pkg{psych} is installed. It is
#' computed from an unrotated one-factor solution
#' (\code{psych::fa(nfactors = 1, rotate = "none")}) as
#' \eqn{1 - \sum u^2 / \sum R}{1 - sum(u2) / sum(R)}, which is the
#' \code{omega.tot} that \code{psych::omega(nfactors = 1)} reports, without that
#' function's dependence on \pkg{GPArotation} and without its automatic
#' flipping of negatively loading items -- which would hide exactly the
#' reverse-coding error this function is meant to expose. Omega needs at least
#' three items; for two-item scales it is not identified.
#'
#' For two-item scales (the SUS Learnability scale, three TiA subscales) the
#' Spearman-Brown coefficient \eqn{2r / (1 + r)} is reported as well, which
#' Eisinga, te Grotenhuis & Pelzer (2013) recommend over alpha: alpha
#' underestimates the reliability of a two-item scale whenever the two item
#' variances differ.
#'
#' @inheritParams score_questionnaire
#'
#' @return A data frame with one row per subscale, plus a final row named after
#'   the overall score where the instrument defines one: the number of items,
#'   the number of complete cases it was computed on, \code{alpha},
#'   \code{omega} (omega total), \code{spearman_brown} (two-item scales only),
#'   the mean inter-item correlation, and a \code{note} saying why a
#'   coefficient is missing (a single item, two items, too few complete
#'   responses, \pkg{psych} not installed, or the reason the factor solution
#'   failed). Subscales of a single item yield \code{NA} -- internal
#'   consistency is not defined for them.
#' @references
#' Eisinga, R., te Grotenhuis, M., & Pelzer, B. (2013). The reliability of a
#' two-item scale: Pearson, Cronbach, or Spearman-Brown? \emph{International
#' Journal of Public Health, 58}(4), 637--642. \doi{10.1007/s00038-012-0416-3}
#'
#' McDonald, R. P. (1999). \emph{Test theory: A unified treatment}. Erlbaum.
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
                              verbose = TRUE, unreverse_items = NULL) {
  not_empty(data)
  def <- .q_get(instrument)
  cols <- .q_resolve_items(data, def, items = items, prefix = prefix)
  matched_by <- attr(cols, "matched_by")
  cols <- as.character(cols)
  x <- .q_prepare(
    data, def, cols,
    scale = scale, reverse_items = reverse_items, unreverse_items = unreverse_items
  )

  # Alpha is computed from the same mapping the scores are, so it carries the
  # same caveat: a wrong item order gives a wrong alpha just as quietly.
  .q_announce(
    def, cols, attr(x, "reverse"),
    verbose = verbose, observed = attr(x, "observed"),
    assumed = attr(x, "assumed"), matched_by = matched_by
  )

  memberships <- .q_subscales(def$items$subscale)
  subs <- .q_subscale_names(def)
  blocks <- lapply(subs, function(s) vapply(memberships, function(m) s %in% m, logical(1)))
  names(blocks) <- subs

  # The whole scale, where the instrument defines an overall score -- SUS papers
  # report the ten-item alpha, not the Usability/Learnability split. Skipped
  # when it would only repeat a subscale that already spans every item.
  if (.q_has_overall(def)) {
    all_items <- rep(TRUE, nrow(def$items))
    if (!any(vapply(blocks, function(b) all(b), logical(1)))) {
      blocks[[.q_total_name(def)]] <- all_items
    }
  }

  out <- do.call(rbind, lapply(names(blocks), function(s) {
    .q_reliability_block(x[, blocks[[s]], drop = FALSE], s)
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


# Internal: the reliability coefficients of one block of recoded items.
.q_reliability_block <- function(block, label) {
  block <- block[stats::complete.cases(block), , drop = FALSE]
  k <- ncol(block)
  n <- nrow(block)
  notes <- character()

  alpha <- NA_real_
  mic <- NA_real_
  sb <- NA_real_
  omega <- NA_real_

  if (k < 2) {
    notes <- "single item: internal consistency is not defined"
  } else if (n < 3) {
    notes <- "fewer than 3 complete responses"
  } else {
    item_var <- apply(block, 2, stats::var)
    total_var <- stats::var(rowSums(block))
    if (is.finite(total_var) && total_var > 0) {
      alpha <- (k / (k - 1)) * (1 - sum(item_var) / total_var)
    }
    cm <- suppressWarnings(stats::cor(block))
    mic <- mean(cm[upper.tri(cm)], na.rm = TRUE)

    if (k == 2) {
      # Spearman-Brown step-up of the inter-item correlation. For two items
      # alpha is the Flanagan-Rulon coefficient, which equals Spearman-Brown
      # only when the two item variances are equal and is lower otherwise.
      r <- cm[1, 2]
      if (is.finite(r) && r > -1) sb <- 2 * r / (1 + r)
      notes <- "two items: report spearman_brown (Eisinga et al., 2013); omega is not identified"
    } else {
      om <- .q_omega_total(block)
      omega <- om$value
      notes <- c(notes, om$note)
    }
  }

  data.frame(
    subscale = label, n_items = k, n_complete = n,
    alpha = alpha, omega = omega, spearman_brown = sb, mean_item_cor = mic,
    note = paste(notes, collapse = "; "),
    stringsAsFactors = FALSE
  )
}


# Internal: McDonald's omega total from an unrotated one-factor solution.
#
# psych::omega() routes even a one-factor model through schmid(), which stops
# unless GPArotation is installed -- and the error used to be swallowed, so
# omega came back NA with no reason given. It also flips negatively loading
# items by default, which would report a high omega for exactly the forgotten
# reversal that a negative alpha exposes. psych::fa() with rotate = "none"
# needs neither, and 1 - sum(uniquenesses) / sum(R) is the omega.tot that
# psych::omega(nfactors = 1) reports for the same data.
.q_omega_total <- function(block) {
  if (!requireNamespace("psych", quietly = TRUE)) {
    return(list(value = NA_real_, note = "omega needs the 'psych' package"))
  }
  res <- tryCatch(
    {
      r <- stats::cor(block)
      fit <- suppressWarnings(suppressMessages(
        psych::fa(r, nfactors = 1, n.obs = nrow(block), rotate = "none", fm = "minres", warnings = FALSE)
      ))
      1 - sum(fit$uniquenesses) / sum(r)
    },
    error = function(e) e
  )
  if (inherits(res, "error")) {
    return(list(value = NA_real_, note = paste0("omega not estimated: ", conditionMessage(res))))
  }
  if (!is.finite(res)) {
    return(list(value = NA_real_, note = "omega not estimated: the one-factor solution failed"))
  }
  list(value = as.numeric(res), note = NULL)
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
