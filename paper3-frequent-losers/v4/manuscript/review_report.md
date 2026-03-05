# Co-Author Review Report — Paper 3 v4→v5
## "Frequent Losers as Cover Bidders in Public Procurement"
### Internal review, March 2026

---

## Executive Summary

The paper proposes frequent losers (FL)—firms that never win yet participate in abnormally many tenders—as a screening marker for cover bidding. It is well-conceived, uses a large dataset (4.5M tender-items), and marshals diverse evidence: OLS, IV, Bajari-Ye tests, network analysis, DiD, and CADE validation. The contribution is genuine and policy-relevant.

**Three critical issues must be addressed before submission:**

1. **The "tighter controls" robustness table shows a sign flip (0.064 → −0.031) when controlling for reference price, which the text describes as "stability."** This is the single most dangerous claim in the paper—a referee will see the table and conclude the authors are being evasive. The sign flip needs an explicit, honest discussion (bad control / causal pathway argument).

2. **Several textual claims are overclaimed relative to the evidence:** the oversight effect is described as "monotonically declining" when Q2 < Q3; the HHI×FL interaction is described as "confirming" when it is statistically insignificant (t = −0.36); and the Bajari-Ye tender-FE results show FL pairwise product (0.38) < non-FL (0.86), which complicates the coordination narrative.

3. **Multiple numerical mismatches between text and tables:** CADE firms matched (text: 49, table: 47), CADE tenders dropped (text: 31,453, implied: 31,447), cross-fit coefficient (text: 0.036, table average: 0.0357), and the FL low-win-rate "baseline" uses a different FL count (2,484) and threshold (41) than the main analysis (2,735, ~14).

The paper is publishable in a good field journal after addressing these issues. The identification strategy is sound for the screening-marker claim (H1); the causal claim (H2) is appropriately hedged.

---

## Task 1: Consistency Flags (Claims vs. Evidence)

### Flag 1 — CRITICAL: Tighter controls sign flip described as "stability"
- **Location:** sec_robustness.tex, lines 71–76
- **Type:** Overclaiming / misleading characterization
- **Problematic text:** "Table~\ref{tab:tighter_controls} in Appendix~\ref{app:robustness} shows coefficient stability across increasingly demanding specifications."
- **Diagnosis:** Column (3) of tab_tighter_controls adds log reference price as a control. The FL coefficient flips from +0.064 to −0.031 (p < 0.01). This is not "stability"—it is a sign reversal. If reference price is on the causal pathway (FL presence → higher reference price → higher negotiated price), conditioning on it is a "bad control" (Angrist & Pischke 2009). If it is not on the pathway, the sign flip suggests FL-price correlation is entirely mediated through reference-price selection.
- **Fix:** Replace "stability" with an honest discussion. Recommend: "Column (3) adds log reference price, which absorbs most cross-tender price variation (R² rises from 0.886 to 0.973). The FL coefficient becomes −0.031, consistent with a bad-control problem: if cover bidding inflates reference prices (e.g., through prior-tender manipulation), conditioning on reference price absorbs the treatment effect and may induce collider bias. We therefore treat column (3) as a mechanical decomposition rather than a robustness check." Also add column (4) item×year FE (0.074) back into the "stability" narrative since it IS stable.

### Flag 2 — CRITICAL: Oversight "monotonically" declining but not monotonic
- **Location:** sec_robustness.tex, lines 172–174
- **Type:** Overclaiming
- **Problematic text:** "The coefficient declines monotonically from 0.214 for the smallest PBUs (Q1) to 0.017 for the largest (Q4)"
- **Diagnosis:** tab_regime_oversight shows Q1=0.214, Q2=0.011, Q3=0.066, Q4=0.017. Q2 < Q3, so the pattern is NOT monotonic. Moreover, Q1 is not significant (SE=0.167, t=1.28), Q2 is not significant (SE=0.051, t=0.22), Q4 is not significant (SE=0.016, t=1.03). Only Q3 is significant (SE=0.030, t=2.17).
- **Fix:** "The coefficient is largest for the smallest PBUs (Q1: 0.214, though imprecisely estimated) and smallest for the largest PBUs (Q4: 0.017, not significant), though the pattern is not monotonic across intermediate quartiles. Only Q3 is individually significant (0.066, p < 0.05)."

