#!/usr/bin/env python3
"""
56_composite_v2.py — Composite cartel-screen classifier (revised)

Builds a pair-level classifier with three orthogonal features:

  (A) labor_cos(i, j): 2009 cosine similarity in CBO × municipio space
  (B) n_pair_sym(i, j): # of BEC pregão auctions where (i, j) or (j, i)
                         appears as (winner, runner-up); 0 if never
  (C) item_overlap(i, j): # of distinct BEC items where both i and j bid
                           at least once

Pair universe (unordered pairs {i, j}):
  • All ordered cartel × cartel pairs (both in same CADE setor) as the
    positive class: 6 cartels × C(n_c, 2) pairs each
  • Sampled control × control pairs: 5000 randomly drawn non-cartel
    BEC-active firms, all C(5000, 2) pairs

Validation: leave-one-setor-out on positives.

Key fix relative to 55: do NOT require both firms to appear in Q with
high n_wins. Cartel firms are often losers, not winners — the restriction
in 55 killed the positive sample. Here we treat n_pair as a feature that
can be 0.
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

OUT_REPORT = INTER / "composite_v2.txt"
OUT_FIGURE = BASE / "04_figures" / "composite_v2_roc.pdf"

N_CONTROLS = 2000
SEED       = 42


def log(msg, t0):
    print(f"[{time.time()-t0:6.1f}s] {msg}", flush=True)


def mw_auc(pos, neg, alternative="greater"):
    if len(pos) == 0 or len(neg) == 0:
        return float("nan")
    stat, _ = mannwhitneyu(pos, neg, alternative=alternative)
    return float(stat / (len(pos) * len(neg)))


def fit_logistic(X, y, max_iter=500, lr=0.5, l2=0.001, class_weight=None):
    """Logistic with L2 and optional class balancing.

    class_weight: dict {0: w_neg, 1: w_pos} or "balanced" to auto-balance.
    Features standardized inside; returns (w, mu, sd).
    """
    n, k = X.shape
    mu = X.mean(axis=0)
    sd = X.std(axis=0) + 1e-10
    Xn = np.column_stack([np.ones(n), (X - mu) / sd])
    if class_weight == "balanced":
        w_pos = n / (2 * max((y == 1).sum(), 1))
        w_neg = n / (2 * max((y == 0).sum(), 1))
        sw = np.where(y == 1, w_pos, w_neg)
    elif isinstance(class_weight, dict):
        sw = np.where(y == 1, class_weight.get(1, 1.0), class_weight.get(0, 1.0))
    else:
        sw = np.ones(n)
    w = np.zeros(k + 1)
    for _ in range(max_iter):
        z = Xn @ w
        p = 1 / (1 + np.exp(-np.clip(z, -30, 30)))
        grad = (Xn * sw[:, None]).T @ (p - y) / sw.sum() + l2 * np.r_[0, w[1:]]
        w -= lr * grad
    return w, mu, sd


def predict_logistic(w, X, mu, sd):
    Xn = np.column_stack([np.ones(len(X)), (X - mu) / sd])
    return Xn @ w


def main():
    t0 = time.time()
    INTER.mkdir(parents=True, exist_ok=True)
    OUT_FIGURE.parent.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect()
    con.sql("PRAGMA threads=12; PRAGMA memory_limit='14GB'")
    rais_pre = str(RAIS_DIR / "rais_vinculos_2009.parquet")

    # ── 1. Cartels ───────────────────────────────────────────────────────────
    log("Step 1: cartels", t0)
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
    log(f"  cartel firms: {len(cf_df)}, setores: {len(setor_list)}", t0)

    # ── 2. BEC-active control firms ─────────────────────────────────────────
    log("Step 2: sampling control firms", t0)
    con.sql(f"""
        CREATE TABLE bec_control_pool AS
        SELECT DISTINCT cnpj_raiz
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE cnpj_raiz IS NOT NULL
          AND cnpj_raiz NOT IN (SELECT cnpj_raiz FROM cf)
    """)
    ctrl_pool = con.sql("SELECT cnpj_raiz FROM bec_control_pool").fetchdf()
    rng = np.random.default_rng(SEED)
    ctrl_idx = rng.choice(len(ctrl_pool), size=min(N_CONTROLS, len(ctrl_pool)),
                           replace=False)
    controls = list(ctrl_pool.iloc[ctrl_idx]["cnpj_raiz"])
    log(f"  controls sampled: {len(controls)} "
        f"(pool size: {len(ctrl_pool):,})", t0)

    # ── 3. 2009 CBO × mun vectors for cartel + controls ────────────────────
    log("Step 3: 2009 employment vectors", t0)
    firms_all = cartel_firms + controls
    fs_sql = ",".join(f"'{f}'" for f in firms_all)
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
    log(f"  firms × cells matrix: {mat.shape}", t0)
    firms_with_emp = list(mat.index)
    firm_idx = {f: i for i, f in enumerate(firms_with_emp)}
    mat_vals = mat.values
    norms = np.linalg.norm(mat_vals, axis=1, keepdims=True)
    mat_n = mat_vals / np.where(norms > 0, norms, 1)
    # Precompute cosine matrix (dense, small — ~2000 × 2000)
    sim = mat_n @ mat_n.T
    log(f"  similarity matrix: {sim.shape}", t0)

    # ── 4. Build Q (winner, runner-up pair counts) ──────────────────────────
    log("Step 4: Q matrix", t0)
    con.sql(f"""
        CREATE TABLE ranked AS
        SELECT auction_item, year, cnpj_raiz AS firm, valorunitárioproposta AS bid,
               ROW_NUMBER() OVER (PARTITION BY auction_item
                                   ORDER BY valorunitárioproposta ASC) AS rnk
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE cnpj_raiz IS NOT NULL
          AND valorunitárioproposta > 0
          AND valorunitárioproposta < 1e9
    """)
    con.sql("""
        CREATE TABLE wr AS
        SELECT a.firm AS winner, b.firm AS runner_up,
               COUNT(*) AS n_pair
        FROM ranked a JOIN ranked b
          ON a.auction_item = b.auction_item
        WHERE a.rnk = 1 AND b.rnk = 2 AND a.firm != b.firm
        GROUP BY a.firm, b.firm
    """)
    wr = con.sql("SELECT * FROM wr").fetchdf()
    # Build symmetric n_pair: sum over both orientations
    n_pair_sym = {}
    for _, row in wr.iterrows():
        key = tuple(sorted([row["winner"], row["runner_up"]]))
        n_pair_sym[key] = n_pair_sym.get(key, 0) + row["n_pair"]
    log(f"  Q pairs: {len(wr):,}, unordered pairs: {len(n_pair_sym):,}", t0)

    # ── 5. Item overlap: #items where both firms bid at least once ──────────
    log("Step 5: item overlap", t0)
    # For each firm in our universe, the set of items bid on
    firms_sql = ",".join(f"'{f}'" for f in firms_all)
    items_per_firm = con.sql(f"""
        SELECT cnpj_raiz AS firm, "códigoitem" AS item
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE cnpj_raiz IN ({firms_sql})
        GROUP BY firm, item
    """).fetchdf()
    items_map = {}
    for f, sub in items_per_firm.groupby("firm"):
        items_map[f] = set(sub["item"].values)
    log(f"  firms with BEC items: {len(items_map):,}", t0)

    con.close()

    # ── 6. Build pair-level feature table ──────────────────────────────────
    log("Step 6: pair features", t0)
    # Positive pairs: all ordered pairs within the same cartel setor
    # (unordered — we compute symmetric features)
    positive_pairs = []
    for s in setor_list:
        firms_s = cf_df[cf_df["setor"] == s]["cnpj_raiz"].tolist()
        for i in range(len(firms_s)):
            for j in range(i + 1, len(firms_s)):
                a, b = firms_s[i], firms_s[j]
                positive_pairs.append((a, b, s, 1))
    log(f"  positive pairs: {len(positive_pairs):,}", t0)

    # Negative pairs: all unordered pairs of control firms (subsample if huge)
    n_c = len(controls)
    negative_pairs = []
    # Sample negative pairs to keep manageable
    max_neg = 100000
    if n_c * (n_c - 1) // 2 > max_neg:
        # Random ordered pair sample
        idxs = set()
        while len(idxs) < max_neg:
            i = rng.integers(0, n_c)
            j = rng.integers(0, n_c)
            if i != j:
                idxs.add(tuple(sorted([i, j])))
        for i, j in idxs:
            negative_pairs.append((controls[i], controls[j], "_ctrl_", 0))
    else:
        for i in range(n_c):
            for j in range(i + 1, n_c):
                negative_pairs.append((controls[i], controls[j], "_ctrl_", 0))
    log(f"  negative pairs: {len(negative_pairs):,}", t0)

    all_pairs = positive_pairs + negative_pairs
    rows = []
    skipped_no_emp = 0
    for (a, b, tag, y) in all_pairs:
        if a not in firm_idx or b not in firm_idx:
            skipped_no_emp += 1
            continue
        lc = float(sim[firm_idx[a], firm_idx[b]])
        key = tuple(sorted([a, b]))
        npair = int(n_pair_sym.get(key, 0))
        ia = items_map.get(a, set())
        ib = items_map.get(b, set())
        item_ov = len(ia & ib)
        rows.append({
            "a": a, "b": b, "tag": tag, "label": y,
            "labor_cos": lc,
            "n_pair_sym": npair,
            "log_n_pair": np.log1p(npair),
            "item_overlap": item_ov,
            "log_item_overlap": np.log1p(item_ov),
        })
    D = pd.DataFrame(rows)
    log(f"  training frame: {len(D):,} (pos {int((D['label']==1).sum())}, "
        f"neg {int((D['label']==0).sum()):,}, skipped {skipped_no_emp})", t0)

    # ── 7. Single-feature AUCs ──────────────────────────────────────────────
    log("Step 7: single-feature AUCs", t0)
    y = D["label"].values
    feat_names = ["labor_cos", "log_n_pair", "log_item_overlap"]
    single = {}
    for name in feat_names:
        auc = mw_auc(D[D["label"] == 1][name].values,
                     D[D["label"] == 0][name].values,
                     alternative="greater")
        single[name] = auc
        log(f"  {name:<20s} AUC = {auc:.4f}", t0)

    # ── 8. Leave-one-setor-out CV composite ─────────────────────────────────
    log("Step 8: leave-one-setor-out CV", t0)
    X_all = D[feat_names].values
    oof = np.full(len(D), np.nan)
    fold_aucs = {}
    for s in setor_list:
        train_mask = ~((D["label"] == 1) & (D["tag"] == s))
        test_mask = (D["label"] == 1) & (D["tag"] == s)
        eval_mask = test_mask | (D["label"] == 0)
        X_tr = X_all[train_mask.values]
        y_tr = D.loc[train_mask, "label"].values
        X_ev = X_all[eval_mask.values]
        w, mu, sd = fit_logistic(X_tr, y_tr, class_weight="balanced",
                                  max_iter=500)
        scores = predict_logistic(w, X_ev, mu, sd)
        oof[eval_mask.values] = scores
        y_ev = D.loc[eval_mask, "label"].values
        fold_auc = mw_auc(scores[y_ev == 1], scores[y_ev == 0],
                          alternative="greater")
        fold_aucs[s] = (int(test_mask.sum()), fold_auc)
        log(f"  fold {s:<25s}  n_pos={int(test_mask.sum()):>3}  "
            f"AUC = {fold_auc:.4f}", t0)

    mask = ~np.isnan(oof)
    oof_auc = mw_auc(oof[mask][y[mask] == 1], oof[mask][y[mask] == 0],
                     alternative="greater")
    log(f"  overall OOF AUC = {oof_auc:.4f}", t0)

    # In-sample composite
    w_full, mu_full, sd_full = fit_logistic(X_all, y, class_weight="balanced",
                                              max_iter=500)
    scores_is = predict_logistic(w_full, X_all, mu_full, sd_full)
    auc_is = mw_auc(scores_is[y == 1], scores_is[y == 0], alternative="greater")
    log(f"  in-sample composite AUC = {auc_is:.4f}", t0)

    # ── 9. Report ───────────────────────────────────────────────────────────
    with open(OUT_REPORT, "w") as f:
        f.write("Composite cartel-screen classifier (v2)\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")

        f.write("DESIGN\n")
        f.write("-" * 50 + "\n")
        f.write("  Unit: unordered firm pairs {i, j}.\n")
        f.write("  Positive class: both firms in the same CADE setor.\n")
        f.write("  Negative class: sampled pairs of BEC-active non-cartel firms.\n")
        f.write("  Features:\n")
        f.write("    labor_cos        — cosine sim of 2009 CBO × mun vectors\n")
        f.write("    log_n_pair       — ln(1 + #(winner,runner-up) events)\n")
        f.write("    log_item_overlap — ln(1 + #items both firms bid on)\n")
        f.write("  Validation: leave-one-CADE-setor-out (6 folds).\n\n")

        f.write("SAMPLE\n")
        f.write("-" * 50 + "\n")
        f.write(f"  Cartel firms:    {len(cf_df)}\n")
        f.write(f"  Control firms:   {len(controls):,}\n")
        f.write(f"  Pairs total:     {len(D):,}\n")
        f.write(f"    positive: {int((D['label']==1).sum())}\n")
        f.write(f"    negative: {int((D['label']==0).sum()):,}\n\n")

        f.write("SINGLE-FEATURE AUC\n")
        f.write("-" * 50 + "\n")
        for name in feat_names:
            f.write(f"  {name:<20s} AUC = {single[name]:.4f}\n")
        f.write("\n")

        f.write("LEAVE-ONE-SETOR-OUT FOLDS\n")
        f.write("-" * 50 + "\n")
        for s, (n_p, auc) in fold_aucs.items():
            f.write(f"  {s:<25s}  n_pos = {n_p:>3}   AUC = {auc:.4f}\n")
        f.write(f"\n  Overall OOF AUC  = {oof_auc:.4f}\n")
        f.write(f"  In-sample AUC    = {auc_is:.4f}\n\n")

        f.write("LOGISTIC COEFFICIENTS (in-sample, standardized)\n")
        f.write("-" * 50 + "\n")
        names = ["intercept"] + feat_names
        for n, c in zip(names, w_full):
            f.write(f"  {n:<20s}: {c:+.4f}\n")
        f.write("\n")

        if oof_auc >= 0.85:
            v = "✓ STRONG: OOF AUC ≥ 0.85 — clear RAND paper"
        elif oof_auc >= 0.75:
            v = "△ GOOD: 0.75 ≤ OOF AUC < 0.85 — field paper, RAND plausible"
        else:
            v = "✗ WEAK: OOF AUC < 0.75 — redesign needed"
        f.write(f"DECISION: {v}\n")

    log(f"report → {OUT_REPORT}", t0)
    print("\n" + OUT_REPORT.read_text())

    # ── 10. ROC figure ─────────────────────────────────────────────────────
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        def roc(scores, labels):
            order = np.argsort(-scores)
            yy = labels[order]
            tps = np.cumsum(yy == 1)
            fps = np.cumsum(yy == 0)
            return fps / max((labels == 0).sum(), 1), tps / max((labels == 1).sum(), 1)

        fig, ax = plt.subplots(figsize=(7, 6))
        for n in feat_names:
            fpr, tpr = roc(D[n].values, y)
            ax.plot(fpr, tpr, alpha=0.55, label=f"{n} (AUC={single[n]:.3f})")
        fpr, tpr = roc(scores_is, y)
        ax.plot(fpr, tpr, color="black", linewidth=2.5,
                label=f"composite IS (AUC={auc_is:.3f})")
        if mask.sum() > 0:
            oof_scores = oof[mask]
            y_oof = y[mask]
            fpr_o, tpr_o = roc(oof_scores, y_oof)
            ax.plot(fpr_o, tpr_o, color="#b2182b", linewidth=2, linestyle="--",
                    label=f"composite OOF (AUC={oof_auc:.3f})")
        ax.plot([0, 1], [0, 1], "--", color="grey", linewidth=0.8)
        ax.set_xlabel("False positive rate")
        ax.set_ylabel("True positive rate")
        ax.set_title("Composite cartel-screen ROC (v2)")
        ax.legend(loc="lower right", fontsize=9)
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
