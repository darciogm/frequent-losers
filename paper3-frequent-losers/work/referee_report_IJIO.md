# Referee Report

**Journal:** International Journal of Industrial Organization (IJIO)
**Paper:** Frequent Losers as Cover Bidders in Public Procurement
**Overall Recommendation:** Major Revision
**Date:** 2026-03-14

---

## 1. SUMMARY

This paper proposes "frequent losers" (FL)---firms with a zero win rate that participate in an abnormally large number of public procurement tenders---as a firm-level screening marker for cover bidding in procurement auctions. Using 4.5 million tender-items and 40 million bids from Sao Paulo's Bolsa Eletronica de Compras (BEC) platform (2009--2019), the authors identify 2,735 FL firms via a median + 1.5 x IQR threshold applied to the participation distribution of always-loser firms. The paper tests two hypotheses: that FL presence is a useful screening marker for collusion (H1), and that FL firms are themselves cover bidders deployed by cartels (H2). The empirical toolkit includes: (i) OLS regressions with high-dimensional fixed effects showing 4--9% higher prices in FL-present tenders; (ii) a leave-one-out instrumental variable yielding a 21% price markup (F = 396); (iii) external validation against CADE cartel convictions showing FL firms are 3.5x more likely to co-participate with convicted cartelists; (iv) Bajari-Ye exchangeability and conditional independence tests; (v) network-based heterogeneity analysis; and (vi) a staggered Callaway-Sant'Anna DiD. The paper also presents a "minimal model" of cover bidding generating five testable predictions, a regime identification exercise (complementary vs. coordinated cover bidding), and a welfare analysis bounding the cost of cover bidding between R$734 million and R$2.4 billion.

---

## 2. OVERALL ASSESSMENT

This paper tackles a genuine gap in the bid-rigging detection literature: the absence of a firm-level screen that operates without bid-level data. The FL concept is operationally simple and potentially useful for resource-constrained competition authorities. The dataset is exceptionally large and the institutional setting is rich. The paper demonstrates intellectual ambition by deploying multiple identification strategies.

However, the paper's most important problem is that **none of its identification strategies conclusively establishes the causal mechanism (H2), and several produce results that contradict the cover bidding interpretation when examined closely**. The leave-one-out IV is fragile across fixed-effects specifications (0.194 to 3.64). The Bajari-Ye tests, under tender fixed effects, show FL pairs with *lower* residual correlation than non-FL pairs---the opposite of the cover bidding prediction. The network split reveals that the FL firms most consistent with a cover bidding profile (high HHI, repeat partners) show *no* price effect, while the effect is driven entirely by FL firms in competitive markets. The staggered DiD is underpowered and yields a near-zero ATT. Individually, each result can be rationalized; collectively, they suggest the paper should reframe H2 as suggestive rather than established. The H1 contribution (FL as a screening tool) is solid and sufficient for IJIO if properly framed.

---

## 3. MAJOR COMMENTS

### [M1] The LOO instrument is fragile and the exclusion restriction is not credibly defended

**Problem:** The leave-one-out instrument (FL supply at other PBUs in the same product market and year) has a partial R-squared of 0.0002--0.0006 (Table 3). Despite an F-statistic of 396 (driven entirely by the massive sample), the instrument explains essentially none of the variation in FL presence. More critically, when the fixed-effects structure is tightened to item-group x year FE (Table B.8, Panel C), the 2SLS estimate explodes from 0.194 to 3.64---an implausible 38x price markup. The paper correctly flags this as weak-instrument amplification, but the instability reveals that the instrument's identifying variation is concentrated in cross-product-market-year comparisons that are absorbed by the more demanding FE structure. This means the preferred Panel A specification identifies off variation that may reflect correlated demand or enforcement shocks across product markets.

**Location:** Section 5.2 (Equation 3), Table 3 (first stage), Table B.8 (Panel C).

**Why it matters:** For IJIO, the IV results are central to the H2 claim. An instrument with near-zero partial R-squared that produces wildly different estimates across FE structures does not meet IJIO's standard for credible identification. The balance test (Table B.2) compounds the concern: all four observables are statistically significantly predicted by the instrument (all p-values <= 0.013). The paper's argument that standardized effects are below 0.03 sigma is insufficient---at N > 1.5 million, even 0.03 sigma imbalance can generate economically meaningful bias in the second stage, and the *pattern* of significant imbalance across all four observables suggests systematic violation of the exclusion restriction, not random noise.

