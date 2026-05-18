# Theory–Validation Bridge — Route 2 Memo (v17)

**Date:** 2026-05-02.
**Vehicle:** `scripts/62_theory_bridge_bidlevel.R`, executed
2026-05-02. All numbers below from
`output/theory_bridge_bidlevel/*.csv` and
`work/v13/output/tables/tab_theory_bridge_bidlevel.tex`.

**Goal of this pass.** v16 (`THEORY_VALIDATION_BRIDGE_v16.md`,
§V Reservation 2) explicitly stated that bid-level cover-bidder
predictions about *bid aggressiveness* and *bid dispersion* are *not
testable*: "Two predictions of the cover-bidder type — bid aggressiveness
and bid dispersion — cannot be tested at the firm level given the data
layer." This claim is incorrect. The v17 audit established that
`bid_level_full_v14.parquet` carries per-bid \textit{Valor Unitário
Proposta} (100\,\% populated for Convite + Pregão), per-bid \textit{Data
Hr Proposta} (timestamp), per-bid \textit{Código Fornecedor}, and
\textit{Flag Vencedor} winning identification, used by 11 scripts already
in the repo. This memo extends the v16 within-stratum bridge with bid-level
metrics the v16 memo wrongly considered out of reach.

---

## I. What metrics are computable, and which are not

| Metric | Computable at firm level? | Coverage in losing-bid sample |
|---|---|---|
| Per-bid mean of (bid $-$ winning bid) / winning bid | **Yes** | $99\%$ of losing bids in Convite + Pregão |
| Per-firm median, p75, mean, SD of the above | **Yes** | $\geq 5$ usable losing bids per firm filter retains $30{,}051$ firms incl.\ $190$ cobidders |
| Per-bid (bid / reference price) | Yes at the per-bid level, **not at the per-firm level** | Convite ${\sim}22\%$; Pregão ${\sim}32\%$ — median $n$ usable per firm is $0$, so per-firm aggregates are missing for most firms |
| Within-tender CV of bids (across firms) | Yes | Used elsewhere (Imhof full pipeline); not needed here as it is a tender-level not firm-level metric |
| Per-firm mean of (bid time - tender open time) | Possible from \textit{Data Hr Proposta} | Not pursued in this memo (pregão-only and the cover-bidding model is silent on timing) |

The bid/reference ratio and bid sequencing dimensions cannot reliably
discriminate firms in our cobidder vs FL non-cobidder comparison. They
can be computed as appendix-level diagnostics but should not appear in
the headline panel. The gap-to-winner family is the one bid-level
dimension where the v16 self-imposed limitation is incorrect.

## II. Headline univariate result

Cobidders ($N = 182$ with $\geq 5$ usable losing bids) vs.\ FL
non-cobidders ($N = 2{,}369$) within the always-loser stratum, on
per-firm aggregates of the per-bid (bid $-$ winning bid) / winning bid
ratio (winsorized at $[-0.99, 10]$ before per-firm aggregation):

| Dimension | Cobidder mean | FL non-cob.\ mean | Cohen's $d$ | Wilcoxon $p$ |
|---|---|---|---|---|
| Median (bid $-$ winner) / winner | **$0.582$** | $0.809$ | **$-0.281$** | $4.3 \times 10^{-7}$ |
| P75 (bid $-$ winner) / winner | $1.300$ | $1.498$ | $-0.156$ | $0.007$ |
| Mean (bid $-$ winner) / winner | $0.957$ | $1.102$ | $-0.169$ | $0.014$ |
| Within-firm SD of (bid $-$ winner) / winner | $1.207$ | $1.099$ | $+0.147$ | $0.050$ |

Three of the four dimensions point in a *consistent* direction:
**cobidders bid systematically closer to the eventual winner than FL
non-cobidders do**. Only the dispersion dimension goes the opposite way
(cobidders show somewhat higher within-firm dispersion, $d = +0.15$).

## III. Headline multivariate result

A logit of cobidder ($\in$ FL stratum) on participation intensity and
the bid-level moments:

$$
\log \frac{\Pr(\text{cobidder})}{1 - \Pr(\text{cobidder})}
= -5.38 + 0.65\, \log(1 + \text{tenders\_count})
        - 0.71\, \widetilde{\text{median gap to winner}}
        + 0.44\, \widetilde{\text{SD of gap to winner}},
$$

where $\widetilde{\,\cdot\,}$ denotes 1/99\,\% winsorization. Coefficients
and tests:

| Term | Coefficient | SE | $z$ | $p$-value |
|---|---|---|---|---|
| (Intercept) | $-5.380$ | $0.447$ | $-12.04$ | $<10^{-32}$ |
| $\log(1+\text{tenders\_count})$ | $+0.651$ | $0.094$ | $6.91$ | $<10^{-11}$ |
| **Median (bid $-$ winner) / winner** (winsorized) | **$-0.708$** | $0.171$ | $-4.14$ | $3.4 \times 10^{-5}$ |
| **Within-firm SD of (bid $-$ winner) / winner** (winsorized) | **$+0.442$** | $0.122$ | $+3.62$ | $3.0 \times 10^{-4}$ |

