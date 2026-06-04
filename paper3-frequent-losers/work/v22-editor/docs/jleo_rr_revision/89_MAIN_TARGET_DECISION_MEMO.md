# 89 — MAIN TARGET DECISION MEMO (JLEO final optimization)

**Date:** 2026-06-04 · **Decision rule applied:** Step 5 of the final-optimization protocol.

## Verdict: CASE 2 — narrow target not reproducible; BROAD ALWAYS-LOSER COBIDDER TARGET ADOPTED AS MAIN

## Chosen main target

**Target B — broad always-loser cobidder target (adjudication-anchored exposure).**

> A unique always-loser firm (W_i = 0 over the 2009–2019 BEC award record) that shares at
> least one BEC tender-item with at least one BEC-active direct CADE defendant. Direct
> defendants are excluded. The frequent-loser flag is not used to construct the label.

## Why

1. **The narrow cartel-tender target (Target C) is not reproducible.** The static
   `cade_fl_cobidders.csv` (193 rows) was built with an undocumented "cartel-tender"
   restriction whose builder is absent from the repo (blocker B3, open since Subprompt 4).
   Per the decision rule, an archived target cannot be main.
2. **The archived target is also circular for the score under evaluation.** All 193 rows are
   `is_FL = TRUE`: the archived builder conditioned the positive label on frequent-loser
   status. Validating FL14 / log(tenders_count) against an FL-only label mechanically
   inflates separation. This is disqualifying independent of reproducibility.
3. **Target B is fully reproducible from current scripts** (`00_build_canonical_validation_targets.R`,
   logic verbatim from `01_label_funnel_reconciliation.R` S1–S3, raw inputs only),
   deterministic (assertion T10), excludes defendants (T1), counts unique W_i = 0 firms (T2),
   and is independent of FL status (T3) with non-degenerate FL composition (T4: 341 FL + 310 non-FL).

## Counts (canonical_target_counts.csv, run 2026-06-04)

| Object | Count |
|---|---|
| **Main target (broad AL cobidders)** | **651** |
| — of which FL14 (descriptive composition) | 341 |
| — of which non-FL (descriptive composition) | 310 |
| Candidate universe (always-losers) | 16,843 |
| BEC-active direct defendants (excluded anchors) | 41 (48 crossmatch) |
| Conservative benchmark (same def, cases judged ≤ 2020-12-31) | 208 cobidders / 19 crossmatch (16 BEC-active) defendants |
| Timing: rankable-incumbent positives (pre-2017 history) | 498 |
| Timing: unrankable entrant positives | 153 (23.5%) |
| Defendant tender-items (anchor set) | 52,013 |

## Reproducible? Independent of FL?

- Reproducible: **YES** — single script, raw inputs, 1.6 s, assertions T1–T10 all pass.
- Independent of FL: **YES** — label derives only from tender-item joins; FL14 appears in the
  labels file solely as the score column under evaluation.

## How the old 193 is handled

- **Removed from the submitted manuscript and appendix as a validation target.** No archived-
  builder caveat remains in submitted text.
- Retained ONLY internally: `in_static_archived_193` column + `target_set_comparisons.csv`
  (`ARCHIVED_INTERNAL_COMPARISON`) + this memo. Not reproduced → cannot be cited as a count
  in the submitted paper.
- The previously planned "disclose + robustness" route (user decision U2, 2026-06-02) is
  **superseded**: disclosure of an irreproducible, screen-conditioned main target does not
  survive a hostile referee; replacement does.

## Downstream tables that must be regenerated (all currently estimated on the 193 label)

| Output | Script | Manuscript location |
|---|---|---|
| Label funnel (Table 2 / Table A) | 01 (rewrite rows: main = 651 broad AL) | §4.1 + App A/C |
| Opportunity-adjusted validation (Table 3 / C, D) + firm frame | 02 | §4.2–4.3 |
| Strict timing + rolling origin (Table 4 / D, E) | 03 | §4.4 |
| LOCO + case dominance (G, H) | 04 | §4.4 + App |
| Profile/monotonicity (J, K, L, M) + group counts (E) | 05 (via new frame) | §5 |
| Robustness (N + placebo/market/negative) | 06 | §5 + App |
| Bid-feature support (O) | 07 | App F |
| Bid benchmark reproduction + validation (P, Q, R, S; Table 5) | 08, 09 | §6.1 + App |
| Cost-recall frontier (Table 6 / G set) | 10 | §6.2 + App |
| Survival appendix (B set) | 11 | App B |

## Submission-ready after this step?

**Not yet.** Verdict C territory until every downstream table above is regenerated under the
new label and the manuscript/appendix text, macros, abstract, and framing are rebuilt to the
new numbers (Steps 6–18). The paper must NOT be submitted with old-label results under the
new target definition.
