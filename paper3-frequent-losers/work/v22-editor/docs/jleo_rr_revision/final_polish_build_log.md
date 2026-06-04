# Final Polish Build Log (2026-06-04)

## Commands run

```
# polish edits: sec_frontmatter (abstract +"implemented as a frequent-loser flag"),
# sec06 (Step-7 caveat paragraph inserted at §6.2 opening; "Timing discipline" de-duplicated;
# §6 opener "The screen is useful because" -> "Whatever value the award-layer ranking retains";
# fig-caption "cost saving" -> "footprint reduction"), sec03 ("The screen is useful only if" ->
# "The ranking can organize incumbent-firm triage only if"), sec02 ("if a cheap screen is
# useful" -> audited-premise phrasing), sec_app03 ("ranking signal survives" -> "limited
# within-pool residual ordering remains"), cover_letter_jleo.md (exact org-framework opener;
# HUMAN_DECISION marker -> submittable sentence), admin/*.md (HUMAN_DECISION -> [AUTHOR INPUT REQUIRED])
cd submission_clean
for f in online_appendix_submission_clean online_appendix_jleo_submission \
         paper_jleo_submission paper_submission_clean; do pdflatex ×2-3 + bibtex; done
cp paper_jleo_submission.pdf  ../submission_jleo/manuscript/GenicoloMartins_..._Manuscript.pdf
cp online_appendix_jleo_submission.pdf ../submission_jleo/appendix/GenicoloMartins_..._Appendix.pdf
pandoc cover_letter_jleo.md -> GenicoloMartins_..._CoverLetter.pdf  (1 page)
pdftotext -> outputs/diagnostics/final_{manuscript,appendix}_text_after_polish.txt
```

## Results

| Item | Value |
|---|---|
| Build success | YES — 4/4 documents |
| Final manuscript PDF | `submission_clean/paper_jleo_submission.pdf` → packaged `submission_jleo/manuscript/GenicoloMartins_Azevedo_CheapSignals_CostlyProof_JLEO_Manuscript.pdf` |
| Final appendix PDF | `submission_clean/online_appendix_jleo_submission.pdf` → packaged `submission_jleo/appendix/..._Appendix.pdf` |
| Main body pages | 53 (double-spaced JLEO format; +1 from Step-7 caveat insertion) |
| Appendix pages | 47 |
| Errors / undefined refs / undefined cites | **0 / 0 / 0** (all four logs) |
| Main tables / figures | **6 / 3** — exactly at JLEO budget (`main_float_budget_audit.csv`; all six core tables kept) |
| Abstract word count | ≈130–143 (counting-method dependent) — **≤150** |
| Cover letter PDF | 1 page, regenerated post-edit (verified by distinctive-phrase check) |
| PDF text scan | `final_pdf_text_scan_after_polish.csv` — all high-risk terms 0; deployment terms negated-boundary only; "screen is useful" 0 after §6 opener fix |
| Unresolved warnings | none blocking (standard elsarticle/natbib notices only) |
