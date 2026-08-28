# Fitting the model that recommend_test() recommends.
#
# recommend_test() stops at advice: it returns the name of a function and a
# fit_call string to paste. That leaves the most error-prone step -- getting the
# outcome into the class the model needs, building the random-effect term,
# picking the post-hoc machinery that matches the fit -- to be redone by hand in
# every project. fit_recommended() carries the recommendation through to a
# fitted model, its post-hoc contrasts, and the manuscript sentence, so the
# choice of test and the analysis that is actually run cannot drift apart.


# Internal: build the model formula implied by a recommendation.
.fit_formula <- function(outcome, predictors, cluster = NULL, interaction = TRUE) {
  fixed <- if (is.null(predictors) || length(predictors) == 0) {
    "1"
  } else {
    paste(predictors, collapse = if (interaction) " * " else " + ")
  }
  rhs <- if (is.null(cluster)) fixed else paste0(fixed, " + (1 | ", cluster, ")")
  stats::as.formula(paste(outcome, "~", rhs))
}


# Internal: coerce the columns a model family requires into the class it needs,
# reporting every coercion. Silently turning a numeric 1-5 rating into an
# ordered factor changes what is being estimated, so it is said out loud.
.fit_coerce <- function(data, outcome, predictors, cluster, outcome_type, verbose = TRUE) {
  say <- function(...) if (isTRUE(verbose)) message(...)

  if (identical(outcome_type, "ordinal") && !is.ordered(data[[outcome]])) {
    # sort() on a character column is collation order, not response order, so
    # c("low", "medium", "high") would become high < low < medium and the
    # proportional-odds model would estimate a scrambled scale. Refuse rather
    # than guess: only the caller knows the real order.
    if (is.character(data[[outcome]]) || (is.factor(data[[outcome]]) && !is.ordered(data[[outcome]]))) {
      stop(
        "`", outcome, "` holds labels, so its response order cannot be inferred ",
        "(sorting them gives collation order, not the scale's order). Supply it ",
        "as an ordered factor, e.g. factor(", outcome,
        ", levels = c(\"low\", \"medium\", \"high\"), ordered = TRUE).",
        call. = FALSE
      )
    }
    lv <- sort(unique(stats::na.omit(data[[outcome]])))
    data[[outcome]] <- factor(data[[outcome]], levels = lv, ordered = TRUE)
    say(
      "Coerced `", outcome, "` to an ordered factor with ", length(lv),
      " levels (", paste(utils::head(lv, 3), collapse = " < "),
      if (length(lv) > 3) " < ..." else "", ")."
    )
  }

  if (identical(outcome_type, "binary") && !is.factor(data[[outcome]])) {
    data[[outcome]] <- factor(data[[outcome]])
    say(
      "Coerced `", outcome, "` to a factor; modelling P(",
      levels(data[[outcome]])[2], ")."
    )
  }

  for (p in predictors) {
    if (.is_grouping(data[[p]]) && !is.factor(data[[p]])) {
      data[[p]] <- factor(data[[p]])
      say("Coerced predictor `", p, "` to a factor with ", nlevels(data[[p]]), " levels.")
    }
  }

  if (!is.null(cluster) && !is.factor(data[[cluster]])) {
    data[[cluster]] <- factor(data[[cluster]])
    say("Coerced cluster `", cluster, "` to a factor with ", nlevels(data[[cluster]]), " levels.")
  }

  data
}


# Internal: require a Suggests package, naming the model it is needed for.
.fit_need <- function(pkg, what) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(
      "Fitting ", what, " needs the '", pkg, "' package. Install it with ",
      "install.packages(\"", pkg, "\").",
      call. = FALSE
    )
  }
  invisible(TRUE)
}


