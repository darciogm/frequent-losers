# NEW NUMBERS MAP — BEC↔ComprasNet side-by-side delta table (R3 verification gate)

> **CHANGELOG 2026-06-05 (target-quality fix, post 18:18 rerun).** Federal canonical
> counts updated after the sentinel CNPJ `000000000000-2` was dropped from the cobidder
> builder: cobidders all **3,851→3,850**; broad-AL positives **196→195**; FL composition of
> broad-AL **95→94** (non-FL stays 101); conservative broad-AL 171 unchanged. D-i rebuild
> delta is now PROVEN as TI/DF-exclusion = 313 cobidders (26 AL) + 1 junk CNPJ; the
> establishment-vs-raiz anchoring grain contributes **0** (v3 reproduced bit-for-bit when
> TI/DF reinstated) — earlier "estab-anchored rebuild" attribution is retired.

**Purpose.** Authoritative skeleton for the two-platform comparative numbers. The **BEC column is
PRE-FILLED** from canonical sources (each row cites BOTH the `values.tex` macro AND the regenerated
output file). The **ComprasNet column is a named slot**: the EXACT `outputs/comprasnet/...` file the
running federal chain will write, plus the proposed `\valFedAud*` macro from the comparative skeleton.

**Do not transcribe federal numbers from logs.** When the chain finishes, fill each slot ONLY by
reading the named output file, double-check against the diagnostics CSV, then bind the macro in
`values.tex` with a `% src:` comment (protocol at the bottom of this file).

**Macro namespace.** Both draft tex files (`sec_comparative_DRAFT.tex` and `sec_appG_federal_DRAFT.tex`)
use a single consistent federal namespace: `\valFedAud*` (distinct from the five `\valFed*`
panel/universe descriptor macros). **No namespace mismatch between the two
drafts** — verified row by row (see findings). *Note: the legacy `\valFed*` replication macros
formerly lived in `sec_app07_comprasnet_submission.tex`, which was DELETED 2026-06-05 (orphan,
gutted; the two salvageable slivers merged into `sec_appG_federal_DRAFT.tex`). The five `\valFed*`
universe macros remain and are now referenced only by the comparative + appG drafts.*

**NEW macro added 2026-06-06 (armor pack landed).** `\valFedAudPowerSixty` — federal detection
probability at injected within-AUC 0.60. **Src spec:**
`outputs/comprasnet/diagnostics/audit_armor/permutation_power_curve.csv :: 0.6 rejection_rate_alpha05`
= **0.90**. Carried as the second value of the dual power cell (row 6) in `sec_comparative_DRAFT.tex`,
alongside `\valFedAudPowerFive` (=0.35 @0.55). Federal armor literal on disk:
`\valArmorPowerTen`=0.90 in `audit_armor_macros.tex` (rebind into `\valFedAudPowerSixty`).

**Already-built federal targets.** Phase-1 funnel/universe targets are ALREADY materialized in
`outputs/comprasnet/targets/canonical_target_counts.csv` and `canonical_case_labels.csv`, so the
label-funnel and universe rows below carry the federal value in brackets `[built: …]`. The
opportunity / timing / power / LOCO / negative-control / armor rows are PENDING the running chain
(scripts 02+ federal twins) and carry `PENDING` in the federal value column.

---

## Construction differences — read every delta against this header

The two platforms are NOT the same experiment. Every row below must be read against these
construction differences; absolute-level gaps are expected and are not, by themselves, findings.

| Dimension | BEC–SP | ComprasNet (federal) |
|---|---|---|
| Observable window | 2009–2019 | **2013–2019** (federal-overlap window) |
| FL cut (IQR rule, same rule both) | median+1.5·IQR ⇒ **14** (≥) | median+1.5·IQR ⇒ **32** (≥) — *re-estimated, not transported* |
| MEDIUM opportunity cell | year × buyer (PBU) × item-group | **year × buyer (UASG)** — item-group margin not observed federally |
| COARSE opportunity cell | item-group × year | **year only** (no shared item classification) |
| STRICT opportunity cell | item_code × year × PBU | item_code × year × UASG |
| Modality margin | convite (sealed) + pregão | **pure pregão** (~15% regular + ~85% SRP); convite extinct federally → no modality stratification |
| CADE anchors | 12-case portfolio, BEC-active | **7 numbered cases** (same cases, **partially overlapping**), establishment-anchored CNPJ; 1 unnumbered summary case excluded; TI/DF defendants excluded |
| Cobidder label (broad AL) | **651** | **195** (federal broad-AL cobidders) |
| Static archived comparison rows | 193 (dead/circular) | 4,164 (internal only; never a label) |
| Bid tier | LANCES bid ladder present | **absent** — no federal bid microdata; no bid-layer forensic / Imhof benchmark constructible from public data |

