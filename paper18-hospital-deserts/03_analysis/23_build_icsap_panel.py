"""
23_build_icsap_panel.py

Painel município × ano de hospitalizações por causas sensíveis a atenção
primária (ICSAP), usando a lista canônica da Portaria MS 221/2008
(reaproveitada do script 17c). ICSAP é o outcome canônico de access-to-
care na literatura brasileira (Macinko et al. 2018, Dourado et al. 2011)
e captura piora de cuidado primário/ambulatorial via internações que
deveriam ter sido prevenidas pelo PHC.

Outcome: icsap_per1k = 1000 × n_internacoes_ICSAP / pop

Output: 02_data/intermediate/icsap_panel.parquet
  Schema: codmun_6, year, n_icsap, n_total, icsap_per1k, pop
"""

from __future__ import annotations

import argparse
import logging
import sys
import time
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
RAW_SIH = ROOT / "02_data" / "raw" / "sih_rd"
INTER = ROOT / "02_data" / "intermediate"
LOG = ROOT / "04_logs"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "23_build_icsap_panel.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("icsap")

OUT = INTER / "icsap_panel.parquet"
POP = INTER / "pop_municipal_2015_2025.parquet"

# Mesma lista do 17c (Portaria MS 221/2008)
ICSAP_PREFIXES = [
    "A33","A34","A35","A36","A37","A95","B05","B06","B16","B26","B77","G00",
    "A00","A01","A02","A03","A04","A05","A06","A07","A08","A09","E86",
    "D50","E40","E41","E42","E43","E44","E45","E46","E50","E51","E52","E53",
    "E54","E55","E56","E58","E59","E60","E61","E63","E64",
    "H66","J00","J01","J02","J03","J06","J31",
    "J13","J14","J15","J16","J18",
    "J45","J46","J20","J21","J40","J41","J42","J43","J44","J47",
    "I10","I11","I20","I50","J81","I63","I64","I65","I66","I67","I69","G45","G46",
    "E10","E11","E12","E13","E14","G40","G41",
    "N10","N11","N12","N30","N34","A46","L01","L02","L03","L04","L08",
    "N70","N71","N72","N73","N75","N76","K25","K26","K27","K28",
    "O23","A50",
]
ICSAP_SET_SQL = "(" + ", ".join(f"'{p}'" for p in ICSAP_PREFIXES) + ")"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    if OUT.exists() and not args.force:
        log.info("output já existe — usar --force para reprocessar")
        return

    t0 = time.time()
    log.info("==== begin icsap panel build ====")

    files = []
    for y in range(2010, 2025):
        yy = f"{y % 100:02d}"
        files.extend(sorted(RAW_SIH.glob(f"rd*{yy}??.parquet")))
    files_sql = "[" + ", ".join(f"'{f}'" for f in files) + "]"
    log.info("SIH-RD files: %d (2010-2024)", len(files))

    con = duckdb.connect()
    con.execute("PRAGMA threads=12")
    con.execute("PRAGMA memory_limit='14GB'")
    con.execute("PRAGMA temp_directory='/tmp/duckdb_paper18'")

    log.info("[1/3] varredura SIH-RD ...")
    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE sih_clean AS
        SELECT
            CAST(ANO_CMPT AS INTEGER)         AS year,
            LPAD(MUNIC_RES, 6, '0')           AS codmun_6,
            SUBSTR(DIAG_PRINC, 1, 3)          AS cid3
        FROM read_parquet({files_sql}, union_by_name=true)
        WHERE MUNIC_RES IS NOT NULL
          AND ANO_CMPT IS NOT NULL
          AND CAST(ANO_CMPT AS INTEGER) BETWEEN 2010 AND 2024
    """)
    n_aih = con.sql("SELECT COUNT(*) FROM sih_clean").fetchone()[0]
    log.info("    AIH limpas: %s", f"{n_aih:,}")

    log.info("[2/3] agregando ICSAP por (codmun, year)...")
    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE sih_agg AS
        SELECT codmun_6, year,
               COUNT(*) AS n_total,
               SUM(CASE WHEN cid3 IN {ICSAP_SET_SQL} THEN 1 ELSE 0 END) AS n_icsap
        FROM sih_clean
        GROUP BY codmun_6, year
    """)

    log.info("[3/3] join pop e gravar...")
    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE pop AS
        SELECT SUBSTR(cod_mun, 1, 6) AS codmun_6, ano AS year, pop
        FROM read_parquet('{POP}')
        WHERE ano BETWEEN 2010 AND 2024
    """)
    con.execute(f"""
        COPY (
            SELECT
                a.codmun_6,
                a.year,
                a.n_icsap,
                a.n_total,
                p.pop,
                CASE WHEN p.pop > 0
                     THEN 1000.0 * a.n_icsap / p.pop
                     ELSE NULL END AS icsap_per1k,
                CASE WHEN a.n_total > 0
                     THEN 100.0 * a.n_icsap / a.n_total
                     ELSE NULL END AS icsap_share_pct
            FROM sih_agg a
            LEFT JOIN pop p USING (codmun_6, year)
            ORDER BY codmun_6, year
        ) TO '{OUT}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    n_out = con.sql(f"SELECT COUNT(*) FROM read_parquet('{OUT}')").fetchone()[0]
    log.info("    rows: %s", f"{n_out:,}")

    log.info("\n=== summary by year ===")
    summ = con.sql(f"""
        SELECT year,
               COUNT(*) AS n_munis,
               SUM(n_icsap) AS icsap_total,
               SUM(n_total) AS aih_total,
               1.0 * SUM(n_icsap) / SUM(n_total) AS icsap_share,
               AVG(icsap_per1k) AS icsap_per1k_mean,
               STDDEV(icsap_per1k) AS icsap_per1k_sd
        FROM read_parquet('{OUT}')
        GROUP BY year ORDER BY year
    """).pl()
    log.info("\n%s", summ)

    log.info("==== done ==== elapsed %.1fs", time.time() - t0)


if __name__ == "__main__":
    main()
