"""
14_external_validation.py

Validacao externa (Secao 7): os desertos batem com a regionalizacao
administrativa do SUS (regiao de saude / CIR)? As regioes de saude sao
desenhadas para conter a referencia: o paciente deveria ser atendido dentro da
propria regiao. O fluxo revelado permite medir quanto essa promessa se cumpre, e
se os desertos de fluxo escapam mais da propria regiao --- o que validaria F1
como detector de falha de referencia que o mapa administrativo nao enxerga.

Medidas por municipio de residencia:
  within_region_share  - fracao das internacoes atendidas DENTRO da regiao de
                         saude do municipio
  tophub_out_region    - 1 se o maior hub externo esta FORA da regiao de saude

Entrada: bipartite_edges, hospital_master (CNES->mun), cnes_caps_cir
(regsaude_modal), master_muni_panel.
Saida:
  02_data/processed/external_validation_panel.parquet
  02_data/processed/external_validation_by_quadrant.csv
"""

from __future__ import annotations

import logging
import sys
import time
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
PAPER18 = ROOT.parent / "paper18-hospital-deserts"
INTER18 = PAPER18 / "02_data" / "intermediate"
PROC18 = PAPER18 / "02_data" / "processed"
PROC19 = ROOT / "02_data" / "processed"
LOG_DIR = ROOT / "04_logs"
LOG_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s",
    handlers=[logging.FileHandler(LOG_DIR / "14_external_validation.log", mode="w"),
              logging.StreamHandler(sys.stdout)])
log = logging.getLogger("extval")


def main() -> None:
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--window-start", type=int, default=2015)
    ap.add_argument("--window-end", type=int, default=2022)
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()
    ws, we = args.window_start, args.window_end

    out_panel = PROC19 / "external_validation_panel.parquet"
    out_csv = PROC19 / "external_validation_by_quadrant.csv"
    if out_panel.exists() and not args.force:
        log.info("output ja existe - use --force"); return

    t0 = time.perf_counter()
    log.info("==== external validation (regiao de saude) ====")
    edges = (INTER18 / "bipartite_edges.parquet").as_posix()
    hm = (INTER18 / "hospital_master.parquet").as_posix()
    cir = (PROC18 / "cnes_caps_cir_municipality_year.parquet").as_posix()
    master = (PROC19 / "master_muni_panel.parquet").as_posix()

    con = duckdb.connect()
    con.execute("PRAGMA threads=12")
    con.execute("PRAGMA memory_limit='14GB'")
    con.execute("PRAGMA temp_directory='/tmp/duckdb_paper19'")

    # regiao de saude modal por municipio (uma por municipio, moda sobre anos)
    con.execute(f"""
        CREATE TEMP TABLE reg AS
        SELECT municipality AS codmun_6, mode(regsaude_modal) AS regsaude
        FROM read_parquet('{cir}')
        WHERE regsaude_modal IS NOT NULL
        GROUP BY municipality
    """)

    # fluxo residencia -> municipio de destino, com regioes de ambos os lados
    log.info("[1/3] fluxo + regiao de saude (origem e destino)...")
    con.execute(f"""
        CREATE TEMP TABLE flow AS
        SELECT e.codmun_6 AS res, h.codmun_6_modal AS dest,
               rr.regsaude AS reg_res, rd.regsaude AS reg_dest,
               SUM(e.n_internacoes) AS n
        FROM read_parquet('{edges}') e
        JOIN read_parquet('{hm}') h ON e.CNES = h.CNES
        LEFT JOIN reg rr ON e.codmun_6 = rr.codmun_6
        LEFT JOIN reg rd ON h.codmun_6_modal = rd.codmun_6
        WHERE e.year BETWEEN {ws} AND {we} AND e.n_internacoes > 0
        GROUP BY 1,2,3,4
    """)

    log.info("[2/3] within-region share + top hub fora da regiao...")
    con.execute("""
        CREATE TEMP TABLE val AS
        WITH agg AS (
            SELECT res, reg_res,
                   SUM(n) AS total,
                   SUM(CASE WHEN reg_dest = reg_res THEN n ELSE 0 END) AS n_within
            FROM flow WHERE reg_res IS NOT NULL GROUP BY res, reg_res
        ),
        tophub AS (
            SELECT res, reg_res, reg_dest,
                   ROW_NUMBER() OVER (PARTITION BY res ORDER BY n DESC) AS rk
            FROM flow WHERE dest <> res AND reg_res IS NOT NULL
        )
        SELECT a.res AS codmun_6,
               a.n_within::DOUBLE / NULLIF(a.total,0) AS within_region_share,
               CASE WHEN t.reg_dest IS DISTINCT FROM a.reg_res THEN 1 ELSE 0 END AS tophub_out_region
        FROM agg a LEFT JOIN tophub t ON a.res = t.res AND t.rk = 1
    """)
    n = con.sql("SELECT COUNT(*) FROM val").fetchone()[0]
    log.info("    municipios com regiao=%d", n)
    con.execute(
        f"COPY (SELECT * FROM val ORDER BY within_region_share) "
        f"TO '{out_panel.as_posix()}' (FORMAT PARQUET, COMPRESSION 'snappy')")

    log.info("[3/3] concordancia: within-region por quadrante + corr com F1...")
    corr = con.sql(f"""
        SELECT ROUND(corr(v.within_region_share, m.f1_km),3)  AS r_within_f1,
               ROUND(corr(v.within_region_share, m.iso_km),3) AS r_within_iso,
               ROUND(AVG(v.within_region_share),3)            AS mean_within
        FROM val v JOIN read_parquet('{master}') m USING (codmun_6)
    """).df()
    log.info("\n%s", corr.to_string(index=False))
    byq = con.sql(f"""
        SELECT m.quadrant, COUNT(*) n_mun,
               ROUND(median(v.within_region_share)*100,1) AS pct_within_region,
               ROUND(AVG(v.tophub_out_region)*100,1)      AS pct_tophub_out
        FROM val v JOIN read_parquet('{master}') m USING (codmun_6)
        GROUP BY m.quadrant
        ORDER BY array_position(['flow_only','both','distance_only','neither'], m.quadrant)
    """).df()
    log.info("\n%s", byq.to_string(index=False))
    corr.to_csv(out_csv, index=False)
    with open(out_csv, "a") as fh:
        fh.write("\n"); byq.to_csv(fh, index=False)

    log.info("==== fim %.1fs ====", time.perf_counter() - t0)


if __name__ == "__main__":
    main()