**Cobidder magnitude note.** The "3,850 federal cobidders" cited in `sec_comparative_DRAFT.tex`
line 97 (`\valFedAudCobiddersAll`) is the broad-RULE cobidder set BEFORE the always-loser restriction;
the **195** figure (`\valFedAudCobiddersBroadAL`) is the broad-AL-restricted main target that mirrors
the BEC 651. (Both dropped by 1 in the 2026-06-05 target-quality fix that removed the all-zeros
sentinel CNPJ `000000000000-2`.) The draft text earlier (line 70–98) also names placeholders `\valFedPanelRows (51.0M)`,
`\valFedFirms (92,600)`, `\valFedAlwaysLosers (35,943)`, `\valFedFLthreshold (32)`,
`\valFedFLcount (6,491)` in the `\valFed*` (non-Aud) namespace — those are the panel/universe
descriptors, distinct from the `\valFedAud*` audit-battery macros. See namespace finding below.

---

## ROW GROUP 1 — Label-construction funnel

BEC source files: `outputs/targets/canonical_target_counts.csv` + `values.tex`.
Federal source files (built): `outputs/comprasnet/targets/canonical_target_counts.csv` +
`outputs/comprasnet/tables/table_A_label_funnel.csv`.

| Row | BEC value | BEC source (file + macro) | Federal slot (file) | Federal `\valFedAud*` macro |
|---|---|---|---|---|
| CADE cases (numbered portfolio) | 12 | `canonical_target_counts.csv::cade_cases` ; `\valFunnel*` family / `\valDirectCADE` context | `outputs/comprasnet/targets/canonical_target_counts.csv::cade_cases` `[built: 7]` | `\valFedAudCases` |
| Legal direct defendants (crossmatch) | 48 | `canonical_target_counts.csv::A_direct_defendants_crossmatch` ; `\valDirectCADE`=47 (cited) | `…/canonical_target_counts.csv::A_direct_defendants_crossmatch` `[built: 25]` | `\valFedAudLegalDef` |
| Platform-active direct defendants | 41 | `canonical_target_counts.csv::A_direct_defendants_bec_active` ; `\valFunnelDirectActiveFTM`=41 | `…/canonical_target_counts.csv::A_direct_defendants_bec_active` `[built: 25]` | `\valFedAudFedActiveDef` |
| Cobidders — broad rule (all) | n/a (BEC reports broad-AL only) | — (BEC has no separate pre-AL broad count in canonical_target_counts) | `outputs/comprasnet/cache/canonical_cobidders_broad.csv` (row count) `[PENDING confirm; draft cites 3,850]` | `\valFedAudCobiddersAll` |
| Cobidders — broad-AL (MAIN target) | **651** | `canonical_target_counts.csv::B_broad_AL_cobidders_MAIN` ; `\valMainCobidders`=651 / `\valCobidders`=651 | `…/canonical_target_counts.csv::B_broad_AL_cobidders_MAIN` `[built: 195]` | `\valFedAudCobiddersBroadAL` |
| Cobidders — conservative (broad-AL, pre-cutoff) | 208 | `canonical_target_counts.csv::D_conservative_broad_AL_cobidders` ; `\valFunnelConsALcob`=208 | `…/canonical_target_counts.csv::D_conservative_broad_AL_cobidders` `[built: 171]` | `\valFedAudConsBroadAL` |
| Conservative platform-active defendants | 16 | `canonical_target_counts.csv::D_conservative_defendants_bec_active` ; `\valFunnelConsFD`=19 (crossmatch) | `…/canonical_target_counts.csv::D_conservative_defendants_bec_active` `[built: 20]` | `\valFedAudConsFedDef` |
| Composition: FL among positives | 341 | `canonical_target_counts.csv::B_composition_FL` ; `\valMainCobFL`=341 | `…/canonical_target_counts.csv::B_composition_FL` `[built: 94]` | `\valFedAudCompFL` |
| Composition: non-FL among positives | 310 | `canonical_target_counts.csv::B_composition_nonFL` ; `\valMainCobNonFL`=310 | `…/canonical_target_counts.csv::B_composition_nonFL` `[built: 101]` | `\valFedAudCompNonFL` |
| Defendant tender-items (anchor set) | 52,013 | `canonical_target_counts.csv::defendant_tender_items` ; `\valFunnelDefItems`=52013 | `…/canonical_target_counts.csv::defendant_tender_items` `[built: 31,200]` | `\valFedAudDefItems` |

---

## ROW GROUP 2 — Universe

BEC source: `values.tex` head + `outputs/targets/canonical_target_counts.csv`.
Federal (built): `outputs/comprasnet/targets/canonical_target_counts.csv`.

| Row | BEC value | BEC source (file + macro) | Federal slot (file) | Federal macro |
|---|---|---|---|---|
| Panel participation rows | (not in canonical CSV) | `\valSampleNfull`=1,654,447 (analysis sample, not raw panel) | `outputs/comprasnet/diagnostics/phase0_g2_panel_semantics.csv` `[draft cites 51.0M]` | `\valFedPanelRows` (non-Aud) |
| Distinct firms | 41,444 | `\valBECfirms`=41,444 | `outputs/comprasnet/diagnostics/phase0_g5_al_universe.csv` `[draft cites 92,600]` | `\valFedFirms` (non-Aud) |
| Always-losers (candidate pool) | **16,843** | `canonical_target_counts.csv::universe_always_losers` ; `\valAlwaysLosers`=16,843 | `…/canonical_target_counts.csv::universe_always_losers` `[built: 35,943]` | `\valFedAlwaysLosers` (non-Aud) |
| FL cut (IQR threshold) | **14** | `\valThreshold`=14 ; `output/threshold_table_q3iqr/threshold_table_q3iqr.csv::median_plus_1.5_iqr` | `outputs/comprasnet/diagnostics/phase0_g5_al_universe.csv` (threshold field) `[draft cites 32]` | `\valFedFLthreshold` (non-Aud) |
| FL count (above cut) | **2,735** | `canonical_target_counts.csv::universe_FL14` ; `\valFL`=2,735 | `…/canonical_target_counts.csv::universe_FL14` `[built: 6,491]` | `\valFedFLcount` (non-Aud) |

