# Referee Report --- RAND Journal of Economics

**Paper:** Frequent Losers as Cover Bidders in Public Procurement
**Authors:** Genicolo-Martins & Furquim de Azevedo
**Recommendation:** Reject with invitation to resubmit
**Date:** 2026-03-15

---

## 1. SUMMARY

This paper proposes "frequent losers" (FL)---firms that never win yet participate in an abnormally large number of public procurement tenders---as a screening marker for cover bidding. Using 4.5 million tender-items and 40 million bids from Sao Paulo's BEC platform (2009--2019), the authors identify 2,735 FL firms via a median + 1.5 x IQR threshold on the participation distribution of always-losers. The main empirical findings are: (1) FL-present tenders exhibit 4--9% higher negotiated prices in OLS with item, year, and purchasing-unit fixed effects; (2) a leave-one-out IV yields a 21% LATE (F = 396); (3) 7.1% of FL firms co-participate with CADE-convicted cartelists, 3.5x the participation-adjusted rate; (4) Bajari-Ye tests reject exchangeability and conditional independence for FL bid residuals, though with important caveats under tender FE; (5) a network-based classification shows the price effect concentrates in competitive markets. The paper advances two hypotheses: H1 (FL as screening marker) and H2 (FL as causal cover bidding mechanism).

---

## 2. OVERALL ASSESSMENT

The paper does not currently meet RAND's identification standard for its central causal claim. The leave-one-out IV---the only strategy that moves beyond conditional correlation---fails balance on all four observable characteristics (Table B.8), produces an implausibly large estimate under a more saturated FE structure (3.64 in Panel C), and rests on an exclusion restriction that the authors themselves acknowledge is "more concerning" than originally presented. The Bajari-Ye tests, intended to provide non-structural corroboration, produce internally inconsistent results: the fake-groups placebo (Panel C of Table 11) yields a pairwise product of 5.80 that *exceeds* the FL product of 5.16, and the tender-FE specification reverses the magnitude ordering (FL: 0.38 < non-FL: 0.86). The DiD is null (ATT = 0.014, SE = 0.039). RAND publishes papers where the primary identification strategy is credible; here, the primary strategy (IV) is supplementary by the authors' own admission, and the supplementary evidence (Bajari-Ye, DiD) is either contradictory or uninformative. The H1 contribution---FL as a practical screening tool---is genuine and empirically supported, but it is a policy contribution rather than the identification or structural contribution RAND typically requires.

---

## 3. MAJOR COMMENTS

### [M1] The IV fails RAND's identification standard

**Problem:** The LOO instrument (Equation 3) counts FL firms active at *other* PBUs in the same product group and year. Table B.8 (balance tests) shows that the instrument significantly predicts all four observable characteristics---number of firms, number of bids, convite indicator, and reference price---after absorbing item, year, and PBU fixed effects. The authors report standardized differences below 0.03 sigma and frame this as "economically negligible." With N = 1.65 million, 0.03 sigma corresponds to t-statistics well above conventional thresholds. The authors now acknowledge in Section 6.2 that "the pattern of statistically significant imbalance across all four observables is more concerning than any single coefficient." This is correct, and it is fatal for a causal claim at RAND.

**Location:** Section 6.2, Section 7.2, Table B.8.

**Why it matters for RAND:** RAND's standard for IV identification requires (a) a plausible exclusion restriction, (b) balance on pre-determined observables, and (c) robustness to specification choices. This paper fails (b) on its own terms and fails (c) because Panel C (item-group x year FE) produces an estimate of 3.64, an order of magnitude larger than Panel A (0.194). The paper correctly dismisses Panel C as weak-instrument amplification, but this is evidence that the IV estimate is specification-sensitive, not robust.

**What would resolve it:** Either (i) provide Conley-Hansen-Rossi (2012) bounds on the 2SLS estimate allowing for violations of the exclusion restriction proportional to the observed imbalance, or (ii) find a different source of exogenous variation in FL exposure---an institutional change, a geographic discontinuity, or a policy shock that plausibly shifts FL supply without directly affecting prices.

---

### [M2] The Bajari-Ye tests are internally inconsistent

**Problem:** Three results undermine the Bajari-Ye evidence:

