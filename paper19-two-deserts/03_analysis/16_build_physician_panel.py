"""
16_build_physician_panel.py

Constroi, a partir do CNES-PF limpo (medico-vinculo mensal, script 15):

(1) OFERTA  - painel municipio x ano: medicos distintos, por especialidade
    (CBO familia), SUS-only, FTE (horas/40), e medicos por 1.000 hab.
(2) MOBILIDADE - rastreia cada CNS_PROF ao longo do tempo:
    - municipio primario por (CNS, ano) = onde tem mais horas no ano
    - mudancas ano-a-ano = migracao de medico (origem -> destino)
    - por municipio-ano: entradas, saidas, saldo, retencao
    - rede de migracao medica origem->destino, para comparar com o fluxo de
      PACIENTES: medicos fluem para os mesmos hubs?

Saidas (paper19):
  02_data/processed/physician_supply_panel.parquet
  02_data/processed/physician_mobility_panel.parquet
  02_data/processed/physician_migration_edges.parquet
  02_data/processed/physician_by_quadrant.csv
"""

from __future__ import annotations

import argparse
import logging
import os
import socket
import sys
import time
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
PAPER18 = ROOT.parent / "paper18-hospital-deserts"
PF_DIR = ROOT / "02_data" / "intermediate" / "cnes_pf_medicos"
PROC19 = ROOT / "02_data" / "processed"
LOG_DIR = ROOT / "04_logs"
PROC19.mkdir(parents=True, exist_ok=True)
LOG_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s",
    handlers=[logging.FileHandler(LOG_DIR / "16_build_physician_panel.log", mode="w"),
              logging.StreamHandler(sys.stdout)])
log = logging.getLogger("phys")


