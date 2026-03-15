# Referee Report -- Revision 1

**Journal:** International Journal of Industrial Organization (IJIO)
**Paper:** Frequent Losers as Cover Bidders in Public Procurement
**Overall Recommendation:** Minor Revision
**Date:** 2026-03-15

---

## 1. SUMMARY

This paper proposes "frequent losers" (FL)---firms with a zero win rate that participate in an abnormally large number of public procurement tenders---as a firm-level screening marker for cover bidding. Using 4.5 million tender-items and 40 million bids from Sao Paulo's BEC platform (2009--2019), the authors identify 2,735 FL firms via a median + 1.5 x IQR threshold. The paper tests two hypotheses: FL presence is a useful screening marker (H1), and FL firms are themselves cover bidders (H2). The main findings are: FL-present tenders exhibit 4--9% higher prices (OLS with item, year, and PBU FE); 7.1% of FL firms co-participate with CADE-convicted cartelists (3.5x the participation-adjusted rate); a leave-one-out IV yields a 21% LATE (F = 396), though the authors now acknowledge the IV's sensitivity to the FE structure; Bajari-Ye tests reject exchangeability, though the conditional independence result is attenuated under tender FE. The revision adds conditional descriptive statistics, a horse-race regression against Imhof-style bid-level screens, alternative mechanism tests (firm age, geography, financial distress, minimum-bidder compliance), FL subgroup observable characteristics, enriched Bajari-Ye first stage, and sensitivity-adjusted welfare bounds.

---

## 2. OVERALL ASSESSMENT

The revision substantially improves the paper. The authors have addressed the three conditions I set for IJIO acceptance with varying degrees of success.

**Condition 1 (Reframe H2 as suggestive):** Fully met. The introduction, results, and conclusion now consistently present the IV and Bajari-Ye evidence as "suggestive" and "consistent with" cover bidding rather than establishing it. The Bajari-Ye tender-FE reversal is presented honestly in the main text (Section 6.3), with both interpretations laid out. This is a significant improvement in intellectual honesty. The IV is now framed as supplementary evidence with explicit caveats about the low partial R-squared and specification sensitivity.

**Condition 2 (Benchmark FL against existing screens):** Substantially met. The horse-race regression (Section 8.3) shows that FL persists (0.084) after controlling for Imhof-style CV flags, and the correlation between the two screens is low (0.060). This is the right analysis and it demonstrates incremental value. The finding that FL captures a different signal than bid-level screens is an important contribution.

**Condition 3 (Address network-split inconsistency):** Partially met. The paper now acknowledges the ambiguity explicitly and reports that the two FL subgroups are observationally similar on age, geography, and firm size. The similarity in observables is a useful finding that rules out the simplest selection stories. However, the paper does not provide a compelling theoretical account of why concentrated-market FL firms show zero price effect despite having the network characteristics most consistent with cover bidding.

The paper is now a solid candidate for IJIO. The remaining issues are minor and can be addressed in a final revision.

---

## 3. MAJOR COMMENTS

### [M1] Prediction 5 should be revised or dropped

**Problem:** Prediction 5 (Section 3.3) states that "FL bid residuals within the same tender exhibit positive correlation, with magnitude larger than for non-FL residuals." The paper now acknowledges in Section 6.3 that under tender FE, FL pairs show *less* correlation (0.38) than non-FL pairs (0.86), directly contradicting this prediction. Yet Prediction 5 remains unchanged in Section 3.3. A theoretical prediction that is explicitly contradicted by the preferred specification should either be revised (e.g., "FL residuals violate conditional independence, though the magnitude relative to non-FL is ambiguous") or dropped.

**Location:** Section 3.3 (Prediction 5) vs. Section 6.3.

**Suggested fix:** Revise Prediction 5 to state that FL residuals violate conditional independence (significantly positive pairwise product), without the magnitude comparison to non-FL pairs. Alternatively, add a discussion of why the prediction fails under tender FE as a subsection of Section 3.

### [M2] The IV balance test discussion is internally contradictory

**Problem:** The exclusion restriction discussion (Section 5.2, Threat 2) now honestly acknowledges that all four observables are significantly predicted by the instrument and that "the pattern of significant imbalance across all four observables is more concerning than any individual coefficient and is consistent with---though does not prove---systematic violation of the exclusion restriction." This is commendable transparency. However, Section 6.2 still states that "standardized differences are below 0.03 sigma---well inside what is typically considered negligible covariate imbalance" and "we therefore evaluate balance on economic grounds rather than statistical significance." These two passages send contradictory signals: one raises the alarm, the other dismisses it. The paper should pick one interpretation.

**Location:** Section 5.2 (Threat 2) vs. Section 6.2.

