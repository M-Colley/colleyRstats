r_files <- list.files("R", pattern = "\\.R$", full.names = TRUE)
for (file in r_files) {
  sys.source(file, envir = globalenv())
}
