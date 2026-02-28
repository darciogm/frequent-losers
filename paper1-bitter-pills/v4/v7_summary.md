# V7 Extensions — Execution Summary

**Date:** 2026-02-28 12:34:12
**Total time:** 119.1 seconds (2 min)
**Hardware:** 16 cores, 16.6 GB RAM
**Threads:** fixest=16, data.table=16

## Task 1: Under the Gun — Missing Outcomes

Added to UTG section (IV: `is_admin`, Admin vs Litigated):

| Estimate | DV | Sample | Pub Table |
|----------|----|---------|-----------| 
| Ref Prices | bid_price_ref_log | UTG winners | t1_tab_utg_ref_prices.tex |
| Quantities | bid_qty_log | UTG winners | t1_tab_utg_quantities.tex |
| Firms (A+B) | ln_n_firms | UTG winners | t1_tab_utg_firms.tex |
| Success LPM (A+B) | po_firm_winner | UTG all obs | t1_tab_utg_success.tex |

## Task 2: Urgent Purchases — Litigated Only

Replicated all urgent regressions with IV: `litigated` (Litigated vs Ordinary, excluding Admin):

| Estimate | DV | Sample | Pub Table |
|----------|----|---------|-----------| 
| Ref Prices | bid_price_ref_log | Lit+Ord winners | t2_tab_ref_prices.tex |
| Quantities | bid_qty_log | Lit+Ord winners | t2_tab_quantities.tex |
| Neg Prices (A+B) | bid_price_log | Lit+Ord winners | t2_tab_neg_prices.tex |
| Firms (A+B) | ln_n_firms | Lit+Ord winners | t2_tab_firms.tex |
| Success LPM (A+B) | po_firm_winner | Lit+Ord all obs | t2_tab_success.tex |

## Timing Breakdown

| Step | Time (sec) |
|------|------------|
| Data loading | 11.9 |
| T1.1 UTG Ref Prices | 2.8 |
| T1.2 UTG Quantities | 1.9 |
| T1.3 UTG Firms | 3.4 |
| T1.4 UTG Success | 3.8 |
| T2.1 Lit Ref Prices | 2.2 |
| T2.2 Lit Quantities | 2.1 |
| T2.3 Lit Neg Prices Total | 2.2 |
| T2.4 Lit Neg Prices Direct | 2.2 |
| T2.5 Lit Firms Total | 1.8 |
| T2.6 Lit Firms Direct | 2.1 |
| T2.7 Lit Success Total | 2.0 |
| T2.8 Lit Success Direct | 2.3 |

## Files Generated

- **Pub tables (v7):** 9 .tex files in `v4/pub/tables_v7/`
- **Manuscript LaTeX (v7):** 14 .tex files in `v4/manuscript_v7/`
- **HTML results (v7):** 14 .html files in `v4/results_v7/`
- **Checkpoints:** 9 .rds files in `v4/checkpoints_v7/`

## Regressions Run

- **Task 1:** 24 regressions (6 outcome specs × 4 FE each = 24)
- **Task 2:** 32 regressions (8 outcome specs × 4 FE each = 32)
- **Total:** 56 regressions

