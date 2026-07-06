# cces_cumulative_knowledge

Split-out RStudio project for the CCES cumulative media-use and political-knowledge
pipeline.

Run `01_download-cces-dataverse.R` first on a fresh machine to populate the
yearly common-content files under `data/source/cces/YYYY_cc.dta`. The
MEDIAKNOWL build scripts then run in numeric order. 

# CCES Media Use & Political Knowledge (cumulative, long form)

A small standalone pipeline that pulls the **media use** and **political
knowledge** batteries out of the CCES common content (`data/source/cces/YYYY_cc.dta`,
2006–2025) and stacks them into two harmonized **long-form** datasets.

The hard part is that variable names *and* value-label codings drift across
years. Two traps are handled explicitly:

- **Item ordering shifts.** The media "past 24 hours" battery suffixes are
  reordered starting 2020 (item `_1` is *blog* through 2019 but *social media*
  from 2020). Items are mapped by their variable **label**, not their suffix.
- **Party codes flip.** Party-knowledge questions code Democrats = 1 in
  2006/2007/2009 but Republicans = 1 in 2008 and 2010+. All harmonization is
  done on the value-label **text** (`label_raw → response`), never on the raw
  integer, so `response` is comparable across years. `value_raw` keeps the
  original code for auditing.

## Scripts (run in order)

| script | what it does |
|---|---|
| `00_functions.R` | Shared helpers sourced by the build scripts. |
| `01_download-cces-dataverse.R` | Downloads the CCES common-content files and supporting auxiliary files into `data/source/cces/`. |
| `02_codebook.R` | Reads **metadata only** (0 rows) from all yearly common-content files, classifies the relevant variables into harmonized items, and writes the crosswalk, value-label inventory, response map, and a human-readable codebook. |
| `03_media-use.R` | Builds the cumulative **media-use** long file. |
| `04_political-knowledge.R` | Builds the cumulative **political-knowledge** long file. |
| `05_correct-answers.R` | Adds correct answers and `is_correct` for federal control and officeholder party-recall items where a source key is available. |
| `06_eval-ideo.R` | Appends officeholder **evaluation** and **ideological-placement** engagement items (own Senator 1/2, Governor) for 2020 and 2024 to the scored release file. These items have no correct-answer key, so `is_correct` encodes engagement (substantive response vs. "Not sure"). |

```sh
Rscript 01_download-cces-dataverse.R
Rscript 02_codebook.R
Rscript 03_media-use.R
Rscript 04_political-knowledge.R
Rscript 05_correct-answers.R
Rscript 06_eval-ideo.R
```

## Outputs

Final release datasets are written to `data/release`. Metadata and build
diagnostics are written to `data/output/`.

**Codebook / crosswalk** (from script 02):

- `mediaknowl_codebook.md` — items, year coverage, and every raw → harmonized response mapping
- `mediaknowl_crosswalk.csv` — year × original variable → harmonized item
- `mediaknowl_valuelabels.csv` — full value-label inventory with harmonized responses
- `mediaknowl_response_map.csv` — `(group, label_raw) → response` lookup
- `mediaknowl_coverage.csv` — item-level year coverage

**Long datasets** (`data/output`, `.feather`):

- `mediause_long_2007-2025` — the past-24h media battery
  (blog/TV/newspaper/radio/social/none), TV-news & newspaper type, the network
  battery (ABC/CBS/NBC/CNN/Fox/MSNBC/PBS/Other, 2020+), and the social-media
  activity sub-battery, with `newsint_4pt` attached to every row. ~6.1M rows.
- `knowledge_long_2006-2025_scored` — party **control** (U.S. House, U.S. Senate,
  state senate, state lower chamber) and party **recall** (own Governor, Senator
  1, Senator 2, House member as `recall_house`), with correct answers where available. ~5.5M rows,
  all 20 years, and `newsint_4pt` attached where available.
- `mediause_long_2007-2025_sample.dta` and
  `knowledge_long_2006-2025_scored_sample.dta` — 10,000-row random samples for
  quick inspection.

Both share one row per respondent × year × item, with columns:
`year, case_id, newsint_4pt, item, item_label, response_scheme, var_orig, qtext,
value_raw, label_raw, response`.

**Correctness outputs** (from script 05):

- `knowledge_long_2006-2025_scored.feather` — final political-knowledge dataset,
  adding `correct_response`, `correct_source`, and `is_correct`
- `knowledge_correct_answer_key.csv` — answer-key rows used for scoring
- `knowledge_correct_summary.csv` — item-level scored-row counts and mean
  correctness

**Evaluation / ideology outputs** (from script 06):

- Appends `eval_senator1`, `eval_senator2`, `eval_governor`, `ideo_senator1`,
  `ideo_senator2`, `ideo_governor` for 2020 and 2024 directly into
  `knowledge_long_2006-2025_scored.feather` (same schema; `is_correct` is
  `TRUE` for a substantive response, `FALSE` for "Not sure", `NA` if
  skipped/not asked). The script is idempotent: re-running it drops and
  rebuilds these six items rather than duplicating rows.

## Notes

- Media coverage starts in 2008 after moving `newsint` out of the item rows and
  into the row-level `newsint_4pt` covariate. `newsint_4pt` is available from
  2007 onward and is missing for 2006 knowledge rows. Knowledge coverage spans
  2006–2025.
- 2006 Senate control uses the post-Virginia item (`v4069`); the 2007 file uses
  its native battery rather than the carried-over 2006 panel variables.
- Correctness is computed for U.S. House/Senate control and for party recall
  when a respondent-level current-officeholder party field is available in the
  CCES source files. State-legislature control correctness remains `NA` because
  the CCES common files do not include a state chamber majority-party key.
