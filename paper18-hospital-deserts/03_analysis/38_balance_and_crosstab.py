"""
38_balance_and_crosstab.py

Path2 #3 (Major #1+#2 do parecer): produce (a) balance check em
pre-treatment observables entre E1-treated e never-treated, e (b)
cross-tabulação hospital_type × closure_motive da F5 sample.

Output:
- 04_logs/38_balance.json
- 01_manuscript/tables/tab_balance.tex
- 01_manuscript/tables/tab_crosstab_motive.tex
"""

from __future__ import annotations

import json
import logging
import sys
from pathlib import Path

import numpy as np
import polars as pl
import scipy.stats as stats

ROOT = Path(__file__).resolve().parents[1]
INTER = ROOT / "02_data" / "intermediate"
LOG = ROOT / "04_logs"
TAB = ROOT / "01_manuscript" / "tables"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "38_balance_crosstab.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("balance")

PANEL = INTER / "staggered_panel_F5_main.parquet"
CLO = INTER / "hospital_closures_exogenous.parquet"
CLAS = INTER / "closures_classified_v2.parquet"


def main():
    log.info("==== balance + crosstab ====")

    panel = pl.read_parquet(PANEL)
    # pre-treatment averages per municipality (anos 2010-2014)
    # janela balance: 2015-2017 (intersecção pop_2015+ × pib × pre-pandemic × largest cohort
    # pre-period). Treated munis pelo gname>=2018 já têm essa janela como pre-period;
    # cohorts mais cedos (2012-2017) terão alguns anos de pós, mas usamos a média no
    # subset comum para balance check, não como contraste causal.
    pre = panel.filter((pl.col("year") >= 2015) & (pl.col("year") <= 2017)).group_by("muni_id").agg([
        pl.col("pop").mean().alias("pop_mean_pre"),
        pl.col("pib_corr").mean().alias("pib_pre"),
        pl.col("travel_burden_km").mean().alias("travel_pre"),
        pl.col("icsap_per1k").mean().alias("icsap_pre"),
        pl.col("share_outflow").mean().alias("share_outflow_pre"),
        pl.col("g_emb").max().alias("g_emb"),
        pl.col("uf").first().alias("uf"),
        pl.col("codmun_6").first().alias("codmun_6"),
    ])
    pre = pre.with_columns([
        pl.col("pop_mean_pre").log().alias("log_pop"),
        pl.col("pib_pre").log().alias("log_pib"),
        (pl.col("g_emb") > 0).alias("treated"),
    ])

    treated = pre.filter(pl.col("treated"))
    control = pre.filter(~pl.col("treated"))
    log.info("n_treated=%d  n_control=%d", len(treated), len(control))

    rows = []
    cov_labels = {
        "log_pop": "log(population)",
        "log_pib": "log(municipal GDP)",
        "travel_pre": "travel burden 2015-17 (km)",
        "icsap_pre": "ICSAP rate 2015-17 (per 1k)",
        "share_outflow_pre": "share of outflow admissions 2015-17",
    }
    for col, label in cov_labels.items():
        t = treated[col].drop_nulls().to_numpy()
        c = control[col].drop_nulls().to_numpy()
        t = t[np.isfinite(t)]; c = c[np.isfinite(c)]
        m_t = float(np.mean(t)); m_c = float(np.mean(c))
        sd_t = float(np.std(t)); sd_c = float(np.std(c))
        # Welch's t-test
        tstat, pval = stats.ttest_ind(t, c, equal_var=False)
        # Std diff: (m_t - m_c) / sqrt((sd_t^2 + sd_c^2)/2)
        std_diff = (m_t - m_c) / max(np.sqrt((sd_t**2 + sd_c**2) / 2), 1e-9)
        rows.append({
            "label": label, "covariate": col,
            "mean_treated": m_t, "sd_treated": sd_t, "n_treated": len(t),
            "mean_control": m_c, "sd_control": sd_c, "n_control": len(c),
            "diff": m_t - m_c, "std_diff": std_diff,
            "pval_welch": float(pval),
        })
        log.info("%30s  T=%9.2f (%6.2f)  C=%9.2f (%6.2f)  Δ=%+8.2f  std_diff=%+0.3f  p=%.3f",
                 label, m_t, sd_t, m_c, sd_c, m_t - m_c, std_diff, pval)

    (LOG / "38_balance.json").write_text(json.dumps(rows, indent=2))

    # ---- LaTeX balance table ----
    tab = [
        "\\begin{table}[h!]",
        "\\centering",
        f"\\caption{{Pre-treatment balance (years $2015$--$2017$, the window where SUS pop, GDP, and outcome data are jointly available) between E1-treated municipalities ($n = {len(treated)}$) and never-treated municipalities ($n = {len(control)}$). Standardized differences computed as $(m_T - m_C) / \\sqrt{{(s_T^2 + s_C^2)/2}}$.}}",
        "\\label{tab:balance}",
        "\\small",
        "\\begin{tabular}{lcccc}",
        "\\toprule",
        "Pre-treatment covariate & Treated mean (sd) & Control mean (sd) & Std.\\ diff. & $p$-value \\\\",
        "\\midrule",
    ]
    for r in rows:
        sig = ""
        if r["pval_welch"] < 0.01: sig = "$^{***}$"
        elif r["pval_welch"] < 0.05: sig = "$^{**}$"
        elif r["pval_welch"] < 0.10: sig = "$^{*}$"
        tab.append(
            f"{r['label']} & {r['mean_treated']:.2f} ({r['sd_treated']:.2f}) & "
            f"{r['mean_control']:.2f} ({r['sd_control']:.2f}) & "
            f"{r['std_diff']:+.3f} & {r['pval_welch']:.3f}{sig} \\\\"
        )
    tab.extend([
        "\\bottomrule",
        "\\multicolumn{5}{l}{\\footnotesize Welch's $t$-test. $^{*}$ p$<$0.10, $^{**}$ p$<$0.05, $^{***}$ p$<$0.01.} \\\\",
        "\\end{tabular}",
        "\\end{table}"
    ])
    (TAB / "tab_balance.tex").write_text("\n".join(tab))
    log.info("wrote tab_balance.tex")

    # ---- crosstab tp_unid × motivo ----
    log.info("\n==== crosstab tp_unid × motivo ====")
    clo = pl.read_parquet(CLO).filter(pl.col("exogenous")) \
            .select(["CNES", "tp_unid"])
    clas = pl.read_parquet(CLAS).select(["CNES", "motivo_v2", "confidence_v2"])
    merged = clo.join(clas, on="CNES", how="inner")
    log.info("merged %d closures", len(merged))

    # cross-tab
    pivot = merged.group_by(["tp_unid", "motivo_v2"]).agg(pl.len().alias("n"))
    log.info("pivot:\n%s", pivot)

    # converter para tabela larga
    motives = ["administrativo", "falência", "fiscal", "fusão", "demanda", "pandemia", "outros", "unknown"]
    types = sorted(merged["tp_unid"].unique().to_list())
    grid = {(t, m): 0 for t in types for m in motives}
    for r in pivot.iter_rows(named=True):
        if r["motivo_v2"] in motives and r["tp_unid"] in types:
            grid[(r["tp_unid"], r["motivo_v2"])] = r["n"]

    label_tp = {
        "05": "General hospital",
        "07": "Specialized hospital",
        "62": "Day hospital",
        "15": "Mixed unit"
    }

    tab2 = [
        "\\begin{table}[h!]",
        "\\centering",
        f"\\caption{{Cross-tabulation of NLP-classified closure motive (Section~\\ref{{sec:method-nlp}}) by establishment type, F5 measurement sample ($n = 60$ closures).}}",
        "\\label{tab:crosstab-motive}",
        "\\small",
        "\\begin{tabular}{l" + "r" * len(motives) + "r}",
        "\\toprule",
        "Establishment type & " + " & ".join([
            "admin." if m == "administrativo" else
            "fal\\^encia" if m == "falência" else
            "fus\\~ao" if m == "fusão" else
            "pand." if m == "pandemia" else
            m for m in motives
        ]) + " & Total \\\\",
        "\\midrule",
    ]
    col_totals = {m: 0 for m in motives}
    for t in types:
        row_total = sum(grid[(t, m)] for m in motives)
        if row_total == 0: continue
        cells = [str(grid[(t, m)]) if grid[(t, m)] > 0 else "--" for m in motives]
        for m in motives: col_totals[m] += grid[(t, m)]
        tab2.append(
            f"{label_tp.get(t, t)} (\\texttt{{tp\\_unid}}={t}) & " +
            " & ".join(cells) + f" & {row_total} \\\\"
        )
    tab2.append("\\midrule")
    grand_total = sum(col_totals.values())
    tab2.append(
        "Total & " +
        " & ".join(str(col_totals[m]) if col_totals[m] > 0 else "--" for m in motives) +
        f" & {grand_total} \\\\"
    )
    tab2.extend(["\\bottomrule", "\\end{tabular}", "\\end{table}"])
    (TAB / "tab_crosstab_motive.tex").write_text("\n".join(tab2))
    log.info("wrote tab_crosstab_motive.tex")

    log.info("==== done ====")


if __name__ == "__main__":
    main()
