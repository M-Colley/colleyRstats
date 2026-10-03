# Classify the measurement scale of an outcome variable

Decides how a dependent variable should be modelled by inspecting its
type and distribution of values. The measurement scale is the first
branch of a principled model choice: it dictates the *family* (Gaussian,
binomial, Poisson, cumulative-link) before any distributional assumption
is checked.

## Usage

``` r
classify_outcome(y, ordinal_max_levels = 7L)
```

## Arguments

- y:

  The outcome vector.

- ordinal_max_levels:

  Integer. Integer-valued numerics with at most this many distinct
  values are treated as ordinal (Likert-like). Default 7.

## Value

A single string, one of `"continuous"`, `"ordinal"`, `"binary"`,
`"count"`, or `"nominal"`.

## Details

The rules are deliberately simple and transparent:

- ordered factor \\\rightarrow\\ `"ordinal"`;

- logical, a factor with two observed levels, a character vector with
  two distinct values, or a numeric coded `0`/`1` \\\rightarrow\\
  `"binary"`;

- unordered factor/character with more than two levels \\\rightarrow\\
  `"nominal"`;

- a numeric with at most two distinct values that are *not* `0`/`1` – a
  1–7 item on which only 6 and 7 were ticked, or a yes/no item coded 1/2
  – is *not* taken for binary: it is classified as `"ordinal"` (whole
  numbers) or `"continuous"`, with a warning;

- integer-valued numeric with at most `ordinal_max_levels` distinct
  values (a Likert-type item) \\\rightarrow\\ `"ordinal"`;

- non-negative whole numbers that are all multiples of 5 within \\\[0,
  100\]\\ (the shape of a raw NASA-TLX subscale or a 0–100 slider in
  steps of 5) \\\rightarrow\\ `"continuous"`, with a message;

- any other non-negative whole numbers \\\rightarrow\\ `"count"`. This
  is always announced with a message that says how to override it, and
  the message becomes a *warning* when the values lie in a closed range
  without zeros (\\\[1, 100\]\\) – the typical shape of a summed
  questionnaire score or a 1–10 rating, which a Poisson model would
  misdescribe;

- any other numeric \\\rightarrow\\ `"continuous"`.

The heuristics can never be perfect (a 1–7 Likert item and a small count
are genuinely ambiguous); pass an explicit `outcome_type` to
[`recommend_test()`](https://m-colley.github.io/colleyRstats/reference/recommend_test.md)
or
[`fit_recommended()`](https://m-colley.github.io/colleyRstats/reference/fit_recommended.md)
when you want to override them.

## Examples

``` r
classify_outcome(rnorm(50)) # "continuous"
#> [1] "continuous"
classify_outcome(factor(sample(1:5, 50, TRUE), ordered = TRUE)) # "ordinal"
#> [1] "ordinal"
classify_outcome(sample(0:1, 50, TRUE)) # "binary"
#> [1] "binary"
classify_outcome(rpois(50, 3)) # "count", with a message
#> The outcome holds non-negative whole numbers (9 distinct values, 0-8), so it is classified as a count and modelled with a Poisson (or, if over-dispersed, negative-binomial) model. If it is a rating, a summed questionnaire score or another bounded scale rather than a count of events, pass outcome_type = "continuous" (or "ordinal").
#> [1] "count"
```
