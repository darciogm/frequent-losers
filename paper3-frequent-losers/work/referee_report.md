# Referee Report

**Paper:** Frequent Losers as Cover Bidders in Public Procurement
**Authors:** Darcio Genicolo-Martins & Paulo Furquim de Azevedo (INSPER)
**Journal (Hypothetical submission):** International Journal of Industrial Organization (IJIO)
**Overall Recommendation:** Major Revision
**Date:** 2026-03-14

---

## SUMMARY

This paper proposes "frequent losers" (FL)---firms that never win yet participate in an abnormally large number of public procurement tenders---as a screening marker for cover bidding (shill bidding) in procurement auctions. Using 4.5 million tender-items and 40 million bids from Sao Paulo's BEC electronic procurement platform (2009--2019), the authors identify 2,735 FL firms via an IQR-based statistical threshold applied to firms with a zero win rate. The paper advances two hypotheses: (H1) that FL presence is a useful screening marker for collusion, and (H2) that FL firms are themselves cover bidders deployed by cartels. The main findings are: FL-present tenders exhibit 4--9% higher negotiated prices (OLS with item, year, and PBU fixed effects); a leave-one-out instrumental variable yields a 21% price markup (F = 396); 7.1% of FL firms co-participate with CADE-convicted cartelists (3.5x the rate expected by chance); and Bajari-Ye tests reject exchangeability and conditional independence for FL bid residuals. The paper is ambitious in scope, combining OLS, IV, network analysis, and bid-level diagnostics across a massive dataset with clear policy relevance.

---

## OVERALL ASSESSMENT

This is a well-executed empirical paper that makes a genuine contribution to the cartel screening literature. The FL concept is simple, implementable, and potentially useful for competition authorities---particularly in developing countries with limited bid-level data. The scale of the dataset is impressive. However, the paper's central identification challenge---separating cover bidding from selection and confounding---is not fully resolved, and the paper would benefit from a more disciplined treatment of what the evidence can and cannot establish. The single most important issue is the **exclusion restriction of the leave-one-out IV**, which is asserted rather than rigorously defended. The paper also suffers from a tension between its careful hedging (especially in the co-author edits visible throughout) and its substantive claims about causal mechanisms. A major revision addressing the IV identification, the Bajari-Ye interpretation, and the welfare analysis would make this paper competitive at IJIO or JLE.

---

## MAJOR COMMENTS

### 1. The leave-one-out IV exclusion restriction is insufficiently defended

The instrument (FL activity at other PBUs in the same product market and year) requires that FL supply at distant PBUs affects focal PBU outcomes *only* through FL participation at that PBU. This is a strong assumption. The paper acknowledges three threats (Section 5.2) but does not convincingly address the most important one: **correlated cartel organization**. If a cartel coordinates FL deployment across multiple PBUs simultaneously---which is exactly what a well-organized cartel would do---then the LOO instrument captures coordinated entry rather than exogenous supply variation. The balance test (Table B.2) shows statistically significant but "economically negligible" imbalance, but this framing is questionable: with N > 1.5 million, economic significance should be evaluated by computing the bias implied by the imbalance, not by inspecting standardized differences.

**Suggested fix:** (a) Formally derive the bias from violation of the exclusion restriction under a plausible model of coordinated cartel deployment. (b) Implement a falsification test using *time-lagged* FL supply (e.g., FL activity in t-2) as a placebo instrument---if the contemporaneous instrument captures cartel coordination, lagged supply should also predict prices. (c) Consider a Bartik-style decomposition (Goldsmith-Pinkham et al. 2020, already cited) to assess which product markets drive the first stage and whether those markets have characteristics consistent with exogenous supply variation.

### 2. The Bajari-Ye results are substantially weaker than presented

The Bajari-Ye tests are presented as strong evidence for cover bidding, but the tender-FE specification (Table B.12) tells a more nuanced story. Under tender fixed effects, FL pairwise product (0.38) is *lower* than non-FL pairwise product (0.86). The paper acknowledges this but argues it is "not inconsistent" with cover bidding because genuine bidders share cost information. This is a significant concession: the Bajari-Ye framework is designed precisely to detect *excess* coordination among suspected colluders relative to competitive bidders. If FL pairs show *less* within-tender correlation than non-FL pairs after absorbing tender-level shocks, the test is not rejecting competitive bidding for FL firms specifically---it is rejecting exchangeability, which could reflect *any* systematic difference between FL and non-FL bidders (e.g., different cost structures, geographic reach, or firm size).

