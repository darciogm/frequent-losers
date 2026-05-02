# JLEO Editorial Map — Paper 3 (v19 reframe, planning pass)

**Status:** PART 1 of the JLEO reframe — diagnosis only, no rewriting yet.
**Date:** 2026-05-01.
**Companion files:** `RESULTS_INVENTORY_JLEO.csv`, `project_paper3_jleo_reframe_brief.md` (memory).

---

## 1. New paper identity

The paper's identity must shift from a procurement-management contribution to a law-and-economics / organization contribution about screening under coarsened observability.

| Dimension | Current (v18-final) | JLEO target (v19) |
|---|---|---|
| Genre | Procurement triage / oversight tool | Screening under incomplete observability; enforcement design under partial information |
| Central question | "What signal can oversight bodies extract from contract-award records when bid microdata are unavailable?" | "What collusion-relevant information survives when enforcement observes only the contract-award layer rather than the bid layer?" |
| Theory's role | Organizing device, lightly used | Conceptual core: derives why the loss-intensity statistic is the primitive, why `wins=0` is the equilibrium-separating filter, and why endogenous sorting into the broad sample is part of the screening object |
| Sign reversal | "Two estimates answer different empirical questions about the same population" | Screening-value object vs treatment-effect object: forcing overlap removes the endogenous sorting that *generates* the screen's economic value |
| Contribution | Triage tool deployable on award records | (i) screening statistic that survives data coarsening; (ii) award-layer/bid-layer enforcement-stage separation; (iii) cartel adjacency as the appropriate validation object under coarsened data |
| Buyer-size heterogeneity | "Thinner institutional capacity at smaller buyers" | "Heterogeneity in the monitoring/detection regime; informativeness of the screen across enforcement environments" |
| Conclusion payoff | "Tool for oversight bodies where bid microdata are absent" | "Which screening statistics survive coarsening; how screening and forensic stages should be separated under incomplete observability; implications for enforcement design in organizationally structured bidding environments" |

---

## 2. Core evidentiary spine for the JLEO version

Under the new identity, the load-bearing evidence narrows to six items, in this logical order:

| # | Object | Role under JLEO frame | Status |
|---|---|---|---|
| **A** | Theory-to-statistic operationalization (Prop.~exposure_stmt + Lemma~wins_zero_stmt) | Why the participation primitive is `log(1+tenders_count)` and the filter is `wins=0`. Anchors §3. | Already in Appendix A; promote to main §3 as "Theory and Operationalization". |
| **B** | `tab_horse_race_v14` — continuous loss-intensity vs binary FL14 (DeLong $p<0.001$) | Empirical test of which statistic survives data coarsening. Justifies the choice of primitive. | Currently in §8.1; promote to main §6 as the first piece of evidence. |
| **C** | `tab_prices` — broad-sample price association ($+3.6\%$ to $+7.7\%$) across 4 estimators | Headline screening-value evidence under coarsened observability. | Currently in §7; **stays as Table 1 of Results**, recast as screening-value (not treatment-effect) evidence. |
| **D** | `tab_item_level_scope_match` — overlap-cell ATT $-9.72\%$, PS-trimmed $-30.67\%$ | The sign reversal as the centerpiece of the screening-value-vs-treatment-effect distinction. | Currently in §9.1 (Robustness); **promote to §6.2** as the conceptual centerpiece. |
| **E** | `tab_regime_oversight` + `fig_14_oversight_heterogeneity` — buyer-size gradient | Heterogeneity in the monitoring/detection regime. Demonstrates the screen's informativeness varies with the enforcement environment. | Currently in Appendix B; **promote to main §6.3** with reframed labels. |
| **F** | CADE validation (§6.1 populations table + conservative + prospective benchmarks) | Cartel adjacency as the appropriate validation object under coarsened data; AUC differential $0.748$/$0.864$ vs $0.491$ defines scope. | Stays as main §7 (renamed "Validation: Cartel Adjacency"). |

The Imhof–Wallimann benchmark (`tab_imhof_full`) becomes the §8 closer: empirical evidence on the screening-vs-forensic-stage separation. Same data layer, different questions.

