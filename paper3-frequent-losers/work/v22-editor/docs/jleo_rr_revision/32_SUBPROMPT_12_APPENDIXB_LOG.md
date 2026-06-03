# 32 — SUBPROMPT 12 LOG: Appendix B exit margin + survival (JLEO R&R v22)
Date 2026-06-03. Branch v22.
- Read docs 00–31 + Appendix B (sec_app01, 1054w, λ_C>λ_G maintained-not-derived). Firm-year data feasible (firm_tender_map).
- E1: NEW scripts/analysis/11_survival_hazard_frequent_losers.R (seed 20260603). Firm-year panel (16,843/101,366), baseline exit (last-active<2019, right-censored 2019), KM + cloglog hazard + Cox + sensitivity. Outputs: cache/firm_year_survival_panel.csv; tables/appendix/{table_B_survival_summary, table_B_discrete_time_hazard, table_B_exit_definition_sensitivity, table_B_survival_sensitivity, table_B_cox_duration_model}; figures/appendix/fig_B_survival_curves; logs/survival_hazard.log.
- RESULT (Verdict A): FL cobidders median 6yr vs 2 vs 1; exit-share 0.54/0.73/0.85; cloglog HR 0.155 (p≈1e-102); Cox 0.221 (PH violated, reported); log-rank p≈3e-261; all 6 sensitivities same direction.
- W1: rewrote sec_app01 B.1–B.6 (exit margin Eqs B1–B5 deriving λ_C>λ_G; Assumption B1 + Proposition B1 + Corollary B1, count not increased; survival B.5 with 2 tables + KM figure; mechanism-supporting-not-proof framing). Labels preserved (lem_zero_win, prop_monotone, prop_scope).
- Lead: §3.1 one-sentence exit-margin+survival pointer.
- Commands: Rscript 11_survival_hazard (~2min, exit 0; fixed printf/merge/separation issues); compile paper+appendix; make diagnostics.
- BUILD PASS: paper 39pp, appendix 55pp, 0 errors/undefined, claims critical=0.
- Verdict A. Blockers: appendix now 55pp (Sub13 will move survival sensitivity/Cox to online supplement).
