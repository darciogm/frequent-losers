# Wow-Factor Calibration — Summary (2026-06-09)

Targeted calibration of mechanism, title fulfillment, and front-page punch for
JHE. Goal: make the title's promise ("Where Patients Go When a Hospital Closes")
literal by adding a *displacement* step — pre-closure flows identify who depended
on the provider; post-closure, the data show whether that inpatient use reappears
elsewhere. It does not: other hospitals do not absorb the lost psychiatric volume.
No new conceptual frame, no new headline number, paper kept concise (+1 page).

## New result added to the paper

Psychiatric-specific displacement decomposition (the all-cause script 52 carried a
self-flagged caveat that this "requires a dedicated SIH edge rebuild" — now done).
Catchment-level mean inpatient psychiatric admissions (ICD-10 F00–F99), event years
−3..−1 vs +1..+3, across the **30 PNASH closures with flow support**:

| Inpatient psychiatric admissions | Pre | Post | Change |
|---|---|---|---|
| To the closing hospital | 596 | 0 | −596 |
| To other hospitals | 430 | 379 | −51 (−12%) |
| **Total (any hospital)** | 1,026 | 379 | **−647 (−63%)** |

**Mechanism:** other hospitals do **not** absorb the lost volume — their
psychiatric admissions *fall* (−12%), not rise. The 63% descriptive net drop is
consistent with the 69% event-study headline (which remains THE headline number).
This is a net loss of inpatient psychiatric care, not a hospital-to-hospital
reallocation.

## Files modified

Manuscript:
- `01_manuscript/main.tex` — abstract sentence (B); `\input{values_displacement.tex}`.
- `01_manuscript/introduction.tex` — two-step displacement mechanism in "The closures bite" para (A).
- `01_manuscript/results.tex` — §5.2/5.3/5.4 retitled to exposure→displacement→mortality (E); displacement paragraph + compact table + new figure inserted in §5.3; outpatient/CAPS one-sentence limitation (G); bridge sentence into §5.4.
- `01_manuscript/conclusion.tex` — first two paragraphs return to title + displacement (H).
- `01_manuscript/discussion.tex` — "displaced patients" → "displaced volume" (F).
- `01_manuscript/setting.tex` — "abrupt loss of care" → "abrupt loss of inpatient care" (F).
- `01_manuscript/online_appendix.tex` — `\input{values_displacement.tex}`; new "Psychiatric displacement decomposition" subsection with full table.

Analysis / outputs created:
- `03_analysis/88_psych_displacement_decomposition.py` — builds psych edge list + decomposition.
- `03_analysis/89_fig_where_inpatient_use_goes.py` — builds the figure.
- `02_data/intermediate/bipartite_edges_psych.parquet` — F00–F99 SIH edges (cached, `--force`).
- `02_data/processed/psych_displacement_panel.parquet` — cnes × event_time panel (figure input).
- `02_data/processed/displacement_decomposition.csv` — machine-readable summary.
- `01_manuscript/tables/table_displacement_compact.tex` — main-text table.
- `01_manuscript/tables_appendix/table_displacement_full.tex` — appendix table (by event time).
- `01_manuscript/values_displacement.tex` — LaTeX macros (single source of truth for new numbers).
- `04_figures/fig_where_inpatient_use_goes.pdf` — the visual answer to the title.
- `04_logs/displacement_decomposition_20260609.log` — telemetry.

## Figure / table that answers "where inpatient use goes"

- **Figure** `fig:where-inpatient-use-goes` (`fig_where_inpatient_use_goes.pdf`): three
  event-time lines — closing hospital collapses to 0; other hospitals flat→slightly
  down; total falls and stays down. Mechanism legible in ~20s.
- **Table** `tab:displacement-compact` (main §5.3) + `tab:displacement-full` (appendix).

## Wording changes ("care" → "inpatient psychiatric care")

- Abstract: "a net loss of care" → "a net loss of inpatient psychiatric care rather
  than a reallocation to other hospitals, which do not absorb the lost volume."
- setting.tex: "abrupt loss of care" → "abrupt loss of inpatient care."
- discussion.tex: "displaced patients" → "displaced volume."
- No individual-level patient-tracking language remains in the body (the title's
  broad "Where Patients Go" is intentional and unchanged).

## New macros (all trace to `displacement_decomposition.csv`)

