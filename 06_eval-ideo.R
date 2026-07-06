# Written by Claude Code
# Append officeholder EVALUATION and IDEOLOGICAL-PLACEMENT engagement items for
# 2020 and 2024 to the scored political-knowledge long file. These items have no
# correct-answer key, so is_correct encodes engagement: a substantive response
# scores TRUE, "Not sure" scores FALSE (matching the "don't know counts"
# convention in 05_correct-answers.R), and skipped / not asked is NA. Every
# existing row is left untouched. Run after 05_correct-answers.R.
#
# Source items (own Senator 1, Senator 2, Governor):
#   2020 eval CC20_320g/h/d, ideo CC20_340g/h/b  (CES20 common content)
#   2024 eval CC24_312h/i/e, ideo CC24_330i/j/b  (CES24 common content)

source("00_functions.R")
library(arrow)

# Setup -------------------------------------------------------------------

src_dir     <- "data/source/cces"
release_dir <- "data/release"
scored_path <- path(release_dir, "knowledge_long_2006-2025_scored.feather")

ITEM_LABELS <- c(
  eval_senator1 = "Offers an approval evaluation of own U.S. Senator 1",
  eval_senator2 = "Offers an approval evaluation of own U.S. Senator 2",
  eval_governor = "Offers an approval evaluation of own Governor",
  ideo_senator1 = "Places own U.S. Senator 1 on an ideological scale",
  ideo_senator2 = "Places own U.S. Senator 2 on an ideological scale",
  ideo_governor = "Places own Governor on an ideological scale"
)

# Engagement coding: substantive response = TRUE, "Not sure" = FALSE, else NA
code_eval <- \(x) {
  v <- zap_labels(x)
  case_when(v %in% 1:4 ~ TRUE, v == 5 ~ FALSE, .default = NA)
}
code_ideo <- \(x) {
  v <- zap_labels(x)
  case_when(v %in% 1:7 ~ TRUE, v == 8 ~ FALSE, .default = NA)
}

# Function: read one year's eval/ideo items --------------------------------

read_eval_ideo <- function(yr, eval_vars, ideo_vars) {
  fp <- path(src_dir, glue("{yr}_cc.dta"))
  if (!file_exists(fp)) {
    cli_abort("Missing {.file {fp}}. Run 01_download-cces-dataverse.R for {yr}.")
  }
  read_dta(fp, col_select = all_of(c("case_id", eval_vars, ideo_vars))) |>
    transmute(
      case_id = fmt_case_id(case_id),
      year    = as.numeric(yr),
      eval_senator1 = code_eval(.data[[eval_vars[1]]]),
      eval_senator2 = code_eval(.data[[eval_vars[2]]]),
      eval_governor = code_eval(.data[[eval_vars[3]]]),
      ideo_senator1 = code_ideo(.data[[ideo_vars[1]]]),
      ideo_senator2 = code_ideo(.data[[ideo_vars[2]]]),
      ideo_governor = code_ideo(.data[[ideo_vars[3]]])
    )
}

# Build eval/ideo long rows ------------------------------------------------

new_wide <- bind_rows(
  read_eval_ideo(2020,
                 c("CC20_320g", "CC20_320h", "CC20_320d"),
                 c("CC20_340g", "CC20_340h", "CC20_340b")),
  read_eval_ideo(2024,
                 c("CC24_312h", "CC24_312i", "CC24_312e"),
                 c("CC24_330i", "CC24_330j", "CC24_330b"))
)

new_long <- new_wide |>
  pivot_longer(
    cols      = !c(case_id, year),
    names_to  = "item",
    values_to = "is_correct"
  ) |>
  filter(!is.na(is_correct)) |>
  transmute(
    year,
    case_id,
    item,
    item_label = unname(ITEM_LABELS[item]),
    is_correct
  )

# Append to the scored release file (standard output) ----------------------

# Idempotent: drop any prior eval/ideo rows so re-running does not duplicate.
scored <- read_feather(scored_path) |>
  filter(!item %in% names(ITEM_LABELS))

scored_extended <- bind_rows(scored, new_long)

write_feather(scored_extended, scored_path)

cli_alert_success(
  "Appended {nrow(new_long)} eval/ideo rows (2020+2024) to {.file {scored_path}}."
)
new_long |> count(year, item) |> arrange(year, item) |> print(n = Inf)
