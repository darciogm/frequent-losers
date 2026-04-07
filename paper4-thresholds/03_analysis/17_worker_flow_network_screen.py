#!/usr/bin/env python3
"""
17_worker_flow_network_screen.py — A.5 worker-flow network screen

Purpose
-------
Build a firm-firm network where edge weight = number of workers who have
been employed at both firms (over the 2009-2017 RAIS panel). Then test
whether cartel pair-matched auctions (winner + runner-up are both cartel
firms) are concentrated in more-connected firm pairs than control auctions.

Hypothesis
----------
Under collusion that requires cross-firm coordination, cartel firms are
more likely to share personnel — managers, salespeople, engineers — who
serve as informal communication channels. Worker-flow connectivity is a
proxy for this hidden coordination capacity.

This is a NOVEL screen, not in the existing detection literature.

Pipeline
--------
1. Load BEC firm universe (~38k cnpj_raiz)
2. From RAIS harmonized vinculos 2009-2017, build (pis × cnpj_raiz)
   long table — one row per worker per firm they ever worked at
3. Filter to PIS with at least 2 distinct BEC firms
4. Self-join on pis to generate firm-firm edges
5. Aggregate to (cnpj_a, cnpj_b) → shared_workers count
6. Load pregão close-bid pairs with cartel flags
7. For each (winner, runner-up) pair, look up edge weight
8. Compare distribution: cartel-active vs clean control
9. Two-sample t-test + AUC for cartel detection

Outputs
-------
  02_data/firms/firm_firm_worker_flow_edges.parquet
  02_data/intermediate/worker_flow_screen_results.txt
"""
from __future__ import annotations

import gc
import time
from pathlib import Path

import polars as pl

BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")
BEC_CNPJ_LIST = BASE / "02_data" / "bec_cnpj_list.parquet"
VINCULOS_DIR  = BASE / "RAIS" / "parquet" / "harmonized"
PAIRS_PATH    = BASE / "02_data" / "final" / "df_pregao_with_cartel_flags.parquet"
EDGES_OUT     = BASE / "02_data" / "firms" / "firm_firm_worker_flow_edges.parquet"
REPORT_OUT    = BASE / "02_data" / "intermediate" / "worker_flow_screen_results.txt"

YEARS = list(range(2009, 2018))


def load_bec_set() -> set[str]:
    print("Loading BEC firm universe...")
    df = pl.read_parquet(BEC_CNPJ_LIST)
    raiz = set(
        df.select(pl.col("cnpj_raiz").cast(pl.Utf8).str.zfill(8))["cnpj_raiz"]
        .unique().to_list()
    )
    raiz.discard("00000000")
    print(f"  {len(raiz):,} BEC cnpj_raiz")
    return raiz


def build_pis_firm_panel(bec_set: set[str]) -> pl.DataFrame:
    print("\nBuilding (pis × cnpj_raiz) long panel from harmonized RAIS...")
    frames = []
    for year in YEARS:
        fpath = VINCULOS_DIR / f"rais_vinculos_{year}.parquet"
        if not fpath.exists():
            continue
        print(f"  [{year}] scanning...", flush=True)
        df = (
            pl.scan_parquet(fpath)
            .filter(pl.col("cnpj_raiz").is_in(bec_set))
            .filter(pl.col("pis").is_not_null() & (pl.col("pis") > 0))
            .select(["pis", "cnpj_raiz"])
            .unique()
            .collect()
        )
        print(f"    rows: {df.height:,}")
        frames.append(df)
        gc.collect()

    panel = pl.concat(frames, how="diagonal").unique()
    print(f"  combined unique (pis, cnpj_raiz): {panel.height:,}")
    print(f"  unique PIS: {panel['pis'].n_unique():,}")
    print(f"  unique cnpj_raiz: {panel['cnpj_raiz'].n_unique():,}")
    return panel


