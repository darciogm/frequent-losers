"""
20_filter_exogenous_closures.py

Filtra os 3.518 CNES detectados como "fechados" em hospital_closures.parquet
para isolar o subset de fechamentos plausivelmente exógenos para o
event-study CS21.

Filtros (em ordem):
  F1  janela temporal: year_last ∈ {2012..2018} ∪ {2022..2023}
        (exclui pandemia 2020-2021 e bordas de painel)
  F2  tipo de unidade: tp_unid_modal ∈ {05 hospital geral, 07 hospital
        especializado, 15 unidade mista, 62 hospital/dia}
  F3  porte: média de QT_SUS no ano pré-fechamento ≥ 30 leitos SUS
        (excluí hospitais-fantasma e clínicas pequenas)
  F4  massa de produção: total de AIH no ano pré-fechamento ≥ 100
        (excluí estabelecimentos de fato inativos antes do fechamento
         oficial)
  F5  não-demand-driven: AIH no ano pré-fechamento ≥ 50% da média dos 3
        anos anteriores (descarta exit por queda de demanda local)

Limitação não tratada nesta versão: fusões/aquisições (mesmo CNPJ-raiz
reaparecendo em outro CNES no mesmo município). Marcado como tarefa de
robustness post-v1.

Output:
- 02_data/intermediate/hospital_closures_exogenous.parquet
  Schema: CNES, codmun_6, year_closure, tp_unid, qt_sus_pre,
          n_int_t_minus_1, n_int_avg_3y_pre, ratio_pre,
          flag_filter_F1..F5 (bool)
- 04_logs/20_filter_exogenous_closures.log (N após cada filtro)
"""

from __future__ import annotations

import argparse
import logging
import sys
import time
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
RAW_LT = ROOT / "02_data" / "raw" / "cnes_lt"
INTER = ROOT / "02_data" / "intermediate"
LOG = ROOT / "04_logs"
INTER.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "20_filter_exogenous_closures.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("filter_close")

CLOSURES_IN = INTER / "hospital_closures.parquet"
MASTER_IN = INTER / "hospital_master.parquet"
EDGES_IN = INTER / "bipartite_edges.parquet"
OUT = INTER / "hospital_closures_exogenous.parquet"

