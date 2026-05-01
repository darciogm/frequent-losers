# Replication Archive — Paper 3: Loser-Side Concentration as a Low-Cost Bid-Rigging Risk Screen

**Authors:** Darcio Genicolo-Martins, Paulo Furquim de Azevedo (INSPER)
**Manuscript:** `work/v13/paper_v13.pdf`
**Last update:** 2026-05-01

This archive contains all code, raw data references, and intermediate
outputs needed to reproduce every number, figure, and table in the
manuscript. Re-running the pipeline takes approximately 14 minutes on
a consumer-class machine.

## Quick start

```bash
# Full reproduction end-to-end (data → analyses → values.tex → PDF)
bash scripts/00_master_paper.sh

# Fast: only regenerate values.tex + recompile (assumes cached outputs)
bash scripts/00_master_paper.sh --fast

# Verification suite
bash scripts/verify_paper.sh
```

## Hardware requirements

- 12-thread CPU recommended (configured via `PRAGMA threads=12`)
- 16 GB RAM (out-of-core via DuckDB `memory_limit='14GB'`)
- ~5 GB disk for intermediate parquets
- R 4.0+ with packages: `arrow`, `data.table`, `fixest`, `pROC`,
  `MatchIt`, `ranger`, `survival`, `ggplot2`, `duckdb`, `DBI`,
  `rdrobust`, `rddensity`
- TeX Live 2023+ with `elsarticle`, `chicago.bst`

## Pipeline structure

```
00_master_paper.sh                           ← entry point
├── Stage 1: 01_clean.R                      ← rebuild /tmp cache
├── Stage 2: gate diagnostics 36–39          ← γ++ pre-registered gate
├── Stage 3: 40_leakage_audit_d3.R           ← item-level AUC audit
├── Stage 4: 42, 43 (operational + audit)    ← precision@k
├── Stage 5: 41_fix_figures.R                ← regenerate fig subtitles
├── Stage 5b: 44, 45, 46                     ← v8 legacy + falsification
├── Stage 6: 99_make_paper_values.R          ← generate values.tex
├── Stage 7: pdflatex × 3 + bibtex           ← compile paper
└── Stage 8: verify_paper.sh                 ← 15 invariants
```

## Data

All raw inputs are public Brazilian government data:

- **BEC contract awards** (São Paulo state procurement, 2009-2019):
  ~40M bid-level rows. Sources cited in `paper_v13.pdf` Section~3.
- **CADE adjudication records** (`data/processed/cade_*.csv`): public
  bid-rigging cartel decisions 2009-2019.
- **Firm registry** (CNPJ-CNAE-porte): public derivative of receita
  federal data.

Intermediate processed parquet files are in `data/processed/` (git-ignored
due to size). The Python build script `00_build_bidlevel.py` reproduces
them from source CSV (~6 minutes).

## Scripts

### Core analytical pipeline

| Script | Purpose | Output |
|---|---|---|
| `00_master_paper.sh` | Full pipeline orchestration | All below |
| `01_clean.R` | Load 4 parquets, build analysis dataset | `/tmp/p3_prepared.rds` |
| `02_analysis.R` | 16 baseline regressions (4 DVs × 4 specs) | `/tmp/p3_models.rds` |
| `03_tables.R` | LaTeX tables (5) | `output/tables/tab_*.tex` |
| `04_figures.R` | PDFs (3 main figures) | `output/figures/fig_*.pdf` |
| `05_robustness.R` | Threshold + clustering robustness | `output/tables/tab_threshold_*.tex` |
| `06_did_temporal.R` | Sun-Abraham staggered DiD (declared invalid) | `output/tables/tab_did_*.tex` |
| `07_heterogeneity.R` | By procedure type, PBU size, item group | tables |
| `08_additional_dvs.R` | Price ratio, procedure duration | tables |
| `09_matching.R` | CEM + IPW matching | `tab_matching.tex` |
| `10_fl_characteristics.R` | FL firm characterization | `tab_fl_characteristics.tex` |

### v14 disciplinary cleanup (round 2-4)

| Script | Purpose |
|---|---|
| `30_first_time_fl_matching.R` | First-tender FL premium under matching |
| `31_imhof_full_pipeline.R` | Full Imhof–Wallimann (5 features) vs FL |
| `32_matched_heterogeneity.R` | Heterogeneity in matched sample |
| `33_auc_direct_cade.R` | AUC vs 47 direct CADE defendants |
| `34_horse_race_fl_continuous.R` | Horse race FL14 vs continuous |
| `35_unified_mechanism.R` | Network-quadrant heterogeneity |

### v14 gate diagnostics (γ++ pre-registered)

| Script | Diagnostic |
|---|---|
| `36_gate_d1_harmonized.R` | D1: harmonized horse race (PASS) |
| `37_gate_d2_modal_auc.R` | D2: modal-by-modal AUC (FAIL — direction opposite) |
| `38_gate_d3_continuous_only.R` | D3: continuous preserves thesis (PASS) |
| `39_gate_d4_cade_winner_heavy.R` | D4: CADE defendants are winners (PASS) |

### v14 audits and falsification

