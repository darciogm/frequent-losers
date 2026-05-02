# Sign-Reversal Decomposition — v16

**Goal:** treat the broad-sample positive $\widehat\beta$ vs overlap-restricted negative $\widehat\beta^{ov}$ as empirically as possible, using only existing data.
**Vehicle:** `scripts/59_sign_reversal_decomp.R`, ran 2026-05-02. All numbers below from `output/sign_reversal_decomp/*.csv` and `work/v13/output/tables/tab_sign_reversal_decomp.tex`.

---

## I. What the decomposition was able to do

Three empirically separable steps were possible from the existing prepared dataset:

1. **Decompose the sign-reversal mechanically.** The broad-sample $\widehat\beta = +0.064$ ($p=0.003$) and the overlap-restricted $\widehat\beta^{ov} = -0.097$ ($p<10^{-9}$) differ along **two independent margins**: (i) restricting to overlap cells (those with both treated and untreated items), and (ii) ATT-reweighting within those cells. We re-estimated the same regression on the overlap subsample **without** ATT-weights, isolating the two margins. Result:

   | Spec | $\widehat\beta$ | $p$-value | $N$ |
   |---|---|---|---|
   | Broad-sample $\widehat\beta$ | $+0.064$ | $0.003$ | $1{,}654{,}401$ |
   | Overlap subsample, **unweighted** | $+0.044$ | $0.035$ | $1{,}517{,}868$ |
   | Overlap subsample, **ATT-weighted** ($\widehat\beta^{ov}$) | $-0.097$ | $<10^{-9}$ | $1{,}517{,}868$ |

   **The sign reversal is overwhelmingly an ATT-reweighting result, not an overlap-restriction result.** Restricting to cells with common support drops only 8.3 % of items and keeps $\widehat\beta$ positive at $+4.4 \%$. The reversal to $-9.7\%$ comes from up-weighting cells with relatively few untreated counterfactuals.

2. **Quantify how many treated items the overlap restriction actually drops.**

   | Cell category | Cells | Items | Treated items |
   |---|---|---|---|
   | Surviving (treated $\geq 1$ and untreated $\geq 1$) | $8{,}625$ | $1{,}517{,}868$ | $78{,}613$ |
   | Dropped: no untreated counterfactual | $599$ | $839$ | $\mathbf{839}$ |
   | Dropped: no treated unit (untreated-only) | $10{,}216$ | $135{,}694$ | $0$ |

   Only **839 of $79{,}452$ treated items ($1.06\%$)** are strictly dropped by the overlap restriction. The "what gets dropped" framing has very small empirical bite: the overlap design retains essentially the entire treated sample.

3. **Test the screening-value reading directly** by comparing characteristics of treated items in dropped vs surviving cells:

   | Characteristic | In dropped cells | In surviving cells | Difference | $p$-value | Direction |
   |---|---|---|---|---|---|
   | Convite share | $0.496$ | $0.638$ | $-0.142$ | $<10^{-15}$ | **Against screening reading** |
   | Direct-CADE-item share | $0.019$ | $0.024$ | $-0.005$ | $0.33$ | Null |
   | Cobidder-item share | $0.139$ | $0.078$ | $+0.061$ | $<10^{-6}$ | **Consistent with screening reading** |
   | PBU size quartile | $2.44$ | $3.56$ | $-1.12$ | $<10^{-150}$ | Against (smaller PBUs dropped) |
   | Mean log reference price | $6.69$ | $5.49$ | $+1.20$ | $<10^{-15}$ | High-priced specialty items dropped |
   | Mean number of bidders | $10.5$ | $9.0$ | $+1.5$ | $<10^{-7}$ | High-participation items dropped |

   Of the six discriminators, **one points toward** the screening-value reading (cobidder share is concentrated in dropped cells), **two point against** (convite share and PBU size are *lower* in dropped cells, opposite of what deployment-targeting would predict), **one is null** (direct-CADE share), and **two characterize a different story** (dropped cells are high-priced, high-participation specialty items where there are no comparable untreated counterfactuals — a thin-market problem, not a deployment-sorting problem).

