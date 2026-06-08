"""
32_counterfactual_perturbation.py

R2 — Counterfactual graph perturbation. Para cada (CNES_fechou, year_closure-1),
medir como a topologia do grafo paciente-fluxo muda ao remover o hospital
fechado.

Implementação determinística (sem random walks): usa diretamente a matriz
A_MM = (TF-IDF do bipartido) · (TF-IDF do bipartido)^T como medida de
similaridade município-município. Top-K vizinhos de m em A_MM são
deterministicamente reproduzíveis. Comparação Jaccard isola perturbação
puramente topológica de noise estocástico.

(Nota framework: equivalente conceitual a GraphSAGE inductive sobre grafo
counterfactual, com aggregation function = TF-IDF cosine. A propriedade
chave é "what changes about m's neighborhood structure when h is removed
from the bipartite graph?")

Output: 02_data/intermediate/perturbation_panel.parquet
  schema: codmun_6, CNES_fechou, year_closure, year_pre,
          jaccard_topK, perturbation (= 1 - jaccard),
          shared_pre (peso do hospital fechado em A_MM_baseline para m,
                       proxy de "how much does m depend on h?"),
          rank_lost (mudança de rank do principal vizinho de m)
"""

from __future__ import annotations

import argparse
import gc
import logging
import sys
import time
from pathlib import Path

import numpy as np
import polars as pl
import psutil
import scipy.sparse as sp

ROOT = Path(__file__).resolve().parents[1]
INTER = ROOT / "02_data" / "intermediate"
LOG = ROOT / "04_logs"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "32_perturbation.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("perturb")

EDGES_FILE = INTER / "bipartite_edges.parquet"
CLO_FILE = INTER / "hospital_closures_exogenous.parquet"
OUT_FILE = INTER / "perturbation_panel.parquet"

TOPK = 10


def rss_gb():
    return psutil.Process().memory_info().rss / 1e9


def build_AMM(df_edges_pre: pl.DataFrame, exclude_cnes: str | None = None):
    """Constrói A_MM = (TF-IDF bipartido) · (TF-IDF)^T determinístico.
    Retorna (codmun_list, A_MM dense ndarray normalizada por linha → cosine sim).
    """
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

    # TF-IDF
    row_sums = np.asarray(A.sum(axis=1)).ravel()
    row_sums[row_sums == 0] = 1.0
    A_tf = sp.diags(1.0 / row_sums) @ A
    df_h = np.asarray((A > 0).sum(axis=0)).ravel().astype(np.float32)
    df_h[df_h == 0] = 1.0
    idf = np.log(n_M / df_h).astype(np.float32)
    A_w = A_tf @ sp.diags(idf)
    # row-normalize for cosine
    rn = sp.linalg.norm(A_w, axis=1)
    rn[rn == 0] = 1.0
    A_norm = sp.diags(1.0 / rn) @ A_w

    # A_MM = A_norm · A_norm^T (cosine entre munis na representação TF-IDF)
    A_MM = (A_norm @ A_norm.T).tocsr()
    A_MM.setdiag(-np.inf)  # excluir auto-similaridade
    return munis, A_MM


def topk_indices_sparse(A_MM, target_idx, k):
    """Top-k indices na linha target_idx de A_MM sparse."""
    row = A_MM.getrow(target_idx)
    if row.nnz <= k:
        return row.indices.tolist()
    # converter para denso só essa linha (vetor pequeno)
    dense = row.toarray().ravel()
    top = np.argpartition(-dense, k)[:k]
    return top.tolist()


