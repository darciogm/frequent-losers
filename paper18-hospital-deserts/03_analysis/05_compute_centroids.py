"""
05_compute_centroids.py

Lê o shapefile IBGE de municípios (paper5 link), calcula centroide de cada
município em coordenadas geográficas (WGS84 lat/lon) e em projeção métrica
para distância Euclidiana confiável.

Output:
- 02_data/intermediate/municipios_centroids.parquet
  Schema: cod_mun_7 (IBGE 7 dig), cod_mun_6 (DATASUS 6 dig),
          nome_mun, uf, lat, lon, x_m, y_m (Albers/Polyconic Brazil)

Distância par-a-par é calculada on-demand depois (5570² = 31M pares).
"""

from __future__ import annotations

import logging
import sys
import time
from pathlib import Path

import geopandas as gpd
import polars as pl

ROOT = Path(__file__).resolve().parents[1]
RAW_IBGE = ROOT / "02_data" / "raw" / "ibge"
INTER = ROOT / "02_data" / "intermediate"
LOG = ROOT / "04_logs"
INTER.mkdir(parents=True, exist_ok=True)
LOG.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "05_compute_centroids.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("centroid")

OUT = INTER / "municipios_centroids.parquet"


def main():
    t0 = time.time()
    log.info("==== begin centroids ====")
    src = RAW_IBGE / "municipios_2010.gpkg"
    log.info("reading %s", src)
    gdf = gpd.read_file(src)
    log.info("rows: %d, crs: %s, cols: %s", len(gdf), gdf.crs, list(gdf.columns)[:15])

    # achar coluna com código IBGE 7 dígitos e nome
    cl = {c.lower(): c for c in gdf.columns}
    code_col = next((cl[c] for c in cl if c in ("code_muni", "cd_mun", "geocodigo", "geocodi")
                     or ("code" in c and "muni" in c)), None)
    name_col = next((cl[c] for c in cl if c in ("name_muni", "nm_mun", "nome", "nome_muni")
                     or ("name" in c and "muni" in c)), None)
    uf_col = next((cl[c] for c in cl if c in ("abbrev_state", "sigla_uf", "uf", "estado", "sigla")), None)
    log.info("col map: code=%s name=%s uf=%s", code_col, name_col, uf_col)

    # converter CRS de origem para WGS84 (lat/lon)
    if gdf.crs is None or gdf.crs.to_epsg() != 4326:
        gdf_ll = gdf.to_crs(epsg=4326)
    else:
        gdf_ll = gdf

    # centroides em lat/lon (silenciar warning de centroides em CRS geográfico — adequado p/ Brasil)
    import warnings
    warnings.filterwarnings("ignore", category=UserWarning)
    centroids_ll = gdf_ll.geometry.centroid
    lons = centroids_ll.x.values
    lats = centroids_ll.y.values

    # projetado em Albers Brasil (EPSG:5880 SIRGAS 2000 / Brasil Polyconic) p/ distância métrica
    gdf_m = gdf.to_crs(epsg=5880)
    centroids_m = gdf_m.geometry.centroid
    xs = centroids_m.x.values
    ys = centroids_m.y.values

    # converter para int primeiro evita "1100015.0" quando coluna vier como float
    cod_7 = list(gdf[code_col].astype("int64").astype(str).str.zfill(7))
    nome = list(gdf[name_col].astype(str)) if name_col else [""] * len(gdf)
    ufs = list(gdf[uf_col].astype(str)) if uf_col else [""] * len(gdf)

    df = pl.DataFrame({
        "cod_mun_7": cod_7,
        "cod_mun_6": [c[:6] for c in cod_7],
        "nome_mun": nome,
        "uf": ufs,
        "lat": lats,
        "lon": lons,
        "x_m": xs,
        "y_m": ys,
    })
    df.write_parquet(OUT, compression="snappy")
    log.info("wrote %s (rows=%d)", OUT, len(df))

    # sanity
    log.info("\n=== summary ===\n%s",
             df.select(["lat", "lon", "x_m", "y_m"]).describe())
    log.info("first 5:\n%s", df.head(5))
    log.info("==== done ==== elapsed %.1fs", time.time() - t0)


if __name__ == "__main__":
    main()
