# JLE Radical Rewrite — *Detection Without Identification*

**Date:** 2026-04-29
**Premise:** The institutional identification did not survive replication. Rather than disguise that, we make it the paper's contribution. The piece becomes an essay-style empirical paper on what passive cartel screens can and cannot deliver in low-microdata environments — with São Paulo's BEC as the worked-out case.

This is the **third and most demanding** path: instead of recovering identification through new data (option 1) or replicating elsewhere (option 2), we rebuild the paper around the epistemic limit and propose detection as a distinct deliverable from causal identification. This positioning is unusual for a JLE empirical paper but well-aligned with the journal's tradition of pieces that defend a specific institutional claim with explicit acknowledgment of what the data cannot prove (e.g., Posner 1970, Becker 1968, Polinsky–Shavell 2000 — papers JLE published despite the absence of strict causal identification because the institutional and policy contributions were specific and bounded).

---

## Working title

**Detection Without Identification: A Cartel Screen for Procurement Systems Without Bid Microdata**

Subtitle (optional, for cover letter): *Evidence from São Paulo (2009–2019) and the Epistemic Limits of Passive Screening*.

---

## Central thesis (single paragraph)

> Cartel detection and cartel identification are different empirical objects. Detection asks: which procurement environments warrant scrutiny, with what false-positive rate, against what ground-truth standard? Identification asks: by what causal channel does cartel activity affect prices, and what counterfactual price would prevail absent the cartel? Bid-rigging research has historically conflated the two because the bid-microdata-rich settings used to validate detection tools (Swiss highway, Ohio milk, NYC stamps) are also rich enough to support identification. In data-thin environments — where most procurement systems actually operate — the conflation breaks: detection is achievable, identification is not. We show that a participation-only frequent-losers (FL) screen achieves AUC = 0.94 against São Paulo cartel adjudications, while the same data cannot deliver causal identification of the screen's price implications. We treat this as a feature, not a bug. A passive screen that flags markets with high accuracy, without claiming to estimate the cover-bidding markup, is the epistemically honest deliverable for the data-thin regime that characterizes most public procurement worldwide. The paper develops this distinction theoretically, demonstrates it empirically, and traces its implications for the law-and-economics of antitrust enforcement.

**Why this works for JLE:** the contribution is now an L&E argument about *what enforcement institutions can know* given the data they have — squarely in JLE's tradition. Identification failure is not concealed; it is the empirical anchor for the policy claim that screening and prosecution operate at different epistemic levels.

---

## What changes substantively (vs v13)

### Promoted to headline

1. **The detection/identification distinction.** This was implicit in v13's "the screen does not identify cover bidders firm-by-firm" disclosure paragraph. We elevate it to the paper's central methodological argument.

2. **The Bajari–Ye partition contribution.** Currently a side benefit; becomes a core deliverable because it is exactly the kind of thing detection-without-identification can offer downstream researchers.

3. **The honest epistemic stance.** RV q=1 = 17.5%, conditional FL–CADE p=0.93, pre-trends at $t=-2,-3$, FL persistence 10%, modality split that doesn't identify — all of these become *parts of the contribution*, not concessions in §10.

4. **The cross-jurisdictional applicability claim.** Currently aspirational; becomes the policy core because the case for detection-without-identification is stronger when the screen demonstrably travels across data-thin environments.

### Demoted from headline to context

1. **Conditional price gap of 3.6–7.7%.** Reported once in §6, framed as "*observable* but not *identifiable*"; not the empirical anchor of the paper.

2. **Modal heterogeneity (pregão > convite).** Reported once as descriptive evidence that cover-bidding incentives operate across both formats; no causal claim.

3. **Mechanisms M1–M5.** Retained but framed as *coherence with cover-bidding mechanisms*, not as identification.

4. **Welfare 0.3–0.9%.** Stripped from main text; appears only in appendix as illustrative back-of-envelope under explicit "assumes causality the design does not establish."

### Removed entirely

