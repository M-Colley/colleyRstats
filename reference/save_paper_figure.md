# Save a plot with publication-ready defaults

Saves a ggplot with sizes matching common two-column conference/journal
layouts (e.g., ACM): a single-column figure is 3.33 in wide, a
full-width figure 7 in. On Windows and Linux, PDFs are rendered with
[`grDevices::cairo_pdf`](https://rdrr.io/r/grDevices/cairo.html) so that
fonts are embedded and unicode glyphs survive; on macOS the default pdf
device is used instead, because R's cairo on macOS is known to crash
some setups (e.g., GitHub Actions runners) and the macOS device handles
fonts well on its own.

## Usage

``` r
save_paper_figure(
  plot = ggplot2::last_plot(),
  filename,
  columns = 1,
  width = NULL,
  height = NULL,
  base_size = NULL,
  dpi = 300,
  device = NULL
)
```

## Arguments

- plot:

  The plot to save (defaults to the last plot displayed).

- filename:

  Output path; the extension selects the device (`.pdf` is recommended
  for LaTeX).

- columns:

  1 for a single-column figure, 2 for a full-width figure. Ignored when
  `width` is given.

- width:

  Figure width in inches; overrides `columns`.

- height:

  Figure height in inches. Defaults to 2/3 of the width.

- base_size:

  Base font size in points for the saved figure, applied via
  [`colley_theme()`](https://m-colley.github.io/colleyRstats/reference/colley_theme.md)
  sizing on top of whatever theme the plot carries. The default `NULL`
  derives it from `width`, so a 3.33 in figure gets about 7 pt and a 7
  in figure about 9 pt – close to the body text of a typical two-column
  paper, which is what makes a figure legible at 100\\ rather than only
  when zoomed. Pass a number to choose it yourself, or `NA` to leave the
  plot's own text sizes untouched.

- dpi:

  Resolution for raster output. Default 300.

- device:

  Graphics device passed to
  [`ggplot2::ggsave()`](https://ggplot2.tidyverse.org/reference/ggsave.html).
  The default `NULL` selects it automatically as described above; pass
  e.g. [`grDevices::cairo_pdf`](https://rdrr.io/r/grDevices/cairo.html)
  explicitly to override.

## Value

Invisibly returns `filename`.

## Examples

``` r
# \donttest{
p <- ggplot2::ggplot(mtcars, ggplot2::aes(factor(cyl), mpg)) +
  ggplot2::geom_boxplot()
save_paper_figure(p, file.path(tempdir(), "cyl-mpg.pdf"), columns = 1)
#> Saved figure to '/tmp/RtmpbCzReO/cyl-mpg.pdf' (3.33 x 2.22 in, base font 7 pt).
# }
```
