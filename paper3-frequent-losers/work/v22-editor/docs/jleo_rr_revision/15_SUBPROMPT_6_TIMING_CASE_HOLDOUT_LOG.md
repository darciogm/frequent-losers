# 15 — SUBPROMPT 6 LOG: Timing, leakage, rolling-origin, leave-one-case-out, case dominance (JLEO R&R v22)

Date: 2026-06-03. Agent: mr-frequent-losers. Branch **`v22`** (R&R revision branch; Subprompts 1–5 committed here; staying on it, documented). Paper3 v22-editor tree clean (unrelated paper1/2/18 + stale dirt untouched).

## SETUP / gates
Docs 00–14 + memos present. Subprompt 5 ended **VERDICT B** (residual signal survives exposure, attenuated) — NOT Verdict C, so proceed (under the downgraded claim). Label funnel RESOLVED (Sub4) → NOT `TIMING_VALIDATION_BLOCKED_BY_LABEL_FUNNEL`.

## CONFIRMED INPUTS
- **case linkage** `output/label_funnel/case_cobidder_map.csv` (5,121 rows: cnpj, proc, jdate, is_AL, is_FL) → LOCO ready. case_id = `proc`; only `jdate` (judgment, 9/12 cases) — **no conduct/filing dates → DAY_LEVEL_TIMING_UNAVAILABLE; year-level timing only**; year=substr(numerodaoc,12,4).
- **script 53** `output/strict_train_threshold/`: strict 2009-16→2017-19 firm AUC **FL_train 0.767** [0.734,0.800] > **cont 0.750** [0.706,0.795]; threshold_train **7** (vs full 13.5); n_pos 193, n 21,819, n_flagged 3,365, precision_flagged 0.039, recall_flagged 0.684, top500 prec 0.062/rec 0.161; DeLong z=1.72 **p=0.085** (binary>cont, NOT sig). item_2017-19 cont AUC 0.770.
- **script 77** `output/reverse_causality_timing/`: TIMING FAIL — cobidders year-HHI 0.553 vs ctrl 0.727 (d=−0.66, p=5e-19), MORE temporally spread → **deployment vs sincere persistence observationally equivalent**; do NOT claim prospective causal use.
- **script 33** + `\valAUCdirectCADE`=0.491 (direct-defendant scope check, random).
- **Sub5 frame** `outputs/cache/firm_opportunity_adjusted_frame.csv` (O_i/E_i/exposure). Sub5 flag: top CADE case ≈47% of TP@500; top item-group ≈32%.

## EXPECTED VERDICT (pre-data): **B (limited prospective for incumbents) + case-dominance caveat.** Strict firm AUC ~0.75–0.77 retained; but (i) script-77 timing concentration FAILS, (ii) ≈47% TP@500 from one case → leave-largest-case-out is the decisive test (Verdict D risk if it collapses).

## EXECUTION (fan-out, 2 parallel empirical streams on disjoint outputs)
- **E1 (timing):** NEW `scripts/analysis/03_timing_case_holdout_validation.R` — information sets (5A–G), strict 2009-16→2017-19 (5 samples + PR battery + entrant/tie), rolling-origin 2014–2019 (training-window-only scores, PR-led), leakage audit, direct-defendant timing scope. Reuse script 53 + metrics_triage.
- **E2 (case/environment):** NEW `scripts/analysis/04_case_holdout_dominance.R` — LOCO (case_cobidder_map), leave-largest/top-two, case dominance + top-k case coverage + case-balanced metrics, environment dominance (buyer/item/modality), clustered randomization inference. Reuse metrics_triage.
- Phase B (parallel writers after verify): W1 new §4.4 "Timing, Leakage, and Case Composition" + main Table I + Fig 2 revision + macros; W2 appendix technical. Me: claims scan, docs, completion report, build, verdict.

