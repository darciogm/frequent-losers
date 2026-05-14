# Cover letter audit — JPubE submission requirements

Diagnostic of `manuscript/cover_letter.tex` against Elsevier / JPubE
expected components. JPubE follows the standard Elsevier submission
structure plus the AEA Data and Code Availability Policy adopted by
the journal in 2020.

Last reviewed: 2026-04-27.

---

## What the current cover letter has

| Component | Status | Notes |
|---|---|---|
| Sender block (name, affiliation, address) | ✅ | Lines 8-9 |
| Recipient (Editor, JPubE) | ✅ | Line 13 |
| Salutation ("Dear Editor") | ✅ | Line 15 |
| Manuscript title (italicized) | ✅ | Line 17 |
| Topic + contribution summary | ✅ | Para 2 (line 19) |
| Three-result enumeration | ✅ | Para 3 (line 21) — leads with R$55-128M |
| Why JPubE specifically | ✅ | Para 4 (line 23) — "public-economics contribution" |
| Magnitude bridge (DiD vs structural) | ✅ | Para 5 (line 25) |
| Manuscript scope (length, appendix) | ✅ | Para 6 (line 27) |
| Replication-code statement | ⚠️ partial | Para 6 — "upon acceptance" + SEFAZ-SP data agreement noted |
| No-parallel-submission declaration | ✅ | Para 7 (line 29) |
| Conflicts of interest declaration | ✅ | Para 7 |
| Suggested reviewers | ✅ | Para 8 (line 31) — Marion, Decarolis, Nakabayashi |
| Closing + signature | ✅ | Lines 33, 35 |

---

## What is missing or thin

### 1. Funding statement — MISSING

JPubE expects an explicit funding declaration even when none was received. Current letter has no such statement.

**Add:** "This research did not receive any specific grant from funding agencies in the public, commercial, or not-for-profit sectors." OR list any grants received.

**Where:** New paragraph between current paras 7 and 8 (before suggested reviewers).

### 2. Author CRediT statement — NOT NEEDED FOR SOLE-AUTHOR

JPubE follows the CRediT taxonomy for multi-author papers. For sole-author submissions, no CRediT statement is required. ✓ skip.

### 3. Data availability statement — THIN

Current letter says "Replication code, anonymized analytical sample, and data dictionary will be made available at the project repository upon acceptance; the underlying BEC microdata are available from SEFAZ-SP under a data-use agreement." This is OK but should be expanded to satisfy JPubE's adoption of the AEA Data and Code Availability Policy.

**Strengthen to:**

> *"In compliance with the AEA Data and Code Availability Policy adopted by JPubE, this paper is accompanied by a replication package containing all code (R) and processed datasets necessary to reproduce every table and figure in the manuscript and online appendix. The underlying BEC microdata are administrative records from SEFAZ-SP and are available to qualified researchers under a data-use agreement; access protocols are described in the package README. Pre-merged anonymized analytical samples are included in the package directly. The package is currently hosted on a private GitHub repository and will be made public upon acceptance, with persistent archival via Zenodo or the AEA Data Editor's openICPSR deposit at the journal's request."*

### 4. Use of AI tools statement — DEPENDS

JPubE/Elsevier in 2024-2025 added a requirement to disclose use of generative-AI tools in manuscript preparation (writing assistance, code generation). If you used Claude/ChatGPT/Codex for any non-trivial portion of writing or coding, you should declare it briefly.

**Suggested add (only if applicable):**

> *"Generative-AI tools were used in a supporting capacity for code review, LaTeX formatting, and copy-editing of prose; all substantive analysis, identification strategy, structural specification, and economic interpretation are the author's sole work. No AI-generated content was used to produce empirical results or to fabricate references."*

This is increasingly expected. Even if minimal use, declaring is safer than silence.

### 5. Excluded reviewers — OPTIONAL, recommend skipping

JPubE allows you to exclude up to 2 reviewers (typical reasons: prior conflict, competing work). For your case (junior solo author, no prior pubs, no competing work known), I'd skip this. Excluding looks defensive.

### 6. Highlights — SEPARATE FILE

Highlights (3-5 bullet points, max ~85 characters each) are uploaded separately, not in the cover letter. ✅ already exists at `manuscript/highlights.tex` / `highlights.pdf`.

### 7. Graphical abstract — OPTIONAL

JPubE allows but does not require a graphical abstract. For a structural paper with technical content, optional. Skip unless you want to invest the design effort.

---

## Recommended edits to `cover_letter.tex`

Add **two new paragraphs** before the suggested-reviewers paragraph (line 31):

```
This research did not receive any specific grant from funding agencies in the public, commercial, or not-for-profit sectors.

In compliance with the AEA Data and Code Availability Policy adopted by JPubE, the paper is accompanied by a replication package containing all R code and processed datasets necessary to reproduce every table and figure in the manuscript and online appendix. The underlying BEC microdata are administrative records from SEFAZ-SP and are available to qualified researchers under a data-use agreement; access protocols and software requirements are documented in the package README. Pre-merged anonymized analytical samples are included directly. The package will be archived on Zenodo or deposited at openICPSR upon acceptance, per the journal's protocol.
```

If you used AI tools in any part of the prep:

```
Generative-AI tools were used in a supporting capacity for code review, LaTeX formatting, and copy-editing of prose; all substantive analysis, identification strategy, structural specification, and economic interpretation are the author's sole work.
```

---

## Verdict

The cover letter is **80% complete**. Three additions bring it to 100%:
1. Funding statement (1 line)
2. Expanded data-availability statement (1 paragraph)
3. AI-tools disclosure (1 line, if applicable)

These are formality items, not strategic. Adding them eliminates a desk-reject pathway via "incomplete submission" without affecting the substantive case for R&R.

Want me to apply these three edits to `cover_letter.tex` directly?
