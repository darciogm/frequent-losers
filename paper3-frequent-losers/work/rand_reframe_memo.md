# Reframe Strategy Memo

**Target:** RAND Journal of Economics
**Paper:** Frequent Losers as Cover Bidders in Public Procurement
**Date:** 2026-03-15

---

## 1. HONEST DIAGNOSIS

### 1a. What the paper currently IS

The paper is an applied empirical IO paper that proposes a new firm-level screening tool (frequent losers) for detecting cover bidding in procurement auctions. Its empirical backbone is a high-dimensional OLS regression showing a robust 4-9% price association between FL presence and negotiated prices, validated against CADE cartel convictions and a battery of robustness checks. The paper attempts to move beyond association toward causation using three supplementary strategies---a leave-one-out IV, Bajari-Ye bid-coordination tests, and a staggered DiD---but none of these delivers clean causal identification. The paper's genuine strength is the practical screening contribution (H1): a simple, data-parsimonious tool that works with participation data alone, demonstrated at scale (4.5M tender-items) in a developing-country context. The causal claim (H2) is suggestive but not established.

### 1b. What RAND wants

RAND would publish a paper on this topic if it offered one of: (a) clean causal identification of the price effect of cover bidding, using a quasi-experiment or institutional discontinuity that provides exogenous variation in FL exposure; (b) a structural model of cover bidding that estimates the cartel's optimization problem, delivers counterfactual predictions (e.g., optimal screening threshold, welfare under alternative procurement rules), and fits the data; (c) a methodological contribution that advances the detection toolkit---a new algorithm with formal properties (consistency, power, false-discovery rate) that demonstrably outperforms existing methods on held-out validation data; or (d) strong reduced-form evidence that disciplines auction theory, such as cleanly identified effects of cover bidding on entry, bid distributions, or auction outcomes that map onto structural parameters. RAND values precise identification and theoretical novelty over breadth of robustness checks.

### 1c. The gap

The gap is in identification and theoretical grounding. The paper has *breadth* (16 tables, 14 figures, 6 robustness groups) but lacks *depth* on any single identification strategy. The IV fails balance; the Bajari-Ye tests are internally inconsistent; the DiD is null; the theoretical framework is taxonomic rather than equilibrium-based. RAND papers typically do one thing excellently rather than six things adequately. The paper needs to either (i) find a single clean identification strategy and build the paper around it, or (ii) reframe away from causal identification toward methodological or policy contribution. The CADE validation---currently a five-page section---is actually the paper's most RAND-relevant contribution but is underexploited: it connects the statistical screen to real enforcement outcomes.

---

## 2. REFRAME OPTIONS

### Option A --- "The Identification Paper"

**Strategy:** Reframe around clean causal identification of the cover-bidding price effect. Drop the LOO IV as the primary strategy. Identify a natural experiment or institutional discontinuity in BEC data.

**Candidates to investigate:**

1. **Minimum-bidder regulation change.** Did any Brazilian procurement regulation during 2009-2019 change the minimum number of bidders required for convite modality? If a regulation raised or lowered the threshold, this creates a difference-in-differences design where cover bidding incentives shift discontinuously.

2. **BEC geographic expansion.** If BEC expanded to cover new municipalities or agencies during the sample period, newly covered PBUs provide a clean treatment group for FL entry effects. The staggered adoption of BEC across agencies could serve as an instrument for FL supply.

3. **Value threshold for modality switching.** Convite applies below R\$80,000 and pregao above. If there is bunching at this threshold, an RDD using procurement value as the running variable could identify the causal effect of the convite minimum-bidder rule on cover bidding.

4. **CADE enforcement shocks.** If CADE convicted specific cartels during the sample period, the post-conviction exit of FL firms from affected markets provides a quasi-experiment: do prices fall when FL firms exit?

5. **FL firm deaths/exits.** If FL firms are shell companies, some will be deregistered (CNPJ cancelled) for tax non-compliance. Exogenous FL exits (driven by tax enforcement, not procurement outcomes) provide clean variation in FL exposure.

| Dimension | Assessment |
|---|---|
| Feasibility | Medium. Requires investigation of institutional details and data availability. The value-threshold RDD and CADE enforcement shocks are most promising with existing data. |
| Required work | 2-3 months to investigate candidates, implement the cleanest one, and restructure the paper. |
| RAND probability | **Medium (30-40%)** if a clean quasi-experiment is found. The paper becomes "clean ID + BEC data" which is publishable but not guaranteed at RAND if the natural experiment is small or local. |

---

### Option B --- "The Structural Screening Paper"

