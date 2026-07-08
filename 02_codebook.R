# Build a crosswalk / codebook for the CCES common-content MEDIA USE,
# POLITICAL KNOWLEDGE, and AWARENESS batteries, 2006-2025.
#
# This script reads ONLY the metadata (variable labels + value labels) of each
# data/source/cces/YYYY_cc.dta file, classifies the relevant variables into a
# harmonized set of items, and writes a machine-readable crosswalk plus a
# value-label inventory and a human-readable codebook. Downstream builders
# 03_media-use.R and 04_political-knowledge.R consume the crosswalk and response
# map.
#
# Key complication handled here: variable names AND value-label codings differ
# across years. For example the media battery item suffixes are reordered after
# 2019 (item 1 = blog through 2019, but = social media from 2020), and the party
# knowledge codes are FLIPPED across years (Democrats = 1 in 2006/2007/2009 but
# Republicans = 1 in 2008 and 2010+). Harmonization is therefore done on the
# value-label TEXT, never on the raw integer code.

library(tidyverse)
library(haven)
library(glue)
library(fs)
library(cli)

# Helpers ----

#' Read variable + value label metadata from a single .dta (0 rows)
read_meta <- function(path) {
  yr <- as.integer(str_extract(path_file(path), "^[0-9]{4}"))
  d <- read_dta(path, n_max = 0)

  varlab <- tibble(
    year = yr,
    var_orig = names(d),
    qtext = map_chr(d, ~ {
      l <- attr(.x, "label")
      if (is.null(l) || length(l) == 0) NA_character_ else as.character(l)[1]
    })
  )

  vallab <- imap(d, function(col, nm) {
    vl <- attr(col, "labels")
    if (is.null(vl) || length(vl) == 0) return(NULL)
    tibble(year = yr, var_orig = nm,
           value = as.integer(unname(vl)),
           label_raw = names(vl))
  }) |>
    compact() |>
    list_rbind()

  lst(varlab, vallab)
}

