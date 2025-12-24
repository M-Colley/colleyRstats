package_root <- normalizePath(file.path("..", ".."), mustWork = TRUE)
r_files <- list.files(file.path(package_root, "R"), pattern = "\\.R$", full.names = TRUE)
for (file in r_files) {
  sys.source(file, envir = globalenv())
}
