# Tests for the principled model-selection helper and the mixed-model reporters.

make_mixed_df <- function(seed = 42, n_id = 20) {
  set.seed(seed)
  data.frame(
    id     = factor(rep(seq_len(n_id), each = 3)),
    cond   = factor(rep(c("A", "B", "C"), times = n_id)),
    score  = rnorm(n_id * 3),
    rating = factor(sample(1:5, n_id * 3, replace = TRUE), ordered = TRUE),
    bin    = rbinom(n_id * 3, 1, 0.5),
    cnt    = rpois(n_id * 3, 4),
    age    = round(runif(n_id * 3, 20, 60))
  )
}

# ---- classify_outcome ----------------------------------------------------

test_that("classify_outcome maps common variable shapes to the right scale", {
  expect_identical(classify_outcome(rnorm(50)), "continuous")
  expect_identical(classify_outcome(factor(sample(1:5, 50, TRUE), ordered = TRUE)), "ordinal")
  expect_identical(classify_outcome(sample(1:5, 50, TRUE)), "ordinal") # Likert integers
  expect_identical(classify_outcome(sample(0:1, 50, TRUE)), "binary")
  expect_identical(classify_outcome(c(TRUE, FALSE, NA, TRUE)), "binary")
  expect_identical(classify_outcome(factor(c("a", "b", "c", "a"))), "nominal")
  # Counts without zeros in a closed range are still counts, but loudly.
  expect_identical(suppressWarnings(classify_outcome(rpois(50, 5) + 3L)), "count")
})

test_that("classify_outcome respects ordinal_max_levels", {
  x <- sample(1:10, 100, replace = TRUE) # 10 distinct non-negative integers
  expect_warning(
    expect_identical(classify_outcome(x, ordinal_max_levels = 7L), "count"),
    "closed range"
  )
  expect_identical(classify_outcome(x, ordinal_max_levels = 12L), "ordinal")
})

test_that("classify_outcome errors on an unclassifiable input", {
  expect_error(classify_outcome(as.complex(1:5)), "Cannot classify")
  expect_error(classify_outcome(NULL), "must not be empty")
})

test_that("bounded rating scores are not silently classified as counts", {
  # Raw NASA-TLX: 0-100 in steps of 5. Classified as a count it went into a
  # Poisson GLMM without a word.
  set.seed(1)
  tlx <- sample(seq(0, 100, by = 5), 60, replace = TRUE)
  expect_message(
    expect_identical(classify_outcome(tlx), "continuous"),
    "NASA-TLX"
  )

  # Whole-number 0-100 scores, summed Likert scales and 1-10 ratings stay
  # "count" by the rules, but with a warning that names the override.
  tlx_whole <- pmin(100, pmax(1, round(50 + rnorm(60, sd = 15))))
  expect_warning(classify_outcome(tlx_whole), "outcome_type = \"continuous\"")
  summed <- rowSums(matrix(sample(1:7, 4 * 60, TRUE), ncol = 4)) # 4 items, 4-28
  expect_warning(classify_outcome(summed), "closed range without zeros")

  # A genuine count (zeros present) is still announced, as a message.
  expect_message(
    expect_identical(classify_outcome(c(0:12, rpois(40, 3))), "count"),
    "classified as a count"
  )
})

test_that("two-valued numerics are binary only when coded 0/1", {
  # A 1-7 item on which only 6 and 7 were ticked is a restricted range, not a
  # binary outcome; it used to become a logistic regression.
  set.seed(2)
  expect_warning(
    expect_identical(classify_outcome(sample(6:7, 40, TRUE)), "ordinal"),
    "not coded 0/1"
  )
  expect_warning(classify_outcome(sample(1:2, 40, TRUE)), "not coded 0/1")
  expect_silent(expect_identical(classify_outcome(sample(0:1, 40, TRUE)), "binary"))
})

# ---- recommend_test decision tree ---------------------------------------

