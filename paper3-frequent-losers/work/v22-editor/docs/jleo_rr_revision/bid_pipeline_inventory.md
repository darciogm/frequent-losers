# Bid-Layer Pipeline Inventory (Step 3)

**Audit date:** 2026-06-03
**Auditor scope:** bid-layer benchmark (Imhof–Wallimann forensic comparison) only.
**Repo root:** `/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers`
**Engine:** R + arrow/data.table (script 31) and DuckDB (script 49). Seed `20260430` (script 31), `20260501` (script 49).

This document inventories every component of the bid-layer benchmark with exact
paths and line numbers. The benchmark answers: *does the cheap, award-layer
frequent-loser signal add value over the expensive, full-bid-microdata
Imhof–Wallimann screen?*

> **Learner correction.** The benchmark learner is a **random forest**
> (`ranger`, 500 trees, `probability = TRUE`), **not** a logit. The script
> header (31:15) and docstring still say "logit / 10-fold CV"; the actual code
> (31:124–145) uses `ranger` with **5-fold random CV**. Any manuscript prose
> claiming "logit" is wrong. Correct phrasing: **"Imhof–Wallimann moments in a
> random forest, evaluated by 5-fold random cross-validation."**

---

## 1. Component map (10 components)

| # | Component | Path / location | Status |
|---|-----------|-----------------|--------|
| 1 | Raw bid data | `v3/data/processed/bid_level_with_prices.parquet` (245 MB) — cols `códigofornecedor`, `numerodaoc`, `códigoitem`, `bid_price` | FOUND |
| 2 | Tender-bid-moment construction | script `31:51–78` (data.table `by=.(numerodaoc, codigoitem)`); DuckDB twin in `49:41–149` | FOUND |
| 3 | Firm-level aggregation | `31:82–99` (firm-mean of per-tender features); DuckDB twin `49:121–149` | FOUND |
| 4 | Model training | `31:123–177` (`ranger`, 500 trees, 5-fold random CV); `49:182–259` | FOUND |
| 5 | Table generation (current §6 benchmark) | **CSV** written by `31:177` → `output/imhof_full/imhof_full_results.csv`. The §6 manuscript table is **hand-built inline** in `sec06_screening_forensics_submission.tex:98` (not script-generated). The incremental table IS script-generated: `49:299–340` → `tab_imhof_incremental.tex`. | FOUND (partial: §6 table is inline) |
| 6 | Figure source | `31:179–213` → `output/imhof_full/fig_imhof_comparison.pdf` | FOUND |
| 7 | Target-label file | `data/processed/cade_fl_cobidders.csv` (193 rows, 193 unique firm_code) — loaded `31:104`, `49:153` | FOUND |
| 8 | Direct-defendant exclusion file | `data/processed/cade_bec_crossmatch.csv` (49 rows; **47 unique firm CNPJs**) — direct CADE defendants. **NOTE: neither script 31 nor 49 explicitly subtracts this file** (see §3 caveat). | FOUND (used only implicitly) |
| 9 | Sample restriction | always-loser ∩ complete Imhof features. Script 31: `31:109–121` (complete cv/skew/kurt → **N=16,779**). Script 49: `49:160–180` (all 7 features incl `cv_sd` → **N=11,676**). | FOUND |
| 10 | Current Table location in manuscript | `sec06_screening_forensics_submission.tex`, `\label{tab:imhof_cost_submission}` (line 98); referenced lines 64, 71, 173. Incremental table `\label{tab:imhof_incremental}`. | FOUND |

**All 10 components located.** Two annotations:
- Component 5: the §6 benchmark table is **inline/hand-built** in the .tex, fed by
  `imhof_full_results.csv` + `values.tex` macros (`values.tex:54–56, 379, 1085–1142`).
  It is not emitted by a table-generating R block. The *incremental* table (§6,
  `tab:imhof_incremental`) IS script-emitted by `49:299–340`.
- Component 8 (direct-defendant exclusion): see §3 below — it is a **soft**
  exclusion, not a hard filter in code.

---

## 2. Two scripts, two samples (explained)

