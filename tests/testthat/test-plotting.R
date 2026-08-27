test_that("generateEffectPlot returns a ggplot object", {
  # Create dummy data
  df <- data.frame(
    strat = rep(c("A", "B"), each = 10),
    emotion = rep(c("Happy", "Sad"), 10),
    score = rnorm(20)
  )

  # Run function
  p <- generateEffectPlot(
    data = df,
    x = "strat",
    y = "score",
    fillColourGroup = "emotion",
    ytext = "Score",
    xtext = "Strategy"
  )

  # Check if it is a ggplot class
  expect_s3_class(p, "ggplot")
})

test_that("generateEffectPlot errors on unknown effect type", {
  df <- data.frame(
    strat = rep(c("A", "B"), each = 10),
    emotion = rep(c("Happy", "Sad"), 10),
    score = rnorm(20)
  )

  expect_error(
    generateEffectPlot(
      data = df,
      x = "strat",
      y = "score",
      fillColourGroup = "emotion",
      shownEffect = "unknown"
    ),
    "wrong effect defined"
  )
})

test_that("generateMoboPlot returns a ggplot object", {
  df <- data.frame(
    Iteration = 1:10,
    score = rnorm(10),
    ConditionID = rep(c("A", "B"), each = 5)
  )

  p <- generateMoboPlot(df, x = "Iteration", y = "score")
  expect_s3_class(p, "ggplot")
})

test_that("generateMoboPlot2 returns a ggplot object", {
  df <- data.frame(
    Iteration = 1:10,
    score = rnorm(10),
    ConditionID = rep(c("A", "B"), each = 5),
    Phase = rep(c("sampling", "optimization"), each = 5)
  )

  p <- generateMoboPlot2(
    data = df,
    x = "Iteration",
    y = "score",
    phaseCol = "Phase",
    fillColourGroup = "ConditionID"
  )
  expect_s3_class(p, "ggplot")
})

test_that("generateMoboPlot2 rejects data without both phases", {
  df <- data.frame(
    Iteration = 1:10,
    score = rnorm(10),
    ConditionID = rep(c("A", "B"), each = 5),
    Phase = rep("optimization", 10)
  )

  # Used to silently produce -Inf annotation positions
  expect_error(
    generateMoboPlot2(data = df, x = "Iteration", y = "score"),
    "sampling"
  )
})

test_that("generateMoboPlot2 uses documented default grouping and labels", {
  df <- data.frame(
    Iteration = 1:10,
    score = rnorm(10),
    ConditionID = rep(c("value_only", "llm_only"), each = 5),
    Phase = rep(c("sampling", "optimization"), each = 5)
  )

  p <- generateMoboPlot2(
    data = df,
    x = "Iteration",
    y = "score",
    fillLabels = c(value_only = "Value Only", llm_only = "LLM Only")
  )

  expect_s3_class(p, "ggplot")
  expect_equal(p$labels$x, "Iteration")
  expect_equal(p$labels$y, "Score")
  expect_true(any(vapply(p$scales$scales, inherits, logical(1), what = "ScaleDiscrete")))
})

test_that("animate_mobo2 needs more than one iteration", {
  df <- data.frame(
    Iteration = rep(1, 10),
    score = rnorm(10),
    ConditionID = rep(c("A", "B"), each = 5),
    Phase = rep(c("sampling", "optimization"), each = 5)
  )

  expect_error(
    animate_mobo2(df, y = "score", filename = tempfile(fileext = ".mp4")),
    "at least two iterations"
  )
})

test_that("animate_mobo2 writes a video of the run", {
  skip_on_cran()
  skip_if_not_installed("av")
  skip_if_not_installed("Hmisc")

  set.seed(1)
  df <- data.frame(
    Iteration   = rep(1:4, each = 4),
    ConditionID = rep(rep(c("A", "B"), each = 2), 4),
    Phase       = rep(c("sampling", "optimization"), each = 8),
    score       = 0.3 + 0.05 * rep(1:4, each = 4) + rnorm(16, sd = 0.05)
  )
  out <- tempfile(fileext = ".mp4")

  expect_message(
    animate_mobo2(
      df,
      y = "score", filename = out,
      width = 3, height = 2, dpi = 100, end_pause = 0
    ),
    "Saved animation"
  )
  expect_true(file.exists(out))
  expect_gt(file.size(out), 0)
})

