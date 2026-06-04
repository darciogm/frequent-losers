# 95 — Final Visual Repair Checklist (Step 17)

Visual inspection of the two submission PDFs, page by page (Read tool, ≤20 pp/call).

- `paper_jleo_submission.pdf` — 52 pp, double-spaced JLEO format
- `online_appendix_jleo_submission.pdf` — 47 pp

Recorded as PASS / FAIL / NOTE with page numbers and what was seen.

---

## SUMMARY VERDICT: **VISUAL_ISSUES**

Most of the checklist passes cleanly. The PDFs are legible, no `??` unresolved refs,
no "Appendix Appendix", no table spilling off the margin, no duplicated "Alt text:"
blocks, no leftover internal/workflow language, no AUC literal in Figure 1. Figure 1
labels and caption match the information-cost vocabulary exactly. Tables 1–6 all
present and correct.

Two issues found, one a genuine **layout/numbering bug that text micro-edits will NOT
fix** and one a **text-level title inconsistency**. Both are flagged below and broken
out in the dedicated sections at the end.

---

## MAIN MANUSCRIPT

### Title / abstract page — **PASS** (p. 1)
- Title reads exactly: "Cheap Signals, Costly Proof: The Reach and Limits of
  Award-Layer Screening in Cartel Enforcement". CORRECT.
- Abstract present, single paragraph, ~140 words by count — plausibly ≤150. PASS.
- Authors Darcio Genicolo-Martins & Paulo Furquim de Azevedo, INSPER. Keywords + JEL
  (D44, D73, H57, K21, K42, L41) on p. 2. PASS.

### Figure 1 — **PASS** (p. 12)
- Column headers: "Costly recovered bid record" (left) and "Routine award record"
  (right). Footer labels: "Bid-distribution forensics (requires recovered bid record)"
  and "Award-layer triage score (routine record only)". All four information-cost
  vocabulary terms present. PASS.
- Caption opens: "This is an information-cost diagram, not a detector horse race."
  Explicitly an information-cost diagram. PASS.
- NO AUC literal anywhere in figure or caption. PASS.
- Single Alt-text block, not duplicated. PASS.

### Table 2 — Label funnel — **PASS** (p. 20)
- Title "Label-Construction Funnel and Benchmark Reconciliation". Three rows: Full CADE
  portfolio / Main validation target (651 AL cobid, role = primary) / Conservative
  pre-2020. Main target 651 present. PASS.
- No "static narrow" row. PASS.

### Table 3 — Opportunity-adjusted — **PASS** (p. 24)
- "Within-opportunity stratum" row: log_tc ROC-AUC 0.471 (≈ chance, ≈ 0.47). PASS.
- "Nested increment over exposure" row: +0.010, DeLong p = 0.013. Increment +0.010
  present. PASS.
- Notes legible; fits margin. PASS.

### Table 4 — Timing / case synthesis — **PASS** (p. 27)
- Title "Timing and Case-Composition Synthesis". Rows cover full-sample retrospective,
  strict full test universe, rankable incumbent, training pool, rolling-origin,
  leave-largest/two-out, clustered RI, direct-defendant scope. Legible, fits margin.
  PASS. (Dense but readable — see NOTE below.)

### Table 5 — Bid benchmark — **PASS** (p. 37)
- Title "Bid-Layer Benchmark and Award-Layer Screen: Ranking Performance". Pooled vs
  case-grouped vs excl-label blocks. Legible. PASS.

### Table 6 — Cost-recall frontier — **PASS** (p. 42)
- Title "Cost-Recall Frontier for Sequential Award→Bid Gatekeeping". Panels A (k=500)
  and B (k=1,000). Legible, fits margin. PASS.

### Cost-recall figure (Fig 3) — **PASS** (p. 43)
- "Cost-recall frontier: sequential gatekeeping vs full observability". Axis labels,
  legend, single Alt-text block. Caption frames it as operational trade-offs "not legal
  proof". PASS.

