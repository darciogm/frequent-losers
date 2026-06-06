# Site updates — v23 (ComprasNet two-platform extension) — DRAFT

> **Status: READY-TO-PUBLISH-AFTER-INTEGRATION (text drafting only).**
> Prepared by Mr. Frequent Losers (co-author mode), 2026-06-05. CONDITIONAL on the
> provisional federal verdict **Draft A** (deflation replicates; dual framing per A3).
>
> **PUBLISH GATE — do not deploy any of this until the manuscript catches up.** The site
> mirrors `work/v22-editor/submission_clean/` and **the paper wins on divergence**. None of
> the four blocks below may go live until the federal numbers are (a) bound into
> `values.tex` as `\valFedAud*` macros with `% src:` comments per the protocol in
> `NEW_NUMBERS_MAP_COMPRASNET.md`, (b) integrated into `sec_comparative_DRAFT.tex` /
> `sec_appG_federal_DRAFT.tex`, and (c) compiled clean (0 undefined refs). Until then this
> file is a staging document, not a deploy target. **Do NOT edit the live site repo from
> this file.**
>
> **Number provenance.** Every figure below is sourced from the verified triage docs
> (`outputs/comprasnet/diagnostics/early_triage_00_01.md`, `…_03.md`, `…_04.md`) and
> `NEW_NUMBERS_MAP_COMPRASNET.md`. Zero invention. Cells that depend on outputs not yet
> read from their named CSV (the opportunity-adjusted Group-3 block + armor pack) are
> marked **`PENDING (12/06 outputs)`** and MUST NOT be filled from logs.

---

## Number ledger used in this draft (verified, post-18:18 target-quality fix)

| Quantity | Value | Source |
|---|---|---|
| Panel participation rows | 51.0M | NEW_NUMBERS_MAP_COMPRASNET §Universe (`\valFedPanelRows`, draft-cited) |
| Distinct firms | 92,600 | NEW_NUMBERS_MAP_COMPRASNET §Universe (`\valFedFirms`) |
| Always-losers (candidate pool) | 35,943 | targets/canonical_target_counts.csv `[built]` |
| FL cut (IQR rule, re-estimated) | 32 (≥) | NEW_NUMBERS_MAP_COMPRASNET §Universe; *not transported from BEC's 14* |
| FL count (above cut) | 6,491 | targets/canonical_target_counts.csv `[built]` |
| Cobidders — broad rule (all) | 3,850 | early_triage_00_01 post-fix (was 3,851 pre-sentinel-drop) |
| Cobidders — broad-AL (MAIN target) | 195 | early_triage_00_01 post-fix (was 196; mirrors BEC 651) |
| FL composition of broad-AL | 94 FL / 101 non-FL | early_triage_00_01 post-fix |
| Numbered CADE cases (federal) | 7 | early_triage_00_01 (1 unnumbered TI/DF case excluded) |
| Platform-active direct defendants | 25 establishments | early_triage_00_01 / _03 |
| Window | 2013–2019 | all triage docs |
| Modality | pure Pregão (~15% regular + ~85% SRP) | NEW_NUMBERS_MAP_COMPRASNET §construction |
| Raw award-layer ROC-AUC (log T) | 0.744 | early_triage_04 LOCO table (federal full) |
| Strict training-AL continuous ROC | 0.666 (BEC twin 0.684) | early_triage_03 T1 |
| Strict full-universe ROC (entrants @0) | 0.489 (BEC 0.474) | early_triage_03 T1 |
| Worst rolling-origin year ROC | 0.480 (2015) | early_triage_03 T2 |
| Direct-defendant FL-binary AUC | 0.465–0.503 (≈ chance) | early_triage_03 T3 |
| Top-case share of positives | 35.4% (69/195) | early_triage_04 |
| Top-two share of positives (link-row) | 64.4% (132/205) | early_triage_04 |
| Top-case share of TP@500 | 87.5% (7 of 8 TP) | early_triage_04 |
| LOCO ROC drop-largest | 0.744 → 0.744 (robust) | early_triage_04 |
| Clustered-RI p (ROC ordering) | 0.001 | early_triage_04 |
| Clustered-RI p (case-coverage breadth) | 0.487 (NS) | early_triage_04 |
| contact≥2 sensitivity N+ | 108 of 195 (55.4% retained) | early_triage_00_01 POST-02b |
| **Opportunity-adjusted within-stratum residual AUC (federal)** | **PENDING (12/06 outputs)** | Group-3 twin not yet read from CSV |
| **Exposure-only AUC (federal, within-exposed base)** | **PENDING (12/06 outputs)** | Group-3 twin |
| **Nested increment + DeLong p (federal)** | **PENDING (12/06 outputs)** | Group-3 twin |
| **Matched-permutation p (federal)** | **PENDING (12/06 outputs)** | Group-3/-5 twin |
| **Label-blind opportunity expectation E (federal)** | **PENDING (12/06 outputs)** | armor pack |
| **Power curve @ within-AUC 0.55 (federal)** | **PENDING (12/06 outputs)** | armor pack |
| **Frozen-timing prospective AUC + pool N (federal)** | **PENDING (12/06 outputs)** | armor pack (`audit_armor/` not built yet) |

