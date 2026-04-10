#!/usr/bin/env python3
"""
29_cobidding_temporal.py — Co-bidding screen with temporal conditioning

Purpose
-------
Test whether co-bidding density AUC (0.70 full-panel) collapses under temporal
conditioning, like worker-flow AUC does. Build cumulative co-bidding counts
[2009, t-1] for each auction year t, then recompute AUCs.

If co-bidding AUC also collapses → reinforces methodological warning broadly.
If it survives → co-bidding is fundamentally different (real-time observable).
"""
from __future__ import annotations

import time
from pathlib import Path

import numpy as np
import duckdb

BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")
FINAL = BASE / "02_data" / "final"
FIRMS = BASE / "02_data" / "firms"
INTER = BASE / "02_data" / "intermediate"

PAIRS_PREGAO = str(FINAL / "df_pregao_with_cartel_flags.parquet")
SCREENS      = str(FINAL / "auction_screens_pregao.parquet")
# Full-panel co-bidding edges (for reference)
COB_EDGES    = str(FIRMS / "firm_firm_cobidding_edges.parquet")
# Need bid-level data to build temporal co-bidding
BID_LEVEL    = str(Path("/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers"
                        "/v3/data/processed/bid_level_with_prices.parquet"))

OUT_REPORT = INTER / "cobidding_temporal.txt"
MV_BANDWIDTH = 0.10


def compute_auc(t: np.ndarray, c: np.ndarray, direction: str) -> dict:
    t = t[~np.isnan(t)]
    c = c[~np.isnan(c)]
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
    return dict(n_t=n_t, n_c=n_c,
                auc=float(auc_gt if direction == "higher_is_cartel" else 1.0 - auc_gt))