**Suggested fix:** (a) Compute the implied bias from the balance test imbalance using the formula in Goldsmith-Pinkham et al. (2020), already cited. (b) Implement a formal Bartik decomposition to identify which product markets drive the first stage and assess whether those markets are plausibly exogenous. (c) Test a time-lagged instrument (FL supply in t-2) as a placebo---if the contemporaneous instrument captures cartel coordination rather than supply shocks, lagged supply should also predict prices. (d) Consider whether the paper can stand on OLS alone (with the sensitivity analysis providing the robustness bound) and relegate the IV to a supplementary exercise.

### [M2] The Bajari-Ye tender-FE results contradict the cover bidding interpretation

**Problem:** Under tender fixed effects---the appropriate specification for the Bajari-Ye framework, since it absorbs all tender-level confounds---the FL pairwise product is 0.38, *lower* than the non-FL pairwise product of 0.86 (Table B.12). This means that after removing common tender-level shocks, FL bid residuals are *less* correlated with each other than non-FL residuals. This directly contradicts Prediction 5 (Section 3.3), which states that "FL bid residuals within the same tender exhibit positive correlation, with magnitude larger than for non-FL residuals." The paper acknowledges this reversal but argues it is "not inconsistent" with cover bidding because genuine bidders share cost information. This post-hoc rationalization undermines the entire Bajari-Ye exercise.

Furthermore, the fake-groups placebo (Panel C of Table 5) produces a pairwise product of 5.80 under baseline FE---*higher* than the FL product of 5.16. This means that randomly grouping non-FL firms generates *more* apparent coordination than the FL classification. The paper correctly notes that the relevant comparison is FL vs. non-FL, not FL vs. zero. But the fact that random grouping outperforms FL classification in the baseline specification raises serious questions about what the Bajari-Ye tests are actually detecting.

**Location:** Table 5 (Panel C), Table B.12, Section 6.3.

**Why it matters:** The Bajari-Ye framework is one of the paper's three claimed contributions and a standard tool in the IJIO bid-rigging literature. If the results do not survive the correct specification (tender FE), the paper cannot claim them as evidence for cover bidding. An IJIO referee familiar with Bajari & Ye (2003) will immediately flag this.

**Suggested fix:** (a) Acknowledge explicitly that the tender-FE Bajari-Ye results fail to support the cover bidding interpretation and downgrade the Bajari-Ye contribution to "descriptive evidence of bid heterogeneity." (b) Report both specifications side-by-side in the main text (currently the tender-FE results are buried in the appendix). (c) Discuss whether the exchangeability violation reflects cost heterogeneity (FL firms have different cost structures) rather than strategic coordination.

### [M3] The Bajari-Ye first stage is underspecified

**Problem:** The auxiliary bid regression (Table B.10) includes only firm size (porte) and item + year fixed effects, with no reference price, distance to PBU, firm age, capacity measures, CNAE sector, or other cost shifters. The R-squared of 0.77 is driven almost entirely by item fixed effects (which absorb mean price levels across items). With only one firm-level regressor (porte), the residuals are capturing most of the cross-firm cost heterogeneity rather than strategic bidding deviations. This makes the exchangeability test (KS test on residuals) largely a test of whether FL and non-FL firms have different cost structures---which they almost certainly do, since FL firms participate in fundamentally different tenders (mean negotiated price of R$140,673 vs. R$12,465 for non-FL, per Table 1).

**Location:** Table B.10, Section 5.4.

**Why it matters:** The Bajari-Ye framework requires that the first-stage bid regression absorbs all observable cost drivers, so that residuals reflect unobserved strategic components. With a single firm-level control, the residuals are contaminated by unobserved costs, making the exchangeability and conditional independence tests uninterpretable as tests of strategic behavior.

**Suggested fix:** (a) Add all available firm-level controls: CNAE sector, firm age, municipality, distance to PBU (if constructable). (b) Add reference price as a regressor (this is the most important missing variable---it anchors bid levels and its omission biases residuals). (c) Report the first-stage R-squared with and without item FE to assess how much the FE are doing. (d) Consider using the reference price to normalize bids (bid/reference price) as the dependent variable, reducing the reliance on item FE.

### [M4] The network split produces results that undermine H2

