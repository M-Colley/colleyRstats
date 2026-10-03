# Fitting the model that recommend_test() recommends.
#
# recommend_test() stops at advice: it returns the name of a function and a
# fit_call string to paste. That leaves the most error-prone step -- getting the
# outcome into the class the model needs, building the random-effect term,
# picking the post-hoc machinery that matches the fit -- to be redone by hand in
# every project. fit_recommended() carries the recommendation through to a
# fitted model, its post-hoc contrasts, and the manuscript sentence, so the
# choice of test and the analysis that is actually run cannot drift apart.


# Internal: build the model formula implied by a recommendation. Names are
# backtick-quoted, so "tlx-mental" or "Condition ID" survive being pasted into
# a formula. `random` overrides the default random-intercept term.
.fit_formula <- function(outcome, predictors, cluster = NULL, interaction = TRUE, random = NULL) {
  fixed <- if (is.null(predictors) || length(predictors) == 0) {
    "1"
  } else {
    paste(.bt(predictors), collapse = if (interaction) " * " else " + ")
  }
  re <- if (!is.null(random)) {
    random
  } else if (!is.null(cluster)) {
    paste0("(1 | ", .bt(cluster), ")")
  } else {
    NULL
  }
  rhs <- if (is.null(re)) fixed else paste0(fixed, " + ", re)
  stats::as.formula(paste(.bt(outcome), "~", rhs))
}


