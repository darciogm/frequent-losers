# Active Source Inventory — Final Polish (2026-06-04)

**Branch:** `v22` · HEAD `1b6e2df` · v22-editor tree clean at start.

## Active build (JLEO submission pair)

| Role | Path |
|---|---|
| Main manuscript source | `submission_clean/paper_jleo_submission.tex` |
| Active manuscript includes | `sec_frontmatter`, `sec01–sec08`, `sec99` (`_submission.tex`) |
| Appendix source | `submission_clean/online_appendix_jleo_submission.tex` |
| Active appendix includes (order = lettering) | app00 (roadmap, unnumbered) → **A**=app02 → **B**=app01 → **C**=app03 → **D**=app08 → **E**=app09+app06 → **F**=app04+app05 |
| Macro files | `values.tex`, `values_adversarial.tex` (both `\input` by all four wrappers) |
| Bibliography | `references.bib` (natbib/bibtex) |
| Figures | `submission_clean/output/figures/{fig_data_coarsening, fig_observed_vs_expected_contact_bins, fig_3_cost_recall_frontier}.pdf` (3 `\includegraphics` in main) |
| Tables | inline (macro-bound); generated artifacts under `outputs/tables/` are provenance, not `\input` |
| Final manuscript PDF | `submission_clean/paper_jleo_submission.pdf` → packaged as `submission_jleo/manuscript/GenicoloMartins_Azevedo_CheapSignals_CostlyProof_JLEO_Manuscript.pdf` |
| Final appendix PDF | `submission_clean/online_appendix_jleo_submission.pdf` → `submission_jleo/appendix/GenicoloMartins_..._JLEO_Appendix.pdf` |
| Active cover letter | `submission_jleo/cover_letter/cover_letter_jleo.md` (→ pandoc → `GenicoloMartins_..._JLEO_CoverLetter.pdf`); short variant `cover_letter_jleo_short.md`; working copy `submission_clean/cover_letter_JLEO_submission.md` |
| Build command | (cd submission_clean) compile `online_appendix_submission_clean` FIRST (xr aux) → `online_appendix_jleo_submission` → `paper_jleo_submission` → `paper_submission_clean`; pdflatex×3 + bibtex each |

## Stale / inactive (scan-only, DO NOT edit as active)

- `submission_clean/sec_app07_comprasnet_submission.tex` — **NOT \input by any wrapper** (orphaned; known). Scan-only.
- `submission_clean/{paper_submission_clean_final.pdf, online_appendix_submission_clean_final.pdf, paper_plus_appendix_submission_clean.pdf}` — frozen earlier snapshots; not the submission PDFs.
- `submission_jleo/manuscript/GenicoloMartins_..._Manuscript_compact_backup.pdf` — backup, not submitted.
- `work/v13/`, `work/v20-editor/`, `work/v21-editor/`, repo-level `manuscript/`, `papers_finais/`, `v2–v4/` — historical lines, out of scope.
- `docs/jleo_rr_revision/*` — internal command-center docs (193 mentions allowed; internal_doc_ignore).
- `outputs/`, `online_supplement/` — generated artifacts; checked via the PDFs/registries, not edited by hand.

## Files scanned but not edited

All stale files above + `Referees/`, `referee_report_*.md`, `mr-frequent-losers.md` (persona), `Makefile` (verified, no edit needed).
