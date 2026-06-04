# 92 — FINAL TARGETED REPAIR LOG (2026-06-04)

**Mode:** Mr. Frequent Losers, FINAL TARGETED REPAIR MODE · **Branch:** `v22` (HEAD `00c9276` at
start; dedicated revision branch, no new branch created — same rationale as log 86).
**Precondition:** the canonical-target repair (logs 86–91, commits `9cf5f16`/`ad20700`/`00c9276`)
already executed the substantive replacement (651 target, regeneration, reframing, hygiene).
This pass = verification sweep + the genuinely open items: cover letters, submission_jleo
package refresh, named scan CSVs, visual checklist, final verdict.

## Session log

### Step 1 — safety
- pwd = work/v22-editor; branch v22; tree clean for v22-editor paths (other-paper files dirty
  in monorepo, untouched). Proceeding on `v22`.

### Step 2 — final submission files (also in 93_FINAL_REPAIR_FILE_INVENTORY.md)
- Manuscript source: `submission_clean/paper_jleo_submission.tex` (+ sec01–sec99, frontmatter)
- Appendix source: `submission_clean/online_appendix_jleo_submission.tex` (+ sec_app00–09)
- Final PDFs: `submission_clean/paper_jleo_submission.pdf` (52pp), `online_appendix_jleo_submission.pdf` (47pp)
- Cover letters: `submission_jleo/cover_letter/{cover_letter_jleo.md, cover_letter_jleo_short.md}`
  + `submission_clean/cover_letter_JLEO_submission.md` (+ stale PDF in package)
- Package: `submission_jleo/{manuscript,appendix,cover_letter,admin,online_supplement,replication,figures_source}`
  — manuscript/appendix PDFs predate the canonical repair → REFRESH REQUIRED
- Table/figure generators: `scripts/analysis/00–11 + 55-canonical`, `make_submission_figures.R`
- Build: pdflatex×3+bibtex, **clean appendix before paper** (xr reads `online_appendix_submission_clean.aux`)

### Step 3/6/13/14 — scans (fan-out agent; CSVs in outputs/diagnostics/)
### Step 15 — cover letters (fan-out agent; notes in 94)
### Step 17 — visual checklist (fan-out agent; 95)
### Steps 4–5, 16, 18–20 — lead (assertions CSV, rebuild, package refresh, 96, verdict)

(Agent results appended to 96.)
