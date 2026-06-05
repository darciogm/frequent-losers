# Federal Run Chain — Artifact-Dependency DAG Audit & Runbook

**Scope:** `scripts/analysis/{00,01,02,02b,03,04,05,06,12,12b}` in `--source=comprasnet` mode.
**cfg:** `scripts/utils/source_config.R` → federal dirs under `work/v22-editor/outputs/comprasnet/{targets,tables,figures,diagnostics,cache,logs}`; spill = `outputs/comprasnet/cache/duckdb_spill`.
**Machine:** 21 GiB RAM, 16 GiB budget, 12 threads. Single-process sequential.
**Audited:** 2026-06-05. GREP/READ-only; nothing executed.

---

## 1. Input data — all federal parquets present on disk (verified)

| Artifact (cfg field) | Path | Status |
|---|---|---|
| firm_tender_map | `data/processed_comprasnet/firm_tender_map.parquet` (608 MB) | OK |
| firm_loss_stats | `…/firm_loss_stats.parquet` | OK |
| freq_particip | `…/FREQ_PARTICIP_rebuilt.parquet` | OK |
| losers | `…/LOSERS_rebuilt.parquet` | OK |
| bid_level | `…/bid_level_full.parquet` | OK |
| item_panel (year/buyer map) | `…/item_level_panel.parquet` (carries `year`,`po_phase_code`,`codigo_ug`,`descricao_item`) | OK |
| cade direct_defendants | `…/cade_link_v3/direct_defendants_federal.parquet` (`firm_id,razao_cade,processo,setor,always_loser,win_rate`) | OK |
| cade cobidders (set-cmp only) | `…/cade_link_v3/cobidders_federal.parquet` (has `always_loser`) | OK |
| cade anchored_tenders | `…/cade_link_v3/anchored_tenders_federal.parquet` | OK |
| cade cnpjs_enriched | `…/cade_link_v3/cnpjs_enriched.csv` (`numero_processo,data_julgamento`) | OK |

Schema names match what each script reads. `descricao_item` present → confirms item-group NOT_OBSERVED decision (no cheap product taxonomy).

---

## 2. Producer → Consumer DAG (derived artifacts in federal cache/diag)

```
00 ──writes──> outputs/comprasnet/cache/canonical_cobidders_broad.csv ──┐
                                                                        ├─> 02, 02b, 03, 04, 05, 06, 12, 12b  (consume)
00 ──writes──> targets/canonical_{firm,case}_labels.csv, target_counts.csv
00 ──writes──> diagnostics/federal_cobidder_rebuild_vs_v3.csv, target_*assertions.csv

01 ──writes──> tables/table_A_label_funnel.{csv,tex}, table_B_*.{csv,tex},
               diagnostics/label_count_reproduction.csv, …, figures/fig_label_funnel.pdf
               (01 is a LEAF: consumes only raw parquets+CADE; nothing downstream reads its outputs)

02 ──writes──> outputs/comprasnet/cache/firm_opportunity_adjusted_frame.csv ──┐
               outputs/comprasnet/cache/firm_panel_exposure_axis.csv          ├─> 05, 06, 12, 12b (consume frame)
               + tables C/D family, perm metrics, figures

02b ─writes──> *** SAME PATH *** cache/firm_opportunity_adjusted_frame.csv  (OVERWRITES 02 — see GAP-2)

03 ──writes──> cache/year_map.parquet (federal-only, built once);  tables D/E/F timing, figures
               (03 is effectively a LEAF for the chain: nothing downstream reads its outputs)

04 ──reads──> cache/canonical_cobidders_broad.csv (00)
   ──reads──> cache/case_cobidder_map_federal.csv  ***HARD stop() IF MISSING*** (GAP-1)
   ──writes──> tables G/H + LOCO/RI/dominance csv+figs

05 ──reads──> cache/firm_opportunity_adjusted_frame.csv (02/02b)  [HARD stop if missing]
   ──reads──> cache/canonical_cobidders_broad.csv (00)
   ──reads──> cache/case_cobidder_map.csv  [GRACEFUL no-op if missing] (GAP-3)
   ──writes──> tables E/J/K/L/M/N + monotonicity csv + figs

06 ──reads──> cache/canonical_cobidders_broad.csv (00)
   ──reads──> cache/firm_opportunity_adjusted_frame.csv (02/02b)
   ──reads──> cache/case_cobidder_map.csv  [GRACEFUL no-op if missing] (GAP-3)
   ──writes──> tables E/N + placebo/threshold csv + figs

12 ──reads──> cache/firm_opportunity_adjusted_frame.csv (02/02b)  [HARD stop if missing]
   ──reads──> cache/canonical_cobidders_broad.csv (00)            [HARD stop if missing]
   ──writes──> diagnostics/audit_armor/leakage_check_cell_level.csv ──┐
               + frozen_timing, granularity_sweep, permutation_power, macros
                                                                       │
12b ─reads──> diagnostics/audit_armor/leakage_check_cell_level.csv (12) [GRACEFUL: NA macros if missing]
   ──reads──> cache/firm_opportunity_adjusted_frame.csv + canonical_cobidders_broad.csv [HARD stop if missing]
   ──writes──> audit_armor/{audit_armor_macros.tex,granularity_sweep,permutation_power_curve}.* (fixup)
```

