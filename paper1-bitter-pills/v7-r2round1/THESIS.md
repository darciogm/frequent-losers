# THESIS — v7-r2round1 (locked)

This is the canonical thesis statement for v7. ROADMAP.md describes *how* to
implement v7; this file describes *what* the paper claims and *why*. Every
empirical exercise, every prose paragraph, every macro must be traceable to
a clause below. If a result, finding, or claim cannot be mapped here, it
either belongs in the Online Appendix or it should be cut.

## The single sentence

The paper provides the **first quantitative decomposition** of the
procurement cost of judicial enforcement in Brazil, using an institutional
feature unique to São Paulo since 2009 — the parallel administrative-request
channel that shares all planning constraints of court-mandated procurement
but carries no penalty for officials when delivery fails. The decomposition
identifies **three distinct channels** through which judicial pressure
generates procurement cost premiums.

## The three channels

### C1 — Demand fragmentation (dominant)

**What:** Sanctions force order shrinkage; smaller orders mechanically
forgo bulk discounts.

**Where it operates:** Across both comparison levels.

- Across-comparison (urgent vs ordinary): C1 accounts for roughly half of
  the 5.4% urgency premium on negotiated prices.
- Within-urgent (litigated vs administrative): C1 accounts for essentially
  the entire 23–30% UTG gap. Holding order quantity constant, the
  per-unit-price differential between litigated and administrative urgent
  purchases is statistically indistinguishable from zero.

**Identifying evidence:**
- Panel B mediation: log-quantity control reduces the urgency price
  premium by ~50% (across-comparison) and to ~zero (within-urgent UTG).
- Item-level event study: order quantity drops sharply after first court
  order arrives at the same item.
- Distributional evidence: administrative orders are ~3.3x the size of
  litigated orders for the same item in the same month.
- Bulk-discount elasticity (-0.34) applied to the log-quantity gap (1.34)
  mechanically over-explains the 30% UTG gap.

**Magnitude of the contribution:** ~2.4 percentage points of the 5.4%
urgent premium AND the entirety of the 23–30% UTG gap.

**Statistical robustness:** Robust across specifications, FE structures,
and within-item × within-month tests.

### C2 — Demand-side per-unit residual (urgency-induced)

**What:** Officials accept worse unit prices under time pressure even at
identical order size — compressed search, reduced bargaining capacity,
truncated reference-price research.

**Where it operates:** Across-comparison only (urgent-vs-ordinary
residual after quantity control). Does NOT survive the within-urgent
UTG comparison after quantity control.

**Identifying evidence:**
- Panel B mediation residual: ~3.0% urgency premium remaining after
  controlling for log quantity. Marginally significant ($p < 0.10$).
- Reference-price residual (NEW in v7, T2.1): reference prices set BEFORE
  bidding cannot reflect supplier markup, so a residual urgency premium
  in reference prices isolates pure demand-side. Expected positive and
  marginally significant.
- Search-cost proxy (NEW in v7, T2.4): mean bids per participating firm
  per tender drops under urgency, consistent with truncated officials'
  search.
- Deadline intensity heterogeneity (NEW in v7, T2.3): the residual
  per-unit demand-side premium is larger for shorter delivery deadlines.

**Magnitude of the contribution:** ~3.0% residual on top of the
fragmentation channel; only operates across-comparison.

**Statistical robustness:** Marginal in baseline; T2.1 (reference prices)
expected to confirm; T2.3 (deadline) expected to deliver direct
mechanism-by-variation evidence.

### C3 — Supply-side within-firm markup (conditional)

**What:** The same supplier charges the same buyer more for the same item
under urgency than under ordinary procurement, exploiting the government's
reduced outside option when judicial deadlines bind.

**Where it operates:** Across-comparison (urgent-vs-ordinary, within-firm).

**Identifying evidence:**
- Supplier-FE decomposition: adding firm fixed effects to the urgent
  baseline reduces the coefficient by 52% (from 5.3% to 2.5%). The
  within-firm residual of 2.5% is the supply-side markup, but is
  statistically not distinguishable from zero in the global sample.
- Within firm-buyer-item triple regression (NEW in v7, T3.3): tightest
  possible test — same firm, same buyer, same item, different urgency
  status.
- Market-concentration heterogeneity (NEW in v7, T3.1): expected to show
  that C3 is positive and significant in concentrated markets (where
  firms have power to extract rents) and zero in competitive markets.