1. **§7.4 "Additional Identification Evidence" as an identification claim.** The section is renamed and reframed (see below) but no longer claims to identify $\beta$.

2. **The 7.6% / −16% / sign-flip narrative.** Gone. Replaced with the canonical sample-split as descriptive heterogeneity in a smaller table.

3. **The Cinelli–Hazlett RV bound as a robustness check on identification.** It now appears as part of the *epistemic floor* — the bound on what we cannot rule out, which is the paper's central honesty mechanism, not a robustness footnote.

4. **The structural model markup interpretation.** Calibration appendix only; no main-text claim that the structural model independently identifies anything.

---

## Revised section structure (new outline)

The paper is shorter than v13 (~50 pp main body vs 81 pp). The reduction comes from removing the identification-claiming material rather than from cutting evidence.

### Title page + Abstract + Highlights (1 page)

**Abstract (rewrite, ~150 words):**

> Cartel detection and cartel identification are distinct empirical objects, separable in data-thin procurement environments where the second is unattainable. We propose a participation-only screen for bid-rigging cartels — frequent losers (FL): firms participating in many tenders without ever winning — and apply it to São Paulo's electronic procurement platform (BEC, 2009–2019, 4.5M tender-items). The screen achieves AUC = 0.94 against the prospective ground truth (12 CADE cartel adjudications, 8 of which post-date the sample) and AUC = 0.748 against the strictly contemporaneous ground truth. Detection generalizes: across 10 product sectors, mean AUC = 0.954. The screen's classification produces an *ex ante* firm-level partition that bid-coordination tests (Bajari–Ye 2003) had previously required as input; with the FL partition, exchangeability and conditional-independence are rejected at $D = 0.15$ and $t = 81.0$. We are explicit about what the design does not deliver: causal identification of the screen's price implications is not feasible from contract-award records alone. We propose this gap as a feature of the institutional setting, develop the law-and-economics implications, and outline a Screen→Triage→Investigate enforcement pathway that respects the epistemic limit.

### §1 Introduction (~3 pages)

**Three-act structure:**

**Act 1 — The puzzle.** 16,843 always-losers in BEC; 2,735 placed bids in 14 or more tenders. At plausible bid-preparation costs, sustained zero-win participation is rationally dominated. Why?

**Act 2 — The institutional setting.** Convite (Lei 8.666 Art. 22) requires three valid proposals. Pregão has no minimum-bidder rule. Both modalities offer cover-bidding incentives. The screen is agnostic to which channel dominates because neither is causally identified by what we observe.

**Act 3 — The detection/identification distinction.** State the central thesis (paragraph above). Detection is achievable; identification is not; the data-thin regime is the binding constraint. Define the contribution as making this distinction operational and showing what it costs to honor it.

**Findings (in this strict order):**
1. AUC = 0.94 prospective / 0.748 contemporaneous against CADE adjudications.
2. Cross-sector mean AUC = 0.954 across 10 product sectors.
3. Bajari–Ye partition test rejects exchangeability ($D = 0.15$) and conditional independence ($t = 81.0$) using the FL partition as input.
4. The conditional price gap (3.6–7.7%) is *observable* and *consistent with* cover-bidding mechanisms, but the institutional design does not deliver causal identification — and we argue this limitation is structural to passive screening in data-thin regimes, not a failure of effort.
5. Mechanism diagnostics (M1–M5) are mutually consistent with cartel-ecosystem readings, individually consistent with non-collusive alternatives.

**Three contributions:**

(i) **Methodological — the detection/identification distinction.** A formal statement of what passive participation-only screens can deliver and what they cannot, with implications for how cartel-screening tools are validated and deployed.

(ii) **Substantive — the FL partition for downstream tests.** Bajari–Ye-class coordination tests have historically required *ex post* partitions (post-conviction or assumed). The FL classifier produces an *ex ante* firm-level partition that downstream tests can consume. Demonstrated empirically.

