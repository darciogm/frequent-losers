# 29 — SUBPROMPT 10 COMPLETION REPORT: Cost-recall frontier & sequential gatekeeping (JLEO R&R v22)

Date: 2026-06-03. Branch `v22`. Method: lead diagnosis + 1 empirical agent (frontier build) + lead cost-wedge memo + 2 writers (§6B, Appendix G) + lead intro reframe.

| # | Item | Result |
|---|---|---|
| 1 | Sub9 compression complete? | YES (36pp main; now 38pp with Table 6 + Fig 3). |
| 2 | Candidate pools | Pool A complete-Imhof 16,772/190 (main); B all always-losers (award-only); D case-grouped (holdout). |
| 3 | Ranking rules | award-only, bid-only full-obs, joint full-obs, sequential award→bid, award→combined, FL→bid, random (opportunity-adjusted award skipped — not deployable). |
| 4 | K1 grid | 250, 500, 1000, 1500, 2000, 3000, 5000, 7500, full. |
| 5 | Final k grid | 100, 250, 500, 1000. |
| 6 | Cost denominators | firms / survivor-firm-tender-items / opened tender-items / opened bid rows full-tender / survivor bid rows (lower bound) / buyer×item-group×year cells / buyers / item-groups. |
| 7 | Denominators unavailable | LANCES exports (assumed 1 tender-item=1 export), legal/subpoena requests, monetary cost. |
| 8 | Bid-row & tender-item costs measured? | **YES** — the key denominators. |
| 9 | Analyst-hour proxies? | Illustrative only (Appendix G; α·tender-items + β·bid-rows/1000, low/med/high), never measured. |
| 10 | Main frontier result | At K1=2000 (k=1000): recall 0.668, firm reduction 88%, **bid-row reduction 33%**. Sequential peaks ~K1=3000 (recall 0.52 @k500 = joint, ~24% bid-row reduction); never beats joint full-obs. |
| 11 | K1=2000 representative? | **One operating point, not an optimum** — frontier is non-monotone; agencies choose by capacity. |
| 12 | Award-only baseline | Recall 0.34 @k500 / 0.50 @k1000 at ZERO bid-recovery cost; award-survivor recall already 0.78 @K1=2000. |
| 13 | Random baseline | Recall 0.10 @K1=2000; sequential 3–12× above the random ceiling. |
| 14 | Bid-only full-obs | Recall 0.35 @k500 / 0.52 @k1000 (requires whole-pool recovery). |
| 15 | Joint full-obs | **Upper bound:** 0.52 @k500 / 0.78 @k1000. |
| 16 | Sequential rule | Preserves much of joint recall while cutting forensic scope; the bid rerank reorders the survivor pool (doesn't find new positives). |
| 17 | False positives / missed | @K1=2000,k=500: 1,852 non-cobidders opened for recovery; 42 positives lost at the gate; 409 non-labeled in top-500; 99/190 missed; precision ~0.18. |
| 18 | Timing gatekeeper | Award-only strict 2009-16 AUC 0.73; **sequential strict-timing BLOCKED** (bid features not time-limitable) — disclosed. |
| 19 | Case-holdout gatekeeper | **Case-fragile:** leave-largest-case-out recall 0.48→0.34 (one case = 55% of positives). |
| 20 | Tables created | Main Table 6; Appendix G: denominator definitions, full grid (slice), baselines, operating points, case-holdout. |
| 21 | Figures created | Main Fig 3 (cost-recall frontier); Appendix: cost-recall-by-tender-items, cost-per-TP, false-positive frontier. |
| 22 | §6B edits | Rewritten "Sequential Gatekeeping and the Cost-Recall Frontier"; old single-point table deleted; intro reframed 83%→frontier. |
| 23 | Appendix G edits | G.1–G.11 (pools, rules, denominators, full grid, baselines, timing, case-holdout, operating points, algorithm, limitations). |
| 24 | Claims softened/removed | "83% reduction" universal → frontier; "optimal" → "no universal optimum"; combined = upper bound; analyst-hours illustrative. critical=0. |
| 25 | Build | **PASS** — paper 38pp, appendix 49pp; 0 errors, 0 undefined refs, 0 undefined control sequences; 6 main tables / 3 main figures (at budget). |
| 26 | Remaining blockers | Sequential strict-timing blocked; NOT_OBSERVED denominators; case-fragility; appendix 49pp; B3; conservative-AUC. |
| 27 | Cost-of-evidence claim JLEO-defensible? | **YES, honestly bounded** — see verdict. |

## STEP 25 — VERDICT

**VERDICT B — CREDIBLE BUT K1/DENOMINATOR-SENSITIVE.**

> *The sequential architecture traces a genuine cost-recall frontier: across the full K1 grid it preserves much of the adjudication-anchored recall of full bid-layer scoring while reducing the bid-recovery footprint, and it dominates a random survivor baseline 3–12×. But the saving is honest about its denominator — large in firms opened (≈88% at K1=2000), far smaller in tender-items and bid rows (≈33%), because survivors are high-participation firms whose tender-items account for a disproportionate share of bid rows. At a fixed survivor pool the bid rerank reorders rather than discovers (award-survivor recall ≈0.78), the rule never beats the full-observability upper bound, and recall is case-fragile (leave-largest-case-out 0.48→0.34). The contribution is the frontier and the denominator transparency, not a calibrated optimum: K1=2000 is one operating point, and agencies of different capacity would choose different ones.*

NOT Verdict A (the multi-denominator reduction is not uniformly strong; bid-row reduction is modest). Clearly above C/D (the frontier is real, multi-denominator, and beats random across the whole K1 grid — not a single point). The referee's "83% is mechanically firm-level" objection is conceded and turned into the paper's transparency contribution.

## Honesty ledger respected
No invented cost data. Firm-vs-bid-row divergence reported as the core caveat, not hidden. Analyst-hours illustrative-only. Sequential never beats joint (upper bound). Bid-rerank marginal value (reordering, not discovery) disclosed. Case-fragility reported. K1=2000 = one operating point. Cost = processing footprint, not monetary/measured.

## Recommended next
**Subprompt 11 — Section 7: Price, Legal Scope, and Strategic Adaptation** (price = scope only — already compressed in Sub9; verify theater-not-identified + no damages/overcharge/causal). Then Appendix B exit/survival (script 81 not built), final JLEO compliance audit (double-spacing, JEL, Bluebook, alt-text completeness).
