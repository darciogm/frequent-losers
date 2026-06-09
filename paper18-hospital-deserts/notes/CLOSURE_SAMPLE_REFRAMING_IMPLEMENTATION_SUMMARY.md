# Closure-Sample Reframing Implementation Summary

Date: 2026-06-08

## Files modified

- `01_manuscript/main.tex`
- `01_manuscript/introduction.tex`
- `01_manuscript/setting.tex`
- `01_manuscript/data.tex`
- `01_manuscript/method.tex`
- `01_manuscript/results.tex`
- `01_manuscript/discussion.tex`
- `01_manuscript/conclusion.tex`
- Selected legacy appendix/table captions relabeled from F5 "main" to F5 "measurement" in `01_manuscript/appendix.tex` and `01_manuscript/tables/`
- `run_pipeline.sh`

## Scripts created

- `03_analysis/63_closure_sample_architecture.py`
- `03_analysis/64_estimate_first_stage_by_sample.R`
- `03_analysis/check_sample_consistency.py`

## Scripts modified

- Caption/rubric relabeling in legacy generators:
  - `03_analysis/28f_motive_sensitivity_v2.R`
  - `03_analysis/30_event_study_final.R`
  - `03_analysis/31_causal_forest.R`
  - `03_analysis/34_robustness_battery.R`
  - `03_analysis/35b_bjs_true_compare.R`
  - `03_analysis/38_balance_and_crosstab.py`
  - `03_analysis/47_spillover_donut_conley.R`
  - `03_analysis/47b_seed_att_distribution.R`
  - `03_analysis/48_policy_magnitude.R`

## Tables created

- `01_manuscript/tables/table_master_closure_samples.tex`
- `01_manuscript/tables/table_flow_distance_disagreement_f5.tex`
- `01_manuscript/tables/table_flow_distance_by_type_region.tex`
- `01_manuscript/tables/table_first_stage_by_sample.tex`
- `01_manuscript/tables/table_f5_vs_failed_f5_diagnostics.tex`

## Figures created

- `04_figures/fig_flow_distance_disagreement_f5.pdf`
- `04_figures/fig_first_stage_f5.pdf`
- `04_figures/fig_first_stage_pnash_psych.pdf`
- `04_figures/fig_first_stage_nonpsych_f5.pdf`
- `04_figures/fig_first_stage_failed_f5.pdf`
- `04_figures/fig_f5_filter_admission_trajectories.pdf`

## Data outputs created

- `02_data/processed/master_closure_sample_table.parquet`
- `02_data/processed/master_closure_sample_table.csv`
- `02_data/processed/closure_sample_exposure_flags_long.parquet`
- `02_data/processed/flow_distance_disagreement_f5.parquet`
- `02_data/processed/failed_f5_predecline_closures.parquet`
- `02_data/processed/first_stage_sample_panels.parquet`
- `02_data/processed/first_stage_by_sample_estimates.csv`
- `02_data/processed/first_stage_by_sample_eventstudy.parquet`

## Sample counts

- Raw CNES exits: 3,518
- Candidate non-pandemic closures: 1,828
- Hospital-grade closures: 1,363
- Bed- and volume-filtered closures: 90
- F5 economically meaningful closures: 60
- PNASH psychiatric closures: 48
- General-hospital F5 closures: 18
- Hospital-day F5 closures: 1
- Nonpsychiatric F5 closures: 19
- Failed-F5 predecline closures: 30

## Which sample supports which claim

- F5 economically meaningful closures, N=60: main measurement sample for flow-versus-distance disagreement and broad first-stage diagnostics.
- PNASH psychiatric closures, N=48: main causal mortality sample for suicide and self-harm.
- Nonpsychiatric F5 closures, N=19: external-validity / contrast sample showing the exposure problem extends beyond psychiatric closures.
- Failed-F5 predecline closures, N=30: diagnostic sample showing why gradual pre-closure institutional decline is excluded from the main design.

## Key generated findings used in text

- Full F5 flow-distance disagreement: 293 of 337 municipality-closure pairs flagged by either rule are classified by only one rule.
- Full F5 travel-burden first stage:
  - Flow exposure ATT: -5.84 km, 95% CI [-9.21, -2.46].
  - Distance exposure ATT: -3.63 km, 95% CI [-4.99, -2.27].
- PNASH psychiatric first stage:
  - Flow exposure ATT: -7.09 km, 95% CI [-11.07, -3.10].
  - Distance exposure has a strong pre-trend, so it is not treated as the preferred causal exposure.
- Nonpsychiatric F5 first stage is reported only as contrast evidence, not as a causal mortality result.
- Failed-F5 predecline first stages fail pre-trend checks and are used only diagnostically.

## General-hospital contrast feasibility

Feasible. The F5 type field identifies 18 general-hospital closures and one hospital-day closure. I generated nonpsychiatric F5 exposure, first-stage table rows, and a contrast first-stage figure. The manuscript states explicitly that this is not a pooled mortality headline.

## Failed-F5 diagnostic feasibility

Feasible. Failed-F5 closures are identified from `hospital_closures_exogenous.parquet` as closures that pass F4 but fail F5. I generated a parquet dataset, a diagnostics table, and an admission-trajectory figure.

## Unavailable variables

No new variable gap was created for this task. Urban/capital breakdown was only partially feasible: capital status can be hardcoded from municipality codes, but no clean urban/rural classification was available in the current data objects. The generated breakdown focuses on hospital type and macroregion.

## Scripts run

- `python3 03_analysis/63_closure_sample_architecture.py --force`
- `Rscript 03_analysis/64_estimate_first_stage_by_sample.R --force`
- `python3 03_analysis/check_sample_consistency.py --force`
- `pdflatex -interaction=nonstopmode main && bibtex main && pdflatex -interaction=nonstopmode main && pdflatex -interaction=nonstopmode main` from `01_manuscript/`

## Build status

Build completed successfully. Output:

- `01_manuscript/main.pdf`

Final log checks found no LaTeX errors, undefined control sequences, undefined citations, or undefined references.

Non-fatal warnings:

- Float placement warnings.
- Underfull/overfull hbox warnings in dense tables.
- Duplicate destination warning for `page.1`.
- One float-only page.

## Sample-consistency audit

`04_logs/sample_consistency_audit_20260608.log` reports no warnings. It verifies:

- F5 N=60.
- PNASH N=48.
- General-hospital F5 N=18.
- Hospital-day F5 N=1.
- Nonpsychiatric F5 N=19.
- Failed-F5 N=30.
- F5 disagreement: flow-only 97, distance-only 196, both 44, union 337, misclassified 293.

## Remaining risks

- The PNASH psychiatric sample is not literally nested inside F5 because the current PNASH definition relaxes the F5 demand-decline screen. The manuscript now avoids calling it a strict nested sample and instead describes distinct samples for distinct claims.
- The nonpsychiatric F5 contrast is small and heterogeneous; the manuscript treats it only as an exposure-measurement contrast.
- Legacy appendix tables remain dense and produce hbox warnings, but they no longer label F5 as the main causal sample.
