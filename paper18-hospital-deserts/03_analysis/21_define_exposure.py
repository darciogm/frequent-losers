"""
21_define_exposure.py

Para cada fechamento exógeno (do S1 = hospital_closures_exogenous.parquet),
define qual conjunto de municípios foi exposto ao choque, sob duas
definições de exposure que são o coração do paper:

  (E1) embedding-based exposure:
       município m é exposto se a aresta (m, h_fechou) no ano pré-fechamento
       teve share = n_internacoes(m,h) / sum_h n_internacoes(m,·) >= θ_emb.
       Default θ_emb = 0.05 (5%). Salva também a share contínua para usar
       como treatment intensity em CS21 weighted e em causal forest (R3).

  (E2) km-based exposure (placebo causal):
       município m é km-exposto se h_fechou está entre os top-3 hospitais
       mais próximos a m por distância haversine centroide-a-centroide no
       ano pré-fechamento, INDEPENDENTEMENTE de pacientes irem ou não.

A diferença entre os conjuntos (E1 \ E2 e E2 \ E1) é a contribuição
metodológica do paper: o embedding identifica municípios afetados que
o km não identifica, e descarta municípios que km classificaria como
afetados mas não estavam usando o hospital.

Output: 02_data/intermediate/exposure_panel.parquet
  Schema: codmun_6, CNES, year_closure,
          share_emb (float), exposed_emb (bool),
          dist_km (float), rank_km (int), exposed_km (bool),
          uf, region, n_aih_pre

Ano de pré-fechamento: year_closure - 1 (consistente com S1).

Threshold robustness: testar θ_emb ∈ {0.01, 0.05, 0.10, 0.25} em S6.
Default 0.05.
"""

from __future__ import annotations

import argparse
import logging
import sys
import time
from pathlib import Path

import duckdb
import numpy as np
import polars as pl

ROOT = Path(__file__).resolve().parents[1]
INTER = ROOT / "02_data" / "intermediate"
LOG = ROOT / "04_logs"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "21_define_exposure.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("exposure")

CLOSURES_IN = INTER / "hospital_closures_exogenous.parquet"
EDGES_IN = INTER / "bipartite_edges.parquet"
MASTER_IN = INTER / "hospital_master.parquet"
CENT_IN = INTER / "municipios_centroids.parquet"
OUT = INTER / "exposure_panel.parquet"

THETA_EMB = 0.05
TOP_K_KM = 3


