# Beneath the Surface

**Incumbency advantages in Brazilian public procurement — Regression Discontinuity Design**

Galletta, Genicolo-Martins & Vacchini, 2025

## Status

Manuscript exists (PDF). Empirical analysis pipeline complete. Figures not yet exported to final directory.

## Directory Structure

```
paper4-thresholds/
├── 01_manuscript/          # Compiled paper PDF
├── 02_data/                # Datasets (git-ignored, large)
│   ├── raw/                # (empty — originals in Dropbox)
│   ├── intermediate/       # Regression result CSVs (~17GB)
│   ├── final/              # Main dataset: df_convite_winner_looser.dta (5.2GB)
│   └── firms/              # Firm characteristics: Firms_final.dta (20MB)
├── 03_analysis/            # Analysis code by collaborator
│   ├── Dario_Vacchini/
│   │   ├── code/           # Stata scripts (.do)
│   │   ├── notebooks/      # Jupyter notebooks (visualization)
│   │   ├── cluster/        # Euler HPC cluster scripts
│   │   └── results/        # 67 CSV regression result files
│   └── Sergio/             # Sergio's Stata scripts
├── 04_figures/             # Final figures for paper (to be populated)
├── 05_references/          # Reference papers (PDFs)
├── 06_scratch/             # Small archives (Code, Documents, Literature, Paper)
├── _legacy/                # Old versions and large data archives
│   ├── Procurement_Sao_Paulo/  # Earlier paper versions (ETH, LACEA, v1, v2)
│   ├── RDD_Sergio_original/    # Previous analysis version (~22GB)
│   ├── data_archives/          # Data ZIPs (final, intermediate, raw)
│   └── phd_scripts/            # PhD-era Stata scripts (v10-v12)
└── notes/                  # Research notes, ideas, to-do lists
```

## Analysis Pipeline (Dario_Vacchini)

1. `00_main.do` — Master script, path definitions
2. `01_prepare_dataset.do` — Data prep (428 lines)
3. `02_a_analysis_incumbency.do` — RDD: won t-1 (705 lines)
4. `02_b_analysis_backlog.do` — RDD: share won 90/120 days (234 lines)
5. `02_c_analysis_firm_structure.do` — RDD: firm age, type (166 lines)
6. `04_analysis_other.do` — Additional analyses (150 lines)
7. `03_*.ipynb` — Coefficient significance plots
8. `05_*.ipynb` — Binscatter plots

## RDD Design

- **Running variable:** Margin of victory (bid difference)
- **Discontinuity:** MV = 0 (winning threshold)
- **Outcomes:** Incumbency, backlog, firm age, firm type, last bid
- **Heterogeneity:** By market, item class, item group (67 result files)
- **Software:** Stata (rdrobust, reghdfe, rangestat) + Python (pandas, seaborn)

## Data

Large data files (22GB+) are in `_legacy/data_archives/` and `02_data/`. Not version-controlled — share via Dropbox.

## Collaborators

- Sergio Galletta (ETH Zurich)
- Darcio Genicolo-Martins (INSPER)
- Dario Vacchini
