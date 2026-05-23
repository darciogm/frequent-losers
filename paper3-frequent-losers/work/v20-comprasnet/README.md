# v20-comprasnet — cross-jurisdiction federal replication

## Scope

This directory contains all v20-specific artifacts for the
ComprasNet federal cross-jurisdiction replication of Paper 3
("Frequent Losers in Public Procurement").

**v18 (in `work/v18-editor/submission_clean/`) remains the canonical
JLEO submission** until the v20 integration is complete and
explicitly approved. Do not back-edit v18 with v20-derived numbers
unless the autor authorizes a v19 → v20 promotion.

## Why a separate v20

The BEC-only manuscript at v18 reached "Partial (strongly
supported)" on 7 of 8 hypotheses, bounded below 🟢 by single-
jurisdiction scope. v20 introduces:

- A second procurement panel (federal Pregão + Pregão SRP via
  Portal da Transparência CGU, 2013-2019; 51M participation rows).
- A federal CADE × ComprasNet ground-truth (built via 4-stage
  enrichment + linkage; see `STAGE_1C_CADE_COMPRASNET_LINKAGE_PLAN.md`
  in the paper root).
- Federal replications of 5 core ANs (AN-001, AN-004, AN-006,
  AN-007, AN-014) + the §7 selection/mechanism decomposition
  (AN-039 + AN-040) if `Valor Item` allows it.
- A new Appendix C in the manuscript documenting all of the above.

Expected R&R lift at JLEO: **+10 to +15 percentage points**.

## Directory layout

```
work/v20-comprasnet/
├── README.md                       # this file
├── LOG_SESSION.md                  # rolling per-session diary (created on first action)
├── manuscript/                     # appendix C drafts, eventual sec_app07_comprasnet.tex
├── output/                         # tables and figures specific to v20
└── values_comprasnet.tex           # macros for the federal numbers (later)
```

Shared artifacts (NOT in v20 dir):

- Build scripts: `scripts/00_build_eventlevel_comprasnet.py` (paper root)
- Linkage scripts: `scripts/65_cade_comprasnet_linkage.py` (paper root, this session)
- Data: `data/processed_comprasnet/` (paper root)
- Logs: `logs/comprasnet/` (paper root)

## Status

- **2026-05-22 23:35** — directory created. v20 work begins with
  Stage 1c.2 (linkage) using D1 step-1 (BEC reuse) as input.
- ComprasNet panel built (51.3M participation rows, 92.6K firms,
  35.9K always-losers, IQR threshold 32, 6.3K FL firms).
- POC linkage rodado em modo manual: 4 directs, 196 cobidders,
  5 FL cobidders. v1 do pipeline a seguir é a formalização disso.

## What v20 will NOT include (deferred)

- **Stage 2 Imhof full pipeline.** Requires bid-level microdata
  (lance value per ranking) which Portal CGU does NOT expose. Defer
  to R&R if invited (see Decisão D4 do plano).
- **Cross-modality test (D2 / AN-016).** Federal Convite is extinct
  (~5 participations/month). BEC-only by design.
- **Re-write of §1-7 from v18.** Only Appendix C is new prose.

---

**Last updated:** 2026-05-22 23:35
**Lead author of v20:** Darcio Genicolo-Martins (mr-frequent
delegated session continuation 2026-05-22).
