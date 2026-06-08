"""
17b_evaluate_cause_specific.py

Repete o CV ridge do script 07 separadamente para cada causa específica
(ami, stroke, sepsis, maternal, perinatal). Aproveita o mesmo painel de
isolation (iso_km, iso_emb) já calculado do projeto 06b/07.

Specs por causa:
  M0:    pop_log + pib_log + UF_FE
  M_km:  M0 + z(log iso_km)
  M_emb: M0 + z(iso_emb)
  M_both: M0 + z(log iso_km) + z(iso_emb)

5-fold CV, ridge alpha=1, seed=42. Outcome winsorizado [1%, 99%], pooled
2010-2023. Sample restringe a munis com pop média ≥ 10.000 (mesmo critério
do script 09) para evitar variância explosiva em mortalidade rara em
munis pequenos.

Outputs:
- 04_logs/17b_cause_specific_metrics.json
- 04_figures/fig_cause_specific.pdf  (forest plot ΔR² emb-vs-km e both-vs-km)
- 01_manuscript/tables/tab_cause_specific.tex (tabela 5×4 ΔR²)
"""

from __future__ import annotations

import json
import logging
import sys
import time
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import polars as pl
import psutil
from sklearn.linear_model import Ridge
from sklearn.metrics import mean_absolute_error, r2_score
from sklearn.model_selection import KFold

ROOT = Path(__file__).resolve().parents[1]
INTER = ROOT / "02_data" / "intermediate"
LOG = ROOT / "04_logs"
FIG = ROOT / "04_figures"
TAB = ROOT / "01_manuscript" / "tables"

EMB_FILE = INTER / "embeddings_munmun_proj.parquet"
CENT_FILE = INTER / "municipios_centroids.parquet"
CAUSE_FILE = INTER / "cause_specific_mortality.parquet"
POP_FILE = INTER / "pop_municipal_2015_2025.parquet"
PIB_FILE = INTER / "pib_municipal_2015_2023.parquet"

K_NEIGHBORS = 5
SEED = 42
N_SPLITS = 5
POP_MIN = 10_000
CAUSES = ["ami", "stroke", "sepsis", "maternal", "perinatal"]
CAUSE_LABELS = {
    "ami": "AMI (I21)",
    "stroke": "Stroke (I60-64)",
    "sepsis": "Sepsis (A40-41)",
    "maternal": "Maternal (O00-99)",
    "perinatal": "Perinatal (P00-09)",
}

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "17b_evaluate_cause_specific.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("eval_cs")

plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "font.size": 9,
    "axes.titlesize": 10,
    "axes.labelsize": 9,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "figure.dpi": 110,
    "savefig.dpi": 300,
    "savefig.bbox": "tight",
})


def haversine_matrix(lat: np.ndarray, lon: np.ndarray) -> np.ndarray:
    lat_r = np.deg2rad(lat); lon_r = np.deg2rad(lon)
    dlat = lat_r[:, None] - lat_r[None, :]
    dlon = lon_r[:, None] - lon_r[None, :]
    a = (np.sin(dlat / 2) ** 2
         + np.cos(lat_r)[:, None] * np.cos(lat_r)[None, :] * np.sin(dlon / 2) ** 2)
    return 2 * 6371 * np.arcsin(np.sqrt(np.clip(a, 0, 1)))


def zscore(x: np.ndarray) -> np.ndarray:
    s = x.std()
    return (x - x.mean()) / s if s > 0 else x - x.mean()


