#!/usr/bin/env python3
"""
31_rivalry_decomposition.py — Worker flows decomposed by auction rivalry

Purpose
-------
For each cartel firm, decompose post-conduct worker outflows into:
  (a) flows to AUCTION RIVALS — firms that were runner-up when the cartel firm
      won (or vice versa) in close-margin auctions during the conduct period
  (b) flows to MARKET PEERS — firms that bid on the same item codes but were
      never in a close-margin (winner, runner-up) pair with the cartel firm
  (c) flows to BYSTANDERS — other BEC firms with no auction connection

Tests whether enforcement-driven labor reallocation follows the procurement
competition structure, or is generic labor market mobility.

Also: for close-margin auctions where the cartel firm won, does the specific
runner-up in THAT auction absorb ex-workers from the cartel firm in later years?

Output
------
- 02_data/intermediate/rivalry_decomposition.txt
- 04_figures/rivalry_decomposition.pdf
"""
from __future__ import annotations

import time
from pathlib import Path

import numpy as np
import duckdb

BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")
RAIS_DIR = BASE / "RAIS" / "parquet" / "harmonized"
FINAL = BASE / "02_data" / "final"
FIRMS = BASE / "02_data" / "firms"
INTER = BASE / "02_data" / "intermediate"
FIGS  = BASE / "04_figures"

BEC_FIRMS    = str(BASE / "02_data" / "bec_cnpj_list.parquet")
PAIRS_PREGAO = str(FINAL / "df_pregao_with_cartel_flags.parquet")
GROUND_TRUTH = str(FIRMS / "cade_ground_truth.parquet")

OUT_REPORT = INTER / "rivalry_decomposition.txt"
OUT_FIGURE = FIGS / "rivalry_decomposition.pdf"

MV_BANDWIDTH = 0.10


