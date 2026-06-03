# 13 — SUBPROMPT 5 LOG: Opportunity-adjusted validation (JLEO R&R v22)

Date: 2026-06-03. Agent: mr-frequent-losers. Branch: **`v22`** (R&R revision branch; Subprompts 1–4 committed here — staying on it, documented; not creating `rr_jleo_opportunity_validation`). Paper3 v22-editor tree clean at start (only unrelated paper1/2/18 + stale v6/v7/v12–v18 dirt, untouched).

## SETUP / label-funnel gate
Docs 00–12 + `label_reconciliation_memo.md` + `unit_definitions_label_funnel.md` present. **Label funnel RESOLVED (Subprompt 4, verdict RECONCILED)** → NOT `OPPORTUNITY_VALIDATION_BLOCKED_BY_LABEL_FUNNEL`. Proceed.

## THE LOCKED CORE (script `76_exposure_adjusted_audit.R`, run; `output/exposure_adjusted_audit/auc_summary.csv`)
n=16,843 always-losers, npos=191 cobidders (all exposed).
- Unconditional: fl14 AUC **0.9236**, log_tc **0.9386**.
- **Exposure-only (log opportunity) AUC = 0.9462** ← pure opportunity reproduces the label very well (the core caveat).
- Exposed-only (opp>0, n=6,040): fl14 0.8417, log_tc 0.8635.
- **Within-opportunity-decile stratum: log_tc 0.7715 / fl14 0.7709** (headline exposure-adjusted).
- Logit nested: exposure-only 0.8467 → +score 0.8882; **increment +0.0415, DeLong Z=−4.745, p=2.08e-06**.
- CEM-opp-matched log_tc 0.8628.
76's pre-committed rejection region (within-opp AUC ≥0.70 AND increment ≥0.02 & p<0.05): **BOTH PASS**.

## VERDICT (pre-committed, honest): **B — proceed but downgrade.** A meaningful share of the raw 0.924/0.939 is opportunity exposure (exposure-only alone 0.946); the score retains *limited but significant* residual triage value (within-opp AUC 0.77; +0.04 over exposure, p<0.001). NOT Verdict A (would overclaim vs 0.946); NOT C (signal does not disappear). Sell direction + significance, not magnitude (CLAUDE.md honesty ledger A1).

## INFRASTRUCTURE AVAILABLE (Subprompt 2, purpose-built)
`scripts/utils/exposure_validation.R`: build_opportunity_cells, calculate_cell_defendant_contact_rate, calculate_firm_expected_contact (+LOO), calculate_excess_contact, exposure_adjusted_model_frame, exposure_stratified_matching_frame, cell_preserving_permutation_skeleton. `scripts/utils/metrics_triage.R`: roc_auc, average_precision, precision/recall/FP/FN/lift@k, metrics_at_k_grid, bootstrap_metric_ci, grouped_cv/LOCO/rolling-origin splits.

## EXECUTION (fan-out)
- Phase A (empirical): NEW `work/v22-editor/scripts/analysis/02_opportunity_adjusted_validation.R` — O_i/E_i (3 cell defs + LOO), common support (3 rules), control-function specs + PR battery (Table C), observed-vs-expected bins + figure, permutation B+C (Table D-perm), matched/stratified (Table D-matched), case/buyer contribution, caches.
- Phase B (parallel, after verify): §4.2 rewrite (W1); Appendix D restructure (W2). Me: front-end touch-ups, claims scan, registry/docs, build, completion report + verdict.

### Files read · data · utils inspected
- Docs 00–12 + memos. `scripts/76_exposure_adjusted_audit.R` (full) + `output/exposure_adjusted_audit/{auc_summary,firm_panel,audit_log}`. Utils `exposure_validation.R` + `metrics_triage.R` (signatures). Data: `firm_tender_map.parquet`, `FREQ_PARTICIP_rebuilt.parquet`, `cade_fl_cobidders.csv` (193), `cade_bec_crossmatch.csv` (direct defendants).

