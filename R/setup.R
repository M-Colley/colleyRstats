#' Configure Global R Environment for colleyRstats
#'
#' Sets the ggplot2 theme, and on request the \code{conflicted} preferences, to
#' match the standards used in the colleyRstats workflow.
#'
#' @param set_options Logical. If \code{TRUE}, prints a notice that global
#'   options are no longer changed automatically. Default is \code{FALSE}.
#' @param set_theme Logical. If \code{TRUE}, sets the default \code{ggplot2} theme
#'   to \code{see::theme_lucid} with custom modifications. Default is \code{TRUE}.
#' @param base_size Base font size in points for the theme. Every text element
#'   is sized relative to it (see [colley_theme()]), so a figure destined for a
#'   3.33 in column and one destined for a slide can share the same theme and
#'   differ only in this number. Default 17 reproduces the sizes used before
#'   this argument existed. [save_paper_figure()] overrides it per figure to
#'   match the width actually being written.
#' @param set_conflicts Logical. If \code{TRUE}, registers this package's
#'   \code{conflicted} preferences, which favor \code{dplyr} and other tidyverse
#'   packages. Default is \code{FALSE}. Registering them activates
#'   \code{conflicted}, which takes over \code{library()} for the rest of the
#'   session, so it is opt-in and belongs after your \code{library()} calls --
#'   see Details.
#' @param print_citation Logical. If \code{TRUE}, prints the citation information
#'   for this package. Default is \code{TRUE}.
#' @param verbose Logical. If \code{TRUE}, emit informational messages.
#'   Default is \code{TRUE}.
#'
#' @details
#' \strong{\code{set_conflicts} changes what \code{library()} does, so call it
#' last.} \code{conflicted::conflict_prefer()} does not merely record a
#' preference: it activates \code{conflicted}, which attaches a
#' \code{.conflicts} environment carrying its own \code{library()} and
#' \code{require()} shims. Every later attach in the session goes through them,
#' and they forward \code{quietly} and \code{verbose} into \code{base::library()}
#' as unevaluated symbols. A package whose \code{.onAttach} inspects the calling
#' \code{library()} frame -- meta-packages that attach their own constituents do
#' this to decide whether to print a banner -- then evaluates those symbols in a
#' frame that does not bind them, and the attach fails outright:
#'
#' \preformatted{
#' colleyRstats_setup(set_conflicts = TRUE)
#' library(easystats)
#' #> Error: .onAttach failed in attachNamespace() for 'easystats':
#' #>   object 'quietly' not found
#' }
#'
#' The two mechanisms do not compose, and \code{colleyRstats_setup()} cannot
#' know whether more \code{library()} calls are coming. The preferences are
#' therefore opt-in, and the contract when you opt in is that
#' \code{colleyRstats_setup()} runs \emph{after} everything else is attached:
#'
#' \preformatted{
#' library(colleyRstats)
#' library(easystats)
#' library(dplyr)
#' colleyRstats_setup(set_conflicts = TRUE)   # last
#' }
#'
#' That is also the ordering in which the preferences are worth most:
#' \code{conflicted} resolves only those names that are ambiguous among the
#' packages attached at the time, so a call made before the rest of the script's
#' \code{library()} calls has less to work with.
#'
#' @return Invisibly returns \code{NULL}.
#' @export
#'
#' @examples
#' # Runs everywhere, no extra packages, no session side effects
#' colleyRstats::colleyRstats_setup(
#'   set_options = FALSE,
#'   set_theme = FALSE,
#'   set_conflicts = FALSE,
#'   print_citation = FALSE,
#'   verbose = FALSE
#' )
#'
#' \donttest{
#' # Full setup (requires suggested packages; changes session defaults)
#' if (requireNamespace("ggplot2", quietly = TRUE) &&
#'     requireNamespace("see", quietly = TRUE)) {
#'   local({
#'     old_theme <- ggplot2::theme_get()
#'     on.exit(ggplot2::theme_set(old_theme), add = TRUE)
#'
#'     colleyRstats::colleyRstats_setup(
#'       set_options = FALSE,
#'       set_conflicts = FALSE,   # the default; see Details
#'       print_citation = FALSE,
#'       verbose = TRUE
#'     )
#'
#'     ggplot2::ggplot(mtcars, ggplot2::aes(mpg, wt)) +
#'       ggplot2::geom_point()
#'   })
#' }
#' }
colleyRstats_setup <- function(set_options = FALSE,
                        set_theme = TRUE,
                        base_size = 17,
                        set_conflicts = FALSE,
                        print_citation = TRUE,
                        verbose = TRUE) {

  # 1. Global options: do not change them, just notify if requested
  if (isTRUE(set_options) && isTRUE(verbose)) {
    message(
      "Argument 'set_options' is deprecated and has no effect; ",
      "colleyRstats no longer changes global options() for CRAN compliance.\n",
      "If you want these settings, call for example:\n",
      "  options(scipen = 999, digits = 10, digits.secs = 3)"
    )
  }

  # 2. Set conflict preferences
  #
  # Off by default, and that default is load-bearing. conflict_prefer() records
  # a preference AND activates conflicted, which attaches `.conflicts` with its
  # own library()/require() shims; from then on every attach in the session goes
  # through them. The shims forward `quietly`/`verbose` into base::library() as
  # unevaluated symbols, and a package whose .onAttach reads the calling
  # library() frame -- easystats does, to decide whether to print its banner --
  # evaluates them in a frame that does not bind them, so the attach dies with
  # "object 'quietly' not found". The two mechanisms cannot be composed and this
  # function cannot know whether more library() calls are coming, so the caller
  # opts in at the point where it is correct: after everything is attached.
  if (isTRUE(set_conflicts)) {
    if (!requireNamespace("conflicted", quietly = TRUE)) {
      if (isTRUE(verbose)) {
        warning("Package 'conflicted' is not installed. Skipping conflict resolution.")
      }
    } else {
      preferences <- list(
        c("mutate", "dplyr"),
        c("filter", "dplyr"),
        c("select", "dplyr"),
        c("summarise", "dplyr"),
        c("summarize", "dplyr"),
        c("rename", "dplyr"),
        c("arrange", "dplyr"),
        c("first", "dplyr"),
        c("last", "dplyr"),
        c("lag", "dplyr"),
        c("recode", "dplyr"),
        c("src", "dplyr"),
        c("alpha", "scales"),
        c("col_factor", "scales"),
        c("annotate", "ggplot2"),
        c("%+%", "ggplot2"),
        c("ar", "brms"),
        c("cs", "brms"),
        c("bootCase", "car"),
        c("cache_info", "httr"),
        c("cohens_d", "effectsize"),
        c("eta_squared", "effectsize"),
        c("phi", "effectsize"),
        c("cor_test", "correlation"),
        c("describe", "psych"),
        c("headtail", "psych"),
        c("logit", "psych"),
        c("discard", "purrr"),
        c("some", "purrr"),
        c("display", "report"),
        c("expand", "tidyr"),
        c("extract", "tidyr"),
        c("pack", "tidyr"),
        c("unpack", "tidyr"),
        c("format_error", "insight"),
        c("format_message", "insight"),
        c("format_warning", "insight"),
        c("get_emmeans", "modelbased"),
        c("has_name", "tibble"),
        c("label", "xtable"),
        c("label<-", "Hmisc"),
        c("lmer", "lme4"),
        c("ngrps", "lme4"),
        c("rescale", "datawizard"),
        c("test", "devtools")
      )

      # try() keeps one unsettable preference (a package that has since renamed
      # or dropped the function) from aborting the rest, but a preference that
      # silently fails to register is still a preference the caller does not
      # have, so collect the failures rather than discarding them.
      failed <- character()
      suppressMessages({
        for (p in preferences) {
          set <- try(
            conflicted::conflict_prefer(p[1L], p[2L], quiet = TRUE),
            silent = TRUE
          )
          if (inherits(set, "try-error")) {
            failed <- c(failed, paste0(p[2L], "::", p[1L]))
          }
        }
      })

      if (isTRUE(verbose)) {
        message(
          "Conflict preferences set (favoring dplyr, ggplot2, etc.).\n",
          "'conflicted' now manages library() for this session: attach any ",
          "further packages before calling colleyRstats_setup(), not after."
        )
        if (length(failed) > 0L) {
          message(
            "Could not set ", length(failed), " preference(s): ",
            paste(failed, collapse = ", ")
          )
        }
      }
    }
  }

  # 3. Set ggplot2 theme
  if (isTRUE(set_theme)) {
    if (!requireNamespace("ggplot2", quietly = TRUE) ||
        !requireNamespace("see", quietly = TRUE)) {
      if (isTRUE(verbose)) {
        warning("Packages 'ggplot2' and/or 'see' not installed. Skipping theme setup.")
      }
    } else {
      ggplot2::theme_set(colley_theme(base_size = base_size))
      if (isTRUE(verbose)) {
        message(
          "ggplot2 theme set to 'theme_lucid' with custom sizing ",
          "(base_size = ", base_size, " pt)."
        )
      }
    }
  }

  # 4. Citation
  if (isTRUE(print_citation)) {
    citation_text <- NULL
    citation_file <- system.file("CITATION", package = "colleyRstats")
    if (nzchar(citation_file)) {
      citation_text <- utils::capture.output(
        utils::citation(package = "colleyRstats")
      )
    } else if (file.exists(file.path("inst", "CITATION"))) {
      citation_text <- utils::capture.output(
        utils::readCitationFile(file.path("inst", "CITATION"))
      )
    } else if (file.exists("CITATION")) {
      citation_text <- utils::capture.output(
        utils::readCitationFile("CITATION")
      )
    } else {
      citation_text <- utils::capture.output(
        utils::citation(package = utils::packageName())
      )
    }

    msg <- paste0(
      "\nIf you use these functions, please cite:\n\n",
      paste(citation_text, collapse = "\n")
    )
    message(msg)
  }

  invisible(NULL)
}


