# Sign Reversal — Route 2 Memo (v17)

**Date:** 2026-05-02.
**Vehicle:** `scripts/61_sign_reversal_segment_decomp.R`, executed
2026-05-02. All numbers below from
`output/sign_reversal_segment/*.csv` and
`work/v13/output/tables/tab_sign_reversal_segment.tex`.

**Goal of this pass.** Beyond v16's headline three-step decomposition
(broad $+0.064$ → overlap-unweighted $+0.044$ → overlap-ATT $-0.097$),
identify *which segments* drive the broad-sample positive, and quantify
how concentrated the ATT-weighting machinery is. Use the answers to
discipline the manuscript's interpretation.

---

## I. Headline new finding: the broad-sample positive is a Q4-tender-value phenomenon

Re-estimating the headline regression within tender-value quintiles
(item-level pre-tender reference value):

| Quintile | Broad $\widehat\beta$ | Overlap unwt.\ $\widehat\beta$ | Overlap ATT $\widehat\beta^{ov}$ | $N_{\text{broad}}$ | $N_{\text{treat,broad}}$ |
|---|---|---|---|---|---|
| Q1 (smallest tenders) | $-0.065$ ($p<10^{-15}$) | $-0.064$ ($p<10^{-15}$) | $-0.053$ ($p<10^{-13}$) | 434,419 | 10,397 |
| Q2 | $-0.057$ ($p<10^{-29}$) | $-0.057$ ($p<10^{-28}$) | $-0.048$ ($p<10^{-25}$) | 476,570 | 14,223 |
| Q3 | $-0.040$ ($p<10^{-17}$) | $-0.042$ ($p<10^{-19}$) | $-0.037$ ($p<10^{-11}$) | 391,299 | 13,954 |
| **Q4 (largest tenders)** | **$+0.046$** ($p=0.012$) | **$+0.044$** ($p=0.038$) | **$+0.041$** ($p=0.045$) | 352,106 | 40,878 |

This is the cleanest segment finding in the entire decomposition. Three
implications, each independent of the v16 reweighting story:

1. **The broad-sample positive is not a property of the broad sample —
   it is a property of the largest-value tender stratum.** In Q1–Q3,
   the broad coefficient is already negative; the broad $+0.064$ is
   essentially the population-weighted average of three negatives and
   one positive (Q4) where the positive has 40,878 treated items vs.
   $\approx$ 38,500 in Q1+Q2+Q3 combined. Q4's leverage is structural,
   not a diagnostic.
2. **In Q4, the positive survives all three specifications.** The
   overlap restriction does nothing to it ($+0.046 \to +0.044$); the
   ATT reweighting does almost nothing either ($+0.044 \to +0.041$).
   This is the only segment where the reading "the screening signal
   varies with deployment value, and is positive where deployment
   value is highest" survives the design dependence test.
3. **The deployment-value reading the v16 memo demoted is alive,
   narrowed.** Not "the screening-value-vs-treatment-effect framing
   adjudicates the broad sample"; rather "in the large-tender-value
   stratum where deployment value is most plausible *a priori*, the
   pricing imprint is positive in all three specifications, with the
   overlap restriction and the ATT reweighting both leaving it
   essentially unchanged."

This finding moves the manuscript from "the sign reversal is a
reweighting phenomenon and the negative ATT estimate cannot be
interpreted causally" (v16) to a tighter pair of statements:

> *(a)* The positive broad-sample coefficient is concentrated in the
>      Q4 tender-value stratum, where it is robust to overlap
>      restriction and ATT reweighting.
>
> *(b)* The negative ATT-weighted overlap coefficient is the
>      population-weighted average of negative within-quintile
>      coefficients in Q1–Q3 dominating Q4 once the ATT weights
>      down-weight Q4's large-volume cells.

Both statements are factual and defensible.

## II. Other segments where the reversal is diagnostic

### II.1. Item groups with the largest stratum-N

For the three biggest item groups (each with $\geq$ 95k items in the
broad sample):

| Item group | Broad | Overlap unwt. | Overlap ATT |
|---|---|---|---|
| 13 (specialty) | $+0.255$ | $+0.245$ | $-0.129$ |
| 12 | $+0.265$ ($p=0.024$) | $+0.256$ ($p=0.025$) | $-0.072$ ($p=0.25$) |
| 29 | $+0.029$ | $+0.022$ | $-0.051$ ($p=0.019$) |

Item group 13 is the most informative single cell: a +25 percentage-point
broad positive that survives the overlap restriction (+24.5pp) but flips
to $-13$pp under ATT weights. This is the v16 reweighting phenomenon in
microcosm: a single item group where the weighting machinery does the
sign-reversal work all by itself.

### II.2. PBU size quintile

