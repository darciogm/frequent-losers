# v6-jpube reproducibility & macro-linkage protocol

This version refactors v5-jpube to make every numerical claim in the
manuscript **automatically refresh** when the pipeline is re-run. The contract
is one-way: change the data or the scripts, recompile, and the prose updates.

## TL;DR — full rebuild

```bash
cd /home/darciogm1/projetos/bitter-pills/paper2-me-epp/v6-jpube
Rscript scripts/00_master.R --keep-going
cd manuscript
pdflatex paper_v6 && bibtex paper_v6 && pdflatex paper_v6 && pdflatex paper_v6
```

Outputs land in `output/tables/*.tex`, `output/figures/*.pdf`,
`output/values.tex`, and `manuscript/paper_v6.pdf`.

## Macro architecture

- `scripts/utils_v6.R` defines `write_macro()`, `write_macro_pct()`,
  `write_macro_int()`, `write_macro_dec()`, `write_macro_money()`, and
  `reset_macros()`. Every numerical claim should pass through one of these.
- `00_master.R` calls `reset_macros()` once at start, then runs each numbered
  script as a separate `Rscript` subprocess (memory hygiene on 21 GiB RAM).
- `98_emit_macros.R` runs near the end of the pipeline and reads every
  produced parquet to populate `output/values.tex` with the full headline
  dictionary (105+ macros). It is the single source of truth for the prose.
- `paper_v6.tex` preamble loads the dictionary via:

  ```latex
  \InputIfFileExists{../output/values.tex}{}{%
    \PackageWarning{paper_v6}{values.tex not found — run scripts/00_master.R}}
  ```

  Missing macros are tolerated via `\providecommand{}{}` defaults — LaTeX emits
  a warning rather than aborting.

## Pipeline DAG

| # | Script | Output | Macros emitted |
|---|---|---|---|
| 32 | `historical_sme.R` | `bid_level_sme_g65.parquet`, `g65_proxy_audit.parquet` | `nBidsTotal` |
| 33 | `pharma_flag.R` | `bid_level_sme_pharma_g65.parquet`, `tab_v3_pharma_counts.tex` | — |
| 34 | `s1_descriptives.R` | `tab_v3_s1_handoff.tex` | (`nObsAuctions`, `nDistinctAuctions` static) |
| 35 | `pregao_dropouts.R` | `pregao_dropouts.parquet` | `nFirmAuctions` |
| 36 | `pregao_fc_dropout.R` | `pregao_fc.parquet` | — |
| 37 | `pregao_ht_refined.R` | `pregao_ht_bounds.parquet`, `tab_v3_pregao_ht_refined.tex` | — |
| 38 | `cross_modality.R` | `convite_fc.parquet`, `tab_v3_cross_modality.tex` | — |
| 39 | `primitive_invariance.R` | `tab_v3_primitive_invariance.tex` | — |
| 40 | `uh_variance.R` | `uh_variance.parquet`, `tab_v3_uh_variance.tex` | — |
| 41 | `uh_clean_bids.R` | `bids_uh_cleaned.parquet`, `tab_v3_uh_vs_raw.tex` | — |
| 42 | `uh_rerun_fc.R` | `pregao_fc_uh.parquet`, `convite_fc_uh.parquet` | — |
| 43 | `uh_invariance_update.R` | `tab_v3_uh_invariance.tex` | — |
| 44 | `entry_pool.R` | `entry_rates.parquet`, `tab_v3_entry_rates.tex` | `entryN*` |
| 45 | `bne_simulation.R` | **`bne_decomp.parquet`**, `tab_v3_bne_decomp.tex`, `fig_v3_bne_prices.pdf` | `bneEffectTotal*`, `bneShareIntens*`, `bneNsme*`, `bneMeanS*` |
| 46 | `decomp_compare.R` | `decomp_grid.parquet`, `tab_v3_decomp_grid.tex`, `fig_v3_decomposition.pdf` | `gridShareIntens*`, `latentShockRatio*`, `latentShockTimes*` |
| 47 | `entry_cost.R` | `tab_v3_entry_cost.tex`, `fig_v3_entry_insurance.pdf` | — |
| 48 | `turnbull_fc.R` | `pregao_fc_turnbull.parquet`, `tab_v3_turnbull_fc.tex` | `turnbullShareNp/Ph` |
| 49 | `sensitivity_fc.R` | `tab_v3_sensitivity_fc.tex` | — |
| 50 | `bandwidth_grid.R` | `tab_v3_bandwidth_grid.tex` | — |
| 51 | `bootstrap_ci.R` (~2 min) | `bootstrap_ci.parquet`, `tab_v3_bootstrap_ci.tex` | — |
| 52 | `filter_sensitivity.R` | `tab_v3_filter_sensitivity.tex` | — |
| 53 | `apv.R` | `tab_v3_apv.tex` | — |
| 54 | `window_sensitivity.R` | `tab_v3_window_sensitivity.tex` | — |
| 55 | `welfare.R` | **`welfare_decomp.parquet`**, `tab_v3_welfare.tex` | `welfMeanPSone*`, `welfTotalLossLthirty*`, `welfLossPctLthirty*`, … |
| 56 | `welfare_bootstrap.R` (~30 s) | `welfare_bootstrap.parquet`, `tab_v3_welfare_ci.tex`, `fig_v3_welfare_forest.pdf` | `welfLossPctLo/Hi*` |
| 57 | `strict_invariance.R` | `strict_invariance.parquet`, `tab_v3_strict_invariance.tex` | `siDeltaTotal*`, `siWelfWeight*`, `strictShareNp/Ph` |
| 57 | `welfare_adherence_sensitivity.R` | `tab_welfare_adherence_sensitivity.tex` | — |
| 58 | `collusion_screen.R` (~slow) | `tab_collusion_screen.tex` | — |
| 58 | `figures.R` | several headline figures | — |
| 59 | `collusion_screen_schurter.R` | — | — |
| 59 | `gelbach_waterfall.R` | `fig_v3_gelbach_waterfall.pdf` | — |
| 60 | `collusion_screen_bajari_ye.R` | `tab_collusion_screen_bajariye.tex` | — |
| 60 | `distributional_incidence.R` | `tab_v3_incidence.tex` | — |
| 61 | `collusion_screen_pair_classcond.R` | `tab_collusion_screen_pair_classcond.tex` | — |
| 61 | `optimal_preference.R` | `tab_v3_preference_grid.tex`, `fig_v3_optimal_preference.pdf` | `optPrefThreshold` |
| 62 | `buyer_heterogeneity.R` | `tab_v3_buyer_het.tex` | — |
| 62 | `maskin_riley_fpsb_bound.R` | `tab_maskin_riley_bound.tex` | — |
| 63 | `gelbach_enriched.R` | `tab_v3_gelbach_enriched.tex` | — |
| 70 | `phased_adoption.R` | `tab_phased_adoption.tex` | — |
| 98 | **`emit_macros.R`** | `output/values.tex` | (consolidator: 100+ macros) |
| 99 | `internal_robustness.R` | sanity checks | — |

