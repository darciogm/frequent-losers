# REFEREE REPORT

**Manuscript:** "Frequent Losers as Cover Bidders in Public Procurement"
**Authors:** Genicolo-Martins & Furquim de Azevedo (INSPER)
**Journal:** RAND Journal of Economics
**Version:** v8 (March 2026)
**Recommendation:** Accept with Minor Revisions

---

## I. Summary

This paper proposes a firm-level screening tool for bid-rigging cartels in procurement auctions. "Frequent losers" (FL) are firms that never win a single tender yet participate abnormally often --- a behavioral pattern consistent with cover bidding, in which cartels deploy sham bidders to simulate competition. Using 4.5 million tender-items and 40 million bids from Sao Paulo's BEC electronic procurement platform (2009--2019), the authors:

1. Develop a structural framework for cover-bidder deployment with explicit assumptions, formal proofs, and five testable predictions (Section 3);
2. Identify 2,735 FL firms using a statistical threshold (median + 1.5 x IQR on participation among always-losers);
3. Estimate the structural mixture model, selecting Regime 2 (coordinated cover bidding, sigma_c/sigma_g = 0.72) by BIC;
4. Show that FL-present tenders exhibit 3.6--6.6% higher prices across six independent estimators (OLS, cross-fit, matching, structural n-conditional, IV);
5. Validate the FL screen against CADE cartel convictions (AUC = 0.94), outperforming Imhof-style bid-level screens (AUC = 0.79);
6. Compute three policy counterfactuals: removing the minimum-bidder rule (R$74M savings), optimal screening threshold (1.6x IQR at R$100K/investigation), and detection probability calibration.

The paper has improved substantially through revision. The formalized structural model, honest treatment of identification limitations, and novel counterfactual analysis represent genuine contributions to the cartel-detection literature.

---

## II. Overall Assessment

This is a strong empirical paper that makes three contributions meriting publication at RAND:

**First**, the FL screen is a practical, data-parsimonious detection tool that dominates existing bid-level screens on the same ground truth while requiring *less data* (participation records only, no bid values). This has immediate policy relevance for competition authorities in developing countries where bid-level data are unavailable.

**Second**, the structural framework provides formal economic foundations for the screening rule. The five testable predictions --- price effect, strategic selection, regime identification, market selection, and exchangeability violation --- are all empirically confirmed, with the market-selection heterogeneity (12.6% effect in competitive markets vs. -1.8% in concentrated markets) being the most striking result.

**Third**, the counterfactual welfare analysis demonstrates that the structural model delivers policy-relevant predictions beyond what the reduced form alone provides: the optimal screening threshold, the welfare gain from removing the minimum-bidder rule, and the marginal value of increased detection.

The paper's identification strategy is necessarily multi-pronged rather than relying on a single clean quasi-experiment. The honest framing --- presenting six estimators as a convergence band rather than privileging any single one, demoting the IV to supplementary status, and elevating the cross-fit as the conservative preferred estimate --- is appropriate and credible.

---

## III. Major Comments

### 1. The structural model's Assumption A1 needs stronger economic foundations

Assumption A1 states that the cartel's surplus pi is weakly increasing in the number of cover bidders m. This is the foundation of the entire model, yet it is asserted without formal derivation. The intuition --- that cover bidders help sustain higher prices by creating the appearance of competition --- is plausible but needs microfoundations.

In a standard first-price sealed-bid auction, adding bidders who never win does not mechanically increase the winner's surplus. The mechanism must operate through one of: (a) satisfying the minimum-bidder constraint (formalized in the corner solution); (b) deterring genuine entry by inflating apparent competition; (c) contaminating forensic screens with noise.

Channel (a) is already captured in the constraint. Channels (b) and (c) would require explicit modeling of genuine bidders' entry decisions and detection algorithms. I encourage the authors to either (i) formally model one of these channels, or (ii) state more precisely that A1 is an assumption about the *reduced-form* relationship, supported empirically by the positive FL-price coefficient but not derived from auction theory.

