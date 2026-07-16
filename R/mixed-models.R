# Mixed-model support: a principled test-selection helper plus LaTeX/APA
# reporters for generalized linear mixed models (GLMM; lme4 / glmmTMB) and
# cumulative link mixed models (CLMM; ordinal). The heavy dependencies
# (lme4, ordinal, glmmTMB, parameters) live in Suggests, so every function
# here degrades gracefully via requireNamespace() rather than importing them.


#' Classify the measurement scale of an outcome variable
#'
#' Decides how a dependent variable should be modelled by inspecting its type
#' and distribution of values. The measurement scale is the first branch of a
#' principled model choice: it dictates the *family* (Gaussian, binomial,
#' Poisson, cumulative-link) before any distributional assumption is checked.
#'
#' The rules are deliberately simple and transparent:
#' \itemize{
#'   \item ordered factor \eqn{\rightarrow} \code{"ordinal"};
#'   \item logical, a two-level factor, or a numeric/character with exactly two
#'     distinct values \eqn{\rightarrow} \code{"binary"};
#'   \item unordered factor/character with more than two levels
#'     \eqn{\rightarrow} \code{"nominal"};
#'   \item integer-valued numeric with at most \code{ordinal_max_levels}
#'     distinct values (a Likert-type item) \eqn{\rightarrow} \code{"ordinal"};
#'   \item non-negative integer-valued numeric with more distinct values
#'     \eqn{\rightarrow} \code{"count"};
#'   \item any other numeric \eqn{\rightarrow} \code{"continuous"}.
#' }
#' The heuristics can never be perfect (a 1--7 Likert item and a small count are
#' genuinely ambiguous); pass an explicit \code{outcome_type} to
#' [recommend_test()] when you want to override them.
#'
#' @param y The outcome vector.
#' @param ordinal_max_levels Integer. Integer-valued numerics with at most this
#'   many distinct values are treated as ordinal (Likert-like). Default 7.
#'
#' @return A single string, one of \code{"continuous"}, \code{"ordinal"},
#'   \code{"binary"}, \code{"count"}, or \code{"nominal"}.
#' @export
#'
#' @examples
#' classify_outcome(rnorm(50)) # "continuous"
#' classify_outcome(factor(sample(1:5, 50, TRUE), ordered = TRUE)) # "ordinal"
#' classify_outcome(sample(0:1, 50, TRUE)) # "binary"
#' classify_outcome(rpois(50, 3)) # "count"
classify_outcome <- function(y, ordinal_max_levels = 7L) {
  not_empty(y)

  if (is.ordered(y)) {
    return("ordinal")
  }
  if (is.factor(y)) {
    return(if (nlevels(y) <= 2L) "binary" else "nominal")
  }
  if (is.logical(y)) {
    return("binary")
  }
  if (is.character(y)) {
    return(if (length(unique(stats::na.omit(y))) <= 2L) "binary" else "nominal")
  }
  if (is.numeric(y)) {
    vals <- stats::na.omit(y)
    if (length(vals) == 0L) {
      stop("`y` has no non-missing values to classify.", call. = FALSE)
    }
    n_uniq <- length(unique(vals))
    if (n_uniq <= 2L) {
      return("binary")
    }
    is_integer_valued <- all(abs(vals - round(vals)) < .Machine$double.eps^0.5)
    if (is_integer_valued && n_uniq <= ordinal_max_levels) {
      return("ordinal")
    }
    if (is_integer_valued && min(vals) >= 0) {
      return("count")
    }
    return("continuous")
  }

  stop(
    "Cannot classify an outcome of class ",
    paste(class(y), collapse = "/"), ".",
    call. = FALSE
  )
}


# Internal: is a predictor a grouping variable (categorical) rather than a
# continuous covariate? Few-valued numerics count as grouping.
.is_grouping <- function(v, max_levels = 10L) {
  is.factor(v) || is.character(v) || is.logical(v) ||
    (is.numeric(v) && length(unique(stats::na.omit(v))) <= max_levels)
}


