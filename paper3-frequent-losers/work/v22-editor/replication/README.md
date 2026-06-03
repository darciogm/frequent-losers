# Replication Package — *Cheap Signals, Costly Proof: The Reach and Limits of Award-Layer Screening in Cartel Enforcement*

**Authors:** Darcio Genicolo-Martins & Paulo Furquim de Azevedo (INSPER)
**Journal:** *Journal of Law, Economics, & Organization* (JLEO) — R&R submission, v22.
**Contact:** Darcio Genicolo-Martins, INSPER — <darcio.g.martins@gmail.com>

---

## 1. Package overview

This package documents how the empirical results in the paper and its online
appendix are produced. It covers:

- the analysis pipeline (Python ETL → R analysis → table/figure assembly →
  LaTeX build);
- a script-by-output map for **main Tables 1–6** and **Figures 1–3**, the
  appendix tables, and the online-supplement diagnostics;
- data-availability and confidentiality statements (see
  [`DATA_CONFIDENTIALITY.md`](DATA_CONFIDENTIALITY.md)); and
- the machine-readable manifests
  ([`OUTPUTS_MAP.csv`](OUTPUTS_MAP.csv), [`MANIFEST.csv`](MANIFEST.csv)) and
  the dependency-ordered run sequence ([`SCRIPT_ORDER.md`](SCRIPT_ORDER.md)).

The single source of truth for the manuscript is
`work/v22-editor/submission_clean/`. Canonical analysis outputs live under
`paper3-frequent-losers/output/<module>/`; revision deliverables (revision
tables/figures, logs, diagnostics, cache) live under
`work/v22-editor/outputs/`. All paths below are relative to the repository root
`paper3-frequent-losers/` unless prefixed with `work/v22-editor/`.

> **Status note.** This is an honest, in-progress R&R replication package. Some
> outputs are **blocked** and are disclosed as such (see §8 Known limitations);
> we do not claim results we cannot regenerate.

---

## 2. Software requirements

- **R 4.5** (4.5.2 used). Packages: `data.table`, `fixest`, `ranger`, `pROC`,
  `survival`, `MatchIt`, `DBI`, `duckdb`, `ggplot2`. Utility helpers under
  `work/v22-editor/scripts/utils/` are base-R / dependency-free.
- **Python 3** (ETL only). Packages: `pandas`, `pyarrow`, `duckdb`.
- **LaTeX** — `elsarticle` document class with `natbib` (**bibtex**, not biber).
- **OS / hardware used:** Linux (WSL2), Intel i7-1260P, 21 GiB RAM, no GPU.

### Environment setup

```r
# R packages
install.packages(c("data.table","fixest","ranger","pROC","survival",
                   "MatchIt","DBI","duckdb","ggplot2"))
```

```bash
# Python packages
pip install pandas pyarrow duckdb
```

**Machine caps (house rule, honored by heavy scripts):** DuckDB
`PRAGMA threads=12`, `memory_limit='14GB'`, spill to `/tmp/duckdb_spill`;
`setDTthreads(12)`; keep `n_workers × peak_per_worker ≤ 16 GiB`.

---

## 3. Data availability & confidentiality (summary)

Full statement in [`DATA_CONFIDENTIALITY.md`](DATA_CONFIDENTIALITY.md). In short:

- **BEC procurement microdata** (LANCES bid-level, firm registry; State of São
  Paulo procurement platform) are **administrative data and are NOT freely
  public**. The raw `.dta`/parquet files **cannot be redistributed** in this
  package.
- **CADE adjudication data** are **public rulings** (gov.br/cade); the curated
  case file `cade_carteis_licitacoes_2009_2019.csv` is derived from those public
  rulings.
- The **193-cobidder label file** `data/processed/cade_fl_cobidders.csv` has **no
  on-disk builder** (blocker **B3**). We disclose this. The reproducible
  alternative is the transparent label funnel in `scripts/79_label_funnel.R`
  (plus `work/v22-editor/scripts/analysis/01_label_funnel_reconciliation.R`),
  which rebuilds the cobidder set from public CADE cases + firm participation.
