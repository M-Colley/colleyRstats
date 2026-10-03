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
    ylab = "Mental Demand",
    subject = "Participant"
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
    xlabels = c("A", "B", "C"),
    subject = "Participant"
  )
  expect_s3_class(p, "ggplot")
})


# ---------------------------------------------------------------------------
# Within-subjects pairing (`subject`)
# ---------------------------------------------------------------------------

# Repeated-measures toy data with a large between-participant spread and a
# small, consistent condition effect: the paired test finds it easily, a test
# that pairs the wrong rows does not.
within_df <- function(n = 20, seed = 1) {
  set.seed(seed)
  d <- data.frame(
    pid = rep(seq_len(n), 3),
    cond = factor(rep(c("A", "B", "C"), each = n))
  )
  d$y <- rnorm(n, 0, 5)[d$pid] + c(0, 1, 2)[as.integer(d$cond)] + rnorm(3 * n, 0, 0.5)
  d
}

omnibus <- function(p) {
  st <- ggstatsplot::extract_stats(p)$subtitle_data
  c(statistic = st$statistic[1], p.value = st$p.value[1])
}

test_that("within wrappers require `subject`", {
  d <- within_df()
  expect_error(
    ggwithinstatsWithPriorNormalityCheck(d, "cond", "y", ylab = "Y"),
    "`subject` is required for a within-subjects"
  )
  expect_error(
    ggwithinstatsWithPriorNormalityCheck(d, "cond", "y", ylab = "Y", subject = NULL),
    "paired by row order"
  )
  expect_error(
    ggwithinstatsWithPriorNormalityCheckAsterisk(d, "cond", "y", ylab = "Y", xlabels = c("A", "B", "C")),
    "`subject` is required"
  )
  expect_error(
    ggwithinstatsWithPriorNormalityCheck(d, "cond", "y", ylab = "Y", subject = "pid_typo"),
    "'pid_typo' not found"
  )
})

test_that("within wrapper pairs by participant, not by row order", {
  d <- within_df()
  shuffled <- d
  rows_b <- which(shuffled$cond == "B")
  set.seed(99)
  shuffled[rows_b, ] <- shuffled[sample(rows_b), ]

  p_sorted <- ggwithinstatsWithPriorNormalityCheck(d, "cond", "y", ylab = "Y", subject = "pid")
  p_shuffled <- ggwithinstatsWithPriorNormalityCheck(shuffled, "cond", "y", ylab = "Y", subject = "pid")

  # Before the fix, shuffling one condition's rows re-paired the observations
  # and moved p from ~1e-15 to ~0.16.
  expect_equal(omnibus(p_shuffled), omnibus(p_sorted))
  expect_lt(omnibus(p_sorted)[["p.value"]], 1e-6)
  pw_sorted <- ggstatsplot::extract_stats(p_sorted)$pairwise_comparisons_data
  pw_shuffled <- ggstatsplot::extract_stats(p_shuffled)$pairwise_comparisons_data
  expect_equal(pw_shuffled$p.value, pw_sorted$p.value)
})

test_that("asterisk within wrapper pairs by participant, not by row order", {
  d <- within_df()
  shuffled <- d[sample(nrow(d)), ]

  brackets <- function(p) {
    sig <- Filter(function(l) inherits(l$geom, "GeomSignif"), p$layers)
    expect_length(sig, 1L)
    sig[[1]]$stat_params$annotations
  }
  p_sorted <- suppressMessages(ggwithinstatsWithPriorNormalityCheckAsterisk(
    d, "cond", "y", ylab = "Y", xlabels = c("A", "B", "C"), subject = "pid"
  ))
  p_shuffled <- suppressMessages(ggwithinstatsWithPriorNormalityCheckAsterisk(
    shuffled, "cond", "y", ylab = "Y", xlabels = c("A", "B", "C"), subject = "pid"
  ))
  expect_equal(omnibus(p_shuffled), omnibus(p_sorted))
  expect_identical(brackets(p_shuffled), brackets(p_sorted))

  # The brackets carry the participant-paired, Holm-adjusted post-hoc p-values
  # that ggstatsplot computes for the same data.
  ref <- ggstatsplot::extract_stats(
    ggwithinstatsWithPriorNormalityCheck(d, "cond", "y", ylab = "Y", subject = "pid")
  )$pairwise_comparisons_data
  expected <- .p_to_asterisk(ref$p.value)
  expect_identical(brackets(p_sorted), expected[!is.na(expected)])
})

