# CONSOLIDATED RESULTS — ComprasNet (Federal) Extension · Phase-2 CLOSING LEDGER

**Author:** Mr. Frequent Losers (co-author mode) · **Date:** 2026-06-06 · **Status:** Phase 2 (verification gates R1–R4) CLOSED. Phase 3 (manuscript integration) gated on Darcio's D-iii decision.
**Scope:** the single document a coauthor or future session reads to know exactly what the federal leg established, by which artifact, and what remains. Read-only synthesis; no manuscript file edited from here.
**Canonical positive set:** **N+ = 195** broad-AL cobidders, establishment-anchored, post-sentinel-drop (`targets/canonical_target_counts.csv :: B_broad_AL_cobidders_MAIN`).

---

## 1. THE VERDICT IN ONE PARAGRAPH

**Draft A is CONFIRMED: the deflation replicates on the federal platform, and on the decisive rows it lands more cleanly than on BEC.** Every materialized federal cell points the same way — when a cheap award-layer statistic (loss intensity) is held to an opportunity-adjusted standard, its apparent discrimination collapses to generic co-participation geometry. Exposure-only ROC-AUC (0.754) **equals-to-edges-out** the raw score (0.744) federally (on BEC exposure only approaches raw, 0.713 vs 0.761); the within-stratum residual sits at ≈chance (0.462); the nested DeLong increment is null (+0.005, p=0.191); the matched permutation does not reject (p=0.906); and **both negative controls reproduce the real raw AUC** (matched-volume placebo p=0.258, non-CADE high-volume-winner p=0.582 — the protocol's designated arbiter, ruling for Draft A). What the federal evidence **establishes** is the *portability of the audit protocol and of the loser-side construct* across a second, institutionally distinct platform (federal pure-Pregão, 2013–2019). What it **does not** establish — and is disclosed, not defended — is (i) an independent cartel ground truth (the 7 federal cases are the *same* cases as BEC's, partially overlapping, establishment-anchored), (ii) a clean small-residual null (the within row is power-bounded: ≥0.60 ruled out @90% power, the ≤0.55 region unadjudicated at N+=195), and (iii) operational multi-case generalization (realized top-500 detections are 87.5% one case; top-two cases = 64.4% of positives). The federal leg is a **single-system, concentrated-anchor stress test of the protocol**, not a multi-case operational claim. Draft B ("residual survives federally → institution-coupled screening value") has **no supporting cell** and is to be deleted at integration.

---

## 2. THE FILLED COMPARATIVE TABLE (BEC | ComprasNet, every cell sourced)

