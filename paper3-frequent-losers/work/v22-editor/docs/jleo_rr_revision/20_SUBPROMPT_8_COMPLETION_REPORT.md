# 20 — SUBPROMPT 8 COMPLETION REPORT: Section 6A bid-layer benchmark audit & complementarity (JLEO R&R v22)

Date: 2026-06-03. Branch `v22`. Method: lead diagnosis + 2 parallel empirical agents (E1 inventory/dictionary/support/reproduce, E2 model-audit/validation/complementarity/leakage) + 2 parallel writers (W1 §6.1, W2 Appendix I) + lead Fig-1 reconciliation.

| # | Item | Result |
|---|---|---|
| 1 | **Prior §4/§5 deps complete?** | YES (Sub4–7). §6A under the reframe. |
| 2 | **Bid-layer data** | `v3/data/processed/bid_level_with_prices.parquet` (245 MB; firm×tender-item bid_price). |
| 3 | **Bid-layer scripts** | `31_imhof_full_pipeline.R` (main), `49_imhof_incremental_value.R`, `26_auc_by_subsample.R`. All located. |
| 4 | **Current numbers reproduced?** | YES — N=11,676 exact; N=16,779 within CV jitter (no per-fold seed). FL 0.921, imhof_full 0.888, combined 0.962. |
| 5 | **Feature dictionary** | Table F — 7 within-tender Imhof moments (CV, CV-sd, skew, kurt, spread, min-max-log, second-low) + formulas. Timing/bid-revision/late-bid features **NOT implemented** (no timestamps). |
| 6 | **Missingness/support** | Table O — pool N=16,779 (script 31) / 11,676 (script 49, +cv_sd 30.7% missing). **All 193 positives retained in both pools (zero positive loss).** No support problem. |
| 7 | **Model architecture** | **Random forest** (ranger, 500 trees, probability), NOT logit; no tuning; no standardization; 5-fold CV. Documented in `bid_benchmark_model_audit.md` (20 Qs) + Table P. |
| 8 | **CV/holdout designs** | A pooled-random (diagnostic upper bound); E case-grouped/LOCO; F exclude-label-defining-tenders; G environment holdout. Fold audit logged. |
| 9 | **Leakage audit** | Table S — award clean; bid/combined full = diagnostic_only; bid/combined strict-timing = **blocked**; LOCO = case-holdout robustness. Random folds optimistic (positives cluster by case). |
| 10 | **Feature-target contamination** | Design F: excluding label-defining tenders lowers bid ROC only 0.891→0.874 (**−0.017**) — minor; fragility is case clustering, not feature-target overlap. |
| 11 | **Main performance** | Pooled (Table Q): award FL14 0.921 (PR 0.085), bid RF 0.888 (PR 0.124), combined 0.962 (PR 0.275). **Case-grouped:** bid 0.810 (PR 0.045, −63%), combined 0.936 (PR 0.109), award unchanged 0.938. |
| 12 | **Complementarity** | Spearman(award,bid)=**0.42**; top-500 overlap 17%, award catches 33 net-new / bid 36; Δ PR-AUC adding award to bid = pooled **+0.151** → case-grouped **+0.064** (DeLong p<0.001, halves; surviving increment is award rescuing bid). Combined = full-observability **upper bound**. Table R. |
| 13 | **Calibration/error** | Table F calibration (Brier, decile) + error analysis; FPs are non-labeled firms under a limited target, not "bad firms." |
| 14 | **Figure 1 revision** | YES — removed the side-by-side AUC annotations (0.888/0.903) → pure information-cost diagram (consistent with caption + reframe); benchmark AUCs live in §6.1/Table Q with caveats. Regenerated. |
| 15 | **Tables created** | Main: O, P, Q, R, S. Appendix: F-dictionary, F-missingness, F-calibration. |
| 16 | **Figures created** | Main: award-bid PR curves, rank overlap. Appendix: score scatter, calibration. All alt-texted. |
| 17 | **§6.1 edits** | Retitled "Bid-Layer Forensics as a Full-Observability Benchmark"; 8-step structure; PR-led; "comparable at lower cost" + case-grouped caveat + complementarity bounded; "outperforms/state-of-the-art" absent. |
| 18 | **Appendix edits** | NEW Appendix I (`sec_app09_bid_benchmark`, I.1–I.10) + `\input` in master (adjustbox-outermost). |
| 19 | **Claims softened/removed** | learner=RF (was implied canonical Imhof); "comparable" not "outperforms"; combined = upper bound; pooled = diagnostic. critical=0. |
| 20 | **Build result** | **PASS** — paper 64pp, appendix 55pp; 0 errors, 0 undefined, 0 overfull >40pt. |
| 21 | **Remaining blockers** | Bid strict-timing blocked (documented); script-31 per-fold seed recommendation (no number change); appendix length. |
| 22 | **Proceed to §6B cost-recall frontier?** | YES. |

## STEP 24 — DECISION RULE VERDICT

**VERDICT E — LEAKAGE-SENSITIVE FULL-OBSERVABILITY DIAGNOSTIC** (with elements of B: complementarity real but bounded).

> *The bid-layer benchmark is reproducible and fully documented (Imhof–Wallimann within-tender moments in a random forest), and all adjudicated positives are retained, so the comparison is not support-limited. On the pooled full-observability diagnostic the cheap award-layer flag is comparable to the costly bid benchmark (ROC 0.921 vs 0.888) at far lower informational cost, and the two layers carry partially non-overlapping ranking information (Spearman 0.42; each captures positives the other misses). But the pooled metrics use random cross-validation folds that are optimistic because positives cluster by CADE case: under case-grouped folds the bid layer falls hardest (PR-AUC 0.124→0.045) and the combined model survives only because the label-independent award score holds, with the award-over-bid increment halving (+0.151→+0.064). The benchmark is therefore best read as a forensic-stage, full-observability diagnostic and case-holdout robustness check — not a real-time first-stage screen, and not proof of conduct. The combined model is a full-observability upper bound.*

NOT Verdict A (random-CV optimism + case clustering bound the complementarity). NOT D (reproducible). The combined-model and pooled-AUC framing is explicitly an upper bound; strict bid-timing is disclosed as blocked.

## Honesty ledger respected
No invented features/numbers. Learner corrected to random forest. Support loss = zero positives (disclosed). Random-CV optimism + case-grouped collapse reported, not hidden. Feature-target contamination quantified (−0.017). "Comparable at lower cost," never "outperforms/state-of-the-art." Combined = upper bound. Cobidders = adjudication-anchored exposure, not membership.

## Recommended next
**Subprompt 9 — Section 6B: Cost-Recall Frontier and Sequential Gatekeeping.** RUN `scripts/56_regulatory_cost_frontier.R` (`output/regulatory_frontier/` currently EMPTY); extend `63`/`64` to a K1 × cost-denominator grid; replace the "83%" headline with a cost-recall frontier; PR-AUC/precision@k/recall@k/FP/FN/cost-per-TP. Then §7 price downgrade (script 78), Appendix B survival/exit, JLEO compliance.
