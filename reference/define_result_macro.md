# Define a named LaTeX macro for a single result (single source of truth)

Emits `\newcommand{\<name>}{<value>}` so you can write `\<name>` in your
prose and have it always reflect the latest analysis – re-run the R code
and the number updates everywhere it is referenced, the gold standard
for reproducible manuscripts. The `name` is sanitised to a letters-only
LaTeX command name: other characters start a new camel-case word and
digits are spelled out, so `"tlx_1"` and `"tlx_2"` become `\tlxOne` and
`\tlxTwo` rather than colliding. A name that would redefine an existing
LaTeX or colleyRstats command (e.g. `"p"`, which is the package's own
`\p`, or `"time"`) is refused with an error that suggests an
alternative.

## Usage

``` r
define_result_macro(name, value, path = NULL)
```

## Arguments

- name:

  A label for the result, e.g. `"tlx_mental_omnibus"` (becomes
  `\tlxMentalOmnibus`).

- value:

  The rendered result string, e.g. `"F(2, 57) = 4.50, p = .02"`. It is
  inserted verbatim (already-formatted LaTeX), not escaped. Several
  strings are joined with spaces, and line breaks become spaces, so each
  definition occupies exactly one line.

- path:

  Optional `.tex` path. When it already exists, the definition is added
  to it (so many results can accumulate in one file); a definition of
  the same command already in the file is replaced rather than
  duplicated, because a second `\newcommand` for one name stops the
  build. Each line ends in a `%` comment naming the label it came from,
  so that a different label mapping to the same command (`"tlx1"` and
  `"tlx_1"` are both `\tlxOne`) is reported when it replaces the other's
  result.

## Value

Invisibly, a named character scalar: the `\newcommand` line, named by
the generated command. Also emitted via
[`message()`](https://rdrr.io/r/base/message.html).

## Examples

``` r
define_result_macro("tlx_mental_omnibus", "F(2, 57) = 4.50, p = .02")
#> \newcommand{\tlxMentalOmnibus}{F(2, 57) = 4.50, p = .02}% tlx_mental_omnibus
```
