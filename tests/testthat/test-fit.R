# A within-subjects study of three conditions whose continuous outcome passes
# the residual normality check, so the recommendation lands on a linear mixed
# model rather than its rank-based fallback. The seed is part of the fixture:
# with another one these tests would assert the wrong branch.
make_study <- function(seed = 1) {
  set.seed(seed)
  d <- data.frame(
    id = factor(rep(1:24, each = 3)),
    cond = factor(rep(c("A", "B", "C"), times = 24))
  )
  person <- stats::rnorm(24)
  d$score <- stats::rnorm(72, sd = 0.8) + person[as.integer(d$id)] +
    rep(c(0, 0.5, 1.1), times = 24)
  d$rating <- factor(
    pmin(pmax(round(3 + (as.integer(d$cond) - 2) * 0.9 + stats::rnorm(72, sd = 0.6)), 1), 5),
    ordered = TRUE
  )
  d$hit <- stats::rbinom(72, 1, 0.4)
  d
}


test_that("a clustered continuous outcome is fitted as a linear mixed model", {
  skip_if_not_installed("lme4")
  skip_if_not_installed("parameters")
  d <- make_study()

  fit <- fit_recommended(d, "score", "cond", cluster = "id", verbose = FALSE)

  expect_s3_class(fit, "colley_fit")
  expect_equal(fit$engine, "lmer")
  expect_s4_class(fit$model, "merMod")
  expect_true(any(grepl("linear mixed model", fit$text, ignore.case = TRUE)))
  # The methods sentence and the fitted model come from the same call, which is
  # the whole point: they cannot describe different analyses.
  expect_match(fit$methods, "clustered")
})


test_that("an ordinal outcome is fitted as a cumulative link mixed model", {
  skip_if_not_installed("ordinal")
  skip_if_not_installed("parameters")
  d <- make_study()

  fit <- fit_recommended(d, "rating", "cond", cluster = "id", verbose = FALSE)

  expect_equal(fit$engine, "clmm")
  expect_s3_class(fit$model, "clmm")
  # A cumulative link model reports odds ratios, not raw coefficients.
  expect_true(any(grepl("OR", fit$text, fixed = TRUE)))
})


test_that("a numeric Likert outcome is coerced to an ordered factor, and says so", {
  skip_if_not_installed("ordinal")
  d <- make_study()
  d$rating <- as.integer(as.character(d$rating))

  expect_message(
    fit <- fit_recommended(d, "rating", "cond", cluster = "id"),
    "Coerced `rating` to an ordered factor"
  )
  expect_equal(fit$engine, "clmm")
})


test_that("a binary outcome is fitted as a binomial GLMM", {
  skip_if_not_installed("lme4")
  skip_if_not_installed("parameters")
  d <- make_study()

  fit <- fit_recommended(d, "hit", "cond", cluster = "id", verbose = FALSE)

  expect_equal(fit$engine, "glmer")
  expect_equal(stats::family(fit$model)$family, "binomial")
})


test_that("outcome_type overrides the automatic classification", {
  skip_if_not_installed("lme4")
  d <- make_study()
  # Whole numbers on 0-100: classified as a count unless told otherwise, which
  # is how a questionnaire subscale ends up in a Poisson model -- now with a
  # warning that names the override.
  d$subscale <- round(50 + 10 * d$score)

  expect_warning(
    auto <- suppressMessages(fit_recommended(d, "subscale", "cond", cluster = "id", verbose = FALSE)),
    "outcome_type = \"continuous\""
  )
  told <- fit_recommended(d, "subscale", "cond",
    cluster = "id",
    outcome_type = "continuous", verbose = FALSE
  )

  expect_equal(auto$recommendation$outcome_type, "count")
  expect_equal(told$recommendation$outcome_type, "continuous")
  expect_equal(told$engine, "lmer")
})


test_that("post-hoc contrasts come back adjusted", {
  skip_if_not_installed("lme4")
  skip_if_not_installed("emmeans")
  d <- make_study()

  fit <- fit_recommended(d, "score", "cond", cluster = "id", adjust = "holm", verbose = FALSE)
  con <- as.data.frame(fit$contrasts)

  expect_equal(nrow(con), 3L) # A-B, A-C, B-C
  expect_true(all(con$p.value >= 0 & con$p.value <= 1))
  expect_true(all(con$adjust == "holm"))
  expect_false(is.null(fit$emmeans))
  expect_match(fit$methods, "Holm-adjusted")
})


