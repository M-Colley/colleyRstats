if (!requireNamespace("colleyRstats", quietly = TRUE)) {
  if (!requireNamespace("pkgload", quietly = TRUE)) {
    stop("Package 'pkgload' is required to load colleyRstats for tests.")
  }
  pkgload::load_all(path = ".", export_all = FALSE, quiet = TRUE)
} else {
  suppressPackageStartupMessages(library(colleyRstats))
}
