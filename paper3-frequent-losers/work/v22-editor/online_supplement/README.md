# Online Supplement / Replication Materials — "Cheap Signals, Costly Proof"

This supplement holds the full diagnostic battery that backs the paper and the
submitted appendix. It is **not** part of the submitted manuscript; it exists for
transparency and referee response. Numbers here match the submitted paper exactly
(same seeds, same scripts).

## Contents
- **S-D Timing & opportunity (full):** full observed-vs-expected bin tables, full
  cell-preserving permutation draws, full common-support diagnostics, rolling-origin
  per-year tables, full per-case leave-one-case-out, environment-dominance full grid,
  clustered randomization-inference draws. (Submitted Appendix D keeps the headline rows.)
- **S-H Economic profile (full):** full standardized-difference table, monotonicity
  bin tables, full placebo-threshold sweep, market-specific zero-win validation,
  negative-control draws, calibration. (Submitted Appendix H keeps the summary.)
- **S-I Bid benchmark (full):** full bid-feature dictionary, fold-by-fold audit,
  per-case LOCO, calibration deciles, error-analysis environment tables,
  number-reproduction audit. (Submitted Appendix I keeps model audit + headline performance.)

## Generating scripts (deterministic, seeded)
`scripts/76_exposure_adjusted_audit.R`, `79_label_funnel.R`, and
`work/v22-editor/scripts/analysis/01–09_*.R` (seeds 20260430/20260530/20260603).
Full CSV/figure outputs under `paper3-frequent-losers/output/<module>/` and
`work/v22-editor/outputs/`.

## Replication tier (not submitted)
`work/v22-editor/docs/jleo_rr_revision/` — repo audit, revision plan, response matrix,
output/dataset registries, claims/number/alt-text scanner logs, per-subprompt logs and
completion reports, label-reconciliation and binary-vs-continuous memos.
