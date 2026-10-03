# Internal: write text to the clipboard when possible. clipr is a suggested
# package and clipboards are unavailable on headless systems (e.g. CI), so a
# missing clipboard degrades to a warning instead of an error.
.write_clipboard <- function(text) {
  if (!requireNamespace("clipr", quietly = TRUE) || !clipr::clipr_available()) {
    warning("Clipboard is not available; skipping clipboard output.", call. = FALSE)
    return(invisible(NULL))
  }
  clipr::write_clip(text)
  invisible(NULL)
}


# Internal: is an ANOVA-table term an interaction? R joins the factors of an
# interaction with ":" in every model it fits, so the raw term name answers it.
# The reporters used to rewrite ":" to " X", search the finished sentence for a
# capital "X", and then turn every whitespace-X in it into a times sign -- so a
# main effect called `UX` was reported as an interaction, and a dependent
# variable called "X position" came out as "on $\times$ \ position".
.term_is_interaction <- function(term) {
  grepl(":", as.character(term), fixed = TRUE)
}

# Internal: an ANOVA-table term rendered for a sentence. Each factor is rendered
# on its own with .tex_name() -- a `\Name` macro only where that is a safe new
# command, escaped text otherwise -- so `Video_Type` or `trial2` no longer become
# un-compilable control sequences, and the factors of an interaction are joined
# with a multiplication sign.
.term_label <- function(term) {
  parts <- trimws(strsplit(as.character(term), ":", fixed = TRUE)[[1]])
  parts <- parts[nzchar(parts)]
  paste(.tex_name(parts), collapse = " $\\times$ ")
}

# Internal: ", $\eta_{p}^{2}$ = 0.54, 95\% CI: [0.31, 0.68]" from an F test, or ""
# when no effect size can be derived. effectsize::F_to_eta2() defaults to
# `alternative = "greater"`, i.e. a one-sided interval whose upper bound is
# always 1.00; labelling that "95% CI" misstates it, so a two-sided interval is
# requested explicitly.
.eta2p_text <- function(f, df, df_error) {
  if (is.null(f) || length(f) == 0 || any(is.na(c(f, df, df_error))) ||
      !all(is.finite(c(f, df, df_error)))) {
    return("")
  }
  es <- tryCatch(
    as.data.frame(effectsize::F_to_eta2(
      f = f, df = df, df_error = df_error,
      ci = 0.95, alternative = "two.sided"
    )),
    error = function(e) NULL
  )
  if (is.null(es) || is.null(es$Eta2_partial) || is.na(es$Eta2_partial)) {
    return("")
  }
  out <- paste0(", $\\eta_{p}^{2}$ = ", .fmt_bounded(es$Eta2_partial))
  if (!is.null(es$CI_low) && !is.null(es$CI_high) &&
      !any(is.na(c(es$CI_low, es$CI_high)))) {
    out <- paste0(
      out, ", 95\\% CI: [", .fmt_bounded(es$CI_low), ", ",
      .fmt_bounded(es$CI_high), "]"
    )
  }
  out
}


#' Generate the Latex-text based on the NPAV by Lüpsen (see \url{https://www.uni-koeln.de/~luepsen/R/}).
#' Only significant main and interaction effects are reported.
#' P-values are rounded for the third digit and partial eta squared values,
#' with a two-sided 95% confidence interval, are provided when possible.
#' A term is reported as an interaction when its name contains \code{":"}.
#' Attention: the independent variables of the formula and the term specifying the participant must be factors (i.e., use as.factor()).
#'
#' Deprecated: `reportNPAV()` will be removed in a future release.
#' Use `reportART()` with ARTool instead.
#'
#' To easily copy and paste the results to your manuscript, the following commands must be defined in Latex:
#' \code{\\newcommand{\\F}[3]{$F({#1},{#2})={#3}$}}
#' \code{\\newcommand{\\p}{\\textit{p=}}}
#' \code{\\newcommand{\\pminor}{\\textit{p$<$}}}
#'
#' @param model the model of the np.anova
#' @param dv the name of the dependent variable that should be reported
#' @param write_to_clipboard whether to write to the clipboard
#' @param sink_to optional path of a \code{.tex} file to write the sentences to,
#'   so a manuscript can \code{\\input{}} them
#'
#' @return Invisibly returns the reported sentence(s) as a character vector;
#'   the text is also emitted via \code{message()}.
#' @export
#'
#' @examples
#' model <- data.frame(
#'   Df = c(1, 1, 10),
#'   `F value` = c(6.12, 5.01, NA),
#'   `Pr(>F)` = c(0.033, 0.045, NA),
#'   check.names = FALSE
#' )
#' rownames(model) <- c("Video", "gesture:eHMI", "Residuals")
#' reportNPAV(model, dv = "mental workload")

reportNPAV <- function(model, dv = "Testdependentvariable", write_to_clipboard = FALSE, sink_to = NULL) {
  .Deprecated(
    "reportART",
    msg = paste(
      "reportNPAV() is deprecated and will be removed in a future release.",
      "Use reportART() with ARTool instead."
    )
  )
  not_empty(model)
  not_empty(dv)
  dv_tex <- latex_escape(dv)

  if ("Pr(>F)" %!in% colnames(model)) {
    message(paste0("No column ``Pr(>F)'' was found. reportNPAV() expects the ANOVA table produced by np.anova(); consider reportART() with ARTool instead."))
  } else {
    if (!any(model$`Pr(>F)` < 0.05, na.rm = TRUE)) {
      no_effect_msg <- paste0("The NPAV found no significant effects on ", dv_tex, ". ")
      message(no_effect_msg)
      if (write_to_clipboard) {
        .write_clipboard(no_effect_msg)
      }
      if (!is.null(sink_to)) {
        .write_tex(no_effect_msg, sink_to)
      }
      return(invisible(no_effect_msg))
    } else {
      # there is a significant effect if any value is under 0.05
      # make the names accessible in a novel column (raw term names; whether a
      # term is an interaction is decided from its ":" below)
      model$descriptions <- trimws(rownames(model))

      # Collect every significant effect; the clipboard is written once at the
      # end so multiple effects do not overwrite each other.
      sentences <- character(0)

      for (i in seq_along(model$`Pr(>F)`)) {
        # Residuals have NA therefore, we need this double-check
        if (!is.na(model$`Pr(>F)`[i]) && model$`Pr(>F)`[i] < 0.05) {
          Fvalue <- model$`F value`[i] # raw value; rounded only for display
          numeratordf <- model$Df[i]

          # denominator is the next row whose p-value is NA (the residual row).
          # Reset per iteration so we never reuse a previous effect's value or
          # hit an undefined object when no residual row follows this term.
          denominatordf <- NA_real_
          for (k in seq.int(i, length(model$`Pr(>F)`))) {
            if (is.na(model$`Pr(>F)`[k])) {
              denominatordf <- model$Df[k]
              break
            }
          }

          pValue <- .fmt_p_macro(model$`Pr(>F)`[i])

          effect_type <- if (.term_is_interaction(model$descriptions[i])) "interaction" else "main"
          stringtowrite <- paste0(
            "The NPAV found a significant ", effect_type, " effect of ",
            .term_label(model$descriptions[i]), " on ", dv_tex,
            " (\\F{", .fmt_df(numeratordf), "}{", .fmt_df(denominatordf), "}{",
            .fmt_num(Fvalue), "}, ", pValue
          )

          # Partial eta squared with a two-sided 95% CI (see .eta2p_text()); the
          # parenthetical is closed whether or not one could be derived.
          stringtowrite <- paste0(
            stringtowrite,
            .eta2p_text(Fvalue, numeratordf, denominatordf),
            "). "
          )

          message(stringtowrite)
          sentences <- c(sentences, stringtowrite)
        }
      }

      if (write_to_clipboard && length(sentences) > 0) {
        .write_clipboard(paste(sentences, collapse = ""))
      }
      if (!is.null(sink_to) && length(sentences) > 0) {
        .write_tex(sentences, sink_to)
      }
      return(invisible(sentences))
    }
  }
  invisible(NULL)
}


#' Generate the Latex-text based on the ARTool (see \url{https://github.com/mjskay/ARTool}). The ART result must be piped into an anova().
#' Only significant main and interaction effects are reported.
#' P-values are rounded for the third digit. Each effect is accompanied by its
#' partial eta squared, derived from the F statistic and its degrees of freedom
#' with [effectsize::F_to_eta2()], and a two-sided 95% confidence interval.
#' A term is reported as an interaction when its name contains \code{":"}; each
#' factor name is rendered as a \code{\\Name} macro only when that is a safe new
#' LaTeX command, and as escaped text otherwise.
#' Attention: the independent variables of the formula and the term specifying the participant must be factors (i.e., use as.factor()).
#'
#' To easily copy and paste the results to your manuscript, the following commands must be defined in Latex:
#' \code{\\newcommand{\\F}[3]{$F({#1},{#2})={#3}$}}
#' \code{\\newcommand{\\p}{\\textit{p=}}}
#' \code{\\newcommand{\\pminor}{\\textit{p$<$}}}
#'
#' @param model the model of the art
#' @param dv the name of the dependent variable that should be reported
#' @param write_to_clipboard whether to write to the clipboard
#' @param sink_to optional path of a \code{.tex} file to write the sentences to,
#'   so a manuscript can \code{\\input{}} them
#'
#' @return Invisibly returns the reported sentence(s) as a character vector;
#'   the text is also emitted via \code{message()}.
#' @export
#'
#' @examples
#' \donttest{
#' if (requireNamespace("ARTool", quietly = TRUE)) {
#'   set.seed(123)
#'
#'   main_df <- data.frame(
#'     tlx_mental = stats::rnorm(80),
#'     Video      = factor(rep(c("A", "B"), each = 40)),
#'     gesture    = factor(rep(c("G1", "G2"), times = 40)),
#'     eHMI       = factor(rep(c("On", "Off"), times = 40)),
#'     UserID     = factor(rep(1:20, each = 4))
#'   )
#'
#'   art_model <- ARTool::art(
#'     tlx_mental ~ Video * gesture * eHMI +
#'       Error(UserID / (gesture * eHMI)),
#'     data = main_df
#'   )
#'
#'   model_anova <- stats::anova(art_model)
#'   reportART(model_anova, dv = "mental demand")
#' }
#' }
reportART <- function(model, dv = "Testdependentvariable", write_to_clipboard = FALSE, sink_to = NULL) {
  # Check that the model and dependent variable are not empty
  not_empty(model)
  not_empty(dv)
  dv_tex <- latex_escape(dv)

  # Check if the model has a "Pr(>F)" column
  if ("Pr(>F)" %!in% colnames(model)) {
    message(paste0("No column ``Pr(>F)'' was found."))
  } else {
    # Check if any p-values are significant
    if (!any(model$`Pr(>F)` < 0.05, na.rm = TRUE)) {
      message_to_write <- paste0("The ART found no significant effects on ", dv_tex, ". ")
      message(message_to_write)
      if (write_to_clipboard) {
        .write_clipboard(message_to_write)
      }
      if (!is.null(sink_to)) {
        .write_tex(message_to_write, sink_to)
      }
      return(invisible(message_to_write))
    } else {
      # Process significant effects. anova() on an ART model puts the term in
      # a "Term" column; a hand-built table may carry it in its first column
      # or only in the row names.
      model$descriptions <- if ("Term" %in% names(model)) {
        as.character(model$Term)
      } else if (is.character(model[[1]]) || is.factor(model[[1]])) {
        as.character(model[[1]])
      } else {
        rownames(model)
      }
      model$descriptions <- trimws(model$descriptions)

      # Collect every significant effect; the clipboard is written once at the
      # end so multiple effects do not overwrite each other.
      sentences <- character(0)

      # anova() names the F column "F value" for a between-only (lm) ART fit but
      # "F" for a mixed (lmer) one, so resolve it once instead of assuming.
      Fvalues <- .f_values(model)

      for (i in seq_along(model$`Pr(>F)`)) {
        if (!is.na(model$`Pr(>F)`[i]) && model$`Pr(>F)`[i] < 0.05) {
          # Raw values; rounding happens only at display time so the effect
          # size below is computed from the unrounded F statistic.
          Fvalue <- if (is.null(Fvalues)) NA_real_ else Fvalues[i]
          numeratordf <- model$Df[i]
          denominatordf <- model$Df.res[i]
          pValue <- .fmt_p_macro(model$`Pr(>F)`[i])

          # Partial eta squared with a two-sided 95% CI via
          # effectsize::F_to_eta2() (see .eta2p_text()).
          effect_size_text <- .eta2p_text(Fvalue, numeratordf, denominatordf)

          # An interaction is a term whose raw name contains ":".
          effect_type <- if (.term_is_interaction(model$descriptions[i])) "interaction" else "main"
          stringtowrite <- paste0(
            "The ART found a significant ",
            effect_type,
            " effect of ",
            .term_label(model$descriptions[i]),
            " on ",
            dv_tex,
            " (\\F{",
            .fmt_df(numeratordf),
            "}{",
            .fmt_df(denominatordf),
            "}{",
            .fmt_num(Fvalue),
            "}, ",
            pValue
          )

          # The parenthetical must always be closed -- previously the ")" was
          # only appended when an effect size was available, so a sentence
          # without one shipped unbalanced parentheses.
          stringtowrite <- paste0(stringtowrite, effect_size_text, "). ")

          message(stringtowrite)
          sentences <- c(sentences, stringtowrite)
        }
      }

      if (write_to_clipboard && length(sentences) > 0) {
        .write_clipboard(paste(sentences, collapse = ""))
      }
      if (!is.null(sink_to) && length(sentences) > 0) {
        .write_tex(sentences, sink_to)
      }
      return(invisible(sentences))
    }
  }
  invisible(NULL)
}