test_that("a participant missing a condition is dropped, with a message", {
  d <- within_df()
  incomplete <- d[!(d$pid == 7 & d$cond == "B"), ]

  expect_message(
    p_dropped <- ggwithinstatsWithPriorNormalityCheck(incomplete, "cond", "y", ylab = "Y", subject = "pid"),
    "dropped 1 of 20 participants.*: 7\\."
  )
  # Identical to analysing the complete participants only. Before the fix the
  # missing cell shifted the pairing of every later participant.
  p_complete <- ggwithinstatsWithPriorNormalityCheck(d[d$pid != 7, ], "cond", "y", ylab = "Y", subject = "pid")
  expect_equal(omnibus(p_dropped), omnibus(p_complete))

  # A missing outcome counts as a missing condition
  na_cell <- d
  na_cell$y[na_cell$pid == 3 & na_cell$cond == "C"] <- NA
  expect_message(
    ggwithinstatsWithPriorNormalityCheck(na_cell, "cond", "y", ylab = "Y", subject = "pid"),
    "dropped 1 of 20 participants.*: 3\\."
  )
})

test_that("more than one row per participant and condition is an error", {
  d <- within_df()
  duplicated_trial <- rbind(d, d[d$pid == 4 & d$cond == "A", ])
  expect_error(
    ggwithinstatsWithPriorNormalityCheck(duplicated_trial, "cond", "y", ylab = "Y", subject = "pid"),
    "More than one row per participant and condition.*participant 4.*aggregate"
  )
  expect_error(
    ggwithinstatsWithPriorNormalityCheckAsterisk(duplicated_trial, "cond", "y", ylab = "Y",
                                                 xlabels = c("A", "B", "C"), subject = "pid"),
    "aggregate repeated trials"
  )
})


# ---------------------------------------------------------------------------
# Arguments that ggstatsplot had silently stopped honouring
# ---------------------------------------------------------------------------

has_signif <- function(p) any(vapply(p$layers, function(l) inherits(l$geom, "GeomSignif"), logical(1)))

test_that("showPairwiseComp = FALSE removes the brackets", {
  d <- within_df()
  on <- ggwithinstatsWithPriorNormalityCheck(d, "cond", "y", ylab = "Y", subject = "pid",
                                             showPairwiseComp = TRUE)
  off <- ggwithinstatsWithPriorNormalityCheck(d, "cond", "y", ylab = "Y", subject = "pid",
                                              showPairwiseComp = FALSE)
  expect_true(has_signif(on))
  expect_false(has_signif(off))

  between <- data.frame(g = factor(rep(c("A", "B", "C"), each = 15)),
                        y = c(rnorm(15, 0), rnorm(15, 3), rnorm(15, 6)))
  expect_false(has_signif(
    ggbetweenstatsWithPriorNormalityCheck(between, "g", "y", ylab = "Y", showPairwiseComp = FALSE)
  ))
  expect_error(
    ggbetweenstatsWithPriorNormalityCheck(between, "g", "y", ylab = "Y", showPairwiseComp = "yes"),
    "TRUE or FALSE"
  )
})