### Flag 3 — MAJOR: Network interaction "confirms" but coefficient is insignificant
- **Location:** sec_results.tex, lines 136–138
- **Type:** Overclaiming
- **Problematic text:** "The negative interaction coefficient confirms that the FL price effect diminishes in concentrated markets"
- **Diagnosis:** tab_network_interactions col (1) shows FL×HHI = −0.024 (SE = 0.067, t = −0.36, p > 0.70). The interaction is not statistically distinguishable from zero. "Confirms" is not appropriate for a null result.
- **Fix:** "The interaction coefficient is negative (−0.024) but not statistically significant (SE = 0.067), consistent with the direction predicted by the network-split analysis, though lacking the power to confirm it in a continuous specification."

### Flag 4 — MAJOR: CADE firms matched — text vs. table mismatch
- **Location:** sec_cade.tex, line 15
- **Type:** Numerical mismatch
- **Problematic text:** "49 convicted firms are matched to BEC"
- **Diagnosis:** tab_cade_permutation Panel A says "CADE firms matched to BEC: 47"
- **Fix:** Change text to "47 convicted firms"

### Flag 5 — MAJOR: CADE tenders dropped — text vs. implied mismatch
- **Location:** sec_cade.tex, line 68
- **Type:** Numerical mismatch
- **Problematic text:** "we drop all 31,453 tender-items"
- **Diagnosis:** tab_excl_cade: baseline N=1,654,401, excl-CADE N=1,622,954. Difference = 31,447, not 31,453. (Also line 16 says "approximately 12,400 tender-items" while tab_excl_cade says 12,514.)
- **Fix:** Change to "31,447" or verify source and reconcile.

### Flag 6 — MAJOR: FL low-win-rate "baseline" uses different FL count and threshold
- **Location:** sec_robustness.tex, lines 19–24 (references tab_fl_lowwinrate)
- **Type:** Internal inconsistency (table vs. main analysis)
- **Diagnosis:** tab_fl_lowwinrate "baseline" row shows 2,484 FL firms and threshold=41, vs. the main analysis's 2,735 FL firms and threshold≈14. The coefficient is also different (0.094 vs. 0.064). This table appears to use a different FL identification procedure or pipeline version.
- **Fix:** Verify the R script generating this table. If the "baseline" here uses a different definition, either (a) make it consistent with the main analysis, or (b) add a footnote explaining why it differs. A referee will immediately notice 2,484≠2,735.

### Flag 7 — MAJOR: Cross-fit coefficient 0.036 vs. 0.0357
- **Location:** sec_robustness.tex, line 35; tab_welfare_bounds
- **Type:** Internal inconsistency
- **Problematic text:** "cross-fold average of 0.036" / welfare table uses 0.0360
- **Diagnosis:** tab_fl_crossfit: (0.0528 + 0.0186)/2 = 0.0357, not 0.036. The welfare script hardcodes b_crossfit=0.036 rather than computing from the crossfit table.
- **Fix:** Use 0.036 consistently (acceptable rounding) but note the exact average is 0.0357. Or compute dynamically in the welfare script.

