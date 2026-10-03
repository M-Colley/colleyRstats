# Definitions of the standardised questionnaires this package can score.
#
# Each definition encodes one published instrument: its response range, its
# items in administration order, which subscale each item belongs to, and which
# items are worded against the direction of their scale. The scoring machinery
# lives in questionnaires.R; this file is deliberately nothing but data, so a
# definition can be checked against the paper it comes from by reading it.
#
# IMPORTANT: item ORDER and item POLARITY are properties of the sheet a study
# actually administered, not of the instrument in the abstract. Surveys reorder
# items, translate them, and flip semantic differentials. The definitions here
# follow the published item order and scoring key, with ONE exception: the
# `attrakdiff` key lists its word pairs blocked by dimension with the negative
# pole first, which is NOT the order or the polarity of the official sheet (see
# its notes). It is kept unchanged so existing analyses keep scoring the same
# columns the same way; `attrakdiff_official` encodes the sheet as administered.
# check_questionnaire() prints the mapping that will be used, so it can be
# compared against the real survey before any number is believed.


# Internal: build one instrument definition. Items are given as parallel
# vectors so a definition reads like the questionnaire sheet it encodes.
#
# `reverse` holds item *numbers* (positions), which is how published scoring
# keys are written ("items 2, 4, 6, 8 and 10 are reverse-scored"), so a
# definition can be diffed against the key without counting columns.
#
# The remaining fields describe how the published instrument is SCORED, beyond
# its item key:
#   overall      the instrument defines an overall score (used by
#                score_reliability() to add a whole-scale row). Implied by
#                `total`; set explicitly where a custom aggregator forms it.
#   total_name   that overall score's column name, when it is not "Total".
#   integer      responses are whole scale points (a Likert or semantic-
#                differential format), so a fractional value signals an
#                averaged or mis-exported column rather than a response.
#   missing      the published rule for an item a respondent left out, applied
#                when `min_valid` < 1 lets such a row be scored: "prorate" (the
#                mean of the items answered) or "midpoint" (the scale centre).
.q_def <- function(key, name, reference, scale, code, label, subscale,
                   reverse = integer(0), recode = "none", total = "mean",
                   aggregate = NULL, higher = NA_character_,
                   notes = character(), overall = !is.null(total),
                   total_name = NULL, integer = TRUE, missing = "prorate") {
  n <- length(code)
  stopifnot(length(label) == n, length(subscale) == n)
  stopifnot(all(reverse %in% seq_len(n)))
  stopifnot(missing %in% c("prorate", "midpoint"))

  list(
    key = key,
    name = name,
    reference = reference,
    scale = scale,
    items = data.frame(
      item = seq_len(n),
      code = code,
      label = label,
      subscale = subscale,
      reverse = seq_len(n) %in% reverse,
      stringsAsFactors = FALSE
    ),
    recode = recode,
    total = total,
    aggregate = aggregate,
    higher = higher,
    notes = notes,
    overall = isTRUE(overall),
    total_name = total_name,
    integer = isTRUE(integer),
    missing = missing
  )
}


