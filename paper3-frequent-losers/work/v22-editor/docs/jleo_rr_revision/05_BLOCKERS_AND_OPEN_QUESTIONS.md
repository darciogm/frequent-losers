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

## ★ CP-1 UPDATE (2026-06-02, `scripts/79_label_funnel.R` run) — corrects the earlier "fabricated literals" read
Transparent funnel (cobidder = shares ≥1 tender-item with a BEC-active direct defendant; FL14=tc≥14):
- CADE cases **12** (=12 ✓); BEC-active defendants **41** (vs `\valDirectCADE`=47 — zero-pad/match gap); cobidders-all 4,369; AL cobidders 651; **FL cobidders 341 vs `\valCobidders`=193 → DISCREPANT** (overlap 149/193, file-only 44, recon-only 192).
- Conservative (judged ≤2020): cases **4** (=4 ✓); defendants **19** (vs 30 ✗); **AL cobidders 208 ≈ 210 ✓**; **FL cobidders 107 ≈ 108 ✓**.
- **Verdict:** 210/108 are **NOT fabricated** — they reproduce (208/107) under the *broad* co-bid definition. The main **193 used a *narrower*, undocumented cartel-tender restriction** → the main and conservative benchmarks were built with **inconsistent cobidder definitions**. The original builder of `cade_fl_cobidders.csv` is **absent from the entire repo** (every script only consumes it) → **B3 confirmed**.
- **B2 partly resolved:** `output/label_funnel/case_cobidder_map.csv` (5,121 cobidder×case rows) now materializes the cobidder→case linkage → LOCO can proceed at cobidder level (NEW `80`).

## BLOCKERS — ranked (updated 2026-06-02)
1. 🟡 **B1 — Funnel inconsistency, NOT fabrication** (Q7). Conservative 210/108 reproduce (208/107); main 193 does not (341) under the transparent def. The real issue is two inconsistent definitions + the lost builder. **Fix:** U2 decision — adopt one scripted definition repo-wide (re-validate all AUC) or reverse-engineer the narrow restriction. Defendant 30 (vs 19) is a genuine over-count to drop.
2. 🟡 **B2 — cobidder→case linkage** (Q14/Q16) — **now materialized** in `case_cobidder_map.csv`. Remaining: feed `80_leave_one_case_out.R`.
3. ⛔ **B3 — Cobidder & crossmatch labels have NO builder anywhere on disk** (Q5/Q6). Confirmed by exhaustive grep — all scripts consume, none produce. Blocks JLEO replication. **Fix:** `79` now regenerates a *transparent* funnel; either bless it as canonical (U2) or recover the original.
4. 🟡 **B4 — Conduct-onset dates absent** (Q15/Q17/Q18). Limits rolling-origin to award-year timeline; survival is censored. **Fix:** disclose; use judgment date where defensible.
5. 🟡 **B5 — `>` vs `≥` FL cut** (Q4). Could shift the 193 set. **Fix:** verify before re-deriving any count.
6. 🟡 **B6 — Script 56 not run / regulatory_frontier empty** (Q13/CP-4). **Fix:** run 56.

