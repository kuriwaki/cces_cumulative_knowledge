# Written by Codex
# Build the cumulative long-form MEDIA USE dataset (2007-2025) from the CCES
# common content. Items: news interest, the "past 24 hours" media battery
# (blog / TV / newspaper / radio / social media / none), TV-news and newspaper
# type, the cable/broadcast network battery (ABC/CBS/NBC/CNN/Fox/MSNBC/PBS/Other),
# and the recent-social-media-activity sub-battery. See 02_codebook.R for the
# crosswalk and harmonization rules (responses are mapped on value-label text,
# not raw codes, because item ordering and codings shift across years).

source("00_functions.R")
library(arrow)

# Config ----

out_dir = "data/output"
release_dir = "data/release"

# Inputs ----

dir_create(out_dir)
dir_create(release_dir)
required_inputs <- path(out_dir, c("mediaknowl_crosswalk.csv", "mediaknowl_response_map.csv"))
if (any(!file_exists(required_inputs))) {
  stop("Missing codebook outputs. Run 02_codebook.R before 03_media-use.R.")
}

xwalk <- read_csv(path(out_dir, "mediaknowl_crosswalk.csv"), show_col_types = FALSE)
response_map <- read_csv(path(out_dir, "mediaknowl_response_map.csv"), show_col_types = FALSE)

media_xwalk <- filter(xwalk, group == "media", item != "news_interest")
media_map <- filter(response_map, group == "media")

# Build ----

cli_alert_info("Building media-use long file over {n_distinct(media_xwalk$year)} years.")
mediause_long <- build_long(
  xwalk = media_xwalk,
  response_map = media_map
)
newsint_4pt <- build_newsint_4pt(xwalk = xwalk)

mediause_long <- mediause_long |>
  left_join(newsint_4pt, by = c("year", "case_id"), relationship = "many-to-one") |>
  relocate(newsint_4pt, .after = case_id)

# Report ----

cli_alert_success("media-use long: {nrow(mediause_long)} rows, {n_distinct(mediause_long$case_id)} respondents.")
cli_h2("Rows per item")
mediause_long |> count(item, item_label) |> arrange(item) |> print(n = Inf)

# Save ----

set.seed(20250611)
mediause_sample <- sample_mediaknowl_case_ids(
  data = mediause_long,
  target_rows = 10000
) |>
  prepare_mediaknowl_dta_sample()

write_feather(mediause_long, path(release_dir, "mediause_long_2007-2025.feather"))
write_dta(mediause_sample, path(release_dir, "mediause_long_2007-2025_sample.dta"))

cli_alert_success("Wrote media-use release files to {.path {release_dir}}.")