**Magnitude of the contribution:** ~2.5% within-firm markup globally;
expected larger in concentrated subsamples.

**Statistical robustness:** n.s. globally; conditional-on-concentration
is the publishable form. Honest reporting required: paper acknowledges
that the global C3 result is suggestive, not confirmed, and that T3.1
heterogeneity is the load-bearing test.

## The umbrella concept

All three channels are "under the gun" — they all reflect cost premiums
that arise because procurement is conducted under judicial deadlines
and personal-sanction exposure. The paper's contribution is to
**decompose** this umbrella, not to claim that any single sanction-effect
on per-unit price is identified causally.

## What the paper explicitly does NOT claim

- **No structural counterfactual.** The 23–30% UTG gap is NOT the price
  reduction we would observe if we removed sanctions while holding
  urgency constant. That object is unidentified because the
  administrative subsample is itself selected (scientific committee
  filter on cost-effectiveness criteria).
- **No causal sanction-on-per-unit-price effect.** Holding quantity
  constant, the litigated-vs-administrative gap is statistically zero.
  We cannot, with these data, separate the per-unit-price effect of
  personal sanctions from the per-unit-price effect of urgency in
  general.
- **No claim that sanctions cause fragmentation directly.** What we
  show is a correlation between sanction exposure and order size,
  conditional on item and time. The mechanism (sanctions → desperation
  → small orders) is plausible from institutional knowledge, but our
  identification cannot rule out alternative mediators (e.g., budget
  constraints differ by purchase type; patient-side characteristics
  affect both order size and procurement channel).
- **No claim of dose-response monotonicity.** v6 prose claimed a
  monotonic-then-plateau pattern over court-orders-per-item-year that
  v6 numbers (6.8% / 12.4% / 10.5%) do not support. v7 drops this from
  the main text. A footnote points to the saturating dose-response in
  Online Appendix.

## Magnitudes (from v6 macros, locked at the time of writing this thesis)

These are the numerical anchors on which v7 prose builds. They come from
the regenerated v6 pipeline and are reproduced exactly in v7 unless v7
adds new specifications.

| Macro | Value | Source |
|---|---|---|
| `\BPnegPctHeadline` | 5.4% | tab_neg_prices col 3 (urgent vs ord, item+year+PBU) |
| `\BPfirmsPctHeadline` | -5.4% | tab_firms col 3 |
| `\BPsuccessPP` | 2.1 pp | tab_success col 3 |
| `\BPrefPctPreferred` | 2.7% | tab_ref_prices col 3 |
| `\BPnegPanelBpct` | 3.0% | tab_neg_prices Panel B col 3 (residual after qty) |
| `\BPnegPanelBqty` | -0.392 | log-qty coef in Panel B col 3 (bulk-discount elasticity-like) |
| `\BPutgPct` | 30.0% | tab_underthegun Panel A col 3 |
| `\BPutgPctItemYM` | 30.4% | tab_underthegun Panel A col 4 |
| `\BPutgPctRange` | 23–30% | sweep over 4 specs (col 1-4) |
| `\BPutgPanelBcoef` | 0.117 | tab_underthegun Panel B col 3 (n.s. after qty) |
| `\BPutgPanelBSE` | 0.122 | SE of above |
| `\BPutgQtyAdminCoefPref` | 1.203 | qty ~ is_admin, item+year+PBU |
| `\BPutgQtyAdminFoldPref` | 3.3 | e^1.203 |
| `\BPbulkElast` | -0.34 | bulk-discount elasticity from Panel B |
| `\BPqtyGapAdmLit` | 1.34 | mean log-qty gap admin vs lit |
| `\BPqtyImpliedPct` | 58% | mechanical price gap from qty channel alone |
| `\BPsupBaselinePct` | 5.3% | baseline urgency price premium (without firm FE) |
| `\BPsupFirmFE` | 0.025 | residual after firm FE |
| `\BPsupFirmFEAttn` | 52% | percent attenuation from baseline to firm FE |
| `\BPsupFirmFEqty` | 0.011 | residual after firm FE + log qty |
| `\BPsupFirmsBothShare` | 92% | share of urgent winners that also serve ordinary |

## New macros to be emitted in Wave 0

These quantify the welfare bounds, the policy counterfactuals, and the
calibration anchors that the v7 prose needs.

