# Replication Package

## Bitter Pills to Swallow: The Enforcement Costs of Health Litigation

**Authors:** Darcio Genicolo-Martins and Paulo Furquim de Azevedo
**Affiliation:** Insper Institute of Education and Research, São Paulo, Brazil
**Contact:** darciogm1@insper.edu.br

---

## Overview

This replication package contains all code, data, and instructions needed to reproduce the tables, figures, and manuscript in "Bitter Pills to Swallow: The Enforcement Costs of Health Litigation." The paper estimates the fiscal costs of judicial enforcement in public health procurement using bid-level data from São Paulo, Brazil (2009–2019).

The package produces:
- **26 publication-ready LaTeX tables** (output/tables/)
- **20 publication-ready PDF figures** (output/figures/)
- **Compiled manuscript PDF** (manuscript/Bitter-Pills_v7.pdf)

---

## Data Availability Statement

### Primary Dataset

| Data | Source | Availability | File |
|------|--------|-------------|------|
| BEC procurement records (Group 65) | Bolsa Eletrônica de Compras (BEC), São Paulo State Government | Public records, available upon request from SES/SP | `data/BEC-G65-WORK1.parquet` |

The primary dataset contains 479,330 purchase-offer-item (POI) observations covering all pharmaceutical procurement transactions by the São Paulo State Department of Health (SES/SP) from January 2009 through December 2019. Data were obtained from the BEC electronic procurement platform (public records) and cross-referenced with the S-CODES health litigation database.

**Purchase type classification** was performed using a regular expression algorithm applied to the "Object of the Contract" field of public tender notices. The classification code is included in the dataset as the `purchase_type` variable (0 = Ordinary, 1 = Administrative, 2 = Litigated).

### Supplementary Data (Downloaded Automatically)

| Data | Source | Description |
|------|--------|-------------|
| Municipal boundaries | IBGE via `geobr` R package | Shapefiles for São Paulo state municipalities |
| Population estimates | IBGE via `sidrar` R package | SIDRA table 6579 (2009–2019 average) |

These data are downloaded automatically by the map-generating scripts (10–15) via the `geobr` and `sidrar` R packages.

### Data Dictionary

See `DATA_DICTIONARY.md` for a complete description of all 180 variables in the dataset, including types, valid counts, summary statistics, and definitions.

---

## Computational Requirements

### Software

| Software | Version | Purpose |
|----------|---------|---------|
| R | ≥ 4.3 | Statistical analysis and figure generation |
| LaTeX | TeX Live ≥ 2023 | Manuscript compilation |
| Bash | ≥ 4.0 | Master script orchestration |

### R Packages

| Package | Version | Purpose |
|---------|---------|---------|
| `data.table` | ≥ 1.14 | Data manipulation |
| `fixest` | ≥ 0.11 | High-dimensional fixed effects estimation |
| `modelsummary` | ≥ 1.4 | Regression table generation |
| `ggplot2` | ≥ 3.4 | Figure generation |
| `arrow` | ≥ 14.0 | Parquet file reading |
| `knitr` | ≥ 1.42 | LaTeX table formatting |
| `scales` | ≥ 1.2 | Number formatting |
| `haven` | ≥ 2.5 | Data import utilities |
| `sf` | ≥ 1.0 | Spatial data handling |
| `geobr` | ≥ 1.7 | Brazilian geographic data |
| `sidrar` | ≥ 0.2 | IBGE SIDRA API access |

All R packages are installed automatically by the master script if not already present.

### LaTeX Packages

The manuscript uses the `elsarticle` document class with: `natbib`, `booktabs`, `threeparttable`, `graphicx`, `hyperref`, `amsmath`, `tikz`, `subfig`, `placeins`, `adjustbox`, `rotating`, `lscape`. These are included in standard TeX Live installations.

### Hardware

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU cores | 4 | 16 |
| RAM | 8 GB | 16 GB |
| Disk space | 2 GB | 4 GB |
| Runtime | ~30 min | ~10–15 min |

The `fixest` package uses OpenMP for parallel estimation. Runtime scales with the number of available cores. The master script automatically detects and uses all available cores.

### Tested Environments

| OS | R Version | TeX Distribution |
|----|-----------|-----------------|
| WSL2 (Ubuntu) on Windows 11 | R 4.5.0 | TinyTeX 2025 |

---

## Directory Structure