Everything else moves to the appendix or out.

---

## 3. Editorial decisions (full set)

### 3.1 KEEP in main text (potentially promoted)

| Object | From | To |
|---|---|---|
| `tab_theory_operationalization` | §4.2 | §3 (Theory & Operationalization) |
| `tab_strict_train_threshold` | §4.2 | stay §4 (data + temporal honesty) |
| `tab_desc_stats` | §4.3 | stay §4 |
| `tab_horse_race_v14` | §8.1 | promote to §6 (first evidence) |
| `tab_prices` | §7.1 | stay §6 (Table 1 of Results) |
| `tab_item_level_scope_match` | §9.1 | promote to §6.2 (sign-reversal centerpiece) |
| `tab_regime_oversight` | Appendix B.3 | promote to §6.3 (monitoring-regime heterogeneity) |
| `fig_14_oversight_heterogeneity` | unused | add to §6.3 alongside `tab_regime_oversight` |
| `tab_falsification_modal` | §7.1 + Appendix B.4 | stay §6 (modal informativeness contrast) |
| `tab_imhof_full` | §9.4 (Robustness) | promote to §8 closing (screening vs forensic) |
| `tab_cade_populations` (inline) | §6.1 | stay §7 (renamed "Validation: Cartel Adjacency") |
| `tab_cade_fl_firms` | §6.3 | stay §7 (within-firm enrichment) |

### 3.2 KEEP in appendix

| Object | From | To |
|---|---|---|
| Theory propositions (full proofs) | App A | stay App A |
| `tab_modality_by_year` | App B | stay |
| `tab_conditional_descstats` | App B | stay |
| `tab_mccrary` + `fig_density_shift` + `fig_regime_densities` | App B | bundled |
| `tab_excl_cade` | App B | stay |
| `tab_oster_delta` | App B | stay |
| `tab_leakage_audit` | App C | stay |
| `tab_threshold_robustness` + `tab_threshold_q3iqr` + `fig_07_threshold_stability` + `fig_12_fl_definition_robustness` + `fig_threshold_heatmap` | App B | bundle as "Threshold robustness" |
| `tab_clustering_robustness` | App B | stay |
| `tab_iv_placebo` + `fig_first_stage_binscatter` | App C | bundle |
| `tab_did_revised` + `tab_stacked_did` + `fig_06_event_study` + `fig_06_cs_event_study_price` + `fig_06_cs_event_study_nfirms_excl` | App D | bundle as "Design-based strategies that return null" |
| `tab_operational_metrics` | §9.3 | demote to App E |
| `tab_imhof_incremental` | App E | stay |
| `tab_adversarial_adaptation` + `values_adversarial.tex` | App G | stay |
| `tab_negative_cell_audit` | §8.3 | demote to App F (mechanism predictions undecided) |
| `tab_predictions_findings` | unused | add to main §3 closing or App A as theory-empirics bridge |
| `tab_external_validity_scope` | unused | add to App H (portability) |
| `tab_cade_permutation` | unused | add to App C (validation rigor) |
| `fig_08_sensitivity_contour` | unused | add to App B alongside Cinelli/Oster |
| `fig_01_losses_distribution` + `fig_02_iqr_identification` | App B | stay (or `fig_02` promoted to §3 figure with theory) |

### 3.3 DROP (legacy or incompatible)