**Topological validity:** every consumed *derived* artifact is produced by an earlier script in the planned order **EXCEPT** `case_cobidder_map(_federal).csv`, which has **no federal producer anywhere** (GAP-1, GAP-3).

---

## 3. Known-risk resolutions

| # | Risk | Verdict |
|---|---|---|
| (i) | `canonical_cobidders_broad.csv` produced by 00-federal? | **YES.** `00_…R:453` writes it to `cfg$dirs$cache` (federal cache). Confirmed produced before all 8 consumers. |
| (ii) | who writes `firm_opportunity_adjusted_frame.csv`; ordered before readers? | **02 writes it** (`02_…R:709`, `dir_cache`). Readers = 05,06,12,12b. Writer ordered first. **But 02b also writes the same path → see GAP-2.** Not 05. |
| (iii) | `case_cobidder_map_federal.csv` / `case_cobidder_map.csv` producer? | **CHAIN GAP. No federal producer.** BEC producer = `scripts/79_label_funnel.R` (top-level, BEC-only, not source-adapted, writes to `output/label_funnel/`). 04 HARD-stops; 05/06 degrade. See GAP-1/GAP-3. |
| (iv) | `year_map.parquet` (03) cache collision? | **Safe.** Only `03_…R:150` writes/reads `cfg$dirs$cache/year_map.parquet`. `source_config.get_year_map()` and `register_keymap()` in 02/12 build in-memory `keymap`/`ymap` tables (no file). No other script writes `year_map.parquet`. Federal cache is isolated from BEC `/tmp`. No collision. |
| (v) | 12b needs 12's `leakage_check_cell_level.csv`? | **Confirmed handoff.** 12 writes it to `cfg$dirs$diagnostics/audit_armor/` (`12:230`); 12b reads same path (`12b:70,329`). 12b GRACEFULLY degrades (FLAG + NA `\valArmorExp*` macros) if absent — so 12 MUST run before 12b for complete macros, but absence is non-fatal. |
| (vi) | BEC-only artifact consumed unconditionally in federal mode? | **None unconditional.** All `REPO/output/…` legacy reads (firm_panel.csv `02:654`/`02b:627`; case_cobidder_map `04:177`,`05:626`,`06:154`; case_timing `04:222`; STRICT53 `05:731`) are behind `IS_BEC`/`cfg$source=="bec"` guards or soft `list.files`. `imhof_firm_features.parquet` (00 Target F) is GRACEFUL (`if file.exists` → NA). Federal recomputes/degrades. `09`’s unguarded legacy read is NOT in this 10-script chain. |

---

## 4. CHAIN GAPS (loud)

