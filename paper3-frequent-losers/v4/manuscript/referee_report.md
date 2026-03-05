# Referee Report

**Paper:** "Frequent Losers as Cover Bidders in Public Procurement"
**Authors:** Genicolo-Martins & Furquim de Azevedo (INSPER)
**Date:** March 2026

---

## 1. Summary

This paper proposes "frequent losers" (FL)—firms that never win yet participate in an abnormally large number of public procurement tenders—as a screening marker for cover bidding. Using 4.5 million tender-items from São Paulo's BEC platform (2009–2019), the authors identify 2,735 FL firms via an IQR-based threshold on the participation distribution of always-losers. The paper advances two hypotheses: (H1) FL presence is a useful screening marker correlating with price anomalies and cartel overlap, and (H2) FL firms are themselves cover bidders causing price inflation.

The empirical strategy combines OLS (4–9% price markup), a leave-one-out instrumental variable (21% markup, F = 396), external validation against CADE cartel convictions (3.5x co-participation rate), Bajari-Ye tests for bid coordination, network-based heterogeneity analysis, and an extensive battery of robustness checks. Estimated welfare losses range from R$734 million (OLS) to R$2.4 billion (IV).

---

## 2. Overall Assessment

This is a well-executed empirical paper that makes a genuinely novel contribution to the cartel screening literature. The core idea—that persistent losers with anomalously high participation are likely shill bidders—is simple, intuitive, and practically useful. The two-hypothesis framing (screening marker vs. causal mechanism) is sophisticated and honest: the authors are forthright about what the evidence can and cannot establish.

**Key strengths:**
- A novel, firm-level screening approach requiring only participation data (not bid values)—a genuine advantage in developing-country settings where bid-level data are scarce
- Massive dataset (4.5M tender-items, 40M bids) providing statistical power rarely seen in the bid-rigging literature
- Multi-method triangulation: OLS, IV, Bajari-Ye, network analysis, matching, DiD, sensitivity analysis, and external validation against actual cartel convictions
- Exemplary robustness: threshold sensitivity, cross-fitting, temporal definitions, matching estimators, clustering alternatives, and the Cinelli-Hazlett sensitivity framework
- Honest treatment of limitations: the DiD null result is correctly interpreted as underpowered rather than contradictory; the IV magnitude caveat regarding LATE vs. ATE is appropriately flagged

**Key weaknesses:**
- The IV exclusion restriction, while discussed, remains the paper's Achilles' heel
- The network-split results, while interesting, generate a counterintuitive labeling problem (the "low-suspicion" group drives the effect)
- The Bajari-Ye tender FE results (FL < non-FL pairwise product) weaken the conditional independence claim
- The welfare analysis is mechanical and lacks structural foundations

**Verdict:** The paper is publishable in a good field journal. The H1 case is decisive; the H2 case is suggestive but not conclusive. The paper's practical contribution—an operationally simple cartel screen—is its strongest selling point.

---

## 3. Major Comments

### 3.1. IV Exclusion Restriction (Critical)

The leave-one-out instrument (FL supply at other PBUs in the same product-market-year) is the paper's most powerful tool but also its most vulnerable assumption. The authors discuss three threats (correlated demand shocks, statewide cartel organization, enforcement variation) and argue that item + year + PBU FE mitigate them. This is reasonable but not fully convincing for two reasons:

**(a) Geographic correlation in cartel activity.** If a cartel deploys FL firms across multiple PBUs simultaneously, the LOO instrument captures coordinated entry rather than independent supply variation. The balance tests show statistically significant (though standardized-small) imbalance, which is consistent with this concern. The item-group × year FE specification (Panel C) could address this, but the resulting estimate (3.64) is implausibly large—the authors correctly diagnose weak-instrument amplification, but this means the robustness test is uninformative.

**(b) Common cost shocks.** If input costs for certain product categories spike statewide, this could simultaneously increase prices and attract FL firms (who may be marginal firms seeking contracts during high-price periods). The PBU FE absorbs cross-sectional level differences but not within-PBU time-varying cost shocks correlated across PBUs.

**Suggestion:** Consider a "peer PBU" instrument limited to geographically distant PBUs (different municipalities or regions). If the estimate is similar, geographic cartel coordination is less concerning. Alternatively, show that the first-stage relationship holds within narrow geographic bands.

### 3.2. Network Split Interpretation (Major)

The network-split results are the paper's most creative contribution but suffer from a counterintuitive labeling problem. FL firms in *competitive* markets (low winner HHI = "low suspicion") drive the entire price effect, while those in *concentrated* markets (high winner HHI = "high suspicion") show no effect. The economic interpretation—cover bidding is most profitable where genuine competition exists—is correct. But the labels "high-suspicion" and "low-suspicion" are misleading: from a detection standpoint, the FL firms *with the price effect* are the ones that should be flagged, regardless of the market structure label.

