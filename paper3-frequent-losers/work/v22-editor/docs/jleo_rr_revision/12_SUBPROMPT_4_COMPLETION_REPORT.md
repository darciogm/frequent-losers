# 12 — SUBPROMPT 4 COMPLETION REPORT: Label funnel & 193-vs-210 reconciliation (JLEO R&R v22)

Date: 2026-06-03. Branch `v22`. Agent: mr-frequent-losers. Method: lead diagnosis + 3-agent fan-out (Phase A empirical reconciliation; Phase B1 memos; Phase B2 manuscript) on disjoint files.

| # | Item | Result |
|---|---|---|
| 1 | **Scripts created/modified** | NEW `work/v22-editor/scripts/analysis/01_label_funnel_reconciliation.R` (extends `scripts/79_label_funnel.R`, DuckDB, seed 20260602). `scripts/79_label_funnel.R` unchanged. |
| 2 | **Data files used** | `firm_tender_map`, `firm_loss_stats`, `FREQ_PARTICIP_rebuilt` (parquet); `cade_bec_crossmatch.csv`, `cade_carteis_licitacoes_2009_2019.csv`, `cade_fl_cobidders.csv`. None modified. |
| 3 | **Counts reproduced (EXACT)** | 193, 341, 651, 208, 107, 19, 41, 52,013, 149-overlap, 16,843, 2,735. Off-by-1: 41,443 (manu 41,444), 48 distinct crossmatch CNPJ (manu 47) — both benign, disclosed in Table A note. |
| 4 | **Counts NOT reproduced** | 65 legal-defendant roster (rulings CSV CNPJ column empty); 16,779 Imhof common-support pool (scripts 31/49); 11,676 gatekeeping pool (scripts 63/64). All flagged `not_found`, NOT fabricated. |
| 5 | **Source of 193** | Row count of static `cade_fl_cobidders.csv` (FL-only, `always_loser=1`), built under a **narrow cartel-tender restriction** whose builder is **absent from the repo** (B3). |
| 6 | **Source of 210** | `\valConservativeCobidders`, formerly hard-typed in `99_make_paper_values.R:1321`; **reproduces to 208** always-loser cobidders under the broad shared-tender-item definition over the 4 conservative cases (judgment ≤ 2020-12-31). |
| 7 | **Explanation of discrepancy** | TWO compounding definition differences: (i) **stratum** — 210/208 count always-losers, 193 the narrower frequent-loser subset (AL⊇FL); (ii) **cobidder definition** — broad shared-tender-item vs narrow cartel-tender. A smaller case set yields a larger count because broad+AL out-casts narrow+FL. Under a common definition the subset relation is restored (208<651 AL; 107<341 FL). `explanation_code = DIFFERENT_COBIDDER_DEFINITION (+ AL-vs-FL stratum)`. |
| 8 | **Coding error or definition difference?** | **Definition / documentation difference**, not a computation bug. The one genuine data error is the 30-defendant over-count → corrected to 19. |
| 9 | **Downstream regeneration** | Conservative COUNTS now reproducible (208/107/19, rebound in values.tex). Conservative-benchmark AUC/enrichment (`\valAUCprePost`, `\valCADEenrich`, `\valCADEbase`) re-estimation under the harmonized label is **deferred to Subprompt 4B** — invariance NOT asserted (per honest-not-confessional rule + U2 caveat). |
| 10 | **Tables created** | Table A `tab:label_funnel_submission` (Table 3, p18, inline, macro-bound, 4 benchmark rows). Table B `tab:case_timing_submission` (App C, 12 cases, anonymized Case A–L, judgment dates, benchmark-inclusion flags). |
| 11 | **Figures created** | `outputs/figures/main/fig_label_funnel.pdf` (two-branch funnel; reproduced nodes only). Not yet placed in manuscript (optional; available for later use). |
| 12 | **Manuscript sections edited** | sec04 §4.1 (new) + roadmap; sec02 Table 1 note; values.tex (macros). |
| 13 | **Appendix sections edited** | sec_app02 restructured C.1–C.7 + Table B + label-table updates. |
| 14 | **Assertions** | **9 pass / 1 warning / 0 fail** (`label_funnel_assertions.csv`). Warning A8 = the 210-vs-193 inequality classified as a definition difference, not silently passed. |
| 15 | **Build result** | **PASS** — paper 44pp, appendix 18pp; 0 errors, 0 undefined refs, 0 overfull hboxes; Table 3 cross-ref resolves into the appendix via bidirectional `xr`. |
| 16 | **Remaining blockers** | **B3** (193 builder absent) open for the JLEO *replication package* only — mitigated in-manuscript by the transparent funnel; final fix = bless the transparent funnel (U2 option a, re-validates AUC) or recover the original. Conservative AUC re-estimation = 4B. |
| 17 | **Proceed to opportunity-adjusted validation?** | **YES — verdict RECONCILED.** Not `NOT_READY_FOR_JLEO_LABEL_CONSTRUCTION_BLOCKER`. |

## Success conditions (all met)
Source of 193 identified ✓; source of 210 identified ✓; discrepancy explained (definition difference) ✓; reproducible label-funnel table exists (Table A, script-generated) ✓; case-level timing table exists (Table B) ✓; unit definitions documented (`unit_definitions_label_funnel.md`) ✓; unique-firm / firm-case / firm-defendant / firm-tender counts kept separate ✓; direct defendants and cobidders remain legally distinct ✓; §4.1 + App C explain construction ✓; manuscript no longer leaves "fewer cases → more cobidders" unexplained ✓.

## Honesty ledger
No invented counts. The narrow-target builder absence is disclosed, not hidden. 30→19 over-count dropped. 210/108 superseded by reproducible 208/107 with the earlier figures explicitly named in App C as superseded. No AUC invariance claimed. Cobidders never called cartel members; "adjudication-anchored exposure label" used throughout.

## Recommended next
**Subprompt 4B — Opportunity-Adjusted Validation as the Main Result** (CP-2): promote script 76 within-opportunity AUC 0.7715 / +0.0415 (DeLong p=2.08e-06), state exposure-only=0.946; and re-estimate the conservative-benchmark AUC under the harmonized label here.