# Internal: coerce the columns a model family requires into the class it needs,
# reporting every coercion. Silently turning a numeric 1-5 rating into an
# ordered factor changes what is being estimated, so it is said out loud -- as
# is turning a numeric predictor into a factor, or leaving a few-valued numeric
# predictor numeric.
.fit_coerce <- function(data, outcome, predictors, cluster, outcome_type,
                        categorical = NULL, verbose = TRUE) {
  say <- function(...) if (isTRUE(verbose)) message(...)
  if (is.null(categorical)) categorical <- .categorical_predictors(data, predictors, cluster)

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
    lv <- levels(data[[outcome]])
    if (length(lv) == 2L) {
      say("Coerced `", outcome, "` to a factor; modelling P(", lv[2], ").")
    } else {
      # A binomial model codes the first level as failure and EVERY other level
      # as success, so with three codes it models P(not first), not P(second).
      warning(
        "`", outcome, "` has ", length(lv), " distinct values but was declared binary: ",
        "the binomial model contrasts '", lv[1], "' with all other values, i.e. it models ",
        "P(", outcome, " != ", lv[1], "). Recode it to two values if that is not what you mean.",
        call. = FALSE
      )
    }
  }

  # A nominal outcome stored as text: mblogit() and multinom() need a factor
  # (mblogit refuses a character response outright).
  if (identical(outcome_type, "nominal") && !is.factor(data[[outcome]])) {
    data[[outcome]] <- factor(data[[outcome]])
    say(
      "Coerced `", outcome, "` to a factor with ", nlevels(data[[outcome]]),
      " categories; '", levels(data[[outcome]])[1], "' is the reference category."
    )
  }

  for (p in predictors) {
    v <- data[[p]]
    if (isTRUE(categorical[[p]]) && !is.factor(v)) {
      data[[p]] <- factor(v)
      if (is.numeric(v)) {
        say(
          "Treating numeric predictor `", p, "` (values ",
          paste(utils::head(levels(data[[p]]), 6), collapse = ", "),
          if (nlevels(data[[p]]) > 6) ", ..." else "",
          ") as categorical: its values look like condition codes. Declare the ",
          "categorical predictors with `factors` to override (factors = character(0) ",
          "keeps every numeric predictor numeric)."
        )
      } else {
        say("Coerced predictor `", p, "` to a factor with ", nlevels(data[[p]]), " levels.")
      }
    } else if (!isTRUE(categorical[[p]]) && is.numeric(v) &&
      length(unique(stats::na.omit(v))) <= 10L) {
      say(
        "Kept numeric predictor `", p, "` (", length(unique(stats::na.omit(v))),
        " distinct values) as a continuous covariate; list it in `factors` to treat it ",
        "as categorical."
      )
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


# Internal: evaluate a model-fitting call so that the fitted object is
# self-contained. The call is built with the formula itself (so it prints
# readably) and `data` bound in an environment that is also the formula's
# environment: emmeans' recover_data() and lme4's update() look the data up
# there, so post-hoc contrasts and Type III tests work on the returned object
# outside this function. Warnings and messages are captured, not printed, so
# the caller can decide which of them describe the final model.
.fit_eval <- function(fun, formula, data, ...) {
  env <- new.env(parent = globalenv())
  assign("data", data, envir = env)
  environment(formula) <- env
  cl <- as.call(c(list(fun), list(formula = formula, data = quote(data)), list(...)))
  warns <- character(0)
  msgs <- character(0)
  model <- withCallingHandlers(
    eval(cl, env),
    warning = function(w) {
      warns <<- c(warns, conditionMessage(w))
      invokeRestart("muffleWarning")
    },
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  list(model = model, warnings = warns, messages = msgs)
}


.conv_pattern <- "converge|Hessian|non-positive-definite"


# Internal: is a mixed model's random-effects structure singular (a variance
# estimated at zero, or a correlation at +/-1)?
.is_singular_fit <- function(m, tol = 1e-4) {
  if (inherits(m, "merMod")) {
    return(lme4::isSingular(m, tol = tol))
  }
  vc <- NULL
  if (inherits(m, "clmm")) {
    vc <- ordinal::VarCorr(m)
  } else if (inherits(m, "glmmTMB")) {
    vc <- glmmTMB::VarCorr(m)$cond
  }
  if (is.null(vc)) {
    return(FALSE)
  }
  sds <- unlist(lapply(vc, function(v) attr(v, "stddev")))
  cors <- unlist(lapply(vc, function(v) {
    r <- attr(v, "correlation")
    if (is.null(r) || length(r) < 4) numeric(0) else r[upper.tri(r)]
  }))
  any(sds < tol) || any(abs(cors) > 1 - tol, na.rm = TRUE)
}


# Internal: fit a mixed model with the maximal justified random-effects
# structure, simplifying it step by step -- interaction slopes, then main-effect
# slopes, then random intercepts only -- while the fit is singular or fails to
# converge (Barr et al., 2013; Matuschek et al., 2017). A convergence warning
# first earns one refit with a more patient optimiser (`retry_control`). The
# simplest structure is kept, flagged, when nothing simpler is left.
.fit_mixed <- function(fun, outcome, predictors, cluster, candidates, data,
                       interaction = TRUE, extra = list(), retry_control = NULL) {
  conv_bad <- function(w) any(grepl(.conv_pattern, w, ignore.case = TRUE))
  attempts <- list()
  for (re in candidates) {
    fml <- .fit_formula(outcome, predictors, cluster, interaction, random = re)
    res <- tryCatch(
      do.call(.fit_eval, c(list(fun, fml, data), extra)),
      error = function(e) list(error = conditionMessage(e))
    )
    if (is.null(res$error) && conv_bad(res$warnings) && !is.null(retry_control)) {
      retry <- tryCatch(
        do.call(.fit_eval, c(list(fun, fml, data), extra, list(control = retry_control))),
        error = function(e) NULL
      )
      if (!is.null(retry) && !conv_bad(retry$warnings)) res <- retry
    }
    res$random <- re
    if (is.null(res$error)) {
      res$converged <- !conv_bad(res$warnings)
      res$singular <- isTRUE(tryCatch(.is_singular_fit(res$model), error = function(e) FALSE))
    }
    attempts[[length(attempts) + 1L]] <- res
    if (is.null(res$error) && res$converged && !res$singular) break
  }
  ok <- Filter(function(a) is.null(a$error), attempts)
  if (length(ok) == 0) {
    stop(attempts[[length(attempts)]]$error, call. = FALSE)
  }
  clean <- Filter(function(a) a$converged && !a$singular, ok)
  final <- if (length(clean) > 0) clean[[1]] else ok[[length(ok)]]
  first <- attempts[[1]]
  final$dropped <- if (identical(final$random, candidates[[1]])) {
    NULL
  } else if (!is.null(first$error)) {
    "not estimable"
  } else if (isTRUE(first$singular)) {
    "singular (a variance component was estimated at zero or a correlation at +/-1)"
  } else {
    "not converged"
  }
  final
}


# Internal: the call that was run, as a string with the data argument shown as
# `your_data`, e.g. "stats::glm(hit ~ cond, family = binomial, data = your_data)".
.call_string <- function(fun, formula, extra = NULL) {
  paste0(
    fun, "(", paste(deparse(formula, width.cutoff = 500L), collapse = " "),
    if (length(extra)) paste0(", ", paste(extra, collapse = ", ")) else "",
    ", data = your_data)"
  )
}


# Internal: rename columns with non-syntactic names ("Condition ID",
# "tlx-mental") to syntactic ones for the engines that cannot take backticked
# names (ARTool, nparLD, mclogit). Returns the renamed data and the map
# original -> safe name.
.safe_rename <- function(data, vars) {
  vars <- unique(vars)
  safe <- make.names(vars, unique = TRUE)
  need <- safe != vars
  if (!any(need)) {
    return(list(data = data, map = stats::setNames(vars, vars), renamed = FALSE))
  }
  taken <- setdiff(names(data), vars)
  for (i in which(need)) {
    while (safe[[i]] %in% c(taken, safe[-i])) safe[[i]] <- paste0(safe[[i]], "_")
  }
  names(data)[match(vars, names(data))] <- safe
  list(data = data, map = stats::setNames(safe, vars), renamed = TRUE)
}

# Internal: map "safe1:safe2" term labels back to the original names.
.unsafe_term <- function(x, map) {
  vapply(as.character(x), function(t) {
    parts <- strsplit(trimws(t), ":", fixed = TRUE)[[1]]
    idx <- match(parts, map)
    parts[!is.na(idx)] <- names(map)[idx[!is.na(idx)]]
    paste(parts, collapse = ":")
  }, character(1), USE.NAMES = FALSE)
}


# Internal: a standard omnibus table (term, df1, df2, statistic, stat_name, p)
# from an ANOVA table of aov, afex, car::Anova or ARTool.
.anova_rows <- function(tab) {
  tab <- as.data.frame(tab)
  terms <- if ("Term" %in% names(tab)) as.character(tab$Term) else trimws(rownames(tab))
  fcol <- intersect(c("F value", "F"), names(tab))
  df1col <- intersect(c("num Df", "NumDF", "Df"), names(tab))
  if (length(fcol) == 0 || length(df1col) == 0 || !"Pr(>F)" %in% names(tab)) {
    return(NULL)
  }
  fcol <- fcol[[1]]
  df1col <- df1col[[1]]
  df2 <- if ("den Df" %in% names(tab)) {
    tab[["den Df"]]
  } else if ("Df.res" %in% names(tab)) {
    tab[["Df.res"]]
  } else if ("DenDF" %in% names(tab)) {
    tab[["DenDF"]]
  } else if (any(terms == "Residuals")) {
    rep(tab[terms == "Residuals", df1col][[1]], nrow(tab))
  } else {
    rep(NA_real_, nrow(tab))
  }
  keep <- !(terms %in% c("(Intercept)", "Residuals")) & !is.na(tab[["Pr(>F)"]])
  data.frame(
    term = gsub("`", "", terms[keep]), df1 = tab[[df1col]][keep], df2 = df2[keep],
    statistic = tab[[fcol]][keep], stat_name = "F", p = tab[["Pr(>F)"]][keep],
    method = "F", stringsAsFactors = FALSE
  )
}


# Internal: fit the model a recommendation names. Returns the fitted object
# plus the engine that produced it, the function actually called, the call as
# a string, and -- for mixed models -- the random-effects structure that was
# kept and why a richer one was dropped.
.fit_dispatch <- function(rec, data, interaction = TRUE, verbose = TRUE) {
  outcome <- rec$outcome
  predictors <- rec$predictors
  cluster <- if (isTRUE(rec$clustered)) rec$cluster else NULL
  categorical <- rec$categorical
  if (is.null(categorical)) categorical <- .categorical_predictors(data, predictors, cluster)
  cat_preds <- names(categorical)[categorical]
  no_re <- .fit_formula(outcome, predictors, NULL, interaction = interaction)
  candidates <- if (!is.null(cluster)) {
    .random_terms(cluster, rec$random$slopes, rec$random$slope_interaction, interaction)
  } else {
    NULL
  }

  result <- function(model, engine, reporter, fun, call_str, report_object = NULL,
                     anova = NULL, random = NULL, dropped = NULL, singular = FALSE,
                     converged = TRUE, warnings = character(0), messages = character(0),
                     name_map = NULL) {
    list(
      model = model, engine = engine, reporter = reporter, fun = fun,
      call_str = call_str, report_object = report_object, anova = anova,
      random = random, dropped = dropped, singular = singular,
      converged = converged, warnings = warnings, messages = messages,
      name_map = name_map
    )
  }
  mixed <- function(fun_chr, fun, extra = list(), extra_str = NULL, engine, reporter,
                    retry_control = NULL) {
    r <- .fit_mixed(fun, outcome, predictors, cluster, candidates, data,
      interaction = interaction, extra = extra, retry_control = retry_control
    )
    result(
      r$model, engine, reporter, fun_chr,
      .call_string(fun_chr, stats::formula(r$model), extra_str),
      random = r$random, dropped = r$dropped, singular = r$singular,
      converged = r$converged, warnings = r$warnings, messages = r$messages
    )
  }
  single <- function(fun_chr, fun, formula, extra = list(), extra_str = NULL, engine,
                     reporter, ...) {
    r <- do.call(.fit_eval, c(list(fun, formula, data), extra))
    result(r$model, engine, reporter, fun_chr, .call_string(fun_chr, formula, extra_str),
      warnings = r$warnings, messages = r$messages, ...
    )
  }

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
      mixed("ordinal::clmm", quote(ordinal::clmm), engine = "clmm", reporter = "report_clmm")
    },
    "ordinal::clm" = {
      .fit_need("ordinal", "a cumulative link model")
      single("ordinal::clm", quote(ordinal::clm), no_re, engine = "clm", reporter = "report_clmm")
    },
    "lme4::glmer" = {
      .fit_need("lme4", "a generalized linear mixed model")
      binary <- identical(rec$outcome_type, "binary")
      mixed(
        "lme4::glmer", quote(lme4::glmer),
        extra = list(family = if (binary) quote(stats::binomial()) else quote(stats::poisson())),
        extra_str = paste0("family = ", if (binary) "binomial" else "poisson"),
        engine = "glmer", reporter = "report_glmm",
        retry_control = quote(lme4::glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5)))
      )
    },
    "glmmTMB::glmmTMB" = {
      .fit_need("glmmTMB", "a negative-binomial mixed model")
      mixed(
        "glmmTMB::glmmTMB", quote(glmmTMB::glmmTMB),
        extra = list(family = quote(glmmTMB::nbinom2)),
        extra_str = "family = glmmTMB::nbinom2",
        engine = "glmmtmb", reporter = "report_glmm"
      )
    },
    "stats::glm" = {
      binary <- identical(rec$outcome_type, "binary")
      single(
        "stats::glm", quote(stats::glm), no_re,
        extra = list(family = if (binary) quote(stats::binomial()) else quote(stats::poisson())),
        extra_str = paste0("family = ", if (binary) "binomial" else "poisson"),
        engine = "glm", reporter = "report_glmm"
      )
    },
    "MASS::glm.nb" = {
      .fit_need("MASS", "a negative-binomial regression")
      single("MASS::glm.nb", quote(MASS::glm.nb), no_re, engine = "glmnb", reporter = "report_glmm")
    },
    "lme4::lmer" = ,
    "lmerTest::lmer" = {
      # lmerTest adds Satterthwaite degrees of freedom, which is what makes a
      # mixed model reportable in APA form at all; lme4 alone gives no p-values.
      control <- quote(lme4::lmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5)))
      if (requireNamespace("lmerTest", quietly = TRUE)) {
        mixed("lmerTest::lmer", quote(lmerTest::lmer),
          engine = "lmer", reporter = "report_glmm", retry_control = control
        )
      } else {
        .fit_need("lme4", "a linear mixed model")
        if (isTRUE(verbose)) {
          message(
            "Install 'lmerTest' for Satterthwaite degrees of freedom and p-values; ",
            "fitting with lme4 alone."
          )
        }
        mixed("lme4::lmer", quote(lme4::lmer),
          engine = "lmer", reporter = "report_glmm", retry_control = control
        )
      }
    },
    "ARTool::art" = {
      .fit_need("ARTool", "an aligned rank transform model")
      numeric_preds <- setdiff(predictors, cat_preds)
      if (length(numeric_preds) > 0) {
        stop(
          "The aligned rank transform accepts only categorical predictors, but ",
          paste0("`", numeric_preds, "`", collapse = ", "), " is numeric. Model a ",
          "covariate with a (mixed) linear model, or declare a column of condition ",
          "codes categorical with `factors`.",
          call. = FALSE
        )
      }
      if (!isTRUE(interaction) && length(predictors) > 1L) {
        stop(
          "The aligned rank transform needs the full factorial model -- ARTool aligns ",
          "the response for each effect by removing all the others -- so it cannot be ",
          "fitted with `interaction = FALSE`. Use interaction = TRUE.",
          call. = FALSE
        )
      }
      sr <- .safe_rename(data, c(outcome, predictors, cluster))
      m <- sr$map
      fml <- .fit_formula(m[[outcome]], unname(m[predictors]), if (!is.null(cluster)) m[[cluster]] else NULL)
      r <- .fit_eval(quote(ARTool::art), fml, sr$data)
      # report_art() reports an ANOVA table, not the art object -- its first act
      # is to look for a "Pr(>F)" column. Keep the art fit in $model (art.con()
      # needs it) and hand the reporter the table, labelled with the original
      # column names.
      # anova() refits ARTool's per-effect models; their lme4 chatter is about
      # those internal aligned-rank fits, not the user's model.
      tab <- suppressMessages(stats::anova(r$model))
      if (sr$renamed && "Term" %in% names(tab)) tab$Term <- .unsafe_term(tab$Term, m)
      result(
        r$model, "art", "report_art", "ARTool::art",
        .call_string("ARTool::art", .fit_formula(outcome, predictors, cluster)),
        report_object = tab, anova = .anova_rows(tab),
        random = if (!is.null(cluster)) paste0("(1 | ", .bt(cluster), ")") else NULL,
        warnings = r$warnings, messages = r$messages, name_map = m
      )
    },
    "nparLD::nparLD" = {
      .fit_need("nparLD", "a rank-based repeated-measures model")
      if (length(predictors) != 1L || is.null(cluster) || !isTRUE(rec$within[predictors])) {
        stop(
          "nparLD needs exactly one within-subject factor -- a predictor that varies ",
          "within `cluster` -- and the cluster column. A between-subjects factor with ",
          "repeated rows per cluster needs a mixed model or ARTool::art() with a ",
          "random intercept instead.",
          call. = FALSE
        )
      }
      # nparLD refuses a participant missing a condition ("Some subjects are
      # missing subplot levels"). As in every paired analysis here, it is fitted on
      # the participants observed in all conditions (.complete_within()).
      data <- .complete_within(
        data, cluster, predictors, outcome,
        context = if (isTRUE(verbose)) paste0("nparLD analysis of '", outcome, "': ") else NULL
      )$data
      data[c(predictors, cluster)] <- lapply(data[c(predictors, cluster)], function(v) {
        if (is.factor(v)) droplevels(v) else v
      })
      sr <- .safe_rename(data, c(outcome, predictors, cluster))
      m <- sr$map
      f <- stats::as.formula(paste(m[[outcome]], "~", m[[predictors]]))
      # nparLD before 2.3.0 prints a description of the design to stdout and
      # offers no argument to turn it off, so it is captured rather than passed.
      model <- NULL
      invisible(utils::capture.output(
        model <- nparLD::nparLD(f, data = as.data.frame(sr$data), subject = m[[cluster]])
      ))
      if (sr$renamed) {
        for (nm in c("ANOVA.test", "ATS", "Wald.test", "ANOVA.test.mod.Box")) {
          if (!is.null(model[[nm]]) && !is.null(rownames(model[[nm]]))) {
            rownames(model[[nm]]) <- .unsafe_term(rownames(model[[nm]]), m)
          }
        }
      }
      result(
        model, "nparld", "report_nparld", "nparLD::nparLD",
        paste0(
          "nparLD::nparLD(", .bt(outcome), " ~ ", .bt(predictors), ", subject = \"",
          cluster, "\", data = your_data)"
        ),
        name_map = m
      )
    },
    "stats::aov" = {
      r <- single("stats::aov", quote(stats::aov), no_re, engine = "aov", reporter = NA_character_)
      r$anova <- .anova_rows(summary(r$model)[[1]])
      r
    },
    "afex::aov_car" = {
      # Type III sums of squares with sum-to-zero contrasts: in an unbalanced
      # factorial design the sequential (Type I) tests of stats::aov() depend on
      # the order in which the predictors are listed.
      cc <- stats::complete.cases(data[, c(outcome, predictors), drop = FALSE])
      d <- data[cc, , drop = FALSE]
      if (requireNamespace("afex", quietly = TRUE)) {
        id <- ".colley_row"
        while (id %in% names(d)) id <- paste0(id, "_")
        d[[id]] <- factor(seq_len(nrow(d)))
        fixed <- paste(.bt(predictors), collapse = if (interaction) " * " else " + ")
        fml <- stats::as.formula(paste(.bt(outcome), "~", fixed, "+ Error(", .bt(id), ")"))
        r <- .fit_eval(quote(afex::aov_car), fml, d)
        result(
          r$model, "afex", NA_character_, "afex::aov_car",
          paste0(
            "afex::aov_car(", .bt(outcome), " ~ ", fixed,
            " + Error(row_id), data = your_data)"
          ),
          report_object = r$model$anova_table, anova = .anova_rows(r$model$anova_table),
          warnings = r$warnings, messages = r$messages
        )
      } else {
        .fit_need("car", "a Type III factorial ANOVA (or install 'afex')")
        ctr <- stats::setNames(rep(list("contr.sum"), length(cat_preds)), cat_preds)
        r <- .fit_eval(quote(stats::lm), no_re, d, contrasts = ctr)
        tab <- car::Anova(r$model, type = 3)
        result(
          r$model, "anova3", NA_character_, "car::Anova",
          paste0(
            "car::Anova(", .call_string("stats::lm", no_re, paste0(
              "contrasts = list(", paste0(.bt(cat_preds), " = \"contr.sum\"", collapse = ", "), ")"
            )), ", type = 3)"
          ),
          report_object = tab, anova = .anova_rows(tab),
          warnings = r$warnings, messages = r$messages
        )
      }
    },
    "car::Anova" = {
      .fit_need("car", "a heteroscedasticity-robust (HC3) factorial ANOVA")
      ctr <- stats::setNames(rep(list("contr.sum"), length(cat_preds)), cat_preds)
      r <- .fit_eval(quote(stats::lm), no_re, data, contrasts = ctr)
      # car announces "Coefficient covariances computed by hccm()"; the call
      # string and the methods text already say so.
      tab <- suppressMessages(car::Anova(r$model, type = 3, white.adjust = "hc3"))
      result(
        r$model, "lm_hc3", NA_character_, "car::Anova",
        paste0(
          "car::Anova(", .call_string("stats::lm", no_re, paste0(
            "contrasts = list(", paste0(.bt(cat_preds), " = \"contr.sum\"", collapse = ", "), ")"
          )), ", type = 3, white.adjust = \"hc3\")"
        ),
        report_object = tab, anova = .anova_rows(tab),
        warnings = r$warnings, messages = r$messages
      )
    },
    "stats::oneway.test" = result(
      stats::oneway.test(one_way, data = data, var.equal = FALSE), "htest", NA_character_,
      "stats::oneway.test", .call_string("stats::oneway.test", one_way, "var.equal = FALSE")
    ),
    "stats::kruskal.test" = result(
      stats::kruskal.test(one_way, data = data), "htest", NA_character_,
      "stats::kruskal.test", .call_string("stats::kruskal.test", one_way)
    ),
    "stats::wilcox.test" = result(
      stats::wilcox.test(one_way, data = data), "htest", NA_character_,
      "stats::wilcox.test", .call_string("stats::wilcox.test", one_way)
    ),
    "stats::lm" = single("stats::lm", quote(stats::lm), no_re, engine = "lm", reporter = "report_glmm"),
    "nnet::multinom" = {
      .fit_need("nnet", "a multinomial logistic regression")
      # summary.multinom() re-evaluates the recorded call, so that call must not
      # name .fit_dispatch()'s locals or print(fit) dies with "object 'no_re'
      # not found". do.call() with quote = FALSE splices the formula and the
      # data frame themselves into the call, which is what makes the fitted
      # object self-contained.
      result(
        do.call(nnet::multinom, list(no_re, data = data, trace = FALSE)),
        "multinom", NA_character_, "nnet::multinom", .call_string("nnet::multinom", no_re)
      )
    },
    "mclogit::mblogit" = {
      # A clustered nominal outcome: each participant's repeated choices are not
      # independent, so the cluster needs a random intercept. nnet::multinom()
      # would treat them as independent (pseudo-replication).
      .fit_need("mclogit", "a multinomial logistic mixed model for a clustered nominal outcome")
      if (is.null(cluster)) {
        stop("A clustered nominal outcome needs the `cluster` column.", call. = FALSE)
      }
      sr <- .safe_rename(data, c(outcome, predictors, cluster))
      m <- sr$map
      fml <- .fit_formula(m[[outcome]], unname(m[predictors]), NULL, interaction = interaction)
      rnd <- stats::as.formula(paste("~ 1 |", m[[cluster]]))
      # mclogit reports its inner iterations on both stdout and stderr even
      # with trace = FALSE; its warnings are still captured by .fit_eval().
      r <- NULL
      invisible(utils::capture.output(utils::capture.output(
        r <- .fit_eval(quote(mclogit::mblogit), fml, sr$data, random = rnd, trace = FALSE),
        type = "message"
      )))
      result(
        r$model, "mblogit", NA_character_, "mclogit::mblogit",
        .call_string("mclogit::mblogit", no_re, paste0("random = ~ 1 | ", .bt(cluster))),
        random = paste0("(1 | ", .bt(cluster), ")"),
        warnings = r$warnings, messages = r$messages, name_map = m
      )
    },
    stop(
      "fit_recommended() cannot yet fit '", rec$model_function,
      "'. Fit it yourself with:\n  ", rec$fit_call,
      call. = FALSE
    )
  )
}


