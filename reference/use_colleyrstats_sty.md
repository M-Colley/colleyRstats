# Write colleyRstats.sty into a project (for Overleaf)

Copies the colleyRstats LaTeX macro package next to your manuscript so
the report output compiles with a single `\usepackage{colleyRstats}` –
no need to paste
[`latex_preamble()`](https://m-colley.github.io/colleyRstats/reference/latex_preamble.md)
into the preamble. Upload the written `colleyRstats.sty` to your
Overleaf project (or keep it in the same folder as `main.tex`).

## Usage

``` r
use_colleyrstats_sty(dir = ".", overwrite = FALSE)
```

## Arguments

- dir:

  Directory to write `colleyRstats.sty` into. Default the current
  working directory.

- overwrite:

  Overwrite an existing file? Default `FALSE`.

## Value

Invisibly, the path to the written `.sty` file.

## Examples

``` r
use_colleyrstats_sty(tempdir(), overwrite = TRUE)
#> Wrote '/tmp/RtmpbCzReO/colleyRstats.sty'. Add \usepackage{colleyRstats} to your document.
```
