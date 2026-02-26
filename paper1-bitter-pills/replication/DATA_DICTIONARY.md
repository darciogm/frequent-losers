# Data Dictionary

## Dataset: BEC-G65-WORK1.parquet

**Description:** Bid-level dataset covering all pharmaceutical procurement transactions by the São Paulo State Department of Health (SES/SP) from January 2009 through December 2019, conducted through the state's electronic procurement platform (BEC). Restricted to BEC Group 65 ("Medical, dental, and hospital equipment and supplies").

**Dimensions:** 479,330 rows × 180 columns
**Format:** Apache Parquet
**Size:** ~125 MB

---

## Key Analysis Variables

### Treatment and Sample Classification

| Variable | Type | Description | Values |
|----------|------|-------------|--------|
| `purchase_type` | int | Purchase type classification | 0 = Ordinary, 1 = Administrative, 2 = Litigated |
| `dummy_judicial` | int | Indicator for litigated purchase | 0/1 |
| `dummy_admin` | int | Indicator for administrative purchase | 0/1 |

**Derived in analysis scripts (not in raw data):**

| Variable | Type | Description | Derivation |
|----------|------|-------------|------------|
| `urgent` | int | Urgent purchase indicator | `purchase_type > 0` (administrative or litigated) |
| `is_admin` | int | Administrative purchase indicator | `purchase_type == 1` (used in UTG analysis) |

### Outcome Variables

| Variable | Type | N Valid | Mean | Min | Max | Description |
|----------|------|---------|------|-----|-----|-------------|
| `bid_price_ref` | numeric | 479,300 | 8,643.4 | 0.001 | 51,895,500 | Reference price (max price government will pay), in BRL |
| `bid_price` | numeric | 479,300 | 4,867.3 | 0 | 42,456,000 | Negotiated (final) bid price, in BRL |
| `bid_qty` | numeric | 479,300 | 98,215.7 | 1 | 701,500,000 | Quantity demanded in tender notice |
| `n_firms_bids` | numeric | 212,170 | 3.03 | 0 | 18 | Number of distinct firms submitting bids (bidding phase) |
| `po_item_winner` | numeric | 479,330 | 0.848 | 0 | 1 | Tender success indicator (1 = successful purchase) |

**Log-transformed versions (derived in analysis scripts):**

| Variable | Derivation | Description |
|----------|------------|-------------|
| `bid_price_ref_log` | `log(bid_price_ref)` where > 0 | Log reference price |
| `bid_price_log` | `log(bid_price)` where > 0 | Log negotiated price |
| `bid_qty_log` | `log(bid_qty)` where > 0 | Log quantity |
| `ln_n_firms` | `log(n_firms_bids)` where > 0 | Log number of bidding firms |

### Fixed Effects and Clustering

| Variable | Type | N Unique | Description |
|----------|------|----------|-------------|
| `item` | character | 33,144 | Item code (product identifier) — used for item FE |
| `pbu_code` | character | 100 | Public buyer unit code — used for PBU FE and primary clustering |
| `year` | character | 11 | Year (2009–2019) — used for year FE |
| `m_y` | POSIXct | — | Year-month timestamp — used for year-month FE |

**Derived in analysis scripts:**

| Variable | Derivation | Description |
|----------|------------|-------------|
| `item_id` | Factor from `item` | Item fixed effect factor |
| `pbu_id` | Factor from `pbu_code` | PBU fixed effect factor |
| `year_n` | Integer from `year` | Year as integer for FE |
| `ym_f` | Factor from `m_y` | Year-month factor for FE |

### Heterogeneity Variables (Derived in Analysis Scripts)

| Variable | Type | Description | Derivation |
|----------|------|-------------|------------|
| `sus_basic` | int | Basic SUS component proxy | 1 if "MEDICAMENTO" in `class_item_descr` |
| `late_period` | int | Late period indicator | 1 if `year >= 2014` |
| `high_competition` | int | High competition indicator | Above-median item-level median bidders |
| `large_pbu` | int | Large PBU indicator | Above-median PBU transaction count |

### Purchase Order Identifiers

| Variable | Type | N Unique | Description |
|----------|------|----------|-------------|
| `po` | character | 106,881 | Purchase order identifier |
| `po_subject` | character | 51,059 | Purchase order subject/description |
| `po_item` | character | 479,330 | Purchase-offer-item (POI) — unique observation identifier |
| `po_status_code` | character | 9 | Purchase order status code |
| `po_status_descr` | character | 9 | Purchase order status description |
| `po_proc_code` | numeric | — | Procurement procedure code (1–3; 3 = electronic auction/pregão) |

### Item Characteristics

| Variable | Type | N Unique | Description |
|----------|------|----------|-------------|
| `item` | character | 33,144 | Item code |
| `item_descr` | character | 31,428 | Item description |
| `item_unit` | character | 535 | Unit of measurement |
| `categ_item` | integer | 1 | Item category (all = 1 in this dataset) |
| `group_item` | character | 1 | BEC group code (all = "65" in this dataset) |
| `group_item_descr` | character | 1 | BEC group description |
| `class_item` | character | 54 | Item classification code |
| `class_item_descr` | character | 93 | Item classification description |

### Public Buyer Unit (PBU) Characteristics

