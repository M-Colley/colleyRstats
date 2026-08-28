# The scoring keys are the part of this package that can be wrong without
# anything looking wrong, so they are checked against published reference values
# rather than against whatever the implementation happens to produce.

withr::local_options(colleyRstats.quiet_questionnaires = TRUE, .local_envir = teardown_env())


make_items <- function(values, prefix, n) {
  d <- as.data.frame(matrix(values, ncol = n, byrow = TRUE))
  names(d) <- paste0(prefix, seq_len(n))
  d
}


# -------------------------------------------------------------------------
# Reference values
# -------------------------------------------------------------------------

test_that("SUS reproduces its published anchors", {
  # Odd items positive, even items negative: the best possible answer pattern
  # scores 100, its mirror image 0, and all-neutral 50 (Brooke, 1996).
  d <- make_items(
    c(
      5, 1, 5, 1, 5, 1, 5, 1, 5, 1,
      1, 5, 1, 5, 1, 5, 1, 5, 1, 5,
      3, 3, 3, 3, 3, 3, 3, 3, 3, 3
    ),
    "sus_", 10
  )

  out <- score_questionnaire(d, "sus", prefix = "sus_")

  expect_equal(out$SUS, c(100, 0, 50))
  expect_equal(out$Usability, c(100, 0, 50))
  expect_equal(out$Learnability, c(100, 0, 50))
})


test_that("SSQ applies the Kennedy et al. (1993) weights", {
  # Every symptom at its maximum: each subscale is 7 items x 3 = 21 raw, and
  # the total is formed from the UNWEIGHTED subscale sums.
  d <- make_items(c(rep(3, 16), rep(0, 16)), "ssq", 16)

  out <- score_questionnaire(d, "ssq")

  expect_equal(out$Nausea, c(21 * 9.54, 0))
  expect_equal(out$Oculomotor, c(21 * 7.58, 0))
  expect_equal(out$Disorientation, c(21 * 13.92, 0))
  expect_equal(out$Total, c((21 + 21 + 21) * 3.74, 0))
})


test_that("SSQ subscales each draw on exactly seven items, with the documented overlaps", {
  def <- colleyRstats:::.q_get("ssq")
  members <- colleyRstats:::.q_subscales(def$items$subscale)

  for (s in c("Nausea", "Oculomotor", "Disorientation")) {
    expect_equal(sum(vapply(members, function(m) s %in% m, logical(1))), 7L,
      info = s
    )
  }
  # General discomfort, difficulty focusing, nausea, difficulty concentrating
  # and blurred vision load on two subscales each.
  expect_equal(sum(lengths(members) == 2L), 5L)
})


test_that("raw NASA-TLX rescales any sheet onto 0-100", {
  # The 21-point sheet: 1 is the low anchor, 21 the high one.
  d <- make_items(c(rep(1, 6), rep(11, 6), rep(21, 6)), "tlx", 6)
  names(d) <- colleyRstats:::.q_get("nasa_tlx")$items$code

  out <- score_questionnaire(d, "nasa_tlx", scale = c(1, 21))

  expect_equal(out$RTLX, c(0, 50, 100))
  expect_equal(out$Mental_Demand, c(0, 50, 100))
  # Raw TLX is the unweighted mean, so a mixed profile averages plainly.
  mixed <- as.data.frame(as.list(stats::setNames(c(21, 1, 21, 1, 21, 1), names(d))))
  expect_equal(score_questionnaire(mixed, "nasa_tlx", scale = c(1, 21))$RTLX, 50)
})


test_that("UEQ-S centres its items on zero", {
  d <- make_items(c(rep(7, 8), rep(4, 8), rep(1, 8)), "ueqs", 8)

  out <- score_questionnaire(d, "ueq_s")

  expect_equal(out$Overall, c(3, 0, -3))
  expect_equal(out$Pragmatic_Quality, c(3, 0, -3))
  expect_equal(out$Hedonic_Quality, c(3, 0, -3))
})