---

## ROW GROUP 3 — Opportunity-adjusted validation (the headline deflation)

BEC source: `outputs/tables/main/table_C_opportunity_adjusted_validation.csv` (+ `_D` permutation).
Federal slot (PENDING): `outputs/comprasnet/tables/table_C_opportunity_adjusted_validation.csv`
and `…/table_D_opportunity_permutation_validation.csv` (chain twins).

| Row | BEC value | BEC source (file + macro) | Federal slot (file) | Federal macro |
|---|---|---|---|---|
| Raw award-layer ROC-AUC (log T) | **0.761** | `table_C…csv::S0_raw_score roc_auc` ; `\valExpRawScoreAUC`=0.761 | `outputs/comprasnet/tables/table_C_opportunity_adjusted_validation.csv::S0_raw_score roc_auc` `[PENDING]` | `\valFedAudRawAUC` |
| Raw award-layer PR-AUC | 0.143 | `table_C…csv::S0_raw_score pr_auc` ; `\valExpRawScorePRAUC`=0.143 | `…/table_C…csv::S0_raw_score pr_auc` `[PENDING]` | `\valFedAudRawPRAUC` |
| Raw FL (binary cut) ROC | 0.688 | `table_C…csv::S0_raw_fl14 roc_auc` (NEW_NUMBERS_MAP row) | `…/table_C…csv::S0_raw_fl14 roc_auc` `[PENDING]` | `\valFedAudRawFLAUC` |
| Raw FL PR-AUC | 0.097 | `table_C…csv::S0_raw_fl14 pr_auc` ; `\valExpRawFLPRAUC`=0.097 | `…/table_C…csv::S0_raw_fl14 pr_auc` `[PENDING]` | `\valFedAudRawFLPRAUC` |
| Exposure-only logit ROC (exposed subsample) | 0.713 | `table_C…csv::S2_exposure_only_logit roc` ; `\valExpOnlyAUC`=0.713 | `…/table_C…csv::S2_exposure_only_logit roc` `[PENDING]` | `\valFedAudExpOnlyAUC` |
| Exposure-only PR-AUC | 0.300 | `table_C…csv::S2_exposure_only_logit pr_auc` ; `\valExpExpOnlyPRAUC`=0.300 | `…/table_C…csv` `[PENDING]` | `\valFedAudExpOnlyPRAUC` |
| Within-stratum residual (score \| MEDIUM cells) | **0.471** (≈chance) | `table_C…csv::WITHIN_STRATUM_log_tc` ; `\valExpWithinAUC`=0.471 ; also `table_D_matched_opportunity_validation_summary.csv::within_stratum_auc_score`=0.4476 | `…/table_C…csv::WITHIN_STRATUM_log_tc` `[PENDING]` | `\valFedAudWithinAUC` |
| Within-stratum FL \| stratum | 0.507 | `table_C…csv::WITHIN_STRATUM_fl14` ; `\valExpWithinFLAUC`=0.507 | `…/table_C…csv::WITHIN_STRATUM_fl14` `[PENDING]` | `\valFedAudWithinFLAUC` |
| Label-blind opportunity expectation (AUC, E) | **0.553** | `\valArmorExpLB`=0.553 ; `outputs/diagnostics/audit_armor/audit_armor_macros.tex` + `granularity_sweep.csv` | `outputs/comprasnet/diagnostics/audit_armor/leakage_check_cell_level.csv :: E_i label-blind (cell rate from NON-cobidder rows only)` `[built: 0.6114]` (apples-to-apples; identical cell-level construction to BEC 0.553) | `\valFedAudLabelBlindAUC` |
| Nested increment (exposure→exposure+score) | **+0.010** | `table_C…csv::NESTED auc_increment` ; `\valExpIncrement`=0.010 | `…/table_C…csv::NESTED auc_increment` `[PENDING]` | `\valFedAudNestedIncrement` |
| Nested DeLong p | 0.013 | `table_C…csv::NESTED delong_p` ; `\valExpDeLongP`=0.013 | `…/table_C…csv::NESTED delong_p` `[PENDING]` | `\valFedAudNestedP` |
| Nested exposure+score ROC | 0.723 | `table_C…csv::NESTED exposure+score` (NEW_NUMBERS_MAP) | `…/table_C…csv::NESTED exposure+score` `[PENDING]` | `\valFedAudNestedExpScoreAUC` |
| Matched-permutation p (Approach C, within-strata shuffle) | **0.127** (NOT sig) | `table_D_opportunity_permutation_validation.csv::Approach C p_pr` ; `\valExpPermCp`=0.127 | `outputs/comprasnet/tables/table_D_opportunity_permutation_validation.csv::Approach C p_pr` `[PENDING]` | `\valFedAudPermCp` |

