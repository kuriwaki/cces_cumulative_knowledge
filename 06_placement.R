# Written by Codex
# Build the cumulative officeholder evaluation and ideological-placement long file
# (2012, 2016, 2020, 2024). Senator ideology in 2012/2016/2020 uses
# dplyr::replace_when() to coalesce the current-senator item with the matched
# Senate-candidate item (dplyr >= 1.2.0).

source("00_functions.R")
library(arrow)

if (packageVersion("dplyr") < "1.2.0") {
  stop("06_placement.R requires dplyr >= 1.2.0 (replace_when).")
}

# Config ----

out_dir = "data/output"
release_dir = "data/release"

expected_items = c(
  "eval_senator1", "eval_senator2", "eval_governor",
  "ideo_senator1", "ideo_senator2", "ideo_governor"
)

IDEO_COALESCE_YEARS = c(2012L, 2016L, 2020L)
IDEO_COALESCE_ITEMS = c("ideo_senator1", "ideo_senator2")

ideo_coalesce_match_cfg = list(
  `2012` = list(
    match_by   = "party",
    cand_items = c(Democratic = "CC334J", Republican = "CC334K"),
    sen_party  = c(ideo_senator1 = "CurrentSen1Party", ideo_senator2 = "CurrentSen2Party")
  ),
  `2016` = list(
    match_by   = "name",
    cand_items = c("CC16_340l", "CC16_340m"),
    cand_names = c("SenCand1Name", "SenCand2Name"),
    sen_names  = c(ideo_senator1 = "CurrentSen1Name", ideo_senator2 = "CurrentSen2Name")
  ),
  `2020` = list(
    match_by   = "name",
    cand_items = c("CC20_340i", "CC20_340j"),
    cand_names = c("SenCand1Name", "SenCand2Name"),
    sen_names  = c(ideo_senator1 = "CurrentSen1Name", ideo_senator2 = "CurrentSen2Name")
  )
)

# Helpers ----

surname <- function(x) {
  if_else(x == "", NA_character_, str_to_lower(word(x, -1)))
}

coalesce_ideo_slot <- function(source_data,
                               slot_cfg,
                               item,
                               year,
                               current_var,
                               qtext_lookup) {
  not_asked <- is.na(zap_labels(source_data[[current_var]]))
  value_current <- haven_int(source_data[[current_var]])
  label_current <- haven_chr(source_data[[current_var]])

  if (slot_cfg$match_by == "party") {
    party <- str_trim(haven_chr(source_data[[slot_cfg$sen_party[[item]]]]))
    cand_var <- case_when(
      party == "Democratic" ~ slot_cfg$cand_items[["Democratic"]],
      party == "Republican" ~ slot_cfg$cand_items[["Republican"]],
      .default = NA_character_
    )
    value_cand <- case_when(
      party == "Democratic" ~ haven_int(source_data[[slot_cfg$cand_items[["Democratic"]]]]),
      party == "Republican" ~ haven_int(source_data[[slot_cfg$cand_items[["Republican"]]]]),
      .default = NA_integer_
    )
    label_cand <- case_when(
      party == "Democratic" ~ haven_chr(source_data[[slot_cfg$cand_items[["Democratic"]]]]),
      party == "Republican" ~ haven_chr(source_data[[slot_cfg$cand_items[["Republican"]]]]),
      .default = NA_character_
    )
  } else {
    sen_name <- str_trim(as.character(source_data[[slot_cfg$sen_names[[item]]]]))
    cand1 <- str_trim(as.character(source_data[[slot_cfg$cand_names[[1]]]]))
    cand2 <- str_trim(as.character(source_data[[slot_cfg$cand_names[[2]]]]))
    cand1_var <- slot_cfg$cand_items[[1]]
    cand2_var <- slot_cfg$cand_items[[2]]
    value_c1 <- haven_int(source_data[[cand1_var]])
    value_c2 <- haven_int(source_data[[cand2_var]])
    label_c1 <- haven_chr(source_data[[cand1_var]])
    label_c2 <- haven_chr(source_data[[cand2_var]])
    match_c1 <- sen_name != "" & (sen_name == cand1 | surname(sen_name) == surname(cand1))
    match_c2 <- sen_name != "" & (sen_name == cand2 | surname(sen_name) == surname(cand2))

    cand_var <- case_when(
      match_c1 ~ cand1_var,
      match_c2 ~ cand2_var,
      .default = NA_character_
    )
    value_cand <- case_when(
      match_c1 ~ value_c1,
      match_c2 ~ value_c2,
      .default = NA_integer_
    )
    label_cand <- case_when(
      match_c1 ~ label_c1,
      match_c2 ~ label_c2,
      .default = NA_character_
    )
  }

  from_cand <- not_asked & !is.na(cand_var)

  tibble(
    year = year,
    case_id = fmt_case_id(source_data$case_id),
    item = item,
    value_raw = replace_when(value_current, from_cand ~ value_cand),
    label_raw = replace_when(label_current, from_cand ~ label_cand),
    var_orig = if_else(from_cand, cand_var, current_var),
    qtext = if_else(from_cand, unname(qtext_lookup[cand_var]), qtext_lookup[[current_var]])
  ) |>
    filter(!is.na(value_raw) | !is.na(label_raw))
}

