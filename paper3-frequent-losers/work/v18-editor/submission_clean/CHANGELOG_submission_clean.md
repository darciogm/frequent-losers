# Submission-clean change log

## Critical cleanup

- Created a self-contained submission package under `submission_clean/`.
- Removed internal version markers from the submission files and generated auxiliary files.
- Removed draft-only wording, including internal design labels.
- Fixed the appendix-reference pattern so compiled text does not produce "Appendix Appendix".
- Rebuilt Figure 1 with "Bid layer (forensic-recoverable)".
- Rebuilt Figure 2 with "Temporal holdout: training-window expansion test".
- Resolved the Table 3 draft cell by replacing the internal-design cell with a submission-facing pointer to the exposure-adjusted audit.

## Title and abstract

- Final title: "Cheap Signals, Costly Proof: Award-Layer Evidence Triage in Cartel Enforcement".
- The appendix title and PDF metadata use the same title.
- The abstract now reports the sequential gatekeeping result: 83% bid-microdata reduction while recovering 131 of 193 adjudicated cobidders.

## Cross-references

- Section, table, figure, and appendix labels were renamed for the submission package.
- Appendix lettering compiles as:
  A. Guide to the Online Appendix;
  B. Evidence-Allocation Framework and Legal Scope;
  C. Data Construction and Validation Labels;
  D. Validation Audits;
  E. Scope of Price Evidence;
  F. Adaptive Deployment Diagnostics;
  G. Forensic Sequencing Details.
- No undefined references remain after the final build.

## Numerical consistency

- The abstract gatekeeping sentence matches Section 6: 83% reduction and 131 of 193 adjudicated cobidders.
- Figure 1 uses the Section 6 AUCs: award-layer AUC 0.903 [0.884, 0.923] and bid-layer benchmark AUC 0.888 [0.865, 0.911].
- Figure 2 uses the appendix year-by-year temporal-holdout AUC series.
- Direct-defendant AUC references remain context-specific: the main firm-level scope check uses 0.49, while appendix leakage/direct-temporal checks report item-level variants.
- No numerical conflict requiring author decision was found in this cleanup pass.

## Compilation

- Commands used:
  - `Rscript make_submission_figures.R`
  - `pdflatex -interaction=nonstopmode online_appendix_submission_clean.tex`
  - `pdflatex -interaction=nonstopmode paper_submission_clean.tex`
  - `bibtex online_appendix_submission_clean`
  - `bibtex paper_submission_clean`
  - final `pdflatex` reruns for both files
- Final logs contain no LaTeX, Package, Class, underfull, overfull, undefined-reference, or undefined-citation warnings.
- Main bibliography: 37 entries.
- Appendix bibliography: 3 entries.

## Output files

- `paper_submission_clean.pdf`
- `paper_submission_clean.tex`
- `online_appendix_submission_clean.pdf`
- `online_appendix_submission_clean.tex`
- `references.bib`
- `CHANGELOG_submission_clean.md`

## Submission readiness

Ready for author read-through before submission.
