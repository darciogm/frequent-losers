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

---

## Subprompt 3 status update (Sections 1–3, 2026-06-02)
Front-end revision implemented + compiled (43pp, 0 errors). Referee items moved:
- **#15 (Fig 1 lost/survives → routine/costly-recovered):** ✅ implemented — 5 labels relabeled in `make_submission_figures.R` + figure regenerated; caption is an info-cost diagram; alt text added.
- **#16 (JLEO framing → organizational enforcement design):** 🟧 partial — abstract + §1 lead with evidence allocation under costly observability; §8 conclusion still pending (later prompt).
- **#17 ("cartel-adjacent" sparingly / defined):** ✅ implemented in sec 1–3 — replaced by "adjudication-anchored exposure" throughout body prose; §2.3 retitled; zero affirmative "cartel-adjacent" in sec 1–3. (Other sections still to sweep.)
- **#18 (unit-of-analysis table):** 🟧 partial — Table 1 gained a Legal-interpretation column; the standalone unit-of-analysis Table F (level/N/key) is still to build.
- **Abstract overpacked:** ✅ 187→137 words (≤150).
- **T_i tender-item vs Pregão offers:** ✅ footnote in §2.2 + clause in §3.1.
- **"not proof" repetition:** ✅ thinned; architecture carries it.
- **Table 2:** ✅ converted to a 6-col validation-threat map (pre-analysis, no results).

---

## Subprompt 4 status update (Label funnel & 193-vs-210, 2026-06-03)
Credibility repair IMPLEMENTED + compiled (paper 44pp, appendix 18pp, 0 errors). Referee items:
- **#4 (label funnel + 193 vs 210):** ✅ RECONCILED — definition difference, not a bug. 193=static narrow FL target (builder archived, B3); 341/651=transparent broad funnel; conservative reproduces to 19/208/107. Two-axis explanation (stratum AL-vs-FL + cobidder narrow-vs-broad) in new §4.1 + Table A (Table 3). `alConservativeFD` 30→19, `alConservativeCobidders` 210→208, `alConservativeFL` 108→107 (rebound to reproducible values). Drop-30 mandate honored.
- **#18 (unit of analysis unclear):** ✅ `unit_definitions_label_funnel.md` — unique-firm vs firm-case (5,121) vs firm-defendant vs defendant-tender-item (52,013) separated.
- **#19 (CADE case timing table):** ✅ Table B (`tab:case_timing_submission`, App C, anonymized Case A–L; 9/12 dated, conduct-onset disclosed missing).
- **Direct-defendant / cobidder distinction:** preserved (App C.3/C.4; defendants excluded from cobidders).
- **Downstream validation-table regeneration:** conservative COUNTS reproducible now (208/107); conservative-benchmark AUC/enrichment re-estimation under the harmonized label DEFERRED to Subprompt 4B — invariance NOT asserted.
- Verdict: RECONCILED. Paper may proceed to opportunity-adjusted validation.

---

## Subprompt 5 status update (Opportunity-adjusted validation, 2026-06-03)
The make-or-break test is IN as the central result (§4.3). **VERDICT B.**
- **#1 (mechanical T_i↔cobidder correlation):** ✅ ADDRESSED — exposure-only AUC 0.946 stated as the central caveat; within-opportunity-stratum AUC 0.771; nested score increment +0.042 over exposure (DeLong p=2.1e-6). The score retains *limited but significant* residual signal.
- **#2 (opportunity exposure not central):** ✅ promoted from App D to §4.3 "Opportunity-Adjusted Validation" (the central exercise); App D restructured D.1–D.12.
- **#7 (PR metrics missing):** ✅ PR-AUC/precision@k/recall@k/lift@k/FP/FN throughout (rare target 191/16,843); Table C + D.
- **Exposure-cell construction:** ✅ 3 granularities (coarse/medium/strict) + LOO p_{g,-i}; App D.2/D.3.
- **Common-support uncertainty:** ✅ 3 rules; retention ~46% MEDIUM / ~9% STRICT reported (no cherry-pick).
- **Case/buyer dominance (preliminary):** 🟧 flagged — largest CADE case ≈47% of TP@500 → formal leave-one-case-out is Subprompt 6.
- **Permutation (both directions, honest):** Approach B (pure-exposure binomial) PR-AUC p=1.00 (exposure out-predicts raw score); Approach C (matched-stratum label perm) p=0.023; FL14-enrichment p<0.001.
- **HONESTY ENFORCED:** combined exposure+score logit ROC-AUC ~0.98 EXPLICITLY omitted/caveated (E_i mechanically encodes the label; not score evidence) — in both §4.3 prose and Table C note.
- Claim DOWNGRADED honestly (no "survives exposure" unqualified; intro hedged). Proceed to timing/case-holdout.
---

