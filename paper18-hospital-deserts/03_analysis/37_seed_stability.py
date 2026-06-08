"""
37_seed_stability.py

Apêndice C: estabilidade do node2vec sobre 5 seeds. Rodar treinos
adicionais (seeds 7, 13, 99, 2024) sobre o mesmo grafo M-M de 06b
(seed=42 baseline) e medir:
  - Pearson correlation pair-distance entre cada seed e baseline (5000 pairs)
  - Jaccard top-10 vizinhos para SP (355030) e Manaus (130260)

Output: 04_logs/37_seed_stability.json
"""

from __future__ import annotations

import json
import logging
import os
import sys
import tempfile
import time
from pathlib import Path

import numpy as np
import polars as pl
import scipy.sparse as sp
from pecanpy import pecanpy as pn

ROOT = Path(__file__).resolve().parents[1]
INTER = ROOT / "02_data" / "intermediate"
LOG = ROOT / "04_logs"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "37_seed_stability.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("seed_stab")

EDGES_BIP = INTER / "bipartite_edges_pooled.parquet"
SEEDS = [42, 7, 13, 99, 2024]
DIM = 128
WALK_LEN = 20
NUM_WALKS = 10
WINDOW = 10
EPOCHS = 5
WORKERS = 12
TOPK = 10

os.environ["NUMBA_NUM_THREADS"] = str(WORKERS)


def build_graph_and_embed(seed):
    df = pl.read_parquet(EDGES_BIP)
    munis = sorted(df["codmun_6"].unique().to_list())
    hosps = sorted(df["CNES"].unique().to_list())
    m_idx = {m: i for i, m in enumerate(munis)}
    h_idx = {h: i for i, h in enumerate(hosps)}
    n_M, n_H = len(munis), len(hosps)
    rows = np.fromiter((m_idx[x] for x in df["codmun_6"].to_list()),
                       dtype=np.int32, count=len(df))
    cols = np.fromiter((h_idx[x] for x in df["CNES"].to_list()),
                       dtype=np.int32, count=len(df))
    w = df["n_internacoes"].to_numpy().astype(np.float32)
    A = sp.csr_matrix((w, (rows, cols)), shape=(n_M, n_H), dtype=np.float32)
    rs = np.asarray(A.sum(axis=1)).ravel()
    rs[rs == 0] = 1.0
    A_tf = sp.diags(1.0 / rs) @ A
    df_h = np.asarray((A > 0).sum(axis=0)).ravel().astype(np.float32)
    df_h[df_h == 0] = 1.0
    idf = np.log(n_M / df_h).astype(np.float32)
    A_w = A_tf @ sp.diags(idf)
    A_MM = (A_w @ A_w.T).tocsr()
    A_MM.setdiag(0); A_MM.eliminate_zeros()

    indptr = [0]; indices = []; data = []
    for i in range(n_M):
        row = A_MM.getrow(i)
        if row.nnz == 0:
            indptr.append(indptr[-1]); continue
        ci = row.indices; vi = row.data
        if len(vi) > 30:
            top = np.argpartition(-vi, 30)[:30]
            ci = ci[top]; vi = vi[top]
        indices.extend(ci.tolist()); data.extend(vi.tolist())
        indptr.append(indptr[-1] + len(ci))
    A_top = sp.csr_matrix(
        (np.array(data, dtype=np.float32),
         np.array(indices, dtype=np.int32),
         np.array(indptr, dtype=np.int32)),
        shape=(n_M, n_M))
    A_sym = A_top.maximum(A_top.T).tocsr()

    coo = A_sym.tocoo()
    keep = coo.row < coo.col
    src_idx = coo.row[keep]; dst_idx = coo.col[keep]; w_e = coo.data[keep]
    with tempfile.NamedTemporaryFile(mode="w", suffix=".edg", delete=False, dir="/tmp") as f:
        edge_tsv = f.name
        for i in range(len(w_e)):
            f.write(f"{munis[src_idx[i]]}\t{munis[dst_idx[i]]}\t{w_e[i]}\n")

    g = pn.SparseOTF(p=1.0, q=1.0, workers=WORKERS, verbose=False, random_state=seed)
    g.read_edg(edge_tsv, weighted=True, directed=False, delimiter="\t")
    node_ids = list(g.nodes)
    os.unlink(edge_tsv)
    g.preprocess_transition_probs()
    emb = g.embed(dim=DIM, num_walks=NUM_WALKS, walk_length=WALK_LEN,
                  window_size=WINDOW, epochs=EPOCHS, verbose=False)
    emb = np.asarray(emb, dtype=np.float32)
    return node_ids, emb


