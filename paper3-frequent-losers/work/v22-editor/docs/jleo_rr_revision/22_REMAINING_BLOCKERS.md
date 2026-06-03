# 22 — REMAINING BLOCKERS (out of the manuscript, JLEO R&R v22)

These are unresolved items kept OUT of the compiled paper (no TODO markers remain in source). They live here, not in the manuscript.

## Open empirical / reproducibility items
1. **Cost-recall frontier (Subprompt 9, NOT YET DONE):** `scripts/56_regulatory_cost_frontier.R` not run (`output/regulatory_frontier/` EMPTY). The main-text cost result is currently the existing `tab:gatekeeper_submission` (the 6th main table, a proxy). Subprompt 9 must run 56, extend 63/64 to a K1×cost grid, and replace the "83%" headline with a frontier; the 3rd main figure slot is reserved for `fig_cost_recall_frontier`.
2. **B3 — absent 193-cobidder builder:** `cade_fl_cobidders.csv` has no on-disk builder. Mitigated in-manuscript (transparent script-79 funnel = 341 robustness target); JLEO replication package still needs either to bless the transparent funnel or recover the original builder.
3. **Conservative-benchmark AUC re-estimation under the harmonized label:** `\valAUCprePost`/enrichment macros were never re-estimated under the 341 funnel (Sub4 deferred; never claimed invariant).
4. **Script 31 bit-reproducibility:** no per-fold RF seed → N=16,779 numbers reproduce within CV jitter (N=11,676 exact). Add `seed=20260430+k` to `ranger()` (no manuscript number changes). Header still says "logit/10-fold" (code is RF/5-fold).
5. **Bid strict-timing BLOCKED:** within-tender moments can't be cleanly time-limited; disclosed in App I.
6. **NOT_OBSERVED award-layer proxies:** distance-to-winner, geography, later-wins → ordinary-loser alternatives (specialization, geography) narrowed but not eliminated.

## Structural / compliance items (post-compression)
7. **Online appendix length (55pp vs 20–30 target):** the appendix absorbed all the demoted main-text detail (App A–I), which is correct (that is where the referee-proofing belongs). Further reduction = split the heaviest technical appendices (D timing, H profile, I bid) into a separate **online supplement / replication tier**, and move scanner logs / registries / completion reports (already in `docs/` + `outputs/`, NOT in the compiled appendix) to the replication package. Main-text compression (the priority) is achieved (36pp).
8. **Appendix relettering (cosmetic):** current A–I order (referee-map, framework/theory, data/labels, validation audits, price, adaptive, forensic, profile, bid) does not match the idealized A-data/B-theory/C-opportunity/D-timing/E-bid/F-price scheme; deferred (risky reletter; all cross-refs currently resolve).
9. **Pending later prompts:** §7 price downgrade is done (theater-not-identified disclosed); Appendix B exit/survival hazard (`81_survival_hazard.R`) NOT built; JLEO final compliance audit (double-spacing, JEL on title page, Bluebook cites, alt-text completeness) pending.

## Status
None of these blocks the compressed submission ARCHITECTURE. They are tracked for the remaining subprompts (9 = cost-recall frontier; then App B survival; then final JLEO compliance).
