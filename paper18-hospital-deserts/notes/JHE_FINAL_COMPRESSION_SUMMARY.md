# JHE Final Compression Summary

Date: 2026-06-08

## Build Status

- Main manuscript: `01_manuscript/main.pdf`
- Online appendix: `01_manuscript/online_appendix.pdf`
- Main build command used:
  - `cd 01_manuscript && pdflatex -interaction=nonstopmode main && bibtex main && pdflatex -interaction=nonstopmode main && pdflatex -interaction=nonstopmode main`
- Online appendix build command used:
  - `cd 01_manuscript && pdflatex -interaction=nonstopmode online_appendix && pdflatex -interaction=nonstopmode online_appendix`
- Final main page count: 21 pages, including references.
- Final online appendix page count: 7 pages.
- Length targets met: yes. Main is below 38 pages; appendix is below 16 pages.
- LaTeX status: both PDFs compile. Final logs report no undefined references, missing citations, LaTeX errors, or fatal errors.

## Files Modified

- `01_manuscript/main.tex`
- `01_manuscript/introduction.tex`
- `01_manuscript/setting.tex`
- `01_manuscript/data.tex`
- `01_manuscript/method.tex`
- `01_manuscript/results.tex`
- `01_manuscript/robustness.tex`
- `01_manuscript/discussion.tex`
- `01_manuscript/conclusion.tex`
- `01_manuscript/online_appendix.tex`
- `03_analysis/74_jhe_compression_package.py`
- `run_pipeline.sh`

The old integrated appendix file remains in the repository but is no longer compiled into `main.pdf`.

## Scripts Created or Modified

- Created/updated `03_analysis/74_jhe_compression_package.py`.
  - Generates compact main-text tables.
  - Generates appendix-support tables.
  - Creates risk-set-aware distance benchmark outputs.
  - Copies detailed robustness tables into `01_manuscript/tables_appendix/`.
- Updated `run_pipeline.sh`.
  - Adds step `74`.
  - Uses `python` when available and falls back to `python3` otherwise.

## Main-Text Exhibits Kept

The main paper now has 7 core exhibits:

1. `01_manuscript/tables/table_sample_architecture_compact.tex`
2. `01_manuscript/tables/table_measurement_compact.tex`
3. `04_figures/fig_flow_distance_disagreement_f5.pdf`
4. `01_manuscript/tables/table_pnash_identification_summary.tex`
5. `04_figures/fig_first_stage_decomposition_eventstudy.pdf`
6. `01_manuscript/tables/table_main_mortality_scaled_bounds.tex`
7. `04_figures/fig_es_mortality.pdf`

## Appendix Exhibits Kept

The online appendix keeps only referee-relevant detail:

- Closure-sample construction and F0-F5 sample table.
- PNASH event-level closure table.
- Full pre-closure predictor and true pre-treatment balance tables.
- Full distance benchmark and exposure-variant tables.
- Full first-stage decomposition and top substitute-destination tables.
- Spillover, closure-influence, and HonestDiD sensitivity tables.
- Remaining data caveats table.

Non-essential ML, LLM, embedding, causal forest, and graph perturbation material is excluded from the submitted online appendix and left to replication notes / non-submitted diagnostics.

## Outputs Generated

- `01_manuscript/tables/table_sample_architecture_compact.tex`
- `01_manuscript/tables/table_measurement_compact.tex`
- `01_manuscript/tables/table_pnash_identification_summary.tex`
- `01_manuscript/tables/table_main_mortality_scaled_bounds.tex`
- `01_manuscript/tables_appendix/table_distance_benchmark_full.tex`
- `01_manuscript/tables_appendix/table_pnash_event_level.tex`
- `02_data/processed/distance_benchmarks_risksets.parquet`
- `02_data/processed/distance_benchmark_compact.csv`
- `04_logs/74_jhe_compression_package_20260608_155819.log`
- `04_logs/sample_consistency_audit_20260608.log`

## Final Sample Counts

- F5 measurement sample: 60 economically meaningful closures.
- PNASH psychiatric causal sample: 48 closures.
- General-hospital F5 contrast sample: 18 closures.
- Hospital-day F5 contrast sample: 1 closure.
- Nonpsychiatric F5 contrast sample: 19 closures.
- Failed-F5 predecline diagnostic sample: 30 closures.
- F5 measurement disagreement: 293 misclassified pairs out of 337 municipality-closure pairs flagged by either flow or distance.

## Final Main Mortality Estimates

Main causal sample: PNASH psychiatric causal sample.

- Suicide mortality: ATT = +0.28 per 100,000; 95% CI = [-0.72, +1.29].
- Self-harm mortality: ATT = +0.61 per 100,000; 95% CI = [-0.90, +2.12].
- Scaled suicide upper bound: about 37.7 additional deaths per year across exposed catchments, or 1.26 per 1,000 pre-closure psychiatric AIH episodes.
- Scaled self-harm upper bound: about 61.9 additional deaths per year, or 2.07 per 1,000 pre-closure psychiatric AIH episodes.

The abstract and results now use the bounded interpretation: no evidence of large acute increases, while smaller harms and non-mortality welfare losses remain unresolved.

## Checks Passed

- Main PDF builds.
- Online appendix PDF builds.
- Main page count under 38.
- Appendix page count under 16.
- Main text has exactly 7 core exhibits.
- Sample consistency audit passed for F5, PNASH, nonpsychiatric F5, hospital-day F5, and failed-F5 counts.
- No undefined LaTeX references or citations in final logs.
- Phrase audit found no forbidden phrases in manuscript, appendix, or generated tables.
- PDF text audit found no Portuguese labels in the submitted PDFs.
- Abstract numbers match generated mortality-bound table.

## Remaining Risks

- PNASH score and formal de-accreditation micro-indicators are not available locally; the appendix table states this.
- Travel-time distance benchmarks are not implemented because no travel-time matrix is available locally.
- Private insurance penetration and some fiscal-capacity measures remain unavailable without external ANS/SICONFI pulls.
- The PNASH identification evidence remains supportive rather than definitive; the manuscript now phrases closure timing as plausibly orthogonal conditional on checks, not randomized.
- The nonpsychiatric F5 sample is kept as contrast evidence only, not a second causal application.

