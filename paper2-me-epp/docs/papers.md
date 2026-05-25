---
paper: sme-public
---

# Research Agenda

This page lists the paper currently in submission preparation and a
ranked set of follow-up paper ideas that can be built using the same
underlying data (the BEC-SP centralized procurement panel 2016–2019,
with the longer registry back to 2005; Pregão event-log drop-out bids;
the March 2018 PGE-SP reinterpretation and the 2018 Decreto 9.412 cap
shift; CMED pharmaceutical price ceilings; reference prices; plus
linkages to RAIS firm/worker records and IBGE municipal panels). Each
entry includes three target-journal options with my probability
estimates of revise-and-resubmit (R&R) at each.

Probabilities are honest reviewer-style assessments; "Confirmed" is
not an option for any single-jurisdiction paper from this data lake
without cross-data replication. All probabilities assume a clean
manuscript at submission.

!!! abstract "Reading the R&R probability columns"
    R&R = invited to revise and resubmit (not Accept). Acceptance
    probability is roughly half of R&R for the listed top journals.
    "Strong fit" = my reviewer-side reading of the journal's recent
    publication mix; "Marginal fit" = stretch.

---

## 1. Current paper (in submission preparation)

### The Price of Exclusion: SME Set-Asides in Public Procurement

**Author:** Darcio Genicolo-Martins (Insper)

**Version:** v8 (May 2026, JPubE submission)
[manuscript PDF](assets/paper/paper.pdf) ·
[online appendix](assets/paper/online_appendix.pdf)

**Distinctive contributions:**

1. *A price-formation decomposition of the set-aside* — the price
   effect of an SME set-aside is split into a **lost-discipline
   component** (non-SMEs removed from the price-forming pool, SME pool
   held fixed: $S_2 - S_1$) and a **protected-pool offset** (the
   post-policy SME pool replacing the pre-policy one: $S_3 - S_2$). The
   set-aside price effect becomes a design question — how much is
   mechanical exclusion of rival bidders, and how much is the protected
   pool's response — rather than a single reduced-form number.
2. *Implementation via a reverse-auction setting* — in São Paulo's
   Pregão (descending-clock electronic reverse auction), losing
   bidders' drop-out prices reveal type-specific willingness to supply
   under the maintained independent-private-values clock interpretation
   (Vickrey 1961; Milgrom–Weber 1982; Haile–Tamer 2003). The recovered
   primitives, an auction-level heterogeneity correction in the spirit
   of Krasnokutskaya (2011), and observed equilibrium entry simulate
   counterfactual price-formation objects under three pools.
3. *A recast of policy design* — the relevant policy frontier is not
   SME support versus no support, but **exclusionary redistribution
   versus support that preserves the price-forming bidder pool**. A
   10% SME price preference enters as a static design benchmark: it
   keeps the non-SMEs that discipline the price-forming order statistic
   but delivers less redistribution than full exclusion.

In standardized non-pharmaceutical procurement, the protected pool
responds (SME participation roughly doubles) but does not replace the
excluded discipline: the full set-aside generates a **static welfare
loss of 28.9% of the open-regime price** at λ=0.30, with the exclusion
component accounting for **~72% of the absolute price decomposition**.
The implied SME welfare weight required for a planner to prefer full
exclusion to the 10% preference is **2.42**. The exclusion-dominant
ranking survives Turnbull winner-censoring (74%), strict-invariance of
the post-policy SME distribution (85%), and replacement of the Poisson
bidder-count process with the empirical class-period-type count
distribution (69%). Pharmaceutical procurement is reported as a
**boundary case**, not a second headline.

**Target journals:**