**Suggested fix:** Harmonize the two discussions. The honest version (Section 5.2) is better. Section 6.2 should reference it and acknowledge the tension rather than dismissing the imbalance as negligible.

### [M3] The enriched Bajari-Ye first stage should be reported and discussed

**Problem:** The paper describes the Bajari-Ye first stage as including "reference price, firm size, item and year fixed effects" (Section 5.4), but the actual first stage (Table B.10) only includes firm size. The revision ran an enriched first stage with firm age and CNAE sector, finding that R-squared barely changes (0.776 to 0.803) and KS/pairwise product results are essentially unchanged. This is an important finding---it rules out the concern that the exchangeability violation is driven by omitted firm-level cost shifters. But I cannot find this enriched analysis reported in the manuscript text. It should be added, at minimum as a footnote or paragraph in Section 6.3.

**Location:** Section 5.4, Section 6.3, Appendix.

**Suggested fix:** Add a paragraph in Section 6.3 noting that enriching the Bajari-Ye first stage with firm age and CNAE sector does not change the results (cite the enriched table in the appendix). Also correct the Section 5.4 description to accurately reflect what the first stage includes.

### [M4] The welfare figure caption is inconsistent with the text

**Problem:** The welfare analysis text (Section 8.5) now correctly frames the estimates as "back-of-the-envelope" and discusses the negative concentrated-market estimate. However, the welfare figure caption (Figure D.2) still says "OLS (lower bound) and IV (upper bound)," using the bounds language the revision was supposed to remove. The figure should be regenerated or the caption updated.

**Location:** Appendix D, Figure D.2 caption.

**Suggested fix:** Update the figure caption to remove "lower bound" and "upper bound" language, consistent with the text revision.

---

## 4. MINOR COMMENTS

1. **REVISION-V5 tags:** Approximately 20 LaTeX comments of the form `% REVISION-V5:` are visible in the source. These are useful for tracking changes but should be removed before submission, as they signal to the reader that the paper is in revision rather than a polished manuscript.

2. **Section 5.4:** The text describes the first stage as including "reference price, firm size, item and year fixed effects" but Table B.10 shows only firm size (porte). Reference price is not available at the individual bid level (only 3.2% coverage). The text should accurately describe the first stage as estimated.

3. **Section 7.4 (Alternative Explanations):** The learning-by-doing test finds FL firms are *younger* (14.6 vs. 15.6 years), which the paper describes as "directionally consistent with a learning channel." This is a fair characterization, but the paper should note that an age difference of one year is within the range that could be generated by differences in firm entry timing across product markets, not just by learning.

4. **Table 7 (Network Split):** The revision correctly renamed rows to "Concentrated-market FL" and "Competitive-market FL." However, the table notes still reference "winner HHI above median and >=2 repeat co-bidding partners" without explaining the economic rationale for these specific cutoffs.

5. **Section 8.3 (Horse Race):** The Imhof flag is based on within-item-group CV median split. This is a reasonable proxy but is coarser than the actual Imhof et al. (2017) implementation, which uses multiple features (CV, kurtosis, spread) and a trained classifier. The paper should note this limitation.

6. **Section 4.2:** The economic justification for the median-based IQR threshold is improved but could go further. The argument that "the median anchors the threshold at the center of mass" is more statistical than economic. An economic argument would be: "We seek firms whose participation frequency is so extreme that their behavior is difficult to rationalize as competitive optimization, regardless of the distribution's shape."

7. **Conditional descriptive statistics:** The finding that the FE-residualized gap is only 0.050 log points (vs. 2.43 unconditional) is important and convincingly demonstrates that item FE absorb the selection. This should be highlighted more prominently, perhaps in the introduction when presenting the OLS result.

8. **Section 6.2:** The paragraphs on IV robustness still occupy substantial space despite the IV being reframed as supplementary. Consider compressing the LATE interpretation paragraph, which is standard and does not need as much real estate.

---

## 5. SPECIFIC COMMENTS ON IDENTIFICATION

### 5.1 OLS with High-Dimensional FE (H1)

The OLS baseline remains the paper's most credible and important result. The revision strengthens it with two valuable additions:

(a) **Conditional descriptive statistics** (Section 4.3): The FE-residualized gap of 0.050 log points (vs. 2.43 unconditional) demonstrates convincingly that the regressions exploit within-item variation where FL and non-FL tenders are comparable. The overlap coefficient of 0.978 is reassuring.

(b) **Horse-race regression** (Section 8.3): FL persists at 0.084 after controlling for Imhof-style bid-level screens (correlation 0.060). This is a meaningful result that demonstrates the FL screen captures information orthogonal to bid-level features.

Together with the existing robustness battery (matching, sensitivity analysis, alternative FL definitions, unrestricted sample), the OLS evidence for H1 is strong and well-documented. No further work needed.

