#' Ensure input is not empty
#'
#' Stops execution if x is NULL, empty, contains only NAs, or is a data frame
#' without rows.
#'
#' @param x The object to check
#' @param msg The error message to display. The default names the offending
#'   argument, e.g. \code{"`data` must not be empty."}.
#' @return Invisible TRUE if valid.
#' @export
not_empty <- function(x, msg = NULL) {
  if (is.null(msg)) {
    msg <- paste0("`", deparse(substitute(x))[1], "` must not be empty.")
  }
  if (is.null(x) || length(x) == 0) {
    stop(msg, call. = FALSE)
  }

  # A data frame's length() is its number of columns, so a filter that removed
  # every row (e.g. a typo in a condition label) used to pass this check and
  # surface later as an obscure error -- or as a statistic computed on nothing.
  if (is.data.frame(x) && nrow(x) == 0L) {
    stop(msg, call. = FALSE)
  }

  if (is.atomic(x) && all(is.na(x))) {
    stop(msg, call. = FALSE)
  }

  invisible(TRUE)
}

# Internal: assert that the given column names exist in `data`, with an error
# message that names the missing columns and lists the available ones. This
# turns the cryptic downstream dplyr/rlang errors ("object 'X' not found") that
# a simple typo in `x`/`y`/`iv`/`dv` used to trigger into an actionable one.
.check_columns <- function(data, cols, data_arg = "data") {
  cols <- as.character(cols)
  missing_cols <- setdiff(cols, names(data))
  if (length(missing_cols) > 0) {
    stop(
      "Column", if (length(missing_cols) > 1) "s" else "", " ",
      paste0("'", missing_cols, "'", collapse = ", "),
      " not found in `", data_arg, "`. Available columns: ",
      paste0(names(data), collapse = ", "), ".",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

#' Negate `%in%` membership
#'
#' @param x Vector of values to test.
#' @param y Vector of values to match against.
#' @return Logical vector indicating non-membership.
#' @export
not_in <- function(x, y) !(x %in% y)

#' @rdname not_in
#' @export
`%!in%` <- not_in


#' Replace NA values with zero
#'
#' @param x A vector.
#' @return A vector with NAs replaced by zeros.
#' @export
#' @examples
#' na.zero(c(NA, 1, NA, 2))
na.zero <- function(x) {
  x[is.na(x)] <- 0
  return(x)
}


#' Convert Windows paths to R-friendly format
#'
#' @param path Path to convert or the string "clipboard" to read from the clipboard.
#' @param read_fn Optional custom function to read from the clipboard.
#' @param write_fn Optional custom function to write to the clipboard.
#' @return A normalized path string.
#' @export
pathPrep <- function(path = "clipboard", read_fn = NULL, write_fn = NULL) {
  get_clip_reader <- function() {
    if (!is.null(read_fn)) {
      return(read_fn)
    }
    if (requireNamespace("clipr", quietly = TRUE) && clipr::clipr_available()) {
      return(clipr::read_clip)
    }
    if (exists("readClipboard", mode = "function")) {
      return(get("readClipboard", mode = "function"))
    }
    stop("Clipboard is not available. Provide a custom `read_fn` or a direct path.")
  }

  get_clip_writer <- function() {
    if (!is.null(write_fn)) {
      return(write_fn)
    }
    if (requireNamespace("clipr", quietly = TRUE) && clipr::clipr_available()) {
      return(clipr::write_clip)
    }
    if (exists("writeClipboard", mode = "function")) {
      return(get("writeClipboard", mode = "function"))
    }
    return(function(...) invisible(NULL))
  }

  from_clipboard <- identical(path, "clipboard")

  y <- if (from_clipboard) {
    reader <- get_clip_reader()
    reader()
  } else {
    path
  }

  x <- chartr("\\", "/", y)
  # Only write back to the clipboard when the path was read from it; otherwise
  # an explicit `path` argument would silently clobber the user's clipboard.
  if (from_clipboard) {
    writer <- get_clip_writer()
    writer(x)
  }
  return(x)
}

#' Build a median/size label for plot annotations
#'
#' @param x A numeric vector.
#' @return A data frame with the median and label.
#' @export
n_fun <- function(x) {
  x <- x[!is.na(x)]
  return(data.frame(y = median(x), label = paste0("n = ", length(x))))
}


#' Generating the sum and adding a crossbar.
#'
#' @param fun function
#' @param geom geom to be shown
#' @param ... Additional arguments passed to stat_summary
#'
#' @return A \code{ggplot2} layer that can be added to a ggplot object.
#' @export
#'
#' @examples \donttest{
#'   # Simple summary function: use the mean as y, ymin, and ymax
#'   mean_fun <- function(x) {
#'     m <- mean(x, na.rm = TRUE)
#'     data.frame(y = m, ymin = m, ymax = m)
#'   }
#'
#'   ggplot2::ggplot(mtcars, ggplot2::aes(x = factor(cyl), y = mpg)) +
#'     stat_sum_df(mean_fun)
#' }
stat_sum_df <- function(fun, geom = "crossbar", ...) {
  ggplot2::stat_summary(fun.data = fun, colour = "red", geom = geom, width = 0.2, ...)
}

#' This function normalizes the values in a vector to the range \[new_min, new_max\]
#' based on their original range \[old_min, old_max\].
#'
#' @param x_vector A numeric vector that you want to normalize.
#' @param old_min The minimum value in the original scale of the data.
#' @param old_max The maximum value in the original scale of the data.
#' @param new_min The minimum value in the new scale to which you want to normalize the data.
#' @param new_max The maximum value in the new scale to which you want to normalize the data.
#' @return A numeric vector with the normalized values.
#' @export
#' @examples
#' normalize(c(1, 2, 3, 4, 5), 1, 5, 0, 1)
normalize <- function(x_vector, old_min, old_max, new_min, new_max) {
  if (old_max == old_min) {
    stop("`old_min` and `old_max` must differ; cannot rescale a zero-width range.")
  }
  return(new_min + ((x_vector - old_min) / (old_max - old_min)) * (new_max - new_min))
}


# Internal: write report sentences to a (LaTeX) text file so a manuscript can
# \input{} them; parent directories are created as needed. Re-running an
# analysis then updates the paper without any copy-paste. When the option
# colleyRstats.macros is set to FALSE, the colleyRstats stat macros are expanded
# to plain standard-LaTeX math so the file compiles with no custom preamble.
.write_tex <- function(sentences, path) {
  not_empty(path)
  dir <- dirname(path)
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  }
  body <- paste(sentences, collapse = "\n")
  if (!isTRUE(getOption("colleyRstats.macros", TRUE))) {
    body <- expand_latex_macros(body)
  }
  writeLines(body, con = path)
  message("Wrote results to '", path, "'.")
  invisible(path)
}


#' Escape LaTeX special characters in plain text
#'
#' Makes an arbitrary string safe to drop into a LaTeX document by escaping the
#' characters that would otherwise be interpreted as markup
#' (\code{\\ \{ \} $ & # _ % ~ ^ < >}). Use it on variable names, factor-level
#' labels, captions -- anything user-supplied that reaches the \code{.tex}. This
#' is what prevents a dependent variable called \code{tlx_mental} from producing
#' an un-compilable \code{tlx_mental} (a subscript error) in Overleaf.
#'
#' @param x A character vector (or something coercible to one).
#' @return A character vector with LaTeX specials escaped; \code{NA} is
#'   preserved.
#' @export
#' @examples
#' latex_escape("tlx_mental")
#' latex_escape("cost (%) & margin")
latex_escape <- function(x) {
  if (length(x) == 0) {
    return(character(0))
  }
  x <- as.character(x)
  na <- is.na(x)
  bs <- "\001" # sentinel for the original backslashes
  x <- gsub("\\", bs, x, fixed = TRUE)
  x <- gsub("{", "\\{", x, fixed = TRUE)
  x <- gsub("}", "\\}", x, fixed = TRUE)
  x <- gsub("$", "\\$", x, fixed = TRUE)
  x <- gsub("&", "\\&", x, fixed = TRUE)
  x <- gsub("#", "\\#", x, fixed = TRUE)
  x <- gsub("_", "\\_", x, fixed = TRUE)
  x <- gsub("%", "\\%", x, fixed = TRUE)
  x <- gsub("~", "\\textasciitilde{}", x, fixed = TRUE)
  x <- gsub("^", "\\textasciicircum{}", x, fixed = TRUE)
  x <- gsub("<", "\\textless{}", x, fixed = TRUE)
  x <- gsub(">", "\\textgreater{}", x, fixed = TRUE)
  x <- gsub(bs, "\\textbackslash{}", x, fixed = TRUE)
  x[na] <- NA_character_
  x
}

# Internal shorthand.
.latex_escape <- latex_escape

# Internal: TRUE where `x` can safely become a new LaTeX command `\x`. That
# needs more than letters only: the name must not already be a command, or the
# \newcommand an author writes for it fails ("already defined") and the
# \providecommand stubs emit_overleaf() writes do nothing -- leaving `time` to
# typeset as the TeX primitive \time (a compile error), `L` as the letter Ł and
# `small` as a font-size switch. `.latex_reserved_names` (R/sysdata.rda, built by
# data-raw/latex_reserved.R from TeX itself) lists the commands defined by the
# primitives, the LaTeX kernel, the article/IEEEtran/acmart classes and the
# packages a typical manuscript loads, plus the colleyRstats macros. LaTeX also
# refuses to \newcommand any name beginning with "end".
.latex_name_ok <- function(x) {
  x <- as.character(x)
  !is.na(x) & grepl("^[A-Za-z]+$", x) & !grepl("^end", x) &
    !(x %in% .latex_reserved_names)
}

# Internal: render a variable/factor-level name for LaTeX. By default (option
# colleyRstats.name_macros = TRUE) a name that can safely be a new command (see
# .latex_name_ok()) is emitted as "\name" so the author can control its
# typography centrally via \newcommand (see emit_name_macros()); any other name
# -- digits, underscores, spaces, or one that is already a LaTeX command -- is
# emitted as escaped plain text instead, because "\tlx_mental" is itself an
# un-compilable control sequence and "\time" means something else entirely.
# Setting the option to FALSE always emits escaped plain text.
#
# The macro is written as "\name{}": TeX ends a control word at the first
# non-letter and then swallows the spaces after it, so "\cyl on mpg" typesets as
# "cylon mpg". The empty group stops that and is harmless for a macro that takes
# no argument.
.tex_name <- function(x) {
  use_macro <- isTRUE(getOption("colleyRstats.name_macros", TRUE))
  vapply(as.character(x), function(nm) {
    if (isTRUE(use_macro) && .latex_name_ok(nm)) {
      paste0("\\", nm, "{}")
    } else {
      latex_escape(nm)
    }
  }, character(1), USE.NAMES = FALSE)
}

# Internal: backtick-quote column names for use inside a formula string, so
# that "Mental Demand", "tlx-mental" or "Condition ID" survive being pasted into
# `y ~ x`. Syntactic names come back unchanged.
.bt <- function(x) {
  vapply(as.character(x), function(nm) deparse(as.name(nm), backtick = TRUE),
         character(1), USE.NAMES = FALSE)
}


#' Expand the colleyRstats LaTeX macros to plain standard LaTeX
#'
#' The report functions normally emit compact custom macros (\code{\\F},
#' \code{\\p}, \code{\\m}, \code{\\sd}, \code{\\df}, \code{\\chisq},
#' \code{\\padj}, \code{\\padjminor}, \code{\\pminor}, \code{\\rankbiserial},
#' \code{\\effectsize}) that require [latex_preamble()] definitions. This
#' expands them into equivalent plain math (e.g. \code{\\F{2}{57}{4.50}} becomes
#' \code{$F(2, 57) = 4.50$}) so the text compiles in any document with no custom
#' preamble -- the "zero-setup Overleaf" path. It is applied automatically by
#' the \code{sink_to}/\code{emit_overleaf()} writers when
#' \code{options(colleyRstats.macros = FALSE)}.
#'
#' @param x A character vector of report text.
#' @return The text with the macros expanded to standard LaTeX math.
#' @export
#' @examples
#' expand_latex_macros("A significant effect (\\F{2}{57}{4.50}, \\p{0.012}).")
expand_latex_macros <- function(x) {
  x <- as.character(x)
  rp <- function(pat, repl) x <<- gsub(pat, repl, x, perl = TRUE)
  # three-argument F macro first
  rp("\\\\F\\{([^{}]*)\\}\\{([^{}]*)\\}\\{([^{}]*)\\}", "$F(\\1, \\2) = \\3$")
  # adjusted-p variants before the plain ones so the longer name wins
  rp("\\\\padjminor\\{([^{}]*)\\}", "$p_{adj} < \\1$")
  rp("\\\\padj\\{([^{}]*)\\}", "$p_{adj} = \\1$")
  rp("\\\\pminor\\{([^{}]*)\\}", "$p < \\1$")
  rp("\\\\p\\{([^{}]*)\\}", "$p = \\1$")
  rp("\\\\m\\{([^{}]*)\\}", "$M = \\1$")
  rp("\\\\sd\\{([^{}]*)\\}", "$SD = \\1$")
  rp("\\\\df\\{([^{}]*)\\}", "$df = \\1$")
  rp("\\\\mdn\\{([^{}]*)\\}", "$Mdn = \\1$")
  rp("\\\\iqr\\{([^{}]*)\\}", "$IQR = \\1$")
  rp("\\\\rankbiserial\\{([^{}]*)\\}", "$r_{rb} = \\1$")
  rp("\\\\effectsize\\{([^{}]*)\\}", "$r = \\1$")
  rp("\\\\chisq", "$\\\\chi^2$")
  x
}

# Internal: number formatting for reported statistics (fixed decimal places).
.fmt_num <- function(x, digits = 2) {
  sprintf(paste0("%.", digits, "f"), x)
}

# Internal: degrees of freedom for display. Integer dfs stay integers; the
# fractional ones produced by Greenhouse-Geisser corrections or Kenward-Roger /
# Welch approximations are rounded, so a sentence reads "F(1.81, 66.92)"
# instead of "F(1.80875305770353, 66.9238631350305)".
.fmt_df <- function(x, digits = 2) {
  if (is.null(x) || length(x) == 0) {
    return(x)
  }
  num <- suppressWarnings(as.numeric(x))
  ifelse(is.na(num), as.character(x),
    ifelse(num == round(num),
      format(round(num), trim = TRUE, scientific = FALSE),
      format(round(num, digits), trim = TRUE, scientific = FALSE)
    )
  )
}

# Internal: "An" before a word that is read starting with a vowel sound, "A"
# otherwise, so method names flow ("An ANOVA ...", "A Friedman rank sum test
# ..."). Acronyms are read letter-by-letter, hence the extra letter set.
.indefinite_article <- function(word) {
  w <- sub("^[^[:alnum:]]*", "", as.character(word)[1])
  if (is.na(w) || !nzchar(w)) {
    return("A")
  }
  first <- substr(w, 1, 1)
  # Read as an acronym when the opening upper-case run is not followed by a
  # lower-case letter ("ANOVA", "RM-ANOVA", "F test"): such letters are spoken
  # individually, and A, E, F, H, I, L, M, N, O, R, S, X begin with a vowel
  # sound ("an ANOVA", "an F test", "a Games-Howell test").
  if (grepl("^[A-Z]{2,}", w) || grepl("^[A-Z]([^A-Za-z]|$)", w)) {
    if (grepl(first, "AEFHILMNORSX", fixed = TRUE)) {
      return("An")
    }
    return("A")
  }
  # A vowel letter does not settle it: some vowel-initial words are read
  # starting with a consonant. "One-way analysis of means" -- the name
  # statsExpressions gives a Welch ANOVA -- is spoken "wun" and takes "A", as do
  # the "yoo" spellings ("a unique", "a European"). The "un-" prefix is the trap
  # in that second class, since "an unpaired Wilcoxon test" and "an unadjusted
  # p-value" really are vowel-sounded; hence the word boundary after "one" (not
  # "an onerous") and the exclusion of "unin-", "unim-" and "unid-".
  if (grepl("^(onc?e\\b|eu|uni(?![nmd])|us[ae]|usu|util|ubiq)", w, ignore.case = TRUE, perl = TRUE)) {
    return("A")
  }
  if (grepl("^[aeiouAEIOU]", w)) "An" else "A"
}


# Internal: the first element of `x` as a length-one string, or NULL when it
# carries nothing usable (absent column, NA, empty string). Factors go through
# their labels rather than their integer codes.
.scalar_chr <- function(x) {
  if (is.null(x) || length(x) == 0) {
    return(NULL)
  }
  x <- trimws(as.character(x)[1])
  if (is.na(x) || !nzchar(x)) NULL else x
}


# Internal: TRUE when a `p.adjust.method` label says no correction was applied.
# 'ggstatsplot' spells it "None", `stats::p.adjust()` "none". An absent label
# (NULL) is not an answer either way and yields FALSE, so a caller that has no
# such column keeps whatever it did before.
.adjustment_is_none <- function(adjust) {
  !is.null(adjust) && tolower(adjust) %in% c("none", "no")
}


# Internal: name the post-hoc test behind a 'ggstatsplot' pairwise table.
# `pairwise_comparisons_data` carries the test in `test` ("Games-Howell",
# "Dunn", "Durbin-Conover", "Yuen's trimmed means", "Student's t") and the
# multiplicity correction in `p.adjust.method` ("Holm", "Bonferroni", "FDR",
# "None"), so a sentence can say which test produced the p-value it reports
# instead of the anonymous "A post-hoc test ...". Yields e.g.
# "A Games-Howell post-hoc test (Holm-adjusted)", and falls back to
# "A post-hoc test" when the columns are absent -- an older 'ggstatsplot', or a
# hand-built table.
.posthoc_test_phrase <- function(test = NULL, adjust = NULL) {
  test <- .scalar_chr(test)
  adjust <- .scalar_chr(adjust)

  phrase <- if (is.null(test)) {
    "A post-hoc test"
  } else {
    # the article is chosen from the raw name: latex_escape() may prefix a
    # backslash, which .indefinite_article() would then have to strip again
    paste0(.indefinite_article(test), " ", latex_escape(test), " post-hoc test")
  }

  if (!is.null(adjust) && !.adjustment_is_none(adjust)) {
    phrase <- paste0(phrase, " (", latex_escape(adjust), "-adjusted)")
  }
  phrase
}


# Internal: the F statistics of an ANOVA-style table, whichever way the column
# is named. `stats::anova()` on an ARTool model names it "F value" for a
# between-only (lm) fit, but plain "F" for a mixed (lmer) fit -- reading only
# `F value` silently yields NULL for every mixed model, which drops the F
# statistic and the effect size from the reported sentence.
.f_values <- function(model) {
  for (nm in c("F value", "F", "F.value", "statistic")) {
    if (nm %in% colnames(model)) {
      return(model[[nm]])
    }
  }
  NULL
}

# Internal: like .fmt_num, but for statistics bounded within [-1, 1] by
# definition (p-values, r, eta^2). APA style omits their leading zero; opt in
# via options(colleyRstats.leading_zero = FALSE).
.fmt_bounded <- function(x, digits = 2) {
  out <- .fmt_num(x, digits)
  if (!isTRUE(getOption("colleyRstats.leading_zero", TRUE))) {
    out <- sub("^(-?)0\\.", "\\1.", out)
  }
  out
}

# Internal: the LaTeX rendering of a statsExpressions effect size.
#
# `ggstatsplot::extract_stats(p)$subtitle_data` carries the effect size in
# `estimate` and NAMES it in `effectsize` -- and that name changes with the
# test: a paired t-test yields Hedges' g, a Wilcoxon r (rank biserial), a
# Friedman test Kendall's W, a Kruskal-Wallis Epsilon2 (rank), an ANOVA Omega2.
# Calling all of them "r", as the reporters did before 0.2.0, puts a wrong
# statistic name in the manuscript, and for the standardised mean differences an
# impossible one: g is unbounded, so a reported "r=-1.38" claims a correlation
# outside [-1, 1].
#
# Two things follow from the name: the symbol, and whether the value is bounded
# within [-1, 1]. Only the bounded ones may lose their leading zero under APA
# style, which is what .fmt_bounded() does; the rest go through .fmt_num().
#
# Unrecognised names are printed verbatim rather than guessed at. The robust
# tests in particular return long descriptive names ("Explanatory measure of
# effect size") that already read as English.
.effect_size_tex <- function(name, value, digits = 2) {
  num <- suppressWarnings(as.numeric(value)[1])
  if (length(num) == 0L || is.na(num)) {
    return("")
  }
  nm <- if (is.null(name) || length(name) == 0L || is.na(name[1])) {
    ""
  } else {
    trimws(as.character(name)[1])
  }
  key <- tolower(nm)

  # The rank-biserial correlation has a house macro of its own, and
  # reportArtCon() already emits it, so the two reporters stay consistent.
  if (grepl("rank biserial", key, fixed = TRUE)) {
    return(paste0("\\rankbiserial{", .fmt_bounded(num, digits), "}"))
  }

  # Most specific pattern first: "eta2 (partial)" must not be caught by the
  # plain "eta2" entry, nor "log(odds ratio)" by "odds ratio".
  known <- list(
    c("eta2 (partial)",   "$\\eta_{p}^{2}$",           "bounded"),
    c("omega2 (partial)", "$\\omega_{p}^{2}$",         "bounded"),
    c("epsilon2 (rank)",  "$\\epsilon_{ordinal}^{2}$", "bounded"),
    c("eta2",             "$\\eta^{2}$",               "bounded"),
    c("omega2",           "$\\omega^{2}$",             "bounded"),
    c("epsilon2",         "$\\epsilon^{2}$",           "bounded"),
    c("kendall's w",      "$W_{Kendall}$",             "bounded"),
    c("cohen's w",        "$w_{Cohen}$",               "bounded"),
    c("cramer",           "$V_{Cramer}$",              "bounded"),
    c("pearson's c",      "$C$",                       "bounded"),
    c("hedges",           "$g_{Hedges}$",              "unbounded"),
    c("cohen's d",        "$d_{Cohen}$",               "unbounded"),
    c("log(odds ratio)",  "$\\log(OR)$",               "unbounded"),
    c("odds ratio",       "$OR$",                      "unbounded")
  )
  for (row in known) {
    if (grepl(row[[1]], key, fixed = TRUE)) {
      val <- if (identical(row[[3]], "bounded")) {
        .fmt_bounded(num, digits)
      } else {
        .fmt_num(num, digits)
      }
      return(paste0(row[[2]], " = ", val))
    }
  }

  label <- if (nzchar(nm)) latex_escape(nm) else "effect size"
  paste0(label, " = ", .fmt_num(num, digits))
}


# Internal: a p-value as text, never rounded across a significance boundary.
# Plain rounding prints p = 0.0496 as "0.050" -- inside a sentence that calls the
# result significant, and next to a "*" from .p_to_asterisk(). Where rounding to
# `digits` would land on or above a conventional boundary (.10, .05, .01) that
# the unrounded p is below, more digits are shown until the printed value is on
# the same side as the real one ("0.0496", "0.04996"). Past 8 digits the value
# is truncated rather than rounded (0.0499999999 -> "0.04999999"), so even a p
# a hair below a boundary never prints on it. Leading zero follows
# options(colleyRstats.leading_zero), as for every bounded statistic.
.P_BOUNDARIES <- c(0.1, 0.05, 0.01)

.fmt_p_number <- function(p, digits = 3) {
  crosses <- function(pv, shown) any(pv < .P_BOUNDARIES & shown >= .P_BOUNDARIES)
  vapply(p, function(pv) {
    if (is.na(pv)) {
      return(NA_character_)
    }
    d <- digits
    while (d < 8 && crosses(pv, round(pv, d))) {
      d <- d + 1
    }
    if (crosses(pv, round(pv, d))) {
      pv <- floor(pv * 10^d) / 10^d
    }
    .fmt_bounded(pv, d)
  }, character(1), USE.NAMES = FALSE)
}

# Internal: LaTeX p-value macro, e.g. "\\p{0.033}", or "\\pminor{0.001}" below
# the reporting threshold. macro/minor_macro switch to the adjusted-p variants
# ("padj"/"padjminor") used by the post-hoc reporters.
.fmt_p_macro <- function(p, macro = "p", minor_macro = "pminor", digits = 3, threshold = 0.001) {
  if (is.na(p)) {
    return(paste0("\\", macro, "{NA}"))
  }
  if (p < threshold) {
    paste0("\\", minor_macro, "{", .fmt_bounded(threshold, digits), "}")
  } else {
    paste0("\\", macro, "{", .fmt_p_number(p, digits), "}")
  }
}


# Internal: significance stars for (adjusted) p-values following the APA
# convention *** p < .001, ** p < .01, * p < .05. Boundary values fall into
# the next-weaker category (e.g. p = 0.01 yields "*"); non-significant or NA
# p-values yield NA so callers can filter them out.
.p_to_asterisk <- function(p) {
  dplyr::case_when(
    p < 0.001 ~ "***",
    p < 0.01 ~ "**",
    p < 0.05 ~ "*",
    .default = NA_character_
  )
}


#' Check normality for groups
#'
#' Decides between a parametric and a non-parametric analysis from Shapiro-Wilk
#' tests, testing the quantity the parametric test actually assumes to be
#' normal.
#'
#' * **Between subjects** (\code{subject = NULL}): one test per group, with the
#'   p-values corrected for the number of groups (\code{p_adjust}, Holm by
#'   default). Without the correction, six perfectly normal groups would send
#'   about one analysis in four to the non-parametric branch by chance alone.
#' * **Within subjects** (\code{subject} given): a paired t-test assumes the
#'   *differences* are normal, and a repeated-measures ANOVA the *residuals*
#'   after removing participant and condition effects -- not the raw scores per
#'   condition, which also carry the between-participant spread. With two
#'   conditions the per-participant differences are tested; with more, the
#'   residuals of the additive model \code{y ~ x + subject}. Participants
#'   lacking any condition are left out (they cannot enter a paired analysis),
#'   and more than one row per participant and condition is an error.
#'
#' A group that cannot be tested -- fewer than three values, or no variance at
#' all, as in a rating scale where everyone ticked the top box -- counts as
#' **not** normal, so the decision errs towards the non-parametric test rather
#' than letting an untestable group pass silently.
#'
#' Testing assumptions with significance tests has well-known limits (low power
#' in small samples, trivial deviations flagged in large ones); report the
#' check, and treat it as one input to the choice rather than the whole of it.
#'
#' @param data the data frame
#' @param x the grouping (condition) column, as a string
#' @param y the outcome column, as a string
#' @param subject the participant-ID column for a within-subjects design, as a
#'   string; \code{NULL} (default) for a between-subjects design.
#' @param p_adjust multiplicity correction across groups, passed to
#'   [stats::p.adjust()]. Default \code{"holm"}; only used between subjects.
#'
#' @return \code{TRUE} if no test rejects normality and every group could be
#'   tested, \code{FALSE} otherwise. Attributes:
#'   \describe{
#'     \item{\code{tests}}{data frame with columns \code{group} (the condition,
#'       or \code{"differences"} / \code{"residuals"} within subjects),
#'       \code{n}, \code{W}, \code{p_value}, \code{p_adjusted} and
#'       \code{testable}, e.g. for [assumption_methods_text()].}
#'     \item{\code{method}}{\code{"groupwise"}, \code{"differences"} or
#'       \code{"residuals"}.}
#'     \item{\code{p_adjust}}{the correction applied (\code{"none"} for a
#'       single test).}
#'     \item{\code{untestable}}{the groups that could not be tested.}
#'     \item{\code{dropped_subjects}}{within subjects: the participants left
#'       out for lacking a condition.}
#'   }
#'   For a group with more than 5000 values, Shapiro-Wilk is computed on a
#'   random sample of 5000 (a warning is emitted), so the result is only
#'   reproducible with a seed set beforehand.
#' @export
#' @examples
#' set.seed(1)
#' d <- data.frame(id = rep(1:20, 2), cond = rep(c("A", "B"), each = 20))
#' d$score <- rnorm(40, mean = ifelse(d$cond == "A", 5, 6))
#' check_normality_by_group(d, "cond", "score")                  # between
#' check_normality_by_group(d, "cond", "score", subject = "id")  # within
check_normality_by_group <- function(data, x, y, subject = NULL, p_adjust = "holm") {
  # Input validation
  if (missing(data) || missing(x) || missing(y)) stop("Missing arguments")
  .check_columns(data, c(x, y, subject))

  # Ensure numeric. A factor goes through its labels: as.numeric() on a factor
  # returns the level *codes*, so a rating stored as factor(c(1, 2, 5)) would be
  # tested as 1, 2, 3 -- a different distribution.
  if (!is.numeric(data[[y]])) {
    val <- data[[y]]
    if (is.factor(val)) val <- as.character(val)
    val <- suppressWarnings(as.numeric(val))
    if (all(is.na(val))) {
      return(FALSE)
    } # Non-numeric data
    data[[y]] <- val
  }

  if (is.null(subject)) {
    .normality_groupwise(data, x, y, p_adjust)
  } else {
    .normality_within(data, x, y, subject)
  }
}

# Internal: Shapiro-Wilk on one vector, or NA when it cannot be run (n < 3 or
# no variance). Samples 5000 values beyond Shapiro-Wilk's limit.
.shapiro_row <- function(group, values) {
  values <- values[!is.na(values)]
  n <- length(values)
  # shapiro.test() itself refuses a range below 1e-10 ("all values identical")
  testable <- n >= 3 && diff(range(values)) >= 1e-10
  W <- p <- NA_real_
  if (testable) {
    if (n > 5000) values <- sample(values, size = 5000)
    tst <- stats::shapiro.test(values)
    W <- unname(tst$statistic)
    p <- tst$p.value
  }
  data.frame(group = as.character(group), n = n, W = W, p_value = p,
             testable = testable, stringsAsFactors = FALSE)
}

.normality_result <- function(tests, method, p_adjust, extra = list()) {
  if (any(tests$n > 5000)) {
    warning("Groups with n > 5000 were tested using a random sample of 5000 observations.", call. = FALSE)
  }
  tests$p_adjusted <- NA_real_
  ok <- tests$testable
  tests$p_adjusted[ok] <- stats::p.adjust(tests$p_value[ok], method = p_adjust)

  normal <- nrow(tests) > 0 && all(tests$testable) &&
    !any(tests$p_adjusted < 0.05, na.rm = TRUE)

  rownames(tests) <- NULL
  attr(normal, "tests") <- tests[, c("group", "n", "W", "p_value", "p_adjusted", "testable")]
  attr(normal, "method") <- method
  attr(normal, "p_adjust") <- if (sum(ok) > 1) p_adjust else "none"
  attr(normal, "untestable") <- tests$group[!tests$testable]
  for (nm in names(extra)) attr(normal, nm) <- extra[[nm]]
  normal
}

.normality_groupwise <- function(data, x, y, p_adjust) {
  keep <- !is.na(data[[x]])
  g <- data[[x]][keep]
  g <- if (is.factor(g)) droplevels(g) else factor(g)
  groups <- split(data[[y]][keep], g)
  tests <- do.call(rbind, Map(.shapiro_row, names(groups), groups))
  if (is.null(tests)) {
    tests <- .shapiro_row(character(0), numeric(0))[0, ]
  }
  .normality_result(tests, "groupwise", p_adjust)
}

# Internal: a short, readable list of IDs for a message ("3, 7 and 2 more").
.format_ids <- function(ids, max_shown = 10L) {
  ids <- as.character(ids)
  if (length(ids) <= max_shown) {
    return(paste(ids, collapse = ", "))
  }
  paste0(paste(ids[seq_len(max_shown)], collapse = ", "), " and ", length(ids) - max_shown, " more")
}

# Internal: the rows a repeated-measures analysis can use. This is the one
# place that decides who is analysed, so the normality check, the figure, the
# test, the descriptives and the assumption advice cannot disagree about it --
# as they did while each kept its own copy of the rule.
#
# * Rows without a participant ID, a condition or an outcome are dropped.
# * More than one row per participant and condition is an error: a
#   repeated-measures analysis needs one value per cell, and which trial to
#   keep, or how to average them, is the analyst's call.
# * Participants not observed in every condition are dropped: they cannot
#   enter a paired analysis, and a participant seen in a single condition would
#   otherwise get a residual of exactly 0 from their own subject term.
#
# `within` names the within-subject factor column(s); with several, a
# condition is a combination of their levels. With none (`character(0)`), the
# only rule left is one row per participant -- the between-subjects check.
# Participants are identified by their observed IDs, so the unused levels of a
# factor ID are never reported as dropped, while a participant whose every row
# lacked a value is. Column types are left as they are; callers convert.
#
# With `context` (a sentence opening such as "Within-subjects analysis of
# 'tlx': "), each exclusion is announced in a message; without it the helper is
# silent and the caller reports what it needs from the return value: a list of
# `data`, `dropped_subjects` and `n_subjects`.
.complete_within <- function(data, subject, within, y, context = NULL) {
  say <- function(...) if (!is.null(context)) message(context, ...)
  plural <- function(n, word) paste0(n, " ", word, if (n == 1L) "" else "s")
  what <- if (length(within) == 1L) {
    paste0("'", within, "'")
  } else {
    paste0("'", paste(within, collapse = "' x '"), "'")
  }

  sid_all <- as.character(data[[subject]])
  ids <- unique(sid_all[!is.na(sid_all)])
  if (any(is.na(sid_all))) {
    say("dropped ", plural(sum(is.na(sid_all)), "row"),
        " without a participant ID in '", subject, "'.")
  }

  key_all <- if (length(within) == 0L) {
    rep("", nrow(data))
  } else {
    ifelse(stats::complete.cases(data[within]),
           do.call(paste, c(lapply(data[within], as.character), sep = ":")),
           NA_character_)
  }
  observed <- unique(key_all[!is.na(key_all)])
  keep <- !is.na(sid_all) & !is.na(key_all) & !is.na(data[[y]])
  d <- data[keep, , drop = FALSE]
  key <- key_all[keep]
  sid <- sid_all[keep]

  lost <- setdiff(observed, key)
  if (length(lost) > 0L) {
    say("condition", if (length(lost) == 1L) " " else "s ",
        paste0("'", lost, "'", collapse = ", "), " of ", what, " had no usable observation and ",
        if (length(lost) == 1L) "is" else "are", " not analysed.")
  }

  cells <- table(sid, key)
  if (any(cells > 1L)) {
    dup <- which(cells > 1L, arr.ind = TRUE)[1L, ]
    stop(
      "More than one row per participant", if (length(within) > 0L) " and condition", " in '", y,
      "' (e.g. participant ", rownames(cells)[dup[1L]],
      if (length(within) > 0L) paste0(" in condition '", colnames(cells)[dup[2L]], "' of ", what),
      "). ", if (length(within) > 0L) {
        "A within-subjects analysis needs exactly one value per participant and condition: "
      } else {
        "Each participant must contribute one row: "
      },
      "aggregate repeated trials first, e.g. the mean per participant",
      if (length(within) > 0L) " and condition", ".",
      call. = FALSE
    )
  }

  complete <- rownames(cells)[rowSums(cells > 0L) == ncol(cells)]
  dropped <- setdiff(ids, complete)
  if (length(dropped) > 0L) {
    say("dropped ", length(dropped), " of ", plural(length(ids), "participant"), " ('", subject,
        "') without a value in every condition of ", what,
        " -- a paired analysis can only use participants measured in all conditions: ",
        .format_ids(dropped), ".")
  }
  list(
    data = d[sid %in% complete, , drop = FALSE],
    dropped_subjects = dropped,
    n_subjects = length(complete)
  )
}

# Internal: per-participant differences between the two levels of a two-level
# within-subject factor (second level minus first) -- what a paired test, and a
# repeated-measures ANOVA with one such factor, assumes to be normal. Testing
# the model residuals instead goes wrong here: each participant's two residuals
# are mirror images (+e, -e), so Shapiro-Wilk sees a doubled, symmetrised sample
# that hides skew. With between-subject factors the differences are centred
# within their groups, removing what the group-by-condition interaction
# explains, as the model would. The participants are those .complete_within()
# keeps; the result is named by participant.
.paired_differences <- function(data, y, within, subject, between = character(0)) {
  if (length(between) > 0L) {
    data <- data[stats::complete.cases(data[between]), , drop = FALSE]
  }
  d <- .complete_within(data, subject, within, y)$data
  cond <- as.character(d[[within]])
  lv <- levels(droplevels(as.factor(d[[within]])))
  if (length(lv) != 2L) {
    stop("Internal error: .paired_differences() needs a factor with two observed levels.",
         call. = FALSE)
  }
  a <- d[cond == lv[1L], , drop = FALSE]
  b <- d[cond == lv[2L], , drop = FALSE]
  b <- b[match(as.character(a[[subject]]), as.character(b[[subject]])), , drop = FALSE]
  diffs <- b[[y]] - a[[y]]
  if (length(between) > 0L && length(diffs) > 0L) {
    diffs <- diffs - stats::ave(diffs, interaction(a[between], drop = TRUE))
  }
  stats::setNames(diffs, as.character(a[[subject]]))
}

.normality_within <- function(data, x, y, subject) {
  kept <- .complete_within(data, subject, x, y)
  d <- kept$data
  dropped <- kept$dropped_subjects
  d[[x]] <- droplevels(as.factor(d[[x]]))
  k <- nlevels(d[[x]])

  if (k == 2L) {
    tests <- .shapiro_row("differences", .paired_differences(d, y, x, subject))
    method <- "differences"
  } else {
    # Residuals of y ~ x + subject. With one value per participant and
    # condition and no gaps, OLS for the additive model is double centring.
    subj_mean <- stats::ave(d[[y]], d[[subject]])
    cond_mean <- stats::ave(d[[y]], d[[x]])
    res <- d[[y]] - subj_mean - cond_mean + mean(d[[y]])
    tests <- .shapiro_row("residuals", if (k > 2L) res else numeric(0))
    method <- "residuals"
  }
  .normality_result(tests, method, "none", list(dropped_subjects = dropped))
}


#' Check homogeneity of variances across groups
#'
#' Runs the **Brown-Forsythe test**: Levene's test computed on the absolute
#' deviations from each group's *median* rather than its mean
#' ([rstatix::levene_test()]'s default, \code{center = median}). The
#' median-centred version keeps close to its nominal error rate when the data
#' are skewed or heavy-tailed, as rating-scale data often are, where Levene's
#' mean-centred original rejects too often (Brown & Forsythe, 1974). Report it
#' under that name; the \code{"method"} attribute carries it, e.g. for
#' [assumption_methods_text()].
#'
#' The grouping column is treated as a factor whatever its type, so numeric
#' condition codes (1, 2, 3) define groups rather than a covariate, and
#' non-syntactic column names such as \code{"Mental Demand"} work.
#'
#' @param data the data frame
#' @param x the grouping variable (column name as string)
#' @param y the dependent variable (column name as string)
#'
#' @return TRUE if the test is non-significant (p >= .05), FALSE otherwise.
#'   Attributes: \code{"test"}, the test result (columns \code{df1},
#'   \code{df2}, \code{statistic}, \code{p}); \code{"method"}, the name of the
#'   test that was run (\code{"Brown-Forsythe test (median-centred Levene's
#'   test)"}).
#' @references Brown, M. B., & Forsythe, A. B. (1974). Robust tests for the
#'   equality of variances. \emph{Journal of the American Statistical
#'   Association, 69}(346), 364--367. \doi{10.1080/01621459.1974.10482955}
#' @export
check_homogeneity_by_group <- function(data, x, y) {
  not_empty(data)
  not_empty(x)
  not_empty(y)
  .check_columns(data, c(x, y))

  if (!requireNamespace("rstatix", quietly = TRUE)) {
    warning("Package 'rstatix' not installed. Assuming unequal variances (var.equal = FALSE).")
    return(FALSE)
  }

  # Work on an ungrouped copy: rstatix::levene_test() runs once per group of a
  # grouped tibble, and only the first of those results would be read below.
  # The grouping column becomes a factor, because car::leveneTest() refuses a
  # numeric one ("not appropriate with quantitative explanatory variables").
  d <- as.data.frame(data)[, c(x, y), drop = FALSE]
  d[[x]] <- if (is.factor(d[[x]])) droplevels(d[[x]]) else factor(d[[x]])

  # reformulate() + backticks, not paste(): "Mental Demand ~ cond" does not parse
  levene_res <- rstatix::levene_test(
    data    = d,
    formula = stats::reformulate(.bt(x), response = .bt(y))
  )

  # rstatix::levene_test returns a tibble with column 'p'
  p_val <- levene_res$p[1L]

  result <- if (is.na(p_val)) FALSE else p_val >= 0.05
  attr(result, "test") <- as.data.frame(levene_res)
  attr(result, "method") <- .BROWN_FORSYTHE
  return(result)
}

# Internal: the name of the variance test rstatix::levene_test() runs with its
# default `center = median`.
.BROWN_FORSYTHE <- "Brown-Forsythe test (median-centred Levene's test)"


# Internal: the standard-normal deviate behind a p-value, for Rosenthal's
# r = |z| / sqrt(N). A two-sided p-value splits its probability over both
# tails, so z = qnorm(p / 2); a one-sided one has it all in one tail, so
# z = qnorm(p). Halving a one-sided p overstates |z| (p = .031 one-sided gives
# |z| = 2.16 instead of 1.87) and with it r. A missing `alternative` -- a
# hand-built list, a test object that does not record one -- is two-sided.
.z_from_p <- function(p, alternative = "two.sided") {
  alt <- .scalar_chr(alternative)
  if (is.null(alt)) alt <- "two.sided"
  alt <- match.arg(alt, c("two.sided", "less", "greater"))
  if (identical(alt, "two.sided")) stats::qnorm(p / 2) else stats::qnorm(p)
}


#' Calculation based on Rosenthal's formula (1994). N stands for the *number of measurements*.
#'
#' Computes \eqn{r = |z| / \sqrt{N}}, recovering \eqn{z} from the test's
#' p-value. A two-sided p-value splits its probability over both tails, so
#' \eqn{z = \Phi^{-1}(p/2)}; a one-sided test (\code{alternative = "less"} or
#' \code{"greater"}, read from the test object) has it all in one tail, so
#' \eqn{z = \Phi^{-1}(p)}. Halving a one-sided p-value, as this function did
#' before 0.3.0, overstates \eqn{|z|} and therefore \eqn{r}.
#'
#' \eqn{r} is returned as a magnitude (non-negative); read the direction of the
#' effect from the data. With an exact p-value (small samples without ties) the
#' recovered \eqn{z} is the normal deviate matching that p-value rather than
#' the test's normal-approximation statistic.
#'
#' @param wilcoxModel the Wilcox model (an \code{htest} object from
#'   [stats::wilcox.test()]); its \code{alternative} is taken into account.
#' @param N number of measurements in the experiment
#'
#' @return Invisibly returns a list with components:
#'   \itemize{
#'     \item \code{r}: effect size as a numeric scalar.
#'     \item \code{z}: corresponding z-statistic.
#'     \item \code{text}: character string that is also sent to the console.
#'   }
#' @references Rosenthal, R. (1994). Parametric measures of effect size. In
#'   H. Cooper & L. V. Hedges (Eds.), \emph{The handbook of research
#'   synthesis} (pp. 231--244). Russell Sage Foundation.
#' @export
#'
#' @examples
#' set.seed(1)
#' d <- data.frame(
#'   group = rep(c("A", "B"), each = 10),
#'   value = rnorm(20)
#' )
#' w <- stats::wilcox.test(value ~ group, data = d, exact = FALSE)
#' rFromWilcox(w, N = nrow(d))
rFromWilcox <- function(wilcoxModel, N) {
  not_empty(wilcoxModel)
  not_empty(N)

  z <- .z_from_p(wilcoxModel$p.value, wilcoxModel$alternative)
  # Report the magnitude: z is derived from the p-value, which carries no
  # direction (a two-sided p always yields a negative z), so the raw quotient
  # would report a sign unrelated to the true direction.
  r <- abs(z / sqrt(N))

  msg <- sprintf(
    "%s Effect Size, r = %.3f, z = %.3f",
    wilcoxModel$data.name, r, z
  )
  message(msg)

  invisible(list(r = r, z = z, text = msg))
}

#' Effect size r from a multiplicity-inflated Wilcoxon p-value (deprecated)
#'
#' @description
#' `r lifecycle::badge("deprecated")`
#'
#' This function is deprecated because the quantity it returns is not an
#' effect size. It multiplies the p-value by \code{adjustFactor} before
#' converting it to \eqn{r}, which shrinks \eqn{r} towards zero as the number
#' of comparisons grows (\eqn{r = 0.34} becomes 0.21 with six comparisons and 0
#' with forty) although the effect itself is unchanged. Multiplicity
#' corrections belong to the p-values, which decide significance; an effect
#' size describes the magnitude of one comparison and is reported unadjusted.
#' Adjust the p-values with [stats::p.adjust()] and compute \eqn{r} with
#' [rFromWilcox()]. The old value is still returned for compatibility.
#'
#' @param wilcoxModel the Wilcox model; its \code{alternative} is taken into
#'   account as in [rFromWilcox()].
#' @param N number of measurements in the experiment
#' @param adjustFactor the factor the p-value is multiplied by (the number of
#'   comparisons).
#'
#' @return Invisibly returns a list with components:
#'   \itemize{
#'     \item \code{r}: the shrunken "effect size" as a numeric scalar.
#'     \item \code{z}: the z-statistic of the inflated p-value.
#'     \item \code{text}: character string that is also sent to the console.
#'   }
#' @export
#'
#' @examples \donttest{
#' set.seed(1)
#' d <- data.frame(
#'   group = rep(c("A", "B"), each = 10),
#'   value = rnorm(20)
#' )
#' w <- stats::wilcox.test(value ~ group, data = d, exact = FALSE)
#' # Instead of rFromWilcoxAdjusted(w, N = nrow(d), adjustFactor = 2):
#' stats::p.adjust(w$p.value, method = "bonferroni", n = 2)
#' rFromWilcox(w, N = nrow(d))
#' }
rFromWilcoxAdjusted <- function(wilcoxModel, N, adjustFactor) {
  lifecycle::deprecate_warn(
    when = "0.3.0",
    what = "rFromWilcoxAdjusted()",
    with = "rFromWilcox()",
    details = c(
      paste(
        "An effect size must not be adjusted for multiple comparisons:",
        "inflating the p-value by `adjustFactor` shrinks r towards zero",
        "although the effect is unchanged."
      ),
      i = "Adjust the p-values (stats::p.adjust()) and report the unadjusted r from rFromWilcox()."
    )
  )
  not_empty(wilcoxModel)
  not_empty(N)
  not_empty(adjustFactor)

  # An adjusted p-value (e.g. Bonferroni-style p * factor) can exceed 1, and
  # qnorm() would then return NaN; probabilities are capped at 1.
  adjusted_p <- min(wilcoxModel$p.value * adjustFactor, 1)
  z <- .z_from_p(adjusted_p, wilcoxModel$alternative)
  # Report the magnitude: z is derived from the p-value, which carries no
  # direction, so the raw quotient would report a sign unrelated to the true
  # direction.
  r <- abs(z / sqrt(N))

  msg <- sprintf(
    "%s Effect Size, r = %.3f, z = %.3f",
    wilcoxModel$data.name, r, z
  )
  message(msg)
  invisible(list(r = r, z = z, text = msg))
}


#' Calculation based on Rosenthal's formula (1994). N stands for the *number of measurements*.
#'
#' Computes \eqn{r = |z| / \sqrt{N}} with \eqn{z = \Phi^{-1}(p/2)} for a
#' two-sided p-value, or \eqn{z = \Phi^{-1}(p)} for a one-sided one
#' (\code{alternative = "less"} or \code{"greater"}).
#'
#' The conversion is defined for *focused* tests with a single degree of
#' freedom (Rosenthal, 1994). The p-value of an \eqn{F} test with one numerator
#' degree of freedom equals the two-sided p-value of the matching \eqn{t} test,
#' so the default is right for such effects. An omnibus \eqn{F} test with more
#' than one numerator degree of freedom -- a main effect of a three-level
#' factor, say -- has no single
#' direction and no \eqn{z} equivalent: its p-value converts to a number, but
#' not to the effect size \eqn{r} of anything. Pass \code{df1} to be warned in
#' that case, and report partial eta squared for such effects instead (as
#' [reportNPAV()] and [reportART()] do).
#'
#' Necessary LaTeX command:
#' \code{\\newcommand{\\effectsize}{\\textit{r=}}}
#'
#' @param pvalue p value
#' @param N number of measurements in the experiment
#' @param alternative \code{"two.sided"} (default), \code{"less"} or
#'   \code{"greater"}: the alternative of the test that produced
#'   \code{pvalue}.
#' @param df1 optional numerator degrees of freedom of the \eqn{F} test that
#'   produced \code{pvalue}; a value above 1 triggers a warning (see Details).
#'
#' @return Invisibly returns a list with components:
#'   \itemize{
#'     \item \code{r}: effect size as a numeric scalar.
#'     \item \code{z}: corresponding z-statistic.
#'     \item \code{text}: LaTeX-formatted character string that is also sent
#'       to the console.
#'   }
#' @references Rosenthal, R. (1994). Parametric measures of effect size. In
#'   H. Cooper & L. V. Hedges (Eds.), \emph{The handbook of research
#'   synthesis} (pp. 231--244). Russell Sage Foundation.
#' @export
#'
#' @examples rFromNPAV(0.02, N = 180)
rFromNPAV <- function(pvalue, N, alternative = "two.sided", df1 = NULL) {
  not_empty(pvalue)
  not_empty(N)

  if (!is.null(df1) && isTRUE(any(df1 > 1))) {
    warning(
      "rFromNPAV(): the p-value comes from a test with ", df1[1], " numerator ",
      "degrees of freedom. r = z / sqrt(N) is defined for single-df (focused) ",
      "tests only; report partial eta squared for an omnibus effect instead.",
      call. = FALSE
    )
  }

  z <- .z_from_p(pvalue, alternative)
  # Report the magnitude: z is derived from the p-value, which carries no
  # direction (a two-sided p always yields a negative z), so the raw quotient
  # would report a sign unrelated to the true direction.
  r <- abs(z / sqrt(N))

  stringtowrite <- sprintf(
    "\\effectsize{%s}, Z=%s",
    format(round(r, 3), trim = TRUE, nsmall = 3),
    format(round(z, 2), trim = TRUE, nsmall = 2)
  )
  message(stringtowrite)
  invisible(list(r = r, z = z, text = stringtowrite))
}


#' Debug contrast errors in ANOVA-like models
#'
#' @param dat A data frame of predictors.
#' @param subset_vec Optional logical or numeric index vector used to subset rows before checks.
#'
#' @return A list with two elements:
#' \describe{
#'   \item{nlevels}{Integer vector giving the number of levels for each factor
#'   variable in \code{dat}.}
#'   \item{levels}{List of factor level labels for each factor variable in
#'   \code{dat}.}
#' }

#' @export
#'
#' @examples
#' \donttest{
#' dat <- data.frame(
#'   group = factor(rep(letters[1:3], each = 3)),
#'   score = rnorm(9)
#' )
#'
#' debug_contr_error(dat = dat)
#' }
debug_contr_error <- function(dat, subset_vec = NULL) {
  if (!is.null(subset_vec)) {
    ## step 0
    if (mode(subset_vec) == "logical") {
      if (length(subset_vec) != nrow(dat)) {
        stop("'logical' `subset_vec` provided but length does not match `nrow(dat)`")
      }
      subset_log_vec <- subset_vec
    } else if (mode(subset_vec) == "numeric") {
      ## check range
      ran <- range(subset_vec)
      if (ran[1] < 1 || ran[2] > nrow(dat)) {
        stop("'numeric' `subset_vec` provided but values are out of bound")
      } else {
        subset_log_vec <- logical(nrow(dat))
        subset_log_vec[as.integer(subset_vec)] <- TRUE
      }
    } else {
      stop("`subset_vec` must be either 'logical' or 'numeric'")
    }
    dat <- base::subset(dat, subset = subset_log_vec)
  } else {
    ## step 1
    dat <- stats::na.omit(dat)
  }
  if (nrow(dat) == 0L) warning("no complete cases")
  ## step 2
  var_mode <- vapply(dat, mode, character(1))
  if (any(var_mode %in% c("complex", "raw"))) stop("complex or raw not allowed!")
  # inherits() rather than class() == "AsIs": class() of an ordered factor or a
  # date-time has length 2, which turns sapply(dat, class) into a list
  is_asis <- vapply(dat, function(v) inherits(v, "AsIs"), logical(1))
  if (any(var_mode[is_asis] %in% c("logical", "character"))) {
    stop("matrix variables with 'AsIs' class must be 'numeric'")
  }
  ind1 <- which(var_mode %in% c("logical", "character"))
  dat[ind1] <- lapply(dat[ind1], as.factor)
  ## step 3
  fctr <- which(vapply(dat, is.factor, logical(1)))
  if (length(fctr) == 0L) warning("no factor variables to summary")
  # The factors that were factors already must lose their unobserved levels
  # (as.factor() above only creates observed ones). setdiff() compares column
  # indices; `fctr[-ind1]` dropped by *position within fctr* instead, so a
  # character column placed before the offending factor removed the factor
  # itself from the list and its empty level was reported as real.
  ind2 <- setdiff(fctr, ind1)
  dat[ind2] <- lapply(dat[ind2], base::droplevels.factor)
  ## step 4
  lev <- lapply(dat[fctr], base::levels.default)
  nl <- lengths(lev)
  ## return
  list(nlevels = nl, levels = lev)
}


#' Check the assumptions for an ANOVA with a variable number of factors: Normality and Homogeneity of variance assumption.
#'
#' Checks the normality and variance assumptions of a factorial ANOVA and
#' recommends the parametric or the non-parametric analysis. Every factor is
#' treated as categorical -- numeric condition codes (1, 2, 3) included, which
#' [stats::lm()] would otherwise fit as a single linear covariate -- and the
#' message names the tests that were run and their results.
#'
#' * **Between subjects** (\code{subject = NULL}, the default): a Shapiro-Wilk
#'   test on the residuals of the linear model \code{y ~ A * B * ...}; a
#'   Shapiro-Wilk test within every cell of the design, Holm-corrected across
#'   the cells (as in [check_normality_by_group()]); and the Brown-Forsythe
#'   test (median-centred Levene's test) across the cells. This assumes one
#'   row per participant: a within-subject factor analysed this way is tested
#'   on residuals that still contain each participant's overall level, so pass
#'   \code{subject} for repeated measures.
#' * **Within subjects or mixed** (\code{subject} given): a Shapiro-Wilk test on
#'   the residuals of \code{y ~ A * B * ... + subject}, with the participant
#'   as a fixed factor -- the residuals after removing each participant's
#'   overall level, which is what a repeated-measures ANOVA assumes to be
#'   normal. The raw scores per cell are not tested, as they also carry the
#'   between-participant spread. Variance homogeneity is checked only for
#'   between-subject factors (those constant within a participant), with the
#'   Brown-Forsythe test across their groups at each combination of the
#'   within-subject factors (Holm-corrected). For within-subject factors the
#'   corresponding assumption is sphericity, which [rstatix::anova_test()]
#'   tests (Mauchly) and corrects (Greenhouse-Geisser) itself. More than one
#'   row per participant and cell is an error: aggregate repeated trials
#'   first.
#'
#' A residual set or cell that cannot be tested -- fewer than three values, or
#' no variance -- counts as **not** normal, so the advice errs towards the
#' non-parametric analysis. Rows with a missing value in \code{y},
#' \code{factors} or \code{subject} are left out.
#'
#' @param data the data frame
#' @param y The dependent variable for which assumptions should be checked
#' @param factors A character vector of factor names
#' @param subject the participant-ID column for a design with within-subject
#'   factors, as a string; \code{NULL} (default) for a between-subjects design.
#'
#' @return The guidance text (also emitted as a message), invisibly, with
#'   attributes:
#'   \describe{
#'     \item{\code{parametric}}{\code{TRUE} if every check passed.}
#'     \item{\code{design}}{\code{"between"}, \code{"within"} or
#'       \code{"mixed"}.}
#'     \item{\code{method}}{named character vector naming the tests run
#'       (\code{residuals}, \code{groupwise}, \code{homogeneity}).}
#'     \item{\code{residuals}}{the Shapiro-Wilk result on the model residuals
#'       (columns as in [check_normality_by_group()]'s \code{tests}).}
#'     \item{\code{groupwise}}{between subjects: the per-cell Shapiro-Wilk
#'       results with Holm-adjusted p-values; \code{NULL} otherwise.}
#'     \item{\code{homogeneity}}{the Brown-Forsythe result(s) (\code{df1},
#'       \code{df2}, \code{statistic}, \code{p}, \code{p_adjusted}), or
#'       \code{NULL} when no between-subject factor exists.}
#'   }
#' @export
#'
#' @examples
#' \donttest{
#' set.seed(123)
#'
#' main_df <- data.frame(
#'   tlx_mental      = rnorm(40),
#'   Video           = factor(rep(c("A", "B"), each = 20)),
#'   DriverPosition  = factor(rep(c("Left", "Right"), times = 20))
#' )
#'
#' checkAssumptionsForAnova(
#'   data    = main_df,
#'   y       = "tlx_mental",
#'   factors = c("Video", "DriverPosition")
#' )
#'
#' # The same two factors measured within each of 10 participants
#' within_df <- expand.grid(
#'   id             = 1:10,
#'   Video          = c("A", "B"),
#'   DriverPosition = c("Left", "Right")
#' )
#' within_df$tlx_mental <- rnorm(10)[within_df$id] + rnorm(40)
#' checkAssumptionsForAnova(
#'   data    = within_df,
#'   y       = "tlx_mental",
#'   factors = c("Video", "DriverPosition"),
#'   subject = "id"
#' )
#' }
checkAssumptionsForAnova <- function(data, y, factors, subject = NULL) {
  # Ensure data and variables are not empty
  not_empty(data)
  not_empty(y)
  not_empty(factors)
  .check_columns(data, c(y, factors, subject))

  if (!requireNamespace("rstatix", quietly = TRUE)) {
    stop("Package 'rstatix' is required for checkAssumptionsForAnova(). Please install it.")
  }

  # Work on a copy holding only the analysed columns, with complete rows.
  d <- as.data.frame(data)[, unique(c(y, factors, subject)), drop = FALSE]
  d <- d[stats::complete.cases(d), , drop = FALSE]
  not_empty(d, msg = "No complete rows in `data` for the given `y`, `factors` and `subject`.")
  if (!is.numeric(d[[y]])) {
    stop("checkAssumptionsForAnova(): `y` ('", y, "') must be numeric.", call. = FALSE)
  }
  # Factors become factors: lm() fits a numeric condition code as one linear
  # covariate (so 1/2/3 gives other residuals than "A"/"B"/"C"), and
  # car::leveneTest() refuses it outright.
  for (f in factors) {
    d[[f]] <- if (is.factor(d[[f]])) droplevels(d[[f]]) else factor(d[[f]])
  }
  cells <- interaction(d[factors], drop = TRUE, sep = ":")

  # Which factors vary within participants decides the design.
  design <- "between"
  between <- factors
  if (!is.null(subject)) {
    d[[subject]] <- factor(as.character(d[[subject]]))
    is_between <- vapply(factors, function(f) {
      all(tapply(d[[f]], d[[subject]], function(v) length(unique(v))) <= 1, na.rm = TRUE)
    }, logical(1))
    between <- factors[is_between]
    within <- factors[!is_between]
    if (length(within) > 0) {
      design <- if (length(between) > 0) "mixed" else "within"
    }
    # One row per participant and within-subject cell, and only participants
    # observed in every such cell -- the rule every within-subjects entry point
    # shares. With no within-subject factor this is one row per participant.
    d <- .complete_within(d, subject, within, y)$data
    d[] <- lapply(d, function(v) if (is.factor(v)) droplevels(v) else v)
    cells <- interaction(d[factors], drop = TRUE, sep = ":")
  }

  fmt_p <- function(p) {
    if (is.na(p)) "p = NA" else if (p < 0.001) "p < 0.001" else paste0("p = ", .fmt_p_number(p))
  }
  rhs <- paste(.bt(factors), collapse = " * ")
  model_txt <- paste(y, "~", paste(factors, collapse = " * "))

  # 1. Normality of the model residuals
  if (design == "between") {
    model_formula <- stats::as.formula(paste(.bt(y), "~", rhs))
  } else {
    model_formula <- stats::as.formula(paste(.bt(y), "~", rhs, "+", .bt(subject)))
    model_txt <- paste(model_txt, "+", subject)
  }
  res_label <- paste0("the residuals of ", model_txt)
  if (design != "between" && length(within) == 1L && nlevels(d[[within]]) == 2L) {
    # One two-level within factor: test the per-participant differences, not
    # the mirror-image residuals (see .paired_differences()).
    resid_values <- .paired_differences(d, y, within, subject, between)
    res_label <- paste0("the per-participant differences between the levels of ", within,
                        if (length(between) > 0) " (centred within groups)" else "")
  } else {
    resid_values <- stats::residuals(stats::lm(model_formula, data = d))
  }
  residual_check <- .normality_result(
    .shapiro_row("residuals", resid_values), "residuals", "none"
  )
  residual_tests <- attr(residual_check, "tests")
  method <- c(residuals = paste0("Shapiro-Wilk test on ", res_label))

  # 2. Normality within each cell -- between subjects only, where the residuals
  # of a cell are its scores minus the cell mean.
  groupwise_check <- NULL
  if (design == "between") {
    groups <- split(d[[y]], cells)
    groupwise_check <- .normality_result(
      do.call(rbind, Map(.shapiro_row, names(groups), groups)), "groupwise", "holm"
    )
    method <- c(method, groupwise = paste0(
      "Shapiro-Wilk test per cell (",
      if (identical(attr(groupwise_check, "p_adjust"), "none")) "unadjusted" else "Holm-adjusted",
      ")"
    ))
  }

  # 3. Homogeneity of variance across the between-subject groups, at each
  # combination of the within-subject factors (once, between subjects).
  levene_one <- function(dd) {
    res <- tryCatch(
      rstatix::levene_test(
        dd, stats::reformulate(paste(.bt(between), collapse = " * "), response = .bt(y))
      ),
      error = function(e) NULL
    )
    if (is.null(res)) {
      return(data.frame(df1 = NA_real_, df2 = NA_real_, statistic = NA_real_, p = NA_real_))
    }
    as.data.frame(res)
  }
  homogeneity <- NULL
  if (length(between) > 0 && nlevels(interaction(d[between], drop = TRUE)) > 1) {
    if (design == "between") {
      homogeneity <- levene_one(d)
      homogeneity$cell <- "all"
    } else {
      at <- split(d, interaction(d[within], drop = TRUE, sep = ":"))
      homogeneity <- do.call(rbind, lapply(names(at), function(nm) {
        cbind(levene_one(at[[nm]]), cell = nm, stringsAsFactors = FALSE)
      }))
    }
    rownames(homogeneity) <- NULL
    homogeneity$p_adjusted <- stats::p.adjust(homogeneity$p, method = "holm")
    method <- c(method, homogeneity = paste0(
      .BROWN_FORSYTHE, if (nrow(homogeneity) > 1) " at each within-subject cell (Holm-adjusted)" else ""
    ))
  }

  # Decide, naming the first assumption that fails.
  res_row <- residual_tests[1, ]
  res_txt <- paste0("Shapiro-Wilk on ", res_label, ": ",
                    if (isTRUE(res_row$testable)) paste0("W = ", .fmt_num(res_row$W, 3), ", ", fmt_p(res_row$p_value)) else "not testable")
  text <- NULL
  if (!isTRUE(res_row$testable)) {
    text <- paste0("Normality of the model residuals (", model_txt, ") could not be assessed ",
                   "(fewer than three residuals or no variance). Take the non-parametric ANOVA to be safe.")
  } else if (!isTRUE(as.logical(residual_check))) {
    text <- paste0("You must take the non-parametric ANOVA as the model residuals are non-normal (",
                   res_txt, ").")
  }
  if (is.null(text) && !is.null(groupwise_check) && !isTRUE(as.logical(groupwise_check))) {
    gt <- attr(groupwise_check, "tests")
    untestable <- attr(groupwise_check, "untestable")
    if (length(untestable) > 0) {
      text <- paste0("Group-wise normality could not be assessed for cell(s) ",
                     paste(untestable, collapse = ", "),
                     " (fewer than three observations or no variance). Take the non-parametric ANOVA to be safe.")
    } else {
      worst <- which.min(gt$p_adjusted)
      text <- paste0("You must take the non-parametric ANOVA as normality assumption by groups is violated ",
                     "(Shapiro-Wilk per cell, ", sub("^Shapiro-Wilk test per cell \\((.*)\\)$", "\\1", method[["groupwise"]]),
                     "; cell ", gt$group[worst], ": W = ", .fmt_num(gt$W[worst], 3), ", ",
                     fmt_p(gt$p_adjusted[worst]), ").")
    }
  }
  if (is.null(text) && !is.null(homogeneity)) {
    worst <- if (all(is.na(homogeneity$p_adjusted))) 1L else which.min(homogeneity$p_adjusted)
    hr <- homogeneity[worst, ]
    if (is.na(hr$p_adjusted)) {
      text <- paste0("Homogeneity of variance could not be assessed (", .BROWN_FORSYTHE,
                     " failed). Take the non-parametric ANOVA to be safe.")
    } else if (hr$p_adjusted < 0.05) {
      text <- paste0("You must take the non-parametric ANOVA as the ", .BROWN_FORSYTHE, " is significant (",
                     if (nrow(homogeneity) > 1) paste0("at ", hr$cell, ", Holm-adjusted: ") else "",
                     "F(", .fmt_df(hr$df1), ", ", .fmt_df(hr$df2), ") = ", .fmt_num(hr$statistic),
                     ", ", fmt_p(hr$p_adjusted), ").")
    }
  }

  parametric <- is.null(text)
  if (parametric) {
    checks <- res_txt
    if (!is.null(groupwise_check)) {
      checks <- c(checks, paste0(method[["groupwise"]], ": no cell deviates"))
    }
    if (!is.null(homogeneity)) {
      hr <- homogeneity[which.min(homogeneity$p_adjusted), ]
      checks <- c(checks, paste0(.BROWN_FORSYTHE, ": F(", .fmt_df(hr$df1), ", ", .fmt_df(hr$df2), ") = ",
                                 .fmt_num(hr$statistic), ", ", fmt_p(hr$p_adjusted),
                                 if (nrow(homogeneity) > 1) " (smallest Holm-adjusted)" else ""))
    }
    if (design != "between") {
      checks <- c(checks, paste0(
        "sphericity of the within-subject factor(s) ", paste(within, collapse = ", "),
        " is tested (Mauchly) and corrected (Greenhouse-Geisser) by rstatix::anova_test()"
      ))
    }
    text <- paste0("You may take parametric ANOVA (function anova_test). Checks: ",
                   paste(checks, collapse = "; "),
                   ". See https://www.datanovia.com/learn/biostatistics/anova/anova-in-r#check-assumptions-1 for more information.")
  }

  message(text)
  attr(text, "parametric") <- parametric
  attr(text, "design") <- design
  attr(text, "method") <- method
  attr(text, "residuals") <- residual_tests
  attr(text, "groupwise") <- if (is.null(groupwise_check)) NULL else attr(groupwise_check, "tests")
  attr(text, "homogeneity") <- homogeneity
  invisible(text)
}


#' Replace values across a data frame
#'
#' @description
#' Replace all occurrences of given values in all columns of a data frame.
#' Factor levels are preserved (and extended by the replacement values), and
#' numeric/logical columns are only touched where a value actually matches, so
#' unrelated entries keep their exact binary representation.
#'
#' @param data The input data frame to be modified.
#' @param to_replace A vector of values to be replaced within the data frame. This must be the same length as `replace_with`.
#' @param replace_with A vector of corresponding replacement values. This must be the same length as `to_replace`.
#'
#' @return Modified data frame with specified values replaced.
#' @export
#'
#' @examples
#' \donttest{
#' data <- data.frame(
#'   q1 = c("neg2", "neg1", "0"),
#'   q2 = c("1", "neg2", "neg1")
#' )
#'
#' replace_values(
#'   data,
#'   to_replace = c("neg2", "neg1"),
#'   replace_with = c("-2", "-1")
#' )
#' }
replace_values <- function(data, to_replace, replace_with) {
  if (length(to_replace) != length(replace_with)) {
    stop("Length of 'to_replace' and 'replace_with' must be the same.")
  }

  # Create a named vector for replacements
  replace_map <- setNames(replace_with, to_replace)

  # Apply replacements column-wise. Only the matching entries are touched:
  # round-tripping a whole numeric column through as.character()/as.numeric()
  # would silently lose precision in values that were never replaced
  # (as.character() keeps only 15 significant digits).
  data[] <- lapply(data, function(column) {
    # Convert factors to characters and restore factor levels after replacement
    if (is.factor(column)) {
      column_chr <- as.character(column)
      hits <- !is.na(column_chr) & column_chr %in% names(replace_map)
      if (!any(hits)) {
        return(column)
      }
      column_chr[hits] <- replace_map[column_chr[hits]]
      new_levels <- unique(c(levels(column), replace_with))
      return(factor(column_chr, levels = new_levels))
    }

    # Replace values for character columns
    if (is.character(column)) {
      hits <- !is.na(column) & column %in% names(replace_map)
      if (any(hits)) {
        column[hits] <- replace_map[column[hits]]
      }
      return(column)
    }

    # Logical/numeric columns: match on the character representation, replace
    # in place, and only if the replacements are type-compatible
    if (is.logical(column) || is.numeric(column)) {
      column_chr <- as.character(column)
      hits <- !is.na(column_chr) & column_chr %in% names(replace_map)
      if (!any(hits)) {
        return(column)
      }
      replacement_chr <- unname(replace_map[column_chr[hits]])

      if (is.logical(column)) {
        coerced <- as.logical(replacement_chr)
        if (any(is.na(coerced) & !is.na(replacement_chr))) {
          stop("Replacement values are incompatible with logical columns.")
        }
        column[hits] <- coerced
        return(column)
      }

      coerced <- suppressWarnings(as.numeric(replacement_chr))
      if (any(is.na(coerced) & !is.na(replacement_chr))) {
        stop("Replacement values are incompatible with numeric columns.")
      }
      column[hits] <- if (is.integer(column)) as.integer(coerced) else coerced
      return(column)
    }

    column
  })

  return(data)
}


#' Reshape Excel Data Based on Custom Markers and Include Custom ID Column
#'
#' This function takes an Excel file with data in a wide format and transforms it to a long format.
#' It includes a customizable "ID" column in the first position and repeats it for each slice.
#' The function identifies sections of columns between markers that start with a user-defined string (default is "videoinfo")
#' and appends those sections under the first section, aligning by column index.
#' Columns before the first marker (e.g. a survey export's metadata or
#' demographics) are not a section: like the ID column, they are repeated for
#' every slice. The marker columns themselves are dropped.
#'
#' Relevant if you receive data in wide-format but cannot use built-in functionality due to naming (e.g., in LimeSurvey)
#'
#' @param input_filepath String, the file path of the input Excel file.
#' @param sheetName String, the name of the sheet to read from the Excel file. Default is "Results".
#' @param marker String, the string that identifies the start of a new section of columns. Default is "videoinfo".
#' @param id_col String, the name of the column to use as the ID column. Default is "ID".
#' @param output_filepath String, the file path for the output Excel file.
#'
#' @return None, writes the reshaped data to an Excel file specified by output_filepath.
#' @export
#'
#' @examples
#' \donttest{
#' if (requireNamespace("writexl", quietly = TRUE) &&
#'   requireNamespace("readxl", quietly = TRUE)) {
#'   tmp_in  <- tempfile(fileext = ".xlsx")
#'   tmp_out <- tempfile(fileext = ".xlsx")
#'
#'   # Two marker-delimited sections of equal width; each section is stacked
#'   # under the first one, keyed by the ID column.
#'   toy <- data.frame(
#'     ID = c(1, 2),
#'     videoinfo1 = c("marker", "marker"),
#'     rating = c(10, 11),
#'     videoinfo2 = c("marker", "marker"),
#'     rating2 = c(20, 21),
#'     stringsAsFactors = FALSE
#'   )
#'
#'   writexl::write_xlsx(toy, tmp_in)
#'
#'   reshape_data(
#'     input_filepath = tmp_in,
#'     marker = "videoinfo",
#'     id_col = "ID",
#'     output_filepath = tmp_out
#'   )
#'
#'   out <- readxl::read_excel(tmp_out)
#'   print(out)
#' }
#' }
reshape_data <- function(input_filepath, sheetName = "Results", marker = "videoinfo", id_col = "ID", output_filepath) {
  if (!requireNamespace("readxl", quietly = TRUE) || !requireNamespace("writexl", quietly = TRUE)) {
    stop("Packages 'readxl' and 'writexl' are required for reshape_data(). Please install them.")
  }

  # Read the Excel file into a data frame. If the requested sheet is missing,
  # fall back to the first available sheet to keep the helper robust for
  # single-sheet workbooks created on the fly (e.g., in tests).
  available_sheets <- readxl::excel_sheets(input_filepath)
  sheet_to_read <- if (sheetName %in% available_sheets) sheetName else available_sheets[[1]]
  df <- readxl::read_excel(input_filepath, sheet = sheet_to_read)

  .check_columns(df, id_col, data_arg = "the sheet")

  data_columns <- setdiff(names(df), id_col)
  is_marker <- startsWith(data_columns, marker)
  section_id <- cumsum(is_marker)

  # Columns before the first marker are not a section: they are per-participant
  # columns (a survey export's submit date, language, demographics). They used
  # to be stacked as the first slice, which either failed the equal-width
  # check below or -- when the widths happened to match -- silently stacked
  # them under the item columns and renamed every slice after them. They are
  # now carried along with the ID, repeated for every slice.
  leading_cols <- if (any(is_marker)) data_columns[section_id == 0] else character(0)

  # Extract the custom "ID" column (plus the per-participant columns)
  id_column <- df |> dplyr::select(dplyr::all_of(c(id_col, leading_cols)))

  # Sections are the runs of columns between marker columns (markers
  # themselves are dropped). Empty runs (adjacent markers) are discarded.
  in_section <- !is_marker & section_id > 0
  section_cols <- split(data_columns[in_section], section_id[in_section])
  section_cols <- Filter(length, section_cols)

  if (length(section_cols) == 0) {
    long_df <- dplyr::bind_cols(
      df |> dplyr::select(dplyr::all_of(id_col)),
      df |> dplyr::select(-dplyr::all_of(id_col))
    )
  } else {
    widths <- lengths(section_cols)
    if (length(unique(widths)) > 1) {
      stop(
        "All sections delimited by marker '", marker,
        "' must contain the same number of columns; found section widths: ",
        paste(widths, collapse = ", "), "."
      )
    }

    base_names <- c(id_col, leading_cols, section_cols[[1]])
    slices <- lapply(section_cols, function(cols) {
      slice <- dplyr::bind_cols(id_column, df |> dplyr::select(dplyr::all_of(cols)))
      names(slice) <- base_names
      slice
    })
    long_df <- dplyr::bind_rows(slices, .id = NULL)
  }

  # Check if file exists and modify output_filepath to avoid overwriting
  counter <- 1
  new_output_filepath <- output_filepath
  while (file.exists(new_output_filepath)) {
    new_output_filepath <- paste0(gsub("\\.xlsx$", "", output_filepath), "_", counter, ".xlsx")
    counter <- counter + 1
  }

  # Write the long-form data frame to a new Excel file
  writexl::write_xlsx(long_df, new_output_filepath)
}


# Internal: validate the `maximise` argument of the Pareto helpers and expand it
# to one entry per objective.
#
# The length check is deliberately strict. moocore::is_nondominated() does NOT
# reject a `maximise` of the wrong length -- given three flags for two
# objectives it silently uses the first two -- so a mis-specified direction
# would quietly produce a plausible, wrong front. Catch it here instead.
.pareto_maximise <- function(maximise, objectives) {
  if (!is.logical(maximise) || anyNA(maximise)) {
    stop(
      "`maximise` must be TRUE or FALSE, or a logical vector with one entry ",
      "per objective (no NAs).",
      call. = FALSE
    )
  }
  n <- length(objectives)
  if (length(maximise) == 1L) {
    return(rep(maximise, n))
  }
  if (length(maximise) != n) {
    stop(
      "`maximise` has ", length(maximise), " entr",
      if (length(maximise) == 1) "y" else "ies", " but there ",
      if (n == 1) "is " else "are ", n, " objective", if (n == 1) "" else "s",
      " (", paste(objectives, collapse = ", "), "). Give one flag, or one per objective.",
      call. = FALSE
    )
  }
  maximise
}


# Internal: flip the objectives that are to be maximised, so that a
# minimisation-only dominance routine answers the maximisation question.
# Negating a criterion turns "smaller is better" into "larger is better" and
# leaves the dominance relation otherwise untouched.
.pareto_orient <- function(objective_data, maximise) {
  for (j in which(maximise)) {
    objective_data[[j]] <- -objective_data[[j]]
  }
  objective_data
}


#' Add `PARETO_EMOA` Column to a Data Frame
#'
#' This function calculates the Pareto front using emoa for a given set of objectives in a data frame and adds a new column, `PARETO_EMOA`, which indicates whether each row in the data frame belongs to the Pareto front.
#'
#' @param data A data frame containing the data, including the objective columns.
#' @param objectives A character vector specifying the names of the objective columns in `data`. These columns should be numeric and will be used to calculate the Pareto front.
#' @param maximise Direction of optimisation. \code{FALSE} (the default) treats
#'   every objective as one to be \emph{minimised}, which is what
#'   \pkg{emoa} does natively. Pass \code{TRUE} when larger is better for every
#'   objective -- as it is for trust, acceptance, perceived safety and most
#'   other rating-scale outcomes -- or a logical vector with one entry per
#'   objective for a mixed problem, e.g.
#'   \code{c(TRUE, TRUE, FALSE)} to maximise the first two and minimise the
#'   third. Objectives flagged \code{TRUE} are negated internally, so you no
#'   longer need to pass negated copies of your own columns.
#'
#' @return A data frame with the same columns as `data`, along with an additional column, `PARETO_EMOA`, which is `TRUE` for rows that are on the Pareto front and `FALSE` otherwise.
#'   Identical rows share one verdict (a copy of a non-dominated point is
#'   non-dominated too), as in [add_pareto_moocore_column()]. Rows with a
#'   missing objective value get \code{NA}, with a warning, and the front is
#'   computed from the complete rows.
#' @export
#' @seealso [add_pareto_moocore_column()], which answers the same question via
#'   \pkg{moocore} and accepts the same \code{maximise} argument.
#'
#' @examples
#' # Define objective columns
#' objectives <- c("trust", "predictability", "perceivedSafety", "Comfort")
#'
#' # Example data frame
#' main_df <- data.frame(
#'   trust = runif(10),
#'   predictability = runif(10),
#'   perceivedSafety = runif(10),
#'   Comfort = runif(10)
#' )
#'
#' # Add the Pareto front column (minimising, the default)
#' main_df <- add_pareto_emoa_column(data = main_df, objectives)
#' head(main_df)
#'
#' # All four objectives are ratings where higher is better
#' main_df <- add_pareto_emoa_column(main_df, objectives, maximise = TRUE)
add_pareto_emoa_column <- function(data, objectives, maximise = FALSE) {
  if (!requireNamespace("emoa", quietly = TRUE)) {
    stop("Package 'emoa' is required for add_pareto_emoa_column(). Please install it.")
  }

  # Input checks
  not_empty(data)
  not_empty(objectives)
  .check_columns(data, objectives)

  # Select only the objective columns
  objective_data <- data |> dplyr::select(dplyr::all_of(objectives))
  non_numeric <- names(objective_data)[!vapply(objective_data, is.numeric, logical(1))]
  if (length(non_numeric) > 0) {
    stop(
      "All objective columns must be numeric; not numeric: ",
      paste0("'", non_numeric, "'", collapse = ", "), ".",
      call. = FALSE
    )
  }

  maximise <- .pareto_maximise(maximise, objectives)
  objective_data <- .pareto_orient(objective_data, maximise)
  ok <- .pareto_complete_rows(objective_data, "PARETO_EMOA")

  # emoa expects one point per matrix *column* (criteria in rows) and
  # minimises every criterion; emoa::is_dominated() has no direction argument,
  # so the maximised objectives were negated above. is_dominated() flags each
  # point directly, so no error-prone float-equality matching against the front
  # is needed.
  front <- rep(NA, nrow(data))
  if (any(ok)) {
    m <- t(as.matrix(objective_data[ok, , drop = FALSE]))
    # emoa's C code accepts only a double matrix ("Argument 's_points' is not a
    # real matrix"), and rating-scale columns are often integer
    storage.mode(m) <- "double"
    front[ok] <- !emoa::is_dominated(m)
  }
  data$PARETO_EMOA <- front

  # Return the updated data frame
  return(data)
}


#' Add `PARETO_MOOCORE` Column to a Data Frame
#'
#' This function calculates the Pareto front using moocore for a given set of objectives in a data frame and adds a new column, `PARETO_MOOCORE`, which indicates whether each row in the data frame belongs to the Pareto front.
#'
#' @param data A data frame containing the data, including the objective columns.
#' @param objectives A character vector specifying the names of the objective columns in `data`. These columns should be numeric and will be used to calculate the Pareto front.
#' @param maximise Direction of optimisation, passed through to
#'   \code{moocore::is_nondominated()}. \code{FALSE} (the default) treats every
#'   objective as one to be \emph{minimised}. Pass \code{TRUE} when larger is
#'   better for every objective -- as it is for trust, acceptance, perceived
#'   safety and most other rating-scale outcomes -- or a logical vector with one
#'   entry per objective for a mixed problem, e.g. \code{c(TRUE, TRUE, FALSE)}
#'   to maximise the first two and minimise the third. This removes the need to
#'   pass negated copies of your own columns.
#'
#' @return A data frame with the same columns as `data`, along with an additional column, `PARETO_MOOCORE`, which is `TRUE` for rows that are on the Pareto front and `FALSE` otherwise.
#'   Identical rows share one verdict: every copy of a non-dominated point is
#'   kept (\code{keep_weakly = TRUE}), as in [add_pareto_emoa_column()], where
#'   \code{moocore::is_nondominated()} on its own would mark only the first
#'   copy. Rows with a missing objective value get \code{NA}, with a warning,
#'   and the front is computed from the complete rows.
#' @export
#' @seealso [add_pareto_emoa_column()], which answers the same question via
#'   \pkg{emoa} and accepts the same \code{maximise} argument.
#'
#' @examples
#' # Define objective columns
#' objectives <- c("trust", "predictability", "perceivedSafety", "Comfort")
#'
#' # Example data frame
#' main_df <- data.frame(
#'   trust = runif(10),
#'   predictability = runif(10),
#'   perceivedSafety = runif(10),
#'   Comfort = runif(10)
#' )
#'
#' # Add the Pareto front column (minimising, the default)
#' main_df <- add_pareto_moocore_column(data = main_df, objectives)
#' head(main_df)
#'
#' # All four objectives are ratings where higher is better
#' main_df <- add_pareto_moocore_column(main_df, objectives, maximise = TRUE)
#'
#' # Mixed: maximise the ratings, minimise a workload score
#' main_df$workload <- runif(10)
#' main_df <- add_pareto_moocore_column(
#'   main_df,
#'   c(objectives, "workload"),
#'   maximise = c(TRUE, TRUE, TRUE, TRUE, FALSE)
#' )
add_pareto_moocore_column <- function(data, objectives, maximise = FALSE) {
  if (!requireNamespace("moocore", quietly = TRUE)) {
    stop("Package 'moocore' is required for add_pareto_moocore_column(). Please install it.")
  }

  # Input checks
  not_empty(data)
  not_empty(objectives)
  .check_columns(data, objectives)

  # Select only the objective columns
  objective_data <- data |> dplyr::select(dplyr::all_of(objectives))
  non_numeric <- names(objective_data)[!vapply(objective_data, is.numeric, logical(1))]
  if (length(non_numeric) > 0) {
    stop(
      "All objective columns must be numeric; not numeric: ",
      paste0("'", non_numeric, "'", collapse = ", "), ".",
      call. = FALSE
    )
  }

  # Validate the direction before the single-row shortcut, so a mis-specified
  # `maximise` is reported for every input rather than only for some.
  maximise <- .pareto_maximise(maximise, objectives)

  ok <- .pareto_complete_rows(objective_data, "PARETO_MOOCORE")
  front <- rep(NA, nrow(data))
  m <- as.matrix(objective_data[ok, , drop = FALSE])
  storage.mode(m) <- "double"

  if (nrow(m) == 1L) {
    # A single point is trivially non-dominated whichever way the objectives
    # point.
    front[ok] <- TRUE
  } else if (nrow(m) > 1L) {
    front[ok] <- .moocore_nondominated(m, maximise)
  }
  data$PARETO_MOOCORE <- front

  # Return the updated data frame
  return(data)
}


# Internal: rows whose objectives are all observed. A missing objective makes a
# point incomparable, and neither backend copes: emoa::is_dominated() lets the
# NA poison the comparisons (a point that is on the front among the complete
# rows comes back as dominated). Such rows get NA, and the front is computed
# from the complete rows only.
.pareto_complete_rows <- function(objective_data, column) {
  ok <- stats::complete.cases(objective_data)
  if (!all(ok)) {
    warning(
      sum(!ok), " row", if (sum(!ok) == 1) "" else "s",
      " with a missing objective value cannot be compared and get NA in `",
      column, "`; the front is computed from the complete rows.",
      call. = FALSE
    )
  }
  ok
}


# Internal: moocore's non-dominance with weak dominance, i.e. every copy of a
# non-dominated point is kept. moocore::is_nondominated() defaults to
# keep_weakly = FALSE and marks only the first of two identical non-dominated
# rows, while emoa::is_dominated() marks both -- so the two backends disagreed
# on any data set with ties, which rating-scale data produce all the time. A
# moocore without `keep_weakly` gets the same answer by evaluating the distinct
# points and giving every duplicate its point's verdict.
.moocore_nondominated <- function(m, maximise) {
  if ("keep_weakly" %in% names(formals(moocore::is_nondominated))) {
    return(moocore::is_nondominated(m, maximise = maximise, keep_weakly = TRUE))
  }
  key <- apply(m, 1, function(r) paste(sprintf("%.17g", r), collapse = "\r"))
  first <- !duplicated(key)
  nd <- moocore::is_nondominated(m[first, , drop = FALSE], maximise = maximise)
  nd[match(key, key[first])]
}



#' Flag suspicious survey responses via the Response Entropy Index (REI)
#'
#' Computes each respondent's Response Entropy Index (Tawa, 2021) and flags
#' unusually low or high values. Note that no rows are removed; entries are
#' only flagged via the `Suspicious` column.
#'
#' The REI is the Shannon entropy (base 10) of a respondent's distribution of
#' answers over the response options,
#' \eqn{REI_i = -\sum_k p_{ki} \log_{10} p_{ki}}, where \eqn{p_{ki}} is the
#' proportion of the respondent's *answered* items that received option
#' \eqn{k}. Low values indicate overly consistent answering (e.g.
#' straight-lining), high values overly scattered answering; either can
#' indicate careless responding. Because the index ignores item content,
#' compute it on the items as answered, before reverse-coding (Tawa, 2021).
#'
#' Missing responses are left out: proportions are taken over the items a
#' respondent answered, so the same answer pattern yields the same REI however
#' many items were skipped (dividing by the total number of items, as versions
#' before 0.3.0 did, lowered the REI of anyone who skipped items). A
#' respondent who answered nothing gets \code{NA}. Responses outside the
#' declared Likert `range` trigger a warning (they often indicate mis-coded
#' data, or a non-item column) but are still included in the REI computation.
#'
#' Flags are relative to the sample: each REI is converted to a percentile of
#' a normal distribution with the sample's mean and standard deviation.
#' \code{"Maybe"} marks the outer 10% on either side (the preliminary guideline
#' of Tawa, 2021), \code{"Yes"} the outer 5%. When all
#' respondents have the same REI the percentiles are undefined: `Percentile`
#' is \code{NA}, no row is flagged, and a warning says so.
#'
#' @param df Data frame containing the data.
#' @param header Which columns enter the computation. \code{TRUE}: only the
#'   columns named in \code{variables}. \code{FALSE} (the default, kept for
#'   compatibility): \emph{every} column of \code{df} -- remove ID, timestamp
#'   and other non-item columns first. A warning names any column that does not
#'   look like a response: with \code{header = FALSE} a non-numeric column, and
#'   in either mode a column with values outside \code{range}.
#' @param variables Which variables to consider when \code{header = TRUE}:
#'   either a single character string with names separated by commas
#'   (\code{"var1,var2"}) or a character vector (\code{c("var1", "var2")}).
#'   Names are matched exactly (not as regular expressions), so survey-export
#'   names such as \code{"G01Q01[SQ001]"} work; names not found in \code{df}
#'   are ignored with a warning.
#' @param range Numeric vector of length 2 specifying the range of the Likert scale
#'   (used to sanity-check the responses). Defaults to c(1, 5).
#'
#' @return A data frame with the calculated `REI`, the item columns used,
#'   `Percentile`, and a `Suspicious` flag (\code{"No"}, \code{"Maybe"},
#'   \code{"Yes"}; \code{NA} for a respondent without answers).
#' @references Tawa, J. (2021). The Response Entropy Index: Comparative
#'   assessment of performance and cultural bias across indices of careless
#'   responding. \emph{Survey Research Methods, 15}(3), 299--325.
#'   \doi{10.18148/srm/2021.v15i3.7832}
#' @export
#'
#' @examples
#' \donttest{
#' df <- data.frame(
#'   id = 1:6,
#'   q1 = c(1, 5, 3, 3, 2, 4), q2 = c(1, 1, 4, 3, 2, 5),
#'   q3 = c(1, 4, 3, 3, 5, 4), q4 = c(1, 2, 4, 3, 1, 5)
#' )
#' # select the item columns; the ID column is no response
#' result <- remove_outliers_REI(df, TRUE, c("q1", "q2", "q3", "q4"), c(1, 5))
#' result
#' }
remove_outliers_REI <- function(df, header = FALSE, variables = "", range = c(1, 5)) {
  not_empty(df)
  # Validate and parse variables: a single string is split at commas, a
  # character vector is used as it is, so both "var1,var2" and
  # c("var1", "var2") work.
  variables <- as.character(variables)
  variableNames <- if (length(variables) == 1L) {
    stringr::str_split(variables, ",")[[1]]
  } else {
    variables
  }
  variableNames <- unique(trimws(variableNames))
  variableNames <- variableNames[!is.na(variableNames) & nzchar(variableNames)]
  if (length(variableNames) == 0 && isTRUE(header)) {
    stop("Please input variables to consider!")
  }
  if (!is.numeric(range) || length(range) != 2 || range[1] > range[2]) {
    stop("`range` must be a numeric vector of length 2 with range[1] <= range[2].")
  }

  df <- as.data.frame(df)
  # Extract specified columns. Names are matched exactly: they used to be
  # pasted into a regular expression, so "G01Q01[SQ001]" matched nothing and
  # "q.1" also selected "qx1".
  if (isTRUE(header)) {
    not_found <- setdiff(variableNames, names(df))
    if (length(not_found) > 0) {
      warning(
        "Variable", if (length(not_found) > 1) "s" else "", " not found in `df` and ignored: ",
        paste0("'", not_found, "'", collapse = ", "), ".",
        call. = FALSE
      )
    }
    item_names <- intersect(variableNames, names(df))
  } else {
    item_names <- names(df)
  }
  items <- df[, item_names, drop = FALSE]

  # Check column count for validity
  if (ncol(items) < 2) {
    stop("Not enough columns found with the given phrase.")
  }

  # Columns that do not look like responses. With header = FALSE every column
  # is used, so an ID or timestamp column would silently count as an "item".
  is_num <- vapply(items, is.numeric, logical(1))
  if (!isTRUE(header) && any(!is_num)) {
    warning(
      "Non-numeric column", if (sum(!is_num) > 1) "s" else "", " ",
      paste0("'", names(items)[!is_num], "'", collapse = ", "),
      " entered the REI as response options: with `header = FALSE` every column ",
      "of `df` is used. Select the item columns with `header = TRUE` and `variables`.",
      call. = FALSE
    )
  }
  out_of_range <- vapply(items, function(v) {
    num <- suppressWarnings(as.numeric(if (is.factor(v)) as.character(v) else v))
    any(num < range[1] | num > range[2], na.rm = TRUE)
  }, logical(1))
  if (any(out_of_range)) {
    warning(
      "Responses outside the declared Likert `range` [", range[1], ", ", range[2],
      "] were found in ", paste0("'", names(items)[out_of_range], "'", collapse = ", "),
      "; they are still included in the REI computation.",
      if (!isTRUE(header)) " With `header = FALSE` every column of `df` is used, including ID columns." else "",
      call. = FALSE
    )
  }

  # Responses as text, so that 1 (double), 1L and factor level "1" are one
  # response option, and an NA stays missing.
  resp <- matrix(unlist(lapply(items, as.character), use.names = FALSE), nrow = nrow(items))
  answered <- rowSums(!is.na(resp))
  rei <- numeric(nrow(resp))
  for (option in unique(resp[!is.na(resp)])) {
    # proportion of the items this respondent *answered*, not of all items
    p <- rowSums(resp == option, na.rm = TRUE) / answered
    rei <- rei - ifelse(p > 0, p * log10(p), 0)
  }
  rei[answered == 0] <- NA_real_

  testDF <- data.frame(REI = rei, items, check.names = FALSE, stringsAsFactors = FALSE)

  # Calculate percentile and flag suspicious entries. With no spread in the
  # REI (every respondent gave the same pattern) the percentile is undefined:
  # pnorm() with sd = 0 returns 0 or 1, which flagged every row "Yes".
  rei_sd <- stats::sd(rei, na.rm = TRUE)
  if (is.na(rei_sd) || rei_sd < 1e-10) {
    warning(
      "All respondents have the same REI, so percentiles are undefined and no ",
      "row is flagged.",
      call. = FALSE
    )
    testDF$Percentile <- NA_real_
  } else {
    testDF$Percentile <- round(stats::pnorm(rei, mean = mean(rei, na.rm = TRUE), sd = rei_sd), digits = 2) * 100
  }
  testDF$Suspicious <- "No"
  testDF$Suspicious[which(testDF$Percentile <= 10 | testDF$Percentile >= 90)] <- "Maybe"
  testDF$Suspicious[which(testDF$Percentile <= 5 | testDF$Percentile >= 95)] <- "Yes"
  testDF$Suspicious[is.na(rei)] <- NA_character_

  return(testDF)
}
