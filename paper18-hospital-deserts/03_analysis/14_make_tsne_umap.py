"""
14_make_tsne_umap.py

Projeção 2D do embedding M-M (06b) via t-SNE e UMAP, colorida por
macrorregião IBGE. Demonstra visualmente que o embedding recupera a
geografia brasileira a partir SÓ de fluxos paciente-hospital — sem
ver coordenadas.

Output: 04_figures/fig_tsne_umap.pdf+png
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
from openTSNE import TSNE
import umap

ROOT = Path(__file__).resolve().parents[1]
INTER = ROOT / "02_data" / "intermediate"
LOG = ROOT / "04_logs"
FIG = ROOT / "04_figures"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "14_tsne_umap.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("tsne")

REG = {
    "AC":"N","AM":"N","AP":"N","PA":"N","RO":"N","RR":"N","TO":"N",
    "AL":"NE","BA":"NE","CE":"NE","MA":"NE","PB":"NE","PE":"NE","PI":"NE","RN":"NE","SE":"NE",
    "ES":"SE","MG":"SE","RJ":"SE","SP":"SE",
    "PR":"S","RS":"S","SC":"S",
    "DF":"CO","GO":"CO","MS":"CO","MT":"CO",
}

COLORS = {
    "N":  "#56B4E9",
    "NE": "#E69F00",
    "SE": "#009E73",
    "S":  "#CC79A7",
    "CO": "#F0E442",
}

LABEL = {"N":"North","NE":"Northeast","SE":"Southeast","S":"South","CO":"Center-West"}

# âncoras com nome curto para anotar nos plots
ANCHORS = {
    "355030": "São Paulo",
    "330455": "Rio de Janeiro",
    "310620": "Belo Horizonte",
    "230440": "Fortaleza",
    "261160": "Recife",
    "292740": "Salvador",
    "530010": "Brasília",
    "130260": "Manaus",
    "150140": "Belém",
    "410690": "Curitiba",
    "431490": "Porto Alegre",
    "421660": "Florianópolis",
    "140010": "Boa Vista",
    "172100": "Palmas",
    "120040": "Rio Branco",
}

SEED = 42

plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "font.size": 9,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "savefig.dpi": 300,
    "savefig.bbox": "tight",
})


def main():
    t0 = time.perf_counter()
    log.info("==== begin t-SNE / UMAP ====")
    emb_df = pl.read_parquet(INTER / "embeddings_munmun_proj.parquet")
    cent = pl.read_parquet(INTER / "municipios_centroids.parquet").select(
        pl.col("cod_mun_6").alias("codmun_6"), "uf", "nome_mun"
    )
    df = emb_df.join(cent, left_on="cod_mun_6", right_on="codmun_6", how="inner")
    df = df.with_columns(
        regiao=pl.col("uf").replace_strict(REG, default="?")
    )
    log.info("muns matched: %d", len(df))

    dim_cols = [c for c in emb_df.columns if c.startswith("dim_")]
    X = df.select(dim_cols).to_numpy().astype(np.float32)
    munis = df["cod_mun_6"].to_list()
    regs = df["regiao"].to_list()
    log.info("X shape=%s", X.shape)

    # ---- t-SNE -----------------------------------------------------
    t = time.perf_counter()
    tsne = TSNE(perplexity=30, metric="cosine", n_iter=750, n_jobs=12,
                random_state=SEED, initialization="pca", verbose=False)
    Y_tsne = tsne.fit(X)
    log.info("t-SNE: %.1fs  shape=%s", time.perf_counter() - t, Y_tsne.shape)

    # ---- UMAP ------------------------------------------------------
    t = time.perf_counter()
    reducer = umap.UMAP(n_neighbors=30, min_dist=0.1, metric="cosine",
                        random_state=SEED, n_jobs=12)
    Y_umap = reducer.fit_transform(X)
    log.info("UMAP: %.1fs  shape=%s", time.perf_counter() - t, Y_umap.shape)

    # ---- plot ------------------------------------------------------
    fig, axes = plt.subplots(1, 2, figsize=(13, 6.2))

    for ax, Y, title in [(axes[0], Y_tsne, "(a) t-SNE"),
                         (axes[1], Y_umap, "(b) UMAP")]:
        for r in ["N","NE","SE","S","CO"]:
            mask = np.array([reg == r for reg in regs])
            ax.scatter(Y[mask, 0], Y[mask, 1], s=4, c=COLORS[r], alpha=0.7,
                       edgecolors="none", label=f"{LABEL[r]} ({mask.sum()})")
        ax.set_xticks([])
        ax.set_yticks([])
        ax.set_title(title, fontsize=10.5, loc="left")

        # anotar âncoras
        idx_map = {m: i for i, m in enumerate(munis)}
        for code, name in ANCHORS.items():
            i = idx_map.get(code)
            if i is None:
                continue
            ax.scatter(Y[i, 0], Y[i, 1], s=22, c="black",
                       edgecolors="white", linewidth=0.6, zorder=10)
            ax.annotate(name, (Y[i, 0], Y[i, 1]),
                        xytext=(5, 5), textcoords="offset points",
                        fontsize=7.5, color="black", zorder=11)

    axes[0].legend(loc="upper left", frameon=False, fontsize=8,
                   markerscale=2.0, title="IBGE region (n)", title_fontsize=8.5)

    fig.suptitle(
        "Two-dimensional projection of the M-M embedding "
        "(node2vec on TF--IDF co-patiency graph), coloured by IBGE macro-region",
        fontsize=10, y=1.01,
    )
    fig.tight_layout()
    fig.savefig(FIG / "fig_tsne_umap.pdf")
    fig.savefig(FIG / "fig_tsne_umap.png", dpi=200)
    plt.close(fig)
    log.info("wrote %s", FIG / "fig_tsne_umap.pdf")

    log.info("==== done ==== elapsed=%.1fs", time.perf_counter() - t0)


if __name__ == "__main__":
    main()
