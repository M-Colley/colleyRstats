# Report significant ART contrasts (art.con) as LaTeX text

Companion to
[`reportDunnTest()`](https://m-colley.github.io/colleyRstats/reference/reportDunnTest.md)
for aligned-rank-transform (ART) models. It extracts the significant
pairwise comparisons produced by
[`ARTool::art.con()`](https://rdrr.io/pkg/ARTool/man/art.con.html) (an
emmeans contrast grid), computes the mean and standard deviation of the
groups involved from the raw data, and prints LaTeX-formatted sentences.

## Usage

``` r
reportArtCon(
  ac,
  data,
  iv = "testiv",
  dv = "testdv",
  paired = FALSE,
  id = NULL,
  sink_to = NULL
)

report_art_con(
  ac,
  data,
  iv = "testiv",
  dv = "testdv",
  paired = FALSE,
  id = NULL,
  sink_to = NULL
)
```

## Arguments

- ac:

  the contrast object returned by
  [`ARTool::art.con()`](https://rdrr.io/pkg/ARTool/man/art.con.html) (or
  its [`summary()`](https://rdrr.io/r/base/summary.html))

- data:

  the raw data frame used to fit the model

- iv:

  independent variable (the contrasted factor)

- dv:

  dependent variable

- paired:

  whether to compute the rank-biserial effect size for paired
  (within-subjects) data. Defaults to `FALSE`. When `TRUE`, `id` is
  required.

- id:

  the subject/pairing column, used only when `paired = TRUE`. Replicate
  trials per subject and condition are averaged before pairing.

- sink_to:

  optional path of a `.tex` file to write the sentences to, so a
  manuscript can `\input{}` them

## Value

Invisibly returns the reported sentence(s) as a character vector; the
text is also emitted via
[`message()`](https://rdrr.io/r/base/message.html).

## Details

The p-values are taken as-is from the contrast object, i.e. they are
already adjusted by whatever `adjust` was passed to `art.con()` (e.g.
`"holm"`). The effect size is the rank-biserial correlation computed
from the raw data. ART is most often used for within-subjects designs;
pass `paired = TRUE` together with `id` (the subject column) to obtain
the paired rank-biserial effect size.

Attention: `ac` must be a pairwise contrast over a single factor `iv`
(e.g. `art.con(model, ~ interaction_mode, adjust = "holm")`).

Required commands in LaTeX:
`\newcommand{\padjminor}{\textit{p$_{adj}<$}}`
`\newcommand{\padj}{\textit{p$_{adj}$=}}`
`\newcommand{\rankbiserial}[1]{$r_{rb} = #1$}`

## Naming

`report_art_con()` is the spelling used throughout the documentation and
the one to prefer in new code: the `report_*` / `plot_*` / `check_*`
prefixes make the API discoverable through autocomplete.

`reportArtCon()` **\[superseded\]** is the original name. Both names
refer to the same function object, so they are entirely interchangeable;
the original remains fully supported and is not scheduled for removal,
and existing scripts keep working unchanged.

## Examples

``` r
# \donttest{
if (requireNamespace("ARTool", quietly = TRUE) &&
  requireNamespace("emmeans", quietly = TRUE)) {
  set.seed(123)
  n <- 20
  df <- data.frame(
    UserID = factor(rep(seq_len(n), times = 3)),
    mode   = factor(rep(c("Hand", "Eye", "Both"), each = n)),
    prime  = factor(rep(rep(c("A", "B"), each = n / 2), times = 3))
  )
  df$score <- as.numeric(df$mode) * 2 + stats::rnorm(nrow(df))

  m  <- ARTool::art(score ~ mode * prime + Error(UserID / mode), data = df)
  ac <- ARTool::art.con(m, ~ mode, adjust = "holm")
  reportArtCon(ac, data = df, iv = "mode", dv = "score", paired = TRUE, id = "UserID")
}
#> NOTE: Results may be misleading due to involvement in interactions
#> A post-hoc test found that score for the \mode Eye was significantly higher (\m{3.95}, \sd{0.83}) than for Both (\m{2.11}, \sd{0.96}; \padjminor{0.001}, \rankbiserial{0.97}). 
#> A post-hoc test found that score for the \mode Hand was significantly higher (\m{6.14}, \sd{0.97}) than for Both (\m{2.11}, \sd{0.96}; \padjminor{0.001}, \rankbiserial{1.00}) and Eye (\m{3.95}, \sd{0.83}; \padjminor{0.001}, \rankbiserial{1.00}). 
# }
```
