#!/usr/bin/env python3
"""
61_phase1_revision.py — Phase 1 revisions (M2-M9 of referee report)

Consolidates the Phase 1 fixes required by the RAND referee report into
a single reproducible script. Replaces scattered outputs from scripts
56 and 57 with a consistent, deduplicated, audit-ready workflow.

Fixes addressed
---------------
M2  Labor vector timing: compute labor_cos for 2009, 2013, and 2017 and
    compare across years. RAIS panel does not start before 2009 so truly
    pre-conduct vectors are only available for cafeteria_aeroporto.
M3  Item-overlap window: split into pre-, during-, post-conduct per cartel
    and report three variants of log_item_overlap.
M4  Positive-class dedup bug: one firm (60756475) appears in BOTH
    trens_metros and aquecedores_solares. Fix: include it as member of
    both cartels but deduplicate the pair set via a `set`.
M5  Macro-averaged fold AUC alongside pooled micro-average.
M6  Cluster bootstrap over cartels (not pair bootstrap) for the CI of
    the composite OOF AUC.
M7  Trivial baselines: CNAE4-match, cobid indicator, common-buyer,
    computed at pair level and added to single-feature Table.
M1a Bootstrap CI of the DIFFERENCE AUC(composite) − AUC(overlap-only),
    testing whether labor's incremental contribution is distinguishable
    from zero.
M8  (Text-only, handled in .tex)
M9  Defer to Phase 2 with closure metric integration.

Output
------
02_data/intermediate/phase1_revision.txt — single consolidated report
02_data/intermediate/phase1_revision.parquet — pair-level feature frame
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

OUT_REPORT = INTER / "phase1_revision.txt"
OUT_FRAME = INTER / "phase1_revision.parquet"

N_CONTROLS = 2000
N_BOOT = 500
N_BOOT_DIFF = 500
SEED = 42


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

def log(msg, t0):
    print(f"[{time.time()-t0:6.1f}s] {msg}", flush=True)


def mw_auc(pos, neg, alternative="greater"):
    pos = np.asarray(pos)
    neg = np.asarray(neg)
    pos = pos[~np.isnan(pos)]
    neg = neg[~np.isnan(neg)]
    if len(pos) == 0 or len(neg) == 0:
        return float("nan")
    stat, _ = mannwhitneyu(pos, neg, alternative=alternative)
    return float(stat / (len(pos) * len(neg)))


def fit_logistic(X, y, max_iter=500, lr=0.5, l2=0.001):
    """Class-balanced logistic with L2 penalty; features standardized."""
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


def loo_setor_auc(D, feat_cols, setor_list, return_folds=False):
    """Leave-one-CADE-setor-out pooled OOF AUC, with optional per-fold AUCs."""
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

    mask = ~np.isnan(oof)
    auc_pooled = mw_auc(oof[mask][y[mask] == 1], oof[mask][y[mask] == 0])
    valid_folds = [v for v in fold_aucs.values() if not np.isnan(v)]
    auc_macro = float(np.mean(valid_folds)) if valid_folds else float("nan")

    if return_folds:
        return auc_pooled, auc_macro, fold_aucs
    return auc_pooled, auc_macro


# ─────────────────────────────────────────────────────────────────────────────
# Feature builders
# ─────────────────────────────────────────────────────────────────────────────

def build_labor_similarity(con, firms_all, year):
    """Return a firms_list, firm_idx dict, and cosine similarity matrix
    for the given RAIS year."""
    fs_sql = ",".join(f"'{f}'" for f in firms_all)
    rais_file = str(RAIS_DIR / f"rais_vinculos_{year}.parquet")
    con.sql(f"DROP TABLE IF EXISTS emp")
    con.sql(f"""
        CREATE TABLE emp AS
        SELECT cnpj_raiz AS firm, cbo2002::VARCHAR AS cbo,
               mun_estab::VARCHAR AS mun, COUNT(*) AS n
        FROM read_parquet('{rais_file}')
        WHERE cnpj_raiz IN ({fs_sql})
          AND cbo2002 IS NOT NULL AND mun_estab IS NOT NULL
        GROUP BY firm, cbo, mun
    """)
    emp = con.sql("SELECT * FROM emp").fetchdf()
    if len(emp) == 0:
        return [], {}, None
    emp["cell"] = emp["cbo"].astype(str) + "|" + emp["mun"].astype(str)
    mat = emp.pivot_table(index="firm", columns="cell", values="n",
                          fill_value=0, aggfunc="sum").astype(float)
    firms_with = list(mat.index)
    fidx = {f: i for i, f in enumerate(firms_with)}
    mv = mat.values
    norms = np.linalg.norm(mv, axis=1, keepdims=True)
    mv_n = mv / np.where(norms > 0, norms, 1)
    sim = mv_n @ mv_n.T
    return firms_with, fidx, sim


def build_items_maps(con, firms_all, cartel_meta):
    """For each firm, return the set of items bid on in (i) full window,
    (ii) pre-conduct window (strictly before start year for each cartel
    the firm belongs to), (iii) post-conduct window (strictly after end
    year)."""
    fs_sql = ",".join(f"'{f}'" for f in firms_all)
    # firm × item × year with at least one bid
    fiy = con.sql(f"""
        SELECT cnpj_raiz AS firm, "códigoitem" AS item, year
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE cnpj_raiz IN ({fs_sql})
        GROUP BY firm, item, year
    """).fetchdf()

    items_full = {}
    items_pre_by_cartel = {}
    items_post_by_cartel = {}

    for f, sub in fiy.groupby("firm"):
        items_full[f] = set(sub["item"].values)

    # Pre/post windows depend on which cartel each firm belongs to; for
    # non-cartel firms, "pre" and "post" are meaningless. We index
    # pre/post maps by cartel sector so that a pair lookup uses the
    # window of the pair's sector (positive pairs) or a neutral
    # definition (negative pairs use the full window).
    for _, row in cartel_meta.iterrows():
        s = row["setor"]
        s_year = int(row["s_year"])
        e_year = int(row["e_year"])
        pre = {}
        post = {}
        for f, sub in fiy.groupby("firm"):
            pre[f] = set(sub[sub["year"] < s_year]["item"].values)
            post[f] = set(sub[sub["year"] > e_year]["item"].values)
        items_pre_by_cartel[s] = pre
        items_post_by_cartel[s] = post

    return items_full, items_pre_by_cartel, items_post_by_cartel


# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

def main():
    t0 = time.time()
    INTER.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect()
    con.sql("PRAGMA threads=12; PRAGMA memory_limit='14GB'")

    # ── 1. Cartel metadata (M4 audit) ───────────────────────────────────────
    log("Step 1: cartel metadata + M4 audit", t0)
    con.sql(f"""
        CREATE TABLE cf_raw AS
        SELECT DISTINCT cnpj_raiz, setor, cartel_start_year::INT AS s_year,
               cartel_end_year::INT AS e_year
        FROM read_parquet('{GROUND_TRUTH}')
        WHERE sp_relevant = 1 AND processo IS NOT NULL
          AND cartel_start_year IS NOT NULL
          AND cartel_end_year <= 2016
          AND in_bec = 1
    """)
    cf_raw = con.sql("SELECT * FROM cf_raw").fetchdf()
    log(f"  cf_raw rows: {len(cf_raw)}", t0)

    # M4 audit: multi-cartel firms
    audit = con.sql("""
        SELECT cnpj_raiz, COUNT(DISTINCT setor) AS n_setors
        FROM cf_raw
        GROUP BY cnpj_raiz
        HAVING COUNT(DISTINCT setor) > 1
    """).fetchdf()
    n_multi = len(audit)
    multi_firms = set(audit["cnpj_raiz"]) if n_multi > 0 else set()
    log(f"  [M4] multi-cartel firms: {n_multi} → {sorted(multi_firms)}", t0)

    cartel_meta = (cf_raw.groupby("setor")
                   .agg(n_firms=("cnpj_raiz", "nunique"),
                        s_year=("s_year", "min"),
                        e_year=("e_year", "max"))
                   .reset_index())
    setor_list = sorted(cartel_meta["setor"].unique())
    log(f"  setores: {setor_list}", t0)

    # cartel_firms is the distinct set of firms (for similarity matrix)
    cartel_firms_unique = sorted(cf_raw["cnpj_raiz"].unique())
    log(f"  cartel firms (unique): {len(cartel_firms_unique)}", t0)

    # firm → list of setors (multi-cartel firms have >1)
    firm_to_setors = {}
    for _, row in cf_raw.iterrows():
        firm_to_setors.setdefault(row["cnpj_raiz"], []).append(row["setor"])

    # ── 2. Controls (2000 sampled non-cartel BEC firms) ─────────────────────
    log("Step 2: sampling controls", t0)
    ctrl_pool = con.sql(f"""
        SELECT DISTINCT cnpj_raiz FROM read_parquet('{PAIRS_PREGAO}')
        WHERE cnpj_raiz IS NOT NULL
          AND cnpj_raiz NOT IN (SELECT cnpj_raiz FROM cf_raw)
    """).fetchdf()
    rng = np.random.default_rng(SEED)
    controls = list(ctrl_pool.sample(n=N_CONTROLS, random_state=SEED)["cnpj_raiz"])
    log(f"  controls: {len(controls)}", t0)

    firms_all = sorted(set(cartel_firms_unique) | set(controls))
    log(f"  firms_all: {len(firms_all)}", t0)

    # ── 3. Labor similarity at multiple years (M2) ──────────────────────────
    log("Step 3: labor similarity at 2009, 2013, 2017", t0)
    firms_emp_2009, fidx_2009, sim_2009 = build_labor_similarity(con, firms_all, 2009)
    firms_emp_2013, fidx_2013, sim_2013 = build_labor_similarity(con, firms_all, 2013)
    firms_emp_2017, fidx_2017, sim_2017 = build_labor_similarity(con, firms_all, 2017)
    log(f"  firms with RAIS data: 2009={len(firms_emp_2009)}, "
        f"2013={len(firms_emp_2013)}, 2017={len(firms_emp_2017)}", t0)

    # ── 4. Item maps (M3): full + per-cartel pre/post windows ───────────────
    log("Step 4: item maps (full + per-cartel pre/post)", t0)
    items_full, items_pre, items_post = build_items_maps(con, firms_all, cartel_meta)
    log(f"  items_full firms: {len(items_full)}", t0)

    # ── 5. CNAE4 per firm (M7 baseline 1) ───────────────────────────────────
    log("Step 5: CNAE4 per firm (from 2009 RAIS)", t0)
    fs_sql = ",".join(f"'{f}'" for f in firms_all)
    cnae_df = con.sql(f"""
        SELECT cnpj_raiz AS firm,
               MODE(cnae20_classe) AS cnae4
        FROM read_parquet('{RAIS_DIR}/rais_vinculos_2009.parquet')
        WHERE cnpj_raiz IN ({fs_sql})
          AND cnae20_classe IS NOT NULL
        GROUP BY firm
    """).fetchdf()
    firm_to_cnae = dict(zip(cnae_df["firm"], cnae_df["cnae4"]))
    log(f"  firms with CNAE: {len(firm_to_cnae):,}", t0)

    # ── 6. Common-buyer and cobid maps (M7 baselines 2-3) ──────────────────
    log("Step 6: cobid and common-buyer indicators", t0)
    # For each firm, the set of auction_items it bid on
    firm_auctions = con.sql(f"""
        SELECT cnpj_raiz AS firm, auction_item
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE cnpj_raiz IN ({fs_sql})
        GROUP BY firm, auction_item
    """).fetchdf()
    firm_to_auctions = {f: set(sub["auction_item"].values)
                         for f, sub in firm_auctions.groupby("firm")}

    firm_buyers = con.sql(f"""
        SELECT cnpj_raiz AS firm,
               códigounidadecompradora AS buyer
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE cnpj_raiz IN ({fs_sql}) AND flagvencedor = 1
        GROUP BY firm, buyer
    """).fetchdf()
    firm_to_buyers = {f: set(sub["buyer"].values)
                       for f, sub in firm_buyers.groupby("firm")}
    log(f"  firms with auction sets: {len(firm_to_auctions):,}", t0)
    log(f"  firms with buyer sets:   {len(firm_to_buyers):,}", t0)
    con.close()

    # ── 7. Positive-pair construction (M4 fix via set) ─────────────────────
    log("Step 7: building positive pairs (deduplicated)", t0)
    positive_set = set()
    pair_to_tag = {}  # which cartel sector this pair belongs to
    for s in setor_list:
        firms_s = sorted(set(cf_raw[cf_raw["setor"] == s]["cnpj_raiz"]))
        for i in range(len(firms_s)):
            for j in range(i + 1, len(firms_s)):
                a, b = sorted([firms_s[i], firms_s[j]])
                key = (a, b)
                positive_set.add(key)
                # If a pair appears in multiple cartels (should not happen
                # within this sample), keep the first assignment.
                pair_to_tag.setdefault(key, s)
    log(f"  positive pairs (deduplicated): {len(positive_set)}", t0)
    # Verify expected count: sum of C(n_c, 2) across setores
    expected = sum(n * (n - 1) // 2 for n in cartel_meta["n_firms"])
    log(f"  expected (from cartel_meta): {expected}", t0)

    # ── 8. Negative-pair sampling ───────────────────────────────────────────
    log("Step 8: sampling negative pairs", t0)
    max_neg = 100_000
    neg_set = set()
    n_c = len(controls)
    while len(neg_set) < max_neg:
        i = rng.integers(0, n_c)
        j = rng.integers(0, n_c)
        if i != j:
            neg_set.add(tuple(sorted([controls[i], controls[j]])))
    log(f"  negative pairs drawn: {len(neg_set):,}", t0)

    # ── 9. Assemble pair-level feature frame ────────────────────────────────
    log("Step 9: assembling pair-level features", t0)

    def pair_features(a, b, tag, label):
        # Labor similarity at three years (NaN if firm missing)
        lc_2009 = float(sim_2009[fidx_2009[a], fidx_2009[b]]) \
            if (a in fidx_2009 and b in fidx_2009) else np.nan
        lc_2013 = float(sim_2013[fidx_2013[a], fidx_2013[b]]) \
            if (a in fidx_2013 and b in fidx_2013) else np.nan
        lc_2017 = float(sim_2017[fidx_2017[a], fidx_2017[b]]) \
            if (a in fidx_2017 and b in fidx_2017) else np.nan

        # Item overlaps
        ia_full = items_full.get(a, set())
        ib_full = items_full.get(b, set())
        ov_full = np.log1p(len(ia_full & ib_full))
        ov_full_raw = len(ia_full & ib_full)

        # Pre and post windows: for positive pairs, use the pair's cartel
        # window; for negative pairs, use a neutral window (full — no
        # split). This means ov_pre and ov_post are meaningful only for
        # positive pairs and are the full window for negatives. The LOO
        # classifier sees the difference.
        if label == 1 and tag in items_pre:
            ia_pre = items_pre[tag].get(a, set())
            ib_pre = items_pre[tag].get(b, set())
            ov_pre = np.log1p(len(ia_pre & ib_pre))
            ia_post = items_post[tag].get(a, set())
            ib_post = items_post[tag].get(b, set())
            ov_post = np.log1p(len(ia_post & ib_post))
        else:
            ov_pre = ov_full
            ov_post = ov_full

        # Baselines
        cnae_a = firm_to_cnae.get(a)
        cnae_b = firm_to_cnae.get(b)
        cnae_match = int(cnae_a is not None and cnae_a == cnae_b)

        aa = firm_to_auctions.get(a, set())
        ab = firm_to_auctions.get(b, set())
        cobid_ind = int(len(aa & ab) > 0)
        cobid_count = len(aa & ab)

        ba = firm_to_buyers.get(a, set())
        bb = firm_to_buyers.get(b, set())
        common_buyer = int(len(ba & bb) > 0)

        return dict(
            a=a, b=b, tag=tag, label=label,
            labor_cos_2009=lc_2009, labor_cos_2013=lc_2013, labor_cos_2017=lc_2017,
            log_ov_full=ov_full, ov_full_raw=ov_full_raw,
            log_ov_pre=ov_pre, log_ov_post=ov_post,
            cnae_match=cnae_match,
            cobid_ind=cobid_ind, log_cobid_count=np.log1p(cobid_count),
            common_buyer=common_buyer,
        )

    rows = []
    for (a, b) in positive_set:
        rows.append(pair_features(a, b, pair_to_tag[(a, b)], 1))
    for (a, b) in neg_set:
        rows.append(pair_features(a, b, "_ctrl_", 0))

    D = pd.DataFrame(rows)

    # Drop rows with missing labor_cos_2009 (primary feature)
    D = D[D["labor_cos_2009"].notna()].reset_index(drop=True)
    n_pos = int((D["label"] == 1).sum())
    n_neg = int((D["label"] == 0).sum())
    log(f"  frame: {len(D):,}  pos={n_pos}  neg={n_neg:,}", t0)

    D.to_parquet(OUT_FRAME, index=False)
    log(f"  saved → {OUT_FRAME}", t0)

    # ── 10. Single-feature LOO AUCs (M1, M7 context) ───────────────────────
    log("Step 10: single-feature LOO AUCs", t0)
    single_feats = [
        "labor_cos_2009", "labor_cos_2013", "labor_cos_2017",
        "log_ov_full", "log_ov_pre", "log_ov_post",
        "cnae_match", "cobid_ind", "log_cobid_count", "common_buyer",
    ]
    single = {}
    for feat in single_feats:
        if D[feat].notna().all():
            auc_p, auc_m = loo_setor_auc(D, [feat], setor_list)
            single[feat] = (auc_p, auc_m)
            log(f"  {feat:<22s}  pooled={auc_p:.4f}  macro={auc_m:.4f}", t0)

    # ── 11. Composite specifications ────────────────────────────────────────
    log("Step 11: composite LOO AUCs", t0)
    composites = [
        ("two-feat 2009 baseline",
         ["labor_cos_2009", "log_ov_full"]),
        ("two-feat pre-window overlap",
         ["labor_cos_2009", "log_ov_pre"]),
        ("two-feat post-window overlap",
         ["labor_cos_2009", "log_ov_post"]),
        ("overlap only (log_ov_full)",
         ["log_ov_full"]),
        ("overlap only (log_ov_pre)",
         ["log_ov_pre"]),
        ("CNAE4 match only",
         ["cnae_match"]),
        ("CNAE4 + log_ov_full",
         ["cnae_match", "log_ov_full"]),
        ("two-feat + CNAE4 (3-feat)",
         ["labor_cos_2009", "log_ov_full", "cnae_match"]),
    ]
    comp = {}
    for name, feats in composites:
        if all(f in D.columns and D[f].notna().all() for f in feats):
            auc_p, auc_m, folds = loo_setor_auc(D, feats, setor_list, return_folds=True)
            comp[name] = (auc_p, auc_m, folds)
            log(f"  {name:<32s} pooled={auc_p:.4f}  macro={auc_m:.4f}", t0)

    # ── 12. Cluster bootstrap over cartels (M6) ─────────────────────────────
    log(f"Step 12: cluster bootstrap over cartels (B={N_BOOT})", t0)
    informative = [s for s in setor_list if s not in ("sacos_de_lixo", "cafeteria_aeroporto")]
    log(f"  informative cartels: {informative}", t0)

    baseline_feats = ["labor_cos_2009", "log_ov_full"]
    overlap_feats = ["log_ov_full"]
    boot_pooled = np.zeros(N_BOOT)
    boot_macro = np.zeros(N_BOOT)

    pos_rows_by_tag = {s: D[(D["label"] == 1) & (D["tag"] == s)]
                       for s in informative}
    neg_frame = D[D["label"] == 0]

    for b in range(N_BOOT):
        draw = rng.choice(informative, size=len(informative), replace=True)
        parts = [pos_rows_by_tag[s] for s in draw]
        parts.append(neg_frame.sample(n=len(neg_frame), replace=True,
                                       random_state=b))
        D_b = pd.concat(parts, ignore_index=True)
        auc_p, auc_m = loo_setor_auc(D_b, baseline_feats, list(set(draw)))
        boot_pooled[b] = auc_p
        boot_macro[b] = auc_m
        if (b + 1) % 100 == 0:
            log(f"  bootstrap {b+1}/{N_BOOT}", t0)

    ci_pooled = np.percentile(boot_pooled[~np.isnan(boot_pooled)], [2.5, 97.5])
    ci_macro = np.percentile(boot_macro[~np.isnan(boot_macro)], [2.5, 97.5])
    log(f"  cluster-bootstrap pooled CI: [{ci_pooled[0]:.4f}, {ci_pooled[1]:.4f}]", t0)
    log(f"  cluster-bootstrap macro CI:  [{ci_macro[0]:.4f}, {ci_macro[1]:.4f}]", t0)

    # ── 13. Bootstrap of AUC difference (M1a) ───────────────────────────────
    log(f"Step 13: bootstrap of AUC difference (B={N_BOOT_DIFF})", t0)
    boot_diff_pooled = np.zeros(N_BOOT_DIFF)
    boot_diff_macro = np.zeros(N_BOOT_DIFF)
    for b in range(N_BOOT_DIFF):
        draw = rng.choice(informative, size=len(informative), replace=True)
        parts = [pos_rows_by_tag[s] for s in draw]
        parts.append(neg_frame.sample(n=len(neg_frame), replace=True,
                                       random_state=b + 10_000))
        D_b = pd.concat(parts, ignore_index=True)
        auc_comp_p, auc_comp_m = loo_setor_auc(D_b, baseline_feats, list(set(draw)))
        auc_ov_p, auc_ov_m = loo_setor_auc(D_b, overlap_feats, list(set(draw)))
        boot_diff_pooled[b] = auc_comp_p - auc_ov_p
        boot_diff_macro[b] = auc_comp_m - auc_ov_m

    ci_diff_pooled = np.percentile(boot_diff_pooled[~np.isnan(boot_diff_pooled)], [2.5, 97.5])
    ci_diff_macro = np.percentile(boot_diff_macro[~np.isnan(boot_diff_macro)], [2.5, 97.5])
    p_zero_pooled = (boot_diff_pooled <= 0).mean()
    p_zero_macro = (boot_diff_macro <= 0).mean()
    log(f"  diff pooled mean = {boot_diff_pooled.mean():+.4f} "
        f"CI [{ci_diff_pooled[0]:+.4f}, {ci_diff_pooled[1]:+.4f}]  "
        f"p(diff≤0) = {p_zero_pooled:.3f}", t0)
    log(f"  diff macro  mean = {boot_diff_macro.mean():+.4f} "
        f"CI [{ci_diff_macro[0]:+.4f}, {ci_diff_macro[1]:+.4f}]  "
        f"p(diff≤0) = {p_zero_macro:.3f}", t0)

    # ── 14. Write consolidated report ───────────────────────────────────────
    log("Step 14: writing report", t0)
    with open(OUT_REPORT, "w") as f:
        f.write("Phase 1 revision — consolidated results\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")

        f.write("M4 AUDIT\n")
        f.write("-" * 50 + "\n")
        f.write(f"  multi-cartel firms: {n_multi}\n")
        for fm in sorted(multi_firms):
            setors = [r["setor"] for _, r in cf_raw[cf_raw["cnpj_raiz"] == fm].iterrows()]
            f.write(f"    {fm}: {sorted(setors)}\n")
        f.write(f"  unique cartel firms: {len(cartel_firms_unique)}\n")
        f.write(f"  positive pairs (dedup): {len(positive_set)}  "
                f"(expected: {expected})\n")
        f.write(f"  positive pairs (in frame after labor-2009 filter): {n_pos}\n\n")

        f.write("SAMPLE\n")
        f.write("-" * 50 + "\n")
        f.write(f"  Controls:           {len(controls)}\n")
        f.write(f"  Pair frame total:   {len(D):,}\n")
        f.write(f"    positive:         {n_pos}\n")
        f.write(f"    negative:         {n_neg:,}\n\n")

        f.write("SINGLE-FEATURE LOO AUCs (pooled / macro)\n")
        f.write("-" * 50 + "\n")
        f.write(f"  {'feature':<24s}  {'pooled':>8s}  {'macro':>8s}\n")
        for feat, (p, m) in single.items():
            f.write(f"  {feat:<24s}  {p:>8.4f}  {m:>8.4f}\n")
        f.write("\n")

        f.write("COMPOSITE LOO AUCs\n")
        f.write("-" * 50 + "\n")
        f.write(f"  {'specification':<32s}  {'pooled':>8s}  {'macro':>8s}\n")
        for name, (p, m, folds) in comp.items():
            f.write(f"  {name:<32s}  {p:>8.4f}  {m:>8.4f}\n")
        f.write("\n")

        f.write("PER-FOLD AUCs (two-feat 2009 baseline)\n")
        f.write("-" * 50 + "\n")
        _, _, folds = comp["two-feat 2009 baseline"]
        for s, auc in folds.items():
            n_pos_s = int(((D["label"] == 1) & (D["tag"] == s)).sum())
            auc_str = f"{auc:.4f}" if not np.isnan(auc) else "nan"
            f.write(f"  {s:<22s}  n_pos={n_pos_s:>3}  AUC={auc_str}\n")
        f.write("\n")

        f.write("CLUSTER BOOTSTRAP OVER CARTELS (B = {})\n".format(N_BOOT))
        f.write("-" * 50 + "\n")
        f.write(f"  two-feat pooled:  mean = {boot_pooled.mean():.4f}  "
                f"95% CI [{ci_pooled[0]:.4f}, {ci_pooled[1]:.4f}]\n")
        f.write(f"  two-feat macro:   mean = {boot_macro.mean():.4f}  "
                f"95% CI [{ci_macro[0]:.4f}, {ci_macro[1]:.4f}]\n\n")

        f.write("BOOTSTRAP OF DIFFERENCE AUC(composite) − AUC(overlap only)\n")
        f.write("-" * 50 + "\n")
        f.write(f"  pooled: mean = {boot_diff_pooled.mean():+.4f}  "
                f"95% CI [{ci_diff_pooled[0]:+.4f}, {ci_diff_pooled[1]:+.4f}]  "
                f"p(diff≤0) = {p_zero_pooled:.3f}\n")
        f.write(f"  macro:  mean = {boot_diff_macro.mean():+.4f}  "
                f"95% CI [{ci_diff_macro[0]:+.4f}, {ci_diff_macro[1]:+.4f}]  "
                f"p(diff≤0) = {p_zero_macro:.3f}\n\n")

        f.write("INTERPRETATION\n")
        f.write("-" * 50 + "\n")
        if p_zero_pooled < 0.05:
            f.write("  [PASS] Labor adds statistically distinguishable signal (pooled).\n")
        else:
            f.write("  [FAIL] Labor's incremental contribution is not "
                    "distinguishable from zero (pooled).\n")
        if p_zero_macro < 0.05:
            f.write("  [PASS] Labor adds signal under macro averaging.\n")
        else:
            f.write("  [FAIL] Labor does not add signal under macro averaging.\n")

    log(f"report → {OUT_REPORT}", t0)
    print("\n" + OUT_REPORT.read_text())
    log(f"DONE ({time.time()-t0:.1f}s)", t0)


if __name__ == "__main__":
    main()