#' Recommend a principled analysis for one outcome
#'
#' Works out, from the data alone, which statistical model is appropriate for a
#' given outcome and set of predictors, and -- crucially -- *why*. The decision
#' follows a transparent three-question tree:
#' \enumerate{
#'   \item \strong{What is the outcome's measurement scale?}
#'     (via [classify_outcome()]: continuous, ordinal, binary, count, nominal.)
#'     This fixes the model family.
#'   \item \strong{Are the observations independent or clustered?}
#'     A repeated-measures / clustered design (a \code{cluster} id is supplied,
#'     or \code{design = "within"}) needs random effects, i.e. a *mixed* model.
#'   \item \strong{For a continuous outcome, do the parametric assumptions
#'     hold?} Group-wise normality (Shapiro--Wilk) and, for between-subjects
#'     designs, homogeneity of variance (Levene) decide between a parametric
#'     test and a non-parametric / rank-based alternative.
#' }
#'
#' The recommendation therefore ranges over ordinary ANOVA / t-tests, rank-based
#' methods (Kruskal--Wallis + Dunn, Wilcoxon, the Aligned Rank Transform, nparLD),
#' generalized linear models, cumulative link models, and their mixed-model
#' counterparts -- linear mixed models (LMM), generalized linear mixed models
#' (GLMM, \code{lme4}/\code{glmmTMB}) and cumulative link mixed models (CLMM,
#' \code{ordinal}).
#'
#' @param data The data frame.
#' @param outcome The dependent variable (column name as string).
#' @param predictors Optional character vector of predictor (independent
#'   variable) column names.
#' @param cluster Optional column name identifying the subject/cluster for
#'   repeated-measures or otherwise non-independent data (the random-effect
#'   grouping factor).
#' @param design One of \code{"auto"} (default; clustered when \code{cluster} is
#'   given), \code{"between"}, or \code{"within"}.
#' @param outcome_type One of \code{"auto"} (default; use [classify_outcome()])
#'   or an explicit \code{"continuous"}, \code{"ordinal"}, \code{"binary"},
#'   \code{"count"}, \code{"nominal"} to override the automatic classification.
#' @param ordinal_max_levels Passed to [classify_outcome()]. Default 7.
#'
#' @return An object of class \code{"colley_recommendation"} (a list) with
#'   components including \code{outcome_type}, \code{clustered}, \code{family},
#'   \code{recommendation} (human-readable label), \code{model_function} (the
#'   R function to call, e.g. \code{"ordinal::clmm"}), \code{reporter} (the
#'   matching colleyRstats reporter), \code{fit_call} (a ready-to-edit call as a
#'   string), \code{alternatives}, \code{rationale}, and \code{methods_text} (an
#'   APA-style sentence). A \code{print} method summarises it.
#' @export
#'
#' @examples
#' set.seed(1)
#' d <- data.frame(
#'   id    = factor(rep(1:20, each = 3)),
#'   cond  = factor(rep(c("A", "B", "C"), times = 20)),
#'   score = rnorm(60),
#'   rating = factor(sample(1:5, 60, TRUE), ordered = TRUE)
#' )
#' # Ordinal outcome measured repeatedly within subject -> CLMM
#' recommend_test(d, outcome = "rating", predictors = "cond", cluster = "id")
#' # Continuous, between-subjects -> ANOVA or its rank-based fallback
#' recommend_test(d, outcome = "score", predictors = "cond")
recommend_test <- function(data, outcome, predictors = NULL, cluster = NULL,
                           design = c("auto", "between", "within"),
                           outcome_type = c(
                             "auto", "continuous", "ordinal",
                             "binary", "count", "nominal"
                           ),
                           ordinal_max_levels = 7L) {
  not_empty(data)
  not_empty(outcome)
  design <- match.arg(design)
  outcome_type <- match.arg(outcome_type)
  .check_columns(data, c(outcome, predictors))
  if (!is.null(cluster)) {
    stopifnot(length(cluster) == 1L)
    .check_columns(data, cluster)
  }

  if (identical(outcome_type, "auto")) {
    outcome_type <- classify_outcome(data[[outcome]], ordinal_max_levels = ordinal_max_levels)
  }

  clustered <- !is.null(cluster) || identical(design, "within")
  design_resolved <- if (identical(design, "auto")) {
    if (clustered) "within" else "between"
  } else {
    design
  }

  # --- assumption checks (only meaningful for a continuous outcome compared
  # across a single grouping predictor) -------------------------------------
  normal <- NA
  homogeneous <- NA
  primary <- if (!is.null(predictors) && length(predictors) >= 1L) predictors[[1L]] else NULL
  grouping_primary <- !is.null(primary) && .is_grouping(data[[primary]])
  if (identical(outcome_type, "continuous") && grouping_primary) {
    normal <- tryCatch(
      isTRUE(as.logical(check_normality_by_group(data, primary, outcome))),
      error = function(e) NA
    )
    if (!clustered && requireNamespace("rstatix", quietly = TRUE)) {
      homogeneous <- tryCatch(
        isTRUE(as.logical(check_homogeneity_by_group(data, primary, outcome))),
        error = function(e) NA
      )
    }
  }

  rec <- .build_recommendation(
    outcome = outcome, outcome_type = outcome_type, predictors = predictors,
    cluster = cluster, clustered = clustered, grouping_primary = grouping_primary,
    primary = primary, data = data, normal = normal, homogeneous = homogeneous
  )

  n_clusters <- if (!is.null(cluster)) length(unique(stats::na.omit(data[[cluster]]))) else NA_integer_

  out <- list(
    outcome = outcome,
    outcome_type = outcome_type,
    predictors = predictors,
    cluster = cluster,
    clustered = clustered,
    design = design_resolved,
    n_obs = nrow(data),
    n_clusters = n_clusters,
    family = rec$family,
    assumptions = list(normal = normal, homogeneous = homogeneous),
    recommendation = rec$recommendation,
    model_function = rec$model_function,
    reporter = rec$reporter,
    fit_call = rec$fit_call,
    alternatives = rec$alternatives,
    rationale = rec$rationale
  )
  out$methods_text <- .recommendation_methods_text(out)
  class(out) <- "colley_recommendation"
  out
}


