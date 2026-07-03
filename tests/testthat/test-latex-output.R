# Tests for the Overleaf-oriented output layer: escaping, macro expansion,
# the .sty package, name/result macros, emit_overleaf(), and booktabs tables.

# ---- latex_escape --------------------------------------------------------

test_that("latex_escape escapes every LaTeX special character", {
  expect_identical(latex_escape("tlx_mental"), "tlx\\_mental")
  expect_identical(latex_escape("a & b"), "a \\& b")
  expect_identical(latex_escape("50%"), "50\\%")
  expect_identical(latex_escape("x$y"), "x\\$y")
  expect_identical(latex_escape("c#1"), "c\\#1")
  expect_identical(latex_escape("a{b}c"), "a\\{b\\}c")
  expect_identical(latex_escape("a~b"), "a\\textasciitilde{}b")
  expect_identical(latex_escape("a^b"), "a\\textasciicircum{}b")
  expect_identical(latex_escape("p<.05"), "p\\textless{}.05")
  expect_identical(latex_escape("p>.05"), "p\\textgreater{}.05")
  expect_identical(latex_escape("a\\b"), "a\\textbackslash{}b")
})

test_that("latex_escape leaves clean names untouched and preserves NA/empty", {
  expect_identical(latex_escape("Mental Demand"), "Mental Demand")
  expect_identical(latex_escape("gesture:eHMI"), "gesture:eHMI") # colon is not special
  expect_identical(latex_escape(c("a_b", NA)), c("a\\_b", NA_character_))
  expect_identical(latex_escape(character(0)), character(0))
})

# ---- expand_latex_macros -------------------------------------------------

test_that("expand_latex_macros turns colleyRstats macros into plain math", {
  expect_identical(expand_latex_macros("\\F{2}{57}{4.50}"), "$F(2, 57) = 4.50$")
  expect_identical(expand_latex_macros("\\p{0.012}"), "$p = 0.012$")
  expect_identical(expand_latex_macros("\\pminor{0.001}"), "$p < 0.001$")
  expect_identical(expand_latex_macros("\\padj{0.02}"), "$p_{adj} = 0.02$")
  expect_identical(expand_latex_macros("\\padjminor{0.001}"), "$p_{adj} < 0.001$")
  expect_identical(expand_latex_macros("\\m{6.14}"), "$M = 6.14$")
  expect_identical(expand_latex_macros("\\sd{0.97}"), "$SD = 0.97$")
  expect_identical(expand_latex_macros("\\rankbiserial{1.00}"), "$r_{rb} = 1.00$")
  expect_match(expand_latex_macros("\\chisq"), "\\\\chi\\^2")
  # a realistic composite fragment survives and contains no residual macros
  out <- expand_latex_macros("(\\F{2}{57}{4.50}, \\p{0.012})")
  expect_false(grepl("\\\\F\\{|\\\\p\\{", out))
})

# ---- .tex_name -----------------------------------------------------------

test_that(".tex_name uses \\name only for valid all-letter command names", {
  expect_identical(colleyRstats:::.tex_name("Video"), "\\Video")
  # underscore/dot names are NOT valid commands -> escaped plain text
  expect_identical(colleyRstats:::.tex_name("tlx_mental"), "tlx\\_mental")
  expect_identical(colleyRstats:::.tex_name("Sepal.Length"), "Sepal.Length")

  old <- options(colleyRstats.name_macros = FALSE)
  on.exit(options(old), add = TRUE)
  expect_identical(colleyRstats:::.tex_name("Video"), "Video")
})

# ---- reporters honor escaping + plain mode -------------------------------

