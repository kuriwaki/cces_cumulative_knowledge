# Written by Codex
# Build the cumulative long-form POLITICAL KNOWLEDGE dataset (2006-2025) from the
# CCES common content. Two sub-batteries:
#   * party CONTROL of legislatures  (U.S. House, U.S. Senate, state senate /
#     upper chamber, state lower chamber)
#   * party RECALL of the respondent's own officeholders (Governor, U.S. Senator
#     1, U.S. Senator 2, U.S. House member)
# See 02_codebook.R for the crosswalk and harmonization. Critically, the raw
# party codes FLIP across years (Democrats = 1 in 2006/2007/2009 but
# Republicans = 1 in 2008 and 2010+), so `response` is harmonized on the
# value-label text. `value_raw` keeps the original code for auditing.

source("00_functions.R")
library(arrow)

# Inputs ----
out_dir      <- "data/output"
dir_create(out_dir)
required_inputs <- path(out_dir, c("mediaknowl_crosswalk.csv", "mediaknowl_response_map.csv"))
if (any(!file_exists(required_inputs))) {
  stop("Missing codebook outputs. Run 02_codebook.R before 04_political-knowledge.R.")
}
xwalk        <- read_csv(path(out_dir, "mediaknowl_crosswalk.csv"), show_col_types = FALSE)
response_map <- read_csv(path(out_dir, "mediaknowl_response_map.csv"), show_col_types = FALSE)

know_xwalk <- filter(xwalk, group == "knowledge")
know_map   <- filter(response_map, group == "knowledge")

# Build ----
cli_alert_info("Building political-knowledge long file over {n_distinct(know_xwalk$year)} years.")
knowledge_long <- build_long(know_xwalk, know_map)
newsint_4pt <- build_newsint_4pt(xwalk)

knowledge_long <- knowledge_long |>
  left_join(newsint_4pt, by = c("year", "case_id"), relationship = "many-to-one") |>
  relocate(newsint_4pt, .after = case_id)

# Report ----
cli_alert_success("knowledge long: {nrow(knowledge_long)} rows, {n_distinct(knowledge_long$case_id)} respondents.")
cli_h2("Rows per item")
knowledge_long |> count(item, item_label) |> arrange(item) |> print(n = Inf)

# Sanity check the party-code flip is correctly harmonized: in years where the
# raw code 1 means Democrats (2006/2007/2009) vs Republicans (2008/2010+), the
# harmonized `response` should agree with the label regardless of `value_raw`.
cli_h2("Harmonization check: value_raw 1 should map to BOTH parties across years")
knowledge_long |>
  filter(item == "control_house", value_raw == 1, !is.na(response)) |>
  count(year, response) |>
  pivot_wider(names_from = response, values_from = n) |>
  print(n = Inf)

# Save ----
write_feather(knowledge_long, path(out_dir, "knowledge_long_2006-2025.feather"))

cli_alert_success("Wrote political-knowledge long file to {.path {out_dir}}.")
