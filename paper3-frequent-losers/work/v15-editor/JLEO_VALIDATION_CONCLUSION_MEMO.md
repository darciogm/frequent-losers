# JLEO Validation + Mechanism + Conclusion Reframe Memo — Paper 3 (v19, PART 5)

**Status:** §6 (Validation), §8 (Mechanism Heterogeneity), §12 (Conclusion) rewritten in JLEO register. PDF compiles at 45 pp.
**Files touched:** `sec_cade_v15.tex`, `sec_mechanisms_v15.tex`, `sec_conclusion_v15.tex`.
**Word counts:** §6 = 877 (was 649, +35%); §8 = 1,026 (was ≈900, +14%); §12 = 643 (was ≈300, +110%). The growth in §6 and §12 is conceptual: the screening framing requires explicit articulation of why cobidders are the appropriate validation object and why the conclusion ends on enforcement architecture rather than on operational deployment.

---

## 1. §6 Validation — what changed

### 1.1 Section title and opening
| Before | After |
|---|---|
| "Validation Against CADE Adjudications" | "Validation: Cartel Adjacency Under Coarsened Observability" |
| "The validation asks whether the construct discriminates populations with a higher prior probability of cartel adjacency than random selection." | "The validation asks the structurally appropriate question for a screening statistic computed on award-record data: does the construct concentrate on populations of firms with a higher prior probability of operating inside cartel-affected environments than random selection at comparable participation volume?" |

The opening now tells the reader **why** cobidders are the appropriate validation object: award-record data does not contain the information required for membership identification, and the screening framing of §5 does not require it. The cobidder-vs-membership distinction is now derivative of the JLEO frame, not an apologetic disclaimer.

### 1.2 Population table notes
Refined: "Strong AUC against this label corroborates that the screening statistic concentrates on cartel-relevant environments; it does not adjudicate membership." The phrase "screening statistic" replaces "the construct" in the notes; the "is not equivalent to identifying membership" clause becomes "does not adjudicate membership", which is the JLEO-register statement.

### 1.3 Conservative benchmark (§6.2)
Adds a sentence at the close: *"The excess is what the screening framing predicts under the separating equilibrium of Online Appendix~A: where the cartel deploys cover bidders, the loser-side participation footprint concentrates."* The contemporaneous excess is now explicitly read against the framework's prediction, not just reported as a statistical fact.

### 1.4 Direct-defendant asymmetry (§6.3)
Reframed: *"The asymmetry between cobidder discrimination ($\valAUCFLfirm$ in-sample, $\valAUCFLfirmTemp$ under temporal holdout) and direct-defendant discrimination ($\valAUCdirectStd$) is the design's empirical signature, not a failure of validation. The screening statistic recovers loser-side participation footprints; direct defendants are by construction the winner side of the same arrangements and lie outside the target population."* The asymmetry is now the design's signature, with an explicit structural justification.

Also: removed the `\resizebox{\textwidth}{!}{...}` from `tab_cade_fl_firms` (the same formatting bug that affected Table 6). The 5-column small table now renders at natural width.

### 1.5 Robustness to enforcement record (§6.4)
Reframed: *"The screening signal in $\beta$ operates independently of the enforcement record."* Then both readings of the residual sample (undetected cartels OR price environments correlated with FL through orthogonal channels) are stated as consistent with the screening interpretation. The "triage" framing is dropped.

### 1.6 Closing claim (§6.5)
Restructured into four numbered claims explicitly labeled as supporting the screening interpretation. Closes with: *"The labels are indirect by construction---a feature of working at the award layer rather than the bid layer. The validation corroborates the screening interpretation of the construct; it does not, and under coarsened observability cannot, adjudicate the legal status of any individual firm."* The "cannot under coarsened observability" is now declarative, not apologetic.

---

## 2. §8 Mechanism Heterogeneity — what changed

### 2.1 Section title and opening
| Before | After |
|---|---|
| "Mechanism Heterogeneity" | "Heterogeneity of the Screening Signal" |
| "The price gap and the procuring-unit-size gradient establish that the construct has a measurable, institutionally patterned imprint. This section reads the heterogeneity through the framework's mechanism predictions." | "The screening object reads against the framework's deployment problem. This section reports two pieces of within-evidence that discipline the framing." |

The section now reads as evidence for the framing rather than as a hunt for institutional mechanism.

### 2.2 §8.1 Loss intensity dominates
Largely preserved. Closing reframed: *"The dose-response pattern is consistent with the screening interpretation and inconsistent with a pure-confound reading of the broad-sample association (\S\ref{sec:results_overlap})."* The horse race now does explicit JLEO work, supporting the screening reading vs the confound reading of $\beta$ rather than just defending a vocabulary choice.

### 2.3 §8.2 Modal contrast — fundamentally reframed
| Before title | After title |
|---|---|
| "Modal Heterogeneity: Pregão Deeper than Convite" | "Modal Contrast as Observability-Regime Variation" |

