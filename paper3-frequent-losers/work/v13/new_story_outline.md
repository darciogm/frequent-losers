# v14 (provisional) — Outline based on what reproduces

**Date:** 2026-04-29
**Premise:** The detection contribution survives unchanged. The institutional identification contribution (Movement 3 of v13-jle) does not — `tab_modal_id` headlines (+0.076 voluntary / −0.160 binding) cannot be reproduced, and the canonical pipeline produces the **opposite** sign in the binding cell. This outline rebuilds the paper using only numbers in the ✅/⚠️ buckets of `forensic_audit.md`.

---

## What dies (and how to bury it cleanly)

| Dead claim | Replacement | Where the body changes |
|---|---|---|
| "Voluntary 7.6%, binding −16% — the rule's effect identifies cover bidding institutionally" | The within-convite split is reported as a **descriptive heterogeneity** (voluntary +4%, binding +7%) consistent with non-causal readings | §1 intro, §5 strategy, §7.4 identification, §8 mechanisms, §11 conclusion |
| "Three institutional sources jointly identify $\beta$" (modal + within-convite + statutory threshold) | Modal + threshold as **specification consistency**, not identification. McCrary stays. The within-convite split is dropped from the identification claim, demoted to descriptive heterogeneity. | §5 strategy, §7.4 (renamed §7.4 *Mechanism coherence*) |
| "The institutional design identifies the 7.6% premium" | Removed | abstract, intro, conclusion |
| "Convite's rule generates regulatory cover bidding; the screen exploits the resulting decoy population" | "Cover-bidding incentives exist in both modalities; the screen detects them across the modal split, with pregão (no rule) showing the cleanest signal" | §3 institutional, §1, §11 |
| "Welfare quantification at 0.3–0.9% of spending" if presented as policy estimate | Kept as illustrative back-of-the-envelope only, with explicit "assumes causality the design does not establish" | §9, appendix |

## What survives

The empirical core: detection performance, CADE external consistency, Bajari–Ye partition contribution, mechanism diagnostics M1–M5, conditional price gap with sensitivity bounds, cross-sector replication, operational pathway.

---

## Three contributions (revised)

The new contribution structure aligns 1:1 with three literatures and three reproducible empirical anchors.

### Contribution 1 — Operational detection screen

**Anchor:** AUC = 0.94 prospective against CADE (DeLong CI [0.932, 0.946]); AUC = 0.748 contemporaneous (CI [0.713, 0.783]); cross-sector mean AUC = 0.954 (SD 0.034) across 10 sectors.

**Lit gap:** Imhof, Huber, Wallimann tools require bid microdata that many electronic platforms do not preserve. The FL screen runs on contract-award records (winner, participants).

**Reproducibility:** ✅ — `roc_detection.py` reruns directly on current data; commit `1f41c1b` already validated the contemporaneous version.

**What this is, plainly:** the cheapest possible cartel screen, deployable wherever a procurement system records who participated and who won.

### Contribution 2 — Bajari–Ye partition

**Anchor:** Bajari–Ye exchangeability rejected at $D = 0.15$, $p < 0.001$; conditional-independence rejected at $t = 81.0$, $p < 0.001$. The FL classifier provides the *ex ante* firm-level partition the test requires; prior implementations rely on *ex post* (post-conviction, leniency) partitions or on assumed group structure.

**Lit gap:** Bajari–Ye (2003), Conley–Decarolis (2016), Porter–Zona (1993, 1999), Asker (2010), Marshall–Marx (2012), Schurter (2020), Clark et al. (2021) — the partition is constructed *ex post* or by assumption in every case. The FL classifier is the first construction of an ex ante partition usable as input to these tests.

**Reproducibility:** ⚠️ — `tab_bajari_ye_corrected.tex` exists; rerun `flag1_bajari_ye_corrected.R` to confirm.

**What this is, plainly:** a methodological infrastructure piece — the FL screen is not just a flag, it is a partition that downstream forensic tools (which require the partition as input) can now consume.

