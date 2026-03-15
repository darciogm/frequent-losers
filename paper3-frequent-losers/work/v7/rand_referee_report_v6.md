# Referee Report --- RAND Journal of Economics

**Paper:** Frequent Losers as Cover Bidders in Public Procurement (v6)
**Authors:** Genicolo-Martins & Furquim de Azevedo
**Referee expertise:** Cartels, bid rigging, procurement auctions, antitrust screening
**Recommendation:** Major Revision
**Date:** 2026-03-15

---

## 1. SUMMARY

This paper proposes "frequent losers" (FL)---firms that never win yet participate in an abnormally large number of public procurement tenders---as a screening marker for cover bidding. Version 6 represents a substantial reframe toward RAND standards, adding a structural model of cover-bidder deployment (new Section 3), a formal detection validation with ROC analysis (AUC = 0.94), and a reorganized empirical strategy that elevates structural estimation and detection performance as the primary contributions while demoting the leave-one-out IV to a bracketing device. Using 4.5 million tender-items and 40 million bids from São Paulo's BEC platform (2009--2019), the authors identify 2,735 FL firms via an IQR-based threshold. FL-present tenders exhibit 6.4% higher negotiated prices (OLS with item, year, and PBU fixed effects). The structural model derives equilibrium cover-bid distributions under two regimes, predicts that cover bidding concentrates in competitive markets, and provides a likelihood framework for separating cover bids from genuine bids. Bajari--Ye tests (with corrected first stage excluding the endogenous n_bids variable) reject exchangeability and conditional independence for FL bid residuals. External validation against CADE cartel convictions yields a 3.5x participation-adjusted co-bidding rate and an AUC of 0.94 for the FL detection screen.

---

## 2. OVERALL ASSESSMENT

The v6 reframe is a genuine improvement over the prior version. The authors have addressed the most critical weakness---the absence of theoretical grounding---by developing a structural model that derives the market-selection prediction (cover bidding concentrates in competitive markets) endogenously rather than as a post-hoc rationalization. The ROC analysis with AUC = 0.94 is a strong empirical result that positions the FL screen as a demonstrably effective detection tool validated against actual enforcement outcomes. The corrected Bajari--Ye implementation (excluding n_bids from the first stage) and the honest reframing of the IV as a bracketing device rather than the primary identification strategy are both welcome.

However, significant gaps remain between the paper's ambitions and its execution. The structural model in Section 3 is well-motivated but incompletely estimated: the paper describes a mixture likelihood and two-stage MLE procedure (Section 5.1) but the Results section (Section 7) presents only the v4 reduced-form OLS and IV estimates, not the structural parameter estimates. The structural model exists as theory and methodology but not as estimated output. The paper effectively has three distinct identities---structural IO paper (Sections 3, 5.1), reduced-form screening paper (Sections 5.2--5.4, 7--9), and detection methodology paper (Section 5.3)---and does not fully integrate them. A RAND paper must deliver on its structural promises.

My recommendation is **Major Revision** with a clear path to acceptance conditional on completing the structural estimation and integrating the results throughout the manuscript.

---

## 3. MAJOR COMMENTS

### [M1] The structural model is not estimated

**Problem:** Section 3 develops a structural model with four propositions (optimal m*, Regime 1 and 2 cover-bid distributions, market-selection prediction). Section 5.1 describes a two-stage MLE procedure: Stage 1 estimates the genuine bid distribution from 37.5M non-FL bids; Stage 2 estimates the cover-bid parameters conditional on the winning bid. BIC model selection determines the empirically dominant regime. Bootstrap standard errors are described (500 replications, 16 cores).

However, the Results section (Section 7) does not report any structural parameter estimates. There is no table of $(\hat{\boldsymbol{\beta}}, \hat{\sigma}_g^2, \hat{\delta}, \hat{\sigma}_c, \hat{\theta})$, no BIC comparison between Regime 1 and Regime 2, no structural markup calculation, no log-likelihood values, and no bootstrap standard errors. The one structural data point reported in the manuscript is the tender-level bid CV ratio (FL: 0.56 vs. non-FL: 0.37, ratio = 1.52, in Section 4.4), which is a descriptive statistic, not a structural estimate from the likelihood. The [ESTIMATE] placeholder in Section 5.1 (bootstrap completion time) further confirms the estimation has not been run.

**Location:** Section 3 (model), Section 5.1 (estimation procedure), Section 7 (results---absent).