def main() -> None:
    t0 = time.time()
    INTER.mkdir(parents=True, exist_ok=True)
    FIGS.mkdir(parents=True, exist_ok=True)

    con = duckdb.connect()
    con.sql("PRAGMA threads=12; PRAGMA memory_limit='14GB'")
    con.sql("PRAGMA temp_directory='/tmp/duckdb_spill'")

    rais_glob = str(RAIS_DIR / "rais_vinculos_*.parquet")

    # ── Step 1: Worker-firm panel ────────────────────────────────────────────

    print("Step 1: Building worker-firm panel...", flush=True)
    con.sql(f"""
        CREATE OR REPLACE TABLE worker_firm AS
        SELECT pis, cnpj_raiz, MIN(ano) AS first_year, MAX(ano) AS last_year
        FROM read_parquet('{rais_glob}')
        WHERE cnpj_raiz IN (SELECT cnpj_raiz FROM read_parquet('{BEC_FIRMS}'))
          AND pis IS NOT NULL AND cnpj_raiz IS NOT NULL
        GROUP BY pis, cnpj_raiz
    """)
    # Filter to mobile workers (2-30 firms)
    con.sql("""
        CREATE OR REPLACE TABLE worker_firm_f AS
        SELECT wf.* FROM worker_firm wf
        SEMI JOIN (
            SELECT pis FROM worker_firm
            GROUP BY pis HAVING count(DISTINCT cnpj_raiz) BETWEEN 2 AND 30
        ) p ON wf.pis = p.pis
    """)
    n = con.sql("SELECT count(*) FROM worker_firm_f").fetchone()[0]
    print(f"  worker-firm pairs (filtered): {n:,}")

    # ── Step 2: Cartel firms and conduct periods ─────────────────────────────

    print("Step 2: Loading cartel firms...", flush=True)
    con.sql(f"""
        CREATE OR REPLACE TABLE cartel_firms AS
        SELECT DISTINCT cnpj_raiz, setor,
               cartel_start_year::INT AS start_yr,
               cartel_end_year::INT AS end_yr
        FROM read_parquet('{GROUND_TRUTH}')
        WHERE sp_relevant = 1 AND processo IS NOT NULL
          AND cartel_start_year IS NOT NULL
          AND cartel_end_year <= 2017
    """)
    n_cf = con.sql("SELECT count(*) FROM cartel_firms").fetchone()[0]
    print(f"  cartel firms: {n_cf}")

    # ── Step 3: Build rivalry categories ─────────────────────────────────────

    print("Step 3: Building rivalry categories...", flush=True)

    # Load close-margin pairs to identify auction rivals
    con.sql(f"""
        CREATE OR REPLACE TABLE close_pairs AS
        SELECT DISTINCT
            numerodaoc, "códigoitem", year,
            LPAD(CAST("códigofornecedor" AS VARCHAR), 14, '0')[1:8] AS cnpj_raiz,
            flagvencedor
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE ABS(MV) < {MV_BANDWIDTH}
    """)

    # Winners and runners-up at auction level
    con.sql("""
        CREATE OR REPLACE TABLE auction_pairs AS
        SELECT DISTINCT
            w.numerodaoc, w."códigoitem", w.year,
            w.cnpj_raiz AS winner_cnpj,
            l.cnpj_raiz AS loser_cnpj
        FROM (SELECT DISTINCT numerodaoc, "códigoitem", year, cnpj_raiz
              FROM close_pairs WHERE flagvencedor = 1) w
        JOIN (SELECT DISTINCT numerodaoc, "códigoitem", year, cnpj_raiz
              FROM close_pairs WHERE flagvencedor = 0) l
            ON w.numerodaoc = l.numerodaoc
            AND w."códigoitem" = l."códigoitem"
            AND w.year = l.year
    """)

    # AUCTION RIVALS: firms that were in a (winner, runner-up) pair with
    # a cartel firm during the conduct period
    con.sql("""
        CREATE OR REPLACE TABLE auction_rivals AS
        -- Case 1: cartel firm was winner, rival was loser
        SELECT DISTINCT cf.cnpj_raiz AS cartel_cnpj, ap.loser_cnpj AS rival_cnpj,
               cf.setor
        FROM cartel_firms cf
        JOIN auction_pairs ap ON cf.cnpj_raiz = ap.winner_cnpj
            AND ap.year BETWEEN cf.start_yr AND cf.end_yr
        WHERE ap.loser_cnpj NOT IN (SELECT cnpj_raiz FROM cartel_firms
                                     WHERE setor = cf.setor)
        UNION
        -- Case 2: cartel firm was loser, rival was winner
        SELECT DISTINCT cf.cnpj_raiz AS cartel_cnpj, ap.winner_cnpj AS rival_cnpj,
               cf.setor
        FROM cartel_firms cf
        JOIN auction_pairs ap ON cf.cnpj_raiz = ap.loser_cnpj
            AND ap.year BETWEEN cf.start_yr AND cf.end_yr
        WHERE ap.winner_cnpj NOT IN (SELECT cnpj_raiz FROM cartel_firms
                                      WHERE setor = cf.setor)
    """)
    n_rivals = con.sql("SELECT count(*) FROM auction_rivals").fetchone()[0]
    print(f"  auction rival pairs: {n_rivals:,}")

    # MARKET PEERS: firms that bid on the same item codes as cartel firm
    # but were never in a close-margin (winner, runner-up) pair
    con.sql("""
        CREATE OR REPLACE TABLE market_peers AS
        SELECT DISTINCT cf.cnpj_raiz AS cartel_cnpj,
               cp.cnpj_raiz AS peer_cnpj, cf.setor
        FROM cartel_firms cf
        -- Find item codes the cartel firm bid on during conduct
        JOIN close_pairs cp_cf ON cf.cnpj_raiz = cp_cf.cnpj_raiz
            AND cp_cf.year BETWEEN cf.start_yr AND cf.end_yr
        -- Find other firms that bid on the same items
        JOIN close_pairs cp ON cp_cf."códigoitem" = cp."códigoitem"
            AND cp.cnpj_raiz != cf.cnpj_raiz
        -- Exclude auction rivals
        LEFT JOIN auction_rivals ar ON cf.cnpj_raiz = ar.cartel_cnpj
            AND cp.cnpj_raiz = ar.rival_cnpj
        -- Exclude other cartel firms
        LEFT JOIN cartel_firms cf2 ON cp.cnpj_raiz = cf2.cnpj_raiz
            AND cf2.setor = cf.setor
        WHERE ar.rival_cnpj IS NULL AND cf2.cnpj_raiz IS NULL
    """)
    n_peers = con.sql("SELECT count(*) FROM market_peers").fetchone()[0]
    print(f"  market peer pairs: {n_peers:,}")

    # ── Step 4: Count post-conduct worker flows by rivalry category ──────────

    print("Step 4: Counting post-conduct worker flows by category...", flush=True)

    # All post-conduct worker flows FROM cartel firms TO any other firm
    con.sql("""
        CREATE OR REPLACE TABLE post_flows AS
        SELECT
            cf.cnpj_raiz AS cartel_cnpj,
            cf.setor,
            cf.end_yr,
            wf_rival.cnpj_raiz AS dest_cnpj,
            wf_rival.first_year AS dest_first_year,
            wf_cartel.pis,
            wf_cartel.first_year AS cartel_first_year,
            wf_cartel.last_year AS cartel_last_year
        FROM cartel_firms cf
        JOIN worker_firm_f wf_cartel ON cf.cnpj_raiz = wf_cartel.cnpj_raiz
        JOIN worker_firm_f wf_rival ON wf_cartel.pis = wf_rival.pis
            AND wf_rival.cnpj_raiz != cf.cnpj_raiz
        -- Exclude intra-cartel flows
        LEFT JOIN cartel_firms cf2 ON wf_rival.cnpj_raiz = cf2.cnpj_raiz
            AND cf2.setor = cf.setor
        -- Post-conduct: worker appeared at destination AFTER conduct ended
        WHERE wf_rival.first_year > cf.end_yr
          AND cf2.cnpj_raiz IS NULL
    """)
    n_post = con.sql("SELECT count(*) FROM post_flows").fetchone()[0]
    print(f"  post-conduct flow records: {n_post:,}")

    # Classify each flow
    con.sql("""
        CREATE OR REPLACE TABLE flows_classified AS
        SELECT
            pf.*,
            CASE
                WHEN ar.rival_cnpj IS NOT NULL THEN 'auction_rival'
                WHEN mp.peer_cnpj IS NOT NULL THEN 'market_peer'
                ELSE 'bystander'
            END AS rival_type
        FROM post_flows pf
        LEFT JOIN auction_rivals ar ON pf.cartel_cnpj = ar.cartel_cnpj
            AND pf.dest_cnpj = ar.rival_cnpj
        LEFT JOIN market_peers mp ON pf.cartel_cnpj = mp.cartel_cnpj
            AND pf.dest_cnpj = mp.peer_cnpj
    """)

    # Aggregate
    agg = con.sql("""
        SELECT
            rival_type,
            count(DISTINCT pis) AS n_workers,
            count(DISTINCT dest_cnpj) AS n_dest_firms,
            count(DISTINCT cartel_cnpj) AS n_cartel_firms
        FROM flows_classified
        GROUP BY rival_type
        ORDER BY rival_type
    """).fetchdf()

    # Per-cartel breakdown
    agg_cartel = con.sql("""
        SELECT
            setor, rival_type,
            count(DISTINCT pis) AS n_workers,
            count(DISTINCT dest_cnpj) AS n_dest_firms
        FROM flows_classified
        GROUP BY setor, rival_type
        ORDER BY setor, rival_type
    """).fetchdf()

    # Rates: what share of post-conduct flows go to each category?
    total_workers = int(agg["n_workers"].sum())

    # ── Step 5: How many auction-rival pairs actually see flows? ─────────────

    print("Step 5: Auction-pair flow analysis...", flush=True)

    # For each close-margin auction where cartel firm won:
    # does the specific runner-up absorb ex-workers post-conduct?
    con.sql("""
        CREATE OR REPLACE TABLE pair_absorption AS
        SELECT
            ap.numerodaoc, ap."códigoitem", ap.year AS auction_year,
            ap.winner_cnpj AS cartel_cnpj,
            ap.loser_cnpj AS runnerup_cnpj,
            cf.setor, cf.end_yr,
            count(DISTINCT fc.pis) AS n_absorbed
        FROM auction_pairs ap
        JOIN cartel_firms cf ON ap.winner_cnpj = cf.cnpj_raiz
            AND ap.year BETWEEN cf.start_yr AND cf.end_yr
        LEFT JOIN flows_classified fc
            ON fc.cartel_cnpj = ap.winner_cnpj
            AND fc.dest_cnpj = ap.loser_cnpj
        -- Exclude if runner-up is also cartel
        LEFT JOIN cartel_firms cf2 ON ap.loser_cnpj = cf2.cnpj_raiz
            AND cf2.setor = cf.setor
        WHERE cf2.cnpj_raiz IS NULL
        GROUP BY ap.numerodaoc, ap."códigoitem", ap.year,
                 ap.winner_cnpj, ap.loser_cnpj, cf.setor, cf.end_yr
    """)

    absorption_stats = con.sql("""
        SELECT
            count(*) AS n_auction_pairs,
            count(CASE WHEN n_absorbed > 0 THEN 1 END) AS n_with_flows,
            avg(n_absorbed) AS mean_absorbed,
            max(n_absorbed) AS max_absorbed,
            sum(n_absorbed) AS total_absorbed
        FROM pair_absorption
    """).fetchdf()

    # ── Step 6: Write report ─────────────────────────────────────────────────

    with open(OUT_REPORT, "w") as f:
        f.write("Rivalry Decomposition of Post-Conduct Worker Flows\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")

        f.write("RIVALRY CATEGORIES\n")
        f.write("-" * 60 + "\n")
        f.write("  Auction rival: was runner-up (or winner) in a close-margin\n")
        f.write("    auction against the cartel firm during conduct period\n")
        f.write("  Market peer: bid on the same item codes but never in a\n")
        f.write("    close-margin pair with the cartel firm\n")
        f.write("  Bystander: other BEC firm with no auction connection\n\n")

        f.write(f"  Auction rival pairs:  {n_rivals:,}\n")
        f.write(f"  Market peer pairs:    {n_peers:,}\n\n")

        f.write("POST-CONDUCT WORKER FLOWS BY RIVAL TYPE\n")
        f.write("-" * 60 + "\n")
        f.write(f"{'Type':20s} {'Workers':>8s} {'Share':>7s} {'Dest firms':>10s}\n")
        f.write("-" * 60 + "\n")
        for _, row in agg.iterrows():
            share = int(row["n_workers"]) / total_workers * 100 if total_workers > 0 else 0
            f.write(f"{row['rival_type']:20s} {int(row['n_workers']):>8,} "
                    f"{share:>6.1f}% {int(row['n_dest_firms']):>10,}\n")
        f.write(f"{'TOTAL':20s} {total_workers:>8,} {'100.0':>6s}%\n\n")

        # Intensity: workers per destination firm
        f.write("INTENSITY (workers per destination firm)\n")
        f.write("-" * 50 + "\n")
        for _, row in agg.iterrows():
            intensity = int(row["n_workers"]) / max(int(row["n_dest_firms"]), 1)
            f.write(f"  {row['rival_type']:20s}  {intensity:.1f} workers/firm\n")
        f.write("\n")

        # Per-cartel
        f.write("PER-CARTEL BREAKDOWN\n")
        f.write("-" * 70 + "\n")
        for setor in agg_cartel["setor"].unique():
            f.write(f"\n  {setor}:\n")
            sub = agg_cartel[agg_cartel["setor"] == setor]
            stotal = int(sub["n_workers"].sum())
            for _, row in sub.iterrows():
                sh = int(row["n_workers"]) / stotal * 100 if stotal > 0 else 0
                f.write(f"    {row['rival_type']:20s}  workers={int(row['n_workers']):>5,}  "
                        f"({sh:.0f}%)\n")
        f.write("\n")

        # Auction-pair absorption
        f.write("AUCTION-PAIR ABSORPTION\n")
        f.write("-" * 60 + "\n")
        f.write("  (For auctions where cartel firm won: does the specific\n")
        f.write("   runner-up absorb ex-workers post-conduct?)\n\n")
        for col in absorption_stats.columns:
            val = absorption_stats[col].iloc[0]
            f.write(f"  {col:25s}  {val}\n")

        n_pairs_total = int(absorption_stats["n_auction_pairs"].iloc[0])
        n_with = int(absorption_stats["n_with_flows"].iloc[0])
        pct = n_with / n_pairs_total * 100 if n_pairs_total > 0 else 0
        f.write(f"\n  → {pct:.1f}% of auction pairs show post-conduct worker\n")
        f.write(f"    absorption from the winner (cartel) to the runner-up.\n")

    print(f"\n[written] {OUT_REPORT}")

    # ── Step 7: Figure ───────────────────────────────────────────────────────

    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        categories = agg["rival_type"].tolist()
        workers = agg["n_workers"].astype(int).tolist()
        colors = {"auction_rival": "#d73027", "market_peer": "#fdae61",
                  "bystander": "#4575b4"}

        fig, ax = plt.subplots(figsize=(7, 4.5))
        bars = ax.barh(categories, workers,
                       color=[colors.get(c, "grey") for c in categories],
                       edgecolor="white", linewidth=0.5)

        for bar, w in zip(bars, workers):
            pct = w / total_workers * 100
            ax.text(bar.get_width() + total_workers * 0.01, bar.get_y() + bar.get_height() / 2,
                    f"{w:,} ({pct:.0f}%)", va="center", fontsize=9)

        ax.set_xlabel("Distinct workers (post-conduct flows from cartel firms)",
                      fontsize=10)
        ax.set_xlim(0, max(workers) * 1.25)
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)

        fig.tight_layout()
        fig.savefig(OUT_FIGURE, dpi=300, bbox_inches="tight")
        plt.close(fig)
        print(f"[written] {OUT_FIGURE}")
    except ImportError:
        print("  matplotlib not available")

    con.close()
    print(f"\nTotal time: {time.time() - t0:.1f}s")
    print("\n--- report ---")
    print(OUT_REPORT.read_text())


if __name__ == "__main__":
    main()