test_that("contrasts can be switched off", {
  skip_if_not_installed("lme4")
  d <- make_study()

  fit <- fit_recommended(d, "score", "cond", cluster = "id", contrasts = FALSE, verbose = FALSE)

  expect_null(fit$contrasts)
})


test_that("a between-subjects continuous outcome takes the classical route", {
  set.seed(5)
  d <- data.frame(
    g = factor(rep(c("x", "y", "z"), each = 20)),
    y = c(stats::rnorm(20), stats::rnorm(20, 1), stats::rnorm(20, 2))
  )

  fit <- fit_recommended(d, "y", "g", verbose = FALSE)

  expect_equal(fit$engine, "aov")
  expect_s3_class(fit$model, "aov")
  expect_match(paste(fit$text, collapse = " "), "one-way ANOVA")
})


test_that("sink_to writes the sentences for the manuscript to \\input{}", {
  skip_if_not_installed("lme4")
  skip_if_not_installed("parameters")
  d <- make_study()
  path <- withr::local_tempfile(fileext = ".tex")

  suppressMessages(
    fit <- fit_recommended(d, "score", "cond", cluster = "id", sink_to = path, verbose = FALSE)
  )

  expect_true(file.exists(path))
  expect_equal(readLines(path), fit$sentences)
})


test_that("fit_recommended validates before it fits", {
  d <- make_study()

  expect_error(fit_recommended(d, "nope", "cond"), "not found in `data`")
  expect_error(fit_recommended(d, "score", "nope"), "not found in `data`")
})


test_that("the formula builder places the random effect and the interaction", {
  expect_equal(
    deparse(colleyRstats:::.fit_formula("y", c("a", "b"), "id")),
    "y ~ a * b + (1 | id)"
  )
  expect_equal(
    deparse(colleyRstats:::.fit_formula("y", c("a", "b"), "id", interaction = FALSE)),
    "y ~ a + b + (1 | id)"
  )
  expect_equal(deparse(colleyRstats:::.fit_formula("y", NULL, NULL)), "y ~ 1")
  # Non-syntactic names are backtick-quoted rather than breaking the formula.
  expect_equal(
    deparse(colleyRstats:::.fit_formula("tlx-mental", "Condition ID", "Participant ID")),
    "`tlx-mental` ~ `Condition ID` + (1 | `Participant ID`)"
  )
})


test_that("print.colley_fit summarises the analysis", {
  skip_if_not_installed("lme4")
  d <- make_study()
  fit <- fit_recommended(d, "score", "cond", cluster = "id", verbose = FALSE)

  out <- utils::capture.output(print(fit))

  expect_true(any(grepl("colleyRstats fitted analysis", out)))
  expect_true(any(grepl("Linear Mixed Model", out)))
})


# -------------------------------------------------------------------------
# Regressions
# -------------------------------------------------------------------------

test_that("the stored recommendation describes the model actually fitted", {
  skip_if_not_installed("lme4")
  # recommend_test() writes a main-effects fit_call ("y ~ a + b"), but a
  # factorial design is fitted with the interaction. Left unreconciled, the
  # object would carry a fit_call describing a different model from $model --
  # in the one object whose purpose is that they cannot drift apart.
  set.seed(1)
  d <- expand.grid(a = c("a1", "a2"), b = c("b1", "b2"), id = 1:20)
  d$id <- factor(d$id); d$a <- factor(d$a); d$b <- factor(d$b)
  d$y <- stats::rnorm(nrow(d)) + stats::rnorm(20)[as.integer(d$id)]

  fit <- fit_recommended(d, "y", c("a", "b"), cluster = "id", verbose = FALSE)

  expect_equal(deparse(fit$formula), deparse(stats::formula(fit$model)))
  expect_match(fit$recommendation$fit_call, "a * b", fixed = TRUE)

  main_only <- fit_recommended(d, "y", c("a", "b"),
    cluster = "id", interaction = FALSE, verbose = FALSE
  )
  expect_match(main_only$recommendation$fit_call, "a + b", fixed = TRUE)
})


