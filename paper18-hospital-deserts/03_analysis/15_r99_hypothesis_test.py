"""
15_r99_hypothesis_test.py

Testa empiricamente a hipótese central da Discussion (Section 6):

H_R99: A fração de óbitos com causa básica ill-defined (CID-10 R-codes,
       em particular R99) entre os óbitos totais é maior em municípios
       mais isolados — operacionalmente, correlaciona positivamente com
       iso_km_hosp e iso_emb_hosp. Esse padrão atenua mecanicamente a
       associação entre acesso e amenable mortality observada,
       explicando por que o ΔR² da regressão da Section 5 é nulo.

Operacionalização:
- frac_r99_i = (óbitos com CAUSABAS começando com 'R' no município i,
                pooled 2010-2023) / (total óbitos no município i)
- frac_r99_strict_i = (óbitos com CAUSABAS == 'R99' OR começando com 'R'
                       específico das ill-defined: R96-R99, ou seja
                       'R96', 'R97', 'R98', 'R99')
- testes:
  (1) Pearson(frac_r99, iso_km_z) — esperamos > 0
  (2) Pearson(frac_r99, iso_emb_z) — esperamos > 0
  (3) Pearson(frac_r99, divergence_z) — direção menos óbvia
  (4) frac_r99 vs região (boxplot) — N e NE devem ter média maior
  (5) Regressão: amenable_rate ~ iso_km + iso_emb + frac_r99 + controls
      → coef de frac_r99 deve ser negativo e significativo, sugerindo
      que após controlar por R99 a relação acesso-mortalidade emerge.

Output:
- 04_logs/15_r99_hypothesis_test.json
- 04_logs/15_r99_hypothesis_test.log
- 04_figures/fig_r99_hypothesis.pdf+png  (4 painéis)
"""

from __future__ import annotations

import json
import logging
import sys
import time
from pathlib import Path

import duckdb
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import polars as pl
import psutil
from sklearn.linear_model import Ridge
from sklearn.metrics import r2_score
from sklearn.model_selection import KFold

ROOT = Path(__file__).resolve().parents[1]
INTER = ROOT / "02_data" / "intermediate"
LOG = ROOT / "04_logs"
FIG = ROOT / "04_figures"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "15_r99_hypothesis_test.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("r99")

REG = {
    "AC":"N","AM":"N","AP":"N","PA":"N","RO":"N","RR":"N","TO":"N",
    "AL":"NE","BA":"NE","CE":"NE","MA":"NE","PB":"NE","PE":"NE","PI":"NE","RN":"NE","SE":"NE",
    "ES":"SE","MG":"SE","RJ":"SE","SP":"SE",
    "PR":"S","RS":"S","SC":"S",
    "DF":"CO","GO":"CO","MS":"CO","MT":"CO",
}
REG_LABEL = {"N":"North","NE":"Northeast","SE":"Southeast","S":"South","CO":"Center-West"}
REG_COLOR = {"N":"#56B4E9","NE":"#E69F00","SE":"#009E73","S":"#CC79A7","CO":"#F0E442"}

plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "font.size": 9,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "savefig.dpi": 300,
    "savefig.bbox": "tight",
})


