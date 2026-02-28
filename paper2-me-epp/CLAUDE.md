# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Academic research paper analyzing **micro and small enterprises (ME/EPP — Micro Empresa / Empresa de Pequeno Porte) participation in public procurement** in the state of São Paulo, Brazil. Part of a doctoral thesis by Darcio Genicolo-Martins & Paulo Furquim de Azevedo (INSPER). Uses BEC (Bolsa Eletrônica de Compras) procurement data.

This is **Paper 2** in the `bitter-pills` monorepo. See also `../paper1-bitter-pills/` (active R/fixest pipeline) and `../paper3-thresholds/` (regression discontinuity).

## Current Status

Data-only — no active analysis scripts exist yet. The directory contains raw/processed datasets and a 2019 presentation outline. Analysis will likely follow patterns established in Paper 1's v4 pipeline (R/fixest).

## Datasets

All in `data/`:

| File | Size | Format | Description |
|------|------|--------|-------------|
| `SME.dta` | 261 MB | Stata | Primary SME procurement dataset |
| `Paper2_ME_EPP.csv` | 6.4 GB | CSV | Full detailed procurement transactions |
| `ONLY SES_SME.csv` | 45 MB | CSV | SES (health secretary) filtered subset |
| `ME_EPP_Items_tempo.csv` | 15 MB | CSV | Time-series data on items purchased by SMEs |
| `Estudo items_smes.csv` | 11 MB | CSV | Study data linking items and SMEs |
| `Paper 2_ME_EPP_Choose.xlsx` | 170 KB | Excel | Research selection criteria |
| `me_epp.xlsx` | 2.6 MB | Excel | SME summary data |
| `SME.xlsx` | 53 KB | Excel | SME reference data |
| `me_epp_items.txt` | 1.5 MB | Text | Stata tabulation output of items |
| `me_epp.log` / `Log_me_epp.log` | ~2 MB | Log | Historical Stata log output |
| `SME_dist_nolog_final.rtf` | 78 KB | RTF | Distribution analysis results |

Note: All data files are git-ignored (see root `.gitignore`). The 6.4 GB CSV has very long lines.

## Shared Resources

- **Shared data:** `../data/` contains raw BEC procurement files, CNPJ firm registry, geocoding/shapefiles, and processed datasets used across all papers
- **Shared code:** `../code/` has Stata data-preparation scripts (BEC processing by year/semester) and `master.do`
- **References:** `../references/` has academic papers, data dictionaries, and reports

## Tech Stack & Environment

- **R 4.5** — Expected for new analysis (following Paper 1's v4 approach using `fixest`, `data.table`, `arrow`)
- **Stata/SE** — Historical analysis tool; existing logs/outputs were generated with Stata
- **LaTeX** — Manuscript preparation (elsarticle document class)
- **Environment:** WSL2 (Linux under Windows), 16 cores / 15 GB RAM

## Conventions (from Paper 1)

When building analysis scripts for Paper 2, follow these patterns from `../paper1-bitter-pills/v4/`:

- Number scripts sequentially (`00_prepare_data.R`, `01_desc_stats.R`, etc.)
- Use a `utils.R` for shared path constants and helpers
- Cache prepared data at `/tmp/` as `.rds` for fast reload across scripts
- Use `fixest::feols` for fixed-effects regressions with multiple FE specifications
- Output both HTML (for review) and LaTeX (for manuscript) versions of tables
- Publication-ready tables: `threeparttable` + `booktabs` format (no `tabularray`/`siunitx`)
- Publication-ready figures: grayscale, cairo PDF, 6.5 x 4 in, 9pt text
- Winsorize continuous outcomes at 1%/99% baseline with robustness checks
