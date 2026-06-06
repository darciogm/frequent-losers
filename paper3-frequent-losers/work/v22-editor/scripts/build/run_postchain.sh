#!/bin/bash
# Post-chain sequence: re-runs (label/filename fixes) -> R1-extended -> SRP -> price panel
set -e
cd /home/darciogm1/projetos/bitter-pills/paper3-frequent-losers/work/v22-editor
LOGDIR=outputs/comprasnet/logs
echo "=== [$(date +%H:%M:%S)] re-run 01-federal (labels) ==="
Rscript scripts/analysis/01_label_funnel_reconciliation.R --source=comprasnet > "$LOGDIR/01_label_funnel_reconciliation_comprasnet.log" 2>&1
echo "=== [$(date +%H:%M:%S)] re-run 03-federal (filename) ==="
Rscript scripts/analysis/03_timing_case_holdout_validation.R --source=comprasnet > "$LOGDIR/03_timing_case_holdout_validation_comprasnet.log" 2>&1
rm -f outputs/comprasnet/tables/table_D_strict_2009_2016_to_2017_2019.csv outputs/comprasnet/tables/table_D_strict_2009_2016_to_2017_2019.tex
echo "=== [$(date +%H:%M:%S)] R1-EXTENDED (BEC byte-identity, 8 scripts) ==="
bash scripts/build/run_r1_extended.sh || { echo "!!! R1-EXTENDED FAILED/DIFF — inspect r1_extended_verdicts.csv"; exit 1; }
echo "=== [$(date +%H:%M:%S)] SRP stratified leg ==="
Rscript scripts/analysis/13_srp_stratified_validation.R --source=comprasnet > "$LOGDIR/13_srp_stratified_comprasnet.log" 2>&1
echo "=== [$(date +%H:%M:%S)] federal price panel build ==="
python3 scripts/build/build_federal_price_panel.py > "$LOGDIR/build_federal_price_panel.log" 2>&1
echo "=== [$(date +%H:%M:%S)] final fill re-extract ==="
python3 scripts/build/fill_federal_numbers.py > "$LOGDIR/final_fill_extract.log" 2>&1
echo "=== POST-CHAIN COMPLETE [$(date +%H:%M:%S)] ==="
