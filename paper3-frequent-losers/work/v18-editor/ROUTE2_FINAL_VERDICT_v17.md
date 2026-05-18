# Route 2 Final Verdict — v17

**Date:** 2026-05-02.
**Vehicle:** v17 manuscript (`paper_v17editor.pdf`, 60 pp) +
online appendix (`paper_v17editor_online_appendix.pdf`, 22 pp);
implementation summary in `ROUTE2_IMPLEMENTATION_SUMMARY_v17.md`.
**Reviewer:** mr-frequent (modo revisor) — same hat as Subprompts 0–4.

The final-verdict memo answers the four required questions. It
follows the honesty rule: where gains are real but modest, that is
what is reported; where they are material, that is what is
reported; nothing is faked.

---

## I. Did Route 2 materially improve the paper?

**Yes, partially — bordering on materially, on the strength of one
front.**

Three fronts; one materially improved (architecture / observability),
one substantively improved with a clarifying twist (theory bridge),
one modestly improved (sign-reversal segment). Each contributes
defensible new evidence; none of them, on its own, would change a
referee's editorial recommendation. Together with the mandatory
disclosure cleanup, they meaningfully sharpen the paper at exactly
the dimensions a competent JLEO referee will press hardest on:

1. *"What does the construct actually need to deploy, and what does
   the comparison with bid-distribution methods actually show?"* —
   answered by the gatekeeper analysis and the operational/
   forensic-recoverable distinction.
2. *"Are cobidders really the modeled type, or just a label of
   convenience?"* — answered (or at least tightened) by the
   bid-level signature consistent with credible cover bidding.
3. *"Why does the sign reversal happen, and is it interpretable?"* —
   answered by the segment-level decomposition (Q4 broad positive
   robust to spec; Q1–Q3 broad negative robust to spec; trim
   sensitivity forecloses the few-cell-artifact reading).

