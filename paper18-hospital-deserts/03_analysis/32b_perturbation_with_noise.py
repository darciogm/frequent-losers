"""
32b_perturbation_with_noise.py

R2 v3 — Counterfactual graph perturbation com noise baseline estimation.

Para cada year_pre, treinar node2vec N_SEEDS vezes (seeds diferentes,
mesmo grafo). Computar Jaccard inter-seeds = noise floor para esse year.
Para cada closure, treinar perturbed (1 seed), calcular Jaccard contra cada
baseline-seed. Perturbação = (jaccard_intra_baseline) - (jaccard_baseline_vs_perturbed).

Se perturbação > 0 (com std baseline como CI), efeito é real.

Output: 02_data/intermediate/perturbation_panel.parquet
  schema: codmun_6, CNES_fechou, year_closure, year_pre,
          jaccard_intra_baseline_mean, jaccard_intra_baseline_sd,
          jaccard_baseline_vs_perturbed_mean,
          perturbation_signal (= intra_mean - vs_perturbed_mean),
          z_signal (= signal / intra_sd)
"""

from __future__ import annotations

import argparse
import gc
import logging
import os
import sys
import tempfile
import time
from itertools import combinations
from pathlib import Path

import numpy as np
import polars as pl
import psutil
import scipy.sparse as sp
from pecanpy import pecanpy as pn

ROOT = Path(__file__).resolve().parents[1]
INTER = ROOT / "02_data" / "intermediate"
LOG = ROOT / "04_logs"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "32b_perturbation.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("perturb_v3")

EDGES_FILE = INTER / "bipartite_edges.parquet"
CLO_FILE = INTER / "hospital_closures_exogenous.parquet"
OUT_FILE = INTER / "perturbation_panel.parquet"

DIM = 64
WALK_LENGTH = 20
NUM_WALKS = 10
P, Q = 1.0, 1.0
WINDOW = 10
EPOCHS = 3
WORKERS = 12
TOPK = 10
TOPK_THRESHOLD = 30

N_SEEDS_BASELINE = 4
SEEDS_BASELINE = [42, 7, 13, 99]
SEED_PERTURBED = 2024

os.environ["OMP_NUM_THREADS"] = str(WORKERS)
os.environ["NUMBA_NUM_THREADS"] = str(WORKERS)


def rss_gb():
    return psutil.Process().memory_info().rss / 1e9


