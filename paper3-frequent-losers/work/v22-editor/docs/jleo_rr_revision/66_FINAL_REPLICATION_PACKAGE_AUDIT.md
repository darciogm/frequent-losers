# 66 — Final Replication-Package Audit (JLEO submission, v22)

**Scope.** Verify the replication infrastructure under `work/v22-editor/` is
complete, all main/appendix outputs map to scripts, manifests/registries/seeds/
environment are documented, confidentiality is handled, and **no raw firm
identifiers (CNPJ) leak into public-facing files.**

**Headline.** The package is **near-ready and well-documented** (README,
SCRIPT_ORDER, DATA_CONFIDENTIALITY, OUTPUTS_MAP, both registries, both supplement
manifests all present; T1–T6 + F1–F3 + appendix all mapped; seeds + R 4.5.2 env
documented; BEC microdata confidentiality stated; honest blocker disclosure).
**One blocker:** a **raw 14-digit CNPJ leaks into a public-facing online-supplement
file**, which directly contradicts the package's own no-raw-CNPJ policy.

> **`REPLICATION_PACKAGE_NOT_READY_FOR_JLEO`** — single gap:
> raw CNPJ `61288437000167` in
> `work/v22-editor/online_supplement/S_D_timing_opportunity.md:86`.
> Must be anonymized before the supplement is posted. (See §5. Not fixed here —
> read-only mandate.)

---

## 1. Required files present (PASS)

| File | Path | Status |
|---|---|---|
| README | `replication/README.md` | PRESENT (185 lines; overview, software, data avail, T1–T6/F1–F3 map, appendix map, seeds, known limits) |
| Script order | `replication/SCRIPT_ORDER.md` | PRESENT (dependency-ordered, 11 stages incl. LaTeX build order) |
| Data confidentiality | `replication/DATA_CONFIDENTIALITY.md` | PRESENT (BEC not redistributable; CADE public; B3 disclosed; anonymized-frame policy) |
| Outputs map | `replication/OUTPUTS_MAP.csv` | PRESENT (16 rows; T1–T6, F1–F3, App B/D/E/G/H/I) |
| Manifest | `replication/MANIFEST.csv` | PRESENT |

## 2. Registries (PASS — path documented)

| Registry | Path | Status |
|---|---|---|
| `output_registry.csv` | `work/v22-editor/outputs/output_registry.csv` | **PRESENT** (header + per-output rows with script, inputs, metrics, status) |
| `dataset_registry.csv` | `work/v22-editor/outputs/dataset_registry.csv` | **PRESENT** (per-dataset path/level/key/row-count/status) |

- **NOT** under `paper3-frequent-losers/output/` — both live under
  `work/v22-editor/outputs/`. Path resolved and reported here so reviewers don't
  hunt for them.
- Minor staleness (non-blocking): `output_registry.csv` row
  `MAIN_COST_RECALL_FRONTIER` still says "BLOCKED: output/regulatory_frontier/
  EMPTY (run 56)", but Table 6 is now produced by the newer
  `scripts/analysis/10_cost_recall_frontier.R` per `OUTPUTS_MAP.csv`. The registry
  note is legacy; the OUTPUTS_MAP (the file reviewers use) is correct.
  Recommend refreshing that one registry row for tidiness.

## 3. Output → script mapping (PASS)

- **Main Tables 1–6 and Figures 1–3** are all individually mapped to generating
  scripts in both `replication/README.md §4` and `OUTPUTS_MAP.csv` (rows
  `MAIN_T1…T6`, `FIG1…FIG3`). The three `\includegraphics` figures
  (`fig_data_coarsening`, `fig_observed_vs_expected_contact_bins`,
  `fig_3_cost_recall_frontier`) are named and path-resolved.
- **Appendix outputs** (App B survival, App D validation audits, App E price-scope,
  App G cost denominators, App H profile, App I bid benchmark) are mapped in
  README §5 and OUTPUTS_MAP rows `APP_*`.
- **Online-supplement** is index-only: 9 numbered dirs + A–F lettered dirs, each
  with a README pointer, plus `MANIFEST.csv`, `APPENDIX_MOVED_MANIFEST.csv`, and
  `S_D/S_H/S_I` narrative indexes. The supplement points to CSV/figure artifacts
  under `outputs/diagnostics|tables|figures|cache/` rather than embedding data.

