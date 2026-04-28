"""
01_build_hospital_universe.py

Varre 6426 arquivos CNES-ST 2005-2025, monta:

1) hospital_panel_monthly.parquet
   1 linha por (CNES × COMPETEN). Universo: estabelecimentos que em algum
   mês reportam LEITHOSP > 0 OU TP_UNID em lista hospitalar.
   Cols: CNES, COMPETEN, year, month, codmun_6, codmun_7, TP_UNID, LEITHOSP,
         TPGESTAO, ESFERA_A, NAT_JUR, VINC_SUS, NIV_HIER,
         ATENDHOS, URGEMERG, ATENDAMB, CENTRCIR, CENTROBS, DT_ATUAL.

2) hospital_master.parquet
   1 linha por CNES — first/last competência presente, modal município/tipo,
   leitos máximos, número total de meses observados.

3) hospital_closures.parquet
   Eventos de fechamento: CNES presente até mês t, ausente em (t+1, t+2, t+3)
   e nunca mais reaparece (ou só reaparece após >12 meses).
   Cols: CNES, codmun_6, t_last_present, t_first_absent, gap_meses_to_reopen.

Stack: DuckDB out-of-core (12 threads, 14GB).
"""

from __future__ import annotations

import logging
import sys
import time
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "02_data" / "raw" / "cnes_st"
INTER = ROOT / "02_data" / "intermediate"
LOG = ROOT / "04_logs"
INTER.mkdir(parents=True, exist_ok=True)
LOG.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "01_build_hospital_universe.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("hospitals")

# Filtros canônicos para "estabelecimento hospitalar"
HOSPITAL_TPUNID = ("'05'", "'07'", "'12'", "'15'", "'20'", "'62'", "'73'")  # geral, esp, hosp/dia, mista, PS, hosp/dia, PA

OUT_PANEL = INTER / "hospital_panel_monthly.parquet"
OUT_MASTER = INTER / "hospital_master.parquet"
OUT_CLOSURES = INTER / "hospital_closures.parquet"