**Why it matters for RAND:** RAND publishes structural papers when the structural model is estimated, not when it is merely specified. The current paper makes a structural promise in Sections 3 and 5.1 but delivers only reduced-form results in Section 7. This is the single most important gap.

**What would resolve it:** Estimate the mixture model. Report a table with:

| Parameter | Estimate | Bootstrap SE | 95% CI |
|-----------|----------|-------------|--------|
| $\hat{\sigma}_g$ (genuine bid SD) | ... | ... | ... |
| $\hat{\delta}$ (Regime 1 spread) | ... | ... | ... |
| $\hat{\sigma}_c$ (Regime 2 SD) | ... | ... | ... |
| BIC (Regime 1) | ... | | |
| BIC (Regime 2) | ... | | |
| KS distance (Regime 1) | ... | | |
| KS distance (Regime 2) | ... | | |
| Implied markup (%) | ... | ... | ... |

Then verify that (a) the implied structural markup falls within the OLS--IV range (6.4%--21%), (b) BIC selects Regime 1 (consistent with the CV ratio > 1), and (c) the KS goodness-of-fit is acceptable. Without this table, the structural model is an unverified theory section.

---

### [M2] The Results section is disconnected from the new empirical strategy

**Problem:** The Results section (Section 7) presents OLS (Section 7.1), IV (Section 7.2), network split (Section 7.3), Bajari--Ye (Section 7.4), and regime test (Section 7.5). This ordering follows the v4 empirical strategy (OLS → IV → network → Bajari--Ye), not the v6 strategy (structural estimation → reduced-form → detection validation → Bajari--Ye). There is no Section 7.X presenting the structural estimation results, no section reporting the ROC analysis results (AUC = 0.94, optimal threshold = 1.45x), and no section connecting the structural parameter estimates to the theoretical predictions in Section 3.

**Location:** Section 7 (entire section).

**Why it matters for RAND:** The disconnect between the empirical strategy (Section 5) and the results (Section 7) suggests the reframe was applied to the front matter and methodology but not carried through to the results presentation. RAND expects the results to follow the strategy section's ordering and to directly test the theoretical predictions.

**What would resolve it:** Restructure Section 7 as:
- 7.1 Structural Estimation Results (new: parameter table, regime selection, implied markup)
- 7.2 Reduced-Form Evidence (existing OLS + reframed IV)
- 7.3 Detection Performance (new: ROC figure, AUC table, optimal threshold)
- 7.4 Network-Split Heterogeneity (existing, now motivated by Proposition 4)
- 7.5 Bajari--Ye Tests (existing, corrected)
- 7.6 Regime Test (existing, now benchmarked against structural BIC)

Each subsection should open with the relevant prediction from Section 3 and state whether the result confirms or disconfirms it.

---

### [M3] The structural proofs are heuristic, not formal

**Problem:** The three proofs in Section 3 are economic arguments rather than formal mathematical proofs.

- Proposition 1 (optimal m*): The proof states the FOC and applies the implicit function theorem, but the profit function $\pi(b^*, m, n)$ is not specified beyond "cartel surplus." Without a functional form for $\pi$, the comparative statics ($\partial m^*/\partial n > 0$, $\partial m^*/\partial \theta < 0$) are assertions about the sign of derivatives of an unspecified function. The condition $\partial^2 \pi / \partial m^2 < 0$ (decreasing marginal returns) is assumed, not derived.

- Proposition 2 (Regime 1): The proof claims the uniform distribution "maximizes entropy over the feasible support, minimizing statistical distinguishability." This is correct if the detection algorithm is an entropy-based screen, but is not generally true. A cartel minimizing detection probability against a variance screen (e.g., Imhof et al. 2018) would choose a *different* distribution than uniform.

- Proposition 4 (market selection): The cross-derivative $\partial^2 \pi / \partial m \partial \text{HHI} < 0$ is asserted, and the sign is economically intuitive, but the argument relies on the claim that "in concentrated markets, the cartel can sustain high prices through tacit coordination or market power without needing cover bidders." This is a statement about the outside option of the cartel, not a derived comparative static.

**Location:** Section 3.2, 3.3, 3.4.

**Why it matters for RAND:** RAND structural papers typically derive propositions from primitives (payoff functions, information structure, equilibrium concept). The current proofs are closer to the standard in empirical IO survey papers (e.g., Handbook chapters) than to RAND's proof standard. This is acceptable if the paper labels Section 3 as a "framework" rather than a "model," but the current title ("A Structural Model") sets expectations for formal derivations.

