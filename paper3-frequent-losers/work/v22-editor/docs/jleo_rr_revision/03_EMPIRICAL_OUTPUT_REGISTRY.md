# 03 — EMPIRICAL OUTPUT REGISTRY (JLEO R&R v22)

Maps current outputs → revised outputs needed. Paths relative to `paper3-frequent-losers/`.
Status: ✅ exists+run · 🟧 exists, needs extend/rebind · ⬜ to create · ⛔ blocked.
**Rule:** never hand-edit generated tables/figures; regenerate from script and `\input` or macro-bind.

---

## A. Main-text TABLES

| Output | Current path | Revised path | Manuscript dest | Data level | Main vars needed | Generating script | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| **Table A — Label funnel & sample reconciliation** | — (none) | `output/label_funnel/funnel.csv` → inline tab | sec04 §4.1 (`tab:label_funnel`) | case/firm | case_id, defendant CNPJ, cobidder CNPJ, is_FL, always_loser, data_julgamento | NEW `79_label_funnel.R` | ⛔ | Must reconcile 12→47→193→(210/108/30). 210/108/30 unsourced |
| **Table B — Opportunity-adjusted validation** | `output/exposure_adjusted_audit/auc_summary.csv` | same (+PR cols) | sec04 §4.2 (`tab:exposure_adjusted`) | firm (always-loser) | cobidder, fl14, log_tc, n_opp_items, opp_decile | `76_exposure_adjusted_audit.R` | 🟧 | RUN. within-AUC 0.7715; incr +0.0415; exp-only 0.946. Add PR-AUC |
| **Table C — Timing & leave-one-case-out** | `output/strict_train_threshold/strict_train_threshold.csv`; `output/reverse_causality_timing/*` | + `output/loco/` | sec04 §4.3 (`tab:timing_loco`) | firm / firm-year / case | frozen-train threshold, AUC, year_hhi, Δshare, LOCO-AUC | `53`,`77` (run) + NEW `80_leave_one_case_out.R` | ⛔ | 53/77 run; LOCO blocked on CP-1. Timing verdict = FAIL (disclose) |
| **Table D — Cost-recall frontier** | `output/architecture_gatekeeper/precision_at_k.csv` (53/63 trees) | `output/regulatory_frontier/*` (EMPTY) | sec06 §6.4 (`tab:gatekeeper_submission` replace) | firm/cell | K1, cost denominator, recall, precision, FP, FN | `56_regulatory_cost_frontier.R` (NOT RUN); `63`,`64` | ⛔ | RUN 56; extend 63 to K1×cost grid. Replaces hard-typed sec06 cells |
| **Table E — Bid-layer benchmark audit** | `output/imhof_incremental/`; `tab:imhof_cost_submission` | + missingness cols | sec06 §6.1-6.2 (`tab:imhof_cost_submission`) | bid/item | Imhof features, learner, CV scheme, missingness, holdout AUC | `31`,`49`,`26` | 🟧 | Document features/CV/leakage controls |
| **Table F — Unit-of-analysis table** | — | inline | sec02 (`tab:unit_of_analysis`) | meta | level, file, N, key | hand-built from `00_REPO_AUDIT §C` + `01_clean.R` | ⬜ | Pure documentation |
| **Table G — CADE case timing** | — | `output/label_funnel/case_timing.csv` | sec02 §2.3 (`tab:cade_case_timing`) | case | numero_processo, data_julgamento, setor, n_defendants | NEW `79` (or split) | 🟧 | Judgment dates only; 9/12 dated, 3 NaT — disclose |

Existing main-text tables to KEEP/revise (already inline, see manuscript map): `tab:testable_implications_submission`, `tab:populations_submission`, `tab:three_classifier_submission`, `tab:scope_matrix_submission`, `tab:validation_benchmarks_submission`, `tab:cobidder_signature_submission`, `tab:price_imprint_submission`, `tab:sign_reversal_decomposition_submission`, `tab:price_scope_submission`.

## B. APPENDIX tables

