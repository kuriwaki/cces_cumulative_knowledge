# Written by Codex

library(ccesMRPprep)
stopifnot(packageVersion("ccesMRPprep") >= "0.1.16")
library(haven)
library(glue)
library(fs)
library(cli)
library(dataverse)
library(tidyverse)

# Setup ----

if (!nzchar(Sys.getenv("DATAVERSE_SERVER"))) {
  Sys.setenv(DATAVERSE_SERVER = "dataverse.harvard.edu")
}

dir_create("data/source/cces")
dir_create("data/output")
dir_create("data/release")

# Yearly common-content files ----

for (yr in 2006:2025) {
  filedir <- "data/source/cces"

  filename <- glue("{yr}_cc.dta")

  if (file_exists(path(filedir, filename))) next

  cli_alert_info("Will download and write {.file {filename}}.")
  dataverse_dl <- get_cces_dataverse(name = yr)
  write_dta(dataverse_dl, path(filedir, filename))
}

# Cumulative and auxiliary files ----

ccp <- get_dataframe_by_name(
  filename = "cces_common_cumulative_4.dta",
  "10.7910/DVN/26451",
  version = "5.0",
  .f = haven::read_dta,
  original = TRUE
)
write_dta(ccp, "data/source/cces/2006_2012_cumulative.dta")

# Modules and panels ----

cc18_comp <- get_dataframe_by_name(
  filename = "CCES18_CD_vv.dta",
  "10.7910/DVN/KDAWBM",
  version = "1",
  .f = haven::read_dta,
  original = TRUE
)
write_dta(cc18_comp, "data/source/cces/2018_cc_competitive.dta")
