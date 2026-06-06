#!/usr/bin/env bash
# =============================================================================
# run_r1_extended.sh  --  R1-EXTENDED BEC byte-identity regression harness.
# -----------------------------------------------------------------------------
# WHY THIS EXISTS
#   Gate R1 proved BEC byte-identity for the two-source refactor on scripts
#   00 + 02 only. EIGHT more analysis scripts were ported to the source_config
#   abstraction layer, and their --source=bec outputs feed the FROZEN submitted
#   manuscript. This harness proves the SAME thing for those eight: that running
#   each ported script with --source=bec reproduces its BEC outputs byte-for-byte
#   (modulo the established benign-diff taxonomy: cairo PDF metadata, timestamped
#   telemetry logs, STRING_AGG(DISTINCT) intra-cell token order).
#
# !!  CONCURRENCY WARNING  --  READ BEFORE RUNNING (non-dry-run)  !!
#   A heavy FEDERAL (ComprasNet) chain may be running concurrently. This harness
#   runs REAL R scripts and writes BEC outputs. It MUST NOT run while the federal
#   chain is active, because:
#     (a) both can saturate RAM/CPU past the workstation budget (<=16 GiB), and
#     (b) the git-clean precheck inspects the working tree; concurrent federal
#         writes under outputs/comprasnet/ would muddy `git status`.
#   The harness's manifest is FENCED to BEC paths only (no outputs/comprasnet/**
#   path is ever touched), and it checks `pgrep -f run_federal_chain` and aborts
#   if the federal chain looks live. STOP the federal chain before --run.
#
# MODES
#   --dry-run            print plan + manifest + per-file git/baseline state; run NO R.
#   (no flag) / --run    execute: snapshot -> git-clean precheck -> run R (cheapest
#                        first, sequential, /usr/bin/time -v) -> classify diffs ->
#                        write verdicts CSV -> auto-restore benign, LEAVE DIFF in place.
#   --only=NN[,NN...]    restrict to a comma list of script tags (e.g. --only=01,12b).
#   --skip-federal-check bypass the federal-chain liveness guard (use only if certain).
#
# OUTPUT
#   outputs/comprasnet/diagnostics/r1_extended_verdicts.csv
#     columns: script,file,status,note
#     status in {identical, benign-metadata, benign-tokenorder, benign-telemetry,
#                benign-numeric, new-expected, DIFF, vanished}
#   PASS iff zero DIFF-class (and zero vanished) files.
#
# DESIGN NOTE -- git baseline vs snapshot baseline
#   The repo .gitignore ignores *.csv, *.pdf, *.parquet. Therefore only the .tex /
#   .txt / .md outputs of these scripts are git-tracked; the bulk (CSV/PDF) are
#   present on disk but UNTRACKED. So a pure `git diff` baseline (as the task's
#   wording assumes) covers only part of the surface. This harness uses BOTH:
#     - TRACKED files  : git-clean precheck via `git status --porcelain`; restore
#                        via `git checkout --`.
#     - UNTRACKED files: byte-snapshot into a baseline dir BEFORE running; restore
#                        by copying the snapshot back. (No git involvement.)
#   Either way the working tree ends byte-identical to its pre-run state for all
#   benign-class files; DIFF-class files are left in place for inspection.
# =============================================================================
set -u -o pipefail

# ----------------------------------------------------------------------------- paths
V22="/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers/work/v22-editor"
REPO="/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers"
ANALYSIS="$V22/scripts/analysis"
CLASSIFY="$V22/scripts/build/r1_diff_classify.sh"
VERDICTS="$V22/outputs/comprasnet/diagnostics/r1_extended_verdicts.csv"
LOGDIR="$V22/outputs/comprasnet/logs/r1_extended"
SNAPDIR="$V22/outputs/comprasnet/cache/r1_extended_baseline"   # snapshot STORE for untracked BEC baselines; the dir itself lives under the comprasnet (non-BEC) tree so snapshots never collide with the BEC outputs they mirror

# ----------------------------------------------------------------------------- args
MODE="run"; ONLY=""; SKIP_FED_CHECK=0
for a in "$@"; do
  case "$a" in
    --dry-run) MODE="dry" ;;
    --run)     MODE="run" ;;
    --only=*)  ONLY="${a#--only=}" ;;
    --skip-federal-check) SKIP_FED_CHECK=1 ;;
    *) echo "unknown arg: $a" >&2; exit 2 ;;
  esac
done

