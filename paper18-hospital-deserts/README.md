# Who Is Exposed?

**Flow-Based Exposure to Hospital Closures and the Care-Substitution Channel**

Darcio Genicolo-Martins (Insper) · 2026

[`01_manuscript/main.pdf`](01_manuscript/main.pdf) · 37 pages · 8 sections + 8 appendix placeholders

---

## What this paper does

We propose a methodological framework that uses realized patient-flow
shares to identify exposure to hospital closures, instead of relying on
geographic proximity alone. Applied to $60$ exogenous closures in Brazil
(SUS, $2010$--$2024$), the implemented share-based exposure rule recovers
a **care-substitution effect** in specialized-hospital closures
(predominantly psychiatric, under the Lei~$10.216$/$2001$ reform):
travel burden falls after closure because patients no longer commute for
specialized care, and preventable hospitalizations (ICSAP) rise with a
lag. The stronger claim that the embedding itself outperforms kilometer
or travel-time baselines in cross-sectional prediction does not survive
the current horse races.

The framework integrates four components: (i) a node2vec embedding of
the bipartite municipality--hospital graph; (ii) a share-based exposure
rule (E1) with a kilometer-based alternative exposure rule (E2); (iii) a structured
NLP classification of declared closure motives (Receita Federal CNPJ
status + retrieved web sources, processed by a zero-shot LLM); and
(iv) staggered Sun-Abraham event-study estimation paired with Athey-Wager
causal-forest heterogeneity attribution.

---

## Quick start

```bash
# 1. Create the analysis environment
conda env create -f environment.yml
conda activate paper18

# 2. (Pip alternative if you prefer venv)
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# 3. (Optional) Set your Anthropic API key for the NLP step
export ANTHROPIC_API_KEY=sk-ant-...

# 4. Run the full pipeline (skips outputs that already exist)
./run_pipeline.sh

# 5. Re-compile the manuscript
cd 01_manuscript
pdflatex main && bibtex main && pdflatex main && pdflatex main
```

`run_pipeline.sh` accepts `--from <id>` and `--to <id>` flags to start
or stop at a specific step. Each script in `03_analysis/` accepts
`--force` to bypass output-detection caching.

---

## Repository layout

```
paper18-hospital-deserts/
├── 01_manuscript/                 LaTeX sources
│   ├── main.tex                   Master file
│   ├── introduction.tex           §1 (5 movements)
│   ├── setting.tex                §2 (SUS + Reforma Psiq)
│   ├── data.tex                   §3 (5 sub-sections)
│   ├── method.tex                 §4 (6 sub-sections, framework)
│   ├── results.tex                §5 (6 sub-sections, hybrid)
│   ├── robustness.tex             §6 (7 specs + summary)
│   ├── discussion.tex             §7 (5 sub-sections)
│   ├── conclusion.tex             §8
│   ├── appendix.tex               Apêndice A-H placeholders
│   ├── references.bib             31 refs verified
│   └── tables/                    .tex tables (auto-generated)
├── 02_data/
│   ├── raw/                       DATASUS (.dbc → .parquet) + IBGE
│   ├── intermediate/              Pipeline outputs (parquet, sqlite)
│   └── final/                     (reserved)
├── 03_analysis/                   Numbered scripts (00 → 36)
├── 04_figures/                    PDFs ready for inclusion
├── 04_logs/                       Per-script execution logs + JSON metrics
├── 05_references/                 Reference PDFs (offline copies)
├── 06_scratch/                    Throwaway exploration
├── notes/                         Decision logs, audits, outline
├── environment.yml                conda env (Python + R)
├── requirements.txt               pip-only alternative
├── run_pipeline.sh                Pipeline orchestrator (00 → 36)
├── README.md                      (this file)
└── CLAUDE.md                      Project conventions for AI-assisted work
```

---

## Pipeline order

The `03_analysis/` scripts are numbered to reflect dependency order; the
orchestrator `run_pipeline.sh` runs them in this sequence. Major
conceptual blocks:

