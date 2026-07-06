# Written by Claude Code and Codex
# Append officeholder evaluation and ideological-placement awareness items for
# 2020 and 2024 to the scored political-knowledge release file.

source("00_functions.R")
library(arrow)

# Inputs ----

out_dir <- "data/output"
release_dir <- "data/release"
scored_path <- path(release_dir, "knowledge_long_2006-2025_scored.feather")
required_inputs <- c(
  scored_path,
  path(out_dir, "mediaknowl_crosswalk.csv"),
  path(out_dir, "mediaknowl_response_map.csv")
)
if (any(!file_exists(required_inputs))) {
  stop("Missing inputs. Run 02_codebook.R and 05_correct-answers.R before 06_eval-ideo.R.")
}

xwalk <- read_csv(path(out_dir, "mediaknowl_crosswalk.csv"), show_col_types = FALSE)
response_map <- read_csv(
  path(out_dir, "mediaknowl_response_map.csv"),
  show_col_types = FALSE
)
awareness_xwalk <- filter(xwalk, group == "awareness")
awareness_map <- filter(response_map, group == "awareness")
awareness_items <- unique(awareness_xwalk$item)

if (nrow(awareness_xwalk) != 12L ||
    any(count(awareness_xwalk, year, item)$n != 1L)) {
  stop("Expected exactly 12 unique awareness year-item mappings from 02_codebook.R.")
}

# Build ----

newsint_4pt <- build_newsint_4pt(xwalk)
awareness_long <- build_long(awareness_xwalk, awareness_map) |>
  left_join(newsint_4pt, by = c("year", "case_id"), relationship = "many-to-one") |>
  mutate(
    is_aware = case_when(
      response == "Not sure" ~ FALSE,
      !is.na(response) ~ TRUE,
      TRUE ~ NA
    ),
    correct_response = NA_character_,
    correct_source = NA_character_,
    is_correct = NA
  ) |>
  filter(!is.na(is_aware)) |>
  relocate(newsint_4pt, .after = case_id)

scored <- read_feather(scored_path) |>
  filter(!item %in% awareness_items) |>
  mutate(is_aware = NA)

scored_extended <- bind_rows(scored, awareness_long)

# Save ----

write_feather(scored_extended, scored_path)

cli_alert_success(
  "Appended {nrow(awareness_long)} awareness rows (2020 and 2024) to {.file {scored_path}}."
)
awareness_long |>
  count(year, item, is_aware) |>
  arrange(year, item, is_aware) |>
  print(n = Inf)
