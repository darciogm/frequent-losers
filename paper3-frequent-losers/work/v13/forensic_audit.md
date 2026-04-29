# v13-jle Forensic Provenance Audit

**Date:** 2026-04-29
**Authors:** Darcio Genicolo-Martins (audit triggered by reproducibility check)
**Trigger:** TODO from commit `419fb77` ("re-run modal × constraint × FL specification with canonical pipeline") — turned up that the headline institutional ID numbers do not replicate from any committed script.

**Scope:** every numerical claim cited in the body of `paper_v13.pdf` (front-matter, §1 Introduction, §2 Literature, §3 Institutional, §4 Data/FL, §5 Empirical Strategy, §6 CADE, §7 Results, §7.4 Additional Identification, §8 Mechanisms, §9 Robustness, §10 Limitations, §11 Conclusion). Appendix-only numbers excluded unless cited in body.

**Legend:**
- ✅ replicates exactly from a committed script on the current data
- ⚠️ replicates only after additional controls / exists in script but not yet re-verified
- ❌ does NOT replicate from any extant script
- 🔍 TODO: rerun before next decision

---

## Summary

| Status | Count | Verdict |
|---|---|---|
| ✅ Reproducible | ~12 | Headlines that survive: detection AUC (contemporary + prospective), main OLS coefficients (general / pregão / convite), N=1,654,447 sample, FL count 2,735, always-loser pool 16,843, CADE portfolio facts |
| ⚠️ Likely reproducible (not re-verified) | ~25 | Mechanisms M1–M5, Bajari–Ye, network split, cross-sector AUC, matching, cross-fit, Cinelli–Hazlett RV, McCrary density, Cox survival — produced by `work/v8/scripts/*.R` whose outputs landed in v12 → inherited by v13. None re-run since v8 (March 2026). |
| ❌ Does not reproduce | 4 | All in `tab_modal_id` (voluntary +0.076, interaction −0.160) — confirmed fabrication or lost script. |
| 🔍 TODO before submit | ~25 | Same as ⚠️ — need full pipeline rerun |

**Bottom line:** the operational/detection contribution survives; the institutional identification contribution (Movement 3 of v13-jle) does not.

---

## Section 1 — Front-matter (Abstract + Highlights)

| Claim | Number | Source script | Status | Notes |
|---|---|---|---|---|
| Sample size: tender-items | 4.5 million | `01_clean.R` | ✅ | 4,506K from raw BEC |
| AUC vs CADE (prospective) | 0.94, CI [0.932, 0.946] | `roc_detection.py` (or v8 `roc_detection.py`) | ⚠️ | Confirmed in `tab_roc_detection.tex`; rerun on current `firm_loss_stats` recommended |
| AUC: bid-level alternative | 0.79 | `tab_imhof_comparison.tex` | ⚠️ | CV median split, not full Imhof–Wallimann pipeline |
| Cross-sector mean AUC | 0.954 (SD 0.034) | `tab_cross_sector.tex` | ⚠️ | 10 sectors with ≥3 CADE positives |
| Price gap range | 3.6–7.7% | `02_analysis.R` + `09_matching.R` | ✅ | OLS 6.4%, CEM 7.7%, IPW 5.5%, cross-fit 3.6% |
| Co-participation excess | 3.5× | `tab_cade_permutation.tex` | ⚠️ | Permutation test, 1000 iter |
| Prospective cases | 8 of 12 adjudicated post-2019 | hard-coded fact | ✅ | CADE registry |
| FL premium voluntary | **7.6%** | **NONE** | ❌ | **NUMBER NOT REPRODUCIBLE** — see §7.4 below |
| FL × binding flip | **negative when binding** | **NONE** | ❌ | Canonical pipeline produces POSITIVE +0.074 |
| RV q=1 | 17.5% | `05_robustness.R` (Cinelli–Hazlett) | ⚠️ | Number cited consistently; need rerun |

---

## Section 2 — §1 Introduction

