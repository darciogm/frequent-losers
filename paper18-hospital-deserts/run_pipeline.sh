#!/usr/bin/env bash
# run_pipeline.sh
#
# Orchestrates the analysis pipeline for paper18 end-to-end.
# Replication-friendly: each step is idempotent (output detection +
# --force flag) so re-running this script will skip steps whose
# outputs already exist.
#
# Usage:
#   ./run_pipeline.sh                 # full pipeline
#   ./run_pipeline.sh --from 20       # restart from script 20
#   ./run_pipeline.sh --to 17d        # stop after 17d
#
# Requires: conda env "paper18" activated, ANTHROPIC_API_KEY set
# (only needed for steps 28, 28d which call the LLM classifier).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

# ---- argparse ----
FROM_STEP=""
TO_STEP=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from) FROM_STEP="$2"; shift 2 ;;
    --to)   TO_STEP="$2"; shift 2 ;;
    -h|--help)
      grep '^#' "$0" | head -25
      exit 0 ;;
    *) echo "unknown arg: $1"; exit 1 ;;
  esac
done

# ---- pipeline order ----
# Each entry: "id|interpreter|script_path|description"
declare -a STEPS=(
  # ---- ingest (00–05): population, GDP, CNES habilitations, centroids ----
  "00|python|03_analysis/00_download_pop_2022_2024.py|Download IBGE pop 2022-2024"
  "00b|python|03_analysis/00b_consolidate_pop_panel.py|Consolidate pop panel 2015-2025"
  "00c|python|03_analysis/00c_download_pib_municipal.py|Download IBGE municipal GDP"
  "00d|python|03_analysis/00d_download_cnes_hb.py|Download CNES HB (habilitations)"
  "00d2|python|03_analysis/00d2_patch_cnes_hb.py|Patch CNES HB"
  "00e|python|03_analysis/00e_download_cnes_pf.py|Download CNES PF"
  "01|python|03_analysis/01_build_hospital_universe.py|Hospital universe master"
  "02|python|03_analysis/02_build_amenable_mortality.py|Amenable mortality (Nolte-McKee)"
  "03|python|03_analysis/03_build_bipartite_graph.py|Bipartite mun-hosp graph"
  "04|python|03_analysis/04_build_hospital_habilitations.py|Hospital habilitations"
  "05|python|03_analysis/05_compute_centroids.py|Municipality centroids"
  # ---- embedding + cross-section diagnostics (06–16) ----
  "06|python|03_analysis/06_train_node2vec.py|Train node2vec bipartite"
  "06b|python|03_analysis/06b_train_node2vec_proj.py|Train node2vec M-M projection"
  "07|python|03_analysis/07_evaluate_embeddings.py|Cross-section eval (amenable mort)"
  "07b|python|03_analysis/07b_evaluate_hospital_iso.py|Hospital isolation eval"
  "08|python|03_analysis/08_map_divergence.py|Divergence map figure"
  "09|python|03_analysis/09_divergence_regression.py|Divergence regression"
  "10|python|03_analysis/10_robustness.py|Embedding robustness"
  "11|python|03_analysis/11_make_tables.py|Make legacy tables"
  "12|python|03_analysis/12_make_robustness_figure.py|Robustness figure (legacy)"
  "13|python|03_analysis/13_make_regional_map.py|Regional map"
  "14|python|03_analysis/14_make_tsne_umap.py|t-SNE/UMAP figures"
  "15|python|03_analysis/15_r99_hypothesis_test.py|R99 hypothesis test"
  "16|python|03_analysis/16_make_uf_ranking_table.py|UF ranking table"
  # ---- cause-specific & alt outcomes (17 family) ----
  "17|python|03_analysis/17_build_cause_specific_outcomes.py|Cause-specific mortality panel"
  "17b|python|03_analysis/17b_evaluate_cause_specific.py|Eval cause-specific (Δ R²)"
  "17c|python|03_analysis/17c_build_alt_outcomes.py|Build alt outcomes panel"
  "17d|python|03_analysis/17d_evaluate_alt_outcomes.py|Eval alt outcomes (Δ R²)"
  # ---- closure event identification (S1-S5) ----
  "20|python|03_analysis/20_filter_exogenous_closures.py|Filter exogenous closures (60)"
  "21|python|03_analysis/21_define_exposure.py|Define E1/E2 exposures"
  "22|python|03_analysis/22_build_travel_burden.py|Travel burden outcome"
  "23|python|03_analysis/23_build_icsap_panel.py|ICSAP panel outcome"
  "24a|python|03_analysis/24a_build_staggered_panel.py|Build staggered panel"
  "24b|R|03_analysis/24b_event_study_cs21.R|Pilot CS21 event-study"
  "25|R|03_analysis/25_pilot_robustness.R|Pilot robustness (heterogeneity)"
  # ---- R1 NLP-documented exogeneity ----
  "26|python|03_analysis/26_extract_closure_metadata.py|Extract closure metadata"
  "27|python|03_analysis/27_lookup_cnpj.py|CNPJ lookup via BrasilAPI (cached)"
  "28|python|03_analysis/28_classify_motives.py|Haiku classification v1 (cached)"
  "28b|python|03_analysis/28b_generate_queries.py|Generate WebSearch queries"
  "28d|python|03_analysis/28d_classify_with_web.py|Sonnet classification v2 (cached)"
  # ---- final estimation, robustness, ML attribution ----
  "29|python|03_analysis/29_build_final_panels.py|Build final 5 panels (F5/F6/admin/...)"
  "30|R|03_analysis/30_event_study_final.R|Sun-Abraham final hybrid event-study"
  "31|R|03_analysis/31_causal_forest.R|Causal forest heterogeneity"
  "32b|python|03_analysis/32b_perturbation_with_noise.py|Counterfactual perturbation"
  "33|R|03_analysis/33_event_study_with_perturbation.R|ES with perturbation exposure"
  "34|R|03_analysis/34_robustness_battery.R|Robustness battery (S6, 18 specs)"
  "35|R|03_analysis/35_sa_vs_bjs_compare.R|SA vs BJS event-study comparison"
  "36|python|03_analysis/36_cross_section_null_figure.py|Cross-section null figure"
  # ---- AEJ:Policy restructure: mortality gate, PNASH power, pop backfill, outputs ----
  # D1 builds psychiatric outcomes + spec07 panel; D2 runs the pre-trend gate
  # (diagnostic readout); D3 builds the PNASH-expanded closure panels; D4
  # backfills population 2010-2014 and rebuilds the *_ext panels with observable
  # pre-periods; D5 emits the mortality-null table + figures; D6 regenerates
  # values.tex (the single source of truth for every manuscript number).
  # Run D1->D3->D4 in order (D4 depends on D1+D3); D5/D6 read the *_ext panels.
  "D1|python|03_analysis/D1_build_psych_gate.py|Psychiatric outcomes (SIM/SIH) + spec07 panel"
  "D2|R|03_analysis/D2_psych_gate.R|Pre-trend gate on psychiatric outcomes (diagnostic)"
  "D3|python|03_analysis/D3_pnash_power.py|PNASH power: pnash48 + psymax60 closure panels"
  "D4|python|03_analysis/D4_extend_pop_rebuild.py|Backfill pop 2010-14, rebuild *_ext panels"
  "49|python|03_analysis/49_audit_project_state.py|Revision audit: repo/manuscript/data/output map"
  "50|python|03_analysis/50_build_master_sample_table.py|Revision audit: master samples + PNASH event diagnostics"
  "51|python|03_analysis/51_build_exposure_variants.py|Revision audit: exposure variants and diagnostics"
  "61|python|03_analysis/61_resolve_remaining_data_caveats.py|Revision audit: resolve local data caveats"
  "52|python|03_analysis/52_revision_measurement_diagnostics.py|Revision audit: distance, decomposition, spillover, LLM diagnostics"
  "53|R|03_analysis/53_raw_means_revision.R|Revision robustness: raw means"
  "54|R|03_analysis/54_fe_sensitivity_revision.R|Revision robustness: FE sensitivity"
  "55|R|03_analysis/55_mortality_scaling_mde_revision.R|Revision robustness: mortality scaling and MDE"
  "56|R|03_analysis/56_heterogeneity_dependence_revision.R|Revision robustness: dependence heterogeneity"
  "57|R|03_analysis/57_postpandemic_exclusion_revision.R|Revision robustness: post-pandemic closure exclusion"
  "58|R|03_analysis/58_honestdid_mortality_revision.R|Revision robustness: HonestDiD mortality sensitivity"
  "59|R|03_analysis/59_exposure_distance_variant_eventstudies.R|Revision robustness: exposure/distance variant event studies"
  "60|R|03_analysis/60_leave_one_closure_out_revision.R|Revision robustness: leave-one-closure-out inference"
  "66|R|03_analysis/66_anticipation_renorm.R|ID hardening: anticipation re-normalization (e=-2,-3)"
  "67|R|03_analysis/67_illdefined_placebo.R|ID hardening: R96-R99 ill-defined-cause placebo"
  "68|R|03_analysis/68_goodman_bacon.R|ID hardening: Goodman-Bacon decomposition of TWFE"
  "69a|python|03_analysis/69_recipient_control_spillover.py|ID hardening: recipient-control flow construction (DuckDB)"
  "69|R|03_analysis/69_recipient_control_spillover.R|ID hardening: recipient-control spillover bound"
  "70a|python|03_analysis/70a_build_lococor.py|ID hardening: build LOCOCOR place-of-occurrence counts"
  "70|R|03_analysis/70_lococor_displacement.R|ID hardening: mechanical death-displacement check"
  "71|R|03_analysis/71_id_hardening_figures.R|ID hardening: appendix event-study figures (spillover, displacement)"
  "75|R|03_analysis/75_psych_admissions_result.R|Featured result: inpatient psychiatric admissions event study + figure"
  "76|R|03_analysis/76_synthetic_control_leg.R|ID design: synthetic-DiD second identification leg (suicide null)"
  "77|R|03_analysis/77_doubly_robust_selection.R|ID design: doubly-robust CS + selection-into-timing test"
  "78|R|03_analysis/78_triple_difference_placebo.R|ID check (negative): triple-difference vs placebo cause (inconclusive)"
  "79|R|03_analysis/79_reimbursement_bartik.R|ID check (negative): reimbursement-exposure Bartik first stage (weak, dropped)"
  "80|R|03_analysis/80_spec_curve.R|Presentation: specification curve for the suicide ATT (consolidates robustness)"
  "81|R|03_analysis/81_pnash_strict_window.R|ID upgrade: strict exact +/-1yr PNASH-window robustness (37 closures)"
  "82|python|03_analysis/82_enrich_pnash_event_level.py|ID upgrade: closure-level PNASH event table (audit all 48 events)"
  "83|R|03_analysis/83_preclosure_timing_tests.R|ID upgrade: pre-closure timing-predictor tests"
  "84|R|03_analysis/84_honestdid_sensitivity.R|ID upgrade: HonestDiD reconciled to headline + ICSAP placebo"
  "85|R|03_analysis/85_sdid_full.R|ID upgrade: fully-documented synthetic DiD (suicide + self-harm + diagnostics)"
  "86|R|03_analysis/86_caps_heterogeneity.R|ID upgrade: baseline-CAPS heterogeneity / outpatient-substitution limit"
  "87a|python|03_analysis/87a_build_distinct_spillover_flags.py|ID upgrade: build genuinely distinct contamination flags"
  "87|R|03_analysis/87_spillover_distinct_flags.R|ID upgrade: de-aliased spillover sensitivity table"
  "88|python|03_analysis/88_psych_displacement_decomposition.py|Mechanism: psychiatric displacement decomposition (where inpatient use goes)"
  "90|python|03_analysis/90_build_other_hosp_psych_panel.py|Mechanism: build other-hospital psychiatric admissions panel"
  "91|R|03_analysis/91_other_hosp_event_study.R|Mechanism: causal event study of non-absorption by other hospitals"
  "94|R|03_analysis/94_network_spillover_sutva.R|Mechanism: network co-patiency spillover/SUTVA robustness of the suicide null"
  "95|python|03_analysis/95_build_disagreement_groups.py|Exposure validation: disagreement groups"
  "96|R|03_analysis/96_estimate_disagreement_placebo.R|Exposure validation: disagreement-placebo event studies"
  "97|python|03_analysis/97_fig_disagreement_first_stage.py|Exposure validation: disagreement first-stage figure"
  "63|python|03_analysis/63_closure_sample_architecture.py|Closure-sample architecture: F5 measurement, PNASH causal, contrast and diagnostics"
  "64|R|03_analysis/64_estimate_first_stage_by_sample.R|First-stage travel burden by closure sample"
  "65|python|03_analysis/check_sample_consistency.py|Sample consistency audit"
  "D5|R|03_analysis/D5_make_mortality_results.R|Mortality-null table + event-study figures"
  "62|python|03_analysis/62_format_legacy_tables.py|Format legacy LaTeX tables"
  "D6|R|03_analysis/D6_make_values.R|Generate values.tex (single source of truth)"
  "D7|R|03_analysis/D7_inference.R|UF-cluster + randomization inference on suicide null"
  "72|python|03_analysis/72_jhe_submission_tables.py|JHE package: balance, PNASH timing, variants, bounds, influence"
  "73|R|03_analysis/73_jhe_spillover_sensitivity.R|JHE package: network spillover mortality sensitivity"
  "74|python|03_analysis/74_jhe_compression_package.py|JHE final compression tables and online appendix support"
  "65b|python|03_analysis/check_sample_consistency.py|Final sample consistency audit"
)

