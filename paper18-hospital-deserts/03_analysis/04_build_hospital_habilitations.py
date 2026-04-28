"""
04_build_hospital_habilitations.py

Constrói painel de habilitações por hospital × competência a partir do CNES-HB
(3564 arquivos UF×mês 2015-2025).

HB = habilitações de alta complexidade (oncologia, cardio, neuro, transplantes,
trauma, urgência, etc.) emitidas via portaria SAS/MS.

Output:
- 02_data/intermediate/hospital_habilitations.parquet
  Schema: CNES, codmun_6, COMPETEN, year, month, SGRUPHAB,
          CMPT_INI, CMPT_FIM, NULEITOS_HAB, ativa_hoje (bool)

- 02_data/intermediate/hospital_hub_classification.parquet
  Para cada CNES, lista de SGRUPHAB ativas em algum momento + agregados
  (é hub oncológico? cardio? neuro? trauma?).
"""

from __future__ import annotations

import logging
import sys
import time
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "02_data" / "raw" / "cnes_hb"
INTER = ROOT / "02_data" / "intermediate"
LOG = ROOT / "04_logs"
INTER.mkdir(parents=True, exist_ok=True)
LOG.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "04_build_hospital_habilitations.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("hb")

OUT_PANEL = INTER / "hospital_habilitations.parquet"
OUT_HUB = INTER / "hospital_hub_classification.parquet"

# Mapeamento SGRUPHAB → categoria macro (baseado em portarias SAS/MS).
# Códigos típicos (3-4 dígitos). Categorias chave para Paper 18:
#   ONCO     - oncologia (CACON, UNACON, alta complexidade tumores)
#   CARDIO   - cardiovascular alta complexidade (cardiologia interv., cirurgia)
#   NEURO    - neurologia, neurocirurgia, AVC, estimulação cerebral
#   TRAUMA   - urgência/emergência, ortopedia, queimados
#   PERINAT  - neonatal, gestação alto risco, UCIN, UTI neonatal
#   RENAL    - terapia renal substitutiva, transplantes renais
#   OUTRO    - demais habilitações
#
# Os primeiros 2 dígitos do SGRUPHAB indicam o eixo:
#   01-04 oncologia, 05-08 cardio, 09-12 neuro, 13-15 ortopedia/trauma,
#   16-18 transplantes, 19+ outros.
# Como a tabela é grande e sujeita a mudanças, classificamos via faixas.
HUB_CATEGORIES_SQL = """
    CASE
        WHEN SGRUPHAB LIKE '00%' OR SGRUPHAB LIKE '01%' OR SGRUPHAB LIKE '02%'
             OR SGRUPHAB LIKE '03%' OR SGRUPHAB LIKE '04%' THEN 'ONCO'
        WHEN SGRUPHAB LIKE '05%' OR SGRUPHAB LIKE '06%' OR SGRUPHAB LIKE '07%'
             OR SGRUPHAB LIKE '08%' THEN 'CARDIO'
        WHEN SGRUPHAB LIKE '09%' OR SGRUPHAB LIKE '10%' OR SGRUPHAB LIKE '11%'
             OR SGRUPHAB LIKE '12%' THEN 'NEURO'
        WHEN SGRUPHAB LIKE '13%' OR SGRUPHAB LIKE '14%' OR SGRUPHAB LIKE '15%' THEN 'TRAUMA_ORTO'
        WHEN SGRUPHAB LIKE '16%' OR SGRUPHAB LIKE '17%' OR SGRUPHAB LIKE '18%' THEN 'TRANSPLANTE'
        WHEN SGRUPHAB LIKE '19%' OR SGRUPHAB LIKE '20%' OR SGRUPHAB LIKE '21%' THEN 'PERINAT'
        WHEN SGRUPHAB LIKE '22%' OR SGRUPHAB LIKE '23%' THEN 'RENAL'
        ELSE 'OUTRO'
    END
"""


