# Binary vs. Continuous Score — Section 5 Memo (v22 JLEO R&R)
_Generated 2026-06-05 by 05_section5_profile_monotonicity.R (seed 20260603)._

## Q1. Is the score <-> exposure relationship monotone?
- Cobidder prevalence vs. T_i-bin rank: Spearman = 0.945 -> prevalence rises monotonically with participation.
- BUT opportunity-adjusted EXCESS contact: Spearman(X_i) = 0.345, Spearman(Z_i) = -0.055.
  -> Excess is FLAT / non-monotone. Prevalence rises mechanically with exposure; the opportunity-adjusted
  residual does not track the rank in the same way, weakening a STRUCTURAL reading of T_i.

## Q2. Does FL14 outperform the continuous score in any sample?
- full always-loser:        continuous=0.7443 vs FL14=0.6516 -> continuous wins/ties
- opportunity common support: continuous=0.6660 vs FL14=0.6083 -> continuous wins/ties
- Reference (script 53, strict-timing): FL14 binary 0.767 > continuous 0.750, DeLong p=0.085 (NOT significant).
  The flip is SAMPLE-SPECIFIC (strict-timing common support), not a general dominance of the binary.

## Q3. Does T>=14 look structural?
- NO. T>=14 is median + 1.5*IQR of always-loser participation — an administrative/outlier cut,
  not a behavioral threshold. The continuous log(1+T_i) carries the signal; FL14 is a deployable rule.

## Q4. Emphasize continuous, binary, or both? Downgrade monotone-ranking claims?
- EMPHASIZE BOTH but frame honestly: continuous score is the underlying signal; FL14 is the
  operational rule (administrative cut). Where the strict-timing flip appears, report it but do NOT
  elevate the binary to a structural threshold.
- DOWNGRADE structural monotone-ranking claims: prevalence rises with exposure (mechanical), but
  opportunity-adjusted excess does not rise the same way. The rank is an exposure ranking, not a
  collusion-intensity ranking.

## Numbers (this run)
```
               sample        score_form     N positives roc_auc pr_auc prec_500
               <char>            <char> <int>     <int>   <num>  <num>    <num>
 1:           full_AL continuous_log1pT 35943       195  0.7443 0.0142    0.016
 2:           full_AL       fl14_binary 35943       195  0.6516 0.0142    0.016
 3:           full_AL     binned_decile 35943       195  0.7420 0.0142    0.016
 4:           full_AL        spline_ns4 35943       195  0.7443 0.0142    0.016
 5:   opp_common_supp continuous_log1pT 15134       195  0.6660 0.0228    0.024
 6:   opp_common_supp       fl14_binary 15134       195  0.6083 0.0228    0.024
 7:   opp_common_supp     binned_decile 15134       195  0.6651 0.0228    0.024
 8:   opp_common_supp        spline_ns4 15134       195  0.6661 0.0245    0.024
 9: excl_largest_case continuous_log1pT 35874       126  0.7436 0.0079    0.002
10: excl_largest_case       fl14_binary 35874       126  0.6526 0.0079    0.002
11: excl_largest_case     binned_decile 35874       126  0.7465 0.0079    0.002
12: excl_largest_case        spline_ns4 35874       126  0.7493 0.0085    0.010
```
