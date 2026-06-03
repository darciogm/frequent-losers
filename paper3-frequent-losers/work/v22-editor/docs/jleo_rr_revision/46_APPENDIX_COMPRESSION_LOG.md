# 46 — APPENDIX COMPRESSION LOG (Subprompt 13B)

Date 2026-06-03. Branch **`v22`** (designated JLEO R&R revision branch; Subprompts 1–13 committed here; working tree clean for `submission_clean/`, so no separate `rr_jleo_appendix_compression` branch was cut — v22 IS the safe revision branch).

## Files read
- `docs/jleo_rr_revision/` 29/30/31/33–34/44/45 completion reports + memos; appendix master + 9 `sec_app0*` files; cross-ref + table-label maps (grep).

## Method
Lead length+cross-ref audit → 5 fan-out compression agents (one per appendix family, disjoint files) → lead architecture rebuild (roadmap, master reorder, two section-merges) → lead build + audits + manifest.

## Agents (disjoint .tex files; CUT/MERGE/MOVE only, no number edits)
| Agent | File(s) | Lines | Tables | Result |
|---|---|---|---|---|
| A | sec_app02 (Data, App A) | 309→199 | 3→2 | kept screen_construction+validation_labels; moved case_timing |
| B | sec_app01 (Theory, App B) | 377→279 | 2→1 +fig | kept survival_summary+KM figure+Prop B1/Cor B1; moved survival_hazard |
| C | sec_app03 (Validation, App C) | **938→360** | **10→3** | kept control_function+strict_holdout+case_dominance; moved 7; 22→6 subsecs |
| D+F | sec_app08, sec_app04, sec_app05 | 408→163 / 222→127 / 92→24 | 3→1, 3→1, 1→0 | kept profile_smd, app_overlap_decomp; moved 5; removed H.x manual numbers |
| E | sec_app09, sec_app06 | 354→201 / 405→281 | 4→1, 3→2; figs 3→1 | kept bid_perf, G_denoms, G_frontier, cost-recall fig, algorithm; moved 3 tab+2 fig |

## Lead architecture rebuild
- **Roadmap:** sec_app00 referee-map table (stale letters, 0 refs) → unnumbered `\section*{Appendix Roadmap}` (≤250 words, A–F), table dropped.
- **Master reorder** to A–F: app02(A) app01(B) app03(C) app08(D) app09+app06(E) app04+app05(F); stripped stale `% CO-AUTHOR` comments.
- **Merge E:** app06 `\section`→`\subsection`, its `\subsection`→`\subsubsection`; app09 section retitled "Bid-Layer Benchmark and Cost-Recall Details".
- **Merge F:** app05 `\section`→`\subsection`; app04 retitled "Price Scope and Adaptive Deployment".

## Tables/figures moved → online supplement
18 tables + 2 figures, consolidated in `online_supplement/APPENDIX_MOVED_MANIFEST.csv` (20 rows); supplement dirs `A_…/`…`F_…/`+`Z_…/` created with READMEs.

## Builds / fixes
- Appendix preamble lacked `\newtheorem{assumption}`/`{corollary}` (used by App B) → added.
- app04 dangling `app:adaptive_deployment_submission` → `app:strategic_adaptation_submission`.
- `\texttt{timing_sequential_blocked.csv}` filename → prose "infeasible".
- **Final: paper 39pp / appendix 31pp, 0 errors, 0 undefined refs both halves.**

## Result
Appendix **55pp→31pp**; tables **30→11**; figures **4→2**; appendices **9→6 (A–F)+roadmap**; subsections 66→~28. Internal-language 0; affirmative terminology 0; 0 dangling refs.

## Remaining blockers
See `49_…REMAINING_BLOCKERS.md`. None build-blocking. Two App-A construction tables lack tablenotes (cosmetic).