def main():
    t0 = time.time()
    log.info("==== begin habilitations build ====")

    n_files = len(list(RAW.glob("hb*.parquet")))
    log.info("input files: %d", n_files)
    glob = str(RAW / "hb*.parquet")

    con = duckdb.connect()
    con.execute("PRAGMA threads=12")
    con.execute("PRAGMA memory_limit='14GB'")

    # ---- 1) painel completo de habilitações ---------------------------
    log.info("[1/2] painel HB...")
    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE hb_panel AS
        SELECT
            CNES,
            LPAD(CODUFMUN, 6, '0')                        AS codmun_6,
            COMPETEN,
            TRY_CAST(SUBSTR(COMPETEN, 1, 4) AS INTEGER)   AS year,
            TRY_CAST(SUBSTR(COMPETEN, 5, 2) AS INTEGER)   AS month,
            SGRUPHAB,
            {HUB_CATEGORIES_SQL}                            AS hub_categoria,
            CMPT_INI,
            CMPT_FIM,
            NULEITOS                                        AS nuleitos_hab,
            -- ativa "hoje" (até a data da competência)
            CASE
                WHEN CMPT_FIM = '999999' OR CMPT_FIM IS NULL THEN TRUE
                WHEN COMPETEN <= CMPT_FIM THEN TRUE
                ELSE FALSE
            END                                             AS ativa,
            DTPORTAR,
            PORTARIA
        FROM read_parquet('{glob}', union_by_name=true)
        WHERE CNES IS NOT NULL
          AND SGRUPHAB IS NOT NULL
          AND COMPETEN IS NOT NULL
          AND LENGTH(COMPETEN) = 6
          AND TRY_CAST(SUBSTR(COMPETEN, 1, 4) AS INTEGER) IS NOT NULL
    """)
    n_panel = con.sql("SELECT COUNT(*) FROM hb_panel").fetchone()[0]
    log.info("    HB panel rows: %s", f"{n_panel:,}")

    # escrever painel completo
    con.execute(f"""
        COPY (
            SELECT CNES, codmun_6, COMPETEN, year, month,
                   SGRUPHAB, hub_categoria,
                   CMPT_INI, CMPT_FIM, nuleitos_hab, ativa,
                   DTPORTAR, PORTARIA
            FROM hb_panel
            ORDER BY CNES, COMPETEN, SGRUPHAB
        ) TO '{OUT_PANEL}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    log.info("    escrito %s", OUT_PANEL)

    # ---- 2) classificação de hubs por CNES ----------------------------
    log.info("[2/2] hub classification por CNES...")
    con.execute(f"""
        COPY (
            WITH per_cnes_cat AS (
                SELECT CNES,
                       MODE(codmun_6) AS codmun_6,
                       hub_categoria,
                       COUNT(*) AS n_meses,
                       MIN(COMPETEN) AS competen_first,
                       MAX(COMPETEN) AS competen_last,
                       SUM(CASE WHEN ativa THEN 1 ELSE 0 END) AS n_meses_ativos
                FROM hb_panel
                GROUP BY CNES, hub_categoria
            )
            SELECT
                CNES,
                codmun_6,
                hub_categoria,
                n_meses,
                n_meses_ativos,
                competen_first,
                competen_last,
                CAST(n_meses_ativos > 0 AS BOOLEAN) AS hub_ativo_qualquer_mes
            FROM per_cnes_cat
            ORDER BY CNES, hub_categoria
        ) TO '{OUT_HUB}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    n_hub = con.sql(f"SELECT COUNT(*) FROM read_parquet('{OUT_HUB}')").fetchone()[0]
    log.info("    hub classification rows: %s (CNES × categoria)", f"{n_hub:,}")

    # ---- sanity --------------------------------------------------------
    log.info("\n=== distribuição de habilitações por categoria ===")
    by_cat = con.sql(f"""
        SELECT hub_categoria,
               COUNT(*) AS n_obs,
               COUNT(DISTINCT CNES) AS n_cnes,
               SUM(CASE WHEN ativa THEN 1 ELSE 0 END) AS ativas
        FROM read_parquet('{OUT_PANEL}')
        GROUP BY hub_categoria ORDER BY n_obs DESC
    """).pl()
    log.info("\n%s", by_cat)

    log.info("\n=== n_cnes com habilitação por ano ===")
    by_year = con.sql(f"""
        SELECT year,
               COUNT(DISTINCT CNES) AS n_hosp_com_hab,
               COUNT(*) AS n_obs
        FROM read_parquet('{OUT_PANEL}')
        WHERE ativa
        GROUP BY year ORDER BY year
    """).pl()
    log.info("\n%s", by_year)

    log.info("\n=== top 10 hospitais por nº categorias ativas ===")
    top_hubs = con.sql(f"""
        SELECT CNES,
               codmun_6,
               COUNT(DISTINCT hub_categoria) AS n_categorias,
               STRING_AGG(DISTINCT hub_categoria, ',') AS categorias
        FROM read_parquet('{OUT_HUB}')
        WHERE hub_ativo_qualquer_mes = TRUE
        GROUP BY CNES, codmun_6
        ORDER BY n_categorias DESC LIMIT 10
    """).pl()
    log.info("\n%s", top_hubs)

    log.info("==== done ==== elapsed %.1fs", time.time() - t0)


if __name__ == "__main__":
    main()
