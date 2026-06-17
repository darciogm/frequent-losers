"""
17_physician_vs_patient_flow.py

Testa H3 da secao de mobilidade medica: a rede de MIGRACAO de medicos espelha a
rede de FLUXO de pacientes? Ou seja, os medicos saem dos desertos de fluxo em
direcao aos MESMOS hubs para onde os pacientes ja viajam?

Compara duas redes municipio->municipio:
  - fluxo de pacientes: internacoes residencia->municipio do hospital (SIH)
  - migracao de medicos: mudanca de municipio primario ano-a-ano (CNES-PF)

Medidas:
  - correlacao dos pesos de aresta sobre pares (origem,destino) comuns
  - por municipio de origem: o principal destino de pacientes coincide com o
    principal destino de medicos? (top-hub match)
  - fracao dos medicos que saem de desertos de fluxo rumo ao hub de pacientes
  - sintese por quadrante de deserto

Entrada: physician_migration_edges.parquet (script 16), bipartite_edges +
hospital_master (paper18), master_muni_panel.
Saida:
  02_data/processed/physician_vs_patient_network.csv
  02_data/processed/tophub_match_by_quadrant.csv
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
INTER18 = PAPER18 / "02_data" / "intermediate"
PROC19 = ROOT / "02_data" / "processed"
LOG_DIR = ROOT / "04_logs"
LOG_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s",
    handlers=[logging.FileHandler(LOG_DIR / "17_physician_vs_patient_flow.log", mode="w"),
              logging.StreamHandler(sys.stdout)])
log = logging.getLogger("netcmp")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--window-start", type=int, default=2015)
    ap.add_argument("--window-end", type=int, default=2022)
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()
    ws, we = args.window_start, args.window_end

    mig = PROC19 / "physician_migration_edges.parquet"
    if not mig.exists():
        log.error("falta %s -- rode 16_build_physician_panel.py primeiro", mig)
        sys.exit(1)
    out_net = PROC19 / "physician_vs_patient_network.csv"
    if out_net.exists() and not args.force:
        log.info("output ja existe - use --force"); return

    t0 = time.perf_counter()
    edges = (INTER18 / "bipartite_edges.parquet").as_posix()
    hm = (INTER18 / "hospital_master.parquet").as_posix()
    master = (PROC19 / "master_muni_panel.parquet").as_posix()

    con = duckdb.connect()
    con.execute("PRAGMA threads=12")
    con.execute("PRAGMA memory_limit='14GB'")
    con.execute("PRAGMA temp_directory='/tmp/duckdb_paper19'")

    # rede de fluxo de pacientes: residencia -> municipio destino, fora do proprio
    log.info("[1] rede de fluxo de pacientes (origem->destino)...")
    con.execute(f"""
        CREATE TEMP TABLE pat AS
        SELECT e.codmun_6 AS origin, h.codmun_6_modal AS dest, SUM(e.n_internacoes) AS n_pat
        FROM read_parquet('{edges}') e
        JOIN read_parquet('{hm}') h ON e.CNES = h.CNES
        WHERE e.year BETWEEN {ws} AND {we} AND e.codmun_6 <> h.codmun_6_modal
        GROUP BY 1,2
    """)
    # rede de migracao medica
    con.execute(f"""
        CREATE TEMP TABLE doc AS
        SELECT codmun_origin AS origin, codmun_dest AS dest, n_movers AS n_doc
        FROM read_parquet('{mig.as_posix()}')
        WHERE codmun_origin <> codmun_dest
    """)

    # (a) correlacao dos pesos sobre pares comuns
    log.info("[2] correlacao das duas redes sobre arestas comuns...")
    corr = con.sql("""
        WITH j AS (SELECT p.origin, p.dest, p.n_pat, d.n_doc
                   FROM pat p JOIN doc d USING (origin, dest))
        SELECT COUNT(*) arestas_comuns,
               ROUND(corr(n_pat, n_doc),3)             AS r_niveis,
               ROUND(corr(ln(n_pat), ln(n_doc)),3)     AS r_log
        FROM j
    """).df()
    log.info("\n%s", corr.to_string(index=False))

    # (b) top-hub por origem: paciente vs medico coincidem?
    log.info("[3] top-hub match por municipio de origem...")
    con.execute("""
        CREATE TEMP TABLE tophub AS
        WITH pt AS (
            SELECT origin, dest, n_pat,
                   ROW_NUMBER() OVER (PARTITION BY origin ORDER BY n_pat DESC) rk
            FROM pat
        ),
        dt AS (
            SELECT origin, dest, n_doc,
                   ROW_NUMBER() OVER (PARTITION BY origin ORDER BY n_doc DESC) rk
            FROM doc
        )
        SELECT pt.origin AS codmun_6, pt.dest AS pat_hub, dt.dest AS doc_hub,
               (pt.dest = dt.dest) AS match
        FROM pt JOIN dt ON pt.origin = dt.origin AND pt.rk=1 AND dt.rk=1
    """)

    # fracao dos medicos que saem rumo ao hub de pacientes (sobre todas as origens)
    frac = con.sql("""
        WITH share AS (
            SELECT d.origin,
                   SUM(CASE WHEN d.dest = ph.pat_hub THEN d.n_doc ELSE 0 END)::DOUBLE
                     / NULLIF(SUM(d.n_doc),0) AS frac_to_pat_hub
            FROM doc d
            JOIN (SELECT origin, dest AS pat_hub FROM pat
                  QUALIFY ROW_NUMBER() OVER (PARTITION BY origin ORDER BY n_pat DESC)=1) ph
              USING (origin)
            GROUP BY d.origin
        )
        SELECT ROUND(AVG(frac_to_pat_hub),3) AS frac_medicos_para_hub_paciente,
               COUNT(*) n_origens
        FROM share
    """).df()
    log.info("\n%s", frac.to_string(index=False))
    corr.assign(**frac.iloc[0].to_dict()).to_csv(out_net, index=False)

    # (c) por quadrante de deserto: top-hub match + fracao
    log.info("[4] sintese por quadrante...")
    byq = con.sql(f"""
        WITH share AS (
            SELECT d.origin,
                   SUM(CASE WHEN d.dest = ph.pat_hub THEN d.n_doc ELSE 0 END)::DOUBLE
                     / NULLIF(SUM(d.n_doc),0) AS frac
            FROM doc d
            JOIN (SELECT origin, dest AS pat_hub FROM pat
                  QUALIFY ROW_NUMBER() OVER (PARTITION BY origin ORDER BY n_pat DESC)=1) ph
              USING (origin)
            GROUP BY d.origin
        )
        SELECT m.quadrant, COUNT(*) n_mun,
               ROUND(100.0*AVG(th.match::INT),1)  AS pct_tophub_match,
               ROUND(AVG(s.frac),3)               AS frac_medicos_para_hub_paciente
        FROM read_parquet('{master}') m
        LEFT JOIN tophub th USING (codmun_6)
        LEFT JOIN share s ON s.origin = m.codmun_6
        GROUP BY m.quadrant
        ORDER BY array_position(['flow_only','both','distance_only','neither'], m.quadrant)
    """).df()
    byq.to_csv(PROC19 / "tophub_match_by_quadrant.csv", index=False)
    log.info("\n%s", byq.to_string(index=False))
    log.info("==== fim %.0fs ====", time.perf_counter() - t0)


if __name__ == "__main__":
    main()