# ----------------------------------------------------------------------------- --only ownership guard
# 12 and 12b SHARE five audit_armor/ files (frozen_timing.csv + defendant_roles.csv
# have 12b-owned schemas in the committed state; three more are 12b-overwritten).
# Running 12 WITHOUT 12b would verify 12's bytes for files whose committed state is
# 12b's -> false DIFF, and would leave the shared dir in 12's (non-committed) state.
# Refuse any --only selection that includes 12 but not 12b.
if [[ -n "$ONLY" ]]; then
  _has12=0; _has12b=0
  IFS=',' read -ra _onlyarr <<<"$ONLY"
  for _x in "${_onlyarr[@]}"; do
    [[ "$_x" == "12"  ]] && _has12=1
    [[ "$_x" == "12b" ]] && _has12b=1
  done
  if [[ "$_has12" -eq 1 && "$_has12b" -eq 0 ]]; then
    echo "ABORT: --only includes 12 without 12b." >&2
    echo "       12 and 12b share five files under outputs/diagnostics/audit_armor/" >&2
    echo "       (frozen_timing.csv + defendant_roles.csv carry 12b-owned schemas in the" >&2
    echo "       committed state; granularity_sweep.csv + permutation_power_curve.csv +" >&2
    echo "       audit_armor_macros.tex are 12b-overwritten). Verifying 12 alone would" >&2
    echo "       false-DIFF against the committed 12b state and leave the shared dir in 12's" >&2
    echo "       (non-committed) state. Re-run with --only=12,12b (or drop 12)." >&2
    exit 2
  fi
fi

