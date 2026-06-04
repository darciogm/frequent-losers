# NEW NUMBERS MAP — canonical broad AL label (651) regeneration, 2026-06-04

**Authoritative source for ALL manuscript number rebinding.** Every number below is read from
a regenerated CSV under `outputs/` (path given). DO NOT use any number not in this map or not
readable from a regenerated output. Old-label numbers (0.946/0.7715/+0.0415/0.924-vs-cobidders/
0.921/0.888/0.962/55%/−71%/131/193/191/190 as positives) are DEAD unless explicitly retained
below with context.

## Label & funnel (canonical_target_counts.csv; outputs/targets/)

| Object | New value | Old (dead) |
|---|---|---|
| Main target: broad AL cobidders | **651** | 193 |
| Composition: FL14 among positives | 341 (52.4%) | — |
| Composition: non-FL among positives | 310 (47.6%) | — |
| Candidate universe (always-losers) | 16,843 | same |
| BEC-active direct defendants | 41 (48 crossmatch; 47 cited \valDirectCADE) | same |
| Conservative (judged ≤2020-12-31, SAME def) | 208 cobidders / 19 crossmatch defendants | 208/19 (def-consistent now) |
| Defendant tender-items | 52,013 | same |
| Timing: rankable-incumbent positives | 498 | — |
| Timing: unrankable entrant positives | 153 (23.5% of 651) | 45/193 (23%) |
| FL14 universe | 2,735 | same |
| Derived enrichment (from canonical counts): P(cobidder|FL14)=341/2735=12.5% vs P(cobidder|non-FL AL)=310/14,108=2.2% → ratio ≈5.7×; P(FL|cobidder)=52.4% vs P(FL|non-cobidder AL)=14.8% → ≈3.5× | | replaces \valCADEenrich 3.95%/1.24%/3.2× framing if used |

## Table 3 — opportunity-adjusted (outputs/tables/main/table_C_opportunity_adjusted_validation.csv)

| Quantity | New | Old (dead) |
|---|---|---|
| Raw log_tc: ROC [CI] | **0.761** [0.741, 0.780] | 0.946 |
| Raw log_tc: PR-AUC | 0.143 [0.122, 0.168] | — |
| Raw log_tc: prec@500 / rec@500 / lift@500 | 0.216 / 0.166 / 5.59 | 0.130 / 0.340 / 11.46 |
| Raw FL14: ROC | 0.688 [0.669, 0.707] | 0.924 |
| Raw FL14: PR-AUC / prec@500 | 0.097 / 0.128 | — |
| Exposure-only logit (exposed n=6,040): ROC | **0.713** | 0.8467 |
| Exposure-only: PR-AUC | 0.300 | — |
| Exposure-only unconditional (all AL): ROC | 0.9045 | 0.946 (exp-only) |
| Nested exposure+score: ROC | 0.723 | 0.8882 |
| Nested increment | **+0.0100, DeLong p=0.0129** | +0.0415, p=2.08e-06 |
| Within-opportunity-stratum log_tc | **0.4705 (≈chance)** | 0.7715 |
| Within-stratum FL14 | 0.5065 | 0.7709 |
| Score ranks excess contact 1[O−E>0] (475 pos) | 0.764 | — |
| CEM matched AUC (n=6,039, support 100%) | 0.626 | — |
| Within-stratum dP(cobidder) FL14 vs non | **−0.0172 (negative)** | +(old) |
| Combined score+logE (mechanically inflated, report-only) | 0.985 / PR 0.708 | 0.98 |

## Permutations (outputs/tables/main/table_D_opportunity_permutation_validation.csv)

| Test | New | Old (dead) |
|---|---|---|
| B pure-exposure null: obs PR 0.143 vs null mean 0.264 | **p=1.00** (exposure null beats score) | p=1.00 (same direction) |
| C matched-stratum label perm: obs PR 0.143 vs null 0.137 | **p=0.127 — NOT significant** | p=0.023 (sig) |
| FL enrichment within matched strata | obs 3.23 vs null 3.16, **p=0.067 — NOT significant** | p<0.001 |

**⇒ HEADLINE REVERSAL: there is NO robust residual signal net of opportunity under the
non-circular label.** The only marginal positive is the nested +0.010 (p=0.013); within-stratum
AUC is chance, matched permutation ns, FL-enrichment ns, matched dP negative. Prose must say
the residual is "fragile/marginal at best and not robust across designs" — NOT "limited but
statistically reliable".

## Table 4 — timing (table_D_strict_2009_2016_to_2017_2019.csv, table_E_rolling_origin_validation.csv)

| Design | New | Old (dead) |
|---|---|---|
| Strict full test universe (41,444; 651 pos): ROC | **0.474 (below chance)**, PR 0.0137, prec@500=rec@500=0 | 0.55 / 0.005 / 0 |
| Strict rankable (32,682; 498 pos): ROC | 0.471, prec@500=0 | — |
| Strict training-AL pool (21,819; 651 pos): cont ROC | **0.684**; FL binary 0.646 | 0.750 / 0.767 |
| Entrant share of positives | 23.5% (153/651) | 23% (45/193) |
| Tie-at-zero share (full universe) | 24.6% | ~25% |
| Rolling origin 2014–2019 full universe | ROC 0.45–0.50; prec@500=rec@500=0 ALL years; worst 2015 ROC 0.446 | worst 0.497; zeros same |
| Rolling train_AL pool ROC | 0.66–0.70 | — |

## Case composition (table_G/_H, case_dominance; script 04 log)