| Object | Reason |
|---|---|
| `tab_bajari_ye*` (4 tables) | Old framework; conflicts with current narrative. |
| `tab_iv_main`, `tab_iv_main_panelc`, `tab_iv_first_stage`, `tab_iv_balance` | Old IV framework; current draft uses leave-one-out IV only as diagnostic. |
| `tab_iv_network_split`, `tab_network_interactions`, `tab_network_split`, `tab_fl_network_summary`, `fig_11_network_split`, `fig_network_graph`, `fig_network_hhi` | Network angle not load-bearing under JLEO frame. |
| `tab_dyadic_permutation` | Superseded by `25_sham_fl_permutation` → `tab_cade_permutation`. |
| `tab_cox_survival`, `fig_km_fl_exposure` | Survival angle not used. |
| `tab_homogeneous_cv`, `tab_homogeneous_subsample` | Overlap with `tab_imhof_full`. |
| `tab_fl_crossfit` | Cross-fit estimate now inline. |
| `tab_fl_lowwinrate`, `tab_fl_temporal` | Superseded. |
| `tab_matching` | Older CEM/IPW; superseded by `tab_item_level_scope_match`. |
| `tab_mechanisms`, `tab_unified_mechanism` | Older mechanism summaries; not aligned with current §8. |
| `tab_robustness_summary_inline` | Superseded by individual robustness tables. |
| `tab_tighter_controls` | Older tightening exercise; superseded. |
| `tab_unrestricted_sample` | Coefficient referenced inline in §4.3; standalone table not needed. |
| `tab_regime_test` | Old regime test; superseded. |
| `tab_welfare_bounds`, `fig_09_welfare_markup`, `fig_welfare_heatmap` | Welfare/markup angle incompatible with JLEO frame (managerial). |
| `fig_03_coef_summary`, `fig_05_regime_boxplot`, `fig_10_year_coefficients` | Visual fillers, redundant with tables. |

### 3.4 ADD from existing scripts (currently unused)

| Object | Source | Destination | Why |
|---|---|---|---|
| `tab_predictions_findings` | manual + scripts 31–46 | main §3 closing or App A | Bridge from theory propositions to empirical findings — under JLEO frame this is load-bearing as the conceptual map. |
| `tab_cade_permutation` | scripts/25_sham_fl_permutation.R | App C | Permutation $p<0.001$ baseline for the validation; rigor signal. |
| `fig_14_oversight_heterogeneity` | scripts/04_figures.R | main §6.3 | Visual companion to `tab_regime_oversight`. |
| `tab_external_validity_scope` | scripts/52_external_validity_scope.R | App H (portability) | Anchors §10.3 portability claim that currently sits in prose only. |
| `fig_08_sensitivity_contour` | scripts/04_figures.R + 02_analysis.R | App B | Cinelli sensitivity contour; replaces prose mention of $RV_{q=1}$. |
| `tab_stratum_scope` | scripts/48_stratum_scope_reframe.R | main §6.2 supporting (or App F) | Stratum-scope reframe of how AUC/coefficient depend on the always-loser stratum boundary. Could supplement the sign-reversal §6.2 if the conceptual extension lands. |
| `fig_07_threshold_stability`, `fig_threshold_heatmap`, `fig_12_fl_definition_robustness` | scripts/04, 18, 41 | App B (threshold robustness bundle) | Visual evidence of the stability of the participation primitive. |
| `tab_gate_diagnostics` | scripts/36–39 | App I (optional, "Design diagnostics") | Gate D1–D4 transparency. **Author decision** — could be a strength signal but might invite questions. Default: skip. |
| `fig_first_stage_binscatter` | scripts/02_analysis.R | App C (with `tab_iv_placebo`) | Visual first-stage. |
| `fig_density_shift`, `fig_regime_densities` | scripts/13 | App B (with `tab_mccrary`) | Visual McCrary. |

---

## 4. Section-level reorganization (proposed)

