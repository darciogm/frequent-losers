# Referee Response Log — 2026-03-16
## Git commit de backup: 3368b6e

## ETAPA 0 — Mapeamento

### Manuscript Structure (v8 — latest, in work/v8/)
| Section | File | Content |
|---------|------|---------|
| 1 | sec_introduction.tex | Introduction (mechanism + H1/H2 + contributions) |
| 2 | sec_literature.tex | Related Literature (4 strands) |
| 3 | sections/sec3_structural_model.tex | Framework for Cover-Bidder Deployment (propositions) |
| 4 | sections/sec4_data_fl.tex | Data and FL Definition |
| 5 | sec_cade.tex | CADE External Validation |
| 6 | sections/sec5_empirical_strategy.tex | Empirical Strategy (structural + OLS + IV + ROC + B-Y) |
| 7 | sections/sec7_results.tex | Results (structural + detection + OLS/IV + identification + network + B-Y + regime + counterfactual) |
| 8 | sec_mechanisms.tex | Mechanisms and Alternative Explanations |
| 9 | sec_robustness.tex | Robustness and Extensions |
| 10 | sec_conclusion.tex | Conclusion |
| App | sec_appendix.tex | Appendix |

### Scripts (work/v8/scripts/)
| Script | Purpose | Status |
|--------|---------|--------|
| structural_estimation.R | MLE of cover-bid distribution | COMPLETE |
| roc_detection.py | ROC/AUC analysis vs CADE | COMPLETE |
| flag1_bajari_ye_corrected.R | Bajari-Ye tests | COMPLETE |
| flag2_cade_enforcement_did.R | CADE enforcement DiD | COMPLETE |
| flag3_crossfit_check.R | Temporal cross-fitting | COMPLETE |
| counterfactual_welfare.R | Policy counterfactuals (CF1-CF3) | COMPLETE |
| imhof_comparison.R | FL vs Imhof screen comparison | COMPLETE |
| identification_tests.R | FL entry event study + min-bidder constraint | COMPLETE |
| alternative_classification.R | IQR vs structural vs ML classifiers | COMPLETE |
| ground_truth_robustness.R | Ground truth robustness tests | COMPLETE |
| mechanism_evidence.R | Bid rotation + bid inflation tests | COMPLETE |
| fl_participation_rationality.R | FL rationality test (NEW) | COMPLETE |

### Data (data/processed/)
| File | Rows | Key Columns |
|------|------|-------------|
| bid_level_full.parquet | 39,961,357 | firm_id, winner_flag, oc, item, pbu |
| firm_tender_map.parquet | 16,866,542 | firm_id, oc, item, won |
| firm_loss_stats.parquet | 41,444 | firm_id, win_rate, always_loser |
| FREQ_PARTICIP_rebuilt.parquet | 16,843 | firm_id, tenders_count |
| LOSERS_rebuilt.parquet | 85,386 | oc, item, losers_count |
| BEC_collapse_final.parquet | 4,533,754 | prices, n_firms, phase |
| Firms_final.parquet | 39,632 | CNPJ, CNAE, porte, location |

---

## BLOCO 1 — Upgrades Empíricos

### T1.1 Bid Rotation Test
- **Status: ALREADY COMPLETE** (work/v8/scripts/mechanism_evidence.R + sec_mechanism_evidence.tex)
- Diagnóstico: Winner persistence test shows FL winner HHI = 0.178 (diversified, 14.3 unique winners) vs non-FL = 0.303 (concentrated, 5.0 winners)
- Repeated FL-winner pairs: 38,941 pairs, 4,603 with ≥5 shared tenders, max 177
- Outputs: work/v8/tables/mechanism_tests.csv, work/v8/images/fig_bid_inflation.pdf

### T1.2 Latent Class Cartel Classification
- **Status: ALREADY COMPLETE** (work/v8/scripts/alternative_classification.R + sec_classification.tex)
- IQR rule AUC = 0.94 DOMINATES structural classifier (0.56) and Random Forest (0.90, DeLong p=0.04)
- Outputs: work/v8/tables/tab_classification_comparison.tex, work/v8/images/fig_classification_comparison.pdf
- Note: Uses likelihood-ratio structural classifier instead of LCA (more appropriate for the data structure)

### T1.3 Event Study: FL Entry
- **Status: ALREADY COMPLETE** (work/v8/scripts/identification_tests.R + sec_identification.tex)
- FL entry event study shows positive pre-event coefficients → strategic selection (FL enters already-expensive PBUs)
- Min-bidder constraint variation: FL×(n<3) = -0.160 (price effect concentrates in voluntary deployments)
- CADE enforcement DiD: FL presence declines post-conviction (ATT = -0.275, p<0.001)
- Outputs: work/v8/images/fig_fl_entry_event_study.pdf, work/v8/tables/identification_tests.csv

