# JLEO Intro Reframe Memo — Paper 3 (v19, PART 2)

**Status:** Title, abstract, introduction rewritten for JLEO. PDF compiles at 39 pp.
**Files touched:** `sec_frontmatter_v15.tex` (title + abstract + keywords), `sec_introduction_v15.tex`.
**Word counts:** abstract 216 words (was 188); introduction 1,006 words (was 573). The abstract grows slightly to do conceptual work that the previous version offloaded to §1; the introduction grows because the JLEO frame requires more theory and contribution work than the triage-tool frame did.

---

## 1. Old central question vs new central question

| | Before (v18-final) | After (v19-JLEO) |
|---|---|---|
| **Central question** | "What signal can oversight bodies extract from contract-award records when bid microdata are unavailable?" | "What collusion-relevant information remains when enforcement observes only the award layer rather than the bid layer?" |
| **Frame** | Operational / managerial. The reader is positioned as a procurement-oversight body looking for a deployable triage tool. | Conceptual / law-econ-org. The reader is positioned as a researcher of enforcement under coarsened information, asking what statistic survives the data-layer mismatch. |
| **What the paper is about** | An award-record screen for procurement triage. | The screening value of endogenous loser-side participation; an award-layer screening stage that runs before a bid-layer forensic stage; what the framework's separating logic implies for what is identifiable under coarsened observability. |

The new question is harder to defend on operational grounds and easier to defend on JLEO grounds. The procurement setting becomes the empirical application, not the identity of the paper.

---

## 2. Old contribution framing vs new

### Old (v18-final)
1. A triage tool computable on award records alone.
2. Adjacency-based validation against CADE.
3. Honest limitations (no causal effect, no firm-level guilt).
4. Integrates with bid-distribution methods where microdata are available.

### New (v19-JLEO)
1. **A screening statistic that survives data coarsening.** The framework identifies $\log(1+\text{tenders\_count})$ together with $\text{wins}=0$ as a sufficient ranking statistic for cover-bidder type given award-record data. The horse-race result (continuous dominates binary) is the empirical test of which statistic survives coarsening.
2. **A screening-value-vs-treatment-effect interpretation of the sign reversal.** The broad-sample association is read as the loser-side participation footprint where the cartel deploys it; the overlap-restricted estimate strips the endogenous sorting that *generates* the screen's economic content. The reversal is diagnostic of the screening-value interpretation, not a robustness failure of a treatment-effect interpretation.
3. **Cartel adjacency as the structurally appropriate validation object.** Award-record data cannot adjudicate membership; cobidder labels are the validation object the framework's screening statistic is designed to recover. The asymmetry between cobidder AUC ($\valAUCFLfirm$) and direct-defendant AUC ($\valAUCdirectStd$) is the design's empirical signature, not a failure.
4. **Architectural claim: enforcement under incomplete observability separates a screening stage (award layer) from a forensic stage (bid layer).** The construct fills the first; bid-distribution screens fill the second. The two stages answer different questions and require different statistics. This is the JLEO-style closing claim — empirically supported by the Imhof–Wallimann benchmark in §10.

The four old contributions all survive but are recast as consequences of the new architectural claim rather than as the paper's payoff.

---

## 3. Specific reframings inside the introduction

| Element | Before | After |
|---|---|---|
| Opening sentence | "Brazilian electronic procurement has a peculiar feature: thousands of firms register, prepare bids, show up auction after auction, and never win." | "The empirical literature on cartel detection has converged on methods that read collusion off the distribution of submitted bids…" — opens on the bid-layer assumption rather than on a Brazilian curiosity. |
| Problem statement | Implicit. | Explicit: bid-distribution methods become inoperative in the layer that survives. |
| Theory paragraph | One paragraph at the end, four lines: framework as "organizing device, not identification". | Promoted to second-block paragraph with two specific results: (i) $\Pr(\text{win}\mid C)=0$ as a separating choice; (ii) $\log(1+\text{tc})$ as a sufficient ranking statistic under MLR-Poisson. The framework does conceptual work, not fake identification. |
| Sign-reversal | "The two estimates answer different empirical questions about the same population." Triage justification. | "The empirical signature of a screening-value object rather than a treatment-effect object: the overlap restriction strips the endogenous sorting that, under the framework, generates the screen's economic content." Theoretical justification for the headline choice. |
| Validation framing | "Adjudicated cobidder firms" — language is correct but undefended. | "Cobidders are the structurally appropriate validation object under coarsened observability: the award-record envelope cannot adjudicate cartel membership, and participation alongside adjudicated cartel members is the label that the screening statistic is designed to recover." |
| Buyer-size heterogeneity | "Consistent with thinner institutional capacity at smaller buyers." | "Heterogeneity in the detection regime that we interpret as scope information rather than as identification of the institutional channel." JLEO vocabulary. |
| Contribution paragraph | Triage → integrates with bid-distribution methods. | Three-literature positioning (Bajari–Ye / bid-distribution / retrospective cover-bidding) + the new architectural claim about screening-vs-forensic stages. |
| "What this paper does and does not do" | Eight items disclaiming various overclaims. | Three positive claims (participation primitive carries collusion-relevant information that survives coarsening; screening-value interpretation makes the sign reversal diagnostic; construct discriminates the structurally appropriate cartel-adjacency object) followed by three negative claims condensed into one sentence. The disclaimers serve the new framing rather than apologize for it. |
| Roadmap | Generic four-block. | Tied to the new architecture: §6 results subsection treats the sign reversal as the screening-value-vs-treatment-effect distinction; §10 (new) develops the screening-vs-forensic-stage separation. |