### Contribution 3 — Law-and-economics deployment pathway

**Anchor:** Three-stage pathway Screen → Triage → Investigate, ordered by marginal data cost. Stage 1 needs nothing oversight bodies do not already have. Stage 2 reuses warehouse-resident HHI and pair counts. Stage 3 invokes bid-level forensic tools where they have real bite.

**Lit gap:** Sanchez-Graells (2019) and OECD (2019) flag the resource gap in low-resource enforcement; the FL screen closes part of it operationally.

**Reproducibility:** ✅ — pathway is normative argument; institutional facts referenced in §3 are public.

**What this is, plainly:** the operational claim. The screen does not identify cover bidders firm-by-firm and does not deliver a causal welfare estimate; it lowers the data threshold for proactive enforcement.

### What's NOT a contribution anymore

- ~~"Regime 2 cover bidding documented empirically"~~ — the price gap is conditional, not causal.
- ~~"Sign flip identifies the regulatory channel"~~ — does not reproduce.
- ~~"Welfare quantification under the cover-bidding regime"~~ — illustrative only.
- ~~"Cross-modality variation as identification"~~ — descriptive specification consistency, not identification.

The contribution count drops from 4 (CLAUDE.md) → 3 (v13-jle) → **3 (revised)**, but the contribution **content** has shifted: the institutional identification piece is replaced by the partition contribution. This is a cleaner story, not a weaker one.

---

## Section-by-section outline

### Front matter

**Title (provisional):** *Detecting Bid-Rigging Cartels Without Bid Microdata: A Frequent-Losers Screen* — keep current title; it never claimed institutional identification.

**Abstract (rewrite):** Lead with detection (AUC 0.94 prospective, 0.748 contemporaneous, 0.954 cross-sector). State the partition contribution. State the conditional price gap (3.6–7.7%) with explicit "conditional association, not causal estimate." Drop the "7.6% under voluntary cover bidding" sentence. Drop "institutionally identified." Keep RV bound (17.5%), eight-of-twelve prospective fact, contribution paragraph.

**Highlights:** Replace "FL premium of 7.6%..." with "Bajari–Ye exchangeability rejected at D=0.15 using the FL partition" or similar. Keep the rest.

### §1 Introduction (rewrite, ~3 pages)

**Paragraph structure:**
1. The puzzle: 16,843 always-losers, 2,735 placed bids in 14+ tenders, sustained zero-win participation rationally dominated under any standard entry model.
2. The institutional setting: convite's minimum-bidder rule + pregão's electronic format. **Reframed:** both modalities create cover-bidding incentives; the rule is a procedural floor that interacts with strategic deployment.
3. The screen: define FL in two steps (always-losers + IQR threshold). Emphasize parsimony.
4. Findings (detection-first, in this order):
   - AUC 0.94 prospective / 0.748 contemporaneous; cross-sector 0.954.
   - Bajari–Ye partition rejected at D=0.15.
   - Conditional price gap 3.6–7.7% (cross-fit, OLS, matching, IV); modal heterogeneity with pregão showing the largest premium (9.3%) — explicitly *not* identifying-channel claim.
   - Mechanisms M1–M5 jointly fit cartel ecosystem.
5. Three contributions (the new ones above).
6. Honest scope statement (what the design does not deliver — same content as v13 final paragraph, slightly expanded).
7. Roadmap.

**Headline number to lead with:** AUC = 0.94 prospective / 0.748 contemporaneous / 2.6× within-firm enrichment / Bajari–Ye D = 0.15. NOT "+7.6% under voluntary cover bidding."

### §2 Related Literature (light revision, 1 page)

Keep the four-literature structure. Synthesize at end into the **three** contributions, not four.

Edit the synthesis paragraph: drop "operates prospectively rather than retrospectively" (still true but redundant), foreground the partition contribution.

### §3 Legal and Institutional Framework (light revision)