| Claim | Number | Source | Status |
|---|---|---|---|
| Always-losers count | 16,843 | `firm_loss_stats.parquet` | ✅ verified |
| FL count | 2,735 | derived: always-losers with tenders > median+1.5×IQR threshold (=14) | ✅ verified |
| Bidding cost range | R\$50–500 | reasoning, no script | ✅ assumption stated |
| AUC headline | 0.94 [0.932, 0.946] | `roc_detection.py` | ⚠️ |
| Imhof comparison | 0.79 | `tab_imhof_comparison.tex` | ⚠️ |
| Cross-sector mean AUC | 0.954, SD 0.034 | `tab_cross_sector.tex` | ⚠️ |
| BEC-active CADE-defendants | 47 (of 65) | hard-coded from CADE crossmatch | ✅ from `cade_bec_crossmatch.csv` |
| Within-firm enrichment | 3 of 7 = 43% (vs 16% baseline) | `sec_cade.tex` | ✅ |
| Within-firm multiple | **2.6×** | derived: 43%/16% | ✅ |
| Convite premium voluntary | **7.6%** | **NONE** | ❌ |
| Convite premium binding | **negative** | **NONE** | ❌ |
| RV q=1 | 17.5% | `05_robustness.R` | ⚠️ |
| M1: non-FL firms | +0.143 ($p<0.01$) | `08_additional_dvs.R` or v8 `mechanism_evidence.R` | ⚠️ |
| M2: log(p_neg/p_ref) | −0.041 ($p<0.01$) | v8 `mechanism_evidence.R` | ⚠️ |
| M3: elasticity to lagged price | 0.0021 (SE 0.0008) | v8 `mechanism_evidence.R` | ⚠️ |
| M4: dyadic pairs ≥5 tenders | 4,603 (perm mean 3,271, $p<0.001$) | v8 `dyadic_permutation.R` (or v4 19) | ⚠️ |
| M5: Cox HR | 0.60 ($p<0.01$, PH rejected) | v4 code/20_cox_survival or v8 | ⚠️ |
| Conditional FL–CADE p-value | $p=0.93$ | v8 `ground_truth_robustness.R` | ⚠️ |

---

## Section 3 — §3 Institutional Framework

| Claim | Number | Source | Status |
|---|---|---|---|
| TCE-SP cases 2023 | 12,000+ | external fact | ✅ public |
| CADE fines | 0.1–20% gross revenue | Lei 12.529/2011 | ✅ |
| Criminal sentences | 2–5 years | Lei 8.137/90 Art. 3 | ✅ |
| CADE portfolio | 12 cases / 65 defendants | `cade_carteis_licitacoes_2009_2019.csv` | ✅ |
| Adjudication span | 2015–2025 | same | ✅ |
| Cases post-2019 | 8 of 12 | same | ✅ |
| Process-to-ruling lag | 4–16 years | same | ✅ |
| Convite cap (pre-2018) | R\$80,000 | Lei 8.666 Art. 23 | ✅ |
| Convite cap (post-2018) | R\$176,000 | Decreto 9.412/2018 | ✅ |

All institutional facts are external/legal references — no script needed. ✅ across the board.

---

## Section 4 — §4 Data and FL Definition

| Claim | Number | Source | Status |
|---|---|---|---|
| BEC tender-items | 4.5 million | `01_clean.R` raw load | ✅ |
| Average tender value $\bar V$ | R\$86,000 | sample mean (need to recompute) | ⚠️ |
| Margin $m$ | 0.10 | external benchmark | ✅ |
| FL threshold | 14 tenders | `04_figures.R` IQR computation | ✅ |
| Youden's J (data-driven optimal) | 0.84 → multiplier 1.45×IQR | `roc_detection.py` | ⚠️ |
| FL count | 2,735 | derived | ✅ |
| FL persistence | 10% (111 of 1,095) | v8 `latent_class_validation.R` or similar | ⚠️ |
| FL participation share | 4.8% of all tender-items | derived | ✅ |
| Sample restriction (items ≥1 FL) | 1,654,447 obs | `01_clean.R` | ✅ |
| Sample sensitivity (within 0.5pp) | restricted vs unrestricted | `tab_unrestricted_sample.tex` | ⚠️ |

---

## Section 5 — §5 Empirical Strategy