test_that("the UEQ's reversed items are the ones that make its polarity balance", {
  # The UEQ prints 13 of its 26 pairs with the positive term on the left. The
  # reverse set is pinned literally below; here we only check the consequence,
  # which is that answering the positive pole of every pair scores +3 on all six
  # scales. Deriving `best` from def$items$reverse would make this a tautology
  # that passes under ANY reverse set, so the pattern is written out.
  positive_pole <- c(
    7, 7, 1, 1, 1, 7, 7, 7, 1, 1, 7, 1, 7,
    7, 7, 7, 1, 1, 1, 7, 1, 7, 1, 1, 1, 7
  )
  d <- make_items(positive_pole, "ueq", 26)

  out <- score_questionnaire(d, "ueq")

  expect_true(all(vapply(out, function(v) isTRUE(all.equal(v, 3)), logical(1))))
})


# -------------------------------------------------------------------------
# Every definition is internally consistent
# -------------------------------------------------------------------------

test_that("every built-in instrument is well formed", {
  for (key in list_questionnaires()$key) {
    def <- colleyRstats:::.q_get(key)

    expect_false(anyDuplicated(def$items$code) > 0, info = key)
    expect_equal(nrow(def$items), length(def$items$label), info = key)
    expect_true(all(nzchar(def$items$subscale)), info = key)
    expect_true(def$scale[1] < def$scale[2], info = key)
    expect_true(def$recode %in% c("none", "center", "zero_base"), info = key)
    expect_true(is.null(def$total) || def$total %in% c("mean", "sum"), info = key)
  }
})


test_that("every instrument scores a midpoint response without error", {
  for (key in list_questionnaires()$key) {
    def <- colleyRstats:::.q_get(key)
    d <- as.data.frame(matrix(mean(def$scale), nrow = 2, ncol = nrow(def$items)))
    names(d) <- def$items$code

    out <- score_questionnaire(d, key, items = def$items$code)

    expect_equal(nrow(out), 2L, info = key)
    expect_true(all(vapply(out, is.numeric, logical(1))), info = key)
    expect_false(anyNA(out), info = key)
  }
})


# The scoring key of an instrument is exactly the kind of thing that can be
# wrong while every structural check still passes: a permuted item order leaves
# the subscale *counts* untouched. These tests therefore pin the actual vectors,
# transcribed from the published scoring keys, so that any change to an item's
# subscale or reversal has to be made deliberately and against a citation.

test_that("SUS key matches Brooke (1996) / Lewis & Sauro (2009)", {
  def <- colleyRstats:::.q_get("sus")
  expect_equal(which(def$items$reverse), c(2L, 4L, 6L, 8L, 10L))
  expect_equal(
    def$items$subscale,
    c(rep("Usability", 3), "Learnability", rep("Usability", 5), "Learnability")
  )
})


test_that("UEQ key matches the UEQ handbook", {
  def <- colleyRstats:::.q_get("ueq")
  expect_equal(
    which(def$items$reverse),
    c(3L, 4L, 5L, 9L, 10L, 12L, 17L, 18L, 19L, 21L, 23L, 24L, 25L)
  )
  expect_equal(which(def$items$subscale == "Attractiveness"), c(1L, 12L, 14L, 16L, 24L, 25L))
  expect_equal(which(def$items$subscale == "Perspicuity"), c(2L, 4L, 13L, 21L))
  expect_equal(which(def$items$subscale == "Efficiency"), c(9L, 20L, 22L, 23L))
  expect_equal(which(def$items$subscale == "Dependability"), c(8L, 11L, 17L, 19L))
  expect_equal(which(def$items$subscale == "Stimulation"), c(5L, 6L, 7L, 18L))
  expect_equal(which(def$items$subscale == "Novelty"), c(3L, 10L, 15L, 26L))
})


test_that("UEQ-S is fixed-polarity, four pragmatic then four hedonic", {
  def <- colleyRstats:::.q_get("ueq_s")
  expect_false(any(def$items$reverse))
  expect_equal(def$items$subscale, c(rep("Pragmatic Quality", 4), rep("Hedonic Quality", 4)))
})


