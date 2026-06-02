# 06 — NEXT PROMPTS CHECKLIST (JLEO R&R v22)

Execution order for the section-by-section revision. Each next prompt = one bounded pass. Do NOT skip ahead: CP-1 (label funnel) gates the validation claims; CP-2/CP-3 gate the abstract/intro rewrite. Success/failure conditions are gate-driven (no overclaiming).

All work in `work/v22-editor/`, branch `v22`. Bind every new number into `values.tex` by hand with `% src:` comments (never re-run script 99).

---

### Prompt 1 — Transversal 2: reproducibility infrastructure & output-registry implementation
> **STATUS: ✅ COMPLETED 2026-06-02 (Subprompt 1 = label funnel script 79; Subprompt 2 = metrics/cost/exposure/label utilities + 4 scanners + registries + Makefile + 22-assertion metrics test passing). Infra is GO.**
- **Objective:** make the pipeline reproducible enough for a JLEO replication package skeleton; create `scripts/79_label_funnel.R` regenerating cobidder/crossmatch links; write `output/` manifest; de-hard-code the worst paths.
- **Expected files:** NEW `scripts/79_label_funnel.R`, `work/v22-editor/README_replication.md`, manifest under `docs/jleo_rr_revision/`.
- **Expected outputs:** `output/label_funnel/funnel.csv`, `case_timing.csv`.
- **Success:** funnel.csv reproduces 12→47→193 from data; case→cobidder map materialized.
- **Failure:** if 210/108/30 cannot be derived → log as confirmed-irreproducible, escalate U2 to user (retire vs replace).

### Prompt 2 — Sections 1–3 (abstract, intro, institution, layers, ranking)
- **Objective:** reframe as enforcement-design under costly observability; JLEO-fit contribution para; abstract ≤150 words bound to verified macros.
- **Expected files:** `sec_frontmatter`, `sec01`, `sec02`, `sec03`, `values.tex`.
- **Expected outputs:** Tables F (unit-of-analysis) + G (case timing) drafted.
- **Success:** abstract ≤150 words, no affirmative forbidden terms, contribution names ≥3 literature gaps.
- **Failure:** if abstract leans on CP-1/CP-2 numbers not yet locked → defer those sentences.
- **DEPENDS ON:** Prompt 1 (funnel for Table A teaser), CP-2/CP-3 numbers.

### Prompt 3 — Section 4A: label funnel & 193 vs 210 reconciliation
- **Objective:** Table A + App C rebuild; resolve FL-only-vs-always-loser labeling; retire/replace 210/108/30.
- **Expected files:** `sec04` §4.1, `sec_app02`, `values.tex`.
- **Expected outputs:** inline Table A from `output/label_funnel/funnel.csv`.
- **Success:** every target count traces to a script line; no unsourced literal remains.
- **Failure:** unresolved count → mark BLOCKED in-text is NOT allowed for a submission; must retire the claim instead.
- **DEPENDS ON:** Prompt 1.

### Prompt 4 — Section 4B: opportunity-adjusted validation
- **Objective:** promote script 76 to §4.2 core; Table B; observed-vs-expected figure; bind exposure macros.
- **Expected files:** `sec04` §4.2, `sec_app03` (demote), `values.tex`, NEW figure script.
- **Expected outputs:** Table B; `fig_obs_vs_expected_bin.pdf`.
- **Success:** §4.2 leads with within-stratum AUC 0.7715 + increment +0.0415 (p<0.001) AND states exposure-only=0.946.
- **Failure:** if extra strata (buyer/item-group) erase the increment → demote to "partial exposure artifact," do not headline.

### Prompt 5 — Section 4C: timing, leakage, rolling origin, leave-one-case-out
- **Objective:** Table C; report 53 (binary>cont flip) + 77 (FAIL, observational equivalence) honestly; add LOCO via `80`.
- **Expected files:** `sec04` §4.3, NEW `scripts/80_leave_one_case_out.R`, `values.tex`.
- **Expected outputs:** Table C; LOCO distribution figure.
- **Success:** timing limitation disclosed verbatim; LOCO runs at cobidder level.
- **Failure:** LOCO blocked (CP-1 incomplete) → report defendant-level LOCO + flag cobidder-level as pending.
- **DEPENDS ON:** Prompt 1 (case linkage).

### Prompt 6 — Section 5: economic profile, monotonicity, binary vs continuous
- **Objective:** §5 with volume-matched profile (`74`); disclose binary>continuous strict-pool flip; integrate that 193 are FL-only.
- **Expected files:** `sec05`, `values.tex`.
- **Success:** binary-vs-continuous framed as operationalization, flip disclosed.
- **Failure:** if matched profile erases cobidder distinctness → reframe per A4 fallback.

