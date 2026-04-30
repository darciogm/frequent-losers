# Master Plan — JLE (A) / JLEO (B)

**Date:** 2026-04-29
**Decision:** Build the strongest possible paper for JLE. JLEO as fallback. Open to new tests and estimations.

---

## What changes vs. paths α/β documents

The earlier `new_story_outline.md` (α) and `jle_radical_rewrite.md` (β) assumed we'd work only with **existing reproducible material**. This plan adds: **new identification strategies that the data may genuinely support**, run before committing to a narrative. If even one delivers, JLE odds move from 35–40% to 50–60%. If none do, we fall to β (Detection without Identification) for JLE attempt, with JLEO ready as fallback.

The principle: **don't lock the narrative until the new tests have been run**. Decide narrative from data, not data from narrative.

---

## Three new identification strategies to try

### Strategy 1 — Sharp RDD on FL prevalence at R\$80,000 cap (highest-promise)

**Setup.** Lei 8.666 Art. 23 forces convite below R\$80,000 contract value and pregão above (until April 2018, when the cap rose to R\$176,000). The cap is administered on contract value, not bidder identity. McCrary density tests already pass (ratio 0.94, log-discontinuity −0.063, no manipulation evidence).

**The test.** Run a **sharp RDD on FL prevalence** (binary: tender has ≥1 FL participant) using running variable = log(contract value) and cutoff = log(R\$80,000). If the convite minimum-bidder rule generates regulatory cover bidding, FL prevalence should jump discontinuously **upward** as we cross from above the cap (pregão) to below (convite).

**Why this is identification (not just association).** The cap is a statutory rule, not a buyer choice. McCrary passes. Within a small bandwidth around the cap (say R\$70K–R\$90K), tender characteristics are arguably balanced. The discontinuity isolates the institutional channel that the v13 manuscript tried to claim with the within-convite split.

**What we learn.**
- If FL prevalence jumps at the cap → real identification of the regulatory channel. **JLE-grade evidence.** Replaces the dead `tab_modal_id` with a clean RDD figure.
- If FL prevalence is continuous → the rule does not generate cover bidding; cover bidding is modality-agnostic. Closes the institutional channel honestly. The §3 Detection-vs-Identification framing carries the paper.

**Implementation.** ~2 days. Use `rdrobust` (Calonico–Cattaneo–Titiunik) for optimal bandwidth + bias correction. Run on:
- DV1: FL prevalence (binary)
- DV2: log(negotiated price) — fuzzy (modality switch as instrument)
- DV3: number of bidders
- DV4: winner concentration

Falsification: re-run at placebo cutoffs (R\$50K, R\$100K). Robustness: triangular vs uniform kernel, bandwidth halving.

### Strategy 2 — Decreto 9.412/2018 cap raise as DiD

**Setup.** April 2018: the convite cap rose from R\$80,000 to R\$176,000. Tenders with contract value in **[R\$80K, R\$176K]** became newly convite-eligible. Tenders with values outside this range (control) had no modality change.

**The test.** Difference-in-differences:
$$y_{igt} = \alpha_g + \lambda_t + \delta \cdot \mathbb{1}[t \geq 2018-04] \cdot \mathbb{1}[v_{igt} \in [80K, 176K]] + \varepsilon_{igt}$$

For:
- DV1: FL prevalence (treatment effect on FL)
- DV2: log(p) (treatment effect on price — the welfare-relevant outcome)
- DV3: convite share (first-stage check — should jump for treated tenders)

**Why this works.** The Decreto is exogenous policy. The cap-raise expanded the convite-eligible range. If convite generates FL deployment, FL prevalence should rise in the [80K, 176K] range post-2018; if it does not, the institutional channel is empty.

**Pre-trend test.** Event study with leads $t = -3, -2, -1$ (placebo) and lags $t = +1, +2$ (treatment). If pre-trends are flat, parallel-trends survives.

**What we learn.**
- If FL prevalence jumps in the treated range → independent confirmation of the institutional channel. Combined with Strategy 1, this is decisive.
- If FL prevalence is unchanged → the cap-raise did not move cover bidding. Reinforces the §3 framing.

