#!/usr/bin/env python3
"""
25_cartel_by_cartel_auc.py — Per-cartel AUCs + rolling-window comparison

Purpose
-------
Address referee comment M1: the headline AUC of 0.75 may be driven by a single
cartel (medicamentos). This script:
1. Joins auction-level cartel flags back to cade_ground_truth.parquet to recover
   which specific cartel (processo/setor) each auction belongs to.
2. Computes screen AUCs for each cartel separately.
3. Repeats the analysis using rolling-window edges (scripts 20-21) to address
   M4 (temporal contamination).
4. Reports leave-one-out AUCs for completeness.

Output
------
- 02_data/intermediate/cartel_by_cartel_auc.txt   (human-readable)
- 02_data/intermediate/cartel_by_cartel_auc.csv   (machine-readable)
"""
from __future__ import annotations

import time
from math import sqrt
from pathlib import Path

import numpy as np
import polars as pl
from scipy import stats

BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")
FINAL = BASE / "02_data" / "final"
FIRMS = BASE / "02_data" / "firms"
INTER = BASE / "02_data" / "intermediate"
ROLLING = FIRMS / "rolling_edges"

PAIRS_PREGAO   = FINAL / "df_pregao_with_cartel_flags.parquet"
SCREENS_PREGAO = FINAL / "auction_screens_pregao.parquet"
WF_EDGES       = FIRMS / "firm_firm_worker_flow_edges.parquet"
COB_EDGES      = FIRMS / "firm_firm_cobidding_edges.parquet"
GROUND_TRUTH   = FIRMS / "cade_ground_truth.parquet"

OUT_REPORT = INTER / "cartel_by_cartel_auc.txt"
OUT_CSV    = INTER / "cartel_by_cartel_auc.csv"

MV_BANDWIDTH = 0.10

# ── AUC computation ─────────────────────────────────────────────────────────

def compute_auc(treat_vals: np.ndarray, control_vals: np.ndarray,
                direction: str) -> dict:
    t = treat_vals[~np.isnan(treat_vals)]
    c = control_vals[~np.isnan(control_vals)]
    n_t, n_c = len(t), len(c)
    if n_t < 2 or n_c < 2:
        return dict(n_t=n_t, n_c=n_c, auc=np.nan)

    all_scores = np.concatenate([t, c])
    labels = np.concatenate([np.ones(n_t), np.zeros(n_c)])
    order = np.argsort(all_scores, kind="mergesort")
    sorted_scores = all_scores[order]
    ranks = np.empty_like(order, dtype=float)
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
    auc_gt = u1 / (n_t * n_c)
    auc = auc_gt if direction == "higher_is_cartel" else 1.0 - auc_gt
    return dict(n_t=n_t, n_c=n_c, auc=float(auc))


SCREEN_DIRS = {
    "cv_bid": "lower_is_cartel",
    "spread": "lower_is_cartel",
    "n_firms": "lower_is_cartel",
    "shared_workers": "higher_is_cartel",
    "jaccard": "higher_is_cartel",
    "n_cobids": "higher_is_cartel",
}


# ── Build sample with per-cartel identity ───────────────────────────────────