## 4. Seeds & environment (PASS)

- **Seeds documented** (README §7): `20260430, 20260501, 20260530, 20260602,
  20260603`. Covers the task-listed seeds (20260430/20260530/20260602/20260603)
  plus 20260501. Deterministic-count scripts noted as seed-free.
- **Environment documented:** R **4.5 (4.5.2)** with package list
  (`data.table, fixest, ranger, pROC, survival, MatchIt, DBI, duckdb, ggplot2`);
  Python 3 (`pandas, pyarrow, duckdb`) for ETL; LaTeX `elsarticle`+`natbib`
  (**bibtex, not biber**); OS/hardware (WSL2, i7-1260P, 21 GiB, no GPU); machine
  caps (DuckDB threads=12 / 14GB / spill). Install snippets included.

## 5. Confidential / proprietary data treatment (PASS on policy; FAIL on one leak)

**Policy — documented (PASS).** `DATA_CONFIDENTIALITY.md` correctly states:
BEC microdata are administrative, **not redistributable** (contains CNPJ); CADE
rulings are public; B3 label-builder absence is disclosed; **only anonymized
firm-level frames (anonymous `firm_id`, no raw CNPJ) may be posted**; the
`códigofornecedor = -1` sentinel must be excluded.

**Identifier-leak spot-check — one FAIL.**
Scanned `replication/` and `online_supplement/` text files (`.md`, `.csv`) for
14-digit CNPJ patterns and formatted CNPJ patterns:

- `replication/` — **clean**. The only CNPJ hits are the *policy text itself*
  ("raw CNPJ", "no raw CNPJ"), not actual identifiers.
- `online_supplement/` — **one raw CNPJ found**:
  - `S_D_timing_opportunity.md:86` →
    `... mean ROC 0.944, dominated by **61288437000167** / trens_metros lead).`
  - `61288437000167` is a valid 14-digit Brazilian CNPJ (formats to
    61.288.437/0001-67). It is the **only** raw identifier in the entire
    supplement tree (the supplement is otherwise index-only).

This is a direct contradiction of the package's own no-raw-CNPJ rule and must be
remediated before the online supplement is posted. **Recommended fix (for the
author, not applied here):** replace the raw CNPJ with the anonymized `firm_id` or
a generic descriptor (e.g. "the lead defendant group / trens_metros") — the
narrative point ("one defendant group dominates the leave-one-out grid") survives
without the identifier.

*(Note: this string is a transit-authority-style entity, not necessarily a
private cartel defendant — but the no-raw-CNPJ policy is categorical, so it should
be stripped regardless.)*

## 6. Honest-disclosure posture (PASS)

The package openly discloses (README §8, DATA_CONFIDENTIALITY §3):
B3 (193-cobidder file has no on-disk builder; reproducible alternative is the
12→41→341 funnel reproducing 208≈210/107≈108 but **not** legacy 193);
sequential strict-timing **blocked** → timing reported as FAIL/observational-
equivalence; NOT_OBSERVED cost denominators labeled illustrative. This is the
correct stance for a JLEO R&R and is consistent with the manuscript text.

---

## 7. Verdict & required action

| Check | Result |
|---|---|
| README / SCRIPT_ORDER / DATA_CONFIDENTIALITY / OUTPUTS_MAP exist | PASS |
| output_registry.csv + dataset_registry.csv exist | PASS (under `work/v22-editor/outputs/`) |
| T1–T6 + F1–F3 mapped to scripts | PASS |
| Appendix outputs mapped | PASS |
| Online-supplement MANIFEST + APPENDIX_MOVED_MANIFEST exist | PASS |
| Seeds documented | PASS |
| Environment (R version + packages) documented | PASS |
| Confidential-data policy documented | PASS |
| **No raw CNPJ in public-facing files** | **FAIL** (1 leak) |

**`REPLICATION_PACKAGE_NOT_READY_FOR_JLEO`** — blocked by exactly one gap:
strip raw CNPJ `61288437000167` from
`online_supplement/S_D_timing_opportunity.md:86`. Optional tidy-ups: refresh the
stale `MAIN_COST_RECALL_FRONTIER` registry note. Once the CNPJ is anonymized the
package is JLEO-ready.
