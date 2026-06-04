# 55 — JLEO Compliance Audit (Final Submission)

**Paper:** *Cheap Signals, Costly Proof: The Reach and Limits of Award-Layer Screening in Cartel Enforcement* — Darcio Genicolo-Martins & Paulo Furquim de Azevedo (INSPER)
**Target:** JLEO R&R, branch `v22`. **Auditor mode:** read-only compliance.
**Source root:** `work/v22-editor/submission_clean/` (master `paper_submission_clean.tex`) + `online_appendix_submission_clean.tex`.
**PDFs audited:** `paper_submission_clean.pdf` (39pp) · `online_appendix_submission_clean.pdf` (31pp), built 2026-06-03.
**Reference rules:** JLEO official instructions as verified in doc `54_JLEO_OFFICIAL_INSTRUCTIONS_VERIFICATION.md` (Editorial Express; PDF/Word/RTF; $100 fee; double-spaced + 1.25in margins; abstract ≤150w; JEL required; Chicago 15th; exclusive submission; data within 3yr or proprietary exemption).

Severity scale: low / medium / high / fatal. Status: pass / fail / n.a. / blocked / needs-human.

---

## A. Submission platform / files

| # | Item | Status | Evidence | Action | Severity |
|---|------|--------|----------|--------|----------|
| A1 | Submitted via Editorial Express | needs-human | Cannot verify from repo; platform action is external. | Confirm upload to JLEO Editorial Express at submission. | low |
| A2 | Accepted file format (PDF) | pass | Two compiled PDFs present and well-formed (`pdfinfo` Pages 39/31, no encryption, Form none). | None. | — |
| A3 | Single master compiles cleanly | pass | `paper_submission_clean.log` / appendix `.log` show no `Undefined`, no fatal errors; `.bbl` populated. | None. | — |
| A4 | Cross-reference between paper and appendix (`xr`) resolves | pass | `\usepackage{xr}` line 33; no `??` in `/tmp/paper.txt` or appendix text (grep count 0/0). | None. | — |

## B. Exclusivity / fee

| # | Item | Status | Evidence | Action | Severity |
|---|------|--------|----------|--------|----------|
| B1 | Exclusive (not under review elsewhere) | needs-human | Authorial declaration, not in repo. | State exclusivity in cover letter / Editorial Express form. | medium |
| B2 | $100 submission fee | needs-human | Payment is external. | Pay at submission. | low |

## C. Front matter

Source: `sec_frontmatter_submission.tex`.

| # | Item | Status | Evidence | Action | Severity |
|---|------|--------|----------|--------|----------|
| C1 | Title present, capitalized | pass | `\title{Cheap Signals, Costly Proof: The Reach and Limits of Award-Layer Screening in Cartel Enforcement}`; title case consistent. | None. | — |
| C2 | Abstract ≤150 words | **pass** | Computed word count = **146** (macros `\valYearStart/\valYearEnd` counted as 1 each → conservative). | None. | — |
| C3 | Keywords present | pass | "Keywords: cartel screening, public procurement, award-layer data, enforcement triage, incomplete observability, bid rigging." | None. | — |
| C4 | JEL codes present (required) | pass | "JEL No.: D44, D73, H57, K21, L41" — matches known state. | None. | — |
| C5 | Abstract free of "cartel detector" | pass | grep: absent. | None. | — |
| C6 | Abstract free of "proof from award records" / proof-claim | pass (boundary) | Abstract uses "proof" only as the thesis object: "costly proof-producing effort / before legal proof exists" and closes "Liability remains in the richer bid-level record." This is disciplined (proof is what the screen does NOT supply), not a claim. | None. | — |
| C7 | Abstract free of "damages" / "overcharge" | pass | grep: absent in abstract. | None. | — |
| C8 | Corresponding author + affiliation | pass | Corresponding author tagged (`\corref`); affiliation INSPER, São Paulo, Brazil. | None. | — |

## D. Main formatting

Source: `paper_submission_clean.tex`.