---

# BLOCK 1 — Changelog entry (full text, ready to paste at top of `docs/changelog.md`)

```markdown
## v23 — The Audit on a Second Platform (ComprasNet) — <DATE PLACEHOLDER: 2026-06-XX>

**Headline:** the award-layer evidence-triage protocol is now demonstrated on **two
independent procurement platforms**. Beyond São Paulo's BEC (2009–2019), we re-run the
full audit battery on the **federal ComprasNet** platform (2013–2019, pure Pregão) against
the same family of CADE cartel anchors. The federal leg **replicates the deflation
anatomy**: under opportunity adjustment the screen's discriminating power collapses toward
the exposure axis — exposure-only discrimination is ≥ the raw-score discrimination, and the
within-stratum residual (score net of defendant-contact exposure) falls to chance. The
construct **ports and deflates; it does not break.** The strict-temporal carrier replicates
too: the prospective ranking collapses outside the incumbent pool on both platforms
(strict full-universe ROC 0.489 federal / 0.474 BEC), while the incumbent-pool continuous
score deflates in the same direction and magnitude class (0.666 federal vs 0.684 BEC).

**What this adds — and what it does NOT.** This is a *second-platform demonstration of the
audit protocol*, not yet a promotion to **Confirmed**. The federal CADE anchors **partially
overlap** the BEC portfolio (same cartels, different establishments and tender footprints),
so the two legs are correlated, not fully independent. Federal panel: **51.0M** participation
rows, **92,600** firms, **35,943** always-losers, FL cut re-estimated at **32** (≥; *not*
transported from BEC's 14), **6,491** federal frequent losers. Main target: **3,850** broad-rule
cobidders → **195** broad-AL cobidders (mirrors BEC's 651), of which **94** are FL and **101**
non-FL, anchored on **7 numbered** CADE cases and **25** platform-active direct-defendant
establishments.

**Honest caveats (front-paged, not hidden):**

- **Partially overlapping legal anchors.** The 7 federal cases are the *same cartels* as the
  BEC portfolio, establishment-anchored at the federal level. This is a robustness leg under
  partially correlated ground truth, not a clean out-of-sample replication on an unrelated
  cartel set.
- **Shorter window (2013–2019).** Four training years federally vs eight on BEC. The
  strict-timing rows that carry the prospective claim are robust to the short pre-period
  (worst rolling-origin year 0.480 federal, no worse than BEC's 0.446), but the federal
  *frozen-pool* prospective row may not clear the N≥120 floor and is reported as such.
- **Pure Pregão.** Convite is extinct federally, so the federal leg cannot reproduce the
  BEC modality stratification (convite vs pregão). No federal bid microdata exists, so no
  bid-layer/Imhof forensic benchmark is constructible from the public federal data.
- **Case concentration is worse than on BEC.** The federal positive base is more
  cartel-concentrated: top case 35.4% of positives, **top-two 64.4%**, and the realized
  top-500 detections are **87.5% one case**. The clustered-randomization *ordering* test is
  robust (leaving out the largest case leaves ROC-AUC 0.744 → 0.744; ordering p = 0.001),
  but the operational precision/recall-at-k ranking is one-to-two-cartel-dominated and the
  case-coverage-breadth test is non-significant (p = 0.487). We therefore frame the federal
  leg as a **single-system, concentrated-anchor stress test** of the protocol, not as a
  multi-case operational generalization. Both the breadth disclosure and the per-case
  leave-one-case-out table appear in Appendix G.
- **Contact≥2 robustness.** Restricting cobidders to ≥2 co-participations with a direct
  defendant (108 of 195 survive) does not overturn the deflation reading; the within-stratum
  residual stays below chance and the matched-permutation p stays non-significant — removing
  the "loose 1-contact rule" objection.

**New site material (this version):**

- **AN-043 — Federal opportunity-adjusted validation (ComprasNet).** The two-platform audit
  anatomy with the federal numbers; opportunity-adjusted cells marked PENDING until the
  Group-3/armor outputs are read from their named CSVs.
- **Scorecard:** new **cross-platform portability** row, verdict *"deflation replicates
  (provisional)"* — explicitly NOT a promotion to Confirmed (partially overlapping anchors).
- Landing page: two-platform extension announced, with the partially-overlapping-anchors
  caveat stated in the text.

*Manuscript home of these numbers:* the comparative two-platform table
(`sec_comparative_DRAFT.tex`) and Appendix G (`sec_appG_federal_DRAFT.tex`); the federal
column is bound via the `\valFedAud*` macro namespace. **This changelog entry must not go
live before those drafts are integrated and compiled.**
```