# Internal: plain names of multiplicity adjustments, for the methods sentence.
.adjust_label <- function(adjust) {
  switch(tolower(adjust),
    holm = "Holm",
    bonferroni = "Bonferroni",
    tukey = "Tukey",
    sidak = "Sidak",
    hs = "Holm-Sidak",
    hochberg = "Hochberg",
    hommel = "Hommel",
    fdr = ,
    bh = "Benjamini-Hochberg",
    by = "Benjamini-Yekutieli",
    mvt = "multivariate-t",
    scheffe = "Scheffe",
    adjust
  )
}


# Internal: a contrast summary in one standard shape, whatever produced it.
.std_contrasts <- function(s, term, by, adjust) {
  pick <- function(cands) {
    x <- intersect(cands, names(s))
    if (length(x)) s[[x[[1]]]] else rep(NA_real_, nrow(s))
  }
  est_name <- intersect(c("estimate", "odds.ratio", "ratio", "difference"), names(s))[[1]]
  by_lab <- if (!is.null(s$.by)) {
    s$.by
  } else if (length(by) && all(by %in% names(s))) {
    apply(s[by], 1, function(r) paste0(by, " = ", trimws(r), collapse = ", "))
  } else {
    rep(NA_character_, nrow(s))
  }
  data.frame(
    term = rep(term, nrow(s)), by = by_lab, contrast = as.character(s$contrast),
    estimate = s[[est_name]],
    scale = switch(est_name,
      odds.ratio = "odds ratio",
      ratio = "ratio",
      "difference"
    ),
    SE = pick("SE"), df = pick("df"),
    lower.CL = pick(c("lower.CL", "asymp.LCL")), upper.CL = pick(c("upper.CL", "asymp.UCL")),
    statistic = pick(c("t.ratio", "z.ratio")), p.value = s$p.value,
    adjust = rep(adjust, nrow(s)), stringsAsFactors = FALSE, row.names = NULL
  )
}


