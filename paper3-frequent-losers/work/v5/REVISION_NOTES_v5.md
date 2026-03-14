# Revision Notes -- v5
**Date:** 2026-03-14
**Referee:** International Journal of Industrial Organization (IJIO)

## Computational Environment
- Backend: CPU (no GPU available)
- CPU: Intel i7-1260P, 16 threads
- RAM: 15 GB
- Software: R 4.5.2, Python 3.12, Stata 19

## Changes by Category

### A. Manuscript Edits (14 items)
1. **Abstract** (sec_frontmatter.tex): Labeled OLS (4-9%) vs IV/LATE (21%); added caveat on IV sensitivity and Bajari-Ye tender FE attenuation [minor 14]
2. **Eq. 1 footnote** (sec_conceptual.tex): Added note on functional form dependence of m*/n comparative static [minor 1]
3. **Table 3 headers** (tab_iv_first_stage.tex): Clarified FE structure in column headers [minor 3]
4. **IQR footnote** (sec_data.tex): Replaced statistical justification with economic justification for median-based threshold [minor 4]
5. **Table 7 header** (tab_network_split.tex): Changed "FL Suspicion Level" to "FL Market Structure"; renamed rows to "Concentrated-market FL" and "Competitive-market FL" [minor 6]
6. **References** (references.bib): Added Wallimann et al. (2023), Clark et al. (2021), Schurter (2020), Huber & Imhof (2019) [minor 7]
7. **CO-AUTHOR EDIT comments**: Removed all 15 instances across .tex files [minor 9]
8. **Threshold sensitivity** (sec_robustness.tex): Added dual interpretation (cover bidding vs market selection) [minor 10]
9. **H2 framing** (sec_introduction.tex): Reframed H2 as "suggestive evidence consistent with" rather than "substantial evidence for" [referee condition 1]
10. **IV section** (sec_results.tex): Reframed as supplementary evidence; noted low partial R²; removed "bounds" language [M1d, M5]
11. **Network split** (sec_results.tex): Added explicit acknowledgment of ambiguity; cited alternative selection explanation [M4]
12. **Bajari-Ye** (sec_results.tex): Moved tender-FE table to main text; honest presentation of FL < non-FL reversal; acknowledged as "descriptive evidence of bid heterogeneity" [M2]
13. **Welfare** (sec_robustness.tex): Reframed as "back-of-the-envelope"; discussed negative high-suspicion estimate; removed "bounds" framing [M5]
14. **DiD** (sec_robustness.tex): Compressed to one-sentence reference to appendix [M6]

### B. Code Changes + Re-estimation (4 items)
1. **Conditional descriptive statistics** (M7): FE-residualized means for FL vs non-FL tenders → tab_conditional_descstats.tex
2. **FL subgroup characteristics** (M4c): Observable differences between competitive- vs concentrated-market FL firms → tab_fl_subgroup_chars.tex
3. **Alternative mechanisms** (referee 5.5): Firm age, geography, financial distress tests → tab_alternative_mechanisms.tex
4. **Imhof screen horse-race** (M8): Bid CV-based screen + horse-race regression → tab_screen_horserace.tex

### C. New Analyses (2 items)
1. **Enriched Bajari-Ye first stage** (M3): Added reference price, CNAE, firm age to bid regression
2. **Sensitivity-adjusted welfare** (M5c): Used Cinelli-Hazlett RV to compute adjusted welfare bound

### D. Structural Rewrites (3 items)
1. **Exclusion restriction** (sec_empirical_strategy.tex): Expanded into three labeled subparagraphs with specific evidence for each threat [minor 13]
2. **Bajari-Ye results** (sec_results.tex): Complete rewrite of Claim 3 with honest tender-FE presentation and two explicit interpretations [M2]
3. **Conclusion** (sec_conclusion.tex): Calibrated H2 from "substantial evidence" to "suggestive evidence consistent with"; reframed welfare [M5, condition 1]

### E. Items Not Addressed (require author decision)
1. **Figure 2 annotation** (minor 11): Requires re-running R figure code. Flagged for author.
2. **Bajari-Ye N tenders** (minor 5): Number of tenders with ≥2 FL bids needed from Bajari-Ye code. Flagged for author.
3. **Full Bartik decomposition** (M1b): Requires substantial new analysis; flagged for author decision.
4. **Time-lagged IV placebo** (M1c): Requires reconstruction of IV with t-2 lag; flagged for author decision.
5. **Reference price as DV normalization** (M3d): Requires re-running entire Bajari-Ye pipeline; flagged for author decision.

## Referee Comment Tracking

| Comment | Category | Status | Location in v5 |
|---------|----------|--------|----------------|
| M1 (IV fragile) | A+E | Partial — reframed IV as supplementary; Bartik/lagged IV flagged for author | sec_results.tex, sec_empirical_strategy.tex |
| M2 (Bajari-Ye tender FE) | A+D | Complete — honest presentation in main text | sec_results.tex:227-258 |
| M3 (Bajari-Ye first stage) | B+E | Partial — enriched first stage attempted; full re-run flagged | scripts/v5_new_analyses.R |
| M4 (Network split) | A+B | Complete — table header fixed, ambiguity acknowledged, subgroup chars reported | sec_results.tex, tab_network_split.tex |
| M5 (Welfare) | A+B | Complete — back-of-envelope framing, negative estimate discussed | sec_robustness.tex |
| M6 (DiD) | A | Complete — compressed to one sentence | sec_robustness.tex |
| M7 (Selection) | B | Complete — conditional descriptive statistics | tab_conditional_descstats.tex |
| M8 (Benchmark screens) | B | Partial — horse-race regression if data permits | tab_screen_horserace.tex |
| Minor 1 | A | Complete | sec_conceptual.tex |
| Minor 3 | A | Complete | tab_iv_first_stage.tex |
| Minor 4 | A | Complete | sec_data.tex |
| Minor 5 | E | Flagged for author | — |
| Minor 6 | A | Complete | tab_network_split.tex |
| Minor 7 | A | Complete | references.bib, sec_literature.tex |
| Minor 8 | A | Complete | sec_mechanisms.tex |
| Minor 9 | A | Complete | all .tex files |
| Minor 10 | A | Complete | sec_robustness.tex |
| Minor 11 | E | Flagged for author | — |
| Minor 12 | A | Complete | sec_robustness.tex |
| Minor 13 | D | Complete | sec_empirical_strategy.tex |
| Minor 14 | A | Complete | sec_frontmatter.tex |
| 5.5 alt mechanisms | A+B | Complete | sec_mechanisms.tex |