# Internal: fit the model a recommendation names. Returns the fitted object plus
# the name of the engine that produced it, so the caller can pick a reporter.
.fit_dispatch <- function(rec, data, interaction = TRUE, verbose = TRUE) {
  outcome <- rec$outcome
  predictors <- rec$predictors
  cluster <- if (isTRUE(rec$clustered)) rec$cluster else NULL
  fml <- .fit_formula(outcome, predictors, cluster, interaction = interaction)
  no_re <- .fit_formula(outcome, predictors, NULL, interaction = interaction)

  # The classical one-way tests have no multi-factor semantics. Given a
  # multi-term right-hand side, stats::oneway.test() and kruskal.test() do not
  # complain -- they silently collapse the predictors with interaction() and
  # analyse the resulting cells, so the object would answer a different question
  # from the one the recommendation describes.
  htest_fns <- c("stats::oneway.test", "stats::kruskal.test", "stats::wilcox.test")
  if (rec$model_function %in% htest_fns) {
    if (length(predictors) == 0) {
      stop(
        rec$model_function, "() compares groups, but no predictor was given. ",
        "Pass `predictors`, or model the outcome directly.",
        call. = FALSE
      )
    }
    if (length(predictors) > 1L) {
      stop(
        rec$recommendation, " (", rec$model_function, ") is a one-way test, but ",
        length(predictors), " predictors were given. Analyse the factorial design ",
        "with the aligned rank transform instead -- ARTool::art(", deparse(no_re),
        ") -- or call fit_recommended() with a single predictor.",
        call. = FALSE
      )
    }
    one_way <- .fit_formula(outcome, predictors[[1L]], NULL, interaction = FALSE)
  }

  switch(rec$model_function,
    "ordinal::clmm" = {
      .fit_need("ordinal", "a cumulative link mixed model")
      list(model = ordinal::clmm(fml, data = data), engine = "clmm", reporter = "report_clmm")
    },
    "ordinal::clm" = {
      .fit_need("ordinal", "a cumulative link model")
      list(model = ordinal::clm(no_re, data = data), engine = "clm", reporter = "report_clmm")
    },
    "lme4::glmer" = {
      family <- if (identical(rec$outcome_type, "binary")) stats::binomial() else stats::poisson()
      .fit_need("lme4", "a generalized linear mixed model")
      list(
        model = lme4::glmer(fml, data = data, family = family),
        engine = "glmer", reporter = "report_glmm"
      )
    },
    "stats::glm" = {
      family <- if (identical(rec$outcome_type, "binary")) stats::binomial() else stats::poisson()
      list(
        model = stats::glm(no_re, data = data, family = family),
        engine = "glm", reporter = "report_glmm"
      )
    },
    "lme4::lmer" = {
      # lmerTest adds Satterthwaite degrees of freedom, which is what makes a
      # mixed model reportable in APA form at all; lme4 alone gives no p-values.
      if (requireNamespace("lmerTest", quietly = TRUE)) {
        list(model = lmerTest::lmer(fml, data = data), engine = "lmer", reporter = "report_glmm")
      } else {
        .fit_need("lme4", "a linear mixed model")
        if (isTRUE(verbose)) {
          message(
            "Install 'lmerTest' for Satterthwaite degrees of freedom and p-values; ",
            "fitting with lme4 alone."
          )
        }
        list(model = lme4::lmer(fml, data = data), engine = "lmer", reporter = "report_glmm")
      }
    },
    "ARTool::art" = {
      .fit_need("ARTool", "an aligned rank transform model")
      # report_art() reports an ANOVA table, not the art object -- its first act
      # is to look for a "Pr(>F)" column. Keep the art fit in $model (art.con()
      # needs it) and hand the reporter the table.
      art_fit <- ARTool::art(fml, data = data)
      list(
        model = art_fit, engine = "art", reporter = "report_art",
        report_object = stats::anova(art_fit)
      )
    },
    "nparLD::nparLD" = {
      .fit_need("nparLD", "a rank-based repeated-measures model")
      within_factor <- if (length(predictors)) predictors[[1L]] else NULL
      if (is.null(within_factor) || is.null(cluster)) {
        stop(
          "nparLD needs one within-subject factor and a cluster column.",
          call. = FALSE
        )
      }
      f <- stats::as.formula(paste(outcome, "~", within_factor))
      # nparLD before 2.3.0 prints a description of the design to stdout and
      # offers no argument to turn it off, so it is captured rather than passed.
      model <- NULL
      invisible(utils::capture.output(
        model <- nparLD::nparLD(f, data = as.data.frame(data), subject = cluster)
      ))
      list(model = model, engine = "nparld", reporter = "report_nparld")
    },
    "stats::aov" = list(model = stats::aov(no_re, data = data), engine = "aov", reporter = NA_character_),
    "stats::oneway.test" = list(
      model = stats::oneway.test(one_way, data = data, var.equal = FALSE),
      engine = "htest", reporter = NA_character_
    ),
    "stats::kruskal.test" = list(
      model = stats::kruskal.test(one_way, data = data), engine = "htest", reporter = NA_character_
    ),
    "stats::wilcox.test" = list(
      model = stats::wilcox.test(one_way, data = data), engine = "htest", reporter = NA_character_
    ),
    "stats::lm" = list(model = stats::lm(no_re, data = data), engine = "lm", reporter = "report_glmm"),
    "nnet::multinom" = {
      .fit_need("nnet", "a multinomial logistic regression")
      # summary.multinom() re-evaluates the recorded call, so that call must not
      # name .fit_dispatch()'s locals or print(fit) dies with "object 'no_re'
      # not found". do.call() with quote = FALSE splices the formula and the
      # data frame themselves into the call, which is what makes the fitted
      # object self-contained.
      list(
        model = do.call(nnet::multinom, list(no_re, data = data, trace = FALSE)),
        engine = "multinom", reporter = NA_character_
      )
    },
    stop(
      "fit_recommended() cannot yet fit '", rec$model_function,
      "'. Fit it yourself with:\n  ", rec$fit_call,
      call. = FALSE
    )
  )
}