| # | Item | Status | Evidence | Action | Severity |
|---|------|--------|----------|--------|----------|
| D1 | Double-spaced | **fail** | `\renewcommand{\baselinestretch}{1.48}` (line 84). 1.48 ≈ generous 1.5-spacing, NOT JLEO-required double (2.0). | Build a double-spaced review version (`\baselinestretch{1.66}`–`2.0` or `\doublespacing`) before final upload. | **high** |
| D2 | 1.25in margins | **fail** | `\usepackage[left=28mm,right=30mm,top=28mm,bottom=28mm]{geometry}` (line 10). 28–30 mm ≈ 1.10–1.18in, below JLEO's 1.25in (31.75mm). | Set all margins to ≥1.25in for the review build. | **high** |
| D3 | Page numbers | pass | `fancyhdr` + `\def\@oddfoot{\centerline{\thepage}}` (line 65). | None. | — |
| D4 | Numbered headings | pass | No `\section*` in body files (`sec0*.tex`); all sections numbered. | None. | — |
| D5 | Equation numbering | pass | 5 numbered `equation`/`align` environments across body+appendix. | None. | — |
| D6 | Footnotes present and well-formed | pass | Title footnote (acknowledgments) + section footnotes render; no orphaned `\footnote{}`. | None. | — |
| D7 | 12pt base font | pass | `\documentclass[12pt,authoryear]{elsarticle}`. | None. | — |

**Note on D1/D2:** Both were flagged in the task brief as expected FAILs needing a double-spaced build. They are formatting-only and do not affect content; remediation is a one-line change each plus recompile. They are blocking for a *clean* JLEO upload but trivial to fix.

## E. Tables / figures

| # | Item | Status | Evidence | Action | Severity |
|---|------|--------|----------|--------|----------|
| E1 | ≤6 main tables | pass | Exactly **6**: T1 *Data Layers, Populations…* (sec02); T2 *Label-Construction Funnel…*, T3 *Opportunity-Adjusted Validation…*, T4 *Timing and Case-Composition Synthesis* (sec04); T5 *Bid-Layer Benchmark…*, T6 *Cost-Recall Frontier…* (sec06). | None. | — |
| E2 | ≤3 main figures | pass | Exactly **3**: F1 `fig_data_coarsening` (sec02), F2 `fig_observed_vs_expected_contact_bins` (sec04), F3 `fig_3_cost_recall_frontier` (sec06). | None. | — |
| E3 | All tables/figures cited | pass | All 3 figure labels resolve via `\ref` in their own sections; no `??`; no "LaTeX Warning: Reference … undefined". | None. | — |
| E4 | Notes define unit / sample / target / metrics | pass | T1 note defines legal-vs-screening categories; T2 note defines funnel + benchmark cobidder; T3/T4 notes define opportunity cells + PR/ROC + timing; T5 note: "Evaluation pool: 16,772 always-loser firms…positives are 190 CADE-cobidders…target is adjudication-anchored exposure"; T6 note defines firm/tender-item/bid-row denominators. | None. | — |
| E5 | Alt text on main figures | pass | All three carry explicit "Alt text:" prose (F1 sec02 l.~127; F2 sec04 inside caption; F3 sec06 l.~388). | None. | — |
| E6 | F1 free of "Bid layer (lost)" / "Award layer (survives)" / stale AUC | pass | F1 caption: "information-cost diagram, not a detector horse race"; no lost/survives labels, no AUC. Underlying `fig_data_coarsening.pdf`: pdftotext grep for "Bid layer/Award layer/lost/survives/AUC/Cartel-Adjacency" → 0 hits. | None. | — |
| E7 | Appendix float budget | pass | Appendix carries 11 tables + 2 figures (A–F lettered) — matches known state and is in the online appendix, not main. | None. | — |

## F. References / citations

| # | Item | Status | Evidence | Action | Severity |
|---|------|--------|----------|--------|----------|
| F1 | All citation keys resolve | pass | No "Citation … undefined" in either `.log`; `.bbl` populated (9.7KB). | None. | — |
| F2 | No `[VERIFY]` / placeholder refs | pass | grep VERIFY/XXXX/placeholder/??? on `references.bib` + `paper_submission_clean.bbl` → 0. | None. | — |
| F3 | Author-date consistency | pass | `elsarticle[authoryear]` + `\biboptions{authoryear}` + `\bibliographystyle{chicago}`. Rendered cites are author-year (e.g., "Imhof et al., 2018", "Wallimann et al., 2023"). | None. | — |
| F4 | Chicago 15th style | pass | `\bibliographystyle{chicago}`. | None. | — |
| F5 | References begin after main text | pass | "References" heading on PDF page 36 (main text pp. 1–35). | None. | — |

## G. Claims discipline

