# Revision Notes — v6
**Date:** 2026-03-15
**Target journal:** RAND Journal of Economics
**Reframe strategy:** Option B+C (Structural + Detection Tool)
**Based on:** work/rand_reframe_memo.html

## Summary of changes from v4/v5

### New Section 3: Framework for Cover-Bidder Deployment
- Full structural model of cover-bidder deployment (replaces taxonomic "Conceptual Framework")
- Cartel's optimization problem with formal objective function and constraints
- 3 propositions with arguments: optimal m*, Regime 1 (uniform), Regime 2 (normal)
- Market selection proposition: cover bidding concentrates in competitive markets
- Structural likelihood: supervised mixture model (genuine vs. cover bids)
- Identification discussion for each structural parameter
- 5 testable predictions mapped to empirical tests

### Rewritten Section 4: Data and FL Definition
- Added: Structural estimation sample description (bid-level data)
- Added: CADE validation sample (temporal split 2009-2014 / 2015-2019)
- Added: Forward reference to optimal IQR threshold from ROC analysis (AUC=0.94)
- Updated: bid dispersion discussion to match structural estimation results

### Rewritten Section 5: Empirical Strategy
- Three-tier structure: structural estimation → reduced-form → detection validation
- Structural MLE estimation procedure (two-stage, bootstrap SEs)
- IV reframed as bracketing device (upper bound), not primary identification
- Detection validation with ROC analysis and Imhof comparison
- Corrected Bajari-Ye: n_bids excluded from first stage, placebo reframed
- RDD at R$80K removed (no first-stage discontinuity in BEC data)

### New Section 7: Restructured Results
- 7.1 Structural estimation results (Regime 2 selected, sigma_c/sigma_g = 0.72)
- 7.2 Detection performance (AUC = 0.94, Youden's J = 0.84 at 1.45x)
- 7.3 OLS and IV results (OLS=0.064, IV=0.194)
- 7.4 Network-split heterogeneity (competitive-market FL: 0.126)
- 7.5 Bajari-Ye tests (KS D=0.15, pairwise product=5.16)
- 7.6 Regime test (BIC selects Regime 2, ΔB IC = -91,473)

### Abstract
- Rewritten to lead with structural model contribution
- AUC = 0.94 cited explicitly
- Detection threshold framed as welfare-maximizing

### Introduction
- Section roadmap updated to match new structure

## Structural Estimation Results (structural_params.csv)

| Parameter | Estimate | Bootstrap SE | 95% CI |
|-----------|----------|-------------|--------|
| mu_g (genuine mean) | 4.059 | — | — |
| sigma_g (genuine SD) | 1.642 | — | — |
| R² (genuine FE regression) | 0.772 | — | — |
| N genuine | 23,177,905 | — | — |
| N FL | 189,381 | — | — |
| delta_hat (R1: max spread) | 6.397 | 0.098 | [6.193, 6.572] |
| epsilon_hat (R2: mean spread) | 0.831 | 0.005 | [0.823, 0.841] |
| sigma_c (R2: cover SD) | 1.187 | 0.012 | [1.167, 1.206] |
| BIC Regime 1 | 640,559 | — | — |
| BIC Regime 2 | 549,086 | — | — |
| **Selected** | **Regime 2** | — | — |
| sigma_c / sigma_g | 0.72 | — | — |

## ROC Detection Results (roc_detection_full.csv)

| Metric | Value |
|--------|-------|
| AUC | 0.937 |
| Optimal multiplier (Youden's J) | 1.45x |
| Youden's J at optimum | 0.843 |
| Baseline (1.5x) TPR | 1.000 |
| Baseline (1.5x) FPR | 0.157 |

## Critical flags addressed

| Flag | Issue | Resolution |
|------|-------|------------|
| 1 | n_bids in BY first stage | Script: flag1_bajari_ye_corrected.R (excludes n_bids) |
| 2 | CADE enforcement DiD | Script: flag2_cade_enforcement_did.R |
| 3 | Cross-fit attenuation | Script: flag3_crossfit_check.R |
| 4 | Network split mislabeling | Already resolved (no high/low-suspicion labels in v6) |

## Items requiring author decision before submission

### CRITICAL: Structural estimation
1. **Regime selection**: BIC selects Regime 2 (coordinated cover bidding).
   - sigma_c = 1.19 < sigma_g = 1.64 → FL bids LESS dispersed than genuine
   - This is consistent with cover bidders calibrating near a focal point
   - Manuscript text updated to reflect Regime 2 selection
   - **Decision**: Verify this is economically plausible for BEC context

2. **Estimation sample**: Used v3/bid_level_analysis.parquet (23.2M genuine, 189K FL).
   Re-estimation on full bid_level_full.parquet (40M rows) may refine estimates.

3. **Raw markup implausible**: The unconditional price gap (1328%) is not meaningful.
   The controlled OLS estimate (6.4%) is the appropriate comparison for the structural markup.

### Other decisions
4. **CADE enforcement DiD**: Review for statistical significance
5. **Cross-fit attenuation**: Review fold-level stability
6. **Bootstrap replications**: Currently 100 reps; increase to 500 for submission
7. **Missing bib entries**: Add Calonico-Cattaneo-Titiunik (2014) if RDD analysis added later
