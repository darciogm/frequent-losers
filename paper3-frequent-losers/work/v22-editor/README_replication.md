# Replication notes — *Cheap Signals, Costly Proof* (Paper 3, v22, JLEO R&R)

Skeleton replication doc for the JLEO submission. This is a WORK-IN-PROGRESS during the R&R; the final ReadMe PDF (JLEO policy) is produced at the integration pass (Prompt 12). Paths relative to `paper3-frequent-losers/`.

## 1. Pipeline at a glance

```
data/raw (BEC LANCES .dta, CADE CSVs)
  └─ scripts/00_build_bidlevel.py        → data/processed/*.parquet (5 files)
  └─ scripts/12_build_item_value.R       → data/processed/item_value_panel.parquet
scripts/01_clean.R                       → /tmp/p3_prepared.rds (+ caches)
scripts/02–10  (via 00_master.R)         → output/tables, output/figures   (core regressions)
scripts/11–78  (run by hand)             → output/<module>/   (diagnostics, audits, revision)
work/v22-editor/submission_clean/        → manuscript (paper_submission_clean.tex + sec*.tex + values.tex)
```

- **Engine:** R (`data.table`, `fixest`, `pROC`, `DBI`/`duckdb`, `MatchIt`), Python ETL (`pandas`, `duckdb`). LaTeX `elsarticle`/`natbib`.
- **Machine caps (house rule):** DuckDB `threads=12`, `memory_limit='14GB'`, spill `/tmp/duckdb_spill`; `setDTthreads(12)`. ≤16 GiB RAM budget.
- **Determinism:** all resampling scripts seed `2026xxxx` (76/77=20260530, new 79=20260602). Deterministic scripts (53/78/79 core counts) need no seed.

## 2. Datasets (data/processed/, git-ignored)

| File | Level | Notes |
|---|---|---|
| `bid_level_full_v14.parquet` (1.45 GB) | bid | raw 39.96M rows, item group/class/category |
| `firm_tender_map.parquet` | firm-item | key `(códigofornecedor, numerodaoc, códigoitem)` + `won`; `códigofornecedor` is 14-digit zero-padded CNPJ; **`-1` = anonymized sentinel, exclude** |
| `firm_loss_stats.parquet` | firm | `win_rate`, `always_loser` |
| `FREQ_PARTICIP_rebuilt.parquet` | firm | always-loser universe (16,843) + `tenders_count` |
| `item_value_panel.parquet` | tender-item | 3.99M items; `year`, `modality` (1=Convite,3=Pregão), `pbu_code`, `has_fl` |
| `cade_carteis_licitacoes_2009_2019.csv` | case | 12 procs; `data_julgamento` for 9/12; no conduct/filing dates |
| `cade_bec_crossmatch.csv` | defendant×case | 48 distinct CNPJ across 7 procs (+1 `IT_DF` junk) |
| `cade_fl_cobidders.csv` | firm | **193-row validation target — static artifact, see §4** |

## 3. Key constructs

- **always_loser** = `win_rate==0` (`00_build_bidlevel.py:107`).
- **tenders_count** = participation count among always-losers (`:142`).
- **FL14** = `tenders_count >= 14` (canonical). ⚠ The Python builder at `:153-163` uses `>` with a `median+1.5·IQR` threshold — verify which set backs the 2,735/193 artifacts (open item B5).
- **Treatment** in regressions = `losers` (binary) / `losers_share` (continuous), `01_clean.R:148,156`. There is no `T_i`/`W_i` in code; map theory notation accordingly.
- **Tender-item key** = `(numerodaoc, códigoitem)`; stable across award (`firm_tender_map`) and bid (`bid_level_full`) layers.

## 4. ⚠ Provenance gaps (must close for JLEO replication)

1. **`cade_fl_cobidders.csv` (the 193 validation target) has NO builder on disk.** Every script — current and archived (`work/v6,v8/roc_detection.py`) — only *consumes* it (takes `firm_id` as the positive set). The columns `tenders_with_cade`, `total_cobids` were produced by a one-off builder that is not in the repo.
2. **`cade_bec_crossmatch.csv`** is likewise a static artifact (exact-CNPJ + fuzzy match against `Firms_final`), no regenerating script.
3. **`scripts/79_label_funnel.R`** (NEW, v22) rebuilds the funnel transparently and reconciles the counts (see §5). It does **not** reproduce the static 193 exactly because the original used an undocumented narrow cartel-tender restriction.

## 5. Label funnel — `scripts/79_label_funnel.R` (CP-1)

Run: `Rscript scripts/79_label_funnel.R` → `output/label_funnel/{funnel.csv, case_timing.csv, case_cobidder_map.csv, audit_log.txt}`.

Transparent cobidder definition: a firm is a *cobidder* if it shares ≥1 tender-item `(numerodaoc, códigoitem)` with a BEC-active direct defendant (`-1` and defendants excluded). FL14 = `tenders_count≥14`.

Reconciliation vs cited macros (v22 run, 2026-06-02):

| Funnel count | Data | Manuscript | Verdict |
|---|---|---|---|
| CADE cases | 12 | 12 | exact |
| BEC-active direct defendants | 41 | `\valDirectCADE`=47 | discrepant (zero-pad/match) |
| cobidders (all) | 4,369 | — | — |
| always-loser cobidders | 651 | (App C labels 193) | — |
| **FL cobidders** | **341** | `\valCobidders`=**193** | **discrepant** (broad def; original narrow) |
| conservative cases (≤2020) | 4 | `\valConservativeCases`=4 | exact |
| conservative defendants | 19 | `\valConservativeFD`=30 | discrepant |
| conservative AL cobidders | 208 | `\valConservativeCobidders`=210 | **approx (data-grounded)** |
| conservative FL cobidders | 107 | conservative-FL=108 | **approx (data-grounded)** |

**Finding:** 210/108 are NOT fabricated (reproduce to 208/107). But the main 193 and the conservative 210/108 were built with **different** cobidder definitions (narrow vs broad). `case_cobidder_map.csv` (5,121 cobidder×case rows) now materializes the cobidder→case linkage that unblocks leave-one-case-out.

**Open decision (U2):** adopt one transparent scripted definition repo-wide and re-validate every AUC, OR reverse-engineer the original narrow restriction.

## 6. Known non-portable paths (de-hard-code before release)
`12_build_item_value.R:42` (paper2 CSV dir), `00_build_bidlevel.py:40`, `67/70/73*.py` (comprasnet). Documented, not yet edited — builds already produced their parquets; do not re-run mid-revision.

## 7. Do NOT
- re-run `99_make_paper_values.R` (writes stale `work/v13/values.tex`).
- hand-edit generated tables/figures — regenerate from script.
- edit `work/v20-editor/` (frozen) or `work/v21-editor/` (abandoned).