### Flag 8 — MAJOR: Bajari-Ye tender FE — FL product < non-FL product
- **Location:** sec_results.tex, lines 190–203
- **Type:** Underdiscussed result inconsistent with hypothesis
- **Problematic text:** "FL pairwise product drops from 5.16 to 0.38—smaller than the non-FL product in levels, but still significantly positive"
- **Diagnosis:** Under tender FE, FL pairwise product (0.38) is LOWER than non-FL (0.86). Under the cover bidding hypothesis, FL residuals should be MORE correlated than non-FL residuals. The text acknowledges the level comparison but pivots to "still significantly positive." A referee will ask: if FL < non-FL, doesn't this reject conditional dependence?
- **Fix:** Add an explicit paragraph: "The reversal in relative magnitudes—FL pairs exhibiting weaker within-tender correlation than non-FL pairs after absorbing tender-level shocks—may reflect the fact that genuine bidders in the same tender share cost information (e.g., input prices, local market conditions) that induces positive residual correlation, while cover bidders submit bids without such cost information. The relevant test under tender FE is therefore whether FL residuals are significantly positive (indicating some common signal beyond the tender-level mean), not whether they exceed non-FL residuals."

### Flag 9 — MINOR: Abstract "6–9%" omits convite (3.8%)
- **Location:** sec_frontmatter.tex, line 17
- **Type:** Selective reporting
- **Diagnosis:** The 6–9% range (general=6.8%, pregão=9.3%) omits convite=3.8%. A referee may flag this.
- **Fix:** Change to "4–9% higher" or "6–9% in the general and pregão specifications (3.8% for convite)"

### Flag 10 — MINOR: IV p-value understated
- **Location:** sec_results.tex, line 52
- **Type:** Imprecise
- **Problematic text:** "0.194, p < 0.05"
- **Diagnosis:** 0.1944/0.0758 = 2.56, p ≈ 0.010. Stars in table show **, consistent with p < 0.05. But "p < 0.05" is imprecise for a t-stat of 2.56; "p < 0.02" or "p = 0.01" is more informative.
- **Fix:** Change to "p = 0.01" or "p < 0.02"

### Flag 11 — MINOR: Mechanisms M1 coefficient doesn't match main results table
- **Location:** sec_mechanisms.tex, line 17
- **Type:** Potential inconsistency
- **Problematic text:** "The OLS coefficient is 0.143 (p < 0.01)"
- **Diagnosis:** tab_mechanisms M1 OLS = 0.1426 (consistent with rounding). BUT tab_nfirms_excl PBU FE (col 2) = 0.1881 (the "main" estimate for this DV). The mechanisms table appears to use a different specification. The text cites 0.143 but the results section says "0.19 log points" for the same DV. This may confuse referees.
- **Fix:** Clarify which specification is used in tab_mechanisms, or align coefficients.

### Flag 12 — MINOR: sec_results.tex references "0.19 log points"
- **Location:** sec_results.tex, line 20
- **Diagnosis:** tab_nfirms_excl col 2 = 0.1881. Text rounds to 0.19. Acceptable but 0.188 would be more precise.

### Flag 13 — INFO: Sensitivity RV value cannot be verified
- **Location:** sec_robustness.tex, line 95
- **Text:** "$RV_{q=1} = 17.5\%$"
- **Diagnosis:** No output file found to verify this value. The sensemakr computation is in the R code but the output is printed to console, not saved to a table.
- **Fix:** Add the sensemakr output to a table or at minimum to the pipeline log.

---

## Task 2: Identification Strategy Scrutiny

### Concern 1 — MAJOR: Balance tests all significant
- **Severity:** Major
- **Diagnosis:** tab_iv_balance shows all four observables (log firms excl, log ref price, convite, log bid SD) are significantly correlated with the LOO instrument (all p < 0.013). The text dismisses this as "economically negligible (all < 0.001)." But the magnitudes need context: what is the range of the instrument? If the LOO instrument varies by 1,000 units, a coefficient of 0.00032 on log bid SD implies a 0.32 change per 1,000-unit increase, which may not be negligible.
- **Fix:** Report standardized effects (coefficient × SD of instrument) and/or the partial R² of the instrument on each observable. The current defense is insufficient.

