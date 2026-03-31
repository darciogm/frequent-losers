# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Academic research paper: **"Frequent Losers in Public Procurement"** by Darcio Genicolo-Martins & Paulo Furquim de Azevedo (INSPER). The paper proposes frequent losers (firms that systematically lose public tenders) as a screening marker for bid-rigging cartels in Brazilian public procurement (BEC, State of Sao Paulo, 2009-2019).

This is **Paper 3** in the `bitter-pills` monorepo. See also `../paper1-bitter-pills/` and `../paper2-me-epp/`.

## Commands

```bash
# Full R pipeline (~8 min on 16 cores)
cd paper3-frequent-losers
Rscript scripts/00_master.R

# Python data build (~6 min, only needed if parquets are missing)
python3 scripts/00_build_bidlevel.py

# Individual R scripts (requires /tmp/p3_prepared.rds from 01_clean.R)
Rscript -e ".script_dir <- 'scripts'; source('scripts/01_clean.R')"
Rscript -e ".script_dir <- 'scripts'; source('scripts/02_analysis.R')"

# Manuscript compilation
cd manuscript && pdflatex main.tex && biber main && pdflatex main.tex && pdflatex main.tex
```

## Architecture

### Two-stage pipeline: Python build → R analysis

**Stage 1: `00_build_bidlevel.py`** (Python, runs once)
- Reads `LANCES_Final_Semester.dta` (~40M bid-level rows, 22 semesters)
- Produces 5 parquets in `data/processed/`:
  - `bid_level_full.parquet` (40M rows) — firm × item × OC bids
  - `firm_tender_map.parquet` (16.8M rows) — firm × (OC, item) with `won` flag
  - `firm_loss_stats.parquet` (41K rows) — per-firm win_rate, always_loser flag
  - `FREQ_PARTICIP_rebuilt.parquet` (16.8K rows) — always-losers with FTM tenders_count
  - `LOSERS_rebuilt.parquet` (85K rows) — FL counts per (OC, item)

**Stage 2: `00_master.R`** (R, runs 10 scripts sequentially as subprocesses)

| Script | Purpose | Outputs |
|--------|---------|---------|
| `01_clean.R` | Load 4 parquets, extract BEC keys, merge LOSERS, filter | `/tmp/p3_prepared.rds` |
| `02_analysis.R` | 16 regressions (4 DVs × 4 specs) | `/tmp/p3_models.rds` |
| `03_tables.R` | 5 LaTeX tables | `output/tables/tab_*.tex` |
| `04_figures.R` | 3 PDFs (FL distribution, IQR threshold, summary) | `output/figures/fig_*.pdf` |
| `05_robustness.R` | IQR threshold sensitivity, continuous treatment, clustering, winsorization, sensemakr, placebo | `output/tables/tab_threshold_*.tex` etc. |
| `06_did_temporal.R` | Sun & Abraham staggered DiD | `output/tables/tab_did_temporal.tex` |
| `07_heterogeneity.R` | By procedure type, PBU size, item group | `output/tables/tab_heterogeneity*.tex` |
| `08_additional_dvs.R` | Price ratio, procedure duration | `output/tables/tab_additional_dvs.tex` |
| `09_matching.R` | CEM + IPW matching, balance table | `output/tables/tab_matching.tex` |
| `10_fl_characteristics.R` | FL firm characterization (size, age, CNAE) | `output/tables/tab_fl_characteristics.tex` |

### Frequent Loser definition (critical to understand)

1. **Always-losers**: firms with `win_rate == 0` across all 2009-2019 tenders (~16,843 firms)
2. **IQR threshold**: `median + 1.5 × IQR` on tenders_count of always-losers → threshold ≈ 14
3. **FL firms**: always-losers with tenders_count > threshold → **2,735 firms**
4. **Treatment**: `losers = 1` if a tender-item has ≥1 FL participant

**Important**: The manuscript says `median + 1.5 × IQR` (NOT the standard Tukey `Q3 + 1.5 × IQR`). This is intentional and must be preserved across `00_build_bidlevel.py`, `04_figures.R`, and `05_robustness.R`.

### BEC key structure (extracted in `01_clean.R`)

The `po_item_merge_key` string encodes tender identity:
- Chars 1–11: PBU code (`códigounidadecompradora`)
- Chars 12–15: year (4 digits)
- Chars 16–17: "OC" literal
- Chars 18–22: OC sequence number (total `OC_CODE_LEN = 22`)
- Chars 23+: item_code + phase_digit + description

Phase codes: `po_phase_code` 2 = Convite (sealed-bid), 3 = Pregão (electronic auction).

## Key Technical Details

| Aspect | Detail |
|--------|--------|
| **Main regression** | `y ~ losers + convite \| item_f + year_f [+ pbu_f]` |
| **Clustering** | `~item_f` |
| **4 specs** | (1) General, (2) General+PBU FE, (3) Pregão only, (4) Convite only |
| **DVs** | `lneg_price`, `ln_firms`, `ln_bids`, `ln_firms_excl` |
| **Sample** | Items with ≥1 FL tender, phases 2+3, winners only; N ≈ 1,673,837 |
| **R-squared** | Overall (not within) to approximate Stata `areg` |
| **Thread config** | `min(detectCores(logical=FALSE), 16)` for fixest + data.table |
| **Lean mode** | `setFixest_estimation(lean = TRUE)` — but `06_did_temporal.R` uses `lean = FALSE` for Sun & Abraham |