## Open questions for the USER (decisions I can't make from data/code)
- **U1 — ComprasNet appendix (app07):** wire in as cross-jurisdiction robustness, or delete? Currently orphaned. (Memory says federal extension is a reserved spinoff — recommend DELETE from this submission.)
- **U2 — [UPDATED 2026-06-02, DECISION NEEDED]** The 193-cobidder ground truth has **no builder on disk** and the main (193) vs conservative (210/108) targets use **inconsistent cobidder definitions**. Three options:
  - **(a) Bless the transparent `79_label_funnel.R` definition as canonical** (cobidder = shares a tender-item with a BEC-active direct defendant; FL14=tc≥14 → 341 FL cobidders). Cleanest for JLEO replication, but **re-validates every AUC in the paper against a new, larger target** (193→341) — i.e. re-run scripts 17/26/33/34/36/40/42/53/63/64/74/75/76/77 with the new label. Big but defensible.
  - **(b) Reverse-engineer the original narrow restriction** to reproduce 193 exactly (e.g. restrict co-bids to cartel-relevant tenders by sector/case-year), document it, keep existing AUCs. Lower blast radius, but the restriction may not be recoverable and risks looking like target-gerrymandering.
  - **(c) Keep 193 as the headline but ADD the transparent funnel as a robustness target** and disclose both. Pragmatic; discloses the inconsistency honestly.
  - **mr-frequent recommendation:** (c) for this R&R round (disclose + robustness), with (a) as the stated path if a referee pushes on reproducibility. Drop the unsupported 30-defendant figure regardless (use 19). **Needs your call before §4 (Prompts 3–5).**
  - **✅ RESOLVED 2026-06-02 — user chose (c) DISCLOSE + ROBUSTNESS.** Keep **193** as the headline/primary target; ADD the transparent script-79 funnel (**341**) as a fully-reproducible robustness target; disclose the inconsistency + absent builder honestly; **drop 30 → use 19** conservative defendants; option (a) is the stated fallback if a referee presses reproducibility. **ACTION for Prompt 3/4:** Table A reports both the 193 primary and the 341 transparent funnel. ⚠ **CLAIMS-DISCIPLINE FLAG:** the phrase "results are materially unchanged" is **UNVERIFIED** — before it enters prose, re-run at least one core AUC (e.g. script 76 within-opportunity, or 34 horse-race) under the 341 label and confirm the discrimination is materially the same. Do NOT assert invariance without that check (see [[feedback_paper3_tone_honest_not_confessional]]).
- **U3 — Branch hygiene:** v22 branched off v21 to preserve scripts 76/77/78. If you want v21's *commits* out of v22 history, say so and I'll rebase onto v20 + cherry-pick the four scripts.

---

## Subprompt 2 infrastructure pass (2026-06-02) — new/updated items

Reproducibility infra built; no NEW hard blockers. Findings:

- **B3 reconfirmed (replication):** `cade_fl_cobidders.csv` and `cade_bec_crossmatch.csv` have NO builder anywhere on disk (exhaustive grep + script-79 reconstruction). For JLEO replication policy, either bless the transparent `79_label_funnel.R` definition (U2 option a) or recover the originals. Tracked in `dataset_registry.csv` (status STATIC).
- **B6 still open:** `output/regulatory_frontier/` EMPTY → `make jleo_rr_status` flags it; cost-recall frontier (Table D / FIG_COST_RECALL_FRONTIER) blocked until `scripts/56_regulatory_cost_frontier.R` is RUN.
- **NEW scripts still to author:** `80_leave_one_case_out.R` (linkage now READY via `case_cobidder_map.csv`) and `81_survival_hazard.R` (exit right-censored at 2019 — bounding argument, not clean hazard).
- **Compliance items surfaced by scanners:** both manuscript figures MISSING "Alt text:" (JLEO requires it); 1 bib entry defined-but-uncited; 8 hard-typed numbers (incl. sec07:161 "30" conservative defendants → drop to 19 per U2).
- **Infra-fix log (non-blocking):** `scan_refs.R` `#1` macro-param false positive fixed; `make_registries.R` arg-count guard added after two short rows.

### Tooling now available for the empirical prompts (reduces future blocker risk)
- `scripts/utils/metrics_triage.R` — ROC-AUC, PR-AUC/AP, precision/recall/FP/FN/lift@k, cost-per-TP, seeded bootstrap CI, grouped-CV / leave-one-case-out / rolling-origin split generators (22-assertion toy test PASSES).
- `scripts/utils/cost_frontier.R` — cost-recall frontier over K1 × cost denominators (skeleton; needs script 56 panel).
- `scripts/utils/exposure_validation.R` — opportunity-cell construction, leave-one-out contact rates, exposure-adjusted/stratified frames, cell-preserving permutation (mirrors script 76).
- `scripts/utils/label_funnel.R` — Table-A schema + reconciliation helpers around script 79.

---