def main():
    t0 = time.perf_counter()
    log.info("==== begin R99 hypothesis test ====")
    log.info("RAM avail=%.1fGB", psutil.virtual_memory().available / 1e9)

    # ---- frac_r99 por município via DuckDB sobre SIM consolidado ----
    con = duckdb.connect()
    con.execute("PRAGMA threads=12")
    con.execute("PRAGMA memory_limit='14GB'")
    con.execute("PRAGMA temp_directory='/tmp/duckdb_paper18'")

    log.info("[1/5] computing frac_r99 by municipality (SIM 2010-2023)...")
    sim_df = con.sql(f"""
        WITH sim AS (
            SELECT
                LPAD(CAST(codmunres AS VARCHAR), 6, '0') AS codmun_6,
                EXTRACT(YEAR FROM dtobito) AS year,
                causabas
            FROM read_parquet('{INTER}/sim_consolidated/sim_do_*.parquet', union_by_name=true)
            WHERE codmunres IS NOT NULL
              AND dtobito IS NOT NULL
              AND EXTRACT(YEAR FROM dtobito) BETWEEN 2010 AND 2023
              AND causabas IS NOT NULL
        )
        SELECT
            codmun_6,
            COUNT(*) AS n_total,
            SUM(CASE WHEN SUBSTR(causabas, 1, 1) = 'R' THEN 1 ELSE 0 END) AS n_r,
            SUM(CASE WHEN SUBSTR(causabas, 1, 3) IN ('R96','R97','R98','R99') THEN 1 ELSE 0 END) AS n_r_illdef,
            SUM(CASE WHEN SUBSTR(causabas, 1, 3) = 'R99' THEN 1 ELSE 0 END) AS n_r99
        FROM sim
        GROUP BY codmun_6
        HAVING n_total >= 50
    """).pl()
    log.info("muns with ≥50 deaths: %d", len(sim_df))
    log.info("R-code totals (all): %s", sim_df.select(pl.col("n_r").sum()).item())
    log.info("ill-defined R96-R99 totals: %s", sim_df.select(pl.col("n_r_illdef").sum()).item())

    sim_df = sim_df.with_columns([
        (pl.col("n_r").cast(pl.Float64) / pl.col("n_total")).alias("frac_r"),
        (pl.col("n_r_illdef").cast(pl.Float64) / pl.col("n_total")).alias("frac_r_illdef"),
        (pl.col("n_r99").cast(pl.Float64) / pl.col("n_total")).alias("frac_r99"),
    ])
    log.info("frac_r summary: median=%.3f mean=%.3f p90=%.3f max=%.3f",
             sim_df["frac_r"].median(), sim_df["frac_r"].mean(),
             sim_df["frac_r"].quantile(0.90), sim_df["frac_r"].max())
    log.info("frac_r_illdef summary: median=%.3f mean=%.3f p90=%.3f max=%.3f",
             sim_df["frac_r_illdef"].median(), sim_df["frac_r_illdef"].mean(),
             sim_df["frac_r_illdef"].quantile(0.90), sim_df["frac_r_illdef"].max())

    # ---- juntar com divergence panel ---------------------------------
    log.info("[2/5] joining with divergence panel and isolation features...")
    div = pl.read_parquet(INTER / "divergence_panel.parquet")
    panel = div.join(sim_df, on="codmun_6", how="inner") \
               .with_columns(
                   regiao=pl.col("uf").replace_strict(REG, default="?")
               )
    log.info("panel rows: %d", len(panel))

    # ---- (1) (2) (3) correlações principais ---------------------------
    log.info("[3/5] correlation tests...")
    p_km = float(np.corrcoef(panel["frac_r_illdef"].to_numpy(),
                             panel["iso_km_z"].to_numpy())[0, 1])
    p_emb = float(np.corrcoef(panel["frac_r_illdef"].to_numpy(),
                              panel["iso_emb_z"].to_numpy())[0, 1])
    p_div = float(np.corrcoef(panel["frac_r_illdef"].to_numpy(),
                              panel["divergence_z"].to_numpy())[0, 1])
    p_emb_full_r = float(np.corrcoef(panel["frac_r"].to_numpy(),
                                     panel["iso_emb_z"].to_numpy())[0, 1])
    p_km_full_r = float(np.corrcoef(panel["frac_r"].to_numpy(),
                                    panel["iso_km_z"].to_numpy())[0, 1])
    log.info("(1) Pearson(frac_r_illdef, iso_km_z) = %+.3f", p_km)
    log.info("(2) Pearson(frac_r_illdef, iso_emb_z) = %+.3f", p_emb)
    log.info("(3) Pearson(frac_r_illdef, divergence_z) = %+.3f", p_div)
    log.info("    Pearson(frac_r [all R], iso_km_z) = %+.3f", p_km_full_r)
    log.info("    Pearson(frac_r [all R], iso_emb_z) = %+.3f", p_emb_full_r)

    # ---- (4) por região --------------------------------------------
    log.info("[4/5] regional breakdown...")
    regional_stats = []
    for r in ["N","NE","SE","S","CO"]:
        sub = panel.filter(pl.col("regiao") == r)
        regional_stats.append({
            "regiao": r,
            "n": len(sub),
            "frac_r_illdef_median": float(sub["frac_r_illdef"].median()),
            "frac_r_illdef_mean": float(sub["frac_r_illdef"].mean()),
            "frac_r_illdef_p90": float(sub["frac_r_illdef"].quantile(0.90)),
        })
        log.info("  %s: n=%d  median=%.3f  mean=%.3f  p90=%.3f",
                 r, len(sub), regional_stats[-1]["frac_r_illdef_median"],
                 regional_stats[-1]["frac_r_illdef_mean"],
                 regional_stats[-1]["frac_r_illdef_p90"])

    # ---- (5) regressão: amenable_rate ~ controls + iso + frac_r99 -
    log.info("[5/5] augmented regression with frac_r_illdef control...")
    mort = pl.read_parquet(INTER / "amenable_mortality.parquet").filter(
        (pl.col("year") >= 2010) & (pl.col("year") <= 2023)
    ).group_by("codmun_6").agg([
        pl.col("n_amenable").sum().alias("n_amenable_tot"),
        pl.col("pop").mean().alias("pop_mean"),
    ]).with_columns(
        rate_per100k=(pl.col("n_amenable_tot") / pl.col("pop_mean") / 14 * 1e5)
    )
    pop = pl.read_parquet(INTER / "pop_municipal_2015_2025.parquet").filter(
        (pl.col("ano") >= 2010) & (pl.col("ano") <= 2023)
    ).with_columns(codmun_6=pl.col("cod_mun").str.slice(0, 6)) \
     .group_by("codmun_6").agg(pop_mean_v2=pl.col("pop").mean())
    pib = pl.read_parquet(INTER / "pib_municipal_2015_2023.parquet").filter(
        (pl.col("ano") >= 2010) & (pl.col("ano") <= 2023)
    ).with_columns(codmun_6=pl.col("cod_mun").str.slice(0, 6)) \
     .group_by("codmun_6").agg(pib_mean=pl.col("pib_corr").mean())

    reg_panel = panel.join(mort, on="codmun_6", how="left") \
                     .join(pop, on="codmun_6", how="left") \
                     .join(pib, on="codmun_6", how="left") \
                     .with_columns(pop_eff=pl.coalesce("pop_mean", "pop_mean_v2")) \
                     .filter(
                         pl.col("rate_per100k").is_not_null() &
                         pl.col("pop_eff").is_not_null() & (pl.col("pop_eff") >= 10000) &
                         pl.col("pib_mean").is_not_null() & (pl.col("pib_mean") > 0) &
                         pl.col("uf").is_not_null()
                     ).with_columns([
                         pl.col("pop_eff").log().alias("pop_log"),
                         pl.col("pib_mean").log().alias("pib_log"),
                         pl.col("rate_per100k").clip(
                             pl.col("rate_per100k").quantile(0.01),
                             pl.col("rate_per100k").quantile(0.99),
                         ).alias("y"),
                         pl.col("frac_r_illdef").alias("r99_frac"),
                     ])
    log.info("regression panel: %d obs", len(reg_panel))

    y = reg_panel["y"].to_numpy()
    pop_log = reg_panel["pop_log"].to_numpy().reshape(-1, 1)
    pib_log = reg_panel["pib_log"].to_numpy().reshape(-1, 1)
    iso_km_z = reg_panel["iso_km_z"].to_numpy().reshape(-1, 1)
    iso_emb_z = reg_panel["iso_emb_z"].to_numpy().reshape(-1, 1)
    r99 = reg_panel["r99_frac"].to_numpy().reshape(-1, 1)
    r99_z = (r99 - r99.mean()) / r99.std()
    uf_dum = pl.DataFrame({"uf": reg_panel["uf"].to_list()}).to_dummies("uf").to_numpy().astype(np.float32)

    base = np.hstack([pop_log, pib_log, uf_dum])
    Xs = {
        "M_km":              np.hstack([base, iso_km_z]),
        "M_km_r99":          np.hstack([base, iso_km_z, r99_z]),
        "M_both":            np.hstack([base, iso_km_z, iso_emb_z]),
        "M_both_r99":        np.hstack([base, iso_km_z, iso_emb_z, r99_z]),
    }

    kf = KFold(n_splits=5, shuffle=True, random_state=42)
    cv_results = {}
    coefs_summary = {}
    for name, X in Xs.items():
        r2s = []
        coefs = []
        for tr, te in kf.split(X):
            m = Ridge(alpha=1.0).fit(X[tr], y[tr])
            r2s.append(r2_score(y[te], m.predict(X[te])))
            coefs.append(m.coef_)
        cv_results[name] = {"r2_mean": float(np.mean(r2s)),
                            "r2_sd": float(np.std(r2s)),
                            "n_features": X.shape[1]}
        # extract coefs of last few terms (the iso + r99 ones)
        n_extra = X.shape[1] - base.shape[1]
        coefs_summary[name] = {
            "extra_coef_means": np.array(coefs)[:, base.shape[1]:].mean(axis=0).tolist(),
            "extra_coef_sds": np.array(coefs)[:, base.shape[1]:].std(axis=0).tolist(),
        }
        log.info("%s: R²=%.3f±%.3f  features=%d  extra_coefs=%s",
                 name, cv_results[name]["r2_mean"], cv_results[name]["r2_sd"],
                 X.shape[1],
                 [f"{c:+.3f}" for c in coefs_summary[name]["extra_coef_means"]])

    delta_r99_over_km = cv_results["M_km_r99"]["r2_mean"] - cv_results["M_km"]["r2_mean"]
    delta_emb_after_r99 = cv_results["M_both_r99"]["r2_mean"] - cv_results["M_km_r99"]["r2_mean"]
    log.info(">>> ΔR² adding R99 to M_km: %+.4f", delta_r99_over_km)
    log.info(">>> ΔR² adding emb after R99: %+.4f", delta_emb_after_r99)

    # ---- export JSON ----------------------------------------------
    metrics = {
        "frac_r_illdef_distribution": {
            "median": float(sim_df["frac_r_illdef"].median()),
            "mean": float(sim_df["frac_r_illdef"].mean()),
            "p90": float(sim_df["frac_r_illdef"].quantile(0.90)),
            "max": float(sim_df["frac_r_illdef"].max()),
        },
        "correlations": {
            "pearson_r99_vs_iso_km_z": p_km,
            "pearson_r99_vs_iso_emb_z": p_emb,
            "pearson_r99_vs_divergence_z": p_div,
            "pearson_full_r_vs_iso_km_z": p_km_full_r,
            "pearson_full_r_vs_iso_emb_z": p_emb_full_r,
        },
        "regional_stats": regional_stats,
        "regression_models": cv_results,
        "regression_coefs": coefs_summary,
        "delta_r2_r99_over_km": delta_r99_over_km,
        "delta_r2_emb_after_r99": delta_emb_after_r99,
        "n_obs_corr": len(panel),
        "n_obs_reg": int(len(reg_panel)),
    }
    (LOG / "15_r99_hypothesis_test.json").write_text(json.dumps(metrics, indent=2))

    # ---- figura 4 painéis -----------------------------------------
    fig, axes = plt.subplots(2, 2, figsize=(11, 8.5))

    # (a) hexbin frac_r_illdef vs iso_km_z
    ax = axes[0, 0]
    ax.hexbin(panel["iso_km_z"].to_numpy(), panel["frac_r_illdef"].to_numpy(),
              gridsize=40, mincnt=1, cmap="viridis", bins="log")
    ax.set_xlabel("$z(\\log\\,\\mathrm{iso}^{km})$")
    ax.set_ylabel("Fraction of deaths with ill-defined cause (R96–R99)")
    ax.set_title(f"(a) frac. ill-defined vs km isolation\nPearson ρ = {p_km:+.3f}",
                 fontsize=10)

    # (b) hexbin frac_r_illdef vs iso_emb_z
    ax = axes[0, 1]
    ax.hexbin(panel["iso_emb_z"].to_numpy(), panel["frac_r_illdef"].to_numpy(),
              gridsize=40, mincnt=1, cmap="viridis", bins="log")
    ax.set_xlabel("$z(\\mathrm{iso}^{emb})$")
    ax.set_ylabel("Fraction of deaths with ill-defined cause (R96–R99)")
    ax.set_title(f"(b) frac. ill-defined vs embedding isolation\nPearson ρ = {p_emb:+.3f}",
                 fontsize=10)

    # (c) boxplot por região
    ax = axes[1, 0]
    data_box = []
    pos = []
    cols = []
    for r in ["N","NE","SE","S","CO"]:
        sub = panel.filter(pl.col("regiao") == r)
        data_box.append(sub["frac_r_illdef"].to_numpy())
        pos.append(len(data_box))
        cols.append(REG_COLOR[r])
    bp = ax.boxplot(data_box, positions=pos, widths=0.6, patch_artist=True,
                    medianprops=dict(color="black", lw=1),
                    flierprops=dict(marker="o", markersize=2, alpha=0.4))
    for patch, c in zip(bp["boxes"], cols):
        patch.set_facecolor(c)
        patch.set_alpha(0.7)
    ax.set_xticks(pos)
    ax.set_xticklabels([REG_LABEL[r] for r in ["N","NE","SE","S","CO"]],
                       fontsize=9, rotation=15)
    ax.set_ylabel("Fraction of deaths with ill-defined cause")
    ax.set_title("(c) Ill-defined fraction by macro-region", fontsize=10)

    # (d) bar plot: ΔR² emb-over-km BEFORE vs AFTER R99 control
    ax = axes[1, 1]
    labels = ["M_km", "M_both\n(no R99)", "M_km+R99", "M_both\n+R99"]
    r2s = [cv_results["M_km"]["r2_mean"],
           cv_results["M_both"]["r2_mean"],
           cv_results["M_km_r99"]["r2_mean"],
           cv_results["M_both_r99"]["r2_mean"]]
    sds = [cv_results["M_km"]["r2_sd"],
           cv_results["M_both"]["r2_sd"],
           cv_results["M_km_r99"]["r2_sd"],
           cv_results["M_both_r99"]["r2_sd"]]
    colors = ["C0", "C1", "C2", "C3"]
    ax.bar(range(len(labels)), r2s, yerr=sds, capsize=3, alpha=0.85,
           color=colors, edgecolor="black", linewidth=0.5)
    ax.set_xticks(range(len(labels)))
    ax.set_xticklabels(labels, fontsize=8.5)
    ax.set_ylabel("Out-of-sample $R^2$")
    ax.set_title("(d) Predictive R² across models\n(5-fold CV, ridge, n=" + str(len(reg_panel)) + ")",
                 fontsize=10)
    for i, (r, s) in enumerate(zip(r2s, sds)):
        ax.text(i, r + s + 0.005, f"{r:.3f}", ha="center", fontsize=8)
    ax.set_ylim(0, max(r2s) + 0.08)

    fig.suptitle(
        "R99 hypothesis: SIM ill-defined-cause coverage gradient explains the predictive null",
        fontsize=11, y=1.005,
    )
    fig.tight_layout()
    fig.savefig(FIG / "fig_r99_hypothesis.pdf")
    fig.savefig(FIG / "fig_r99_hypothesis.png", dpi=200)
    plt.close(fig)
    log.info("wrote %s", FIG / "fig_r99_hypothesis.pdf")

    log.info("==== done ==== elapsed=%.1fs", time.perf_counter() - t0)


if __name__ == "__main__":
    main()