test_that("generateEffectPlot applies custom axis and legend labels", {
  df <- data.frame(
    strat = rep(c("A", "B"), each = 10),
    emotion = rep(c("Happy", "Sad"), 10),
    score = rnorm(20)
  )

  p <- generateEffectPlot(
    data = df,
    x = "strat",
    y = "score",
    fillColourGroup = "emotion",
    ytext = "Custom Y",
    xtext = "Custom X",
    legendHeading = "Emotion",
    effectLegend = TRUE,
    effectDescription = "Overall mean"
  )

  expect_equal(p$labels$x, "Custom X")
  expect_equal(p$labels$y, "Custom Y")
  expect_equal(p$labels$colour, "Emotion")
  expect_equal(p$labels$fill, "Emotion")
})

test_that("plot wrappers reject unknown column names with a clear error", {
  main_df <- data.frame(
    CondID = factor(rep(c("A", "B"), each = 15)),
    tlx_mental = rnorm(30)
  )

  expect_error(
    ggbetweenstatsWithPriorNormalityCheck(
      data = main_df, x = "Cond_typo", y = "tlx_mental", ylab = "Mental Demand"
    ),
    "'Cond_typo' not found"
  )
  expect_error(
    generateEffectPlot(
      data = main_df, x = "CondID", y = "missing_dv", fillColourGroup = "CondID"
    ),
    "'missing_dv' not found"
  )
})

test_that("plot wrappers warn when xlabels length does not match the groups", {
  main_df <- data.frame(
    CondID = factor(rep(c("A", "B", "C"), each = 10)),
    tlx_mental = rnorm(30)
  )

  expect_warning(
    ggbetweenstatsWithPriorNormalityCheck(
      data = main_df, x = "CondID", y = "tlx_mental",
      ylab = "Mental Demand", xlabels = c("Only", "Two")
    ),
    "xlabels"
  )
})

test_that("ggwithinstatsWithPriorNormalityCheck returns a ggplot object", {
  main_df <- data.frame(
    Participant = factor(rep(1:10, each = 3)),
    CondID = factor(rep(c("A", "B", "C"), times = 10)),
    tlx_mental = rnorm(30)
  )

  p <- ggwithinstatsWithPriorNormalityCheck(
    data = main_df,
    x = "CondID",
    y = "tlx_mental",
    ylab = "Mental Demand"
  )
  expect_s3_class(p, "ggplot")
})

test_that("ggbetweenstatsWithPriorNormalityCheck returns a ggplot object", {
  main_df <- data.frame(
    CondID = factor(rep(c("A", "B"), each = 15)),
    tlx_mental = rnorm(30)
  )

  p <- ggbetweenstatsWithPriorNormalityCheck(
    data = main_df,
    x = "CondID",
    y = "tlx_mental",
    ylab = "Mental Demand",
    xlabels = c("A", "B")
  )
  expect_s3_class(p, "ggplot")
})

test_that("ggbetweenstatsWithPriorNormalityCheckAsterisk returns a ggplot object", {
  main_df <- data.frame(
    CondID = factor(rep(c("A", "B"), each = 15)),
    tlx_mental = rnorm(30)
  )

  p <- ggbetweenstatsWithPriorNormalityCheckAsterisk(
    data = main_df,
    x = "CondID",
    y = "tlx_mental",
    ylab = "Mental Demand",
    xlabels = c("A", "B")
  )
  expect_s3_class(p, "ggplot")
})

test_that("ggwithinstatsWithPriorNormalityCheckAsterisk returns a ggplot object", {
  main_df <- data.frame(
    Participant = factor(rep(1:10, each = 3)),
    CondID = factor(rep(c("A", "B", "C"), times = 10)),
    tlx_mental = rnorm(30)
  )

  p <- ggwithinstatsWithPriorNormalityCheckAsterisk(
    data = main_df,
    x = "CondID",
    y = "tlx_mental",
    ylab = "Mental Demand",
    xlabels = c("A", "B", "C")
  )
  expect_s3_class(p, "ggplot")
})
