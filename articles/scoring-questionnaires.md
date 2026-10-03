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
#>                    key                                              name
#> 1           attrakdiff                                      AttrakDiff 2
#> 2  attrakdiff_official     AttrakDiff 2 (official sheet order and poles)
#> 3                  fms                  Fast Motion Sickness Scale (FMS)
#> 4                  ipq               igroup Presence Questionnaire (IPQ)
#> 5                 misc                               Misery Scale (MISC)
#> 6             nasa_tlx                  NASA Task Load Index, raw (RTLX)
#> 7                  ssq            Simulator Sickness Questionnaire (SSQ)
#> 8                  sus                      System Usability Scale (SUS)
#> 9                  tia                         Trust in Automation (TiA)
#> 10                 ueq    User Experience Questionnaire (UEQ), full form
#> 11               ueq_s User Experience Questionnaire, short form (UEQ-S)
#>    n_items n_subscales scale
#> 1       28           4   1-7
#> 2       28           4   1-7
#> 3        1           1  0-20
#> 4       14           4   0-6
#> 5        1           1  0-10
#> 6        6           6 0-100
#> 7       16           3   0-3
#> 8       10           2   1-5
#> 9       19           6   1-5
#> 10      26           6   1-7
#> 11       8           2   1-7
```

## Scoring

Point it at the item columns. A prefix is usually enough:

``` r

set.seed(1)
study <- data.frame(participant = factor(1:8))
study[paste0("sus_", 1:10)] <- lapply(1:10, function(i) sample(1:5, 8, TRUE))

score_questionnaire(study, "sus", prefix = "sus_")
#> Scoring System Usability Scale (SUS) from 10 columns (sus_1 ... sus_10, matched by item number); responses observed 1 to 5 on the assumed range 1 to 5; reverse-coded: sus2, sus4, sus6, sus8, sus10.
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

A prefix selects the columns, and their *names* then say which item each
one holds – never their sort order, which would put `sus_10` before
`sus_2`, or `tlx_effort` before `tlx_mental`. Either what follows the
prefix is the item’s code or label, compared without case or
punctuation:

``` r

tlx_named <- data.frame(
  tlx_effort = 50, tlx_frustration = 60, tlx_mental = 10,
  tlx_performance = 40, tlx_physical = 20, tlx_temporal = 30
)
score_questionnaire(tlx_named, "nasa_tlx", prefix = "tlx_")$Mental_Demand
#> Scoring NASA Task Load Index, raw (RTLX) from 6 columns (tlx_mental ... tlx_frustration, matched by item name); responses observed 10 to 60 on the assumed range 0 to 100; no items reverse-coded.
#> CAUTION: item numbers, order and polarity depend on how the questionnaire
#> was administered -- survey tools renumber items, translations reorder them,
#> and short forms drop them. This package applies the PUBLISHED key. If your
#> sheet differed, the scores will be wrong without any error being raised.
#> Check the mapping against the survey your participants actually saw, and
#> double-check any number before it goes into a paper.
#>   See the full mapping with check_questionnaire(data, "nasa_tlx", ...); silence this note with options(colleyRstats.quiet_questionnaires = TRUE).
#> [1] 10
```

or it carries one item number per column, running exactly 1 to the
number of items (`sus_2`, `SUS[2]`, or `SUS_2_1`, where the number that
varies across the columns is the item). Names that do neither – a
partial match, numbering from 0 – are an error asking for a named
`items` mapping rather than a guess.

### Item columns must be numbers

Survey exports often deliver responses as text. A column holding
`"Strongly agree"`, `"5 - Strongly agree"` or a decimal comma such as
`"2,5"` stops scoring with an error that names the values and says how
to recode them: converting them would silently turn those answers into
missing values, and with a relaxed `min_valid` the row would be scored
as if the participant had skipped them. Blank cells are missing
responses. Factors are read by their labels when those are numbers, and
by level order only when the factor is ordered.