test_that("TiA key matches Koerber's published manual", {
  # Transcribed from Table 1 of TiA_Manual_Eng.pdf and the item order printed in
  # Trust-in-Automation_TiA_questionnaire.pdf, both at
  # github.com/moritzkoerber/TiA_Trust_in_Automation_Questionnaire. The manual
  # states verbatim: "The responses to inverted items (item 5, 7, 10, 15, and
  # 16) must be recoded prior to the analysis".
  def <- colleyRstats:::.q_get("tia")

  expect_equal(which(def$items$reverse), c(5L, 7L, 10L, 15L, 16L))
  expect_equal(which(def$items$subscale == "Reliability/Competence"), c(1L, 6L, 10L, 13L, 15L, 19L))
  expect_equal(which(def$items$subscale == "Understanding/Predictability"), c(2L, 7L, 11L, 16L))
  expect_equal(which(def$items$subscale == "Familiarity"), c(3L, 17L))
  expect_equal(which(def$items$subscale == "Intention of Developers"), c(4L, 8L))
  expect_equal(which(def$items$subscale == "Propensity to Trust"), c(5L, 12L, 18L))
  expect_equal(which(def$items$subscale == "Trust in Automation"), c(9L, 14L))

  # Item wordings that pin the ORDER, which the subscale counts alone cannot.
  expect_match(def$items$label[1], "interpreting situations correctly")
  expect_match(def$items$label[9], "^I trust the system$")
  expect_match(def$items$label[15], "sporadic errors")
  expect_match(def$items$label[19], "confident about the system")

  # Answering the trusting pole of every item scores the maximum everywhere.
  d <- as.data.frame(matrix(ifelse(def$items$reverse, 1, 5), nrow = 1))
  names(d) <- def$items$code
  expect_true(all(unlist(score_questionnaire(d, "tia", items = def$items$code)) == 5))
})


test_that("IPQ key matches the igroup scoring syntax", {
  # igroup.org publishes "compute sp2u = -1 * sp2 + 6" and the same for inv3 and
  # real1: those three are the inverted items. SP3 and INV1 sound negative but
  # carry pre-flipped anchors on the published form, so they are NOT inverted.
  def <- colleyRstats:::.q_get("ipq")

  expect_equal(which(def$items$reverse), c(3L, 9L, 11L))
  expect_equal(def$items$code[c(3L, 9L, 11L)], c("sp2", "inv3", "real1"))
  expect_match(def$items$label[11], "How real did the virtual world seem")
  expect_match(def$items$label[12], "consistent")
})


test_that("SSQ item-to-subscale map matches Kennedy et al. (1993)", {
  def <- colleyRstats:::.q_get("ssq")
  members <- colleyRstats:::.q_subscales(def$items$subscale)
  on_scale <- function(s) which(vapply(members, function(m) s %in% m, logical(1)))

  expect_equal(on_scale("Nausea"), c(1L, 6L, 7L, 8L, 9L, 15L, 16L))
  expect_equal(on_scale("Oculomotor"), c(1L, 2L, 3L, 4L, 5L, 9L, 11L))
  expect_equal(on_scale("Disorientation"), c(5L, 8L, 10L, 11L, 12L, 13L, 14L))
})


test_that("NASA-TLX has six unreversed dimensions in sheet order", {
  def <- colleyRstats:::.q_get("nasa_tlx")
  expect_false(any(def$items$reverse))
  expect_equal(
    def$items$subscale,
    c("Mental Demand", "Physical Demand", "Temporal Demand", "Performance", "Effort", "Frustration")
  )
})


test_that("subscale counts match the published structure", {
  expect_equal(nrow(colleyRstats:::.q_get("tia")$items), 19L)

  ipq <- colleyRstats:::.q_get("ipq")
  expect_equal(nrow(ipq$items), 14L)
  expect_equal(
    as.vector(table(ipq$items$subscale)[
      c("Experienced Realism", "General Presence", "Involvement", "Spatial Presence")
    ]),
    c(4L, 1L, 4L, 5L)
  )

  ad <- colleyRstats:::.q_get("attrakdiff")
  expect_equal(nrow(ad$items), 28L)
  expect_true(all(table(ad$items$subscale) == 7L))
})


# -------------------------------------------------------------------------
# Column resolution
# -------------------------------------------------------------------------

test_that("a prefix selects item columns in numeric, not lexical, order", {
  # sus_10 sorts before sus_2 lexically. Mapping in that order would score five
  # of the ten items against the wrong scoring key, silently.
  d <- make_items(rep(3, 10), "sus_", 10)
  d <- d[, order(names(d))] # sus_1, sus_10, sus_2, ...

  mapping <- attr(score_questionnaire(d, "sus", prefix = "sus_"), "mapping")

  expect_equal(mapping$column, paste0("sus_", 1:10))
})