## Subprompt 6 status update (Timing & case-holdout, 2026-06-03) — VERDICT C+D
The toughest test landed hard. Honest downgrade implemented (§4.4).
- **#5 (strict ex-ante timing):** ✅ implemented — strict 2009-16→2017-19 + rolling-origin 2014-19. Result: survives ONLY inside the always-loser incumbent pool (AUC ~0.75); on the realistic full universe ROC 0.55, **precision@500 = recall@500 = 0 every rolling year**; 23% of positives are unrankable entrants; worst year 2015 below chance. → NOT prospectively deployable.
- **#6 (leave-one-case-out):** ✅ implemented (case_cobidder_map). **Leave-largest-case-out COLLAPSES operational metrics: PR-AUC 0.126→0.036 (−71%), precision@500 −69%.** One case (trens_metros) = 55% of positives / 72% of TP@500. Case-balanced precision 0.029 vs pooled 0.130.
- **Case dominance / environment dominance:** ✅ — item-group HHI 0.188 (drop largest halves PR-AUC); 96.8% Pregão; top-2 years drive much of it.
- **Clustered RI:** ✅ — significant but THIN (PR-AUC p=0.015); case-coverage breadth NOT significant (p=0.32).
- **#7 (ROC overemphasis):** ✅ — ROC reframed as a red herring (robust ~0.93 precisely because insensitive to the case concentration the operational metrics expose); PR/precision/recall primary.
- **#12 (direct-defendant scope):** ✅ — ROC 0.49 full & strict; "not a generic direct-defendant classifier," not an escape hatch.
- **Fig 2:** ROC-only replaced by PR-led rolling-origin.
- **CLAIM DOWNGRADED:** retrospective, incumbent-pool, case-sensitive triage diagnostic — NOT prospective platform-wide screening.
- **STRATEGIC FLAG for Darcio:** the "deployable screen" framing is no longer supportable; the honest paper is now about the LIMITS/boundary conditions of award-layer screening. Decision needed before §5+.

---

## Subprompt 7 status update (Section 5 profile/monotonicity, 2026-06-03) — VERDICT B
§5 rewritten under the reframe; strengths-forward, honest.
- **#3 (weak raw cobidder target — what does it capture?):** ✅ Table J — cobidders economically distinct (Pregão 96.6% vs 66.6% SMD 0.76; buyers 24.9 vs 14.3 SMD 0.72; persistence SMD 0.84; proximity SMD 3.76/3.12 partly mechanical).
- **#10 (binary FL14 vs continuous):** ✅ RESOLVED — continuous ties/beats FL14 in every full-sample setup; 53's strict-pool flip (0.767>0.750, p=0.085 n.s.) is sample-specific; T=14 = median+1.5·IQR, administrative; no bunching (ratio 1.06). Table M + memo.
- **#13 (global zero-win too blunt):** ✅ market-specific zero-win definitions tested — global NOT dominated (alt 0.554–0.774 vs 0.939); leave-one-item-group-out stable [0.936,0.941]. Keep global.
- **Monotonicity (KEY):** cobidder prevalence rises with T_i (Spearman +0.92) but opportunity-adjusted EXCESS flat/negative (−0.93) → the rank is an EXPOSURE ranking, not collusion-intensity. Supports reframe.
- **Opportunity-adjusted profile (Table K):** item-group HHI VANISHES (SMD 0.45→0.02); breadth attenuates; proximity halves (3.76→2.25). Much of the raw difference is procurement-environment composition.
- **Ordinary-loser alternatives (Table N):** NARROWED not eliminated — cobidders wider/longer-lived (not low-capacity), low Convite/quorum (not padding), low first-year conc. (not explore-exit); but distance/geography/later-wins NOT_OBSERVED → specialization & geography not fully ruled out. CADE contact = distinguishing axis.
- **★ Negative controls (STRENGTH):** real cobidder ROC-AUC 0.939 beats matched placebo-anchor null (0.755, p<0.001) + non-CADE-winner null (0.780, p<0.001) → ranking SPECIFIC to the real defendant network, not generic high-volume co-bidding. Honest caveat: placebo PR-AUC p=0.70 (base-rate inflation; ROC is the decisive ranking metric).
- "cartel-adjacent" REMOVED (§5 retitled "Economic Content and Ordinary-Loser Alternatives"). New Appendix H. Claims critical=0.

---

## Subprompt 8 status update (Section 6A bid-layer benchmark, 2026-06-03) — VERDICT E
§6.1 made transparent + honestly bounded. Bid pipeline REPRODUCIBLE (not blocked).
- **#9 (bid-layer benchmark under-documented):** ✅ — learner = random forest (ranger 500 trees, NOT logit), 7 within-tender Imhof moments, candidate=always-losers w/ complete features, target=193 cobidders. Tables P (model audit), O (support), F (feature dictionary). Timing/bid-revision features NOT implemented (disclosed).
- **#7 (ROC overemphasis):** ✅ — PR-AUC/precision/recall lead; Table Q. all 193 positives retained (no support problem).
- **Complementarity (separately demonstrated):** Spearman(award,bid)=0.42; top-500 overlap 17%, award catches 33 net-new / bid 36; incremental Δ PR-AUC adding award to bid = pooled +0.151 → case-grouped +0.064 (p<0.001, halves). Combined = full-observability UPPER BOUND. Table R.
- **STRENGTH:** cheap award FL (0.921) ≈ costly bid benchmark (0.888) → "comparable discrimination at lower informational cost" (NOT "outperforms").
- **★ KEY CAVEAT (Verdict E):** pooled metrics use random CV folds (optimistic; positives cluster by case). Case-grouped: bid ROC 0.891→0.810, PR-AUC 0.124→0.045 (−63%); combined holds (0.936) only because label-independent award holds. Excl-label-defining-tenders: bid 0.891→0.874 (−0.017, minor contamination). Bid strict-timing BLOCKED. Table S leakage audit.
- Fig 1 AUC annotations (0.888/0.903) REMOVED → pure info-cost diagram (benchmark AUCs live in §6.1/Table Q with caveats).
- "outperforms"/"state of the art" absent; claims critical=0.