# nparLD 2.3.0 rewrote the object its `nparLD()` returns: the ANOVA-type
# statistic that older versions put in `$ANOVA.test` now sits in `$ATS` on an
# object of class `nparld_fit`. Both are keyed by effect name and carry the same
# `Statistic`, `df` and `p-value` columns, so either can be reported once it has
# been located.
.nparld_anova_table <- function(model) {
  tbl <- NULL
  if (is.list(model)) {
    for (nm in c("ANOVA.test", "ATS")) {
      if (!is.null(model[[nm]])) {
        tbl <- model[[nm]]
        break
      }
    }
  }
  if (is.null(tbl)) {
    stop(
      "`model` does not look like an nparLD model: it carries neither ",
      "`$ANOVA.test` (nparLD < 2.3.0) nor `$ATS` (nparLD >= 2.3.0). ",
      "Pass the object returned by nparLD::nparLD().",
      call. = FALSE
    )
  }
  as.data.frame(tbl)
}


#' Report the model produced by nparLD. The model provided must be the model generated by the command 'nparLD' \code{\link[nparLD]{nparLD}} (see \url{https://CRAN.R-project.org/package=nparLD}).
#'
#' Only significant main and interaction effects of the ANOVA-type statistic
#' (ATS) are reported, as \eqn{F(df, \infty)}{F(df, Inf)} with the estimated (fractional)
#' numerator degrees of freedom. P-values are rounded for the third digit. No
#' effect size is attached: the relative treatment effects 'nparLD' estimates
#' describe factor-level combinations, not the terms of the ATS table.
#' A term is reported as an interaction when its name contains \code{":"}.
#' Attention: the independent variables of the formula and the term specifying the participant must be factors (i.e., use as.factor()).
#'
#' To easily copy and paste the results to your manuscript, the following commands must be defined in Latex:
#' \code{\\newcommand{\\F}[3]{$F({#1},{#2})={#3}$}}
#' \code{\\newcommand{\\p}{\\textit{p=}}}
#' \code{\\newcommand{\\pminor}{\\textit{p$<$}}}
#' @param model the model
#' @param dv the dependent variable
#' @param write_to_clipboard whether to write to the clipboard
#' @param sink_to optional path of a \code{.tex} file to write the sentences to,
#'   so a manuscript can \code{\\input{}} them
#'
#' @return Invisibly returns the reported sentence(s) as a character vector;
#'   the text is also emitted via \code{message()}.
#' @export
#'
#' @examples \donttest{
#' if (requireNamespace("nparLD", quietly = TRUE)) {
#'   # Small toy data set for nparLD
#'   set.seed(123)
#'   example_data <- data.frame(
#'     Subject = factor(rep(1:10, each = 3)),
#'     Time    = factor(rep(c("T1", "T2", "T3"), times = 10)),
#'     # a rising trend over time, so there is something to report
#'     TLX1    = rep(c(45, 52, 61), times = 10) + stats::rnorm(30, sd = 4)
#'   )
#'
#'   # Fit nparLD model
#'   model <- nparLD::nparLD(TLX1 ~ Time, data = example_data, subject = "Subject")
#'
#'   # Report the nparLD result
#'   reportNparLD(model, dv = "TLX1")
#' }
#' }
reportNparLD <- function(model, dv = "Testdependentvariable", write_to_clipboard = FALSE, sink_to = NULL) {
  not_empty(model)
  not_empty(dv)
  dv_tex <- latex_escape(dv)

  # first retrieve relevant subset
  model <- .nparld_anova_table(model)

  if (!any(model$`p-value` < 0.05, na.rm = TRUE)) {
    no_effect_msg <- paste0("The nparLD analysis found no significant effects on ", dv_tex, ". ")
    message(no_effect_msg)
    if (write_to_clipboard) {
      .write_clipboard(no_effect_msg)
    }
    if (!is.null(sink_to)) {
      .write_tex(no_effect_msg, sink_to)
    }
    return(invisible(no_effect_msg))
  }

  # there is a significant effect if any value is under 0.05
  # make the names accessible in a novel column (raw term names; whether a
  # term is an interaction is decided from its ":" below)
  model$descriptions <- trimws(rownames(model))

  # Collect every significant effect; the clipboard is written once at the
  # end so multiple effects do not overwrite each other.
  sentences <- character(0)

  for (i in seq_along(model$`p-value`)) {
    # Residuals have NA therefore we need this double check
    if (!is.na(model$`p-value`[i]) && model$`p-value`[i] < 0.05) {
      Fvalue <- .fmt_num(model$`Statistic`[i])
      # The ATS numerator df is estimated from the data and is fractional
      # (e.g. 1.906913); rounding it to an integer misreports the test.
      numeratordf <- .fmt_df(model$df[i])

      pValue <- .fmt_p_macro(model$`p-value`[i])

      # The ATS is referred to an F distribution with infinite denominator df.
      # \F already wraps its arguments in $...$, so the infinity sign goes in
      # bare: "{$\infty$}" nested math mode and did not compile.
      effect_type <- if (.term_is_interaction(model$descriptions[i])) "interaction" else "main"
      stringtowrite <- paste0(
        "The nparLD analysis found a significant ", effect_type, " effect of ",
        .term_label(model$descriptions[i]), " on ", dv_tex,
        " (\\F{", numeratordf, "}{\\infty}{", Fvalue, "}, ", pValue, "). "
      )

      # No effect size is attached: nparLD's relative treatment effects belong
      # to factor-level combinations, not to a term of the ANOVA-type table.

      message(stringtowrite)
      sentences <- c(sentences, stringtowrite)
    }
  }

  if (write_to_clipboard && length(sentences) > 0) {
    .write_clipboard(paste(sentences, collapse = ""))
  }
  if (!is.null(sink_to) && length(sentences) > 0) {
    .write_tex(sentences, sink_to)
  }
  invisible(sentences)
}


#' Transform text from `report::report()` into LaTeX-friendly output.
#'
#' This function transforms the text output from `report::report()` by performing several substitutions
#' to prepare the text for LaTeX typesetting. Every LaTeX special character
#' (\code{\\ \{ \} $ & # _ % ^}) is escaped -- `report()` keeps variable and
#' level names such as `tlx_mental` verbatim -- `~`, `<` and `>` become
#' \code{$\\sim$}, \code{$<$} and \code{$>$}, and `R2` and `Rhat` become
#' \code{$R^2$} and \code{$\\hat{R}$}. Additionally, it provides options to:
#' \itemize{
#'   \item Omit bullet items marked as "non-significant" (when `only_sig = TRUE`).
#'   \item Remove a concluding note about standardized parameters (when `remove_std = TRUE`).
#'   \item Wrap bullet items in a LaTeX `itemize` environment or leave them as plain text (controlled by `itemize`).
#' }
#'
#' @param x Character vector or a single string containing the report text.
#' @param print_result Logical. If `TRUE` (default), the formatted text is printed to the console.
#' @param only_sig Logical. If `TRUE`, bullet items containing "non-significant" are omitted. Default is `FALSE`.
#' @param remove_std Logical. If `TRUE`, the final standardized parameters note is removed. Default is `FALSE`.
#' @param itemize Logical. If `TRUE` (default), bullet items are wrapped in a LaTeX `itemize` environment;
#'   otherwise the bullet markers are simply removed.
#'
#' @return A single string with the LaTeX-friendly formatted report text.
#' @export
#'
#' @examples
#' \donttest{
#' if (requireNamespace("report", quietly = TRUE)) {
#'   # Simple linear model on the iris dataset
#'   model <- stats::lm(
#'     Sepal.Length ~ Sepal.Width + Petal.Length,
#'     data = datasets::iris
#'   )
#'
#'   # Format the report output, showing only significant items, removing the
#'   # standard note, and wrapping bullet items in an itemize environment.
#'   report_text <- try(report::report(model), silent = TRUE)
#'   if (!inherits(report_text, "try-error")) {
#'     latexify_report(
#'       report_text,
#'       only_sig = TRUE,
#'       remove_std = TRUE,
#'       itemize = TRUE
#'     )
#'   }
#' }
#' }
latexify_report <- function(x,
                            print_result = TRUE,
                            only_sig = FALSE,
                            remove_std = FALSE,
                            itemize = TRUE) {
  # If x is a character vector of lines, collapse to a single string
  if (length(x) > 1) {
    x <- paste(x, collapse = "\n")
  }

  # Check for unparsed logical variables and warn the user
  if (grepl("[?]", x, fixed = TRUE)) {
    warning("The report text contains '[?]'. This usually happens when logical/boolean variables are used in the model. For `report::report()` to work optimally, ensure your variables are converted to factors (e.g., using `as.factor()`) before fitting the model.")
  }


  # Perform substitutions:
  #   1. Escape every LaTeX special in the raw text. report() keeps variable
  #      and level names verbatim ("tlx_mental", "cond_type [a]") and writes
  #      "p < .001", so escaping only % and ~ -- as this function used to --
  #      left subscript errors and inverted-exclamation glyphs in the document.
  #      "~", "<" and ">" are set aside first because they are rendered as math
  #      ($\sim$, $<$, $>$) rather than as latex_escape()'s text symbols.
  #   2. Replace "R2" with "$R^2$" and "Rhat" with "$\hat{R}$". This runs after
  #      escaping, so the markup it introduces is never escaped itself.
  # R2/Rhat use word boundaries so tokens such as "VAR2" are left alone.
  out <- x |>
    gsub("~", "\002", x = _, fixed = TRUE) |>
    gsub("<", "\003", x = _, fixed = TRUE) |>
    gsub(">", "\004", x = _, fixed = TRUE) |>
    latex_escape() |>
    gsub("\002", "$\\sim$", x = _, fixed = TRUE) |>
    gsub("\003", "$<$", x = _, fixed = TRUE) |>
    gsub("\004", "$>$", x = _, fixed = TRUE) |>
    gsub("\\bR2\\b", "$R^2$", x = _) |>
    gsub("\\bRhat\\b", "$\\\\hat{R}$", x = _)

  # Split into individual lines for processing
  lines <- strsplit(out, "\n")[[1]]

  # Prepare to reconstruct the report line-by-line. Lists grow in amortised
  # constant time when appended at the end, unlike repeated c() calls.
  new_lines <- list()
  bullet_block <- list() # temporary holder for bullet items
  in_bullet_block <- FALSE # flag to denote if we are collecting bullet items

  # Define a pattern to identify the standard note line
  std_pattern <- "Standardized parameters were obtained by fitting the model"

  flush_bullets <- function(new_lines, bullet_block) {
    c(new_lines, list("\\begin{itemize}"), bullet_block, list("\\end{itemize}"))
  }

  for (line in lines) {
    # Optionally remove the final standard note line
    if (remove_std && grepl(std_pattern, line, fixed = TRUE)) {
      next # Skip this line entirely
    }

    # Check if the line is a bullet candidate (i.e., starts with a dash)
    if (grepl("^\\s*-\\s+", line)) {
      # If only_sig==TRUE, skip bullet items that contain "non-significant"
      if (only_sig && grepl("non-significant", line, fixed = TRUE)) {
        next
      }

      if (itemize) {
        # Replace initial dash with LaTeX \item and add to bullet_block
        bullet_block[[length(bullet_block) + 1L]] <- sub("^\\s*-\\s+", "\\\\item ", line)
        in_bullet_block <- TRUE
      } else {
        # If not itemizing, simply remove the dash and add the line directly
        new_lines[[length(new_lines) + 1L]] <- sub("^\\s*-\\s+", "", line)
      }
    } else {
      # If we reach a non-bullet line while inside a bullet block,
      # flush the bullet block into the new_lines (if itemize is TRUE)
      if (in_bullet_block && itemize) {
        new_lines <- flush_bullets(new_lines, bullet_block)
        # Reset bullet block and flag
        bullet_block <- list()
        in_bullet_block <- FALSE
      }
      # Add the non-bullet line
      new_lines[[length(new_lines) + 1L]] <- line
    }
  }
  # At the end, if a bullet block is pending, flush it now
  if (in_bullet_block && itemize) {
    new_lines <- flush_bullets(new_lines, bullet_block)
  }

  # Re-combine the resulting lines into a single string.
  out <- paste(unlist(new_lines), collapse = "\n")

  # Optionally print to the console
  if (print_result) {
    message(out, "\n")
  }

  invisible(out)
}


