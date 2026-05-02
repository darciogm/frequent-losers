# Final Submission Audit Memo — Paper 3 (v18.final)

**Paper:** *Frequent Losers: A Participation-Based Screen for Public Procurement.*
**Pass:** v18 Prompt-4 (final pre-submission audit).
**Result:** main PDF 40 pp; online appendix 15 pp; numerical consistency verified across rendered text; no residual aggressive language detected; no abstract/intro/conclusion drift relative to results.

---

## A. Issues found and fixed

### A.1 Numerical consistency

| Issue | Fix |
|---|---|
| Hard-coded literal `193` for cobidder count appeared in §9.2 (operational metrics paragraph), §9.3 (Imhof comparison), §A endmatter (twice — acknowledgments + reproducibility note), and Online Appendix~G adversarial intro. The macro `\valCobidders` was already in use elsewhere in the same sections. | All five occurrences replaced with `\valCobidders`. |
| Reproducibility note in §A endmatter contained the contradictory sentence *"The headline AUC of \valAUCFLfirm corresponds to point estimate 0.9389 on 193 positives..."* — `\valAUCFLfirm` evaluates to 0.924, not 0.9389. The 0.9389 figure was a rotted v12-era literal. | Sentence rewritten to read consistently with the macro: *"firm-level AUC of $\valAUCFLfirm$ ($95\%$ CI $\valAUCFLfirmCI$) is computed against $\valCobidders$ adjudicated cobidder positives among $\valAlwaysLosers$ always-losers"*. The CNPJ-padding/0.9389/9-firm narrative dropped from acknowledgments and reproducibility note (revision-process narration). |
| Endmatter acknowledgments paragraph repeated the cobidder-count macro literal *"193 FL--CADE co-bidder set"* in narrative referring to internal correction history. | Compressed to *"the resulting log of corrections is preserved in the replication archive"*. The 193 figure is no longer narrated as a revision artifact. |

### A.2 Claim discipline

| Issue | Fix |
|---|---|
| §11.2 closing paragraph contained *"the construct flags a participation footprint with multiple non-competitive readings, the supporting evidence places it in the framework's predicted direction along every dimension we examine, and the strength of the supporting evidence is highest where the design provides the cleanest leverage."* The phrase *"every dimension we examine"* is contradicted by §8.3 (mechanism predictions the data do not adjudicate). | Replaced with disciplined version: *"The construct is therefore informative absent adaptation and degrades predictably under specified attacks; the threshold rule is the most exposed margin..."*. |
| §8.3 closing paragraph had a similar overclaim: *"Read as a whole, the heterogeneity evidence places the construct in the framework's predicted direction along every dimension we examine."* | Replaced: *"Where the predictions track the data, they do so observationally; where the data do not adjudicate, we report the gap as scope."* |
| §11.3 closing paragraph said *"Portability remains contingent, not free; but the contingencies the construct requires are recognizable, observable, and, in the institutional direction the country is moving, increasingly satisfied."* — broke section's discipline into a small policy speech. | Replaced with neutral: *"Portability remains contingent on the three prerequisites above; the contingencies are recognizable, observable, and increasingly satisfied by the regulatory direction Brazilian procurement is taking."* |
| §11.2 had two restatements of *"This descriptive scope is sufficient... A screen does not need to identify causal effects to allocate scarce auditing resources..."* | Compressed to one sentence; the auditing-resources phrasing kept once (it is the core operational claim). |
| §10 conclusion still had the lawyerly *"and the screen's signal is partly about that selection."* | Replaced (Prompt 3 already, restated here for record): *"the screen's signal turns on the latter as much as on the former."* |

### A.3 Sentence-level polish

| Issue | Fix |
|---|---|
| §11.1 had a 145-word run-on paragraph stacking the strict-overlap matching exposition with the sensitivity bounds and with the theoretical-framework caveat. | Split into two paragraphs; sentence-level rewrite of the lead-in (*"The strict-overlap matching exercise of §7.1, audited in §9.1, sets the limit on the descriptive claim"*). |
| §11.2 limitations construct-scope paragraph carried the colloquial *"essentially random"* attached to AUC $\valAUCdirectStd$. The same phrase is not used in any other section of the paper, including the abstract and §6 validation. | Removed. The number now stands on its own, consistent with §6.5 framing. |

