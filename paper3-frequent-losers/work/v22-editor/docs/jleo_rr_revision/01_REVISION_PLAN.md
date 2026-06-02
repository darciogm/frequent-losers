# 01 — REVISION PLAN (JLEO R&R, v22)

Objective: convert the paper into a defensible **enforcement-design paper about evidence allocation under costly observability**, with the opportunity-adjusted validation as the empirical core. Maximize P(serious R&R). No overclaiming; honest about the two limitations the run-artifacts already expose (timing observational-equivalence; theater-not-identified).

Branch `v22`, dir `work/v22-editor/`. Risk legend: 🟢 low / 🟡 medium / 🔴 high. "Data-blocked?" flags dependence on data not yet materialized.

---

## 1. Critical path to JLEO R&R

Ordered. Each must clear before the next *claim* leans on it.

### CP-1 — Label funnel & sample reconciliation (193 vs 210)
- **Objective:** one executable funnel reconciling every target count: raw CADE procs (12) → BEC-active direct defendants (47/48/49) → cobidders → always-loser cobidders → FL cobidders (193) → conservative pre-2020 subset (claimed 4 cases / 30 def / 210 / 108). Resolve the 193="FL-only but labeled always-loser" inconsistency and the unsourced 210/108/30.
- **Why referees care:** the validation target is the paper's ground truth; an unreconstructable, internally-inconsistent target count is a desk-reject-grade hole (Referee #4).
- **Files to edit:** `sec04_validation_submission.tex` (§4.1), `sec_app02_data_labels_submission.tex` (App C label tables), `values.tex` (rebind/retire 210/108/30 macros).
- **Scripts to modify/create:** NEW `scripts/79_label_funnel.R` — rebuild case→defendant→cobidder linkage from `firm_tender_map ⋈ cade_bec_crossmatch` (keys `numerodaoc,códigoitem,firm_cnpj`), attach `data_julgamento`, emit every funnel count to `output/label_funnel/funnel.csv`. Verify FL `>` vs `≥`.
- **Outputs:** `output/label_funnel/funnel.csv`, Table A, rebuilt App C label table.
- **Risk:** 🔴 — 210/108/30 may be **irreproducible**; if so they must be *retired/replaced* with data-derived numbers, not patched. **Data-blocked?** PARTIAL (case→cobidder must be rebuilt; feasible, keys exist).

