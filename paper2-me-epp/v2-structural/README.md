# Paper 2 — v2-structural (top-5 upgrade)

**Goal**: lift the paper from top-field (JPubE/AEJ:Policy) to top-5 (AER/QJE/ReStud) by replacing the reduced-form Gelbach mediation with **structural auction estimation** (Krasnokutskaya 2011 / GPV 2000 / Carvalho 2019).

## Relationship to v1 (root)

- **v1 (root)**: reduced-form staggered-DiD paper, 180-word abstract, 68pp manuscript. Stable, submittable to JPubE.
- **v2-structural**: structural estimation of cost distributions SME vs non-SME, bid-level data, counterfactual welfare decomposition. **All new work lands here**; v1 root remains unchanged.

## Data foundations (sprint 0, 2026-04-20)

### Source: `paper3-frequent-losers/v3/data/processed/bid_level_with_prices.parquet`

39.96M bids, 2009–2019. Schema:
`mêsanoencerramento, códigofornecedor, numerodaoc, códigoitem, códigounidadecompradora, descriçãoprocedimentocompra, won, bid_price, negot_price, ref_price`.

### Paper-2 universe (18-month window, Group 65 + 76 controls):

| Modality | Arm | Auctions | Bids | Bids/firm |
|---|---|---|---|---|
| **Convite** | G65 | 51,555 | 138k | **1.00** (sealed-bid ✓) |
| Convite | Controls | 406,691 | 1.92M | 1.00 |
| **Pregão** | G65 | 163,004 | 1.81M | 3.20 (iterative) |
| Pregão | Controls | 167,827 | 3.99M | 4.29 |
| Dispensa | Controls | 105,477 | 1.32M | 4.15 |

Dispensa has no G65 bids (values below Dispensa ceiling don't hit medical supplies).

## Identification strategy

1. **Convite G65 (51,555 auctions, sealed-bid)** → **GPV (2000) non-parametric**. Pure FPSB setting. First-pass structural pilot.
2. **Pregão G65 (163k auctions, iterative + random close)** → **Carvalho (2019 World Bank)** / Hong-Shum (2003) English-reverse model.
3. **Cross-modality validation**: same items procured in both modalities → cost distributions should converge if model is well-specified.

## Pipeline

| Script | Purpose | Output |
|---|---|---|
| `32_bid_level_merge.R` | Merge bid-level with Paper-2 keys (group, date, winner-SME, class) | `data/processed/{convite,pregao}_{g65,controls}.parquet` |
| `33_descriptives.R` | First-stage descriptives: bid distributions, firm counts, Nash-style summary | `output/tables/tab_v2_desc.tex` |
| `34_gpv_convite.R` | GPV non-parametric on Convite G65 | `data/processed/convite_pseudo_costs.parquet` |
| `35_pregao_semi.R` | Carvalho-style estimation on Pregão G65 | `data/processed/pregao_pseudo_costs.parquet` |
| `36_counterfactuals.R` | Simulate SME-only vs. open equilibria, welfare decomposition | `output/tables/tab_v2_welfare.tex` |

## Known gaps to address

- **Bidder-level SME flag**: bid_level_with_prices.parquet has no `me_epp` per bidder. Need to derive from `Firms_final.parquet` (firm registry with `fornec_enquad`, `porte_empresa`) or re-extract raw CSV with bid-level me_epp field. **S1 decision.**
- **Pharma/CMED class flag**: `class_alt == 6531` split needs merge from Paper-2 parquet.
- **Time index**: bid-level uses `mêsanoencerramento` string; Paper-2 uses `data_oc_numb` Stata int. Bridge via `/tmp/p2_keys.parquet`.

## Target journals

- **Primary**: ReStud, QJE (structural identification + welfare)
- **Secondary**: JPubE (if structural story weaker than hoped)
- **Timeline**: 4 weeks pilot + 2 months estimation + 1 month writeup = ~4 months to complete draft
