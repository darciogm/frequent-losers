#!/bin/bash
# Full v9 reproducibility run: every numbered analysis script, in order, isolated
# and logged. Re-running from the prepared cache (/tmp/v4_prepared.rds) regenerates
# values.tex and output/tables/*.tex byte-identically; figure PDFs differ only by
# an embedded creation timestamp (rendered raster content is identical). The
# cache-building step (v4 00_prepare_data.R, raw BEC data) is upstream and not
# part of this run. Each script sets its own threads (bp_set_threads(12)); scripts
# run sequentially so peak RSS stays well within the 16 GB budget.
set -u
AN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALUES="$AN/../manuscript/paper/values.tex"
mkdir -p "$AN/../logs"
LOG="$AN/../logs/pipeline_run_$(date +%Y%m%d_%H%M).log"
cd "$AN" || exit 1
{
  echo "==== v9 pipeline reproducibility run ===="
  echo "host=$(hostname) nproc=$(nproc) $(free -h | awk '/Mem:/{print "free="$7}')"
  echo "cache: $(ls -la /tmp/v4_prepared.rds 2>/dev/null | awk '{print $5" bytes"}')"
  echo "values.tex md5 (pre):  $(md5sum "$VALUES" | cut -d' ' -f1)"
  echo "------------------------------------------------------------"
  for s in $(ls [0-9]*.R [0-9]*.py | sort); do
    case "$s" in *.py) run=python3 ;; *) run=Rscript ;; esac
    t0=$SECONDS
    if "$run" "$s" >"/tmp/pipe_${s}.out" 2>&1; then st="OK  "; else st="FAIL"; fi
    printf "[%s %4ds] %s\n" "$st" "$((SECONDS - t0))" "$s"
  done
  echo "------------------------------------------------------------"
  echo "values.tex md5 (post): $(md5sum "$VALUES" | cut -d' ' -f1)"
  echo "== git diff (tracked outputs; empty == reproducible) =="
  git -C "$AN" diff --stat -- ../manuscript/paper/values.tex ../output/tables/
} | tee "$LOG"
