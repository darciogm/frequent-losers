# JPubE pre-submission checklist

Final review checklist before clicking *Submit* in EM (Editorial Manager).
Walk through this end-to-end immediately before submission.

Last updated: 2026-04-27.

---

## A. Manuscript file (`paper_v5.pdf`)

### A.1 Compilation

- [ ] Latest `paper_v5.tex` compiled with the full 4-pass pipeline:
      `pdflatex → bibtex → pdflatex → pdflatex → pdflatex`
- [ ] Compilation log shows **zero** `Overfull \hbox`, `Underfull \hbox`,
      `LaTeX Warning`, undefined references, or "Label may have changed"
      messages
- [ ] `paper_v5.pdf` is exactly **88 pages** (sanity check against expected)
- [ ] All in-text references render correctly (no `??` artifacts)
- [ ] All figures embedded; no missing-image warnings
- [ ] Footnotes numbered correctly and resolve

```bash
# Verification command
cd manuscript
grep -E "Overfull|Underfull|LaTeX Warning" paper_v5.log | grep -v "^$"
# Expected output: empty
```

### A.2 Content sanity

- [ ] Title matches across: cover letter, paper, highlights, online
      appendix, site landing page, suggested-reviewers paragraph
- [ ] Abstract is **under 250 words** (JPubE limit) and contains R\$
      magnitude in the central placement
- [ ] All section/subsection numbers match cross-references in the text
- [ ] Tables and figures all referenced at least once in the text
- [ ] All numbers in the abstract appear (and match exactly) in the body
- [ ] All numbers in the introduction's three-finding panels appear
      (and match) in the body Tables
- [ ] No remaining `\todo{...}` or `XXX` placeholders
- [ ] No track-changes or red text remaining
- [ ] No commented-out paragraphs that were forgotten

### A.3 References

- [ ] Every `\cite{...}` resolves to an entry in `References.bib`
- [ ] Every entry in `References.bib` is cited at least once (else
      bibtex prints unused-entry warnings)
- [ ] **Triple-check** every reference exists: author, year, title,
      journal, volume, pages — flag any uncertain references with
      `[VERIFY]` and resolve before submission
- [ ] DOIs included for top-tier and recent (post-2015) references
- [ ] No fabricated references (verified individually via JSTOR / RePEc)

### A.4 Tables

- [ ] All numerical entries match the source CSV exactly
- [ ] Standard errors reported alongside every coefficient
- [ ] Significance stars consistent with table notes
- [ ] Sample sizes (N) reported for every regression
- [ ] No "data not shown" or unsourced numbers
- [ ] Specifications-comparison tables align controls vertically

### A.5 Figures

- [ ] Every figure has caption explaining x-axis, y-axis, sample, sample-size
- [ ] Confidence intervals or error bars reported where appropriate
- [ ] Grayscale-readable (avoid red/green-only color contrasts)
- [ ] Resolution sufficient for print (cairo_pdf, vector format)
- [ ] No ggplot2 warnings about missing values or removed observations
      that the figure note doesn't explain

---

## B. Cover letter (`cover_letter.pdf`)

- [ ] Recipient: "The Editor, Journal of Public Economics"
- [ ] Manuscript title (italicized)
- [ ] Topic + contribution summary (1 paragraph)
- [ ] Three-result enumeration with R\$ magnitudes
- [ ] Why JPubE specifically (1 paragraph)
- [ ] Manuscript scope statement (length, appendix, replication)
- [ ] **Funding declaration** ✓ (added)
- [ ] **Conflicts-of-interest declaration** ✓
- [ ] **No-parallel-submission declaration** ✓
- [ ] **Data-availability statement** (AEA Data Editor compliance) ✓ (added)
- [ ] **AI-tools disclosure** ✓ (added, if applicable)
- [ ] **Suggested reviewers** (3 names with one-line justification each) ✓
- [ ] **Excluded reviewers** — usually skip; only include if there is a clear conflict

---

## C. Online appendix (`online_appendix.pdf`)