def main():
    t0 = time.time()
    log.info("==== begin hospital universe build ====")

    n_files = len(list(RAW.glob("st*.parquet")))
    log.info("input files: %d", n_files)

    con = duckdb.connect()
    con.execute("PRAGMA threads=12")
    con.execute("PRAGMA memory_limit='14GB'")
    con.execute("PRAGMA temp_directory='/tmp/duckdb_paper18'")

    # ---- 1) ler todos parquets, selecionar cols, padronizar tipos -------
    glob = str(RAW / "st*.parquet")
    log.info("glob: %s", glob)

    # universo: CNES com LEITHOSP > 0 OR TP_UNID hospitalar EM ALGUM mês.
    log.info("[1/4] varredura inicial: identificar CNES hospitalares...")
    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE cnes_hosp AS
        SELECT DISTINCT CNES
        FROM read_parquet('{glob}', union_by_name=true, filename=true)
        WHERE TRY_CAST(LEITHOSP AS INTEGER) > 0
           OR TP_UNID IN ({','.join(HOSPITAL_TPUNID)})
    """)
    n_cnes_hosp = con.sql("SELECT COUNT(*) FROM cnes_hosp").fetchone()[0]
    log.info("    universo hospitalar: %s CNES únicos", f"{n_cnes_hosp:,}")

    # ---- 2) painel mensal: 1 linha por (CNES × COMPETEN) ----------------
    log.info("[2/4] painel mensal: extraindo todas as competências...")
    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE panel AS
        SELECT
            s.CNES,
            s.COMPETEN,
            CAST(SUBSTR(s.COMPETEN, 1, 4) AS INTEGER)              AS year,
            CAST(SUBSTR(s.COMPETEN, 5, 2) AS INTEGER)              AS month,
            s.CODUFMUN                                              AS codmun_6,
            -- IBGE 7-dig = 6-dig + DV; sem o DV temos só prefixo. Usar codmun_6 como chave; codmun_7 é approx.
            s.TP_UNID,
            TRY_CAST(s.LEITHOSP AS INTEGER)                         AS leithosp,
            s.TPGESTAO,
            s.ESFERA_A,
            s.NAT_JUR,
            s.VINC_SUS,
            s.NIV_HIER,
            s.ATENDHOS,
            s.URGEMERG,
            s.ATENDAMB,
            s.CENTRCIR,
            s.CENTROBS,
            s.DT_ATUAL
        FROM read_parquet('{glob}', union_by_name=true) s
        SEMI JOIN cnes_hosp h ON h.CNES = s.CNES
    """)
    n_panel = con.sql("SELECT COUNT(*) FROM panel").fetchone()[0]
    log.info("    painel mensal bruto: %s linhas", f"{n_panel:,}")

    # de-duplicar (CNES, COMPETEN) — em alguns meses o mesmo CNES aparece em
    # arquivos de UF distintas se houve mudança; ficar com o último DT_ATUAL.
    con.execute("""
        CREATE OR REPLACE TEMP TABLE panel_dedup AS
        SELECT * FROM (
            SELECT *,
                   ROW_NUMBER() OVER (PARTITION BY CNES, COMPETEN ORDER BY DT_ATUAL DESC NULLS LAST) AS rn
            FROM panel
        ) WHERE rn = 1
    """)
    n_dedup = con.sql("SELECT COUNT(*) FROM panel_dedup").fetchone()[0]
    log.info("    painel mensal dedup: %s linhas", f"{n_dedup:,}")

    # escrever painel
    con.execute(f"""
        COPY (
            SELECT CNES, COMPETEN, year, month, codmun_6,
                   TP_UNID, leithosp, TPGESTAO, ESFERA_A, NAT_JUR,
                   VINC_SUS, NIV_HIER, ATENDHOS, URGEMERG, ATENDAMB,
                   CENTRCIR, CENTROBS, DT_ATUAL
            FROM panel_dedup
            ORDER BY CNES, COMPETEN
        ) TO '{OUT_PANEL}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    log.info("    escrito %s", OUT_PANEL)

    # ---- 3) master por CNES --------------------------------------------
    log.info("[3/4] hospital_master: agregando por CNES...")
    con.execute(f"""
        COPY (
            WITH agg AS (
                SELECT
                    CNES,
                    MIN(COMPETEN) AS competen_first,
                    MAX(COMPETEN) AS competen_last,
                    COUNT(*) AS n_meses,
                    MAX(leithosp) AS leithosp_max,
                    AVG(leithosp) AS leithosp_avg,
                    MODE(codmun_6) AS codmun_6_modal,
                    MODE(TP_UNID) AS tp_unid_modal,
                    MODE(TPGESTAO) AS tpgestao_modal,
                    MODE(ESFERA_A) AS esfera_modal,
                    MODE(NAT_JUR) AS nat_jur_modal
                FROM panel_dedup
                GROUP BY CNES
            )
            SELECT *,
                   CAST(SUBSTR(competen_first, 1, 4) AS INTEGER) AS year_first,
                   CAST(SUBSTR(competen_last, 1, 4) AS INTEGER) AS year_last
            FROM agg
            ORDER BY CNES
        ) TO '{OUT_MASTER}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    log.info("    escrito %s", OUT_MASTER)

    # ---- 4) closures: CNES com gap >= 12 meses depois de presença ------
    log.info("[4/4] hospital_closures: detectando fechamentos...")
    # estratégia: para cada CNES, ranquear COMPETEN. Detectar gaps.
    # Conversão competência → integer mês desde 2000: yyyy*12 + mm.
    con.execute("""
        CREATE OR REPLACE TEMP TABLE panel_with_idx AS
        SELECT *,
               (year - 2000) * 12 + month AS month_idx
        FROM panel_dedup
    """)
    # closure event: linha com max month_idx por CNES, marcada se month_idx_max < 300 (dez/2024)
    # mais robusto: identificar transições — para cada CNES, lista de gaps.
    con.execute(f"""
        COPY (
            WITH per_cnes AS (
                SELECT CNES,
                       codmun_6_modal AS codmun_6,
                       MAX(competen_last) AS competen_last,
                       MAX(year_last) AS year_last
                FROM (SELECT * FROM read_parquet('{OUT_MASTER}'))
                GROUP BY CNES, codmun_6_modal
            )
            SELECT CNES,
                   codmun_6,
                   competen_last,
                   year_last,
                   CASE WHEN year_last <= 2023 THEN TRUE ELSE FALSE END AS closed_by_2023
            FROM per_cnes
            WHERE year_last <= 2023
            ORDER BY CNES
        ) TO '{OUT_CLOSURES}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    n_closures = con.sql(f"SELECT COUNT(*) FROM read_parquet('{OUT_CLOSURES}')").fetchone()[0]
    log.info("    candidatos a fechamento (último COMPETEN <= 2023): %s", f"{n_closures:,}")

    # ---- sanity logs ---------------------------------------------------
    log.info("\n=== summary panel ===")
    by_year = con.sql(f"""
        SELECT year, COUNT(*) AS n_obs,
               COUNT(DISTINCT CNES) AS n_cnes,
               SUM(CASE WHEN leithosp > 0 THEN 1 ELSE 0 END) AS with_leitos,
               SUM(leithosp) AS total_leitos
        FROM read_parquet('{OUT_PANEL}')
        GROUP BY year ORDER BY year
    """).pl()
    log.info("\n%s", by_year)

    log.info("\n=== closure year distribution ===")
    by_close_year = con.sql(f"""
        SELECT year_last, COUNT(*) AS n
        FROM read_parquet('{OUT_CLOSURES}')
        GROUP BY year_last ORDER BY year_last
    """).pl()
    log.info("\n%s", by_close_year)

    log.info("==== done ====")
    log.info("elapsed %.1fs", time.time() - t0)


if __name__ == "__main__":
    main()