#' Report the mean and standard deviation of a dependent variable for all levels of an independent variable rounded to the 2nd digit.
#'
#' Each level yields one line such as \code{A: \\m{4.21}, \\sd{1.03}}, with the
#' level name escaped for LaTeX. Written to \code{sink_to}, the lines are joined
#' into one compilable sentence ("A: ...; B: ...."). Until 0.3.0 every line was a
#' LaTeX comment (it began with a percent sign), so an \code{\\input{}} of the
#' file typeset nothing; \code{as_comment = TRUE} restores that form for notes
#' kept next to a manuscript.
#'
#' To easily copy and paste the results to your manuscript, the following commands must be defined in Latex:
#' \code{\\newcommand{\\m}{\\textit{M=}}}
#' \code{\\newcommand{\\sd}{\\textit{SD=}}}
#' @param data the data frame
#' @param iv the independent variable
#' @param dv the dependent variable
#' @param sink_to optional path of a \code{.tex} file to write the lines to,
#'   so a manuscript can \code{\\input{}} them
#' @param as_comment if \code{TRUE}, every line is prefixed with a percent
#'   sign (a LaTeX comment) and written one per line, as before 0.3.0.
#'   Defaults to \code{FALSE}: real text.
#'
#' @return Invisibly returns the formatted lines (one per level) as a character
#'   vector; the text is also emitted via \code{message()}.
#' @export
#'
#' @examples \donttest{
#'
#' example_data <- data.frame(Condition = rep(c("A", "B", "C"),
#' each = 10), TLX1 = stats::rnorm(30))
#'
#' reportMeanAndSD(example_data, iv = "Condition", dv = "TLX1")
#' }
reportMeanAndSD <- function(data, iv = "testiv", dv = "testdv", sink_to = NULL, as_comment = FALSE) {
  not_empty(data)
  not_empty(iv)
  not_empty(dv)
  .check_columns(data, c(iv, dv))

  test <- data |>
    tidyr::drop_na(!!rlang::sym(iv)) |>
    tidyr::drop_na(!!rlang::sym(dv)) |>
    dplyr::group_by(!!rlang::sym(iv)) |>
    dplyr::summarise(dplyr::across(!!rlang::sym(dv), list(mean = mean, sd = stats::sd)))

  # Level names are user data and are escaped like every other label; the
  # lines carry no trailing newline (it used to be doubled by message() and by
  # the file writer, which also prefixed every line with "%" so nothing was
  # typeset).
  lines <- paste0(
    if (isTRUE(as_comment)) "%" else "",
    latex_escape(as.character(test[[1]])),
    ": \\m{", .fmt_num(test[[2]]), "}, \\sd{", .fmt_num(test[[3]]), "}"
  )
  lines <- lines[seq_len(nrow(test))]
  for (line in lines) {
    message(line)
  }

  if (!is.null(sink_to) && length(lines) > 0) {
    body <- if (isTRUE(as_comment)) {
      lines
    } else {
      # one sentence: "A: ...; B: ...; C: ...."
      paste0(lines, c(rep(";", length(lines) - 1L), "."))
    }
    .write_tex(body, sink_to)
  }
  invisible(lines)
}


# Internal: a Bayes factor for display, inside math mode. Bayes factors span
# many orders of magnitude, so very large or very small ones are written as
# "1.23 \times 10^{5}" rather than as a long fixed-point number or as 0.00.
.fmt_bf <- function(bf) {
  if (is.na(bf) || !is.finite(bf) || bf <= 0) {
    return(as.character(bf))
  }
  if (bf >= 1000 || bf < 0.01) {
    ex <- floor(log10(bf))
    man <- bf / 10^ex
    if (round(man, 2) >= 10) {
      man <- man / 10
      ex <- ex + 1
    }
    return(paste0(.fmt_num(man), " \\times 10^{", ex, "}"))
  }
  # Below 1, two decimals are not two significant digits: 0.014 would print as
  # "0.01". Show at least two significant digits ("0.014", "0.050", "0.50").
  if (bf < 1) {
    return(.fmt_num(bf, max(2L, 1L - floor(log10(bf)))))
  }
  .fmt_num(bf)
}

# Internal: the sentence for a `type = "bayes"` ggstatsplot, which carries a
# Bayes factor (bf10) and no p-value. The verbal evidence category comes from
# effectsize::interpret_bf() with the Jeffreys (1961) scheme, named explicitly
# so a future change of that package's default cannot silently relabel it.
.bayes_factor_sentence <- function(bf10, method_tex, iv, dv_tex) {
  bf <- suppressWarnings(as.numeric(bf10)[1])
  if (length(bf) == 0 || is.na(bf)) {
    stop(
      "The plot's statistics carry neither a p-value nor a Bayes factor; ",
      "nothing can be reported.",
      call. = FALSE
    )
  }
  evidence <- as.character(effectsize::interpret_bf(bf, rules = "jeffreys1961"))
  paste0(
    "A Bayes factor analysis (", method_tex, ") found ", evidence,
    " an effect of ", .tex_name(iv), " on ", dv_tex,
    " ($\\mathrm{BF}_{10} = ", .fmt_bf(bf), "$). "
  )
}


#' Report statistical details for ggstatsplot.
#'
#' Writes the omnibus test of a \code{ggbetweenstats()}/\code{ggwithinstats()}
#' plot as a sentence, naming the test statsExpressions ran and the effect size
#' it produced. Rank-based tests are reported with their \eqn{\chi^2}{chi^2},
#' \emph{V} or \emph{W} statistic, t tests (including Yuen's trimmed-means
#' test) as \emph{t(df)}, and ANOVA-type tests as \emph{F(df1, df2)}. A plot
#' made with \code{type = "bayes"} carries a Bayes factor instead of a p-value;
#' it is reported as \eqn{BF_{10}} together with the evidence category of
#' Jeffreys (1961), as classified by [effectsize::interpret_bf()].
#'
#' @param p the object returned by ggwithinstats or ggbetweenstats
#' @param iv the independent variable
#' @param dv the dependent variable
#' @param write_to_clipboard whether to write to the clipboard
#' @param sink_to optional path of a \code{.tex} file to write the sentence to,
#'   so a manuscript can \code{\\input{}} it
#'
#' @return Invisibly returns the reported sentence(s) as a character vector;
#'   the text is also emitted via \code{message()}.
#' @export
#'
#' @examples \donttest{
#' library(ggstatsplot)
#' library(dplyr)
#'
#' # Generate a plot
#' plt <- ggbetweenstats(mtcars, am, mpg)
#'
#' reportggstatsplot(plt, iv = "am", dv = "mpg")
#' }
reportggstatsplot <- function(p, iv = "independent", dv = "Testdependentvariable", write_to_clipboard = FALSE, sink_to = NULL) {
  not_empty(p)
  not_empty(dv)
  not_empty(iv)

  stats <- ggstatsplot::extract_stats(p)$subtitle_data
  if (is.null(stats) || nrow(stats) == 0) {
    stop("The plot carries no subtitle statistics to report.", call. = FALSE)
  }
  # A Bayesian plot has one row per model parameter (all with the same Bayes
  # factor); every other type has a single row. Report the first.
  stats <- as.data.frame(stats)[1, , drop = FALSE]
  resultString <- ""

  stat_col <- function(nm) if (nm %in% names(stats)) stats[[nm]] else NULL

  dv_tex <- latex_escape(dv)
  # Some statsExpressions method names begin with an article of their own
  # ("A heteroscedastic one-way ANOVA for trimmed means"); prefixing ours
  # produced "A A heteroscedastic ...". Strip it before choosing ours.
  method_raw <- sub("^(an?|the)\\s+", "", trimws(as.character(stats$method)), ignore.case = TRUE)
  method_tex <- latex_escape(method_raw)
  article <- .indefinite_article(method_raw)

  p_raw <- suppressWarnings(as.numeric(stat_col("p.value")))
  if (length(p_raw) == 0 || is.na(p_raw)) {
    # type = "bayes" yields a Bayes factor and no p-value; .fmt_p_macro(NULL)
    # used to fail with "argument is of length zero".
    msg <- .bayes_factor_sentence(stat_col("bf10"), method_tex, iv, dv_tex)
    message(msg)
    if (write_to_clipboard) {
      .write_clipboard(msg)
    }
    if (!is.null(sink_to)) {
      .write_tex(msg, sink_to)
    }
    return(invisible(msg))
  }

  pValue <- .fmt_p_macro(p_raw)
  statistic <- .fmt_num(stats$statistic)

  # The effect size is named by the test, not by the branch we happen to be in:
  # a t-test gives Hedges' g, a Wilcoxon a rank-biserial r, a Friedman test
  # Kendall's W. Read the name statsExpressions supplies and render the matching
  # symbol, so the sentence cannot call an unbounded g an "r".
  effectTex <- .effect_size_tex(stat_col("effectsize"), stats$estimate)
  effectPart <- if (nzchar(effectTex)) paste0(", ", effectTex) else ""

  # Create String. Method names come from statsExpressions, which uses the
  # stats::*.test naming ("Wilcoxon rank sum test" for unpaired data, statistic
  # W; "Wilcoxon signed rank test" for paired data, statistic V) - match on
  # substrings so the "exact test" variants are covered as well.
  # Degrees of freedom are formatted for display: Greenhouse-Geisser corrected
  # and Welch-approximated dfs are fractional and would otherwise be printed at
  # full double precision (e.g. "F(1.80875305770353, 66.9238631350305)").
  # Rank-based tests carry no df column at all, so read it only if it is there
  # (a bare stats$df would warn about an uninitialised column).
  df_raw <- stat_col("df")
  df_disp <- .fmt_df(df_raw)
  df_error_disp <- .fmt_df(stat_col("df.error"))

  method <- as.character(stats$method)
  has_df_error <- !is.null(stat_col("df.error")) && !is.na(stat_col("df.error"))
  if (method %in% c("Kruskal-Wallis rank sum test", "Friedman rank sum test")) {
    resultString <- paste0("(\\chisq(", df_error_disp, ")=", statistic, ", ", pValue, effectPart, ")")
  } else if (method %in% c("Paired t-test", "Welch Two Sample t-test", "Student's t-test") ||
             ((grepl("t-test", method, fixed = TRUE) || grepl("Yuen", method, fixed = TRUE)) &&
              (is.null(df_raw) || is.na(df_raw)) && has_df_error)) {
    # Yuen's trimmed-means test is a t test too ("Yuen's test on trimmed means
    # for independent/dependent samples"); it used to fall through to the
    # generic "statistic=" branch, which also dropped its df.
    resultString <- paste0("(t(", df_error_disp, ")=", statistic, ", ", pValue, effectPart, ")")
  } else if (grepl("signed rank", method, fixed = TRUE)) {
    resultString <- paste0("(V=", statistic, ", ", pValue, effectPart, ")")
  } else if (grepl("rank sum test", method, fixed = TRUE) || method == "Mann-Whitney U test") {
    resultString <- paste0("(W=", statistic, ", ", pValue, effectPart, ")")
  } else if (!is.null(df_raw) && !is.na(df_raw)) {
    # ANOVA and similar tests with both df and df.error
    resultString <- paste0("(\\F{", df_disp, "}{", df_error_disp, "}{", statistic, "}, ", pValue, effectPart, ")")
  } else {
    # Fallback for other methods
    resultString <- paste0("(statistic=", statistic, ", ", pValue, effectPart, ")")
  }

  if (!isTRUE(p_raw < 0.05)) {
    msg <- paste0(article, " ", method_tex, " found no significant effects on ", dv_tex, " ", resultString, ". ")
  } else {
    msg <- paste0(article, " ", method_tex, " found a significant effect of ", .tex_name(iv), " on ", dv_tex, " ", resultString, ". ")
  }

  message(msg)
  if (write_to_clipboard) {
    .write_clipboard(msg)
  }
  if (!is.null(sink_to)) {
    .write_tex(msg, sink_to)
  }

  invisible(msg)
}


# ---- post-hoc helpers -------------------------------------------------------

# Internal: the levels of `iv` present in `data`, as character: factor levels
# in their declared order (unused ones dropped), otherwise the sorted values.
.iv_levels <- function(data, iv) {
  x <- data[[iv]]
  if (is.factor(x)) {
    levels(droplevels(x))
  } else {
    sort(unique(as.character(x[!is.na(x)])))
  }
}

