# Section 7 (Price / Scope) Inventory

Scope: price-evidence section of the JLEO submission (`work/v22-editor/submission_clean/`).
All paths relative to repo root `/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers`.

## 1. Where §7 lives

| Item | File | Notes |
|---|---|---|
| §7 main section | `work/v22-editor/submission_clean/sec07_price_scope_submission.tex` | `\section{Scope, Limits, and Price Corroboration}`, `\label{sec:price_scope_conclusion}`. **Compressed**: header comment says "§7 cut to ~2pp, all 3 main tables deleted, refs repointed to Appendix". |
| §7 subsection | same file, `\subsection{Adaptive Deployment}` `\label{sec:adaptive_deployment_submission}` | Deployment-as-moving-queue prose; no numbers. |
| §7 paragraphs | "The broad price imprint" / "The sign reversal, decomposed" / "An honest limit on the mechanism" | All three carry the price macros below. |

### Price appendix
| Item | File | Notes |
|---|---|---|
| Price appendix | `work/v22-editor/submission_clean/sec_app04_scope_submission.tex` | `\section{Scope of Price Evidence}`, `\label{app:scope_adaptation_submission}`. **THIN: ~214 words, 0 tables.** Subsection `\subsection{Overlap and Segment Scope}` `\label{app:overlap_scope_submission}`. |

## 2. DANGLING PROMISE (flag)

§7 repeatedly points to the appendix for "full regressions":
- L14–15: "The full price regressions are reported in Appendix~\ref{app:scope_adaptation_submission}."
- L52–54: "Full regressions and the bidder-count boundary appear in Appendix~\ref{app:scope_adaptation_submission}."

But `sec_app04_scope_submission.tex` is **prose-only, 0 tables, ~214 words.** It contains NO regression grid, NO bidder-count decomposition table, NO modality/quartile/segment table. The promised "full price regressions" and "bidder-count boundary" do not exist in the appendix. **The dangling-appendix-promise is real and must be closed** by adding the regression tables (data already exist as CSVs — see §4). The appendix also references macros `\valSRQoneBroad … \valSRQfourATT … \valSRTrim*` for a segment narrative but presents them only as inline prose, not as a table.

## 3. Price macros used in §7 (with values + sources)

All values from `work/v22-editor/submission_clean/values.tex` unless noted. `\valHeadlineRange` is defined in `paper_submission_clean.tex` (and `online_appendix_submission_clean.tex`), NOT in values.tex.

| Macro | Value | Source CSV |
|---|---|---|
| `\valTabPricesColOne` | `0.0677^{***}` | output/tables/tab_prices.tex col(1) |
| `\valTabPricesColTwo` | `0.0636^{***}` | output/tables/tab_prices.tex col(2) |
| `\valTabPricesColThree` | `0.0933^{***}` | output/tables/tab_prices.tex col(3) Pregão |
| `\valTabPricesColFour` | `0.0382^{**}` | output/tables/tab_prices.tex col(4) Convite |
| `\valHeadlineRange` | `+3.6%--+7.7%` | implied band from cols 1/2 (paper_submission_clean.tex) |
| `\valBetaBroad` / `…P` / `…N` | `+0.064` / `0.003` / `1,654,401` | output/sign_reversal_decomp/headline_specs.csv (broad_sample_beta) |
| `\valBetaOverlapATT` / `…P` | `-0.097` / `<0.001` | headline_specs.csv (overlap_cell_att) |
| `\valScopeOverlapCoef`/`SE`/`Plt`/`N` | `-0.097`/`0.015`/`<0.001`/`1,517,066` | output/item_level_scope_match/item_level_scope_match.csv (overlap_cell_att) |
| `\valScopeOverlapRefCoef`/`SE`/`N` | `-0.097`/`0.015`/`1,434,636` | item_level_scope_match.csv (overlap_ref_att) |
| `\valScopePSCoef`/`SE`/`N` | `-0.307`/`0.020`/`400,687` | item_level_scope_match.csv (ps_att_trimmed) |
| `\valBetaUnwOverlap` / `…P` | `+0.044` / `0.035` | headline_specs.csv (overlap_cell_unweighted) |
| `\valDroppedItemsShare` | `1.06%` | output/sign_reversal_decomp/cell_dropping_dimensions.csv (dropped_no_control) |
| `\valSelTestQOne` / `QFive` | `1.35` / `6.93` | output/selection_mechanism/non_treated_price_by_fl_share.csv |
| `\valSelTestDelta` | `5.58` | non_treated_price_by_fl_share.csv (Q5−Q1) |
| `\valSelTestCoefFullFE`/`SEFullFE`/`N` | `+3.55`/`0.23`/`1,439,255` | output/selection_mechanism/selection_test_results.csv (all-5-dim-FE row) |
| `\valSelTestCoefRaw`/`SERaw`/`CoefFE`/`SEFE` | `+22.65`/`0.03`/`+24.04`/`0.56` | selection_test_results.csv (raw / item-group+year-FE rows) |
| `\valSignBetaConvATT` / `PregATT` | `-0.099` / `-0.098` | output/sign_reversal_decomp/within_overlap_subgroup_betas.csv (modality 0 / 1) |
| `\valSignBetaQoneATT` / `QfourATT` | `-0.053` / `+0.041` | within_overlap_subgroup_betas.csv (tender_value_q 1 / 4) |
| `\valSignBetaCADEDirectATT` / `CADENonDirectATT` | `-0.061` / `-0.097` | within_overlap_subgroup_betas.csv (any_direct 1 / 0) |
| `\valBetaQfour` / `…P` | `+0.041` / `0.045` | within_overlap_subgroup_betas.csv (tender_value_q 4) |
| `\valBetaCADEDirect` / `…P` | `-0.061` / `0.45` | within_overlap_subgroup_betas.csv (any_direct 1) |
| `\valMechWinnerVsRef` / `SE` | `-0.048` / `0.004` | output/mechanism_within_cell/bidder_decomp.csv (winner_vs_ref~losers) |
| `\valMechWinnerVsRefControlled` / `SE` | `+0.008` / `0.004` | bidder_decomp.csv (+log(n_firms), ns) |
| `\valSRQ*Broad` / `\valSRQfourATT` / `\valSRTrim*` (appendix) | (appendix segment narrative) | output/sign_reversal_segment/segment_betas.csv + att_trim_sensitivity.csv |