More substantively, this finding raises an identification concern. In competitive markets, there is more scope for price variation in general. The FL coefficient in competitive markets could reflect unobserved heterogeneity in competitive conditions rather than cover bidding per se. The continuous HHI interaction (–0.024, SE = 0.067) is too imprecise to confirm the discrete split.

**Suggestion:** (i) Rename the subgroups (e.g., "concentrated-market FL" vs. "competitive-market FL") to avoid confusion. (ii) Run the IV separately for each subgroup—if the low-concentration FL firms still show a strong IV effect with a strong first stage, the case is strengthened considerably. (iii) Show that the interaction is robust to alternative concentration measures (e.g., C4 ratio, number of distinct winners).

### 3.3. Bajari-Ye Tender FE Reversal (Major)

The Bajari-Ye results with tender fixed effects (Table A.12) present an uncomfortable finding: the FL pairwise product (0.38) is *smaller* than the non-FL product (0.86) after absorbing all tender-level shocks. The authors interpret this as genuine bidders sharing cost information while cover bidders lack such shared signals. This is plausible but undermines the paper's claim that FL residuals exhibit "significantly stronger within-tender correlation than non-FL residuals"—this holds only for the baseline specification, not after tender FE.

The relevant finding—that FL residual correlation remains significantly positive (0.38, p < 0.001) after tender FE—is still informative: it means FL bids co-move beyond what common tender-level factors can explain. But the paper should not lead with the conditional independence comparison (FL > non-FL) in the abstract and conclusion, since this comparison reverses under the more demanding specification.

**Suggestion:** Restructure the Bajari-Ye discussion to foreground the KS exchangeability test (which is unambiguous) and present the pairwise products with appropriate caveats. The tender-FE reversal should be discussed in the main text (not just the appendix) since it materially qualifies the CI claim.

### 3.4. DiD as Evidence (Major)

The staggered DiD yields a null result (ATT = 0.014, SE = 0.039) that the authors correctly interpret as underpowered. The MDE (0.076) exceeds the OLS estimate (0.064), confirming insufficient power. However, the paper could better leverage the DiD:

**(a)** The pre-trend coefficient (–0.013) and post coefficient (–0.008) from the TWFE are both small and negative, offering no directional support for the FL hypothesis in a causal framework. This deserves more discussion.

**(b)** The "sharp entry" subsample yields the same ATT (0.014, SE = 0.039)—meaning the cleaner treatment timing does not sharpen the estimate. This null-within-null should be acknowledged.

**(c)** Panel C (Rambachan-Roth bounds) is referenced but the actual Mbar values are absent from the table. This panel should be populated or the reference removed.

**Suggestion:** Either present the DiD as genuinely uninformative (move to online appendix) or invest in a more powerful panel design (e.g., longer pre-periods, more granular market definitions to increase treatment variation).

### 3.5. FL Definition Endogeneity (Major)

The FL definition uses the full 2009–2019 period to classify firms, then estimates regressions over the same period. This look-ahead creates a mechanical concern: a firm classified as FL based on its *lifetime* participation pattern is labeled FL in early years when it may have been a genuine competitor. The cross-fitting exercise partially addresses this (coefficient drops from 0.064 to 0.036), suggesting that roughly half the OLS effect comes from this temporal contamination.

The temporal FL definition (rolling 3-year windows, coefficient = 0.070) is more convincing but uses a smaller sample (N = 1,256,998). Given its importance, this should be the *primary* specification, with the full-period definition as robustness. The paper currently treats the more problematic definition as the baseline.

**Suggestion:** Consider making the temporal FL definition the primary specification and discussing the full-period definition as a robustness check that yields similar results.

---

## 4. Minor Comments

### 4.1. Writing and Presentation

- The paper is well-written and clearly structured. The two-hypothesis framework (H1/H2) with five testable predictions is pedagogically effective.
- At 55 pages (including appendix), the paper is somewhat long. Consider trimming the conceptual framework section, which sets up a formal model but then tests mostly reduced-form predictions that don't require the model.
- The `% CO-AUTHOR EDIT` comments should be removed before submission.

### 4.2. Literature

- The literature review is adequate but could engage more with the recent machine-learning screening literature (post-2020): there have been several papers applying random forests and neural networks to bid-rigging detection that are not cited.
- The comparison with Conley & Decarolis (2016) could be sharper: they detect *groups* from co-bidding patterns; this paper detects *individual* cover bidders from participation patterns—a distinct contribution.
- Missing citations: Kawai & Nakabayashi (2022, published version if available); Chassang & Ortner (2019) on collusion-proof mechanisms; Tóth et al. (2022) on network-based cartel detection in European procurement.

