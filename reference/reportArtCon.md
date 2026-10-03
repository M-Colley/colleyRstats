# Report significant ART contrasts (art.con) as LaTeX text

Companion to
[`reportDunnTest()`](https://m-colley.github.io/colleyRstats/reference/reportDunnTest.md)
for aligned-rank-transform (ART) models. It extracts the significant
pairwise comparisons produced by
[`ARTool::art.con()`](https://rdrr.io/pkg/ARTool/man/art.con.html) (an
emmeans contrast grid), describes the groups involved from the raw data,
and prints LaTeX-formatted sentences such as "An ART-C post-hoc test
(Holm-adjusted) found that ...".

## Usage

``` r
reportArtCon(
  ac,
  data,
  iv = "testiv",
  dv = "testdv",
  paired = FALSE,
  id = NULL,
  sink_to = NULL,
  descriptives = c("auto", "mean", "median", "trimmed")
)

report_art_con(
  ac,
  data,
  iv = "testiv",
  dv = "testdv",
  paired = FALSE,
  id = NULL,
  sink_to = NULL,
  descriptives = c("auto", "mean", "median", "trimmed")
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

- descriptives:

  which descriptives to print beside each level: `"auto"` (default,
  median and IQR for this rank-based test), `"mean"`, `"median"` or
  `"trimmed"` (20% trimmed mean and 20% winsorized SD).

## Value

Invisibly returns the reported sentence(s) as a character vector; the
text is also emitted via
[`message()`](https://rdrr.io/r/base/message.html).

## Details

The p-values are taken as-is from the contrast object, i.e. they are
already adjusted by whatever `adjust` was passed to `art.con()` (e.g.
`"holm"`), and that correction – read from the contrast summary – is
named in the sentence. With `adjust = "none"` the p-values are emitted
as `\p{}`/`\pminor{}` rather than as \\p\_{adj}\\. The effect size is
the rank-biserial correlation computed from the raw data. ART is most
often used for within-subjects designs; pass `paired = TRUE` together
with `id` (the subject column) to obtain the paired rank-biserial effect
size.

Which level is "higher" follows the sign of the contrast estimate (first
minus second level, on the aligned-rank scale). Until 0.3.0 it followed
the raw means, which can disagree with the test. By default
(`descriptives = "auto"`) the levels are described by their median and
IQR, which match a rank-based test; `"mean"` restores *M*/*SD* and warns
where the means order two levels against the contrast.

The two levels of each contrast are read from the contrast coefficients,
so level names that emmeans rewrites in its labels – numbers ("mode1 -
mode2") or names containing `-`, `+`, `*` or `/` ("Both - (Hand-only)")
– are handled.

Attention: `ac` must be a pairwise contrast over a single factor `iv`
(e.g. `art.con(model, ~ interaction_mode, adjust = "holm")`).

Required commands in LaTeX (all part of
[`latex_preamble()`](https://m-colley.github.io/colleyRstats/reference/latex_preamble.md)):
`\padj`, `\padjminor`, `\p`, `\pminor`, `\mdn`, `\iqr`, `\m`, `\sd` and
`\newcommand{\rankbiserial}[1]{$r_{rb} = #1$}`.

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
#> An ART-C post-hoc test (Holm-adjusted) found that score for the \mode{} Eye was significantly higher (\mdn{3.86}, \iqr{1.37}) than for Both (\mdn{1.96}, \iqr{1.05}; \padjminor{0.001}, \rankbiserial{0.97}). 
#> An ART-C post-hoc test (Holm-adjusted) found that score for the \mode{} Hand was significantly higher (\mdn{6.12}, \iqr{1.04}) than for Both (\mdn{1.96}, \iqr{1.05}; \padjminor{0.001}, \rankbiserial{1.00}) and Eye (\mdn{3.86}, \iqr{1.37}; \padjminor{0.001}, \rankbiserial{1.00}). 
# }
```
