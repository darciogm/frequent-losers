# Co-Author Internal Review Report — Paper 2: SMEs and Public Procurement

**Reviewer:** Co-author (applied microeconomist / econometrician)
**Date:** March 2026
**Manuscript:** "SMEs and Public Procurement: the Costs of Restricting Tenders"

---

## 1. Executive Summary

The paper exploits a clean quasi-experimental design (DiDiR) to estimate the costs of restricting public tenders to SMEs in Sao Paulo. The institutional setting is unusually sharp: group 65 (medical supplies) was exempt from SME-only rules until March 2018, providing a credible natural experiment. The research question is policy-relevant, the data are comprehensive (universe of standardized procurement), and the battery of robustness checks is impressive.

**What is strong:**
- The institutional narrative is compelling and well-documented.
- The breadth of robustness analysis (Lee bounds, HonestDiD, quantile DiD, causal forests, Gelbach decomposition, randomization inference) is exemplary.
- The heterogeneity analysis by item value adds genuine insight.

**Three most critical issues (must-fix before submission):**

1. **CRITICAL: Stale numbers throughout the manuscript.** The text reports price effects of "4.58% to 8.08%," firm participation of "22%," valid bids of "25%," and distance of "4 km." None of these match the current regression tables. The actual coefficients imply price effects of 12--14%, firm participation of 10--20%, valid bids of 5--17%, and distance of 5--11 km. Every empirical claim in the abstract, introduction, results, and conclusion must be updated.

2. **CRITICAL: Real vs. nominal price effects are NOT "virtually identical."** The IPCA-deflated 18-month coefficient (-0.076) is 42% smaller than the nominal coefficient (-0.131). The fiscal cost calculation uses the nominal coefficient, overstating the real fiscal cost by roughly R$34 million. This must be discussed transparently.

3. **MAJOR: Clustering level.** Treatment varies at the group level (76 groups) but the main specification clusters at the item level (~82,000 items). The group-level cluster SEs are nearly twice as large (0.0178 vs. 0.0096). While significance survives, the main tables' standard errors are likely understated. The paper should either report group-level clustering as the main specification or prominently discuss why item-level is preferred.

---

## 2. Consistency Flags (Task 1)

### Flag 1 — CRITICAL: Price effect magnitude (Abstract, Intro, Results, Conclusion)
- **Location:** Abstract (line ~115 in main.tex); Introduction para 8 (line 35); Empirical results (line 66 in empirical_strategy_results.tex); Conclusion para 2 (line 7 in conclusion.tex)
- **Type:** Numerical mismatch
- **Text says:** "between 4.58% and 8.08%"
- **Tables show:** Baseline coefficients range from -0.1309 to -0.1311 across the three windows (Table 2). Using exact transformation: $e^{-0.1309}-1 = -12.27\%$ to $e^{-0.1311}-1 = -12.29\%$. Even the real-price 18m coefficient ($-0.0762 \to 7.33\%$) doesn't match.
- **Diagnosis:** These are stale numbers from a prior estimation. The current tables have been regenerated with different results, but the text was never updated.
- **Fix:** Replace with "between 12.3% and 13.4%" (using $e^{\hat\beta}-1$ across the six baseline+PBU-FE specifications) or "approximately 13 log points" using the raw coefficients.

### Flag 2 — CRITICAL: Firm participation magnitude (Abstract, Intro, Results, Conclusion)
- **Location:** Abstract, Introduction (line 35), Results (line 70), Conclusion (line 7)
- **Type:** Numerical mismatch
- **Text says:** "approximately 22% higher"
- **Table shows:** 6-month baseline coefficient = 0.1776, i.e., $e^{0.1776}-1 = 19.4\%$. PBU FE: 0.1821 $\to$ 20.0%. No specification yields 22%.
- **Fix:** Replace with "approximately 19--20% higher" (6-month window) or state the coefficient and window explicitly.

### Flag 3 — CRITICAL: Valid bids magnitude (Abstract, Intro, Results, Conclusion)
- **Location:** Abstract, Introduction (line 35), Results (line 72), Conclusion (line 7)
- **Type:** Numerical mismatch
- **Text says:** "approximately 25% more valid bids"
- **Table shows:** 6-month baseline coefficient = 0.1524, i.e., $e^{0.1524}-1 = 16.5\%$. PBU FE: 0.1533 $\to$ 16.6%.
- **Fix:** Replace with "approximately 16--17% more valid bids" (6-month window).

