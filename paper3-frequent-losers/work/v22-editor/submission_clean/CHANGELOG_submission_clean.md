# Submission-clean change log

## Critical cleanup

- Created a self-contained submission package under `submission_clean/`.
- Removed internal version markers from the submission files and generated auxiliary files.
- Removed draft-only wording, including internal design labels.
- Fixed the appendix-reference pattern so compiled text does not produce "Appendix Appendix".
- Rebuilt Figure 1 with "Bid layer (forensic-recoverable)".
- Rebuilt Figure 2 with "Temporal holdout: training-window expansion test".
- Resolved the Table 3 placeholder by replacing the internal-design cell with a submission-facing pointer to the exposure-adjusted audit.

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

## Forensic audit pass (2026-05-25)

Full referee-grade audit of the compiled submission. Result: clean compile
(zero undefined references or citations after building the appendix before the
paper), no overclaiming language, and all 39 `\cite` keys resolve to real,
defined bibliography entries (39 cited = 39 defined, 1:1). The following
corrections were applied.

### Imhof complementarity (B2): same-sample increment reconciled

- The Table 7 levels (Imhof full 0.888, FL flag 0.921; raw gap 0.033) are on
  the 16,779-firm cross-validation pool, but the DeLong incremental test in the
  text reports +0.035 (p = 0.014), which is computed on the stricter
  same-sample subset of firms with complete bid-layer features (N = 11,676;
  Imhof 0.846, FL 0.881). DeLong requires paired observations, so the two
  differ.
- Added a `tablenotes` footnote to Table 7 making this explicit, so the +0.035
  reconciles with the displayed 0.033 gap. No estimate changed.

### Macro-binding of hardcoded numbers

Numbers that appeared as literals in prose/table cells were bound to their
registry macros (values unchanged; rendering identical), restoring the
macro-bound discipline and traceability:

- Abstract and introduction: "131 of 193" -> `\valGateSeqKTwoKOneTPIn` /
  `\valCobidders`; "83%" -> new `\valGateFootprintPct`.
- Section 4: sham price "+0.064 / +0.144" -> `\valShamPriceObs` /
  `\valShamPriceMean`; D4 figures "14.9% / 0.261 / 0.086" ->
  `\valDirectShareAL` / `\valDirectMedWR` / `\valOthersMedWR`.
- Section 7: "41%" -> `\valPctFortyone`; the across-cell selection rows
  (+22.65 / SE 0.03 and +24.04 / SE 0.56) -> new `\valSelTestCoefRaw`,
  `\valSelTestSERaw`, `\valSelTestCoefFE`, `\valSelTestSEFE`, verified against
  `output/selection_mechanism/selection_test_results.csv`.

### Rendering fix

- `\valImhofIncCombo` used `--` inside math mode, which rendered as two minus
  signs ("+0.096 - - +0.098") in Section 6.2. Redefined with `\text{ to }` so
  it renders "+0.096 to +0.098".

### D1 horse-race re-run (gate diagnostic)

- Re-ran gate diagnostic D1 (script 36, Part A) with the corrected
  frequent-loser cut `tenders_count >= 14` (the pre-fix code used `> 14`, which
  silently computed FL15 numbers). Result confirms the gate **PASS**: continuous
  log-participation AUC 0.939 [0.932, 0.946] dominates the binary FL14 AUC 0.924
  [0.921, 0.926]; DeLong Z = -4.38, p = 1.2e-05; price-coefficient sign
  preserved. Sample sanity: 16,843 always-losers, 2,735 FL14 firms, 193
  cobidders.
- Corrected the residual FL15-bug macros in the registry: `\valHorseAUCBin` and
  `\valAUCFLBinSameSample` 0.911 -> 0.924 (CI -> [0.921, 0.926]); `\valDeLongZ`
  -4.30 -> -4.38; `\valDeLongP` 2e-05 -> 1.2e-05. All five were unused in the
  prose of both the paper and the appendix, so no compiled output changed; the
  fix is registry hygiene. `output/gate_d1/d1_auc.csv` refreshed.
- Note: the DeLong p moved 1.7e-05 -> 1.2e-05 (slightly tighter) even though the
  AUC gap shrank from 0.028 to 0.015, because DeLong is a covariance-paired test
  on the same firms; the gap alone does not determine significance.

### Build and pipeline notes (for maintainers)

- Build order matters: compile `online_appendix_submission_clean` (with bibtex)
  before `paper_submission_clean`, otherwise the body's `xr`/`\externaldocument`
  cross-references to appendix labels render undefined.
- `values.tex` is hand-maintained for this submission. The generator
  `scripts/99_make_paper_values.R` writes to the stale `work/v13/values.tex`
  (diverged by ~147 macros, still carries the pre-fix convite 0.824 and lacks
  ~151 submission macros). Do not re-run it to refresh the submission; add
  macros directly to `submission_clean/values.tex` with `% src:` provenance
  comments.

## Submission readiness

Ready for author read-through before submission. The 2026-05-25 forensic pass
cleared the two blockers (stale final PDF refreshed; Imhof same-sample
increment reconciled) and bound the remaining prose/table literals to macros.
