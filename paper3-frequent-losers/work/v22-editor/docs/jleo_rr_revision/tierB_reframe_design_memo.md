# Tier B Reframe — Design Memo (Two Analytical Objects)

**Author:** Mr. Frequent Losers (co-author / theorist mode)
**Date:** 2026-06-06
**Status:** DESIGN ONLY. No manuscript file is edited from this memo. This memo gates the reframe; the writing agents execute it after Darcio signs off.
**Purpose:** Convert the paper from "honest null + checklist" into a positive law-and-economics contribution by designing two analytical objects that **organize the existing evidence** rather than add new claims. Both objects must be consistent with every locked number; neither may contradict the deflation result.

---

## 0. THE PROBLEM, RESTATED IN ONE PARAGRAPH

Two hostile referees rejected on the same ground. The organizational contribution (C1) is **named** ("the object an enforcement designer chooses is the cost–recall frontier") but never **modeled**: the frontier is a descriptive scatter, the K1=2000 operating point is explicitly disowned ("one operating point, not a calibrated optimum"), and the audit protocol reads as an obvious checklist. R4's "so what" is precise: the paper says "adjust for exposure or you over-credit" as a *caveat* and "the frontier is the object" as an *assertion*, with no object behind either sentence. The fix is **not** new empirics. It is to write down the two latent objects the data already trace, so that (i) the frontier becomes the empirical image of a solved enforcer optimal-stopping problem, and (ii) the raw-AUC inflation becomes a characterized, estimable bias with a sufficient statistic. The constraint is absolute: the model must *rationalize* the deflation and the frontier, never reverse them.

---

## OBJECT 1 — THE ENFORCER'S EVIDENCE-ACQUISITION PROBLEM

### 1.1 What it is and what it must do

A minimal optimal-stopping model of how deep an enforcement agency should descend a cheap ranking before it stops opening costly bid-level records. The model's single job is to make **the cost–recall frontier of §7 the empirical image of a solved problem**, so that the sentence "there is no optimal cutoff" upgrades from a confession to a *result*: the optimum is a budget-dependent point ON the frontier, and the frontier is the locus of those optima as the budget varies. K1 stops being an embarrassing arbitrary choice and becomes "the tangency we would recover at a given B/c."

This is the JLEO institutional object the referees demanded. It is deliberately **reduced-form on payoffs** — it does not re-derive the cartel's internal organization (that is the existing Karlin-Rubin ranking appendix), and it does not claim to estimate a structural recovery technology. It is the enforcement-economics counterpart to the ranking result already in `sec_app01`.

### 1.2 Primitives (six, all reduced-form)

1. **A ranking.** The award-layer score induces an ordering of the $N$ always-loser candidate firms, $i=1,\dots,N$, by exposure-loaded loss intensity. Write $\rho(k)$ for the **marginal recovery density** at depth $k$: the expected number of adjudicable cases recovered by opening the $k$-th firm on the ranked list (equivalently the slope of the recall curve). This is an *object the data give us* — it is the discrete derivative of the recall curve in Table 7 / Fig. 3.
2. **A per-firm forensic cost** $c>0$: the expected cost of recovering, cleaning, and inspecting one survivor's bid-level record (LANCES history). In the paper's accounting this is naturally indexed to **bid rows**, not firms, which is exactly why the firm-vs-bid-row asymmetry (§1.5) is a feature of the cost side, not a nuisance.
3. **A budget** $B$ (or, dually, a shadow price of forensic capacity). Either a hard cap on total recovery cost or a Lagrange multiplier $\mu$ on the capacity constraint.
4. **A recovery payoff** $V>0$ per adjudicable case surfaced (the social value of routing a true case to the proof-producing stage). Only the ratio $c/V$ (or $\mu/V$) will matter, so the model carries one effective primitive.
5. **A monotone-decreasing marginal-recovery schedule** $\rho(k)$, decreasing in $k$ because the ranking is informative: high-exposure firms are opened first, so each successive firm yields weakly fewer expected recoveries. This is the *only* substantive behavioral assumption, and it is **exactly the ranking property the Karlin-Rubin proposition already delivers** (the posterior is non-decreasing in the score ⇒ the recovery density is non-increasing in rank). Object 1 inherits this; it does not re-assume it.
6. **The bid layer as the evaluation stage** (not a primitive choice variable): opened records are evaluated by the costly forensic stage. The model stops at "open or not"; what happens after opening (liability) is outside the object, consistent with the Corollary's legal-scope boundary.

### 1.3 Objective and the proposition