# Internal: which two levels a pairwise-contrast label compares, as
# c(first, second), or NULL when it matches no pair (or more than one).
# FSA labels a comparison "A - B"; emmeans -- and so ARTool::art.con() --
# wraps a level containing "-", "+", "*" or "/" in parentheses
# ("Both - (Hand-only)") and prefixes all-numeric levels with the factor name
# ("mode1 - mode2"). Splitting the label on " - " handled neither (and breaks
# on any level that itself contains " - "), so every way of writing every
# ordered pair of levels is generated and the label is matched exactly.
.match_contrast_pair <- function(label, levels, prefix = NULL) {
  norm <- function(s) gsub("\\s+", " ", trimws(s))
  label <- norm(as.character(label))
  levels <- as.character(levels)
  spell <- function(l) {
    s <- c(l, if (!is.null(prefix)) paste0(prefix, l))
    norm(unique(c(s, paste0("(", s, ")"))))
  }
  hits <- list()
  for (a in levels) {
    for (b in levels) {
      if (identical(a, b)) next
      cand <- as.vector(outer(spell(a), spell(b), paste, sep = " - "))
      if (label %in% cand) hits[[length(hits) + 1L]] <- c(a, b)
    }
  }
  if (length(hits) == 1L) hits[[1L]] else NULL
}

# Internal: a multiplicity-correction name for a sentence or caption, from the
# spelling of whichever package applied it, or NULL when it is unknown. FSA
# records its method as "Holm", "Benjamini-Hochberg", ... or "No Adjustment";
# emmeans (and so art.con()) as "holm", "tukey", "fdr", ... or "none".
# Uncorrected p-values come back as "none", which .adjustment_is_none() and
# .posthoc_test_phrase() recognise.
.adjust_label <- function(adjust) {
  adjust <- .scalar_chr(adjust)
  if (is.null(adjust)) {
    return(NULL)
  }
  key <- tolower(adjust)
  if (grepl("^no(ne)?\\b", key)) {
    return("none")
  }
  known <- c(
    holm = "Holm", bonferroni = "Bonferroni", tukey = "Tukey",
    sidak = "Sidak", scheffe = "Scheffe", hochberg = "Hochberg",
    hommel = "Hommel", fdr = "Benjamini-Hochberg", bh = "Benjamini-Hochberg",
    by = "Benjamini-Yekutieli", "benjamini-yekuteli" = "Benjamini-Yekutieli",
    mvt = "multivariate-t", dunnettx = "Dunnett"
  )
  if (key %in% names(known)) unname(known[key]) else adjust
}

# Internal: the p-value macros for a (possibly) corrected p-value. Uncorrected
# p-values must not be labelled p_adj; an unknown correction keeps the p_adj
# macros these reporters have always used.
.p_macros <- function(adjust) {
  if (.adjustment_is_none(adjust)) c("p", "pminor") else c("padj", "padjminor")
}

# Internal: "auto" resolved to the descriptives that match a test.
#
# A post-hoc sentence says "A was significantly higher (M=..., SD=...) than B",
# so the numbers in it must describe the quantity the test compared. Rank-based
# tests (Dunn, Durbin-Conover, ART-C) compare (aligned) ranks, and their
# direction contradicts the means precisely when such tests are chosen --
# skewed data, outliers -- so they are accompanied by medians and IQRs. Yuen's
# test compares 20% trimmed means; t tests and Games-Howell compare means.
.resolve_descriptives <- function(descriptives, auto) {
  if (identical(descriptives, "auto")) auto else descriptives
}

# Internal: the 20% winsorized standard deviation that accompanies a 20%
# trimmed mean (Wilcox), via WRS2 -- the package ggstatsplot's robust tests
# themselves run on.
.winsorized_sd <- function(v, tr = 0.2) {
  if (length(v) < 2L) {
    return(NA_real_)
  }
  if (!requireNamespace("WRS2", quietly = TRUE)) {
    stop("Package 'WRS2' is required for trimmed-mean descriptives.", call. = FALSE)
  }
  sqrt(WRS2::winvar(v, tr = tr))
}

# Internal: per-level location ("loc") and dispersion ("disp") as a matrix
# with one row per level: mean/SD, median/IQR, or 20% trimmed mean/winsorized SD.
.describe_levels <- function(values, groups, levels, kind) {
  groups <- as.character(groups)
  out <- vapply(levels, function(l) {
    v <- values[!is.na(groups) & groups == l & !is.na(values)]
    if (length(v) == 0L) {
      return(c(NA_real_, NA_real_))
    }
    switch(kind,
      mean = c(mean(v), stats::sd(v)),
      median = c(stats::median(v), stats::IQR(v)),
      trimmed = c(mean(v, trim = 0.2), .winsorized_sd(v, tr = 0.2))
    )
  }, numeric(2))
  out <- t(matrix(out, nrow = 2L, dimnames = list(c("loc", "disp"), levels)))
  out
}

# Internal: descriptives as LaTeX, e.g. "\m{4.20}, \sd{1.10}".
.fmt_descriptives <- function(loc, disp, kind) {
  switch(kind,
    mean = paste0("\\m{", .fmt_num(loc), "}, \\sd{", .fmt_num(disp), "}"),
    median = paste0("\\mdn{", .fmt_num(loc), "}, \\iqr{", .fmt_num(disp), "}"),
    trimmed = paste0("$M_{t}$=", .fmt_num(loc), ", $SD_{w}$=", .fmt_num(disp))
  )
}

# Internal: per level, the statistic a post-hoc test compares, computed from
# the data: means, 20% trimmed means, mean ranks of the pooled ranking (Dunn),
# or sums of the ranks within each participant (Durbin-Conover, which needs
# `blocks` and complete blocks).
.direction_scores <- function(values, groups, levels, how, blocks = NULL) {
  keep <- !is.na(values) & !is.na(groups)
  values <- values[keep]
  groups <- as.character(groups)[keep]
  score <- switch(how,
    mean = values,
    trimmed = values,
    meanrank = rank(values),
    blockrank = stats::ave(values, as.character(blocks)[keep], FUN = rank)
  )
  fun <- switch(how,
    mean = mean,
    trimmed = function(v) mean(v, trim = 0.2),
    meanrank = mean,
    blockrank = sum
  )
  vapply(levels, function(l) {
    v <- score[groups == l]
    if (length(v) > 0L) fun(v) else NA_real_
  }, numeric(1))
}

# Internal: warn when the reported descriptives order two levels against the
# direction of the test. The sentence always follows the test; this flags a
# sentence whose numbers would contradict its own words, e.g. forced means
# beside a rank-based test on skewed data. `forced` says whether the caller
# chose the descriptives: only then is "auto" the remedy. Under "auto" the
# medians that accompany a rank-based test can still disagree with the mean
# ranks it compares, and the advice has to say that instead.
.check_descriptive_direction <- function(desc, first, second, first_higher, kind, test_label,
                                         forced = TRUE) {
  d <- desc[first, "loc"] - desc[second, "loc"]
  if (!is.na(d) && d != 0 && (d > 0) != first_higher) {
    what <- switch(kind,
      mean = "means", median = "medians", trimmed = "trimmed means"
    )
    hi <- if (first_higher) first else second
    lo <- if (first_higher) second else first
    remedy <- if (isTRUE(forced)) {
      "Use `descriptives = \"auto\"` to report the statistic the test compares."
    } else {
      paste0("The ", what, " are the descriptives that conventionally accompany this test, ",
             "but they summarise the data differently from what it compares (e.g. mean ",
             "ranks), and here the two disagree: say so in the text, or report the ",
             "statistic the test compares.")
    }
    warning(
      "The ", test_label, " finds '", hi, "' significantly higher than '", lo,
      "', but their ", what, " order them the other way round. The sentence ",
      "follows the test; its descriptives contradict it. ", remedy,
      call. = FALSE
    )
  }
  invisible(NULL)
}

# Internal: what a 'ggstatsplot' pairwise test compares (`how`, for the
# direction) and which descriptives match it (`auto`).
.ggstatsplot_test_profile <- function(test) {
  t <- .scalar_chr(test)
  t <- if (is.null(t)) "" else tolower(t)
  if (grepl("dunn", t, fixed = TRUE)) {
    return(list(how = "meanrank", auto = "median"))
  }
  if (grepl("durbin", t, fixed = TRUE) || grepl("conover", t, fixed = TRUE)) {
    return(list(how = "blockrank", auto = "median"))
  }
  if (grepl("yuen", t, fixed = TRUE) || grepl("trimmed", t, fixed = TRUE)) {
    return(list(how = "trimmed", auto = "trimmed"))
  }
  # Games-Howell, Student's t, and an unnamed (older/hand-built) table
  list(how = "mean", auto = "mean")
}

# Internal: TRUE when a 'ggstatsplot' omnibus test is a within-subjects one,
# judged by the method name statsExpressions gives it (FALSE when unknown).
.ggstatsplot_is_within <- function(p) {
  method <- tryCatch(
    as.character(ggstatsplot::extract_stats(p)$subtitle_data$method[1]),
    error = function(e) NA_character_
  )
  if (length(method) == 0L || is.na(method)) {
    return(FALSE)
  }
  # \b keeps "dependent samples" from matching inside "independent samples"
  # (Yuen's between-subjects test is "... for independent samples").
  grepl("afex|\\bpaired|friedman|signed rank|repeated measures|\\bdependent samples",
        method, ignore.case = TRUE, perl = TRUE)
}

# Internal: the observations a post-hoc test on a 'ggstatsplot' was computed
# on, as a data frame with columns .iv, .dv and (within-subjects) .block.
#
# ggwithinstats() drops every participant who is not observed in all levels of
# the factor before testing, so descriptives taken from all rows describe a
# different sample than the one tested. With `subject`, only participants
# observed in every level are kept, by the rule every within-subjects entry
# point shares (.complete_within(), utils.R): one row per participant and
# level is required. Without it, `pair_by_row = TRUE` reproduces
# ggwithinstats()'s own behaviour without `subject.id`: the i-th observation of
# each level forms a participant.
.posthoc_sample <- function(data, iv, dv, subject = NULL, pair_by_row = FALSE) {
  as_sample <- function(d, block = NULL) {
    out <- data.frame(.iv = as.character(d[[iv]]), .dv = d[[dv]], stringsAsFactors = FALSE)
    if (!is.null(block)) out$.block <- block
    out
  }

  if (!is.null(subject)) {
    d <- data[!is.na(data[[iv]]) & !is.na(data[[dv]]) & !is.na(data[[subject]]), , drop = FALSE]
    n_levels <- tapply(as.character(d[[iv]]), as.character(d[[subject]]),
                       function(v) length(unique(v)))
    if (all(n_levels <= 1L)) {
      .complete_within(d, subject, character(0), dv) # one row per participant
      message(
        "Every participant in `", subject, "` was observed in a single level of `",
        iv, "`: the design is between-subjects, so `subject` does not restrict ",
        "the sample."
      )
      return(as_sample(d))
    }
    kept <- .complete_within(d, subject, iv, dv)
    if (kept$n_subjects == 0L) {
      stop(
        "No participant was observed in every level of `", iv, "`, so no ",
        "within-subjects comparison can have been computed from `data`.",
        call. = FALSE
      )
    }
    return(as_sample(kept$data, as.character(kept$data[[subject]])))
  }

  x <- as_sample(data)
  x <- x[!is.na(x$.iv), , drop = FALSE]
  if (isTRUE(pair_by_row)) {
    x$.block <- as.character(stats::ave(seq_len(nrow(x)), x$.iv, FUN = seq_along))
  }
  x <- x[!is.na(x$.dv), , drop = FALSE]
  if (is.null(x$.block)) {
    return(x)
  }
  n_levels <- tapply(x$.iv, x$.block, function(v) length(unique(v)))
  x[x$.block %in% names(n_levels)[n_levels == length(unique(x$.iv))], , drop = FALSE]
}