test_that("recommend_test routes an ordinal clustered outcome to a CLMM", {
  d <- make_mixed_df()
  r <- recommend_test(d, outcome = "rating", predictors = "cond", cluster = "id")
  expect_s3_class(r, "colley_recommendation")
  expect_identical(r$outcome_type, "ordinal")
  expect_true(r$clustered)
  expect_identical(r$model_function, "ordinal::clmm")
  expect_identical(r$reporter, "reportCLMM")
  expect_match(r$methods_text, "cumulative link", ignore.case = TRUE)
})

test_that("recommend_test routes an ordinal independent outcome to a CLM", {
  d <- make_mixed_df()
  r <- recommend_test(d, outcome = "rating", predictors = "cond")
  expect_false(r$clustered)
  expect_identical(r$model_function, "ordinal::clm")
})

test_that("recommend_test routes binary and count clustered outcomes to a GLMM", {
  skip_if_not_installed("lme4")
  d <- make_mixed_df()
  rb <- recommend_test(d, outcome = "bin", predictors = "cond", cluster = "id")
  expect_identical(rb$outcome_type, "binary")
  expect_identical(rb$model_function, "lme4::glmer")
  expect_identical(rb$reporter, "reportGLMM")
  expect_match(rb$family, "binomial")

  rc <- suppressMessages(recommend_test(d, outcome = "cnt", predictors = "cond", cluster = "id"))
  expect_identical(rc$outcome_type, "count")
  expect_identical(rc$model_function, "lme4::glmer")
  expect_match(rc$family, "poisson")
  expect_false(rc$dispersion$overdispersed)
})

test_that("recommend_test routes a continuous clustered outcome to an LMM", {
  d <- make_mixed_df()
  r <- recommend_test(d, outcome = "score", predictors = "cond", cluster = "id")
  expect_identical(r$outcome_type, "continuous")
  expect_true(r$clustered)
  expect_identical(r$model_function, "lme4::lmer")
})

test_that("recommend_test picks a parametric test when normality holds and rank-based when it does not", {
  set.seed(7)
  d_norm <- data.frame(
    cond = factor(rep(c("A", "B", "C"), each = 30)),
    y = rnorm(90)
  )
  r_norm <- recommend_test(d_norm, outcome = "y", predictors = "cond")
  expect_true(isTRUE(r_norm$assumptions$normal))
  expect_match(r_norm$recommendation, "ANOVA")

  set.seed(7)
  d_skew <- data.frame(
    cond = factor(rep(c("A", "B", "C"), each = 30)),
    y = rexp(90, rate = 0.5) # strongly right-skewed
  )
  r_skew <- recommend_test(d_skew, outcome = "y", predictors = "cond")
  expect_false(isTRUE(r_skew$assumptions$normal))
  expect_match(r_skew$model_function, "kruskal|wilcox|art", ignore.case = TRUE)
})

test_that("recommend_test honours an explicit outcome_type override", {
  d <- make_mixed_df()
  # 'cnt' would auto-classify as count; force it to be treated as continuous
  r <- recommend_test(d, outcome = "cnt", predictors = "cond", outcome_type = "continuous")
  expect_identical(r$outcome_type, "continuous")
})

test_that("recommend_test validates its inputs", {
  d <- make_mixed_df()
  expect_error(recommend_test(d, outcome = "nope"), "'nope' not found")
  expect_error(recommend_test(d, outcome = "score", predictors = "nope"), "'nope' not found")
  expect_error(recommend_test(d, outcome = "score", cluster = "nope"), "'nope' not found")
  expect_error(
    recommend_test(d, outcome = "score", predictors = "cond", factors = "age"),
    "not among `predictors`"
  )
})

test_that("print.colley_recommendation returns its input invisibly", {
  d <- make_mixed_df()
  r <- recommend_test(d, outcome = "rating", predictors = "cond", cluster = "id")
  expect_output(print(r), "analysis recommendation")
  expect_invisible(print(r))
})

