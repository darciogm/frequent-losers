# Early triage — script 13 SRP `within_stratum_auc` (0.867 / 0.713)

**Adjudicator:** Mr. Frequent Losers (reviewer mode) · **Date:** 2026-06-06 · **Status:** RESOLVED
**Verdict: DIFFERENT ESTIMAND (not a construction bug) — but NOT publishable next to script 02's
within column. The SRP `within_stratum_auc` column is `DO-NOT-PUBLISH`. The A7 answer rides on the
comparable rows (raw / exposure-only / FL32), which ARE cross-stratum consistent.**

---

## 1. What script 13's `within_stratum_auc` actually computes

Script 13 (`scripts/analysis/13_srp_stratified_validation.R`), function `cell_strat_auc`
(lines 159–169) + section D (lines 401–423):

- **Stratum axis = modal (year | buyer) administrative cell.** For each AL firm it picks the single
  `cell_id = paste(yr, pbu)` in which the firm participates most (modal cell, deterministic tiebreak
  on `cell_id`, line 405), then runs a pooled within-cell Mann–Whitney C-statistic over
  cobidder(+) vs non-cobidder(−) firm pairs **inside the same year×buyer cell**.
- **Score = pooled `log1p(tenders_count)`** (loss intensity), held fixed.
- **Evaluation sample = AL firms active in the stratum** (≥1 participation row in that modality):
  25,190 firms / 114 positives (pregão regular) and 20,461 / 165 (SRP). The 114+165 double-counts
  firms active in both modalities — fine for a per-stratum read, irrelevant to the estimand question.

This is a **year×buyer-cell C-statistic**. It does **not** condition on opportunity/exposure
intensity.

## 2. What script 02 / 12's "within" compute (the numbers being compared against)

- **Script 02 matched within = 0.462** (`02_…R` line 1130, `strat_auc(mf, "score_i", "cobidder",
  "exposure_stratum")`). Stratum = `exposure_stratum` from `exposure_stratified_matching_frame`
  (`utils/exposure_validation.R` L111–119) = **10 quantile bins of `log_opp`**, i.e. firm-level
  exposure to CADE-active (buyer×year×ig) cells. One stratum per firm, keyed on the **confound**.
- **Script 12 decile sweep within = 0.558** (`12_…R` L249–261). Stratum = 10 quantile bins of
  `E_i_loo` (LOO expected defendant contact), exposed firms only. Same family: **exposure-intensity
  bins**, not administrative cells.
- The manuscript's `\valExpWithinAUC = 0.471` and `\valFedAudWithinAUC` are this exposure-stratum
  estimand — the paper's honest "near chance after purging exposure" headline.

**So 02/12 stratify on the exact confound the audit exists to remove (exposure intensity); 13
stratifies on a year×buyer administrative cell that leaves exposure free to vary within cell.**
Different axis ⇒ different number. No referee whiplash is acceptable if both sit in the same table
under the same column name "within-stratum AUC."

## 3. Surgical pooled-sample check (`/tmp/triage13_pooled_check.R`)

Built 13's POOLED federal `al_opp` (no modality split: 1,064,212 rows; 35,943 active AL; 195 pos)
and ran BOTH estimators on the **identical population**:

| Estimator (POOLED federal, same firms) | AUC | comparable pairs |
|---|---|---|
| RAW pooled `log_tc` | **0.7443** | — |
| EXPOSURE-ONLY (`log_E`) | **0.9683** | — |
| **13-style within = modal (year\|buyer) cell** | **0.7938** | 4,802 |
| **02-style within = exposure decile** | **0.4639** | 146,076 |

Reference reported numbers: 02 matched-within = 0.462; 12 sweep-within = 0.558;
13 SRP-within = 0.867 / 0.713.

**Reading:** on one and the same population the 02-style estimator returns **0.4639** (reproduces
02's 0.462 to 3 decimals) while the 13-style estimator returns **0.7938** (same neighborhood as 13's
0.867/0.713). The divergence is **100% the stratification axis**, not the modality subsetting and
not a pair-construction bug — pairs are genuinely within-cell. **Conclusion: DIFFERENT ESTIMAND.**

### Why 13's number is high (and not a confound-purged residual)
- It barely moves off **raw** (0.744) and sits far from the exposure-purged 0.46. The year×buyer cell
  does **not** hold the exposure confound fixed, so the C-stat re-encodes most of the raw/exposure
  signal (exposure-only alone = 0.968). It is a raw-signal cousin, not an opportunity-adjusted one.