YEARS_PRE_PANDEMIC = (2012, 2018)
YEARS_POS_PANDEMIC = (2022, 2023)
HOSP_TYPES = ["05", "07", "15", "62"]
QT_SUS_MIN = 30
N_AIH_MIN_PRE = 100
RATIO_DEMAND_MIN = 0.50


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    if OUT.exists() and not args.force:
        log.info("output já existe — usar --force para reprocessar")
        return

    t0 = time.time()
    log.info("==== begin filter exogenous closures ====")

    files = sorted(RAW_LT.glob("*.parquet"))
    files_sql = "[" + ", ".join(f"'{f}'" for f in files) + "]"
    log.info("CNES-LT raw files: %d", len(files))

    con = duckdb.connect()
    con.execute("PRAGMA threads=12")
    con.execute("PRAGMA memory_limit='14GB'")
    con.execute("PRAGMA temp_directory='/tmp/duckdb_paper18'")

    # ---- bed counts CNES × ano (média anual de QT_SUS) ----
    log.info("[1/5] agregando QT_SUS de cnes_lt por (CNES, year)...")
    hosp_types_sql = "(" + ", ".join(f"'{t}'" for t in HOSP_TYPES) + ")"
    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE bed_panel AS
        WITH lt_norm AS (
            SELECT
                CNES,
                CAST(SUBSTR(COMPETEN, 1, 4) AS INTEGER) AS year,
                CAST(QT_SUS AS INTEGER) AS qt_sus
            FROM read_parquet({files_sql}, union_by_name=true)
            WHERE COMPETEN IS NOT NULL
              AND LENGTH(COMPETEN) >= 6
        )
        SELECT CNES, year,
               AVG(qt_sus) AS qt_sus_mean
        FROM lt_norm
        GROUP BY CNES, year
    """)
    n_bed = con.sql("SELECT COUNT(*) FROM bed_panel").fetchone()[0]
    log.info("    bed_panel rows: %s", f"{n_bed:,}")

    # ---- AIH anual por CNES (de bipartite_edges) ----
    log.info("[2/5] agregando AIH/year por CNES de bipartite_edges...")
    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE aih_panel AS
        SELECT CNES, year,
               SUM(n_internacoes) AS n_aih
        FROM read_parquet('{EDGES_IN}')
        GROUP BY CNES, year
    """)
    n_aih = con.sql("SELECT COUNT(*) FROM aih_panel").fetchone()[0]
    log.info("    aih_panel rows: %s", f"{n_aih:,}")

    # ---- merge tudo no closures + master + filtros ----
    log.info("[3/5] aplicando filtros progressivos...")
    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE candidates AS
        WITH base AS (
            SELECT
                c.CNES,
                c.codmun_6,
                c.year_last AS year_closure,
                m.tp_unid_modal AS tp_unid,
                m.codmun_6_modal AS codmun_hosp
            FROM read_parquet('{CLOSURES_IN}') c
            JOIN read_parquet('{MASTER_IN}') m USING (CNES)
        ),
        with_beds AS (
            SELECT b.*,
                   bp.qt_sus_mean AS qt_sus_pre
            FROM base b
            LEFT JOIN bed_panel bp ON bp.CNES = b.CNES AND bp.year = b.year_closure - 1
        ),
        with_aih AS (
            SELECT wb.*,
                   ap1.n_aih AS n_int_t_minus_1,
                   (
                       SELECT AVG(n_aih)
                       FROM aih_panel ap_avg
                       WHERE ap_avg.CNES = wb.CNES
                         AND ap_avg.year BETWEEN wb.year_closure - 4 AND wb.year_closure - 2
                   ) AS n_int_avg_3y_pre
            FROM with_beds wb
            LEFT JOIN aih_panel ap1
                   ON ap1.CNES = wb.CNES AND ap1.year = wb.year_closure - 1
        )
        SELECT *,
               CASE WHEN n_int_avg_3y_pre IS NULL OR n_int_avg_3y_pre = 0 THEN NULL
                    ELSE n_int_t_minus_1 / n_int_avg_3y_pre END AS ratio_pre,
               -- F1 janela
               (year_closure BETWEEN {YEARS_PRE_PANDEMIC[0]} AND {YEARS_PRE_PANDEMIC[1]}
                OR year_closure BETWEEN {YEARS_POS_PANDEMIC[0]} AND {YEARS_POS_PANDEMIC[1]}) AS f1_window,
               -- F2 tipo unidade
               (tp_unid IN {hosp_types_sql}) AS f2_type,
               -- F3 leitos
               (qt_sus_pre IS NOT NULL AND qt_sus_pre >= {QT_SUS_MIN}) AS f3_beds,
               -- F4 massa
               (n_int_t_minus_1 IS NOT NULL AND n_int_t_minus_1 >= {N_AIH_MIN_PRE}) AS f4_mass
        FROM with_aih
    """)

    n_total = con.sql("SELECT COUNT(*) FROM candidates").fetchone()[0]
    log.info("    F0 closures totais: %s", f"{n_total:,}")

    # progressivos para o log
    for label, where in [
        ("F1 (janela)",                  "f1_window"),
        ("F1 + F2 (tipo)",               "f1_window AND f2_type"),
        ("F1 + F2 + F3 (leitos>=30)",    "f1_window AND f2_type AND f3_beds"),
        ("F1+F2+F3+F4 (AIH>=100)",       "f1_window AND f2_type AND f3_beds AND f4_mass"),
    ]:
        n = con.sql(f"SELECT COUNT(*) FROM candidates WHERE {where}").fetchone()[0]
        log.info("    %-30s : %s closures", label, f"{n:,}")

    # ---- F5: não-demand-driven (ratio_pre >= 0.50) ----
    log.info("[4/5] aplicando F5 (ratio_pre >= %.2f)...", RATIO_DEMAND_MIN)
    n_f5 = con.sql(f"""
        SELECT COUNT(*) FROM candidates
        WHERE f1_window AND f2_type AND f3_beds AND f4_mass
          AND ratio_pre IS NOT NULL AND ratio_pre >= {RATIO_DEMAND_MIN}
    """).fetchone()[0]
    log.info("    F1+F2+F3+F4+F5                 : %s closures (FINAL)", f"{n_f5:,}")

    # distribuição final por ano e tipo
    log.info("\n=== distribuição final por ano ===")
    df = con.sql(f"""
        SELECT year_closure, COUNT(*) AS n
        FROM candidates
        WHERE f1_window AND f2_type AND f3_beds AND f4_mass
          AND ratio_pre IS NOT NULL AND ratio_pre >= {RATIO_DEMAND_MIN}
        GROUP BY year_closure ORDER BY year_closure
    """).pl()
    log.info("\n%s", df)

    log.info("\n=== distribuição final por tp_unid ===")
    df = con.sql(f"""
        SELECT tp_unid, COUNT(*) AS n,
               AVG(qt_sus_pre) AS qt_sus_avg,
               AVG(n_int_t_minus_1) AS n_aih_avg
        FROM candidates
        WHERE f1_window AND f2_type AND f3_beds AND f4_mass
          AND ratio_pre IS NOT NULL AND ratio_pre >= {RATIO_DEMAND_MIN}
        GROUP BY tp_unid ORDER BY n DESC
    """).pl()
    log.info("\n%s", df)

    log.info("\n=== distribuição final por região (UF prefix) ===")
    df = con.sql(f"""
        SELECT SUBSTR(codmun_6, 1, 1) AS uf_region, COUNT(*) AS n
        FROM candidates
        WHERE f1_window AND f2_type AND f3_beds AND f4_mass
          AND ratio_pre IS NOT NULL AND ratio_pre >= {RATIO_DEMAND_MIN}
        GROUP BY uf_region ORDER BY uf_region
    """).pl()
    log.info("\n%s", df)

    # ---- escrever output ----
    log.info("[5/5] escrevendo output...")
    con.execute(f"""
        COPY (
            SELECT CNES, codmun_6, year_closure, tp_unid,
                   qt_sus_pre, n_int_t_minus_1, n_int_avg_3y_pre, ratio_pre,
                   f1_window, f2_type, f3_beds, f4_mass,
                   (ratio_pre IS NOT NULL AND ratio_pre >= {RATIO_DEMAND_MIN}) AS f5_not_demand_driven,
                   (f1_window AND f2_type AND f3_beds AND f4_mass
                    AND ratio_pre IS NOT NULL AND ratio_pre >= {RATIO_DEMAND_MIN}) AS exogenous
            FROM candidates
            ORDER BY year_closure, codmun_6, CNES
        ) TO '{OUT}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    log.info("wrote %s", OUT)
    log.info("==== done ==== elapsed %.1fs", time.time() - t0)


if __name__ == "__main__":
    main()
