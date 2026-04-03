# Replication Package

**Paper:** "Screening for Bid Rigging with Frequent Losers in Public Procurement"
**Authors:** Darcio Genicolo-Martins & Paulo Furquim de Azevedo (INSPER)
**Journal:** Journal of Law and Economics (submitted April 2026)

---

## Overview

This package reproduces all tables, figures, and statistical results in the paper.
The pipeline runs in approximately 8 minutes on a 16-core machine.

## System Requirements

- **R** >= 4.3 (tested on 4.4.2)
- **Python** >= 3.10 (only for data build stage; can be skipped if parquets provided)
- **LaTeX** (pdflatex + bibtex) for manuscript compilation
- **OS:** Linux (tested on Ubuntu 22.04 / WSL2); should work on macOS

### R Packages (installed automatically by `00_setup.R`)

Core: `data.table`, `fixest`, `ggplot2`, `arrow`, `scales`, `sensemakr`, `MatchIt`

Optional (installed on first run): `bacondecomp`, `did`, `HonestDiD`, `survival`, `igraph`, `ggraph`, `tidygraph`

### Python Packages (data build only)

`pandas`, `pyarrow`, `pyreadstat`

## Directory Structure

```
replication/
  README.md              ← this file
  code/                  ← R and Python analysis scripts
    00_master_v4.R       ← master pipeline (runs all scripts sequentially)
    00_setup.R           ← shared setup (packages, paths, helpers)
    01_data_prep.R       ← load parquets, merge, filter → analysis dataset
    02_network_analysis.R← co-bidding network, winner HHI, FL classification
    03_iv_construction.R ← leave-one-out FL supply instrument
    04_iv_regressions.R  ← IV estimation + balance tests
    05_main_regressions.R← OLS, matching, cross-fit
    06_bajari_ye_test.R  ← Bajari-Ye exchangeability + conditional independence
    07_mechanism_tests.R ← M1-M3 diagnostics
    08_did_revised.R     ← Callaway-Sant'Anna staggered DiD
    09_cade_permutation.R← CADE validation + permutation test
    10_robustness.R      ← threshold sensitivity, clustering, specification
    11_welfare_bounds.R  ← illustrative welfare calculations
    12_tables.R          ← LaTeX table generation
    13_figures.R         ← PDF figure generation
    14_quality_checks.R  ← N verification, coefficient cross-checks
    15_fl_definition_robustness.R ← IQR variants, win-rate cutoffs
    16_regime_test.R     ← structural estimation + BIC model selection
    17_stacked_did.R     ← stacked regression (Cengiz et al.)
    18_oster_delta.R     ← Oster coefficient stability
    19_dyadic_permutation.R ← FL-winner dyadic linkage test
    20_cox_survival.R    ← Cox proportional hazard model
    21_network_graph.R   ← co-bidding network visualization
    22_threshold_heatmap.R ← 2D threshold sensitivity heatmap
  data/                  ← input data (see Data Availability below)
    processed/
      BEC_collapse_final.parquet  (268 MB) — main tender-item dataset
      Firms_final.parquet         (3 MB)   — firm registry
      LOSERS_rebuilt.parquet      (696 KB) — FL counts per tender-item
      FREQ_PARTICIP_rebuilt.parquet (200 KB) — always-losers participation
      bid_level_full.parquet      (102 MB) — raw bid-level data
      firm_tender_map.parquet     (106 MB) — firm x tender participation
      firm_loss_stats.parquet     (820 KB) — per-firm win/loss stats
      cade_carteis_licitacoes_2009_2019.csv (12 KB) — CADE convictions
      cade_bec_crossmatch.csv     (12 KB) — CADE-BEC firm matches
      cade_fl_cobidders.csv       (20 KB) — FL firms co-bidding with CADE
  output/
    tables/              ← generated LaTeX tables (39 files)
    figures/             ← generated PDF figures (20+ files)
  manuscript/            ← LaTeX source (for reference)
```

## How to Reproduce

### Step 1: Data

Place all parquet and CSV files in `data/processed/`. Total size: ~480 MB.

If you have the original Stata file (`LANCES_Final_Semester.dta`, ~8 GB),
you can rebuild the parquets:

```bash
cd replication
python3 code/00_build_bidlevel.py   # ~6 min, produces 5 parquets
```

### Step 2: Analysis Pipeline

```bash
cd replication
Rscript code/00_master_v4.R         # ~8 min on 16 cores
```

This runs scripts 01-22 sequentially, producing:
- All `.tex` tables in `output/tables/`
- All `.pdf` figures in `output/figures/`
- Cached intermediate objects in `/tmp/p3v4_*.rds`

### Step 3: Manuscript Compilation

```bash
cd manuscript
pdflatex paper_screening.tex
bibtex paper_screening
pdflatex paper_screening.tex
pdflatex paper_screening.tex
```

### Running Individual Scripts

Each script can be run independently after `01_data_prep.R` has created
the cached dataset (`/tmp/p3v4_prepared.rds`):

```bash
Rscript -e '.v4_dir <- "replication"; source("replication/code/01_data_prep.R")'
Rscript -e '.v4_dir <- "replication"; source("replication/code/05_main_regressions.R")'
```

## Key Parameters

| Parameter | Value | Location |
|-----------|-------|----------|
| FL threshold | median + 1.5 x IQR | `01_data_prep.R` |
| Clustering | item level (`~item_f`) | `00_setup.R` |
| Thread limit | min(physical cores, 16) | `00_setup.R` |
| fixest lean mode | TRUE (except Bajari-Ye) | `00_setup.R` |
| Bootstrap replications | 500 (structural), 1000 (permutation) | various |

## Data Availability

The BEC data are publicly available from the Sao Paulo state government
transparency portal (transparencia.sp.gov.br). CADE cartel conviction
data are from public administrative proceedings (cade.gov.br).

The processed parquet files are derived from the raw BEC bid-level
data (`LANCES_Final_Semester.dta`, 22 semester files covering 2009-2019)
using `code/00_build_bidlevel.py`.

## Computational Environment

Results were produced on:
- Linux 6.6.87 (WSL2), AMD Ryzen 9 5900X (16 logical cores), 32 GB RAM
- R 4.4.2, data.table 1.16.4, fixest 0.12.1, arrow 18.1.0
- Python 3.12.3, pandas 2.2.2, pyarrow 18.1.0

## Contact

Darcio Genicolo-Martins: darciogm1@insper.edu.br
