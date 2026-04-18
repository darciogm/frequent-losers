#!/usr/bin/env python3
"""
63_paper_master.py — Paper-ready master script (Path A: worker flow)

Consolidates Phase 1 + Phase 2 findings into a single reproducible
workflow that produces every number used in the revised paper_screens
manuscript. Worker flow replaces static labor cosine similarity as the
primary labor feature. All specifications are evaluated under leave-one-
CADE-cartel-out (LOO) with pooled and macro averaging, cluster bootstrap
over cartels, and permutation null.

Features computed at the unordered firm-pair level:
  worker_flow_log  : log(1 + #PIS moved between firms in adjacent RAIS years)
  log_ov_full      : log(1 + #items both firms bid on, 2009-2017)
  log_ov_pre       : pre-start-year variant (cartel-specific window)
  log_ov_post      : post-end-year variant
  labor_cos_2009   : static cosine similarity (for comparison only)
  cnae_match       : trivial baseline — same 4-digit CNAE2.0 class
  cobid_ind        : trivial baseline — both firms ever in same auction_item
  common_buyer     : trivial baseline — both firms ever won from same buyer

Main specifications reported:
  (M1) worker_flow_log + log_ov_full         ← preferred two-fingerprint
  (M0) labor_cos_2009  + log_ov_full         ← earlier draft baseline
  (S1) log_ov_full alone                      ← overlap-only reference
  (S2) cnae_match + log_ov_full               ← trivial-baseline composite
  (S3) worker_flow_log alone
  (S4) cnae_match alone

Outputs:
  02_data/intermediate/paper_master.txt       — consolidated report
  02_data/intermediate/paper_master.parquet   — pair frame
  04_figures/paper_master_roc.pdf             — main ROC curve
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
FIGS  = BASE / "04_figures"

PAIRS_PREGAO = str(FINAL / "df_pregao_with_cartel_flags.parquet")
GROUND_TRUTH = str(FIRMS / "cade_ground_truth.parquet")

OUT_REPORT = INTER / "paper_master.txt"
OUT_FRAME  = INTER / "paper_master.parquet"
OUT_FIG    = FIGS  / "paper_master_roc.pdf"

N_CONTROLS = 2000
N_BOOT = 500
N_PERM = 500
SEED = 42


# ─────────────────────────────────────────────────────────────────────────────

def log(msg, t0):
    print(f"[{time.time()-t0:6.1f}s] {msg}", flush=True)


def mw_auc(pos, neg):
    pos = np.asarray(pos); neg = np.asarray(neg)
    pos = pos[~np.isnan(pos)]; neg = neg[~np.isnan(neg)]
    if len(pos) == 0 or len(neg) == 0:
        return float("nan")
    stat, _ = mannwhitneyu(pos, neg, alternative="greater")
    return float(stat / (len(pos) * len(neg)))


def fit_logit(X, y, max_iter=500, lr=0.5, l2=0.001):
    n, k = X.shape
    mu = X.mean(axis=0); sd = X.std(axis=0) + 1e-10
    Xn = np.column_stack([np.ones(n), (X - mu) / sd])
    np_ = max((y == 1).sum(), 1); nn_ = max((y == 0).sum(), 1)
    sw = np.where(y == 1, n / (2 * np_), n / (2 * nn_))
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


def loo(D_in, feat_cols, setor_list):
    D_in = D_in.dropna(subset=feat_cols).reset_index(drop=True)
    X = D_in[feat_cols].values.astype(float)
    y = D_in["label"].values.astype(int)
    oof = np.full(len(D_in), np.nan)
    folds = {}
    for s in setor_list:
        train = ~((D_in["label"] == 1) & (D_in["tag"] == s))
        test = (D_in["label"] == 1) & (D_in["tag"] == s)
        ev = test | (D_in["label"] == 0)
        if test.sum() == 0:
            folds[s] = float("nan"); continue
        X_tr = X[train.values]; y_tr = y[train.values]; X_ev = X[ev.values]
        w, mu, sd = fit_logit(X_tr, y_tr)
        scores = predict(w, X_ev, mu, sd)
        oof[ev.values] = scores
        y_ev = y[ev.values]
        folds[s] = mw_auc(scores[y_ev == 1], scores[y_ev == 0])
    m = ~np.isnan(oof)
    pooled = mw_auc(oof[m][y[m] == 1], oof[m][y[m] == 0])
    valid = [v for v in folds.values() if not np.isnan(v)]
    macro = float(np.mean(valid)) if valid else float("nan")
    return pooled, macro, folds, oof, D_in["label"].values, D_in["tag"].values


# ─────────────────────────────────────────────────────────────────────────────

def main():
    t0 = time.time()
    INTER.mkdir(parents=True, exist_ok=True)
    FIGS.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect()
    con.sql("PRAGMA threads=12; PRAGMA memory_limit='14GB'")
    rais_glob = str(RAIS_DIR / "rais_vinculos_*.parquet")

    # ── 1. Cartels ──────────────────────────────────────────────────────────
    log("Step 1: cartels + M4 audit", t0)
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
    cartel_firms = sorted(cf_df["cnpj_raiz"].unique())
    cartel_meta = (cf_df.groupby("setor")
                   .agg(n_firms=("cnpj_raiz", "nunique"),
                        s_year=("s_year", "min"),
                        e_year=("e_year", "max"))
                   .reset_index())
    setor_list = sorted(cartel_meta["setor"].unique())
    log(f"  unique cartel firms: {len(cartel_firms)}", t0)
    log(f"  cartels: {setor_list}", t0)

    # ── 2. Controls ─────────────────────────────────────────────────────────
    log("Step 2: controls", t0)
    ctrl_pool = con.sql(f"""
        SELECT DISTINCT cnpj_raiz FROM read_parquet('{PAIRS_PREGAO}')
        WHERE cnpj_raiz IS NOT NULL
          AND cnpj_raiz NOT IN (SELECT cnpj_raiz FROM cf)
    """).fetchdf()
    rng = np.random.default_rng(SEED)
    controls = list(ctrl_pool.sample(n=N_CONTROLS, random_state=SEED)["cnpj_raiz"])
    firms_all = sorted(set(cartel_firms) | set(controls))
    fs_sql = ",".join(f"'{f}'" for f in firms_all)
    log(f"  controls: {len(controls)}, firms_all: {len(firms_all)}", t0)

    # ── 3. Static labor cosine (comparison) ─────────────────────────────────
    log("Step 3: static labor cosine 2009", t0)
    con.sql(f"""
        CREATE TABLE emp09 AS
        SELECT cnpj_raiz AS firm, cbo2002::VARCHAR AS cbo,
               mun_estab::VARCHAR AS mun, COUNT(*) AS n
        FROM read_parquet('{RAIS_DIR}/rais_vinculos_2009.parquet')
        WHERE cnpj_raiz IN ({fs_sql})
          AND cbo2002 IS NOT NULL AND mun_estab IS NOT NULL
        GROUP BY firm, cbo, mun
    """)
    emp09 = con.sql("SELECT * FROM emp09").fetchdf()
    emp09["cell"] = emp09["cbo"] + "|" + emp09["mun"]
    mat = emp09.pivot_table(index="firm", columns="cell", values="n",
                             fill_value=0, aggfunc="sum").astype(float)
    firms_emp = list(mat.index)
    fidx_emp = {f: i for i, f in enumerate(firms_emp)}
    mv = mat.values
    norms = np.linalg.norm(mv, axis=1, keepdims=True)
    mv_n = mv / np.where(norms > 0, norms, 1)
    sim_labor = mv_n @ mv_n.T
    log(f"  firms with 2009 RAIS: {len(firms_emp)}", t0)

    # ── 4. Worker flow (primary labor feature) ─────────────────────────────
    log("Step 4: worker flow (symmetric, all years 2009-2017)", t0)
    con.sql(f"""
        CREATE TABLE wy AS
        SELECT DISTINCT pis, cnpj_raiz AS firm, ano AS year
        FROM read_parquet('{rais_glob}')
        WHERE cnpj_raiz IN ({fs_sql}) AND pis IS NOT NULL
    """)
    con.sql("""
        CREATE TABLE flows_raw AS
        SELECT w1.firm AS a, w2.firm AS b, w1.year,
               COUNT(DISTINCT w1.pis) AS n_flow
        FROM wy w1
        JOIN wy w2 ON w2.pis = w1.pis AND w2.year = w1.year + 1
        WHERE w1.firm != w2.firm
        GROUP BY w1.firm, w2.firm, w1.year
    """)
    flows = con.sql("SELECT a, b, SUM(n_flow) AS n_flow FROM flows_raw GROUP BY a, b").fetchdf()
    flow_map = {}
    for _, r in flows.iterrows():
        key = tuple(sorted([r["a"], r["b"]]))
        flow_map[key] = flow_map.get(key, 0) + int(r["n_flow"])
    log(f"  unordered pair flows: {len(flow_map):,}", t0)

    # ── 5. Item overlap (full window + pre/post by cartel) ─────────────────
    log("Step 5: item overlap", t0)
    fiy = con.sql(f"""
        SELECT cnpj_raiz AS firm, "códigoitem" AS item, year
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE cnpj_raiz IN ({fs_sql})
        GROUP BY firm, item, year
    """).fetchdf()
    items_full = {f: set(sub["item"].values) for f, sub in fiy.groupby("firm")}

    items_pre_by_cartel = {}
    items_post_by_cartel = {}
    for _, row in cartel_meta.iterrows():
        s = row["setor"]; s_year = int(row["s_year"]); e_year = int(row["e_year"])
        pre = {f: set(sub[sub["year"] < s_year]["item"].values) for f, sub in fiy.groupby("firm")}
        post = {f: set(sub[sub["year"] > e_year]["item"].values) for f, sub in fiy.groupby("firm")}
        items_pre_by_cartel[s] = pre
        items_post_by_cartel[s] = post
    log(f"  item maps built", t0)

    # ── 6. CNAE4 + cobid + common buyer ─────────────────────────────────────
    log("Step 6: baselines CNAE, cobid, common buyer", t0)
    cnae_df = con.sql(f"""
        SELECT cnpj_raiz AS firm, MODE(cnae20_classe) AS cnae4
        FROM read_parquet('{RAIS_DIR}/rais_vinculos_2009.parquet')
        WHERE cnpj_raiz IN ({fs_sql}) AND cnae20_classe IS NOT NULL
        GROUP BY firm
    """).fetchdf()
    firm_to_cnae = dict(zip(cnae_df["firm"], cnae_df["cnae4"]))

    firm_auctions = con.sql(f"""
        SELECT cnpj_raiz AS firm, auction_item
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE cnpj_raiz IN ({fs_sql})
        GROUP BY firm, auction_item
    """).fetchdf()
    firm_to_auctions = {f: set(sub["auction_item"].values)
                        for f, sub in firm_auctions.groupby("firm")}

    firm_buyers = con.sql(f"""
        SELECT cnpj_raiz AS firm, códigounidadecompradora AS buyer
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE cnpj_raiz IN ({fs_sql}) AND flagvencedor = 1
        GROUP BY firm, buyer
    """).fetchdf()
    firm_to_buyers = {f: set(sub["buyer"].values)
                      for f, sub in firm_buyers.groupby("firm")}
    con.close()

    # ── 7. Positive pairs (deduped) ─────────────────────────────────────────
    log("Step 7: positive pairs (dedup)", t0)
    positive_set = set()
    pair_to_tag = {}
    for s in setor_list:
        firms_s = sorted(set(cf_df[cf_df["setor"] == s]["cnpj_raiz"]))
        for i in range(len(firms_s)):
            for j in range(i + 1, len(firms_s)):
                a, b = sorted([firms_s[i], firms_s[j]])
                key = (a, b)
                positive_set.add(key)
                pair_to_tag.setdefault(key, s)
    log(f"  positives: {len(positive_set)}", t0)

    # ── 8. Negative pairs ───────────────────────────────────────────────────
    log("Step 8: negative pairs", t0)
    max_neg = 100000
    neg_set = set()
    while len(neg_set) < max_neg:
        i = rng.integers(0, len(controls)); j = rng.integers(0, len(controls))
        if i != j:
            neg_set.add(tuple(sorted([controls[i], controls[j]])))
    log(f"  negatives: {len(neg_set):,}", t0)

    # ── 9. Assemble pair features ───────────────────────────────────────────
    log("Step 9: assembling features", t0)

    def pair_row(a, b, tag, label):
        # Labor static
        lc = (float(sim_labor[fidx_emp[a], fidx_emp[b]])
              if a in fidx_emp and b in fidx_emp else np.nan)

        # Worker flow (symmetric)
        key = tuple(sorted([a, b]))
        wf = np.log1p(flow_map.get(key, 0))

        # Item overlap (full window)
        ia = items_full.get(a, set())
        ib = items_full.get(b, set())
        inter = len(ia & ib)
        ov_full = np.log1p(inter)

        # Pre/post by cartel (for positives) or full (for negatives)
        if label == 1 and tag in items_pre_by_cartel:
            ia_pre = items_pre_by_cartel[tag].get(a, set())
            ib_pre = items_pre_by_cartel[tag].get(b, set())
            ov_pre = np.log1p(len(ia_pre & ib_pre))
            ia_po = items_post_by_cartel[tag].get(a, set())
            ib_po = items_post_by_cartel[tag].get(b, set())
            ov_post = np.log1p(len(ia_po & ib_po))
        else:
            ov_pre = ov_full
            ov_post = ov_full

        # Baselines
        cnae_a = firm_to_cnae.get(a); cnae_b = firm_to_cnae.get(b)
        cnae_m = int(cnae_a is not None and cnae_a == cnae_b)

        aa = firm_to_auctions.get(a, set()); ab = firm_to_auctions.get(b, set())
        cobid = int(len(aa & ab) > 0)

        ba = firm_to_buyers.get(a, set()); bb = firm_to_buyers.get(b, set())
        cbuy = int(len(ba & bb) > 0)

        return dict(
            a=a, b=b, tag=tag, label=label,
            labor_cos_2009=lc,
            worker_flow_log=wf,
            log_ov_full=ov_full,
            log_ov_pre=ov_pre,
            log_ov_post=ov_post,
            cnae_match=cnae_m,
            cobid_ind=cobid,
            common_buyer=cbuy,
        )

    rows = [pair_row(a, b, pair_to_tag[(a, b)], 1) for (a, b) in positive_set]
    rows += [pair_row(a, b, "_ctrl_", 0) for (a, b) in neg_set]
    D = pd.DataFrame(rows)

    # Use the FULL frame (do not drop rows missing labor_cos_2009 — worker_flow
    # is defined for all pairs, so the primary sample is the full frame).
    n_pos_total = int((D["label"] == 1).sum())
    n_neg_total = int((D["label"] == 0).sum())
    log(f"  frame: {len(D):,}  pos={n_pos_total}  neg={n_neg_total:,}", t0)
    D.to_parquet(OUT_FRAME, index=False)
    log(f"  saved → {OUT_FRAME}", t0)

    # ── 10. Single-feature LOO AUCs ─────────────────────────────────────────
    log("Step 10: single-feature LOOs", t0)
    single_feats = [
        "worker_flow_log", "labor_cos_2009",
        "log_ov_full", "log_ov_pre", "log_ov_post",
        "cnae_match", "cobid_ind", "common_buyer",
    ]
    single = {}
    for f in single_feats:
        p, m, folds, _, _, _ = loo(D, [f], setor_list)
        single[f] = (p, m, folds)
        log(f"  {f:<20s}  pooled={p:.4f}  macro={m:.4f}", t0)

    # ── 11. Composite LOO AUCs ──────────────────────────────────────────────
    log("Step 11: composite LOOs", t0)
    composites = [
        ("M1 worker_flow + log_ov_full",
         ["worker_flow_log", "log_ov_full"]),
        ("M0 labor_cos_2009 + log_ov_full",
         ["labor_cos_2009", "log_ov_full"]),
        ("S1 log_ov_full alone",
         ["log_ov_full"]),
        ("S2 cnae_match + log_ov_full",
         ["cnae_match", "log_ov_full"]),
        ("S3 worker_flow_log alone",
         ["worker_flow_log"]),
        ("S4 cnae_match alone",
         ["cnae_match"]),
        ("S5 worker_flow + cnae_match + log_ov_full",
         ["worker_flow_log", "cnae_match", "log_ov_full"]),
        ("S6 worker_flow + log_ov_pre",
         ["worker_flow_log", "log_ov_pre"]),
    ]
    comp = {}
    oof_by_spec = {}
    for name, feats in composites:
        p, m, folds, oof, y_used, tag_used = loo(D, feats, setor_list)
        comp[name] = (p, m, folds)
        oof_by_spec[name] = (oof, y_used)
        log(f"  {name:<42s} pooled={p:.4f}  macro={m:.4f}", t0)

    # ── 12. Cluster bootstrap on main composite ────────────────────────────
    log(f"Step 12: cluster bootstrap (B={N_BOOT}) on main composite", t0)
    informative = [s for s in setor_list if s not in ("sacos_de_lixo", "cafeteria_aeroporto")]
    main_feats = ["worker_flow_log", "log_ov_full"]
    ref_feats = ["log_ov_full"]

    pos_by_tag = {s: D[(D["label"] == 1) & (D["tag"] == s)] for s in informative}
    neg = D[D["label"] == 0]

    boot_main_pooled = np.zeros(N_BOOT)
    boot_main_macro = np.zeros(N_BOOT)
    boot_ref_pooled = np.zeros(N_BOOT)
    boot_ref_macro = np.zeros(N_BOOT)
    boot_diff_pooled = np.zeros(N_BOOT)
    boot_diff_macro = np.zeros(N_BOOT)

    for b in range(N_BOOT):
        draw = rng.choice(informative, size=len(informative), replace=True)
        parts = [pos_by_tag[s] for s in draw]
        parts.append(neg.sample(n=len(neg), replace=True, random_state=b + 30000))
        D_b = pd.concat(parts, ignore_index=True)
        p_m, m_m, _, _, _, _ = loo(D_b, main_feats, list(set(draw)))
        p_r, m_r, _, _, _, _ = loo(D_b, ref_feats, list(set(draw)))
        boot_main_pooled[b] = p_m
        boot_main_macro[b] = m_m
        boot_ref_pooled[b] = p_r
        boot_ref_macro[b] = m_r
        boot_diff_pooled[b] = p_m - p_r
        boot_diff_macro[b] = m_m - m_r
        if (b + 1) % 100 == 0:
            log(f"  bootstrap {b+1}/{N_BOOT}", t0)

    def pct(x, pcts=(2.5, 97.5)):
        x = x[~np.isnan(x)]
        if len(x) == 0: return (np.nan, np.nan)
        return tuple(np.percentile(x, pcts))

    ci_main_p = pct(boot_main_pooled)
    ci_main_m = pct(boot_main_macro)
    ci_ref_p = pct(boot_ref_pooled)
    ci_ref_m = pct(boot_ref_macro)
    ci_diff_p = pct(boot_diff_pooled)
    ci_diff_m = pct(boot_diff_macro)
    p_diff_p = float((boot_diff_pooled <= 0).mean())
    p_diff_m = float((boot_diff_macro <= 0).mean())

    log(f"  main pooled: mean {np.nanmean(boot_main_pooled):.4f}  "
        f"CI [{ci_main_p[0]:.4f}, {ci_main_p[1]:.4f}]", t0)
    log(f"  main macro:  mean {np.nanmean(boot_main_macro):.4f}  "
        f"CI [{ci_main_m[0]:.4f}, {ci_main_m[1]:.4f}]", t0)
    log(f"  diff pooled: mean {np.nanmean(boot_diff_pooled):+.4f}  "
        f"CI [{ci_diff_p[0]:+.4f}, {ci_diff_p[1]:+.4f}]  p(≤0) = {p_diff_p:.3f}", t0)
    log(f"  diff macro:  mean {np.nanmean(boot_diff_macro):+.4f}  "
        f"CI [{ci_diff_m[0]:+.4f}, {ci_diff_m[1]:+.4f}]  p(≤0) = {p_diff_m:.3f}", t0)

    # ── 13. Permutation null ────────────────────────────────────────────────
    log(f"Step 13: permutation null (B={N_PERM}) on main composite", t0)
    y_orig = D["label"].values.copy()
    perm_pooled = np.zeros(N_PERM)
    perm_macro = np.zeros(N_PERM)
    for b in range(N_PERM):
        D_p = D.copy()
        D_p["label"] = rng.permutation(y_orig)
        D_p.loc[D_p["label"] == 1, "tag"] = rng.choice(informative,
                                                         size=(D_p["label"] == 1).sum())
        p_, m_, _, _, _, _ = loo(D_p, main_feats, informative)
        perm_pooled[b] = p_
        perm_macro[b] = m_
        if (b + 1) % 100 == 0:
            log(f"  permutation {b+1}/{N_PERM}", t0)

    perm_p_pooled = float((perm_pooled >= comp["M1 worker_flow + log_ov_full"][0]).mean())
    perm_p_macro = float((perm_macro >= comp["M1 worker_flow + log_ov_full"][1]).mean())
    log(f"  perm pooled: mean {perm_pooled.mean():.4f} 95p={np.percentile(perm_pooled,95):.4f}"
        f"  p={perm_p_pooled:.4f}", t0)
    log(f"  perm macro:  mean {perm_macro.mean():.4f} 95p={np.percentile(perm_macro,95):.4f}"
        f"  p={perm_p_macro:.4f}", t0)

    # ── 14. Write report ────────────────────────────────────────────────────
    with open(OUT_REPORT, "w") as f:
        f.write("Paper master — revised for Path A (worker flow primary)\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 72 + "\n\n")

        f.write("SAMPLE\n")
        f.write("-" * 50 + "\n")
        f.write(f"  Cartel firms (unique after dedup): {len(cartel_firms)}\n")
        f.write(f"  Cartel sectors:                    {len(setor_list)}\n")
        f.write(f"  Positive pairs:                    {n_pos_total}\n")
        f.write(f"  Negative pairs:                    {n_neg_total:,}\n\n")

        f.write("CARTEL META\n")
        f.write("-" * 50 + "\n")
        for _, r in cartel_meta.iterrows():
            n_p = int(sum(1 for k, t in pair_to_tag.items() if t == r["setor"]))
            f.write(f"  {r['setor']:<22s} firms={int(r['n_firms']):>2}  "
                    f"years={int(r['s_year'])}--{int(r['e_year'])}  "
                    f"pairs={n_p}\n")
        f.write("\n")

        f.write("SINGLE-FEATURE LOO AUC (pooled / macro)\n")
        f.write("-" * 50 + "\n")
        f.write(f"  {'feature':<22s}  {'pooled':>8s}  {'macro':>8s}\n")
        for k, (p, m, _) in single.items():
            f.write(f"  {k:<22s}  {p:>8.4f}  {m:>8.4f}\n")
        f.write("\n")

        f.write("COMPOSITE LOO AUC (pooled / macro)\n")
        f.write("-" * 50 + "\n")
        f.write(f"  {'specification':<44s}  {'pooled':>8s}  {'macro':>8s}\n")
        for k, (p, m, _) in comp.items():
            f.write(f"  {k:<44s}  {p:>8.4f}  {m:>8.4f}\n")
        f.write("\n")

        f.write("MAIN COMPOSITE (M1: worker_flow + log_ov_full) per-fold AUCs\n")
        f.write("-" * 50 + "\n")
        _, _, folds = comp["M1 worker_flow + log_ov_full"]
        for s, auc in folds.items():
            n_p = int(((D["label"] == 1) & (D["tag"] == s)).sum())
            auc_str = f"{auc:.4f}" if not np.isnan(auc) else "nan"
            f.write(f"  {s:<22s}  n_pos={n_p:>3}  AUC={auc_str}\n")
        f.write("\n")

        f.write("CLUSTER BOOTSTRAP (B = {}) on MAIN COMPOSITE\n".format(N_BOOT))
        f.write("-" * 50 + "\n")
        f.write(f"  main pooled AUC:  mean = {np.nanmean(boot_main_pooled):.4f}  "
                f"95% CI [{ci_main_p[0]:.4f}, {ci_main_p[1]:.4f}]\n")
        f.write(f"  main macro AUC:   mean = {np.nanmean(boot_main_macro):.4f}  "
                f"95% CI [{ci_main_m[0]:.4f}, {ci_main_m[1]:.4f}]\n")
        f.write(f"  ref  pooled AUC:  mean = {np.nanmean(boot_ref_pooled):.4f}  "
                f"95% CI [{ci_ref_p[0]:.4f}, {ci_ref_p[1]:.4f}]\n")
        f.write(f"  ref  macro AUC:   mean = {np.nanmean(boot_ref_macro):.4f}  "
                f"95% CI [{ci_ref_m[0]:.4f}, {ci_ref_m[1]:.4f}]\n")
        f.write(f"  diff pooled:      mean = {np.nanmean(boot_diff_pooled):+.4f}  "
                f"95% CI [{ci_diff_p[0]:+.4f}, {ci_diff_p[1]:+.4f}]  "
                f"p(≤0) = {p_diff_p:.3f}\n")
        f.write(f"  diff macro:       mean = {np.nanmean(boot_diff_macro):+.4f}  "
                f"95% CI [{ci_diff_m[0]:+.4f}, {ci_diff_m[1]:+.4f}]  "
                f"p(≤0) = {p_diff_m:.3f}\n\n")

        f.write("PERMUTATION NULL (B = {}) on MAIN COMPOSITE\n".format(N_PERM))
        f.write("-" * 50 + "\n")
        f.write(f"  null pooled: mean = {perm_pooled.mean():.4f}  "
                f"99th pct = {np.percentile(perm_pooled, 99):.4f}\n")
        f.write(f"  null macro:  mean = {perm_macro.mean():.4f}  "
                f"99th pct = {np.percentile(perm_macro, 99):.4f}\n")
        f.write(f"  observed pooled: {comp['M1 worker_flow + log_ov_full'][0]:.4f}  "
                f"p = {perm_p_pooled:.4f}\n")
        f.write(f"  observed macro:  {comp['M1 worker_flow + log_ov_full'][1]:.4f}  "
                f"p = {perm_p_macro:.4f}\n\n")

        f.write("LOGISTIC COEFFICIENTS (full-sample, standardized, main composite)\n")
        f.write("-" * 50 + "\n")
        X = D[main_feats].values.astype(float)
        y = D["label"].values.astype(int)
        w, mu, sd = fit_logit(X, y)
        f.write(f"  intercept           : {w[0]:+.4f}\n")
        for i, f_ in enumerate(main_feats):
            f.write(f"  {f_:<20s}: {w[i+1]:+.4f}\n")

    log(f"report → {OUT_REPORT}", t0)
    print("\n" + OUT_REPORT.read_text())

    # ── 15. ROC figure ──────────────────────────────────────────────────────
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        def roc(scores, labels):
            order = np.argsort(-scores)
            yy = labels[order]
            tps = np.cumsum(yy == 1); fps = np.cumsum(yy == 0)
            n_p = max(int((labels == 1).sum()), 1)
            n_n = max(int((labels == 0).sum()), 1)
            return fps / n_n, tps / n_p

        fig, ax = plt.subplots(figsize=(7, 6))

        oof_main, y_main = oof_by_spec["M1 worker_flow + log_ov_full"]
        mask = ~np.isnan(oof_main)
        fpr_m, tpr_m = roc(oof_main[mask], y_main[mask])
        ax.plot(fpr_m, tpr_m, color="black", linewidth=2.5,
                label=f"worker_flow + overlap (pooled={comp['M1 worker_flow + log_ov_full'][0]:.3f}, "
                      f"macro={comp['M1 worker_flow + log_ov_full'][1]:.3f})")

        oof_s1, y_s1 = oof_by_spec["S1 log_ov_full alone"]
        mask_s1 = ~np.isnan(oof_s1)
        fpr_s1, tpr_s1 = roc(oof_s1[mask_s1], y_s1[mask_s1])
        ax.plot(fpr_s1, tpr_s1, color="#2166ac", linewidth=1.8, linestyle="--",
                label=f"overlap alone (pooled={comp['S1 log_ov_full alone'][0]:.3f}, "
                      f"macro={comp['S1 log_ov_full alone'][1]:.3f})")

        oof_s2, y_s2 = oof_by_spec["S2 cnae_match + log_ov_full"]
        mask_s2 = ~np.isnan(oof_s2)
        fpr_s2, tpr_s2 = roc(oof_s2[mask_s2], y_s2[mask_s2])
        ax.plot(fpr_s2, tpr_s2, color="#b2182b", linewidth=1.8, linestyle=":",
                label=f"CNAE4 + overlap (pooled={comp['S2 cnae_match + log_ov_full'][0]:.3f}, "
                      f"macro={comp['S2 cnae_match + log_ov_full'][1]:.3f})")

        ax.plot([0, 1], [0, 1], "--", color="grey", linewidth=0.8)
        ax.set_xlabel("False positive rate")
        ax.set_ylabel("True positive rate")
        ax.set_title("Leave-one-CADE-cartel-out ROC (pooled)")
        ax.legend(loc="lower right", fontsize=9)
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)
        fig.tight_layout()
        fig.savefig(OUT_FIG, dpi=300, bbox_inches="tight")
        plt.close(fig)
        log(f"figure → {OUT_FIG}", t0)
    except ImportError:
        pass

    log(f"DONE ({time.time()-t0:.1f}s)", t0)


if __name__ == "__main__":
    main()
