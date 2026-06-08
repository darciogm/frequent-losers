#!/usr/bin/env python3
"""
07d_osrm_real_routes — replaces 07c haversine fallback with REAL OSRM driving
times via the public OSRM demo server (router.project-osrm.org).

For each Brazilian municipality, finds the nearest high-complexity hub
hospital (matching the iso_km_hosp logic in 07b) and queries OSRM for the
routed driving time muni_centroid -> hub_hospital_centroid. Then refits the
07c horse race.
"""
from __future__ import annotations

import argparse, json, logging, sys, time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import polars as pl
import psutil
import requests
from sklearn.linear_model import Ridge
from sklearn.metrics import mean_absolute_error, r2_score
from sklearn.model_selection import KFold

ROOT = Path(__file__).resolve().parents[1]
INTER = ROOT / "02_data" / "intermediate"
LOG_DIR = ROOT / "04_logs"
FIG_DIR = ROOT / "04_figures"
TAB_DIR = ROOT / "01_manuscript" / "tables"

OUT_PANEL = INTER / "osrm_travel_time_panel.parquet"
OUT_JSON = LOG_DIR / "07c_osrm_vs_embedding.json"
OUT_LOG = LOG_DIR / "07d_osrm_real_routes.log"
OUT_FIG = FIG_DIR / "fig_osrm_vs_embedding.pdf"
OUT_TAB = TAB_DIR / "tab_osrm_vs_embedding.tex"

CENT_FILE = INTER / "municipios_centroids.parquet"
HUB_FILE = INTER / "hospital_hub_classification.parquet"
MASTER_FILE = INTER / "hospital_master.parquet"
DIV_FILE = INTER / "divergence_panel.parquet"
EMB_BIP_FILE = INTER / "embeddings_node2vec.parquet"

HIGH_COMPLEX = {"CARDIO", "ONCO", "NEURO", "RENAL", "PERINAT", "TRAUMA_ORTO", "TRANSPLANTE"}
SEED = 42
OSRM_BASE = "https://router.project-osrm.org"
N_WORKERS = 6
RATE_DELAY_S = 0.20

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[logging.FileHandler(OUT_LOG, mode="w"), logging.StreamHandler(sys.stdout)],
)
log = logging.getLogger("osrm")


def haversine_nn(lat_q, lon_q, lat_t, lon_t):
    lat_q_r = np.radians(lat_q)[:, None]
    lon_q_r = np.radians(lon_q)[:, None]
    lat_t_r = np.radians(lat_t)[None, :]
    lon_t_r = np.radians(lon_t)[None, :]
    dlat = lat_t_r - lat_q_r
    dlon = lon_t_r - lon_q_r
    a = np.sin(dlat / 2) ** 2 + np.cos(lat_q_r) * np.cos(lat_t_r) * np.sin(dlon / 2) ** 2
    d = 2 * 6371 * np.arcsin(np.sqrt(np.clip(a, 0, 1)))
    return d.min(axis=1), d.argmin(axis=1)


def osrm_route(o_lat, o_lon, d_lat, d_lon, retries=2):
    url = f"{OSRM_BASE}/route/v1/driving/{o_lon:.5f},{o_lat:.5f};{d_lon:.5f},{d_lat:.5f}?overview=false"
    for k in range(retries + 1):
        try:
            r = requests.get(url, timeout=15)
            if r.status_code == 200:
                d = r.json()
                if d.get("code") == "Ok" and d.get("routes"):
                    rt = d["routes"][0]
                    return float(rt["duration"]) / 60.0, float(rt["distance"]) / 1000.0
            time.sleep(0.5)
        except Exception:
            time.sleep(0.5)
    return None, None