**Suggested fix:** (a) Acknowledge explicitly that the tender-FE Bajari-Ye results do not support the cover bidding interpretation and may instead reflect cost heterogeneity. (b) Report the first-stage R-squared and discuss how well observable cost shifters predict bids---if the first stage is weak, the residuals may capture cost heterogeneity rather than strategic behavior. (c) Consider implementing the Bajari-Ye tests within narrow product categories to reduce cross-item cost heterogeneity.

### 3. The network-based FL classification is ad hoc and drives key results

The paper splits FL firms into "concentrated-market" and "competitive-market" subgroups based on winner HHI and repeat partners (Section 5.3). This classification is data-driven with no theoretical justification for the specific cutoffs (median HHI, repeat partners >= 2). The resulting network split produces a striking asymmetry: competitive-market FL drives the entire price effect (0.126), while concentrated-market FL shows *negative* coefficients (-0.018). This asymmetry is presented as evidence for cover bidding, but it could equally reflect that FL firms in competitive markets are simply *different firms* that happen to participate in higher-priced tenders for non-collusive reasons (e.g., they are small firms attracted to competitive, higher-value tenders).

**Suggested fix:** (a) Provide formal justification for the classification cutoffs---currently, median HHI is used without discussion of why this is the right break point. (b) Show that the results are robust to continuous specifications (the paper reports one in Table B.13, but the interaction is not significant). (c) Discuss the possibility that competitive-market FL firms are simply firms with different characteristics that correlate with both FL status and prices.

### 4. The welfare analysis conflates bounds with point estimates

The welfare analysis (Section 8.5) presents OLS (R$734M) as a "lower bound" and IV (R$2.4B) as an "upper bound," with the cross-fit estimate (R$410M) as an intermediate. This framing is misleading. The OLS estimate is a lower bound *only if* measurement error is the sole source of attenuation---but omitted variable bias, reverse causality, or selection could cause OLS to *overestimate* the effect. The IV estimate is an upper bound *only if* the instrument is valid---but LATE heterogeneity could also explain the IV-OLS gap without any attenuation. Presenting these as tight welfare bounds overstates precision.

Furthermore, the welfare calculation simply multiplies the price coefficient by total FL-present procurement value, ignoring general equilibrium effects (deadweight loss, allocative efficiency, entry deterrence).

**Suggested fix:** (a) Acknowledge that OLS could be an upper or lower bound depending on the sign and magnitude of omitted variable bias. (b) Use the Cinelli-Hazlett sensitivity framework (already implemented) to bound the OLS estimate from below. (c) Reframe the welfare analysis as back-of-the-envelope calculations rather than bounds, and discuss what is excluded (deadweight loss, dynamic effects).

### 5. The FL definition threshold is arbitrary and the paper does not fully grapple with this

The paper uses median + 1.5 * IQR on the participation distribution of always-losers, yielding a threshold of approximately 14 participations. This departs from the standard Tukey rule (Q3 + 1.5 * IQR) and the footnote in Section 4.2 explains this is due to right skewness. However, (a) the standard Tukey rule *is designed* for skewed distributions, so the departure needs stronger justification; (b) the choice of 1.5 as the multiplier is inherited from the Tukey convention but applied to a different statistic, making it doubly arbitrary; (c) the threshold sensitivity exercise (Section 8.1) shows monotonically increasing coefficients with stricter thresholds, which is consistent with the screen working *but also* consistent with progressively more extreme firms having more extreme price outcomes for non-collusive reasons (e.g., they participate in more unusual, higher-priced markets).

**Suggested fix:** (a) Show that the main results hold with data-driven threshold selection (e.g., a changepoint analysis or a kink in the relationship between participation count and the price coefficient). (b) Report the distribution of FL firm characteristics at different thresholds to assess whether higher-threshold firms are genuinely "more suspicious" or merely different along observable dimensions.

