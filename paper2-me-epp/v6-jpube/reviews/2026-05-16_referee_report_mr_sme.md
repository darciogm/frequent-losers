# Referee Report -- "Sheltered Bidding: The Within-Auction Cost of SME Set-Asides"

**Recommendation:** Major revision / revise-and-resubmit.  
**Bottom line:** The paper has a promising institutional setting, unusually rich procurement microdata, and a plausible structural route from Pregao drop-out bids to a within-auction decomposition. It is not ready for acceptance in its current form. The empirical design and structural interpretation are close enough to be worth revising, but several claims are still too strong relative to the evidence.

## Summary

The paper studies the extension of SME-only procurement rules to medical and hospital supplies on Sao Paulo's BEC platform. A legal reinterpretation in 2017/2018 generated a shift in admissibility for Group 65 items. The paper first estimates a reduced-form price increase after the rule and then uses an asymmetric IPV model of descending-clock reverse auctions to decompose the effect into an "inside the auction" order-statistic component and an entry-response component. It then compares full SME set-asides to price-preference instruments and computes welfare losses under a marginal cost of public funds.

The core idea is attractive. The Pregao format is genuinely useful because losing drop-out bids can be interpreted as cost observations under IPV, avoiding some of the bid-function inversion burden in first-price procurement settings. The institutional narrative is also plausible: the rule change came from a general legal reinterpretation, not from a medical-supply-specific economic shock. The paper's strongest contribution is therefore not the label "sheltered bidding"; it is the combination of a legal trigger, clock-auction cost recovery, observed entry shifts, and welfare comparison across alternative SME instruments.

That said, the current draft overstates the strength of several links in the chain. The reduced-form anchor is weaker than the prose suggests; the post-policy SME cost distribution remains only partially identified as "selection"; the collusion diagnostics are not innocuous; and the policy conclusion sometimes treats a modest price preference as if it achieved the same distributional objective as a full set-aside. The paper can be made much stronger, but it needs to become more modest and more internally disciplined.

## Major Comments

### 1. The DiD evidence is too weak to carry the current anchoring language.

The paper presents the DiD as a design validation and magnitude anchor, but the supporting evidence is mixed. The pre-treatment balance table shows serious imbalance: 7 of 9 normalized differences exceed 0.10 and 4 of 9 exceed 0.25, with particularly large gaps in firms per item, SME bid share, Pregao share, and bidder geography. Item fixed effects help, but they do not solve differential trends or composition-specific shocks.

The alternative DiD estimators also weaken the claim. TWFE gives about -0.108, but BJS falls to -0.056 with a confidence interval that reaches zero, and Callaway-Sant'Anna is essentially uninformative. The placebo tests are not clean either: two fake price cutoffs are significant. The "magnitude separation" argument is usable, but it is not a substitute for clean pre-trends.

Required revision: downgrade the DiD from "anchoring" evidence to a suggestive reduced-form benchmark unless stronger evidence is added. At minimum, report matched-control or pre-trend-weighted controls, show robustness to excluding badly imbalanced control groups, and present monthly leads/lags rather than only semester bins. The current text should not imply that modern DiD estimators corroborate the TWFE magnitude; they mostly corroborate the sign, and weakly.

### 2. The treatment of cost primitives is still the central identification vulnerability.

The model assumes the non-SME cost distribution is stable across periods, while allowing the SME distribution to differ pre/post. But the text also reports primitive-invariance tests that reject stability in some non-SME and Pregao cells. That is not a small detail. If non-SME primitives are moving around the cutoff, the open-regime counterfactual and the legal-trigger interpretation become less clean.

For SMEs, the main specification estimates `F_c^{SME,Post}` directly from post-period exits and interprets the difference from `F_c^{SME,Pre}` as selection or composition change. The new turnover test helps: new pharma SMEs are a large share of post-period firms and bids. But turnover proves composition change, not the welfare-relevant claim that entrants draw from a systematically different cost tail caused by the policy. New firms could be high cost, low cost, specialized, regionally different, or responding to unrelated market conditions.

Required revision: make the primitive-stability failures explicit and state exactly how they affect the counterfactual. Add entrant-versus-incumbent cost distributions, continuing-firm pre/post comparisons, reweighting exercises that hold observed firm composition fixed, and a version excluding new entrants. Without those, the pharma "bifurcation" should remain a sensitivity result, not a policy-design conclusion.

### 3. "Sheltered bidding" is still overbranded relative to the economics.

The paper's decomposition is useful, but the within-auction component is an order-statistic/admissibility component. In the clock-auction IPV model, there is no strategic rebidding response by surviving firms: exit-at-cost remains weakly dominant. Calling this "bidding" risks suggesting a behavioral mechanism the paper explicitly rules out.

The decomposition is also partly mechanical:

`S3 - S1 = (S2 - S1) + (S3 - S2)`.

That arithmetic is not the contribution. The contribution is estimating the components from the auction format and showing their magnitudes in this policy environment.

Required revision: make "order-statistic component" the technical term and reserve "sheltered bidding" as a descriptive label, if used at all. The abstract and conclusion should report both normalizations: the within-auction component is about 69-72% of absolute component magnitude, but 164-183% of the net effect because entry offsets it. The latter is more informative for readers.

### 4. Bid coordination remains a real threat to the cost interpretation.

The robustness section reports that Conley-style and Bajari-Ye screens reject independence in all class-period cells. The fact that clustering does not increase after the policy is reassuring, but it does not eliminate the problem. If drop-out behavior reflects coordination, the recovered object is not a pure cost distribution; it is a cost-plus-coordination object. That matters directly for the structural welfare decomposition.

