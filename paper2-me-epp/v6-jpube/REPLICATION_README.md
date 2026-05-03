# Replication package — *The Cost of Inclusion: Decomposing Bidder Exclusion in Public Procurement*

**Author:** Darcio Genicolo-Martins (Insper, São Paulo)
**Manuscript version:** v5 (April 2026)
**Target journal:** Journal of Public Economics
**Compliance:** AEA Data and Code Availability Policy (adopted by JPubE)

This package contains the code and processed data necessary to reproduce
every table and figure in the manuscript and online appendix.

---

## 1. Data

### 1.1 Primary data sources

| Source | Description | Access | Confidentiality |
|---|---|---|---|
| **BEC (Bolsa Eletrônica de Compras)** | Administrative records of all electronic public procurement on the São Paulo state platform, 2005–2019. ~860,000 purchase orders, ~4.8M item-level transactions. | SEFAZ-SP under data-use agreement. Contact: `<sefaz-sp-contact-tbd>` | Restricted (administrative microdata) |
| **CADMAT classification** | São Paulo state product/material classification codes. | Public — `cadmat.sp.gov.br` | Public |
| **Brazilian SME registry (Receita Federal)** | Used to construct the SME flag at the firm level, validated against historical bidding behavior. | Public — Receita Federal CNPJ public registry | Public |

### 1.2 Confidentiality and ethics statement

The BEC microdata are administrative records covering identifiable firms, contracts, and public buyers. The data-use agreement with SEFAZ-SP permits academic use under the following restrictions:

- Pre-merged, anonymized analytical samples are included directly in this package (firm IDs replaced with deterministic hashes; PBU IDs aggregated to PBU-class level).
- The raw BEC microdata are NOT included. Researchers seeking direct access must apply to SEFAZ-SP independently.
- Files in `data/raw/` are git-ignored. Files in `data/processed/` contain only the pre-merged samples used for replication of headline tables and figures.

### 1.3 Pre-merged datasets included

| File | Description | Size | Used by |
|---|---|---|---|
| `data/processed/bids_uh_cleaned.parquet` | Bid-level Pregão sample after Krasnokutskaya UH cleaning | ~12 MB | Scripts 35-62 |
| `data/processed/pregao_dropouts.parquet` | Drop-out exit prices on losers (point-ID inputs) | ~3 MB | Scripts 36-37 |
| `data/processed/pregao_fc.parquet` | Estimated cost distributions $F_c^k$ by stratum | <1 MB | Scripts 41-50 |
| `data/processed/uh_variance.parquet` | Method-of-moments UH variance decomposition | <1 MB | Scripts 40-41 |
| `data/processed/decomp_grid.parquet` | BNE counterfactual simulations | ~2 MB | Scripts 50-55 |
| `data/processed/welfare_bootstrap.parquet` | Cluster-bootstrap welfare CIs | ~2 MB | Script 56 |
| `data/processed/strict_invariance.parquet` | Strict-invariance robustness | <1 MB | Script 53 |
| `data/processed/bid_level_sme_g65.parquet` | CADMAT classification join key | ~5 MB | Scripts 31-32, 61 |

Total processed-data footprint: ~30 MB.

---

## 2. Software requirements

### 2.1 Operating system

- Linux (tested on Ubuntu 20.04 / WSL2 kernel 6.6.87)
- macOS (untested but expected to work)
- Windows (not tested; recommend WSL2)

### 2.2 R environment

- R version 4.5.x (any 4.5 patch)
- BLAS/LAPACK: standard (Reference, OpenBLAS, or MKL — all produce the same point estimates within Monte Carlo precision)
- Package versions pinned in `renv.lock` (regenerate with `renv::restore()`)

Key packages:

```
data.table  >= 1.16.0
arrow       >= 17.0
fixest      >= 0.12.1
duckdb      >= 1.1.0
DBI         >= 1.2
ggplot2     >= 3.5
Matrix      >= 1.7
modelsummary >= 2.2 (tables only)
kableExtra  >= 1.4 (tables only)
```

### 2.3 LaTeX