(a) **Fake-groups placebo failure.** The fake-groups placebo (Panel C of Table 11) randomly splits non-FL firms into two groups and computes pairwise residual products. The placebo product is 5.80---*larger* than the FL product of 5.16. Under the cover-bidding hypothesis, FL pairs should exhibit *stronger* correlation than random non-FL pairs, not weaker. The paper argues that the FL vs. non-FL difference (5.16 vs. 2.21 = 2.95) is the relevant comparison, not the FL vs. fake-groups comparison. But the fact that random non-FL pairs exhibit even stronger within-tender correlation than FL pairs raises the possibility that what the test detects is tender-level heterogeneity, not bid coordination.

(b) **Tender-FE reversal.** Under tender FE (Table B.17), which absorb all tender-level confounds, the FL pairwise product drops from 5.16 to 0.38 while the non-FL product drops from 2.21 to 0.86. The magnitude ordering reverses: FL (0.38) < non-FL (0.86). The paper interprets this as "genuine bidders share cost information that induces residual correlation," which is plausible but untested. The key issue is that Prediction 5 (Section 3.3) now predicts FL residuals "differ systematically" without a magnitude claim, but the original Bajari-Ye (2003) conditional-independence test is specifically designed to detect *stronger* within-group correlation as evidence of coordination. The FL group failing this relative comparison undermines the test's evidentiary value.

(c) **First-stage endogeneity concern.** Section 6.4 describes the Bajari-Ye first stage as including "firm size, firm age, CNAE sector dummies, number of bids, and item and year fixed effects." The inclusion of *number of bids* is potentially problematic: if FL presence mechanically increases the number of bids in a tender (Table 6 shows this), and number of bids is included as a regressor in the first-stage bid equation, the residuals are mechanically correlated with FL status through the prediction error on this endogenous variable. Bajari and Ye (2003, p. 978) explicitly note that their test requires the first-stage regressors to be cost shifters, not endogenous market outcomes. The number of bids in a tender is an equilibrium outcome, not a cost shifter.

**Location:** Table 11 (Panels A-C), Table B.17, Section 7.4.

**Why it matters for RAND:** The Bajari-Ye tests are presented as the third leg of the evidentiary tripod (alongside OLS and IV). If the tests are internally inconsistent and the first stage includes an endogenous variable, the non-structural corroboration falls apart.

**What would resolve it:** (i) Remove number of bids from the Bajari-Ye first stage and re-estimate. (ii) Run the fake-groups placebo separately within FL-present and FL-absent tenders to diagnose whether tender-level heterogeneity drives the result. (iii) Provide a formal test of whether the magnitude reversal under tender FE is statistically significant (bootstrap the FL - non-FL difference under tender FE).

---

### [M3] The theoretical framework is a descriptive taxonomy, not a model

**Problem:** Section 3 presents a "conceptual framework" with a cartel profit maximization problem (Equation 1), two regime definitions, and five predictions. However: (i) the first-order condition is stated but not derived---the paper asserts that m* is increasing in n and decreasing in theta without showing the derivation; (ii) Regimes 1 and 2 are defined by distributional assumptions on cover bids (uniform vs. normal), not by equilibrium conditions---there is no strategic interaction among bidders, no game tree, no equilibrium concept; (iii) Predictions 1-5 are assertions about observables under cover bidding, not derived comparative statics from a model.

This matters because several predictions are not actually tested in the paper. Specifically:

| Prediction | Claimed test | Assessment |
|---|---|---|
| 1 (Price effect) | Table 5 OLS | Tested |
| 2 (Strategic selection) | Table 6 | Tested |
| 3 (Regime identification) | Section 7.5, Figure 7 | Visual only; no formal test |
| 4 (Exchangeability) | Table 11, Panel A | Tested (KS test) |
| 5 (Bid heterogeneity) | Table 11, Panel B | Tested but contradicted under tender FE |

Prediction 3 has no formal statistical test---the regime comparison is based on a visual comparison of density plots (Figure 7). There is no variance-ratio test, no formal model selection, and no likelihood comparison.

**Location:** Section 3, Section 7.5.

**Why it matters for RAND:** RAND expects theoretical frameworks that generate precise, falsifiable predictions derived from strategic interaction. A taxonomy of cover-bidding regimes is useful for organizing the empirical analysis but does not meet RAND's theory standard. If the theory section remains as is, the paper should explicitly label it as a "descriptive framework" or "empirical classification" rather than using the language of predictions and comparative statics.