### Figure 2 — **PASS** (p. 24)
- "Observed vs expected defendant contact by score decile". Single Alt-text block.
  PASS.

### Section 7 (price) length — **PASS** (pp. 44–46)
- §7 "Scope, Limits, and Price Corroboration" runs ~2.5 pp incl. §7.1; price reported
  in prose with full regressions deferred to Appendix F. Short, as required. PASS.

### Conclusion — **PASS** (pp. 46–49)
- §8 Conclusion present, ends p. 49 just before References. Coherent. PASS.

### References — **PASS** (pp. 49–52)
- Alphabetical, complete entries (Abrantes-Metz … Wils). No "??", no missing/blank
  entries. All citations seen in text (Porter-Zona, Bajari-Ye, Imhof, Kawai-Nakabayashi,
  Chassang, Sánchez Graells, Becker, Stigler, etc.) have matching reference entries.
  No fabricated `clark2021collusion` (removed per recent commit). PASS.

---

## ONLINE APPENDIX

### Roadmap page — **PASS** (p. 1)
- "Appendix Roadmap" present, maps Appendices A–F to their content. Hyperlinked refs
  resolve (blue). PASS.
- **NOTE / text issue:** appendix cover subtitle reads "Cheap Signals, Costly Proof:
  Award-Layer Evidence Triage in Cartel Enforcement" — the subtitle differs from the
  main paper's subtitle ("The Reach and Limits of Award-Layer Screening in Cartel
  Enforcement"). See Text-Issues section.

### Appendix A — label construction — **PASS** (pp. 2–7)
- 651 always-loser cobidders stated (p. 4). PASS.
- "The frequent-loser flag is not used to construct the label" — explicit italic
  statement (p. 4). PASS.
- Concordance table present: Table A.3 "Positive-count concordance across validation
  exercises" (p. 8). PASS. Table A.1 (Screen Construction) and Table A.2 (Validation
  Labels) also present and legible.

### Appendix B — **PASS** (pp. 7–14)
- "Evidence-Allocation Framework and Legal Scope". Lemma 1, Assumption 2, Proposition 3,
  Corollary 4 present and consistently numbered. Equations (B.1)–(B.5) sequential.
  Survival audit Table B.1 + Figure B.1 (Kaplan-Meier) present, single Alt-text block.
  PASS.

### Appendix C/D — opportunity / timing — **PASS** (pp. 14–28)
- Appendix C "Validation Audits" (opportunity-cell, opportunity-adjusted, timing/strict
  holdout, case composition, direct-defendant scope, limitations). Tables C.1, C.2, C.3
  legible. PASS.
- Appendix D "Economic Profile and Robustness". Table D.1 legible. PASS.

### Bid / cost appendix (Appendix E) — **PASS with NUMBERING BUG** (pp. 29–43)
- "Bid-Layer Benchmark and Cost-Recall Details". Tables E.1, E.2, E.3 + Figure E.1
  present and legible, single Alt-text block on E.1. PASS on content.
- **FAIL (layout/numbering, not text-fixable by micro-edit):** Appendix E.7.6 (p. 41)
  contains "**Algorithm G.1: Award-Layer Gatekeeping with Cost Measurement**". The
  algorithm sits inside **Appendix E** but is labelled **G.1** — the algorithm counter
  is keyed to the wrong appendix letter (G, not E). This contradicts its appendix
  letter. See Layout/Numbering section.

### Price appendix (Appendix F) — **PASS** (pp. 43–47)
- "Price Scope and Adaptive Use". Sub-sections F.1–F.6. Table F.1 "Sign-Reversal
  Decomposition" legible (p. 45). Adaptive-use simulation F.6 present. PASS.

### Last page — **PASS** (p. 47)
- Ends cleanly on Appendix F.6 (Adaptive Triage Designs). No orphaned/cut-off content,
  no trailing "??". PASS.

