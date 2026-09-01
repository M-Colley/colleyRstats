# Bundle an analysis into an Overleaf-ready folder

Writes everything a manuscript needs into one directory you can drag
into Overleaf and compile immediately: a `main.tex` that already
`\input`s the results, one `.tex` per result section, the figures, a
`references.bib`, and – unless macros are expanded inline –
`colleyRstats.sty`. This is the one-call end of the "R analysis to
compiled PDF" pipeline.

## Usage

``` r
emit_overleaf(
  x,
  dir,
  figures = TRUE,
  methods = c("ggstatsplot", "effectsize"),
  title = "Results",
  plain = NULL,
  columns = 1,
  overwrite = FALSE
)
```

## Arguments

- x:

  What to emit. Accepts a
  [`report_all()`](https://m-colley.github.io/colleyRstats/reference/report_all.md)
  result (one section per dependent variable, with figures), an
  [`analyze_and_report()`](https://m-colley.github.io/colleyRstats/reference/analyze_and_report.md)
  result, a named list of sentence vectors, or a single character
  vector.

- dir:

  Output directory (created if needed).

- figures:

  Whether to save figures for sections that carry a plot. Default
  `TRUE`.

- methods:

  Methods to cite (passed to
  [`cite_methods()`](https://m-colley.github.io/colleyRstats/reference/cite_methods.md))
  for `references.bib`; `NULL` to skip the bibliography.

- title:

  Title used in the generated `main.tex`. Default `"Results"`.

- plain:

  Whether to expand the colleyRstats macros to plain LaTeX (so no `.sty`
  / `\usepackage` is needed). Default `NULL` follows
  `getOption("colleyRstats.macros")` (i.e. plain when that is `FALSE`).

- columns:

  Figure width preset passed to
  [`save_paper_figure()`](https://m-colley.github.io/colleyRstats/reference/save_paper_figure.md).

- overwrite:

  Overwrite existing files in `dir`? Default `FALSE`.

## Value

Invisibly, a list with the paths written (`dir`, `main`, `results`,
`sections`, `figures`, `bib`, `sty`).

## Examples

``` r
# \donttest{
out <- report_all(mtcars, dvs = c("mpg", "disp"), iv = "cyl")
#> Shapiro--Wilk tests indicated no significant deviation from normality in any group (all $p \geq 0.05$); therefore, parametric tests were used. Levene's test indicated unequal variances ($F(2, 29) = 5.51$, $p = 0.009$); Welch-corrected statistics were used where applicable.
#> A One-way analysis of means (not assuming equal variances) found a significant effect of \cyl on mpg (\F{2}{18.03}{31.62}, \pminor{0.001}, $\omega^{2}$ = 0.74). 
#> A Games-Howell post-hoc test (Holm-adjusted) found that 4 was significantly higher (\m{26.66}, \sd{4.51}) in terms of \mpg compared to 6 (\m{19.74}, \sd{1.45}; \padj{0.001}). 
#> A Games-Howell post-hoc test (Holm-adjusted) found that 4 was significantly higher (\m{26.66}, \sd{4.51}) in terms of \mpg compared to 8 (\m{15.10}, \sd{2.56}; \padjminor{0.001}). 
#> A Games-Howell post-hoc test (Holm-adjusted) found that 6 was significantly higher (\m{19.74}, \sd{1.45}) in terms of \mpg compared to 8 (\m{15.10}, \sd{2.56}; \padjminor{0.001}). 
#> Shapiro--Wilk tests indicated a significant deviation from normality for at least one group (minimum $W = 0.80$, $p = 0.043$); therefore, non-parametric tests were used. Levene's test indicated homogeneity of variances ($F(2, 29) = 3.29$, $p = 0.052$).
#> A Kruskal-Wallis rank sum test found a significant effect of \cyl on disp (\chisq(2)=26.68, \pminor{0.001}, $\epsilon_{ordinal}^{2}$ = 0.86). 
#> A Dunn post-hoc test (Holm-adjusted) found that 8 was significantly higher (\m{353.10}, \sd{67.77}) in terms of \disp compared to 4 (\m{105.14}, \sd{26.87}; \padjminor{0.001}). 
#> A Dunn post-hoc test (Holm-adjusted) found that 8 was significantly higher (\m{353.10}, \sd{67.77}) in terms of \disp compared to 6 (\m{183.31}, \sd{41.56}; \padj{0.028}). 
emit_overleaf(out, dir = file.path(tempdir(), "paper"), overwrite = TRUE)
#> Wrote an Overleaf-ready project to '/tmp/RtmpZDhk29/paper' (2 sections; \usepackage{colleyRstats}).
# }
```