(iii) **Operational — the data-thin enforcement pathway.** A three-stage Screen → Triage → Investigate deployment ordered by marginal data cost, deployable wherever a procurement system records winners and participants regardless of bid-level archiving. Applies to subnational systems in Brazil, US small-business procurement (FAR 13.106-2), EU member-state platforms with limited bid microdata (Directive 2014/24/EU), and OECD developing-economy contexts.

**Honest scope statement:** what the design does not deliver. Welfare estimation requires causal identification, which the design does not provide. Firm-by-firm cartel attribution requires firm-type stability, which the FL flag does not exhibit (10% persistence). The screen identifies environments, not operatives.

**Roadmap.**

### §2 Related Literature (~1 page, light revision)

Same four-literature structure as v13. The synthesis paragraph reframes the four literatures around the **detection/identification gap**:

- **Bajari–Ye** family: needs the partition. We provide it.
- **Imhof/Wallimann** family: needs bid microdata. We work without it.
- **Cover-bidding identification** family: needs post-conviction records. We operate prospectively.
- **Procurement-enforcement-in-low-resource-settings** family: flagged the gap; we close part of it operationally.

### §3 Detection Versus Identification (~2 pages, NEW)

This is the methodological backbone of the radical rewrite. Currently absent in v13.

**Subsection structure:**

1. **Definitions.** Detection: classifying procurement environments (markets, tender-cells, firms-in-context) by their probability of containing cartel activity. Identification: estimating the causal effect of cartel activity on a price-or-quantity outcome under a stated counterfactual. Both objects are well-defined; they are not the same object.

2. **The data-thin/data-rich asymmetry.** The bid-rigging literature's empirical canon (Porter–Zona 1993 Ohio, Pesendorfer 2000 NY stamps, Asker 2010 NYC, Imhof 2017 Switzerland highway, Conley–Decarolis 2016 Italy) operates in data-rich environments where bid microdata is available and identification is feasible. The settings where cartels are most likely to operate — subnational procurement, developing-economy systems, federal small-business contracting — are systematically data-thin. This is not a temporary data limitation: it reflects how administrative procurement records are stored.

3. **What detection can deliver.** Triage. ROC-curve classification at administratively useful FPR/TPR trade-offs. Cross-sector replication tests. Partitions usable as inputs to downstream tools.

4. **What detection cannot deliver.** A causal estimate of the cartel markup. A counterfactual price. A welfare loss expressed as a fraction of GDP. A firm-level cartel-membership identification.

5. **Why honoring the distinction matters for L&E.** When detection is read as identification, three pathologies follow:
   - **Welfare overclaim.** Markups estimated under selection-on-observables are reported as policy-relevant magnitudes; they are not.
   - **Firm-level overclaim.** A flag of high prior is read as a verdict; due-process expectations are violated.
   - **Mechanism overclaim.** A correlation pattern is interpreted as evidence for one mechanism over another; competing mechanisms remain underdetermined.
   
   The data-thin regime forces an epistemic discipline that the data-rich regime can dispense with. We argue this discipline is the right one for procurement-enforcement institutions operating under realistic data constraints.

6. **Implications for econometric practice.** A passive screening tool should be validated by (a) detection performance against ground truth, (b) cross-validation across institutional contexts, (c) downstream-input usability — *not* by the magnitude of an associated price coefficient. We organize the empirical evaluation in §6–§8 around this principle.

### §4 Legal and Institutional Framework (~1.5 pages)

Substantially same as v13's `sec_institutional.tex` but with one critical edit:

The paragraph that currently reads "the convite minimum-bidder rule generates a population of firms whose participation pattern is the empirical signature of regulatory cover bidding" is replaced with: "The rule, designed to ensure procedural competition, can be satisfied by genuine entry or by mechanical cover bidding. Whether the rule generates cover bidding or merely accommodates it is an empirical question we deliberately do not attempt to settle. The screen detects the configuration without committing to the cover-bidding generation channel — consistent with the detection/identification distinction of §3."

Other content (TCE-SP, CGE, CADE, Lei 14.133/2021, OECD parallels) unchanged.

