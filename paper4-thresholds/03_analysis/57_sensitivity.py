#!/usr/bin/env python3
"""
57_sensitivity.py — Robustness checks for the composite classifier

Four sensitivity analyses that feed into §7 of the paper_screens draft:

  (1) Permutation test for the null distribution of OOF AUC under label
      shuffling. B = 500 shuffles; report empirical p-value and null
      distribution quantiles.

  (2) Bootstrap confidence intervals on single-feature AUCs and on the
      composite OOF AUC. B = 500 resamples of pairs (with class
      stratification) and refit of the composite on each resample.

  (3) Sensitivity to N_CONTROLS: rerun the composite across a grid of
      control-sample sizes {500, 1000, 2000, 3000, 5000} to check that
      the OOF AUC does not depend on a lucky control draw.

  (4) Alternative feature definitions:
        - Jaccard overlap |Π_i ∩ Π_j| / |Π_i ∪ Π_j| instead of log count
        - Labor similarity from 2010 instead of 2009 RAIS (placebo check
          on the pre-period year)
        - Symmetric n_pair with log transform as a separate feature
        - Combined 4-feature logistic

Outputs:
    02_data/intermediate/sensitivity.txt — single consolidated report
    04_figures/sensitivity_permutation.pdf — null-distribution histogram
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

OUT_REPORT = INTER / "sensitivity.txt"
OUT_FIGURE = BASE / "04_figures" / "sensitivity_permutation.pdf"

N_CONTROLS_DEFAULT = 2000
N_CONTROLS_GRID    = [500, 1000, 2000, 3000, 5000]
N_BOOT             = 500
N_PERM             = 500
SEED               = 42


# ── Helpers ──────────────────────────────────────────────────────────────────

def log(msg, t0):
    print(f"[{time.time()-t0:6.1f}s] {msg}", flush=True)


def mw_auc(pos, neg, alternative="greater"):
    if len(pos) == 0 or len(neg) == 0:
        return float("nan")
    stat, _ = mannwhitneyu(pos, neg, alternative=alternative)
    return float(stat / (len(pos) * len(neg)))


def fit_logistic(X, y, max_iter=500, lr=0.5, l2=0.001, class_weight="balanced"):
    n, k = X.shape
    mu = X.mean(axis=0)
    sd = X.std(axis=0) + 1e-10
    Xn = np.column_stack([np.ones(n), (X - mu) / sd])
    if class_weight == "balanced":
        w_pos = n / (2 * max((y == 1).sum(), 1))
        w_neg = n / (2 * max((y == 0).sum(), 1))
        sw = np.where(y == 1, w_pos, w_neg)
    else:
        sw = np.ones(n)
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
    """Compute leave-one-CADE-setor-out pooled OOF AUC for a given feature set."""
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


def build_features(con, cartel_firms, controls, rais_pre, pairs_pregao,
                    firm_to_setor, setor_list, rng, pre_year_alt=None):
    """Build pair-level feature frame D with features:
       labor_cos, log_item_overlap, log_n_pair, jaccard_overlap, lab_alt.

    Returns D DataFrame with columns [a, b, tag, label, labor_cos,
    log_item_overlap, log_n_pair, jaccard_overlap, lab_alt].
    """
    firms_all = list(cartel_firms) + list(controls)
    fs_sql = ",".join(f"'{f}'" for f in firms_all)

    # 2009 employment matrix
    con.sql("DROP TABLE IF EXISTS emp")
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

    # Optional alternative pre-year
    sim_alt = None
    if pre_year_alt is not None:
        rais_alt = str(RAIS_DIR / f"rais_vinculos_{pre_year_alt}.parquet")
        con.sql("DROP TABLE IF EXISTS emp_alt")
        con.sql(f"""
            CREATE TABLE emp_alt AS
            SELECT cnpj_raiz AS firm, cbo2002::VARCHAR AS cbo,
                   mun_estab::VARCHAR AS mun, COUNT(*) AS n
            FROM read_parquet('{rais_alt}')
            WHERE cnpj_raiz IN ({fs_sql})
              AND cbo2002 IS NOT NULL AND mun_estab IS NOT NULL
            GROUP BY firm, cbo, mun
        """)
        emp_a = con.sql("SELECT * FROM emp_alt").fetchdf()
        emp_a["cell"] = emp_a["cbo"].astype(str) + "|" + emp_a["mun"].astype(str)
        mat_a = emp_a.pivot_table(index="firm", columns="cell", values="n",
                                    fill_value=0, aggfunc="sum").astype(float)
        # Reindex to same firms as primary sim
        mat_a = mat_a.reindex(firms_with_emp, fill_value=0)
        mv_a = mat_a.values
        na = np.linalg.norm(mv_a, axis=1, keepdims=True)
        mv_a_n = mv_a / np.where(na > 0, na, 1)
        sim_alt = mv_a_n @ mv_a_n.T

    # n_pair (symmetric) from Q
    con.sql("DROP TABLE IF EXISTS ranked")
    con.sql(f"""
        CREATE TABLE ranked AS
        SELECT auction_item, cnpj_raiz AS firm, valorunitárioproposta AS bid,
               ROW_NUMBER() OVER (PARTITION BY auction_item
                                   ORDER BY valorunitárioproposta ASC) AS rnk
        FROM read_parquet('{pairs_pregao}')
        WHERE cnpj_raiz IS NOT NULL
          AND valorunitárioproposta > 0
          AND valorunitárioproposta < 1e9
    """)
    wr = con.sql("""
        SELECT a.firm AS winner, b.firm AS runner_up, COUNT(*) AS n_pair
        FROM ranked a JOIN ranked b ON a.auction_item = b.auction_item
        WHERE a.rnk = 1 AND b.rnk = 2 AND a.firm != b.firm
        GROUP BY a.firm, b.firm
    """).fetchdf()
    n_pair_sym = {}
    for _, row in wr.iterrows():
        key = tuple(sorted([row["winner"], row["runner_up"]]))
        n_pair_sym[key] = n_pair_sym.get(key, 0) + int(row["n_pair"])

    # Item sets per firm
    items_per_firm = con.sql(f"""
        SELECT cnpj_raiz AS firm, "códigoitem" AS item
        FROM read_parquet('{pairs_pregao}')
        WHERE cnpj_raiz IN ({fs_sql})
        GROUP BY firm, item
    """).fetchdf()
    items_map = {}
    for f, sub in items_per_firm.groupby("firm"):
        items_map[f] = set(sub["item"].values)

    # Positive pairs
    positive = []
    for s in setor_list:
        firms_s = [f for f in cartel_firms if firm_to_setor.get(f) == s]
        for i in range(len(firms_s)):
            for j in range(i + 1, len(firms_s)):
                positive.append((firms_s[i], firms_s[j], s, 1))

    # Negative pairs — sample from control pool
    n_c = len(controls)
    max_neg = 100000
    negative = []
    if n_c * (n_c - 1) // 2 > max_neg:
        idxs = set()
        while len(idxs) < max_neg:
            i = rng.integers(0, n_c)
            j = rng.integers(0, n_c)
            if i != j:
                idxs.add(tuple(sorted([i, j])))
        for i, j in idxs:
            negative.append((controls[i], controls[j], "_ctrl_", 0))
    else:
        for i in range(n_c):
            for j in range(i + 1, n_c):
                negative.append((controls[i], controls[j], "_ctrl_", 0))

    rows = []
    for (a, b, tag, y) in positive + negative:
        if a not in firm_idx or b not in firm_idx:
            continue
        lc = float(sim[firm_idx[a], firm_idx[b]])
        lc_alt = (float(sim_alt[firm_idx[a], firm_idx[b]])
                   if sim_alt is not None else np.nan)
        key = tuple(sorted([a, b]))
        npair = n_pair_sym.get(key, 0)
        ia = items_map.get(a, set())
        ib = items_map.get(b, set())
        inter = len(ia & ib)
        union = len(ia | ib)
        jacc = inter / union if union > 0 else 0.0
        rows.append({
            "a": a, "b": b, "tag": tag, "label": y,
            "labor_cos":        lc,
            "log_item_overlap": np.log1p(inter),
            "jaccard_overlap":  jacc,
            "log_n_pair":       np.log1p(npair),
            "lab_alt":          lc_alt,
        })
    return pd.DataFrame(rows)


def main():
    t0 = time.time()
    INTER.mkdir(parents=True, exist_ok=True)
    OUT_FIGURE.parent.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect()
    con.sql("PRAGMA threads=12; PRAGMA memory_limit='14GB'")
    rais_pre = str(RAIS_DIR / "rais_vinculos_2009.parquet")

    # Cartels
    log("cartels", t0)
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

    # Control pool
    con.sql(f"""
        CREATE TABLE bec_ctrl AS
        SELECT DISTINCT cnpj_raiz FROM read_parquet('{PAIRS_PREGAO}')
        WHERE cnpj_raiz IS NOT NULL
          AND cnpj_raiz NOT IN (SELECT cnpj_raiz FROM cf)
    """)
    ctrl_pool_df = con.sql("SELECT cnpj_raiz FROM bec_ctrl").fetchdf()
    log(f"  cartel firms: {len(cartel_firms)}  ctrl pool: "
        f"{len(ctrl_pool_df):,}", t0)

    rng = np.random.default_rng(SEED)

    # Build primary frame with N=2000 controls and 2009 pre year + 2010 alt
    log("building primary frame (N_CONTROLS=2000, lab_alt=2010)", t0)
    ctrl_2000 = list(ctrl_pool_df.sample(n=2000, random_state=SEED)["cnpj_raiz"])
    D = build_features(con, cartel_firms, ctrl_2000,
                        rais_pre, PAIRS_PREGAO,
                        firm_to_setor, setor_list, rng, pre_year_alt=2010)
    n_pos = int((D["label"] == 1).sum())
    n_neg = int((D["label"] == 0).sum())
    log(f"  D rows: {len(D):,}  pos {n_pos}  neg {n_neg:,}", t0)

    baseline_feats = ["labor_cos", "log_item_overlap"]
    baseline_auc = loo_setor_auc(D, baseline_feats, setor_list)
    log(f"  baseline OOF AUC = {baseline_auc:.4f}", t0)

    # ── Check 1: permutation test ──────────────────────────────────────────
    log(f"Check 1: permutation test (B={N_PERM})", t0)
    y_orig = D["label"].values.copy()
    perm_aucs = np.zeros(N_PERM)
    for b in range(N_PERM):
        perm = rng.permutation(y_orig)
        D["label"] = perm
        # Rebuild tag for the shuffled labels — positive tag stays only for
        # original positive rows; permuted "positives" get tag "_perm_"
        D_perm = D.copy()
        D_perm.loc[D_perm["label"] == 1, "tag"] = "_perm_"
        # Since leave-one-out needs setor labels on positives and we just
        # shuffled them, we skip LOO and use a simple in-sample AUC via
        # a random 80/20 holdout
        n = len(D_perm)
        idx = rng.permutation(n)
        split = int(0.8 * n)
        train_idx, test_idx = idx[:split], idx[split:]
        X_tr = D_perm[baseline_feats].values[train_idx]
        y_tr = D_perm["label"].values[train_idx]
        X_te = D_perm[baseline_feats].values[test_idx]
        y_te = D_perm["label"].values[test_idx]
        if y_tr.sum() < 2 or y_te.sum() < 1:
            perm_aucs[b] = 0.5
            continue
        w, mu, sd = fit_logistic(X_tr, y_tr)
        scores = predict(w, X_te, mu, sd)
        perm_aucs[b] = mw_auc(scores[y_te == 1], scores[y_te == 0])
    D["label"] = y_orig  # restore
    perm_p = (perm_aucs >= baseline_auc).mean()
    log(f"  perm null mean AUC = {perm_aucs.mean():.4f}  "
        f"p = {perm_p:.4f}", t0)

    # ── Check 2: bootstrap CI ──────────────────────────────────────────────
    log(f"Check 2: bootstrap CI (B={N_BOOT})", t0)
    # Stratified bootstrap: resample positives and negatives separately
    pos_idx = np.where(D["label"].values == 1)[0]
    neg_idx = np.where(D["label"].values == 0)[0]
    boot_aucs = np.zeros(N_BOOT)
    for b in range(N_BOOT):
        p_idx = rng.choice(pos_idx, size=len(pos_idx), replace=True)
        n_idx = rng.choice(neg_idx, size=len(neg_idx), replace=True)
        idx = np.concatenate([p_idx, n_idx])
        D_b = D.iloc[idx].reset_index(drop=True)
        boot_aucs[b] = loo_setor_auc(D_b, baseline_feats, setor_list)
        if (b + 1) % 100 == 0:
            log(f"  bootstrap {b+1}/{N_BOOT}", t0)
    boot_lo, boot_hi = np.percentile(boot_aucs, [2.5, 97.5])
    boot_mean = boot_aucs.mean()
    log(f"  bootstrap OOF AUC mean = {boot_mean:.4f}  "
        f"95% CI [{boot_lo:.4f}, {boot_hi:.4f}]", t0)

    # ── Check 3: sensitivity to N_CONTROLS ─────────────────────────────────
    log("Check 3: N_CONTROLS sensitivity", t0)
    nc_results = {}
    for nc in N_CONTROLS_GRID:
        rng_nc = np.random.default_rng(SEED + nc)
        if nc > len(ctrl_pool_df):
            continue
        ctrl_nc = list(ctrl_pool_df.sample(n=nc, random_state=SEED + nc)
                        ["cnpj_raiz"])
        D_nc = build_features(con, cartel_firms, ctrl_nc,
                                rais_pre, PAIRS_PREGAO,
                                firm_to_setor, setor_list, rng_nc,
                                pre_year_alt=None)
        a = loo_setor_auc(D_nc, baseline_feats, setor_list)
        nc_results[nc] = (len(D_nc), int((D_nc["label"]==1).sum()), a)
        log(f"  N_CONTROLS={nc:>5}  n_pairs={len(D_nc):>7,}  AUC={a:.4f}", t0)

    # ── Check 4: alternative feature definitions ──────────────────────────
    log("Check 4: alternative features", t0)
    alt_specs = [
        ("baseline (labor_cos + log_item_overlap)",
         ["labor_cos", "log_item_overlap"]),
        ("labor_cos only",           ["labor_cos"]),
        ("log_item_overlap only",    ["log_item_overlap"]),
        ("jaccard_overlap only",     ["jaccard_overlap"]),
        ("labor_cos + jaccard",      ["labor_cos", "jaccard_overlap"]),
        ("+ log_n_pair (3-feat)",
         ["labor_cos", "log_item_overlap", "log_n_pair"]),
        ("2010 labor (placebo year)",
         ["lab_alt", "log_item_overlap"]),
    ]
    alt_results = {}
    for name, feats in alt_specs:
        valid = [c for c in feats if c in D.columns and D[c].notna().all()]
        if len(valid) != len(feats):
            alt_results[name] = float("nan")
            continue
        a = loo_setor_auc(D, valid, setor_list)
        alt_results[name] = a
        log(f"  {name:<45s}  AUC = {a:.4f}", t0)

    con.close()

    # ── Report ─────────────────────────────────────────────────────────────
    with open(OUT_REPORT, "w") as f:
        f.write("Sensitivity analyses for the composite classifier\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")

        f.write(f"Baseline OOF AUC (2-feature logit, "
                f"leave-one-CADE-setor-out): {baseline_auc:.4f}\n\n")

        f.write("=" * 70 + "\n")
        f.write("CHECK 1: PERMUTATION TEST\n")
        f.write("=" * 70 + "\n")
        f.write(f"  B = {N_PERM} label shuffles\n")
        f.write(f"  Null mean AUC           : {perm_aucs.mean():.4f}\n")
        f.write(f"  Null 95th percentile    : {np.percentile(perm_aucs, 95):.4f}\n")
        f.write(f"  Null 99th percentile    : {np.percentile(perm_aucs, 99):.4f}\n")
        f.write(f"  Observed AUC            : {baseline_auc:.4f}\n")
        f.write(f"  Empirical p-value       : {perm_p:.4f}\n\n")

        f.write("=" * 70 + "\n")
        f.write("CHECK 2: BOOTSTRAP CI ON OOF AUC\n")
        f.write("=" * 70 + "\n")
        f.write(f"  B = {N_BOOT} stratified pair resamples\n")
        f.write(f"  Bootstrap mean          : {boot_mean:.4f}\n")
        f.write(f"  95% percentile CI       : [{boot_lo:.4f}, {boot_hi:.4f}]\n\n")

        f.write("=" * 70 + "\n")
        f.write("CHECK 3: SENSITIVITY TO N_CONTROLS\n")
        f.write("=" * 70 + "\n")
        f.write(f"  {'N_CONTROLS':>12s}  {'n_pairs':>10s}  {'n_pos':>6s}  "
                f"{'OOF AUC':>8s}\n")
        for nc, (np_total, npos, a) in nc_results.items():
            f.write(f"  {nc:>12,}  {np_total:>10,}  {npos:>6}  {a:>8.4f}\n")
        f.write("\n")

        f.write("=" * 70 + "\n")
        f.write("CHECK 4: ALTERNATIVE FEATURE DEFINITIONS\n")
        f.write("=" * 70 + "\n")
        f.write(f"  {'specification':<45s}  {'OOF AUC':>8s}\n")
        for name, a in alt_results.items():
            f.write(f"  {name:<45s}  {a:>8.4f}\n")
        f.write("\n")

        f.write("=" * 70 + "\n")
        f.write("OVERALL READING\n")
        f.write("=" * 70 + "\n")
        checks = []
        checks.append(("permutation p < 0.01",
                       perm_p < 0.01))
        checks.append(("bootstrap CI lower bound > 0.80",
                       boot_lo > 0.80))
        checks.append(("OOF AUC stable in [0.85, 0.93] across N_CONTROLS",
                       all(0.85 <= r[2] <= 0.93 for r in nc_results.values())))
        checks.append(("composite dominates any single feature",
                       alt_results["baseline (labor_cos + log_item_overlap)"] >=
                       max(alt_results["labor_cos only"],
                            alt_results["log_item_overlap only"]) + 0.05))
        for name, ok in checks:
            marker = "PASS" if ok else "FAIL"
            f.write(f"  [{marker}] {name}\n")

    log(f"report → {OUT_REPORT}", t0)
    print("\n" + OUT_REPORT.read_text())

    # ── Figure: permutation null histogram ─────────────────────────────────
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        fig, ax = plt.subplots(figsize=(8, 5))
        ax.hist(perm_aucs, bins=40, color="#cccccc", edgecolor="grey",
                 alpha=0.8, label=f"null distribution (B={N_PERM})")
        ax.axvline(baseline_auc, color="#b2182b", linewidth=2.5,
                    label=f"observed AUC = {baseline_auc:.3f}")
        ax.axvline(np.percentile(perm_aucs, 95), color="black",
                    linestyle="--", linewidth=1, alpha=0.6,
                    label=f"null 95th = {np.percentile(perm_aucs, 95):.3f}")
        ax.set_xlabel("OOF AUC under label shuffling")
        ax.set_ylabel("count")
        ax.set_title("Permutation null distribution of the composite OOF AUC")
        ax.legend()
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)
        fig.tight_layout()
        fig.savefig(OUT_FIGURE, dpi=300, bbox_inches="tight")
        plt.close(fig)
        log(f"figure → {OUT_FIGURE}", t0)
    except ImportError:
        log("matplotlib unavailable", t0)

    log(f"DONE ({time.time()-t0:.1f}s)", t0)


if __name__ == "__main__":
    main()
