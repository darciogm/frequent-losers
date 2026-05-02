# JLEO Reframe Final — v16

**Goal.** Rewrite the manuscript so it reads as a JLEO paper — about *screening under incomplete observability*, *enforcement architecture with layered information*, *equilibrium-generated loser-side participation*, *award-layer screening before bid-layer forensics* — not as a procurement-management or public-administration paper. Strongest claims first, no rhetorical forcing.

**This pass executed.** Title, abstract, introduction, empirical-strategy framing, validation framing, and conclusion rewritten. Related-literature section already JLEO-coded by prior pass; minor calibration only. Section-internal evidentiary structure already adjusted in Subprompts 3 and 4 (sign-reversal demoted, theory-validation bridge inserted).

---

## I. New central question

> When a cartel-enforcement environment preserves only the contract-award layer — winner identity, participant identity, item code, negotiated price — what collusion-relevant information remains, and how should the resulting enforcement architecture be sequenced?

This single question carries three sub-questions, one informational, one architectural, one design-theoretic.

1. **Identifiability under coarsening.** Is there a statistic that the collusive arrangement generates which survives the move from the bid layer to the award layer?
2. **Architectural sequencing.** If such a statistic exists and discriminates cartel-adjacent populations comparably to bid-distribution methods, does the appropriate enforcement architecture deploy it as a screening stage that runs ahead of bid-layer forensic methods, or as a substitute for them?
3. **Equilibrium content of the statistic.** Is the candidate statistic — endogenous loser-side participation — read as deployment evidence of cover bidders in a separating equilibrium, or as confounded variation in firm types? The first reading licenses a screening interpretation; the second forces a treatment-effect framing.

The framing dictates everything downstream: the discrimination AUC is the primary object (it answers the identifiability question), the architectural test against the Imhof pipeline is co-headline (it answers the sequencing question), and the conditional price imprint is descriptive corroboration that the screening signal also leaves a price trace on the items it concentrates on.

## II. New contribution statement

> **Under incomplete observability of the bid layer, an award-layer screening statistic derived from a separating-equilibrium framework with cover bidders discriminates cartel-adjacent populations at accuracy comparable to bid-distribution methods that require bid microdata, with non-redundant signal in same-sample combination. The architectural implication is that an award-layer screening stage runs ahead of the bid-layer forensic stage the prior literature requires; the two stages answer different questions, operate on different data envelopes, and trade off accuracy against deployability in different ways. The contribution is informational and architectural, not causal.**

The contribution is sharply scoped:

- **Informational.** What survives the data-coarsening step. Answer: a participation-based ranking statistic identified under MLR Poisson assumptions, with the binary frequent-loser rule its information-coarsening.
- **Architectural.** How enforcement should be sequenced when bid microdata are unavailable or expensive to query. Answer: screening on award records first, forensic on bid microdata second; not the reverse, not parallel, not substitutable.
- **Equilibrium-grounded.** Why the participation statistic carries the signal. Answer: cover bidders satisfy $\Pr(\text{win}\mid C)=0$ in equilibrium and concentrate participation in cartel-affected items; the resulting footprint is what the award layer preserves.

The contribution is **not**:
- a procurement management improvement;
- a deployment recipe for audit courts;
- a public administration paper about cartel enforcement at the level of a single jurisdiction;
- a causal estimate of cover bidding's effect on prices;
- an identification of any institutional channel.

## III. Strongest evidentiary pillars

| # | Pillar | Object | Evidence | Strength |
|---|---|---|---|---|
| 1 | Discrimination of cartel-adjacent populations under coarsened observability | AUC | $0.864$ temporal holdout (train 2009–2016, test 2017–2019); $0.748$ pre-2020 conservative benchmark with permutation null ($p<0.001$) | **Primary** |
| 2 | Architectural separation: award-layer screening reaches forensic-comparable accuracy on a thinner envelope, with non-redundant signal in combination | Same-sample AUC comparison vs Imhof pipeline | $0.903$ (FL14) vs $0.888$ (Imhof full); $+0.035$ AUC same-sample, DeLong $p=0.014$ | **Primary** |
| 3 | Theory-validation bridge: cobidders match the modeled cover-bidder type along $4/5$ measurable operational predictions | Within-stratum descriptive comparison | Cohen's $d$ up to $+1.00$ on unique winners faced (deployment intensity); $+0.46$ on direct-CADE proximity; $+0.39$ on item-group HHI (specialization); $-0.32$ on n distinct item-groups (specialization) | **Primary** |
| 4 | Continuous primitive strictly dominates binary cutoff | DeLong test | $p<10^{-3}$ | Supporting |
| 5 | Pricing imprint as descriptive corroboration | Conditional $\beta$ | $+3.6\%$–$+7.7\%$ across four estimators on broad sample; $+4.4\%$ ($p=0.035$) on overlap subsample without ATT-weighting | Supporting |
| 6 | Sensitivity to selection on observables | Cinelli RV; Oster $\delta$ | $RV_{q=1}=17.5\%$; $\hat\delta=261.6$ | Supporting |
| 7 | Honest disclosure: failed RDD/DiD designs reported | McCrary; parallel-trends | Density discontinuity; failed pre-trends | Disciplinary |

