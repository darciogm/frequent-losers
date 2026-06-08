"""
06_train_node2vec.py

Treina embeddings node2vec sobre o grafo bipartido paciente-hospital pooled
2015-2022. Cada nó (município OU hospital) ganha um vetor 128-dim.

Stack: pecanpy (SparseOTF, numba JIT) + scipy.sparse. O pacote eliorc/node2vec
foi descartado: materializava walks em listas Python e estourou OOM (RSS 6 GiB
matando o processo às 07:32 em 2026-04-28). Pecanpy roda os random walks em
numba com adjacência CSR e mantém RSS em ~2-3 GiB para grafos deste porte.

Input:
- 02_data/intermediate/bipartite_edges_pooled.parquet (~496k arestas)

Output:
- 02_data/intermediate/embeddings_node2vec.parquet
  Schema: node_id (str: raw cod_mun_6 ou CNES), node_type ('M' ou 'H'),
          dim_0..dim_127 (float32)

Hyperparams baseline:
  dim=128, walk_length=20, num_walks=10, p=1, q=1, window=10, epochs=5, sg=1.

Random walks ponderadas pelo peso da aresta (n_internacoes).
12 threads (cap global DarcioWork).
"""

from __future__ import annotations

import gc
import argparse
import logging
import os
import sys
import tempfile
import time
from pathlib import Path

import numpy as np
import polars as pl
import psutil
from pecanpy import pecanpy as pn

ROOT = Path(__file__).resolve().parents[1]
INTER = ROOT / "02_data" / "intermediate"
LOG = ROOT / "04_logs"
LOG.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "06_train_node2vec.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("n2v")

EDGES = INTER / "bipartite_edges_pooled.parquet"
OUT = INTER / "embeddings_node2vec.parquet"

DIM = 128
WALK_LENGTH = 20
NUM_WALKS = 10
P = 1.0
Q = 1.0
WINDOW = 10
EPOCHS = 5
WORKERS = 12
SEED = 42

# numba/MKL respeitam env, então setamos antes de qualquer numpy heavy op
os.environ["OMP_NUM_THREADS"] = str(WORKERS)
os.environ["OPENBLAS_NUM_THREADS"] = str(WORKERS)
os.environ["MKL_NUM_THREADS"] = str(WORKERS)
os.environ["NUMBA_NUM_THREADS"] = str(WORKERS)


def rss_gb() -> float:
    return psutil.Process().memory_info().rss / 1e9