def build_sample_with_cartel_id() -> pl.DataFrame:
    """Build unified close-margin sample with cartel processo/setor attached."""
    print("Loading pair file...", flush=True)
    pairs = pl.read_parquet(PAIRS_PREGAO)
    pairs = pairs.filter(pl.col("MV").abs() < MV_BANDWIDTH)

    pairs = pairs.with_columns(
        pl.col("códigofornecedor").cast(pl.Utf8).str.zfill(14)
        .str.slice(0, 8).alias("cnpj_raiz_n")
    )

    for c in ("has_active_cartel", "both_cartel_active"):
        if c not in pairs.columns:
            pairs = pairs.with_columns(pl.lit(0).cast(pl.Int8).alias(c))

    # Extract winners and losers
    winners = pairs.filter(pl.col("flagvencedor") == 1).select([
        "auction_item", "numerodaoc", "códigoitem", "year",
        pl.col("cnpj_raiz_n").alias("winner_cnpj"),
        "has_any_cartel_firm", "has_active_cartel",
        "both_cartel_firm", "both_cartel_active",
    ]).unique(subset=["auction_item"], keep="first")

    losers = pairs.filter(pl.col("flagvencedor") == 0).select([
        "auction_item",
        pl.col("cnpj_raiz_n").alias("loser_cnpj"),
    ]).unique(subset=["auction_item"], keep="first")

    auctions = winners.join(losers, on="auction_item", how="inner")
    print(f"  auction-level rows: {auctions.height:,}")

    # Undirected edge key
    auctions = auctions.with_columns([
        pl.when(pl.col("winner_cnpj") < pl.col("loser_cnpj"))
        .then(pl.col("winner_cnpj"))
        .otherwise(pl.col("loser_cnpj")).alias("cnpj_a"),
        pl.when(pl.col("winner_cnpj") < pl.col("loser_cnpj"))
        .then(pl.col("loser_cnpj"))
        .otherwise(pl.col("winner_cnpj")).alias("cnpj_b"),
    ])

    # ── Attach per-cartel identity ──────────────────────────────────────────
    gt = pl.read_parquet(GROUND_TRUTH).filter(
        pl.col("sp_relevant") == 1,
        pl.col("processo").is_not_null(),
        pl.col("cartel_start_year").is_not_null(),
    ).select(["cnpj_raiz", "processo", "setor", "cartel_start_year", "cartel_end_year"])

    # Expand ground truth to firm × year
    gt_expanded = (
        gt.with_columns(
            pl.int_ranges(pl.col("cartel_start_year"),
                          pl.col("cartel_end_year") + 1).alias("years")
        )
        .explode("years")
        .rename({"years": "year"})
        .with_columns(pl.col("year").cast(pl.Int32))
    )

    # Match winner to cartel
    winner_cartel = auctions.join(
        gt_expanded.select([
            pl.col("cnpj_raiz").alias("winner_cnpj"),
            pl.col("year"),
            pl.col("processo").alias("winner_processo"),
            pl.col("setor").alias("winner_setor"),
        ]),
        on=["winner_cnpj", "year"], how="left",
    )

    # Match loser to cartel
    winner_cartel = winner_cartel.join(
        gt_expanded.select([
            pl.col("cnpj_raiz").alias("loser_cnpj"),
            pl.col("year"),
            pl.col("processo").alias("loser_processo"),
            pl.col("setor").alias("loser_setor"),
        ]),
        on=["loser_cnpj", "year"], how="left",
    )

    # Derive auction-level cartel identity: take whichever is non-null
    # (prefer winner, fall back to loser)
    auctions = winner_cartel.with_columns([
        pl.coalesce(["winner_processo", "loser_processo"]).alias("cartel_processo"),
        pl.coalesce(["winner_setor", "loser_setor"]).alias("cartel_setor"),
    ])

    # ── Attach classical screens ────────────────────────────────────────────
    screens = (
        pl.read_parquet(SCREENS_PREGAO)
        .with_columns(
            (pl.col("numerodaoc") + pl.lit("_") + pl.col("códigoitem"))
            .alias("auction_item")
        )
        .select(["auction_item", "cv_bid", "spread", "mv", "n_firms"])
    )
    auctions = auctions.join(screens, on="auction_item", how="left")

    # ── Attach full-panel worker-flow edges ─────────────────────────────────
    wf = pl.read_parquet(WF_EDGES).select(["cnpj_a", "cnpj_b", "shared_workers", "jaccard"])
    auctions = auctions.join(wf, on=["cnpj_a", "cnpj_b"], how="left").with_columns([
        pl.col("shared_workers").fill_null(0),
        pl.col("jaccard").fill_null(0.0),
    ])

    # ── Attach co-bidding edges ─────────────────────────────────────────────
    if COB_EDGES.exists():
        cob = pl.read_parquet(COB_EDGES)
        for cand in ("n_cobids", "cobidding_count", "n_shared_auctions", "weight"):
            if cand in cob.columns:
                auctions = auctions.join(
                    cob.select(["cnpj_a", "cnpj_b", pl.col(cand).alias("n_cobids")]),
                    on=["cnpj_a", "cnpj_b"], how="left"
                ).with_columns(pl.col("n_cobids").fill_null(0))
                break
        else:
            auctions = auctions.with_columns(pl.lit(0).alias("n_cobids"))
    else:
        auctions = auctions.with_columns(pl.lit(0).alias("n_cobids"))

    for c in ("has_active_cartel", "has_any_cartel_firm",
              "both_cartel_firm", "both_cartel_active"):
        auctions = auctions.with_columns(pl.col(c).cast(pl.Int8))

    return auctions