#' Report significant post-hoc pairwise comparisons
#'
#' This function extracts significant pairwise comparisons from a `ggstatsplot` object,
#' describes the groups involved from the raw data, and prints LaTeX-formatted
#' sentences reporting the results.
#'
#' Each sentence names the post-hoc test that produced the comparison and the
#' multiplicity correction applied to its p-value, both read from the pairwise
#' table `ggstatsplot` attaches to the plot (e.g. "A Games-Howell post-hoc test
#' (Holm-adjusted) found that ..."). Which test that is depends on the `type`
#' of the plot and on whether it is between- or within-subjects -- Games-Howell,
#' Dunn, Durbin-Conover, Student's t or Yuen's trimmed means -- so it is worth
#' reporting rather than assuming. When the plot carries no such information
#' (an older `ggstatsplot`, or a hand-built table) the sentence falls back to a
#' plain "A post-hoc test ...".
#'
#' @section Direction and descriptives:
#' Which level "was significantly higher" is decided by the quantity the test
#' compares, computed from `data`: the means for Student's t and Games-Howell,
#' the mean ranks of the pooled ranking for Dunn, the within-participant rank
#' sums for Durbin-Conover, and the 20% trimmed means for Yuen's test (taken
#' from the sign of the `estimate` column of the pairwise table when it is
#' present). Until 0.3.0 the direction always came from the raw means, which
#' contradicts a rank-based test whenever outliers or skew pull a mean -- the
#' situation in which such a test is chosen.
#'
#' The descriptives printed beside each level match the test by default
#' (`descriptives = "auto"`): \code{\\m{}}/\code{\\sd{}} for the mean-based
#' tests, \code{\\mdn{}}/\code{\\iqr{}} for the rank-based ones, and the 20%
#' trimmed mean \eqn{M_t} with the 20% winsorized standard deviation
#' \eqn{SD_w} for Yuen's test. Any of these can be forced; a warning is given
#' when the forced descriptives order two levels against the test's direction.
#'
#' For a within-subjects plot pass `subject`: `ggwithinstats()` tests only the
#' participants observed in every level, and with `subject` the descriptives
#' (and the Durbin-Conover rank sums) are computed from exactly those
#' participants. Without it, all rows are described, and a Durbin-Conover
#' table pairs observations by row order within each level -- what
#' `ggwithinstats()` itself does without `subject.id` -- with a warning.
#'
#' @section LaTeX Requirements:
#' To easily copy and paste the results to your manuscript, the commands of
#' [latex_preamble()] (or the shipped \code{colleyRstats.sty}) must be defined:
#' \code{\\m}, \code{\\sd}, \code{\\mdn}, \code{\\iqr}, \code{\\padj},
#' \code{\\padjminor}, \code{\\p} and \code{\\pminor}.
#'
#' \code{\\p}/\code{\\pminor} are used only when the plot reports
#' `p.adjust.method = "None"`: those p-values are uncorrected and must not be
#' labelled \eqn{p_{adj}}.
#'
#' @param data A data frame containing the raw data used to generate the plot.
#' @param p A `ggstatsplot` object (e.g., returned by `ggbetweenstats`) containing the pairwise comparison statistics.
#' @param iv Character string. The column name of the independent variable (grouping variable).
#' @param dv Character string. The column name of the dependent variable.
#' @param label_mappings Optional named list or vector. Used to rename factor levels in the output text
#' (e.g., `list("old_name" = "New Label")`).
#' @param sink_to optional path of a \code{.tex} file to write the sentences to,
#'   so a manuscript can \code{\\input{}} them. It is written in every case,
#'   including when nothing is significant, so a manuscript never keeps a
#'   stale result.
#' @param descriptives which descriptives to print beside each level:
#'   \code{"auto"} (default; the ones matching the test, see Details),
#'   \code{"mean"} (\emph{M}, \emph{SD}), \code{"median"} (\emph{Mdn},
#'   \emph{IQR}) or \code{"trimmed"} (20% trimmed mean, 20% winsorized SD).
#' @param subject optional column name identifying participants in a
#'   within-subjects (`ggwithinstats()`) plot. When given, the descriptives and
#'   any direction statistic are computed only from participants observed in
#'   every level of `iv`, one row per participant and level.
#'
#' @return Invisibly returns the reported sentence(s) as a character vector;
#'   the text is also emitted via \code{message()}.
#' @export
#'
#' @examples
#' \donttest{
#' library(ggstatsplot)
#' library(dplyr)
#'
#' # Generate a plot (a factor with three levels, so there are pairwise tests)
#' plt <- ggbetweenstats(mtcars, cyl, mpg)
#'
#' # Report stats
#' reportggstatsplotPostHoc(
#'   data = mtcars,
#'   p = plt,
#'   iv = "cyl",
#'   dv = "mpg",
#'   label_mappings = list("4" = "four cylinders")
#' )
#' }
reportggstatsplotPostHoc <- function(data, p, iv = "testiv", dv = "testdv", label_mappings = NULL, sink_to = NULL,
                                     descriptives = c("auto", "mean", "median", "trimmed"), subject = NULL) {
  # Asserts to ensure non-empty inputs
  not_empty(data)
  not_empty(p)
  not_empty(iv)
  not_empty(dv)
  descriptives <- match.arg(descriptives)
  .check_columns(data, c(iv, dv, subject))
  # The dv is plain text here, as in every other reporter: .tex_name() would
  # turn a dv called `v` into the háček accent \v.
  dv_tex <- latex_escape(dv)

  # Extract stats from the ggstatsplot object
  stats <- attr(p, "pairwise_comparisons_data")
  # Fallback
  if (is.null(stats)) {
    stats <- ggstatsplot::extract_stats(p)$pairwise_comparisons_data
  }
  if (is.null(stats) || nrow(stats) == 0) {
    no_data_msg <- paste0("No pairwise comparison data found for ", dv, ". ")
    message(no_data_msg)
    # Not manuscript text, but the file is still overwritten (with a LaTeX
    # comment) so it cannot keep a result from an earlier run.
    if (!is.null(sink_to)) {
      .write_tex(paste0("% ", no_data_msg), sink_to)
    }
    return(invisible(NULL))
  }
  stats <- as.data.frame(stats)
  if (!"p.value" %in% names(stats)) {
    # A type = "bayes" plot carries Bayes factors and no p-values; reading the
    # missing column as "nothing significant" would report a falsehood.
    if ("bf10" %in% names(stats)) {
      stop(
        "The pairwise comparisons of this plot are Bayesian (type = \"bayes\"): ",
        "they carry Bayes factors, not p-values, so they cannot be reported as ",
        "significant or not. Use a frequentist plot type for post-hoc tests.",
        call. = FALSE
      )
    }
    stop("The pairwise comparison table carries no `p.value` column.", call. = FALSE)
  }

  # Which post-hoc test produced these p-values, and under which multiplicity
  # correction. `ggstatsplot` reports both in the pairwise table; an older
  # version or a hand-built table may not, and then the phrasing stays generic.
  test_col <- if ("test" %in% names(stats)) stats$test else NULL
  adjust_col <- if ("p.adjust.method" %in% names(stats)) stats$p.adjust.method else NULL

  if (!any(stats$p.value < 0.05, na.rm = TRUE)) {
    # Written to sink_to as well: returning early used to leave whatever an
    # earlier run had written there, so a manuscript could keep reporting a
    # significant difference that no longer exists.
    no_diff_msg <- paste0(
      .posthoc_test_phrase(test_col, adjust_col),
      " found no significant differences for ", dv_tex, ". "
    )
    message(no_diff_msg)
    if (!is.null(sink_to)) {
      .write_tex(no_diff_msg, sink_to)
    }
    return(invisible(no_diff_msg))
  }

  # What the test compares decides both the direction of each sentence and,
  # under descriptives = "auto", the descriptives printed beside it.
  profile <- .ggstatsplot_test_profile(test_col)
  kind <- .resolve_descriptives(descriptives, profile$auto)
  needs_blocks <- identical(profile$how, "blockrank")
  if (needs_blocks && is.null(subject)) {
    warning(
      "The Durbin-Conover test compares ranks within participants, but no ",
      "`subject` was given: observations are paired by their row order within ",
      "each level of `", iv, "`, as ggwithinstats() does without `subject.id`. ",
      "Pass `subject` to pair them by the participant column.",
      call. = FALSE
    )
  }
  # Equal row counts per level do not show that every participant is complete
  # (13 rows per level can come from 11 complete participants and two partial
  # ones), so the warning does not wait for unequal counts.
  if (!needs_blocks && is.null(subject) && .ggstatsplot_is_within(p)) {
    warning(
      "This is a within-subjects plot, but no `subject` was given: ggwithinstats() ",
      "tests only the participants observed in every level of `", iv, "`, while ",
      "without `subject` the descriptives are computed from all rows, which can ",
      "include participants the test never saw. Pass `subject`.",
      call. = FALSE
    )
  }
  smp <- .posthoc_sample(data, iv, dv, subject = subject, pair_by_row = needs_blocks)
  levs <- intersect(.iv_levels(data, iv), unique(smp$.iv))
  desc <- .describe_levels(smp$.dv, smp$.iv, levs, kind)
  scores <- .direction_scores(smp$.dv, smp$.iv, levs, profile$how, blocks = smp$.block)
  # Yuen's test reports its estimate (group1 - group2: the difference of the
  # trimmed means between subjects, the trimmed mean of the differences within
  # subjects), so its sign is the test's own direction.
  use_estimate <- identical(profile$how, "trimmed") && "estimate" %in% names(stats)

  # Map a raw factor level to its display label; falls back to the raw level
  # when no mapping is supplied or the level is missing from the mapping
  # (otherwise a NULL/NA entry would silently vanish inside paste0()).
  map_label <- function(condition) {
    # group levels may arrive as factors; [[ on a list indexed by a factor
    # would use the underlying integer code instead of the label
    condition <- as.character(condition)
    if (is.null(label_mappings)) {
      return(condition)
    }
    mapped <- if (is.list(label_mappings)) label_mappings[[condition]] else unname(label_mappings[condition])
    if (is.null(mapped) || length(mapped) == 0 || is.na(mapped)) condition else mapped
  }

  sentences <- character(0)

  for (i in seq_along(stats$p.value)) {
    if (!is.na(stats$p.value[i]) && stats$p.value[i] < 0.05) {
      # Format p-value. A table that explicitly reports "None" as its
      # correction carries raw p-values, which must not be labelled p_adj; an
      # absent column says nothing either way, so p_adj stays the default.
      rowAdjust <- .scalar_chr(adjust_col[i])
      unadjusted <- .adjustment_is_none(rowAdjust)
      pValue <- .fmt_p_macro(
        stats$p.value[i],
        macro = if (unadjusted) "p" else "padj",
        minor_macro = if (unadjusted) "pminor" else "padjminor"
      )

      # Get conditions
      firstCondition <- as.character(stats$group1[i])
      secondCondition <- as.character(stats$group2[i])
      if (!all(c(firstCondition, secondCondition) %in% levs)) {
        stop(
          "The pairwise table compares '", firstCondition, "' and '",
          secondCondition, "', but `data` has no observations of both in `",
          iv, "`. Pass the data the plot was made from.",
          call. = FALSE
        )
      }

      firstLabel <- latex_escape(map_label(firstCondition))
      secondLabel <- latex_escape(map_label(secondCondition))

      # Name the post-hoc test (e.g. "Games-Howell", "Dunn") and the correction
      # it was adjusted with, so each sentence stands on its own about which
      # test produced the p-value it reports.
      testName <- paste0(.posthoc_test_phrase(test_col[i], rowAdjust), " found that ")
      test_label <- .scalar_chr(test_col[i])
      test_label <- if (is.null(test_label)) "post-hoc test" else paste(test_label, "test")

      # Format statistics. These are built WITHOUT the closing parenthesis so
      # each use site can decide what goes inside it: the first parenthetical
      # closes immediately, while the second also carries the p-value. (It used
      # to close here and have a second ")" appended after the p-value, which
      # produced "...\sd{1.62}); \padj{0.001})." -- unbalanced, and the p-value
      # sat outside the parentheses it belonged to.)
      firstStats <- paste0(" (", .fmt_descriptives(desc[firstCondition, "loc"], desc[firstCondition, "disp"], kind))
      secondStats <- paste0(" (", .fmt_descriptives(desc[secondCondition, "loc"], desc[secondCondition, "disp"], kind))

      # The direction comes from what the test compared (see profile above),
      # never from the raw means: a Dunn test on skewed data can find the level
      # with the larger mean significantly LOWER.
      diff <- if (use_estimate) {
        suppressWarnings(as.numeric(stats$estimate[i]))
      } else {
        scores[[firstCondition]] - scores[[secondCondition]]
      }

      sentence <- if (is.na(diff) || diff == 0) {
        warning(
          "The direction of the difference between '", firstCondition, "' and '",
          secondCondition, "' could not be determined from `data`; it is ",
          "reported without one.",
          call. = FALSE
        )
        paste0(testName, firstLabel, firstStats, ") and ", secondLabel, secondStats, "; ", pValue, ") differed significantly in terms of ", dv_tex, ". ")
      } else {
        first_higher <- diff > 0
        .check_descriptive_direction(desc, firstCondition, secondCondition, first_higher, kind, test_label,
                                     forced = !identical(descriptives, "auto"))
        if (first_higher) {
          paste0(testName, firstLabel, " was significantly higher", firstStats, ")", " in terms of ", dv_tex, " compared to ", secondLabel, secondStats, "; ", pValue, "). ")
        } else {
          paste0(testName, secondLabel, " was significantly higher", secondStats, ")", " in terms of ", dv_tex, " compared to ", firstLabel, firstStats, "; ", pValue, "). ")
        }
      }
      message(sentence)
      sentences <- c(sentences, sentence)
    }
  }

  if (!is.null(sink_to) && length(sentences) > 0) {
    .write_tex(sentences, sink_to)
  }
  invisible(sentences)
}


