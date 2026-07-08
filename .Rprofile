options(tidyverse.quiet = TRUE)

# Load shared helpers when the project opens (RStudio) or Rscript runs from root.
# Use .Rprofile for R code; .Renviron is for environment variables (e.g. DATAVERSE_SERVER).
local({
  root <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  load_r <- file.path(root, "R", "load.R")
  if (file.exists(load_r)) {
    source(load_r, local = FALSE)
  }
})
