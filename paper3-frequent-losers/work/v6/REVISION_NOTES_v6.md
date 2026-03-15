# Revision Notes --- v6
**Date:** 2026-03-15
**Target journal:** RAND Journal of Economics
**Reframe strategy:** Option B+C (Structural + Detection Tool)
**Based on:** work/rand_reframe_memo.html

## Summary of changes from v4

### New Section 3: Structural Model of Cover-Bidder Deployment
- Full game-theoretic model with cartel optimization (Equation 6)
- Three formal propositions with proofs:
  - P1: Optimal number of cover bidders (comparative statics)
  - P2/P3: Equilibrium cover-bid distributions under Regime 1 (uniform) and Regime 2 (normal)
  - P4: Market-selection prediction (cover bidding concentrates in competitive markets)
- Structural likelihood: supervised mixture model (known FL labels)
- Two-stage MLE: genuine bids (log-normal) + cover bids (regime-specific)
- BIC model selection between regimes
- Identification discussion mapping each parameter to data variation
- Six testable predictions mapped to empirical tests

### Rewritten Section 4: Data and FL Definition
- Kept: BEC platform, FL definition, sample construction
- Added 4.4: Structural estimation sample (40M bids description)
- Added 4.5: CADE validation sample (temporal split 2009-2014 / 2015-2019)
- Updated IQR footnote with ROC-derived optimal threshold connection

### Rewritten Section 5: Empirical Strategy (RAND standard)
- 5.1 Structural likelihood estimation (primary)
- 5.2 Reduced-form identification (OLS + IV reframed as bracketing)
- 5.3 Detection performance validation (ROC analysis)
- 5.4 Bajari-Ye corrected (n_bids excluded, placebo reframed)
- 5.5 Convite minimum-bidder RDD at R$80,000

### Abstract rewritten for RAND
- Leads with cover bidding as market failure
- States structural model in sentence 2
- References CADE validation
- Ends with welfare-maximizing threshold

### Network relabeling (FLAG 4)
- All "high-suspicion" → "concentrated-market"
- All "low-suspicion" → "competitive-market"
- Applied to all .tex files via sed

## Critical flags addressed

| Flag | Issue | Resolution |
|------|-------|------------|
| 1 | n_bids in BY first stage | Confirmed NOT in actual R code (only in manuscript text). sec5 explicitly excludes it with justification citing Bajari-Ye (2003, p.978) |
| 2 | CADE enforcement DiD | Script written; requires CADE conviction dates in data |
| 3 | Cross-fit attenuation | Script written; checking cache availability |
| 4 | Network split mislabeling | sed replacement applied to all v6 .tex files |

## Compilation
- paper_v6.pdf: 70 pages, 784K
- 0 LaTeX errors, 0 warnings
- Full compile with bibtex successful

## Items requiring author decision before submission
1. **Structural model parameters:** Run structural estimation on bid-level data. Fill [ESTIMATE] placeholders in sec4_data_fl.tex
2. **ROC analysis:** Run roc_detection.py and fill AUC/optimal threshold values
3. **RDD feasibility:** Check sample density near R$80,000 threshold
4. **CADE DiD:** If ATT(price) not significant, remove from primary narrative
5. **Abstract [X] and [Y]:** Fill markup and AUC from estimation output
6. **Missing bib entries:** Add Calonico-Cattaneo-Titiunik (2014), Cattaneo (2020) to references.bib
