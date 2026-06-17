"""
19_physician_setting.py

Decompoe a oferta medica por SETTING do estabelecimento (hospital vs atencao
primaria vs ambulatorio especializado), usando TP_UNID do CNES-PF. Refina a
secao de mobilidade: o deficit medico dos desertos de fluxo esta no andar
hospitalar/especialista, nao no piso da atencao primaria.

Classificacao de TP_UNID derivada DOS DADOS (fracao de horas hospitalares por
tipo, nao tabela hardcoded): tipos com >=40% das horas em ambiente hospitalar =
hospital; 01/02 (UBS/posto, ~0% horas hosp) = atencao primaria; demais
ambulatorios. Validada contra HORAHOSP/HORA_AMB.

Saida:
  02_data/processed/physician_setting_panel.parquet  (municipio: hosp/prim/espec por 1.000)
  02_data/processed/physician_setting_by_quadrant.csv
"""

from __future__ import annotations

import argparse
import logging
import sys
import time
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
PAPER18 = ROOT.parent / "paper18-hospital-deserts"
PF_GLOB = (ROOT / "02_data" / "intermediate" / "cnes_pf_medicos"
           / "uf=*" / "year=*" / "month=*" / "data.parquet").as_posix()
PROC19 = ROOT / "02_data" / "processed"
LOG_DIR = ROOT / "04_logs"
LOG_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s",
    handlers=[logging.FileHandler(LOG_DIR / "19_physician_setting.log", mode="w"),
              logging.StreamHandler(sys.stdout)])
log = logging.getLogger("setting")

# data-driven (ver bloco exploratorio): >=40% horas hospitalares
HOSP = ("05", "07", "60", "15", "21")   # hospital geral/espec., unidade mista, PS espec.
PRIM = ("01", "02")                      # posto de saude, UBS/centro de saude


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()
    out = PROC19 / "physician_setting_panel.parquet"
    if out.exists() and not args.force:
        log.info("output ja existe - use --force"); return

    t0 = time.perf_counter()
    pop = (PAPER18 / "02_data" / "intermediate" / "pop_municipal_2015_2025.parquet").as_posix()
    master = (PROC19 / "master_muni_panel.parquet").as_posix()
    hset = "','".join(HOSP)
    pset = "','".join(PRIM)

    con = duckdb.connect()
    con.execute("PRAGMA threads=12")
    con.execute("PRAGMA memory_limit='14GB'")
    con.execute("PRAGMA temp_directory='/tmp/duckdb_paper19'")

    log.info("[1] medico distinto por setting (municipio x ano)...")
    con.execute(f"""
        CREATE TEMP TABLE st AS
        SELECT codmun_6, year, CNS_PROF,
               MAX(CASE WHEN TP_UNID IN ('{hset}') THEN 1 ELSE 0 END) hosp,
               MAX(CASE WHEN TP_UNID IN ('{pset}') THEN 1 ELSE 0 END) prim,
               MAX(CASE WHEN cbo_fam IN ('2252','2253') THEN 1 ELSE 0 END) espec
        FROM read_parquet('{PF_GLOB}') GROUP BY 1,2,3
    """)
    log.info("[2] densidade por 1.000 (media da janela)...")
    con.execute(f"""
        COPY (
            WITH c AS (SELECT codmun_6, year, SUM(hosp) n_hosp, SUM(prim) n_prim,
                              SUM(espec) n_espec FROM st GROUP BY 1,2),
                 p AS (SELECT substr(cod_mun,1,6) codmun_6, ano AS yr, pop
                       FROM read_parquet('{pop}'))
            SELECT c.codmun_6,
                   AVG(1000.0*n_hosp /NULLIF(p.pop,0)) AS hosp_per1000,
                   AVG(1000.0*n_prim /NULLIF(p.pop,0)) AS prim_per1000,
                   AVG(1000.0*n_espec/NULLIF(p.pop,0)) AS espec_per1000
            FROM c JOIN p ON p.codmun_6=c.codmun_6 AND p.yr=c.year
            GROUP BY c.codmun_6
        ) TO '{out.as_posix()}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)

    log.info("[3] sintese por quadrante...")
    byq = con.sql(f"""
        SELECT m.quadrant, COUNT(*) n,
               ROUND(median(x.hosp_per1000),2)  AS hosp_1k,
               ROUND(median(x.prim_per1000),2)  AS primaria_1k,
               ROUND(median(x.espec_per1000),2) AS espec_1k
        FROM read_parquet('{master}') m JOIN read_parquet('{out.as_posix()}') x USING (codmun_6)
        GROUP BY m.quadrant
        ORDER BY array_position(['flow_only','both','distance_only','neither'], m.quadrant)
    """).df()
    byq.to_csv(PROC19 / "physician_setting_by_quadrant.csv", index=False)
    log.info("\n%s", byq.to_string(index=False))
    log.info("==== fim %.0fs ====", time.perf_counter() - t0)


if __name__ == "__main__":
    main()