---

## ROW GROUP 4 — Power bounds (matched-permutation calibration)

BEC source: `outputs/diagnostics/audit_armor/permutation_power_curve.csv` + `\valArmorPower*`.
Federal slot (PENDING): `outputs/comprasnet/diagnostics/audit_armor/permutation_power_curve.csv`.

| Row | BEC value | BEC source (file + macro) | Federal slot (file) | Federal macro |
|---|---|---|---|---|
| Detection prob. @ true within-AUC 0.52 | 0.28 | `permutation_power_curve.csv` ; `\valArmorPowerTwo`=0.28 | `audit_armor/permutation_power_curve.csv :: 0.52 rejection_rate_alpha05` `[built: 0.167]` | `\valFedAudPowerTwo` |
| Detection prob. @ true within-AUC **0.55** | **0.97** | `permutation_power_curve.csv` ; `\valArmorPowerFive`=0.97 | `audit_armor/permutation_power_curve.csv :: 0.55 rejection_rate_alpha05` `[built: 0.35]` | `\valFedAudPowerFive` |
| Detection prob. @ true within-AUC **0.60** | 1.00 | `permutation_power_curve.csv` ; `\valArmorPowerTen`=1.00 | `audit_armor/permutation_power_curve.csv :: 0.6 rejection_rate_alpha05` `[built: 0.90]` | **`\valFedAudPowerSixty`** (NEW) |
| Detection prob. @ true within-AUC 0.65 | 1.00 | `permutation_power_curve.csv` (0.65) | `audit_armor/permutation_power_curve.csv :: 0.65 rejection_rate_alpha05` `[built: 1.00]` | `\valFedAudPowerSixtyFive` |
| Within-stratum positive control (O_i, MEDIUM) | 0.953 | `granularity_sweep.csv` / armor ; `\valArmorOiControlMedium`=0.953 | `audit_armor/granularity_sweep.csv :: E_loo_MEDIUM within_AUC_Oi_positive_control` `[built: 0.9921]` (COARSE 0.9987; STRICT 0.5333 — sparse, ignore) | `\valFedAudOiControlMedium` |

**Power-bound reading (Group 4, federal).** The federal positive set is ~30% of BEC's, so the
matched-permutation null is *informative against within-stratum residuals ≥0.60* (det. prob.
**0.90**) but *underpowered at 0.55* (**0.35**, vs BEC **0.97**). The within-stratum positive
control O_i (0.992–0.999 at MEDIUM/COARSE) confirms the design **detects within-stratum signal when
present** — the federal null is a power bound on a genuine null, not a design artifact. Federal armor
file writes these under the `\valArmor*` namespace (`12_audit_armor.R`); the comparative/appG drafts
rebind into `\valFedAud*`. (Federal armor literals on disk: `\valArmorPowerFive`=0.35,
`\valArmorPowerTen`=0.90, `\valArmorOiControlMedium`=0.992 in
`outputs/comprasnet/diagnostics/audit_armor/audit_armor_macros.tex`.) **Source for `\valFedAudPowerSixty`:
`permutation_power_curve.csv :: 0.6 rejection_rate_alpha05` = 0.90.**

---

## ROW GROUP 5 — Matched permutation verdict + granularity sweep

BEC source: `table_D_opportunity_permutation_validation.csv` + `granularity_sweep.csv`.
Federal slot (PENDING): `outputs/comprasnet/tables/table_D_opportunity_permutation_validation.csv`
+ `outputs/comprasnet/diagnostics/audit_armor/granularity_sweep.csv`.

| Row | BEC value | BEC source (file + macro) | Federal slot (file) | Federal macro |
|---|---|---|---|---|
| Permutation verdict | does NOT reject (p=0.127) | `table_D…csv::Approach C` ; `\valExpPermCp`=0.127 | `…/table_D_opportunity_permutation_validation.csv` `[PENDING]` | `\valFedAudPermVerdict` |
| Within-AUC, COARSE cells | 0.508 | `granularity_sweep.csv` ; `\valArmorWithinCoarse`=0.508 | `…/granularity_sweep.csv` (COARSE) `[PENDING]` | `\valFedAudWithinCoarse` |
| Within-AUC, MEDIUM cells | 0.493 | `granularity_sweep.csv` ; `\valArmorWithinMedium`=0.493 | `…/granularity_sweep.csv` (MEDIUM) `[PENDING]` | `\valFedAudWithinMedium` |
| Within-AUC, STRICT cells | 0.600 | `granularity_sweep.csv` ; `\valArmorWithinStrict`=0.600 | `…/granularity_sweep.csv` (STRICT) `[PENDING]` | `\valFedAudWithinStrict` |

---

## ROW GROUP 6 — Opportunity-cell construction (appendix grid)

BEC source: `outputs/tables/appendix/table_D_opportunity_cell_construction.csv`.
Federal slot (PENDING): `outputs/comprasnet/tables/table_D_opportunity_cell_construction.csv` (or
appendix twin).