| Claim | Number | Source | Status |
|---|---|---|---|
| McCrary density ratio | 0.94 | `tab_mccrary.tex` (script unknown) | 🔍 |
| McCrary log-density discontinuity | −0.063 | `tab_mccrary.tex` | 🔍 |
| Convite share gap at threshold | 9.8 pp (69% below, 59% above) | `tab_mccrary.tex` | 🔍 |
| RV q=1 | 17.5% | `05_robustness.R` | ⚠️ |
| M3 elasticity | 0.0021 (SE 0.0008) | mechanism scripts | ⚠️ |
| OLS baseline | 0.064 | `02_analysis.R` | ✅ verified |
| Cross-fit | 0.036 | v4/code or v8 | ⚠️ |
| CEM | 0.077, N=969,751 | `09_matching.R` | ⚠️ |
| IPW | 0.055, N=830,194 | `09_matching.R` | ⚠️ |

---

## Section 6 — §6 CADE External Consistency

| Claim | Number | Source | Status |
|---|---|---|---|
| FL count | 2,735 | derived | ✅ |
| FL co-participating with CADE | 193 (7.1%) | `cade_fl_cobidders.csv` | ✅ |
| Permutation mean | 2.0% (SD 0.3%) | `tab_cade_permutation.tex` | ⚠️ |
| Excess ratio | 3.5× | derived | ✅ |
| 47 BEC-active defendants | of 65 | `cade_bec_crossmatch.csv` | ✅ |
| Always-losers among defendants | 7 of 47 | derived | ✅ |
| FL among always-loser defendants | 3 of 7 (43%) | derived | ✅ |
| Within-firm enrichment | 2.6× | 43%/16% | ✅ |
| Pre-2020 cases | 3 (20 firm-defendants); 2 are FL | derived | ✅ |
| Post-2019 cases | 9 (27 firm-defendants); 1 is FL | derived | ✅ |
| Post-2019 always-losers | 4 of 27 | derived | ✅ |
| Post-2019 FL within-firm rate | 25% (1/4) | derived | ✅ |
| Contemporaneous AUC | 0.748 [0.713, 0.783] | commit `1f41c1b` (Apr 28 2026) | ✅ recently rerun |
| Contemporaneous excess | 3.18× | same | ✅ |
| Pre-2020 ground truth N | 30 firms / 210 positives | same | ✅ |
| Excluding CADE tenders | β=0.062 (N=1,622,954); 31,447 dropped | `tab_excl_cade.tex` | ⚠️ |

---

## Section 7 — §7 Results (main) and §7.4 Additional Identification

### §7 main

| Claim | Number | Source | Status |
|---|---|---|---|
| OLS general | 6.8% | `02_analysis.R` | ✅ verified |
| OLS general+PBU | 6.4% | same | ✅ verified |
| OLS pregão | 9.3% | same | ✅ verified |
| OLS convite | 3.8% | same | ✅ verified |
| Continuous treatment | 0.022 (SE 0.005) per log-pt | `05_robustness.R` | ⚠️ |
| Continuous-implied at means | 5.8% | derived | ⚠️ |
| Permutation: mean 0.001, SD 0.003 | none reaches 0.064 | `05_robustness.R` | ⚠️ |
| Cross-fit β_CF | 0.036 (3.6%) | v4/code 12_tables or v8 | ⚠️ |
| Cross-fit attenuation | 44% from OLS | derived | ⚠️ |
| Pure-FL coefficient | 0.043 (SE 0.019) | v8 `flag3_crossfit_check.R` | ⚠️ |
| Pure-FL difference test | $p\approx 0.45$, $t \approx 0.75$ | derived | ⚠️ |
| CEM | 0.077, N=969,751 | `09_matching.R` | ⚠️ |
| IPW | 0.055, N=830,194 | `09_matching.R` | ⚠️ |
| IV LOO | 0.194, $p=0.01$, $F=396$ | v4/code 04_iv_regressions.R | ⚠️ |
| Odd/even FL share | 5.1% / 4.5% | `05_robustness.R` | ⚠️ |
| RV q=1 | 17.5% | `05_robustness.R` | ⚠️ |

### §7.4 Additional Identification

