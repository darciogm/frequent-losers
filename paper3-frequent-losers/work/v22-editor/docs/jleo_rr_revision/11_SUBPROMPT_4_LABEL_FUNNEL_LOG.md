# 11 — SUBPROMPT 4 LOG: Label funnel & 193-vs-210 reconciliation (JLEO R&R v22)

Date: 2026-06-02. Agent: mr-frequent-losers. Branch: **`v22`** (the R&R revision branch; Subprompts 1–3 committed here — staying on it, NOT creating `rr_jleo_label_funnel`, to preserve the single-branch R&R history; documented same as Subprompt 3). Paper3 tree clean for v22-editor at start (only unrelated paper1/2/18 + stale v6/v7/v12-v18 dirt, untouched).

## SETUP check
All of `docs/jleo_rr_revision/00–10` present (00–08 from Subprompts 1–2; 09–10 from Subprompt 3). Not SETUP_MISSING.

## THE DIAGNOSIS (locked before building — from `scripts/79_label_funnel.R` + its run artifacts + static-file inspection)

**Source of 193 (`\valCobidders`):** row count of the static `data/processed/cade_fl_cobidders.csv` (193 rows, **all `is_FL=True`, `always_loser=1`**; cols incl. `tenders_with_cade`, `total_cobids`, `wins_in_cade_tenders=0`). Built by a builder that is **absent from the entire repo** (B3) using a **narrow cartel-tender restriction** (the `tenders_with_cade` field counts cobids in CADE-flagged tenders specifically, not every tender a defendant entered). Under script 79's transparent **broad** definition (any shared tender-item with a BEC-active direct defendant; FL14 = tenders_count ≥ 14) the full 12-case portfolio yields **341** FL cobidders — overlapping the static 193 at only **149/193** (44 file-only, 192 recon-only).

**Source of 210 (`\valConservativeCobidders`):** was hard-typed in `99_make_paper_values.R:1321`. Script 79 **reproduces it as 208** always-loser cobidders under the **broad** definition restricted to the **4 conservative cases** (judgment date ≤ 2020-12-31). So 210 ≈ 208 — data-grounded, NOT fabricated.

**Why 210 > 193 with FEWER cases — TWO compounding definition differences (NOT a bug):**
1. **Stratum:** 210 counts **always-loser** cobidders (S4); 193 counts the narrower **frequent-loser** subset (S5). AL ⊇ FL ⇒ AL counts are larger.
2. **Cobidder definition:** 210 uses the **broad** "any shared tender-item with a BEC-active defendant" net; 193 uses the **narrow** cartel-tender restriction. The broad net casts wide even for 4 cases.

Under a **common** definition+stratum the subset relation is restored: broad-AL 208 (cons) < 651 (full); broad-FL 107 (cons) < 341 (full). ⇒ `explanation_code = DIFFERENT_COBIDDER_DEFINITION` (+ stratum AL-vs-FL), **not** `SAME_DEFINITION_UNEXPECTED_DIFFERENCE`.

**Other counts:** BEC-active direct defendants — manuscript `\valDirectCADE`=47 (crossmatch-matched; file has 48 distinct CNPJ / 8 procs) vs script-79 **41** (those actually in `firm_tender_map`). Conservative defendants — manuscript `\valConservativeFD`=**30** is an over-count with **no reproduction**; script gives **19** BEC-active in the 4 cases → **DROP 30 → 19** (U2-mandated). Cases: 12 total (9 with judgment dates, 3 NaT); conservative = 4 (judged ≤2020).

## U2 decision (locked, 05_BLOCKERS): keep **193** primary (disclose absent builder) + add transparent **341** robustness; **drop 30 → 19**; keep AUC-linked 210/108 in prose with Table A showing the 208/107 reproduction (do NOT assert AUC invariance — re-estimation is 4B).

## Verdict: **RECONCILED (definition difference, not a coding error).** Paper can proceed to 4B.

---
## EXECUTION (fan-out)
- Phase A (empirical): NEW `work/v22-editor/scripts/analysis/01_label_funnel_reconciliation.R` → count reproduction, Table A, Table B, 193-vs-210 set diff, assertions, funnel figure, macro snippet.
- Phase B (parallel): docs (memo + unit definitions); manuscript (§4.1 + App C + Table 1 note + values.tex). Me: tracking-doc updates, build, scanners, completion report.