test_that("plotType hides the violin or the box", {
  d <- within_df()
  geom_data <- function(p, geom) {
    i <- which(vapply(p$layers, function(l) inherits(l$geom, geom), logical(1)))
    ggplot2::layer_data(p, i)
  }
  hidden <- function(ld) all(ld$xmin == ld$xmax) && all(is.na(ld$colour))

  box <- ggwithinstatsWithPriorNormalityCheck(d, "cond", "y", ylab = "Y", subject = "pid", plotType = "box")
  expect_true(hidden(geom_data(box, "GeomViolin")))
  expect_false(hidden(geom_data(box, "GeomBoxplot")))

  violin <- ggwithinstatsWithPriorNormalityCheck(d, "cond", "y", ylab = "Y", subject = "pid", plotType = "violin")
  expect_true(hidden(geom_data(violin, "GeomBoxplot")))
  expect_false(hidden(geom_data(violin, "GeomViolin")))

  both <- ggwithinstatsWithPriorNormalityCheck(d, "cond", "y", ylab = "Y", subject = "pid")
  expect_false(hidden(geom_data(both, "GeomViolin")))
  expect_false(hidden(geom_data(both, "GeomBoxplot")))

  between <- data.frame(g = factor(rep(c("A", "B"), each = 15)), y = rnorm(30))
  bbox <- ggbetweenstatsWithPriorNormalityCheck(between, "g", "y", ylab = "Y", plotType = "box")
  expect_true(hidden(geom_data(bbox, "GeomViolin")))

  expect_error(
    ggbetweenstatsWithPriorNormalityCheck(between, "g", "y", ylab = "Y", plotType = "bar"),
    "plotType"
  )
})

test_that("between wrappers no longer run an (ignored) Levene test", {
  local_mocked_bindings(check_homogeneity_by_group = function(...) stop("Levene should not run"))
  between <- data.frame(g = factor(rep(c("A", "B", "C"), each = 15)), y = rnorm(45))
  expect_s3_class(
    ggbetweenstatsWithPriorNormalityCheck(between, "g", "y", ylab = "Y"),
    "ggplot"
  )
  expect_s3_class(
    suppressMessages(ggbetweenstatsWithPriorNormalityCheckAsterisk(between, "g", "y", ylab = "Y",
                                                                   xlabels = c("A", "B", "C"))),
    "ggplot"
  )
})

test_that("a non-parametric test is labelled with medians, a parametric one with means", {
  centrality_labels <- function(p) {
    i <- which(vapply(p$layers, function(l) inherits(l$geom, "GeomLabelRepel"), logical(1)))
    vapply(ggplot2::layer_data(p, i)$label, function(e) paste(deparse(e), collapse = ""), character(1))
  }
  set.seed(3)
  skewed <- data.frame(pid = rep(1:15, 3), cond = factor(rep(c("A", "B", "C"), each = 15)))
  skewed$y <- rexp(45)^3
  np <- ggwithinstatsWithPriorNormalityCheck(skewed, "cond", "y", ylab = "Y", subject = "pid")
  expect_match(ggstatsplot::extract_stats(np)$subtitle_data$method, "Friedman")
  expect_true(all(grepl("median", centrality_labels(np))))

  par <- ggwithinstatsWithPriorNormalityCheck(within_df(), "cond", "y", ylab = "Y", subject = "pid")
  expect_true(all(grepl("mean", centrality_labels(par))))

  skewed_between <- data.frame(g = factor(rep(c("A", "B", "C"), each = 15)), y = rexp(45)^3)
  npb <- ggbetweenstatsWithPriorNormalityCheck(skewed_between, "g", "y", ylab = "Y")
  expect_match(ggstatsplot::extract_stats(npb)$subtitle_data$method, "Kruskal")
  expect_true(all(grepl("median", centrality_labels(npb))))
})


# ---------------------------------------------------------------------------
# Realistic column names and condition codes
# ---------------------------------------------------------------------------

realistic_df <- function() {
  set.seed(5)
  n <- 15
  d <- data.frame(`Participant ID` = rep(seq_len(n), 3), ConditionID = rep(1:3, each = n),
                  check.names = FALSE)
  d$`Mental Demand` <- rnorm(n, 50, 10)[d$`Participant ID`] + 5 * d$ConditionID + rnorm(3 * n, 0, 3)
  d
}