test_that("reporters escape special characters in variable names", {
  skip_if_not_installed("parameters")
  skip_if_not_installed("lme4")
  set.seed(1)
  d <- data.frame(
    id = factor(rep(1:15, each = 3)),
    cond = factor(rep(c("A", "B", "C"), 15)),
    score = rnorm(45)
  )
  m <- lme4::lmer(score ~ cond + (1 | id), data = d)
  txt <- paste(suppressMessages(reportGLMM(m, dv = "tlx_mental")), collapse = " ")
  expect_match(txt, "tlx\\\\_mental") # escaped underscore
  expect_false(grepl("tlx_mental", txt, fixed = TRUE)) # no raw underscore
})

test_that("plain-macro mode expands the macros in the sunk .tex file", {
  skip_if_not_installed("parameters")
  skip_if_not_installed("lme4")
  old <- options(colleyRstats.macros = FALSE)
  on.exit(options(old), add = TRUE)

  set.seed(1)
  d <- data.frame(
    id = factor(rep(1:15, each = 3)),
    cond = factor(rep(c("A", "B", "C"), 15)),
    score = rnorm(45)
  )
  m <- lme4::lmer(score ~ cond + (1 | id), data = d)
  f <- tempfile(fileext = ".tex")
  suppressMessages(reportGLMM(m, dv = "score", sink_to = f))
  content <- paste(readLines(f), collapse = "\n")
  expect_false(grepl("\\p{", content, fixed = TRUE)) # macro expanded away
  expect_match(content, "\\$p = ") # into plain math
})

# ---- colleyRstats.sty ----------------------------------------------------

test_that("use_colleyrstats_sty writes a loadable package file", {
  dir <- file.path(tempdir(), "sty-test")
  unlink(dir, recursive = TRUE)
  path <- use_colleyrstats_sty(dir)
  expect_true(file.exists(path))
  lines <- readLines(path)
  expect_true(any(grepl("\\ProvidesPackage{colleyRstats}", lines, fixed = TRUE)))
  expect_true(any(grepl("\\newcommand{\\rankbiserial}", lines, fixed = TRUE)))
  # refuses to overwrite unless asked
  expect_error(use_colleyrstats_sty(dir), "already exists")
  expect_silent(suppressMessages(use_colleyrstats_sty(dir, overwrite = TRUE)))
  unlink(dir, recursive = TRUE)
})

test_that("the shipped inst/colleyRstats.sty matches the generated source", {
  path <- system.file("colleyRstats.sty", package = "colleyRstats")
  skip_if(!nzchar(path))
  expect_identical(readLines(path), colleyRstats:::.colley_sty_lines())
})

test_that("latex_preamble writes a .sty when the path ends in .sty", {
  f <- file.path(tempdir(), "pre.sty")
  suppressMessages(latex_preamble(f))
  expect_true(any(grepl("\\ProvidesPackage", readLines(f), fixed = TRUE)))
  unlink(f)
})

# ---- name / result macros ------------------------------------------------

test_that("emit_name_macros defines valid names and warns about invalid ones", {
  lines <- suppressMessages(emit_name_macros(c("Video", "DriverPosition")))
  expect_length(lines, 2)
  expect_match(lines[1], "\\\\newcommand\\{\\\\Video\\}")
  expect_warning(emit_name_macros(c("tlx_mental")), "not valid LaTeX")
})

test_that("emit_name_macros maps names to display labels", {
  lines <- suppressMessages(emit_name_macros(c(tlxMental = "TLX Mental Demand")))
  expect_identical(lines, "\\newcommand{\\tlxMental}{TLX Mental Demand}")
})

test_that("define_result_macro sanitises the name and can append to a file", {
  res <- suppressMessages(define_result_macro("tlx_mental_omnibus", "F(2, 57) = 4.50, p = .02"))
  expect_identical(names(res), "tlxMentalOmnibus")
  expect_match(res[[1]], "^\\\\newcommand\\{\\\\tlxMentalOmnibus\\}")

  f <- tempfile(fileext = ".tex")
  suppressMessages(define_result_macro("first_dv", "F = 1", path = f))
  suppressMessages(define_result_macro("second_dv", "F = 2", path = f))
  expect_length(readLines(f), 2) # appended, not overwritten
  unlink(f)
})

