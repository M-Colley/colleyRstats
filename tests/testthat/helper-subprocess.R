# conflicted's library()/require() shims are session-global: once colleyRstats_setup()
# has installed them there is no supported way to take them back out, and every
# later attach in the process goes through them. Checking what setup() does to
# library() therefore cannot be done in the testthat session itself without
# leaking into every test that follows -- and the thing under test is precisely
# an attach performed *after* setup(). These checks each run in a fresh R.
#
# Returns NULL when no subprocess could be started, and otherwise a list with
# the combined output and the exit status. `output` begins with "SKIP:" if the
# child could not load colleyRstats (e.g. testing a source tree that was never
# installed), which the callers turn into a testthat skip.
run_in_fresh_r <- function(lines) {
  rscript <- file.path(
    R.home("bin"),
    if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"
  )
  if (!file.exists(rscript)) {
    return(NULL)
  }

  script <- tempfile(fileext = ".R")
  on.exit(unlink(script), add = TRUE)

  # --vanilla means the child reads no profile and no .Renviron, so the library
  # paths have to be handed over explicitly; without this it would not find the
  # copy of colleyRstats that R CMD check just installed.
  preamble <- c(
    sprintf(".libPaths(%s)", paste(deparse(.libPaths()), collapse = "")),
    'if (!requireNamespace("colleyRstats", quietly = TRUE)) {',
    '  cat("SKIP: colleyRstats is not installed\\n")',
    '  quit(save = "no", status = 0L)',
    "}"
  )

  writeLines(c(preamble, lines), script)

  out <- suppressWarnings(
    system2(rscript, c("--vanilla", shQuote(script)),
            stdout = TRUE, stderr = TRUE)
  )
  status <- attr(out, "status")

  list(
    output = paste(out, collapse = "\n"),
    status = if (is.null(status)) 0L else as.integer(status)
  )
}

# Skip unless a fresh R could actually be run with colleyRstats available.
skip_unless_subprocess <- function(res) {
  skip_if(is.null(res), "could not locate Rscript for a subprocess check")
  skip_if(grepl("^SKIP:", res$output), "colleyRstats is not installed")
}