### Flag 4 — MAJOR: Distance magnitude (Abstract, Intro, Results, Conclusion)
- **Location:** Abstract, Introduction, Results (line 74), Conclusion (line 11)
- **Type:** Numerical mismatch / cherry-picking
- **Text says:** "approximately 4 km further"
- **Table shows:** 6-month baseline = 4.90 km (INSIGNIFICANT, p > 0.10). Significant estimates: 12-month baseline = 9.72 km, 18-month baseline = 10.86 km. With PBU FE: 4.62 km (12m, p<0.10), 5.29 km (18m, p<0.05).
- **Diagnosis:** The "4 km" figure doesn't correspond to any significant estimate. The 6-month estimate is 4.90 but statistically insignificant. Reporting an insignificant point estimate as if it were a finding is misleading.
- **Fix:** Report the significant 18-month estimate: "approximately 5--11 km further, depending on specification" or cite only the PBU-FE estimate of 5.3 km.

### Flag 5 — MAJOR: Real prices described as "virtually identical" to nominal
- **Location:** Section 4.4 Extensions (line 100, empirical_strategy_results.tex)
- **Type:** Overclaiming
- **Text says:** "The IPCA-deflated results are virtually identical to the nominal estimates"
- **Tables show:** Nominal 18m = -0.1309; Real 18m = -0.0762. The real effect is 42% smaller. The gap widens with window length: 6m: 18% smaller; 12m: 27% smaller; 18m: 42% smaller.
- **Diagnosis:** The nominal-real gap is substantial and growing, suggesting differential inflation between group 65 (medical supplies, with regulated pricing) and other groups. This is NOT a minor deviation.
- **Fix:** Rewrite to: "The IPCA-deflated results are qualitatively similar but smaller in magnitude, particularly in wider windows (18-month: $-0.076$ vs. $-0.131$), suggesting that part of the nominal price effect reflects differential inflation across product groups. The fiscal cost estimates should be interpreted as upper bounds when differential inflation is present."

### Flag 6 — MAJOR: Fiscal cost uses nominal rather than real coefficients
- **Location:** Section 4.5 (line 112-149, empirical_strategy_results.tex)
- **Type:** Overclaiming
- **Text says:** Fiscal cost of R$84.5--85.8 million
- **Corrected (real prices):** Using $\hat\beta_{real} = -0.0762$: implied real effect = $e^{-0.0762}-1 = -7.33\%$; fiscal cost = $689.0 \times 7.33\% = \text{R\$}50.5$ million. The reported fiscal cost overstates by ~R$34 million.
- **Fix:** Report both nominal and real estimates side by side, or use real prices as the primary specification and note that the nominal version provides an upper bound.

### Flag 7 — MODERATE: Placebo price coefficient described as "insignificant" when marginally significant
- **Location:** Robustness section (line 92, empirical_strategy_results.tex)
- **Type:** Numerical mismatch
- **Text says:** "small and statistically insignificant in both exercises ($-0.0145$ and $0.0206$)"
- **Table shows:** The March 2017 placebo coefficient is $0.0206^*$ (significant at 10%)
- **Fix:** Replace with "small in magnitude: the September 2017 placebo ($-0.015$) is statistically insignificant, while the March 2017 placebo ($0.021$, p < 0.10) is marginally significant but economically negligible relative to the main estimates."

### Flag 8 — MODERATE: Extensive margin described as "less precisely estimated" when highly significant
- **Location:** Extensions section (line 102, empirical_strategy_results.tex)
- **Type:** Underclaiming / factual error
- **Text says:** "the point estimates suggest that open tenders may improve completion rates, though these effects are less precisely estimated"
- **Table shows:** ALL extensive margin coefficients are highly significant (p < 0.01), ranging from 0.107 to 0.127 with SEs of 0.003-0.004. These are t-statistics above 25.
- **Fix:** "Open tenders significantly increase completion rates by 10.7--12.7 percentage points (all $p < 0.01$), providing direct evidence of an extensive margin channel."

### Flag 9 — MODERATE: Efficiency table has unstable coefficients across windows
- **Location:** Extensions section (line 104, empirical_strategy_results.tex)
- **Type:** Potential coding issue / overclaiming
- **Text says:** "results show that open tenders achieve better price efficiency"
- **Table shows:** 6-month coefficient is -0.0651*** but 12-month is -0.4399 (insignificant) and 18-month is -0.3033 (insignificant). The magnitude jumps by 6-7x between windows while losing significance. R-squared drops from 0.0038 to 0.0001.
- **Diagnosis:** The dramatic instability across windows (0.065 → 0.440 → 0.303) combined with plummeting R-squared suggests a potential data issue with the efficiency ratio variable in wider samples. Verify the reference price variable coverage.
- **Fix:** Acknowledge that the efficiency results are fragile and driven by the 6-month window. Consider investigating the reference price variable for the broader sample.

