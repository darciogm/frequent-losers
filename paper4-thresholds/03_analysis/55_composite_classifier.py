#!/usr/bin/env python3
"""
55_composite_classifier.py — Composite cartel-screen classifier

Builds a pair-level detection classifier that combines three orthogonal
fingerprints:

  (A) Labor-network proximity: cosine similarity of 2009 CBO × municipio
      employment vectors between firms i and j.
  (B) Cover-bid cooccurrence: n_pair(i, j) = raw count of (i = winner,
      j = runner-up) events in BEC auctions.
  (C) Cover-bid conditional: q(i, j) = n_pair(i, j) / n_wins(i).

Unit of analysis: ORDERED firm pairs (i, j) that appear at least once as
(winner, runner-up). Label: 1 if both firms are in the same CADE-convicted
setor (positive); 0 if neither firm is in any CADE cartel (negative);
"mixed" pairs are excluded.

Validation: leave-one-setor-out cross-validation (6 folds, one per
convicted setor) to prevent within-cartel leakage. Report AUC of each
feature alone and of the logistic composite.

Decision rule:
  STRONG  combined AUC ≥ 0.85 (clear RAND paper)
  GOOD    combined AUC in [0.75, 0.85) (strong field paper; RAND plausible)
  WEAK    combined AUC < 0.75 (redesign)
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

OUT_REPORT = INTER / "composite_classifier.txt"
OUT_FIGURE = BASE / "04_figures" / "composite_roc.pdf"

MIN_WINS = 5   # min wins for a firm to be a "winner" (pair source)
SEED     = 42


def log(msg, t0):
    print(f"[{time.time()-t0:6.1f}s] {msg}", flush=True)


def compute_auc(scores, labels):
    """AUC via Mann-Whitney U, with positive-rank convention."""
    pos = scores[labels == 1]
    neg = scores[labels == 0]
    if len(pos) == 0 or len(neg) == 0:
        return float("nan")
    stat, _ = mannwhitneyu(pos, neg, alternative="greater")
    return float(stat / (len(pos) * len(neg)))


def fit_logistic(X, y, max_iter=200, lr=0.1, l2=0.01):
    """Minimal logistic regression with L2 penalty.

    Returns coefs array (including intercept) and classification scores.
    Features X should be standardized; we do it inside.
    """
    n, k = X.shape
    mu = X.mean(axis=0)
    sd = X.std(axis=0) + 1e-10
    Xn = (X - mu) / sd
    Xn = np.column_stack([np.ones(n), Xn])
    w = np.zeros(k + 1)
    for _ in range(max_iter):
        z = Xn @ w
        p = 1 / (1 + np.exp(-np.clip(z, -30, 30)))
        grad = Xn.T @ (p - y) / n + l2 * np.r_[0, w[1:]]
        w -= lr * grad
    # Predict scores on Xn
    scores = Xn @ w
    return w, scores, mu, sd


def predict_logistic(w, X, mu, sd):
    Xn = (X - mu) / sd
    Xn = np.column_stack([np.ones(len(X)), Xn])
    return Xn @ w


def main():
    t0 = time.time()
    INTER.mkdir(parents=True, exist_ok=True)
    OUT_FIGURE.parent.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect()
    con.sql("PRAGMA threads=12; PRAGMA memory_limit='14GB'")

    rais_glob = str(RAIS_DIR / "rais_vinculos_*.parquet")
    rais_pre  = str(RAIS_DIR / "rais_vinculos_2009.parquet")

    # ── 1. Cartel ground truth ───────────────────────────────────────────────
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
    cartel_set = set(cf_df["cnpj_raiz"])
    setor_list = sorted(cf_df["setor"].unique())
    log(f"  cartel firms: {len(cf_df)}, setores: {len(setor_list)}", t0)

    # ── 2. Build Q (winner → runner-up pair counts) ─────────────────────────
    log("Step 2: Q matrix", t0)
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
        SELECT a.auction_item, a.year, a.firm AS winner, b.firm AS runner_up
        FROM ranked a JOIN ranked b ON a.auction_item = b.auction_item
        WHERE a.rnk = 1 AND b.rnk = 2 AND a.firm != b.firm
    """)
    con.sql("""
        CREATE TABLE wins AS
        SELECT winner, COUNT(*) AS n_wins FROM wr GROUP BY winner
    """)
    con.sql(f"""
        CREATE TABLE Q AS
        SELECT p.winner, p.runner_up, p.n_pair, w.n_wins,
               p.n_pair::DOUBLE / w.n_wins::DOUBLE AS q
        FROM (SELECT winner, runner_up, COUNT(*) AS n_pair
              FROM wr GROUP BY winner, runner_up) p
        JOIN wins w USING (winner)
        WHERE w.n_wins >= {MIN_WINS}
    """)
    Q_df = con.sql("SELECT * FROM Q").fetchdf()
    log(f"  Q rows: {len(Q_df):,}", t0)

    # ── 3. Labor-network cosine similarity on active firms ─────────────────
    log("Step 3: labor cosine similarity", t0)
    active_firms = set(Q_df["winner"]) | set(Q_df["runner_up"])
    # Restrict to firms we can check in RAIS 2009
    firm_list_sql = ",".join(f"'{f}'" for f in active_firms)
    con.sql(f"""
        CREATE TABLE emp AS
        SELECT cnpj_raiz AS firm, cbo2002::VARCHAR AS cbo,
               mun_estab::VARCHAR AS mun, COUNT(*) AS n
        FROM read_parquet('{rais_pre}')
        WHERE cnpj_raiz IN ({firm_list_sql})
          AND cbo2002 IS NOT NULL AND mun_estab IS NOT NULL
        GROUP BY firm, cbo, mun
    """)
    emp = con.sql("SELECT * FROM emp").fetchdf()
    log(f"  emp rows: {len(emp):,}, firms with 2009 data: "
        f"{emp['firm'].nunique()}", t0)

    emp["cell"] = emp["cbo"].astype(str) + "|" + emp["mun"].astype(str)
    mat = emp.pivot_table(index="firm", columns="cell", values="n",
                          fill_value=0, aggfunc="sum").astype(float)
    firms_with_emp = mat.index.tolist()
    firm_idx = {f: i for i, f in enumerate(firms_with_emp)}
    mat_vals = mat.values
    norms = np.linalg.norm(mat_vals, axis=1, keepdims=True)
    mat_n = mat_vals / np.where(norms > 0, norms, 1)

    def cosine(i_firm, j_firm):
        ii = firm_idx.get(i_firm)
        jj = firm_idx.get(j_firm)
        if ii is None or jj is None:
            return np.nan
        return float(mat_n[ii] @ mat_n[jj])

    # Apply
    log("  applying cosine to Q rows", t0)
    Q_df["labor_cos"] = [
        cosine(w, r) for w, r in zip(Q_df["winner"].values, Q_df["runner_up"].values)
    ]
    n_with_labor = Q_df["labor_cos"].notna().sum()
    log(f"  pairs with labor_cos: {n_with_labor:,} / {len(Q_df):,}", t0)

    # ── 4. Labels (positive = same setor cartel, negative = ctrl-ctrl) ──────
    Q_df["winner_in_cartel"] = Q_df["winner"].isin(cartel_set)
    Q_df["runner_in_cartel"] = Q_df["runner_up"].isin(cartel_set)
    Q_df["winner_setor"]  = Q_df["winner"].map(firm_to_setor)
    Q_df["runner_setor"]  = Q_df["runner_up"].map(firm_to_setor)
    Q_df["label"] = 0
    same_cartel = (
        Q_df["winner_in_cartel"] & Q_df["runner_in_cartel"]
        & (Q_df["winner_setor"] == Q_df["runner_setor"])
    )
    ctrl_ctrl = (~Q_df["winner_in_cartel"]) & (~Q_df["runner_in_cartel"])
    Q_df.loc[same_cartel, "label"] = 1
    Q_df.loc[~(same_cartel | ctrl_ctrl), "label"] = -1  # mark mixed

    # Drop mixed and missing-labor
    D = Q_df[(Q_df["label"] >= 0) & Q_df["labor_cos"].notna()].copy()
    log(f"  training frame: {len(D):,} "
        f"(pos {int((D['label']==1).sum())}, "
        f"neg {int((D['label']==0).sum())})", t0)

    # ── 5. Single-feature AUCs ──────────────────────────────────────────────
    log("Step 5: single-feature AUCs", t0)
    y = D["label"].values
    feats = {
        "labor_cos":     D["labor_cos"].values,
        "n_pair":        D["n_pair"].values,
        "q":             D["q"].values,
        "log_n_pair":    np.log1p(D["n_pair"].values),
    }
    single = {name: compute_auc(v, y) for name, v in feats.items()}
    for name, auc in single.items():
        log(f"  {name:<15s} AUC = {auc:.4f}", t0)

    # ── 6. Composite logistic regression with leave-one-setor-out CV ────────
    log("Step 6: leave-one-setor-out CV", t0)
    # Each positive pair has a setor; rotate through the 6 setores
    D["fold_setor"] = D["winner_setor"].where(D["label"] == 1, other="_neg_")
    X_all = np.column_stack([
        D["labor_cos"].values,
        np.log1p(D["n_pair"].values),
        D["q"].values,
    ])
    n_folds = len(setor_list)
    oof_scores = np.full(len(D), np.nan)

    for s in setor_list:
        # Train: all negatives + all positives from OTHER setores
        train_mask = (
            ((D["label"] == 0)) |
            ((D["label"] == 1) & (D["winner_setor"] != s))
        )
        test_mask = (
            (D["label"] == 1) & (D["winner_setor"] == s)
        )
        # For AUC we also want to score the negatives; include all negatives
        # in test eval, the "positives" of this fold, and hold out rest
        test_eval = test_mask | (D["label"] == 0)

        X_tr = X_all[train_mask.values]
        y_tr = D.loc[train_mask, "label"].values
        X_te = X_all[test_eval.values]

        w, _, mu, sd = fit_logistic(X_tr, y_tr)
        scores = predict_logistic(w, X_te, mu, sd)
        oof_scores[test_eval.values] = scores
        # Metrics for this fold
        y_te = D.loc[test_eval, "label"].values
        fold_auc = compute_auc(scores, y_te)
        n_pos_fold = int(test_mask.sum())
        log(f"  fold {s}: n_pos={n_pos_fold}, fold AUC = {fold_auc:.4f}", t0)

    # Overall OOF AUC
    oof_mask = ~np.isnan(oof_scores)
    auc_oof = compute_auc(oof_scores[oof_mask], y[oof_mask])
    log(f"  overall leave-one-setor-out AUC = {auc_oof:.4f}", t0)

    # In-sample composite (for reference)
    w_full, scores_full, mu_full, sd_full = fit_logistic(X_all, y)
    auc_insample = compute_auc(scores_full, y)
    log(f"  in-sample composite AUC = {auc_insample:.4f}", t0)

    con.close()

    # ── 7. Report ───────────────────────────────────────────────────────────
    with open(OUT_REPORT, "w") as f:
        f.write("Composite cartel-screen classifier\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")

        f.write("DATA\n")
        f.write("-" * 50 + "\n")
        f.write(f"  Pair universe (winner ≥ {MIN_WINS} wins): {len(Q_df):,}\n")
        f.write(f"  After labor_cos requirement: {n_with_labor:,}\n")
        f.write(f"  Positive pairs (same cartel setor): "
                f"{int((D['label']==1).sum())}\n")
        f.write(f"  Negative pairs (ctrl × ctrl):       "
                f"{int((D['label']==0).sum()):,}\n")
        f.write(f"  Setores for CV: {', '.join(setor_list)}\n\n")

        f.write("SINGLE-FEATURE AUC\n")
        f.write("-" * 50 + "\n")
        for name, auc in single.items():
            f.write(f"  {name:<15s} AUC = {auc:.4f}\n")
        f.write("\n")

        f.write("LEAVE-ONE-SETOR-OUT COMPOSITE\n")
        f.write("-" * 50 + "\n")
        f.write(f"  Features: [labor_cos, log(1+n_pair), q]\n")
        f.write(f"  OOF AUC (held-out setor positives vs all negatives): "
                f"{auc_oof:.4f}\n")
        f.write(f"  In-sample composite AUC: {auc_insample:.4f}\n\n")

        f.write("LOGISTIC COEFFICIENTS (in-sample, standardized)\n")
        f.write("-" * 50 + "\n")
        names = ["intercept", "labor_cos", "log(1+n_pair)", "q"]
        for n, coef in zip(names, w_full):
            f.write(f"  {n:<20s}: {coef:+.4f}\n")
        f.write("\n")

        # Decision
        if auc_oof >= 0.85:
            verdict = "✓ STRONG: OOF AUC ≥ 0.85"
        elif auc_oof >= 0.75:
            verdict = "△ GOOD: 0.75 ≤ OOF AUC < 0.85"
        else:
            verdict = "✗ WEAK: OOF AUC < 0.75"

        f.write("DECISION\n")
        f.write("-" * 50 + "\n")
        f.write(f"  Leave-one-setor-out AUC = {auc_oof:.4f}\n")
        f.write(f"  Verdict: {verdict}\n")

    log(f"report → {OUT_REPORT}", t0)
    print("\n" + OUT_REPORT.read_text())

    # ── 8. ROC figure ──────────────────────────────────────────────────────
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        def roc_curve(scores, labels):
            order = np.argsort(-scores)
            y_sorted = labels[order]
            tps = np.cumsum(y_sorted == 1)
            fps = np.cumsum(y_sorted == 0)
            n_pos = max(int((labels == 1).sum()), 1)
            n_neg = max(int((labels == 0).sum()), 1)
            return fps / n_neg, tps / n_pos

        fig, ax = plt.subplots(figsize=(7, 6))
        for name, arr in feats.items():
            fpr, tpr = roc_curve(arr, y)
            ax.plot(fpr, tpr, label=f"{name} (AUC={single[name]:.3f})",
                    alpha=0.6)
        fpr_c, tpr_c = roc_curve(scores_full, y)
        ax.plot(fpr_c, tpr_c, label=f"composite (AUC={auc_insample:.3f})",
                linewidth=2.5, color="black")
        ax.plot([0, 1], [0, 1], "--", color="grey", linewidth=0.8)
        ax.set_xlabel("False positive rate")
        ax.set_ylabel("True positive rate")
        ax.set_title("Composite cartel-screen ROC (in-sample)")
        ax.legend(loc="lower right", fontsize=9)
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)
        fig.tight_layout()
        fig.savefig(OUT_FIGURE, dpi=300, bbox_inches="tight")
        plt.close(fig)
        log(f"figure → {OUT_FIGURE}", t0)
    except ImportError:
        log("matplotlib unavailable; skipping figure", t0)

    log(f"DONE ({time.time()-t0:.1f}s)", t0)


if __name__ == "__main__":
    main()
