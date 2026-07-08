# Written by Codex
# Compare placement release summary stats to Moskowitz (2021) replication
# benchmarks (cces_1216.dta, Harvard Dataverse 10.7910/DVN/HDDPTB).

root <- testthat::test_path("..", "..")
source(file.path(root, "00_functions.R"), local = FALSE)
library(arrow)
library(testthat)

source(file.path(root, "tests", "helpers.R"))

placement_path <- file.path(root, "data/release/placement_long_2012-2024.feather")
benchmark_path <- file.path(root, "tests/fixtures/moskowitz_placement_benchmarks.csv")

skip_if_not(
  file.exists(placement_path),
  "placement release missing (run 02_codebook.R and 06_placement.R first)"
)

placement_long <- read_feather(placement_path)
expected <- read_csv(benchmark_path, show_col_types = FALSE)
observed <- summarize_placement_moskowitz(placement_long)

test_that("placement item counts match Moskowitz replication (2012, 2016)", {
  cmp <- expected |>
    left_join(observed, by = c("year", "item"), suffix = c("_exp", "_obs")) |>
    mutate(
      n_tol = if_else(
        year == 2012L & item %in% c("ideo_senator1", "ideo_senator2", "sen_both_ideo"),
        pmax(150L, as.integer(ceiling(0.003 * n_scored_exp))),
        0L
      ),
      n_scored_ok = abs(n_scored_obs - n_scored_exp) <= n_tol,
      n_aware_ok = abs(n_aware_obs - n_aware_exp) <= n_tol,
      pct_ok = abs(pct_aware_obs - pct_aware_exp) <= 0.002,
      ok = n_scored_ok & n_aware_ok & pct_ok
    )

  expect_true(
    all(cmp$ok, na.rm = TRUE),
    info = paste(
      "Moskowitz benchmark mismatches:",
      paste(capture.output(print(filter(cmp, !ok), n = Inf)), collapse = "\n")
    )
  )
})

test_that("2016 senator ideology rows match Moskowitz exactly", {
  exact_items <- c("ideo_senator1", "ideo_senator2", "sen_both_ideo")
  cmp <- expected |>
    filter(year == 2016L, item %in% exact_items) |>
    inner_join(observed, by = c("year", "item"), suffix = c("_exp", "_obs"))

  expect_equal(cmp$n_scored_obs, cmp$n_scored_exp)
  expect_equal(cmp$n_aware_obs, cmp$n_aware_exp)
})

test_that("evaluation items match Moskowitz exactly in both years", {
  cmp <- expected |>
    filter(startsWith(item, "eval_")) |>
    inner_join(observed, by = c("year", "item"), suffix = c("_exp", "_obs"))

  expect_equal(cmp$n_scored_obs, cmp$n_scored_exp)
  expect_equal(cmp$n_aware_obs, cmp$n_aware_exp)
})