# Effective value of one theme element for a plot: what the plot sets, falling
# back to the session theme. ggplot2 stores only the overrides on the plot.
.plot_theme_element <- function(plot, name) {
  el <- NULL
  if (!is.null(plot$theme)) el <- plot$theme[[name]]
  if (is.null(el)) el <- ggplot2::theme_get()[[name]]
  el
}


#' The colleyRstats ggplot2 theme
#'
#' \code{see::theme_lucid()} with the sizing and legend conventions used across
#' colleyRstats figures. Every text element is expressed as a multiple of
#' \code{base_size} rather than in absolute points, which is what lets the same
#' theme serve a 3.33 in journal column and a full-width figure: only
#' \code{base_size} changes.
#'
#' Sizing text in absolute points is the usual reason a figure comes out
#' unreadable. Point sizes do not shrink when the canvas does, so a theme tuned
#' on a large canvas puts 20 pt axis titles on a 3.33 in figure, where they
#' overrun the panel and the axis labels collide. Choose \code{base_size} from
#' the size the figure is finally PLACED at -- roughly the body-text size of the
#' document, or a point or two below it. [save_paper_figure()] does this for you.
#'
#' The multipliers are, relative to \code{base_size}: axis titles 1.15, axis
#' text 1.0, plot title 1.65, subtitle 1.0, legend text 0.9, caption 0.8, strip
#' text 1.3.
#'
#' @param base_size Base font size in points. Default 17, which reproduces the
#'   sizes colleyRstats used before this function was factored out.
#' @param base_family Base font family, passed to \code{see::theme_lucid()}.
#'
#' @return A ggplot2 theme object.
#' @export
#'
#' @examples
#' \donttest{
#' if (requireNamespace("see", quietly = TRUE)) {
#'   ggplot2::ggplot(mtcars, ggplot2::aes(mpg, wt)) +
#'     ggplot2::geom_point() +
#'     colley_theme(base_size = 8)   # sized for a single journal column
#' }
#' }
colley_theme <- function(base_size = 17, base_family = "") {
  if (!requireNamespace("see", quietly = TRUE)) {
    stop("Package 'see' is required for colley_theme().")
  }
  if (!is.numeric(base_size) || length(base_size) != 1L ||
      is.na(base_size) || base_size <= 0) {
    stop("`base_size` must be a single positive number.")
  }

  r <- .COLLEY_TEXT_RATIOS
  see::theme_lucid(base_size = base_size, base_family = base_family) +
    ggplot2::theme(
      # rel() is relative to the parent element, which for all of these is
      # `text`, i.e. base_size. Absolute sizes here would defeat the point.
      axis.title    = ggplot2::element_text(size = ggplot2::rel(r[["axis.title"]])),
      axis.text     = ggplot2::element_text(size = ggplot2::rel(r[["axis.text"]])),
      plot.title    = ggplot2::element_text(size = ggplot2::rel(r[["plot.title"]])),
      plot.subtitle = ggplot2::element_text(size = ggplot2::rel(r[["plot.subtitle"]])),
      plot.caption  = ggplot2::element_text(size = ggplot2::rel(r[["plot.caption"]])),
      legend.text   = ggplot2::element_text(size = ggplot2::rel(r[["legend.text"]])),
      strip.text    = ggplot2::element_text(size = ggplot2::rel(r[["strip.text"]])),
      legend.title  = ggplot2::element_blank(),
      legend.background = ggplot2::element_blank(),
      legend.position = "inside",
      legend.position.inside = c(0.85, 0.45)
    )
}