#' Report dunnTest as text
#'
#' Reports the significant comparisons of an [FSA::dunnTest()] result as
#' sentences such as "A Dunn post-hoc test (Holm-adjusted) found that ... for
#' the Species virginica was significantly higher (Mdn=..., IQR=...) than for
#' setosa (Mdn=..., IQR=...; p_adj<.001, r_rb=...)". The multiplicity
#' correction is read from the test object; with `method = "none"` the
#' p-values are uncorrected and are emitted as \code{\\p{}}/\code{\\pminor{}},
#' not as \eqn{p_{adj}}.
#'
#' Which level is "higher" follows the sign of the test's \eqn{Z} (FSA labels a
#' comparison "A - B"; \eqn{Z > 0} means A has the higher mean rank). Until 0.3.0
#' it followed the raw means, which can point the other way: with a few large
#' outliers a level can have the larger mean but the significantly lower mean
#' rank. As a consistency check, the mean ranks are recomputed from `data` and
#' a warning is given when they disagree with \eqn{Z} (i.e. when `data` is not
#' the data the test was computed on).
#'
#' By default (`descriptives = "auto"`) each level is described by its median
#' and IQR, the location measure that matches a rank-based test; `"mean"`
#' restores \emph{M}/\emph{SD} and warns where the means order two levels
#' against the test.
#'
#' Required commands in LaTeX (all part of [latex_preamble()]):
#' \code{\\padj}, \code{\\padjminor}, \code{\\p}, \code{\\pminor},
#' \code{\\mdn}, \code{\\iqr}, \code{\\m}, \code{\\sd} and
#' \code{\\newcommand{\\rankbiserial}[1]{$r_{rb} = #1$}}.
#'
#' @param d the dunn test object
#' @param data the data frame
#' @param iv independent variable
#' @param dv dependent variable
#' @param sink_to optional path of a \code{.tex} file to write the sentences to,
#'   so a manuscript can \code{\\input{}} them
#' @param descriptives which descriptives to print beside each level:
#'   \code{"auto"} (default, median and IQR for this rank-based test),
#'   \code{"mean"}, \code{"median"} or \code{"trimmed"} (20% trimmed mean and
#'   20% winsorized SD).
#'
#' @return Invisibly returns the reported sentence(s) as a character vector;
#'   the text is also emitted via \code{message()}.
#' @export
#'
#' @examples
#' \donttest{
#' if (requireNamespace("FSA", quietly = TRUE)) {
#'   # Use built-in iris data
#'   data(iris)
#'
#'   # Dunn test on Sepal.Length by Species
#'   d <- FSA::dunnTest(Sepal.Length ~ Species,
#'     data   = iris,
#'     method = "holm"
#'   )
#'
#'   # Report the Dunn test
#'   reportDunnTest(d,
#'     data = iris,
#'     iv   = "Species",
#'     dv   = "Sepal.Length"
#'   )
#' }
#' }
reportDunnTest <- function(d, data, iv = "testiv", dv = "testdv", sink_to = NULL,
                           descriptives = c("auto", "mean", "median", "trimmed")) {
  not_empty(data)
  not_empty(d)
  not_empty(iv)
  not_empty(dv)
  .check_columns(data, c(iv, dv))
  descriptives <- match.arg(descriptives)
  dv_tex <- latex_escape(dv)

  # The correction FSA applied ("Holm", ..., "No Adjustment"). A hand-built
  # list without `method` says nothing either way and keeps the p_adj macros.
  adjust <- .adjust_label(d$method)
  p_macro <- .p_macros(adjust)
  phrase <- .posthoc_test_phrase("Dunn", adjust)

  # Check for significance globally first
  # Note: d$res$P.adj can contain NAs, so we remove them for the check
  if (!any(d$res$P.adj < 0.05, na.rm = TRUE)) {
    no_diff_msg <- paste0(phrase, " found no significant differences for ", dv_tex, ". ")
    message(no_diff_msg)
    if (!is.null(sink_to)) {
      .write_tex(no_diff_msg, sink_to)
    }
    return(invisible(no_diff_msg))
  }

  # The observations the test ranked: every row with both iv and dv present.
  keep <- !is.na(data[[iv]]) & !is.na(data[[dv]])
  values <- data[[dv]][keep]
  groups <- as.character(data[[iv]][keep])
  levs <- .iv_levels(data[keep, , drop = FALSE], iv)
  kind <- .resolve_descriptives(descriptives, "median")
  desc <- .describe_levels(values, groups, levs, kind)
  mean_ranks <- .direction_scores(values, groups, levs, "meanrank")

  # 1. Collect all significant findings into a data frame/list
  findings <- list()

  for (i in seq_along(d$res$P.adj)) {
    if (!is.na(d$res$P.adj[i]) && d$res$P.adj[i] < 0.05) {
      # --- P-Value Formatting ---
      pValueStr <- .fmt_p_macro(d$res$P.adj[i], macro = p_macro[1], minor_macro = p_macro[2])

      # --- Identify the two levels ---
      # FSA labels the comparison "A - B"; match it against the levels rather
      # than splitting on " - ", which a level name may itself contain.
      comparison <- as.character(d$res$Comparison[i])
      pair <- .match_contrast_pair(comparison, levs)
      if (is.null(pair)) {
        stop(
          "Comparison '", comparison, "' of the Dunn test does not match two ",
          "levels of `", iv, "` in `data`. Pass the data the test was computed on.",
          call. = FALSE
        )
      }
      condA <- pair[1]
      condB <- pair[2]

      # --- Determine Direction (from the test) ---
      # FSA's Z for "A - B" is the standardised difference of mean ranks, so
      # Z > 0 means A ranks higher. The raw means are no guide: a level with a
      # few large outliers can have the larger mean and the lower mean rank.
      z <- if (!is.null(d$res$Z)) suppressWarnings(as.numeric(d$res$Z[i])) else NA_real_
      mr_diff <- mean_ranks[[condA]] - mean_ranks[[condB]]
      if (is.na(z) || z == 0) {
        if (is.na(mr_diff) || mr_diff == 0) {
          stop("The direction of comparison '", comparison, "' cannot be determined.", call. = FALSE)
        }
        first_higher <- mr_diff > 0
      } else {
        first_higher <- z > 0
        if (!is.na(mr_diff) && mr_diff != 0 && (mr_diff > 0) != first_higher) {
          warning(
            "The Dunn test's Z for '", comparison, "' (", .fmt_num(z), ") ",
            "disagrees with the mean ranks in `data`. Is `data` the data the ",
            "test was computed on? The sentence follows the test.",
            call. = FALSE
          )
        }
      }
      .check_descriptive_direction(desc, condA, condB, first_higher, kind, "Dunn test",
                                   forced = !identical(descriptives, "auto"))

      # --- Calculate Effect Size ---
      esStr <- ""
      tryCatch(
        {
          rrb <- .art_con_effect_size(data, iv, dv, condA, condB, paired = FALSE)
          esStr <- paste0(", \\rankbiserial{", .fmt_bounded(rrb), "}")
        },
        error = function(e) {
          warning(
            "Effect size could not be computed for '", comparison, "': ",
            conditionMessage(e),
            call. = FALSE
          )
        }
      )

      winner <- if (first_higher) condA else condB
      loser <- if (first_higher) condB else condA
      findings[[length(findings) + 1]] <- .posthoc_finding(
        winner, loser, desc, kind, paste0("; ", pValueStr, esStr)
      )
    }
  }

  # 2. Group findings by Winner and construct sentences
  sentences <- .posthoc_winner_sentences(findings, phrase, dv_tex, iv)

  if (!is.null(sink_to) && length(sentences) > 0) {
    .write_tex(sentences, sink_to)
  }
  invisible(sentences)
}


# Internal: one significant comparison of reportDunnTest()/reportArtCon(), with
# condition names escaped for display. `tail` is what follows the loser's
# descriptives inside its parentheses ("; \padj{...}, \rankbiserial{...}").
.posthoc_finding <- function(winner, loser, desc, kind, tail) {
  list(
    winner = latex_escape(winner),
    winnerStats = paste0("(", .fmt_descriptives(desc[winner, "loc"], desc[winner, "disp"], kind), ")"),
    loserString = paste0(
      latex_escape(loser), " (",
      .fmt_descriptives(desc[loser, "loc"], desc[loser, "disp"], kind), tail, ")"
    )
  )
}

# Internal: group findings by the level that was higher and write one sentence
# per such level, joining the levels it beat with an Oxford comma.
.posthoc_winner_sentences <- function(findings, phrase, dv_tex, iv) {
  sentences <- character(0)
  if (length(findings) == 0) {
    return(sentences)
  }
  # Convert list to dataframe for easier grouping
  df_res <- do.call(rbind, lapply(findings, as.data.frame, stringsAsFactors = FALSE))

  # Render the IV name (a macro like \scenario when it is a valid command
  # name, escaped plain text otherwise).
  iv_cmd <- .tex_name(iv)

  for (w in unique(df_res$winner)) {
    # Get all entries where this condition was the winner
    subset_res <- df_res[df_res$winner == w, ]

    # Helper for Oxford comma logic (A, B, and C)
    losers <- subset_res$loserString
    n <- length(losers)
    joined_losers <- if (n == 1) {
      losers[1]
    } else if (n == 2) {
      paste(losers, collapse = " and ")
    } else {
      paste0(paste(losers[1:(n - 1)], collapse = ", "), ", and ", losers[n])
    }

    final_str <- paste0(
      phrase, " found that ", dv_tex, " for the ", iv_cmd, " ", w,
      " was significantly higher ", subset_res$winnerStats[1],
      " than for ", joined_losers, ". "
    )

    message(final_str)
    sentences <- c(sentences, final_str)
  }
  sentences
}

# Internal: a \label{} key for a table. Variable names go into it verbatim
# (so existing \ref{}s keep working), except for the characters that end or
# break the argument of \label -- % starts a comment, braces unbalance it, and
# \ # $ & ^ ~ are LaTeX specials -- which become "-".
.table_label <- function(prefix, iv, dv) {
  clean <- function(x) gsub("[\\\\{}%#$&^~]", "-", as.character(x))
  paste0(prefix, "-", clean(iv), "-", clean(dv))
}


#' report Dunn test as a table. Customizable with sensible defaults.
#'
#' The table lists the significant comparisons with their \eqn{Z}, p-value and
#' rank-biserial correlation. FSA's \eqn{Z} for "A - B" is positive when A has
#' the higher mean rank, which the caption states. The p-value column is headed
#' "p-adjusted" and the caption names the correction read from the test object;
#' a test run with `method = "none"` gets the header "p" and a caption saying
#' the p-values are not adjusted. P-values are never rounded across .05 or .01.
#'
#' @param d the dunn test object
#' @param data the data frame
#' @param iv independent variable
#' @param dv dependent variable
#' @param orderByP whether to order by the p value
#' @param numberDigitsForPValue the number of digits to show
#' @param latexSize which size for the text
#' @param orderText whether to order the comparisons alphabetically; ignored when `orderByP = TRUE`
#' @param style table rule style: \code{"hline"} (default, classic
#'   \code{\\hline} rules) or \code{"booktabs"} (journal-standard
#'   \code{\\toprule}/\code{\\midrule}/\code{\\bottomrule}; needs
#'   \code{\\usepackage{booktabs}}).
#' @param sink_to optional path of a \code{.tex} file to write the table to,
#'   so a manuscript can \code{\\input{}} it
#'
#' @return Invisibly returns the rendered LaTeX table as a string (or
#'   \code{NULL} when xtable is unavailable); the table is also printed.
#' @export
#'
#' @examples
#' \donttest{
#' if (requireNamespace("FSA", quietly = TRUE)) {
#'   # Use built-in iris data
#'   data(iris)
#'
#'   # Dunn test on Sepal.Length by Species
#'   d <- FSA::dunnTest(Sepal.Length ~ Species,
#'     data   = iris,
#'     method = "holm"
#'   )
#'
#'   # Report the Dunn test
#'   reportDunnTestTable(d,
#'     data = iris,
#'     iv   = "Species",
#'     dv   = "Sepal.Length"
#'   )
#' }
#' }
reportDunnTestTable <- function(d = NULL, data, iv = "testiv", dv = "testdv", orderByP = FALSE, numberDigitsForPValue = 4, latexSize = "small", orderText = TRUE, style = c("hline", "booktabs"), sink_to = NULL) {
  not_empty(data)
  not_empty(iv)
  not_empty(dv)
  .check_columns(data, c(iv, dv))
  style <- match.arg(style)

  # If d is not provided, calculate it
  if (is.null(d)) {
    if (!requireNamespace("FSA", quietly = TRUE)) {
      stop("Package 'FSA' is required to compute the Dunn test when `d` is not supplied. Please install it or pass `d` directly.")
    }
    d <- FSA::dunnTest(stats::as.formula(paste(.bt(dv), "~", .bt(iv))), data = data, method = "holm")
  }

  # The correction FSA applied. With method = "none" the column holds raw
  # p-values and must not be headed "p-adjusted".
  adjust <- .adjust_label(d$method)
  unadjusted <- .adjustment_is_none(adjust)
  p_header <- if (unadjusted) "p" else "p-adjusted"

  # Use the dunn test result that was passed in
  # dunnTest returns a list with $res component
  table <- data.frame(
    Comparison = d$res$Comparison,
    Z = d$res$Z,
    p = d$res$P.adj,
    check.names = FALSE
  )

  # only show significant ones
  table <- table[!is.na(table$p) & table$p < 0.05, , drop = FALSE]

  # Check if there are any significant results
  if (nrow(table) == 0) {
    no_diff_msg <- paste0(
      .posthoc_test_phrase("Dunn", adjust),
      " found no significant differences for ", latex_escape(dv), ". "
    )
    message(no_diff_msg)
    if (!is.null(sink_to)) {
      .write_tex(no_diff_msg, sink_to)
    }
    return(invisible(no_diff_msg))
  }

  # Calculate effect sizes for all comparisons (only for significant ones).
  # The two levels are matched against the data rather than split out of the
  # label, which breaks on level names containing " - ".
  levs <- .iv_levels(data, iv)
  effectSizes <- numeric(nrow(table))
  for (i in seq_len(nrow(table))) {
    comparison <- as.character(table[i, "Comparison"])
    pair <- .match_contrast_pair(comparison, levs)

    tryCatch(
      {
        if (is.null(pair)) {
          stop("it does not match two levels of `", iv, "` in `data`")
        }
        effectSizes[i] <- .art_con_effect_size(data, iv, dv, pair[1], pair[2], paired = FALSE)
      },
      error = function(e) {
        # Super-assign so the failure is recorded in the enclosing vector;
        # a plain `<-` here would only mutate a discarded local copy.
        effectSizes[i] <<- NA
        warning(
          "Effect size could not be computed for '", comparison, "': ",
          conditionMessage(e),
          call. = FALSE
        )
      }
    )
  }

  # Add effect size column
  table$r <- effectSizes

  # orderByP takes precedence: previously the alphabetical sort below ran
  # second and silently undid an explicitly requested p-value ordering.
  if (orderByP) {
    table <- table[order(table$p), ]
  } else if (orderText) {
    table <- table[order(table$Comparison), ]
  }

  # Replace 0.000 with <0.001 automatically. Other p-values are never rounded
  # across .05/.01 (formatC printed 0.04996 as "0.0500" at 4 digits).
  table$p <- ifelse(table$p < 0.001, paste0("<", .fmt_bounded(0.001, 3)),
    .fmt_p_number(table$p, digits = numberDigitsForPValue)
  )
  names(table)[names(table) == "p"] <- p_header

  # Format effect size
  table$r <- formatC(table$r, digits = 2, format = "f")

  adjust_txt <- if (unadjusted) {
    " p-values are not adjusted for multiple comparisons."
  } else if (!is.null(adjust)) {
    paste0(" p-values are ", latex_escape(adjust), "-adjusted.")
  } else {
    ""
  }
  caption_txt <- paste0(
    "Dunn post-hoc comparisons for independent variable ", .tex_name(iv),
    " and dependent variable ", .tex_name(dv),
    ". Positive Z-values mean that the first-named level has the higher mean rank; for negative Z-values, the second-named level does.",
    adjust_txt,
    " Effect size reported as rank-biserial correlation (r)."
  )

  # Adjust the xtable call to handle the modified columns
  if (requireNamespace("xtable", quietly = TRUE)) {
    xtable_obj <- xtable::xtable(table,
      digits = c(0, 0, 4, 0, 0),
      caption = caption_txt,
      label = .table_label("tab:posthoc", iv, dv)
    )

    latex_str <- print(xtable_obj, type = "latex", size = latexSize, caption.placement = "top", include.rownames = FALSE, booktabs = identical(style, "booktabs"), print.results = FALSE)
    cat(latex_str)
    if (!is.null(sink_to)) {
      .write_tex(latex_str, sink_to)
    }
    return(invisible(latex_str))
  }

  message(paste0(caption_txt, "\n"))
  print(table)

  invisible(NULL)
}