The agency chooses stopping depth $K$ to maximize net recovery:
$$
\max_{K}\; \Pi(K) \;=\; V\!\int_0^{K}\!\rho(k)\,dk \;-\; c\,\Phi(K),
$$
where $\Phi(K)$ is the cumulative forensic cost of opening the top-$K$ firms (cumulative **bid rows**, not firms — this is where the §1.5 denominator enters). Under a budget cap the constraint is $\Phi(K)\le B$.

**Proposition 1 (Optimal stopping depth / trigger condition).**
*If the marginal-recovery density $\rho(k)$ is non-increasing in rank (inherited from the Karlin–Rubin ranking) and the marginal forensic cost $\phi(k)=\Phi'(k)>0$ is non-decreasing, then the unconstrained optimum $K^\*$ is the unique tangency*
$$
V\,\rho(K^\*) \;=\; c\,\phi(K^\*)
\qquad\Longleftrightarrow\qquad
\frac{\rho(K^\*)}{\phi(K^\*)} \;=\; \frac{c}{V},
$$
*i.e. the agency descends the ranking until the marginal case recovered per unit forensic cost falls to the cost–value ratio $c/V$. Under a binding budget the optimum is the largest $K$ with $\Phi(K)\le B$, and the locus $\{(\Phi(K^\*(c/V)),\,\text{recall}(K^\*(c/V)))\}_{c/V>0}$ traces exactly the cost–recall frontier.*

**Proof sketch (clean, one paragraph).** $\Pi$ is the difference of a concave benefit (integral of a non-increasing density) and a convex cost (integral of a non-decreasing marginal cost), so $\Pi$ is concave and the first-order condition $V\rho(K)=c\phi(K)$ is necessary and sufficient. Monotone comparative statics: $K^\*$ is non-increasing in $c/V$ (cheaper or more valuable forensics ⇒ open more). Sweeping $c/V$ over $(0,\infty)$ and reading off $(\text{cost},\text{recall})$ at each $K^\*$ generates the frontier; the budget-constrained problem hits the same locus from the constraint side (the multiplier $\mu$ plays the role of $c$). $\square$

The concavity claim is the one place to be careful: the *empirical* recall curve in Table 7 is **non-monotone in K1** (108→124→116→115→102 TP at k=500). See §1.7 — this is reconciled, not papered over.

### 1.4 How it maps to §7's frontier and K1

- **Frontier = solution locus.** Each point in Fig. 3 / Table 7 is $(\Phi(K_1),\text{recall}(K_1))$. Proposition 1 says these are the optima of the same objective at different $c/V$. The frontier is therefore not "a descriptive plot with the optimization removed" — it IS the value function's argmax locus.
- **K1 = a tangency, not a guess.** "$K_1=2{,}000$ is one operating point, not a calibrated optimum" becomes: "$K_1=2{,}000$ is the optimum for an agency with cost–value ratio $c/V$ in the implied range; agencies with cheaper forensics sit deeper, those with dearer forensics shallower. We do not calibrate $c/V$ because we do not observe agency budgets, so we report the whole frontier — the menu of optima — rather than impose one." This is the single highest-leverage sentence in the reframe.
- **The 88%-firms-vs-33%-bid-rows asymmetry becomes the engine.** Because $\Phi$ is measured in bid rows and survivors are the highest-participation firms, $\phi(k)$ is **steeply increasing early** (the first firms opened are the most bid-row-expensive). The model predicts that the firm-denominator frontier and the bid-row-denominator frontier diverge sharply — exactly the divergence the paper already reports. The asymmetry stops being an awkward caveat and becomes the comparative-statics signature of the cost technology.

### 1.5 Exact claims the writing agent MUST make

- The cost–recall frontier is the empirical image of a stopping rule: the agency opens firms down the cheap ranking until marginal recovery per forensic cost equals $c/V$ (Proposition 1).
- There is no single optimal cutoff *because the optimum is budget-dependent*; the frontier is the locus of budget-dependent optima, and reporting it (not a point) is the correct response to unobserved agency budgets.
- The firm-vs-bid-row asymmetry is the model's cost-side comparative static: survivors are high-volume, so marginal forensic cost rises fastest where recovery is richest.
- The model inherits its one behavioral assumption (decreasing marginal recovery) from the Karlin–Rubin ranking already proved in `sec_app01`; it adds the cost side and the stopping rule.

### 1.6 Exact claims the writing agent must NOT make

- **NOT** that the model identifies cartels, conduct, or that opened firms are "likelier to have coordinated." The stopping rule operates on *recovery of adjudicable exposure*, and §4 forecloses a conduct reading. The objective's "recovery" is recovery of the adjudication-anchored target, full stop.
- **NOT** that $c/V$ is estimated or calibrated. It is a free institutional primitive; the frontier is reported precisely because it is unobserved.
- **NOT** that the stopping rule "beats full information." Proposition 1's optimum is bounded above by the joint full-observability upper bound (133 TP at k=500); the model must state $\Pi(K)\le \Pi^{\text{full-obs}}$.
- **NOT** that the within-stratum residual matters here. Object 1 runs on the *raw* exposure ranking; it is an evidence-allocation/recovery-footprint object, and §4 has already established it carries no conduct residual. The honest framing (already in §7): "the frontier prices the recovery footprint of an exposure-ranking architecture, never evidence that the score identifies active conduct." Object 1 must preserve that sentence verbatim in spirit.