def train_node2vec(df_edges_pre, exclude_cnes, seed, label):
    """Treina embedding M-M, retorna (codmun_list, top-K dict por código)."""
    if exclude_cnes:
        df_edges_pre = df_edges_pre.filter(pl.col("CNES") != exclude_cnes)
    munis = sorted(df_edges_pre["codmun_6"].unique().to_list())
    hosps = sorted(df_edges_pre["CNES"].unique().to_list())
    n_M, n_H = len(munis), len(hosps)
    if n_M < 100 or n_H < 50:
        return None, None
    m_idx = {m: i for i, m in enumerate(munis)}
    h_idx = {h: i for i, h in enumerate(hosps)}

    rows = np.fromiter((m_idx[x] for x in df_edges_pre["codmun_6"].to_list()),
                       dtype=np.int32, count=len(df_edges_pre))
    cols = np.fromiter((h_idx[x] for x in df_edges_pre["CNES"].to_list()),
                       dtype=np.int32, count=len(df_edges_pre))
    w = df_edges_pre["n_internacoes"].to_numpy().astype(np.float32)
    A = sp.csr_matrix((w, (rows, cols)), shape=(n_M, n_H), dtype=np.float32)

    row_sums = np.asarray(A.sum(axis=1)).ravel()
    row_sums[row_sums == 0] = 1.0
    A_tf = sp.diags(1.0 / row_sums) @ A
    df_h = np.asarray((A > 0).sum(axis=0)).ravel().astype(np.float32)
    df_h[df_h == 0] = 1.0
    idf = np.log(n_M / df_h).astype(np.float32)
    A_w = A_tf @ sp.diags(idf)
    A_MM = (A_w @ A_w.T).tocsr()
    A_MM.setdiag(0); A_MM.eliminate_zeros()
    del A, A_tf, A_w; gc.collect()

    indptr = [0]; indices = []; data = []
    for i in range(n_M):
        row = A_MM.getrow(i)
        if row.nnz == 0:
            indptr.append(indptr[-1]); continue
        cols_i = row.indices; vals_i = row.data
        if len(vals_i) > TOPK_THRESHOLD:
            top = np.argpartition(-vals_i, TOPK_THRESHOLD)[:TOPK_THRESHOLD]
            cols_i = cols_i[top]; vals_i = vals_i[top]
        indices.extend(cols_i.tolist()); data.extend(vals_i.tolist())
        indptr.append(indptr[-1] + len(cols_i))
    A_top = sp.csr_matrix(
        (np.array(data, dtype=np.float32),
         np.array(indices, dtype=np.int32),
         np.array(indptr, dtype=np.int32)),
        shape=(n_M, n_M))
    A_sym = A_top.maximum(A_top.T).tocsr()
    del A_MM, A_top, indptr, indices, data; gc.collect()

    coo = A_sym.tocoo()
    keep = coo.row < coo.col
    src_idx = coo.row[keep]; dst_idx = coo.col[keep]; w_e = coo.data[keep]
    if len(w_e) == 0:
        return None, None

    with tempfile.NamedTemporaryFile(mode="w", suffix=".edg", delete=False, dir="/tmp") as f:
        edge_tsv = f.name
        for i in range(len(w_e)):
            f.write(f"{munis[src_idx[i]]}\t{munis[dst_idx[i]]}\t{w_e[i]}\n")

    g = pn.SparseOTF(p=P, q=Q, workers=WORKERS, verbose=False, random_state=seed)
    g.read_edg(edge_tsv, weighted=True, directed=False, delimiter="\t")
    node_ids = list(g.nodes)
    os.unlink(edge_tsv)
    g.preprocess_transition_probs()
    emb = g.embed(dim=DIM, num_walks=NUM_WALKS, walk_length=WALK_LENGTH,
                  window_size=WINDOW, epochs=EPOCHS, verbose=False)
    emb = np.asarray(emb, dtype=np.float32)

    # top-K vizinhos
    norms = np.linalg.norm(emb, axis=1, keepdims=True)
    norms = np.where(norms > 0, norms, 1)
    emb_n = emb / norms
    cos = emb_n @ emb_n.T
    np.fill_diagonal(cos, -np.inf)
    topk_idx = np.argpartition(-cos, TOPK, axis=1)[:, :TOPK]
    topk_dict = {munis[i]: {node_ids[k] for k in topk_idx[i] if k < len(node_ids)}
                 for i, _ in enumerate(node_ids)}
    del A_sym, emb, cos, emb_n, topk_idx; gc.collect()
    return node_ids, topk_dict