def main():
    t0 = time.time()
    log.info("==== begin seed stability ====")

    embeddings = {}
    for seed in SEEDS:
        ts = time.time()
        log.info("training seed=%d ...", seed)
        node_ids, emb = build_graph_and_embed(seed)
        embeddings[seed] = (node_ids, emb)
        log.info("  done seed=%d  shape=%s  %.0fs", seed, emb.shape, time.time() - ts)

    # baseline = seed 42
    base_ids, base_emb = embeddings[42]
    base_idx = {n: i for i, n in enumerate(base_ids)}
    norms = np.linalg.norm(base_emb, axis=1, keepdims=True)
    norms[norms == 0] = 1
    base_n = base_emb / norms

    # 5000 random pairs from baseline ids
    rng = np.random.default_rng(42)
    common_ids = set(base_ids)
    for s in SEEDS[1:]:
        common_ids &= set(embeddings[s][0])
    common = sorted(common_ids)
    log.info("common nodes: %d", len(common))
    common_idx_b = np.array([base_idx[n] for n in common])
    sample = rng.choice(len(common), size=5000, replace=False)
    a = sample[:2500]; b = sample[2500:]
    pa = common_idx_b[a]; pb = common_idx_b[b]
    base_d = 1 - (base_n[pa] * base_n[pb]).sum(axis=1)

    # for SP and Manaus, top-10 baseline
    canonical = {"São Paulo (355030)": "355030", "Manaus (130260)": "130260"}
    base_topk = {}
    for label, mid in canonical.items():
        if mid not in base_idx:
            log.warning("%s not in baseline", label); continue
        sims = base_n @ base_n[base_idx[mid]]
        sims[base_idx[mid]] = -np.inf
        top = np.argpartition(-sims, TOPK)[:TOPK]
        base_topk[label] = set(base_ids[k] for k in top)

    results = {}
    for seed in SEEDS[1:]:
        s_ids, s_emb = embeddings[seed]
        s_idx = {n: i for i, n in enumerate(s_ids)}
        s_norms = np.linalg.norm(s_emb, axis=1, keepdims=True)
        s_norms[s_norms == 0] = 1
        s_n = s_emb / s_norms

        # pair-distance correlation against baseline (mesmas 5000 pairs)
        common_idx_s = np.array([s_idx[n] for n in common])
        pa_s = common_idx_s[a]; pb_s = common_idx_s[b]
        s_d = 1 - (s_n[pa_s] * s_n[pb_s]).sum(axis=1)
        rho = float(np.corrcoef(base_d, s_d)[0, 1])

        # top-10 Jaccard against baseline
        topk_jac = {}
        for label, mid in canonical.items():
            if mid not in s_idx: continue
            sims = s_n @ s_n[s_idx[mid]]
            sims[s_idx[mid]] = -np.inf
            top = np.argpartition(-sims, TOPK)[:TOPK]
            s_topk = set(s_ids[k] for k in top)
            inter = len(s_topk & base_topk[label])
            union = len(s_topk | base_topk[label])
            topk_jac[label] = inter / union if union else 1.0
            log.info("  seed=%d  %s  Jaccard=%.2f", seed, label, topk_jac[label])

        results[str(seed)] = {
            "rho_pair_distance_vs_baseline_42": rho,
            "topk_jaccard_vs_baseline": topk_jac,
        }
        log.info("seed=%d  rho_pairs=%.4f", seed, rho)

    out = {"baseline_seed": 42, "n_pairs_compared": len(base_d),
           "n_common_nodes": len(common), "K": TOPK, "results": results}
    (LOG / "37_seed_stability.json").write_text(json.dumps(out, indent=2))
    log.info("wrote 37_seed_stability.json")
    log.info("==== done %.0fs ====", time.time() - t0)


if __name__ == "__main__":
    main()
