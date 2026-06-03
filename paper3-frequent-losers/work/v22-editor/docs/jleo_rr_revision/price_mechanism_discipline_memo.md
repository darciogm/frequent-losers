# Price & Mechanism Discipline Memo — §7

Internal memo for the JLEO R&R. Confirms what the price evidence is, what it is
not, and that the §7 prose stays inside the disciplined boundary. All numbers
traced to script output CSVs (see `price_number_reproduction.csv`). No numbers
invented.

## The 17 questions

1. **Price outcome.** Log negotiated unit price (`lneg_price`). The within-cell
   mechanism test uses a derived gap, `winner_vs_ref = lneg_price − log_ref_price`
   (winner-to-reference compression), built in script 78.

2. **Treatment.** Frequent-loser presence at the item level — the binary
   `losers` (≥1 FL participant on the item-tender). For the disciplined
   comparisons it is re-expressed as overlap-cell membership (treated vs control
   items inside the same exact cell of item-group × year × modality × PBU-size ×
   tender-value quartile).

3. **Broad association.** `+0.064` (= 0.0636, `p = 0.003`, N = 1,654,401), within
   item+year+PBU FE. Positive: flagged items carry higher negotiated prices.
   `headline_specs.csv` / `tab_prices.tex`.

4. **Overlap-cell ATT.** `−0.097` (`p < 0.001`, = 1.75e-10, SE 0.015,
   N ≈ 1.52M). Within the same observable cell, treated items have *lower* prices.
   `headline_specs.csv` / `item_level_scope_match.csv`.

5. **The sign REVERSES.** Broad `+0.064` → overlap-unweighted `+0.044`
   (`p = 0.035`) → overlap-cell ATT `−0.097` (`p < 0.001`). The reversal is a
   *weighting* result, not a dropped-observation artifact: only `1.06%` of
   treated items lack a within-cell counterfactual. PS-trimmed common-support
   ATT goes further negative, `−0.307` (N 400,687). Broad and overlap estimates
   average different parts of the procurement distribution.

6. **Q4 high-value differs.** Tender-value quartile Q4 is the **only systematic
   positive cell**: ATT `+0.041` (`p = 0.045`). Q1–Q3 are all negative
   (`−0.053 / −0.048 / −0.037`). Interpretation in text: coordination costs
   spread over larger contracts. `within_overlap_subgroup_betas.csv` /
   `segment_betas.csv`.

7. **Pregão vs Convite.** Under overlap-cell ATT **both modalities are negative**
   (Convite `−0.099`, Pregão `−0.098`). In the *broad* imprint the association is
   **larger in Pregão** (`+0.0933`) than Convite (`+0.0382`). The text uses the
   larger broad Pregão imprint to argue against a pure procedural-artifact reading
   (if FL were just quorum fillers under the convite 3-bidder rule, the imprint
   should be stronger in convite, not pregão).

8. **Reference prices observed?** Yes. Script 78 reads `bid_ref_price_min` and
   builds `winner_vs_ref = lneg_price − log_ref_price`. Reference (pre-bid ceiling)
   prices ARE in the data and are used directly in the within-cell compression
   test. (`overlap_ref_att` in script 51 even adds pre-bid reference-price bins to
   the exact overlap design, coef unchanged at `−0.097`.)

9. **Bidder counts controlled?** Yes. The within-cell compression
   (`winner_vs_ref ~ losers`, `−0.048`) collapses to `+0.008` (NOT significant)
   once `log(n_firms)` enters. Splitting bidders: the genuine-bidder count loads
   strongly (`l_gen = −0.137`) while the FL count is **not significant**
   (`l_fl = +0.026`, SE 0.020). The price movement runs through the
   bidder-count channel, **the cover-bidding mechanism is NOT identified.**
   `bidder_decomp.csv` / `mechanism_test_results.csv`.

10. **Fixed effects.** Broad: item + year (+ PBU in col 2). Overlap/ATT designs:
    exact-cell match on item-group × year × modality × PBU-size × tender-value
    quartile (the `overlap_cell` FE). Selection test: all-5-dimension FE except
    firm identity. Clustering at item level throughout.

11. **What causal claim IS identified.** **None.** Every row is explicitly
    descriptive. The overlap/ATT/PS designs tighten *comparability* on observables
    but do not purge selection on unobservables (script 51 notes say to call the
    gap a "conditional price association rather than a causal effect"). The screen
    is an enforcement-triage signal, not a treatment.

12. **What is NOT identified.** (a) the cover-bidding mechanism (price movement is
    a bidder-count channel, FL count ns); (b) a treatment effect of FL presence on
    price (selection on unobservables not ruled out, sign is weighting-dependent).

13. **Why not damages.** The direct-CADE overlap estimate is **null**
    (`−0.061`, `p = 0.45`). Price regressions do not recover the legal object of
    the cartel cases and supply no damages base, and there is no counterfactual
    (but-for) price. Overcharge/damages has its own evidentiary tradition
    (Bryant-Eckard, Connor) distinct from screening.

14. **Why not overcharge.** The broad positive imprint is
    **selection-into-high-price-cells** (non-treated mean log price rises Q1 `1.35`
    → Q5 `6.93`, Δ `5.58`; partialled-out `+3.55`), not a within-cell markup. Once
    cells are held fixed the price is *lower*, not higher. A markup interpretation
    of `+0.064` would misread cell-level selection as a price-formation effect.

15. **Safest main-text text.** The existing §7 wording is **already safe** and
    needs no softening. §7 opens by stating the boundary once: price evidence is
    "scope evidence … not a damages estimate, an overcharge, a cartel markup, a
    causal price effect … or proof of a cover-bidding mechanism." It labels the
    broad numbers "descriptive associations … not causal effects," frames the
    reversal as a weighting result, calls the mechanism "*not* identified by these
    data," and closes that the award-layer signal is "a trigger for richer evidence
    collection, not a stand-alone measure of price injury." **Confirmed:
    scope-only, no-causal, no-overcharge, mechanism-not-identified. No residual
    overclaim found in the prose.**

16. **What to move to appendix.** The **full regression grids** — broad /
    overlap-unweighted / overlap-ATT / PS-trimmed, plus modality, value-quartile,
    direct-CADE rows, and the bidder-count decomposition — **must be ADDED** to the
    appendix. They are **currently MISSING**: `sec_app04_scope_submission.tex` is
    ~214 words, 0 tables, while §7 twice promises "full price regressions … in
    Appendix" and "the bidder-count boundary." **Dangling promise — close it.**
    All data already exist (headline_specs.csv, within_overlap_subgroup_betas.csv,
    segment_betas.csv, att_trim_sensitivity.csv, bidder_decomp.csv); no
    re-estimation needed.

17. **What to delete.** **Nothing on reproducibility grounds.** Every price
    number in §7 traces to a script output CSV (20/20 match, 0 not_found — see
    `price_number_reproduction.csv`). No unreproduced number sits in the main text,
    so no deletion is required. The only outstanding action is additive (close the
    appendix gap in item 16).

## Bottom line

The §7 prose is disciplined and reproducible. The single defect is structural,
not substantive: the appendix that the main text points to for "full regressions"
is a 214-word stub with no tables. Add the grids; delete nothing.