**What would resolve it:** Either (a) specify $\pi(b^*, m, n)$ explicitly (e.g., as a function of the winning bid's rank among genuine bids and the number of cover bidders) and derive the propositions formally, or (b) rename Section 3 to "Framework for Cover-Bidder Deployment" and adjust the proof environments to "Argument" or "Sketch of proof" to set appropriate expectations. Option (b) is faster and does not weaken the paper if the structural estimation in Section 5.1 delivers.

---

### [M4] The mixture model with known labels is a distributional decomposition, not a structural model in the RAND sense

**Problem:** The likelihood in Equation (12) conditions on known group membership: FL firms are classified as cover bidders and non-FL firms as genuine. This is a supervised mixture model, not an unsupervised one. The paper acknowledges this: "The FL classification provides the mixture labels, so no EM algorithm is required" (Section 3.5).

The consequence is that the "structural" estimation does not identify which firms are cover bidders---this is assumed from the FL classification. The structural parameters describe the *distributions* of bids conditional on the FL label, not the *probability* of being a cover bidder conditional on bid behavior. This is an important distinction. Papers that RAND has published on bid-rigging detection (e.g., Bajari--Ye 2003, Chassang--Ortner 2022) develop methods that *identify* collusive behavior from bid data without requiring pre-labeled groups. The FL screen pre-classifies firms and then asks "how do the classified groups differ?"---a question that OLS with FL × bid-dispersion interactions could also answer without the structural apparatus.

**Location:** Section 3.5, Equations (10)--(12).

**Why it matters for RAND:** The structural contribution of the paper is diminished if the model does not identify cover bidders but merely characterizes their bid distributions conditional on a pre-assigned label. The incremental value over reduced-form methods (which already show FL bids have higher dispersion) is unclear.

**What would resolve it:** The most direct path is to estimate the mixture model *without* using FL labels---treat the cover-bidder identity as latent and estimate group membership jointly with the distributional parameters. If the model's posterior classification of cover bidders correlates with the FL label, this provides a powerful structural validation of the FL screen. This is more work but would make the structural contribution genuine. Alternatively, if the supervised approach is retained, the paper should explicitly state that the structural model characterizes bid distributions *conditional on the FL screen* rather than identifying cover bidders independently, and adjust the claims accordingly.

---

### [M5] The ROC analysis is strong but the ground truth is imperfect

**Problem:** The ROC analysis achieves AUC = 0.94 using co-participation with CADE-convicted cartelists as ground truth. This is an excellent result. However, three caveats deserve discussion:

(a) **Ground truth contamination.** The 193 FL firms that co-participate with CADE cartelists are used as "true positives." But co-participation does not imply collusion: an FL firm that bids in the same tender as a convicted cartel member may be a genuine firm operating in the same market. The ground truth conflates "co-bidding with cartelists" with "being a cover bidder for cartelists." The paper should report the ROC analysis under alternative ground truth definitions (e.g., FL firms that co-bid with CADE cartelists in ≥3 tenders, or FL firms where the CADE-convicted firm *won* the tender).

(b) **Base rate.** Only 98 of the 193 CADE co-bidders overlap with the FREQ_PARTICIP sample (always-losers), yielding a ground truth of 98 positives out of 16,843 firms---a base rate of 0.58%. With such a low base rate, the precision at the optimal threshold (reported as 3.6%) means 96.4% of flagged firms are false positives. The paper should report the precision-recall tradeoff alongside the ROC curve, as ROC can be misleading with highly imbalanced classes.

(c) **Temporal validation design.** Section 4.5 describes a temporal split (FL defined 2009--2014, CADE validated 2015--2019), but the ROC script uses the full sample, not the temporal split. This should be corrected for out-of-sample validity.

**Location:** Section 5.3, Section 4.5, tab_roc_detection.tex.

**Why it matters for RAND:** The detection contribution is the paper's strongest suit for RAND. Strengthening it with robustness on ground truth definitions and honest reporting of the precision-recall tradeoff would make the detection validation publishable on its own.

**What would resolve it:** (i) Report precision-recall curve alongside ROC. (ii) Run ROC with temporal split as described in Section 4.5. (iii) Vary ground truth stringency (co-bid ≥1, ≥3, ≥5 tenders with CADE firms). (iv) Report a confusion matrix at the optimal threshold.

---

### [M6] The convite vs. pregão difference lacks structural explanation

**Problem:** The OLS coefficient is larger for pregão (9.3%) than convite (3.8%). Section 8.4 discusses this, but the structural model predicts the *opposite*: Proposition 1 implies $m^*$ is weakly larger under convite (because the minimum-bidder constraint binds), which should produce a larger price effect under convite, not pregão. The original Prediction 6 (minimum-bidder RDD) has been removed because the RDD is not feasible, but the theoretical tension remains: the model predicts more cover bidding under convite, but the empirical price effect is smaller.

**Location:** Section 3.2 (Equation 7, constraint n + m ≥ 3), Section 8.4.

**Why it matters for RAND:** A structural model that generates a prediction contradicted by the data should either be reconciled (e.g., by adding a channel through which pregão facilitates cover bidding despite no minimum-bidder rule) or acknowledged as a limitation.

**What would resolve it:** Add a discussion to Section 3.4 or Section 8.4 noting that the convite minimum-bidder constraint creates a *floor* on cover bidding (m ≥ 2 when n = 1) but the price *effect* of cover bidding is larger under pregão because real-time bid observation facilitates Regime 1 calibration. The structural model should distinguish between the *quantity* of cover bidders (higher under convite) and the *price impact* per cover bidder (higher under pregão).

---

### [M7] The welfare analysis does not use structural parameters

**Problem:** Section 9.5 computes welfare as (exp(β) − 1) × total FL procurement value, using the reduced-form OLS and IV coefficients. The structural model provides an alternative: the implied structural markup from the mixture model could generate a structurally grounded welfare estimate that accounts for the distinction between Regime 1 and Regime 2 cover bidding effects and for the market-selection pattern (cover bidding concentrates in competitive markets). The structural welfare estimate would be more credible than the accounting exercise currently reported.

**Location:** Section 9.5.

**What would resolve it:** After completing the structural estimation (M1), compute a structural welfare bound using the estimated cover-bid markup and the distribution of FL tenders across market concentration levels. Compare with the reduced-form accounting estimate.

---

## 4. MINOR COMMENTS

1. **One remaining [ESTIMATE] placeholder** in Section 5.1 (line 104): "the bootstrap completes in approximately [ESTIMATE] hours." Fill or remove.

2. **Abstract specificity.** The abstract now states "a cartel markup consistent with OLS (6.4%)" but does not give the structural markup value. After completing M1, the abstract should state the structural estimate explicitly.

3. **Literature: Kawai-Nakabayashi-Ortner.** The references.bib now includes kawai2022detecting, but this paper is not cited in the manuscript text. Add a citation in Section 2 (Related Literature) near the Bajari--Ye discussion.

4. **Literature: Chassang-Ortner (2022).** This important reference is cited in references.bib but the manuscript does not discuss where the FL screen sits relative to robust screening in the Chassang--Ortner framework. Add 2--3 sentences in Section 2.

5. **Cross-fit attenuation.** The 44% attenuation (0.036 vs 0.064) from cross-fitting is mentioned in the robustness section but not reconciled with the structural model. If the structural markup exceeds the cross-fit estimate, this suggests the full-sample FL classification may overfit. Discuss.

6. **Proposition numbering.** Section 3 uses both `\begin{proposition}` (Propositions 3--6 by the counter, since definitions and predictions share the counter) and `\begin{prediction}` (Predictions 7--11). The numbering may be confusing to readers. Consider resetting counters or using separate numbering.

7. **Table B.17 (Bajari--Ye tender FE).** The tender-FE results are critical to the Bajari--Ye interpretation. Confirm that the corrected first stage (excluding n_bids) is used for the tender-FE variant as well, not just the baseline.

8. **CADE temporal split not implemented.** Section 4.5 describes training on 2009--2014 and validating on 2015--2019, but neither the cross-fit analysis nor the ROC script implements this split. The ROC uses the full FL classification (2009--2019). Implement the temporal split for at least the ROC analysis.

9. **Structural sample description.** Section 4.4 states "40 million individual bids" but the bid_level_full.parquet contains firm-tender records, not individual bid amounts. The price information is at the tender-item level (BEC_collapse). Clarify the distinction between the participation-level data (40M rows) and the price data (2.9M tender-items with bid statistics).

10. **Network relabeling consistency.** The relabeling from "high-suspicion" to "concentrated-market" is correct but the original code variable names (has_high_susp_fl) are referenced in the RAND referee report and may appear in appendix tables generated by R code. Ensure no residual "suspicion" labels appear in generated tables.

11. **Regime test formalization.** Prediction 3 states that BIC model selection determines the dominant regime. The current Regime Test subsection (Section 7.6/D.3) uses only a visual density comparison and an OLS regression of bid dispersion on FL presence. Replace or supplement with the actual BIC comparison from the structural estimation.

---

## 5. IDENTIFICATION DEEP-DIVE

### 5.1 Structural Identification

The mixture model with known labels (Section 3.5) is identified by construction: the FL classification partitions bids into two groups, and the distributional parameters of each group are identified from the within-group variation. However, this identification relies entirely on the *validity* of the FL classification. If some FL firms are genuinely incompetent rather than cover bidders, the estimated cover-bid distribution $\hat{G}_{\text{cover}}$ is a mixture of true cover bids and incompetent genuine bids, biasing the structural markup estimate toward zero (attenuation). The paper should discuss this selection-into-FL problem and, ideally, use the network-split classification to estimate the structural model separately for competitive-market FL (where the price effect is significant) and concentrated-market FL (where it is zero).

### 5.2 OLS with Rich Fixed Effects

The OLS estimate of 0.064 remains the paper's most credible and important result. The Cinelli--Hazlett robustness value (RV = 17.5%) is reassuring. The FE-residualized gap of 0.050 log points, reported in the introduction, demonstrates that within-item comparisons are economically meaningful. For the RAND detection paper, this is sufficient. The OLS need not be causal for the screening contribution to hold.

### 5.3 Leave-One-Out IV

The reframing of the IV as a "bracketing device" rather than the primary strategy is appropriate and honestly handled. The balance test discussion (Section 5.2) now acknowledges the imbalance without dismissing it. The Panel A estimate (0.194) provides an upper bound under the measurement-error attenuation interpretation. The Panel C instability (3.64) is correctly characterized as weak-instrument amplification. No further work needed on the IV---the current framing is honest and appropriate for a secondary role.

### 5.4 Bajari--Ye (Corrected)

The exclusion of n_bids from the first stage is critical and correctly implemented. The v4 cache confirms that the actual code never included n_bids (the manuscript text was the error, not the estimation). The KS statistic (0.151, p < 0.001) and pairwise product (FL: 5.16, non-FL: 2.21, difference: 2.95) remain significant. The fake-groups placebo reframing (Section 5.4) is substantially improved: the paper now correctly notes that common tender-level shocks drive the placebo result and that the FL-vs-non-FL *difference* is the relevant test. The tender-FE magnitude reversal (FL: 0.38 < non-FL: 0.86) should be discussed in the context of the structural model's regime prediction: under Regime 1, cover bids are drawn from a wider distribution, which may produce *lower* within-group residual correlation after absorbing tender means (because the uniform distribution has higher variance but lower within-pair covariance than a correlated cost distribution among genuine bidders).

### 5.5 Detection Validation

The ROC analysis is the paper's strongest new contribution. AUC = 0.94 is excellent for a screen using only participation data (no bid values required). The optimal threshold of 1.45x IQR, nearly identical to the paper's 1.5x rule, provides ex post validation of the FL classification. The Youden's J of 0.84 indicates strong separation. The main limitations (ground truth imprecision, low precision at 3.6%) should be addressed per M5.

---

## 6. THEORY EVALUATION

### 6.1 Model Structure

The structural model (Section 3) is well-organized: environment → cartel's problem → equilibrium cover-bid distributions → market selection → likelihood → identification → predictions. The progression from primitives to testable implications is logical. The cartel's objective function (Equation 6) with the three constraints (reference price, cover-above, minimum bidder) captures the key institutional features of BEC.

### 6.2 Prediction--Test Mapping

| Prediction | Test Location | Data Support |
|-----------|--------------|-------------|
| P1 (Price effect) | Section 7.1, Table 5 | 0.064*** (OLS) |
| P2 (Strategic selection) | Section 7.1, Table 6 | 0.19*** (more genuine firms) |
| P3 (Regime identification) | Section 4.4, descriptive | CV ratio 1.52 (Regime 1) |
| P4 (Market selection) | Section 7.3, Table 9 | Competitive FL: 0.126***, Concentrated: −0.018 |
| P5 (Exchangeability) | Section 7.4, Table 11 | KS = 0.151 (p < 0.001) |

All five predictions are confirmed by the data. Prediction 3 is currently supported only by a descriptive CV ratio; the structural BIC comparison (once estimated) would provide a formal test. The prediction-to-test mapping is clean and well-documented.

### 6.3 Missing Theoretical Elements

- The model does not endogenize the cartel's choice of *which* tenders to target (market selection is a comparative static on HHI, not a discrete-choice model of cartel entry).
- The detection probability $\theta_k$ is exogenous; a fuller model would endogenize detection as a function of the enforcement authority's screening strategy, creating a screening game. This is beyond the current paper's scope but should be noted as a limitation.
- The model assumes the winning bid $b^*$ is chosen optimally by the cartel but does not model the interaction between $b^*$ and the genuine bidders' strategies. In a first-price auction, genuine bidders' optimal bids depend on the number of competitors (including cover bidders), creating a feedback loop that the current model does not address.

---

## 7. LITERATURE POSITIONING

### 7.1 Positioning Relative to Key Papers

The paper should position itself more explicitly relative to:

- **Bajari & Ye (2003, ReStat):** The v6 paper correctly implements the Bajari--Ye tests and improves on the original by introducing the FL partition as a principled grouping criterion (vs. ad hoc geographic or size-based groups). The corrected first stage (excluding n_bids) is a methodological contribution.

- **Conley & Decarolis (2016, AEJ:Micro):** The paper cites this but does not compare FL screening with Conley--Decarolis group detection. The FL screen is operationally simpler (participation counts vs. co-bidding matrices) but less general. A direct comparison on BEC data would strengthen the contribution.

- **Chassang & Ortner (2022, Econometrica):** The FL screen is not "robust" in the Chassang--Ortner sense (it relies on a specific threshold). The paper should discuss this limitation and whether the ROC analysis partially addresses it by characterizing the screen's operating characteristics.

- **Imhof et al. (2018, 2019):** The horse-race between FL and Imhof-style CV screens is mentioned in the empirical strategy but results are not reported in the Results section. The v4 manuscript has this in Section 8.3; it should be integrated into the v6 detection validation.

### 7.2 Incremental Contribution

The paper's clearest contribution for RAND is the *combination* of:
1. A structural foundation for why cover-bidder detection works (Section 3)
2. A practical detection tool validated against enforcement outcomes (AUC = 0.94)
3. The market-selection insight (cover bidding concentrates in competitive markets)

This combination---structural theory + validated detection tool + policy-relevant heterogeneity---is publishable at RAND if the structural estimation is completed.

---

## 8. CONCLUSION AND CONDITIONS

This paper has the ingredients for a RAND publication: a structural model with clear predictions, a large and rich dataset, a detection tool with AUC = 0.94 validated against enforcement outcomes, and a novel market-selection finding that emerges from theory. The v6 reframe is a substantial improvement over the prior version. However, the structural model is specified but not estimated, and the Results section has not been updated to reflect the new empirical strategy. The paper is currently a hybrid of a well-developed structural methodology section and an unreconstructed reduced-form results section.

I recommend **Major Revision** with three conditions for acceptance:

1. **Complete the structural estimation** (M1). Report the structural parameter table, BIC regime comparison, implied markup, and bootstrap standard errors. This is the paper's centerpiece and it must deliver quantitative results, not just methodology.

2. **Restructure the Results section** (M2). Align Section 7 with the empirical strategy in Section 5. Lead with structural estimation results, followed by detection validation (ROC/AUC), then reduced-form evidence and Bajari--Ye tests.

3. **Strengthen the detection validation** (M5). Report precision-recall alongside ROC. Implement the temporal split described in Section 4.5. Vary ground truth stringency. Report a confusion matrix.

If these three conditions are met, the paper would be a strong candidate for RAND. The structural model + detection validation combination is novel and the BEC dataset provides a uniquely rich laboratory. The market-selection prediction---derived theoretically and confirmed empirically---is the kind of finding RAND values: it advances understanding of how cartels operate, not just how to detect them.

**Estimated acceptance probability conditional on completing M1--M3: 50--60%.**

The main remaining risk is that the structural estimation may produce implausible parameters or that the BIC comparison may not cleanly select between regimes. If the structural estimation fails, the paper should pivot to the Detection Tool framing (Option C from the reframe memo) and target RAND on the basis of the ROC validation and the market-selection heterogeneity result, dropping the structural claim. This fallback version has a lower but still viable probability at RAND (~25--30%).

---

*Word count: approximately 3,100 words.*
