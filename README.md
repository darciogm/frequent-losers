# Bitter Pills to Swallow - Research Project

Research project on public procurement and health judicialization in Brazil, comprising a doctoral thesis and three papers.

## Papers

- **Paper 1 (Bitter Pills)**: The impact of drug judicialization on public procurement outcomes in the state of São Paulo, Brazil. Uses BEC (Bolsa Eletrônica de Compras) procurement data matched with judicial S-CODES data.
- **Paper 2 (ME/EPP)**: Analysis of micro and small enterprises (ME/EPP) participation in public procurement.
- **Paper 3 (Thresholds)**: Analysis using regression discontinuity / threshold-based identification.
- **Thesis**: Doctoral thesis encompassing the three papers (final version: June 2020).

## Directory Structure

```
bitter-pills/
├── paper1-bitter-pills/          # Paper 1 - Main paper (Bitter Pills)
│   ├── manuscript/               # LaTeX manuscript (current version)
│   │   ├── figures/              # Manuscript figures
│   │   ├── model/                # Formal model (.tex)
│   │   └── presentation/         # Beamer presentation (.tex)
│   ├── analysis/                 # Stata analysis code (.do)
│   │   └── results/              # Regression tables (.rtf)
│   ├── datasets/                 # Paper 1 specific datasets (.dta, .csv)
│   ├── presentations/            # PowerPoint presentations
│   └── drafts/                   # Earlier manuscript versions
│
├── paper2-me-epp/                # Paper 2 - Micro/Small Enterprises
│   ├── presentations/
│   ├── analysis/
│   └── data/
│
├── paper3-thresholds/            # Paper 3 - Thresholds
│   └── analysis/                 # Stata scripts (v10, v11, v12)
│
├── thesis/                       # Doctoral Thesis
│   └── presentations/
│
├── data/                         # Shared datasets
│   ├── raw/                      # Raw data sources
│   │   ├── bec-procurement/      # BEC procurement data (DTA, by semester)
│   │   ├── judicial-scodes/      # Judicial S-CODES data
│   │   ├── cnpj/                 # CNPJ firm registry
│   │   ├── cnae/                 # CNAE economic classification
│   │   ├── tse-electoral/        # TSE electoral data
│   │   ├── esancoes/             # Sanctions data
│   │   └── pregoeiros/           # Auctioneer (pregoeiro) data + RAIS
│   ├── geocoding/                # Geocoding data
│   │   ├── shapefiles/           # SP shapefiles (municipios, microrregioes)
│   │   ├── postal-codes/         # CEP/postal code databases
│   │   └── geocoded-datasets/    # Geocoded output datasets
│   ├── processed/                # Intermediate/derived datasets
│   ├── updates/                  # Data updates (e.g., ago-dez-2019)
│   └── audesp-entities/          # Audesp entity classification
│
├── code/                         # Shared code
│   ├── master.do                 # Master script
│   ├── data-preparation/         # Active data preparation scripts
│   └── archive/                  # Old script versions
│
├── references/                   # Reference materials
│   ├── papers/                   # Academic PDFs
│   ├── reports/                  # Reports (CNJ-Insper, etc.)
│   ├── student-work/             # Supervised student papers
│   └── data-dictionaries/        # Variable lists, RAIS layouts
│
├── supporting/                   # Supporting materials
│   ├── drug-selection/           # Drug selection criteria and lists
│   ├── exploratory/              # Exploratory analyses, common trends
│   └── graphs/                   # Stata graphs (.gph)
│
└── archive/                      # Archived materials
    ├── old-data-backups/         # Old BEC data backups
    ├── old-code-versions/        # Obsolete code
    ├── see-later/                # Deferred items
    └── misc/                     # Miscellaneous
```

## Key Data Sources

- **BEC (Bolsa Eletrônica de Compras)**: Electronic procurement platform for the state of São Paulo
- **S-CODES**: Judicial case data from São Paulo courts related to health/drug lawsuits
- **CNPJ**: Brazilian firm registry (Receita Federal)
- **TSE**: Electoral data from the Superior Electoral Tribunal
- **RAIS**: Annual Social Information Report (labor market data)
- **Audesp**: Audit system for São Paulo public entities

## Software

- **Stata**: Primary analysis tool (.do scripts, .dta datasets)
- **LaTeX**: Manuscript preparation
- **Python**: Geocoding (Geopandas, Fiona)
