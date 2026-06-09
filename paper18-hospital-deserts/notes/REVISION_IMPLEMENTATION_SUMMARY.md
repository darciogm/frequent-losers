# Revision Implementation Summary

## Files Created

- `03_analysis/revision_utils.py`
- `03_analysis/49_audit_project_state.py`
- `03_analysis/50_build_master_sample_table.py`
- `03_analysis/51_build_exposure_variants.py`
- `03_analysis/52_revision_measurement_diagnostics.py`
- `03_analysis/53_raw_means_revision.R`
- `03_analysis/54_fe_sensitivity_revision.R`
- `03_analysis/55_mortality_scaling_mde_revision.R`
- `03_analysis/56_heterogeneity_dependence_revision.R`
- `03_analysis/57_postpandemic_exclusion_revision.R`
- `03_analysis/58_honestdid_mortality_revision.R`
- `03_analysis/59_exposure_distance_variant_eventstudies.R`
- `03_analysis/60_leave_one_closure_out_revision.R`
- `03_analysis/61_resolve_remaining_data_caveats.py`
- `03_analysis/62_format_legacy_tables.py`
- `02_data/processed/*.parquet` and `02_data/processed/*.csv` revision outputs
- New generated tables in `01_manuscript/tables/`: `master_sample_table.tex`, `table_*`, and `tab_*_revision.tex`
- New revision figures in `04_figures/`
- `notes/PROJECT_STATE_AUDIT.md`
- `notes/VARIABLE_GAPS.md`
- `notes/_archive/` contains the temporary pre-install HonestDiD note produced before the package was installed.

## Files Modified

- `run_pipeline.sh`
- `01_manuscript/main.tex`
- `01_manuscript/introduction.tex`
- `01_manuscript/setting.tex`
- `01_manuscript/data.tex`
- `01_manuscript/method.tex`
- `01_manuscript/results.tex`
- `01_manuscript/robustness.tex`
- `01_manuscript/discussion.tex`
- `01_manuscript/conclusion.tex`
- `01_manuscript/appendix.tex`
- `01_manuscript/main.pdf`
- `01_manuscript/values.tex`
- `01_manuscript/values_inference.tex`
- Main D5 figures regenerated: `fig_firststage_travel.pdf`, `fig_es_mortality.pdf`, `fig_es_icsap_pretrend.pdf`
- `03_analysis/D7_inference.R` now accepts `--B=<int>` and caches randomization-inference draws.
- `03_analysis/D5_make_mortality_results.R` and `03_analysis/28f_motive_sensitivity_v2.R` now resize wide generated tables rather than requiring hand edits.

## Scripts Run

- `python3 03_analysis/49_audit_project_state.py --force`
- `python3 03_analysis/50_build_master_sample_table.py --force`
- `python3 03_analysis/51_build_exposure_variants.py --force`
- `python3 03_analysis/52_revision_measurement_diagnostics.py --force`
- `Rscript 03_analysis/53_raw_means_revision.R --force`
- `Rscript 03_analysis/54_fe_sensitivity_revision.R --force`
- `Rscript 03_analysis/55_mortality_scaling_mde_revision.R --force`
- `Rscript 03_analysis/56_heterogeneity_dependence_revision.R --force`
- `Rscript 03_analysis/57_postpandemic_exclusion_revision.R --force`
- `Rscript 03_analysis/58_honestdid_mortality_revision.R --force`
- `Rscript 03_analysis/59_exposure_distance_variant_eventstudies.R --force`
- `Rscript 03_analysis/60_leave_one_closure_out_revision.R --force`
- `python3 03_analysis/61_resolve_remaining_data_caveats.py --force`
- `Rscript 03_analysis/D5_make_mortality_results.R`
- `Rscript 03_analysis/28f_motive_sensitivity_v2.R`
- `python3 03_analysis/62_format_legacy_tables.py --force`
- `Rscript 03_analysis/D6_make_values.R`
- `Rscript 03_analysis/D7_inference.R --force`
- `Rscript 03_analysis/D7_inference.R`
- `Rscript 03_analysis/D7_inference.R --B=500 --force`
- `cd 01_manuscript && pdflatex -interaction=nonstopmode main && bibtex main && pdflatex -interaction=nonstopmode main && pdflatex -interaction=nonstopmode main`
- Final post-edit compile: `cd 01_manuscript && pdflatex -interaction=nonstopmode main && pdflatex -interaction=nonstopmode main`

## Outputs Generated

