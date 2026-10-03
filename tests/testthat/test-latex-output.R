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
  expect_identical(colleyRstats:::.tex_name("Video"), "\\Video{}")
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

test_that(".latex_cmd_name spells out digits so numbered labels stay distinct", {
  # Dropping the digits mapped tlx_1/tlx_2 (and Q1/Q2) onto one command.
  cmd <- colleyRstats:::.latex_cmd_name
  expect_identical(cmd(c("tlx_1", "tlx_2")), c("tlxOne", "tlxTwo"))
  expect_identical(cmd(c("Q1", "Q2")), c("QOne", "QTwo"))
  expect_identical(cmd("tlx_mental (T1)"), "tlxMentalTOne")
  expect_identical(cmd("1st_dv"), "oneStDv")
  expect_identical(cmd(c("", NA)), c("result", "result"))
  expect_true(all(grepl("^[A-Za-z]+$", cmd(c("Zufriedenheit_ä", "tést 2")))))
})

test_that("emit_name_macros skips names that are already LaTeX commands", {
  # \newcommand{\time} stops the build ("Command \time already defined"); \L
  # is the letter Ł and \small a font-size switch.
  expect_warning(
    lines <- suppressMessages(emit_name_macros(c("Video", "time", "L", "small"))),
    "already LaTeX commands"
  )
  expect_identical(lines, "\\newcommand{\\Video}{Video}")
  expect_warning(suppressMessages(emit_name_macros("endpoint")), "already LaTeX commands")
  # the package's own macros are no exception
  expect_warning(suppressMessages(emit_name_macros("p")), "already LaTeX commands")
})

test_that("emit_name_macros names elements individually and drops duplicates", {
  lines <- suppressMessages(emit_name_macros(c(tlxMental = "TLX Mental Demand", "Video")))
  expect_identical(lines, c("\\newcommand{\\tlxMental}{TLX Mental Demand}", "\\newcommand{\\Video}{Video}"))

  # a level shared by two factors must not produce a second \newcommand
  lines2 <- suppressMessages(emit_name_macros(c("Video", "Audio", "Video")))
  expect_identical(lines2, c("\\newcommand{\\Video}{Video}", "\\newcommand{\\Audio}{Audio}"))
  expect_warning(
    suppressMessages(emit_name_macros(c(Video = "Video A", Video = "Video B"))),
    "different labels"
  )
})

test_that("define_result_macro refuses names that would redefine a command", {
  # "p" is the package's own \p; "time" a TeX primitive
  expect_error(suppressMessages(define_result_macro("p", "x")), "resultP")
  expect_error(suppressMessages(define_result_macro("time", "x")), "already a LaTeX")
  expect_error(suppressMessages(define_result_macro("endpoint", "x")), "resultEndpoint")
})