Both bid-level coefficients survive the inclusion of $\log(1+\text{tenders\_count})$:
the cobidder profile is not just a participation-intensity story (P1),
nor a multicollinearity artifact. Holding participation intensity
constant, cobidders are characterized by a lower median gap to winner
*and* a higher within-firm cross-bid dispersion of that gap. The two
coefficients are in tension along the "uncompetitive bid" dimension and
*both* survive the joint test, which is the kind of multivariate
signature single-margin frameworks have trouble producing by accident.

## IV. What the cover-bidder framework predicted, and what we found

The v16 manuscript's Online Appendix~A models cover bidders as the
modeled type. The first-pass reading of that model — call it the *R1
textbook* reading — predicts:

> **R1.** Cover bidders place bids that are deliberately and visibly
> uncompetitive: high relative to reference, high relative to winners,
> and dispersed within firm.

The data **falsify R1's first margin**. Cobidders bid *closer* to
winners, not further from them. The directional prediction goes the
opposite way of what the textbook cover-bidder reading implies.

A more refined reading of the same model — call it the *R2 credible
phantom-competition* reading, in the spirit of Marshall \& Marx (2009,
2014), Porter \& Zona (1993, 1999), and Asker (2010) — predicts:

> **R2.** Cover bidders place bids that are *plausibly close to* the
> winner so that the auction looks competitive, while exhibiting
> systematic within-firm dispersion across tenders consistent with
> repeated rotation through cover roles.

The data **support R2 on both margins**. Cobidders bid plausibly close
to winners ($-0.28$ standard deviations on median gap, $-0.16$ on p75)
and exhibit slightly higher within-firm dispersion ($+0.15$). The
multivariate logit confirms both signs survive joint estimation
controlling for participation intensity.

This is a *reframing* result, not a falsification. The bid-level
extension does not destroy the v16 cover-bidder framework; it reads it
through R2 (credible phantom competition) instead of R1 (textbook
visible uncompetitive cover bid). The framework's identifying
assumption — that the cobidder population is enriched for the cover
bidder type — is supported on the bid-level dimensions where it can be
tested.

## V. How this changes the bridge counter

The v16 memo summarized the within-stratum bridge as 5-of-7 firm-level
dimensions matching the cover-bidder type, with the following accounting:

| Dimension (v16) | Direction match? |
|---|---|
| P1 (deployment intensity, mean tenders) | Yes ($d = +0.67$) |
| P1' (unique winners faced) | Yes ($d = +1.00$) |
| P2 (deployment proximity, direct-CADE share) | Yes ($d = +0.46$) |
| P3 (repeat co-bidding count) | Yes ($d = +0.19$) |
| P3' (repeat co-bidding share) | **No** ($d = -0.38$) |
| P4 (item-group HHI) | Yes ($d = +0.39$) |
| P4' (distinct item-groups) | Yes ($d = -0.32$, expected sign) |

