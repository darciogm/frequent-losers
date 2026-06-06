# R4 — HOSTILE READ, EXECUTED (Federal / ComprasNet extension)

**Date:** 2026-06-06 · **Author:** Mr. Frequent Losers (Referee-2 mode) · **Status:** EXECUTED — fill-in-the-blanks complete against the live chain outputs.
**Protocol:** `docs/jleo_rr_revision/R4_hostile_read_protocol.md` (14 attacks A1–A14).
**Discipline:** light reads only (R1 regression harness owns the machine; no R run).
**Canonical N+ = 195** (broad-AL cobidders, post-sentinel-drop), confirmed `targets/canonical_target_counts.csv :: B_broad_AL_cobidders_MAIN = 195`.

This document reads the SOURCE CSVs directly (the `federal_fill_report.csv` is stale for the late files, as the script-04 triage warned). Prior triage adjudications (A2, A3, A4, A8, A9, A11, A14) were VERIFIED against source, not re-derived; one disagreement-of-emphasis with the A9 triage is flagged below.

---

## 14-ATTACK VERDICT TABLE

| # | Attack | X (from source file) | Threshold Z | VERDICT | Manuscript implication |
|---|---|---|---|---|---|
| **A2** | Positive-set power | `\valFedAudPowerFive` = **0.35** @0.55 (`permutation_power_curve.csv`); @0.60 = **0.90**; @0.65 = **1.00**; size@0.50 = 0.117. Positive control O_i MEDIUM = **0.9921** (`granularity_sweep.csv`) | ≥0.80 powered / 0.60–0.80 marginal / <0.55 dies; control ≈0.95 | **SURVIVES-WITH-CAVEAT (power-bounded)** | Within-stratum row is NOT a clean null at N+=195: rule out residual ≥0.60 @90% power; the ≤0.55 region is unadjudicated. Report ONE within number (0.56 MEDIUM) + ONE power bound. Positive control passes ⇒ not a design failure. |
| **A3** | Case concentration | top-case-by-positives = **35.4%** (69/195); top-two = **64.4%** link-row / 67.7% firm; TP@500 = **87.5%** one case; LOCO PR-AUC full **0.0142** → drop-largest **0.0079** (−44.4%) → drop-top-two **0.0038** (−73.3%); ROC full 0.744 → drop-largest **0.744** (−0.1%) → drop-top-two 0.710; cluster-RI ordering p **0.001**, breadth p **0.487 (NS)** | DIES if PR drop-largest >60% or drop-top-two at chance | **DEGRADED / SPLIT** | Survives on ROC-ordering (LOCO-robust 0.744→0.744, RI p=0.001, LODGO clean) → "rank-ordering not driven by one cartel." MUST retreat on operational/PR-AUC & precision-at-k (87.5% one case, PR −73% top-two) → frame federal as "single-system, concentrated-anchor stress test," not multi-case generalization. Foreground TP@500=87.5% + top-two=64.4%, NOT the flattering 35.4%. |
| **A9** | Negative controls | placebo (matched-volume) AUC **0.744** vs real 0.744, p=**0.27**; HV-winner AUC **0.745**, p=**0.542** (`table_E_negative_controls.csv`) | placebo p>0.10 ⇒ clean geometry; real−placebo gap p<0.05 ⇒ cartel-specific | **SURVIVES (Draft A confirmed)** | Both placebos statistically indistinguishable from the real-anchor raw AUC (p=0.27, p=0.542 ≫ 0.10). The raw 0.744 ordering IS generic co-participation geometry, not cartel-specific. This is the arbiter: **Draft A (deflation reading)**, NOT Draft B. |
| **A4** | Window/timing | frozen prospective AUC **0.595**, N+ = **98**, pool 24,888 (`frozen_timing.csv`); CI [0.535, 0.654]; frozen retrospective **0.740**, N+=177; strict full-universe **0.489**; strict training-AL continuous **0.666** (`table_D_strict_2013_2016_to_2017_2019.csv`); rolling worst-year **0.480** | N≥120 ⇒ comparable; CI [0.4,0.9] ⇒ "—" | **SURVIVES-WITH-CAVEAT** | Frozen prospective N=98 < 120 floor BUT CI [0.535,0.654] excludes 0.50 and 0.713 ⇒ informative-but-power-limited, NOT a "—". Report with explicit 4-yr-pre-period caveat (0.59 [0.54,0.65]); lead the prospective-collapse claim on the strict full-universe row (0.489, entrants-at-zero), which needs only the test window. Retrospective 0.74 corroborates the design. |
| **A6** | Cell coarseness | granularity sweep score within-AUC: COARSE **0.5745** / MEDIUM **0.5582** / STRICT 0.6467 (singleton, see A12); O_i control 0.9987/0.9921/0.533 (`granularity_sweep.csv`) | residual must not vanish only as cells tighten | **SURVIVES (conservative direction)** | Federal verdict is null/power-bounded under the COARSER federal MEDIUM (no item-group margin), which holds LESS fixed ⇒ the null is conservative a-fortiori. Residual does NOT appear and then vanish; it is near-chance at every granularity that has support. Mandatory annotation: "federal cells one margin coarser than BEC (no item-group)" — present (comparative L280; appG L97). |
| **A7** | SRP split | feasibility gates both clear: regular cobidders 3,546 / SRP 4,069 (≫100); directs 21 / 23 (≥5); contact≥2 sensitivity (02b) replicates deflation (within sub-0.5, perm p 0.951) | strata agree ⇒ pool; disagree ⇒ stratify | **SURVIVES (pending stratified-row confirmation)** | Both strata clear gates; main + contact≥2 sensitivity agree in direction (deflation). Pooled federal verdict defensible. Carry SRP-vs-regular as the only institutional contrast (A14). Recommend the App G SRP-stratified row be present/footnoted as invariance evidence; not a blocker. |
| **A12** | STRICT support | STRICT = 692,450 cells, all singletons; retention 0 under moderate/strict; granularity STRICT n_retained=105, O_i control collapses to **0.533** (`opportunity_cell_sparsity.csv`, `granularity_sweep.csv`) | headline must be MEDIUM | **SURVIVES** | Headline within-stratum is MEDIUM (12,781 cells / 7,801 retained); STRICT is singleton-dominated and its O_i positive control itself collapses to 0.533 ⇒ STRICT shown sweep-only with explicit low-support flag. Identical to BEC handling. |
| **A5** | FL cut sensitivity | continuous score is primary: strict training-AL continuous **0.666** vs FL-binary **0.634**; within MEDIUM score 0.558; per-stratum IQR 33.5 reg / 64.5 SRP, pooled FL32 used (`srp_stratification_feasibility.csv`) | score must not flip vs FL32 | **SURVIVES (by design)** | Continuous log-tenders score is the primary object everywhere; verdict invariant to FL cut (score and binary both near chance within-stratum, both deflate same direction). FL32 is the deployable analogue, never defended as special. Caveat present (comparative L82–85). |
| **A1** | Anchor circularity | framing scan: `phase0_g3_linkage_audit.csv` = 7/7 overlap, `independence_verdict = NOT independent`; every "independent" use in drafts is a NEGATION | zero "independent/out-of-sample" affirmations | **SURVIVES** | All claims scoped to method+construct portability. "partially overlapping" present in both drafts (comparative L93; appG L36, L322). "second platform" L20/L93. Zero affirmative independence/out-of-sample/external-validation phrasings. Three `independent` hits are all "NOT/neither an independent ground truth" disclaimers. Clean. |
| **A8** | TI/DF exclusion | excluded case disclosed in BOTH drafts ("one unnumbered summary case excluded for lack of firm-level identification," comparative L91; appG L79); v3-reinstatement control proves it (`federal_cobidder_rebuild_vs_v3.csv`) | verdict unmoved | **SURVIVES** | Exclusion pre-emptively disclosed; it is the ONLY federal-only anchor and excluding it makes overlap exact 7/7. v3-reinstatement reproduces v3 bit-for-bit ⇒ direction-of-effect known & non-strategic. Sensitivity (+2 TI estabs) recommended as a one-line confirmation if a referee presses; numbers map shows it does not move federal quantities. |
| **A11** | Anchoring grain | rebuild establishment-anchored **195** vs v3 raiz-reported **222**; gap decomposed: TI/DF exclusion = **313 cobidders (26 AL)** + 1 junk; estab-vs-raiz grain = **0** (v3 reproduces bit-for-bit on reinstatement) (`federal_cobidder_rebuild_vs_v3.csv` :: D_I_TIDF_EXCLUSION_VERIFIED) | main target = estab 195; grain delta = 0 | **SURVIVES** | Establishment-anchored 195 is the MAIN target everywhere; v3's 222 is set-comparison only. Referee premise ("different grain = different universe") is empirically FALSE here — entire gap is the disclosed TI/DF case-exclusion + 1 junk record, grain contributes 0. Drafts specify establishment anchoring (comparative L99; appG L48). |
| **A10** | Price | NO federal price claim made (Tier-1 only): grep for menorLance/valorEstimado/valorHomologado/"federal price" in both drafts = **zero hits** | omit, or balance <0.1 SD if claimed | **SURVIVES (by omission)** | The federal audit runs on participation + winner flag; no price field touches any cell, row, or claim. A10 never lands. Recommended default holds. |
| **A13** | S2 laundering | S2 absent from comparative table & abstract (zero hits in `sec_comparative_DRAFT.tex`); present in App G ONLY (L138) WITH "label-encoding; not score evidence" + "mechanically inflated" note (L149–150) | zero S2-as-score citations | **SURVIVES** | S2 confined to App G with its inflation note; never cited as the federal screen ranking defendants. Score's isolated contribution is the nested increment / within-stratum only. Clean. |
| **A14** | Modality loss | federal pure pregão (convite extinct); convite branch SKIPPED + logged ("source=comprasnet has no convite; gate G5 pure pregao"); no modality-mechanism claim in drafts | no modality-mechanism claim | **SURVIVES** | Loss reframed as construct-sharpening (the construct earns its keep without modality variation). SRP-vs-regular is the only institutional contrast and is reported as such, not as a convite analogue. Consistent with locked D2 rule. |

