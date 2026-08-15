# Flag suspicious survey responses via the Response Entropy Index (REI)

This function takes a data frame, optional header information, variables
to consider, and a range for a Likert scale. It then calculates the
Response Entropy Index (REI) and flags suspicious entries based on
percentiles. Note that no rows are removed; entries are only flagged via
the `Suspicious` column.

## Usage

``` r
remove_outliers_REI(df, header = FALSE, variables = "", range = c(1, 5))
```

## Arguments

- df:

  Data frame containing the data.

- header:

  Logical indicating if the data frame has a header. Defaults to FALSE.

- variables:

  Which variables to consider: either a single character string with
  names separated by commas (`"var1,var2"`) or a character vector
  (`c("var1", "var2")`).

- range:

  Numeric vector of length 2 specifying the range of the Likert scale
  (used to sanity-check the responses). Defaults to c(1, 5).

## Value

A data frame with calculated REI, percentile, and a 'Suspicious' flag.

## Details

Missing responses are ignored when tallying answers. Responses outside
the declared Likert `range` trigger a warning (they often indicate
mis-coded data) but are still included in the REI computation.

For more information on the REI method, refer to: [Response Entropy
Index Method](https://ojs.ub.uni-konstanz.de/srm/article/view/7832)

## Examples

``` r
# \donttest{
df <- data.frame(var1 = c(1, 2, 3), var2 = c(2, 3, 4))
result <- remove_outliers_REI(df, TRUE, "var1,var2", c(1, 5))
# }
```
