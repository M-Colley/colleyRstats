# Generate \newcommand stubs for variable/factor names

The report functions can emit variable and factor-level names as LaTeX
commands (e.g. `\Video`) so their typography is controlled centrally.
This writes the matching `\newcommand` definitions so those commands are
never undefined – the classic "Undefined control sequence" that stops an
Overleaf build. A name gets a macro only when it can safely become a new
command: letters only, and not already a LaTeX command. `time`, `L` or
`small`, for instance, are TeX/LaTeX commands already, so
`\newcommand{\time}` would stop the build ("Command \time already
defined") and redefining them would break LaTeX itself; names starting
with `end` are refused by LaTeX too. Such names are skipped with a
warning, and the reporters emit them as escaped plain text instead.

## Usage

``` r
emit_name_macros(vars, path = NULL, labels = NULL)
```

## Arguments

- vars:

  Character vector of variable/level names (e.g. the columns you pass as
  `iv`/`dv`), or a named character vector / list mapping a name to the
  display label it should expand to (unnamed elements are their own
  label).

- path:

  Optional `.tex`/`.sty` path to write the definitions to.

- labels:

  Optional named character vector mapping a name to its display label
  (overrides names taken from `vars`).

## Value

Invisibly, the `\newcommand` lines as a character vector (one per
distinct name); also emitted via
[`message()`](https://rdrr.io/r/base/message.html).

## Examples

``` r
emit_name_macros(c("Video", "DriverPosition"))
#> \newcommand{\Video}{Video}
#> \newcommand{\DriverPosition}{DriverPosition}
emit_name_macros(c(tlxMental = "TLX Mental Demand"))
#> \newcommand{\tlxMental}{TLX Mental Demand}
```