#' Classify (var_orig, qtext) vectors into harmonized group + item.
#' Returns a tibble(group, item); NA item for variables not in scope.
classify_item <- function(var_orig, qtext) {
  L <- str_squish(str_to_lower(replace_na(qtext, "")))
  N <- str_remove_all(L, "\\s+")               # no-space version, for office matching
  v <- var_orig
  has_idx <- str_detect(v, "_[0-9]+$")          # core/sub-battery items end in _<digit>

  chamber <- case_when(
    str_detect(L, "state senate|upper")            ~ "control_state_senate",
    str_detect(L, "lower")                         ~ "control_state_lower",
    str_detect(L, "house|reps|house maj")          ~ "control_house",
    str_detect(L, "senate|sen maj")                ~ "control_senate",
    TRUE ~ NA_character_
  )
  office <- case_when(
    str_detect(N, "gov")                ~ "recall_governor",
    str_detect(N, "sen1|senator1")      ~ "recall_senator1",
    str_detect(N, "sen2|senator2")      ~ "recall_senator2",
    str_detect(N, "house|rep")          ~ "recall_house",
    TRUE ~ NA_character_
  )
  network <- case_when(
    str_detect(L, "msnbc")        ~ "network_msnbc",
    str_detect(L, "fox")          ~ "network_fox",
    str_detect(L, "cnn")          ~ "network_cnn",
    str_detect(L, "\\babc\\b")    ~ "network_abc",
    str_detect(L, "\\bcbs\\b")    ~ "network_cbs",
    str_detect(L, "\\bnbc\\b")    ~ "network_nbc",
    str_detect(L, "\\bpbs\\b")    ~ "network_pbs",
    str_detect(L, "other")        ~ "network_other",
    TRUE ~ NA_character_
  )
  sm_activity <- case_when(
    str_detect(L, "posted a story") | (str_detect(L, "posted a") & str_detect(L, "story")) ~ "sm_post_story",
    str_detect(L, "posted a comment")     ~ "sm_post_comment",
    str_detect(L, "read a story")         ~ "sm_read_story",
    str_detect(L, "followed a political") ~ "sm_follow_event",
    str_detect(L, "forwarded")            ~ "sm_forward_story",
    str_detect(L, "none")                 ~ "sm_none",
    TRUE ~ NA_character_
  )
  core <- case_when(
    str_detect(L, "blog")             ~ "blog",
    str_detect(L, "social media")     ~ "social",
    str_detect(L, "\\btv\\b|tv news") ~ "tv",
    str_detect(L, "newspaper")        ~ "newspaper",
    str_detect(L, "radio")            ~ "radio",
    str_detect(L, "none")             ~ "none",
    TRUE ~ NA_character_
  )

  is_newsint <- v %in% c("newsint", "V244", "v244")
  is_core    <- str_starts(L, "media use") & has_idx
  is_tvtype  <- str_detect(L, "tv news type|tv news kind|tv type followup|watch news|watch local/natl|watch local news|did you watch local|local news, national")
  is_nptype  <- str_detect(L, "newspaper type|read print news|print news, online|did you read a print|print newspaper, an online")
  is_network <- str_starts(L, "media networks") | str_starts(L, "network watched")
  is_smact   <- str_starts(L, "social media -") | str_starts(L, "recent social media") | str_starts(L, "social media activity")
  is_control <- str_detect(L, "party majority|party of government|party in government|know_party_control|majority party in|controls the house|controls the senate|house maj|sen maj")
  is_recall  <- str_detect(L, "party recall|party of representative|party affiliation -|party of us|party of governor|name recognition|knowledge house rep|knowledge gov|knowledge sen")

  group <- case_when(
    is_newsint | is_core | is_tvtype | is_nptype | is_network | is_smact ~ "media",
    is_control | is_recall ~ "knowledge",
    TRUE ~ NA_character_
  )
  item <- case_when(
    is_newsint ~ "news_interest",
    is_core    ~ core,
    is_tvtype  ~ "tv_type",
    is_nptype  ~ "newspaper_type",
    is_network ~ network,
    is_smact   ~ sm_activity,
    is_control ~ chamber,
    is_recall  ~ office,
    TRUE ~ NA_character_
  )

  tibble(group = group, item = item)
}

# Item-level metadata (labels + harmonization scheme), for the codebook ----
item_meta <- tribble(
  ~item,                  ~item_label,                                        ~response_scheme,
  "news_interest",        "Interest in news / public affairs",                "interest_4pt",
  "blog",                 "Past 24h: read a blog",                            "binary_yesno",
  "tv",                   "Past 24h: watched TV news",                        "binary_yesno",
  "newspaper",            "Past 24h: read a newspaper",                       "binary_yesno",
  "radio",                "Past 24h: listened to radio news",                 "binary_yesno",
  "social",               "Past 24h: used social media",                      "binary_yesno",
  "none",                 "Past 24h: none of these media",                    "binary_yesno",
  "tv_type",              "TV news watched: local / national / both",         "tv_type",
  "newspaper_type",       "Newspaper read: print / online / both",            "newspaper_type",
  "network_abc",          "Network watched 24h: ABC",                         "binary_yesno",
  "network_cbs",          "Network watched 24h: CBS",                         "binary_yesno",
  "network_nbc",          "Network watched 24h: NBC",                         "binary_yesno",
  "network_cnn",          "Network watched 24h: CNN",                         "binary_yesno",
  "network_fox",          "Network watched 24h: Fox News",                    "binary_yesno",
  "network_msnbc",        "Network watched 24h: MSNBC",                       "binary_yesno",
  "network_pbs",          "Network watched 24h: PBS",                         "binary_yesno",
  "network_other",        "Network watched 24h: Other",                       "binary_yesno",
  "sm_post_story",        "Social media 24h: posted a story/photo/link",      "binary_yesno",
  "sm_post_comment",      "Social media 24h: posted a comment",               "binary_yesno",
  "sm_read_story",        "Social media 24h: read a story / watched a video", "binary_yesno",
  "sm_follow_event",      "Social media 24h: followed a political event",     "binary_yesno",
  "sm_forward_story",     "Social media 24h: forwarded a story/photo/link",   "binary_yesno",
  "sm_none",              "Social media 24h: none of these",                  "binary_yesno",
  "control_house",        "Knows party controlling U.S. House",               "party_control",
  "control_senate",       "Knows party controlling U.S. Senate",              "party_control",
  "control_state_senate", "Knows party controlling state senate/upper",       "party_control",
  "control_state_lower",  "Knows party controlling state lower chamber",      "party_control",
  "recall_governor",      "Knows party of own Governor",                      "party_recall",
  "recall_senator1",      "Knows party of own U.S. Senator 1",                "party_recall",
  "recall_senator2",      "Knows party of own U.S. Senator 2",                "party_recall",
  "recall_house",         "Knows party of own U.S. House member",             "party_recall",
  "eval_senator1",        "Offers an approval evaluation of own U.S. Senator 1", "awareness_eval",
  "eval_senator2",        "Offers an approval evaluation of own U.S. Senator 2", "awareness_eval",
  "eval_governor",        "Offers an approval evaluation of own Governor",      "awareness_eval",
  "ideo_senator1",        "Places own U.S. Senator 1 on an ideological scale",  "awareness_ideo",
  "ideo_senator2",        "Places own U.S. Senator 2 on an ideological scale",  "awareness_ideo",
  "ideo_governor",        "Places own Governor on an ideological scale",        "awareness_ideo"
)