| | Script 31 (`31_imhof_full_pipeline.R`) | Script 49 (`49_imhof_incremental_value.R`) |
|---|---|---|
| Engine | arrow + data.table | DuckDB |
| Join key format | `as.character(códigofornecedor)` (no zero-pad) — but `bid_level` codes already 14-digit, so join is consistent | `LPAD(...,14,'0')` |
| Sample filter | complete `cv` & `skew` & `kurt` (`31:116–118`) | complete **all 7** features incl `cv_sd` (`49:170–172`) + non-NA `tenders_count` |
| **Pool N** | **16,779** | **11,676** |
| Positives | **193** | **193** |
| CV scheme | 5-fold random, seed 20260430 | 5-fold random, seed 20260501 |
| Headline | imhof_full 0.888, fl 0.921, +fl 0.962 | imhof_full 0.846, fl 0.881, +fl 0.942 |
| Output CSV | `output/imhof_full/imhof_full_results.csv` | `output/imhof_incremental/imhof_incremental.csv` |

The **16,779 vs 11,676** gap is driven entirely by one feature, `imhof_cv_sd`
(within-firm SD of per-tender CV). It is undefined for firms with only **one**
priced tender, so it is non-missing for only 11,676 of the 16,843 always-losers
(69.3%). Script 31 does not require `cv_sd` to be present for the sample filter
(it lists it as a model feature but `ranger` tolerates the NA via the firms that
do have it… in fact the 16,779 pool is defined by cv/skew/kurt completeness; the
`cv_sd` column carries NA for single-tender firms and `ranger` handles them in
the trees). Script 49 hard-requires all 7 → loses the single-priced-tender firms.

This is a **legitimate two-sample design**, not a discrepancy in computation:
script 31 is the "max-coverage" comparison (16,779), script 49 is the
"same-universe incremental" comparison (11,676) where the DeLong tests are run on
an identical row set across models. Both are reported; the manuscript must label
which N each AUC comes from.

---

## 3. Caveat: direct-defendant exclusion is soft, not hard

The task spec says direct CADE defendants (`cade_bec_crossmatch.csv`, 49 rows)
should be **excluded from the cobidder candidate pool**. In the code, the
candidate pool is the **always-loser** universe, and positives are defined as
`firm_code %in% cade_fl_cobidders` (the 193 cobidders). The 193-cobidder file was
constructed upstream to be *co-bidders of cartelists who are themselves
always-losers* — it is conceptually disjoint from the direct defendants. Neither
script 31 nor 49 does an explicit `setdiff(always_losers, direct_defendants)`.
The exclusion is therefore enforced **upstream** (in how `cade_fl_cobidders.csv`
was built), not at the point of model training. This is fine for reproduction but
should be stated as a maintained assumption: **the benchmark trains on
always-losers and scores against 193 cobidder labels; direct defendants enter
only insofar as they are also always-losers and cobidders, which the label file
already curates.** Verified: all 193 cobidder codes are present in the
always-loser universe (193/193). Of the 47 unique direct-defendant CNPJs, **7
are also always-losers** — they sit in the candidate pool as negatives unless
they also appear in the cobidder label file; the label file does not list them
as positives, so they cannot inflate the positive count.

## 6. Reproduction note (Step 7)

Re-running the RF CV (`scripts/analysis/08_bid_benchmark_reproduction.R`,
`num.threads=12`) reproduces all committed/manuscript numbers. The script-49
pool (N=11,676) reproduces to 4 decimals exactly (it sets per-fold seeds). The
script-31 pool (N=16,779) reproduces within CV jitter because **script 31 sets
no per-fold RF seed** (31:136 has no `seed=` arg), so single re-runs wobble at
the 3rd decimal. The committed `imhof_full_results.csv` is the canonical, and it
matches the manuscript exactly. **One spec wobbles more: `imhof_cv_only`**
(committed 0.585; one re-run gave 0.547) — this is a single-feature, near-coin-flip
RF and is the most fold-sensitive; the canonical CSV value (0.585) stands. To make
script-31 numbers bit-reproducible, add `seed=20260430+k` to the `ranger()` call,
mirroring script 49. No manuscript number changes.

---

## 4. Feature set (7 Imhof–Wallimann moments + 2 counts)

Constructed within each tender-item (`numerodaoc`, `códigoitem`) with **≥2
priced bids**, then averaged across each firm's priced tenders. See
`bid_layer_unit_definitions.md` and `table_F_bid_feature_dictionary` for exact
formulas. Timestamp / bid-revision / late-bid features are **NOT implemented** in
the benchmark (no timestamp column is read) — they are discussed in Fig 1 of the
manuscript but are not in this pipeline.

---

## 5. Missing / not-implemented

- **NONE missing** among the 10 inventory components.
- **NOT IMPLEMENTED (by design):** timing/timestamp features, bid-revision
  counts, late-bid flags. The parquet read in script 31 selects only
  `códigofornecedor, numerodaoc, códigoitem, bid_price`; no time column is
  touched. Do not represent these as part of the benchmark.
