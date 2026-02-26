# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Academic research paper: **"Bitter Pills to Swallow: The Enforcement Costs of Health Litigation"** by Darcio Genicolo-Martins & Paulo Furquim de Azevedo (INSPER). The paper estimates how court-mandated health procurement in Brazil (2009-2019) affects prices, bidder participation, and success rates using matched administrative and procurement data.

## Tech Stack

- **R 4.5** for v4 analysis (`fixest`, `data.table`, `modelsummary`, `ggplot2`, `arrow`)
- **Stata/SE** for v2/v3 analysis (requires `reghdfe`, `ftools`)
- **Python 3** for edital text classification (`v3/classify_editais.py`)
- **LaTeX** (elsarticle document class, chicago bibliography style) for the manuscript
- Runs on WSL2 (Linux under Windows), 16 cores / 15GB RAM

## Common Commands

### R Analysis (v4 — primary)

```bash
# Run the full v4 pipeline (~3.5 min on 16 cores)
Rscript v4/run_all.R

# Run individual v4 scripts (must run 00 first to create /tmp/v4_prepared.rds)
Rscript v4/analysis/00_prepare_data.R
Rscript v4/analysis/03_main_regressions.R

# Install arrow package if missing (requires C++20 compiler)
# May need: mkdir -p ~/.R && echo 'CXX20 = g++\nCXX20STD = -std=c++20\nCXX20FLAGS = -O2 -fPIC' > ~/.R/Makevars
Rscript -e "install.packages('arrow')"
```

### Stata Analysis (v2/v3 — legacy)

```bash
# Install required Stata packages (one-time setup)
stata-se -b -q do v2/analysis/install_packages.do

# Run individual v2 scripts
stata-se -b -q do v2/analysis/balance_table.do
stata-se -b -q do v2/analysis/desc_stats_table_v2.do
stata-se -b -q do v2/analysis/clustered_regressions.do

# Run the full v3 pipeline (serial data prep, then parallel analyses)
bash v3/analysis/run_all.sh

# Run individual v3 scripts (must run 00_prepare_data.do first)
stata-se -b -q do v3/analysis/00_prepare_data.do
stata-se -b -q do v3/analysis/03_main_regressions.do

# Check Stata log output after running (log file name matches .do file name)
cat clustered_regressions.log
```

Note: Stata log files are created in the current working directory, not next to the .do file.

### Manuscript Compilation

```bash
cd manuscript && pdflatex -interaction=nonstopmode main.tex
# For bibliography: bibtex main && pdflatex main.tex && pdflatex main.tex
```

### Open PDFs (WSL)

```bash
wslview manuscript/main.pdf
```

## Project Structure

### Analysis Versions

Four analysis versions exist. **v4** is the current primary version (R/fixest on G65 dataset):

- `v4/analysis/` — **Current primary analysis** (R/fixest, BEC-G65-WORK1.parquet, 479K obs, Group 65 medical items)
  - `utils.R` — Shared infrastructure: path constants, `winsorize()`, `run_feols4()`, `save_table()`, `theme_paper()`
  - `00_prepare_data.R` — Load parquet, create derived variables, save to `/tmp/v4_prepared.rds`
  - `01_desc_stats.R` — Descriptive statistics (3 purchase types, Panels A/B/C, Welch t-tests)
  - `02_balance_table.R` — Balance table (Admin vs Litigated in urgent subsample)
  - `03_main_regressions.R` — Tables 4-10: 4 FE specs × 3 clustering variants
  - `04_heterogeneity.R` — Heterogeneous effects (SUS component, period, competition, PBU size)
  - `05_fiscal_costs.R` — Fiscal cost estimates (total, direct, UTG channels)
  - `06_robustness.R` — 120+ regressions: UTG progressive controls + all tables × 3 winsorization levels
  - `07_graphs.R` — 8 PDF figures (densities, bar chart, time trends, coefficient plot)
  - `run_all.R` — Orchestrator: package checks → sequential execution → timing summary
- `v2/analysis/` — Original Stata analysis (subsample: electronic auctions with both litigated and ordinary)
  - `clustered_regressions.do` — Main regressions (Tables 4-8)
  - `balance_table.do`, `desc_stats_table_v2.do`, `fiscal_costs.do`, `heterogeneity.do`
  - `underthegun_robustness.do`, `winsorization_sensitivity.do`
- `v3/analysis/` — Extended Stata analysis (BEC_JUD.dta, 193K obs, all auction types)
  - Numbered scripts `00_prepare_data.do` through `07_graphs.do` (must run 00 first)
  - `run_all.sh` — Orchestration: serial data prep → parallel analyses → error checking
- `v3/classify_editais.py` — Python regex classifier for edital text (judicial/administrative/ordinary)
- `replication/replicate_paper.do` — Exact OLS + xtreg specifications matching the manuscript
- `analysis/` — Legacy v1 scripts (do not use)

