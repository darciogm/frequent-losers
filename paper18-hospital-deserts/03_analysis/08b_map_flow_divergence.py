"""
08b_map_flow_divergence.py

Flow-based "Map of Revealed Access" — the headline measurement figure.

For each municipality, contrasts two isolation measures to the SUS
hospital network, both centroid-to-centroid (CNES carries no coordinates;
matches the distance rule E2 in the paper):

  iso_km   = haversine km to the NEAREST municipality hosting a SUS hospital
  iso_flow = admission-weighted distance to the hospitals residents
             ACTUALLY USED (travel_burden_km, averaged over the panel)

Divergence (z-scored, log1p for the long tails):
  divergence = z(iso_flow) - z(iso_km)

  divergence > 0 (red)  -> people travel farther than their nearest
                           hospital: referral crosses borders, distance
                           understates isolation.
  divergence < 0 (blue) -> the nearest hospital overstates isolation;
                           residents reach care closer than the map of
                           nearest facilities implies.

This is embedding-free by construction: it uses raw admission flows and
geography only, consistent with the share-based E1 treatment rule. The
node2vec divergence map (08_map_divergence.py) is a separate diagnostic.

Outputs:
- 04_figures/fig_map_flow_divergence.pdf / .png
- 02_data/intermediate/flow_divergence_panel.parquet
"""

from __future__ import annotations

import argparse
import logging
import sys
import time
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import duckdb
import psutil
import geopandas as gpd

ROOT = Path(__file__).resolve().parents[1]
INTER = ROOT / "02_data" / "intermediate"
RAW = ROOT / "02_data" / "raw"
LOG = ROOT / "04_logs"
FIG = ROOT / "04_figures"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "08b_map_flow_divergence.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("flowmap")

TRAVEL = INTER / "travel_burden_panel.parquet"
EDGES = INTER / "bipartite_edges_pooled.parquet"
MASTER = INTER / "hospital_master.parquet"
CENT = INTER / "municipios_centroids.parquet"
MUN_GPKG = RAW / "ibge" / "municipios_2010.gpkg"
ST_GPKG = RAW / "ibge" / "estados_2010.gpkg"

OUT_PARQUET = INTER / "flow_divergence_panel.parquet"
OUT_PDF = FIG / "fig_map_flow_divergence.pdf"

plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "font.size": 9,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "savefig.dpi": 300,
    "savefig.bbox": "tight",
})


def haversine_min(lat_q, lon_q, lat_t, lon_t):
    """Min great-circle km from each query point to a target set."""
    lat_q_r = np.deg2rad(lat_q)[:, None]
    lon_q_r = np.deg2rad(lon_q)[:, None]
    lat_t_r = np.deg2rad(lat_t)[None, :]
    lon_t_r = np.deg2rad(lon_t)[None, :]
    dlat = lat_t_r - lat_q_r
    dlon = lon_t_r - lon_q_r
    a = np.sin(dlat / 2)**2 + np.cos(lat_q_r) * np.cos(lat_t_r) * np.sin(dlon / 2)**2
    return (2 * 6371 * np.arcsin(np.sqrt(np.clip(a, 0, 1)))).min(axis=1)


