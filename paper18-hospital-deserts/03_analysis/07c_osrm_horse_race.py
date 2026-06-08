#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import logging
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import polars as pl
from sklearn.linear_model import Ridge
from sklearn.metrics import mean_absolute_error, r2_score
from sklearn.model_selection import KFold

from _telemetry import StepTimer, runtime_header, write_json

ROOT = Path(__file__).resolve().parents[1]
INTER = ROOT / "02_data" / "intermediate"
LOG_DIR = ROOT / "04_logs"
FIG_DIR = ROOT / "04_figures"
TAB_DIR = ROOT / "01_manuscript" / "tables"

OUT_PANEL = INTER / "osrm_travel_time_panel.parquet"
OUT_JSON = LOG_DIR / "07c_osrm_vs_embedding.json"
OUT_LOG = LOG_DIR / "07c_osrm_horse_race.log"
OUT_FIG = FIG_DIR / "fig_osrm_vs_embedding.pdf"
OUT_TAB = TAB_DIR / "tab_osrm_vs_embedding.tex"
BLOCKED = LOG_DIR / "blocked_07c.md"
SEED = 42


def build_logger() -> logging.Logger:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        handlers=[logging.FileHandler(OUT_LOG, mode="w"), logging.StreamHandler(sys.stdout)],
    )
    return logging.getLogger("osrm_horse_race")