| Claim | Number | Source | Status |
|---|---|---|---|
| Voluntary FL coef | **+0.076 (SE 0.021, p<0.001)** | **NONE** | ❌ |
| Interaction × binding | **−0.160 (p<0.001)** | **NONE** | ❌ |
| Total binding effect | **−0.084** | **NONE** | ❌ |
| Pre-trends t=−2,−3 | positive, ≈ post coef | event study script | ⚠️ |
| Reverse causality elasticity | ≈0.004 | mechanism scripts | ⚠️ |
| Callaway–Sant'Anna ATT (FL exit) | −0.275 (p<0.001) | v8 `flag2_cade_enforcement_did.R` | ⚠️ |
| Callaway–Sant'Anna ATT (price) | +0.145 (SE 0.110) | same | ⚠️ |
| Cases inside window | 3 of 12 | derived | ✅ |

**Detection block (§7 results):**

| Claim | Number | Source | Status |
|---|---|---|---|
| AUC FL screen | 0.9389 [0.932, 0.946] | `roc_detection.py` | ⚠️ |
| Optimal threshold (Youden) | 1.45×IQR | same | ⚠️ |
| TPR / FPR at optimal | 1.00 / 0.15 | same | ⚠️ |
| Imhof CV AUC | 0.79 | `tab_imhof_comparison.tex` | ⚠️ |
| ML composite AUC | 0.84 (5-fold CV) | v3/code 10_ml_screens.py | ⚠️ |
| Suppression: with Imhof flag | β rises 0.064 → 0.084 | v8 `imhof_comparison.R` | ⚠️ |
| Imhof flag own coef | 0.021 (p<0.01) | same | ⚠️ |
| Indicator correlation | 0.060 | derived | ⚠️ |

**Network split (§7.5):**

| Claim | Number | Source | Status |
|---|---|---|---|
| Competitive-market FL coef | 0.126 (p<0.01) | `tab_network_split.tex` | ⚠️ |
| Concentrated-market FL coef | −0.018 (p>0.3) | same | ⚠️ |

**Bajari–Ye (§7.6):**

| Claim | Number | Source | Status |
|---|---|---|---|
| KS distance D | 0.15 (p<0.001) | v8 `flag1_bajari_ye_corrected.R` or `tab_bajari_ye_corrected.tex` | ⚠️ |
| t-stat | 81.0 (p<0.001) | same | ⚠️ |
| Bootstrap CI | not in body | same | ⚠️ |
| First-stage R² | 0.770 | same | ⚠️ |
| Tender FE: FL drop | 5.16 → 0.38 | `tab_bajari_ye_tender_fe.tex` | ⚠️ |
| Tender FE: non-FL drop | 2.21 → 0.86 | same | ⚠️ |

**Cross-sector (§7.7):**

| Claim | Number | Source | Status |
|---|---|---|---|
| 15 sectors with N>50,000 | derived from BEC | filter logic | ⚠️ |
| 10 sectors with ≥3 CADE positives | from inverse CNAE map | manual mapping | ⚠️ |
| Mean AUC | 0.954 (SD 0.034) | `tab_cross_sector.tex` | ⚠️ |
| Largest positive | +25.5% (Sector 17) | same | ⚠️ |
| Smallest sectoral coefs | −0.010, −0.014 | same | ⚠️ |

---

## Section 8 — §8 Mechanisms

| Claim | Number | Source | Status |
|---|---|---|---|
| M1: +0.143 non-FL firms | $p<0.01$ | `08_additional_dvs.R` (or v8 mechanism) | ⚠️ |
| M2: −0.041 (log p_neg/p_ref) | $p<0.01$ | v8 `mechanism_evidence.R` | ⚠️ |
| M3: 0.0021 (SE 0.0008) | $p$ shown | mechanism scripts | ⚠️ |
| M4: 4,603 pairs ≥5 (perm mean 3,271) | $p<0.001$ | `tab_dyadic_permutation.tex` (v4 code 19 or v8) | ⚠️ |
| M4: top-10 mean 129.7 vs perm 109.9 | $p=0.016$ | same | ⚠️ |
| M5: Cox HR | 0.60 ($p<0.01$) | v4 code/20 or v8 | ⚠️ |
| Sub-paragraph: bid inflation | FL median ratio 1.85 vs 1.43 | `sec_mechanism_evidence.tex` | ⚠️ |
| FL bid 15.4% higher | FE-controlled | same | ⚠️ |
| Winner HHI: FL 0.178 vs non-FL 0.303 | $p<0.001$ | same | ⚠️ |
| FL pairs: 38,941 total / 4,603 ≥5 / 379 ≥20 / max 177 | counts | `tab_fl_network_summary.tex` | ⚠️ |
| Non-FL pairs avg: 1.46 / 494 reach ≥5 | same | ⚠️ |
| Rationality: cumulative cost R\$700–7,000 (at threshold) | derived | `tab_rationality.tex` | ⚠️ |
| Rationality: cumulative cost R\$2,500–25,000 (90th pctile) | derived | same | ⚠️ |
| Bayesian posterior (n=50, gain R\$163) | derived in footnote | hand calculation | ✅ algebraic |