def build_firm_edges(panel: pl.DataFrame) -> pl.DataFrame:
    print("\nBuilding firm-firm worker-flow edges...")

    # Per-firm worker count (for normalization later)
    firm_size = (
        panel.group_by("cnpj_raiz")
        .agg(pl.len().alias("n_workers_ever"))
    )
    print(f"  per-firm worker counts: {firm_size.height:,}")

    # Restrict to PIS that appear at ≥2 firms (only these contribute to edges)
    pis_n_firms = (
        panel.group_by("pis")
        .agg(pl.col("cnpj_raiz").n_unique().alias("n_firms"))
    )
    multi_pis = pis_n_firms.filter(pl.col("n_firms") >= 2).select("pis")
    print(f"  PIS at ≥2 BEC firms: {multi_pis.height:,}")

    # Cap to PIS that worked at <= 30 firms (drop hyper-mobile workers,
    # likely outsourcing/temp agencies that would create huge spurious edges)
    multi_pis_capped = pis_n_firms.filter(
        (pl.col("n_firms") >= 2) & (pl.col("n_firms") <= 30)
    ).select("pis")
    print(f"  PIS at 2-30 BEC firms (capped): {multi_pis_capped.height:,}")

    panel_filt = panel.join(multi_pis_capped, on="pis", how="inner")
    print(f"  filtered panel: {panel_filt.height:,}")

    # Self-join on pis to get all (cnpj_a, cnpj_b) co-occurrences
    print("  performing self-join...", flush=True)
    edges = (
        panel_filt
        .join(
            panel_filt.rename({"cnpj_raiz": "cnpj_b"}),
            on="pis",
            how="inner",
        )
        .filter(pl.col("cnpj_raiz") < pl.col("cnpj_b"))   # de-dup pairs (a < b)
        .group_by(["cnpj_raiz", "cnpj_b"])
        .agg(pl.len().alias("shared_workers"))
        .rename({"cnpj_raiz": "cnpj_a"})
    )
    print(f"  unique firm-firm edges: {edges.height:,}")

    # Add firm sizes for Jaccard / cosine
    edges = (
        edges
        .join(firm_size.rename({"cnpj_raiz": "cnpj_a",
                                 "n_workers_ever": "n_workers_a"}),
              on="cnpj_a", how="left")
        .join(firm_size.rename({"cnpj_raiz": "cnpj_b",
                                 "n_workers_ever": "n_workers_b"}),
              on="cnpj_b", how="left")
        .with_columns([
            (pl.col("shared_workers") /
             (pl.col("n_workers_a") + pl.col("n_workers_b") -
              pl.col("shared_workers")))
                .alias("jaccard"),
        ])
    )

    EDGES_OUT.parent.mkdir(parents=True, exist_ok=True)
    edges.write_parquet(EDGES_OUT, compression="snappy")
    print(f"  [written] {EDGES_OUT} ({EDGES_OUT.stat().st_size/1e6:.1f} MB)")
    return edges


