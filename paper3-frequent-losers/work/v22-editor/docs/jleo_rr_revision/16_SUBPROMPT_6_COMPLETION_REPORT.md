# 16 — SUBPROMPT 6 COMPLETION REPORT: Timing, leakage, rolling-origin, LOCO, case dominance (JLEO R&R v22)

Date: 2026-06-03. Branch `v22`. Agent: mr-frequent-losers. Method: lead diagnosis + 2 parallel empirical agents (E1 timing, E2 case/dominance) + 2 parallel writers (W1 §4.4+macros, W2 appendix), disjoint files.

| # | Item | Result |
|---|---|---|
| 1 | **Opportunity validation done first?** | YES (Subprompt 5, Verdict B). |
| 2 | **Timing information sets** | A full-retrospective, B relaxed, C strict, D rankable, E entrants, F adjudication-observable-at-time (infeasible), G prospective-score/retro-label. `timing_information_sets.md`. Year-level only (no conduct dates). |
| 3 | **Strict 2009-16→2017-19** | Within always-loser pool: FL_train AUC **0.767**, cont **0.750** (reproduces script 53; threshold_train 7 vs full 13.5). **Full candidate universe: ROC 0.55, PR-AUC 0.005, precision@500 = recall@500 = 0.** |
| 4 | **Rolling-origin 2014–2019** | precision@500 = recall@500 = 0 every year on the full universe; worst year 2015 ROC 0.497 (below chance); the year-on-year "improvement" is retrospective accumulation, not forward prediction. |
| 5 | **Entrant / score-zero ties** | **45/193 positives (23%) are entrants** (no pre-window history → score 0, unrankable); 148 rankable; tie-at-zero 25%; entrants are ~57% of top-500 misses in the active pool. Prospective use materially weakened. |
| 6 | **Leakage audit** | A leaks score+zero-win+threshold (upper bound); B leaks zero-win; C/D/G clean; F infeasible. Table F. |
| 7 | **Leave-one-case-out** | 6 linkable cases (1 too-sparse). ROC uniformly ~0.95 (uninformative at <1% prevalence); PR-AUC mean 0.039, driven by the largest case (max 0.121). |
| 8 | **Leave-largest-case-out** | **COLLAPSE: PR-AUC 0.126→0.036 (−71%), precision@500 0.130→0.040 (−69%), recall 0.342→0.233.** Top-two-out → 0.029. ROC barely moves (0.939→0.929). |
| 9 | **Case-balanced metrics** | Case-balanced precision@500 **0.029** vs firm-weighted **0.130** — pooled precision is almost entirely the one big case. |
| 10 | **Buyer/item/modality dominance** | item-group HHI 0.188 (largest 30.5%, top-5 82%; drop largest → PR-AUC 0.062); modality 96.8% Pregão; buyer diffuse (HHI 0.019, survives dropping largest buyer); drop top-2 years → 0.048. |
| 11 | **Clustered randomization inference** | Within buyer×item_group×year, B=1000. ROC p=0.001, PR-AUC p=0.015, prec@500 p=0.013, recall@500 p=0.016 — significant but **thin** (null PR-AUC already 0.101); **case-coverage breadth 6 vs 5.0, p=0.317 (NOT significant)**. |
| 12 | **Direct-defendant temporal scope** | ROC ≈ **0.49** full and strict (0.491/0.492); "not a generic direct-defendant classifier," not an escape hatch. |
| 13 | **Claims upgraded / preserved / downgraded?** | **DOWNGRADED substantially.** From "residual signal survives exposure" (Sub5 B) to "retrospective, incumbent-pool, case-sensitive triage diagnostic; not prospectively deployable platform-wide." |
| 14 | **Tables created** | Main: D-strict, E-rolling, F-leakage, G-LOCO, H-case-dominance, **I-summary**. Appendix: environment-dominance, clustered-RI, defendant-group-out, direct-defendant-timing. |
| 15 | **Figures created** | Main: rolling-origin PR-AUC (NEW Fig 2), rolling-origin precision/recall, LOCO distribution. Appendix: rolling-origin ROC, case-positive concentration, clustered-RI. |
| 16 | **Section 4.4 changes** | NEW "Timing, Leakage, and Case Composition" (8 blocks); leads with the limits; PR/precision/recall primary; ROC reframed as red herring; Fig 2 swapped ROC→PR. |
| 17 | **Appendix changes** | sec_app03 D.13–D.21 timing/case block (9 subsections, 9 tables, 3 figures). |
| 18 | **Build result** | **PASS** — paper 53pp, appendix 34pp; 0 errors, 0 undefined, 0 undefined control sequences, no overfull >30pt; claims critical=0. |
| 19 | **Remaining blockers** | Year-level timing only; 23% entrant coverage hole; 43/190 cobidders unlinked to a case; App D now very long (D.1–D.21). **Strategic: reframe decision (below).** |
| 20 | **Proceed to §5 profile work?** | YES, but §5 must be written UNDER the downgraded claim. |

## STEP 24 — DECISION RULE VERDICT

**COMPOSITE: VERDICT C (timing — mainly retrospective/incumbent-pool) + VERDICT D (case-dominance — cluster-sensitive).**

> *The award-layer ranking is informative as a retrospective, incumbent-pool triage diagnostic, but its operational performance is concentrated in one adjudicated case (trens_metros: 55% of positives, 72% of TP@500; leave-largest-case-out collapses PR-AUC by 71%) and one procurement environment (96.8% Pregão; one item-group drives half the PR-AUC). It does not support prospective, platform-wide deployment: on the realistic candidate universe, precision@500 and recall@500 are zero in every rolling-origin year, and 23% of positives are unrankable new entrants. The high ROC-AUC is a red herring — robust precisely because it is insensitive to the case concentration that the operational metrics expose.*

NOT Verdict A or B (strict prospective performance is near-random on the deployable universe). The manuscript claim is downgraded accordingly.

## ⚠ STRATEGIC DECISION REQUIRED (Darcio's call — mr-frequent recommendation)
Verdicts C+D mean the paper's implicit "deployable award-layer screen" claim is **no longer supportable**. The honest, JLEO-viable path is **(a) REFRAME the paper as a study of the LIMITS / boundary conditions of award-layer cartel screening**: cheap administrative records carry *concentrated, retrospective, case-specific* exposure signal but do **not** support prospective platform-wide triage. This is a legitimate Law-and-Economics / evidence-allocation contribution — but a more modest and more honest paper than the current framing. Alternatives: (b) salvage with cross-case breadth evidence (no data path — only 6 linkable cases, one dominant); (c) descope to a methods note. **Recommend (a).** This decision should be made before Subprompt 7 (§5), because §5's framing depends on it.

## Honesty ledger respected
No invented results. The strict-timing collapse, the entrant hole, the leave-largest-case-out collapse, the thin clustered-RI margin, and the non-significant case-coverage breadth are all reported, not buried. ROC reframed as a red herring. Cobidders never called members; no proof/detection/causal. Claim downgraded, not spun.

## Recommended next
Resolve the strategic reframe (a/b/c) with Darcio, THEN **Subprompt 7 — Section 5: Economic Profile, Monotonicity, Binary vs Continuous Score, and Ordinary-Loser Alternatives** — written under the downgraded claim (the §5 finding will likely be: cobidders are largely high-volume losers concentrated in one case, with limited distinct economic content — consistent with C+D).