test_that("the recorded call names the real function and keeps the family", {
  skip_if_not_installed("lme4")
  skip_if_not_installed("lmerTest")
  d <- make_study()
  # An lmerTest fit used to be recorded as lme4::lmer, and a logistic GLM as
  # "stats::glm(hit ~ cond, data = your_data)" -- a Gaussian model if re-run.
  fit <- fit_recommended(d, "score", "cond", cluster = "id", verbose = FALSE)
  expect_match(fit$recommendation$fit_call, "^lmerTest::lmer\\(")
  expect_identical(fit$model_function, "lmerTest::lmer")
  expect_match(fit$methods, "`lmerTest::lmer`", fixed = TRUE)

  glm_fit <- fit_recommended(d, "hit", "cond", verbose = FALSE)
  expect_match(glm_fit$recommendation$fit_call, "family = binomial", fixed = TRUE)
})


test_that("a one-way test refuses a factorial design instead of collapsing it", {
  # stats::oneway.test() does not reject a multi-term RHS: it silently collapses
  # the predictors with interaction() and analyses the resulting cells, which is
  # a different question from the one the recommendation describes.
  # recommend_test() no longer proposes it for a factorial design (see the HC3
  # test below), so the dispatcher's guard is exercised directly.
  set.seed(11)
  w <- expand.grid(g = factor(c("x", "y", "z")), h = factor(c("p", "q")), rep = 1:15)
  w$v <- stats::rnorm(nrow(w), 0, ifelse(w$g == "x", 0.2, 3))
  rec <- suppressWarnings(recommend_test(w, "v", c("g", "h")))
  rec$model_function <- "stats::oneway.test"
  expect_error(colleyRstats:::.fit_dispatch(rec, w), "one-way test")
})


test_that("a heteroscedastic factorial design gets HC3-robust Type III tests, not a collapsed Welch test", {
  skip_if_not_installed("car")
  # Welch's ANOVA has no factorial form: the old fit_call oneway.test(v ~ g + h)
  # analysed the six collapsed cells as one factor.
  set.seed(2)
  d <- expand.grid(g = factor(c("x", "y", "z")), h = factor(c("p", "q")), rep = 1:20)
  d$v <- stats::rnorm(nrow(d), mean = (d$h == "q") * 0.5, sd = ifelse(d$g == "x", 1, 1.8))

  rec <- recommend_test(d, "v", c("g", "h"))
  expect_identical(rec$model_function, "car::Anova")
  expect_false(rec$assumptions$homogeneous)

  fit <- fit_recommended(d, "v", c("g", "h"), verbose = FALSE)
  expect_identical(fit$engine, "lm_hc3")
  ref <- car::Anova(
    stats::lm(v ~ g * h, data = d, contrasts = list(g = "contr.sum", h = "contr.sum")),
    type = 3, white.adjust = "hc3"
  )
  expect_equal(fit$anova$term, c("g", "h", "g:h"))
  expect_equal(fit$anova$statistic, ref[c("g", "h", "g:h"), "F"], tolerance = 1e-8)
  expect_match(fit$recommendation$fit_call, "white.adjust = \"hc3\"", fixed = TRUE)
  expect_match(paste(fit$text, collapse = " "), "HC3")
})


test_that("an unbalanced between-subjects factorial uses order-independent Type III tests", {
  skip_if_not_installed("afex")
  # stats::aov() gave F = 2.03 / p = .158 or F = 0.14 / p = .709 for the same
  # effect depending on the order of the predictors (sequential sums of squares).
  set.seed(14)
  ub <- data.frame(
    a = factor(sample(c("a1", "a2"), 90, TRUE, prob = c(.75, .25))),
    b = factor(sample(c("b1", "b2"), 90, TRUE))
  )
  ub$b[ub$a == "a2"] <- factor(sample(c("b1", "b2"), sum(ub$a == "a2"), TRUE, prob = c(.85, .15)),
    levels = c("b1", "b2")
  )
  ub$y <- stats::rnorm(90) + 0.6 * (ub$b == "b2")

  f1 <- fit_recommended(ub, "y", c("a", "b"), verbose = FALSE)
  f2 <- fit_recommended(ub, "y", c("b", "a"), verbose = FALSE)
  expect_identical(f1$engine, "afex")
  expect_equal(f1$anova$statistic[f1$anova$term == "a"], f2$anova$statistic[f2$anova$term == "a"])
  expect_equal(f1$anova$statistic[f1$anova$term == "b"], f2$anova$statistic[f2$anova$term == "b"])
  ref <- car::Anova(
    stats::lm(y ~ a * b, data = ub, contrasts = list(a = "contr.sum", b = "contr.sum")),
    type = 3
  )
  expect_equal(f1$anova$statistic[f1$anova$term == "a"], ref["a", "F value"], tolerance = 1e-8)
})


