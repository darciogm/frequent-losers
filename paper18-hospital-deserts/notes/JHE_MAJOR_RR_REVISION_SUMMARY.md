# JHE Major R&R Revision Summary

Generated: 2026-06-08T15:32:57

## Files created or materially updated
- `03_analysis/72_jhe_submission_tables.py`
- `03_analysis/73_jhe_spillover_sensitivity.R`
- `run_pipeline.sh`
- `01_manuscript/main.tex`, `introduction.tex`, `setting.tex`, `data.tex`, `method.tex`, `results.tex`, `robustness.tex`, `discussion.tex`, `conclusion.tex`, `appendix.tex`
- New/updated tables in `01_manuscript/tables/`: true PNASH balance, PNASH timing, pre-closure predictor tests, exposure-variant mortality, distance benchmark results, first-stage decomposition, spillover sensitivity, closure influence, mortality bounds scaling.
- New figure: `04_figures/fig_first_stage_decomposition_eventstudy.pdf`.

## Final sample counts
| sample_id                           |   number_of_closures |   number_of_unique_flow_exposed_municipalities | years_included   |
|:------------------------------------|---------------------:|-----------------------------------------------:|:-----------------|
| f5_economically_meaningful_closures |                   60 |                                            130 | 2012-2023        |
| pnash_psychiatric_closures          |                   48 |                                            104 | 2012-2017        |
| nonpsychiatric_f5_closures          |                   19 |                                             25 | 2012-2023        |
| failed_f5_predecline_closures       |                   30 |                                             26 | 2012-2023        |

## Main mortality estimates and bounds
| outcome   |   att_per100k |   lo_per100k |   hi_per100k |   baseline_rate_per100k |   upper_ci_percent_of_baseline |   upper_deaths_per_year |   upper_deaths_per_1000_psych_admissions |
|:----------|--------------:|-------------:|-------------:|------------------------:|-------------------------------:|------------------------:|-----------------------------------------:|
| Suicide   |       0.28473 |    -0.72317  |      1.29263 |                 5.11182 |                        25.2871 |                 37.7223 |                                  1.25769 |
| Self-harm |       0.61213 |    -0.898393 |      2.12265 |                 7.3221  |                        28.9897 |                 61.9445 |                                  2.06527 |

## Status by requested package
- True PNASH pre-treatment balance: implemented in `table_balance_pnash_true_preperiod.tex`; old 2015--2017 balance removed from main text.
- PNASH event-level timing and predictor tests: implemented in `table_pnash_event_timing.tex` and `table_preclosure_predictor_tests.tex`; PNASH score and de-accreditation micro indicators remain unavailable and are documented in `notes/VARIABLE_GAPS.md`.
- Exposure variants: implemented via existing variant event-study estimates and summarized in `table_exposure_variant_mortality.tex`.
- Distance benchmarks: generic and specialty-aware rules summarized in `table_flow_vs_distance_benchmarks.tex`; estimable distance event studies summarized in `table_distance_benchmark_results.tex`; rules with zero controls are explicitly reported as support failures.
- First-stage decomposition: descriptive utilization decomposition regenerated in `table_first_stage_decomposition.tex` and `fig_first_stage_decomposition_eventstudy.pdf`; available for 30 PNASH closures with sufficient SIH edge support.
- Network spillovers: mortality re-estimated after excluding contaminated controls in `table_spillover_sensitivity.tex`.
- Closure influence: top leave-one-closure-out changes reported in `table_closure_influence.tex`; full figures already exist for suicide and self-harm.
- Mortality scaling: upper-bound deaths/year and deaths per 1,000 psychiatric AIH episodes reported in `table_mortality_bounds_scaled.tex` and `02_data/processed/mortality_bounds_scaled.csv`.
- Editorial compression/reframing: main text now foregrounds hospital-closure exposure measurement, limits mortality claims to PNASH psychiatric closures, demotes ML/LLM machinery, and removes rhetorical/forbidden phrases.

## Checks run
- `python3 03_analysis/check_sample_consistency.py --force`: passed; F5=60, PNASH=48, nonpsychiatric=19, failed-F5=30; flow-distance disagreement=293/337.
- `pdflatex`, `bibtex`, `pdflatex`, `pdflatex`: final PDF built at `01_manuscript/main.pdf` (61 pages).
- Text audit found no active forbidden phrases. The only remaining LaTeX messages are non-fatal float/underfull/overfull warnings.

## Remaining risks
- PNASH facility scores and formal de-accreditation indicators are not in the local data.
- Psychiatric-specific exposure denominators produce much broader treated support; the manuscript now treats them as stress tests rather than a silent replacement for the main rule.
- Specialty distance rules that classify all municipalities as exposed are not separately estimable; the table reports that limitation directly.
- First-stage decomposition is descriptive and available for 30 PNASH closures, so the mechanism language remains bounded.