test_that("over-dispersed counts are recommended a negative-binomial model", {
  skip_if_not_installed("MASS")
  # NB data fitted as Poisson gave p = .037 where glm.nb gives p = .43
  # (Pearson dispersion 6.2), with nothing to say the model was wrong.
  set.seed(6)
  oc <- data.frame(g = factor(rep(c("x", "y"), each = 40)))
  oc$errors <- MASS::rnegbin(80, mu = ifelse(oc$g == "x", 4, 5.5), theta = 0.8)

  r <- suppressMessages(recommend_test(oc, "errors", "g"))
  expect_true(r$dispersion$overdispersed)
  expect_gt(r$dispersion$ratio, 3)
  expect_identical(r$model_function, "MASS::glm.nb")
  expect_match(r$methods_text, "over-dispersed")

  skip_if_not_installed("lme4")
  set.seed(6)
  oc_cl <- data.frame(id = factor(rep(1:20, each = 4)), g = factor(rep(c("x", "y"), 40)))
  oc_cl$errors <- MASS::rnegbin(80, mu = ifelse(oc_cl$g == "x", 4, 5.5), theta = 0.8)
  r_cl <- suppressMessages(recommend_test(oc_cl, "errors", "g", cluster = "id"))
  expect_identical(r_cl$model_function, "glmmTMB::glmmTMB")
  expect_match(r_cl$fit_call, "nbinom2")
})

test_that("a clustered nominal outcome is recommended a multinomial mixed model", {
  set.seed(8)
  nm <- data.frame(id = factor(rep(1:20, each = 6)), cond = factor(rep(c("A", "B"), 60)))
  nm$choice <- factor(sample(c("p", "q", "r"), 120, TRUE))
  r <- recommend_test(nm, "choice", "cond", cluster = "id")
  expect_identical(r$model_function, "mclogit::mblogit")
  expect_match(r$fit_call, "random = ~ 1 | id", fixed = TRUE)
  expect_identical(recommend_test(nm, "choice", "cond")$model_function, "nnet::multinom")
})

test_that("normality is judged on the model residuals, not on one marginal", {
  skip_if_not_installed("lme4")
  # A strong effect of b makes the raw outcome bimodal within each level of a,
  # so the old Shapiro-Wilk on y split by the first predictor rejected
  # normality and sent a perfectly normal 2 x 2 within design to ART.
  set.seed(1)
  d <- expand.grid(a = factor(c("a1", "a2")), b = factor(c("b1", "b2")), id = factor(1:20))
  d$y <- 6 * (d$b == "b2") + rnorm(20, sd = 0.5)[as.integer(d$id)] + rnorm(nrow(d), sd = 0.7)
  expect_true(any(tapply(d$y, d$a, function(v) stats::shapiro.test(v)$p.value) < 0.05))

  r <- recommend_test(d, "y", c("a", "b"), cluster = "id")
  expect_identical(r$model_function, "lme4::lmer")
  expect_true(r$assumptions$normal)
  expect_identical(r$assumptions$normality$model, "linear mixed model")
  expect_match(r$methods_text, "residuals of the linear mixed model")
})

test_that("homogeneity of variance is tested across all design cells", {
  skip_if_not_installed("car")
  # The variance differs between the levels of the SECOND predictor only; the
  # old check tested the first predictor alone and found nothing.
  set.seed(9)
  d <- expand.grid(a = factor(c("a1", "a2")), b = factor(c("p", "q")), rep = 1:25)
  d$v <- rnorm(nrow(d), sd = ifelse(d$b == "q", 3, 1))
  r <- suppressWarnings(recommend_test(d, "v", c("a", "b")))
  expect_identical(r$assumptions$homogeneity$cells, 4L)
  expect_false(r$assumptions$homogeneous)
})

test_that("the routing never claims homogeneity it did not test, and offers a factorial robust ANOVA", {
  base <- list(
    outcome = "v", outcome_type = "continuous", predictors = c("g", "h"),
    cluster = NULL, clustered = FALSE, categorical = c(g = TRUE, h = TRUE),
    within = c(g = FALSE, h = FALSE), trial_replicates = FALSE, random = NULL,
    normal = TRUE, dispersion = NULL, n_groups = NA_integer_
  )
  untested <- colleyRstats:::.build_recommendation(c(base, list(homogeneous = NA)))
  expect_false(grepl("variances are homogeneous", untested$rationale))
  expect_match(untested$rationale, "could not be tested")
  expect_identical(untested$model_function, "afex::aov_car")

  # Heterogeneous factorial: not a Welch one-way test on collapsed cells.
  hetero <- colleyRstats:::.build_recommendation(c(base, list(homogeneous = FALSE)))
  expect_identical(hetero$model_function, "car::Anova")
  expect_match(hetero$fit_call, "white.adjust = \"hc3\"", fixed = TRUE)
  expect_match(hetero$fit_call, "g * h", fixed = TRUE)
})