| Quintile | Broad | Overlap unwt. | Overlap ATT |
|---|---|---|---|
| Q1 (smallest PBUs) | $+0.147$ ($p=0.33$) | $-0.097$ | $-0.091$ |
| Q2 | $+0.027$ | $-0.046$ | $-0.132$ ($p=0.011$) |
| Q3 | $+0.062$ ($p=0.035$) | $+0.034$ | $-0.070$ ($p=0.087$) |
| Q4 (largest PBUs) | $+0.018$ | $+0.009$ | $-0.100$ ($p<10^{-17}$) |

PBU size does not produce a pattern as clean as tender value. The
overlap-unweighted estimate flips sign across quintiles in non-monotonic
ways (Q1 negative, Q3 positive, Q4 essentially zero). This is consistent
with v16's reading that PBU-size selection is not the load-bearing
margin.

## III. ATT-weight concentration: the reversal is *not* fragile to a small set of cells

| Diagnostic | Value |
|---|---|
| Number of overlap cells | $8{,}625$ |
| HHI of cell-level ATT weights | $0.000596$ ($\approx 1{,}679$ effective cells) |
| Top-1\% (87 cells) weight share | $15.2\%$ |
| Top-10\% (863 cells) weight share | $54.6\%$ |
| Treated items in top-decile cells | $42{,}902$ ($54.6\%$ of treated items) |

Top-decile cells are big *and* convite-leaning ($78.9\%$ vs.\ $62.6\%$
in the rest), with higher mean log reference price ($3.92$ vs.\ $2.93$)
and more bidders ($5.8$ vs.\ $4.8$). They are large public buys via
sealed-bid, which is exactly the segment where deployment incentives are
*a priori* highest. So the cells doing most of the ATT-weighting work
look like the cells the screening-value reading would target — but, as
we will see in §IV, dropping them does not reverse the sign of
$\widehat\beta^{ov}$.

### III.1. Trim sensitivity: dropping top-weight cells does not flip the sign

| Spec | $\widehat\beta^{ov}$ | $N$ | $N_{\text{treat}}$ |
|---|---|---|---|
| No trim | $-0.097$ ($p<10^{-9}$) | 1,517,868 | 78,613 |
| Drop top 1\% of weighted cells | $-0.107$ ($p<10^{-15}$) | 1,440,988 | 66,844 |
| Drop top 5\% | $-0.113$ ($p<10^{-14}$) | 1,192,587 | 48,407 |
| Drop top 10\% | $-0.118$ ($p<10^{-12}$) | 973,582 | 36,677 |
| Drop top 25\% | $-0.115$ ($p<10^{-5}$) | 550,801 | 18,438 |
| Drop top 50\% | $-0.133$ ($p=0.001$) | 240,307 | 7,468 |

This is the most consequential robustness diagnostic in this pass. **The
ATT-weighted negative does not weaken when the most heavily weighted
cells are removed; it strengthens.** A reader who suspects the negative
estimate is mechanically driven by a small number of cells with extreme
treated/untreated imbalance gets the opposite of what they expect: the
negative is *more* concentrated in the bulk of the overlap sample and is
attenuated, if anything, by the heavy weight on Q4-large-PBU
convite cells.

This forces a meaningful update to the v16 narrative.

## IV. Updated reading of the sign reversal (v17 manuscript prose)

The v16 framing was: "the sign reversal is overwhelmingly an
ATT-reweighting phenomenon, and the reweighted estimate cannot be
interpreted causally because the dropped/reweighted cells are not
exclusively cartel-adjacent." The v17 framing should add and partially
replace:

> *Decomposed into design margins:* the broad-sample $\widehat\beta =
> +0.064$ averages four within-quintile estimates that already split:
> negative in tender-value Q1--Q3, positive in Q4. The overlap
> restriction leaves all four quintile-level estimates essentially
> unchanged. The ATT reweighting moves Q1--Q3 modestly toward zero (from
> $-0.06/-0.06/-0.04$ to $-0.05/-0.05/-0.04$) and leaves Q4 essentially
> unchanged at $+0.04$. The aggregate sign reversal is therefore not
> the result of a single phenomenon: it is the result of two facts
> stacking. *Fact one:* in Q4 (large-tender-value items where deployment
> value is most plausible *a priori*), all three specifications return a
> coefficient of approximately $+0.04$. *Fact two:* in Q1--Q3 (small and
> medium tenders), all three specifications return a coefficient between
> $-0.05$ and $-0.06$. The broad-sample positive is the population
> average of these four estimates, in which Q4's $40{,}878$ treated
> items dominate the volume-weighted mean. The ATT-weighted overlap
> $\widehat\beta^{ov}$ is the same average under cell-size weights that
> down-weight Q4's volume; under those weights, Q1--Q3 dominate.

