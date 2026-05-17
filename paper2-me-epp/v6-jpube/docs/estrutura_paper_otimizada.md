# The Price of Exclusion: SME Set-Asides in Public Procurement

## Core Thesis

SME set-asides increase procurement prices mainly because they remove the
non-SME bidders that discipline the auction. Additional SME entry exists and
partly offsets the damage, but it does not replace the lost competitive
discipline. A price preference preserves that discipline and can support SMEs
at much lower welfare cost in thick standardized markets.

## 9.5+ Ambition

The paper should read as a general procurement-design principle, not as a
collection of Sao Paulo results:

> Set-asides are costly because they replace competition by eligibility. The
> policy question is not whether to support SMEs, but whether to support them
> while preserving the bidders that discipline price formation.

To reach that level, the paper needs:

- one general decomposition of set-aside effects into lost competitive
  discipline and protected-entry/composition offset;
- one memorable "paper in one figure" visualization;
- direct evidence that the entry/composition margin is not driving the
  headline result;
- direct evidence that coordination does not explain the recovered cost
  distributions;
- a reduced-form section that is either stronger or rhetorically demoted;
- a policy frontier framing rather than a slogan that preferences are free.

The route to 9.5+ is depth and clarity, not more results.

## Core DAG

```text
Legal shock
  -> SME-only rule
  -> non-SME exclusion + SME entry/composition
  -> effective auction pool
  -> price formation and allocation
  -> welfare
  -> set-aside vs price preference
```

Every main-text section should correspond to one block of this DAG. If a result
does not help the DAG, it should not be in the body of the paper.

## Main Text Structure

Target length: 30-33 pages before references if possible.

Recommended inventory:

- 4 main tables.
- 3 main figures, with Figure 2 as the "paper in one figure."
- No table farm in the body.
- Robustness summarized, not exhaustively displayed.

The ideal main figure layout:

- Figure 1: legal shock and take-up.
- Figure 2: two-panel core mechanism:
  - Panel A: `S1 -> S2 -> S3` set-aside decomposition.
  - Panel B: set-aside vs price preference, showing that the preference keeps
    non-SMEs in the auction and preserves competitive discipline.
- Figure 3: welfare-weight / policy frontier.

## 1. Introduction

Target: 4 pages.

Purpose: sell one idea only.

Main logic:

1. Set-asides are meant to help SMEs, but they operate through exclusion.
2. Exclusion changes two margins with opposite signs:
   - it removes non-SME competitive discipline;
   - it induces SME entry and changes SME composition.
3. Reduced-form price effects cannot separate those mechanisms.
4. Sao Paulo's legal shock and BEC Pregao auctions allow the decomposition.
5. Main finding: SME entry increases, but exclusion of non-SMEs dominates.
6. Policy implication: price preferences preserve competition; full set-asides
   require stronger justification in thick standardized markets.

General contribution sentence:

> The paper turns SME set-asides from a price-effect question into a
> procurement-design question: when the government supports protected bidders,
> does the instrument preserve or remove the bidders that discipline the
> auction?

Allowed headline claims:

- The cost is primarily the loss of competitive discipline.
- Entry is an offset, not the source of the markup.
- Price preferences dominate full set-asides in thick standardized markets.

Avoid as headline claims:

- Pharma bifurcation.
- "Sheltered bidding" as the central concept.
- Annual R$ scaling.
- Empate ficto.

## 2. Setting, Data, and First-Stage Facts

Target: 5-6 pages.

Purpose: establish the institutional shock and show that the DAG's mediators
move in the data.

### 2.1 Legal Shock

Keep short:

- LC 123/2006 and LC 147/2014 as background.
- Old interpretation: the threshold applied to the total purchase notice.
- PGE-SP/BEC shift to item-by-item interpretation.
- Group 65 becomes exposed to SME-only treatment.
- March 2018 is mass take-up, not formal enablement.

Main figure:

- Figure 1: institutional timeline plus adoption/take-up.

### 2.2 Data and Auction Format

Only what is needed:

- BEC administrative microdata.
- Group 65.
- Pregao reverse auction.
- SME status.
- Structural window.
- Pharma/non-pharma as market heterogeneity, not a second paper.

### 2.3 First-Stage Facts

Show four facts:

1. SME-only adoption rises.
2. Non-SME participation falls.
3. SME entry rises.
4. Winning prices rise.

Main tables:

- Table 1: sample, pre/post entry, SME participation, prices.
- Table 2: compact DiD benchmark.

Tone:

- Call the DiD a reduced-form benchmark or design validation.
- Do not make it carry the full causal magnitude of the structural paper.
- To support a 9.5+ version, either strengthen the DiD with matched/synthetic
  or pre-trend-weighted controls, or deliberately reduce its rhetorical load.
  The structural decomposition should not rest on a reduced-form estimate whose
  modern-DiD variants are materially weaker.

