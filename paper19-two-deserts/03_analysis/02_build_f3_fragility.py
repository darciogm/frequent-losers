"""
02_build_f3_fragility.py

Operacionalizacao F3 do deserto de fluxo: FRAGILIDADE / CONCENTRACAO dos
destinos de internacao, no nivel do municipio de residencia, 2015-2022. F3 e a
terceira leitura de fluxo (F1 burden efetivo e a primaria; F2 isolamento em
embedding e a segunda) e serve de robustez: se as tres concordam, o deserto de
fluxo nao depende de uma unica medida.

Medida primaria: DEPENDENCIA DE HUB UNICO (hub_dependence) = fracao das
internacoes do municipio que vai para o seu maior hub EXTERNO. Alta = fragil:
um unico destino externo carrega o cuidado; se ele fecha, o municipio fica
exposto (ponte direta com o desenho de perda-de-provedor do paper18).

Tambem reportadas:
  dest_hhi      - HHI dos destinos (inclui o proprio municipio); concentracao
  n_eff_dest    - numero efetivo de destinos = 1/dest_hhi (inverso de Simpson)
  top_hub_share - maior share entre todos os destinos (inclui o proprio)
  external_hhi  - HHI entre destinos externos (so fluxo que sai)
  outflow_share - fracao das internacoes fora do municipio

Disciplina: descritivo. Le ativos do paper18, escreve em paper19.

Entrada: bipartite_edges.parquet, hospital_master.parquet (CNES->mun destino).
Saida:
  02_data/processed/f3_fragility_panel.parquet
  02_data/processed/f3_concordance.csv  (corr com F1 + medianas por quadrante)
"""

from __future__ import annotations

import argparse
import logging
import os
import socket
import subprocess
import sys
import time
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
PAPER18 = ROOT.parent / "paper18-hospital-deserts"
INTER18 = PAPER18 / "02_data" / "intermediate"
PROC19 = ROOT / "02_data" / "processed"
LOG_DIR = ROOT / "04_logs"
PROC19.mkdir(parents=True, exist_ok=True)
LOG_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s",
    handlers=[logging.FileHandler(LOG_DIR / "02_build_f3_fragility.log", mode="w"),
              logging.StreamHandler(sys.stdout)])
log = logging.getLogger("f3")


def _rss_gib() -> float:
    try:
        import psutil
        return psutil.Process().memory_info().rss / 1e9
    except Exception:
        import resource
        return resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1e6


