#' Print a banner at the start of a pipeline script.
#'
#' @param script_name basename of the script (e.g. `"02_codebook.R"`)
script_banner <- function(script_name) {
  cli_rule(left = "{.file {script_name}}")
  invisible(script_name)
}