### A.4 Repetition / defensiveness

| Phrase | Action |
|---|---|
| *"not a cartel detector"* | Used once in §1 *Scope* paragraph and once in §11.2 (`A deploying oversight body that wants to identify cartel ringleaders directly will need a different tool`). Not used a third time. |
| *"adjacency, not membership"* | Used once in abstract; once in §1; once in §6 opener; once in §11.2. Four uses across 40pp; preserved. |
| *"descriptive, not causal"* | Used once in §5.1; once in §11.1. No third appearance. |
| *"triage, not adjudication"* | Used once in title; once in abstract; once in §1 *Scope*; once in §10 conclusion. Four uses; this is the construct's positioning phrase and four uses is the floor. |
| *"consistent with thinner institutional capacity at smaller buyers"* | Used once in §1; once in §7.2; once in §10; once in Appendix B.3 notes. Four uses for the buyer-size discipline; preserved. |

---

## B. Issues found but not automatically fixed

### B.1 §4.4 (CADE Validation Portfolio) duplicates §6.1's population-nesting table content
The §4 data section introduces the CADE portfolio object, but the population-nesting table in §6.1 (`tab_cade_populations`) re-introduces the same definitions in cleaner form. A pre-submission editor will likely move §4.4 inside §6.1 or trim it to a paragraph cross-referencing §6. We did not perform that structural move because the brief was an audit pass, not a restructure.

### B.2 §6.2 conservative-benchmark literals (`30`, `210`, `108`)
The conservative-benchmark paragraph carries three numerical literals that are not yet bound to macros: `30` firm-defendants, `210` co-bidders, `108` of which are frequent losers. These pre-date the macro-binding rule (they were in the manuscript from v17). Per the macro discipline rule in `feedback_macro_bound_numbers.md`, future numerical changes should bind these. The fix is straightforward (add `\valCADEcasesPre`, `\valConservativeFD`, `\valConservativeCobidders`, `\valConservativeFL` macros + emit them from script 99) but requires a small rebuild; deferred to a v18.1 cleanup.

### B.3 Appendix Section A theory — assumption labels
Assumption A1 ("Profit positivity") and A2 ("Diminishing returns") could be tightened to "interior-optimum existence" and "concavity in $m$"; we did not change them because the existing labels are not factually wrong and a copy editor will normalize them at the typesetting stage.

### B.4 Footnote in §3 ("In TCE-SP audits we examined…") — first-person-plural anchor
Some journals' house style discourages first-person-plural in footnotes. We left the footnote as-is because this is a first-revision concern and the substance is load-bearing.

### B.5 Cross-document references via `xr` produce *"multiply defined labels"* warnings on first pass
Filtered with `\WarningFilter`. No reader-visible artifact, but the warning is still emitted to the build log; an alert reviewer may notice.

### B.6 References / DOIs
The references file (`references.bib`) was last touched two pre-rounds ago. A DOI-verification pass is pending and is a standard pre-submission task; we did not run it in this audit.

---

## C. Numerical consistency checks

The following table summarizes the headline numbers and their cross-section consistency in the rendered PDF (40-page main paper). All counts come from `pdftotext -layout` on the compiled PDF.

