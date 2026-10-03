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
    # floor(): the SSQ's 0-3 has no 1.5, and a fractional response would warn.
    d <- as.data.frame(matrix(floor(mean(def$scale)), nrow = 2, ncol = nrow(def$items)))
    names(d) <- def$items$code

    out <- expect_no_warning(score_questionnaire(d, key, items = def$items$code))

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

  ado <- colleyRstats:::.q_get("attrakdiff_official")
  expect_equal(nrow(ado$items), 28L)
  expect_true(all(table(ado$items$subscale) == 7L))
})


test_that("attrakdiff_official reproduces the administered sheet", {
  # Order, dimensions and the 15 positive-left pairs as printed on the form;
  # Lallemand et al. (2015) reverse exactly QP_1, ATT_1, QHS_1, QP_2, QHI_2,
  # QP_3, ATT_3, QHI_3, QP_5, QHI_6, ATT_5, QHS_3, QHS_4, ATT_7, QHS_7.
  def <- colleyRstats:::.q_get("attrakdiff_official")

  expect_equal(
    which(def$items$reverse),
    c(1L, 3L, 4L, 5L, 6L, 8L, 9L, 11L, 12L, 15L, 19L, 22L, 23L, 26L, 27L)
  )
  expect_equal(
    def$items$code[def$items$reverse],
    c(
      "pq1", "att1", "hqs1", "pq2", "hqi2", "pq3", "att3", "hqi3", "pq5", "hqi6",
      "att5", "hqs3", "hqs4", "att7", "hqs7"
    )
  )
  expect_equal(which(def$items$subscale == "Pragmatic Quality"), c(1L, 5L, 8L, 10L, 12L, 20L, 28L))
  expect_equal(which(def$items$subscale == "Hedonic Quality - Identity"), c(2L, 6L, 11L, 13L, 14L, 15L, 16L))
  expect_equal(which(def$items$subscale == "Hedonic Quality - Stimulation"), c(4L, 18L, 22L, 23L, 24L, 25L, 27L))
  expect_equal(which(def$items$subscale == "Attractiveness"), c(3L, 7L, 9L, 17L, 19L, 21L, 26L))
  expect_equal(def$items$label[c(1, 15, 28)], c(
    "human - technical", "brings me closer to people - separates me from people",
    "unruly - manageable"
  ))

  # Answering the positive term of every pair -- written out, not derived from
  # def$items$reverse, which would make this pass under any reverse set.
  positive_pole <- c(
    1, 7, 1, 1, 1, 1, 7, 1, 1, 7, 1, 1, 7, 7,
    1, 7, 7, 7, 1, 7, 7, 1, 1, 7, 7, 1, 1, 7
  )
  d <- make_items(positive_pole, "ad", 28)
  out <- score_questionnaire(d, "attrakdiff_official", items = names(d))
  expect_true(all(vapply(out, function(v) isTRUE(all.equal(v, 3)), logical(1))))
})


