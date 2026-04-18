#!/usr/bin/env python3
"""
58_variance_benchmark.py — Classical variance screen as a benchmark

Implements the Abrantes-Metz-style variance screen at the pair level and
compares it to the two-feature composite from script 56/57. The goal is
to answer the referee question: "how much better is your composite than
the classical bid-variance screen on the same sample?"

Benchmark construction (pair-level aggregation of a classical screen):
  For each auction, compute the coefficient of variation (CV) of the bids
  that appear in that auction. For each firm pair (i, j), compute the
  average CV across all auctions in which both firms bid. Cartel pairs
  should exhibit LOWER CV on average (tighter bid clustering), because
  collusive bids cluster around the reference rather than dispersing.

Comparison:
  (1) Single-feature AUC of the pair-level CV against our ground truth.
  (2) Orthogonality check: add CV as a third feature to the composite
      and recompute OOF AUC.
  (3) CV-only LOO baseline vs composite LOO.

Outputs:
  02_data/intermediate/variance_benchmark.txt
"""
from __future__ import annotations
import time
from pathlib import Path
import numpy as np
import pandas as pd
import duckdb
from scipy.stats import mannwhitneyu

BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")
RAIS_DIR = BASE / "RAIS" / "parquet" / "harmonized"
FINAL = BASE / "02_data" / "final"
FIRMS = BASE / "02_data" / "firms"
INTER = BASE / "02_data" / "intermediate"

PAIRS_PREGAO = str(FINAL / "df_pregao_with_cartel_flags.parquet")
GROUND_TRUTH = str(FIRMS / "cade_ground_truth.parquet")

OUT = INTER / "variance_benchmark.txt"

N_CONTROLS = 2000
SEED = 42


def log(msg, t0):
    print(f"[{time.time()-t0:6.1f}s] {msg}", flush=True)


def mw_auc(pos, neg, alternative="greater"):
    pos = pos[~np.isnan(pos)]
    neg = neg[~np.isnan(neg)]
    if len(pos) == 0 or len(neg) == 0:
        return float("nan")
    stat, _ = mannwhitneyu(pos, neg, alternative=alternative)
    return float(stat / (len(pos) * len(neg)))


def fit_logistic(X, y, max_iter=500, lr=0.5, l2=0.001):
    n, k = X.shape
    mu = X.mean(axis=0)
    sd = X.std(axis=0) + 1e-10
    Xn = np.column_stack([np.ones(n), (X - mu) / sd])
    n_pos = max((y == 1).sum(), 1)
    n_neg = max((y == 0).sum(), 1)
    sw = np.where(y == 1, n / (2 * n_pos), n / (2 * n_neg))
    w = np.zeros(k + 1)
    for _ in range(max_iter):
        z = Xn @ w
        p = 1 / (1 + np.exp(-np.clip(z, -30, 30)))
        grad = (Xn * sw[:, None]).T @ (p - y) / sw.sum() + l2 * np.r_[0, w[1:]]
        w -= lr * grad
    return w, mu, sd


def predict(w, X, mu, sd):
    Xn = np.column_stack([np.ones(len(X)), (X - mu) / sd])
    return Xn @ w


def loo_setor_auc(D, feat_cols, setor_list):
    X = D[feat_cols].values.astype(float)
    y = D["label"].values.astype(int)
    oof = np.full(len(D), np.nan)
    for s in setor_list:
        train_mask = ~((D["label"] == 1) & (D["tag"] == s))
        eval_mask = ((D["label"] == 1) & (D["tag"] == s)) | (D["label"] == 0)
        X_tr = X[train_mask.values]
        y_tr = y[train_mask.values]
        X_ev = X[eval_mask.values]
        w, mu, sd = fit_logistic(X_tr, y_tr)
        oof[eval_mask.values] = predict(w, X_ev, mu, sd)
    mask = ~np.isnan(oof)
    return mw_auc(oof[mask][y[mask] == 1], oof[mask][y[mask] == 0])