Pillars 1–3 are the JLEO-facing argument. Pillar 5 (pricing) is descriptive corroboration with the sign reversal demoted to one paragraph in Results and one paragraph in App A; the empirical decomposition (Subprompt 3) shows the sign reversal is overwhelmingly an ATT-reweighting artifact, not an overlap-dropping phenomenon. Pillars 6–7 carry the disclosure discipline that JLEO referees expect.

## IV. Claims deliberately narrowed

Six claims that v15 made explicitly or implicitly are now narrowed in v16. Each narrowing replaces a verbal rhetorical move with a precise factual statement the data support.

| v15 framing | v16 framing |
|---|---|
| Pricing $\beta = +3.6\%$–$+7.7\%$ leads the abstract and §1 | Discrimination AUCs lead the abstract and §1; pricing is one descriptive corroboration sentence |
| Sign reversal under overlap restriction is the "screening-value diagnostic" | Sign reversal decomposed empirically: $+0.044$ unweighted overlap remains positive; $-0.097$ ATT-weighted is a reweighting result; cell-dropping evidence is mixed (1 of 6 dimensions consistent with screening reading) |
| "Cobidders are the empirical content the screening statistic recovers" | "Cobidders are the within-stratum population whose descriptive profile is closest to the cover-bidder type along 4 of 5 measurable operational predictions" |
| Primary empirical object is the broad-sample $\beta$ | Primary empirical object is the discrimination AUC; pricing $\beta$ is secondary |
| Buyer-size gradient as headline ($12.6\times$ extreme-quartile) | Buyer-size gradient as scope information; non-monotonic intermediate quartiles disclosed |
| Architectural claim implicit in §10 only | Architectural claim foregrounded in title, abstract, §1, §12; co-headline with discrimination evidence |

Two further narrowings that v15 already partly executed but v16 finishes:

- The screening-value-vs-treatment-effect distinction is now framed in App A as "one interpretation among several the data do not adjudicate," not as the load-bearing reading.
- The framework's predictions about firm-level bid aggressiveness and bid dispersion are explicitly noted as **not** testable at the data layer, with the caveat that they would become testable in jurisdictions with bid microdata. This is now a portability point in §11 and §10, not an unstated gap.

## V. Remaining vulnerabilities

Six vulnerabilities are documented and not fully addressed by the reframe. The reframe makes them smaller (by reducing the claim base) but does not eliminate them.

1. **Cobidder labels are by construction within-stratum.** The validation positive class is always-loser firms participating alongside direct CADE defendants. Some of the $192$ cobidders may be genuine losers who happened to bid alongside cartel members. The within-stratum bridge (Subprompt 4) shows the population's descriptive profile matches the cover-bidder type on $4/5$ measurable dimensions, but firm-level membership remains unidentified.
2. **Single-jurisdiction empirical universe.** The discrimination evidence is from one electronic procurement platform in one Brazilian state over an eleven-year window. Cross-jurisdictional replication is the natural extension and is flagged as such. The portability claim — that the screening stage is deployable wherever award records are preserved — rests on prerequisites (winner/loser registry, electronic platform, institutional asymmetry) that are checkable ex ante in candidate jurisdictions, but the claim is not yet empirically verified outside BEC.
3. **Rent-component-co-movement assumption (App A, Proposition 4).** The screening-value-as-rationale interpretation of the sign reversal depends on a non-testable premise. The Proposition is now explicitly framed as one interpretation among several. This is honest disclosure, not a fix.
4. **Two operational predictions of the cover-bidder type cannot be tested.** Firm-level bid aggressiveness and bid dispersion are out of reach at the award-record envelope. The bridge stops at $4/5$ rather than $5/5$.
5. **The sign reversal is not eliminated.** The decomposition (Subprompt 3) localizes it as an ATT-reweighting result and shows the broad-sample positive imprint survives the overlap restriction without ATT-weighting at $+0.044$. But the ATT-weighted estimate is still negative; a referee who privileges the ATT-weighted estimate as the relevant treatment-effect target will not be persuaded by the screening-value framing alone.
6. **Direct-defendant AUC is essentially random ($\approx 0.49$).** This is acknowledged transparently as the design's empirical signature (the construct recovers loser-side participation, not winner-side identity), but a referee may read it as a scope limitation that the screening interpretation papers over. The reframe states the asymmetry plainly in the abstract and §1.