**Strategy:** Build a structural model of cover bidding that:
- Models the cartel's cover-bidder deployment decision as a function of n genuine bidders, reference price, detection probability, and auction format
- Derives the equilibrium cover-bid distribution under each regime as a best response
- Generates a structural likelihood function over observed bid data
- Estimates structural parameters (detection probability, cover-bidding cost, cartel markup)
- Computes counterfactual welfare under alternative procurement rules (e.g., removing minimum-bidder requirements, introducing FL screening)

This would transform the paper from "here is a screen" to "here is a model of cover bidding that rationalizes the screen, estimates its parameters, and delivers policy counterfactuals."

| Dimension | Assessment |
|---|---|
| Feasibility | Low-Medium. Requires structural auction modeling expertise. The 40M bid-level dataset provides sufficient data for estimation, but the model must handle the two-modality structure (convite vs. pregao) and the endogenous number of cover bidders. |
| Required work | 4-6 months minimum. Model development, estimation, counterfactual computation. |
| RAND probability | **Medium-High (40-50%)** if executed well. Structural auction models are RAND's bread and butter, and this would be the first structural model of cover bidding with parameter estimates. The risk is that the model may not fit the data well or may produce implausible parameter estimates. |

---

### Option C --- "The Detection Tool Paper"

**Strategy:** Reframe around the methodological contribution of FL as a detection algorithm. Drop the causal claim (H2) entirely. Make H1 the entire paper. The CADE validation becomes the centerpiece.

**Key elements:**
1. **Formal detection framework.** Define FL screening as a classification problem: FL = 1 vs. FL = 0 for each firm, with CADE convictions as ground truth. Compute precision, recall, F1-score, and false-discovery rate.
2. **ROC curve.** Vary the IQR threshold and compute the receiver operating characteristic curve. Find the optimal threshold that maximizes expected enforcement value (weighting true positives by prosecution benefit and false positives by investigation cost).
3. **Head-to-head comparison.** Implement Imhof et al. (2018) and Conley-Decarolis (2016) on BEC data. Compare FL with these established methods on the same held-out CADE validation set. Compute incremental detection power of combining FL with bid-level screens.
4. **Policy design.** Given a competition authority with a fixed investigation budget, what is the optimal allocation between FL screening and bid-level screening? This is a statistical decision theory problem with practical relevance.
5. **Out-of-sample validation.** Use temporal cross-validation: define FL using 2009-2014 data, validate against CADE convictions during 2015-2019.

| Dimension | Assessment |
|---|---|
| Feasibility | High. All components are implementable with existing BEC data and CADE validation data. The Conley-Decarolis implementation requires constructing the co-bidding matrix, which is computationally intensive but feasible with the firm-tender map (16.8M rows). |
| Required work | 1-2 months. ROC curve, formal comparison, policy design framework. |
| RAND probability | **Low-Medium (20-30%)**. RAND has published methodological papers (Chassang-Ortner 2022) but they typically require theoretical foundations (optimality, robustness). A purely empirical comparison of screens may be better suited to the Journal of Econometrics or a specialized outlet. However, if the comparison demonstrates dramatic incremental value of FL over existing methods, and the policy design component is rigorous, RAND could be interested. |

---

### Option D --- "The Market Design Paper"

**Strategy:** Reframe around the institutional design question: Why do cover bidders exist in Brazilian procurement but not (as visibly) elsewhere? What features of BEC's rules create the FL equilibrium?

**Key elements:**
1. **Institutional analysis.** Compare BEC's rules with procurement systems where cover bidding is less prevalent (e.g., EU e-procurement, US federal procurement). Identify which BEC features---minimum-bidder requirements, reference price disclosure, real-time bid observation in pregao---create the cover-bidding opportunity.
2. **Counterfactual rule changes.** Analyze what would happen if: (a) the minimum-bidder requirement were removed; (b) reference prices were sealed; (c) FL screening were implemented with automatic investigation triggers. Use the existing estimates to calibrate the effects.
3. **Mechanism design.** Can the procurement mechanism be redesigned to make cover bidding unprofitable? This connects to the Chassang-Ortner (2022) robust screening framework.
4. **Dynamic effects.** What happens when FL firms are screened out? Do cartels adapt (rotate cover bidders, allow occasional wins)? The temporal FL definition (Section 9.1) provides suggestive evidence.

| Dimension | Assessment |
|---|---|
| Feasibility | Medium. The institutional analysis is feasible but requires knowledge of comparative procurement regulation. The counterfactual analysis requires assumptions about cartel behavior under alternative rules. |
| Required work | 3-4 months. Institutional comparison, counterfactual calibration, mechanism design component. |
| RAND probability | **Medium (25-35%)**. This is the most "RAND-style" framing but requires the most new work. The risk is that the institutional comparison becomes descriptive rather than analytical. If the mechanism design component is rigorous (proving that a specific rule change eliminates the cover-bidding equilibrium), this could be very strong. |