| Tier | Journal | R&R prob. | Fit rationale |
|:-:|---|:-:|---|
| 1 | **JPubE** (J. of Public Economics) | **30–40%** | The natural home: SME-preference welfare analysis with an MCPF + Saez–Stantcheva frame is JPubE-core, and the policy-frontier recast is the kind of design contribution JPubE rewards. The binding constraints are single-jurisdiction external validity and the maintained IPV-clock assumption, which JPubE referees with a structural-IO bent will press hardest. |
| 2 | **AEJ: Policy** | **35–45%** | Strong fit for the exclusionary-redistribution-vs-preference frontier and the implied-welfare-weight statistic; AEJ:Policy values clean policy-design counterfactuals tied to a real natural experiment (the March 2018 PGE-SP reversal). |
| 3 | **IJIO** (Int'l J. of Industrial Organization) | **45–55%** | More reachable empirical-IO target; the structural recovery from drop-out bids and the entry-cost asymmetry fit the procurement-auction literature there. The welfare framing is less central than at JPubE/AEJ:Policy, but the auction mechanics travel well. |

**Current submission gating constraints:**

- *Single-jurisdiction limitation* — every estimate lives in São Paulo
  BEC. A second procurement jurisdiction (federal ComprasNet, or
  another state platform) replicating the open-vs-set-aside price
  effect would push R&R toward the upper end at every tier.
- *Maintained IPV-clock assumption* — the structural decomposition
  reads Pregão drop-outs as willingness-to-supply observations
  ([H:ipv-clock-admissible](hypotheses/ipv-clock-admissible.md)). It is
  load-bearing and not testable within the data; the cross-modality GPV
  recovery from Convite first-price bids
  ([AN-019](analyses/an-019-cross-modality-gpv.md)) gives partial
  discipline, not proof.
- *Static-only welfare* — the paper measures the static price/welfare
  cost and does not credit any dynamic SME capacity-building benefit.
  Idea 2.1 below is the direct fix path.

---

## 2. Eight follow-up paper ideas using the same data

The ideas below are grouped by **overlap with the current paper**. Ideas
2.1–2.5 are the original set, ordered from highest overlap to none; Ideas
2.6–2.8 are a later batch spanning auction collusion, buyer state
capacity, and targeting incidence. Several extend the set-aside /
price-formation framework directly; the rest take the BEC + RAIS + CMED +
IBGE data lake into different research programs.

### Idea 2.1 — Do Set-Asides Build SME Capacity? The Dynamic Case for Exclusion

**Overlap with current paper:** **High** — directly answers the main
limitation of the current paper (static-only welfare), using the same
March 2018 shock and the same treated group.

**Central question:** The current paper measures only the static cost
of the set-aside. The standard defense of set-asides is dynamic: the
protected pool *grows* — SMEs that win build capacity, hire, and
eventually compete unassisted. Does the data show this? Do SMEs that
win under the set-aside expand employment, payroll, and survival
relative to comparable SMEs that do not?

**Empirical strategy:** Link BEC SME winners to RAIS firm/worker
trajectories (the linkage already built for
[AN-028](analyses/an-028-rais-validation.md)). Event-study and
Callaway–Sant'Anna designs around first set-aside win and around the
March 2018 expansion of protected demand into Group 65. Outcomes:
employment, wage bill, formal-sector survival, and subsequent unaided
(open-auction) win rates. The dynamic benefit is then compared against
the static welfare cost the current paper already quantifies.

**Data reuse:** BEC panel + RAIS linkage (already loaded), March 2018
shock. ~8–10 weeks; mostly RAIS panel assembly and event-study
pipeline.

**Target journals:**

| Tier | Journal | R&R prob. | Rationale |
|:-:|---|:-:|---|
| 1 | **J. of Public Economics** | 30–40% | Pairs naturally with the current paper as the dynamic counterpart; JPubE would value a clean static-cost-vs-dynamic-benefit ledger on one policy. Identification of the dynamic margin is the cap. |
| 2 | **AEJ: Applied Economics** | 35–45% | RAIS-based firm-growth event study is squarely AEJ:A; the procurement-as-industrial-policy framing travels. |
| 3 | **J. of Labor Economics** | 30–40% | If the worker-flow / hiring margin is the lead (set-aside wins → formal hiring), JOLE is a strong secondary fit. |

**Why this idea exists:** It converts the current paper's headline
limitation into a paper. If the dynamic benefit is small, it
strengthens the current paper's policy reading; if large, it is the
counterweight the static cost cannot see.

---

### Idea 2.2 — Optimal SME Preference Design: Solving for the Margin, Sector by Sector

**Overlap with current paper:** **Medium** — same structural machinery
(recovered primitives + BNE simulation), but pivots from evaluating one
policy to *designing* the optimal one.

**Central question:** The current paper benchmarks a *single* 10%
preference. What is the welfare-maximizing preference margin, and how
does it vary across product groups with different SME/non-SME cost gaps
and entry-cost asymmetries? Is there a sector where full exclusion is
actually optimal under a defensible welfare weight?

**Empirical strategy:** Generalize the preference benchmark from
[AN-012](analyses/an-012-preference-benchmark.md) into a margin-choice
problem. For each product cell, use the recovered type-specific cost
distributions and calibrated entry costs
([AN-030](analyses/an-030-entry-rates-cost.md)) to trace welfare as a
function of the preference margin under a λ-grid and a grid of SME
welfare weights. Map the policy frontier sector by sector.

**Data reuse:** Recovered primitives + entry costs already produced for
the current paper; new code is the optimization sweep, not new data.
~6–8 weeks.

**Target journals:**

| Tier | Journal | R&R prob. | Rationale |
|:-:|---|:-:|---|
| 1 | **AEJ: Policy** | 35–45% | Optimal-design papers with an explicit planner objective and a real institutional preference instrument are a strong AEJ:Policy fit. |
| 2 | **J. of Public Economics** | 30–40% | JPubE likes mechanism-design-meets-welfare, but would want the structural assumptions stress-tested harder than a single-paper sweep allows. |
| 3 | **IJIO** | 45–55% | The auction-design mechanics fit IJIO; weaker on the welfare/planner side. |

**Differentiator from current paper:** the current paper *evaluates*
two regimes (set-aside, 10% preference); this paper *solves* for the
optimal preference and characterizes when exclusion can be rationalized.

---

### Idea 2.3 — Procurement and Local Economic Development: Does Buying Local Pay?

**Overlap with current paper:** **Low** — same data substrate, but a
development / fiscal-federalism question and outcomes (municipal
employment), not auction welfare.

**Central question:** The current paper finds open auctions pull in
geographically distant non-SME suppliers on high-value items
([AN-003](analyses/an-003-didir-distance.md)). Flip the welfare
question: does keeping procurement *local* (which SME-only tendering
tends to do) support local employment and formal-sector activity, and
at what price premium? Is there a local-multiplier benefit that offsets
part of the static price cost?

**Empirical strategy:** Municipality × year panel. Link BEC supplier
locations (PBU and firm CEP) to RAIS municipal employment and IBGE
fiscal/demographic data. Use the March 2018 shock and the 2018 Decreto
cap shift as variation in how "local" procurement becomes. Outcomes:
local formal employment, supplier diversity (HHI of who wins),
local-supplier share, and the implied price premium for local sourcing.

**Data reuse:** BEC supplier geocoding + RAIS municipal + IBGE
(IBGE/RAIS already in the monorepo). ~10–12 weeks; new spatial /
municipal-panel pipeline.

**Target journals:**

| Tier | Journal | R&R prob. | Rationale |
|:-:|---|:-:|---|
| 1 | **J. of Economic Geography** | 50–60% | Spatial structure of public demand and local-supplier development is a perfect fit; smaller but high-impact within geography. |
| 2 | **Regional Science and Urban Economics** | 45–55% | Strong methodological fit for the local-multiplier-of-procurement question. |
| 3 | **World Development** | 40–50% | Brazilian municipal context with a clear policy lever; less competitive, values practical-policy work. |

**Differentiator:** the unit is the municipality, not the auction; the
contribution is a local-development ledger, and the auction welfare
machinery of the current paper is absent.

---

### Idea 2.4 — Reference Prices and the Anchoring of Bids in Reverse Auctions

**Overlap with current paper:** **None** — same data, a market-design
question about information rather than set-asides.

**Central question:** Every BEC tender carries a reference price
(*preço de referência*) that bidders observe. Does that anchor shape
bidding — compressing dispersion toward the reference, inviting a
winner's-curse-style overshoot, or capping competition because no one
bids far below it? Would changing reference-price disclosure raise
competition or lower prices?

**Empirical strategy:** Bid-level analysis using the normalized bid
$c_\varepsilon = b/p^{\mathrm{ref}}$ already constructed for the
structural sample. Exploit cross-cell and over-time variation in how
reference prices are set (historical vs market-survey vs CMED-anchored)
and any disclosure-rule changes. Test for bunching at the reference,
dispersion compression, and the relationship between reference-price
staleness and realized competition.

**Data reuse:** BEC bid-level + reference prices + CMED ceilings
(all in hand). ~8–10 weeks.

**Target journals:**

| Tier | Journal | R&R prob. | Rationale |
|:-:|---|:-:|---|
| 1 | **J. of Public Economics** | 30–40% | Information design in procurement is JPubE-relevant; needs a sharp source of variation in reference-price rules to clear the identification bar. |
| 2 | **AEJ: Applied Economics** | 35–45% | Bunching / anchoring evidence on real auction data is a good AEJ:A fit. |
| 3 | **Int'l J. of Industrial Organization** | 45–55% | The auction-information mechanics fit IJIO well; more reachable. |

**Differentiator:** no set-aside, no SME framing; the object is the
reference price as an information instrument in auction design.

---

### Idea 2.5 — Do Price Ceilings Bind? CMED Caps and Pharmaceutical Procurement

**Overlap with current paper:** **None** — promotes the current paper's
*boundary case* (pharmaceuticals) to the headline, with a different
(health-economics / regulation) question.

**Central question:** Pharmaceuticals in BEC are subject to CMED
federal price ceilings. Do those ceilings bind in procurement, and what
is the pass-through? Does the ceiling act as a focal point that *raises*
realized prices (a cap-as-floor effect), or does competition pull prices
well below it? The current paper treats pharma as model-sensitive and
sets it aside; this paper makes the CMED ceiling the object of study.

**Empirical strategy:** Restrict to CADMAT pharmaceutical classes
(6531, 6532, 6536, 6581) where CMED ceilings apply. Compare realized
winning prices to the binding CMED ceiling; exploit CMED ceiling
revisions over time as variation. Test for bunching at the ceiling,
cap-as-floor focal-point behavior, and heterogeneity by molecule
competition (single-source vs multi-source generics).

**Data reuse:** BEC pharma sub-sample + CMED ceiling series + the
within-Group-65 CMED split already built for
[AN-027](analyses/an-027-within-g65-cmed.md). ~8–12 weeks; main lift is
assembling the CMED ceiling panel.

**Target journals:**

| Tier | Journal | R&R prob. | Rationale |
|:-:|---|:-:|---|
| 1 | **J. of Health Economics** | 35–45% | Pharmaceutical price regulation and procurement is a JHE-core topic; the cap-as-floor question is novel for the Brazilian setting. |
| 2 | **J. of Public Economics** | 25–35% | Possible if the welfare/pass-through framing is sharp; JPubE prefers OECD pharma-pricing contexts and tighter identification. |
| 3 | **AEJ: Policy** | 30–40% | Price-ceiling design with a clear regulatory lever fits AEJ:Policy; needs a clean source of ceiling variation. |

**Differentiator:** a regulation paper about price ceilings, not a
set-aside paper; the auction-welfare decomposition is absent and the
pharmaceutical sector is the headline rather than the caveat.

---

### Idea 2.6 — Do Set-Asides Facilitate Collusion? Pool Contraction and Coordination Risk

**Overlap with current paper:** **Medium-Low** — reuses the March 2018
shock and the collusion screens already built for
[AN-015](analyses/an-015-collusion-screens.md), but asks an
IO-of-collusion question that runs orthogonal to the static welfare
decomposition.

**Central question:** A set-aside mechanically shrinks the eligible
bidder pool. The theory of collusion (fewer firms, more stable
coordination — the folk-theorem / Green–Porter logic) predicts the
contraction could *raise* collusion risk, a cost the static welfare
decomposition cannot see. Does the March 2018 pool contraction (Group 65
forced back to SME-only) raise the incidence of bid-coordination markers
among the surviving eligible SMEs?

**Original contributions to the literature:**

1. *A causal estimate of how set-asides affect collusion risk*, not just
   static competition. The set-aside literature (Marion 2007;
   Nakabayashi 2013; Reis & Cabral 2015) measures price and
   participation effects; the collusion-facilitation channel is
   theorized but, to my knowledge, never measured against a
   policy-induced change in pool size.
2. *Turns structural collusion detection into a difference-in-differences
   on coordination markers.* The detection toolkit (Bajari & Ye 2003;
   Conley & Decarolis 2016, AEJ:Micro; Kawai & Nakabayashi 2022, JPE)
   is built for fixed cross-sections; here it is applied to a clean
   structural break, so the screens identify a *change* rather than a
   level.
3. *A welfare correction to the current paper.* If exclusion raises
   coordination risk, the true cost of the set-aside exceeds the static
   decomposition — this paper supplies the previously-omitted term.

**Paper structure:**

- §1 Introduction — collusion as the omitted cost of set-asides
- §2 Setting: BEC Pregão, the eligible pool, and March 2018 as a
  structural-change experiment
- §3 Theory: pool size and the sustainability of collusion
- §4 Data and coordination markers (Conley–Decarolis co-bidding
  proximity; bid rotation; complementary/cover bidding; Bajari–Ye
  test statistics)
- §5 DiD on coordination markers: treated Group 65 (pool contracts) vs
  always-SME control groups
- §6 Robustness: secular trends in controls, entry composition, placebo
  cutoffs, and (if linkable) validation against CADE-flagged cases
- §7 Welfare: re-pricing the set-aside with the collusion-risk term

**Empirical strategy:** DiD on screen-based coordination markers around
March 2018. The treated group's eligible pool contracts; always-SME
groups do not. CADE ground truth would upgrade the markers to
conduct — feasible only if SP CADE cases link to BEC Group 65, which is
an open data question, not an assumed asset.

**Data reuse:** BEC bid-level + co-bidding network + the AN-015 screen
battery already in hand. ~10–12 weeks; main lift is the longitudinal
screen panel and the DiD layer.

**Target journals:**

| Tier | Journal | R&R prob. | Rationale |
|:-:|---|:-:|---|
| 1 | **JLEO** (J. of Law, Economics & Organization) | 30–40% | Set-aside-as-collusion-enabler is squarely L&E/organization; JLEO rewards a policy-induced structural change paired with a detection apparatus. The markers-vs-conduct gap is the cap. |
| 2 | **IJIO** | 40–50% | Empirical-IO collusion detection is core IJIO; the DiD-on-screens design is the draw and the auction mechanics travel. |
| 3 | **J. of Competition Law & Economics** | 40–50% | High fit for the antitrust-policy angle; smaller audience, more reachable. |

**Honest risk:** screens detect *markers*, not collusion. Without CADE
confirmation the headline is "coordination-marker incidence," and
referees will press the same markers-vs-conduct gap that
[AN-015](analyses/an-015-collusion-screens.md) already flags. The DiD
also inherits the control-group secular-trend problem visible in the
firm-count placebo of the current paper.

---

### Idea 2.7 — State Capacity at the Buyer Level: Which Bureaucracies Turn Competition into Savings?

**Overlap with current paper:** **Low** — same BEC panel, but the object
of study is the buyer (PBU), not the auction format; the set-aside
becomes a covariate rather than the treatment.

**Central question:** The current paper absorbs buyer heterogeneity in
PBU fixed effects. Make those fixed effects the object: how much of the
variation in prices paid for *identical* items is attributable to the
purchasing unit and the people who run it, and do high-capacity buyers
extract more of the gains from open competition? Best, Hjort & Szakonyi
(2023, AER) find 39% of price variation in Russian procurement is
bureaucrat/organization-driven; does centralized São Paulo look similar,
and does buyer capacity *interact* with the competition margin the
current paper identifies?

**Original contributions to the literature:**

1. *An item-level decomposition of procurement price variation into
   buyer vs market components*, extending Best–Hjort–Szakonyi (2023) to
   a (i) descending-clock reverse-auction, (ii) centralized-platform
   setting with (iii) a within-platform policy experiment — a different
   institutional environment from the Russian first-price setting.
2. *The interaction BHS cannot estimate*: whether buyer capacity
   *moderates* the price effect of competition — do competent buyers
   convert open auctions into savings while weak buyers leave them on
   the table? This links the state-capacity literature (Bandiera, Prat &
   Valletti 2009; Best–Hjort–Szakonyi 2023) to auction design.
3. *A policy implication orthogonal to set-asides*: if buyer capacity is
   the binding constraint, the marginal return to procurement reform is
   in *who buys*, not only in *how the tender is structured*.

**Paper structure:**

- §1 Introduction — bureaucrats vs market structure as sources of
  procurement savings
- §2 Setting: BEC centralization, PBU discretion, observable buyer
  attributes
- §3 Decomposition framework (two-way buyer/item AKM-style; mover design
  across PBU reorganizations where available)
- §4 Data: PBU panel, item-normalized prices, buyer characteristics
- §5 Variance decomposition — share of price variation attributable to
  the PBU
- §6 Interaction: buyer capacity × competition margin, using the March
  2018 variation
- §7 Policy: returns to buyer capacity vs tender-design reform

**Empirical strategy:** two-way (item × buyer) variance decomposition à
la AKM; the buyer component is identified off items purchased by many
PBUs; the headline interaction crosses buyer capacity with the
open-vs-set-aside margin.

**Data reuse:** BEC PBU panel + item normalization already in hand;
richer buyer covariates may need assembly. ~10–12 weeks.

**Target journals:**

| Tier | Journal | R&R prob. | Rationale |
|:-:|---|:-:|---|
| 1 | **JPubE** | 30–40% | State-capacity-meets-procurement is JPubE-core; the BHS extension plus the capacity×competition interaction is the contribution. Identification of the buyer component (limited cross-PBU purchasing) is the cap. |
| 2 | **AEJ: Applied Economics** | 35–45% | Variance-decomposition + capacity-interaction is a clean AEJ:A empirical paper on real administrative data. |
| 3 | **J. of Public Administration Research & Theory** | 45–55% | Framed for the public-management audience, high fit; smaller economics footprint. |

**Honest risk:** the AKM-style buyer decomposition needs enough
cross-PBU purchasing of identical items to separate buyer from item. If
BEC items are effectively PBU-specific, the buyer component is
under-identified — this feasibility check must clear *before* committing
to the design.

---

### Idea 2.8 — Leakage and Capture: Who Actually Wins the Protected Rents?

**Overlap with current paper:** **Low-Medium** — uses the RAIS linkage
(like Idea 2.1) and the set-aside frame, but asks a targeting/incidence
question: are the protected rents reaching genuinely small firms?

**Central question:** ME/EPP status in Brazil is *revenue*-based (gross
receipts thresholds), not employment-based. A firm can be a legal "small
enterprise" while being a large employer, part of a corporate group, or
a vehicle that re-bids under the classification. Using RAIS to observe
*true* firm size (employment, payroll, corporate linkage), do the rents
created by the set-aside flow to genuinely small firms, or do they leak
to firms that are "small" only on paper?

**Original contributions to the literature:**

1. *First measurement of targeting leakage in a procurement set-aside
   using an independent firm-size source* (RAIS) distinct from the
   eligibility-defining variable (declared revenue). The set-aside
   literature evaluates price and efficiency costs; the *distributional
   incidence within the protected group* is unstudied.
2. *Connects size-dependent-policy distortions* (Garicano, Lelarge &
   Van Reenen 2016, AER) *and misallocation* (Hsieh & Klenow 2009) *to
   procurement*: a revenue-threshold eligibility rule creates the same
   bunching and gaming incentives, now observable in who captures public
   demand.
3. *A sharper welfare reading of the current paper*: if a large share of
   protected rents leaks to non-target firms, the redistributive benefit
   that could justify the static cost (the implied 2.42 welfare weight)
   is overstated — the implied weight on *genuine* small firms is even
   higher.

**Paper structure:**

- §1 Introduction — a set-aside is only as good as its targeting
- §2 Institutional: ME/EPP revenue thresholds vs employment reality
- §3 Data: BEC SME winners × RAIS firm size, payroll, and corporate
  group via CNPJ-raiz linkage ([AN-028](analyses/an-028-rais-validation.md))
- §4 Leakage measurement: the true-size distribution of protected
  winners; the share of rents captured by top-employment "SMEs"
- §5 Bunching at the revenue threshold (firms managing receipts to
  retain eligibility)
- §6 Re-weighted welfare: the implied weight restricted to genuinely
  small firms
- §7 Policy: revenue- vs employment-based eligibility and anti-gaming
  design

**Empirical strategy:** link BEC SME winners to RAIS true size (the
AN-028 linkage); characterize the size distribution of protected
winners; test for revenue-threshold bunching; recompute the implied
welfare weight restricting the "benefit" to genuinely small firms.

**Data reuse:** BEC + RAIS linkage already built for
[AN-028](analyses/an-028-rais-validation.md). ~8–10 weeks.

**Target journals:**

| Tier | Journal | R&R prob. | Rationale |
|:-:|---|:-:|---|
| 1 | **JPubE** | 30–40% | Targeting/leakage of a redistributive instrument is JPubE-core; the independent-size-source design is the contribution. |
| 2 | **AEJ: Policy** | 35–45% | Eligibility-rule design plus within-group incidence is a strong AEJ:Policy fit. |
| 3 | **J. of Development Economics** | 40–50% | Brazilian SME targeting with a gaming/misallocation angle fits JDE; informality and firm-size themes travel. |

**Honest risk:** RAIS captures formal *employment*, not revenue, so
"true size" is a proxy — a genuinely small-revenue firm with many
low-wage workers could be misread as leakage. The bunching test needs
firm revenue, which BEC/RAIS may not directly observe; feasibility hinges
on whether declared revenue or a credible proxy is available. This is the
binding data constraint to resolve first.

---

## Summary: portfolio view

| Idea | Overlap | Top journal | Top R&R |
|:-:|---|---|:-:|
| Current paper | — | JPubE | 30–40% |
| 2.1 Dynamic capacity-building | High | AEJ: Applied | 35–45% |
| 2.2 Optimal preference design | Medium | AEJ: Policy | 35–45% |
| 2.3 Local economic development | Low | J. Economic Geography | 50–60% |
| 2.4 Reference-price anchoring | None | IJIO | 45–55% |
| 2.5 CMED price ceilings | None | J. Health Economics | 35–45% |
| 2.6 Set-asides and collusion | Medium-Low | IJIO | 40–50% |
| 2.7 Buyer state capacity | Low | AEJ: Applied | 35–45% |
| 2.8 Set-aside leakage/capture | Low-Medium | J. Development Economics | 40–50% |

The portfolio mixes:

- **Highest R&R targets**: J. of Economic Geography (Idea 2.3, smaller
  but high-fit), then IJIO (Idea 2.4), then AEJ:Policy / AEJ:Applied
  (Ideas 2.1, 2.2).
- **Most coherent pairing**: Idea 2.1 (dynamic capacity-building) is
  the direct counterpart to the current paper's static-only welfare and
  is the cleanest sequel.
- **Cleanest reach**: J. of Economic Geography (Idea 2.3) and the IJIO
  targets (2.2, 2.4) at ~50% with good positioning.
- **Disjoint papers** (2.4 and 2.5) avoid cannibalizing the current
  paper's contribution, at the cost of more data assembly.
- **Newest batch (2.6–2.8)**: collusion-facilitation (2.6) is the
  highest-novelty extension of the current paper's welfare frame — it
  adds a cost term the static decomposition cannot see; buyer state
  capacity (2.7) is the cleanest break into a separate literature
  (state effectiveness à la Best–Hjort–Szakonyi); leakage/capture (2.8)
  sharpens the current paper's redistribution claim using the RAIS
  linkage already in hand, and pairs naturally with Idea 2.1.

**Sequencing recommendation:** complete the current paper's R&R cycle
first; then pursue Idea 2.1 (Dynamic capacity-building) as the natural
sequel — it answers the most predictable referee question about the
current paper ("but don't set-asides build SME capacity over time?")
and reuses the RAIS linkage already in hand. Idea 2.3 (Local
development) is the clean break that uses similar data without
competing intellectually with the current paper.

---

*Last updated: 2026-05-25*
