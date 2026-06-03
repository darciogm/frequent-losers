# 49 — APPENDIX COMPRESSION: REMAINING BLOCKERS (Subprompt 13B)

No build-blocking or submission-blocking issues. Residuals:

| # | Item | Severity | Note |
|---|---|---|---|
| 1 | Appendix 31pp vs 25–30 target | minor | Within ≤35 hard max; close to target. Second compression pass NOT triggered. |
| 2 | App A tables A.1/A.2 lack `\begin{tablenotes}` | cosmetic | Construction tables; captions self-explanatory. Optional polish before final submission. |
| 3 | "blocked"→"infeasible" wording for strict bid-timing | resolved | Substantive disclosure retained; filename reference removed. |
| 4 | Online supplement files are MANIFEST + dir stubs, not the moved LaTeX/CSV payloads | tracked | Moved-table OUTPUTS exist under `outputs/`; the supplement payload assembly is a packaging step for final submission (Subprompt 14), not a compression blocker. |
| 5 | Orphaned `sec_app07_comprasnet` | tracked | Not `\input` in master; intentionally excluded from the submitted package. |

No `APPENDIX_NOT_SUBMISSION_READY` / `OVERCOMPRESSED` / `BUILD_BLOCKED` flags raised.
