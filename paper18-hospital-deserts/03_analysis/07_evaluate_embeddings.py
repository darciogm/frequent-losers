"""
07_evaluate_embeddings.py

Avalia o embedding M-M (06b) contra baseline km-haversine na predição de
mortalidade evitável (Nolte-McKee). Critério go/no-go do paper:

  ΔR² (modelo com embedding) - (modelo só com km) ≥ 0.05  →  paper tem story
  ΔR² ≥ 0.02 e ≤ 0.05                                       →  marginal, ok
  ΔR² < 0.02                                                →  re-pensar premissa

Métrica de "isolamento" para um município i (ano-pooled 2015-2022):
  iso_emb_i = média de emb_dist(i, j) para j entre os top-K vizinhos no
              embedding (K=5)
  iso_km_i  = média de haversine(i, j) para j entre os top-K vizinhos
              FÍSICOS (K=5)

Ambas medem "quão longe está o tecido conectado mais próximo". Embedding
diverge porque os top-5 vizinhos não são os mesmos.

Modelos (ridge linear, para manter comparação parsimoniosa e estável):
  M0: rate ~ pop_log + pib_log + UF_FE                       (controles)
  M_km:  M0 + iso_km
  M_emb: M0 + iso_emb
  M_both: M0 + iso_km + iso_emb

5-fold CV com KFold embaralhado (não estratificado por UF). Reporta R²
OOS e MAE. Plot scatter density emb_dist × km na amostra.

Inputs:
- 02_data/intermediate/embeddings_munmun_proj.parquet
- 02_data/intermediate/municipios_centroids.parquet
- 02_data/intermediate/amenable_mortality.parquet
- 02_data/intermediate/pop_municipal_2015_2025.parquet
- 02_data/intermediate/pib_municipal_2015_2023.parquet

Outputs:
- 04_logs/07_metrics.json
- 04_figures/fig_emb_vs_km.pdf
- 04_figures/fig_isolation_distribution.pdf
"""

from __future__ import annotations

import json
import logging
import os
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
LOG.mkdir(parents=True, exist_ok=True)
FIG.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "07_evaluate_embeddings.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("eval")

EMB_FILE = INTER / "embeddings_munmun_proj.parquet"
CENT_FILE = INTER / "municipios_centroids.parquet"
MORT_FILE = INTER / "amenable_mortality.parquet"
POP_FILE = INTER / "pop_municipal_2015_2025.parquet"
PIB_FILE = INTER / "pib_municipal_2015_2023.parquet"

K_NEIGHBORS = 5
SEED = 42
N_SPLITS = 5

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


def rss_gb() -> float:
    return psutil.Process().memory_info().rss / 1e9


def haversine_matrix(lat: np.ndarray, lon: np.ndarray) -> np.ndarray:
    """Retorna matriz N×N de distâncias em km. Memória: 8·N² bytes."""
    lat_r = np.deg2rad(lat)
    lon_r = np.deg2rad(lon)
    dlat = lat_r[:, None] - lat_r[None, :]
    dlon = lon_r[:, None] - lon_r[None, :]
    a = np.sin(dlat / 2)**2 + np.cos(lat_r)[:, None] * np.cos(lat_r)[None, :] * np.sin(dlon / 2)**2
    return 2 * 6371 * np.arcsin(np.sqrt(np.clip(a, 0, 1)))