- **Pair starvation + concentration:** the modal-cell collapse keeps only **4,802** comparable pairs
  (vs 146,076 for the exposure-decile design — a ~97% information loss), and the **top-5 cells carry
  68.3%** of all comparable pairs. The statistic is dominated by a handful of dense year×buyer cells
  and is noise-fragile.

## 4. Are the comparable rows cross-stratum consistent? (the A7 payload)

Yes. From `outputs/comprasnet/tables/table_SRP_stratified.csv`:

| Column (comparable across strata) | pregão regular | SRP | gap |
|---|---|---|---|
| Raw AUC | 0.748 [0.704, 0.792] | 0.703 [0.667, 0.739] | 0.045 |
| Exposure-only AUC | 0.859 | 0.874 | 0.015 |
| FL32 AUC | 0.656 | 0.641 | 0.015 |
| PR-AUC | 0.014 | 0.016 | — |

All three substantive variants (raw, exposure-only, FL32) move **together** across the two pregão
variants — the consistency story A7 needs. **The within column is the ONLY one that diverges
wildly (0.867 vs 0.713, gap 0.154), precisely because it is a different, exposure-free, pair-starved
estimand — and the divergence there is an artifact of cell density, not economics.**

## 5. Manuscript-contamination check

`grep` over `submission_clean/`: the `\valFedAudSRPregWithinAUC` / `\valFedAudSRPsrpWithinAUC` macros
are generated into `table_SRP_stratified_macros.tex` but are **cited NOWHERE** in the manuscript. The
prose `\valFedAudWithinAUC` / `\valExpWithinAUC` slots all point at the **exposure-stratum** estimand
(0.471, "near chance"), which is correct and uncontaminated. **No contamination has occurred yet.**

## 6. VERDICT & required action

- **(i) Bug?** No. `cell_strat_auc` is correct for what it computes; pairs are genuinely within-cell.
- **(ii) Different estimand?** **Yes.** Exact definition: *"pooled within-(year×buyer)-cell
  C-statistic of pooled loss-intensity, evaluation sample = AL firms active in the modality, modal-
  cell assignment."* It is **NOT** comparable to script 02/12's within-(exposure-stratum) C-statistic
  and must never share a column header with it. It also fails the audit's purpose (does not condition
  on exposure) and is pair-starved/cell-concentrated.
- **(iii) A7 answer that survives:** rely on the **raw / exposure-only / FL32** rows, which are
  cross-stratum consistent (raw 0.748 vs 0.703; FL32 0.656 vs 0.641; exposure-only 0.859 vs 0.874).
  **A7 verdict: the loser-side concentration signal behaves CONSISTENTLY across the two federal pregão
  variants — raw discrimination gap = 0.045 (< 0.05), exposure-only and FL32 gaps ≈ 0.015. Pooling the
  two pregão variants does NOT hide heterogeneity in the signal.**

### Required labeling / suppression
1. **Mark `within_stratum_auc` in `table_SRP_stratified.csv` as DO-NOT-PUBLISH.** Drop the column from
   the SRP `.tex` table, or relabel it unambiguously as "within (year×buyer) C-stat — NOT the
   exposure-adjusted within of Table C/Appendix G; reported for completeness only" with an explicit
   tablenote that the comparable metric across platforms is the exposure-stratum within (§4 / App G).
2. **Do NOT emit `\valFedAudSRPregWithinAUC` / `\valFedAudSRPsrpWithinAUC` into prose.** Leave them
   out of `values.tex`. (Currently uncited — keep it that way.)
3. The SRP table CAN feed the manuscript **with the within column suppressed/relabeled**; the A7
   robustness leg stands on raw + exposure-only + FL32.

### Optional (only if a within-style row is wanted in the SRP table)
If a within row is desired for the SRP leg, recompute it on the **exposure-stratum** axis
(quantile bins of `log_E`, mirroring 02/12) so it is column-comparable. Per-stratum N+ (114/165) is
above the power floor but exposure-decile within at N+≈100–165 will be noisy; report with CI or as a
sensitivity, not as a headline. This is a >20-line change to script 13 (new estimator + table plumbing)
— **report, do not apply silently.**

---
*Check script: `/tmp/triage13_pooled_check.R`. SRP table: `outputs/comprasnet/tables/table_SRP_stratified.csv`.*