test_that("fit_recommended refuses shapes it cannot honestly fit", {
  set.seed(3)
  b <- data.frame(g = factor(rep(c("x", "y", "z"), each = 20)))
  b$v <- c(stats::rexp(20), stats::rexp(20, .5), stats::rexp(20, .2))

  # No predictor: there are no groups to compare.
  expect_error(fit_recommended(b, "v", verbose = FALSE), "no predictor was given")

  # design = "within" is the explicit way to say repeated measures, and needs
  # the column saying what the measurements repeat over.
  expect_error(
    fit_recommended(b, "v", "g", design = "within", verbose = FALSE),
    "`cluster` must name"
  )
})


test_that("the aligned rank transform is refused without the full factorial model", {
  skip_if_not_installed("ARTool")
  # ARTool: "Model must include all combinations of interactions".
  set.seed(5)
  d <- expand.grid(a = factor(c("a1", "a2")), b = factor(c("b1", "b2")), id = factor(1:15))
  d$y <- stats::rexp(nrow(d)) + as.integer(d$a)
  skip_if_not(identical(recommend_test(d, "y", c("a", "b"), cluster = "id")$model_function, "ARTool::art"))
  expect_error(
    fit_recommended(d, "y", c("a", "b"), cluster = "id", interaction = FALSE, verbose = FALSE),
    "full factorial"
  )
})


test_that("recommended rank-based and mixed routes can actually be fitted", {
  skip_if_not_installed("ARTool")
  skip_if_not_installed("lme4")
  # Between-subjects factor + repeated rows per participant: used to go to
  # nparLD ("There is no subplot factor provided").
  set.seed(3)
  nb <- data.frame(id = factor(rep(1:20, each = 3)))
  nb$grp <- factor(ifelse(as.integer(nb$id) <= 10, "ctrl", "trt"))
  nb$y <- stats::rexp(60) * ifelse(nb$grp == "trt", 2.5, 1)
  f_nb <- fit_recommended(nb, "y", "grp", cluster = "id", verbose = FALSE)
  expect_identical(f_nb$engine, "art")
  expect_true(length(f_nb$text) > 0)

  # nparLD is refused for a predictor that does not vary within the cluster.
  rec <- recommend_test(nb, "y", "grp", cluster = "id")
  rec$model_function <- "nparLD::nparLD"
  expect_error(colleyRstats:::.fit_dispatch(rec, nb), "within-subject factor")

  # Factor + continuous covariate, non-normal: used to go to ART ("All fixed
  # effect terms must be factors").
  set.seed(11)
  cv <- data.frame(id = factor(rep(1:20, each = 3)), cond = factor(rep(c("A", "B", "C"), 20)))
  cv$age <- rep(round(stats::runif(20, 18, 65), 1), each = 3)
  cv$y <- stats::rexp(60)
  f_cv <- fit_recommended(cv, "y", c("cond", "age"), cluster = "id", verbose = FALSE)
  expect_identical(f_cv$engine, "lmer")
})


