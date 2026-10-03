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
  for `references.bib`; `NULL` to skip the bibliography. Every entry is
  listed via `\nocite{*}`, since the generated text cites nothing and
  BibTeX writes an empty bibliography without a citation. When none of
  the methods can be cited (their packages are not installed), no
  `references.bib` is written, with a warning.

- title:

  Title used in the generated `main.tex`. Default `"Results"`.

- plain:

  Whether to expand the colleyRstats macros to plain LaTeX (so no `.sty`
  / `\usepackage` is needed). Default `NULL` follows
  `getOption("colleyRstats.macros")` (i.e. plain when that is `FALSE`).

- columns:

  Figure width preset passed to
  [`save_paper_figure()`](https://m-colley.github.io/colleyRstats/reference/save_paper_figure.md).
  A single-column figure is included at its natural size, because
  [`save_paper_figure()`](https://m-colley.github.io/colleyRstats/reference/save_paper_figure.md)
  chose its type size for exactly that width (scaling it to the line
  width would enlarge the text with it); a full-width figure
  (`columns = 2`) goes into a `figure*` at `\textwidth`.

- overwrite:

  Overwrite existing files in `dir`? Default `FALSE`: if any file the
  project consists of already exists, nothing is written.

## Value

Invisibly, a list with the paths written (`dir`, `main`, `results`,
`sections`, `figures`, `bib`, `sty`, `names`); `bib`, `sty` and `names`
are `NULL` when the file was not needed.

## Details

Section keys become file names with only letters, digits and hyphens
kept (`"tlx_1"` is written to `sections/tlx-1.tex`); keys that would
share a file name – including names differing only in case, which
Windows and macOS treat as one file – get a numbered suffix, so no
section can overwrite another. The keys themselves are escaped with
[`latex_escape()`](https://m-colley.github.io/colleyRstats/reference/latex_escape.md)
wherever they are typeset (headings, captions). Name macros in the text
(`\Video`) get `\providecommand` stubs in `names.tex`, and a
[`{}`](https://rdrr.io/r/base/Paren.html) where a space follows them,
because TeX would otherwise swallow that space ("`\cyl on`" typesets as
"cylon").

## Examples

``` r
# \donttest{
out <- report_all(mtcars, dvs = c("mpg", "disp"), iv = "cyl")
#> Shapiro--Wilk tests in each of the 3 groups of cyl (Holm-corrected for 3 tests) indicated no significant deviation from normality (smallest $p$: $W = 0.91$, $p_{\mathrm{Holm}} = 0.782$ for group 4); therefore, parametric tests were used. Brown-Forsythe test (median-centred Levene's test) indicated unequal variances ($F(2, 29) = 5.51$, $p = 0.009$); Welch-corrected statistics were used where applicable.
#> A One-way analysis of means (not assuming equal variances) found a significant effect of \cyl{} on mpg (\F{2}{18.03}{31.62}, \pminor{0.001}, $\omega^{2}$ = 0.74). 
#> A Games-Howell post-hoc test (Holm-adjusted) found that 4 was significantly higher (\m{26.66}, \sd{4.51}) in terms of mpg compared to 6 (\m{19.74}, \sd{1.45}; \padj{0.001}). 
#> A Games-Howell post-hoc test (Holm-adjusted) found that 4 was significantly higher (\m{26.66}, \sd{4.51}) in terms of mpg compared to 8 (\m{15.10}, \sd{2.56}; \padjminor{0.001}). 
#> A Games-Howell post-hoc test (Holm-adjusted) found that 6 was significantly higher (\m{19.74}, \sd{1.45}) in terms of mpg compared to 8 (\m{15.10}, \sd{2.56}; \padjminor{0.001}). 
#> Shapiro--Wilk tests in each of the 3 groups of cyl (Holm-corrected for 3 tests) indicated no significant deviation from normality (smallest $p$: $W = 0.80$, $p_{\mathrm{Holm}} = 0.129$ for group 6); therefore, parametric tests were used. Brown-Forsythe test (median-centred Levene's test) did not indicate unequal variances ($F(2, 29) = 3.29$, $p = 0.052$).
#> A One-way analysis of means (not assuming equal variances) found a significant effect of \cyl{} on disp (\F{2}{14.89}{76.89}, \pminor{0.001}, $\omega^{2}$ = 0.89). 
#> A Games-Howell post-hoc test (Holm-adjusted) found that 6 was significantly higher (\m{183.31}, \sd{41.56}) in terms of disp compared to 4 (\m{105.14}, \sd{26.87}; \padj{0.004}). 
#> A Games-Howell post-hoc test (Holm-adjusted) found that 8 was significantly higher (\m{353.10}, \sd{67.77}) in terms of disp compared to 4 (\m{105.14}, \sd{26.87}; \padjminor{0.001}). 
#> A Games-Howell post-hoc test (Holm-adjusted) found that 8 was significantly higher (\m{353.10}, \sd{67.77}) in terms of disp compared to 6 (\m{183.31}, \sd{41.56}; \padjminor{0.001}). 
emit_overleaf(out, dir = file.path(tempdir(), "paper"), overwrite = TRUE)
#> Wrote an Overleaf-ready project to '/tmp/Rtmpox81T4/paper' (2 sections; \usepackage{colleyRstats}).
# }
```