### 5.2 Leave-One-Out IV (H2)

The revision appropriately reframes the IV as supplementary evidence. The honest treatment of the exclusion restriction threats (Section 5.2) is a significant improvement. However, the internal contradiction between Sections 5.2 and 6.2 on the balance test interpretation should be resolved (see M2 above).

The core IV results are unchanged: Panel A yields 0.194 (F = 396), Panel C yields 3.64 (implausible). The revision correctly notes that the low partial R-squared (0.0002) means the instrument explains essentially nothing about FL presence after absorbing FE. The paper has made peace with the IV's limitations, which is the right approach.

### 5.3 Bajari-Ye Tests

The revision substantially improves the Bajari-Ye presentation. Key improvements:

(a) **Tender FE results in main text** (Section 6.3): This is the most important change. The paper now presents Table B.12 (previously in appendix) in the main text, with an honest discussion of the FL < non-FL reversal and two competing interpretations. This was the single most important fix from the previous round.

(b) **Enriched first stage**: Adding firm age and CNAE sector to the Bajari-Ye first stage barely changes R-squared (0.776 to 0.803) or the KS/pairwise product results. This rules out the concern that exchangeability failure is driven by omitted firm-level cost shifters. This finding should be reported in the manuscript (see M3).

Remaining concern: Prediction 5 in Section 3.3 should be revised to match the empirical finding (see M1).

### 5.4 Alternative Mechanisms

The revision adds a valuable new section (Section 7.4) testing four alternative explanations:

- **Financial distress:** FL firms are modestly more micro/small (77.2% vs. 73.0%). Difference is statistically significant but economically small.
- **Learning:** FL firms are one year younger (14.6 vs. 15.6). Directionally consistent with learning but magnitude is small.
- **Geographic distance:** FL firms are modestly more out-of-state (76.8% vs. 82.2% from SP). 5.4pp difference.
- **Minimum-bidder compliance:** Cannot explain the pregao coefficient (no minimum requirement), which is larger (9.3%) than convite (3.8%).

None of these alternative explanations can individually account for the 6-9% price effect. The combined logit shows all three are statistically significant but with small marginal effects. This is a useful exercise that narrows the space of non-collusive explanations, even though it cannot definitively rule them out.

---

## 6. ASSESSMENT OF CONTRIBUTION

### Contribution 1: FL as a Screening Marker (H1)

**Assessment: Strong.** The revision significantly strengthens this contribution with the horse-race regression and conditional descriptive statistics. The demonstration that FL captures information orthogonal to Imhof-style screens (correlation 0.060) is a genuine advance. For IJIO, this contribution is now well-established and policy-relevant.

### Contribution 2: Suggestive Evidence for Cover Bidding (H2)

**Assessment: Appropriately calibrated.** The revision correctly reframes H2 as suggestive evidence. The convergence of IV, network, and bid-level evidence is presented honestly, with explicit acknowledgment of limitations. The alternative mechanisms section rules out the simplest non-collusive explanations. For IJIO, this is sufficient as a secondary contribution---the paper does not need to prove causality to be valuable.

### Contribution 3: Bajari-Ye with FL Partition

**Assessment: Improved but still secondary.** The honest presentation of the tender-FE reversal is important. The enriched first stage showing that additional firm controls do not change the results is a useful finding. However, the contribution remains methodological rather than substantive. The Bajari-Ye tests detect bid heterogeneity between FL and non-FL firms but do not conclusively establish coordination. This is now stated clearly, which is appropriate.

### Overall Novelty

The FL concept is now positioned more accurately: a data-parsimonious, firm-level screen that complements existing tender-level tools. The horse-race regression provides empirical evidence for complementarity rather than mere assertion. This is a solid applied IO contribution appropriate for IJIO.

---

## 7. CONCLUSION & RECOMMENDATION

I recommend **Minor Revision**. The paper has substantially improved since the first round. The three conditions I set for IJIO acceptance are largely met:

1. **H2 reframed as suggestive:** Fully met. The paper now presents identification evidence with appropriate calibration.
2. **FL benchmarked against existing screens:** Substantially met. The horse-race regression demonstrates incremental value.
3. **Network-split inconsistency addressed:** Partially met. Ambiguity acknowledged and observables reported, but theoretical explanation remains incomplete.

**Four items for the final revision:**

1. Revise or drop Prediction 5 to match the tender-FE findings (M1).
2. Harmonize the IV balance test discussion between Sections 5.2 and 6.2 (M2).
3. Add the enriched Bajari-Ye first stage results to the manuscript text (M3).
4. Fix the welfare figure caption to remove "bounds" language (M4).

These are minor changes that do not require new estimation. The paper is ready for publication at IJIO after this final pass.
