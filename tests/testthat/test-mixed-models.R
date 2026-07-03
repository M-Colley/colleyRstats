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
  expect_identical(classify_outcome(rpois(50, 5) + 3L), "count")
})

test_that("classify_outcome respects ordinal_max_levels", {
  x <- sample(1:10, 100, replace = TRUE) # 10 distinct non-negative integers
  expect_identical(classify_outcome(x, ordinal_max_levels = 7L), "count")
  expect_identical(classify_outcome(x, ordinal_max_levels = 12L), "ordinal")
})

test_that("classify_outcome errors on an unclassifiable input", {
  expect_error(classify_outcome(as.complex(1:5)), "Cannot classify")
  expect_error(classify_outcome(NULL), "must not be empty")
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
  d <- make_mixed_df()
  rb <- recommend_test(d, outcome = "bin", predictors = "cond", cluster = "id")
  expect_identical(rb$outcome_type, "binary")
  expect_identical(rb$model_function, "lme4::glmer")
  expect_identical(rb$reporter, "reportGLMM")
  expect_match(rb$family, "binomial")

  rc <- recommend_test(d, outcome = "cnt", predictors = "cond", cluster = "id")
  expect_identical(rc$outcome_type, "count")
  expect_identical(rc$model_function, "lme4::glmer")
  expect_match(rc$family, "poisson")
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
  expect_error(recommend_test(d, outcome = "nope"), "outcome")
  expect_error(recommend_test(d, outcome = "score", predictors = "nope"))
  expect_error(recommend_test(d, outcome = "score", cluster = "nope"))
})

test_that("print.colley_recommendation returns its input invisibly", {
  d <- make_mixed_df()
  r <- recommend_test(d, outcome = "rating", predictors = "cond", cluster = "id")
  expect_output(print(r), "analysis recommendation")
  expect_invisible(print(r))
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

test_that("reportCLMM rejects a non-ordinal model", {
  skip_if_not_installed("lme4")
  skip_if_not_installed("ordinal")
  d <- make_mixed_df()
  m <- lme4::lmer(score ~ cond + (1 | id), data = d)
  expect_error(reportCLMM(m), "clmm")
})