test_that("recommend_test only recommends models that can be fitted to the design", {
  # Continuous covariate + factor, non-normal: ART cannot take covariates.
  set.seed(11)
  cv <- data.frame(id = factor(rep(1:20, each = 3)), cond = factor(rep(c("A", "B", "C"), 20)))
  cv$age <- rep(round(runif(20, 18, 65), 1), each = 3)
  cv$y <- rexp(60)
  r_cv <- recommend_test(cv, "y", c("cond", "age"), cluster = "id")
  expect_identical(r_cv$model_function, "lme4::lmer")
  expect_false(r_cv$categorical[["age"]])

  # A between-subjects factor with repeated rows per participant: nparLD has
  # no subplot factor to work with; the cluster must still be modelled.
  set.seed(3)
  nb <- data.frame(id = factor(rep(1:20, each = 3)))
  nb$grp <- factor(ifelse(as.integer(nb$id) <= 10, "ctrl", "trt"))
  nb$y <- rexp(60) * ifelse(nb$grp == "trt", 2.5, 1)
  r_nb <- recommend_test(nb, "y", "grp", cluster = "id")
  expect_identical(r_nb$model_function, "ARTool::art")
  expect_true(r_nb$clustered)
  expect_false(r_nb$within[["grp"]])
  # design = "between" with a cluster used to land on nparLD as well.
  r_bt <- recommend_test(nb, "y", "grp", cluster = "id", design = "between")
  expect_false(identical(r_bt$model_function, "nparLD::nparLD"))

  # One within-subject factor, one row per participant and level: nparLD.
  set.seed(3)
  np <- data.frame(id = factor(rep(1:20, each = 3)), cond = factor(rep(c("A", "B", "C"), 20)))
  np$y <- rexp(60) * c(1, 1.5, 3)[as.integer(np$cond)]
  expect_identical(recommend_test(np, "y", "cond", cluster = "id")$model_function, "nparLD::nparLD")
})

test_that("a cluster column with one row per cluster does not make the design clustered", {
  set.seed(2)
  oc <- data.frame(pid = factor(1:40), g = factor(rep(c("a", "b"), 20)))
  oc$y <- rnorm(40)
  r <- recommend_test(oc, "y", "g", cluster = "pid")
  expect_false(r$clustered)
  expect_false(grepl("lmer", r$model_function))
})

test_that("observation counts in the methods text exclude incomplete rows", {
  d <- make_mixed_df()
  d$score[1:6] <- NA
  r <- recommend_test(d, "score", "cond", cluster = "id")
  expect_identical(r$n_obs, 54L)
  expect_match(r$methods_text, "54 observations")
})

test_that("non-syntactic column names produce a parseable fit_call", {
  set.seed(4)
  sc <- data.frame(
    id = factor(rep(1:20, each = 3)), `Condition ID` = factor(rep(c("A", "B", "C"), 20)),
    `tlx-mental` = rnorm(60), check.names = FALSE
  )
  r <- recommend_test(sc, "tlx-mental", "Condition ID", cluster = "id")
  expect_match(r$fit_call, "`tlx-mental` ~ `Condition ID`", fixed = TRUE)
  expect_no_error(str2lang(sub("  #.*$", "", r$fit_call)))
})

test_that("repeated trials per participant and condition earn random slopes", {
  set.seed(17)
  sl <- expand.grid(trial = 1:6, cond = factor(c("A", "B")), id = factor(1:20))
  r <- recommend_test(within(sl, y <- rnorm(nrow(sl))), "y", "cond", cluster = "id")
  expect_identical(r$random$term, "(1 + cond | id)")
  expect_match(r$fit_call, "(1 + cond | id)", fixed = TRUE)
  expect_match(r$methods_text, "random slopes")
  # One row per participant and level: a slope is not identifiable.
  d <- make_mixed_df()
  expect_identical(recommend_test(d, "score", "cond", cluster = "id")$random$term, "(1 | id)")
})