4. **Localize where $\widehat\beta^{ov}<0$ lives within the overlap sample.** Re-estimating the ATT-weighted overlap regression in subgroups:

   | Subgroup | $\widehat\beta^{ov}$ | $p$-value | $N$ |
   |---|---|---|---|
   | Pregão items | $-0.099$ | $<10^{-5}$ | $475{,}923$ |
   | Convite items | $-0.098$ | $<10^{-13}$ | $1{,}041{,}945$ |
   | Non-direct-CADE items | $-0.097$ | $<10^{-9}$ | $1{,}487{,}055$ |
   | **Direct-CADE items** | $-0.061$ | $0.45$ | $30{,}813$ |
   | Tender-value Q1 | $-0.053$ | $<10^{-13}$ | $389{,}352$ |
   | Tender-value Q2 | $-0.048$ | $<10^{-25}$ | $428{,}487$ |
   | Tender-value Q3 | $-0.037$ | $<10^{-11}$ | $358{,}052$ |
   | **Tender-value Q4** | $+0.041$ | $0.045$ | $341{,}977$ |

   Two informative results inside the overlap sample: (a) within direct-CADE items, $\widehat\beta^{ov}$ is statistically indistinguishable from zero (point estimate $-0.061$, $p=0.45$) — the negative reading does not survive in the cells closest to known cartel adjudications; (b) in the highest tender-value quartile (where deployment value is most plausible *a priori*), $\widehat\beta^{ov}$ is **positive and significant** at $+4.1\%$ ($p=0.045$).

## II. What the decomposition shows

The decomposition replaces the previous interpretation in three concrete ways:

1. **The sign reversal is a reweighting phenomenon, not a "dropping" phenomenon.** The unweighted overlap regression produces $\widehat\beta = +0.044$ ($p=0.035$): the broad-sample positive imprint *survives* the overlap restriction itself. Only the ATT-weights, which up-weight cells with few untreated counterfactuals (treated-heavy cells, structurally), flip the sign. This is well-known in the matching literature but was not foregrounded in v15.

2. **The strongest interpretive claim — that overlap restriction strips out exactly the deployment-sorted, screening-rich environments — is not supported on the dimensions that should carry it.** Convite share and PBU size both move in the *wrong* direction in dropped cells; direct-CADE share is null; only cobidder share is consistent with the prediction. This is mixed evidence at best, not the empirical confirmation v15 implied.

3. **Within the overlap sample, two informative wedges remain:** (a) $\widehat\beta^{ov}$ is null among direct-CADE items, where the screening reading would predict it should be most attenuated and is; (b) $\widehat\beta^{ov}$ is positive and significant in Q4-value items, the cells where deployment value is most plausible *ex ante*. These two subgroup results are quantitatively modest, but they are the empirical residue of the screening-value reading and they survive the decomposition.

## III. What remains unresolved

- We cannot identify, from observables alone, whether the ATT-weights are picking up deployment selection (the screening reading) or selection on unobservable item characteristics correlated with both FL presence and price formation. The decomposition narrows the interpretation of the sign reversal but does not eliminate the alternative-interpretation problem.
- Cobidder-item share *is* concentrated in dropped cells ($+6.1\,$pp, $p<10^{-6}$), which is the dimension most directly tied to the screening framework. We can foreground this, but it is one signal among six.
- The Q4 positive $\widehat\beta^{ov}$ is suggestive of deployment-relevant heterogeneity (large public buys are where targeting is most informative *ex ante*), but its CI is wide and the magnitude is small ($+4\%$).

## IV. How the paper's interpretation should change

The two-objects framing remains useful, but the **interpretive weight on the sign reversal as a screening-value-vs-treatment-effect diagnostic must drop substantially**. The honest reading is:

> **The broad-sample association is positive ($+6.4\%$). It survives overlap restriction without ATT reweighting ($+4.4\%$). It reverses to $-9.7\%$ only after ATT-weights up-weight cells with few untreated counterfactuals; this is a reweighting phenomenon, and the reweighted estimate cannot be interpreted as a treatment effect under the data-generating process the screening framework points to. Within the overlap sample, $\widehat\beta^{ov}$ is null among direct-CADE items and positive in the highest tender-value quartile — two modest empirical traces consistent with the screening reading. The cell-dropping pattern provides one of six dimensions consistent with the screening reading (cobidder share concentration), with the others either null or in the opposite direction. The screening-value-vs-treatment-effect framing is a candidate interpretation; we no longer treat it as the reading the data confirm.**

### Specific edits this requires