def attach_rolling_edges(auctions: pl.DataFrame) -> pl.DataFrame:
    """Replace full-panel worker-flow edges with year-specific rolling edges."""
    # Drop full-panel columns
    auctions = auctions.drop(["shared_workers", "jaccard"])

    # Load all rolling edges and stack
    rolling_parts = []
    for year in range(2010, 2018):
        fp = ROLLING / f"edges_y{year}.parquet"
        if fp.exists():
            part = pl.read_parquet(fp).select([
                "cnpj_a", "cnpj_b", "shared_workers", "jaccard",
            ]).with_columns(pl.lit(year).alias("edge_year").cast(pl.Int32))
            rolling_parts.append(part)

    if not rolling_parts:
        print("  ⚠️ No rolling edge files found!")
        return auctions.with_columns([
            pl.lit(0).alias("shared_workers"),
            pl.lit(0.0).alias("jaccard"),
        ])

    rolling = pl.concat(rolling_parts)
    print(f"  rolling edges loaded: {rolling.height:,} rows across "
          f"{len(rolling_parts)} years")

    # Join on (cnpj_a, cnpj_b, year = edge_year)
    auctions = auctions.join(
        rolling.rename({"edge_year": "year"}),
        on=["cnpj_a", "cnpj_b", "year"], how="left"
    ).with_columns([
        pl.col("shared_workers").fill_null(0),
        pl.col("jaccard").fill_null(0.0),
    ])

    return auctions


# ── Main ────────────────────────────────────────────────────────────────────

