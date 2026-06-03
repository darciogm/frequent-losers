# 18 — SUBPROMPT 7 COMPLETION REPORT: Section 5 economic profile, monotonicity, binary-vs-continuous, ordinary-loser alternatives (JLEO R&R v22)

Date: 2026-06-03. Branch `v22`. Method: lead diagnosis + 2 parallel empirical agents (E1 profile/monotonicity, E2 robustness) + 2 parallel writers (W1 §5, W2 Appendix H) + 1 table-nesting fixer, disjoint files.

| # | Item | Result |
|---|---|---|
| 1 | **Section 4 deps complete?** | YES (Sub4 RECONCILED, Sub5 B, Sub6 C+D + reframe). §5 written under the reframe. |
| 2 | **Datasets** | Sub5 firm frame `firm_opportunity_adjusted_frame.csv`; firm_tender_map; item_value_panel (modality); cade_fl_cobidders (193); cade_bec_crossmatch; case_cobidder_map. |
| 3 | **Comparison groups** | A–M + H. D FL non-cobidders 2,544; E FL cobidders 191 (≡F); H direct defendants 46 (excluded from A–G, asserted). |
| 4 | **Profile variables** | Participation, breadth/HHI, CADE proximity, modality. NOT_OBSERVED: tender value, distance-to-winner, geography, later-wins (documented). |
| 5 | **Raw profile** | Cobidders distinct: Pregão 96.6% vs 66.6% (SMD 0.76), buyers 24.9 vs 14.3 (0.72), active years (0.84), proximity (n_cases 3.76, n_def 3.12 — partly mechanical), item-group HHI 0.45. |
| 6 | **Opportunity-adjusted profile** | item-group HHI **vanishes** (0.45→0.02); buyer breadth attenuates (0.72→0.19); proximity **halves** (3.76→2.25); years survives (0.84→0.54). Much of the raw difference is procurement-environment composition. |
| 7 | **Monotonicity** | Cobidder prevalence rises with T_i (Spearman **+0.92**); opportunity-adjusted **excess flat/negative** (Spearman **−0.93**). The rank is an **exposure ranking, not a collusion-intensity ranking**. |
| 8 | **Binary vs continuous verdict** | Continuous log(1+T_i) ties/beats FL14 in every full-sample setup (full 0.939 vs 0.924). Script 53's strict-pool flip (0.767>0.750, DeLong p=0.085 n.s.) is **sample-specific**. FL14 is administrative, not structural. |
| 9 | **Threshold sensitivity** | Smooth across thresholds, no discontinuity at 14; bunching density ratio **1.06 ≈ 1** (no strategic bunching; threshold never published). T=14 = median+1.5·IQR. |
| 10 | **Ordinary-loser alternatives** | **Narrowed, not eliminated.** Cobidders wider/longer-lived (not low-capacity), low Convite/quorum (not padding), low first-year concentration (not explore-exit). distance/geography/later-wins NOT_OBSERVED → specialization & geography not fully ruled out. CADE contact is the distinguishing axis. |
| 11 | **Market-specific zero-win** | Global **not dominated** (alternatives ROC 0.554–0.774 vs global 0.939; overlap 33–55%); leave-one-item-group-out stable [0.936, 0.941]. Keep global. |
| 12 | **Negative controls** | **Strength:** real cobidder ROC-AUC 0.939 beats matched placebo-anchor null (mean 0.755, p<0.001) and non-CADE-winner null (0.780, p<0.001) → ranking specific to the real defendant network. Honest caveat: placebo PR-AUC p=0.70 (base-rate inflation; ROC decisive). B=500, seed 20260603. |
| 13 | **Tables created** | Main: J (economic profile), K (opportunity-adjusted), L (monotonicity bins), M (binary-vs-continuous), N (ordinary-loser alternatives). Appendix: group counts, standardized diffs, placebo thresholds, market-zero-win ×2, negative controls. |
| 14 | **Figures created** | Main: standardized differences, cobidder prevalence by bin, excess contact by bin. Appendix: threshold sensitivity, bunching T=14, negative-control distribution. All with alt text. |
| 15 | **§5 edits** | Retitled "Economic Content and Ordinary-Loser Alternatives"; 5.1–5.6; "cartel-adjacent" removed; strengths-forward + honest attenuation + exposure-ranking finding. |
| 16 | **Appendix edits** | NEW Appendix H (`sec_app08_profile`, H.1–H.9) + `\input` in master. |
| 17 | **Claims softened/removed** | "cartel-adjacent" → "adjudication-anchored exposure"; profile framed as descriptive, not proof; SMDs emphasized over p-values; "exposure ranking not collusion-intensity" stated. critical=0. |
| 18 | **Build result** | **PASS** — paper 59pp, appendix 44pp; 0 errors, 0 undefined, no overfull >35pt. (Fixed: 6 Appendix-H tables had adjustbox-inside-threeparttable → reordered; 1 dangling \ref redirected.) |
| 19 | **Remaining blockers** | NOT_OBSERVED proxies (distance/geography) leave specialization & geography un-ruled-out; conservative-AUC re-estimation (carried); B3 (carried); App D/H length. |
| 20 | **Proceed to §6 bid-layer benchmark?** | YES. |

## STEP 23 — DECISION RULE VERDICT

**VERDICT B — DESCRIPTIVE SUPPORT, BUT OPPORTUNITY-COMPOSITION IMPORTANT** (with a C-flavored threshold/monotonicity note; ordinary-loser alternatives narrowed, not central).

> *Frequent-loser cobidders are economically distinct from other frequent losers — more Pregão-oriented, broader, more persistent, and closer to adjudicated anchors — and the ranking is specific to the real defendant network rather than an artifact of high-volume co-bidding (negative controls, p<0.001 on ROC). But the distinction is drawn largely from different procurement environments: after opportunity adjustment, market-concentration differences vanish and proximity differences halve, and the opportunity-adjusted excess contact does not rise with participation intensity. The frequent-loser rank is therefore best read as a disciplined exposure ranking with genuine but bounded economic content; the binary FL14 cutoff is an administrative queueing device, not a structural threshold; and ordinary-loser explanations are narrowed but not eliminated. The construct gives the exposure target economic content; it does not establish cartel conduct.*

NOT Verdict A (differences attenuate materially under opportunity adjustment; excess is flat). The threshold/monotonicity note (Verdict C language) is incorporated: "the binary rule is best interpreted as an administrative queueing device, not evidence of a structural participation threshold."

## Honesty ledger respected
No invented results. Attenuation reported (HHI vanishes, proximity halves, excess flat). NOT_OBSERVED proxies disclosed; ordinary alternatives not overclaimed as ruled out. Negative-control PR-AUC base-rate caveat stated alongside the ROC strength. Cobidders never called members; no proof/collusion/clean/guilty. SMDs over p-values.

## Recommended next
**Subprompt 8 — Section 6A: Bid-Layer Benchmark Audit and Complementarity** (scripts 31/49/26 Imhof). Under the reframe: award layer carries information beyond the bid-distribution benchmark on the same target — "comparable discrimination at lower informational cost," complementarity NOT "outperforms." Then §6B cost-recall frontier (RUN script 56), §7 price downgrade, App B survival, JLEO compliance.
