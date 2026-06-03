# S-I. Bid-Layer Benchmark — Granular Diagnostics (Online Supplement)

These granular diagnostics were moved out of Appendix I ("Bid-Layer
Benchmark", `app:bid_benchmark_submission`) in compress pass 2. The
trimmed appendix retains the core robustness (data/linkage, learner
correction, model-spec audit, support summary, CV/holdout designs and
the case-grouped collapse, leakage audit, performance table,
complementarity summary, limitations). Everything below is the
full-detail material referenced from the appendix as "online supplement,
§S-I". No numbers are changed; these are the same artifacts, deposited
here in full.

All source paths are relative to `work/v22-editor/outputs/`.

## Moved tables

- **Full bid-feature dictionary** (all columns: feature, per-tender
  formula, firm aggregation, family, leakage risk)
  - `tables/appendix/table_F_bid_feature_dictionary.csv`
  - `tables/appendix/table_F_bid_feature_dictionary.tex`
- **Full bid-feature missingness table** (per-feature N nonmissing,
  missingness, positives nonmissing/total over the 16,843 always-loser
  universe)
  - `tables/appendix/table_F_bid_feature_missingness.csv`
  - `diagnostics/bid_feature_support_diagnostics.csv`
- **Number-reproduction audit** (out-of-fold ROC-AUC, reproduced vs.
  committed, spec by spec, both pools)
  - `diagnostics/bid_benchmark_number_reproduction.csv`
- **Fold composition by validation design** (positives per fold,
  Designs A/E/F/G)
  - `diagnostics/bid_benchmark_fold_audit.csv`
- **Per-case leave-one-case-out (LOCO) table** (held-out CADE case,
  positives, candidates, award/bid/combined AUCs)
  - `diagnostics/bid_benchmark_loco_per_case.csv`
- **Bid-RF calibration by predicted-probability decile** (N, mean
  predicted, observed cobidder rate; overall Brier = 0.0095)
  - `tables/appendix/table_F_bid_model_calibration.csv`
- **Error-analysis environment table**
  - `diagnostics/bid_benchmark_error_analysis.csv`

## Moved figures

- **Bid-layer random-forest calibration plot** (observed cobidder rate
  vs. mean predicted probability by decile)
  - `figures/appendix/fig_bid_model_calibration.pdf`
- **Award score vs. bid-layer random-forest score scatter** (cobidders
  highlighted)
  - `figures/appendix/fig_award_bid_score_scatter.pdf`