# Internal: coerce an art.con() result (or its summary) into a tidy data frame
# with normalised column names. `art.con()` returns an emmeans `emmGrid`; its
# summary carries `contrast`, `estimate`, `SE`, `df`, `t.ratio`/`z.ratio` and
# `p.value`. Also accepts an already-summarised data frame so callers may pass
# either `ac` or `summary(ac)`.
#
# Two attributes travel with the result: "adjust", the multiplicity correction
# emmeans applied (its summary records it, e.g. "holm", "tukey" or "none";
# NULL when a bare data frame says nothing), and "stat_name", "t" or "z"
# depending on whether emmeans produced t or z ratios.
.art_con_to_df <- function(ac) {
  if (inherits(ac, "emmGrid")) {
    s <- summary(ac)
    adjust <- attr(s, "adjust")
    tbl <- as.data.frame(s)
  } else {
    adjust <- attr(ac, "adjust")
    tbl <- as.data.frame(ac)
  }
  stat_name <- if ("z.ratio" %in% names(tbl) && !"t.ratio" %in% names(tbl)) "z" else "t"

  # Contrast label column
  if (!"contrast" %in% names(tbl)) {
    cand <- names(tbl)[vapply(tbl, function(x) is.character(x) || is.factor(x), logical(1))]
    if (length(cand) == 0) {
      stop("Could not find a contrast/label column in the art.con() object.")
    }
    names(tbl)[names(tbl) == cand[1]] <- "contrast"
  }
  tbl$contrast <- as.character(tbl$contrast)

  # p-value column (already adjusted by art.con()'s `adjust` argument)
  if (!"p.value" %in% names(tbl)) {
    pcol <- grep("^p\\.value$|p\\.val|Pr\\(>", names(tbl), ignore.case = TRUE, value = TRUE)
    if (length(pcol) == 0) {
      stop("Could not find a p-value column in the art.con() object.")
    }
    names(tbl)[names(tbl) == pcol[1]] <- "p.value"
  }

  # Test statistic column: prefer t.ratio, fall back to z.ratio
  if (!"statistic" %in% names(tbl)) {
    scol <- grep("^t\\.ratio$|^z\\.ratio$", names(tbl), value = TRUE)
    tbl$statistic <- if (length(scol) > 0) tbl[[scol[1]]] else NA_real_
  }
  if (!"df" %in% names(tbl)) {
    tbl$df <- NA_real_
  }

  attr(tbl, "adjust") <- .adjust_label(adjust)
  attr(tbl, "stat_name") <- stat_name
  tbl
}


# Internal: the two levels of `iv` each art.con() contrast compares, as a
# character matrix (first, second) with NA rows where none can be found. The
# estimate of a pairwise contrast is first minus second.
#
# The labels emmeans writes cannot simply be split on " - ": it parenthesises
# levels containing "-", "+", "*" or "/" ("Both - (Hand-only)") and prefixes
# all-numeric levels with the factor name ("mode1 - mode2"). Splitting turned
# both into level names that do not exist, so reportArtCon() crashed with
# "missing value where TRUE/FALSE needed" and reportArtConTable() silently
# printed NA effect sizes. For an emmGrid the pairs are read from the contrast
# coefficients themselves (+1 on the first level, -1 on the second); otherwise,
# and as a fallback, the label is matched against the levels of `iv`.
.art_con_pairs <- function(ac, tbl, data, iv) {
  levs <- .iv_levels(data, iv)
  pairs <- matrix(NA_character_, nrow = nrow(tbl), ncol = 2L)

  if (inherits(ac, "emmGrid")) {
    cc <- tryCatch(ac@misc$con.coef, error = function(e) NULL)
    og <- tryCatch(ac@misc$orig.grid, error = function(e) NULL)
    if (is.matrix(cc) && is.data.frame(og) && ncol(og) == 1L &&
        nrow(cc) == nrow(tbl) && ncol(cc) == nrow(og)) {
      og_levels <- as.character(og[[1]])
      for (i in seq_len(nrow(cc))) {
        pos <- which(cc[i, ] > 0)
        neg <- which(cc[i, ] < 0)
        if (length(pos) == 1L && length(neg) == 1L) {
          pairs[i, ] <- og_levels[c(pos, neg)]
        }
      }
    }
  }

  for (i in which(is.na(pairs[, 1]) | is.na(pairs[, 2]))) {
    m <- .match_contrast_pair(tbl$contrast[i], levs, prefix = iv)
    if (!is.null(m)) pairs[i, ] <- m
  }

  # Only levels that exist in `data` can be described or used for effect sizes.
  bad <- !(pairs[, 1] %in% levs & pairs[, 2] %in% levs)
  pairs[bad, ] <- NA_character_
  pairs
}


# Internal: rank-biserial correlation for one pair of conditions, computed from
# the raw data. For unpaired data the formula interface is used. For paired
# (within-subjects) data we aggregate to one value per subject x condition
# (mean of any replicate trials), align the two conditions by `id`, and use the
# two-vector interface (the formula interface of effectsize does not support
# `paired = TRUE`).
.art_con_effect_size <- function(data, iv, dv, condA, condB, paired = FALSE, id = NULL) {
  data_subset <- data |>
    dplyr::filter(!!rlang::sym(iv) %in% c(condA, condB)) |>
    droplevels()

  if (!paired) {
    # Backticks keep names such as "Mental Demand" intact in the formula.
    es <- effectsize::rank_biserial(
      stats::as.formula(paste(.bt(dv), "~", .bt(iv))),
      data = data_subset
    )
    return(abs(es$r_rank_biserial))
  }

  if (is.null(id) || !id %in% names(data)) {
    stop("`paired = TRUE` requires `id` to name the subject/pairing column.")
  }

  wide <- data_subset |>
    dplyr::group_by(!!rlang::sym(id), !!rlang::sym(iv)) |>
    dplyr::summarise(.value = mean(!!rlang::sym(dv), na.rm = TRUE), .groups = "drop") |>
    tidyr::pivot_wider(names_from = !!rlang::sym(iv), values_from = ".value")

  x <- wide[[condA]]
  y <- wide[[condB]]
  keep <- stats::complete.cases(x, y)
  es <- effectsize::rank_biserial(x[keep], y[keep], paired = TRUE)
  abs(es$r_rank_biserial)
}