# Internal: estimated marginal means and pairwise contrasts, by whatever route
# the engine supports. ART must go through ARTool's own contrast machinery --
# emmeans on the aligned-rank fit compares the wrong quantity.
.fit_contrasts <- function(fit, rec, data, adjust = "holm") {
  predictors <- rec$predictors
  if (is.null(predictors) || length(predictors) == 0) {
    return(NULL)
  }
  grouping <- predictors[vapply(predictors, function(p) .is_grouping(data[[p]]), logical(1))]
  if (length(grouping) == 0) {
    return(NULL)
  }

  if (identical(fit$engine, "art")) {
    if (!requireNamespace("emmeans", quietly = TRUE)) {
      return(NULL)
    }
    return(tryCatch(
      ARTool::art.con(fit$model, paste(grouping, collapse = ":"), adjust = adjust),
      error = function(e) NULL
    ))
  }

  if (!requireNamespace("emmeans", quietly = TRUE)) {
    return(NULL)
  }
  if (fit$engine %in% c("htest", "nparld", "multinom")) {
    return(NULL)
  }

  tryCatch(
    {
      specs <- stats::as.formula(paste("~", paste(grouping, collapse = " * ")))
      em <- emmeans::emmeans(fit$model, specs = specs)
      list(emmeans = em, contrasts = emmeans::contrast(em, method = "pairwise", adjust = adjust))
    },
    error = function(e) NULL
  )
}


