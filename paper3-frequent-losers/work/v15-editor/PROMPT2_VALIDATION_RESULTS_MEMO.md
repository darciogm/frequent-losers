# Prompt 2 — Validation + Results + Core Narrative Tightening Memo

**Paper:** *Frequent Losers: A Participation-Based Screen for Public Procurement.*
**Pass:** v18 Prompt-2 (core narrative only).
**Sections edited:** §5 Empirical Strategy, §6 Validation Against CADE Adjudications, §7 Main Results.
**Word counts after edits:** §5 = 790, §6 = 649, §7 = 538 (down from roughly 880 / 750 / 620).

---

## Main tightening changes

### §5 Empirical Strategy

| Block | Change |
|---|---|
| §5.1 third paragraph (audit catalogue) | Five-line catalogue compressed to a four-item list, no per-audit gloss. The reader is oriented; details live in §9. |
| §5.1 sign-reversal language | "We read as informative about selection" → *sharpens the interpretation of selection within the always-loser stratum.* Neutral phrasing per the brief. |
| §5.2 estimator gloss | Cross-fit / CEM / IPW / IV reduced from one sentence each to a tight enumeration. The leave-one-out IV intuition kept (one line) since it is needed to read the IV column in §7. |
| §5.2 clustering paragraph | Untouched: it is already minimal. |
| §5.3 heterogeneity opening | Removed restatement that the cell grid is descriptive (already said in the opening clause). |
| §5.3 cell-heterogeneity paragraph | Untouched: it pre-stages §8.2 and any further compression would force a forward-reference loop. |

### §6 Validation Against CADE Adjudications

| Block | Change |
|---|---|
| Opening | "The validation asks whether the construct discriminates populations of firms with a higher prior probability of cartel adjacency than random selection. It does not speak to firm-level membership. The labels we use are indirect by construction." → two-sentence opener that lands the same scope claim without echoing the introduction. |
| Population table notes | Cleaner parallel "Definition and role" entries; participation-alongside disclaimer compressed. |
| §6.2 conservative benchmark | The "30 firm-defendants, all matching BEC. Always-losers co-bidding with at least one number 210" sentence (which had a broken parse) rewritten as: *"$30$ firm-defendants, all active in BEC, with $210$ always-losers co-bidding with at least one of them, of which $108$ are frequent losers."* The reader now learns immediately what the 210/108 numbers refer to. |
| §6.2 second paragraph | Compressed to two sentences. *"This is the benchmark we treat as primary"* moved to active voice with the rationale ("uses no information from cases adjudicated post-sample and the labels predate estimation"). |
| §6.3 prospective benchmark | "We report it as complementary, not as the headline" → *"we report it as complementary to the conservative anchor"*. Less argumentative. |
| §6.3 within-firm closing | "These three firms are direct defendants who happen to share the always-loser footprint" → *"the exception within a direct-defendant population that is otherwise frequent-winner-heavy"*. |
| §6.5 closing interpretation | Restructured into a single sentence listing four pieces of evidence. *"places a hard upper bound on broader detection claims outside the always-loser stratum"* → *"delimits its scope"*. Same content, less rhetoric. |

### §7 Main Results

| Block | Change |
|---|---|
| Opening | Two-sentence opener replaces three-sentence one; "we treat the reversal as central rather than as a robustness check" dropped (already established in §1 and §6 opener). |
| Pregão–convite paragraph | Reframed as *evidence the signal is not reducible to the quorum rule*, with explicit disclaimer that we do not interpret the asymmetry as a positive test of any specific institutional channel. The phrase "falsification" / "does not generate the gap" was strong-leaning relative to the rest of the paper; replaced with descriptive phrasing. |
| Sign-reversal paragraph | Same logic, compressed. *"Within overlap cells, the price comparison runs the opposite way, which likely reflects the unobserved features that drive entry into the selected cells"* → dropped (the previous sentence already says it). |
| Headline-justification paragraph | "We report the broad-sample $\valHeadlineRange$ as the headline because it maps to the deployment question---which environments to flag---and a triage tool sees the population frequent losers do select into, not a counterfactual matched on observables. The within-cell coefficient answers a different question and is reported in parallel, not in opposition." → compressed to: *"The two estimates answer different empirical questions about the same population. We treat the broad-sample $\valHeadlineRange$ as the headline because triage operates on the population frequent losers select into, and report the overlap-restricted coefficient alongside as the corresponding within-support comparison."* The "in parallel, not in opposition" framing was lawyerly and redundant. |
| §7.2 buyer-size heterogeneity opener | "steep, monotonic gradient" → "monotonic gradient". Removed *"larger than the pregão--convite gap"* — true but rhetorical. |
| §7.2 mechanism interpretation paragraph | "Identifying that channel would require variation in oversight plausibly orthogonal to the other correlated features---a research design we do not have" → dropped. The remaining sentence ("none can be separated with the variation we have") carries the load without sounding defensive. The closing sentence kept the *"operational implication is robust to the mechanism reading, the mechanism reading itself is not"* contrast — it is the cleanest one-line statement of the section's discipline. |