### §5 Data and FL Definition (~1.5 pages, unchanged)

All numbers ✅. The FL definition (always-loser ∩ tenders > median+1.5×IQR threshold) is reported as constructed *a priori* on behavioral grounds and validated *post hoc* by detection performance. Detection-by-construction.

### §6 Detection Performance (~5 pages)

This is the empirical core. The reorganization is:

**§6.1 Headline AUC.** 0.94 prospective, 0.748 contemporaneous, both bounds reported.

**§6.2 Imhof comparison.** AUC 0.79 against the bid-level CV alternative; the FL screen exceeds the bid-level alternative by 15 ROC points despite consuming strictly less data. This is the central detection-performance result.

**§6.3 ML composite.** AUC 0.84 (5-fold CV) when FL is combined with Imhof features. Marginal improvement over FL alone is small, suggesting FL captures most of the detection-relevant variance.

**§6.4 Cross-sector replication.** Mean AUC 0.954 (SD 0.034) across 10 sectors. AUC stability is the strongest available evidence that the screen reflects a transferable signal rather than a São Paulo-specific artifact.

**§6.5 Bajari–Ye partition.** $D = 0.15$, $t = 81.0$. The partition contribution is here, not buried in §7.6 of v13. This is the second core result.

**§6.6 CADE external consistency.** 12 cases / 65 defendants / 47 BEC-active / 8 post-sample. Co-participation 7.1% vs perm 2.0% (3.5×). Within-firm 3 of 7 always-loser defendants are FL = 43% (2.6× baseline). Conditional FL–CADE p=0.93 — disclosed prominently. Excluding CADE tenders: $\hat\beta = 0.062$ vs full-sample 0.064.

### §7 Conditional Price Association (~3 pages, demoted)

**The shift:** this section is no longer a results section in the v13 sense. It is reframed as **descriptive evidence on what FL-flagged environments look like, organized to be informative without claiming identification**.

**§7.1 OLS conditional associations.** General 6.8%, general+PBU 6.4%, pregão 9.3%, convite 3.8%. Reported as "the FL flag selects environments in which negotiated prices are 4–9% higher than non-flagged environments within the same item-year-buyer cell, conditional on modality. This is an *observable* feature of FL-flagged environments. It does not establish that the FL flag *causes* the price differential."

**§7.2 Specification consistency.** Cross-fit (3.6%), CEM (7.7%, N=969,751), IPW (5.5%, N=830,194). All bracket the OLS point estimate.

**§7.3 Modality and within-convite heterogeneity.** Pregão > convite (9.3 > 3.8). Within convite, n_genuine ≥ 3 (4.0%) vs n_genuine < 3 (7.4%) using the canonical pipeline numbers. Reported as descriptive heterogeneity. Frame: "the modal heterogeneity is consistent with cover-bidding incentives operating across both formats. We do not interpret it as identifying the cover-bidding channel; that interpretation requires variation the design does not provide."

**§7.4 Sensitivity to unobservables.** $RV_{q=1} = 17.5\%$. Oster degenerate. Cinelli–Hazlett bound is not a robustness check on identification (because identification is not claimed); it is a quantification of *how much we cannot rule out*, the central epistemic object of §3.

The section length shrinks because most of v13's §7 — institutional ID, structural model, network split, IV — is either dropped or moved to mechanism-coherence (§8).

### §8 Mechanism Coherence (~3 pages, renamed)

**Reframing:** what was "Supporting Diagnostics" in v13 becomes the appropriate object for detection-without-identification — a battery of tests that *constrain alternative readings of the FL flag* without identifying the cover-bidding mechanism.

M1 (no crowding-out: +0.143 non-FL firms), M2 (calibrated bidding: −0.041 to ref price), M3 (low elasticity to lagged price: 0.0021), M4 (repeated pairs: 4,603 ≥5 vs perm 3,271), M5 (Cox HR=0.60, longer survival).

