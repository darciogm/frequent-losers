"""
10_robustness.py

Roda as robustezas que o apêndice do paper afirma. Sem isso, são alucinações.

Seções do apêndice cobertas:
A) Seed stability — re-treina embedding bipartite com seeds {1, 13, 100}
   além do baseline 42. Reporta:
   - Correlação Pearson entre emb_dist baseline-vs-alternativa em 5000 pares
     aleatórios fixos
   - Concordância dos top-10 vizinhos para São Paulo e Manaus
B) Walk-length sensitivity — re-treina com walk_length ∈ {40, 80} mantendo
   resto. Reporta a mesma correlação Pearson + identidade dos top-15
   divergence positiva e negativa.
C) Alternative high-complexity definition — recalcula divergence_panel sob
   (i) só CARDIO+ONCO, (ii) só habilitações ativas em ≥24 meses do panel.
   Reporta rank-correlation Spearman do divergence vs baseline.
D) Sample restriction sensitivity — re-roda regressão de mortalidade com
   pop_min ∈ {0, 50_000} e com restrição "amenable count > 0 todo ano".
   Reporta delta R² emb-over-km em cada caso.

Output:
- 04_logs/10_robustness.json
- 04_logs/10_robustness.log
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
import psutil
from pecanpy import pecanpy as pn
from sklearn.linear_model import Ridge
from sklearn.metrics import r2_score
from sklearn.model_selection import KFold

ROOT = Path(__file__).resolve().parents[1]
INTER = ROOT / "02_data" / "intermediate"
LOG = ROOT / "04_logs"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "10_robustness.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("rob")

EDGES_BIP = INTER / "bipartite_edges_pooled.parquet"
HUB = INTER / "hospital_hub_classification.parquet"
MASTER = INTER / "hospital_master.parquet"
CENT = INTER / "municipios_centroids.parquet"
MORT = INTER / "amenable_mortality.parquet"
POP = INTER / "pop_municipal_2015_2025.parquet"
PIB = INTER / "pib_municipal_2015_2023.parquet"
DIV_BASELINE = INTER / "divergence_panel.parquet"

WORKERS = 12
DIM = 128
WALK_LEN_BASELINE = 20
NUM_WALKS = 10
WINDOW = 10
EPOCHS = 5
SEED_BASELINE = 42

HIGH_COMPLEX = {"CARDIO", "ONCO", "NEURO", "RENAL",
                "PERINAT", "TRAUMA_ORTO", "TRANSPLANTE"}
HIGH_COMPLEX_NARROW = {"CARDIO", "ONCO"}

os.environ["OMP_NUM_THREADS"] = str(WORKERS)
os.environ["NUMBA_NUM_THREADS"] = str(WORKERS)


def rss_gb() -> float:
    return psutil.Process().memory_info().rss / 1e9


def train_bipartite(seed: int, walk_length: int) -> tuple[list, np.ndarray]:
    """Re-treina o embedding bipartite com hyperparams variados.
    Retorna (node_ids, emb).
    """
    df = pl.read_parquet(EDGES_BIP)
    with tempfile.NamedTemporaryFile(mode="w", suffix=".edg", delete=False, dir="/tmp") as f:
        edge_path = f.name
        out = df.select(
            (pl.lit("M:") + pl.col("codmun_6")).alias("src"),
            (pl.lit("H:") + pl.col("CNES")).alias("dst"),
            pl.col("n_internacoes").cast(pl.Float32).alias("w"),
        )
        for s, d_, w in out.iter_rows():
            f.write(f"{s}\t{d_}\t{w}\n")
    g = pn.SparseOTF(p=1.0, q=1.0, workers=WORKERS, verbose=False, random_state=seed)
    g.read_edg(edge_path, weighted=True, directed=False, delimiter="\t")
    node_ids = list(g.nodes)
    g.preprocess_transition_probs()
    emb = g.embed(
        dim=DIM,
        num_walks=NUM_WALKS,
        walk_length=walk_length,
        window_size=WINDOW,
        epochs=EPOCHS,
        verbose=False,
    )
    os.unlink(edge_path)
    return node_ids, np.asarray(emb, dtype=np.float32)


def emb_dist_pairs(emb: np.ndarray, node_ids: list, ids: list[str], rng) -> np.ndarray:
    """Pega 5000 pares aleatórios (fixados pelo rng) e retorna emb_dist."""
    idx_map = {n: i for i, n in enumerate(node_ids)}
    valid = [i for i in ids if i in idx_map]
    pairs = rng.choice(len(valid), size=10000).reshape(-1, 2)
    pairs = pairs[pairs[:, 0] != pairs[:, 1]][:5000]
    a = np.array([idx_map[valid[i]] for i in pairs[:, 0]])
    b = np.array([idx_map[valid[i]] for i in pairs[:, 1]])
    cosine = (emb[a] * emb[b]).sum(axis=1) / (
        np.linalg.norm(emb[a], axis=1) * np.linalg.norm(emb[b], axis=1) + 1e-12
    )
    return 1 - cosine


def topk_neighbors(emb: np.ndarray, node_ids: list, target_id: str, k: int = 10) -> list[str]:
    idx_map = {n: i for i, n in enumerate(node_ids)}
    if target_id not in idx_map:
        return []
    i = idx_map[target_id]
    norms = np.linalg.norm(emb, axis=1) + 1e-12
    sims = (emb @ emb[i]) / (norms * norms[i])
    sims[i] = -np.inf
    top = np.argsort(-sims)[:k]
    return [node_ids[j] for j in top]


def main():
    t0 = time.perf_counter()
    log.info("==== robustness battery begins ====")
    log.info("RAM avail=%.1fGB workers=%d", psutil.virtual_memory().available / 1e9, WORKERS)

    results: dict = {"seed_stability": {}, "walk_length": {}, "high_complex_def": {}, "sample_restriction": {}}

    # ---- baseline carregar ----------------------------------------
    log.info("[A] training baseline (seed=42, walk_len=20)...")
    nodes_base, emb_base = train_bipartite(SEED_BASELINE, WALK_LEN_BASELINE)
    log.info("    baseline emb shape=%s elapsed=%.1fs RSS=%.2fGB",
             emb_base.shape, time.perf_counter() - t0, rss_gb())

    rng = np.random.default_rng(123)
    fixed_pairs_ids = [n for n in nodes_base if n.startswith("M:")]
    base_dists = emb_dist_pairs(emb_base, nodes_base, fixed_pairs_ids, rng)
    sp_neighbors_base = topk_neighbors(emb_base, nodes_base, "M:355030", 10)
    mn_neighbors_base = topk_neighbors(emb_base, nodes_base, "M:130260", 10)
    log.info("    SP top-10 baseline: %s", [s.split(":")[1] for s in sp_neighbors_base if s.startswith("M:")][:5] or sp_neighbors_base[:5])
    log.info("    Manaus top-10 baseline: %s", [s.split(":")[1] for s in mn_neighbors_base if s.startswith("M:")][:5] or mn_neighbors_base[:5])

    # ---- A) seed stability ----------------------------------------
    for seed in [1, 13, 100]:
        t = time.perf_counter()
        log.info("[A] training seed=%d...", seed)
        nodes_alt, emb_alt = train_bipartite(seed, WALK_LEN_BASELINE)

        rng2 = np.random.default_rng(123)
        alt_dists = emb_dist_pairs(emb_alt, nodes_alt, fixed_pairs_ids, rng2)
        ρ = float(np.corrcoef(base_dists, alt_dists)[0, 1])

        sp_alt = topk_neighbors(emb_alt, nodes_alt, "M:355030", 10)
        mn_alt = topk_neighbors(emb_alt, nodes_alt, "M:130260", 10)
        sp_overlap = len(set(sp_neighbors_base) & set(sp_alt))
        mn_overlap = len(set(mn_neighbors_base) & set(mn_alt))

        results["seed_stability"][f"seed_{seed}"] = {
            "pearson_emb_dist": ρ,
            "sp_top10_overlap": sp_overlap,
            "manaus_top10_overlap": mn_overlap,
        }
        log.info("    seed=%d: pearson(emb_dist)=%.3f  SP overlap=%d/10  Manaus overlap=%d/10  elapsed=%.1fs",
                 seed, ρ, sp_overlap, mn_overlap, time.perf_counter() - t)

    # ---- B) walk-length sensitivity -------------------------------
    for wlen in [40, 80]:
        t = time.perf_counter()
        log.info("[B] training walk_length=%d...", wlen)
        nodes_alt, emb_alt = train_bipartite(SEED_BASELINE, wlen)
        rng2 = np.random.default_rng(123)
        alt_dists = emb_dist_pairs(emb_alt, nodes_alt, fixed_pairs_ids, rng2)
        ρ = float(np.corrcoef(base_dists, alt_dists)[0, 1])

        sp_alt = topk_neighbors(emb_alt, nodes_alt, "M:355030", 10)
        mn_alt = topk_neighbors(emb_alt, nodes_alt, "M:130260", 10)
        sp_overlap = len(set(sp_neighbors_base) & set(sp_alt))
        mn_overlap = len(set(mn_neighbors_base) & set(mn_alt))

        results["walk_length"][f"wlen_{wlen}"] = {
            "pearson_emb_dist": ρ,
            "sp_top10_overlap": sp_overlap,
            "manaus_top10_overlap": mn_overlap,
        }
        log.info("    walk_length=%d: pearson=%.3f  SP overlap=%d/10  Manaus overlap=%d/10  elapsed=%.1fs",
                 wlen, ρ, sp_overlap, mn_overlap, time.perf_counter() - t)

    # ---- C) alternative high-complexity definition ----------------
    log.info("[C] alternative high-complexity definitions...")
    cent_df = pl.read_parquet(CENT).select(["cod_mun_6", "lat", "lon"])
    master_df = pl.read_parquet(MASTER).select(["CNES", "codmun_6_modal"])

    def compute_iso_emb_for_set(hub_set: set, min_months: int = 0) -> np.ndarray:
        hub = pl.read_parquet(HUB).filter(
            (pl.col("CNES").str.strip_chars() != "") &
            (pl.col("hub_categoria").is_in(list(hub_set))) &
            (pl.col("hub_ativo_qualquer_mes")) &
            (pl.col("n_meses_ativos") >= min_months)
        ).select(["CNES", "codmun_6"]).unique()
        hub = hub.join(master_df, on="CNES", how="left").with_columns(
            pl.coalesce(pl.col("codmun_6_modal"), pl.col("codmun_6")).alias("codmun_6_loc")
        )
        hub_cent = hub.join(cent_df, left_on="codmun_6_loc", right_on="cod_mun_6", how="inner")

        bip_H = pl.DataFrame({
            "CNES": [n[2:] for n in nodes_base if n.startswith("H:")],
            "_idx": [i for i, n in enumerate(nodes_base) if n.startswith("H:")],
        })
        hub_with_vec = hub_cent.join(bip_H, on="CNES", how="inner")
        h_idx = hub_with_vec["_idx"].to_numpy()
        if len(h_idx) == 0:
            return np.full(5588, np.nan)
        hub_emb = emb_base[h_idx]
        m_idx = [i for i, n in enumerate(nodes_base) if n.startswith("M:")]
        mun_emb = emb_base[m_idx]
        mn = mun_emb / (np.linalg.norm(mun_emb, axis=1, keepdims=True) + 1e-12)
        hn = hub_emb / (np.linalg.norm(hub_emb, axis=1, keepdims=True) + 1e-12)
        return 1 - (mn @ hn.T).max(axis=1)

    div_baseline = pl.read_parquet(DIV_BASELINE)
    iso_emb_baseline = compute_iso_emb_for_set(HIGH_COMPLEX, 0)
    iso_emb_narrow = compute_iso_emb_for_set(HIGH_COMPLEX_NARROW, 0)
    iso_emb_long = compute_iso_emb_for_set(HIGH_COMPLEX, 24)

    valid = ~np.isnan(iso_emb_baseline) & ~np.isnan(iso_emb_narrow)
    rho_narrow = float(np.corrcoef(
        np.argsort(np.argsort(iso_emb_baseline[valid])),
        np.argsort(np.argsort(iso_emb_narrow[valid]))
    )[0, 1])
    valid2 = ~np.isnan(iso_emb_baseline) & ~np.isnan(iso_emb_long)
    rho_long = float(np.corrcoef(
        np.argsort(np.argsort(iso_emb_baseline[valid2])),
        np.argsort(np.argsort(iso_emb_long[valid2]))
    )[0, 1])
    log.info("    spearman(iso_emb baseline, narrow CARDIO+ONCO) = %.3f", rho_narrow)
    log.info("    spearman(iso_emb baseline, ≥24-month) = %.3f", rho_long)
    results["high_complex_def"] = {
        "spearman_narrow_cardio_onco": rho_narrow,
        "spearman_long_lived_min24mo": rho_long,
    }

    # ---- D) sample restriction sensitivity ------------------------
    log.info("[D] sample restriction sensitivity...")
    div = pl.read_parquet(DIV_BASELINE)
    mort = pl.read_parquet(MORT).filter(
        (pl.col("year") >= 2010) & (pl.col("year") <= 2023)
    ).group_by("codmun_6").agg([
        pl.col("n_amenable").sum().alias("n_amenable_tot"),
        pl.col("pop").mean().alias("pop_mean"),
        (pl.col("n_amenable") > 0).all().alias("amenable_pos_all_years"),
    ]).with_columns(
        rate_per100k=(pl.col("n_amenable_tot") / pl.col("pop_mean") / 14 * 1e5)
    )
    pop_alt = pl.read_parquet(POP).filter(
        (pl.col("ano") >= 2010) & (pl.col("ano") <= 2023)
    ).with_columns(codmun_6=pl.col("cod_mun").str.slice(0, 6)) \
     .group_by("codmun_6").agg(pop_mean_v2=pl.col("pop").mean())
    pib = pl.read_parquet(PIB).filter(
        (pl.col("ano") >= 2010) & (pl.col("ano") <= 2023)
    ).with_columns(codmun_6=pl.col("cod_mun").str.slice(0, 6)) \
     .group_by("codmun_6").agg(pib_mean=pl.col("pib_corr").mean())

    panel = div.join(mort, on="codmun_6", how="left") \
               .join(pop_alt, on="codmun_6", how="left") \
               .join(pib, on="codmun_6", how="left") \
               .with_columns(pop_eff=pl.coalesce("pop_mean", "pop_mean_v2"))

    def fit_eval(panel_filt) -> dict:
        df = panel_filt.filter(
            pl.col("rate_per100k").is_not_null() &
            pl.col("pop_eff").is_not_null() & (pl.col("pop_eff") > 0) &
            pl.col("pib_mean").is_not_null() & (pl.col("pib_mean") > 0) &
            pl.col("uf").is_not_null()
        ).with_columns([
            pl.col("pop_eff").log().alias("pop_log"),
            pl.col("pib_mean").log().alias("pib_log"),
            pl.col("rate_per100k").clip(
                pl.col("rate_per100k").quantile(0.01),
                pl.col("rate_per100k").quantile(0.99),
            ).alias("y"),
        ])
        if len(df) < 200:
            return {"n": len(df), "delta_emb_over_km": None}
        y = df["y"].to_numpy()
        pop_log = df["pop_log"].to_numpy().reshape(-1, 1)
        pib_log = df["pib_log"].to_numpy().reshape(-1, 1)
        uf_dum = pl.DataFrame({"uf": df["uf"].to_list()}).to_dummies("uf").to_numpy().astype(np.float32)
        iso_km_z = df["iso_km_z"].to_numpy().reshape(-1, 1)
        iso_emb_z = df["iso_emb_z"].to_numpy().reshape(-1, 1)
        base = np.hstack([pop_log, pib_log, uf_dum])
        kf = KFold(n_splits=5, shuffle=True, random_state=42)
        def cv(X):
            r2s = []
            for tr, te in kf.split(X):
                m = Ridge(alpha=1.0).fit(X[tr], y[tr])
                r2s.append(r2_score(y[te], m.predict(X[te])))
            return float(np.mean(r2s))
        r2_km = cv(np.hstack([base, iso_km_z]))
        r2_both = cv(np.hstack([base, iso_km_z, iso_emb_z]))
        return {"n": len(df), "r2_km": r2_km, "r2_both": r2_both,
                "delta_emb_over_km": r2_both - r2_km}

    for label, filt in [
        ("pop_min_0",      panel),
        ("pop_min_10000",  panel.filter(pl.col("pop_eff") >= 10_000)),
        ("pop_min_50000",  panel.filter(pl.col("pop_eff") >= 50_000)),
        ("amenable_pos_all_years",
            panel.filter(pl.col("pop_eff") >= 10_000)
                 .filter(pl.col("amenable_pos_all_years"))),
    ]:
        r = fit_eval(filt)
        results["sample_restriction"][label] = r
        log.info("    %-25s n=%4d  ΔR² emb-over-km=%s",
                 label, r["n"],
                 f"{r['delta_emb_over_km']:+.4f}" if r["delta_emb_over_km"] is not None else "n/a")

    # ---- final report --------------------------------------------
    (LOG / "10_robustness.json").write_text(json.dumps(results, indent=2))
    log.info("==== done ==== elapsed=%.1fs RSS=%.2fGB",
             time.perf_counter() - t0, rss_gb())
    log.info("=== summary ===")
    log.info(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
