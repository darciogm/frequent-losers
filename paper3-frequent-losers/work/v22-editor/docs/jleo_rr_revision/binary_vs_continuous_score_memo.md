# Binary vs. Continuous Score — Section 5 Memo (v22 JLEO R&R)
_Generated 2026-06-04 by 05_section5_profile_monotonicity.R (seed 20260603)._

## Q1. Is the score <-> exposure relationship monotone?
- Cobidder prevalence vs. T_i-bin rank: Spearman = 0.991 -> prevalence rises monotonically with participation.
- BUT opportunity-adjusted EXCESS contact: Spearman(X_i) = -0.255, Spearman(Z_i) = -0.927.
  -> Excess is FLAT / non-monotone. Prevalence rises mechanically with exposure; the opportunity-adjusted
  residual does not track the rank in the same way, weakening a STRUCTURAL reading of T_i.

## Q2. Does FL14 outperform the continuous score in any sample?
- full always-loser:        continuous=0.7608 vs FL14=0.6880 -> continuous wins/ties
- opportunity common support: continuous=0.6269 vs FL14=0.6040 -> continuous wins/ties
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
 1:           full_AL continuous_log1pT 16843       651  0.7608 0.1432    0.216
 2:           full_AL       fl14_binary 16843       651  0.6880 0.1432    0.216
 3:           full_AL     binned_decile 16843       651  0.7552 0.1432    0.216
 4:           full_AL        spline_ns4 16843       651  0.7608 0.1432    0.216
 5:   opp_common_supp continuous_log1pT  6040       651  0.6269 0.1857    0.242
 6:   opp_common_supp       fl14_binary  6040       651  0.6040 0.1857    0.242
 7:   opp_common_supp     binned_decile  6040       651  0.6209 0.1857    0.242
 8:   opp_common_supp        spline_ns4  6040       651  0.6289 0.1859    0.242
 9: excl_largest_case continuous_log1pT 16635       443  0.7634 0.0894    0.132
10: excl_largest_case       fl14_binary 16635       443  0.6902 0.0894    0.132
11: excl_largest_case     binned_decile 16635       443  0.7577 0.0894    0.132
12: excl_largest_case        spline_ns4 16635       443  0.7634 0.0894    0.132
13:   excl_largest_ig continuous_log1pT 15706       558  0.7588 0.1188    0.180
14:   excl_largest_ig       fl14_binary 15706       558  0.6843 0.0899    0.120
15:   excl_largest_ig     binned_decile 15706       558  0.7534 0.1029    0.140
16:   excl_largest_ig        spline_ns4 15706       558  0.7588 0.1188    0.180
```