### Flag 10 — MODERATE: PBU heterogeneity described as "broadly similar" when it shows large interaction
- **Location:** Extensions section (line 108, empirical_strategy_results.tex)
- **Type:** Underclaiming
- **Text says:** "broadly similar effects across buyer types"
- **Table shows:** Base price effect for indirect admin = $-0.072^{***}$; interaction for direct admin = $-0.066^{***}$. Total effect for direct admin = $-0.072 + (-0.066) = -0.138$, nearly double. The firm participation interaction is $+0.118^{***}$, also substantial.
- **Fix:** "The price effects are roughly twice as large for direct administration PBUs ($-0.138$) as for indirect administration ($-0.072$), suggesting that institutional constraints amplify the costs of SME restrictions."

### Flag 11 — MINOR: Abstract word count
- **Type:** Format violation
- **Abstract is approximately 249 words;** most top-5 journals require 100--150 words.
- **Fix:** Radically trim to ~150 words focusing on question, method, main coefficient, and contribution.

### Flag 12 — MINOR: Event study last post-period coefficient
- **Location:** Results discussion of Figure 1 (line 55, empirical_strategy_results.tex)
- **Type:** Underclaiming / gap
- **Text says:** "the difference between the groups narrows dramatically after the change...and then stabilizes"
- **Figure shows:** The last post-period coefficient (Mar19--Aug19) is POSITIVE and significant (~+0.10), suggesting the gap doesn't just narrow but reverses. This is potentially problematic for the parallel trends assumption.
- **Fix:** Acknowledge the positive drift in the last period and discuss whether it reflects a learning effect, seasonal patterns, or a genuine concern.

### Flag 13 — MINOR: Gelbach decomposition and "primary mechanism" tension
- **Location:** Results (line 72 vs. line 76, empirical_strategy_results.tex)
- **Type:** Logical inconsistency
- **Text says (line 72):** Competition is the "primary mechanism" explaining lower prices.
- **Text says (line 76):** Gelbach decomposition shows "the large unexplained component ($-0.123$) indicates that most of the price effect operates through channels not captured by these two mediators."
- **Diagnosis:** The Gelbach shows that competition and composition together explain only $0.009$ of the $0.132$ total effect (~7%). Calling competition the "primary mechanism" when 93% of the effect is unexplained overstates the evidence.
- **Fix:** Temper the mechanism language: "While the competition channel operates in the expected direction, the Gelbach decomposition reveals that most of the price effect operates through channels beyond simple participation counts and winner composition."

---

## 3. Identification Concerns (Task 2)

### CRITICAL: Clustering level mismatch

Treatment is assigned at the **group level** (76 groups: group 65 vs. 75 others). The main specification clusters standard errors at the **item level** (~82,000 clusters). When treatment varies at a higher level than the clustering unit, standard errors are typically understated because within-cluster correlation at the treatment-assignment level is ignored.

The alternative clustering table (B.3) confirms this: group-level clustering yields SEs of 0.0178 vs. 0.0096 at the item level (86% larger). While significance survives ($t \approx 7.3$), the reported t-statistics in the main tables (around 13.6) substantially overstate the precision of the estimates.

**Recommended fix (one of):**
1. Make group-level clustering the main specification and report item-level as a robustness check.
2. Adopt the wild cluster bootstrap (Cameron, Gelbach & Miller 2008) at the group level, which performs better with few clusters.
3. At minimum, add a prominent footnote to the main tables noting that group-level clustering roughly doubles the SEs but preserves significance.

### MAJOR: Single treated unit

The design has only **one** switched group (group 65) and 75 always-treated groups. This means any group-65-specific shock coinciding with March 2018 could confound the estimates. While the institutional narrative is convincing, a single-treated-unit design is inherently fragile against:
- Group-65-specific supply chain disruptions
- Changes in ANVISA (drug regulatory agency) policies affecting pharmaceutical pricing
- Seasonal patterns specific to medical supplies

**Recommended fix:** Add a discussion acknowledging this limitation. The randomization inference exercise partially addresses it (permuting group assignment), which is good. Consider additionally testing whether the effect is robust to excluding specific subgroups within group 65 (e.g., medications vs. hospital supplies).

### MAJOR: Real vs. nominal divergence suggests confounding