| Output | Current path | Manuscript dest | Level | Script | Status | Notes |
|---|---|---|---|---|---|---|
| Participation-bin monotonicity | `output/auc_subsample.csv`; `threshold_table_q3iqr.csv` | App D | firm | `26`,`54` | 🟧 | Add observed-vs-expected by bin |
| Exposure-cell construction | `output/exposure_adjusted_audit/firm_panel.csv` | App C/D | firm | `76` | ✅ | Document cell = PBU×year×item-group |
| Exposure-adjusted permutation | `output/sham_auc_distribution.csv` | App D.1 | firm | `25_sham_fl_permutation.R` | ✅ | seed 20260430 |
| Strict-timing robustness | `output/strict_train_threshold/*` | App D | firm/item | `53` | ✅ | binary>cont flip |
| Leave-largest-case-out | `output/loco/` | App D | case | NEW `80` | ⛔ | CP-1 dep |
| Price scope | `tab:price_scope_submission` (inline) | App E | item/segment | `59`,`51`,`52` | 🟧 | theater-not-identified |
| Survival / hazard | `output/survival/` | App B | firm-year | NEW `81_survival_hazard.R` | ⛔ | exit censored 2019 |
| Bid-feature missingness | `output/imhof_incremental/` | App G | bid | `49` | ⬜ | new missingness table |
| Gatekeeping algorithm params | `output/architecture_gatekeeper/*` | App G | firm | `63` | 🟧 | K1, K2, cost params |
| Year-by-year holdout AUC | `output/auc_summary.csv` (17); app03 inline | App D.4 | firm | `17_temporal_holdout_roc.R` | 🟧 | **hard-typed in app03:223-228 — macro-bind** |
| Leakage audit | `output/leakage_audit_d3.csv` | App D.3 | firm/item | `40` | ✅ | seed 20260430 |

## C. FIGURES

| Output | Current path | Manuscript dest | Script | Status | Notes |
|---|---|---|---|---|---|
| Observed-vs-expected defendant contact by participation bin | — | sec04 §4.2 | NEW (from `76` firm_panel) | ⬜ | core exposure visual |
| PR / lift curves | `output/figures/fig_pr_curve.pdf` | sec06 §6.3 | `42` | 🟧 | replace ROC headline |
| Rolling-origin validation | `output/figures/fig_temporal_holdout_roc.pdf` (in submission) | sec04 (already `\includegraphics`) | `17`/`make_submission_figures.R` | ✅ | values hardcoded in make script |
| Leave-one-case-out distribution | — | sec04 §4.3 | NEW `80` | ⛔ | CP-1 dep |
| Cost-recall frontier | `fig_regulatory_frontier.pdf` | sec06 §6.4 | `56` | ⛔ | **MISSING — script 56 not run** |
| Cobidder prevalence by participation-count bin | `output/figures/fig_threshold_heatmap_2d.pdf` (rel) | App C/D | `18`,`26` | 🟧 | reuse/extend |
| Survival / Kaplan-Meier | — | App B | NEW `81` | ⛔ | feasibility partial |
| Price scope segment | `output/figures/fig_segment_betas.pdf` | App E | `61_segment` | ✅ | exists |
| Data-coarsening diagram (Fig 1) | `output/figures/fig_data_coarsening.pdf` (in submission) | sec02 (already `\includegraphics`) | `58`/`make_submission_figures.R` | ✅ | relabel "lost/survives"→"routine/costly-recovered" (#15) |

## Run-artifact snapshot (verified 2026-06-02, from May 30 runs)
- **76** auc_summary.csv: unconditional fl14 0.9236 / log_tc 0.9386; exposure-only 0.9462; exposed-only fl14 0.8417 / log_tc 0.8635; **within-opp-stratum log_tc 0.7715 / fl14 0.7709**; logit exposure-only 0.8467 → +score 0.8882 (**+0.0415, DeLong Z=−4.745 p=2.08e-06**); CEM-opp-matched log_tc 0.8628. n=16,843, npos=191.
- **77** concentration: cobidders year_hhi 0.553 vs ctrl 0.727 (**d=−0.661 p=5e-19**), n_active_years 3.62 vs 2.40 (d=+0.674), span 4.41 vs 2.95, peak_share 0.647 vs 0.791. Event study mean_part jumps tau=−1 7.30 → tau=0 25.27. **Verdict: sincere persistence NOT ruled out.**
- **78** bidder_decomp: winner_vs_ref~losers = −0.0479; +genuine+FL → l_gen=−0.137 (se .003), l_fl=+0.0258 (se .020, ~ns), losers=−0.0346. **Theater not identified.**
- **53** strict_train: firm AUC binary **0.767** [0.734,0.800] > continuous **0.750** [0.706,0.795]; threshold frozen on 09-16 = **7** (vs full-sample 13.5); item 2017-19 cont AUC 0.770. npos=193.
- **EMPTY:** `output/regulatory_frontier/` (script 56). **MISSING:** `fig_regulatory_frontier.pdf`.

## Macro-binding discipline (for `values.tex`, hand-edit with `% src:`)
New macros to bind: `\valExpWithinAUC`(0.7715), `\valExpExpOnlyAUC`(0.946), `\valExpIncrement`(0.0415), `\valExpDeLongP`(2.08e-06), `\valExpExposedFLAUC`(0.842), `\valTimingYearHHIcob`(0.553), `\valTimingYearHHIctrl`(0.727), `\valTimingD`(−0.66), `\valStrictBinAUC`(0.767), `\valStrictContAUC`(0.750), `\valStrictThreshTrain`(7), `\valBidderDecompGen`(−0.137), `\valBidderDecompFL`(0.026). Retire/replace: `\valConservativeCobidders`(210), `\valConservativeFD`(30), conservative-FL(108) pending CP-1.
