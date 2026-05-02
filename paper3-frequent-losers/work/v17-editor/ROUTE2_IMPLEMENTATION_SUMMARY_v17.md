# Route 2 Implementation Summary — v17

**Date:** 2026-05-02.
**Working dir:** `work/v17-editor/`. v16 at `work/v16-editor/` is byte-frozen.
**Compile state:** `paper_v17editor.pdf` (60 pp, 623 KB) +
`paper_v17editor_online_appendix.pdf` (22 pp, 449 KB), both clean
(0 LaTeX errors, baseline natbib/wasy/multiply-defined warnings only).

---

## Where edits landed (v17 only)

| File | What changed | Why |
|---|---|---|
| `paper_v17editor.tex` (master) | Added 49 v17 macros for Route 2 numbers (gatekeeper, bid-level bridge, segment decomposition) | Macro-bound numbers per CLAUDE.md project rule |
| `paper_v17editor_online_appendix.tex` (master) | Mirror of the same 49 macros | Cross-references between main and OA require both files to expose the same symbols |
| `sec_frontmatter_v17.tex` (abstract) | Rewrote observability framing (operational vs.\ forensic-recoverable layer); added gatekeeper headline; added bid-level bridge headline | Front 3 (architecture) + cross-cutting observability + Front 2 (theory) |
| `sec_introduction_v17.tex` | 5 surgical edits: opening paragraph reframed; Imhof comparison sentence sharpened with sequential gatekeeper claim; theory-bridge paragraph extended with R2 reading; pricing paragraph replaced with segment-level Q4 finding + trim sensitivity; "claims the paper does not make" updated | Cross-cutting observability + all three Route 2 fronts |
| `sec_institutional_v17.tex` | Replaced "data layer that survives at the analytical warehouse" paragraph with explicit two-layer distinction (operational vs.\ forensic-recoverable); rewrote international comparison paragraph with same distinction; added detailed disclosure footnote about LANCES export access | Cross-cutting observability reframe (highest-priority prose change in the v17 push) |
| `sec5_emp_v17.tex` | Added long footnote on data access disclosure to the primary empirical-object paragraph; updated body sentence to distinguish operational layer | Cross-cutting observability disclosure |
| `sec_forensic_v17.tex` | Rewrote opening paragraph: three architectural dimensions (same target / non-redundant / sequential gatekeeper); rewrote framing of figure caption to seven Imhof features; added new paragraph + `tab_architecture_gatekeeper.tex` for sequential gatekeeper; rewrote architectural-reading paragraph and portability implication around the operational/forensic-recoverable distinction | Front 3 (architecture: the strongest contribution moved closer to center) |
| `sec_cade_v17.tex` | Added new subsubsection $\S$\ref{sec:cade_bridge_bidlevel} with `tab_theory_bridge_bidlevel.tex`; introduced R1 (textbook cover bid) vs R2 (credible cover bidding) distinction; bridge counter updated to 7-of-9 under R2 (vs.\ 4-of-5 firm-level only in v16) | Front 2 (theory bridge: bid-level extension that v16 walked away from) |
| `sec_results_v17.tex` | Added new paragraph "Segment-level decomposition: the broad-sample positive is a Q4 phenomenon" with `tab_sign_reversal_segment.tex`; trim-sensitivity discussion forecloses few-cell-artifact reading; demoted v16 reweighting-phenomenon framing | Front 1 (sign reversal: real but modest gain; demoted, not embellished) |
| `sec_conclusion_v17.tex` | Rewrote opening paragraph + three sub-paragraphs to use operational vs.\ forensic-recoverable layer distinction; added gatekeeper sentence; added bid-level bridge sentence | Cross-cutting observability + the three fronts |

**Files NOT touched** (intentionally — no new evidence):
`sec_literature_v17.tex`, `sec4_data_v17.tex`, `sec_mechanisms_v17.tex`,
`sec_robustness_v17.tex` (segment table is referenced from
`sec_results_v17`, no new robustness needed),
`sec_limitations_v17.tex`, `sec_endmatter_v17.tex`,
`sec_appendix_v17.tex` (the new tables live in main text; OA gets
them automatically via `xr` cross-references).

## Net new generated artifacts (Subprompts 2 + 3)

