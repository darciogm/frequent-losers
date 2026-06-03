# 21 — LENGTH & COMPRESSION AUDIT (JLEO R&R v22)

Date: 2026-06-03. Goal: 64pp main → 30–38pp; ≤6 main tables; ≤3 main figures; preserve core defenses.

## Step 1 — Current length (main 64pp / appendix 55pp)
| Section | File | Prose words | Tables | Figures |
|---|---|---|---|---|
| §1 Intro | sec01 | 1,286 | 0 | 0 |
| §2 Setting/layers | sec02 | 1,716 | 1 | 1 |
| §3 Award screen | sec03 | 1,381 | 1 | 0 |
| §4 Validation | sec04 | 5,018 | 7 | 4 |
| §5 Profile | sec05 | 2,731 | 5 | 2 |
| §6 Forensics/bid | sec06 | 3,472 | 6 | 1 |
| §7 Price/scope | sec07 | 2,235 | 3 | 0 |
| §8 Conclusion | sec08 | 522 | 0 | 0 |
| **Total** | | **~18,360** | **23** | **8** |

Appendix: A–I (sec_app00–06, app08 profile=H, app09 bid=I), 55pp.

## Step 2/3/4 — Classification (KEEP 6 tables + 2 figures in main)

### KEEP in main
| Item | Loc | Why kept |
|---|---|---|
| Fig `coarsening` | §2 | (#1) Information layers |
| Tab `populations` | §2 | (#1) Data objects & legal-economic roles |
| Tab `label_funnel` | §4 | (#2) Label funnel & sample reconciliation |
| Tab `opportunity_adjusted_validation` | §4 | (#3) Opportunity-adjusted validation (fatal threat) |
| Fig `observed_vs_expected_contact` | §4 | (#2) Opportunity-adjusted evidence |
| Tab `timing_case_holdout` | §4 | (#4) Timing & case-holdout |
| Tab `bid_layer_performance` | §6 | (#5) Bid-layer benchmark & complementarity |
| Tab `gatekeeper_submission` | §6 | (#6) Cost/gatekeeping (proxy for cost-recall frontier until Sub9) |

(3rd figure slot reserved for the cost-recall frontier — Subprompt 9.)

### DEMOTE to appendix (delete redundant main float, repoint in-section \ref to existing appendix twin; all refs are in-section)
| Item | From | Appendix home |
|---|---|---|
| Tab `testable_implications` | §3 | App C/D (fold to prose pointer) |
| Tab `three_classifier`, `opportunity_permutation`, `scope_matrix`, `validation_benchmarks` | §4 | App D (sec_app03) |
| Fig `opportunity_permutation`, `rolling_origin_pr_auc`, `leave_one_case_out` | §4 | App D |
| Tab `economic_profile`, `opportunity_adjusted_profile`, `monotonicity_bins`, `binary_vs_continuous`, `ordinary_loser_alternatives` | §5 | App H (sec_app08) |
| Fig `profile_smd`, `mono_bins` | §5 | App H |
| Tab `bid_feature_support`, `bid_model_audit`, `award_bid_complementarity`, `bid_leakage_audit` | §6 | App I (sec_app09) |
| Fig `award_bid_benchmark` | §6 | App I |
| Tab `price_imprint`, `sign_reversal_decomposition`, `price_scope` | §7 | App E (sec_app04) |

**Rule applied:** a float stays in main only if it defines the sample, attacks the fatal identification threat (opportunity exposure / timing-case-holdout), shows the operational cost-recall result, or establishes the legal-economic boundary. App D/H/I already hold the technical detail (built in Sub 6/7/8), so demoted main floats are redundant → delete + cite appendix.

## Prose-compression targets
§1 → 4–5pp (cut "not proof" repetition, lit review, robustness roadmap, award/bid re-explanation). §2+§3 → 7–9pp (keep institutional sequence/layers/CADE/score; move formulas beyond s_i=log(1+T_i) to appendix). §4 → 9–11pp (4 subsections; one table + summarize rest w/ App D refs). §5 → 2–3pp (economic content only; rest → App H). §6 → 6–8pp (bid benchmark + audit + cost/gatekeeper; detail → App I). §7 → 1.5–2pp (price = scope only; tables → App E). §8 keep.

## Execution: 6 parallel agents (disjoint section files) — each compresses prose + deletes its demoted floats + repoints in-section refs to the appendix. Lead: TODO strip, claims scan, compile, reports.