This is a revision item, not a rejection concern. The empirical results stand regardless of the theoretical foundations.

### 2. The "convergence" of six estimators overstates precision

The paper presents six markup estimates (cross-fit 3.6%, structural 6.4%, IPW 5.7%, OLS 6.6%, CEM 8.0%, IV 21.4%) and frames their convergence as evidence of robustness. The five non-IV estimates span 3.6--8.0% --- a factor of 2.2.

This framing has two problems. First, each estimator uses different identifying assumptions; variation across estimators reflects assumption sensitivity, not sampling uncertainty. The 3.6% cross-fit and 8.0% CEM answer somewhat different questions (out-of-sample prediction vs. matched treatment effect). Second, the ordering CEM > OLS > IPW is somewhat unusual --- CEM typically yields lower estimates than OLS when matching improves balance --- and deserves brief discussion.

I suggest the authors present the estimates more transparently as a *sensitivity analysis* rather than *convergence evidence*. The cross-fit (3.6%) is the most conservative and arguably most credible; the OLS (6.4%) is the standard benchmark; the CEM/IPW bracket the OLS. This is strong evidence of robustness, but calling it "convergence" implies more precision than warranted.

### 3. Counterfactual welfare depends on unobserved deterrence rate

The optimal-screening-threshold counterfactual (CF2) depends critically on the deterrence rate delta --- the fraction of detected cartels that cease cover bidding after investigation. The paper uses delta = 0.50 as the baseline, yielding R$135M net welfare, but does not present sensitivity analysis across delta.

At delta = 0.10 (investigations mostly ignored), welfare drops dramatically; at delta = 0.90, it rises proportionally. Since delta is the key unobserved parameter driving the policy recommendation, the figure showing optimal threshold as a function of investigation cost should also show the sensitivity to delta. This appears to have been computed (the script includes multiple deterrence rates) but the presentation in the text focuses only on delta = 0.50.

---

## IV. Significant Comments

### 4. The Regime 2 parametric specification is untested against flexible alternatives

The BIC comparison selects Regime 2 (log-normal) over Regime 1 (uniform) with overwhelming margin (Delta-BIC = -91,473). This is strong evidence that log-normal fits better than uniform, but it is not evidence that log-normal is the *correct* specification. A non-parametric alternative (kernel density estimation of the FL bid spread distribution) would provide a model-free benchmark. If the non-parametric distribution is multimodal or heavy-tailed, the log-normal assumption may be misleading despite its lower BIC.

### 5. Alternative explanation: quality heterogeneity

The paper discusses learning (FL firms are ~1 year younger) and reverse causality (elasticity ~ 0.004) as alternative explanations, but does not formally test quality heterogeneity. If FL firms are persistently low-quality or high-cost, they would lose every tender by competitive forces, not by cartel design. The key test would be: do FL firms' *bids* look like cost-competitive bids that happen to lose, or like strategically inflated bids designed to lose? The structural estimation partially addresses this (cover bids have different dispersion than genuine bids), but a direct quality test --- e.g., comparing FL firms' bid-to-reference-price ratios with non-FL losers --- would strengthen the argument.

### 6. CADE ground truth limitations deserve a formal caveat paragraph

The paper uses CADE co-participation as ground truth for the ROC analysis, with appropriate caveats scattered throughout. However, there is no single consolidated discussion of the three key limitations of this ground truth: (a) CADE convictions are not a random sample of true cartels (enforcement-determined); (b) co-participation is not proof of cartel membership (FL firms may co-bid with convicted firms coincidentally); (c) the low base rate (0.58%) means precision is necessarily low at all thresholds. A consolidated paragraph early in Section 7.2 would help the reader evaluate the ROC results.

### 7. External validity

