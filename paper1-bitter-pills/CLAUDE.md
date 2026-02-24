# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Academic research paper: **"Bitter Pills to Swallow: The Enforcement Costs of Health Litigation"** by Darcio Genicolo-Martins & Paulo Furquim de Azevedo (INSPER). The paper estimates how court-mandated health procurement in Brazil (2009-2019) affects prices, bidder participation, and success rates using matched administrative and procurement data.

## Tech Stack

- **Stata/SE** for data processing and econometric analysis (requires `reghdfe`, `ftools`)
- **Python 3** for edital text classification (`v3/classify_editais.py`)
- **LaTeX** (elsarticle document class, chicago bibliography style) for the manuscript
- Runs on WSL2 (Linux under Windows)

## Common Commands

### Stata Analysis

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

Three analysis versions exist. **v2** is the primary manuscript version; **v3** extends to the full sample:

- `v2/analysis/` — **Primary analysis** (subsample: electronic auctions with both litigated and ordinary purchases)
  - `clustered_regressions.do` — Main regressions (Tables 4-8: reference prices, quantities, negotiated prices, firm participation, success rates)
  - `balance_table.do` — Balance tests between admin vs litigated purchases
  - `desc_stats_table_v2.do` — Descriptive statistics by purchase type
  - `fiscal_costs.do` — Aggregate fiscal cost calculations
  - `heterogeneity.do` — Heterogeneous effects analysis
  - `underthegun_robustness.do` — "Under the gun" robustness with progressive controls
  - `winsorization_sensitivity.do` — Sensitivity to winsorization levels (0%, 1%, 5%)
- `v3/analysis/` — **Extended full-sample analysis** (BEC_JUD.dta, 193K obs, all auction types)
  - Numbered scripts `00_prepare_data.do` through `07_graphs.do` (must run 00 first)
  - `run_all.sh` — Orchestration: serial data prep → parallel analyses → error checking → output verification
- `v3/classify_editais.py` — Python regex classifier for edital text (judicial/administrative/ordinary)
- `replication/replicate_paper.do` — Exact OLS + xtreg specifications matching the manuscript
- `analysis/` — Legacy v1 scripts (do not use)

### Data

- `datasets/` — Processed Stata .dta files (not tracked in git)
  - `3_BEC_PAPER_1_JUD_FINAL.dta` — v2 subsample dataset
  - `3_BEC_PAPER_1_JUD_FINAL_PANEL.dta` — Panel format variant
  - `BEC_JUD.dta` — Full-sample dataset (v3, 193K obs, all auction types)
  - `Classif_editais/` — Raw edital classification data (~18GB compressed): regex dummy CSVs, judicial reference data

### Manuscript & Output

- `manuscript/` — LaTeX source (main.tex inputs section files: Introduction, InstitutionalBackground, EmpiricalStrategy, etc.)
- `v2/analysis/results/` — RTF regression tables from v2
- `v3/results/` — RTF tables + classification CSV from v3
- `v3/graphs/` — Generated PDF figures (density plots, coefficient plots, time trends)

## Key Dataset Variables

- `jud` / `adm` / `jud_adm` — Purchase type indicators (judicial, administrative, either)
- `purchase_type` — Derived: 0=Ordinary, 1=Administrative, 2=Litigated
- `urgent` — Binary: 1 if administrative or litigated (purchase_type > 0)
- `bid_price` / `bid_price_ref` / `bid_qty` — Prices and quantities (log versions with `_log` suffix)
- `item` — Product identifier (used as fixed effect)
- `pbu_code` — Public buyer unit code (used for clustering)
- `po_proc_code` — Procurement procedure code (3 = electronic auction/pregão)
- `m_y` — Year-month (used as fixed effect)
- `n_firms_bids` — Number of bidding firms

## Econometric Approach

The main analysis uses `reghdfe` with:
- **Fixed effects:** Item, Year, PBU, Year-Month (in various combinations)
- **Clustering:** Standard errors clustered at PBU level (primary), item level, and two-way (robustness)
- **Sample restriction (v2):** Electronic auctions only (`po_proc_code == 3`), items that have both litigated and ordinary purchases
- **Sample (v3):** All auction types in BEC_JUD.dta (193K observations)
- **Winsorization:** Applied at 1%/99% percentiles for key outcome variables
- **Coefficient interpretation:** Use `exp(β)-1` for percentage effects from log-level regressions

## Conventions

- All Stata scripts use absolute paths to the datasets directory
- Stata scripts output LaTeX tables (`.tex`) for direct inclusion in the manuscript via `\input{}`
- Regression tables are exported as RTF to version-specific results directories
- The manuscript uses `\input{}` to include section files and generated tables
- v3 scripts are numbered and must run sequentially (00 first), though analyses after 00 can run in parallel
