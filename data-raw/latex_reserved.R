# Builds `.latex_reserved_names` in R/sysdata.rda: the all-letter LaTeX command
# names that a variable name must never be turned into.
#
# Why: .tex_name() renders an all-letter variable name as a macro (`Video` ->
# `\Video`) so authors can set its typography with one \newcommand. A name that
# is already a command -- `time` (a TeX primitive), `value`, `width`, `L` (the
# letter Ł), `small` -- then either fails to compile or silently prints
# something else, and the \providecommand stubs emit_overleaf() writes cannot
# help because they only define commands that do not exist yet. The list is
# taken from TeX itself rather than typed by hand, so it covers the primitives,
# the LaTeX kernel and the packages a typical HCI manuscript loads.
#
# Requires a TeX installation with lualatex. Run from the package root:
#   Rscript data-raw/latex_reserved.R

stopifnot(file.exists("DESCRIPTION"))
lualatex <- Sys.which("lualatex")
if (!nzchar(lualatex)) stop("lualatex not found on PATH")

work <- tempfile("latex-reserved-")
dir.create(work)
file.copy("data-raw/latex_reserved.lua", work)
template <- readLines("data-raw/latex_reserved.tex")

dump_class <- function(class, options = "", drop = character()) {
  doc <- gsub("CLASSNAME", class, template, fixed = TRUE)
  doc <- gsub("CLASSOPTS", options, doc, fixed = TRUE)
  for (pkg in drop) doc <- gsub(paste0("\\maybeuse{", pkg, "}"), "", doc, fixed = TRUE)
  tex <- file.path(work, paste0(class, ".tex"))
  writeLines(doc, tex)
  old <- setwd(work)
  on.exit(setwd(old))
  status <- system2(lualatex, c("-interaction=nonstopmode", "-halt-on-error", basename(tex)),
                    stdout = FALSE, stderr = FALSE)
  out <- file.path(work, paste0("reserved-", class, ".txt"))
  if (!file.exists(out)) {
    message("Could not dump class '", class, "' (lualatex status ", status, "); skipped.")
    return(character())
  }
  log <- readLines(file.path(work, paste0(class, ".log")), warn = FALSE)
  missing <- sub("^MISSING-PACKAGE ", "", grep("^MISSING-PACKAGE ", log, value = TRUE))
  if (length(missing)) message(class, ": packages not installed, not covered: ", toString(missing))
  readLines(out)
}

dumped <- c(
  dump_class("article"),
  dump_class("IEEEtran", "conference"),
  # acmart loads natbib and amsthm itself
  dump_class("acmart", "sigconf", drop = c("natbib", "amsthm"))
)

# acmart (the CHI / ACM class) needs packages a minimal TeX Live may lack, in
# which case the dump above is empty. Its user-level commands (\keywords,
# \institution, \country, \position, ...) are the ones that collide with real
# variable names, so read them straight from the class file as a fallback.
acmart <- Sys.which("kpsewhich")
acmart <- if (nzchar(acmart)) system2(acmart, "acmart.cls", stdout = TRUE) else character()
static <- character()
if (length(acmart) && file.exists(acmart[1])) {
  cls <- readLines(acmart[1], warn = FALSE)
  pat <- "\\\\(?:newcommand|renewcommand|providecommand|DeclareRobustCommand|def|gdef|let)\\*?\\{?\\\\([A-Za-z]+)"
  hits <- regmatches(cls, gregexpr(pat, cls, perl = TRUE))
  static <- unique(sub(pat, "\\1", unlist(hits), perl = TRUE))
}

# The colleyRstats macros themselves: a variable called `sd` or `m` must not
# shadow \sd / \m.
own <- c("F", "p", "pminor", "padj", "padjminor", "m", "sd", "df", "chisq",
         "rankbiserial", "effectsize", "mdn", "iqr")

.latex_reserved_names <- sort(unique(c(dumped, static, own, "relax")))
message(length(.latex_reserved_names), " reserved names")

# Keep any other internal data already in sysdata.rda.
env <- new.env()
if (file.exists("R/sysdata.rda")) load("R/sysdata.rda", envir = env)
assign(".latex_reserved_names", .latex_reserved_names, envir = env)
save(list = ls(env, all.names = TRUE), envir = env, file = "R/sysdata.rda",
     compress = "xz", version = 2)