## Conventions

1. **Letters-only macro names.** LaTeX's `\newcommand` only accepts letters in
   command names. For numeric suffixes (e.g., $\lambda \in \{0.15, 0.20, 0.30,
   0.40, 0.45\}$) we use word-tags: `welfLossPctLfifteenNp`, `Ltwenty`,
   `Lthirty`, `Lforty`, `Lfortyfive`. Never embed digits in macro names.
2. **`\providecommand` + `\renewcommand` pair.** Every emitted macro is wrapped
   so the manuscript can be compiled even if a script failed: missing macros
   render blank and emit a warning rather than aborting.
3. **Idempotent within a run.** `reset_macros()` truncates `values.tex` at the
   top of `00_master.R`. Subsequent re-emits during the same run accumulate.
4. **Static fall-backs.** A handful of macros are still static literals in
   `98_emit_macros.R` — clearly marked. They are: DiD coefficients (parent
   reduced-form pipeline lives in `../scripts/02_analysis.R`, not yet wired),
   welfare weights $w^{\text{SME}}_\star$ in main spec, furosemide vignette
   numbers, and "10 percent" preference threshold. Future work: route them
   through producer scripts.

## Coverage status (manuscript sections)

- ✅ **Abstract** — fully macro-linked.
- ✅ **00_introduction.tex** — fully macro-linked (DiD numbers, welfare,
  decomposition, Table 1 headline preview).
- ⏳ **01_institutional_background.tex** — hardcoded sample sizes, pending.
- ⏳ **02_data.tex** — hardcoded percentages, pending.
- ⏳ **03_model.tex** — calibration constants, pending.
- ⏳ **04_identification.tex** — KS p-values, pending.
- ⏳ **05_results.tex** — hardcoded $p_{S_3}-p_{S_1}$ and shares, pending.
- ⏳ **06_welfare.tex** — hardcoded $\lambda$ grid, pending.
- ⏳ **07_robustness.tex** — bootstrap CI bounds, pending.
- ⏳ **08_discussion.tex** — welfare weights, pending.
- ✅ **09_conclusion.tex** — no numerals.
- ⏳ **10_tables.tex / 11_appendix.tex / 12_appendix_did.tex** — pending.