test_that("wrappers accept non-syntactic names and numeric condition codes", {
  d <- realistic_df()

  # Used to fail with "unexpected symbol" (Mental Demand) and "Levene's test is
  # not appropriate with quantitative explanatory variables" (ConditionID 1:3).
  pb <- ggbetweenstatsWithPriorNormalityCheck(d, "ConditionID", "Mental Demand", ylab = "Mental Demand")
  expect_s3_class(pb, "ggplot")
  expect_true(nrow(ggstatsplot::extract_stats(pb)$pairwise_comparisons_data) == 3L)

  pba <- suppressMessages(ggbetweenstatsWithPriorNormalityCheckAsterisk(
    d, "ConditionID", "Mental Demand", ylab = "Mental Demand", xlabels = c("1", "2", "3")
  ))
  expect_s3_class(pba, "ggplot")

  pw <- ggwithinstatsWithPriorNormalityCheck(d, "ConditionID", "Mental Demand",
                                             ylab = "Mental Demand", subject = "Participant ID")
  expect_equal(ggstatsplot::extract_stats(pw)$pairwise_comparisons_data$group1, c("1", "1", "2"))

  pwa <- suppressMessages(ggwithinstatsWithPriorNormalityCheckAsterisk(
    d, "ConditionID", "Mental Demand", ylab = "Mental Demand",
    xlabels = c("1", "2", "3"), subject = "Participant ID"
  ))
  expect_true(has_signif(pwa))

  # The Bayes-factor caption used to vanish silently for a non-syntactic name
  # (BayesFactor cannot rebuild its model frame from "Mental Demand").
  expect_false(is.null(ggstatsplot::extract_stats(pb)$caption_data))
  expect_false(is.null(ggstatsplot::extract_stats(pw)$caption_data))
})

test_that("analyze_and_report handles non-syntactic names and numeric codes", {
  d <- realistic_df()
  res_w <- suppressMessages(analyze_and_report(
    d, dv = "Mental Demand", iv = "ConditionID", design = "within", subject = "Participant ID"
  ))
  expect_s3_class(res_w$plot, "ggplot")
  expect_true(length(res_w$posthoc) > 0)

  # The same numbers read as 45 independent participants
  between <- d
  between$`Participant ID` <- seq_len(nrow(between))
  res_b <- suppressMessages(analyze_and_report(between, dv = "Mental Demand", iv = "ConditionID",
                                               subject = "Participant ID"))
  expect_s3_class(res_b$plot, "ggplot")
})


# ---------------------------------------------------------------------------
# Asterisk brackets with two conditions follow the figure's own test
# ---------------------------------------------------------------------------

test_that("two-group asterisk brackets use the omnibus test shown in the subtitle", {
  # Seeds picked so that the post-hoc machinery and the omnibus test disagree
  # about significance: Mann-Whitney p = .053 vs Dunn p = .0496 (between), and
  # Wilcoxon signed-rank p = .031 vs Durbin-Conover p = .082 (within). The old
  # code drew the post-hoc verdict above a subtitle reporting the other test.
  set.seed(108)
  b <- data.frame(g = factor(rep(c("A", "B"), each = 12)), y = c(rexp(12), rexp(12) + 0.6))
  pb <- suppressMessages(ggbetweenstatsWithPriorNormalityCheckAsterisk(b, "g", "y", ylab = "Y",
                                                                       xlabels = c("A", "B")))
  expect_gt(omnibus(pb)[["p.value"]], 0.05)
  expect_false(has_signif(pb))

  set.seed(14)
  n <- 12
  w <- data.frame(pid = rep(1:n, 2), g = factor(rep(c("A", "B"), each = n)))
  w$y <- rnorm(n)[w$pid] + c(rexp(n), rexp(n) + 0.5)
  pw <- suppressMessages(ggwithinstatsWithPriorNormalityCheckAsterisk(w, "g", "y", ylab = "Y",
                                                                      xlabels = c("A", "B"),
                                                                      subject = "pid"))
  expect_match(ggstatsplot::extract_stats(pw)$subtitle_data$method, "signed rank")
  sig <- Filter(function(l) inherits(l$geom, "GeomSignif"), pw$layers)
  expect_length(sig, 1L)
  expect_identical(sig[[1]]$stat_params$annotations, .p_to_asterisk(omnibus(pw)[["p.value"]]))
})


# ---------------------------------------------------------------------------
# generateEffectPlot
# ---------------------------------------------------------------------------