---

## 3. RECOMMENDED PATH

### Primary recommendation: Option B (Structural) combined with elements of Option C (Detection)

The highest-probability path to RAND is a structural model of cover bidding estimated on BEC data, combined with a rigorous detection comparison. Specifically:

1. **Build a simple model** of cartel cover-bidder deployment (extending Section 3 from taxonomy to equilibrium). The model should predict: how many cover bidders to deploy, what bids they submit, and which tenders to target. Estimate the structural parameters using maximum likelihood on the 40M bid-level dataset.

2. **Use the structural model to derive the optimal detection threshold.** This replaces the ad-hoc IQR threshold with a model-implied threshold that maximizes expected social welfare given prosecution costs and detection rates.

3. **Validate against CADE** convictions using the structural model's predictions. Compute the model-implied probability of cover bidding for each tender and compare with CADE conviction data.

This combination delivers what RAND wants: a structural contribution (model + estimation) with empirical validation (CADE) and policy relevance (optimal detection design).

**Honest probability at RAND: 35-45%** with 4-6 months of additional work.

### If RAND is not achievable

If the structural path is infeasible (due to timeline, expertise, or model fit issues), the recommended fallback sequence is:

1. **IJIO** (current target): The paper is already accepted for minor revision at IJIO. Complete the R1 revision and publish. Probability: **90%+**.

2. **Journal of Law, Economics, & Organization (JLEO):** Reframe around the policy/enforcement contribution. The CADE validation, implementation blueprint, and developing-country context are strong for JLEO. Minor modifications needed. Probability: **60-70%**.

3. **Review of Economics and Statistics (ReStat):** Only viable if a clean quasi-experiment is found (Option A). ReStat values clean ID over structural models. Probability: **25-35%** conditional on finding the natural experiment.

4. **Journal of the European Economic Association (JEEA):** Similar to ReStat but more open to applied IO without structural estimation. Probability: **30-40%** with Option A or C reframe.

### Bottom line

RAND is achievable but requires 4-6 months of structural modeling work that may not succeed. The expected-value calculation favors publishing at IJIO now (90%+ probability) and developing the structural extension as a separate paper. If the authors want to pursue RAND, Option B is the path, but they should only commit if they have structural auction modeling expertise on the team or can bring in a co-author.

---

## 4. ADDITIONAL ANALYSES --- SHORT LIST

### Analysis 1: Bajari-Ye first stage without n_bids

**What it tests:** Whether the exchangeability and conditional-independence violations survive when the potentially endogenous variable (number of bids) is removed from the Bajari-Ye first stage.

**Implementation:** Re-estimate the first-stage bid equation excluding n_bids. Keep firm size, firm age, CNAE sector, and item + year FE. Re-compute KS statistic (exchangeability), pairwise products (conditional independence), and tender-FE variants.

**Strengthening result:** KS and pairwise products remain significant and similar in magnitude. **Weakening result:** Exchangeability violation disappears or is substantially reduced.

**Supports:** All reframe options. This is a fix, not a reframe-specific analysis.

**Impact:** High. **Feasibility:** High (re-estimate existing code with one variable dropped). **Time:** 1 week.

---

### Analysis 2: CADE enforcement shock DiD

**What it tests:** Whether prices in markets with FL presence decline after CADE convicts cartelists in related markets, and whether FL firms exit after CADE enforcement.