def main() -> None:
    t0 = time.time()
    INTER.mkdir(parents=True, exist_ok=True)

    auctions = build_sample_with_cartel_id()
    control = auctions.filter(pl.col("has_any_cartel_firm") == 0)
    treat_all = auctions.filter(pl.col("has_active_cartel") == 1)

    # Diagnostics
    cartel_counts = (
        treat_all
        .filter(pl.col("cartel_setor").is_not_null())
        .group_by("cartel_setor")
        .agg(pl.len().alias("n_auctions"))
        .sort("n_auctions", descending=True)
    )

    all_rows = []

    with open(OUT_REPORT, "w") as f:
        f.write(f"Cartel-by-Cartel AUC Analysis\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"MV bandwidth: {MV_BANDWIDTH}\n")
        f.write("=" * 70 + "\n\n")

        f.write("CARTEL-ACTIVE AUCTION COUNTS\n")
        f.write("-" * 40 + "\n")
        f.write(f"Total cartel-active: {treat_all.height:,}\n")
        unmatched = treat_all.filter(pl.col("cartel_setor").is_null()).height
        f.write(f"  with cartel ID:    {treat_all.height - unmatched:,}\n")
        f.write(f"  unmatched:         {unmatched:,}\n\n")

        for row in cartel_counts.iter_rows(named=True):
            f.write(f"  {row['cartel_setor']:30s}  N = {row['n_auctions']:>5,}\n")
        f.write("\n")

        # ── A. Per-cartel AUCs (full-panel edges) ───────────────────────────

        f.write("=" * 70 + "\n")
        f.write("A. PER-CARTEL AUCs (full-panel worker-flow edges)\n")
        f.write("=" * 70 + "\n\n")

        screens_report = ["cv_bid", "n_firms", "shared_workers", "jaccard"]

        f.write(f"{'Cartel':30s} {'N_t':>6s}  "
                + "  ".join(f"{s:>8s}" for s in screens_report) + "\n")
        f.write("-" * 70 + "\n")

        for row in cartel_counts.iter_rows(named=True):
            setor = row["cartel_setor"]
            cartel_treat = treat_all.filter(pl.col("cartel_setor") == setor)
            line = f"{setor:30s} {cartel_treat.height:>6,}  "
            for screen in screens_report:
                direction = SCREEN_DIRS[screen]
                r = compute_auc(
                    cartel_treat[screen].to_numpy().astype(float),
                    control[screen].to_numpy().astype(float),
                    direction,
                )
                line += f"{r['auc']:>8.3f}  "
                all_rows.append(dict(
                    edge_type="full_panel", analysis="per_cartel",
                    cartel=setor, screen=screen, direction=direction,
                    n_t=r["n_t"], n_c=r["n_c"], auc=r["auc"],
                ))
            f.write(line + "\n")

        # Add "All" row
        line = f"{'ALL':30s} {treat_all.height:>6,}  "
        for screen in screens_report:
            direction = SCREEN_DIRS[screen]
            r = compute_auc(
                treat_all[screen].to_numpy().astype(float),
                control[screen].to_numpy().astype(float),
                direction,
            )
            line += f"{r['auc']:>8.3f}  "
            all_rows.append(dict(
                edge_type="full_panel", analysis="all",
                cartel="ALL", screen=screen, direction=direction,
                n_t=r["n_t"], n_c=r["n_c"], auc=r["auc"],
            ))
        f.write(line + "\n\n")

        # ── B. Leave-one-out AUCs (full-panel) ──────────────────────────────

        f.write("=" * 70 + "\n")
        f.write("B. LEAVE-ONE-OUT AUCs (full-panel)\n")
        f.write("=" * 70 + "\n\n")

        f.write(f"{'Dropped cartel':30s} {'N_t':>6s}  "
                + "  ".join(f"{s:>8s}" for s in screens_report) + "\n")
        f.write("-" * 70 + "\n")

        for row in cartel_counts.iter_rows(named=True):
            setor = row["cartel_setor"]
            loo_treat = treat_all.filter(pl.col("cartel_setor") != setor)
            line = f"drop {setor:26s} {loo_treat.height:>6,}  "
            for screen in screens_report:
                direction = SCREEN_DIRS[screen]
                r = compute_auc(
                    loo_treat[screen].to_numpy().astype(float),
                    control[screen].to_numpy().astype(float),
                    direction,
                )
                line += f"{r['auc']:>8.3f}  "
                all_rows.append(dict(
                    edge_type="full_panel", analysis="leave_one_out",
                    cartel=f"drop_{setor}", screen=screen, direction=direction,
                    n_t=r["n_t"], n_c=r["n_c"], auc=r["auc"],
                ))
            f.write(line + "\n")
        f.write("\n")

        # ── C. Per-cartel AUCs (rolling-window edges) ───────────────────────

        f.write("=" * 70 + "\n")
        f.write("C. PER-CARTEL AUCs (rolling-window edges, [t-3, t-1])\n")
        f.write("=" * 70 + "\n\n")

        auctions_rolling = attach_rolling_edges(auctions.clone())
        control_r = auctions_rolling.filter(pl.col("has_any_cartel_firm") == 0)
        treat_all_r = auctions_rolling.filter(pl.col("has_active_cartel") == 1)

        # Filter to years with rolling edges (2010-2017)
        treat_all_r = treat_all_r.filter(pl.col("year").is_between(2010, 2017))
        control_r = control_r.filter(pl.col("year").is_between(2010, 2017))
        f.write(f"(Restricted to auction years 2010-2017 where rolling edges exist)\n\n")

        f.write(f"{'Cartel':30s} {'N_t':>6s}  "
                + "  ".join(f"{s:>8s}" for s in screens_report) + "\n")
        f.write("-" * 70 + "\n")

        cartel_counts_r = (
            treat_all_r
            .filter(pl.col("cartel_setor").is_not_null())
            .group_by("cartel_setor")
            .agg(pl.len().alias("n_auctions"))
            .sort("n_auctions", descending=True)
        )

        for row_r in cartel_counts_r.iter_rows(named=True):
            setor = row_r["cartel_setor"]
            cartel_treat_r = treat_all_r.filter(pl.col("cartel_setor") == setor)
            line = f"{setor:30s} {cartel_treat_r.height:>6,}  "
            for screen in screens_report:
                direction = SCREEN_DIRS[screen]
                r = compute_auc(
                    cartel_treat_r[screen].to_numpy().astype(float),
                    control_r[screen].to_numpy().astype(float),
                    direction,
                )
                line += f"{r['auc']:>8.3f}  "
                all_rows.append(dict(
                    edge_type="rolling", analysis="per_cartel",
                    cartel=setor, screen=screen, direction=direction,
                    n_t=r["n_t"], n_c=r["n_c"], auc=r["auc"],
                ))
            f.write(line + "\n")

        # All rolling
        line = f"{'ALL (rolling)':30s} {treat_all_r.height:>6,}  "
        for screen in screens_report:
            direction = SCREEN_DIRS[screen]
            r = compute_auc(
                treat_all_r[screen].to_numpy().astype(float),
                control_r[screen].to_numpy().astype(float),
                direction,
            )
            line += f"{r['auc']:>8.3f}  "
            all_rows.append(dict(
                edge_type="rolling", analysis="all",
                cartel="ALL_rolling", screen=screen, direction=direction,
                n_t=r["n_t"], n_c=r["n_c"], auc=r["auc"],
            ))
        f.write(line + "\n\n")

        # ── D. Leave-one-out with rolling edges ─────────────────────────────

        f.write("=" * 70 + "\n")
        f.write("D. LEAVE-ONE-OUT AUCs (rolling-window)\n")
        f.write("=" * 70 + "\n\n")

        f.write(f"{'Dropped cartel':30s} {'N_t':>6s}  "
                + "  ".join(f"{s:>8s}" for s in screens_report) + "\n")
        f.write("-" * 70 + "\n")

        for row_r in cartel_counts_r.iter_rows(named=True):
            setor = row_r["cartel_setor"]
            loo_r = treat_all_r.filter(pl.col("cartel_setor") != setor)
            line = f"drop {setor:26s} {loo_r.height:>6,}  "
            for screen in screens_report:
                direction = SCREEN_DIRS[screen]
                r = compute_auc(
                    loo_r[screen].to_numpy().astype(float),
                    control_r[screen].to_numpy().astype(float),
                    direction,
                )
                line += f"{r['auc']:>8.3f}  "
                all_rows.append(dict(
                    edge_type="rolling", analysis="leave_one_out",
                    cartel=f"drop_{setor}", screen=screen, direction=direction,
                    n_t=r["n_t"], n_c=r["n_c"], auc=r["auc"],
                ))
            f.write(line + "\n")

    print(f"\n[written] {OUT_REPORT}")

    # Write CSV
    import csv
    with open(OUT_CSV, "w", newline="") as cf:
        if all_rows:
            w = csv.DictWriter(cf, fieldnames=list(all_rows[0].keys()))
            w.writeheader()
            w.writerows(all_rows)
    print(f"[written] {OUT_CSV}")

    print(f"\nTotal time: {time.time() - t0:.1f}s")
    print("\n--- report preview ---")
    print(OUT_REPORT.read_text())


if __name__ == "__main__":
    main()
