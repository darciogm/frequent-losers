# 57 — FINAL SUBMISSION BUILD LOG

Date 2026-06-03. Branch `v22`.

## Commands
```
pdflatex online_appendix_submission_clean.tex   # refresh original auxes (post CNPJ/Lei/JEL edits)
pdflatex paper_submission_clean.tex  (x2)
# double-spaced 1.25in JLEO variants:
pdflatex online_appendix_jleo_submission.tex    (x3)
pdflatex paper_jleo_submission.tex              + bibtex + pdflatex (x2)
```

## Results
| File | Path (submission_clean/) | Pages | Errors | Undef |
|---|---|---|---|---|
| Manuscript (double-spaced, 1.25in) | paper_jleo_submission.pdf | **52** | 0 | 0 |
| Appendix (double-spaced, 1.25in) | online_appendix_jleo_submission.pdf | **43** | 0 | 0 |
| Manuscript compact (1.48) backup | paper_submission_clean.pdf | 39 | 0 | 0 |
| Appendix compact (1.38) backup | online_appendix_submission_clean.pdf | 31 | 0 | 0 |

- Severe overfull (>30pt): 0 (manuscript variant).
- Cover letter: submission_jleo/cover_letter/..._CoverLetter.pdf (1pp, pandoc/pdflatex).
- All PDFs open; abstract ≤150w; 6 main tables / 3 figures; appendix 11 tables / 2 figures.
- Package: submission_jleo/{manuscript,appendix,cover_letter,online_supplement,replication,admin,figures_source}.
