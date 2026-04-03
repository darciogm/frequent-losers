# JLE Submission Checklist — paper_screening_v4

## Journal requirements

- [x] Double-spaced throughout (12pt, 1in margins)
- [x] Abstract ≤ 150 words (current: ~120)
- [x] Chicago citation style (natbib + chicago.bst)
- [x] Single-blind (author names visible — JLE policy)
- [x] Keywords + JEL codes on title page
- [x] No special LaTeX class files (standard article class)
- [x] All .bib files included
- [x] Online appendix clearly demarcated with separate page counter

## Submission package contents

1. **paper_screening_v4.pdf** — Main manuscript (81 pp)
   - Body: ~31 pp
   - References: ~2 pp
   - Print appendix (A-E): ~12 pp
   - Online appendix (F-I): ~36 pp

2. **cover_letter.pdf** — Cover letter (2 pp)

3. **LaTeX source bundle** — All .tex, .bib, .bst files
   - paper_screening_v4.tex (main driver)
   - 10 section .tex files
   - 10 sections/*.tex files
   - 9 tables/*.tex files
   - references.bib

4. **Replication package** — Available at ../replication/
   - README.md with full instructions
   - 24 R scripts
   - 10 data files (~480 MB parquets + CSVs)
   - 40 output tables + 23 figures

## Upload to Editorial Manager

Portal: https://www.editorialmanager.com/jlawecon

Steps:
1. Create account / log in
2. Select "New Submission"
3. Upload manuscript PDF
4. Upload cover letter
5. Upload LaTeX source as supplementary
6. Fill in: title, authors, abstract, keywords, JEL codes
7. Pay submission fee ($100 non-subscriber / $75 subscriber)
8. Submit disclosure statement
9. Note: replication package to be provided upon acceptance

## Pre-submission final checks

- [x] Zero unresolved references (??) in PDF
- [x] Zero overclaim terms in body text
- [x] 92 enforcement/triage terms across body
- [x] All numerical results unchanged from pipeline
- [x] N = 1,654,401 consistent throughout
- [x] Table 6 fits within page margins
- [x] Online appendix header with title + authors
- [x] Companion paper cited (genicolomartins2026structural)