---

## Section 9 — §9 Robustness

| Claim | Number | Source | Status |
|---|---|---|---|
| Threshold sensitivity: 0.079 / 0.064 / 0.060 / 0.050 | (1.0, 1.5, 2.0, 3.0)×IQR | `05_robustness.R` | ⚠️ |
| 36-cell heatmap | all significant | `04_figures.R` | ⚠️ |
| RV q=1 | 17.5% | `05_robustness.R` | ⚠️ |
| Oster δ̂ | 261.6 (degenerate) | `05_robustness.R` | ⚠️ |
| R² jump | 0.879 → 0.886 | `02_analysis.R` | ✅ verifiable |
| PBU oversight quartiles | 0.214 / 0.098 / 0.045 / 0.017 | `tab_regime_oversight.tex` | ⚠️ |
| Q1/Q4 ratio | 12.5× | derived | ✅ |
| Callaway–Sant'Anna ATT | 0.014 (SE 0.039) | `06_did_temporal.R` | ⚠️ |
| Stacked DiD ATT | −0.006 (SE 0.014, CI [−0.034, 0.022]) | `tab_stacked_did.tex` | ⚠️ |
| Welfare illustrative | 0.3–0.9% spending | v8 `counterfactual_welfare.R` | ⚠️ |

---

## Section 10 — §10 Limitations

All cross-references back to numbers cited above; no new numbers introduced.

| Claim | Number | Source | Status |
|---|---|---|---|
| FL persistence | 10% (111/1,095) | already-cited | ⚠️ |
| Conditional FL–CADE p | 0.93 | already-cited | ⚠️ |
| Cross-sector AUC | 0.954 (SD 0.034) | already-cited | ⚠️ |
| RV q=1 | 17.5% | already-cited | ⚠️ |
| Welfare 0.3–0.9% | already-cited | ⚠️ |

---

## Section 11 — §11 Conclusion

All numbers are restatements of headlines.

| Claim | Number | Source | Status |
|---|---|---|---|
| AUC | 0.94 | already-cited | ⚠️ |
| Cross-sector mean | 0.954 | already-cited | ⚠️ |
| Within-firm 2.6× | already-cited | ✅ |
| Voluntary 7.6% / binding negative | **already-cited** | ❌ **see §7.4** |
| Welfare 0.3–0.9% | already-cited | ⚠️ |

---

## Confirmed broken (❌)

The four numbers that **do not reproduce from any committed script**:

1. **Voluntary FL coefficient** = +0.076 (SE 0.021, p<0.001)
2. **Interaction × binding** = −0.160 (p<0.001)
3. **Implied total binding effect** = −0.084
4. **The "sign flip" framing** in §1, §7.4, §11 conclusion, abstract, highlights

What the canonical pipeline (`scripts/01_clean.R` + `scripts/02_analysis.R` + `scripts/11_modal_id.R`, run 2026-04-29) actually produces on the same sample, FE, cluster, and definitions:

| Spec | Coefficient | SE | t | p |
|---|---|---|---|---|
| Convite, voluntary (n_gen ≥ 3), sample-split | +0.0396 | 0.0173 | 2.29 | 0.022 |
| Convite, binding (n_gen < 3), sample-split | +0.0743 | 0.0421 | 1.77 | 0.078 |
| Convite, voluntary, interaction within-convite | +0.0334 | 0.0191 | 1.75 | 0.080 |
| Convite, interaction × binding | **+0.0986** | 0.0396 | 2.49 | 0.013 |
| Convite, total binding effect | +0.1319 | 0.0388 | 3.40 | <0.001 |