test_that("numeric covariates are not silently turned into factors", {
  skip_if_not_installed("lme4")
  # Eight participants with eight distinct ages: as an eight-level factor, age
  # was aliased with the participant random effect and lmer failed.
  set.seed(12)
  sm <- data.frame(id = factor(rep(1:8, each = 3)), cond = factor(rep(c("A", "B", "C"), 8)))
  sm$age <- rep(c(21, 23, 24, 27, 30, 31, 35, 42), each = 3)
  sm$y <- stats::rnorm(24)
  expect_message(
    fit <- fit_recommended(sm, "y", c("cond", "age"), cluster = "id"),
    "Kept numeric predictor `age`"
  )
  expect_true(is.numeric(stats::model.frame(fit$model)$age))

  # Integer condition codes are treated as categorical -- announced -- unless
  # `factors` says otherwise.
  set.seed(2)
  cd <- data.frame(id = factor(rep(1:12, each = 3)), cond = rep(1:3, 12))
  cd$y <- stats::rnorm(36) + cd$cond
  expect_message(
    f_codes <- fit_recommended(cd, "y", "cond", cluster = "id"),
    "Treating numeric predictor `cond`"
  )
  expect_true(is.factor(stats::model.frame(f_codes$model)$cond))
  f_num <- fit_recommended(cd, "y", "cond", cluster = "id", factors = character(0), verbose = FALSE)
  expect_true(is.numeric(stats::model.frame(f_num$model)$cond))
})


test_that("column names with spaces and hyphens can be fitted", {
  skip_if_not_installed("lme4")
  set.seed(4)
  sc <- data.frame(
    `Participant ID` = factor(rep(1:20, each = 3)),
    `Condition ID` = factor(rep(c("A", "B", "C"), 20)),
    check.names = FALSE
  )
  sc$`tlx-mental` <- stats::rnorm(60) + stats::rnorm(20)[as.integer(sc$`Participant ID`)]
  fit <- fit_recommended(sc, "tlx-mental", "Condition ID", cluster = "Participant ID", verbose = FALSE)
  expect_identical(fit$engine, "lmer")
  expect_match(paste(fit$text, collapse = " "), "\\textit{Condition ID}", fixed = TRUE)
  expect_equal(nrow(fit$contrasts), 3L)

  # The rank-based engines cannot take backticked names; they are fitted on
  # syntactic copies and reported under the original names.
  skip_if_not_installed("ARTool")
  set.seed(5)
  sa <- expand.grid(a = factor(c("a1", "a2")), b = factor(c("b1", "b2")), p = factor(1:15))
  names(sa) <- c("Fac A", "Fac-b", "Participant ID")
  sa$`tlx-mental` <- stats::rexp(nrow(sa)) + as.integer(sa$`Fac A`)
  fa <- fit_recommended(sa, "tlx-mental", c("Fac A", "Fac-b"), cluster = "Participant ID", verbose = FALSE)
  skip_if_not(identical(fa$engine, "art"))
  expect_true(all(c("Fac A", "Fac-b", "Fac A:Fac-b") %in% fa$anova$term))
  expect_true(all(c("Fac A", "Fac-b") %in% fa$contrasts$term))

  skip_if_not_installed("nparLD")
  set.seed(3)
  np <- data.frame(
    `Participant ID` = factor(rep(1:20, each = 3)),
    `Time point` = factor(rep(c("T1", "T2", "T3"), 20)), check.names = FALSE
  )
  np$`tlx-mental` <- stats::rexp(60) * c(1, 1.5, 3)[as.integer(np$`Time point`)]
  fn <- fit_recommended(np, "tlx-mental", "Time point", cluster = "Participant ID", verbose = FALSE)
  expect_identical(fn$engine, "nparld")
})


test_that("a clustered nominal outcome is fitted with a random intercept, not as independent", {
  skip_if_not_installed("mclogit")
  # 20 subjects x 6 choices went into multinom(choice ~ cond) with no warning,
  # while the methods text said "clustered within id".
  set.seed(8)
  nm <- data.frame(id = factor(rep(1:20, each = 6)), cond = factor(rep(c("A", "B"), 60)))
  nm$choice <- factor(sample(c("p", "q", "r"), 120, TRUE))
  fit <- suppressWarnings(fit_recommended(nm, "choice", "cond", cluster = "id", verbose = FALSE))
  expect_identical(fit$engine, "mblogit")
  expect_s3_class(fit$model, "mblogit")
  expect_match(fit$recommendation$fit_call, "random = ~ 1 | id", fixed = TRUE)
})