# Internal: turn the resolved (outcome type, clustering, assumptions) state into
# a concrete model recommendation. Returns a plain list.
.build_recommendation <- function(outcome, outcome_type, predictors, cluster,
                                   clustered, grouping_primary, primary, data,
                                   normal, homogeneous) {
  fixed_rhs <- if (is.null(predictors)) "1" else paste(predictors, collapse = " + ")
  cl <- if (is.null(cluster)) "cluster_id" else cluster
  re_term <- if (clustered) paste0(" + (1 | ", cl, ")") else ""
  formula_str <- paste0(outcome, " ~ ", fixed_rhs, re_term)

  n_groups <- if (grouping_primary) length(unique(stats::na.omit(data[[primary]]))) else NA_integer_
  factorial <- !is.null(predictors) && length(predictors) > 1L

  make <- function(recommendation, model_function, reporter, fit_call,
                   rationale, family = NA_character_, alternatives = character(0)) {
    list(
      recommendation = recommendation, model_function = model_function,
      reporter = reporter, fit_call = fit_call, rationale = rationale,
      family = family, alternatives = alternatives
    )
  }

  switch(outcome_type,
    ordinal = if (clustered) {
      make(
        "Cumulative Link Mixed Model (CLMM)", "ordinal::clmm", "reportCLMM",
        paste0("ordinal::clmm(", formula_str, ", data = your_data)  # outcome must be an ordered factor"),
        "the outcome is ordinal and the observations are clustered, so an ordinal (proportional-odds) model with a random effect is appropriate",
        family = "cumulative link (logit)",
        alternatives = "nparLD (rank-based repeated measures) if proportional odds is untenable"
      )
    } else {
      make(
        "Cumulative Link Model (CLM, proportional odds)", "ordinal::clm", "reportCLMM",
        paste0("ordinal::clm(", outcome, " ~ ", fixed_rhs, ", data = your_data)  # outcome must be an ordered factor"),
        "the outcome is ordinal and the observations are independent, so a proportional-odds cumulative link model is appropriate",
        family = "cumulative link (logit)",
        alternatives = if (isTRUE(n_groups == 2L)) {
          "Mann-Whitney U (wilcox.test) as a rank-based alternative"
        } else {
          "Kruskal-Wallis + Dunn's test (reportDunnTest) as a rank-based alternative"
        }
      )
    },
    binary = if (clustered) {
      make(
        "Generalized Linear Mixed Model (GLMM), binomial", "lme4::glmer", "reportGLMM",
        paste0("lme4::glmer(", formula_str, ", data = your_data, family = binomial)"),
        "the outcome is binary and the observations are clustered, so a mixed-effects logistic regression is appropriate",
        family = "binomial (logit)",
        alternatives = "glmmTMB::glmmTMB(..., family = binomial) for more flexible random structures"
      )
    } else {
      make(
        "Logistic regression (GLM, binomial)", "stats::glm", "reportGLMM",
        paste0("stats::glm(", outcome, " ~ ", fixed_rhs, ", data = your_data, family = binomial)"),
        "the outcome is binary and the observations are independent, so logistic regression is appropriate",
        family = "binomial (logit)",
        alternatives = "chi-squared / Fisher's exact test for a simple two-way contingency"
      )
    },
    count = if (clustered) {
      make(
        "Generalized Linear Mixed Model (GLMM), Poisson/NB", "lme4::glmer", "reportGLMM",
        paste0("lme4::glmer(", formula_str, ", data = your_data, family = poisson)  # use glmmTMB nbinom2 if over-dispersed"),
        "the outcome is a count and the observations are clustered, so a mixed-effects Poisson (or negative-binomial) model is appropriate",
        family = "poisson (log)",
        alternatives = "glmmTMB::glmmTMB(..., family = nbinom2) when the counts are over-dispersed"
      )
    } else {
      make(
        "Poisson/NB regression (GLM)", "stats::glm", "reportGLMM",
        paste0("stats::glm(", outcome, " ~ ", fixed_rhs, ", data = your_data, family = poisson)"),
        "the outcome is a count and the observations are independent, so Poisson (or negative-binomial) regression is appropriate",
        family = "poisson (log)",
        alternatives = "MASS::glm.nb() when the counts are over-dispersed"
      )
    },
    nominal = make(
      "Multinomial logistic regression", "nnet::multinom", NA_character_,
      paste0("nnet::multinom(", outcome, " ~ ", fixed_rhs, ", data = your_data)",
        if (clustered) "  # clustered: consider mclogit::mblogit or a Bayesian multilevel model" else ""),
      "the outcome is unordered categorical with more than two levels, so a multinomial model is appropriate",
      family = "multinomial",
      alternatives = "collapse to a binary outcome and use logistic regression if the research question allows"
    ),
    continuous = .recommend_continuous(
      outcome, predictors, fixed_rhs, formula_str, clustered, cl,
      grouping_primary, n_groups, factorial, normal, homogeneous, make
    )
  )
}


