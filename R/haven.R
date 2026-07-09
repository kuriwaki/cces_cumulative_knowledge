#' Integer codes from a haven-labelled column (strip labels, preserve NA).
haven_int <- function(x) {
  as.integer(zap_labels(x))
}

#' Value-label text from a haven-labelled column.
haven_chr <- function(x) {
  as.character(as_factor(x))
}

#' Variable-label text keyed by column name from a read_dta() data frame.
var_qtext <- function(source_data) {
  map_chr(source_data, function(col) {
    label <- attr(col, "label")
    if (is.null(label) || length(label) == 0) NA_character_ else as.character(label)[1]
  })
}