# Internal: for each contrast of an ART-C interaction term, the two cells it
# compares, as list(first, second) of per-factor levels (NULL where it cannot be
# told). ART-C pastes the factors of the term into one with "," between the
# levels ("b,1,x"), and emmeans parenthesises labels holding "-" -- so splitting
# the contrast labels on " - " and "," misreads level names such as "low - fast"
# or "b,1". The cells are instead read from the contrast coefficients (+1 on the
# first cell, -1 on the second) and looked up among the real combinations of
# the factor levels; a combination that two different cells would spell the
# same way is an error rather than a guess.
.art_con_cell_pairs <- function(con, data, vars) {
  cc <- con@misc$con.coef
  og <- con@misc$orig.grid
  if (!is.matrix(cc) || !is.data.frame(og) || ncol(og) != 1L) {
    stop("ART-C contrasts of an interaction have an unexpected layout.", call. = FALSE)
  }
  combos <- expand.grid(
    lapply(vars, function(v) levels(droplevels(as.factor(data[[v]])))),
    stringsAsFactors = FALSE
  )
  key <- do.call(paste, c(unname(as.list(combos)), sep = ","))
  if (anyDuplicated(key)) {
    stop("Level names containing \",\" make the ART-C cells of `",
         paste(vars, collapse = ":"), "` ambiguous; rename those levels.", call. = FALSE)
  }
  cell <- function(lbl) {
    r <- match(lbl, key)
    if (is.na(r)) NULL else unname(unlist(combos[r, ]))
  }
  og_lab <- as.character(og[[1]])
  lapply(seq_len(nrow(cc)), function(i) {
    pos <- which(cc[i, ] > 0)
    neg <- which(cc[i, ] < 0)
    if (length(pos) != 1L || length(neg) != 1L) {
      return(NULL)
    }
    a <- cell(og_lab[pos])
    b <- cell(og_lab[neg])
    if (is.null(a) || is.null(b)) NULL else list(a, b)
  })
}