| Macro | What it captures | Producing script |
|---|---|---|
| `\BPwelfareBoundLow` | $5.4\% \times \$300\text{M} \approx \$16\text{M}$ | 30_referee_analyses |
| `\BPwelfareBoundHigh` | UTG-pct × sanction-exposed base ($69-90M range) | 30_referee_analyses |
| `\BPwelfareBoundRange` | "16–90" string for prose | 30_referee_analyses |
| `\BPpolicyAdminRecoveryHigh` | UTG-pct × admin-eligible-share × \$300M | 30_referee_analyses |
| `\BPpolicyFrameworkRecovery` | ~half-fragmentation × feasible-items-share × \$300M | 30_referee_analyses |
| `\BPbpvBaseline` | Bandiera-Prat-Valletti (2009) reference dispersion (10–20%) | manual narrative |
| `\BPbhsBaseline` | Best-Hjort-Szakonyi (2023 QJE) within-buyer dispersion in Russia | manual narrative |

## New macros for the three-channel decomposition (Wave 1, T4.1 + T4.2)

| Macro | What it captures |
|---|---|
| `\BPchanQtyUrgent` | C1 contribution to urgent-vs-ord premium (pp) |
| `\BPchanFirmSelUrgent` | C3 selection contribution (pp) |
| `\BPchanResidualUrgent` | residual after C1 + C3 (pp) |
| `\BPchanQtyUTG` | C1 contribution to UTG gap (pp) |
| `\BPchanResidualUTG` | residual after C1 in UTG (pp) |

## New macros for per-channel positive evidence (Wave 1)

| Macro | What it captures | Producing script |
|---|---|---|
| `\BPrefPanelBcoef` | Reference-price Panel B residual (T2.1) | 03_main_regressions or 30 |
| `\BPrefPanelBpct` | Same as percentage | 03_main_regressions or 30 |
| `\BPfirmsPanelBcoef` | Firms-count Panel B residual (T2.2) | 03_main_regressions or 30 |
| `\BPsearchBidsPerFirmUrgent` | Mean bids per firm in urgent tenders (T2.4) | 30 |
| `\BPsearchBidsPerFirmOrdinary` | Same in ordinary | 30 |
| `\BPeventQtyDropFirstOrder` | Quantity drop magnitude after first court order (T1.4) | 31_honest_did extension |

## New macros for heterogeneity tests (Wave 2)

| Macro | What it captures | Producing script |
|---|---|---|
| `\BPdeadlineShortPct` | Demand-side residual under short deadlines (1-3 days, T2.3) | 30 or new 36_deadline |
| `\BPdeadlineLongPct` | Same under long deadlines (7-10 days) | 30 or new 36_deadline |
| `\BPconcentrationHighSupFE` | Within-firm markup in concentrated markets (T3.1) | 30 or new 37_concentration |
| `\BPconcentrationLowSupFE` | Same in competitive markets | 30 or new 37_concentration |
| `\BPtripleFirmBuyerItemCoef` | Within firm-buyer-item triple coefficient (T3.3) | 20_falsification extension |

## What changes vs v6

- v6's "demand fragmentation" framing applied uniformly to both
  comparison levels (urgent-vs-ord AND lit-vs-admin) is **factually
  imprecise**. v7 splits: fragmentation explains ~50% of urgent-vs-ord
  AND ~100% of lit-vs-admin within urgent.
- v6's prose suggested that controlling for quantity isolates the
  "sanction-on-per-unit-price" effect. v7 acknowledges that within UTG
  this effect is statistically zero, and the across-comparison residual
  (3%) is urgency-induced (not specifically sanction-induced).
- v6's monotonic-then-plateau dose-response claim is dropped from main
  text in v7 (footnote only).
- v6's $16-18M point estimate of fiscal cost is replaced by the
  $16-90M welfare bound in v7.
- v6's policy paragraph is qualitative; v7 quantifies admin-expansion
  and framework-agreements counterfactuals.
- v6's Figure 0 (`fig_08_coefplot.pdf`) is replaced by F.1 — three-channel
  cascade decomposition figure.
- v6 has 5 hedges of the form "we read this as descriptive decomposition";
  v7 has one declaration in the intro and zero hedges in Results / Conclusion.

## Cross-reference to ROADMAP.md

ROADMAP.md is the implementation plan; THESIS.md is the constitution.
If they conflict, THESIS.md wins. ROADMAP.md may be revised as work
proceeds; THESIS.md is locked at the start of v7 and changes only by
explicit revision.