### Files read · scripts inspected · data inspected
- Docs 00–10 (Subprompt 3 read). `scripts/79_label_funnel.R` (full). Outputs `output/label_funnel/{funnel.csv,case_timing.csv,audit_log.txt}` + `case_cobidder_map.csv` (5,121 rows).
- Data: `cade_fl_cobidders.csv` (193×12 cols), `cade_bec_crossmatch.csv` (49 rows/48 CNPJ/8 procs), `cade_carteis_licitacoes_2009_2019.csv` (12 procs, 9 dated).
- Manuscript: `sec04` §4.1, `sec02` (Table 1), `sec_app02` (App C) macro usage mapped.

### Outputs created (Phase A — `01_label_funnel_reconciliation.R`)
`outputs/tables/main/table_A_label_funnel.{csv,tex}`, `table_B_case_timing_and_benchmark_use.{csv,tex}`; `outputs/diagnostics/{label_count_reproduction,cobidder_set_comparison_193_vs_210,cobidder_set_comparison_summary,label_funnel_assertions,label_funnel_new_macros}`; `outputs/figures/main/fig_label_funnel.pdf`; `outputs/logs/label_funnel_reconciliation.log`. Scanner snapshots `outputs/diagnostics/{number,claims}_scan_after_label_funnel.csv`.

### Counts reproduced (Phase A — all core EXACT)
193 (static, exact); 341 broad-FL / 651 broad-AL (full portfolio); 208 cons-AL / 107 cons-FL; 19 cons-defendants; 41 ftm-active def; 52,013 defendant tender-items; 149 static∩broad overlap; 16,843 always-losers; 2,735 FL; 41,443 all-BEC (manu 41,444, off-by-1). NOT reproducible (flagged, not fabricated): 65 legal roster (empty CNPJ col), 16,779 Imhof pool (scripts 31/49), 11,676 gatekeeping pool (scripts 63/64).

### Exact source of 193 / 210 / discrepancy
- **193** = row count of static `data/processed/cade_fl_cobidders.csv` (FL-only, narrow cartel-tender def; builder ABSENT — B3).
- **210** = `\valConservativeCobidders` (was hard-typed `99_make_paper_values.R:1321`); reproduces to **208** broad-def always-loser cobidders over the 4 conservative cases.
- **Discrepancy = DIFFERENT_COBIDDER_DEFINITION + AL-vs-FL stratum** (two axes; conservative uses broad def over the wider AL stratum, main uses narrow def over the FL subset). Under a common def the subset relation holds (208<651, 107<341). NOT a coding bug; the only hard data error is the 30-defendant over-count → 19. Verdict **RECONCILED**.

### Manuscript edits
- `values.tex`: +9 `\valFunnel*` macros (`% src:`); rebind ConservativeFD 30→19, ConservativeCobidders 210→208, ConservativeFL 108→107. AUC macros untouched.
- `sec04`: new §4.1 "Label Construction and Sample Reconciliation" + inline Table A (Table 3) + two-axis 193-vs-210 paragraph + roadmap line.
- `sec_app02` (App C): restructured C.1–C.7 (award universe / screen / CADE match exact-CNPJ / cobidder labels / conservative+timing / denominator changes / reconciliation) + inline Table B (anonymized Case A–L) + label-table updates (cobidder = exposure label, conservative macros).
- `sec02`: Table 1 tablenote cross-link to Table A.
- Memos: `unit_definitions_label_funnel.md`, `label_reconciliation_memo.md`.

### Commands run
`Rscript work/v22-editor/scripts/analysis/01_label_funnel_reconciliation.R` (exit 0, ~1s, RSS 237MB); compile paper+appendix (`pdflatex`×/`bibtex`, bidirectional `xr` — paper first then appendix to resolve the Table-3 cross-ref); `make diagnostics`. None failed (appendix `bibtex exit 2` = pre-existing no-`\bibliography`-in-appendix, resolves via xr).

### Build result
**PASS.** Paper **44pp** (was 43; Table A added a page), appendix **18pp**. 0 errors, 0 undefined refs, 0 overfull hboxes (after fixing compile-order xr for Table 3). claims critical=0; numbers 77 hits (the +9 are the intentional 65/210/108/30 reconciliation-disclosure literals). Assertions 9 pass / 1 warning / 0 fail.

### Failures / blockers
- **B3** (absent 193-builder) still open for the JLEO replication PACKAGE; mitigated in manuscript via the transparent funnel. 
- Conservative-benchmark AUC re-estimation under harmonized label = deferred to 4B (no invariance asserted).
- No blocker prevents proceeding to 4B.
