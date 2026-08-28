# {{name}}

Analysis for {{name}}. Scaffolded with `colleyRstats::use_study_project()` on {{date}}.

Questionnaires used: {{instruments}}.

## Running it

```r
targets::tar_make()          # runs every stale stage, in order
targets::tar_visnetwork()    # shows what is stale and why
targets::tar_read(results)   # the fitted models and the summary table
```

The pipeline ships with example data in `data-raw/`, so it runs end to end
before any real data exists. Replace that file with your own export, adjust
`R/read.R` if the format differs, and run `tar_make()` again.

## Layout

| Path | What it holds |
| --- | --- |
| `data-raw/` | The raw export, exactly as it came out of the survey tool or simulator. Never edited by hand. |
| `R/read.R` | Reads the raw file, and nothing else. |
| `R/prepare.R` | Cleaning, exclusions, and questionnaire scoring. Every decision about the data is visible here. |
| `R/analysis.R` | The models, and the LaTeX the manuscript reads. |
| `R/figures.R` | The figures, at publication sizes. |
| `report/report.qmd` | A Quarto report of everything the pipeline produced. |
| `paper/generated/` | Generated `.tex` snippets. The manuscript `\input{}`s these. |
| `output/figures/` | Generated figures. |
| `_targets.R` | The pipeline: which stage depends on what. |

`paper/` and `output/` are generated. Deleting either and running `tar_make()`
must reproduce them exactly; if it does not, that is a bug in the pipeline.

## Getting numbers into the manuscript

Numbers are never re-typed. The pipeline writes one `.tex` file per outcome into
`paper/generated/`, and the manuscript pulls them in:

```latex
\usepackage{colleyRstats}     % paper/colleyRstats.sty, defines \p, \F, \m, \sd
...
\input{generated/RTLX}
```

Re-run `tar_make()` after a data fix and every number in the paper updates.

## Before you trust the scores

Run this once per instrument, per study, and read what it prints:

```r
targets::tar_load(clean)
check_questionnaire(clean, "sus", prefix = "sus_")
```

It shows which column supplies which item, which subscale it loads on, and
which items are reverse-coded. Item order and polarity belong to the sheet your
participants actually saw -- a shifted or re-ordered export scores silently, and
wrongly.

## Reproducibility

Package versions are pinned in `renv.lock`. A collaborator runs:

```r
renv::restore()
targets::tar_make()
```

After adding a package, run `renv::snapshot()` so the lockfile keeps up.