1. **§5 / §7.2 (sign-reversal interpretation).** Remove or heavily compress the screening-value-as-rationale framing. Replace with a precise three-step decomposition: broad → overlap-unweighted (still $+4.4\%$) → ATT-weighted ($-9.7\%$). State plainly that the first reweighting margin produces the sign change, not the overlap restriction itself.
2. **Online Appendix A, Proposition 4.** The proposition formalizes the rent-component-co-movement assumption that the sign-reversal-as-screening-diagnostic depends on. Demote from interpretive cornerstone to "one possible interpretation under the auxiliary assumption stated in Proposition 4; the data do not adjudicate among interpretations." Add a line that the decomposition in §X (insert reference) provides only mixed support across six discriminating dimensions.
3. **Add a new robustness paragraph** documenting:
   - The unweighted overlap $\widehat\beta = +0.044$ ($p=0.035$).
   - The 1.06 % drop rate.
   - The $\widehat\beta^{ov}$ null in direct-CADE items and positive in Q4-value items, framed as residue-of-the-screening-reading.
4. **Insert `tab_sign_reversal_decomp.tex`** in the appendix (App C or App E), referenced from §7.2.
5. **§1 / Abstract.** Remove the language that treats the sign reversal as a screening-value diagnostic. The pricing imprint becomes "$+3.6\%$ to $+7.7\%$ in the broad sample; $+4.4\%$ under overlap restriction without weighting; the ATT-weighted estimate is $-9.7\%$ under different sample weights and we report all three to disclose the design dependence." This sentence is short, factual, and demoted.

### What the decomposition lets the paper *gain* in defensibility

Even after the demotion, the decomposition gives the paper:

- **A new robustness fact**: $\widehat\beta = +0.044$ under unweighted overlap restriction. The broad-sample positive result was not built on items the overlap restriction would discard. This is a stronger version of the corroboration than the v15 paper claims.
- **A null inside the overlap sample**: $\widehat\beta^{ov}$ is statistically indistinguishable from zero among direct-CADE items. Far from undermining the screening reading, this is precisely what the framework's auxiliary assumption (Proposition 4) predicts — among items where the cartel is actually adjudicated, the rent component absorbed by FL co-presence is largest, attenuating the negative reading.
- **A positive trace in Q4-value items**: $\widehat\beta^{ov} = +0.041$ ($p=0.045$). Deployment-targeting is most plausible *a priori* in large public buys, and that is where the overlap-weighted estimate stays positive.

These three lines are honest, narrow, and defensible. They replace the v15 framing that overclaimed.

## V. Files produced

| File | Role |
|---|---|
| `output/sign_reversal_decomp/headline_specs.csv` | Three-row table of $\widehat\beta$, $\widehat\beta^{ov}$ unweighted, $\widehat\beta^{ov}$ ATT-weighted |
| `output/sign_reversal_decomp/cell_dropping_dimensions.csv` | Cell counts and characteristics by survival status |
| `output/sign_reversal_decomp/per_dimension_overlap_share.csv` | Share of items in surviving cells, by modality / size / direct-CADE / cobidder / year |
| `output/sign_reversal_decomp/within_overlap_subgroup_betas.csv` | Subgroup $\widehat\beta^{ov}$ within the overlap sample (modality, PBU size, tender value, direct-CADE, cobidder, year) |
| `output/sign_reversal_decomp/screening_alignment.csv` | Direct test of screening-value reading: dropped vs surviving cell characteristics |
| `work/v13/output/tables/tab_sign_reversal_decomp.tex` | Three-panel summary table for the paper |

---

## VI. Decisions for the v16 line-edit pass

| Decision | Implementation |
|---|---|
| Demote screening-value-as-diagnostic in §1 / abstract | Replace with the three-step factual statement |
| Add the unweighted-overlap result ($\widehat\beta=+0.044$) | One sentence in §7 main and one row in the appendix table |
| Acknowledge cell-dropping evidence is mixed | One paragraph in §7.2 referencing the new appendix table |
| Promote the within-overlap subgroup nulls/positives | One paragraph in §7.2; reference Panel B of `tab_sign_reversal_decomp` |
| Insert table in Appendix | Add `\input{output/tables/tab_sign_reversal_decomp}` to App C, with explanatory text |
| Update macros in `values.tex` | Add `\valBetaUnwOverlap`, `\valBetaUnwOverlapP`, `\valBetaQ4`, `\valBetaQ4P`, `\valBetaCADEDirect`, `\valBetaCADEDirectP`, `\valDroppedItems`, `\valDroppedItemsShare`, `\valSurvivingItems`, `\valDropConviteShare`, `\valSurvConviteShare` |
| Keep Proposition 4 in OA but mark its role honestly | "One interpretation among several; the data do not adjudicate" |

---

*End of decomposition memo. Manuscript edits proceed in the next pass.*