- Master sample table: `02_data/processed/master_sample_table.parquet`, `01_manuscript/tables/master_sample_table.tex`
- PNASH event-level dataset: `02_data/processed/pnash_event_level_dataset.parquet`, `table_event_level_pnash.tex`
- True pre-period checks: `table_preclosure_predictors.tex`, `table_balance_true_preperiod.tex`
- Exposure variants: `02_data/processed/exposure_variants_long.parquet`, `table_exposure_definition_diagnostics.tex`, `fig_exposure_share_distribution.pdf`, `fig_exposure_definition_overlap.pdf`
- Resolved local caveats: `02_data/processed/preclosure_sih_covariates.parquet`, `02_data/processed/cnes_caps_cir_municipality_year.parquet`, `table_preclosure_sih_covariates.tex`, `table_remaining_data_caveats.tex`
- Distance benchmarks: `02_data/processed/distance_benchmark_exposures.parquet`, `table_flow_vs_distance_benchmarks.tex`, `table_distance_benchmark_results.tex`, `fig_flow_distance_overlap_by_region.pdf`
- First-stage decomposition: `02_data/processed/first_stage_decomposition_panel.parquet`, `table_first_stage_decomposition.tex`, `table_top_substitute_hospitals.tex`
- Spillover flags: `02_data/processed/spillover_control_flags.parquet`, `table_spillover_sensitivity.tex`
- LLM validation status: `table_llm_validation_status.tex`, `04_logs/llm_classification_audit_latest.log`
- FE/raw mean/scaling/heterogeneity/post-pandemic outputs from scripts `53`--`57`
- HonestDiD sensitivity: `table_honestdid_mortality.tex`, `fig_honestdid_suicide.pdf`, `fig_honestdid_selfharm.pdf`
- Exposure/distance event-study variants: `02_data/processed/exposure_distance_variant_eventstudies.csv`, `table_exposure_distance_variant_eventstudies.tex`
- Closure-catchment influence: `02_data/processed/leave_one_closure_out_revision.csv`, `table_closure_level_inference.tex`, `fig_leave_one_closure_out_suicide.pdf`, `fig_leave_one_closure_out_selfharm.pdf`

## Checks Passed

- PDF compiles successfully to `01_manuscript/main.pdf` with zero fatal errors.
- `rg` found no undefined references/citations in `01_manuscript/main.log`.
- Text audit found no development markers or banned rhetorical phrases in active manuscript sources/tables.
- Required generated data/table/figure inputs exist.
- `04_logs/sample_consistency_audit_latest.log` reports: sample consistency audit passed for generated macro checks.
- All new scripts write timestamped logs in `04_logs/` with git SHA, runtime, package versions, and memory information where applicable.
- `HonestDiD` installed successfully after adding Rust via `rustup`; `requireNamespace("HonestDiD", quietly = TRUE)` returns `TRUE` and the mortality sensitivity table/figures are real outputs, not placeholders.
- `D7_inference.R --B=500 --force` completed with 500 valid placebos, RI p-value 0.622, placebo 95% interval [-1.24, +1.24], and wrote `values_inference.tex`.
- Newly added appendix tables and legacy wide tables compile after resizing/escaping fixes.

## Remaining Blockers And Caveats

- A prose-only cleanup shortened the old introduction and appendix passages that caused several overfull hbox warnings. Wide generated tables are now handled in their scripts or by `03_analysis/62_format_legacy_tables.py`.
- `fixest` reported non-positive-semidefinite VCOV warnings in some specifications and fixed the matrices internally; logs preserve those warnings.
- HonestDiD relative-magnitude intervals are very wide at `Mbar=1`; the manuscript now states that this is a sensitivity bound rather than new precision.
- The strongest-dependence heterogeneity is not uniformly null: the highest exposure-share quartile has a positive suicide estimate, and one episode-count quartile has a positive self-harm estimate. The manuscript should not claim all high-dependence groups are null.

## Variables Unavailable

Documented in `notes/VARIABLE_GAPS.md`:

- Unique psychiatric patients/persons remain unobservable in public SIH; all scaled admission counts are AIH episodes.
- FHS/primary-care coverage requires an external e-Gestor/SISAB national coverage series; local CNES-PF files are partial from 2015 onward.
- private insurance penetration
- SICONFI fiscal capacity
- routed road travel-time matrix

Psychiatric-specific exposure denominators were rebuilt from raw SIH diagnosis fields for admissions, bed-days, AIH value, and episode counts. They remain episode-based, not person-based. CAPS facility counts and same-health-region proxies are now rebuilt from CNES-ST December establishment files in `02_data/processed/cnes_caps_cir_municipality_year.parquet`; the CIR proxy uses modal `REGSAUDE`, so an official relationship table would still be cleaner.

## Not Fully Implemented

- Full event-study re-estimation for exposure and distance variants is now implemented in `03_analysis/59_exposure_distance_variant_eventstudies.R`. Two distance variants classify all municipalities as treated and are reported as status rows because no never-treated controls remain.
- Leave-one-closure-catchment-out influence diagnostics are now implemented in `03_analysis/60_leave_one_closure_out_revision.R`. Exact closure-catchment clustering remains not well-defined because catchments overlap and never-treated municipalities have no associated closure.
- CIR-based contaminated-control flags are now implemented with the CNES-ST modal `REGSAUDE` proxy. They should be read as a network-contamination diagnostic, not as an official CIR crosswalk.
- LLM labels were audited and demoted, but no external API calls or new human validation were performed.
