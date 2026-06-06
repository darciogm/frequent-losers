#!/bin/bash
set -e
cd /home/darciogm1/projetos/bitter-pills/paper3-frequent-losers/work/v22-editor
LOGDIR=outputs/comprasnet/logs
echo "=== [$(date +%H:%M:%S)] SRP stratified leg ==="
Rscript scripts/analysis/13_srp_stratified_validation.R --source=comprasnet > "$LOGDIR/13_srp_stratified_comprasnet.log" 2>&1
echo "=== [$(date +%H:%M:%S)] federal price panel ==="
python3 scripts/build/build_federal_price_panel.py > "$LOGDIR/build_federal_price_panel.log" 2>&1
echo "=== [$(date +%H:%M:%S)] final fill extract ==="
python3 scripts/build/fill_federal_numbers.py > "$LOGDIR/final_fill_extract.log" 2>&1
tail -2 "$LOGDIR/final_fill_extract.log"
echo "=== FINAL LEG COMPLETE [$(date +%H:%M:%S)] ==="