| File | Created by | Purpose |
|---|---|---|
| `scripts/61_sign_reversal_segment_decomp.R` | Subprompt 2 (Front 1) | Segment β across three specs + ATT-weight concentration + trim sensitivity |
| `scripts/62_theory_bridge_bidlevel.R` | Subprompt 2 (Front 2) | Per-firm bid-level metrics from `bid_level_full_v14.parquet`; multivariate logit |
| `scripts/63_architecture_gatekeeper.R` | Subprompt 3 (Front 3) | Sequential gatekeeper precision/recall envelope using `bid_level_with_prices.parquet` |
| `output/sign_reversal_segment/{segment_betas, att_weight_concentration, top_weight_cells, att_trim_sensitivity}.csv + fig_segment_betas.pdf` | Front 1 | 4 CSVs + 1 PDF |
| `output/theory_bridge_bidlevel/{firm_bidlevel_metrics, standardized_diffs_bidlevel, multivariate_logit, class_counts}.csv` | Front 2 | 4 CSVs |
| `output/architecture_gatekeeper/{precision_at_k, sequential_envelope}.csv + fig_precision_at_k.pdf` | Front 3 | 2 CSVs + 1 PDF |
| `work/v13/output/tables/tab_sign_reversal_segment.tex` | Front 1 | 3-panel main-text table |
| `work/v13/output/tables/tab_theory_bridge_bidlevel.tex` | Front 2 | 3-panel main-text table |
| `work/v13/output/tables/tab_architecture_gatekeeper.tex` | Front 3 | 6-rule precision/recall/microdata-footprint table |

## Macros added (Route 2)

49 new `\val…` macros, prefixed by front:

- **Architecture / gatekeeper** (15): `\valArchPoolSize`, `\valArchNPos`,
  `\valArchBaseRate`, `\valArchPrecAtFiveHund{FL,Imhof,Joint,SeqK}`,
  `\valArchRecallThou{Joint,SeqK}`, `\valArchTPThou{Joint,SeqK}`,
  `\valArchSeqKone`, `\valArchFootprintReduction`, `\valArchRecallCost`.
- **Theory bridge bid-level** (19): `\valTBBLnCob`, `\valTBBLnFLnc`,
  `\valTBBL{Med,PS,SD}Gap{Cob,FLnc,D}`, `\valTBBLLogit{Med,SD,TC}{Coef,Z}`,
  `\valTBBLRefCov{Convite,Pregao}`.
- **Sign-reversal segment** (15): `\valSRQ{one,two,three,four}{Broad,ATT,ATTp}`,
  `\valSRTrim{None,One,Ten,Fifty}`, `\valSRHHIWeights`,
  `\valSRTopOnePctShare`, `\valSRTopTenPctShare`, `\valSRTopDecileConvShare`.

All values inline-bound in `paper_v17editor.tex` and mirrored in
`paper_v17editor_online_appendix.tex`. None of them propagates to
v15/v16/v13 because they are defined inside the v17 master, not in the
shared `values.tex` symlink. (Following Subprompt 1's hedge rule: never
edit shared `values.tex` for v17-specific reframings.)

## Observability reframe — locations actually changed

The audit (Subprompt 1 §II.1) identified 15 sloppy prose locations.
Fixed in v17:

