# Data Access Instructions

## Overview

The empirical analysis in this paper uses confidential administrative records from the **Bolsa Eletronica de Compras (BEC)**, the electronic procurement platform of the state of Sao Paulo, Brazil. These data are maintained by the **Secretaria da Fazenda e Planejamento do Estado de Sao Paulo (SEFAZ/SP)**.

The raw data cannot be redistributed as part of this replication package due to confidentiality restrictions. Researchers wishing to replicate this study must obtain the data directly from SEFAZ/SP.

## Required File

| File | Size | Format | Encoding | Separator |
|------|------|--------|----------|-----------|
| `Paper2_ME_EPP.csv` | ~6.4 GB | CSV | Latin-1 (ISO-8859-1) | Semicolon (`;`) |

This file contains **373 columns** of item-level public procurement records covering the period **2016–2019**.

## How to Obtain the Data

1. **Contact SEFAZ/SP** to request access to BEC procurement microdata:
   - Website: https://www.fazenda.sp.gov.br/
   - BEC Portal: https://www.bec.sp.gov.br/
   - Researchers should submit a formal data access request to the Coordenadoria de Compras Eletronicas, explaining the academic purpose of the research.

2. **Describe the data needed:** Request item-level procurement records from the BEC system for the period September 2016 through August 2019, including:
   - Transaction details (prices, dates, quantities)
   - Participating firms and bid information
   - Buyer unit (PBU) identifiers
   - Product group codes (codigogrupo)
   - Item classification codes
   - Geographic information (firm and PBU locations)

3. **Expected timeline:** Approximately 3 months from initial request to data delivery.

4. **Place the file** in this directory (`data/raw/`) as `Paper2_ME_EPP.csv`.

## Key Variables

The following are key variables used by the analysis pipeline (the full dataset contains 373 columns):

| Variable | Description |
|----------|-------------|
| `codigogrupo` | Product group code (e.g., "65" for medical/dental/hospital supplies) |
| `data_oc_numb` | Tender date as Stata monthly date (months since January 1960) |
| `preco_final` | Final negotiated price |
| `oc_item_status` | Item completion status (1 = completed) |
| `num_firms` | Number of participating firms |
| `num_bids` | Number of valid bids |
| `dist1` | Distance (km) from buyer unit to winning firm |
| `convite` | Indicator for sealed-bid (convite) tender type |
| `quantidade` | Quantity requested |
| `item_alt` | Item fixed-effect identifier |
| `pbu_alt` | Buyer unit (PBU) fixed-effect identifier |

## Verification

After placing the file, the pipeline will automatically:
1. Read the CSV (Latin-1, semicolon-separated).
2. Select the 14 required columns.
3. Convert to Parquet format (`data/processed/paper2_me_epp.parquet`) for fast subsequent access.

You can verify the file is correctly placed by running:
```bash
Rscript scripts/00_master.R
```

The pre-flight checks will confirm whether the data file is found.
