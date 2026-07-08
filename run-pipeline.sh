#!/usr/bin/env bash
# Run the CCES media/knowledge/placement pipeline in order.
# Usage: ./run-pipeline.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

run_script() {
  local script="$1"
  echo ""
  echo "========================================"
  echo "==> ${script}"
  echo "========================================"
  Rscript "${script}"
}

run_script 01_download-cces-dataverse.R
run_script 02_codebook.R
run_script 03_media-use.R
run_script 04_political-knowledge.R
run_script 05_correct-answers.R
run_script 06_placement.R
run_script 07_join-release.R

echo ""
echo "Pipeline finished."