## 3. Model and Identification

Target: 5 pages.

Purpose: explain how the paper moves from observed prices to mechanisms.

### 3.1 Auction Environment

Include:

- Asymmetric IPV.
- SME and non-SME cost distributions.
- Pregao as an English-reverse procurement auction.
- Losing drop-out bids as cost observations under exit-at-cost.

### 3.2 Cost Recovery

Keep focused:

- Drop-outs identify type-specific cost distributions.
- Winner censoring handled in robustness.
- Auction-level unobserved heterogeneity correction explained briefly.
- Avoid turning this into a technical appendix.

### 3.3 Counterfactual Objects

Define only the three essential scenarios:

- `S1`: open auction, pre-policy pool.
- `S2`: SME-only auction, pre-policy SME pool.
- `S3`: SME-only auction, post-policy SME pool.

Core decomposition:

```text
p_S3 - p_S1 = (p_S2 - p_S1) + (p_S3 - p_S2)
```

Terminology:

- `S2 - S1`: exclusion / competitive-discipline component.
- `S3 - S2`: entry-composition offset.

General framework:

```text
Delta_set-aside
  = lost competitive discipline
  + protected-entry/composition offset
```

The contribution should be framed as a transportable decomposition, not merely
as three simulated prices in one application.

Use "sheltered bidding" only as a descriptive label if retained at all. The
technical object should be the exclusion or order-statistic component.

### 3.4 Scope of the Model

State clearly:

- This is not a full entry equilibrium.
- Entry is observed equilibrium entry.
- `F_c^{SME,Post}` is estimated from post-period exits, not derived from a
  formal selection model.
- Non-pharma is the robust policy result.
- Pharma is a boundary/sensitivity case because the ranking depends on how the
  post-policy SME pool is modeled.

This honesty is protective. It makes the paper harder to attack.

To support the 9.5+ version, the model section should pre-commit to the two
most important empirical adjudications:

- entrant/incumbent and reweighting checks for the `S3 - S2` margin;
- low-coordination checks for whether drop-out bids can be read as costs.

## 4. Exclusion, Entry, and Price Formation

Target: 5 pages.

Purpose: deliver the main result.

### 4.1 Entry Responds

Show that SMEs enter after the set-aside. This rejects the simple story that the
policy raises prices because SMEs do not show up.

### 4.2 Exclusion Dominates

This is the central empirical result.

Main figure:

- Figure 2, Panel A: `S1`/`S2`/`S3` decomposition.

The visual message should be immediate:

- `S1 -> S2`: removing non-SMEs creates a large price increase.
- `S2 -> S3`: SME entry/composition offsets part of the increase.
- `S1 -> S3`: the net effect remains positive.

Main table:

- Table 3: structural decomposition.

Minimum columns:

- `p_S1`
- `p_S2`
- `p_S3`
- total effect
- exclusion component
- entry-composition offset
- exclusion/net
- absolute share

### 4.3 Entry/Composition Is Not the Main Driver

This subsection is needed for a 9.5+ paper. It should be short, but it must
directly address the weakest link in the decomposition: `S3 - S2` is not pure
entry; it includes entry and the post-policy SME cost/composition object.

Preferred checks:

- entrant vs incumbent cost distributions;
- continuing-firm pre/post comparison;
- reweighting that holds observed SME composition fixed;
- excluding new entrants;
- empirical entry-count distribution or negative-binomial arrivals instead of
  only Poisson means.

Main message:

> The exclusion component remains the dominant force even when the
> entry/composition margin is disciplined more tightly.

If this cannot be shown, keep the claim narrower: non-pharma robust, pharma
conditional.

### 4.4 Interpretation

Core sentence:

> The policy attracts SMEs, but it cannot recreate the competitive discipline
> supplied by excluded non-SMEs.

Avoid saying that SMEs "bid less aggressively" if the maintained model is
exit-at-cost. The mechanism is price formation through the second-order
statistic, not behavioral shading.

## 5. Welfare and Policy Design

Target: 6 pages.

Purpose: turn the mechanism into the JPubE policy contribution.

### 5.1 From Price Formation to Welfare

Separate the two structural objects:

- `c_(2)` determines government payment.
- `c_(1)` determines allocative efficiency.

Welfare components:

- allocative DWL;
- MCPF distortion on extra government outlay;
- transfer to SMEs, which is redistribution rather than destruction.

### 5.2 Set-Aside Welfare Cost

Use one simple expression:

```text
Loss = DWL_alloc + lambda * Delta_gov
```

Do not let this section become a long accounting exercise.

### 5.3 Set-Aside vs Price Preference

Compare only two instruments in the body:

- V0: full SME-only set-aside.
- V3: 10 percent SME price preference.