| Row | BEC value | BEC source (file + macro) | Federal slot (file) | Federal macro |
|---|---|---|---|---|
| Mean cell defendant-contact rate p̄_g (across defs) | 0.017–0.019 (COARSE 0.0179 / MED 0.0171 / STRICT 0.0187) | `table_D_opportunity_cell_construction.csv::mean_p_g` ; *(no scalar macro; draft notes "BEC: 0.017–0.019")* | `outputs/comprasnet/tables/table_D_opportunity_cell_construction.csv::mean_p_g` `[PENDING]` | `\valFedAudPbarRange` |
| STRICT cells with <5 tender-items | 99.5% | `table_D_opportunity_cell_construction.csv::pct_cells_lt5_items` (STRICT row) | `…/table_D_opportunity_cell_construction.csv::pct_cells_lt5_items` (STRICT) `[PENDING]` | `\valFedAudStrictSparseShare` |
| Common-support retention, MEDIUM | 46% | *draft-cited (BEC: 46%); derive from* `table_D_matched_opportunity_validation_summary.csv::support_retained_share` *or cell grid* — **BEC: LOCATE-FAILED as a standalone macro** | `outputs/comprasnet/tables/table_D_opportunity_cell_construction.csv` (retention col) `[PENDING]` | `\valFedAudMediumRetention` |
| Common-support retention, STRICT | 9% | *draft-cited (BEC: 9%)* — **BEC: LOCATE-FAILED as a standalone macro** (no `valStrictRetention`; only `\valOpRetentionFiveHund`=53% which is a different object) | `…/table_D_opportunity_cell_construction.csv` (retention col, STRICT) `[PENDING]` | `\valFedAudStrictRetention` |

---

## ROW GROUP 7 — Timing / leakage / label-frozen prospective test

BEC source: `table_D_strict_2009_2016_to_2017_2019.csv`, `table_E_rolling_origin_validation.csv`,
`outputs/diagnostics/audit_armor/frozen_timing.csv`, `strict_holdout_composition.csv`.
Federal slot (PENDING): `outputs/comprasnet/tables/table_D_strict_2013_2016_to_2017_2019.csv` and
`outputs/comprasnet/diagnostics/audit_armor/frozen_timing.csv`.

