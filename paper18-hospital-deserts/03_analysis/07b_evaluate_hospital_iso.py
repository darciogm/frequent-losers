"""
07b_evaluate_hospital_iso.py

Reformulação após veredito NO_GO_RECONSIDER do 07. Hipóteses corrigidas:

1. "Isolamento" útil para predizer mortalidade evitável é distância ao
   HOSPITAL adequado mais próximo, não ao município vizinho qualquer.
2. Embedding deve viver no MESMO espaço de hospitais — usamos o embedding
   bipartido (06) que coloca M e H no mesmo vetorial space.
3. Mortalidade municipal anual em municípios pequenos (pop < 10k) é
   dominada por ruído de Poisson — filtrar.

Definições:
- "Hospital de alta complexidade" = CNES com hub_categoria ∈
  {CARDIO, ONCO, NEURO, RENAL, PERINAT, TRAUMA_ORTO, TRANSPLANTE}
  e ativo em qualquer mês 2015-2022.
- iso_km_hosp_i = haversine de i ao hospital alta-complexidade mais próximo
- iso_emb_hosp_i = 1 - cos no embedding bipartido (06) ao mesmo set de hosp
                  (mesmo vetor pra eles)
- iso_km_mun_i, iso_emb_mun_i = como em 07 (top-K=5 vizinhos), pra robustez

Modelos (Ridge, 5-fold CV):
  M0_controls:  pop_log + pib_log + UF_FE
  M_km_hosp:    M0 + iso_km_hosp
  M_emb_hosp:   M0 + iso_emb_hosp
  M_both_hosp:  M0 + iso_km_hosp + iso_emb_hosp

Filtro: pop_eff ≥ 10000 (corta ~50% dos municípios mas remove o ruído).

Outputs:
- 04_logs/07b_metrics.json
- 04_figures/fig_iso_hosp.pdf
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

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "07b_evaluate_hospital_iso.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("eval_h")

EMB_M_FILE = INTER / "embeddings_munmun_proj.parquet"      # 06b
EMB_BIP_FILE = INTER / "embeddings_node2vec.parquet"        # 06
CENT_FILE = INTER / "municipios_centroids.parquet"
HUB_FILE = INTER / "hospital_hub_classification.parquet"
MASTER_FILE = INTER / "hospital_master.parquet"
MORT_FILE = INTER / "amenable_mortality.parquet"
POP_FILE = INTER / "pop_municipal_2015_2025.parquet"
PIB_FILE = INTER / "pib_municipal_2015_2023.parquet"

K_NEIGHBORS = 5
SEED = 42
N_SPLITS = 5
POP_MIN = 10_000
HIGH_COMPLEX = {"CARDIO", "ONCO", "NEURO", "RENAL",
                "PERINAT", "TRAUMA_ORTO", "TRANSPLANTE"}

plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "font.size": 9,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "savefig.dpi": 300,
    "savefig.bbox": "tight",
})


def rss_gb() -> float:
    return psutil.Process().memory_info().rss / 1e9


def haversine_to_set(lat_q, lon_q, lat_t, lon_t):
    """Para cada query (lat_q, lon_q), retorna distância em km ao mais
    próximo do conjunto target (lat_t, lon_t). Vetorizado."""
    lat_q_r = np.deg2rad(lat_q)[:, None]
    lon_q_r = np.deg2rad(lon_q)[:, None]
    lat_t_r = np.deg2rad(lat_t)[None, :]
    lon_t_r = np.deg2rad(lon_t)[None, :]
    dlat = lat_t_r - lat_q_r
    dlon = lon_t_r - lon_q_r
    a = np.sin(dlat / 2)**2 + np.cos(lat_q_r) * np.cos(lat_t_r) * np.sin(dlon / 2)**2
    d = 2 * 6371 * np.arcsin(np.sqrt(np.clip(a, 0, 1)))
    return d.min(axis=1), d.argmin(axis=1)


def main():
    t0 = time.perf_counter()
    log.info("==== begin 07b: hospital-isolation evaluation ====")
    log.info("RAM avail=%.1fGB  pop_min=%d  hub_set=%s",
             psutil.virtual_memory().available / 1e9, POP_MIN, HIGH_COMPLEX)

    # ---- hospitais alta complexidade --------------------------------
    hub = pl.read_parquet(HUB_FILE).filter(
        (pl.col("CNES").str.strip_chars() != "") &
        (pl.col("hub_categoria").is_in(list(HIGH_COMPLEX))) &
        (pl.col("hub_ativo_qualquer_mes"))
    ).select(["CNES", "codmun_6"]).unique()
    log.info("hospitais alta-complex (CNES únicos): %d", len(hub))

    # localização dos hospitais via codmun_6 modal (hospital_master)
    master = pl.read_parquet(MASTER_FILE).select(["CNES", "codmun_6_modal"])
    hub = hub.join(master, on="CNES", how="left").rename(
        {"codmun_6_modal": "codmun_6_hosp"}
    )
    # alguns hubs têm codmun_6 do hub_classification mas não do master:
    hub = hub.with_columns(
        pl.coalesce(pl.col("codmun_6_hosp"), pl.col("codmun_6"))
        .alias("codmun_6_loc")
    )

    cent = pl.read_parquet(CENT_FILE).select(["cod_mun_6", "lat", "lon"])
    hub_cent = hub.join(cent, left_on="codmun_6_loc", right_on="cod_mun_6", how="inner")
    log.info("hospitais alta-complex com centroide: %d", len(hub_cent))
    hub_lat = hub_cent["lat"].to_numpy()
    hub_lon = hub_cent["lon"].to_numpy()
    hub_cnes = hub_cent["CNES"].to_list()

    # ---- embeddings -------------------------------------------------
    emb_m_df = pl.read_parquet(EMB_M_FILE)
    emb_bip_df = pl.read_parquet(EMB_BIP_FILE)
    log.info("emb M (06b): %d  emb bipartite (06): %d",
             len(emb_m_df), len(emb_bip_df))

    # bipartite split: M (node_type=='M') vs H (node_type=='H')
    bip_M = emb_bip_df.filter(pl.col("node_type") == "M")
    bip_H = emb_bip_df.filter(pl.col("node_type") == "H")
    dim_cols = [c for c in emb_bip_df.columns if c.startswith("dim_")]
    log.info("  bip M=%d  bip H=%d  dim=%d", len(bip_M), len(bip_H), len(dim_cols))

    # vetor por CNES de hospital alta-complex (no espaço bipartite)
    hub_vec_df = bip_H.rename({"node_id": "CNES"}).select(["CNES"] + dim_cols)
    hub_with_vec = hub_cent.join(hub_vec_df, on="CNES", how="inner")
    hub_emb = hub_with_vec.select(dim_cols).to_numpy().astype(np.float32)
    hub_lat = hub_with_vec["lat"].to_numpy()
    hub_lon = hub_with_vec["lon"].to_numpy()
    log.info("hospitais alta-complex com vetor bipartite: %d", len(hub_with_vec))

    # ---- universo de municípios -------------------------------------
    mun_emb_m_df = emb_m_df.rename({"cod_mun_6": "codmun_6"})
    bip_M = bip_M.rename({"node_id": "codmun_6"})
    mun_bip_df = bip_M.select(["codmun_6"] + dim_cols)
    mun_proj_df = mun_emb_m_df.select(
        ["codmun_6"] + [c for c in mun_emb_m_df.columns if c.startswith("dim_")]
    )

    df = cent.rename({"cod_mun_6": "codmun_6"}).join(
        mun_bip_df.select("codmun_6").with_columns(has_bip=pl.lit(True)),
        on="codmun_6", how="left"
    ).with_columns(
        has_bip=pl.col("has_bip").fill_null(False)
    ).filter(pl.col("has_bip"))
    log.info("muns com vetor bipartite + centroide: %d", len(df))

    munis = df["codmun_6"].to_list()
    lat = df["lat"].to_numpy()
    lon = df["lon"].to_numpy()
    n = len(munis)

    # vetor bipartite de cada município
    mun_bip_arr = mun_bip_df.join(
        pl.DataFrame({"codmun_6": munis, "_o": np.arange(n)}),
        on="codmun_6", how="inner"
    ).sort("_o").select(dim_cols).to_numpy().astype(np.float32)
    log.info("mun_bip_arr shape=%s", mun_bip_arr.shape)

    # ---- iso_km_hosp + iso_emb_hosp ---------------------------------
    iso_km_hosp, nn_idx_km = haversine_to_set(lat, lon, hub_lat, hub_lon)
    log.info("iso_km_hosp: median=%.0fkm  p90=%.0fkm  max=%.0fkm",
             np.median(iso_km_hosp), np.percentile(iso_km_hosp, 90),
             iso_km_hosp.max())

    # iso_emb_hosp: cosine entre vetor M e cada hub vector, pegar o mais perto
    mn = mun_bip_arr / (np.linalg.norm(mun_bip_arr, axis=1, keepdims=True) + 1e-12)
    hn = hub_emb / (np.linalg.norm(hub_emb, axis=1, keepdims=True) + 1e-12)
    sim = mn @ hn.T               # n × |H|
    iso_emb_hosp = 1 - sim.max(axis=1)
    nn_idx_emb = sim.argmax(axis=1)
    log.info("iso_emb_hosp: median=%.4f  p90=%.4f  max=%.4f",
             np.median(iso_emb_hosp), np.percentile(iso_emb_hosp, 90),
             iso_emb_hosp.max())

    # cross-corr: o hospital escolhido pelo embedding é o mesmo do km?
    same_hosp = (nn_idx_km == nn_idx_emb).mean()
    log.info("hospital escolhido pelo km == hospital escolhido pelo emb: %.1f%%",
             same_hosp * 100)

    # ---- mortalidade + controles ------------------------------------
    mort = pl.read_parquet(MORT_FILE).filter(
        (pl.col("year") >= 2010) & (pl.col("year") <= 2023)
    ).group_by("codmun_6").agg([
        pl.col("n_amenable").sum().alias("n_amenable_tot"),
        pl.col("pop").mean().alias("pop_mean"),
    ]).with_columns(
        rate_per100k=(pl.col("n_amenable_tot") / pl.col("pop_mean") / 14 * 1e5)
    ).select(["codmun_6", "rate_per100k", "pop_mean", "n_amenable_tot"])

    pop = pl.read_parquet(POP_FILE).filter(
        (pl.col("ano") >= 2010) & (pl.col("ano") <= 2023)
    ).with_columns(codmun_6=pl.col("cod_mun").str.slice(0, 6)) \
     .group_by("codmun_6").agg(pop_mean_v2=pl.col("pop").mean())

    pib = pl.read_parquet(PIB_FILE).filter(
        (pl.col("ano") >= 2010) & (pl.col("ano") <= 2023)
    ).with_columns(codmun_6=pl.col("cod_mun").str.slice(0, 6)) \
     .group_by("codmun_6").agg(pib_mean=pl.col("pib_corr").mean())

    uf_df = pl.read_parquet(CENT_FILE).select(
        pl.col("cod_mun_6").alias("codmun_6"), "uf"
    )

    panel = pl.DataFrame({
        "codmun_6": munis,
        "iso_km_hosp": iso_km_hosp,
        "iso_emb_hosp": iso_emb_hosp,
    }).join(mort, on="codmun_6", how="left") \
      .join(pop, on="codmun_6", how="left") \
      .join(pib, on="codmun_6", how="left") \
      .join(uf_df, on="codmun_6", how="left") \
      .with_columns(
          pop_eff=pl.coalesce(pl.col("pop_mean"), pl.col("pop_mean_v2"))
      ).filter(
          pl.col("rate_per100k").is_not_null() &
          pl.col("pop_eff").is_not_null() & (pl.col("pop_eff") >= POP_MIN) &
          pl.col("pib_mean").is_not_null() & (pl.col("pib_mean") > 0) &
          pl.col("uf").is_not_null()
      ).with_columns([
          pl.col("pop_eff").log().alias("pop_log"),
          pl.col("pib_mean").log().alias("pib_log"),
          pl.col("rate_per100k").clip(
              pl.col("rate_per100k").quantile(0.01),
              pl.col("rate_per100k").quantile(0.99),
          ).alias("y"),
      ])
    log.info("panel filtered (pop>=%d): %d obs", POP_MIN, len(panel))
    log.info("y stats: median=%.1f  mean=%.1f  sd=%.1f",
             panel["y"].median(), panel["y"].mean(), panel["y"].std())

    # ---- montar X ---------------------------------------------------
    y = panel["y"].to_numpy()
    pop_log = panel["pop_log"].to_numpy().reshape(-1, 1)
    pib_log = panel["pib_log"].to_numpy().reshape(-1, 1)
    uf_dum = pl.DataFrame({"uf": panel["uf"].to_list()}).to_dummies("uf").to_numpy().astype(np.float32)
    iso_km_h = panel["iso_km_hosp"].to_numpy().reshape(-1, 1)
    iso_emb_h = panel["iso_emb_hosp"].to_numpy().reshape(-1, 1)

    # log-transform iso_km (very right-skewed) e standardize iso_emb
    iso_km_h_log = np.log1p(iso_km_h)
    iso_emb_h_z = (iso_emb_h - iso_emb_h.mean()) / iso_emb_h.std()
    iso_km_h_z = (iso_km_h_log - iso_km_h_log.mean()) / iso_km_h_log.std()

    base = np.hstack([pop_log, pib_log, uf_dum])
    Xs = {
        "M0_controls":  base,
        "M_km_hosp":    np.hstack([base, iso_km_h_z]),
        "M_emb_hosp":   np.hstack([base, iso_emb_h_z]),
        "M_both_hosp":  np.hstack([base, iso_km_h_z, iso_emb_h_z]),
    }

    # ---- 5-fold CV --------------------------------------------------
    kf = KFold(n_splits=N_SPLITS, shuffle=True, random_state=SEED)
    results = {}
    coef_summary = {}
    for name, X in Xs.items():
        r2s, maes = [], []
        coefs = []
        for fold, (tr, te) in enumerate(kf.split(X)):
            mdl = Ridge(alpha=1.0, random_state=SEED)
            mdl.fit(X[tr], y[tr])
            yhat = mdl.predict(X[te])
            r2s.append(r2_score(y[te], yhat))
            maes.append(mean_absolute_error(y[te], yhat))
            coefs.append(mdl.coef_)
        results[name] = {
            "r2_mean": float(np.mean(r2s)),
            "r2_sd":   float(np.std(r2s)),
            "mae_mean": float(np.mean(maes)),
            "n_features": X.shape[1],
        }
        # coef do iso_*: posições finais
        if "iso" in name:
            coefs_arr = np.array(coefs)
            coef_summary[name] = {
                "iso_terms_mean": coefs_arr[:, -(X.shape[1] - base.shape[1]):].mean(axis=0).tolist(),
                "iso_terms_sd":   coefs_arr[:, -(X.shape[1] - base.shape[1]):].std(axis=0).tolist(),
            }
        log.info("%s: R²=%.3f±%.3f  MAE=%.1f  features=%d",
                 name,
                 results[name]["r2_mean"], results[name]["r2_sd"],
                 results[name]["mae_mean"], X.shape[1])
    log.info("coef summary: %s", json.dumps(coef_summary, indent=2))

    delta_emb_over_km = results["M_emb_hosp"]["r2_mean"] - results["M_km_hosp"]["r2_mean"]
    delta_both_over_km = results["M_both_hosp"]["r2_mean"] - results["M_km_hosp"]["r2_mean"]
    delta_both_over_emb = results["M_both_hosp"]["r2_mean"] - results["M_emb_hosp"]["r2_mean"]
    log.info("ΔR² emb-vs-km        = %+.4f", delta_emb_over_km)
    log.info("ΔR² both-vs-km       = %+.4f  (incremento de embedding sobre só-km)", delta_both_over_km)
    log.info("ΔR² both-vs-emb      = %+.4f  (incremento de km sobre só-emb)", delta_both_over_emb)

    if delta_both_over_km >= 0.05:
        verdict = "GO_STRONG"
    elif delta_both_over_km >= 0.02:
        verdict = "GO_MARGINAL"
    elif delta_both_over_km >= 0.005:
        verdict = "WEAK_BUT_PRESENT"
    else:
        verdict = "NO_GO_RECONSIDER"
    log.info(">>> VERDICT: %s", verdict)

    metrics = {
        "models": results,
        "coef_summary": coef_summary,
        "delta_r2_both_over_km": delta_both_over_km,
        "delta_r2_both_over_emb": delta_both_over_emb,
        "delta_r2_emb_over_km": delta_emb_over_km,
        "verdict": verdict,
        "n_obs": int(len(y)),
        "pop_min": POP_MIN,
        "K_neighbors": K_NEIGHBORS,
        "n_splits": N_SPLITS,
        "seed": SEED,
        "iso_km_hosp_median_km": float(np.median(iso_km_hosp)),
        "iso_km_hosp_p90_km": float(np.percentile(iso_km_hosp, 90)),
        "same_hosp_km_vs_emb_pct": float(same_hosp * 100),
    }
    (LOG / "07b_metrics.json").write_text(json.dumps(metrics, indent=2))

    # ---- figura: scatter iso_km vs iso_emb ao hospital --------------
    fig, axes = plt.subplots(1, 3, figsize=(13, 4.2))

    ax = axes[0]
    ax.hexbin(iso_km_hosp, iso_emb_hosp, gridsize=50, mincnt=1, cmap="viridis", bins="log")
    p = np.corrcoef(iso_km_hosp, iso_emb_hosp)[0, 1]
    ax.set_xlabel("km to nearest high-complexity hospital")
    ax.set_ylabel("embedding-distance to same set")
    ax.set_title(f"Hospital-set isolation  (n={n})\nPearson ρ = {p:.3f}")

    ax = axes[1]
    ax.hist(iso_km_hosp[iso_km_hosp < 500], bins=60, color="C0", alpha=0.85)
    ax.set_xlabel("iso_km_hosp (km)")
    ax.set_ylabel("Municipalities")
    ax.set_title(f"Geographic isolation  (median {np.median(iso_km_hosp):.0f} km)")
    ax.axvline(np.median(iso_km_hosp), color="k", ls="--", lw=0.8)

    ax = axes[2]
    ax.hist(iso_emb_hosp, bins=60, color="C1", alpha=0.85)
    ax.set_xlabel("iso_emb_hosp")
    ax.set_ylabel("Municipalities")
    ax.set_title(f"Embedding isolation  (median {np.median(iso_emb_hosp):.3f})")
    ax.axvline(np.median(iso_emb_hosp), color="k", ls="--", lw=0.8)

    fig.tight_layout()
    fig.savefig(FIG / "fig_iso_hosp.pdf")
    fig.savefig(FIG / "fig_iso_hosp.png", dpi=200)
    plt.close(fig)
    log.info("wrote %s", FIG / "fig_iso_hosp.pdf")

    log.info("==== done ==== elapsed=%.1fs RSS=%.2fGB",
             time.perf_counter() - t0, rss_gb())


if __name__ == "__main__":
    main()