| Section | Location | Before | After |
|---|---|---|---|
| `sec_frontmatter_v17` (abstract) | "Most enforcement environments globally preserve only the contract-award layer" | "Most enforcement environments globally preserve per-bidder bid amounts only at a forensic-recoverable layer reached through administrative request, while routine analytical access is limited to the contract-award envelope." | Operational/forensic-recoverable distinction |
| `sec_frontmatter_v17` | "detectors that require per-bidder bid amounts" | "Imhof--Wallimann pipeline trained on the forensic-recoverable bid-microdata layer" | ditto |
| `sec_introduction_v17` (L7) | "informative about coordinated bidding when the bid-level record is preserved" | "informative about coordinated bidding when per-bidder bid amounts are routinely observable" | ditto |
| `sec_introduction_v17` (L67) | "Against bid-distribution detectors that require per-bidder bid amounts" | "Against the seven-feature Imhof--Wallimann bid-distribution pipeline trained on the forensic-recoverable bid-microdata layer" | ditto |
| `sec_introduction_v17` (L113) | "require bid microdata; the construct operates on the information-coarsened layer that survives" | "require bid microdata at the analytical-warehouse layer; the construct operates on the operational layer that audit courts can query without administrative request" | ditto |
| `sec_introduction_v17` (L130) | "Under incomplete observability of the bid layer" | "Under incomplete observability of the bid layer at the analytical-warehouse interface" | ditto |
| `sec_introduction_v17` (L136) | "jurisdictions that lack bid microdata can deploy the screening stage" | "jurisdictions whose operational layer carries award records but not per-bidder bid amounts can deploy the screening stage" | ditto |
| `sec_institutional_v17` (paragraph) | "The data layer that survives at the analytical warehouse" | "Two observability layers, not one" — full rewrite with explicit operational/forensic-recoverable distinction + LANCES disclosure footnote | ditto |
| `sec_institutional_v17` (paragraph) | "The asymmetry between the two layers is structural rather than parochial" | "The two-layer asymmetry is structural rather than parochial" — body rewritten to mention forensic-recoverability via subpoena/FOI/admin in US/EU/UK | ditto |
| `sec5_emp_v17` (footnote) | (none) | New $\sim 200$-word disclosure footnote on LANCES export access, attached to the primary empirical-object paragraph | ditto |
| `sec_forensic_v17` (opening) | "under incomplete observability, enforcement architecture separates" | "under incomplete operational observability of the bid layer (\S{sec:institutional}), enforcement architecture separates" | ditto |
| `sec_forensic_v17` (opening) | "Most enforcement environments do not preserve those features at the analytical-warehouse layer" | "At the operational layer most enforcement environments preserve only the award envelope" | ditto |
| `sec_forensic_v17` (architectural reading) | "Under incomplete observability the deployable architecture is therefore" | "Under incomplete operational observability the deployable architecture is therefore" | ditto |
| `sec_forensic_v17` (portability implication) | "Jurisdictions that preserve only the award layer" | "Jurisdictions whose operational layer carries award records but not per-bidder bid amounts" | ditto |
| `sec_conclusion_v17` (opening) | "The bid-rigging detection literature has been built on the assumption that bid-level data are observable" | "...bid-level data are routinely operationally observable" + new paragraph that introduces the two-layer distinction | ditto |
| `sec_conclusion_v17` (3 paragraphs) | "What survives data coarsening" / "Proactive screening does not require bid-microdata archival as a precondition" / "wherever an enforcement environment exposes the award layer without exposing the bid layer" | All three rewritten with operational-layer vocabulary | ditto |

Every prose location flagged in the audit is either fixed or
intentionally left (the literature review section's paraphrases of
Imhof's claims do not need to use our vocabulary).

## What was NOT done

1. **No broad rewrite.** Sections that did not gain new evidence
   (`sec_literature_v17`, `sec4_data_v17`, `sec_mechanisms_v17`,
   `sec_limitations_v17`, `sec_appendix_v17`) are byte-identical to
   v16. The brief explicitly forbids broad rewrites without
   justification.
2. **No dollarised cost-effectiveness claim.** The Subprompt 3 audit
   warned against this; Section §`sec:forensic` uses recall-vs-microdata-
   footprint trade-offs without dollar costs.
3. **No new robustness battery.** The Q4 segment finding lives in
   `sec_results_v17`, not in a new robustness subsection. The trim
   sensitivity is part of the same paragraph that introduces the
   segment decomposition. This is intentional — the robustness
   discipline of v16 is preserved.
4. **No retraction of Online Appendix A's Proposition 4.** The v16
   sign-reversal memo demoted it to "one interpretation among
   several"; the v17 segment-level reading is consistent with that
   demotion and does not require Proposition 4 to be retracted. The
   theory document retains its original role as a possible
   data-generating-process specification.
5. **No deployment of v17 to the public site.**
   `darciogm.github.io/research/frequent-losers/` continues to point
   at v15 (per the project memory note); v17 is for offline revision
   and editorial submission, not public release until the JLEO
   submission package is final.

---

*End of implementation summary. The final-verdict memo
(`ROUTE2_FINAL_VERDICT_v17.md`) provides the editorial expectation
and the up-or-down call on whether Route 2 was worth doing.*