**Problem:** Table 7 splits FL firms into "high-suspicion" (high HHI, repeat partners) and "low-suspicion" groups. The high-suspicion group---precisely the firms whose network characteristics are most consistent with cover bidding (concentrated winners, repeated co-bidders)---shows a *negative* price coefficient (-0.018, insignificant). The entire price effect comes from "low-suspicion" FL firms operating in competitive markets. The paper relabels these groups as "concentrated-market" and "competitive-market" to reframe the finding, but the original table header still reads "Price Effects by FL Suspicion Level."

The paper argues that cover bidding is most valuable in competitive markets, which is plausible. But this interpretation requires that cover bidding in competitive markets operates through a different channel than in concentrated markets---and the paper's own model (Section 3) does not make this distinction. Moreover, the competitive-market FL firms may simply be firms that participate in higher-value, more competitive tenders for non-collusive reasons (e.g., they are small firms that repeatedly lose genuinely competitive auctions for popular items).

**Location:** Table 7, Section 6.4, Table B.13.

**Why it matters:** The network split is central to the paper's H2 argument. The finding that the "most suspicious" FL firms show no price effect, while "less suspicious" firms drive the entire effect, is a significant challenge to the cover bidding narrative. For IJIO, this internal inconsistency will be a red flag.

**Suggested fix:** (a) Update Table 7's header to match the text's labels. (b) Acknowledge explicitly that the network-split results are ambiguous: they are consistent with cover bidding in competitive markets *but also* with selection stories that do not involve collusion. (c) Test whether competitive-market FL firms have observable characteristics (firm size, CNAE, geography) that differ from concentrated-market FL firms in ways that could explain the price effect without invoking collusion. (d) Report the continuous interaction specification (Table B.13, Column 1) more prominently and note that the interaction is not significant---meaning the data do not support a strong market-structure gradient.

### [M5] The welfare analysis is unreliable as presented

**Problem:** The welfare calculation (Table B.5) multiplies the price coefficient by total FL-present procurement value. Three issues: (i) the OLS is labeled a "lower bound," but this holds only under measurement-error attenuation---if OLS suffers from positive omitted variable bias (FL firms select into expensive tenders), OLS is an upper bound; (ii) the IV is labeled an "upper bound," but LATE heterogeneity (not just attenuation) can explain the OLS-IV gap, making the IV an unreliable upper bound; (iii) the "high-suspicion FL" column shows *negative* welfare loss (R$-88M), which means the welfare calculation produces a *benefit* from FL presence among the supposedly most suspicious firms. This contradicts the entire framing and is not discussed.

**Location:** Section 8.5, Table B.5.

**Why it matters:** Welfare analysis is a core expectation for applied IO papers. A welfare table with one column showing negative losses from the "high-suspicion" group, without comment, will undermine the paper's credibility with IJIO referees.

**Suggested fix:** (a) Reframe as "back-of-the-envelope" calculations rather than bounds. (b) Discuss the negative welfare estimate for high-suspicion FL explicitly. (c) Compute the welfare bounds using the Cinelli-Hazlett RV_q=1 = 17.5% to derive a sensitivity-adjusted lower bound on the OLS estimate. (d) Acknowledge that general equilibrium effects (entry deterrence, allocative inefficiency, deadweight loss) are excluded.

### [M6] The DiD contributes nothing and should be fully relegated to the appendix

**Problem:** The Callaway-Sant'Anna DiD yields an ATT of 0.014 (SE = 0.040) for log prices---effectively zero. The MDE at 5% significance is 0.078, which exceeds the OLS benchmark of 0.064. The paper acknowledges the exercise is underpowered and "complementary only." Yet it occupies a full subsection in the main text (Section 8.4) and a full appendix section (Appendix C) with detailed discussion of Rambachan-Roth sensitivity, sharp-entry subsamples, and event-study figures.

**Location:** Section 8.4, Appendix C (Table C.1, Figure C.1).

**Why it matters:** An underpowered DiD that produces null results is not informative. Including it in the main text creates the impression that the paper has a panel-data identification strategy that supports the findings, when in fact it does not. For IJIO, space should be allocated to analyses that produce informative results.

**Suggested fix:** Move the entire DiD discussion to the appendix (or an online appendix). In the main text, mention in one sentence that the DiD is underpowered and cite the appendix. Use the freed space to expand the Bajari-Ye tender-FE discussion (currently in the appendix but more important than the DiD).

