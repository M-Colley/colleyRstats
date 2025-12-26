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
