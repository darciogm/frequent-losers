# Visual / Positioning Review — v22 (Jun 6 build)

**PDFs reviewed.** `submission_clean/paper_submission_clean.pdf` (**47 pp**,
0 undefined refs) and `online_appendix_submission_clean.pdf` (**40 pp**,
0 undefined refs, 1 minor overfull hbox). Rendered Box 1 (p. 8) and Appendix G
result pages as images; full text via pdftotext -layout.

**Overall positioning verdict.** The paper now **sells a positive
governance/audit contribution**, not "the screen fails." The contribution is
framed as (i) an organizational/law-and-economics result — award-to-bid recovery
as a sequential evidence-allocation problem; (ii) a reproducible audit
architecture; (iii) a cost-recall frontier. The deflationary empirics are
presented as *the method's findings* ("That is the finding, not a confession.",
§5.4), which reads as confident, not apologetic. No overclaim, no stale-target
language, no production artifacts in the main paper.

---

## MAIN PDF — element-by-element

| Element | Status | Note |
|---|---|---|
| Title | PASS | "Cheap Signals, Costly Proof: The Reach and Limits of Award-Layer Screening in Cartel Enforcement" — exact match |
| Abstract | PASS | Governance-first ("Enforcement agencies must govern suspicion before they can produce proof"); **132 words** (≤150). Ends "Liability stays where the evidence is richest." |
| Intro first 5 pp | PASS | Becker–Stigler / Decarolis framing; "The contribution of this paper is therefore not a new cartel detector. It is an audit architecture." Clean, no broken refs |
| Box 1 "What the Audit Does" | **PASS** | Renders as a clean bordered non-float box (top/bottom rules, bold title), **7 rows × 4 cols** (Label construction, Raw ranking, Opportunity, Timing, Case composition, Bid layer, Cost-recall), all legible, no crowding, no run-together text. Sits cleanly on p. 8. (Verified via rendered image.) |
| Table 1 (roles) | PASS | 7 objects incl. 651 cobidders; clean legal-interpretation column |
| Table 2 (label funnel) | PASS | 651 / 341 FL / 47 BEC-active; notes intact |
| Opportunity-adjusted validation (Table 3) | PASS | Raw 0.761, within 0.471, nested +0.010; tiered notes readable |
| Timing/case content (§4.3, Table 4) | PASS | Full-universe collapse 0.474, prec@500=0; case 32.0%/45.4% |
| §5 second-platform | PASS | Explicitly "stress test … not an independent cartel universe"; "partially overlapping CADE anchors"; Table 5 two-platform side-by-side renders cleanly in body |
| Bid benchmark (Table 6) | PASS | "comparable discrimination at lower informational cost"; combined = full-observability upper bound |
| Cost-recall frontier (Table 7, Fig. 3) | PASS | "no optimal cutoff … frontier itself"; 88% firm vs 33% bid-row divergence in body; Fig. 3 caption + dual alt-text clean |
| Price section (§8) | PASS | Scope-only; sign-reversal +0.064→−0.097 reported as weighting artifact |
| Conclusion (§9) | PASS | "The limits are part of the design, not an apology for it." Positive close |
| References | PASS | Clean, no malformed entries |

---

## APPENDIX PDF — element-by-element

| Element | Status | Note |
|---|---|---|
| Roadmap | PASS | Logical A→G walkthrough; one reading-convention paragraph |
| Appendix A (data/labels) | PASS | Tables A.1–A.3; 651 stable, 195 federal not present here (correct) |
| Appendix B (framework/survival) | PASS | Lemma 1 / Prop 3 / Corollary 4; Table B.1 + KM Fig. B.1 render cleanly; survival caveats explicit |
| Appendix C (validation audits) | PASS | Tables C.1–C.3; leakage tiers, falsifiability, power all present |
| Appendix D (profile) | PASS | Table D.1 SMDs; opportunity-adjustment collapse documented |
| Appendix E + E.7 (bid benchmark, cost-recall) | PASS | Tables E.1–E.3, Fig. E.1, Algorithm E.1 render cleanly |
| Appendix F (price + adaptive) | PASS | Tables F.1; F.6 strategic-response framed as institutional-design probe |
| **Appendix G / sec_app10 (federal)** | **FAIL — production artifacts** | See defect list below |
| Last page | PASS | G.10 Replication; clean end |

---

## VISUAL DEFECTS (with page numbers and exact fix)

### DEFECT 1 — Run-together verdict text in Appendix G (math-mode space collapse). **Appendix pp. 37–39.** Severity: high (glaring, reviewer-visible).
Four text-valued macros are wrapped in `$...$` math mode in
`submission_clean/sec_app10_federal_audit_submission.tex`; math mode eats the
spaces and turns hyphens into minus signs. Rendered output (confirmed via image
crop, p. 37):

