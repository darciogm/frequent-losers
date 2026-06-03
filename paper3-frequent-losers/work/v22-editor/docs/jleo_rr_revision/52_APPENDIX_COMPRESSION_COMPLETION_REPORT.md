# 52 — APPENDIX COMPRESSION COMPLETION REPORT (Subprompt 13B)

Date 2026-06-03. Branch `v22`. Paper *Cheap Signals, Costly Proof: The Reach and Limits of Award-Layer Screening in Cartel Enforcement*.

| # | Metric | Before | After |
|---|---|---|---|
| 1 | Appendix pages | 55 | **31** |
| 2 | Appendix lines (sum of `\input` files) | 3157 | ~1634 |
| 3 | Appendix tables | 30 | **11** |
| 4 | Appendix figures | 4 | **2** |
| 5 | Lettered appendices | 9 (A–I sprawl) | **6 (A–F)** + unnumbered roadmap |
| 6 | Subsections | 66 | ~28 |
| 7 | Tables moved to online supplement | — | 18 |
| 8 | Figures moved to online supplement | — | 2 |
| 9 | Subsections folded/moved | — | ~38 |
| 10 | Internal logs/comments removed | — | all (0 remain) |
| 11 | Affirmative forbidden-terminology hits | — | 0 (9 boundary uses, all negated) |
| 12 | Cross-reference status | — | 0 undefined, 0 dangling to moved floats |
| 13 | Numbering status | — | A.1…F.1 auto; 11/11 captioned, 9/11 with notes |
| 14 | Online-supplement manifest | — | `APPENDIX_MOVED_MANIFEST.csv` (20 rows) + 7 dirs |
| 15 | Build | — | paper 39pp / appendix 31pp, 0 err, 0 undef |
| 16 | Second compression pass needed? | — | No |

## Final architecture
- **Roadmap** (unnumbered, ≤250w).
- **A — Data, Matching, and Label Construction** (app02): A.1 screen construction, A.2 label funnel/reconciliation.
- **B — Theory, Exit Margin, and Survival Audit** (app01): Assumption B1 + Proposition B1 + Corollary B1, exit-margin λ_C>λ_G, B.1 survival summary, Fig B.1 KM curves.
- **C — Opportunity and Timing Validation** (app03): C.1 control-function (opportunity), C.2 strict holdout (timing), C.3 case dominance (LOCO); 6 threat-family subsections.
- **D — Economic Profile and Score Diagnostics** (app08): D.1 standardized differences.
- **E — Bid-Layer Benchmark and Cost-Recall Details** (app09+app06 merged): E.1 bid performance, E.2 cost denominators, E.3 cost-recall grid, Fig E.1 frontier, gatekeeping algorithm.
- **F — Price Scope and Adaptive Deployment** (app04+app05 merged): F.1 overlap-cell sign reversal; adaptive-deployment subsection.

## Fatal-threat coverage retained (each has ≥1 inline table/figure)
label construction (A.1/A.2) · opportunity exposure (C.1) · timing/leakage (C.2) · case dominance (C.3) · bid-benchmark opacity (E.1) · cost-recall frontier (E.3+Fig E.1) · price overclaim boundary (F.1) · exit-margin/theory (B.1+Prop B1).

## Items moved (full grids → online supplement)
case-timing · survival hazard/Cox · opportunity permutation · leakage decomposition · audit crosswalk · timing information-sets · timing-leakage cross-tab · clustered-RI · direct-defendant timing · profile groups · negative controls · broad price grid · high-value segment grid · adaptation summary · bid units/support · bid leakage · award-bid complementarity · cost-recall case-holdout · cost-per-TP figure · false-positive figure.

## STEP 18 — VERDICT

**VERDICT A — Appendix submission-ready.**

> *The submitted appendix is 31 pages (≤35 hard max, near the 25–30 target), 11 tables, 2 figures, organized as six lettered appendices A–F plus a short roadmap. No internal logs or workflow language remain; terminology is disciplined (price = scope, not damages; ranking = forensic priority, not proof; operating point on a frontier, not "optimal"). Every fatal referee threat retains its inline anchor, full diagnostic grids are relocated to a manifested online supplement, and both the paper (39pp) and appendix (31pp) build with zero errors and zero undefined references.*

Residuals (non-blocking): two App-A construction tables lack tablenotes (cosmetic); online-supplement payload assembly is a packaging step for Subprompt 14.

## Next
**Subprompt 14 — JLEO Compliance Audit, Cover Letter, and Submission Readiness.**
