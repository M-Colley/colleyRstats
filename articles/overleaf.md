# From R to Overleaf: publication-ready output

``` r

library(colleyRstats)
#> Loading required package: ggplot2
#> Registered S3 methods overwritten by 'ggpp':
#>   method                  from   
#>   heightDetails.titleGrob ggplot2
#>   widthDetails.titleGrob  ggplot2
```

`colleyRstats` reporters produce LaTeX so your analysis can flow
straight into a manuscript. This vignette shows how to get that output
into a LaTeX/Overleaf project with the least friction, and – just as
importantly – how to make sure the generated `.tex` always compiles.

## The two macro modes

By default the reporters emit **compact macros** such as `\F{}{}{}`,
`\p{}`, and `\m{}` instead of raw math. This keeps the sentences short
and gives you one central place to control how every statistic is
typeset. The trade-off is that these macros must be defined in your
document’s preamble, otherwise LaTeX stops with an “Undefined control
sequence” error.

[`latex_preamble()`](https://m-colley.github.io/colleyRstats/reference/latex_preamble.md)
prints (and optionally writes) the definitions so you can paste them
into a preamble:

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
#> \newcommand{\rankbiserial}[1]{$r_{rb} = #1$}
#> \newcommand{\effectsize}{\textit{r=}}
```

For an Overleaf project it is cleaner to ship the definitions as a
package. `use_colleyrstats_sty(dir)` writes `colleyRstats.sty`; upload
that file and add a single `\usepackage{colleyRstats}` to your document.
We write into [`tempdir()`](https://rdrr.io/r/base/tempfile.html) here
so the vignette leaves nothing behind.

``` r

sty_path <- use_colleyrstats_sty(tempdir(), overwrite = TRUE)
#> Wrote '/tmp/RtmpbtcWlY/colleyRstats.sty'. Add \usepackage{colleyRstats} to your document.
sty_path
#> [1] "/tmp/RtmpbtcWlY/colleyRstats.sty"
```

If you would rather not carry a preamble at all, set
`options(colleyRstats.macros = FALSE)`. The sinks and the
[`emit_overleaf()`](https://m-colley.github.io/colleyRstats/reference/emit_overleaf.md)
bundle then expand every macro to **plain math** via
[`expand_latex_macros()`](https://m-colley.github.io/colleyRstats/reference/expand_latex_macros.md),
so the output is self-contained. You can call the expander directly to
see what the compact form turns into:

``` r

cat(expand_latex_macros("A significant effect (\\F{2}{57}{4.50}, \\p{0.012})."))
#> A significant effect ($F(2, 57) = 4.50$, $p = 0.012$).
```

Whichever mode you use, any text you place into LaTeX – a variable name,
a factor level – must be escaped so characters like `_` and `%` do not
break the build.
[`latex_escape()`](https://m-colley.github.io/colleyRstats/reference/latex_escape.md)
handles that:

``` r

latex_escape("tlx_mental (%)")
#> [1] "tlx\\_mental (\\%)"
```

## Tables

[`reportDunnTestTable()`](https://m-colley.github.io/colleyRstats/reference/reportDunnTestTable.md)
and
[`reportArtConTable()`](https://m-colley.github.io/colleyRstats/reference/reportArtConTable.md)
render a full post-hoc comparison table as LaTeX. Both accept
`style = c("hline", "booktabs")`: use `"booktabs"` for the cleaner rules
most journals prefer. Rendering a table needs the **xtable** package,
and computing a Dunn test from raw data additionally needs **FSA**, so
the demo below is guarded and only runs when both are installed.

``` r

set.seed(1)
tbl_df <- data.frame(
  group = factor(rep(c("A", "B", "C"), each = 12)),
  score = c(rnorm(12, 50), rnorm(12, 54), rnorm(12, 58))
)

reportDunnTestTable(
  data = tbl_df,
  iv = "group",
  dv = "score",
  style = "booktabs"
)
#>   Kruskal-Wallis rank sum test
#> 
#> data: x and g
#> Kruskal-Wallis chi-squared = 31.1351, df = 2, p-value = 0
#> 
#> 
#>                       Dunn's Pairwise Comparison of x by g                      
#>                                      (Holm)                                     
#> 
#> Col Mean-│
#> Row Mean │          A          B
#> ─────────┼──────────────────────
#>        B │  -2.789943
#>          │     0.0105*
#>          │
#>        C │  -5.579886  -2.789943
#>          │     0.0000*    0.0053*
#> 
#> FWER = 0.05
#> Reject Ho if adjusted p ≤ FWER with stopping rule, where (unadjusted) p = Pr(|Z| ≥ |z|)
#> % latex table generated in R 4.6.1 by xtable 1.8-8 package
#> % Tue Sep  1 17:41:14 2026
#> \begin{table}[ht]
#> \centering
#> \caption{Post-hoc comparisons for independent variable \group and dependent variable \score. Positive Z-values mean that the first-named level is sig. higher than the second-named. For negative Z-values, the opposite is true. Effect size reported as rank-biserial correlation (r).} 
#> \label{tab:posthoc-group-score}
#> \begingroup\small
#> \begin{tabular}{lrll}
#>   \toprule
#> Comparison & Z & p-adjusted & r \\ 
#>   \midrule
#> A - B & -2.7899 & 0.0105 & 1.00 \\ 
#>   A - C & -5.5799 & $<$0.001 & 1.00 \\ 
#>   B - C & -2.7899 & 0.0053 & 1.00 \\ 
#>    \bottomrule
#> \end{tabular}
#> \endgroup
#> \end{table}
```

If `FSA`/`xtable` are not available the chunk above is skipped so the
vignette still builds.

## Reproducible values

The most robust way to keep numbers in your prose correct is to never
type them by hand.
[`define_result_macro()`](https://m-colley.github.io/colleyRstats/reference/define_result_macro.md)
emits a `\newcommand` you reference in the text; re-running the R code
updates the number everywhere it appears.

``` r

define_result_macro("tlx_mental_omnibus", "F(2, 57) = 4.50, p = .02")
#> \newcommand{\tlxMentalOmnibus}{F(2, 57) = 4.50, p = .02}
```

The label is sanitised to a valid (letters-only) command name – here
`\tlxMentalOmnibus` – which you then use in prose as
`... omnibus effect (\tlxMentalOmnibus).`

Variable and factor-level names deserve the same treatment. When the
reporters emit a name like `\Video`, that command must exist too.
[`emit_name_macros()`](https://m-colley.github.io/colleyRstats/reference/emit_name_macros.md)
generates the matching `\newcommand` stubs so those names are never
undefined:

``` r

emit_name_macros(c("Video", "DriverPosition"))
#> \newcommand{\Video}{Video}
#> \newcommand{\DriverPosition}{DriverPosition}
```

## The one-call bundle

[`emit_overleaf()`](https://m-colley.github.io/colleyRstats/reference/emit_overleaf.md)
is the end of the pipeline: it turns a
[`report_all()`](https://m-colley.github.io/colleyRstats/reference/report_all.md)
/
[`analyze_and_report()`](https://m-colley.github.io/colleyRstats/reference/analyze_and_report.md)
result – or, as here, a plain named list of sentence vectors – into a
folder you can drag straight into Overleaf. It writes `main.tex`,
`results.tex`, one `sections/*.tex` per result, `references.bib`,
`colleyRstats.sty`, and (when the text contains name macros)
`names.tex`.

``` r

study <- list(results = list(
  workload = list(
    sentences = "A significant main effect of \\Video on workload (\\F{2}{57}{4.50}, \\p{0.012}).",
    plot = NULL
  ),
  trust = list(
    sentences = "No significant effect on trust (\\p{0.45}).",
    plot = NULL
  )
))

out <- emit_overleaf(study, dir = file.path(tempdir(), "paper"), overwrite = TRUE)
#> Wrote an Overleaf-ready project to '/tmp/RtmpbtcWlY/paper' (2 sections; \usepackage{colleyRstats}).
list.files(out$dir, recursive = TRUE)
#> [1] "colleyRstats.sty"      "main.tex"              "names.tex"            
#> [4] "references.bib"        "results.tex"           "sections/trust.tex"   
#> [7] "sections/workload.tex"
```

The generated `main.tex` already `\usepackage`s the shipped
`colleyRstats.sty`, so this project compiles as-is. To drop the preamble
dependency entirely, switch to plain mode: the same call then expands
the macros inline and omits the `.sty`.

``` r

old <- options(colleyRstats.macros = FALSE)
plain <- emit_overleaf(study, dir = file.path(tempdir(), "paper-plain"), overwrite = TRUE)
#> Wrote an Overleaf-ready project to '/tmp/RtmpbtcWlY/paper-plain' (2 sections; macros expanded inline).
options(old)

list.files(plain$dir, recursive = TRUE)
#> [1] "main.tex"              "names.tex"             "references.bib"       
#> [4] "results.tex"           "sections/trust.tex"    "sections/workload.tex"
```

Notice there is no `colleyRstats.sty` in the plain output – every
statistic has been expanded to standalone math, so the folder compiles
without a preamble. Either way, the result is a LaTeX project that goes
from R to a compiled PDF with no manual editing of numbers.