| Script | Purpose |
|---|---|
| `40_leakage_audit_d3.R` | Item-level AUC anti-leakage audit |
| `41_fix_figures.R` | Regenerate figure subtitles (cosmetic) |
| `42_operational_metrics.R` | Precision/recall/lift @ top-k |
| `43_precision_at_k_audit.R` | Temporal-holdout precision@k audit |
| `44_consolidate_v8_csvs.R` | v7/v8 legacy CSVs → unified CSV |
| `45_legacy_m1m3_perm_welfare.R` | Re-run M1/M2/M3 + dyadic + welfare |
| `46_falsification_pregao_only.R` | Pregão-only falsification |

### Pipeline infrastructure

| Script | Purpose |
|---|---|
| `99_make_paper_values.R` | Generate `values.tex` from canonical CSVs |
| `00_master_paper.sh` | Full pipeline orchestration |
| `verify_paper.sh` | 15-invariant verification suite |

## Manuscript files

```
work/v13/
├── paper_v13.pdf                    ← compiled output
├── paper_v13.tex                    ← root file
├── values.tex                        ← AUTO-GENERATED, 406 macros
├── audit_paper_numbers.md           ← provenance map (every macro → script)
├── references.bib                    ← bibliography
├── REPLICATION_README.md            ← this file
├── cover_letter_jleo.md             ← submission cover letter
├── sec_frontmatter.tex              ← title, abstract, highlights
├── sec_introduction.tex             ← introduction (rewritten)
├── sec_literature.tex
├── sec_institutional.tex
├── sections/sec4_data_fl.tex
├── sections/sec5_empirical_strategy.tex
├── sec_cade.tex
├── sections/sec7_results.tex
├── sec_mechanisms.tex                ← rewritten (drop cartel-signature)
├── sec_robustness.tex                ← rewritten (D2 reframed, leakage audit, falsification)
├── sec_limitations.tex
├── sec_conclusion.tex
├── sec_endmatter.tex
├── sec_appendix.tex                  ← online supplement
└── output/tables/                    ← generated tables (some via scripts)
```

## Numerical claims and provenance

Every numeric claim in the manuscript appears as a `\val<Macro>` LaTeX
command. The full mapping is in `work/v13/audit_paper_numbers.md`,
which lists each macro with its source script and CSV row. Sample:

| Macro | Value | Source |
|---|---|---|
| `\valFL` | $2{,}537$ | `data/processed/FREQ_PARTICIP_rebuilt.parquet` |
| `\valAUCFLfirm` | $0.911$ | `scripts/34_horse_race_fl_continuous.R` |
| `\valAUClogtc` | $0.939$ | `scripts/34_horse_race_fl_continuous.R` |
| `\valAUCdirectCADE` | $0.491$ | `scripts/33_auc_direct_cade.R` |
| `\valAUCImhofFull` | $0.888$ | `scripts/31_imhof_full_pipeline.R` |
| `\valFalPregBin` | $+9.59\%$ | `scripts/46_falsification_pregao_only.R` |
| `\valFalConvBin` | $+3.92\%$ | `scripts/46_falsification_pregao_only.R` |

Re-running any analytical script regenerates its CSV; running
`scripts/99_make_paper_values.R` regenerates `values.tex`; recompiling
the paper updates every number.

## Verification suite

`verify_paper.sh` checks 15 invariants:

- `values.tex` exists and contains expected number of macros
- All required CSV outputs present
- Disciplined sections (intro, abstract, mechanisms, robustness)
  contain no sensitive legacy literals (`2,735` instead of
  `\valFL`, etc.)
- PDF compiled successfully
- No `Undefined` references in compile log
- Provenance audit document present and matches macro count

Each pull request to the replication archive should pass
`verify_paper.sh` before merge.

## Known issues / scope

- **Numbers that diverge between v13 manuscript and v14 reproduction:**
  M3 (reverse causality) coefficient is $+0.0037$ in v14 reproduction
  vs $+0.0021$ reported in earlier drafts; the substantive
  interpretation (positive, significant, much smaller than headline
  by a factor of ~17) is preserved. The dyadic permutation null mean
  is $\sim 783$ under uniform shuffle (v14) vs $3{,}271$ under
  stratified shuffle (v13); the observed value $4{,}603$ rejects the
  null in both designs.
- **v8 legacy proofs** (cover-bidding framework, structural
  estimation) are reproduced from `work/v8/scripts/` and consolidated
  via `scripts/44_consolidate_v8_csvs.R`. The original v8 scripts
  are preserved for reference but not part of the active pipeline.
- **Welfare back-of-envelope** has two reported figures: the v8
  counterfactual welfare (R$74M, R$135M, R$211M from
  `counterfactual_results.csv`) and a v14 conservative back-of-envelope
  (R$410M-R$739M from `welfare_bounds.csv`). The v8 numbers are the
  canonical values reported in the manuscript; the v14 version is
  reported as a sensitivity bound.

## Contact

Corresponding author: Darcio Genicolo-Martins (darciogm1@insper.edu.br).

Replication assistance / clarifications: please open an issue on the
public archive (link to be provided upon acceptance).
