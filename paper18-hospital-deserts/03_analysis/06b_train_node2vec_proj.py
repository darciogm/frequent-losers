"""
06b_train_node2vec_proj.py

Projeção M-M do grafo bipartido paciente-hospital, depois node2vec.

Motivação: o embedding bipartido puro (06) tem problema topológico — random
walks alternam paridade M↔H, então cos(M_i, M_j) fica baixo por construção,
não por dissimilaridade substantiva. Para responder "Beyond the kilometer:
network-revealed access *between municipalities*", precisamos de um grafo
monopartido onde dois municípios estão ligados se compartilham hospitais
(co-paciência hospitalar).

Construção do grafo M-M:
1. A_MH = adjacência município × hospital ponderada por n_internacoes (sparse)
2. Row-normalize: cada linha vira distribuição de probabilidade do paciente do
   município i sobre hospitais (TF-style)
3. IDF nos hospitais: down-weight de hubs (HC-USP, INCOR) que servem todo
   mundo e contaminariam similaridades. idf_h = log(N_M / df_h), df_h =
   número de municípios que mandam ≥1 paciente para h
4. A_MH_w = A_MH_norm * idf_h (broadcast por coluna)
5. A_MM = A_MH_w @ A_MH_w.T → similaridade de co-paciência (sparse mas densa
   localmente)
6. Threshold: para cada município, manter apenas top-K vizinhos (K=30) — corta
   ruído e mantém o grafo esparso
7. Simetrizar (max(w_ij, w_ji))

Hyperparams node2vec idênticos ao 06 para comparabilidade direta.

Input:
- 02_data/intermediate/bipartite_edges_pooled.parquet

Output:
- 02_data/intermediate/embeddings_munmun_proj.parquet
  Schema: cod_mun_6 (str), dim_0..dim_127 (float32)
- 02_data/intermediate/edges_munmun_proj.parquet (debug/inspeção)
"""

from __future__ import annotations

import gc
import logging
import os
import sys
import tempfile
import time
from pathlib import Path

import numpy as np
import polars as pl
import psutil
import scipy.sparse as sp
from pecanpy import pecanpy as pn

ROOT = Path(__file__).resolve().parents[1]
INTER = ROOT / "02_data" / "intermediate"
LOG = ROOT / "04_logs"
LOG.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "06b_train_node2vec_proj.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("n2v_proj")

EDGES_BIP = INTER / "bipartite_edges_pooled.parquet"
OUT_EMB = INTER / "embeddings_munmun_proj.parquet"
OUT_EDG = INTER / "edges_munmun_proj.parquet"

DIM = 128
WALK_LENGTH = 20
NUM_WALKS = 10
P = 1.0
Q = 1.0
WINDOW = 10
EPOCHS = 5
WORKERS = 12
SEED = 42
TOPK = 30

os.environ["OMP_NUM_THREADS"] = str(WORKERS)
os.environ["OPENBLAS_NUM_THREADS"] = str(WORKERS)
os.environ["MKL_NUM_THREADS"] = str(WORKERS)
os.environ["NUMBA_NUM_THREADS"] = str(WORKERS)


def rss_gb() -> float:
    return psutil.Process().memory_info().rss / 1e9


def stage(label: str, t_prev: float, t0: float) -> float:
    now = time.perf_counter()
    log.info("  [%s] %.1fs cumul=%.1fs RSS=%.2fGB",
             label, now - t_prev, now - t0, rss_gb())
    return now


