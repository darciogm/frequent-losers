# Bid-layer benchmark — model audit (Step 8)

_Generated 2026-06-03 13:38:09 by `09_bid_benchmark_validation.R` (seed 20260603). Numbers are from this run; never invented._

## Specification
- **Learner**: random forest (ranger, 500 trees, `probability=TRUE`), num.threads=12.
- **Outcome**: `is_cade` (1 = 193-file CADE cobidder, in candidate pool, not a direct defendant).
- **Candidate pool**: always-losers with COMPLETE Imhof feature set, direct CADE defendants excluded. N=16,731, positives=190.
- **Features (7, firm-mean of within-tender moments)**: imhof_cv_mean, imhof_cv_sd, imhof_skew_mean, imhof_kurt_mean, imhof_spread_mean, imhof_minmax_mean, imhof_second_low_mean.
- **Standardization**: none (RF is scale-invariant).
- **Hyperparameter tuning**: none (fixed 500 trees, default mtry).
- **Default CV**: 5-fold RANDOM (the PROBLEM — CADE labels cluster by case, so random folds let a case's positives co-train).
- **Direct defendants**: excluded from the candidate pool (they define defendant tender-items).
- **Bid features DO include label-defining tenders** (co-appearance with defendants) — contamination risk, tested in Design F.
- **No future-info control** in the bid features (full-period within-tender moments).
- **Same target** as the award score; **same sample** (minus feature-incomplete firms).

## 20 questions
1. **What is the learner?** RF (ranger, 500 trees, probability forest).
2. **Is it tuned?** No — fixed 500 trees, default mtry/min.node.size, no grid search.
3. **What is the outcome?** Binary `is_cade` (193-file cobidder in pool, not a defendant).
4. **What is the candidate pool?** Always-losers with complete Imhof features, defendants excluded (N=16,731, 190 positives).
5. **What are the features?** 7 firm-mean within-tender bid-distribution moments (CV, CV-sd, skew, kurtosis, spread, min-max-log, second-lowest-distance).
6. **Standardized?** No (RF scale-invariant).
7. **Missingness?** Listwise — pool restricted to firms with complete Imhof features.
8. **Default validation?** 5-fold RANDOM CV. Reproduces bid AUC=0.891, combined AUC=0.958 (vs script-31 0.888/0.962).
9. **Why is random CV a problem?** CADE positives cluster by case; random folds put same-case positives in train and test, so the RF can memorize case-specific bid signatures.
10. **Does case-grouped CV change it?** Yes — Design E pooled bid AUC=0.810, combined AUC=0.936.
11. **Do bid features include label-defining tenders?** Yes by default (firm-mean over ALL its tenders, including defendant-co-appearance tenders).
12. **What happens excluding them?** Design F bid AUC=0.874 (vs 0.891 pooled); contamination delta=-0.017.
13. **Same target as award score?** Yes — both predict `is_cade`.
14. **Same sample?** Award uses the full always-loser pool; RF restricts to complete-feature firms (a subset). Table Q reports each on its own N.
15. **Are direct defendants in the pool?** No — excluded (they define the labels).
16. **Is there a future-info control?** No for bid features (full-period moments). Award has a strict-timing variant (Sub6); bid strict-timing is BLOCKED (cannot re-derive within-tender moments on a time-limited panel cleanly).
17. **Is the complementarity real?** Pooled yes (Table R), but it is a full-observability diagnostic with random-CV optimism — see how it changes under Design E.
18. **What is the operational interpretation?** Bid/combined RF are rich-data FORENSIC benchmarks (need all within-tender bids); NOT first-stage triage.
19. **What is the legal interpretation?** Flags/prioritizes a limited 193-cobidder target; NOT proof of cartel role.
20. **What is the headline risk?** Two: (a) random-CV optimism (case clustering), (b) label-defining-tender contamination. Both quantified in Designs E and F.

## Cross-references
- Award opportunity-adjusted within-AUC 0.7715 / +0.0415 (Sub5, script 76).
- Award strict-timing temporal holdout (Sub6).
- See Table Q (performance by design), Table R (complementarity), Table S (leakage audit).
