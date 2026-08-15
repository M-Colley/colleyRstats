# Methods-section sentence justifying the test selection

Runs the group-wise Shapiro-Wilk normality check (and optionally
Levene's test for homogeneity of variances) and turns the outcome into a
ready-made methods-section sentence, including the relevant statistics.
This is the justification reviewers expect next to the choice of a
parametric or non-parametric test.

## Usage

``` r
assumption_methods_text(data, x, y, include_homogeneity = FALSE)
```

## Arguments

- data:

  the data frame

- x:

  the grouping variable (column name as string)

- y:

  the dependent variable (column name as string)

- include_homogeneity:

  whether to also report Levene's test. Useful for between-subjects
  designs. Default `FALSE`.

## Value

Invisibly returns the sentence(s) as a single string; the text is also
emitted via [`message()`](https://rdrr.io/r/base/message.html).

## Examples

``` r
set.seed(1)
d <- data.frame(g = rep(c("A", "B"), each = 20), v = rnorm(40))
assumption_methods_text(d, x = "g", y = "v")
#> Shapiro--Wilk tests indicated no significant deviation from normality in any group (all $p \geq 0.05$); therefore, parametric tests were used.
```