### 4.3. Data

- The sample is limited to São Paulo state (BEC). The authors acknowledge this in the conclusion but could discuss more explicitly why the FL pattern might or might not generalize to federal procurement (ComprasNet) or other states.
- The 2019 data is sparse (38,833 tender-items vs. 370,000+ in earlier years). The authors should verify that results are robust to excluding 2019.
- The descriptive statistics (Table 3) show that FL-present tenders have dramatically higher mean prices (R$140,673 vs. R$12,465) and this 11x difference is not explained by the 4–9% regression coefficient. This likely reflects composition effects (FL firms tend to participate in tenders for more expensive items), but deserves explicit discussion.

### 4.4. Econometric Details

- **Clustering:** The item-level clustering is justified but somewhat unusual. Most procurement papers cluster at the market or PBU level. The robustness to alternative clustering is reassuring, but the choice should be motivated more explicitly (why not PBU × item group?).
- **R-squared:** The note in the CLAUDE.md mentions using "overall R² to approximate Stata areg." This is fine but should be stated in the paper since within-R² would be much lower.
- **Convite dummy:** The convite indicator appears as a regressor in specifications that include both modalities. Since the pregao-only and convite-only specifications absorb modality, the general specification effectively controls for a level shift. But the convite indicator also changes sign between columns 1 and 2 (–0.009 to +0.010). This instability deserves a footnote.

### 4.5. Welfare Analysis

- The welfare computation assumes the entire price premium in FL-present tenders is attributable to cover bidding. Under H1 (screening marker only), some FL-present tenders may have higher prices for non-collusive reasons. The welfare numbers should be clearly labeled as "consistent with" the cover bidding interpretation.
- The high-suspicion FL column in the welfare table shows a *negative* welfare effect (–R$88M), which is inconsistent with the cover bidding narrative. This should be addressed or the column removed.
- Inflation adjustment: R$734M over 2009–2019 should be expressed in constant reais (or at minimum, indicate whether these are nominal or real).

### 4.6. Specific Numerical Issues

- **Threshold robustness (Table A.2):** The text says the coefficient "increases monotonically" with the multiplier, but the table shows it *decreasing* from 0.079 (1.0×) to 0.050 (3.0×). This is consistent with stricter thresholds selecting fewer but more extreme FL firms, but the monotonicity claim is about *coefficient magnitude*, not about the screen's *informativeness*. Clarify the direction.
- **Low-win-rate variant (<2%):** This variant produces a coefficient of 0.018 (insignificant). Describing this as "coefficients are stable across definitions" is generous. The <2% variant substantially dilutes the screen, which is itself informative—but should be discussed honestly.
- **Cross-fit asymmetry:** The odd-year fold (0.053, significant) and even-year fold (0.019, insignificant) show substantial asymmetry. This may reflect different FL firm composition across periods. Report the number of overlapping FL firms between folds.
- **Panel C (Rambachan-Roth):** Referenced in the DiD section text but not populated in the table. Either add the Mbar-specific confidence intervals or remove the panel reference.
- **Homogeneous subsample (Table A.5 vs. A.6):** The `tab_homogeneous_subsample.tex` file still contains the old "infeasible" stub, while `tab_homogeneous_cv.tex` has the actual CV-based results. The stub table is still included in the appendix but appears unreferenced. Remove it.

---

## 5. Questions for the Authors

1. What fraction of FL firms participate in both convite and pregão tenders? If most FL firms specialize in one modality, the pooled regression may obscure important heterogeneity.

2. Are there FL firms that are related entities (same ownership, shared directors, shared address) to frequent winners? This would provide direct evidence of the cover bidding mechanism beyond statistical association.

3. The IV first-stage partial R² is extremely low (0.0002–0.0006). While the F-statistic is large due to the massive sample size, the instrument explains essentially none of the variation in FL presence. How should we interpret a strong first stage that is statistically but not substantively predictive?

4. Have you considered a triple-differences design exploiting the 2006 pregão reform (Lei 10.520/2002 implementation timeline across PBUs) as a shock to cover bidding incentives?

5. The bid-level data (40M rows) are used only for the Bajari-Ye tests. Have you considered using bid values more intensively—e.g., analyzing the distribution of FL bid-to-winning-bid ratios conditional on tender characteristics?

---

## 6. Verdict

**Recommendation: Revise and Resubmit (minor to moderate revisions)**