test_that("over-dispersed counts are fitted as negative binomial and reported as IRRs", {
  skip_if_not_installed("MASS")
  skip_if_not_installed("parameters")
  set.seed(6)
  oc <- data.frame(g = factor(rep(c("x", "y"), each = 40)))
  oc$errors <- MASS::rnegbin(80, mu = ifelse(oc$g == "x", 4, 5.5), theta = 0.8)

  fit <- suppressMessages(fit_recommended(oc, "errors", "g", verbose = FALSE))
  expect_identical(fit$engine, "glmnb")
  ref <- summary(MASS::glm.nb(errors ~ g, data = oc))$coefficients["gy", "Pr(>|z|)"]
  txt <- paste(fit$text, collapse = " ")
  expect_match(txt, "$IRR = ", fixed = TRUE)
  expect_match(txt, colleyRstats:::.fmt_p_macro(ref), fixed = TRUE)
  expect_match(fit$methods, "negative-binomial")

  # Clustered: a negative-binomial GLMM (glmmTMB nbinom2), still reported as IRRs.
  skip_if_not_installed("lme4")
  skip_if_not_installed("glmmTMB")
  set.seed(6)
  oc_cl <- data.frame(id = factor(rep(1:20, each = 4)), g = factor(rep(c("x", "y"), 40)))
  oc_cl$errors <- MASS::rnegbin(80, mu = ifelse(oc_cl$g == "x", 4, 5.5), theta = 0.8)
  fit_cl <- suppressWarnings(suppressMessages(
    fit_recommended(oc_cl, "errors", "g", cluster = "id", verbose = FALSE)
  ))
  expect_identical(fit_cl$engine, "glmmtmb")
  expect_match(fit_cl$recommendation$fit_call, "family = glmmTMB::nbinom2", fixed = TRUE)
  expect_match(paste(fit_cl$text, collapse = " "), "$IRR = ", fixed = TRUE)
})


test_that("sink_to writes LaTeX that escapes the methods sentence", {
  skip_if_not_installed("lme4")
  skip_if_not_installed("parameters")
  # The methods sentence carried `tlx_mental` with a bare underscore, which
  # does not compile.
  d <- make_study()
  d$tlx_mental <- d$score
  d$participant_id <- d$id
  path <- withr::local_tempfile(fileext = ".tex")
  fit <- suppressMessages(fit_recommended(d, "tlx_mental", "cond",
    cluster = "participant_id", sink_to = path, verbose = FALSE
  ))
  tex <- readLines(path)
  expect_match(tex[[1]], "\\texttt{tlx\\_mental}", fixed = TRUE)
  expect_false(any(grepl("`", tex, fixed = TRUE)))
  expect_false(any(grepl("(?<!\\\\)_", tex, perl = TRUE)))
  # The console version stays readable.
  expect_match(fit$methods, "`tlx_mental`", fixed = TRUE)
})


test_that("contrast failures are reported instead of silently returning NULL", {
  skip_if_not_installed("emmeans")
  d <- make_study()
  rec <- recommend_test(d, "score", "cond")
  broken <- list(model = "not a model", engine = "lm")
  expect_message(
    res <- colleyRstats:::.fit_contrasts(broken, rec, d),
    "could not be computed"
  )
  expect_null(res)
})


test_that("a singular fit is flagged and written into the methods", {
  skip_if_not_installed("lme4")
  # No between-participant variance at all: the random intercept is estimated
  # at zero. lme4 says so on the console, but nothing reached the result.
  set.seed(9)
  sg <- data.frame(id = factor(rep(1:10, each = 3)), cond = factor(rep(c("A", "B", "C"), 10)))
  sg$y <- stats::rnorm(30)
  fit <- fit_recommended(sg, "y", "cond", cluster = "id", verbose = FALSE)
  expect_true(fit$singular)
  expect_match(fit$methods, "singular")
})