# ============================================================================ MANIFEST
# Each manifest row:  TAG | SCRIPT_FILE | REL_OUTPUT_PATH | HINT | EXPECT
#   REL_OUTPUT_PATH : relative to $V22 (BEC paths only -- NEVER outputs/comprasnet/**)
#   HINT            : plain | pdf | telemetry | tokenorder | numeric  (steers the classifier)
#   EXPECT          : baseline | new-expected | conditional
#                       baseline     -> must exist pre-run, compared byte/benign.
#                       new-expected -> known new file from the refactor (no baseline;
#                                       presence after run is OK, absence also OK).
#                       conditional  -> only written on a branch/flag; absence is OK,
#                                       presence is compared if a baseline exists.
# Order of the eight scripts is CHEAPEST-FIRST (see EXEC ORDER rationale at bottom):
#   01  (seconds: count reconciliations, one small fig)
#   05  (profile/monotonicity: medium frame ops, no permutation)
#   06  (section5 robustness: threshold sweeps, negative controls; medium)
#   02b (opportunity sensitivity: B-permutation block + matched strata; heavier)
#   03  (timing holdout: rolling-origin self-joins over firm x year panel)
#   04  (case holdout: leave-one-case/-defendant-out + clustered RI null draws)
#   12  (audit armor: permutation power curve B-draws + granularity sweep)
#   12b (audit armor fixup: re-runs the same B-permutation power block)
# -----------------------------------------------------------------------------
read -r -d '' MANIFEST <<'EOF'
# --- 01_label_funnel_reconciliation -----------------------------------------
01|01_label_funnel_reconciliation.R|outputs/diagnostics/label_count_reproduction.csv|plain|baseline
01|01_label_funnel_reconciliation.R|outputs/tables/main/table_A_label_funnel.csv|plain|baseline
01|01_label_funnel_reconciliation.R|outputs/tables/main/table_A_label_funnel.tex|plain|baseline
01|01_label_funnel_reconciliation.R|outputs/tables/main/table_B_case_timing_and_benchmark_use.csv|plain|baseline
01|01_label_funnel_reconciliation.R|outputs/tables/main/table_B_case_timing_and_benchmark_use.tex|plain|baseline
01|01_label_funnel_reconciliation.R|outputs/diagnostics/cobidder_set_comparison_193_vs_210.csv|plain|baseline
01|01_label_funnel_reconciliation.R|outputs/diagnostics/cobidder_set_comparison_summary.csv|plain|baseline
01|01_label_funnel_reconciliation.R|outputs/diagnostics/label_funnel_assertions.csv|plain|baseline
01|01_label_funnel_reconciliation.R|outputs/figures/main/fig_label_funnel.pdf|pdf|baseline
01|01_label_funnel_reconciliation.R|outputs/diagnostics/label_funnel_new_macros.tex|plain|baseline
# --- 05_section5_profile_monotonicity ---------------------------------------
05|05_section5_profile_monotonicity.R|outputs/tables/appendix/table_E_section5_group_counts.csv|plain|baseline
05|05_section5_profile_monotonicity.R|outputs/tables/appendix/table_E_section5_group_counts.tex|plain|baseline
05|05_section5_profile_monotonicity.R|outputs/tables/main/table_J_economic_profile.csv|plain|baseline
05|05_section5_profile_monotonicity.R|outputs/tables/main/table_J_economic_profile.tex|plain|baseline
05|05_section5_profile_monotonicity.R|outputs/tables/appendix/table_E_standardized_profile_differences.csv|plain|baseline
05|05_section5_profile_monotonicity.R|outputs/tables/appendix/table_E_standardized_profile_differences.tex|plain|baseline
05|05_section5_profile_monotonicity.R|outputs/figures/main/fig_profile_standardized_differences.pdf|pdf|baseline
05|05_section5_profile_monotonicity.R|outputs/tables/main/table_K_opportunity_adjusted_profile.csv|numeric|baseline
05|05_section5_profile_monotonicity.R|outputs/tables/main/table_K_opportunity_adjusted_profile.tex|plain|baseline
05|05_section5_profile_monotonicity.R|outputs/tables/main/table_L_monotonicity_bins.csv|plain|baseline
05|05_section5_profile_monotonicity.R|outputs/diagnostics/monotonicity_score_deciles.csv|plain|baseline
05|05_section5_profile_monotonicity.R|outputs/diagnostics/monotonicity_topk.csv|plain|baseline
05|05_section5_profile_monotonicity.R|outputs/tables/main/table_L_monotonicity_bins.tex|plain|baseline
05|05_section5_profile_monotonicity.R|outputs/figures/main/fig_cobidder_prevalence_by_participation_bin.pdf|pdf|baseline
05|05_section5_profile_monotonicity.R|outputs/figures/main/fig_excess_contact_by_participation_bin.pdf|pdf|baseline
05|05_section5_profile_monotonicity.R|outputs/tables/main/table_M_binary_vs_continuous_score.csv|plain|baseline
05|05_section5_profile_monotonicity.R|outputs/tables/main/table_M_binary_vs_continuous_score.tex|plain|baseline
05|05_section5_profile_monotonicity.R|docs/jleo_rr_revision/binary_vs_continuous_score_memo.md|plain|baseline
05|05_section5_profile_monotonicity.R|outputs/diagnostics/section5_profile_audit_log.txt|telemetry|baseline
# --- 06_section5_robustness -------------------------------------------------
06|06_section5_robustness.R|outputs/tables/appendix/table_E_placebo_thresholds.csv|plain|baseline
06|06_section5_robustness.R|outputs/figures/appendix/fig_threshold_sensitivity.pdf|pdf|baseline
06|06_section5_robustness.R|outputs/diagnostics/threshold_bunching_T14.csv|plain|baseline
06|06_section5_robustness.R|outputs/figures/appendix/fig_threshold_bunching_T14.pdf|pdf|baseline
06|06_section5_robustness.R|outputs/diagnostics/ordinary_loser_proxy_stats.csv|plain|baseline
06|06_section5_robustness.R|outputs/tables/main/table_N_ordinary_loser_alternatives.csv|plain|baseline
06|06_section5_robustness.R|outputs/tables/main/table_N_ordinary_loser_alternatives.tex|plain|baseline
06|06_section5_robustness.R|outputs/tables/appendix/table_E_market_specific_zero_win_definitions.csv|plain|baseline
06|06_section5_robustness.R|outputs/tables/appendix/table_E_market_specific_zero_win_validation.csv|plain|baseline
06|06_section5_robustness.R|outputs/diagnostics/leave_one_item_group_out.csv|plain|baseline
06|06_section5_robustness.R|outputs/tables/appendix/table_E_negative_controls.csv|plain|baseline
06|06_section5_robustness.R|outputs/figures/appendix/fig_negative_control_distribution.pdf|pdf|baseline
06|06_section5_robustness.R|outputs/diagnostics/section5_robustness_audit_log.txt|telemetry|baseline
# --- 02b_opportunity_sensitivity_contact2 -----------------------------------
# NOTE (TRAP): isolated subdir sensitivity_contact2/. The frame cache was RENAMED
# *_contact2.csv by the refactor; the OLD-name file (firm_opportunity_adjusted_frame.csv)
# is an orphan from a pre-rename run and is reported separately (not in the manifest).
02b|02b_opportunity_sensitivity_contact2.R|outputs/sensitivity_contact2/diagnostics/observed_defendant_contact_summary.csv|plain|baseline
02b|02b_opportunity_sensitivity_contact2.R|outputs/sensitivity_contact2/tables/appendix/table_D_opportunity_cell_construction.csv|plain|baseline
02b|02b_opportunity_sensitivity_contact2.R|outputs/sensitivity_contact2/diagnostics/opportunity_cell_sparsity.csv|plain|baseline
02b|02b_opportunity_sensitivity_contact2.R|outputs/sensitivity_contact2/tables/appendix/table_D_opportunity_cell_construction.tex|plain|baseline
02b|02b_opportunity_sensitivity_contact2.R|outputs/sensitivity_contact2/cache/firm_opportunity_adjusted_frame_contact2.csv|plain|new-expected
02b|02b_opportunity_sensitivity_contact2.R|outputs/sensitivity_contact2/diagnostics/opportunity_common_support.csv|plain|baseline
02b|02b_opportunity_sensitivity_contact2.R|outputs/sensitivity_contact2/tables/appendix/table_D_control_function_validation_full.csv|plain|baseline
02b|02b_opportunity_sensitivity_contact2.R|outputs/sensitivity_contact2/tables/main/table_C_opportunity_adjusted_validation.csv|plain|baseline
02b|02b_opportunity_sensitivity_contact2.R|outputs/sensitivity_contact2/tables/main/table_C_opportunity_adjusted_validation.tex|plain|baseline
02b|02b_opportunity_sensitivity_contact2.R|outputs/sensitivity_contact2/tables/appendix/table_D_observed_expected_by_score_bins.csv|plain|baseline
02b|02b_opportunity_sensitivity_contact2.R|outputs/sensitivity_contact2/tables/appendix/table_D_observed_expected_by_score_bins.tex|plain|baseline
02b|02b_opportunity_sensitivity_contact2.R|outputs/sensitivity_contact2/figures/main/fig_observed_vs_expected_contact_bins.pdf|pdf|baseline
02b|02b_opportunity_sensitivity_contact2.R|outputs/sensitivity_contact2/figures/appendix/fig_excess_contact_by_score_bins.pdf|pdf|baseline
02b|02b_opportunity_sensitivity_contact2.R|outputs/sensitivity_contact2/cache/opportunity_permutation_metrics.csv|plain|baseline
02b|02b_opportunity_sensitivity_contact2.R|outputs/sensitivity_contact2/tables/main/table_D_opportunity_permutation_validation.csv|plain|baseline
02b|02b_opportunity_sensitivity_contact2.R|outputs/sensitivity_contact2/tables/main/table_D_opportunity_permutation_validation.tex|plain|baseline
02b|02b_opportunity_sensitivity_contact2.R|outputs/sensitivity_contact2/figures/main/fig_opportunity_permutation_pr_auc.pdf|pdf|baseline
02b|02b_opportunity_sensitivity_contact2.R|outputs/sensitivity_contact2/figures/appendix/fig_opportunity_permutation_precision_at_k.pdf|pdf|baseline
02b|02b_opportunity_sensitivity_contact2.R|outputs/sensitivity_contact2/tables/appendix/table_D_matched_opportunity_validation.csv|plain|baseline
02b|02b_opportunity_sensitivity_contact2.R|outputs/sensitivity_contact2/tables/appendix/table_D_matched_opportunity_validation_summary.csv|plain|baseline
02b|02b_opportunity_sensitivity_contact2.R|outputs/sensitivity_contact2/tables/appendix/table_D_matched_opportunity_validation.tex|plain|baseline
02b|02b_opportunity_sensitivity_contact2.R|outputs/sensitivity_contact2/diagnostics/opportunity_case_buyer_contribution.csv|plain|baseline
02b|02b_opportunity_sensitivity_contact2.R|outputs/sensitivity_contact2/diagnostics/opportunity_validation_audit_log.txt|telemetry|baseline
# --- 03_timing_case_holdout_validation --------------------------------------
# NOTE (TRAP): in BEC mode USE_YEAR_MAP=FALSE -> year_map.parquet cache is NOT
# written (federal-only). It is intentionally NOT in this manifest.
03|03_timing_case_holdout_validation.R|outputs/tables/main/table_D_strict_2009_2016_to_2017_2019.csv|plain|baseline
03|03_timing_case_holdout_validation.R|outputs/diagnostics/strict_holdout_composition.csv|plain|baseline
03|03_timing_case_holdout_validation.R|outputs/tables/main/table_D_strict_2009_2016_to_2017_2019.tex|plain|baseline
03|03_timing_case_holdout_validation.R|outputs/tables/main/table_E_rolling_origin_validation.csv|plain|baseline
03|03_timing_case_holdout_validation.R|outputs/tables/main/table_E_rolling_origin_validation.tex|plain|baseline
03|03_timing_case_holdout_validation.R|outputs/figures/main/fig_rolling_origin_pr_auc.pdf|pdf|baseline
03|03_timing_case_holdout_validation.R|outputs/figures/main/fig_rolling_origin_precision_recall.pdf|pdf|baseline
03|03_timing_case_holdout_validation.R|outputs/figures/appendix/fig_rolling_origin_auc.pdf|pdf|baseline
03|03_timing_case_holdout_validation.R|outputs/tables/main/table_F_leakage_audit.csv|plain|baseline
03|03_timing_case_holdout_validation.R|outputs/tables/main/table_F_leakage_audit.tex|plain|baseline
03|03_timing_case_holdout_validation.R|outputs/tables/appendix/table_D_direct_defendant_timing_scope_check.csv|plain|baseline
# --- 04_case_holdout_dominance ----------------------------------------------
# NOTE (TRAP): case_cobidder_map_federal.csv is federal-only (not in manifest).
# clustered RI outputs are CONDITIONAL (ri_blocker branch); absence is OK.
04|04_case_holdout_dominance.R|outputs/tables/main/table_G_leave_one_case_out_validation.csv|plain|baseline
04|04_case_holdout_dominance.R|outputs/tables/main/table_G_leave_one_case_out_validation.tex|plain|baseline
04|04_case_holdout_dominance.R|outputs/figures/main/fig_leave_one_case_out_distribution.pdf|pdf|baseline
04|04_case_holdout_dominance.R|outputs/diagnostics/case_dominance_summary.csv|plain|baseline
04|04_case_holdout_dominance.R|outputs/tables/main/table_H_case_dominance_validation.csv|plain|baseline
04|04_case_holdout_dominance.R|outputs/diagnostics/case_topk_coverage.csv|plain|baseline
04|04_case_holdout_dominance.R|outputs/tables/main/table_H_case_dominance_validation.tex|plain|baseline
04|04_case_holdout_dominance.R|outputs/figures/appendix/fig_case_positive_concentration.pdf|pdf|baseline
04|04_case_holdout_dominance.R|outputs/diagnostics/environment_dominance_summary.csv|plain|baseline
04|04_case_holdout_dominance.R|outputs/tables/appendix/table_D_environment_dominance.csv|plain|baseline
04|04_case_holdout_dominance.R|outputs/tables/appendix/table_D_leave_one_defendant_group_out.csv|plain|baseline
04|04_case_holdout_dominance.R|outputs/cache/clustered_ri_metrics.csv|plain|conditional
04|04_case_holdout_dominance.R|outputs/tables/appendix/table_D_clustered_randomization_inference.csv|plain|conditional
04|04_case_holdout_dominance.R|outputs/figures/appendix/fig_clustered_randomization_inference.pdf|pdf|conditional
04|04_case_holdout_dominance.R|docs/jleo_rr_revision/clustered_randomization_inference_blocker.md|plain|conditional
04|04_case_holdout_dominance.R|outputs/diagnostics/case_holdout_dominance_audit_log.txt|telemetry|baseline
# --- 12_audit_armor ---------------------------------------------------------
# NOTE (TRAP): armor_flags.csv is written ONLY when ARMOR_FLAGS is non-empty
# (degrade-gracefully). On a clean BEC run all components are present -> no flags
# -> file absent. Classified new-expected (presence OK, absence OK; not a DIFF).
# NOTE (SHARED-OWNERSHIP, FIVE FILES -- expanded 2026-06-06 to mirror the S1
# manifest-ownership fix): 12 writes EARLY versions of FIVE files that 12b then
# OVERWRITES with a DIFFERENT schema; the COMMITTED on-disk state is 12b's for
# all five, so all five are 12b-OWNED and listed ONLY in the 12b block below:
#     frozen_timing.csv             (12: 5 cols w/ note -> 12b: 4 cols  [12b committed])
#     defendant_roles.csv           (12: long stat names -> 12b: short  [12b committed])
#     granularity_sweep.csv         (12: 3 rows, cols `granularity`/`comparable_pairs_score`
#                                      -> 12b: 5 rows incl. label-blind, cols
#                                      `stratifier`/`pairs` [12b committed])
#     permutation_power_curve.csv   (12 writes, 12b overwrites; numbers IDENTICAL
#                                      under the shared seed 20260605L, but 12b owns it)
#     audit_armor_macros.tex        (12 writes a subset; 12b emits the SUPERSET incl.
#                                      \valArmorWithinLB/\valArmorWithinLBall/
#                                      \valArmorFrozenRetroN consumed by the manuscript)
# Listing any of the five under tag 12 makes the harness snapshot 12's INTERMEDIATE
# write as the baseline and then false-DIFF the 12b-final state against it (the exact
# manifest-ownership artifact the S1 review predicted). They are intentionally NOT
# listed here. 12 still OWNS leakage_check_cell_level.csv (part A; 12b only READS it)
# and armor_flags.csv (12's degrade-gracefully flag file).
12|12_audit_armor.R|outputs/diagnostics/audit_armor/leakage_check_cell_level.csv|plain|baseline
12|12_audit_armor.R|outputs/diagnostics/audit_armor/armor_flags.csv|plain|new-expected
# --- 12b_audit_armor_fixup --------------------------------------------------
# NOTE (SHARED-OVERWRITE): 12b runs LAST and OVERWRITES FIVE files in the SAME
# audit_armor/ dir that 12 also writes:
#     granularity_sweep.csv         (12 writes, 12b overwrites)
#     permutation_power_curve.csv   (12 writes, 12b overwrites)
#     audit_armor_macros.tex        (12 writes, 12b overwrites)
#     frozen_timing.csv             (12: 5 cols  -> 12b: 4 cols  [12b committed])
#     defendant_roles.csv           (12: long labels -> 12b: short labels [12b committed])
# Ownership: the COMMITTED manuscript state for all five is 12b's. 12b running
# AFTER 12 means 12's bytes are verified (for the three it shares with the same
# schema) before 12b touches them; for frozen_timing/defendant_roles the schemas
# DIFFER, so only 12b's version is baselined here -- they are 12b-owned and were
# removed from the 12 block above. armor_flags_12b.csv is conditional (new-expected).
12b|12b_audit_armor_fixup.R|outputs/diagnostics/audit_armor/granularity_sweep.csv|plain|baseline
12b|12b_audit_armor_fixup.R|outputs/diagnostics/audit_armor/permutation_power_curve.csv|plain|baseline
12b|12b_audit_armor_fixup.R|outputs/diagnostics/audit_armor/audit_armor_macros.tex|plain|baseline
12b|12b_audit_armor_fixup.R|outputs/diagnostics/audit_armor/frozen_timing.csv|plain|baseline
12b|12b_audit_armor_fixup.R|outputs/diagnostics/audit_armor/defendant_roles.csv|plain|baseline
12b|12b_audit_armor_fixup.R|outputs/diagnostics/audit_armor/armor_flags_12b.csv|plain|new-expected
EOF

