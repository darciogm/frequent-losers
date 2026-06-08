"""
17c_build_alt_outcomes.py

Constrói painel município × ano com 5 outcomes alternativos para testar a
tese original do paper (embedding revela acesso além de km), saindo do canal
de mortalidade SIM-residencial que está confessadamente confundido por
under-reporting + cross-border death recording.

Outcomes (cross-section, pooled 2010-2023):

  (α) hospitalization_per1k    = n_internações / pop × 1.000
                                 fonte: bipartite_edges.parquet (já existe)

  (β) in_hosp_mortality_pct    = 100 × n_mortes / n_internações
                                 mortalidade intra-internação, residente
                                 fonte: bipartite_edges.parquet (já existe)

  (γ) urgency_ratio_pct        = 100 × n_internações(CAR_INT=2) / n_total
                                 fonte: SIH-RD raw, varre CAR_INT

  (δ) icsap_per1k              = n_internações(DIAG_PRINC ∈ ICSAP) / pop × 1.000
                                 fonte: SIH-RD raw, lista Portaria MS 221/2008
                                 (versão enxuta com os 19 grupos canônicos)

  (ε) ami_in_hosp_mortality_pct = 100 × n_mortes(I21*) / n_int(I21*)
                                  AMI in-hospital mortality recipient-side
                                  contorna SIM cross-border problem
                                  fonte: SIH-RD raw

Output: 02_data/intermediate/alt_outcomes.parquet
  Schema: codmun_6, year, hosp_per1k, in_hosp_mort_pct, urg_ratio_pct,
          icsap_per1k, ami_inhosp_mort_pct, n_int_total, n_int_ami, pop
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
INTER.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "17c_build_alt_outcomes.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("alt_out")

OUT = INTER / "alt_outcomes.parquet"
EDGES = INTER / "bipartite_edges.parquet"
POP = INTER / "pop_municipal_2015_2025.parquet"

# Lista ICSAP (Portaria MS 221/2008) — prefixos CID-10 de 3 chars dos 19 grupos.
# Versão enxuta: cobertura ~95% das hospitalizações ICSAP. Para detalhe completo
# (sub-itens P35.0, J17.0 etc) ver lista DATASUS/CONASEMS.
ICSAP_PREFIXES = [
    # G1 imunização
    "A33","A34","A35","A36","A37","A95","B05","B06","B16","B26","B77","G00",
    # G2 gastroenterites
    "A00","A01","A02","A03","A04","A05","A06","A07","A08","A09","E86",
    # G3 anemia / G4 nutricionais
    "D50","E40","E41","E42","E43","E44","E45","E46","E50","E51","E52","E53",
    "E54","E55","E56","E58","E59","E60","E61","E63","E64",
    # G5 infecções vias aéreas sup
    "H66","J00","J01","J02","J03","J06","J31",
    # G6 pneumonias bact
    "J13","J14","J15","J16","J18",
    # G7 asma / G8 DPOC
    "J45","J46","J20","J21","J40","J41","J42","J43","J44","J47",
    # G9 hipertensão / G10 angina / G11 IC / G12 cerebrovascular
    "I10","I11","I20","I50","J81","I63","I64","I65","I66","I67","I69","G45","G46",
    # G13 diabetes / G14 epilepsia
    "E10","E11","E12","E13","E14","G40","G41",
    # G15 infecção rim/urinário / G16 pele
    "N10","N11","N12","N30","N34","A46","L01","L02","L03","L04","L08",
    # G17 DIP / G18 ulcera GI
    "N70","N71","N72","N73","N75","N76","K25","K26","K27","K28",
    # G19 doenças relacionadas pré-natal e parto
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
    log.info("==== begin alt outcomes build ====")

    files = []
    for y in range(2010, 2025):
        yy = f"{y % 100:02d}"
        files.extend(sorted(RAW_SIH.glob(f"rd*{yy}??.parquet")))
    files_sql = "[" + ", ".join(f"'{f}'" for f in files) + "]"
    log.info("SIH-RD raw files: %d (2010-2024)", len(files))

    con = duckdb.connect()
    con.execute("PRAGMA threads=12")
    con.execute("PRAGMA memory_limit='14GB'")
    con.execute("PRAGMA temp_directory='/tmp/duckdb_paper18'")

    # ---- 1) hospitalization_rate + in-hospital mortality já saem do bipartite ----
    log.info("[1/4] (α) e (β) de bipartite_edges.parquet ...")
    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE bip_agg AS
        SELECT codmun_6, year,
               SUM(n_internacoes) AS n_int_total,
               SUM(n_mortes)      AS n_mortes_total
        FROM read_parquet('{EDGES}')
        WHERE year BETWEEN 2010 AND 2023
        GROUP BY codmun_6, year
    """)

    # ---- 2) varredura SIH-RD raw para CAR_INT, ICSAP, AMI ---------------
    log.info("[2/4] (γ) (δ) (ε) varrendo SIH-RD raw ... isso leva uns 60-120s")
    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE sih_aux AS
        SELECT
            CAST(ANO_CMPT AS INTEGER)         AS year,
            LPAD(MUNIC_RES, 6, '0')           AS codmun_6,
            CAST(CAR_INT AS VARCHAR)          AS car_int,
            SUBSTR(DIAG_PRINC, 1, 3)          AS cid3,
            CASE WHEN MORTE IN ('1', 1) THEN 1 ELSE 0 END AS morte
        FROM read_parquet({files_sql}, union_by_name=true)
        WHERE MUNIC_RES IS NOT NULL
          AND ANO_CMPT IS NOT NULL
          AND CAST(ANO_CMPT AS INTEGER) BETWEEN 2010 AND 2023
    """)
    n_aux = con.sql("SELECT COUNT(*) FROM sih_aux").fetchone()[0]
    log.info("    SIH raw varrido: %s AIH", f"{n_aux:,}")

    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE sih_outcomes AS
        SELECT codmun_6, year,
               COUNT(*)                                                          AS n_int_check,
               SUM(CASE WHEN car_int IN ('2', '02') THEN 1 ELSE 0 END)          AS n_urg,
               SUM(CASE WHEN cid3 IN {ICSAP_SET_SQL} THEN 1 ELSE 0 END)          AS n_icsap,
               SUM(CASE WHEN cid3 = 'I21' THEN 1 ELSE 0 END)                    AS n_ami,
               SUM(CASE WHEN cid3 = 'I21' AND morte = 1 THEN 1 ELSE 0 END)     AS n_ami_morte
        FROM sih_aux
        GROUP BY codmun_6, year
    """)
    n_rows = con.sql("SELECT COUNT(*) FROM sih_outcomes").fetchone()[0]
    log.info("    sih_outcomes rows: %s", f"{n_rows:,}")

    # ---- 3) population ---------------------------------------------------
    log.info("[3/4] join populacao ...")
    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE pop AS
        SELECT SUBSTR(cod_mun, 1, 6) AS codmun_6, ano AS year, pop
        FROM read_parquet('{POP}')
        WHERE ano BETWEEN 2010 AND 2023
    """)

    # ---- 4) consolidar ---------------------------------------------------
    log.info("[4/4] consolidar e gravar parquet ...")
    con.execute(f"""
        COPY (
            SELECT
                b.codmun_6,
                b.year,
                b.n_int_total,
                CASE WHEN p.pop > 0 THEN 1000.0 * b.n_int_total / p.pop ELSE NULL END AS hosp_per1k,
                CASE WHEN b.n_int_total > 0 THEN 100.0 * b.n_mortes_total / b.n_int_total ELSE NULL END AS in_hosp_mort_pct,
                CASE WHEN s.n_int_check > 0 THEN 100.0 * s.n_urg / s.n_int_check ELSE NULL END AS urg_ratio_pct,
                CASE WHEN p.pop > 0 THEN 1000.0 * s.n_icsap / p.pop ELSE NULL END AS icsap_per1k,
                s.n_ami,
                s.n_ami_morte,
                CASE WHEN s.n_ami > 0 THEN 100.0 * s.n_ami_morte / s.n_ami ELSE NULL END AS ami_inhosp_mort_pct,
                p.pop
            FROM bip_agg b
            LEFT JOIN sih_outcomes s USING (codmun_6, year)
            LEFT JOIN pop p          USING (codmun_6, year)
            ORDER BY codmun_6, year
        ) TO '{OUT}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    n_out = con.sql(f"SELECT COUNT(*) FROM read_parquet('{OUT}')").fetchone()[0]
    log.info("    rows escritas: %s", f"{n_out:,}")

    log.info("\n=== summary by year (mean of outcomes) ===")
    summ = con.sql(f"""
        SELECT year,
               COUNT(*)                                                  AS n_rows,
               AVG(hosp_per1k)                                           AS hosp_per1k_mean,
               AVG(in_hosp_mort_pct)                                     AS in_hosp_mort_pct_mean,
               AVG(urg_ratio_pct)                                        AS urg_ratio_pct_mean,
               AVG(icsap_per1k)                                          AS icsap_per1k_mean,
               AVG(ami_inhosp_mort_pct)                                  AS ami_inhosp_mort_pct_mean
        FROM read_parquet('{OUT}')
        GROUP BY year ORDER BY year
    """).pl()
    log.info("\n%s", summ)

    log.info("==== done ==== elapsed %.1fs", time.time() - t0)


if __name__ == "__main__":
    main()
