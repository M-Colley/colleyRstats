# Scaffold a reproducible study analysis

Writes a complete, runnable analysis project: a targets pipeline that
recomputes only what changed, R scripts split along the stages every
user study goes through (read, clean, score, model, plot), a Quarto
report, and a directory the generated LaTeX lands in so a manuscript can
`\input{}` the numbers instead of having them re-typed.

## Usage

``` r
use_study_project(
  path,
  name = NULL,
  questionnaires = c("nasa_tlx", "sus"),
  renv = FALSE,
  git = TRUE,
  overwrite = FALSE,
  quiet = FALSE
)
```

## Arguments

- path:

  Directory to create the project in. Created if it does not exist.

- name:

  Project name, used in the README and the report title. Defaults to the
  directory name.

- questionnaires:

  Character vector of instrument keys the study uses, e.g.
  `c("nasa_tlx", "sus")`. The scoring script is generated with one call
  per instrument. See
  [`list_questionnaires()`](https://m-colley.github.io/colleyRstats/reference/list_questionnaires.md).

- renv:

  Logical. Initialise renv in the project, pinning the package versions
  this analysis was run with – which is what makes the project still run
  in three years, and what makes it a usable open-science artifact.
  Default `FALSE`: initialising discovers every package the scripts use
  and installs it into a project library, which can mean network
  downloads, so it is opt-in. With `TRUE`,
  [`renv::init()`](https://rstudio.github.io/renv/reference/init.html)
  runs in a separate R process (via callr when installed, otherwise
  `Rscript`), because activating a project rewrites the calling
  session's library paths, environment variables (`R_LIBS_USER`, `PATH`,
  `RENV_PATHS_*`), repository options and sandbox; your current session
  is left exactly as it was. Run
  [`renv::init()`](https://rstudio.github.io/renv/reference/init.html)
  yourself later to opt in after the fact.

- git:

  Logical. Write a `.gitignore` suited to an R analysis project. Default
  `TRUE`.

- overwrite:

  Logical. Replace files that already exist. Default `FALSE`, so running
  this on a live project adds missing pieces without touching your work.

- quiet:

  Logical. Suppress the per-file messages.

## Value

Invisibly, the normalised project path.

## Details

The generated pipeline is wired to this package: scoring goes through
[`score_questionnaire()`](https://m-colley.github.io/colleyRstats/reference/score_questionnaire.md),
model choice and fitting through
[`fit_recommended()`](https://m-colley.github.io/colleyRstats/reference/fit_recommended.md),
sentences and tables through the `report_*` functions, and figures
through
[`save_paper_figure()`](https://m-colley.github.io/colleyRstats/reference/save_paper_figure.md).
It runs as written against the example data it ships with, so the first
thing you do in a new project is see a green pipeline, then replace the
example data with yours.

## Why a pipeline rather than a script

A study analysis is re-run many times – after a data fix, after a
reviewer asks for one more contrast, after a co-author changes a factor
label. With a script, that means re-running everything and hoping
nothing stale is left in the workspace; targets tracks which step
depends on what and recomputes only the affected ones, which also means
the pipeline is a machine-checkable record of how each number was
produced.

## See also

[`score_questionnaire()`](https://m-colley.github.io/colleyRstats/reference/score_questionnaire.md),
[`fit_recommended()`](https://m-colley.github.io/colleyRstats/reference/fit_recommended.md),
[`save_paper_figure()`](https://m-colley.github.io/colleyRstats/reference/save_paper_figure.md),
[`emit_overleaf()`](https://m-colley.github.io/colleyRstats/reference/emit_overleaf.md)

## Examples

``` r
# \donttest{
project <- file.path(tempdir(), "driving-study")
use_study_project(project, questionnaires = c("nasa_tlx", "sus"), renv = FALSE)
#> Creating study project 'driving-study' in /tmp/Rtmpb2vD81/driving-study
#>   wrote: /tmp/Rtmpb2vD81/driving-study/_targets.R
#>   wrote: /tmp/Rtmpb2vD81/driving-study/R/read.R
#>   wrote: /tmp/Rtmpb2vD81/driving-study/R/prepare.R
#>   wrote: /tmp/Rtmpb2vD81/driving-study/R/analysis.R
#>   wrote: /tmp/Rtmpb2vD81/driving-study/R/figures.R
#>   wrote: /tmp/Rtmpb2vD81/driving-study/report/report.qmd
#>   wrote: /tmp/Rtmpb2vD81/driving-study/README.md
#>   wrote: /tmp/Rtmpb2vD81/driving-study/.gitignore
#>   wrote: /tmp/Rtmpb2vD81/driving-study/data-raw/example-study.csv
#>   wrote: /tmp/Rtmpb2vD81/driving-study/data-raw/README.md
#>   wrote: /tmp/Rtmpb2vD81/driving-study/paper/generated/README.md
#>   wrote: /tmp/Rtmpb2vD81/driving-study/output/figures/README.md
#>   wrote: /tmp/Rtmpb2vD81/driving-study/paper/colleyRstats.sty
#> 
#> Done. Next:
#>   1. setwd("/tmp/Rtmpb2vD81/driving-study")
#>   2. targets::tar_make()            # runs end to end on the example data
#>   3. replace data-raw/example-study.csv with yours, then edit R/read.R
#>   4. targets::tar_visnetwork()      # see what is out of date
list.files(project, recursive = TRUE)
#>  [1] "R/analysis.R"               "R/figures.R"               
#>  [3] "R/prepare.R"                "R/read.R"                  
#>  [5] "README.md"                  "_targets.R"                
#>  [7] "data-raw/README.md"         "data-raw/example-study.csv"
#>  [9] "output/figures/README.md"   "paper/colleyRstats.sty"    
#> [11] "paper/generated/README.md"  "report/report.qmd"         
# }
```
