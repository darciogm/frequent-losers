# 19 — SUBPROMPT 8 LOG: Section 6A bid-layer benchmark audit & complementarity (JLEO R&R v22)

Date: 2026-06-03. Agent: mr-frequent-losers. Branch **`v22`** (R&R revision branch; Subprompts 1–7 committed; staying on it).

## SETUP / gates
Docs 00–18 + memos present. Sub4 RECONCILED, Sub5 B, Sub6 C+D (reframe to "Reach and Limits"), Sub7 B. NOT `SECTION6A_BLOCKED_BY_PRIOR_OUTPUTS`. §6A written under the reframe; honest framing = COMPLEMENTARITY at lower cost, NOT "outperforms".

## BID PIPELINE LOCATED + REPRODUCIBLE (not a blocker)
- **Data:** `v3/data/processed/bid_level_with_prices.parquet` (245 MB; bid_price per firm×tender-item).
- **Scripts:** `31_imhof_full_pipeline.R` (main; N=16,779 sample), `49_imhof_incremental_value.R` (N=11,676 same-sample), `26_auc_by_subsample.R`.
- **Model architecture:** within-tender Imhof–Wallimann MOMENTS (CV, skew, kurtosis, spread, min-max-log, second-lowest-dist) computed per tender-item (≥2 priced bids), aggregated to firm = mean across firm's priced tenders (+cv_sd, n_tenders_priced). Learner = **random forest (ranger, 500 trees, probability)**, **5-fold RANDOM CV, seed 20260430**. Candidate pool = always-losers with full Imhof feature set. Target = `is_cade` (193 cobidders).
- **Reproduced numbers (output/imhof_full/imhof_full_results.csv, N=16,779):** fl_alone(FL14) **0.921**, tenders_alone **0.884**, imhof_cv_only **0.585**, imhof_full **0.888**, imhof_full+fl **0.962**, imhof_full+tenders **0.962**. Macros: `\valImhofFLBin`=0.921, `\valImhofFLcont`=0.884, `\valImhofCVonly`=0.585, `\valImhofFull`=0.888, `\valImhofComboCont`=0.962, `\valImhofComboBin`=0.955, `\valImhofPoolN`=16,779.
- **N=11,676 same-sample (script 49, output/imhof_incremental/imhof_incremental.csv):** imhof_full 0.846, fl 0.881, tenders 0.877, imhof+fl **0.942** (Δ+0.096, DeLong p=1.15e-26), imhof+tenders 0.944. Macros `\valAUCImhofFull`=0.846, `\valAUCImhofPlusFL`=0.942, `\valAUCImhofPlusTC`=0.944.

## CRITICAL AUDIT ANGLES (the honest story to surface)
1. **FL alone (0.921) ≈/beats imhof_full (0.888)** on N=16,779 → "comparable discrimination at lower informational cost" is FAIR; "outperforms" is NOT (overlapping CIs; flips by sample: N=11,676 has imhof_full 0.846 < fl 0.881).
2. **Random CV folds** while labels cluster by CADE case (Sub6: one case=55% positives) → pooled AUC is OPTIMISTIC. Must re-run **case-grouped folds (Design E LOCO)**.
3. **Feature-target overlap:** firm bid features include the label-defining tenders (where the firm co-bid with defendants). **Design F (exclude label-defining tenders)** tests contamination.
4. **Combined model (0.962/0.942) = full-observability UPPER BOUND** (requires bid recovery) — NOT a first-stage operational screen.
5. **Learner is RF, not logit** — manuscript must say "Imhof–Wallimann-style moments in a random forest," not imply a canonical Imhof model.
6. Two samples (16,779 vs 11,676) — disclose B2 cross-sample.

## EXPECTED VERDICT: **E (leakage-sensitive forensic-stage diagnostic) + B (complementarity attenuates under case-grouped folds / excluding label-defining tenders).** Pooled = full-observability diagnostic; honest complementarity is "partially non-overlapping info on the same target," bounded.

