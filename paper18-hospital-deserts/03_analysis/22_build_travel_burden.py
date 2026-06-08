"""
22_build_travel_burden.py

Painel município × ano de travel burden = distância média ponderada (por
n_internações) entre o centroide do município de residência e o centroide
do município do hospital onde o paciente internou.

Aproximação município-a-município é o padrão na literatura brasileira de
access (Macinko et al. 2011, Dourado et al. 2011) porque (i) hospitais
SUS não têm coordenadas em CNES, (ii) within-municipality distances são
pequenas relativas a between-municipality, especialmente fora de regiões
metropolitanas. Em municípios capitais (RJ, SP, BH), há viés de
subestimação que documentamos em §robustness.

Outcome travel_burden_km_t,m = sum_h (n_int_t,m,h × d_centroid(m, mun(h))) / sum_h n_int_t,m,h

Hospitais no mesmo município do paciente → distância 0.

Outcome variante (no apêndice): travel_burden_emb_t,m
  = mesmo cálculo, mas usando embedding-distance no lugar de km. Útil
    para mostrar que o "first stage" do paper (fechamento aumenta travel
    burden) sobrevive sob ambas as métricas, com magnitudes diferentes.

Output: 02_data/intermediate/travel_burden_panel.parquet
  Schema: codmun_6, year, travel_burden_km, travel_burden_emb,
          n_aih_total, share_outflow (frac aih em hosp fora do município)
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
        logging.FileHandler(LOG / "22_build_travel_burden.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("travel")

EDGES_IN = INTER / "bipartite_edges.parquet"
MASTER_IN = INTER / "hospital_master.parquet"
CENT_IN = INTER / "municipios_centroids.parquet"
EMB_IN = INTER / "embeddings_munmun_proj.parquet"
OUT = INTER / "travel_burden_panel.parquet"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    if OUT.exists() and not args.force:
        log.info("output já existe — usar --force para reprocessar")
        return

    t0 = time.time()
    log.info("==== begin travel burden build ====")

    con = duckdb.connect()
    con.execute("PRAGMA threads=12")
    con.execute("PRAGMA memory_limit='14GB'")
    con.execute("PRAGMA temp_directory='/tmp/duckdb_paper18'")

    # ---- 1) materializar pares (codmun_residente, codmun_hospital, ano, n) ----
    log.info("[1/4] juntando bipartite_edges com hospital_master para mapear hospital -> município...")
    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE flow AS
        SELECT
            e.codmun_6        AS codmun_res,
            m.codmun_6_modal  AS codmun_hosp,
            e.year,
            e.n_internacoes
        FROM read_parquet('{EDGES_IN}') e
        JOIN read_parquet('{MASTER_IN}') m USING (CNES)
        WHERE e.year BETWEEN 2010 AND 2024
          AND m.codmun_6_modal IS NOT NULL
    """)
    n_flow = con.sql("SELECT COUNT(*) FROM flow").fetchone()[0]
    log.info("    pares (res, hosp, ano): %s rows", f"{n_flow:,}")

    # ---- 2) centroides como dict {codmun -> (lat, lon)} ----
    log.info("[2/4] carregando centroides...")
    cent = pl.read_parquet(CENT_IN).select(["cod_mun_6", "lat", "lon"])
    cent_pd = cent.to_pandas().set_index("cod_mun_6")
    log.info("    centroides: %d munis", len(cent))

    # ---- 3) emb dictionary (para travel_burden_emb) ----
    log.info("[3/4] carregando embeddings (para variante emb)...")
    emb_df = pl.read_parquet(EMB_IN)
    dim_cols = [c for c in emb_df.columns if c.startswith("dim_")]
    emb_arr = emb_df.select(dim_cols).to_numpy().astype(np.float32)
    emb_munis = emb_df["cod_mun_6"].to_list()
    norms = np.linalg.norm(emb_arr, axis=1, keepdims=True)
    emb_norm = emb_arr / np.where(norms > 0, norms, 1)
    emb_idx = {m: i for i, m in enumerate(emb_munis)}
    log.info("    embeddings: %d munis", len(emb_munis))

    # ---- 4) computar travel burden por (codmun_res, year) ----
    log.info("[4/4] agregando flow + computando distâncias...")
    flow_df = con.sql("""
        SELECT codmun_res, codmun_hosp, year, n_internacoes
        FROM flow
    """).pl()

    # decide pairs unique (m_res, m_hosp) para cachear distâncias
    pairs_unique = flow_df.select(["codmun_res", "codmun_hosp"]).unique()
    log.info("    pares únicos (res, hosp): %d", len(pairs_unique))

    # vetorizar haversine sobre os pares únicos
    res_ids = pairs_unique["codmun_res"].to_list()
    hosp_ids = pairs_unique["codmun_hosp"].to_list()

    def lookup_lat_lon(ids):
        lats = np.full(len(ids), np.nan)
        lons = np.full(len(ids), np.nan)
        for i, m in enumerate(ids):
            if m in cent_pd.index:
                lats[i] = cent_pd.at[m, "lat"]
                lons[i] = cent_pd.at[m, "lon"]
        return lats, lons

    lat_r, lon_r = lookup_lat_lon(res_ids)
    lat_h, lon_h = lookup_lat_lon(hosp_ids)

    lat_r_rad = np.deg2rad(lat_r); lat_h_rad = np.deg2rad(lat_h)
    dlat = lat_h_rad - lat_r_rad
    dlon = np.deg2rad(lon_h - lon_r)
    a = (np.sin(dlat / 2) ** 2
         + np.cos(lat_r_rad) * np.cos(lat_h_rad) * np.sin(dlon / 2) ** 2)
    dist_km = 2 * 6371 * np.arcsin(np.sqrt(np.clip(a, 0, 1)))

    # embedding distance pra cada par
    dist_emb = np.full(len(res_ids), np.nan, dtype=np.float32)
    for i, (mr, mh) in enumerate(zip(res_ids, hosp_ids)):
        if mr in emb_idx and mh in emb_idx:
            v_r = emb_norm[emb_idx[mr]]
            v_h = emb_norm[emb_idx[mh]]
            dist_emb[i] = float(1 - v_r @ v_h)

    pairs_dist = pairs_unique.with_columns([
        pl.Series("dist_km", dist_km),
        pl.Series("dist_emb", dist_emb),
    ])
    log.info("    dist_km median=%.1f mean=%.1f max=%.0f",
             np.nanmedian(dist_km), np.nanmean(dist_km), np.nanmax(dist_km))

    # join distâncias de volta no flow_df
    flow_dist = flow_df.join(
        pairs_dist, on=["codmun_res", "codmun_hosp"], how="left"
    )

    # weighted average por (codmun_res, year)
    panel = flow_dist.group_by(["codmun_res", "year"]).agg([
        ((pl.col("n_internacoes") * pl.col("dist_km")).sum()
         / pl.col("n_internacoes").sum()).alias("travel_burden_km"),
        ((pl.col("n_internacoes") * pl.col("dist_emb")).sum()
         / pl.col("n_internacoes").sum()).alias("travel_burden_emb"),
        pl.col("n_internacoes").sum().alias("n_aih_total"),
        ((pl.col("codmun_res") != pl.col("codmun_hosp"))
         .cast(pl.Float64) * pl.col("n_internacoes")).sum().alias("n_outflow"),
    ]).with_columns(
        share_outflow=pl.col("n_outflow") / pl.col("n_aih_total"),
    ).rename({"codmun_res": "codmun_6"}).sort(["codmun_6", "year"])

    panel.write_parquet(OUT, compression="snappy")
    log.info("wrote %s (rows=%d)", OUT, len(panel))

    # sumarios
    log.info("\n=== distribuição travel_burden_km por ano (mean, p25, p50, p75) ===")
    summ = con.sql(f"""
        SELECT year,
               COUNT(*) AS n_munis,
               AVG(travel_burden_km) AS mean_km,
               QUANTILE_CONT(travel_burden_km, 0.25) AS p25_km,
               QUANTILE_CONT(travel_burden_km, 0.50) AS p50_km,
               QUANTILE_CONT(travel_burden_km, 0.75) AS p75_km,
               AVG(share_outflow) AS share_outflow_mean
        FROM read_parquet('{OUT}')
        GROUP BY year ORDER BY year
    """).pl()
    log.info("\n%s", summ)

    log.info("==== done ==== elapsed %.1fs", time.time() - t0)


if __name__ == "__main__":
    main()