# Execution order (cheapest-first); 12b after 12 (shares files).
ORDER="01 05 06 02b 03 04 12 12b"

# Orphan / rename traps to REPORT (not run, not DIFF-classified):
#   02b: old-name frame cache orphaned by the *_contact2 rename.
ORPHAN_REPORT="outputs/sensitivity_contact2/cache/firm_opportunity_adjusted_frame.csv"

# ============================================================================ helpers
hr(){ printf '%s\n' "----------------------------------------------------------------------"; }

manifest_for(){  # $1 = tag ; echoes the manifest rows for that tag
  printf '%s\n' "$MANIFEST" | grep -v '^#' | grep -v '^$' | awk -F'|' -v t="$1" '$1==t'
}

is_tracked(){  # $1 = rel path -> 0 if git-tracked
  git -C "$REPO" ls-files --error-unmatch "$V22/$1" >/dev/null 2>&1
}

selected(){  # honor --only
  [[ -z "$ONLY" ]] && return 0
  local tag="$1"; IFS=',' read -ra arr <<<"$ONLY"
  for x in "${arr[@]}"; do [[ "$x" == "$tag" ]] && return 0; done
  return 1
}

# ============================================================================ federal guard
federal_live(){
  pgrep -f 'run_federal_chain' >/dev/null 2>&1 && return 0
  pgrep -f 'build_federal_price_panel' >/dev/null 2>&1 && return 0
  pgrep -f -- '--source=comprasnet' >/dev/null 2>&1 && return 0
  return 1
}