### GAP-1 (BLOCKER) — `case_cobidder_map_federal.csv` has no producer; script 04 HARD-stops

- **Consumer:** `04_case_holdout_dominance.R:184-192` — federal branch reads
  `cfg$dirs$cache/case_cobidder_map_federal.csv`; if missing it calls `stop()` with
  the BLOCKER message ("federal cobidder→case map not found … produced by the Phase-1
  canonical federal cobidder rebuild (NOT YET RUN)"). **04 cannot run.**
- **Producer in chain:** NONE. Nothing in `{00..12b}` writes `case_cobidder_map_federal.csv`.
- **BEC producer:** `scripts/79_label_funnel.R:216` writes `output/label_funnel/case_cobidder_map.csv`
  with columns `cnpj, proc, is_AL` (from its `cobidder_case` DuckDB table joined to `cob_stat`).
  79 is **NOT** source-adapted (no `--source=`/`source_config`); it is BEC-only.
- **Required columns (from 04 usage):** `cnpj`, `proc`, and (for 05/06) `is_AL`. 04 restricts to
  the 7 **NUMBERED** federal processos only (`numbered_procs` from `def_proc_map`, TI/DF empty-processo dropped per gate G3).
- **Fix (cheapest, exact):** script 00 ALREADY builds the identical `cobidder_case`
  table (`00_…R:225-231`) — the same verbatim S3 join 79 uses. Add one federal emit
  to **00** (or a tiny new `00b`) writing the federal twin to BOTH paths the chain reads:
  ```r
  # in 00, federal branch, after cobidder_case is built:
  ccm_fed <- dbGetQuery(con, "SELECT cnpj, proc FROM cobidder_case")
  setDT(ccm_fed)
  ccm_fed <- merge(ccm_fed, lab[, .(cnpj, is_AL = as.integer(always_loser==1L))],
                   by="cnpj", all.x=TRUE)
  ccm_fed[is.na(is_AL), is_AL := 0L]
  fwrite(ccm_fed, file.path(cfg$dirs$cache, "case_cobidder_map_federal.csv"))  # for 04
  fwrite(ccm_fed, file.path(cfg$dirs$cache, "case_cobidder_map.csv"))          # for 05/06
  ```
  04 then auto-restricts to numbered processos itself. Run 00 once → unblocks 04 and
  upgrades 05/06 from degraded to full. (Alternative: source-adapt 79 to `--source` and
  point its OUTDIR at `cfg$dirs$cache`; heavier, re-derives the same join.)

### GAP-2 (HAZARD) — 02b OVERWRITES 02's primary frame at the same cache path

- `02b_opportunity_sensitivity_contact2.R:677` writes `firm_opportunity_adjusted_frame.csv`
  to the **same** `dir_cache` path as `02:709`, but 02b restricts positives to the
  `contact >= 2` **sensitivity** label (`02b:388-394`).
- Planned order `02 → 02b → {05,06,12,12b}` means downstream §5/armor scripts would read
  **02b's sensitivity frame**, silently substituting the contact≥2 variant for the primary
  validation frame → corrupts main §5/armor numbers.
- **Fix:** either (a) run `02b` **AFTER** all of {05,06,12,12b} (re-order so 02's frame is the
  one on disk when downstream runs), or (b) make 02b write a distinct filename
  (`firm_opportunity_adjusted_frame_contact2.csv`) and never overwrite the primary. Option (b)
  is safer. If neither is done, **re-run 02 immediately before {05,06,12,12b}** to restore the
  primary frame.

### GAP-3 (DEGRADE, not fatal) — 05/06 read federal `case_cobidder_map.csv` (no `_federal` suffix), also unproduced

- `05:627` and `06:155` read `cfg$dirs$cache/case_cobidder_map.csv` (NOT the `_federal` twin
  04 wants). Both GRACEFULLY degrade (`largest_case` legs become no-ops: `cob_largest=0` /
  `in_largest_case=0`) if absent — so 05/06 still complete, but the "share of positives from
  largest case" / largest-case-exclusion sensitivity columns are vacuous.
- **Fix:** GAP-1's fix writes BOTH `case_cobidder_map.csv` and `case_cobidder_map_federal.csv`
  → 05/06 upgrade to full automatically. (Note the filename mismatch between 04 and 05/06;
  the GAP-1 fix emits both names to cover it.)

---

## 5. Hard-stop (`stop()`) inventory — federal mode

| Script | Hard-stop condition | Mitigation |
|---|---|---|
| 00 | `stopifnot(file.exists(ftm,loss,freq))`; arrow missing for federal CADE parquets | inputs present; install `arrow` |
| 01 | same input `stopifnot`; arrow missing | inputs present |
| 02/02b | `sql_buyer_key/sql_year_key` `stop()` if substring lambda called federally (guarded — only fires on a coding regression) | not triggered in normal flow |
| 03 | `stop()` if `canonical_cobidders_broad.csv` missing | run 00 first |
| **04** | **`stop()` if `case_cobidder_map_federal.csv` missing** | **GAP-1 — must produce it** |
| 05 | `stop()` if `firm_opportunity_adjusted_frame.csv` missing; `stop()` if no CNPJ col in direct_defendants | run 02 first; schema OK |
| 12 | `stop()` if frame OR canonical cache missing; `stop()` if `cfg$freeze_year` missing | run 00+02 first; freeze_year=2016 wired |
| 12b | `stop()` if frame OR canonical cache missing; freeze_year `stop()` | run 00+02 first |

Graceful degrades: 00 Target-F (imhof→NA), 01 figure (tryCatch), 05/06 case_cobidder_map (no-op), 05 STRICT53 (list.files), 12b leakage handoff (NA macros).

---

## 6. Compute profile & PRAGMA

All heavy steps already set `PRAGMA threads=12`, `memory_limit='12-14GB'`,
`temp_directory=outputs/comprasnet/cache/duckdb_spill` from cfg. **No change needed.**
Single-process sequential respects the 16 GiB budget (peak ≈ 12-14 GiB in 02/04 self-joins).

| Step | Heaviest op | Rows touched | B (perm/boot) | Est. wall |
|---|---|---|---|---|
| 00 | ftm×defend join, cobidder_case | ftm ~ tens of M | — | 2-4 min |
| 01 | same S1-S3 joins + ggplot | ftm | — | 2-3 min |
| 02 | **defendant-contact self-join (peak)** + cells COARSE/MED/STRICT + matching | ftm self-join; AL firm-opportunity rows | bootstrap B=2000 (×3 metrics), perm B_PERM | **8-14 min** |
| 02b | identical to 02 (contact≥2 variant) | same | same | 8-14 min |
| 03 | firm×year panel + year_map build + rolling-origin | ftm + item_panel | rolling folds | 4-7 min |
| 04 | contact self-join + LOCO + clustered RI | ftm self-join | RI B=1000 | 5-9 min |
| 05 | frame reload + monotonicity + ig_mass (skipped fed) | frame (firm-level, small) + 1 ftm scan | — | 2-4 min |
| 06 | placebo thresholds + negative-control draws | frame + ftm | placebo B=500 | 3-6 min |
| 12 | granularity sweep + permutation power | frame + ftm | power B=200×60 sims | 4-7 min |
| 12b | fixup of 12 (power curve + frozen timing) | frame | B=200×60 | 3-5 min |

**Total expected wall time (sequential): ~45-75 min** (≈ 60 min midpoint), dominated by
02+02b (two full self-join passes) and 04.

---

## 7. RUNBOOK — exact commands, in order

Pre-flight: ensure R pkgs `DBI, duckdb, data.table, arrow, pROC, MatchIt, splines, ggplot2, digest` installed.

```bash
cd /home/darciogm1/projetos/bitter-pills/paper3-frequent-losers
A=work/v22-editor/scripts/analysis
L=work/v22-editor/outputs/comprasnet/logs

# 1. canonical targets + (AFTER GAP-1 FIX) case_cobidder_map_federal.csv
Rscript $A/00_build_canonical_validation_targets.R --source=comprasnet 2>&1 | tee $L/00.log

# 2. label funnel (leaf; independent)
Rscript $A/01_label_funnel_reconciliation.R       --source=comprasnet 2>&1 | tee $L/01.log

# 3. PRIMARY opportunity frame  (writes firm_opportunity_adjusted_frame.csv)
Rscript $A/02_opportunity_adjusted_validation.R   --source=comprasnet 2>&1 | tee $L/02.log

# 4. timing holdout (leaf; builds year_map.parquet)
Rscript $A/03_timing_case_holdout_validation.R    --source=comprasnet 2>&1 | tee $L/03.log

# 5. case holdout / LOCO  (NEEDS case_cobidder_map_federal.csv from step 1)
Rscript $A/04_case_holdout_dominance.R            --source=comprasnet 2>&1 | tee $L/04.log

# 6. §5 profile + robustness  (consume the PRIMARY frame from step 3)
Rscript $A/05_section5_profile_monotonicity.R     --source=comprasnet 2>&1 | tee $L/05.log
Rscript $A/06_section5_robustness.R               --source=comprasnet 2>&1 | tee $L/06.log

# 7. audit armor  (12 writes leakage_check_cell_level.csv -> 12b reads it)
Rscript $A/12_audit_armor.R                       --source=comprasnet 2>&1 | tee $L/12.log
Rscript $A/12b_audit_armor_fixup.R                --source=comprasnet 2>&1 | tee $L/12b.log

# 8. sensitivity variant LAST (GAP-2: it overwrites the primary frame; run after all
#    primary-frame consumers, OR redirect its output filename first).
Rscript $A/02b_opportunity_sensitivity_contact2.R --source=comprasnet 2>&1 | tee $L/02b.log
```

**Order change vs the original plan:** the original `00→01→02(+02b)→{03,04}→{05,06}→12→12b`
runs 02b before the primary-frame consumers, which silently swaps the contact≥2 sensitivity
frame in for the main results (GAP-2). The runbook above **moves 02b to the very end**.
If you instead apply the GAP-2 option (b) filename fix to 02b, it may run anywhere after 02.

**Validated run order (after GAP-1 fix applied to 00):**
`00 → 01 → 02 → 03 → 04 → 05 → 06 → 12 → 12b → 02b`

---

## 8. Pre-execution checklist

- [ ] **GAP-1:** add `case_cobidder_map_federal.csv` + `case_cobidder_map.csv` emit to 00 (federal branch). Without this, 04 hard-stops and 05/06 run degraded.
- [ ] **GAP-2:** run 02b LAST (or give it a distinct output filename). Otherwise §5/armor read the contact≥2 frame.
- [ ] confirm `arrow` R package installed (00/01/12/12b federal CADE parquet reads).
- [ ] confirm `digest` installed (hashed firm ids; else deterministic-int fallback).
- [ ] (info) federal test window is 2017-2019 (`holdout_test`); data window 2013-2019 → covered.

---
## ERRATUM (2026-06-05, post-fix)
- **GAP-2 premise was WRONG**: 02b's `dir_cache` resolves to the isolated `sensitivity_contact2/cache/`, NOT the shared cache — it never overwrote 02's canonical frame. The rename to `firm_opportunity_adjusted_frame_contact2.csv` was applied anyway (defense-in-depth). **02b is order-independent** (any point after 02).
- **GAP-1 FIXED**: script 00 federal mode now emits `case_cobidder_map_federal.csv` + `case_cobidder_map.csv` (`cnpj,proc,is_AL`) to the federal cache; unblocks 04, upgrades 05/06 to full. BEC mode unchanged (verified: 00-bec rerun byte-identical, R1 holds).
- **Final validated order**: 00 → 01 → 02 → 02b → 03 → 04 → 05 → 06 → 12 → 12b.