### 6. The CADE validation is weaker than the presentation suggests

The CADE validation shows that 7.1% of FL firms co-participate with convicted cartelists, versus 2.0% for a participation-intensity-matched random draw (3.5x ratio, p < 0.001). While statistically significant, this means 92.9% of FL firms have no CADE overlap. The paper addresses this by arguing that CADE captures only 1-5% of actual cartels, but this argument is unfalsifiable---it could justify any overlap rate. More importantly, the unconditional chi-squared comparison (7.1% vs 5.9%, odds ratio = 1.21) is barely significant and economically small. The permutation test is more impressive, but it compares FL firms to *always-losers*, not to all firms. If always-losers as a group are already less connected to cartel markets (because they never win), the 3.5x ratio may overstate FL firms' cartel association relative to the general population.

**Suggested fix:** (a) Report the co-participation rate for *all* firms (not just always-losers) as the baseline comparison. (b) Conduct a regression-based test: does CADE overlap predict the FL-price coefficient at the tender level? (c) Compute the positive predictive value and false positive rate of the FL screen against the CADE benchmark to give readers a more calibrated sense of screen performance.

### 7. The convite-pregao difference is underexplored and potentially informative

The paper finds a larger FL coefficient for pregao (9.3%) than convite (3.8%), which it explains as reflecting real-time bid observation and the minimum-bidder rule. But convite is precisely the modality where cover bidding should be *most* valuable---the three-bidder minimum creates a direct incentive. The larger pregao effect may instead reflect that FL firms in pregao are selected into higher-value or more competitive tenders, or that the pregao sample has different composition. The paper's explanation (Section 6.4) is plausible but speculative.

**Suggested fix:** (a) Show that the pregao-convite difference persists after controlling for tender value and number of genuine competitors. (b) Test whether the difference is driven by composition (different items, PBUs, or years in each modality) by running the split regressions on the intersection of items that appear in both modalities.

### 8. Sample construction creates a potential selection problem

The analysis sample is restricted to "item types that have at least one tender with FL participation" (restriction iii in Section 4.3). This conditions on the treatment and creates a selected sample: only markets where FL firms choose to participate are included. If FL firms select into markets with higher prices or more collusion-prone characteristics, the sample restriction mechanically inflates the FL-price association. The paper reports that the unrestricted sample yields a similar coefficient (0.063 vs 0.064), which is reassuring but not definitive---item fixed effects in the restricted sample absorb item-level means, which may mask composition effects.

**Suggested fix:** Report the unrestricted sample results more prominently (not just in the robustness section) and discuss whether they should be the preferred specification.

---

## MINOR COMMENTS

1. **Abstract, line 3:** "4--9% higher negotiated prices" is the OLS range, but the abstract also mentions the 21% IV markup. The reader may confuse these as comparable estimates. Clarify that the 4--9% is OLS and the 21% is LATE/IV.

2. **Section 3, Equation 1:** The first-order condition claim that $m^*$ is increasing in $n$ is stated without proof. For a "minimal model," this is fine, but the paper should note that this depends on the functional form of $\pi(m, n)$ and that the comparative static is assumed rather than derived.

3. **Table 1 (Descriptive Statistics):** FL-present tenders have a mean negotiated price of R$140,673 vs R$12,465 for non-FL tenders---a factor of 11. This enormous difference in levels (even in logs: 4.92 vs 2.49) raises concerns about whether FL firms select into fundamentally different (larger, more complex) tenders. The item fixed effects may not fully absorb this heterogeneity if item groups are broad.

4. **Section 5.4 (Bajari-Ye Test Design):** The pairwise product interpretation ("when one FL bid is R$1 above predicted, the paired FL bid is R$5.16 above") assumes log residuals have been exponentiated. Clarify the units and transformation.

5. **Table 3 (First Stage):** The partial R-squared is extremely low (0.0002--0.0006). While the F-statistic is large due to the massive sample size, the instrument explains essentially none of the variation in FL presence. This raises concerns about what the instrument is actually capturing: with a partial R-squared this low, the 2SLS estimate may be driven by a small number of observations where the instrument has meaningful variation.

