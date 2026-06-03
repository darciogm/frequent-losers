# 47 — APPENDIX LENGTH AUDIT (BEFORE COMPRESSION)

Date 2026-06-03. Branch `v22`. Source: `work/v22-editor/submission_clean/online_appendix_submission_clean.tex` (compiled PDF) + per-file grep.

Commands:
- `pdfinfo online_appendix_submission_clean.pdf | awk '/Pages/{print $2}'` → **55 pages**
- per file: `wc -l`, `grep -cE '\\begin\{table'` minus `\begin{tablenotes}`, `grep -cE '\\begin\{figure'`, `grep -cE '\\subsection\{'`

## Before-state inventory (submitted appendix = 9 `\input` files; `sec_app07_comprasnet` is ORPHANED, not `\input`)

| Order | File | Logical appendix | Lines | Tables | Figs | Subsecs |
|---|---|---|---|---|---|---|
| 1 | sec_app00 referee_map | Guide | 52 | 1 | 0 | 0 |
| 2 | sec_app01 framework | Theory/Exit/Survival | 377 | 2 | 1 | 6 |
| 3 | sec_app02 data_labels | Data/Label | 309 | 3 | 0 | 8 |
| 4 | **sec_app03 validation_audits** | Opportunity/Timing/Case | **938** | **10** | 0 | **22** |
| 5 | sec_app04 scope | Price | 222 | 3 | 0 | 9 |
| 6 | sec_app05 adaptive_deployment | Adaptation | 92 | 1 | 0 | 2 |
| 7 | sec_app06 forensic_sequence | Cost-recall | 405 | 3 | 3 | 10 |
| 8 | sec_app08 profile | Profile/Score | 408 | 3 | 0 | 9 |
| 9 | sec_app09 bid_benchmark | Bid benchmark | 354 | 4 | 0 | 9 |
| — | sec_app07 comprasnet | (orphaned) | 401 | 0 | 0 | 7 |
| | **TOTAL (9 submitted)** | | **3157** | **30** | **4** | **66** |

## Problems
- **55pp** vs ≤35 hard max / 25–30 target.
- **30 tables** vs ≤12 budget.
- 4 figures (within ≤5).
- **66 subsections** — the appendix reads like an audit dossier.
- **sec_app03 is the monster**: 938 lines, 10 tables, 22 subsections — opportunity + timing + leakage + case + clustered-RI all piled in.
- Granular grids inline: full opportunity-cell permutation (opp_permutation), full validation-audit map, clustered-RI full output, direct-defendant-timing, year-by-year holdout, full bid-feature dictionary, full price regression grid, full cost-recall grid, negative controls, market-specific zero-win variants.

## Cross-reference finding (decisive for safe fan-out)
Every appendix table label is `\ref`-ed **only inside its own appendix file**; no main-text section and no other appendix references any appendix table. → Tables can be moved per-file with the moving agent fixing its own in-file ref; no central dangling-ref risk. (Section-level `\label{app:...}` are preserved, so main-text section refs auto-renumber A–F.)

## Target architecture (6 appendices A–F)
A=data(app02) · B=theory(app01) · C=validation(app03) · D=profile(app08) · E=bid(app09)+cost(app06) merged · F=price(app04)+adaptive(app05) merged. Guide(app00)→≤250-word roadmap. Table budget 11: A2 B1 C3 D1 E3 F1. Figure budget 2: B survival, E cost-recall.
