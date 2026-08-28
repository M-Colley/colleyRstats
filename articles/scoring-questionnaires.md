# Scoring questionnaires

``` r

library(colleyRstats)
#> Loading required package: ggplot2
#> Registered S3 methods overwritten by 'ggpp':
#>   method                  from   
#>   heightDetails.titleGrob ggplot2
#>   widthDetails.titleGrob  ggplot2
```

Turning raw item columns into subscale scores is the most repeated step
of a user study, and the one most able to be wrong without anything
looking wrong. Every project re-implements the same reverse-coding and
averaging by hand, and a single mis-numbered item changes every result
downstream without producing a single error.

[`score_questionnaire()`](https://m-colley.github.io/colleyRstats/reference/score_questionnaire.md)
applies a published instrument’s own scoring key.

## What is available

``` r

list_questionnaires()[, c("key", "name", "n_items", "n_subscales", "scale")]
#>           key                                              name n_items
#> 1  attrakdiff                                      AttrakDiff 2      28
#> 2         fms                  Fast Motion Sickness Scale (FMS)       1
#> 3         ipq               igroup Presence Questionnaire (IPQ)      14
#> 4        misc                               Misery Scale (MISC)       1
#> 5    nasa_tlx                  NASA Task Load Index, raw (RTLX)       6
#> 6         ssq            Simulator Sickness Questionnaire (SSQ)      16
#> 7         sus                      System Usability Scale (SUS)      10
#> 8         tia                         Trust in Automation (TiA)      19
#> 9         ueq    User Experience Questionnaire (UEQ), full form      26
#> 10      ueq_s User Experience Questionnaire, short form (UEQ-S)       8
#>    n_subscales scale
#> 1            4   1-7
#> 2            1  0-20
#> 3            4   0-6
#> 4            1  0-10
#> 5            6 0-100
#> 6            3   0-3
#> 7            2   1-5
#> 8            6   1-5
#> 9            6   1-7
#> 10           2   1-7
```

## Scoring

Point it at the item columns. A prefix is usually enough:

``` r

set.seed(1)
study <- data.frame(participant = factor(1:8))
study[paste0("sus_", 1:10)] <- lapply(1:10, function(i) sample(1:5, 8, TRUE))

score_questionnaire(study, "sus", prefix = "sus_")
#> Scoring System Usability Scale (SUS) from 10 columns (sus_1 ... sus_10); reverse-coded: sus2, sus4, sus6, sus8, sus10.
#> CAUTION: item numbers, order and polarity depend on how the questionnaire
#> was administered -- survey tools renumber items, translations reorder them,
#> and short forms drop them. This package applies the PUBLISHED key. If your
#> sheet differed, the scores will be wrong without any error being raised.
#> Check the mapping against the survey your participants actually saw, and
#> double-check any number before it goes into a paper.
#>   See the full mapping with check_questionnaire(data, "sus", ...); silence this note with options(colleyRstats.quiet_questionnaires = TRUE).
#>    SUS Usability Learnability
#> 1 50.0    56.250         25.0
#> 2 47.5    40.625         75.0
#> 3 20.0    21.875         12.5
#> 4 37.5    31.250         62.5
#> 5 65.0    62.500         75.0
#> 6 55.0    46.875         87.5
#> 7 42.5    43.750         37.5
#> 8 30.0    28.125         37.5
```

The SUS score is the sum of the ten recoded items times 2.5, which puts
it on 0–100. That is a percentage of the maximum, **not** a percentile:
the mean SUS across published studies is about 68, so 68 is average
rather than poor.

Every instrument’s notes say this sort of thing, and
[`questionnaire_items()`](https://m-colley.github.io/colleyRstats/reference/questionnaire_items.md)
prints them:

``` r

questionnaire_items("ueq_s")
#> User Experience Questionnaire, short form (UEQ-S) -- Schrepp, Hinderks & Thomaschewski (2017), IJIMAI 4(6)
#> Response range 1-7; 8 items in 2 subscales.
#> CAUTION: item numbers, order and polarity depend on how the questionnaire
#> was administered -- survey tools renumber items, translations reorder them,
#> and short forms drop them. This package applies the PUBLISHED key. If your
#> sheet differed, the scores will be wrong without any error being raised.
#> Check the mapping against the survey your participants actually saw, and
#> double-check any number before it goes into a paper.
#>   - Items are centred to -3 (most negative) .. +3 (most positive); the overall score is the mean of all eight. Values above +0.8 are conventionally read as a positive evaluation, below -0.8 as a negative one.
#>   - Unlike the full UEQ, the UEQ-S fixes the polarity: all eight pairs are printed with the negative term on the LEFT, i.e. at the low response value, so no item is reverse-scored. Pass reverse_items only if your own survey tool stored a pair the other way round.
#>  item  code                         label          subscale reverse
#>     1 ueqs1      obstructive - supportive Pragmatic Quality   FALSE
#>     2 ueqs2            complicated - easy Pragmatic Quality   FALSE
#>     3 ueqs3       inefficient - efficient Pragmatic Quality   FALSE
#>     4 ueqs4             confusing - clear Pragmatic Quality   FALSE
#>     5 ueqs5             boring - exciting   Hedonic Quality   FALSE
#>     6 ueqs6 not interesting - interesting   Hedonic Quality   FALSE
#>     7 ueqs7      conventional - inventive   Hedonic Quality   FALSE
#>     8 ueqs8          usual - leading edge   Hedonic Quality   FALSE
```

### Declaring the response range

Instruments are administered on whatever scale the survey tool offered.
Say which one you used and the responses are rescaled onto the
instrument’s own range before scoring:

``` r

tlx <- data.frame(
  mental = c(14, 3), physical = c(2, 1), temporal = c(11, 4),
  performance = c(6, 2), effort = c(13, 5), frustration = c(9, 1)
)

# The 21-point NASA-TLX sheet, scored onto the conventional 0-100
score_questionnaire(tlx, "nasa_tlx", scale = c(1, 21))
#> Scoring NASA Task Load Index, raw (RTLX) from 6 columns (mental ... frustration); no items reverse-coded.
#> CAUTION: item numbers, order and polarity depend on how the questionnaire
#> was administered -- survey tools renumber items, translations reorder them,
#> and short forms drop them. This package applies the PUBLISHED key. If your
#> sheet differed, the scores will be wrong without any error being raised.
#> Check the mapping against the survey your participants actually saw, and
#> double-check any number before it goes into a paper.
#>   See the full mapping with check_questionnaire(data, "nasa_tlx", ...); silence this note with options(colleyRstats.quiet_questionnaires = TRUE).
#>   Mental_Demand Physical_Demand Temporal_Demand Performance Effort Frustration
#> 1            65               5              50          25     60          40
#> 2            10               0              15           5     20           0
#>        RTLX
#> 1 40.833333
#> 2  8.333333
```

Responses outside the range you declare are an error rather than a
silent rescale, which is what stops a 1–7 export from being scored as if
it were the 0–100 TLX.

### Adding scores to the data

``` r

scored <- score_questionnaire(study, "sus", prefix = "sus_", append = TRUE)
names(scored)[1:3]
#> [1] "participant" "sus_1"       "sus_2"
scored$SUS
#> [1] 50.0 47.5 20.0 37.5 65.0 55.0 42.5 30.0
```

## Verify the mapping before you trust the scores

This is the important part.

Item numbers, item order and item polarity belong to the sheet a study
actually administered, not to the instrument in the abstract. Survey
tools renumber items, translations reorder them, short forms drop them
from the middle, and semantic differentials get printed with the poles
the other way round. This package applies each instrument’s *published*
key — the right default, and still only a default.
[`score_questionnaire()`](https://m-colley.github.io/colleyRstats/reference/score_questionnaire.md)
maps your columns onto the instrument’s items *positionally*, so a
shifted export produces scores that look entirely reasonable and are
wrong.

Nothing errors when that happens, which is why R says it out loud: the
first time each distinct mapping is scored in a session, the mapping and
a caution print together. Read them rather than tuning them out, and
double-check any number before it reaches a paper.

Run this once per instrument, per study, and read what it prints:

``` r

invisible(check_questionnaire(study, "sus", prefix = "sus_"))
#> System Usability Scale (SUS) -- Brooke (1996), Usability Evaluation in Industry; Lewis & Sauro (2009), HCII
#> CAUTION: item numbers, order and polarity depend on how the questionnaire
#> was administered -- survey tools renumber items, translations reorder them,
#> and short forms drop them. This package applies the PUBLISHED key. If your
#> sheet differed, the scores will be wrong without any error being raised.
#> Check the mapping against the survey your participants actually saw, and
#> double-check any number before it goes into a paper.
#> Assumed response range: 1-5 (the instrument's own; pass `scale` if your survey differed)
#> 
#> Item mapping (verify against the survey your participants saw):
#>  item  code column     subscale reverse observed_min observed_max n_missing
#>     1  sus1  sus_1    Usability   FALSE            1            5         0
#>     2  sus2  sus_2    Usability    TRUE            1            5         0
#>     3  sus3  sus_3    Usability   FALSE            1            5         0
#>     4  sus4  sus_4 Learnability    TRUE            1            4         0
#>     5  sus5  sus_5    Usability   FALSE            1            4         0
#>     6  sus6  sus_6    Usability    TRUE            1            5         0
#>     7  sus7  sus_7    Usability   FALSE            1            5         0
#>     8  sus8  sus_8    Usability    TRUE            1            5         0
#>     9  sus9  sus_9    Usability   FALSE            1            5         0
#>    10 sus10 sus_10 Learnability    TRUE            1            5         0
#> 
#> Notes:
#>   - The SUS score is the sum of the ten recoded items multiplied by 2.5, giving 0-100. That is a percentage of the maximum, NOT a percentile: the mean SUS across studies is about 68, so 68 is average rather than poor.
#>   - Usability (8 items, x 3.125) and Learnability (2 items, x 12.5) follow Lewis & Sauro (2009) and are likewise on 0-100. The two are strongly correlated; report them only if the study has a reason to separate them.
```

It shows which column supplies which item, which subscale that item
loads on, whether it is reverse-coded, and the observed range of each
column – so a column of all-3s where you expected variation, or a 1–7
export where the instrument expects 1–5, is visible immediately.

If your survey stored a pair the other way round, `reverse_items`
toggles it. Naming an item that the key already reverses *un*-reverses
it:

``` r

# A survey that anchored NASA-TLX performance "Good" at the high end
scores <- score_questionnaire(tlx, "nasa_tlx",
  scale = c(1, 21),
  reverse_items = "performance"
)
#> Scoring NASA Task Load Index, raw (RTLX) from 6 columns (mental ... frustration); reverse-coded: performance.
#> CAUTION: item numbers, order and polarity depend on how the questionnaire
#> was administered -- survey tools renumber items, translations reorder them,
#> and short forms drop them. This package applies the PUBLISHED key. If your
#> sheet differed, the scores will be wrong without any error being raised.
#> Check the mapping against the survey your participants actually saw, and
#> double-check any number before it goes into a paper.
#>   See the full mapping with check_questionnaire(data, "nasa_tlx", ...); silence this note with options(colleyRstats.quiet_questionnaires = TRUE).
scores$Performance
#> [1] 75 95
```

A named `items` argument avoids positional mapping altogether, and is
the safer choice for an export you did not lay out yourself:

``` r

score_questionnaire(
  tlx, "nasa_tlx",
  scale = c(1, 21),
  items = c(
    mental = "mental", physical = "physical", temporal = "temporal",
    performance = "performance", effort = "effort", frustration = "frustration"
  )
)$RTLX
#> Scoring NASA Task Load Index, raw (RTLX) from 6 columns (mental ... frustration); no items reverse-coded.
#> CAUTION: item numbers, order and polarity depend on how the questionnaire
#> was administered -- survey tools renumber items, translations reorder them,
#> and short forms drop them. This package applies the PUBLISHED key. If your
#> sheet differed, the scores will be wrong without any error being raised.
#> Check the mapping against the survey your participants actually saw, and
#> double-check any number before it goes into a paper.
#>   See the full mapping with check_questionnaire(data, "nasa_tlx", ...); silence this note with options(colleyRstats.quiet_questionnaires = TRUE).
#> [1] 40.833333  8.333333
```

## Incomplete responses

By default a subscale is scored only if every one of its items was
answered, and is `NA` otherwise. Nothing is imputed silently.

``` r

gappy <- study
gappy$sus_3[1] <- NA

score_questionnaire(gappy, "sus", prefix = "sus_")$SUS[1]
#> [1] NA

# Score responses that are at least 80% complete
score_questionnaire(gappy, "sus", prefix = "sus_", min_valid = 0.8)$SUS[1]
#> [1] 44.44444
```

With `min_valid` relaxed, a subscale is the mean of the items present,
and a sum-scored instrument such as the SUS is scaled up proportionally
so it stays on its published 0–100 range.

## Internal consistency

[`score_reliability()`](https://m-colley.github.io/colleyRstats/reference/score_reliability.md)
computes Cronbach’s alpha on the same recoded matrix that is aggregated,
so reverse-coded items are already flipped:

``` r

score_reliability(study, "sus", prefix = "sus_")
#>       subscale n_items n_complete      alpha     omega mean_item_cor
#> 1    Usability       8          8 0.08806964 0.7100107   0.000716434
#> 2 Learnability       2          8 0.73003802        NA   0.575355962
```

Because the reversal has already happened, a negative alpha means a real
problem – the items of that subscale do not point the same way – rather
than a forgotten flip. It warns when one appears.

Do not read the values above as anything: the example responses are
random, so `Usability` is near zero as it should be, while the two-item
`Learnability` looks respectable purely by chance. Eight participants is
far too few to estimate alpha at all, which is itself worth remembering
– `n_complete` is reported next to it for that reason.

## Your own instruments

[`define_questionnaire()`](https://m-colley.github.io/colleyRstats/reference/define_questionnaire.md)
registers one, after which it behaves exactly like a built-in. Put the
call in a project’s setup script and every analysis in that project
scores it identically:

``` r

define_questionnaire(
  key = "acceptance",
  name = "Van der Laan acceptance scale",
  reference = "Van der Laan, Heino & De Waard (1997), Transp. Res. C 5(1)",
  scale = c(-2, 2),
  label = c(
    "useful - useless", "pleasant - unpleasant", "bad - good",
    "nice - annoying", "effective - superfluous", "irritating - likeable",
    "assisting - worthless", "undesirable - desirable",
    "raising alertness - sleep-inducing"
  ),
  subscale = rep(c("Usefulness", "Satisfying"), length.out = 9),
  reverse = c(1, 2, 4, 5, 7, 9),
  higher = "better"
)

vdl <- as.data.frame(matrix(c(-2, 2, -2, 2, -2, 2, -2, 2, -2), nrow = 1))
names(vdl) <- paste0("item", 1:9)

score_questionnaire(vdl, "acceptance")
#> Scoring Van der Laan acceptance scale from 9 columns (item1 ... item9); reverse-coded: item1, item2, item4, item5, item7, item9.
#> CAUTION: item numbers, order and polarity depend on how the questionnaire
#> was administered -- survey tools renumber items, translations reorder them,
#> and short forms drop them. This package applies the PUBLISHED key. If your
#> sheet differed, the scores will be wrong without any error being raised.
#> Check the mapping against the survey your participants actually saw, and
#> double-check any number before it goes into a paper.
#>   See the full mapping with check_questionnaire(data, "acceptance", ...); silence this note with options(colleyRstats.quiet_questionnaires = TRUE).
#>   Usefulness Satisfying
#> 1        1.2          0
```

## Sickness over time

FMS and MISC are single items sampled repeatedly during exposure, so the
analysis lives in the time course rather than in any one measurement.
[`summarize_sickness()`](https://m-colley.github.io/colleyRstats/reference/summarize_sickness.md)
produces the per-participant measures those studies report:

``` r

ratings <- data.frame(
  participant = rep(c("p1", "p2"), each = 5),
  minute = rep(0:4, 2),
  fms = c(0, 1, 3, 6, 8, 0, 0, 1, 1, 2)
)

summarize_sickness(ratings,
  value = "fms", id = "participant",
  time = "minute", threshold = 5
)
#>   participant n peak mean final auc auc_rate reached time_to_threshold
#> 1          p1 5    8  3.6     8  14     3.50    TRUE                 3
#> 2          p2 5    2  0.8     2   3     0.75   FALSE                NA
```

`auc` is the trapezoidal area under the rating curve and `auc_rate` is
that divided by the observed duration, i.e. the time-weighted mean
rating – which is comparable across participants who were exposed for
different lengths of time.

Note that MISC is *ordinal* and unevenly spaced: the step from 6
(nausea) to 10 (vomiting) is not four times the step from 0 to 1.
Analyse it with an ordinal model rather than by taking means.

You have to say so, though. A 0–10 MISC column has more distinct values
than
[`classify_outcome()`](https://m-colley.github.io/colleyRstats/reference/classify_outcome.md)’s
`ordinal_max_levels` of 7, so left to itself it is taken for a count and
[`recommend_test()`](https://m-colley.github.io/colleyRstats/reference/recommend_test.md)
proposes a Poisson GLMM:

``` r

misc <- data.frame(misc = c(0, 1, 3, 6, 10, 2, 4, 8))
classify_outcome(score_questionnaire(misc, "misc")$MISC)
#> Scoring Misery Scale (MISC) from 1 columns (misc ... misc); no items reverse-coded.
#> CAUTION: item numbers, order and polarity depend on how the questionnaire
#> was administered -- survey tools renumber items, translations reorder them,
#> and short forms drop them. This package applies the PUBLISHED key. If your
#> sheet differed, the scores will be wrong without any error being raised.
#> Check the mapping against the survey your participants actually saw, and
#> double-check any number before it goes into a paper.
#>   See the full mapping with check_questionnaire(data, "misc", ...); silence this note with options(colleyRstats.quiet_questionnaires = TRUE).
#> [1] "count"
```

Pass `outcome_type = "ordinal"` to
[`fit_recommended()`](https://m-colley.github.io/colleyRstats/reference/fit_recommended.md),
or raise `ordinal_max_levels` to 11.

## Onward

[`fit_recommended()`](https://m-colley.github.io/colleyRstats/reference/fit_recommended.md)
takes the scored data and fits the model each outcome calls for. Here is
the whole path, from raw items to a manuscript sentence:

``` r

set.seed(7)
trial <- expand.grid(
  participant = factor(1:12),
  condition = factor(c("baseline", "ambient", "explicit"))
)
effect <- c(baseline = 0, ambient = 0.6, explicit = 1.2)[trial$condition]
# Participants differ from one another too, which is what the random intercept
# of the mixed model is there to absorb.
person <- rnorm(12, 0, 0.6)[as.integer(trial$participant)]
for (i in 1:10) {
  raw <- 3 + effect + person + rnorm(nrow(trial), 0, 0.5)
  if (i %% 2 == 0) raw <- 6 - raw   # the even SUS items are negatively worded
  trial[[paste0("sus_", i)]] <- pmin(pmax(round(raw), 1), 5)
}

scored <- score_questionnaire(trial, "sus", prefix = "sus_", append = TRUE)

fit <- fit_recommended(
  scored,
  outcome = "SUS",
  predictors = "condition",
  cluster = "participant",
  verbose = FALSE
)

fit$recommendation$recommendation
#> [1] "Linear Mixed Model (LMM) / parametric within-subjects"
fit$text
#> [1] "A linear mixed model was fitted for SUS."                                                                                                    
#> [2] "The effect of \\textit{conditionbaseline} on SUS was significant ($b = 15.42$, 95\\% CI $[10.96, 19.88]$, $t(31) = 7.05$, \\pminor{0.001})." 
#> [3] "The effect of \\textit{conditionexplicit} on SUS was significant ($b = 24.79$, 95\\% CI $[20.33, 29.25]$, $t(31) = 11.34$, \\pminor{0.001})."
```

The sentence is LaTeX;
[`expand_latex_macros()`](https://m-colley.github.io/colleyRstats/reference/expand_latex_macros.md)
renders it as plain text if you want to read it here rather than paste
it into a manuscript.

Watch the classification when an outcome stays whole-numbered — a raw
NASA-TLX subscale or a MISC rating is taken for a count unless you say
`outcome_type = "continuous"` or `"ordinal"`. SUS and RTLX are
fractional, so they classify as continuous on their own.

[`use_study_project()`](https://m-colley.github.io/colleyRstats/reference/use_study_project.md)
scaffolds a whole analysis around this – scoring, models, figures, and
the generated LaTeX a manuscript reads – as a `targets` pipeline, and
writes those `outcome_type` declarations for you.