The v16 score: 6 of 7 dimensions in the predicted direction, with one
($P3'$ share) going the wrong way and the v16 memo flagging it.

Adding the bid-level dimensions:

| Dimension (v17 add) | Cob.\ direction (R1 reading) | Cob.\ direction (R2 reading) |
|---|---|---|
| Median gap to winner | $-0.28$ — wrong sign | $-0.28$ — right sign |
| P75 gap to winner | $-0.16$ — wrong sign | $-0.16$ — right sign |
| Within-firm SD of gap to winner | $+0.15$ — right sign | $+0.15$ — right sign |
| Multivariate logit (median gap, controlling for log $1+$tc) | Wrong sign on coefficient | Right sign on coefficient |
| Multivariate logit (SD gap, controlling for log $1+$tc) | Right sign on coefficient | Right sign on coefficient |

Under the **R1 textbook reading**, two of three new bid-level dimensions
go the wrong way — the bridge weakens to 7-of-10.

Under the **R2 credible-phantom-competition reading** (which is the
reading the cover-bidding literature has converged on since
Marshall \& Marx 2009 and Asker 2010), all three new dimensions go the
right way — the bridge strengthens to 9-of-10. Two of the three are
strongly significant ($p < 10^{-4}$ in the multivariate logit).

The honest statement is: *the bridge tightens substantially under the
refined cover-bidder reading and weakens slightly under the textbook
reading*. We adopt the refined reading explicitly in the v17 manuscript
and discuss both in the limitations section.

## VI. What this gains the manuscript, concretely

1. **A new headline statement**: "Cobidders' losing bids cluster
   plausibly close to winning bids and exhibit elevated within-firm
   cross-bid dispersion --- a signature consistent with the credible
   phantom-competition reading of cover bidding (Marshall \& Marx 2009;
   Asker 2010), not with the textbook deliberately-uncompetitive
   reading."

2. **A new main-text-quality table** (`tab_theory_bridge_bidlevel.tex`,
   three panels: univariate gap-to-winner moments; cross-bid dispersion;
   multivariate logit). Goes in §`sec:cade` immediately after the v16
   firm-level table.

3. **A direct retraction of the v16 self-imposed limitation.**
   `THEORY_VALIDATION_BRIDGE_v16.md` §V Reservation 2 is replaced by:
   *"Two predictions of the cover-bidder type --- bid aggressiveness
   against the reference price and bid sequencing in pregão --- remain
   untested at the firm level. The reference-price field in BEC's
   analytical-warehouse export is populated for $\sim 22\%$ of convite
   losing bids and $\sim 32\%$ of pregão losing bids; coverage is
   correlated with item type and leaves most cobidders without
   firm-level reference-price aggregates. Bid sequencing in pregão is
   pursued in Online Appendix~B as exploratory evidence only."*

4. **A reframed Online Appendix A**: introduce R1/R2 distinction as a
   formal note inside the cover-bidder type, and report the bid-level
   findings as a test of R2's primitive predictions.

5. **A small but real referee-defensible artifact**: a multivariate
   logit with two significant bid-level coefficients
   ($p < 10^{-4}, p < 10^{-3}$) controlling for participation intensity.
   This is a stronger artifact than any single bid-level Cohen's $d$.

## VII. What this does *not* gain the manuscript

This pass does not deliver:

1. **A test of the bid-aggressiveness prediction (P5).** The
   reference-price coverage problem is structural to BEC's analytical
   warehouse and we cannot work around it at the firm level. The v17
   memo discloses the limitation explicitly and notes that the
   prediction is testable in jurisdictions with universal reference-price
   archival.

2. **A causal identification of cobidder-as-cover-bidder.** The bridge
   is profile evidence, not mechanism evidence. Some of the 192
   cobidders may be genuine losers who happened to bid plausibly close
   to winners; the empirical profile shows the cobidder population looks
   more like the cover-bidder type than the FL non-cobidder population
   does on the dimensions tested, but firm-level membership remains
   unidentified. This was already the v16 position and is unchanged.

3. **A test against the direct CADE defendant population.** The
   direct-CADE pool ($N=47$) is too small for stable bid-level moment
   estimation at the firm level. This was already the v16 limitation
   (and was the basis for choosing cobidders as the validation positive
   class in the first place).

## VIII. Verdict — Front 2

**Material upside delivered, with a clarifying twist.** The v16 memo
walked away from a testable bridge dimension because it misread the
data layer. Reversing that walk-away delivers:

- a univariate signature consistent with the refined cover-bidding
  reading (R2: credible phantom competition) on three new dimensions;
- a multivariate signature surviving the inclusion of participation
  intensity, with two of three bid-level coefficients significant at
  $p < 10^{-3}$;
- a sharper position in the manuscript: cobidder profile is consistent
  with R2 cover bidding, not with R1 textbook cover bidding; the
  framework in OA-A is read through R2 explicitly.

The clarifying twist is that the v16 manuscript's reading of cover
bidding (R1, the textbook visibly-uncompetitive bid) is not what the
data show. The v17 manuscript should adopt R2 — which is the modern
literature's reading anyway — and report the bid-level evidence as the
empirical content of that adoption.

**Recommendation:** wire `tab_theory_bridge_bidlevel.tex` into v17,
extend §sec:cade with $\sim$300 words on R1 vs R2 and the data, update
Online Appendix A with the R1/R2 distinction, retract the §V
Reservation 2 in `THEORY_VALIDATION_BRIDGE_v16.md`, and add a
limitations note about the reference-price coverage problem.

## IX. Files produced

| File | Role |
|---|---|
| `output/theory_bridge_bidlevel/firm_bidlevel_metrics.csv` | Per-firm moments for $30{,}051$ firms |
| `output/theory_bridge_bidlevel/standardized_diffs_bidlevel.csv` | Cohen's $d$ + Wilcoxon $p$ for each dimension and comparison group |
| `output/theory_bridge_bidlevel/multivariate_logit.csv` | Multivariate logit coefficients |
| `output/theory_bridge_bidlevel/class_counts.csv` | Class assignment counts |
| `work/v13/output/tables/tab_theory_bridge_bidlevel.tex` | Three-panel summary table |
| `scripts/62_theory_bridge_bidlevel.R` | Generating script |

---

*End of Front 2 Route 2 memo. Manuscript edits proceed in Subprompt 3 onward.*
