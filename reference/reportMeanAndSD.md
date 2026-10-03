# Report the mean and standard deviation of a dependent variable for all levels of an independent variable rounded to the 2nd digit.

Each level yields one line such as `A: \m{4.21}, \sd{1.03}`, with the
level name escaped for LaTeX. Written to `sink_to`, the lines are joined
into one compilable sentence ("A: ...; B: ...."). Until 0.3.0 every line
was a LaTeX comment (it began with a percent sign), so an `\input{}` of
the file typeset nothing; `as_comment = TRUE` restores that form for
notes kept next to a manuscript.

## Usage

``` r
reportMeanAndSD(
  data,
  iv = "testiv",
  dv = "testdv",
  sink_to = NULL,
  as_comment = FALSE
)

report_mean_sd(
  data,
  iv = "testiv",
  dv = "testdv",
  sink_to = NULL,
  as_comment = FALSE
)
```

## Arguments

- data:

  the data frame

- iv:

  the independent variable

- dv:

  the dependent variable

- sink_to:

  optional path of a `.tex` file to write the lines to, so a manuscript
  can `\input{}` them

- as_comment:

  if `TRUE`, every line is prefixed with a percent sign (a LaTeX
  comment) and written one per line, as before 0.3.0. Defaults to
  `FALSE`: real text.

## Value

Invisibly returns the formatted lines (one per level) as a character
vector; the text is also emitted via
[`message()`](https://rdrr.io/r/base/message.html).

## Details

To easily copy and paste the results to your manuscript, the following
commands must be defined in Latex: `\newcommand{\m}{\textit{M=}}`
`\newcommand{\sd}{\textit{SD=}}`

## Naming

`report_mean_sd()` is the spelling used throughout the documentation and
the one to prefer in new code: the `report_*` / `plot_*` / `check_*`
prefixes make the API discoverable through autocomplete.

`reportMeanAndSD()` **\[superseded\]** is the original name. Both names
refer to the same function object, so they are entirely interchangeable;
the original remains fully supported and is not scheduled for removal,
and existing scripts keep working unchanged.

## Examples

``` r
# \donttest{

example_data <- data.frame(Condition = rep(c("A", "B", "C"),
each = 10), TLX1 = stats::rnorm(30))

reportMeanAndSD(example_data, iv = "Condition", dv = "TLX1")
#> A: \m{0.12}, \sd{0.94}
#> B: \m{-0.36}, \sd{1.00}
#> C: \m{0.31}, \sd{0.55}
# }
```