The remaining vulnerabilities are real, scoped, and reported. The reframe makes the paper as hard to reject as the existing evidence honestly allows, by leading with what is strongest (discrimination + architectural test), demoting what is fragile (sign-reversal interpretation), and disclosing what cannot be tested (firm-level bid behavior).

## VI. What the reframe changes structurally

| File | Change |
|---|---|
| `sec_frontmatter_v16.tex` | New title (was "Frequent Losers: Screening Cartels Without Bid Microdata"; now "Screening Cartels Under Incomplete Observability: Award-Layer Detection and the Architecture of Enforcement"); abstract rewritten to lead with discrimination AUCs and architectural test, demote pricing $\beta$ to one corroborating sentence |
| `sec_introduction_v16.tex` | Three-question opening (informational / architectural / equilibrium-content); discrimination-led empirical evidence paragraph; explicit non-claims paragraph including the sign-reversal-decomposition disclosure |
| `sec5_emp_v16.tex` | Empirical object reordered: discrimination AUC primary, conditional association secondary; sign reversal explicitly framed as reweighting phenomenon |
| `sec_cade_v16.tex` (Subprompt 4) | New subsection §6.2 "Within-stratum profile of cobidders" carrying the theory-validation bridge |
| `sec_results_v16.tex` (Subprompt 3) | §7.2 retitled "What the Sign Reversal Does and Does Not Tell Us"; three-step decomposition replaces screening-value-as-diagnostic framing; defense explicitly stated as not resting on the sign reversal |
| `sec_conclusion_v16.tex` | Re-anchored on discrimination + architectural separation; pricing as third paragraph, with empirical decomposition explicit |
| `sec_literature_v16.tex` | Already JLEO-coded by prior pass; no changes needed |

Two PDF artifacts confirm the reframe builds clean: `paper_v16editor.pdf` at 52 pages (was 50 after Subprompt 4; +2pp from longer abstract, intro, and conclusion), `paper_v16editor_online_appendix.pdf` at 22 pages (unchanged). No unresolved references, no LaTeX errors above the standard natbib boilerplate.

---

## VII. What the cover letter should now say

> *"This paper offers a screening statistic for cartel-adjacency that operates on award-record data, the data layer that survives in most electronic procurement environments globally. The construct discriminates adjudicated CADE-cobidder firms inside the always-loser stratum at AUC 0.864 under temporal holdout (train 2009–2016, test 2017–2019) and at AUC 0.748 on a strict contemporaneous benchmark restricted to pre-2020 cases. Against bid-distribution detectors that require per-bidder bid amounts, the screening statistic reaches comparable accuracy on a substantially thinner data envelope (AUC 0.903 vs 0.888 on the same target) and adds non-redundant signal in same-sample combination ($+0.035$ AUC, DeLong $p=0.014$). Within the always-loser stratum, the cobidder validation positive class matches the modeled cover-bidder type along four of five operational predictions (Cohen's $d$ up to $+1.00$). The construct also leaves a $+3.6\%$ to $+7.7\%$ conditional log price imprint as descriptive corroboration. The contribution is informational and architectural — an award-layer screening stage that runs ahead of the bid-layer forensic stage the prior literature requires — rather than causal-identification. Failed RDD and DiD designs are reported transparently; the sign reversal under overlap restriction is decomposed empirically as a reweighting phenomenon. The paper does not claim cartel-membership identification, causal effect estimation, or institutional-channel identification."*

JLEO editors recognize this register: identifiability under data constraints, architectural sequencing, equilibrium-grounded statistic, scoped contribution, honest non-claims.

## VIII. Whether the rebuilt paper is now JLEO-shaped

**Yes, on the dimensions the editors recognize.**

- **Central question.** Identifiability under data coarsening is a question that JLEO papers explicitly take up; v16 frames it as the opening problem.
- **Theoretical structure.** A separating-equilibrium framework with cover bidders identifies the participation statistic as the sufficient ranking object. The framework does not have to be original — it has to be *load-bearing*, which it now is (it identifies the primitive, the binary rule's coarsening role, and the equilibrium content of the participation footprint).
- **Architectural claim.** Sequencing of screening and forensic stages is a Becker–Stigler–Baker question; v16 makes the architectural separation an empirical claim with a same-sample test against a thicker-envelope competitor.
- **Disclosure discipline.** Failed designs reported, sign reversal decomposed and demoted, scope limitations stated in §1 and §11.

The remaining JLEO risk is the standard one for empirical IO papers without clean causal identification: a referee who insists on $\beta^{ov}$ as the relevant treatment-effect target and rejects the screening interpretation. The reframe minimizes this risk by anchoring the contribution on AUC + architectural evidence that does not depend on overlap weighting; pillar 5 (pricing) is now corroborative rather than central. If the referee still rejects on the pricing pillar, the discrimination + architectural pillars survive intact.

---

*End of JLEO reframe memo. The paper is now the strongest defensible version of itself the existing evidence permits.*