test_that("the LaTeX methods text escapes names and typesets them as code", {
  d <- make_mixed_df()
  d$tlx_mental <- d$score
  d$participant_id <- d$id
  r <- recommend_test(d, "tlx_mental", "cond", cluster = "participant_id")
  expect_match(r$methods_text, "`tlx_mental`", fixed = TRUE) # console stays readable
  expect_match(r$methods_tex, "\\texttt{tlx\\_mental}", fixed = TRUE)
  expect_false(grepl("`", r$methods_tex, fixed = TRUE))
  expect_false(grepl("(?<!\\\\)_", r$methods_tex, perl = TRUE))
})

# ---- reportGLMM ----------------------------------------------------------

test_that("reportGLMM reports a linear mixed model with b and t(df)", {
  skip_if_not_installed("lme4")
  skip_if_not_installed("parameters")
  d <- make_mixed_df()
  m <- lme4::lmer(score ~ cond + (1 | id), data = d)
  expect_message(out <- reportGLMM(m, dv = "workload"), "linear mixed model")
  txt <- paste(out, collapse = " ")
  expect_match(txt, "\\$b = ") # raw coefficient, not exponentiated
  expect_match(txt, "\\$t\\(") # t statistic with df
  expect_false(grepl("\\(Intercept\\)", txt)) # intercept omitted by default
})

test_that("reportGLMM reports Satterthwaite df and p for linear mixed models", {
  skip_if_not_installed("lme4")
  skip_if_not_installed("lmerTest")
  skip_if_not_installed("parameters")
  # A between-subjects effect with 12 subjects x 10 trials: the residual df
  # (116) made p = .030 where Satterthwaite (df = 10) gives p = .053.
  set.seed(2)
  d <- data.frame(id = factor(rep(1:12, each = 10)))
  d$grp <- factor(ifelse(as.integer(d$id) <= 6, "a", "b"))
  d$y <- rnorm(120) + rnorm(12, sd = 2)[as.integer(d$id)] + (d$grp == "b") * 1.2
  ref <- summary(lmerTest::lmer(y ~ grp + (1 | id), data = d))$coefficients["grpb", ]
  df_txt <- if (abs(ref[["df"]] - round(ref[["df"]])) < 1e-6) {
    format(round(ref[["df"]]))
  } else {
    sprintf("%.1f", ref[["df"]])
  }
  expected <- paste0(
    "$t(", df_txt, ") = ", sprintf("%.2f", ref[["t value"]]), "$, ",
    colleyRstats:::.fmt_p_macro(ref[["Pr(>|t|)"]])
  )
  for (m in list(lme4::lmer(y ~ grp + (1 | id), data = d), lmerTest::lmer(y ~ grp + (1 | id), data = d))) {
    txt <- paste(suppressMessages(reportGLMM(m, dv = "y")), collapse = " ")
    expect_true(grepl(expected, txt, fixed = TRUE), info = txt)
    expect_false(grepl("t(118)", txt, fixed = TRUE))
    expect_match(txt, "Satterthwaite")
  }
})