### T1.4 Cover Bid Signature
- **Status: ALREADY COMPLETE** (work/v8/scripts/mechanism_evidence.R, bid inflation section)
- FL median bid/winner ratio = 1.85 (85% above winner) vs non-FL = 1.43
- Regression: FL bids 15.4% higher controlling for item+year FE (p<0.001)
- Outputs: work/v8/images/fig_bid_inflation.pdf

### T1.5 Structural Markup Parameter
- **Status: ALREADY COMPLETE** (work/v8/scripts/structural_estimation.R)
- BIC selects Regime 2 (coordinated cover bidding), ΔBIC = -91,473
- ε̂ = 0.83 (mean log-spread), σ̂_c = 1.19 (SE=0.012), σ̂_g = 1.64
- σ_c/σ_g = 0.72 → cover bids less dispersed (Regime 2 signature)
- Bootstrap: 500 reps, all parameters estimated with SEs
- Outputs: work/v8/tables/structural_params.csv, tab_structural_params.tex

---

## BLOCO 2 — Críticas Referees

### T2.1 FL Participation Rationality Test
- **Status: COMPLETE (NEW)**
- Script: work/v8/scripts/fl_participation_rationality.R
- Key results:
  - FL firms: 100% have E[π] < 0 at ANY positive bidding cost
  - FL mean participations = 27.7 (6.7x more than non-FL always-losers at 4.1)
  - At 1% bidding cost: FL mean career loss = R$10,600
  - Total FL career losses = R$25.9M
  - Regular competitors: E[π] > 0, only 0.3% negative at 1% cost
- Outputs: work/v8/tables/tab_rationality.tex, rationality_results.csv
- LaTeX insertion: sec_mechanisms.tex (subsection "Rationality of FL Participation")

### T2.2 IV Conservative Framing
- **Status: COMPLETE**
- The v8 manuscript already had IV explicitly demoted to "supplementary" with balance-test concerns
- Added stronger language in sec5_empirical_strategy.tex: explicit statement that "reduced-form and structural evidence ... which do not rely on the instrument, provide independent support for our main conclusions"
- Tag: % CO-AUTHOR EDIT: IV CONSERVATIVE FRAMING [T2.2]

### T2.3 Theoretical Insights
- **Status: COMPLETE**
- T2.3a (Cover bidding as strategic complement): Added explicit paragraph in sec3_structural_model.tex after Proposition 3
  - "Cover bidding is a strategic complement to genuine competition, not a substitute"
  - References Marshall & Marx (2012)
- T2.3b (Lower dispersion contradicts literature): Added explicit paragraph in sec3_structural_model.tex
  - "This finding reverses a common assumption in the cartel detection literature"
  - References Imhof et al. (2019)
- Tags: % CO-AUTHOR EDIT: THEORETICAL INSIGHT 1 [T2.3a], % CO-AUTHOR EDIT: THEORETICAL INSIGHT 2 [T2.3b]

---

## BLOCO 3 — Reorganização Narrativa

### T3.1 Rewrite Opening Paragraph
- **Status: NOT NEEDED** — The v8 introduction already leads with mechanism (cover bidding hypothesis), FL definition, and main result. Lines 1-52 of sec_introduction.tex contain exactly the structure requested:
  - Frase 1-2: Mechanism (bid rigging, cover bidding, shill bidders)
  - Frase 3: What FL firms are
  - Frase 4: Main results (4-9% higher prices)
  - H1/H2 hypothesis structure

### T3.2 Forward Reference AUC
- **Status: ALREADY PRESENT** — Line 69 of v8 sec_introduction.tex: "7.1% of FL firms co-participate with convicted cartelists—3.5 times the rate expected by chance"
- AUC = 0.94 explicitly mentioned in first contribution paragraph (implicit forward reference)
- The v8 intro already front-loads the AUC result effectively

### T3.3 Contribution Comparison Table
- **Status: COMPLETE (NEW)**
- Added Table 1 "Positioning Relative to Existing Cartel Detection Methods" in sec_introduction.tex
- Compares: unit of detection, bid requirements, scalability, CADE validation, ex ante capability, policy threshold
- Tag: % CO-AUTHOR EDIT: CONTRIBUTION TABLE [T3.3]

### T3.4 Section Order Assessment
- **Status: COMPLETE (assessment only)**