def _git_sha() -> str:
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, text=True).strip()
    except Exception:
        return "unknown"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--window-start", type=int, default=2015)
    ap.add_argument("--window-end", type=int, default=2022)
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()
    ws, we = args.window_start, args.window_end

    out_panel = PROC19 / "f3_fragility_panel.parquet"
    out_conc = PROC19 / "f3_concordance.csv"
    if out_panel.exists() and not args.force:
        log.info("output ja existe (%s) - use --force", out_panel.name)
        return

    t0 = time.perf_counter()
    log.info("==== build F3 fragility ====")
    log.info("host=%s cores=%s git=%s window=%d-%d",
             socket.gethostname(), os.cpu_count(), _git_sha(), ws, we)

    edges = (INTER18 / "bipartite_edges.parquet").as_posix()
    hm = (INTER18 / "hospital_master.parquet").as_posix()

    con = duckdb.connect()
    con.execute("PRAGMA threads=12")
    con.execute("PRAGMA memory_limit='14GB'")
    con.execute("PRAGMA temp_directory='/tmp/duckdb_paper19'")

    # fluxo residencia -> municipio de destino (mapeado via hospital_master)
    log.info("[1/3] fluxo residencia -> municipio de destino...")
    con.execute(f"""
        CREATE TEMP TABLE flow_md AS
        SELECT e.codmun_6 AS res, h.codmun_6_modal AS dest,
               SUM(e.n_internacoes) AS n
        FROM read_parquet('{edges}') e
        JOIN read_parquet('{hm}') h ON e.CNES = h.CNES
        WHERE e.year BETWEEN {ws} AND {we} AND e.n_internacoes > 0
        GROUP BY e.codmun_6, h.codmun_6_modal
    """)

    # metricas de fragilidade por municipio de residencia
    log.info("[2/3] HHI, hub dependence, n efetivo de destinos...")
    con.execute("""
        CREATE TEMP TABLE f3 AS
        WITH tot AS (
            SELECT res, SUM(n) AS total,
                   SUM(CASE WHEN dest = res THEN n ELSE 0 END) AS n_local,
                   SUM(CASE WHEN dest <> res THEN n ELSE 0 END) AS n_ext
            FROM flow_md GROUP BY res
        ),
        sh AS (
            SELECT f.res, f.dest, f.n, t.total, t.n_ext,
                   f.n::DOUBLE / t.total AS share,
                   (f.dest = f.res) AS is_self
            FROM flow_md f JOIN tot t ON f.res = t.res
        )
        SELECT res AS codmun_6,
               MAX(total)                                   AS n_aih,
               SUM(share * share)                           AS dest_hhi,
               1.0 / NULLIF(SUM(share * share), 0)          AS n_eff_dest,
               MAX(share)                                   AS top_hub_share,
               1.0 - MAX(CASE WHEN is_self THEN share ELSE 0 END) AS outflow_share,
               -- maior hub EXTERNO como fracao do total de internacoes
               MAX(CASE WHEN NOT is_self THEN share ELSE 0 END)   AS hub_dependence,
               -- HHI entre destinos externos (so fluxo que sai)
               SUM(CASE WHEN NOT is_self THEN (n::DOUBLE/NULLIF(n_ext,0))^2 ELSE 0 END) AS external_hhi
        FROM sh GROUP BY res
    """)
    n = con.sql("SELECT COUNT(*) FROM f3").fetchone()[0]
    log.info("    municipios=%d (rss=%.2fGiB)", n, _rss_gib())

    con.execute(
        f"COPY (SELECT * FROM f3 ORDER BY hub_dependence DESC) "
        f"TO '{out_panel.as_posix()}' (FORMAT PARQUET, COMPRESSION 'snappy')")

    # concordancia com F1 (sustenta a promessa de robustez do paper)
    log.info("[3/3] concordancia F3 x F1 (master panel)...")
    master = PROC19 / "master_muni_panel.parquet"
    if master.exists():
        corr = con.sql(f"""
            SELECT COUNT(*) n,
                   ROUND(corr(f3.hub_dependence, m.f1_km),3) AS r_hubdep_f1,
                   ROUND(corr(f3.dest_hhi,       m.f1_km),3) AS r_hhi_f1,
                   ROUND(corr(f3.outflow_share,  m.f1_km),3) AS r_outflow_f1,
                   ROUND(corr(f3.hub_dependence, m.iso_km),3) AS r_hubdep_iso
            FROM f3 JOIN read_parquet('{master.as_posix()}') m USING (codmun_6)
        """).df()
        log.info("\n%s", corr.to_string(index=False))
        byq = con.sql(f"""
            SELECT m.quadrant, COUNT(*) n_mun,
                   ROUND(median(f3.hub_dependence),2) med_hub_dep,
                   ROUND(median(f3.dest_hhi),3)       med_hhi,
                   ROUND(median(f3.n_eff_dest),1)     med_n_eff_dest
            FROM f3 JOIN read_parquet('{master.as_posix()}') m USING (codmun_6)
            GROUP BY m.quadrant
            ORDER BY array_position(['flow_only','both','distance_only','neither'], m.quadrant)
        """).df()
        log.info("\n%s", byq.to_string(index=False))
        # grava: linha de corr + tabela por quadrante concatenadas
        corr.to_csv(out_conc, index=False)
        with open(out_conc, "a") as fh:
            fh.write("\n")
            byq.to_csv(fh, index=False)
    else:
        log.warning("master ausente - pulei concordancia")

    log.info("outputs: %s ; %s", out_panel.name, out_conc.name)
    log.info("==== fim em %.1fs (rss~%.2fGiB) ====", time.perf_counter() - t0, _rss_gib())


if __name__ == "__main__":
    main()
