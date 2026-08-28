# Reading the raw study export.
#
# Keep this stage dumb: read the file, change nothing. Everything that is a
# decision -- dropping a participant, renaming a condition, recoding an item --
# belongs in prepare_study(), where it is visible and reviewable rather than
# buried in an import call.

read_study <- function(path) {
  raw <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)

  # For an Excel export, swap the line above for:
  #   raw <- readxl::read_excel(path)
  # For SPSS, keeping the value labels:
  #   raw <- haven::read_sav(path)

  stopifnot(nrow(raw) > 0)
  raw
}