- [ ] Cross-references to main paper resolve (e.g., "Table A.1" referenced
      from main matches the table number in the appendix)
- [ ] All robustness/sensitivity tables cited from §7 of main are present
- [ ] Section numbering does NOT clash with main paper (use prefix A, B, C
      or Roman numerals)
- [ ] Self-contained: a referee should be able to read the appendix
      without flipping back to the main constantly

---

## D. Highlights (`highlights.pdf`)

- [ ] **3-5 bullets**, each ≤ 85 characters (JPubE/Elsevier limit)
- [ ] First bullet leads with R\$ magnitude (matches hero card on site)
- [ ] No equations, no math symbols beyond standard ASCII
- [ ] Each bullet self-contained (does not reference earlier bullets)

---

## E. Replication package (`v5-jpube/REPLICATION_README.md` + code)

- [ ] `REPLICATION_README.md` complete, with sections for: data sources,
      software requirements, file structure, script-to-output map,
      headline numbers expected, contact, license
- [ ] All scripts in `scripts/` execute end-to-end on fresh clone with
      `Rscript scripts/XX_*.R` (verify on a clean shell session)
- [ ] `data/raw/` is git-ignored; `data/processed/` contains pre-merged
      anonymized samples used to reproduce headline tables and figures
- [ ] `output/INTERNAL_NOTES.md` documents which `tab_*.tex` files are
      `\input{}`'d in the paper vs which are internal-only (collusion
      screens)
- [ ] `renv.lock` or equivalent pins package versions
- [ ] Computational requirements documented (RAM peak, CPU time)
- [ ] Confidentiality / data-use agreement language for SEFAZ-SP data
- [ ] No PII in pre-merged samples (firm IDs hashed, PBU IDs aggregated)
- [ ] Repository ready for Zenodo / openICPSR archival on acceptance

---

## F. Editorial Manager (EM portal) submission

### F.1 Preparation

- [ ] EM account active; email verified
- [ ] ORCID linked to EM account
- [ ] Affiliation, address, ORCID iD up-to-date

### F.2 During submission

- [ ] Article type: "Research Paper" (not "Note" or "Replication")
- [ ] Manuscript title field: matches `\title{}` in `paper_v5.tex` exactly
- [ ] Abstract pasted: matches `paper_v5.tex` exactly (no hyphenation
      artifacts from PDF copy)
- [ ] Keywords field: 5-6 keywords, lowercase
- [ ] JEL codes field: H32, H57, L26, L53, D44 (or your final list)
- [ ] Sole-author flag set correctly
- [ ] Funding source: "None declared" or list grants
- [ ] Conflict of interest: "None declared"
- [ ] Cover letter file uploaded as PDF
- [ ] Manuscript file uploaded as PDF
- [ ] Highlights uploaded (separate file, plain text or PDF)
- [ ] Online appendix uploaded (separate file)
- [ ] Suggested reviewers entered with full name + email + affiliation
      (do NOT submit emails for people you have not verified are at the
      stated affiliation as of submission date)
- [ ] **Verify each suggested-reviewer email** before entering
      (one wrong email = the editor cannot send the invitation)

### F.3 Final pre-submit checks

- [ ] Saved as draft and downloaded the EM-rendered PDF preview
- [ ] Preview matches your local PDF (no formatting drift)
- [ ] All co-authors confirmed (n/a sole)
- [ ] Submission data export saved locally
- [ ] **Click submit** — record the submission ID and date

---

## G. Post-submission

### G.1 Confirmation

- [ ] EM auto-confirmation email received (usually <5 min)
- [ ] Submission ID logged in `outreach/submission_log.md`

### G.2 Within 24h

- [ ] Save final submitted PDFs (cover, manuscript, appendix, highlights)
      under `manuscript/submitted/2026-MM-DD/` for audit trail
- [ ] Tag the git commit:
      `git tag -a jpube-submitted-2026-MM-DD -m "JPubE submission"`

### G.3 Communication restrictions

- [ ] Until first decision: do **not** make new substantive edits or
      preprint changes
