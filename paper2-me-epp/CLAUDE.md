# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Academic research paper analyzing **micro and small enterprises (ME/EPP — Micro Empresa / Empresa de Pequeno Porte) participation in public procurement** in the state of Sao Paulo, Brazil. Part of a doctoral thesis by Darcio Genicolo-Martins & Paulo Furquim de Azevedo (INSPER). Uses BEC (Bolsa Eletronica de Compras) procurement data.

This is **Paper 2** in the `bitter-pills` monorepo. See also `../paper1-bitter-pills/` (active R/fixest pipeline) and `../paper3-thresholds/` (regression discontinuity).

## Current Status

Full R/fixest pipeline implemented. Run `Rscript scripts/00_master.R` from project root to reproduce all tables and figures.

## Directory Structure

```
paper2-me-epp/
├── manuscript/           # LaTeX (elsarticle) — \input tables from output/
├── data/raw/             # 12 original data files (git-ignored)
├── data/processed/       # Parquet conversion (git-ignored)
├── scripts/              # R pipeline (utils.R, 00-04)
├── output/tables/        # Generated .tex (5 tables)
├── output/figures/       # Generated .pdf (4 event studies)
```

## Commands

```bash
Rscript scripts/00_master.R                    # Full pipeline
Rscript -e "source('scripts/01_clean.R')"      # Data only
cd manuscript && pdflatex main.tex && bibtex main && pdflatex main.tex && pdflatex main.tex
```

## Pipeline

| Script | Purpose | Key outputs |
|--------|---------|-------------|
| `utils.R` | Paths, helpers, `run_didir_6()`, `theme_pub()` | — |
| `01_clean.R` | CSV→parquet, variable creation, RDS cache | `data/processed/paper2_me_epp.parquet`, `/tmp/p2_prepared.rds` |
| `02_analysis.R` | 24 DiDiR + 4 event study regressions | `/tmp/p2_models.rds` |
| `03_tables.R` | 5 LaTeX tables (threeparttable+booktabs) | `output/tables/tab_*.tex` |
| `04_figures.R` | 4 event study PDFs (grayscale, cairo) | `output/figures/fig_*.pdf` |

## Key Technical Details

| Aspect | Detail |
|--------|--------|
| **Main regression** | `y ~ g65_pre + Pre + convite + lquantidade \| item_alt [+ pbu_alt]` |
| **Clustering** | Main: `~item_alt`; Event study: `~grupo_f` |
| **Treatment** | g65 = 1 if codigogrupo == "65"; Pre = 1 if data_oc_numb < 698 (March 2018) |
| **Windows** | 6m=[692,703], 12m=[686,709], 18m=[680,715] (Stata monthly dates) |
| **Price/distance sample** | `oc_item_status == 1` (completed items) |
| **Firms/bids sample** | All items |
| **CSV format** | Latin-1, semicolon-separated, 373 columns |
| **Parquet cache** | `data/processed/paper2_me_epp.parquet` (14 selected columns) |
| **R-squared** | Overall R-squared (to approximate Stata areg output) |
| **Cache timestamp order** | Pipeline scripts write `output/tables/*.tex` *before* saving `/tmp/p2_*.rds`, so a table file may have an earlier mtime than the RDS it derives from. This is expected and not a staleness signal — inversion is benign. |

## Datasets

All raw data in `data/raw/` (git-ignored):

| File | Size | Description |
|------|------|-------------|
| `Paper2_ME_EPP.csv` | 6.4 GB | Primary dataset (373 cols, semicolon-sep, Latin-1) |
| `SME.dta` | 261 MB | Stata dataset |
| `ONLY SES_SME.csv` | 45 MB | Health secretary subset |
| Other files | <15 MB | Supporting data, logs, Stata outputs |

## Conventions (from Paper 1 v4)

- Scripts numbered sequentially: `00_master.R` through `04_figures.R`
- `utils.R` for shared path constants and helpers
- Cache prepared data at `/tmp/` as `.rds` for fast reload
- `fixest::feols` for fixed-effects regressions
- Publication tables: `threeparttable` + `booktabs` (no `tabularray`/`siunitx`)
- Publication figures: grayscale, `cairo_pdf`, 6.5 x 4 in, 9pt base text, `theme_bw`
- 16 threads for `fixest` and `data.table`

## Shared Resources

- **Shared data:** `../data/` — raw BEC procurement, CNPJ registry, geocoding
- **Shared code:** `../code/` — Stata data-preparation scripts
- **References:** `../references/` — academic papers, data dictionaries

## Tech Stack

- **R 4.5** — `fixest`, `data.table`, `arrow`, `ggplot2`
- **LaTeX** — elsarticle document class
- **Environment:** WSL2, 16 cores / 15 GB RAM