### Concern 2 — MAJOR: IGYR FE specification suggests instrument is not fully exogenous
- **Severity:** Major
- **Diagnosis:** Adding item-group × year FE (Panel C) should strengthen the exclusion restriction by absorbing product-market-year shocks. Instead, the first-stage F drops dramatically and the 2SLS estimate explodes to 3.64 (implausibly large). The text correctly identifies weak-instrument amplification, but a referee may interpret this differently: the instrument may be valid only because item+year FE leave residual product-market-year variation that confounds both the instrument and prices. When this variation is absorbed (IGYR FE), the instrument loses power because the exogenous variation was actually confounded.
- **Fix:** Strengthen the defense. Compute Rotemberg weights (Goldsmith-Pinkham et al. 2020) to identify which item-groups drive the IV estimate. If a few item-groups dominate, discuss whether their FL supply variation is plausibly exogenous.

### Concern 3 — MAJOR: Tighter controls sign flip undermines the OLS estimates
- **Severity:** Major
- **Diagnosis:** When controlling for log reference price, the FL coefficient flips to −0.031. This means that within item×year×PBU cells, and conditional on reference price, FL-present tenders have LOWER negotiated prices. One interpretation: FL firms participate in tenders with high reference prices (selection), and the "cover bidding" effect is actually a reference-price selection effect. Another interpretation: reference price is a "bad control" on the causal path. The paper must choose an interpretation and defend it.
- **Fix:** If the interpretation is "bad control": add a formal causal graph (DAG) showing FL → ref price → neg price, which makes ref price a mediator. Cite the bad-controls literature. If the interpretation is "selection": acknowledge that the OLS price effect is partly driven by FL firms selecting into high-reference-price tenders, and the IV strategy addresses this by instrumenting FL presence.

### Concern 4 — MODERATE: LATE vs. ATE interpretation
- **Severity:** Moderate
- **Diagnosis:** The text interprets λ = OLS/IV ≈ 0.33 as 67% measurement error (classical attenuation). But this assumes: (a) classical measurement error in the binary treatment, and (b) homogeneous treatment effects. If treatment effects are heterogeneous, IV > OLS can arise from LATE ≠ ATE even without measurement error. The paper acknowledges the LATE issue in the welfare section but not in the main IV discussion.
- **Fix:** Add to the IV magnitude paragraph: "The ratio λ can reflect either classical attenuation (if the binary FL indicator misclassifies some firms) or treatment effect heterogeneity (if the IV identifies complier tenders with larger-than-average effects). Both interpretations are consistent with the data; we do not attempt to disentangle them."

### Concern 5 — MODERATE: Bajari-Ye tender FE reversal
- **Severity:** Moderate
- **Diagnosis:** See Flag 8 above. Under tender FE, FL pairwise product (0.38) < non-FL pairwise product (0.86). The conditional dependence prediction (Prediction 5) states FL products should EXCEED non-FL products. The tender-FE results reverse this ordering, contradicting the prediction at the within-tender level.
- **Fix:** The defense should explain that tender FE absorbs so much variation that the remaining within-tender residuals primarily reflect idiosyncratic bidder heterogeneity, and that FL bid residuals have less idiosyncratic variation (because cover bids are less dispersed?) which reduces their pairwise product. Alternatively, acknowledge this as a limitation.

### Concern 6 — MINOR: Multiple testing
- **Severity:** Minor
- **Diagnosis:** The paper reports 20+ tables with dozens of hypothesis tests (OLS, IV, matching, DiD, Bajari-Ye, network split, interactions, robustness variants). No multiple-testing correction is applied. While this is common in economics, the sheer volume of tests increases the probability of spurious findings.
- **Fix:** Not a must-fix, but note in the conclusion that "our robustness exercises are intended to probe the stability of the main finding rather than to test independent hypotheses; we do not apply multiple-testing corrections."