| Block | Scripts | Purpose |
|---|---|---|
| **Ingest** | `00*`, `01-05` | DATASUS .dbc parse, IBGE pop/GDP, CNES habilitation, hospital universe, centroids |
| **Embedding** | `06`, `06b` | node2vec on bipartite + projected M-M graph |
| **Cross-section diagnostic** | `07`, `07b`, `09`, `15` | $\Delta R^2$ over km baseline (11 nulls) |
| **Visualization (legacy)** | `08`, `11-14`, `16` | Divergence map, t-SNE, regional tables |
| **Cause-specific & alt outcomes** | `17`, `17b`, `17c`, `17d` | $\Delta R^2$ across 11 outcomes |
| **Closure identification** | `20`, `21`, `22`, `23`, `24a` | F5 filter, E1/E2 exposures, travel burden, ICSAP, staggered panel |
| **Event-study (pilot)** | `24b`, `25` | First-pass Sun-Abraham + heterogeneity |
| **NLP exogeneity (R1)** | `26`, `27`, `28`, `28b`, `28d` | Metadata, CNPJ lookup, Haiku v1, Sonnet v2 with web |
| **Final estimation** | `29`, `30`, `31` | Build 5 panels (F5/F6/admin/falência/fiscal), Sun-Abraham hybrid, causal forest |
| **Counterfactual perturbation** | `32b`, `33` | Re-train embedding without each closing hospital |
| **Robustness battery** | `34` | 18 specs (alt thresholds/estimators/samples) |
| **Final figures** | `35`, `36` | SA vs BJS comparison, cross-section null forest |

Outputs in `02_data/intermediate/`, `04_figures/`, `04_logs/`, and
`01_manuscript/tables/` are all under git for replication; raw DATASUS
in `02_data/raw/` is git-ignored (re-downloadable via the `00*` scripts).

---

## Caches and external services

The pipeline calls two external services in the NLP block; both are
cached so re-runs do not re-query.

* **BrasilAPI** (Receita Federal CNPJ lookup, public free endpoint).
  Cached in `02_data/intermediate/cnpj_cache.sqlite` (~$\sim 65$ entries
  for our $90$ closures, plus valid-CNPJ misses).
* **Anthropic Claude API** (LLM classifier). Cached in
  `02_data/intermediate/llm_classify_cache.sqlite` (Haiku v1) and
  `llm_classify_cache_v2.sqlite` (Sonnet v2 with web snippets). Total
  spend for the published classifications was ~\$0.85.

To replicate the paper's classifications without re-querying the
services, ship these caches with the repository (they are small,
$\le 2$~MB total) and skip steps `27`, `28`, `28d` if the caches are
already populated.

---

## Hardware

The pipeline was developed on:

* WSL2 Ubuntu, kernel `6.6.87.2-microsoft-standard`, on Intel i7-1260P
  ($14$ logical cores in WSL, $21$~GB RAM, no GPU).
* Total wall-clock for a cold run from `00` to `36`: **$\sim 35$ min**
  on this machine, dominated by SIH-RD ingest (~$30$~min for the raw
  parse) and node2vec training (~$60$~s per closure for the $32$b
  perturbation step, $61$ closures).
* Re-run with caches populated: $\sim 8$~min.

DuckDB is the default engine for parquet I/O across the pipeline,
configured with `PRAGMA threads=12 memory_limit='14GB'
temp_directory='/tmp/duckdb_paper18'` (set in each script).

---

## Citing this work

The working paper is the canonical citation:

> Genicolo-Martins, D. (2026). Who Is Exposed? Patient-Flow Embeddings,
> Hospital Closures, and the Care-Substitution Channel. Working paper,
> Insper.

`https://github.com/darciogm/bitter-pills/tree/main/paper18-hospital-deserts`

---

## Authorship and policy

Sole-authored. Comments welcome to `darcio.g.martins@gmail.com`.

This repository follows the conventions in `CLAUDE.md` (Brazilian
Portuguese in code comments, no AI-co-author markers in commits, DuckDB
defaults for parquet, $16$~GB RAM budget per workload, $12$ internal
threads).
