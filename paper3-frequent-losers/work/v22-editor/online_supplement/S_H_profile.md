# §S-H — Economic Profile and Robustness (moved-out granular diagnostics)

Granular diagnostics moved out of submitted Appendix H
(`submission_clean/sec_app08_profile_submission.tex`, COMPRESS PASS 2) to
keep the appendix at its essential robustness. Numbers unchanged; this is a
relocation, not a re-estimation. Source CSV paths are relative to
`work/v22-editor/outputs/`.

## Moved tables

- **Full standardized profile differences (all 20 variables), E minus D.**
  The appendix retains only the top 11 by `|d|`; the full table lives here.
  - Source: `tables/appendix/table_E_standardized_profile_differences.csv`

- **Placebo-threshold sensitivity grid (always-loser universe).**
  Decile cuts, fixed `T>=k`, IQR multiples, top-share rules; precision,
  recall, lift across the grid.
  - Source: `tables/appendix/table_E_placebo_thresholds.csv`

- **Market-specific zero-win definitions (4 strata).**
  Definitions: candidate counts, positives, overlap with the global
  always-loser set.
  - Source: `tables/appendix/table_E_market_specific_zero_win_definitions.csv`

- **Validation of zero-win definitions against the adjudication-anchored
  target.** ROC-AUC, PR-AUC, Prec.@500 for global vs. four home-market strata.
  - Source: `tables/appendix/table_E_market_specific_zero_win_validation.csv`

## Moved figures

- **Participation-count distribution around the T=14 threshold (bunching).**
  Local density ratio at T=14 = 1.06.
  - Figure source: `output/figures/fig_threshold_bunching_T14`
  - Data: `diagnostics/threshold_bunching_T14.csv`

- **Discrimination across the placebo-threshold grid.**
  Precision/recall/lift curves; smooth, no discontinuity at T=14.
  - Figure source: `output/figures/fig_threshold_sensitivity`
  - Data: `tables/appendix/table_E_placebo_thresholds.csv`

- **Null ROC-AUC distributions vs. the real target (negative controls).**
  B=500 matched draws (placebo CADE anchors, non-CADE high-volume winners);
  real ROC-AUC 0.939 marked in the right tail.
  - Figure source: `output/figures/fig_negative_control_distribution`
  - Data: `tables/appendix/table_E_negative_controls.csv`