### 1.7 The non-monotone-recall reconciliation (do not skip)

The empirical sequential recall is non-monotone in $K_1$ (124 TP at $K_1{=}1000$ > 116 at $K_1{=}2000$ for $k{=}500$). A naive reading says "then $\rho$ is not monotone and Proposition 1 is false." It is not false — three reasons, and the memo commits to stating reason (a) in the text:

(a) **The sequential object in §7 is award→bid rerank, not pure award-ranking descent.** The non-monotonicity is a property of the *two-stage* rule (a larger survivor pool dilutes the bid rerank's precision at fixed $k$), NOT of the underlying award marginal-recovery density. Object 1 is stated on the **award-ranking recall curve** (the "award-only / zero-bid-cost" object), which IS the clean monotone primitive. The writing agent must anchor Proposition 1 to the award-recall curve, and treat the sequential rerank's non-monotonicity as a *second-order* effect of the rerank stage, explicitly noted.
(b) Sampling noise at small TP counts (single-case dominance, §9 of CONSOLIDATED) makes the 124-vs-116 gap fragile; the frontier's *shape* (concave envelope) is what Proposition 1 predicts, not every point's exact height.
(c) Proposition 1's concavity is on **expected** recovery; the realized counts are one draw.

**Risk verdict on this point (honest):** stating Proposition 1 on the award-recall curve is clean and defensible. Stating it on the sequential award→bid curve would be theory-theater (the curve is non-monotone there). The writing agent MUST anchor to the award curve and footnote the rerank caveat. This is non-negotiable.

### 1.8 Where Object 1 lives

- **New main-text subsection**, ~0.75–1.0pp, opening §7 (before the current §7.2 frontier subsection) OR as a short §7.0 "The evidence-allocation problem." It states primitives 1–6 in prose, Proposition 1 as a displayed FOC with a two-line proof, and the three mapping bullets (§1.4). It does NOT introduce new floats.
- **Framework-appendix extension** in `sec_app01_framework_submission.tex`: a new subsection `\subsection{The evidence-acquisition stopping rule}` after `app:framework_scope`, giving the full statement and proof of Proposition 1, the concavity argument, and the explicit link "the recovery density $\rho$ is non-increasing by Proposition~\ref{prop:submission_monotone}." This is the natural home: the existing appendix already proves the ranking; Object 1 adds the decision layer on top of it. ~0.5pp.
- **Intro contribution paragraph (C1)** rewritten to name the stopping rule as the organizational object (see §4 writing plan).

---

## OBJECT 2 — THE OVER-CREDITING BIAS AS AN ESTIMABLE OBJECT

### 2.1 What it is and what it must do

A characterization of **why raw award-screen AUC inflates**, turning the paper's central caveat ("adjust for exposure or you over-credit") into a *law*: the inflation $\Delta = \text{AUC}_{\text{raw}} - \text{AUC}_{\text{opp-adj}}$ is an increasing function of (a) the dispersion of participation volume across firms and (b) the adjudicated base rate, with a transparent **sufficient statistic** practitioners can compute. The BEC ($0.761\to\approx$chance within-stratum; label-blind exposure $E$ AUC $0.553$) and federal ($0.744$ raw, exposure-only $0.754$, within $0.462$, label-blind $E$ $0.611$) numbers then become **two points on one inflation curve at different volume-dispersion / base-rate coordinates**, not "the same null twice." This is R4's highest-leverage requested change.

### 2.2 The mechanism, stated cleanly

The label is **contact-defined**: a cobidder is an always-loser that shares ≥1 tender-item with a defendant. Probability of contact is mechanically increasing in participation volume $T_i$:
$$
\Pr(\text{cobidder}_i = 1 \mid T_i) \;\approx\; 1 - (1-\pi)^{T_i} \;\approx\; \pi T_i \quad (\pi T_i \text{ small}),
$$
where $\pi$ is the per-tender-item defendant-contact rate (the $p_g$ density of §4, the "expected contact $E_i$" object). The award score is monotone in $T_i$ by construction ($\log(1+T_i)$). **So the raw score and the label are both functions of $T_i$** — the score ranks the label not because loss intensity is behaviorally informative but because both load on volume. That is the entire over-crediting mechanism, and it is *exactly* what the within-stratum null and the label-blind $E$ AUC already demonstrate empirically.

### 2.3 The characterization — analytic core (tractable) + simulation (honest fallback)

**Analytic skeleton (clean, belongs in the appendix).** AUC = $\Pr(\text{score}_i > \text{score}_j \mid y_i=1, y_j=0)$ for a random positive $i$ and negative $j$. With score monotone in $T$ and $\Pr(y=1\mid T)=\pi T$ (rare-target linearization), the positive class is the **size-biased** distribution of $T$ (weighted by $\pi T$) and the negative class is approximately the raw distribution of $T$. Then:
$$
\text{AUC}_{\text{raw}} \;=\; \Pr(T_i > T_j),\quad T_i\sim \text{size-biased}(F_T),\; T_j\sim F_T .
$$
This is a classic size-bias gap. Two clean comparative statics fall out:

- **(a) Volume dispersion.** The size-biased/raw stochastic gap $\Pr(T_i>T_j)-\tfrac12$ is increasing in the dispersion of $F_T$. For a concrete, citable handle: if $T\sim$ Gamma (a natural fit for participation counts, and the Poisson-mixing already used in `sec_app01`), $\text{AUC}_{\text{raw}}$ is increasing in the coefficient of variation $\text{CV}(T)$; in the limit of degenerate $T$ (no dispersion), $\text{AUC}_{\text{raw}}\to 0.5$ (no inflation — there is nothing to rank). **Sufficient statistic: $\text{CV}(T)$ among the candidate pool** (or the size-bias gap $\mathbb{E}[T^2]/(\mathbb{E}[T])^2 - 1 = \text{CV}^2$).
- **(b) Base rate.** The linearization $\Pr(y=1\mid T)\approx \pi T$ holds when $\pi T$ is small (rare target). As the base rate rises, the size-biasing saturates ($1-(1-\pi)^T$ flattens), the positive class stops being as strongly size-biased, and $\text{AUC}_{\text{raw}}$ **declines toward** the within-stratum (genuine-signal) value. So lower base rate ⇒ MORE inflation. The federal platform has a ~10× lower base rate (195/~92K ≈ 0.2% vs BEC 651/16,843 ≈ 3.9% on the AL pool; or the PR base rates 0.014 vs 0.143), so the federal raw AUC sits where the curve predicts for a rarer target with comparable volume dispersion.

**The inflation law (the deliverable claim):**
$$
\Delta \;=\; \text{AUC}_{\text{raw}} - \text{AUC}_{\text{opp-adj}} \;=\; g\big(\text{CV}(T),\, \text{base rate}\big),
\quad \partial_g/\partial\text{CV} > 0,\;\; \partial_g/\partial(\text{base rate}) < 0,
$$
where $\text{AUC}_{\text{opp-adj}}$ is the within-opportunity-stratum / label-blind value (the genuine-signal floor). The sufficient statistic a practitioner computes **before opening any bid file** is the candidate pool's $\text{CV}(T)$ and the target base rate; together they bound how much of any raw AUC is mechanical.

### 2.4 Why the analytic claim must be backed by a transparent simulation (honest risk call)

The analytic FOC is clean for the *monotone* comparative-static SIGNS, but the *magnitude* function $g(\cdot)$ is not closed-form once you (i) move off the rare-target linearization, (ii) use the actual empirical $F_T$ (heavy-tailed, not exactly Gamma), and (iii) account for the opportunity adjustment being multi-cell rather than a single $\pi$. **I am a skeptic about claiming a closed-form $g$.** Recommended honest version:

> State the two comparative-static signs as a **Proposition** (size-bias monotone in CV; inflation monotone-decreasing in base rate, both provable in the linearized rare-target regime), and **demonstrate the magnitude with a transparent simulation** over a parameter grid built from EXISTING quantities — no new confidential-data analysis.

**Simulation spec (executable, uses only already-known quantities):**
- Draw $T_i$ from a family indexed by CV (Gamma or empirical-resampled from the BEC always-loser $T$ distribution, which is on disk). Grid CV over a range bracketing BEC and federal.
- Generate labels $y_i \sim \text{Bernoulli}(\min(\pi T_i,1))$; grid $\pi$ to sweep base rate over a range bracketing 0.2%–4%.
- Add a *genuine* within-stratum signal of known strength $\theta$ (AUC contribution net of volume) — set $\theta=0$ for the pure-null curve and small $\theta$ for the powered curves, reusing the EXISTING power-calibration machinery (the permutation_power_curve already injects synthetic within-stratum signal; this is the same device).
- Compute raw AUC and within-stratum AUC at each grid point; plot $\Delta$ vs CV and vs base rate.
- **Overlay the two real data points** (BEC: CV of $T$ among 16,843 AL, base rate, $\Delta = 0.761-\approx0.50$; federal: CV among 35,943 AL, base rate, $\Delta = 0.744-0.462$) and show they land on the predicted surface.

This simulation is cheap (single-process, in-memory, no confidential microdata — just the $T$ distribution and base rates already published), reproducible, and it is the honest way to claim a "law" without overclaiming a closed form. It reuses the power-calibration injection device already in the paper, so it is not a new method.

### 2.5 BEC + federal as two points on the curve (the consistency story)

| Quantity | BEC | Federal | Predicted relation |
|---|---|---|---|
| Raw AUC | 0.761 | 0.744 | comparable (similar volume dispersion) |
| Base rate (AL-pool) | ~3.9% | ~0.2% | federal ~10× rarer |
| Within-stratum (genuine floor) | ≈chance (0.471) | ≈chance (0.462) | both at floor |
| Label-blind exposure $E$ AUC | 0.553 | 0.611 | both modest; federal slightly higher |
| Inflation $\Delta$ (raw − within) | ~0.29 | ~0.28 | comparable |
| Exposure-only AUC | 0.713 | 0.754 | federal exposure-only ≥ raw |

**The story the writing agent tells:** federal is rarer (lower base rate) and its exposure-only model *edges out* the raw score ($0.754 > 0.744$), i.e. the inflation is, if anything, MORE complete federally — exactly the direction Object 2 predicts for a lower base rate. The within-stratum floor is ≈chance on both. The ComprasNet replication is therefore **not "the same null twice"**: it is a second coordinate $(\text{CV}_{\text{fed}}, \text{base rate}_{\text{fed}})$ that lands on the predicted inflation surface, with the lower base rate pushing exposure-only past raw. This is the positive, generalizing content R4 wanted.

### 2.6 Exact claims the writing agent MUST make

- The raw award-screen AUC inflates because score and contact-defined label are both monotone in participation volume; the positive class is the size-biased volume distribution.
- The inflation is increasing in participation-volume dispersion (sufficient statistic: CV of $T$) and decreasing in the adjudicated base rate (Proposition + simulation).
- A practitioner can compute the sufficient statistic from award data alone, *before* opening any bid file, to bound how much of a raw AUC is mechanical.
- BEC and federal are two points on this inflation surface; the lower federal base rate is why exposure-only edges out the raw score federally.

### 2.7 Exact claims the writing agent must NOT make

- **NOT** a closed-form $g(\cdot)$ for the inflation magnitude. Claim the SIGNS analytically; demonstrate MAGNITUDE by simulation. Do not write "$\Delta = $ [formula]."
- **NOT** that the correction "recovers" a deployable signal. The correction reveals the genuine floor is ≈chance here; it does not rescue the screen. The sufficient statistic is a *diagnostic*, not a fix that makes FL usable.
- **NOT** that federal is an independent ground truth (the 7 cases overlap BEC's; CONSOLIDATED §6 limitation 1). It tests portability of the *audit/inflation law*, not an independent cartel test.
- **NOT** that the simulation uses confidential microdata. It uses only the published $T$ distribution shape and base rates; say so.
- **NOT** that the within-stratum ≈chance result is "fully powered" federally. It is power-bounded (≤0.55 unadjudicated at N+=195; CONSOLIDATED §6 limitation 2). The inflation law is the part that "replicates at full power" (the first-stage deflation, label-blind $E$); the residual floor is power-bounded. The writing agent must keep these separate.

### 2.8 Where Object 2 lives

- **New main-text content folded into §4.2** (`sec04_validation_submission.tex`, the "Opportunity-Adjusted Validation" subsection): 1 short paragraph stating the inflation mechanism (score and label both load on $T$ ⇒ size-bias) and naming the sufficient statistic (CV of $T$). This *replaces* the current bare assertion "any contact-derived benchmark … is mechanically entangled with participation volume" with the actual characterization. ~0.3pp, no new float in main text.
- **Framework / methods appendix**: the Proposition (two signs) + proof in the rare-target regime, and the simulation figure. Natural home is a new subsection in the validation-audits appendix (`sec_app...validation_audits`) OR a short addendum to `sec_app01`. One new appendix figure (the inflation surface with BEC + federal overlaid). ~0.75pp + 1 figure.
- **Comparative section** (`sec_comparative_submission.tex`): reframe the federal verdict paragraph from "same null twice" to "second point on the inflation curve; lower base rate ⇒ exposure-only edges out raw." ~0.2pp edit.
- **Intro C2 contribution paragraph**: "validating an administrative screen against adjudicated cases without adjusting for procurement opportunity systematically over-credits it" upgraded to "…over-credits it by an amount that grows with participation-volume dispersion and shrinks with the base rate — a bias we characterize and give a sufficient statistic for." ~0.1pp.

---

## CONSISTENCY LEDGER (vs every locked number)

Each row confirms the design does not contradict the locked evidence. Sources: `CONSOLIDATED_RESULTS_FEDERAL.md`, `NEW_NUMBERS_MAP_COMPRASNET.md`, the four read .tex files.

| Locked quantity | Value | Object 1 | Object 2 | Consistent? |
|---|---|---|---|---|
| Canonical target (broad AL cobidders) | 651 BEC / 195 fed | recovery target; unchanged | label being inflated; unchanged | ✅ both treat 651/195 as the recovery/label target, never redefine it |
| Raw award AUC | 0.761 BEC / 0.744 fed | the ranking $\rho$ descends | the inflated number to be explained | ✅ |
| Within-stratum residual | 0.471 BEC / 0.462 fed (≈chance) | NOT used (Object 1 runs on raw ranking, explicitly an exposure-footprint object) | the genuine floor $\text{AUC}_{\text{opp-adj}}$ | ✅ Object 1 must NOT claim conduct; Object 2 names this as the floor |
| Label-blind exposure $E$ AUC | 0.553 BEC / 0.611 fed | — | a point on the inflation story (genuine opportunity ranking is modest) | ✅ |
| Exposure-only AUC | 0.713 BEC / 0.754 fed | — | federal exp-only > raw is the lower-base-rate prediction | ✅ the design USES this asymmetry as evidence |
| Nested DeLong increment | +0.010 p=0.013 BEC / +0.005 p=0.191 fed | — | residual is marginal/null; Object 2 says the genuine floor is ~chance | ✅ Object 2 does not claim a residual exists |
| Cost–recall frontier (Table 7) | 108/124/116/115/102 TP @k=500 | the solution locus; non-monotonicity handled in §1.7 | — | ⚠ see flag below |
| K1=2000 operating point | 12% firms / 67% bid rows | becomes a tangency at implied c/V | — | ✅ this is the central upgrade |
| 88%-firm-vs-33%-bid-row asymmetry | $\Delta$Firm 0.88 / $\Delta$Bid 0.33 @ K1=2000 | cost-side comparative static (φ steep early) | — | ✅ becomes the model's signature |
| Joint full-obs upper bound | 133 TP @k=500 | $\Pi(K)\le\Pi^{\text{full-obs}}$ ceiling | — | ✅ model must state the ceiling |
| Power bound (within ≤0.55 unadjudicated fed) | det.prob 0.35@0.55 fed | — | inflation law replicates at full power; residual floor power-bounded | ✅ kept separate (§2.7) |
| Federal base rate ~10× lower | 0.014 vs 0.143 PR-AUC | — | drives exp-only > raw federally | ✅ the load-bearing fact |
| Negative controls (placebo/HV-winner NS) | p=0.258/0.582 fed | — | confirms raw AUC is generic volume geometry = the size-bias mechanism | ✅ Object 2's mechanism IS "generic volume geometry" |

### Flags / tensions (one real, two minor)

1. **REAL (§1.7): the sequential recall curve is non-monotone in K1.** Proposition 1's concavity holds on the AWARD-recall curve, not the award→bid sequential curve. **Resolution: anchor Object 1 to the award-recall curve; footnote the sequential rerank's dilution effect.** If the writing agent anchors Proposition 1 to the sequential curve, it is theory-theater and will be caught. This is the single design constraint that, if violated, sinks Object 1.
2. **Minor: $c$ indexed to bid rows vs firms.** The model's $\Phi$ must be the bid-row cumulative cost for the asymmetry result to work. The text already reports bid-row counts in Table 7, so this is available; the writing agent must use bid-row $\Phi$, not firm-count $\Phi$.
3. **Minor: base-rate definition.** Object 2's "base rate" should be stated as the AL-pool positive rate (651/16,843 ≈ 3.9% BEC; 195/35,943 ≈ 0.5% fed) for the within-pool AUC story, OR the PR base rate — pick one and be consistent. The ~10× claim holds under both framings (PR 0.014/0.143; pool 0.5%/3.9%). Recommend AL-pool rate (cleaner mapping to the size-bias linearization).

**No tension with the deflation thesis.** Both objects *rationalize* the deflation: Object 1 prices the recovery footprint of an exposure ranking that §4 has shown carries no conduct residual; Object 2 explains *why* the raw number was high in the first place. Neither resurrects a conduct claim.

---

## VERIFIED LITERATURE ANCHORS

All four verified this session (WebSearch). Add to `references.bib` (note `becker1968crime`, `stigler1970optimum`, `chassang2022robust`, `harrington2008detecting`, `sanchezgraells2019screening` ALREADY present).

| Key (proposed) | Citation | Verified | Use |
|---|---|---|---|
| `polinsky2000economic` | Polinsky, A. Mitchell and Steven Shavell (2000), "The Economic Theory of Public Enforcement of Law," *Journal of Economic Literature* 38(1): 45–76. | ✅ (title is "Economic **Theory** of Public Enforcement," NOT "Economics of") | Object 1 anchor: enforcement as costly instrument whose intensity is chosen optimally — the survey our stopping rule specializes |
| `mookherjee1989optimal` | Mookherjee, Dilip and Ivan Png (1989), "Optimal Auditing, Insurance, and Redistribution," *Quarterly Journal of Economics* 104(2): 399–415. | ✅ | Object 1 anchor: optimal-audit / when to verify costly soft information; closest formal cousin to "how deep to open records" |
| `townsend1979optimal` | Townsend, Robert M. (1979), "Optimal Contracts and Competitive Markets with Costly State Verification," *Journal of Economic Theory* 21(2): 265–293. | ✅ (canonical vol. **21**, per MIT/RePEc/JET header; one secondary source misprints "33" — use 21) | Object 1 anchor: costly-state-verification — the agency pays $c$ to verify the bid-level state; our $c$ is a CSV cost |
| (existing) `becker1968crime` | Becker (1968), JPE 76(2):169–217. | ✅ already in bib | Object 1: the optimal-enforcement tradition the margin sits one step before |

**Anchoring sentence for Object 1 (writing agent may adapt):** "The optimal-enforcement tradition treats detection and sanctions as costly instruments chosen to maximize net deterrence \citep{becker1968crime,polinsky2000economic}; the audit literature studies when a principal pays to verify soft information \citep{townsend1979optimal,mookherjee1989optimal}. We specialize that logic to a sequential evidence-acquisition margin: how deep an agency descends a cheap ranking before paying the costly-state-verification price of opening bid-level records."

**Do NOT** cite these as having solved *this* problem — they are the tradition we specialize, not prior art on procurement-screen stopping rules. The novelty claim ("sequencing of these audit steps for the award-to-bid decision is, to our knowledge, new") stays.

---

## RISK ASSESSMENT (skeptical, per object)

### Object 1 — TRACTABLE and HONEST, with one hard constraint
- **Tractability: HIGH.** A concave-benefit/convex-cost stopping problem with a one-line FOC. The only non-trivial input ($\rho$ non-increasing) is *already proved* in the existing Karlin-Rubin appendix. This is genuinely minimal — exactly the "clean institutional object" JLEO wants, not a structural IO model.
- **Honesty risk: the non-monotone sequential curve (§1.7).** If anchored to the sequential award→bid curve, the concavity claim is false and it is theory-theater. **Mitigation (mandatory): anchor Proposition 1 to the award-recall curve; footnote the rerank.** With that, it is honest. Verdict: **SHIP, with the §1.7 anchoring constraint enforced.**
- **Theory-theater check:** Is the model doing work or just relabeling the plot? It is doing work: it converts "no optimal cutoff" (a weakness) into "the optimum is budget-dependent, so we report the locus" (a result), and it predicts the firm-vs-bid-row asymmetry as a comparative static. That is genuine organization of existing evidence, not decoration.

### Object 2 — TRACTABLE on SIGNS, simulation-backed on MAGNITUDE; HONEST if the closed-form temptation is resisted
- **Tractability: MEDIUM-HIGH for signs, LOW for closed-form magnitude.** The size-bias representation of raw AUC is clean and citable; the two comparative-static signs (CV↑, base-rate↓) are provable in the rare-target linearization. The magnitude function $g$ is NOT clean off-linearization.
- **Honesty risk: claiming a closed-form law.** **Mitigation (mandatory): Proposition states SIGNS only; magnitude is a transparent simulation over a grid built from the published $T$ distribution + base rates, with BEC and federal overlaid as two real points.** The simulation reuses the existing power-injection device, so it is not a new method. Verdict: **SHIP as Proposition(signs)+simulation(magnitude). Do NOT write a magnitude formula.**
- **Theory-theater check:** Does it earn the "law" framing? Yes, conditionally: the *sufficient statistic* (CV of $T$, computable before any bid file is opened) is a real, portable deliverable a practitioner can use, and it converts R4's caveat into method. The two-points-on-a-curve story is the genuine generalizing content. The risk is only in overclaiming a closed form, which the mitigation removes.
- **Is the simulation necessary or padding?** Necessary. Without it the magnitude claim is hand-waving; with it, the BEC/federal overlay is the empirical validation of the law. It is the load-bearing exhibit for Object 2.

**Overall verdict:** both objects are defensible minimal versions, NOT theory-theater, PROVIDED the two mandatory mitigations hold (Object 1 anchored to award curve; Object 2 signs-analytic + magnitude-simulation, no closed form). If either mitigation is dropped, that object becomes overclaiming and must be cut to the weaker defensible form (Object 1 → "the frontier is a stopping-rule locus" stated without the concavity proposition; Object 2 → "raw AUC inflates via volume size-bias" stated as mechanism without the law).

---

## WRITING PLAN (file-by-file, ordered)

Execute in this order. Each step is one writing agent's edit; steps 1–2 are independent and can run in parallel, 3 onward depend on the appendix props existing.

**Step 0 — references (any agent, first).** Add `polinsky2000economic`, `mookherjee1989optimal`, `townsend1979optimal` to `submission_clean/references.bib` (exact entries in §"Verified Literature Anchors" above). Tag `% VERIFIED 2026-06-06`.

**Step 1 — Framework appendix (Object 1 home).** `submission_clean/sec_app01_framework_submission.tex`: add `\subsection{The evidence-acquisition stopping rule}` after `app:framework_scope`. State primitives 1–6, Proposition 1 (displayed FOC + 1-paragraph proof), the concavity argument, the explicit "$\rho$ non-increasing by Proposition~\ref{prop:submission_monotone}" link, the joint-upper-bound ceiling, and the §1.6 must-NOT boundary (recovery of exposure, not conduct). ~0.5pp.

**Step 2 — Validation/methods appendix (Object 2 home).** Add the inflation Proposition (two signs, rare-target proof) + the simulation figure (inflation surface, BEC+federal overlaid) to the validation-audits appendix. State sufficient statistic = CV($T$). Enforce §2.7 boundaries (signs not magnitude; simulation not confidential data; floor power-bounded). ~0.75pp + 1 figure. (Requires generating the simulation figure — small R/Python script using the published $T$ distribution + base rates + the existing power-injection device.)

**Step 3 — §7 main text (Object 1 image).** `submission_clean/sec06_screening_forensics_submission.tex`: add a short §7.0/opening subsection "The evidence-allocation problem" stating primitives in prose + Proposition 1 reference + the three mapping bullets (§1.4). Rewrite the existing "A menu of operating points" paragraph so K1=2000 is "the tangency at an implied c/V" not "an arbitrary point." Keep the honest "prices the recovery footprint, not conduct" sentence. Anchor to the **award-recall curve** for the monotone claim (§1.7); footnote the sequential non-monotonicity. ~0.75pp net (some replaces existing prose).

**Step 4 — §4.2 main text (Object 2 mechanism).** `submission_clean/sec04_validation_submission.tex`: replace the bare "mechanically entangled with participation volume" assertion with the size-bias mechanism + sufficient-statistic sentence. ~0.3pp.

**Step 5 — comparative §5 (Object 2 generalization).** `submission_clean/sec_comparative_submission.tex`: reframe the federal verdict from "same null twice" to "second point on the inflation curve; lower base rate ⇒ exposure-only edges out raw ($0.754>0.744$)." ~0.2pp.

**Step 6 — intro C1 + C2 + abstract + Box 1 + conclusion (reframe).**
- `sec01_introduction_submission.tex`: C1 paragraph names the **stopping rule** as the organizational object (the frontier is its solution locus); C2 paragraph upgrades the over-crediting caveat to "a bias we characterize with a sufficient statistic." Add the Object-1 anchoring sentence with the four L&E cites.
- Abstract: one clause upgrading "cost–recall frontier" → "the cost–recall frontier traced by an enforcer's optimal-stopping rule" and "over-credits it" → "over-credits it by a characterized, base-rate-dependent amount."
- Box 1: the "Cost–recall" row implication "A frontier to design against, not a cutoff to deploy" → "The solution locus of a budget-dependent stopping rule." The "Opportunity" row → name the sufficient statistic.
- `sec08_conclusion_submission.tex`: one sentence each — the frontier as stopping-rule image; the inflation law as the portable diagnostic.

**Step 7 — verification.** Compile appendix-before-paper (xr cross-refs), confirm 0 undefined refs (the new `\ref{prop:...}` and `\ref{fig:inflation...}`), claims-discipline scan (no "detects/proves/identifies conduct" introduced by the reframe), and a forbidden-verb scan on the edited intro/abstract/conclusion (per CONSOLIDATED §5 step 4).

**Length budget:** net additions ~2.5–3.0pp main + ~1.25pp appendix + 1 appendix figure. Within the JLEO 30–38pp main envelope if paired with a compensating compression (the existing §6 bid-benchmark demotion option in CONSOLIDATED §5 covers it).

---

## MEMO PATH

`/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers/work/v22-editor/docs/jleo_rr_revision/tierB_reframe_design_memo.md`
