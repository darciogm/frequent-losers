# 05 — BLOCKERS & OPEN QUESTIONS (JLEO R&R v22)

Status: ✅ answered · 🟡 partial · ❔ unknown · ⛔ blocked. Each has evidence path + next action.
Resolved from the 2026-06-02 4-agent audit + run-artifact reads.

| # | Question | Status | Evidence path | Next action |
|---|---|---|---|---|
| 1 | Where is the firm-level always-loser dataset constructed? | ✅ | `scripts/00_build_bidlevel.py:106-107` → `firm_loss_stats.parquet` / `FREQ_PARTICIP_rebuilt.parquet` | none |
| 2 | Where is Tᵢ constructed? | ✅ | **No `T_i` in code.** Treatment = `losers` binary, `01_clean.R:148`; `losers_share` `:156`; item-panel `has_fl` (`12_build_item_value.R`) | reconcile theory notation (Tᵢ) to code name in App B |
| 3 | Where is Wᵢ constructed? | ✅ | No `W_i`; winner flag = `flagvencedor` (`00_build_bidlevel.py:97`), win_rate `:106` | same as #2 |
| 4 | Where is FL14 constructed? | 🟡 | `00_build_bidlevel.py:153-163` threshold `median+1.5·IQR`, uses **`>`** (=FL15-style); `54_threshold_table_q3iqr.R` re-derives | **VERIFY `>` vs `≥`**: confirm which set (2,735/193) the artifacts actually back before any re-derivation (CP-1) |
| 5 | Where are CADE direct defendants matched to BEC? | 🟡 | `cade_bec_crossmatch.csv` (49 rows, static). Producing logic **archived only** (README §CROSSMATCH; `work/v6,v8`); no current script regenerates | write regen script for JLEO replication (§5/CP-8) |
| 6 | Where is cobidderᵢ constructed? | ⛔ | `cade_fl_cobidders.csv` (193 rows, static March-2026). Logic in archived `work/v6/scripts/roc_detection.py:107`; current scripts only consume | **rebuild regenerating script** (NEW `79`); document provenance |
| 7 | Why 193 vs 210 cobidders? | ⛔ | 193 = `\valCobidders` = row count of `cade_fl_cobidders.csv` (FL-only, all is_FL=True). **210 = `\valConservativeCobidders`, HARDCODED in `99_make_paper_values.R:1321`**, not computed by any script; conservative pre-2020 benchmark (4 cases/30 def/210/108-FL). Data-reconstructable conservative defendants = **~19-20 ≠ 30** | **CP-1.** Rebuild funnel; if 210/108/30 irreproducible, RETIRE & replace with data-derived counts |
| 8 | Tender-item IDs stable across award & bid layers? | ✅ | `firm_tender_map` & `bid_level_full` share `(códigofornecedor, numerodaoc, códigoitem)`; `BEC_collapse_final` via `po_item_merge_key` | join on `(numerodaoc, códigoitem)` |
| 9 | Item codes AND item groups both available? | 🟡 | code (`códigoitem`) everywhere; **group/class/category only in `bid_level_full_v14.parquet`** (`Código Grupo`…), not propagated to item_value_panel/firm_tender_map | join back to v14 if exposure strata need item-group |
| 10 | Buyer / PBU IDs available & stable? | ✅ | `códigounidadecompradora` (bid_level/v14); `pbu_code` in item_value_panel (1,535 distinct); `po_item_merge_key[1:11]` | none |
| 11 | Modality & year at tender-item level? | ✅ | `item_value_panel.modality` (1=Convite,3=Pregão), `.year` (2009-19); `BEC_collapse_final.po_phase_code` (2,3) | none |
| 12 | Bid-layer LANCES linked to award participants? | ✅ | via `(numerodaoc,códigoitem)`+`códigofornecedor`; both descend from 22 `intermediate/bid_level_lances_*` | none |
| 13 | Bid rows available for cost-denominator (pool-size)? | ✅ | `n_bids`,`n_firms` in item_value_panel & BEC_collapse; raw bids in `bid_level_full_v14` (39.96M) | use for CP-4 cost frontier |
| 14 | CADE case IDs attached to defendant tender-items? | ⛔ | `numero_processo`/`processo` on **firm→case** (cade_carteis, crossmatch). **NO case_id on any tender-item; NO case_id on cobidder file** | rebuild tender-item→case via `firm_tender_map ⋈ crossmatch` (CP-1) |
| 15 | CADE case dates (conduct/filing/decision)? | 🟡 | **only `data_julgamento`** (judgment), present **9/12 cases** (3 NaT). NO conduct-period, NO filing/opening dates | use judgment date for Table G + LOCO anchoring; disclose conduct-onset unknown |
| 16 | Enough data for leave-one-case-out? | ⛔ | feasible at *defendant-firm* level (case_id in crossmatch); **NOT at cobidder level** (no cobidder→case map) until #14 rebuilt | NEW `80_leave_one_case_out.R` after CP-1 |
| 17 | Enough data for rolling-origin? | 🟡 | feature-time truncation works (`64:340`); **conduct-timeline rolling-origin blocked** — only post-sample judgment dates exist | rolling-origin on *award year* (sample timeline), not conduct; state limitation |
| 18 | Enough data for survival/hazard? | 🟡 | firm-year derivable (year=OC substr); **no explicit exit date** — exit = last active year, right-censored at 2019 | NEW `81_survival_hazard.R`; frame as bounded/censored, not clean hazard |
| 19 | Scripts deterministic & seeded? | ✅ | house seeds: 76/77=20260530, 25/37/40/43/45=20260430, 49/55/56=20260501, 63=20260502, 64=20260503. 53/78 deterministic (no resampling). Python ETL deterministic | seed any NEW script (79/80/81) with `2026xxxx` |
| 20 | Can manuscript tables be regenerated from scripts? | 🟡 | most write CSV/tex (regenerable) but to **`work/v13/output/tables/`** (stale path); submission uses **inline** tables; 2 hard-typed bodies (sec06 gatekeeper, app03 year-holdout) + sec07:145 "~1.4%" | macro-bind/`\input` the inline tables from script output during section passes |