The growing gap between nominal and real price effects across windows (18% at 6m, 27% at 12m, 42% at 18m) suggests that group 65 experienced different inflation dynamics than other groups. Medical supply prices in Brazil are often subject to CMED (Camara de Regulacao do Mercado de Medicamentos) price controls, which could generate differential price trajectories unrelated to the SME policy. If inflation differentials are group-specific and time-varying, they could bias the DiDiR estimates even if the SME policy change itself is exogenous.

**Recommended fix:**
1. Report real-price specifications as the preferred estimates.
2. Investigate whether the CMED price ceiling for pharmaceuticals changed during the sample period and discuss whether this could account for part of the effect.
3. The fiscal cost calculation should use the real-price coefficient as the primary estimate.

### MODERATE: Post-period parallel trends drift

The event study figure shows a positive and significant coefficient in the last post-period (Mar19--Aug19, ~+0.10). In the DiDiR framework, post-period coefficients should be zero if parallel trends hold. A significant positive coefficient in the last period suggests either:
- Group 65 prices are rising faster than other groups post-switch, violating parallel trends
- PBU learning effects that attenuate the restriction costs over time
- Composition changes in the groups being compared

The HonestDiD analysis provides partial reassurance, but the CI at $\bar{M} = 0$ for log prices appears to be close to including zero, suggesting the sensitivity analysis is less decisive than the text implies.

**Recommended fix:** Discuss this drift explicitly and test whether the main results are robust to excluding the last post-period.

### MODERATE: Extensive margin and sample selection

The extensive margin results show that open tenders increase completion rates by 10--13 percentage points (highly significant). This is a large effect, and it means the price estimates condition on a sample that is endogenously selected. The Lee bounds ($-0.131$ to $-0.123$) are tight, which is reassuring. However, the trimming proportion of 8.82% is non-trivial, and the direction of selection (open tenders have more completions, so the completed sample under open tenders includes marginal items that might have higher prices) could attenuate the price effect.

**No additional action required** beyond what the paper already provides. The Lee bounds analysis is well-done. Consider briefly noting the economic interpretation of the selection direction.

### MINOR: Multiple testing

The paper tests 4 outcomes $\times$ 6 specifications = 24 primary regressions, plus numerous robustness and extension analyses. No multiple testing correction is discussed. Given the very high significance of the price results ($p \ll 0.001$), Bonferroni or Holm corrections would not alter the price conclusions. However, the weaker results (distance in 6-month window, efficiency ratios, placebo for March 2017) might not survive adjustment.

**Recommended fix:** Add a sentence noting that the primary price results survive any reasonable multiple testing correction, and that the secondary results should be interpreted with appropriate caution.

---

## 4. Literature Gaps (Task 3)

