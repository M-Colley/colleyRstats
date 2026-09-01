# Animate a Multi-objective Optimization Plot

Renders
[`generateMoboPlot2()`](https://m-colley.github.io/colleyRstats/reference/generateMoboPlot2.md)
one iteration at a time and encodes the frames into a video, so a talk
or a supplement can show an optimisation run building up rather than
only its end state. Frame *i* is the same plot restricted to the data up
to iteration *i*: the mean points, their bootstrapped intervals, the
fitted line and its equation all move as the run proceeds.

## Usage

``` r
animate_mobo2(
  data,
  x = "Iteration",
  y,
  filename,
  ...,
  fps = 5,
  end_pause = 2,
  width = 8,
  height = 5,
  dpi = 150,
  label_iterations = TRUE
)
```

## Arguments

- data:

  A data frame holding the run, as for
  [`generateMoboPlot2()`](https://m-colley.github.io/colleyRstats/reference/generateMoboPlot2.md).

- x:

  A string naming the iteration column in `data`. Default `"Iteration"`.

- y:

  A string naming the objective column in `data`.

- filename:

  Path of the video to write. Its extension chooses the container:
  `.mp4`, `.gif`, `.mov`, `.webm` – whatever the `av` package's FFmpeg
  build can encode.

- ...:

  Further arguments for
  [`generateMoboPlot2()`](https://m-colley.github.io/colleyRstats/reference/generateMoboPlot2.md),
  e.g. `phaseCol`, `fillColourGroup`, `ytext`, `legendPos`,
  `fillLabels`.

- fps:

  Frames per second. One frame is drawn per iteration, so this is
  equally the number of iterations shown per second. Default 5.

- end_pause:

  Seconds to hold the final frame, so the finished plot can be read
  before the video ends or loops. Default 2; use 0 for no hold.

- width, height:

  Frame size in inches. Default 8 x 5.

- dpi:

  Resolution. Default 150, so the default frame is 1200 x 750 px.

- label_iterations:

  Whether to caption each frame with the iteration it shows. Default
  `TRUE`, which writes the plot's subtitle.

## Value

Invisibly returns `filename`.

## Details

The plot is built once from the complete data, and a frame only ever
hides rows. That is what keeps the axes, the sampling/optimisation
guides and the legend still while the data grows – and it is also the
only way the early frames can be drawn at all, since
[`generateMoboPlot2()`](https://m-colley.github.io/colleyRstats/reference/generateMoboPlot2.md)
requires both phases to be present and the first iterations are all
sampling.

## See also

[`generateMoboPlot2()`](https://m-colley.github.io/colleyRstats/reference/generateMoboPlot2.md)
for the static plot.

## Examples

``` r
# \donttest{
# Kept deliberately tiny: every frame is a full ggplot render, so the cost
# of the example is set by the number of iterations, not by the frame size.
if (requireNamespace("av", quietly = TRUE)) {
  set.seed(42)
  df <- data.frame(
    Iteration   = rep(1:3, each = 4),
    ConditionID = rep(rep(c("A", "B"), each = 2), 3),
    Phase       = rep(c("Sampling", "Optimization"), times = c(2 * 4, 4))
  )
  df$score <- 0.3 + 0.05 * df$Iteration + stats::rnorm(nrow(df), sd = 0.05)

  animate_mobo2(
    df,
    y = "score", ytext = "Score",
    filename = file.path(tempdir(), "mobo.mp4"),
    width = 4, height = 2.5, dpi = 96, end_pause = 0
  )
}
#> Rendering 3 frames ...
#> Saved animation to '/tmp/RtmpkLHuaX/mobo.mp4' (3 iterations at 5 fps, 384 x 240 px).
# }
```