**What would resolve it:** Either (i) develop a simple game-theoretic model of cover bidding that derives the optimal cover-bid distribution as a function of the number of genuine bidders, detection probability, and auction format, generating the regimes as equilibrium outcomes; or (ii) honestly relabel Section 3 as a descriptive taxonomy and strengthen the empirical contribution to compensate (e.g., the Detection Tool reframe).

---

### [M4] The network split contradicts the cover-bidding hypothesis

**Problem:** Table 9 splits FL firms into "concentrated-market" (winner HHI above median, repeat partners >= 2) and "competitive-market" subgroups. The results are striking: competitive-market FL firms show a price effect of 0.126 (p < 0.01); concentrated-market FL firms show -0.018 (p > 0.3). The paper interprets this as "cover bidding is most valuable where genuine competitive threat exists."

This interpretation has three problems. First, the classification was originally designed to identify high-suspicion cover bidders (the code variables are named `has_high_susp_fl` and `has_low_susp_fl`). The reframing as "market structure" is post-hoc. Second, under the cover-bidding hypothesis, firms operating in concentrated markets with repeated winners (high HHI, repeated co-bidders) have exactly the network characteristics most consistent with organized collusion---they lose repeatedly to the same few winners, which is the classic bid-rotation pattern. The null result for these firms directly undermines H2. Third, the network classification conflates firm-level network characteristics with market-level concentration. A firm's winner HHI reflects the markets it *chooses to enter*, not the structural concentration of those markets. This is an endogenous selection problem.

**Location:** Table 9, Section 7.3, Section 6.3.

**Why it matters for RAND:** A paper claiming that FL firms are cover bidders must explain why half of them (1,356 of 2,735) show no price effect. If 49.5% of flagged firms are false positives, the welfare calculation, which uses all FL firms, is inflated. More fundamentally, the cover-bidding theory does not predict that cover bidding should be *absent* in concentrated markets---if anything, concentrated markets with fewer genuine bidders should make cover bidding more necessary (to meet minimum-bidder requirements) and more profitable (less competition to discipline prices).

**What would resolve it:** (i) Interact FL presence with continuous market-level HHI (computed at the item-group x PBU x year level, not from the network classification) to provide a direct test of the market-structure heterogeneity hypothesis. (ii) Acknowledge that the original network classification did not perform as designed. (iii) Recalculate welfare bounds using only competitive-market FL firms, since concentrated-market FL firms contribute zero price effect. (iv) Provide a theoretical reason why cover bidding should be *absent* in concentrated markets.

---

### [M5] The null DiD undermines the causal narrative

**Problem:** The Callaway & Sant'Anna estimator (Section 9.4) yields ATT = 0.014 (SE = 0.039), statistically insignificant. The paper frames this as "underpowered" and computes an MDE of 0.076, exceeding the OLS estimate of 0.064. However:

(a) The design uses within-market temporal variation---arguably the cleanest identification strategy in the paper---and produces a null result. A skeptical reader will note that this is also consistent with no causal effect: FL firms select into expensive markets, and the cross-sectional OLS captures this selection.

(b) The sample is not trivially small: 19,777 markets, 1,511 treated, 18,266 never-treated. The null is informative.

(c) The paper includes the DiD in the robustness section, which implicitly presents it as supporting evidence. A null result from the cleanest design should be discussed as a limitation, not packaged as robustness.

**Location:** Section 9.4, Table C.1, Appendix C.

**Why it matters for RAND:** RAND weighs the DiD heavily because it exploits temporal variation that the cross-sectional OLS cannot. A null DiD with an MDE close to the OLS estimate means the paper cannot rule out a zero causal effect using its best quasi-experimental design.

**What would resolve it:** (i) Move the DiD from "Robustness" to a standalone section titled "Causal Evidence: Limitations" or integrate it into the IV discussion. (ii) Discuss candidly that the null DiD is consistent with both low power and no causal effect. (iii) Consider whether an alternative panel design (e.g., within-firm or within-PBU variation) could provide more statistical power.

---

### [M6] The welfare analysis is accounting, not structural