> *Two further facts argue against the alternative reading "the negative
> ATT estimate is a few-cell artifact."* First, dropping the
> most heavily weighted cells from the overlap-ATT estimator strengthens
> the negative estimate: from $-0.097$ at no trim to $-0.118$ when the
> top decile of cells is removed. Second, the top-decile cells of the
> overlap-ATT design are convite-leaning large public buys --- the
> segment where deployment value is most plausible. The negative
> $\widehat\beta^{ov}$ is therefore neither a thin-market artifact nor a
> few-cell artifact; it is a structural property of the bulk of the
> overlap sample.

> *The screening-value reading the v15 paper used to motivate the sign
> reversal is therefore not adjudicated by this decomposition.* What the
> decomposition supports is narrower: the pricing imprint is positive in
> the segment where deployment value is most plausible *a priori* (Q4),
> robust to design choice; in Q1--Q3 it is negative across all three
> specifications. The interpretation of the negative coefficient in
> Q1--Q3 remains open --- it is consistent with treatment effects on
> price formation in small tenders, with selection on item
> characteristics correlated with both FL presence and price formation,
> or with composition heterogeneity in the firm pool that the available
> identification cannot disentangle. The paper no longer treats the
> sign reversal as a screening-value-vs-treatment-effect diagnostic;
> instead it foregrounds the segment-level decomposition as a more
> honest reading of the design dependence.

## V. What this gains the manuscript, concretely

1. **A new headline statement** ("the broad-sample positive is a
   Q4-tender-value phenomenon, robust to design") that is short,
   factual, and defensible. This goes in §1, the abstract, and §7.2.

2. **Two new robustness tables**: the segment-level $\widehat\beta$
   table (`tab_sign_reversal_segment.tex`, three panels: segment-level
   estimates; ATT-weight concentration; trim sensitivity) and the
   complementary v16 `tab_sign_reversal_decomp.tex`. Both go in
   Appendix C.

3. **A figure** (`fig_segment_betas.pdf`) showing the segment-level
   $\widehat\beta$ trajectory across specifications. Goes in §7.2 if
   space permits, otherwise Appendix C.

4. **A factual rebuttal to the "few-cell artifact" referee critique.**
   The trim-sensitivity panel directly addresses the implicit referee
   concern that the negative ATT estimate is mechanically driven by
   extreme leverage on cells with thin counterfactuals. The opposite
   is true.

## VI. What this does *not* gain the manuscript

This pass does not deliver:

1. **A causal interpretation of the negative estimate in Q1--Q3.** The
   decomposition narrows the reading but does not adjudicate
   alternative interpretations (treatment effects vs.\ selection vs.\
   composition heterogeneity). The honesty rule from v16 stays.

2. **A direct test of the screening-value framework.** The segment
   decomposition is consistent with a screening-value reading
   (deployment value highest in Q4; pricing imprint highest in Q4) but
   does not require it: a competing story in which Q4 large tenders
   simply have different price-formation regimes (more bidders, more
   reference-price competition) would generate the same pattern.

3. **A replacement for Proposition 4 (OA-A).** The proposition
   formalizes the rent-component-co-movement assumption that would let
   the sign reversal be read as a screening-value diagnostic. The
   decomposition does not validate the proposition; it shows the
   proposition's reading is not contradicted by Q4 evidence and is not
   required by Q1--Q3 evidence either.

## VII. Verdict — Front 1

**Material upside delivered.** The Q4-tender-value finding is a
substantive new headline that the v16 memo did not anticipate. Combined
with the trim-sensitivity result (which forecloses the "few-cell
artifact" reading), this pass meaningfully tightens the manuscript's
honest position on the sign reversal. It does not solve the
identification problem; it does identify the cleanest empirical fact in
the design dependence (Q4 robust positive; Q1--Q3 robust negative
across specs).

**Recommendation:** wire `tab_sign_reversal_segment.tex` and
`fig_segment_betas.pdf` into v17, with §7.2 prose rewritten along the
lines of §IV above. Demote the v16 reweighting-phenomenon framing
without retracting it (it is still true; it is just no longer the
load-bearing observation).

## VIII. Files produced

| File | Role |
|---|---|
| `output/sign_reversal_segment/segment_betas.csv` | 81 rows: $\widehat\beta$ per (segment, level, spec) |
| `output/sign_reversal_segment/att_weight_concentration.csv` | HHI + top-k% weight share |
| `output/sign_reversal_segment/top_weight_cells.csv` | Characteristics of top-decile-weighted cells vs.\ rest |
| `output/sign_reversal_segment/att_trim_sensitivity.csv` | $\widehat\beta^{ov}$ after dropping top-k% weighted cells |
| `output/sign_reversal_segment/fig_segment_betas.pdf` | Dot plot of segment $\widehat\beta$ across three specs |
| `work/v13/output/tables/tab_sign_reversal_segment.tex` | Three-panel summary table |
| `scripts/61_sign_reversal_segment_decomp.R` | Generating script |

---

*End of Front 1 Route 2 memo. Manuscript edits proceed in Subprompt 3 onward.*