awareness_vars <- tribble(
  ~year, ~group,      ~item,            ~var_orig,
  2012L, "awareness", "eval_senator1",  "CC315b",
  2012L, "awareness", "eval_senator2",  "CC315c",
  2012L, "awareness", "eval_governor",  "CC308d",
  2012L, "awareness", "ideo_senator1",  "CC334H",
  2012L, "awareness", "ideo_senator2",  "CC334I",
  2012L, "awareness", "ideo_governor",  "CC334B",
  2016L, "awareness", "eval_senator1",  "CC16_320g",
  2016L, "awareness", "eval_senator2",  "CC16_320h",
  2016L, "awareness", "eval_governor",  "CC16_320d",
  2016L, "awareness", "ideo_senator1",  "CC16_340j",
  2016L, "awareness", "ideo_senator2",  "CC16_340k",
  2016L, "awareness", "ideo_governor",  "CC16_340b",
  2020L, "awareness", "eval_senator1",  "CC20_320g",
  2020L, "awareness", "eval_senator2",  "CC20_320h",
  2020L, "awareness", "eval_governor",  "CC20_320d",
  2020L, "awareness", "ideo_senator1",  "CC20_340g",
  2020L, "awareness", "ideo_senator2",  "CC20_340h",
  2020L, "awareness", "ideo_governor",  "CC20_340b",
  2024L, "awareness", "eval_senator1",  "CC24_312g",
  2024L, "awareness", "eval_senator2",  "CC24_312h",
  2024L, "awareness", "eval_governor",  "CC24_312d",
  2024L, "awareness", "ideo_senator1",  "CC24_330i",
  2024L, "awareness", "ideo_senator2",  "CC24_330j",
  2024L, "awareness", "ideo_governor",  "CC24_330b"
)