def main():
    t0 = time.perf_counter()
    log.info("==== begin evaluate embeddings ====")
    log.info("RAM avail=%.1fGB  K=%d  splits=%d  seed=%d",
             psutil.virtual_memory().available / 1e9, K_NEIGHBORS, N_SPLITS, SEED)

    # ---- carregar embeddings + centroides ----------------------------
    emb_df = pl.read_parquet(EMB_FILE)
    cent_df = pl.read_parquet(CENT_FILE).select(
        ["cod_mun_6", "nome_mun", "uf", "lat", "lon"]
    )
    df = emb_df.join(cent_df, left_on="cod_mun_6", right_on="cod_mun_6", how="inner")
    log.info("muns com embedding+centroide: %d", len(df))

    dim_cols = [c for c in emb_df.columns if c.startswith("dim_")]
    emb = df.select(dim_cols).to_numpy().astype(np.float32)
    lat = df["lat"].to_numpy()
    lon = df["lon"].to_numpy()
    munis = df["cod_mun_6"].to_list()
    ufs = df["uf"].to_list()
    n = len(munis)
    idx_of = {m: i for i, m in enumerate(munis)}
    log.info("emb shape=%s  RSS=%.2fGB", emb.shape, rss_gb())

    # ---- top-K vizinhos no embedding (cosine) -----------------------
    norms = np.linalg.norm(emb, axis=1, keepdims=True)
    emb_n = emb / np.where(norms > 0, norms, 1)
    cos_mat = emb_n @ emb_n.T          # 5588² float32 ≈ 125 MB
    np.fill_diagonal(cos_mat, -np.inf)
    emb_dist_mat = 1 - cos_mat
    np.fill_diagonal(emb_dist_mat, np.inf)
    nn_emb = np.argpartition(emb_dist_mat, K_NEIGHBORS, axis=1)[:, :K_NEIGHBORS]
    iso_emb = np.take_along_axis(emb_dist_mat, nn_emb, axis=1).mean(axis=1)
    log.info("iso_emb computed  RSS=%.2fGB  range=[%.3f, %.3f]",
             rss_gb(), iso_emb.min(), iso_emb.max())

    # ---- top-K vizinhos físicos (haversine) ------------------------
    km_mat = haversine_matrix(lat, lon)
    np.fill_diagonal(km_mat, np.inf)
    nn_km = np.argpartition(km_mat, K_NEIGHBORS, axis=1)[:, :K_NEIGHBORS]
    iso_km = np.take_along_axis(km_mat, nn_km, axis=1).mean(axis=1)
    log.info("iso_km computed   RSS=%.2fGB  median=%.0fkm  max=%.0fkm",
             rss_gb(), np.median(iso_km), iso_km.max())

    # ---- juntar com mortalidade (pooled 2015-2022) ------------------
    mort = pl.read_parquet(MORT_FILE).filter(
        (pl.col("year") >= 2015) & (pl.col("year") <= 2022)
    ).group_by("codmun_6").agg([
        pl.col("n_amenable").sum().alias("n_amenable_tot"),
        pl.col("pop").mean().alias("pop_mean"),
    ]).with_columns(
        rate_per100k=(pl.col("n_amenable_tot") / pl.col("pop_mean") / 8 * 1e5)
    ).select(["codmun_6", "rate_per100k", "pop_mean"])

    pop = pl.read_parquet(POP_FILE).filter(
        (pl.col("ano") >= 2015) & (pl.col("ano") <= 2022)
    ).with_columns(
        codmun_6=pl.col("cod_mun").str.slice(0, 6)
    ).group_by("codmun_6").agg(pop_mean_v2=pl.col("pop").mean())

    pib = pl.read_parquet(PIB_FILE).filter(
        (pl.col("ano") >= 2015) & (pl.col("ano") <= 2022)
    ).with_columns(
        codmun_6=pl.col("cod_mun").str.slice(0, 6)
    ).group_by("codmun_6").agg(
        pib_mean=pl.col("pib_corr").mean(),
    )

    panel = pl.DataFrame({
        "codmun_6": munis,
        "uf": ufs,
        "iso_emb": iso_emb,
        "iso_km": iso_km,
    }).join(mort, on="codmun_6", how="left") \
      .join(pop, on="codmun_6", how="left") \
      .join(pib, on="codmun_6", how="left")
    log.info("panel raw rows=%d", len(panel))

    panel = panel.with_columns([
        pl.coalesce(pl.col("pop_mean"), pl.col("pop_mean_v2")).alias("pop_eff"),
    ]).filter(
        pl.col("rate_per100k").is_not_null() &
        pl.col("pop_eff").is_not_null() & (pl.col("pop_eff") > 0) &
        pl.col("pib_mean").is_not_null() & (pl.col("pib_mean") > 0)
    )
    panel = panel.with_columns([
        pl.col("pop_eff").log().alias("pop_log"),
        pl.col("pib_mean").log().alias("pib_log"),
        # winsorize rate at 1st/99th
        pl.col("rate_per100k").clip(
            pl.col("rate_per100k").quantile(0.01),
            pl.col("rate_per100k").quantile(0.99),
        ).alias("y"),
    ])
    log.info("panel filtered rows=%d (dropped %d for NA)", len(panel), n - len(panel))

    # ---- montar features --------------------------------------------
    y = panel["y"].to_numpy()
    feat_iso_km = panel["iso_km"].to_numpy().reshape(-1, 1)
    feat_iso_emb = panel["iso_emb"].to_numpy().reshape(-1, 1)
    feat_pop = panel["pop_log"].to_numpy().reshape(-1, 1)
    feat_pib = panel["pib_log"].to_numpy().reshape(-1, 1)

    uf_codes = pl.DataFrame({"uf": panel["uf"].to_list()})
    uf_dum = uf_codes.to_dummies("uf").to_numpy().astype(np.float32)

    base = np.hstack([feat_pop, feat_pib, uf_dum])
    Xs = {
        "M0_controls":   base,
        "M_km":          np.hstack([base, feat_iso_km]),
        "M_emb":         np.hstack([base, feat_iso_emb]),
        "M_both":        np.hstack([base, feat_iso_km, feat_iso_emb]),
    }

    # ---- 5-fold CV --------------------------------------------------
    kf = KFold(n_splits=N_SPLITS, shuffle=True, random_state=SEED)
    results: dict = {}
    for name, X in Xs.items():
        r2s, maes = [], []
        for fold, (tr, te) in enumerate(kf.split(X)):
            mdl = Ridge(alpha=1.0, random_state=SEED)
            mdl.fit(X[tr], y[tr])
            yhat = mdl.predict(X[te])
            r2s.append(r2_score(y[te], yhat))
            maes.append(mean_absolute_error(y[te], yhat))
        results[name] = {
            "r2_mean": float(np.mean(r2s)),
            "r2_sd":   float(np.std(r2s)),
            "mae_mean": float(np.mean(maes)),
            "n_features": X.shape[1],
        }
        log.info("%s: R²=%.3f±%.3f  MAE=%.1f  features=%d",
                 name,
                 results[name]["r2_mean"], results[name]["r2_sd"],
                 results[name]["mae_mean"], X.shape[1])

    delta_r2_emb_over_km = results["M_emb"]["r2_mean"] - results["M_km"]["r2_mean"]
    delta_r2_both_over_km = results["M_both"]["r2_mean"] - results["M_km"]["r2_mean"]
    delta_r2_both_over_emb = results["M_both"]["r2_mean"] - results["M_emb"]["r2_mean"]
    log.info("ΔR² emb-vs-km        = %+.4f", delta_r2_emb_over_km)
    log.info("ΔR² both-vs-km       = %+.4f  (incremento de embedding sobre só-km)", delta_r2_both_over_km)
    log.info("ΔR² both-vs-emb      = %+.4f  (incremento de km sobre só-emb)", delta_r2_both_over_emb)

    # critério go/no-go
    if delta_r2_both_over_km >= 0.05:
        verdict = "GO_STRONG"
    elif delta_r2_both_over_km >= 0.02:
        verdict = "GO_MARGINAL"
    else:
        verdict = "NO_GO_RECONSIDER"
    log.info(">>> VERDICT: %s", verdict)

    metrics = {
        "models": results,
        "delta_r2_both_over_km": delta_r2_both_over_km,
        "delta_r2_both_over_emb": delta_r2_both_over_emb,
        "delta_r2_emb_over_km": delta_r2_emb_over_km,
        "verdict": verdict,
        "n_obs": int(len(y)),
        "K_neighbors": K_NEIGHBORS,
        "n_splits": N_SPLITS,
        "seed": SEED,
    }
    (LOG / "07_metrics.json").write_text(json.dumps(metrics, indent=2))

    # ---- figura 1: scatter density emb_dist × km haversine ---------
    rng = np.random.default_rng(SEED)
    sample = rng.choice(n, size=min(2000, n), replace=False)
    pairs_a = rng.choice(sample, size=15000, replace=True)
    pairs_b = rng.choice(sample, size=15000, replace=True)
    keep = pairs_a != pairs_b
    pairs_a, pairs_b = pairs_a[keep], pairs_b[keep]
    pair_emb = emb_dist_mat[pairs_a, pairs_b]
    # haversine on the fly para não materializar matriz
    la = np.deg2rad(lat[pairs_a]); lb = np.deg2rad(lat[pairs_b])
    loa = np.deg2rad(lon[pairs_a]); lob = np.deg2rad(lon[pairs_b])
    a = np.sin((lb-la)/2)**2 + np.cos(la)*np.cos(lb)*np.sin((lob-loa)/2)**2
    pair_km = 2 * 6371 * np.arcsin(np.sqrt(np.clip(a, 0, 1)))

    fig, axes = plt.subplots(1, 2, figsize=(10, 4.2))

    axes[0].hexbin(pair_km, pair_emb, gridsize=60, mincnt=1, cmap="viridis", bins="log")
    axes[0].set_xlabel("Geographic distance (km, haversine)")
    axes[0].set_ylabel("Embedding distance (1 − cosine similarity)")
    axes[0].set_title(f"Pair-wise: embedding vs km  (n={len(pair_km)})")
    p = np.corrcoef(pair_km, pair_emb)[0, 1]
    axes[0].annotate(f"Pearson ρ = {p:.3f}",
                     xy=(0.04, 0.92), xycoords="axes fraction",
                     fontsize=9, ha="left",
                     bbox=dict(boxstyle="round,pad=0.3", fc="white", ec="0.6", lw=0.6))

    bins = np.percentile(pair_km, np.linspace(0, 100, 21))
    bin_idx = np.digitize(pair_km, bins) - 1
    bin_idx = np.clip(bin_idx, 0, len(bins) - 2)
    bin_centers = (bins[:-1] + bins[1:]) / 2
    bin_med = np.array([np.median(pair_emb[bin_idx == i]) for i in range(len(bins) - 1)])
    bin_q25 = np.array([np.quantile(pair_emb[bin_idx == i], 0.25) for i in range(len(bins) - 1)])
    bin_q75 = np.array([np.quantile(pair_emb[bin_idx == i], 0.75) for i in range(len(bins) - 1)])
    axes[1].fill_between(bin_centers, bin_q25, bin_q75, alpha=0.25, color="C0", label="IQR")
    axes[1].plot(bin_centers, bin_med, color="C0", lw=1.8, label="Median")
    axes[1].set_xlabel("Geographic distance (km)")
    axes[1].set_ylabel("Embedding distance (median, IQR)")
    axes[1].set_title("Binned median by km percentile")
    axes[1].legend(frameon=False, fontsize=8)

    fig.tight_layout()
    fig.savefig(FIG / "fig_emb_vs_km.pdf")
    fig.savefig(FIG / "fig_emb_vs_km.png", dpi=200)
    plt.close(fig)
    log.info("wrote %s", FIG / "fig_emb_vs_km.pdf")

    # ---- figura 2: distribuição iso_emb e iso_km --------------------
    fig, axes = plt.subplots(1, 2, figsize=(10, 4))
    axes[0].hist(iso_km, bins=60, color="C0", alpha=0.85)
    axes[0].set_xlabel("iso_km (mean km to top-5 nearest, km)")
    axes[0].set_ylabel("Municipalities")
    axes[0].set_title(f"Geographic isolation (n={n})")
    axes[0].axvline(np.median(iso_km), color="k", ls="--", lw=0.8,
                    label=f"median {np.median(iso_km):.0f} km")
    axes[0].legend(frameon=False, fontsize=8)

    axes[1].hist(iso_emb, bins=60, color="C1", alpha=0.85)
    axes[1].set_xlabel("iso_emb (mean emb-distance to top-5 nearest)")
    axes[1].set_ylabel("Municipalities")
    axes[1].set_title("Network-revealed isolation")
    axes[1].axvline(np.median(iso_emb), color="k", ls="--", lw=0.8,
                    label=f"median {np.median(iso_emb):.3f}")
    axes[1].legend(frameon=False, fontsize=8)
    fig.tight_layout()
    fig.savefig(FIG / "fig_isolation_distribution.pdf")
    fig.savefig(FIG / "fig_isolation_distribution.png", dpi=200)
    plt.close(fig)
    log.info("wrote %s", FIG / "fig_isolation_distribution.pdf")

    log.info("==== done ==== elapsed=%.1fs RSS=%.2fGB",
             time.perf_counter() - t0, rss_gb())


if __name__ == "__main__":
    main()
