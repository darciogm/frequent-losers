#!/usr/bin/env python3
"""
60_dose_response.py — Dose-response: fingerprint strength vs cartel age/size

For each of the six CADE cartels, compute:
  (i)   mean within-cartel labor cosine similarity
  (ii)  mean within-cartel log item overlap
  (iii) fold AUC from leave-one-setor-out composite
and report against the cartel's structural characteristics:
  - conduct duration (end_year - start_year)
  - number of BEC-active firms in the cartel
  - within-cartel n positive pairs
  - item scope (number of distinct items bid on by cartel firms)
  - cartel vintage (gap between 2009 pre-year and conduct end)

Goal: support the framework claim that structural fingerprints develop
over time. Hypothesis: longer-running, larger cartels exhibit stronger
composite signal than short, small ones.

This is illustrative with N=6 cartels; we report correlations as
Spearman rank and acknowledge the small-N limit.
"""
from __future__ import annotations
import time
from pathlib import Path
import numpy as np
import pandas as pd
import duckdb
from scipy.stats import mannwhitneyu, spearmanr

BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")
RAIS_DIR = BASE / "RAIS" / "parquet" / "harmonized"
FINAL = BASE / "02_data" / "final"
FIRMS = BASE / "02_data" / "firms"
INTER = BASE / "02_data" / "intermediate"

PAIRS_PREGAO = str(FINAL / "df_pregao_with_cartel_flags.parquet")
GROUND_TRUTH = str(FIRMS / "cade_ground_truth.parquet")

OUT = INTER / "dose_response.txt"
OUT_FIG = BASE / "04_figures" / "dose_response.pdf"

N_CONTROLS = 2000
SEED = 42


def log(msg, t0):
    print(f"[{time.time()-t0:6.1f}s] {msg}", flush=True)


def mw_auc(pos, neg):
    if len(pos) == 0 or len(neg) == 0:
        return float("nan")
    stat, _ = mannwhitneyu(pos, neg, alternative="greater")
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


