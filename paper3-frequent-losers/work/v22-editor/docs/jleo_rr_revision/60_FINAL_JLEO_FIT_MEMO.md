# 60 — FINAL JLEO FIT MEMO

**Paper:** *Cheap Signals, Costly Proof: The Reach and Limits of Award-Layer Screening in Cartel Enforcement* — Genicolo-Martins & de Azevedo (INSPER).
**Stage:** JLEO R&R, branch `v22`. **Mode:** internal, hostile-Referee-2 calibration. **Date:** 2026-06-03.
**Grounding:** sec01 / sec_frontmatter / sec08 (read in full), plus docs 44, 45, 52, 55, 04, 02, 62.

> **Headline verdict: GOOD (not perfect) JLEO fit.** The organizational/division-of-labor contribution is genuinely present and load-bearing in both the introduction and the conclusion — it is not bolted on. But it shares the spotlight with a method contribution (the decomposition) and an empirical reach-map; the "organization of enforcement" framing is the *frame*, while the *deliverable* is an honesty audit of a screen. A skeptical editor can read this as an applied empirical-IO screening paper wearing a JLEO jacket. Submit, but the cover letter must lead with sequencing/division-of-labor, not with the screen.

---

## 1. One-sentence thesis

Cartel enforcement must allocate costly proof-producing effort *before* legal proof exists, so the paper asks how far cheap administrative award records can order forensic priority across investigative layers, and answers with a disciplined map of where that ordering is real signal versus exposure arithmetic, retrospection, and single-case concentration.

## 2. Why JLEO and not IO-only

The object is not "a better cartel screen." It is the **institutional sequencing of an enforcement agency's investigative effort** under costly observability: a cheap, legally thin award layer that ranks *where to look*, and a costly, evidentiary bid layer that decides *what is found*. That is a Law-and-Economics-of-Organization question — how an enforcement institution divides labor between an information-acquisition stage and a proof-production stage, and how it should sequence them under a budget. A pure IO journal would care about the AUC; JLEO should care about the gatekeeping architecture and the legal boundary on what each layer is allowed to conclude. The paper's own framing (sec01 ¶1 "the allocation of proof-producing effort"; sec08 "the contribution is not to collapse these layers, but to sequence them") is squarely organizational.

**Honest caveat:** the paper does not *model* the agency as an organization (no principal-agent, no formal sequencing-game solved in equilibrium beyond the App-B exit-margin sketch). The organizational content is conceptual/architectural, not a structural organizational-economics model. JLEO publishes both; this is the lighter, applied-institutional end.

## 3. Law dimension

- **CADE adjudications as external legal anchors.** Validation is tied to firms that bid alongside *adjudicated* (legally proven) cartel defendants — the label is "adjudication-anchored exposure," explicitly *not* membership (sec01 ¶5; G2 in doc 55).
- **Evidentiary staging.** The paper is built around the distinction between a screen (forensic priority) and proof (liability), and is disciplined that "liability remains in the richer bid-level record" (abstract; sec08). This is the law-and-economics-of-evidence core.
- **Brazilian procurement law.** BEC modalities (Convite/Pregão), the institutional visibility of award vs bid records, and the regulatory-deployment discussion (gaming, refreshed thresholds, bunching, top-k queues) connect the statistic to real enforcement governance.

Strength: **medium-high.** The legal-scope discipline is real and consistent. Weakness: the legal analysis is institutional/descriptive, not doctrinal — no deep engagement with Brazilian antitrust statute or evidentiary standards beyond the screen/proof boundary.

## 4. Economics dimension

- **Screening / detection theory:** positioned against the bid-distribution screening literature (Porter-Zona, Bajari-Ye, Abrantes-Metz, Harrington, Imhof, Wallimann, Chassang) as a *prior-stage* exercise.
- **IO / auctions:** loser-side participation, cover-bidding logic, role allocation (Pesendorfer, Asker, Kawai), procurement modalities.
- **Information economics:** costly observability, cheap-vs-costly signal acquisition, the cost-recall frontier as a budget-constrained acquisition problem.

Strength: **high** on positioning, **medium** on novelty of the economic primitives (the modeling is light; the contribution is empirical-institutional).

## 5. Organization dimension — THE PIVOT (assessed from sec01 + sec08)

This is where JLEO fit is won or lost, so I assess it directly against the actual prose.

**Present and central:**
- sec01 ¶6 ("A complementary result concerns the **division of labor between the two layers** … the layers enter at different stages: award records prioritize where to look, and bid records evaluate what is found") — this is a genuine sequencing/division-of-labor claim, supported by the bid-benchmark complementarity (Table 5) and the cost-recall frontier (Table 6).
- sec01 ¶ contribution-1 reframes the whole exercise as "evidence allocation under costly observability … turning screening toward enforcement triage."
- sec08 ¶3 ("The contribution is not to collapse these layers, but to **sequence** them") and ¶5 ("sequential gatekeeping is the architecture relevant once an agency knows where the cheap layer ranks and where it does not").

