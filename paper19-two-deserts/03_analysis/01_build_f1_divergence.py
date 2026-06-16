"""
01_build_f1_divergence.py

Constrói o cross-section município-nível que sustenta o coração do relatório
(§6, Figure 1): a divergência entre o deserto de DISTÂNCIA e o deserto de
FLUXO (medida primária F1, "burden efetivo de fluxo").

Conceitos
---------
- Distância (deserto de mapa): iso_km_hosp = km do centroide do município ao
  hospital ATIVO mais próximo. É o que a política de acesso baseada em mapa
  enxerga. Reaproveitado de paper18 (divergence_panel / osrm_travel_time_panel).

- F1, burden efetivo de fluxo: travel_burden_km = distância média ponderada por
  n_internações entre o município de residência e o município onde o paciente
  REALMENTE internou (paper18, script 22). Captura "para onde os pacientes vão",
  não "qual o hospital mais próximo no mapa".

- Gap = F1 - distância. O excesso de viagem revelado além do hospital mais
  próximo: bypass / referência local fraca. É a essência do conceito.

- Taxonomia 2x2 (deserto = acima do limiar de cada medida):
    flow_only      perto em km, isolado em fluxo  <- o que a política de
                                                     distância sistematicamente
                                                     NÃO enxerga
    distance_only  longe em km, conectado em fluxo  <- km superestima o burden
    both           longe e isolado
    neither        nem um nem outro

Disciplina: descritivo. Nenhuma linguagem causal. O causal mora no paper18.

Inputs (lidos de paper18, fonte única — não duplicar fluxos pesados):
  travel_burden_panel.parquet  (F1, município x ano)
  divergence_panel.parquet     (iso_km_hosp, iso_emb_hosp por município)
  osrm_travel_time_panel.parquet (travel_time_min_proxy)
  municipios_centroids.parquet (nome, uf, lat, lon)
  pop_municipal_2015_2025.parquet (denominador para população exposta)

Outputs (em paper19):
  02_data/processed/f1_divergence_panel.parquet      (cross-section município)
  02_data/processed/f1_divergence_quadrant_summary.csv (contagem 2x2 + pop exposta)
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
OUT_DIR = ROOT / "02_data" / "processed"
LOG_DIR = ROOT / "04_logs"

LOG_DIR.mkdir(parents=True, exist_ok=True)
OUT_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG_DIR / "01_build_f1_divergence.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("f1_div")


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
    ap.add_argument("--pop-year", type=int, default=2019,
                    help="ano de referência da população (denominador exposto)")
    ap.add_argument("--dist-quantile", type=float, default=0.75,
                    help="quantil de iso_km acima do qual = deserto de distância")
    ap.add_argument("--flow-quantile", type=float, default=0.75,
                    help="quantil de F1 acima do qual = deserto de fluxo")
    ap.add_argument("--dist-thresh-km", type=float, default=None,
                    help="se dado, deserto de distância = iso_km > este valor (absoluto)")
    ap.add_argument("--flow-thresh-km", type=float, default=None,
                    help="se dado, deserto de fluxo = F1 > este valor (absoluto)")
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    out_panel = OUT_DIR / "f1_divergence_panel.parquet"
    out_summary = OUT_DIR / "f1_divergence_quadrant_summary.csv"
    if out_panel.exists() and not args.force:
        log.info("output já existe (%s) — use --force para reprocessar", out_panel.name)
        return

    # --- telemetria de início ---
    t0 = time.perf_counter()
    try:
        import psutil

        vm = psutil.virtual_memory()
        ram_total, ram_avail = vm.total / 1e9, vm.available / 1e9
    except Exception:
        ram_total = ram_avail = float("nan")
    log.info("==== build f1 divergence ====")
    log.info("host=%s cores=%s git=%s ram_total=%.1fGiB ram_avail=%.1fGiB",
             socket.gethostname(), os.cpu_count(), _git_sha(), ram_total, ram_avail)
    log.info("window=%d-%d pop_year=%d dist_q=%.2f flow_q=%.2f dist_abs=%s flow_abs=%s",
             args.window_start, args.window_end, args.pop_year,
             args.dist_quantile, args.flow_quantile,
             args.dist_thresh_km, args.flow_thresh_km)

    for p in (INTER18 / "travel_burden_panel.parquet",
              INTER18 / "divergence_panel.parquet",
              INTER18 / "municipios_centroids.parquet"):
        if not p.exists():
            log.error("input ausente: %s", p)
            sys.exit(1)

    con = duckdb.connect()
    con.execute("PRAGMA threads=12")
    con.execute("PRAGMA memory_limit='14GB'")
    con.execute("PRAGMA temp_directory='/tmp/duckdb_paper19'")

    tb = (INTER18 / "travel_burden_panel.parquet").as_posix()
    dv = (INTER18 / "divergence_panel.parquet").as_posix()
    osrm = (INTER18 / "osrm_travel_time_panel.parquet").as_posix()
    cent = (INTER18 / "municipios_centroids.parquet").as_posix()
    pop = (INTER18 / "pop_municipal_2015_2025.parquet").as_posix()

    # thresholds: absolutos vencem; senão quantis da própria distribuição
    if args.dist_thresh_km is not None:
        dist_cut_sql = f"{args.dist_thresh_km}"
        dist_rule = f"abs>{args.dist_thresh_km}km"
    else:
        dist_cut_sql = f"quantile_cont(iso_km, {args.dist_quantile}) OVER ()"
        dist_rule = f"q{args.dist_quantile}"
    if args.flow_thresh_km is not None:
        flow_cut_sql = f"{args.flow_thresh_km}"
        flow_rule = f"abs>{args.flow_thresh_km}km"
    else:
        flow_cut_sql = f"quantile_cont(f1_km, {args.flow_quantile}) OVER ()"
        flow_rule = f"q{args.flow_quantile}"

    log.info("[1/3] agregando F1 (AIH-weighted, NaN-filtered) e juntando distância...")
    con.execute(
        f"""
        CREATE TEMP TABLE base AS
        WITH f1 AS (
            SELECT codmun_6,
                   SUM(travel_burden_km * n_aih_total) / SUM(n_aih_total) AS f1_km,
                   SUM(share_outflow * n_aih_total) / SUM(n_aih_total)      AS share_outflow,
                   SUM(n_aih_total)                                          AS aih_total
            FROM read_parquet('{tb}')
            WHERE year BETWEEN {args.window_start} AND {args.window_end}
              AND travel_burden_km IS NOT NULL AND NOT isnan(travel_burden_km)
            GROUP BY codmun_6
        ),
        popy AS (
            SELECT substr(cod_mun, 1, 6) AS codmun_6, pop
            FROM read_parquet('{pop}')
            WHERE ano = {args.pop_year}
        )
        SELECT f1.codmun_6,
               c.nome_mun, c.uf, c.lat, c.lon,
               f1.f1_km, f1.share_outflow, f1.aih_total,
               d.iso_km_hosp        AS iso_km,
               d.iso_emb_hosp       AS iso_emb,
               o.travel_time_min_proxy AS travel_time_min,
               f1.f1_km - d.iso_km_hosp AS gap_km,
               popy.pop
        FROM f1
        JOIN read_parquet('{dv}')   d USING (codmun_6)
        LEFT JOIN read_parquet('{osrm}') o USING (codmun_6)
        LEFT JOIN read_parquet('{cent}') c ON c.cod_mun_6 = f1.codmun_6
        LEFT JOIN popy USING (codmun_6)
        """
    )
    n_base = con.sql("SELECT COUNT(*) FROM base").fetchone()[0]
    log.info("    municípios no cross-section: %d (rss=%.2fGiB)", n_base, _rss_gib())

    log.info("[2/3] z-scores, divergência e taxonomia 2x2 (regra dist=%s, flow=%s)...",
             dist_rule, flow_rule)
    con.execute(
        f"""
        CREATE TEMP TABLE panel AS
        WITH z AS (
            SELECT *,
                   (iso_km  - AVG(iso_km)  OVER ()) / stddev_samp(iso_km)  OVER () AS iso_km_z,
                   (f1_km   - AVG(f1_km)   OVER ()) / stddev_samp(f1_km)   OVER () AS f1_km_z,
                   {dist_cut_sql} AS dist_cut,
                   {flow_cut_sql} AS flow_cut
            FROM base
        )
        SELECT *,
               (f1_km_z - iso_km_z)              AS divergence_z,
               (iso_km > dist_cut)               AS dist_desert,
               (f1_km  > flow_cut)               AS flow_desert,
               CASE
                   WHEN iso_km > dist_cut AND f1_km > flow_cut THEN 'both'
                   WHEN iso_km <= dist_cut AND f1_km > flow_cut THEN 'flow_only'
                   WHEN iso_km > dist_cut AND f1_km <= flow_cut THEN 'distance_only'
                   ELSE 'neither'
               END                               AS quadrant
        FROM z
        """
    )

    con.execute(
        f"COPY (SELECT * FROM panel ORDER BY divergence_z DESC) "
        f"TO '{out_panel.as_posix()}' (FORMAT PARQUET, COMPRESSION 'snappy')"
    )

    log.info("[3/3] resumo de quadrantes + população exposta...")
    summary = con.sql(
        """
        SELECT quadrant,
               COUNT(*)                              AS n_mun,
               ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER (), 1) AS pct_mun,
               SUM(COALESCE(pop, 0))                 AS pop_exposed,
               ROUND(100.0*SUM(COALESCE(pop,0))/SUM(SUM(COALESCE(pop,0))) OVER (), 1) AS pct_pop,
               ROUND(AVG(iso_km), 1)                 AS avg_iso_km,
               ROUND(AVG(f1_km), 1)                  AS avg_f1_km,
               ROUND(AVG(gap_km), 1)                 AS avg_gap_km
        FROM panel
        GROUP BY quadrant
        ORDER BY array_position(['flow_only','both','distance_only','neither'], quadrant)
        """
    ).df()
    summary.to_csv(out_summary, index=False)

    # headline descritivo
    head = con.sql(
        """
        SELECT ROUND(corr(f1_km, iso_km), 3) AS corr_f1_iso,
               ROUND(median(f1_km), 1)        AS med_f1,
               ROUND(median(iso_km), 1)       AS med_iso,
               ROUND(median(gap_km), 1)       AS med_gap
        FROM panel
        """
    ).fetchone()

    log.info("---- HEADLINE (descritivo) ----")
    log.info("corr(F1, distância)=%.3f | F1 mediano=%.1f km | dist mediana=%.1f km | gap mediano=%.1f km",
             head[0], head[1], head[2], head[3])
    log.info("\n%s", summary.to_string(index=False))
    log.info("outputs: %s ; %s", out_panel.name, out_summary.name)
    log.info("==== fim em %.1fs (rss_pico~%.2fGiB) ====", time.perf_counter() - t0, _rss_gib())


if __name__ == "__main__":
    main()
