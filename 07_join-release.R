# Written by Codex
# Stack the separate media, knowledge, and placement release files into one
# long-form mediaknowl dataset. Each row is still respondent x year x item;
# run after 03, 05, and 06_placement.R.

source("00_functions.R")
script_banner("07_join-release.R")
library(arrow)

# Config ----

release_dir = "data/release"

release_files = list(
  media = path(release_dir, "mediause_long_2007-2025.feather"),
  knowledge = path(release_dir, "knowledge_long_2006-2025_scored.feather"),
  placement = path(release_dir, "placement_long_2012-2024.feather")
)

out_feather = path(release_dir, "mediaknowl_long_2006-2025.feather")
out_sample = path(release_dir, "mediaknowl_long_2006-2025_sample.dta")

# Helpers ----

align_release_columns <- function(data, battery) {
  if (!"is_aware" %in% names(data)) data$is_aware <- NA
  if (!"correct_response" %in% names(data)) data$correct_response <- NA_character_
  if (!"correct_source" %in% names(data)) data$correct_source <- NA_character_
  if (!"is_correct" %in% names(data)) data$is_correct <- NA

  data |> mutate(battery = battery)
}

# Inputs ----

dir_create(release_dir)
missing <- release_files[!map_lgl(release_files, file_exists)]
if (length(missing) > 0) {
  stop(
    "Missing release files: ",
    paste(names(missing), collapse = ", "),
    ". Run 03, 05, and 06_placement.R first.",
    call. = FALSE
  )
}

# Build ----

mediaknowl_long <- bind_rows(
  align_release_columns(read_feather(release_files$media), battery = "media"),
  align_release_columns(read_feather(release_files$knowledge), battery = "knowledge"),
  align_release_columns(read_feather(release_files$placement), battery = "placement")
) |>
  arrange(year, case_id, battery, item)

dupes <- mediaknowl_long |>
  reframe(n = n(), .by = c(year, case_id, item)) |>
  filter(n > 1)
if (nrow(dupes) > 0) {
  print(dupes)
  stop("Duplicate rows after stacking release files.")
}

# Save ----

set.seed(20250611)
mediaknowl_sample <- sample_mediaknowl_case_ids(
  data = mediaknowl_long,
  target_rows = 10000
) |>
  prepare_mediaknowl_dta_sample()

write_feather(mediaknowl_long, out_feather)
write_dta(mediaknowl_sample, out_sample)

cli_alert_success(
  "Wrote stacked mediaknowl release ({nrow(mediaknowl_long)} rows) to {.path {release_dir}}."
)