**Implementation.** ~3 days. Issues to handle: tender values may have manipulation around R\$80K (re-run McCrary on contract value distribution); cap raise was administrative not legislative — verify implementation date in TCE-SP records; the [80K, 176K] range had only ~10 months of post-treatment within sample (April 2018 to Dec 2019), so power may be limited.

### Strategy 3 — First-time-FL behavioral test

**Setup.** For each FL firm, identify their **first tender ever observed in BEC**. Same for non-FL always-losers (the comparison group). Compare bid distributions on first appearance.

**The test.** A firm whose first appearance shows bidding patterns characteristic of cover bidding (calibrated to reference price, narrow distribution, high relative-to-winner ratio) is behaving like a cover bidder *before* any selection on outcome can occur. They haven't lost anything yet.

**Why this works.** Selection bias arguments require selection on outcome (firms learn they will lose, adapt). On first bid, no learning is possible. If FL behavior is identifiable on first bid, the cover-bidding mechanism is detectable without selection.

**What we learn.** If FL bid 1 ≠ non-FL always-loser bid 1 in terms of:
- Distance from reference price (calibration)
- Distribution shape (narrowness)
- Ratio to winner price (markup pattern)

Then the FL flag captures behavioral type, not survivor selection. **This is a strong response to "FL is mechanically a function of losing".**

**Implementation.** ~2 days. Uses `bid_level_full.parquet` (40M rows). Need DuckDB for performance.

### What we drop from the original three-source identification claim

The within-convite n_genuine split (the failed `tab_modal_id`) is dropped. Strategies 1 + 2 are stronger institutional identification, and they don't depend on the partition that broke.

The McCrary density test is retained as supporting evidence (specification consistency at the cap).

---

## Three Tier-2 tests to harden the empirical core

### T2.1 — Cohort-stratified CADE spillovers

**Setup.** For each of the 12 CADE convictions, define the convicted sector (CNAE) and the conviction year. Test whether FL prevalence and prices in **other sectors** within the same year (or in PBUs that do business with the convicted firms) drop after the conviction. This identifies peer-deterrence: does enforcement in sector X spill to sector Y?

**Implementation.** Already-existing `flag2_cade_enforcement_did.R` extended with cross-sector interaction. ~2 days. Combines naturally with §6 CADE consistency check.

### T2.2 — Pregão real-time bid sequence patterns

**Setup.** Pregão has timestamped bids (real-time auction). FL firms may exhibit characteristic patterns: early bid + early withdrawal, no improvement attempts, bunched timing.

**Implementation.** Uses `bid_level_full.parquet`. Compute per FL bid: position in time within tender, withdrawal rank, number of improvement attempts. Compare to non-FL losers. ~3 days. Requires designing the comparison metric.

### T2.3 — Network position analysis

**Setup.** Build the firm × firm co-bidding graph. Compute network statistics for each firm: clustering coefficient, betweenness centrality, k-core membership, triangle count. Test whether FL firms cluster in network positions characteristic of cartels (high local clustering + repeated triangles).

**Implementation.** Already partly done in `tab_fl_network_summary.tex`. Extend with formal network-statistic comparisons. ~2 days.

---

## Honest welfare strategy: Manski-Pepper bounds

**Replacement for the deleted "Welfare under cover bidding".** Compute lower and upper welfare bounds:
- Lower: zero (no causal effect)
- Upper: full conditional association × FL-tagged spending

Plus a **sensitivity-bounded estimate** under Cinelli–Hazlett RV constraint: what is the residual welfare loss assuming the unobserved confounder explains exactly the bound (17.5%)?

Reports a **range, not a number**. Aligns with §3 Detection-vs-Identification thesis. Implementation: ~1 day.

---

## Phase plan (5 weeks total)

### Phase 1 — Data work (2 weeks)

**Week 1 (verification):**
- Day 1–2: Re-run all ⚠️ legacy scripts (`work/v8/scripts/*.R`). Document numbers ✅ or ❌. Update `forensic_audit.md`.
- Day 3: Run `00_master.R` end to end. Verify all canonical tables.
- Day 4–5: Run Strategy 3 (first-time-FL test). Lower bandwidth, faster turnaround.

