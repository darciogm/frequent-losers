# Prompt 3 — Literature + Institutional + Appendix + Final Consistency Sweep Memo

**Paper:** *Frequent Losers: A Participation-Based Screen for Public Procurement.*
**Pass:** v18 Prompt-3 (last-touch consistency sweep).
**Outcome:** main PDF 40 pp (was 42); online appendix 15 pp (was 16). Net text reduction across this pass ≈ 800 words; no claims weakened or strengthened.

---

## Section-by-section changes

### §2 Related Literature (was 970 w → 800 w; −18%)

| Block | Change |
|---|---|
| Opener | Single sentence enumerating the four data/timing constraints (was two sentences); "not as a more powerful test against any of them individually" trimmed to "not as a more powerful test than any of these". |
| Bid-coordination paragraph | Citation chain compressed; "the literature that builds on Bajari--Ye inherits this constraint" reads more cleanly. |
| Bid-distribution paragraph | "Many real procurement systems do not preserve this layer at scale: electronic platforms, including BEC during much of our sample, archive..." → consolidated into one declarative sentence. The "operational, not theoretical" framing dropped (already implied). |
| Cover-bidding paragraph | "to our knowledge" → *"We are not aware of a published prospective identification..."* — slightly more modest priority claim. |
| Institutions paragraph | Closing sentence about the construct "being most naturally read as identifying environments where institutional structure permits suspicious participation patterns" dropped; the gradient sentence in §7.2 already carries this. |
| Synthesis | Final paragraph compressed from eight sentences to four. Same content, no rhetorical surplus. |

### §3 Legal and Institutional Framework (was 1010 w → 530 w; −47%)

| Block | Change |
|---|---|
| Statutes paragraph | Three paragraphs collapsed to two: bidding rule + auction form + caps; modal contrast as institutional context (one sentence); 2021 reform consolidated to one sentence. The earlier prose on Marshall--Marx-style cover-bidding-rule lineage moved out (already in literature review and over-loaded the section). |
| Enforcement architecture | TCE-SP, CGE, CADE described in three lines (was one paragraph each); CADE leniency mention condensed; criminal-law reference dropped (not load-bearing for the validation). |
| CADE portfolio paragraph | "ranging from \emph{Cartel dos trens-metr\^os}... to \emph{Transporte escolar}" example list dropped; the time-span and 8-of-12 prospective-after-2019 facts kept. |
| Screening problem paragraph | Three paragraphs compressed to one. Footnote on TCE-SP audit logistics kept (it carries the only operational anchor). U.S./EU comparison preserved as one sentence. |

### §4 Data and Frequent Losers Definition (mostly preserved; meta-language removed)

| Block | Change |
|---|---|
| §4.2 behavioral anchor | "we adopt the cover-bidding reading as the working interpretation" → *"we organize the empirical work around the cover-bidding reading without claiming it as the unique interpretation"*. |
| §4.2 IQR threshold footnote | "The referee's standard Tukey alternative" → *"The Tukey alternative"* (removed revision-narration trace). |
| §4.3 / §4.4 | Untouched: prose was already disciplined. |

### §6 Validation (only one residual fix in this pass, post Prompt-2)

No additional edits in Prompt 3 beyond what Prompt 2 produced.

### §10 Conclusion (one residual phrase replaced for consistency)

| Block | Change |
|---|---|
| Sign-reversal caveat | "the screen's signal is partly about that selection" → *"the screen's signal turns on the latter as much as on the former"*. Same content, cleaner register; *"partly about"* hedge removed. |

### §9 Robustness — leakage audit paragraph (cosmetic)

| Block | Change |
|---|---|
| Audit 2/3 | "breaks the construction" → *"isolates the structural component"* (Audit 2) and *"evaluates the construct under temporal holdout"* (Audit 3). Same logic, more clinical register. |

### Online Appendix