# Internal: the continuous-outcome branch, where assumption checks select
# between a parametric model and a rank-based / mixed alternative.
.recommend_continuous <- function(outcome, predictors, fixed_rhs, formula_str,
                                   clustered, cl, grouping_primary, n_groups,
                                   factorial, normal, homogeneous, make) {
  # A continuous predictor (regression) rather than group comparison.
  if (!is.null(predictors) && !grouping_primary) {
    if (clustered) {
      return(make(
        "Linear Mixed Model (LMM)", "lme4::lmer", "reportGLMM",
        paste0("lme4::lmer(", formula_str, ", data = your_data)"),
        "the outcome is continuous with a continuous predictor and clustered observations, so a linear mixed model is appropriate",
        family = "gaussian",
        alternatives = "add lmerTest for Satterthwaite p-values"
      ))
    }
    return(make(
      "Linear regression (lm)", "stats::lm", "reportGLMM",
      paste0("stats::lm(", outcome, " ~ ", fixed_rhs, ", data = your_data)"),
      "the outcome is continuous with a continuous predictor and independent observations, so linear regression is appropriate",
      family = "gaussian",
      alternatives = "check residual normality; use a robust or rank-based fit if it is violated"
    ))
  }

  # Group comparison. normal == NA means it could not be assessed -> be cautious.
  is_normal <- isTRUE(normal)
  assessable <- !is.na(normal)

  if (clustered) {
    # Normal, or normality could not be assessed: default to a linear mixed
    # model (the standard modern approach for repeated continuous data). Only a
    # detected departure from normality steers us to a rank-based method.
    if (is_normal || !assessable) {
      return(make(
        "Linear Mixed Model (LMM) / parametric within-subjects", "lme4::lmer", "reportGLMM",
        paste0("lme4::lmer(", formula_str, ", data = your_data)  # or ggwithinstatsWithPriorNormalityCheck() for a figure + test"),
        paste0(
          "the outcome is continuous",
          if (assessable) ", approximately normal," else "",
          " and measured repeatedly, so a linear mixed model (parametric within-subjects) is appropriate",
          if (!assessable) "; check the residuals, as group-wise normality could not be assessed" else ""
        ),
        family = "gaussian",
        alternatives = "ggwithinstatsWithPriorNormalityCheck() to obtain the figure and omnibus test together"
      ))
    }
    # non-normal (or un-assessable) repeated measures
    return(make(
      if (factorial) "Aligned Rank Transform (ART), repeated measures" else "Rank-based repeated measures (nparLD)",
      if (factorial) "ARTool::art" else "nparLD::nparLD",
      if (factorial) "reportArtCon" else "reportNparLD",
      if (factorial) {
        paste0("ARTool::art(", outcome, " ~ ", fixed_rhs, " + (1 | ", cl, "), data = your_data)")
      } else {
        within_factor <- if (length(predictors)) predictors[[1L]] else "time"
        paste0("nparLD::nparLD(", outcome, " ~ ", within_factor, ", subject = \"", cl, "\", data = your_data)")
      },
      paste0(
        "the outcome is continuous but ",
        if (assessable) "non-normal" else "normality could not be assessed",
        " and measured repeatedly, so a rank-based repeated-measures method is safer than a parametric mixed model"
      ),
      family = "gaussian (rank-based)",
      alternatives = "a linear mixed model (lme4::lmer) if a suitable transformation restores normality"
    ))
  }

  # between-subjects group comparison
  if (is_normal && !isFALSE(homogeneous)) {
    return(make(
      if (factorial) "Factorial ANOVA (parametric)" else if (isTRUE(n_groups == 2L)) "t-test (parametric)" else "One-way ANOVA (parametric)",
      "stats::aov", "reportggstatsplot",
      paste0("ggbetweenstatsWithPriorNormalityCheck(data = your_data, x = \"",
        if (length(predictors)) predictors[[1L]] else "group", "\", y = \"", outcome, "\")"),
      paste0(
        "the outcome is continuous and normally distributed",
        if (isFALSE(homogeneous)) "" else " with homogeneous variances",
        ", so a parametric ", if (isTRUE(n_groups == 2L)) "t-test" else "ANOVA", " is appropriate"
      ),
      family = "gaussian",
      alternatives = if (isFALSE(homogeneous)) "Welch's correction for unequal variances" else "none needed"
    ))
  }
  if (is_normal && isFALSE(homogeneous)) {
    return(make(
      if (isTRUE(n_groups == 2L)) "Welch's t-test" else "Welch's ANOVA",
      "stats::oneway.test", "reportggstatsplot",
      paste0("stats::oneway.test(", outcome, " ~ ", fixed_rhs, ", data = your_data, var.equal = FALSE)"),
      "the outcome is continuous and normal but the group variances are unequal, so a Welch-corrected test is appropriate",
      family = "gaussian",
      alternatives = "a rank-based test if normality is also doubtful"
    ))
  }
  # non-normal or un-assessable
  make(
    if (factorial) "Aligned Rank Transform (ART)" else if (isTRUE(n_groups == 2L)) "Mann-Whitney U test" else "Kruskal-Wallis + Dunn's test",
    if (factorial) "ARTool::art" else if (isTRUE(n_groups == 2L)) "stats::wilcox.test" else "stats::kruskal.test",
    if (factorial) "reportArtCon" else if (isTRUE(n_groups == 2L)) NA_character_ else "reportDunnTest",
    if (factorial) {
      paste0("ARTool::art(", outcome, " ~ ", fixed_rhs, ", data = your_data)")
    } else if (isTRUE(n_groups == 2L)) {
      paste0("stats::wilcox.test(", outcome, " ~ ", fixed_rhs, ", data = your_data)")
    } else {
      paste0("stats::kruskal.test(", outcome, " ~ ", fixed_rhs, ", data = your_data)  # follow up with FSA::dunnTest() + reportDunnTest()")
    },
    paste0(
      "the outcome is continuous but ",
      if (!is.na(normal)) "significantly non-normal" else "normality could not be assessed",
      ", so a rank-based test is safer than a parametric one"
    ),
    family = "gaussian (rank-based)",
    alternatives = "a parametric test if a transformation (e.g. log) restores normality"
  )
}