### Concern 7 — MINOR: Clustering level
- **Severity:** Minor
- **Diagnosis:** Baseline clustering is at the item level. The paper reports robustness to PBU-level and two-way clustering. However, the treatment varies at the tender-item level, and FL firms operate across item-PBU cells. Clustering at the item level may not account for serial correlation within PBUs over time.
- **Fix:** The two-way clustering already addresses this. No further action needed, but mention the logic for the baseline choice.

---

## Task 3: Literature & Contribution Audit

### Gap 1 — Missing: Clark, Houde, Kastl & Maréchal (2021)
- **Paper:** "Bid Rigging and Entry Deterrence in Public Procurement," *AER* (verify citation)
- **Why:** Directly relevant to the cover bidding mechanism and entry deterrence—the paper studies how cartels use bidding strategies to deter entry, which is closely related to the FL framework.
- **Fix:** Add to the "Cover bidding" paragraph in sec_literature.tex if verified.

### Gap 2 — Missing: Schurter (2020)
- **Paper:** "Identification and Inference in First-Price Auctions with Collusion" (verify citation — may be working paper)
- **Why:** Methodological contribution on identifying collusion in auctions.
- **Fix:** Add if relevant and published.

### Gap 3 — Structural vs. reduced-form positioning
- **Diagnosis:** The literature review does not position the paper in the structural vs. reduced-form debate. The Bajari-Ye test is structural in flavor (model-based predictions about bid distributions), while the OLS/IV analysis is reduced-form. A sentence acknowledging this distinction would strengthen the positioning.
- **Fix:** Add to introduction or literature review: "Our approach is primarily reduced-form—estimating the FL-price association and instrumenting for endogenous FL presence—but we complement this with structural-form evidence via Bajari-Ye tests that leverage model predictions about bid residual distributions."

### Gap 4 — Missing: Bergman, Lundberg & Spagnolo (2020)
- **Paper:** Potentially relevant work on institutional procurement design and cartels (verify citation).
- **Fix:** Verify and add if published.

### Contribution differentiation — OK
The paper's contribution relative to Conley & Decarolis (2016), Imhof et al. (2018, 2019), and Chassang & Ortner (2022) is clearly stated: firm-level screen using only participation data, not bid values.

### Introduction structure — OK
The introduction follows the canonical structure: question (para 1), what we do (para 2), what we find (contributions subsection), roadmap (final para). The main coefficient (6–9% OLS, 21% IV) is stated.

### Citation accuracy — one concern
- **Connor (2007):** Text says "median overcharge around 20%" citing Connor (2007). Verify this specific claim exists in the cited work, as Connor's survey reports a wide range of overcharges. The "10–50%" range is more defensible.

---

## Task 4: Editorial Changes Log

Changes applied directly to .tex files. Each marked with `% CO-AUTHOR EDIT: [reason]`.

