# R2 Revision Log

**Date:** 2026-04-01
**Referee verdict:** Major Revision
**Target:** Acceptance as screening paper
**Manuscript version:** v11 (work/v11/)
**Main file:** paper_v11.tex

## Summary of Changes

### Bloco 1: Screening framing
- [x] Abstract rewritten — "diagnostic tool," no causal claims, "starting point not verdict"
- [x] Intro ¶1 rewritten — opens with detection problem
- [x] Contributions rewritten — "primarily diagnostic," "conditional associations"
- [x] Language audit completed — "diagnostic" 7x across intro/abstract/conclusion

### Bloco 2: Mechanism language
- [x] Convite section hedged — "most informative heterogeneity result," selection caveat
- [x] Structural model compressed — 385 → 332 lines (–14%), Predictions as compact table
- [x] Bid rotation section contained — Mechanisms opens with "complement, not prove"
- [x] CADE section consolidated — "operating principle," p=0.93 in body
- [x] Event study pre-trends addressed — "cannot adjudicate," symmetric interpretations
- [x] Body-wide grep completed — 0 overclaims remaining

### Bloco 3: Welfare
- [x] Body reduced to appendix pointer only (0 dollar amounts in body)
- [x] Appendix has caveats: "assume full causality, which the paper does not establish"

### Bloco 4: OLS/cross-fit discipline
- [x] No "preferred estimate" remains (only disclaimer)
- [x] Range 3.6–7.7% used consistently
- [x] Decomposition 0.043 described, not promoted

### Bloco 5: Referee minor points
- [x] Comparability result (0.978 overlap) in intro ¶4
- [x] Unrestricted sample highlighted in Results OLS paragraph
- [x] FL classification reframed as "aggregate marker, not firm type"
- [x] Item FE granularity noted ("finest product-code level")
- [x] Odd/even FL incidence reported (5.1% vs 4.5%)

### Bloco 6: Length
- Body reduction: ~21% from v9 baseline
- Pages: 73 (including appendix)

### Bloco 7: Response letter
- [x] Created: work/R2_response/response_letter.md

### Bloco 8: Compilation
- [x] PDF compiles without errors
- [x] 0 undefined references
- [x] 0 duplicate labels

### Bloco 9: Git
- [x] Backup commit: 70818aa
- [x] Previous commits: 5f7aae1, 2d7270e

## New estimations incorporated
1. Cross-fit decomposition: 0.043 (SE 0.019) — odd-year FL on full sample
2. AUC bootstrap 95% CI: [0.91, 0.94] (1000 reps)
3. Continuous FL measure: 0.022/log-point (SE 0.005)
4. Permutation placebo: mean 0.001, SD 0.003, 0/20 ≥ 0.064
5. FL persistence: 10% across 2009-13 / 2014-19
6. Effective items: 15,101 of 18,441 (82%) with FL variation

## Files modified (v11)
- sec_frontmatter.tex (abstract, title)
- sec_introduction.tex (complete rewrite)
- sec_literature.tex (compressed, new refs)
- sections/sec4_data_fl.tex (FL definition, persistence, classification diagnostics moved)
- sections/sec3_structural_model.tex (compressed, predictions as table)
- sections/sec5_empirical_strategy.tex (reordered, IV compressed)
- sec_cade.tex (consistency check framing, killer table)
- sections/sec7_results.tex (classification diagnostics subsection, cross-fit decomp, H1→H2 transition)
- sec_mechanisms.tex (alternatives hedged, strategic adaptation, convite softened)
- sec_robustness.tex (table with assumptions, threshold sensitivity, oversight gradient, welfare pointer)
- sec_conclusion.tex (conceptual opening, no welfare numbers, narrative loop)
- sections/sec_identification.tex (agnostic pre-trends)
- sections/sec_ground_truth.tex (flowing prose)
- sections/sec_mechanism_evidence.tex (minor)
- sec_appendix.tex (structural ID, horse-race table, counterfactual caveats)
- references.bib (Baldwin 1997, Clark 2021, Schurter 2020, Wallimann 2023)

## Warnings / Items Requiring Author Review
- Figure fig_03_coef_summary.pdf: ordering of estimators not changed (requires R pipeline regeneration)
- Horse-race table (tab_horse_race) in appendix is hand-constructed; verify against actual regression output
- Continuous measure footnote (r=0.33 correlation with AL count) based on single R run; may want to verify