# Internal: assemble the APA-style methods sentence for a recommendation.
.recommendation_methods_text <- function(x) {
  type_desc <- switch(x$outcome_type,
    continuous = "continuous",
    ordinal = "ordinal",
    binary = "binary",
    count = "a count",
    nominal = "unordered categorical (nominal)"
  )
  dependence <- if (x$clustered) {
    paste0(
      "the observations are clustered",
      if (!is.null(x$cluster)) paste0(" within `", x$cluster, "`") else "",
      if (!is.na(x$n_clusters)) paste0(" (", x$n_clusters, " clusters, ", x$n_obs, " observations)") else ""
    )
  } else {
    "the observations are independent"
  }
  assumption_clause <- ""
  if (identical(x$outcome_type, "continuous") && !is.na(x$assumptions$normal)) {
    assumption_clause <- if (isTRUE(x$assumptions$normal)) {
      " Group-wise Shapiro-Wilk tests indicated no significant departure from normality."
    } else {
      " Group-wise Shapiro-Wilk tests indicated a significant departure from normality."
    }
  }
  paste0(
    "The outcome `", x$outcome, "` is ", type_desc, ", and ", dependence, ".",
    assumption_clause,
    " A ", x$recommendation, " (`", x$model_function, "`) is therefore recommended",
    if (!is.na(x$reporter)) paste0("; report it with `", x$reporter, "()`.") else "."
  )
}