| Quantity | New | Old (dead) |
|---|---|---|
| Largest case (trens_metros) share of positives | **32.0%** (208/651) | 54.7% |
| Largest case share of TP@500 | 45.4% | 72.3% |
| Full pooled: ROC / PR / prec@500 / rec@500 | 0.761 / 0.143 / 0.216 / 0.166 | 0.939 / 0.126 / 0.130 / 0.342 |
| Drop largest case: PR | **0.0895 (−37%)**; prec@500 0.132; rec@500 0.149; ROC 0.763 (stable) | 0.036 (−71%); 0.040 |
| Drop top two: PR / prec@500 | 0.058 / 0.092 | 0.029 / 0.030 |
| Case-balanced prec@500 | 0.043 (vs pooled 0.216) | 0.0X vs 0.130 |
| TP@500 case coverage | 6 distinct cases | 6 |
| Top item-group share of positives | 21.5%; item-group HHI 0.100; buyer HHI 0.009 | 50% PR-AUC halving claim dead |
| Clustered RI (item_group×year): ROC p / PR p / prec p / coverage p | 0.001 / 0.001 / 0.001 / **0.103 (ns)** | p=0.001; coverage ns |

## Direct-defendant scope (script 03 log / scope CSV)

| Quantity | New | Old (dead) |
|---|---|---|
| FL binary vs 47 defendants (all BEC) | 0.491 (random) | 0.49 |
| Continuous score vs defendants (all BEC) | **0.658** (full) / 0.695 (strict) | "below random" claim DEAD |
| In AL pool (6 defendants) | 0.646–0.695 | — |

⇒ §4.5 rewrite: FL-binary remains silent on defendants (0.49); but continuous participation
ranks defendants moderately above chance (0.66–0.70). The "reversal below random"
(\valAUCParticDefendants < 0.5) claim is dead. Asymmetry claim must be restated: the
loser-side BINARY flag is uninformative about defendants; participation volume is not.

## Bid benchmark (script 08 log; gatekeeping same-sample pool)

| Model | New | Old (dead) |
|---|---|---|
| Bid RF (Imhof full) | **0.665** | 0.888 |
| Award FL-only | **0.665** | 0.921 |
| Combined | **0.727** | 0.962 |

## Bid benchmark, pool A (table_Q; 16,731 firms, 651 positives, all retained)

| Model | Random-CV ROC / PR | Case-grouped ROC / PR | prec@500 (random) |
|---|---|---|---|
| Award continuous (fixed score, fold-free) | 0.760 / 0.143 | 0.760 / 0.143 | 0.216 |
| Award FL14 | 0.688 / 0.098 | same | 0.130 |
| Bid RF (Imhof moments) | 0.717 / 0.116 | **0.626 / 0.062** | 0.180 |
| Combined RF | 0.756 / 0.188 | **0.689 / 0.103** | 0.274 |
| Excl. label-defining tenders (contamination) | award 0.829 / 0.156 (569 pos retained) | — | — |

Same-sample gatekeeping pool (script 08 log): imhof_full 0.665, fl_only 0.665, imhof+fl 0.727.
**Honest statements:** award ≈ bid on the pooled diagnostic; the combined model beats award on
PR under random CV (+0.045) but FALLS BELOW award-only under case-grouped folds (0.103 vs
0.143). Complementarity is conditional and case-fragile. Spearman award–bid 0.544.

## Cost-recall frontier (table_6; pool 16,731, 651 positives)

| Rule (k=500) | Firms opened | TP | prec | recall | firm cost-red. | bid-row cost-red. |
|---|---|---|---|---|---|---|
| Award-only (K=500) | 500 | 108 | 0.216 | 0.166 | 97.0% | 60.0% |
| Bid-only (full obs) | 16,772 | 102 | 0.204 | 0.157 | 0 | 0 |
| Joint (upper bound) | 16,772 | 133 | 0.266 | 0.204 | 0 | 0 |
| Sequential K1=1000 | 1,000 | **124** | 0.248 | 0.190 | 94.0% | 47.4% |
| Sequential K1=2000 | 2,000 | 116 | 0.232 | 0.178 | 88.1% | **32.7%** |
| Sequential K1=5000 | 5,000 | 102 | 0.204 | 0.157 | 70.2% | 13.9% |

**Honest statements:** the frontier is the object; firm-count savings (88% at K1=2000)
overstate bid-row savings (33%); K1=1000 happens to beat K1=2000 at k=500 in this sample —
one more reason no K is "optimal". Sequential at K1=1000 recovers 124/133 = 93% of the joint
upper bound's TP at k=500. Recovery-footprint measures, not measured agency budget savings.

## Intensity sensitivity (lead's quick check, informational — NOT yet a manuscript number)

Raw AUC rises with contact-intensity-restricted positives (contact≥1: 0.72; ≥2: 0.80; ≥5: 0.89;
≥10: 0.93; cases≥2: 0.89, npos 54) — consistent with opportunity mechanics (more contact ↔ more
participation). Recommended future appendix sensitivity: re-run script 02 with contact≥2 label.
Do NOT cite these in the manuscript (not from a registered pipeline output).

## Style rules for using these numbers (binding)

1. PR-AUC and prec/rec@500 lead; ROC reported alongside.
2. Never describe the nested +0.010 as "reliable residual signal"; the permutation tests do
   not support it. Allowed: "statistically marginal and not robust across designs".
3. The deflationary decomposition IS the contribution. Sell the framework, not the screen.
4. All operational language: retrospective adjudication-anchored validation; incumbent-firm
   triage; not platform-wide prospective deployment.
5. Composition (341 FL / 310 non-FL) shows the label is NOT FL-conditioned — state once.