### [M7] The descriptive statistics reveal a massive selection problem that is not adequately addressed

**Problem:** Table 1 shows that FL-present tenders have a mean negotiated price of R$140,673 compared to R$12,465 for non-FL tenders---a factor of 11.3x. In logs, the difference is 4.92 vs. 2.49 (a 2.43 log-point gap). Even with item fixed effects, this level of disparity raises serious concerns about whether FL firms select into fundamentally different tenders (larger contracts, more complex goods, different item types) within item groups. The item FE absorb cross-item means, but if item groups are broad (the paper mentions 18,783 item types across ~90 two-digit groups), within-group heterogeneity could be substantial.

**Location:** Table 1 (Section 4.3).

**Why it matters:** If FL-present tenders are systematically different from non-FL tenders along dimensions not fully absorbed by item FE---contract size, complexity, specificity---then the OLS coefficient captures selection, not treatment. The 11x price difference is too large to be explained by a 6% treatment effect; most of the difference must reflect selection that item FE may not fully absorb.

**Suggested fix:** (a) Report conditional descriptive statistics (means after residualizing on item + year + PBU FE) to show how much of the 11x gap is absorbed by fixed effects. (b) Show that the within-item-group price distribution of FL-present and FL-absent tenders overlap substantially after conditioning on FE. (c) The item x year FE specification (Table B.4, Column 4: coefficient = 0.074) is more demanding and should be given greater prominence.

### [M8] The paper does not benchmark FL against existing screens

**Problem:** The paper positions FL as a complement to bid-level screens (Imhof et al. 2017, 2018; Huber & Imhof 2019) but never actually compares FL's detection performance against these screens. Given that the paper has bid-level data (40 million bids), it is feasible to compute standard screen statistics (bid CV, bid variance, kurtosis, number of unique digits) and assess: (a) whether FL-flagged tenders also flag on bid-level screens, (b) whether FL adds incremental predictive power above bid-level screens, (c) the false-positive rate of FL screening relative to bid-level methods.

**Location:** Section 2 (Related Literature), Section 9 (Conclusion).

**Why it matters:** For IJIO, a paper claiming to introduce a new detection tool must demonstrate that it adds value relative to the existing toolkit. Without a direct comparison, the paper cannot support its claim that FL "complements" existing screens. The claim remains assertion.

**Suggested fix:** (a) Compute Imhof-style tender-level screen statistics for the sample. (b) Report a confusion matrix: FL-flagged vs. screen-flagged tenders. (c) Run a horse-race regression: do FL effects persist after controlling for bid-level screen indicators? This would be a substantial contribution and would strengthen the paper's IO positioning.

---

## 4. MINOR COMMENTS

1. **Section 3, Equation 1:** The comparative static that m* is increasing in n requires specific curvature assumptions on pi(m,n) that are not stated. For a "minimal model," this is acceptable, but the paper should note the dependence on functional form.

2. **Table 1:** Report the within-item-FE conditional means alongside the raw means. The current unconditional comparison (R$140K vs. R$12K) is misleading about the variation the regressions actually exploit.

3. **Table 3 (First Stage):** Column headers are misaligned. Column (1) is labeled "General" but includes no PBU FE; Column (2) is "General+PBU" but uses the same instrument. Clarify the FE structure in column headers rather than only in the bottom rows.

4. **Section 4.2, footnote:** The justification for using median + 1.5 x IQR instead of Tukey's Q3 + 1.5 x IQR is "the participation distribution is highly right-skewed." But the Tukey rule is *designed* for skewed distributions (it uses Q3, which is robust to right skew). The footnote should instead argue on economic grounds why the median-based threshold better captures the relevant cutoff.

5. **Table 5 (Bajari-Ye):** Report the number of tenders used for the pairwise product calculation (Panel B requires tenders with >= 2 FL bids). If this subsample is small, the test's power may be limited.

6. **Section 6.4 (Network Split):** The text relabels "high-suspicion" as "concentrated-market" but the table header (Table 7) still reads "FL Suspicion Level." This is an internal inconsistency. Reconcile throughout.

7. **References:** Missing key IJIO-relevant citations: Wallimann, Huber & Imhof (2023) on ML detection extensions; Clark, Houde & Kastl (2021) on collusion dynamics; Schurter (2020) on identification in first-price auctions with collusion. The literature review has 35 references, lean for a paper of this scope targeting IJIO.

