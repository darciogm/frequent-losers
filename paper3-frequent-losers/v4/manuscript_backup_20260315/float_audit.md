# Float Numbering & Positioning Audit — paper_v4.pdf

**Date:** 2026-03-05
**Pages:** 59 | **Errors:** 0 | **Undefined refs:** 0 | **Overfull hboxes >20pt:** 0

---

## Problem Found & Fixed

**Root cause:** `\appendix` in `paper_v4.tex` (line 89) changed section numbering to letters (A, B, C...) but did NOT reset table/figure counters. Result: appendix floats numbered A.13, B.15, etc. instead of A.1, B.1, etc.

**Fix applied:** Added counter reset commands after `\appendix`:
```latex
\setcounter{table}{0}
\setcounter{figure}{0}
\renewcommand{\thetable}{\Alph{section}.\arabic{table}}
\renewcommand{\thefigure}{\Alph{section}.\arabic{figure}}
\makeatletter
\@addtoreset{table}{section}
\@addtoreset{figure}{section}
\makeatother
```

---

## Final Float Manifest

### Main Body (Tables 1–12, Figures 1–6)

| # | Label | Caption (short) | Page | Source |
|---|-------|----------------|------|--------|
| Table 1 | `tab:modality_year` | Tender Counts by Modality/Year | 9 | sec_data |
| Figure 1 | `fig:losses` | FL distribution | 10 | sec_data |
| Figure 2 | `fig:iqr` | IQR identification | 11 | sec_data |
| Table 2 | `tab:descstats` | Descriptive Statistics | 11 | sec_data |
| Table 3 | `tab:cade_permutation` | CADE Validation | 13 | sec_cade |
| Table 4 | `tab:excl_cade` | Excl. CADE Markets | 15 | sec_cade |
| Table 5 | `tab:prices` | Negotiated Prices | 19 | sec_results |
| Table 6 | `tab:nfirms_excl` | Genuine Firms | 20 | sec_results |
| Figure 3 | `fig:coef_summary` | Coefficient summary | 20 | sec_results |
| Table 7 | `tab:iv_first_stage` | IV First Stage | 21 | sec_results |
| Table 8 | `tab:iv_main` | 2SLS Estimates | 22 | sec_results |
| Figure 4 | `fig:first_stage` | First-stage binscatter | 24 | sec_results |
| Table 9 | `tab:network_split` | Network Split | 25 | sec_results |
| Table 10 | `tab:fl_network_summary` | Network Metrics | 25 | sec_results |
| Table 11 | `tab:bajari_ye` | Bajari-Ye Tests | 26 | sec_results |
| Figure 5 | `fig:regime_densities` | Regime densities | 29 | sec_results |
| Table 12 | `tab:mechanisms` | Mechanism Tests | 31 | sec_mechanisms |
| Figure 6 | `fig:threshold_stability` | Threshold stability | 36 | sec_robustness |

**Citation order:** Tables 1→12 sequential ✓ | Figures 1→6 sequential ✓

### Appendix A — Additional Competition Outcomes

| # | Label | Caption (short) | Page |
|---|-------|----------------|------|
| Table A.1 | `tab:nfirms` | Number of Firms | 42 |
| Table A.2 | `tab:nbids` | Number of Bids | 42 |

### Appendix B — Robustness Checks (18 tables, 2 figures)

| # | Label | Caption (short) | Page |
|---|-------|----------------|------|
| Table B.1 | `tab:threshold` | IQR Threshold Sensitivity | 43 |
| Table B.2 | `tab:fl_lowwinrate` | Low-Win-Rate Variants | 43 |
| Table B.3 | `tab:fl_crossfit` | Cross-Fitting | 43 |
| Table B.4 | `tab:fl_temporal` | Rolling Window | 44 |
| Table B.5 | `tab:unrestricted_sample` | Unrestricted Sample | 44 |
| Table B.6 | `tab:homogeneous_cv` | Price Homogeneity | 44 |
| Table B.7 | `tab:tighter_controls` | Tighter Controls | 45 |
| Table B.8 | `tab:matching` | Matching (CEM/IPW) | 45 |
| Table B.9 | `tab:clustering` | Alternative Clustering | 45 |
| Figure B.1 | `fig:sensitivity` | Sensitivity contour | 46 |
| Table B.10 | `tab:iv_balance` | IV Balance Tests | 46 |
| Table B.11 | `tab:iv_panelc` | IV with IG×Year FE | 47 |
| Table B.12 | `tab:iv_placebo` | Placebo IV | 48 |
| Table B.13 | `tab:iv_network_split` | IV Network Split | 49 |
| Table B.14 | `tab:regime_oversight` | Oversight Heterogeneity | 50 |
| Figure B.2 | `fig:oversight` | Oversight coefficients | 48 |
| Table B.15 | `tab:bajari_ye_firststage` | Bajari-Ye First Stage | 50 |
| Table B.16 | `tab:bajari_ye_placebo` | Bajari-Ye Placebo | 51 |
| Table B.17 | `tab:bajari_ye_tender_fe` | Bajari-Ye Tender FE | 51 |
| Table B.18 | `tab:network_interactions` | Network Interactions | 52 |

### Appendix C — Staggered DiD

| # | Label | Caption (short) | Page |
|---|-------|----------------|------|
| Table C.1 | `tab:did_revised` | C&S Staggered DiD | 54 |
| Figure C.1 | `fig:event_study` | TWFE Event Study | 53 |

### Appendix D — Extensions

| # | Label | Caption (short) | Page |
|---|-------|----------------|------|
| Table D.1 | `tab:welfare_bounds` | Welfare Loss Bounds | 55 |
| Figure D.1 | `fig:welfare` | Welfare markup | 56 |
| Figure D.2 | `fig:year_coefs` | Year-by-year coefficients | 56 |
| Table D.2 | `tab:regime_test` | Regime Test | 55 |
| Figure D.3 | `fig:network_hhi` | Winner HHI distribution | 57 |
| Figure D.4 | `fig:fl_robustness` | FL definition robustness | 57 |

### Appendix E — Heterogeneity

| # | Label | Caption (short) | Page |
|---|-------|----------------|------|
| Figure E.1 | `fig:network_split` | Network split coefficients | 58 |

---

## Additional Fixes

1. **Unreferenced main-body floats** — 3 floats had `\label` but no `\ref`:
   - `fig:iqr` (Figure 2): added reference in sec_data.tex
   - `fig:first_stage` (Figure 4): added reference in sec_results.tex
   - `tab:mechanisms` (Table 12): added reference in sec_mechanisms.tex

2. **Unreferenced appendix floats** — 13 appendix floats have labels but no `\ref` in text. This is standard for supplementary material (tables/figures placed for reference without explicit cross-citation). No action needed.

3. **Orphaned table file** — `tab_homogeneous_subsample.tex` exists in output/tables/ but is not inputted by any manuscript file. Harmless (superseded by `tab_homogeneous_cv.tex`).

4. **No hardcoded float numbers** — All cross-references use `\ref{}` commands.

5. **No undefined references** — All `\ref{}` calls resolve correctly.

---

## Totals

| Category | Main Body | Appendix | Total |
|----------|-----------|----------|-------|
| Tables | 12 | 23 | 35 |
| Figures | 6 | 8 | 14 |
| **All floats** | **18** | **31** | **49** |