The factual risk identified in Subprompt 1 (the "bid microdata
unavailable" framing was at odds with what the team itself ran) is
fully closed. That alone is a non-cosmetic improvement.

The honest call is **partially material**. The paper is sharper on
its three weakest fronts; it is not transformed.

## II. Front-by-front assessment

### II.1. Sign reversal — modest substantive gain, demoted not embellished

The v16 memo had the headline result: the sign reversal is a
reweighting phenomenon, not an overlap-dropping phenomenon (1.06\,\%
of treated items strictly dropped under overlap; the rest is
ATT-weighting). Subprompt 2 added two new facts:

- *Segment-level decomposition.* In tender-value Q4 (where
  deployment value is most plausible \emph{a priori}), the
  coefficient is $+0.046$ and survives all three of broad,
  overlap-unweighted, and overlap-ATT-weighted specifications. In
  Q1–Q3 the coefficient is $-0.05$ to $-0.06$ across all three
  specifications. The aggregate broad positive of $+0.064$ and the
  aggregate ATT-weighted negative of $-0.097$ are population
  averages of these four within-quintile estimates under different
  weighting schemes.
- *Trim sensitivity.* Removing the 1\,\%, 5\,\%, 10\,\%, 25\,\%, or
  50\,\% most heavily ATT-weighted cells \emph{strengthens} the
  negative ATT estimate, from $-0.097$ at no trim to $-0.118$ at the
  top decile trim. The reversal is structural across the bulk of
  the overlap sample, not a few-cell artifact.

The first finding is a genuine new headline; the second forecloses an
otherwise-natural referee critique. Neither identifies the
generating process behind the negative ATT-weighted estimate. The
v17 manuscript treats them as the cleanest empirical reading of the
design dependence, with the screening-value-as-diagnostic
interpretation explicitly demoted.

**Front 1 verdict: modest material gain. Sign-reversal interpretation
is now narrower and more defensible, with one new headline (Q4
robust positive) and one referee-critique block (trim sensitivity).
Not a breakthrough.**

### II.2. Theory–validation bridge — substantive gain with clarifying twist

The v16 memo declared bid-level cover-bidder predictions
*untestable*. They are not: `bid_level_full_v14.parquet` has
per-bid `Valor Unitário Proposta` populated for $100\,\%$ of
Convite + Pregão losing bids and `Flag Vencedor` populated for
$94\,\%$. Subprompt 2 extended the within-stratum bridge along the
gap-to-winner family:

- Cobidders' median gap to the winning bid is $0.582$ vs.\ $0.809$
  for FL non-cobidders ($d=-0.28$, $p<10^{-6}$).
- Their within-firm dispersion of that gap is elevated
  ($d=+0.15$, $p=0.05$).
- A multivariate logit holding $\log(1+\text{tenders\_count})$
  constant returns coefficients on median gap of $-0.71$
  ($z=-4.14$, $p<10^{-4}$) and on within-firm SD of $+0.44$
  ($z=+3.62$, $p<10^{-3}$). Both bid-level signs survive the
  inclusion of participation intensity.

**The signs do not match the textbook reading of cover bidding** (R1:
deliberately uncompetitive bid). They match the credible-cover-
bidding reading (R2: bid plausibly close to winner, cycle through
cover roles across tenders) — which is the modern literature's
reading anyway (Marshall \& Marx 2009, 2014; Asker 2010; Porter \&
Zona 1993). The v17 manuscript adopts R2 explicitly in
$\S$\ref{sec:cade_bridge_bidlevel}, retracting the v16
self-imposed limitation.

This is the most substantive single gain of the three fronts. The
bridge tightens from "4-of-5 firm-level dimensions match" (v16) to
"7-of-9 dimensions match under R2 reading, including two of three
where the multivariate logit confirms significance after
participation control" (v17). The cost is one explicit theoretical
move (R1→R2 framing); that cost is pure upside because R2 is the
literature's settled reading.

**Front 2 verdict: substantive material gain. The bridge is
meaningfully tighter, and the manuscript no longer leans on a
self-imposed data limitation that was empirically false. The
cost-of-overhaul is small (one R1→R2 paragraph in
$\S$\ref{sec:cade_bridge_bidlevel} and a brief note in OA-A which we
have not yet rewritten — flagged for follow-on).**

### II.3. Architecture / complementarity — material gain (the strongest of the three)

This is where the repository's bid-level data did the most work.
The v16 manuscript already had the AUC numbers (FL 0.881 vs.\ Imhof
full 0.846 same-sample; combined $0.942$, $\Delta=+0.096$, DeLong
$p<10^{-25}$); they were just hedged. Subprompt 3 added:

- *Sequential gatekeeper analysis* (`scripts/63_architecture_gatekeeper.R`):
  a Stage-1 FL screen narrows the bid-microdata interrogation to
  $K_1=2{,}000$ firms; Stage-2 Imhof full re-ranks within that pool.
  At top-$1{,}000$ flags, the sequential pipeline captures
  $131/193$ cobidders (recall $0.679$) while requiring bid microdata
  for $2{,}000$ firms — an $83\,\%$ reduction in bid-microdata
  footprint at an $8\,\%$ recall cost relative to joint single-model
  scoring on the full $11{,}676$-firm pool.
- *Operational/forensic-recoverable observability distinction* now
  threading through the abstract, intro, $\S$\ref{sec:institutional},
  $\S$\ref{sec:forensic}, and conclusion. The disclosure footnote in
  $\S$\ref{sec:emp_estimand} states explicitly that the team obtained
  the LANCES export through administrative request for evaluation
  purposes; the screening object is built around the layer audit
  courts can deploy without that cost.

The factual risk that the v16 manuscript was running comparisons on
data it elsewhere claimed didn't exist is closed. The architecture
story now reads as an operational two-stage protocol with numbers
attached, not a methodological aspiration. The headline statement —
*"comparable recall at $\approx 17\,\%$ of the bid-microdata
footprint of joint scoring"* — is short, factual, and directly
referee-defensible.

**Front 3 verdict: material gain. This is now the strongest single
contribution of the paper. The architecture/complementarity story
moved from $\S$8 of the manuscript (where it was hedged into
something forgettable) to a content area that anchors $\S$1 and
$\S$\ref{sec:forensic} with specific numbers and a forced
disclosure of the data layer the team actually used.**

## III. Did `bitter-pills/` materially change the project's ceiling?

**Yes — for two reasons, one defensive, one offensive.**

*Defensive:* the bid-level data in `bid_level_full_v14.parquet`
(80 columns, 100\,\% per-bid price coverage in Convite + Pregão)
make the v16 "bid microdata unavailable" framing factually
incorrect. A competent JLEO referee can find this in 30 minutes.
Without the v17 disclosure cleanup, the manuscript would have read
as either inconsistent or quietly evasive. The repository's data
*forced* the reframe; not making it would have been a ceiling-cap
the paper could not have escaped.

*Offensive:* the same data permitted the gatekeeper analysis
(Front 3) and the bid-level extension of the within-stratum bridge
(Front 2). Both are non-trivial editorial assets that v16 did not
deliver. The repository did not just expose a risk; it supplied
the evidence to convert that risk into the paper's strongest two
fronts.

The ceiling moved up by approximately the gap between "paper that
would be caught by a careful referee on a factual disclosure issue"
and "paper that cleanly anchors its strongest contribution on
data-envelope economics with a sequential operational test." That
gap is real but not transformational.

## IV. Best honest editorial expectation for v17

**Improved odds of favorable major R\&R, conditional on JLEO referee
draw.** Concretely:

| Outcome | Pre-v16 | v16 (acceptance push complete) | v17 (Route 2 complete) |
|---|---|---|---|
| Outright reject (R) | $\sim 60\,\%$ | $\sim 50\,\%$ | $\sim 35\,\%$--$40\,\%$ |
| Reject + encourage resubmission as new ms (RnR) | $\sim 15\,\%$ | $\sim 20\,\%$ | $\sim 20\,\%$ |
| Major R\&R | $\sim 20\,\%$ | $\sim 25\,\%$ | $\sim 35\,\%$--$40\,\%$ |
| Conditional accept / minor R\&R | $\sim 5\,\%$ | $\sim 5\,\%$ | $\sim 5\,\%$ |

The improvement is concentrated at the major-R\&R margin: the v17
manuscript reads as a clean architectural contribution with a
defensible empirical apparatus, the kind of paper a JLEO referee
will spend 90 minutes on rather than 25, and one that the editor
can plausibly send back rather than reject outright.

The improvement is *not* sufficient to clear the conditional-accept
bar. JLEO is a low-volume journal whose typical-acceptance pipeline
runs through major R\&R rounds; v17 should be sent in expecting one,
not a clean accept on first round.

The remaining $\sim 35\,\%$--$40\,\%$ outright-reject probability comes
from three sources the Route 2 push did not address:
1. Identification scope on $\beta$. The paper still cannot causally
   identify the negative ATT-weighted estimate's data-generating
   process. Q1–Q3 negativity is consistent with multiple stories
   the data do not adjudicate. A referee who insists on causal
   identification of the price imprint will reject.
2. CADE label thinness. $193$ cobidder positives is a non-trivial
   sample, but a $\$$narrow-cobidder-label referee can argue the
   bridge is one well-specified instrument away from contradiction.
3. JLEO scope. The contribution is methodological and informational,
   not a structural-IO model with welfare quantification. JLEO's
   editorial taste varies on whether this counts as "core IO" — the
   draw matters.

None of the three are addressable inside the Route 2 envelope. The
remaining reject probability is a *contribution-shape* risk, not an
*execution* risk; the v17 execution is clean.

## V. Was Route 2 worth doing?

**Yes, on the strength of two facts.**

*Fact one:* the disclosure cleanup was mandatory regardless of the
substantive moves. The half-day of disclosure work alone was
worth doing — it removed a referee gotcha that a competent editor
could have caught in the first $30$ minutes. Even if Subprompts 2
and 3 had returned no substantive evidence, the disclosure cleanup
floor would have justified the v17 push.

*Fact two:* Front 3 (architecture/complementarity) materially
strengthened the paper's strongest section, with a sequential
gatekeeper headline that did not exist in v16 and is now anchored in
the abstract, $\S$\ref{sec:intro}, and $\S$\ref{sec:forensic}. Front
2 (theory bridge) tightened the second-strongest section by reversing
a self-imposed limitation that was empirically false, with a
multivariate logit confirming the new bid-level signature at
$p<10^{-3}$. Front 1 (sign reversal) gave a modest but defensible new
empirical fact (Q4 robust positive) and a referee-critique block
(trim sensitivity) on the paper's most contested estimate. None of
the three is a breakthrough; together they produce a JLEO-fit
manuscript at the major-R\&R-feasible level.

The four Route-2-working-day estimate from Subprompt 1's audit was
roughly correct. The hedge integrity is preserved (v16 byte-frozen,
deployable at any time). The cost of Route 2 is bounded; the
expected value is positive.

**Route 2 was worth doing. It was not a breakthrough. The
manuscript improved at exactly the dimensions where the audit said
it would, with the magnitudes the audit estimated, and at the cost
the audit estimated. The ceiling moved up by enough to justify
submission to JLEO with realistic expectations of a serious major
R\&R, not by enough to expect a clean accept.**

## VI. Honesty audit

Three places where the temptation to overstate is highest, with
what the v17 manuscript actually says:

1. *Sequential gatekeeper as cost-effective deployment.* The v17
   manuscript reports recall-vs-microdata-footprint, not
   dollarised cost-per-cobidder. The Subprompt 3 brief flagged
   this; the implementation respects it; the abstract and
   $\S$\ref{sec:forensic} state the trade-off as $83\,\%$ footprint
   reduction at $8\,\%$ recall cost without monetary scaling. *Not
   overstated.*
2. *Bid-level bridge as cover-bidder validation.* The v17
   manuscript describes the bid-level signature as *consistent with*
   credible cover bidding under R2, not as identification of
   cover-bidder type. The $\S$\ref{sec:cade_bridge_bidlevel}
   subsection makes the R1/R2 distinction explicit and presents
   R2 as the literature's settled reading rather than as a
   bespoke salvage move. *Not overstated.*
3. *Q4 robust positive as identification of the screening
   framework.* The v17 manuscript reports the segment-level
   decomposition as the cleanest reading of the design dependence,
   not as positive identification of the screening-value
   interpretation. The original "screening-value-as-diagnostic"
   framing of v15 is explicitly demoted. *Not overstated.*

A fourth would-be overstatement — that the architecture story is now
the paper's central contribution rather than its third — *is*
something v17 nudges toward (the abstract leads with the
sequential-gatekeeper claim; the title remains
"Screening Cartels Under Incomplete Observability" which lines up
with that center). This is a real editorial reorganization and we
defend it: the architectural / observability angle is empirically
the cleanest, theoretically the freshest, and editorially the most
JLEO-fit. Promoting it is not overstating; it is recognizing where
the paper's strongest evidence actually lives.

---

*End of Route 2 final verdict. v16 remains byte-frozen as
recoverable hedge. v17 is ready for one further pass on
follow-on items (temporal-holdout audit of the gatekeeper;
brief OA-A note on R1/R2; literature-section refresh) before
JLEO submission.*