The reframing recasts the pregão–convite contrast as **variation in the observability regime within which the screening signal is recovered**, not as a horse race between two modalities. The two BEC modalities expose different observability regimes (preg\~ao = real-time electronic auction with public bidding interface; convite = sealed-bid invitation procedure with statutory quorum). The fact that the screening signal is sharper in pregão is read as: the observability regime that exposes more information also exposes the screening footprint more sharply. The institutional reform direction (Lei~14.133/2021 consolidates pregão-style auctions) is now read as a statement about the regime in which the construct is most informative — and explicitly **not** as strengthening "the deployable case for the construct" (the old triage register). The new closing instead says: *"Whether this is read as strengthening the construct's portability or as scope-restricting it depends on which observability regime a candidate jurisdiction operates under; both readings are consistent with the screening-stage interpretation."*

### 2.4 §8.3 What the data do not adjudicate — renamed and reframed
| Before title | After title |
|---|---|
| "What the Data Do Not Support" | "Predictions the Data Do Not Adjudicate" |

Open language change ("do not support" → "do not adjudicate") is JLEO-register and accurate: the data are silent, not refuting. Opening sentence reframed: *"They are not load-bearing for the screening interpretation, which rests on the participation primitive (\S8.1) and the observability-regime variation (\S8.2), not on the cell-level structure of cartel rotation."* The two failed predictions (cell heterogeneity, first-time-FL) are explicitly demoted from "scope" to "non-load-bearing" — the JLEO frame does not need them.

### 2.5 Closing
Removed the closing paragraph that said the operational implication is "concrete: oversight bodies on platforms dominated by pregão-style auctions can expect stronger signal-to-noise..." That was JPART/JPAM register. Replaced with the regime-variation reading.

---

## 3. §12 Conclusion — what changed

### 3.1 Old conclusion structure
- ¶1: triage screen extracts usable signal from the data envelope every system maintains.
- ¶2: caveats — sign reversal and buyer-size gradient under-identified.
- ¶3: integration with bid-distribution methods, adversarial adaptation, replication open.

### 3.2 New conclusion structure (4 paragraphs)

**¶1 — The informational mismatch as starting point.**
Opens on the fact that the bid-rigging detection literature presupposes bid-level data while real enforcement environments preserve only the award envelope. Frames the paper's question as: what collusion-relevant statistic can be recovered when only the award layer is observable.

**¶2 — Empirical answer.**
Lists the framework's identification of the participation primitive and the empirical evidence: $\valHeadlineRange$ broad-sample association, AUC $\valAUCFLfirm$ / $\valAUCFLfirmTemp$ against cobidders, $\valMultThreeTwo\!\!\times$ contemporaneous excess, continuous-dominates-binary, $\valAUCdirectStd$ against direct defendants as the design's signature. No "triage" language anywhere.

**¶3 — Screening framing reorganizes how to read the evidence.**
Names $\beta$ and $\beta^{\text{ov}}$ as different empirical objects; sign reversal as diagnostic; buyer-size gradient as detection-regime variation; lists the three corroborations.

**¶4 — Implications for enforcement design.**
Two declarative implications:
1. *"What survives data coarsening is not a moment of submitted bids but the equilibrium-generated participation footprint that the collusive arrangement leaves on the award layer."*
2. *"The architecture of enforcement under incomplete observability separates an award-layer screening stage from a bid-layer forensic stage. The screening stage produces candidate flags; the forensic stage adjudicates suspected coordination on the bid distribution where microdata exist."*
The Imhof benchmark is cited as evidence that the two stages operate on the same underlying cases without dominating each other.

**Closing paragraph: scope and conceptual portability.**
The construct stops at the screening stage by design; cannot adjudicate membership under coarsened observability; cobidders are the structurally appropriate validation object. Adversarial adaptation and replication beyond São Paulo are scope. The closing sentence:

> *"Wherever an enforcement environment exposes the award layer without exposing the bid layer, the question is not whether bid-distribution screens can be retrofitted but what participation primitive the collusive arrangement generates that survives the coarsening, and how the screening stage that reads that primitive should be sequenced before the forensic stage that requires bid-level evidence."*

This is the JLEO-style payoff. No "deployable", no "oversight bodies", no "operational pathway".

---

## 4. Cross-section of vocabulary changes

| Old | New |
|---|---|
| "the construct" (when meaning the empirical object) | "the screening statistic" or "the screening signal" |
| "operational footprint" | "screening object" |
| "operational implication" | "implication for enforcement design" |
| "deployable" | dropped or "portable to other observability regimes" |
| "triage" | dropped |
| "thinner institutional capacity at smaller buyers" | "variation in the screening signal across detection regimes" / "informativeness across the monitoring environment" |
| "operative channel" | "causal channel" (in negation only) |
| "scope information about where the construct fires most cleanly" | "variation in the screening signal across observability regimes" |
| "hard upper bound on broader detection claims" | "delimits its scope" / "cannot, under coarsened observability, adjudicate" |
| "the screen's signal turns on the latter as much as on the former" | "$\beta$ and $\beta^{\text{ov}}$ are different empirical objects" |

---

## 5. Appendix — minimal touches

