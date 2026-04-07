#!/usr/bin/env python3
"""
20_build_rolling_edges.py — Rolling-window worker-flow edges (M4)

Purpose
-------
Fix the look-ahead bias in 17_worker_flow_network_screen.py by building
a separate firm-firm worker-flow edge file for each auction year,
using only RAIS mobility from a backward window [max(2009, t-3), t-1].

An auction in year t is therefore matched against edges that capture
worker mobility BEFORE the auction, never after.

Engine
------
DuckDB (per project convention for parquet manipulation). Self-joins
that would OOM in polars eager stream naturally in DuckDB with
PRAGMA memory_limit.

Window choice
-------------
3-year backward window [max(2009, t-3), t-1]. Tighter than 5 years to
(i) give 2010-2012 a non-empty window, (ii) capture recent mobility
which is most relevant for cartel coordination.

For t=2009: SKIP (no backward history available).
For t=2010: window = [2009] (1 year).
For t=2011: window = [2009, 2010] (2 years).
For t=2012+: window = [t-3, t-1] (full 3 years).

Outputs
-------
  02_data/firms/rolling_edges/edges_y{year}.parquet
  02_data/intermediate/rolling_edges_summary.txt
"""
from __future__ import annotations

import os
import socket
import time
from pathlib import Path

import duckdb
import psutil

BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")
BEC_CNPJ_LIST = BASE / "02_data" / "bec_cnpj_list.parquet"
VINCULOS_DIR  = BASE / "RAIS" / "parquet" / "harmonized"
OUT_DIR       = BASE / "02_data" / "firms" / "rolling_edges"
OUT_REPORT    = BASE / "02_data" / "intermediate" / "rolling_edges_summary.txt"

AUCTION_YEARS = list(range(2010, 2018))  # 2010..2017
RAIS_YEARS_AVAILABLE = set(range(2009, 2018))
# WINDOW_TYPE: "rolling" (fixed window) or "cumulative" (all years before t)
WINDOW_TYPE = os.environ.get("WINDOW_TYPE", "cumulative")
WINDOW_YEARS = int(os.environ.get("WINDOW_YEARS", "3"))   # only for rolling


def log_mem(label: str, t0: float) -> None:
    rss = psutil.Process(os.getpid()).memory_info().rss / 1024**3
    free = psutil.virtual_memory().available / 1024**3
    print(f"  [mem {time.time()-t0:6.1f}s] {label:45s} rss={rss:5.2f} GiB free={free:5.2f} GiB",
          flush=True)


def compute_window(t: int) -> list[int]:
    """Return the backward RAIS years used for auction year t.
    If WINDOW_TYPE='cumulative', all years [2009, t-1] are used.
    If WINDOW_TYPE='rolling', only [max(2009, t-WINDOW_YEARS), t-1]."""
    hi = t - 1
    if WINDOW_TYPE == "cumulative":
        lo = 2009
    else:
        lo = max(2009, t - WINDOW_YEARS)
    if lo > hi:
        return []
    return [y for y in range(lo, hi + 1) if y in RAIS_YEARS_AVAILABLE]


