# 03 — EMPIRICAL OUTPUT REGISTRY (JLEO R&R v22)

Maps current outputs → revised outputs needed. Paths relative to `paper3-frequent-losers/`.
Status: ✅ exists+run · 🟧 exists, needs extend/rebind · ⬜ to create · ⛔ blocked.
**Rule:** never hand-edit generated tables/figures; regenerate from script and `\input` or macro-bind.

---

## A. Main-text TABLES

| Output | Current path | Revised path | Manuscript dest | Data level | Main vars needed | Generating script | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| **Table A — Label funnel & sample reconciliation** | `output/label_funnel/funnel.csv` (RUN) | inline tab | sec04 §4.1 (`tab:label_funnel`) | case/firm | case_id, defendant CNPJ, cobidder CNPJ, is_FL, always_loser, data_julgamento | `79_label_funnel.R` ✅ | 🟧 | **RUN 2026-06-02.** 12→41→341 (main 193 NOT reproduced; cons 208≈210/107≈108 ✓). U2 decision gates final form. Also emits `case_cobidder_map.csv` (LOCO) + `case_timing.csv` (Table G) |
| **Table B — Opportunity-adjusted validation** | `output/exposure_adjusted_audit/auc_summary.csv` | same (+PR cols) | sec04 §4.2 (`tab:exposure_adjusted`) | firm (always-loser) | cobidder, fl14, log_tc, n_opp_items, opp_decile | `76_exposure_adjusted_audit.R` | 🟧 | RUN. within-AUC 0.7715; incr +0.0415; exp-only 0.946. Add PR-AUC |
| **Table C — Timing & leave-one-case-out** | `output/strict_train_threshold/strict_train_threshold.csv`; `output/reverse_causality_timing/*` | + `output/loco/` | sec04 §4.3 (`tab:timing_loco`) | firm / firm-year / case | frozen-train threshold, AUC, year_hhi, Δshare, LOCO-AUC | `53`,`77` (run) + NEW `80_leave_one_case_out.R` | ⛔ | 53/77 run; LOCO blocked on CP-1. Timing verdict = FAIL (disclose) |
| **Table D — Cost-recall frontier** | `output/architecture_gatekeeper/precision_at_k.csv` (53/63 trees) | `output/regulatory_frontier/*` (EMPTY) | sec06 §6.4 (`tab:gatekeeper_submission` replace) | firm/cell | K1, cost denominator, recall, precision, FP, FN | `56_regulatory_cost_frontier.R` (NOT RUN); `63`,`64` | ⛔ | RUN 56; extend 63 to K1×cost grid. Replaces hard-typed sec06 cells |
| **Table E — Bid-layer benchmark audit** | `output/imhof_incremental/`; `tab:imhof_cost_submission` | + missingness cols | sec06 §6.1-6.2 (`tab:imhof_cost_submission`) | bid/item | Imhof features, learner, CV scheme, missingness, holdout AUC | `31`,`49`,`26` | 🟧 | Document features/CV/leakage controls |
| **Table F — Unit-of-analysis table** | — | inline | sec02 (`tab:unit_of_analysis`) | meta | level, file, N, key | hand-built from `00_REPO_AUDIT §C` + `01_clean.R` | ⬜ | Pure documentation |
| **Table G — CADE case timing** | — | `output/label_funnel/case_timing.csv` | sec02 §2.3 (`tab:cade_case_timing`) | case | numero_processo, data_julgamento, setor, n_defendants | NEW `79` (or split) | 🟧 | Judgment dates only; 9/12 dated, 3 NaT — disclose |

Existing main-text tables to KEEP/revise (already inline, see manuscript map): `tab:testable_implications_submission`, `tab:populations_submission`, `tab:three_classifier_submission`, `tab:scope_matrix_submission`, `tab:validation_benchmarks_submission`, `tab:cobidder_signature_submission`, `tab:price_imprint_submission`, `tab:sign_reversal_decomposition_submission`, `tab:price_scope_submission`.

## B. APPENDIX tables