def main():
    t0 = time.perf_counter()
    vm = psutil.virtual_memory()
    log.info("==== begin node2vec PROJECTION M-M ====")
    log.info("host=%s ram_total=%.1fGB ram_avail=%.1fGB workers=%d seed=%d topk=%d",
             os.uname().nodename, vm.total / 1e9, vm.available / 1e9,
             WORKERS, SEED, TOPK)
    log.info("hyperparams: dim=%d walk_len=%d num_walks=%d p=%.2f q=%.2f window=%d epochs=%d",
             DIM, WALK_LENGTH, NUM_WALKS, P, Q, WINDOW, EPOCHS)

    t = t0

    # ---- carregar arestas bipartidas ---------------------------------
    df = pl.read_parquet(EDGES_BIP)
    log.info("bipartite edges: %d", len(df))

    munis = sorted(df["codmun_6"].unique().to_list())
    hosps = sorted(df["CNES"].unique().to_list())
    n_M, n_H = len(munis), len(hosps)
    m_idx = {m: i for i, m in enumerate(munis)}
    h_idx = {h: i for i, h in enumerate(hosps)}
    log.info("|M|=%d  |H|=%d", n_M, n_H)

    rows = np.fromiter((m_idx[x] for x in df["codmun_6"].to_list()),
                       dtype=np.int32, count=len(df))
    cols = np.fromiter((h_idx[x] for x in df["CNES"].to_list()),
                       dtype=np.int32, count=len(df))
    w = df["n_internacoes"].to_numpy().astype(np.float32)
    A = sp.csr_matrix((w, (rows, cols)), shape=(n_M, n_H), dtype=np.float32)
    log.info("A_MH: %s nnz=%d", A.shape, A.nnz)
    del df, rows, cols, w
    gc.collect()
    t = stage("build_A_MH", t, t0)

    # ---- TF-IDF: row-normalize × idf por coluna ----------------------
    # row-norm: cada município com mistura de hospitais que soma 1
    row_sums = np.asarray(A.sum(axis=1)).ravel()
    row_sums[row_sums == 0] = 1.0
    D_row = sp.diags(1.0 / row_sums)
    A_tf = D_row @ A
    # IDF por hospital: penaliza hubs que recebem de todo município
    df_h = np.asarray((A > 0).sum(axis=0)).ravel().astype(np.float32)
    df_h[df_h == 0] = 1.0
    idf = np.log(n_M / df_h).astype(np.float32)
    D_idf = sp.diags(idf)
    A_w = A_tf @ D_idf
    log.info("A_w (TF-IDF): %s nnz=%d  idf range=[%.2f, %.2f] mean=%.2f",
             A_w.shape, A_w.nnz, idf.min(), idf.max(), idf.mean())
    del A, A_tf, D_row, D_idf
    gc.collect()
    t = stage("tfidf", t, t0)

    # ---- projeção M-M = A_w @ A_w.T ----------------------------------
    # resultado é simétrico, denso localmente (até |M|² = 31M cells), mas o
    # threshold logo a seguir corta para ~|M|·K = 168k arestas
    A_MM = (A_w @ A_w.T).tocsr()
    A_MM.setdiag(0)
    A_MM.eliminate_zeros()
    log.info("A_MM raw: %s nnz=%d (%.1fM cells)",
             A_MM.shape, A_MM.nnz, A_MM.nnz / 1e6)
    del A_w
    gc.collect()
    t = stage("project_MM", t, t0)

    # ---- threshold top-K vizinhos por município ----------------------
    # itera linhas, pega indices dos K maiores, descarta resto
    indptr = [0]
    indices = []
    data = []
    A_MM_lil = A_MM.tolil()
    for i in range(n_M):
        row = A_MM.getrow(i)
        if row.nnz == 0:
            indptr.append(indptr[-1])
            continue
        cols_i = row.indices
        vals_i = row.data
        if len(vals_i) > TOPK:
            top = np.argpartition(-vals_i, TOPK)[:TOPK]
            cols_i = cols_i[top]
            vals_i = vals_i[top]
        indices.extend(cols_i.tolist())
        data.extend(vals_i.tolist())
        indptr.append(indptr[-1] + len(cols_i))
    A_top = sp.csr_matrix(
        (np.array(data, dtype=np.float32),
         np.array(indices, dtype=np.int32),
         np.array(indptr, dtype=np.int32)),
        shape=(n_M, n_M),
    )
    # simetrizar: max(w_ij, w_ji)
    A_sym = A_top.maximum(A_top.T).tocsr()
    log.info("A_top@K%d: nnz=%d  A_sym: nnz=%d  avg_degree=%.1f",
             TOPK, A_top.nnz, A_sym.nnz, A_sym.nnz / n_M)
    del A_MM, A_MM_lil, A_top, indptr, indices, data
    gc.collect()
    t = stage("topk_threshold", t, t0)

    # ---- exportar edge list (debug + edge list pra pecanpy) ----------
    coo = A_sym.tocoo()
    keep = coo.row < coo.col  # uma direção só; pecanpy directed=False
    src_idx = coo.row[keep]
    dst_idx = coo.col[keep]
    w_e = coo.data[keep]
    edges_df = pl.DataFrame({
        "src_codmun_6": [munis[i] for i in src_idx],
        "dst_codmun_6": [munis[i] for i in dst_idx],
        "weight": w_e.astype(np.float32),
    })
    edges_df.write_parquet(OUT_EDG, compression="snappy")
    log.info("wrote edges parquet: %s (%d edges)", OUT_EDG, len(edges_df))

    # edge list TSV pra pecanpy.read_edg
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".edg", delete=False, dir="/tmp"
    ) as f:
        edge_tsv = f.name
        for s, d_, ww in edges_df.iter_rows():
            f.write(f"{s}\t{d_}\t{ww}\n")
    log.info("wrote edge TSV: %s (%.1fMB)",
             edge_tsv, os.path.getsize(edge_tsv) / 1e6)
    del coo, edges_df, A_sym
    gc.collect()
    t = stage("export_edges", t, t0)

    # ---- pecanpy SparseOTF -------------------------------------------
    g = pn.SparseOTF(p=P, q=Q, workers=WORKERS, verbose=False, random_state=SEED)
    g.read_edg(edge_tsv, weighted=True, directed=False, delimiter="\t")
    node_ids = list(g.nodes)
    log.info("pecanpy graph: %d nodes  %d edges", len(node_ids), g.num_edges)
    os.unlink(edge_tsv)
    t = stage("read_edg", t, t0)

    g.preprocess_transition_probs()
    t = stage("preprocess_probs", t, t0)

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
    t = stage("embed", t, t0)

    # ---- exportar -----------------------------------------------------
    cols_out = {"cod_mun_6": node_ids}
    for d in range(DIM):
        cols_out[f"dim_{d}"] = emb[:, d]
    out_df = pl.DataFrame(cols_out)
    out_df.write_parquet(OUT_EMB, compression="snappy")
    log.info("wrote %s (rows=%d, cols=%d, file=%.1fMB)",
             OUT_EMB, len(out_df), len(out_df.columns),
             OUT_EMB.stat().st_size / 1e6)
    t = stage("write_parquet", t, t0)

    # ---- sanity 1: vizinhos de São Paulo (355030) --------------------
    id_to_idx = {n: i for i, n in enumerate(node_ids)}
    sp_idx = id_to_idx.get("355030")
    if sp_idx is not None:
        sims = emb @ emb[sp_idx]
        norms = np.linalg.norm(emb, axis=1) * np.linalg.norm(emb[sp_idx])
        sims = sims / np.where(norms > 0, norms, 1)
        top = np.argsort(-sims)[1:11]
        log.info("=== sanity: top-10 vizinhos de 355030 (São Paulo-SP) ===")
        for i in top:
            log.info("  %s : %.3f", node_ids[i], sims[i])

    # ---- sanity 2: vizinhos de Manaus (130260) -----------------------
    mn_idx = id_to_idx.get("130260")
    if mn_idx is not None:
        sims = emb @ emb[mn_idx]
        norms = np.linalg.norm(emb, axis=1) * np.linalg.norm(emb[mn_idx])
        sims = sims / np.where(norms > 0, norms, 1)
        top = np.argsort(-sims)[1:11]
        log.info("=== sanity: top-10 vizinhos de 130260 (Manaus-AM) ===")
        for i in top:
            log.info("  %s : %.3f", node_ids[i], sims[i])

    # ---- sanity 3: corr embedding-cosine vs km haversine -------------
    cent = pl.read_parquet(INTER / "municipios_centroids.parquet").select(
        ["cod_mun_6", "lat", "lon"]
    )
    emb_munis = pl.DataFrame({"cod_mun_6": node_ids, "_idx": np.arange(len(node_ids))})
    cent = cent.join(emb_munis, on="cod_mun_6", how="inner")
    log.info("centroids matched: %d / %d nodes", len(cent), len(node_ids))

    # amostra 5000 pares aleatórios pra correlação rápida
    rng = np.random.default_rng(SEED)
    n_match = len(cent)
    iA = rng.integers(0, n_match, size=5000)
    iB = rng.integers(0, n_match, size=5000)
    keep = iA != iB
    iA, iB = iA[keep], iB[keep]

    idx_a = cent["_idx"].to_numpy()[iA]
    idx_b = cent["_idx"].to_numpy()[iB]
    lat_a = np.deg2rad(cent["lat"].to_numpy()[iA])
    lat_b = np.deg2rad(cent["lat"].to_numpy()[iB])
    lon_a = np.deg2rad(cent["lon"].to_numpy()[iA])
    lon_b = np.deg2rad(cent["lon"].to_numpy()[iB])
    dlat = lat_b - lat_a
    dlon = lon_b - lon_a
    a = np.sin(dlat / 2)**2 + np.cos(lat_a) * np.cos(lat_b) * np.sin(dlon / 2)**2
    km = 2 * 6371 * np.arcsin(np.sqrt(a))

    e_a = emb[idx_a]
    e_b = emb[idx_b]
    cos = (e_a * e_b).sum(axis=1) / (
        np.linalg.norm(e_a, axis=1) * np.linalg.norm(e_b, axis=1) + 1e-12
    )
    emb_dist = 1 - cos

    pearson = np.corrcoef(emb_dist, km)[0, 1]
    spearman = np.corrcoef(
        np.argsort(np.argsort(emb_dist)),
        np.argsort(np.argsort(km)),
    )[0, 1]
    log.info("=== sanity: emb_dist vs km (n=%d pares) ===", len(km))
    log.info("  pearson(emb_dist, km) = %.3f", pearson)
    log.info("  spearman(emb_dist, km) = %.3f", spearman)
    log.info("  km median=%.0f  mean=%.0f  max=%.0f",
             np.median(km), km.mean(), km.max())

    log.info("==== done ==== elapsed=%.1fs (%.1fmin) peak_RSS=%.2fGB",
             time.perf_counter() - t0,
             (time.perf_counter() - t0) / 60,
             rss_gb())


if __name__ == "__main__":
    main()
