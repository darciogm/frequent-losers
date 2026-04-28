"""
09_divergence_regression.py

Testa especificações que faltaram em 07/07b:
- |divergence|  → magnitude do desalinhamento mapa-vs-realidade
- divergence assimétrico (pos vs neg como features separadas)
- interação divergence × pop (efeito heterogêneo por tamanho do município)

Hipóteses:
H1: |divergence| > 0 prediz mortalidade evitável incremental sobre km e
    controles, porque ambos os extremos sinalizam sistema mal calibrado.
H2: divergence positiva (hospital evitado) tem efeito maior que negativa
    (km mente mas embedding revela conexão real).

Modelos (Ridge, 5-fold CV, mesma amostra do 07b):
  M0:    pop_log + pib_log + UF_FE
  M_km:  M0 + iso_km_z
  M_div: M0 + |div_z|
  M_split: M0 + div_pos + div_neg                (como features separadas)
  M_full: M0 + iso_km_z + |div_z|

Outputs:
- 04_logs/09_metrics.json
"""

from __future__ import annotations

import json
import logging
import sys
import time
from pathlib import Path

import numpy as np
import polars as pl
import psutil
from sklearn.linear_model import Ridge
from sklearn.metrics import mean_absolute_error, r2_score
from sklearn.model_selection import KFold

ROOT = Path(__file__).resolve().parents[1]
INTER = ROOT / "02_data" / "intermediate"
LOG = ROOT / "04_logs"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "09_divergence_regression.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("div_reg")

DIV_FILE = INTER / "divergence_panel.parquet"
MORT_FILE = INTER / "amenable_mortality.parquet"
POP_FILE = INTER / "pop_municipal_2015_2025.parquet"
PIB_FILE = INTER / "pib_municipal_2015_2023.parquet"

POP_MIN = 10_000
SEED = 42
N_SPLITS = 5


def main():
    t0 = time.perf_counter()
    log.info("==== begin divergence regression ====")
    log.info("RAM avail=%.1fGB  pop_min=%d", psutil.virtual_memory().available / 1e9, POP_MIN)

    div = pl.read_parquet(DIV_FILE)
    mort = pl.read_parquet(MORT_FILE).filter(
        (pl.col("year") >= 2010) & (pl.col("year") <= 2023)
    ).group_by("codmun_6").agg([
        pl.col("n_amenable").sum().alias("n_amenable_tot"),
        pl.col("pop").mean().alias("pop_mean"),
    ]).with_columns(
        rate_per100k=(pl.col("n_amenable_tot") / pl.col("pop_mean") / 14 * 1e5)
    ).select(["codmun_6", "rate_per100k", "pop_mean"])

    pop = pl.read_parquet(POP_FILE).filter(
        (pl.col("ano") >= 2010) & (pl.col("ano") <= 2023)
    ).with_columns(codmun_6=pl.col("cod_mun").str.slice(0, 6)) \
     .group_by("codmun_6").agg(pop_mean_v2=pl.col("pop").mean())

    pib = pl.read_parquet(PIB_FILE).filter(
        (pl.col("ano") >= 2010) & (pl.col("ano") <= 2023)
    ).with_columns(codmun_6=pl.col("cod_mun").str.slice(0, 6)) \
     .group_by("codmun_6").agg(pib_mean=pl.col("pib_corr").mean())

    panel = div.join(mort, on="codmun_6", how="left") \
               .join(pop, on="codmun_6", how="left") \
               .join(pib, on="codmun_6", how="left") \
               .with_columns(pop_eff=pl.coalesce("pop_mean", "pop_mean_v2")) \
               .filter(
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
                   pl.col("divergence_z").abs().alias("div_abs"),
                   pl.col("divergence_z").clip(0, None).alias("div_pos"),
                   (-pl.col("divergence_z")).clip(0, None).alias("div_neg"),
               ])

    log.info("panel: %d obs", len(panel))

    y = panel["y"].to_numpy()
    pop_log = panel["pop_log"].to_numpy().reshape(-1, 1)
    pib_log = panel["pib_log"].to_numpy().reshape(-1, 1)
    iso_km_z = panel["iso_km_z"].to_numpy().reshape(-1, 1)
    div_abs = panel["div_abs"].to_numpy().reshape(-1, 1)
    div_pos = panel["div_pos"].to_numpy().reshape(-1, 1)
    div_neg = panel["div_neg"].to_numpy().reshape(-1, 1)
    uf_dum = pl.DataFrame({"uf": panel["uf"].to_list()}).to_dummies("uf").to_numpy().astype(np.float32)

    base = np.hstack([pop_log, pib_log, uf_dum])
    Xs = {
        "M0_controls":          base,
        "M_km":                 np.hstack([base, iso_km_z]),
        "M_div_abs":            np.hstack([base, div_abs]),
        "M_div_split":          np.hstack([base, div_pos, div_neg]),
        "M_km_plus_div_abs":    np.hstack([base, iso_km_z, div_abs]),
        "M_km_plus_div_split":  np.hstack([base, iso_km_z, div_pos, div_neg]),
    }

    kf = KFold(n_splits=N_SPLITS, shuffle=True, random_state=SEED)
    results = {}
    coef_summary = {}
    for name, X in Xs.items():
        r2s, maes = [], []
        coefs = []
        for tr, te in kf.split(X):
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
        if X.shape[1] > base.shape[1]:
            extra = coefs and np.array(coefs)[:, base.shape[1]:]
            coef_summary[name] = {
                "extra_terms_mean": np.array(coefs)[:, base.shape[1]:].mean(axis=0).tolist(),
                "extra_terms_sd":   np.array(coefs)[:, base.shape[1]:].std(axis=0).tolist(),
            }
        log.info("%s: R²=%.3f±%.3f  MAE=%.1f", name, results[name]["r2_mean"],
                 results[name]["r2_sd"], results[name]["mae_mean"])

    log.info("coef summary (extra terms):")
    log.info(json.dumps(coef_summary, indent=2))

    delta_div_over_km = results["M_km_plus_div_abs"]["r2_mean"] - results["M_km"]["r2_mean"]
    delta_split_over_km = results["M_km_plus_div_split"]["r2_mean"] - results["M_km"]["r2_mean"]
    log.info("ΔR² div_abs over km        = %+.4f", delta_div_over_km)
    log.info("ΔR² div_split over km      = %+.4f", delta_split_over_km)

    if delta_split_over_km >= 0.05:
        verdict = "GO_STRONG"
    elif delta_split_over_km >= 0.02:
        verdict = "GO_MARGINAL"
    elif delta_split_over_km >= 0.005:
        verdict = "WEAK_BUT_PRESENT"
    else:
        verdict = "NO_GO_RECONSIDER"
    log.info(">>> VERDICT: %s", verdict)

    metrics = {
        "models": results,
        "coef_summary": coef_summary,
        "delta_r2_div_abs_over_km": delta_div_over_km,
        "delta_r2_div_split_over_km": delta_split_over_km,
        "verdict": verdict,
        "n_obs": int(len(y)),
        "pop_min": POP_MIN,
        "n_splits": N_SPLITS,
        "seed": SEED,
    }
    (LOG / "09_metrics.json").write_text(json.dumps(metrics, indent=2))

    log.info("==== done ==== elapsed=%.1fs RSS=%.2fGB",
             time.perf_counter() - t0,
             psutil.Process().memory_info().rss / 1e9)


if __name__ == "__main__":
    main()