8. **Section 7.2 (M2, Reference Price Calibration):** The coefficient of -0.041 on log(p_negot/p_ref) could reflect that FL firms participate in tenders with goods whose prices are closer to the reference price by nature (standardized goods), not that cartels calibrate bids. The paper does not control for item-level price-to-reference dispersion.

9. **CO-AUTHOR EDIT comments:** Approximately 15 LaTeX comments of the form "% CO-AUTHOR EDIT:" are visible in the .tex source. Remove before submission.

10. **Section 8.1 (Threshold Sensitivity):** The monotonically increasing coefficient with stricter thresholds is consistent with the screen working, but also with more extreme firms participating in more unusual (higher-priced) markets. Discuss both interpretations.

11. **Figure 2 (IQR Identification):** The threshold line is not annotated with its numerical value (~14 participations). Add the annotation.

12. **Table B.5 (Welfare):** The "High-Suspicion FL" column with negative welfare loss is not discussed anywhere in the text. This omission will be noticed by careful referees.

13. **Section 5.2 (Threats to exclusion restriction):** The three threats are discussed in a single paragraph with no formal analysis of any of them. Each threat warrants its own subsection with specific evidence or falsification tests.

14. **Abstract:** "4--9% higher negotiated prices" is the OLS range; "21% price markup" is the IV LATE. The abstract should clearly label these to avoid conflation.

---

## 5. SPECIFIC COMMENTS ON IDENTIFICATION

### 5.1 OLS with High-Dimensional Fixed Effects (H1)

The OLS baseline (Equation 1, Table 2) is the paper's most credible result. Item, year, and PBU fixed effects absorb time-invariant item price levels, aggregate trends, and purchasing-unit-specific factors. The coefficient of 0.064 (with PBU FE) represents the within-item, within-year, within-PBU difference in prices between FL-present and FL-absent tenders.

**Strengths:** (a) The coefficient is stable across specifications (0.064--0.094 without and with genuine bidder count). (b) The item x year FE specification yields 0.074, close to the baseline. (c) Matching estimators (CEM: 0.077, IPW: 0.055) bracket the OLS estimate. (d) The Cinelli-Hazlett robustness value (RV_q=1 = 17.5%) implies that a confounder would need to explain substantial variation in both treatment and outcome to nullify the result.

**Weaknesses:** (a) The specification with reference price as a control (Column 3 of Table B.4) produces a *negative* coefficient (-0.031), which the paper interprets as a "bad control" problem. But reference price is a pre-determined institutional benchmark, not a post-treatment variable---calling it a bad control requires assuming that cover bidding manipulates reference prices, which is a testable claim, not an assumption. The paper should test this directly (e.g., regress reference price on lagged FL presence). (b) The massive unconditional price gap (11x between FL and non-FL tenders) means the OLS exploits within-item variation, but if FL firms select into higher-priced tenders *within* item groups, the FE do not fully resolve selection.

**Assessment:** The OLS results support H1 (FL as a screening marker) credibly. They are sufficient for the paper's core contribution.

### 5.2 Leave-One-Out Instrumental Variable (H2)

The LOO instrument (Section 5.2, Equation 2) counts FL firms active at other PBUs in the same product market and year.

**First-stage diagnosis:** The F-statistic (396) is large but driven by N = 1.65 million. The partial R-squared (0.0002) is the relevant measure of instrument strength, and it is vanishingly small. A partial R-squared this low means the instrument explains less than 0.02% of the residual variation in FL presence after absorbing fixed effects. The 2SLS estimate is therefore identified off an extremely thin sliver of variation.

**Exclusion restriction:** The identifying assumption is that FL activity at distant PBUs affects focal-PBU outcomes *only* through FL participation at the focal PBU. Three concerns:

1. **Correlated cartel organization:** A cartel that deploys FL firms coordinates across PBUs. The LOO instrument would then capture coordinated entry, not exogenous supply. The balance test (Table B.2) shows all four observables significantly predicted by the instrument---a pattern consistent with correlated shocks rather than quasi-random supply.

