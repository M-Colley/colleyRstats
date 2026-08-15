# Expand the colleyRstats LaTeX macros to plain standard LaTeX

The report functions normally emit compact custom macros (`\F`, `\p`,
`\m`, `\sd`, `\df`, `\chisq`, `\padj`, `\padjminor`, `\pminor`,
`\rankbiserial`, `\effectsize`) that require
[`latex_preamble()`](https://m-colley.github.io/colleyRstats/reference/latex_preamble.md)
definitions. This expands them into equivalent plain math (e.g.
`\F{2}{57}{4.50}` becomes `$F(2, 57) = 4.50$`) so the text compiles in
any document with no custom preamble – the "zero-setup Overleaf" path.
It is applied automatically by the
`sink_to`/[`emit_overleaf()`](https://m-colley.github.io/colleyRstats/reference/emit_overleaf.md)
writers when `options(colleyRstats.macros = FALSE)`.

## Usage

``` r
expand_latex_macros(x)
```

## Arguments

- x:

  A character vector of report text.

## Value

The text with the macros expanded to standard LaTeX math.

## Examples

``` r
expand_latex_macros("A significant effect (\\F{2}{57}{4.50}, \\p{0.012}).")
#> [1] "A significant effect ($F(2, 57) = 4.50$, $p = 0.012$)."
```