The closing paragraph: "Each diagnostic is individually consistent with non-collusive alternatives. Jointly, they are coherent with the cover-bidding-mechanism reading and inconsistent with the simplest competitive-displacement and price-chasing alternatives. They do not identify the mechanism; they constrain the readings of the flag."

The bid-rotation/bid-inflation sub-block (HHI 0.178 vs 0.303, FL bids 15.4% above winners) goes here as supporting evidence.

### §9 Limitations as Contribution (~2 pages, RENAMED FROM "Limitations")

This is the **most important rhetorical move** in the radical rewrite. The §10 "Limitations" of v13 becomes §9 "Limitations as Contribution" — and is positioned as evidence that the paper honors the epistemic discipline §3 argues for.

**Subsection structure:**

1. **The price-gap claim is not causal.** Pre-trends at $t=-2,-3$; staggered DiD invalidated; Cinelli–Hazlett bounds not strict identification. Each is reported and the consequence drawn.

2. **The institutional identification we attempted does not survive replication.** Explicit disclosure: "An earlier version of this paper claimed that interacting FL with a within-convite constraint-binding indicator yielded a 7.6% premium under voluntary cover bidding flipping negative under the binding rule. Re-running this specification on the canonical pipeline with controls held fixed produced different magnitudes and signs (see online appendix). We treat this as evidence in favor of the §3 thesis: the modal × constraint variation does not reach the level of institutional identification we initially attributed to it. We report the within-convite split in §7.3 as descriptive heterogeneity only."

   This paragraph is the heart of the credibility claim.

3. **FL persistence is 10% across sample halves.** The flag identifies environments, not operatives — and we name this as a feature of the screen, not a defect.

4. **Conditional FL–CADE p=0.93.** The unconditional 3.5× excess is participation-driven, not FL-classification-driven, conditional on participation count. We name this as a feature of how the screen is intended to operate.

5. **Welfare is illustrative only.** The 0.3–0.9% range, were it interpreted as a causal magnitude, would extrapolate beyond what the design supports. We report it in the appendix only.

6. **External validity.** São Paulo BEC is one platform. Cross-sector AUC stability is the strongest available robustness; ComprasNet, TCE-MG, MEPA, CompraNet replications are open empirical questions.

### §10 Conclusion (~2 pages)

**Paragraph structure:**

1. The detection/identification distinction restated. The empirical case demonstrates both halves: detection achieved at AUC 0.94, identification not achieved.

2. The three contributions restated explicitly.

3. **The L&E core argument:** procurement enforcement institutions operate under data constraints that do not permit strict causal identification of cartel markups. A passive screen that flags environments at high accuracy without claiming to estimate the markup is the epistemically honest deliverable. Treating detection as identification — interpreting the flag as a verdict, the conditional association as a causal estimate, the markup proxy as a welfare loss — leads to known pathologies.

4. **The deployment pathway** (Screen → Triage → Investigate) that honors the distinction.

5. **Open questions.** Causal identification (Lei 14.133 DiD, post-2021 data). External replication (ComprasNet, OECD). Sector-cartel correspondence (BEC item dictionary).

6. **Closing line:** "A flag is not a verdict — and a paper that honors the distinction is not a smaller paper. It is a different kind of paper, suited to the kind of data the institutions of procurement enforcement actually have."

---

## What the radical rewrite costs

| Element | Effort | Risk |
|---|---|---|
| §3 NEW (Detection vs Identification) | High — this is essay-style L&E methodological writing | Must land cleanly; if it reads as defensive, the paper loses the gambit |
| §6 reorganization (detection-first results section) | Medium — material exists, sequencing changes | Low |
| §7 demotion (price gap to descriptive) | Medium — requires rewriting all framing claims | Low |
| §9 "Limitations as Contribution" | Medium — section exists, rhetorical reframing | Medium — the paragraph admitting v13 ID failure is delicate |
| Drop ~30 pages from v13 (structural model main, welfare main, IV main, network split as identification) | Medium — moves to appendix or out | Low |
| Bibliography: add Posner 1970, Becker 1968, Polinsky–Shavell 2000, Harrington 2008, Sanchez-Graells 2019 in JLE-style framing | Low — references already in bib | Low |
| Total | ~12 days vs the ~10 days for non-radical | |