---

## 4. Title

| Before | After |
|---|---|
| *Frequent Losers: A Participation-Based Screen for Public Procurement* | *Screening Under Incomplete Observability: Equilibrium Loser-Side Participation as an Award-Layer Signal of Cartel Activity* |

The new title front-loads the conceptual contribution (screening under incomplete observability) and the mechanism (equilibrium loser-side participation), with cartel activity as the substantive object. "Award-layer signal" places the paper in the data-layer architecture without using "procurement" or "triage" in the title at all. The "Public Procurement" emphasis is now an empirical-application detail, not the title's identity.

---

## 5. Keywords

| Before | After |
|---|---|
| frequent losers, participation-based screen, public procurement, cartel adjacency, triage, separating equilibrium | screening under incomplete observability, cover bidding, cartel adjacency, award-layer enforcement, separating equilibrium, participation-based statistics |

"Triage" and "public procurement" out; "screening under incomplete observability", "cover bidding", "award-layer enforcement" in.

---

## 6. Unresolved risks

### R1. The intro grew from 573 to 1,006 words.
The JLEO frame requires more conceptual work in the opening. We accept the length cost; subsequent sections compress accordingly in PART 3. If the editor sets a hard length limit, the easiest cuts are (i) collapse the validation paragraph into one sentence and forward-reference §6, and (ii) collapse the contribution paragraph by dropping the three-literature catalogue and forward-referencing §2.

### R2. The screening-value interpretation is non-standard.
Some referees will ask why the broad-sample estimate is informative if the overlap-restricted estimate reverses sign. The intro now answers this conceptually (the overlap restriction strips the sorting that generates the signal), but a hostile referee may still read this as defending an apparent failure of identification. Three mitigations: (i) the framework's separating equilibrium provides a model-based reason for the sorting; (ii) the cartel-adjacency validation is independent of the broad-sample price coefficient and corroborates the screening-value interpretation; (iii) we make no causal-effect claim, so the standard treatment-effect identification objection does not bite.

### R3. The framework now does heavier conceptual work.
A referee reading Online Appendix~A may find the framework's results too thin to support the framing weight they now carry in the intro. The lemma and proposition are technically correct but minimalist. PART 3 should consider whether to expand the framework section or to keep it tight; the latter is preferable if the empirical content can carry the conceptual claim, which we believe it can.

### R4. The buyer-size heterogeneity reframing.
"Heterogeneity in the detection regime" is more JLEO-ish than "thinner institutional capacity", but it is also more abstract and harder to interpret. A referee may read the new framing as evasive. The exposition in §6.3 (PART 3) needs to do the work of making the new vocabulary concrete without slipping back into the procurement-administration register.

### R5. Cartel adjacency as the validation object.
The intro now defends cobidders as the structurally appropriate validation object under coarsened observability. This is a strong claim and a referee may push back: why is cartel adjacency the right object rather than membership? The model-based answer is that the screening statistic is *designed* to recover loser-side participation, and the loser side is precisely the cobidder population. The empirical answer is that direct-defendant AUC is $\valAUCdirectStd$ — the asymmetry is the design. Both answers are in the intro; the question is whether they are crisp enough.

### R6. Procurement still appears as the empirical application throughout the body.
The body sections have not yet been reframed. A referee reading §3–§9 of the current paper will see the old triage register reasserting itself. PART 3 must propagate the JLEO frame through the body or the new intro will read as a marketing statement disconnected from the rest of the paper.

### R7. The contribution claim about screening-vs-forensic stages requires §10 to actually exist.
Currently §10 (the new "Screening vs Forensic Stages" section) is in the editorial map but not yet written. If PART 3 does not deliver this section, the abstract and intro promise architecture that the body does not deliver. This is the highest-priority follow-through item.

---

## 7. What was deliberately preserved

- The numerical anchors of the abstract (sample sizes, headline range, ATTs, AUCs, gradient ratio, validation CI) — all macro-bound and unchanged.
- The empirical claim itself; the reframe is interpretive, not numerical.
- The cartel-adjacency-not-membership discipline.
- The asymmetry between cobidder and direct-defendant AUC as the design's signature.
- The integration-not-replacement positioning against bid-distribution methods.
- The disclosure of failed RDD/DiD designs (now in the body's roadmap).

---

## 8. PART 3 follow-through checklist

When authorized:

1. Reframe §2 (Related Literature) to add the enforcement-with-incomplete-information pillar.
2. Promote Lemma + Proposition out of Appendix A into a new main §3 ("Theory and Operationalization").
3. Restructure §7 Results to put the horse race first, the sign reversal as conceptual centerpiece (§7.2), and the buyer-size heterogeneity as detection-regime variation (§7.3).
4. Write the new §10 "Screening vs Forensic Stages" using the Imhof–Wallimann comparison.
5. Reframe §6 Validation opening to defend cartel adjacency as the structurally appropriate object under coarsened observability.
6. Rewrite §11 Limitations and §12 Conclusion in the JLEO register.
7. Close the reproducibility gaps catalogued in `JLEO_EDITORIAL_MAP.md` §5.

---

*End of memo. Awaiting authorization for PART 3 (body sections + theory promotion).*
