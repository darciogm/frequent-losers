# Paper 2: Cover Bidding in Public Procurement — Structural Estimation and the Dispersion Paradox

**Target**: RAND, JIE, ou IJIO (companion)
**Status**: Manuscript ~90% pronto (sections 1-9 + appendix skeleton written)
**Source**: v6-v8 (structural path) reescrito como standalone

## Central Finding: The Dispersion Paradox
Coordinated cover bidding produces LOWER bid dispersion than genuine
competition (σ_c/σ_g = 0.72). Variance-based screens yield false
negatives for the most sophisticated cartels.

## Manuscript Structure
- `paper_structural.tex` — main file
- `sec_frontmatter.tex` — title, abstract, keywords
- `sec_introduction.tex` — dispersion paradox framing, 3 contributions
- `sec_literature.tex` — 5 strands (structural auctions, Bajari-Ye, screening, cover bidding, procurement design)
- `sec3_structural_model.tex` — 4 propositions, likelihood, identification, 5 predictions
- `sec4_data_fl.tex` — BEC, FL definition (refs Paper 1), estimation samples
- `sec5_empirical_strategy.tex` — MLE two-stage, reduced-form, detection, Bajari-Ye, network
- `sec6_results.tex` — structural → spec tests → detection → reduced-form → event study
- `sec7_counterfactual.tex` — CF1 (min-bidder), CF2 (optimal threshold), CF3 (detection prob)
- `sec8_robustness.tex` — refs Paper 1 for reduced-form; structural-specific checks
- `sec9_conclusion.tex` — dispersion paradox implications, limitations, future research
- `sec_appendix_p2.tex` — proofs, additional tables (skeleton)

## Key Results
| Result | Value |
|--------|-------|
| Regime selection | Regime 2 (ΔBIC = -91,473) |
| σ_c / σ_g | 0.72 (cover bids 28% less dispersed) |
| ε (cover bid spread) | 0.83 log points above winner |
| AUC (FL screen) | 0.94 |
| AUC (Imhof CV) | 0.79 |
| AUC (Random Forest) | 0.90 |
| AUC (Structural LR) | 0.56 |
| Price gap range | 3.6-8.0% (5 estimators) |
| Welfare CF1 | R$74-211M |

## TODO
- [ ] Populate appendix tables from v4 pipeline output
- [ ] Copy missing output figures (fig_03, fig_07, etc.) from v4/output
- [ ] Compile and debug LaTeX
- [ ] Verify all cross-references resolve
- [ ] Add Krasnokutskaya (2011) bid-level unobserved heterogeneity discussion
- [ ] Final polish pass

## Companion Paper
References `\citep{genicolomartins2026screening}` — Paper 1 (screening tool)