# ---- emit_overleaf -------------------------------------------------------

fake_report_all <- function() {
  list(results = list(
    mpg = list(sentences = c("A significant effect of \\Video (\\F{2}{57}{4.50}, \\p{0.012})."), plot = NULL),
    disp = list(sentences = c("No effect on disp\\_raw (\\p{0.4})."), plot = NULL)
  ))
}

test_that("emit_overleaf writes a compilable project (macros mode)", {
  dir <- file.path(tempdir(), "ol-macros")
  unlink(dir, recursive = TRUE)
  out <- suppressMessages(emit_overleaf(fake_report_all(), dir = dir, methods = "effectsize"))

  expect_true(file.exists(out$main))
  expect_true(file.exists(out$results))
  expect_true(file.exists(out$sty)) # macros mode ships the package
  expect_length(out$sections, 2)
  main <- readLines(out$main)
  expect_true(any(grepl("\\documentclass", main, fixed = TRUE)))
  expect_true(any(grepl("\\usepackage{colleyRstats}", main, fixed = TRUE)))
  expect_true(any(grepl("\\input{results}", main, fixed = TRUE)))
  # section files keep the macros in this mode
  expect_true(any(grepl("\\F{", readLines(out$sections[1]), fixed = TRUE)))
  expect_true(file.exists(out$bib))
  # a names.tex with providecommand stubs makes \Video-style macros safe, but
  # never stubs the built-in stat macros (that would clash with the .sty)
  expect_true(file.exists(out$names))
  stubs <- readLines(out$names)
  expect_true(any(grepl("\\providecommand{\\Video}{Video}", stubs, fixed = TRUE)))
  expect_false(any(grepl("providecommand{\\F}", stubs, fixed = TRUE)))
  unlink(dir, recursive = TRUE)
})

test_that("emit_overleaf plain mode expands macros and omits the .sty", {
  dir <- file.path(tempdir(), "ol-plain")
  unlink(dir, recursive = TRUE)
  out <- suppressMessages(emit_overleaf(fake_report_all(), dir = dir, plain = TRUE, methods = NULL))

  expect_null(out$sty)
  main <- readLines(out$main)
  expect_false(any(grepl("usepackage{colleyRstats}", main, fixed = TRUE)))
  sect <- paste(readLines(out$sections[1]), collapse = "\n")
  expect_false(grepl("\\F{", sect, fixed = TRUE)) # expanded
  expect_match(sect, "\\$F\\(2, 57\\) = 4.50\\$")
  unlink(dir, recursive = TRUE)
})

test_that("emit_overleaf accepts a plain named list of sentences", {
  dir <- file.path(tempdir(), "ol-list")
  unlink(dir, recursive = TRUE)
  out <- suppressMessages(emit_overleaf(
    list(workload = "Workload sentence.", trust = "Trust sentence."),
    dir = dir, methods = NULL
  ))
  expect_length(out$sections, 2)
  expect_true(all(file.exists(out$sections)))
  unlink(dir, recursive = TRUE)
})

# ---- booktabs tables -----------------------------------------------------

test_that("reportDunnTestTable style = 'booktabs' uses booktabs rules", {
  skip_if_not_installed("FSA")
  skip_if_not_installed("xtable")
  d <- FSA::dunnTest(Sepal.Length ~ Species, data = iris, method = "holm")

  hline <- utils::capture.output(suppressMessages(
    reportDunnTestTable(d, data = iris, iv = "Species", dv = "Sepal.Length", style = "hline")
  ))
  book <- utils::capture.output(suppressMessages(
    reportDunnTestTable(d, data = iris, iv = "Species", dv = "Sepal.Length", style = "booktabs")
  ))
  expect_true(any(grepl("\\hline", hline, fixed = TRUE)))
  expect_true(any(grepl("\\toprule", book, fixed = TRUE)))
  expect_false(any(grepl("\\hline", book, fixed = TRUE)))
})
