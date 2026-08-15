# Report statistical details for ggstatsplot.

Report statistical details for ggstatsplot.

## Usage

``` r
reportggstatsplot(
  p,
  iv = "independent",
  dv = "Testdependentvariable",
  write_to_clipboard = FALSE,
  sink_to = NULL
)

report_ggstatsplot(
  p,
  iv = "independent",
  dv = "Testdependentvariable",
  write_to_clipboard = FALSE,
  sink_to = NULL
)
```

## Arguments

- p:

  the object returned by ggwithinstats or ggbetweenstats

- iv:

  the independent variable

- dv:

  the dependent variable

- write_to_clipboard:

  whether to write to the clipboard

- sink_to:

  optional path of a `.tex` file to write the sentence to, so a
  manuscript can `\input{}` it

## Value

Invisibly returns the reported sentence(s) as a character vector; the
text is also emitted via
[`message()`](https://rdrr.io/r/base/message.html).

## Naming

`report_ggstatsplot()` is the spelling used throughout the documentation
and the one to prefer in new code: the `report_*` / `plot_*` / `check_*`
prefixes make the API discoverable through autocomplete.

`reportggstatsplot()` **\[superseded\]** is the original name. Both
names refer to the same function object, so they are entirely
interchangeable; the original remains fully supported and is not
scheduled for removal, and existing scripts keep working unchanged.

## Examples

``` r
# \donttest{
library(ggstatsplot)
#> You can cite this package as:
#>      Patil, I. (2021). Visualizations with statistical details: The 'ggstatsplot' approach.
#>      Journal of Open Source Software, 6(61), 3167, doi:10.21105/joss.03167
library(dplyr)
#> 
#> Attaching package: ‘dplyr’
#> The following object is masked from ‘package:colleyRstats’:
#> 
#>     replace_values
#> The following objects are masked from ‘package:stats’:
#> 
#>     filter, lag
#> The following objects are masked from ‘package:base’:
#> 
#>     intersect, setdiff, setequal, union

# Generate a plot
plt <- ggbetweenstats(mtcars, am, mpg)

reportggstatsplot(plt, iv = "am", dv = "mpg")
#> A Welch Two Sample t-test found a significant effect of \am on mpg (t(18.33)=-3.77, \p{0.001}, r=-1.35). 
# }
```
