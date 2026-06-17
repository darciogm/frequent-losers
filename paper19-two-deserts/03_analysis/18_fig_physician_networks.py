"""
18_fig_physician_networks.py

Figura de 2 paineis para a Secao de mobilidade medica:
  (A) mapa do saldo migratorio liquido de medicos por 1.000 (dreno): vermelho =
      municipio perde medicos, azul = ganha. Para comparar com a geografia do
      deserto de fluxo (Fig 1).
  (B) scatter aresta-a-aresta: fluxo de PACIENTES vs migracao de MEDICOS sobre
      os pares origem->destino comuns (log-log). Mostra a correlacao (r=0,44) e
      a divergencia: arestas saindo de desertos de fluxo destacadas.

Saida: 04_figures/fig5_physician_networks.{pdf,png}
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
from matplotlib.colors import TwoSlopeNorm
from matplotlib.cm import ScalarMappable
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
PAPER18 = ROOT.parent / "paper18-hospital-deserts"
INTER18 = PAPER18 / "02_data" / "intermediate"
RAW_IBGE = PAPER18 / "02_data" / "raw" / "ibge"
PROC19 = ROOT / "02_data" / "processed"
FIG_DIR = ROOT / "04_figures"
LOG_DIR = ROOT / "04_logs"
FIG_DIR.mkdir(parents=True, exist_ok=True)
LOG_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s",
    handlers=[logging.FileHandler(LOG_DIR / "18_fig_physician_networks.log", mode="w"),
              logging.StreamHandler(sys.stdout)])
log = logging.getLogger("fig5")

CAP = 200.0  # teto do saldo/1000 para a escala divergente


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--simplify", type=float, default=500.0)
    args = ap.parse_args()
    out = FIG_DIR / "fig5_physician_networks.pdf"
    if out.exists() and not args.force:
        log.info("output ja existe - use --force"); return

    t0 = time.perf_counter()
    con = duckdb.connect()
    con.execute("PRAGMA threads=12")
    con.execute("PRAGMA memory_limit='14GB'")
    master = (PROC19 / "master_muni_panel.parquet").as_posix()
    mobp = (PROC19 / "physician_mobility_panel.parquet").as_posix()
    mig = (PROC19 / "physician_migration_edges.parquet").as_posix()
    edges = (INTER18 / "bipartite_edges.parquet").as_posix()
    hm = (INTER18 / "hospital_master.parquet").as_posix()

    plt.rcParams.update({"font.family": "serif", "font.size": 9,
                         "pdf.fonttype": 42, "savefig.bbox": "tight"})
    fig, (axA, axB) = plt.subplots(1, 2, figsize=(11.5, 5.8),
                                   gridspec_kw={"width_ratios": [1.05, 1]})

    # ---------- Painel A: mapa do saldo migratorio medico ----------
    log.info("[A] mapa do saldo migratorio liquido...")
    net = con.sql(f"""
        SELECT codmun_6, 1000.0*SUM(net)/NULLIF(SUM(n_stock),0) AS net_rate
        FROM '{mobp}' GROUP BY codmun_6
    """).df()
    munis = gpd.read_file(RAW_IBGE / "municipios_2010.gpkg")
    states = gpd.read_file(RAW_IBGE / "estados_2010.gpkg")
    munis["codmun_6"] = munis["code_muni"].astype("int64").astype(str).str[:6]
    g = munis.merge(net, on="codmun_6", how="left").to_crs(5880)
    states = states.to_crs(5880)
    g["geometry"] = g.simplify(args.simplify)
    states["geometry"] = states.simplify(args.simplify)
    norm = TwoSlopeNorm(vmin=-CAP, vcenter=0, vmax=CAP)
    g.plot(ax=axA, column="net_rate", cmap="RdBu", norm=norm,
           linewidth=0.05, edgecolor="white",
           missing_kwds={"color": "#EFEFEF"})
    states.boundary.plot(ax=axA, linewidth=0.4, edgecolor="#555555")
    axA.set_axis_off(); axA.set_aspect("equal")
    axA.set_title("(A) Saldo migratório médico líquido", fontsize=11, fontweight="bold")
    sm = ScalarMappable(cmap="RdBu", norm=norm)
    cb = fig.colorbar(sm, ax=axA, orientation="horizontal", fraction=0.045, pad=0.02,
                      ticks=[-200, -100, 0, 100, 200])
    cb.set_label("entradas − saídas por 1.000 médicos", fontsize=8.5)
    cb.ax.tick_params(labelsize=8)
    cb.ax.set_xticklabels(["−200", "−100", "0", "+100", "+200"])

    # ---------- Painel B: scatter fluxo pacientes vs migracao medicos ----------
    log.info("[B] scatter rede paciente x rede medico...")
    df = con.sql(f"""
        WITH pat AS (
            SELECT e.codmun_6 AS origin, h.codmun_6_modal AS dest, SUM(e.n_internacoes) n_pat
            FROM '{edges}' e JOIN '{hm}' h ON e.CNES=h.CNES
            WHERE e.year BETWEEN 2015 AND 2022 AND e.codmun_6 <> h.codmun_6_modal
            GROUP BY 1,2
        ),
        doc AS (SELECT codmun_origin origin, codmun_dest dest, n_movers n_doc
                FROM '{mig}' WHERE codmun_origin <> codmun_dest)
        SELECT p.n_pat, d.n_doc,
               (m.quadrant='flow_only') AS from_flowdesert
        FROM pat p JOIN doc d USING (origin, dest)
        LEFT JOIN '{master}' m ON m.codmun_6 = p.origin
    """).df()
    other = df[~df.from_flowdesert.fillna(False)]
    fd = df[df.from_flowdesert.fillna(False)]
    axB.scatter(other.n_pat, other.n_doc, s=6, alpha=0.18, linewidths=0,
                color="#9E9E9E", label="outras origens", rasterized=True)
    axB.scatter(fd.n_pat, fd.n_doc, s=9, alpha=0.5, linewidths=0,
                color="#D55E00", label="origem = deserto de fluxo", rasterized=True)
    axB.set_xscale("log"); axB.set_yscale("log")
    axB.set_xlabel("Fluxo de pacientes na aresta (internações)")
    axB.set_ylabel("Migração de médicos na aresta (nº)")
    axB.set_title("(B) As duas redes, aresta a aresta", fontsize=11, fontweight="bold")
    r = float(np.corrcoef(np.log(df.n_pat), np.log(df.n_doc))[0, 1])
    axB.text(0.04, 0.95, f"r (log) = {r:.2f}\n{len(df):,} arestas comuns".replace(",", "."),
             transform=axB.transAxes, va="top", fontsize=9,
             bbox=dict(boxstyle="round,pad=0.3", fc="white", ec="#cccccc", lw=0.5))
    axB.legend(loc="lower right", frameon=False, fontsize=8, markerscale=2)

    for ext in ("pdf", "png"):
        fig.savefig(FIG_DIR / f"fig5_physician_networks.{ext}", dpi=300)
    plt.close(fig)
    log.info("salvo fig5_physician_networks | %.1fs", time.perf_counter() - t0)


if __name__ == "__main__":
    main()
