#' Ensure input is not empty
#'
#' Stops execution if x is NULL, empty, or contains only NAs.
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

# Internal: render a variable/factor-level name for LaTeX. By default (option
# colleyRstats.name_macros = TRUE) an all-letters name is emitted as "\name" so
# the author can control its typography centrally via \newcommand (see
# emit_name_macros()); any name that is NOT a valid LaTeX command name (digits,
# underscores, spaces, ...) is emitted as escaped plain text instead, because
# "\tlx_mental" is itself an un-compilable control sequence. Setting the option
# to FALSE always emits escaped plain text.
.tex_name <- function(x) {
  use_macro <- isTRUE(getOption("colleyRstats.name_macros", TRUE))
  vapply(as.character(x), function(nm) {
    if (isTRUE(use_macro) && grepl("^[A-Za-z]+$", nm)) {
      paste0("\\", nm)
    } else {
      latex_escape(nm)
    }
  }, character(1), USE.NAMES = FALSE)
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
  rp("\\\\rankbiserial\\{([^{}]*)\\}", "$r_{rb} = \\1$")
  rp("\\\\effectsize\\{([^{}]*)\\}", "$r = \\1$")
  rp("\\\\chisq", "$\\\\chi^2$")
  x
}

# Internal: number formatting for reported statistics (fixed decimal places).
.fmt_num <- function(x, digits = 2) {
  sprintf(paste0("%.", digits, "f"), x)
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
    paste0("\\", macro, "{", .fmt_bounded(p, digits), "}")
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
#' @param data the data frame
#' @param x the x column
#' @param y the y column
#'
#' @return TRUE if all groups are normal, FALSE otherwise. The per-group
#'   Shapiro-Wilk statistics are attached as a data frame in the \code{"tests"}
#'   attribute (columns: group, \code{W}, \code{p_value}), e.g. for use in a
#'   methods section via [assumption_methods_text()]. For groups with more
#'   than 5000 non-missing values, Shapiro-Wilk is computed on a random sample of
#'   5000 observations (a warning is emitted); the returned value still reflects
#'   that sampled test. Because the sample is drawn randomly, results for such
#'   large groups are not reproducible unless a seed is set beforehand.
#' @export
check_normality_by_group <- function(data, x, y) {
  # Input validation
  if (missing(data) || missing(x) || missing(y)) stop("Missing arguments")
  .check_columns(data, c(x, y))

  # Ensure numeric
  if (!is.numeric(data[[y]])) {
    val <- as.numeric(data[[y]])
    if (all(is.na(val))) {
      return(FALSE)
    } # Non-numeric data
    data[[y]] <- val
  }

  # Count non-missing values so the sampling warning below fires exactly when
  # the Shapiro-Wilk branch actually samples (it tests na.omit()-ed values).
  group_sizes <- data |>
    dplyr::group_by(!!dplyr::sym(x)) |>
    dplyr::summarise(n = sum(!is.na(!!dplyr::sym(y))), .groups = "drop")

  results <- data |>
    dplyr::group_by(!!dplyr::sym(x)) |>
    dplyr::summarise(
      shapiro = list({
        values <- stats::na.omit(!!dplyr::sym(y))
        if (length(values) >= 3 && stats::var(values, na.rm = TRUE) > 0) {
          if (length(values) > 5000) {
            values <- sample(values, size = 5000)
          }
          tst <- stats::shapiro.test(values)
          c(W = unname(tst$statistic), p_value = tst$p.value)
        } else {
          c(W = NA_real_, p_value = NA_real_) # Cannot test
        }
      }),
      .groups = "drop"
    ) |>
    tidyr::unnest_wider("shapiro")

  if (any(group_sizes$n > 5000)) {
    warning("Groups with n > 5000 were tested using a random sample of 5000 observations.", call. = FALSE)
  }

  # If any group is significant (p < 0.05), data is NOT normal
  all_normal <- !any(results$p_value < 0.05, na.rm = TRUE)

  attr(all_normal, "tests") <- as.data.frame(results)
  return(all_normal)
}


#' Check homogeneity of variances across groups
#'
#' @param data the data frame
#' @param x the grouping variable (column name as string)
#' @param y the dependent variable (column name as string)
#'
#' @return TRUE if Levene's test is non-significant (p >= .05), FALSE otherwise.
#'   The Levene test result (columns \code{df1}, \code{df2}, \code{statistic},
#'   \code{p}) is attached in the \code{"test"} attribute, e.g. for use in a
#'   methods section via [assumption_methods_text()].
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

  formula_string <- paste(y, "~", x)
  levene_res <- rstatix::levene_test(
    data    = data,
    formula = stats::as.formula(formula_string)
  )

  # rstatix::levene_test returns a tibble with column 'p'
  p_val <- levene_res$p[1L]

  result <- if (is.na(p_val)) FALSE else p_val >= 0.05
  attr(result, "test") <- as.data.frame(levene_res)
  return(result)
}