def main() -> None:
    t0 = time.time()
    INTER.mkdir(parents=True, exist_ok=True)

    con = duckdb.connect()
    con.sql("PRAGMA threads=12; PRAGMA memory_limit='14GB'")
    con.sql("PRAGMA temp_directory='/tmp/duckdb_spill'")

    # ── Step 1: Build cumulative co-bidding from bid-level data ──────────────

    print("Step 1: Building cumulative co-bidding edges...", flush=True)

    # Build auction-year lookup from the pair file (already pregão-filtered)
    con.sql(f"""
        CREATE OR REPLACE TABLE bids AS
        SELECT DISTINCT
            numerodaoc, "códigoitem",
            LPAD(CAST("códigofornecedor" AS VARCHAR), 14, '0')[1:8] AS cnpj_raiz,
            year AS bid_year
        FROM read_parquet('{PAIRS_PREGAO}')
    """)

    # Self-join to get co-bidding pairs per auction
    con.sql("""
        CREATE OR REPLACE TABLE cobid_pairs AS
        SELECT
            CASE WHEN a.cnpj_raiz < b.cnpj_raiz THEN a.cnpj_raiz
                 ELSE b.cnpj_raiz END AS cnpj_a,
            CASE WHEN a.cnpj_raiz < b.cnpj_raiz THEN b.cnpj_raiz
                 ELSE a.cnpj_raiz END AS cnpj_b,
            a.bid_year,
            a.numerodaoc,
            a."códigoitem"
        FROM bids a
        JOIN bids b ON a.numerodaoc = b.numerodaoc
            AND a."códigoitem" = b."códigoitem"
            AND a.cnpj_raiz < b.cnpj_raiz
    """)

    # Cumulative co-bidding: for auction year t, count co-bids in [2009, t-1]
    # First, get the earliest co-bid year for each pair
    con.sql("""
        CREATE OR REPLACE TABLE cobid_by_year AS
        SELECT cnpj_a, cnpj_b, bid_year,
               count(DISTINCT numerodaoc || '_' || "códigoitem") AS n_cobids_yr
        FROM cobid_pairs
        GROUP BY cnpj_a, cnpj_b, bid_year
    """)

    n_pairs = con.sql("SELECT count(*) FROM cobid_by_year").fetchone()[0]
    print(f"  co-bidding pair-year records: {n_pairs:,}")

    # ── Step 2: Build auction benchmark ──────────────────────────────────────

    print("Step 2: Building auction benchmark...", flush=True)

    con.sql(f"""
        CREATE OR REPLACE TABLE pairs_raw AS
        SELECT *,
            LPAD(CAST("códigofornecedor" AS VARCHAR), 14, '0')[1:8] AS cnpj_raiz_n
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE ABS(MV) < {MV_BANDWIDTH}
    """)
    con.sql("""
        CREATE OR REPLACE TABLE winners AS
        SELECT DISTINCT ON (auction_item)
            auction_item, numerodaoc, "códigoitem", year,
            cnpj_raiz_n AS winner_cnpj,
            has_any_cartel_firm, has_active_cartel
        FROM pairs_raw WHERE flagvencedor = 1
    """)
    con.sql("""
        CREATE OR REPLACE TABLE losers AS
        SELECT DISTINCT ON (auction_item)
            auction_item, cnpj_raiz_n AS loser_cnpj
        FROM pairs_raw WHERE flagvencedor = 0
    """)
    con.sql("""
        CREATE OR REPLACE TABLE auctions AS
        SELECT w.*, l.loser_cnpj,
            CASE WHEN w.winner_cnpj < l.loser_cnpj
                THEN w.winner_cnpj ELSE l.loser_cnpj END AS cnpj_a,
            CASE WHEN w.winner_cnpj < l.loser_cnpj
                THEN l.loser_cnpj ELSE w.winner_cnpj END AS cnpj_b
        FROM winners w JOIN losers l ON w.auction_item = l.auction_item
    """)

    # ── Step 3: Join co-bidding (full-panel and cumulative) ──────────────────

    print("Step 3: Computing full-panel and cumulative co-bidding per auction...",
          flush=True)

    # Full-panel co-bidding count
    con.sql("""
        CREATE OR REPLACE TABLE cobid_full AS
        SELECT cnpj_a, cnpj_b, SUM(n_cobids_yr) AS n_cobids_full
        FROM cobid_by_year
        GROUP BY cnpj_a, cnpj_b
    """)

    # Cumulative: for each auction, sum co-bids from years < auction year
    con.sql("""
        CREATE OR REPLACE TABLE auction_cobid AS
        SELECT
            a.auction_item, a.year, a.has_active_cartel, a.has_any_cartel_firm,
            COALESCE(cf.n_cobids_full, 0) AS cobid_full,
            COALESCE(cc.n_cobids_cum, 0) AS cobid_cum
        FROM auctions a
        LEFT JOIN cobid_full cf ON a.cnpj_a = cf.cnpj_a AND a.cnpj_b = cf.cnpj_b
        LEFT JOIN (
            SELECT cby.cnpj_a, cby.cnpj_b, a2.year AS auction_year,
                   SUM(cby.n_cobids_yr) AS n_cobids_cum
            FROM cobid_by_year cby
            JOIN (SELECT DISTINCT cnpj_a, cnpj_b, year FROM auctions) a2
                ON cby.cnpj_a = a2.cnpj_a AND cby.cnpj_b = a2.cnpj_b
            WHERE cby.bid_year < a2.year
            GROUP BY cby.cnpj_a, cby.cnpj_b, a2.year
        ) cc ON a.cnpj_a = cc.cnpj_a AND a.cnpj_b = cc.cnpj_b
            AND a.year = cc.auction_year
    """)

    # ── Step 4: Compute AUCs ─────────────────────────────────────────────────

    print("Step 4: Computing AUCs...", flush=True)

    df = con.sql("""
        SELECT has_active_cartel, has_any_cartel_firm, cobid_full, cobid_cum
        FROM auction_cobid
    """).fetchnumpy()

    treat = np.array(df["has_active_cartel"], dtype=float) == 1
    clean = np.array(df["has_any_cartel_firm"], dtype=float) == 0
    cobid_full = np.array(df["cobid_full"], dtype=float)
    cobid_cum = np.array(df["cobid_cum"], dtype=float)

    r_full = compute_auc(cobid_full[treat], cobid_full[clean], "higher_is_cartel")
    r_cum = compute_auc(cobid_cum[treat], cobid_cum[clean], "higher_is_cartel")

    # ── Step 5: Write report ─────────────────────────────────────────────────

    with open(OUT_REPORT, "w") as f:
        f.write("Co-Bidding Screen: Temporal Conditioning\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 60 + "\n\n")

        f.write("CO-BIDDING AUCs\n")
        f.write("-" * 50 + "\n")
        f.write(f"  Full-panel [2009-2019]:      AUC = {r_full['auc']:.3f}  "
                f"N_t={r_full['n_t']:,}  N_c={r_full['n_c']:,}\n")
        f.write(f"  Cumulative [2009, t-1]:      AUC = {r_cum['auc']:.3f}  "
                f"N_t={r_cum['n_t']:,}  N_c={r_cum['n_c']:,}\n\n")

        f.write("COMPARISON WITH WORKER-FLOW SCREENS\n")
        f.write("-" * 60 + "\n")
        f.write("  Screen              Full-panel    Cumulative    Δ\n")
        f.write(f"  Shared workers      0.750         0.524         -0.226\n")
        f.write(f"  Co-bidding          {r_full['auc']:.3f}         "
                f"{r_cum['auc']:.3f}         "
                f"{r_cum['auc'] - r_full['auc']:+.3f}\n\n")

        if r_cum["auc"] > 0.60:
            f.write("INTERPRETATION:\n")
            f.write("  → Co-bidding AUC SURVIVES temporal conditioning.\n")
            f.write("  → Co-bidding is observable in real-time (firms bid together\n")
            f.write("    before the auction being screened), unlike worker flows\n")
            f.write("    which require future RAIS data.\n")
            f.write("  → The look-ahead bias warning is SPECIFIC to employment-\n")
            f.write("    network screens, not universal to all network screens.\n")
        else:
            f.write("INTERPRETATION:\n")
            f.write("  → Co-bidding AUC also collapses with temporal conditioning.\n")
            f.write("  → Look-ahead bias affects BOTH network layers.\n")
            f.write("  → The methodological warning is fully general.\n")

    print(f"\n[written] {OUT_REPORT}")
    con.close()
    print(f"Total time: {time.time() - t0:.1f}s")
    print("\n--- report ---")
    print(OUT_REPORT.read_text())


if __name__ == "__main__":
    main()
