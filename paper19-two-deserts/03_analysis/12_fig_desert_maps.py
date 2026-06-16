"""
12_fig_desert_maps.py

Figuras 3 e 4 (Secoes 4 e 5): os dois desertos isolados, como choropleths.
  fig3_distance_map.{pdf,png}  -> distancia ao hospital ativo mais proximo (km)
  fig4_flow_map.{pdf,png}      -> burden efetivo de fluxo F1 (km)

Ambos na MESMA escala de km e mesmos cortes, para comparacao direta: o mapa de
fluxo fica visivelmente mais "quente" (burden maior em quase todo lugar) e com
distribuicao espacial diferente. Paleta sequencial cividis (colorblind-safe).

Entrada: master_muni_panel.parquet + malha IBGE 2010.
"""

from __future__ import annotations

import argparse
import logging
import sys
import time
from pathlib import Path

import duckdb
import geopandas as gpd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import BoundaryNorm
from matplotlib.cm import ScalarMappable
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
PAPER18 = ROOT.parent / "paper18-hospital-deserts"
RAW_IBGE = PAPER18 / "02_data" / "raw" / "ibge"
PROC19 = ROOT / "02_data" / "processed"
FIG_DIR = ROOT / "04_figures"
LOG_DIR = ROOT / "04_logs"
FIG_DIR.mkdir(parents=True, exist_ok=True)
LOG_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s",
    handlers=[logging.FileHandler(LOG_DIR / "12_fig_desert_maps.log", mode="w"),
              logging.StreamHandler(sys.stdout)])
log = logging.getLogger("maps")

BREAKS = [0, 10, 25, 50, 100, 200, 700]  # 700 = teto finito (max F1 ~619)
BREAK_LABELS = ["0–10", "10–25", "25–50", "50–100", "100–200", "≥200"]


def render(gdf, states, col, title, out_stem):
    cmap = plt.get_cmap("cividis", len(BREAKS) - 1)
    norm = BoundaryNorm(BREAKS, cmap.N)
    plt.rcParams.update({"font.family": "serif", "font.size": 9,
                         "pdf.fonttype": 42, "savefig.bbox": "tight"})
    fig, ax = plt.subplots(figsize=(7.0, 7.8))
    fig.subplots_adjust(left=0.02, right=0.98, top=0.93, bottom=0.06)
    gdf.plot(ax=ax, column=col, cmap=cmap, norm=norm, linewidth=0.05,
             edgecolor="white", missing_kwds={"color": "#FBFBFB"})
    states.boundary.plot(ax=ax, linewidth=0.45, edgecolor="#5A5A5A")
    ax.set_axis_off(); ax.set_aspect("equal")
    ax.set_title(title, fontsize=13.5, fontweight="bold", pad=10)

    sm = ScalarMappable(cmap=cmap, norm=norm)
    cbar = fig.colorbar(sm, ax=ax, orientation="horizontal", fraction=0.04,
                        pad=0.02, ticks=[0, 10, 25, 50, 100, 200])
    cbar.ax.set_xticklabels(["0", "10", "25", "50", "100", "200"])
    cbar.set_label("quilômetros", fontsize=9)
    cbar.ax.tick_params(labelsize=8)

    for ext in ("pdf", "png"):
        fig.savefig(FIG_DIR / f"{out_stem}.{ext}", dpi=300)
    plt.close(fig)
    log.info("salvo %s", out_stem)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--simplify", type=float, default=500.0)
    args = ap.parse_args()
    if (FIG_DIR / "fig3_distance_map.pdf").exists() and not args.force:
        log.info("outputs ja existem - use --force"); return

    t0 = time.perf_counter()
    panel = PROC19 / "master_muni_panel.parquet"
    munis = gpd.read_file(RAW_IBGE / "municipios_2010.gpkg")
    states = gpd.read_file(RAW_IBGE / "estados_2010.gpkg")
    munis["codmun_6"] = munis["code_muni"].astype("int64").astype(str).str[:6]
    vals = duckdb.sql(
        f"SELECT codmun_6, iso_km, f1_km FROM '{panel.as_posix()}'").df()
    gdf = munis.merge(vals, on="codmun_6", how="left").to_crs(5880)
    states = states.to_crs(5880)
    gdf["geometry"] = gdf.simplify(args.simplify)
    states["geometry"] = states.simplify(args.simplify)
    log.info("municipios=%d com dado=%d", len(gdf), int(gdf.iso_km.notna().sum()))

    render(gdf, states, "iso_km",
           "Deserto de distância: km ao hospital mais próximo",
           "fig3_distance_map")
    render(gdf, states, "f1_km",
           "Deserto de fluxo: burden efetivo de viagem (F1)",
           "fig4_flow_map")
    log.info("==== fim %.1fs ====", time.perf_counter() - t0)


if __name__ == "__main__":
    main()
