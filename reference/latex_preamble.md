# LaTeX preamble required by the report functions

All report functions emit LaTeX text that relies on a small set of
custom commands. This helper prints the complete set, ready to paste
into a manuscript preamble, or writes it to a file that can be included
with `\input{}` (or renamed to `.sty` and loaded via `\usepackage`).

## Usage

``` r
latex_preamble(path = NULL)
```

## Arguments

- path:

  Optional path of a `.tex` file to write the definitions to. If the
  path ends in `.sty`, a `\ProvidesPackage` header is added so it can be
  uploaded to Overleaf and loaded with `\usepackage{colleyRstats}` (see
  also
  [`use_colleyrstats_sty()`](https://m-colley.github.io/colleyRstats/reference/use_colleyrstats_sty.md)).

## Value

Invisibly returns the macro definitions as a character vector; the text
is also emitted via [`message()`](https://rdrr.io/r/base/message.html).

## Examples

``` r
latex_preamble()
#> % colleyRstats: LaTeX commands required by the report functions
#> \newcommand{\F}[3]{$F({#1},{#2})={#3}$}
#> \newcommand{\p}{\textit{p=}}
#> \newcommand{\pminor}{\textit{p$<$}}
#> \newcommand{\padj}{\textit{p$_{adj}$=}}
#> \newcommand{\padjminor}{\textit{p$_{adj}<$}}
#> \newcommand{\m}{\textit{M=}}
#> \newcommand{\sd}{\textit{SD=}}
#> \newcommand{\df}{\textit{df=}}
#> \newcommand{\chisq}{$\chi^2$}
#> \newcommand{\mdn}{\textit{Mdn=}}
#> \newcommand{\iqr}{\textit{IQR=}}
#> \newcommand{\rankbiserial}[1]{$r_{rb} = #1$}
#> \newcommand{\effectsize}{\textit{r=}}
```