# Text sizes as multiples of base_size. Held in one place so that colley_theme()
# and the resizing applied by save_paper_figure() cannot drift apart.
.COLLEY_TEXT_RATIOS <- c(
  text          = 1.00,
  axis.title    = 1.15,
  axis.text     = 1.00,
  plot.title    = 1.65,
  plot.subtitle = 1.00,
  plot.caption  = 0.80,
  legend.text   = 0.90,
  strip.text    = 1.30
)

# A theme that restates the colleyRstats sizes at a given base, in absolute
# points. Added to a plot at save time it overrides whatever sizes the plot is
# carrying -- including the absolute ones that ggstatsplot and friends set
# internally, which a rel()-based theme alone cannot reach.
#
# Spacing is rescaled alongside the text, using the same half_line convention
# ggplot2 itself derives from base_size. Resizing only the text leaves legend
# keys, legend spacing and plot margins at the sizes the session theme chose:
# on a small figure the type then looks right but the legend still occupies the
# space it needed at 17 pt, and pushes itself off the panel.
#
# legend.title is deliberately absent: colley_theme() blanks it, and naming it
# here with a size would replace that element_blank() and bring every legend
# title back. save_paper_figure() resizes it only where one is actually wanted.
.resize_theme <- function(base_size) {
  half_line <- base_size / 2

  args <- lapply(.COLLEY_TEXT_RATIOS, function(ratio) {
    ggplot2::element_text(size = base_size * ratio)
  })

  args$legend.key.size    <- grid::unit(1.2 * base_size, "pt")
  args$legend.spacing     <- grid::unit(base_size, "pt")
  args$legend.box.spacing <- grid::unit(base_size, "pt")
  args$legend.margin      <- ggplot2::margin(half_line, half_line, half_line, half_line)
  args$panel.spacing      <- grid::unit(half_line, "pt")
  args$plot.margin        <- ggplot2::margin(half_line, half_line, half_line, half_line)

  do.call(ggplot2::theme, args)
}


# Base font size of the currently active theme, in points. Used by the plotting
# wrappers so that annotation drawn by other packages (ggsignif brackets, for
# instance) matches the theme instead of being fixed in absolute units.
.theme_base_size <- function(default = 11) {
  sz <- try(ggplot2::theme_get()$text$size, silent = TRUE)
  if (inherits(sz, "try-error") || is.null(sz) || !is.numeric(sz) ||
      length(sz) != 1L || is.na(sz) || sz <= 0) {
    return(default)
  }
  sz
}

# ggsignif and other ggplot2 *geoms* take text size in MILLIMETRES, while themes
# take points. Mixing the two silently is why bracket labels come out roughly
# three times the size of the axis text they sit next to.
.pt_to_mm <- function(pt) pt / .pt

# Significance-bracket labels, as a multiple of the theme base size. Chosen so
# that at the historical base of 17 pt this reproduces the 4 mm / 3.9 mm that
# were previously hard-coded, while now following the theme when it changes.
.SIGNIF_TEXT_RATIO <- 0.67

# Text size in millimetres for ggsignif annotation under the active theme.
.signif_text_mm <- function(ratio = .SIGNIF_TEXT_RATIO) {
  .pt_to_mm(.theme_base_size() * ratio)
}
