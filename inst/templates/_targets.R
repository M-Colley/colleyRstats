# Analysis pipeline for {{name}}, scaffolded by colleyRstats on {{date}}.
#
# Run it with            targets::tar_make()
# See what is stale with targets::tar_visnetwork()
# Read one result with   targets::tar_read(results)
#
# Each tar_target() below is one stage. targets records what each stage depends
# on, so changing the raw data re-runs everything, changing a figure re-runs
# only the figures, and nothing is ever silently stale -- which is the property
# a plain script cannot give you.

library(targets)

tar_option_set(
  packages = c("colleyRstats", "dplyr", "ggplot2"),
  format = "rds"
)

# Every function used below lives in R/. Edit those, not this file.
tar_source("R")

list(

  # format = "file" tracks the CSV by its contents, so a corrected data export
  # invalidates the pipeline even though the path did not change.
  tar_target(raw_file, "data-raw/example-study.csv", format = "file"),

  tar_target(raw, read_study(raw_file)),

  # Cleaning and scoring are separate stages on purpose: re-running the scoring
  # after fixing a reverse-coded item should not re-read the raw file, and a
  # reviewer should be able to see the scored data without re-deriving it.
  tar_target(clean, prepare_study(raw)),
  tar_target(scored, score_scales(clean)),

  tar_target(results, run_models(scored)),
  tar_target(figures, make_figures(scored), format = "file"),

  # The manuscript \input{}s these, so a number can never be re-typed wrongly.
  tar_target(manuscript_tex, write_manuscript_tex(results, scored), format = "file")
)

# To render report/report.qmd as part of the pipeline, install tarchetypes and
# add this to the list above:
#
#   tarchetypes::tar_quarto(report, "report/report.qmd")
