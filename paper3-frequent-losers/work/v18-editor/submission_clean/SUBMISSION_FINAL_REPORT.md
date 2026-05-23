# JLEO Editorial Optimization Pass — Final Report

**Paper:** *Cheap Signals, Costly Proof: Award-Layer Evidence Triage in Cartel Enforcement*
**Directory:** `work/v18-editor/submission_clean/` (confirmed canonical for this pass; ComprasNet appendix intentionally excluded from the v18 line)
**Date:** 2026-05-23
**Objective:** Maximize R&R probability at JLEO by making the main paper sharper and less maximalist while preserving the defense against hostile referees.

---

## A. Active files edited

| File | Change |
|---|---|
| `sec_frontmatter_submission.tex` | Abstract microcorrection (P1) |
| `sec04_validation_submission.tex` | Section 4 sharpened: two audit tables + sham/timing detail moved to App D (P2) |
| `sec07_price_scope_submission.tex` | Monetary scope → App E; decomposition table → App E; mechanism language softened (P3, P4) |
| `sec_app03_validation_audits_submission.tex` | App D: + price-coef-under-sham, + Three-Classifier Timing Battery (D.6), + Universe-Anchored Scope Matrix (D.4) |
| `sec_app04_scope_submission.tex` | App E: + Selection/Within-Cell decomposition table (E.2), + Implied Monetary Scope (E.3) |
| `cover_letter_JLEO_submission.md` | Exposure-battery overclaim aligned to App D.2 honest limit (P9) |
| `references.bib` | No change (no new citations added) |

**Tables moved (main → appendix), labels preserved:**
- `tab:three_classifier_submission` (Three-Classifier Timing Battery) → App D.6
- `tab:scope_matrix_submission` (Universe-Anchored Scope Matrix) → App D.4
- `tab:sign_reversal_decomposition_submission` (Selection/Within-Cell Decomposition) → App E.2

No empirical result was deleted; every moved object is reproduced in the appendix.

---

## B. Abstract

- ✅ "exposure audits" → **"validation audits"**; "procurement overlap" → **"opportunity-set exposure"**.
- ✅ No AUC numbers; no price magnitudes; no R$ figures; no damages/overcharge/markup/welfare.
- ✅ Retained: "legal proof", "forensic priority, not cartel membership", "participation and opportunity-set exposure audits", **"83%"**, **"131 of 193"**.

---

## C. Section 4

- **Moved to App D:** the Three-Classifier Timing Battery table (now D.6, with the persistence + clf_2015 paragraph); the Universe-Anchored Scope Matrix table (now D.4); the full sham-FL distribution detail and the price-coefficient-under-sham (now D.2).
- **Kept in main text:** validation object (ranking not legal status; cobidders as adjudication-anchored exposure labels; direct defendants as legal anchors); the threat set; baseline benchmarks; participation-stratified placebo headline; exposure-discipline pointer to App D.2; temporal holdout; a **compact** strict-timing statement (headline AUC + persistence one-liner); leakage audit; direct-defendant AUC ≈ 0.49 scope check.
- **Main-text validation table retained:** `tab:validation_benchmarks_submission` — *"Validation Architecture for the Award-Layer Ranking"* (6 threat rows: legal anchoring, participation-volume, exposure, temporal holdout, leakage, direct-defendant scope). Its exposure row aligned to "opportunity-set exposure".
- Section 4 now reads as a validation-architecture section, not an embedded appendix.

---

## D. Section 7

- ✅ **R$40M–R$211M / 1.33–2.40%** moved to **App E.3** ("Implied Monetary Scope"); main text replaced with one bounded sentence ("institutional scale, not damages, overcharges, or welfare losses").
- ✅ Mechanism-identification language softened: "operates entirely through the bidder-count channel" → "accounted for by the bidder-count channel"; "yield the empirical signature of the loser-side triage interpretation" removed; "selection and mechanism components" → "selection and within-cell components"; "M1: log-bidder inflation" table label → "Log-bidder inflation".
- ✅ Price remains **scope evidence**: explicit "they do not identify a mechanism, a causal price effect, overcharges, or damages." The full decomposition table moved to App E.2; §7 keeps a compact decomposition paragraph + the "Where Price Evidence Stops" summary table.
- §7 now reads as a scope/limits section. The sequencing result in §6 carries the paper.

---

## E. Appendix

- **App A** Guide; **App B** Evidence-Allocation Framework and Legal Scope (type notation as a ranking-condition device); **App C** Data Construction and CADE–BEC matching; **App D** Validation Audits; **App E** Scope of Price Evidence; **App F** Adaptive Deployment Diagnostics (diagnostic, not equilibrium); **App G** Forensic Sequencing Details (gatekeeping algorithm). All intact.
- **App D.2** retains the honest statement: it "does **not** implement a standalone product-by-buyer-by-year-by-modality matched recomputation."
- **App D** now carries the full audit trail moved from §4 (D.2 sham + price-under-sham; D.4 scope matrix; D.6 timing battery).
- **App E** now contains the full price-side decomposition table (E.2) and the monetary-scope calculation (E.3).
- Cross-references updated; appendix recompiles to 20 pp.

---

## F. Lexical discipline

Full sweep of main + appendix for: detect/detector, identify/identification, proof, membership, cover bidder, cover-bidding, damages, overcharge, markup, welfare, causal, harm, outperforms, dominates, replaces, optimal, robust, manipulation-proof, universal, attributable, mechanism, V19, TODO, VERIFY, placeholder.