```
replication/
├── README.md                    ← This file
├── DATA_DICTIONARY.md           ← Complete variable descriptions
├── data/
│   └── BEC-G65-WORK1.parquet   ← Primary dataset (479K obs × 180 vars)
├── code/
│   ├── run_all.sh               ← Master replication script
│   ├── utils.R                  ← Shared infrastructure (paths, helpers)
│   ├── 00_prepare_data.R        ← Data loading and variable creation
│   ├── 01_desc_stats.R          ← Descriptive statistics (Table 1)
│   ├── 02_balance_table.R       ← Balance table (Table 2)
│   ├── 03_main_regressions.R    ← Main regressions (Tables 3–7)
│   ├── 04_heterogeneity.R       ← Heterogeneity analysis (Tables 8–11)
│   ├── 05_fiscal_costs.R        ← Fiscal cost estimates
│   ├── 06_robustness.R          ← Robustness checks (Tables A.1–A.5)
│   ├── 07_graphs.R              ← Working figures (densities, trends)
│   ├── 08_pub_tables.R          ← Publication-ready LaTeX tables (17 files)
│   ├── 09_pub_figures.R         ← Publication-ready PDF figures (8 files)
│   ├── 10_map_litigation.R      ← Litigation per capita map
│   ├── 11_map_pbu.R             ← PBU location map
│   ├── 12_fig_purchase_types.R  ← Purchase types comparison figure
│   ├── 13_map_litigation_total.R← Total litigation cases map
│   ├── 14_map_litigation_ratio.R← Litigation ratio map
│   ├── 15_admin_figures.R       ← Administrative demand figures (5 maps)
│   └── 16_v7_extensions.R      ← V7: UTG extended outcomes + litigated-only
├── output/                      ← Generated by scripts (initially empty)
│   ├── tables/                  ← 17 .tex publication-ready tables
│   └── figures/                 ← 18 .pdf publication-ready figures
├── manuscript/
│   ├── main.tex                 ← Master LaTeX document
│   ├── Introduction.tex         ← Section files
│   ├── LiteratureReview.tex
│   ├── InstitutionalBackground.tex
│   ├── DataAndSample.tex
│   ├── EmpiricalStrategy.tex
│   ├── Results.tex
│   ├── Conclusion.tex
│   ├── Appendix.tex
│   └── References.bib           ← Bibliography
└── logs/                        ← Runtime logs (created by run_all.sh)
```

---

## Instructions for Replicators

### Quick Start (Full Replication)

```bash
cd replication/
bash code/run_all.sh
```

This single command:
1. Checks all software prerequisites
2. Installs any missing R packages
3. Runs the complete analysis pipeline (scripts 00–15)
4. Compiles the manuscript PDF
5. Reports a summary of all outputs

### Step-by-Step Replication

If you prefer to run scripts individually:

```bash
cd replication/

# Step 1: Prepare data (creates output/v4_prepared.rds cache)
Rscript code/00_prepare_data.R

# Step 2: Descriptive statistics and balance table
Rscript code/01_desc_stats.R
Rscript code/02_balance_table.R

# Step 3: Main regressions
Rscript code/03_main_regressions.R

# Step 4: Extensions
Rscript code/04_heterogeneity.R
Rscript code/05_fiscal_costs.R
Rscript code/06_robustness.R

# Step 5: Figures
Rscript code/07_graphs.R
Rscript code/08_pub_tables.R
Rscript code/09_pub_figures.R

# Step 6: Maps
Rscript code/10_map_litigation.R
Rscript code/11_map_pbu.R
Rscript code/12_fig_purchase_types.R
Rscript code/13_map_litigation_total.R
Rscript code/14_map_litigation_ratio.R
Rscript code/15_admin_figures.R

# Step 7: Compile manuscript
cd manuscript/
pdflatex -interaction=nonstopmode -jobname=Bitter-Pills_v7 main.tex
bibtex Bitter-Pills_v7
pdflatex -interaction=nonstopmode -jobname=Bitter-Pills_v7 main.tex
pdflatex -interaction=nonstopmode -jobname=Bitter-Pills_v7 main.tex
```

**Important:** Script `00_prepare_data.R` must run first. It creates a cached `.rds` file that all subsequent scripts read. Scripts 01–15 are independent of each other and can run in any order after 00, though sequential execution is recommended because `fixest` uses all available CPU cores internally.

---

## Output Mapping: Scripts → Tables/Figures

### Tables

