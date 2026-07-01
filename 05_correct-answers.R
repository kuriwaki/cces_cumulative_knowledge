# Written by Codex
# Add correct-answer metadata to the cumulative political-knowledge long file.
# Federal chamber control is keyed by survey year. Officeholder recall is keyed
# to respondent-specific current-officeholder party fields in the CCES source
# files. State legislative control is left missing because the source CCES files
# do not include a state chamber majority-party key.

library(tidyverse)
library(haven)
library(glue)
library(fs)
library(cli)
library(arrow)
library(bit64)

source("00_functions.R")

# Helpers ----

normalize_party <- function(x) {
  lab <- str_squish(str_to_lower(replace_na(as.character(x), "")))

  case_when(
    lab == "" ~ NA_character_,
    lab %in% c("democrat", "democratic", "democratic-farmer-labor") ~ "Democratic",
    lab %in% c("republican", "republicans") ~ "Republican",
    lab %in% c("independent", "other", "other party", "other party/independent",
               "other party / independent") ~ "Other/Independent",
    TRUE ~ NA_character_
  )
}

read_recall_key <- function(year, vars, src_dir = "data/source/cces") {
  fp <- path(src_dir, glue("{year}_cc.dta"))
  needed <- c("case_id", unname(vars))
  present <- intersect(needed, names(read_dta(fp, n_max = 0)))

  if (!"case_id" %in% present || length(setdiff(present, "case_id")) == 0) {
    return(tibble())
  }

  d <- read_dta(fp, col_select = all_of(present)) |>
    transmute(case_id = fmt_case_id(case_id),
              across(-case_id, ~ normalize_party(as_factor(.x)))) |>
    pivot_longer(-case_id, names_to = "var_correct", values_to = "correct_response")

  tibble(item = names(vars), var_correct = unname(vars)) |>
    inner_join(d, by = "var_correct", relationship = "one-to-many") |>
    mutate(
      year = year,
      correct_source = glue("{year}_cc.dta:{var_correct}")
    ) |>
    select(year, case_id, item, correct_response, correct_source)
}

# Inputs ----

out_dir <- "data/output"
release_dir <- "data/release"
dir_create(out_dir)
dir_create(release_dir)
required_input <- path(out_dir, "knowledge_long_2006-2025.feather")
if (!file_exists(required_input)) {
  stop("Missing political-knowledge long file. Run 04_political-knowledge.R before 05_correct-answers.R.")
}
knowledge_long <- read_feather(path(out_dir, "knowledge_long_2006-2025.feather"))

recall_var_map <- list(
  `2006` = c(
    recall_governor = "v5020",
    recall_house = "v5014",
    recall_senator2 = "v5018"
  ),
  `2007` = c(
    recall_governor = "CC06_V5020",
    recall_house = "CC06_V5014",
    recall_senator1 = "CC06_V5016",
    recall_senator2 = "CC06_V5018"
  ),
  `2008` = c(
    recall_governor = "V513",
    recall_house = "V535",
    recall_senator1 = "V544",
    recall_senator2 = "V548"
  ),
  `2009` = c(),
  `2010` = c(
    recall_governor = "V530",
    recall_house = "V502",
    recall_senator1 = "V514",
    recall_senator2 = "V522"
  ),
  `2011` = c(),
  `2012` = c(
    recall_governor = "CurrentGovParty",
    recall_house = "CurrentHouseParty",
    recall_senator1 = "CurrentSen1Party",
    recall_senator2 = "CurrentSen2Party"
  ),
  `2013` = c(
    recall_governor = "CurrentGovParty",
    recall_house = "CurrentHouseParty",
    recall_senator1 = "CurrentSen1Party",
    recall_senator2 = "CurrentSen2Party"
  ),
  `2014` = c(
    recall_governor = "CurrentGovParty",
    recall_house = "CurrentHouseParty",
    recall_senator1 = "CurrentSen1Party",
    recall_senator2 = "CurrentSen2Party"
  ),
  `2015` = c(
    recall_governor = "CurrentGovParty",
    recall_house = "CurrentHouseParty",
    recall_senator1 = "CurrentSen1Party",
    recall_senator2 = "CurrentSen2Party"
  ),
  `2016` = c(
    recall_governor = "CurrentGovParty",
    recall_house = "CurrentHouseParty",
    recall_senator1 = "CurrentSen1Party",
    recall_senator2 = "CurrentSen2Party"
  ),
  `2017` = c(
    recall_governor = "CurrentGovParty",
    recall_house = "CurrentHouseParty",
    recall_senator1 = "CurrentSen1Party",
    recall_senator2 = "CurrentSen2Party"
  ),
  `2018` = c(
    recall_governor = "CurrentGovParty",
    recall_house = "CurrentHouseParty",
    recall_senator1 = "CurrentSen1Party",
    recall_senator2 = "CurrentSen2Party"
  ),
  `2019` = c(
    recall_governor = "CurrentGovParty",
    recall_house = "CurrentHouseParty",
    recall_senator1 = "CurrentSen1Party",
    recall_senator2 = "CurrentSen2Party"
  ),
  `2020` = c(
    recall_governor = "CurrentGovParty",
    recall_house = "CurrentHouseParty",
    recall_senator1 = "CurrentSen1Party",
    recall_senator2 = "CurrentSen2Party"
  ),
  `2021` = c(
    recall_governor = "CurrentGovParty",
    recall_house = "CurrentHouseParty",
    recall_senator1 = "CurrentSen1Party",
    recall_senator2 = "CurrentSen2Party"
  ),
  `2022` = c(
    recall_governor = "CurrentGovParty",
    recall_house = "CurrentHouseParty",
    recall_senator1 = "CurrentSen1Party",
    recall_senator2 = "CurrentSen2Party"
  ),
  `2023` = c(
    recall_governor = "CurrentGovParty",
    recall_house = "CurrentHouseParty",
    recall_senator1 = "CurrentSen1Party",
    recall_senator2 = "CurrentSen2Party"
  ),
  `2024` = c(
    recall_governor = "CurrentGovParty",
    recall_house = "CurrentHouseParty",
    recall_senator1 = "CurrentSen1Party",
    recall_senator2 = "CurrentSen2Party"
  ),
  `2025` = c(
    recall_governor = "CurrentGovParty",
    recall_house = "CurrentHouseParty",
    recall_senator1 = "CurrentSen1Party",
    recall_senator2 = "CurrentSen2Party"
  )
)