def main(force: bool):
    t0 = time.perf_counter()
    vm = psutil.virtual_memory()
    log.info("==== flow divergence map | host=%s cores=%d RAM=%.1fG free=%.1fG ====",
             Path("/etc/hostname").read_text().strip() if Path("/etc/hostname").exists() else "?",
             psutil.cpu_count(), vm.total / 1e9, vm.available / 1e9)
    if OUT_PDF.exists() and not force:
        log.info("output exists, skipping (use --force): %s", OUT_PDF)
        return

    con = duckdb.connect()
    con.execute("PRAGMA threads=12")
    con.execute("PRAGMA memory_limit='14GB'")

    # ---- iso_flow: admission-weighted distance to used hospitals ----
    # panel mean of travel_burden_km per municipality (embedding-free).
    iso_flow = con.execute(f"""
        SELECT lpad(codmun_6, 6, '0') AS codmun_6,
               AVG(travel_burden_km)   AS iso_flow,
               SUM(n_aih_total)        AS n_aih
        FROM read_parquet('{TRAVEL}')
        GROUP BY 1
    """).df()
    log.info("iso_flow munis=%d  median=%.1f km",
             len(iso_flow), iso_flow["iso_flow"].median())

    # ---- hospital municipalities: distinct destinations that received
    #      SUS admissions, located at the hospital's modal municipality ---
    cent = con.execute(f"""
        SELECT lpad(cod_mun_6, 6, '0') AS codmun_6, lat, lon, uf
        FROM read_parquet('{CENT}')
        WHERE lat IS NOT NULL AND lon IS NOT NULL
    """).df()

    hosp_mun = con.execute(f"""
        SELECT DISTINCT lpad(m.codmun_6_modal, 6, '0') AS codmun_6
        FROM (SELECT DISTINCT CNES FROM read_parquet('{EDGES}')) e
        JOIN read_parquet('{MASTER}') m USING (CNES)
        WHERE m.codmun_6_modal IS NOT NULL
    """).df()
    hosp_cent = hosp_mun.merge(cent, on="codmun_6", how="inner")
    log.info("hospital-hosting municipalities with centroid: %d", len(hosp_cent))

    # ---- iso_km: nearest hospital-hosting municipality --------------
    q = cent.copy()
    iso_km = haversine_min(q["lat"].to_numpy(), q["lon"].to_numpy(),
                           hosp_cent["lat"].to_numpy(), hosp_cent["lon"].to_numpy())
    q["iso_km"] = iso_km
    log.info("iso_km median=%.1f km  p95=%.1f km",
             np.median(iso_km), np.percentile(iso_km, 95))

    # ---- merge, z-score, divergence --------------------------------
    panel = q.merge(iso_flow, on="codmun_6", how="inner")
    # drop municipalities with no recorded admissions (NaN travel burden)
    n_pre = len(panel)
    panel = panel[panel["iso_flow"].notna() & panel["iso_km"].notna()].copy()
    log.info("dropped %d munis with missing iso_flow/iso_km; %d remain",
             n_pre - len(panel), len(panel))
    for col, src in [("iso_km_z", "iso_km"), ("iso_flow_z", "iso_flow")]:
        v = np.log1p(panel[src].to_numpy())
        panel[col] = (v - np.nanmean(v)) / np.nanstd(v)
    panel["divergence_z"] = panel["iso_flow_z"] - panel["iso_km_z"]
    log.info("divergence: median=%+.3f p05=%+.3f p95=%+.3f sd=%.3f",
             panel["divergence_z"].median(),
             np.percentile(panel["divergence_z"], 5),
             np.percentile(panel["divergence_z"], 95),
             panel["divergence_z"].std())
    panel.to_parquet(OUT_PARQUET, compression="snappy")
    log.info("wrote %s (n=%d)", OUT_PARQUET, len(panel))

    # ---- map --------------------------------------------------------
    gdf = gpd.read_file(MUN_GPKG)
    gdf["codmun_6"] = gdf["code_muni"].astype("int64").astype(str).str.zfill(7).str[:6]
    gdf = gdf.merge(panel[["codmun_6", "divergence_z"]], on="codmun_6", how="left")
    log.info("gdf rows=%d  non-NA divergence=%d", len(gdf), gdf["divergence_z"].notna().sum())
    states = gpd.read_file(ST_GPKG)

    fig, ax = plt.subplots(1, 1, figsize=(8.5, 8.5))
    vmax = float(np.percentile(np.abs(panel["divergence_z"].to_numpy()), 95))
    gdf.plot(
        column="divergence_z", cmap="RdBu_r", vmin=-vmax, vmax=vmax,
        legend=True,
        legend_kwds={"label": "Flow isolation $-$ distance isolation (z)",
                     "shrink": 0.55, "orientation": "vertical"},
        missing_kwds={"color": "0.92", "edgecolor": "0.85", "linewidth": 0.05},
        edgecolor="none", linewidth=0, ax=ax,
    )
    states.boundary.plot(ax=ax, color="black", linewidth=0.4)
    ax.set_axis_off()
    fig.savefig(OUT_PDF)
    fig.savefig(FIG / "fig_map_flow_divergence.png", dpi=200)
    plt.close(fig)
    log.info("wrote %s", OUT_PDF)

    # ---- console: most divergent municipalities (sanity) ------------
    named = con.execute(f"""
        SELECT lpad(cod_mun_6,6,'0') AS codmun_6, nome_mun, uf
        FROM read_parquet('{CENT}')
    """).df()
    pn = panel.merge(named[["codmun_6", "nome_mun"]], on="codmun_6", how="left")
    log.info("=== top-10 RED (flow >> distance: bypass nearest) ===")
    for _, r in pn.sort_values("divergence_z", ascending=False).head(10).iterrows():
        log.info("  %s %s-%s km=%.0f flow=%.0f div=%+.2f",
                 r["codmun_6"], r["nome_mun"], r["uf"], r["iso_km"], r["iso_flow"], r["divergence_z"])
    log.info("=== top-10 BLUE (distance >> flow) ===")
    for _, r in pn.sort_values("divergence_z").head(10).iterrows():
        log.info("  %s %s-%s km=%.0f flow=%.0f div=%+.2f",
                 r["codmun_6"], r["nome_mun"], r["uf"], r["iso_km"], r["iso_flow"], r["divergence_z"])

    log.info("==== done elapsed=%.1fs RSS=%.2fGB ====",
             time.perf_counter() - t0, psutil.Process().memory_info().rss / 1e9)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    main(ap.parse_args().force)
