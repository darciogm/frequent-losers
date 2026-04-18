#!/usr/bin/env python3
"""
62_phase2_labor_reop.py — Phase 2: labor-feature re-operationalization

After Phase 1 (script 61) established that raw labor_cos_2009 does not
generalize cross-cartel (LOO pooled 0.528, macro 0.615) and that its
incremental contribution to the composite is not statistically
distinguishable from zero, this script tests three re-operationalizations
of labor-network proximity to see whether any restores the two-fingerprint
framing.

Three variants
--------------
(B1) labor_cos_resid_cnae: cosine similarity minus the median within-CNAE4
     pair baseline. Removes the industry-level confound that makes the
     absolute level of labor similarity non-comparable across cartels.

(B2) labor_cos_mgmt: cosine similarity of firms restricted to managerial
     and professional CBO groups (CBO2002 major groups 1 and 2). This is
     the Lamichhane-McGee theoretical channel for coordination — managers
     carry pricing/strategy information, operational workers do not.

(C)  worker_flow_log: log(1 + number of PIS) that were observed at firm i
     in year t and at firm j in year t+1, summed over 2009-2016 (latest
     possible) but RESTRICTED to pre-conduct period for each cartel when
     possible. For cartels whose conduct started before 2009 (trens,
     medicamentos, merenda, sacos), this is unavoidably mid-conduct.

Each variant is added to the pair-level frame from script 61, and the
leave-one-cartel-out composite is recomputed. The acceptance criterion
is: (variant + log_ov_full) composite LOO macro AUC > overlap_only macro
AUC by at least 0.03, with bootstrap CI of the difference excluding zero.

Output
------
02_data/intermediate/phase2_labor_reop.txt
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
PHASE1_FRAME = str(INTER / "phase1_revision.parquet")

OUT = INTER / "phase2_labor_reop.txt"

N_BOOT = 300
SEED = 42


def log(msg, t0):
    print(f"[{time.time()-t0:6.1f}s] {msg}", flush=True)


def mw_auc(pos, neg):
    pos = np.asarray(pos)
    neg = np.asarray(neg)
    pos = pos[~np.isnan(pos)]
    neg = neg[~np.isnan(neg)]
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


def loo_setor_auc(D, feat_cols, setor_list):
    X = D[feat_cols].values.astype(float)
    y = D["label"].values.astype(int)
    # Drop rows with missing features
    mask_valid = ~np.isnan(X).any(axis=1)
    if not mask_valid.all():
        D = D.loc[mask_valid].reset_index(drop=True)
        X = D[feat_cols].values.astype(float)
        y = D["label"].values.astype(int)

    oof = np.full(len(D), np.nan)
    fold_aucs = {}
    for s in setor_list:
        train_mask = ~((D["label"] == 1) & (D["tag"] == s))
        test_mask = (D["label"] == 1) & (D["tag"] == s)
        eval_mask = test_mask | (D["label"] == 0)
        if test_mask.sum() == 0:
            fold_aucs[s] = float("nan")
            continue
        X_tr = X[train_mask.values]
        y_tr = y[train_mask.values]
        X_ev = X[eval_mask.values]
        w, mu, sd = fit_logistic(X_tr, y_tr)
        scores = predict(w, X_ev, mu, sd)
        oof[eval_mask.values] = scores
        y_ev = y[eval_mask.values]
        fold_aucs[s] = mw_auc(scores[y_ev == 1], scores[y_ev == 0])

    m = ~np.isnan(oof)
    pooled = mw_auc(oof[m][y[m] == 1], oof[m][y[m] == 0])
    valid = [v for v in fold_aucs.values() if not np.isnan(v)]
    macro = float(np.mean(valid)) if valid else float("nan")
    return pooled, macro, fold_aucs


def main():
    t0 = time.time()
    con = duckdb.connect()
    con.sql("PRAGMA threads=12; PRAGMA memory_limit='14GB'")

    # ── Load Phase 1 frame ──────────────────────────────────────────────────
    log("Loading Phase 1 frame", t0)
    D = pd.read_parquet(PHASE1_FRAME)
    log(f"  D rows: {len(D):,}  pos={(D['label']==1).sum()}  "
        f"neg={(D['label']==0).sum():,}", t0)

    all_firms = sorted(set(D["a"]) | set(D["b"]))
    fs_sql = ",".join(f"'{f}'" for f in all_firms)

    # ── Cartel metadata (reload for consistency) ───────────────────────────
    con.sql(f"""
        CREATE TABLE cf AS
        SELECT DISTINCT cnpj_raiz, setor,
               cartel_start_year::INT AS s_year,
               cartel_end_year::INT AS e_year
        FROM read_parquet('{GROUND_TRUTH}')
        WHERE sp_relevant = 1 AND processo IS NOT NULL
          AND cartel_start_year IS NOT NULL
          AND cartel_end_year <= 2016
          AND in_bec = 1
    """)
    cf_df = con.sql("SELECT * FROM cf").fetchdf()
    cartel_firms_set = set(cf_df["cnpj_raiz"])
    cartel_meta = (cf_df.groupby("setor")
                   .agg(n_firms=("cnpj_raiz", "nunique"),
                        s_year=("s_year", "min"),
                        e_year=("e_year", "max"))
                   .reset_index())
    setor_list = sorted(cartel_meta["setor"].unique())

    # ── (B1) CNAE-residualized labor similarity ─────────────────────────────
    log("Step B1: CNAE-residualized labor similarity", t0)
    # Compute CNAE4 per firm from 2009 RAIS
    cnae_df = con.sql(f"""
        SELECT cnpj_raiz AS firm,
               MODE(cnae20_classe) AS cnae4
        FROM read_parquet('{RAIS_DIR}/rais_vinculos_2009.parquet')
        WHERE cnpj_raiz IN ({fs_sql}) AND cnae20_classe IS NOT NULL
        GROUP BY firm
    """).fetchdf()
    firm_to_cnae = dict(zip(cnae_df["firm"], cnae_df["cnae4"]))
    log(f"  firms with CNAE: {len(firm_to_cnae):,}", t0)

    # For each pair, the pair's "CNAE context" is the min(cnae_a, cnae_b)
    # if both are defined. We then compute the median labor_cos_2009 for
    # all pairs with the same CNAE context (from the negative class
    # only, to avoid leakage from positives) and subtract it.
    D["cnae_a"] = D["a"].map(firm_to_cnae)
    D["cnae_b"] = D["b"].map(firm_to_cnae)
    D["cnae_pair"] = D.apply(
        lambda r: None if pd.isna(r["cnae_a"]) or pd.isna(r["cnae_b"])
        else str(sorted([int(r["cnae_a"]), int(r["cnae_b"])])),
        axis=1,
    )

    # Baseline median cosine from negative-class pairs with defined cnae_pair
    neg = D[(D["label"] == 0) & D["cnae_pair"].notna() & D["labor_cos_2009"].notna()]
    median_by_cnae_pair = neg.groupby("cnae_pair")["labor_cos_2009"].median().to_dict()
    global_median = float(neg["labor_cos_2009"].median())

    def residualize(row):
        if pd.isna(row["labor_cos_2009"]):
            return np.nan
        baseline = median_by_cnae_pair.get(row["cnae_pair"], global_median)
        return row["labor_cos_2009"] - baseline

    D["labor_cos_resid"] = D.apply(residualize, axis=1)
    log(f"  labor_cos_resid: "
        f"pos mean={D[D.label==1]['labor_cos_resid'].mean():.4f}, "
        f"neg mean={D[D.label==0]['labor_cos_resid'].mean():.4f}", t0)

    # ── (B2) Managerial/professional restricted labor ──────────────────────
    log("Step B2: managerial/professional restricted labor", t0)
    con.sql(f"""
        CREATE TABLE emp_mgmt AS
        SELECT cnpj_raiz AS firm,
               cbo2002::VARCHAR AS cbo,
               mun_estab::VARCHAR AS mun,
               COUNT(*) AS n
        FROM read_parquet('{RAIS_DIR}/rais_vinculos_2009.parquet')
        WHERE cnpj_raiz IN ({fs_sql})
          AND cbo2002 IS NOT NULL AND mun_estab IS NOT NULL
          AND LEFT(cbo2002, 1) IN ('1', '2')
        GROUP BY firm, cbo, mun
    """)
    emp_mgmt = con.sql("SELECT * FROM emp_mgmt").fetchdf()
    log(f"  mgmt rows: {len(emp_mgmt):,}  firms: {emp_mgmt['firm'].nunique()}", t0)

    emp_mgmt["cell"] = emp_mgmt["cbo"] + "|" + emp_mgmt["mun"]
    mat_m = emp_mgmt.pivot_table(index="firm", columns="cell", values="n",
                                  fill_value=0, aggfunc="sum").astype(float)
    firms_mgmt = list(mat_m.index)
    fidx_m = {f: i for i, f in enumerate(firms_mgmt)}
    mv_m = mat_m.values
    norms_m = np.linalg.norm(mv_m, axis=1, keepdims=True)
    mv_m_n = mv_m / np.where(norms_m > 0, norms_m, 1)
    sim_m = mv_m_n @ mv_m_n.T

    def lookup_mgmt(row):
        a, b = row["a"], row["b"]
        if a in fidx_m and b in fidx_m:
            return float(sim_m[fidx_m[a], fidx_m[b]])
        return np.nan

    D["labor_cos_mgmt"] = D.apply(lookup_mgmt, axis=1)
    log(f"  labor_cos_mgmt non-null: {D['labor_cos_mgmt'].notna().sum():,}", t0)
    log(f"    pos mean={D[D.label==1]['labor_cos_mgmt'].mean():.4f}, "
        f"neg mean={D[D.label==0]['labor_cos_mgmt'].mean():.4f}", t0)

    # ── (C) Worker flow (count of PIS moving i→j across consecutive years) ──
    log("Step C: pre-conduct worker flow (2009-2010 earliest)", t0)
    # For each PIS, track sequence of (firm, year) in RAIS 2009-2016
    # Compute: for each pair (a, b) of firms in our universe, count PIS
    # who were at firm a in year t and firm b in year t+1 (or vice versa).
    # Restrict to pre-conduct years per cartel where possible.
    # Simplification: compute the flow count summed across all year-to-year
    # transitions in 2009-2016, for the firm pair universe. This is not
    # strictly pre-conduct but matches data availability.
    rais_glob = str(RAIS_DIR / "rais_vinculos_*.parquet")
    con.sql(f"""
        CREATE TABLE wy AS
        SELECT DISTINCT pis, cnpj_raiz AS firm, ano AS year
        FROM read_parquet('{rais_glob}')
        WHERE cnpj_raiz IN ({fs_sql}) AND pis IS NOT NULL
    """)
    # Transitions: pis × firm_t × firm_t+1 in consecutive years
    con.sql("""
        CREATE TABLE flows AS
        SELECT w1.pis, w1.firm AS a, w2.firm AS b, w1.year
        FROM wy w1
        JOIN wy w2 ON w2.pis = w1.pis AND w2.year = w1.year + 1
        WHERE w1.firm != w2.firm
    """)
    flows = con.sql("""
        SELECT a, b, COUNT(DISTINCT pis) AS n_flow
        FROM flows GROUP BY a, b
    """).fetchdf()
    # Symmetrize: flow_sym(a,b) = flow(a,b) + flow(b,a)
    flow_map = {}
    for _, r in flows.iterrows():
        key = tuple(sorted([r["a"], r["b"]]))
        flow_map[key] = flow_map.get(key, 0) + int(r["n_flow"])
    log(f"  unique pair flows (symmetrized): {len(flow_map):,}", t0)

    def lookup_flow(row):
        key = tuple(sorted([row["a"], row["b"]]))
        return np.log1p(flow_map.get(key, 0))

    D["worker_flow_log"] = D.apply(lookup_flow, axis=1)
    log(f"  worker_flow_log: "
        f"pos mean={D[D.label==1]['worker_flow_log'].mean():.4f}, "
        f"neg mean={D[D.label==0]['worker_flow_log'].mean():.4f}", t0)
    con.close()

    # ── Single-feature LOO AUCs for new features ────────────────────────────
    log("Step: single-feature LOO AUCs", t0)
    new_feats = ["labor_cos_resid", "labor_cos_mgmt", "worker_flow_log"]
    single_results = {}
    for feat in new_feats:
        # Drop rows with missing feature
        D_feat = D.dropna(subset=[feat]).copy()
        p, m, _ = loo_setor_auc(D_feat, [feat], setor_list)
        single_results[feat] = (p, m, len(D_feat))
        log(f"  {feat:<22s}  pooled={p:.4f}  macro={m:.4f}  n={len(D_feat):,}", t0)

    # ── Composite LOO AUCs ──────────────────────────────────────────────────
    log("Step: composite LOO AUCs", t0)
    composites = [
        ("baseline: labor_cos_2009 + log_ov_full",
         ["labor_cos_2009", "log_ov_full"]),
        ("B1: labor_cos_resid + log_ov_full",
         ["labor_cos_resid", "log_ov_full"]),
        ("B2: labor_cos_mgmt + log_ov_full",
         ["labor_cos_mgmt", "log_ov_full"]),
        ("C:  worker_flow_log + log_ov_full",
         ["worker_flow_log", "log_ov_full"]),
        ("reference: log_ov_full alone",
         ["log_ov_full"]),
        ("reference: cnae_match + log_ov_full",
         ["cnae_match", "log_ov_full"]),
        ("mix: worker_flow + cnae_match + log_ov_full",
         ["worker_flow_log", "cnae_match", "log_ov_full"]),
        ("mix: labor_cos_resid + cnae_match + log_ov_full",
         ["labor_cos_resid", "cnae_match", "log_ov_full"]),
    ]
    comp_results = {}
    for name, feats in composites:
        D_c = D.dropna(subset=feats).copy()
        p, m, folds = loo_setor_auc(D_c, feats, setor_list)
        comp_results[name] = (p, m, folds, len(D_c))
        log(f"  {name:<52s} pooled={p:.4f}  macro={m:.4f}  n={len(D_c):,}", t0)

    # ── Bootstrap of difference for each B-variant vs overlap-only ─────────
    log("Step: bootstrap of difference AUC (B={}) for new features".format(N_BOOT), t0)
    rng = np.random.default_rng(SEED)
    informative = [s for s in setor_list
                    if s not in ("sacos_de_lixo", "cafeteria_aeroporto")]

    def cluster_boot_diff(D_in, alt_feats, ref_feats=["log_ov_full"]):
        pos_by_tag = {s: D_in[(D_in["label"] == 1) & (D_in["tag"] == s)]
                       for s in informative}
        neg = D_in[D_in["label"] == 0]
        pooled_diffs = np.zeros(N_BOOT)
        macro_diffs = np.zeros(N_BOOT)
        for b in range(N_BOOT):
            draw = rng.choice(informative, size=len(informative), replace=True)
            parts = [pos_by_tag[s] for s in draw]
            parts.append(neg.sample(n=len(neg), replace=True, random_state=b + 20000))
            D_b = pd.concat(parts, ignore_index=True)
            p_alt, m_alt, _ = loo_setor_auc(D_b, alt_feats, list(set(draw)))
            p_ref, m_ref, _ = loo_setor_auc(D_b, ref_feats, list(set(draw)))
            pooled_diffs[b] = p_alt - p_ref
            macro_diffs[b] = m_alt - m_ref
        return pooled_diffs, macro_diffs

    variants_to_test = [
        ("B1: labor_cos_resid + overlap",
         ["labor_cos_resid", "log_ov_full"]),
        ("C:  worker_flow_log + overlap",
         ["worker_flow_log", "log_ov_full"]),
    ]
    diff_results = {}
    for name, feats in variants_to_test:
        D_v = D.dropna(subset=feats).copy()
        if len(D_v) == 0:
            log(f"  {name}: empty sample — skipping", t0)
            continue
        pooled, macro = cluster_boot_diff(D_v, feats)
        pv = pooled[~np.isnan(pooled)]
        mv = macro[~np.isnan(macro)]
        if len(pv) == 0 or len(mv) == 0:
            log(f"  {name}: bootstrap all-NaN — skipping", t0)
            continue
        ci_p = np.percentile(pv, [2.5, 97.5])
        ci_m = np.percentile(mv, [2.5, 97.5])
        p_p = float((pooled <= 0).mean())
        p_m = float((macro <= 0).mean())
        diff_results[name] = {
            "pooled_mean": float(pooled.mean()),
            "pooled_ci": (float(ci_p[0]), float(ci_p[1])),
            "pooled_p": p_p,
            "macro_mean": float(macro.mean()),
            "macro_ci": (float(ci_m[0]), float(ci_m[1])),
            "macro_p": p_m,
        }
        log(f"  {name}", t0)
        log(f"    pooled: +{pooled.mean():+.4f}  "
            f"[{ci_p[0]:+.4f}, {ci_p[1]:+.4f}]  p(≤0)={p_p:.3f}", t0)
        log(f"    macro:  +{macro.mean():+.4f}  "
            f"[{ci_m[0]:+.4f}, {ci_m[1]:+.4f}]  p(≤0)={p_m:.3f}", t0)

    # ── Write report ────────────────────────────────────────────────────────
    with open(OUT, "w") as f:
        f.write("Phase 2: labor re-operationalization\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")

        f.write("NEW FEATURES\n")
        f.write("-" * 50 + "\n")
        for feat, (p, m, n) in single_results.items():
            f.write(f"  {feat:<22s}  pooled={p:.4f}  macro={m:.4f}  n={n:,}\n")
        f.write("\n")

        f.write("COMPOSITE LOO AUCs\n")
        f.write("-" * 50 + "\n")
        for name, (p, m, _, n) in comp_results.items():
            f.write(f"  {name:<52s}  {p:.4f} / {m:.4f}  (n={n:,})\n")
        f.write("\n")

        f.write("BOOTSTRAP OF DIFFERENCE vs log_ov_full ALONE\n")
        f.write("-" * 50 + "\n")
        for name, d in diff_results.items():
            f.write(f"  {name}\n")
            f.write(f"    pooled diff: {d['pooled_mean']:+.4f}  "
                    f"95% CI [{d['pooled_ci'][0]:+.4f}, {d['pooled_ci'][1]:+.4f}]  "
                    f"p(≤0) = {d['pooled_p']:.3f}\n")
            f.write(f"    macro  diff: {d['macro_mean']:+.4f}  "
                    f"95% CI [{d['macro_ci'][0]:+.4f}, {d['macro_ci'][1]:+.4f}]  "
                    f"p(≤0) = {d['macro_p']:.3f}\n")
        f.write("\n")

        f.write("DECISION\n")
        f.write("-" * 50 + "\n")
        best = None
        best_macro = -1
        for name, d in diff_results.items():
            if d["macro_p"] < 0.05 and d["macro_mean"] > 0.03:
                if d["macro_mean"] > best_macro:
                    best_macro = d["macro_mean"]
                    best = name
        if best:
            f.write(f"  [PASS] {best} restores two-fingerprint framing.\n")
            f.write(f"         macro gain = +{best_macro:.4f} "
                    f"(p < 0.05)\n")
        else:
            f.write("  [FAIL] No labor variant achieves statistically\n")
            f.write("         distinguishable incremental contribution.\n")
            f.write("         Recommend pivot to CNAE4 + overlap framing.\n")

    log(f"report → {OUT}", t0)
    print("\n" + OUT.read_text())
    log(f"DONE ({time.time()-t0:.1f}s)", t0)


if __name__ == "__main__":
    main()