test_that("reportGLMM tests model terms with Type III omnibus tests and labels contrasts honestly", {
  skip_if_not_installed("lmerTest")
  skip_if_not_installed("parameters")
  # Crossover 2 x 2: aa2 is the a2 - a1 difference at b = b1 (large), while
  # the main effect of a is null. It used to be reported as "the effect of
  # aa2 ... significant, p < .001".
  set.seed(10)
  w <- expand.grid(a = factor(c("a1", "a2")), b = factor(c("b1", "b2")), id = factor(1:24))
  w$y <- rnorm(nrow(w), sd = 0.7) + rnorm(24)[as.integer(w$id)] +
    ifelse(w$a == "a2" & w$b == "b1", 1, 0) + ifelse(w$a == "a2" & w$b == "b2", -1, 0)
  m <- lmerTest::lmer(y ~ a * b + (1 | id), data = w)
  txt <- paste(suppressMessages(reportGLMM(m, dv = "y")), collapse = " ")
  a3 <- stats::anova(m, type = 3)
  expected_a <- paste0(
    "The main effect of \\textit{a} on y was not significant (\\F{",
    colleyRstats:::.fmt_df(a3["a", "NumDF"]), "}{", colleyRstats:::.fmt_df(a3["a", "DenDF"]),
    "}{", sprintf("%.2f", a3["a", "F value"]), "}, ", colleyRstats:::.fmt_p_macro(a3["a", "Pr(>F)"]), ")"
  )
  expect_true(grepl(expected_a, txt, fixed = TRUE), info = txt)
  expect_match(txt, "interaction effect of \\textit{a} $\\times$ \\textit{b}", fixed = TRUE)
  expect_match(txt, "\\textit{a2} vs.\\ \\textit{a1} of \\textit{a} (at \\textit{b} = \\textit{b1})", fixed = TRUE)
  expect_false(grepl("The effect of", txt, fixed = TRUE))

  # A three-level factor gets its 2-df omnibus test.
  d <- make_mixed_df()
  txt3 <- paste(suppressMessages(reportGLMM(lmerTest::lmer(score ~ cond + (1 | id), data = d), dv = "s")), collapse = " ")
  expect_match(txt3, "main effect of \\textit{cond} on s was not significant (\\F{2}{", fixed = TRUE)
})

test_that("reportGLMM exponentiates a binomial GLMM to odds ratios", {
  skip_if_not_installed("lme4")
  skip_if_not_installed("parameters")
  d <- make_mixed_df()
  m <- lme4::glmer(bin ~ cond + (1 | id), data = d, family = binomial)
  out <- suppressMessages(reportGLMM(m, dv = "accuracy"))
  txt <- paste(out, collapse = " ")
  expect_match(txt, "generalized linear mixed model")
  expect_match(txt, "\\$OR = ")
  expect_match(txt, "\\$z = ")
  expect_match(txt, "\\chi^2(2)", fixed = TRUE) # Wald omnibus test of cond
})

test_that("reportGLMM also handles plain glm and lm (recommend_test routes them here)", {
  skip_if_not_installed("parameters")
  d <- make_mixed_df()
  # logistic GLM -> odds ratios, z
  m_glm <- stats::glm(bin ~ cond, data = d, family = binomial)
  txt_glm <- paste(suppressMessages(reportGLMM(m_glm, dv = "accuracy")), collapse = " ")
  expect_match(txt_glm, "generalized linear model")
  expect_match(txt_glm, "\\$OR = ")
  # linear model -> raw b, t(df)
  m_lm <- stats::lm(score ~ cond, data = d)
  txt_lm <- paste(suppressMessages(reportGLMM(m_lm, dv = "score")), collapse = " ")
  expect_match(txt_lm, "linear model")
  expect_match(txt_lm, "\\$b = ")
  expect_match(txt_lm, "\\$t\\(")
})

test_that("odds-ratio and IRR labels follow the link function", {
  skip_if_not_installed("parameters")
  skip_if_not_installed("ordinal")
  # exp() of a probit coefficient is not an odds ratio; it was printed as
  # "OR = 1.45" (glm) and "OR = 3.94" (clm).
  set.seed(3)
  g <- data.frame(x = rnorm(200))
  g$yb <- rbinom(200, 1, stats::pnorm(0.5 * g$x))
  txt_p <- paste(suppressMessages(reportGLMM(
    stats::glm(yb ~ x, data = g, family = binomial(link = "probit")),
    dv = "hit"
  )), collapse = " ")
  expect_false(grepl("OR =", txt_p, fixed = TRUE))
  expect_match(txt_p, "probit")
  expect_match(txt_p, "$b = ", fixed = TRUE)

  txt_c <- paste(suppressMessages(reportCLMM(
    ordinal::clm(rating ~ temp, data = ordinal::wine, link = "probit"),
    dv = "rating"
  )), collapse = " ")
  expect_false(grepl("OR =", txt_c, fixed = TRUE))
  expect_match(txt_c, "probit")

  # Forcing exponentiation on a probit fit must not invent an odds ratio.
  txt_f <- paste(suppressMessages(reportGLMM(
    stats::glm(yb ~ x, data = g, family = binomial(link = "probit")),
    dv = "hit", exponentiate = TRUE
  )), collapse = " ")
  expect_false(grepl("OR =", txt_f, fixed = TRUE))

  # Logit and log links keep their ratios.
  g$cnt <- stats::rpois(200, exp(0.3 * g$x))
  expect_match(paste(suppressMessages(reportGLMM(
    stats::glm(cnt ~ x, data = g, family = poisson), dv = "n"
  )), collapse = " "), "$IRR = ", fixed = TRUE)
})

