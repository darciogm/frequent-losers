#!/usr/bin/env python3
"""
19_outlier_investigation.py — Investigate worker-flow edge outliers

Purpose
-------
The skew diagnostic in 18_worker_flow_robustness.py revealed that the
control distribution for convite shared_workers has max=4954 (while the
treat distribution tops out at 82). This single outlier drives the
within-CNAE AUC from the expected 0.70-ish down to 0.5001.

This script identifies:
  (1) The top firm-pairs by shared_workers (the 4954 case and neighbors)
  (2) The top firm-pairs by jaccard (where a value of 1.0 appears —
      likely same-group firms or merger artifacts)
  (3) Cross-references with Firms_final.parquet to get razão social
      and CNAE, so we know WHAT these firms are.

Decision support: after seeing who the outliers are, we decide between
  - winsorize shared_workers at p99.5
  - exclude the specific pair
  - exclude all firms with n_workers > threshold (e.g., > 50k)

Per project convention: DuckDB as engine for parquet.
"""
from __future__ import annotations

import time
from pathlib import Path

import duckdb

BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")
EDGES = BASE / "02_data" / "firms" / "firm_firm_worker_flow_edges.parquet"
FIRMS = BASE / "02_data" / "firms" / "Firms_final.parquet"
OUT = BASE / "02_data" / "intermediate" / "outlier_investigation.txt"


def main() -> None:
    t0 = time.time()
    con = duckdb.connect()
    con.sql("PRAGMA threads=12")
    con.sql("PRAGMA memory_limit='12GB'")

    print("=" * 70)
    print(f"Worker-flow outlier investigation — {time.strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 70)

    # Edge summary
    print("\n[1] Edge summary statistics")
    con.sql(f"""
        SELECT
          COUNT(*) AS n_edges,
          MIN(shared_workers) AS sw_min,
          MAX(shared_workers) AS sw_max,
          QUANTILE_CONT(shared_workers, 0.50) AS sw_p50,
          QUANTILE_CONT(shared_workers, 0.99) AS sw_p99,
          QUANTILE_CONT(shared_workers, 0.999) AS sw_p999,
          MAX(jaccard) AS j_max,
          QUANTILE_CONT(jaccard, 0.99) AS j_p99
        FROM read_parquet('{EDGES}')
    """).show()

    # Build a firm name lookup by cnpj_raiz (first 8 of códigofornecedor)
    print("\n[2] Building firm-name lookup from Firms_final...")
    con.sql(f"""
        CREATE OR REPLACE TABLE firms AS
        SELECT DISTINCT
          SUBSTR(LPAD(códigofornecedor, 14, '0'), 1, 8) AS cnpj_raiz,
          FIRST(descriçãorazãosocial ORDER BY códigofornecedor) AS razao,
          FIRST(cnae_descr ORDER BY códigofornecedor) AS cnae,
          FIRST(descriçãouffornecedor ORDER BY códigofornecedor) AS uf
        FROM read_parquet('{FIRMS}')
        GROUP BY 1
    """)
    print(f"  {con.sql('SELECT COUNT(*) FROM firms').fetchone()[0]:,} unique cnpj_raiz")

    # Top 20 by shared_workers
    print("\n[3] TOP 20 firm-pairs by shared_workers (raw)")
    top_sw = con.sql(f"""
        SELECT
          e.cnpj_a, e.cnpj_b, e.shared_workers, e.jaccard,
          e.n_workers_a, e.n_workers_b,
          fa.razao AS razao_a, fa.cnae AS cnae_a,
          fb.razao AS razao_b, fb.cnae AS cnae_b
        FROM read_parquet('{EDGES}') e
        LEFT JOIN firms fa ON e.cnpj_a = fa.cnpj_raiz
        LEFT JOIN firms fb ON e.cnpj_b = fb.cnpj_raiz
        ORDER BY e.shared_workers DESC
        LIMIT 20
    """).pl()
    print(top_sw)

    # Top 20 by jaccard (filtering out tiny overlaps to avoid noise)
    print("\n[4] TOP 20 firm-pairs by jaccard (shared_workers ≥ 5)")
    top_j = con.sql(f"""
        SELECT
          e.cnpj_a, e.cnpj_b, e.shared_workers, e.jaccard,
          e.n_workers_a, e.n_workers_b,
          fa.razao AS razao_a, fa.cnae AS cnae_a,
          fb.razao AS razao_b, fb.cnae AS cnae_b
        FROM read_parquet('{EDGES}') e
        LEFT JOIN firms fa ON e.cnpj_a = fa.cnpj_raiz
        LEFT JOIN firms fb ON e.cnpj_b = fb.cnpj_raiz
        WHERE e.shared_workers >= 5
        ORDER BY e.jaccard DESC
        LIMIT 20
    """).pl()
    print(top_j)

    # Firms that appear MANY times in top-shared_workers edges
    # (if a single firm is in many outlier edges, it's a hub = temp agency)
    print("\n[5] Firms that appear in many high-shared_workers edges")
    hubs = con.sql(f"""
        WITH high_edges AS (
            SELECT cnpj_a, cnpj_b, shared_workers
            FROM read_parquet('{EDGES}')
            WHERE shared_workers >= 100
        ),
        degree AS (
            SELECT cnpj_raiz, COUNT(*) AS n_high_edges, MAX(shared_workers) AS max_sw
            FROM (
                SELECT cnpj_a AS cnpj_raiz, shared_workers FROM high_edges
                UNION ALL
                SELECT cnpj_b AS cnpj_raiz, shared_workers FROM high_edges
            )
            GROUP BY cnpj_raiz
        )
        SELECT d.*, f.razao, f.cnae
        FROM degree d
        LEFT JOIN firms f ON d.cnpj_raiz = f.cnpj_raiz
        ORDER BY n_high_edges DESC
        LIMIT 20
    """).pl()
    print(hubs)

    # Distribution of firm-level max-shared-workers
    print("\n[6] How extreme is the distribution?")
    dist = con.sql(f"""
        SELECT
          COUNT(*) FILTER (WHERE shared_workers >= 100) AS n_ge_100,
          COUNT(*) FILTER (WHERE shared_workers >= 500) AS n_ge_500,
          COUNT(*) FILTER (WHERE shared_workers >= 1000) AS n_ge_1000,
          COUNT(*) FILTER (WHERE shared_workers >= 4000) AS n_ge_4000,
          COUNT(*) FILTER (WHERE jaccard >= 0.9) AS n_jaccard_ge_09,
          COUNT(*) FILTER (WHERE jaccard = 1.0) AS n_jaccard_eq_1
        FROM read_parquet('{EDGES}')
    """).pl()
    print(dist)

    # Write full report to file
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT, "w") as f:
        f.write(f"Worker-flow outlier investigation — {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")
        f.write("TOP 20 by shared_workers:\n")
        f.write(str(top_sw) + "\n\n")
        f.write("TOP 20 by jaccard (shared_workers >= 5):\n")
        f.write(str(top_j) + "\n\n")
        f.write("Hub firms (n edges with shared_workers >= 100):\n")
        f.write(str(hubs) + "\n\n")
        f.write("Extreme-value counts:\n")
        f.write(str(dist) + "\n")
    print(f"\n[written] {OUT}")
    print(f"Total time: {time.time()-t0:.1f}s")


if __name__ == "__main__":
    main()