6. **Section 6.3 (Bajari-Ye, Panel C):** The fake-groups pairwise product (5.80) *exceeds* the FL pairwise product (5.16). This is mentioned but not fully digested: it means that the baseline conditional dependence test is uninformative---the FL-specific signal is *smaller* than what random grouping produces among non-FL firms, even before tender FE.

7. **Section 7 (Mechanisms, M2):** The reference price calibration test finds that winning bids in FL-present tenders are 4% closer to the reference price. But this could also reflect that FL firms participate in tenders with tighter reference price anchoring (e.g., standardized goods), not that cartels calibrate bids.

8. **Notation inconsistency:** The paper uses `losers_igt` in Section 5.1 but `losers` in Table 2 headers. Standardize throughout.

9. **Section 8.4 (DiD):** The DiD MDE (0.076) exceeds the OLS estimate (0.064), meaning the DiD is underpowered for the effect of interest. The paper acknowledges this, but the DiD section currently occupies substantial space for something the authors explicitly do not rely on. Consider moving the entire DiD discussion to the appendix.

10. **Table 7 (Network Split):** The table header says "Price Effects by FL Suspicion Level" but the text (Section 6.4) relabeled these as "concentrated-market" and "competitive-market." Update the table header to match the text.

11. **References:** The bibliography has 35 entries, which is lean for a paper of this ambition. Notable absences include: Wallimann et al. (2023, IJIO) on ML-based cartel screening, Huber & Imhof (2019) on bid-rigging detection with limited data, and Clark et al. (2021) on the dynamics of collusive cartels. The paper should position itself relative to these more recent contributions.

12. **Section 3.2 (Two Regimes):** The uniform and normal distributional assumptions for Regimes 1 and 2 are quite specific. The predictions would be more robust if derived from weaker assumptions (e.g., stochastic dominance for Regime 1, variance comparison for Regime 2) rather than parametric distributions.

13. **Figure 1:** The figure shows the distribution of participations among always-losers, but the IQR threshold line is hard to interpret without the numerical value being displayed on the figure itself. Add the threshold value (approximately 14) as an annotation.

14. **Welfare Table (Table B.5):** The "High-Suspicion FL" column shows a *negative* welfare loss (R$-88M), meaning concentrated-market FL firms are associated with *lower* prices. This directly contradicts the cover bidding hypothesis for this subgroup and should be discussed.

15. **CO-AUTHOR EDIT comments:** Several LaTeX comments of the form "% CO-AUTHOR EDIT:" are visible throughout the source. While these are helpful for tracking revisions, they should be removed before submission.

---

## TARGET JOURNAL ANALYSIS

### RAND Journal of Economics
**(a) Fit:** Moderate. RAND publishes IO papers with clear theoretical contributions and rigorous identification. **(b) What is needed:** A tighter theoretical model generating sharper predictions than the current "minimal framework." The Bajari-Ye analysis would need to be significantly strengthened---RAND referees will expect structural estimation or at least clean reduced-form tests. The IV identification concerns would need to be resolved. Current version is below the RAND bar.

### Review of Economics and Statistics (ReStat)
**(a) Fit:** Good. ReStat values applied econometrics with clear policy relevance and novel data. **(b) What is needed:** The identification must be bullet-proof. Resolve the IV exclusion restriction issue (Major Comment 1). The paper's length is appropriate for ReStat, but the robustness section should be tightened---currently it reads as comprehensive but somewhat unfocused. The CADE validation is a natural selling point.

### Journal of Law and Economics (JLE)
**(a) Fit:** Strong. JLE publishes empirical papers on antitrust and regulation with lower identification bars than top-5 journals. **(b) What is needed:** Strengthen the institutional context (more on Brazilian procurement law, CADE enforcement). The policy blueprint in the conclusion is well-suited for JLE readers. Address the welfare analysis concerns. This is a realistic target with a major revision.

### Journal of Law, Economics, and Organization (JLEO)
**(a) Fit:** Good. JLEO values institutional detail and organizational economics. **(b) What is needed:** Deepen the discussion of how cartels organize cover bidding (draw more on Asker 2010, Marshall & Marx 2012). The network analysis could be extended to characterize the organizational structure of suspected cartels. Currently, the organizational dimension is underexplored.