# Harmonize a raw value-label string into a canonical response category ----
normalize_response <- function(group, label_raw) {
  lab <- str_squish(str_to_lower(replace_na(label_raw, "")))
  out_know <- case_when(
    lab %in% c("the democrats", "democrats", "democrat", "democratic")        ~ "Democratic",
    lab %in% c("the republicans", "republicans", "republican")                ~ "Republican",
    lab %in% c("independent", "other party/independent", "other party / independent") ~ "Other/Independent",
    lab == "neither"                                                          ~ "Neither",
    lab %in% c("tied", "there will be 50 democrats and 50 republicans")       ~ "Tied",
    str_detect(lab, "never heard")                                           ~ "Never heard of person",
    lab %in% c("not sure", "don't know", "dont know")                        ~ "Not sure",
    TRUE ~ NA_character_
  )
  out_media <- case_when(
    lab %in% c("yes", "selected")        ~ "Yes",
    lab %in% c("no", "not selected")     ~ "No",
    lab == "local newscast"              ~ "Local",
    lab == "national newscast"           ~ "National",
    lab == "both"                        ~ "Both",
    lab == "print"                       ~ "Print",
    lab == "online"                      ~ "Online",
    lab == "most of the time"            ~ "Most of the time",
    lab == "some of the time"            ~ "Some of the time",
    lab == "only now and then"           ~ "Only now and then",
    lab == "hardly at all"               ~ "Hardly at all",
    lab == "don't know"                  ~ "Don't know",
    TRUE ~ NA_character_
  )
  out_awareness <- case_when(
    lab == "strongly approve"          ~ "Strongly approve",
    lab == "somewhat approve"          ~ "Somewhat approve",
    lab == "somewhat disapprove"       ~ "Somewhat disapprove",
    lab == "strongly disapprove"       ~ "Strongly disapprove",
    # 2012 senator approval battery (CC315b/c) uses a 4-pt scale without
    # "Somewhat", plus a "Never Heard" category
    lab == "approve"                   ~ "Approve",
    lab == "disapprove"                ~ "Disapprove",
    str_detect(lab, "never heard")     ~ "Never heard of person",
    lab == "very liberal"              ~ "Very Liberal",
    lab == "liberal"                   ~ "Liberal",
    lab == "somewhat liberal"          ~ "Somewhat Liberal",
    lab == "middle of the road"        ~ "Middle of the Road",
    lab == "somewhat conservative"     ~ "Somewhat Conservative",
    lab == "conservative"              ~ "Conservative",
    lab == "very conservative"         ~ "Very Conservative",
    lab == "not sure"                  ~ "Not sure",
    TRUE ~ NA_character_
  )
  case_when(
    group == "knowledge" ~ out_know,
    group == "media" ~ out_media,
    group == "awareness" ~ out_awareness
  )
}

# Build metadata, crosswalk, value-label inventory ----
files <- dir_ls("data/source/cces", regexp = "[0-9]{4}_cc\\.dta$") |> sort()
if (length(files) == 0) {
  stop("No yearly CCES common-content files found. Run 01_download-cces-dataverse.R first.")
}
cli_alert_info("Reading metadata from {length(files)} files.")
meta <- map(files, read_meta)
varlab_all <- map(meta, "varlab") |> list_rbind()
vallab_all <- map(meta, "vallab") |> list_rbind()

xwalk <- varlab_all |>
  mutate(classify_item(var_orig, qtext)) |>
  filter(!is.na(group), !is.na(item))

awareness_xwalk <- awareness_vars |>
  left_join(varlab_all, by = c("year", "var_orig"), relationship = "many-to-one")
if (any(is.na(awareness_xwalk$qtext))) {
  print(filter(awareness_xwalk, is.na(qtext)))
  stop("Awareness variables missing from source metadata; see above.")
}
xwalk <- bind_rows(xwalk, awareness_xwalk)

# Deduplicate: drop 2006-instrument carryforwards present in the 2007 file, and
# the pre-Virginia (provisional) 2006 Senate-control item (keep post-Virginia).
xwalk <- xwalk |>
  filter(!(year == 2007 & str_starts(var_orig, "CC06_V"))) |>
  filter(!(year == 2006 & var_orig == "v4070"))

# Each (year, item) must map to exactly one variable
dups <- xwalk |> count(year, group, item) |> filter(n > 1)
if (nrow(dups) > 0) {
  print(left_join(dups, xwalk, by = c("year", "group", "item"), relationship = "one-to-many"))
  stop("Ambiguous (year, item) mappings remain; see above.")
}

xwalk <- xwalk |>
  left_join(item_meta, by = "item", relationship = "many-to-one") |>
  arrange(group, item, year) |>
  relocate(year, group, item, item_label, response_scheme, var_orig, qtext)

