# R4 — HOSTILE READ PROTOCOL (Federal / ComprasNet extension)

> **CHANGELOG 2026-06-05 (target-quality fix, post 18:18 rerun).** The all-zeros sentinel
> CNPJ `000000000000-2` was dropped from the cobidder builder. Federal positive count shifts
> by 1: **N+ = 196 → 195** everywhere below (cobidders all 3,851→3,850; FL composition 95→94).
> The sentinel lived in **Case F (medic_genericos, 08012.005928/2003-12)**, so the per-case AL
> distribution changes only there: **F = 23 → 22**; AL firm-case rows **206 → 205**. Cases A
> (69) and D (63) are unchanged, so the top-2 numerator is unchanged at 132 — **top-2 share
> 64% → 64.4%**, top-case A 33% → 33.7%. **A2 power attack does NOT need re-derivation**: the
> kill threshold is `\valFedAudPowerFive` vs the BEC power *curve*; a Δ=1 in N+ (0.5%) does not
> move the 0.80 / 0.55 power thresholds. The D-i rebuild delta (A11) is now PROVEN as
> TI/DF-exclusion = 313 cobidders (26 AL) + 1 junk; estab-vs-raiz grain = 0 (see A11 rewrite below).
> All inline "196 / 206 / F=23" mentions updated to 195 / 205 / 22 with the pre-fix value noted.

**Date:** 2026-06-05 · **Author:** Mr. Frequent Losers (Referee-2 mode) · **Status:** PRE-WRITTEN — executes the moment the federal run chain finishes
**Scope:** the new §"The Audit on a Second Platform" (`sec_comparative_DRAFT.tex`) + Appendix G (`sec_appG_federal_DRAFT.tex`). Pre-positions every attack a hostile JLEO referee will run against the federal leg so the hostile read is a fill-in-the-blanks pass, not a fresh think.
**Companion docs:** `NEW_NUMBERS_MAP_COMPRASNET.md` (file→macro slots), `99_COMPRASNET_EXTENSION_PLAN.md` (build plan), `phase0_g3_linkage_audit.csv` (case-overlap verdict), `canonical_case_labels.csv` (per-case label counts), `srp_stratification_feasibility.csv`, `opportunity_cell_sparsity.csv`, `opportunity_common_support.csv`, `item_pregao_linkability.md`.

**One framing rule above all (locked):** the BEC and federal CADE anchors are the **same 7 numbered cases** (G3 = `FAIL_INDEP`, 7/7 overlap). The phrase **"second platform, partially overlapping legal anchors"** is mandatory and non-negotiable in every place the federal evidence is described. We never say "independent setting", "second ground truth", "out-of-sample validation", or "external replication of the labels". What is independent is the **platform, firms, tenders, observability, and FL threshold** — NOT the legal provenance of the labels.

---

## ATTACK SET — 14 attacks

Each: (a) exact failure mode (what the referee says, in their voice) · (b) which chain-output file answers it · (c) survives/dies threshold · (d) honest fallback framing if it dies.

---

### A1 — Anchor circularity ("same validation twice, not a second test")

**(a) Failure mode.** "Your federal labels are the same 7 CADE cases that anchor your BEC validation (your own `phase0_g3_linkage_audit.csv` says 7/7 numbered cases overlap, `independence_verdict = NOT independent`). So this is not a second test of the screen against new ground truth — it is the same ground truth re-projected onto a second data dump. A null that replicates is mechanically guaranteed by shared anchors; a residual that appears is a property of how those same cartels happen to bid federally. Either way you have learned nothing about transportability of the *finding*; you have only re-described the same defendants."

**(b) Answers it.** `phase0_g3_linkage_audit.csv` (rows `case_overlap_BEC`, `case_federal_only`, `independence_verdict`, `cobidder_rule_divergence_vs_BEC`); `NEW_NUMBERS_MAP_COMPRASNET.md` construction-differences header.