| # | Item | Status | Evidence | Action | Severity |
|---|------|--------|----------|--------|----------|
| G1 | "Forensic priority" not "proof" | pass | Body uses "ranking for forensic priority, not proof of conduct"; "validate forensic priority, not membership, damages, or proof." | None. | — |
| G2 | Cobidders = "adjudication-anchored exposure", not membership | pass | Repeated verbatim across sec01/03/04/06/08: "adjudication-anchored exposure, not cartel membership." | None. | — |
| G3 | Price = scope, not damages/overcharge | pass | sec07: "not a damages estimate, an overcharge, a cartel markup, a causal price effect…"; "scope facts…not damages or overcharge." | None. | — |
| G4 | Cost-recall = operating frontier, not optimal cutoff | pass | sec06: "The frontier, not a cutoff"; "K1 = 2,000 is one operating point, not a calibrated optimum." | None. | — |

## H. Data / code / replication

Source: `work/v22-editor/replication/`.

| # | Item | Status | Evidence | Action | Severity |
|---|------|--------|----------|--------|----------|
| H1 | README present | pass | `README.md` (10.7KB) — pipeline, software, data, repro map, runtime, seeds, limitations. | None. | — |
| H2 | SCRIPT_ORDER present | pass | `SCRIPT_ORDER.md` (dependency-ordered run list). | None. | — |
| H3 | OUTPUTS_MAP present | pass | `OUTPUTS_MAP.csv` (output → script → input → manuscript float). | None. | — |
| H4 | DATA_CONFIDENTIALITY present | pass | `DATA_CONFIDENTIALITY.md` — "We do not claim the BEC procurement microdata are public"; access-request path; aligns with JLEO proprietary-data exemption. | None. | — |
| H5 | MANIFEST present | pass | `MANIFEST.csv` (file → type → status, "present"). | None. | — |
| H6 | Seeds documented | pass | README §7 "Runtime categories & seeds": deterministic seeds `20260430`, `20260501`, `20260530`; per-script seeds tagged in MANIFEST/OUTPUTS_MAP. | None. | — |
| H7 | Outputs traceable to scripts | pass | OUTPUTS_MAP rows tie each table/figure to script + input parquet + manuscript location. | None. | — |
| H8 | Data within 3yr OR proprietary exemption | pass (exemption) | BEC microdata proprietary; DATA_CONFIDENTIALITY claims exemption + access path, satisfying JLEO's proprietary route. | Cite exemption in cover letter. | low |

## I. Ethics / conflicts / funding / permissions

| # | Item | Status | Evidence | Action | Severity |
|---|------|--------|----------|--------|----------|
| I1 | Conflict-of-interest statement | needs-human (HUMAN_DECISION) | Not located in manuscript/repo. | Add COI declaration to Editorial Express / cover letter. | medium |
| I2 | Funding statement | needs-human (HUMAN_DECISION) | No funding/grant acknowledgment beyond INSPER seminar thanks. | Confirm whether any funding must be disclosed. | medium |
| I3 | Data-use permissions (CADE / BEC) | needs-human (HUMAN_DECISION) | DATA_CONFIDENTIALITY describes access but not a formal data-use permission/IRB statement. | Confirm BEC/CADE data-use terms permit publication. | medium |
| I4 | Human-subjects / ethics approval | n.a. | Administrative procurement + adjudication records; no human subjects. | None. | — |

---

## Compliance summary

| Status | Count |
|--------|-------|
| pass | 30 |
| fail | 2 (D1 double-spacing, D2 margins) |
| needs-human / HUMAN_DECISION | 8 (A1, B1, B2, H8-followup, I1, I2, I3 + A1 platform) |
| n.a. | 1 (I4) |
| blocked | 0 |

**Fatal items: 0.**

**Blocking-for-clean-upload (high, non-fatal): 2** — D1 (1.48 → double spacing) and D2 (28–30mm → ≥1.25in margins). Both are one-line LaTeX changes + recompile; content unaffected. These were flagged in advance as the expected formatting FAILs.

**Needs-human before submit:** exclusivity declaration (B1), $100 fee (B2), COI (I1), funding (I2), data-use permission (I3), and external platform/upload confirmation (A1). These are decisions/actions the authors must take — not invented here.

**Headline verdict:** No fatal compliance defects. Manuscript is content-compliant; the only hard blockers are the double-spacing and margin builds (trivial). Proceed after the double-spaced/1.25in build and the human declarations.