| Output | Current path | Manuscript dest | Level | Script | Status | Notes |
|---|---|---|---|---|---|---|
| Participation-bin monotonicity | `output/auc_subsample.csv`; `threshold_table_q3iqr.csv` | App D | firm | `26`,`54` | 🟧 | Add observed-vs-expected by bin |
| Exposure-cell construction | `output/exposure_adjusted_audit/firm_panel.csv` | App C/D | firm | `76` | ✅ | Document cell = PBU×year×item-group |
| Exposure-adjusted permutation | `output/sham_auc_distribution.csv` | App D.1 | firm | `25_sham_fl_permutation.R` | ✅ | seed 20260430 |
| Strict-timing robustness | `output/strict_train_threshold/*` | App D | firm/item | `53` | ✅ | binary>cont flip |
| Leave-largest-case-out | `output/loco/` | App D | case | NEW `80` | ⛔ | CP-1 dep |
| Price scope | `tab:price_scope_submission` (inline) | App E | item/segment | `59`,`51`,`52` | 🟧 | theater-not-identified |
| Survival / hazard | `output/survival/` | App B | firm-year | NEW `81_survival_hazard.R` | ⛔ | exit censored 2019 |
| Bid-feature missingness | `output/imhof_incremental/` | App G | bid | `49` | ⬜ | new missingness table |
| Gatekeeping algorithm params | `output/architecture_gatekeeper/*` | App G | firm | `63` | 🟧 | K1, K2, cost params |
| Year-by-year holdout AUC | `output/auc_summary.csv` (17); app03 inline | App D.4 | firm | `17_temporal_holdout_roc.R` | 🟧 | **hard-typed in app03:223-228 — macro-bind** |
| Leakage audit | `output/leakage_audit_d3.csv` | App D.3 | firm/item | `40` | ✅ | seed 20260430 |

## C. FIGURES

