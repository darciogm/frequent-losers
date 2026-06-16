"""
10_fig1_divergence_map.py

Figure 1 — o mapa da divergencia. Coropletico nacional dos municipios pintados
pelo quadrante distancia x fluxo (Secao 6). O "wow" do relatorio: os dois
off-diagonais (perto-no-mapa-mas-deserto-em-fluxo; longe-no-mapa-mas-conectado)
mostram que deserto de distancia e deserto de fluxo nao sao o mesmo mapa.

Entrada: master_muni_panel.parquet (quadrante por municipio) + malha IBGE 2010.
Saida:   04_figures/fig1_divergence_map.{pdf,png}

Desenho: paleta Okabe-Ito (colorblind-safe), off-diagonais salientes, diagonal
(concordam) em cinza; projecao Brasil Polyconic (EPSG:5880) para areas honestas;
legenda abaixo do mapa com contagem e populacao por quadrante.
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
from matplotlib.patches import Patch

ROOT = Path(__file__).resolve().parents[1]
PAPER18 = ROOT.parent / "paper18-hospital-deserts"
RAW_IBGE = PAPER18 / "02_data" / "raw" / "ibge"
PROC19 = ROOT / "02_data" / "processed"
FIG_DIR = ROOT / "04_figures"
LOG_DIR = ROOT / "04_logs"
FIG_DIR.mkdir(parents=True, exist_ok=True)
LOG_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG_DIR / "10_fig1_divergence_map.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("fig1")

# Okabe-Ito: off-diagonais salientes, concordam em tons neutros
COLORS = {
    "flow_only": "#D55E00",      # vermillion - perto no mapa, deserto em fluxo
    "distance_only": "#0072B2",  # blue - longe no mapa, conectado em fluxo
    "both": "#5D3A9B",           # roxo - deserto pleno (concordam)
    "neither": "#E6E6E6",        # cinza claro - sem deserto (concordam)
}
LABELS = {
    "flow_only": "Perto no mapa, deserto em fluxo",
    "distance_only": "Longe no mapa, conectado em fluxo",
    "both": "Deserto pleno (concordam)",
    "neither": "Sem deserto (concordam)",
}
ORDER = ["flow_only", "distance_only", "both", "neither"]


def _fmt_pop(p: float) -> str:
    s = f"{p / 1e6:.1f} mi" if p >= 1e6 else f"{p / 1e3:.0f} mil"
    return s.replace(".", ",")  # decimal PT


def _fmt_n(n: int) -> str:
    return f"{n:,}".replace(",", ".")  # milhar PT


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--simplify", type=float, default=500.0,
                    help="tolerancia de simplificacao em metros (CRS projetado)")
    args = ap.parse_args()

    out_pdf = FIG_DIR / "fig1_divergence_map.pdf"
    if out_pdf.exists() and not args.force:
        log.info("output ja existe (%s) - use --force", out_pdf.name)
        return

    t0 = time.perf_counter()
    panel = PROC19 / "master_muni_panel.parquet"
    if not panel.exists():
        log.error("falta %s - rode 03_build_master_muni_table.py", panel)
        sys.exit(1)

    plt.rcParams.update({
        "font.family": "serif",
        "font.size": 9,
        "axes.linewidth": 0.4,
        "savefig.bbox": "tight",
        "pdf.fonttype": 42,
    })

    log.info("[1/3] lendo malha IBGE + painel...")
    munis = gpd.read_file(RAW_IBGE / "municipios_2010.gpkg")
    states = gpd.read_file(RAW_IBGE / "estados_2010.gpkg")
    munis["codmun_6"] = munis["code_muni"].astype("int64").astype(str).str[:6]

    quad = duckdb.sql(
        f"SELECT codmun_6, quadrant, COALESCE(pop,0) AS pop "
        f"FROM '{panel.as_posix()}'"
    ).df()

    gdf = munis.merge(quad, on="codmun_6", how="left")
    n_match = int(gdf["quadrant"].notna().sum())
    log.info("    municipios na malha=%d | com quadrante=%d | sem dado=%d",
             len(gdf), n_match, len(gdf) - n_match)

    log.info("[2/3] projecao (EPSG:5880) + simplificacao (%.0fm)...", args.simplify)
    gdf = gdf.to_crs(5880)
    states = states.to_crs(5880)
    gdf["geometry"] = gdf.simplify(args.simplify)
    states["geometry"] = states.simplify(args.simplify)
    gdf["color"] = gdf["quadrant"].map(COLORS).fillna("#FBFBFB")

    stats = (quad.groupby("quadrant")
             .agg(n=("codmun_6", "size"), pop=("pop", "sum")))

    log.info("[3/3] render...")
    fig, ax = plt.subplots(figsize=(7.2, 8.6))
    fig.subplots_adjust(left=0.02, right=0.98, top=0.93, bottom=0.16)
    gdf.plot(ax=ax, color=gdf["color"], linewidth=0.05, edgecolor="white")
    states.boundary.plot(ax=ax, linewidth=0.45, edgecolor="#5A5A5A")
    ax.set_axis_off()
    ax.set_aspect("equal")
    ax.set_title("Dois desertos não são o mesmo mapa",
                 fontsize=14, fontweight="bold", pad=10)

    handles = []
    for q in ORDER:
        n = int(stats.loc[q, "n"]) if q in stats.index else 0
        pop = float(stats.loc[q, "pop"]) if q in stats.index else 0.0
        handles.append(Patch(
            facecolor=COLORS[q], edgecolor="#999999", linewidth=0.3,
            label=f"{LABELS[q]}  ({_fmt_n(n)} mun., {_fmt_pop(pop)} hab.)"))
    leg = fig.legend(
        handles=handles, loc="lower center", bbox_to_anchor=(0.5, 0.055),
        frameon=False, fontsize=8.5, ncol=2, columnspacing=1.4,
        handlelength=1.1, handletextpad=0.5,
        title="Quadrante distância × fluxo, 2015–2022",
        title_fontsize=9)
    leg.get_title().set_fontweight("bold")

    fig.text(
        0.5, 0.018,
        "Leitura: vermelho = hospital próximo no mapa, mas o paciente viaja longe na "
        "prática; azul = longe no mapa, mas atendido perto (a distância superestima o "
        "isolamento).",
        ha="center", fontsize=7.4, color="#333333", wrap=True)

    for ext in ("pdf", "png"):
        out = FIG_DIR / f"fig1_divergence_map.{ext}"
        fig.savefig(out, dpi=300)
        log.info("    salvo %s", out.name)
    plt.close(fig)
    log.info("==== fim em %.1fs ====", time.perf_counter() - t0)


if __name__ == "__main__":
    main()
