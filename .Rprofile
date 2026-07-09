options(tidyverse.quiet = TRUE)

# Load shared helpers in RStudio / interactive sessions only.
# Batch scripts (Rscript) load via source("00_functions.R") or their own libraries.
# Auto-loading here breaks dplyr::filter() in scripts like 02_codebook.R that
# attach tidyverse separately (tidyverse 2.x no longer re-masks filter on attach).
if (interactive()) {
  local({
    root <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
    load_r <- file.path(root, "R", "load.R")
    if (file.exists(load_r)) {
      source(load_r, local = FALSE)
    }
  })
}