| Output | Current path | Manuscript dest | Script | Status | Notes |
|---|---|---|---|---|---|
| Observed-vs-expected defendant contact by participation bin | — | sec04 §4.2 | NEW (from `76` firm_panel) | ⬜ | core exposure visual |
| PR / lift curves | `output/figures/fig_pr_curve.pdf` | sec06 §6.3 | `42` | 🟧 | replace ROC headline |
| Rolling-origin validation | `output/figures/fig_temporal_holdout_roc.pdf` (in submission) | sec04 (already `\includegraphics`) | `17`/`make_submission_figures.R` | ✅ | values hardcoded in make script |
| Leave-one-case-out distribution | — | sec04 §4.3 | NEW `80` | ⛔ | CP-1 dep |
| Cost-recall frontier | `fig_regulatory_frontier.pdf` | sec06 §6.4 | `56` | ⛔ | **MISSING — script 56 not run** |
| Cobidder prevalence by participation-count bin | `output/figures/fig_threshold_heatmap_2d.pdf` (rel) | App C/D | `18`,`26` | 🟧 | reuse/extend |
| Survival / Kaplan-Meier | — | App B | NEW `81` | ⛔ | feasibility partial |
| Price scope segment | `output/figures/fig_segment_betas.pdf` | App E | `61_segment` | ✅ | exists |
| Data-coarsening diagram (Fig 1) | `output/figures/fig_data_coarsening.pdf` (in submission) | sec02 (already `\includegraphics`) | `58`/`make_submission_figures.R` | ✅ | relabel "lost/survives"→"routine/costly-recovered" (#15) |

## Run-artifact snapshot (verified 2026-06-02, from May 30 runs)
- **76** auc_summary.csv: unconditional fl14 0.9236 / log_tc 0.9386; exposure-only 0.9462; exposed-only fl14 0.8417 / log_tc 0.8635; **within-opp-stratum log_tc 0.7715 / fl14 0.7709**; logit exposure-only 0.8467 → +score 0.8882 (**+0.0415, DeLong Z=−4.745 p=2.08e-06**); CEM-opp-matched log_tc 0.8628. n=16,843, npos=191.
- **77** concentration: cobidders year_hhi 0.553 vs ctrl 0.727 (**d=−0.661 p=5e-19**), n_active_years 3.62 vs 2.40 (d=+0.674), span 4.41 vs 2.95, peak_share 0.647 vs 0.791. Event study mean_part jumps tau=−1 7.30 → tau=0 25.27. **Verdict: sincere persistence NOT ruled out.**
- **78** bidder_decomp: winner_vs_ref~losers = −0.0479; +genuine+FL → l_gen=−0.137 (se .003), l_fl=+0.0258 (se .020, ~ns), losers=−0.0346. **Theater not identified.**
- **53** strict_train: firm AUC binary **0.767** [0.734,0.800] > continuous **0.750** [0.706,0.795]; threshold frozen on 09-16 = **7** (vs full-sample 13.5); item 2017-19 cont AUC 0.770. npos=193.
- **EMPTY:** `output/regulatory_frontier/` (script 56). **MISSING:** `fig_regulatory_frontier.pdf`.

## Macro-binding discipline (for `values.tex`, hand-edit with `% src:`)
New macros to bind: `\valExpWithinAUC`(0.7715), `\valExpExpOnlyAUC`(0.946), `\valExpIncrement`(0.0415), `\valExpDeLongP`(2.08e-06), `\valExpExposedFLAUC`(0.842), `\valTimingYearHHIcob`(0.553), `\valTimingYearHHIctrl`(0.727), `\valTimingD`(−0.66), `\valStrictBinAUC`(0.767), `\valStrictContAUC`(0.750), `\valStrictThreshTrain`(7), `\valBidderDecompGen`(−0.137), `\valBidderDecompFL`(0.026). Retire/replace: `\valConservativeCobidders`(210), `\valConservativeFD`(30), conservative-FL(108) pending CP-1.

---

## Machine-readable registries (Subprompt 2, 2026-06-02)

The narrative tables above are now mirrored by **script-generated CSV registries** (no manual spreadsheet):

- **`work/v22-editor/outputs/output_registry.csv`** — 24 rows, all required `output_id`s (MAIN_*, APP_*, FIG_*). Columns: `output_id, output_name, output_type, manuscript_destination, current_path, revised_path, generating_script, data_inputs, data_level, primary_metrics, status, last_generated, notes`. Status ∈ {existing_current, planned, blocked→noted, implemented, deprecated}. Current split: **13 existing_current / 11 planned**.
- **`work/v22-editor/outputs/dataset_registry.csv`** — 13 datasets (firm/firm-year/tender-item/firm-item/bid/case levels). Large parquets marked `not_checked_large_file`.
- **Generator:** `work/v22-editor/scripts/build/make_registries.R` (run via `make audit`). Deterministic; regenerate any time.

### Directory mapping (preferred structure → existing convention)
The subprompt's preferred `outputs/tables/{main,appendix}`, `outputs/figures/{main,appendix}`, `outputs/{logs,diagnostics,cache,manuscript}` were created under **`work/v22-editor/`**. Existing **canonical analysis outputs were NOT moved** — they remain at `paper3-frequent-losers/output/<module>/` and are referenced by the `current_path` column of `output_registry.csv`. The v22 `outputs/tables/` and `outputs/figures/` hold the revision LaTeX/PDF deliverables assembled from those analysis CSVs.

### Existing vs planned vs blocked (from output_registry.csv)
- **existing_current (run, artifacts present):** MAIN_LABEL_FUNNEL, MAIN_OPPORTUNITY_ADJUSTED_VALIDATION, MAIN_TIMING_CASE_HOLDOUT (53/77 parts), MAIN_CADE_CASE_TIMING, APP_EXPOSURE_CELL_CONSTRUCTION, APP_EXPOSURE_PERMUTATION, APP_STRICT_TIMING_ROBUSTNESS, APP_PRICE_SCOPE (78 part), APP_GATEKEEPING_PARAMETERS, FIG_ROLLING_ORIGIN_VALIDATION, FIG_PRICE_SCOPE_SEGMENTS, FIG_COBIDDER_PREVALENCE_BINS, FIG_PR_LIFT_CURVES.
- **planned/blocked:** MAIN_COST_RECALL_FRONTIER (run script 56 — `output/regulatory_frontier/` EMPTY), MAIN_BID_BENCHMARK_AUDIT (document features), MAIN_UNIT_OF_ANALYSIS (build), APP_LEAVE_LARGEST_CASE_OUT + FIG_CASE_HOLDOUT_DISTRIBUTION (NEW script 80 — linkage ready via case_cobidder_map.csv), APP_SURVIVAL_HAZARD + FIG_SURVIVAL_KM (NEW script 81 — exit censored at 2019), APP_BID_FEATURE_MISSINGNESS (build), FIG_OBSERVED_EXPECTED_CONTACT (build from script 76 firm_panel), FIG_COST_RECALL_FRONTIER (run 56).

---

## Subprompt 4 outputs registry update (2026-06-03)
- **MAIN_LABEL_FUNNEL → IMPLEMENTED.** Script `work/v22-editor/scripts/analysis/01_label_funnel_reconciliation.R` (extends `scripts/79_label_funnel.R`). Outputs: `outputs/tables/main/table_A_label_funnel.{csv,tex}` (→ inline Table 3 in sec04), `outputs/tables/main/table_B_case_timing_and_benchmark_use.{csv,tex}` (→ inline Table B App C), `outputs/diagnostics/{label_count_reproduction,cobidder_set_comparison_193_vs_210,cobidder_set_comparison_summary,label_funnel_assertions,label_funnel_new_macros}.{csv,tex}`, `outputs/figures/main/fig_label_funnel.pdf`, `outputs/logs/label_funnel_reconciliation.log`.
- **MAIN_CADE_CASE_TIMING (Table G/B) → IMPLEMENTED** (Table B in App C).
- New reproducible macros bound in values.tex: `\valFunnelFLcobBroad`(341), `\valFunnelALcobBroad`(651), `\valFunnelConsALcob`(208), `\valFunnelConsFLcob`(107), `\valFunnelConsFD`(19), `\valFunnelDirectActiveFTM`(41), `\valFunnelDefItems`(52013), `\valFunnelStaticOverlap`(149), `\valFunnelStaticTarget`(193). Rebound: ConservativeFD 30→19, ConservativeCobidders 210→208, ConservativeFL 108→107.
- Not reproducible from label-funnel objects (flagged, not fabricated): 65 legal roster (empty CNPJ col in rulings CSV), 16,779 Imhof common-support (scripts 31/49), 11,676 gatekeeping pool (scripts 63/64).

---

## Subprompt 5 outputs (Opportunity-adjusted validation, 2026-06-03)
Script: `work/v22-editor/scripts/analysis/02_opportunity_adjusted_validation.R` (extends 76; utils exposure_validation.R + metrics_triage.R; seed 20260603). Reproduces ALL of script 76 exactly (exposure-only 0.946; within-stratum 0.771; +0.042 DeLong p=2.08e-6).
- Main tables: `outputs/tables/main/table_C_opportunity_adjusted_validation.{csv,tex}` (→ inline Table in §4.3), `table_D_opportunity_permutation_validation.{csv,tex}` (→ inline §4.3).
- Appendix tables: `outputs/tables/appendix/{table_D_opportunity_cell_construction, table_D_observed_expected_by_score_bins, table_D_matched_opportunity_validation, table_D_control_function_validation_full}.*`.
- Figures: `outputs/figures/main/{fig_observed_vs_expected_contact_bins, fig_opportunity_permutation_pr_auc}.pdf`; `outputs/figures/appendix/{fig_excess_contact_by_score_bins, fig_opportunity_permutation_precision_at_k}.pdf` (all copied into submission_clean/output/figures/).
- Cache: `outputs/cache/{firm_opportunity_adjusted_frame, opportunity_permutation_metrics}.csv` (anon firm_id, NO raw CNPJ).
- Diagnostics: `outputs/diagnostics/{observed_defendant_contact_summary, opportunity_cell_sparsity, opportunity_common_support, opportunity_case_buyer_contribution}.csv`; `claims_scan_after_opportunity_validation.csv`.
- values.tex: +20 `\valExp*` macros (each src-tagged). App D uses CSV-matched literals (minor follow-up: swap to macros).
- Data note: 1 firm (NEW HOPE) miscoded in BOTH crossmatch (defendant) and 193 cobidders — excluded from defendant set (a firm cannot be its own contact); direct defendants used = 46; npos stays 191.

---

## Subprompt 6 outputs (Timing & case-holdout, 2026-06-03)
Scripts: `scripts/analysis/03_timing_case_holdout_validation.R` (timing/rolling/leakage/direct-defendant; reproduces 53's 0.767/0.750 + 33's 0.491) and `04_case_holdout_dominance.R` (LOCO/leave-largest/dominance/clustered-RI; seed 20260603).
- Main tables: `outputs/tables/main/{table_D_strict_2009_2016_to_2017_2019, table_E_rolling_origin_validation, table_F_leakage_audit, table_G_leave_one_case_out_validation, table_H_case_dominance_validation, table_I_timing_case_holdout_validation}.{csv,tex}`.
- Appendix tables: `outputs/tables/appendix/{table_D_environment_dominance, table_D_clustered_randomization_inference, table_D_leave_one_defendant_group_out, table_D_direct_defendant_timing_scope_check}.csv`.
- Figures: main fig_rolling_origin_pr_auc (NEW Fig 2), fig_rolling_origin_precision_recall, fig_leave_one_case_out_distribution; appendix fig_rolling_origin_auc, fig_case_positive_concentration, fig_clustered_randomization_inference.
- Diagnostics: strict_holdout_composition, case_dominance_summary, environment_dominance_summary, case_topk_coverage; claims_scan_after_timing_case_holdout.csv. Caches: clustered_ri_metrics.csv.
- Docs: timing_information_sets.md. values.tex +19 `\valStrict*/\valLOCO*/...` macros.

---

## Subprompt 7 outputs (Section 5 profile, 2026-06-03)
Scripts: `scripts/analysis/05_section5_profile_monotonicity.R` (groups, Table J/K/L/M, std-diffs, monotonicity; seed 20260603) + `06_section5_robustness.R` (thresholds/bunching, ordinary-loser Table N, market-zero-win, negative controls; seed 20260603).
- Main tables: `outputs/tables/main/{table_J_economic_profile, table_K_opportunity_adjusted_profile, table_L_monotonicity_bins, table_M_binary_vs_continuous_score, table_N_ordinary_loser_alternatives}.{csv,tex}`.
- Appendix tables: `outputs/tables/appendix/{table_E_section5_group_counts, table_E_standardized_profile_differences, table_E_placebo_thresholds, table_E_market_specific_zero_win_definitions, table_E_market_specific_zero_win_validation, table_E_negative_controls}.*`.
- Figures: main {fig_profile_standardized_differences, fig_cobidder_prevalence_by_participation_bin, fig_excess_contact_by_participation_bin}; appendix {fig_threshold_sensitivity, fig_threshold_bunching_T14, fig_negative_control_distribution}.
- Diagnostics: monotonicity_score_deciles, monotonicity_topk, threshold_bunching_T14, ordinary_loser_proxy_stats, leave_one_item_group_out, section5_*_audit_log; claims_scan_after_section5.csv. memo: binary_vs_continuous_score_memo.md.
- Manuscript: sec05 rewritten 5.1–5.6; NEW Appendix H (sec_app08_profile + \input in master); values.tex +19 \valProf* macros. NOT_OBSERVED: tender value, distance-to-winner, geography, later-wins.

---

## Subprompt 8 outputs (Section 6A bid benchmark, 2026-06-03)
Scripts: `scripts/analysis/{07_bid_feature_audit, 08_bid_benchmark_reproduction, 09_bid_benchmark_validation}.R` (seed 20260603; reuse pipeline scripts 31/49). Data `v3/data/processed/bid_level_with_prices.parquet`.
- Main tables: `outputs/tables/main/{table_O_bid_feature_support, table_P_bid_benchmark_model_audit, table_Q_bid_layer_performance, table_R_award_bid_complementarity, table_S_bid_layer_leakage_audit}.{csv,tex}`.
- Appendix tables: `outputs/tables/appendix/{table_F_bid_feature_dictionary, table_F_bid_feature_missingness, table_F_bid_model_calibration}.*`.
- Figures: main {fig_award_bid_pr_curves, fig_award_bid_rank_overlap}; appendix {fig_award_bid_score_scatter, fig_bid_model_calibration}. Fig 1 regenerated (AUC annotations removed).
- Cache: bid_benchmark_predictions, imhof_firm_features(.parquet/_excl_label), imhof_tender_features. Diagnostics: bid_benchmark_{number_reproduction, fold_audit, loco_per_case, error_analysis}, bid_feature_support_diagnostics; claims_scan_after_section6a_bid_benchmark.csv.
- Docs: bid_pipeline_inventory.md, bid_layer_unit_definitions.md, bid_benchmark_model_audit.md.
- Manuscript: sec06 §6.1 revised; NEW Appendix I (sec_app09_bid_benchmark, I.1–I.10) + \input in master; values.tex +18 \valBid* macros (reuse \valImhof* for pooled). Fig 1 (make_submission_figures.R) AUCs removed.
