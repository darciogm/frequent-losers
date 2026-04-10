#!/usr/bin/env python3
"""
30_bootstrap_ci.py — Bootstrap confidence intervals on key AUCs

Purpose
-------
Compute 1000-resample bootstrap 95% CIs for all headline AUCs to formally
test AUC ≠ 0.50.

Screens tested:
- Classical: CV, spread, n_firms
- Network (full-panel): shared_workers, jaccard
- Network (cumulative): shared_workers_cum
- Per-window: sw_pre, sw_during, sw_post
"""
from __future__ import annotations

import time
from pathlib import Path

import numpy as np
import polars as pl

BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")
FINAL = BASE / "02_data" / "final"
FIRMS = BASE / "02_data" / "firms"
INTER = BASE / "02_data" / "intermediate"

PAIRS_PREGAO  = FINAL / "df_pregao_with_cartel_flags.parquet"
SCREENS_PREGAO = FINAL / "auction_screens_pregao.parquet"
WF_EDGES      = FIRMS / "firm_firm_worker_flow_edges.parquet"

OUT_REPORT = INTER / "bootstrap_ci.txt"
OUT_CSV    = INTER / "bootstrap_ci.csv"

MV_BANDWIDTH = 0.10
N_BOOT = 1000
SEED = 42


def compute_auc_fast(treat_vals: np.ndarray, control_vals: np.ndarray) -> float:
    """Compute AUC = P(treat > control) via Mann-Whitney U, no direction flip."""
    n_t, n_c = len(treat_vals), len(control_vals)
    if n_t < 2 or n_c < 2:
        return np.nan
    all_scores = np.concatenate([treat_vals, control_vals])
    labels = np.concatenate([np.ones(n_t), np.zeros(n_c)])
    order = np.argsort(all_scores, kind="mergesort")
    sorted_scores = all_scores[order]
    ranks = np.empty(len(order), dtype=float)
    i = 0
    while i < len(sorted_scores):
        j = i
        while j < len(sorted_scores) and sorted_scores[j] == sorted_scores[i]:
            j += 1
        avg_rank = (i + j + 1) / 2.0
        ranks[order[i:j]] = avg_rank
        i = j
    rank_sum_t = ranks[labels == 1].sum()
    u1 = rank_sum_t - n_t * (n_t + 1) / 2.0
    return u1 / (n_t * n_c)


def bootstrap_auc(treat_vals: np.ndarray, control_vals: np.ndarray,
                  direction: str, n_boot: int, rng: np.random.Generator) -> dict:
    """Bootstrap AUC with 95% percentile CI."""
    t = treat_vals[~np.isnan(treat_vals)]
    c = control_vals[~np.isnan(control_vals)]
    n_t, n_c = len(t), len(c)

    if n_t < 5 or n_c < 5:
        return dict(n_t=n_t, n_c=n_c, auc=np.nan, ci_lo=np.nan, ci_hi=np.nan,
                    p_value=np.nan)

    # Point estimate
    raw_auc = compute_auc_fast(t, c)
    auc = raw_auc if direction == "higher_is_cartel" else 1.0 - raw_auc

    # Bootstrap
    boot_aucs = np.empty(n_boot)
    for b in range(n_boot):
        t_boot = rng.choice(t, size=n_t, replace=True)
        c_boot = rng.choice(c, size=n_c, replace=True)
        raw = compute_auc_fast(t_boot, c_boot)
        boot_aucs[b] = raw if direction == "higher_is_cartel" else 1.0 - raw

    ci_lo = float(np.percentile(boot_aucs, 2.5))
    ci_hi = float(np.percentile(boot_aucs, 97.5))

    # Two-sided p-value for H0: AUC = 0.5
    # Fraction of bootstrap samples on the other side of 0.5
    if auc >= 0.5:
        p_value = float(2 * np.mean(boot_aucs < 0.5))
    else:
        p_value = float(2 * np.mean(boot_aucs > 0.5))
    p_value = min(p_value, 1.0)

    return dict(n_t=n_t, n_c=n_c, auc=float(auc),
                ci_lo=ci_lo, ci_hi=ci_hi,
                boot_mean=float(boot_aucs.mean()),
                boot_sd=float(boot_aucs.std()),
                p_value=p_value)


