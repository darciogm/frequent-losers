# 28 — SUBPROMPT 10 LOG: Cost-recall frontier & sequential gatekeeping (JLEO R&R v22)

Date: 2026-06-03. Agent: mr-frequent-losers. Branch **`v22`** (R&R revision branch; Subprompts 1–9 committed; staying on it).

## SETUP / gates
Docs 00–27 present. Sub8 bid benchmark (Verdict E) + Sub9 compression done. NOT `COST_FRONTIER_BLOCKED_BY_MISSING_BID_BENCHMARK`. §6B written under the reach-and-limits reframe; honest framing = the FRONTIER (not a universal K1), with explicit firm-vs-bid-row denominator divergence.

## CONFIRMED INPUTS
- **Bid predictions cache** `outputs/cache/bid_benchmark_predictions.csv` (205,545 rows): firm_id, target, model_name {award_continuous, award_FL14, bid_RF, combined_RF}, validation_design {A_pooled_random, E_case_grouped, F_excl_label_tenders, G_env_holdout}, score_predicted, raw_award_score, FL14, bid_feature_availability, direct_defendant_flag. **Pool A (A_pooled) = 16,731 firms, 190 positives** (= the always-loser-with-complete-Imhof pool; relates to script-49 same-sample 11,676/193 and script-31 16,779/193).
- **Cost data:** `outputs/cache/imhof_tender_features.parquet` (per tender-item; n_bids), `v3/data/processed/bid_level_with_prices.parquet` (245MB raw bid rows per firm×tender-item), `data/processed/firm_tender_map.parquet` (firm→tender-items). buyer=substr(numerodaoc,1,11), year=substr(12,4), item_group=substr(códigoitem,1,2).
- **Existing gatekeeper (= K1=2000 point):** `\valGateSeqKTwoKOneTPIn`=131, `\valGateFootprintPct`=83\%, `\valArchPoolSize`=11,676, `\valArchNPos`=193, precision@500 FL/Imhof/joint/seq=0.132/0.146/0.224/0.192, recall@1000 joint/seq=0.736/0.679, TP@1000 joint=142. `\valArch*` defined INLINE in paper_submission_clean.tex:145+. Current `tab:gatekeeper_submission` at sec06:231 → REPLACE with the frontier (Table 6).
- `scripts/utils/cost_frontier.R` (Sub2) available.

## CRITICAL HONEST ANGLE (the referee's objection to make fail)
"83% = 1 − 2000/11,676" is mechanically firm-level. The frontier must report MULTIPLE cost denominators (firms / opened tender-items / opened bid rows full-tender / cells). Because survivors are the **highest-participation** always-losers, opening their tender-items (within-tender moments need the full tender-item LANCES record) opens a disproportionate share of bid rows → **the bid-row/tender-item reduction will be much smaller than the firm-level 83%.** Report this honestly; it is the contribution (the frontier + denominator transparency), not a nice K1.

## EXPECTED VERDICT: **B or C** — firm-level footprint reduction clean; realistic processing-burden (tender-items/bid-rows) reduction smaller. Frontier defensible; K1=2000 is one operating point.

## EXECUTION (fan-out)
- E1 (empirical core): NEW `scripts/analysis/10_cost_recall_frontier.R` — pools, rules (award-only/bid-only/joint/seq award→bid/seq award→combined/FL→bid/random), K1 grid {250…full}, k grid {100,250,500,1000}, ALL cost denominators, frontier metrics (TP/FP/FN/precision/recall/lift/cost-per-TP/marginal/vs-joint/vs-award-only), main Table 6, full grid, Fig 3, appendix tables/figs, case-holdout (design E), award-only timing frontier (bid strict-timing blocked).
- Me: cost_wedge_memo (Step 13, parallel). Writers W1 (§6B + Table 6 + Fig 3 + macros), W2 (Appendix G). Then claims scan, docs, completion report, build, verdict.

### Files read · data · scripts
Docs 00–27. bid_benchmark_predictions.csv; imhof_tender_features/firm_tender_map; bid_level_with_prices. cost_frontier util. gatekeeper macros + sec06.

### Scripts created
`scripts/analysis/10_cost_recall_frontier.R` (seed 20260603). Re-keyed RF to CNPJ (bid 0.886/combined 0.957 reproduce); cost denominators via firm_tender_map ⋈ imhof_tender_features.

### Cost denominators / K1 grid / k grid / rules / timing
Denominators: firms / survivor-firm-tender-items / opened tender-items / opened bid rows full-tender / survivor bid rows (lower bound) / buyer×item-group×year cells / buyers / item-groups. NOT_OBSERVED: LANCES exports, legal requests, monetary. Analyst-hours = illustrative proxy (appendix). K1 {250,500,1000,1500,2000,3000,5000,7500,full}; k {100,250,500,1000}. Rules: award-only, bid-only full-obs, joint full-obs, seq award→bid, seq award→combined, FL→bid, random. Timing: award-only frontier; sequential strict-timing BLOCKED.

### Results (Verdict B)
- K1=2000 reproduces (recall 0.668 @k1000; precision@500 0.182).
- **Firm vs bid-row reduction @K1=2000: 88% vs 33%** (tender-items 34%). Survivors high-participation.
- Recall (seq award→bid, k=500): K1 {500:0.34,1000:0.44,2000:0.48,3000:0.52,5000:0.42}; joint 0.52; award-only 0.34; random 0.10. Never beats joint.
- Award-survivor recall 0.78 @K1=2000 (bid reorders, no new positives).
- FP@K1=2000,k=500: 1,852 opened / 42 lost at gate / 409 final FP / 99-of-190 missed.
- Case-fragile: leave-largest-case-out 0.48→0.34.

### Manuscript edits
- `sec06` §6B rewritten "Sequential Gatekeeping and the Cost-Recall Frontier" + Table 6 + Fig 3; old `tab:gatekeeper_submission` deleted. `values.tex` +17 \valCost* (digit-free). `sec01` intro reframed (83%→frontier). Appendix G (sec_app06) → G.1–G.11 + 5 tables + 3 figs. Memo `cost_wedge_memo.md`.

### Commands run
`Rscript .../10_cost_recall_frontier.R` (~20s; RF rerun + DuckDB cost joins); compile paper+appendix. **Build fix:** LaTeX macro names cannot contain digits → `sed`-renamed all \valCost*2000/3000/k500/k1000 to letter-only (29 errors → 0).

### Build result
**PASS.** Paper **38pp** (was 36; Table 6 + Fig 3), appendix **49pp**. 0 errors, 0 undefined refs, 0 undefined control sequences. Main floats **6 tables / 3 figures** (at budget). claims critical=0.

### Failures / blockers
- Sequential strict-timing BLOCKED (documented). NOT_OBSERVED denominators (LANCES/legal/monetary). Case-fragility. Carried: B3, conservative-AUC, appendix length.