test_that("repeated trials are fitted with random slopes, simplified when singular", {
  skip_if_not_installed("lme4")
  # Several trials per participant and condition: without by-participant
  # slopes the condition effect is tested against the trial-level residual,
  # which is anti-conservative (Barr et al., 2013).
  set.seed(17)
  sl <- expand.grid(trial = 1:6, cond = factor(c("A", "B")), id = factor(1:20))
  u <- stats::rnorm(20)
  s <- stats::rnorm(20, sd = 0.8)
  sl$y <- u[as.integer(sl$id)] + (sl$cond == "B") * (0.3 + s[as.integer(sl$id)]) + stats::rnorm(nrow(sl))
  fit <- fit_recommended(sl, "y", "cond", cluster = "id", verbose = FALSE)
  expect_identical(fit$random, "(1 + cond | id)")
  expect_match(fit$recommendation$fit_call, "(1 + cond | id)", fixed = TRUE)
  # The denominator df reflect the 20 participants, not the 240 trials.
  expect_lt(fit$anova$df2[[1]], 30)

  # No true slope variance in a 2 x 2 within design: the slope model is
  # singular and is simplified, and the methods say so.
  set.seed(2)
  d <- expand.grid(a = factor(c("a1", "a2")), b = factor(c("b1", "b2")), id = factor(1:20))
  d$y <- stats::rnorm(nrow(d)) + stats::rnorm(20)[as.integer(d$id)]
  expect_message(
    f2 <- fit_recommended(d, "y", c("a", "b"), cluster = "id"),
    "simplified"
  )
  expect_identical(f2$random, "(1 | id)")
  expect_match(f2$methods, "simplified to `(1 | id)`", fixed = TRUE)
})


test_that("post-hoc contrasts are per factor, with simple effects only for a significant interaction", {
  skip_if_not_installed("emmeans")
  skip_if_not_installed("afex")
  # emmeans compared every a x b cell: 15 tests for a 2 x 3 design, even with
  # interaction = FALSE or a null interaction.
  set.seed(18)
  ph <- expand.grid(a = factor(c("a1", "a2")), b = factor(c("b1", "b2", "b3")), rep = 1:15)
  ph$y <- stats::rnorm(nrow(ph)) + (ph$b == "b3")
  # Balanced design: the sequential interaction test equals the Type III one.
  skip_if_not(stats::anova(stats::lm(y ~ a * b, data = ph))["a:b", "Pr(>F)"] >= 0.05)
  fit <- fit_recommended(ph, "y", c("a", "b"), verbose = FALSE)
  expect_equal(nrow(fit$contrasts), 4L) # a: 1, b: 3
  expect_setequal(unique(fit$contrasts$term), c("a", "b"))
  main <- fit_recommended(ph, "y", c("a", "b"), interaction = FALSE, verbose = FALSE)
  expect_equal(nrow(main$contrasts), 4L)

  # A significant crossover interaction adds simple effects, adjusted within
  # each level of the other factor.
  set.seed(19)
  cx <- expand.grid(a = factor(c("a1", "a2")), b = factor(c("b1", "b2", "b3")), rep = 1:15)
  cx$y <- stats::rnorm(nrow(cx)) + ifelse(cx$b == "b3", -1, 1) * (cx$a == "a2")
  fx <- fit_recommended(cx, "y", c("a", "b"), verbose = FALSE)
  expect_lt(fx$anova$p[fx$anova$term == "a:b"], 0.05)
  simple <- fx$contrasts[fx$contrasts$term == "b | a", ]
  expect_equal(nrow(simple), 6L)
  ref <- as.data.frame(emmeans::contrast(
    emmeans::emmeans(stats::lm(y ~ a * b, data = cx), ~ b | a),
    "pairwise", adjust = "holm"
  ))
  expect_equal(simple$p.value, ref$p.value, tolerance = 1e-8)
  expect_match(fx$methods, "simple effects")
})


test_that("contrasts are computed for a cumulative link mixed model", {
  skip_if_not_installed("ordinal")
  skip_if_not_installed("emmeans")
  # emmeans could not find the data of a model fitted inside fit_recommended(),
  # so CLMM contrasts silently came back NULL.
  d <- make_study()
  fit <- fit_recommended(d, "rating", "cond", cluster = "id", verbose = FALSE)
  expect_equal(nrow(fit$contrasts), 3L)
})


