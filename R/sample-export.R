#' Attach variable labels for Stata sample exports.
label_mediaknowl_vars <- function(data) {
  var_labels <- c(
    year = "CCES survey year",
    case_id = "Respondent case identifier",
    item = "Harmonized item identifier",
    item_label = "Human-readable item label",
    response_scheme = "Harmonized response scheme",
    var_orig = "Original CCES source variable",
    qtext = "Original CCES question text or variable label",
    newsint_4pt = "News interest: 1 Most, 2 Some, 3 Only, 4 Hardly, 7 DK",
    value_raw = "Original numeric response code",
    label_raw = "Original value-label text",
    response = "Harmonized respondent response",
    correct_response = "Correct harmonized response",
    correct_source = "Source used for correct response",
    is_correct = "Whether response matches correct response",
    is_aware = "Whether respondent offers a substantive awareness response"
  )

  for (nm in base::intersect(names(var_labels), names(data))) {
    attr(data[[nm]], "label") <- unname(var_labels[[nm]])
  }

  data
}

#' Prepare sampled data for Stata export.
prepare_mediaknowl_dta_sample <- function(data) {
  data <- data |>
    mutate(case_id = as.double(case_id)) |>
    label_mediaknowl_vars()

  attr(data$case_id, "format.stata") <- "%12.0f"

  data
}

#' Sample whole respondents while keeping the sampled long file near target_rows.
sample_mediaknowl_case_ids <- function(data, target_rows = 10000) {
  sampled_ids <- data |>
    count(case_id, name = "n_rows") |>
    slice_sample(prop = 1) |>
    mutate(
      sample_order = row_number(),
      cumulative_rows = cumsum(n_rows)
    )

  under <- sampled_ids |> filter(cumulative_rows <= target_rows) |> slice_tail(n = 1)
  over <- sampled_ids |> filter(cumulative_rows > target_rows) |> slice_head(n = 1)

  cutoff_order <- if (nrow(under) == 0) {
    over$sample_order
  } else if (nrow(over) == 0) {
    under$sample_order
  } else if (abs(under$cumulative_rows - target_rows) <=
             abs(over$cumulative_rows - target_rows)) {
    under$sample_order
  } else {
    over$sample_order
  }

  selected_ids <- sampled_ids |>
    filter(sample_order <= cutoff_order) |>
    select(case_id)

  data |>
    semi_join(selected_ids, by = "case_id")
}