**Problem:** The welfare bounds (Section 9.5, Table D.1) compute welfare loss as (exp(beta) - 1) x sum of FL-present tender values. The range is R\$734M (OLS) to R\$2.4B (IV), or 2.4% to 7.8% of total BEC procurement. This is a back-of-the-envelope calculation that assumes: (i) the entire FL coefficient represents cartel overcharge, (ii) there are no offsetting efficiency effects, (iii) the partial equilibrium counterfactual (remove FL, prices fall by beta) is valid. None of these assumptions are tested or defended.

For a paper claiming a 21% cartel markup (IV), RAND will expect either a structural welfare analysis that accounts for equilibrium effects (entry/exit of genuine bidders, reallocation across markets, dynamic effects on cartel stability) or an explicit statement that the welfare figures are illustrative only.

**Location:** Section 9.5, Table D.1.

**Why it matters for RAND:** A 3.3x range (R\$734M to R\$2.4B) driven entirely by OLS vs. IV coefficient choice provides limited policy guidance. The cross-fit coefficient (0.036) produces an intermediate estimate that the paper now reports, but the structural interpretation remains shallow.

**What would resolve it:** Either (i) build a simple structural model of procurement competition with cover bidding that allows counterfactual welfare computation, or (ii) dramatically compress the welfare section and frame it explicitly as "illustrative" or "back-of-the-envelope" without claiming these are welfare bounds.

---

### [M7] FL novelty relative to Conley-Decarolis (2016, AEJ:Micro)

**Problem:** Conley and Decarolis (2016) detect bidder groups from co-bidding patterns in Italian procurement, without requiring bid values. Their method identifies coordinated groups and estimates the competitive effect of group structure. The FL screen similarly identifies suspicious firms from participation data alone. The paper cites Conley-Decarolis in the literature review (Section 2) but does not provide a direct comparison of what FL does that Conley-Decarolis cannot.

The paper's claimed advantage---"FL provides a natural partition of bidders into suspected cover bidders and genuine competitors"---is precisely what Conley-Decarolis's group detection algorithm also produces, and the latter does so without requiring a threshold on a loss distribution. The paper must articulate clearly what the incremental contribution is. Operational simplicity (FL requires only participation counts, not co-bidding matrices) is a legitimate advantage but should be stated explicitly and benchmarked.

**Location:** Section 2, Section 1.

**Why it matters for RAND:** RAND scrutinizes incremental contribution relative to the existing IO literature. "New data, similar question" is not sufficient.

**What would resolve it:** Add a direct comparison paragraph: what data does FL require vs. Conley-Decarolis? What does each method detect? Can the methods be combined? Ideally, implement the Conley-Decarolis algorithm on BEC data and compare the flagged firms/tenders with FL flags.

---

### [M8] The bid dispersion test is ambiguous

**Problem:** The paper finds FL-present tenders have higher log bid standard deviation (0.47-0.55 log points), interpreted as evidence for Regime 1 (complementary cover bidding). However, Table 6 also shows FL-present tenders have more genuine (non-FL) bidders (0.19 log points). More diverse genuine competition could independently increase bid dispersion through heterogeneous valuations.

The critical question is: is the dispersion test computed on FL firms' *own bids* or on *all bids* in FL-present tenders? Section 7.5 describes a regression of log bid SD on FL presence at the tender-item level. If the dependent variable is the SD of all bids in the tender, the higher dispersion could reflect compositional effects (FL bids are high, genuine bids are competitive, so mixing them increases variance) rather than Regime 1 behavior. Only the SD of FL bids *conditional on genuine bid dispersion* would isolate the regime effect.

**Location:** Section 7.5, Table D.2.

**Why it matters for RAND:** This is the only direct test of Regime 1 vs. Regime 2. If the test cannot distinguish regime-specific cover-bid dispersion from compositional effects, the regime classification is not empirically supported.

**What would resolve it:** Decompose bid dispersion into (i) within-FL dispersion, (ii) within-non-FL dispersion, and (iii) between-group dispersion. Test whether within-FL dispersion exceeds within-non-FL dispersion controlling for the number of genuine bidders. This directly tests Regime 1.

---

## 4. MINOR COMMENTS

1. **Missing citations.** The paper does not cite Kawai, Nakabayashi, and Ortner (2022, "Detecting Collusion Through Bidding Patterns," working paper / in progress for RAND), which develops a structural approach to detecting coordinated bidding using bid-level data. It does not cite Decarolis (2014, AER), which studies entry deterrence in Italian procurement. It does not cite Decarolis and Giuffrida (2017), which examines procurement corruption in developing countries. These are close substitutes that RAND referees will know.