- TeX Live 2025 (or newer)
- Required packages: `elsarticle`, `threeparttable`, `booktabs`, `microtype`, `adjustbox`, `natbib`, `hyperref`

### 2.4 Computational requirements

| Operation | Memory peak | CPU time | Threads |
|---|---|---|---|
| Single-pass DiD (script 12_appendix_did) | <2 GB | ~1 min | 12 |
| BNE Monte Carlo (script 50, B=2000) | ~4 GB | ~5 min | 12 |
| Cluster-bootstrap welfare (script 56, B=500) | ~6 GB | ~25 min | 12 |
| Collusion screens 58-61 (B=500/200) | ~3 GB | ~3 min | 1 (sequential) |
| Full pipeline end-to-end | <8 GB | ~45 min | 12 |

The pipeline is designed to run on a workstation with 16 GB RAM and 12 cores. Settings are documented in `scripts/utils.R`.

---

## 3. File structure

```
paper2-me-epp/v5-jpube/
├── REPLICATION_README.md         # This file
├── manuscript/                    # LaTeX source
│   ├── paper_v5.tex              # Main entry point
│   ├── 00_introduction.tex       # — 12_appendix_did.tex
│   ├── highlights.tex
│   ├── cover_letter.tex
│   ├── online_appendix.tex
│   ├── References.bib
│   └── paper_v5.pdf              # Compiled output
├── scripts/                       # R replication code
│   ├── utils.R                   # Shared paths and helpers
│   ├── 31_*.R — 62_*.R           # Numbered pipeline (see §4)
├── data/
│   ├── raw/                       # NOT INCLUDED — git-ignored
│   └── processed/                 # Pre-merged samples (parquet)
├── output/
│   ├── tables/                    # Generated .tex tables
│   ├── figures/                   # Generated .pdf figures
│   └── INTERNAL_NOTES.md          # Internal-only artifacts log
├── logs/                          # Execution logs
└── renv.lock                      # Package version pin
```

---

## 4. Pipeline — execution order

The pipeline is sequential. Each numbered script depends on the outputs
of earlier scripts. Run them in order:

```bash
cd v5-jpube
for s in scripts/31_*.R scripts/3[2-9]_*.R scripts/4[0-9]_*.R scripts/5[0-9]_*.R scripts/6[0-2]_*.R; do
  echo "Running $s ..."
  Rscript $s 2>&1 | tee logs/$(basename $s .R).log || { echo "FAILED: $s"; exit 1; }
done
```

Or to reproduce a specific table/figure, run only the script that produces it. Map below.

### Script-to-output map

| Script | Outputs | Used in section |
|---|---|---|
| `31_historical_sme.R` | Historical SME identification | §2 |
| `32_historical_sme_v2.R` | Pharma-narrow SME refinement | §2 |
| `33_pharma_flag.R` | CADMAT 6531/6532 etc. flag | §2 |
| `34_s1_descriptives.R` | `tab_v3_s1_handoff` | Tables, §2 |
| `35_pregao_dropouts.R` | Drop-out exit data | §3, §4 |
| `36_pregao_fc_dropout.R` | All-bidders ECDF $F_c^k$ | §4.1 |
| `37_pregao_ht_refined.R` | Haile-Tamer refined bounds | §4.1, robust |
| `38_cross_modality.R` | Convite GPV vs Pregão drop-out | §4.1, Fig 4.1 |
| `39_primitive_invariance.R` | KS test on $F_c$ stability | §3, robust |
| `40_uh_variance.R` | Method-of-moments UH decomp | §4.2 |
| `41_uh_clean_bids.R` | UH-clean residuals $\hat e_{it}$ | §4.2 |
| `50_bne_decomp.R` | BNE counterfactual simulation | §5 |
| `51_decomp_grid.R` | Decomposition over scenarios | §5 |
| `52_strict_invariance.R` | Strict-invariance robustness | §7.1 |
| `53_window_filter.R` | Window/filter sensitivity | §7.2 |
| `55_welfare.R` | Welfare arithmetic | §6 |
| `56_welfare_bootstrap.R` | Cluster-bootstrap welfare CIs | §6.3 |
| `57_welfare_adherence_sensitivity.R` | Adherence-rate sensitivity | §6.5.1 |
| `58_collusion_screen.R` | Raw Conley close-pair screen | §7.4 |
| `59_collusion_screen_anchor.R` | Anchor-controlled screen | §7.4 |
| `60_collusion_screen_bajari_ye.R` | Bajari-Ye persistent-pair | §7.4 |
| `61_collusion_screen_pair_classcond.R` | Class-conditional Bajari-Ye | §7.4 |
| `62_maskin_riley_fpsb_bound.R` | Maskin-Riley FPSB bound | §3, §7 |
| `12_appendix_did/*.R` | DiD design-validation | App. A |