def main():
    t0 = time.time()
    INTER.mkdir(parents=True, exist_ok=True)
    OUT_FIG.parent.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect()
    con.sql("PRAGMA threads=12; PRAGMA memory_limit='14GB'")
    rais_pre = str(RAIS_DIR / "rais_vinculos_2009.parquet")

    # 1. Cartels with metadata
    log("Step 1: cartels with metadata", t0)
    con.sql(f"""
        CREATE TABLE cf AS
        SELECT DISTINCT cnpj_raiz, setor,
               cartel_start_year::INT AS s_year,
               cartel_end_year::INT   AS e_year
        FROM read_parquet('{GROUND_TRUTH}')
        WHERE sp_relevant = 1 AND processo IS NOT NULL
          AND cartel_start_year IS NOT NULL
          AND cartel_end_year <= 2016
          AND in_bec = 1
    """)
    cf_df = con.sql("SELECT * FROM cf").fetchdf()
    setor_list = sorted(cf_df["setor"].unique())
    firm_to_setor = dict(zip(cf_df["cnpj_raiz"], cf_df["setor"]))

    # Cartel-level metadata
    cartel_meta = (cf_df.groupby("setor")
                   .agg(n_firms=("cnpj_raiz", "nunique"),
                        s_year=("s_year", "min"),
                        e_year=("e_year", "max"))
                   .reset_index())
    cartel_meta["duration"] = cartel_meta["e_year"] - cartel_meta["s_year"] + 1
    cartel_meta["vintage_2009"] = cartel_meta["e_year"] - 2009 + 1
    log(f"  cartel meta:\n{cartel_meta.to_string()}", t0)

    # 2. Controls
    ctrl_pool = con.sql(f"""
        SELECT DISTINCT cnpj_raiz FROM read_parquet('{PAIRS_PREGAO}')
        WHERE cnpj_raiz IS NOT NULL
          AND cnpj_raiz NOT IN (SELECT cnpj_raiz FROM cf)
    """).fetchdf()
    rng = np.random.default_rng(SEED)
    controls = list(ctrl_pool.sample(n=N_CONTROLS, random_state=SEED)["cnpj_raiz"])

    # 3. Build labor similarity + item maps
    log("Step 2: features", t0)
    firms_all = list(cf_df["cnpj_raiz"]) + controls
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

    # 4. Per-cartel within-cartel stats
    log("Step 3: per-cartel within-cartel feature means", t0)
    rows = []
    for s in setor_list:
        firms_s = cf_df[cf_df["setor"] == s]["cnpj_raiz"].tolist()
        pair_lcs = []
        pair_ovs = []
        n_pairs = 0
        for i in range(len(firms_s)):
            for j in range(i + 1, len(firms_s)):
                a, b = firms_s[i], firms_s[j]
                if a in firm_idx and b in firm_idx:
                    pair_lcs.append(float(sim[firm_idx[a], firm_idx[b]]))
                    ia = items_map.get(a, set())
                    ib = items_map.get(b, set())
                    pair_ovs.append(np.log1p(len(ia & ib)))
                    n_pairs += 1
        # Item scope: union of items bid on by cartel firms
        item_union = set()
        for f in firms_s:
            item_union |= items_map.get(f, set())
        rows.append({
            "setor": s,
            "n_firms_bec": len(firms_s),
            "n_pairs_with_emp": n_pairs,
            "item_scope": len(item_union),
            "mean_labor_cos": float(np.mean(pair_lcs)) if pair_lcs else np.nan,
            "mean_log_overlap": float(np.mean(pair_ovs)) if pair_ovs else np.nan,
        })
    cartel_features = pd.DataFrame(rows).merge(cartel_meta, on="setor")
    log(f"  cartel features:\n{cartel_features.to_string()}", t0)

    # 5. Per-fold composite AUC from leave-one-cartel-out (reuse 56 logic)
    log("Step 4: per-fold composite AUC (leave-one-out)", t0)
    positive_pairs = []
    for s in setor_list:
        firms_s = cf_df[cf_df["setor"] == s]["cnpj_raiz"].tolist()
        for i in range(len(firms_s)):
            for j in range(i + 1, len(firms_s)):
                positive_pairs.append((firms_s[i], firms_s[j], s, 1))

    max_neg = 100000
    neg_set = set()
    while len(neg_set) < max_neg:
        i = rng.integers(0, len(controls))
        j = rng.integers(0, len(controls))
        if i != j:
            neg_set.add(tuple(sorted([i, j])))
    negative_pairs = [(controls[i], controls[j], "_ctrl_", 0) for (i, j) in neg_set]

    data_rows = []
    for (a, b, tag, y) in positive_pairs + negative_pairs:
        if a not in firm_idx or b not in firm_idx:
            continue
        ia = items_map.get(a, set())
        ib = items_map.get(b, set())
        data_rows.append({
            "tag": tag, "label": y,
            "labor_cos": float(sim[firm_idx[a], firm_idx[b]]),
            "log_item_overlap": np.log1p(len(ia & ib)),
        })
    D = pd.DataFrame(data_rows)
    n_pos = int((D["label"] == 1).sum())
    log(f"  D rows: {len(D):,}  positives: {n_pos}", t0)

    fold_aucs = {}
    X_all = D[["labor_cos", "log_item_overlap"]].values
    y_all = D["label"].values
    for s in setor_list:
        train_mask = ~((D["label"] == 1) & (D["tag"] == s))
        eval_mask = ((D["label"] == 1) & (D["tag"] == s)) | (D["label"] == 0)
        n_test_pos = int(((D["label"] == 1) & (D["tag"] == s)).sum())
        if n_test_pos == 0:
            fold_aucs[s] = float("nan")
            continue
        X_tr = X_all[train_mask.values]
        y_tr = y_all[train_mask.values]
        X_ev = X_all[eval_mask.values]
        w, mu, sd = fit_logistic(X_tr, y_tr)
        scores = predict(w, X_ev, mu, sd)
        y_ev = y_all[eval_mask.values]
        fold_aucs[s] = mw_auc(scores[y_ev == 1], scores[y_ev == 0])

    cartel_features["fold_auc"] = cartel_features["setor"].map(fold_aucs)
    log(f"  final cartel features:\n{cartel_features.to_string()}", t0)

    # 6. Spearman correlations with fold_auc (excluding nan)
    log("Step 5: Spearman correlations", t0)
    cf_use = cartel_features.dropna(subset=["fold_auc"])
    correlations = {}
    for col in ["duration", "n_firms_bec", "item_scope", "vintage_2009",
                "mean_labor_cos", "mean_log_overlap"]:
        rho, p = spearmanr(cf_use[col], cf_use["fold_auc"])
        correlations[col] = (float(rho), float(p))
        log(f"  ρ({col:<18s} → fold_auc) = {rho:+.3f}  p = {p:.3f}", t0)

    # 7. Report
    with open(OUT, "w") as f:
        f.write("Dose-response: fingerprint strength vs cartel characteristics\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")

        f.write("DESIGN\n")
        f.write("-" * 50 + "\n")
        f.write("  Per-cartel statistics + leave-one-out composite fold AUC.\n")
        f.write("  N = 6 cartels; correlations are Spearman rank, illustrative.\n\n")

        f.write("CARTEL-LEVEL TABLE\n")
        f.write("-" * 50 + "\n")
        cols = ["setor", "n_firms_bec", "duration", "n_pairs_with_emp",
                "item_scope", "mean_labor_cos", "mean_log_overlap", "fold_auc"]
        f.write(cartel_features[cols].to_string(index=False,
                                                  float_format="%.3f"))
        f.write("\n\n")

        f.write("SPEARMAN CORRELATIONS WITH fold_auc\n")
        f.write("-" * 50 + "\n")
        for col, (rho, p) in correlations.items():
            f.write(f"  {col:<20s}  ρ = {rho:+.3f}  (p = {p:.3f})\n")
        f.write("\n")

        f.write("INTERPRETATION\n")
        f.write("-" * 50 + "\n")
        f.write("  Framework prediction: duration, n_firms, and item_scope should\n")
        f.write("  positively predict fold_auc because structural fingerprints\n")
        f.write("  develop over time. Mean within-cartel labor similarity and\n")
        f.write("  log overlap are direct measures of how 'fingerprinted' the\n")
        f.write("  cartel is. Significant positive rank correlations support the\n")
        f.write("  framework; null rank correlations with N=6 are underpowered\n")
        f.write("  but the pattern should go in the predicted direction.\n")

    log(f"report → {OUT}", t0)
    print("\n" + OUT.read_text())

    # 8. Figure
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        fig, axes = plt.subplots(1, 2, figsize=(11, 5))

        for ax, col, label in [
            (axes[0], "duration", "conduct duration (years)"),
            (axes[1], "n_firms_bec", "cartel size (firms in BEC)"),
        ]:
            x = cf_use[col].values
            y = cf_use["fold_auc"].values
            ax.scatter(x, y, s=80, color="#2166ac")
            for _, row in cf_use.iterrows():
                ax.annotate(row["setor"][:15],
                             (row[col], row["fold_auc"]),
                             xytext=(5, 3), textcoords="offset points",
                             fontsize=7)
            ax.set_xlabel(label)
            ax.set_ylabel("leave-one-out fold AUC")
            ax.axhline(0.5, color="grey", linestyle="--", linewidth=0.8)
            ax.spines["top"].set_visible(False)
            ax.spines["right"].set_visible(False)
            rho, p = correlations[col]
            ax.set_title(f"{label}\n  ρ = {rho:+.2f}  p = {p:.2f}")

        fig.tight_layout()
        fig.savefig(OUT_FIG, dpi=300, bbox_inches="tight")
        plt.close(fig)
        log(f"figure → {OUT_FIG}", t0)
    except ImportError:
        log("matplotlib unavailable", t0)

    log(f"DONE ({time.time()-t0:.1f}s)", t0)


if __name__ == "__main__":
    main()
