# Online Supplement / Replication Materials — "Cheap Signals, Costly Proof"

This supplement holds the full diagnostic battery that backs the paper and the
submitted appendix. It is **not** part of the submitted manuscript; it exists for
transparency and referee response. Numbers here match the submitted paper exactly
(same seeds, same scripts).

## Directory structure (9 modules)

The supplement is organized into nine module directories, each with a `README.md`
naming what belongs there. `MANIFEST.csv` (in this directory) lists the moved
diagnostic CSVs/figures by directory, pointing to their actual paths under
`work/v22-editor/outputs/` (and, for price scope, `paper3-frequent-losers/output/`).

| Dir | Module | Main / appendix reference |
|---|---|---|
| `01_label_funnel/` | CADE-cobidder label construction (12->41->341; 193 vs 210) | Table 2 / App D2 |
| `02_opportunity_validation/` | Opportunity/exposure-adjusted validation, observed-vs-expected, permutation | Table 3, Figure 2 / App D |
| `03_timing_case_holdout/` | Timing info sets, strict-timing, rolling-origin, LOCO, clustered-RI | Table 4 / App D |
| `04_economic_profile_score_diagnostics/` | Standardized differences, monotonicity, placebo, negative controls | App H |
| `05_bid_benchmark/` | Bid-feature dictionary, missingness, calibration, fold/LOCO audit | Table 5 / App I |
| `06_cost_recall_frontier/` | Full cost grid, denominators, operating points | Table 6, Figure 3 / App G |
| `07_price_scope_adaptation/` | Sign-reversal / mechanism decomposition, bidder-count, adaptation | App E / sec_app05 |
| `08_survival_hazard/` | Discrete-time hazard, Cox, exit-definition sensitivity, KM curves | App B |
| `09_diagnostics_and_logs/` | Claims/number/reference/alt-text scanners + per-script run logs | all sections |

## Legacy index files (kept)
The three pre-existing narrative index files remain and now correspond to the
directories above:
- **S-D** (`S_D_timing_opportunity.md`) → `02_opportunity_validation/` + `03_timing_case_holdout/`:
  full observed-vs-expected bin tables, full cell-preserving permutation draws, full
  common-support diagnostics, rolling-origin per-year tables, full per-case
  leave-one-case-out, environment-dominance grid, clustered randomization-inference
  draws. (Submitted Appendix D keeps the headline rows.)
- **S-H** (`S_H_profile.md`) → `04_economic_profile_score_diagnostics/`: full
  standardized-difference table, monotonicity bin tables, full placebo-threshold
  sweep, market-specific zero-win validation, negative-control draws, calibration.
  (Submitted Appendix H keeps the summary.)
- **S-I** (`S_I_bid_benchmark.md`) → `05_bid_benchmark/`: full bid-feature
  dictionary, fold-by-fold audit, per-case LOCO, calibration deciles, error-analysis
  environment tables, number-reproduction audit. (Submitted Appendix I keeps model
  audit + headline performance.)

## Generating scripts (deterministic, seeded)
`scripts/{53,59,61,62,76,77,78,79}_*.R`, `scripts/31_imhof_full_pipeline.R`,
and `work/v22-editor/scripts/analysis/01–11_*.R`
(seeds 20260430/20260501/20260530/20260602/20260603).
Full CSV/figure outputs under `paper3-frequent-losers/output/<module>/` and
`work/v22-editor/outputs/`. Per-file index: **`MANIFEST.csv`** in this directory.

## Replication tier (not submitted)
`work/v22-editor/docs/jleo_rr_revision/` — repo audit, revision plan, response matrix,
output/dataset registries, claims/number/alt-text scanner logs, per-subprompt logs and
completion reports, label-reconciliation and binary-vs-continuous memos.