def fit_cv(y, Xs):
    kf = KFold(n_splits=5, shuffle=True, random_state=SEED)
    out = {}
    for name, X in Xs.items():
        r2s, maes = [], []
        for tr, te in kf.split(X):
            mdl = Ridge(alpha=1.0, random_state=SEED)
            mdl.fit(X[tr], y[tr])
            pred = mdl.predict(X[te])
            r2s.append(r2_score(y[te], pred))
            maes.append(mean_absolute_error(y[te], pred))
        out[name] = {
            "r2_mean": float(np.mean(r2s)),
            "r2_sd": float(np.std(r2s)),
            "mae_mean": float(np.mean(maes)),
            "n_features": int(X.shape[1]),
        }
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--limit", type=int, default=0,
                    help="cap N munis for testing; 0 = all")
    args = ap.parse_args()

    t0 = time.perf_counter()
    log.info("==== 07d osrm real routes ====")
    log.info("ram_avail_gb=%.1f  cores=%d", psutil.virtual_memory().available / 1e9,
             psutil.cpu_count(logical=True))

    # 1. hubs com lat/lon
    hub = pl.read_parquet(HUB_FILE).filter(
        (pl.col("CNES").str.strip_chars() != "") &
        (pl.col("hub_categoria").is_in(list(HIGH_COMPLEX))) &
        (pl.col("hub_ativo_qualquer_mes"))
    ).select(["CNES", "codmun_6"]).unique()
    master = pl.read_parquet(MASTER_FILE).select(["CNES", "codmun_6_modal"])
    hub = hub.join(master, on="CNES", how="left").rename({"codmun_6_modal": "codmun_6_hosp"})
    hub = hub.with_columns(
        pl.coalesce(pl.col("codmun_6_hosp"), pl.col("codmun_6")).alias("codmun_6_loc"))
    cent = pl.read_parquet(CENT_FILE).select(["cod_mun_6", "lat", "lon"])
    hub_cent = hub.join(cent, left_on="codmun_6_loc", right_on="cod_mun_6", how="inner")
    hub_lat = hub_cent["lat"].to_numpy()
    hub_lon = hub_cent["lon"].to_numpy()
    log.info("n hubs com centroide: %d", len(hub_cent))

    # 2. munis com lat/lon (mesmo universo do divergence_panel)
    div = pl.read_parquet(DIV_FILE)
    munis = div.select(["codmun_6", "uf", "lat", "lon", "iso_km_hosp", "iso_emb_hosp"]).unique(subset=["codmun_6"])
    if args.limit > 0:
        munis = munis.sort("codmun_6").head(args.limit)
    n_mun = len(munis)
    log.info("n munis a rotear: %d", n_mun)

    # 3. nearest-hub index para cada muni
    mlat = munis["lat"].to_numpy()
    mlon = munis["lon"].to_numpy()
    km_min, nn_idx = haversine_nn(mlat, mlon, hub_lat, hub_lon)

    # 4. OSRM routing paralelo
    log.info("OSRM batch: %d queries, %d workers, %.2fs delay", n_mun, N_WORKERS, RATE_DELAY_S)
    out_min = np.full(n_mun, np.nan, dtype=np.float64)
    out_dist = np.full(n_mun, np.nan, dtype=np.float64)
    submitted = 0
    failed = 0
    t_route = time.perf_counter()

    def task(i):
        time.sleep(RATE_DELAY_S)
        d_idx = int(nn_idx[i])
        m, d = osrm_route(mlat[i], mlon[i], hub_lat[d_idx], hub_lon[d_idx])
        return i, m, d

    with ThreadPoolExecutor(max_workers=N_WORKERS) as ex:
        futs = {ex.submit(task, i): i for i in range(n_mun)}
        for j, fut in enumerate(as_completed(futs)):
            i, m, d = fut.result()
            if m is None:
                failed += 1
            else:
                out_min[i] = m
                out_dist[i] = d
            submitted += 1
            if submitted % 200 == 0:
                el = time.perf_counter() - t_route
                rate = submitted / el if el > 0 else 0
                eta = (n_mun - submitted) / rate if rate > 0 else float("inf")
                log.info("  %d/%d done  rate=%.1f q/s  eta=%.0fs  failed=%d",
                         submitted, n_mun, rate, eta, failed)
    log.info("OSRM done: %d/%d  failed=%d  elapsed=%.0fs",
             submitted - failed, n_mun, failed, time.perf_counter() - t_route)

    # 5. monta panel novo
    panel = munis.with_columns([
        pl.Series("travel_time_min_osrm", out_min),
        pl.Series("travel_dist_km_osrm", out_dist),
        pl.Series("osrm_failed", np.isnan(out_min)),
        pl.lit("osrm_real_demo_server").alias("travel_time_method"),
    ])
    # imputa fails com fallback haversine speed-adjusted
    panel = panel.with_columns(
        pl.when(pl.col("osrm_failed"))
        .then(pl.col("iso_km_hosp") * 1.35 / 45.0 * 60.0)
        .otherwise(pl.col("travel_time_min_osrm"))
        .alias("travel_time_min")
    )
    panel.write_parquet(OUT_PANEL, compression="snappy")
    log.info("panel writen: %s rows=%d", OUT_PANEL, panel.height)

    # 6. assemble model df + horse race
    mort = pl.read_parquet(INTER / "amenable_mortality.parquet").filter(
        (pl.col("year") >= 2015) & (pl.col("year") <= 2022)
    ).group_by("codmun_6").agg([
        pl.col("n_amenable").sum().alias("n_amenable_tot"),
        pl.col("pop").mean().alias("pop_mean"),
    ]).with_columns(
        (pl.col("n_amenable_tot") / pl.col("pop_mean") / 8.0 * 1e5).alias("rate_per100k")
    )
    pop = pl.read_parquet(INTER / "pop_municipal_2015_2025.parquet").filter(
        (pl.col("ano") >= 2015) & (pl.col("ano") <= 2022)
    ).with_columns(codmun_6=pl.col("cod_mun").str.slice(0, 6)).group_by("codmun_6").agg(
        pl.col("pop").mean().alias("pop_mean_v2")
    )
    pib = pl.read_parquet(INTER / "pib_municipal_2015_2023.parquet").filter(
        (pl.col("ano") >= 2015) & (pl.col("ano") <= 2022)
    ).with_columns(codmun_6=pl.col("cod_mun").str.slice(0, 6)).group_by("codmun_6").agg(
        pl.col("pib_corr").mean().alias("pib_mean")
    )

    model_df = panel.join(mort, on="codmun_6", how="left") \
        .join(pop, on="codmun_6", how="left") \
        .join(pib, on="codmun_6", how="left")
    model_df = model_df.with_columns([
        pl.coalesce("pop_mean", "pop_mean_v2").alias("pop_eff"),
    ]).filter(
        pl.col("rate_per100k").is_not_null()
        & pl.col("pop_eff").is_not_null() & (pl.col("pop_eff") > 0)
        & pl.col("pib_mean").is_not_null() & (pl.col("pib_mean") > 0)
    ).with_columns([
        pl.col("pop_eff").log().alias("pop_log"),
        pl.col("pib_mean").log().alias("pib_log"),
        pl.col("rate_per100k").clip(
            pl.col("rate_per100k").quantile(0.01),
            pl.col("rate_per100k").quantile(0.99),
        ).alias("y"),
    ])
    log.info("model_df rows=%d", model_df.height)

    y = model_df["y"].to_numpy()
    feat_pop = model_df["pop_log"].to_numpy().reshape(-1, 1)
    feat_pib = model_df["pib_log"].to_numpy().reshape(-1, 1)
    feat_km = model_df["iso_km_hosp"].to_numpy().reshape(-1, 1)
    feat_tt = model_df["travel_time_min"].to_numpy().reshape(-1, 1)
    feat_emb = model_df["iso_emb_hosp"].to_numpy().reshape(-1, 1)
    uf_dum = pl.DataFrame({"uf": model_df["uf"].to_list()}).to_dummies("uf").to_numpy().astype(np.float32)
    base = np.hstack([feat_pop, feat_pib, uf_dum])

    results = fit_cv(y, {
        "M_km_only": np.hstack([base, feat_km]),
        "M_travel_time_only": np.hstack([base, feat_tt]),
        "M_embedding_only": np.hstack([base, feat_emb]),
        "M_travel_time_plus_embedding": np.hstack([base, feat_tt, feat_emb]),
        "M_km_plus_travel_time": np.hstack([base, feat_km, feat_tt]),
    })

    emb_vs_tt = results["M_embedding_only"]["r2_mean"] - results["M_travel_time_only"]["r2_mean"]
    both_vs_tt = results["M_travel_time_plus_embedding"]["r2_mean"] - results["M_travel_time_only"]["r2_mean"]
    tt_vs_km = results["M_travel_time_only"]["r2_mean"] - results["M_km_only"]["r2_mean"]
    verdict = "embedding_beats_travel_time" if emb_vs_tt > 0 else "embedding_fails_travel_time"

    fig, ax = plt.subplots(figsize=(7.0, 4.0))
    names = ["KM only", "Real OSRM time", "Embedding only", "OSRM + emb"]
    vals = [results["M_km_only"]["r2_mean"], results["M_travel_time_only"]["r2_mean"],
            results["M_embedding_only"]["r2_mean"], results["M_travel_time_plus_embedding"]["r2_mean"]]
    sds = [results["M_km_only"]["r2_sd"], results["M_travel_time_only"]["r2_sd"],
           results["M_embedding_only"]["r2_sd"], results["M_travel_time_plus_embedding"]["r2_sd"]]
    ax.bar(names, vals, yerr=sds, color=["#666666", "#1b9e77", "#d95f02", "#7570b3"])
    ax.set_ylabel("Out-of-sample $R^2$")
    ax.set_title(f"Real OSRM driving time vs km vs embedding (n={model_df.height})")
    ax.tick_params(axis="x", rotation=15)
    plt.tight_layout()
    FIG_DIR.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUT_FIG)

    n_failed = int(panel["osrm_failed"].sum())
    tab = [
        "\\begin{table}[h!]",
        "\\centering",
        "\\caption{Out-of-sample horse race for amenable mortality, real OSRM driving times via the public router.project-osrm.org demo server (5-fold ridge CV, controls: pop log, GDP log, UF FE).}",
        "\\label{tab:osrm-vs-embedding}",
        "\\small",
        "\\begin{tabular}{lrr}",
        "\\toprule",
        "Model & Mean OOS $R^2$ & Mean MAE \\\\",
        "\\midrule",
        f"Kilometer only & {results['M_km_only']['r2_mean']:.3f} & {results['M_km_only']['mae_mean']:.2f} \\\\",
        f"Real OSRM driving time only & {results['M_travel_time_only']['r2_mean']:.3f} & {results['M_travel_time_only']['mae_mean']:.2f} \\\\",
        f"Embedding only & {results['M_embedding_only']['r2_mean']:.3f} & {results['M_embedding_only']['mae_mean']:.2f} \\\\",
        f"OSRM time + embedding & {results['M_travel_time_plus_embedding']['r2_mean']:.3f} & {results['M_travel_time_plus_embedding']['mae_mean']:.2f} \\\\",
        f"KM + OSRM time & {results['M_km_plus_travel_time']['r2_mean']:.3f} & {results['M_km_plus_travel_time']['mae_mean']:.2f} \\\\",
        "\\midrule",
        f"$\\Delta R^2$ embedding $-$ OSRM time & {emb_vs_tt:+.4f} & \\\\",
        f"$\\Delta R^2$ (OSRM + emb) $-$ OSRM time & {both_vs_tt:+.4f} & \\\\",
        f"$\\Delta R^2$ OSRM time $-$ km & {tt_vs_km:+.4f} & \\\\",
        "\\bottomrule",
        "\\end{tabular}",
        f"\\\\\\footnotesize Routed times: real OSRM for $n={n_mun-n_failed}$ munis; haversine fallback for $n={n_failed}$ failed queries.",
        "\\end{table}",
    ]
    OUT_TAB.write_text("\n".join(tab) + "\n")

    payload = {
        "status": "ok_real_osrm",
        "telemetry": {"hostname": "DarcioWork", "ram_gb_avail": psutil.virtual_memory().available / 1e9},
        "travel_time_method": "osrm_real_demo_server",
        "n_munis_routed_ok": int(n_mun - n_failed),
        "n_munis_routed_failed": int(n_failed),
        "elapsed_total_s": time.perf_counter() - t0,
        "models": results,
        "delta_r2_embedding_minus_travel_time": emb_vs_tt,
        "delta_r2_tt_plus_embedding_minus_travel_time": both_vs_tt,
        "delta_r2_travel_time_minus_km": tt_vs_km,
        "verdict": verdict,
    }
    OUT_JSON.write_text(json.dumps(payload, indent=2))
    log.info("verdict=%s  emb_vs_tt=%.4f  both_vs_tt=%.4f  tt_vs_km=%.4f",
             verdict, emb_vs_tt, both_vs_tt, tt_vs_km)
    log.info("done in %.0fs", time.perf_counter() - t0)


if __name__ == "__main__":
    main()
