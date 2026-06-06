# 100 — Active Source Inventory (Story / Compression / Humanization pass)
**Date:** 2026-06-06 · **Branch:** `rr_jleo_story_compression_humanization` (from `v22`)

## Active build sources (EDIT THESE)
- Main master: `work/v22-editor/submission_clean/paper_submission_clean.tex` (+ `paper_jleo_submission.tex` double-spaced twin, shared sections)
- Appendix master: `online_appendix_submission_clean.tex` (+ `online_appendix_jleo_submission.tex` twin)
- **Online Supplement master (NEW this pass):** `online_supplement_submission.tex` → `\input`s `sec_supp_*.tex`
- Cover letter: `cover_letter_JLEO_submission.md`
- Bib: `references.bib` · Macros (READ-ONLY values): `values.tex`, `values_adversarial.tex`

### Main section files + current size (words)
frontmatter 204 · intro(sec01) 2288 · setting(sec02) 1486 · screen(sec03) 844 · validation(sec04) **4017** · comparative §5 2190 · cobidder §6→sec05 1198 · forensics §7→sec06 **4328** · price §8→sec07 478 · conclusion sec08 812

### Appendix files + current size (words) — 46pp, 16 tables, 3 figs
app00 roadmap 266 · app01 framework 2639 · app02 data/labels 1655 · app03 validation **4459** · app04 scope/price 755 · app05 adaptive 267 · app06 forensic-seq 2030 · app08 profile 1195 · app09 bid 1394 · app10 federal **2372**

## Targets
- Main body **40–42pp** (currently 53). Appendix **~20pp, hard max 22** (currently 46) → ~26pp + ~6 tables migrate to Online Supplement.
- Main ≤6 tables / ≤3 figs (currently 7/3 — fold or demote 1). Appendix ≤10 tables / ≤3 figs (currently 16/3).

## Migration convention
Heavy grids/permutations/dictionaries/fold-audits/full-price-grids/full-federal-construction move from `sec_appNN` → new `sec_supp_NN.tex` (\input by supplement master). Appendix keeps a COMPACT summary + one-paragraph pointer "full grid in Online Supplement S.NN". Keep the appendix section `\label` so main-text `\ref{app:...}` still resolves; give migrated tables new `supp:` labels.

## Build (appendix → supplement → paper → re-appendix for xr)
```
pdflatex online_appendix_submission_clean ×2
pdflatex online_supplement_submission ×2
pdflatex paper_submission_clean ; bibtex ; pdflatex ×2
pdflatex online_appendix_submission_clean   # resolve refs
```

## Stale (DO NOT submit/edit): `_stale_pdf_quarantine/` PDFs.
