# Define a named LaTeX macro for a single result (single source of truth)

Emits `\newcommand{\<name>}{<value>}` so you can write `\<name>` in your
prose and have it always reflect the latest analysis – re-run the R code
and the number updates everywhere it is referenced, the gold standard
for reproducible manuscripts. The `name` is sanitised to a valid
letters-only LaTeX command name.

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
  inserted verbatim (already-formatted LaTeX), not escaped.

- path:

  Optional `.tex` path. When supplied and it already exists, the
  definition is appended (so many results can accumulate in one file).

## Value

Invisibly, a named character scalar: the `\newcommand` line, named by
the generated command. Also emitted via
[`message()`](https://rdrr.io/r/base/message.html).

## Examples

``` r
define_result_macro("tlx_mental_omnibus", "F(2, 57) = 4.50, p = .02")
#> \newcommand{\tlxMentalOmnibus}{F(2, 57) = 4.50, p = .02}
```