test_that("only location / conditional-mean coefficients are reported", {
  skip_if_not_installed("parameters")
  skip_if_not_installed("ordinal")
  # Equidistant thresholds were reported as "the effect of threshold.1 ...
  # OR = 0.20" and "spacing ... OR = 6.89".
  me <- ordinal::clm(rating ~ temp, data = ordinal::wine, threshold = "equidistant")
  out_e <- suppressMessages(reportCLMM(me, dv = "rating"))
  expect_false(any(grepl("threshold|spacing", out_e)))
  expect_identical(sum(grepl("vs.", out_e, fixed = TRUE)), 1L)

  # A scale effect is not a location odds ratio.
  ms <- ordinal::clm(rating ~ temp, scale = ~contact, data = ordinal::wine)
  expect_false(any(grepl("contact", suppressMessages(reportCLMM(ms, dv = "rating")))))

  # Zero-inflated glmmTMB: condB/condC were reported twice, the second copy
  # being the zero-inflation logit exponentiated and labelled IRR.
  skip_if_not_installed("glmmTMB")
  set.seed(4)
  z <- data.frame(id = factor(rep(1:20, each = 6)), cond = factor(rep(c("A", "B", "C"), 40)))
  z$cnt <- ifelse(stats::runif(120) < 0.3, 0, stats::rpois(120, 3))
  mz <- suppressWarnings(glmmTMB::glmmTMB(cnt ~ cond + (1 | id), ziformula = ~cond, family = poisson, data = z))
  out_z <- suppressMessages(reportGLMM(mz, dv = "count"))
  expect_identical(sum(grepl("vs.", out_z, fixed = TRUE)), 2L)
  expect_true(all(grepl("IRR", out_z[grepl("vs.", out_z, fixed = TRUE)])))
})

test_that("reportGLMM can write to a .tex sink", {
  skip_if_not_installed("lme4")
  skip_if_not_installed("parameters")
  d <- make_mixed_df()
  m <- lme4::lmer(score ~ cond + (1 | id), data = d)
  f <- tempfile(fileext = ".tex")
  suppressMessages(reportGLMM(m, dv = "workload", sink_to = f))
  expect_true(file.exists(f))
  expect_true(any(grepl("mixed model", readLines(f))))
})

# ---- reportCLMM ----------------------------------------------------------

test_that("reportCLMM reports odds ratios and omits the thresholds", {
  skip_if_not_installed("ordinal")
  skip_if_not_installed("parameters")
  d <- make_mixed_df()
  m <- ordinal::clmm(rating ~ cond + (1 | id), data = d)
  out <- suppressMessages(reportCLMM(m, dv = "rating"))
  txt <- paste(out, collapse = " ")
  expect_match(txt, "cumulative link mixed model")
  expect_match(txt, "\\$OR = ")
  # threshold parameters like "1|2" must never appear
  expect_false(grepl("\\|", txt))
})

test_that(".fmt_p_macro tolerates NA without erroring", {
  # Regression: an un-estimable fixed effect yields p = NA; formatting it used
  # to abort with "missing value where TRUE/FALSE needed".
  expect_identical(colleyRstats:::.fmt_p_macro(NA_real_), "\\p{NA}")
  expect_identical(
    colleyRstats:::.fmt_p_macro(NA_real_, macro = "padj", minor_macro = "padjminor"),
    "\\padj{NA}"
  )
})