The paper makes a novel and practically relevant contribution to the cartel screening literature. The H1 case (FL as screening marker) is convincingly established through the combination of OLS, CADE validation, and extensive robustness. The H2 case (FL as cover bidders) rests primarily on the IV strategy, which is well-executed but not bulletproof. The honest acknowledgment of limitations (DiD null, Bajari-Ye tender FE reversal, LATE caveat) reflects a mature empirical approach.

The required revisions are: (1) address the network-split labeling and interpretation; (2) discuss the Bajari-Ye tender FE reversal more prominently; (3) consider making the temporal FL definition the primary specification; (4) clean up the DiD presentation (populate Panel C or remove); (5) remove the "infeasible" homogeneous subsample stub; (6) clarify the threshold sensitivity direction claim.

---

## 7. Journal Targeting

### Tier 1 — High probability of desk acceptance, competitive R&R

| Journal | Fit | Rationale |
|---------|-----|-----------|
| **Journal of Industrial Economics** | ★★★★★ | Core audience: bid rigging, procurement, cartel detection. Recent papers on screening (Imhof et al., Chassang). Empirical focus with policy relevance. The FL screen is exactly the kind of practical contribution JIE values. |
| **International Journal of Industrial Organization** | ★★★★★ | Regularly publishes procurement and bid-rigging empirics. The CADE validation and developing-country context add novelty. The paper's length (55 pp) is acceptable. |
| **Journal of the European Economic Association** | ★★★★ | Policy-relevant empirics with a novel identification idea. The IV strategy and CADE validation are the hooks. Competitive but feasible. |

### Tier 2 — Good fit, somewhat more competitive

| Journal | Fit | Rationale |
|---------|-----|-----------|
| **Journal of Political Economy** | ★★★ | Would require the H2 case to be more conclusive (the DiD null and Bajari-Ye reversal hurt). But the scale of data and practical novelty could attract interest. High bar. |
| **American Economic Journal: Economic Policy** | ★★★★ | Strong policy angle (procurement screening in developing countries). The welfare analysis and operational recommendations fit the journal's mandate. |
| **Review of Economics and Statistics** | ★★★ | Methodological rigor is there, but the paper is more applied than REStat typically prefers. The IV + network analysis combination might appeal. |
| **RAND Journal of Economics** | ★★★★ | IO and auction theory audience. The Bajari-Ye application and regime test connect to RAND's core readership. |

### Tier 3 — Excellent fit, high acceptance probability

| Journal | Fit | Rationale |
|---------|-----|-----------|
| **Journal of Law, Economics, and Organization** | ★★★★★ | Antitrust enforcement, cartel detection, institutional analysis (BEC, convite vs. pregão). Natural home for the paper. |
| **Journal of Competition Law & Economics** | ★★★★★ | Dedicated to competition policy. The CADE validation and practical screening tool are ideal for this audience. |
| **European Economic Review** | ★★★★ | Broad economics audience, accepts strong empirical work. The developing-country procurement angle differentiates from the European-focused bid-rigging literature. |
| **Journal of Public Economics** | ★★★★ | Procurement is a public economics topic. The welfare analysis and policy implications align well. |

### Recommended Strategy

1. **First submission:** *Journal of the European Economic Association* or *AEJ: Economic Policy* — these maximize visibility and are within reach given the paper's quality.
2. **If rejected at Tier 1-2:** *Journal of Industrial Economics* or *IJIO* — near-certain R&R given the paper's contribution and the journals' scope.
3. **Backup:** *JLEO* or *Journal of Public Economics* — excellent topical fit with high acceptance probability.

The paper's practical contribution (a simple, operational screening tool for developing-country procurement) is its strongest differentiator from the existing literature. The recommended target should emphasize this practical angle over the theoretical contributions.

---

## Appendix: Checklist Summary

| Aspect | Assessment |
|--------|-----------|
| Novelty | **High** — firm-level screening from participation data is new |
| Data quality | **Excellent** — 4.5M obs, 40M bids, 11 years, two modalities |
| Identification | **Good** — IV plausible but not ironclad; multi-method triangulation compensates |
| Robustness | **Exemplary** — 15+ robustness checks spanning definition, sample, specification, estimation |
| External validity | **Moderate** — CADE validation is strong but limited to one state/platform |
| Writing | **Very good** — clear, well-structured, honest about limitations |
| Policy relevance | **High** — operational screening tool with clear implementation path |
| Welfare analysis | **Adequate** — mechanical but bounded; LATE caveat well-handled |
| Literature engagement | **Adequate** — could cite more recent ML screening papers |
| Replicability | **High** — pipeline-based R code, fixed effects clearly documented |
