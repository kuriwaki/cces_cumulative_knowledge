# Written by Codex
# Add officeholder evaluation and ideological-placement awareness items for
# 2012, 2016, 2020, and 2024 to the scored political-knowledge release file.

source("00_functions.R")
library(arrow)

# Inputs ----

out_dir <- "data/output"
if (any(!file_exists(c(
  path(out_dir, "knowledge_long_2006-2025_scored_base.feather"),
  path(out_dir, "mediaknowl_crosswalk.csv"),
  path(out_dir, "mediaknowl_response_map.csv")
)))) {
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

if (nrow(awareness_xwalk) != 24L ||
    any(count(awareness_xwalk, year, item)$n != 1L)) {
  stop("Expected exactly 24 unique awareness year-item mappings from 02_codebook.R.")
}

# Senator-ideology candidate fallback ----
# In 2012, 2016, and 2020 the CCES does not ask the current-senator ideology
# item about a senator who is on the ballot; that senator's placement appears
# only under the Senate-candidate ideology item. Recover those placements by
# matching the candidate to the senator — by party in 2012 (candidate items are
# labeled Dem/Rep), by sample-frame name in 2016/2020. In 2024 the
# current-senator items are asked of everyone, so no fallback is needed.
# Moskowitz (2021) applies the same recovery in his replication data.

ideo_fallback_cfg <- list(
  `2012` = list(
    current    = c(ideo_senator1 = "CC334H", ideo_senator2 = "CC334I"),
    match_by   = "party",
    cand_items = c(Democratic = "CC334J", Republican = "CC334K"),
    sen_party  = c(ideo_senator1 = "CurrentSen1Party", ideo_senator2 = "CurrentSen2Party")
  ),
  `2016` = list(
    current    = c(ideo_senator1 = "CC16_340j", ideo_senator2 = "CC16_340k"),
    match_by   = "name",
    cand_items = c("CC16_340l", "CC16_340m"),
    cand_names = c("SenCand1Name", "SenCand2Name"),
    sen_names  = c(ideo_senator1 = "CurrentSen1Name", ideo_senator2 = "CurrentSen2Name")
  ),
  `2020` = list(
    current    = c(ideo_senator1 = "CC20_340g", ideo_senator2 = "CC20_340h"),
    match_by   = "name",
    cand_items = c("CC20_340i", "CC20_340j"),
    cand_names = c("SenCand1Name", "SenCand2Name"),
    sen_names  = c(ideo_senator1 = "CurrentSen1Name", ideo_senator2 = "CurrentSen2Name")
  )
)

build_ideo_fallback <- function(cfg_all, item_meta_xwalk, src_dir = "data/source/cces") {
  one_year <- function(cfg, yr_chr) {
    yr <- as.integer(yr_chr)
    fp <- path(src_dir, glue("{yr}_cc.dta"))
    if (!file_exists(fp)) return(NULL)

    vars <- unique(c(
      unname(cfg$current), unname(cfg$cand_items),
      unname(cfg$cand_names), unname(cfg$sen_party), unname(cfg$sen_names)
    ))
    d <- read_dta(fp, col_select = any_of(c("case_id", vars)))
    qtext_of <- map_chr(d, ~ {
      l <- attr(.x, "label")
      if (is.null(l) || length(l) == 0) NA_character_ else as.character(l)[1]
    })

    map(names(cfg$current), function(it) {
      # respondents whose current-senator item was not asked
      need <- is.na(zap_labels(d[[cfg$current[[it]]]]))

      # source candidate item for this senator, per respondent
      if (cfg$match_by == "party") {
        party <- str_trim(as.character(as_factor(d[[cfg$sen_party[[it]]]])))
        src_var <- unname(cfg$cand_items[party])
      } else {
        # exact full-name match, falling back to surname match (the sample
        # frame sometimes uses different first-name forms, e.g. "Chuck" vs
        # "Charles" Grassley, in the senator vs candidate fields)
        surname <- function(x) if_else(x == "", NA_character_,
                                       str_to_lower(word(x, -1)))
        sen_name <- str_trim(as.character(d[[cfg$sen_names[[it]]]]))
        cand1 <- str_trim(as.character(d[[cfg$cand_names[[1]]]]))
        cand2 <- str_trim(as.character(d[[cfg$cand_names[[2]]]]))
        src_var <- case_when(
          sen_name != "" & sen_name == cand1 ~ cfg$cand_items[[1]],
          sen_name != "" & sen_name == cand2 ~ cfg$cand_items[[2]],
          !is.na(surname(sen_name)) & surname(sen_name) == surname(cand1) ~ cfg$cand_items[[1]],
          !is.na(surname(sen_name)) & surname(sen_name) == surname(cand2) ~ cfg$cand_items[[2]],
          .default = NA_character_
        )
      }

      map(unique(na.omit(src_var)), function(cv) {
        idx <- which(need & !is.na(src_var) & src_var == cv)
        if (length(idx) == 0) return(NULL)
        tibble(
          year = yr,
          case_id = fmt_case_id(d$case_id)[idx],
          item = it,
          var_orig = cv,
          qtext = qtext_of[[cv]],
          value_raw = as.integer(zap_labels(d[[cv]]))[idx],
          label_raw = as.character(as_factor(d[[cv]]))[idx]
        ) |>
          filter(!is.na(value_raw) | !is.na(label_raw))
      }) |>
        list_rbind()
    }) |>
      list_rbind()
  }

  imap(cfg_all, one_year) |>
    compact() |>
    list_rbind() |>
    left_join(item_meta_xwalk, by = "item", relationship = "many-to-one") |>
    relocate(year, case_id, item, item_label, response_scheme, var_orig, qtext)
}

ideo_fallback_long <- build_ideo_fallback(
  ideo_fallback_cfg,
  distinct(awareness_xwalk, item, item_label, response_scheme)
) |>
  left_join(select(awareness_map, label_raw, response), by = "label_raw",
            relationship = "many-to-one")

# Build ----

newsint_4pt <- build_newsint_4pt(xwalk)
awareness_long <- build_long(awareness_xwalk, awareness_map) |>
  bind_rows(ideo_fallback_long) |>
  left_join(newsint_4pt, by = c("year", "case_id"), relationship = "many-to-one") |>
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
  filter(!is.na(is_aware)) |>
  relocate(newsint_4pt, .after = case_id)

scored <- read_feather(path(out_dir, "knowledge_long_2006-2025_scored_base.feather")) |>
  filter(!item %in% awareness_items) |>
  mutate(is_aware = NA)

scored_extended <- bind_rows(scored, awareness_long)

set.seed(20250611)
scored_extended_sample <- scored_extended |>
  sample_mediaknowl_case_ids(target_rows = 10000) |>
  prepare_mediaknowl_dta_sample()

# Save ----

dir_create("data/release")
write_feather(scored_extended, path("data/release", "knowledge_long_2006-2025_scored.feather"))
write_dta(scored_extended_sample,
          path("data/release", "knowledge_long_2006-2025_scored_sample.dta"))

cli_alert_success(
  "Wrote final scored political-knowledge release file with {nrow(awareness_long)} awareness rows."
)
awareness_long |>
  count(year, item, is_aware) |>
  arrange(year, item, is_aware) |>
  print(n = Inf)