test_that("a named items mapping is order-proof", {
  d <- data.frame(b = 5, a = 1, c = 3)
  define_questionnaire(
    key = "tiny", name = "Tiny scale", scale = c(1, 5),
    subscale = c("S", "S", "S"), code = c("i1", "i2", "i3")
  )
  on.exit(rm("tiny", envir = colleyRstats:::.q_user), add = TRUE)

  out <- score_questionnaire(d, "tiny", items = c(i1 = "a", i2 = "b", i3 = "c"))

  expect_equal(attr(out, "mapping")$column, c("a", "b", "c"))
  expect_equal(out$S, 3)
})


test_that("column resolution fails loudly rather than scoring the wrong columns", {
  d <- make_items(rep(3, 8), "sus_", 8)

  expect_error(score_questionnaire(d, "sus", prefix = "sus_"), "matches 8 columns")
  expect_error(score_questionnaire(d, "sus", items = names(d)), "has 10 items")
  expect_error(score_questionnaire(d, "sus"), "Could not find")
  expect_error(score_questionnaire(d, "nope"), "Unknown questionnaire")
})


test_that("out-of-range responses stop rather than being rescaled silently", {
  # A 1-7 export scored as if it were the 0-100 TLX would otherwise pass.
  d <- make_items(rep(7, 6), "x", 6)
  names(d) <- colleyRstats:::.q_get("nasa_tlx")$items$code

  expect_error(
    score_questionnaire(d, "nasa_tlx", scale = c(1, 5)),
    "outside the assumed response range"
  )
  expect_silent(score_questionnaire(d, "nasa_tlx", scale = c(1, 7), verbose = FALSE))
})


# -------------------------------------------------------------------------
# Reverse coding
# -------------------------------------------------------------------------

test_that("reverse_items toggles rather than sets", {
  d <- make_items(c(5, 1, 5, 1, 5, 1, 5, 1, 5, 1), "sus_", 10)

  # Un-reversing all five negatively worded items must undo the scoring key.
  out <- score_questionnaire(d, "sus", prefix = "sus_", reverse_items = c(2, 4, 6, 8, 10))
  expect_equal(out$SUS, 50)

  reversed <- attr(out, "mapping")$reverse
  expect_false(any(reversed))
})


test_that("reverse_code uses the stated scale, not the observed one", {
  expect_equal(reverse_code(c(1, 3, 5, NA), 1, 5), c(5, 3, 1, NA))
  # Nobody answered 1, but the flip must still be about the possible range.
  expect_equal(reverse_code(c(3, 4, 5), 1, 5), c(3, 2, 1))
  expect_error(reverse_code(1:5, 5, 1), "min < max")
  expect_warning(reverse_code(c(1, 9), 1, 5), "outside the stated scale")
})


# -------------------------------------------------------------------------
# Missing data
# -------------------------------------------------------------------------

test_that("min_valid governs whether an incomplete subscale is scored", {
  d <- make_items(c(5, 1, 5, 1, 5, 1, 5, 1, 5, 1), "sus_", 10)
  d$sus_3 <- NA

  strict <- score_questionnaire(d, "sus", prefix = "sus_")
  expect_true(is.na(strict$SUS))

  # Relaxed: the sum is scaled up proportionally, so the score stays on 0-100.
  relaxed <- score_questionnaire(d, "sus", prefix = "sus_", min_valid = 0.8)
  expect_equal(relaxed$SUS, 100)
  expect_false(is.na(relaxed$Learnability))
})


# -------------------------------------------------------------------------
# Reliability
# -------------------------------------------------------------------------

test_that("alpha is computed on the reverse-coded items", {
  set.seed(11)
  trait <- rnorm(80)
  d <- as.data.frame(lapply(1:10, function(i) round(pmin(pmax(3 + trait + rnorm(80, sd = 0.4), 1), 5))))
  names(d) <- paste0("sus_", 1:10)
  # Make the even items negatively worded, as they are on the real SUS.
  neg <- paste0("sus_", c(2, 4, 6, 8, 10))
  d[neg] <- 6 - d[neg]

  rel <- score_reliability(d, "sus", prefix = "sus_")

  expect_true(all(rel$alpha > 0.7))
  expect_equal(rel$n_items, c(8L, 2L))
})


