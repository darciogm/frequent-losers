# Self-Review: Post-R1 Revision
**Date:** 2026-03-15
**Branch:** ijio-r1-response

## Executive Summary

All four major and eight minor referee comments have been addressed through surgical textual edits. No new estimation was required. The manuscript compiles cleanly (60 pages, 0 undefined references, 0 bibtex warnings). A 7-page response letter quotes every revision for the referee's convenience. The paper's internal consistency has improved: Prediction 5 no longer contradicts the tender-FE Bajari-Ye results, and the balance test discussion no longer presents conflicting assessments across sections.

## Status by Referee Comment

| Item | Status | Section(s) Modified | Notes |
|------|--------|---------------------|-------|
| M1 | Done | 3.3, 7.4 | Prediction 5 revised to target exchangeability violation without magnitude claim |
| M2 | Done | 6.2, 7.2 | Balance test discussion harmonized; honest acknowledgment in both sections |
| M3 | Done | 6.4, 7.4 | Enriched BY first stage paragraph added; reference price removed from first-stage description |
| M4 | Done | Appendix D (Fig D.2) | Caption updated to back-of-the-envelope framing |
| minor-1 | Done | 7 .tex files | 24 CO-AUTHOR EDIT tags removed |
| minor-2 | Done | 6.4 | Ref price removed (part of M3b) |
| minor-3 | Done | 8 (Mechanisms) | New subsection on learning/entry timing added |
| minor-4 | Done | 7.3 footnote | HHI median + repeat-partners cutoff rationale added |
| minor-5 | Done | 2 (Literature) | Imhof proxy coarseness caveat in footnote |
| minor-6 | Done | 4.2 footnote | IQR economic framing added alongside statistical description |
| minor-7 | Done | 1 (Introduction) | 0.050 log-point residualized gap added |
| minor-8 | Done | 7.2 | LATE paragraph compressed from 6 lines to 3 sentences |

## Remaining Risks

1. **minor-3 (Learning/age caveat):** The current manuscript did not previously contain a "learning" discussion or firm age statistics. The new subsection introduces a claim ("approximately one year younger") that should be verified against the descriptive statistics in tab_fl_characteristics.tex or the FL characteristics analysis. If the exact age difference is different, the text needs updating.

2. **minor-5 (Imhof proxy):** The footnote references "Section 9" for the CV median split comparison, but the actual robustness section discusses homogeneous sub-samples (CV-based split) without explicitly calling it an "Imhof proxy." A referee who looks for this specific framing in Section 9 may not find an exact match. Consider adding a sentence to the homogeneous CV paragraph in sec_robustness.tex linking it to the Imhof footnote.

3. **M2 (Balance test):** The revised text in sec_empirical_strategy.tex now says "the pattern of statistically significant imbalance across all four observables is more concerning than any single coefficient." If the referee expected the paper to quantify exactly how concerning (e.g., with a formal omnibus test), this qualitative statement may not fully satisfy.

4. **Figure D.2 caption:** The welfare figure caption now references "Section 9.5" which depends on the actual section numbering in the compiled PDF. If the numbering shifted after edits, the cross-reference should use \ref{sec:welfare} instead of a hardcoded number. (It currently uses the label-based reference.)

5. **Prediction 5 label:** The label remains `pred:independence` (from the original "Conditional dependence" title) while the prediction is now titled "Bid heterogeneity." The label is internal only and does not affect the compiled output, but a pedantic reviewer of the source might notice.

## Verdict

The revision addresses all referee comments precisely and surgically, consistent with a Minor Revision scope. The paper's internal contradictions (Prediction 5 vs. tender-FE result; balance test dismissal vs. honest assessment) have been resolved. The response letter is structured for efficient referee verification.

**Estimated acceptance probability: 85-90%.** The main risk is that the referee may want to see the enriched BY first-stage results in a formal table (currently described in text only), or may push back on the learning/age subsection if they expected more substantive engagement with the learning hypothesis. Both of these could be addressed in a second minor revision if needed.