| Current section | JLEO target |
|---|---|
| §1 Introduction | Rebuilt — 6-paragraph architecture (incomplete observability → screening question → answer → theory preview → empirical preview → contribution as law-econ-org) |
| §2 Related Literature | Repositioned — adds enforcement-with-incomplete-information pillar; reduces procurement-administration emphasis |
| §3 Legal & Institutional Framework | Largely intact (already lean); rename emphasis from "platform/audit infrastructure" to "data layers and observability regime" |
| §4 Data and Frequent Losers Definition | Kept; tightened (drop §4.4 and merge into §7 to avoid duplication) |
| **NEW §3 / between §3 and §5: Theory and Operationalization** | New section pulling Lemma + Proposition out of Appendix A into main text, with `tab_theory_operationalization` and (optionally) `tab_predictions_findings` |
| §5 Empirical Strategy | Kept; reframe "descriptive identifying stance" → "screening-value identification under coarsened data" |
| §6 Validation Against CADE Adjudications | Renamed: "Validation: Cartel Adjacency Under Coarsened Observability" |
| §7 Main Results | Restructured into three subsections: §7.1 horse race (which statistic survives coarsening), §7.2 broad-sample price association, §7.3 the sign reversal as screening-value-vs-treatment-effect |
| §8 Mechanism Heterogeneity | Restructured: §8.1 modal contrast (informativeness across detection environments), §8.2 monitoring-regime gradient (buyer size), §8.3 demoted to appendix |
| §9 Robustness | Trimmed: leakage audit + threshold sensitivity stay; everything else demoted to appendix |
| **NEW §10: Screening vs Forensic Stages** | Short section with Imhof comparison reframed as "the same data layer answers different questions" — closes the conceptual loop |
| §11 Limitations | Tightened; reframed to scope under JLEO contribution (incomplete observability scope, not procurement-policy scope) |
| §12 Conclusion | Rewritten to end on screening-survival / enforcement-design / organizationally-structured-bidding implications |

Net effect: from 12 sections (40pp) to 12 sections (~36pp expected) with a sharper conceptual spine.

---

## 5. Reproducibility status (input to PART 2)

The current setup uses `values.tex` (495 macros) + `values_adversarial.tex` (15 macros) generated by `scripts/99_make_paper_values.R`, plus `\input{./output/tables/...}` for table fragments. Most tables are already linked.

**Gaps to close in PART 2:**

| Item | Current | Target |
|---|---|---|
| `tab_prices` cells | Bound (post-Table-6 fix) — 20 macros | Already JLEO-ready |
| `tab_horse_race_v14` cells | Partial — caption macros only | Bind all 12 cells |
| `tab_falsification_modal` cells | Partial — top-line macros, table cells hardcoded | Bind all cells (8 main + 4 joint + 3 N rows) |
| `tab_item_level_scope_match` cells | Partial | Bind all cells (4 specs × 4 lines) |
| `tab_regime_oversight` cells | None — all hardcoded | Bind all 18 cells (4 quartiles × 3 + 2 modal × 3) |
| `tab_oster_delta` literal $\hat\delta=261.64$ in §6.2 prose | Hardcoded literal | Bind to `\valOsterDelta` |
| Conservative-benchmark literals (30, 210, 108) in §6.2 prose | Hardcoded | Add `\valConservativeFD`, `\valConservativeCobidders`, `\valConservativeFL` |
| `tab_strict_train_threshold` cells | Partial | Bind all rows |
| `tab_desc_stats` cells | None | Bind all cells |
| `tab_excl_cade` cells | Partial — `\valCADEpermObs`, `\valCADEpermPerm` | Bind remaining cells |
| `tab_modality_by_year` cells | None | Bind |
| `tab_conditional_descstats` cells | None | Bind |
| `tab_threshold_robustness` cells | None | Bind |
| `tab_clustering_robustness` cells | None | Bind |
| `tab_iv_placebo` cells | Partial (\valBidPHigh, F=33 hardcoded) | Bind first stage F, 2SLS coef |
| `tab_did_revised` + `tab_stacked_did` | None | Bind (or accept as transparency-only since DiD is null) |
| `tab_operational_metrics` precision/lift cells | Partial (some \valPrec*) | Bind all |
| `tab_imhof_full` AUC cells | None — hardcoded (0.903 / 0.884 / 0.888 / 0.752) | Bind all 8 cells |
| `tab_imhof_incremental` cells | None | Bind |
| `tab_negative_cell_audit` cells | None | Bind (in case kept) |
| `tab_adversarial_adaptation` cells | Partial (\valAUCBase, \valAUCAdaptCombined, \valAdapt*) — main numbers bound; row literals (0.928, 0.931, 96.0%) still hardcoded | Bind row entries |
| `tab_leakage_audit` cells | Partial | Bind row entries (0.995, 0.506, 0.891, 0.864) |
| `tab_theory_operationalization` cells | None | Bind |
| Conservative-benchmark CI `[0.713, 0.783]` in §7.2 | Bound (\valCADEcobidCIlo, \valCADEcobidCIhi) | Use `\valCADEpilotCIlo` macro consistently |

