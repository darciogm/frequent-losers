# sec_app07 Reconciliation Memo — Orphaned ComprasNet Appendix vs. the v22 Federal Battery

**Date:** 2026-06-05 · **Author:** Mr. Frequent Losers (reviewer mode) · **Status:** DECISION EXECUTED 2026-06-05
**Scope:** `submission_clean/sec_app07_comprasnet_submission.tex` (legacy, orphaned)
vs. `sec_appG_federal_DRAFT.tex` (new federal audit battery) + `sec_comparative_DRAFT.tex`.
**Discipline:** READ-ONLY on manuscript files; this memo + one salvage-block draft are the only writes.

---

## ✅ DECISION EXECUTED — 2026-06-05

GUT + DELETE + salvage-merge carried out exactly as planned:

- **Salvage merged.** The two surviving slivers (graduation table + structural-boundary
  statement + one stripped linkage-provenance sentence) were merged from
  `sec_appG_salvage_block_DRAFT.tex` into `sec_appG_federal_DRAFT.tex` as the new closing
  subsection **"Graduation: What Ports and What Deflates"**, inserted immediately **before**
  `\subsection{Replication}` (per §3a). The redundant `\providecommand{\valTODO}` preamble was
  dropped (the host file already declares it); all `% TODO_NUMBER` tags and `\valTODO`
  placeholders preserved. New macros introduced: `\valFedAudBoundaryAUC`,
  `\valFedAudBoundaryAUCLow`, `\valFedAudBoundaryAUCHi`, `\valFedAudDirectsWinshare`,
  `\valFedAudDirectsN`.
- **Salvage file deleted.** `submission_clean/sec_appG_salvage_block_DRAFT.tex` removed.
- **Orphan deleted.** `git rm submission_clean/sec_app07_comprasnet_submission.tex` (orphan
  re-verified: zero `\input`/`\include` in any master; only comment mentions remained).
