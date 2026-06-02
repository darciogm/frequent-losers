# 02 — REFEREE RESPONSE MATRIX (internal, JLEO R&R v22)

Status legend: ⬜ not started · 🟧 in progress · ✅ implemented · ⛔ blocked.
"Code/data" cites the script or file that must change or supply evidence. CP-x links to `01_REVISION_PLAN.md`.

| # | Referee concern | Sev | Manuscript loc | Code/data loc | Required empirical output | Required manuscript edit | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| 1 | Mechanical correlation between Tᵢ (participation) and cobidder label — high-volume zero-win firms mechanically appear near defendants | **critical** | sec04 §4.2; abstract | `76_exposure_adjusted_audit.R`; `firm_tender_map` | within-opportunity AUC (0.7715) + increment over exposure-only (+0.0415, DeLong p=2.08e-06) | New §4.2: lead with within-stratum number; state exposure-only alone = 0.946 | 🟧 | Script run (CP-2). Result modest by design — frame as "+0.04 beyond exposure," not 0.92 |
| 2 | Opportunity-set exposure not yet central — buried in App D | **critical** | sec04; sec_app03 | `76`; add buyer/item-group strata | Table B; observed-vs-expected by participation bin figure | Promote App D.2 → §4.2; demote appendix to support | 🟧 | CP-2 |
| 3 | Weakness of raw cobidder target (193) — what does it actually capture? | high | sec04 §4.1; sec05 | `cade_fl_cobidders.csv`; `60_theory_validation_bridge.R` | profile of cobidders vs 4 reference pops | §5 economic-content para; §4.1 target definition | ⬜ | 193 are FL-only (all is_FL=True) — disclose |
| 4 | Label funnel + 193 vs 210 reconciliation | **critical** | sec04 §4.1; sec_app02 | `79_label_funnel.R` ✅; `99_make_paper_values.R:1320-1322` | `output/label_funnel/{funnel,case_cobidder_map,case_timing}.csv`; Table A | Table A funnel; resolve def inconsistency; drop 30→19 | 🟧 | **RUN 2026-06-02:** cons 208≈210/107≈108 reproduce; main 193→341 does NOT (inconsistent defs); builder absent (B3). U2 decision needed before §4 |
| 5 | Need strict ex-ante / timing validation, not pooled AUC | **critical** | sec04 §4.3; sec06 §6.4 | `53` (run), `77` (run), `17`,`27`,`64` | Table C; rolling-origin fig | §4.3 timing; report frozen-train AUC 0.767/0.750 | 🟧 | CP-3. Honest: timing concentration test FAILS (Q16/Q18) |
| 6 | Leave-one-case-out / case-dominance checks | high | sec04 §4.3; sec_app03 | NEW `80_leave_one_case_out.R` | LOCO AUC distribution; largest-case-out | §4.3 paragraph + appendix table/fig | ⛔ | Needs CP-1 case→cobidder linkage. Q14/Q16 |
| 7 | ROC-AUC overemphasis vs PR/lift/precision/recall | high | sec06 §6.3; sec_app05 | `42`,`43`,`56` (56 NOT run) | PR-AUC, precision@k, recall@k, lift@k, FP/FN | Replace ROC headline with PR table | 🟧 | CP-4. `output/regulatory_frontier/` empty |
| 8 | Cost-recall frontier missing/underdeveloped | high | sec06 §6.4 | `56_regulatory_cost_frontier.R`; `63`,`64` | Table D; `fig_regulatory_frontier.pdf` (missing) | Frontier over K1 × cost denominator | ⛔ | RUN script 56; extend 63 grid. CP-4 |
| 9 | Bid-layer benchmark under-documented | high | sec06 §6.1-6.2; sec_app06 | `31`,`49`,`26` | Table E (features/learner/CV/missingness/holdout) | Benchmark-audit subsection | ⬜ | CP-5 |
| 10 | Binary flag sometimes outperforms continuous score | medium | sec05; sec04 §4.3 | `53` (run), `34`,`22` | strict-pool flip: binary 0.767 > cont 0.750 | Disclose flip honestly; FL = operationalization | 🟧 | CP-3. DeLong on strict pool in `strict_pool_delong.csv` |
| 11 | Price sign reversal / mechanism overclaim ("theater") | **critical** | sec07 (all) | `78` (run), `59`,`61`,`62` | l_gen=−0.137 vs l_fl≈ns → theater NOT identified | Reframe price as scope; drop theater mechanism | 🟧 | CP-6. Honest downgrade |
| 12 | Direct-defendant null interpretation too convenient | high | sec04 §4.3 | `33_auc_direct_cade.R` | AUC 0.491 vs direct defendants | Front-page as structural scope limit, not excuse | ⬜ | Already in values (`\valAUCdirectCADE=0.491`) |
| 13 | Global zero-win definition too blunt | medium | sec03; sec_app02 | `00_build_bidlevel.py:107`; `24_market_persistence.R` | firm- vs market-level persistence | Acknowledge; offer market-conditional variant | ⬜ | `>` vs `≥` cut also to verify (Q4) |
| 14 | Theory assumes λ_C > λ_G without exit margin | high | sec_app01 (B) | NEW `81_survival_hazard.R` | KM/hazard of exit by AL & cobidder status | Add survival subsection to App B | ⛔ | Exit censored at 2019; bounding argument. CP-7. Q18 |
| 15 | Fig 1 "lost/survives" language → routine/costly-recovered | low | sec02:128 fig | `58_fig_data_coarsening.R`; `make_submission_figures.R` | regen figure | Caption + figure labels | ⬜ | Figure values hardcoded in make script |
| 16 | JLEO framing → organizational enforcement design | high | sec01; sec08 | none | — | Contribution para + conclusion: agency org, sequencing, triage, governance | ⬜ | CP-8. Desk-screen gate |
| 17 | Terminology: "cartel-adjacent" used sparingly / defined | medium | throughout | none | — | Replace with "adjudication-anchored exposure" in technical text; define cartel-adjacent once, legally bounded | ⬜ | CP-8 |
| 18 | Need unit-of-analysis table | medium | sec02 | `01_clean.R`; data dictionary | level/N table | Table F | ⬜ | Levels mapped in 00_REPO_AUDIT §C |
| 19 | Need CADE case timing table | medium | sec02 §2.3; sec_app02 | `cade_carteis_licitacoes_2009_2019.csv` | case × judgment-date table (9/12 dated) | Table G | 🟧 | Only judgment dates exist; 3 NaT. Q15 |
| 20 | Replication / JLEO compliance audit | high | endmatter; README | NEW regen scripts; compliance checklist | manifest + ReadMe | JLEO compliance audit doc | ⬜ | Cobidder/crossmatch provenance not reproducible (Q1-Q6). CP-8/§5 |

## Cross-cutting honesty ledger (do not let optimism overwrite these)
- **#1/#2:** the exposure-adjusted contribution is **+0.04**, with exposure-only already at 0.946. Sell the *direction and significance*, not magnitude.
- **#5/#14 (timing):** script 77 verdict is FAIL on concentration (cobidders *more* spread, d=−0.66). Disclose observational equivalence between deployment and sincere persistence. Do not claim prospective proof.
- **#11 (price):** script 78 says compression is genuine-bidder entry, not FL theater. The cover-bidding mechanism is **not identified** from these data.
- **#4 (funnel):** if 210/108/30 cannot be regenerated, they must be **retired and replaced** with data-derived counts — not silently kept.