def main():
    t0 = time.perf_counter()
    log.info("==== begin cause-specific evaluation ====")
    log.info("RAM avail=%.1fGB  K=%d  splits=%d  pop_min=%d  seed=%d",
             psutil.virtual_memory().available / 1e9, K_NEIGHBORS, N_SPLITS, POP_MIN, SEED)

    # ---- isolation features (mesma construção do 07) ----------------
    emb_df = pl.read_parquet(EMB_FILE)
    cent_df = pl.read_parquet(CENT_FILE).select(["cod_mun_6", "uf", "lat", "lon"])
    df = emb_df.join(cent_df, on="cod_mun_6", how="inner")
    dim_cols = [c for c in emb_df.columns if c.startswith("dim_")]
    emb = df.select(dim_cols).to_numpy().astype(np.float32)
    lat = df["lat"].to_numpy()
    lon = df["lon"].to_numpy()
    munis = df["cod_mun_6"].to_list()
    ufs = df["uf"].to_list()
    n = len(munis)
    log.info("muns no embedding: %d", n)

    norms = np.linalg.norm(emb, axis=1, keepdims=True)
    emb_n = emb / np.where(norms > 0, norms, 1)
    cos_mat = emb_n @ emb_n.T
    np.fill_diagonal(cos_mat, -np.inf)
    emb_dist_mat = 1 - cos_mat
    np.fill_diagonal(emb_dist_mat, np.inf)
    nn_emb = np.argpartition(emb_dist_mat, K_NEIGHBORS, axis=1)[:, :K_NEIGHBORS]
    iso_emb = np.take_along_axis(emb_dist_mat, nn_emb, axis=1).mean(axis=1)

    km_mat = haversine_matrix(lat, lon)
    np.fill_diagonal(km_mat, np.inf)
    nn_km = np.argpartition(km_mat, K_NEIGHBORS, axis=1)[:, :K_NEIGHBORS]
    iso_km = np.take_along_axis(km_mat, nn_km, axis=1).mean(axis=1)
    log.info("iso_emb median=%.4f  iso_km median=%.0fkm", np.median(iso_emb), np.median(iso_km))

    # ---- controles cross-section (pop, pib mean, UF dummies) -------
    pop_panel = pl.read_parquet(POP_FILE).filter(
        (pl.col("ano") >= 2010) & (pl.col("ano") <= 2023)
    ).with_columns(codmun_6=pl.col("cod_mun").str.slice(0, 6)) \
     .group_by("codmun_6").agg(pop_mean=pl.col("pop").mean())
    pib_panel = pl.read_parquet(PIB_FILE).filter(
        (pl.col("ano") >= 2010) & (pl.col("ano") <= 2023)
    ).with_columns(codmun_6=pl.col("cod_mun").str.slice(0, 6)) \
     .group_by("codmun_6").agg(pib_mean=pl.col("pib_corr").mean())

    base_panel = pl.DataFrame({
        "codmun_6": munis, "uf": ufs,
        "iso_emb": iso_emb, "iso_km": iso_km,
    }).join(pop_panel, on="codmun_6", how="left") \
      .join(pib_panel, on="codmun_6", how="left") \
      .filter(
          pl.col("pop_mean").is_not_null() & (pl.col("pop_mean") >= POP_MIN) &
          pl.col("pib_mean").is_not_null() & (pl.col("pib_mean") > 0)
      )
    log.info("base panel após pop_min=%d e PIB válido: %d munis", POP_MIN, len(base_panel))

    # ---- outcome cross-section por causa (pooled 2010-2023) --------
    cause_df = pl.read_parquet(CAUSE_FILE).filter(
        (pl.col("year") >= 2010) & (pl.col("year") <= 2023)
    ).group_by(["codmun_6", "cause"]).agg([
        pl.col("n_deaths").sum().alias("n_tot"),
        pl.col("pop").mean().alias("pop_yr"),
    ]).with_columns(
        rate_per100k=(pl.col("n_tot") / pl.col("pop_yr") / 14 * 1e5)
    ).select(["codmun_6", "cause", "rate_per100k"])

    all_results: dict = {}
    for cause in CAUSES:
        c_panel = cause_df.filter(pl.col("cause") == cause) \
                          .select(["codmun_6", "rate_per100k"])
        # munis sem mortes pra causa = rate 0 (não NA): preserva massa do panel
        merged = base_panel.join(c_panel, on="codmun_6", how="left") \
                           .with_columns(pl.col("rate_per100k").fill_null(0.0))

        # winsorize at [1%, 99%]
        q1 = merged["rate_per100k"].quantile(0.01)
        q99 = merged["rate_per100k"].quantile(0.99)
        merged = merged.with_columns(
            pl.col("rate_per100k").clip(q1, q99).alias("y"),
            pl.col("pop_mean").log().alias("pop_log"),
            pl.col("pib_mean").log().alias("pib_log"),
        )

        y = merged["y"].to_numpy()
        pop_log = merged["pop_log"].to_numpy().reshape(-1, 1)
        pib_log = merged["pib_log"].to_numpy().reshape(-1, 1)
        iso_km_z = zscore(np.log(merged["iso_km"].to_numpy() + 1)).reshape(-1, 1)
        iso_emb_z = zscore(merged["iso_emb"].to_numpy()).reshape(-1, 1)
        uf_dum = pl.DataFrame({"uf": merged["uf"].to_list()}).to_dummies("uf").to_numpy().astype(np.float32)

        base = np.hstack([pop_log, pib_log, uf_dum])
        Xs = {
            "M0":      base,
            "M_km":    np.hstack([base, iso_km_z]),
            "M_emb":   np.hstack([base, iso_emb_z]),
            "M_both":  np.hstack([base, iso_km_z, iso_emb_z]),
        }

        kf = KFold(n_splits=N_SPLITS, shuffle=True, random_state=SEED)
        out = {}
        for name, X in Xs.items():
            r2s, maes = [], []
            for tr, te in kf.split(X):
                mdl = Ridge(alpha=1.0, random_state=SEED)
                mdl.fit(X[tr], y[tr])
                yhat = mdl.predict(X[te])
                r2s.append(r2_score(y[te], yhat))
                maes.append(mean_absolute_error(y[te], yhat))
            out[name] = {
                "r2_mean": float(np.mean(r2s)),
                "r2_sd":   float(np.std(r2s)),
                "mae_mean": float(np.mean(maes)),
            }
        d_emb = out["M_emb"]["r2_mean"] - out["M_km"]["r2_mean"]
        d_both = out["M_both"]["r2_mean"] - out["M_km"]["r2_mean"]
        out["delta_r2_emb_vs_km"] = d_emb
        out["delta_r2_both_vs_km"] = d_both
        out["n_obs"] = int(len(y))
        out["mean_rate"] = float(y.mean())
        all_results[cause] = out
        log.info("[%s] n=%d mean_rate=%.1f  M0=%.3f  M_km=%.3f  M_emb=%.3f  "
                 "M_both=%.3f  Δemb=%+.4f  Δboth=%+.4f",
                 cause, out["n_obs"], out["mean_rate"],
                 out["M0"]["r2_mean"], out["M_km"]["r2_mean"],
                 out["M_emb"]["r2_mean"], out["M_both"]["r2_mean"],
                 d_emb, d_both)

    metrics = {
        "results": all_results,
        "config": {
            "K_neighbors": K_NEIGHBORS, "n_splits": N_SPLITS, "pop_min": POP_MIN,
            "seed": SEED, "winsor": [0.01, 0.99],
        },
    }
    (LOG / "17b_cause_specific_metrics.json").write_text(json.dumps(metrics, indent=2))
    log.info("wrote %s", LOG / "17b_cause_specific_metrics.json")

    # ---- forest plot ------------------------------------------------
    causes = list(CAUSES)
    delta_emb = [all_results[c]["delta_r2_emb_vs_km"] for c in causes]
    delta_both = [all_results[c]["delta_r2_both_vs_km"] for c in causes]
    sd_emb = [all_results[c]["M_emb"]["r2_sd"] for c in causes]

    fig, axes = plt.subplots(1, 2, figsize=(10, 4))
    y_pos = np.arange(len(causes))[::-1]

    axes[0].axvline(0, color="0.6", lw=0.8, ls="--")
    axes[0].errorbar(delta_emb, y_pos, xerr=sd_emb, fmt="o", color="C0",
                     ms=6, elinewidth=1.2, capsize=3)
    axes[0].set_yticks(y_pos)
    axes[0].set_yticklabels([CAUSE_LABELS[c] for c in causes])
    axes[0].set_xlabel(r"$\Delta R^2$: $M_{emb}$ vs $M_{km}$")
    axes[0].set_title("Embedding alone vs km alone")

    axes[1].axvline(0, color="0.6", lw=0.8, ls="--")
    axes[1].errorbar(delta_both, y_pos, xerr=sd_emb, fmt="o", color="C2",
                     ms=6, elinewidth=1.2, capsize=3)
    axes[1].set_yticks(y_pos)
    axes[1].set_yticklabels([])
    axes[1].set_xlabel(r"$\Delta R^2$: $M_{both}$ vs $M_{km}$")
    axes[1].set_title("Embedding incremental gain over km")

    fig.suptitle("Cause-specific predictive content of the embedding (5-fold CV ridge)", y=1.02)
    fig.tight_layout()
    fig.savefig(FIG / "fig_cause_specific.pdf")
    fig.savefig(FIG / "fig_cause_specific.png", dpi=200)
    plt.close(fig)
    log.info("wrote %s", FIG / "fig_cause_specific.pdf")

    # ---- LaTeX table -------------------------------------------------
    rows = []
    for c in causes:
        r = all_results[c]
        rows.append(
            f"{CAUSE_LABELS[c]:<22} & {r['n_obs']:>5} & {r['mean_rate']:>6.1f} "
            f"& {r['M0']['r2_mean']:>5.3f} & {r['M_km']['r2_mean']:>5.3f} "
            f"& {r['M_emb']['r2_mean']:>5.3f} & {r['M_both']['r2_mean']:>5.3f} "
            f"& ${r['delta_r2_emb_vs_km']:+.3f}$ & ${r['delta_r2_both_vs_km']:+.3f}$ \\\\"
        )
    body = "\n".join(rows)
    table = (
        "\\begin{table}[h!]\n"
        "\\centering\n"
        "\\caption{Cause-specific cross-sectional ridge $R^2$ (5-fold CV). "
        "Sample: municipalities with $\\overline{\\mathrm{pop}} \\ge 10{,}000$. "
        "Outcome winsorized at $[1\\%, 99\\%]$. Rates per $100{,}000$, "
        "pooled $2010\\text{--}2023$. \\textsc{ami}, \\textsc{stroke}, "
        "\\textsc{sepsis} subject to age cap $<75$; \\textsc{maternal} and "
        "\\textsc{perinatal} unrestricted.}\n"
        "\\label{tab:cause-specific}\n"
        "\\small\n"
        "\\begin{tabular}{lrrrrrrrr}\n"
        "\\toprule\n"
        "Cause & $n$ & mean & $M_0$ & $M_{km}$ & $M_{emb}$ & $M_{both}$ "
        "& $\\Delta_{\\mathrm{emb}}$ & $\\Delta_{\\mathrm{both}}$ \\\\\n"
        "\\midrule\n"
        f"{body}\n"
        "\\bottomrule\n"
        "\\end{tabular}\n"
        "\\end{table}\n"
    )
    (TAB / "tab_cause_specific.tex").write_text(table)
    log.info("wrote %s", TAB / "tab_cause_specific.tex")

    log.info("==== done ==== elapsed=%.1fs", time.perf_counter() - t0)


if __name__ == "__main__":
    main()