test_that("a forgotten reversal shows up as a negative alpha, with a warning", {
  set.seed(12)
  trait <- rnorm(60)
  d <- as.data.frame(lapply(1:10, function(i) round(pmin(pmax(3 + trait + rnorm(60, sd = 0.3), 1), 5))))
  names(d) <- paste0("sus_", 1:10)
  # All ten items point the same way, so applying the SUS key to them makes half
  # of them oppose the other half.
  expect_warning(rel <- score_reliability(d, "sus", prefix = "sus_"), "do not point the same way")
  expect_true(rel$alpha[rel$subscale == "Usability"] < 0)
})


# -------------------------------------------------------------------------
# Registration and inspection
# -------------------------------------------------------------------------

test_that("define_questionnaire registers a scorable instrument", {
  define_questionnaire(
    key = "vdl", name = "Van der Laan acceptance", scale = c(-2, 2),
    subscale = rep(c("Usefulness", "Satisfying"), length.out = 9),
    reverse = c(1, 2, 4, 5, 7, 9), total_name = "Acceptance"
  )
  on.exit(rm("vdl", envir = colleyRstats:::.q_user), add = TRUE)

  expect_true("vdl" %in% list_questionnaires()$key)

  d <- as.data.frame(matrix(0, nrow = 1, ncol = 9))
  names(d) <- paste0("item", 1:9)
  out <- score_questionnaire(d, "vdl")

  expect_equal(out$Usefulness, 0)
  expect_named(out, c("Usefulness", "Satisfying"))
})


test_that("define_questionnaire validates its inputs", {
  expect_error(
    define_questionnaire("x", "X", scale = c(5, 1), subscale = "a"),
    "increasing"
  )
  expect_error(
    define_questionnaire("x", "X", scale = c(1, 5), subscale = "a", total = "median"),
    "must be"
  )
})


test_that("check_questionnaire reports the mapping it would use", {
  d <- make_items(rep(3, 10), "sus_", 10)

  expect_message(check_questionnaire(d, "sus", prefix = "sus_"), "System Usability Scale")
  out <- suppressMessages(check_questionnaire(d, "sus", prefix = "sus_"))

  expect_equal(nrow(out), 10L)
  expect_equal(out$reverse, seq_len(10) %in% c(2, 4, 6, 8, 10))
  expect_true(all(out$observed_min == 3))
  expect_true(all(out$n_missing == 0))
})


test_that("list_questionnaires and questionnaire_items describe the registry", {
  reg <- list_questionnaires()

  expect_true(all(c("sus", "nasa_tlx", "ueq_s", "tia", "ssq", "ipq") %in% reg$key))
  expect_equal(reg$n_items[reg$key == "sus"], 10L)

  items <- suppressMessages(questionnaire_items("ueq_s"))
  expect_equal(nrow(items), 8L)
  expect_equal(unique(items$subscale), c("Pragmatic Quality", "Hedonic Quality"))
})


# -------------------------------------------------------------------------
# Sickness time courses
# -------------------------------------------------------------------------

test_that("summarize_sickness reduces a time course to the usual measures", {
  d <- data.frame(
    pid = rep(c("p1", "p2"), each = 5),
    minute = rep(0:4, 2),
    fms = c(0, 1, 3, 6, 8, 0, 0, 1, 1, 2)
  )

  out <- summarize_sickness(d, value = "fms", id = "pid", time = "minute", threshold = 5)

  expect_equal(out$peak, c(8, 2))
  expect_equal(out$final, c(8, 2))
  expect_equal(out$mean, c(3.6, 0.8))
  # Trapezoidal: 0.5 + 2 + 4.5 + 7 = 14 over four minutes.
  expect_equal(out$auc, c(14, 3))
  expect_equal(out$auc_rate, c(3.5, 0.75))
  expect_equal(out$reached, c(TRUE, FALSE))
  expect_equal(out$time_to_threshold, c(3, NA))
})