test_that("an ordinal outcome held as labels is refused rather than sorted alphabetically", {
  # sort(c("low","medium","high")) is high < low < medium, which would fit a
  # proportional-odds model on a scrambled scale.
  set.seed(4)
  d <- data.frame(
    id = factor(rep(1:20, each = 3)),
    g = factor(rep(c("x", "y", "z"), 20)),
    stringsAsFactors = FALSE
  )
  # Not perfectly confounded with `g`: a response that varies within each group
  # is what an ordinal model can actually be estimated on.
  d$r <- sample(c("low", "medium", "high"), nrow(d), replace = TRUE)

  expect_error(
    fit_recommended(d, "r", "g", cluster = "id", outcome_type = "ordinal", verbose = FALSE),
    "response order cannot be inferred"
  )

  # Supplied in the right order, it fits.
  skip_if_not_installed("ordinal")
  d$r <- factor(d$r, levels = c("low", "medium", "high"), ordered = TRUE)
  expect_equal(fit_recommended(d, "r", "g", cluster = "id", verbose = FALSE)$engine, "clmm")
})


test_that("the ART engine produces a report sentence", {
  skip_if_not_installed("ARTool")
  # report_art() reports an ANOVA table, not the art object; handing it the
  # latter made $text silently NULL and a significant effect went unreported.
  set.seed(5)
  d <- expand.grid(a = factor(c("a1", "a2")), b = factor(c("b1", "b2")), id = factor(1:15))
  d$y <- stats::rexp(nrow(d)) + as.integer(d$a)

  fit <- suppressWarnings(fit_recommended(d, "y", c("a", "b"), cluster = "id", verbose = FALSE))

  skip_if_not(identical(fit$engine, "art"))
  expect_true(length(fit$text) > 0)
  expect_match(paste(fit$text, collapse = " "), "ART")
})


test_that("ART simple effects use ART-C within the levels of the other factor", {
  skip_if_not_installed("ARTool")
  set.seed(1)
  ad <- expand.grid(a = factor(c("a1", "a2")), b = factor(c("b1", "b2", "b3")), id = factor(1:16))
  ad$y <- stats::rexp(nrow(ad)) * exp(0.9 * (ad$a == "a2") * (ad$b == "b3"))
  fit <- suppressWarnings(fit_recommended(ad, "y", c("a", "b"), cluster = "id", verbose = FALSE))
  skip_if_not(identical(fit$engine, "art"))
  art_tab <- suppressMessages(stats::anova(fit$model))
  skip_if_not(art_tab[["Pr(>F)"]][trimws(art_tab$Term) == "a:b"] < 0.05)
  # Not the 15 cell-by-cell comparisons of a:b: 1 (a) + 3 (b) + 3 (a | b) + 6 (b | a).
  expect_equal(nrow(fit$contrasts), 13L)
  simple <- fit$contrasts[fit$contrasts$term == "a | b", ]
  expect_equal(nrow(simple), 3L)
  expect_setequal(simple$by, c("b = b1", "b = b2", "b = b3"))
  expect_match(fit$methods, "ART-C")
})


test_that("a multinomial fit can be printed", {
  skip_if_not_installed("nnet")
  # summary.multinom() re-evaluates the recorded call, so a call naming
  # .fit_dispatch()'s locals made print(fit) throw "object 'no_re' not found".
  set.seed(8)
  d <- data.frame(g = factor(rep(c("x", "y"), each = 40)))
  d$out <- factor(sample(c("A", "B", "C"), 80, TRUE))

  fit <- fit_recommended(d, "out", "g", verbose = FALSE)

  expect_equal(fit$engine, "multinom")
  expect_no_error(utils::capture.output(print(fit)))
})


test_that("the adjust argument actually adjusts", {
  skip_if_not_installed("lme4")
  skip_if_not_installed("emmeans")
  # Asserting only that p-values lie in [0, 1] would pass under any adjustment,
  # or none.
  d <- make_study()

  holm <- as.data.frame(fit_recommended(d, "score", "cond",
    cluster = "id", adjust = "holm", verbose = FALSE
  )$contrasts)
  none <- as.data.frame(fit_recommended(d, "score", "cond",
    cluster = "id", adjust = "none", verbose = FALSE
  )$contrasts)

  expect_true(all(holm$p.value >= none$p.value - 1e-12))
  expect_true(any(holm$p.value > none$p.value))
})
