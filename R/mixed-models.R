# Mixed-model support: a principled test-selection helper plus LaTeX/APA
# reporters for generalized linear mixed models (GLMM; lme4 / glmmTMB) and
# cumulative link mixed models (CLMM; ordinal). The heavy dependencies
# (lme4, ordinal, glmmTMB, parameters, emmeans, car, performance) live in
# Suggests, so every function here degrades gracefully via requireNamespace()
# rather than importing them.


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
#'   \item logical, a factor with two observed levels, a character vector with
#'     two distinct values, or a numeric coded \code{0}/\code{1}
#'     \eqn{\rightarrow} \code{"binary"};
#'   \item unordered factor/character with more than two levels
#'     \eqn{\rightarrow} \code{"nominal"};
#'   \item a numeric with at most two distinct values that are \emph{not}
#'     \code{0}/\code{1} -- a 1--7 item on which only 6 and 7 were ticked, or a
#'     yes/no item coded 1/2 -- is \emph{not} taken for binary: it is classified
#'     as \code{"ordinal"} (whole numbers) or \code{"continuous"}, with a
#'     warning;
#'   \item integer-valued numeric with at most \code{ordinal_max_levels}
#'     distinct values (a Likert-type item) \eqn{\rightarrow} \code{"ordinal"};
#'   \item non-negative whole numbers that are all multiples of 5 within
#'     \eqn{[0, 100]} (the shape of a raw NASA-TLX subscale or a 0--100 slider
#'     in steps of 5) \eqn{\rightarrow} \code{"continuous"}, with a message;
#'   \item any other non-negative whole numbers \eqn{\rightarrow}
#'     \code{"count"}. This is always announced with a message that says how to
#'     override it, and the message becomes a \emph{warning} when the values
#'     lie in a closed range without zeros (\eqn{[1, 100]}) -- the typical
#'     shape of a summed questionnaire score or a 1--10 rating, which a Poisson
#'     model would misdescribe;
#'   \item any other numeric \eqn{\rightarrow} \code{"continuous"}.
#' }
#' The heuristics can never be perfect (a 1--7 Likert item and a small count are
#' genuinely ambiguous); pass an explicit \code{outcome_type} to
#' [recommend_test()] or [fit_recommended()] when you want to override them.
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
#' classify_outcome(rpois(50, 3)) # "count", with a message
classify_outcome <- function(y, ordinal_max_levels = 7L) {
  not_empty(y)
  .classify_outcome(y, ordinal_max_levels = ordinal_max_levels, name = NULL)
}


