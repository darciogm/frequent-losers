"""
17d_evaluate_alt_outcomes.py

Avalia o embedding M-M contra km-baseline em 5 outcomes alternativos
(painel de 17c) — testando se a tese original do paper sobrevive fora do
canal de mortalidade SIM-residencial.

Outcomes:
  hosp_per1k          — taxa de internação SUS por 1k hab (massa, sem under-rep)
  in_hosp_mort_pct    — mortalidade intra-internação % (recipient-side)
  urg_ratio_pct       — % de AIH em caráter urgência (CAR_INT=2)
  icsap_per1k         — taxa de ICSAP por 1k (canon access-to-care BR)
  ami_inhosp_mort_pct — AMI in-hospital mortality % (recipient-side, contorna SIM)

Specs (cross-section, pooled 2015-2023):
  M0:    pop_log + pib_log + UF FE
  M_km:  M0 + z(log iso_km)
  M_emb: M0 + z(iso_emb)
  M_both: M0 + z(log iso_km) + z(iso_emb)

5-fold CV, ridge alpha=1, seed=42, sample pop_min=10k, winsor [1%,99%].

Outputs:
- 04_logs/17d_alt_outcomes_metrics.json
- 04_figures/fig_alt_outcomes.pdf  (forest plot ΔR² × outcome)
- 01_manuscript/tables/tab_alt_outcomes.tex
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
OUT_FILE = INTER / "alt_outcomes.parquet"
POP_FILE = INTER / "pop_municipal_2015_2025.parquet"
PIB_FILE = INTER / "pib_municipal_2015_2023.parquet"

K_NEIGHBORS = 5
SEED = 42
N_SPLITS = 5
POP_MIN = 10_000
YR_LO, YR_HI = 2015, 2023  # janela com pop válida em todos

OUTCOMES = {
    "hosp_per1k":          "Hospitalization rate (per 1k hab)",
    "in_hosp_mort_pct":    "In-hospital mortality (\\%)",
    "urg_ratio_pct":       "Urgency-admission ratio (\\%)",
    "icsap_per1k":         "ICSAP rate (per 1k hab)",
    "ami_inhosp_mort_pct": "AMI in-hospital mortality (\\%)",
}

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "17d_evaluate_alt_outcomes.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("eval_alt")

plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "font.size": 9,
    "axes.titlesize": 10,
    "axes.labelsize": 9,
    "axes.spines.top": False,
    "axes.spines.right": False,
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
    log.info("==== begin alt-outcomes evaluation ====")
    log.info("RAM avail=%.1fGB  K=%d  splits=%d  pop_min=%d  seed=%d  yrs=%d-%d",
             psutil.virtual_memory().available / 1e9,
             K_NEIGHBORS, N_SPLITS, POP_MIN, SEED, YR_LO, YR_HI)

    # ---- isolation features (réplica do 07/17b) ---------------------
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
    log.info("muns no embedding: %d  iso_km median=%.0fkm  iso_emb median=%.4f",
             n, np.median(iso_km), np.median(iso_emb))

    # ---- controles cross-section ----------------------------------
    pop_panel = pl.read_parquet(POP_FILE).filter(
        (pl.col("ano") >= YR_LO) & (pl.col("ano") <= YR_HI)
    ).with_columns(codmun_6=pl.col("cod_mun").str.slice(0, 6)) \
     .group_by("codmun_6").agg(pop_mean=pl.col("pop").mean())
    pib_panel = pl.read_parquet(PIB_FILE).filter(
        (pl.col("ano") >= YR_LO) & (pl.col("ano") <= YR_HI)
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

    # ---- outcomes pooled -------------------------------------------
    out_df = pl.read_parquet(OUT_FILE).filter(
        (pl.col("year") >= YR_LO) & (pl.col("year") <= YR_HI)
    )
    # média simples por município (todos os anos contribuem igual)
    out_agg = out_df.group_by("codmun_6").agg([
        pl.col(c).mean().alias(c) for c in OUTCOMES
    ])
    log.info("outcomes pooled: %d munis", len(out_agg))

    all_results: dict = {}
    for outcome in OUTCOMES:
        merged = base_panel.join(out_agg.select(["codmun_6", outcome]),
                                 on="codmun_6", how="left") \
                           .filter(pl.col(outcome).is_not_null())
        if len(merged) < 100:
            log.warning("[%s] sample tiny (n=%d), pulando", outcome, len(merged))
            continue

        q1 = merged[outcome].quantile(0.01)
        q99 = merged[outcome].quantile(0.99)
        merged = merged.with_columns(
            pl.col(outcome).clip(q1, q99).alias("y"),
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
            "M0":     base,
            "M_km":   np.hstack([base, iso_km_z]),
            "M_emb":  np.hstack([base, iso_emb_z]),
            "M_both": np.hstack([base, iso_km_z, iso_emb_z]),
        }

        kf = KFold(n_splits=N_SPLITS, shuffle=True, random_state=SEED)
        out = {}
        coefs_iso = []
        for name, X in Xs.items():
            r2s, maes = [], []
            cs = []
            for tr, te in kf.split(X):
                mdl = Ridge(alpha=1.0, random_state=SEED)
                mdl.fit(X[tr], y[tr])
                yhat = mdl.predict(X[te])
                r2s.append(r2_score(y[te], yhat))
                maes.append(mean_absolute_error(y[te], yhat))
                if X.shape[1] > base.shape[1]:
                    cs.append(mdl.coef_[base.shape[1]:].copy())
            out[name] = {
                "r2_mean": float(np.mean(r2s)),
                "r2_sd":   float(np.std(r2s)),
                "mae_mean": float(np.mean(maes)),
            }
            if cs:
                out[name]["coef_extra_mean"] = np.array(cs).mean(axis=0).tolist()
                out[name]["coef_extra_sd"]   = np.array(cs).std(axis=0).tolist()

        d_emb  = out["M_emb"]["r2_mean"]  - out["M_km"]["r2_mean"]
        d_both = out["M_both"]["r2_mean"] - out["M_km"]["r2_mean"]
        out["delta_r2_emb_vs_km"]  = float(d_emb)
        out["delta_r2_both_vs_km"] = float(d_both)
        out["n_obs"] = int(len(y))
        out["mean"]  = float(y.mean())
        out["std"]   = float(y.std())
        all_results[outcome] = out
        log.info("[%-22s] n=%d mean=%6.2f sd=%6.2f  M0=%.3f  M_km=%.3f  M_emb=%.3f "
                 " M_both=%.3f  Δemb=%+.4f  Δboth=%+.4f",
                 outcome, out["n_obs"], out["mean"], out["std"],
                 out["M0"]["r2_mean"], out["M_km"]["r2_mean"],
                 out["M_emb"]["r2_mean"], out["M_both"]["r2_mean"],
                 d_emb, d_both)

    metrics = {
        "results": all_results,
        "config": {
            "K_neighbors": K_NEIGHBORS, "n_splits": N_SPLITS,
            "pop_min": POP_MIN, "seed": SEED,
            "winsor": [0.01, 0.99], "yrs": [YR_LO, YR_HI],
        },
    }
    (LOG / "17d_alt_outcomes_metrics.json").write_text(json.dumps(metrics, indent=2))
    log.info("wrote %s", LOG / "17d_alt_outcomes_metrics.json")

    # ---- forest plot -------------------------------------------------
    keys = list(all_results.keys())
    delta_emb  = [all_results[k]["delta_r2_emb_vs_km"]  for k in keys]
    delta_both = [all_results[k]["delta_r2_both_vs_km"] for k in keys]
    sd_emb     = [all_results[k]["M_emb"]["r2_sd"]      for k in keys]

    fig, axes = plt.subplots(1, 2, figsize=(11, 4.2))
    y_pos = np.arange(len(keys))[::-1]

    axes[0].axvline(0, color="0.55", lw=0.8, ls="--")
    axes[0].errorbar(delta_emb, y_pos, xerr=sd_emb, fmt="o", color="C0",
                     ms=6, elinewidth=1.2, capsize=3)
    axes[0].set_yticks(y_pos)
    axes[0].set_yticklabels([OUTCOMES[k] for k in keys])
    axes[0].set_xlabel(r"$\Delta R^2$: $M_{emb}$ vs $M_{km}$")
    axes[0].set_title("Embedding alone vs km alone")

    axes[1].axvline(0, color="0.55", lw=0.8, ls="--")
    axes[1].errorbar(delta_both, y_pos, xerr=sd_emb, fmt="o", color="C2",
                     ms=6, elinewidth=1.2, capsize=3)
    axes[1].set_yticks(y_pos)
    axes[1].set_yticklabels([])
    axes[1].set_xlabel(r"$\Delta R^2$: $M_{both}$ vs $M_{km}$")
    axes[1].set_title("Incremental gain of embedding over km")

    fig.suptitle("Predictive content of the patient-flow embedding across SUS outcomes",
                 y=1.03)
    fig.tight_layout()
    fig.savefig(FIG / "fig_alt_outcomes.pdf")
    fig.savefig(FIG / "fig_alt_outcomes.png", dpi=200)
    plt.close(fig)
    log.info("wrote %s", FIG / "fig_alt_outcomes.pdf")

    # ---- LaTeX table -------------------------------------------------
    rows = []
    for k in keys:
        r = all_results[k]
        rows.append(
            f"{OUTCOMES[k]:<40} & {r['n_obs']:>5} & {r['mean']:>7.2f} "
            f"& {r['M0']['r2_mean']:>5.3f} & {r['M_km']['r2_mean']:>5.3f} "
            f"& {r['M_emb']['r2_mean']:>5.3f} & {r['M_both']['r2_mean']:>5.3f} "
            f"& ${r['delta_r2_emb_vs_km']:+.3f}$ & ${r['delta_r2_both_vs_km']:+.3f}$ \\\\"
        )
    body = "\n".join(rows)
    table = (
        "\\begin{table}[h!]\n"
        "\\centering\n"
        "\\caption{Out-of-sample $R^2$ for alternative SUS outcomes (5-fold CV ridge). "
        f"Sample: municipalities with $\\overline{{\\mathrm{{pop}}}} \\ge {POP_MIN:,}$, "
        f"period {YR_LO}--{YR_HI}. Outcomes computed from SIH-RD raw and pooled by "
        "municipality. Ridge $\\alpha = 1$, seed 42.}\n"
        "\\label{tab:alt-outcomes}\n"
        "\\small\n"
        "\\begin{tabular}{lrrrrrrrr}\n"
        "\\toprule\n"
        "Outcome & $n$ & mean & $M_0$ & $M_{km}$ & $M_{emb}$ & $M_{both}$ "
        "& $\\Delta_{\\mathrm{emb}}$ & $\\Delta_{\\mathrm{both}}$ \\\\\n"
        "\\midrule\n"
        f"{body}\n"
        "\\bottomrule\n"
        "\\end{tabular}\n"
        "\\end{table}\n"
    )
    (TAB / "tab_alt_outcomes.tex").write_text(table)
    log.info("wrote %s", TAB / "tab_alt_outcomes.tex")

    log.info("==== done ==== elapsed=%.1fs", time.perf_counter() - t0)


if __name__ == "__main__":
    main()
