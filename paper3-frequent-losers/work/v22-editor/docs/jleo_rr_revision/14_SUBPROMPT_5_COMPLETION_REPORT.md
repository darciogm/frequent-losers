# 14 — SUBPROMPT 5 COMPLETION REPORT: Opportunity-adjusted validation (JLEO R&R v22)

Date: 2026-06-03. Branch `v22`. Agent: mr-frequent-losers. Method: lead diagnosis + 3-agent fan-out (Phase A empirical; Phase B1 §4.3+macros; Phase B2 Appendix D) on disjoint files.

| # | Item | Result |
|---|---|---|
| 1 | **Label funnel resolved before starting?** | YES (Subprompt 4, verdict RECONCILED). Not blocked. |
| 2 | **Input datasets** | `firm_tender_map.parquet`, `FREQ_PARTICIP_rebuilt.parquet`, `cade_fl_cobidders.csv` (193), `cade_bec_crossmatch.csv` (direct defendants). Reused script 76's `firm_panel.csv` exposure axis. |
| 3 | **Opportunity-cell definitions** | THREE: COARSE item_group×year; MEDIUM +buyer/PBU; STRICT item_code×year×buyer. Modality dropped (award-layer limit; sensitivity). LOO p_{g,-i}. |
| 4 | **Observed contact O_i** | # distinct tender-items where firm i shares with ≥1 direct CADE defendant; Y_i=1[O_i>0]. |
| 5 | **Expected contact E_i** | E_i=Σ_g n_ig·p_g (and LOO); X_i=O_i−E_i; standardized Z_i. |
| 6 | **Common-support rules** | Minimal / Moderate (≥5-item cells) / Strict (overlapping FL-vs-nonFL support). Retention ~98–100% / ~46% / ~9% — all reported. |
| 7 | **Control-function designs** | S0 raw, S1 flexible-participation (separation→flagged), S2 expected-contact, S3 +breadth, S4 exposure-decile FE, S5 score-ranks-excess, S6 strict-support. |
| 8 | **Permutation designs** | B (firm-exposure binomial sim, B=2000) + C (matched-stratum label perm, B=2000); A documented as equivalent-substitute. |
| 9 | **Matched/stratified** | CEM on opportunity deciles + within-stratum FL-vs-non differences. |
| 10 | **Main results summary** | Exposure-only AUC **0.946** (reproduces the label better than the raw score). Within-opportunity-stratum AUC **0.771**. Nested score increment **+0.042** over exposure (DeLong **p=2.1×10⁻⁶**). Score ranks positive excess contact AUC 0.764. Matched ΔP(FL14 vs non) +0.083; CEM-matched 0.863. Permutation: **B p=1.00** (pure exposure out-predicts on PR-AUC), **C p=0.023** (score ranks within matched exposure), FL14-enrichment p<0.001. |
| 11 | **Does the raw signal attenuate?** | YES, materially. Raw 0.939 → within-stratum 0.771; on PR-AUC a pure-exposure model matches/beats the raw score (B p=1.00). A large share of the headline is opportunity exposure. |
| 12 | **Non-trivial residual remains?** | YES — within-stratum AUC 0.77 (≫0.5); +0.042 over exposure (p=2e-6); matched-label permutation p=0.023; FL14-enrichment p<0.001. Limited but statistically significant. |
| 13 | **Claims upgraded / preserved / downgraded?** | **DOWNGRADED honestly.** No "survives opportunity exposure" unqualified claim; intro hedged; the mechanically-inflated 0.98 combined AUC explicitly omitted/caveated as not score evidence. |
| 14 | **Tables created** | Main: Table C (opportunity-adjusted validation), Table D (permutation). Appendix: cell construction, observed-vs-expected bins, matched, control-function-full. |
| 15 | **Figures created** | Main: observed-vs-expected contact bins, permutation PR-AUC. Appendix: excess contact by score bins, permutation precision@k. All with JLEO alt text. |
| 16 | **Appendix D changes** | Restructured D.1–D.12 (volume placebo, cell construction, E_i+LOO, control-function +0.98 caveat, permutation both directions, matched, common support, sensitivity, limitations + legacy audits). |
| 17 | **Section 4.3 changes** | Retitled "Opportunity-Adjusted Validation," promoted to the central exercise; threat → O_i/E_i definitions → main result (PR-AUC/within-stratum/nested-increment led, exposure-only benchmark stated) → Verdict-B interpretation → legal boundary → transition to timing/case-holdout. |
| 18 | **Build result** | **PASS** — paper 47pp, appendix 26pp; 0 errors, 0 undefined refs, 0 undefined control sequences, no severe overfull; claims scanner critical=0. |
| 19 | **Remaining blockers** | Top-case ≈47% TP@500 (→ Subprompt 6 LOCO); conservative-AUC re-estimation under harmonized label (carried); B3 absent 193 builder; App D literals not yet macro-bound (non-blocking). |
| 20 | **Proceed to timing/case-holdout?** | **YES.** |

## STEP 22 — DECISION RULE VERDICT

**VERDICT B — PROCEED, BUT DOWNGRADE.**

> *A meaningful share of the raw ranking performance reflects opportunity exposure: pure opportunity exposure reproduces the adjudication-anchored cobidder label at least as well as the raw award-layer score (exposure-only AUC 0.946; on PR-AUC a pure-exposure model matches or beats the raw score). Conditional on opportunity, however, the score retains limited but statistically significant residual value for prioritizing bid-layer follow-up (within-opportunity-stratum AUC 0.77; +0.04 over an exposure-only model, DeLong p<0.001; matched-stratum permutation p=0.023; FL14-enrichment p<0.001).*

NOT Verdict A (would overclaim against the 0.946 exposure benchmark and the B-permutation p=1.00). NOT Verdict C (the residual signal does not disappear; it is significant on three independent tests). The manuscript claim is downgraded to "limited residual triage value," consistent with the locked honesty ledger ("sell direction and significance, not magnitude").

## Honesty ledger respected
No invented results. Attenuation not hidden (exposure-only 0.946; B-permutation p=1.00 both reported). The mechanically-inflated 0.98 combined AUC explicitly excluded from evidence. Cobidders never called members; no proof/detector/causal/damages. Case dominance flagged, not buried.

## Recommended next
**Subprompt 6 — Section 4C: Timing, Leakage, Rolling Origin, Leave-One-Case-Out, and Case Dominance** (CP-3). Inputs ready: script 53 (frozen-train binary 0.767 > cont 0.750), script 77 (timing concentration FAIL — observational equivalence, disclose), `case_cobidder_map.csv` (LOCO), and the ≈47% top-case TP@500 flag from this subprompt.