PART 2 will close these gaps and audit the pipeline `99_make_paper_values.R` so a single command reproduces every macro from the underlying script outputs.

---

## 6. What strengthens / what weakens the JLEO case

### Strengthens
- The horse race result (continuous dominates binary) maps cleanly onto "what statistic survives coarsening".
- The sign reversal becomes an opportunity rather than a vulnerability under the new framing.
- The Imhof comparison can carry the screening-vs-forensic-stage separation argument as a clean closing.
- `tab_predictions_findings` (currently unused) maps theory propositions to empirical findings in one table — a JLEO-style bridge.
- The CADE validation is structurally the right object under JLEO frame (cartel adjacency, not membership).

### Weakens (to be mitigated in writing, not by adding evidence)
- The buyer-size gradient is still under-identified; the reframe to "monitoring regime" does not solve this. Disclose openly.
- The cobidder label remains indirect by construction; no extra evidence will fix this. The JLEO frame *uses* this honestly: indirect labels are the right validation object under coarsened observability.
- The first-time-FL prediction does not survive PS matching. Demote (already in §8.3) and own it.
- The convite/pregão modal asymmetry inverts the naive quorum-rule prediction. Under JLEO frame this is informative (informativeness varies across detection environments), not falsifying. Reframe in §6 / §8.

### Unresolved weaknesses requiring author input (flagged for PART 2)
- **U1.** Whether to add `tab_external_validity_scope` (cross-sector replication) to App H. It exists in scripts but was not in the current draft. Author decision.
- **U2.** Whether `tab_predictions_findings` becomes a §3 table or an Appendix A table.
- **U3.** Whether to keep §8.3 (mechanism predictions undecided) in main text at all, or push the entire subsection to App F.
- **U4.** Whether to include `tab_gate_diagnostics` as a transparency appendix. The gates (D1–D4) explain why the paper went JLEO-not-JLE; revealing them is honest but invites questions a referee may not have asked.
- **U5.** Whether to keep `tab_operational_metrics` at all. Operational/managerial framing is incompatible with JLEO, but the same content recast as "deployable scope" (App E) could anchor the screening-stage claim. Author decision.

---

## 7. Plan for PART 2 (do not start yet)

When authorized:

1. Branch `v19-jleo` (or work in `v15-editor` after backup commit `paper3 v18-final: backup before JLEO reframe`).
2. Build the new §3 (Theory & Operationalization) by promoting Lemma + Proposition from Appendix A.
3. Rewrite §1, §2, §6 (Validation), §7 (Results), §10 (new), §11 (Limitations), §12 (Conclusion) per the architecture in §4 of this memo.
4. Reposition `tab_horse_race_v14`, `tab_item_level_scope_match`, `tab_regime_oversight`, `fig_14_oversight_heterogeneity`, `tab_imhof_full` per §3 of this memo.
5. Demote `tab_negative_cell_audit`, `tab_operational_metrics`, parts of `tab_did_revised`/`tab_stacked_did` per §3.2 of this memo.
6. Drop the legacy material in §3.3 of this memo (already not in current paper; just don't accidentally reintroduce).
7. Close all reproducibility gaps in §5 of this memo. New macros and pipeline hooks emitted from `99_make_paper_values.R`.
8. Generate `JLEO_REFRAME_MEMO.md`, the final `RESULTS_INVENTORY_JLEO.csv` (status updated), and `REPRODUCIBILITY_LINKING_MEMO.md`.

PART 2 will produce a new compiled PDF; expected length is similar to current (38pp main + 15pp OA, possibly slightly heavier in main text due to the new §3 and §10).

---

*End of PART 1 memo. Awaiting author authorization to begin PART 2.*