**Verdict on centrality:** The organizational contribution is **genuinely central, not decorative** — it survives if you delete the AUC numbers, because the deliverable ("here is the architecture and its reach") stands on the sequencing logic. This clears the bar I was told to enforce: I can call it a good JLEO fit *because* division-of-labor is load-bearing.

**Honest limit:** the organizational result is *one* of three contributions and is the most affirmative one, but the empirical spine of the paper (the decomposition, §4) is a *screening-validity audit*, which reads as IO. The risk is that a referee weighs the paper by its biggest empirical section (§4, decomposition) rather than by its frame (sequencing). Mitigation already in place: §6 (benchmark + frontier) is the affirmative organizational payoff and is given real estate.

## 6. Institutional contribution

A concrete map of **what an enforcement institution can and cannot delegate to a cheap administrative layer**: it can order forensic priority *within* a loser-side, incumbent, retrospective boundary; it cannot substitute for bid-layer proof, cannot rank new entrants, and cannot detect win-side defendants. The "reach and limits" map is itself the institutional product — knowing where a triage rule stops is part of disciplined enforcement (sec08 closing). This is a usable governance result for procurement regulators.

## 7. Methodological contribution

The **decomposition** of a pooled screening metric into (i) genuine ranking signal, (ii) mechanical opportunity/exposure arithmetic, (iii) retrospective vs prospective information, and (iv) single-case concentration — using opportunity-cell adjustment, strict rolling-origin timing, and leave-one-case-out. This is transferable to *any* validation-against-anchors screening study and is the most defensible "new" thing in the paper. It is honest precisely because it is built to subtract the paper's own apparent success (0.946 pooled → 0.7715 within-stratum).

## 8. What the paper does NOT claim (and must keep not claiming)

- Not a cartel detector; not proof; not membership identification.
- Not damages / overcharge / causal price effect (price is scope-only; mechanism *not identified* — script 78).
- Not prospective causal deployment (timing concentration test FAILS; deployment vs sincere persistence observationally equivalent — script 77).
- Not a calibrated optimum (cost-recall is a frontier, not an optimal cutoff).
- Not dominance over bid screens ("complementary," "comparable at lower cost," never "outperforms").

## 9. Most likely DESK-rejection concern

**"This is an applied empirical-IO cartel-screening paper; the organizational/L&E-of-Organization content is a framing layer over a screen-validation exercise — wrong journal."** An editor skimming abstract + intro could file it under IO field-journal (IJIO/JLE-empirical) rather than JLEO.

## 10. How addressed

- Abstract and intro lead with **enforcement organization / evidence allocation**, not with the screen or any AUC (no raw pooled AUC in abstract or cover letter — doc 62).
- §6 (division of labor: benchmark complementarity + cost-recall frontier) is a full, affirmative organizational section, not an afterthought.
- sec08 frames the deliverable as *sequencing architecture* + *reach map*, the JLEO-native objects.
- **Residual desk risk: MEDIUM.** Cannot be fully neutralized — the empirical center of gravity (§4 decomposition) is screening-validation. Cover letter must explicitly tell the editor this is about *how an agency sequences investigative layers*, citing the division-of-labor and reach-map contributions, so the desk read is organizational, not IO.

## 11. Most likely referee concern

**"Most of your measured power is opportunity exposure (0.946 alone) and one case; the residual within-stratum signal is +0.04 and your own timing test fails — what is left to publish?"** (R1/R2/R3 in doc 44; the two genuine Highs.)

## 12. How addressed

- This *is* the thesis, not a buried weakness: the paper sells the **decomposition and the reach map** as the contribution, so a small, bounded, honestly-located residual is a *finding*, not a failure (sec01 ¶ contribution-2/3; sec08 ¶3).
- The affirmative payoff is moved to the **division-of-labor** result (§6: award score adds non-redundant info beyond the Imhof benchmark; cost-recall frontier beats random 3–12×), which does not depend on the +0.04 being large.
- Honesty ledger (doc 02) keeps the magnitude claims disciplined: "+0.04 over exposure-only, p<0.001," never "0.92 is exposure-free."
- **Residual referee risk: HIGH but on-thesis.** A hostile referee can still say "the affirmative content is thin." The defense is that *mapping the limit is the product* — persuasive at JLEO (institutional design) in a way it would not be at a pure-IO venue.

## 13. Recommendation

**SUBMIT — conditional on (a) the double-spaced/1.25in build (doc 55 D1/D2) and (b) a cover letter that leads with the sequencing/division-of-labor contribution so the desk read is organizational.** The organizational contribution is real and central enough to justify JLEO; the honest empirical thinness is reframed as the paper's own thesis. Do not oversell §4; lead institutional, deliver the decomposition as method, and let §6 carry the affirmative weight. Fit is good, not perfect — the empirical spine reads IO and that is an unremovable residual, managed not eliminated.