### CP-2 — Opportunity-adjusted validation → main empirical core
- **Objective:** promote script 76's within-opportunity-stratum result from App D to the §4 spine. Headline = within-opportunity AUC `log_tc`=**0.7715** and increment over exposure-only **+0.0415** (DeLong p=2.08e-06), NOT raw 0.924. State explicitly that exposure-only *alone* scores **0.946** (the mechanical-exposure benchmark) and that the contribution is the **+0.04 beyond it**.
- **Why referees care:** mechanical exposure is THE core vulnerability (Referee #1/#2). The defensible claim is "signal beyond participation volume / opportunity set," and the number is modest by design.
- **Files:** `sec04_validation_submission.tex` (new §4.2 "Exposure-adjusted validation"), `sec_app03` (demote to support), `values.tex` (bind `\valExpWithinAUC`, `\valExpIncrement`, `\valExpDeLongP`, `\valExpOnlyAUC=0.946`).
- **Scripts:** `76_exposure_adjusted_audit.R` (already run; may extend with PR-AUC + per-stratum table). Add buyer-FE and item-group-FE strata variants if referees want more exposure axes.
- **Outputs:** Table B, exposure figure (observed-vs-expected by participation bin).
- **Risk:** 🟡 — result is real but modest; framing must not oversell. **Data-blocked?** No (run).

### CP-3 — Timing / leakage / rolling-origin / leave-one-case-out
- **Objective:** headline strict ex-ante validation. Report (a) script 53 frozen-train threshold (firm AUC binary **0.767** / cont **0.750**, threshold frozen on 2009-16 = 7), (b) script 77 deployment-timing event study, **honestly reporting the FAIL**: cobidders show *lower* year-HHI (d=−0.66), so sincere persistence is NOT ruled out → disclose observational equivalence. Add leave-one-case-out once CP-1 rebuilds case→cobidder links.
- **Why referees care:** pooled retrospective AUC ≠ prospective deployability (Referee #5/#6). The honest timing limitation is more credible than a fake clean pass.
- **Files:** `sec04_validation_submission.tex` (§4.3), `sec06` (gatekeeper timing), `sec_app03`.
- **Scripts:** `53` (run), `77` (run), `17`/`27`/`64` (temporal), NEW `scripts/80_leave_one_case_out.R` (depends on CP-1 linkage).
- **Outputs:** Table C, rolling-origin figure, leave-one-case-out distribution figure.
- **Risk:** 🔴 — leave-one-case-out blocked until CP-1; timing verdict is a disclosed limitation. **Data-blocked?** YES (LOCO needs CP-1; rolling-origin on *conduct* timeline blocked — only judgment dates exist).

### CP-4 — PR metrics & cost-recall frontier
- **Objective:** shift operational reporting from ROC-AUC to **PR-AUC, precision@k, recall@k, lift@k, FP, FN, cost-recall frontier**. Report the sequential gatekeeper as a **frontier over K1 and cost denominators**, not a single "83%."
- **Why referees care:** ROC-AUC is misleading at extreme class imbalance (193 positives in 16,843); enforcement cares about precision at the budget they can afford (Referee #5/#6).
- **Files:** `sec06_screening_forensics_submission.tex` (§6.3-6.4), `sec_app05`/`sec_app06`.
- **Scripts:** `42_operational_metrics.R`, `43_precision_at_k_audit.R`, `56_regulatory_cost_frontier.R` (**NOT YET RUN — `output/regulatory_frontier/` empty**), `63`/`64` (gatekeeper). NEW: extend 63 to emit a K1 × cost-denominator grid.
- **Outputs:** Table D (cost-recall frontier), PR/lift curve figure, `fig_regulatory_frontier.pdf` (currently missing).
- **Risk:** 🟡. **Data-blocked?** No (need to RUN 56).

### CP-5 — Bid-layer benchmark audit
- **Objective:** make the Imhof/bid-layer benchmark transparent: features, aggregation, learner, CV scheme, leakage controls, missingness, case-holdout performance. Sell complementarity ("comparable discrimination at lower informational cost"), never "outperforms."
- **Why referees care:** an under-documented benchmark makes the "award layer adds non-redundant info" claim unfalsifiable (Referee #8/#10).
- **Files:** `sec06` (§6.1-6.2), `sec_app06`/`sec_app07`.
- **Scripts:** `31_imhof_full_pipeline.R`, `49_imhof_incremental_value.R`, `26_auc_by_subsample.R`. Document each feature; add a missingness table.
- **Outputs:** Table E (bid-layer benchmark audit), feature/missingness appendix table.
- **Risk:** 🟡. **Data-blocked?** No.

### CP-6 — Price-claims downgrade (legal caution)
- **Objective:** price evidence = **scope/corroborative only**, never damages/overcharge/proof/causal mechanism. Incorporate script 78: within-cell compression loads on **genuine** bidders (l_gen=−0.137), not FL count (l_fl≈ns) → the "cover-bidding theater" mechanism is **not identified**; reframe accordingly.
- **Why referees care:** legal overclaim from award records is fatal in L&E (Referee #7/#11).
- **Files:** `sec07_price_scope_submission.tex` (all subs), `sec_app04`.
- **Scripts:** `59`, `61_selection`, `62_within_cell`, `78` (run). Bind `\valBidderDecompGen`, `\valBidderDecompFL`.
- **Outputs:** revised price scope table; decomposition row.
- **Risk:** 🟡 (weakens a headline, but honestly). **Data-blocked?** No.

### CP-7 — Theory appendix: exit/survival (Appendix B)
- **Objective:** address endogenous exit/survival — honest zero-win firms may leave; cartel-deployed losing-role firms may persist (role has strategic value/compensation). Add the asymmetric-exit margin to the λ_C > λ_G ranking logic.
- **Why referees care:** the ranking statistic assumes persistence reflects role, but persistence could be survivorship (Referee #9/#14).
- **Files:** `sec_app01_framework_submission.tex` (add survival subsection + formal note).
- **Scripts:** NEW `scripts/81_survival_hazard.R` — Kaplan-Meier / discrete-time hazard of platform exit by always-loser status and cobidder status, using firm-year participation (year = OC substr). Feasibility: firm-year derivable; **no explicit exit date** → exit = last active year (right-censored at 2019).
- **Outputs:** survival/hazard table, KM plot (if feasible).
- **Risk:** 🔴 — exit is censored at panel end; "exit" is operationalized as last-participation, conduct-onset unknown. May land as a *bounding* argument, not a clean hazard. **Data-blocked?** PARTIAL.

### CP-8 — JLEO claims discipline (cross-cutting)
- **Objective:** enforce the locked language rules + "adjudication-anchored exposure" in technical text; explicit JLEO-fit framing (agency organization, costly observability, evidence sequencing, administrative triage, governance under constraints, legal-economic boundaries).
- **Why referees care:** JLEO fit is a desk-screen gate (Referee #16/#17).
- **Files:** all sec*.tex (targeted), `sec01` (contribution para), `sec08`.
- **Scripts:** none.
- **Outputs:** see `04_CLAIMS_DISCIPLINE_LOG.md`.
- **Risk:** 🟢. **Data-blocked?** No.

## 2. Main-text restructuring
- §1: lead with enforcement-design question (where should costly proof-production begin?), not "we detect cartels." Contribution para names the closest gaps (Imhof/Huber screens; Porter-Zona/Bajari-Ye cover bidding; admin-triage L&E).
- §2: keep costly-proof/award-vs-bid-layer framing; add a **unit-of-analysis table** (Table F) and a **CADE case-timing table** (Table G).
- §3: ranking statistic + operational queue; foreground that FL is the *operationalization* of continuous loss-intensity.
- §4: REBUILT as core — funnel (Table A) → exposure-adjusted (Table B) → timing/LOCO (Table C). Direct-defendant null (AUC 0.491) stays front-paged as the design's scope limit.
- §5: economic profile; binary-vs-continuous reported with the strict-pool flip (53) disclosed.
- §6: bid-layer benchmark audit (Table E) → complementarity → cost-recall frontier (Table D) → gatekeeper timing.
- §7: price as scope only; theater-not-identified disclosed.
- §8: enforcement-design payoff; liability stays in the richer record.

## 3. Empirical redesign
Priority order = CP-1, CP-2, CP-3, CP-4, CP-5, CP-6, CP-7. New scripts: `79_label_funnel.R`, `80_leave_one_case_out.R`, `81_survival_hazard.R`; RUN `56_regulatory_cost_frontier.R`; extend `76` (PR-AUC, extra strata) and `63` (K1×cost grid). Bind all new numbers into `values.tex` by hand with `% src:` comments. Seed everything (house seed pattern `2026xxxx`).

## 4. Appendix redesign
- B (theory): add exit/survival.
- C (data/labels): rebuilt funnel; retire/replace 210/108/30; document cobidder & crossmatch provenance (regenerating script) for JLEO replication.
- D (audits): demote exposure result to support of §4; keep permutation, leakage, year-holdout.
- E (price scope): theater-not-identified.
- F (adaptive): keep.
- G (forensic sequence): bid-layer benchmark detail + gatekeeper algorithm + K1×cost grid.
- ComprasNet (app07): decide — wire in as cross-jurisdiction robustness OR delete. Currently orphaned; do not leave half-in.

## 5. Reproducibility & compliance
- Write a regenerating script for `cade_fl_cobidders.csv` + `cade_bec_crossmatch.csv` (provenance currently archived only) → JLEO replication policy.
- De-hard-code paths; add a minimal `README_replication.md` + manifest.
- JLEO compliance audit (abstract ≤150 words, JEL codes, double-spacing on final, alt text on both figures, Bluebook for CADE/legal cites, appendix master `\bibliography` fix).
- Eliminate the 2 hard-typed table bodies (sec06 gatekeeper, app03 year-holdout) → macro-bind or `\input` from script output.

## 6. What NOT to do unless the main fixes work (illusions of progress)
- Do NOT add more decorative robustness, prettier figures, or broaden the literature review before CP-1/CP-2/CP-3 land.
- Do NOT revive the cover-bidding-theater mechanism with more heterogeneity — script 78 already says it's not identified.
- Do NOT inflate the welfare/policy headline.
- Do NOT re-run `99_make_paper_values.R` (writes stale v13 values).
- Do NOT chase the ComprasNet federal extension as a "second paper" inside this submission (reserved spinoff).
- Do NOT defend FL14 as ontologically special; it is the operationalization of `log(tenders_count)`.
