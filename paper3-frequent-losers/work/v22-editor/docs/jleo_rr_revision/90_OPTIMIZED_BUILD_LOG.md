# 90 — OPTIMIZED BUILD LOG (JLEO final optimization, 2026-06-04)

## Commands run (chronological, condensed)

```
Rscript scripts/analysis/00_build_canonical_validation_targets.R        # 1.6 s, T1–T10 pass
# label swap in scripts 02–11 (3 parallel edit agents) + lead rewrite of 01
for f in 01 02 03 04 05 06 11; Rscript scripts/analysis/$f_*.R          # regen_nonbid_chain.log, all rc=0
for f in 07 08 09 10;          Rscript scripts/analysis/$f_*.R          # regen_bid_chain.log, all rc=0
Rscript scripts/analysis/55_adversarial_adaptation_canonical.R          # values_adversarial.tex regenerated
# concordance + diagnostics CSV generators (inline R)
# manuscript fan-out: 7 agents + lead sec04 rewrite + lead values.tex Prof-block rebind
# fix: sed 's/Appendix~\\ref{app:/\\ref{app:/g' (17+6 "Appendix Appendix" hits → 0)
pdflatex/bibtex ×3 passes each: online_appendix_{jleo,clean} then paper_{jleo,clean}
Rscript scripts/diagnostics/scan_claims.R
```

## Build status

| Document | Errors | Undefined refs | Pages |
|---|---|---|---|
| paper_jleo_submission.pdf | **0** | **0** | 52 (double-spaced JLEO format) |
| online_appendix_jleo_submission.pdf | **0** | **0** | 46 |
| paper_submission_clean.pdf | 0 | 0 | 39 (single-spaced working) |
| online_appendix_submission_clean.pdf | 0 | 0 | 32 |

- Abstract: **137 words** (agent count; pdftotext segment ≈142 incl. header) — under the 150 cap.
- Main tables ≤6; main figures ≤3 (structure unchanged from Subprompt 13 compression).
- Main target count: **651** (broad always-loser cobidders; 341 FL / 310 non-FL).
- Positive-count concordance: `tab:positive_count_concordance` embedded in Appendix A; main-text
  note in §4.1 points to it.
- xr note: paper preamble reads `online_appendix_submission_clean.aux` — the clean appendix MUST
  be compiled before the paper (already the documented build order).

## Scans

- `optimized_pdf_text_scan.csv`: archived / not reproduced / frequent-loser only /
  cade_fl_cobidders / Appendix Appendix / cartel-adjacent / cartel detector / legal membership
  anchors / 83% / 131 of 193 / optimal cutoff / operationally useful / Subprompt / TODO / FIXME
  → **0 hits** in both compiled PDFs. damages/overcharge/membership hits are negated boundary
  statements only.
- `optimized_claims_scan.csv`: **critical = 0**; 14 "high" all false positives
  (substring "improves"→"proves"; negated damages/membership boundaries).
- `optimized_number_consistency.csv`: 23 headline numbers ↔ regenerated CSV sources ↔ values.tex
  macros, all consistent.
- `optimized_target_assertions.csv`: builder T1–T10 + manuscript M1–M4, all pass.
- Dead numbers in PDFs: 0.946 / 0.7715 / 0.0415 / 0.921 / 0.888 / 0.962 / 0.939 / 0.924 → **0 hits**.
- References: no new citations added; `clark2021collusion` already removed at `132e274`; bibtex
  ran clean (no missing-entry warnings in .blg beyond pre-existing style notices).

## Remaining high-risk terms

None found in compiled text. Stale macros in values.tex are annotated `% STALE — do not cite`
and verified uncited in any sec file.
