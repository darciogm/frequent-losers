# 97 — Active Source Inventory (Positioning + Humanization pass)
**Date:** 2026-06-06 · **Branch:** `rr_jleo_positioning_humanization` (from `v22`)

## Active build sources (EDIT THESE)
- **Main manuscript master (canonical):** `work/v22-editor/submission_clean/paper_submission_clean.tex`
- **Main master (JLEO double-spaced twin):** `paper_jleo_submission.tex` — shares the SAME section files; differs only in preamble (spacing/geometry). Editing sec files updates both.
- **Appendix master (canonical):** `online_appendix_submission_clean.tex`
- **Appendix master (JLEO twin):** `online_appendix_jleo_submission.tex`
- **Cover letter:** `cover_letter_JLEO_submission.md`
- **Bibliography:** `references.bib`
- **Macros (numbers — READ ONLY, never hand-edit values):** `values.tex`, `values_adversarial.tex`

### Main section files (in \input order)
sec_frontmatter_submission (TITLE+ABSTRACT) · sec01_introduction_submission · sec02_setting_layers_submission · sec03_award_layer_screen_submission · sec04_validation_submission · sec_comparative_submission (§5 federal) · sec05_cobidder_type_submission (§6) · sec06_screening_forensics_submission (§7) · sec07_price_scope_submission (§8) · sec08_conclusion_submission (§9) · sec99_endmatter_submission

### Appendix section files (in \input order)
sec_app00_referee_map · sec_app02_data_labels · sec_app01_framework · sec_app03_validation_audits · sec_app08_profile · sec_app09_bid_benchmark · sec_app06_forensic_sequence · sec_app04_scope · sec_app05_adaptive_deployment · sec_app10_federal_audit

## Final PDFs intended for submission
- `paper_submission_clean.pdf` (Jun 6) + `online_appendix_submission_clean.pdf` (Jun 6) — canonical
- `paper_jleo_submission.pdf` + `online_appendix_jleo_submission.pdf` — double-spaced submission format

## Build command (appendix FIRST for xr cross-refs)
```
pdflatex online_appendix_submission_clean ; pdflatex online_appendix_submission_clean
pdflatex paper_submission_clean ; bibtex paper_submission_clean ; pdflatex paper_submission_clean ; pdflatex paper_submission_clean
pdflatex online_appendix_submission_clean   # resolve §-refs to new box
# repeat for the _jleo twins
```

## Stale detected — DO NOT submit, DO NOT edit
- **QUARANTINED** to `_stale_pdf_quarantine/`: `paper_submission_clean_final.pdf` (May 25), `online_appendix_submission_clean_final.pdf` (May 25), `paper_plus_appendix_submission_clean.pdf` (May 26) — predate v23 federal work; same-family names = FATAL_PACKAGE_CONFUSION risk, now neutralized.
- Earlier-version DRAFT scratch (`sec_comparative_DRAFT.tex`, `sec_appG_federal_DRAFT.tex`) already deleted in Phase 3.

## Files to scan but NOT edit
- Everything under `docs/`, `outputs/` (logs/ledgers), `scripts/` (analysis code), `data/`.
- `values.tex` / `values_adversarial.tex`: scan for stale numbers only; never hand-edit (regenerated; hand-edit only with `% src:` per house rule, and not in this prose pass).
