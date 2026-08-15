# Drawing a plot with no graphics device open makes R open one itself, which in
# a non-interactive session means an Rplots.pdf in the working directory -- for
# tests, tests/testthat. That left a stray file in the repo after every
# devtools::test(). Send the tests' output to a null device instead, and close
# it once the suite is done.
#
# This lives in setup.R rather than a helper-*.R file because teardown_env()
# only exists once the test run proper has started; helpers are sourced before
# that.
grDevices::pdf(NULL)
withr::defer(grDevices::dev.off(), testthat::teardown_env())