``` r

text_export <- study
text_export$sus_3 <- as.character(text_export$sus_3)
text_export$sus_3[1] <- "Strongly agree"
try(score_questionnaire(text_export, "sus", prefix = "sus_"))
#> Error : Column 'sus_3' holds values that are not numbers: 'Strongly agree'. Converting them would silently turn those responses into missing values and score the remaining items as if they had been skipped. Recode the column to numbers first. For response labels ("Strongly agree"): recode them to their scale values, e.g. unname(c("Strongly disagree" = 1, ..., "Strongly agree" = 5)[x]), or export numeric codes from the survey tool.
```

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
#> Scoring NASA Task Load Index, raw (RTLX) from 6 columns (mental ... frustration, matched by item code); responses observed 1 to 14 on the assumed range 1 to 21; no items reverse-coded.
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

The quieter failure is a coding that fits the range but is shifted
against it. The scoring message prints the observed range next to the
assumed one, and without an explicit `scale` three patterns draw a
warning: NASA-TLX responses that never exceed 21 (the 21-point sheet,
which scored as 0–100 understates workload about five-fold); no response
at 0 on a zero-based instrument such as the IPQ or SSQ (a 1-based export
in which nobody chose the top point); and no response at the top of a
one-based instrument such as the SUS (a 0-based export in which nobody
chose 0). The last two need at least five respondents. Passing `scale`
explicitly confirms the coding and silences them.

``` r

# The same 21-point responses, without saying so: RTLX comes out five times too low
score_questionnaire(tlx, "nasa_tlx")$RTLX
#> Warning: NASA Task Load Index, raw (RTLX): responses run only from 1 to 14,
#> although the assumed range is 0-100. That is the signature of the 21-point
#> paper sheet or a 20-point slider; scored as 0-100 it understates workload about
#> five-fold. Pass scale = c(1, 21) (or c(1, 20)) if so, or scale = c(0, 100) to
#> confirm the data really are on 0-100 and silence this warning.
#> [1] 9.166667 2.666667
```

A fractional response on an instrument answered in whole scale points
(every built-in one except the NASA-TLX) warns too: it is an averaged,
imputed or mis-exported column rather than a response.

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
key — the right default, and still only a default. Whatever your columns
are called, the instrument’s item 3 is taken to be the question your
participants saw third; if your sheet ordered, worded or poled them
differently, the scores look entirely reasonable and are wrong. (An
unnamed `items` vector is mapped by position, too.)

AttrakDiff is the case in point. The `attrakdiff` key lists its 28 word
pairs blocked by dimension, each with its negative term first – the
layout of data that has already been re-sorted and re-poled, not of the
official form. Data stored as answered on the official sheet, which
interleaves the pairs and prints 15 of them with the positive term on
the left, belong to `"attrakdiff_official"`. Both keys use the same item
codes for the same word pairs, so a named `items` mapping works with
either.

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
#> Observed responses: 1 to 5
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
#>   - Missing items: Brooke (1996) instructs a respondent who cannot answer an item to mark the centre point of the scale, so when `min_valid` < 1 lets an incomplete row be scored, each missing item counts as the centre (3 on 1-5). One missing item in an otherwise perfect response therefore gives 95, not 100. Pass impute = "prorate" to scale up from the answered items instead, and say which rule you used.
#>   - Learnability has only two items. score_reliability() reports the Spearman-Brown coefficient for it, which Eisinga, te Grotenhuis & Pelzer (2013) recommend over alpha for two-item scales.
```

It shows which column supplies which item, which subscale that item
loads on, whether it is reverse-coded, and the observed range of each
column – so a column of all-3s where you expected variation, or a 1–7
export where the instrument expects 1–5, is visible immediately.

If your survey printed a pair the other way round, `reverse_items`
reverses it in addition to the key’s own reversals:

``` r

# A survey that anchored NASA-TLX performance "Good" at the high end
scores <- score_questionnaire(tlx, "nasa_tlx",
  scale = c(1, 21),
  reverse_items = "performance"
)
#> Scoring NASA Task Load Index, raw (RTLX) from 6 columns (mental ... frustration, matched by item code); responses observed 1 to 14 on the assumed range 1 to 21; reverse-coded: performance.
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

Do not pass an instrument’s own reverse set there. `reverse_items`
*toggles*, for backward compatibility, so
`reverse_items = c(2, 4, 6, 8, 10)` on the SUS – a line many tutorials
contain – un-reverses all five negatively worded items, and a perfect
respondent scores 50. That now raises a warning. If an export genuinely
stored items that the key reverses already reversed, say so with
`unreverse_items`, which does the same on purpose and without a warning:

``` r

perfect <- data.frame(t(c(5, 1, 5, 1, 5, 1, 5, 1, 5, 1)))
names(perfect) <- paste0("sus_", 1:10)
score_questionnaire(perfect, "sus", prefix = "sus_")$SUS
#> [1] 100

# Items 2 and 4 were stored pre-reversed by the survey tool
pre_reversed <- perfect
pre_reversed[c("sus_2", "sus_4")] <- 5
score_questionnaire(pre_reversed, "sus", prefix = "sus_",
  unreverse_items = c("sus2", "sus4")
)$SUS
#> Scoring System Usability Scale (SUS) from 10 columns (sus_1 ... sus_10, matched by item number); responses observed 1 to 5 on the assumed range 1 to 5; reverse-coded: sus6, sus8, sus10.
#> CAUTION: item numbers, order and polarity depend on how the questionnaire
#> was administered -- survey tools renumber items, translations reorder them,
#> and short forms drop them. This package applies the PUBLISHED key. If your
#> sheet differed, the scores will be wrong without any error being raised.
#> Check the mapping against the survey your participants actually saw, and
#> double-check any number before it goes into a paper.
#>   See the full mapping with check_questionnaire(data, "sus", ...); silence this note with options(colleyRstats.quiet_questionnaires = TRUE).
#> [1] 100
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
#> Scoring NASA Task Load Index, raw (RTLX) from 6 columns (mental ... frustration, matched by item code (named `items`)); responses observed 1 to 14 on the assumed range 1 to 21; no items reverse-coded.
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
#> Scoring System Usability Scale (SUS) from 10 columns (sus_1 ... sus_10, matched by item number); responses observed 1 to 5 on the assumed range 1 to 5; reverse-coded: sus2, sus4, sus6, sus8, sus10.
#> CAUTION: item numbers, order and polarity depend on how the questionnaire
#> was administered -- survey tools renumber items, translations reorder them,
#> and short forms drop them. This package applies the PUBLISHED key. If your
#> sheet differed, the scores will be wrong without any error being raised.
#> Check the mapping against the survey your participants actually saw, and
#> double-check any number before it goes into a paper.
#>   See the full mapping with check_questionnaire(data, "sus", ...); silence this note with options(colleyRstats.quiet_questionnaires = TRUE).
#> [1] NA

# Score responses that are at least 80% complete
score_questionnaire(gappy, "sus", prefix = "sus_", min_valid = 0.8)$SUS[1]
#> [1] 45
```

With `min_valid` relaxed, the missing items are completed by the
instrument’s published rule. For the SUS that is Brooke’s (1996): a
respondent who cannot answer an item marks the centre point, so each
missing item counts as 3 on 1–5. One missing item in an otherwise
perfect response gives 95, not 100. For every other instrument a
subscale is the mean of the items present, with a summed score scaled up
proportionally so it stays on its published range. `impute = "prorate"`
or `impute = "midpoint"` chooses a rule explicitly – report which one
you used:

``` r

score_questionnaire(gappy, "sus", prefix = "sus_", min_valid = 0.8,
  impute = "prorate"
)$SUS[1]
#> [1] 44.44444
```

## Internal consistency

