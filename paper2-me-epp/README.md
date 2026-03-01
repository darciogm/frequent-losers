# Paper 2 — SMEs and Public Procurement: the Costs of Restricting Tenders

Darcio Genicolo-Martins & Paulo Furquim de Azevedo (INSPER)

## Overview

This paper estimates the costs of restricting public tenders to small and medium-sized enterprises (SMEs) using a difference-in-differences in reverse (DiDiR) design. We exploit the timing of a policy change in March 2018 that extended SME tender restrictions to group 65 items (medical/dental/hospital supplies) in the state of Sao Paulo, Brazil.

## Directory Structure

```
paper2-me-epp/
├── manuscript/           # LaTeX source (elsarticle)
│   ├── main.tex          # Main document
│   ├── appendix.tex      # Appendix figures
│   └── figures/          # Original PNG figures (backup)
├── data/
│   ├── raw/              # Original data files (git-ignored)
│   └── processed/        # Parquet conversion (git-ignored)
├── scripts/              # R analysis pipeline
│   ├── utils.R           # Shared infrastructure
│   ├── 00_master.R       # Pipeline orchestrator
│   ├── 01_clean.R        # Data loading & preparation
│   ├── 02_analysis.R     # DiDiR regressions & event studies
│   ├── 03_tables.R       # LaTeX table generation
│   └── 04_figures.R      # Event study figures
├── output/               # Generated outputs (git-ignored)
│   ├── tables/           # .tex files (5 tables)
│   └── figures/          # .pdf files (4 event studies)
├── CLAUDE.md
└── README.md
```

## Reproduction

### Requirements

- **R 4.5+** with packages: `data.table`, `fixest`, `arrow`, `ggplot2`
- **LaTeX** with `elsarticle`, `booktabs`, `threeparttable` (standard TeX Live)
- Raw data files in `data/raw/` (not tracked by git)

### Run the pipeline

```bash
cd paper2-me-epp
Rscript scripts/00_master.R
```

First run reads the 6.4 GB CSV and converts to parquet (~5 min); subsequent runs use cached parquet (~1 min).

### Script-to-output map

| Script | Outputs |
|--------|---------|
| `01_clean.R` | `data/processed/paper2_me_epp.parquet`, `/tmp/p2_prepared.rds` |
| `02_analysis.R` | `/tmp/p2_models.rds` |
| `03_tables.R` | `output/tables/tab_{desc_stats,prices,participants,validbids,distance}.tex` |
| `04_figures.R` | `output/figures/fig_{01..04}_*.pdf` |

### Compile the manuscript

```bash
cd manuscript
pdflatex main.tex && bibtex main && pdflatex main.tex && pdflatex main.tex
```

## Replication

For complete replication instructions following the Social Science Data Editors template (DCAS v1.0), see [README_replication.md](README_replication.md).
