# 58 — Final Manuscript Technical Audit

**Paper:** *Cheap Signals, Costly Proof…* (JLEO R&R, v22). **Auditor mode:** read-only, verify-by-tool.
**Method:** `pdfinfo`, `pdftotext`, grep on BOTH `.tex` sources AND PDF text. PDFs built 2026-06-03.

---

## 1. Structural counts (tool-verified)

| Metric | Value | Source |
|--------|-------|--------|
| Paper PDF pages | **39** | `pdfinfo paper_submission_clean.pdf` → Pages: 39 |
| Main-text pages (excl. references) | **35** (pp. 1–35; References starts p. 36) | per-page `pdftotext` scan, "References" heading on p. 36 |
| References pages | 4 (pp. 36–39) | same |
| Abstract word count | **146** (≤150 ✓) | computed from `sec_frontmatter_submission.tex` |
| Main tables | **6** | `\begin{table}` in `sec0*.tex`: sec02×1, sec04×3, sec06×2 |
| Main figures | **3** | `\begin{figure}` in `sec0*.tex`: sec02, sec04, sec06 |
| Appendix PDF pages | **31** | `pdfinfo online_appendix_submission_clean.pdf` → Pages: 31 |
| Appendix tables | **11** | `\begin{table}` count across `sec_app*.tex` |
| Appendix figures | **2** | `\begin{figure}` count across `sec_app*.tex` |

All counts match the declared known state.

## 2. Reference / build integrity

| Check | Result |
|-------|--------|
| `??` (unresolved ref) in paper PDF text | **0** |
| `??` in appendix PDF text | **0** |
| "Reference … undefined" in `.log` (both) | **none** |
| "Citation … undefined" in `.log` (both) | **none** |
| "Rerun … labels may have changed" (substantive) | none (only benign rerunfilecheck "has not changed" lines) |
| `[VERIFY]` / placeholder in `references.bib` + `.bbl` | **0** |
| Empty `\cite{}` / TBD / XXX in `.tex` | **0** (lone "VERIFY" string is a code comment about macro binding, not a citation flag) |

## 3. Hygiene grep — forbidden strings

Ran on BOTH the `.tex` source set AND `pdftotext` of both PDFs.

### 3a. Strings with ZERO hits anywhere (clean)

`TODO`, `FIXME`, `cartel detector`, `proof from award records`, `cover-bidding theater`, `Bid layer (lost)`, `Award layer (survives)`, `Cartel-Adjacency`, `Mr. Frequent`, and (rendered) `Subprompt`, `Claude`, `BLOCKED`-as-marker.

### 3b. Strings with hits — every hit judged

| String | Where | Quote (representative) | Verdict |
|--------|-------|------------------------|---------|
| `BLOCKED`/`blocked` | sec06 (×2), sec_app06, sec_app09; renders in PDF | "the bid benchmark is \emph{blocked}, because within-tender dispersion moments cannot be cleanly recovered"; "Strict bid-timing validation is \textbf{blocked}" | **justified (boundary).** Honest disclosure that a specific test cannot be run; the word describes a genuinely blocked analysis, not a leftover marker. Must-remove: NO. |
| `Subprompt` | `values.tex` comments only (lines 1148, 1184, 1205, 1375, 1388, …) | "% === Subprompt 4: label-funnel reconciliation (CP-1) ===" | **justified.** LaTeX comments; NOT rendered (0 hits in either PDF). Cosmetic only. Optional cleanup. Must-remove: NO (does not appear in submitted PDF). |
| `cartel members`/`membership` | sec01, sec03, sec04, sec06, sec08, sec_app01, sec_app03; renders | "adjudication-anchored exposure, not cartel membership"; "does not test cartel membership or conduct" | **justified (negated).** Every occurrence is a disciplinary negation. Must-remove: NO. |
| `overcharge` | sec07, sec_app04; renders | "It is \emph{not} a damages estimate, an overcharge, a cartel markup…"; bibliography "Connor (2007) Price-fixing overcharges" | **justified (negated + legit ref).** Body uses are negations; the standalone is a real Connor (2007) citation. Must-remove: NO. |
| `damages` | sec01, sec07, sec08, sec_app00/01/03/04; renders | "Price evidence is scope information, not a damages exercise"; "supply no damages base" | **justified (negated).** All boundary/negation. Must-remove: NO. |
| `Claude` (as substring) | not found in PDFs | — | clean (0 PDF hits). |

**Hygiene verdict: 0 must-remove hits.** All forbidden-string occurrences are either (i) the paper's own disciplinary negations of the forbidden claim, (ii) a genuine blocked-test disclosure, (iii) a legitimate bibliography entry, or (iv) non-rendering `values.tex` comments. The optional-only item is removing `% Subprompt` comments from `values.tex` for tidiness (not in the submitted PDF, so non-blocking).

## 4. Float / caption spot-checks (via pdftotext extracts)

| Float | Check | Result |
|-------|-------|--------|
| **Figure 1** caption (`fig_data_coarsening`) | no lost/survives labels, no stale AUC | ✓ "information-cost diagram, not a detector horse race"; alt text present; underlying PDF clean. |
| **Table 2** label funnel | renders, defines funnel + benchmark cobidder | ✓ "Label-Construction Funnel and Benchmark Reconciliation"; broad funnel 341 FL / 651 AL cobidders, narrow 193 target. |
| **Table 3** opportunity-adjusted | renders, opportunity cells + within-stratum | ✓ "Opportunity-Adjusted Validation"; exposure-only 0.946, within 0.771, +0.042, p=2.1e-6. |
| **Table 4** timing/case | renders | ✓ "Timing and Case-Composition Synthesis"; rolling-origin / leave-largest-case-out present. |
| **Table 5** bid benchmark | renders, full pool definition | ✓ Imhof 0.888 / FL 0.921 / combo 0.962; pool 16,772 firms, 190 positives. |
| **Table 6** cost-recall | renders, frontier framing | ✓ "Cost-Recall Frontier…"; K1=2,000 → 88% firm / 33% bid-row reduction. |
| **§7 price** | scope discipline | ✓ "not a damages estimate…"; broad +0.064 → overlap −0.097 → Q4 +0.041. |
| **Appendix B theory** (`sec_app01`) | reduced-form scope, no over-claim | ✓ "Evidence-Allocation Framework"; "justifies an ordering rule for scarce forensic attention, not the internal organization of a cartel." |

## 5. Headline verdict

**Must-remove hygiene hits: 0.** No `??`, no undefined refs/citations, no rendered TODO/FIXME/Subprompt/Claude, no stale AUC or lost/survives labels in Figure 1. The only non-rendering residue is `% Subprompt` comments in `values.tex` (optional tidy-up). Technically clean.