def _rss():
    try:
        import psutil
        return psutil.Process().memory_info().rss / 1e9
    except Exception:
        return -1.0


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()
    out_supply = PROC19 / "physician_supply_panel.parquet"
    if out_supply.exists() and not args.force:
        log.info("output ja existe - use --force"); return

    glob = (PF_DIR / "uf=*" / "year=*" / "month=*" / "data.parquet").as_posix()
    pop = (PAPER18 / "02_data" / "intermediate" / "pop_municipal_2015_2025.parquet").as_posix()
    master = (PROC19 / "master_muni_panel.parquet").as_posix()

    t0 = time.perf_counter()
    log.info("==== build physician panel ====")
    log.info("host=%s cores=%s", socket.gethostname(), os.cpu_count())

    con = duckdb.connect()
    con.execute("PRAGMA threads=12")
    con.execute("PRAGMA memory_limit='14GB'")
    con.execute("PRAGMA temp_directory='/tmp/duckdb_paper19'")

    n_files = len(list(PF_DIR.glob("uf=*/year=*/month=*/data.parquet")))
    log.info("[0] arquivos PF: %d", n_files)

    # vinculos limpos: horas numericas, municipio valido
    log.info("[1] carregando medico-vinculos mensais...")
    con.execute(f"""
        CREATE TEMP TABLE vinc AS
        SELECT CNS_PROF AS cns, codmun_6, year, month, cbo_fam,
               (PROF_SUS='1') AS sus,
               COALESCE(TRY_CAST(HORAHOSP AS INT),0)
               + COALESCE(TRY_CAST(HORA_AMB AS INT),0)
               + COALESCE(TRY_CAST(HORAOUTR AS INT),0) AS horas
        FROM read_parquet('{glob}')
        WHERE CNS_PROF IS NOT NULL AND CNS_PROF <> ''
          AND codmun_6 IS NOT NULL AND length(codmun_6)=6
    """)
    nv = con.sql("SELECT COUNT(*) FROM vinc").fetchone()[0]
    log.info("    vinculos=%s (rss=%.1fGiB)", f"{nv:,}", _rss())

    # ---------- (1) OFERTA: municipio x ano ----------
    log.info("[2] painel de oferta (municipio x ano)...")
    con.execute(f"""
        CREATE TEMP TABLE supply AS
        WITH cns_my AS (  -- presenca de cada medico no municipio-ano + horas mensais medias
            SELECT codmun_6, year, cns,
                   MAX(sus::INT) AS any_sus,
                   SUM(horas)::DOUBLE / COUNT(DISTINCT month) AS horas_mes,
                   ANY_VALUE(cbo_fam) AS cbo_fam
            FROM vinc GROUP BY codmun_6, year, cns
        )
        SELECT codmun_6, year,
               COUNT(DISTINCT cns)                                   AS n_medicos,
               COUNT(DISTINCT CASE WHEN cbo_fam='2251' THEN cns END) AS n_clinico,
               COUNT(DISTINCT CASE WHEN cbo_fam='2252' THEN cns END) AS n_cirurgico,
               COUNT(DISTINCT CASE WHEN cbo_fam='2253' THEN cns END) AS n_diagnostico,
               COUNT(DISTINCT CASE WHEN any_sus=1 THEN cns END)      AS n_sus,
               SUM(horas_mes)/40.0                                   AS fte
        FROM cns_my GROUP BY codmun_6, year
    """)
    con.execute(f"""
        COPY (
            SELECT s.*, p.pop,
                   CASE WHEN p.pop>0 THEN 1000.0*s.n_medicos/p.pop END AS medicos_por_1000,
                   CASE WHEN p.pop>0 THEN 1000.0*s.n_sus/p.pop END     AS medicos_sus_por_1000
            FROM supply s
            LEFT JOIN (SELECT substr(cod_mun,1,6) AS codmun_6, ano AS yr, pop
                       FROM read_parquet('{pop}')) p
              ON p.codmun_6 = s.codmun_6 AND p.yr = s.year
            ORDER BY s.codmun_6, s.year
        ) TO '{out_supply.as_posix()}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    log.info("    oferta salva (rss=%.1fGiB)", _rss())

    # ---------- (2) MOBILIDADE ----------
    log.info("[3] municipio primario por (medico, ano) = argmax horas...")
    con.execute("""
        CREATE TEMP TABLE primary_my AS
        WITH h AS (
            SELECT cns, year, codmun_6, SUM(horas) AS horas
            FROM vinc GROUP BY cns, year, codmun_6
        ),
        rk AS (
            SELECT cns, year, codmun_6,
                   ROW_NUMBER() OVER (PARTITION BY cns, year
                                      ORDER BY horas DESC, codmun_6) AS rk
            FROM h
        )
        SELECT cns, year, codmun_6 AS prim FROM rk WHERE rk=1
    """)

    log.info("[4] movimentos ano-a-ano (origem -> destino)...")
    con.execute("""
        CREATE TEMP TABLE moves AS
        SELECT a.cns, a.year AS year_from, a.prim AS origin, b.prim AS dest
        FROM primary_my a
        JOIN primary_my b ON a.cns = b.cns AND b.year = a.year + 1
        WHERE a.prim <> b.prim
    """)
    nm = con.sql("SELECT COUNT(*) FROM moves").fetchone()[0]
    log.info("    movimentos detectados=%s", f"{nm:,}")

    # rede de migracao medica (para comparar com fluxo de pacientes)
    con.execute(f"""
        COPY (
            SELECT origin AS codmun_origin, dest AS codmun_dest, COUNT(*) AS n_movers
            FROM moves GROUP BY origin, dest ORDER BY n_movers DESC
        ) TO '{(PROC19/'physician_migration_edges.parquet').as_posix()}'
        (FORMAT PARQUET, COMPRESSION 'snappy')
    """)

    # painel municipio-ano: entradas, saidas, saldo, retencao
    log.info("[5] painel de mobilidade por municipio-ano...")
    con.execute(f"""
        COPY (
            WITH outm AS (SELECT origin codmun_6, year_from AS "year", COUNT(*) n_out FROM moves GROUP BY 1,2),
                 inm  AS (SELECT dest codmun_6, year_from AS "year", COUNT(*) n_in  FROM moves GROUP BY 1,2),
                 stock AS (SELECT prim codmun_6, year, COUNT(*) n_stock FROM primary_my GROUP BY 1,2)
            SELECT s.codmun_6, s.year, s.n_stock,
                   COALESCE(i.n_in,0)  AS n_in,
                   COALESCE(o.n_out,0) AS n_out,
                   COALESCE(i.n_in,0) - COALESCE(o.n_out,0) AS net,
                   1.0 - COALESCE(o.n_out,0)::DOUBLE/NULLIF(s.n_stock,0) AS retention
            FROM stock s
            LEFT JOIN inm  i USING (codmun_6, year)
            LEFT JOIN outm o USING (codmun_6, year)
            ORDER BY s.codmun_6, s.year
        ) TO '{(PROC19/'physician_mobility_panel.parquet').as_posix()}'
        (FORMAT PARQUET, COMPRESSION 'snappy')
    """)

    # ---------- (3) por quadrante de deserto ----------
    log.info("[6] sintese por quadrante de deserto...")
    byq = con.sql(f"""
        WITH sup AS (
            SELECT codmun_6, AVG(medicos_por_1000) med_1000, AVG(n_medicos) n_med,
                   AVG(n_sus::DOUBLE/NULLIF(n_medicos,0)) sus_share
            FROM read_parquet('{out_supply.as_posix()}') GROUP BY codmun_6
        ),
        mob AS (
            SELECT codmun_6, SUM(n_in) tot_in, SUM(n_out) tot_out,
                   SUM(n_in)-SUM(n_out) net, AVG(retention) reten
            FROM read_parquet('{(PROC19/'physician_mobility_panel.parquet').as_posix()}')
            GROUP BY codmun_6
        )
        SELECT m.quadrant, COUNT(*) n_mun,
               ROUND(median(sup.med_1000),2)  AS med_medicos_1000,
               ROUND(median(sup.sus_share),2) AS med_sus_share,
               ROUND(median(mob.reten),3)     AS med_retention,
               SUM(mob.net)                   AS net_migracao_total,
               ROUND(1000.0*SUM(mob.net)/NULLIF(SUM(sup.n_med),0),1) AS net_por_1000_med
        FROM read_parquet('{master}') m
        LEFT JOIN sup USING (codmun_6)
        LEFT JOIN mob USING (codmun_6)
        GROUP BY m.quadrant
        ORDER BY array_position(['flow_only','both','distance_only','neither'], m.quadrant)
    """).df()
    byq.to_csv(PROC19 / "physician_by_quadrant.csv", index=False)
    log.info("\n%s", byq.to_string(index=False))
    log.info("==== fim %.0fs (rss=%.1fGiB) ====", time.perf_counter()-t0, _rss())


if __name__ == "__main__":
    main()