# Internal: one family of pairwise contrasts -- the levels of `f`, averaged over
# the other factors (by = NULL), or compared within each level of `by` (simple
# effects). Returns list(grid, table).
.contrast_family <- function(fit, f, by, adjust, order) {
  term <- if (length(by)) paste0(f, " | ", paste(by, collapse = ", ")) else f
  if (identical(fit$engine, "art")) {
    m <- fit$name_map
    if (!length(by)) {
      con <- ARTool::art.con(fit$model, unname(m[[f]]), adjust = adjust)
      return(list(grid = con, table = .std_contrasts(as.data.frame(con), term, NULL, adjust)))
    }
    # ART-C has no `by`: compare the cells of the interaction term and keep the
    # pairs that share the levels of `by`, adjusting within each of its levels.
    vars <- order[order %in% c(f, by)]
    con <- ARTool::art.con(fit$model, paste(unname(m[vars]), collapse = ":"), adjust = "none")
    s <- as.data.frame(con)
    lv <- .art_con_cell_pairs(con, fit$model$data, unname(m[vars]))
    fi <- match(f, vars)
    bi <- match(by, vars)
    keep <- vapply(lv, function(z) {
      !is.null(z) && identical(z[[1]][bi], z[[2]][bi]) && !identical(z[[1]][fi], z[[2]][fi])
    }, logical(1))
    s <- s[keep, , drop = FALSE]
    lv <- lv[keep]
    s$.by <- vapply(lv, function(z) paste0(by, " = ", z[[1]][bi], collapse = ", "), character(1))
    s$contrast <- vapply(lv, function(z) paste(z[[1]][fi], "-", z[[2]][fi]), character(1))
    method <- if (adjust %in% stats::p.adjust.methods) adjust else "holm"
    s$p.value <- stats::ave(s$p.value, s$.by, FUN = function(p) stats::p.adjust(p, method = method))
    return(list(grid = con, table = .std_contrasts(s, term, by, method)))
  }

  args <- list(fit$model, specs = f)
  if (length(by)) args$by <- by
  if (identical(fit$engine, "lm_hc3")) args$vcov. <- car::hccm(fit$model, type = "hc3")
  em <- suppressMessages(do.call(emmeans::emmeans, args))
  con <- emmeans::contrast(em, method = "pairwise", adjust = adjust)
  sum_args <- list(con, infer = c(TRUE, TRUE))
  if (fit$engine %in% c("glm", "glmer", "glmmtmb", "glmnb")) sum_args$type <- "response"
  s <- as.data.frame(suppressMessages(do.call(summary, sum_args)))
  list(grid = em, table = .std_contrasts(s, term, by, adjust))
}