# Value-label inventory with harmonized responses (the heart of the codebook) ----
vallab_codebook <- xwalk |>
  select(year, group, item, item_label, response_scheme, var_orig) |>
  left_join(vallab_all, by = c("year", "var_orig"), relationship = "many-to-many") |>
  mutate(response = normalize_response(group, label_raw)) |>
  arrange(group, item, year, value)

# Response map consumed by the builders: (group, label_raw) -> response
response_map <- vallab_codebook |>
  distinct(group, label_raw, response) |>
  filter(!is.na(label_raw))

# Coverage summary ----
coverage <- xwalk |>
  group_by(group, item, item_label, response_scheme) |>
  summarize(
    n_years = n_distinct(year),
    years = glue_collapse(sort(unique(year)), sep = ", "),
    .groups = "drop"
  ) |>
  arrange(group, item)

# Human-readable codebook (markdown) ----
md <- c(
  "# CCES Media Use, Political Knowledge & Awareness — Cumulative Codebook (2006-2025)",
  "",
  glue("Built by `02_codebook.R`. Source: `data/source/cces/YYYY_cc.dta`."),
  "",
  "Two long-form cumulative datasets are derived from this crosswalk:",
  "",
  "- `mediause_long` — media-use battery (one row per respondent x year x item)",
  "- `knowledge_long` — political-knowledge battery (party control / party recall)",
  "- awareness items — officeholder evaluation / ideological placement, appended to `knowledge_long`",
  "",
  "## Important harmonization notes",
  "",
  "- **Item ordering shifts.** The media \"past 24 hours\" battery suffixes are",
  "  reordered starting 2020 (e.g. item `_1` is *blog* through 2019 but *social",
  "  media* from 2020). Items here are mapped by their variable LABEL, not suffix.",
  "- **Party codes are flipped across years.** Party-control questions code",
  "  Democrats = 1 in 2006/2007/2009 but Republicans = 1 in 2008 and 2010+.",
  "  All harmonization is done on the value-label TEXT (`label_raw -> response`),",
  "  never on the raw integer, so `response` is comparable across years.",
  "- `value_raw` (original integer) and `label_raw` (original value label) are",
  "  retained in the long files for auditing.",
  "- Awareness items distinguish substantive responses (`is_aware = TRUE`) from",
  "  `Not sure` (`is_aware = FALSE`); they are never coded as correct or incorrect.",
  "",
  "## Items and year coverage",
  "",
  "| group | item | description | scheme | n_years | years |",
  "|---|---|---|---|---|---|"
)
md <- c(md, glue_data(coverage,
  "| {group} | `{item}` | {item_label} | {response_scheme} | {n_years} | {years} |"))
md <- c(md, "",
  "## Harmonized response categories",
  "",
  "| scheme | raw value labels seen -> harmonized response |",
  "|---|---|")
scheme_map <- vallab_codebook |>
  filter(!is.na(response)) |>
  distinct(response_scheme, label_raw, response) |>
  group_by(response_scheme) |>
  summarize(map = glue_collapse(glue("{label_raw} -> {response}") |> unique(), sep = "; "),
            .groups = "drop")
md <- c(md, glue_data(scheme_map, "| {response_scheme} | {map} |"))

# Save ----
out_dir <- "data/output/"
dir_create(out_dir)

write_csv(xwalk,            path(out_dir, "mediaknowl_crosswalk.csv"))
write_csv(vallab_codebook,  path(out_dir, "mediaknowl_valuelabels.csv"))
write_csv(response_map,     path(out_dir, "mediaknowl_response_map.csv"))
write_csv(coverage,         path(out_dir, "mediaknowl_coverage.csv"))
writeLines(md,              path(out_dir, "mediaknowl_codebook.md"))

cli_alert_success("Wrote crosswalk ({nrow(xwalk)} year-vars) and codebook to {.path {out_dir}}.")
print(coverage, n = Inf)