#' Fit the model that the data call for, and report it
#'
#' Runs [recommend_test()] to choose an analysis, then actually fits it: coerces
#' the outcome and predictors into the classes that model family needs, builds
#' the random-effect term for a repeated-measures design, fits, computes
#' pairwise post-hoc contrasts with the matching machinery, and produces the
#' APA/LaTeX sentence via this package's reporter for that model family.
#'
#' The point is that the test you justify in the methods section and the model
#' you actually ran are produced by the same call, from the same data, and
#' therefore cannot drift apart -- the failure mode of a pipeline where
#' `recommend_test()` prints advice that someone then re-types by hand.
#'
#' @section What it can fit:
#' Cumulative link models with and without random effects
#' (\pkg{ordinal}), generalized and linear mixed models (\pkg{lme4},
#' \pkg{lmerTest}), GLMs, the aligned rank transform (\pkg{ARTool}), rank-based
#' repeated measures (\pkg{nparLD}), multinomial regression (\pkg{nnet}), and
#' the classical ANOVA / Welch / Kruskal-Wallis / Wilcoxon tests. Model packages
#' live in \code{Suggests}: a branch you use needs its package installed, and
#' says which one if it is not.
#'
#' @param data The data frame.
#' @param outcome The dependent variable (column name as string).
#' @param predictors Character vector of independent variable column names.
#' @param cluster Optional column identifying the subject or cluster for
#'   repeated-measures data -- the random-effect grouping factor.
#' @param design One of \code{"auto"} (default; clustered when \code{cluster} is
#'   given), \code{"between"}, or \code{"within"}.
#' @param outcome_type \code{"auto"} (default; use [classify_outcome()]) or an
#'   explicit \code{"continuous"}, \code{"ordinal"}, \code{"binary"},
#'   \code{"count"}, \code{"nominal"} to override the classification. Pass it
#'   when the automatic choice is wrong -- a 1-7 Likert item and a small count
#'   are genuinely ambiguous from the data alone.
#' @param ordinal_max_levels Passed to [classify_outcome()]. Default 7.
#' @param interaction Logical. With more than one predictor, fit the full
#'   factorial model (\code{TRUE}, default) or main effects only
#'   (\code{FALSE}).
#' @param contrasts Logical. Compute pairwise post-hoc contrasts between the
#'   levels of the grouping predictors. Default \code{TRUE}.
#' @param adjust Multiplicity adjustment for those contrasts, passed to
#'   \pkg{emmeans} or \pkg{ARTool}. Default \code{"holm"}.
#' @param sink_to Optional path of a \code{.tex} file; the methods sentence and
#'   the result sentence are written there so a manuscript can
#'   \code{\\input{}} them.
#' @param verbose Logical. If \code{TRUE} (default), report every coercion and
#'   the model being fitted.
#'
#' @return An object of class \code{"colley_fit"}: a list with
#'   \code{recommendation} (the [recommend_test()] object), \code{model} (the
#'   fitted object), \code{engine}, \code{emmeans} and \code{contrasts} (or
#'   \code{NULL}), \code{methods} and \code{text} (manuscript sentences), and
#'   \code{sentences} (both, in manuscript order). A \code{print} method
#'   summarises it.
#' @export
#' @seealso [recommend_test()] for the choice alone, [analyze_and_report()] for
#'   the figure-plus-sentence path through \pkg{ggstatsplot}.
#'
#' @examples
#' \donttest{
#' set.seed(1)
#' d <- data.frame(
#'   id = factor(rep(1:20, each = 3)),
#'   cond = factor(rep(c("A", "B", "C"), times = 20)),
#'   score = rnorm(60)
#' )
#' if (requireNamespace("lme4", quietly = TRUE)) {
#'   fit <- fit_recommended(d, outcome = "score", predictors = "cond", cluster = "id")
#'   fit
#' }
#' }
fit_recommended <- function(data, outcome, predictors = NULL, cluster = NULL,
                            design = c("auto", "between", "within"),
                            outcome_type = c(
                              "auto", "continuous", "ordinal",
                              "binary", "count", "nominal"
                            ),
                            ordinal_max_levels = 7L,
                            interaction = TRUE, contrasts = TRUE,
                            adjust = "holm", sink_to = NULL, verbose = TRUE) {
  not_empty(data)
  not_empty(outcome)
  design <- match.arg(design)
  outcome_type <- match.arg(outcome_type)
  .check_columns(data, c(outcome, predictors, cluster))

  # recommend_test() accepts this combination and writes a `cluster_id`
  # placeholder into its fit_call string, but there is nothing to fit a random
  # effect on, so the model would fail deep inside lme4 with "object cluster_id
  # not found".
  if (identical(design, "within") && is.null(cluster)) {
    stop(
      "`design = \"within\"` means repeated measures, so `cluster` must name the ",
      "column identifying the subject each measurement came from.",
      call. = FALSE
    )
  }

  rec <- recommend_test(
    data,
    outcome = outcome, predictors = predictors, cluster = cluster,
    design = design, outcome_type = outcome_type,
    ordinal_max_levels = ordinal_max_levels
  )

  data <- .fit_coerce(
    data, outcome, predictors, cluster,
    outcome_type = rec$outcome_type, verbose = verbose
  )

  if (isTRUE(verbose)) {
    message("Fitting: ", rec$recommendation, " via ", rec$model_function, "().")
  }
  fit <- .fit_dispatch(rec, data, interaction = interaction, verbose = verbose)

  con <- if (isTRUE(contrasts)) .fit_contrasts(fit, rec, data, adjust = adjust) else NULL
  emm <- NULL
  if (is.list(con) && !is.null(con$emmeans)) {
    emm <- con$emmeans
    con <- con$contrasts
  }

  # The reporters both message() their sentences and return them invisibly.
  # Take the return value and suppress the duplicate chatter: print.colley_fit()
  # shows them, and they are in $text either way.
  text <- NULL
  if (!is.na(fit$reporter)) {
    # Most reporters take the fitted model; ART's takes its ANOVA table.
    report_object <- if (is.null(fit$report_object)) fit$model else fit$report_object
    text <- tryCatch(
      suppressMessages(do.call(fit$reporter, list(report_object, dv = outcome))),
      error = function(e) {
        if (isTRUE(verbose)) {
          message(
            "Fitted, but could not build the report sentence automatically: ",
            conditionMessage(e)
          )
        }
        NULL
      }
    )
  }

  # The recommendation's fit_call is built by recommend_test() with main effects
  # only ("y ~ a + b"), while a factorial design is fitted with the interaction
  # ("y ~ a * b"). Left alone, $recommendation$fit_call would describe a
  # different model from $model -- in an object whose whole purpose is that the
  # two cannot drift apart. Record what was actually fitted.
  fitted_formula <- tryCatch(stats::formula(fit$model), error = function(e) NULL)
  if (!is.null(fitted_formula)) {
    rec$fit_call <- paste0(
      sub("::.*$", "", rec$model_function), "::",
      sub("^.*::", "", rec$model_function), "(",
      paste(deparse(fitted_formula), collapse = " "), ", data = your_data)"
    )
  }

  out <- list(
    recommendation = rec,
    formula = fitted_formula,
    model = fit$model,
    engine = fit$engine,
    reporter = fit$reporter,
    emmeans = emm,
    contrasts = con,
    methods = rec$methods_text,
    text = text,
    sentences = c(rec$methods_text, text)
  )
  class(out) <- "colley_fit"

  if (!is.null(sink_to)) {
    .write_tex(out$sentences, sink_to)
  }
  out
}


#' @export
print.colley_fit <- function(x, ...) {
  cat("<colleyRstats fitted analysis>\n")
  cat("  Outcome     : ", x$recommendation$outcome,
    " (", x$recommendation$outcome_type, ")\n",
    sep = ""
  )
  cat("  Model       : ", x$recommendation$recommendation,
    " [", x$engine, "]\n",
    sep = ""
  )
  if (!is.null(x$contrasts)) {
    cat("  Contrasts   : available in $contrasts\n")
  }
  if (!is.null(x$text)) {
    cat("  Reported as :\n")
    cat(paste0("    ", x$text, collapse = "\n"), "\n", sep = "")
  } else {
    cat("  Report with : summary(fit$model)\n")
  }
  cat("\n")
  # summary() of an htest is a structure table ("Length Class Mode"), not a
  # result; the object prints itself properly.
  if (inherits(x$model, "htest")) {
    print(x$model)
  } else {
    print(summary(x$model))
  }
  invisible(x)
}