The discipline going forward: when editing prose, read from `output/values.tex`
(or browse `\providecommand` definitions); when editing scripts, add a
`write_macro()` call beside any `cat()` of a value used downstream.

## Seed regime (`scripts/seeds.R`)

Single source of truth for RNG seeds across the pipeline. `utils_v6.R` sources
`seeds.R` automatically, so every script that includes `source(utils_v6.R)`
gets `MASTER_SEED`, `seed_for_script(NN)`, and `seed_for_iter(NN, b)` for
free.

**Contract:**

```
MASTER_SEED <- 20260423L
seed_for_script(NN) = MASTER_SEED + NN
seed_for_iter(NN, b) = MASTER_SEED + NN*1000 + b
```

The script-number prefix (NN) is parsed from the filename: `45_bne_simulation.R`
takes seed `seed_for_script(45) = 20260468`. Bootstrap loops use
`seed_for_iter(NN, b)` so each (script, iter) pair has a globally unique seed
auditable in isolation.

**Coverage** (17 stochastic scripts, all routed through the helper):

| Script | Seed form | Resolves to |
|---|---|---|
| `39_primitive_invariance.R` | `seed_for_script(39)` | 20260462 |
| `45_bne_simulation.R` | `seed_for_script(45)` | 20260468 |
| `46_decomp_compare.R` | `seed_for_script(46)` ×2 | 20260469 |
| `47_entry_cost.R` | `seed_for_script(47)` | 20260470 |
| `49_sensitivity_fc.R` | `seed_for_script(49)` ×2 | 20260472 |
| `51_bootstrap_ci.R` | `seed_for_iter(51, bs_idx)` | 20260474 + b·1000 |
| `52_filter_sensitivity.R` | `seed_for_script(52)` | 20260475 |
| `53_apv.R` | `seed_for_script(53)` | 20260476 |
| `54_window_sensitivity.R` | `seed_for_script(54)` | 20260477 |
| `55_welfare.R` | `seed_for_script(55)` | 20260478 |
| `56_welfare_bootstrap.R` | `seed_for_iter(56, bs_idx)` | 20260479 + b·1000 |
| `57_strict_invariance.R` | `seed_for_script(57)` ×2 | 20260480 |
| `58_collusion_screen.R` | `SEED <- seed_for_script(58)` | 20260481 |
| `59_collusion_screen_schurter.R` | `seed_for_script(59)` | 20260482 |
| `60_collusion_screen_bajari_ye.R` | `seed_for_script(60)` | 20260483 |
| `61_collusion_screen_pair_classcond.R` | `seed_for_script(61)` | 20260484 |
| `61_optimal_preference.R` | `seed_for_script(61)` | 20260484 |

**To rotate the seed regime** (sensitivity check on Monte Carlo noise): change
`MASTER_SEED` in `scripts/seeds.R` and re-run. All 17 scripts shift in lockstep.

**To audit a single Monte Carlo result**: identify the producing script (e.g.,
`55_welfare.R`), compute `seed_for_script(55) = 20260478`, set in a fresh R
session, and the simulation is bit-reproducible.

## Reruns and reproducibility caveats

- Several scripts use Monte Carlo (`set.seed(20260423)` in 45/56). On a clean
  rebuild against the same input parquets, results are bit-identical.
- BUT: a fresh build that includes scripts 32–44 may produce slightly different
  intermediate parquets (e.g., the auction-level UH shrinkage in 41 is fit
  numerically; tiny differences propagate). This is normal and expected —
  the macro layer handles it transparently.
- If you upgrade R or DuckDB, expect ε-level drift in 4th-decimal places.

## Restoring the v3-baseline of any script

If a v6 script is suspected of corruption, `v3-structural/scripts/` holds the
clean Apr-23 copy. After restoring, re-run:

```bash
sed -i 's|paper2-me-epp/v3-structural/scripts/utils_v3.R|paper2-me-epp/v6-jpube/scripts/utils_v6.R|g' scripts/<file>.R
sed -i 's|paper2-me-epp/v5-jpube|paper2-me-epp/v6-jpube|g' scripts/<file>.R
```

The shim `path_v3 <- path_v6` in `utils_v6.R` keeps any leftover `path_v3()`
calls writing into v6 instead of v3.