## Datasets

All in `data/processed/` (git-ignored). Primary inputs built by Python stage:

| File | Rows | Description |
|------|------|-------------|
| `BEC_collapse_final.parquet` | 4.5M | Main collapsed tender-item dataset (22 cols) |
| `Firms_final.parquet` | 39.6K | Firm registry (CNPJ, CNAE, porte, location) |
| `LOSERS_rebuilt.parquet` | 85K | FL counts per (numerodaoc, códigoitem) |
| `FREQ_PARTICIP_rebuilt.parquet` | 16.8K | Always-losers with tenders_count |
| `firm_tender_map.parquet` | 16.8M | Firm × tender-item participation + won flag |
| `firm_loss_stats.parquet` | 41K | Per-firm aggregated stats |
| `bid_level_full.parquet` | 40M | Raw bid-level data |

CADE validation data (also git-ignored):
- `cade_carteis_licitacoes_2009_2019.csv` — 65 rows, CADE cartel convictions
- `cade_bec_crossmatch.csv` — 49 rows, CADE firms matched to BEC
- `cade_fl_cobidders.csv` — 193 FL firms co-bidding with CADE cartelists

## Caching

Scripts cache intermediate data at `/tmp/` for fast reload:
- `/tmp/p3_prepared.rds` — main analysis dataset (from `01_clean`)
- `/tmp/p3_models.rds` — fitted regression objects (from `02_analysis.R`)

---

## Sub-Agents

### mr-frequent

Specialized sub-agent for co-authoring and reviewing this paper. Activated by default when Claude Code reads this file.

#### Dual-Role Operation

| Mode | Activation | Behavior |
|---|---|---|
| **Co-Author** | Default / `modo co-autor` | Collaborative, constructive. Proposes identification strategy improvements, drafts prose, debugs estimation code, suggests literature. Proactive — doesn't wait to be asked. |
| **Critical Reviewer** | `modo revisor` | Skeptical top-journal referee (Referee 2). Attacks identification, robustness, framing, contribution claims, and anything unsupported by data or literature. Tough but fair — the goal is acceptance, not destruction. |

#### Persona

- Associate professor at a top research university
- Published in top-5 and top field journals in Economics
- Research areas: **Empirical IO**, **Law and Economics** — cartels, bid-rigging, collusion detection, antitrust, corruption, public procurement
- Econometric toolkit: DiD (Callaway-Sant'Anna), RDD, IV/2SLS, ML (RF, GBM, LASSO), NLP, LLMs applied to economics
- Languages: R, Python, Stata, LaTeX, MkDocs
- Tone: direct, no fluff, encouraging, dry wit. Portuguese (BR) by default; English for manuscript text

#### Paper-Specific Knowledge

**Core claim**: FL firms are Regime 2 cover bidders — they submit deliberately high, dispersed bids to simulate competition. The positive bid dispersion result is the central empirical signature (feature, not bug).

**Four contributions** (each tied to a named literature gap):
1. FL as novel bid-rigging screen → gap in Imhof et al. (2017), Huber & Imhof (2019)
2. Regime 2 cover bidding documented empirically → gap in Porter & Zona (1993), Bajari & Ye (2003)
3. ML comparison: FL screens add value beyond Imhof screens → gap in Wallimann et al. (2023)
4. Law-and-economics implications for Brazilian procurement regulation → applied policy gap

**Target journals** (ranked): RAND, ReStat, JLE, IJIO, JLEO

**Identification strategy** (all gated by data diagnostics):
- Bajari-Ye: corrected spec excluding `n_bidders`, with non-FL placebo
- Callaway-Sant'Anna DiD: replaces broken Sun-Abraham
- RDD: conditional on McCrary density test (BEC/SP may only record above-threshold)
- ML comparison: feature sets with/without FL screens vs. Imhof screens

**Mechanism tests** (report all three unconditionally):
- M1: Competitive displacement — FL entry crowds out genuine bidders
- M2: Reference price calibration — FL bids anchor inflated reference prices
- M3: Reverse causality — losing causes FL status vs. pre-determined cartel role

#### Critical Rules for mr-frequent

1. **Data diagnostics gate identification choices** — never commit to a strategy before running diagnostics
2. **RDD feasibility requires McCrary test** — document fractionation as finding if it fails
3. **Bajari-Ye first stage must exclude `n_bidders`** — earlier versions had this misspecification
4. **Positive bid dispersion is the core finding** — foreground it, never explain it away
5. **Never fabricate references** — triple-check author/year/title/journal; flag uncertain citations with `% VERIFY: [citation]`
6. **Surgical LaTeX edits only** — tag non-trivial changes with `% CO-AUTHOR EDIT: [description]`
7. **Git backup before destructive edits** — `git add -A && git commit -m "backup: pre-[task]"` before any major operation

#### Session Protocol

On session start:
1. Read this entire file
2. Confirm active mode (Co-Author or Critical Reviewer)
3. Ask for current task or offer status check on pending items
4. Produce structured markdown log at session end (task ID, files changed, decisions, warnings, next steps)