### Outputs created (Phase A — `02_opportunity_adjusted_validation.R`)
Tables: `outputs/tables/main/{table_C_opportunity_adjusted_validation, table_D_opportunity_permutation_validation}.{csv,tex}`; `outputs/tables/appendix/{table_D_opportunity_cell_construction, table_D_observed_expected_by_score_bins, table_D_matched_opportunity_validation, table_D_control_function_validation_full}.*`. Figures (4): `outputs/figures/{main,appendix}/…` (copied into `submission_clean/output/figures/`). Caches: `firm_opportunity_adjusted_frame.csv`, `opportunity_permutation_metrics.csv` (anon firm_id). Diagnostics: observed_defendant_contact_summary, opportunity_cell_sparsity, opportunity_common_support, opportunity_case_buyer_contribution; `claims_scan_after_opportunity_validation.csv`. Log: `outputs/logs/opportunity_validation.log`.

### Opportunity-cell definitions
COARSE = item_group(substr2 of códigoitem) × year; MEDIUM = + buyer/PBU(substr11 of numerodaoc); STRICT = item_code × year × buyer/PBU. Modality dropped (not in award layer; sensitivity only). LOO p_{g,-i} computed.

### Support retained
COARSE ~98–100%; MEDIUM ~46%; STRICT ~9% (sparsity: 65–95% of participation in <5-item cells). Reported, not cherry-picked.

### Models / metrics
Control-function S0–S6 (logit; S1 hit rare-event separation → flagged, excluded from headline). PR-AUC/precision@{100,250,500,1000}/recall/lift/FP/FN + bootstrap CI (B=2000). Permutation B (binomial firm-exposure sim, B=2000) + C (matched-stratum label perm, B=2000); A documented as equivalent-to-B substitute. CEM-opportunity matching.

### Metrics computed (headline, all reproduce script 76 to <0.0002)
Exposure-only AUC **0.946** (PR-AUC 0.194 exposed); raw score AUC 0.939 (PR-AUC 0.126); within-opp-stratum **0.771**; nested increment **+0.042** (DeLong p=2.08e-06); score-ranks-excess AUC 0.764; CEM-matched 0.863; within-stratum ΔP(FL14 vs non) +0.083. Permutation: **B p=1.00** (exposure out-predicts on PR-AUC), **C p=0.023**, FL14-enrich p<0.001. Case: top CADE case ≈47% of TP@500 (flag for Sub6).

### Manuscript edits
- `sec04`: §4 roadmap promotes §4.3 as central; §4.3 retitled "Opportunity-Adjusted Validation" + Table C + Table D-perm + 2 figures; the ~0.98 combined AUC explicitly omitted/caveated (E_i encodes label). `values.tex`: +20 `\valExp*` macros.
- `sec_app03` (App D): restructured D.1–D.12 (cells, E_i+LOO, control-function with 0.98 caveat, permutation both directions, matched, common support, sensitivity, limitations + legacy audits D.10–D.12).
- `sec01`: honest exposure hedge ("much of this raw concentration reflects procurement opportunity … but a limited and statistically significant signal survives once opportunity is held fixed").

### Commands run
`Rscript work/v22-editor/scripts/analysis/02_opportunity_adjusted_validation.R` (~150s, RSS ~1.66GB, exit 0 — one corrected re-run after a first-pass exposure undercount, documented). `make diagnostics`. Compile paper+appendix (bidirectional xr: paper→appendix→paper×2). No failures.

### Build result
**PASS.** Paper **47pp** (was 44), appendix **26pp** (was 18). 0 errors, 0 undefined refs/cites, 0 undefined control sequences, no severe overfull. claims critical=0. All 20 `\valExp*` resolve; 8 new table labels + 4 figures resolve.

### Failures / blockers
- S1 rare-event separation (flagged, excluded — score is a monotone transform of T_i anyway).
- STRICT-cell common support collapses to ~9% (reported, not hidden).
- Carried: conservative-benchmark AUC re-estimation under harmonized label; B3 (absent 193 builder); App D literals not yet macro-bound.
- NEW for Sub6: top-case ≈47% TP@500 dominance.