`\valPsychDispNClosures`=30, `\valPsychClosingPre`=596, `\valPsychOtherPre`=430,
`\valPsychOtherPost`=379, `\valPsychOtherChange`=51, `\valPsychOtherDeclinePct`=12,
`\valPsychTotalPre`=1,026, `\valPsychTotalPost`=379, `\valPsychDispNetDropPct`=63.
Headline `\valPsychAdmPct`=69 (event study) unchanged.

## Page counts / build status

- Main: **29 pp** (was 28). Appendix: **14 pp**.
- `latexmk main.tex` → exit 0, **0 undefined refs, 0 errors, 0 `??`**.
- `latexmk online_appendix.tex` → exit 0, **0 undefined refs, 0 `??`**.

## Causal upgrade of non-absorption (added in second pass)

The descriptive "do not absorb" claim was upgraded to causal. A staggered
Sun-Abraham event study (identical spec to the headline) re-estimated with the
outcome redefined as inpatient psychiatric admissions at hospitals *other* than
the focal closing hospital, per 1,000 residents:

- **Other hospitals: ATT = +0.08 per 1,000, 95% CI [−0.74, +0.91]** (base 3.32,
  +3% of base), flat pre-trends (p = 0.52) — a precise null.
- Robustness: clean subsample (97 treated with identified closing) +0.23
  [−0.55, +1.01]; municipality-weighted −0.03 [−0.61, +0.54]. All null.
- Sanity: same spec on **total** admissions reproduces **−69%** (ATT −7.32,
  base 10.66) — confirms the panel is correctly wired.

Interpretation: total inpatient psychiatric admissions fall 69% while other-hospital
admissions are statistically unchanged. The CI upper bound caps absorption at
~12% of the lost volume; the point estimate is ~1%. The trend-netted estimate
(~0) **supersedes** the raw descriptive −12%; body prose (intro, §5.3, conclusion)
now leads with the causal null, not the descriptive figure. The descriptive
−12%/−63% remain only in the appendix decomposition table as raw levels.

New files: `03_analysis/90_build_other_hosp_psych_panel.py`,
`03_analysis/91_other_hosp_event_study.R`,
`02_data/processed/other_hosp_psych_panel.parquet`,
`02_data/processed/other_hosp_event_study.csv`,
`04_figures/fig_es_other_hosp_psych.pdf`,
`01_manuscript/tables_appendix/table_other_hosp_es.tex`,
`01_manuscript/tables_appendix/table_psych_intensity.tex` (intensity pre-emption).
New macros: `\valOtherHospATT/Lo/Hi/Base/Pct/Ppre`, `\valPsychLOSClosing/Other`,
`\valPsychBeddaysDropPct`. Appendix now 16 pp; main 29 pp. Both compile clean.

Where did the lost volume go (intensity evidence, appendix Table~psych-intensity):
the disappeared admissions were full-intensity care (LOS 24 vs 23 days at
surviving hospitals; bed-days fall 66% vs admissions 63%), not custodial volume —
so the residual most plausibly shifted to community/outpatient (CAPS, unobserved)
or to unmet need; neither is identifiable from inpatient records.

## Remaining risks

1. **Descriptive vs causal — RESOLVED.** The non-absorption is now causal: the
   trend-netted other-hospital event study (ATT +0.08, CI [−0.74, +0.91]) shows
   admissions at other hospitals are statistically unchanged while total falls 69%
   (see "Causal upgrade" above). The descriptive decomposition is retained only as
   the intuitive companion; body prose leads with the causal estimate.
2. **Catchment = all-cause 5% flow rule.** Catchment membership uses the paper's
   all-cause flow exposure (consistent with `exposure_panel`), while the measured
   outcome is psychiatric-only. This mirrors the main design but a referee may ask
   for a psych-flow-defined catchment robustness check.
3. **Outpatient (CAPS) substitution unobserved.** Stated as a limitation in §5.3 and
   Discussion; only coarse baseline CAPS capacity is in the appendix. Cannot rule
   out outpatient absorption of displaced demand.
4. **Pre-existing embedding/network material** remains in replication-adjacent
   content (e.g., Figure 1 caption *explicitly states it does not use the
   embedding*). Not part of the main contribution; left untouched per scope.
5. **Title still differs from last commit message** ("Closure Without Catastrophe").
   Current title preserved per instruction; reconcile commit framing separately.