### Data

- `datasets/` — Processed datasets (not tracked in git)
  - `BEC-G65-WORK1.parquet` — **v4 input** (479K obs × 180 cols, Group 65 medical/hospital items, 2009-2019)
  - `BEC_JUD.dta` — v3 input (193K obs, all auction types)
  - `3_BEC_PAPER_1_JUD_FINAL.dta` — v2 subsample dataset
  - `3_BEC_PAPER_1_JUD_FINAL_PANEL.dta` — Panel format variant
  - `Classif_editais/` — Raw edital classification data (~18GB compressed): regex dummy CSVs, judicial reference data

### Manuscript & Output

- `manuscript/` — LaTeX source (main.tex inputs section files: Introduction, InstitutionalBackground, EmpiricalStrategy, etc.)
- `v4/manuscript/` — LaTeX tables from v4 (59 `.tex` files)
- `v4/results/` — HTML tables + fiscal costs log from v4 (59 `.html` + 1 `.txt`)
- `v4/graphs/` — PDF figures from v4 (8 figures: densities, bar chart, time trends, coefficient plot)
- `v2/analysis/results/` — RTF regression tables from v2
- `v3/results/` — RTF tables + classification CSV from v3
- `v3/graphs/` — Generated PDF figures from v3

## Key Dataset Variables

### Treatment & sample
- `purchase_type` — 0=Ordinary, 1=Administrative, 2=Litigated (int8, present in parquet)
- `urgent` — Binary: 1 if administrative or litigated (`purchase_type > 0`)
- `is_admin` — Binary: 1 if administrative (`purchase_type == 1`), used in UTG analysis
- `po_firm_winner` — Binary: successful tender (renamed from `po_item_winner` in v4 parquet)

### Outcomes
- `bid_price` / `bid_price_ref` / `bid_qty` — Prices and quantities (log versions with `_log` suffix)
- `ln_n_firms` — Log number of bidding firms
- `n_firms_bids` — Number of bidding firms (56% missing in G65 dataset)

### Fixed effects & clustering
- `item` / `item_id` — Product identifier (FE in all models)
- `pbu_code` / `pbu_id` — Public buyer unit code (FE + primary clustering dimension)
- `year_n` — Year as integer (FE in specs 2-3)
- `ym_f` — Year-month factor (FE in spec 4)

### Heterogeneity
- `sus_basic` — Proxy for SUS component (1=Basic via "MEDICAMENTO" in `class_item_descr`)
- `late_period` — 1 if year >= 2014
- `high_competition` — Above-median item-level median bidders
- `large_pbu` — Above-median PBU transaction count

### Legacy (v2/v3 only)
- `jud` / `adm` / `jud_adm` — Purchase type indicators
- `po_proc_code` — Procurement procedure code (3 = electronic auction/pregão)
- `m_y` — Year-month (Stata ym format in v3, timestamp in v4 parquet)

## Econometric Approach

The v4 analysis uses `fixest::feols` (equivalent to Stata `reghdfe`):
- **4 FE specifications:** (1) Item, (2) Item+Year, (3) Item+Year+PBU (preferred), (4) Item+YM+PBU
- **Clustering:** PBU (primary), item, and two-way PBU×Item (robustness)
- **Sample (v4):** BEC-G65-WORK1.parquet, 479K obs, Group 65 medical items; restricted to items with both litigated and ordinary purchases (226K obs); winners only for most tables (197K obs)
- **Sample (v2):** Electronic auctions only (`po_proc_code == 3`), items with both types
- **Sample (v3):** All auction types in BEC_JUD.dta (193K obs)
- **Winsorization:** 1%/99% baseline; robustness with 0% and 5%/95%
- **Coefficient interpretation:** Use `exp(β)-1` for percentage effects from log-level regressions
- **Thread parallelism:** fixest uses OpenMP (16 threads per regression); scripts run sequentially via `run_all.R`

## Conventions

- v4 R scripts use `utils.R` for shared path constants and helpers; sourced automatically via robust `--file=` detection
- v4 caches prepared data at `/tmp/v4_prepared.rds` (no compression, ~1.2GB); scripts 01-07 read from cache
- v4 outputs LaTeX (`.tex` in `v4/manuscript/`) and HTML (`.html` in `v4/results/`) for each table via `modelsummary`
- v4 graphs are saved as PDF in `v4/graphs/`
- All Stata scripts (v2/v3) use absolute paths to the datasets directory
- Stata scripts output RTF to version-specific results directories
- The manuscript uses `\input{}` to include section files and generated tables
- v3/v4 scripts are numbered and must run sequentially (00 first); v3 analyses after 00 can run in parallel