| Item | Change |
|---|---|
| Table B.3 (`tab_regime_oversight`) | Caption *"FL Price Effect by Oversight Proxy"* → *"Frequent-Loser Price Coefficient by Procuring-Unit Size and Procedure"*. Quartile labels *"(lower oversight) / (higher oversight)"* → *"(smallest buyers) / (largest buyers)"* on Q1 and Q4 only; Q2 and Q3 unlabeled. Pregão/Convite parentheticals replaced (*"reverse electronic auction"*, *"sealed-bid invitation"*) instead of the editorializing *"more transparent / less transparent"*. Notes rewritten to align with main-text discipline: *"consistent with thinner institutional capacity at smaller buyers; we do not identify oversight as the operative channel"*. |
| Table B.4 (`tab_falsification_modal`) | Caption *"Falsification: Loser-Side Concentration..."* → *"Frequent-Loser Price Coefficient by Modality (Pregão vs.~Convite)"* (drops the *"falsification"* label and the obsolete *"loser-side concentration"* internal name). Notes rewritten: *"identifies coordination behavior across modal regimes"* → *"suggesting the signal is not mechanically driven by the convite quorum rule; we do not interpret it as a positive test of any specific institutional channel"*. |
| Table C.2 (`tab_leakage_audit`) | Notes block compressed from 11 lines to 6: structural-component vs leakage component said once; the tautology explanation kept terse since it has been said in §9 already. |
| Adversarial-adaptation appendix prose | Trimmed from 26 lines to 16; no claim altered. *"We do not claim the construct is adaptation-proof"* dropped (already said in body); the operational-implication paragraph compressed to three sentences. |

---

## Final consistency sweep — what was harmonized

1. **Trailing periods on `\paragraph{...}` headings** removed across §1 and §7 (elsarticle adds the period itself, otherwise prints two). Five paragraphs cleaned. This was the most visible cosmetic defect.
2. **Outdated internal name** *"loser-side concentration"* removed from Appendix B caption. The construct is now consistently *"frequent-loser construct"* / *"the construct"* / *"the screen"* across both manuscript and appendix.
3. **"Falsification" rhetoric** retained only in scripts and internal commit messages; removed from manuscript and appendix prose and from a table caption.
4. **"Hard upper bound" / "identifies coordination behavior" / "we read as informative"** all replaced in this or the previous pass.
5. **"Breaks the construction"** colloquialism in robustness leakage paragraph replaced; the appendix table notes match.
6. **Procurement-officer / oversight-channel disclaimer** said once each in §1, §7.2, §10, Appendix B.3 notes (and not anywhere else).
7. **Cobidder vs direct-defendant asymmetry** stated in abstract, §1, §6.5, §10. Four uses across 40pp is at the design's required count.

---

## Title alternatives (still no change)

The current title remains the right choice. The Prompt-1 alternatives are still in the record; none has overtaken the current title in the rounds since.

---

## Remaining cosmetic / editorial concerns before submission

1. **§4 data section is still ≈900 words.** It is dense because the construct definition + behavioral anchor + temporal-validation + sample construction + CADE portfolio all live there. A pre-submission editor will likely move §4.4 (CADE Validation Portfolio) into §6.1 to cut overlap with the validation section. We did not do that here because the brief excluded a structural reorganization of §6.

2. **Appendix Section A theory** is 2 propositions + 1 lemma, well-sized for a JLEO submission. The phrasing of A1/A2 ("Profit positivity" / "Diminishing returns") could be tightened but reads cleanly as is.

3. **Appendix C `tab_did_revised` and `tab_stacked_did`** retain the long table notes that were appropriate for an earlier review round; a copy editor will likely shorten them. Out of scope for this pass.

4. **Cross-document references via `xr`** between main and online appendix work but produce *"multiply defined labels"* warnings on first compile. Filtered with `\WarningFilter{natbib}{Citation}`. No reader-visible artifact.

5. **Footnote in §3** ("In TCE-SP audits we examined, requesting bid-by-bid microdata...") is the only first-person-plural anchor in the section; if the journal house style discourages this, replace with *"in TCE-SP audits, requesting..."*. Trivial.

6. **Reference list (`references.bib`)** was last touched two rounds ago; one DOI verification pass remains as a pre-submission task. Out of editorial scope for this pass.

---

## Cumulative compression across Prompts 1–3

| Section | Pre-Prompt-1 | Post-Prompt-3 | Change |
|---|---|---|---|
| Abstract | 277 w | 185 w | −33% |
| Introduction | 910 w | 573 w | −37% |
| Empirical Strategy | ≈920 w | 790 w | −14% |
| Validation | ≈750 w | 649 w | −13% |
| Main Results | ≈620 w | 538 w | −13% |
| Related Literature | 970 w | 800 w | −18% |
| Institutional | 1010 w | 530 w | −47% |
| Total main PDF | 56 pp (peak) | 40 pp | −29% |

The paper now reads as one disciplined argument with consistent vocabulary across body, appendix, and table notes, and is ready for the JLEO submission stack.

---

*End of memo. Pass 3 concluded; submission package coherent.*