---

## Wording deliberately softened

- "Hard upper bound" → "delimits its scope" (§6.5).
- "Falsification" / "does not generate the gap" → "not reducible to the quorum rule" (§7.1).
- "Steep, monotonic gradient" → "monotonic gradient" (§7.2).
- "We read as informative" → "sharpens the interpretation" (§5.1).
- "We report it as complementary, not as the headline" → "we report it as complementary to the conservative anchor" (§6.3).

---

## Wording deliberately preserved

- *"Cartel adjacency, not membership"* — used once, in §6 opening; not repeated.
- *"Triage operates on the population frequent losers select into"* — used once, in §7.1; once in abstract; once in §1 interpretive challenge. Three uses across the paper for the same idea is at the upper limit; further compression risks losing the headline-justification logic.
- *"Consistent with thinner institutional capacity at smaller buyers"* — kept as the most economical formulation; used in §7.2 closing.
- The sentence about "AUC $\valAUCdirectStd$ against direct CADE defendants in the broader BEC firm universe" is now stated once in the abstract, once in §1 (Three findings), and once in §6.5. This is the design's central asymmetry; three statements is correct.

---

## Remaining vulnerabilities in the edited sections

1. **§6.2 conservative benchmark still leans on the 4-case / 30-defendant / 210-cobidder / 108-frequent-loser stack.** The numbers are accurate but dense. Light table presentation could replace the prose, but the brief said "do not redesign", so I left the prose form. A future pass could replace the second paragraph with a small pop-out table.

2. **§7.1 IV gloss "the direction expected under classical attenuation when the binary indicator proxies for an underlying continuous loss-intensity statistic"** is concise but assumes the reader recalls the §5.2 framing. If a referee skims §7 standalone the line will read tautologically.

3. **§7.2 buyer-size paragraph still ends with the *"operational implication is robust... the mechanism reading itself is not"* contrast.** I kept it because it is the section's tightest disciplinary statement, but a reader can read it as "the policy claim survives without identification" — which is true but politically charged. Consider moving to §10 conclusion if a referee flags it.

4. **§5.1 design-based-strategies paragraph** still opens with "Two design-based strategies that would extract a causal estimate return null and are reported as such." This sentence is necessary (signals discipline) but slightly defensive. Could be replaced by an even more direct opener but at risk of sounding dismissive of the diagnostics.

---

## Sentence-level problems noticed elsewhere but **not edited** (per brief)

- **§9.2 Robustness — leakage audit paragraph** still uses the formulation *"Audit~3 breaks the construction temporally"*. "Breaks" is colloquial. Consider *"Audit~3 evaluates the construct under temporal holdout"*.
- **§10 Conclusion** has the line *"the screen's signal is partly about that selection"* — *"partly about"* is the same lawyerly phrasing the brief asked us to remove from §1 and §7. This Pass-2 brief explicitly excluded the conclusion, so left untouched. Flag for Prompt 3 (or the polish pass that covers conclusion).
- **§11 Limitations**, §11.2 — opening sentence reads *"The most informative single observation about the limits of the descriptive claim..."* This is heavy. Mark for the limitations-pass round if it comes.
- **Online Appendix~G adversarial-adaptation table** uses the percent-sign-as-symbol convention. We patched this for compile but a journal copy editor will likely change formatting again. Not load-bearing.

---

## Style audit on edited sections

- No occurrences of "robustly", "decisively", "we caution", "it is worth noting", "we acknowledge".
- One instance of "consistent with" (kept; needed for the buyer-size gradient).
- One instance of "we do not" (kept; signals the scope of the institutional channel claim).
- No instance of "outperforms", "novel framework", "first to document".

---

*End of memo. Pass 2 concluded; no drift into title, abstract, intro, lit review, institutional background, conclusion, limitations, or appendix.*