def jacc(a, b):
    if not a and not b: return 1.0
    return len(a & b) / len(a | b) if (a or b) else 0.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=None)
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    if OUT_FILE.exists() and not args.force:
        log.info("output existe — usar --force"); return

    t0 = time.time()
    log.info("==== begin perturbation v3 (node2vec + noise baseline) ====")
    log.info("seeds baseline: %s  seed perturbed: %d", SEEDS_BASELINE, SEED_PERTURBED)

    closures = pl.read_parquet(CLO_FILE).filter(pl.col("exogenous"))
    if args.limit:
        closures = closures.head(args.limit)
    log.info("closures: %d", len(closures))

    years_pre = sorted(set(y - 1 for y in closures["year_closure"].to_list()))
    log.info("years_pre: %s", years_pre)

    edges_all = pl.read_parquet(EDGES_FILE)

    # ---- baselines: para cada year_pre, N seeds ----
    log.info("[1/3] treinando %d × %d = %d baselines...",
             len(years_pre), N_SEEDS_BASELINE, len(years_pre) * N_SEEDS_BASELINE)
    baselines = {}  # year_pre -> [topk_dict per seed]
    for y in years_pre:
        df_pre = edges_all.filter(pl.col("year") == y)
        if len(df_pre) == 0: continue
        topks = []
        for seed in SEEDS_BASELINE:
            t_b = time.time()
            _, topk = train_node2vec(df_pre, None, seed, f"baseline_{y}_s{seed}")
            if topk is None: continue
            topks.append(topk)
            log.info("  baseline year=%d seed=%d  %ds  RSS=%.2fGB",
                     y, seed, int(time.time() - t_b), rss_gb())
        baselines[y] = topks

    # pre-compute Jaccard intra-baseline (noise floor) por (year, codmun)
    log.info("[2/3] computando Jaccard intra-baseline (noise floor)...")
    intra_mean = {}  # (year, codmun) -> mean
    intra_sd = {}    # (year, codmun) -> sd
    for y, topks in baselines.items():
        # munis comuns a todos os seeds
        common = set.intersection(*[set(t.keys()) for t in topks])
        for m in common:
            jac_pairs = []
            for a, b in combinations(range(len(topks)), 2):
                jac_pairs.append(jacc(topks[a][m], topks[b][m]))
            intra_mean[(y, m)] = float(np.mean(jac_pairs))
            intra_sd[(y, m)] = float(np.std(jac_pairs))

    log.info("intra-baseline summary (over all (year,muni)):")
    arr = np.array(list(intra_mean.values()))
    log.info("  mean=%.3f  median=%.3f  sd=%.3f", arr.mean(), np.median(arr), arr.std())

    # ---- perturbed: 1 treino por closure ----
    log.info("[3/3] treinando perturbações + computando signal...")
    rows_out = []
    for i, c in enumerate(closures.iter_rows(named=True)):
        cnes_h = c["CNES"]
        year_pre = c["year_closure"] - 1
        if year_pre not in baselines: continue
        df_pre = edges_all.filter(pl.col("year") == year_pre)
        t_p = time.time()
        _, pert_topk = train_node2vec(df_pre, cnes_h, SEED_PERTURBED,
                                       f"perturb_{cnes_h}_{year_pre}")
        if pert_topk is None: continue

        topks_b = baselines[year_pre]
        common = set.intersection(*[set(t.keys()) for t in topks_b]) & set(pert_topk.keys())

        for m in common:
            # Jaccard de perturbed vs cada baseline-seed
            vs = [jacc(pert_topk[m], topks_b[s][m]) for s in range(len(topks_b))]
            vs_mean = float(np.mean(vs))
            im = intra_mean.get((year_pre, m), 0.0)
            isd = intra_sd.get((year_pre, m), 1e-9)
            signal = im - vs_mean   # quanto a perturbação 'baixou' a similaridade
            z = signal / max(isd, 1e-3)
            rows_out.append({
                "codmun_6":     m,
                "CNES_fechou":  cnes_h,
                "year_closure": c["year_closure"],
                "year_pre":     year_pre,
                "jaccard_intra_baseline_mean": im,
                "jaccard_intra_baseline_sd":   isd,
                "jaccard_vs_perturbed_mean":   vs_mean,
                "perturbation_signal":         signal,
                "z_signal":                    z,
            })

        log.info("[%d/%d] CNES=%s year_pre=%d  recorded=%d  (%ds)",
                 i + 1, len(closures), cnes_h, year_pre, len(common),
                 int(time.time() - t_p))
        del pert_topk; gc.collect()

    log.info("[final] gravando output...")
    out_df = pl.DataFrame(rows_out)
    out_df.write_parquet(OUT_FILE, compression="snappy")
    log.info("wrote %s (rows=%d)", OUT_FILE, len(out_df))

    log.info("\n=== distribution of perturbation_signal (baseline noise-corrected) ===")
    log.info("\n%s", out_df["perturbation_signal"].describe())

    log.info("\n=== top 10 munis com maior signal médio ===")
    log.info("\n%s", out_df.group_by("codmun_6").agg([
        pl.col("perturbation_signal").max().alias("sig_max"),
        pl.col("perturbation_signal").mean().alias("sig_mean"),
        pl.col("z_signal").max().alias("z_max"),
    ]).sort("sig_mean", descending=True).head(10))

    log.info("\n=== fração de (m,h) com z_signal > 1.96 (1-sided test) ===")
    sig_count = (out_df["z_signal"] > 1.96).sum()
    log.info("  %d / %d (%.1f%%)", sig_count, len(out_df), 100.0*sig_count/len(out_df))

    log.info("==== done ==== elapsed %.1fs (%.1fmin)",
             time.time() - t0, (time.time() - t0) / 60)


if __name__ == "__main__":
    main()