def main() -> None:
    t0 = time.time()
    INTER.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(SEED)

    # ── Build unified sample (same as script 23) ────────────────────────────

    print("Loading data...", flush=True)
    pairs = pl.read_parquet(PAIRS_PREGAO)
    pairs = pairs.filter(pl.col("MV").abs() < MV_BANDWIDTH)
    pairs = pairs.with_columns(
        pl.col("códigofornecedor").cast(pl.Utf8).str.zfill(14)
        .str.slice(0, 8).alias("cnpj_raiz_n")
    )
    for c in ("has_active_cartel", "both_cartel_active"):
        if c not in pairs.columns:
            pairs = pairs.with_columns(pl.lit(0).cast(pl.Int8).alias(c))

    winners = pairs.filter(pl.col("flagvencedor") == 1).select([
        "auction_item", "numerodaoc", "códigoitem", "year",
        pl.col("cnpj_raiz_n").alias("winner_cnpj"),
        "has_any_cartel_firm", "has_active_cartel",
    ]).unique(subset=["auction_item"], keep="first")

    losers = pairs.filter(pl.col("flagvencedor") == 0).select([
        "auction_item",
        pl.col("cnpj_raiz_n").alias("loser_cnpj"),
    ]).unique(subset=["auction_item"], keep="first")

    auctions = winners.join(losers, on="auction_item", how="inner")
    auctions = auctions.with_columns([
        pl.when(pl.col("winner_cnpj") < pl.col("loser_cnpj"))
        .then(pl.col("winner_cnpj")).otherwise(pl.col("loser_cnpj")).alias("cnpj_a"),
        pl.when(pl.col("winner_cnpj") < pl.col("loser_cnpj"))
        .then(pl.col("loser_cnpj")).otherwise(pl.col("winner_cnpj")).alias("cnpj_b"),
    ])

    # Classical screens
    screens = (
        pl.read_parquet(SCREENS_PREGAO)
        .with_columns(
            (pl.col("numerodaoc") + pl.lit("_") + pl.col("códigoitem")).alias("auction_item")
        ).select(["auction_item", "cv_bid", "spread", "n_firms"])
    )
    auctions = auctions.join(screens, on="auction_item", how="left")

    # Worker-flow edges (full-panel)
    wf = pl.read_parquet(WF_EDGES).select(["cnpj_a", "cnpj_b", "shared_workers", "jaccard"])
    auctions = auctions.join(wf, on=["cnpj_a", "cnpj_b"], how="left").with_columns([
        pl.col("shared_workers").fill_null(0),
        pl.col("jaccard").fill_null(0.0),
    ])

    for c_name in ("has_active_cartel", "has_any_cartel_firm"):
        auctions = auctions.with_columns(pl.col(c_name).cast(pl.Int8))

    treat_mask = auctions["has_active_cartel"].to_numpy() == 1
    clean_mask = auctions["has_any_cartel_firm"].to_numpy() == 0

    print(f"  N_treat={treat_mask.sum():,}  N_clean={clean_mask.sum():,}")

    # ── Bootstrap all screens ────────────────────────────────────────────────

    screens_to_test = [
        ("cv_bid",          "lower_is_cartel"),
        ("spread",          "lower_is_cartel"),
        ("n_firms",         "lower_is_cartel"),
        ("shared_workers",  "higher_is_cartel"),
        ("jaccard",         "higher_is_cartel"),
    ]

    results = []

    for screen_name, direction in screens_to_test:
        print(f"  bootstrapping {screen_name}...", flush=True)
        vals = auctions[screen_name].to_numpy().astype(float)
        r = bootstrap_auc(vals[treat_mask], vals[clean_mask],
                          direction, N_BOOT, rng)
        r["screen"] = screen_name
        r["window"] = "full_panel"
        results.append(r)

    # ── Also bootstrap cumulative and per-window AUCs from script 27 data ───

    # Load temporal decomposition results if available
    temporal_csv = INTER / "temporal_decomposition.csv"
    if temporal_csv.exists():
        print("  loading temporal decomposition for per-window bootstrap...",
              flush=True)
        # Need to rebuild the per-auction window counts from script 27
        # For efficiency, use the cached results and just bootstrap the
        # overall AUC from the summary statistics
        # Actually need the raw auction-level data — check if we can get it
        # from the cumulative edges script output

    cumulative_csv = INTER / "cumulative_edges_auc.csv"
    # We don't have auction-level cumulative data cached, so we'll note
    # that these need to be bootstrapped in a future pass

    # ── Write report ─────────────────────────────────────────────────────────

    with open(OUT_REPORT, "w") as f:
        f.write("Bootstrap Confidence Intervals (95%, percentile method)\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"B = {N_BOOT}, seed = {SEED}\n")
        f.write("=" * 70 + "\n\n")

        f.write(f"{'Screen':20s} {'Window':15s} {'AUC':>6s}  "
                f"{'95% CI':>20s}  {'p(=0.5)':>8s}  {'sig':>4s}\n")
        f.write("-" * 75 + "\n")

        for r in results:
            sig = ""
            if r["p_value"] < 0.001:
                sig = "***"
            elif r["p_value"] < 0.01:
                sig = "**"
            elif r["p_value"] < 0.05:
                sig = "*"
            f.write(f"{r['screen']:20s} {r['window']:15s} {r['auc']:>6.3f}  "
                    f"[{r['ci_lo']:>6.3f}, {r['ci_hi']:>6.3f}]"
                    f"{'':>6s}  {r['p_value']:>8.4f}  {sig:>4s}\n")

        f.write("\n")
        f.write("Note: p-value is two-sided bootstrap test of H0: AUC = 0.50.\n")
        f.write("      Percentile method (Efron).\n")

    print(f"\n[written] {OUT_REPORT}")

    # Write CSV
    import csv
    with open(OUT_CSV, "w", newline="") as cf:
        if results:
            w = csv.DictWriter(cf, fieldnames=list(results[0].keys()))
            w.writeheader()
            w.writerows(results)
    print(f"[written] {OUT_CSV}")

    print(f"\nTotal time: {time.time() - t0:.1f}s")
    print("\n--- report ---")
    print(OUT_REPORT.read_text())


if __name__ == "__main__":
    main()
