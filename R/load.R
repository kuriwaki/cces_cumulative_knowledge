# Load shared pipeline helpers once per R session.
# Sourced from .Rprofile (interactive) and 00_functions.R (Rscript fallback).

.cces_load_helpers <- function(root = getwd()) {
  if (isTRUE(getOption("cces_cumulative_knowledge.loaded", FALSE))) {
    return(invisible(NULL))
  }

  r_dir <- file.path(root, "R")
  if (!dir.exists(r_dir)) {
    stop(
      "Cannot find R/ under {.path {root}}. ",
      "Set the working directory to the project root.",
      call. = FALSE
    )
  }

  helper_files <- c(
    "load-packages.R",
    "case-id.R",
    "haven.R",
    "sample-export.R",
    "build-long.R"
  )

  invisible(lapply(
    helper_files,
    function(f) source(file.path(r_dir, f), local = FALSE)
  ))

  options(cces_cumulative_knowledge.loaded = TRUE)
  invisible(NULL)
}

.cces_load_helpers()