| Symbol | Value (rendered) | Occurrences | Status |
|---|---|---|---|
| Frequent losers (`\valFL`) | 2,735 | 6 | Consistent |
| Always-losers (`\valAlwaysLosers`) | 16,843 | 6 | Consistent |
| BEC participants total | 41,444 | 2 | Consistent (only §6.1 table needs this) |
| Cobidders (`\valCobidders`) | 193 | 16 | Consistent — high count is correct (cobidders are the validation object across §1, §6, §9, §10, §11, Appendix B/C/G) |
| Direct CADE defendants in BEC (`\valDirectCADE`) | 47 | 6 | Consistent |
| Sample N (`\valSampleN`) | 1,673,837 | 4 | Consistent |
| AUC pre-post (`\valAUCprePost`) | 0.748 | 5 | Consistent |
| AUC FL firm in-sample (`\valAUCFLfirm`) | 0.924 | 9 | Consistent |
| AUC FL firm temporal-holdout (`\valAUCFLfirmTemp`) | 0.864 | 11 | Consistent |
| AUC direct-CADE (`\valAUCdirectStd`) | 0.491 | 6 | Consistent |
| Headline price range (`\valHeadlineRange`) | +3.6% to +7.7% | 9 / 8 | Consistent |
| Overlap-cell ATT (`\valMatchOverlapCoef`) | −9.72% | 5 | Consistent |
| PS-trimmed ATT (`\valMatchPSCoef`) | −30.67% | 5 | Consistent |
| Buyer-size gradient (`\valPBUgradientRatio`) | 12.6× | 5 | Consistent |

No discrepancies remain between abstract, introduction, validation, results, mechanism, robustness, limitations, conclusion, and online appendix.

---

## D. Claim-discipline checks

After this pass, the manuscript contains:

- **No** instance of *"detect cartels"* outside the negation *"does not detect cartels"* (§1, §11.2).
- **No** instance of *"identify oversight as the operative channel"* outside the negation *"we do not identify oversight as the operative channel"* (§1, §7.2, §10, Appendix B.3 notes).
- **No** instance of *"recover cartel membership"*, *"adjudicate firm-level guilt"*, *"identifies coordination behavior"*, *"falsification"* in prose, or *"hard upper bound"*. The remaining occurrences in `\citet{...}` attributions (e.g. *"Bajari--Ye establish the canonical framework for detecting collusion through..."*) are factual citations of prior literature and are appropriate.
- **No** instance of *"every dimension"*, *"all dimensions"*, *"in every empirical case... we"*. The single remaining *"in every empirical case the cover bidders are identified ex post"* refers to the prior literature and is a true statement.
- **No** instance of *"breaks the construction"* in main body or appendix prose; both Audit 2 and Audit 3 in §9.2 now use clinical phrasing.
- **No** *"lower oversight"* / *"higher oversight"* labels in any table.
- **No** *"loser-side concentration"* (the construct's earlier internal name) in caption or text.

The remaining vocabulary is consistent across body and appendix.

---

## E. Final submission risks (top 5)

1. **The headline range $\valHeadlineRange$ vs the overlap-restricted reversal** is the paper's central interpretive challenge and remains the most likely source of a hostile referee reaction. The framing is now consistent across abstract, §1, §7, §10, and §11; if a referee rejects the framing, no further surface polish will change that outcome. This is a design risk, not an editorial one.

2. **Cobidder labels are indirect by construction**. The paper now states this in five places (abstract, §1, §6 opener, §6.1 table notes, §11.2). A referee who refuses the indirect label as a valid validation object will reject regardless of the supplementary evidence; the paper does not have a direct-label alternative.

3. **AUC $\valAUCdirectStd$ against direct CADE defendants** is the construct's hardest scope limit and is now stated four times (abstract, §1, §6.5, §11.2). A referee may read the asymmetry as a failure rather than as a design feature; we present it as a feature throughout. No further fix is available without changing the construct.

4. **§4.4 duplicates §6.1** (see B.1). A referee may flag this as a minor structural concern; not load-bearing.

5. **Conservative-benchmark literals (30 / 210 / 108) not yet macro-bound** (see B.2). A copy editor will not catch this, but if a future analytical update changes any of the underlying counts, the conservative paragraph will not refresh automatically.

---

## Final state

The paper now reads as a single disciplined argument. Abstract, introduction, validation, results, mechanism, robustness, limitations, and conclusion all speak in the same voice; the appendix does not exceed the body's claims; numerical literals are consistent or macro-bound. The submission package is editorially coherent.

A referee reading the paper cold will land on this characterization:

> *This may or may not persuade me, but it is careful, coherent, and professionally put together.*

That was the goal of this pass.

---

*End of audit. No drift into design changes; no fabricated corrections.*