test_that("generateEffectPlot's main effect is the unweighted mean of cell means", {
  skip_if_not_installed("Hmisc") # the default error bars bootstrap via Hmisc
  # Unbalanced: at x = A the high group has 9 rows, at x = B only 1. The raw
  # marginal means are 9 and 1; the cell means average to 5 and 5.
  df <- data.frame(
    x = rep(c("A", "A", "B", "B"), times = c(9, 1, 1, 9)),
    g = rep(c("high", "low", "high", "low"), times = c(9, 1, 1, 9)),
    y = rep(c(10, 0, 10, 0), times = c(9, 1, 1, 9))
  )
  for (effect in c("main", "interaction")) {
    p <- suppressWarnings(generateEffectPlot(df, "x", "y", "g", shownEffect = effect))
    big <- which(vapply(p$layers, function(l) isTRUE(l$aes_params$size == 6), logical(1)))
    expect_length(big, 1L)
    expect_equal(ggplot2::layer_data(p, big)$y, c(5, 5))
  }
})

test_that("generateEffectPlot warns about the unused numberColors", {
  df <- data.frame(strat = rep(c("A", "B"), each = 10), emotion = rep(c("Happy", "Sad"), 10),
                   score = rnorm(20))
  lifecycle::expect_deprecated(
    generateEffectPlot(df, "strat", "score", "emotion", numberColors = 6)
  )
})

test_that("generateEffectPlot gives Cousineau-Morey intervals with a subject", {
  set.seed(2)
  n <- 12
  d <- expand.grid(pid = factor(1:n), A = c("a1", "a2"), B = c("b1", "b2", "b3"))
  d$y <- rnorm(n, 0, 3)[d$pid] + (d$A == "a2") + as.integer(d$B) * 0.5 + rnorm(nrow(d))

  p <- generateEffectPlot(d, "A", "y", "B", subject = "pid")
  eb <- which(vapply(p$layers, function(l) inherits(l$geom, "GeomErrorbar"), logical(1)))
  ld <- ggplot2::layer_data(p, eb)

  # By hand: normalise, then t-interval with the Morey correction (M = 6).
  norm <- d$y - ave(d$y, d$pid) + mean(d$y)
  cell <- interaction(d$A, d$B)
  half <- tapply(norm, cell, function(v) stats::qt(0.975, length(v) - 1) * sd(v) / sqrt(length(v))) *
    sqrt(6 / 5)
  means <- tapply(d$y, cell, mean)
  expect_equal(sort(ld$ymax - ld$ymin), sort(as.numeric(2 * half)))
  expect_equal(sort((ld$ymax + ld$ymin) / 2), sort(as.numeric(means)))

  # Much narrower than the between-subject interval, which carries the
  # participant spread (sd 3) the within comparison does not depend on.
  between_half <- tapply(d$y, cell, function(v) stats::qt(0.975, length(v) - 1) * sd(v) / sqrt(length(v)))
  expect_true(all(sort(ld$ymax - ld$ymin) < sort(as.numeric(2 * between_half))))

  # Same numbers as afex's within-subject error bars, incl. a mixed design
  skip_if_not_installed("afex")
  fit <- suppressMessages(afex::aov_ez(id = "pid", dv = "y", data = d, within = c("A", "B")))
  ref <- afex::afex_plot(fit, x = "A", trace = "B", error = "within", return = "data")$means
  expect_equal(sort(ld$ymin), sort(as.numeric(ref$lower)))

  mixed <- d[(as.integer(d$pid) %% 3 + 1) == as.integer(d$B), ]
  pm <- generateEffectPlot(mixed, "A", "y", "B", subject = "pid")
  ldm <- ggplot2::layer_data(pm, which(vapply(pm$layers, function(l) inherits(l$geom, "GeomErrorbar"), logical(1))))
  fitm <- suppressMessages(afex::aov_ez(id = "pid", dv = "y", data = mixed, within = "A", between = "B"))
  refm <- suppressWarnings(suppressMessages(
    afex::afex_plot(fitm, x = "A", trace = "B", error = "within", return = "data")
  ))$means
  expect_equal(sort(ldm$ymin), sort(as.numeric(refm$lower)))
})


# ---------------------------------------------------------------------------
# MOBO plots with a factor iteration column
# ---------------------------------------------------------------------------

