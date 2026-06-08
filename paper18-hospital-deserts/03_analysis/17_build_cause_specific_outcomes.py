"""
17_build_cause_specific_outcomes.py

Painel município × ano × causa para 5 outcomes onde o canal de acesso
(travel-time, referral) tem janela terapêutica curta — isto é, onde
a teoria prediz que o embedding deveria bater km se tem qualquer
informação além de homofilia regional.

Causas:
  ami       — I21*  (infarto agudo miocárdio)         cap 75
  stroke    — I60-64 (cerebrovascular agudo)          cap 75
  sepsis    — A40-41 (septicemias bacterianas)        cap 75
  maternal  — O00-99 (causas obstétricas)             sem cap
  perinatal — P00-09 (afecções perinatais)            sem cap

Cap idade segue Nolte-McKee: <75 quando aplicável, sem cap em causas
maternas e perinatais. Centenários (5XX) excluídos universalmente.

Output: 02_data/intermediate/cause_specific_mortality.parquet
  Schema: codmun_6 (str), year (i32), cause (categorical), n_deaths (i64),
          pop (f64), rate_per100k (f64).

Uso:  python 03_analysis/17_build_cause_specific_outcomes.py [--force]
"""

from __future__ import annotations

import argparse
import logging
import sys
import time
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
RAW_SIM = ROOT / "02_data" / "raw" / "sim"
INTER = ROOT / "02_data" / "intermediate"
LOG = ROOT / "04_logs"
INTER.mkdir(parents=True, exist_ok=True)
LOG.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "17_cause_specific.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("cause_spec")

OUT = INTER / "cause_specific_mortality.parquet"
POP = INTER / "pop_municipal_2015_2025.parquet"

# (cause, sql_predicate_on_CAUSABAS_prefix3, age_cap)
CAUSES = [
    ("ami",       "SUBSTR(CAUSABAS, 1, 3) = 'I21'",                                   75),
    ("stroke",    "SUBSTR(CAUSABAS, 1, 3) IN ('I60','I61','I62','I63','I64')",         75),
    ("sepsis",    "SUBSTR(CAUSABAS, 1, 3) IN ('A40','A41')",                           75),
    ("maternal",  "SUBSTR(CAUSABAS, 1, 1) = 'O'",                                       None),
    ("perinatal", "SUBSTR(CAUSABAS, 1, 3) BETWEEN 'P00' AND 'P09'",                    None),
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true", help="Reprocessa mesmo com output existente")
    args = ap.parse_args()

    if OUT.exists() and not args.force:
        log.info("output já existe (%s) — usar --force pra reprocessar", OUT)
        return

    t0 = time.time()
    log.info("==== begin cause-specific outcomes build ====")

    files = []
    for y in range(2010, 2024):
        files.extend(sorted(RAW_SIM.glob(f"do*{y}.parquet")))
    files_sql = "[" + ", ".join(f"'{f}'" for f in files) + "]"
    log.info("input files: %d (SIM 2010–2023)", len(files))

    con = duckdb.connect()
    con.execute("PRAGMA threads=12")
    con.execute("PRAGMA memory_limit='14GB'")
    con.execute("PRAGMA temp_directory='/tmp/duckdb_paper18'")

    log.info("[1/3] varredura SIM 2010–2023 + decode IDADE...")
    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE sim_clean AS
        SELECT
            CAST(SUBSTR(DTOBITO, 5, 4) AS INTEGER) AS year,
            LPAD(CODMUNRES, 6, '0') AS codmun_6,
            CAUSABAS,
            CASE
                WHEN SUBSTR(IDADE, 1, 1) = '4' THEN CAST(SUBSTR(IDADE, 2, 2) AS INTEGER)
                ELSE NULL
            END AS idade_anos,
            CASE WHEN SUBSTR(IDADE, 1, 1) IN ('1','2','3') THEN TRUE ELSE FALSE END AS is_subanual,
            CASE WHEN SUBSTR(IDADE, 1, 1) = '5' THEN TRUE ELSE FALSE END AS is_centenarian
        FROM read_parquet({files_sql}, union_by_name=true)
        WHERE CAUSABAS IS NOT NULL
          AND CODMUNRES IS NOT NULL
          AND DTOBITO IS NOT NULL
          AND LENGTH(DTOBITO) = 8
          AND CAST(SUBSTR(DTOBITO, 5, 4) AS INTEGER) BETWEEN 2010 AND 2023
    """)
    n_total = con.sql("SELECT COUNT(*) FROM sim_clean WHERE NOT is_centenarian").fetchone()[0]
    log.info("    SIM 2010-2023 limpo (sem centenários): %s óbitos", f"{n_total:,}")

    log.info("[2/3] aplicando filtros causa × idade-cap por cause...")
    case_clauses = []
    for cause, predicate, cap in CAUSES:
        if cap is None:
            cond = predicate
        else:
            cond = (
                f"({predicate} AND "
                f"((idade_anos IS NOT NULL AND idade_anos < {cap}) OR is_subanual = TRUE))"
            )
        case_clauses.append(f"WHEN {cond} THEN '{cause}'")
    case_sql = "CASE\n        " + "\n        ".join(case_clauses) + "\n    END"

    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE sim_flagged AS
        SELECT codmun_6, year,
               {case_sql} AS cause
        FROM sim_clean
        WHERE NOT is_centenarian
    """)
    cause_summary = con.sql("""
        SELECT cause, COUNT(*) AS n
        FROM sim_flagged
        WHERE cause IS NOT NULL
        GROUP BY cause ORDER BY n DESC
    """).pl()
    log.info("\n=== contagem 2010-2023 por causa ===\n%s", cause_summary)

    log.info("[3/3] agregando por (codmun_6, year, cause) + join pop...")
    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE pop AS
        SELECT
            SUBSTR(cod_mun, 1, 6) AS codmun_6,
            ano AS year,
            pop
        FROM read_parquet('{POP}')
    """)
    con.execute(f"""
        COPY (
            WITH agg AS (
                SELECT codmun_6, year, cause, COUNT(*) AS n_deaths
                FROM sim_flagged
                WHERE cause IS NOT NULL
                GROUP BY codmun_6, year, cause
            )
            SELECT
                a.codmun_6,
                a.year,
                a.cause,
                a.n_deaths,
                p.pop,
                CASE WHEN p.pop > 0
                     THEN 1.0 * a.n_deaths / p.pop * 100000
                     ELSE NULL END AS rate_per100k
            FROM agg a
            LEFT JOIN pop p USING (codmun_6, year)
            ORDER BY codmun_6, year, cause
        ) TO '{OUT}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    n_rows = con.sql(f"SELECT COUNT(*) FROM read_parquet('{OUT}')").fetchone()[0]
    log.info("    rows escritas: %s", f"{n_rows:,}")

    log.info("\n=== summary by year × cause (mean rate) ===")
    summ = con.sql(f"""
        SELECT year, cause,
               COUNT(*) AS n_munis,
               SUM(n_deaths) AS deaths_total,
               AVG(rate_per100k) AS mean_rate
        FROM read_parquet('{OUT}')
        GROUP BY year, cause
        ORDER BY year, cause
    """).pl()
    log.info("\n%s", summ)

    log.info("==== done ==== elapsed %.1fs", time.time() - t0)


if __name__ == "__main__":
    main()