## BLOCKERS — ranked (must resolve before the dependent empirical claim)
1. ⛔ **B1 — Conservative funnel (210/108/30) irreproducible** (Q7/Q14). Unsourced literals; ~19-20≠30. Blocks Table A / Referee #4. **Fix:** CP-1 rebuild; retire if irreproducible.
2. ⛔ **B2 — No cobidder→case linkage** (Q6/Q14/Q16). Blocks leave-one-case-out (Table C, Referee #6). **Fix:** rebuild from `firm_tender_map ⋈ crossmatch` in `79`, feed `80`.
3. ⛔ **B3 — Cobidder & crossmatch labels not reproducible** (Q5/Q6). Blocks JLEO replication package. **Fix:** regenerating script + ReadMe.
4. 🟡 **B4 — Conduct-onset dates absent** (Q15/Q17/Q18). Limits rolling-origin to award-year timeline; survival is censored. **Fix:** disclose; use judgment date where defensible.
5. 🟡 **B5 — `>` vs `≥` FL cut** (Q4). Could shift the 193 set. **Fix:** verify before re-deriving any count.
6. 🟡 **B6 — Script 56 not run / regulatory_frontier empty** (Q13/CP-4). **Fix:** run 56.

## Open questions for the USER (decisions I can't make from data/code)
- **U1 — ComprasNet appendix (app07):** wire in as cross-jurisdiction robustness, or delete? Currently orphaned. (Memory says federal extension is a reserved spinoff — recommend DELETE from this submission.)
- **U2 — If 210/108/30 are irreproducible,** do we (a) retire the conservative benchmark entirely, or (b) replace with the data-derived ~19-20 defendants + recomputed cobidder counts? Recommend (b) with full funnel disclosure.
- **U3 — Branch hygiene:** v22 branched off v21 to preserve scripts 76/77/78. If you want v21's *commits* out of v22 history, say so and I'll rebase onto v20 + cherry-pick the four scripts.