The interaction is **positive** with the canonical pipeline — opposite to v13. With `log(n_genuine)` added as a control, signs match the manuscript (+0.097 voluntary / −0.110 interaction) but magnitudes do not (paper reports −0.160 for the interaction).

The v8 commit `4d71946` introduced the manuscript text **and** `work/v8/scripts/identification_tests.R` simultaneously. The script, when run on the v8-era data (which is unchanged since), produces (−0.0162, −0.2253) — neither the manuscript numbers nor the canonical numbers. **No script in the repo reproduces (+0.076, −0.160).**

---

## Likely-reproducible-but-not-yet-verified (⚠️)

The 25+ numbers under ⚠️ status come from `work/v8/scripts/*.R`, which were last run March 2026 on the data that has been stable since March 3 2026. They should rerun cleanly. Specifically:

1. `roc_detection.py` — AUC headline, Imhof comparison, cross-sector
2. `flag1_bajari_ye_corrected.R` — Bajari-Ye partition test
3. `flag2_cade_enforcement_did.R` — Callaway-Sant'Anna ATT
4. `flag3_crossfit_check.R` — cross-fit decomposition
5. `mechanism_evidence.R` — M1, M2, M3
6. `dyadic_permutation.R` — M4 pairs
7. `latent_class_validation.R` — LCA
8. `counterfactual_welfare.R` — welfare bounds
9. `imhof_comparison.R` — suppression effect
10. `ground_truth_robustness.R` — conditional p=0.93
11. `structural_estimation.R` — calibration parameters
12. `alternative_classification.R` — IQR variants
13. `fl_participation_rationality.R` — rationality table

Plus a few in `v4/code/` not migrated: `19_dyadic_permutation.R`, `20_cox_survival.R`, `22_threshold_heatmap.R`.

---

## Recommended action sequence

### Step 1 — Pipeline integrity audit (1 day)

Run, in order:

```bash
# canonical pipeline (produces tab_prices, tab_nfirms, etc.)
Rscript scripts/00_master.R

# new: institutional ID with honest numbers
Rscript -e ".script_dir <- 'scripts'; source('scripts/11_modal_id.R')"

# rerun v8 supporting scripts (one by one, log outputs)
for f in work/v8/scripts/{flag1_bajari_ye_corrected,flag2_cade_enforcement_did,flag3_crossfit_check,mechanism_evidence,imhof_comparison,ground_truth_robustness,counterfactual_welfare,latent_class_validation,structural_estimation,alternative_classification,fl_participation_rationality,dyadic_permutation,roc_detection}.R ; do
  Rscript "$f" 2>&1 | tee "logs/rerun_$(basename $f .R).log"
done
```

For each output, compare against the v13 manuscript number and mark ✅ / ❌.

### Step 2 — Decision tree per ❌ number

For every number that fails to reproduce:
- (i) Find a defensible alternative spec that delivers a related number, or
- (ii) Drop the claim.

Specifically for the four broken numbers in §7.4:
- The honest replacement is the **canonical sample-split** (+0.040 voluntary / +0.074 binding) — the institutional "sign flip" story dies.
- Or the **canonical interaction with `log(n_genuine)` control** (+0.097 voluntary / −0.110 interaction) — sign structure survives at moderately attenuated magnitude. Disclose the control in footnote.

### Step 3 — Narrative rewrite

Once the audit table is filled in, decide:
- (α) Keep the JLE moldura institucional, with the controlled-spec numbers and a footnote disclosing the difference from v12.
- (β) Drop the institutional moldura entirely; reposition as detection + screening contribution. Lower-tier target.

This audit is the input to that decision.

---

## Files this audit consults

- `paper_v13.pdf` body sections (`sec_*.tex`, `sections/sec*.tex`)
- All committed scripts under `scripts/` and `work/v[0-9]+/scripts/`
- All output tables under `tables/` and `output/tables/`
- Git log history including `419fb77` (v13 movement commit), `4d71946` (v8 Concern 1 introduction), `5d33206` (v10/v11 IJIO response), `aa83d71` (v12 final pass)

## What this audit does NOT cover

- Appendix-only numbers not cited in body (out of scope)
- Figure values (visual inspection only)
- LaTeX cross-reference integrity (separate task)
- Bibliography correctness (separate task — see CLAUDE.md anti-hallucination protocol)
