# Helpers for comparing placement release stats to Moskowitz (2021) replication
# benchmarks. Values in tests/fixtures/moskowitz_placement_benchmarks.csv were
# computed from cces_1216.dta (Harvard Dataverse 10.7910/DVN/HDDPTB).

#' Summarize placement long rows in Moskowitz-compatible terms.
#'
#' @param placement_long output of script 06_placement.R
#' @param years survey years to summarize (default 2012 and 2016)
#' @return tibble with columns year, item, n_scored, n_aware, pct_aware
summarize_placement_moskowitz <- function(placement_long, years = c(2012L, 2016L)) {
  item_rows <- placement_long |>
    filter(year %in% years, item %in% c(
      "eval_senator1", "eval_senator2", "eval_governor",
      "ideo_senator1", "ideo_senator2", "ideo_governor"
    )) |>
    summarize(
      year = first(year),
      n_scored = n(),
      n_aware = sum(is_aware),
      pct_aware = mean(is_aware),
      .by = c(year, item)
    )

  both_rows <- placement_long |>
    filter(
      year %in% years,
      item %in% c("ideo_senator1", "ideo_senator2")
    ) |>
    select(year, case_id, item, is_aware) |>
    pivot_wider(names_from = item, values_from = is_aware) |>
    filter(!is.na(ideo_senator1), !is.na(ideo_senator2)) |>
    mutate(both_aware = ideo_senator1 & ideo_senator2) |>
    summarize(
      year = first(year),
      item = "sen_both_ideo",
      n_scored = n(),
      n_aware = sum(both_aware),
      pct_aware = mean(both_aware),
      .by = year
    )

  bind_rows(item_rows, both_rows) |>
    arrange(year, item)
}