# ============================================================================ DRY-RUN
if [[ "$MODE" == "dry" ]]; then
  echo "############################################################"
  echo "#  R1-EXTENDED  --  DRY RUN (no R executed, no files written)"
  echo "############################################################"
  echo "repo            : $REPO"
  echo "v22-editor      : $V22"
  echo "verdicts target : $VERDICTS"
  echo "classifier      : $CLASSIFY  ($( [[ -x $CLASSIFY ]] && echo executable || echo 'NOT +x') )"
  echo "pdftotext       : $(command -v pdftotext >/dev/null 2>&1 && echo available || echo MISSING)"
  echo "/usr/bin/time   : $([[ -x /usr/bin/time ]] && echo available || echo MISSING)"
  if federal_live; then
    echo "FEDERAL CHAIN   : *** LIVE *** (pgrep matched) -> real --run would ABORT until stopped"
  else
    echo "FEDERAL CHAIN   : not detected (safe to --run)"
  fi
  hr
  echo "EXECUTION ORDER (cheapest-first): $ORDER"
  hr
  ndiff_tracked_dirty=0; nmissing_baseline=0; nfiles=0
  for tag in $ORDER; do
    selected "$tag" || continue
    sf="$(manifest_for "$tag" | head -1 | awk -F'|' '{print $2}')"
    echo "### script $tag  ($sf)"
    while IFS='|' read -r TAG SCRIPT REL HINT EXPECT; do
      [[ -z "${TAG:-}" ]] && continue
      nfiles=$((nfiles+1))
      abs="$V22/$REL"
      track=$([[ $(is_tracked "$REL"; echo $?) -eq 0 ]] && echo tracked || echo untrack)
      present=$([[ -e "$abs" ]] && echo present || echo ABSENT)
      dirty=""
      if [[ "$track" == "tracked" ]]; then
        if [[ -n "$(git -C "$REPO" status --porcelain -- "$abs" 2>/dev/null)" ]]; then
          dirty="DIRTY"; ndiff_tracked_dirty=$((ndiff_tracked_dirty+1))
        else dirty="clean"; fi
      fi
      if [[ "$EXPECT" == "baseline" && "$present" == "ABSENT" ]]; then
        nmissing_baseline=$((nmissing_baseline+1))
      fi
      printf '   %-7s %-8s %-8s %-7s %-12s %s\n' "$track" "$present" "$dirty" "$HINT" "$EXPECT" "$REL"
    done < <(manifest_for "$tag")
  done
  hr
  echo "ORPHAN/RENAME report (02b): $ORPHAN_REPORT"
  if [[ -e "$V22/$ORPHAN_REPORT" ]]; then
    echo "   -> orphan PRESENT on disk (old pre-rename name). The refactor writes"
    echo "      *_contact2.csv instead; this old file is NOT rewritten and will persist."
    echo "      Recommend manual removal AFTER R1-EXTENDED passes (no consumer reads it)."
  else
    echo "   -> orphan absent (clean)."
  fi
  hr
  echo "DRY-RUN SUMMARY:"
  echo "  manifest files                : $nfiles"
  echo "  tracked files DIRTY pre-run   : $ndiff_tracked_dirty"
  echo "  baseline files MISSING on disk: $nmissing_baseline"
  if federal_live; then echo "  federal chain                 : LIVE (must stop before real run)"; fi
  echo
  echo "Plan for a real --run (per script, cheapest first):"
  echo "  1. snapshot untracked baselines -> $SNAPDIR"
  echo "  2. git-clean precheck on tracked outputs (abort that script if DIRTY)"
  echo "  3. Rscript <script> --source=bec  under /usr/bin/time -v (log to $LOGDIR)"
  echo "  4. classify each manifest file via $CLASSIFY"
  echo "  5. write $VERDICTS ; auto-restore benign-class ; LEAVE DIFF-class in place"
  echo "  PASS iff zero DIFF and zero vanished."
  exit 0