#' Calculation based on Rosenthal's formula (1994). N stands for the *number of measurements*.
#'
#' @param wilcoxModel the Wilcox model
#' @param N number of measurements in the experiment
#'
#' @return Invisibly returns a list with components:
#'   \itemize{
#'     \item \code{r}: effect size as a numeric scalar.
#'     \item \code{z}: corresponding z-statistic.
#'     \item \code{text}: character string that is also sent to the console.
#'   }
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

  z <- stats::qnorm(wilcoxModel$p.value / 2)
  # Report the magnitude: z is derived from a two-sided p-value and is always
  # negative, so the raw quotient would spuriously report a negative effect
  # size regardless of the true direction.
  r <- abs(z / sqrt(N))

  msg <- sprintf(
    "%s Effect Size, r = %.3f, z = %.3f",
    wilcoxModel$data.name, r, z
  )
  message(msg)

  invisible(list(r = r, z = z, text = msg))
}

#' rFromWilcoxAdjusted
#'
#' @param wilcoxModel the Wilcox model
#' @param N number of measurements in the experiment
#' @param adjustFactor ad adjustment factor
#'
#' @return Invisibly returns a list with components:
#'   \itemize{
#'     \item \code{r}: adjusted effect size as a numeric scalar.
#'     \item \code{z}: adjusted z-statistic.
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
#' rFromWilcoxAdjusted(w, N = nrow(d), adjustFactor = 2)
#' }
rFromWilcoxAdjusted <- function(wilcoxModel, N, adjustFactor) {
  not_empty(wilcoxModel)
  not_empty(N)
  not_empty(adjustFactor)

  # An adjusted p-value (e.g. Bonferroni-style p * factor) can exceed 1, and
  # qnorm() would then return NaN; probabilities are capped at 1.
  adjusted_p <- min(wilcoxModel$p.value * adjustFactor, 1)
  z <- stats::qnorm(adjusted_p / 2)
  # Report the magnitude: z is derived from a two-sided p-value and is always
  # negative, so the raw quotient would spuriously report a negative effect
  # size regardless of the true direction.
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
#' Necessary LaTeX command:
#' \code{\\newcommand{\\effectsize}{\\textit{r=}}}
#'
#' @param pvalue p value
#' @param N number of measurements in the experiment
#'
#' @return Invisibly returns a list with components:
#'   \itemize{
#'     \item \code{r}: effect size as a numeric scalar.
#'     \item \code{z}: corresponding z-statistic.
#'     \item \code{text}: LaTeX-formatted character string that is also sent
#'       to the console.
#'   }
#' @export
#'
#' @examples rFromNPAV(0.02, N = 180)
rFromNPAV <- function(pvalue, N) {
  not_empty(pvalue)
  not_empty(N)

  z <- qnorm(pvalue / 2)
  # Report the magnitude: z is derived from a two-sided p-value and is always
  # negative, so the raw quotient would spuriously report a negative effect
  # size regardless of the true direction.
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
  var_mode <- sapply(dat, mode)
  if (any(var_mode %in% c("complex", "raw"))) stop("complex or raw not allowed!")
  var_class <- sapply(dat, class)
  if (any(var_mode[var_class == "AsIs"] %in% c("logical", "character"))) {
    stop("matrix variables with 'AsIs' class must be 'numeric'")
  }
  ind1 <- which(var_mode %in% c("logical", "character"))
  dat[ind1] <- lapply(dat[ind1], as.factor)
  ## step 3
  fctr <- which(sapply(dat, is.factor))
  if (length(fctr) == 0L) warning("no factor variables to summary")
  ind2 <- if (length(ind1) > 0L) fctr[-ind1] else fctr
  dat[ind2] <- lapply(dat[ind2], base::droplevels.factor)
  ## step 4
  lev <- lapply(dat[fctr], base::levels.default)
  nl <- lengths(lev)
  ## return
  list(nlevels = nl, levels = lev)
}


#' Check the assumptions for an ANOVA with a variable number of factors: Normality and Homogeneity of variance assumption.
#'
#' @param data the data frame
#' @param y The dependent variable for which assumptions should be checked
#' @param factors A character vector of factor names
#'
#' @return A message indicating whether to use parametric or non-parametric ANOVA
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
#' }
checkAssumptionsForAnova <- function(data, y, factors) {
  # Ensure data and variables are not empty
  not_empty(data)
  not_empty(y)
  not_empty(factors)
  .check_columns(data, c(y, factors))

  if (!requireNamespace("rstatix", quietly = TRUE)) {
    stop("Package 'rstatix' is required for checkAssumptionsForAnova(). Please install it.")
  }

  emit_guidance <- function(text) {
    message(text)
    invisible(text)
  }

  extract_p_value <- function(test_result) {
    if ("p" %in% names(test_result)) {
      return(test_result$p)
    }
    if ("p.value" %in% names(test_result)) {
      return(test_result$p.value)
    }
    NA_real_
  }

  # Dynamically construct the formula based on the number of factors
  formula_string <- paste(y, "~", paste(factors, collapse = " * "))
  model <- lm(as.formula(formula_string), data = data)

  # Shapiro-Wilk test of normality on model residuals
  model_results <- rstatix::shapiro_test(stats::residuals(model))
  model_p <- extract_p_value(model_results)
  if (!is.na(model_p) && model_p < 0.05) {
    return(emit_guidance("You must take the non-parametric ANOVA as model is non-normal."))
  }

  # Check normality for each group
  test <- data |>
    dplyr::group_by(dplyr::across(dplyr::all_of(factors))) |>
    rstatix::shapiro_test(!!rlang::sym(y))

  # Check if the normality assumption holds (p >= 0.05 for all groups)
  test_p <- extract_p_value(test)
  if (all(is.na(test_p))) {
    return(emit_guidance("Group-wise normality could not be assessed (e.g., too few observations per group). Take the non-parametric ANOVA to be safe."))
  }
  if (min(test_p, na.rm = TRUE) < 0.05) {
    return(emit_guidance("You must take the non-parametric ANOVA as normality assumption by groups is violated (one or more p < 0.05)."))
  }

  # Homogeneity of variance assumption using Levene's Test
  levene_formula <- as.formula(paste(y, "~", paste(factors, collapse = " * ")))
  levene_test_result <- rstatix::levene_test(data, levene_formula)
  levene_p <- extract_p_value(levene_test_result)

  if (!is.na(levene_p) && levene_p < 0.05) {
    return(emit_guidance("You must take the non-parametric ANOVA as Levene's test is significant (p < 0.05)."))
  }

  emit_guidance("You may take parametric ANOVA (function anova_test). See https://www.datanovia.com/en/lessons/anova-in-r/#check-assumptions-1 for more information.")
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

  # Extract the custom "ID" column
  id_column <- df |> dplyr::select(dplyr::all_of(id_col))

  # Sections are the runs of columns between marker columns (markers
  # themselves are dropped); section 0 holds any columns before the first
  # marker. Empty runs (adjacent markers) are discarded.
  data_columns <- setdiff(names(df), id_col)
  is_marker <- startsWith(data_columns, marker)
  section_id <- cumsum(is_marker)
  section_cols <- split(data_columns[!is_marker], section_id[!is_marker])
  section_cols <- Filter(length, section_cols)

  if (length(section_cols) == 0) {
    long_df <- dplyr::bind_cols(id_column, df |> dplyr::select(-dplyr::all_of(id_col)))
  } else {
    widths <- lengths(section_cols)
    if (length(unique(widths)) > 1) {
      stop(
        "All sections delimited by marker '", marker,
        "' must contain the same number of columns; found section widths: ",
        paste(widths, collapse = ", "), "."
      )
    }

    base_names <- c(id_col, section_cols[[1]])
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


#' Add `PARETO_EMOA` Column to a Data Frame
#'
#' This function calculates the Pareto front using emoa for a given set of objectives in a data frame and adds a new column, `PARETO_EMOA`, which indicates whether each row in the data frame belongs to the Pareto front.
#'
#' @param data A data frame containing the data, including the objective columns.
#' @param objectives A character vector specifying the names of the objective columns in `data`. These columns should be numeric and will be used to calculate the Pareto front.
#'
#' @return A data frame with the same columns as `data`, along with an additional column, `PARETO_EMOA`, which is `TRUE` for rows that are on the Pareto front and `FALSE` otherwise.
#' @export
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
#' # Add the Pareto front column
#' main_df <- add_pareto_emoa_column(data = main_df, objectives)
#' head(main_df)
add_pareto_emoa_column <- function(data, objectives) {
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

  # emoa expects one point per matrix *column* (criteria in rows) and
  # minimises every criterion. is_dominated() flags each point directly, so no
  # error-prone float-equality matching against the front is needed.
  data$PARETO_EMOA <- !emoa::is_dominated(t(as.matrix(objective_data)))

  # Return the updated data frame
  return(data)
}


#' Add `PARETO_MOOCORE` Column to a Data Frame
#'
#' This function calculates the Pareto front using moocore for a given set of objectives in a data frame and adds a new column, `PARETO_MOOCORE`, which indicates whether each row in the data frame belongs to the Pareto front.
#'
#' @param data A data frame containing the data, including the objective columns.
#' @param objectives A character vector specifying the names of the objective columns in `data`. These columns should be numeric and will be used to calculate the Pareto front.
#'
#' @return A data frame with the same columns as `data`, along with an additional column, `PARETO_MOOCORE`, which is `TRUE` for rows that are on the Pareto front and `FALSE` otherwise.
#' @export
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
#' # Add the Pareto front column
#' main_df <- add_pareto_moocore_column(data = main_df, objectives)
#' head(main_df)
add_pareto_moocore_column <- function(data, objectives) {
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

  # If there's only one row, mark it as PARETO_EMOA directly
  if (nrow(objective_data) == 1) {
    data$PARETO_MOOCORE <- TRUE
    return(data)
  }

  # moocore::is_nondominated evaluates points directly based on a row x col matrix.
  # It automatically returns a logical vector matching the row indices.
  data$PARETO_MOOCORE <- moocore::is_nondominated(as.matrix(objective_data))

  # Return the updated data frame
  return(data)
}



#' Flag suspicious survey responses via the Response Entropy Index (REI)
#'
#' This function takes a data frame, optional header information, variables to consider,
#' and a range for a Likert scale. It then calculates the Response Entropy Index (REI)
#' and flags suspicious entries based on percentiles. Note that no rows are
#' removed; entries are only flagged via the `Suspicious` column.
#'
#' Missing responses are ignored when tallying answers. Responses outside the
#' declared Likert `range` trigger a warning (they often indicate mis-coded
#' data) but are still included in the REI computation.
#'
#' For more information on the REI method, refer to:
#' [Response Entropy Index Method](https://ojs.ub.uni-konstanz.de/srm/article/view/7832)
#'
#' @param df Data frame containing the data.
#' @param header Logical indicating if the data frame has a header. Defaults to FALSE.
#' @param variables Which variables to consider: either a single character
#'   string with names separated by commas (\code{"var1,var2"}) or a character
#'   vector (\code{c("var1", "var2")}).
#' @param range Numeric vector of length 2 specifying the range of the Likert scale
#'   (used to sanity-check the responses). Defaults to c(1, 5).
#'
#' @return A data frame with calculated REI, percentile, and a 'Suspicious' flag.
#' @export
#'
#' @examples
#' \donttest{
#' df <- data.frame(var1 = c(1, 2, 3), var2 = c(2, 3, 4))
#' result <- remove_outliers_REI(df, TRUE, "var1,var2", c(1, 5))
#' }
remove_outliers_REI <- function(df, header = FALSE, variables = "", range = c(1, 5)) {
  # Validate and parse variables; a character vector is collapsed so both
  # "var1,var2" and c("var1", "var2") work.
  variables <- paste(variables, collapse = ",")
  if (variables == "" && header == TRUE) {
    stop("Please input variables to consider!")
  }
  if (!is.numeric(range) || length(range) != 2 || range[1] > range[2]) {
    stop("`range` must be a numeric vector of length 2 with range[1] <= range[2].")
  }
  iniVariables <- stringr::str_split(variables, ",")
  variableNames <- unique(trimws(iniVariables[[1]]))

  # Initialize data frame for REI calculation
  testDF <- data.frame(REI = numeric(nrow(df)))

  # Extract specified columns
  if (header == FALSE) {
    testDF <- cbind(testDF, df)
  } else {
    for (i in variableNames) {
      columnMatches <- grep(paste("^", i, "$", sep = ""), colnames(df))
      if (length(columnMatches) > 0) {
        testDF <- cbind(testDF, df[, columnMatches])
      }
    }
  }

  # Check column count for validity
  if (NCOL(testDF) <= 2) {
    stop("Not enough columns found with the given phrase.")
  }

  # Calculate REI and related metrics
  numQuestions <- ncol(testDF) - 1
  getResponses <- function(df) {
    # NA responses are excluded from the tally; without na.rm a single NA
    # would poison the row's counts for every response option.
    recordedResponses <- unique(as.vector(as.matrix(df)))
    recordedResponses <- recordedResponses[!is.na(recordedResponses)]
    tallies <- sapply(recordedResponses, function(x) rowSums(df == x, na.rm = TRUE))
    return(tallies)
  }

  response_values <- suppressWarnings(as.numeric(as.vector(as.matrix(testDF[, -1]))))
  if (any(response_values < range[1] | response_values > range[2], na.rm = TRUE)) {
    warning(
      "Responses outside the declared Likert `range` [", range[1], ", ", range[2],
      "] were found; they are still included in the REI computation.",
      call. = FALSE
    )
  }

  tallies <- getResponses(testDF[, -1])
  proportions <- tallies / numQuestions
  logs <- proportions * log10(proportions)
  logs[is.na(logs)] <- 0
  testDF[, "REI"] <- rowSums(logs, na.rm = TRUE) * -1

  # Calculate percentile and flag suspicious entries
  testDF$Percentile <- round(stats::pnorm(testDF$REI, mean = mean(testDF$REI, na.rm = TRUE), sd = stats::sd(testDF$REI, na.rm = TRUE)), digits = 2) * 100
  testDF$Suspicious <- "No"
  testDF$Suspicious[testDF$Percentile <= 10 | testDF$Percentile >= 90] <- "Maybe"
  testDF$Suspicious[testDF$Percentile <= 5 | testDF$Percentile >= 95] <- "Yes"

  return(testDF)
}
