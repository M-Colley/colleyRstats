# Reading the raw study export.
#
# Keep this stage dumb: read the file, change nothing. Everything that is a
# decision -- dropping a participant, renaming a condition, recoding an item --
# belongs in prepare_study(), where it is visible and reviewable rather than
# buried in an import call.

read_study <- function(path) {
  # na.strings: a blank cell is a missing response. Without it, one blank in an
  # otherwise numeric item column can leave the column as text.
  raw <- utils::read.csv(
    path,
    stringsAsFactors = FALSE, check.names = FALSE,
    na.strings = c("", "NA")
  )

  # For a European export with decimal commas ("2,5") and semicolon separators,
  # use utils::read.csv2() instead -- read.csv() leaves such columns as text.
  # For an Excel export, swap the call above for:
  #   raw <- readxl::read_excel(path)
  # For SPSS, keeping the value labels:
  #   raw <- haven::read_sav(path)

  stopifnot(nrow(raw) > 0)
  raw
}
