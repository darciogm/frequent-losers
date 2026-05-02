#!/usr/bin/env bash
# ============================================================================
# 00_master_paper.sh — full reproducible pipeline: data → values.tex → PDF
# Paper 3 v14
#
# Run order:
#   1. 01_clean.R                          (rebuild /tmp cache)
#   2. Disciplinary cleanup scripts (30-35) — already run; reuse outputs
#   3. Gate diagnostics (36-39)
#   4. Leakage audit (40)
#   5. Operational metrics + audit (42, 43)
#   6. Cosmetic figures (41)
#   7. JLEO rereview diagnostics (47-54)
#   8. 99_make_paper_values.R              (regenerate values.tex + audit)
#   9. pdflatex × 3 + bibtex                 (compile paper)
#  10. verify_paper.sh                       (run verification suite)
#
# Usage:
#   bash scripts/00_master_paper.sh           # full rerun
#   bash scripts/00_master_paper.sh --fast    # skip 01-43, only regen values + compile
# ============================================================================

set -euo pipefail
cd "$(dirname "$0")/.."

FAST=0
if [[ "${1:-}" == "--fast" ]]; then FAST=1; fi

LOG_DIR=logs
TS=$(date +%Y%m%d_%H%M%S)
mkdir -p "$LOG_DIR"

run_R() {
  local script=$1
  local tag=$2
  local logfile="$LOG_DIR/${tag}_${TS}.log"
  echo "  [$(date +%H:%M:%S)] running $script ..."
  Rscript -e ".script_dir <- 'scripts'; source('${script}')" \
    > "$logfile" 2>&1 \
    || { echo "    FAILED. See $logfile"; tail -20 "$logfile"; exit 1; }
  echo "    done. log: $logfile"
}

if [[ $FAST -eq 0 ]]; then
  echo "=== Stage 1: rebuild /tmp cache (01_clean.R) ==="
  run_R "scripts/01_clean.R" "01_clean"

  echo "=== Stage 2: gate diagnostics (36-39) ==="
  for s in 36_gate_d1_harmonized 37_gate_d2_modal_auc 38_gate_d3_continuous_only 39_gate_d4_cade_winner_heavy; do
    run_R "scripts/${s}.R" "${s}"
  done

  echo "=== Stage 3: leakage audit (40) ==="
  run_R "scripts/40_leakage_audit_d3.R" "40_leakage"

  echo "=== Stage 4: operational + precision audit (42, 43) ==="
  run_R "scripts/42_operational_metrics.R" "42_ops"
  run_R "scripts/43_precision_at_k_audit.R" "43_audit"

  echo "=== Stage 5: cosmetic figures (41) ==="
  run_R "scripts/41_fix_figures.R" "41_figs"
fi

if [[ $FAST -eq 0 ]]; then
  echo "=== Stage 5b: v8 CSV consolidation + legacy reproduction (44, 45) ==="
  run_R "scripts/44_consolidate_v8_csvs.R" "44_v8"
  run_R "scripts/45_legacy_m1m3_perm_welfare.R" "45_legacy"

  echo "=== Stage 5c: JLEO rereview diagnostics (53, 54, 47-52) ==="
  for s in 53_strict_train_period_threshold \
           54_threshold_table_q3iqr \
           47_theory_operationalization_audit \
           48_stratum_scope_reframe \
           49_imhof_incremental_value \
           50_negative_cell_audit \
           51_item_level_scope_match \
           52_external_validity_scope; do
    run_R "scripts/${s}.R" "${s}"
  done
fi

echo "=== Stage 6: regenerate values.tex + provenance audit (99) ==="
run_R "scripts/99_make_paper_values.R" "99_values"

echo "=== Stage 7: compile paper_v13.tex ==="
cd work/v13
rm -f paper_v13.aux paper_v13.bbl paper_v13.blg
# Pass 1 (warnings about undefined refs are normal — bibtex hasn't run yet).
pdflatex -interaction=nonstopmode -draftmode paper_v13.tex > "../../$LOG_DIR/pdflatex1_${TS}.log" 2>&1 || true
bibtex paper_v13 > "../../$LOG_DIR/bibtex_${TS}.log" 2>&1 || true
pdflatex -interaction=nonstopmode -draftmode paper_v13.tex > "../../$LOG_DIR/pdflatex2_${TS}.log" 2>&1 || true
pdflatex -interaction=nonstopmode paper_v13.tex > "../../$LOG_DIR/pdflatex3_${TS}.log" 2>&1 || true
# Final pass 3 must produce a PDF and have no LaTeX errors.
if grep -q "^! " "../../$LOG_DIR/pdflatex3_${TS}.log"; then
  echo "FAILED at final pass — LaTeX error:"
  grep -E "^! |Undefined" "../../$LOG_DIR/pdflatex3_${TS}.log" | head -5
  exit 1
fi
cd ../..

echo "=== Stage 8: verification ==="
bash scripts/verify_paper.sh

echo
echo "=== ALL DONE ==="
echo "    PDF:   work/v13/paper_v13.pdf"
echo "    Values: work/v13/values.tex"
echo "    Audit: work/v13/audit_paper_numbers.md"
ls -la work/v13/paper_v13.pdf work/v13/values.tex work/v13/audit_paper_numbers.md 2>/dev/null
