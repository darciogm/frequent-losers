#!/usr/bin/env python3
"""
27_temporal_decomposition.py — Temporal decomposition of worker flows

Purpose
-------
For each cartel, decompose shared workers between cartel firms and BEC rivals
into three temporal windows:
  - PRE-CONDUCT:    worker moved before cartel_start_year
  - DURING-CONDUCT: worker moved during [start, end]
  - POST-CONDUCT:   worker moved after cartel_end_year (but within RAIS 2009-2017)

"Moved" = max(first_year_at_firm_A, first_year_at_firm_B), i.e., the year
when the worker first appeared at BOTH firms.

Also measures:
  - DIRECTIONALITY: cartel→rival (first at cartel, then at rival) vs.
                    rival→cartel (first at rival, then at cartel)
  - AUCs by temporal window: do pre-conduct flows carry detection signal?

Output
------
- 02_data/intermediate/temporal_decomposition.txt
- 02_data/intermediate/temporal_decomposition.csv
- 04_figures/worker_flow_timing.pdf (event-study style figure)
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
SCREENS      = str(FINAL / "auction_screens_pregao.parquet")
GROUND_TRUTH = str(FIRMS / "cade_ground_truth.parquet")

OUT_REPORT = INTER / "temporal_decomposition.txt"
OUT_CSV    = INTER / "temporal_decomposition.csv"
OUT_FIGURE = FIGS / "worker_flow_timing.pdf"

MV_BANDWIDTH = 0.10


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
    FIGS.mkdir(parents=True, exist_ok=True)

    con = duckdb.connect()
    con.sql("PRAGMA threads=12")
    con.sql("PRAGMA memory_limit='14GB'")
    con.sql("PRAGMA temp_directory='/tmp/duckdb_spill'")

    rais_glob = str(RAIS_DIR / "rais_vinculos_*.parquet")

    # ── Step 1: Build (PIS, firm, first_year) ────────────────────────────────

    print("Step 1: Building worker-firm panel...", flush=True)
    con.sql(f"""
        CREATE OR REPLACE TABLE worker_firm AS
        SELECT pis, cnpj_raiz, MIN(ano) AS first_year
        FROM read_parquet('{rais_glob}')
        WHERE cnpj_raiz IN (SELECT cnpj_raiz FROM read_parquet('{BEC_FIRMS}'))
          AND pis IS NOT NULL AND cnpj_raiz IS NOT NULL
        GROUP BY pis, cnpj_raiz
    """)

    # Filter to PIS with 2-30 firms
    con.sql("""
        CREATE OR REPLACE TABLE worker_firm_f AS
        SELECT wf.*
        FROM worker_firm wf
        SEMI JOIN (
            SELECT pis FROM worker_firm
            GROUP BY pis HAVING count(DISTINCT cnpj_raiz) BETWEEN 2 AND 30
        ) pf ON wf.pis = pf.pis
    """)
    n_wf = con.sql("SELECT count(*) FROM worker_firm_f").fetchone()[0]
    print(f"  worker-firm pairs (filtered): {n_wf:,}")

    # ── Step 2: Load cartel ground truth ─────────────────────────────────────

    print("Step 2: Loading cartel ground truth...", flush=True)
    con.sql(f"""
        CREATE OR REPLACE TABLE cartels AS
        SELECT DISTINCT
            cnpj_raiz, processo, setor,
            cartel_start_year::INT AS start_yr,
            cartel_end_year::INT AS end_yr,
            judgment_year::INT AS judgment_yr
        FROM read_parquet('{GROUND_TRUTH}')
        WHERE sp_relevant = 1 AND processo IS NOT NULL
          AND cartel_start_year IS NOT NULL
    """)

    cartel_info = con.sql("""
        SELECT DISTINCT setor, start_yr, end_yr, judgment_yr,
               count(DISTINCT cnpj_raiz) AS n_firms
        FROM cartels GROUP BY setor, start_yr, end_yr, judgment_yr
        ORDER BY start_yr
    """).fetchall()
    print("  Cartels:")
    for row in cartel_info:
        print(f"    {row[0]:30s} conduct={row[1]}-{row[2]}  "
              f"judgment={row[3]}  firms={row[4]}")

    # ── Step 3: For each cartel firm × rival, classify shared workers ────────

    print("Step 3: Classifying shared worker flows by timing...", flush=True)

    # Get all cartel firm CNPJs
    con.sql("""
        CREATE OR REPLACE TABLE cartel_firms AS
        SELECT DISTINCT cnpj_raiz, setor, start_yr, end_yr
        FROM cartels
    """)

    # Self-join worker_firm_f to get shared workers between cartel firms
    # and ALL other BEC firms, with timing information
    con.sql("""
        CREATE OR REPLACE TABLE shared_flows AS
        SELECT
            cf.setor,
            cf.start_yr,
            cf.end_yr,
            cf.cnpj_raiz AS cartel_cnpj,
            wf_rival.cnpj_raiz AS rival_cnpj,
            wf_cartel.pis,
            wf_cartel.first_year AS first_yr_at_cartel,
            wf_rival.first_year AS first_yr_at_rival,
            GREATEST(wf_cartel.first_year, wf_rival.first_year) AS move_year,
            -- Direction: who had the worker first?
            CASE
                WHEN wf_cartel.first_year < wf_rival.first_year THEN 'cartel_to_rival'
                WHEN wf_cartel.first_year > wf_rival.first_year THEN 'rival_to_cartel'
                ELSE 'simultaneous'
            END AS direction,
            -- Timing relative to conduct period
            CASE
                WHEN GREATEST(wf_cartel.first_year, wf_rival.first_year) < cf.start_yr
                    THEN 'pre_conduct'
                WHEN GREATEST(wf_cartel.first_year, wf_rival.first_year)
                    BETWEEN cf.start_yr AND cf.end_yr
                    THEN 'during_conduct'
                WHEN GREATEST(wf_cartel.first_year, wf_rival.first_year) > cf.end_yr
                    THEN 'post_conduct'
            END AS timing
        FROM cartel_firms cf
        -- Worker observations at cartel firm
        JOIN worker_firm_f wf_cartel ON cf.cnpj_raiz = wf_cartel.cnpj_raiz
        -- Same PIS at a different (non-cartel) firm
        JOIN worker_firm_f wf_rival ON wf_cartel.pis = wf_rival.pis
            AND wf_rival.cnpj_raiz != cf.cnpj_raiz
        -- Exclude intra-cartel pairs (rival is also a cartel firm in same cartel)
        LEFT JOIN cartel_firms cf2 ON wf_rival.cnpj_raiz = cf2.cnpj_raiz
            AND cf2.setor = cf.setor
        WHERE cf2.cnpj_raiz IS NULL
    """)

    n_flows = con.sql("SELECT count(*) FROM shared_flows").fetchone()[0]
    print(f"  total shared-worker flow records: {n_flows:,}")

    # ── Step 4: Aggregate by cartel × timing × direction ─────────────────────

    print("Step 4: Aggregating...", flush=True)

    agg = con.sql("""
        SELECT
            setor, timing, direction,
            count(DISTINCT pis) AS n_workers,
            count(DISTINCT rival_cnpj) AS n_rival_firms
        FROM shared_flows
        WHERE timing IS NOT NULL
        GROUP BY setor, timing, direction
        ORDER BY setor, timing, direction
    """).fetchdf()

    # Also aggregate across all cartels
    agg_all = con.sql("""
        SELECT
            'ALL' AS setor, timing, direction,
            count(DISTINCT pis) AS n_workers,
            count(DISTINCT rival_cnpj) AS n_rival_firms
        FROM shared_flows
        WHERE timing IS NOT NULL
        GROUP BY timing, direction
        ORDER BY timing, direction
    """).fetchdf()

    # Year-by-year flow counts (for figure)
    yearly = con.sql("""
        SELECT
            move_year,
            direction,
            count(DISTINCT pis) AS n_workers
        FROM shared_flows
        WHERE move_year BETWEEN 2009 AND 2017
        GROUP BY move_year, direction
        ORDER BY move_year, direction
    """).fetchdf()

    # Year-by-year by cartel
    yearly_cartel = con.sql("""
        SELECT
            setor,
            move_year,
            count(DISTINCT pis) AS n_workers,
            count(DISTINCT CASE WHEN direction = 'cartel_to_rival'
                THEN pis END) AS n_cartel_to_rival,
            count(DISTINCT CASE WHEN direction = 'rival_to_cartel'
                THEN pis END) AS n_rival_to_cartel
        FROM shared_flows
        WHERE move_year BETWEEN 2009 AND 2017
        GROUP BY setor, move_year
        ORDER BY setor, move_year
    """).fetchdf()

    # ── Step 5: Compute AUCs by temporal window ─────────────────────────────

    print("Step 5: Computing AUCs by temporal window...", flush=True)

    # Build auction benchmark with per-window shared worker counts
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

    # For each auction pair, count shared workers by timing window
    # Need to identify which firm (if any) is cartel and what its conduct period is
    con.sql("""
        CREATE OR REPLACE TABLE auction_cartel AS
        SELECT a.*,
            COALESCE(cw.setor, cl.setor) AS cartel_setor,
            COALESCE(cw.start_yr, cl.start_yr) AS start_yr,
            COALESCE(cw.end_yr, cl.end_yr) AS end_yr,
            CASE WHEN cw.cnpj_raiz IS NOT NULL THEN a.winner_cnpj
                 WHEN cl.cnpj_raiz IS NOT NULL THEN a.loser_cnpj
                 END AS cartel_cnpj_in_pair,
            CASE WHEN cw.cnpj_raiz IS NOT NULL THEN a.loser_cnpj
                 WHEN cl.cnpj_raiz IS NOT NULL THEN a.winner_cnpj
                 END AS rival_cnpj_in_pair
        FROM auctions a
        LEFT JOIN cartel_firms cw ON a.winner_cnpj = cw.cnpj_raiz
            AND a.year BETWEEN cw.start_yr AND cw.end_yr
        LEFT JOIN cartel_firms cl ON a.loser_cnpj = cl.cnpj_raiz
            AND a.year BETWEEN cl.start_yr AND cl.end_yr
    """)

    # For cartel-active auctions, count shared workers in each temporal window
    # using the shared_edges from script 26 approach
    con.sql("""
        CREATE OR REPLACE TABLE auction_window_counts AS
        SELECT
            ac.auction_item,
            ac.has_active_cartel,
            ac.has_any_cartel_firm,
            ac.cartel_setor,
            -- Pre-conduct: shared workers where both appearances are before start_yr
            COALESCE(pre.n_pre, 0) AS sw_pre,
            -- During-conduct
            COALESCE(dur.n_dur, 0) AS sw_during,
            -- Post-conduct
            COALESCE(post.n_post, 0) AS sw_post,
            -- Full panel (all windows)
            COALESCE(pre.n_pre, 0) + COALESCE(dur.n_dur, 0)
                + COALESCE(post.n_post, 0) AS sw_total
        FROM auction_cartel ac
        LEFT JOIN (
            SELECT sf.cartel_cnpj, sf.rival_cnpj, sf.setor,
                   count(DISTINCT sf.pis) AS n_pre
            FROM shared_flows sf
            WHERE sf.timing = 'pre_conduct'
            GROUP BY sf.cartel_cnpj, sf.rival_cnpj, sf.setor
        ) pre ON ac.cartel_cnpj_in_pair = pre.cartel_cnpj
            AND ac.rival_cnpj_in_pair = pre.rival_cnpj
            AND ac.cartel_setor = pre.setor
        LEFT JOIN (
            SELECT sf.cartel_cnpj, sf.rival_cnpj, sf.setor,
                   count(DISTINCT sf.pis) AS n_dur
            FROM shared_flows sf
            WHERE sf.timing = 'during_conduct'
            GROUP BY sf.cartel_cnpj, sf.rival_cnpj, sf.setor
        ) dur ON ac.cartel_cnpj_in_pair = dur.cartel_cnpj
            AND ac.rival_cnpj_in_pair = dur.rival_cnpj
            AND ac.cartel_setor = dur.setor
        LEFT JOIN (
            SELECT sf.cartel_cnpj, sf.rival_cnpj, sf.setor,
                   count(DISTINCT sf.pis) AS n_post
            FROM shared_flows sf
            WHERE sf.timing = 'post_conduct'
            GROUP BY sf.cartel_cnpj, sf.rival_cnpj, sf.setor
        ) post ON ac.cartel_cnpj_in_pair = post.cartel_cnpj
            AND ac.rival_cnpj_in_pair = post.rival_cnpj
            AND ac.cartel_setor = post.setor
    """)

    # Fetch for AUC computation
    df = con.sql("""
        SELECT auction_item, has_active_cartel, has_any_cartel_firm,
               cartel_setor, sw_pre, sw_during, sw_post, sw_total
        FROM auction_window_counts
    """).fetchnumpy()

    treat_mask = np.array(df["has_active_cartel"], dtype=float) == 1
    clean_mask = np.array(df["has_any_cartel_firm"], dtype=float) == 0

    # ── Step 6: Write report ─────────────────────────────────────────────────

    print("Step 6: Writing report...", flush=True)

    with open(OUT_REPORT, "w") as f:
        f.write("Temporal Decomposition of Worker Flows\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")

        # ── A. Aggregate timing × direction ─────────────────────────────────

        f.write("A. WORKER FLOW COUNTS BY TIMING AND DIRECTION\n")
        f.write("   (across all cartels)\n")
        f.write("-" * 60 + "\n")

        import pandas as pd
        pivot = agg_all.pivot_table(
            index="timing", columns="direction",
            values="n_workers", aggfunc="sum", fill_value=0
        )
        # Reorder
        for idx in ["pre_conduct", "during_conduct", "post_conduct"]:
            if idx in pivot.index:
                row = pivot.loc[idx]
                total = row.sum()
                f.write(f"  {idx:20s}")
                for col in sorted(pivot.columns):
                    f.write(f"  {col}={int(row.get(col, 0)):>5,}")
                f.write(f"  TOTAL={int(total):>6,}\n")
        f.write("\n")

        # ── B. Per-cartel timing breakdown ──────────────────────────────────

        f.write("B. PER-CARTEL TIMING BREAKDOWN\n")
        f.write("-" * 70 + "\n")

        for ci in cartel_info:
            setor = ci[0]
            f.write(f"\n  {setor} (conduct {ci[1]}-{ci[2]}, judgment {ci[3]})\n")
            cartel_agg = agg[agg["setor"] == setor]
            for timing in ["pre_conduct", "during_conduct", "post_conduct"]:
                t_rows = cartel_agg[cartel_agg["timing"] == timing]
                if len(t_rows) == 0:
                    f.write(f"    {timing:20s}  (no flows)\n")
                    continue
                total = int(t_rows["n_workers"].sum())
                c2r = int(t_rows[t_rows["direction"] == "cartel_to_rival"]["n_workers"].sum())
                r2c = int(t_rows[t_rows["direction"] == "rival_to_cartel"]["n_workers"].sum())
                sim = int(t_rows[t_rows["direction"] == "simultaneous"]["n_workers"].sum())
                f.write(f"    {timing:20s}  total={total:>5,}  "
                        f"cartel→rival={c2r:>5,}  rival→cartel={r2c:>5,}  "
                        f"simultaneous={sim:>5,}\n")
        f.write("\n")

        # ── C. Year-by-year flows (for figure) ─────────────────────────────

        f.write("C. YEAR-BY-YEAR WORKER FLOWS (all cartels combined)\n")
        f.write("-" * 50 + "\n")
        for _, row in yearly.iterrows():
            f.write(f"  {int(row['move_year'])}  {row['direction']:20s}  "
                    f"n_workers={int(row['n_workers']):>5,}\n")
        f.write("\n")

        # ── D. AUCs by temporal window ──────────────────────────────────────

        f.write("D. AUCs BY TEMPORAL WINDOW\n")
        f.write("-" * 60 + "\n")
        f.write("  (Each window's shared-worker count used as the screen)\n\n")

        f.write(f"{'Window':20s} {'AUC':>7s}  {'N_t':>6s}  {'N_c':>8s}  "
                f"{'Mean_t':>7s}  {'Mean_c':>7s}\n")
        f.write("-" * 60 + "\n")

        csv_rows = []
        for window, col in [("pre_conduct", "sw_pre"),
                            ("during_conduct", "sw_during"),
                            ("post_conduct", "sw_post"),
                            ("full_panel", "sw_total")]:
            vals = np.array(df[col], dtype=float)
            t_vals = vals[treat_mask]
            c_vals = vals[clean_mask]
            r = compute_auc(t_vals, c_vals, "higher_is_cartel")
            mean_t = np.nanmean(t_vals) if len(t_vals) > 0 else 0
            mean_c = np.nanmean(c_vals) if len(c_vals) > 0 else 0
            f.write(f"  {window:20s} {r['auc']:>7.3f}  {r['n_t']:>6,}  "
                    f"{r['n_c']:>8,}  {mean_t:>7.3f}  {mean_c:>7.3f}\n")
            csv_rows.append(dict(
                analysis="window_auc", window=window,
                auc=r["auc"], n_t=r["n_t"], n_c=r["n_c"],
                mean_treat=mean_t, mean_control=mean_c,
            ))

        f.write("\n")

        # ── E. Key comparison table ─────────────────────────────────────────

        f.write("E. COMPARISON: WHICH TEMPORAL WINDOW CARRIES THE SIGNAL?\n")
        f.write("-" * 60 + "\n")
        f.write("  Script 23 (full-panel edges, all years):   AUC = 0.750\n")
        f.write("  Script 26 (cumulative [2009,t-1]):         AUC = 0.524\n")
        f.write("  Script 25 (rolling [t-3,t-1]):             AUC = 0.536\n")
        f.write(f"  This script — pre-conduct flows only:     AUC = "
                f"{csv_rows[0]['auc']:.3f}\n")
        f.write(f"  This script — during-conduct flows only:  AUC = "
                f"{csv_rows[1]['auc']:.3f}\n")
        f.write(f"  This script — post-conduct flows only:    AUC = "
                f"{csv_rows[2]['auc']:.3f}\n")
        f.write(f"  This script — all windows combined:       AUC = "
                f"{csv_rows[3]['auc']:.3f}\n\n")

        # Interpretation
        f.write("INTERPRETATION:\n")
        post_auc = csv_rows[2]["auc"]
        pre_auc = csv_rows[0]["auc"]
        during_auc = csv_rows[1]["auc"]
        if post_auc > 0.6 and pre_auc < 0.55:
            f.write("  → Signal is concentrated in POST-CONDUCT flows.\n")
            f.write("  → Consistent with enforcement-driven labor reallocation.\n")
        elif pre_auc > 0.6:
            f.write("  → Signal is present in PRE-CONDUCT flows.\n")
            f.write("  → Consistent with pre-existing coordination channel.\n")
        else:
            f.write("  → No strong temporal concentration detected.\n")
            f.write("  → Signal may be diffuse across windows.\n")

    print(f"\n[written] {OUT_REPORT}")

    # Write CSV
    import csv
    # Add timing/direction aggregates to CSV
    for _, row in agg_all.iterrows():
        csv_rows.append(dict(
            analysis="flow_count",
            window=row["timing"],
            direction=row["direction"],
            n_workers=int(row["n_workers"]),
        ))
    with open(OUT_CSV, "w", newline="") as cf:
        all_keys = list(dict.fromkeys(k for r in csv_rows for k in r))
        w = csv.DictWriter(cf, fieldnames=all_keys, extrasaction="ignore")
        w.writeheader()
        w.writerows(csv_rows)
    print(f"[written] {OUT_CSV}")

    # ── Step 7: Figure ───────────────────────────────────────────────────────

    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        # Year-by-year flows with conduct period shading
        c2r = yearly[yearly["direction"] == "cartel_to_rival"].set_index("move_year")
        r2c = yearly[yearly["direction"] == "rival_to_cartel"].set_index("move_year")
        years_range = range(2009, 2018)

        fig, ax = plt.subplots(figsize=(9, 5))

        c2r_vals = [int(c2r.loc[y, "n_workers"]) if y in c2r.index else 0
                    for y in years_range]
        r2c_vals = [int(r2c.loc[y, "n_workers"]) if y in r2c.index else 0
                    for y in years_range]

        ax.bar([y - 0.15 for y in years_range], c2r_vals, width=0.3,
               color="#d73027", alpha=0.8, label="Cartel → Rival")
        ax.bar([y + 0.15 for y in years_range], r2c_vals, width=0.3,
               color="#4575b4", alpha=0.8, label="Rival → Cartel")

        # Shade typical conduct periods (most cartels active ~2007-2013)
        ax.axvspan(2008.5, 2013.5, alpha=0.08, color="grey",
                   label="Typical conduct period")

        ax.set_xlabel("Year of worker movement", fontsize=11)
        ax.set_ylabel("Distinct workers", fontsize=11)
        ax.set_xticks(list(years_range))
        ax.legend(loc="upper left", fontsize=9)
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)

        fig.tight_layout()
        fig.savefig(OUT_FIGURE, dpi=300, bbox_inches="tight")
        plt.close(fig)
        print(f"[written] {OUT_FIGURE}")
    except ImportError:
        print("  matplotlib not available; skipping figure")

    con.close()
    print(f"\nTotal time: {time.time() - t0:.1f}s")
    print("\n--- report preview ---")
    print(OUT_REPORT.read_text())


if __name__ == "__main__":
    main()