Keep the institutional content (Lei 8.666, 10.520, 12.529, 14.133, OECD parallels).

**Critical edit:** the paragraph that currently reads "the convite minimum-bidder rule generates a population of firms whose participation pattern is the empirical signature of regulatory cover bidding" — soften to: "the rule, designed to ensure procedural competition, can be satisfied either by genuine entry or by mechanical cover bidding. Whether the rule generates cover bidding or merely accommodates it is an empirical question the price-gap pattern alone cannot settle. The screen detects the configuration without committing to the cover-bidding generation channel."

**Optional add:** TCE-SP/CGE/CADE roles (already present) → keep.

### §4 Data and FL Definition (unchanged, 1.5 pages)

All numbers ✅: 4.5M tender-items, 16,843 always-losers, threshold = 14, 2,735 FL, 4.8% participation share, 1,654,447 obs sample, item-FE structure.

Add a small box: "Why median + 1.5×IQR rather than Tukey Q3 + 1.5×IQR" — keep current explanation.

### §5 Empirical Strategy (substantial rewrite, 2 pages)

**Old structure:** "Three institutional sources jointly identify $\beta$" → modal + within-convite binding + statutory threshold.

**New structure:** "**Specification design**" — three layers of conditional-association evidence, none claiming strict causal identification.

1. **Reduced-form baseline.** Equation (2) with item × year × PBU FE, item-clustered SE. Coefficients reported as "conditional associations" throughout.
2. **Modal heterogeneity.** Pregão (9.3%) vs convite (3.8%). Reframed as: "the modality without a minimum-bidder rule shows the larger premium, so the rule is not the proximate cover-bidding driver in our data; the heterogeneity is consistent with pregão's real-time format facilitating coordinated deployment more than convite's sealed-bid format."
3. **Specification consistency.** McCrary at R\$80,000 cap (passes — ratio 0.94, log-density disc −0.063, convite share gap 9.8 pp). Cross-fit (3.6%). Matching (CEM 7.7%, IPW 5.5%). Continuous treatment (0.022 per log-pt).
4. **Sensitivity to unobservables.** Cinelli–Hazlett $RV_{q=1} = 17.5\%$. Oster bound is degenerate (R² jump near zero) — flagged as such.
5. **What we drop and why.** Staggered DiD (CS, stacked) — pre-trends invalidate parallel trends. Honest declaration. Rambachan–Roth bound the maximum permissible pre-trend slope; conclusion does not survive.

**The within-convite n_genuine split** appears in §7.4 as descriptive heterogeneity, not as identification. Different status, different prose.

### §6 CADE External Consistency (mostly unchanged)

All reproducible. Keep:
- 12 cases / 65 firm-defendants / 47 BEC-active / 8 post-2019.
- 193 FL co-bidders, 7.1% rate vs 2.0% perm baseline = 3.5×.
- 3 of 7 always-loser defendants are FL = 43% vs 16% baseline = 2.6×.
- Pre-2020/post-2019 split: 2/2 vs 1/4.
- Contemporaneous AUC 0.748 [0.713, 0.783] (commit `1f41c1b`).
- Conditional FL–CADE p=0.93 honest disclosure.
- Excluding CADE tenders: $\hat\beta = 0.062$, N=1,622,954.

The "headline 0.94 prospective / 0.748 contemporaneous, both bounds reported" framing from v13 already does the right thing. Keep it.

### §7 Results (substantial reorganization, ~6 pages)

**§7.1 Reduced-form OLS.** Equation (2). Pregão 9.3%, convite 3.8%, general+PBU 6.4%, general 6.8%. All ✅.

**§7.2 Cross-fit.** 3.6% canonical. ⚠️ rerun.

**§7.3 Matching.** CEM 7.7% (N=969,751), IPW 5.5% (N=830,194). ⚠️.