# ---- run ----
SECONDS_TOTAL=0
SKIP=0
RUN_NOW=0
[[ -z "$FROM_STEP" ]] && RUN_NOW=1

for entry in "${STEPS[@]}"; do
  IFS='|' read -r ID INTERP SCRIPT DESC <<< "$entry"

  # --from gating
  if [[ -n "$FROM_STEP" && "$ID" == "$FROM_STEP" ]]; then RUN_NOW=1; fi
  if [[ "$RUN_NOW" -eq 0 ]]; then continue; fi

  echo
  echo "============================================================"
  echo "[$ID] $DESC"
  echo "============================================================"
  T0=$SECONDS
  case "$INTERP" in
    python)
      if command -v python >/dev/null 2>&1; then
        python "$SCRIPT"
      else
        python3 "$SCRIPT"
      fi ;;
    R)      Rscript "$SCRIPT" ;;
    *)      echo "unknown interpreter $INTERP for $ID"; exit 1 ;;
  esac
  ELAPSED=$((SECONDS - T0))
  echo "[$ID] done (${ELAPSED}s)"

  # --to gating
  if [[ -n "$TO_STEP" && "$ID" == "$TO_STEP" ]]; then break; fi
done

echo
echo "============================================================"
echo "pipeline complete"
echo "============================================================"