The appendix `sec_appendix_v15.tex` was not edited in PART 5. The labels reframed in PART 3 (Tab B.3 — buyer-size labels; Tab B.4 — modal informativeness; Tab C.2 — leakage audit notes) remain consistent with the §6 / §8 vocabulary established here. No new mismatch surfaces.

The adversarial-adaptation appendix (App G) carries one line that could now be tightened: *"Operational lifetime in any deployment requires periodic recalibration..."* The word "deployment" is a leftover from the operational register. Acceptable in App G because the appendix discusses adversarial dynamics in operational terms by nature; if a JLEO referee flags it, replace with "Practical lifetime in any application of the screening statistic..."

---

## 6. What was deliberately preserved

- All numerical anchors (sample sizes, AUCs, gradient ratios, p-values, CIs).
- The scientific honesty about what the data do not adjudicate (the cell heterogeneity prediction; the first-time-FL prediction; the failed RDD/DiD designs).
- The cobidder-vs-membership distinction, now made structurally derivative of the JLEO frame rather than apologetic.
- The dose-response evidence (continuous dominates binary), now load-bearing for the screening interpretation.
- The direct-defendant AUC as the design's signature.
- The three independent corroborations (cartel-adjacency moves with $\beta$; dose-response; sensitivity bounds).

---

## 7. Risks and open issues

### R18. The conclusion still depends on §10 not yet existing
The conclusion's ¶4 ("the architecture of enforcement under incomplete observability separates an award-layer screening stage from a bid-layer forensic stage") references the Imhof benchmark in §9.4 (Robustness) as evidence of the two-stage architecture. The architectural claim would be sharper if a dedicated §10 existed. The conclusion currently does the architectural work that a §10 would do; if §10 is added in a future pass, the conclusion can be tightened to forward-reference it. Until then, the argument is internally consistent but the architectural claim sits in two places (intro + conclusion + Robustness §9.4) without a dedicated section.

### R19. §8.2 (modal contrast) has been re-typed as observability-regime variation
The reframing makes a stronger interpretive claim than the empirical evidence requires: the data show the screening signal is sharper in pregão than in convite, and the JLEO-register interpretation reads this as informativeness varying with observability regime. A skeptical referee may push for evidence that the regime-variation reading is preferred to alternatives (e.g., bidder-pool composition differences between modalities). The §8.2 closing acknowledges this and explicitly states that the design cannot separate the two readings. The risk is that a JLEO referee finds the abstraction more dignified but no more identified than the JPART version.

### R20. The §6 closing makes a stronger claim than before
The §6.5 closing now says "under coarsened observability cannot adjudicate the legal status of any individual firm". This is JLEO-register and structurally correct, but it is a stronger claim than the "we don't claim cartel detection" of v18. A referee may ask: is the claim of inadequacy specific to award-record data, or general to participation-only screens regardless of the data layer? The framework is silent on this, and the empirical exercise cannot speak to it. We have decided to keep the stronger version because it follows from the screening framing; if a JLEO referee challenges it, the response is that the screening object is constitutively distinct from the membership object, not just observationally weak.

### R21. Word counts
Section length grew on net. The introduction and §5 in PARTs 2 and 4 already added ≈600 words; PART 5 adds ≈900 more across §6, §8, and §12. The current PDF stands at 45 pp. This is the upper end of JLEO acceptable. PART 6 (when authorized) should compress the appendix or accept the length as the cost of the conceptual reframe.

### R22. The conclusion does not mention CADE explicitly
The new ¶2 names "adjudicated CADE cobidders" once and the validation evidence once. Some JLEO readers may want the validation discussed at greater length in the conclusion as the empirical anchor of the screening claim. We accept the tradeoff: the conclusion is now load-bearing for the architectural claim, and the validation has its own dedicated section (§6) and a paragraph in the new ¶3 ("cartel-adjacency validation moves with the broad-sample association"). Further conclusion expansion would dilute the architectural payoff.

---

## 8. Alignment with the JLEO editorial map

This pass implements:
- §6 Validation: "Validation: Cartel Adjacency Under Coarsened Observability" rename ✓
- §6 opener defending cobidders as structurally appropriate object ✓
- §8 buyer-size and modal heterogeneity reframed in detection-regime / observability-regime register ✓
- §12 ending on "what survives data coarsening / how screening and forensic stages should be sequenced / enforcement under partial observability" ✓
- "Triage" and "deployable" eliminated from main text body of these three sections ✓

Editorial map items still pending after PART 5:
- New §10 Screening vs Forensic Stages (architectural section using Imhof benchmark) — currently referenced in §12 but not yet a dedicated section.
- Reproducibility audit: ~14 tables with cells still not fully macro-bound (as catalogued in `JLEO_EDITORIAL_MAP.md` §5).
- Theory promotion: Lemma + Proposition currently in Online Appendix A; editorial map proposed promoting them to a main §3.
- §11 Limitations not yet revisited in PART 5 (still at PART 4 state).

---

*End of memo. PART 6 (when authorized) covers: §10 architectural section, §11 Limitations refresh, full reproducibility audit, theory promotion to main text, final read-through.*
