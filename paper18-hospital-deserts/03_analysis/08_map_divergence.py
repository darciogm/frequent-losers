"""
08_map_divergence.py

Main map for the exposure-measurement result (Pivô A "Map of Revealed Access").

Para cada município, compara duas medidas de isolamento ao hospital de
alta complexidade mais próximo:
  iso_km_hosp_z  = z-score(log(km haversine ao nearest high-complex hospital))
  iso_emb_hosp_z = z-score(emb-distance ao mesmo conjunto)

Métrica de divergência:
  divergence_i = iso_emb_hosp_z_i - iso_km_hosp_z_i

  divergence > 0 → embedding diz "MAIS isolado" do que o mapa sugere
                   (o paciente desvia para um hub mais distante; nearest
                   geográfico é ruim/saturado/inadequado)
  divergence < 0 → embedding diz "MENOS isolado" do que o mapa sugere
                   (paciente cruza fronteira UF/usa hub informal mais perto
                    do que indicaria estradas pavimentadas)
  divergence ≈ 0 → mapa = realidade

Outputs:
- 04_figures/fig_map_divergence.pdf  (headline)
- 04_figures/fig_map_iso_km.pdf
- 04_figures/fig_map_iso_emb.pdf
- 02_data/intermediate/divergence_panel.parquet (codmun_6, lat, lon, uf,
  iso_km_hosp, iso_emb_hosp, divergence_z)
"""

from __future__ import annotations

import logging
import sys
import time
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import polars as pl
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
        logging.FileHandler(LOG / "08_map_divergence.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("map")

EMB_BIP = INTER / "embeddings_node2vec.parquet"
CENT = INTER / "municipios_centroids.parquet"
HUB = INTER / "hospital_hub_classification.parquet"
MASTER = INTER / "hospital_master.parquet"
MUN_GPKG = RAW / "ibge" / "municipios_2010.gpkg"
ST_GPKG = RAW / "ibge" / "estados_2010.gpkg"

OUT_PARQUET = INTER / "divergence_panel.parquet"

HIGH_COMPLEX = {"CARDIO", "ONCO", "NEURO", "RENAL",
                "PERINAT", "TRAUMA_ORTO", "TRANSPLANTE"}

plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "font.size": 9,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "savefig.dpi": 300,
    "savefig.bbox": "tight",
})


def haversine_to_set(lat_q, lon_q, lat_t, lon_t):
    lat_q_r = np.deg2rad(lat_q)[:, None]
    lon_q_r = np.deg2rad(lon_q)[:, None]
    lat_t_r = np.deg2rad(lat_t)[None, :]
    lon_t_r = np.deg2rad(lon_t)[None, :]
    dlat = lat_t_r - lat_q_r
    dlon = lon_t_r - lon_q_r
    a = np.sin(dlat / 2)**2 + np.cos(lat_q_r) * np.cos(lat_t_r) * np.sin(dlon / 2)**2
    d = 2 * 6371 * np.arcsin(np.sqrt(np.clip(a, 0, 1)))
    return d.min(axis=1), d.argmin(axis=1)


