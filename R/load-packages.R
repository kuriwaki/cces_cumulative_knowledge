suppressPackageStartupMessages({
  library(tidyverse)
  library(haven)
  library(glue)
  library(fs)
  library(cli)
  library(arrow)
})

# fmt_case_id() uses bit64::as.integer64() without attaching the package.
# Attaching bit64 breaks dplyr::filter() (stats::filter wins after attach).
