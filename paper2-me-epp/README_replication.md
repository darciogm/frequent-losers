# Data and Code Availability Statement — Replication Package

**SMEs and Public Procurement: the Costs of Restricting Tenders**

Darcio Genicolo-Martins (INSPER) — darciogm1@insper.edu.br

> This document follows the [Social Science Data Editors' template README](https://social-science-data-editors.github.io/template_README/) (v1.2), endorsed by the AEA, Econometrica, REStud, and JPE.

---

## 1. Overview

This replication package reproduces all tables and figures in the paper "SMEs and Public Procurement: the Costs of Restricting Tenders." The paper estimates the costs of restricting public tenders to small and medium-sized enterprises (SMEs) using a difference-in-differences in reverse (DiDiR) design, exploiting the March 2018 policy change in the state of Sao Paulo, Brazil.

The package contains:

- **9 R scripts** that clean the raw data, estimate all regressions, and produce publication-ready tables and figures.
- **1 LaTeX manuscript** that compiles the paper from the generated outputs.
- All outputs can be reproduced with a single command: `Rscript scripts/00_master.R`.

### Manuscript tables and figures

| Output type | Count | Scripts |
|-------------|-------|---------|
| Tables      | 18    | `03_tables.R` |
| Figures     | 15    | `04_figures.R` |

A complete mapping of each table and figure to its generating script is provided in `output/table_figure_map.csv`.

---

## 2. Data Availability and Provenance Statements

### Statement about Rights

- [x] I certify that the author(s) of the manuscript have legitimate access to and permission to use the data used in this manuscript.
- [ ] I certify that the author(s) of the manuscript have documented permission to redistribute/publish the data contained within this replication package. Appropriate permission are documented in the LICENSE.txt file.

### Summary of Availability

- [ ] All data **are** publicly available.
- [x] Some data **cannot be made** publicly available.
- [ ] **No data can be made** publicly available.

The analysis relies on confidential administrative records from the Bolsa Eletronica de Compras (BEC), the electronic procurement system of the state of Sao Paulo, Brazil. These data were obtained under a data access agreement with the Secretaria da Fazenda e Planejamento do Estado de Sao Paulo (SEFAZ/SP). The raw data cannot be redistributed, but the code is provided in full.

### Data Sources

| Data file | Source | Provided | Notes |
|-----------|--------|----------|-------|
| `Paper2_ME_EPP.csv` | BEC / SEFAZ-SP | No | Confidential administrative records |

#### Bolsa Eletronica de Compras (BEC) — SEFAZ/SP

- **Description:** Item-level public procurement records from the electronic procurement platform of the state of Sao Paulo, covering 2016–2019. Contains 373 variables including item descriptions, prices, bids, participating firms, buyer units, and transaction outcomes.
- **Format:** CSV, 6.4 GB, semicolon-separated, Latin-1 encoding.
- **Time period:** 2016–2019 (Stata monthly dates 680–715).
- **Geographic coverage:** State of Sao Paulo, Brazil.
- **Access:** The data are confidential and were obtained under an institutional agreement. Researchers wishing to replicate the study should contact SEFAZ/SP directly. See `data/raw/README_data.md` for detailed access instructions.
- **Estimated timeline for access:** Approximately 3 months from initial request.

### Statement about Data Preservation

The raw data are preserved by SEFAZ/SP as part of their administrative records infrastructure. The author retains a copy of the data used in this study and commits to preserving it for a minimum of 10 years from the date of publication. The code is preserved in this repository under version control.

---

## 3. Computational Requirements

### Software Requirements

- **R 4.5.0** or higher (tested with R 4.5.2)
- **TeX Live 2025** or equivalent LaTeX distribution (for manuscript compilation)

#### R Packages

| Package | Version tested | Purpose |
|---------|---------------|---------|
| `data.table` | 1.18.2.1 | Data manipulation |
| `fixest` | 0.13.2 | Fixed-effects regression |
| `arrow` | 23.0.1.1 | Parquet I/O |
| `ggplot2` | 4.0.2 | Figures |
| `scales` | 1.4.0 | Axis formatting |
| `grf` | 2.5.0 | Causal forest |
| `quantreg` | 6.1 | Quantile regression |
| `gridExtra` | 2.3 | Multi-panel figures |

All packages can be installed by running `Rscript scripts/setup.R`.

### Controlled Randomness

The following scripts use random number generation with fixed seeds for reproducibility:

| Script | Line | Seed | Purpose |
|--------|------|------|---------|
| `05_robustness.R` | 118 | `set.seed(42)` | Randomization inference (500 permutations) |
| `07_advanced.R` | 266 | `set.seed(42)` | Causal forest subsampling |
| `07_advanced.R` | 279 | `seed = 42` | Causal forest training |
| `07_advanced.R` | 383 | `set.seed(42)` | Quantile regression subsampling |

### Hardware Requirements

- **Tested on:** WSL2 / Ubuntu 24.04, 16 cores (AMD/Intel), 15 GB RAM.
- **Minimum recommended:** 4 cores, 12 GB RAM, 10 GB free disk space.
- **Wall-clock time:**
  - First run (CSV → Parquet conversion): ~8 minutes.
  - Subsequent runs (cached Parquet): ~3 minutes.
- **Memory note:** The pipeline runs each script as a separate subprocess to keep peak memory under 15 GB. The master script (`00_master.R`) orchestrates this automatically.

### Thread Configuration

The pipeline auto-detects the number of physical cores and caps at 16 threads for both `fixest` and `data.table`. This is configured in `scripts/utils.R`.

---

## 4. Description of Programs/Code

### Pipeline Overview

The analysis pipeline follows a sequential subprocess model: the master script (`00_master.R`) runs each step as a separate R process, allowing the OS to fully reclaim memory between scripts. This design is necessary because the combined memory footprint of all models exceeds 15 GB.

### Script Table

| Script | Purpose | Inputs | Outputs | ~Duration |
|--------|---------|--------|---------|-----------|
| `utils.R` | Shared paths, helpers, themes | — | — | (loaded by others) |
| `00_master.R` | Pipeline orchestrator | All scripts | Timing summary | — |
| `01_clean.R` | CSV → Parquet, variable creation | `data/raw/Paper2_ME_EPP.csv` | `data/processed/paper2_me_epp.parquet`, `/tmp/p2_prepared.rds` | ~5 min (first), ~10 sec (cached) |
| `02_analysis.R` | 24 DiDiR + 4 event study regressions | `/tmp/p2_prepared.rds` | `/tmp/p2_models.rds` | ~30 sec |
| `05_robustness.R` | Placebo, alt. clustering, winsorization, permutation | `/tmp/p2_prepared.rds` | `/tmp/p2_robustness.rds` | ~60 sec |
| `06_extensions.R` | Real prices, extensive margin, efficiency, heterogeneity, fiscal cost | `/tmp/p2_prepared.rds`, `/tmp/p2_models.rds` | `/tmp/p2_extensions.rds` | ~30 sec |
| `07_advanced.R` | HonestDiD, Lee bounds, causal forest, quantile DiD, Gelbach | `/tmp/p2_prepared.rds`, `/tmp/p2_models.rds` | `/tmp/p2_advanced.rds` | ~90 sec |
| `03_tables.R` | 18 LaTeX tables | `/tmp/p2_models.rds`, `/tmp/p2_robustness.rds`, `/tmp/p2_extensions.rds`, `/tmp/p2_advanced.rds` | `output/tables/tab_*.tex` | ~5 sec |
| `04_figures.R` | 15 PDF figures | `/tmp/p2_models.rds`, `/tmp/p2_robustness.rds`, `/tmp/p2_advanced.rds`, `/tmp/p2_prepared.rds` | `output/figures/fig_*.pdf` | ~10 sec |

### Code Structure

```
scripts/
├── utils.R           # Shared infrastructure (paths, helpers, themes)
├── 00_master.R       # Pipeline orchestrator with pre-flight checks
├── 01_clean.R        # Data loading, CSV→Parquet, variable creation
├── 02_analysis.R     # Main DiDiR regressions and event studies
├── 05_robustness.R   # Placebo, alt. clustering, winsorization, permutation
├── 06_extensions.R   # Real prices, extensive margin, heterogeneity, fiscal cost
├── 07_advanced.R     # HonestDiD, Lee bounds, causal forest, quantile DiD, Gelbach
├── 03_tables.R       # LaTeX table generation (all 18 tables)
├── 04_figures.R      # PDF figure generation (all 15 figures)
└── setup.R           # Environment setup (R version check, package installation)
```

---

## 5. Instructions to Replicators

### Step 1: Install R

Install R 4.5 or higher from [CRAN](https://cran.r-project.org/).

### Step 2: Install Packages

```bash
Rscript scripts/setup.R
```

This script checks the R version, installs any missing packages, and verifies that all required packages load successfully.

### Step 3: Obtain and Place Data

Place the raw data file `Paper2_ME_EPP.csv` in the `data/raw/` directory. See `data/raw/README_data.md` for instructions on how to obtain the data from SEFAZ/SP.

```
data/raw/Paper2_ME_EPP.csv    # 6.4 GB, Latin-1, semicolon-separated
```

### Step 4: Run the Pipeline

```bash
cd paper2-me-epp
Rscript scripts/00_master.R
```

This single command:
1. Checks R version, packages, and data availability.
2. Converts CSV to Parquet (first run only; cached thereafter).
3. Runs all regressions (DiDiR, event studies, robustness, extensions, advanced methods).
4. Generates 18 LaTeX tables in `output/tables/`.
5. Generates 15 PDF figures in `output/figures/`.
6. Prints a timing summary.

### Step 5: Compile the Manuscript

```bash
cd manuscript
pdflatex main.tex && bibtex main && pdflatex main.tex && pdflatex main.tex
```

The manuscript reads tables and figures directly from `output/` via `\input{}` and `\includegraphics{}` commands.

---

## 6. List of Tables and Figures

### Tables

| # | Label | Caption | Script | Output file |
|---|-------|---------|--------|-------------|
| 1 | tab:descstats | Descriptive Statistics (18-month window) | `03_tables.R` | `tab_desc_stats.tex` |
| 2 | tab:prices | Prices (log): Pre-switch-period effect on group 65 | `03_tables.R` | `tab_prices.tex` |
| 3 | tab:participants | Number of Participant Firms (log) | `03_tables.R` | `tab_participants.tex` |
| 4 | tab:heterog_value | Heterogeneous Effects by Item Value (18-month window) | `03_tables.R` | `tab_heterog_value.tex` |
| 5 | tab:placebo | Placebo Tests: Fake Treatment Dates | `03_tables.R` | `tab_placebo.tex` |
| B.1 | tab:validbids | Number of Valid Bids (log) | `03_tables.R` | `tab_validbids.tex` |
| B.2 | tab:distance | Distance from PBUs to Winner Firms | `03_tables.R` | `tab_distance.tex` |
| B.3 | tab:altcluster | Alternative Clustering (18-month window) | `03_tables.R` | `tab_altcluster.tex` |
| B.4 | tab:winsorize | Winsorized Regressions (18-month window) | `03_tables.R` | `tab_winsorize.tex` |
| B.5 | tab:prices_real | Real Prices (IPCA-deflated, log) | `03_tables.R` | `tab_prices_real.tex` |
| B.6 | tab:extensive | Extensive Margin: Tender Completion Rate | `03_tables.R` | `tab_extensive.tex` |
| B.7 | tab:efficiency | Price Efficiency: Final Price / Reference Price | `03_tables.R` | `tab_efficiency.tex` |
| B.8 | tab:sme_winner | Winner Composition: SME Winner (binary) | `03_tables.R` | `tab_sme_winner.tex` |
| B.9 | tab:bid_spread | Bid Spread (conditional) | `03_tables.R` | `tab_bid_spread.tex` |
| B.10 | tab:heterog_pbu | Heterogeneous Effects by PBU Type (18-month window) | `03_tables.R` | `tab_heterog_pbu.tex` |
| B.11 | tab:lee_bounds | Lee (2009) Bounds: Sample Selection Correction | `03_tables.R` | `tab_lee_bounds.tex` |
| B.12 | tab:cforest | Causal Forest: Group Average Treatment Effects | `03_tables.R` | `tab_cforest.tex` |
| B.13 | tab:quantile_did | Quantile DiD: Treatment Effects Across Price Distribution | `03_tables.R` | `tab_quantile_did.tex` |
| B.14 | tab:mediation | Gelbach (2016) Decomposition: Channels of Price Effect | `03_tables.R` | `tab_mediation.tex` |

### Figures

| # | Label | Caption | Script | Output file |
|---|-------|---------|--------|-------------|
| 1 | fig:logprices | Log Prices: Event Study | `04_figures.R` | `fig_01_logprices_es.pdf` |
| A.1 | fig:distance_es | Distance from PBUs to Winner Firms: Event Study | `04_figures.R` | `fig_02_distance_es.pdf` |
| A.2 | fig:numfirms_es | Number of Participant Firms (log): Event Study | `04_figures.R` | `fig_03_numfirms_es.pdf` |
| A.3 | fig:numbids_es | Number of Valid Bids (log): Event Study | `04_figures.R` | `fig_04_numbids_es.pdf` |
| A.4 | fig:trends_prices | Raw Trends: Mean Log Price by Month | `04_figures.R` | `fig_05_trends_prices.pdf` |
| A.5 | fig:trends_firms | Raw Trends: Mean Log Number of Firms by Month | `04_figures.R` | `fig_06_trends_firms.pdf` |
| A.6 | fig:trends_bids | Raw Trends: Mean Log Number of Valid Bids by Month | `04_figures.R` | `fig_07_trends_bids.pdf` |
| A.7 | fig:trends_distance | Raw Trends: Mean Distance (km) by Month | `04_figures.R` | `fig_08_trends_distance.pdf` |
| A.8 | fig:permutation | Randomization Inference: Permuted Coefficients | `04_figures.R` | `fig_09_permutation.pdf` |
| A.9 | fig:sme_share | SME Participation Share Among Firms (Phase 1) | `04_figures.R` | `fig_10_sme_share.pdf` |
| A.10 | fig:honestdid | HonestDiD Sensitivity Analysis | `04_figures.R` | `fig_11_honestdid.pdf` |
| A.11 | fig:cforest_varimp | Causal Forest: Variable Importance | `04_figures.R` | `fig_12_cforest_varimp.pdf` |
| A.12 | fig:cforest_gate | Causal Forest: GATE by CATE Quartile | `04_figures.R` | `fig_13_cforest_gate.pdf` |
| A.13 | fig:quantile_did | Quantile DiD: Treatment Effects Across Price Distribution | `04_figures.R` | `fig_14_quantile_did.pdf` |
| A.14 | fig:mediation | Gelbach (2016) Decomposition: Channel Contributions | `04_figures.R` | `fig_15_mediation.pdf` |

---

## 7. References

- **BEC Data:** Bolsa Eletronica de Compras, Secretaria da Fazenda e Planejamento do Estado de Sao Paulo (SEFAZ/SP). Administrative procurement records, 2016–2019. Available by institutional request.
- **R:** R Core Team (2025). R: A Language and Environment for Statistical Computing. R Foundation for Statistical Computing, Vienna, Austria. https://www.R-project.org/.
- Athey, S., Tibshirani, J., & Wager, S. (2019). Generalized random forests. *Annals of Statistics*, 47(2), 1148–1178.
- Canay, I. A. (2011). A simple approach to quantile regression for panel data. *Econometrics Journal*, 14(3), 368–386.
- Gelbach, J. B. (2016). When do covariates matter? And which ones, and how much? *Journal of Labor Economics*, 34(2), 509–543.
- Lee, D. S. (2009). Training, wages, and sample selection: Estimating sharp bounds on treatment effects. *Review of Economic Studies*, 76(3), 1071–1102.
- Rambachan, A., & Roth, J. (2023). A more credible approach to parallel trends. *Review of Economic Studies*, 90(5), 2555–2591.