### Prompt 7 — Section 6A: bid-layer benchmark audit
- **Objective:** Table E; document Imhof features/learner/CV/missingness/case-holdout; complementarity not dominance.
- **Expected files:** `sec06` §6.1-6.2, `sec_app06`, `values.tex`.
- **Success:** benchmark fully specified; "comparable at lower cost" language.
- **Failure:** if leakage controls drop Imhof AUC materially → report honestly.

### Prompt 8 — Section 6B: cost-recall frontier & sequential gatekeeping
- **Objective:** RUN script 56; extend 63 to K1×cost grid; Table D; PR/lift curves; replace "83%" with frontier.
- **Expected files:** `sec06` §6.3-6.4, `scripts/56` (run), extend `63`, `values.tex`.
- **Expected outputs:** `output/regulatory_frontier/*`, `fig_regulatory_frontier.pdf`, PR curve.
- **Success:** gatekeeper reported as frontier; PR-AUC/precision@k/recall@k/FP/FN present.
- **Failure:** if recall collapses at affordable K1 → frame as budget-regime-specific.

### Prompt 9 — Section 7: price scope & legal-economic downgrade
- **Objective:** price = scope/corroborative only; integrate script 78 (theater not identified); drop damages/overcharge/causal.
- **Expected files:** `sec07`, `sec_app04`, `values.tex`.
- **Success:** no damages/overcharge/causal claim; theater mechanism removed or marked unproven.
- **Failure:** none expected — this is a downgrade.

### Prompt 10 — Appendix B: theory, exit, survival/hazard
- **Objective:** add asymmetric exit/survival margin to λ_C>λ_G; NEW `81_survival_hazard.R`.
- **Expected files:** `sec_app01`, NEW `scripts/81_survival_hazard.R`, `values.tex`.
- **Expected outputs:** survival table; KM plot (if feasible).
- **Success:** exit margin formalized; censoring disclosed.
- **Failure:** if hazard uninformative under censoring → keep as bounding argument in prose.

### Prompt 11 — Appendices C–G: construction, exposure audits, price appendix, adaptation, gatekeeping
- **Objective:** finalize all appendix tables from script outputs (no hand-typed bodies); decide ComprasNet app07 (U1).
- **Expected files:** `sec_app02`–`sec_app06`, optionally delete `sec_app07`, `values.tex`.
- **Success:** zero hard-typed table bodies remain; appendix master `\bibliography` fixed.
- **Failure:** orphaned app07 left half-in → must resolve.

### Prompt 12 — Final integration: JLEO compliance, replication package, response matrix, compile
- **Objective:** JLEO compliance audit (abstract ≤150w, JEL, double-space final, alt text ×2 figs, Bluebook cites); fill referee-response matrix; clean compile of paper+appendix.
- **Expected files:** all; `docs/jleo_rr_revision/02_…` (status→implemented), cover letter, compliance doc.
- **Expected outputs:** compiled `paper_submission_clean.pdf` + `online_appendix_submission_clean.pdf`; response-to-referees draft.
- **Success:** both compile clean; matrix all-green or blockers explicitly escalated; compliance checklist passes.
- **Failure:** any unresolved ⛔ blocker → list in cover note, do not paper over.

---

## Sequencing notes
- **Gate order:** Prompt 1 → 3 → 4 → 5 unlock the validation core; 2 (abstract/intro) is written AFTER 4/5 numbers lock even though it appears first in the paper.
- **Parallelizable (independent):** Prompt 7 (bid-layer audit) and Prompt 9 (price downgrade) and Prompt 10 (theory) can be done in any order once CP-1 is clear.
- **Hard dependencies:** 3,5 ← Prompt 1 (funnel/linkage). 8 ← run script 56. 10 ← new script 81.
- **Each prompt ends with:** re-run forbidden-term scan; bind new macros with `% src:`; update `02_REFEREE_RESPONSE_MATRIX_INTERNAL.md` status.

---

## Subprompt 2 close-out (2026-06-02)
- ✅ Reproducibility infrastructure COMPLETE: `scripts/utils/{metrics_triage,cost_frontier,exposure_validation,label_funnel}.R`, `scripts/diagnostics/{scan_claims,scan_numbers,scan_refs,scan_alt_text,test_metrics_triage}.R`, `scripts/build/make_registries.R`, `Makefile`, `outputs/{output_registry,dataset_registry}.csv`, `outputs/diagnostics/*`.
- ✅ `make diagnostics`, `make audit`, `make jleo_rr_status` all run end-to-end. Metrics toy test: 22/22 PASS.
- **NEXT PROMPT confirmed: "Sections 1–3 — abstract, introduction, institution, award/bid layers, ranking."** No infrastructure failure requires repair first.
- ⚠ Gating reminder: the abstract (Prompt 2 / Sections 1–3) leans on §4 counts. U2 is RESOLVED (disclose 193 primary + 341 robustness; drop 30→19), so Sections 1–3 may proceed, but the cobidder sentence must use the U2-disclosed framing and must NOT assert "results materially unchanged" until a core AUC is re-run under the 341 label.

---
