# Reshape Excel Data Based on Custom Markers and Include Custom ID Column

This function takes an Excel file with data in a wide format and
transforms it to a long format. It includes a customizable "ID" column
in the first position and repeats it for each slice. The function
identifies sections of columns between markers that start with a
user-defined string (default is "videoinfo") and appends those sections
under the first section, aligning by column index. Columns before the
first marker (e.g. a survey export's metadata or demographics) are not a
section: like the ID column, they are repeated for every slice. The
marker columns themselves are dropped.

## Usage

``` r
reshape_data(
  input_filepath,
  sheetName = "Results",
  marker = "videoinfo",
  id_col = "ID",
  output_filepath
)
```

## Arguments

- input_filepath:

  String, the file path of the input Excel file.

- sheetName:

  String, the name of the sheet to read from the Excel file. Default is
  "Results".

- marker:

  String, the string that identifies the start of a new section of
  columns. Default is "videoinfo".

- id_col:

  String, the name of the column to use as the ID column. Default is
  "ID".

- output_filepath:

  String, the file path for the output Excel file.

## Value

None, writes the reshaped data to an Excel file specified by
output_filepath.

## Details

Relevant if you receive data in wide-format but cannot use built-in
functionality due to naming (e.g., in LimeSurvey)

## Examples

``` r
# \donttest{
if (requireNamespace("writexl", quietly = TRUE) &&
  requireNamespace("readxl", quietly = TRUE)) {
  tmp_in  <- tempfile(fileext = ".xlsx")
  tmp_out <- tempfile(fileext = ".xlsx")

  # Two marker-delimited sections of equal width; each section is stacked
  # under the first one, keyed by the ID column.
  toy <- data.frame(
    ID = c(1, 2),
    videoinfo1 = c("marker", "marker"),
    rating = c(10, 11),
    videoinfo2 = c("marker", "marker"),
    rating2 = c(20, 21),
    stringsAsFactors = FALSE
  )

  writexl::write_xlsx(toy, tmp_in)

  reshape_data(
    input_filepath = tmp_in,
    marker = "videoinfo",
    id_col = "ID",
    output_filepath = tmp_out
  )

  out <- readxl::read_excel(tmp_out)
  print(out)
}
#> # A tibble: 4 × 2
#>      ID rating
#>   <dbl>  <dbl>
#> 1     1     10
#> 2     2     11
#> 3     1     20
#> 4     2     21
# }
```