| Table | Script | Output File | Description |
|-------|--------|-------------|-------------|
| Table 1 | 01 + 08 | `tab_desc_stats.tex` | Descriptive statistics by purchase type |
| Table 2 | 02 + 08 | `tab_balance.tex` | Balance: Administrative vs. Litigated |
| Table 3 | 03 + 08 | `tab_ref_prices.tex` | Reference prices |
| Table 4 | 03 + 08 | `tab_quantities.tex` | Quantities |
| Table 5 | 03 + 08 | `tab_neg_prices.tex` | Negotiated prices |
| Table 6 | 03 + 08 | `tab_firms.tex` | Bidder participation |
| Table 7 | 03 + 08 | `tab_success.tex` | Tender success |
| Table 8 | 03 + 08 | `tab_underthegun.tex` | Under the gun (UTG) |
| Table 9 | 04 + 08 | `tab_het_sus.tex` | Heterogeneity: SUS component |
| Table 10 | 04 + 08 | `tab_het_period.tex` | Heterogeneity: Time period |
| Table 11 | 04 + 08 | `tab_het_competition.tex` | Heterogeneity: Competition |
| Table 12 | 04 + 08 | `tab_het_pbu.tex` | Heterogeneity: PBU size |
| Table A.1 | 06 + 08 | `tab_rob_ref_prices.tex` | Robustness: Reference prices |
| Table A.2 | 06 + 08 | `tab_rob_neg_prices.tex` | Robustness: Negotiated prices |
| Table A.3 | 06 + 08 | `tab_rob_firms.tex` | Robustness: Bidder participation |
| Table A.4 | 06 + 08 | `tab_rob_success.tex` | Robustness: Tender success |
| Table A.5 | 06 + 08 | `tab_rob_utg.tex` | Robustness: UTG progressive controls |
| Table 13 | 16 | `t1_tab_utg_ref_prices.tex` | UTG: Reference prices |
| Table 14 | 16 | `t1_tab_utg_quantities.tex` | UTG: Quantities |
| Table 15 | 16 | `t1_tab_utg_firms.tex` | UTG: Bidder participation |
| Table 16 | 16 | `t1_tab_utg_success.tex` | UTG: Tender success |
| Table 17 | 16 | `t2_tab_ref_prices.tex` | Litigated-only: Reference prices |
| Table 18 | 16 | `t2_tab_quantities.tex` | Litigated-only: Quantities |
| Table 19 | 16 | `t2_tab_neg_prices.tex` | Litigated-only: Negotiated prices |
| Table 20 | 16 | `t2_tab_firms.tex` | Litigated-only: Bidder participation |
| Table 21 | 16 | `t2_tab_success.tex` | Litigated-only: Tender success |

### Figures

| Figure | Script | Output File | Description |
|--------|--------|-------------|-------------|
| Figure 1 | 10 | `fig_00_litigation_map.pdf` | Litigation per capita map |
| Figure 2 | 13 | `fig_00d_litigation_total_map.pdf` | Total litigation cases map |
| Figure 3 | 11 | `fig_00b_litigation_pbu_map.pdf` | PBU locations |
| Figure 4 | 12 | `fig_00c_litigation_types.pdf` | Purchase types comparison |
| Figure A.1 | 09 | `fig_01_ref_price_density.pdf` | Reference price density |
| Figure A.2 | 09 | `fig_02_negprice_density.pdf` | Negotiated price density |
| Figure A.3 | 09 | `fig_03_qty_density.pdf` | Quantity density |
| Figure A.4 | 09 | `fig_04_firms_density.pdf` | Firms density |
| Figure A.5 | 09 | `fig_05_utg_density.pdf` | UTG price density |
| Figure A.6 | 09 | `fig_06_success_bar.pdf` | Success rate bar chart |
| Figure A.7 | 09 | `fig_07_time_trends.pdf` | Time trends |
| Figure A.8 | 09 | `fig_08_coefplot.pdf` | Coefficient plot |
| Figure A.9 | 15 | `fig_00_admin_map.pdf` | Admin per capita map |
| Figure A.10 | 15 | `fig_00b_admin_pbu_map.pdf` | Admin PBU map |
| Figure A.11 | 15 | `fig_00c_admin_types.pdf` | Admin vs. litigated comparison |
| Figure A.12 | 15 | `fig_00d_admin_total_map.pdf` | Total admin purchases map |
| Figure A.13 | 15 | `fig_00e_admin_ratio_map.pdf` | Admin share map |
| — | 14 | `fig_00e_litigation_ratio_map.pdf` | Litigation ratio map |
| Figure A.14 | 16 | `fig_09_utg_coefplot_v7.pdf` | UTG coefficient plot (all outcomes) |
| Figure A.15 | 16 | `fig_10_litigated_coefplot_v7.pdf` | Litigated-only coefficient plot |

---

## Econometric Details

- **Estimator:** `fixest::feols` (equivalent to Stata `reghdfe`)
- **Fixed effects:** 4 specifications: (1) Item, (2) Item+Year, (3) Item+Year+PBU, (4) Item+Year-Month+PBU
- **Clustering:** PBU level (primary); item and two-way PBU×Item in robustness
- **Winsorization:** 1%/99% baseline; robustness at 0% and 5%/95%
- **Parallelism:** `fixest` uses OpenMP internally (all available cores)
- **Coefficient interpretation:** `exp(β) - 1` for percentage effects from log-level regressions

---

## Citation

If you use this replication package, please cite:

```bibtex
@unpublished{genicolo2026bitter,
  author = {Genicolo-Martins, Darcio and Azevedo, Paulo Furquim de},
  title  = {Bitter Pills to Swallow: The Enforcement Costs of Health Litigation},
  year   = {2026},
  note   = {Working Paper, Insper Institute of Education and Research}
}
```

---

## License

This replication package is provided for academic use. The code is released under the MIT License. The data are subject to the terms of use of the original data providers (BEC/SES-SP).