**Critical path:** §3 NEW (3–4 days of essay-style writing) + §9 reframing (1 day for the institutional-ID-failure disclosure paragraph). The rest is recombination of existing material.

---

## Why this might land at JLE specifically

JLE has a track record of publishing pieces that:

1. **Develop a principled distinction with policy stakes.** Posner 1970 (private vs public enforcement), Polinsky–Shavell 2000 (deterrence vs incapacitation), Harrington 2008 (proactive vs reactive screens). Detection vs identification fits this tradition directly.

2. **Are honest about what the data cannot prove.** JLE published Becker 1968 with no empirical content. Empirical pieces in JLE that explicitly bound their identification (Caoui 2022, Baranek–Titl 2024) are accepted because the institutional contribution is precise.

3. **Connect to active policy debate.** The OECD/UNCAC procurement-enforcement agenda; Brazilian Lei 14.133 transition; EU Directive 2014/24/EU; US FAR 13.106-2 small-business procurement — all live policy issues that the screen contributes to.

4. **Pay attention to administrative law.** The "flag is not a verdict" framing connects directly to due-process expectations in administrative enforcement, a JLE staple.

**The risk JLE referees pose:**

A typical JLE referee will read §3 first and ask: "Is this a paper, or is it an extended methodological note?" The answer must be: it is a paper because §6–§8 demonstrate empirically that the §3 distinction is *operationalizable* — the screen achieves AUC 0.94 in a low-data setting, the partition contribution is real, the modal heterogeneity is descriptively informative. §3 without §6–§8 is an essay; §3 with §6–§8 is a paper with a substantive empirical core organized around a methodological argument.

A second referee will ask: "Does the FL screen really need to be cast as detection-without-identification, or is the author hiding identification failure?" The §9 paragraph is the answer: yes, identification was attempted; yes, it did not survive replication; we report this and reframe accordingly. JLE referees are sympathetic to authors who diagnose their own failures and rebuild around them, in a way that referees at AEJ:Applied or RAND are not.

**Acceptance odds at JLE:** ~40–50% with the radical rewrite executed well (vs ~30% for the non-radical option-α rewrite of `new_story_outline.md`). This is a real improvement at JLE specifically because the rewrite turns the paper into the kind of thing JLE prefers (institutional + L&E + honest about identification limits) rather than the kind of thing JLE tolerates (empirical IO with partial identification).

---

## What to take to Paulo

The five things this radical rewrite asks Paulo to ratify:

1. **Embrace the failure.** The institutional ID we tried to vend in v13 doesn't replicate. Rather than disguise this, we make it the paper's central methodological contribution.

2. **Reframe the paper.** From "we identify cover bidding via the convite minimum-bidder rule" to "we develop the detection/identification distinction and show it is operationalizable in data-thin procurement settings." Different paper, same data, same screen.

3. **Add §3 as new methodological core.** A 2-page essay-style section developing the detection/identification distinction. This is the writing that turns the paper from "empirical IO with limitations" into "L&E with a precise institutional contribution."

4. **Rewrite §9 Limitations as Contribution.** Explicit disclosure that v13's institutional ID does not replicate; reframe as evidence in favor of the §3 thesis.

5. **Target JLE on this version.** Acceptance odds ~40–50% for this specific reframing, vs ~30% for the option-α non-radical rewrite. The radical version is better suited to JLE because it converts a vulnerability (failed identification) into the contribution (epistemic discipline for data-thin settings).

If Paulo agrees: ~12 days of work, with §3 NEW as the critical path.

If Paulo disagrees: fall back to the non-radical option-α (`new_story_outline.md`), target JLEO/IJIO with ~50–60% odds. Lower stakes, lower target.

If Paulo wants to gamble: try the radical version at JLE first; if rejected, the §3 essay survives and informs the JLEO/IJIO submission of the non-radical version.
