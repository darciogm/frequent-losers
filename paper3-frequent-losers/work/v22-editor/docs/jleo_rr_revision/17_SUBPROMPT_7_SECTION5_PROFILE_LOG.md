# 17 — SUBPROMPT 7 LOG: Section 5 economic profile, monotonicity, binary-vs-continuous, ordinary-loser alternatives (JLEO R&R v22)

Date: 2026-06-03. Agent: mr-frequent-losers. Branch **`v22`** (R&R revision branch; Subprompts 1–6 committed; staying on it, documented).

## SETUP / gates
Docs 00–16 + memos + timing_information_sets present. Sub4 RECONCILED, Sub5 Verdict B, Sub6 Verdict C+D → reframe to "Reach and Limits" executed. NOT `SECTION5_BLOCKED_BY_MISSING_PRIOR_OUTPUTS`. §5 written UNDER the reframe.

## CONFIRMED INPUTS
- **Sub5 firm frame** `outputs/cache/firm_opportunity_adjusted_frame.csv` — RICH: firm_id, T_i, W_i, score_i, fl14, cobidder, Y_broad, O_i, n_opp_items, contact_intensity, n_def_firms, n_cases, n_items_total, n_buyers, n_years, n_item_groups, E_i{COARSE,MEDIUM,STRICT}+LOO, n_cells, n_def_cells, max_cell_rate, share_in_def_cells, X_i(excess)+LOO+Z, log_E. (Most profile vars exist; HHI/modality/tender-value/first-last-year/bid-layer need joins.)
- Case linkage `output/label_funnel/case_cobidder_map.csv`; script 53 strict-pool flip (binary 0.767 > cont 0.750, DeLong p=0.085 NOT sig) = the binary-vs-continuous evidence.
- Current `sec05_cobidder_type_submission.tex` (191 lines): "The Economic Profile of **Cartel-Adjacent** Losers" → REFRAME to "adjudication-anchored exposure"; subsections Comparing/Bid-Level/Interpretation.
- Appendix master \input app00–app06 (A–G); sec_app04=E (price). §5 appendix → NEW **Appendix H** (`sec_app08_profile`) + one \input line.
- Script naming: Sub6 used `04_case_holdout_dominance.R` → new scripts are **`05_section5_profile_monotonicity.R`** + **`06_section5_robustness.R`** (avoid collision).

## EXPECTED VERDICT (pre-data): **B (descriptive support, opportunity-composition important)** possibly → **D (ordinary-loser alternatives central)**. Sub5 showed exposure dominates; Sub6 showed one-case concentration. Cobidder proximity differences partly MECHANICAL (cobidders co-bid with defendants by construction). Honest §5: cobidders drawn from different procurement environments; residual behavioral distinction limited after opportunity adjustment; binary FL14 = administrative not structural; ordinary-loser alternatives narrowed not eliminated.

## EXECUTION (fan-out, 2 parallel empirical streams + 2 writers)
- **E1 (core):** `05_section5_profile_monotonicity.R` — groups A–Q, Table J economic profile, standardized diffs (+figure), opportunity-adjusted profile (Table K), monotonicity bins (Table L +2 figs), binary-vs-continuous (Table M) + memo. Steps 5–10.
- **E2 (robustness):** `06_section5_robustness.R` — threshold sensitivity + bunching T=14, ordinary-loser alternatives (Table N), market-specific zero-win, negative controls. Steps 11–14.
- W1 (§5 rewrite + main tables + macros); W2 (new Appendix H + master \input). Me: claims scan, docs, completion report, build, verdict.

### Files read · data
Docs 00–16 + memos. firm frame cache. sec05, appendix master, sec_app04. firm_tender_map, FREQ_PARTICIP_rebuilt, cade_fl_cobidders, cade_bec_crossmatch. Utils metrics_triage.

### Scripts created
`scripts/analysis/05_section5_profile_monotonicity.R` + `06_section5_robustness.R` (seed 20260603).

### Profile groups
A–M + H (defined identically in both scripts). D FL non-cobidders=2,544; E FL cobidders=191 (all cobidders are FL14 → E≡F); H direct defendants=46 (6 in AL), excluded from A–G (asserted).

### Results (honest — VERDICT B)
- **Table J (distinct):** Pregão 96.6% vs 66.6% (SMD 0.76), buyers 24.9 vs 14.3 (0.72), years SMD 0.84, proximity SMD 3.76/3.12 (partly mechanical). 
- **Table K (attenuation):** item-group HHI VANISHES (0.45→0.02); buyer breadth 0.72→0.19; proximity halves (3.76→2.25).
- **Monotonicity (KEY):** prevalence Spearman +0.92 with T_i; opportunity-adjusted EXCESS Spearman −0.93 → EXPOSURE ranking, not collusion-intensity.
- **Binary-vs-continuous:** continuous ties/beats FL14 full-sample (0.939 vs 0.924); 53's flip sample-specific; T=14 administrative; bunching ratio 1.06 (none).
- **Ordinary-loser (Table N):** narrowed not eliminated; distance/geography/later-wins NOT_OBSERVED.
- **Market-zero-win:** global not dominated (alt 0.554–0.774); leave-one-IG-out [0.936,0.941].
- **Negative controls (STRENGTH):** real 0.939 vs placebo-anchor 0.755 / non-CADE-winner 0.780, p<0.001 on ROC; honest PR-AUC base-rate caveat (p=0.70).

### Manuscript edits
- `sec05` rewritten 5.1–5.6, retitled "Economic Content and Ordinary-Loser Alternatives" ("cartel-adjacent" removed); Tables J/K/L/M/N inline + 3 figures. `values.tex` +19 \valProf*.
- NEW `sec_app08_profile_submission.tex` (Appendix H, H.1–H.9, 6 tables + 3 figs) + `\input` in appendix master.

### Commands run
`Rscript .../05_...R` (~4s) + `.../06_...R` (~173s, B=500 negative-control loop); `make diagnostics`; compile paper+appendix. **Build fix:** Appendix H tables had `adjustbox` nested INSIDE `threeparttable` (102 appendix errors) → reordered to `adjustbox` outermost (working convention) via fixer agent; 1 dangling `\ref{app:profile_ordinary_submission}` redirected to `Section~\ref{sec:cobidder_type}`.

### Build result
**PASS.** Paper **59pp** (was 53), appendix **44pp** (was 34). 0 errors, 0 undefined refs/cites, 0 undefined control sequences, no overfull >35pt. claims critical=0. 6 new figs + 5 main tables + Appendix H resolve.

### Failures / blockers
- NOT_OBSERVED: tender value (winner-only panel coverage 1%), distance-to-winner (bid prices VARCHAR locale-decimals), geography (no geo in firm_tender_map), later-wins (2019 right-censored) → ordinary alternatives B/E not fully ruled out.
- Carried: conservative-AUC re-estimation; B3 absent 193 builder; App D/H length.