# Internal: post-hoc contrasts by whatever route the engine supports. Each
# categorical predictor gets its own family of pairwise comparisons of the
# marginal means (averaged over the other factors) -- not every cell against
# every other cell, which for a 2 x 3 design is 15 tests answering no
# particular question. Simple effects (one factor within the levels of the
# others) are added only for interactions that are in the model and
# significant in the omnibus test. ART must go through ARTool's own contrast
# machinery (ART-C) -- emmeans on the aligned-rank fit compares the wrong
# quantity. Failures are reported, never swallowed.
.fit_contrasts <- function(fit, rec, data, adjust = "holm", omnibus = NULL,
                           interaction = TRUE, verbose = TRUE) {
  say <- function(...) if (isTRUE(verbose)) message(...)
  predictors <- rec$predictors
  categorical <- rec$categorical
  if (is.null(categorical)) categorical <- .categorical_predictors(data, predictors, rec$cluster)
  cat_preds <- names(categorical)[categorical]
  if (length(cat_preds) == 0) {
    return(NULL)
  }
  if (identical(fit$fun, "stats::kruskal.test")) {
    return(.dunn_contrasts(rec, data, adjust, say))
  }
  no_posthoc <- c(
    htest = "classical (htest)", nparld = "nparLD", multinom = "multinomial",
    mblogit = "multinomial mixed"
  )
  if (fit$engine %in% names(no_posthoc)) {
    say(
      "No pairwise post-hoc contrasts are computed for ", no_posthoc[[fit$engine]],
      " fits; follow up with a dedicated test (e.g. FSA::dunnTest() after Kruskal-Wallis)."
    )
    return(NULL)
  }
  if (!requireNamespace("emmeans", quietly = TRUE)) {
    say("Install 'emmeans' to compute post-hoc contrasts.")
    return(NULL)
  }

  sig_terms <- character(0)
  if (isTRUE(interaction) && length(cat_preds) > 1L && !is.null(omnibus) && nrow(omnibus) > 0) {
    for (i in seq_len(nrow(omnibus))) {
      vars <- strsplit(omnibus$term[[i]], ":", fixed = TRUE)[[1]]
      if (length(vars) > 1L && all(vars %in% cat_preds) && isTRUE(omnibus$p[[i]] < 0.05)) {
        sig_terms <- c(sig_terms, omnibus$term[[i]])
      }
    }
  }

  grids <- list()
  tables <- list()
  run <- function(f, by) {
    key <- if (length(by)) paste0(f, " | ", paste(by, collapse = ", ")) else f
    res <- tryCatch(
      suppressWarnings(suppressMessages(.contrast_family(fit, f, by, adjust, predictors))),
      error = function(e) {
        say("Post-hoc contrasts for `", key, "` could not be computed: ", conditionMessage(e))
        NULL
      }
    )
    if (!is.null(res)) {
      grids[[key]] <<- res$grid
      tables[[key]] <<- res$table
    }
    !is.null(res)
  }
  for (f in cat_preds) run(f, NULL)
  # An interaction is described as followed up only if every one of its
  # simple-effect families was actually computed; the methods text must not
  # claim comparisons that are missing from $contrasts.
  simple <- character(0)
  for (t in sig_terms) {
    vars <- strsplit(t, ":", fixed = TRUE)[[1]]
    ok <- vapply(vars, function(f) run(f, setdiff(vars, f)), logical(1))
    if (all(ok)) simple <- c(simple, t)
  }
  if (length(tables) == 0) {
    return(NULL)
  }
  tab <- do.call(rbind, unname(tables))
  rownames(tab) <- NULL
  # ART-C simple effects are adjusted with p.adjust(), which knows no Tukey,
  # Sidak, Scheffe or multivariate-t; those fall back to Holm, and the methods
  # text has to name what was actually applied.
  simple_adjust <- unique(tab$adjust[grepl(" | ", tab$term, fixed = TRUE)])
  list(emmeans = grids, contrasts = tab, simple = simple,
       simple_adjust = if (length(simple_adjust) == 1L) simple_adjust else adjust)
}


# Internal: Dunn's test as the follow-up of the Kruskal-Wallis route, which
# recommend_test() labels "Kruskal-Wallis + Dunn's test": without it, the methods
# sentence would claim a post-hoc test that was never run. FSA::dunnTest() knows
# the p.adjust() corrections except Hommel; anything else falls back to Holm,
# and the table records what was applied.
.dunn_contrasts <- function(rec, data, adjust, say) {
  if (!requireNamespace("FSA", quietly = TRUE)) {
    say("Install 'FSA' to follow the Kruskal-Wallis test up with Dunn's test.")
    return(NULL)
  }
  pred <- rec$predictors[[1]]
  method <- tolower(adjust)
  if (identical(method, "fdr")) method <- "bh"
  if (!method %in% c("holm", "bonferroni", "sidak", "hs", "hochberg", "bh", "by", "none")) {
    say("Dunn's test does not support adjust = \"", adjust, "\"; the comparisons are Holm-adjusted.")
    method <- "holm"
  }
  d <- data[stats::complete.cases(data[c(rec$outcome, pred)]), , drop = FALSE]
  dt <- NULL
  # FSA::dunnTest() prints the omnibus test as a side effect.
  invisible(utils::capture.output(
    dt <- FSA::dunnTest(d[[rec$outcome]], droplevels(as.factor(d[[pred]])), method = method)
  ))
  res <- dt$res
  tab <- data.frame(
    term = pred, by = NA_character_, contrast = as.character(res$Comparison),
    estimate = NA_real_, scale = "mean rank", SE = NA_real_, df = NA_real_,
    lower.CL = NA_real_, upper.CL = NA_real_, statistic = res$Z, p.value = res$P.adj,
    adjust = method, stringsAsFactors = FALSE, row.names = NULL
  )
  list(emmeans = list(dunn = dt), contrasts = tab, simple = character(0),
       simple_adjust = method, engine = "dunn")
}


# Internal: the methods sentence describing the post-hoc comparisons.
.contrasts_methods_text <- function(engine, adjust, simple, simple_adjust = adjust) {
  # Dunn's test has one family; name the correction it actually applied.
  if (identical(engine, "dunn")) adjust <- simple_adjust
  how <- if (identical(engine, "dunn")) {
    "Pairwise post-hoc comparisons (Dunn's test, `FSA::dunnTest`)"
  } else if (identical(engine, "art")) {
    "Pairwise post-hoc comparisons (ART-C contrasts, `ARTool::art.con`)"
  } else if (identical(engine, "lm_hc3")) {
    "Pairwise post-hoc comparisons of the estimated marginal means (`emmeans`, with HC3 standard errors)"
  } else {
    "Pairwise post-hoc comparisons of the estimated marginal means (`emmeans`)"
  }
  adj <- if (identical(tolower(adjust), "none")) {
    " were not adjusted for multiplicity"
  } else {
    paste0(" were ", .adjust_label(adjust), "-adjusted within each factor")
  }
  s <- paste0(how, adj)
  if (length(simple) > 0) {
    s <- paste0(
      s, "; for the significant ",
      paste0("`", gsub(":", "` x `", simple, fixed = TRUE), "`", collapse = " and "),
      " interaction", if (length(simple) > 1) "s" else "",
      ", simple effects of each factor were compared within the levels of the other",
      if (!identical(tolower(simple_adjust), "none")) {
        paste0(", ", .adjust_label(simple_adjust), "-adjusted within each level")
      } else {
        ""
      }
    )
  }
  paste0(s, ".")
}