federal_control_key <- tribble(
  ~year, ~control_house, ~control_senate,
  2006L, "Democratic",  "Democratic",
  2007L, "Democratic",  "Democratic",
  2008L, "Democratic",  "Democratic",
  2009L, "Democratic",  "Democratic",
  2010L, "Democratic",  "Democratic",
  2011L, "Republican",  "Democratic",
  2012L, "Republican",  "Democratic",
  2013L, "Republican",  "Democratic",
  2014L, "Republican",  "Democratic",
  2015L, "Republican",  "Republican",
  2016L, "Republican",  "Republican",
  2017L, "Republican",  "Republican",
  2018L, "Republican",  "Republican",
  2019L, "Democratic",  "Republican",
  2020L, "Democratic",  "Republican",
  2021L, "Democratic",  "Democratic",
  2022L, "Democratic",  "Democratic",
  2023L, "Republican",  "Democratic",
  2024L, "Republican",  "Democratic",
  2025L, "Republican",  "Republican"
) |>
  pivot_longer(-year, names_to = "item", values_to = "correct_response") |>
  mutate(
    case_id = bit64::as.integer64(NA),
    correct_source = "year-level congressional control key"
  )

# Build ----

cli_alert_info("Building respondent-level recall answer key.")
recall_key <- imap(recall_var_map, ~ read_recall_key(as.integer(.y), .x)) |>
  list_rbind() |>
  filter(!is.na(correct_response))

answer_key <- bind_rows(federal_control_key, recall_key) |>
  filter(!is.na(correct_response)) |>
  distinct(year, case_id, item, correct_response, correct_source)

knowledge_scored <- knowledge_long |>
  left_join(answer_key,
            by = c("year", "case_id", "item"),
            relationship = "many-to-one") |>
  left_join(federal_control_key |> select(year, item, correct_response_control = correct_response,
                                          correct_source_control = correct_source),
            by = c("year", "item"),
            relationship = "many-to-one") |>
  mutate(
    correct_response = coalesce(correct_response, correct_response_control),
    correct_source = coalesce(correct_source, correct_source_control),
    is_correct = case_when(
      is.na(response) | is.na(correct_response) ~ NA,
      response == correct_response ~ TRUE,
      TRUE ~ FALSE
    )
  ) |>
  select(-correct_response_control, -correct_source_control)

summary_by_item <- knowledge_scored |>
  group_by(item, item_label) |>
  summarize(
    rows = n(),
    rows_with_correct_answer = sum(!is.na(correct_response)),
    rows_scored = sum(!is.na(is_correct)),
    pct_correct = if_else(rows_scored > 0, mean(is_correct, na.rm = TRUE), NA_real_),
    .groups = "drop"
  ) |>
  arrange(item)

# Save ----
set.seed(20250611)
knowledge_scored_sample <- knowledge_scored |>
  sample_mediaknowl_case_ids(target_rows = 10000) |>
  prepare_mediaknowl_dta_sample()

write_csv(answer_key, path(out_dir, "knowledge_correct_answer_key.csv"))
write_csv(summary_by_item, path(out_dir, "knowledge_correct_summary.csv"))
write_feather(knowledge_scored, path(release_dir, "knowledge_long_2006-2025_scored.feather"))
write_dta(knowledge_scored_sample,
          path(release_dir, "knowledge_long_2006-2025_scored_sample.dta"))
if (file_exists(path(out_dir, "knowledge_long_2006-2025.feather"))) {
  file_delete(path(out_dir, "knowledge_long_2006-2025.feather"))
}

cli_alert_success("Wrote scored political-knowledge release files to {.path {release_dir}}.")
print(summary_by_item, n = Inf)
