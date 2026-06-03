# 44 — FINAL REFEREE RISK MATRIX (JLEO R&R v22, post-Subprompt 13)

Date: 2026-06-03. Branch `v22`. Manuscript: *Cheap Signals, Costly Proof: The Reach and Limits of Award-Layer Screening in Cartel Enforcement* (Genicolo-Martins & de Azevedo). Paper 39pp / Appendix 55pp / Abstract 144w / 6 main tables / 3 figures.

Risk levels: **L** low (defended), **M** medium (conceded + bounded), **H** high (residual, disclosed).

| # | Referee objection (anticipated) | Where addressed | Residual risk | Honest disposition |
|---|---|---|---|---|
| R1 | "AUC 0.92 is just opportunity exposure — high-volume losers mechanically meet defendants." | §4.2 opportunity-adjusted (Table 3); exposure-only AUC 0.946; within-stratum 0.7715 (+0.042, DeLong p≈2e-6) | **M** | Conceded: most raw concentration is opportunity. A limited, significant residual survives once O_i/E_i cells are fixed. Sold as *decomposition*, not headline AUC. |
| R2 | "Performance is retrospective — the score uses post-investigation participation." | §4.3 timing/case-holdout (Table 4); strict 2009-16→2017-19 | **H** | Conceded openly: strict-timing discriminating power is modest and **sequential strict-timing is BLOCKED** (bid features not time-limitable). Disclosed as a reach limit, not hidden. |
| R3 | "It's one case (the largest cartel) doing the work." | §4.3 leave-one-case-out; §6B G.7 | **H** | Conceded: leave-largest-case-out recall 0.48→0.34 (one case ≈55% of positives). Reported as a limit; "map of reach and limits" framing absorbs it. |
| R4 | "193 cobidders is a constructed, non-reproducible label (absent builder)." | §4.1 label funnel (Table 2); App C; B3 disclosed | **M** | Builder absent (B3) disclosed; transparent `79_label_funnel.R` funnel is the reproducible alternative (193 primary; 341/651 robustness; 30→19, 210→208, 108→107 rebounds). Definition difference, not a bug. |
| R5 | "Award layer is redundant with bid-distribution screens (Imhof/Wallimann)." | §6.1 bid benchmark (Table 5) | **M** | Award score carries information beyond the Imhof–Wallimann RF benchmark on the same target (0.888 vs 0.921, joint 0.962). Sold as *division of labor* (different stages), not "outperforms". Leakage-sensitive — conceded. |
| R6 | "83% cost reduction is mechanically firm-level inflation." | §6B cost-recall frontier (Table 6, Fig 3); App G | **M** | Conceded and turned into the contribution: firm reduction ≈88% but **bid-row reduction ≈33%** at K1=2000; denominator transparency is the point. Frontier, not a calibrated optimum; beats random 3–12×. |
| R7 | "Positive price coefficient = overcharge/damages claim without ID." | §7; App H | **L** | Price is scope-only. Broad +0.064 → overlap-cell ATT −0.097 (selection, not markup); Q4 +0.041 scope heterogeneity; direct-CADE null (no damages base). No causal/overcharge/damages language. |
| R8 | "Cover-bidding mechanism (theater) is asserted, not identified." | §7; sec06; script 78 | **L** | Explicitly **not identified**: within-cell movement loads on genuine-bidder count, not FL. Stated as a limit. |
| R9 | "FL14 cutoff is arbitrary / gameable." | §3.2; §7.2; bunching | **L** | FL14 = administrative (median+1.5·IQR), explicitly **not** structural/legal; continuous rank is the object; refreshed queues / top-k / bunching tie to §6B frontier. Bunching ratio 1.06 (threshold never published). |
| R10 | "Direct-CADE AUC ≈ 0.5 means the screen fails." | §4 (Table 4 scope boundary); §5; §8 | **L** | Front-paged as a **scope result**, not a failure: a loser-side screen *should* miss direct defendants; D4 shows defendants are win-heavy. The asymmetry is the design. |
| R11 | "Survival/exit claim (λ_C>λ_G) is post hoc." | App B (B.1-B.6, Prop B1); survival audit | **M** | Derived from an exit-margin model + firm-year platform-survival audit (cobidders persist markedly longer). Maintained behavioral assumption, stated as such; not a structural estimate. |
| R12 | "Theory (MLR ranking) is decorative." | App B Assumption B1 + Prop B1 + Cor B1 | **L** | Monotone-likelihood-ratio result presented as a *maintained-condition ranking justification*, not an identification claim; main text uses it modestly. |
| R13 | "Length / float budget for a journal article." | whole | **M** | Main 39pp / 6 tables / 3 figures — within JLEO norms. Appendix 55pp (referee-proofing battery) — honest residual, above the 35pp aspiration; online supplement absorbs granular grids. |
| R14 | "Replication impossible." | replication/ + online_supplement/ | **M** | Full package: README, SCRIPT_ORDER, OUTPUTS_MAP, MANIFEST + 9-dir supplement. BEC microdata not redistributable (administrative) — disclosed with cooperation pledge; CADE public; derived/anon frames OK. |

## Net assessment
No **affirmative** overclaim survives (claims scan: 0 critical; the one "dominates" is stochastic-dominance of an ROC-AUC distribution, paired with "not dominated by"). The two genuinely **High** residuals (R2 retrospective power, R3 single-case fragility) are the paper's own thesis — *reach and limits* — not concealed weaknesses. The reframe converts the three hardest objections (R1/R2/R3/R6) into the contribution.

**Submission posture: defensible.** Remaining exposure is honesty-bounded, not identification-fatal.
