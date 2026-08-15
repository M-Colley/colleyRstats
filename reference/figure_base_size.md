# Base font size for a figure of a given width

The rule
[`save_paper_figure()`](https://m-colley.github.io/colleyRstats/reference/save_paper_figure.md)
uses to pick a type size from a figure width. Text in a figure should
read at roughly the body-text size of the document the figure is placed
in; since a figure is usually placed at 100\\ means the type size has to
follow the physical width. The rule is calibrated so that the two
standard widths land on sensible values: 3.33 in (a two-column journal
column) gives 7 pt and 7 in (full text width) gives 9 pt, with linear
interpolation between and clamping outside.

## Usage

``` r
figure_base_size(width, min_size = 6, max_size = 12)
```

## Arguments

- width:

  Figure width in inches.

- min_size, max_size:

  Bounds, so that very small or very large figures still get a usable
  size. Defaults 6 and 12 points.

## Value

A single number: the base font size in points.

## Examples

``` r
figure_base_size(3.33)  # 7
#> [1] 7
figure_base_size(7)     # 9
#> [1] 9
```