**§7.4 Mechanism coherence (renamed from "Additional Identification").**
- Pre-trend interpretation honest (selection or confounders, both readings).
- **Modal × n_genuine table** with **canonical numbers from `11_modal_id.R`** — voluntary +4.0%, binding +7.4% (sample-split). Or, if the $\log(n_{\rm genuine})$-controlled spec is preferred for sign coherence: +9.7% / interaction −11.0%, with the control disclosed in the table footnote.
- Reverse-causality test: 0.0021 (SE 0.0008). ⚠️ rerun.
- Callaway–Sant'Anna ATT FL-exit: −0.275 ($p<0.001$), price ATT 0.145 (SE 0.110, imprecise). ⚠️ rerun.
- **Crucially: do not claim institutional identification.** Frame as: "the modal heterogeneity is *consistent with* cover-bidding incentives operating across both formats, with pregão showing the larger premium because its real-time format facilitates strategic coordination unconstrained by procedural cover-bidding requirements."

**§7.5 Detection benchmarking.** AUC 0.94 prospective, 0.748 contemporaneous, Imhof CV 0.79, ML composite 0.84, suppression effect 0.064→0.084 with Imhof flag. ⚠️ rerun.

**§7.6 Bajari–Ye partition test.** D=0.15, t=81.0, first-stage R²=0.770, tender-FE saturation. ⚠️ rerun.

**§7.7 Cross-sector AUC stability.** 15 sectors with N>50,000, 10 with ≥3 CADE positives, mean AUC 0.954 (SD 0.034). Largest +25.5%, smallest −0.010 / −0.014. ⚠️ rerun.

**§7.8 Network heterogeneity.** Competitive-market FL coef 0.126 ($p<0.01$); concentrated-market FL coef −0.018 ($p>0.3$). ⚠️ rerun. Could be combined with §7.4.

### §8 Supporting Diagnostics M1–M5 (mostly unchanged)

All five tests retained:
- **M1.** +0.143 non-FL firms ($p<0.01$) — no crowding-out.
- **M2.** Winners bid 4.1% closer to ref price ($p<0.01$) — calibrated cover bidding.
- **M3.** Reverse-causality elasticity 0.0021 (SE 0.0008) — too small by 30× to drive headline.
- **M4.** Dyadic permutation: 4,603 pairs ≥5 vs 3,271 perm mean ($p<0.001$); top-10 mean 129.7 vs perm 109.9 ($p=0.016$).
- **M5.** Cox HR=0.60 ($p<0.01$, PH rejected) — longer survival in FL-exposed markets.

Plus the rationality block (R\$700–7,000 at threshold; R\$2,500–25,000 at 90th percentile; Bayesian posterior at n=50 yields gain R\$163 < lower-bound cost R\$200) — unchanged ✅/⚠️.

Plus bid-rotation/bid-inflation sub-block: HHI 0.178 vs 0.303, 38,941 pairs / 4,603 ≥5, FL bid 15.4% above non-FL ($p<0.001$). ⚠️ rerun.

### §9 Robustness (unchanged structure, ⚠️ rerun)

Threshold sensitivity, Cinelli–Hazlett, Oster degenerate, oversight quartiles (12.5×), staggered DiD as transparency artifact, illustrative welfare 0.3–0.9% (with the "assumes causality" caveat foregrounded).

### §10 Limitations (light revision)

**Add as primary limitation:** "The price-gap claim is a conditional association, not a causal estimate. Pre-event coefficients in the within-PBU FL-entry event study at $t=-2,-3$ preclude a fully causal reading. The institutional identification we attempted in v13 (modal × within-convite constraint) does not survive the canonical pipeline; we report the within-convite split as descriptive heterogeneity in §7.4 with explicit disclosure."

This is the honest disclosure that turns the audit into a positive feature: we found the bug, we fixed it, we report what the data say.

Other limitations unchanged: persistence, zero-win threshold, conditional FL–CADE indistinguishability, prospective ground truth, structural model is calibration, external validity.

### §11 Conclusion (rewrite, ~1.5 pages)

