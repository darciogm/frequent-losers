## Revision Log: paper_v9 → paper_v10

### TASK 1 — Regime 1/2 dispersion reconciliation
- Files changed: `sec_appendix.tex`, `sections/sec7_results.tex`
- Lines changed: +12 added, 0 deleted
- Summary: Added reconciliation paragraph in Appendix E (Regime Test) explaining that Table E.2 measures pooled tender dispersion (which rises with FL count because cover bids above b* widen the distribution) while σ̂_c/σ̂_g = 0.72 measures individual-bid dispersion (which selects Regime 2). Forward-reference parenthetical added in sec7 Regime selection paragraph.
- ⚠️ Warnings: None.

### TASK 2 — Pre-trend / H2 reconciliation
- Files changed: `sections/sec_identification.tex`, `sec_literature.tex`, `sec_conclusion.tex`
- Lines changed: +18 added, 7 deleted
- Summary: Expanded event-study paragraph to frame pre-trend as strategic market selection complementary to cover-bidding causation (not contradictory). Explained that OLS with item/year/PBU FE absorbs price levels, so conditional β is not contaminated by selection. Referenced M3 reverse-causality test (elasticity 0.004). Added Porter-Zona (1993) connection in literature. Added "strategic market selection" to conclusion H2 summary.
- ⚠️ Warnings: Fixed double-"and" in conclusion created by Task 2(c) insertion.

### TASK 3 — IV role clarification
- Files changed: `sections/sec5_empirical_strategy.tex`, `sections/sec7_results.tex`, `tables/tab_counterfactual_welfare.tex`, `output/tables/tab_welfare_bounds.tex`
- Lines changed: +22 added, 18 deleted
- Summary: Reframed IV throughout as measurement-error correction for binary FL misclassification, not as a clean causal instrument. Lead motivation: classical binary measurement error attenuates OLS → IV corrects by integrating over misclassification via aggregate supply variation. Upper-bound interpretation kept for two explicit reasons: (i) balance imbalance matters for clean causal but not for attenuation correction; (ii) LATE restricts to compliers. Counterfactual table header changed to "IV Upper Bound". Welfare bounds table notes aligned.
- ⚠️ Warnings: None. Same equation (eq:iv_v6) preserved.

### TASK 4 — Contributions count
- Files changed: None
- Lines changed: 0
- Summary: Verified consistency. Section 1.1 says "three contributions" with First/Second/Third enumeration. Abstract describes results narratively without specifying a count. Both are internally consistent. No fix needed.
- ⚠️ Warnings: None.

### TASK 5 — Structural model value-added
- Files changed: `sections/sec3_structural_model.tex`
- Lines changed: +8 added, 0 deleted
- Summary: Added two sentences after the "three aims" list in Section 3 opening: (1) regime identification is the model's primary empirical contribution; (2) unlike Bajari-Ye (2003), the framework uses FL classification as known partition, eliminating EM and directly identifying the cover-bid regime. The "structural parameters characterize mechanism; markup is identified by reduced-form" sentence is already early in sec7.4 (line 192) — no move needed.
- ⚠️ Warnings: None.

### TASK 6 — AUC caveat
- Files changed: `sections/sec7_results.tex`, `sec_literature.tex`
- Lines changed: +12 added, 5 deleted
- Summary: Added 3-sentence caveat paragraph in sec7 Detection Performance: (1) comparison is indicative, not definitive, due to different task structures; (2) ground truth constructed from participation data may inflate TPR for high-participation firms; (3) FL screen's advantage is data requirements, not categorical superiority. Shortened literature footnote to reference the new body caveat.
- ⚠️ Warnings: None.

### Final checks
- pdflatex: PASS — 67 pages, zero errors
- Cross-references: OK — zero undefined references across 3 compilation passes
- Abstract aligned: YES — "3.6–6.4%" consistent in abstract, intro, sec7, conclusion; "three contributions" consistent; AUC = 0.94 present with caveat in sec7
- Git commit: `30e8051`
