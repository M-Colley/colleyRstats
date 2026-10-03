# Flag suspicious survey responses via the Response Entropy Index (REI)

Computes each respondent's Response Entropy Index (Tawa, 2021) and flags
unusually low or high values. Note that no rows are removed; entries are
only flagged via the `Suspicious` column.

## Usage

``` r
remove_outliers_REI(df, header = FALSE, variables = "", range = c(1, 5))
```

## Arguments

- df:

  Data frame containing the data.

- header:

  Which columns enter the computation. `TRUE`: only the columns named in
  `variables`. `FALSE` (the default, kept for compatibility): *every*
  column of `df` – remove ID, timestamp and other non-item columns
  first. A warning names any column that does not look like a response:
  with `header = FALSE` a non-numeric column, and in either mode a
  column with values outside `range`.

- variables:

  Which variables to consider when `header = TRUE`: either a single
  character string with names separated by commas (`"var1,var2"`) or a
  character vector (`c("var1", "var2")`). Names are matched exactly (not
  as regular expressions), so survey-export names such as
  `"G01Q01[SQ001]"` work; names not found in `df` are ignored with a
  warning.

- range:

  Numeric vector of length 2 specifying the range of the Likert scale
  (used to sanity-check the responses). Defaults to c(1, 5).

## Value

A data frame with the calculated `REI`, the item columns used,
`Percentile`, and a `Suspicious` flag (`"No"`, `"Maybe"`, `"Yes"`; `NA`
for a respondent without answers).

## Details

The REI is the Shannon entropy (base 10) of a respondent's distribution
of answers over the response options, \\REI_i = -\sum_k p\_{ki}
\log\_{10} p\_{ki}\\, where \\p\_{ki}\\ is the proportion of the
respondent's *answered* items that received option \\k\\. Low values
indicate overly consistent answering (e.g. straight-lining), high values
overly scattered answering; either can indicate careless responding.
Because the index ignores item content, compute it on the items as
answered, before reverse-coding (Tawa, 2021).

Missing responses are left out: proportions are taken over the items a
respondent answered, so the same answer pattern yields the same REI
however many items were skipped (dividing by the total number of items,
as versions before 0.3.0 did, lowered the REI of anyone who skipped
items). A respondent who answered nothing gets `NA`. Responses outside
the declared Likert `range` trigger a warning (they often indicate
mis-coded data, or a non-item column) but are still included in the REI
computation.

Flags are relative to the sample: each REI is converted to a percentile
of a normal distribution with the sample's mean and standard deviation.
`"Maybe"` marks the outer 10% on either side (the preliminary guideline
of Tawa, 2021), `"Yes"` the outer 5%. When all respondents have the same
REI the percentiles are undefined: `Percentile` is `NA`, no row is
flagged, and a warning says so.

## References

Tawa, J. (2021). The Response Entropy Index: Comparative assessment of
performance and cultural bias across indices of careless responding.
*Survey Research Methods, 15*(3), 299–325.
[doi:10.18148/srm/2021.v15i3.7832](https://doi.org/10.18148/srm/2021.v15i3.7832)

## Examples

``` r
# \donttest{
df <- data.frame(
  id = 1:6,
  q1 = c(1, 5, 3, 3, 2, 4), q2 = c(1, 1, 4, 3, 2, 5),
  q3 = c(1, 4, 3, 3, 5, 4), q4 = c(1, 2, 4, 3, 1, 5)
)
# select the item columns; the ID column is no response
result <- remove_outliers_REI(df, TRUE, c("q1", "q2", "q3", "q4"), c(1, 5))
result
#>        REI q1 q2 q3 q4 Percentile Suspicious
#> 1 0.000000  1  1  1  1         13         No
#> 2 0.602060  5  1  4  2         91      Maybe
#> 3 0.301030  3  4  3  4         54         No
#> 4 0.000000  3  3  3  3         13         No
#> 5 0.451545  2  2  5  1         77         No
#> 6 0.301030  4  5  4  5         54         No
# }
```
