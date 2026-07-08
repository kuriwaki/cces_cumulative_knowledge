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
        newsint_value = haven_int(.data[[present[1]]])
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

    long_num <- d |>
      transmute(
        case_id = fmt_case_id(case_id),
        across(all_of(present), ~ haven_int(.x))
      ) |>
      pivot_longer(-case_id, names_to = "var_orig", values_to = "value_raw")

    long_lab <- d |>
      transmute(
        case_id = fmt_case_id(case_id),
        across(all_of(present), ~ haven_chr(.x))
      ) |>
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
