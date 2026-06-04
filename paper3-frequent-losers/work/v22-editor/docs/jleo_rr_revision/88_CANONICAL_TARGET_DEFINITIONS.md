# 88 — CANONICAL TARGET DEFINITIONS (JLEO final optimization)

**Date:** 2026-06-04 · **Author:** Mr. Frequent Losers (FINAL OPTIMIZATION MODE)
**Builder:** `scripts/analysis/00_build_canonical_validation_targets.R`
**Outputs:** `outputs/targets/canonical_firm_labels.csv`, `canonical_case_labels.csv`,
`canonical_target_counts.csv`; `outputs/diagnostics/target_construction_assertions.csv`,
`target_set_comparisons.csv`.

**Hard rule enforced throughout:** no target that uses FL14 / frequent-loser status to
define positivity can serve as the main validation target. The FL flag appears in the
labels file only as the *score under evaluation*, never as a label ingredient.

---

## Target A — Direct CADE defendants (legal anchors)

| Field | Value |
|---|---|
| Candidate universe | All BEC firms in `firm_tender_map.parquet` (distinct `códigofornecedor` ≠ '-1') |
| Positive-label rule | CNPJ (14-padded) appears in `cade_bec_crossmatch.csv` (adjudicated CADE procurement-cartel defendants matched to BEC by exact CNPJ) AND is present in `firm_tender_map` (BEC-active) |
| Exclusion of direct defendants | n/a (this IS the defendant set) |
| Unit of count | Unique firms |
| FL status used? | **No** |
| Timing rule | Full CADE portfolio (12 cases, any judgment date) |
| Sample window | BEC 2009–2019 |
| Source script | `00_build_canonical_validation_targets.R` (logic verbatim from `01_label_funnel_reconciliation.R` S1) |
| Source data | `cade_bec_crossmatch.csv` × `firm_tender_map.parquet` |
| Current count | **41** BEC-active (48 distinct crossmatch CNPJ; manuscript `\valDirectCADE` = 47) |
| Role in paper | Legal anchors that define exposure; NOT the target of the zero-win loser-side screen (the screen scores zero-win firms; defendants mostly win) |
| Legal interpretation | Adjudicated defendants in CADE rulings; the only firms with adjudicated liability |

## Target B — Broad always-loser cobidder target (MAIN, adjudication-anchored exposure)

| Field | Value |
|---|---|
| Candidate universe | All BEC firms with `W_i = 0` over the 2009–2019 award-record window (always-losers, `firm_loss_stats.always_loser == 1`; n = 16,843) |
| Positive-label rule | Firm shares ≥ 1 BEC tender-item (`numerodaoc` × `códigoitem`) with ≥ 1 BEC-active direct CADE defendant |
| Exclusion of direct defendants | **Yes** — defendants excluded from candidate labels (assertion T1) |
| Unit of count | Unique firms |
| FL status used? | **No** (assertion T3) |
| Timing rule | Full 12-case portfolio, any judgment date; retrospective adjudication anchors |
| Sample window | BEC 2009–2019 |
| Source script | `00_build_canonical_validation_targets.R` (verbatim from `01_…R` S2–S4) |
| Source data | `firm_tender_map.parquet`, `firm_loss_stats.parquet`, `cade_bec_crossmatch.csv` |
| Current count | **651** unique always-loser cobidders |
| Role in paper | **Main validation target** for the award-layer score |
| Legal interpretation | Adjudication-anchored exposure (shared tender-items with adjudicated defendants) — NOT cartel membership, NOT liability |

## Target C — Narrow cartel-tender always-loser cobidder target

| Field | Value |
|---|---|
| Candidate universe | All BEC firms with `W_i = 0` |
| Positive-label rule | Firm shares a tender-item with a BEC-active direct defendant **within a cartel-relevant tender-item subset** |
| Status | **NOT REPRODUCIBLE.** The historical narrow restriction (static `cade_fl_cobidders.csv`, 193 rows) used an undocumented "cartel-tender" filter (`tenders_with_cade`) whose builder is absent from the repo. No current data file defines a cartel-relevant tender-item subset independent of that archived builder. |
| FL status used (historical file)? | **Yes — the static file is FL-only (all 193 rows `is_FL = TRUE`), which is exactly the circularity this repair eliminates** |
| Decision | **Cannot be the main target** (prompt hard rule + decision rule Case 2). The static 193 file is retained only as `target_source_flag = static_archived` for internal set comparison; it does not define any submitted label. |

## Target D — Conservative pre-2020 benchmark

| Field | Value |
|---|---|
| Definition | **Identical to Target B** (broad always-loser cobidder), restricting CADE cases to judgment date ≤ 2020-12-31 (4 cases) |
| Held fixed | The cobidder definition and stratum are the SAME as the main target — definition is never switched between main and conservative comparisons (assertion T6) |
| Current count | **208** unique always-loser cobidders; **19** BEC-active direct defendants in conservative cases |
| Role in paper | Conservative robustness benchmark (anticipation/look-ahead concern) |

## Target E — Timing target

| Field | Value |
|---|---|
| Definition | Target B labels used in train-2009–2016 / test-2017–2019 and rolling-origin evaluations |
| Label nature | **Retrospective adjudication anchors** — CADE judgments are NOT legally observable at the screening date for most cases; the paper must state this and never claim real-time legal knowledge |
| Derived fields | `first_cobid_year`, `last_cobid_year` (from `numerodaoc` chars 12–15) identify when the exposure contact occurs; firms with no pre-2017 history are unrankable entrants |
| Role in paper | Strict-timing validation (Table 4); incumbent-firm triage only |

## Target F — Bid-feature common-support target

| Field | Value |
|---|---|
| Definition | Target B labels restricted to always-loser firms with complete Imhof bid-feature support (`outputs/cache/imhof_firm_features.parquet`) |
| Role in paper | Explains why bid-benchmark and cost-recall positives are smaller than the main-label count (historically 190/191 vs 193 under the old label; new counts emitted by the builder as `bid_feature_support` × `broad_cobidder`) |
| Source | Builder joins the canonical labels to the bid-feature support set; no new estimation |

---

## Universe constants (reproduced, for reference)

| Object | Count | Source |
|---|---|---|
| All BEC firms | 41,443–41,444 | `firm_tender_map` distinct ≠ '-1' |
| Always-losers (W_i = 0) | 16,843 | `firm_loss_stats.always_loser == 1` |
| Frequent losers (FL14, score stratum — NOT a label) | 2,735 | `FREQ_PARTICIP_rebuilt`, `tenders_count ≥ 14` |
| CADE cases | 12 | `cade_carteis_licitacoes_2009_2019.csv` |
| Defendant tender-items | 52,013 | ftm × crossmatch |
| Static archived narrow file (internal comparison only) | 193 | `cade_fl_cobidders.csv` row count |
| Broad FL-stratum cobidders (descriptive only — never a validation label) | 341 | scripted |
