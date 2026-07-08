# Global preferences

## Code style
- Add `# Written by ...` as the first line of every new script file you write, e.g. Cursor, Claude Code, or Codex.

## R / tidyverse
- Use RStudio-compatible section headers: `# Section name ----` for top-level sections, `## Subsection name ----` for subsections (four trailing dashes minimum). Do NOT use box-style headers with `====` or `####`.
- Always specify `relationship` argument in joins (e.g., `relationship = "many-to-one"`)
- Prefer `glue::glue()` over `sprintf()` or `paste0()` for string interpolation
- Use `scales::number()`, `scales::percent()`, `scales::comma()`, etc. for formatting numbers — not `sprintf()`
- Use `summarize()` (American spelling), not `summarise()`
- Use `modelsummary::modelsummary()` for regression tables, not `fixest::etable()`
- Use tidyverse/readr I/O functions: `read_rds()` / `write_rds()` instead of `readRDS()` / `saveRDS()`
- Never overwrite an object with itself (e.g., `dat <- dat |> ...`). Instead, use a new name (e.g., `dat_raw <- read_dta(); dat <- dat_raw |> ...; dat_fmt <- dat |> ...`), fold the transformation into the existing pipeline, or use a helper function.
- Do not open a script with a block of variables that just store file paths. Inline each path at its point of use. Exception: a genuinely complicated script where the same path is reused or modified in several places (e.g. a shared directory prefix combined many ways) — then a named variable is justified.
- Assume an RStudio project workspace whose working directory is the project root, so write paths relative to the root. Don't define `root <- "."` or call `setwd()` in most cases.
- **Shared helpers** live in `R/` and load once per session via `.Rprofile` (and `source("00_functions.R")` as an `Rscript --vanilla` fallback). Do not use `.Renviron` for sourcing R code — reserve `.Renviron` for environment variables (e.g. `DATAVERSE_SERVER`).
- **Assignment split (`=` vs `<-`).** In numbered pipeline scripts (`03`–`07`), use two conventions:
  - **`=`** for script-level **config** set once at the top — paths reused across the script (`out_dir`), lookup tables, year/item constants, and other knobs you might tweak before a run. Group these under a `# Config ----` section near the top.
  - **`<-`** for **derived** objects — anything produced by I/O, joins, transforms, or helper functions (`xwalk`, `awareness_long`, `scored_extended`, etc.).
  - **`<-`** always inside function bodies, including function definitions (`helper <- function(...)`).
  - When naming a config variable for a shared path is justified (see path rule above), put it in `# Config ----` and assign with `=`.
- **Named arguments** in calls to project helpers (`build_long()`, `build_ideo_coalesce()`, etc.) when passing more than one argument or when names aid readability. Piped first arguments may stay positional.
- **Release scripts.** Scripts 03, 05, and 06 each write a distinct dataset to `data/release` (media, scored knowledge, placement). Script 07 optionally stacks those three files. Script 04 writes an intermediate unscored knowledge file to `data/output` consumed by 05. Do not stack placement onto knowledge inside 05 or 06; use 07 or join on `(year, case_id)` when needed.
- One sentence per source line. Each sentence gets its own line; never hard-wrap a single sentence across multiple lines. This keeps git diffs sentence-level.