2. **Sample restriction.** Restriction (iii)---limiting to item types with at least one FL-present tender---is non-standard and potentially endogenous. The unrestricted-sample robustness check (coefficient 0.063 vs. 0.064) is reassuring but should be the default specification, not a robustness check.

3. **IQR threshold arbitrariness.** The median + 1.5 x IQR threshold is acknowledged as non-standard (not the Tukey rule). The economic framing in the footnote (Section 4.2) is an improvement but remains assertion. The threshold sensitivity exercise (Section 9.1) shows coefficients increasing monotonically with stricter thresholds, which is evidence for the screen's validity but also suggests the specific threshold is not "optimal" in any formal sense.

4. **Cross-fitting attenuation.** The cross-fit coefficient (0.036) is 44% smaller than the full-sample OLS (0.064). One fold is significant (0.053), the other is not (0.019). The paper attributes this to power differences between odd and even years, but does not rule out in-sample overfitting of the FL definition. This should be discussed more carefully.

5. **Abstract and introduction overstate CADE validation.** The abstract and introduction lead with "3.5 times the rate expected by chance" without immediately noting that the unconditional odds ratio is only 1.21. The permutation test adjusts for participation intensity, which is appropriate, but the raw OR should be stated prominently for transparency.

6. **Table formatting.** Several appendix tables use inconsistent formatting (some with adjustbox, some without; some with threeparttable notes, some with captions only). Standardize across all tables.

7. **Convite coefficient interpretation.** The convite coefficient (3.8%) is lower than pregao (9.3%), which is counterintuitive if convite's minimum-bidder requirement creates the strongest incentive for cover bidding. The paper's explanation (Section 8.4) invokes multiple offsetting channels (less scope for calibration + compositional effect of minimum-bidder rule). This is plausible but hand-waving. A formal decomposition would strengthen the argument.

8. **Temporal FL definition.** The temporal FL (3-year rolling window) produces a coefficient of 0.070, *larger* than the full-sample 0.064. This is unexpected---shorter windows should introduce noise and attenuate. The paper does not explain this.

9. **Notation inconsistency.** Equation 1 uses alpha_g, lambda_t, gamma_k for item, year, and PBU FE, but g is described as "item group" in some places and "item type" in others. Clarify whether g indexes groups (first two digits) or individual items (full code).

10. **BEC representativeness.** The paper analyzes only Sao Paulo's BEC platform. How representative is BEC of Brazilian procurement? BEC is electronic and relatively transparent; the FL screen's performance may differ in less transparent states. A brief discussion of external validity is warranted.

---

## 5. IDENTIFICATION DEEP-DIVE

### 5.1 OLS Interpretation

The OLS baseline (Table 5) is the paper's strongest result. The coefficient of 0.064 with item + year + PBU FE represents a conditional correlation: within the same item type, year, and purchasing unit, tenders with FL presence have 6.4% higher negotiated prices. The inclusion of 18,783 item FE, 11 year FE, and 1,308 PBU FE absorbs substantial heterogeneity. The FE-residualized gap of 0.050 log points (now reported in the introduction) shows the conditional comparison is economically meaningful.

The OLS cannot be interpreted causally because FL presence is endogenous: cartels choose where to deploy cover bidders, and this choice may be correlated with unobserved tender characteristics (e.g., procurement complexity, product specificity, enforcement intensity). The paper is honest about this limitation. For H1 (FL as screening marker), a conditional correlation with appropriate sensitivity analysis is sufficient.

The sensitivity analysis (Cinelli-Hazlett, RV = 17.5%) is useful: an unobserved confounder would need to explain 17.5% of residual variation in both FL presence and log prices to reduce the coefficient to zero. This is a high bar given the rich FE structure. However, the Cinelli-Hazlett framework assumes linear confounding and does not account for potentially non-linear selection mechanisms.

### 5.2 Leave-One-Out IV

The LOO instrument (Equation 3) is a supply-side shift instrument in the spirit of Goldsmith-Pinkham et al. (2020). The identifying assumption is that FL activity at other PBUs in the same product-group x year cell affects focal-PBU prices only through the probability of FL participation at the focal PBU.

