"""
03_build_master_muni_table.py

Costura o painel-mestre município-nível que destrava §6.3 (perfis dos
quadrantes), §8 (overlay de mortalidade evitável) e a Figure 1 (mapa da
divergência). Uma linha por município (~5.5k), cross-section 2015-2022.

Parte do cross-section F1 (script 01) e anexa:
  - F2 (isolamento embedding) como divergência alternativa de robustez
  - ANS (penetração de saúde suplementar) — moderador do §6.3
  - PIB per capita — renda do §6.3
  - oferta local (nº hospitais com leitos + leitos) — porte do §6.3,
    explica o paradoxo flow_only (tem hospital local de baixa complexidade)
  - mortalidade evitável (Nolte-McKee), taxa pooled base + redistribuída R99 — §8

Pendências sinalizadas (NÃO fabricar):
  - cobertura de atenção primária (ESF/APS): sem ativo no inventário paper18.
    Usar leitos locais como proxy de oferta; APS fica como TODO.
  - regionalização CIR/RIPSA (§7): precisa de crosswalk de região de saúde;
    não bloqueia Figure 1/§6.3/§8. TODO separado.

Disciplina: descritivo, linguagem associativa. Causal mora no paper18.

Output (paper19):
  02_data/processed/master_muni_panel.parquet
  02_data/processed/profiles_by_quadrant.csv   (exibição direta do §6.3)
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

LOG_DIR.mkdir(parents=True, exist_ok=True)
PROC19.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG_DIR / "03_build_master_muni_table.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("master")


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
            ["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, text=True
        ).strip()
    except Exception:
        return "unknown"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--window-start", type=int, default=2015)
    ap.add_argument("--window-end", type=int, default=2022)
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    f1_panel = PROC19 / "f1_divergence_panel.parquet"
    if not f1_panel.exists():
        log.error("falta %s — rode 01_build_f1_divergence.py primeiro", f1_panel)
        sys.exit(1)

    out_panel = PROC19 / "master_muni_panel.parquet"
    out_profiles = PROC19 / "profiles_by_quadrant.csv"
    if out_panel.exists() and not args.force:
        log.info("output já existe (%s) — use --force", out_panel.name)
        return

    t0 = time.perf_counter()
    log.info("==== build master muni table ====")
    log.info("host=%s cores=%s git=%s window=%d-%d",
             socket.gethostname(), os.cpu_count(), _git_sha(),
             args.window_start, args.window_end)

    con = duckdb.connect()
    con.execute("PRAGMA threads=12")
    con.execute("PRAGMA memory_limit='14GB'")
    con.execute("PRAGMA temp_directory='/tmp/duckdb_paper19'")

    f1 = f1_panel.as_posix()
    dv = (INTER18 / "divergence_panel.parquet").as_posix()
    ans = (INTER18 / "ans_private_penetration.parquet").as_posix()
    pib = (INTER18 / "pib_municipal_2015_2023.parquet").as_posix()
    hm = (INTER18 / "hospital_master.parquet").as_posix()
    am = (INTER18 / "amenable_mortality_redistributed.parquet").as_posix()
    ws, we = args.window_start, args.window_end

    log.info("[1/4] oferta local (hospitais com leitos ativos na janela)...")
    con.execute(
        f"""
        CREATE TEMP TABLE supply AS
        SELECT codmun_6_modal AS codmun_6,
               COUNT(*)              AS n_local_hosp,
               SUM(leithosp_max)     AS local_beds_max
        FROM read_parquet('{hm}')
        WHERE leithosp_max > 0
          AND year_first <= {we} AND year_last >= {ws}
        GROUP BY codmun_6_modal
        """
    )

    log.info("[2/4] PIB per capita (média da janela) e mortalidade pooled...")
    con.execute(
        f"""
        CREATE TEMP TABLE pibm AS
        SELECT substr(cod_mun,1,6) AS codmun_6, AVG(pib_corr) AS pib_corr_mean
        FROM read_parquet('{pib}')
        WHERE ano BETWEEN {ws} AND {we}
        GROUP BY substr(cod_mun,1,6)
        """
    )
    con.execute(
        f"""
        CREATE TEMP TABLE mort AS
        SELECT codmun_6,
               SUM(n_amenable)                / NULLIF(SUM(pop),0) * 1e5 AS amenable_rate,
               SUM(n_amenable_redistributed)  / NULLIF(SUM(pop),0) * 1e5 AS amenable_rate_redist,
               SUM(n_amenable)                AS n_amenable_win,
               SUM(pop)                       AS pop_years
        FROM read_parquet('{am}')
        WHERE year BETWEEN {ws} AND {we}
          AND pop IS NOT NULL AND NOT isnan(CAST(pop AS DOUBLE))
        GROUP BY codmun_6
        """
    )

    log.info("[3/4] costura final + F2 divergência + perfis derivados...")
    con.execute(
        f"""
        CREATE TEMP TABLE master AS
        WITH j AS (
            SELECT b.*,
                   a.tx_cobert_med_pct, a.low_private,
                   p.pib_corr_mean,
                   COALESCE(s.n_local_hosp, 0)   AS n_local_hosp,
                   COALESCE(s.local_beds_max, 0) AS local_beds_max,
                   m.amenable_rate, m.amenable_rate_redist,
                   m.n_amenable_win
            FROM read_parquet('{f1}') b
            LEFT JOIN read_parquet('{ans}') a USING (codmun_6)
            LEFT JOIN pibm   p USING (codmun_6)
            LEFT JOIN supply s USING (codmun_6)
            LEFT JOIN mort   m USING (codmun_6)
        ),
        z AS (
            SELECT *,
                   (iso_emb - AVG(iso_emb) OVER ()) / stddev_samp(iso_emb) OVER () AS iso_emb_z
            FROM j
        )
        SELECT *,
               (iso_emb_z - iso_km_z)                            AS divergence_z_f2,
               CASE WHEN pop > 0 THEN pib_corr_mean*1000.0 / pop END         AS pib_pc,
               CASE WHEN pop > 0 THEN local_beds_max * 10000.0 / pop END     AS beds_per10k,
               (n_local_hosp > 0)                                AS has_local_hosp
        FROM z
        """
    )
    n = con.sql("SELECT COUNT(*) FROM master").fetchone()[0]
    cov = con.sql(
        """
        SELECT SUM(CASE WHEN tx_cobert_med_pct IS NULL THEN 1 ELSE 0 END) no_ans,
               SUM(CASE WHEN pib_pc IS NULL THEN 1 ELSE 0 END) no_pib,
               SUM(CASE WHEN amenable_rate IS NULL THEN 1 ELSE 0 END) no_mort,
               SUM(CASE WHEN n_local_hosp=0 THEN 1 ELSE 0 END) no_local_hosp
        FROM master
        """
    ).fetchone()
    log.info("    N=%d | nulos: ANS=%d PIB=%d mort=%d | sem hosp local=%d (rss=%.2fGiB)",
             n, cov[0], cov[1], cov[2], cov[3], _rss_gib())

    con.execute(
        f"COPY (SELECT * FROM master ORDER BY divergence_z DESC) "
        f"TO '{out_panel.as_posix()}' (FORMAT PARQUET, COMPRESSION 'snappy')"
    )

    log.info("[4/4] perfis por quadrante (§6.3)...")
    profiles = con.sql(
        """
        SELECT quadrant,
               COUNT(*)                          AS n_mun,
               SUM(COALESCE(pop,0))              AS pop,
               ROUND(median(iso_km),1)          AS med_iso_km,
               ROUND(median(f1_km),1)           AS med_f1_km,
               ROUND(median(gap_km),1)          AS med_gap_km,
               ROUND(median(share_outflow),2)   AS med_outflow,
               ROUND(median(pib_pc),0)          AS med_pib_pc,
               ROUND(median(beds_per10k),2)     AS med_beds_per10k,
               ROUND(100.0*AVG(CASE WHEN has_local_hosp THEN 1 ELSE 0 END),0) AS pct_has_hosp,
               ROUND(median(tx_cobert_med_pct),1) AS med_ans_pct,
               ROUND(median(amenable_rate),1)   AS med_amenable_rate
        FROM master
        GROUP BY quadrant
        ORDER BY array_position(['flow_only','both','distance_only','neither'], quadrant)
        """
    ).df()
    profiles.to_csv(out_profiles, index=False)
    log.info("\n%s", profiles.to_string(index=False))
    log.info("outputs: %s ; %s", out_panel.name, out_profiles.name)
    log.info("==== fim em %.1fs (rss~%.2fGiB) ====", time.perf_counter() - t0, _rss_gib())


if __name__ == "__main__":
    main()