fi

# ============================================================================ REAL RUN
if federal_live && [[ "$SKIP_FED_CHECK" -eq 0 ]]; then
  echo "ABORT: federal chain appears LIVE (pgrep matched run_federal_chain / build_federal_price_panel)." >&2
  echo "       Stop it before running R1-EXTENDED, or pass --skip-federal-check if you are certain." >&2
  exit 3
fi

[[ -x "$CLASSIFY" ]] || { echo "ABORT: classifier not executable: $CLASSIFY" >&2; exit 4; }
mkdir -p "$LOGDIR" "$SNAPDIR" "$(dirname "$VERDICTS")"
echo "script,file,status,note" > "$VERDICTS"

n_diff=0; n_vanished=0

snap_path(){ printf '%s/%s' "$SNAPDIR" "$1"; }   # $1 = rel path

for tag in $ORDER; do
  selected "$tag" || continue
  SCRIPT="$(manifest_for "$tag" | head -1 | awk -F'|' '{print $2}')"
  echo; hr; echo "### R1-EXTENDED script $tag : $SCRIPT"; hr

  # ---- (a) snapshot untracked baselines + git-clean precheck on tracked --------
  abort_script=0
  while IFS='|' read -r TAG S REL HINT EXPECT; do
    [[ -z "${TAG:-}" ]] && continue
    abs="$V22/$REL"
    if is_tracked "$REL"; then
      if [[ -n "$(git -C "$REPO" status --porcelain -- "$abs" 2>/dev/null)" ]]; then
        echo "  PRECHECK DIRTY (tracked): $REL  -> skipping script $tag check"
        abort_script=1
      fi
    else
      # snapshot the untracked baseline (if present) so we can compare + restore.
      if [[ -e "$abs" ]]; then
        mkdir -p "$(dirname "$(snap_path "$REL")")"
        cp -p "$abs" "$(snap_path "$REL")"
      fi
    fi
  done < <(manifest_for "$tag")

  if [[ "$abort_script" -eq 1 ]]; then
    while IFS='|' read -r TAG S REL HINT EXPECT; do
      [[ -z "${TAG:-}" ]] && continue
      printf '%s,%s,%s,%s\n' "$tag" "$REL" "DIFF" "\"skipped: a tracked output of this script was DIRTY pre-run\"" >> "$VERDICTS"
      n_diff=$((n_diff+1))
    done < <(manifest_for "$tag")
    continue
  fi

  # ---- (b) run the script --source=bec under /usr/bin/time -v ------------------
  tlog="$LOGDIR/${tag}.time.log"; rlog="$LOGDIR/${tag}.run.log"
  echo "  running: Rscript $SCRIPT --source=bec   (log: $rlog ; time: $tlog)"
  ( cd "$ANALYSIS" && /usr/bin/time -v -o "$tlog" \
      Rscript "$ANALYSIS/$SCRIPT" --source=bec ) >"$rlog" 2>&1
  rc=$?
  echo "  exit code: $rc"
  if [[ $rc -ne 0 ]]; then
    echo "  WARNING: script $tag exited non-zero; classifying outputs anyway (tail of run log):"
    tail -5 "$rlog" | sed 's/^/    /'
  fi

  # ---- (c) classify each manifest file -----------------------------------------
  while IFS='|' read -r TAG S REL HINT EXPECT; do
    [[ -z "${TAG:-}" ]] && continue
    abs="$V22/$REL"
    if is_tracked "$REL"; then base=""; else base="$(snap_path "$REL")"; fi

    if [[ "$EXPECT" == "new-expected" ]]; then
      # No baseline expected. Presence OK, absence OK. Never a DIFF.
      if [[ -e "$abs" ]]; then st="new-expected"; note="refactor-added file; present after run (no frozen baseline)"
      else st="new-expected"; note="refactor-added file; not written this run (conditional) -- OK"; fi
      printf '%s,%s,%s,"%s"\n' "$tag" "$REL" "$st" "$note" >> "$VERDICTS"
      continue
    fi

    if [[ "$EXPECT" == "conditional" ]]; then
      if [[ ! -e "$abs" && ( -z "$base" || ! -e "$base" ) ]]; then
        printf '%s,%s,%s,"%s"\n' "$tag" "$REL" "new-expected" "conditional output; not written this run and no baseline -- OK" >> "$VERDICTS"
        continue
      fi
    fi

    if is_tracked "$REL"; then
      # tracked: use git to decide identity; benign hint applies to the diff.
      if [[ -z "$(git -C "$REPO" status --porcelain -- "$abs" 2>/dev/null)" ]]; then
        printf '%s,%s,%s,"%s"\n' "$tag" "$REL" "identical" "git-tracked, working tree clean after run" >> "$VERDICTS"
        continue
      fi
      # changed vs HEAD: materialize HEAD blob to compare via classifier
      bcopy="$(mktemp)"
      if git -C "$REPO" show "HEAD:$(git -C "$REPO" ls-files --full-name "$abs")" >"$bcopy" 2>/dev/null; then
        res="$("$CLASSIFY" "$abs" "$bcopy" "$HINT")"
      else
        res=$'DIFF\tcannot read HEAD blob for tracked file'
      fi
      rm -f "$bcopy"
    else
      # untracked: compare current vs snapshot baseline
      res="$("$CLASSIFY" "$abs" "$base" "$HINT")"
    fi

    st="${res%%$'\t'*}"; note="${res#*$'\t'}"
    printf '%s,%s,%s,"%s"\n' "$tag" "$REL" "$st" "$note" >> "$VERDICTS"
    case "$st" in
      DIFF)     n_diff=$((n_diff+1)) ;;
      vanished) n_vanished=$((n_vanished+1)) ;;
    esac
  done < <(manifest_for "$tag")
