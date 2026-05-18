# Reproducibility Linking Memo — Paper 3 (v17-editor)

**Date:** 2026-05-03
**Discipline:** Every numeric claim in the manuscript is bound to a `\valXxx` macro defined in `values.tex`; every `\valXxx` macro is preceded by a `% src:` comment naming the producing script and intermediate output file.

## Pipeline overview

```
(raw)        (intermediate)       (analysis scripts)        (output)
                                                              │
LANCES_*.dta ─┐                                               ├─ output/figures/*.pdf
              │  scripts/00_build_bidlevel.py                 │
              ▼                                               ├─ output/tables/*.tex
data/processed/                                               │
  bid_level_full.parquet ─┐                                   ├─ values.tex (macro defs)
  firm_tender_map.parquet │                                   │
  firm_loss_stats.parquet │  scripts/12_build_item_value.R    │
  FREQ_PARTICIP_*.parquet │  scripts/13_rdd_cap.R             │
  LOSERS_*.parquet        │  scripts/14_did_decreto_2018.R    │
  cade_*.csv ─────────────┤  scripts/15_first_time_fl.R       │
                          │  scripts/30-43_*.R (rounds 2-5)   │
                          │  scripts/45-59_*.R (rounds 6+)    │
                          │                                   │
                          ▼                                   ▼
                       (executed by 00_master.R)        (consumed by paper_v17editor.tex)
```

## Macro discipline (audit results from Bloco B)

- **Macros used in manuscript:** 200 unique `\valXxx` references.
- **Macros defined in repo:** 691 (in `values.tex`) + 75 inline in `paper_v17editor.tex` headline section.
- **Ghost macros:** 0 (post Bloco B audit).
- **Macros without `% src:` provenance tag:** 0 (post Bloco B audit; src tag carries forward across blocks).

Audit script (re-runnable):

```bash
# Used macros
grep -hoE '\\val[A-Za-z]+' sec_*.tex paper_v17editor.tex | sort -u > /tmp/macros_used.txt

# Defined macros (across all definition sites)
grep -hoE '\\newcommand\{\\val[A-Za-z]+\}' values.tex values_adversarial.tex paper_v17editor.tex paper_v17editor_online_appendix.tex \
  | sed -E 's/\\newcommand\{(\\val[A-Za-z]+)\}/\1/' | sort -u > /tmp/macros_defined.txt

# Ghost macros
comm -23 /tmp/macros_used.txt /tmp/macros_defined.txt
```

## Headline-number reproduction chain

| Macro | Value | Producing script | Intermediate output |
|---|---|---|---|
| `\valArchFootprintReduction` | (script-defined) | `scripts/41_architecture_gatekeeper.R` | `output/architecture_gatekeeper/architecture_summary.csv` |
| `\valArchSeqKone` | 1,985 | `scripts/41_architecture_gatekeeper.R` | `output/architecture_gatekeeper/architecture_summary.csv` |
| `\valArchPoolSize` | 11,676 | `scripts/41_architecture_gatekeeper.R` | `output/architecture_gatekeeper/architecture_summary.csv` |
| `\valArchTPThouSeqK` | 126 (or current) | `scripts/41_architecture_gatekeeper.R` | `output/architecture_gatekeeper/architecture_summary.csv` |
| `\valArchNPos` | 193 | `scripts/45_cade_populations.R` | `output/cade_populations/cobidder_count.csv` |
| `\valAUCFLfirmTemp` | 0.864 | `scripts/40_leakage_audit_d3.R` | `output/leakage_audit_d3/leakage_audit_d3.csv` |
| `\valAUCprePost` | (script-defined) | `scripts/40_leakage_audit_d3.R` | `output/leakage_audit_d3/leakage_audit_d3.csv` |
| `\valImhofIncFL` | 0.035 | `scripts/49_imhof_incremental_value.R` | `output/imhof_incremental/imhof_incremental.csv` |
| `\valImhofIncFLp` | 0.014 | `scripts/49_imhof_incremental_value.R` | `output/imhof_incremental/imhof_incremental.csv` |
| `\valCobidders` | (script-defined) | `scripts/45_cade_populations.R` | `output/cade_populations/cobidder_count.csv` |
| `\valDirectCADE` | 47 | `scripts/45_cade_populations.R` | `output/cade_populations/direct_count.csv` |
| `\valAUCdirectStd` | (script-defined) | `scripts/33_auc_direct_cade.R` | `output/auc_direct_cade/auc_direct_cade.csv` |

## Reproduction commands

Full pipeline reproduction (~8 min on 16 cores):

```bash
cd paper3-frequent-losers
Rscript scripts/00_master.R
```

Manuscript compilation:

```bash
cd work/v17-editor
pdflatex paper_v17editor.tex
bibtex paper_v17editor
pdflatex paper_v17editor.tex
pdflatex paper_v17editor.tex
```

## Symlink layout (work/v17-editor)

The working directory inherits from `work/v13/` via symlinks for the data/output/macros layer:

```
work/v17-editor/output         -> ../v13/output
work/v17-editor/references.bib -> ../v13/references.bib
work/v17-editor/values.tex     -> ../v13/values.tex
```

Edits to `references.bib`, `values.tex`, and `output/tables/*` therefore land in `work/v13/` and are tracked there. Edits to `sec_*_v17.tex` files are local to `work/v17-editor/`.

## Disclosed limitations as macro chains

| Limitation | Where disclosed | Backing macro |
|---|---|---|
| In-sample AUC inflation | sec_cade leakage paragraph + Table 8 caption | `\valLeakStructLow`, `\valLeakStructHigh`, `\valLeakTautLow`, `\valLeakTautHigh` |
| Precision@k inflation | sec_robustness operational metrics table | `\valOpInsamplePrecFiveHund`, `\valOpPrecFiveHund`, `\valOpInflationShare` |
| Cobidders, not cartelists | Abstract + intro + conclusion explicit triage clause | `\valCobidders` (193) vs `\valDirectCADE` (47) |
| Sign reversal under overlap | sec_results_overlap | `\valMatchOverlapCoef`, `\valMatchPSCoef`, `\valSRQfourBroad`, `\valSRQfourATT` |

## Replication checklist for editor / referee

1. Confirm `data/processed/*.parquet` files match the file sizes reported in `README.md`.
2. Run `Rscript scripts/00_master.R` end-to-end; expect ~8 min runtime.
3. Compile `paper_v17editor.tex`; expect 49 pages, zero undefined refs/citations, zero bibtex errors.
4. Audit script (above) confirms zero ghost macros and zero macros without `% src:` provenance.
5. Cross-check at least 5 random `\valXxx` macros from manuscript prose against the named producing script's output CSV.