def stage(label: str, t_prev: float) -> float:
    now = time.perf_counter()
    log.info("  [%s] %.1fs cumul=%.1fs RSS=%.2fGB",
             label, now - t_prev, now - T0, rss_gb())
    return now


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=SEED)
    ap.add_argument("--output", type=str, default=str(OUT))
    args = ap.parse_args()

    global T0
    T0 = time.perf_counter()
    vm = psutil.virtual_memory()
    log.info("==== begin node2vec (pecanpy SparseOTF) ====")
    log.info("host=%s ram_total=%.1fGB ram_avail=%.1fGB workers=%d seed=%d",
             os.uname().nodename, vm.total / 1e9, vm.available / 1e9, WORKERS, args.seed)
    log.info("hyperparams: dim=%d walk_len=%d num_walks=%d p=%.2f q=%.2f window=%d epochs=%d",
             DIM, WALK_LENGTH, NUM_WALKS, P, Q, WINDOW, EPOCHS)

    t = T0

    # ---- carregar arestas ---------------------------------------------
    df = pl.read_parquet(EDGES)
    log.info("edges loaded: %d rows", len(df))
    t = stage("load_edges", t)

    # ---- escrever edge list TSV (formato esperado por pecanpy.read_edg)
    # bipartido não-direcional: src=M:codmun_6, dst=H:CNES, weight=n_internacoes
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".edg", delete=False, dir="/tmp"
    ) as f:
        edge_path = f.name
        # vetorizado: monta as strings via polars e despeja
        out = df.select(
            (pl.lit("M:") + pl.col("codmun_6")).alias("src"),
            (pl.lit("H:") + pl.col("CNES")).alias("dst"),
            pl.col("n_internacoes").cast(pl.Float32).alias("w"),
        )
        for s, d_, w in out.iter_rows():
            f.write(f"{s}\t{d_}\t{w}\n")
    log.info("wrote edge list: %s (%.1fMB)",
             edge_path, os.path.getsize(edge_path) / 1e6)
    del df, out
    gc.collect()
    t = stage("write_edglist", t)

    # ---- pecanpy SparseOTF -------------------------------------------
    # SparseOTF computa probs de transição on-the-fly, RSS linear em |E|.
    # read_edg aceita TSV ponderado e indexa nós conforme aparecem.
    g = pn.SparseOTF(p=P, q=Q, workers=WORKERS, verbose=False, random_state=args.seed)
    g.read_edg(edge_path, weighted=True, directed=False, delimiter="\t")
    node_ids = list(g.nodes)
    n_nodes = len(node_ids)
    n_M = sum(1 for n in node_ids if n.startswith("M:"))
    n_H = n_nodes - n_M
    log.info("pecanpy graph: %d nodes (M=%d H=%d), %d edges",
             n_nodes, n_M, n_H, g.num_edges)
    os.unlink(edge_path)
    t = stage("pecanpy_read_edg", t)

    # ---- preprocess transition probs (setup numba) --------------------
    g.preprocess_transition_probs()
    t = stage("preprocess_probs", t)

    # ---- treinar embeddings (random walks + Word2Vec skipgram) -------
    # embed() executa simulate_walks internamente em numba paralelo + gensim sg
    emb = g.embed(
        dim=DIM,
        num_walks=NUM_WALKS,
        walk_length=WALK_LENGTH,
        window_size=WINDOW,
        epochs=EPOCHS,
        verbose=False,
    )
    emb = np.asarray(emb, dtype=np.float32)
    log.info("embeddings: shape=%s dtype=%s", emb.shape, emb.dtype)
    t = stage("embed", t)

    # ---- exportar -----------------------------------------------------
    types = ["M" if n.startswith("M:") else "H" for n in node_ids]
    raw_ids = [n[2:] for n in node_ids]
    cols_out = {"node_id": raw_ids, "node_type": types}
    for d in range(DIM):
        cols_out[f"dim_{d}"] = emb[:, d]
    out_df = pl.DataFrame(cols_out)
    out_path = Path(args.output)
    out_df.write_parquet(out_path, compression="snappy")
    log.info("wrote %s (rows=%d, cols=%d, file=%.1fMB)",
             out_path, len(out_df), len(out_df.columns), out_path.stat().st_size / 1e6)
    t = stage("write_parquet", t)

    # ---- sanity: vizinhos top-10 de São Paulo município --------------
    id_to_idx = {n: i for i, n in enumerate(node_ids)}
    sp_idx = id_to_idx.get("M:355030")
    if sp_idx is not None:
        sims = emb @ emb[sp_idx]
        norms = np.linalg.norm(emb, axis=1) * np.linalg.norm(emb[sp_idx])
        sims = sims / np.where(norms > 0, norms, 1)
        top = np.argsort(-sims)[1:11]
        log.info("=== sanity: top-10 vizinhos cosine de M:355030 (São Paulo-SP) ===")
        for i in top:
            log.info("  %s (%s) : %.3f", node_ids[i], types[i], sims[i])
    else:
        log.warning("M:355030 (São Paulo) não está no vocabulário")

    log.info("==== done ==== elapsed=%.1fs (%.1fmin) peak_RSS=%.2fGB",
             time.perf_counter() - T0,
             (time.perf_counter() - T0) / 60,
             rss_gb())


if __name__ == "__main__":
    main()