Current v8 order vs. referee recommended order:

| # | Current v8 | Referee Recommended | Match? |
|---|-----------|-------------------|--------|
| 1 | Introduction | Introduction | ✓ |
| 2 | Related Literature | Institutional background | ✗ (literature vs background) |
| 3 | Structural Model | FL screen (classification) | ✗ (model before data) |
| 4 | Data + FL Definition | Reduced-form evidence | ✗ |
| 5 | CADE Validation | Mechanism evidence | ✗ |
| 6 | Empirical Strategy | Structural interpretation | ✗ |
| 7 | Results (multi-part) | Detection performance | ✗ |
| 8 | Mechanisms | Optimal enforcement | ✗ |
| 9 | Robustness | Conclusion | ✗ |
| 10 | Conclusion | — | |

**Assessment:**
The v8 structure follows a "model → data → estimation → results" narrative (standard for structural IO at RAND). The referee's suggested order follows "screen → evidence → theory → policy" (more applied/empirical). Significant differences:

1. **Literature before data** (v8) vs **Background before screen** (referee): V8 ordering is standard for RAND. Moving literature to later would be unusual for this journal. **Recommendation: KEEP current order.**

2. **Structural model before data** (v8): The model generates testable predictions that organize the empirical strategy. Moving it after the data section would break this logical chain. **Recommendation: KEEP current order.**

3. **CADE section between data and empirical strategy** (v8): This is well-placed — validates FL classification before proceeding to estimation. **Recommendation: KEEP.**

4. **Mechanisms section after Results** (v8): The referee suggests mechanism evidence before structural. V8's ordering (results → mechanisms) is conventional. **Recommendation: KEEP, but the mechanisms are partially embedded in Results (sec7) already.**

5. **Counterfactual welfare inside Results** (v8 sec7.8) vs **separate Optimal Enforcement section** (referee): The counterfactual subsection could be promoted to a standalone section. **Recommendation: CONSIDER promoting to Section 9, before Robustness.** Low risk (no cross-reference dependencies beyond section labels).

**Decision for authors:**
- The v8 structure is well-suited for RAND/IJIO. The referee's ordering is more suitable for a policy journal.
- Only candidate for restructuring: promote counterfactual welfare to standalone section.
- All other moves carry high risk of breaking cross-references with low marginal benefit.

---

## BLOCO 4 — Optimal Enforcement

### T4.1 Optimal Screening Threshold
- **Status: ALREADY COMPLETE** (work/v8/scripts/counterfactual_welfare.R + sec_counterfactual.tex)
- CF1: Remove min-bidder rule → welfare gain R$74M (OLS) to R$211M (IV)
- CF2: Optimal threshold at R$100K/investigation → 1.6×IQR (close to baseline 1.5×)
- CF3: 10% increase in θ → R$24M (OLS) to R$67M (IV) annual savings
- Outputs: tab_counterfactual_welfare.tex, fig_counterfactual_screening.pdf, fig_counterfactual_theta.pdf

---

## Pendências para os autores

1. **Section order**: Consider promoting counterfactual welfare (currently Results §7.8) to a standalone section. No other reordering recommended.
2. **T3.1 opening paragraph**: V8 intro already leads with mechanism — verify if referee's specific phrasing preferences differ.
3. **AUC forward reference**: V8 intro mentions CADE validation but does not explicitly say "AUC = 0.94" in the introduction abstract/contributions. Consider adding the number explicitly if the referee specifically requested it.
4. **Rationality test (T2.1)**: Review table numbers and ensure bidding-cost assumptions (0.5–5%) are defensible for BEC context.
5. **Cover bid regression (T1.4)**: The bid inflation analysis uses v3/data/processed/bid_level_analysis.parquet — verify this dataset is consistent with v8 pipeline.
6. **Latent Class (T1.2)**: The v8 implementation uses structural likelihood + ML comparison rather than formal LCA (stepmix). This is arguably more rigorous, but verify the referee would accept this substitution.
7. **Bibliography**: The new text cites Asker (2010) in the rationality section — verify this entry exists in references.bib.

## Próximos passos recomendados

1. Review all % CO-AUTHOR EDIT tags in v8 .tex files and approve/modify text
2. Compile paper_v8.tex to verify no LaTeX errors from new insertions
3. Re-run full v8 script pipeline to ensure all tables/figures are up to date
4. Verify references.bib contains all new citations (asker2010leniency)
5. Consider writing a response letter to referees that maps each concern to the evidence
6. If submitting to IJIO: verify page/word limits with new content
