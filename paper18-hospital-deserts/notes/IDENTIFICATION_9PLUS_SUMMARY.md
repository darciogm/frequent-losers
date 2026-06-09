# Identification Upgrade to 9+/10 — Implementation Summary (2026-06-09)

Targeted upgrade of the causal identification strategy for
*"Where Patients Go When a Hospital Closes: Evidence from Brazil"* (JHE target).
Goal: make a demanding referee say "not randomized, but the design is credible."
The paper was already mature; this was **gap-filling and honest reconciliation**,
not a rebuild. Main text grew ~1 page (28pp); the online appendix carried the new
evidence (7 → 14pp). No headline number changed.

## Files modified (manuscript)
- `01_manuscript/method.tex` — Section 4.2 rewritten end-to-end (timing condition,
  precise PNASH sample definitions, four-probe structure, honest HonestDiD, SDID as
  load-bearing second design, spillover, limits).
- `01_manuscript/results.tex` — §5.4 HonestDiD **overclaim corrected**; SDID + spillover
  now carry the bounded-null robustness sentence.
- `01_manuscript/introduction.tex` — added "in a stricter exact ±1-year PNASH-window
  sample" to the robustness sentence (Task J). Abstract unchanged (no headline change).
- `01_manuscript/discussion.tex` — §7.4 limitations: added the CAPS/outpatient-substitution
  limitation (now five limitations).
- `01_manuscript/online_appendix.tex` — restructured: new PNASH timing section (enriched
  event-level table, strict-window table, timing tests, raw pre-trend figure), new SDID
  section (table + pre-fit figure), new pre-trend-sensitivity section (HonestDiD table + 3
  figures), CAPS heterogeneity table; added `subcaption`, `rotating`, `\bibliography`.
- `03_analysis/D6_make_values.R` — SDID macros repointed to auditable script 85; added
  22 new macros (strict window, SDID self-harm/donors/cohorts/RMSE, timing tests, CAPS).
- `notes/VARIABLE_GAPS.md` — appended the identification-upgrade gaps.

## Scripts created
- `03_analysis/81_pnash_strict_window.R` — strict 37-closure exact-window robustness.
- `03_analysis/82_enrich_pnash_event_level.py` — closure-level event table (23 cols).
- `03_analysis/83_preclosure_timing_tests.R` — timing-predictor tests.
- `03_analysis/84_honestdid_sensitivity.R` — HonestDiD reconciled to headline + ICSAP.
- `03_analysis/85_sdid_full.R` — fully documented SDID (suicide + self-harm + diagnostics).
- `03_analysis/86_caps_heterogeneity.R` — baseline-CAPS heterogeneity / limitation.
- `03_analysis/87_spillover_distinct_flags.R` + `87a_build_distinct_spillover_flags.py` —
  de-aliased, genuinely distinct contamination flags.

Outputs: matching `02_data/processed/*.csv`/`*.parquet`, `01_manuscript/tables_appendix/*.tex`,
`04_figures_appendix/*.pdf`, and `04_logs/*_20260609.log` for each. Obsolete tables archived
to `01_manuscript/_archive/` (not deleted).

## Main identification changes
1. **48-vs-37 PNASH window** resolved explicitly in code and text: `PNASH_cycle_window`
   (48, ±1yr of either year of a 2-year cycle) vs `PNASH_exact_pm1` / strict (37, ±1yr of
   nearest single cycle year). The 11-closure gap = the 2014 cohort, distance 2 from 2011–12.
2. **Closure-level event table** documents all 48 events for direct audit.
3. **Pre-closure timing tests** reported transparently and honestly.
4. **Raw treated-vs-control pre-trend plots** added to appendix (Task D).
5. **HonestDiD reconciled to the headline pop-weighted spec** and reported honestly.
6. **SDID promoted to load-bearing second design**, fully documented.
7. **Spillover de-aliased** into four genuinely distinct contamination rules.
8. **CAPS** addressed via heterogeneity + explicit limitation.

## Key results (all from generated outputs)
**Main PNASH sample (48, pop-weighted Sun-Abraham):** suicide +0.28 [−0.72, +1.29] (baseline
5.01); self-harm +0.61 [−0.90, +2.12]; psych admissions −7.32 per 1k (≈ −69%); travel −1.73.

**Strict PNASH sample (37):** suicide +0.42 [−0.68, +1.51]; self-harm +0.89 [−0.75, +2.53];
psych admissions −7.32; travel −2.09. **Null preserved.**

**SDID (size-weighted, 4 cohorts, 5,460 donors, pre-fit RMSE/level 0.24, placebo p=0.84):**
suicide −0.22 [−1.80, +1.36]; self-harm +0.73 [−1.14, +2.59]; psych admissions not estimable
(unbalanced cohort blocks — reported NA, not fabricated). Converges with the event study.

**HonestDiD (honest finding):** reconciled exactly to headline +0.28. At the per-100k scale of
small municipalities the mortality series is too noisy for relative-magnitude restrictions —
robust set widens rapidly, breakdown M̄ = 0. The mortality bounded-null therefore rests on the
**classical interval + SDID**, not on trend extrapolation. The same machinery correctly fails
to rescue **ICSAP** (no M̄ excludes zero), validating the placebo. The prior manuscript claim
that the null "survives violations bounded by the largest pre-period deviation" was an
**overclaim and has been corrected.**

**Timing predictors (honest nuance):** closure timing is not predicted by baseline conditions
(joint F p=0.25) or early-vs-late status (p=0.18); a noisier closure-level pre-trend test is
marginal (joint p=0.07; two of five slopes individually p≈0.04). The panel event-study
pre-periods the estimator uses are flat, and the SDID matches each cohort's pre-closure path,
neutralizing this concern. Stated plainly in the text — not papered over.

**Spillover:** four genuinely distinct exclusions (health-region, referral hub, substitute
hospital via recipient flow, high flow-similarity) — null survives all (substitute-exclusion
suicide −0.04 [−0.98, +0.90]; any-contaminated +0.01 [−0.93, +0.95]).

**CAPS heterogeneity:** no detectable suicide differential by baseline CAPS presence
(High 21 vs Low 83 munis; difference p=0.75); a self-harm wrinkle (p=0.04) is one of several
underpowered comparisons. CAPS is facility-count only (no capacity, ends 2016) → documented
limitation; mediation channel cannot be tested directly.

## Remaining identification risks (cannot be solved without new data)
- Not randomized; N=48 closures bounds large effects, not small ones.
- CAPS **capacity** (beds, SRT, outpatient production) and FHS/private-insurance penetration
  unavailable locally → outpatient-substitution mechanism untestable.
- PNASH numeric inspection scores and a formal de-accreditation microrecord not in public data
  (registry status available for 35/48).
- Per-100k mortality noise makes relative-magnitude sensitivity uninformative for mortality.
- Municipal, not individual, mortality; SUS-using population only.

## Build
`cd 01_manuscript && pdflatex -interaction=nonstopmode main && bibtex main && pdflatex main && pdflatex main`
(same for `online_appendix`). Both compile clean: 0 undefined control sequences, 0 undefined
references/citations. main.pdf = 28pp, online_appendix.pdf = 14pp.
