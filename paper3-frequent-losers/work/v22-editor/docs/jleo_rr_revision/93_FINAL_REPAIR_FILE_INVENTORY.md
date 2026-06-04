# 93 — FINAL REPAIR FILE INVENTORY (2026-06-04)

| Role | Path | Status at repair start |
|---|---|---|
| Main manuscript source | `submission_clean/paper_jleo_submission.tex` + `sec_frontmatter` + `sec01–sec08` + `sec99` | canonical (rebuilt 2026-06-04) |
| Appendix source | `submission_clean/online_appendix_jleo_submission.tex` + `sec_app00–09` | canonical |
| Working (single-spaced) pair | `paper_submission_clean.tex` / `online_appendix_submission_clean.tex` | canonical; clean-appendix aux feeds xr |
| Final manuscript PDF | `submission_clean/paper_jleo_submission.pdf` | 52 pp, 0 err/0 undef |
| Final appendix PDF | `submission_clean/online_appendix_jleo_submission.pdf` | 47 pp, 0 err/0 undef |
| Macro files | `submission_clean/values.tex`, `values_adversarial.tex` | rebound to canonical label |
| Cover letter (working) | `submission_clean/cover_letter_JLEO_submission.md` | **STALE → repair (agent)** |
| Cover letters (package) | `submission_jleo/cover_letter/cover_letter_jleo{,_short}.md` + PDF | **STALE → repair + regenerate PDF** |
| Package manuscript/appendix PDFs | `submission_jleo/{manuscript,appendix}/GenicoloMartins_*.pdf` | **STALE (pre-canonical) → refresh from submission_clean builds** |
| Admin statements | `submission_jleo/admin/*.md` (5 files) | verify label-source description (agent) |
| Replication mirror | `submission_jleo/replication/`, `replication/`, `README_replication.md` | must name `00_build_canonical_validation_targets.R` |
| Table generators | `scripts/analysis/00_build_canonical_validation_targets.R`, `01–11`, `55_adversarial_adaptation_canonical.R` | canonical, all rc=0 |
| Figure generator | `submission_clean/make_submission_figures.R` | Figure 1 vocabulary verified |
| Build command | appendix(clean)→appendix(jleo)→paper(jleo)→paper(clean), pdflatex×3 + bibtex | documented in 90 |
| Diagnostics | `Makefile` targets diagnostics/audit; `scripts/diagnostics/scan_*.R` | working |
