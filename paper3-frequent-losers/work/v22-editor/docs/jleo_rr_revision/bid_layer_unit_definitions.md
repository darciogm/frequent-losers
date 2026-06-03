# Bid-Layer Unit Definitions (Step 4)

**Audit date:** 2026-06-03
**Scope:** units of observation in the bid-layer Imhof–Wallimann benchmark.
**Source scripts:** `scripts/31_imhof_full_pipeline.R`, `scripts/49_imhof_incremental_value.R`.

The bid layer has six nested units. Each is defined below with key identifiers,
row uniqueness, and its relationship to the award-layer tender-item IDs and the
CADE labels.

---

## 1. Bid row (raw)
- **File:** `v3/data/processed/bid_level_with_prices.parquet` (245 MB).
- **Key identifiers:** `códigofornecedor` (firm) × `numerodaoc` (OC sequence) ×
  `códigoitem` (item) × `bid_price`.
- **Row = one priced bid** by one firm on one tender-item.
- **Uniqueness:** NOT guaranteed unique on (firm, OC, item) — a firm may have
  multiple bid records on the same item (e.g. across phases/rounds). The pipeline
  pools all priced bids per tender-item; downstream `firm_tender` uses
  `DISTINCT firm × OC × item`.
- **Valid-bid filter:** `bid_price IS NOT NULL AND bid_price > 0` (31:53, 49:49–50).
- **Relationship to award layer:** `(numerodaoc, códigoitem)` is the **same**
  tender-item key used by the award-layer screen (`BEC_collapse_final`,
  `LOSERS_rebuilt`). This is the linkage seam between bid layer and award layer.

## 2. Tender-item unit (bid-moment construction unit)
- **Key:** `(numerodaoc, códigoitem)`.
- **Row = one tender-item** with ≥2 priced bids (`HAVING COUNT(*) >= 2`,
  49:63; `if (.N < 2)` → NA in 31:56). Tender-items with <2 priced bids yield
  NA moments and drop out.
- **Uniqueness:** one row per `(numerodaoc, códigoitem)` after the `GROUP BY`.
- **What is computed here:** the within-tender bid-distribution moments
  (cv, skew, kurt, spread, min_max_log, second_lowest_dist) — see feature
  dictionary. These are properties of the **competitive field on that item**,
  not of any single firm.
- **Relationship to award layer:** identical key; this is where bid-layer
  moments could in principle be joined back to award-layer outcomes. They are
  **not** computable from the award layer (which has no per-bid prices) → see
  `can_be_computed_from_award_layer = NO`.

## 3. Firm-tender-item unit
- **Key:** `(firm_code, numerodaoc, códigoitem)`, DISTINCT.
- **Row = one firm's participation on one tender-item**, carrying that
  tender-item's moments (31:84–86 merge; 49:121–136 `firm_tender` CTE).
- **Uniqueness:** DISTINCT-enforced; one row per firm × OC × item.
- **Purpose:** bridges the tender-item moments to firms so they can be averaged
  to firm level. The moment values are **shared** across all firms on the same
  tender-item (they describe the field, not the firm).

## 4. Firm-level unit (the modeling unit)
- **Key:** `firm_code` (14-digit CNPJ root, zero-padded in script 49;
  `as.character` in script 31 — codes are already 14-digit so equivalent).
- **Row = one firm**, with the **mean** of its per-tender moments across all its
  priced tenders (31:88–97; 49:137–149), plus `n_tenders_priced` (count) and the
  award-layer signals `tenders_count` and `is_fl`.
- **Uniqueness:** one row per firm.
- **This is the unit the random forest is trained and scored on.**
- **Aggregation rule:** firm-mean across the firm's priced tenders (`AVG(cv)`
  etc.). `imhof_cv_sd` = SD of cv across the firm's tenders (undefined for
  single-tender firms → drives the 16,779 vs 11,676 sample gap).

## 5. Common bid-feature pool (the validation sample)
- **Definition:** always-losers with complete Imhof features.
  - **Script 31 pool: N = 16,779** — complete `cv`, `skew`, `kurt`
    (31:116–118). 193 positives.
  - **Script 49 pool: N = 11,676** — complete **all 7** features incl `cv_sd`
    (49:170–172) + non-NA `tenders_count`. 193 positives.
- **Restriction = always-loser ∩ complete-Imhof-features.** Always-losers are
  firms with `win_rate == 0` across 2009–2019 (`FREQ_PARTICIP_rebuilt`,
  `always_loser == 1`, 16,843 firms).
- **Relationship to CADE labels:** positive = `firm_code ∈` the 193
  `cade_fl_cobidders`. **All 193 cobidders are always-losers and all 193 are
  retained in BOTH pools** (verified). Support loss (16,843 → 16,779 → 11,676)
  is entirely on the **negatives / FL count**, never on the positives.

## 6. Validation / scoring unit
- **Out-of-fold firm prediction:** each firm gets one held-out predicted
  probability from the fold in which it is the test set (5-fold random CV,
  31:128–140, 49:182–201). AUC and DeLong tests are computed on these
  out-of-fold firm-level predictions against `is_cade`.

---

## Relationship to direct-defendant / cobidder status (CRITICAL)

| Group | File | N | Role in benchmark |
|---|---|---|---|
| Direct CADE defendants | `cade_bec_crossmatch.csv` | 49 | **EXCLUDED from the cobidder candidate pool.** They are firms named directly in CADE cases. The positive label is *cobidders*, not defendants. The 193-cobidder label file was curated upstream to be disjoint from direct defendants; neither script does a hard `setdiff`, so the exclusion is a **maintained upstream assumption** (see inventory §3). |
| Always-loser cobidders | `cade_fl_cobidders.csv` | 193 (193 unique codes) | **The positive class.** Firms that co-bid with cartelists *and* are themselves always-losers. All 193 ∈ always-loser universe; all 193 retained in both pools. |
| Always-losers | `FREQ_PARTICIP_rebuilt` (`always_loser==1`) | 16,843 | **The candidate pool** (negatives + the 193 positives). |
| Frequent losers (FL14) | `tenders_count >= 14` | 2,735 | A within-pool flag (`is_fl`), an award-layer feature — **not** the candidate pool. In the 16,779 pool, 2,733 are FL14 (2 lost to feature missingness). |

**Bottom line:** the modeling unit is the **firm**; the positive label is the
193 **always-loser cobidders**; direct defendants (49) are excluded from the
candidate pool by upstream label curation; support loss falls only on negatives.