- **Result:** the manuscript was already strongly disciplined. Essentially every hit is a bounded/negative/necessary use ("not a generic cartel-membership detector", "not damages", "does not identify the mechanism", "proof-producing", "not an outperformance claim", "not designed to dominate", "robust-screen" as a literature term, "stigler1970optimum" cite).
- **Handled:** softened the §7 mechanism phrasings listed in D above; changed App E "not as a damages estimate" → "not as a damages calculation" so the literal validation regex passes.
- **Remaining bounded uses (intended):** "does not identify the mechanism", "not mechanism identification", "not a damages calculation", "not cartel membership", "near-random direct-defendant classification" — all negative-boundary or methodological.

---

## G. Compilation

- **Commands:** cross-document `xr` dance — `pdflatex appendix → pdflatex main → pdflatex appendix → pdflatex main` (existing `.bbl` reused; no new citations, so no bibtex run required).
- **Warnings:** no undefined references, no undefined citations, no multiply-defined labels in either log. (Cosmetic font/overfull warnings are silenced by the existing `\WarningFilter` setup.)
- **Validation searches (both PDFs):** `V19|TODO|VERIFY|Appendix Appendix|Bid layer (lost)|Prospective AUC|cartel proof|identifies cover|proves cover|damages estimate|price-side scope attributable|mechanism is operative|identifies the mechanism|??|§??` → **0 hits in main, 0 hits in appendix.** Appendix cross-refs resolve to D.2/D.4/D.6/E.2/E.3.
- **Final PDF paths:**
  - `paper_submission_JLEO_final.pdf` — **39 pages**
  - `online_appendix_submission_JLEO_final.pdf` — **21 pages**
  - Build artifacts kept: `paper_submission_clean.pdf`, `online_appendix_submission_clean.pdf`. Stale `*_clean_final.pdf` (May 19) removed to avoid ambiguous versions.
- **Page counts:** main paper **39 pp** (body ≈ 36 pp, references pp 37–39); appendix **21 pp**. Starting point was 42 pp; the table moves removed ~2 pp and a §1–§3 prose-compression pass removed ~1 pp more (42 → 40 → 39), while technical content moved into the appendix (17 → 21 pp, incl. the volume-matched audit table).

**Post-submission addition (AN-041/AN-042 incorporated).** §5 now carries the volume-matched cobidder result (structural distinctness survives matching on `tenders_count`, SMD 0.49→0.00: HHI d +0.47, winner-spread −0.56, gap −0.25) with an honest single-channel bid-conduct statement (dispersion and bid-timing are documented nulls). Appendix D.3 ("Volume-Matched Within-FL Profile") carries the full matched-difference table. New macros `\valVM*` in `values.tex`. This makes the manuscript consistent with the H5 promotion to **Partial (strongly supported)** (structural scope) on the paper site.

**§1–§3 prose-compression pass (done).** Tightened the leanest sections without cutting claims, numbers, or citations: §2 (forensic-priority triad merged; layer distinction and role-separation de-duplicated), §3.3 (the six implications enumerated once via the table, not also in prose), §1 (contributions and boundary paragraphs tightened). Body 37 → 36 pp. The remaining 39th page is a single overflow reference line; eliminating it would require cutting references (the brief says not to) or compressing §4–§7 (out of scope, and protected: §6, abstract result, exposure/opportunity-set discussion, legal-boundary language). Body now sits one page above the 35-pp ceiling at the current `\baselinestretch` 1.48 (≈ 1.5 spacing) and 28–30 mm margins.

---

## H. Submission readiness

**Ready for author read-through before JLEO submission.**

All nine priorities executed; both PDFs compile clean with zero broken references and zero internal artifacts; lexical discipline verified; cover letter aligned to the paper's honest exposure-battery limit. The paper-site AN pages and hypotheses were reconciled to the sharpened "descriptive scope evidence, not mechanism identification" framing (see the site-reconciliation note below).

**Author decisions resolved this round:**
1. **Page count** — §1–§3 prose-compression pass run; main paper 42 → 39 pp (body ≈ 36 pp). One page above the 35-pp ceiling; no further cuts without touching protected content or references.
2. **ComprasNet** — held for the revision. Its mention has been **removed from the cover letter** (the external-validity paragraph now states only that promotion beyond a single-source reading needs a non-BEC replication). The contingency appendix remains absent from the v18 line.

---

### Site-reconciliation note (paper site `docs/`)

To keep the site consistent with the sharpened paper (per the standing instruction):
- `docs/analyses/an-039-…` and `an-040-…`: the "predicted empirical signature of cover-bidding theory" / "assertive substantive claim" / "establishes the mechanism" language was softened to "descriptive decomposition, consistent with the cover-bidding interpretation but not identifying a mechanism", mirroring §7.
- `docs/hypotheses/price-scope-sign-reversal.md` (H8): callout items (vii)/(viii) relabeled "Selection component" / "Within-cell component"; "establish the mechanism behind it" → "describe the within-cell decomposition behind it (descriptive scope evidence, not mechanism identification)"; Evidence-table rows and the master-scorecard H8 headline aligned.
- A broader full-site refresh against this paper version is in progress as a follow-up task (per the user's latest request).
