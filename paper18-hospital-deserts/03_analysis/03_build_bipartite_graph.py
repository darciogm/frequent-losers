"""
03_build_bipartite_graph.py

Constrói o grafo bipartido paciente -> hospital a partir do SIH-RD (AIH
reduzida) 2015-2024. Cada aresta = (município_residência, hospital_CNES,
ano) com peso = nº internações.

Output:
- 02_data/intermediate/bipartite_edges.parquet   (anual, 2015-2024)
- 02_data/intermediate/bipartite_edges_pooled.parquet (2015-2022 pooled)

Filtros:
- Apenas hospitais no universo (hospital_master, ~15k CNES com leitos ou TP_UNID hospitalar).
- MUNIC_RES e CNES não nulos.
- Internações com COBRANCA != fraude/glosa (filtro mínimo).

Stack: DuckDB out-of-core, 12 threads, 14 GB.
"""

from __future__ import annotations

import logging
import sys
import time
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "02_data" / "raw" / "sih_rd"
INTER = ROOT / "02_data" / "intermediate"
LOG = ROOT / "04_logs"
INTER.mkdir(parents=True, exist_ok=True)
LOG.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "03_build_bipartite_graph.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("graph")

OUT_ANNUAL = INTER / "bipartite_edges.parquet"
OUT_POOLED = INTER / "bipartite_edges_pooled.parquet"
HOSP_MASTER = INTER / "hospital_master.parquet"


def main():
    t0 = time.time()
    log.info("==== begin bipartite graph build ====")

    # selecionar arquivos por ano (range YY 15..24, pegando rdNNyymm.parquet)
    files = []
    for y in range(2010, 2025):
        yy = f"{y % 100:02d}"
        files.extend(sorted(RAW.glob(f"rd*{yy}??.parquet")))
    log.info("input files: %d (SIH-RD 2010-2024)", len(files))
    files_sql = "[" + ", ".join(f"'{f}'" for f in files) + "]"

    con = duckdb.connect()
    con.execute("PRAGMA threads=12")
    con.execute("PRAGMA memory_limit='14GB'")
    con.execute("PRAGMA temp_directory='/tmp/duckdb_paper18'")

    # ---- 1) varredura SIH-RD + filtro ----------------------------------
    log.info("[1/3] varredura SIH-RD + filtros...")
    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE internacoes AS
        SELECT
            CAST(ANO_CMPT AS INTEGER)              AS year,
            LPAD(MUNIC_RES, 6, '0')                AS codmun_6,
            CNES,
            -- morte intra-internação flag (0/1)
            CASE WHEN MORTE IN ('1', 1) THEN 1 ELSE 0 END AS morte,
            CAST(VAL_TOT AS DOUBLE)                AS val_tot,
            CAST(DIAS_PERM AS INTEGER)             AS dias_perm,
            DIAG_PRINC                             AS cid_princ
        FROM read_parquet({files_sql}, union_by_name=true)
        WHERE MUNIC_RES IS NOT NULL
          AND CNES IS NOT NULL
          AND ANO_CMPT IS NOT NULL
          AND CAST(ANO_CMPT AS INTEGER) BETWEEN 2010 AND 2024
    """)
    n_int = con.sql("SELECT COUNT(*) FROM internacoes").fetchone()[0]
    log.info("    internações brutas: %s", f"{n_int:,}")

    # ---- 2) filtrar para universo hospitalar ---------------------------
    log.info("[2/3] filtro p/ universo de hospitais (hospital_master)...")
    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE hosp_universe AS
        SELECT CNES FROM read_parquet('{HOSP_MASTER}')
    """)
    n_hosp = con.sql("SELECT COUNT(*) FROM hosp_universe").fetchone()[0]
    log.info("    universo hospitalar: %s CNES", f"{n_hosp:,}")

    con.execute("""
        CREATE OR REPLACE TEMP TABLE internacoes_hosp AS
        SELECT i.* FROM internacoes i
        SEMI JOIN hosp_universe h ON h.CNES = i.CNES
    """)
    n_int_hosp = con.sql("SELECT COUNT(*) FROM internacoes_hosp").fetchone()[0]
    log.info("    internações com CNES no universo: %s (%.1f%% do bruto)",
             f"{n_int_hosp:,}", 100.0 * n_int_hosp / n_int)

    # ---- 3) agregar por (codmun, CNES, year) ---------------------------
    log.info("[3/3] agregando arestas (codmun_6, CNES, year)...")
    con.execute(f"""
        COPY (
            SELECT
                codmun_6,
                CNES,
                year,
                COUNT(*)            AS n_internacoes,
                SUM(morte)          AS n_mortes,
                SUM(val_tot)        AS val_tot_soma,
                AVG(val_tot)        AS val_tot_medio,
                AVG(dias_perm)      AS dias_perm_medio
            FROM internacoes_hosp
            GROUP BY codmun_6, CNES, year
            HAVING COUNT(*) >= 1
            ORDER BY codmun_6, CNES, year
        ) TO '{OUT_ANNUAL}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    n_edges = con.sql(f"SELECT COUNT(*) FROM read_parquet('{OUT_ANNUAL}')").fetchone()[0]
    log.info("    arestas anuais: %s", f"{n_edges:,}")

    # versão pooled 2015-2022 (período de análise)
    con.execute(f"""
        COPY (
            SELECT
                codmun_6,
                CNES,
                COUNT(*)            AS n_internacoes,
                SUM(morte)          AS n_mortes,
                SUM(val_tot)        AS val_tot_soma,
                AVG(val_tot)        AS val_tot_medio,
                AVG(dias_perm)      AS dias_perm_medio
            FROM internacoes_hosp
            WHERE year BETWEEN 2010 AND 2024
            GROUP BY codmun_6, CNES
            HAVING COUNT(*) >= 1
            ORDER BY codmun_6, CNES
        ) TO '{OUT_POOLED}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    n_edges_p = con.sql(f"SELECT COUNT(*) FROM read_parquet('{OUT_POOLED}')").fetchone()[0]
    log.info("    arestas pooled 2010-24: %s", f"{n_edges_p:,}")

    # ---- sanity ---------------------------------------------------------
    log.info("\n=== summary anual ===")
    summary = con.sql(f"""
        SELECT year,
               COUNT(*)                 AS n_edges,
               COUNT(DISTINCT codmun_6) AS n_munis,
               COUNT(DISTINCT CNES)     AS n_hospitais,
               SUM(n_internacoes)       AS total_int,
               SUM(n_mortes)            AS total_mortes,
               1.0 * SUM(n_mortes) / SUM(n_internacoes) AS mort_rate
        FROM read_parquet('{OUT_ANNUAL}')
        GROUP BY year ORDER BY year
    """).pl()
    log.info("\n%s", summary)

    log.info("\n=== top 10 hospitais 2018 (n_internacoes recebidas) ===")
    top = con.sql(f"""
        SELECT CNES, year,
               SUM(n_internacoes) AS total_int,
               COUNT(DISTINCT codmun_6) AS n_munis_origem
        FROM read_parquet('{OUT_ANNUAL}')
        WHERE year = 2018
        GROUP BY CNES, year
        ORDER BY total_int DESC LIMIT 10
    """).pl()
    log.info("\n%s", top)

    log.info("==== done ==== elapsed %.1fs (%.1f min)",
             time.time() - t0, (time.time() - t0) / 60)


if __name__ == "__main__":
    main()
