# Written by Codex
# Run testthat checks against the placement release file.

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
root <- if (length(file_arg)) {
  normalizePath(file.path(dirname(sub("^--file=", "", file_arg)), ".."), winslash = "/")
} else {
  normalizePath(".", winslash = "/")
}
setwd(root)

source("00_functions.R")

if (!requireNamespace("testthat", quietly = TRUE)) {
  stop(
    "Package 'testthat' is required. Install with install.packages('testthat').",
    call. = FALSE
  )
}

testthat::test_dir("tests/testthat")