The current defense is too quick. Saying that clustering is time-invariant or lower post-policy helps the reduced-form interpretation, but the structural model still treats drop-out prices as costs. Kawai-Nakabayashi-style concerns are therefore not peripheral.

Required revision: bring the coordination tables into the main paper, not only the replication layer. Add a decomposition on a low-coordination subsample, drop high-persistence bidder pairs, and compare results for new versus continuing bidders. If the result survives, the paper becomes much more credible. If it does not, the interpretation should change: the set-aside may raise prices partly by enabling coordination among protected bidders, not only by changing order statistics.

### 5. The welfare comparison currently overstates what the 10% preference achieves.

A 10% price preference appears to have near-zero price and welfare cost, but it also delivers a much smaller distributional intervention than a full set-aside: the SME win-rate gains reported for the preference are only a few percentage points. Full set-asides are costly partly because they are a much larger redistributive instrument. The paper sometimes writes as if V3 "welfare-dominates" V0 in a simple sense, but that conclusion depends on the planner's welfare weight on SME surplus and on whether the policy objective is marginal SME participation or a large transfer to SMEs.

The welfare-weight identity is the right framework. It should discipline the rhetoric more aggressively. In non-pharma, the required SME welfare weight seems high, so a preference rule is more attractive. In pharma, the ranking flips under strict invariance, and the turnover evidence only partly adjudicates that choice.

Required revision: replace unconditional policy language with frontier language. V3 is a low-cost, low-redistribution instrument; V0 is a high-cost, high-redistribution instrument. The paper can argue that V0 is hard to justify in thick standardized markets, but it should not imply that V3 achieves the same SME policy objective.

### 6. Numerical reproducibility is still not publication-grade.

The paper acknowledges drift in `p_S1` across tables: 0.774 in the BNE decomposition, 0.771 in APV, and 0.767 in welfare. The government's extra payment also differs across related tables: the BNE total is about 0.227, APV is about 0.232, and the welfare table uses 0.247 for non-pharma. The footnote attributing this to Monte Carlo noise is not acceptable for a polished submission. These are core headline quantities.

Required revision: run one canonical simulation with common seeds/draws and propagate the same objects to all tables through one macro registry. Use larger Monte Carlo draws where needed and include a run manifest. Do not ask referees to tolerate multiple values for the same object.

### 7. Entry is treated too coarsely for the strength of the claims.

Observed average counts enter as Poisson arrival rates by broad stratum. That is defensible as an accounting exercise, but it is a thin model of entry. Entry likely varies by buyer, item, class, volume, geography, and repeated supplier relationships. A single Poisson mean per class-period can mechanically understate uncertainty in the participation margin.

The "entry cost" calculation is also too fragile to carry much interpretation. The magnitudes are tiny and are not jointly estimated from a free-entry equilibrium. The paper says this is only a calibration check, but then uses the asymmetry to support the entry story.

Required revision: add sensitivity using the empirical entry-count distribution, negative binomial arrivals, and finer class/PBU-specific arrival rates. Downgrade the entry-cost table or move it to the appendix unless it is made structurally meaningful.

## Minor Comments

1. The paper alternates between 76 and 77 control groups. The balance table explains the difference, but the reader should not have to discover this in a footnote. Harmonize terminology early.

2. The balance table reports pre-period Group-65 SME bid share as 0.000. That is surprising in an open regime and needs a clear explanation.

3. The APV table note says "V1 = 50% means half the v3 effect"; this is confusing because V3 is also the name of the 10% preference variant. Use "half the V0 set-aside effect."

4. The welfare section says the annual upper-bound pattern reflects "thin standardized markets"; elsewhere pharma is described as thin and heterogeneous. Use one characterization.

5. The paper repeatedly cites "Athey-Seira" for a paper that is generally Athey, Levin, and Seira. If the bibkey omits Levin, fix the citation and prose.

6. Bootstrap `B = 500` is low for headline confidence intervals. Use at least 1,000, preferably 2,000, unless runtime is prohibitive.

7. The reference-price normalization is important enough to deserve more validation. Show that reference prices do not themselves move around the cutoff within item/PBU cells.

8. The phrase "BNE counterfactual" is unnecessarily strong for the clock-auction simulations. "Monte Carlo counterfactual under IPV exit-at-cost" is more precise.

9. The annual scaling to federal and municipal procurement should be framed as external validity motivation, not proportional extrapolation. The current local estimate is for one product group on one state platform.

## Strengths

The institutional setting is unusually good for this question. The legal reinterpretation and BEC implementation sequence provide a credible source of variation, and the paper documents the timeline carefully.

The use of Pregao drop-out bids is a real advantage. Recovering costs from losing exits under an English-reverse interpretation is a cleaner route than bid-function inversion in first-price formats, conditional on IPV and no coordination.

The paper is unusually transparent about alternative specifications: Turnbull NPMLE, strict invariance, cost-affiliation grids, filter/window sensitivity, policy variants, and modern DiD checks. The right instinct is there. The main problem is not absence of robustness; it is that the prose often outruns what the robustness actually proves.

The welfare-weight framing is the most promising policy contribution. It converts a vague "SMEs deserve support" claim into an explicit price of redistribution. That part should become the organizing policy language.

## Recommendation to the Editor

I would invite a major revision rather than reject. The paper has a plausible path to publication if the author narrows the claims, fixes numerical reproducibility, and treats the DiD/primitive-stability/coordination issues as first-order rather than robustness footnotes. I would not accept the paper in its current form because the headline policy claims depend on assumptions and empirical anchors that are currently presented too confidently.