**Implementation:** Identify the 47 CADE-convicted firms matched to BEC. Define "treated markets" as item-group x PBU cells where convicted firms participate. Use conviction dates as treatment timing. Estimate a staggered DiD (Callaway-Sant'Anna) on log prices in treated vs. never-treated markets, with FL exit as a mediator.

**Strengthening result:** Prices decline in treated markets after conviction, and FL firms exit those markets. **Weakening result:** No price change or FL firms persist after conviction.

**Supports:** Option A (clean identification). Also provides causal evidence for H2.

**Impact:** Very high (this could be the clean quasi-experiment the paper needs). **Feasibility:** Medium (requires CADE conviction dates matched to BEC at the market level). **Time:** 1 month.

---

### Analysis 3: ROC curve and formal detection comparison

**What it tests:** The FL screen's classification performance relative to Imhof-style bid-level screens and random classification, using CADE convictions as ground truth.

**Implementation:** Vary the IQR multiplier from 0.5 to 5.0 in steps of 0.1. For each threshold, classify firms as FL or non-FL. Compute true positive rate (FL firms that co-participate with CADE cartelists) and false positive rate (FL firms that do not). Plot the ROC curve. Compute AUC. Repeat for an Imhof-style screen (CV median split on bid-level data). Compare AUC.

**Strengthening result:** FL achieves AUC > 0.7 and outperforms Imhof on this validation set. **Weakening result:** FL is no better than random classification (AUC ~ 0.5) or Imhof dominates FL.

**Supports:** Option C (Detection Tool Paper). Also strengthens H1 contribution for any reframe.

**Impact:** High. **Feasibility:** High (all data available). **Time:** 2 weeks.

---

### Analysis 4: Value-threshold RDD for convite minimum-bidder effect

**What it tests:** Whether the cover-bidding price effect is discontinuously larger just below the R\$80,000 convite threshold (where minimum-bidder requirements bind) relative to just above (pregao, no minimum).

**Implementation:** Restrict sample to tenders with estimated values near R\$80,000. Use procurement value as the running variable. Estimate a local-linear RD of log negotiated price on FL presence, interacted with an indicator for being below the threshold. Bandwidth selection via Calonico-Cattaneo-Titiunik (2014).

**Strengthening result:** The FL x below-threshold interaction is positive and significant, indicating cover bidding is driven by the minimum-bidder rule. **Weakening result:** No discontinuity, suggesting cover bidding is not driven by the minimum-bidder requirement.

**Supports:** Option A (clean identification) and Option D (market design).

**Impact:** Very high (provides quasi-experimental variation). **Feasibility:** Medium (requires procurement value data, which may be the reference price in BEC). **Time:** 1 month.

---

### Analysis 5: Structural cover-bid distribution estimation

**What it tests:** Whether FL bids are generated by a distribution consistent with cover bidding (Regime 1 or 2) and whether the structural parameters (cartel markup, cover-bidding cost, detection probability) are economically plausible.

**Implementation:** Specify a mixture model: each bidder is either genuine (draws from F_genuine) or cover (draws from F_cover). Use the FL classification as a prior on bidder type. Estimate F_genuine and F_cover nonparametrically (kernel density) or parametrically (log-normal for genuine, uniform or normal for cover). Use the bid-level data (40M bids) for estimation. Compute the implied cartel markup as (E[winning bid | FL present] - E[winning bid | FL absent]) / E[winning bid | FL absent] under the structural model.

**Strengthening result:** The structural markup estimate is consistent with the reduced-form OLS (6-9%) and the estimated cover-bid distribution matches Regime 1 (uniform above winning bid). **Weakening result:** The mixture model cannot distinguish cover from genuine bids, or the implied markup is economically implausible.

**Supports:** Option B (Structural Paper). This is the core analysis for the structural reframe.

**Impact:** Very high. **Feasibility:** Medium-Low (requires structural estimation expertise). **Time:** 2-3 months.

---

## 5. ABSTRACT REWRITE (for recommended Option B + C combination)

> Cover bidding---the deployment of sham bidders to simulate competition in rigged procurement auctions---is a widespread but difficult-to-detect cartel practice. We develop a structural model of cover-bidder deployment that predicts the optimal number, bid distribution, and market selection of cover bidders as a function of genuine competition, reference prices, and detection probability. Estimating the model on 40 million bids from Brazilian public procurement (2009-2019), we identify 2,735 cover-bidder candidates ("frequent losers": firms that never win yet participate abnormally often). The structural estimates imply a cartel markup of [X]% in cover-bid-present tenders, consistent with OLS (6.4%) and within the range of cartel overcharge estimates in the literature. Validation against competition authority convictions shows the model-implied detection probability significantly predicts actual enforcement outcomes (AUC = [Y]). We derive the welfare-maximizing detection threshold as a function of enforcement capacity, providing a practical screening tool for competition authorities.

*(141 words --- adjust X, Y with actual estimates)*

---

## 6. CRITICAL FLAGS

1. **The n_bids variable in Bajari-Ye first stage must be investigated immediately.** If removing it changes the results, the entire Bajari-Ye evidence base collapses. This should be checked before any submission or reframe decision.

2. **The CADE enforcement shock analysis (Analysis 2) should be scoped before committing to any reframe.** If conviction dates are available and the DiD produces a significant result, this changes the calculus dramatically---Option A becomes the highest-probability path to RAND.

3. **The cross-fit attenuation (0.036 vs. 0.064) should be addressed in any version of the paper.** A 44% attenuation from cross-fitting is large and may indicate in-sample overfitting of the FL definition. This is the most common RAND referee concern for screening papers.

4. **The network-split labeling must be resolved.** The variable names (has_high_susp_fl) contradict the paper's current interpretation. Either the variables are mislabeled or the original hypothesis failed. Either way, the current presentation is misleading.