done

# ============================================================================ RESTORE
# Auto-restore benign-class diffs so the working tree ends byte-identical to its
# pre-run state. DIFF-class files are LEFT IN PLACE for inspection.
echo; hr; echo "### RESTORE PHASE (benign auto-restore; DIFF-class left in place)"; hr
restored=0; left=0
while IFS=, read -r r_tag r_file r_status r_note; do
  [[ "$r_tag" == "script" ]] && continue
  abs="$V22/$r_file"
  case "$r_status" in
    DIFF|vanished)
      echo "  LEFT for inspection [$r_status]: $r_file"; left=$((left+1)) ;;
    benign-metadata|benign-tokenorder|benign-telemetry|benign-numeric)
      if is_tracked "$r_file"; then
        git -C "$REPO" checkout -- "$abs" 2>/dev/null && { echo "  restored (git): $r_file"; restored=$((restored+1)); }
      else
        b="$(snap_path "$r_file")"
        [[ -e "$b" ]] && cp -p "$b" "$abs" && { echo "  restored (snap): $r_file"; restored=$((restored+1)); }
      fi ;;
    identical|new-expected) : ;;  # nothing to restore
  esac
done < "$VERDICTS"

# ============================================================================ SUMMARY
echo; echo "############################################################"
echo "#  R1-EXTENDED  --  SUMMARY"
echo "############################################################"
column -s, -t "$VERDICTS" | sed 's/^/  /'
hr
echo "  DIFF-class files     : $n_diff"
echo "  vanished files       : $n_vanished"
echo "  benign auto-restored : $restored"
echo "  DIFF left in place   : $left"
echo "  verdicts CSV         : $VERDICTS"
echo "  snapshot baselines   : $SNAPDIR"
hr
# Orphan report
if [[ -e "$V22/$ORPHAN_REPORT" ]]; then
  echo "  ORPHAN (02b rename): $ORPHAN_REPORT still on disk (old pre-rename name)."
  echo "    Safe to remove (no consumer reads it). Suggested: rm \"$V22/$ORPHAN_REPORT\""
fi
hr
if [[ "$n_diff" -eq 0 && "$n_vanished" -eq 0 ]]; then
  echo "  VERDICT: PASS  (BEC byte-identity holds for all 8 ported scripts;"
  echo "                  all diffs benign; working tree restored to pre-run state)."
  rm -rf "$SNAPDIR"
  exit 0
else
  echo "  VERDICT: FAIL  ($n_diff DIFF + $n_vanished vanished). DIFF-class files left in place."
  echo "  Inspect, then restore the working tree manually with:"
  awk -F, 'NR>1 && ($3=="DIFF"||$3=="vanished"){print $2}' "$VERDICTS" | while read -r f; do
    if is_tracked "$f"; then echo "    git checkout -- \"$V22/$f\""
    else echo "    cp -p \"$SNAPDIR/$f\" \"$V22/$f\"   # from snapshot baseline"; fi
  done
  exit 1
fi