**Week 2 (new identification):**
- Day 1–3: Strategy 1 (Sharp RDD at R\$80K cap). Run with `rdrobust`, multiple bandwidths, falsification at placebo cutoffs.
- Day 3–5: Strategy 2 (Decreto 9.412 DiD). Event study, pre-trend test, robustness.

**Decision point at end of Week 2:**
- If Strategy 1 OR Strategy 2 succeeds → Path β-prime (radical + identification). Target JLE 50–60%.
- If neither succeeds → Path β (radical Detection-vs-Identification). Target JLE 35–40%.
- Path α (non-radical → JLEO/IJIO) becomes the fallback if Path β submission rejects.

### Phase 2 — Architecture + §3 NEW (1 week)

- Day 1–2: Write §3 "Detection vs Identification" essay (the methodological core, 2 pages of careful prose).
- Day 3–4: Decide section structure. If β-prime: §7 Identification gets the new RDD/DiD figures and tables. If β: §7 reframes to "Mechanism Coherence" only.
- Day 5: Outline draft. Send to Paulo for sanity check before full rewrite.

### Phase 3 — Full rewrite (2 weeks)

- Week 1: Front matter + §1 Intro + §2 Lit + §3 NEW + §4 Institutional + §5 Data.
- Week 2: §6 Detection + §7 Identification (or Mechanism Coherence) + §8 Mechanisms + §9 Limitations + §10 Conclusion.

Concurrent: Tier 2 tests integrated as supporting subsections in §6/§8.

### Phase 4 — Polish + submission (1 week)

- Day 1–2: Bibliography sweep using anti-hallucination protocol from CLAUDE.md (every reference verified author/year/title/journal/volume/pages against authoritative source).
- Day 2–3: Compile. Read full PDF integral. Fix orphan refs, broken cross-refs, equation-label drift.
- Day 4: Cover letter (JLE house style: 1.5 pages, lead with the contribution, identify 3 plausible reviewers).
- Day 5: Submission. Backup copy to `submissions/jle_2026q2_v1/` with full replication archive zipped.

---

## Risks and mitigations

| Risk | Probability | Mitigation |
|---|---|---|
| Strategy 1 RDD finds no jump at cap | 50% | Default to β framing; the null result strengthens "rule does not generate cover bidding" leg of §3. |
| Strategy 2 DiD pre-trends fail | 40% | Document failure honestly; report Rambachan–Roth bounds; falls into β. |
| Strategy 3 first-time-FL test ambiguous | 30% | Reframe as descriptive only; less weight in §6. |
| Some Tier-2 test contradicts the cartel ecosystem reading | 20% | Honest disclosure in §9; the contradiction is informative. |
| ⚠️ Legacy script re-run produces different numbers | 25% | Update audit; replace numbers in manuscript; document reason. |
| §3 NEW essay reads defensive | unknown | Draft early (Day 1 of Phase 2); send to Paulo before committing. Iterate. |
| JLE rejects | 50–65% (path-dependent) | JLEO submission ready within 2 weeks of rejection (path-α version uses ~70% of the same content). |
| Submission delayed by data issue | 20% | Phases are independent; data work in Phase 1 is safe to repeat. Built-in slack: 1 week. |

---

## What gets cut from v13

- ~~`tab_modal_id` and the within-convite identification claim~~ — replaced by Strategy 1 RDD (or, if RDD fails, dropped entirely with §9 disclosure).
- ~~"Voluntary > binding sign flip" framing in §1, abstract, highlights, §7.4, §11~~ — gone.
- ~~Welfare 0.3–0.9% as policy estimate~~ — replaced by Manski-Pepper bounds.
- ~~Structural model markup interpretation~~ — calibration appendix only.
- ~~Counterfactual welfare main-text section~~ — appendix only with explicit "assumes causality" caveat.

Total page reduction: ~12–15 pp from v13's 81 pp. Target ~55–60 pp main + ~25 pp appendix = ~80 pp total (roughly the same envelope, different content distribution).

---

## What ships to JLE

