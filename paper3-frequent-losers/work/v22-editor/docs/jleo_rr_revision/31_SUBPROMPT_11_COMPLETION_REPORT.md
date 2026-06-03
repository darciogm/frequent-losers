# 31 — SUBPROMPT 11 COMPLETION REPORT: Section 7 price/scope/adaptation (JLEO R&R v22)

Date: 2026-06-03. Branch `v22`. Method: §7 was already compressed (Sub9) → this pass = audit + populate price appendix + frontier tie. 2 agents (E1 price audit, W1 appendix+§7 tie).

| # | Item | Result |
|---|---|---|
| 1 | §7 length before | ~786w / ~2pp / 0 tables (already compressed Sub9) |
| 2 | §7 length after | ~810w / ~2pp / 0 tables (unchanged + 1 frontier-tie clause) |
| 3 | Price outputs located | scripts 59/61/62/78 + outputs (sign_reversal_decomp, selection_mechanism, mechanism_within_cell, sign_reversal_segment, item_level_scope_match). |
| 4 | Price numbers reproduced | **ALL 20 reproduce** (price_number_reproduction.csv) — broad +0.064, overlap ATT −0.097, PS-trim −0.307, Q4 +0.041, modality ATT −0.099/−0.098, direct-CADE null −0.061, selection Q1→Q5, within-cell mechanism. None not_found. |
| 5 | Main price table | None in main text (Sub9 deleted); compact tables now in the price appendix. |
| 6 | Sign reversal | Decomposed: broad +0.064 (selection into high-price cells) → overlap-cell ATT −0.097 (weighting result, not dropped-obs); blocks a markup reading. |
| 7 | High-value Q4 | Acknowledged (+0.041, the only positive cell; coordination cost spread over larger contracts) — scope heterogeneity. |
| 8 | Causal price language remaining? | **None** (all forbidden terms negated). |
| 9 | Overcharge/damages language? | **None affirmative** — explicitly disclaimed; direct-CADE null = no damages base. |
| 10 | Strategic-adaptation diagnostics | Reused bunching (ratio 1.06 @ T=14, threshold never published) cross-ref; no new run. |
| 11 | Threshold/gaming language | FL14 = administrative not structural; refreshed queue / continuous ranks / bunching / bid-layer follow-up; tied to §6B frontier. |
| 12 | Tables moved to appendix | 3 compact price tables now in price appendix (the "full regressions" promise honored). |
| 13 | Figures moved | None (no price figures). |
| 14 | Online supplement | Full price regression grids noted as living in the online supplement. |
| 15 | Abstract/intro/conclusion edits | None needed (abstract has no price claim; conclusion already disciplined). |
| 16 | Claims softened/removed | None needed — already disciplined; critical=0. |
| 17 | Number consistency | §7 does not conflict with §6B (no 83%-universal; FL14 not structural). |
| 18 | Build | **PASS** — paper 38pp, appendix 51pp; 0 errors, 0 undefined refs. |
| 19 | Remaining blockers | Minor: \valScopeOverlapN (script 51) vs headline_specs N (script 59) differ by ~800 obs (coefficient identical) — non-blocking. |
| 20 | §7 JLEO-safe? | **YES.** |

## STEP 17 — VERDICT

**VERDICT A — Section 7 is safe and useful.**

> *Price patterns provide descriptive scope evidence and reinforce the need for bid-layer follow-up; they do not estimate injury or prove conduct. The broad positive association reflects selection into structurally higher-price procurement cells; the overlap-cell sign reversal blocks a markup interpretation; the high-value Q4 tail is scope heterogeneity; the within-cell movement loads on genuine-bidder count, so the cover-bidding mechanism is not identified; and the direct-CADE null supplies no damages base. Adaptive deployment uses refreshed capacity-constrained queues — points on the §6B cost-recall frontier — rather than a permanent public cutoff.*

All success conditions met: §7 ≤3pp; scope-only; no overcharge/damages/causal; sign reversal explained; Q4 acknowledged; detailed regressions in the appendix; adaptation tied to refreshed queues + frontier; FL14 not structural; claims pass; numbers reproduce and are consistent.

## Recommended next
**Subprompt 12 — Appendix B: Theory, Exit Margin, and Survival/Hazard Evidence** (derive λ_C>λ_G via a dynamic exit margin + firm-year survival audit). Then Subprompt 13 (final integration / hygiene).