2. **Specification sensitivity:** Panel A (item + year + PBU FE) yields 0.194; Panel C (item-group x year + PBU FE) yields 3.64. The 18.7x increase in the coefficient suggests that the identifying variation in Panel A comes from cross-product-market-year comparisons that Panel C absorbs. If the IV worked through a genuine supply channel, tightening FE should reduce precision but not change the point estimate by an order of magnitude.

3. **Placebo IV (Table B.9):** The sub-threshold always-loser placebo has a first-stage F of 33 and a 2SLS estimate of 5.24---implausibly large, which the paper attributes to weak-instrument amplification. However, the fact that a placebo instrument with F = 33 (above the conventional threshold of 10) produces a large coefficient suggests that LOO instruments in this setting are generically prone to amplification, raising questions about whether the main instrument's estimate of 0.194 is also amplified.

**Assessment:** The IV results are fragile and do not meet IJIO's standard for credible causal identification. The paper should present them as supplementary evidence, not as the basis for the H2 claim.

### 5.3 Bajari-Ye Tests

**Exchangeability (KS test):** The KS test rejects the null that FL and non-FL bid residuals are drawn from the same distribution (D = 0.15, p < 0.001). However, with 28 million observations, any non-trivial difference in residual distributions will be detected. The KS statistic D = 0.15 is modest---it means the maximum gap between the two CDFs is 15 percentage points. More importantly, exchangeability failure can reflect cost heterogeneity (FL firms have different cost structures) rather than strategic coordination. Without richer first-stage controls (see M3), the exchangeability test is uninformative about collusion.

**Conditional independence:** Under baseline FE (item + year), FL pairwise product = 5.16, non-FL = 2.21. But the fake-groups placebo = 5.80 > 5.16, meaning random grouping produces *more* apparent coordination than the FL classification. Under tender FE, the ordering reverses the cover bidding prediction: FL (0.38) < non-FL (0.86). The paper's interpretation---that genuine bidders share cost information generating higher correlation---is plausible but not tested. If true, it implies that the conditional independence test cannot discriminate between cover bidding and cost correlation in this setting.

**Assessment:** The Bajari-Ye tests detect heterogeneity between FL and non-FL firms but do not establish that this heterogeneity reflects strategic coordination rather than cost or selection differences. Under the appropriate specification (tender FE), the results contradict the cover bidding prediction.

### 5.4 Staggered DiD (Callaway-Sant'Anna)

The DiD uses first FL entry as treatment at the market (item x PBU x year) level. The C&S ATT is 0.014 (SE = 0.040) for log prices---a near-zero estimate that is not statistically or economically significant. The MDE (0.078) exceeds the OLS benchmark (0.064), confirming that the design is underpowered.

**Treatment definition concern:** "First FL entry" is not an exogenous event. If cartels deploy FL firms in response to market conditions (high prices, low enforcement, new contracts), then treatment timing is endogenous. The paper does not address this beyond the pre-trend test (which is also underpowered).

**Assessment:** The DiD is uninformative. It should be removed from the main text entirely.

### 5.5 Mechanism Tests

The paper reports three mechanism tests (Table 6):

- **M1 (Competitive displacement):** FL-present tenders have *more* genuine competitors (0.143, p < 0.01). This is consistent with strategic selection but does not distinguish cover bidding from FL firms being attracted to competitive, high-value tenders.

- **M2 (Reference price calibration):** Winning bids in FL-present tenders are 4% closer to the reference price. This could reflect cover bidding but also item composition (FL-present tenders may involve more standardized goods with tighter price-reference spreads).

- **M3 (Reverse causality):** The reverse-causality coefficient (0.002) is economically negligible. This is convincing evidence that FL entry is not attracted by high prices.

**Missing mechanisms:** The paper does not test several alternative explanations that an IJIO referee will raise: (a) **financial distress**---firms near bankruptcy may bid on many tenders without winning, generating FL status without collusion; (b) **learning-by-doing**---new entrants may participate repeatedly while learning the procurement system; (c) **geographic scope**---FL firms may be geographically distant from PBUs and consistently outbid by local firms; (d) **minimum-bidder requirements**---firms may be invited by PBU officials to meet the three-bidder minimum for convite, creating FL status through institutional compliance rather than collusion.

---

## 6. ASSESSMENT OF CONTRIBUTION

The paper claims three contributions (Section 1.1):

### Contribution 1: FL as a screening marker (H1)

