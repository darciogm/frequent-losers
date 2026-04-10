#!/usr/bin/env python3
"""
26_cumulative_edges_auc.py — Cumulative backward worker-flow edges + AUCs

Purpose
-------
The decisive temporal-bias test. For each auction at year t, count shared
workers using ONLY RAIS observations from years strictly before t:
    window = [2009, t-1]   (cumulative backward, no look-ahead)

This sits between:
- Full-panel [2009-2017]: overstates signal via look-ahead (AUC 0.75)
- Rolling [t-3, t-1]:     understates signal via short memory (AUC 0.54)

Approach
--------
1. Build (PIS, cnpj_raiz, first_year) from RAIS 2009-2017, filtered to BEC firms.
   first_year = earliest year the worker appeared at that firm.
2. Self-join on PIS to get all (firm_a, firm_b, PIS) triples.
3. For each shared worker, compute availability_year = max(first_year_a, first_year_b).
   The worker is "available" for detecting auctions in year > availability_year.
4. Build an edge table: (cnpj_a, cnpj_b, availability_year, shared_workers_cumulative).
5. Join to the auction benchmark: for auction year t, count shared workers with
   availability_year < t.
6. Compute AUCs: overall, per-cartel, leave-one-out.

Output
------
- 02_data/intermediate/cumulative_edges_auc.txt
- 02_data/intermediate/cumulative_edges_auc.csv
"""
from __future__ import annotations

import time
from math import sqrt
from pathlib import Path

import numpy as np
import duckdb

BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")
RAIS_DIR = BASE / "RAIS" / "parquet" / "harmonized"
FINAL = BASE / "02_data" / "final"
FIRMS = BASE / "02_data" / "firms"
INTER = BASE / "02_data" / "intermediate"

BEC_FIRMS    = BASE / "02_data" / "bec_cnpj_list.parquet"
PAIRS_PREGAO = FINAL / "df_pregao_with_cartel_flags.parquet"
SCREENS      = FINAL / "auction_screens_pregao.parquet"
GROUND_TRUTH = FIRMS / "cade_ground_truth.parquet"

OUT_REPORT = INTER / "cumulative_edges_auc.txt"
OUT_CSV    = INTER / "cumulative_edges_auc.csv"

MV_BANDWIDTH = 0.10


# ── AUC (numpy, same as scripts 23-25) ──────────────────────────────────────

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


