# 91 — OPTIMIZED TARGET FRAMING COMPLETION REPORT

**Date:** 2026-06-04 · **Mode:** Mr. Frequent Losers, FINAL OPTIMIZATION MODE
**Branch:** `v22` (dedicated revision branch; no new branch created — see log 86)

## 1–5. Target

1. **Chosen main target:** Target B — broad always-loser cobidder (adjudication-anchored
   exposure): unique W_i=0 firm sharing ≥1 BEC tender-item with a BEC-active direct CADE
   defendant; defendants excluded.
2. **Reproducible:** YES — `scripts/analysis/00_build_canonical_validation_targets.R`, raw
   inputs only, deterministic (two-path identity check T10), 1.6 s.
3. **Independent of frequent-loser status:** YES (T3 structural; T4 composition non-degenerate).
4. **Direct defendants excluded:** YES (T1 = 0 contamination).
5. **Final main positive count:** **651**.

## 6–9. Companion counts

6. Broad target count: 651 (it IS the main target; the old narrow/broad duality is gone).
7. Conservative count (same definition, cases judged ≤ 2020-12-31): **208** cobidders / **19**
   crossmatch defendants (16 BEC-active).
8. Bid/common-support positives: **651 — all retained** in the 16,731-firm bid-feature pool.
9. Timing positives: **498 rankable incumbents + 153 unrankable entrants (23.5%)**.

## 10–11. The old 193

10. **Replaced and removed.** Not reproduced (archived builder, undocumented narrow filter) and
    additionally **circular** (file is FL-only; all 193 rows `is_FL=TRUE`) — disqualified on
    both grounds. Retained ONLY in internal diagnostics
    (`target_set_comparisons.csv`, `in_static_archived_193` column) and internal memos.
11. **Archived-file caveat removed from submitted manuscript and appendix** — 0 hits for
    archived / not reproduced / builder / frequent-loser only / cade_fl_cobidders / 193-as-target
    in both compiled PDFs.

## 12–13. Regeneration

12. Tables regenerated under the new label (all rc=0): Table 2 funnel (script 01), Table 3
    opportunity-adjusted + permutations (02), Table 4 timing/rolling (03), LOCO/case dominance
    (04), §5 profile/monotonicity/robustness (05–06), Table 5 bid benchmark (07–09), Table 6
    cost-recall frontier (10), survival appendix (11), adversarial adaptation (55-canonical).
    Ledger: `outputs/diagnostics/target_sensitive_outputs_regenerated.csv` (19 rows, all "yes").
13. Figures regenerated: funnel, observed-vs-expected bins, permutation, rolling-origin, LOCO,
    clustered-RI, survival KM. Figure 1 (information-cost diagram) verified label-clean, no AUC
    literal, required caption present.

## 14–18. Manuscript

14. Sections edited: ALL (sec01–sec08, frontmatter, sec99 untouched-clean) + appendices
    app00–app09 + values.tex + values_adversarial.tex. Lead rewrote §4 in full.
15. Appendix A rewritten: exact matching/cobidder/exclusion rules; FL-not-used statement;
    composition 341/310; conservative same-definition; retrospective-anchor timing statement;
    common-support counts; **positive-count concordance table embedded**
    (`tab:positive_count_concordance`); no archived-file caveat.
16. Abstract: **137 words**, no raw AUC, all required elements.
17. Figure 1: clean (information-cost diagram caption; no detector horse race; no AUC literal).
18. "Appendix Appendix": **0** (was 23 across both PDFs; `Appendix~\ref` duplication fixed).

## 19–21. Claim discipline

19. Operational claims: every one carries incumbent-triage / retrospective-validation caveats;
    §6 carries the required bid-rerank timing sentence verbatim; no platform-wide prospective
    deployment claim anywhere.
20. Cost-recall: frontier-is-the-object framing; multi-denominator honesty (88.1% firms vs
    32.7% bid rows at K1=2000); K1=1000>K1=2000 noted as further proof of no optimum; FP and
    missed positives reported; recovery-footprint language.
21. Price: scope evidence only; one boundary disclaimer; compressed to one main-text paragraph.

## 22. Build

0 errors / 0 undefined refs in all four documents; paper 52pp (JLEO double-spaced) + appendix
46pp; claims scan critical=0. Details in log 90.

## 23. Remaining blockers

**None fatal.** Advisory items:
- **(A1 — substantive, author must sign off):** under the non-circular label the empirical
  story DEFLATES beyond the previous draft: within-opportunity residual ≈ chance (0.471),
  nested increment +0.010 (p=0.013), matched permutation p=0.127 ns, FL-enrichment p=0.067 ns,
  negative controls no longer separate real anchors from placebo/high-volume-winner anchors
  (p=0.46/0.91). The paper now stands ENTIRELY on the transferable audit-framework
  contribution ("where cheap screens stop"). This matches the title and §1/§8 as rewritten,
  but it is a materially more negative empirical paper than the GO_WITH_MINOR_REPAIRS version.
  **Darcio must read and approve the new §4/§5/§6 story before submission.**
- (A2) ✅ **RESOLVED 2026-06-04 (post-report):** contact≥2 sensitivity run
  (`02b_opportunity_sensitivity_contact2.R`, outputs/sensitivity_contact2/, 368 positives).
  Deflationary result ROBUST — raw 0.854 but exposure-only 0.873/0.956 out-predicts again;
  within-stratum 0.506 (chance); nested +0.003 p=0.47; matched perm p=0.39 ns. Reported in
  Appendix D + one sentence in §4.2. The dilution objection is now pre-empted in print.
- (A3) Leakage-decomposition macros (\valLeakCVAUC/\valLeakRefAUC) and conservative-AUC macros
  (\valAUCprePost etc.) are STALE-annotated and uncited; delete or regenerate at leisure.
- (A4) Author declarations (fee, COI, funding, preprint, suggested reviewers) — unchanged from
  doc 68, still pending, administrative only.

## 24. Submission recommendation — VERDICT D

**Narrow target not reproducible; broad target adopted.** All Verdict-D conditions hold: the
broad target is reproducible and non-circular; the paper is reframed around broad
adjudication-anchored exposure; downstream outputs are regenerated; framing is deflationary and
matches the actual evidence. The broader target **does** still support the paper's (recalibrated)
limited claims — the transferable decomposition framework, the boundary map, and the cost-recall
accounting — though it no longer supports any residual-signal claim.

**Recommendation:** proceed to the final hostile pre-submission referee read on the new PDFs,
conditional on author sign-off of advisory item A1. Do NOT submit before that sign-off: the
empirical narrative changed materially and the call on whether the more negative paper goes out
belongs to the authors.