**Assessment: Solid.** This is the paper's strongest contribution. The FL concept is operationally simple (requires only participation and outcome data), produces firm-level flags (unlike tender-level screens), and is validated against CADE convictions. The OLS evidence is robust across specifications, matching estimators, and sensitivity analysis. For IJIO, this contribution alone is valuable, particularly given the policy relevance for developing-country competition authorities.

**Relative to prior work:** Imhof et al. (2017, 2018) and Huber & Imhof (2019) develop tender-level screens using bid-level features. The FL screen operates at the firm level using only participation data, which is a genuine advance in data parsimony. However, the paper does not demonstrate *empirically* that FL adds value above existing screens---the complementarity is asserted, not tested (see M8). Conley & Decarolis (2016) detect bidder groups from co-bidding patterns without bid values, which is closer to the FL approach than the paper acknowledges.

### Contribution 2: Causal evidence for cover bidding (H2)

**Assessment: Overstated.** The IV is fragile (M1), the Bajari-Ye results contradict the prediction under tender FE (M2), the network split shows zero price effect for the "most suspicious" FL firms (M4), and the DiD is uninformative (M6). Each individual strategy has defensible limitations; but when all five strategies fail to cleanly establish H2, the cumulative weight of evidence is weaker than the paper's framing suggests. The paper should reframe H2 as "suggestive evidence consistent with cover bidding, among other interpretations" rather than "substantial evidence for the causal mechanism."

**Relative to prior work:** Porter & Zona (1993) and Bajari & Ye (2003) test for collusion using bid-function tests with known cartel participants. This paper attempts the same without known participants, which is harder. The attempt is laudable, but the results do not clear the bar for a definitive contribution.

### Contribution 3: Bajari-Ye framework applied to FL classification

**Assessment: Marginal.** The Bajari-Ye tests use the FL classification to partition bidders into suspected cover bidders and genuine competitors, replacing the ad hoc groupings typically required. This is a reasonable application, but the results (especially under tender FE) do not produce clean evidence of coordination. The contribution is methodological (applying an existing framework with a new partition) rather than substantive (discovering new evidence of collusion).

**Relative to prior work:** Bajari & Ye (2003) is a standard tool. The novelty is the FL-based partition, but the partition's validity depends on whether FL firms are actually cover bidders---which is precisely what the Bajari-Ye tests are supposed to establish. The reasoning is circular unless the FL classification is validated independently (which the CADE validation partially provides).

### Overall novelty assessment

The FL concept is genuinely new as a *named, operationalized* screen. It is not, however, a deep conceptual advance: it amounts to flagging firms with zero wins and high participation as outliers. The theoretical model (Section 3) does not derive the FL concept from equilibrium; it assumes cover bidders exist and derives implications. The paper's contribution is primarily empirical and applied, which is appropriate for IJIO, but the framing should be calibrated accordingly.

---

## 7. CONCLUSION & RECOMMENDATION

I recommend **Major Revision**. The paper introduces a novel and potentially useful screening tool for bid rigging in procurement, validated against a large dataset with rich institutional variation. The H1 contribution (FL as a screening marker) is solid and policy-relevant. However, the causal identification (H2) does not meet IJIO's standard: the IV is fragile, the Bajari-Ye results are weaker than claimed, the network split produces internally inconsistent results, and the DiD is uninformative. The paper also lacks a direct comparison of FL against existing bid-level screens, which is essential for a paper claiming to introduce a new detection tool.

**Three conditions for acceptance at IJIO:**

1. **Reframe H2 as suggestive.** Downgrade the cover bidding mechanism from "substantial evidence" to "consistent evidence among multiple interpretations." Move the IV to supplementary analysis and anchor the paper on OLS + sensitivity analysis for the main price result. Present the Bajari-Ye results honestly, including the tender-FE reversal in the main text.

2. **Benchmark FL against existing screens.** Compute Imhof-style tender-level screen statistics for the sample. Show that FL adds incremental predictive power above bid-level screens, or acknowledge that FL is a complement for settings where bid-level data are unavailable (and demonstrate this constraint is binding in practice).

3. **Address the network-split inconsistency.** Either provide a compelling theoretical account of why "most suspicious" FL firms show no price effect and "least suspicious" firms drive the entire effect, or acknowledge that this pattern is difficult to reconcile with a uniform cover bidding mechanism and discuss alternative interpretations.

Meeting these three conditions would make the paper a strong contribution to IJIO.