| Variable | Type | N Unique | Description |
|----------|------|----------|-------------|
| `pbu_code` | character | 100 | PBU code |
| `pbu_cnpj` | character | 96 | PBU fiscal identifier (CNPJ) |
| `pbu_descr` | character | 95 | PBU name/description |
| `pbu_latit` | numeric | — | PBU latitude (N valid: 451,283) |
| `pbu_longit` | numeric | — | PBU longitude (N valid: 451,283) |
| `pbu_zipcode` | character | 78 | PBU zip code |
| `pbu_city_code` | character | 31 | Municipality code |
| `pbu_city_descr` | character | 31 | Municipality name |
| `pbu_region_code` | character | 15 | Health region code |
| `pbu_region_descr` | character | 15 | Health region description |
| `pbu_uo_code` | character | 16 | Administrative unit code |
| `pbu_uo_descr` | character | 16 | Administrative unit description |
| `pbu_type_mgmt_descr` | character | 3 | PBU management type |
| `pbu_ibge_cod_cidade` | numeric | — | IBGE municipality code |

### Firm Characteristics

| Variable | Type | N Unique | Description |
|----------|------|----------|-------------|
| `firm_id` | character | 2,203 | Firm identifier |
| `firm_descr` | character | 2,130 | Firm name |
| `firm_zipcode` | character | 1,858 | Firm zip code |
| `firm_city` | character | 281 | Firm city |
| `firm_state` | character | 24 | Firm state |
| `firm_latit` | numeric | — | Firm latitude (N valid: 376,498) |
| `firm_longit` | numeric | — | Firm longitude (N valid: 376,498) |
| `firm_state_sp` | numeric | — | Indicator: firm located in São Paulo (N valid: 406,611) |
| `firm_type_code` | numeric | — | Firm type code |
| `firm_person_code` | numeric | — | Legal person type code |

### Bidding Process Variables

| Variable | Type | Description |
|----------|------|-------------|
| `bid_price_reg` | numeric | Registered price indicator (0/1) |
| `bid_green_item` | numeric | Green procurement indicator (0/1) |
| `bid_total_ref` | numeric | Total reference value (price × quantity) |
| `n_firms_prop` | numeric | N firms in proposal phase |
| `n_firms_bids` | numeric | N firms in bidding phase |
| `n_firms_negot` | numeric | N firms in negotiation phase |
| `n_firms_pref` | numeric | N firms in preference phase |

### Distance Variables (km between PBU and firm)

| Variable | Type | Description |
|----------|------|-------------|
| `dist_min_prop` | numeric | Min distance to participating firm (proposal phase) |
| `dist_max_prop` | numeric | Max distance to participating firm (proposal phase) |
| `dist_mean_prop` | numeric | Mean distance to participating firms (proposal phase) |
| `dist_median_prop` | numeric | Median distance to participating firms (proposal phase) |

*Similar variables exist for `_bids`, `_negot`, and `_pref` phases.*

### Process Duration Variables

| Variable | Type | Description |
|----------|------|-------------|
| `proc_length_sec_prop` | numeric | Duration of proposal phase (seconds) |
| `proc_length_minutes_prop` | numeric | Duration of proposal phase (minutes) |
| `proc_length_hours_prop` | numeric | Duration of proposal phase (hours) |
| `proc_length_days_prop` | numeric | Duration of proposal phase (days) |

*Similar variables exist for `_bids`, `_negot`, and `_pref` phases.*

### Price Statistics by Phase

| Variable | Type | Description |
|----------|------|-------------|
| `bid_price_prop_min` | numeric | Min bid price (proposal phase) |
| `bid_price_prop_max` | numeric | Max bid price (proposal phase) |
| `bid_price_prop_mean` | numeric | Mean bid price (proposal phase) |
| `bid_price_prop_median` | numeric | Median bid price (proposal phase) |
| `bid_price_prop_sd` | numeric | Std. dev. of bid prices (proposal phase) |

*Similar variables exist for `_bids`, `_negot`, and `_pref` phases.*

### Winner Variables by Phase

| Variable | Type | Description |
|----------|------|-------------|
| `po_winner_sum_prop` | numeric | Sum of winner indicators (proposal phase) |
| `po_winner_max_prop` | numeric | Max winner indicator (proposal phase) |

*Similar variables exist for `_bids`, `_negot`, and `_pref` phases.*

### Merge and Auxiliary Variables

| Variable | Type | Description |
|----------|------|-------------|
| `key1_merge` | character | Primary merge key (unique per observation) |
| `_merge_ucs` | ordered | Merge indicator from PBU matching |
| `_merge_firm_geoc_final` | ordered | Merge indicator from firm geocoding |
| `_merge_firms` | ordered | Merge indicator from firm matching |
| `_merge` | ordered | General merge indicator |
| `sme` | character | Small/medium enterprise indicator |
| `check_po_status` | numeric | Purchase order status check flag |
| `pbu_code_year` | character | PBU-year combination |
| `po_item_number_firm` | character | POI-firm combination identifier |
| Various `*_unique_count` | numeric | Counts of unique values (dataset-level constants) |

---

## Notes

1. **Currency:** All monetary values are in Brazilian Reais (BRL). No inflation adjustment is applied; year fixed effects absorb common price trends.
2. **Missing values:** Variables with fewer than 479,330 non-missing observations have missing data. Key missingness: `n_firms_bids` (56% missing — available only for tenders reaching bidding phase), firm geocoding (21% missing).
3. **Winsorization:** The analysis scripts winsorize continuous variables at the 1st/99th percentiles (baseline), with robustness checks at 0% and 5%/95%.
4. **Sample restrictions:** The analysis sample restricts to items with at least one ordinary and one litigated purchase (~226,000 obs). Winner-only regressions further restrict to `po_item_winner == 1` (~197,000 obs).