## Subprompt 3 — empirical dependencies still open after front-end (2026-06-02)
Front-end (sec 1–3) is written with forward-looking language; it does NOT assert any of the following is resolved. Carried into the validation prompts:
- **Label funnel counts (12/65/47/193 vs 341 / 210→reconcile / 30→19)** — NOT reconciled in prose; TODO_JLEO_RR_LABEL_FUNNEL in §2.3 + Table 1 tablenote. → Subprompt 4A.
- **Opportunity-adjusted validation** — NOT yet in §4; §3.3 TODO_JLEO_RR_OPPORTUNITY_TABLE points to it. → Prompt 4.
- **Cost-recall frontier** — NOT generated (`output/regulatory_frontier/` empty); abstract/§1/§3.2 carry REVALIDATE/COST_FRONTIER TODOs on 83%/131/193 + K1 grid. → Prompt 8 (run script 56).
- **Bid benchmark audit** — NOT documented (Table E). → Prompt 7.
- **Case-timing table (Table G) + LOCO** — NOT built. → Prompts 3/5.
- **Cosmetic flag:** Fig 1 shows two AUCs (0.888/0.903) under a "not a horse race" caption — reconsider at Prompt 7/8.

---

## Subprompt 4 close-out — B1/B3 resolved-for-manuscript (2026-06-03)
- **B1 (193-vs-210 inconsistency):** ✅ RESOLVED in manuscript — disclosed as a two-axis definition difference (stratum + cobidder def), not a bug; Table A reconciles all benchmarks; conservative rebound to reproducible 19/208/107; 30 over-count dropped. `explanation_code = DIFFERENT_COBIDDER_DEFINITION (+ AL-vs-FL stratum)`. Memo: `label_reconciliation_memo.md`.
- **B3 (absent cobidder builder):** ⚠ STILL OPEN for the JLEO *replication package* — the static `cade_fl_cobidders.csv` (193) builder remains absent. MITIGATED for the manuscript: §4.1 discloses the archived builder; the transparent `01_label_funnel_reconciliation.R` funnel (341/651/208/107) is the reproducible alternative. For final submission, either bless the transparent funnel as canonical (U2 option a, re-validates all AUC) or recover the original builder.
- **B2 (cobidder→case linkage):** ✅ materialized (`case_cobidder_map.csv`) — LOCO (Subprompt 5) unblocked.
- **NEW open item for 4B:** conservative-benchmark AUC/enrichment (`\valAUCprePost`, `\valCADEenrich`, `\valCADEbase`) were estimated on the adjudication-anchored labels; re-estimate under the harmonized definition during opportunity-adjusted validation; do NOT claim invariance until then.
- Assertions: 9 pass / 1 warning (A8 = 210-vs-193 is a definition difference, classified not silently passed) / 0 fail.

---

## Subprompt 5 — open items after the make-or-break test (2026-06-03)
- **Conservative-benchmark AUC re-estimation (carried from Sub4):** still pending under the harmonized label — the §4.2 baseline AUC macros (\valAUCprePost etc.) untouched; opportunity-adjusted §4.3 uses the script-76/02 numbers. Reconcile in a robustness pass if a referee presses.
- **Case dominance (NEW, flagged):** largest CADE case ≈47% of TP@500; top item-group ≈32% of positives. Formal **leave-one-case-out + leave-largest-case-out is Subprompt 6** (linkage ready: `case_cobidder_map.csv`).
- **App D literals vs macros:** App D (D.1–D.12) uses CSV-matched literals for opportunity numbers; main §4.3 uses `\valExp*` macros. Values agree; swap App D to macros in a cleanup pass (non-blocking).
- **Permutation honesty (carry):** Approach B p=1.00 (exposure out-predicts on PR-AUC) is the headline caveat; never frame the result as "beats exposure on PR-AUC." Within-matched-exposure (C, +nested DeLong) is the residual-signal evidence.
- **B3 (absent 193 builder):** still open for the replication package (Sub4).
- Verdict B locked: limited but significant residual triage value; NOT a standalone screen.