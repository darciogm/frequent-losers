# Disagreement-placebo — summary (branch `paper18-disagreement-placebo`)

Exposure-validation placebo: does the first stage load on flow-revealed reliance or
on geographic proximity? Built on the canonical exposure flags; headline mortality
estimates untouched.

## Files created / modified

Created:
- `03_analysis/95_build_disagreement_groups.py` — groups + mutually-exclusive cohorts + event panel.
- `03_analysis/96_estimate_disagreement_placebo.R` — Sun-Abraham event studies by group.
- `03_analysis/97_fig_disagreement_first_stage.py` — first-stage figure.
- `02_data/processed/disagreement_groups_long.parquet`, `disagreement_groups_summary.csv`,
  `disagreement_event_panel.parquet`, `disagreement_placebo_results.csv` (gitignored data).
- `01_manuscript/tables_appendix/table_disagreement_placebo_full.tex` (appendix table).
- `04_figures/fig_disagreement_first_stage.pdf` (appendix figure).
- `04_logs/disagreement_groups_*.log`, `disagreement_placebo_*.log`.
- `notes/DISAGREEMENT_PLACEBO_INTERPRETATION.md`.

Modified:
- `01_manuscript/online_appendix.tex` — new subsection "Exposure-validation placebo".
- `run_pipeline.sh` — steps 95–97.

NOT modified: `main.tex`, `results.tex`, `setting.tex`, `introduction.tex` — headline
mortality estimates untouched (suicide ATT still +0.28; main 30pp compiles clean).

## Counts by group (mutually exclusive municipality cohorts)

| Sample | flow_only | distance_only | both | mixed | pairs flow/dist/both/union |
|---|---|---|---|---|---|
| F5 measurement (60 closures) | 86 | 129 | 40 | 1 | 97 / 196 / 44 / 337 |
| PNASH psychiatric (48 closures) | 74 | 102 | 27 | 0 | 82 / 162 / 30 / 274 |

F5 reproduces the paper's 97/196/44/337 exactly.

## Estimates by group (PNASH, vs never-flagged controls)

| Outcome | flow_only | both | distance_only |
|---|---|---|---|
| Travel burden (km) | **−6.57** [−10.7,−2.4] p=0.07 | −0.53 [−2.1,+1.0] p=0.00 | **−4.32** [−5.0,−3.7] p=0.00 |
| Psych adm /1,000 | **−3.74** [−4.5,−3.0] **p=0.30** | −8.87 [−14.7,−3.1] p=NA | −0.95 [−1.6,−0.3] p=0.00 |
| Suicide /100k | −0.53 [−2.1,+1.1] | +0.57 [−0.6,+1.7] | −0.13 [−0.6,+0.3] |
| Self-harm /100k | +1.89 [−0.3,+4.1] | +0.33 [−1.2,+1.9] | −1.38 [−2.5,−0.3] p=0.00 |

F5 travel burden: flow_only −5.47 (p=0.16), distance_only −4.71 (p=0.00).

## Does distance-only behave like controls? Does flow-only carry the first stage?

- **Flow-only carries the first stage**: psychiatric admissions −3.74 per 1,000 with
  flat pre-trends (p=0.30); travel −6.57 (p=0.07). Yes.
- **Distance-only does NOT behave like a clean control**: it moves (travel −4.32,
  admissions −0.95), but every distance-only pre-trend fails (p=0.00) — the movement
  is differential-trend contamination, not a clean closure response.
- **The discriminating outcome is psychiatric admissions, not travel burden.** On
  admissions, flow-only loses 4× the distance-only volume, with clean vs failed
  pre-trends. On travel burden, both move (travel falls mechanically for any nearby
  municipality), so it does not separate the groups.

## Recommendation: appendix only

This is the spec's **middle decision rule** (flow-only strong, distance-only modestly
nonzero), sharpened by the pre-trend contrast. **Appendix inclusion: yes** (table +
figure, full diagnostics). **Bold main-text claims (intro sentence G, §5.1 "distance-
only do not respond"): NO** — false for travel burden, overstated for admissions.
At most a nuanced one-sentence main-text mention, author's call.

**Exact sentence supported** (nuanced, admissions-based, pre-trend-aware):
> "Splitting the disagreement set, flow-flagged municipalities show the psychiatric-
> admission first stage with flat pre-trends—admissions fall by about 3.7 per 1,000—
> four times the movement among distance-only false positives, whose smaller change
> fails the pre-trend test; the first stage loads primarily on revealed reliance, not
> proximity. Travel burden, which shifts mechanically for any nearby municipality,
> does not discriminate the two groups."

## Build status

- Online appendix: 18→19 pp, compiles exit 0, 0 undefined refs, 0 `??`.
- Main: 30 pp, unchanged, compiles clean; headline suicide ATT +0.28 intact.

## Remaining risks

- A referee could read distance-only's nonzero ATT as "distance also captures
  exposure." The honest rebuttal is the pre-trend failure, not a zero estimate.
- "Both" group is small (n=27), statistically fragile; report directionally.
- Travel burden's mechanical movement must always be disclosed where shown.