def fit_cv(y: np.ndarray, Xs: dict[str, np.ndarray]) -> dict[str, dict]:
    kf = KFold(n_splits=5, shuffle=True, random_state=SEED)
    out: dict[str, dict] = {}
    for name, X in Xs.items():
        r2s: list[float] = []
        maes: list[float] = []
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


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    log = build_logger()
    header = runtime_header(ROOT, seeds=[SEED])
    log.info("==== begin 07c_osrm_horse_race ====")
    log.info("telemetry=%s", json.dumps(header, ensure_ascii=True))
    if OUT_PANEL.exists() and OUT_JSON.exists() and not args.force:
        log.info("outputs already exist; use --force to rebuild")
        write_json(OUT_JSON, {"status": "skipped_existing", "telemetry": header})
        return

    timer = StepTimer(log)
    div = pl.read_parquet(INTER / "divergence_panel.parquet")
    panel = div.select(["codmun_6", "uf", "iso_km_hosp", "iso_emb_hosp"]).with_columns(
        [
            # Fallback because OSRM server, local OSM extract, and osmnx are unavailable here.
            (pl.col("iso_km_hosp") * 1.35 / 45.0 * 60.0).alias("travel_time_min_proxy"),
            pl.lit("speed_adjusted_haversine_fallback").alias("travel_time_method"),
        ]
    )
    panel.write_parquet(OUT_PANEL, compression="snappy")
    write_json(
        OUT_PANEL.with_suffix(".metadata.json"),
        {
            "telemetry": header,
            "rows": panel.height,
            "columns": panel.columns,
            "method_note": "OSRM self-host, local OSM extract, and osmnx were unavailable. Travel time is a fallback proxy: 1.35 x haversine km at 45 km/h.",
            "peak_rss_gb": timer.peak_rss_gb,
        },
    )
    BLOCKED.write_text(
        "# Blocked step 07c: no local routing backend available\n\n"
        "OSRM self-host is unavailable in this workspace, `osmnx` is not installed, and\n"
        "network access is restricted, so no live OSM graph download is possible.\n"
        "The fallback in `07c_osrm_horse_race.py` uses a speed-adjusted haversine\n"
        "travel-time proxy instead of routed travel times.\n",
    )
    step_panel = timer.mark("build_travel_time_proxy")

    mort = pl.read_parquet(INTER / "amenable_mortality.parquet").filter(
        (pl.col("year") >= 2015) & (pl.col("year") <= 2022)
    ).group_by("codmun_6").agg(
        [
            pl.col("n_amenable").sum().alias("n_amenable_tot"),
            pl.col("pop").mean().alias("pop_mean"),
        ]
    ).with_columns(
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

    model_df = panel.join(mort, on="codmun_6", how="left").join(pop, on="codmun_6", how="left").join(pib, on="codmun_6", how="left")
    model_df = model_df.with_columns(
        [
            pl.coalesce("pop_mean", "pop_mean_v2").alias("pop_eff"),
        ]
    ).filter(
        pl.col("rate_per100k").is_not_null()
        & pl.col("pop_eff").is_not_null() & (pl.col("pop_eff") > 0)
        & pl.col("pib_mean").is_not_null() & (pl.col("pib_mean") > 0)
    ).with_columns(
        [
            pl.col("pop_eff").log().alias("pop_log"),
            pl.col("pib_mean").log().alias("pib_log"),
            pl.col("rate_per100k").clip(
                pl.col("rate_per100k").quantile(0.01),
                pl.col("rate_per100k").quantile(0.99),
            ).alias("y"),
        ]
    )
    step_modeldf = timer.mark("assemble_model_panel")

    y = model_df["y"].to_numpy()
    feat_pop = model_df["pop_log"].to_numpy().reshape(-1, 1)
    feat_pib = model_df["pib_log"].to_numpy().reshape(-1, 1)
    feat_km = model_df["iso_km_hosp"].to_numpy().reshape(-1, 1)
    feat_tt = model_df["travel_time_min_proxy"].to_numpy().reshape(-1, 1)
    feat_emb = model_df["iso_emb_hosp"].to_numpy().reshape(-1, 1)
    uf_dum = pl.DataFrame({"uf": model_df["uf"].to_list()}).to_dummies("uf").to_numpy().astype(np.float32)
    base = np.hstack([feat_pop, feat_pib, uf_dum])

    results = fit_cv(
        y,
        {
            "M_km_only": np.hstack([base, feat_km]),
            "M_travel_time_only": np.hstack([base, feat_tt]),
            "M_embedding_only": np.hstack([base, feat_emb]),
            "M_travel_time_plus_embedding": np.hstack([base, feat_tt, feat_emb]),
        },
    )
    step_fit = timer.mark("fit_cv_models")

    emb_vs_tt = results["M_embedding_only"]["r2_mean"] - results["M_travel_time_only"]["r2_mean"]
    both_vs_tt = results["M_travel_time_plus_embedding"]["r2_mean"] - results["M_travel_time_only"]["r2_mean"]
    verdict = "embedding_beats_travel_time" if emb_vs_tt > 0 else "embedding_fails_travel_time"

    fig, ax = plt.subplots(figsize=(6.4, 4.0))
    names = ["KM only", "Travel time only", "Embedding only", "Travel time + embedding"]
    vals = [
        results["M_km_only"]["r2_mean"],
        results["M_travel_time_only"]["r2_mean"],
        results["M_embedding_only"]["r2_mean"],
        results["M_travel_time_plus_embedding"]["r2_mean"],
    ]
    ax.bar(names, vals, color=["#666666", "#1b9e77", "#d95f02", "#7570b3"])
    ax.set_ylabel("Out-of-sample R^2")
    ax.set_title("Fallback travel-time proxy vs embedding")
    ax.tick_params(axis="x", rotation=15)
    plt.tight_layout()
    FIG_DIR.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUT_FIG)

    tab = [
        "\\begin{table}[h!]",
        "\\centering",
        "\\caption{Out-of-sample horse race between kilometer distance, fallback travel-time proxy, and the embedding. CV scheme matches the current implementation of `07_evaluate_embeddings.py` (ridge regression with 5-fold shuffled KFold).}",
        "\\label{tab:osrm-vs-embedding}",
        "\\small",
        "\\begin{tabular}{lrr}",
        "\\toprule",
        "Model & Mean OOS $R^2$ & Mean MAE \\\\",
        "\\midrule",
        f"Kilometer only & {results['M_km_only']['r2_mean']:.3f} & {results['M_km_only']['mae_mean']:.2f} \\\\",
        f"Travel time only & {results['M_travel_time_only']['r2_mean']:.3f} & {results['M_travel_time_only']['mae_mean']:.2f} \\\\",
        f"Embedding only & {results['M_embedding_only']['r2_mean']:.3f} & {results['M_embedding_only']['mae_mean']:.2f} \\\\",
        f"Travel time + embedding & {results['M_travel_time_plus_embedding']['r2_mean']:.3f} & {results['M_travel_time_plus_embedding']['mae_mean']:.2f} \\\\",
        "\\midrule",
        f"$\\Delta R^2$ embedding minus travel time & {emb_vs_tt:.4f} & \\\\",
        f"$\\Delta R^2$ (travel time + embedding) minus travel time & {both_vs_tt:.4f} & \\\\",
        "\\bottomrule",
        "\\end{tabular}",
        "\\end{table}",
    ]
    OUT_TAB.write_text("\n".join(tab) + "\n")

    payload = {
        "status": "ok_with_fallback",
        "telemetry": header,
        "steps": [step_panel, step_modeldf, step_fit],
        "travel_time_method": "speed_adjusted_haversine_fallback",
        "models": results,
        "delta_r2_embedding_minus_travel_time": emb_vs_tt,
        "delta_r2_tt_plus_embedding_minus_travel_time": both_vs_tt,
        "verdict": verdict,
    }
    write_json(OUT_JSON, payload)
    log.info("verdict=%s", verdict)


if __name__ == "__main__":
    main()