test_that("reportGLMM does not crash on a rank-deficient model", {
  skip_if_not_installed("parameters")
  set.seed(1)
  d <- data.frame(y = rnorm(30), g = factor(rep(c("a", "b", "c"), 10)))
  d$g_copy <- d$g # perfectly collinear -> aliased / un-estimable terms
  m <- stats::lm(y ~ g + g_copy, data = d)
  expect_error(suppressWarnings(suppressMessages(reportGLMM(m, dv = "y"))), NA)
})

test_that("reportCLMM rejects a non-ordinal model", {
  skip_if_not_installed("lme4")
  skip_if_not_installed("ordinal")
  d <- make_mixed_df()
  m <- lme4::lmer(score ~ cond + (1 | id), data = d)
  expect_error(reportCLMM(m), "clmm")
})


test_that("a single two-level within factor is checked on the paired differences", {
  # The LMM residuals of one two-level within factor come in near mirror-image
  # pairs, which hides skew; the differences are what a paired analysis assumes.
  skip_if_not_installed("lme4")
  set.seed(2)
  n <- 30
  d <- data.frame(id = factor(rep(1:n, 2)), cond = factor(rep(c("A", "B"), each = n)))
  base <- rnorm(n)
  d$y <- c(base, base + rexp(n))
  r <- suppressMessages(recommend_test(d, "y", "cond", cluster = "id"))
  expect_identical(r$assumptions$normality$model, "paired differences")
  expect_false(isTRUE(r$assumptions$normal))
  expect_match(r$methods_text, "per-participant differences between the levels of `cond`", fixed = TRUE)
})

test_that("a factor's omnibus test in a model with a covariate is taken at the covariate's mean", {
  # lmerTest's Type III test of `cond` in y ~ cond * age is the cond effect at
  # age = 0; the reported main effect is the one at the mean age, i.e. the
  # Type III test of the model with age centred.
  skip_if_not_installed("lmerTest")
  skip_if_not_installed("emmeans")
  set.seed(3)
  n <- 30
  d <- data.frame(id = factor(rep(1:n, each = 4)), cond = factor(rep(c("A", "B"), 2 * n)))
  d$age <- rep(runif(n, 20, 60), each = 4)
  d$y <- 0.74 * (d$cond == "B") + 0.01 * d$age + rnorm(n)[d$id] + rnorm(4 * n)
  tab <- .omnibus_table(lmerTest::lmer(y ~ cond * age + (1 | id), data = d))
  d$age_c <- d$age - mean(d$age)
  ref <- as.data.frame(stats::anova(lmerTest::lmer(y ~ cond * age_c + (1 | id), data = d), type = 3))
  expect_equal(tab$statistic[tab$term == "cond"], ref["cond", "F value"], tolerance = 1e-6)
  expect_equal(tab$p[tab$term == "cond"], ref["cond", "Pr(>F)"], tolerance = 1e-6)
  expect_equal(tab$statistic[tab$term == "cond:age"], ref["cond:age_c", "F value"], tolerance = 1e-6)
  # the uncentred Type III test is a different, much weaker hypothesis here
  old <- as.data.frame(stats::anova(lmerTest::lmer(y ~ cond * age + (1 | id), data = d), type = 3))
  expect_gt(abs(tab$statistic[tab$term == "cond"] - old["cond", "F value"]), 10)
})

test_that("an intercept-only model has an empty omnibus table, not an error", {
  skip_if_not_installed("lmerTest")
  set.seed(1)
  d <- data.frame(id = factor(rep(1:10, each = 3)), y = rnorm(30))
  tab <- .omnibus_table(lmerTest::lmer(y ~ 1 + (1 | id), data = d))
  expect_identical(nrow(tab), 0L)
  expect_named(tab, c("term", "df1", "df2", "statistic", "stat_name", "p", "method"))
})

test_that("joint-test chi-squares are recovered exactly, not from rounded F ratios", {
  skip_if_not_installed("emmeans")
  set.seed(3)
  d <- data.frame(cond = factor(rep(c("A", "B", "C"), 40)), x = rnorm(120))
  d$y <- rbinom(120, 1, plogis(0.6 * (d$cond == "C")))
  tab <- .omnibus_table(glm(y ~ cond, data = d, family = binomial))
  expect_equal(tab$statistic, stats::qchisq(tab$p, tab$df1, lower.tail = FALSE))
})