## EXECUTION (fan-out, 2 parallel empirical + 2 writers)
- **E1 (inventory/dictionary/support/reproduce):** Steps 3–7. bid_pipeline_inventory.md, bid_layer_unit_definitions.md, feature dictionary (Table F), support/missingness (Table O), reproduce numbers.
- **E2 (model audit/validation designs/performance/complementarity/leakage):** Steps 8–15. model audit doc + Table P; Designs A (pooled), E (case-grouped LOCO), F (exclude label-defining tenders), G (environment holdout); Table Q performance (+PR/precision/recall/lift); Table R complementarity (rank corr + top-k overlap + incremental); Table S leakage; calibration.
- W1 (§6.1 + tables O/P/Q/R/S + figs + macros + Fig 1 check); W2 (new Appendix I bid-benchmark). Me: claims scan, docs, completion report, build, verdict.

### Files read · data · scripts
Docs 00–18 + memos. scripts 31/49/26 + outputs (imhof_full_results.csv, imhof_incremental.csv). bid_level_with_prices.parquet. sec06 (§6.1 Imhof subsection, Table imhof_cost). Imhof macros in values.tex.

### Scripts created
`scripts/analysis/{07_bid_feature_audit, 08_bid_benchmark_reproduction, 09_bid_benchmark_validation}.R` (seed 20260603).

### Benchmark definitions / validation folds / leakage
Learner = RF (ranger 500 trees, prob), 7 firm-mean within-tender Imhof moments. Designs: A pooled-random (diagnostic), E case-grouped/LOCO, F exclude-label-defining-tenders, G environment holdout. Leakage: award clean; bid/combined full = diagnostic_only; bid/combined strict-timing = BLOCKED; LOCO = case-holdout.

### Results (Verdict E)
- Reproduced (N=16,779 within CV jitter; N=11,676 exact): FL 0.921, imhof_full 0.888, combined 0.962; all 193 positives retained.
- **Design E case-grouped:** bid ROC 0.891→0.810, PR-AUC 0.124→0.045 (−63%); combined ROC 0.936/PR 0.109; award unchanged (label-independent).
- **Design F excl-label-tenders:** bid 0.891→0.874 (−0.017, minor contamination).
- **Complementarity:** Spearman 0.42; top-500 overlap 17%; Δ PR-AUC adding award to bid +0.151 pooled → +0.064 case-grouped (p<0.001).
- Strength: FL 0.921 ≈ bid 0.888 (comparable at lower cost).

### Manuscript edits
- `sec06` §6.1 rewritten (RF not logit; PR-led; case-grouped caveat; complementarity bounded) + Tables O/P/Q/R/S + 2 figs. `values.tex` +18 \valBid*.
- NEW `sec_app09_bid_benchmark_submission.tex` (Appendix I, I.1–I.10, 10 tables + 2 figs) + \input in master.
- `make_submission_figures.R`: Fig 1 AUC annotations (0.888/0.903) REMOVED → pure info-cost diagram; regenerated.

### Commands run
`Rscript .../07,08,09_*.R` (07/08 ~9min RF reruns; 09 ~92s w/ feature cache); `Rscript make_submission_figures.R` (Fig 1 regen); `make diagnostics`; compile paper+appendix. No failures (E2 fixed 2 dev bugs pre-final-run).

### Build result
**PASS.** Paper **64pp** (was 59), appendix **55pp** (was 44). 0 errors, 0 undefined refs/cites, 0 undefined control sequences, 0 overfull >40pt. claims critical=0. Appendix I used adjustbox-OUTERMOST (avoided the App-H bug).

### Failures / blockers
- Bid strict-timing BLOCKED (within-tender moments not cleanly time-limitable).
- Minor: script 31 stale "logit" header + no per-fold seed (recommend seed=20260430+k; no number changes).
- Carried: conservative-AUC; B3; appendix length.