### International Journal of Industrial Organization (IJIO)
**(a) Fit:** Very strong. This is the natural home for this paper. IJIO publishes empirical IO papers on competition policy with moderate identification requirements. **(b) What is needed:** Address the IV and Bajari-Ye concerns, tighten the welfare analysis. The current version is close to IJIO standards. A revision addressing Major Comments 1, 2, and 4 would make this competitive.

### AER Papers & Proceedings (short version)
**(a) Fit:** Good for a 4-page version focused on the FL concept and OLS/CADE validation. **(b) What is needed:** Radical compression to 3,000 words. Focus on: FL definition, one OLS table, CADE validation, policy implications. Drop IV, Bajari-Ye, and welfare analysis. The novelty of the FL concept carries well in short format.

### Journal of Public Economics (JPubE)
**(a) Fit:** Moderate. JPubE values welfare analysis and public expenditure implications. **(b) What is needed:** A credible welfare analysis (the current one is too speculative---see Major Comment 4). Quantify the fiscal implications for the State of Sao Paulo and benchmark against the cost of procurement monitoring. The welfare bounds need to be tightened considerably.

---

## ROADMAP TO TOP-5

To be competitive at AER, QJE, JPE, ReStud, or Econometrica, this paper would need substantial changes in four areas. I am candid that this bar is *very high* and may not be reachable from the current version, but the pathway would be:

### 1. Identification (Critical)
The current OLS + IV approach is below the top-5 bar for causal claims. Options:
- **Structural estimation:** Estimate a structural model of bidding with cover bidders as a latent type (cf. Kawai et al. 2019). This would allow quantifying the welfare cost from the model rather than back-of-the-envelope calculations. This is the Econometrica/ReStud pathway.
- **Quasi-experimental variation:** Find an institutional shock to FL availability (e.g., a change in bidder registration rules, enforcement action, or procurement reform) that creates plausibly exogenous variation. This is the AER/QJE pathway.
- **RDD:** If there is a registration or qualification threshold that generates discontinuous variation in FL participation, this could provide credible identification.

### 2. Theory (Important for Econometrica/ReStud)
The "minimal model" is too minimal for a theory journal. Develop a full equilibrium model of cover bidding in procurement with: endogenous cartel formation, optimal cover bidder deployment, and interaction with procurement design (reserve prices, minimum bidder rules). Generate structural predictions testable in the data.

### 3. External Validity (Important for AER/QJE)
Currently, evidence comes from a single platform (BEC) in a single state (Sao Paulo) in a single country (Brazil). For a top-5 publication, the paper would need to demonstrate that the FL screen works in at least one additional setting---ideally a developed country with stronger data quality. This could be a separate paper or a major extension.

### 4. Policy Design (Important for AER/QJE)
Go beyond description to prescription: design a mechanism that optimally uses FL information in procurement design. For example, how should a procurer adjust reserve prices, minimum bidder requirements, or auction format when FL firms are detected? This would connect to the mechanism design literature and significantly elevate the contribution.

### Honest Assessment
The most realistic top-5 pathway is to pair the FL screening concept with structural estimation (Econometrica pathway) or to find a compelling natural experiment (AER/QJE pathway). The current reduced-form approach, even with the IV, is more naturally suited to IJIO, JLE, or ReStat. This is not a criticism---these are excellent journals, and the paper makes a solid contribution at that level.

---

## CONCLUSION

This paper introduces a novel and implementable screening marker for bid rigging in public procurement. The FL concept is simple, data-parsimonious, and practically relevant. The empirical execution is thorough, with an impressive array of robustness checks and complementary analyses. However, the paper's causal claims outpace its identification: the IV exclusion restriction is not convincingly defended, the Bajari-Ye results are weaker than presented (especially under tender FE), and the welfare analysis conflates bounds with point estimates. A major revision addressing these issues---particularly the IV identification and the Bajari-Ye interpretation---would make this a strong paper for IJIO or JLE. The paper should lean more heavily into its H1 contribution (FL as a screening tool) and be more measured about H2 (FL as causal cover bidders). The empirical toolkit is already in place; what is needed is more disciplined framing of what the evidence can and cannot establish.

I recommend **Major Revision** with resubmission.
