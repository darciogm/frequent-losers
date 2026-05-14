# Paper 2 — v3-structural (top-5 upgrade)

Working version since 2026-04-23. Closes the structural gaps that the
referee-2 audit of v2 flagged as fatal for ReStud/QJE: endogenous
entry, unobserved auction-level heterogeneity, Pregão as a dynamic
descending auction, and welfare accounting with MCPF.

## Relationship to v1 and v2

- **v1 (root)** — reduced-form DiDiR + CS(2021). JPubE-ready. Frozen.
- **v2-structural** — first structural pilot (GPV Convite, asymmetric
  CPV, HT Pregão bounds, reduced-form entry). Frozen as reference;
  do not edit.
- **v3-structural (this tree)** — canonical working version. All new
  scripts, tables, figures, and manuscript drafts for the structural
  paper live here.

## Roadmap (from the referee-2 audit)

| Sprint | Deliverable | Closes |
|---|---|---|
| **S1** | Historical bid-level SME flag + pharma stratification | Mod5, Mod4 |
| **S2** | Pregão as descending-clock + bug-fix in HT integration | M3 |
| **S3** | Krasnokutskaya (2011) UH deconvolution; refit F_c | M2 |
| **S4** | Athey–Levin–Seira nested entry-bidding; BNE re-solve in CF | M1 |
| **S5** | Robustness battery (bandwidth grid, B=500, filter sens., APV) | Mod1, minors |
| **S6** | Welfare with MCPF + bidder surplus + production DWL | Mod3 |
| **S7** | Manuscript rewrite with primitive-invariance proposition | Framing |

## Current status

**S1 in progress.** Data foundations: per-bid SME flag (historical
validated) + pharma indicator. Blocks S3 and S4.

## Directories

```
v3-structural/
├── scripts/            # R pipeline (32_… onward; utils_v3.R for paths)
├── data/processed/     # parquet caches
├── output/tables/      # generated tables (tab_v3_*.tex/csv)
├── output/figures/     # generated PDFs (fig_v3_*.pdf)
├── logs/               # per-script run logs + S1 memos
└── manuscript/         # paper_v3.tex (assembled after S4)
```

## Targets

- ReStud after S4.
- QJE tentative after S6.
- Pivot to JPubE if S3 or S4 returns results materially weaker than v2.