def attach_to_pairs_and_evaluate(edges: pl.DataFrame) -> None:
    print("\n" + "=" * 70)
    print("Evaluating screen against CADE ground truth")
    print("=" * 70)

    print("\n[1] Loading pregão close-bid pairs...", flush=True)
    pairs = pl.read_parquet(PAIRS_PATH)
    print(f"  total rows: {pairs.height:,}")

    # Restrict to close-bid window for the test (where the discrimination
    # actually matters for cartel detection)
    pairs = pairs.filter(pl.col("MV").abs() < 0.10)
    print(f"  |MV|<0.10: {pairs.height:,}")

    # Build (winner_cnpj_raiz, runnerup_cnpj_raiz) at the AUCTION level
    print("\n[2] Building auction-level (winner, runner-up) pairs...", flush=True)
    pairs = pairs.with_columns(
        pl.col("códigofornecedor").cast(pl.Utf8).str.zfill(14)
            .str.slice(0, 8).alias("cnpj_raiz")
    )

    # Winners and losers separately
    winners = pairs.filter(pl.col("flagvencedor") == 1).select([
        "auction_item",
        pl.col("cnpj_raiz").alias("winner_cnpj"),
        "year", "MV",
        pl.col("has_active_cartel"),
        pl.col("has_any_cartel_firm"),
        pl.col("both_cartel_active"),
    ])
    losers = pairs.filter(pl.col("flagvencedor") == 0).select([
        "auction_item",
        pl.col("cnpj_raiz").alias("loser_cnpj"),
    ])
    auctions = winners.join(losers, on="auction_item", how="inner")
    print(f"  auction-level rows: {auctions.height:,}")

    # Normalize edge: smaller cnpj first (to match edges file)
    auctions = auctions.with_columns([
        pl.when(pl.col("winner_cnpj") < pl.col("loser_cnpj"))
            .then(pl.col("winner_cnpj"))
            .otherwise(pl.col("loser_cnpj"))
            .alias("cnpj_a"),
        pl.when(pl.col("winner_cnpj") < pl.col("loser_cnpj"))
            .then(pl.col("loser_cnpj"))
            .otherwise(pl.col("winner_cnpj"))
            .alias("cnpj_b"),
    ])

    # Lookup edge weight
    print("\n[3] Looking up worker-flow edge weights...", flush=True)
    auctions = auctions.join(
        edges.select(["cnpj_a", "cnpj_b", "shared_workers", "jaccard"]),
        on=["cnpj_a", "cnpj_b"], how="left"
    ).with_columns([
        pl.col("shared_workers").fill_null(0),
        pl.col("jaccard").fill_null(0.0),
    ])

    # Coverage
    n_with_edge = auctions.filter(pl.col("shared_workers") > 0).height
    print(f"  pairs with ≥1 shared worker: {n_with_edge:,} / {auctions.height:,} "
          f"({100*n_with_edge/auctions.height:.1f}%)")

    # ─────────────────────────────────────────────────────────────────
    # Compare distributions
    # ─────────────────────────────────────────────────────────────────
    REPORT_OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(REPORT_OUT, "w") as f:
        f.write(f"Worker-flow network screen — {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")
        f.write(f"Pregão close-bid pairs (|MV|<0.10): {auctions.height:,}\n")
        f.write(f"Pairs with ≥1 shared worker: {n_with_edge:,} "
                f"({100*n_with_edge/auctions.height:.1f}%)\n\n")

        # Group definitions
        treat_active = auctions.filter(pl.col("has_active_cartel") == 1)
        treat_paired = auctions.filter(pl.col("both_cartel_active") == 1)
        control = auctions.filter(pl.col("has_any_cartel_firm") == 0)

        f.write("Group sizes (auction-level):\n")
        f.write(f"  treat: cartel-active any                N={treat_active.height:,}\n")
        f.write(f"  treat: BOTH winner+runner cartel-active N={treat_paired.height:,}\n")
        f.write(f"  control: no cartel firm                 N={control.height:,}\n\n")

        # Means by group
        for screen in ["shared_workers", "jaccard"]:
            f.write(f"\nScreen: {screen}\n")
            f.write(f"  control mean:           {control[screen].mean():.4f}\n")
            f.write(f"  cartel-active mean:     {treat_active[screen].mean():.4f}\n")
            if treat_paired.height > 5:
                f.write(f"  PAIR-MATCHED mean:      {treat_paired[screen].mean():.4f}\n")

            # Two-sample t-test (Welch)
            from math import sqrt, erf
            t_arr = treat_active[screen].drop_nulls().to_numpy()
            c_arr = control[screen].drop_nulls().to_numpy()
            if len(t_arr) > 30 and len(c_arr) > 30:
                mt, mc = t_arr.mean(), c_arr.mean()
                vt, vc = t_arr.var(ddof=1), c_arr.var(ddof=1)
                se = sqrt(vt/len(t_arr) + vc/len(c_arr))
                if se > 0:
                    tstat = (mt - mc) / se
                    p = 2 * (1 - 0.5 * (1 + erf(abs(tstat) / sqrt(2))))
                    f.write(f"  t-stat (cartel-active vs control): {tstat:+.3f}\n")
                    f.write(f"  p-value: {p:.4g}\n")

            # Pair-matched test
            if treat_paired.height >= 10:
                p_arr = treat_paired[screen].drop_nulls().to_numpy()
                mp = p_arr.mean()
                vp = p_arr.var(ddof=1) if len(p_arr) > 1 else 0
                se_p = sqrt(vp/len(p_arr) + vc/len(c_arr))
                if se_p > 0:
                    tstat_p = (mp - mc) / se_p
                    p_p = 2 * (1 - 0.5 * (1 + erf(abs(tstat_p) / sqrt(2))))
                    f.write(f"  PAIR-MATCHED vs control: t={tstat_p:+.3f} "
                            f"p={p_p:.4g} (n_paired={len(p_arr)})\n")

            # AUC computation
            import numpy as np
            for name, treat_arr in [("cartel-active", t_arr),
                                     ("PAIR-MATCHED",
                                      treat_paired[screen].drop_nulls().to_numpy())]:
                if len(treat_arr) < 10:
                    continue
                all_scores = np.concatenate([treat_arr, c_arr])
                labels = np.concatenate([np.ones(len(treat_arr)),
                                         np.zeros(len(c_arr))])
                order = np.argsort(all_scores)
                ranks = np.empty_like(order, dtype=float)
                ranks[order] = np.arange(1, len(all_scores) + 1)
                rank_sum = ranks[labels == 1].sum()
                n_t, n_c = len(treat_arr), len(c_arr)
                auc = (rank_sum - n_t * (n_t + 1) / 2) / (n_t * n_c)
                f.write(f"  AUC ({name} vs control, "
                        f"higher score = more cartel-like): {auc:.4f}\n")

        # Distribution percentiles
        f.write("\n\nDistribution percentiles for shared_workers:\n")
        for p in [50, 75, 90, 95, 99]:
            f.write(f"  p{p}: control={control['shared_workers'].quantile(p/100):.0f} "
                    f"cartel-active={treat_active['shared_workers'].quantile(p/100):.0f}\n")

    print(f"\n[written] {REPORT_OUT}")

    # Print to stdout
    with open(REPORT_OUT) as f:
        print(f.read())


def main() -> None:
    t0 = time.time()
    print("=" * 70)
    print("Worker-flow network screen — Track A.5")
    print(f"Run at: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 70)

    bec_set = load_bec_set()

    # Reuse existing edges file if present (cache)
    if EDGES_OUT.exists():
        print(f"\n[cached] using existing edges: {EDGES_OUT}")
        edges = pl.read_parquet(EDGES_OUT)
        print(f"  edges: {edges.height:,}")
    else:
        panel = build_pis_firm_panel(bec_set)
        edges = build_firm_edges(panel)
        del panel
        gc.collect()

    attach_to_pairs_and_evaluate(edges)

    print(f"\nTotal time: {time.time() - t0:.1f}s")


if __name__ == "__main__":
    main()