test_that("the two AttrakDiff keys share codes, so they name the same word pairs", {
  blocked <- colleyRstats:::.q_get("attrakdiff")
  official <- colleyRstats:::.q_get("attrakdiff_official")

  expect_setequal(blocked$items$code, official$items$code)
  m <- match(official$items$code, blocked$items$code)
  expect_equal(official$items$subscale, blocked$items$subscale[m])
  # Same pair, poles possibly swapped: the two words agree as a set.
  words <- function(x) lapply(strsplit(x, " - ", fixed = TRUE), sort)
  expect_equal(words(official$items$label), words(blocked$items$label[m]))
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

test_that("reverse_items still toggles, but warns when it un-reverses the key", {
  d <- make_items(c(5, 1, 5, 1, 5, 1, 5, 1, 5, 1), "sus_", 10)

  # Passing the SUS's own reverse set, as tutorials do, un-reverses all five
  # negatively worded items: a perfect respondent scores 50. Kept for backward
  # compatibility, but no longer behind a suppressible note -- it is a warning.
  expect_warning(
    out <- score_questionnaire(d, "sus", prefix = "sus_", reverse_items = c(2, 4, 6, 8, 10)),
    "exactly the items the published key"
  )
  expect_equal(out$SUS, 50)
  expect_false(any(attr(out, "mapping")$reverse))

  # Reversing an item the key leaves alone is the documented use: no warning.
  expect_no_warning(score_questionnaire(d, "sus", prefix = "sus_", reverse_items = 1))
})


test_that("unreverse_items undoes a key reversal on purpose, without a warning", {
  d <- make_items(c(5, 1, 5, 1, 5, 1, 5, 1, 5, 1), "sus_", 10)

  out <- expect_no_warning(
    score_questionnaire(d, "sus", prefix = "sus_", unreverse_items = c("sus2", "sus4"))
  )
  expect_equal(which(attr(out, "mapping")$reverse), c(6L, 8L, 10L))
  # Items 2 and 4 (raw 1) now count as 0 instead of 4: 100 - 2 * 4 * 2.5.
  expect_equal(out$SUS, 80)

  expect_error(
    score_questionnaire(d, "sus", prefix = "sus_", unreverse_items = 1),
    "does not reverse"
  )
  expect_error(
    score_questionnaire(d, "sus", prefix = "sus_", reverse_items = 2, unreverse_items = 2),
    "cannot be in both"
  )
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

  # Relaxed: the SUS follows Brooke (1996) -- a missing item is marked at the
  # centre point (2 of 4 after zero-basing) -- so the score stays on 0-100.
  relaxed <- score_questionnaire(d, "sus", prefix = "sus_", min_valid = 0.8)
  expect_equal(relaxed$SUS, (9 * 4 + 2) * 2.5)
  expect_false(is.na(relaxed$Learnability))
})


test_that("a missing SUS item is scored at the centre, as Brooke (1996) instructs", {
  # One missing item 10 in an otherwise perfect response: 95 under Brooke's
  # rule, where the old mean-imputation gave 100.
  d <- make_items(c(5, 1, 5, 1, 5, 1, 5, 1, 5, 1), "sus_", 10)
  d$sus_10 <- NA

  out <- score_questionnaire(d, "sus", prefix = "sus_", min_valid = 0.9)
  expect_equal(out$SUS, 95)

  # Proration remains available on request, and scales the sum back up.
  prorated <- score_questionnaire(d, "sus", prefix = "sus_", min_valid = 0.9, impute = "prorate")
  expect_equal(prorated$SUS, 100)

  # Learnability (items 4 and 10) with one of two items: the centre fills in.
  half <- score_questionnaire(d, "sus", prefix = "sus_", min_valid = 0.5)
  expect_equal(half$Learnability, (4 + 2) * 12.5)
})


test_that("impute applies to every instrument, and defaults to proration elsewhere", {
  d <- make_items(c(7, 7, 7, NA, 7, 7, 7, 7), "ueqs", 8)

  # UEQ-S has no published missing-item rule: the mean of the items present.
  expect_equal(score_questionnaire(d, "ueq_s", min_valid = 0.5)$Pragmatic_Quality, 3)
  # The centre of a centred 1-7 scale is 0.
  expect_equal(
    score_questionnaire(d, "ueq_s", min_valid = 0.5, impute = "midpoint")$Pragmatic_Quality,
    9 / 4
  )
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
  expect_equal(rel$n_items, c(8L, 2L, 10L))
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
  expect_equal(colleyRstats:::.q_item_index(c("1]", "10]", "2]")), c(1, 10, 2))
  expect_equal(colleyRstats:::.q_item_index(c("1_TEXT", "10_TEXT", "2_TEXT")), c(1, 10, 2))

  best <- c(5, 1, 5, 1, 5, 1, 5, 1, 5, 1)
  d <- as.data.frame(as.list(best))
  names(d) <- paste0("q1_", 1:10, "_TEXT")
  d <- d[order(names(d))] # q1_1_TEXT, q1_10_TEXT, q1_2_TEXT, ...
  expect_equal(score_questionnaire(d, "sus", prefix = "q1_")$SUS, 100)
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


# -------------------------------------------------------------------------
# Regressions: a prefix maps columns by name, never by sort order
# -------------------------------------------------------------------------

test_that("prefixed NASA-TLX columns are matched by dimension name", {
  # Sorted, tlx_effort comes first and used to fill Mental Demand.
  tlx <- data.frame(
    tlx_mental = 10, tlx_physical = 20, tlx_temporal = 30,
    tlx_performance = 40, tlx_effort = 50, tlx_frustration = 60
  )
  out <- score_questionnaire(tlx, "nasa_tlx", prefix = "tlx_")
  expect_equal(unlist(out[1, 1:6], use.names = FALSE), c(10, 20, 30, 40, 50, 60))
  expect_equal(attr(out, "mapping")$column, names(tlx))

  # The labels work too, without regard to case or punctuation.
  names(tlx) <- c(
    "TLX_Mental_Demand", "TLX_physical demand", "TLX_Temporal.Demand",
    "TLX_Performance", "TLX_EFFORT", "TLX_frustration"
  )
  out <- score_questionnaire(tlx[rev(names(tlx))], "nasa_tlx", prefix = "TLX_")
  expect_equal(out$Mental_Demand, 10)
  expect_equal(out$Frustration, 60)
})


test_that("prefixed TiA columns are matched by item code, so reversals land right", {
  def <- colleyRstats:::.q_get("tia")
  # The most trusting answer to every item: 1 on the five inverted items.
  d <- as.data.frame(as.list(ifelse(def$items$reverse, 1, 5)))
  names(d) <- paste0("tia_", def$items$code)

  out <- score_questionnaire(d, "tia", prefix = "tia_")

  # Sorted by name the reversals fell on the wrong items: R/C scored 3.67.
  expect_true(all(unlist(out) == 5))
})


test_that("prefixed IPQ columns are matched by item code", {
  def <- colleyRstats:::.q_get("ipq")
  d <- as.data.frame(as.list(ifelse(def$items$reverse, 0, 6)))
  names(d) <- paste0("ipq_", def$items$code)

  out <- score_questionnaire(d, "ipq", prefix = "ipq_")

  # Sorted by name, Spatial Presence scored 2.4 instead of 6.
  expect_equal(out$Spatial_Presence, 6)
  expect_true(all(unlist(out) == 6))
})


test_that("prefixed AttrakDiff columns keep PQ and ATT apart", {
  def <- colleyRstats:::.q_get("attrakdiff")
  values <- c(pq = 7, hqi = 6, hqs = 2, att = 1)[sub("[0-9]+$", "", def$items$code)]
  d <- as.data.frame(as.list(unname(values)))
  names(d) <- paste0("ad_", def$items$code)

  out <- score_questionnaire(d, "attrakdiff", prefix = "ad_")

  # Sorted, the att* columns filled Pragmatic Quality and the pq* ones
  # Attractiveness.
  expect_equal(out$Pragmatic_Quality, 3)
  expect_equal(out$Hedonic_Quality_Identity, 2)
  expect_equal(out$Hedonic_Quality_Stimulation, -2)
  expect_equal(out$Attractiveness, -3)
})


test_that("an export numbering every column SUS_<item>_1 maps by the item number", {
  d <- as.data.frame(as.list(c(5, 1, 5, 1, 5, 1, 5, 1, 5, 1)))
  names(d) <- paste0("SUS_", 1:10, "_1")
  d <- d[order(names(d))] # SUS_1_1, SUS_10_1, SUS_2_1, ...

  out <- score_questionnaire(d, "sus", prefix = "SUS_")

  # Sorted 1, 10, 2, ... this scored 20.
  expect_equal(out$SUS, 100)
  expect_equal(attr(out, "mapping")$column, paste0("SUS_", 1:10, "_1"))
})


test_that("a prefix whose names do not identify the items is an error, not a guess", {
  sus0 <- as.data.frame(as.list(rep(3, 10)))
  names(sus0) <- paste0("sus_", 0:9)
  expect_error(score_questionnaire(sus0, "sus", prefix = "sus_"), "rather than 1-10")

  tlx <- data.frame(
    tlx_mental = 10, tlx_phys = 20, tlx_temp = 30,
    tlx_perf = 40, tlx_effort = 50, tlx_frust = 60
  )
  expect_error(score_questionnaire(tlx, "nasa_tlx", prefix = "tlx_"), "only some of them name an item")

  # Two numbers that both vary (item x condition) leave the item ambiguous.
  define_questionnaire("grid4", "Grid", scale = c(1, 5), subscale = rep("S", 4))
  on.exit(rm("grid4", envir = colleyRstats:::.q_user), add = TRUE)
  g <- data.frame(x1_1 = 3, x1_2 = 3, x2_1 = 3, x2_2 = 3)
  expect_error(score_questionnaire(g, "grid4", prefix = "x"), "Pass `items` named by item code")
})


test_that("one column cannot be given for several items", {
  d <- make_items(rep(3, 10), "sus_", 10)

  expect_error(score_questionnaire(d, "sus", items = rep("sus_1", 10)), "its own column")
  named <- stats::setNames(c(rep("sus_1", 2), paste0("sus_", 3:10)), paste0("sus", 1:10))
  expect_error(score_questionnaire(d, "sus", items = named), "its own column")
  expect_error(
    score_questionnaire(d, "sus", items = c(stats::setNames(paste0("sus_", 1:10), paste0("sus", 1:10)), extra = "x")),
    "not an item code"
  )

  # Partly named used to fall back to position, ignoring the names given.
  part <- paste0("sus_", c(2, 1, 3:10))
  names(part) <- c("sus2", "sus1", rep("", 8))
  expect_error(score_questionnaire(d, "sus", items = part), "partly named")
  twice <- stats::setNames(paste0("sus_", c(1:10, 1)), c(paste0("sus", 1:10), "sus1"))
  expect_error(score_questionnaire(d, "sus", items = twice), "more than once")
})


# -------------------------------------------------------------------------
# Regressions: text is refused, not silently dropped
# -------------------------------------------------------------------------

test_that("text responses stop scoring instead of becoming NA", {
  d <- make_items(c(5, 1, 5, 1, 5, 1, 5, 1, 5, 1), "sus_", 10)

  d$sus_3 <- "Strongly agree"
  # With min_valid = 0.8 this used to score the row over the other nine items.
  expect_error(
    score_questionnaire(d, "sus", prefix = "sus_", min_valid = 0.8),
    "'Strongly agree'"
  )

  d$sus_3 <- "5 - Strongly agree"
  expect_error(score_questionnaire(d, "sus", prefix = "sus_"), "followed by its label")

  d$sus_3 <- "2,5"
  expect_error(score_questionnaire(d, "sus", prefix = "sus_"), "decimal commas")

  # Numbers stored as text, padded or blank, are fine: a blank is missing.
  d$sus_3 <- " 5 "
  expect_equal(score_questionnaire(d, "sus", prefix = "sus_")$SUS, 100)
  d$sus_3 <- ""
  expect_true(is.na(score_questionnaire(d, "sus", prefix = "sus_")$SUS))
})


test_that("check_questionnaire reports an unreadable column instead of hiding it", {
  d <- make_items(rep(3, 10), "sus_", 10)
  d$sus_2 <- "agree"

  expect_warning(
    out <- suppressMessages(check_questionnaire(d, "sus", prefix = "sus_")),
    "not numbers"
  )
  expect_true(is.na(out$observed_min[2]))
})


test_that("summarize_sickness refuses text ratings rather than dropping them", {
  d <- data.frame(pid = "p1", minute = 0:2, fms = c("0", "moderate", "5"))
  expect_error(
    summarize_sickness(d, value = "fms", id = "pid", time = "minute"),
    "'moderate'"
  )
})


test_that("fractional responses on a whole-point instrument warn", {
  d <- make_items(c(5, 1, 5, 1, 5, 1, 5, 1, 5, 1), "sus_", 10)
  d$sus_1 <- 4.5
  expect_warning(score_questionnaire(d, "sus", prefix = "sus_"), "fractional values")

  # A 0-100 rating scale is not a whole-point format.
  tlx <- data.frame(
    mental = 47.5, physical = 30, temporal = 60,
    performance = 25, effort = 55, frustration = 40
  )
  expect_no_warning(score_questionnaire(tlx, "nasa_tlx"))

  define_questionnaire("vas2", "VAS", scale = c(0, 10), subscale = c("S", "S"), integer_responses = FALSE)
  on.exit(rm("vas2", envir = colleyRstats:::.q_user), add = TRUE)
  expect_no_warning(score_questionnaire(data.frame(item1 = 2.5, item2 = 7.25), "vas2"))
})


# -------------------------------------------------------------------------
# Regressions: a coding that fits the range but looks shifted
# -------------------------------------------------------------------------

test_that("NASA-TLX responses that never exceed 21 warn unless `scale` is given", {
  tlx <- data.frame(
    mental = 14, physical = 2, temporal = 11,
    performance = 6, effort = 13, frustration = 9
  )
  # Scored as 0-100 this gives RTLX 9.17; on the 1-21 sheet it is 40.8.
  expect_warning(score_questionnaire(tlx, "nasa_tlx"), "21-point paper sheet")
  expect_equal(
    expect_no_warning(score_questionnaire(tlx, "nasa_tlx", scale = c(1, 21)))$RTLX,
    mean((c(14, 2, 11, 6, 13, 9) - 1) / 20 * 100)
  )
  expect_no_warning(score_questionnaire(tlx, "nasa_tlx", scale = c(0, 100)))
})


test_that("a zero-based instrument on which nobody chose 0 warns of a 1-based export", {
  set.seed(5)
  def <- colleyRstats:::.q_get("ipq")
  # A 1-7 export in which nobody happened to choose 7.
  d <- as.data.frame(matrix(sample(1:6, 6 * 14, TRUE), nrow = 6))
  names(d) <- def$items$code

  expect_warning(score_questionnaire(d, "ipq"), "no respondent chose 0")
  expect_no_warning(score_questionnaire(d, "ipq", scale = c(0, 6)))
  expect_no_warning(score_questionnaire(d, "ipq", scale = c(1, 7)))
})


test_that("a one-based instrument on which nobody chose the top warns of a 0-based export", {
  set.seed(6)
  d <- as.data.frame(matrix(sample(1:4, 6 * 10, TRUE), nrow = 6))
  names(d) <- paste0("sus_", 1:10)

  expect_warning(score_questionnaire(d, "sus", prefix = "sus_"), "no respondent chose 5")
  expect_no_warning(score_questionnaire(d, "sus", prefix = "sus_", scale = c(1, 5)))

  # Too few respondents for an unused endpoint to mean anything.
  expect_no_warning(score_questionnaire(d[1:3, ], "sus", prefix = "sus_"))
  # Responses spanning the whole scale raise nothing.
  d[1, 1] <- 5
  expect_no_warning(score_questionnaire(d, "sus", prefix = "sus_"))
})


test_that("the scoring message reports the observed range next to the assumed one", {
  withr::local_options(colleyRstats.quiet_questionnaires = FALSE)
  suppressWarnings(rm(list = "sus", envir = colleyRstats:::.q_announced))
  d <- make_items(c(5, 1, 5, 1, 5, 1, 5, 1, 5, 1, rep(3, 10)), "sus_", 10)

  expect_message(
    score_questionnaire(d, "sus", prefix = "sus_"),
    "responses observed 1 to 5 on the assumed range 1 to 5"
  )
})


# -------------------------------------------------------------------------
# Regressions: reliability
# -------------------------------------------------------------------------

sus_reliability_data <- function(seed = 11, n = 80) {
  set.seed(seed)
  trait <- rnorm(n)
  d <- as.data.frame(lapply(1:10, function(i) round(pmin(pmax(3 + trait + rnorm(n, sd = 0.6), 1), 5))))
  names(d) <- paste0("sus_", 1:10)
  neg <- paste0("sus_", c(2, 4, 6, 8, 10))
  d[neg] <- 6 - d[neg]
  d
}


test_that("score_reliability adds the whole-scale row where an overall score exists", {
  rel <- score_reliability(sus_reliability_data(), "sus", prefix = "sus_")

  expect_equal(rel$subscale, c("Usability", "Learnability", "SUS"))
  expect_equal(rel$n_items[3], 10L)
  expect_true(rel$alpha[3] > rel$alpha[2])

  ssq <- colleyRstats:::.q_get("ssq")
  d <- as.data.frame(matrix(sample(0:3, 20 * 16, TRUE), nrow = 20))
  names(d) <- ssq$items$code
  rel_ssq <- suppressWarnings(score_reliability(d, "ssq"))
  expect_equal(rel_ssq$subscale[4], "Total")
  expect_equal(rel_ssq$n_items[4], 16L)

  # TiA defines no total, so none is invented.
  tia <- colleyRstats:::.q_get("tia")
  d <- as.data.frame(matrix(sample(1:5, 20 * 19, TRUE), nrow = 20))
  names(d) <- tia$items$code
  rel_tia <- suppressWarnings(score_reliability(d, "tia"))
  expect_false(any(rel_tia$n_items == 19L))
})


test_that("two-item scales report the Spearman-Brown coefficient", {
  d <- sus_reliability_data()
  rel <- score_reliability(d, "sus", prefix = "sus_")

  learn <- rel[rel$subscale == "Learnability", ]
  r <- stats::cor(d$sus_4, d$sus_10)
  expect_equal(learn$spearman_brown, 2 * r / (1 + r))
  expect_true(is.na(learn$omega))
  expect_match(learn$note, "Eisinga")
  expect_true(all(is.na(rel$spearman_brown[rel$n_items != 2])))
})


test_that("omega does not depend on GPArotation or psych::omega()", {
  skip_if_not_installed("psych")
  d <- sus_reliability_data()

  # psych::omega() routes through schmid(), which stops without GPArotation;
  # the error used to be swallowed and omega came back NA without a reason.
  local_mocked_bindings(
    omega = function(...) stop("you need to have the GPArotation package installed"),
    schmid = function(...) stop("you need to have the GPArotation package installed"),
    .package = "psych"
  )
  rel <- score_reliability(d, "sus", prefix = "sus_")

  expect_true(all(is.finite(rel$omega[rel$n_items >= 3])))
  expect_true(all(rel$omega[rel$n_items >= 3] > 0.8))
})


test_that("omega total agrees with psych::omega() on the same items", {
  skip_if_not_installed("psych")
  skip_if_not_installed("GPArotation")
  d <- sus_reliability_data()
  rel <- score_reliability(d, "sus", prefix = "sus_")

  x <- colleyRstats:::.q_prepare(d, colleyRstats:::.q_get("sus"), paste0("sus_", 1:10))
  usability <- x[, c(1, 2, 3, 5, 6, 7, 8, 9)]
  ref <- suppressWarnings(suppressMessages(psych::omega(usability, nfactors = 1, plot = FALSE)))$omega.tot

  expect_equal(rel$omega[rel$subscale == "Usability"], ref, tolerance = 1e-6)
})


test_that("omega is not rescued by flipping items, so a forgotten reversal still shows", {
  skip_if_not_installed("psych")
  set.seed(12)
  trait <- rnorm(60)
  d <- as.data.frame(lapply(1:10, function(i) round(pmin(pmax(3 + trait + rnorm(60, sd = 0.3), 1), 5))))
  names(d) <- paste0("sus_", 1:10)

  rel <- suppressWarnings(score_reliability(d, "sus", prefix = "sus_"))

  expect_lt(rel$omega[rel$subscale == "SUS"], 0.5)
})


# -------------------------------------------------------------------------
# Regressions: argument validation and citations
# -------------------------------------------------------------------------

test_that("`scale` is validated wherever it is accepted", {
  d <- make_items(rep(3, 10), "sus_", 10)

  # check_questionnaire(scale = 5) used to report a "range 5-NA".
  expect_error(suppressMessages(check_questionnaire(d, "sus", prefix = "sus_", scale = 5)), "increasing")
  expect_error(suppressMessages(check_questionnaire(d, "sus", prefix = "sus_", scale = c(5, 1))), "increasing")
  expect_error(score_questionnaire(d, "sus", prefix = "sus_", scale = c("1", "5")), "increasing")
  expect_error(score_reliability(d, "sus", prefix = "sus_", scale = NA), "increasing")
  expect_error(define_questionnaire("x", "X", scale = 5, subscale = "a"), "increasing")
})


test_that("define_questionnaire explains a bad `reverse`, and accepts codes", {
  expect_error(
    define_questionnaire("bad1", "B", scale = c(1, 5), subscale = c("a", "a"), reverse = "a2"),
    "not an item code"
  )
  expect_error(
    define_questionnaire("bad2", "B", scale = c(1, 5), subscale = c("a", "a"), reverse = 3),
    "between 1 and 2"
  )

  define_questionnaire("rev2", "R", scale = c(1, 5), subscale = c("a", "a"), reverse = "item2")
  on.exit(rm("rev2", envir = colleyRstats:::.q_user), add = TRUE)
  expect_equal(which(colleyRstats:::.q_get("rev2")$items$reverse), 2L)
  expect_equal(score_questionnaire(data.frame(item1 = 5, item2 = 1), "rev2")$a, 5)
})


test_that("min_valid is not made stricter by floating-point noise", {
  define_questionnaire("ten", "Ten", scale = c(1, 5), subscale = rep("S", 10))
  on.exit(rm("ten", envir = colleyRstats:::.q_user), add = TRUE)
  d <- as.data.frame(as.list(c(rep(4, 7), NA, NA, NA)))
  names(d) <- paste0("item", 1:10)

  # (1 - 0.3) * 10 is 7.000000000000001; seven answered items must suffice.
  expect_equal(score_questionnaire(d, "ten", min_valid = 1 - 0.3)$S, 4)
})


test_that("item codes differing only in case are refused", {
  # Items are looked up case-insensitively, so "a1" would resolve to "A1".
  expect_error(
    define_questionnaire("case2", "C", scale = c(1, 5), subscale = c("S", "S"), code = c("A1", "a1")),
    "ignoring case"
  )
})


test_that("check_questionnaire handles a single-item instrument", {
  d <- data.frame(fms = c(0, 3, 8, 12, 2, 5))
  out <- expect_no_warning(suppressMessages(check_questionnaire(d, "fms")))
  expect_equal(out$observed_max, 12)
})


test_that("the TiA is cited by the publication year of AISC vol. 823", {
  expect_match(colleyRstats:::.q_get("tia")$reference, "Koerber \\(2019\\)")
})


test_that("a factor mixing numeric and text levels is refused, not scored by level position", {
  # Read by position, "0".."3" plus "no answer" scored every SSQ answer one point
  # too high (Total 160.82 instead of 82.28).
  set.seed(1)
  vals <- matrix(sample(0:3, 16 * 6, TRUE), nrow = 6)
  d <- as.data.frame(lapply(seq_len(16), function(j) {
    ordered(as.character(vals[, j]), levels = c("0", "1", "2", "3", "no answer"))
  }))
  names(d) <- paste0("ssq_", 1:16)
  expect_error(
    suppressMessages(score_questionnaire(d, "ssq", prefix = "ssq_")),
    "no answer", fixed = TRUE
  )
  # the same answers as plain numeric labels score as numbers
  d2 <- as.data.frame(lapply(seq_len(16), function(j) factor(as.character(vals[, j]))))
  names(d2) <- paste0("ssq_", 1:16)
  num <- as.data.frame(vals)
  names(num) <- paste0("ssq_", 1:16)
  expect_equal(
    suppressMessages(score_questionnaire(d2, "ssq", prefix = "ssq_", scale = c(0, 3))),
    suppressMessages(score_questionnaire(num, "ssq", prefix = "ssq_", scale = c(0, 3))),
    ignore_attr = TRUE
  )
})

test_that("a blank factor level is a missing response, as a blank text cell is", {
  v <- factor(c("1", "", "3", "2"), levels = c("", "1", "2", "3"))
  expect_identical(.q_as_numeric(v, "x"), c(1, NA, 3, 2))
  w <- ordered(c("low", "", "high"), levels = c("", "low", "high"))
  expect_identical(.q_as_numeric(w, "x"), c(1, NA, 2))
})

test_that("define_questionnaire refuses a missing subscale", {
  expect_error(
    define_questionnaire("na_sub", "N", scale = c(1, 5), subscale = c("A", NA, "A")),
    "non-missing `subscale`", fixed = TRUE
  )
})

test_that("coding-shift warnings need the range to be the assumed one shifted by a point", {
  set.seed(2)
  # UEQ-S, six respondents answering 2-6: nobody at the top is unremarkable
  ueqs <- as.data.frame(matrix(sample(2:6, 6 * 8, TRUE), nrow = 6))
  names(ueqs) <- paste0("ueqs_", 1:8)
  expect_no_warning(suppressMessages(score_questionnaire(ueqs, "ueq_s", prefix = "ueqs_")))
  # IPQ, answers 2-6 on 0-6: not the 1-7 export pattern
  ipq <- as.data.frame(matrix(sample(2:6, 6 * 14, TRUE), nrow = 6))
  names(ipq) <- paste0("ipq_", 1:14)
  expect_no_warning(suppressMessages(score_questionnaire(ipq, "ipq", prefix = "ipq_")))
  # IPQ filling exactly 1-6 on 0-6: the 1-7 export pattern, warned
  ipq_shift <- as.data.frame(matrix(rep(1:6, length.out = 6 * 14), nrow = 6))
  names(ipq_shift) <- paste0("ipq_", 1:14)
  expect_warning(suppressMessages(score_questionnaire(ipq_shift, "ipq", prefix = "ipq_")), "one point")
  # NASA-TLX, a low-workload respondent on 0-100 in steps of 5
  tlx <- data.frame(tlx_1 = 10, tlx_2 = 5, tlx_3 = 20, tlx_4 = 15, tlx_5 = 0, tlx_6 = 10)
  expect_no_warning(suppressMessages(score_questionnaire(tlx, "nasa_tlx", prefix = "tlx_")))
  tlx21 <- data.frame(tlx_1 = 13, tlx_2 = 4, tlx_3 = 17, tlx_4 = 8, tlx_5 = 2, tlx_6 = 11)
  expect_warning(suppressMessages(score_questionnaire(tlx21, "nasa_tlx", prefix = "tlx_")), "21-point")
})