**(c) Survives / dies.**
- **What is genuinely new federally (the portability claim's true content):** (i) the *platform* (national ComprasNet vs state BEC, different procuring units/UASGs); (ii) the *firm population* — federal cobidders 195 broad-AL (was 196 pre-fix; intersection 195 against the v3 set) but a **different firm universe** from BEC's 651 (different establishments transacting federally); (iii) the *tenders* (federal tender-items, zero shared rows with BEC); (iv) the *observability regime* (no bid microdata federally); (v) the *FL threshold* (32, re-estimated, not transported). The portability claim is therefore: **"the same audit *protocol* and the same loser-side *construct*, re-derived from scratch, produce a coherent verdict when the platform/firms/tenders/observability all change, with the legal anchors held partially constant."**
- **SURVIVES** iff the section's every claim about the federal evidence is scoped to **method + construct portability**, never to **label independence**, and the boundary is stated explicitly: the labels share legal provenance; the data-generating environment does not.
- **DIES** the moment any sentence in `sec_comparative` or App G implies the federal CADE anchors are a fresh/independent cartel population — including soft forms ("out-of-sample", "second setting tests the labels", "external validation").

**(d) Fallback if it dies.** It does not "die" empirically — it is a framing failure, fully controllable in prose. The honest claim, already drafted correctly (`sec_comparative_DRAFT.tex` lines 31–34, 89–95), is: *"The exercise tests portability of the method and of the loser-side construct; it is not an independent cartel universe."* If a referee still presses, concede openly: the value of the federal leg is **construct + protocol portability under a held-constant legal anchor**, which is a weaker but honest claim than independent replication, and is exactly the claim a "portable audit" paper should make. Boundary sentence to keep verbatim near the section head: *"Because the legal anchors partially overlap with BEC, the federal exercise demonstrates that the audit and the loser-side construct travel across procurement systems; it does not assemble an independent ground truth, and we do not read it as one."*

---

### A2 — Positive-set power ("195 positives — is the within-stratum null powered?")

**(a) Failure mode.** "Your headline is a *null* — the within-stratum residual collapses. On BEC you had 651 positives and built a power curve showing detection probability 0.97 at a true within-AUC of 0.55. Federally you have **195** positives — 30% of BEC. A within-stratum null at N+=195 may simply be the test running out of power. Show me the federal power curve, or your null is uninformative." *(N+ was 196 before the 2026-06-05 sentinel-drop fix; the Δ=1 does not change the power reading — the threshold below is on the power curve, not on N.)*

**(b) Answers it.** `outputs/comprasnet/diagnostics/audit_armor/permutation_power_curve.csv` (the **decisive** file) → slots `\valFedAudPowerTwo` (@0.52), `\valFedAudPowerFive` (@0.55), `\valFedAudPowerTen` (@0.60). Positive control: `granularity_sweep.csv` → `\valFedAudOiControlMedium`. Positive count confirmed at `canonical_target_counts.csv::B_broad_AL_cobidders_MAIN` = 195.

**(c) Survives / dies.** The number that **kills the section**: `\valFedAudPowerFive` (detection probability at true within-AUC 0.55).
- **SURVIVES** iff `\valFedAudPowerFive ≥ ~0.80` (BEC = 0.97). At that level, a federal within-stratum AUC near chance is an informative null: the test *would* have caught a 0.55 residual ≥80% of the time and did not. *(This threshold is unchanged by the N+ 196→195 fix: it reads off the empirical power curve at N+=195, not a closed-form N; a 0.5% positive-base change is far inside the curve's resolution.)*
- **MARGINAL** if `0.60 ≤ \valFedAudPowerFive < 0.80`: the null is weak; report the residual point estimate with its CI and lead with the *power-bounded* statement ("we can detect a within-AUC of X with prob Y"), not the null verdict.
- **DIES** if `\valFedAudPowerFive < 0.55` (coin-flip): the null is uninformative, the within-stratum row of `tab:comparative_audit` cannot carry a deflation claim, and the federal leg must retreat to the **descriptive** rows (raw AUC, label-blind E, LOCO, negative controls) only.
- Cross-check the positive control `\valFedAudOiControlMedium`: must reach ≈0.95 (BEC 0.953). If the positive control itself fails to recover O_i within strata, the federal design has no detection power at all → the whole within-stratum apparatus is dropped.

**(d) Fallback if it dies.** Demote the within-stratum row to "not powered federally (N+=195); see App G" and lead the federal verdict on the rows that *are* powered at 195: raw AUC, label-blind opportunity E, LOCO concentration, negative controls, and the label-frozen timing test. The portability claim then narrows to "the deflation's first stage (raw concentration ≈ opportunity arithmetic, via label-blind E) replicates; the within-stratum confirmation is BEC-only by power." Honest and survivable.

---

### A3 — Case concentration ("the result is one cartel")

**(a) Failure mode.** "Your 195 positives are not 7 independent cases. From `canonical_case_labels.csv`, the per-case AL-cobidder counts are A=69, D=63, C=27, F=22, G=12, B=8, E=4 (F was 23 before the 2026-06-05 sentinel drop; the sentinel sat in Case F). The top case (trens_metros, A) is ~35% of positives; the top two (A+D) are ~68%. And by *defendant tender-items* the concentration is even worse — Case D alone has 18,446 of 31,200 anchor items (59%), Case F another 9,782 (31%). Your federal 'result' is one or two cartels wearing a national costume. LOCO will collapse it."

**(b) Answers it.** `canonical_case_labels.csv` (per-case `n_AL_cobidders`, `n_defendant_tender_items`); `outputs/comprasnet/tables/table_G_leave_one_case_out_validation.csv` → `\valFedAudTopCaseShare`, `\valFedAudTopCaseTP`; `table_H_case_dominance_validation.csv` → `\valFedAudLOCOfullPRAUC`, `\valFedAudLOCOdropLargestPRAUC`; clustered-RI → `\valFedAudClusterRIp`, `\valFedAudClusterRIcovP`.

**(c) Survives / dies.** This is **structurally worse than BEC** and known *before* the run from the case-label file: top-case-by-positives ≈ 35% (BEC `\valTopCasePosShare` = 32.0% — comparable) but **top-two ≈ 67%** and **top-case-by-anchor-items ≈ 59%** (BEC top case was ~32% of items). Kill thresholds:
- **DIES as "one cartel"** if `\valFedAudLOCOdropLargestPRAUC` drops by **>60%** from `\valFedAudLOCOfullPRAUC` (BEC dropped −37%: 0.143→0.090), i.e. removing trens_metros guts the ranking; OR if dropping the **top two** cases (A+D) leaves PR-AUC at chance.
- **SURVIVES** iff the verdict is robust to leave-one-case-out within a tolerance comparable to BEC (≤~40% PR-AUC drop on the largest case) AND the clustered-RI breadth test `\valFedAudClusterRIcovP` shows the ordering spans more than the dominant case.
- **Mandatory pre-emptive disclosure regardless of outcome:** the federal positive base is more case-concentrated than BEC (top-two 67%); state it in App G and in the comparative-table notes. Hiding it is fatal; disclosing it is survivable.

**(d) Fallback if it dies.** If LOCO collapses to one case, **do not claim the federal residual/null generalizes across cases.** Reframe: "the federal positive base is dominated by trens_metros and medicamentos; we therefore report the federal audit as a *single-system, concentrated-anchor* stress test of the protocol, not as a multi-case generalization." Pair with the case-by-case LOCO table so the reader sees exactly which case carries the verdict. The protocol-portability claim survives (the audit *ran* and *produced a coherent verdict*); the cross-case-generality claim does not.

---

### A4 — Window asymmetry ("your timing test has 4 training years")

**(a) Failure mode.** "BEC runs 2009–2019 (8 training years, 2009–2016, before the 2017–2019 holdout). Federally you only observe 2013–2019, so your frozen-timing test trains on **2013–2016 — four years**. A label-frozen prospective AUC built on a 4-year pre-period with a thin frozen pool is not comparable to the BEC 0.713 and may be too noisy to interpret. You are comparing apples to a smaller, younger apple."

**(b) Answers it.** `outputs/comprasnet/diagnostics/audit_armor/frozen_timing.csv` → `\valFedAudFrozenPool`, `\valFedAudFrozenProspAUC`, `\valFedAudFrozenProspN`, `\valFedAudFrozenRetroAUC`; `table_D_strict_2013_2016_to_2017_2019.csv` → `\valFedAudStrictFullAUC`, `\valFedAudStrictContAUC`; `table_E_rolling_origin_validation.csv` → `\valFedAudRollWorstAUC`. Construction-difference header row (window 2013–2019) in `NEW_NUMBERS_MAP_COMPRASNET.md`.

**(c) Survives / dies.**
- **SURVIVES** iff `\valFedAudFrozenProspN` (frozen-pool prospective N) is large enough to estimate an AUC with a usable CI — heuristic floor **N ≥ ~120** new-contact cases (BEC `\valArmorFrozenProspN` = 231). At/above that, report `\valFedAudFrozenProspAUC` with its bootstrap CI and annotate the 4-year pre-period explicitly.
- **DIES** as a comparable cell if the frozen pool is so thin that the prospective AUC CI spans roughly [0.4, 0.9] (uninformative). Then the frozen-timing row of `tab:comparative_audit` must be marked "—" federally with a note, not filled with a noisy point estimate.
- The frozen-pool size `\valFedAudFrozenPool` (BEC 13,051) is the early warning: if it is an order of magnitude smaller than BEC, expect the prospective N to fail the floor.

**(d) Fallback if it dies.** Drop the prospective-timing row from the *comparative* table (mark "—, 4-yr pre-period insufficient"), keep it in App G with full CI and the explicit caveat, and lead the federal timing story on the **strict full-universe collapse** (`\valFedAudStrictFullAUC`, entrants-at-zero) which needs only the test window and is robust to the short pre-period. The "prospective ranking collapses outside the incumbent pool" claim is carried by the strict-universe row, not the frozen-pool row, so the thesis survives the loss.

---

### A5 — FL32 cut sensitivity ("the BEC battery had threshold sensitivity; where is the federal one?")

**(a) Failure mode.** "On BEC you ran an IQR-threshold sensitivity sweep. Federally you re-derive a single cut of 32 by the same rule — but I notice `srp_stratification_feasibility.csv` shows the per-stratum IQR threshold is **33.5 for regular pregão and 64.5 for SRP**, and you 'used canonical pooled FL32 elsewhere'. That is a researcher degree of freedom. Show me the federal cut isn't load-bearing."

**(b) Answers it.** `srp_stratification_feasibility.csv` (row `al_median_plus_1p5_iqr`: 33.5 vs 64.5; note "canonical pooled FL32 used elsewhere"); `binary_vs_continuous_score_memo.md` (locked rule that the **continuous log-tenders score is the primary object**, FL-cut is a deployable convenience never defended as ontologically special); within-stratum FL-binary row `\valFedAudWithinFLAUC` vs continuous-score row `\valFedAudWithinAUC`.

**(c) Survives / dies.**
- **SURVIVES by design, no new run needed**, *provided* the federal section makes the **continuous score the primary object** (per locked rules of engagement: "continuous log(tenders_count) dominates FL14 binary; FL14 is a deployable rule, the true signal is loss intensity"). The FL32 cut appears only as the deployable-rule analogue. The drafts already do this — `sec_appG` table rows S0 carry both "raw score (log T)" and "raw FL (binary cut)", and the within-stratum rows carry both `\valFedAudWithinAUC` (score) and `\valFedAudWithinFLAUC` (FL). The score is the headline; the cut is secondary.
- **MARGINAL** if a referee insists on an explicit federal cut-sensitivity sweep. Cheap insurance: the within-stratum **score** AUC (continuous) is cut-free, so report it as the primary deflation evidence and footnote that the verdict is invariant to the FL cut because the score, not the binary, carries it.
- **DIES** only if the federal verdict *flips* between the continuous score and the FL32 binary (e.g. score within-AUC ≈ chance but FL32 within-AUC clearly above) AND the prose leans on the binary. Guard: lead on the score everywhere.

**(d) Fallback if it dies / referee insists.** Add one federal cut-sensitivity row (FL at the regular-stratum cut 33.5 and the SRP cut 64.5 alongside pooled 32) to the App G supplement, showing the within-stratum verdict is invariant. But the locked position is: **the continuous score is the primary object; the cut is never defended as special.** Footnote, do not panic-run.

---

### A6 — MEDIUM = year×buyer ("federal cells are coarser; not apples-to-apples")

**(a) Failure mode.** "Your BEC MEDIUM opportunity cell is year × buyer (PBU) × **item-group**. Your federal MEDIUM is year × buyer (UASG) — **no item-group margin**. A coarser cell removes *less* opportunity variation, so a federal within-stratum residual that 'survives' may survive only because you held *less* fixed. Your comparative deflation table is comparing a finer BEC control to a coarser federal control. The columns are not the same experiment."

**(b) Answers it.** `NEW_NUMBERS_MAP_COMPRASNET.md` construction-differences header (MEDIUM/COARSE/STRICT definitions per platform); `sec_comparative_DRAFT.tex` §4.5 "Observability as an On-Thesis Finding" (lines 204–227); `opportunity_cell_sparsity.csv` (COARSE federal = 8 cells = year-only; MEDIUM = 12,781 cells); App G opportunity-cell subsection (lines 86–115).

**(c) Survives / dies.** This is a **direction-of-bias** point and it cuts toward conservatism on the *null* side:
- Coarser federal MEDIUM holds *less* fixed → makes a residual *easier* to survive, *harder* to null out. So if the federal verdict is **null** (within-AUC ≈ chance under a *coarser* control), the null is **stronger**, not weaker — surviving the attack a fortiori. **SURVIVES cleanly if federal verdict is null.**
- If the federal verdict shows a **surviving residual**, the attack bites: the residual could be a cell-coarseness artifact. **MARGINAL → must** report the granularity sweep (`\valFedAudWithinCoarse / WithinMedium / WithinStrict`) so the reader sees the residual's behavior as cells tighten, and must annotate that the federal STRICT cell (item×year×UASG) is the closest analogue to BEC MEDIUM's granularity.
- **Mandatory annotation regardless:** the comparative table notes and App G must state in plain text that **federal cells are one margin coarser than BEC** (no item-group), and that this makes the federal null *conservative* and the federal residual *generous*. Caught hiding this = fatal.

**(d) Fallback if it dies.** If a surviving federal residual proves cell-coarseness-driven (collapses as cells tighten toward STRICT), reclassify the federal residual as "opportunity-resolution artifact" not "screening value", and the federal verdict reverts to the deflation (null) reading — which is the safer outcome anyway. The comparative table then shows deflation on both platforms with an explicit granularity caveat.

---

### A7 — SRP composition ("85% price-registration is a different economic object")

**(a) Failure mode.** "Your federal panel is **85% SRP** (`sistema de registro de preços`) — framework agreements with potentially multiple awardees, standing-price registers, call-offs. That is not the same economic object as a single-award pregão. Pooling 85% framework auctions with 15% regular auctions hides heterogeneity: 'always-loser' and 'win rate = 0' mean different things when the award structure is a price register. Your construct may be mismeasured for 85% of the data."

**(b) Answers it.** `srp_stratification_feasibility.csv` (the **decisive** file): regular (pregao_5) vs SRP (srp_9999) split — cobidder_firms_active 3,546 vs 4,069 (both ≫100 gate), direct_defendant_estabs_active 21 vs 23 (both ≥5 gate), AL share 35.5% vs 29.7%, AL tenders-count medians 5 vs 12. Optional SRP-stratified leg = re-run the within-stratum/LOCO battery separately on each stratum.

**(c) Survives / dies.** The feasibility file already shows **both strata independently clear the gates** (cobidders ≫100, defendants ≥5 in each), so an SRP-stratified leg is *constructible*.
- **SURVIVES** iff the SRP-stratified leg shows the two strata **agree in direction** (both null, or both residual) on the within-stratum verdict. Then SRP-pooling is innocuous and the pooled federal number is defensible.
- **DIES (pooling indefensible)** iff the two strata **disagree** — e.g. regular pregão deflates to chance but SRP retains a residual (or vice versa). Then the pooled federal verdict is a composition artifact and cannot be reported as a single number.
- Decision rule: **run the SRP-stratified leg as an App G robustness row** (the feasibility gate says it's free). If strata agree → one footnote confirming invariance. If strata disagree → the federal verdict must be reported *stratum-by-stratum*, and the pooled comparative cell is dropped.

**(d) Fallback if strata disagree.** Report the federal audit **separately for regular pregão and SRP**, lead the comparative table on the **regular-pregão stratum** (the cleaner single-award analogue to BEC pregão), and treat SRP as a distinct institutional object with its own verdict and an explicit note that win-rate-zero semantics differ under price registers. This is honest and on-thesis ("reach varies by institutional environment").

---

### A8 — The TI/DF exclusion ("you dropped a case with no process number — convenient?")

**(a) Failure mode.** "Your `phase0_g3_linkage_audit.csv` says you excluded a `tecnologia_informacao` DF case (2 establishments) because it has a blank process number. Convenient — was it dropped because it weakened the result? An undisclosed exclusion of a federal-only case is exactly the kind of researcher choice that inflates a borderline finding."

**(b) Answers it.** `phase0_g3_linkage_audit.csv` (rows `federal_distinct_cases` = "8 process-groups (7 numbered + 1 blank TI)", `case_federal_only`, `case_overlap_BEC`); `canonical_case_labels.csv` (7 numbered cases only — TI absent).

**(c) Survives / dies.** **SURVIVES** iff the exclusion is disclosed pre-emptively with the *non-strategic* reason and the direction-of-effect noted:
- The TI/DF case has **no process number in the source CADE CSV** → it is an *unverifiable* legal anchor (cannot be matched to an adjudicated process, cannot be reconciled against the canonical 12-case BEC portfolio). Excluding it is the *conservative* choice — it would have been the only federal-*only* case, and including an unverifiable anchor would *weaken* the "same numbered cases" framing, not strengthen the result.
- Note the irony to the referee's advantage: the TI case is the *only* genuinely federal-only anchor; excluding it makes the "partially overlapping" claim **more** honest (the included set is 7/7 overlapping), not less.
- **DIES** only if it is silently dropped. The mandatory footnote already drafted (`sec_comparative_DRAFT.tex` lines 88–90, App G lines 78–80) handles this.

**(d) Honest pre-emptive footnote (keep verbatim).** *"One additional federal case (information-technology procurement, Federal District, two establishments) is excluded throughout because the source CADE record carries no process number, leaving it unverifiable against the adjudicated portfolio. It is the only federal-only anchor; its exclusion makes the overlap with the BEC case portfolio exact (7 of 7) rather than introducing an anchor we cannot reconcile. Including it does not materially move any federal quantity (App G)."* — and run a one-line sensitivity (federal verdict with the 2 TI establishments added) so the last clause is true, not asserted.

---

### A9 — Negative controls federally ("what counts as clean?")

**(a) Failure mode.** "Your whole deflation story rests on the claim that any surviving order is generic co-participation geometry, not cartel-specific. Federally, prove it with the same placebo machinery. If a placebo anchor (random firms matched on volume) or a non-CADE high-volume winner reproduces your federal AUC, you have measured procurement geometry, not cartels — fine for the null reading, fatal for any residual reading."

**(b) Answers it.** `outputs/comprasnet/tables/table_E_negative_controls.csv` → `\valFedAudPlaceboAUC` (placebo-anchor matched-volume null), `\valFedAudHVWinnerAUC` (non-CADE high-volume-winner null), vs real `\valFedAudWithinAUC`/raw `\valFedAudRawAUC`; verdict `\valFedAudNegControlVerdict`.

**(c) Survives / dies.** Two opposite readings depending on the federal verdict:
- **If federal verdict is NULL (deflation replicates):** the placebo *should* reproduce the raw AUC (BEC: placebo 0.755 vs real 0.761, p=0.456 NS; HV-winner 0.782, p=0.908). "Clean" = placebo and HV-winner AUCs are **statistically indistinguishable** from the real-anchor raw AUC (permutation p > ~0.10). That *confirms* "generic geometry" → the null reading is correct. SURVIVES.
- **If federal verdict shows a RESIDUAL (survival reading):** the residual is cartel-specific only if the placebo and HV-winner **fail to reproduce it** — i.e. real within-AUC clearly exceeds placebo within-AUC (gap ≥ ~0.05 with permutation p < 0.05). If the placebo reproduces the residual, the "screening value" reading **DIES** — it is geometry, and the federal residual reverts to a null/artifact interpretation.
- Threshold: placebo/HV-winner permutation p **> 0.10** = clean null geometry (supports deflation); real-vs-placebo gap **p < 0.05** = cartel-specific (supports residual). Anything in between is reported as ambiguous, not spun.

**(d) Fallback.** If a claimed federal residual is reproduced by placebos, **abandon the residual/"institution-coupled screening value" reading (Draft B) and ship the deflation reading (Draft A)** with the negative controls front-paged as the reason. The negative-control battery is the arbiter between Draft A and Draft B — wire it that way.

---

### A10 — The price upgrade ("selection into matching — which items match?")

**(a) Failure mode.** "If you make *any* price/deflation claim federally using the `item_pregao_api` fields (`menorLance`/`valorEstimadoItem`), you match items at a 65–74% rate. Which 65–74%? If matched items are systematically the larger, more-contested, or more-documented ones, your federal price comparison is selected and not comparable to BEC. Show me the matched vs unmatched balance before I believe any federal price number."

**(b) Answers it.** `item_pregao_linkability.md` (field completeness: `valorEstimadoItem` 100% non-null/99.95%>0, `menorLance` 94.78%/94.70%>0, `valorHomologadoItem` 84.45%; situacaoItem split: homologado 84.45%, cancelado-no-julgamento 9.52%, cancelado 5.22%; grain `codigoitem` unique, 12.43M items / 426,021 tenders); the item↔award join-rate diagnostic (the "65–74% match" figure — locate the exact match-rate row before any price claim).

**(c) Survives / dies.** **Price is a Tier-2, optional leg** (per `99_COMPRASNET_EXTENSION_PLAN.md` D-ii: "default Tier 1 only; the comparative table does not require the bid tier"). So:
- **Cleanest path — SURVIVES by omission:** the federal *deflation/audit* leg needs **no price**; it runs on participation + winner flag. If no federal price claim is made, A10 never lands. **Recommended default.**
- **If a federal price claim IS made:** it **DIES** unless a matched-vs-unmatched balance table is shown first — compare matched vs unmatched items on year, UASG, situacaoItem mix, valorEstimadoItem distribution, and bidder count. SURVIVES iff the matched subset is balanced on observables (standardized differences < ~0.1) OR the price claim is explicitly scoped to "homologado items with non-null menorLance" with the selection stated. Note the awarded-item bias: `valorHomologadoItem` is present *exactly when the item was awarded* (situacaoItem = homologado), so conditioning on a price field silently conditions on award — a selection on the outcome.

**(d) Fallback.** **Do not make a federal price claim in the R&R.** The audit's contribution is the deflation/portability of the *screen*, not a federal price effect. If a price descriptive is irresistible, ship it only as an App G "price-field availability" note with the matched/unmatched balance table and the explicit homologado-selection caveat — never as a headline or a comparative-table row.

---

### A11 — Cobidder-rule divergence (raiz vs establishment anchoring)

**(a) Failure mode.** "Your `phase0_g3_linkage_audit.csv` (`cobidder_rule_divergence_vs_BEC`) admits the federal v3 linkage anchors on **8-digit RAIZ** while BEC anchors on **establishment**. Different anchoring grain = different cobidder universe = the comparison is contaminated at the label-construction step, before any score is computed."

**(b) Answers it.** `federal_cobidder_rebuild_vs_v3.csv` (rebuild_broad_AL_main_estab = 195 post-fix vs v3_cobidders_federal_AL = 222) and `phase0_g3_linkage_audit.csv` (`cobidder_rule_divergence_vs_BEC`, `exact_vs_fuzzy_directs` 26 exact/1 fuzzy, `cnpj_multiplicity` 0/0); plan decision D-i (rebuild from scratch via canonical establishment-anchored builder).

**(c) Survives / dies.** **SURVIVES** iff the federal label is **rebuilt establishment-anchored** (the canonical BEC rule), giving the **195** main target, with v3's 222 reported only as a set-comparison. **The v3→canonical delta is PROVEN (2026-06-05), and it is NOT an anchoring-grain artifact.** Decomposed exactly: of the v3 cobidder set, **313 cobidders (26 of them always-losers) are dropped by the TI/DF-case exclusion** (the unverifiable no-process-number case, see A8), plus **1 junk CNPJ** (the all-zeros sentinel `000000000000-2`); the **establishment-vs-raiz anchoring grain contributes 0** — v3 reproduces bit-for-bit when the TI/DF defendants are reinstated. So the referee's premise ("different anchoring grain = different cobidder universe") is empirically false here: the entire gap is the disclosed case-exclusion + one junk record, not a raiz-vs-establishment regrain. The drafts already specify establishment anchoring (`sec_appG` lines 47–53, 95–96). **DIES** only if the comparative numbers are computed off the raiz-anchored v3 set while claiming construction parity with BEC.

**(d) Fallback.** Use the establishment-anchored rebuild (**195**) everywhere as the main target; report exact-CNPJ-only sensitivity (26 vs 27 establishments) as the anti-fuzzy robustness, mirroring BEC discipline. The single fuzzy match (Dimaci, 0.943, ≥0.92 rule) gets a one-line disclosure. State the proven decomposition (TI/DF = 313 cobidders/26 AL + 1 junk; grain = 0) so the gap is read as the disclosed case exclusion, not an anchoring choice.

---

### A12 — STRICT cell collapse ("your finest opportunity control is non-functional federally")

**(a) Failure mode.** "Your `opportunity_cell_sparsity.csv` shows the federal STRICT cell (item×year×UASG) is **692,450 cells, every one a singleton** — 100% one-item cells, `share_part_in_sparse = 1`. A leave-one-out cell density on singletons is undefined; your STRICT within-stratum number is computed on zero usable support. Your finest opportunity adjustment is vapor."

**(b) Answers it.** `opportunity_cell_sparsity.csv` (STRICT: n_cells 692,450, cells_1_item 692,450, others 0); `opportunity_common_support.csv` (STRICT moderate/strict retention = 0, N_retained = 0, singleton_firms_dropped = 35,943).

**(c) Survives / dies.** This is **known true** from the diagnostics and is the federal analogue of BEC's STRICT sparsity (BEC STRICT: 99.5% <5 items). 
- **SURVIVES** iff the federal headline within-stratum verdict is reported on **MEDIUM** cells (12,781 cells, retention 96.7% under moderate/strict per `opportunity_common_support.csv`), with STRICT shown only in the granularity sweep and explicitly flagged as singleton-dominated/low-support. The drafts already designate MEDIUM as "the reference definition for the headline federal within-stratum results" (`sec_appG` line 102).
- **DIES** only if a STRICT federal number is presented as a primary result without the singleton disclosure.

**(d) Fallback.** Lead on MEDIUM; present STRICT as "support collapses to singletons federally (App G); the within-stratum verdict is read off MEDIUM cells, with STRICT reported for completeness only." Identical to BEC's handling of STRICT sparsity — internally consistent.

---

### A13 — Exposure-only inflation laundering (S2 read as score evidence)

**(a) Failure mode.** "Your S2 row 'score + log(1+E)' will show a high federal AUC. A careless reader — or a careless author — will cite it as the federal screen working. But E is built from the very defendant-contact rates that define the label; S2 is mechanically inflated and is *not* score evidence. Make sure the federal section doesn't launder S2 into a portability claim."

**(b) Answers it.** App G control-function table note (`sec_appG` lines 148–157, already states S2 is "mechanically inflated… not score evidence"); the isolating quantities `\valFedAudNestedIncrement` (nested DeLong increment over exposure-only) and `\valFedAudWithinAUC` (within-stratum).

**(c) Survives / dies.** **SURVIVES by drafting discipline** — the score's isolated federal contribution is **only** the nested increment `\valFedAudNestedIncrement` (BEC +0.010, p=0.013) and the within-stratum `\valFedAudWithinAUC`. **DIES** if any federal sentence or comparative-table cell cites S2 (combined exposure+score) as evidence the federal screen ranks cartels. Scan for it (language-discipline list below).

**(d) Fallback.** None needed — keep S2 in App G with its "label-encoding, not score evidence" note and never let it touch the comparative verdict table or the abstract/intro claims.

---

### A14 — Modality-margin loss ("you lost your one institutional ID lever")

**(a) Failure mode.** "Your BEC reading leaned on the convite-vs-pregão modality contrast as institutional variation. Federally convite is extinct (pure pregão). So the federal leg cannot replicate the one piece of institutional structure your BEC interpretation used — making it a weaker, not a stronger, test of the same mechanism."

**(b) Answers it.** `NEW_NUMBERS_MAP_COMPRASNET.md` header (modality margin: BEC convite+pregão vs federal pure pregão, ~15% regular + ~85% SRP); `sec_comparative_DRAFT.tex` lines 44–51, 143–145 (no modality stratification reported).

**(c) Survives / dies.** **SURVIVES** iff the loss is reframed as *sharpening* the construct test, not weakening it (already drafted, lines 48–51: "the loser-side construct must earn its keep without the modality variation that organized the BEC reading"). The federal leg tests the **construct + audit**, not the **modality mechanism** — consistent with the locked D2 rule (modality asymmetry is "scope information, not institutional identification"). **DIES** only if the federal section tries to make a modality-mechanism claim it cannot support.

**(d) Fallback.** State plainly: the federal panel has no modality margin; the federal leg therefore tests construct/audit portability, and the SRP-vs-regular split (A7) is the only available institutional contrast and is reported as such — not as a convite analogue.

---

## EXECUTION CHECKLIST (run when the federal chain lands)

For each attack, fill **X from file Y**, compare to **threshold Z**, write the one-line verdict. Order = dependency order (power and negative controls gate the verdict reading).

| # | Attack | Fill X (number) from file Y | Threshold Z | Verdict to write |
|---|---|---|---|---|
| A2 | Power | `\valFedAudPowerFive` ← `audit_armor/permutation_power_curve.csv` (0.55 row); positive control `\valFedAudOiControlMedium` ← `granularity_sweep.csv` | ≥0.80 powered / 0.60–0.80 marginal / <0.55 dies; control must reach ~0.95 | "Within-stratum null is [informative / weak / uninformative] at N+=195." |
| A3 | Case concentration | `\valFedAudTopCaseShare`, top-two share, `\valFedAudLOCOdropLargestPRAUC` vs `\valFedAudLOCOfullPRAUC` ← `table_G/table_H` | LOCO drop >60% ⇒ "one cartel"; top-two already ≈68% of 195 (disclose) | "Federal positives are more case-concentrated than BEC (top-two ~68%); LOCO [robust / collapses to case A(+D)]." |
| A9 | Negative controls | `\valFedAudPlaceboAUC`, `\valFedAudHVWinnerAUC` vs real ← `table_E_negative_controls.csv` | placebo p>0.10 ⇒ clean null; real−placebo gap p<0.05 ⇒ cartel-specific | "Surviving order is [generic geometry ⇒ Draft A / cartel-specific ⇒ Draft B]." |
| — | **Draft A/B switch** | gated by A2 + A9 above | null & placebo reproduces ⇒ **Draft A**; powered residual & placebo fails ⇒ **Draft B** | Keep one paragraph in `sec_comparative_DRAFT.tex`, delete the other. |
| A4 | Window/timing | `\valFedAudFrozenProspN`, `\valFedAudFrozenProspAUC` ← `frozen_timing.csv`; `\valFedAudStrictFullAUC` ← `table_D_strict_2013_2016…` | N≥120 ⇒ comparable; else "—" | "Frozen-timing [reported with 4-yr caveat / dropped to '—']; strict-universe collapse carries the prospective claim." |
| A6 | Cell coarseness | granularity sweep `\valFedAudWithinCoarse/Medium/Strict` ← `granularity_sweep.csv` | residual must not vanish only as cells tighten | "Federal cells one margin coarser; null is conservative / residual is [robust to / artifact of] coarseness." |
| A7 | SRP split | re-run within-stratum/LOCO on regular vs SRP (gates passed: `srp_stratification_feasibility.csv`) | strata agree ⇒ pool ok; disagree ⇒ stratify | "SRP and regular pregão [agree / disagree]; verdict [pooled / stratum-by-stratum]." |
| A12 | STRICT support | confirm MEDIUM is headline; STRICT flagged singleton ← `opportunity_cell_sparsity.csv` | headline must be MEDIUM | "Headline within-stratum on MEDIUM (12,781 cells); STRICT singleton-dominated, sweep-only." |
| A5 | FL cut | `\valFedAudWithinAUC` (score) is primary; `\valFedAudWithinFLAUC` secondary | score must not flip vs FL32 | "Continuous score is primary; verdict invariant to FL cut." |
| A1 | Anchor circularity | framing scan (no number) | zero "independent/out-of-sample" phrasings | "Scoped to method+construct portability; 'partially overlapping anchors' stated N times." |
| A8 | TI/DF exclusion | one-line sensitivity (federal verdict +2 TI estabs) | verdict unmoved | "TI case excluded (no process #); footnote present; sensitivity unmoved." |
| A11 | Anchoring grain | confirm establishment-rebuild 195 used ← `federal_cobidder_rebuild_vs_v3.csv` | main target = establishment 195, not raiz 222; v3→canonical delta PROVEN = TI/DF 313/26 AL + 1 junk, grain=0 | "Establishment-anchored 195 main; v3 222 set-comparison; gap is case-exclusion + junk, not regrain." |
| A10 | Price | **omit federal price claim** (Tier-1 only) | if claimed: matched/unmatched balance <0.1 SD first | "No federal price claim (Tier 1); or balance table shown + homologado-selection caveat." |
| A13 | S2 laundering | scan: S2 absent from comparative table + abstract/intro | zero S2-as-score citations | "S2 confined to App G with 'not score evidence' note." |
| A14 | Modality loss | framing scan | no modality-mechanism claim federally | "Modality loss reframed as construct-sharpening; SRP-split is the only institutional contrast." |

**Verdict-writing order:** A2 → A9 → (A/B switch) → A3 → A4 → A6 → A7 → rest. The Draft A/B paragraph choice is the single most consequential decision and is fully determined by A2 (power) and A9 (negative controls). Decide it first; everything else annotates it.

---

## LANGUAGE-DISCIPLINE SCAN LIST (run `grep` over `sec_comparative*`, `sec_appG*`, abstract/intro/conclusion before submission)

**FORBIDDEN verbs/phrases (zero tolerance — search and destroy):**
- `independent setting`, `independent validation`, `second ground truth`, `external validation`, `out-of-sample` (re: the labels), `replicates the labels` — all violate A1. Replace with "second platform, partially overlapping legal anchors".
- `detects cartelists`, `detects cartels`, `proves`, `confirms collusion`, `identifies the cartel`, `cartel members` (for cobidders) — replace "cobidder" reading with "adjudication-anchored exposure label, not membership".
- `outperforms`, `dominates` (re: federal vs anything), `the screen works federally` — the screen *deflates*; say "the audit travels", "the construct ports".
- any sentence citing **S2 / combined exposure+score** as evidence the federal screen ranks defendants (A13).
- any **federal price effect** stated as a result without a balance table (A10).
- `caused`, `treatment effect` (the sign result is screening value, not a treatment effect — locked rule).

**MANDATORY caveats (must appear, verbatim or near-verbatim):**
- **"second platform, partially overlapping legal anchors"** — at least once in the section intro, once in App G intro, once in the comparative-table notes. This is the load-bearing caveat.
- "the frequent-loser flag is never used to build the label" (non-circularity, both platforms).
- "cobidder = adjudication-anchored exposure, not cartel membership" — in every table note.
- "the federal cells are one margin coarser than BEC (no item-group)" (A6) — comparative-table notes + App G.
- "the federal positive base is more case-concentrated than BEC" (A3) — if A3 disclosure triggered.
- "no federal bid microdata; the bid-layer step cannot be constructed on public federal data" (on-thesis observability finding).
- "FL threshold re-estimated (32), not transported; the construct is the rule, not the cut" (A5).
- TI/DF exclusion footnote (A8).

**Build gate (carry over from BEC discipline):** compile appendix before paper (xr cross-refs); 0 undefined refs; every comparative cell reads a `values.tex` macro (no hard-coded literals); `\valFedAud*` namespace only (never collide with `\valFed*` panel descriptors); delete the `\providecommand{\valTODO}` blocks and `% TODO_NUMBER` tags before integration.

---

## OUTPUT SUMMARY

**Attack count: 14** (10 from the brief + 4 added: A11 cobidder-rule anchoring grain, A12 STRICT singleton collapse, A13 S2-inflation laundering, A14 modality-margin loss).

**The 3 attacks most likely to KILL the federal section (honest ranking):**

1. **A3 — Case concentration ("the result is one cartel").** *Highest kill probability.* Unlike the others this is **already structurally adverse before the run**: `canonical_case_labels.csv` shows top-two cases (trens_metros + medicamentos) = ~68% of the 195 positives (132/195; was ~67% of 196) and Case D alone = 59% of the 31,200 anchor tender-items — materially worse than BEC's 32% top-case. If federal LOCO drops PR-AUC by >60% on the largest case (BEC dropped only 37%), the federal "result" is honestly one or two cartels, and any cross-case generalization claim dies. It cannot be drafted around; it depends entirely on whether the federal cartels' co-bidding spreads across the positive base, which the concentration numbers suggest it does not. Mitigation is disclosure + retreat to "concentrated-anchor stress test", not survival.

2. **A2 — Positive-set power.** *Second.* The federal headline is a *null* (deflation), and a null at N+=195 (30% of BEC's 651) is worthless without power. The whole within-stratum deflation row — the heart of the comparative table — collapses if `\valFedAudPowerFive < 0.55`. Everything downstream (the Draft A vs Draft B choice) is gated on this single number. It is binary and out of the author's control: either the power curve clears 0.80 or the section's headline row is unsupported.

3. **A1 — Anchor circularity.** *Third — different in kind.* It cannot be killed by data (it's a framing exposure), but it caps the *ceiling* of what the section can claim no matter how the numbers fall: with 7/7 overlapping anchors (G3 = `FAIL_INDEP`), the strongest honest claim is "method + construct portability under held-constant labels", never "independent replication". A single careless "out-of-sample"/"independent" phrasing hands a hostile referee a clean kill on the section's entire raison-d'être. Probability of accidental violation is high because the natural language for a second-dataset section is exactly the forbidden vocabulary — hence the zero-tolerance scan list.

*(A7 SRP-disagreement and A9 negative-control-reproduces-residual are the next tier: each can kill a specific reading — pooled verdict / Draft B respectively — but not the whole section.)*

**File written:** `/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers/work/v22-editor/docs/jleo_rr_revision/R4_hostile_read_protocol.md`
