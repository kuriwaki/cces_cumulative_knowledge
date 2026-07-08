# cces_cumulative_knowledge

Split-out RStudio project for the CCES cumulative media-use and political-knowledge
pipeline.

Run `01_download-cces-dataverse.R` first on a fresh machine to populate the
yearly common-content files under `data/source/cces/YYYY_cc.dta`. The
MEDIAKNOWL build scripts then run in numeric order. 

# CCES Media Use & Political Knowledge (cumulative, long form)

A small standalone pipeline that pulls the **media use** and **political
knowledge** batteries out of the CCES common content (`data/source/cces/YYYY_cc.dta`,
2006–2025) and stacks them into harmonized **long-form** datasets. A separate
**placement** release covers officeholder evaluation and ideological placement
(2012, 2016, 2020, 2024).

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
| `00_functions.R` | Sources `R/load.R` — shared helpers for build scripts 03–07. Also loaded automatically via `.Rprofile`. |
| `01_download-cces-dataverse.R` | Downloads the CCES common-content files and supporting auxiliary files into `data/source/cces/`. |
| `02_codebook.R` | Reads **metadata only** (0 rows) from all yearly common-content files, defines the media-use, political-knowledge, and awareness variable mappings, and writes the crosswalk, value-label inventory, response map, and a human-readable codebook. |
| `03_media-use.R` | Builds the cumulative **media-use** long file and writes the media release to `data/release`. |
| `04_political-knowledge.R` | Builds the cumulative **political-knowledge** long file (intermediate, `data/output`). |
| `05_correct-answers.R` | Adds correct answers and `is_correct` for federal control and officeholder party-recall items where a source key is available, and writes the scored **knowledge** release to `data/release`. |
| `06_placement.R` | Builds the **placement** long file (officeholder evaluation and ideological placement) for 2012, 2016, 2020, and 2024 and writes the placement release to `data/release`. `is_aware` distinguishes substantive responses from "Not sure" / "Never heard of person". Senator ideology in 2012/2016/2020 is coalesced per respondent from the current-senator item and, when that row was skipped, the matching Senate-candidate item (requires dplyr ≥ 1.2.0). |
| `07_join-release.R` | Stacks the media, knowledge, and placement release files into `mediaknowl_long_2006-2025.feather` for users who want one combined long file. |

```sh
Rscript 01_download-cces-dataverse.R
Rscript 02_codebook.R
Rscript 03_media-use.R
Rscript 04_political-knowledge.R
Rscript 05_correct-answers.R
Rscript 06_placement.R
Rscript 07_join-release.R
```

Scripts 03, 05, and 06 each write a distinct release dataset. Run 07 to stack
them into one long file, or join on `(year, case_id)` when you need subsets.

## Outputs

Final release datasets are written to `data/release`. Metadata and build
diagnostics are written to `data/output/`.

**Codebook / crosswalk** (from script 02):

- `mediaknowl_codebook.md` — items, year coverage, and every raw → harmonized response mapping
- `mediaknowl_crosswalk.csv` — year × original variable → harmonized item
- `mediaknowl_valuelabels.csv` — full value-label inventory with harmonized responses
- `mediaknowl_response_map.csv` — `(group, label_raw) → response` lookup
- `mediaknowl_coverage.csv` — item-level year coverage

**Release datasets** (`data/release`):

- `mediause_long_2007-2025.feather` — past-24h media battery (blog/TV/newspaper/radio/social/none),
  TV-news and newspaper type, network battery (ABC/CBS/NBC/CNN/Fox/MSNBC/PBS/Other, 2020+),
  and social-media activity sub-battery, with `newsint_4pt` on every row.
- `knowledge_long_2006-2025_scored.feather` — party **control** (U.S. House, U.S. Senate,
  state senate, state lower chamber) and party **recall** (own Governor, Senators 1/2,
  House member), with `correct_response`, `correct_source`, and `is_correct` where available.
- `placement_long_2012-2024.feather` — officeholder **evaluation** and **ideological
  placement** (`eval_senator1`, `eval_senator2`, `eval_governor`, `ideo_senator1`,
  `ideo_senator2`, `ideo_governor`) for 2012, 2016, 2020, and 2024, with `is_aware`
  scoring. Senator ideology rows coalesce from the Senate-candidate item when the
  current-senator row was skipped (2012/2016/2020).
- `*_sample.dta` — 10,000-row respondent samples for each release file.
- `mediaknowl_long_2006-2025.feather` — optional stacked file from script 07
  (media + knowledge + placement, with a `battery` column).

Media, knowledge, and placement share one row per respondent × year × item, with columns:
`year, case_id, newsint_4pt, item, item_label, response_scheme, var_orig, qtext,
value_raw, label_raw, response`, plus battery-specific scoring columns where applicable.

**Build diagnostics** (from script 05, in `data/output/`):

- `knowledge_correct_answer_key.csv` — answer-key rows used for scoring
- `knowledge_correct_summary.csv` — item-level scored-row counts and mean correctness

**Intermediate build file** (from script 04, in `data/output/`):

- `knowledge_long_2006-2025.feather` — unscored political-knowledge long file (removed after script 05 runs)

## Tests

After building the placement release (`06_placement.R`), compare summary
statistics to the Moskowitz (2021) replication benchmarks:

```sh
Rscript tests/run-tests.R
```

Benchmarks are hardcoded in `tests/fixtures/moskowitz_placement_benchmarks.csv`
(from `cces_1216.dta`, Harvard Dataverse [10.7910/DVN/HDDPTB](https://doi.org/10.7910/DVN/HDDPTB)).
Evaluation items and 2016 senator ideology must match exactly; 2012 senator
ideology coalesce rows may differ by up to 0.3% of respondents.

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
- Placement coverage is limited to 2012, 2016, 2020, and 2024. The 2012 senator
  approval battery uses a 4-pt Approve/Disapprove scale without "Somewhat", plus
  "Never Heard" (`is_aware = FALSE`).