test_that("summarize_sickness orders by time, not by row order", {
  shuffled <- data.frame(
    pid = "p1",
    minute = c(4, 0, 2, 1, 3),
    fms = c(8, 0, 3, 1, 6)
  )

  out <- summarize_sickness(shuffled, value = "fms", id = "pid", time = "minute")

  expect_equal(out$auc, 14)
  expect_equal(out$final, 8)
})


test_that("summarize_sickness splits by condition when asked", {
  d <- data.frame(
    pid = rep(c("p1", "p2"), each = 4),
    cond = rep(c("a", "b"), each = 2, times = 2),
    minute = rep(0:1, 4),
    misc = c(0, 2, 0, 5, 1, 1, 0, 8)
  )

  out <- summarize_sickness(d, value = "misc", id = "pid", time = "minute", by = "cond")

  expect_equal(nrow(out), 4L)
  expect_equal(out$peak, c(2, 5, 1, 8))
})


# -------------------------------------------------------------------------
# Regressions
# -------------------------------------------------------------------------

test_that("a named items mapping is honoured, not silently applied positionally", {
  # as.character() drops names; coercing before testing names(items) once made
  # the whole named branch unreachable, so a named vector written in any order
  # was scored in the order it happened to be typed.
  tlx <- data.frame(a = 90, b = 80, c = 70, d = 60, e = 50, f = 40)

  out <- score_questionnaire(tlx, "nasa_tlx", items = c(
    frustration = "f", mental = "a", effort = "e",
    physical = "b", performance = "d", temporal = "c"
  ))

  expect_equal(out$Mental_Demand, 90)
  expect_equal(out$Physical_Demand, 80)
  expect_equal(out$Temporal_Demand, 70)
  expect_equal(out$Performance, 60)
  expect_equal(out$Effort, 50)
  expect_equal(out$Frustration, 40)
})


test_that("factor item columns are read by label, not by level index", {
  # factor(c("3","1","2")) has "3" at position 1. Reading the position would
  # score a 3 as a 1, differently in every column, and silently.
  d <- make_items(rep(3, 10), "sus_", 10)
  d$sus_1 <- factor("3", levels = c("3", "1", "2"))

  expect_equal(score_questionnaire(d, "sus", prefix = "sus_")$SUS, 50)

  # An ordered factor's level order IS the response order, so it may be used.
  d$sus_1 <- factor("3", levels = as.character(1:5), ordered = TRUE)
  expect_equal(score_questionnaire(d, "sus", prefix = "sus_")$SUS, 50)

  # An unordered factor of text labels is a guess, and is refused.
  d$sus_1 <- factor("agree", levels = c("agree", "disagree"))
  expect_error(score_questionnaire(d, "sus", prefix = "sus_"), "level order is collation order")
})


test_that("the item index need not be the last thing in a column name", {
  # LimeSurvey and Qualtrics both emit indices with a suffix after them.
  expect_equal(
    colleyRstats:::.natural_order(c("SUS[1]", "SUS[10]", "SUS[2]")),
    c(1L, 3L, 2L)
  )
  expect_equal(
    colleyRstats:::.natural_order(c("q1_1_TEXT", "q1_10_TEXT", "q1_2_TEXT")),
    c(1L, 3L, 2L)
  )
})


test_that("prefix is matched literally, not as a regular expression", {
  d <- make_items(rep(3, 10), "SUS[", 10)
  names(d) <- paste0("SUS[", 1:10, "]")

  expect_equal(score_questionnaire(d, "sus", prefix = "SUS[")$SUS, 50)
})


test_that("an unanswered column reports NA rather than Inf in the mapping table", {
  d <- make_items(rep(3, 20), "sus_", 10)
  d$sus_4 <- NA

  out <- suppressWarnings(suppressMessages(check_questionnaire(d, "sus", prefix = "sus_")))

  expect_true(is.na(out$observed_min[4]))
  expect_true(is.na(out$observed_max[4]))
  expect_equal(out$n_missing[4], 2L)
})