- **Derived / anonymized firm-level frames** (anonymous `firm_id`, no raw CNPJ)
  **may be posted**.
- The authors will **cooperate with legitimate replication requests** (e.g.
  supervised access or anonymized derived frames), subject to the data-provider
  terms governing the BEC microdata.

---

## 4. Reproducing the main tables and figures

Main tables are **inline** in the manuscript (no `\input`); the values are
produced by the scripts below and the rendered/CSV artifacts are kept under
`work/v22-editor/outputs/tables/main/`. The three `\includegraphics` figures are
under `work/v22-editor/submission_clean/output/figures/`. See
[`OUTPUTS_MAP.csv`](OUTPUTS_MAP.csv) for exact paths.

| Manuscript object | Content | Generating script(s) | Artifact (under `work/v22-editor/outputs/`) |
|---|---|---|---|
| **Table 1** | Unit-of-analysis / populations registry | hand-built from `00_REPO_AUDIT §C` + `scripts/01_clean.R` (documentation) | inline |
| **Table 2** | Label funnel & sample reconciliation | `scripts/79_label_funnel.R` → `scripts/analysis/01_label_funnel_reconciliation.R` | `tables/main/table_A_label_funnel.{csv,tex}` |
| **Table 3** | Opportunity-adjusted validation | `scripts/76_exposure_adjusted_audit.R` → `scripts/analysis/02_opportunity_adjusted_validation.R` | `tables/main/table_C_opportunity_adjusted_validation.{csv,tex}` |
| **Table 4** | Timing & leave-one-case-out / dominance | `scripts/53_strict_train_period_threshold.R`, `scripts/77_reverse_causality_timing.R` → `scripts/analysis/03_timing_case_holdout_validation.R`, `04_case_holdout_dominance.R` | `tables/main/table_B_case_timing_and_benchmark_use.{csv,tex}`, `table_H_case_dominance_validation.{csv,tex}` |
| **Table 5** | Bid-layer benchmark (Imhof) | `scripts/31_imhof_full_pipeline.R` (+ `49_imhof_incremental_value.R`) → `scripts/analysis/09_bid_benchmark_validation.R` | `tables/main/table_Q_bid_layer_performance.{csv,tex}` |
| **Table 6** | Cost–recall frontier | `scripts/analysis/10_cost_recall_frontier.R` (uses `utils/cost_frontier.R`) | `tables/main/table_6_cost_recall_frontier.{csv,tex}` |
| **Figure 1** | Data-coarsening / layers diagram | `submission_clean/make_submission_figures.R` (+ `scripts/58_fig_data_coarsening.R`) | `submission_clean/output/figures/fig_data_coarsening.pdf` |
| **Figure 2** | Observed-vs-expected defendant contact by bin | `scripts/analysis/02_opportunity_adjusted_validation.R` | `submission_clean/output/figures/fig_observed_vs_expected_contact_bins.pdf` |
| **Figure 3** | Cost–recall frontier | `scripts/analysis/10_cost_recall_frontier.R` | `submission_clean/output/figures/fig_3_cost_recall_frontier.pdf` |

> The manuscript embeds exactly three figures via `\includegraphics`:
> `fig_data_coarsening`, `fig_observed_vs_expected_contact_bins`,
> `fig_3_cost_recall_frontier`. Other PDFs under `output/figures/` and
> `outputs/figures/` are appendix / online-supplement figures.

---

## 5. Reproducing the appendix tables

Appendix diagnostics are produced by the same revision scripts and land under
`work/v22-editor/outputs/tables/appendix/` and `outputs/figures/appendix/`:

| Appendix block | Content | Script(s) | Key artifacts |
|---|---|---|---|
| **App D** — validation audits | opportunity-cell construction, observed/expected bins, permutation, strict timing, leave-one-case-out, clustered-RI | `76`, `25_sham_fl_permutation.R`, `53`, `40_leakage_audit_d3.R` → `analysis/02,03,04` | `table_D_*`, `fig_clustered_randomization_inference.pdf` |
| **App H** — economic profile | standardized differences, monotonicity bins, placebo thresholds, negative controls | `scripts/analysis/05_section5_profile_monotonicity.R`, `06_section5_robustness.R` | `table_E_*`, `table_L_*`, `fig_threshold_bunching_T14.pdf` |
| **App I** — bid benchmark | bid-feature dictionary, missingness, model calibration, fold/LOCO audit | `31`, `49` → `analysis/07_bid_feature_audit.R`, `08_bid_benchmark_reproduction.R`, `09_bid_benchmark_validation.R` | `table_F_*`, `table_O/P/R/S_*`, `fig_bid_model_calibration.pdf` |
| **App B** — survival / hazard | discrete-time hazard, Cox, exit-definition sensitivity | `scripts/analysis/11_survival_hazard_frequent_losers.R` (uses `survival`) | `table_B_*`, `fig_B_survival_curves_frequent_losers.pdf` |
| **App E/G** — price scope, cost denominators | price-scope segment betas, cost-denominator definitions, operating points | `59_sign_reversal_decomp.R`, `61_selection_mechanism_test.R`, `62_within_cell_mechanism_test.R`, `78_bidder_count_decomposition.R`; `analysis/10` | `table_G_*` |

---

## 6. Reproducing the online-supplement diagnostics

The full diagnostic battery (full permutation draws, threshold sweeps, feature
dictionary, calibration deciles, full cost grid, survival sensitivity, scanner
logs) is indexed under `work/v22-editor/online_supplement/` (nine directories +
`S_D`/`S_H`/`S_I` index files + `MANIFEST.csv`). The CSV/figure artifacts they
point to live under `work/v22-editor/outputs/diagnostics/`,
`outputs/tables/{main,appendix}/`, `outputs/figures/{main,appendix}/`, and
`outputs/cache/`. See `work/v22-editor/online_supplement/README.md` and its
`MANIFEST.csv`.

---

## 7. Runtime categories & seeds

**Runtime (indicative, on the reference machine):**

- **Quick (< 1 min):** scanners, registry builders, documentation tables
  (`scripts/build/make_registries.R`, claims/number/reference scanners).
- **Moderate (1–10 min):** `scripts/analysis/01–09` and `11`; per-section
  table/figure assembly.
- **Long (> 10 min):** `scripts/analysis/04` (clustered randomization-inference),
  random-forest reruns (`31_imhof_full_pipeline.R`, bid-benchmark validation),
  the full `00_master.R` core pipeline (~8 min) and the Python ETL
  (`00_build_bidlevel.py`, ~6 min).

**Random seeds (deterministic resampling):** `20260430`, `20260501`, `20260530`,
`20260602`, `20260603`. Scripts with deterministic counts only (e.g. core label
counts in `79`, `53`, `78`) require no seed.

---

## 8. Known limitations (disclosed)

- **B3 — absent label builder.** `cade_fl_cobidders.csv` (the 193-cobidder file)
  and `cade_bec_crossmatch.csv` have **no builder on disk**. The reproducible
  alternative is `scripts/79_label_funnel.R` (transparent 12→41→341 funnel;
  reproduces the conservative 208≈210 / 107≈108 sets but **not** the legacy 193).
- **Sequential strict-timing blocked.** Conduct-onset dates are unavailable (CADE
  records judgment dates only, 9/12 dated); sequential strict-timing is blocked,
  so the timing test is reported as a **FAIL / observational-equivalence**
  result, disclosed in the text, not papered over.
- **NOT_OBSERVED cost denominators.** Parts of the cost–recall frontier use
  denominators that are not directly observed (e.g. full-observability analyst
  cost); these cells are labeled as illustrative and treated as such.
- **BEC microdata not redistributable** (see §3 and `DATA_CONFIDENTIALITY.md`).

---

## 9. Contact

Darcio Genicolo-Martins — INSPER — <darcio.g.martins@gmail.com>.
The authors will assist with legitimate replication requests subject to the data
provider's terms.