| Row | BEC value | BEC source (file + macro) | Federal slot (file) | Federal macro |
|---|---|---|---|---|
| Full-sample retrospective ROC (upper bound) | 0.761 | `table_C…csv::S0_raw_score` ; `\valExpRawScoreAUC`=0.761 | `outputs/comprasnet/tables/table_C…csv` (full retro) `[PENDING]` | (reuse `\valFedAudRawAUC`) |
| Strict full test universe ROC (entrants @0) | 0.474 (below chance) | `table_D_strict_2009_2016_to_2017_2019.csv` ; `\valStrictFullAUC`=0.474 | `outputs/comprasnet/tables/table_D_strict_2013_2016_to_2017_2019.csv` `[PENDING]` | `\valFedAudStrictFullAUC` |
| Strict full universe prec@500 | 0 | `table_D_strict…csv` ; `\valStrictFullPrec`=0 | `…/table_D_strict_2013…csv` `[PENDING]` | `\valFedAudStrictPrec` |
| Strict training-AL pool, continuous ROC | 0.684 | `table_D_strict…csv` ; `\valStrictContAUC`=0.684 | `…/table_D_strict_2013…csv` `[PENDING]` | `\valFedAudStrictContAUC` |
| Strict training-AL pool, FL binary ROC | 0.646 | `table_D_strict…csv` ; `\valStrictFLAUC`=0.646 | `…/table_D_strict_2013…csv` `[PENDING]` | `\valFedAudStrictFLAUC` |
| Frozen pool size | 13,051 | `frozen_timing.csv` ; `\valArmorFrozenPool`=13,051 | `audit_armor/frozen_timing.csv :: pool_n` `[built: 24,888]` | `\valFedAudFrozenPool` |
| Label-frozen prospective ROC (new contact) | **0.713** | `frozen_timing.csv` ; `\valArmorFrozenProspAUC`=0.713 (N=231 `\valArmorFrozenProspN`) | `audit_armor/frozen_timing.csv :: d1 auc` `[built: 0.5948, npos=98]` (label = NEW defendant contact 2017–2019; the referee's clean out-of-time test on rankable incumbents) | `\valFedAudFrozenProspAUC` (+`\valFedAudFrozenProspN`=98) |
| Label-frozen retrospective ROC (leakage-closed) | 0.718 | `frozen_timing.csv` ; `\valArmorFrozenRetroAUC`=0.718 (N=582) | `audit_armor/frozen_timing.csv :: d2 auc` `[built: 0.7404, npos=177]` (label = defendant contact within 2013–2016, fully frozen; no cross-window leakage in EITHER label or pool) | `\valFedAudFrozenRetroAUC` (+`\valFedAudFrozenRetroN`=177) |

**Frozen-timing reading (Group 7, federal).** Prospective and retrospective are **different estimands
on different positive sets** (N+=98 vs 177) under the *same* frozen pool (24,888) — they are mutually
consistent, not contradictory; only the prospective number (0.5948) is the referee's clean out-of-time
test, and it lands well below BEC's 0.713. The federal armor file writes
`\valArmorFrozenProspAUC`=0.595 / `\valArmorFrozenRetroAUC`=0.740 / `\valArmorFrozenPool`=24,888 in
`outputs/comprasnet/diagnostics/audit_armor/audit_armor_macros.tex`; rebind into `\valFedAud*` for the
comparative table. Estimand-wall note: the frozen prospective (0.5948) and the raw strict-universe
timing (0.489 full / 0.666 incumbent-pool, Group-8 below) measure different objects on different
samples — do not collide them.
| Worst rolling-origin year ROC | 0.446 (below chance) | `table_E_rolling_origin_validation.csv` ; `\valRollWorstAUC`=0.446 | `outputs/comprasnet/tables/table_E_rolling_origin_validation.csv` `[PENDING]` | `\valFedAudRollWorstAUC` |

---

## ROW GROUP 8 — Case concentration + leave-one-case-out (LOCO)

BEC source: `table_G_leave_one_case_out_validation.csv`, `table_H_case_dominance_validation.csv`,
`outputs/tables/appendix/table_D_clustered_randomization_inference.csv`.
Federal slot (PENDING): `outputs/comprasnet/tables/table_G_leave_one_case_out_validation.csv`,
`…/table_H_case_dominance_validation.csv`.

| Row | BEC value | BEC source (file + macro) | Federal slot (file) | Federal macro |
|---|---|---|---|---|
| Top-case share of positives | **32.0%** (trens_metros 208/651) | `table_G_leave_one_case_out_validation.csv` ; `\valTopCasePosShare`=32.0% | `outputs/comprasnet/tables/table_G_leave_one_case_out_validation.csv` `[PENDING]` | `\valFedAudTopCaseShare` |
| Top-case share of top-500 TP | 45.4% | case-dominance diag ; `\valTopCaseTP`=45.4% | `…/table_H_case_dominance_validation.csv` (top-case TP@500) `[PENDING]` | `\valFedAudTopCaseTP` |
| LOCO full PR-AUC | 0.143 | `table_H_case_dominance_validation.csv::full` ; `\valLOCOfullPRAUC`=0.143 | `…/table_H_case_dominance_validation.csv::full` `[PENDING]` | `\valFedAudLOCOfullPRAUC` |
| LOCO drop-largest PR-AUC | **0.090** (−37%) | `table_H…csv::drop_largest_case` ; `\valLOCOdropLargestPRAUC`=0.090 | `…/table_H…csv::drop_largest_case` `[PENDING]` | `\valFedAudLOCOdropLargestPRAUC` |
| Clustered RI p (pooled ordering) | 0.001 | `table_D_clustered_randomization_inference.csv::roc_auc emp_p` ; `\valClusterRIp`=0.001 | `outputs/comprasnet/tables/.../table_D_clustered_randomization_inference.csv` (or appendix) `[PENDING]` | `\valFedAudClusterRIp` |
| Clustered RI p (case-coverage breadth) | 0.103 (NS) | `table_D_clustered_randomization_inference.csv::topk500_case_coverage emp_p` ; `\valClusterRIcovP`=0.103 | `…/table_D_clustered_randomization_inference.csv` (coverage) `[PENDING]` | `\valFedAudClusterRIcovP` |

---

## ROW GROUP 9 — Negative controls

BEC source: `outputs/tables/appendix/table_E_negative_controls.csv`.
Federal slot (PENDING): `outputs/comprasnet/tables/appendix/table_E_negative_controls.csv` (or
`outputs/comprasnet/tables/table_E_negative_controls.csv`).

| Row | BEC value | BEC source (file + macro) | Federal slot (file) | Federal macro |
|---|---|---|---|---|
| Real (CADE-anchor) ROC | 0.761 | `table_E_negative_controls.csv::real_auc` ; `\valProfNegCtrlRealAUC`=0.761 | `outputs/comprasnet/tables/table_E_negative_controls.csv::real_auc` `[PENDING]` | (reuse `\valFedAudWithinAUC` / raw) |
| Placebo-anchor null ROC (matched volume) | 0.755 (p=0.456 NS) | `table_E_negative_controls.csv::placebo_cade_anchors_matched null_auc_mean` ; `\valProfNegCtrlPlaceboAUC`=0.755 | `outputs/comprasnet/tables/table_E_negative_controls.csv::placebo_cade_anchors_matched null_auc_mean` `[built: 0.729]` (real_auc=0.744, empirical_p_auc=0.27 NS) | `\valFedAudPlaceboAUC` |
| Non-CADE high-volume-winner null ROC | 0.782 (p=0.908) | `table_E_negative_controls.csv::nonCADE_high_volume_winners null_auc_mean` ; **no dedicated BEC macro** (read from CSV) | `outputs/comprasnet/tables/table_E_negative_controls.csv::nonCADE_high_volume_winners null_auc_mean` `[built: 0.745]` (real_auc=0.744, empirical_p_auc=0.542 NS) | `\valFedAudHVWinnerAUC` |
| Negative-control verdict | generic geometry (not cartel-specific) | derived from placebo NS + HV-winner NS | `outputs/comprasnet/tables/table_E_negative_controls.csv` (verdict derivation: placebo p=0.27 NS + HV-winner p=0.542 NS) `[built: generic opportunity/volume geometry — same as BEC]` | `\valFedAudNegControlVerdict` |

---

## ROW GROUP 10 — Armor extras (secondary federal robustness)

BEC source: `outputs/diagnostics/audit_armor/*.csv` + `\valArmor*`.
Federal slot (PENDING): `outputs/comprasnet/diagnostics/audit_armor/*.csv`.

| Row | BEC value | BEC source (file + macro) | Federal slot (file) | Federal macro |
|---|---|---|---|---|
| Firm-level LOO exposure benchmark E_i | 0.855 | `audit_armor_macros.tex` / `granularity_sweep.csv` ; `\valArmorExpLOO`=0.855 | `outputs/comprasnet/diagnostics/audit_armor/granularity_sweep.csv` (LOO E) `[PENDING]` | `\valFedAudExpLOO` |
| Label-blind opportunity ranking (non-cobidder p_g) | 0.553 | `\valArmorExpLB`=0.553 (= label-blind E row) | `outputs/comprasnet/diagnostics/audit_armor/leakage_check_cell_level.csv :: E_i label-blind (cell rate from NON-cobidder rows only)` `[built: 0.6114]` (= Group-3 label-blind E; same object) | `\valFedAudExpLB` |
| Within-AUC label-blind (MEDIUM) | 0.665 | `\valArmorWithinLB`=0.665 | `outputs/comprasnet/diagnostics/audit_armor/granularity_sweep.csv :: E_label_blind_MEDIUM (exposed E_lb>0)` `[built: 0.6952]` (BEC twin 0.665) | `\valFedAudWithinLB` |
| Within-AUC label-blind (all-AL) | 0.722 | `\valArmorWithinLBall`=0.722 | `outputs/comprasnet/diagnostics/audit_armor/granularity_sweep.csv :: E_label_blind_MEDIUM (all AL)` `[built: 0.7389]` (BEC twin 0.722) | `\valFedAudWithinLBall` |
| Breadth (≥2 shared def items): within-AUC | (BEC armor — stable) | `granularity_sweep.csv` breadth row — **read from CSV; no scalar macro** | `…/granularity_sweep.csv` (breadth) `[PENDING]` | `\valFedAudBreadthWithinAUC` |

---

## ROW GROUP 11 — SRP stratification (federal pregão-variant robustness, A7)

Federal-only leg (BEC has no SRP/pregão split). Built by
`scripts/analysis/13_srp_stratified_validation.R` (re-run 2026-06-06, 26s, FULL).
Source: `outputs/comprasnet/tables/table_SRP_stratified.csv` (+ `_macros.csv`).

**SRP-ADJUDICATION (2026-06-06, locked verdict — see
`outputs/comprasnet/diagnostics/early_triage_13_srp.md`).** The A7 deliverable rides on the
**cross-stratum-consistent** rows only: raw / exposure-only / FL32. The script's
within-cell C-statistic (`within_yearbuyer_cell_cstat`, 0.867 reg / 0.713 srp) is a
**DIFFERENT ESTIMAND** — a modal year×buyer *administrative*-cell C-stat that does NOT
purge the exposure confound and is pair-starved (reg 24,543 comparable pairs; **srp only
1,207**). It MUST NOT appear beside script 02/12's exposure-stratum within and **no
`\valFedAudSRP*Within*` prose macro is minted** (the value is kept in the CSV for the
record under a `DO_NOT_PUBLISH_beside_exposure_within` flag column; dropped from the .tex).

| Row | pregão regular (phase 5) | SRP (phase 9999) | gap | Federal slot (file) | Federal `\valFedAud*` macro |
|---|---|---|---|---|---|
| N firms (AL active in stratum) | 25,190 | 20,461 | — | `table_SRP_stratified.csv::n_firms` `[built]` | `\valFedAudSRPregN` / `\valFedAudSRPsrpN` |
| N$^+$ (broad-AL cobidder) | 114 | 165 | — | `…csv::n_pos` `[built]` | `\valFedAudSRPregNpos` / `\valFedAudSRPsrpNpos` |
| Raw AUC [CI] | **0.748** [0.704, 0.792] | **0.703** [0.667, 0.739] | **0.045** (<0.05) | `…csv::raw_auc (+ raw_auc_lo/hi)` `[built]` | `\valFedAudSRPregRawAUC` (+`…CI`) / `\valFedAudSRPsrpRawAUC` (+`…CI`) |
| PR-AUC | 0.014 | 0.016 | — | `…csv::pr_auc` `[built]` | `\valFedAudSRPregPRAUC` / `\valFedAudSRPsrpPRAUC` |
| Exposure-only AUC | 0.859 | 0.874 | 0.015 | `…csv::exposure_only_auc` `[built]` | `\valFedAudSRPregExpAUC` / `\valFedAudSRPsrpExpAUC` |
| FL32 AUC | 0.656 | 0.641 | 0.015 | `…csv::fl32_auc` `[built]` | `\valFedAudSRPregFLthirtytwoAUC` / `\valFedAudSRPsrpFLthirtytwoAUC` |
| Cross-stratum raw-AUC consistency gap | — | — | **0.045** | `…_macros.csv::valFedAudSRPgap` `[built]` | `\valFedAudSRPgap` |
| Within (year×buyer)-cell C-stat — **DO-NOT-PUBLISH** | 0.867 [24,543 pairs] | 0.713 [1,207 pairs] | 0.154 (artifact) | `…csv::within_yearbuyer_cell_cstat` + `DO_NOT_PUBLISH_beside_exposure_within=1` `[built; CSV-only, NOT a macro]` | **(no macro — suppressed)** |

**SRP reading (Group 11, federal).** A7 verdict = the loser-side concentration signal behaves
**CONSISTENTLY** across the two federal pregão variants: raw discrimination gap = **0.045 (< 0.05)**;
exposure-only and FL32 gaps ≈ **0.015**. Pooling the two pregão variants does NOT hide heterogeneity
in the signal. The within-cell C-stat is the ONLY column that diverges wildly (0.867 vs 0.713) — an
artifact of cell density (top-5 cells carry ~68% of comparable pairs in the pooled check; SRP has only
1,207 pairs), NOT economics, and a different estimand from the exposure-adjusted within of Group 3
(`\valFedAudWithinAUC`). Never collide the two.

---

## DATA ASSETS (not result rows — provenance only)

| Asset | Path | Detail | Audit status |
|---|---|---|---|
| Federal price panel | `data/processed_comprasnet/federal_price_panel.parquet` | 12,378,012 item-rows; discount median **0.745** vs estimated reference price (`discount` col; on-disk MEDIAN 0.75, ~0.745 ex-outliers, 168,092 ratio-outliers flagged); portal-panel match-rate ~45.8% (`in_portal_panel`); reference-price coverage `valorEstimadoItem`>0 ≈ 99.9% | **asset available — NOT used in audit scope per R4 A10 (price claims omitted).** Built for completeness; no price-based AUC/treatment claim enters the federal extension. |

---

## VERIFICATION PROTOCOL (when the chain completes)

For EACH federal slot above, in order:

1. **Read the named output file directly.** Open the exact `outputs/comprasnet/...` path/column
   listed in the row. Do **NOT** transcribe the value from a run log, console output, or a
   `.log` file. The CSV/JSON written by the script is the only admissible source.
2. **Double-check against the diagnostics twin.** Cross-read the value against the corresponding
   `outputs/comprasnet/diagnostics/*.csv` (e.g. `label_funnel_assertions.csv`,
   `opportunity_validation_audit_log.txt`, `target_construction_assertions.csv`,
   `canonical_target_macros.tex`). If the two disagree, STOP — do not fill the slot; log the
   discrepancy as an R3 blocker.
3. **Confirm construction parity.** Verify the federal cell definition matches the construction-
   differences header (window 2013–2019, MEDIUM = year×UASG, pure-Pregão, 7 anchors). A federal
   number computed under the wrong cell definition is wrong even if the file says so.
4. **Bind the macro in `values.tex`** with a full `% src:` comment, e.g.:
   `\newcommand{\valFedAudRawAUC}{0.7xx}  % src: outputs/comprasnet/tables/table_C_opportunity_adjusted_validation.csv :: S0_raw_score roc_auc (federal chain 2013-2019, year×UASG MEDIUM)`
   Bind `\valFedAud*` macros, not the `\valFed*` panel-descriptor macros — keep the two namespaces
   separate.
5. **Replace the `\valTODO` placeholder** in `sec_comparative_DRAFT.tex` /
   `sec_appG_federal_DRAFT.tex` with the bound macro, deleting the `% TODO_NUMBER` tag and the
   `\providecommand{\valTODO}` block before integration.
6. **Re-verify the comparative table** reads BOTH columns from `values.tex` (no hard-coded literals),
   then compile appendix-before-paper (xr cross-refs) and confirm 0 undefined refs.

---

## Sources consulted (provenance)

- `submission_clean/values.tex` (hand-maintained, `% src:` comments) — all BEC macros above.
- `outputs/targets/canonical_target_counts.csv` — BEC funnel/universe.
- `outputs/comprasnet/targets/canonical_target_counts.csv` + `canonical_case_labels.csv` — federal
  funnel/universe **already built** (bracketed `[built: …]` values).
- `outputs/tables/main/table_C_opportunity_adjusted_validation.csv`,
  `table_D_opportunity_permutation_validation.csv`,
  `table_D_strict_2009_2016_to_2017_2019.csv`, `table_E_rolling_origin_validation.csv`,
  `table_G_leave_one_case_out_validation.csv`, `table_H_case_dominance_validation.csv` — BEC battery.
- `outputs/tables/appendix/table_D_opportunity_cell_construction.csv`,
  `table_D_matched_opportunity_validation_summary.csv`,
  `table_D_clustered_randomization_inference.csv`, `table_E_negative_controls.csv` — BEC appendix.
- `outputs/diagnostics/audit_armor/{audit_armor_macros.tex, permutation_power_curve.csv,
  granularity_sweep.csv, frozen_timing.csv}` — BEC armor.
- `submission_clean/sec_comparative_DRAFT.tex`, `sec_appG_federal_DRAFT.tex` — federal `\valFedAud*`
  namespace + slot structure.
- `docs/jleo_rr_revision/NEW_NUMBERS_MAP.md` — canonical BEC label (651) format template.
