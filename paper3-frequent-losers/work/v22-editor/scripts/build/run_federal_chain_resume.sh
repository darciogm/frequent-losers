#!/bin/bash
# Federal chain RESUME from 04 (00-03 + 02b done; 04 fixed for ESTRANG codes)
set -e
cd /home/darciogm1/projetos/bitter-pills/paper3-frequent-losers/work/v22-editor
LOGDIR=outputs/comprasnet/logs
for S in 04_case_holdout_dominance 05_section5_profile_monotonicity \
         06_section5_robustness 12_audit_armor 12b_audit_armor_fixup; do
  echo "=== [$(date +%H:%M:%S)] START $S --source=comprasnet ==="
  /usr/bin/time -v Rscript "scripts/analysis/${S}.R" --source=comprasnet \
      > "$LOGDIR/${S}_comprasnet.log" 2>&1 \
    || { echo "!!! FAILED: $S"; exit 1; }
  echo "=== [$(date +%H:%M:%S)] DONE  $S"
done
echo "=== FEDERAL CHAIN RESUME COMPLETE [$(date +%H:%M:%S)] ==="