test_that("define_questionnaire rejects names that would collide in the output", {
  expect_error(
    define_questionnaire("clash1", "C", scale = c(1, 5), subscale = c("A B", "A-B")),
    "resolve to the same score column"
  )
  expect_error(
    define_questionnaire(
      "clash2", "C",
      scale = c(1, 5), subscale = c("Total", "Other"), total = "mean"
    ),
    "would be overwritten"
  )
  expect_error(
    define_questionnaire("clash3", "C", scale = c(1, 5), subscale = c("A", "B"), code = "one"),
    "one entry per item"
  )
  expect_error(
    define_questionnaire("clash4", "C", scale = c(1, 5), subscale = c("A", "B"), code = c("x", "x")),
    "must be unique"
  )
})


test_that("the mapping is announced again when it changes within a session", {
  withr::local_options(colleyRstats.quiet_questionnaires = FALSE)
  announced <- colleyRstats:::.q_announced
  suppressWarnings(rm(list = "sus", envir = announced))
  d <- make_items(rep(3, 10), "sus_", 10)

  expect_message(score_questionnaire(d, "sus", prefix = "sus_"), "System Usability Scale")
  # Same mapping: already said.
  expect_silent(score_questionnaire(d, "sus", prefix = "sus_"))
  # Different reversal: the whole point of the message is to surface this.
  expect_message(
    score_questionnaire(d, "sus", prefix = "sus_", reverse_items = c(1, 3)),
    "reverse-coded"
  )
})


test_that("summarize_sickness reads factor ratings by label", {
  d <- data.frame(
    pid = "p1", minute = 0:4,
    fms = factor(c("0", "1", "3", "6", "8"), levels = c("0", "1", "3", "6", "8"))
  )

  out <- summarize_sickness(d, value = "fms", id = "pid", time = "minute", threshold = 5)

  expect_equal(out$peak, 8)
  expect_equal(out$auc, 14)
  expect_equal(out$time_to_threshold, 3)
})


test_that("summarize_sickness reports reached = NA when nothing was measured", {
  d <- data.frame(pid = rep(c("p1", "p2"), each = 3), minute = rep(0:2, 2),
                  fms = c(NA, NA, NA, 0, 3, 7))

  out <- summarize_sickness(d, value = "fms", id = "pid", time = "minute", threshold = 5)

  # FALSE would count the unmeasured participant as a confirmed non-case.
  expect_true(is.na(out$reached[out$pid == "p1"]))
  expect_true(out$reached[out$pid == "p2"])
})


test_that("the administration caution reaches the console, not only the docs", {
  withr::local_options(colleyRstats.quiet_questionnaires = FALSE)
  d <- make_items(rep(3, 10), "sus_", 10)

  # Scoring: shown with the mapping, the first time each mapping is used.
  suppressWarnings(rm(list = "sus", envir = colleyRstats:::.q_announced))
  expect_message(score_questionnaire(d, "sus", prefix = "sus_"), "CAUTION")
  expect_message(
    {
      suppressWarnings(rm(list = "sus", envir = colleyRstats:::.q_announced))
      score_questionnaire(d, "sus", prefix = "sus_")
    },
    "double-check any number before it goes into a paper"
  )

  # Verification and the item list say it too.
  expect_message(check_questionnaire(d, "sus", prefix = "sus_"), "CAUTION")
  expect_message(questionnaire_items("sus"), "CAUTION")

  # Reliability is derived from the same mapping, so it carries the same caveat.
  suppressWarnings(rm(list = "sus", envir = colleyRstats:::.q_announced))
  expect_message(score_reliability(d, "sus", prefix = "sus_"), "CAUTION")
})


test_that("the caution is one text, so the wording cannot drift", {
  caution <- colleyRstats:::.q_caution()

  expect_true(any(grepl("^CAUTION", caution)))
  expect_true(any(grepl("renumber", caution)))
  expect_true(any(grepl("double-check", caution)))
})


test_that("a pipeline can silence the note without silencing errors", {
  withr::local_options(colleyRstats.quiet_questionnaires = TRUE)
  d <- make_items(rep(3, 10), "sus_", 10)
  suppressWarnings(rm(list = "sus", envir = colleyRstats:::.q_announced))

  expect_silent(score_questionnaire(d, "sus", prefix = "sus_"))
  # The option quiets a note, not a real problem.
  d$sus_1 <- 99
  expect_error(score_questionnaire(d, "sus", prefix = "sus_"), "outside the assumed response range")
})