**Instrument relevance:** The first-stage F-statistic of 396 (Panel A) indicates strong relevance. However, the partial R-squared is extremely low (0.0002), meaning the instrument explains essentially zero variation in FL presence after absorbing fixed effects. This raises the concern that the F-statistic is inflated by the massive sample size rather than reflecting genuine predictive power.

**Exclusion restriction:** Three threats are discussed in Section 6.2:

1. *Correlated demand shocks:* If the same product-group experiences price shocks statewide, FL supply at other PBUs correlates with prices at the focal PBU. Item + year + PBU FE mitigate this, but the instrument varies within item-group x PBU x year cells, so within-cell geographic shocks could still violate exclusion.

2. *Statewide cartel organization:* If cartels coordinate FL deployment across PBUs simultaneously, the LOO instrument captures coordinated entry rather than independent supply variation. The balance tests (Table B.8) are the diagnostic here, and they fail: all four observables are significantly predicted by the instrument.

3. *Enforcement variation:* If enforcement intensity varies across PBUs and correlates with both FL supply and prices, the instrument is invalid. PBU FE absorb time-invariant enforcement differences but not time-varying enforcement changes.

**Specification sensitivity:** The Panel A estimate (0.194) rises to 3.64 in Panel C (item-group x year FE). The paper correctly identifies this as weak-instrument amplification, but the magnitude sensitivity (19x increase from Panel A to Panel C) is extreme and suggests the IV estimate is fragile.

**LATE interpretation:** The compressed LATE paragraph (Section 7.2) now states the IV identifies a LATE for complier tenders. This is appropriate, but the paper should note that the complier population---tenders whose FL status is shifted by supply-side availability at other PBUs---may not be representative of all FL-present tenders.

### 5.3 Bajari-Ye Implementation

The paper implements the Bajari and Ye (2003) tests for exchangeability and conditional independence. The first stage regresses log bid values on firm size, firm age, CNAE sector dummies, number of bids, and item and year fixed effects.

**Critical concern:** The inclusion of *number of bids* in the first-stage bid equation is problematic. The number of bids in a tender is an equilibrium outcome jointly determined with bid levels. FL presence mechanically increases the number of bids (the paper shows this in Table 6). If n_bids is included as a regressor, the first-stage residuals capture (in part) the prediction error from an endogenous variable, which mechanically correlates with FL status. Bajari and Ye (2003, p. 978) specify that first-stage regressors should be "cost variables"---factors that shift bidders' costs, not equilibrium market outcomes. Firm size and CNAE sector are legitimate cost shifters; number of bids is not.

To assess whether this drives the exchangeability violation, the paper should re-estimate the first stage excluding n_bids and re-compute the KS statistic and pairwise products.

### 5.4 Callaway-Sant'Anna DiD

The staggered DiD uses market-level panels (item x PBU x year) with treatment defined as first FL entry. The C&S ATT of 0.014 (SE = 0.039) is null. The paper's power analysis (MDE = 0.076) is correct: the design cannot detect effects of the magnitude estimated by OLS (0.064) at the 5% level.

The key question is whether the "treatment"---first FL entry into a market---is plausibly exogenous. If cartels form and then deploy FL firms into markets they intend to rig, the treatment timing is endogenous to cartel formation, which precedes FL entry. The DiD design would then suffer from the same endogeneity as the cross-sectional OLS. The paper does not discuss the exogeneity of treatment timing.

---

## 6. THEORY EVALUATION

### 6.1 Framework Assessment

Section 3 presents a cartel profit maximization problem (Equation 1) and two cover-bidding regimes. The FOC asserts that the optimal number of cover bidders m* is increasing in n (genuine competitors) and decreasing in theta (detection probability). These comparative statics are stated without derivation.

The two regimes are defined by distributional assumptions:
- Regime 1: cover bids ~ U[b_bar, b_bar + delta], b_bar > b*
- Regime 2: cover bids ~ N(mu_c, sigma_c^2), mu_c close to b*, sigma_c < sigma_genuine

These are not equilibrium outcomes---they are assumed bid distributions. A proper model would derive the cover-bid distribution as a best response given the cartel's information structure and the genuine bidders' strategies. For example, under Regime 1, why do cover bidders submit bids from a uniform distribution? Is this optimal given a procurement scoring rule? Under Regime 2, why is sigma_c < sigma_genuine? Is this a result of information sharing within the cartel?

### 6.2 Untested Predictions