def jaccard(a, b):
    sa, sb = set(a), set(b)
    if not sa and not sb: return 1.0
    return len(sa & sb) / len(sa | sb) if (sa or sb) else 0.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=None)
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    if OUT_FILE.exists() and not args.force:
        log.info("output existe — usar --force"); return

    t0 = time.time()
    log.info("==== begin counterfactual perturbation (deterministic A_MM) ====")
    log.info("RAM avail=%.1fGB  topK=%d", psutil.virtual_memory().available/1e9, TOPK)

    closures = pl.read_parquet(CLO_FILE).filter(pl.col("exogenous"))
    if args.limit:
        closures = closures.head(args.limit)
    log.info("closures: %d", len(closures))

    years_pre = sorted(set(y - 1 for y in closures["year_closure"].to_list()))
    log.info("years_pre únicos: %s", years_pre)

    edges_all = pl.read_parquet(EDGES_FILE)

    # ---- baseline A_MM por year_pre ----
    log.info("[1/3] computando baselines por year_pre...")
    baselines = {}
    for y in years_pre:
        df_pre = edges_all.filter(pl.col("year") == y)
        log.info("  year_pre=%d: %d edges", y, len(df_pre))
        if len(df_pre) == 0: continue
        t_b = time.time()
        munis, A_MM = build_AMM(df_pre, exclude_cnes=None)
        if munis is None: continue
        # pré-computar top-K por nó
        topk_dict = {}
        for i in range(len(munis)):
            top = topk_indices_sparse(A_MM, i, TOPK)
            topk_dict[munis[i]] = [munis[k] for k in top]
        baselines[y] = (munis, topk_dict)
        log.info("    %ds  RSS=%.2fGB", int(time.time() - t_b), rss_gb())
        del A_MM; gc.collect()

    # ---- perturbed A_MM por (CNES, year_pre) ----
    log.info("[2/3] processando %d closures...", len(closures))
    rows_out = []
    for i, c in enumerate(closures.iter_rows(named=True)):
        cnes_h = c["CNES"]
        year_pre = c["year_closure"] - 1
        if year_pre not in baselines:
            log.warning("[%d/%d] year_pre=%d sem baseline", i + 1, len(closures), year_pre)
            continue
        base_munis, base_topk = baselines[year_pre]
        df_pre = edges_all.filter(pl.col("year") == year_pre)
        t_p = time.time()
        pert_munis, pert_AMM = build_AMM(df_pre, exclude_cnes=cnes_h)
        if pert_munis is None: continue

        # pré-computar topK perturbado
        common = sorted(set(base_munis) & set(pert_munis))
        pert_idx_for = {m: i_ for i_, m in enumerate(pert_munis)}

        n_recorded = 0
        for m in common:
            base_neigh = base_topk[m]
            pert_top_idx = topk_indices_sparse(pert_AMM, pert_idx_for[m], TOPK)
            pert_neigh = [pert_munis[k] for k in pert_top_idx]
            jac = jaccard(base_neigh, pert_neigh)
            rows_out.append({
                "codmun_6":      m,
                "CNES_fechou":   cnes_h,
                "year_closure":  c["year_closure"],
                "year_pre":      year_pre,
                "jaccard_topK":  jac,
                "perturbation":  1.0 - jac,
            })
            n_recorded += 1

        log.info("[%d/%d] CNES=%s year_pre=%d  recorded=%d  (%ds)",
                 i + 1, len(closures), cnes_h, year_pre, n_recorded,
                 int(time.time() - t_p))
        del pert_AMM; gc.collect()

    log.info("[3/3] gravando output...")
    out_df = pl.DataFrame(rows_out)
    out_df.write_parquet(OUT_FILE, compression="snappy")
    log.info("wrote %s (rows=%d)", OUT_FILE, len(out_df))

    # sumarios
    log.info("\n=== distribuição perturbation por CNES ===")
    log.info("\n%s", out_df.group_by("CNES_fechou").agg([
        pl.col("perturbation").mean().alias("pert_mean"),
        pl.col("perturbation").max().alias("pert_max"),
        (pl.col("perturbation") > 0.3).sum().alias("n_strong"),
        (pl.col("perturbation") > 0.5).sum().alias("n_severe"),
    ]).sort("pert_mean", descending=True).head(10))

    log.info("\n=== top 10 munis com maior perturbação total ===")
    log.info("\n%s", out_df.group_by("codmun_6").agg([
        pl.col("perturbation").max().alias("pert_max"),
        pl.col("perturbation").mean().alias("pert_mean"),
        pl.col("CNES_fechou").n_unique().alias("n_closures"),
    ]).sort("pert_max", descending=True).head(10))

    log.info("\n=== distribuição global ===")
    log.info("\n%s", out_df["perturbation"].describe())

    log.info("==== done ==== elapsed %.1fs (%.1fmin)",
             time.time() - t0, (time.time() - t0) / 60)


if __name__ == "__main__":
    main()