#' Report significant ART contrasts (art.con) as LaTeX text
#'
#' Companion to [reportDunnTest()] for aligned-rank-transform (ART) models. It
#' extracts the significant pairwise comparisons produced by [ARTool::art.con()]
#' (an \pkg{emmeans} contrast grid), describes the groups involved from the raw
#' data, and prints LaTeX-formatted sentences such as "An ART-C post-hoc test
#' (Holm-adjusted) found that ...".
#'
#' The p-values are taken as-is from the contrast object, i.e. they are already
#' adjusted by whatever `adjust` was passed to `art.con()` (e.g. `"holm"`), and
#' that correction -- read from the contrast summary -- is named in the
#' sentence. With `adjust = "none"` the p-values are emitted as
#' \code{\\p{}}/\code{\\pminor{}} rather than as \eqn{p_{adj}}. The effect size
#' is the rank-biserial correlation computed from the raw data. ART is most
#' often used for within-subjects designs; pass `paired = TRUE` together with
#' `id` (the subject column) to obtain the paired rank-biserial effect size.
#'
#' Which level is "higher" follows the sign of the contrast estimate (first
#' minus second level, on the aligned-rank scale). Until 0.3.0 it followed the
#' raw means, which can disagree with the test. By default
#' (`descriptives = "auto"`) the levels are described by their median and IQR,
#' which match a rank-based test; `"mean"` restores \emph{M}/\emph{SD} and
#' warns where the means order two levels against the contrast.
#'
#' The two levels of each contrast are read from the contrast coefficients, so
#' level names that emmeans rewrites in its labels -- numbers ("mode1 - mode2")
#' or names containing \code{-}, \code{+}, \code{*} or \code{/}
#' ("Both - (Hand-only)") -- are handled.
#'
#' Attention: `ac` must be a pairwise contrast over a single factor `iv`
#' (e.g. `art.con(model, ~ interaction_mode, adjust = "holm")`).
#'
#' Required commands in LaTeX (all part of [latex_preamble()]):
#' \code{\\padj}, \code{\\padjminor}, \code{\\p}, \code{\\pminor},
#' \code{\\mdn}, \code{\\iqr}, \code{\\m}, \code{\\sd} and
#' \code{\\newcommand{\\rankbiserial}[1]{$r_{rb} = #1$}}.
#'
#' @param ac the contrast object returned by [ARTool::art.con()] (or its `summary()`)
#' @param data the raw data frame used to fit the model
#' @param iv independent variable (the contrasted factor)
#' @param dv dependent variable
#' @param paired whether to compute the rank-biserial effect size for paired
#'   (within-subjects) data. Defaults to `FALSE`. When `TRUE`, `id` is required.
#' @param id the subject/pairing column, used only when `paired = TRUE`. Replicate
#'   trials per subject and condition are averaged before pairing.
#' @param sink_to optional path of a \code{.tex} file to write the sentences to,
#'   so a manuscript can \code{\\input{}} them
#' @param descriptives which descriptives to print beside each level:
#'   \code{"auto"} (default, median and IQR for this rank-based test),
#'   \code{"mean"}, \code{"median"} or \code{"trimmed"} (20% trimmed mean and
#'   20% winsorized SD).
#'
#' @return Invisibly returns the reported sentence(s) as a character vector;
#'   the text is also emitted via \code{message()}.
#' @export
#'
#' @examples
#' \donttest{
#' if (requireNamespace("ARTool", quietly = TRUE) &&
#'   requireNamespace("emmeans", quietly = TRUE)) {
#'   set.seed(123)
#'   n <- 20
#'   df <- data.frame(
#'     UserID = factor(rep(seq_len(n), times = 3)),
#'     mode   = factor(rep(c("Hand", "Eye", "Both"), each = n)),
#'     prime  = factor(rep(rep(c("A", "B"), each = n / 2), times = 3))
#'   )
#'   df$score <- as.numeric(df$mode) * 2 + stats::rnorm(nrow(df))
#'
#'   m  <- ARTool::art(score ~ mode * prime + Error(UserID / mode), data = df)
#'   ac <- ARTool::art.con(m, ~ mode, adjust = "holm")
#'   reportArtCon(ac, data = df, iv = "mode", dv = "score", paired = TRUE, id = "UserID")
#' }
#' }
reportArtCon <- function(ac, data, iv = "testiv", dv = "testdv", paired = FALSE, id = NULL, sink_to = NULL,
                         descriptives = c("auto", "mean", "median", "trimmed")) {
  not_empty(ac)
  not_empty(data)
  not_empty(iv)
  not_empty(dv)
  .check_columns(data, c(iv, dv))
  descriptives <- match.arg(descriptives)
  dv_tex <- latex_escape(dv)

  tbl <- .art_con_to_df(ac)
  # The correction emmeans applied; with adjust = "none" the p-values are raw
  # and must not be labelled p_adj.
  adjust <- attr(tbl, "adjust")
  p_macro <- .p_macros(adjust)
  phrase <- .posthoc_test_phrase("ART-C", adjust)

  # Check for significance globally first
  if (!any(tbl$p.value < 0.05, na.rm = TRUE)) {
    no_diff_msg <- paste0(phrase, " found no significant differences for ", dv_tex, ". ")
    message(no_diff_msg)
    if (!is.null(sink_to)) {
      .write_tex(no_diff_msg, sink_to)
    }
    return(invisible(no_diff_msg))
  }

  pairs <- .art_con_pairs(ac, tbl, data, iv)
  keep <- !is.na(data[[iv]]) & !is.na(data[[dv]])
  levs <- .iv_levels(data[keep, , drop = FALSE], iv)
  kind <- .resolve_descriptives(descriptives, "median")
  desc <- .describe_levels(data[[dv]][keep], as.character(data[[iv]][keep]), levs, kind)

  # 1. Collect all significant findings into a list
  findings <- list()

  for (i in seq_along(tbl$p.value)) {
    if (!is.na(tbl$p.value[i]) && tbl$p.value[i] < 0.05) {
      # --- P-Value Formatting ---
      pValueStr <- .fmt_p_macro(tbl$p.value[i], macro = p_macro[1], minor_macro = p_macro[2])

      # --- Identify the two levels (see .art_con_pairs()) ---
      if (anyNA(pairs[i, ]) || !all(pairs[i, ] %in% levs)) {
        stop(
          "Contrast '", tbl$contrast[i], "' does not compare two levels of `",
          iv, "` in `data`. reportArtCon() expects pairwise contrasts over the ",
          "single factor `iv`, e.g. art.con(model, ~ ", iv, ").",
          call. = FALSE
        )
      }
      condA <- pairs[i, 1]
      condB <- pairs[i, 2]

      # --- Determine Direction (from the test) ---
      # The contrast estimate is first minus second on the aligned-rank scale
      # (t.ratio carries the same sign). The raw means are no guide to it.
      est <- if ("estimate" %in% names(tbl)) suppressWarnings(as.numeric(tbl$estimate[i])) else NA_real_
      if (is.na(est) || est == 0) {
        est <- suppressWarnings(as.numeric(tbl$statistic[i]))
      }
      if (is.na(est) || est == 0) {
        stop("The direction of contrast '", tbl$contrast[i], "' cannot be determined.", call. = FALSE)
      }
      first_higher <- est > 0
      .check_descriptive_direction(desc, condA, condB, first_higher, kind, "ART-C contrast",
                                   forced = !identical(descriptives, "auto"))

      # --- Calculate Effect Size (rank-biserial from the raw data) ---
      esStr <- ""
      tryCatch(
        {
          rrb <- .art_con_effect_size(data, iv, dv, condA, condB, paired = paired, id = id)
          esStr <- paste0(", \\rankbiserial{", .fmt_bounded(rrb), "}")
        },
        error = function(e) {
          warning(
            "Effect size could not be computed for '", tbl$contrast[i], "': ",
            conditionMessage(e),
            call. = FALSE
          )
        }
      )

      winner <- if (first_higher) condA else condB
      loser <- if (first_higher) condB else condA
      findings[[length(findings) + 1]] <- .posthoc_finding(
        winner, loser, desc, kind, paste0("; ", pValueStr, esStr)
      )
    }
  }

  # 2. Group findings by Winner and construct sentences (same wording and
  # IV-name policy as reportDunnTest())
  sentences <- .posthoc_winner_sentences(findings, phrase, dv_tex, iv)

  if (!is.null(sink_to) && length(sentences) > 0) {
    .write_tex(sentences, sink_to)
  }
  invisible(sentences)
}


#' Report ART contrasts (art.con) as a LaTeX table. Customizable with sensible
#' defaults. Companion to [reportDunnTestTable()].
#'
#' The table lists the significant contrasts with their test statistic -- a
#' column headed \emph{t}, or \emph{z} when emmeans reports z ratios -- its
#' degrees of freedom (fractional Kenward-Roger or Satterthwaite dfs are shown
#' to two decimals, not rounded to integers; the column is omitted for z
#' ratios), the p-value and the rank-biserial correlation. The p-value column
#' is headed "p-adjusted" and the caption names the correction read from the
#' contrast summary; with `adjust = "none"` the header is "p" and the caption
#' says the p-values are not adjusted. A positive statistic means the
#' first-named level is higher on the aligned-rank scale.
#'
#' @param ac the contrast object returned by [ARTool::art.con()] (or its `summary()`)
#' @param data the raw data frame used to fit the model
#' @param iv independent variable (the contrasted factor)
#' @param dv dependent variable
#' @param paired whether to compute the rank-biserial effect size for paired
#'   (within-subjects) data. Defaults to `FALSE`. When `TRUE`, `id` is required.
#' @param id the subject/pairing column, used only when `paired = TRUE`. Replicate
#'   trials per subject and condition are averaged before pairing.
#' @param orderByP whether to order by the p value
#' @param numberDigitsForPValue the number of digits to show
#' @param latexSize which size for the text
#' @param orderText whether to order the comparisons alphabetically; ignored when `orderByP = TRUE`
#' @param style table rule style: \code{"hline"} (default) or \code{"booktabs"}
#'   (\code{\\toprule}/\code{\\midrule}/\code{\\bottomrule}; needs
#'   \code{\\usepackage{booktabs}}).
#' @param sink_to optional path of a \code{.tex} file to write the table to,
#'   so a manuscript can \code{\\input{}} it
#'
#' @return Invisibly returns the rendered LaTeX table as a string (or
#'   \code{NULL} when xtable is unavailable); the table is also printed.
#' @export
#'
#' @examples
#' \donttest{
#' if (requireNamespace("ARTool", quietly = TRUE) &&
#'   requireNamespace("emmeans", quietly = TRUE)) {
#'   set.seed(123)
#'   n <- 20
#'   df <- data.frame(
#'     UserID = factor(rep(seq_len(n), times = 3)),
#'     mode   = factor(rep(c("Hand", "Eye", "Both"), each = n)),
#'     prime  = factor(rep(rep(c("A", "B"), each = n / 2), times = 3))
#'   )
#'   df$score <- as.numeric(df$mode) * 2 + stats::rnorm(nrow(df))
#'
#'   m  <- ARTool::art(score ~ mode * prime + Error(UserID / mode), data = df)
#'   ac <- ARTool::art.con(m, ~ mode, adjust = "holm")
#'   reportArtConTable(ac, data = df, iv = "mode", dv = "score", paired = TRUE, id = "UserID")
#' }
#' }
reportArtConTable <- function(ac, data, iv = "testiv", dv = "testdv", paired = FALSE, id = NULL, orderByP = FALSE, numberDigitsForPValue = 4, latexSize = "small", orderText = TRUE, style = c("hline", "booktabs"), sink_to = NULL) {
  not_empty(ac)
  not_empty(data)
  not_empty(iv)
  not_empty(dv)
  .check_columns(data, c(iv, dv))
  style <- match.arg(style)

  src <- .art_con_to_df(ac)
  adjust <- attr(src, "adjust")
  unadjusted <- .adjustment_is_none(adjust)
  p_header <- if (unadjusted) "p" else "p-adjusted"
  # emmeans gives t ratios with (often Kenward-Roger, fractional) df, or z
  # ratios with df = Inf; the column is named after the statistic it holds.
  stat_name <- attr(src, "stat_name")
  pairs <- .art_con_pairs(ac, src, data, iv)

  table <- data.frame(
    Comparison = as.character(src$contrast),
    statistic = src$statistic,
    df = src$df,
    p = src$p.value,
    stringsAsFactors = FALSE
  )
  table$.first <- pairs[, 1]
  table$.second <- pairs[, 2]

  # only show significant ones
  table <- table[!is.na(table$p) & table$p < 0.05, , drop = FALSE]

  # Check if there are any significant results
  if (nrow(table) == 0) {
    no_diff_msg <- paste0(
      .posthoc_test_phrase("ART-C", adjust),
      " found no significant differences for ", latex_escape(dv), ". "
    )
    message(no_diff_msg)
    if (!is.null(sink_to)) {
      .write_tex(no_diff_msg, sink_to)
    }
    return(invisible(no_diff_msg))
  }

  # Calculate effect sizes for the significant comparisons
  effectSizes <- numeric(nrow(table))
  for (i in seq_len(nrow(table))) {
    comparison <- as.character(table[i, "Comparison"])

    tryCatch(
      {
        if (is.na(table$.first[i]) || is.na(table$.second[i])) {
          stop("it does not compare two levels of `", iv, "` in `data`")
        }
        effectSizes[i] <- .art_con_effect_size(
          data, iv, dv, table$.first[i], table$.second[i],
          paired = paired, id = id
        )
      },
      error = function(e) {
        # Super-assign so the failure is recorded in the enclosing vector;
        # a plain `<-` here would only mutate a discarded local copy.
        effectSizes[i] <<- NA
        warning(
          "Effect size could not be computed for '", comparison, "': ",
          conditionMessage(e),
          call. = FALSE
        )
      }
    )
  }

  # Add effect size column
  table$r <- effectSizes
  table$.first <- NULL
  table$.second <- NULL

  # orderByP takes precedence: previously the alphabetical sort below ran
  # second and silently undid an explicitly requested p-value ordering.
  if (orderByP) {
    table <- table[order(table$p), ]
  } else if (orderText) {
    table <- table[order(table$Comparison), ]
  }

  # Replace 0.000 with <0.001 automatically. Other p-values are never rounded
  # across .05/.01.
  table$p <- ifelse(table$p < 0.001, paste0("<", .fmt_bounded(0.001, 3)),
    .fmt_p_number(table$p, digits = numberDigitsForPValue)
  )

  # Degrees of freedom: Kenward-Roger/Satterthwaite dfs are fractional and were
  # printed with 0 digits (33.7 -> "34"); a z ratio has df = Inf, so the column
  # is dropped when no df is finite.
  has_df <- any(is.finite(suppressWarnings(as.numeric(table$df))))
  if (has_df) {
    table$df <- .fmt_df(table$df)
  } else {
    table$df <- NULL
  }

  # Format effect size
  table$r <- formatC(table$r, digits = 2, format = "f")
  names(table)[names(table) == "statistic"] <- stat_name
  names(table)[names(table) == "p"] <- p_header

  adjust_txt <- if (unadjusted) {
    " p-values are not adjusted for multiple comparisons."
  } else if (!is.null(adjust)) {
    paste0(" p-values are ", latex_escape(adjust), "-adjusted.")
  } else {
    ""
  }
  caption_txt <- paste0(
    "Post-hoc ART-C contrasts for independent variable ", .tex_name(iv),
    " and dependent variable ", .tex_name(dv),
    ". Positive ", stat_name, "-values mean that the first-named level is higher than the second-named on the aligned-rank scale; for negative ", stat_name, "-values, the second-named level is.",
    adjust_txt,
    " Effect size reported as rank-biserial correlation (r)."
  )

  if (requireNamespace("xtable", quietly = TRUE)) {
    # Comparison, statistic, [df], p, r: only the statistic is numeric here.
    xtable_obj <- xtable::xtable(table,
      digits = c(0, 0, 2, rep(0, ncol(table) - 2L)),
      caption = caption_txt,
      label = .table_label("tab:artcon", iv, dv)
    )

    latex_str <- print(xtable_obj, type = "latex", size = latexSize, caption.placement = "top", include.rownames = FALSE, booktabs = identical(style, "booktabs"), print.results = FALSE)
    cat(latex_str)
    if (!is.null(sink_to)) {
      .write_tex(latex_str, sink_to)
    }
    return(invisible(latex_str))
  }

  message(paste0(caption_txt, "\n"))
  print(table)

  invisible(NULL)
}
