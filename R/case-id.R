#' Coerce a case id to 64-bit integer without scientific notation or lost precision.
fmt_case_id <- function(x) {
  x <- zap_labels(x)
  if (is.numeric(x)) {
    bit64::as.integer64(if_else(
      is.na(x),
      NA_character_,
      format(x, scientific = FALSE, trim = TRUE)
    ))
  } else {
    bit64::as.integer64(as.character(x))
  }
}