Prediction 3 (Regime identification) is tested only visually (Figure 7). There is no formal variance-ratio test comparing FL and non-FL bid dispersions, no likelihood ratio test between the two regime specifications, and no model selection criterion. A visual comparison of density plots does not meet RAND's evidentiary standard.

### 6.3 Missing Theoretical Prediction

The network-split result---that the price effect concentrates in competitive markets---is one of the paper's most interesting findings, but it lacks theoretical grounding. The conceptual framework predicts that cover bidding is more profitable when detection probability theta is low (Section 3.4), which the paper associates with small PBUs. But it does not predict that cover bidding should be absent in concentrated markets. In fact, concentrated markets with few genuine bidders are precisely where minimum-bidder requirements (convite) create the strongest incentive for cover bidding. The paper needs a theoretical explanation for why concentrated-market FL firms show zero price effect.

---

## 7. LITERATURE POSITIONING

### 7.1 Conley-Decarolis (2016, AEJ:Micro)

This is the closest antecedent. Conley and Decarolis detect bidder groups from co-bidding patterns in Italian procurement without requiring bid values. The FL screen is operationally simpler (participation counts vs. co-bidding matrices) but less general (it identifies a specific firm type rather than detecting arbitrary group structures). The paper should provide a direct feature-by-feature comparison and ideally implement Conley-Decarolis on BEC data.

### 7.2 Chassang-Ortner (2022, Econometrica)

Chassang and Ortner develop *robust screens* for non-competitive bidding that are valid under minimal assumptions. The FL screen is not robust in the Chassang-Ortner sense---it relies on a specific threshold and distributional assumption. The paper should discuss where FL sits relative to robust screening methods.

### 7.3 Missing Citations

The paper should cite:
- Kawai, Nakabayashi, and Ortner (working paper): structural detection of coordinated bidding
- Decarolis (2014, AER): entry deterrence in Italian procurement
- Decarolis and Giuffrida (2017): procurement corruption in developing countries
- Kawai and Nakabayashi (2014): detecting collusion through close bids

### 7.4 Developing-Country Contribution

The paper argues that the FL screen is valuable for developing countries where bid-level data are unavailable. This is a genuine practical contribution but is not an IO contribution. RAND distinguishes between policy relevance and intellectual novelty. The developing-country context provides a useful laboratory (large sample, institutional variation between convite and pregao, minimum-bidder rules) but does not by itself advance the IO frontier.

---

## 8. CONCLUSION AND CONDITIONS

This paper presents a genuinely useful cartel screening tool (FL) with strong descriptive evidence for its empirical validity (H1). The OLS evidence---6.4% higher prices in FL-present tenders after absorbing item, year, and PBU fixed effects, with a robustness value of 17.5% and external validation against CADE convictions---is compelling for a screening-marker paper. However, the paper's causal claims (H2) rest on an IV that fails balance, Bajari-Ye tests with internal inconsistencies, and a null DiD. RAND requires either clean causal identification or a structural contribution, and this paper currently provides neither.

I recommend **Reject with invitation to resubmit** with three conditions:

1. **Resolve the identification problem.** Either find clean exogenous variation in FL exposure (institutional change, geographic discontinuity, policy shock) or drop the causal claim entirely and reframe as a detection methodology paper with the OLS evidence as the empirical backbone.

2. **Fix the Bajari-Ye implementation.** Remove number of bids from the first-stage bid equation (it is an equilibrium outcome, not a cost shifter). Re-estimate exchangeability and conditional-independence tests. Separately test the fake-groups placebo within FL-present and FL-absent tenders.

3. **Provide a theoretical account of the network-split result.** Explain why concentrated-market FL firms show zero price effect despite having the network characteristics most consistent with organized collusion. This is either a fundamental challenge to H2 or an important insight about cover-bidding equilibria---but it cannot be left unexplained.

Is RAND the right journal? If the authors can deliver on condition (1)---finding clean exogenous variation or developing a structural model---then yes. If the paper remains an applied screening paper with OLS evidence and suggestive causal tests, it is better suited to the International Journal of Industrial Organization or the Journal of Law, Economics, & Organization, where the policy contribution and CADE validation would be more valued. The honest assessment is that RAND requires either a clean quasi-experiment or a structural model; the current paper has neither.

---

*Word count: approximately 4,200 words.*
