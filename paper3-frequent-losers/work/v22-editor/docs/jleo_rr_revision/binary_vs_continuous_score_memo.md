# Binary vs. Continuous Score — Section 5 Memo (v22 JLEO R&R)
_Generated 2026-06-03 by 05_section5_profile_monotonicity.R (seed 20260603)._

## Q1. Is the score <-> exposure relationship monotone?
- Cobidder prevalence vs. T_i-bin rank: Spearman = 0.917 -> prevalence rises monotonically with participation.
- BUT opportunity-adjusted EXCESS contact: Spearman(X_i) = -0.227, Spearman(Z_i) = -0.927.
  -> Excess is FLAT / non-monotone. Prevalence rises mechanically with exposure; the opportunity-adjusted
  residual does not track the rank in the same way, weakening a STRUCTURAL reading of T_i.

## Q2. Does FL14 outperform the continuous score in any sample?
- full always-loser:        continuous=0.9386 vs FL14=0.9236 -> continuous wins/ties
- opportunity common support: continuous=0.8635 vs FL14=0.8417 -> continuous wins/ties
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
 1:           full_AL continuous_log1pT 16843       191  0.9386 0.1264    0.130
 2:           full_AL       fl14_binary 16843       191  0.9236 0.1264    0.130
 3:           full_AL     binned_decile 16843       191  0.9279 0.1264    0.130
 4:   opp_common_supp continuous_log1pT  6040       191  0.8635 0.1450    0.138
 5:   opp_common_supp       fl14_binary  6040       191  0.8417 0.1450    0.138
 6:   opp_common_supp     binned_decile  6040       191  0.8455 0.1450    0.138
 7: excl_largest_case continuous_log1pT 16739        87  0.9293 0.0365    0.040
 8: excl_largest_case       fl14_binary 16739        87  0.9236 0.0365    0.040
 9: excl_largest_case     binned_decile 16739        87  0.9241 0.0365    0.040
10:   excl_largest_ig continuous_log1pT 15706       148  0.9349 0.0808    0.088
11:   excl_largest_ig       fl14_binary 15706       148  0.9245 0.0728    0.078
12:   excl_largest_ig     binned_decile 15706       148  0.9257 0.0714    0.076
```