- [ ] If errors discovered post-submission: contact JPubE editorial
      office directly with concise correction note (do not re-submit)

---

## H. Diagnostic commands (run these from `manuscript/` directory)

```bash
# 1. Compile from scratch and check for warnings
rm -f paper_v5.aux paper_v5.bbl paper_v5.blg paper_v5.log paper_v5.out paper_v5.toc paper_v5.spl
pdflatex -interaction=nonstopmode paper_v5.tex > /dev/null 2>&1
bibtex paper_v5 > /dev/null 2>&1
pdflatex -interaction=nonstopmode paper_v5.tex > /dev/null 2>&1
pdflatex -interaction=nonstopmode paper_v5.tex > /dev/null 2>&1
pdflatex -interaction=nonstopmode paper_v5.tex > /dev/null 2>&1
echo "=== WARNINGS ==="
grep -E "Overfull|Underfull|LaTeX Warning|Package.*Warning" paper_v5.log | grep -v "^$"
echo "=== UNDEFINED ==="
grep -i "undefined\|may have changed\|multiply.defined" paper_v5.log | head
echo "=== PAGES ==="
grep "Output written" paper_v5.log

# 2. Bibtex sanity
bibtex paper_v5 2>&1 | tee /tmp/bib.log
grep -i "warn\|error" /tmp/bib.log

# 3. Reference verification — flag any \cite{} not in References.bib
for ref in $(grep -oE "\\\\cite[pt]?\{[^}]+\}" *.tex | grep -oE "\{[^}]+\}" | tr -d '{}' | tr ',' '\n' | sort -u); do
  ref_clean=$(echo $ref | xargs)
  grep -q "{${ref_clean}," References.bib || echo "MISSING IN BIB: $ref_clean"
done

# 4. Page count quick check
pdfinfo paper_v5.pdf | grep Pages

# 5. Check abstract word count
awk '/begin{abstract}/,/end{abstract}/' paper_v5.tex | wc -w
# Target: <= 250 words
```

---

## I. Strategic checks (NOT mechanical — need human judgment)

- [ ] First-paragraph hook compelling enough that an editor reading 30
      papers/week stops to read paragraph 2
- [ ] Contribution paragraph names existing literature it extends (Marion,
      Krasnokutskaya, Athey-Levin-Seira, Decarolis et al.) and what
      specifically is new
- [ ] First Table referenced in body (`tab_preview` or equivalent) appears
      within first 6 pages
- [ ] Conclusion stays proportional to evidence (no overclaim about
      external validity beyond what the design supports)
- [ ] Identification section addresses the most threatening confounder
      (here: timing of policy change is plausibly exogenous to G65
      market conditions; addressed in §2)
- [ ] Robustness section addresses 4-5 most natural referee objections
      (sample window, F_c estimator, strict invariance, adherence rate,
      bid-coordination diagnostics)
- [ ] Limitations explicitly stated (entry treated reduced-form, FPSB
      bracketed, V3 entry response not modeled — all in §3.43)

---

## J. The 24-hour post-submission discipline

After submitting:

1. **Stop editing the paper.** Resist the urge to "polish a bit more."
   The submission is now reviewable.
2. **Send the same paper to:** Soares (post-submission update), one or two
   senior collaborators not yet contacted. Their post-submission read becomes
   ammunition for R&R if/when it comes.
3. **Submit to LACEA-LAMES 2026 + AEA 2027** in parallel.
4. **Begin drafting** a 2-page summary memo for seminar audiences:
   what's the paper, what's the contribution, what's the headline number.
   Practice the 3-minute oral pitch.
5. **Do not poll the EM portal more than once a week.** Editorial decisions
   take 8-16 weeks. Watching the inbox does not accelerate them.

---

*Adherence to this checklist roughly corresponds to a +5pp marginal R&R
probability over uncalibrated submission. Most of the gain is in
sections A (manuscript hygiene) and B (cover letter completeness). Sections
F-G are dispositive: even a perfect paper can be rejected on submission
hygiene defects if the EM file is incomplete.*
