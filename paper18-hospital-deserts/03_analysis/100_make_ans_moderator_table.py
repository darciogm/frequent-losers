#!/usr/bin/env python3
"""100_make_ans_moderator_table.py [ans-moderator branch]
Appendix table for the private-penetration moderator: penetration of exposed
catchments + suicide/admission ATT by low/high private-penetration arm.
Reads 98/99 outputs; writes 01_manuscript/tables_appendix/table_ans_private_moderator.tex.
"""
from pathlib import Path
import pandas as pd
ROOT = Path(__file__).resolve().parents[1]
PROC = ROOT / "02_data" / "processed"
desc = pd.read_csv(PROC / "ans_moderator_descriptive.csv")
es = pd.read_csv(PROC / "ans_moderator_eventstudy.csv")

def d(g): return desc[desc.group == g].iloc[0]
tr, nv = d("treated (exposed)"), d("never-treated")
def e(arm, out):
    r = es[(es.arm == arm) & (es.outcome == out)].iloc[0]
    return f"{r.att:+.2f} & [{r.ci_lo:+.2f}, {r.ci_hi:+.2f}] & {r.pretrend_p:.2f} & {int(r.n_treated)}"

L = [
 r"\begin{table}[!htbp]\centering",
 r"\caption{Private-plan penetration does not drive the result (ANS moderator)}",
 r"\label{tab:ans-private-moderator}", r"\small",
 r"\begin{tabular}{lrrrr}", r"\toprule",
 r"\multicolumn{5}{l}{\textbf{Panel A. Private-plan penetration by exposure group}} \\",
 r" & Median \% & Mean \% & \% below 10\% & \% below 20\% \\", r"\midrule",
 f"Exposed (treated) catchments & {tr.median_pct} & {tr.mean_pct} & {int(tr.share_lt10)} & {int(tr.share_lt20)} \\\\",
 f"Never-treated municipalities & {nv.median_pct} & {nv.mean_pct} & {int(nv.share_lt10)} & {int(nv.share_lt20)} \\\\",
 r"\midrule",
 r"\multicolumn{5}{l}{\textbf{Panel B. Event-study ATT by penetration arm vs.\ never-flagged controls}} \\",
 r" & ATT & 95\% CI & Pre-trend $p$ & $N$ treated \\", r"\midrule",
 r"\multicolumn{5}{l}{\emph{Suicide per 100{,}000}} \\",
 f"\\quad all treated & {e('all','suicide_per100k')} \\\\",
 f"\\quad low private penetration & {e('low_private','suicide_per100k')} \\\\",
 f"\\quad high private penetration & {e('high_private','suicide_per100k')} \\\\",
 r"\addlinespace",
 r"\multicolumn{5}{l}{\emph{Inpatient psychiatric admissions per 1{,}000}} \\",
 f"\\quad all treated & {e('all','psych_adm_per1k')} \\\\",
 f"\\quad low private penetration & {e('low_private','psych_adm_per1k')} \\\\",
 f"\\quad high private penetration & {e('high_private','psych_adm_per1k')} \\\\",
 r"\bottomrule",
 r"\multicolumn{5}{p{0.94\textwidth}}{\footnotesize Notes: Private-plan penetration is ANS"
 r" medical-plan beneficiaries over IBGE population (current snapshot, a persistent structural"
 r" characteristic of the municipality). Exposed catchments are SUS-dominant (median penetration"
 r" near $12\%$). Panel B splits treated municipalities at the median treated penetration and"
 r" re-estimates the population-weighted Sun-Abraham event study against never-flagged controls."
 r" Where penetration is low---so displaced patients cannot be absorbed by an unobserved private"
 r" sector---the admission drop persists with flat pre-trends and suicide stays a bounded null,"
 r" so the result is not an artifact of private displacement. Both arms are small ($\sim$52"
 r" treated) and imprecise.}\\",
 r"\end{tabular}", r"\end{table}", ""]
out = ROOT / "01_manuscript" / "tables_appendix" / "table_ans_private_moderator.tex"
out.write_text("\n".join(L))
print("wrote", out)
