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
  "D5|R|03_analysis/D5_make_mortality_results.R|Mortality-null table + event-study figures"
  "D6|R|03_analysis/D6_make_values.R|Generate values.tex (single source of truth)"
  "D7|R|03_analysis/D7_inference.R|UF-cluster + randomization inference on suicide null"
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
    python) python "$SCRIPT" ;;
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
