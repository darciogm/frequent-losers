# S-D — Timing & Opportunity Audits (full diagnostics)

Granular tables and figures moved out of submitted Appendix D ("Validation
Audits") during the compression pass. The submitted appendix keeps the headline
rows, summaries, and the decisive results; this index points to the full
diagnostics, which live as CSVs under `work/v22-editor/outputs/` and are
recoverable in full-LaTeX form from git history of
`submission_clean/sec_app03_validation_audits_submission.tex` (pre-compression
revision). Numbers match the submitted paper exactly (same seeds, same scripts;
seeds 20260603).

## Opportunity-adjusted block (D.2–D.7)

- **Opportunity-cell construction by granularity** (COARSE/MEDIUM/STRICT: cells,
  tender-items, participation, median items/cell, % cells <5, % singletons,
  cells w/ defendant). Submitted appendix keeps a one-line summary
  (mean p_g ~0.017–0.019; STRICT 99.5% <5 items, 75.7% singletons).
  Source: `outputs/tables/appendix/table_D_opportunity_cell_construction.csv`.
- **Observed vs. expected defendant contact by participation tier**
  (T<=5, 6–13, FL14, T>=50; N, N cobidder, obs. prev., mean O_i, E_i, excess X_i).
  Submitted appendix keeps the +0.068 (T>=50) vs ~0 / slightly-negative summary.
  Source: `outputs/tables/appendix/table_D_observed_expected_by_score_bins.csv`.
- **Figure — excess defendant contact by screening-score decile** (bar chart).
  Source figure: `outputs/figures/.../fig_excess_contact_by_score_bins`.
- **Opportunity-matched (CEM) validation by exposure stratum** (6 sextiles;
  N, n FL, n non-FL, ΔP_cob, ΔX). Submitted appendix keeps within-stratum
  AUC 0.725 / CEM-matched AUC 0.863 on 6,039 matched firms.
  Source: `outputs/tables/appendix/table_D_matched_opportunity_validation.csv`
  (summary: `..._matched_opportunity_validation_summary.csv`).
- **Common-support retention by cell definition and rule** (COARSE/MEDIUM/STRICT
  × minimal/moderate/strict; N retained, share). Submitted appendix keeps the
  ~98%/46%/9% retention summary.
  Source: (retention grid generated alongside the cell-construction CSV;
  `outputs/tables/appendix/table_D_opportunity_cell_construction.csv`).

## Opportunity-preserving permutation (D.5)

- **Full precision-at-500 null draws**, Approach B (firm-exposure binomial
  simulation) and Approach C (matched-stratum label permutation), B=2,000.
  Submitted appendix keeps the PR-AUC summary table + empirical p-values
  (B p=1.000; C p=0.023).
  Source: `outputs/tables/main/table_D_opportunity_permutation_validation.csv`.
- **Figure — opportunity-preserving permutation, precision@k=500** (histogram).
  Source figure: `outputs/figures/.../fig_opportunity_permutation_precision_at_k`.

## Temporal / rolling-origin (D.12, D.16)

- **Temporal-holdout AUC by test year** (2014–2019: AUC, 95% CI, N firms, N CADE).
  Submitted appendix keeps the one-line 0.819→0.922 summary.
  Source: (rolling-origin CSV below; year-level holdout rows).
- **Rolling-origin validation, t=2014…2019, training-only scores** (full
  candidate universe + training always-loser pool: N, Pos., ROC, PR-AUC,
  Prec@500, Rec@500). Submitted appendix keeps the full-universe-PR≈0.004–0.006 /
  within-pool ROC 0.717–0.881 summary.
  Source: `outputs/tables/main/table_E_rolling_origin_validation.csv`.
- **Figure — rolling-origin ROC AUC by origin year** (two trajectories).
  Source figure: `outputs/figures/.../fig_rolling_origin_auc`.

## Case-composition (D.18, D.19)

- **Leave-one-case-out discrimination (linkable cases)** (6 cases: Pos., ROC,
  PR-AUC, Prec@500, Rec@500, largest item-group share). Submitted appendix keeps
  the per-case-ROC≈0.95-uninformative / PR-AUC mean 0.039 / max 0.121 summary,
  and retains the leave-largest-case-out table (Case Dominance) in-paper.
  Source: `outputs/tables/main/table_G_leave_one_case_out_validation.csv`.
- **Figure — concentration of true positives across CADE cases** (bar chart,
  trens_metros dominant). Source figure:
  `outputs/figures/.../fig_case_positive_concentration`.
- **Environment-dominance exclusions** (full grid: drop largest buyer /
  item group / buyer×item-group / Pregão only / Convite only / drop top-2
  positive years). Submitted appendix keeps the one-sentence summary
  (item-group HHI 0.188; drop-largest-item-group 0.126→0.062; drop top-2 years
  →0.048; drop largest buyer 0.126→0.120).
  Source: `outputs/tables/appendix/table_D_environment_dominance.csv`.

## Clustered randomization inference (D.20)

- **Figure — clustered randomization inference, observed vs. null** (panel of
  histograms per metric). The submitted appendix keeps the summary table
  (observed vs. null mean / 95th / empirical p: ROC p=0.001, PR-AUC p=0.015,
  Prec@500 p=0.013, Rec@500 p=0.016, case-coverage p=0.317).
  Source figure: `outputs/figures/.../fig_clustered_randomization_inference`;
  table source: `outputs/tables/appendix/table_D_clustered_randomization_inference.csv`.
- **Leave-one-direct-defendant-group-out** (full per-defendant grid; submitted
  appendix keeps the one-paragraph summary: 13/28 defendants ≥5 positives,
  mean ROC 0.944, dominated by a single rail-sector defendant group).
  Source: `outputs/tables/appendix/table_D_leave_one_defendant_group_out.csv`.