#' @export
print.colley_recommendation <- function(x, ...) {
  cat("<colleyRstats analysis recommendation>\n")
  cat("  Outcome        : ", x$outcome, " (", x$outcome_type, ")\n", sep = "")
  cat("  Predictors     : ", if (is.null(x$predictors)) "(none)" else paste(x$predictors, collapse = ", "), "\n", sep = "")
  cat("  Design         : ", x$design,
    if (x$clustered && !is.null(x$cluster)) paste0(" (cluster: ", x$cluster, ")") else "", "\n", sep = "")
  if (identical(x$outcome_type, "continuous") && !is.na(x$assumptions$normal)) {
    cat("  Normality      : ", if (isTRUE(x$assumptions$normal)) "not rejected" else "rejected", "\n", sep = "")
    if (!is.na(x$assumptions$homogeneous)) {
      cat("  Homogeneity    : ", if (isTRUE(x$assumptions$homogeneous)) "not rejected" else "rejected", "\n", sep = "")
    }
  }
  cat("  Recommendation : ", x$recommendation, "\n", sep = "")
  if (!is.na(x$family)) cat("  Family         : ", x$family, "\n", sep = "")
  cat("  Fit with       : ", x$fit_call, "\n", sep = "")
  if (!is.na(x$reporter)) cat("  Report with    : ", x$reporter, "()\n", sep = "")
  if (length(x$alternatives)) cat("  Alternative(s) : ", paste(x$alternatives, collapse = "; "), "\n", sep = "")
  cat("  Rationale      : ", x$rationale, "\n", sep = "")
  invisible(x)
}


# -------------------------------------------------------------------------
# Reporters for mixed models
# -------------------------------------------------------------------------

# Internal: describe a fitted model (kind, family, whether to exponentiate the
# coefficients, and the effect-size label to print).
.mixed_model_info <- function(model) {
  is_cumulative <- inherits(model, c("clmm", "clm", "clmm2"))
  family_name <- if (is_cumulative) {
    "cumulative link"
  } else {
    tryCatch(stats::family(model)$family, error = function(e) NA_character_)
  }
  has_random <- inherits(model, c(
    "merMod", "lmerMod", "glmerMod", "lmerModLmerTest",
    "glmmTMB", "clmm", "clmm2"
  ))
  gaussian <- !is.na(family_name) && identical(family_name, "gaussian")

  exponentiate <- FALSE
  effect_label <- "b"
  if (is_cumulative) {
    exponentiate <- TRUE
    effect_label <- "OR"
  } else if (!is.na(family_name)) {
    if (identical(family_name, "binomial")) {
      exponentiate <- TRUE
      effect_label <- "OR"
    } else if (grepl("poisson|nbinom|negative binomial|genpois", family_name, ignore.case = TRUE)) {
      exponentiate <- TRUE
      effect_label <- "IRR"
    }
  }

  kind <- if (inherits(model, c("clmm", "clmm2"))) {
    "cumulative link mixed model"
  } else if (inherits(model, "clm")) {
    "cumulative link model"
  } else if (has_random && gaussian) {
    "linear mixed model"
  } else if (has_random) {
    "generalized linear mixed model"
  } else if (gaussian) {
    "linear model"
  } else {
    "generalized linear model"
  }

  list(
    kind = kind, family = family_name, exponentiate = exponentiate,
    effect_label = effect_label, is_cumulative = is_cumulative,
    gaussian = gaussian, has_random = has_random
  )
}


# Internal: tidy the fixed-effect (location) coefficients of a mixed model into
# a data frame, dropping thresholds/intercept and normalising the statistic
# column to `.stat` / `.stat_name`.
.mixed_fixed_effects <- function(model, exponentiate = FALSE, conf_level = 0.95,
                                 include_intercept = FALSE) {
  pars <- tryCatch(
    parameters::model_parameters(model, effects = "fixed", exponentiate = exponentiate, ci = conf_level),
    error = function(e) parameters::model_parameters(model, exponentiate = exponentiate, ci = conf_level)
  )
  df <- as.data.frame(pars)

  if ("Effects" %in% names(df)) {
    df <- df[df$Effects == "fixed", , drop = FALSE]
  }
  # cumulative-link thresholds are named like "1|2"; never report them
  df <- df[!grepl("|", df$Parameter, fixed = TRUE), , drop = FALSE]
  if (!isTRUE(include_intercept)) {
    df <- df[df$Parameter != "(Intercept)", , drop = FALSE]
  }

  stat_col <- intersect(c("t", "z", "Statistic", "F"), names(df))
  stat_col <- if (length(stat_col)) stat_col[[1L]] else NA_character_
  df$.stat <- if (!is.na(stat_col)) df[[stat_col]] else NA_real_
  df$.stat_name <- stat_col
  if (!"df_error" %in% names(df)) df$df_error <- NA_real_
  rownames(df) <- NULL
  df
}