def main() -> None:
    t0 = time.time()
    INTER.mkdir(parents=True, exist_ok=True)

    con = duckdb.connect()
    con.sql("PRAGMA threads=12")
    con.sql("PRAGMA memory_limit='14GB'")
    con.sql("PRAGMA temp_directory='/tmp/duckdb_spill'")

    # ── Step 1: Build (PIS, cnpj_raiz, first_year) from RAIS ────────────────

    print("Step 1: Building (PIS, firm, first_year) from RAIS 2009-2017...",
          flush=True)

    rais_glob = str(RAIS_DIR / "rais_vinculos_*.parquet")
    bec_path = str(BEC_FIRMS)

    con.sql(f"""
        CREATE OR REPLACE TABLE worker_firm AS
        SELECT
            pis,
            cnpj_raiz,
            MIN(ano) AS first_year
        FROM read_parquet('{rais_glob}') r
        WHERE cnpj_raiz IN (SELECT cnpj_raiz FROM read_parquet('{bec_path}'))
          AND pis IS NOT NULL
          AND cnpj_raiz IS NOT NULL
        GROUP BY pis, cnpj_raiz
    """)

    stats = con.sql("SELECT count(*) AS n, count(DISTINCT pis) AS n_pis, "
                     "count(DISTINCT cnpj_raiz) AS n_firms FROM worker_firm").fetchone()
    print(f"  worker-firm pairs: {stats[0]:,}  "
          f"({stats[1]:,} workers, {stats[2]:,} firms)")

    # ── Step 2: Filter to PIS with 2-30 firms (same as script 17) ───────────

    print("Step 2: Filtering to PIS with 2-30 firms...", flush=True)
    con.sql("""
        CREATE OR REPLACE TABLE worker_firm_filtered AS
        SELECT wf.*
        FROM worker_firm wf
        JOIN (
            SELECT pis, count(DISTINCT cnpj_raiz) AS n_firms
            FROM worker_firm
            GROUP BY pis
            HAVING n_firms BETWEEN 2 AND 30
        ) pf ON wf.pis = pf.pis
    """)
    stats2 = con.sql("SELECT count(*) AS n, count(DISTINCT pis) AS n_pis "
                      "FROM worker_firm_filtered").fetchone()
    print(f"  after filter: {stats2[0]:,} pairs ({stats2[1]:,} workers)")

    # ── Step 3: Self-join to get shared-worker edges with availability year ──

    print("Step 3: Self-join → shared-worker edges with availability year...",
          flush=True)

    con.sql("""
        CREATE OR REPLACE TABLE shared_edges AS
        SELECT
            CASE WHEN a.cnpj_raiz < b.cnpj_raiz THEN a.cnpj_raiz ELSE b.cnpj_raiz END AS cnpj_a,
            CASE WHEN a.cnpj_raiz < b.cnpj_raiz THEN b.cnpj_raiz ELSE a.cnpj_raiz END AS cnpj_b,
            a.pis,
            GREATEST(a.first_year, b.first_year) AS availability_year
        FROM worker_firm_filtered a
        JOIN worker_firm_filtered b ON a.pis = b.pis AND a.cnpj_raiz < b.cnpj_raiz
    """)
    n_edges = con.sql("SELECT count(*) FROM shared_edges").fetchone()[0]
    print(f"  shared-worker triples: {n_edges:,}")

    # ── Step 4: Build auction benchmark with cartel identity ─────────────────

    print("Step 4: Building auction benchmark...", flush=True)
    pairs_path = str(PAIRS_PREGAO)
    screens_path = str(SCREENS)
    gt_path = str(GROUND_TRUTH)

    con.sql(f"""
        CREATE OR REPLACE TABLE pairs_raw AS
        SELECT *,
            LPAD(CAST("códigofornecedor" AS VARCHAR), 14, '0')[1:8] AS cnpj_raiz_n
        FROM read_parquet('{pairs_path}')
        WHERE ABS(MV) < {MV_BANDWIDTH}
    """)

    # Winners
    con.sql("""
        CREATE OR REPLACE TABLE winners AS
        SELECT DISTINCT ON (auction_item)
            auction_item, numerodaoc, "códigoitem", year,
            cnpj_raiz_n AS winner_cnpj,
            has_any_cartel_firm, has_active_cartel,
            both_cartel_firm, both_cartel_active
        FROM pairs_raw
        WHERE flagvencedor = 1
    """)

    # Losers (runner-up)
    con.sql("""
        CREATE OR REPLACE TABLE losers AS
        SELECT DISTINCT ON (auction_item)
            auction_item,
            cnpj_raiz_n AS loser_cnpj
        FROM pairs_raw
        WHERE flagvencedor = 0
    """)

    # Auctions
    con.sql("""
        CREATE OR REPLACE TABLE auctions AS
        SELECT
            w.*,
            l.loser_cnpj,
            CASE WHEN w.winner_cnpj < l.loser_cnpj THEN w.winner_cnpj ELSE l.loser_cnpj END AS cnpj_a,
            CASE WHEN w.winner_cnpj < l.loser_cnpj THEN l.loser_cnpj ELSE w.winner_cnpj END AS cnpj_b
        FROM winners w
        JOIN losers l ON w.auction_item = l.auction_item
    """)

    n_auctions = con.sql("SELECT count(*) FROM auctions").fetchone()[0]
    print(f"  auctions: {n_auctions:,}")

    # Attach cartel identity
    con.sql(f"""
        CREATE OR REPLACE TABLE gt_expanded AS
        SELECT
            cnpj_raiz, processo, setor,
            UNNEST(generate_series(cartel_start_year::INT, cartel_end_year::INT)) AS year
        FROM read_parquet('{gt_path}')
        WHERE sp_relevant = 1
          AND processo IS NOT NULL
          AND cartel_start_year IS NOT NULL
    """)

    con.sql("""
        CREATE OR REPLACE TABLE auctions_with_cartel AS
        SELECT
            a.*,
            COALESCE(gw.setor, gl.setor) AS cartel_setor,
            COALESCE(gw.processo, gl.processo) AS cartel_processo
        FROM auctions a
        LEFT JOIN gt_expanded gw ON a.winner_cnpj = gw.cnpj_raiz AND a.year = gw.year
        LEFT JOIN gt_expanded gl ON a.loser_cnpj = gl.cnpj_raiz AND a.year = gl.year
    """)

    # Attach classical screens
    con.sql(f"""
        CREATE OR REPLACE TABLE screens AS
        SELECT
            numerodaoc || '_' || "códigoitem" AS auction_item,
            cv_bid, spread, mv, n_firms
        FROM read_parquet('{screens_path}')
    """)

    con.sql("""
        CREATE OR REPLACE TABLE auctions_full AS
        SELECT a.*, s.cv_bid, s.spread, s.n_firms
        FROM auctions_with_cartel a
        LEFT JOIN screens s ON a.auction_item = s.auction_item
    """)

    # ── Step 5: Compute cumulative shared workers per auction ────────────────

    print("Step 5: Computing cumulative shared workers per auction...",
          flush=True)

    con.sql("""
        CREATE OR REPLACE TABLE auction_edges AS
        SELECT
            af.auction_item,
            af.year,
            af.cnpj_a,
            af.cnpj_b,
            af.has_active_cartel,
            af.has_any_cartel_firm,
            af.cartel_setor,
            af.cv_bid,
            af.n_firms,
            COALESCE(e.shared_workers_cum, 0) AS shared_workers,
            COALESCE(e.n_workers_a, 0) AS n_workers_a,
            COALESCE(e.n_workers_b, 0) AS n_workers_b
        FROM auctions_full af
        LEFT JOIN (
            -- For each (cnpj_a, cnpj_b, auction_year), count workers
            -- available before the auction year
            SELECT
                se.cnpj_a,
                se.cnpj_b,
                af2.year AS auction_year,
                COUNT(DISTINCT se.pis) AS shared_workers_cum,
                NULL AS n_workers_a,
                NULL AS n_workers_b
            FROM shared_edges se
            JOIN (SELECT DISTINCT cnpj_a, cnpj_b, year FROM auctions_full) af2
                ON se.cnpj_a = af2.cnpj_a AND se.cnpj_b = af2.cnpj_b
            WHERE se.availability_year < af2.year
            GROUP BY se.cnpj_a, se.cnpj_b, af2.year
        ) e ON af.cnpj_a = e.cnpj_a AND af.cnpj_b = e.cnpj_b AND af.year = e.auction_year
    """)

    # Compute Jaccard (need per-firm worker counts cumulative)
    # For simplicity, use shared_workers as the primary screen; Jaccard requires
    # firm-level cumulative counts which adds complexity. Shared workers is the
    # more interpretable metric anyway.
    con.sql("""
        ALTER TABLE auction_edges ADD COLUMN jaccard DOUBLE DEFAULT 0.0
    """)

    print("  done. Fetching results...", flush=True)

    # ── Step 6: Fetch to numpy and compute AUCs ─────────────────────────────

    df = con.sql("""
        SELECT auction_item, year, has_active_cartel, has_any_cartel_firm,
               cartel_setor, cv_bid, n_firms, shared_workers
        FROM auction_edges
    """).fetchnumpy()

    # Convert to workable arrays
    has_active = np.array(df["has_active_cartel"], dtype=float)
    has_any = np.array(df["has_any_cartel_firm"], dtype=float)
    sw = np.array(df["shared_workers"], dtype=float)
    cv = np.array(df["cv_bid"], dtype=float)
    nf = np.array(df["n_firms"], dtype=float)
    setor = np.array(df["cartel_setor"])  # object array

    treat_mask = has_active == 1
    clean_mask = has_any == 0

    sw_treat = sw[treat_mask]
    sw_clean = sw[clean_mask]
    cv_treat = cv[treat_mask]
    cv_clean = cv[clean_mask]
    nf_treat = nf[treat_mask]
    nf_clean = nf[clean_mask]

    rows = []

    with open(OUT_REPORT, "w") as f:
        f.write(f"Cumulative Backward Edges [2009, t-1] — AUC Analysis\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"MV bandwidth: {MV_BANDWIDTH}\n")
        f.write("=" * 70 + "\n\n")

        f.write(f"Total auctions: {len(sw):,}\n")
        f.write(f"Cartel-active:  {int(treat_mask.sum()):,}\n")
        f.write(f"Clean control:  {int(clean_mask.sum()):,}\n\n")

        # Mean shared workers
        f.write(f"Mean shared workers (cumulative):\n")
        f.write(f"  Cartel-active: {sw_treat.mean():.2f}\n")
        f.write(f"  Clean control: {sw_clean.mean():.2f}\n\n")

        # ── Overall AUCs ────────────────────────────────────────────────────

        f.write("OVERALL AUCs (cumulative edges)\n")
        f.write("-" * 50 + "\n")

        for screen_name, t_vals, c_vals, direction in [
            ("shared_workers", sw_treat, sw_clean, "higher_is_cartel"),
            ("cv_bid", cv_treat, cv_clean, "lower_is_cartel"),
            ("n_firms", nf_treat, nf_clean, "lower_is_cartel"),
        ]:
            r = compute_auc(t_vals, c_vals, direction)
            f.write(f"  {screen_name:20s}  AUC={r['auc']:.3f}  "
                    f"N_t={r['n_t']:,}  N_c={r['n_c']:,}\n")
            rows.append(dict(analysis="overall", cartel="ALL",
                             screen=screen_name, **r))

        # ── Comparison table: full vs rolling vs cumulative ─────────────────

        f.write("\n\nCOMPARISON: Full-panel vs Rolling vs Cumulative\n")
        f.write("-" * 60 + "\n")
        f.write("(Full-panel and rolling from script 25; cumulative from this script)\n\n")

        sw_auc_cum = compute_auc(sw_treat, sw_clean, "higher_is_cartel")["auc"]
        f.write(f"  Shared workers AUC:\n")
        f.write(f"    Full-panel [2009-2017]:     0.750  (from script 25)\n")
        f.write(f"    Rolling [t-3, t-1]:         0.536  (from script 25)\n")
        f.write(f"    Cumulative [2009, t-1]:     {sw_auc_cum:.3f}  ← THIS SCRIPT\n\n")

        # ── Per-cartel AUCs ─────────────────────────────────────────────────

        f.write("PER-CARTEL AUCs (cumulative edges)\n")
        f.write("-" * 70 + "\n")

        # Get unique cartels
        unique_setors = sorted(set(s for s in setor[treat_mask] if s is not None))

        f.write(f"{'Cartel':30s} {'N_t':>6s}  {'SW AUC':>7s}  "
                f"{'CV AUC':>7s}  {'Nfirm AUC':>9s}\n")
        f.write("-" * 70 + "\n")

        for s in unique_setors:
            cartel_mask = treat_mask & (setor == s)
            sw_c = sw[cartel_mask]
            cv_c = cv[cartel_mask]
            nf_c = nf[cartel_mask]
            r_sw = compute_auc(sw_c, sw_clean, "higher_is_cartel")
            r_cv = compute_auc(cv_c, cv_clean, "lower_is_cartel")
            r_nf = compute_auc(nf_c, nf_clean, "lower_is_cartel")
            f.write(f"{s:30s} {r_sw['n_t']:>6,}  {r_sw['auc']:>7.3f}  "
                    f"{r_cv['auc']:>7.3f}  {r_nf['auc']:>9.3f}\n")
            for sn, r in [("shared_workers", r_sw), ("cv_bid", r_cv), ("n_firms", r_nf)]:
                rows.append(dict(analysis="per_cartel", cartel=s, screen=sn, **r))

        # ALL row
        r_sw_all = compute_auc(sw_treat, sw_clean, "higher_is_cartel")
        r_cv_all = compute_auc(cv_treat, cv_clean, "lower_is_cartel")
        r_nf_all = compute_auc(nf_treat, nf_clean, "lower_is_cartel")
        f.write(f"{'ALL':30s} {r_sw_all['n_t']:>6,}  {r_sw_all['auc']:>7.3f}  "
                f"{r_cv_all['auc']:>7.3f}  {r_nf_all['auc']:>9.3f}\n\n")

        # ── Leave-one-out ───────────────────────────────────────────────────

        f.write("LEAVE-ONE-OUT AUCs (cumulative edges)\n")
        f.write("-" * 70 + "\n")
        f.write(f"{'Dropped':30s} {'N_t':>6s}  {'SW AUC':>7s}  "
                f"{'CV AUC':>7s}  {'Nfirm AUC':>9s}\n")
        f.write("-" * 70 + "\n")

        for s in unique_setors:
            loo_mask = treat_mask & (setor != s)
            sw_l = sw[loo_mask]
            cv_l = cv[loo_mask]
            nf_l = nf[loo_mask]
            r_sw = compute_auc(sw_l, sw_clean, "higher_is_cartel")
            r_cv = compute_auc(cv_l, cv_clean, "lower_is_cartel")
            r_nf = compute_auc(nf_l, nf_clean, "lower_is_cartel")
            f.write(f"drop {s:26s} {r_sw['n_t']:>6,}  {r_sw['auc']:>7.3f}  "
                    f"{r_cv['auc']:>7.3f}  {r_nf['auc']:>9.3f}\n")
            for sn, r in [("shared_workers", r_sw), ("cv_bid", r_cv), ("n_firms", r_nf)]:
                rows.append(dict(analysis="leave_one_out", cartel=f"drop_{s}",
                                 screen=sn, **r))

        # ── Year-by-year AUCs ───────────────────────────────────────────────

        f.write("\nYEAR-BY-YEAR AUCs (cumulative edges, shared workers)\n")
        f.write("-" * 50 + "\n")

        years = np.array(df["year"], dtype=float)
        for y in sorted(set(years[~np.isnan(years)])):
            yr = int(y)
            yr_treat = treat_mask & (years == y)
            yr_clean = clean_mask & (years == y)
            if yr_treat.sum() < 2 or yr_clean.sum() < 2:
                continue
            r = compute_auc(sw[yr_treat], sw[yr_clean], "higher_is_cartel")
            f.write(f"  {yr}  N_t={r['n_t']:>5,}  N_c={r['n_c']:>7,}  "
                    f"AUC={r['auc']:.3f}\n")

    print(f"\n[written] {OUT_REPORT}")

    # Write CSV
    import csv
    with open(OUT_CSV, "w", newline="") as cf:
        if rows:
            w = csv.DictWriter(cf, fieldnames=list(rows[0].keys()))
            w.writeheader()
            w.writerows(rows)
    print(f"[written] {OUT_CSV}")

    con.close()
    print(f"\nTotal time: {time.time() - t0:.1f}s")
    print("\n--- report preview ---")
    print(OUT_REPORT.read_text())


if __name__ == "__main__":
    main()