The paper is entirely based on BEC data from Sao Paulo (2009--2019). The FL definition and screening rule may not transfer to other procurement systems where: (a) minimum-bidder requirements differ; (b) electronic auction formats vary; (c) cartel behavior adapts to different legal frameworks. The conclusion mentions external validation as future research (item (i)), but a brief discussion of *which features of BEC* make FL screening effective would help readers assess transferability.

---

## V. Minor Comments

8. **Abstract precision**: "3.6--6.6%" is the appropriate range for the headline estimate. Good.

9. **Proposition 4 proof**: The cross-derivative condition (Equation 24) is correctly stated as an assumption with economic content. The proof via IFT is clean. No issues.

10. **Precision-recall figure**: Excellent addition. The low precision at all thresholds (3.6% at 1.5x) is clearly communicated. The connection to the counterfactual screening-threshold analysis is well-drawn.

11. **Imhof comparison**: The FL screen (AUC = 0.94) convincingly outperforms the Imhof composite (AUC = 0.79, DeLong p < 0.001). The caveat that Imhof is implemented as a CV/kurtosis/spread proxy rather than the full ML classifier is appropriately stated.

12. **Bajari-Ye tender-FE resolution**: The three-point explanation (common shocks, focal-point absorption under Regime 2, mechanical conservatism of tender FE) is well-argued and internally consistent. The footnote clarifying that the tender-FE table uses the baseline first-stage while the main table uses the enriched first-stage is helpful.

13. **Robustness summary table**: Excellent compression. The tabular format with Check/Coefficient/SE/N/Note columns is much more efficient than the previous prose format while preserving all information.

14. **Welfare bounds**: The three-level presentation (cross-fit R$400M, OLS R$734M, IV R$2.4B) with clear labeling of lower bound / baseline / upper bound is well-done. The cross-fit as "preferred conservative" welfare figure is appropriate.

15. **Reference price institutional detail**: The footnote in Section 3.1 explaining BEC reference-price formation (median of three quotations) and the connection to the bad-control concern in robustness is a valuable addition.

---

## VI. Questions for the Authors

1. Can you provide a formal model of how cover bidders increase cartel surplus beyond the minimum-bidder constraint? Specifically, does the marginal return to cover bidding come from (a) deterring genuine entry, (b) contaminating forensic screens, or (c) manipulating reference prices?

2. How does the cross-fit attenuation (44%) compare to what you would expect from pure measurement-error attenuation in a binary treatment variable? Is there a way to decompose the attenuation into classification noise vs. temporal instability vs. broken mechanical correlation?

3. Have you considered fitting a non-parametric (kernel density) model for the cover-bid distribution as a robustness check on Regime 2's log-normal specification?

4. What is the expected number of always-losers (win_rate = 0, participation > 14) under a null hypothesis of random competitive bidding with the observed number of firms and tenders? This would quantify how many FL firms could arise by chance.

5. The counterfactual welfare analysis assumes the OLS markup (0.064) applies uniformly to all FL-present tenders. Is the markup heterogeneous across the distribution of FL intensity (m = 1 vs. m = 5)?

---

## VII. Recommendation

**Accept with Minor Revisions.**

The paper makes a genuine contribution to the cartel-detection literature. The FL screen is practical, well-validated, and addresses a real policy need. The structural framework provides economic foundations, and the counterfactual analysis demonstrates policy relevance. The identification strategy is multi-pronged and honestly presented.

The remaining issues are minor revisions:

1. Strengthen the economic foundations of Assumption A1 (one paragraph of discussion, not a new model);
2. Reframe the "convergence" of six estimators as sensitivity analysis;
3. Add deterrence-rate sensitivity to the counterfactual welfare analysis;
4. Consolidate the CADE ground-truth caveats;
5. Add a brief external-validity discussion.

None of these require new estimation or fundamental changes to the paper's structure. The paper is well-written, appropriately scoped, and makes claims that are supported by the evidence. I recommend publication after these minor revisions.

---

**Referee credentials:** Expert in industrial organization, antitrust economics, and cartel detection. Familiar with Bajari-Ye, Imhof, Porter, and the structural auction estimation literature.