# Internal: the built-in registry. A function rather than a top-level list, so
# the aggregate closures below are resolved at call time; that keeps the file
# order-independent and lets define_questionnaire() overlay entries.
.q_builtin <- function() {
  list(

    # ---------------------------------------------------------------------
    nasa_tlx = .q_def(
      key = "nasa_tlx",
      name = "NASA Task Load Index, raw (RTLX)",
      reference = "Hart & Staveland (1988), Adv. Psychology 52; Hart (2006), HFES 50",
      scale = c(0, 100),
      code = c("mental", "physical", "temporal", "performance", "effort", "frustration"),
      label = c(
        "Mental Demand", "Physical Demand", "Temporal Demand",
        "Performance", "Effort", "Frustration"
      ),
      subscale = c(
        "Mental Demand", "Physical Demand", "Temporal Demand",
        "Performance", "Effort", "Frustration"
      ),
      recode = "none",
      total = "mean",
      higher = "worse",
      # A 0-100 rating scale or slider: fractional values are legitimate.
      integer = FALSE,
      notes = c(
        "Raw (unweighted) TLX: the overall score is the mean of the six subscales. The pairwise weighting procedure of the original TLX is not applied, so report it as raw TLX or RTLX.",
        "Responses are rescaled to 0-100, so pass scale = c(1, 21) for the 21-point sheet, or scale = c(1, 20) for a 20-point slider. Scoring 1-21 responses as if they were 0-100 understates workload about five-fold, so score_questionnaire() warns when every response is 21 or less and no `scale` was given.",
        "Performance is NOT reversed by default: on the original sheet it runs Perfect (low) to Failure (high), so a high value already means poor performance, in the same direction as the other five subscales. If your survey anchored it Good at the high end, pass reverse_items = 'performance'."
      )
    ),

    # ---------------------------------------------------------------------
    sus = .q_def(
      key = "sus",
      name = "System Usability Scale (SUS)",
      reference = "Brooke (1996), Usability Evaluation in Industry; Lewis & Sauro (2009), HCII",
      scale = c(1, 5),
      code = paste0("sus", 1:10),
      label = c(
        "I think that I would like to use this system frequently",
        "I found the system unnecessarily complex",
        "I thought the system was easy to use",
        "I think that I would need the support of a technical person to be able to use this system",
        "I found the various functions in this system were well integrated",
        "I thought there was too much inconsistency in this system",
        "I would imagine that most people would learn to use this system very quickly",
        "I found the system very cumbersome to use",
        "I felt very confident using the system",
        "I needed to learn a lot of things before I could get going with this system"
      ),
      subscale = c(
        "Usability", "Usability", "Usability", "Learnability", "Usability",
        "Usability", "Usability", "Usability", "Usability", "Learnability"
      ),
      reverse = c(2, 4, 6, 8, 10),
      recode = "zero_base",
      total = NULL,
      aggregate = .q_aggregate_sus,
      higher = "better",
      # The SUS score is an overall score, formed by the custom aggregator.
      overall = TRUE,
      total_name = "SUS",
      # Brooke (1996): a respondent who cannot answer an item marks the centre.
      missing = "midpoint",
      notes = c(
        "The SUS score is the sum of the ten recoded items multiplied by 2.5, giving 0-100. That is a percentage of the maximum, NOT a percentile: the mean SUS across studies is about 68, so 68 is average rather than poor.",
        "Usability (8 items, x 3.125) and Learnability (2 items, x 12.5) follow Lewis & Sauro (2009) and are likewise on 0-100. The two are strongly correlated; report them only if the study has a reason to separate them.",
        "Missing items: Brooke (1996) instructs a respondent who cannot answer an item to mark the centre point of the scale, so when `min_valid` < 1 lets an incomplete row be scored, each missing item counts as the centre (3 on 1-5). One missing item in an otherwise perfect response therefore gives 95, not 100. Pass impute = \"prorate\" to scale up from the answered items instead, and say which rule you used.",
        "Learnability has only two items. score_reliability() reports the Spearman-Brown coefficient for it, which Eisinga, te Grotenhuis & Pelzer (2013) recommend over alpha for two-item scales."
      )
    ),

    # ---------------------------------------------------------------------
    ueq_s = .q_def(
      key = "ueq_s",
      name = "User Experience Questionnaire, short form (UEQ-S)",
      reference = "Schrepp, Hinderks & Thomaschewski (2017), IJIMAI 4(6)",
      scale = c(1, 7),
      code = paste0("ueqs", 1:8),
      label = c(
        "obstructive - supportive", "complicated - easy",
        "inefficient - efficient", "confusing - clear",
        "boring - exciting", "not interesting - interesting",
        "conventional - inventive", "usual - leading edge"
      ),
      subscale = c(rep("Pragmatic Quality", 4), rep("Hedonic Quality", 4)),
      recode = "center",
      total = "mean",
      higher = "better",
      notes = c(
        "Items are centred to -3 (most negative) .. +3 (most positive); the overall score is the mean of all eight. Values above +0.8 are conventionally read as a positive evaluation, below -0.8 as a negative one.",
        "Unlike the full UEQ, the UEQ-S fixes the polarity: all eight pairs are printed with the negative term on the LEFT, i.e. at the low response value, so no item is reverse-scored. Pass reverse_items only if your own survey tool stored a pair the other way round."
      )
    ),

    # ---------------------------------------------------------------------
    ueq = .q_def(
      key = "ueq",
      name = "User Experience Questionnaire (UEQ), full form",
      reference = "Laugwitz, Held & Schrepp (2008), USAB; Schrepp, UEQ Handbook",
      scale = c(1, 7),
      code = paste0("ueq", 1:26),
      label = c(
        "annoying - enjoyable", "not understandable - understandable",
        "creative - dull", "easy to learn - difficult to learn",
        "valuable - inferior", "boring - exciting",
        "not interesting - interesting", "unpredictable - predictable",
        "fast - slow", "inventive - conventional",
        "obstructive - supportive", "good - bad",
        "complicated - easy", "unlikable - pleasing",
        "usual - leading edge", "unpleasant - pleasant",
        "secure - not secure", "motivating - demotivating",
        "meets expectations - does not meet expectations", "inefficient - efficient",
        "clear - confusing", "impractical - practical",
        "organized - cluttered", "attractive - unattractive",
        "friendly - unfriendly", "conservative - innovative"
      ),
      subscale = c(
        "Attractiveness", "Perspicuity", "Novelty", "Perspicuity",
        "Stimulation", "Stimulation", "Stimulation", "Dependability",
        "Efficiency", "Novelty", "Dependability", "Attractiveness",
        "Perspicuity", "Attractiveness", "Novelty", "Attractiveness",
        "Dependability", "Stimulation", "Dependability", "Efficiency",
        "Perspicuity", "Efficiency", "Efficiency", "Attractiveness",
        "Attractiveness", "Novelty"
      ),
      reverse = c(3, 4, 5, 9, 10, 12, 17, 18, 19, 21, 23, 24, 25),
      recode = "center",
      total = NULL,
      higher = "better",
      notes = c(
        "The UEQ deliberately balances polarity: 13 of the 26 pairs are printed with the POSITIVE term on the left and are reverse-scored here. Compare that set against your own sheet before trusting the scores.",
        "The handbook reports the six scales separately and defines no single overall UEQ score, so none is produced. Attractiveness is a pure valence scale; Perspicuity, Efficiency and Dependability are pragmatic; Stimulation and Novelty are hedonic."
      )
    ),

    # ---------------------------------------------------------------------
    tia = .q_def(
      key = "tia",
      name = "Trust in Automation (TiA)",
      # The congress was IEA 2018, but AISC vol. 823 appeared in 2019, and the
      # proceedings chapter is cited by its publication year.
      reference = "Koerber (2019), Proc. IEA 2018, Advances in Intelligent Systems and Computing 823",
      scale = c(1, 5),
      code = c(
        "rc1", "up1", "f1", "i1", "pro1", "rc2", "up2", "i2", "t1", "rc3",
        "up3", "pro2", "rc4", "t2", "rc5", "up4", "f2", "pro3", "rc6"
      ),
      # Items 1-19 in the order they are printed on the published sheet
      # (Trust-in-Automation_TiA_questionnaire.pdf).
      label = c(
        "The system is capable of interpreting situations correctly",
        "The system state was always clear to me",
        "I already know similar systems",
        "The developers are trustworthy",
        "One should be careful with unfamiliar automated systems",
        "The system works reliably",
        "The system reacts unpredictably",
        "The developers take my well-being seriously",
        "I trust the system",
        "A system malfunction is likely",
        "I was able to understand why things happened",
        "I rather trust a system than I mistrust it",
        "The system is capable of taking over complicated tasks",
        "I can rely on the system",
        "The system might make sporadic errors",
        "It's difficult to identify what the system will do next",
        "I have already used similar systems",
        "Automated systems generally work well",
        "I am confident about the system's capabilities"
      ),
      subscale = c(
        "Reliability/Competence", "Understanding/Predictability", "Familiarity",
        "Intention of Developers", "Propensity to Trust", "Reliability/Competence",
        "Understanding/Predictability", "Intention of Developers", "Trust in Automation",
        "Reliability/Competence", "Understanding/Predictability", "Propensity to Trust",
        "Reliability/Competence", "Trust in Automation", "Reliability/Competence",
        "Understanding/Predictability", "Familiarity", "Propensity to Trust",
        "Reliability/Competence"
      ),
      reverse = c(5, 7, 10, 15, 16),
      recode = "none",
      total = NULL,
      higher = "better",
      notes = c(
        "Item order, subscale membership and the inverted set are transcribed from the author's own release (github.com/moritzkoerber/TiA_Trust_in_Automation_Questionnaire): Table 1 of TiA_Manual_Eng.pdf, which states that items 5, 7, 10, 15 and 16 are inverse items.",
        "Six subscales over 19 items. Trust in Automation (items 9 and 14) is the outcome scale and the other five are its proposed antecedents. The manual is explicit that a total score over all items is not produced: 'A total sum score derived from all items together is, given the multidimensionality, not unambiguously interpretable', so none is computed here.",
        "Familiarity, Intention of Developers and Trust in Automation have two items each; score_reliability() reports the Spearman-Brown coefficient for them, which Eisinga, te Grotenhuis & Pelzer (2013) recommend over alpha for two-item scales.",
        "Propensity to Trust and Familiarity are dispositional: they describe the participant rather than the system, and are normally measured once, before exposure, rather than per condition.",
        "The 'no response' option on the printed sheet is a missing value, not a sixth scale point. Code it NA rather than 0 or 6."
      )
    ),

    # ---------------------------------------------------------------------
    attrakdiff = .q_def(
      key = "attrakdiff",
      name = "AttrakDiff 2",
      reference = "Hassenzahl, Burmester & Koller (2003), Mensch & Computer 2003",
      scale = c(1, 7),
      code = c(paste0("pq", 1:7), paste0("hqi", 1:7), paste0("hqs", 1:7), paste0("att", 1:7)),
      label = c(
        "technical - human", "complicated - simple", "impractical - practical",
        "cumbersome - straightforward", "unpredictable - predictable",
        "confusing - clearly structured", "unruly - manageable",
        "isolating - connective", "unprofessional - professional",
        "tacky - stylish", "cheap - premium", "alienating - integrating",
        "separates me from people - brings me closer to people",
        "unpresentable - presentable",
        "conventional - inventive", "unimaginative - creative",
        "cautious - bold", "conservative - innovative", "dull - captivating",
        "undemanding - challenging", "ordinary - novel",
        "unpleasant - pleasant", "ugly - attractive", "disagreeable - likeable",
        "rejecting - inviting", "bad - good", "repelling - appealing",
        "discouraging - motivating"
      ),
      subscale = c(
        rep("Pragmatic Quality", 7),
        rep("Hedonic Quality - Identity", 7),
        rep("Hedonic Quality - Stimulation", 7),
        rep("Attractiveness", 7)
      ),
      recode = "center",
      total = NULL,
      higher = "better",
      notes = c(
        "Four dimensions of seven word pairs each, centred to -3 .. +3 and averaged. The published portfolio plot puts Pragmatic Quality on the x-axis against the mean of the two Hedonic dimensions on the y-axis.",
        "NOT the official sheet: the pairs are listed here BLOCKED by dimension, each with its NEGATIVE term first (so nothing is reversed), which suits data you have already re-sorted and re-poled. The official form interleaves the 28 pairs and prints 15 of them with the positive term on the left. Data collected with that form and stored as answered belong to instrument = \"attrakdiff_official\"; scoring them with this key silently mixes up the dimensions and leaves 15 items unreversed.",
        "Within each dimension the pairs keep their order of appearance on the official sheet, so the codes (pq1 .. att7) are the same in both keys and name the same word pair."
      )
    ),

    # ---------------------------------------------------------------------
    # The 28 pairs in the order and with the poles of the sheet as administered.
    # Verified against independent reproductions of the form: the English
    # e-survey of attrakdiff.de/UID (copied into the protocol of trial
    # NCT03599856), the nc-apps/quex survey app, and the French validation by
    # Lallemand, Koenig, Gronier & Martin (2015), whose sheet lists the same
    # order, assigns the same dimensions and names exactly these 15 reversed
    # items (QP_1, ATT_1, QHS_1, QP_2, QHI_2, QP_3, ATT_3, QHI_3, QP_5, QHI_6,
    # ATT_5, QHS_3, QHS_4, ATT_7, QHS_7).
    attrakdiff_official = .q_def(
      key = "attrakdiff_official",
      name = "AttrakDiff 2 (official sheet order and poles)",
      reference = "Hassenzahl, Burmester & Koller (2003), Mensch & Computer 2003; order and poles as administered (cf. Lallemand et al., 2015, Eur. Rev. Appl. Psychol. 65(5))",
      scale = c(1, 7),
      code = c(
        "pq1", "hqi1", "att1", "hqs1", "pq2", "hqi2", "att2", "pq3", "att3", "pq4",
        "hqi3", "pq5", "hqi4", "hqi5", "hqi6", "hqi7", "att4", "hqs2", "att5", "pq6",
        "att6", "hqs3", "hqs4", "hqs5", "hqs6", "att7", "hqs7", "pq7"
      ),
      # Left - right, exactly as printed; the left term is response 1.
      label = c(
        "human - technical", "isolating - connective", "pleasant - unpleasant",
        "inventive - conventional", "simple - complicated",
        "professional - unprofessional", "ugly - attractive",
        "practical - impractical", "likeable - disagreeable",
        "cumbersome - straightforward", "stylish - tacky",
        "predictable - unpredictable", "cheap - premium",
        "alienating - integrating",
        "brings me closer to people - separates me from people",
        "unpresentable - presentable", "rejecting - inviting",
        "unimaginative - creative", "good - bad",
        "confusing - clearly structured", "repelling - appealing",
        "bold - cautious", "innovative - conservative", "dull - captivating",
        "undemanding - challenging", "motivating - discouraging",
        "novel - ordinary", "unruly - manageable"
      ),
      subscale = c(
        "Pragmatic Quality", "Hedonic Quality - Identity", "Attractiveness",
        "Hedonic Quality - Stimulation", "Pragmatic Quality", "Hedonic Quality - Identity",
        "Attractiveness", "Pragmatic Quality", "Attractiveness", "Pragmatic Quality",
        "Hedonic Quality - Identity", "Pragmatic Quality", "Hedonic Quality - Identity",
        "Hedonic Quality - Identity", "Hedonic Quality - Identity",
        "Hedonic Quality - Identity", "Attractiveness", "Hedonic Quality - Stimulation",
        "Attractiveness", "Pragmatic Quality", "Attractiveness",
        "Hedonic Quality - Stimulation", "Hedonic Quality - Stimulation",
        "Hedonic Quality - Stimulation", "Hedonic Quality - Stimulation",
        "Attractiveness", "Hedonic Quality - Stimulation", "Pragmatic Quality"
      ),
      # The pairs printed with the POSITIVE term on the left.
      reverse = c(1, 3, 4, 5, 6, 8, 9, 11, 12, 15, 19, 22, 23, 26, 27),
      recode = "center",
      total = NULL,
      higher = "better",
      notes = c(
        "The 28 word pairs in the order and with the poles of the official sheet, coded 1 (left term) to 7 (right term) as answered. The 15 pairs printed with the positive term on the left (items 1, 3, 4, 5, 6, 8, 9, 11, 12, 15, 19, 22, 23, 26, 27) are reversed, then everything is centred to -3 .. +3 and averaged per dimension.",
        "Order and poles were verified for the English sheet against independent reproductions of the form, including the French validation of Lallemand et al. (2015), which reverses the same 15 items. The German sheet agrees where it could be checked (items 1-10); compare the labels against your own form before relying on it.",
        "Item codes match the `attrakdiff` key (pq1 .. att7 name the same word pairs), so a named `items` mapping works with either key. Use this key for data stored as answered on the official form, and `attrakdiff` for data already re-sorted and re-poled."
      )
    ),

    # ---------------------------------------------------------------------
    ipq = .q_def(
      key = "ipq",
      name = "igroup Presence Questionnaire (IPQ)",
      reference = "Schubert, Friedmann & Regenbrecht (2001), Presence 10(3); igroup.org",
      scale = c(0, 6),
      code = c("g1", paste0("sp", 1:5), paste0("inv", 1:4), paste0("real", 1:4)),
      label = c(
        "In the computer generated world I had a sense of being there (not at all / very much)",
        "Somehow I felt that the virtual world surrounded me",
        "I felt like I was just perceiving pictures",
        "I did not feel present in the virtual space (did not feel / felt present)",
        "I had a sense of acting in the virtual space, rather than operating something from outside",
        "I felt present in the virtual space",
        "How aware were you of the real world surrounding while navigating in the virtual world? (extremely aware / not aware at all)",
        "I was not aware of my real environment",
        "I still paid attention to the real environment",
        "I was completely captivated by the virtual world",
        "How real did the virtual world seem to you? (completely real / not real at all)",
        "How much did your experience in the virtual environment seem consistent with your real world experience? (not consistent / very consistent)",
        "How real did the virtual world seem to you? (about as real as an imagined world / indistinguishable from the real world)",
        "The virtual world seemed more realistic than the real world"
      ),
      subscale = c(
        "General Presence",
        rep("Spatial Presence", 5),
        rep("Involvement", 4),
        rep("Experienced Realism", 4)
      ),
      reverse = c(3, 9, 11),
      recode = "none",
      total = NULL,
      higher = "more presence",
      notes = c(
        "Fourteen items on a 7-point scale scored 0-6. General Presence is a single item, reported on its own; the igroup authors define no overall IPQ score, so none is produced.",
        "Reverse-scored are SP2 (item 3), INV3 (item 9) and REAL1 (item 11), matching the scoring syntax published at igroup.org ('compute sp2u = -1 * sp2 + 6').",
        "SP3 (item 4) and INV1 (item 7) are NOT reversed even though their wording sounds negative: the published form gives them pre-flipped anchors ('did not feel'/'felt present' and 'extremely aware'/'not aware at all'), so a high raw value already means more presence. If your survey re-anchored them to a plain disagree-agree scale, pass reverse_items = c('sp3', 'inv1').",
        "REAL1 (item 11) and REAL3 (item 13) share the same question text and are distinguished only by their anchors, which is how the published instrument reads; the anchors are given in the labels here so the two can be told apart."
      )
    ),

    # ---------------------------------------------------------------------
    ssq = .q_def(
      key = "ssq",
      name = "Simulator Sickness Questionnaire (SSQ)",
      reference = "Kennedy, Lane, Berbaum & Lilienthal (1993), Int. J. Aviation Psychology 3(3)",
      scale = c(0, 3),
      code = paste0("ssq", 1:16),
      label = c(
        "General discomfort", "Fatigue", "Headache", "Eyestrain",
        "Difficulty focusing", "Increased salivation", "Sweating", "Nausea",
        "Difficulty concentrating", "Fullness of head", "Blurred vision",
        "Dizzy (eyes open)", "Dizzy (eyes closed)", "Vertigo",
        "Stomach awareness", "Burping"
      ),
      subscale = c(
        "Nausea,Oculomotor", "Oculomotor", "Oculomotor", "Oculomotor",
        "Oculomotor,Disorientation", "Nausea", "Nausea", "Nausea,Disorientation",
        "Nausea,Oculomotor", "Disorientation", "Oculomotor,Disorientation",
        "Disorientation", "Disorientation", "Disorientation",
        "Nausea", "Nausea"
      ),
      recode = "none",
      total = NULL,
      aggregate = .q_aggregate_ssq,
      higher = "worse",
      # The Total Score is an overall score, formed by the custom aggregator.
      overall = TRUE,
      notes = c(
        "Symptoms are rated 0 = none, 1 = slight, 2 = moderate, 3 = severe. Each subscale draws on seven items, and five of the sixteen items load on two subscales at once, which is why the subscale column names two scales for them.",
        "Weighted per Kennedy et al. (1993): Nausea x 9.54, Oculomotor x 7.58, Disorientation x 13.92, and Total = (raw N + raw O + raw D) x 3.74. The weights make the subscales comparable to one another but leave the scores unbounded above.",
        "SSQ was validated as a difference from a pre-exposure baseline. Score both measurements and analyse the change unless the design rules that out."
      )
    ),

    # ---------------------------------------------------------------------
    fms = .q_def(
      key = "fms",
      name = "Fast Motion Sickness Scale (FMS)",
      reference = "Keshavarz & Hecht (2011), Human Factors 53(4)",
      scale = c(0, 20),
      code = "fms",
      label = "Verbal rating of motion sickness (0 = no sickness, 20 = frank sickness)",
      subscale = "FMS",
      recode = "none",
      total = NULL,
      higher = "worse",
      notes = paste(
        "A single item, sampled repeatedly during exposure, typically once a minute.",
        "Scoring one measurement is trivial; the analysis lives in the time course --",
        "see summarize_sickness() for peak, mean, final value, area under the curve",
        "and time to threshold."
      )
    ),

    # ---------------------------------------------------------------------
    misc = .q_def(
      key = "misc",
      name = "Misery Scale (MISC)",
      reference = "Wertheim, Bos & Bles (1998); Bos, MacKinnon & Patterson (2005), Aviat. Space Environ. Med. 76(12)",
      scale = c(0, 10),
      code = "misc",
      label = "Misery scale (0 = no problems, 6 = nausea, 10 = vomiting)",
      subscale = "MISC",
      recode = "none",
      total = NULL,
      higher = "worse",
      notes = c(
        "A single ordinal item with labelled steps, sampled repeatedly during exposure. It is ORDINAL and unevenly spaced -- the step from 6 (nausea) to 10 (vomiting) is not four times the step from 0 to 1 -- so analyse it with an ordinal model or with rank-based methods, rather than by taking means.",
        "MISC must be DECLARED ordinal: its 0-10 range has more distinct values than classify_outcome()'s ordinal_max_levels of 7, so left to classify itself a MISC column is taken for a count and recommend_test() proposes a Poisson GLMM. Pass outcome_type = \"ordinal\" to fit_recommended(), or ordinal_max_levels = 11.",
        "See summarize_sickness() for the time course."
      )
    )
  )
}
