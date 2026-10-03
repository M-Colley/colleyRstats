# Report significant post-hoc pairwise comparisons

This function extracts significant pairwise comparisons from a
`ggstatsplot` object, describes the groups involved from the raw data,
and prints LaTeX-formatted sentences reporting the results.

## Usage

``` r
reportggstatsplotPostHoc(
  data,
  p,
  iv = "testiv",
  dv = "testdv",
  label_mappings = NULL,
  sink_to = NULL,
  descriptives = c("auto", "mean", "median", "trimmed"),
  subject = NULL
)

report_ggstatsplot_posthoc(
  data,
  p,
  iv = "testiv",
  dv = "testdv",
  label_mappings = NULL,
  sink_to = NULL,
  descriptives = c("auto", "mean", "median", "trimmed"),
  subject = NULL
)
```

## Arguments

- data:

  A data frame containing the raw data used to generate the plot.

- p:

  A `ggstatsplot` object (e.g., returned by `ggbetweenstats`) containing
  the pairwise comparison statistics.

- iv:

  Character string. The column name of the independent variable
  (grouping variable).

- dv:

  Character string. The column name of the dependent variable.

- label_mappings:

  Optional named list or vector. Used to rename factor levels in the
  output text (e.g., `list("old_name" = "New Label")`).

- sink_to:

  optional path of a `.tex` file to write the sentences to, so a
  manuscript can `\input{}` them. It is written in every case, including
  when nothing is significant, so a manuscript never keeps a stale
  result.

- descriptives:

  which descriptives to print beside each level: `"auto"` (default; the
  ones matching the test, see Details), `"mean"` (*M*, *SD*), `"median"`
  (*Mdn*, *IQR*) or `"trimmed"` (20% trimmed mean, 20% winsorized SD).

- subject:

  optional column name identifying participants in a within-subjects
  ([`ggwithinstats()`](https://www.indrapatil.com/ggstatsplot/reference/ggwithinstats.html))
  plot. When given, the descriptives and any direction statistic are
  computed only from participants observed in every level of `iv`, one
  row per participant and level.

## Value

Invisibly returns the reported sentence(s) as a character vector; the
text is also emitted via
[`message()`](https://rdrr.io/r/base/message.html).

## Details

Each sentence names the post-hoc test that produced the comparison and
the multiplicity correction applied to its p-value, both read from the
pairwise table `ggstatsplot` attaches to the plot (e.g. "A Games-Howell
post-hoc test (Holm-adjusted) found that ..."). Which test that is
depends on the `type` of the plot and on whether it is between- or
within-subjects – Games-Howell, Dunn, Durbin-Conover, Student's t or
Yuen's trimmed means – so it is worth reporting rather than assuming.
When the plot carries no such information (an older `ggstatsplot`, or a
hand-built table) the sentence falls back to a plain "A post-hoc test
...".

## Direction and descriptives

Which level "was significantly higher" is decided by the quantity the
test compares, computed from `data`: the means for Student's t and
Games-Howell, the mean ranks of the pooled ranking for Dunn, the
within-participant rank sums for Durbin-Conover, and the 20% trimmed
means for Yuen's test (taken from the sign of the `estimate` column of
the pairwise table when it is present). Until 0.3.0 the direction always
came from the raw means, which contradicts a rank-based test whenever
outliers or skew pull a mean – the situation in which such a test is
chosen.

The descriptives printed beside each level match the test by default
(`descriptives = "auto"`): `\m{}`/`\sd{}` for the mean-based tests,
`\mdn{}`/`\iqr{}` for the rank-based ones, and the 20% trimmed mean
\\M_t\\ with the 20% winsorized standard deviation \\SD_w\\ for Yuen's
test. Any of these can be forced; a warning is given when the forced
descriptives order two levels against the test's direction.

For a within-subjects plot pass `subject`:
[`ggwithinstats()`](https://www.indrapatil.com/ggstatsplot/reference/ggwithinstats.html)
tests only the participants observed in every level, and with `subject`
the descriptives (and the Durbin-Conover rank sums) are computed from
exactly those participants. Without it, all rows are described, and a
Durbin-Conover table pairs observations by row order within each level –
what
[`ggwithinstats()`](https://www.indrapatil.com/ggstatsplot/reference/ggwithinstats.html)
itself does without `subject.id` – with a warning.

## LaTeX Requirements

To easily copy and paste the results to your manuscript, the commands of
[`latex_preamble()`](https://m-colley.github.io/colleyRstats/reference/latex_preamble.md)
(or the shipped `colleyRstats.sty`) must be defined: `\m`, `\sd`,
`\mdn`, `\iqr`, `\padj`, `\padjminor`, `\p` and `\pminor`.

`\p`/`\pminor` are used only when the plot reports
`p.adjust.method = "None"`: those p-values are uncorrected and must not
be labelled \\p\_{adj}\\.

## Naming

`report_ggstatsplot_posthoc()` is the spelling used throughout the
documentation and the one to prefer in new code: the `report_*` /
`plot_*` / `check_*` prefixes make the API discoverable through
autocomplete.

`reportggstatsplotPostHoc()` **\[superseded\]** is the original name.
Both names refer to the same function object, so they are entirely
interchangeable; the original remains fully supported and is not
scheduled for removal, and existing scripts keep working unchanged.

## Examples

``` r
# \donttest{
library(ggstatsplot)
library(dplyr)

# Generate a plot (a factor with three levels, so there are pairwise tests)
plt <- ggbetweenstats(mtcars, cyl, mpg)

# Report stats
reportggstatsplotPostHoc(
  data = mtcars,
  p = plt,
  iv = "cyl",
  dv = "mpg",
  label_mappings = list("4" = "four cylinders")
)
#> A Games-Howell post-hoc test (Holm-adjusted) found that four cylinders was significantly higher (\m{26.66}, \sd{4.51}) in terms of mpg compared to 6 (\m{19.74}, \sd{1.45}; \padj{0.001}). 
#> A Games-Howell post-hoc test (Holm-adjusted) found that four cylinders was significantly higher (\m{26.66}, \sd{4.51}) in terms of mpg compared to 8 (\m{15.10}, \sd{2.56}; \padjminor{0.001}). 
#> A Games-Howell post-hoc test (Holm-adjusted) found that 6 was significantly higher (\m{19.74}, \sd{1.45}) in terms of mpg compared to 8 (\m{15.10}, \sd{2.56}; \padjminor{0.001}). 
# }
```