[`score_reliability()`](https://m-colley.github.io/colleyRstats/reference/score_reliability.md)
computes Cronbach’s alpha on the same recoded matrix that is aggregated,
so reverse-coded items are already flipped. It reports every subscale,
plus the whole scale where the instrument defines an overall score – the
ten-item SUS alpha that SUS papers report:

``` r

score_reliability(study, "sus", prefix = "sus_")
#>       subscale n_items n_complete      alpha     omega spearman_brown
#> 1    Usability       8          8 0.08806964 0.2891371             NA
#> 2 Learnability       2          8 0.73003802        NA      0.7304457
#> 3          SUS      10          8 0.38154446 0.5230492             NA
#>   mean_item_cor
#> 1   0.000716434
#> 2   0.575355962
#> 3   0.056951282
#>                                                                               note
#> 1                                                                                 
#> 2 two items: report spearman_brown (Eisinga et al., 2013); omega is not identified
#> 3
```

Because the reversal has already happened, a negative alpha means a real
problem – the items of that subscale do not point the same way – rather
than a forgotten flip. It warns when one appears.

McDonald’s omega (total) comes from an unrotated one-factor solution
([`psych::fa()`](https://rdrr.io/pkg/psych/man/fa.html)), so it needs
‘psych’ but not ‘GPArotation’, and – unlike
[`psych::omega()`](https://rdrr.io/pkg/psych/man/omega.html) – does not
flip negatively loading items, which would hide the very reversal error
a negative alpha exposes. For two-item scales, such as SUS Learnability,
omega is not identified and alpha understates reliability whenever the
two item variances differ; `spearman_brown` gives the coefficient
Eisinga, te Grotenhuis and Pelzer (2013) recommend instead. The `note`
column says why any coefficient is missing.

Do not read the values above as anything: the example responses are
random, so any coefficient that looks respectable does so purely by
chance. Eight participants is far too few to estimate reliability at
all, which is itself worth remembering – `n_complete` is reported next
to it for that reason.

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
#> Scoring Van der Laan acceptance scale from 9 columns (item1 ... item9, matched by item code); responses observed -2 to 2 on the assumed range -2 to 2; reverse-coded: item1, item2, item4, item5, item7, item9.
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
#> Scoring Misery Scale (MISC) from 1 column (misc, matched by item code); responses observed 0 to 10 on the assumed range 0 to 10; no items reverse-coded.
#> CAUTION: item numbers, order and polarity depend on how the questionnaire
#> was administered -- survey tools renumber items, translations reorder them,
#> and short forms drop them. This package applies the PUBLISHED key. If your
#> sheet differed, the scores will be wrong without any error being raised.
#> Check the mapping against the survey your participants actually saw, and
#> double-check any number before it goes into a paper.
#>   See the full mapping with check_questionnaire(data, "misc", ...); silence this note with options(colleyRstats.quiet_questionnaires = TRUE).
#> The outcome holds non-negative whole numbers (8 distinct values, 0-10), so it is classified as a count and modelled with a Poisson (or, if over-dispersed, negative-binomial) model. If it is a rating, a summed questionnaire score or another bounded scale rather than a count of events, pass outcome_type = "continuous" (or "ordinal").
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
#> [1] "Linear Mixed Model (LMM)"
fit$text
#> [1] "A linear mixed model was fitted for SUS. Model terms were tested with Type III $F$-tests and coefficients with $t$-tests, using Satterthwaite's degrees of freedom. Coefficients are treatment contrasts against each factor's reference level."
#> [2] "The main effect of \\textit{condition} on SUS was significant (\\F{2}{22}{65.57}, \\pminor{0.001})."                                                                                                                                            
#> [3] "The contrast \\textit{baseline} vs.\\ \\textit{ambient} of \\textit{condition} on SUS was significant ($b = 15.42$, 95\\% CI $[10.88, 19.95]$, $t(22) = 7.05$, \\pminor{0.001})."                                                               
#> [4] "The contrast \\textit{explicit} vs.\\ \\textit{ambient} of \\textit{condition} on SUS was significant ($b = 24.79$, 95\\% CI $[20.26, 29.33]$, $t(22) = 11.34$, \\pminor{0.001})."
```

The sentence is LaTeX;
[`expand_latex_macros()`](https://m-colley.github.io/colleyRstats/reference/expand_latex_macros.md)
renders it as plain text if you want to read it here rather than paste
it into a manuscript.

Watch the classification when an outcome stays whole-numbered. A raw
NASA-TLX subscale scored onto 0–100 moves in steps of 5 and is
recognised as a bounded score (continuous), but a MISC rating or another
whole-numbered rating is taken for a count – with a message saying so –
unless you pass `outcome_type = "continuous"` or `"ordinal"`. SUS and
RTLX are fractional, so they classify as continuous on their own.

[`use_study_project()`](https://m-colley.github.io/colleyRstats/reference/use_study_project.md)
scaffolds a whole analysis around this – scoring, models, figures, and
the generated LaTeX a manuscript reads – as a `targets` pipeline, and
writes those `outcome_type` declarations for you.