# Internal: format a test statistic, e.g. "$t(55) = 2.31$" or "$z = 2.55$".
.fmt_stat <- function(stat_name, value, df_error = NA_real_) {
  if (is.na(stat_name) || is.na(value)) {
    return("")
  }
  if (identical(stat_name, "t") && !is.na(df_error) && is.finite(df_error)) {
    df_txt <- if (abs(df_error - round(df_error)) < 1e-6) {
      format(round(df_error))
    } else {
      .fmt_num(df_error, 1)
    }
    return(paste0("$t(", df_txt, ") = ", .fmt_num(value), "$"))
  }
  label <- if (identical(stat_name, "Statistic")) "z" else stat_name
  paste0("$", label, " = ", .fmt_num(value), "$")
}


# Internal: shared workhorse for reportGLMM()/reportCLMM().
.report_mixed <- function(model, dv, info, exponentiate, include_intercept,
                          conf_level, alpha, write_to_clipboard, sink_to) {
  eff <- .mixed_fixed_effects(
    model,
    exponentiate = exponentiate, conf_level = conf_level,
    include_intercept = include_intercept
  )

  dv_tex <- latex_escape(dv)
  intro <- paste0("A ", info$kind, " was fitted for ", dv_tex, ".")

  if (nrow(eff) == 0L) {
    intro <- paste0(intro, " No fixed-effect terms were available to report.")
    message(intro)
    if (write_to_clipboard) .write_clipboard(intro)
    if (!is.null(sink_to)) .write_tex(intro, sink_to)
    return(invisible(intro))
  }

  ci_pct <- format(round(conf_level * 100))
  label <- if (exponentiate) info$effect_label else "b"

  sentences <- character(0)
  for (i in seq_len(nrow(eff))) {
    row <- eff[i, ]
    est <- .fmt_num(row$Coefficient)
    ci <- paste0("[", .fmt_num(row$CI_low), ", ", .fmt_num(row$CI_high), "]")
    stat_txt <- .fmt_stat(row$.stat_name, row$.stat, row$df_error)
    # A fixed effect can have an un-estimable p-value (NA) when the model is
    # rank-deficient or the optimiser did not converge for that term; report it
    # as un-assessable rather than crashing or claiming non-significance.
    p_na <- is.na(row$p)
    p_macro <- if (p_na) "$p$ = NA" else .fmt_p_macro(row$p)
    significant <- !p_na && row$p < alpha

    clause <- paste0(
      "$", label, " = ", est, "$, ", ci_pct, "\\% CI $", ci, "$",
      if (nzchar(stat_txt)) paste0(", ", stat_txt) else "",
      ", ", p_macro
    )
    sentence <- if (p_na) {
      paste0(
        "The effect of \\textit{", latex_escape(row$Parameter), "} on ", dv_tex,
        " could not be assessed (", clause, ")."
      )
    } else {
      paste0(
        "The effect of \\textit{", latex_escape(row$Parameter), "} on ", dv_tex, " was ",
        if (significant) "significant" else "not significant",
        " (", clause, ")."
      )
    }
    sentences <- c(sentences, sentence)
  }

  all_sentences <- c(intro, sentences)
  for (s in all_sentences) message(s)
  if (write_to_clipboard) .write_clipboard(paste(all_sentences, collapse = " "))
  if (!is.null(sink_to)) .write_tex(all_sentences, sink_to)
  invisible(all_sentences)
}


