"""
11_fig2_scatter_flow_distance.py

Figure 2 (Secao 6.1) - scatter F1 (burden efetivo de fluxo) vs distancia ao
hospital mais proximo, por municipio, colorido por quadrante. Mostra quanto um
conceito e (ir)redundante com o outro: correlacao moderada (r=0,55, R2=0,30),
massa acima da diagonal y=x (pacientes viajam alem do hospital mais proximo), e
os dois off-diagonais que o relatorio persegue.

Linhas de corte = quartil superior de cada medida (definicao de deserto).
Tendencia = mediana de F1 por bin de distancia (robusta, sem dependencia extra).

Entrada: master_muni_panel.parquet. Saida: 04_figures/fig2_scatter.{pdf,png}
"""

from __future__ import annotations

import argparse
import logging
import sys
import time
from pathlib import Path

import duckdb
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
PROC19 = ROOT / "02_data" / "processed"
FIG_DIR = ROOT / "04_figures"
LOG_DIR = ROOT / "04_logs"
FIG_DIR.mkdir(parents=True, exist_ok=True)
LOG_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s",
    handlers=[logging.FileHandler(LOG_DIR / "11_fig2_scatter.log", mode="w"),
              logging.StreamHandler(sys.stdout)])
log = logging.getLogger("fig2")

COLORS = {"flow_only": "#D55E00", "distance_only": "#0072B2",
          "both": "#5D3A9B", "neither": "#9E9E9E"}
LABELS = {"flow_only": "Perto, deserto em fluxo", "distance_only": "Longe, conectado",
          "both": "Deserto pleno", "neither": "Sem deserto"}
XMAX, YMAX = 200.0, 300.0


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()
    out_pdf = FIG_DIR / "fig2_scatter.pdf"
    if out_pdf.exists() and not args.force:
        log.info("output ja existe - use --force"); return

    t0 = time.perf_counter()
    panel = PROC19 / "master_muni_panel.parquet"
    df = duckdb.sql(
        f"SELECT nome_mun, uf, iso_km, f1_km, quadrant FROM '{panel.as_posix()}'"
    ).df()
    dist_cut = float(np.quantile(df.iso_km, 0.75))
    flow_cut = float(np.quantile(df.f1_km, 0.75))
    r = float(np.corrcoef(df.iso_km, df.f1_km)[0, 1])
    n_beyond = int(((df.iso_km > XMAX) | (df.f1_km > YMAX)).sum())
    log.info("dist_cut=%.1f flow_cut=%.1f r=%.3f beyond_axes=%d", dist_cut, flow_cut, r, n_beyond)

    plt.rcParams.update({"font.family": "serif", "font.size": 9,
                         "pdf.fonttype": 42, "savefig.bbox": "tight"})
    fig, ax = plt.subplots(figsize=(6.4, 6.0))

    for q in ["neither", "both", "distance_only", "flow_only"]:
        sub = df[df.quadrant == q]
        ax.scatter(sub.iso_km, sub.f1_km, s=7, alpha=0.35, linewidths=0,
                   color=COLORS[q], label=LABELS[q], rasterized=True)

    # referencia y=x: F1 = distancia ao mais proximo
    lim = max(XMAX, YMAX)
    ax.plot([0, lim], [0, lim], ls="--", lw=0.8, color="#444444", zorder=1)
    ax.text(150, 158, "F1 = distância ao mais próximo", fontsize=7,
            color="#444444", rotation=33, ha="center", va="bottom")

    # cortes de deserto (quartil superior)
    ax.axvline(dist_cut, ls=":", lw=0.8, color="#777777")
    ax.axhline(flow_cut, ls=":", lw=0.8, color="#777777")

    # tendencia: mediana de F1 por bin de distancia
    bins = np.arange(0, XMAX + 1, 10)
    cx, cy = [], []
    for lo, hi in zip(bins[:-1], bins[1:]):
        m = (df.iso_km >= lo) & (df.iso_km < hi)
        if m.sum() >= 20:
            cx.append((lo + hi) / 2); cy.append(np.median(df.f1_km[m]))
    ax.plot(cx, cy, color="black", lw=1.8, zorder=5, label="Mediana de F1 por faixa")

    ax.set_xlim(0, XMAX); ax.set_ylim(0, YMAX)
    ax.set_xlabel("Distância ao hospital ativo mais próximo (km)")
    ax.set_ylabel("Burden efetivo de fluxo F1 (km)")
    ax.text(0.97, 0.05, f"r = {r:.2f}   (R² = {r**2:.2f})\nN = {len(df):,}".replace(",", "."),
            transform=ax.transAxes, ha="right", va="bottom", fontsize=8.5,
            bbox=dict(boxstyle="round,pad=0.3", fc="white", ec="#cccccc", lw=0.5))
    leg = ax.legend(loc="upper left", frameon=False, fontsize=7.8, markerscale=2.2,
                    handletextpad=0.3)

    # ancoras canonicas
    anchors = {"Soledade": "Soledade (PB)", "Fonte Boa": "Fonte Boa (AM)",
               "Sobral": "Sobral (CE)"}
    for nm, lab in anchors.items():
        row = df[(df.nome_mun == nm)].sort_values("f1_km", ascending=False)
        if len(row):
            x, y = row.iloc[0].iso_km, row.iloc[0].f1_km
            x, y = min(x, XMAX - 3), min(y, YMAX - 5)
            ax.annotate(lab, (x, y), fontsize=7, color="#222222",
                        xytext=(6, 6), textcoords="offset points")
            ax.scatter([x], [y], s=22, facecolor="none", edgecolor="black", lw=0.8, zorder=6)

    if n_beyond:
        ax.text(0.5, -0.13, f"{n_beyond} municípios além dos eixos (clipados).",
                transform=ax.transAxes, ha="center", fontsize=7, color="#666666")

    for ext in ("pdf", "png"):
        fig.savefig(FIG_DIR / f"fig2_scatter.{ext}", dpi=300)
    plt.close(fig)
    log.info("salvo fig2_scatter | %.1fs", time.perf_counter() - t0)


if __name__ == "__main__":
    main()