---

## DRAFT A / B GATE DECISION (gated on A2 + A9)

**Decision: DRAFT A CONFIRMED (deflation reading). Draft B (institution-coupled screening-value / surviving-residual reading) is DELETED.**

The switch is fully determined by the two gating attacks:

- **A2 (power):** the within-stratum point estimate is near chance (0.56 MEDIUM / 0.46 matched) and is *not* a powered residual — the only open question is whether a *small* residual (≤0.55) hides below federal power, and the answer is "≤0.55 is unadjudicated, ≥0.60 is ruled out @90%." There is no powered residual to support Draft B.
- **A9 (negative controls — the protocol's designated arbiter):** the matched-volume placebo (AUC 0.744, p=0.27) and the non-CADE high-volume-winner null (AUC 0.745, p=0.542) **reproduce the real-anchor raw AUC**. Per the protocol, placebo-reproduces ⇒ the order is generic co-participation geometry ⇒ **ship Draft A with the negative controls front-paged as the reason.** Draft B requires the placebos to FAIL to reproduce the order (gap p<0.05); they do not.

Both gates point the same way. **Keep the Draft A paragraph in `sec_comparative_DRAFT.tex`; delete the Draft B paragraph.** The within-stratum row carries ONE number (0.56 MEDIUM) + ONE power bound (≥0.60 ruled out @90%), exactly as the armor triage specified.

---

## LANGUAGE-DISCIPLINE SCAN — RESULTS

**Forbidden-verb scan (both drafts): CLEAN.** Every hit on the forbidden list is a negation or a code comment:
- `sec_comparative_DRAFT.tex:164` — "adjudication-anchored exposure, **not** cartel membership" (correct disclaimer).
- `sec_comparative_DRAFT.tex:190` — `% never detects / proves / outperforms…` (comment stating the rule).
- `sec_appG_federal_DRAFT.tex:33` — "It does **not** assert cartel membership…" (disclaimer).
- `sec_appG_federal_DRAFT.tex:232` — "**not** cartel members" (disclaimer).
- `sec_appG_federal_DRAFT.tex:355` — "exposure, **not** cartel membership; neither column ranks defendants" (disclaimer).
- `independent` (3 prose hits) — all "**not** an independent ground truth / cartel universe / population" disclaimers (comparative L36, L97; appG L324). Zero affirmative uses.

**Mandatory-caveat scan: ALL PRESENT.**
| Caveat | Location |
|---|---|
| "second platform, partially overlapping legal anchors" | comparative L20, L93; appG L36, L322 |
| "frequent-loser flag is never used to build the label" | comparative L103; appG L52 |
| "cobidder = adjudication-anchored exposure, not membership" | comparative L164; appG L33, L355 |
| "federal cells one margin coarser than BEC (no item-group)" | comparative L280; appG L97 |
| "federal positive base more case-concentrated than BEC" (A3) | comparative table L138 row + appG L252 (LOCO) |
| "no federal bid microdata; bid-layer step cannot be constructed" | comparative L60, L284, L292; appG L388 |
| "FL threshold re-estimated (32), not transported" (A5) | comparative L82–85 |
| TI/DF exclusion footnote (A8) | comparative L91; appG L79 |
| Power bound stated (A2) | comparative L135, L146, L218–221; appG L171, L188 |
| Estimand wall (raw-timing vs adjusted) | carried in script-03 triage §4 labeling guidance; ensure the comparative-table caption sentence is transcribed at integration |

**S2 / price scans: CLEAN.** S2 in App G only (with inflation note); zero federal price claims.

**ONE PRE-INTEGRATION BLOCKER (not a violation, a build-gate item):** both drafts still carry `\valTODO` placeholders and `% TODO_NUMBER` tags (e.g. comparative L135–146, table cells; appG L138, L188, L252). The protocol's build gate requires deleting the `\providecommand{\valTODO}` block and wiring every cell to a real `\valFedAud*` macro before integration. The macros exist (`audit_armor_macros.tex`, `canonical_target_macros.tex`); the binding pass is the integration step, not part of this hostile read.

---

## RESIDUAL-RISK LIST (legitimate hits a referee can still land + pre-written response)

1. **A3 operational concentration — "your realized detections are one cartel" (HIGHEST residual risk).**
   *Hit:* TP@500 = 87.5% one case; PR-AUC drops −73% on the top two; RI case-breadth p=0.487 (NS). The *operational* ranking does not generalize across cases.
   *Pre-written response:* "We concede and disclose this explicitly. The federal leg is presented as a **single-system, concentrated-anchor stress test of the audit protocol**, not as a multi-case operational generalization. What survives leave-one-case-out is the **rank-ordering** (ROC 0.744→0.744 dropping the largest case; clustered-RI ordering p=0.001; LODGO clean), which is genuinely multi-case. The precision-at-k generality claim is withdrawn, and the comparative table notes carry the top-two=64.4% / TP@500=87.5% disclosure verbatim." This is the protocol's predicted degraded→disclosure path, not a kill.

2. **A2 power — "your federal null is an underpowered failure to reject."**
   *Hit:* detection probability at a true within-AUC of 0.55 is only 0.35 (BEC 0.97).
   *Pre-written response:* "We do not claim a clean null. The within-stratum row is **power-bounded**: at N+=195 the matched-permutation test rules out a residual ≥0.60 at 90% power and ≥0.65 at 100%, while the ≤0.55 region is unadjudicated federally. The positive control O_i recovers the injected exposure signal within the same strata at AUC 0.99, so the small-residual blind spot is a sample-size limit, not a design failure. The deflation's *first stage* (raw concentration ≈ opportunity arithmetic, via label-blind E = 0.61 vs BEC 0.55) replicates at full power." The federal headline rests on the powered rows (raw AUC, label-blind E, strict-universe collapse, negative controls), not the under-powered small-residual region.

3. **A4 short pre-period — "a 4-year frozen pool with N=98 is too thin to compare to BEC's 0.713."**
   *Hit:* frozen prospective N=98 < the N≥120 comparability floor.
   *Pre-written response:* "We report the frozen-prospective AUC (0.59 [0.54, 0.65]) with an explicit 4-year-pre-period caveat — it is above chance (CI excludes 0.50) but below BEC's 0.71 and below the comparability floor, so we do **not** lead on it. The prospective-collapse claim is carried by the **strict full-universe row** (0.489, entrants scored at zero), which needs only the 2017–2019 test window and is robust to the short pre-period; the frozen *retrospective* AUC (0.74 [0.70, 0.78]) confirms the design carries timing signal." The thesis survives the loss of the frozen-pool cell.

*(Next-tier residual: A7 SRP-pooling — mitigated by the contact≥2 sensitivity agreeing in direction and both strata clearing gates; ship the SRP-stratified row in App G as invariance evidence. A1 framing — fully controlled in prose, zero affirmative violations found, but the scan must be re-run on the abstract/intro/conclusion at integration since those files were out of scope here.)*

---

## DISAGREEMENTS WITH PRIOR TRIAGE (flagged per instructions)

- **A9 emphasis (minor, not a contradiction).** The prompt's framing of `table_E_negative_controls.csv` ("real 0.744 vs placebo-anchor null 0.729 p=0.27, vs HV-winner null 0.745 p=0.542") quotes the **null-mean** (0.729) for the placebo. The *real* AUC in both rows is identically **0.744** (it is the same observed statistic; the two rows differ only in the null they bootstrap). Verdict is unaffected — both p-values (0.27, 0.542) are ≫0.10, so both placebos reproduce the real order ⇒ generic geometry ⇒ Draft A. I read this as the *clean-null / Draft-A-confirming* outcome, consistent with the A9 triage intent.
- **All other triage verdicts (A2 power-bounded, A3 degraded/split, A4 informative-with-caveat / strict-universe carrier, A8 disclosed, A11 grain=0, A14 construct-sharpening): VERIFIED against source CSVs. No disagreement.**

---

## OVERALL SECTION VERDICT

**READY-FOR-INTEGRATION**, conditional on the integration-pass mechanics below (none are hostile-read failures; all are wiring):

1. **Macro binding** — delete the `\valTODO` / `% TODO_NUMBER` placeholders and wire every comparative/App-G cell to its real `\valFedAud*` macro (sources verified present). Honor the script-04 fill-spec fixes: (a) clustered-RI table path lacks the `appendix/` subdir; (b) `\valFedAudTopCaseTP` reads `case_dominance_summary.csv::share_tp_500`, not table_H; (c) lock top-two denominator to the link-row 64.4% basis with the multi-case note; (d) annotate that federal RI added the buyer margin.
2. **Estimand-wall caption** — transcribe the script-03 §4 one-line caption ("raw-timing rows and opportunity-adjusted rows measure different estimands on different samples; a high raw-timing AUC and a null adjusted increment are mutually consistent") into the comparative-table note so a referee cannot read the 0.67 strict-training row as rebutting the 0.56 within row.
3. **Draft B deletion** — remove the Draft B paragraph; keep Draft A.
4. **Re-run the A1 forbidden-verb scan on abstract/intro/conclusion** at integration (out of scope here; those files were not part of the two-draft scan).

No empirical result kills the section. The two narrowings (A2 power-bound, A3 operational-concentration retreat) are exactly the protocol's pre-written fallbacks; both are honest, survivable, and already drafted. **Draft A is confirmed by both gates.**