#' Report a (generalized) linear mixed model in LaTeX/APA style
#'
#' Turns a fitted mixed model into ready-to-paste manuscript sentences, one per
#' fixed-effect term, with the coefficient (or odds/incidence-rate ratio for
#' non-Gaussian families), its confidence interval, the test statistic, and the
#' p-value. Works with linear mixed models (\code{lme4::lmer}), generalized
#' linear mixed models (\code{lme4::glmer}, \code{glmmTMB::glmmTMB}) and, for
#' convenience, ordinary \code{lm}/\code{glm} fits. Coefficients are
#' exponentiated automatically for binomial (odds ratios) and Poisson/negative-
#' binomial (incidence-rate ratios) families.
#'
#' The reported statistics rely on the \pkg{parameters} package. The LaTeX
#' output uses the \code{\\p}/\code{\\pminor} macros from [latex_preamble()].
#'
#' @param model A fitted model (\code{lmer}, \code{glmer}, \code{glmmTMB},
#'   \code{lm}, or \code{glm}).
#' @param dv Name of the dependent variable, used in the sentence text.
#' @param exponentiate \code{"auto"} (default; exponentiate for binomial and
#'   count families), or \code{TRUE}/\code{FALSE} to force it.
#' @param include_intercept Whether to also report the intercept. Default
#'   \code{FALSE}.
#' @param conf_level Confidence level for the intervals. Default 0.95.
#' @param write_to_clipboard Whether to copy the sentences to the clipboard.
#' @param sink_to Optional path of a \code{.tex} file to write the sentences to,
#'   so a manuscript can \code{\\input{}} them.
#'
#' @return Invisibly returns the reported sentence(s) as a character vector; the
#'   text is also emitted via \code{message()}.
#' @export
#'
#' @examples
#' \donttest{
#' if (requireNamespace("lme4", quietly = TRUE) &&
#'   requireNamespace("parameters", quietly = TRUE)) {
#'   m <- lme4::lmer(Reaction ~ Days + (1 | Subject), data = lme4::sleepstudy)
#'   reportGLMM(m, dv = "reaction time")
#' }
#' }
reportGLMM <- function(model, dv = "Testdependentvariable", exponentiate = "auto",
                       include_intercept = FALSE, conf_level = 0.95,
                       write_to_clipboard = FALSE, sink_to = NULL) {
  not_empty(model)
  not_empty(dv)
  if (!requireNamespace("parameters", quietly = TRUE)) {
    stop("Package 'parameters' is required for reportGLMM(). Please install it.", call. = FALSE)
  }

  info <- .mixed_model_info(model)
  exp <- if (identical(exponentiate, "auto")) info$exponentiate else isTRUE(exponentiate)

  .report_mixed(
    model = model, dv = dv, info = info, exponentiate = exp,
    include_intercept = include_intercept, conf_level = conf_level,
    alpha = 0.05, write_to_clipboard = write_to_clipboard, sink_to = sink_to
  )
}


#' Report a cumulative link (mixed) model in LaTeX/APA style
#'
#' Reporter for ordinal proportional-odds models fitted with \pkg{ordinal}:
#' cumulative link mixed models (\code{ordinal::clmm}) and their fixed-effects
#' counterpart (\code{ordinal::clm}). Each location (predictor) effect is
#' reported as an odds ratio -- the multiplicative change in the odds of being
#' in a higher outcome category for a one-unit increase in the predictor -- with
#' its confidence interval, z statistic and p-value. The threshold (cut-point)
#' coefficients are omitted, as is conventional.
#'
#' @param model A fitted \code{ordinal::clmm} or \code{ordinal::clm} model.
#' @param dv Name of the (ordinal) dependent variable, used in the sentence text.
#' @param exponentiate \code{"auto"} (default; report odds ratios) or
#'   \code{TRUE}/\code{FALSE} to force it. \code{FALSE} reports raw log-odds.
#' @param conf_level Confidence level for the intervals. Default 0.95.
#' @param write_to_clipboard Whether to copy the sentences to the clipboard.
#' @param sink_to Optional path of a \code{.tex} file to write the sentences to.
#'
#' @details The threshold (cut-point) parameters are never reported, so unlike
#'   [reportGLMM()] this reporter has no \code{include_intercept} argument.
#'
#' @return Invisibly returns the reported sentence(s) as a character vector; the
#'   text is also emitted via \code{message()}.
#' @export
#'
#' @examples
#' \donttest{
#' if (requireNamespace("ordinal", quietly = TRUE) &&
#'   requireNamespace("parameters", quietly = TRUE)) {
#'   m <- ordinal::clmm(rating ~ temp + contact + (1 | judge), data = ordinal::wine)
#'   reportCLMM(m, dv = "wine rating")
#' }
#' }
reportCLMM <- function(model, dv = "Testdependentvariable", exponentiate = "auto",
                       conf_level = 0.95,
                       write_to_clipboard = FALSE, sink_to = NULL) {
  not_empty(model)
  not_empty(dv)
  if (!inherits(model, c("clmm", "clm", "clmm2"))) {
    stop(
      "reportCLMM() expects an ordinal::clmm or ordinal::clm model; ",
      "got an object of class ", paste(class(model), collapse = "/"),
      ". Use reportGLMM() for lme4/glmmTMB models.",
      call. = FALSE
    )
  }
  if (!requireNamespace("parameters", quietly = TRUE)) {
    stop("Package 'parameters' is required for reportCLMM(). Please install it.", call. = FALSE)
  }

  info <- .mixed_model_info(model)
  exp <- if (identical(exponentiate, "auto")) info$exponentiate else isTRUE(exponentiate)

  .report_mixed(
    model = model, dv = dv, info = info, exponentiate = exp,
    include_intercept = FALSE, conf_level = conf_level,
    alpha = 0.05, write_to_clipboard = write_to_clipboard, sink_to = sink_to
  )
}
