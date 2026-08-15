# Report significant post-hoc pairwise comparisons

This function extracts significant pairwise comparisons from a
`ggstatsplot` object, calculates the mean and standard deviation for the
groups involved using the raw data, and prints LaTeX-formatted sentences
reporting the results.

## Usage

``` r
reportggstatsplotPostHoc(
  data,
  p,
  iv = "testiv",
  dv = "testdv",
  label_mappings = NULL,
  sink_to = NULL
)

report_ggstatsplot_posthoc(
  data,
  p,
  iv = "testiv",
  dv = "testdv",
  label_mappings = NULL,
  sink_to = NULL
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
  manuscript can `\input{}` them

## Value

Invisibly returns the reported sentence(s) as a character vector; the
text is also emitted via
[`message()`](https://rdrr.io/r/base/message.html).

## LaTeX Requirements

To easily copy and paste the results to your manuscript, the following
commands (or similar) must be defined in your LaTeX preamble, as the
function outputs commands taking arguments (e.g., `\m{value}`):


      \newcommand{\m}[1]{\textit{M}=#1}
      \newcommand{\sd}[1]{\textit{SD}=#1}
      \newcommand{\padj}[1]{$p_{adj}=#1$}
      \newcommand{\padjminor}[1]{$p_{adj}<#1$}

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

# Generate a plot
plt <- ggbetweenstats(mtcars, am, mpg)

# Report stats
reportggstatsplotPostHoc(
  data = mtcars,
  p = plt,
  iv = "am",
  dv = "mpg",
  label_mappings = list("0" = "Automatic", "1" = "Manual")
)
#> No pairwise comparison data found for mpg. 
# }
```
