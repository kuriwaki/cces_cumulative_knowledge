# Backward-compatible entry point for build scripts (03-06).
# Helpers also load via .Rprofile; this covers Rscript --vanilla runs.

if (!isTRUE(getOption("cces_cumulative_knowledge.loaded", FALSE))) {
  source("R/load.R", local = FALSE)
}
