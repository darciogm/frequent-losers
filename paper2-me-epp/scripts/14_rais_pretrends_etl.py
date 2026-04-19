"""
14_rais_pretrends_etl.py — Build firm-year employment panel for pre-trends.

Inputs:
  - data/processed/paper2_me_epp.parquet  (winners' cnpj_fornecedor)
  - ../paper4-thresholds/RAIS/parquet/estb/BR_{2009..2017}_ESTB.parquet

Output:
  - data/processed/p2_rais_firmyear.parquet (cnpj_raiz x year, emp summed)

Includes BEC pre-period classification (g65_wins, other_wins, treated).
"""
from __future__ import annotations
import duckdb
import time
from pathlib import Path

P2      = Path("/home/darciogm1/projetos/bitter-pills/paper2-me-epp")
P4_RAIS = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds/RAIS/parquet")
P2_PARQ = P2 / "data/processed/paper2_me_epp.parquet"
# 2011-2017: standardized schema ("CNPJ Raiz", "Qtd Vínculos Ativos").
# 2009-2010 use legacy columns (RADIC CNPJ, ESTOQUE) and are excluded.
ESTB_FILES = [str(P4_RAIS / f"estb/BR_{y}_ESTB.parquet") for y in range(2011, 2018)]
OUT = P2 / "data/processed/p2_rais_firmyear.parquet"


def main():
    t0 = time.time()
    con = duckdb.connect()
    con.sql("PRAGMA threads=12")
    con.sql("PRAGMA memory_limit='14GB'")
    con.sql("PRAGMA temp_directory='/tmp/duckdb_spill'")

    print("[1/3] Classifying firms from BEC pre-period wins")
    con.sql(f"""
        CREATE OR REPLACE TEMP TABLE firm_class AS
        WITH src AS (
            SELECT cnpj_fornecedor,
                   CASE WHEN regexp_matches(cnpj_fornecedor, '^[0-9]{{14}}$')
                        THEN substr(cnpj_fornecedor, 1, 8) END AS cnpj_raiz,
                   data_oc_numb, oc_item_status, codigogrupo
            FROM read_parquet('{P2_PARQ}')
            WHERE cnpj_fornecedor IS NOT NULL
              AND data_oc_numb < 698
              AND oc_item_status = 1
        )
        SELECT cnpj_raiz,
               SUM(CASE WHEN CAST(codigogrupo AS VARCHAR) = '65' THEN 1 ELSE 0 END) AS g65_wins,
               SUM(CASE WHEN CAST(codigogrupo AS VARCHAR) <> '65' THEN 1 ELSE 0 END) AS other_wins,
               COUNT(*)                                              AS n_pre_wins
        FROM src
        WHERE cnpj_raiz IS NOT NULL
        GROUP BY cnpj_raiz
    """)

    n_classified = con.sql("""
        SELECT SUM(CASE WHEN g65_wins > 0 THEN 1 ELSE 0 END) AS treated,
               SUM(CASE WHEN g65_wins = 0 AND other_wins > 0 THEN 1 ELSE 0 END) AS control
        FROM firm_class
    """).fetchdf()
    print(f"      treated={int(n_classified.treated[0]):,} | "
          f"control={int(n_classified.control[0]):,}")

    print("[2/3] Aggregating RAIS ESTB 2009-2017 by cnpj_raiz x year")
    con.sql(f"""
        CREATE OR REPLACE TEMP TABLE rais_panel AS
        SELECT LPAD(CAST("CNPJ Raiz" AS VARCHAR), 8, '0') AS cnpj_raiz,
               ano                                        AS year,
               SUM("Qtd Vínculos Ativos")                 AS emp
        FROM read_parquet({ESTB_FILES})
        WHERE "CNPJ Raiz" IS NOT NULL
          AND LPAD(CAST("CNPJ Raiz" AS VARCHAR), 8, '0') IN
              (SELECT cnpj_raiz FROM firm_class
               WHERE g65_wins > 0 OR other_wins > 0)
        GROUP BY 1, 2
    """)
    n_rp = con.sql("SELECT COUNT(*) FROM rais_panel").fetchone()[0]
    print(f"      RAIS panel rows (firm-years with emp>0 in RAIS): {n_rp:,}")

    print(f"[3/3] Building balanced panel (9-year grid with zero-fill) → {OUT.name}")
    con.sql(f"""
        COPY (
            WITH firms AS (
                SELECT cnpj_raiz,
                       CASE WHEN g65_wins > 0 THEN 1
                            WHEN other_wins > 0 THEN 0 END AS treated
                FROM firm_class
                WHERE g65_wins > 0 OR other_wins > 0
            ),
            years AS (SELECT UNNEST(GENERATE_SERIES(2011, 2017)) AS year),
            grid  AS (SELECT f.cnpj_raiz, f.treated, y.year
                      FROM firms f CROSS JOIN years y)
            SELECT g.cnpj_raiz,
                   g.year,
                   g.treated,
                   COALESCE(r.emp, 0) AS emp
            FROM grid g
            LEFT JOIN rais_panel r USING (cnpj_raiz, year)
        ) TO '{OUT}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    n_out = con.sql(
        f"SELECT COUNT(*) FROM read_parquet('{OUT}')"
    ).fetchone()[0]
    print(f"      Balanced panel rows: {n_out:,}  ({time.time()-t0:.1f}s total)")


if __name__ == "__main__":
    main()