---

# BLOCK 2 — New AN page skeleton: `docs/analyses/an-043-federal-opportunity-adjusted-validation.md`

> File path on integration: `docs/analyses/an-043-federal-opportunity-adjusted-validation.md`.
> Last existing AN is AN-042, so the federal page is **AN-043**. Add to the analyses index
> and to the relevant hypothesis Evidence tables (H1/H3/H4) on integration.

```markdown
---
paper: frequent-losers
id: an-043
hypothesis: exposure-discipline
type: validation
question: Does the award-layer evidence-triage protocol replicate on a SECOND, independent procurement platform? On federal ComprasNet (2013–2019, pure Pregão) against the same family of CADE cartel anchors, does the opportunity-adjusted deflation anatomy reproduce — exposure-only discrimination ≥ raw, within-stratum residual collapsing to chance — and does the strict-temporal prospective collapse port?
status: provisional
status_date: 2026-06-05
confidence: yellow
claim-altitude: cross-platform robustness (provisional; partially overlapping anchors)
headline: "PROVISIONAL — deflation replicates on the federal platform. ComprasNet (2013–2019, 51.0M participation rows, 92,600 firms, 35,943 always-losers, FL cut re-estimated at 32, 6,491 federal frequent losers) yields 195 broad-AL cobidders (94 FL / 101 non-FL) anchored on 7 numbered CADE cases and 25 platform-active direct-defendant establishments. The raw award-layer ROC-AUC is 0.744; the strict training-AL continuous ROC is 0.666 (BEC twin 0.684) and the strict full-universe ROC is 0.489 (BEC 0.474) — the prospective ranking collapses outside the incumbent pool on both platforms. The opportunity-adjusted block (exposure-only ≥ raw; within-stratum residual at chance; nested increment ~0; matched-permutation NS) is PENDING the Group-3/armor outputs and will be filled only from the named CSVs. Direct-defendant FL-binary AUC is ≈ chance (0.465–0.503), reproducing the loser-side scope by design. Case concentration is worse than BEC (top-two 64.4%, TP@500 87.5% one case); the ROC ordering is LOCO-robust (0.744→0.744, RI p=0.001) but operational k-metrics are one-cartel-dominated — the federal leg is a concentrated-anchor stress test, not a multi-case generalization. Anchors partially overlap BEC, so this is a provisional robustness leg, not a promotion to Confirmed."
created: 2026-06-05
script: scripts/comprasnet/00_build_canonical_validation_targets.R, 01_label_funnel_reconciliation.R, 02_opportunity_adjusted_validation.R, 02b_opportunity_sensitivity_contact2.R, 03_timing_case_holdout_validation.R, 04_case_holdout_dominance.R (--source=comprasnet)
target: outputs/comprasnet/tables/table_C_opportunity_adjusted_validation.csv + table_D_opportunity_permutation_validation.csv + table_G/table_H + outputs/comprasnet/diagnostics/audit_armor/* (PENDING)
tags: ["H:exposure-discipline", "H:cobidder-concentration", "H:timing-discipline", comprasnet, federal, cross-platform, opportunity-adjustment, deflation, replication, provisional]
design:
  sample: "Federal ComprasNet panel, 2013–2019, pure Pregão (~15% regular + ~85% SRP); convite extinct federally. Always-loser candidate pool 35,943; FL cut re-estimated by the same median+1.5·IQR rule (NOT transported) ⇒ threshold 32 ⇒ 6,491 FL. Main target = 195 broad-AL cobidders co-participating with direct CADE defendants (broad-rule pre-AL set = 3,850). Anchors: 7 numbered CADE cases (same cartels as BEC, establishment-anchored), 25 platform-active direct-defendant establishments; 1 unnumbered TI/DF summary case excluded; sentinel CNPJ 000000000000-2 dropped in the 2026-06-05 target-quality fix."
  specification: "Mirrors the BEC audit battery: (S0) raw award-layer score ROC/PR-AUC; (S2) exposure-only logit on the exposed subsample; WITHIN-STRATUM residual = score | opportunity cell (MEDIUM = year × buyer/UASG, since item-group is buyer-collinear federally; COARSE = year only; STRICT = item_code × year × UASG); NESTED exposure→exposure+score increment with DeLong; matched-permutation (within-strata shuffle, PR-AUC); strict holdout train ≤2016 → test 2017–2019; rolling-origin 6 origins; leave-one-case-out (LOCO) + clustered randomization inference. Contact≥2 sensitivity restricts cobidders to ≥2 co-participations with a direct defendant."
  notes: "Construction differs from BEC (window, FL cut, opportunity-cell margins, pure-Pregão, partially overlapping anchors); absolute-level gaps are EXPECTED and are not, by themselves, findings. Read every federal–BEC delta against the construction-differences header in NEW_NUMBERS_MAP_COMPRASNET.md."
---

# AN-043: Federal opportunity-adjusted validation (ComprasNet) — does the audit port?

!!! abstract "Intuition (plain-language)"
    A single platform can flatter a screen: maybe São Paulo's BEC has some quirk that makes
    loser-side firms cluster around cartels. The honest test is to take the *same audit
    protocol* — not the same numbers — to a completely separate procurement system and ask
    whether the screen survives the same disciplines. We re-run the battery on federal
    ComprasNet, where the firms, buyers, auction rules, and even the frequent-loser cutoff
    are different. The protocol behaves identically: the raw screen ranks cobidders, but once
    we net out the simple fact that some firms had more *chances* to bid near a cartel
    (exposure), the residual signal collapses to chance — exactly as on BEC. The screen ports
    as an exposure-loaded triage tool, and the deflation that bounds its interpretation ports
    with it. Two caveats keep this provisional: the federal cartels partially overlap the BEC
    ones, and the federal positives are concentrated in one or two cases.

!!! warning "Provisional — partially overlapping anchors"
    The 7 federal CADE cases are the *same cartels* as the BEC portfolio, establishment-anchored
    at the federal level. This is a robustness leg under partially correlated ground truth, not a
    clean out-of-sample replication on an unrelated cartel set. It does **not** by itself promote
    any hypothesis to **Confirmed**.

## Question

Does the award-layer triage protocol — and, crucially, its **deflation anatomy** under
opportunity adjustment — reproduce on a second, structurally different procurement platform?

## Design

- **Panel.** Federal ComprasNet, 2013–2019, **51.0M** participation rows, **92,600** firms,
  pure Pregão (~15% regular + ~85% SRP); convite is extinct federally.
- **Universe.** Always-loser candidate pool **35,943**; FL cut **re-estimated** by the same
  median + 1.5·IQR rule (not transported) ⇒ threshold **32** ⇒ **6,491** federal frequent
  losers.
- **Target.** **3,850** broad-rule cobidders → **195** broad-AL cobidders (mirrors BEC's
  651), of which **94** FL and **101** non-FL; anchored on **7 numbered** CADE cases and
  **25** platform-active direct-defendant establishments.
- **Battery.** Raw score, exposure-only logit, within-stratum residual (MEDIUM =
  year × buyer/UASG; item-group margin not observed federally), nested increment + DeLong,
  matched permutation, strict holdout (≤2016 → 2017–2019), rolling-origin, LOCO + clustered RI.

## Results

### Universe and target (built)

| Quantity | Federal | BEC twin |
|---|--:|--:|
| Participation rows | 51.0M | 1.65M (analysis sample) |
| Firms | 92,600 | 41,444 |
| Always-losers | 35,943 | 16,843 |
| FL cut (IQR rule) | 32 (≥) | 14 (≥) |
| Frequent losers | 6,491 | 2,735 |
| Broad-AL cobidders (MAIN) | 195 | 651 |
| — FL / non-FL composition | 94 / 101 | 341 / 310 |
| Numbered CADE cases | 7 | 12 |
| Platform-active direct defendants | 25 (estabs) | 41 |

### Raw + strict-temporal (read from CSV; verified in triage 03/04)

| Row (estimand + sample) | Federal | BEC twin |
|---|--:|--:|
| Raw award-layer ROC-AUC (log T, full universe) | 0.744 | 0.761 |
| Strict training-AL continuous ROC (incumbents) | 0.666 | 0.684 |
| Strict full-universe ROC (entrants @ 0) | 0.489 | 0.474 |
| Strict training-AL FL-binary ROC | 0.634 | ≈0.65 |
| Worst rolling-origin year ROC | 0.480 (2015) | 0.446 (2015) |
| Direct-defendant FL-binary AUC (scope-by-design) | 0.465–0.503 | ≈ chance |
| Entrant share among positives | 30.8% | 30.8% |

> *Estimand wall (carry into every caption).* The raw/strict-timing rows above measure the
> **temporal stability of the unadjusted screen** over the firm universe. They are a
> **different estimand on a different sample** than the opportunity-adjusted within-cell rows
> below. A high raw-timing AUC and a null adjusted increment are **mutually consistent, not
> contradictory** — the timing rows are marginal discrimination; the deflation rows are
> residual discrimination *after* netting out exposure within matched cells.

### Opportunity-adjusted deflation block — **PENDING (12/06 outputs)**

Fill ONLY from the named CSVs (`table_C_opportunity_adjusted_validation.csv`,
`table_D_opportunity_permutation_validation.csv`, `audit_armor/*`), never from logs. Provisional
Draft-A expectation per the triage: exposure-only ≥ raw; within-stratum residual ≈ chance;
nested increment ~0 with non-significant DeLong; matched-permutation p non-significant.

| Row | Federal | BEC twin |
|---|--:|--:|
| Exposure-only ROC (within-exposed base) | **PENDING (12/06 outputs)** | 0.713 |
| Within-stratum residual (score \| MEDIUM cell) | **PENDING (12/06 outputs)** | 0.471 |
| Within-stratum FL \| stratum | **PENDING (12/06 outputs)** | 0.507 |
| Nested increment (exposure→exposure+score) | **PENDING (12/06 outputs)** | +0.010 |
| Nested DeLong p | **PENDING (12/06 outputs)** | 0.013 |
| Matched-permutation p (within-strata shuffle) | **PENDING (12/06 outputs)** | 0.127 (NS) |
| Label-blind opportunity expectation E | **PENDING (12/06 outputs)** | 0.553 |
| Detection prob. @ true within-AUC 0.55 | **PENDING (12/06 outputs)** | 0.97 |
| Frozen-pool prospective ROC (N≥120 floor) | **PENDING (12/06 outputs)** | 0.713 (N=231) |

### Contact≥2 sensitivity (read from CSV; verified in triage 02b)

Restricting cobidders to ≥2 co-participations with a direct defendant retains **108 of 195**
positives (55.4%). The deflation reading holds: within-stratum residual stays below chance,
the nested increment shrinks and its DeLong p worsens, and the matched-permutation p stays
non-significant. The only material moves are pre-adjustment AUC *increases* (raw and
exposure-only rise on the cleaner, more exposure-loaded positive set) — expected under, and
supportive of, the exposure-confound interpretation.

### Case concentration (read from CSV; verified in triage 04)

| Concentration metric | Federal | Read |
|---|--:|---|
| Top-case share of positives | 35.4% (69/195) | most flattering — do not lead with it alone |
| Top-two share of positives (link-row) | 64.4% (132/205) | mandated headline disclosure |
| Top-case share of TP@500 | 87.5% (7 of 8 TP) | honest operational concentration |
| LOCO ROC drop-largest | 0.744 → 0.744 | ordering fully robust |
| Clustered-RI p (ROC ordering) | 0.001 | ordering non-random ✅ |
| Clustered-RI p (case-coverage breadth) | 0.487 (NS) | breadth NOT distinguishable from random |

## Interpretation

**The deflation ports.** On a platform with different firms, buyers, auction rules, FL cutoff
(32 vs 14), and opportunity-cell margins, the protocol behaves as on BEC: the raw screen
ranks cobidders, the prospective ranking collapses outside the incumbent pool (strict
full-universe 0.489 / 0.474), and — pending the Group-3 read — the within-stratum residual is
expected to sit at chance, with the exposure axis carrying the discrimination. The construct
**ports and deflates; it does not break.**

**Dual framing on concentration (mandatory).** The ROC *ordering* is genuinely multi-case
(LOCO-robust 0.744→0.744; RI ordering p = 0.001; LODGO clean), so the rank-ordering is not
driven by any single cartel. But the realized **operational** detections are
one-to-two-cartel-dominated (TP@500 87.5% one case; top-two 64.4%; RI breadth p = 0.487 NS).
The federal leg is therefore a **single-system, concentrated-anchor stress test** of the
protocol, NOT a multi-case operational generalization. Both numbers are disclosed.

## Bearing on hypotheses

- **H:exposure-discipline (H3).** Primary bearing — the federal deflation anatomy is the
  cross-platform replication of the exposure-discipline claim. Provisional support; not a
  promotion to Confirmed (partially overlapping anchors).
- **H:cobidder-concentration (H1).** The raw federal ranking concentrates cobidders
  (raw ROC 0.744); ordering is LOCO-robust.
- **H:timing-discipline (H4).** Strict-temporal prospective collapse ports (0.489 / 0.474);
  frozen-pool floor PENDING.
- **H:direct-defendants-null (H2).** Direct-defendant FL-binary AUC ≈ chance (0.465–0.503)
  reproduces the loser-side scope by design.

## Follow-ups

- Fill the opportunity-adjusted block from the named CSVs once the Group-3/armor outputs land
  (12/06); bind `\valFedAud*` macros with `% src:` comments; integrate the comparative table.
- Resolve the stale federal filename token (`table_D_strict_2009_2016_to_2017_2019.csv` on the
  federal run vs the expected 2013 string) before the `\valFedAudStrict*` link step.
- A genuinely independent cartel anchor (non-overlapping cases, or another jurisdiction)
  remains the path from *provisional* to **Confirmed**.
```

---

# BLOCK 3 — Scorecard addition (one row + a short note for `docs/hypotheses/index.md`)

Add a **cross-platform portability** row to the Scorecard table (after H8), and a short
paragraph under the table. The status is deliberately **NOT** "Confirmed" — partially
overlapping anchors keep it provisional.

```markdown
| [X-plat](exposure-discipline.md) | The audit protocol (and its deflation anatomy) replicates on a second, independent platform. | Federal ComprasNet (2013–2019, 51.0M rows, 35,943 always-losers, FL cut 32, 6,491 FL, 195 broad-AL cobidders): raw ROC 0.744; strict full-universe ROC 0.489 (BEC 0.474) — prospective collapse ports; strict incumbent-pool continuous 0.666 (BEC 0.684); direct-defendant FL-binary ≈ chance; opportunity-adjusted deflation block PENDING (12/06). Caveats: anchors **partially overlap** BEC; pure Pregão; case-concentrated (top-two 64.4%, TP@500 87.5% one case). | [AN-043](../analyses/an-043-federal-opportunity-adjusted-validation.md) | **deflation replicates (provisional)** |
```

**Note to append under the Scorecard** (or fold into the existing "Why not Confirmed?"
project rule):

```markdown
> **Cross-platform portability (provisional).** The federal ComprasNet leg
> ([AN-043](../analyses/an-043-federal-opportunity-adjusted-validation.md)) demonstrates the
> audit protocol — including the opportunity-adjusted deflation — on a second platform with
> different firms, buyers, auction rules, and FL cutoff. It is reported as
> **deflation replicates (provisional)**, not as a promotion to **Confirmed**, because the 7
> federal CADE anchors are the *same cartels* as the BEC portfolio (establishment-anchored),
> so the two legs are partially correlated rather than independent. A genuinely independent
> cartel anchor remains the bar for Confirmed.
```

---

# BLOCK 4 — Landing-page delta (`docs/index.md`)

Add a short callout to the **Key Findings** block (after the existing four admonitions), and
update the version tag. Language-disciplined throughout (*flags / screens / ranks*; the
partially-overlapping-anchors caveat is IN the text, not hidden).

**4a. New Key-Findings callout (insert after the `Validation architecture` note):**

```markdown
!!! abstract "Now demonstrated on two platforms"
    The award-layer triage protocol is re-run on a second, independent procurement
    platform — federal **ComprasNet** (2013–2019, pure Pregão) — against the same family of
    CADE cartel anchors. The federal leg **replicates the deflation anatomy**: the raw screen
    ranks cobidders, but once opportunity-set exposure is netted out the residual signal
    collapses to chance, exactly as on BEC. The construct **ports and deflates; it does not
    break.** This is a *provisional* robustness leg, not a promotion to "Confirmed": the
    federal CADE anchors **partially overlap** the São Paulo portfolio (same cartels,
    establishment-anchored), and the federal positive base is more case-concentrated
    (top-two cases ≈ 64% of positives). See
    [AN-043](analyses/an-043-federal-opportunity-adjusted-validation.md).
```

**4b. Version-tag update (line 20):**

```markdown
<p class="version-tag"><em>JLEO R&amp;R version &mdash; two-platform extension (BEC + ComprasNet), June 2026.</em></p>
```

> *Note:* the landing `key-result` hero number (83% / 131 of 193) stays a BEC figure — do
> not federalize the headline. The two-platform extension is announced as a robustness leg,
> not a new headline number.

---

## What remains BLOCKED on manuscript integration (the publish gate)

None of Blocks 1–4 may be deployed until ALL of the following are true:

1. **Group-3 opportunity-adjusted federal numbers read from their named CSVs** (not logs):
   `table_C_opportunity_adjusted_validation.csv`, `table_D_opportunity_permutation_validation.csv`,
   and the armor-pack outputs (`outputs/comprasnet/diagnostics/audit_armor/*`, which **do not
   exist yet** — the armor pack has not run). Until then every `PENDING (12/06 outputs)` cell
   stays PENDING; do not invent or transcribe from logs.
2. **`\valFedAud*` macros bound in `values.tex`** with full `% src:` comments per the protocol
   in `NEW_NUMBERS_MAP_COMPRASNET.md` (read file → cross-check diagnostics twin → confirm
   construction parity → bind). The two namespaces (`\valFedAud*` audit battery vs `\valFed*`
   panel descriptors) must stay separate.
3. **`sec_comparative_DRAFT.tex` + `sec_appG_federal_DRAFT.tex` integrated** into the
   submission, `\valTODO` placeholders replaced, comparative table reading both columns from
   `values.tex` (no hard-coded literals), appendix-before-paper compile, **0 undefined refs**.
4. **Stale federal filename token resolved** (`…2009_2016…` on the federal run vs the expected
   `…2013_2016…`) so the `\valFedAudStrict*` link step finds the file.
5. **Federal RI table path fixed** (script 04 wrote it flat under `comprasnet/tables/`; the
   fill spec / numbers map expects an `appendix/` subdir) and the fill report re-run (the
   19:01 report predates the 19:41 run of script 04, so Group-8 rows still read "file not
   found").
6. **Manuscript catches up first.** The site mirrors `submission_clean/` and **the paper wins
   on divergence.** The changelog/AN/scorecard/landing text above must not assert anything the
   integrated manuscript does not yet say. Publish only after the federal comparative section
   is in the compiled paper.

Until items 1–6 clear, this document is a staging draft. **Do not deploy. Do not edit the
live site repo.**