`tab:comparative_audit` — "The Audit on Two Platforms: BEC–SP versus ComprasNet". Row order mirrors `sec_comparative_DRAFT.tex`. **PR-AUC is the lead metric for rare-target rows; ROC-AUC shown for cross-platform comparability** (read PR-AUC against each platform's base rate — note B). Cells that **changed vs `D3_TABLE_PREVIEW.md` in the final on-disk runs** are flagged ⚠ and explained beneath the table.

| # | Audit stage | BEC–SP | ComprasNet | src (federal, on-disk) |
|---|---|---|---|---|
| 1 | **Raw award-layer ROC-AUC** (log T) | **0.761** | **0.744** | `table_C…csv::S0_raw_score roc_auc` |
| 1b | — Raw award-layer PR-AUC | 0.143 | **0.014** | `table_C…csv::S0_raw_score pr_auc` |
| 2 | **Exposure-only ROC-AUC** (no score) | 0.713 | **0.754** | `table_C…csv::S2_exposure_only_logit roc_auc` |
| 3 | **Label-blind opportunity expectation (AUC, E)** | 0.553 | **0.611** | `leakage_check_cell_level.csv::E_i label-blind (cell rate from NON-cobidder rows only)` = 0.6114; BEC twin `audit_armor_macros.tex::\valArmorExpLB` = 0.553 |
| 4 | **Within-stratum residual** (AUC, MEDIUM cells, exposure-stratum) | 0.471 (≈chance) | **0.462** (≈chance) | `table_C…csv::WITHIN_STRATUM_log_tc roc_auc`; matched within `table_D_matched…summary.csv` |
| 5 | **Nested DeLong increment over exposure-only** | +0.010, p=0.013 | **+0.005, p=0.191 (null)** | `table_C…csv::NESTED auc_increment / delong_p` |
| 6 | **Power-bounded residual** (det. prob. @ true AUC 0.55 / 0.60) | 0.97 (@0.55) | **0.35 @0.55 / 0.90 @0.60** (≥0.65 → 1.00; size@0.50 = 0.117) | `permutation_power_curve.csv`; O_i positive control MEDIUM **0.9921** / COARSE 0.9987 `granularity_sweep.csv` |
| 7 | **Matched-permutation p** (within-strata shuffle) | 0.127 (NOT sig) | **0.906 (NOT sig)** | `table_D_opportunity_permutation_validation.csv::C_matched_label_perm p_pr` |
| 8 | **Label-frozen prospective timing (AUC)** | 0.713 | **0.595 prosp** (pool 24,888, N+=98, CI [0.535,0.654]) / **0.740 retro** (N+=177) | `audit_armor/frozen_timing.csv::d1 auc`=0.5948 / `d2 auc`=0.7404 |
| 9 | **Top-case concentration** (operational) | 32.0% pos / 45.4% TP@500 | **64.4% top-two pos / 87.5% TP@500** (top-case-by-positives 35.4%) | `case_dominance_summary.csv::share_pos`(top-case 0.3538), `share_tp_500`(0.875) |
| 9b | — Ordering robustness (LOCO + RI) | ROC 0.761→0.763; RI p=0.001 | **ROC 0.744→0.744 (drop-largest, −0.1%); RI p=0.001; breadth p=0.487 (NS)** | `table_H::drop_largest_case`; `table_D_clustered…::roc_auc emp_p` |
| 10 ⚠ | **Negative-control verdict** | generic geometry (placebo p=0.456, HV-winner p=0.908) | **generic opportunity/volume geometry — same as BEC** (real 0.744 vs placebo null mean **0.728**, p=**0.258**; vs non-CADE HV-winner null mean **0.746**, p=**0.582** — neither rejects) | `table_E_negative_controls.csv::placebo_cade_anchors_matched real_auc`=0.7443 / `null_auc_mean`=0.7283 / `empirical_p_auc`=0.258; `nonCADE_high_volume_winners null_auc_mean`=0.7461 / `empirical_p_auc`=0.582 |

**Universe / label context (for §5 prose, not a table row):** federal panel **51.0M** participation rows / **92,600** firms; **35,943** always-losers (38.8%); IQR threshold **32** (= 5 + 1.5×18, with `≥`; vs BEC 14); **6,491** federal FLs (NOT the logged 6,303 = old `>` bug); **7** CADE cases (vs BEC 12); **195** broad-AL cobidders (vs BEC **651**); FL composition **94 FL / 101 non-FL**. Window **2013–2019** (7 of BEC's 11 years; source starts 2013-01). Sources: `targets/canonical_target_counts.csv`, `phase0_g5_al_universe.csv`, `phase0_g2_panel_semantics.csv`.

### ⚠ Cell corrected vs D3_TABLE_PREVIEW (row 10, post-determinism-fix)
The script-06 determinism fix (DuckDB parallel-SUM nondeterminism, R1-extended finding) **nudged the negative-control null means**; `real_auc` (0.744) is unchanged.

| Quantity | D3_TABLE_PREVIEW value | CURRENT on-disk value | Δ |
|---|---|---|---|
| placebo null_auc_mean | 0.729 | **0.7283** | −0.0007 |
| placebo empirical_p_auc | 0.27 | **0.258** | −0.012 |
| HV-winner null_auc_mean | 0.745 | **0.7461** | +0.0011 |
| HV-winner empirical_p_auc | 0.542 | **0.582** | +0.040 |

Verdict is **unchanged** — both p-values remain ≫0.10, so both placebos reproduce the real order ⇒ generic geometry ⇒ Draft A. The R4_EXECUTED doc cites the *previous* 0.27/0.542; the values to wire into `values.tex` are the on-disk **0.258 / 0.582** (`table_E_negative_controls.csv`, written 2026-06-06 07:23). All other rows match D3_TABLE_PREVIEW exactly.

### Notes the table carries
- **A — Dual framing (A3 case-concentration).** *Rank-ordering ROBUST* (may claim): drop-largest-case ROC 0.744→0.744, clustered-RI ordering p=0.001, LODGO (13 defendant groups) clean — ordering not one-cartel-driven. *Operational ranking CONCENTRATED* (must retreat): TP@500 = 87.5% one case; top-two = 64.4%; PR-AUC −44% drop-largest / −73% drop-top-two; RI case-breadth p=0.487 (NS). Foreground 64.4% / 87.5%, never the flattering 35.4% alone.
- **B — Base-rate note for PR metrics.** Federal positive prevalence ~0.5% (195 / ~92K), ~10× below BEC. Federal PR-AUC (0.014 vs BEC 0.143) is bounded below by the rarer target, not weaker discrimination. ROC-AUC is the base-rate-invariant cross-platform line.
- **C — Cell-definition annotation.** Federal **MEDIUM = year × buyer (UASG)**; the item-group margin (BEC's COARSE cell) is **NOT observed federally** (federal item codes live in buyer-specific catalogs, no shared classification). Federal STRICT = item_code × year × UASG (singleton-dominated; sweep-only). Federal cells are one margin **coarser** than BEC ⇒ the null is conservative a-fortiori. Clustered-RI stratification adds the buyer margin (finer than BEC) — annotate, not a bug.
- **D — Partially overlapping legal anchors.** The 7 federal cases are the *same* cases as BEC's portfolio, partially overlapping, establishment-anchored, with the unnumbered summary case and TI/DF defendants excluded. Tests *portability*, not independent ground truth — neither confirmation nor refutation of any firm's legal status.
- **E — Estimand wall (script-03 guidance).** Raw-timing AUCs (0.489 full-universe / 0.666 incumbent-pool) measure *temporal stability of the raw score*; rows 4–7 measure *opportunity-adjusted within-cell residual*. Different estimands on different samples — a high raw-timing AUC and a null adjusted increment are **mutually consistent, not contradictory**. (Transcribe this one-line caption into the table note at integration.)

---

## 3. R4 LEDGER — 14 ATTACKS × VERDICTS

Protocol: `R4_hostile_read_protocol.md`; executed in `R4_EXECUTED.md` 2026-06-06 against source CSVs.

| # | Attack | Verdict | One-line basis |
|---|---|---|---|
| A1 | Anchor circularity | **SURVIVES** | `phase0_g3` = 7/7 overlap, `independence_verdict=NOT independent`; all "independent" uses in drafts are negations; claims scoped to method+construct portability. |
| A2 | Positive-set power | **SURVIVES-WITH-CAVEAT (power-bounded)** | det. prob. 0.35@0.55 / 0.90@0.60 / 1.00@0.65; O_i control 0.9921 ⇒ design detects signal when present; rule out residual ≥0.60 @90%, ≤0.55 unadjudicated. |
| A3 | Case concentration | **DEGRADED / SPLIT** | ROC-ordering robust (0.744→0.744, RI p=0.001, LODGO clean); operational retreat (TP@500 87.5%, PR −73% top-two, breadth p=0.487 NS). |
| A4 | Window/timing | **SURVIVES-WITH-CAVEAT** | frozen prosp 0.595 [0.535,0.654] N=98 (<120 floor but CI excludes 0.50 & 0.713); lead on strict full-universe 0.489; retro 0.740 corroborates. |
| A5 | FL-cut sensitivity | **SURVIVES (by design)** | continuous log-tenders primary; strict-train continuous 0.666 vs FL-binary 0.634; verdict invariant to FL32 cut; FL32 never defended as special. |
| A6 | Cell coarseness | **SURVIVES (conservative direction)** | federal MEDIUM (no item-group) holds *less* fixed ⇒ null conservative; residual near-chance at every supported granularity; mandatory coarseness annotation present. |
| A7 | SRP split | **SURVIVES** | both strata clear gates (reg 3,546 / SRP 4,069); raw/exposure-only/FL32 cross-stratum consistent (gaps 0.045/0.015/0.015); contact≥2 sensitivity agrees in direction. |
| A8 | TI/DF exclusion | **SURVIVES** | disclosed in both drafts; only federal-only anchor; v3-reinstatement reproduces bit-for-bit ⇒ effect known & non-strategic. |
| A9 | Negative controls (**arbiter**) | **SURVIVES (Draft A confirmed)** | placebo p=0.258, HV-winner p=0.582 (both ≫0.10) ⇒ raw 0.744 is generic co-participation geometry, not cartel-specific. |
| A10 | Price | **SURVIVES (by omission)** | zero federal price claim; grep menorLance/valorEstimado/valorHomologado = 0 hits in both drafts; participation+winner-flag only. |
| A11 | Anchoring grain | **SURVIVES** | estab-anchored 195 is MAIN; v3's 222 set-comparison only; gap = TI/DF exclusion (313 cobidders / 26 AL) + 1 junk; estab-vs-raiz grain = 0. |
| A12 | STRICT support | **SURVIVES** | headline within is MEDIUM (12,781 cells / 7,801 retained); STRICT singleton-dominated, O_i control collapses to 0.533 ⇒ sweep-only with low-support flag. |
| A13 | S2 laundering | **SURVIVES** | S2 confined to App G with "label-encoding; mechanically inflated" note; never cited as the federal screen ranking defendants. |
| A14 | Modality loss | **SURVIVES** | federal pure-Pregão (convite extinct); reframed as construct-sharpening; SRP-vs-regular is the only institutional contrast, not a convite analogue. |

**Draft A/B gate (on A2 + A9): DRAFT A CONFIRMED, Draft B DELETED.** A2 — no powered residual exists to support Draft B. A9 (designated arbiter) — placebos reproduce the order ⇒ ship Draft A with negative controls front-paged. Both gates point the same way.

### Top-3 residual risks + responses
1. **A3 operational concentration (HIGHEST)** — "your realized detections are one cartel." *Response:* concede & disclose; federal leg is a single-system concentrated-anchor stress test, not multi-case operational generalization. What survives LOCO is the **rank-ordering** (ROC 0.744→0.744, RI p=0.001, LODGO clean), genuinely multi-case. Precision-at-k generality claim withdrawn; table notes carry top-two=64.4% / TP@500=87.5% verbatim.
2. **A2 power** — "your federal null is an underpowered failure to reject." *Response:* not a clean null — power-bounded; ≥0.60 ruled out @90%, ≥0.65 @100%, ≤0.55 unadjudicated. O_i control recovers injected signal @AUC 0.99 ⇒ sample-size limit, not design failure. First-stage deflation (label-blind E 0.61 vs BEC 0.55) replicates at full power.
3. **A4 short pre-period** — "4-year frozen pool, N=98, too thin vs BEC's 0.713." *Response:* report frozen-prosp 0.59 [0.54,0.65] with explicit 4-yr caveat; above chance (CI excludes 0.50) but below floor, so don't lead on it. Prospective-collapse claim carried by strict full-universe row (0.489, entrants-at-zero, needs only the test window); frozen-retro 0.74 confirms timing signal.

*(Next-tier: A7 SRP-pooling — ship SRP-stratified row in App G as invariance evidence; A1 framing — re-run the forbidden-verb scan on abstract/intro/conclusion at integration, out of scope for the two-draft R4 scan.)*

---

## 4. VERIFICATION LEDGER (R1 / R1-extended / R2 / R3 / SRP / price asset)

### R1 — BEC re-run regression (`r1_bec_regression.csv`)
**ZERO real regressions.** All diffs are benign: structural-superset added columns (`cell_definition_note`, `keys_nominal`, `item_group_observed` — empty/constant for BEC, original cols byte-identical), cairo_pdf metadata-only PDF diffs (pdftotext content identical), telemetry timestamps, and one intra-cell token-order nondeterminism in `canonical_firm_labels.csv` (`STRING_AGG DISTINCT` no `ORDER BY`; 0 diffs after token sort; pre-existing, not refactor-induced). T1–T10 target assertions all pass.

### R1-extended — federal-refactor regression (`r1_extended_verdicts.csv`)
**ZERO real regressions.** Four **engineering** findings surfaced and were FIXED:
1. **DuckDB-threads nondeterminism** — parallel-SUM float noise (~5e-15) + `SELECT DISTINCT` emission-order drift; fixed by stabilizing tie-breaks (`order(-n_positives, defendant)` script-04 L770; total order, deterministic BEC+federal). The same nondeterminism is the source of the row-10 null-mean nudge in §2.
2. **Malformed committed `.tex`** — `table_J_economic_profile.tex` DIFF; per-`--source` regeneration (no separate BEC `.tex` baseline; baseline captured CSV only).
3. **Manifest ownership** — `granularity_sweep.csv` / `frozen_timing.csv` / `defendant_roles.csv` earlier DIFFs were ownership artifacts (script-12 vs script-12b schema snapshots); fixed by moving to 12b-only in the manifest + refreshing snapshots to the 12b final schema; now byte-identical.
4. **strat_auc env-drift** — FIX-2 dynamic strings dropped BEC manuscript-reconciliation info in the label-funnel row6; restored EXACT original BEC strings under `cfg$source=="bec"`, federal keeps the honest new strings; re-ran 01 BEC, CSV byte-identical.
*Latent flag (MOOT):* 12b regen mislabels `\valArmorPowerFive` as 0.28 (@0.52) vs correct 0.97 (@0.55); manuscript reads `values.tex` which carries the correct 0.97 — pre-existing latent 12b bug, not a refactor regression.

### R2 — target-construction assertions (`target_construction_assertions.csv`, `label_funnel_assertions.csv`)
**T1–T10 all PASS** (directs excluded from cobidders; all cobidders W_i=0; FL14 NOT in label construction — structural; positives include both FL=94 & non-FL=101 ⇒ no circularity; counting units separated 195 firms / 4,930 firm-case / 31,200 tender-items; conservative⊆main 171≤195; static archive read-only; 0 missing IDs / 0 drops; two independent construction paths agree 195=195). Label-funnel A1–A10 PASS (one expected **warning** A8: the cited "210>193" is a *different-definition* comparison — 210=AL/broad/conservative vs 193=FL/narrow/full — report as definition difference, not bug; A10 action: bind new macros, drop `\valConservativeFD` 30→19).

### R3 — fill state (`federal_fill_report.csv`, 82 macros)
**33 `found` + 23 `filled_already` + 26 `missing` = 82.** The 26 "missing" are the **hand-fill list** — almost all are on disk in `audit_armor/granularity_sweep.csv`, `permutation_power_curve.csv`, `frozen_timing.csv`, `case_dominance_summary.csv`, `table_H…`, `table_D_clustered…csv`; the fill report was generated 19:01 (before scripts 04/12b materialized them) and is **stale** for these — re-run the fill step OR hand-read. Two are genuinely **NOT-PRODUCED** (`\valFedAudMediumRetention`, `\valFedAudStrictRetention` — `opportunity_common_support.csv` lacks the retention col; use draft-cited BEC 46%/9% or derive). Hand-fill list (macro → source):
- Power: `\valFedAudPowerTwo/Five/Ten` ← `permutation_power_curve.csv`
- Granularity/within: `\valFedAudWithinCoarse/Medium/Strict`, `\valFedAudBoundaryAUC[Low/Hi]`, `\valFedAudOiControlMedium`, `\valFedAudExpLOO`, `\valFedAudBreadth{WithinAUC,Increment,P,Verdict}` ← `granularity_sweep.csv`
- Frozen timing: `\valFedAudFrozenPool/ProspAUC/ProspN/RetroAUC` ← `frozen_timing.csv`
- Timing: `\valFedAudRollWorstAUC` ← `table_E_rolling_origin_validation.csv`
- Concentration/ordering: `\valFedAudTopTwoShare` ← `case_dominance_summary.csv`; `\valFedAudLOCOdropPct` ← `table_H…`; `\valFedAudClusterRIverdict/CovVerdict` ← `table_D_clustered_randomization_inference.csv`
- NOT-PRODUCED: `\valFedAudMediumRetention`, `\valFedAudStrictRetention`

### SRP adjudication — estimand discipline (`early_triage_13_srp.md`)
Script-13's `within_stratum_auc` (0.867 reg / 0.713 SRP) is **NOT a bug but a DIFFERENT ESTIMAND** — a within-(year×buyer)-cell C-statistic that leaves exposure free to vary, so it re-encodes the raw signal (pooled-sample check: 13-style 0.7938 vs 02-style exposure-decile 0.4639 on the *identical* population). It is **DO-NOT-PUBLISH** alongside the exposure-stratum within column; pair-starved (4,802 pairs, top-5 cells = 68.3%). The A7 answer rides on the **comparable** rows (raw 0.748 vs 0.703; exposure-only 0.859 vs 0.874; FL32 0.656 vs 0.641 — all consistent). The `\valFedAudSRPregWithinAUC`/`\valFedAudSRPsrpWithinAUC` macros are generated but cited **NOWHERE** — keep them out of prose; suppress/relabel the within column in the SRP table.

### Price-panel asset (built, NOT a result)
`data/processed_comprasnet/federal_price_panel.parquet` — **12.38M rows, 527 MB**, built from API `item_pregao` dumps (`build_federal_price_panel.log`). Carries `menorLance / valorEstimadoItem / valorNegociado / valorHomologadoItem` (item-level discount-vs-reference, comparable to BEC price-ratio DV), homologado share 84.5%, in-portal-panel match 43.4% (≈0% 2009–2012, ≈64–74% 2013–2019; window-consistent). **No federal price claim is made in the current drafts (A10 survives by omission)** — the asset is a future-upgrade hook only; if a referee presses, it is the path to a federal price replication, but it is **out of scope for this submission**.

---

## 5. INTEGRATION RUNBOOK (PHASE 3)

Gated on Darcio's **D-iii** decision (placement / float / compensation — 8 questions in `D3_TABLE_PREVIEW.md` §3b). Lead recommendation: **short standalone §5 (~2–2.5pp) + half-page comparative table + Appendix G**; the lean footprint may make the §6 bid-benchmark demotion optional (main 40 vs 42pp — author's call).

### The 4 wiring steps (from `R4_EXECUTED.md` "Overall section verdict")
1. **Macro binding** — delete the `\providecommand{\valTODO}` block + every `% TODO_NUMBER` tag in both drafts; wire every comparative/App-G cell to a real `\valFedAud*` macro (sources verified present in `audit_armor_macros.tex`, `canonical_target_macros.tex`, and the hand-fill list in §4). Honor the fill-spec fixes: (a) clustered-RI table path lacks the `appendix/` subdir — repoint or symlink; (b) `\valFedAudTopCaseTP` reads `case_dominance_summary.csv::share_tp_500` (0.875), **not** table_H; (c) lock the top-two denominator to the link-row **64.4%** basis (132/205) with the 10-multi-case-firm note (firm-basis 67.7%); (d) annotate that federal RI added the buyer margin. **Use the on-disk row-10 values 0.258 / 0.582, not R4_EXECUTED's stale 0.27 / 0.542.**
2. **Estimand-wall caption** — transcribe the script-03 §4 one-line note ("raw-timing rows and opportunity-adjusted rows measure different estimands on different samples; a high raw-timing AUC and a null adjusted increment are mutually consistent") into the comparative-table note (note E), so a referee cannot read the 0.666 strict-train row as rebutting the 0.462 within row.
3. **Draft B deletion** — remove the Draft B ("residual survives") paragraph from `sec_comparative_DRAFT.tex`; keep Draft A. (Confirmed by both gates; Draft B has no supporting cell.)
4. **Re-run the A1 forbidden-verb scan on abstract/intro/conclusion** — those files were out of scope for the two-draft R4 scan; the C2 contribution paragraph and abstract get federal deltas (see claims-deltas pointer below), so re-scan after editing.

### D-i dependency (must land before set-comparison prose)
The 195-vs-222 cobidder gap is **fully decomposed** (`federal_cobidder_rebuild_vs_v3.csv`): TI/DF case-exclusion = 313 cobidders / 26 AL + 1 junk; establishment-vs-raiz grain = **0** (v3 reproduces bit-for-bit on reinstatement). Main target = establishment-anchored **195** everywhere; v3's 222 is set-comparison only. The sentinel-drop (CNPJ 000000000000-2) moved counts to `\valFedAudCobiddersBroadAL`=195, `\valFedAudCompFL`=94, `\valFedAudCompNonFL`=101 — ensure `values_tex_federal_block_DRAFT.tex` is wired with these final counts (it documents the 196→195 / 95→94 drop in its changelog).

### Claims-deltas pointer
`docs/jleo_rr_revision/claims_upgrade_conditional_deltas.md` carries the **DEFLATION-REPLICATES** variant prose for: §0 Abstract, §1 Introduction C2-contribution paragraph, §3 Conclusion, §4 Cover Letter. **Use the DEFLATION-REPLICATES (= Draft A) variant; discard the RESIDUAL-SURVIVES variant.** §5 of that file is a DO-NOT-UPGRADE guard (C1 organizational-frontier result must NOT be over-claimed; deltas say "audit protocol / construct travels", never "C1 frontier travels").

### Draft B deletion + per-file edit list (which DRAFT files exist, where they go)
| DRAFT file (exists) | Destination | Action |
|---|---|---|
| `submission_clean/sec_comparative_DRAFT.tex` | new standalone **§5** (or §4.5) main text | wire macros, delete Draft B para + `\valTODO`, add estimand-wall note → rename to live `sec_comparative.tex` |
| `submission_clean/sec_appG_federal_DRAFT.tex` | new **Appendix G** (the full deflation battery the §5 notes point to) | wire macros, delete `\valTODO` → rename to live `sec_appG_federal.tex` |
| `docs/jleo_rr_revision/values_tex_federal_block_DRAFT.tex` | append into `submission_clean/values.tex` | fill `<FILL>` sentinels + hand-fill 26 macros, replace TODO sentinels with real values |
| `docs/jleo_rr_revision/claims_upgrade_conditional_deltas.md` | abstract / intro / conclusion / cover letter | apply DEFLATION-REPLICATES variant only |
| `docs/jleo_rr_revision/site_updates_v23_DRAFT.md` | Phase 4 (site deploy) | apply after manuscript lands |

**Orphan resolved:** `sec_app07_comprasnet_submission` was **DELETED 2026-06-05** as an orphan; its two salvageable slivers were merged into `sec_appG_federal_DRAFT.tex`. The live appendix decision is **App G only** — confirm with Darcio (D-iii Q7).

---

## 6. HONEST-LIMITATIONS REGISTER (the section's permanent caveats)

These ship in the §5/App-G prose and table notes regardless of how D-iii resolves; none is optional.
1. **Partially-overlapping legal anchors.** The 7 federal cases are the *same* cases as BEC's, partially overlapping, establishment-anchored; the TI/DF unnumbered summary case is excluded. Tests *portability*, not independent ground truth — neither confirms nor refutes any firm's legal status. (`phase0_g3`, R4-A1/A8/A11.)
2. **Power-bounded within residual (≤0.55 unadjudicated).** At N+=195 the matched permutation rules out a within-stratum residual ≥0.60 @90% power and ≥0.65 @100%, but the ≤0.55 region is unadjudicated federally (det. prob. 0.35@0.55 vs BEC 0.97). O_i positive control 0.99 ⇒ sample-size limit, not design failure. (R4-A2.)
3. **Operational concentration (TP@500 = 87.5% one case).** Realized top-500 detections are 87.5% a single case; top-two = 64.4% of positives; PR-AUC −73% on dropping the top two; RI case-breadth p=0.487 (NS). Federal leg is a single-system concentrated-anchor stress test, not a multi-case operational generalization. (R4-A3.)
4. **4-year pre-period (frozen prospective N=98).** Frozen-prospective AUC 0.595 [0.535,0.654] is above chance but below BEC's 0.713 and below the N≥120 comparability floor; not led upon — prospective-collapse claim carried by the strict full-universe row (0.489). (R4-A4.)
5. **Window 2013–2019.** Federal source starts 2013-01 ⇒ 7 of BEC's 11 years; the comparison is a within-Pregão replication on the overlap window. (`phase0_g2`.)
6. **Pure-Pregão (no convite).** Convite is extinct federally ⇒ no D2 modality-mechanism contrast; loss reframed as construct-sharpening; SRP-vs-regular is the only institutional contrast. (`phase0_g2`, R4-A14.)
7. **Item-group margin NOT OBSERVED.** Federal item codes live in buyer-specific catalogs (no shared classification) ⇒ federal MEDIUM cells are one margin coarser than BEC (year×buyer, no item-group); the null is conservative a-fortiori. (`phase0_g1/g4`, R4-A6.)
8. **No federal bid tier.** Portal participant files carry zero bid values; only the winning `menorLance` is available ⇒ the Tier-2 Imhof bid-distribution benchmark is dropped federally and documented as a platform-observability difference (on-thesis). No federal price claim is made. (`phase0_g4`, R4-A10.)

---

## 7. ASSETS PRODUCED (one line each)

### Scripts / configs / harnesses
- `scripts/utils/source_config.R` — `--source={bec,comprasnet}` switch; federal dir tree, buyer/year-key lambdas, freeze_year=2016, FL_CUT=32 (`≥`).
- `scripts/analysis/{00,01,02,02b,03,04,05,06,12,12b}_*.R` — the 10-script chain, source-adapted; GAP-1 fix (script-00 emits `case_cobidder_map_federal.csv`).
- `scripts/analysis/13_srp_stratified_validation.R` — SRP-vs-regular pregão-variant robustness (A7); `within_stratum_auc` column DO-NOT-PUBLISH (different estimand).
- `build_federal_price_panel` builder — parses API `item_pregao` JSONs → `federal_price_panel.parquet` (future price-upgrade hook; not in current submission).
- R1 / R1-extended regression harness — BEC-re-run + federal-refactor byte/numeric/telemetry diff classifier (verdicts in `r1_bec_regression.csv`, `r1_extended_verdicts.csv`).

### Parquets / panels (`data/processed_comprasnet/`, `outputs/comprasnet/cache/`)
- federal participation panel — 51.0M rows / 92,600 firms / 35,943 AL / IQR threshold 32.
- `firm_opportunity_adjusted_frame.csv` — primary opportunity frame (script 02; consumed by 05/06/12/12b).
- `federal_price_panel.parquet` — 12.38M rows, 527 MB (price asset, unused in submission).
- `year_map.parquet` — script-03 year keymap (federal cache, isolated from BEC).

### Result tables (`outputs/comprasnet/tables/`)
- `table_C_opportunity_adjusted_validation.{csv,tex}` — raw / exposure-only / within / nested (rows 1–5).
- `table_D_opportunity_permutation_validation.{csv,tex}` — matched permutation (row 7, p=0.906).
- `table_D_clustered_randomization_inference.csv` — ordering RI p=0.001, breadth p=0.487 (row 9b).
- `table_D_strict_2013_2016_to_2017_2019.csv` — strict full-universe 0.489 / training-AL continuous 0.666 (row 8; filename uses BEC token — annotate/rename at fill).
- `table_E_negative_controls.csv` — row 10 (real 0.744; placebo null 0.728 p=0.258; HV-winner null 0.746 p=0.582). **CORRECTED vs D3_TABLE_PREVIEW.**
- `table_E_rolling_origin_validation.csv` — rolling worst-year 0.480.
- `table_H_case_dominance_validation.csv` — LOCO PR-AUC 0.0142→0.0079→0.0038; ROC 0.744→0.744.
- `table_SRP_stratified.csv` — A7 (raw/exposure-only/FL32 cross-stratum consistent; within col DO-NOT-PUBLISH).
- `table_J/K/L/M`, `table_A_label_funnel` — §5 profile / monotonicity / binary-vs-continuous / label funnel.

### Diagnostics (`outputs/comprasnet/diagnostics/`)
- `audit_armor/{granularity_sweep,permutation_power_curve,frozen_timing,leakage_check_cell_level,defendant_roles}.csv` — armor pack (rows 3, 6, 8 + O_i control).
- `case_dominance_summary.csv` — row 9 concentration (top-case 35.4%, TP@500 87.5%).
- `federal_cobidder_rebuild_vs_v3.csv` — D-i decomposition (195 vs 222; grain=0).
- `phase0_g{1..5}_*.csv`, `phase0_readiness.csv` — Phase-0 gates.
- `{target_construction,label_funnel}_assertions.csv` — R2 (T1–T10 / A1–A10).
- `r1_bec_regression.csv`, `r1_extended_verdicts.csv` — R1 / R1-extended verdicts.
- `federal_fill_report.csv` — R3 fill state (33 found / 23 filled / 26 missing; stale for late files).
- `early_triage_{00_01,03,04,12,13_srp}.md` — per-script triage adjudications.

### Draft manuscript artifacts (`submission_clean/`, `docs/jleo_rr_revision/`)
- `sec_comparative_DRAFT.tex` → live §5 · `sec_appG_federal_DRAFT.tex` → live App G · `values_tex_federal_block_DRAFT.tex` → values.tex append · `claims_upgrade_conditional_deltas.md` (abstract/intro/conclusion/cover) · `site_updates_v23_DRAFT.md` (Phase 4) · `D3_TABLE_PREVIEW.md` (D-iii decision package) · `R4_EXECUTED.md` (14-attack hostile read) · `NEW_NUMBERS_MAP_COMPRASNET.md` (51-row BEC↔federal delta map).

---

### Provenance
Federal cells read live from `outputs/comprasnet/{tables,diagnostics}/` (2026-06-06 runs); R4 verdicts from `R4_EXECUTED.md`; table skeleton from `D3_TABLE_PREVIEW.md` with row 10 corrected against the on-disk `table_E_negative_controls.csv`; SRP adjudication from `early_triage_13_srp.md`; fill state from `federal_fill_report.csv`; integration steps from `R4_EXECUTED.md` + `claims_upgrade_conditional_deltas.md`. No manuscript file edited from this ledger.
