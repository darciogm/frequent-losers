# 30 — SUBPROMPT 11 LOG: Section 7 price/scope/adaptation (JLEO R&R v22)

Date: 2026-06-03. Branch **`v22`**. Subprompts 1–10 committed.

## STARTING STATE (already strong — §7 compressed in Sub9)
`sec07_price_scope_submission.tex` (~786w, 0 tables, 0 figures, ~2pp): title "Scope, Limits, and Price Corroboration"; price = scope/corroborative; explicitly NOT damages/overcharge/markup/causal/cover-bidding-mechanism; sign-reversal decomposed (broad +0.064 → overlap-cell ATT −0.097); Q4 high-value tail the only positive cell; direct-CADE null (no damages base); **"the mechanism is not identified by these data"** (theater-not-identified); §7.2 Adaptive Deployment (continuous ranks / top-k / refresh / bunching / bid-layer follow-up). **Already near Verdict A.**

## GAPS to fix
1. **Dangling appendix promise:** §7 says "full price regressions in Appendix~\ref{app:scope_adaptation_submission}" but `sec_app04_scope_submission.tex` is THIN (214w, 0 tables) — the price regression tables were deleted in Sub9 compression. → populate the price appendix (H.1–H.9) with compact tables from the price script outputs (numbers already macro-bound).
2. **Tie adaptation to the §6B cost-recall frontier** (Step 9) — §7.2 doesn't reference it yet.
3. Price number reproduction audit (confirm macros vs scripts 59/61/62/78).
4. Memos (inventory, mechanism discipline). Claims/number scan (no 83%-universal conflict; FL14 not structural).

## CONFIRMED INPUTS
- Price macros (values.tex): \valBetaBroad=+0.064 (p=0.003, N=1,654,401), \valScopeOverlapCoef=−0.097, \valBetaQfour=+0.041 (p=0.045), \valBetaCADEDirect=−0.061 (p=0.45), \valSignBetaConvATT=−0.099, \valSignBetaPregATT=−0.098, \valSelTest* (selection Q1 1.35→Q5 6.93, Δ5.58, FullFE +3.55), \valMechWinnerVsRef* (within-cell → genuine bidders).
- Scripts: 59_sign_reversal_decomp, 61_selection_mechanism_test + sign_reversal_segment_decomp, 62_within_cell_mechanism_test + theory_bridge_bidlevel, 78_bidder_count_decomposition. Outputs: output/{sign_reversal_decomp, sign_reversal_segment, selection_mechanism, mechanism_within_cell, unified_mechanism, stratum_scope, item_level_scope_match, external_validity_scope}.

## EXPECTED VERDICT: **A** (§7 is scope-only, no overcharge/damages/causal, sign-reversal explained, mechanism-not-identified, adaptation disciplined, <3pp). Pending: appendix promise honored + frontier tie.

## EXECUTION (fan-out)
- E1 (empirical): price number reproduction audit → `outputs/diagnostics/price_number_reproduction.csv` + `price_mechanism_discipline_memo.md` + `section7_inventory.md`.
- W1 (manuscript): populate price appendix (sec_app04) H.1–H.9 with compact regression tables (macro-bound, from script outputs) + tie §7.2 adaptation to the §6B frontier. Disjoint from E1.
- Me: claims/number scan, docs, completion report, build, verdict.

### Files read · scripts · outputs
Docs 00–29. sec07, sec_app04. Price scripts 59/61/62/78 + outputs. Price macros.

### Results
- **Price numbers: ALL 20 reproduce** (price_number_reproduction.csv) — broad +0.064, overlap-cell ATT −0.097, PS-trim −0.307, Q4 +0.041, Convite/Pregão ATT −0.099/−0.098, direct-CADE null −0.061(p=0.45), selection Q1 1.35→Q5 6.93 (Δ5.58, FullFE +3.55), within-cell → genuine-bidders (FL ns). Nothing to delete.
- §7 prose already scope-only / no-causal / no-overcharge / mechanism-not-identified (confirmed; no residual overclaim).

### Edits
- **Price appendix (sec_app04) EXPANDED** 214w/0 tables → 1042w/3 tables (H.1–H.9): broad associations, sign-reversal decomposition, Q4+modality heterogeneity, direct-CADE null, not-damages/overcharge, within-cell mechanism, adaptation cross-ref, limitations. Dangling "full regressions in Appendix" promise now HONORED.
- **§7.2 frontier tie:** added clause — "survivor-pool size of the refreshed queue is itself a point on the cost-recall frontier of §6B, so deployment capacity and gaming-robustness are chosen together."
- Memos: section7_inventory.md, price_mechanism_discipline_memo.md, price_number_reproduction.csv. claims_scan_after_section7.csv, number scan consistent (no 83%-universal in §7; FL14 not structural).

### Build result
**PASS.** Paper 38pp, appendix 51pp (+2 price appendix), 0 errors/undefined. Main 6 tables / 3 figures. claims critical=0. §7 forbidden terms all negated.

### Verdict: A — §7 is JLEO-safe (scope-only, no overcharge/damages/causal, sign-reversal explained, mechanism-not-identified, adaptation tied to frontier, <3pp; appendix promise honored).