## 4. Price scripts and their outputs

| Script | Outputs (under `output/`) | Feeds |
|---|---|---|
| `scripts/03_tables.R` | `tables/tab_prices.tex`, `tables/tab_modal_id.tex` | TabPricesCol1-4, HeadlineRange |
| `scripts/51_item_level_scope_match.R` | `item_level_scope_match/item_level_scope_match.csv` | ScopeOverlap*, ScopePS* (overlap_cell_att, overlap_ref_att, ps_att_trimmed) |
| `scripts/59_sign_reversal_decomp.R` | `sign_reversal_decomp/{headline_specs, within_overlap_subgroup_betas, cell_dropping_dimensions, per_dimension_overlap_share, screening_alignment}.csv` | BetaBroad, BetaOverlapATT, BetaUnwOverlap, DroppedItemsShare, SignBeta*, BetaQfour, BetaCADEDirect |
| `scripts/61_selection_mechanism_test.R` | `selection_mechanism/{selection_test_results, non_treated_price_by_fl_share}.csv` | SelTest* |
| `scripts/61_sign_reversal_segment_decomp.R` | `sign_reversal_segment/{segment_betas, att_trim_sensitivity, att_weight_concentration, top_weight_cells}.csv` + `fig_segment_betas.pdf` | SR Q*/Trim* (appendix) |
| `scripts/62_within_cell_mechanism_test.R` | `mechanism_within_cell/{mechanism_test_results, mechanism_by_bidder_count, m1_m2_revalidated}.csv` | MechWinnerVsRef* |
| `scripts/78_bidder_count_decomposition.R` | `mechanism_within_cell/{bidder_decomp.csv, bidder_decomp_log.txt}` | genuine-vs-FL split (l_gen/l_fl), MechWinnerVsRef* |
| (continuous comparator) `output/continuous_vs_binary/cont_vs_bin_price_regressions.csv` | binary vs continuous price betas (context) | not §7-specific |
| (stratum context) `output/stratum_scope/stratum_scope_metrics.csv` | AUC scope table | not a price reg |

## 5. Price / adaptation figures

| Figure | File | Used in §7? |
|---|---|---|
| Segment betas | `output/sign_reversal_segment/fig_segment_betas.pdf` | Not referenced in sec07/sec_app04 — candidate for the appendix table/figure to close the dangling promise. |
| Unified mechanism | `output/unified_mechanism/fig_unified_mechanism.pdf` | Not referenced in §7. |

No price-specific figure is currently `\includegraphics`-ed in sec07 or sec_app04. The Adaptive-Deployment strategic-simulation lives in "Appendix F" per sec_app04 L9 (separate).

## 6. Summary action

1. **Close the dangling promise**: add the full price-regression grid (broad / overlap-unweighted / overlap-ATT / PS-trimmed, plus modality + value-quartile + direct-CADE rows + the bidder-count decomposition) to `sec_app04_scope_submission.tex` as proper tables. All data already exist in the CSVs above — no re-estimation needed.
2. The appendix currently references `\valSR*` macros in prose only; convert to a table sourced from `segment_betas.csv` / `att_trim_sensitivity.csv`.
