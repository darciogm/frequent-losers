# Script run order (dependency-ordered)

Run scripts in the order below. Paths are relative to the repository root
`paper3-frequent-losers/`; revision-subprompt scripts live under
`work/v22-editor/scripts/analysis/`; helper utilities under
`work/v22-editor/scripts/utils/`.

Caches are written to `/tmp/` (e.g. `/tmp/p3_prepared.rds`,
`/tmp/p3_models.rds`) and to `work/v22-editor/outputs/cache/`. Most analysis
scripts depend on the Stage-1 ETL parquets and on `/tmp/p3_prepared.rds`.

---

## 1. Data cleaning / ETL (Python build → R clean)
- `scripts/00_build_bidlevel.py` — builds the 5 core parquets in
  `data/processed/` from the raw BEC LANCES `.dta` (~6 min). **Not
  redistributable input.**
- `scripts/12_build_item_value.R` — builds `data/processed/item_value_panel.parquet`.
- `scripts/01_clean.R` — loads parquets, extracts BEC keys, merges LOSERS →
  `/tmp/p3_prepared.rds`.

## 2. Label construction (CADE cobidder labels)
- `scripts/79_label_funnel.R` — transparent 12→41→341 label funnel; emits
  `output/label_funnel/funnel.csv`, `case_cobidder_map.csv`, `case_timing.csv`.
- `work/v22-editor/scripts/analysis/01_label_funnel_reconciliation.R`
  (uses `utils/label_funnel.R`) — reconciles label sets → **Table 2**.

## 3. Opportunity-adjusted validation
- `scripts/76_exposure_adjusted_audit.R` — exposure/opportunity-adjusted AUC.
- `work/v22-editor/scripts/analysis/02_opportunity_adjusted_validation.R`
  (uses `utils/exposure_validation.R`, `utils/metrics_triage.R`) → **Table 3** +
  **Figure 2** (observed-vs-expected contact bins).

## 4. Timing & case-holdout
- `scripts/53_strict_train_period_threshold.R` — frozen-train threshold / strict timing.
- `scripts/77_reverse_causality_timing.R` — concentration / reverse-causality timing.
- `work/v22-editor/scripts/analysis/03_timing_case_holdout_validation.R` → timing rows of **Table 4**.
- `work/v22-editor/scripts/analysis/04_case_holdout_dominance.R` — clustered
  randomization-inference / leave-one-case-out dominance → **Table 4** (dominance) **(long-running)**.

## 5. Economic profile (Section 5)
- `work/v22-editor/scripts/analysis/05_section5_profile_monotonicity.R` — standardized differences + monotonicity.
- `work/v22-editor/scripts/analysis/06_section5_robustness.R` — placebo thresholds, negative controls, market-specific zero-win.

## 6. Bid-layer benchmark (Imhof)
- `scripts/31_imhof_full_pipeline.R` — Imhof feature build + RF benchmark **(long-running, RF)**.
- `scripts/49_imhof_incremental_value.R` — incremental value / missingness.
- `work/v22-editor/scripts/analysis/07_bid_feature_audit.R` — feature dictionary + support.
- `work/v22-editor/scripts/analysis/08_bid_benchmark_reproduction.R` — number reproduction / fold audit.
- `work/v22-editor/scripts/analysis/09_bid_benchmark_validation.R` → **Table 5** **(long-running, RF)**.

## 7. Cost–recall frontier
- `work/v22-editor/scripts/analysis/10_cost_recall_frontier.R`
  (uses `utils/cost_frontier.R`, `utils/metrics_triage.R`) → **Table 6** + **Figure 3** + App G cost grid.

## 8. Price / scope / adaptation
- `scripts/59_sign_reversal_decomp.R` — sign-reversal / price-scope decomposition.
- `scripts/61_selection_mechanism_test.R` — selection-vs-mechanism test.
- `scripts/62_within_cell_mechanism_test.R` — within-cell mechanism test.
- `scripts/78_bidder_count_decomposition.R` — bidder-count decomposition ("theater not identified").

## 9. Survival / hazard (Appendix B)
- `work/v22-editor/scripts/analysis/11_survival_hazard_frequent_losers.R`
  (uses `survival`) — discrete-time hazard, Cox, exit-definition sensitivity.

## 10. Table / figure assembly
- `work/v22-editor/submission_clean/make_submission_figures.R` — renders the
  `\includegraphics` figures (`fig_data_coarsening`, `fig_temporal_holdout_roc`;
  some values hardcoded).
- Remaining main/appendix tables are assembled inline by the analysis scripts in
  steps 2–9 (CSV + `.tex` under `work/v22-editor/outputs/tables/{main,appendix}/`).

## 11. Manuscript build (LaTeX, run manually)
Appendix **first** (so `xr` cross-refs resolve), then the paper:
```bash
# in work/v22-editor/submission_clean/
pdflatex online_appendix_submission_clean && bibtex online_appendix_submission_clean && pdflatex online_appendix_submission_clean
pdflatex paper_submission_clean && bibtex paper_submission_clean && pdflatex paper_submission_clean && pdflatex paper_submission_clean
```
(Also wired as the `manuscript` target in `work/v22-editor/Makefile`.)

---

### Notes on script numbering
- Numeric prefixes collide for a few scripts (`55_*`, `61_*`, `62_*`, `67_*`,
  `00_*`); **key by full filename**, not the number.
- Several builders hard-code absolute paths
  (`12_build_item_value.R`, `00_build_bidlevel.py`, `67/70/73*.py`); these are
  documented, not edited, since the parquets are already built.
