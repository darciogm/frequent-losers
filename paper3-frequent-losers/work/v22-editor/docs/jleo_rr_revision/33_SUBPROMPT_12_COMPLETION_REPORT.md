# 33 — SUBPROMPT 12 COMPLETION REPORT: Appendix B theory, exit margin, survival (JLEO R&R v22)

Date: 2026-06-03. Branch `v22`. Method: E1 survival empirical + W1 Appendix B rewrite + lead main-text touch.

| # | Item | Result |
|---|---|---|
| 1 | Appendix B before | ~1,054w; Lemma + 2 Propositions; λ_C>λ_G "maintained, not derived". |
| 2 | Appendix B after | ~1,500w prose + 2 tables + 1 figure (~5–6pp); B.1–B.6. |
| 3 | Formal results before/after | Lemma+2 Prop → Lemma + Assumption B1 + Proposition B1 + Corollary B1 (count NOT increased; redundant scope prop folded). |
| 4 | Exit margin added? | YES — B.3: ordinary firm G exits when V_G=m_G−c_G+βE[V_G']<0; losing-role C persists via role value a_C; wedge a_C−c_C>m_G−c_G (Eqs B1–B5). |
| 5 | λ_C>λ_G | **DERIVED** from differential exit + role value (no longer bare-assumed). |
| 6 | Survival dataset | Firm-year panel 16,843 always-losers × 101,366 firm-years, 2009–2019. `scripts/analysis/11_survival_hazard_frequent_losers.R`. |
| 7 | Exit definition | Baseline: last-active-year < 2019 = exit; active-2019 = right-censored. + alt (1-yr/2-yr inactivity). |
| 8 | Right-censoring | Handled in KM/Cox/hazard (not truncated); overall 16.9% censored; cobidders 45.8%. |
| 9 | Groups | FL cobidders vs FL non-cobidders vs non-FL always-losers (full-sample labels → descriptive/retrospective). |
| 10 | KM | Median duration 6 / 2 / 1 yr; log-rank χ²=1200, p≈3×10⁻²⁶¹. |
| 11 | Discrete-time hazard | cloglog FL_cobidder HR **0.155** (p≈10⁻¹⁰²); FL_noncobidder 0.368; LPM agrees. |
| 12 | Cox | HR 0.221; PH violated (curves diverge) — reported honestly. |
| 13 | Survival evidence | **SUPPORTS the exit-margin mechanism** — cobidders persist longer; all 6 sensitivity scenarios same direction (incl. exclude-largest-case HR 0.146, timing-disciplined to-date HR 0.768). |
| 14 | Framing | descriptive/retrospective; survival = platform participation NOT legal-entity; mechanism-SUPPORTING at most; identification rests on §§4–6. NOT proof of conduct. |
| 15 | Tables/figures | 2 tables (survival summary + hazard) + 1 KM figure in Appendix B; exit-def/Cox/full-sensitivity → online supplement. |
| 16 | Main-text edit | 1 sentence in §3.1 (exit margin + survival pointer). |
| 17 | Build | PASS — paper 39pp, appendix 55pp, 0 errors/undefined; claims critical=0. |

## STEP 23 — VERDICT
**VERDICT A — Theory and survival evidence are strong enough.**
> *Appendix B rationalizes the ranking through an exit margin and provides descriptive survival evidence consistent with persistent loser-side exposure: ordinary zero-win firms may exit after repeated losses, while losing roles with strategic value persist; frequent-loser cobidders remain active markedly longer than other frequent losers (median 6 vs 2 years; discrete-time exit-hazard ratio 0.16), an effect robust across exit definitions, cohorts, the largest-case exclusion, and a timing-disciplined lagged label. The audit is mechanism-supporting at most; it is not a test of cartel membership.*

## Honesty
λ_C>λ_G derived not assumed; survival descriptive/retrospective, right-censored, Cox-PH-violation reported, mechanism-supporting-not-proof. Type C/G remain model types, not observed classes. Next: Subprompt 13 (final integration).