def main():
    t0 = time.perf_counter()
    log.info("==== begin map divergence ====")

    # ---- hospital alta-complex com vetor bipartite ------------------
    hub = pl.read_parquet(HUB).filter(
        (pl.col("CNES").str.strip_chars() != "") &
        (pl.col("hub_categoria").is_in(list(HIGH_COMPLEX))) &
        (pl.col("hub_ativo_qualquer_mes"))
    ).select(["CNES", "codmun_6"]).unique()
    master = pl.read_parquet(MASTER).select(["CNES", "codmun_6_modal"])
    hub = hub.join(master, on="CNES", how="left").with_columns(
        pl.coalesce(pl.col("codmun_6_modal"), pl.col("codmun_6"))
        .alias("codmun_6_loc")
    )
    cent = pl.read_parquet(CENT).select(["cod_mun_6", "lat", "lon", "uf"])
    hub_cent = hub.join(cent, left_on="codmun_6_loc", right_on="cod_mun_6", how="inner")

    emb_bip = pl.read_parquet(EMB_BIP)
    bip_M = emb_bip.filter(pl.col("node_type") == "M").rename({"node_id": "codmun_6"})
    bip_H = emb_bip.filter(pl.col("node_type") == "H").rename({"node_id": "CNES"})
    dim_cols = [c for c in emb_bip.columns if c.startswith("dim_")]

    hub_with_vec = hub_cent.join(bip_H.select(["CNES"] + dim_cols),
                                 on="CNES", how="inner")
    hub_emb = hub_with_vec.select(dim_cols).to_numpy().astype(np.float32)
    hub_lat = hub_with_vec["lat"].to_numpy()
    hub_lon = hub_with_vec["lon"].to_numpy()
    log.info("hospitais alta-complex com vetor bipartite: %d", len(hub_with_vec))

    # ---- municípios -------------------------------------------------
    mun_panel = cent.join(
        bip_M.select(["codmun_6"] + dim_cols),
        left_on="cod_mun_6", right_on="codmun_6", how="inner"
    )
    log.info("municípios com vetor bipartite + centroide: %d", len(mun_panel))

    munis = mun_panel["cod_mun_6"].to_list()
    lat = mun_panel["lat"].to_numpy()
    lon = mun_panel["lon"].to_numpy()
    uf = mun_panel["uf"].to_list()
    n = len(munis)
    mun_emb = mun_panel.select(dim_cols).to_numpy().astype(np.float32)

    # ---- iso_km_hosp + iso_emb_hosp --------------------------------
    iso_km, _ = haversine_to_set(lat, lon, hub_lat, hub_lon)
    mn = mun_emb / (np.linalg.norm(mun_emb, axis=1, keepdims=True) + 1e-12)
    hn = hub_emb / (np.linalg.norm(hub_emb, axis=1, keepdims=True) + 1e-12)
    sim = mn @ hn.T
    iso_emb = 1 - sim.max(axis=1)
    log.info("iso_km median=%.1fkm  iso_emb median=%.4f",
             np.median(iso_km), np.median(iso_emb))

    # z-score (log para iso_km porque é cauda longa)
    iso_km_log = np.log1p(iso_km)
    iso_km_z = (iso_km_log - iso_km_log.mean()) / iso_km_log.std()
    iso_emb_z = (iso_emb - iso_emb.mean()) / iso_emb.std()
    divergence = iso_emb_z - iso_km_z
    log.info("divergence: median=%+.3f  p05=%+.3f  p95=%+.3f  sd=%.3f",
             np.median(divergence), np.percentile(divergence, 5),
             np.percentile(divergence, 95), divergence.std())

    # ---- exporta painel -------------------------------------------
    panel = pl.DataFrame({
        "codmun_6": munis,
        "uf": uf,
        "lat": lat,
        "lon": lon,
        "iso_km_hosp": iso_km,
        "iso_emb_hosp": iso_emb,
        "iso_km_z": iso_km_z,
        "iso_emb_z": iso_emb_z,
        "divergence_z": divergence,
    })
    panel.write_parquet(OUT_PARQUET, compression="snappy")
    log.info("wrote %s (n=%d)", OUT_PARQUET, len(panel))

    # ---- mapa: shapefile + merge --------------------------------
    log.info("loading shapefile %s", MUN_GPKG)
    gdf = gpd.read_file(MUN_GPKG)
    # code_muni é float em alguns layers do IBGE; normaliza para 6-dig
    gdf["codmun_6"] = gdf["code_muni"].astype(int).astype(str).str[:6]
    gdf = gdf.merge(panel.to_pandas(), on="codmun_6", how="left")
    log.info("muni gdf: %d rows  com divergence_z não-NA: %d",
             len(gdf), gdf["divergence_z"].notna().sum())

    states = gpd.read_file(ST_GPKG)

    # ---- figura headline: mapa de divergência -------------------
    fig, ax = plt.subplots(1, 1, figsize=(9, 8.5))
    vmax = float(np.percentile(np.abs(panel["divergence_z"].to_numpy()), 95))
    gdf.plot(
        column="divergence_z",
        cmap="RdBu_r",
        vmin=-vmax,
        vmax=vmax,
        legend=True,
        legend_kwds={"label": "Network − Geographic isolation (z)",
                     "shrink": 0.6, "orientation": "vertical"},
        missing_kwds={"color": "0.92", "edgecolor": "0.85", "linewidth": 0.05,
                      "label": "no data"},
        edgecolor="none",
        linewidth=0,
        ax=ax,
    )
    states.boundary.plot(ax=ax, color="black", linewidth=0.4)
    ax.set_axis_off()
    ax.set_title(
        "Network-revealed vs geographic access to high-complexity hospitals\n"
        "Red: embedding-isolation > km-isolation (referral cruza barreira)\n"
        "Blue: embedding-isolation < km-isolation (referral mais curto que mapa)",
        fontsize=10, loc="left",
    )
    fig.savefig(FIG / "fig_map_divergence.pdf")
    fig.savefig(FIG / "fig_map_divergence.png", dpi=200)
    plt.close(fig)
    log.info("wrote %s", FIG / "fig_map_divergence.pdf")

    # ---- mapas auxiliares: iso_km e iso_emb ---------------------
    fig, axes = plt.subplots(1, 2, figsize=(14, 7))
    for ax, col, title, cmap in [
        (axes[0], "iso_km_hosp", "Geographic isolation\n(km to nearest high-complex hospital)", "viridis"),
        (axes[1], "iso_emb_hosp", "Embedding isolation\n(1 − cos to nearest high-complex hospital)", "magma"),
    ]:
        vals = panel[col].to_numpy()
        vmax = float(np.percentile(vals, 95))
        gdf.plot(
            column=col,
            cmap=cmap,
            vmin=0,
            vmax=vmax,
            legend=True,
            legend_kwds={"shrink": 0.6, "orientation": "vertical"},
            missing_kwds={"color": "0.92", "linewidth": 0.05},
            edgecolor="none",
            linewidth=0,
            ax=ax,
        )
        states.boundary.plot(ax=ax, color="black", linewidth=0.4)
        ax.set_axis_off()
        ax.set_title(title, fontsize=10, loc="left")
    fig.tight_layout()
    fig.savefig(FIG / "fig_map_iso_km_vs_emb.pdf")
    fig.savefig(FIG / "fig_map_iso_km_vs_emb.png", dpi=200)
    plt.close(fig)
    log.info("wrote %s", FIG / "fig_map_iso_km_vs_emb.pdf")

    # ---- tabelas resumo: top-15 divergence positiva e negativa --
    pn = panel.with_columns(
        pl.col("codmun_6").cast(pl.Utf8)
    ).join(
        pl.read_parquet(CENT).select([
            pl.col("cod_mun_6").alias("codmun_6"),
            "nome_mun",
        ]),
        on="codmun_6", how="left",
    )
    log.info("=== top-15 divergence POSITIVA (embedding > km, nearest é inadequado) ===")
    for r in pn.sort("divergence_z", descending=True).head(15).iter_rows(named=True):
        log.info("  %s %s-%s  km=%.0f  emb=%.3f  div_z=%+.2f",
                 r["codmun_6"], r["nome_mun"], r["uf"],
                 r["iso_km_hosp"], r["iso_emb_hosp"], r["divergence_z"])

    log.info("=== top-15 divergence NEGATIVA (embedding < km, fluxo cruza barreira) ===")
    for r in pn.sort("divergence_z", descending=False).head(15).iter_rows(named=True):
        log.info("  %s %s-%s  km=%.0f  emb=%.3f  div_z=%+.2f",
                 r["codmun_6"], r["nome_mun"], r["uf"],
                 r["iso_km_hosp"], r["iso_emb_hosp"], r["divergence_z"])

    log.info("==== done ==== elapsed=%.1fs RSS=%.2fGB",
             time.perf_counter() - t0,
             psutil.Process().memory_info().rss / 1e9)


if __name__ == "__main__":
    main()