### Files read · data · scripts
Docs 00–14 + memos. `scripts/{53,77,33}` + outputs. `case_cobidder_map.csv`. `firm_opportunity_adjusted_frame.csv`. Utils metrics_triage.R. Data: firm_tender_map, FREQ_PARTICIP_rebuilt, firm_loss_stats, cade_fl_cobidders, cade_bec_crossmatch, cade_carteis (dates).

### Scripts created
`scripts/analysis/03_timing_case_holdout_validation.R` (timing/rolling/leakage/direct-defendant) + `04_case_holdout_dominance.R` (LOCO/leave-largest/dominance/clustered-RI). Both seed 20260603.

### Timing windows / leakage / case-holdout implemented
Information sets A–G (`timing_information_sets.md`); strict 2009-16→2017-19 (5 nested samples); rolling-origin 2014–2019 (expanding, training-only scores); leakage audit (Table F); LOCO (6 linkable cases); leave-largest / top-two; case-balanced; top-k case coverage; environment dominance (buyer/item-group/modality/year + exclusion robustness); clustered randomization inference (within buyer×item_group×year, B=1000); leave-one-defendant-group-out; direct-defendant temporal scope.

### RESULTS (honest)
- **Strict reproduces 53:** FL_train 0.767 / cont 0.750 (within always-loser pool). **Full candidate universe: ROC 0.55, PR-AUC 0.005, precision@500=0, recall@500=0.** 45/193 (23%) entrants; 148 rankable; tie-at-zero 25%.
- **Rolling-origin:** precision@500=recall@500=0 every year on full universe; worst 2015 ROC 0.497 (below chance); apparent improvement = retrospective accumulation.
- **Leave-largest-case-out COLLAPSE:** PR-AUC 0.126→0.036 (−71%), precision@500 0.130→0.040 (−69%), recall 0.342→0.233. Top case = 54.7% positives / 72.3% TP@500. Case-balanced precision 0.029 vs pooled 0.130. ROC barely moves (red herring).
- **Environment:** item-group HHI 0.188 (drop largest → PR-AUC 0.062); 96.8% Pregão; drop top-2 years → 0.048; buyer diffuse.
- **Clustered RI:** ROC p=0.001, PR-AUC p=0.015 (thin; null already 0.101), case-coverage p=0.32 (NOT sig).
- **Direct-defendant:** ROC 0.49 full & strict (scope boundary).

### Manuscript edits
- `sec04`: new §4.4 "Timing, Leakage, and Case Composition" (honest downgrade, C+D verdict) + Table I + §4 roadmap; Fig 2 ROC-only → PR-led rolling-origin; + LOCO-distribution fig. `values.tex` +19 macros.
- `sec_app03`: appended timing block D.13–D.21 (info sets, strict, rolling, leakage, LOCO+leave-largest, environment, clustered-RI+defendant-group, direct-defendant, limitations) + 9 tables + 3 figures.
- Docs: `timing_information_sets.md`.

### Commands run
`Rscript .../03_timing_case_holdout_validation.R` (~8s, exit 0); `Rscript .../04_case_holdout_dominance.R` (~16min, clustered-RI loop, exit 0); `make diagnostics`; compile paper+appendix (bidirectional xr). No failures (one dev bug in 04's table builder fixed before final run).

### Build result
**PASS.** Paper **53pp** (was 47), appendix **34pp** (was 26). 0 errors, 0 undefined refs/cites, 0 undefined control sequences, no overfull >30pt. claims critical=0. 5 new figs + Table I + 9 appendix tables + 19 macros resolve.

### Failures / blockers
- DAY_LEVEL_TIMING_UNAVAILABLE (year-level only; no conduct dates) → set F (adjudication-observable-at-time) infeasible, documented.
- 43/190 cobidders unlinked to a case (no case in map) — kept in full validation, excluded from LOCO/coverage (disclosed).
- **STRATEGIC:** Verdicts C+D → "deployable screen" claim unsupportable; reframe decision pending (see 05_BLOCKERS, 16_COMPLETION_REPORT).