| Section | Pages | Source | New material? |
|---|---|---|---|
| Front matter | 2 | Rewrite | Yes — abstract, highlights |
| §1 Introduction | 3 | Rewrite | Yes — three-act structure |
| §2 Related Literature | 1 | Light edit of v13 | No |
| §3 Detection vs Identification | 2 | NEW | Yes — entire section |
| §4 Institutional Framework | 1.5 | Light edit of v13 | No |
| §5 Data and FL Definition | 1.5 | Same as v13 | No |
| §6 Detection Performance | 5 | Reorg of v13 §6+§7 | Some — first-time-FL added |
| §7 Identification (β-prime) OR Mechanism Coherence (β) | 4 | NEW or reorg | Conditional on Phase 1 results |
| §8 Mechanism Coherence | 3 | v13 §8 mostly intact | Network test added |
| §9 Limitations as Contribution | 2 | Heavy rewrite | Yes — admission paragraph |
| §10 Conclusion | 1.5 | Rewrite | Yes |
| Bibliography | varies | Verified | Yes — sweep |
| Appendix | 25 | Mostly v13 | Some new |

Total main: ~26 pp. Headline content fits JLE's preferred length.

---

## Cover letter outline (Phase 4 deliverable)

1. **Hook (paragraph 1).** "We propose a participation-only screen for bid-rigging cartels deployable in procurement systems without bid microdata. Validated against São Paulo's CADE adjudications, the screen achieves AUC = 0.94 prospective. We develop a methodological distinction between cartel detection and cartel identification and demonstrate it empirically."

2. **Three contributions (one paragraph each).** Detection screen with parsimonious data requirements; Bajari–Ye partition input for downstream tests; L&E Detection-vs-Identification distinction with deployment pathway.

3. **Why JLE.** The detection-vs-identification distinction is precisely the kind of methodological argument JLE has historically published (Posner 1970, Polinsky–Shavell 2000). The empirical work demonstrates the distinction is operational. The L&E pathway argument is precisely scoped.

4. **Three plausible reviewers** (avoiding any from Imhof/Huber/Wallimann tree to avoid hostile paradigm-defenders): Conley (procurement), Asker (auction theory), Caoui (procurement institutional), Best (procurement design), Bandiera (corruption + procurement). Pick 3.

5. **Status of related work.** Companion piece (paper 4 *Beneath the Surface*) on RAND track; this paper is independent.

---

## What success looks like at end of Phase 1 (2 weeks from now)

A document `work/v13/phase1_results.md` with:

1. ✅/❌ status for all ⚠️ legacy numbers in `forensic_audit.md` (everything reproducible or replaced).
2. Strategy 1 RDD result: jump or no jump at R\$80K cap, with figure.
3. Strategy 2 DiD result: pre-trends pass or fail, with event-study figure.
4. Strategy 3 first-time-FL result: discriminating signal or not.
5. T2.1, T2.2, T2.3 results integrated into supporting evidence file.
6. Decision: Path β-prime (with new ID) or β (Detection-vs-Id only)?

This document is the input to Phase 2 (architecture + §3 NEW writing).

---

## Open questions for Paulo before Phase 1 starts

1. Does INSPER have access to **post-2019 BEC data**? If yes, the CADE event study extends; if not, we work with 2009–2019.
2. Is **TCE-SP cooperation** available for the contract-value-cap implementation date verification (Decreto 9.412/2018)?
3. **Who else has read v13**? If anyone outside INSPER has seen the paper with `tab_modal_id` numbers, we need to communicate the reproducibility issue before submission.
4. **Co-author timing**: when is Paulo available for the Day 5 of Phase 2 outline check?

These are decision-relevant; defer Phase 1 only if necessary, but answer them within the first 3 days.

---

## What I will commit to before starting Phase 1

I will not lock the narrative until Phase 1 results are in. Specifically:

- I will not write §3 NEW until I know whether Strategy 1 succeeds.
- I will not delete `tab_modal_id.tex` from v13 (already reverted).
- I will not assume any specific outcome from the new tests.

This discipline is the difference between honest empirical work and the v13 problem we just diagnosed.
