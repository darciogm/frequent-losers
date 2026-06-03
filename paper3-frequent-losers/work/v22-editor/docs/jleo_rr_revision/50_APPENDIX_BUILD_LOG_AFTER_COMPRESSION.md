# 50 — APPENDIX BUILD LOG (AFTER COMPRESSION)

Date 2026-06-03. Branch `v22`.

## Commands
```
pdflatex online_appendix_submission_clean.tex   (x2)
pdflatex paper_submission_clean.tex             (x2, refreshes xr appendix letters)
```

## Result
| Target | PDF | Pages | Errors | Undefined refs/cites |
|---|---|---|---|---|
| Appendix | online_appendix_submission_clean.pdf | **31** | 0 | 0 |
| Paper | paper_submission_clean.pdf | 39 | 0 | 0 |

- Appendix start: Roadmap (unnumbered) → Appendix A … Appendix F.
- Appendix tables: **11** (A.1 A.2 · B.1 · C.1 C.2 C.3 · D.1 · E.1 E.2 E.3 · F.1).
- Appendix figures: **2** (B.1 survival KM · E.1 cost-recall frontier).
- Online-supplement references resolve (prose pointers, no `\ref` to moved floats).
- Warnings: only benign `Float too large`/`Label(s) may have changed` (filtered); rebuilt to stable.

## Fixes applied during build
1. Added `\newtheorem{assumption}`/`{corollary}` to appendix preamble (App B uses them).
2. `app:adaptive_deployment_submission` → `app:strategic_adaptation_submission` (App F).
3. Removed `\texttt{...blocked.csv}` filename; "blocked"→"infeasible".