Policy mechanism:

> A price preference keeps non-SMEs inside the auction, so it preserves
> competitive discipline.

Main table:

- Table 4: V0 vs V3, with price effect, welfare loss, SME win-rate gain, and
  transfer/redistribution metrics.

Important nuance:

- V3 is low-cost but also lower-redistribution.
- V0 is high-cost and high-redistribution.
- The comparison should be framed as a policy frontier, not as "V3 achieves the
  same goal for free."

For the 9.5+ version, this should be stated as a design principle:

> Preferences preserve competition because non-protected bidders remain
> price-forming; set-asides remove them and therefore buy redistribution by
> weakening the auction.

### 5.4 Welfare Weights

Use the welfare-weight identity to discipline the distributional claim.

Main figure:

- Figure 3: implicit SME welfare weight required to prefer the set-aside.

Interpretation:

- In non-pharma, justifying the full set-aside requires a high SME welfare
  weight.
- In pharma, the ranking is conditional on the treatment of the post-policy SME
  pool.
- The paper does not claim that set-asides are universally dominated.

This is the clean way to avoid overclaim:

> V3 is a low-cost, low-redistribution instrument. V0 is a high-cost,
> high-redistribution instrument. The welfare-weight identity tells the reader
> when the extra redistribution is worth the lost competitive discipline.

### 5.5 Scope Conditions

Close the policy section with market-structure conditions:

- Thick standardized markets: price preference dominates.
- Thin heterogeneous markets: full set-aside may be defensible if the planner
  places high value on SME surplus and the induced entrants are policy-relevant.

## 6. Robustness to Core Threats

Target: 3-4 pages.

Purpose: address threats to the DAG, not display every robustness result.

### 6.1 Reduced-Form Validity

Summarize:

- balance;
- event study;
- placebos;
- BJS/CS estimators;
- alternative windows.

9.5+ target:

- matched controls, synthetic/control-weighted Group 65, or pre-trend-weighted
  controls if feasible;
- monthly event-study evidence if readable;
- robustness excluding badly imbalanced control groups.

Keep the full tables in the appendix.

### 6.2 Cost Recovery

Summarize:

- Turnbull NPMLE;
- losers-only vs all-bidders;
- UH correction;
- cross-modality check.

### 6.3 Primitive Stability and Composition

Summarize:

- strict invariance;
- entrant/incumbent turnover;
- composition-fixed reweighting or excluding new entrants;
- empirical entry-count / negative-binomial sensitivity;
- pharma sensitivity.

Language:

- Non-pharma is robust.
- Pharma is informative but conditional.

### 6.4 Coordination

Be honest and concise:

- screens detect bidder clustering;
- clustering does not appear to increase post-policy;
- low-coordination robustness should be reported if available.

9.5+ target:

- drop high-persistence bidder pairs;
- re-estimate the decomposition in low-coordination markets;
- compare high- and low-clustering cells;
- show that the exclusion component survives.

If the body needs a robustness table, use one compact summary table only.

## 7. Conclusion

Target: 1-1.5 pages.

No new numbers. No new literature. No heroic extrapolation.

Final message:

> SME support through exclusion is expensive because it removes competitive
> discipline. SME entry offsets part of the cost, but not enough. Procurement
> policy should favor instruments that support SMEs while keeping rival bidders
> inside the auction, especially in thick standardized markets.

## Main Appendix Structure

The appendix should contain only material that answers likely referee threats.

### Appendix A. Institutional Details

- Full legal timeline.
- Legal text excerpts.
- Adoption/adherence details.

### Appendix B. Reduced-Form Evidence

- Balance.
- Event study.
- Placebos.
- BJS/CS.
- Alternative windows.

### Appendix C. Cost Recovery and Structural Estimation

- Turnbull.
- UH correction.
- Cross-modality check.
- Winner censoring.
- Cost distributions.

### Appendix D. Robustness to Core Mechanism

- Strict invariance.
- Entrant/incumbent composition.
- Coordination screens.
- Entry-count sensitivity.
- Reference-price validation.

### Appendix E. Welfare Details

- Lambda grid.
- Preference grid.
- Annual scaling.

## Online Appendix / Replication Only

Move out of the main paper and main appendix:

- extensive V1/V2/V4 policy variants;
- entry-cost calibration;
- long DiD-to-structural bridge;
- full bandwidth grids;
- full filter/window grids;
- Maskin-Riley bound unless a referee demands it;
- detailed furosemide vignette arithmetic;
- macro audit tables;
- table farms.

## Page Discipline Rule

For every paragraph, table, and figure in the body, ask:

> If this is removed, does the reader lose the central DAG?

If the answer is no, remove it from the body.

For the appendix, ask:

> Does this answer a likely referee threat?

If the answer is no, move it to the online appendix or replication package.