---

## 5. Replication checks

### 5.1 Headline numbers

After running the full pipeline, the following numbers should match (within Monte Carlo noise of $\pm 1\%$):

| Object | Expected value | Source table | Script |
|---|---|---|---|
| DiD coefficient on $\log p^{\mathrm{final}}$, 18-month window, with PBU controls | $-0.113$ (s.e. $0.020$) | `tab_prices` | `12_appendix_did/01_did.R` |
| Within-auction share, non-pharma, main spec | 74.5% | `tab_v3_bne_decomp` | `50_bne_decomp.R` |
| Within-auction share, pharma, main spec | 73.3% | `tab_v3_bne_decomp` | `50_bne_decomp.R` |
| Welfare cost (% of $p_{S_1}$, $\lambda=0.30$), non-pharma | 28.7% | `tab_v3_welfare` | `55_welfare.R` |
| Welfare cost (% of $p_{S_1}$, $\lambda=0.30$), pharma | 47.0% | `tab_v3_welfare` | `55_welfare.R` |
| Annual aggregate welfare cost (43% adherence) | R\$ 55M | `tab_welfare_annual` | `55_welfare.R` |
| Implicit welfare weight $w_\star^{\text{SME}}$, non-pharma main | 2.42 | text §6 | `55_welfare.R` |

### 5.2 Reproducibility

All scripts set `set.seed(20260427L)` for any randomization. The pipeline is deterministic given pinned package versions; values should match exactly.

### 5.3 Recompiling the manuscript

```bash
cd manuscript
pdflatex paper_v5.tex
bibtex paper_v5
pdflatex paper_v5.tex
pdflatex paper_v5.tex
pdflatex paper_v5.tex   # 4 passes for full label resolution
```

Expected output: 88 pages, no LaTeX warnings, no overfull boxes.

---

## 6. Known limitations

1. **Raw BEC microdata are not included.** Replication of pre-merge steps (CSV→parquet conversion, variable creation, sample restrictions) requires SEFAZ-SP access. Pre-merged samples are included for downstream replication.

2. **Cluster bootstrap is computationally expensive.** B=500 replicates × 8 strata × ~30s per replicate ≈ 30 min on 12 cores. Reduce B in `56_welfare_bootstrap.R` if running on smaller hardware (line 23, `B_BS <- 500`).

3. **Some intermediate scripts (12_appendix_did/*) require auxiliary CSV files** generated by the historical pipeline. These are documented inline in each script.

---

## 7. Contact

- **Author:** Darcio Genicolo-Martins
- **Email:** `darciogm1@insper.edu.br`
- **Institution:** Insper, R. Quatá 300, São Paulo, SP, 04546-042, Brazil
- **Project repo:** `<placeholder for public archive — to be assigned upon acceptance>`

---

## 8. Citation

If you use this code or data in academic work, please cite:

> Genicolo-Martins, D. (2026). The Cost of Inclusion: Decomposing Bidder Exclusion in Public Procurement. *Journal of Public Economics*, [forthcoming].

---

## 9. License

Code: MIT License.
Pre-merged data: CC-BY-4.0 (with attribution).
Raw BEC microdata: governed by the SEFAZ-SP data-use agreement; not redistributable.

---

*Last updated: 2026-04-27.*