- p. 37, §G.4: "the observed PR-AUC **doesnotrejectthematched − permutationnull**
  (p = 0.906)" — source line **178** `$\valFedAudPermVerdict$`.
- p. 38, §G.6: "the pooled ordering is **orderingdistinguishablef romrandom**
  (p =< 0.001) while case-coverage breadth is
  **breadthnotdistinguishablef romrandom** (p = 0.487)" — source lines **243**
  `$\valFedAudClusterRIverdict$` and **244** `$\valFedAudClusterRIcovVerdict$`.
- p. 38, §G.7: "in the realm of **genericopportunity/volumegeometry**" — source
  line **265** `$\valFedAudNegControlVerdict$`.
- p. 39, **Table G.4** negative-control row, ComprasNet cell:
  **genericopportunity/volumegeometry** — source line **326**
  `$\valFedAudNegControlVerdict$`.

The macros themselves are fine in `values.tex` (e.g.
`\valFedAudPermVerdict = does not reject the matched-permutation null`). The bug
is the `$...$` wrapper.

**Exact fix** — remove the math wrapper around the *verdict text only* (keep
`$...$` on the `p=` group). In `sec_app10_federal_audit_submission.tex`:
- L178: `…observed PR-AUC $\valFedAudPermVerdict$ ($p=\valFedAudPermCp$);` →
  `…observed PR-AUC \valFedAudPermVerdict{} ($p=\valFedAudPermCp$);`
- L243: `…ordering is $\valFedAudClusterRIverdict$ ($p=\valFedAudClusterRIp$)` →
  `…ordering is \valFedAudClusterRIverdict{} ($p=\valFedAudClusterRIp$)`
- L244: `…breadth is $\valFedAudClusterRIcovVerdict$` →
  `…breadth is \valFedAudClusterRIcovVerdict{}`
- L265 and L326: `$\valFedAudNegControlVerdict$` → `\valFedAudNegControlVerdict{}`

### DEFECT 2 — "p =< 0.001" malformed inequality. **Appendix p. 38, §G.6.** Severity: low (cosmetic).
`\valFedAudClusterRIp = <0.001` used as `($p=\valFedAudClusterRIp$)` renders
"p=<0.001" (reads "p =< 0.001"). Should read "p < 0.001".
**Fix:** either change the macro to `{0.001}` and write `($p<\valFedAudClusterRIp$)`,
or set the macro string to render as `p<0.001` directly. (Same `<` pattern is
used elsewhere as `p<…` cleanly; only this one collides with the `=`.)

### DEFECT 3 — "Appendix Appendix C". **Appendix pp. 35, 35 (G intro + G.2).** Severity: low–medium (visible duplicated word).
Source uses `Appendix~\ref{app:validation_audits_submission}` but the `\ref`
target's printed form already includes the word "Appendix", yielding
"Appendix Appendix C". Lines **15** and **81** of
`sec_app10_federal_audit_submission.tex`.
**Fix:** drop the literal "Appendix~" prefix (write
`\ref{app:validation_audits_submission}` alone, since the ref renders
"Appendix C"), or switch to `\cref`/`\autoref` if the label is configured that
way elsewhere. Verify against how other cross-appendix refs print.

---

## NON-DEFECTS confirmed clean
- 0 undefined references ("??") in either PDF; 0 "undefined reference" log
  warnings in both.
- Only 1 overfull hbox in the entire appendix (negligible; no visible spillover
  found on inspected pages).
- No duplicated alt text errors; Fig. 1, Fig. 2, Fig. 3, Fig. B.1, Fig. E.1 all
  carry single clean alt-text blocks.
- No stale appendix-letter errors other than the "Appendix Appendix" ref bug
  above (Defect 3).
- No broken captions; tables fit page width on inspected pages.
- The collapse defect is **isolated to `sec_app10`** — grep across all other
  `sec*.tex` finds no other text-valued `…Verdict` macro inside `$...$`.

---

## Readiness signal

**MINOR-FORMAT-FIXES.** Positioning, claims, and all main-paper visuals are
clean and submission-grade. Three rendering defects in Appendix G
(`sec_app10_federal_audit_submission.tex`) must be fixed before sending: Defect 1
(high — 5 run-together verdict phrases incl. one in Table G.4), Defect 2 (low —
"p=<0.001"), Defect 3 (low — "Appendix Appendix C" ×2). All three are localized
LaTeX edits in one file plus a one-line rebuild; none touch a claim or a number.
After those edits + recompile, the package is clean.
