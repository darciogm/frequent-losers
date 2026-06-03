# 24 — APPENDIX RELOCATION MAP (compression pass 2, JLEO R&R v22)

Date: 2026-06-03. Submitted appendix reduced **55pp → 42pp** by moving the most granular/voluminous diagnostics to the online supplement (`work/v22-editor/online_supplement/`). Core robustness a referee needs to trust the main claims stays in the submitted appendix. No outputs deleted; the moved material lives in `outputs/*.csv` + scripts and is indexed in the supplement.

## Appendix files (submitted) — kept vs trimmed
| Appendix file | Role | Before (tab/fig/words) | After | Action |
|---|---|---|---|---|
| sec_app00 referee map | nav | 1/0/220 | same | keep |
| sec_app01 framework | theory | 0/0/1054 | same | keep |
| sec_app02 data/labels | data, label funnel | 3/0/1669 | same | keep |
| **sec_app03 validation audits (App D)** | opportunity + timing/case-holdout | **18/5/6286** | **10/0/~5273** | trim → S-D |
| sec_app04 scope | price scope | 0/0/214 | same | keep |
| sec_app05 adaptive | adaptation | 1/0/461 | same | keep |
| sec_app06 forensic seq | gatekeeper algo | 0/0/583 | same | keep |
| **sec_app08 profile (App H)** | §5 profile | **6/3/2748** | **3/0/~1400** | trim → S-H |
| **sec_app09 bid benchmark (App I)** | §6 bid | **10/2/3018** | **4/0/~1700** | trim → S-I |

## What stayed in the submitted appendix (referee-essential)
- **App D:** opportunity-cell construction + E_i formula + LOO; control-function headline (exposure-only 0.946, +0.042, within-stratum 0.771); permutation summary; leakage audit; timing information sets A–G; strict-holdout full-universe collapse; leave-largest-case-out (decisive); clustered-RI summary; direct-defendant scope.
- **App H:** group definitions; Cohen's-d method + compact top-row SMD table; monotonicity finding (prose); negative-controls summary table; limitations.
- **App I:** data/linkage + RF-learner correction; units + support summary (193 positives retained); model-spec audit; CV/holdout designs A/E/F/G + case-grouped collapse; leakage audit; performance table (4 models × 4 designs); complementarity summary; limitations.

## What moved to the online supplement (indexed; data in `outputs/*.csv`)
- **S-D** (`online_supplement/S_D_timing_opportunity.md`): cell-construction-by-granularity; observed-vs-expected bins; CEM-by-stratum; common-support retention; full permutation draws + precision@k figure; temporal-holdout-by-year; rolling-origin per-year + ROC figure; per-case LOCO + concentration figure; environment-dominance grid; clustered-RI figure.
- **S-H** (`online_supplement/S_H_profile.md`): full 20-variable SMD table; placebo-threshold grid; market-zero-win definitions + validation; bunching/threshold-sensitivity/negative-control figures; monotonicity bin tables.
- **S-I** (`online_supplement/S_I_bid_benchmark.md`): full bid-feature dictionary; missingness table; number-reproduction audit; fold-composition; per-case LOCO; calibration-by-decile; error-analysis; calibration + score-scatter figures.

## Replication tier (never submitted, never `\input`)
`docs/jleo_rr_revision/` — repo audit, revision plan, response matrix, output/dataset registries, scanner logs, per-subprompt logs + completion reports, memos.

## Ref integrity
All section `\label`s the main text references (`app:validation_audits_submission`, `app:market_opportunity_submission` [newly defined — fixed a pre-existing dangling ref], `app:profile_submission`, `app:bid_benchmark_submission`, `app:scope_adaptation_submission`, …) preserved. Compile: **0 undefined references, 0 duplicate labels** (paper + appendix).
