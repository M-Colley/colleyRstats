# Function to define a plot, either showing the main or interaction effect in bold.

Function to define a plot, either showing the main or interaction effect
in bold.

## Usage

``` r
generateEffectPlot(
  data,
  x,
  y,
  fillColourGroup,
  ytext = "testylab",
  xtext = "testxlab",
  legendPos = c(0.1, 0.23),
  legendHeading = NULL,
  shownEffect = "main",
  effectLegend = FALSE,
  effectDescription = NULL,
  xLabelsOverwrite = NULL,
  useLatexMarkup = FALSE,
  numberColors = lifecycle::deprecated(),
  subject = NULL
)

plot_effect(
  data,
  x,
  y,
  fillColourGroup,
  ytext = "testylab",
  xtext = "testxlab",
  legendPos = c(0.1, 0.23),
  legendHeading = NULL,
  shownEffect = "main",
  effectLegend = FALSE,
  effectDescription = NULL,
  xLabelsOverwrite = NULL,
  useLatexMarkup = FALSE,
  numberColors = lifecycle::deprecated(),
  subject = NULL
)
```

## Arguments

- data:

  the data frame

- x:

  factor shown on the x-axis

- y:

  dependent variable

- fillColourGroup:

  group to color

- ytext:

  label for y-axis

- xtext:

  label for x-axis

- legendPos:

  position for legend

- legendHeading:

  custom heading for legend

- shownEffect:

  either "main" or "interaction"

- effectLegend:

  TRUE: show legend for effect (Default: FALSE)

- effectDescription:

  custom label for effect

- xLabelsOverwrite:

  custom labels for x-axis

- useLatexMarkup:

  use latex font and markup

- numberColors:

  **\[deprecated\]** Never had any effect: the colours come from
  [`see::scale_colour_see()`](https://easystats.github.io/see/reference/scale_color_see.html),
  which uses one colour per group. Passing it warns.

- subject:

  optional participant-ID column (a string). Give it when `x` and/or
  `fillColourGroup` vary within participants, to get within-subject
  error bars (see Details). Default `NULL`.

## Value

a plot

## Details

**Points and lines.** The small points and the dashed (main) or bold
(interaction) per-group lines are the cell means. The bold main-effect
line and its large points are the *unweighted* marginal means of `x`:
for each level of `x`, the mean of the cell means across
`fillColourGroup`. That is the quantity a main effect in a factorial
ANOVA is about; the mean of the raw observations would weight each cell
by its size and, in an unbalanced design, follow whichever group happens
to be larger.

**Error bars** are 95\\

- `subject = NULL` (default): nonparametric bootstrap intervals
  ([`ggplot2::mean_cl_boot()`](https://ggplot2.tidyverse.org/reference/hmisc.html),
  requires 'Hmisc'). These treat every observation as independent, i.e.
  they are **between-subject** intervals. That is right for
  between-subject factors, but for a factor that varies within
  participants they include the between-participant spread a
  within-subject comparison does not depend on, and look misleadingly
  wide.

- `subject` given: **within-subject** intervals after Cousineau (2005),
  with the Morey (2008) correction. Each participant's scores are
  centred on their own mean, the variance of the normalised scores is
  inflated by \\M/(M-1)\\ (\\M\\ = number of within-subject conditions),
  and a factor that does not vary within participants is respected by
  normalising within its groups. Participants without a value in every
  within-subject condition are dropped (with a message), and more than
  one row per participant and cell is an error.

Either way, the intervals describe single means, not differences between
them; overlapping bars do not by themselves imply a non-significant
difference.

## Naming

`plot_effect()` is the spelling used throughout the documentation and
the one to prefer in new code: the `report_*` / `plot_*` / `check_*`
prefixes make the API discoverable through autocomplete.

`generateEffectPlot()` **\[superseded\]** is the original name. Both
names refer to the same function object, so they are entirely
interchangeable; the original remains fully supported and is not
scheduled for removal, and existing scripts keep working unchanged.

## References

Cousineau, D. (2005). Confidence intervals in within-subject designs: A
simpler solution to Loftus and Masson's method. *Tutorials in
Quantitative Methods for Psychology, 1*(1), 42–45.

Morey, R. D. (2008). Confidence intervals from normalized data: A
correction to Cousineau (2005). *Tutorials in Quantitative Methods for
Psychology, 4*(2), 61–64.

## Examples

``` r
# \donttest{
set.seed(123)
main_df <- data.frame(
  strategy    = factor(rep(c("A", "B"), each = 20)),
  Emotion     = factor(rep(c("Happy", "Sad"), times = 20)),
  trust_mean  = rnorm(40, mean = 5, sd = 1)
)

generateEffectPlot(
  data = main_df,
  x = "strategy",
  y = "trust_mean",
  fillColourGroup = "Emotion",
  ytext = "Trust",
  xtext = "Strategy",
  legendPos = c(0.1, 0.23)
)

# }
```
