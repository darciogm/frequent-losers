"""
13_make_regional_map.py

Gera mapa do Brasil colorido pelas 5 macrorregiões IBGE (N/NE/SE/S/CO),
com sobreposição dos contornos estaduais. Serve de orientação visual
para o leitor quando discutimos os padrões regionais da divergência.

Output: 04_figures/fig_regional_map.pdf+png
"""

from __future__ import annotations
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Patch
import geopandas as gpd

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "02_data" / "raw" / "ibge"
FIG = ROOT / "04_figures"

REG = {
    "AC":"N","AM":"N","AP":"N","PA":"N","RO":"N","RR":"N","TO":"N",
    "AL":"NE","BA":"NE","CE":"NE","MA":"NE","PB":"NE","PE":"NE","PI":"NE","RN":"NE","SE":"NE",
    "ES":"SE","MG":"SE","RJ":"SE","SP":"SE",
    "PR":"S","RS":"S","SC":"S",
    "DF":"CO","GO":"CO","MS":"CO","MT":"CO",
}

# Okabe-Ito-inspired qualitative, colorblind-safe
COLORS = {
    "N":  "#56B4E9",
    "NE": "#E69F00",
    "SE": "#009E73",
    "S":  "#CC79A7",
    "CO": "#F0E442",
}

LABEL = {"N":"North","NE":"Northeast","SE":"Southeast","S":"South","CO":"Center-West"}

plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "font.size": 9,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "axes.spines.left": False,
    "axes.spines.bottom": False,
    "savefig.dpi": 300,
    "savefig.bbox": "tight",
})


def main():
    states = gpd.read_file(RAW / "estados_2010.gpkg")
    # detectar coluna UF (varia)
    uf_col = next(c for c in ["abbrev_state", "abbrev_st", "sigla", "UF"] if c in states.columns)
    states["regiao"] = states[uf_col].map(REG)
    states["color"] = states["regiao"].map(COLORS)

    munis = gpd.read_file(RAW / "municipios_2010.gpkg")

    fig, ax = plt.subplots(1, 1, figsize=(8, 7.5))
    munis.plot(ax=ax, color="0.96", edgecolor="0.85", linewidth=0.05)
    states.plot(ax=ax, color=states["color"], alpha=0.55,
                edgecolor="black", linewidth=0.6)
    ax.set_axis_off()
    ax.set_title("IBGE macro-regions of Brazil",
                 fontsize=11, loc="left")

    # legend
    handles = [Patch(facecolor=COLORS[r], edgecolor="black", linewidth=0.6,
                     label=f"{LABEL[r]} ({r})") for r in ["N","NE","SE","S","CO"]]
    ax.legend(handles=handles, loc="lower left", frameon=False, fontsize=9,
              title=None)

    fig.savefig(FIG / "fig_regional_map.pdf")
    fig.savefig(FIG / "fig_regional_map.png", dpi=200)
    plt.close(fig)
    print(f"wrote {FIG / 'fig_regional_map.pdf'}")


if __name__ == "__main__":
    main()