def haversine_km(lat1, lon1, lat2, lon2):
    lat1r, lat2r = np.deg2rad(lat1), np.deg2rad(lat2)
    dlat = lat2r - lat1r
    dlon = np.deg2rad(lon2 - lon1)
    a = (np.sin(dlat / 2) ** 2
         + np.cos(lat1r) * np.cos(lat2r) * np.sin(dlon / 2) ** 2)
    return 2 * 6371 * np.arcsin(np.sqrt(np.clip(a, 0, 1)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--theta", type=float, default=THETA_EMB,
                    help="threshold de exposed_emb (share mínimo)")
    args = ap.parse_args()

    if OUT.exists() and not args.force:
        log.info("output já existe — usar --force para reprocessar")
        return

    t0 = time.time()
    log.info("==== begin define exposure ====")
    log.info("theta_emb=%.3f  top_k_km=%d", args.theta, TOP_K_KM)

    con = duckdb.connect()
    con.execute("PRAGMA threads=12")
    con.execute("PRAGMA memory_limit='14GB'")

    # ---- 1) carregar 60 closures exógenos ----
    closures = con.sql(f"""
        SELECT CNES, codmun_6 AS codmun_hosp, year_closure
        FROM read_parquet('{CLOSURES_IN}')
        WHERE exogenous = TRUE
    """).pl()
    log.info("closures exógenos: %d", len(closures))

    # ---- 2) ler centroides municipais (e UF) ----
    cent = pl.read_parquet(CENT_IN).select(
        ["cod_mun_6", "uf", "lat", "lon"]
    )
    cent_dict = {row[0]: (row[2], row[3], row[1])
                 for row in cent.iter_rows()}  # codmun -> (lat, lon, uf)
    log.info("centroides carregados: %d munis", len(cent_dict))

    # ---- 3) hospitais master (codmun do hospital, p/ haversine top-K) ----
    hosp_master = con.sql(f"""
        SELECT CNES, codmun_6_modal AS codmun_hosp
        FROM read_parquet('{MASTER_IN}')
    """).pl()
    log.info("hospitais master: %d", len(hosp_master))
    hosp_loc = {row[0]: row[1] for row in hosp_master.iter_rows()}

    # ---- 4) construir painel de exposure por (CNES_fechou, codmun) ----
    rows_out = []
    for ic, c in enumerate(closures.iter_rows(named=True)):
        cnes_h = c["CNES"]
        codmun_hosp = c["codmun_hosp"]
        year_pre = c["year_closure"] - 1

        if codmun_hosp not in cent_dict:
            log.warning("hospital %s sem centroide do municipio %s, pulando",
                        cnes_h, codmun_hosp)
            continue
        lat_h, lon_h, uf_h = cent_dict[codmun_hosp]

        # (a) E1: municipios que mandavam pacientes p/ esse hospital no ano pre,
        #         calcular share = n_int(m,h) / sum_h n_int(m,*)
        share_df = con.sql(f"""
            WITH muni_total AS (
                SELECT codmun_6, SUM(n_internacoes) AS total_aih
                FROM read_parquet('{EDGES_IN}')
                WHERE year = {year_pre}
                GROUP BY codmun_6
            ),
            muni_to_h AS (
                SELECT codmun_6, n_internacoes
                FROM read_parquet('{EDGES_IN}')
                WHERE year = {year_pre} AND CNES = '{cnes_h}'
            )
            SELECT m.codmun_6,
                   COALESCE(mh.n_internacoes, 0) AS n_to_h,
                   m.total_aih,
                   1.0 * COALESCE(mh.n_internacoes, 0) / NULLIF(m.total_aih, 0) AS share
            FROM muni_total m
            LEFT JOIN muni_to_h mh USING (codmun_6)
        """).pl()

        # quem manda algum paciente
        share_pos = share_df.filter(pl.col("n_to_h") > 0)

        # (b) E2: top-K km vizinhos do hospital (no universo de munis)
        codmuns = list(cent_dict.keys())
        lats = np.array([cent_dict[m][0] for m in codmuns])
        lons = np.array([cent_dict[m][1] for m in codmuns])
        d_km = haversine_km(lat_h, lon_h, lats, lons)
        # rank ascendente (0 = mesmo município = 0 km, 1 = mais próximo, etc)
        order = np.argsort(d_km)
        rank_of = {codmuns[order[i]]: i for i in range(len(order))}
        d_of = {codmuns[i]: float(d_km[i]) for i in range(len(codmuns))}

        # (c) união dos dois conjuntos para gerar linhas no painel
        all_munis = set(share_pos["codmun_6"].to_list()) | {
            codmuns[order[i]] for i in range(min(TOP_K_KM + 1, len(order)))
        }

        share_map = {row[0]: float(row[3]) if row[3] is not None else 0.0
                     for row in share_pos.iter_rows()}
        n_aih_map = {row[0]: int(row[1]) for row in share_pos.iter_rows()}

        for m in all_munis:
            if m not in cent_dict:
                continue
            uf_m = cent_dict[m][2]
            sh = share_map.get(m, 0.0)
            d = d_of.get(m, np.nan)
            r = rank_of.get(m, -1)
            n_aih = n_aih_map.get(m, 0)
            rows_out.append({
                "codmun_6":      m,
                "CNES":          cnes_h,
                "year_closure":  c["year_closure"],
                "codmun_hosp":   codmun_hosp,
                "uf":            uf_m,
                "share_emb":     sh,
                "exposed_emb":   sh >= args.theta,
                "dist_km":       d,
                "rank_km":       r,
                "exposed_km":    r >= 0 and r <= TOP_K_KM,  # rank=0 é o próprio mun do hospital
                "n_aih_pre":     n_aih,
            })

        if (ic + 1) % 10 == 0:
            log.info("[%d/%d] processados  rows acum=%d",
                     ic + 1, len(closures), len(rows_out))

    panel = pl.DataFrame(rows_out)
    log.info("rows totais no painel: %d", len(panel))
    panel.write_parquet(OUT, compression="snappy")
    log.info("wrote %s", OUT)

    # ---- 5) sumarios ----
    log.info("\n=== contagem por flag ===")
    log.info("\n%s", panel.group_by(["exposed_emb", "exposed_km"])
                          .agg(pl.len().alias("n"))
                          .sort(["exposed_emb", "exposed_km"]))

    log.info("\n=== exposure por fechamento (mediana e percentis) ===")
    by_close = panel.group_by(["CNES", "year_closure"]).agg([
        pl.col("exposed_emb").sum().alias("n_exp_emb"),
        pl.col("exposed_km").sum().alias("n_exp_km"),
        ((pl.col("exposed_emb")) & (~pl.col("exposed_km"))).sum().alias("n_emb_only"),
        ((~pl.col("exposed_emb")) & (pl.col("exposed_km"))).sum().alias("n_km_only"),
        ((pl.col("exposed_emb")) & (pl.col("exposed_km"))).sum().alias("n_both"),
    ])
    log.info("\n%s", by_close.describe())

    log.info("\n=== top 5 fechamentos por |E1 \\ E2| (embedding pega que km não pegou) ===")
    log.info("\n%s", by_close.sort("n_emb_only", descending=True).head(5))

    log.info("==== done ==== elapsed %.1fs", time.time() - t0)


if __name__ == "__main__":
    main()