# Internal: the classifier behind classify_outcome(). `name` (the column name)
# makes the messages say which outcome they are about when recommend_test()
# classifies a column of a data frame.
.classify_outcome <- function(y, ordinal_max_levels = 7L, name = NULL) {
  what <- if (is.null(name)) "The outcome" else paste0("`", name, "`")

  if (is.ordered(y)) {
    return("ordinal")
  }
  if (is.factor(y)) {
    # Count the levels that occur: an unused level is not a category the model
    # can estimate anything for.
    return(if (length(unique(stats::na.omit(y))) <= 2L) "binary" else "nominal")
  }
  if (is.logical(y)) {
    return("binary")
  }
  if (is.character(y)) {
    return(if (length(unique(stats::na.omit(y))) <= 2L) "binary" else "nominal")
  }
  if (is.numeric(y)) {
    vals <- y[!is.na(y)]
    if (length(vals) == 0L) {
      stop("`y` has no non-missing values to classify.", call. = FALSE)
    }
    uniq <- sort(unique(vals))
    n_uniq <- length(uniq)
    is_integer_valued <- all(abs(vals - round(vals)) < .Machine$double.eps^0.5)

    if (n_uniq <= 2L) {
      # Only a 0/1 coding says "binary". Two observed values on a longer scale
      # (a 1-7 item where everyone ticked 6 or 7) are a restricted range, not a
      # binary outcome, and a logistic model would answer the wrong question.
      if (all(uniq %in% c(0, 1))) {
        return("binary")
      }
      type <- if (is_integer_valued && n_uniq <= ordinal_max_levels) "ordinal" else "continuous"
      warning(
        what, if (n_uniq == 1L) " is constant (every value is " else " has only two distinct values (",
        paste(format(uniq, trim = TRUE), collapse = ", "), "), not coded 0/1, so it is not ",
        "treated as binary but classified as ", type, ". If it is a binary outcome, recode it ",
        "to 0/1 or a two-level factor, or pass outcome_type = \"binary\".",
        call. = FALSE
      )
      return(type)
    }
    if (is_integer_valued && n_uniq <= ordinal_max_levels) {
      return("ordinal")
    }
    if (is_integer_valued && min(vals) >= 0) {
      range_txt <- paste0(format(min(vals), trim = TRUE), "-", format(max(vals), trim = TRUE))
      if (max(vals) <= 100 && all(round(vals) %% 5 == 0)) {
        message(
          what, " holds whole numbers in steps of 5 between 0 and 100 (", n_uniq,
          " distinct values, ", range_txt, "), the shape of a bounded rating score such ",
          "as a raw NASA-TLX subscale, so it is treated as continuous rather than as a ",
          "count. Pass outcome_type = \"count\" if these are counts of events."
        )
        return("continuous")
      }
      msg <- paste0(
        what, " holds non-negative whole numbers (", n_uniq, " distinct values, ",
        range_txt, "), so it is classified as a count and modelled with a Poisson ",
        "(or, if over-dispersed, negative-binomial) model. If it is a rating, a ",
        "summed questionnaire score or another bounded scale rather than a count of ",
        "events, pass outcome_type = \"continuous\" (or \"ordinal\")."
      )
      if (min(vals) >= 1 && max(vals) <= 100) {
        # No zeros and a closed range: the signature of a summed Likert scale or
        # a 1-10 rating. Still a count by the rules, but loudly.
        warning(
          msg, " Its values lie in a closed range without zeros, which is typical of ",
          "rating and questionnaire scores.",
          call. = FALSE
        )
      } else {
        message(msg)
      }
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


# Internal: `factors` must name predictors.
.check_factors_arg <- function(factors, predictors) {
  if (is.null(factors)) {
    return(invisible(TRUE))
  }
  if (!is.character(factors)) {
    stop(
      "`factors` must be a character vector of predictor names, or NULL to ",
      "decide from the data.",
      call. = FALSE
    )
  }
  bad <- setdiff(factors, predictors)
  if (length(bad) > 0) {
    stop(
      "`factors` names ", paste0("'", bad, "'", collapse = ", "), ", which ",
      if (length(bad) > 1) "are" else "is", " not among `predictors`.",
      call. = FALSE
    )
  }
  invisible(TRUE)
}


# Internal: does a numeric predictor look like integer condition codes (1, 2,
# 3 or 0, 1) rather than a measured covariate? Codes are a short run of
# consecutive whole numbers starting at 0 or 1, every level observed at least
# twice and -- with a cluster -- for at least two clusters. Eight participants'
# ages (21, 23, 24, ...) fail every one of these tests, which matters: turned
# into an eight-level factor, they are aliased with the participant random
# effect and the mixed model cannot be fitted.
.looks_like_codes <- function(v, cl = NULL, max_levels = 10L) {
  keep <- !is.na(v)
  vals <- v[keep]
  uniq <- sort(unique(vals))
  k <- length(uniq)
  if (k < 2L || k > max_levels) {
    return(FALSE)
  }
  if (any(abs(uniq - round(uniq)) > .Machine$double.eps^0.5)) {
    return(FALSE)
  }
  if (!(uniq[[1]] %in% c(0, 1)) || any(diff(uniq) != 1)) {
    return(FALSE)
  }
  if (any(table(vals) < 2L)) {
    return(FALSE)
  }
  if (!is.null(cl)) {
    per_level <- tapply(cl[keep], vals, function(x) length(unique(x)))
    if (any(per_level < 2L)) {
      return(FALSE)
    }
  }
  TRUE
}


# Internal: which predictors enter the model as categorical factors? Factors,
# characters and logicals always do. A numeric predictor does only when the
# caller lists it in `factors`, or -- with `factors = NULL` -- when it looks
# like condition codes (.looks_like_codes()). Returns a named logical vector.
.categorical_predictors <- function(data, predictors, cluster = NULL, factors = NULL) {
  out <- vapply(predictors, function(p) {
    v <- data[[p]]
    if (is.factor(v) || is.character(v) || is.logical(v)) {
      return(TRUE)
    }
    if (!is.numeric(v)) {
      return(FALSE)
    }
    if (!is.null(factors)) {
      return(p %in% factors)
    }
    .looks_like_codes(v, if (!is.null(cluster)) data[[cluster]] else NULL)
  }, logical(1))
  names(out) <- predictors
  out
}


# Internal: random-effect terms, from the maximal justified structure down to
# random intercepts only. Slopes are proposed only for within-cluster factors
# whose levels are replicated within a cluster (Barr et al., 2013); the
# interaction slope only when the full within-cells are replicated (several
# trials per participant and condition) and the fixed part has the interaction.
.random_terms <- function(cluster, slopes = character(0), slope_interaction = FALSE,
                          interaction = TRUE) {
  cl <- .bt(cluster)
  out <- character(0)
  if (length(slopes) > 0) {
    if (isTRUE(slope_interaction) && isTRUE(interaction) && length(slopes) > 1L) {
      out <- c(out, paste0("(1 + ", paste(.bt(slopes), collapse = " * "), " | ", cl, ")"))
    }
    out <- c(out, paste0("(1 + ", paste(.bt(slopes), collapse = " + "), " | ", cl, ")"))
  }
  c(out, paste0("(1 | ", cl, ")"))
}


# Internal: the repeated-measures structure of the data. A cluster column only
# makes the design clustered when some cluster contributes more than one row --
# a participant id in a between-subjects data set (one row each) is not a
# reason for a random effect, and lme4 refuses one. `design = "between"` with
# repeated rows per cluster still has to model the cluster: ignoring it would
# treat each participant's trials as independent observations.
.design_info <- function(data, predictors, categorical, cluster, design) {
  has_cluster <- !is.null(cluster)
  repeated <- has_cluster && anyDuplicated(data[[cluster]]) > 0L
  if (identical(design, "within") && has_cluster && !repeated) {
    warning(
      "`design = \"within\"`, but every level of `", cluster, "` has a single ",
      "row, so there are no repeated measures to model; the observations are ",
      "analysed as independent.",
      call. = FALSE
    )
  }
  clustered <- repeated || (identical(design, "within") && !has_cluster)

  cat_preds <- names(categorical)[categorical]
  within <- stats::setNames(logical(length(cat_preds)), cat_preds)
  if (repeated) {
    for (p in cat_preds) {
      within[[p]] <- any(tapply(
        as.character(data[[p]]), data[[cluster]],
        function(x) length(unique(x)) > 1L
      ), na.rm = TRUE)
    }
    if (identical(design, "between") && any(within)) {
      warning(
        "`design = \"between\"`, but ", paste0("`", names(within)[within], "`", collapse = ", "),
        " varies within `", cluster, "`; it is analysed as a within-cluster factor.",
        call. = FALSE
      )
    }
  }

  w <- names(within)[within]
  replicated <- stats::setNames(logical(length(w)), w)
  trial_replicates <- FALSE
  if (repeated && length(w) > 0) {
    cl <- data[[cluster]]
    # "Replicated" when most cluster x level cells hold two or more rows.
    rep_share <- function(g) {
      tab <- table(cl, g)
      cells <- tab[tab > 0]
      length(cells) > 0 && mean(cells >= 2) >= 0.5
    }
    for (p in w) replicated[[p]] <- rep_share(data[[p]])
    trial_replicates <- rep_share(interaction(data[w], drop = TRUE))
  }
  slopes <- names(replicated)[replicated]
  slope_interaction <- length(w) >= 2L && trial_replicates && length(slopes) == length(w)

  resolved <- if (!clustered) {
    "between"
  } else if (length(cat_preds) > 0 && !any(within)) {
    "between (clustered)"
  } else if (any(within) && any(!within)) {
    "mixed"
  } else {
    "within"
  }

  random <- NULL
  if (clustered) {
    cl_name <- if (has_cluster) cluster else "cluster_id"
    cand <- .random_terms(cl_name, slopes, slope_interaction)
    random <- list(
      term = cand[[1]], candidates = cand, slopes = slopes,
      slope_interaction = slope_interaction, dropped = NULL
    )
  }

  list(
    clustered = clustered, repeated = repeated, design = resolved,
    within = within, replicated = replicated,
    trial_replicates = trial_replicates, random = random
  )
}


# Internal: Shapiro-Wilk on a residual vector. NA when it cannot be run (fewer
# than three values or no variance). Beyond shapiro.test()'s limit of 5000 a
# deterministic, evenly spaced subset is tested, so the decision is reproducible
# without a seed.
.shapiro_residuals <- function(r) {
  r <- r[is.finite(r)]
  n <- length(r)
  if (n < 3L || diff(range(r)) < 1e-10) {
    return(list(W = NA_real_, p = NA_real_, n = n))
  }
  if (n > 5000L) {
    r <- r[unique(round(seq(1, n, length.out = 5000L)))]
  }
  tst <- stats::shapiro.test(r)
  list(W = unname(tst$statistic), p = tst$p.value, n = n)
}


# Internal: normality of the quantity the parametric model assumes to be
# normal -- the residuals of the model that would be fitted (all predictors,
# their interactions, and the random-effect structure), not the raw outcome
# split by one predictor. A 2 x 2 design in which every cell is normal can
# have a bimodal marginal distribution over one factor; only the residuals say
# whether the ANOVA/LMM assumption holds.
#
# The exception is a single two-level within-cluster factor with one row per
# participant and condition: there each participant's two residuals are
# mirror images (+e, -e), so the per-participant differences are tested
# instead (.paired_differences(), as check_normality_by_group() does), centred
# within the groups of any between-subject factors.
.residual_normality <- function(data, outcome, predictors, cluster, dsg) {
  w <- names(dsg$within)[dsg$within]
  if (isTRUE(dsg$clustered) && !is.null(cluster) && length(w) == 1L &&
      !isTRUE(dsg$replicated[[w]]) && all(predictors %in% names(dsg$within)) &&
      length(unique(stats::na.omit(as.character(data[[w]])))) == 2L) {
    diffs <- tryCatch(
      .paired_differences(data, outcome, w, cluster, between = setdiff(predictors, w)),
      error = function(e) NULL # e.g. a few repeated rows: fall back to the residuals
    )
    if (!is.null(diffs)) {
      sw <- .shapiro_residuals(diffs)
      return(list(
        normal = if (is.na(sw$p)) NA else sw$p >= 0.05,
        W = sw$W, p = sw$p, n = sw$n, model = "paired differences",
        tested = paste0("per-participant differences between the levels of `", w, "`",
                        if (length(predictors) > 1L) " (centred within the between-subjects groups)" else "")
      ))
    }
  }

  fixed <- paste(.bt(predictors), collapse = " * ")
  res <- NULL
  model_desc <- NULL
  if (isTRUE(dsg$clustered) && !is.null(cluster)) {
    if (requireNamespace("lme4", quietly = TRUE)) {
      for (re in unique(c(dsg$random$term, utils::tail(dsg$random$candidates, 1)))) {
        f <- stats::as.formula(paste(.bt(outcome), "~", fixed, "+", re))
        m <- tryCatch(
          suppressWarnings(suppressMessages(lme4::lmer(f, data = data))),
          error = function(e) NULL
        )
        if (!is.null(m)) {
          res <- stats::residuals(m)
          model_desc <- "linear mixed model"
          break
        }
      }
    }
    if (is.null(res)) {
      d <- data
      d[[cluster]] <- factor(d[[cluster]])
      f <- stats::as.formula(paste(.bt(outcome), "~", fixed, "+", .bt(cluster)))
      m <- tryCatch(stats::lm(f, data = d), error = function(e) NULL)
      if (!is.null(m)) {
        res <- stats::residuals(m)
        model_desc <- paste0("linear model with `", cluster, "` as a fixed effect")
      }
    }
  } else {
    f <- stats::as.formula(paste(.bt(outcome), "~", fixed))
    m <- tryCatch(stats::lm(f, data = data), error = function(e) NULL)
    if (!is.null(m)) {
      res <- stats::residuals(m)
      model_desc <- "linear model"
    }
  }
  if (is.null(res)) {
    return(NULL)
  }
  sw <- .shapiro_residuals(res)
  list(
    normal = if (is.na(sw$p)) NA else sw$p >= 0.05,
    W = sw$W, p = sw$p, n = sw$n, model = model_desc,
    tested = paste0("residuals of the ", model_desc)
  )
}


# Internal: homogeneity of variance across ALL cells of the between-subjects
# design (the interaction of the categorical predictors), by the Brown-Forsythe
# variant of Levene's test (centred on the median, robust to non-normality).
# Testing only the first predictor misses heteroscedasticity in the cells.
.variance_homogeneity <- function(data, outcome, factors) {
  if (!requireNamespace("car", quietly = TRUE)) {
    return(list(homogeneous = NA, p = NA_real_, reason = "the 'car' package is not installed"))
  }
  cells <- interaction(data[factors], drop = TRUE, sep = ":")
  if (nlevels(cells) < 2L || any(table(cells) < 2L)) {
    return(list(homogeneous = NA, p = NA_real_, reason = "a design cell has fewer than two observations"))
  }
  lt <- tryCatch(
    suppressWarnings(car::leveneTest(data[[outcome]], cells, center = stats::median)),
    error = function(e) NULL
  )
  if (is.null(lt)) {
    return(list(homogeneous = NA, p = NA_real_, reason = "the test could not be computed"))
  }
  p <- lt[1, "Pr(>F)"]
  list(
    homogeneous = if (is.na(p)) NA else p >= 0.05,
    F = lt[1, "F value"], df1 = lt[1, "Df"], df2 = lt[2, "Df"], p = p,
    cells = nlevels(cells), factors = factors
  )
}


# Internal: over-dispersion of a fitted Poisson model. Uses
# performance::check_overdispersion() (Pearson chi-squared / residual df; the
# deterministic "normal" residuals for mixed models, so the recommendation does
# not change between runs) and falls back to the same statistic computed
# directly when 'performance' is unavailable.
.overdispersion_test <- function(m) {
  res <- NULL
  if (requireNamespace("performance", quietly = TRUE)) {
    res <- tryCatch(
      {
        od <- if (inherits(m, "glm")) {
          performance::check_overdispersion(m)
        } else {
          performance::check_overdispersion(m, residual_type = "normal")
        }
        if (is.null(od$chisq_statistic)) stop("no Pearson statistic")
        list(
          ratio = od$dispersion_ratio, chisq = od$chisq_statistic,
          df = od$residual_df, p = od$p_value,
          method = "performance::check_overdispersion()"
        )
      },
      error = function(e) NULL
    )
  }
  if (is.null(res)) {
    rp <- stats::residuals(m, type = "pearson")
    rdf <- stats::df.residual(m)
    chisq <- sum(rp^2)
    res <- list(
      ratio = chisq / rdf, chisq = chisq, df = rdf,
      p = stats::pchisq(chisq, df = rdf, lower.tail = FALSE),
      method = "Pearson chi-squared / residual df"
    )
  }
  res$overdispersed <- isTRUE(res$p < 0.05)
  res
}


# Internal: fit the Poisson model the recommendation would otherwise use and
# test it for over-dispersion. NULL when it cannot be assessed (lme4 missing for
# a clustered design, or the fit failed).
.count_dispersion <- function(data, outcome, predictors, cluster, dsg) {
  fixed <- if (length(predictors) > 0) paste(.bt(predictors), collapse = " * ") else "1"
  m <- NULL
  if (isTRUE(dsg$clustered) && !is.null(cluster)) {
    if (!requireNamespace("lme4", quietly = TRUE)) {
      return(NULL)
    }
    f <- stats::as.formula(paste(.bt(outcome), "~", fixed, "+ (1 |", .bt(cluster), ")"))
    m <- tryCatch(
      suppressWarnings(suppressMessages(lme4::glmer(f, data = data, family = stats::poisson()))),
      error = function(e) NULL
    )
  } else {
    f <- stats::as.formula(paste(.bt(outcome), "~", fixed))
    m <- tryCatch(
      suppressWarnings(stats::glm(f, data = data, family = stats::poisson())),
      error = function(e) NULL
    )
  }
  if (is.null(m)) {
    return(NULL)
  }
  .overdispersion_test(m)
}


#' Recommend a principled analysis for one outcome
#'
#' Works out, from the data alone, which statistical model is appropriate for a
#' given outcome and set of predictors, and -- crucially -- *why*. The decision
#' follows a transparent three-question tree:
#' \enumerate{
#'   \item \strong{What is the outcome's measurement scale?}
#'     (via [classify_outcome()]: continuous, ordinal, binary, count, nominal.)
#'     This fixes the model family. A count is checked for over-dispersion
#'     (\code{performance::check_overdispersion()}, Pearson
#'     \eqn{\chi^2}/df); an over-dispersed count is modelled as negative
#'     binomial (\code{glmmTMB::glmmTMB(family = nbinom2)} when clustered,
#'     \code{MASS::glm.nb()} otherwise).
#'   \item \strong{Are the observations independent or clustered?}
#'     A \code{cluster} column in which some cluster contributes several rows
#'     makes the design clustered, whatever \code{design} says: the cluster then
#'     needs a random effect, i.e. a *mixed* model. For a categorical predictor
#'     that varies within clusters and whose levels are replicated within a
#'     cluster, by-cluster random slopes are added (Barr et al., 2013);
#'     [fit_recommended()] simplifies the structure when the fit is singular.
#'   \item \strong{For a continuous outcome, do the parametric assumptions
#'     hold?} A Shapiro--Wilk test on the residuals of the model that would be
#'     fitted (all predictors, their interactions and the random effects) and,
#'     for between-subjects designs, a Brown--Forsythe test (Levene's test
#'     centred on the median) across all design cells decide between a
#'     parametric model and a rank-based alternative.
#' }
#'
#' The recommendation ranges over ordinary ANOVA (Type III sums of squares for
#' factorial designs, via \pkg{afex}), heteroscedasticity-robust (HC3) ANOVA,
#' Welch tests, rank-based methods (Kruskal--Wallis + Dunn, Wilcoxon, the
#' Aligned Rank Transform, nparLD), generalized linear models, cumulative link
#' models, multinomial models, and their mixed-model counterparts -- linear
#' mixed models (LMM), generalized linear mixed models (GLMM,
#' \code{lme4}/\code{glmmTMB}), cumulative link mixed models (CLMM,
#' \code{ordinal}) and multinomial mixed models (\code{mclogit::mblogit}).
#' Only models that can actually be fitted to the design are recommended:
#' continuous covariates take the (mixed) regression route, because ART and
#' nparLD accept only categorical predictors; ART is used only for all-factor
#' full-factorial models; nparLD only for a single within-subject factor.
#'
#' @param data The data frame.
#' @param outcome The dependent variable (column name as string).
#' @param predictors Optional character vector of predictor (independent
#'   variable) column names.
#' @param cluster Optional column name identifying the subject/cluster for
#'   repeated-measures or otherwise non-independent data (the random-effect
#'   grouping factor).
#' @param design One of \code{"auto"} (default; clustered when some
#'   \code{cluster} has several rows), \code{"between"}, or \code{"within"}.
#'   Repeated rows per cluster are modelled with a random effect even with
#'   \code{"between"} -- ignoring them would be pseudo-replication.
#' @param outcome_type One of \code{"auto"} (default; use [classify_outcome()])
#'   or an explicit \code{"continuous"}, \code{"ordinal"}, \code{"binary"},
#'   \code{"count"}, \code{"nominal"} to override the automatic classification.
#' @param ordinal_max_levels Passed to [classify_outcome()]. Default 7.
#' @param factors Optional character vector naming the numeric predictors that
#'   are categorical (condition codes). \code{NULL} (default) decides from the
#'   data: a numeric predictor is categorical only when it looks like codes --
#'   at most 10 consecutive whole numbers starting at 0 or 1, each observed at
#'   least twice (and for at least two clusters). Factor, character and logical
#'   predictors are always categorical; \code{factors = character(0)} keeps
#'   every numeric predictor numeric.
#'
#' @return An object of class \code{"colley_recommendation"} (a list) with
#'   components including \code{outcome_type}, \code{clustered}, \code{design}
#'   (\code{"between"}, \code{"within"}, \code{"mixed"}, or
#'   \code{"between (clustered)"} for between-cluster predictors with repeated
#'   rows per cluster), \code{n_obs} (complete rows),
#'   \code{categorical} (which predictors are categorical), \code{within}
#'   (which categorical predictors vary within clusters), \code{random} (the
#'   random-effect structure), \code{family}, \code{assumptions} (normality and
#'   homogeneity results with their test statistics), \code{dispersion} (for
#'   counts), \code{recommendation} (human-readable label),
#'   \code{model_function} (the R function to call, e.g.
#'   \code{"ordinal::clmm"}), \code{reporter} (the matching colleyRstats
#'   reporter), \code{fit_call} (a ready-to-edit call as a string),
#'   \code{alternatives}, \code{rationale}, \code{methods_text} (an APA-style
#'   sentence) and \code{methods_tex} (the same, escaped for LaTeX). A
#'   \code{print} method summarises it.
#' @references Barr, D. J., Levy, R., Scheepers, C., & Tily, H. J. (2013).
#'   Random effects structure for confirmatory hypothesis testing: Keep it
#'   maximal. \emph{Journal of Memory and Language, 68}(3), 255--278.
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
                           ordinal_max_levels = 7L, factors = NULL) {
  not_empty(data)
  not_empty(outcome)
  design <- match.arg(design)
  outcome_type <- match.arg(outcome_type)
  .check_columns(data, c(outcome, predictors))
  if (!is.null(cluster)) {
    stopifnot(length(cluster) == 1L)
    .check_columns(data, cluster)
  }
  .check_factors_arg(factors, predictors)

  # Every check runs on the rows a model would actually use.
  data <- as.data.frame(data)
  cc <- stats::complete.cases(data[, c(outcome, predictors, cluster), drop = FALSE])
  d <- data[cc, , drop = FALSE]
  if (nrow(d) == 0L) {
    stop("No row has `", outcome, "`, the predictors and the cluster all non-missing.", call. = FALSE)
  }

  if (identical(outcome_type, "auto")) {
    outcome_type <- .classify_outcome(d[[outcome]], ordinal_max_levels = ordinal_max_levels, name = outcome)
  }

  categorical <- .categorical_predictors(d, predictors, cluster, factors)
  dsg <- .design_info(d, predictors, categorical, cluster, design)

  # A working copy with the categorical predictors as factors, so the checks
  # below estimate the same model the recommendation describes (a condition
  # coded 1/2/3 would otherwise enter them as a linear trend).
  dm <- d
  for (p in names(categorical)[categorical]) {
    if (!is.factor(dm[[p]])) dm[[p]] <- factor(dm[[p]])
  }

  normality <- NULL
  homogeneity <- NULL
  dispersion <- NULL
  if (identical(outcome_type, "continuous") && length(predictors) > 0 && is.numeric(dm[[outcome]])) {
    normality <- .residual_normality(dm, outcome, predictors, cluster, dsg)
    if (!dsg$clustered && any(categorical)) {
      homogeneity <- .variance_homogeneity(dm, outcome, names(categorical)[categorical])
    }
  }
  if (identical(outcome_type, "count")) {
    dispersion <- .count_dispersion(dm, outcome, predictors, cluster, dsg)
    if (isTRUE(dispersion$overdispersed)) {
      message(
        "`", outcome, "`: the Poisson model is over-dispersed (dispersion ratio = ",
        .fmt_num(dispersion$ratio), ", ", .fmt_p_text(dispersion$p),
        "), so a negative-binomial model is recommended instead."
      )
    }
  }
  normal <- if (is.null(normality)) NA else normality$normal
  homogeneous <- if (is.null(homogeneity)) NA else homogeneity$homogeneous

  cat_preds <- names(categorical)[categorical]
  n_groups <- if (length(cat_preds) == 1L) length(unique(dm[[cat_preds]])) else NA_integer_

  rec <- .build_recommendation(list(
    outcome = outcome, outcome_type = outcome_type, predictors = predictors,
    cluster = cluster, clustered = dsg$clustered, categorical = categorical,
    within = dsg$within, trial_replicates = dsg$trial_replicates,
    random = dsg$random, normal = normal, homogeneous = homogeneous,
    dispersion = dispersion, n_groups = n_groups
  ))

  # Rank-based and multinomial engines are fitted with random intercepts only;
  # the recommendation must not claim slopes it will not fit.
  random <- dsg$random
  if (!is.null(random) && !(rec$model_function %in% .slope_engines)) {
    random$candidates <- utils::tail(random$candidates, 1)
    random$term <- random$candidates[[1]]
    random$slopes <- character(0)
    random$slope_interaction <- FALSE
  }
  if (identical(rec$model_function, "nparLD::nparLD")) random <- NULL

  n_clusters <- if (dsg$clustered && !is.null(cluster)) length(unique(d[[cluster]])) else NA_integer_

  out <- list(
    outcome = outcome,
    outcome_type = outcome_type,
    predictors = predictors,
    cluster = cluster,
    clustered = dsg$clustered,
    design = dsg$design,
    n_obs = nrow(d),
    n_clusters = n_clusters,
    categorical = categorical,
    within = dsg$within,
    random = random,
    family = rec$family,
    assumptions = list(
      normal = normal, homogeneous = homogeneous,
      normality = normality, homogeneity = homogeneity
    ),
    dispersion = dispersion,
    recommendation = rec$recommendation,
    model_function = rec$model_function,
    reporter = rec$reporter,
    fit_call = rec$fit_call,
    alternatives = rec$alternatives,
    rationale = rec$rationale
  )
  out$methods_text <- .recommendation_methods_text(out)
  out$methods_tex <- .methods_tex(out$methods_text)
  class(out) <- "colley_recommendation"
  out
}


# Model functions that are fitted with the full random-slope structure (and
# simplified on a singular fit) by fit_recommended().
.slope_engines <- c("lme4::lmer", "lme4::glmer", "glmmTMB::glmmTMB", "ordinal::clmm")


# Internal: a p-value for plain-text (methods) sentences, never rounded across
# a significance boundary.
.fmt_p_text <- function(p) {
  if (is.null(p) || length(p) == 0 || is.na(p)) {
    return("p = NA")
  }
  if (p < 0.001) {
    paste0("p < ", .fmt_bounded(0.001, 3))
  } else {
    paste0("p = ", .fmt_p_number(p))
  }
}


# Internal: turn the resolved (outcome type, clustering, assumptions) state into
# a concrete model recommendation. Returns a plain list. `ctx` carries the
# outcome, predictors, cluster, design information and assumption results.
.build_recommendation <- function(ctx) {
  y <- .bt(ctx$outcome)
  predictors <- ctx$predictors
  fixed_rhs <- if (length(predictors) > 0) paste(.bt(predictors), collapse = " * ") else "1"
  cl <- if (is.null(ctx$cluster)) "cluster_id" else ctx$cluster
  re <- if (isTRUE(ctx$clustered)) ctx$random$term else NULL
  f_mixed <- paste0(y, " ~ ", fixed_rhs, if (!is.null(re)) paste0(" + ", re) else "")
  f_fixed <- paste0(y, " ~ ", fixed_rhs)
  clustered <- isTRUE(ctx$clustered)

  make <- function(recommendation, model_function, reporter, fit_call,
                   rationale, family = NA_character_, alternatives = character(0)) {
    list(
      recommendation = recommendation, model_function = model_function,
      reporter = reporter, fit_call = fit_call, rationale = rationale,
      family = family, alternatives = alternatives
    )
  }

  switch(ctx$outcome_type,
    ordinal = if (clustered) {
      make(
        "Cumulative Link Mixed Model (CLMM)", "ordinal::clmm", "reportCLMM",
        paste0("ordinal::clmm(", f_mixed, ", data = your_data)  # outcome must be an ordered factor"),
        "the outcome is ordinal and the observations are clustered, so an ordinal (proportional-odds) model with random effects is appropriate",
        family = "cumulative link (logit)",
        alternatives = "nparLD (rank-based repeated measures) if proportional odds is untenable"
      )
    } else {
      make(
        "Cumulative Link Model (CLM, proportional odds)", "ordinal::clm", "reportCLMM",
        paste0("ordinal::clm(", f_fixed, ", data = your_data)  # outcome must be an ordered factor"),
        "the outcome is ordinal and the observations are independent, so a proportional-odds cumulative link model is appropriate",
        family = "cumulative link (logit)",
        alternatives = if (isTRUE(ctx$n_groups == 2L)) {
          "Mann-Whitney U (wilcox.test) as a rank-based alternative"
        } else {
          "Kruskal-Wallis + Dunn's test (reportDunnTest) as a rank-based alternative"
        }
      )
    },
    binary = if (clustered) {
      make(
        "Generalized Linear Mixed Model (GLMM), binomial", "lme4::glmer", "reportGLMM",
        paste0("lme4::glmer(", f_mixed, ", data = your_data, family = binomial)"),
        "the outcome is binary and the observations are clustered, so a mixed-effects logistic regression is appropriate",
        family = "binomial (logit)",
        alternatives = "glmmTMB::glmmTMB(..., family = binomial) for more flexible random structures"
      )
    } else {
      make(
        "Logistic regression (GLM, binomial)", "stats::glm", "reportGLMM",
        paste0("stats::glm(", f_fixed, ", data = your_data, family = binomial)"),
        "the outcome is binary and the observations are independent, so logistic regression is appropriate",
        family = "binomial (logit)",
        alternatives = "chi-squared / Fisher's exact test for a simple two-way contingency"
      )
    },
    count = .recommend_count(ctx, f_mixed, f_fixed, make),
    nominal = if (clustered) {
      make(
        "Multinomial logistic mixed model (baseline-category logit)", "mclogit::mblogit", NA_character_,
        paste0("mclogit::mblogit(", f_fixed, ", random = ~ 1 | ", .bt(cl), ", data = your_data)"),
        "the outcome is unordered categorical with more than two levels and the observations are clustered, so a multinomial model with a random intercept is needed; an ordinary multinomial regression would treat each cluster's repeated choices as independent",
        family = "multinomial (baseline-category logit)",
        alternatives = "collapse to a binary outcome and use a binomial GLMM if the research question allows"
      )
    } else {
      make(
        "Multinomial logistic regression", "nnet::multinom", NA_character_,
        paste0("nnet::multinom(", f_fixed, ", data = your_data)"),
        "the outcome is unordered categorical with more than two levels, so a multinomial model is appropriate",
        family = "multinomial",
        alternatives = "collapse to a binary outcome and use logistic regression if the research question allows"
      )
    },
    continuous = .recommend_continuous(ctx, y, fixed_rhs, f_mixed, f_fixed, make)
  )
}


# Internal: the count branch -- Poisson unless the Poisson fit is over-dispersed.
.recommend_count <- function(ctx, f_mixed, f_fixed, make) {
  dp <- ctx$dispersion
  od <- isTRUE(dp$overdispersed)
  disp_txt <- if (is.null(dp)) {
    "; over-dispersion could not be assessed, so check it before relying on the Poisson model"
  } else if (od) {
    paste0(
      "; the Poisson model is over-dispersed (dispersion ratio = ", .fmt_num(dp$ratio),
      ", ", .fmt_p_text(dp$p), "), so a negative-binomial model is used instead -- a Poisson model would understate the standard errors"
    )
  } else {
    paste0("; the Poisson model shows no significant over-dispersion (dispersion ratio = ", .fmt_num(dp$ratio), ")")
  }
  if (isTRUE(ctx$clustered)) {
    if (od) {
      return(make(
        "Generalized Linear Mixed Model (GLMM), negative binomial", "glmmTMB::glmmTMB", "reportGLMM",
        paste0("glmmTMB::glmmTMB(", f_mixed, ", data = your_data, family = glmmTMB::nbinom2)"),
        paste0("the outcome is a count and the observations are clustered", disp_txt),
        family = "negative binomial (log)",
        alternatives = "lme4::glmer.nb() fits the same model with lme4"
      ))
    }
    return(make(
      "Generalized Linear Mixed Model (GLMM), Poisson", "lme4::glmer", "reportGLMM",
      paste0("lme4::glmer(", f_mixed, ", data = your_data, family = poisson)"),
      paste0("the outcome is a count and the observations are clustered, so a mixed-effects Poisson model is appropriate", disp_txt),
      family = "poisson (log)",
      alternatives = "glmmTMB::glmmTMB(..., family = nbinom2) if the counts turn out over-dispersed"
    ))
  }
  if (od) {
    return(make(
      "Negative-binomial regression (GLM)", "MASS::glm.nb", "reportGLMM",
      paste0("MASS::glm.nb(", f_fixed, ", data = your_data)"),
      paste0("the outcome is a count and the observations are independent", disp_txt),
      family = "negative binomial (log)",
      alternatives = "a quasi-Poisson GLM as a simpler correction"
    ))
  }
  make(
    "Poisson regression (GLM)", "stats::glm", "reportGLMM",
    paste0("stats::glm(", f_fixed, ", data = your_data, family = poisson)"),
    paste0("the outcome is a count and the observations are independent, so Poisson regression is appropriate", disp_txt),
    family = "poisson (log)",
    alternatives = "MASS::glm.nb() if the counts turn out over-dispersed"
  )
}


# Internal: the continuous-outcome branch, where assumption checks select
# between a parametric model and a rank-based / robust alternative. Every route
# names a model that can be fitted to the design at hand.
.recommend_continuous <- function(ctx, y, fixed_rhs, f_mixed, f_fixed, make) {
  predictors <- ctx$predictors
  clustered <- isTRUE(ctx$clustered)
  cl <- if (is.null(ctx$cluster)) "cluster_id" else ctx$cluster
  cat_preds <- names(ctx$categorical)[ctx$categorical]
  covariates <- setdiff(predictors, cat_preds)
  normal <- ctx$normal
  is_normal <- isTRUE(normal)
  assessable <- !is.na(normal)
  factorial <- length(cat_preds) > 1L
  two_groups <- isTRUE(ctx$n_groups == 2L)
  lmm <- function(rationale, alternatives = "lmerTest::lmer gives Satterthwaite degrees of freedom and p-values") {
    make(
      "Linear Mixed Model (LMM)", "lme4::lmer", "reportGLMM",
      paste0("lme4::lmer(", f_mixed, ", data = your_data)"),
      rationale,
      family = "gaussian", alternatives = alternatives
    )
  }
  non_normal_note <- if (assessable && !is_normal) "; the residuals depart from normality, so inspect them (a transformation or a robust fit may be preferable)" else ""

  if (length(predictors) == 0) {
    if (clustered) {
      return(lmm("the outcome is continuous and the observations are clustered, so an intercept-only linear mixed model estimates the mean and the between-cluster variance"))
    }
    return(make(
      "Intercept-only linear model (no predictors)", "stats::lm", "reportGLMM",
      paste0("stats::lm(", y, " ~ 1, data = your_data)"),
      "no predictors were given, so there are no conditions to compare; an intercept-only model only estimates the mean",
      family = "gaussian"
    ))
  }

  # A continuous covariate: regression. The rank-based alternatives (ART,
  # nparLD, Kruskal-Wallis) accept only categorical predictors, so they are
  # never offered here.
  if (length(covariates) > 0) {
    cov_txt <- paste0("`", covariates, "`", collapse = ", ")
    if (clustered) {
      return(lmm(paste0(
        "the outcome is continuous with a continuous predictor (", cov_txt,
        ") and clustered observations, so a linear mixed model is appropriate (rank-based methods cannot include covariates)",
        non_normal_note
      )))
    }
    return(make(
      "Linear regression (lm)", "stats::lm", "reportGLMM",
      paste0("stats::lm(", f_fixed, ", data = your_data)"),
      paste0(
        "the outcome is continuous with a continuous predictor (", cov_txt,
        ") and independent observations, so linear regression is appropriate (rank-based methods cannot include covariates)",
        non_normal_note
      ),
      family = "gaussian",
      alternatives = "a robust regression (e.g. MASS::rlm) if the residuals are clearly non-normal"
    ))
  }

  if (clustered) {
    # Normal residuals, or normality could not be assessed: the linear mixed
    # model is the standard modern approach for repeated continuous data.
    if (is_normal || !assessable) {
      return(lmm(paste0(
        "the outcome is continuous",
        if (assessable) ", its residuals are approximately normal," else "",
        " and the observations are clustered, so a linear mixed model is appropriate",
        if (!assessable) "; check the residuals, as their normality could not be assessed" else ""
      )))
    }
    has_within <- any(ctx$within)
    # Several trials per participant and condition: the rank-based repeated-
    # measures methods need one value per participant and cell, and would treat
    # the trials as independent replicates. The LMM with random slopes models
    # them properly and its fixed-effect tests are robust to moderate
    # non-normality of the residuals.
    if (has_within && isTRUE(ctx$trial_replicates)) {
      return(lmm(
        paste0(
          "the outcome is continuous and its residuals depart from normality, but each `", cl,
          "` contributed several observations per condition; rank-based repeated-measures methods ",
          "(ART, nparLD) assume one value per `", cl, "` and condition, so a linear mixed model with ",
          "by-`", cl, "` random slopes is recommended -- its fixed-effect tests are robust to moderate ",
          "non-normality, while ignoring the replication is not"
        ),
        alternatives = paste0(
          "aggregate to one value per `", cl, "` and condition, then use the aligned rank transform ",
          "(ARTool::art) or nparLD"
        )
      ))
    }
    if (factorial || !has_within) {
      return(make(
        "Aligned Rank Transform (ART), repeated measures", "ARTool::art", "reportART",
        paste0("ARTool::art(", y, " ~ ", fixed_rhs, " + (1 | ", .bt(cl), "), data = your_data)"),
        paste0(
          "the outcome is continuous but its residuals depart from normality and the observations are clustered, ",
          "so the aligned rank transform with a random intercept for `", cl,
          "` is safer than a parametric mixed model (ART requires the full factorial model)"
        ),
        family = "gaussian (rank-based)",
        alternatives = "a linear mixed model (lme4::lmer) if a suitable transformation restores normality"
      ))
    }
    return(make(
      "Rank-based repeated measures (nparLD)", "nparLD::nparLD", "reportNparLD",
      paste0("nparLD::nparLD(", y, " ~ ", .bt(cat_preds), ", subject = \"", cl, "\", data = your_data)"),
      paste0(
        "the outcome is continuous but its residuals depart from normality and it was measured repeatedly ",
        "under one within-subject factor, so a rank-based repeated-measures analysis is safer than a parametric mixed model"
      ),
      family = "gaussian (rank-based)",
      alternatives = "a linear mixed model (lme4::lmer) if a suitable transformation restores normality"
    ))
  }

  # Between-subjects group comparison.
  homogeneous <- ctx$homogeneous
  if (is_normal) {
    if (isFALSE(homogeneous)) {
      if (factorial) {
        ctr <- paste0(.bt(cat_preds), " = \"contr.sum\"", collapse = ", ")
        return(make(
          "Factorial ANOVA with heteroscedasticity-robust (HC3) tests", "car::Anova", NA_character_,
          paste0(
            "car::Anova(stats::lm(", f_fixed, ", data = your_data, contrasts = list(", ctr,
            ")), type = 3, white.adjust = \"hc3\")"
          ),
          "the outcome is continuous with normal residuals but the variances differ across the design cells, so Type III tests with heteroscedasticity-consistent (HC3) standard errors are appropriate; Welch's ANOVA has no factorial form",
          family = "gaussian",
          alternatives = "a rank-based analysis (ARTool::art) if normality is also doubtful"
        ))
      }
      return(make(
        if (two_groups) "Welch's t-test" else "Welch's ANOVA",
        "stats::oneway.test", NA_character_,
        paste0("stats::oneway.test(", f_fixed, ", data = your_data, var.equal = FALSE)"),
        "the outcome is continuous with normal residuals but the group variances are unequal, so a Welch-corrected test is appropriate",
        family = "gaussian",
        alternatives = "a rank-based test if normality is also doubtful"
      ))
    }
    homog_txt <- if (isTRUE(homogeneous)) {
      " and the variances are homogeneous across the design cells"
    } else {
      " (homogeneity of variance could not be tested)"
    }
    if (factorial) {
      return(make(
        "Factorial ANOVA (Type III sums of squares)", "afex::aov_car", NA_character_,
        paste0("afex::aov_car(", f_fixed, " + Error(row_id), data = your_data)  # row_id: one id per row"),
        paste0(
          "the outcome is continuous, its residuals are approximately normal", homog_txt,
          ", so a factorial ANOVA is appropriate; Type III sums of squares with sum-to-zero contrasts make the tests independent of the order of the predictors in an unbalanced design"
        ),
        family = "gaussian",
        alternatives = "car::Anova(stats::lm(..., contrasts = contr.sum), type = 3) gives the same tests"
      ))
    }
    return(make(
      if (two_groups) "t-test (parametric)" else "One-way ANOVA (parametric)",
      "stats::aov", NA_character_,
      paste0("stats::aov(", f_fixed, ", data = your_data)"),
      paste0(
        "the outcome is continuous, its residuals are approximately normal", homog_txt,
        ", so a parametric ", if (two_groups) "t-test" else "ANOVA", " is appropriate"
      ),
      family = "gaussian",
      alternatives = "ggbetweenstatsWithPriorNormalityCheck() for the figure with the omnibus test"
    ))
  }

  # Non-normal residuals, or normality could not be assessed: rank-based.
  why <- paste0(
    "the outcome is continuous but ",
    if (assessable) "its residuals depart significantly from normality" else "the normality of its residuals could not be assessed",
    ", so a rank-based test is safer than a parametric one"
  )
  if (factorial) {
    return(make(
      "Aligned Rank Transform (ART)", "ARTool::art", "reportART",
      paste0("ARTool::art(", f_fixed, ", data = your_data)"),
      paste0(why, " (ART requires the full factorial model)"),
      family = "gaussian (rank-based)",
      alternatives = "a parametric test if a transformation (e.g. log) restores normality"
    ))
  }
  if (two_groups) {
    return(make(
      "Mann-Whitney U test", "stats::wilcox.test", NA_character_,
      paste0("stats::wilcox.test(", f_fixed, ", data = your_data)"),
      why,
      family = "gaussian (rank-based)",
      alternatives = "a parametric test if a transformation (e.g. log) restores normality"
    ))
  }
  make(
    "Kruskal-Wallis + Dunn's test", "stats::kruskal.test", "reportDunnTest",
    paste0("stats::kruskal.test(", f_fixed, ", data = your_data)  # follow up with FSA::dunnTest() + reportDunnTest()"),
    why,
    family = "gaussian (rank-based)",
    alternatives = "a parametric test if a transformation (e.g. log) restores normality"
  )
}


# Internal: assemble the APA-style methods sentence for a recommendation (or,
# from fit_recommended(), for the model actually fitted). Column and function
# names are wrapped in backticks; .methods_tex() turns those into \texttt{}.
.recommendation_methods_text <- function(x) {
  type_desc <- switch(x$outcome_type,
    continuous = "continuous",
    ordinal = "ordinal",
    binary = "binary",
    count = "a count",
    nominal = "unordered categorical (nominal)"
  )
  dependence <- if (isTRUE(x$clustered)) {
    paste0(
      "the observations are clustered",
      if (!is.null(x$cluster)) paste0(" within `", x$cluster, "`") else "",
      if (!is.na(x$n_clusters)) paste0(" (", x$n_clusters, " clusters, ", x$n_obs, " observations)") else ""
    )
  } else {
    paste0("the observations are independent (", x$n_obs, " observations)")
  }
  s <- paste0("The outcome `", x$outcome, "` is ", type_desc, ", and ", dependence, ".")

  nt <- x$assumptions$normality
  if (identical(x$outcome_type, "continuous") && !is.null(nt) && !is.na(nt$p)) {
    s <- c(s, paste0(
      "A Shapiro-Wilk test on the ",
      if (!is.null(nt$tested)) nt$tested else paste0("residuals of the ", nt$model), " indicated ",
      if (isTRUE(nt$normal)) "no significant" else "a significant",
      " departure from normality (W = ", .fmt_bounded(nt$W), ", ", .fmt_p_text(nt$p), ")."
    ))
  }
  ht <- x$assumptions$homogeneity
  if (identical(x$outcome_type, "continuous") && !is.null(ht) && !is.null(ht$p) && !is.na(ht$p)) {
    s <- c(s, paste0(
      "A Brown-Forsythe test (Levene's test centred on the median) across the ", ht$cells,
      " cells of the between-subjects design indicated ",
      if (isTRUE(ht$homogeneous)) "homogeneous" else "heterogeneous",
      " variances (F(", .fmt_df(ht$df1), ", ", .fmt_df(ht$df2), ") = ", .fmt_num(ht$F), ", ",
      .fmt_p_text(ht$p), ")."
    ))
  }
  dp <- x$dispersion
  if (identical(x$outcome_type, "count") && !is.null(dp)) {
    s <- c(s, if (isTRUE(dp$overdispersed)) {
      paste0(
        "A Poisson model of the counts was over-dispersed (dispersion ratio = ", .fmt_num(dp$ratio),
        ", ", .fmt_p_text(dp$p), "), so a negative-binomial model was used."
      )
    } else {
      paste0(
        "A Poisson model of the counts showed no significant over-dispersion (dispersion ratio = ",
        .fmt_num(dp$ratio), ", ", .fmt_p_text(dp$p), ")."
      )
    })
  }
  rnd <- x$random
  if (isTRUE(x$clustered) && !is.null(rnd) && !is.null(x$cluster)) {
    tried <- if (!is.null(rnd$dropped) && length(rnd$dropped$slopes)) rnd$dropped$slopes else rnd$slopes
    if (length(tried) > 0) {
      sl <- paste0("`", tried, "`", collapse = " and ")
      lead <- paste0(
        "Because each `", x$cluster, "` contributed several observations per level of ", sl,
        ", by-`", x$cluster, "` random slopes for ", sl
      )
      s <- c(s, if (!is.null(rnd$dropped)) {
        paste0(
          lead, " were included in the initial model (Barr et al., 2013), but the fit was ",
          rnd$dropped$reason, ", so the random-effects structure was simplified to `", rnd$term, "`."
        )
      } else {
        paste0(lead, " are included alongside the random intercepts (Barr et al., 2013).")
      })
    }
  }
  fun <- if (!is.null(x$fitted_function)) x$fitted_function else x$model_function
  s <- c(s, paste0(
    .indefinite_article(x$recommendation), " ", x$recommendation, " (`", fun, "`) ",
    if (!is.null(x$fitted_function)) "was fitted" else "is therefore recommended",
    if (!is.na(x$reporter)) paste0("; report it with `", x$reporter, "()`.") else "."
  ))
  paste(s, collapse = " ")
}


# Internal: the LaTeX version of a plain-text methods sentence. Text outside
# backticks is escaped (so `tlx_mental` cannot become a subscript error), and
# names inside backticks are typeset with \texttt{}. The console text keeps
# its backticks, which read naturally there.
.methods_tex <- function(x) {
  vapply(as.character(x), function(s) {
    if (is.na(s) || !nzchar(s)) {
      return(s)
    }
    parts <- strsplit(s, "`", fixed = TRUE)[[1]]
    code <- seq_along(parts) %% 2 == 0
    parts[!code] <- latex_escape(parts[!code])
    parts[code] <- paste0("\\texttt{", latex_escape(parts[code]), "}")
    paste(parts, collapse = "")
  }, character(1), USE.NAMES = FALSE)
}


#' @export
print.colley_recommendation <- function(x, ...) {
  cat("<colleyRstats analysis recommendation>\n")
  cat("  Outcome        : ", x$outcome, " (", x$outcome_type, ")\n", sep = "")
  pred_txt <- if (is.null(x$predictors)) {
    "(none)"
  } else {
    paste0(x$predictors, vapply(x$predictors, function(p) {
      if (!isTRUE(x$categorical[[p]])) {
        return(" (numeric)")
      }
      if (isTRUE(x$within[p])) " (categorical, within)" else " (categorical)"
    }, character(1)), collapse = ", ")
  }
  cat("  Predictors     : ", pred_txt, "\n", sep = "")
  cat("  Design         : ", x$design,
    if (x$clustered && !is.null(x$cluster)) paste0(" (cluster: ", x$cluster, ")") else "", "\n",
    sep = ""
  )
  if (!is.null(x$random)) cat("  Random effects : ", x$random$term, "\n", sep = "")
  if (identical(x$outcome_type, "continuous") && !is.na(x$assumptions$normal)) {
    cat("  Normality      : ", if (isTRUE(x$assumptions$normal)) "not rejected" else "rejected",
      " (residuals)\n",
      sep = ""
    )
  }
  if (identical(x$outcome_type, "continuous") && !is.na(x$assumptions$homogeneous)) {
    cat("  Homogeneity    : ", if (isTRUE(x$assumptions$homogeneous)) "not rejected" else "rejected",
      " (Brown-Forsythe, all cells)\n",
      sep = ""
    )
  }
  if (!is.null(x$dispersion)) {
    cat("  Dispersion     : ratio ", .fmt_num(x$dispersion$ratio),
      if (isTRUE(x$dispersion$overdispersed)) " (over-dispersed)" else "", "\n",
      sep = ""
    )
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

# Internal: TRUE when an expression contains a random-effect bar.
.has_bars <- function(x) {
  if (!is.call(x)) {
    return(FALSE)
  }
  if (identical(x[[1]], as.name("|")) || identical(x[[1]], as.name("||"))) {
    return(TRUE)
  }
  any(vapply(as.list(x)[-1], .has_bars, logical(1)))
}


# Internal: a formula without its random-effect terms.
.drop_bars <- function(f) {
  strip <- function(e) {
    if (is.call(e) && identical(e[[1]], as.name("+"))) {
      if (length(e) == 2L) {
        return(strip(e[[2]]))
      }
      l <- strip(e[[2]])
      r <- strip(e[[3]])
      if (is.null(l)) {
        return(r)
      }
      if (is.null(r)) {
        return(l)
      }
      return(call("+", l, r))
    }
    if (.has_bars(e)) {
      return(NULL)
    }
    e
  }
  rhs <- strip(f[[length(f)]])
  f[[length(f)]] <- if (is.null(rhs)) 1 else rhs
  f
}


# Internal: normalise family names across glm / glm.nb / glmmTMB.
.normalise_family <- function(f) {
  if (is.null(f) || length(f) == 0 || is.na(f[[1]])) {
    return(NA_character_)
  }
  f <- as.character(f[[1]])
  if (grepl("^Negative Binomial", f, ignore.case = TRUE)) {
    return("negative binomial")
  }
  if (identical(f, "nbinom2")) {
    return("negative binomial (NB2)")
  }
  if (identical(f, "nbinom1")) {
    return("negative binomial (NB1)")
  }
  f
}


# Internal: describe a fitted model (kind, family, link, whether to
# exponentiate the coefficients, and the effect-size label to print). Odds
# ratios exist only on the logit scale and incidence-rate ratios only on the
# log scale: exp() of a probit coefficient is not an odds ratio, so other links
# report the raw coefficient and name the link.
.mixed_model_info <- function(model) {
  is_cumulative <- inherits(model, c("clmm", "clm", "clmm2"))
  family_raw <- if (is_cumulative) {
    "cumulative link"
  } else {
    tryCatch(stats::family(model)$family, error = function(e) NA_character_)
  }
  link <- if (is_cumulative) {
    l <- tryCatch(as.character(model$link), error = function(e) character(0))
    if (length(l)) l[[1]] else "logit"
  } else {
    tryCatch(stats::family(model)$link, error = function(e) NA_character_)
  }
  if (is.null(link) || length(link) == 0) link <- NA_character_
  family_name <- if (is_cumulative) "cumulative link" else .normalise_family(family_raw)

  has_random <- inherits(model, c("merMod", "clmm", "clmm2")) ||
    (inherits(model, "glmmTMB") &&
      isTRUE(tryCatch(.has_bars(stats::formula(model)[[3]]), error = function(e) TRUE)))
  gaussian <- !is.na(family_name) && identical(family_name, "gaussian")
  is_binomial <- !is.na(family_name) && family_name %in% c("binomial", "quasibinomial", "betabinomial")
  is_count <- !is.na(family_name) &&
    grepl("poisson|negative binomial|nbinom|genpois|compois", family_name, ignore.case = TRUE)

  exponentiate <- FALSE
  effect_label <- "b"
  effect_long <- NULL
  if ((is_cumulative || is_binomial) && identical(link, "logit")) {
    exponentiate <- TRUE
    effect_label <- "OR"
    effect_long <- "odds ratios"
  } else if (is_binomial && identical(link, "log")) {
    exponentiate <- TRUE
    effect_label <- "RR"
    effect_long <- "risk ratios"
  } else if (is_count && identical(link, "log")) {
    exponentiate <- TRUE
    effect_label <- "IRR"
    effect_long <- "incidence-rate ratios"
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

  family_desc <- if (is_cumulative) {
    if (!is.na(link)) paste0(link, " link") else NULL
  } else if (!is.na(family_name) && !(gaussian && identical(link, "identity"))) {
    paste0(family_name, " family", if (!is.na(link)) paste0(", ", link, " link") else "")
  } else {
    NULL
  }

  list(
    kind = kind, family = family_name, link = link, exponentiate = exponentiate,
    effect_label = effect_label, effect_long = effect_long,
    is_cumulative = is_cumulative, gaussian = gaussian, has_random = has_random,
    family_desc = family_desc
  )
}


# Internal: degrees-of-freedom method for the coefficient t-tests of a linear
# mixed model. parameters::model_parameters() without it uses the residual
# degrees of freedom (n - p) for an lmer fit, which is anti-conservative for
# between-cluster effects (t(116) where Satterthwaite gives t(10)).
.coef_ci_method <- function(model, info) {
  if (inherits(model, "merMod") && isTRUE(info$gaussian)) {
    # Without lmerTest there is no small-sample df: say "asymptotic" (z) rather
    # than pretend the residual df apply.
    return(if (requireNamespace("lmerTest", quietly = TRUE)) "satterthwaite" else "normal")
  }
  NULL
}

.df_method_label <- function(ci_method) {
  switch(ci_method,
    satterthwaite = "Satterthwaite's degrees of freedom",
    "the asymptotic (normal) approximation"
  )
}


# Internal: tidy the fixed-effect (location / conditional-mean) coefficients
# into a data frame, dropping thresholds, scale and zero-inflation parameters
# and the intercept, and normalising the statistic column to `.stat` /
# `.stat_name`.
.mixed_fixed_effects <- function(model, exponentiate = FALSE, conf_level = 0.95,
                                 include_intercept = FALSE, ci_method = NULL) {
  args <- list(model, effects = "fixed", exponentiate = exponentiate, ci = conf_level)
  if (!is.null(ci_method)) args$ci_method <- ci_method
  pars <- tryCatch(
    suppressMessages(do.call(parameters::model_parameters, args)),
    error = function(e) {
      args$effects <- NULL
      suppressMessages(do.call(parameters::model_parameters, args))
    }
  )
  df <- as.data.frame(pars)

  if ("Effects" %in% names(df)) {
    df <- df[df$Effects == "fixed", , drop = FALSE]
  }
  # Only the location / conditional-mean part describes predictor effects on
  # the outcome. parameters labels clm thresholds "intercept", scale effects
  # "scale", and glmmTMB zero-inflation / dispersion coefficients
  # "zero_inflated" / "dispersion" -- reporting those as "the effect of X"
  # would print the zero-inflation logit as an IRR.
  if ("Component" %in% names(df)) {
    df <- df[df$Component %in% c("conditional", "location", "beta"), , drop = FALSE]
  }
  # Cumulative-link models: keep exactly the location coefficients ($beta).
  # This drops thresholds named "1|2", but also the "threshold.1" / "spacing"
  # parameters of equidistant or symmetric thresholds.
  if (inherits(model, c("clm", "clmm")) && !is.null(model$beta)) {
    df <- df[gsub("`", "", df$Parameter) %in% gsub("`", "", names(model$beta)), , drop = FALSE]
  }
  df <- df[!grepl("|", df$Parameter, fixed = TRUE), , drop = FALSE]
  if (!isTRUE(include_intercept)) {
    df <- df[df$Parameter != "(Intercept)", , drop = FALSE]
  }

  stat_col <- intersect(c("t", "z", "Statistic", "F"), names(df))
  stat_col <- if (length(stat_col)) stat_col[[1L]] else NA_character_
  df$.stat <- if (!is.na(stat_col)) df[[stat_col]] else rep(NA_real_, nrow(df))
  df$.stat_name <- rep(stat_col, nrow(df))
  if (!"df_error" %in% names(df)) df$df_error <- rep(NA_real_, nrow(df))
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


# Internal: Type III omnibus tests of the model terms, as a standard table
# (term, df1, df2, statistic, stat_name = "F"/"chisq", p, method).
#   * linear mixed models: lmerTest's Type III F-tests with Satterthwaite's
#     degrees of freedom (contrast-coding independent);
#   * everything else: emmeans::joint_tests(), which builds the tests from the
#     reference grid and is therefore independent of the contrast coding too --
#     an F-test for lm, a Wald chi-squared (F x df1, df2 = Inf) for GLM(M)s and
#     cumulative link models. A numeric covariate enters with
#     cov.reduce = range, so its own slope is tested and factors that interact
#     with it are evaluated at its mid-range.
.omnibus_table <- function(model, info = .mixed_model_info(model)) {
  lmm <- inherits(model, "merMod") && isTRUE(info$gaussian)
  if (lmm && requireNamespace("lmerTest", quietly = TRUE)) {
    m <- if (inherits(model, "lmerModLmerTest")) model else lmerTest::as_lmerModLmerTest(model)
    a <- as.data.frame(stats::anova(m, type = 3, ddf = "Satterthwaite"))
    return(data.frame(
      term = gsub("`", "", rownames(a)), df1 = a$NumDF, df2 = a$DenDF,
      statistic = a$`F value`, stat_name = "F", p = a$`Pr(>F)`,
      method = "Satterthwaite", stringsAsFactors = FALSE
    ))
  }
  if (!requireNamespace("emmeans", quietly = TRUE)) {
    stop("the 'emmeans' package is needed for omnibus tests of this model class", call. = FALSE)
  }
  args <- list(model)
  method <- "Wald"
  if (lmm) {
    # Reached only without lmerTest: no small-sample df, so asymptotic tests.
    args$lmer.df <- "asymptotic"
    method <- "asymptotic"
  }
  jt <- as.data.frame(suppressMessages(do.call(emmeans::joint_tests, args)))
  jt <- jt[!grepl("^\\(", jt[["model term"]]), , drop = FALSE]
  inf <- !is.finite(jt$df2)
  data.frame(
    term = gsub("`", "", as.character(jt[["model term"]])), df1 = jt$df1, df2 = jt$df2,
    statistic = ifelse(inf, jt$F.ratio * jt$df1, jt$F.ratio),
    stat_name = ifelse(inf, "chisq", "F"), p = jt$p.value,
    method = method, stringsAsFactors = FALSE
  )
}


# Internal: one sentence per omnibus test ("The main effect of a ...", "The
# interaction effect of a x b ...").
.omnibus_sentences <- function(tab, dv_tex, alpha = 0.05) {
  if (is.null(tab) || nrow(tab) == 0L) {
    return(character(0))
  }
  vapply(seq_len(nrow(tab)), function(i) {
    r <- tab[i, ]
    vars <- strsplit(gsub("`", "", r$term), ":", fixed = TRUE)[[1]]
    name <- paste0("\\textit{", latex_escape(vars), "}", collapse = " $\\times$ ")
    what <- if (length(vars) > 1L) "interaction effect" else "main effect"
    stat <- if (identical(r$stat_name, "F")) {
      paste0("\\F{", .fmt_df(r$df1), "}{", .fmt_df(r$df2), "}{", .fmt_num(r$statistic), "}")
    } else {
      paste0("$\\chi^2(", .fmt_df(r$df1), ") = ", .fmt_num(r$statistic), "$")
    }
    p_na <- is.na(r$p)
    p_macro <- if (p_na) "$p$ = NA" else .fmt_p_macro(r$p)
    verdict <- if (p_na) {
      "could not be assessed"
    } else if (r$p < alpha) {
      "was significant"
    } else {
      "was not significant"
    }
    paste0("The ", what, " of ", name, " on ", dv_tex, " ", verdict, " (", stat, ", ", p_macro, ").")
  }, character(1))
}


# Internal: the fixed-effect terms object of a model.
.fixed_terms <- function(model) {
  if (inherits(model, "merMod")) {
    return(stats::terms(model, fixed.only = TRUE))
  }
  if (inherits(model, "lm")) {
    return(stats::terms(model))
  }
  if (inherits(model, c("clm", "clmm")) && !is.null(model$terms)) {
    return(stats::delete.response(model$terms))
  }
  stats::terms(.drop_bars(stats::formula(model)))
}

.model_frame <- function(model) {
  if (!isS4(model) && is.data.frame(model$model)) {
    return(model$model)
  }
  tryCatch(stats::model.frame(model), error = function(e) NULL)
}

.model_contrasts <- function(model) {
  ctr <- NULL
  if (!isS4(model) && is.list(model$contrasts)) ctr <- model$contrasts
  if (is.null(ctr)) {
    ctr <- tryCatch(attr(stats::model.matrix(model), "contrasts"), error = function(e) NULL)
  }
  if (is.null(ctr)) list() else ctr
}

# Internal: how a model variable is coded -- a factor (levels, reference level,
# treatment coding or not), a numeric covariate, or something else (a spline
# basis, a matrix) that is labelled generically.
.var_coding <- function(var, mf, contrasts) {
  vname <- gsub("^`|`$", "", var)
  x <- if (!is.null(mf)) mf[[vname]] else NULL
  if (is.null(x)) {
    return(list(type = "other"))
  }
  if (is.logical(x) || is.character(x)) x <- factor(x)
  if (is.factor(x)) {
    ctr <- contrasts[[vname]]
    if (is.null(ctr)) ctr <- getOption("contrasts")[[if (is.ordered(x)) 2L else 1L]]
    treatment <- (is.character(ctr) && identical(ctr, "contr.treatment")) ||
      (is.function(ctr) && identical(ctr, stats::contr.treatment))
    return(list(type = "factor", levels = levels(x), ref = levels(x)[[1]], treatment = treatment))
  }
  if (is.numeric(x) && is.null(dim(x))) {
    return(list(type = "numeric"))
  }
  list(type = "other")
}

.esc_var <- function(v) latex_escape(gsub("`", "", v))

.coef_label_text <- function(comp) {
  part <- function(ci) {
    if (!is.null(ci$level)) {
      paste0("\\textit{", latex_escape(ci$level), "} vs.\\ \\textit{", latex_escape(ci$ref), "}")
    } else {
      paste0("\\textit{", .esc_var(ci$var), "}")
    }
  }
  if (length(comp) == 1L) {
    ci <- comp[[1]]
    if (!is.null(ci$level)) {
      return(paste0("the contrast ", part(ci), " of \\textit{", .esc_var(ci$var), "}"))
    }
    return(paste0("the slope of \\textit{", .esc_var(ci$var), "}"))
  }
  paste0(
    "the interaction contrast ",
    paste(vapply(comp, function(ci) {
      if (!is.null(ci$level)) paste0("(", part(ci), ")") else part(ci)
    }, character(1)), collapse = " $\\times$ ")
  )
}


# Internal: map each treatment-coded coefficient to an honest label. With
# treatment contrasts, `aa2` is the a2 - a1 difference *at the reference level
# of every variable a interacts with* (a simple effect, not "the effect of a"),
# and a slope in an interaction model is the slope where the interacting
# covariates are 0. Returns a list keyed by coefficient name (backticks
# removed), each entry list(label, cond); NULL when the coding is not
# treatment coding, in which case coefficients are labelled generically.
.coef_label_map <- function(model) {
  tt <- tryCatch(.fixed_terms(model), error = function(e) NULL)
  if (is.null(tt)) {
    return(NULL)
  }
  fac <- attr(tt, "factors")
  labels <- attr(tt, "term.labels")
  if (length(labels) == 0 || is.null(dim(fac))) {
    return(NULL)
  }
  vars <- rownames(fac)
  mf <- .model_frame(model)
  ctr <- .model_contrasts(model)
  coding <- stats::setNames(lapply(vars, .var_coding, mf = mf, contrasts = ctr), vars)
  if (any(vapply(coding, function(z) identical(z$type, "factor") && !isTRUE(z$treatment), logical(1)))) {
    return(NULL)
  }

  out <- list()
  for (t in labels) {
    tv <- vars[fac[, t] > 0]
    if (any(fac[tv, t] == 2)) next
    pieces <- lapply(tv, function(v) {
      vi <- coding[[v]]
      if (identical(vi$type, "factor")) {
        lapply(vi$levels[-1], function(L) list(var = v, level = L, ref = vi$ref, key = paste0(v, L)))
      } else if (identical(vi$type, "numeric")) {
        list(list(var = v, level = NULL, key = v))
      } else {
        NULL
      }
    })
    if (any(vapply(pieces, function(p) length(p) == 0, logical(1)))) next

    higher <- labels[vapply(labels, function(h) {
      all(fac[tv, h] > 0) && sum(fac[, h] > 0) > length(tv)
    }, logical(1))]
    cond_vars <- setdiff(unique(unlist(lapply(higher, function(h) vars[fac[, h] > 0]))), tv)
    cond <- vapply(cond_vars, function(v) {
      vi <- coding[[v]]
      if (identical(vi$type, "factor")) {
        paste0("\\textit{", .esc_var(v), "} = \\textit{", latex_escape(vi$ref), "}")
      } else {
        paste0("\\textit{", .esc_var(v), "} = 0")
      }
    }, character(1), USE.NAMES = FALSE)

    combos <- expand.grid(lapply(pieces, seq_along))
    for (i in seq_len(nrow(combos))) {
      comp <- Map(function(p, j) p[[j]], pieces, as.integer(combos[i, ]))
      key <- paste(vapply(comp, function(ci) ci$key, character(1)), collapse = ":")
      out[[gsub("`", "", key)]] <- list(label = .coef_label_text(comp), cond = cond)
    }
  }
  out
}


# Internal: the opening sentence -- what was fitted and how it was tested.
.report_intro <- function(info, dv_tex, omni, label, exponentiate, ci_method, labelled) {
  s <- paste0(
    "A ", info$kind, if (!is.null(info$family_desc)) paste0(" (", info$family_desc, ")") else "",
    " was fitted for ", dv_tex, "."
  )
  df_txt <- if (!is.null(ci_method)) paste0(", using ", .df_method_label(ci_method)) else ""
  if (!is.null(omni) && nrow(omni) > 0) {
    test <- if (all(omni$stat_name == "F")) "$F$-tests" else "Wald $\\chi^2$ tests"
    s <- paste0(
      s, " Model terms were tested with Type III ", test,
      if (!is.null(ci_method) && all(omni$stat_name == "F")) paste0(" and coefficients with $t$-tests", df_txt) else "",
      "."
    )
  } else if (nzchar(df_txt)) {
    s <- paste0(s, " Coefficients were tested with $t$-tests", df_txt, ".")
  }
  coef_txt <- if (exponentiate && identical(label, info$effect_label) && !is.null(info$effect_long)) {
    paste0(" are reported as ", info$effect_long, " (", label, ")")
  } else if (exponentiate) {
    " are reported exponentiated"
  } else if (!is.na(info$link) && !info$gaussian && !identical(info$link, "identity")) {
    paste0(" are on the ", info$link, " scale")
  } else {
    ""
  }
  if (labelled) {
    coef_txt <- paste0(
      coef_txt, if (nzchar(coef_txt)) " and" else "",
      " are treatment contrasts against each factor's reference level"
    )
  }
  if (nzchar(coef_txt)) s <- paste0(s, " Coefficients", coef_txt, ".")
  s
}


# Internal: shared workhorse for reportGLMM()/reportCLMM().
.report_mixed <- function(model, dv, info, exponentiate, include_intercept,
                          conf_level, alpha, write_to_clipboard, sink_to,
                          omnibus = TRUE) {
  ci_method <- .coef_ci_method(model, info)
  eff <- .mixed_fixed_effects(
    model,
    exponentiate = exponentiate, conf_level = conf_level,
    include_intercept = include_intercept, ci_method = ci_method
  )

  omni <- NULL
  if (isTRUE(omnibus)) {
    omni <- tryCatch(.omnibus_table(model, info), error = function(e) {
      message(
        "Type III omnibus tests could not be computed (", conditionMessage(e),
        "); reporting the coefficients only."
      )
      NULL
    })
  }

  dv_tex <- latex_escape(dv)
  label <- if (!exponentiate) {
    "b"
  } else if (!identical(info$effect_label, "b")) {
    info$effect_label
  } else {
    "\\exp(b)"
  }
  label_map <- .coef_label_map(model)
  intro <- .report_intro(info, dv_tex, omni, label, exponentiate, ci_method, labelled = !is.null(label_map))

  if (nrow(eff) == 0L && (is.null(omni) || nrow(omni) == 0L)) {
    intro <- paste0("A ", info$kind, " was fitted for ", dv_tex, ". No fixed-effect terms were available to report.")
    message(intro)
    if (write_to_clipboard) .write_clipboard(intro)
    if (!is.null(sink_to)) .write_tex(intro, sink_to)
    return(invisible(intro))
  }

  ci_pct <- format(round(conf_level * 100))
  sentences <- .omnibus_sentences(omni, dv_tex, alpha)
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
    lab <- if (!is.null(label_map)) label_map[[gsub("`", "", row$Parameter)]] else NULL
    subject <- if (!is.null(lab)) {
      paste0(
        lab$label,
        if (length(lab$cond)) paste0(" (at ", paste(lab$cond, collapse = " and "), ")") else ""
      )
    } else {
      paste0("the coefficient \\textit{", latex_escape(row$Parameter), "}")
    }
    subject <- paste0(toupper(substr(subject, 1, 1)), substring(subject, 2))
    sentence <- paste0(
      subject, " on ", dv_tex, " ",
      if (p_na) "could not be assessed" else if (significant) "was significant" else "was not significant",
      " (", clause, ")."
    )
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
#' Turns a fitted mixed model into ready-to-paste manuscript sentences: first a
#' Type III omnibus test per model term (main effects and interactions), then
#' one sentence per fixed-effect coefficient with its estimate (or odds /
#' incidence-rate ratio), confidence interval, test statistic and p-value.
#' Works with linear mixed models (\code{lme4::lmer}, \code{lmerTest::lmer}),
#' generalized linear mixed models (\code{lme4::glmer},
#' \code{glmmTMB::glmmTMB}) and, for convenience, ordinary \code{lm},
#' \code{glm} and \code{MASS::glm.nb} fits.
#'
#' \strong{Omnibus tests.} With treatment (dummy) coding -- R's default -- a
#' coefficient such as \code{aa2} in \code{y ~ a * b} is the a2 - a1
#' difference \emph{at the reference level of b}, not "the effect of a", and a
#' factor with three or more levels has no single coefficient at all. The
#' omnibus tests answer the questions a results section asks: for linear mixed
#' models, \pkg{lmerTest}'s Type III \eqn{F}-tests with Satterthwaite's degrees
#' of freedom; for all other models, \code{emmeans::joint_tests()} (Type III
#' Wald \eqn{F} for \code{lm}, Wald \eqn{\chi^2} otherwise). Both are
#' independent of the contrast coding. The coefficient sentences that follow
#' are labelled as what they are, e.g. "the contrast a2 vs. a1 of a (at b =
#' b1)", "the slope of age (at cond = A)".
#'
#' \strong{Degrees of freedom.} Coefficient \eqn{t}-tests of linear mixed
#' models use Satterthwaite's degrees of freedom (\pkg{lmerTest}; the
#' asymptotic normal approximation when it is not installed), and the sentence
#' says so -- never the residual degrees of freedom.
#'
#' \strong{Effect labels.} Coefficients are exponentiated automatically only
#' where the ratio has a name: odds ratios (OR) for a logit link, risk ratios
#' (RR) for a binomial log link, incidence-rate ratios (IRR) for a log-link
#' count family (Poisson, negative binomial). Other links (probit, cloglog,
#' identity) report the raw coefficient and name the link. Only the
#' conditional-mean (location) coefficients are reported: zero-inflation,
#' dispersion and scale parameters are not predictor effects on the mean.
#'
#' The reported statistics rely on the \pkg{parameters} package. The LaTeX
#' output uses the \code{\\p}/\code{\\pminor} and \code{\\F} macros from
#' [latex_preamble()].
#'
#' @param model A fitted model (\code{lmer}, \code{glmer}, \code{glmmTMB},
#'   \code{lm}, \code{glm}, or \code{glm.nb}).
#' @param dv Name of the dependent variable, used in the sentence text.
#' @param exponentiate \code{"auto"} (default; exponentiate for logit-link
#'   binomial and log-link count families), or \code{TRUE}/\code{FALSE} to
#'   force it.
#' @param include_intercept Whether to also report the intercept. Default
#'   \code{FALSE}.
#' @param conf_level Confidence level for the intervals. Default 0.95.
#' @param write_to_clipboard Whether to copy the sentences to the clipboard.
#' @param sink_to Optional path of a \code{.tex} file to write the sentences to,
#'   so a manuscript can \code{\\input{}} them.
#' @param omnibus Logical. Report the Type III omnibus test of every model term
#'   before the coefficients. Default \code{TRUE}; needs \pkg{lmerTest} (linear
#'   mixed models) or \pkg{emmeans} (all other models).
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
                       write_to_clipboard = FALSE, sink_to = NULL, omnibus = TRUE) {
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
    alpha = 0.05, write_to_clipboard = write_to_clipboard, sink_to = sink_to,
    omnibus = omnibus
  )
}


#' Report a cumulative link (mixed) model in LaTeX/APA style
#'
#' Reporter for ordinal proportional-odds models fitted with \pkg{ordinal}:
#' cumulative link mixed models (\code{ordinal::clmm}) and their fixed-effects
#' counterpart (\code{ordinal::clm}). Each model term is first tested with a
#' Type III Wald \eqn{\chi^2} test (\code{emmeans::joint_tests()},
#' independent of the contrast coding); each location coefficient is then
#' reported -- as an odds ratio for the logit link (the multiplicative change
#' in the odds of being in a higher outcome category), as the raw coefficient
#' with the link named otherwise -- with its confidence interval, z statistic
#' and p-value, labelled as the contrast it is (see [reportGLMM()]).
#'
#' @param model A fitted \code{ordinal::clmm} or \code{ordinal::clm} model.
#' @param dv Name of the (ordinal) dependent variable, used in the sentence text.
#' @param exponentiate \code{"auto"} (default; odds ratios for the logit link,
#'   raw coefficients for probit, cloglog and other links) or
#'   \code{TRUE}/\code{FALSE} to force it. \code{FALSE} reports raw log-odds.
#' @param conf_level Confidence level for the intervals. Default 0.95.
#' @param write_to_clipboard Whether to copy the sentences to the clipboard.
#' @param sink_to Optional path of a \code{.tex} file to write the sentences to.
#' @param omnibus Logical. Report the Type III omnibus test of every model term
#'   before the coefficients. Default \code{TRUE}; needs \pkg{emmeans}.
#'
#' @details Only the location coefficients are reported: the thresholds
#'   (cut-points, including the \code{threshold.1}/\code{spacing} parameters of
#'   equidistant thresholds), scale effects and nominal effects are not
#'   predictor effects on the location, so unlike [reportGLMM()] this reporter
#'   has no \code{include_intercept} argument.
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
                       write_to_clipboard = FALSE, sink_to = NULL, omnibus = TRUE) {
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
    alpha = 0.05, write_to_clipboard = write_to_clipboard, sink_to = sink_to,
    omnibus = omnibus
  )
}