### sec_cade.tex
- Line 15: "49" → "47" (match tab_cade_permutation)
- Line 68: "31,453" → "31,447" (match N difference)
- Line 16: "12,400" → "12,500" (match tab_excl_cade's 12,514)

### sec_results.tex
- Lines 136-138: "confirms" → "is consistent with...though not statistically significant"
- Lines 190-203: Added discussion of FL < non-FL under tender FE
- Line 52: "p < 0.05" → "p = 0.01"

### sec_robustness.tex
- Lines 71-76: Replaced "stability" with honest discussion of sign flip in column (3)
- Lines 172-174: "monotonically" → "generally declining...though not monotonic"
- Line 35: "0.036" → "0.036 (0.0357 exact)"

### sec_mechanisms.tex
- No changes needed; coefficients round correctly from tables.

### sec_frontmatter.tex
- Abstract: "6–9%" → "4–9%" to acknowledge the convite specification

### sec_conclusion.tex
- No changes needed; conclusion accurately reflects caveats.

---

## Task 5: Suggested Additional Analyses (Prioritized)

### Must-fix before submission
1. **Discuss the tighter-controls sign flip explicitly** (DAG or bad-control argument)
2. **Fix all numerical mismatches** (CADE firms, tender counts)
3. **Fix overclaiming** (monotonicity, "confirms" for insignificant coefficient)
4. **Reconcile tab_fl_lowwinrate baseline** with main FL definition

### Strongly recommended
5. **Report standardized balance test effects** (coefficient × SD of instrument)
6. **Add LATE/heterogeneity caveat** to IV magnitude discussion
7. **Discuss Bajari-Ye tender FE reversal** (FL product < non-FL product)
8. **Compute Rotemberg weights** for the LOO instrument

### Nice-to-have
9. **Multiple-testing note** in conclusion
10. **Verify Connor (2007) "median 20%" claim** in the cited source
11. **Add 1-2 recent citations** (Clark et al. 2021 if verified)
12. **Report sensemakr output to a table** (currently only in console)
13. **Rerun pipeline to regenerate tables** (currently missing from output directory)

---

## Appendix: Quick-Reference Number Verification

| Claim in text | Table source | Table value | Text value | Match? |
|---|---|---|---|---|
| OLS price (general) | tab_prices col 1 | 0.0677 | 6.8% | ✓ (coef %) |
| OLS price (PBU FE) | tab_prices col 2 | 0.0636 | 6.4% | ✓ |
| OLS price (pregão) | tab_prices col 3 | 0.0933 | 9.3% | ✓ |
| OLS price (convite) | tab_prices col 4 | 0.0382 | 3.8% | ✓ |
| IV price | tab_iv_main Panel A | 0.1944 | 0.194 | ✓ |
| First-stage F | tab_iv_first_stage col 2 | 395.5 | 396 | ✓ (round) |
| KS statistic | tab_bajari_ye Panel A | 0.1513 | 0.15 | ✓ |
| FL pairwise product | tab_bajari_ye Panel B | 5.1597 | 5.16 | ✓ |
| Non-FL pairwise product | tab_bajari_ye Panel B | 2.2082 | 2.21 | ✓ |
| Bootstrap CI | tab_bajari_ye Panel B | [2.57, 5.21] | [2.57, 5.21] | ✓ |
| CADE co-participation | tab_cade_permutation | 7.1% | 7.1% | ✓ |
| CADE firms matched | tab_cade_permutation | 47 | 49 | ✗ |
| Excl-CADE coefficient | tab_excl_cade | 0.0616 | 0.062 | ✓ |
| Excl-CADE N dropped | tab_excl_cade implied | 31,447 | 31,453 | ✗ |
| CEM coefficient | tab_matching col 2 | 0.0770 | 0.077 | ✓ |
| IPW coefficient | tab_matching col 3 | 0.0552 | 0.055 | ✓ |
| Unrestricted N | tab_unrestricted_sample | 2,875,653 | 2,875,653 | ✓ |
| Cross-fit average | tab_fl_crossfit | 0.0357 | 0.036 | ✗ (minor) |
| Temporal FL coef | tab_fl_temporal | 0.0698 | 0.070 | ✓ |
| Low-susp FL coef | tab_network_split col 2 | 0.1257 | 0.126 | ✓ |
| High-susp FL coef | tab_network_split col 2 | −0.0181 | −0.018 | ✓ |
| FL×HHI interaction | tab_network_interactions | −0.0244 | "negative" | ✗ (not sig) |
| Oversight Q1 | tab_regime_oversight | 0.2138 | 0.214 | ✓ |
| Oversight Q4 | tab_regime_oversight | 0.0165 | 0.017 | ✓ |
| Welfare OLS | tab_welfare_bounds | R$734M | R$734M | ✓ |
| Welfare IV | tab_welfare_bounds | R$2.4B | R$2.4B | ✓ |
| Total spending | tab_welfare_bounds | R$30.8B | R$30.8B | ✓ |
| MDE (5%) | tab_did_revised | 0.0776 | 0.076 | ✓ (round) |