test_that("define_result_macro keeps tlx_1 and tlx_2 apart and replaces re-definitions", {
  f <- tempfile(fileext = ".tex")
  on.exit(unlink(f), add = TRUE)
  suppressMessages(define_result_macro("tlx_1", "F = 1", path = f))
  suppressMessages(define_result_macro("tlx_2", "F = 2", path = f))
  lines <- readLines(f)
  expect_length(lines, 2)
  expect_match(lines[1], "^\\\\newcommand\\{\\\\tlxOne\\}\\{F = 1\\}")
  expect_match(lines[2], "^\\\\newcommand\\{\\\\tlxTwo\\}\\{F = 2\\}")

  # re-running the analysis updates the definition in place: a second
  # \newcommand{\tlxOne} would stop the build
  suppressMessages(define_result_macro("tlx_1", "F = 1.5", path = f))
  lines <- readLines(f)
  expect_length(lines, 2)
  expect_match(lines[1], "{F = 1.5}", fixed = TRUE)
  expect_identical(sum(grepl("\\newcommand{\\tlxOne}", lines, fixed = TRUE)), 1L)

  # a different label that maps onto the same command is reported
  expect_warning(
    suppressMessages(define_result_macro("tlx1", "F = 9", path = f)),
    "held the result for 'tlx_1'"
  )

  # several strings and line breaks still give a single-line definition
  res <- suppressMessages(define_result_macro("multi", c("A.", "B.\nC.")))
  expect_identical(unname(res), "\\newcommand{\\multi}{A. B. C.}% multi")
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

test_that("emit_overleaf gives every section its own file, even Q1 and Q2", {
  # The regression this guards: file names came from the command-name
  # sanitiser, which drops digits, so Q1 and Q2 were both written to Q.tex --
  # an "already exists" error, or with overwrite = TRUE, Q1 silently lost and
  # Q2 \input twice.
  dir <- file.path(tempdir(), "ol-collide")
  unlink(dir, recursive = TRUE)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  x <- list(Q1 = "First.", Q2 = "Second.", tlx_1 = "Third.", tlx_2 = "Fourth.",
            mpg = "Fifth.", MPG = "Sixth.", `mpg (log)` = "Seventh.")
  out <- suppressMessages(emit_overleaf(x, dir = dir, methods = NULL))

  expect_identical(
    basename(out$sections),
    c("Q1.tex", "Q2.tex", "tlx-1.tex", "tlx-2.tex", "mpg.tex", "MPG-2.tex", "mpg-log.tex")
  )
  expect_identical(
    vapply(out$sections, function(f) readLines(f), character(1), USE.NAMES = FALSE),
    unname(unlist(x))
  )
  res <- readLines(out$results)
  inputs <- grep("^\\\\input\\{sections/", res, value = TRUE)
  expect_length(unique(inputs), length(x))
  # the keys are typeset escaped
  expect_true("\\subsection*{tlx\\_1}" %in% res)

  # overwrite = TRUE rewrites the same set, it does not merge sections
  out2 <- suppressMessages(emit_overleaf(x, dir = dir, methods = NULL, overwrite = TRUE))
  expect_identical(readLines(out2$sections[1]), "First.")
})

test_that("emit_overleaf refuses to overwrite before writing anything", {
  dir <- file.path(tempdir(), "ol-guard")
  unlink(dir, recursive = TRUE)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  dir.create(dir)
  writeLines("% mine", file.path(dir, "main.tex"))
  expect_error(
    suppressMessages(emit_overleaf(list(a = "A."), dir = dir, methods = NULL)),
    "already exists"
  )
  # previously colleyRstats.sty and the sections were written before the
  # refusal, leaving a half-written project
  expect_false(file.exists(file.path(dir, "colleyRstats.sty")))
  expect_false(file.exists(file.path(dir, "sections", "a.tex")))
  expect_identical(readLines(file.path(dir, "main.tex")), "% mine")
})

test_that("emit_overleaf cites every bibliography entry", {
  skip_if_not_installed("ggstatsplot")
  skip_if_not_installed("effectsize")
  dir <- file.path(tempdir(), "ol-bib")
  unlink(dir, recursive = TRUE)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  out <- suppressMessages(emit_overleaf(list(a = "A."), dir = dir))

  main <- readLines(out$main)
  # without a \cite or \nocite BibTeX writes an empty bibliography
  expect_true("\\nocite{*}" %in% main)
  expect_lt(which(main == "\\nocite{*}"), which(main == "\\bibliography{references}"))
  keys <- sub("^@[A-Za-z]+\\{([^,]*),$", "\\1", grep("^@", readLines(out$bib), value = TRUE))
  expect_true(all(nzchar(keys)))
  expect_false(anyDuplicated(keys) > 0)
})

test_that("emit_overleaf stubs only the author's name macros", {
  dir <- file.path(tempdir(), "ol-stubs")
  unlink(dir, recursive = TRUE)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  txt <- c(
    "Effect of \\Video on \\time (\\mdn{3.00}, \\iqr{1.00}, \\textit{x}, $\\chi^2$).",
    "\\endgame and \\DriverPosition."
  )
  out <- suppressMessages(emit_overleaf(list(a = txt), dir = dir, methods = NULL))
  stubs <- readLines(out$names)[-1]
  expect_setequal(stubs, c("\\providecommand{\\Video}{Video}",
                           "\\providecommand{\\DriverPosition}{DriverPosition}"))

  # TeX swallows the space after a control word ("Videoon"); the name macro
  # gets an empty group, and nothing else is touched
  sect <- paste(readLines(out$sections[1]), collapse = "\n")
  expect_match(sect, "\\Video{} on \\time (", fixed = TRUE)
  expect_match(sect, "\\DriverPosition.", fixed = TRUE)
})

test_that("emit_overleaf plain mode needs no colleyRstats definitions", {
  dir <- file.path(tempdir(), "ol-plain-left")
  unlink(dir, recursive = TRUE)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  txt <- "Median (\\mdn{3.00}, \\iqr{1.50}); a nested \\m{\\textit{x}}."
  out <- suppressMessages(emit_overleaf(list(a = txt), dir = dir, plain = TRUE, methods = NULL))

  sect <- readLines(out$sections[1])
  expect_match(sect, "$Mdn = 3.00$, $IQR = 1.50$", fixed = TRUE)
  # what expand_latex_macros() cannot rewrite is defined in names.tex instead
  expect_true(any(grepl("\\providecommand{\\m}{", readLines(out$names), fixed = TRUE)))
  expect_false(any(grepl("\\providecommand{\\mdn}", readLines(out$names), fixed = TRUE)))
})

test_that("emit_overleaf writes figures under safe names and labels them", {
  dir <- file.path(tempdir(), "ol-fig")
  unlink(dir, recursive = TRUE)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
  x <- list(`tlx_mental (T1)` = list(sentences = "A.", plot = p))
  out <- suppressMessages(emit_overleaf(x, dir = dir, methods = NULL))

  expect_identical(basename(out$figures), "tlx-mental-T1.pdf")
  res <- readLines(out$results)
  # included at its natural size: save_paper_figure() chose the type size for it
  expect_true("\\includegraphics{figures/tlx-mental-T1}" %in% res)
  expect_true("\\caption{tlx\\_mental (T1)}" %in% res)
  expect_true("\\label{fig:tlx-mental-T1}" %in% res)
})

# Run pdflatex (and BibTeX) in `dir`; returns the exit codes and the final log.
compile_project <- function(dir) {
  old <- setwd(dir)
  on.exit(setwd(old), add = TRUE)
  run <- function(cmd, args) {
    out <- suppressWarnings(system2(cmd, args, stdout = TRUE, stderr = TRUE))
    status <- attr(out, "status")
    list(out = out, status = if (is.null(status)) 0L else status)
  }
  latex <- c("-interaction=nonstopmode", "-halt-on-error", "main.tex")
  first <- run("pdflatex", latex)
  bib <- if (file.exists("references.bib")) run("bibtex", "main") else NULL
  run("pdflatex", latex)
  last <- run("pdflatex", latex)
  list(
    first = first$status, bib = bib, last = last$status,
    log = readLines("main.log", warn = FALSE),
    bbl = if (file.exists("main.bbl")) readLines("main.bbl", warn = FALSE) else character(0),
    text = if (nzchar(Sys.which("pdftotext")) && file.exists("main.pdf")) {
      paste(suppressWarnings(system2("pdftotext", c("main.pdf", "-"), stdout = TRUE)), collapse = " ")
    }
  )
}

test_that("emit_overleaf projects compile with pdflatex and BibTeX, in both modes", {
  skip_on_cran()
  skip_if(!nzchar(Sys.which("pdflatex")) || !nzchar(Sys.which("bibtex")), "pdflatex/bibtex not available")
  # a minimal TeX installation (e.g. TinyTeX on CI) may lack the packages
  # main.tex loads; that is not what this test is about
  needed <- c("graphicx.sty", "booktabs.sty", "geometry.sty", "plain.bst")
  found <- if (nzchar(Sys.which("kpsewhich"))) {
    suppressWarnings(system2("kpsewhich", needed, stdout = TRUE, stderr = FALSE))
  } else {
    character(0)
  }
  skip_if(length(found) < length(needed), "TeX packages for main.tex not installed")
  skip_if_not_installed("ggstatsplot")
  skip_if_not_installed("effectsize")

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
  x <- list(
    tlx_1 = list(sentences = "An effect of \\Video on tlx\\_1 (\\F{2}{57}{4.50}, \\p{0.012}, \\mdn{3.00}, \\iqr{1.00}).", plot = p),
    tlx_2 = "No effect (\\p{0.40}, \\chisq(2)=1.20).",
    time = "Time (\\m{6.14}, \\sd{0.97}).",
    Q1 = "First item.", Q2 = "Second item."
  )
  for (plain in c(FALSE, TRUE)) {
    dir <- file.path(tempdir(), paste0("ol-compile-", plain))
    unlink(dir, recursive = TRUE)
    out <- suppressMessages(emit_overleaf(x, dir = dir, plain = plain))
    res <- compile_project(dir)

    expect_identical(res$first, 0L, label = paste("first pdflatex run, plain =", plain))
    expect_identical(res$last, 0L, label = paste("last pdflatex run, plain =", plain))
    expect_false(any(grepl("^!", res$log)), label = paste("no TeX errors, plain =", plain))
    expect_false(any(grepl("undefined", res$log, ignore.case = TRUE)))
    expect_identical(res$bib$status, 0L, label = paste("bibtex, plain =", plain))
    # both cited packages made it into the bibliography
    expect_identical(sum(grepl("^\\\\bibitem", res$bbl)), 2L)
    expect_true(file.exists(file.path(dir, "main.pdf")))
    if (!is.null(res$text)) {
      expect_match(res$text, "Video on", fixed = TRUE)
      expect_match(res$text, "Second item.", fixed = TRUE)
    }
    unlink(dir, recursive = TRUE)
  }
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