### Must-cite (a referee will likely flag these):
1. **Best, Hjort, & Szakonyi (2023)** — "Individuals and Organizations as Sources of State Effectiveness," AER. Directly relevant to procurement effectiveness and institutional capacity in Brazil.
2. **Bandiera, Prat, & Valletti (2009)** — "Active and Passive Waste in Government Spending," AER. Core procurement efficiency paper. [verify citation: there's also a 2020 version]
3. **Cameron, Gelbach, & Miller (2008)** — wild cluster bootstrap. Relevant given the clustering concerns. [verify citation]

### Should-cite (strengthens the paper):
4. **Ferraz, Finan, & Szerman (2023)** — already cited, good.
5. **De Chaisemartin & D'Haultfoeuille (2020)** — already cited for staggered DiD, good.
6. **Roth, Sant'Anna, Bilinski, & Poe (2023)** — already cited, good.

### Verify these citations:
7. **Kim (2019)** for DiDiR — verify exact citation. The "time-reversed DiD" terminology should trace back to a specific published paper.
8. **Gelbach (2016)** — verify journal and year. The canonical Gelbach decomposition paper may have a different publication year.

### Minor issues:
- The introduction cites \citet{pwc2014} for European SME statistics — verify this is a published, accessible source and not just a consulting report.
- The canonical structure of the introduction is good: question, method, findings, contribution, roadmap. No issues here.

---

## 5. Editorial Changes Log (Task 4)

Changes will be applied directly to the .tex files with `% CO-AUTHOR EDIT:` comments. Summary of planned changes:

### Abstract (main.tex)
- Rewrite to ~150 words with correct numbers from current tables
- State the key coefficient magnitude explicitly
- Remove verbose mechanism discussion

### Introduction (introduction.tex)
- Update all four empirical claims (prices, firms, bids, distance) to match tables
- Tighten redundant paragraphs
- Ensure the main coefficient magnitude appears with its exact value

### Institutional Background (institutional_background.tex)
- Minor: no substantial changes needed; the institutional narrative is well-written

### Data (data.tex)
- Minor: clarify the sample count description

### Empirical Strategy and Results (empirical_strategy_results.tex)
- Update all numerical claims to match current tables
- Fix "virtually identical" for real prices
- Fix "less precisely estimated" for extensive margin
- Fix "broadly similar" for PBU heterogeneity
- Fix "insignificant" for March 2017 placebo
- Add note about clustering level
- Discuss event study drift in last post-period

### Conclusion (conclusion.tex)
- Update all numerical claims
- Tighten slightly

### Appendix (appendix.tex)
- Minor adjustments to match updated claims

---

## 6. Suggested Additional Analyses (prioritized)

### Must-do before submission:
1. **Update all in-text numbers** to match current regression output (this is non-negotiable).
2. **Report group-level clustered SEs** in the main tables or add a prominent robustness discussion.
3. **Dual fiscal cost table** with both nominal and real-price estimates side by side.

### Strongly recommended:
4. **Investigate the efficiency ratio instability.** The 6x jump in magnitude between 6-month and 12-month windows suggests a data quality issue with the reference price variable.
5. **Exclude-last-post-period robustness check** to address the event study drift in Mar19--Aug19.
6. **Balance test / pre-treatment covariate comparison** between group 65 and other groups to formalize the comparability argument.

### Nice-to-have:
7. **Wild cluster bootstrap** at the group level (76 clusters) for the main price specification.
8. **Heterogeneity within group 65** (medications vs. hospital supplies vs. dental supplies) to test whether the effect is driven by specific subgroups.
9. **Investigate CMED pharmaceutical price regulation** and whether any regulatory changes coincided with the sample period.
10. **Synthetic control** as an alternative estimator for the single-treated-group design (would complement the DiDiR nicely).

---

## Appendix: Numerical Cross-Reference

| Claim in text | Source table | Table value | Text value | Match? |
|---|---|---|---|---|
| Price effect range | Tab 2 (prices) | -0.1309 to -0.1441 (coefficients) | "4.58% to 8.08%" | NO |
| Price effect (exact, e^b-1) | Tab 2 (prices) | 12.27% to 13.42% | "4.58% to 8.08%" | NO |
| Firm participation | Tab 3 (participants) | 0.1776 (6m base), e^b-1 = 19.4% | "approximately 22%" | NO |
| Valid bids | Tab B.1 (validbids) | 0.1524 (6m base), e^b-1 = 16.5% | "approximately 25%" | NO |
| Distance | Tab B.2 (distance) | 4.90 (6m, insig), 10.86 (18m, ***) | "approximately 4 km" | NO |
| Fiscal cost | Fiscal cost table | R$84.5--85.8 million (nominal) | R$84.5--85.8 million | YES (nominal) |
| Lee bounds | Tab B.11 | -0.1306 to -0.1227 | "-0.131 to -0.123" | YES (rounding) |
| Quantile DiD tau=0.10 | Tab B.13 | -0.6231 | "-0.623" | YES (rounding) |
| Quantile DiD tau=0.90 | Tab B.13 | 0.4451 | "+0.445" | YES (rounding) |
| OLS benchmark | Tab B.13 | -0.1241 | "-0.124" | YES (rounding) |
| Causal forest var imp | Tab B.12 note | 0.486 | "0.486" | YES |
| Gelbach short | Tab B.14 | -0.1318 | "-0.132" | YES (rounding) |
| Gelbach full | Tab B.14 | -0.1227 | "-0.123" | YES (rounding) |
| Trimming proportion | Tab B.11 | 0.0882 | "8.82%" | YES |
| Placebo Sep 2017 | Tab 5 (placebo) | -0.0145 (insig) | "-0.0145" (insig) | YES |
| Placebo Mar 2017 | Tab 5 (placebo) | 0.0206* (p<0.10) | "0.0206" (described as insig) | PARTIAL |
| Real prices "virtually identical" | Tab B.5 | -0.0762 (18m) vs -0.1309 nominal | "virtually identical" | NO |
| Extensive margin "less precisely estimated" | Tab B.6 | All *** (t > 25) | "less precisely estimated" | NO |
| Heterog PBU "broadly similar" | Tab B.10 | Interaction -0.066*** (doubles effect) | "broadly similar" | NO |