build_ideo_coalesce <- function(match_cfg,
                                coalesce_xwalk,
                                item_meta,
                                response_map,
                                src_dir = "data/source/cces") {
  one_year <- function(slot_cfg, yr_chr) {
    survey_year <- as.integer(yr_chr)
    fp <- path(src_dir, glue("{survey_year}_cc.dta"))
    if (!file_exists(fp)) return(NULL)

    yr_xwalk <- filter(coalesce_xwalk, year == survey_year)
    vars <- unique(c(
      yr_xwalk$var_orig,
      unname(slot_cfg$cand_items),
      unname(slot_cfg$cand_names),
      unname(slot_cfg$sen_party),
      unname(slot_cfg$sen_names)
    ))
    source_data <- read_dta(fp, col_select = any_of(c("case_id", vars)))
    qtext_lookup <- var_qtext(source_data)

    map(yr_xwalk$item, function(item) {
      current_var <- yr_xwalk$var_orig[yr_xwalk$item == item]
      coalesce_ideo_slot(
        source_data = source_data,
        slot_cfg = slot_cfg,
        item = item,
        year = survey_year,
        current_var = current_var,
        qtext_lookup = qtext_lookup
      )
    }) |>
      list_rbind()
  }

  imap(match_cfg, one_year) |>
    compact() |>
    list_rbind() |>
    left_join(item_meta, by = "item", relationship = "many-to-one") |>
    left_join(response_map, by = "label_raw", relationship = "many-to-one") |>
    relocate(year, case_id, item, item_label, response_scheme, var_orig, qtext,
             value_raw, label_raw, response)
}

score_awareness <- function(data) {
  data |>
    mutate(
      # "Never heard of person" appears only in the 2012 senator approval items;
      # like "Not sure", it is a non-substantive response (Moskowitz 2021 codes
      # both as lacking awareness)
      is_aware = case_when(
        response %in% c("Not sure", "Never heard of person") ~ FALSE,
        !is.na(response) ~ TRUE,
        TRUE ~ NA
      ),
      correct_response = NA_character_,
      correct_source = NA_character_,
      is_correct = NA
    ) |>
    filter(!is.na(is_aware))
}

# Inputs ----

dir_create(release_dir)
if (any(!file_exists(c(
  path(out_dir, "mediaknowl_crosswalk.csv"),
  path(out_dir, "mediaknowl_response_map.csv")
)))) {
  stop("Missing inputs. Run 02_codebook.R before 06_placement.R.")
}

xwalk <- read_csv(path(out_dir, "mediaknowl_crosswalk.csv"), show_col_types = FALSE)
response_map <- read_csv(
  path(out_dir, "mediaknowl_response_map.csv"),
  show_col_types = FALSE
)
awareness_xwalk <- filter(xwalk, group == "awareness")
awareness_map <- filter(response_map, group == "awareness")

if (!setequal(unique(awareness_xwalk$item), expected_items) ||
    any(count(awareness_xwalk, year, item)$n != 1L)) {
  stop("Unexpected awareness year-item mappings from 02_codebook.R.")
}

awareness_coalesce_xwalk <- awareness_xwalk |>
  filter(year %in% IDEO_COALESCE_YEARS, item %in% IDEO_COALESCE_ITEMS)

awareness_standard_xwalk <- awareness_xwalk |>
  filter(!(year %in% IDEO_COALESCE_YEARS & item %in% IDEO_COALESCE_ITEMS))

# Senator-ideology coalesce ----
# In 2012, 2016, and 2020 the CCES skips the current-senator ideology row when
# that senator is on the ballot; the placement appears under the Senate-candidate
# row instead. Coalesce per respondent: keep the current-senator value when
# asked, otherwise substitute the party- (2012) or name-matched (2016/2020)
# candidate item. 2024 asks current senators of everyone — standard build_long().

item_meta <- distinct(awareness_xwalk, item, item_label, response_scheme)
awareness_map_labels <- select(awareness_map, label_raw, response)

ideo_coalesce_long <- build_ideo_coalesce(
  match_cfg = ideo_coalesce_match_cfg,
  coalesce_xwalk = awareness_coalesce_xwalk,
  item_meta = item_meta,
  response_map = awareness_map_labels
)

# Build ----

newsint_4pt <- build_newsint_4pt(xwalk = xwalk)

placement_long <- bind_rows(
  build_long(
    xwalk = awareness_standard_xwalk,
    response_map = awareness_map
  ),
  ideo_coalesce_long
) |>
  left_join(newsint_4pt, by = c("year", "case_id"), relationship = "many-to-one") |>
  score_awareness() |>
  relocate(newsint_4pt, .after = case_id)

dupes <- placement_long |>
  reframe(n = n(), .by = c(year, case_id, item)) |>
  filter(n > 1)
if (nrow(dupes) > 0) {
  print(dupes)
  stop("Duplicate placement rows after coalesce.")
}

set.seed(20250611)
placement_sample <- sample_mediaknowl_case_ids(
  data = placement_long,
  target_rows = 10000
) |>
  prepare_mediaknowl_dta_sample()

# Save ----

write_feather(placement_long, path(release_dir, "placement_long_2012-2024.feather"))
write_dta(
  placement_sample,
  path(release_dir, "placement_long_2012-2024_sample.dta")
)

cli_alert_success(
  "Wrote placement release file with {nrow(placement_long)} rows to {.path {release_dir}}."
)
placement_long |>
  count(year, item, is_aware) |>
  arrange(year, item, is_aware) |>
  print(n = Inf)
