# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Academic research paper: **"Bitter Pills to Swallow: The Enforcement Costs of Health Litigation"** by Darcio Genicolo-Martins & Paulo Furquim de Azevedo (INSPER). The paper estimates how court-mandated health procurement in Brazil (2009-2019) affects prices, bidder participation, and success rates using matched administrative and procurement data.

## Tech Stack

- **Stata/SE** for data processing and econometric analysis (requires `reghdfe`, `ftools`)
- **LaTeX** (elsarticle document class, chicago bibliography style) for the manuscript
- Runs on WSL2 (Linux under Windows)

## Common Commands

### Stata Analysis (v2 is the current version)

```bash
# Install required Stata packages (one-time setup)
stata-se -b -q do v2/analysis/install_packages.do

# Run balance table analysis
stata-se -b -q do v2/analysis/balance_table.do

# Run descriptive statistics
stata-se -b -q do v2/analysis/desc_stats_table_v2.do

# Run main regressions (clustered standard errors, multi-way FE)
stata-se -b -q do v2/analysis/clustered_regressions.do

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

- `v2/analysis/` — **Current analysis scripts** (use these, not `analysis/`)
  - `clustered_regressions.do` — Main econometric analysis (Tables 4-8: reference prices, quantities, negotiated prices, firm participation, success rates)
  - `balance_table.do` — Balance tests between admin vs litigated purchases
  - `desc_stats_table_v2.do` — Descriptive statistics by purchase type
- `analysis/` — Original/legacy analysis scripts (v1)
- `datasets/` — Stata .dta data files (large, not tracked in git)
  - `3_BEC_PAPER_1_JUD_FINAL.dta` — Primary analysis dataset
  - `3_BEC_PAPER_1_JUD_FINAL_PANEL.dta` — Panel format variant
- `manuscript/` — LaTeX source files
  - `main.tex` — Master document (inputs section files)
  - `EmpiricalStrategy.tex` — Core econometric approach and results
  - `figures/` — Paper figures (PNG/PDF)
- `presentations/` — Conference presentation slides
- `drafts/` — Historical manuscript versions

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

The main analysis (`clustered_regressions.do`) uses `reghdfe` with:
- **Fixed effects:** Item, Year, PBU, Year-Month (in various combinations)
- **Clustering:** Standard errors clustered at PBU level (primary), item level, and two-way (robustness)
- **Sample restriction:** Electronic auctions only (`po_proc_code == 3`), items that have both litigated and ordinary purchases
- **Winsorization:** Applied at 1%/99% percentiles for key outcome variables

## Conventions

- All Stata scripts use absolute paths to the datasets directory
- Stata scripts output LaTeX tables (`.tex`) for direct inclusion in the manuscript via `\input{}`
- Regression tables are exported as RTF to `v2/analysis/results/`
- The manuscript uses `\input{}` to include section files and generated tables