test_that("generateMoboPlot2 keeps guides and data aligned for a factor x", {
  skip_if_not_installed("Hmisc") # building the plot bootstraps its error bars
  set.seed(1)
  df <- data.frame(
    Iteration = factor(rep(c(10, 20, 30, 40, 50, 60), each = 4)),
    score = rnorm(24),
    ConditionID = rep(c("A", "B"), 12),
    Phase = rep(c("sampling", "optimization"), each = 12)
  )
  p <- generateMoboPlot2(df, x = "Iteration", y = "score")
  layer_of <- function(geom) {
    i <- which(vapply(p$layers, function(l) inherits(l$geom, geom), logical(1)))[1]
    suppressWarnings(ggplot2::layer_data(p, i))
  }
  # Data at the iteration values, not at factor positions 1..6, and the phase
  # boundary between the last sampling (30) and first optimisation (40) step.
  expect_equal(sort(unique(layer_of("GeomPoint")$x)), c(10, 20, 30, 40, 50, 60))
  expect_equal(layer_of("GeomVline")$xintercept, 35)
  expect_equal(range(layer_of("GeomSmooth")$x), c(10, 60))

  expect_error(
    generateMoboPlot2(transform(df, Iteration = paste0("it", Iteration)), x = "Iteration", y = "score"),
    "iteration numbers"
  )
})

test_that("generateMoboPlot counts sampling steps from the first iteration", {
  skip_if_not_installed("Hmisc") # building the plot bootstraps its error bars
  set.seed(1)
  df <- data.frame(
    Iteration = factor(rep(0:9, each = 2)),
    score = rnorm(20),
    ConditionID = rep(c("A", "B"), 10)
  )
  p <- generateMoboPlot(df, x = "Iteration", y = "score", numberSamplingSteps = 5)
  vline <- which(vapply(p$layers, function(l) inherits(l$geom, "GeomVline"), logical(1)))
  # Five sampling iterations are 0..4, so the boundary is at 4.5 (it used to be
  # drawn at 5.5 on a factor axis where level "0" sits at position 1).
  expect_equal(suppressWarnings(ggplot2::layer_data(p, vline))$xintercept, 4.5)
  expect_error(
    generateMoboPlot(df, x = "Iteration", y = "score", numberSamplingSteps = 10),
    "numberSamplingSteps"
  )
})


# ---------------------------------------------------------------------------
# Pipelines
# ---------------------------------------------------------------------------

test_that("analyze_and_report and report_all require `subject` for within designs", {
  d <- within_df()
  expect_error(
    analyze_and_report(d, dv = "y", iv = "cond", design = "within"),
    "`subject` is required"
  )
  expect_error(
    report_all(d, dvs = "y", iv = "cond", design = "within"),
    "`subject` is required"
  )
})

test_that("analyze_and_report pairs by subject and reports on the analysed participants", {
  d <- within_df()
  incomplete <- d[!(d$pid == 7 & d$cond == "B"), ]
  set.seed(4)
  incomplete <- incomplete[sample(nrow(incomplete)), ]

  expect_message(
    res <- analyze_and_report(incomplete, dv = "y", iv = "cond", design = "within", subject = "pid"),
    "dropped 1 of 20 participants"
  )
  ref <- ggwithinstatsWithPriorNormalityCheck(d[d$pid != 7, ], "cond", "y", ylab = "y", subject = "pid")
  expect_equal(omnibus(res$plot), omnibus(ref))
})

test_that("analyze_and_report rejects repeated rows in a between design", {
  d <- within_df()
  expect_error(
    analyze_and_report(d, dv = "y", iv = "cond", design = "between", subject = "pid"),
    "more than one row.*design = \"within\""
  )
})

test_that("analyze_and_report counts groups on the analysed data", {
  set.seed(6)
  d <- data.frame(g = factor(rep(c("A", "B", "C"), each = 10)), y = rnorm(30))
  d$y[d$g == "C"] <- NA
  # Only two groups are analysed, so there is no post-hoc step. The factor
  # still has three levels, which used to send it down the post-hoc path.
  local_mocked_bindings(reportggstatsplotPostHoc = function(...) stop("no post-hoc for two groups"))
  res <- suppressMessages(analyze_and_report(d, dv = "y", iv = "g"))
  expect_null(res$posthoc)
})