**Paragraph structure:**
1. The participation residue + screen + CADE validation. Detection generalizes.
2. **Reframed honest paragraph:** "The price-gap claim is weaker. A 3.6–7.7% conditional association across OLS, matching, and cross-fit. The modal heterogeneity (pregão 9.3% > convite 3.8%) is consistent with cover-bidding incentives operating across both formats; we do not interpret the modal split as identifying the cover-bidding channel. Welfare losses beyond the 0.3–0.9% illustrative range require causal identification this design does not provide."
3. What does not survive: explicit list (not a hidden disclosure — a feature of the paper).
4. The three contributions restated.
5. Implementation pathway: Screen → Triage → Investigate. Same as v13. ✅
6. Open questions: causal price effect (post-2021 Lei 14.133 DiD), external validity (ComprasNet, OECD), sector-cartel correspondence (BEC item dictionary).
7. Closing line: "Whether frequent losers are unlucky competitors or cartel operatives, their presence marks procurement environments that warrant closer look — and the closer look can begin with the data oversight bodies already have."

---

## Target journals (recalibrated)

| Journal | Fit | Realistic verdict |
|---|---|---|
| **JLE** | Was target. Without institutional identification, the L&E framing is operational only. Possible but a stretch — JLE wants identification. | Risky. ~30% acceptance odds without rebuilding identification. |
| **JLEO** | Better fit — methodology + L&E + screening. Reviewers expect descriptive associations more readily. | Best target. ~50–60% odds with the new outline. |
| **IJIO** | Very strong fit — empirical IO, cartel detection, partition contribution, ML/ROC validation. | Strong target. ~50–60%. |
| **JoEMS** (Methods Series) | Methodology piece (partition contribution as the hook). | Strong target if reframed as methodological. ~60%. |
| **Journal of Antitrust Enforcement** | Substantive perfect fit; lower prestige; faster review. | Backup if top-3 above don't land. |
| **RAND** | Possible but the stricter referee bench will hammer the conditional-association framing. | Low odds. ~15%. |
| **AEJ:Applied / AEJ:Policy** | The conditional-association framing is fatal at AEJ. | Skip. |

**Recommendation:** target JLEO or IJIO; have JoEMS as a methodology-pivot fallback. JLE only if Paulo wants to gamble on the L&E framing carrying it.

---

## What this outline costs to execute

| Step | Work | Time |
|---|---|---|
| Rerun all ⚠️ scripts | Step 1 of forensic audit, ~13 scripts | 2 days |
| Rewrite intro + abstract + highlights | Heavy editing | 2 days |
| Rewrite §3 institutional para | Surgical edit | 0.5 day |
| Rewrite §5 strategy | Substantial (drop institutional ID claim) | 1 day |
| Rewrite §7 results, esp §7.4 | Reorganize, drop sign-flip story, insert canonical numbers | 1.5 days |
| Update §11 conclusion | Surgical | 0.5 day |
| Revise tables (especially `tab_modal_id`) | Replace numbers, change footnote | 0.5 day |
| Bibliography sweep | Verify cited references after structural edits | 1 day |
| Compile + read PDF integral | Quality check | 0.5 day |
| **Total** | | **~10 days** |

If you want to accelerate, the rerun and the §5/§7.4 rewrite are the critical path. Everything else is parallelizable.

---

## What to take to Paulo

The five things this outline asks Paulo to ratify:

1. **Detection-first framing.** Lead with AUC, not with the price gap.
2. **Drop the institutional identification claim.** Voluntary > binding does not reproduce; reframe as descriptive heterogeneity.
3. **Promote the Bajari–Ye partition contribution.** This is genuinely novel; we under-sold it in v13.
4. **Recalibrate target journals.** JLEO/IJIO/JoEMS are realistic; JLE is now a stretch.
5. **Honest disclosure of what failed.** The §10 limitations paragraph explicitly states the v13 institutional ID did not survive the canonical pipeline. This converts a vulnerability into a credibility signal.