def main():
    t0 = time.time()
    INTER.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect()
    con.sql("PRAGMA threads=12; PRAGMA memory_limit='14GB'")
    rais_pre = str(RAIS_DIR / "rais_vinculos_2009.parquet")

    # 1. Cartels and sampling (same as 56)
    log("Step 1: cartels + controls", t0)
    con.sql(f"""
        CREATE TABLE cf AS
        SELECT DISTINCT cnpj_raiz, setor
        FROM read_parquet('{GROUND_TRUTH}')
        WHERE sp_relevant = 1 AND processo IS NOT NULL
          AND cartel_start_year IS NOT NULL
          AND cartel_end_year <= 2016
          AND in_bec = 1
    """)
    cf_df = con.sql("SELECT * FROM cf").fetchdf()
    firm_to_setor = dict(zip(cf_df["cnpj_raiz"], cf_df["setor"]))
    cartel_firms = list(cf_df["cnpj_raiz"])
    setor_list = sorted(cf_df["setor"].unique())

    ctrl_pool = con.sql(f"""
        SELECT DISTINCT cnpj_raiz FROM read_parquet('{PAIRS_PREGAO}')
        WHERE cnpj_raiz IS NOT NULL
          AND cnpj_raiz NOT IN (SELECT cnpj_raiz FROM cf)
    """).fetchdf()
    rng = np.random.default_rng(SEED)
    controls = list(ctrl_pool.sample(n=N_CONTROLS, random_state=SEED)["cnpj_raiz"])
    log(f"  cartel: {len(cartel_firms)}, controls: {len(controls)}", t0)

    # 2. Item-level CV: for each item code, mean CV of its auctions
    log("Step 2: item-level mean CV", t0)
    con.sql(f"""
        CREATE TABLE auction_stats AS
        SELECT auction_item, "códigoitem" AS item,
               COUNT(*)                   AS n_bids,
               AVG(valorunitárioproposta) AS mean_bid,
               STDDEV(valorunitárioproposta) AS sd_bid,
               CASE WHEN AVG(valorunitárioproposta) > 0
                    THEN STDDEV(valorunitárioproposta) / AVG(valorunitárioproposta)
                    ELSE NULL END         AS cv_bid
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE cnpj_raiz IS NOT NULL
          AND valorunitárioproposta > 0 AND valorunitárioproposta < 1e9
        GROUP BY auction_item, item
        HAVING COUNT(*) >= 2
    """)
    con.sql("""
        CREATE TABLE item_cv AS
        SELECT item, AVG(cv_bid) AS mean_cv, COUNT(*) AS n_auc
        FROM auction_stats
        WHERE cv_bid IS NOT NULL
        GROUP BY item
    """)
    n_items_cv = con.sql("SELECT COUNT(*) FROM item_cv").fetchone()[0]
    item_cv_map = con.sql("SELECT item, mean_cv FROM item_cv").fetchdf() \
                      .set_index("item")["mean_cv"].to_dict()
    log(f"  items with CV-valid auctions: {n_items_cv:,}", t0)

    # 3. Firms × items bidding map for pair aggregation
    log("Step 3: firm × item bidding history", t0)
    firms_all = list(cartel_firms) + controls
    fs_sql = ",".join(f"'{f}'" for f in firms_all)
    firm_items = con.sql(f"""
        SELECT cnpj_raiz AS firm, "códigoitem" AS item
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE cnpj_raiz IN ({fs_sql})
        GROUP BY firm, item
    """).fetchdf()
    from collections import defaultdict
    firm_to_items = defaultdict(set)
    for f, it in zip(firm_items["firm"].values, firm_items["item"].values):
        firm_to_items[f].add(it)
    log(f"  firm × item rows: {len(firm_items):,}", t0)

    # Target pairs: build positive and negative pair list (same as 56)
    positive_pairs = []
    for s in setor_list:
        firms_s = cf_df[cf_df["setor"] == s]["cnpj_raiz"].tolist()
        for i in range(len(firms_s)):
            for j in range(i + 1, len(firms_s)):
                positive_pairs.append((firms_s[i], firms_s[j], s, 1))
    # Negative: random sample of pair index pairs from controls
    max_neg = 100000
    neg_pairs = set()
    while len(neg_pairs) < max_neg:
        i = rng.integers(0, len(controls))
        j = rng.integers(0, len(controls))
        if i != j:
            neg_pairs.add(tuple(sorted([i, j])))
    negative_pairs = [(controls[i], controls[j], "_ctrl_", 0)
                       for (i, j) in neg_pairs]

    # Pair-level aggregation: mean item-CV across items in Π_i ∩ Π_j
    def pair_cv(a, b):
        ia = firm_to_items.get(a, set())
        ib = firm_to_items.get(b, set())
        common = ia & ib
        if not common:
            return np.nan
        cvs = [item_cv_map[it] for it in common if it in item_cv_map]
        if not cvs:
            return np.nan
        return float(np.mean(cvs))

    def pair_n(a, b):
        ia = firm_to_items.get(a, set())
        ib = firm_to_items.get(b, set())
        return len(ia & ib)

    # 4. Load the composite features from 56's pair frame quickly
    #    (we rebuild with same SQL as 56 for labor + overlap features)
    log("Step 4: labor + overlap features", t0)
    con.sql(f"""
        CREATE TABLE emp AS
        SELECT cnpj_raiz AS firm, cbo2002::VARCHAR AS cbo,
               mun_estab::VARCHAR AS mun, COUNT(*) AS n
        FROM read_parquet('{rais_pre}')
        WHERE cnpj_raiz IN ({fs_sql})
          AND cbo2002 IS NOT NULL AND mun_estab IS NOT NULL
        GROUP BY firm, cbo, mun
    """)
    emp = con.sql("SELECT * FROM emp").fetchdf()
    emp["cell"] = emp["cbo"].astype(str) + "|" + emp["mun"].astype(str)
    mat = emp.pivot_table(index="firm", columns="cell", values="n",
                          fill_value=0, aggfunc="sum").astype(float)
    firms_with_emp = list(mat.index)
    firm_idx = {f: i for i, f in enumerate(firms_with_emp)}
    mv = mat.values
    norms = np.linalg.norm(mv, axis=1, keepdims=True)
    mv_n = mv / np.where(norms > 0, norms, 1)
    sim = mv_n @ mv_n.T

    items_per_firm = con.sql(f"""
        SELECT cnpj_raiz AS firm, "códigoitem" AS item
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE cnpj_raiz IN ({fs_sql})
        GROUP BY firm, item
    """).fetchdf()
    items_map = {f: set(sub["item"].values) for f, sub in items_per_firm.groupby("firm")}
    con.close()

    # 5. Build pair-level frame with CV feature
    log("Step 5: pair frame", t0)
    rows = []
    for (a, b, tag, y) in positive_pairs + negative_pairs:
        if a not in firm_idx or b not in firm_idx:
            continue
        cv_val = pair_cv(a, b)
        n_shared_auctions = pair_n(a, b)
        lc = float(sim[firm_idx[a], firm_idx[b]])
        ia = items_map.get(a, set())
        ib = items_map.get(b, set())
        inter = len(ia & ib)
        rows.append({
            "a": a, "b": b, "tag": tag, "label": y,
            "labor_cos":        lc,
            "log_item_overlap": np.log1p(inter),
            "cv_bid":           cv_val,
            "n_shared_auctions": n_shared_auctions,
            "neg_cv_bid":       -cv_val if cv_val == cv_val else np.nan,
        })
    D = pd.DataFrame(rows)
    D_cv = D[D["cv_bid"].notna()].copy()
    log(f"  frame: {len(D):,} ({int((D['label']==1).sum())} pos), "
        f"with CV defined: {len(D_cv):,} "
        f"({int((D_cv['label']==1).sum())} pos)", t0)

    # 6. Single-feature AUCs — note CV is INVERSELY related to cartel
    #    (cartels should have lower CV), so score = -CV
    log("Step 6: AUCs", t0)
    y_all = D["label"].values
    y_cv  = D_cv["label"].values
    auc_lab    = mw_auc(D[D.label==1]["labor_cos"].values,
                         D[D.label==0]["labor_cos"].values)
    auc_ov     = mw_auc(D[D.label==1]["log_item_overlap"].values,
                         D[D.label==0]["log_item_overlap"].values)
    # CV: cartels should have lower CV, so use negative for "higher = more cartel"
    auc_cv_neg = mw_auc(D_cv[D_cv.label==1]["neg_cv_bid"].values,
                         D_cv[D_cv.label==0]["neg_cv_bid"].values)
    # Report the raw CV distributions
    pos_cv = D_cv[D_cv.label==1]["cv_bid"].values
    neg_cv = D_cv[D_cv.label==0]["cv_bid"].values

    log(f"  labor_cos alone       AUC = {auc_lab:.4f}", t0)
    log(f"  log_item_overlap alone AUC = {auc_ov:.4f}", t0)
    log(f"  -CV (variance screen) AUC = {auc_cv_neg:.4f}  "
        f"(pos mean CV = {pos_cv.mean():.3f}, neg = {neg_cv.mean():.3f})", t0)

    # 7. Leave-one-setor-out composite with and without CV
    log("Step 7: LOO composite variants", t0)
    two_feat = ["labor_cos", "log_item_overlap"]
    three_feat = ["labor_cos", "log_item_overlap", "neg_cv_bid"]

    auc_two = loo_setor_auc(D_cv, two_feat, setor_list)
    auc_three = loo_setor_auc(D_cv, three_feat, setor_list)
    auc_cv_only = loo_setor_auc(D_cv, ["neg_cv_bid"], setor_list)
    log(f"  two-feature LOO (on CV-valid sample)   = {auc_two:.4f}", t0)
    log(f"  three-feature LOO (+CV)                = {auc_three:.4f}", t0)
    log(f"  CV only LOO                             = {auc_cv_only:.4f}", t0)

    # 8. Report
    with open(OUT, "w") as f:
        f.write("Variance screen benchmark\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")

        f.write("DESIGN\n")
        f.write("-" * 50 + "\n")
        f.write("  Classical screen: coefficient of variation of bids per auction.\n")
        f.write("  Pair-level: mean CV across auctions where both firms bid.\n")
        f.write("  Sign convention: CARTEL → LOWER CV, so we use -CV as score.\n\n")

        f.write("SAMPLE\n")
        f.write("-" * 50 + "\n")
        f.write(f"  Total pair frame:       {len(D):,}\n")
        f.write(f"  With CV defined:        {len(D_cv):,}\n")
        f.write(f"  Positive pairs (total): {int((D['label']==1).sum())}\n")
        f.write(f"  Positive with CV:       {int((D_cv['label']==1).sum())}\n\n")

        f.write("RAW CV DISTRIBUTIONS\n")
        f.write("-" * 50 + "\n")
        f.write(f"  Positive (cartel) pairs: mean CV = {pos_cv.mean():.4f}  "
                f"median = {np.median(pos_cv):.4f}\n")
        f.write(f"  Negative pairs:          mean CV = {neg_cv.mean():.4f}  "
                f"median = {np.median(neg_cv):.4f}\n\n")

        f.write("SINGLE-FEATURE AUCs (in-sample ranking, full pair frame)\n")
        f.write("-" * 50 + "\n")
        f.write(f"  labor_cos             AUC = {auc_lab:.4f}\n")
        f.write(f"  log_item_overlap      AUC = {auc_ov:.4f}\n")
        f.write(f"  -CV (variance screen) AUC = {auc_cv_neg:.4f}\n\n")

        f.write("LEAVE-ONE-CADE-CARTEL-OUT AUCs (CV-valid sample)\n")
        f.write("-" * 50 + "\n")
        f.write(f"  two-feature  (labor + overlap)     = {auc_two:.4f}\n")
        f.write(f"  three-feature (+ variance screen)  = {auc_three:.4f}\n")
        f.write(f"  CV only                             = {auc_cv_only:.4f}\n\n")

        f.write("INTERPRETATION\n")
        f.write("-" * 50 + "\n")
        if auc_cv_neg < 0.55:
            f.write("  Classical variance screen: NEAR-RANDOM at pair level.\n")
        elif auc_cv_neg < 0.65:
            f.write("  Classical variance screen: WEAK detection signal.\n")
        else:
            f.write("  Classical variance screen: meaningful signal.\n")
        delta = auc_three - auc_two
        if delta > 0.01:
            f.write(f"  Adding CV gains +{delta:.4f} AUC over 2-feature baseline.\n")
        elif delta > -0.01:
            f.write(f"  Adding CV is neutral (Δ={delta:+.4f}) — orthogonal but weak.\n")
        else:
            f.write(f"  Adding CV HURTS (Δ={delta:+.4f}) — noise in joint fit.\n")

    log(f"report → {OUT}", t0)
    print("\n" + OUT.read_text())
    log(f"DONE ({time.time()-t0:.1f}s)", t0)


if __name__ == "__main__":
    main()
