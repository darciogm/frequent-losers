#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$ROOT/.." && pwd)"
PAPER="$ROOT/manuscript/paper"

mkdir -p "$ROOT/output/tables" "$ROOT/output/figures" "$ROOT/logs"

if [[ ! -f /tmp/v4_prepared.rds ]]; then
  echo "[v10] /tmp/v4_prepared.rds missing; running v4 data preparation"
  Rscript "$REPO/v4/analysis/00_prepare_data.R"
fi

echo "[v10] regenerating inherited v9 analysis outputs"
Rscript "$ROOT/analysis/20_falsification_and_supplier_fe.R"
Rscript "$ROOT/analysis/40_utg_lee_bounds.R"
Rscript "$ROOT/analysis/41_utg_heckman.R"
Rscript "$ROOT/analysis/42_both_types_cells.R"
Rscript "$ROOT/analysis/43_rambachan_roth.R"
Rscript "$ROOT/analysis/44_wild_bootstrap.R"
Rscript "$ROOT/analysis/45_reconciliation.R"
Rscript "$ROOT/analysis/46_balance_descriptive.R"
Rscript "$ROOT/analysis/46_procurement_cost_bound.R"
Rscript "$ROOT/analysis/47_regen_fig1.R"
Rscript "$ROOT/analysis/48_mechanism_evidence.R"
Rscript "$ROOT/analysis/51_sample_restriction_robustness.R"
Rscript "$ROOT/analysis/52_market_depth_heterogeneity.R"
Rscript "$ROOT/analysis/53_quantity_definition_robustness.R"
python3 "$ROOT/analysis/49_classifier_macros.py"
python3 "$ROOT/analysis/50_v9_outputs.py"
python3 "$ROOT/analysis/54_sample_flow_diagnostics.py"

echo "[v10] checking required generated outputs"
python3 "$ROOT/check_v9_outputs.py"

echo "[v10] compiling main paper"
cd "$PAPER"
pdflatex -interaction=nonstopmode main.tex
bibtex main
pdflatex -interaction=nonstopmode main.tex
pdflatex -interaction=nonstopmode main.tex

echo "[v10] compiling online appendix"
pdflatex -interaction=nonstopmode OnlineAppendix.tex
pdflatex -interaction=nonstopmode OnlineAppendix.tex
pdflatex -interaction=nonstopmode OnlineAppendix.tex

echo "[v10] build complete"