def build_edges_for_year(con: duckdb.DuckDBPyConnection, t: int) -> dict:
    window = compute_window(t)
    if not window:
        return {"year": t, "window": [], "skipped": True}

    out_path = OUT_DIR / f"edges_y{t}.parquet"
    rais_paths = [str(VINCULOS_DIR / f"rais_vinculos_{y}.parquet") for y in window]
    rais_glob = "[" + ", ".join(f"'{p}'" for p in rais_paths) + "]"

    print(f"\n[year {t}] window={window} ({len(window)}y)", flush=True)
    t0 = time.time()

    # Step 1: build (pis, cnpj_raiz) unique for window, restricted to BEC firms.
    # DuckDB streams the scan so this doesn't materialize all RAIS in memory.
    con.sql(f"""
        CREATE OR REPLACE TEMP TABLE pis_firm_{t} AS
        SELECT DISTINCT pis, cnpj_raiz
        FROM read_parquet({rais_glob})
        WHERE pis IS NOT NULL AND pis > 0
          AND cnpj_raiz IS NOT NULL
          AND cnpj_raiz IN (SELECT DISTINCT LPAD(cnpj_raiz, 8, '0') FROM read_parquet('{BEC_CNPJ_LIST}'))
    """)
    n_pairs = con.sql(f"SELECT COUNT(*) FROM pis_firm_{t}").fetchone()[0]
    log_mem(f"year {t}: (pis, firm) pairs = {n_pairs:,}", t0)

    # Step 2: cap PIS at 2-30 firms in window (drop single-firm and hyper-mobile)
    con.sql(f"""
        CREATE OR REPLACE TEMP TABLE pis_multi_{t} AS
        SELECT pis, COUNT(DISTINCT cnpj_raiz) AS n_firms
        FROM pis_firm_{t}
        GROUP BY pis
        HAVING COUNT(DISTINCT cnpj_raiz) BETWEEN 2 AND 30
    """)
    n_multi = con.sql(f"SELECT COUNT(*) FROM pis_multi_{t}").fetchone()[0]
    log_mem(f"year {t}: multi-firm PIS = {n_multi:,}", t0)

    if n_multi == 0:
        print(f"  [year {t}] no multi-firm PIS, skipping edges", flush=True)
        return {"year": t, "window": window, "skipped": True,
                "n_pairs": n_pairs, "n_multi_pis": 0, "n_edges": 0}

    # Step 3: firm sizes in this window (for Jaccard)
    con.sql(f"""
        CREATE OR REPLACE TEMP TABLE firm_size_{t} AS
        SELECT cnpj_raiz, COUNT(*) AS n_workers_ever
        FROM pis_firm_{t}
        GROUP BY cnpj_raiz
    """)

    # Step 4: firm-firm edges via self-join on PIS (capped)
    con.sql(f"""
        CREATE OR REPLACE TEMP TABLE edges_{t} AS
        SELECT
          a.cnpj_raiz AS cnpj_a,
          b.cnpj_raiz AS cnpj_b,
          COUNT(*) AS shared_workers
        FROM pis_firm_{t} a
        JOIN pis_firm_{t} b ON a.pis = b.pis AND a.cnpj_raiz < b.cnpj_raiz
        WHERE a.pis IN (SELECT pis FROM pis_multi_{t})
        GROUP BY a.cnpj_raiz, b.cnpj_raiz
    """)
    n_edges = con.sql(f"SELECT COUNT(*) FROM edges_{t}").fetchone()[0]
    log_mem(f"year {t}: firm-firm edges = {n_edges:,}", t0)

    # Step 5: attach firm sizes and compute jaccard, write parquet
    con.sql(f"""
        COPY (
            SELECT
              e.cnpj_a, e.cnpj_b, e.shared_workers,
              fa.n_workers_ever AS n_workers_a,
              fb.n_workers_ever AS n_workers_b,
              e.shared_workers::DOUBLE /
                (fa.n_workers_ever + fb.n_workers_ever - e.shared_workers)
                AS jaccard,
              {t} AS auction_year
            FROM edges_{t} e
            JOIN firm_size_{t} fa ON e.cnpj_a = fa.cnpj_raiz
            JOIN firm_size_{t} fb ON e.cnpj_b = fb.cnpj_raiz
        ) TO '{out_path}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    log_mem(f"year {t}: written {out_path.name}", t0)

    # Drop temp tables to free memory before next year
    for tbl in [f"pis_firm_{t}", f"pis_multi_{t}", f"firm_size_{t}", f"edges_{t}"]:
        con.sql(f"DROP TABLE IF EXISTS {tbl}")

    return {
        "year": t,
        "window": window,
        "skipped": False,
        "n_pairs": n_pairs,
        "n_multi_pis": n_multi,
        "n_edges": n_edges,
        "bytes": out_path.stat().st_size,
        "elapsed": round(time.time() - t0, 1),
    }


def main() -> None:
    t_global = time.time()
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    print("=" * 70)
    print(f"Rolling-window worker-flow edges — Track A / M4")
    print(f"Run at: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Host: {socket.gethostname()}  PID: {os.getpid()}")
    vm = psutil.virtual_memory()
    print(f"RAM total: {vm.total/1024**3:.1f} GiB free: {vm.available/1024**3:.1f} GiB")
    print(f"Auction years: {AUCTION_YEARS}  Window: [max(2009,t-{WINDOW_YEARS}), t-1]")
    print("=" * 70)

    con = duckdb.connect()
    con.sql("PRAGMA threads=12")
    con.sql("PRAGMA memory_limit='14GB'")
    con.sql("PRAGMA temp_directory='/tmp/duckdb_spill'")
    Path("/tmp/duckdb_spill").mkdir(exist_ok=True)

    summaries = []
    for t in AUCTION_YEARS:
        try:
            s = build_edges_for_year(con, t)
            summaries.append(s)
        except Exception as e:
            print(f"  [ERROR year {t}] {e}", flush=True)
            summaries.append({"year": t, "error": str(e)})

    # Write summary
    OUT_REPORT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT_REPORT, "w") as f:
        f.write(f"Rolling-window edges — {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")
        f.write(f"Window: [max(2009, t-{WINDOW_YEARS}), t-1]\n\n")
        f.write(f"{'Year':<6} {'Window':<20} {'PIS×Firm':>12} {'MultiPIS':>10} "
                f"{'Edges':>10} {'MB':>8} {'Sec':>6}\n")
        for s in summaries:
            if s.get("skipped"):
                f.write(f"{s['year']:<6} [skipped / empty]\n")
                continue
            if "error" in s:
                f.write(f"{s['year']:<6} [ERROR] {s['error']}\n")
                continue
            window_str = f"{min(s['window'])}-{max(s['window'])}"
            f.write(f"{s['year']:<6} {window_str:<20} {s['n_pairs']:>12,} "
                    f"{s['n_multi_pis']:>10,} {s['n_edges']:>10,} "
                    f"{s['bytes']/1e6:>7.1f} {s['elapsed']:>6.1f}\n")

    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)
    with open(OUT_REPORT) as f:
        print(f.read())
    print(f"Total time: {time.time()-t_global:.1f}s")


if __name__ == "__main__":
    main()
