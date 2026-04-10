#!/usr/bin/env python3
"""
34_coordination_type_heterogeneity.py — Screen effectiveness by coordination type

Purpose
-------
The positive contribution: screen effectiveness depends on the coordination
technology the cartel uses. Split results by conduct type:
  - BID RIGGING (6 cartels): trens, merenda, sacos, aquecedores, cafeteria, transporte
  - HUB-AND-SPOKE (1 cartel): medicamentos

Test whether:
  1. Classical screens detect bid rigging but not hub-and-spoke
  2. The Kawai RD fires for bid rigging but not hub-and-spoke
  3. Winner/loser patterns differ by type (incumbency, last bidder)

Output
------
- 02_data/intermediate/coordination_type_heterogeneity.txt
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
WF_EDGES     = str(FIRMS / "firm_firm_worker_flow_edges.parquet")
GROUND_TRUTH = str(FIRMS / "cade_ground_truth.parquet")

OUT_REPORT = INTER / "coordination_type_heterogeneity.txt"
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

    # ── Build sample with cartel identity and conduct type ───────────────────

    print("Building sample...", flush=True)

    con.sql(f"""
        CREATE OR REPLACE TABLE gt AS
        SELECT DISTINCT cnpj_raiz, setor, conduct_type,
               cartel_start_year::INT AS start_yr,
               cartel_end_year::INT AS end_yr
        FROM read_parquet('{GROUND_TRUTH}')
        WHERE sp_relevant = 1 AND processo IS NOT NULL
          AND cartel_start_year IS NOT NULL
    """)

    # Expand to firm × year
    con.sql("""
        CREATE OR REPLACE TABLE gt_expanded AS
        SELECT cnpj_raiz, setor, conduct_type,
               UNNEST(generate_series(start_yr, end_yr)) AS year
        FROM gt
    """)

    # Build auction benchmark
    con.sql(f"""
        CREATE OR REPLACE TABLE pairs AS
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
        FROM pairs WHERE flagvencedor = 1
    """)
    con.sql("""
        CREATE OR REPLACE TABLE losers AS
        SELECT DISTINCT ON (auction_item)
            auction_item, cnpj_raiz_n AS loser_cnpj
        FROM pairs WHERE flagvencedor = 0
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

    # Attach cartel identity + conduct type
    con.sql("""
        CREATE OR REPLACE TABLE auctions_typed AS
        SELECT a.*,
            COALESCE(gw.setor, gl.setor) AS cartel_setor,
            COALESCE(gw.conduct_type, gl.conduct_type) AS conduct_type,
            CASE
                WHEN COALESCE(gw.conduct_type, gl.conduct_type) = 'hub_and_spoke_cartel'
                    THEN 'hub_and_spoke'
                WHEN COALESCE(gw.conduct_type, gl.conduct_type) IS NOT NULL
                    THEN 'bid_rigging'
                ELSE NULL
            END AS type_group
        FROM auctions a
        LEFT JOIN gt_expanded gw ON a.winner_cnpj = gw.cnpj_raiz AND a.year = gw.year
        LEFT JOIN gt_expanded gl ON a.loser_cnpj = gl.cnpj_raiz AND a.year = gl.year
    """)

    # Attach screens
    con.sql(f"""
        CREATE OR REPLACE TABLE screens AS
        SELECT numerodaoc || '_' || "códigoitem" AS auction_item,
               cv_bid, spread, mv, n_firms
        FROM read_parquet('{SCREENS}')
    """)
    con.sql("""
        CREATE OR REPLACE TABLE auctions_full AS
        SELECT a.*, s.cv_bid, s.spread, s.mv, s.n_firms
        FROM auctions_typed a
        LEFT JOIN screens s ON a.auction_item = s.auction_item
    """)

    # Attach worker-flow edges
    con.sql(f"""
        CREATE OR REPLACE TABLE wf AS
        SELECT cnpj_a, cnpj_b, shared_workers, jaccard
        FROM read_parquet('{WF_EDGES}')
    """)
    con.sql("""
        CREATE OR REPLACE TABLE auctions_complete AS
        SELECT af.*,
               COALESCE(wf.shared_workers, 0) AS shared_workers,
               COALESCE(wf.jaccard, 0.0) AS jaccard
        FROM auctions_full af
        LEFT JOIN wf ON af.cnpj_a = wf.cnpj_a AND af.cnpj_b = wf.cnpj_b
    """)

    # ── Fetch and compute AUCs ───────────────────────────────────────────────

    print("Computing AUCs by coordination type...", flush=True)

    df = con.sql("""
        SELECT has_active_cartel, has_any_cartel_firm, type_group,
               cartel_setor, conduct_type,
               cv_bid, spread, mv, n_firms, shared_workers, jaccard
        FROM auctions_complete
    """).fetchnumpy()

    treat = np.array(df["has_active_cartel"], dtype=float) == 1
    clean = np.array(df["has_any_cartel_firm"], dtype=float) == 0
    type_group = np.array(df["type_group"])
    setor = np.array(df["cartel_setor"])

    screens = [
        ("cv_bid", "lower_is_cartel"),
        ("spread", "lower_is_cartel"),
        ("mv", "lower_is_cartel"),
        ("n_firms", "lower_is_cartel"),
        ("shared_workers", "higher_is_cartel"),
        ("jaccard", "higher_is_cartel"),
    ]

    # Clean control (common for all)
    clean_vals = {s: np.array(df[s], dtype=float)[clean] for s, _ in screens}

    # ── Write report ─────────────────────────────────────────────────────────

    with open(OUT_REPORT, "w") as f:
        f.write("Screen Effectiveness by Coordination Technology\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 75 + "\n\n")

        # Sample counts by type
        f.write("SAMPLE COMPOSITION\n")
        f.write("-" * 60 + "\n")
        for tg in ["bid_rigging", "hub_and_spoke"]:
            mask = treat & (type_group == tg)
            n = int(mask.sum())
            setors = sorted(set(setor[mask]) - {None})
            f.write(f"  {tg:20s}  N={n:>5,}  cartels: {', '.join(str(s) for s in setors)}\n")
        f.write(f"  {'ALL':20s}  N={int(treat.sum()):>5,}\n\n")

        # Per-type AUCs
        f.write("AUCs BY COORDINATION TYPE (full-panel)\n")
        f.write("-" * 75 + "\n")
        header_screens = ["cv_bid", "spread", "n_firms", "shared_workers"]
        f.write(f"{'Type':20s} {'N':>5s}  " +
                "  ".join(f"{s:>14s}" for s in header_screens) + "\n")
        f.write("-" * 75 + "\n")

        type_results = {}
        for tg in ["bid_rigging", "hub_and_spoke"]:
            mask = treat & (type_group == tg)
            n = int(mask.sum())
            line = f"{tg:20s} {n:>5,}  "
            type_results[tg] = {}
            for sname in header_screens:
                direction = [d for s, d in screens if s == sname][0]
                vals = np.array(df[sname], dtype=float)
                r = compute_auc(vals[mask], clean_vals[sname], direction)
                line += f"{r['auc']:>14.3f}  "
                type_results[tg][sname] = r['auc']
            f.write(line + "\n")

        # ALL row
        line = f"{'ALL':20s} {int(treat.sum()):>5,}  "
        for sname in header_screens:
            direction = [d for s, d in screens if s == sname][0]
            vals = np.array(df[sname], dtype=float)
            r = compute_auc(vals[treat], clean_vals[sname], direction)
            line += f"{r['auc']:>14.3f}  "
        f.write(line + "\n\n")

        # Per-cartel detail
        f.write("PER-CARTEL DETAIL\n")
        f.write("-" * 75 + "\n")
        f.write(f"{'Cartel':25s} {'Type':>12s} {'N':>5s}  " +
                "  ".join(f"{s:>10s}" for s in header_screens) + "\n")
        f.write("-" * 75 + "\n")

        unique_setors = sorted(set(setor[treat]) - {None})
        for s in unique_setors:
            mask = treat & (setor == s)
            n = int(mask.sum())
            if n < 2:
                continue
            ct = type_group[mask][0] if type_group[mask][0] is not None else "?"
            line = f"{s:25s} {ct:>12s} {n:>5,}  "
            for sname in header_screens:
                direction = [d for sn, d in screens if sn == sname][0]
                vals = np.array(df[sname], dtype=float)
                r = compute_auc(vals[mask], clean_vals[sname], direction)
                line += f"{r['auc']:>10.3f}  "
            f.write(line + "\n")
        f.write("\n")

        # ── Key finding: the gap ─────────────────────────────────────────────

        f.write("KEY FINDING: CLASSICAL SCREENS × COORDINATION TYPE\n")
        f.write("=" * 60 + "\n\n")

        br_cv = type_results.get("bid_rigging", {}).get("cv_bid", np.nan)
        hs_cv = type_results.get("hub_and_spoke", {}).get("cv_bid", np.nan)
        br_nf = type_results.get("bid_rigging", {}).get("n_firms", np.nan)
        hs_nf = type_results.get("hub_and_spoke", {}).get("n_firms", np.nan)
        br_sw = type_results.get("bid_rigging", {}).get("shared_workers", np.nan)
        hs_sw = type_results.get("hub_and_spoke", {}).get("shared_workers", np.nan)

        f.write(f"  Classical screens (CV):\n")
        f.write(f"    Bid rigging:    AUC = {br_cv:.3f}\n")
        f.write(f"    Hub-and-spoke:  AUC = {hs_cv:.3f}\n")
        f.write(f"    Gap:            {br_cv - hs_cv:+.3f}\n\n")

        f.write(f"  Classical screens (bidder count):\n")
        f.write(f"    Bid rigging:    AUC = {br_nf:.3f}\n")
        f.write(f"    Hub-and-spoke:  AUC = {hs_nf:.3f}\n")
        f.write(f"    Gap:            {br_nf - hs_nf:+.3f}\n\n")

        f.write(f"  Worker-flow (full-panel, retrospective):\n")
        f.write(f"    Bid rigging:    AUC = {br_sw:.3f}\n")
        f.write(f"    Hub-and-spoke:  AUC = {hs_sw:.3f}\n")
        f.write(f"    Gap:            {br_sw - hs_sw:+.3f}\n\n")

        if br_cv > 0.58 and hs_cv < 0.52:
            f.write("  → Classical screens DETECT bid rigging but MISS hub-and-spoke.\n")
            f.write("  → The coordination technology determines which screen works.\n")
            f.write("  → Competition authorities should match the screen to the\n")
            f.write("    suspected coordination mechanism.\n")
        elif br_cv > hs_cv:
            f.write("  → Classical screens work better for bid rigging than hub-and-spoke.\n")
        else:
            f.write("  → No clear differential by coordination type.\n")

        # ── Incumbency test by type ──────────────────────────────────────────

        f.write("\n\nINCUMBENCY PATTERN BY TYPE\n")
        f.write("-" * 60 + "\n")
        f.write("  (Is the winner the same firm that won the previous auction\n")
        f.write("   in the same item code? Proxy for bid rotation.)\n\n")

        # Compute incumbency from the pair file
        incumbency = con.sql(f"""
            WITH ordered AS (
                SELECT auction_item, "códigoitem", year,
                    cnpj_raiz_n AS winner_cnpj,
                    has_active_cartel,
                    COALESCE(gw.type_group, gl.type_group) AS type_group,
                    LAG(cnpj_raiz_n) OVER (
                        PARTITION BY "códigoitem"
                        ORDER BY year, auction_item
                    ) AS prev_winner
                FROM (
                    SELECT DISTINCT ON (auction_item)
                        auction_item, "códigoitem", year,
                        cnpj_raiz_n, has_active_cartel
                    FROM pairs WHERE flagvencedor = 1
                ) w
                LEFT JOIN (
                    SELECT cnpj_raiz,
                        CASE WHEN conduct_type = 'hub_and_spoke_cartel'
                            THEN 'hub_and_spoke' ELSE 'bid_rigging' END AS type_group,
                        start_yr, end_yr
                    FROM gt
                ) gw ON w.cnpj_raiz_n = gw.cnpj_raiz
                    AND w.year BETWEEN gw.start_yr AND gw.end_yr
                LEFT JOIN (
                    SELECT cnpj_raiz,
                        CASE WHEN conduct_type = 'hub_and_spoke_cartel'
                            THEN 'hub_and_spoke' ELSE 'bid_rigging' END AS type_group,
                        start_yr, end_yr
                    FROM gt
                ) gl ON w.cnpj_raiz_n = gl.cnpj_raiz
                    AND w.year BETWEEN gl.start_yr AND gl.end_yr
            )
            SELECT
                type_group,
                has_active_cartel,
                COUNT(*) AS n,
                AVG(CASE WHEN winner_cnpj = prev_winner THEN 1.0 ELSE 0.0 END) AS incumbency_rate
            FROM ordered
            WHERE prev_winner IS NOT NULL
            GROUP BY type_group, has_active_cartel
            ORDER BY type_group, has_active_cartel
        """).fetchdf()

        for _, row in incumbency.iterrows():
            tg = str(row["type_group"]) if row["type_group"] is not None else "clean"
            active = "cartel" if int(row["has_active_cartel"]) == 1 else "control"
            f.write(f"  {tg:20s} ({active:7s})  "
                    f"incumbency = {float(row['incumbency_rate']):.3f}  "
                    f"N = {int(row['n']):>7,}\n")

    print(f"\n[written] {OUT_REPORT}")
    con.close()
    print(f"Total time: {time.time() - t0:.1f}s")
    print("\n--- report ---")
    print(OUT_REPORT.read_text())


if __name__ == "__main__":
    main()