- **Compile check.** `sec_appG_federal_DRAFT.tex` compiles standalone with **0 LaTeX errors**
  (6 pages; the 19 "undefined" messages are expected cross-document `\ref`s in a fragment, not
  errors; `\valTODO` resolves via the file's own `\providecommand`, 61 placeholders intact).
- **Docs updated.** `values_tex_federal_block_DRAFT.tex` (provenance list + app07 status note) and
  `NEW_NUMBERS_MAP_COMPRASNET.md` (namespace note) annotated "sec_app07 DELETED 2026-06-05"; the
  five `\valFed*` universe macros explicitly noted as REMAINING (referenced by comparative + appG).

---

## 0. Orphan verdict (precise)

**CONFIRMED ORPHAN, MACRO-DEAD.**

- `\input{sec_app07...}` appears in **zero** master files. Verified against all three masters:
  - `online_appendix_submission_clean.tex` (the appendix master) wires the canonical chain
    `app00 → app02 → app01 → app03 → app08 → app09 → app06 → app04 → app05` only. No app07.
  - `paper_submission_clean.tex` and `paper_jleo_submission.tex` (paper masters) wire
    `sec01..sec08 + sec99` only. No appendix-level federal input at all.
- The **only** textual mention of the string `sec_app07` anywhere in the tree is a *comment*
  inside the new `sec_appG_federal_DRAFT.tex` (describing app07 as the legacy companion).
- All **76 distinct `\valFed*` macros** that app07 references are **undefined**: zero occurrences
  of `valFed` in `values.tex` or `values_adversarial.tex`, and no `\newcommand`/`\providecommand`
  for any `\valFed*` in any `.tex`. The file would not compile against the current macro set.

app07 is dead text. Nothing in the live build depends on it, and nothing breaks if it is deleted.

---

## 1. Inventory: app07 claim → status against the v22 canonical framing + Phase 0

The new battery (Appendix G) and the main-text comparative section re-frame the federal exercise
around the **audit/deflation protocol** (opportunity adjustment → within-stratum residual →
power-bounding → matched permutation → label-frozen timing → LOCO → negative controls), under
the **canonical Phase-0 facts**: window **2013–2019**; **no convite federally**; anchors
**partially overlapping, NOT independent**; **FL = 6,491** at IQR threshold **32**;
**item-group NOT_OBSERVED** (cells = buyer/UASG × year); **no bid tier** (Tier-2 absent, but
`menorLance`/`valorEstimado` price signals exist only at item grain).

| # | app07 claim / block | Status | Disposition |
|---|---|---|---|
| 1 | §Panel construction — 2013–2019 window, modalities 5+9999, convite extinct federally, 5 canonical parquets mirroring BEC schema | **Complementary (already correct)** | Window + convite facts are canonical; superseded by DRAFT comparative §setting + appG, which say it more precisely. **Delete the app07 prose; keep no unique content.** |
| 2 | §CADE ground truth — multi-pass linkage (BEC reuse → RAIS → RF Empresas), fuzzy 0.92, CNPJ-uniqueness, Frontal Móveis acórdão match, scope=national/state | **Complementary (method detail)** | The *linkage method* is real and worth one paragraph of provenance. But app07 **frames it as assembling ground truth** (see Falsified #1). Salvage only the linkage-provenance sentence(s) into appG §Label funnel notes; drop the "carry national+state to build a fuller universe" framing. |
| 3 | AN-001 loser-side concentration survives (AL share, FL share, tail p99/p95/max federal vs BEC) | **Superseded** | appG §Label funnel + comparative §data carry the construct-portability fact (threshold re-derived = 32, FL = 6,491). The "thicker upper tail" descriptive is harmless but redundant; not salvaged. |
| 4 | AN-004 cobidder AUC "survives above chance" (raw firm-level binary 0.x, continuous beats binary, DeLong) reported as a **headline positive result** | **FALSIFIED in framing / superseded in method** | This is the circular, opportunity-**un**adjusted reading the v22 battery exists to dismantle. The canonical verdict is: raw concentration ≈ opportunity arithmetic; within-stratum residual collapses. **Must NOT survive.** Replaced by appG §Opportunity-Adjusted Validation (label-blind / within-stratum / nested rows). |
| 5 | AN-007 boundary against direct defendants (AUC < 0.5; defendants mostly winners) | **Complementary (claim-altitude)** | This is the one genuinely *additive* headline: the structural boundary (the screen does not rank winners/defendants) replicates federally and is a clean, audit-consistent statement. **Salvage as a closing graduation row** in appG (see §3). |
| 6 | AN-006 strict prospective holdout (split 2016-12-31; BEC-style + ultra-strict variants) | **Superseded** | appG §Timing/Leakage/Label-Frozen table is the canonical, more disciplined version (label-frozen pool+score+label, entrants at zero). app07's two-variant holdout is subsumed. Not salvaged. |
| 7 | AN-014 leakage drop chain (M1→M2→M3) | **Superseded** | Folded into appG timing/leakage stage. Not salvaged. |
| 8 | AN-039 selection mechanism (cell = UASG × item-stem-first-12 × year × modality; OLS log valor item on cell FL share) | **FALSIFIED in cell definition + superseded** | Cells use **item-stem** as a margin → relies on item-group structure that is **NOT_OBSERVED federally** (Phase 0). Canonical cells are **buyer/UASG × year** (appG MEDIUM). Also "× modality" is dead (pure Pregão). **Cell definition must NOT survive.** Mechanism/price content is out of scope for the audit appendix anyway. |
| 9 | AN-040 within-cell mechanism (uses `winner_vs_ref` ≈ `log valor item` substitute; reports sign flip, band split, M1 leg replicates) | **FALSIFIED in premise / out of canonical scope** | Built on a **reference/ceiling price that does not exist federally** (app07 itself admits this at lines 293–305) and on the falsified item-stem cells. The v22 federal appendix is an **award-layer audit**, not a price-mechanism replication. Drop entirely. (If any price work is ever revived it belongs under a `menorLance`/`valorEstimado` item-grain caveat, not here.) |
| 10 | §Threshold sensitivity (IQR threshold ≠ AUC peak; sweep; continuous beats binary more federally) | **Partially complementary** | The "IQR rule is not a universal threshold; construct = rule not cutoff" point is canonical and already in the DRAFT comparative §data. The AUC-peak sweep is a circular-score artifact (same problem as #4) and should not be re-introduced as a positive operational claim. Not salvaged. |
| 11 | §Honest interpretation — "4 survive / 3 fail", "AUC ~0.92 panel-specific", "0.79–0.85 within-panel holdout", "~0.60 federal", deployment-floor framing | **FALSIFIED in headline framing** | This is the *old* "the theory survives, only calibration degrades" story built on raw circular AUCs. The v22 thesis is the **opposite altitude**: the deployable product is the **audit**, not a degraded-but-positive ranking; raw concentration is opportunity arithmetic on both platforms. **The entire survives/fails ledger as written must NOT survive.** Appendix G's graduation closing (see §3) replaces it under the correct altitude. |
| 12 | §Replication artifacts (script paths under `work/v20-comprasnet/`) | **Superseded** | Canonical paths are now `work/v22-editor/outputs/comprasnet/` (appG §Replication). app07's v20 paths are stale. Not salvaged. |

---

## 2. Decision: **GUT + DELETE app07; salvage two slivers into Appendix G**

**Decision = DELETE `sec_app07_comprasnet_submission.tex`** (mark for removal once the salvage is
folded), with **MERGE** of exactly two slivers into Appendix G — *not* COEXIST.

**Three-sentence rationale (Referee 2 voice).**
One federal appendix must carry the battery, and the worst possible referee outcome is two federal
appendices whose numbers and altitude disagree — app07's "the screen survives above chance, only the
calibration degrades" headline directly contradicts Appendix G's "the within-stratum residual
collapses; the deliverable is the audit, not a ranking," so coexistence manufactures the exact
internal inconsistency a hostile referee hunts for. app07 is additionally orphaned, macro-dead
(76 undefined `\valFed*`), and carries Phase-0-falsified scaffolding (item-stem cells, a
reference-price mechanism that does not exist federally, an "independent ground truth" framing),
so resurrecting it would mean importing disproven content. The only content with claim-altitude value
beyond Appendix G is the **per-claim graduation view** (which audit stage survives/fails federally vs.
BEC) and the **structural-boundary row** (the screen does not rank defendants/winners) — both are
folded as a closing subsection of Appendix G under the canonical deflation framing, and app07 is then
deleted.

---

## 3. Exact integration plan

### 3a. What moves where

- **SALVAGE → Appendix G, new closing subsection "Graduation: What Ports and What Deflates"**
  (written to `sec_appG_salvage_block_DRAFT.tex`):
  1. A **per-stage graduation table** keyed to the audit battery (raw concentration → label-blind →
     within-stratum → permutation → timing → boundary → negative control), with a BEC vs.
     ComprasNet "ports / deflates / boundary holds" verdict column. This is the *claim-altitude*
     descendant of app07's "survives/fails" ledger, re-pitched at the v22 altitude (deflation is the
     finding, not a degraded positive). All cells `\valTODO` with `% TODO_NUMBER` tags mapping to
     `\valFedAud*`.
  2. The **structural-boundary statement** (AN-007): the federal score does not rank direct
     defendants (AUC ≤ chance), defendants are mostly winners — replicated federally, audit-consistent.
  3. One **linkage-provenance sentence** (salvaged from app07 §CADE ground truth, *stripped* of the
     "assembles independent ground truth" framing) noting the BEC-reuse + RAIS + RF-Empresas multi-pass
     enrichment behind the federal CADE anchors, pointing at the partially-overlapping-anchor caveat.

- **DROP / DO NOT MIGRATE:** app07 §AN-004 raw-AUC headline (#4), §AN-006/§AN-014 holdout/leakage
  chains (#6/#7, already in appG timing stage), §AN-039/§AN-040 selection + within-cell mechanism
  (#8/#9, falsified premise), §Threshold-sweep AUC-peak operational claim (#10), §Honest-interpretation
  survives/fails ledger as written (#11), §Replication v20 paths (#12).

### 3b. `\valFed*` → `\valFedAud*` macro disposition

app07's 76 `\valFed*` macros are **all undefined and all die** with the file. The federal numbers live
exclusively in the new `\valFedAud*` namespace (appG) + the handful of plain `\valFed*` the DRAFT
comparative *re-introduces with explicit `% TODO_NUMBER` bindings* (e.g. `\valFedPanelRows`,
`\valFedFirms`, `\valFedAlwaysLosers`, `\valFedFLthreshold`, `\valFedFLcount`). Mapping:

| app07 `\valFed*` (dies) | Canonical replacement | Notes |
|---|---|---|
| `\valFedPanelRows`, `\valFedFirms`, `\valFedAlwaysLosers`, `\valFedFLthreshold`, `\valFedFLcount` | **same names, re-bound** via `sec_comparative_DRAFT.tex` TODO tags (51.0M / 92,600 / 35,943 / 32 / 6,491) | Re-used, not migrated to `Aud`. The comparative section already owns these. |
| `\valFedAucBinary*`, `\valFedAucContinuous*`, `\valFedDelong*` (AN-004 headline) | **`\valFedAudRawAUC` / `\valFedAudRawFLAUC`** (S0 rows, appG control-function table) | Re-pitched as "raw, pre-adjustment" — never as a standalone positive. DeLong increment becomes `\valFedAudNestedIncrement`/`\valFedAudNestedP`. |
| `\valFedDirectsBinary*`, `\valFedDirectsContinuous*`, `\valFedDirectsWinshare` (AN-007 boundary) | **`\valFedAudBoundaryAUC` / `\valFedAudDirectsWinshare`** (NEW, salvage block) | New `Aud` macros; lead binds after run chain. |
| `\valFedHoldout*`, `\valFedLeakageM*` (AN-006/014) | **`\valFedAudFrozenProspAUC` / `\valFedAudStrictFullAUC` / `\valFedAudFrozenRetroAUC`** (appG timing table) | Subsumed by the canonical timing stage. |
| `\valFedSelection*`, `\valFedMech*` (AN-039/040) | **none — die** | Falsified premise (item-stem cells / nonexistent reference price). No `Aud` successor. |
| `\valFedPeakThreshold`, `\valFedPeakAUC`, `\valFedAucDrop`, `\valFedTc*` | **none — die** (or, if the tail-descriptive is wanted, fold into appG funnel notes) | AUC-peak operational claim dropped as circular. |
| `\valFedCade*`, `\valFedRaizes*`, `\valFedAnchored*`, `\valFedCobidders`, `\valFedALcobidders`, `\valFedFLcobidders` | **`\valFedAudCases` / `\valFedAudCobiddersAll` / `\valFedAudCobiddersBroadAL`** (appG funnel) + the one salvaged provenance sentence | Linkage counts re-expressed in the funnel; provenance prose salvaged, framing stripped. |

### 3c. Deletion mechanics (for the lead, post-salvage) — ✅ DONE 2026-06-05

1. ✅ Salvage block (§3a) folded into `sec_appG_federal_DRAFT.tex` before `\subsection{Replication}`.
2. ✅ `git rm submission_clean/sec_app07_comprasnet_submission.tex`.
3. ✅ Grep-verified: zero live `sec_app07` references remain. Residual mentions are only the
   provenance comments inside `sec_appG_federal_DRAFT.tex`/`sec_appG_salvage_block`(deleted) and the
   two doc annotations, all now marked "DELETED 2026-06-05"; no live `\input`/`\include` ever existed.
4. ✅ No master edit needed (app07 was never `\input`).

---

## 4. Falsified-claims list (Phase-0-disproved — these must NEVER survive into the rebuilt appendix)

1. **"Independent / fuller cartel universe."** app07 frames the federal CADE anchors as a second
   ground truth assembled from national + state roots. **Phase 0: anchors are the SAME, partially
   overlapping BEC cases — NOT independent.** Canonical wording = "partially overlapping legal anchors,
   not a fresh cartel population; tests portability, not an independent universe."
2. **Window 2009–2019.** The federal series begins **2013-01**; the panel is **2013–2019** only.
   (app07's body already says 2013–2019 — keep it that way; the plan header's "2009–2019" is stale.)
3. **Convite present federally.** Convite is **extinct federally** (~5 participations/month). No
   sealed-bid modality, no modality stratification.
4. **Item-group / item-stem cells.** AN-039/040 cells use item-stem-first-12-char as a margin.
   **Item-group is NOT_OBSERVED federally** (buyer-embedded codes). Canonical cells = **buyer/UASG × year**.
5. **`winner_vs_ref` price mechanism federally.** AN-040 substitutes `log(valor item)` for a
   reference/ceiling price that **does not exist federally** (Tier-2 absent). No reference-normalised
   within-cell mechanism can be identified; only `menorLance`/`valorEstimado` at item grain exist, and
   they are out of scope for the award-layer audit.
6. **Raw cobidder AUC as a headline "survives above chance" positive (AN-004) and the
   "theory survives, calibration degrades" survives/fails ledger.** The v22 audit shows raw
   concentration ≈ opportunity arithmetic; the within-stratum residual is the real test. Reporting raw
   AUC as the federal deliverable is the circular reading the battery refutes.
7. **FL count / threshold drift.** Canonical federal **FL = 6,491** at IQR threshold **32**
   (not 6,303). The construct is the *rule* (median + 1.5·IQR), re-estimated, not the transported cutoff.
8. **Stale artifact paths.** `work/v20-comprasnet/...` → canonical is `work/v22-editor/outputs/comprasnet/`.

---

## 5. Files written by this memo task

- `docs/jleo_rr_revision/sec_app07_reconciliation_memo.md` (this file)
- ~~`submission_clean/sec_appG_salvage_block_DRAFT.tex`~~ (merged into
  `sec_appG_federal_DRAFT.tex` and DELETED 2026-06-05 — see DECISION EXECUTED block above)
