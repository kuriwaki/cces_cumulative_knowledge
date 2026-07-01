# Written by Codex
# Shared helpers for the MEDIAKNOWLEDGE pipeline. Sourced by 03, 04, and 05.
# Reads only the columns named in the crosswalk from each YYYY_cc.dta, returns a
# harmonized long-form tibble (one row per respondent x year x item).

library(tidyverse)
library(haven)
library(glue)
library(fs)
library(cli)
library(bit64)

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
    is_correct = "Whether response matches correct response"
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

#' Build respondent-year news-interest covariate.
build_newsint_4pt <- function(xwalk, src_dir = "data/source/cces") {
  news_xwalk <- xwalk |>
    filter(item == "news_interest") |>
    select(year, var_orig)

  one_year <- function(yr) {
    xw <- filter(news_xwalk, year == yr)
    if (nrow(xw) == 0) return(NULL)

    fp <- path(src_dir, glue("{yr}_cc.dta"))
    d <- read_dta(fp, col_select = any_of(c("case_id", xw$var_orig)))
    present <- base::intersect(xw$var_orig, names(d))
    if (length(present) == 0 || !"case_id" %in% names(d)) return(NULL)

    d |>
      transmute(
        year = yr,
        case_id = fmt_case_id(case_id),
        newsint_value = as.integer(zap_labels(.data[[present[1]]]))
      ) |>
      mutate(
        newsint_4pt = case_when(
          newsint_value == 1L ~ "1 - Most",
          newsint_value == 2L ~ "2 - Some",
          newsint_value == 3L ~ "3 - Only",
          newsint_value == 4L ~ "4 - Hardly",
          newsint_value == 7L ~ "7 - Don't know",
          TRUE ~ NA_character_
        )
      ) |>
      select(year, case_id, newsint_4pt)
  }

  map(sort(unique(news_xwalk$year)), one_year) |>
    compact() |>
    list_rbind()
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

#' Build a long-form harmonized dataset for one battery group.
#'
#' @param xwalk crosswalk tibble from 02_codebook.R (already filtered to the
#'   group of interest)
#' @param response_map (group, label_raw) -> response lookup
#' @param src_dir directory holding the YYYY_cc.dta files
#' @return long tibble: year, case_id, item, item_label, response_scheme,
#'   var_orig, qtext, value_raw, label_raw, response
build_long <- function(xwalk, response_map, src_dir = "data/source/cces") {
  years <- sort(unique(xwalk$year))

  one_year <- function(yr) {
    xw  <- filter(xwalk, year == yr)
    fp  <- path(src_dir, glue("{yr}_cc.dta"))
    d   <- read_dta(fp, col_select = any_of(c("case_id", xw$var_orig)))

    present <- base::intersect(xw$var_orig, names(d))
    if (length(present) == 0) {
      cli_alert_warning("{yr}: none of the expected variables found; skipping.")
      return(NULL)
    }
    if (!"case_id" %in% names(d)) stop(glue("{yr}: no case_id column."))

    # original integer codes (preserve, for auditing the cross-year code flips)
    long_num <- d |>
      transmute(case_id = fmt_case_id(case_id),
                across(all_of(present), ~ as.integer(zap_labels(.x)))) |>
      pivot_longer(-case_id, names_to = "var_orig", values_to = "value_raw")

    # original value-label text (the basis for harmonization)
    long_lab <- d |>
      transmute(case_id = fmt_case_id(case_id),
                across(all_of(present), ~ as.character(as_factor(.x)))) |>
      pivot_longer(-case_id, names_to = "var_orig", values_to = "label_raw")

    long_num |>
      left_join(long_lab, by = c("case_id", "var_orig"),
                relationship = "one-to-one") |>
      mutate(year = yr) |>
      filter(!is.na(value_raw) | !is.na(label_raw))
  }

  long <- map(years, one_year) |> compact() |> list_rbind()

  long |>
    left_join(select(xwalk, year, var_orig, group, item, item_label,
                     response_scheme, qtext),
              by = c("year", "var_orig"), relationship = "many-to-one") |>
    left_join(response_map, by = c("group", "label_raw"),
              relationship = "many-to-one") |>
    select(year, case_id, item, item_label, response_scheme,
           var_orig, qtext, value_raw, label_raw, response) |>
    arrange(year, case_id, item)
}
