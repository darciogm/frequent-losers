#!/bin/bash
# Federal run chain — Phase 1 execution (doc 99 §2) — sequential, stop on first failure
set -e
cd /home/darciogm1/projetos/bitter-pills/paper3-frequent-losers/work/v22-editor
LOGDIR=outputs/comprasnet/logs
mkdir -p "$LOGDIR"
for S in 00_build_canonical_validation_targets 01_label_funnel_reconciliation \
         02_opportunity_adjusted_validation 02b_opportunity_sensitivity_contact2 \
         03_timing_case_holdout_validation 04_case_holdout_dominance \
         05_section5_profile_monotonicity 06_section5_robustness \
         12_audit_armor 12b_audit_armor_fixup; do
  echo "=== [$(date +%H:%M:%S)] START $S --source=comprasnet ==="
  /usr/bin/time -v Rscript "scripts/analysis/${S}.R" --source=comprasnet \
      > "$LOGDIR/${S}_comprasnet.log" 2>&1 \
    || { echo "!!! FAILED: $S (see $LOGDIR/${S}_comprasnet.log)"; exit 1; }
  echo "=== [$(date +%H:%M:%S)] DONE  $S (tail of log:)"
  tail -3 "$LOGDIR/${S}_comprasnet.log"
done
echo "=== FEDERAL CHAIN COMPLETE [$(date +%H:%M:%S)] ==="