---

## GLOBAL PER-PAGE CHECKS (all 99 pages read)

| Check | Result |
|---|---|
| No "??" unresolved refs | PASS — none seen on any page |
| No "Appendix Appendix" | PASS — none seen |
| No table spilling off page margin | PASS — Tables 3, 4, 6, C.2, E.2 are wide but stay inside margins |
| No duplicated "Alt text:" blocks | PASS — Figs 1, 2, 3, B.1, E.1 each have exactly one |
| No algorithm numbering contradicting its appendix letter | **FAIL** — "Algorithm G.1" inside Appendix E (app. p. 41) |
| Tables legible (not overly cramped) | PASS — see NOTE on Table 4 |
| No leftover internal/workflow language | PASS — token literals like `DAY_LEVEL_TIMING_UNAVAILABLE`, `is_cade`, script names, CSV filenames appear in the appendix but are intentional reproducibility metadata, not stray workflow chatter |

---

## ISSUES THAT TEXT MICRO-EDITS WOULD NOT FIX (layout / numbering)

1. **Algorithm counter keyed to wrong appendix letter.**
   Location: Online Appendix, Appendix E.7.6, p. 41.
   Seen: heading "Algorithm G.1: Award-Layer Gatekeeping with Cost Measurement".
   The algorithm float lives inside **Appendix E** but is numbered **G.1**. This is a
   numbering/counter problem (the algorithm environment is tied to a stale section/
   appendix counter or hardcoded "G"), not a wording problem. A text replacement of the
   visible string to "E.1" would mask it but the underlying counter/cross-reference
   scheme should be corrected so the float carries its own appendix letter (E). Flagged
   because the checklist explicitly calls out "algorithm numbering that contradicts its
   appendix letter". This is the one true layout/structural FAIL.

---

## TEXT ISSUES (a micro-edit WOULD fix; flagged separately as requested)

1. **Subtitle mismatch between paper and appendix.**
   - Paper title (p. 1): "Cheap Signals, Costly Proof: **The Reach and Limits of
     Award-Layer Screening in Cartel Enforcement**".
   - Appendix cover (app. p. 1): "Cheap Signals, Costly Proof: **Award-Layer Evidence
     Triage in Cartel Enforcement**".
   The shared main title is consistent, but the subtitle/colon-clause differs. For a
   submitted "Online Appendix to:" front matter the subtitle should mirror the paper.
   One-line text edit on the appendix title block.

---

## NOTES (readable; do NOT fail)

- **Table 4** (paper p. 27) is the densest float: ~12 rows × 8 columns with a long
  multi-line Notes block. It is fully inside the margins and legible at normal zoom, but
  it is the most cramped table in the manuscript. NOTE, not FAIL.
- Appendix uses `texttt` token literals (`DAY_LEVEL_TIMING_UNAVAILABLE`,
  `LANCES`, script filenames, CSV source names, seeds like `20260603`). These read as
  deliberate reproducibility/source annotations consistent throughout, not leftover
  internal language. NOTE only.
- Figure 1 central gate box reads "Information coarsening" — consistent with the
  information-cost framing; not a detector/AUC term. NOTE (confirming, not an issue).

---

## Post-repair resolution (lead, 2026-06-04)

- **Issue 1 (Algorithm G.1 in Appendix E):** FIXED — `sec_app06` line 239 corrected to
  "Algorithm E.1" (scans agent); only self-referenced, no external \ref. Rebuilt.
- **Issue 2 (appendix cover subtitle):** FIXED — both `online_appendix_*.tex` titles now read
  "The Reach and Limits of Award-Layer Screening in Cartel Enforcement". Rebuilt.
- Post-rebuild: 4/4 documents 0 errors / 0 undefined; final PDF text scan clean
  (`final_pdf_text_scan_after_repairs.csv`).

**FINAL VISUAL VERDICT: VISUAL_PASS**
