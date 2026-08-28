# A within-subjects study of three conditions whose continuous outcome passes
# the group-wise normality check, so the recommendation lands on a linear mixed
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
  # is how a questionnaire subscale ends up in a Poisson model.
  d$subscale <- round(50 + 10 * d$score)

  auto <- fit_recommended(d, "subscale", "cond", cluster = "id", verbose = FALSE)
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
  expect_false(is.null(fit$emmeans))
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


test_that("a one-way test refuses a factorial design instead of collapsing it", {
  # stats::oneway.test() does not reject a multi-term RHS: it silently collapses
  # the predictors with interaction() and analyses the resulting cells, which is
  # a different question from the one the recommendation describes.
  set.seed(11)
  w <- expand.grid(g = factor(c("x", "y", "z")), h = factor(c("p", "q")), rep = 1:15)
  w$v <- stats::rnorm(nrow(w), 0, ifelse(w$g == "x", 0.2, 3))

  skip_if_not(identical(recommend_test(w, "v", c("g", "h"))$model_function, "stats::oneway.test"))
  expect_error(fit_recommended(w, "v", c("g", "h"), verbose = FALSE), "one-way test")
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
