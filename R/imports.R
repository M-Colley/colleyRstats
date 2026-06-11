# NOTE: ggplot2 lives in Depends (not just Imports) on purpose. The ggproto
# stats of ggpmisc 0.7.0 / ggpp 0.6.0 resolve their parent classes lazily via
# the search path: ggpmisc::stat_poly_line() fails with "object 'Stat' not
# found" in ANY context where ggplot2 is not attached -- e.g. R CMD check
# running testthat via library(colleyRstats), or user scripts that only load
# namespaces. Depends guarantees ggplot2 is attached whenever this package is.
# pkgload::load_all() masks the problem, so verify changes here against an
# *installed* copy of the package.

#' @import ggplot2
#' @import ggpmisc
#' @importFrom dplyr filter select mutate group_by summarise across all_of bind_cols bind_rows arrange case_when
#' @importFrom rlang sym
#' @importFrom stats as.formula lm median pnorm qnorm residuals sd shapiro.test setNames
#' @importFrom utils globalVariables
#' @importFrom see scale_color_see scale_fill_see scale_colour_see
#' @importFrom stringr str_detect str_split
#' @importFrom tidyr drop_na
#' @importFrom ggstatsplot ggbetweenstats ggwithinstats extract_stats
NULL