#' Fit the model that the data call for, and report it
#'
#' Runs [recommend_test()] to choose an analysis, then actually fits it: coerces
#' the outcome and predictors into the classes that model family needs, builds
#' the random-effect structure for a repeated-measures design, fits, computes
#' post-hoc contrasts with the matching machinery, and produces the APA/LaTeX
#' sentence via this package's reporter for that model family.
#'
#' The point is that the test you justify in the methods section and the model
#' you actually ran are produced by the same call, from the same data, and
#' therefore cannot drift apart -- the failure mode of a pipeline where
#' `recommend_test()` prints advice that someone then re-types by hand.
#'
#' @section What it can fit:
#' Cumulative link models with and without random effects
#' (\pkg{ordinal}), generalized and linear mixed models (\pkg{lme4},
#' \pkg{lmerTest}, \pkg{glmmTMB} for negative-binomial counts), Poisson,
#' negative-binomial (\pkg{MASS}) and logistic GLMs, Type III factorial ANOVA
#' (\pkg{afex}, or \pkg{car}), heteroscedasticity-robust (HC3) factorial ANOVA
#' (\pkg{car}), the aligned rank transform (\pkg{ARTool}), rank-based repeated
#' measures (\pkg{nparLD}), multinomial regression (\pkg{nnet}) and its mixed
#' counterpart (\pkg{mclogit}), and the classical one-way ANOVA / Welch /
#' Kruskal-Wallis / Wilcoxon tests. Model packages live in \code{Suggests}: a
#' branch you use needs its package installed, and says which one if it is
#' not.
#'
#' @section Random effects:
#' A repeated-measures model starts from the maximal random-effects structure
#' the design supports (Barr et al., 2013): by-cluster random slopes for every
#' within-cluster factor whose levels are replicated within a cluster, and the
#' interaction slope when there are several trials per cluster and cell. When
#' that fit is singular or does not converge, the structure is simplified step
#' by step down to random intercepts; what was dropped, and why, is announced
#' and written into \code{$methods}. A singular final fit is flagged in
#' \code{$singular}.
#'
#' @section Post-hoc contrasts:
#' Each categorical predictor gets its own family of pairwise comparisons of
#' its marginal means (averaged over the other factors), adjusted with
#' \code{adjust} within that family. Simple effects -- one factor compared
#' within each level of the others -- are added only for interactions that
#' are in the model and significant in the Type III omnibus test.
#'
#' @param data The data frame.
#' @param outcome The dependent variable (column name as string).
#' @param predictors Character vector of independent variable column names.
#' @param cluster Optional column identifying the subject or cluster for
#'   repeated-measures data -- the random-effect grouping factor.
#' @param design One of \code{"auto"} (default; clustered when some
#'   \code{cluster} has several rows), \code{"between"}, or \code{"within"}.
#' @param outcome_type \code{"auto"} (default; use [classify_outcome()]) or an
#'   explicit \code{"continuous"}, \code{"ordinal"}, \code{"binary"},
#'   \code{"count"}, \code{"nominal"} to override the classification. Pass it
#'   when the automatic choice is wrong -- a 1-7 Likert item and a small count
#'   are genuinely ambiguous from the data alone.
#' @param ordinal_max_levels Passed to [classify_outcome()]. Default 7.
#' @param interaction Logical. With more than one predictor, fit the full
#'   factorial model (\code{TRUE}, default) or main effects only
#'   (\code{FALSE}). The aligned rank transform always needs the full model, so
#'   \code{FALSE} is refused on that route.
#' @param contrasts Logical. Compute post-hoc contrasts between the levels of
#'   the categorical predictors. Default \code{TRUE}.
#' @param adjust Multiplicity adjustment for those contrasts, passed to
#'   \pkg{emmeans} or \pkg{ARTool}. Default \code{"holm"}.
#' @param sink_to Optional path of a \code{.tex} file; the methods sentence and
#'   the result sentence are written there (LaTeX-escaped) so a manuscript can
#'   \code{\\input{}} them.
#' @param verbose Logical. If \code{TRUE} (default), report every coercion, the
#'   model being fitted, and every simplification of the random effects.
#' @param factors Optional character vector naming the numeric predictors that
#'   are categorical (condition codes); see [recommend_test()]. \code{NULL}
#'   (default) decides from the data, and every resulting coercion is
#'   announced.
#'
#' @return An object of class \code{"colley_fit"}: a list with
#'   \code{recommendation} (the [recommend_test()] object, updated to record
#'   the function, call and random effects actually used), \code{formula},
#'   \code{model} (the fitted object), \code{engine}, \code{model_function}
#'   (the function actually called, e.g. \code{"lmerTest::lmer"}),
#'   \code{random} (the random-effects term kept), \code{singular} and
#'   \code{converged} (flags), \code{anova} (the omnibus table: term, df1, df2,
#'   statistic, stat_name, p), \code{emmeans} (a named list of the estimated
#'   marginal means grids) and \code{contrasts} (a data frame with one row per
#'   comparison: \code{term}, \code{by}, \code{contrast}, \code{estimate},
#'   \code{scale}, \code{SE}, \code{df}, confidence limits, \code{statistic},
#'   \code{p.value}, \code{adjust}; or \code{NULL}), \code{methods} (plain
#'   text), \code{methods_tex} (LaTeX-escaped), \code{text} (result sentences,
#'   LaTeX), and \code{sentences} (\code{methods_tex} and \code{text}, in
#'   manuscript order -- what \code{sink_to} writes). A \code{print} method
#'   summarises it.
#' @export
#' @seealso [recommend_test()] for the choice alone, [analyze_and_report()] for
#'   the figure-plus-sentence path through \pkg{ggstatsplot}.
#' @references Barr, D. J., Levy, R., Scheepers, C., & Tily, H. J. (2013).
#'   Random effects structure for confirmatory hypothesis testing: Keep it
#'   maximal. \emph{Journal of Memory and Language, 68}(3), 255--278.
#'
#'   Matuschek, H., Kliegl, R., Vasishth, S., Baayen, H., & Bates, D. (2017).
#'   Balancing Type I error and power in linear mixed models. \emph{Journal of
#'   Memory and Language, 94}, 305--315.
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
                            adjust = "holm", sink_to = NULL, verbose = TRUE,
                            factors = NULL) {
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
    ordinal_max_levels = ordinal_max_levels, factors = factors
  )

  if (length(predictors) == 0 && !isTRUE(rec$clustered)) {
    stop(
      "fit_recommended() compares conditions, but no predictor was given. ",
      "Pass `predictors`, or model the outcome directly.",
      call. = FALSE
    )
  }

  # Every engine fits the complete cases that recommend_test() judged. ARTool,
  # nparLD and mblogit refuse a missing value outright ("cannot be performed
  # when fixed effects have missing data"), and the others would each drop
  # their own rows silently.
  data <- as.data.frame(data)
  analysed <- c(outcome, predictors, cluster)
  complete <- stats::complete.cases(data[analysed])
  if (!all(complete)) {
    if (isTRUE(verbose)) {
      message(
        "Dropped ", sum(!complete), " row", if (sum(!complete) == 1L) "" else "s",
        " with a missing value in ", paste0("`", analysed, "`", collapse = ", "), "."
      )
    }
    data <- data[complete, , drop = FALSE]
    data[c(predictors, cluster)] <- lapply(data[c(predictors, cluster)], function(v) {
      if (is.factor(v)) droplevels(v) else v
    })
  }

  data <- .fit_coerce(
    data, outcome, predictors, cluster,
    outcome_type = rec$outcome_type, categorical = rec$categorical, verbose = verbose
  )

  fit <- .fit_dispatch(rec, data, interaction = interaction, verbose = verbose)
  if (isTRUE(verbose)) {
    message("Fitted: ", rec$recommendation, " -- ", fit$call_str)
  }

  # Say what the final model's fitting produced. Singular-fit chatter is
  # replaced by the explicit flag and note below; warnings are passed on.
  if (isTRUE(verbose) && !is.null(fit$dropped)) {
    message(
      "The random-effects structure was simplified to ", fit$random, " because the ",
      "richer fit was ", fit$dropped, "."
    )
  }
  for (w in unique(fit$warnings)) warning(w, call. = FALSE)
  if (isTRUE(verbose)) {
    for (m in unique(fit$messages)) {
      if (!grepl("singular", m, ignore.case = TRUE)) message(trimws(m))
    }
  }

  # Type III omnibus tests: from the fitted ANOVA table where the engine has
  # one, otherwise computed from the model.
  omni <- fit$anova
  if (is.null(omni) && fit$reporter %in% c("report_glmm", "report_clmm")) {
    omni <- tryCatch(.omnibus_table(fit$model), error = function(e) {
      if (isTRUE(verbose)) message("Type III omnibus tests could not be computed: ", conditionMessage(e))
      NULL
    })
  }

  con <- NULL
  emm <- NULL
  simple <- character(0)
  simple_adjust <- adjust
  posthoc_engine <- fit$engine
  if (isTRUE(contrasts)) {
    cres <- .fit_contrasts(fit, rec, data,
      adjust = adjust, omnibus = omni,
      interaction = interaction, verbose = verbose
    )
    if (!is.null(cres)) {
      emm <- cres$emmeans
      con <- cres$contrasts
      simple <- cres$simple
      simple_adjust <- cres$simple_adjust
      if (!is.null(cres$engine)) posthoc_engine <- cres$engine
    }
  }
  # The Kruskal-Wallis route is labelled "Kruskal-Wallis + Dunn's test"; the
  # methods sentence may say so only if Dunn's test was actually run.
  if (identical(fit$fun, "stats::kruskal.test") && !identical(posthoc_engine, "dunn")) {
    rec$recommendation <- "Kruskal-Wallis test"
  }

  # The reporters both message() their sentences and return them invisibly.
  # Take the return value and suppress the duplicate chatter: print.colley_fit()
  # shows them, and they are in $text either way.
  text <- NULL
  if (!is.na(fit$reporter)) {
    # Most reporters take the fitted model; ART's takes its ANOVA table.
    report_object <- if (is.null(fit$report_object)) fit$model else fit$report_object
    # Names as plain text, as in every other sentence fit_recommended() writes:
    # $sentences and sink_to are standalone LaTeX with no \providecommand stubs,
    # so a name macro such as \B{} would be an undefined control sequence.
    op <- options(colleyRstats.name_macros = FALSE)
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
      },
      finally = options(op)
    )
  } else if (fit$engine %in% c("aov", "afex", "anova3", "lm_hc3") && !is.null(omni)) {
    dv_tex <- latex_escape(outcome)
    intro <- switch(fit$engine,
      aov = paste0(
        "A one-way ANOVA",
        if (length(predictors) == 1L && nlevels(droplevels(data[[predictors]])) == 2L) {
          " (equivalent to Student's $t$-test)"
        } else {
          ""
        },
        " was fitted for ", dv_tex, "."
      ),
      lm_hc3 = paste0(
        "A factorial ANOVA with Type III tests based on heteroscedasticity-consistent ",
        "(HC3) standard errors was fitted for ", dv_tex, "."
      ),
      paste0(
        "A factorial ANOVA with Type III sums of squares (sum-to-zero contrasts) was ",
        "fitted for ", dv_tex, "."
      )
    )
    text <- c(intro, .omnibus_sentences(omni, dv_tex))
  }

  # Record what was actually fitted: the function (lmerTest::lmer, not
  # lme4::lmer), the call with its family and random effects, and the random
  # structure kept -- so $recommendation cannot describe a different model from
  # $model. recommend_test() writes the full-factorial fit_call, while
  # interaction = FALSE fits main effects only.
  rec$fitted_function <- fit$fun
  rec$fit_call <- fit$call_str
  if (!is.null(rec$random) && !is.null(fit$random)) {
    tried <- rec$random$slopes
    rec$random$term <- fit$random
    if (!is.null(fit$dropped)) {
      rec$random$dropped <- list(slopes = tried, reason = fit$dropped)
      if (identical(fit$random, utils::tail(rec$random$candidates, 1))) {
        rec$random$slopes <- character(0)
      }
    }
  }
  rec$methods_text <- .recommendation_methods_text(rec)
  rec$methods_tex <- .methods_tex(rec$methods_text)

  notes <- character(0)
  if (isTRUE(fit$singular)) {
    notes <- c(notes, paste0(
      "The final random-effects structure `", gsub("`", "", fit$random, fixed = TRUE),
      "` is singular: a variance ",
      "component was estimated at (or near) zero, so that random effect does not ",
      "contribute to the model."
    ))
  }
  if (!isTRUE(fit$converged)) {
    notes <- c(notes, "The model did not converge cleanly, so its estimates should be interpreted with caution.")
    warning("The ", rec$recommendation, " did not converge cleanly; see $methods.", call. = FALSE)
  }
  if (!is.null(con)) {
    notes <- c(notes, .contrasts_methods_text(posthoc_engine, adjust, simple, simple_adjust))
  }
  methods <- paste(c(rec$methods_text, notes), collapse = " ")
  methods_tex <- .methods_tex(methods)

  fitted_formula <- tryCatch(stats::formula(fit$model), error = function(e) NULL)

  out <- list(
    recommendation = rec,
    formula = fitted_formula,
    model = fit$model,
    engine = fit$engine,
    model_function = fit$fun,
    reporter = fit$reporter,
    random = fit$random,
    singular = isTRUE(fit$singular),
    converged = isTRUE(fit$converged),
    anova = omni,
    emmeans = emm,
    contrasts = con,
    methods = methods,
    methods_tex = methods_tex,
    text = text,
    sentences = c(methods_tex, text)
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
  cat("  Fitted with : ", x$recommendation$fit_call, "\n", sep = "")
  if (!is.null(x$random)) {
    cat("  Random      : ", x$random, if (isTRUE(x$singular)) "  (singular fit)" else "", "\n", sep = "")
  }
  if (!is.null(x$contrasts)) {
    cat("  Contrasts   : ", nrow(x$contrasts), " comparison(s) in $contrasts\n", sep = "")
  }
  if (!is.null(x$text)) {
    cat("  Reported as :\n")
    cat(paste0("    ", x$text, collapse = "\n"), "\n", sep = "")
  } else {
    cat("  Report with : summary(fit$model)\n")
  }
  cat("\n")
  if (!is.null(x$anova) && nrow(x$anova) > 0) {
    a <- x$anova
    cat("Omnibus tests:\n")
    print(data.frame(
      term = a$term, df1 = round(a$df1, 2), df2 = round(a$df2, 2),
      statistic = paste0(ifelse(a$stat_name == "F", "F = ", "Chisq = "), .fmt_num(a$statistic)),
      p = signif(a$p, 3), stringsAsFactors = FALSE
    ), row.names = FALSE)
    cat("\n")
  }
  # summary() of an htest is a structure table ("Length Class Mode"), not a
  # result; the object prints itself properly.
  if (inherits(x$model, c("htest", "afex_aov"))) {
    print(x$model)
  } else {
    print(summary(x$model))
  }
  invisible(x)
}
