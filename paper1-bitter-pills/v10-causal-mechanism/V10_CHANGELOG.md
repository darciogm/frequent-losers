# V10 Changelog

Version directory: `v10-causal-mechanism/`

## Editorial Objective

V10 combines the strongest parts of v8 and v9 for the Journal of Public
Economics short-paper track. The main paper is causal-first and
mechanism-disciplined:

- v8 strength recovered: judicial orders are framed as external urgent
  procurement shocks, plausibly exogenous to procurement shocks conditional on
  item, time, and PBU fixed effects.
- v9 strength preserved: administrative-versus-litigated comparisons are
  selection-bounded, quantity is treated as a post-treatment mechanism, and
  within firm-buyer-item estimates are interpreted as same-firm pricing tests.

## Main Changes from V9

- Retitled the paper to `Judicial Urgency and the Cost of Public Procurement`.
- Rewrote the abstract to lead with the causal urgent-procurement shock.
- Rewrote the introduction around three layers:
  1. externally imposed urgent procurement;
  2. selection-bounded sanction margin;
  3. pricing-versus-sourcing mechanisms.
- Rewrote the institutional section to support the exogeneity claim without
  claiming as-if random allocation of patients or medicines into litigation.
- Rewrote the empirical strategy to state the estimand, identifying assumption,
  threat, and interpretation for each layer.
- Reframed results so the first table establishes the causal urgent-procurement
  effect, the second layer bounds sanction exposure, and the mechanism evidence
  distinguishes same-firm pricing from fragmented sourcing.
- Shortened the appendix to the essentials needed for a JPubE short paper:
  classifier/sample validation, Lee bounds plus placebo/inference, and the
  fiscal procurement-cost calculation.

## JPubE Short-Paper Constraints

The JPubE short-paper guidance says submissions may be no longer than 6,000
words and include up to five exhibits; the main text and exhibits must stand on
their own rather than advertise a longer appendix. V10 keeps the main paper to
five exhibits:

1. institutional purchase-type table;
2. urgent margins plus under-the-gun bounds;
3. within firm-buyer-item robustness;
4. pricing-versus-sourcing figure;
5. winner-switching table.

The online appendix is compact but no longer artificially capped. It includes
only material that directly supports the main claims: classifier validation and
error diagnostics, sample construction, placebo and dynamic diagnostics, Lee
bound robustness, wild-cluster inference, within-firm clustering/power
diagnostics, quantity-as-mechanism evidence, aggregation-cell evidence, and the
fiscal procurement-cost calculation.

## Build

Use:

```bash
./build_v10.sh
```

The analysis layer is inherited from v9, so generated table filenames and
scripts retain some `v9` names. The new build wrapper keeps those scripts intact
but reports the run as v10.
