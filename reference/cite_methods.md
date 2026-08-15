# Citations and methods boilerplate for the analyses used

Prints a ready-made methods phrase plus the BibTeX entries for the R
packages behind the requested analysis methods, so a manuscript's
methods section and bibliography can be filled in one step.

## Usage

``` r
cite_methods(methods = c("ggstatsplot", "effectsize"), bibtex = TRUE)
```

## Arguments

- methods:

  Character vector of analysis methods to cite. Any of `"art"` (Aligned
  Rank Transform via ARTool), `"dunn"` (Dunn's test via FSA), `"nparld"`
  (nparLD), `"ggstatsplot"`, `"effectsize"`, and `"colleyrstats"` (this
  package).

- bibtex:

  whether to include the BibTeX entries. Default `TRUE`.

## Value

Invisibly returns the generated lines as a character vector; the text is
also emitted via [`message()`](https://rdrr.io/r/base/message.html).
Methods whose package is not installed are skipped with a message.

## Examples

``` r
cite_methods("ggstatsplot", bibtex = FALSE)
#> % ggstatsplot: Statistical tests and visualizations were produced with ggstatsplot.
```
