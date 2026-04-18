#!/usr/bin/env python3
"""
64_permutation_standalone.py — Standalone permutation null for main composite

Tests whether the main composite's pooled and macro AUCs exceed what a
label-permutation null would produce. Uses a subsample of the negative
class (20k pairs) for speed so that B=500 permutations each with full
LOO-CV completes in reasonable time. The point estimates for the
composite on this subsample are nearly identical to the full-sample
paper_master estimates.
"""
from __future__ import annotations
import time
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.stats import mannwhitneyu

BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")
INTER = BASE / "02_data" / "intermediate"
FRAME = INTER / "paper_master.parquet"
OUT_SUB = INTER / "permutation_null.txt"
OUT_FULL = INTER / "permutation_null_full.txt"

N_NEG_SUB = 20_000
N_PERM = 500
SEED = 42
# Full-frame variant controlled via CLI arg "full"
FEATS = ["worker_flow_log", "log_ov_full"]


def log(msg, t0):
    print(f"[{time.time()-t0:6.1f}s] {msg}", flush=True)


def mw(pos, neg):
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
        Xn = np.column_stack([np.ones(len(X_ev)), (X_ev - mu) / sd])
        oof[ev.values] = Xn @ w
    m = ~np.isnan(oof)
    pooled = mw(oof[m][y[m] == 1], oof[m][y[m] == 0])
    valid = [mw(oof[(y == 1) & m & (D_in["tag"] == s)],
                 oof[(y == 0) & m])
              for s in setor_list
              if ((D_in["label"] == 1) & (D_in["tag"] == s)).sum() > 0]
    valid = [v for v in valid if not np.isnan(v)]
    macro = float(np.mean(valid)) if valid else float("nan")
    return pooled, macro


def main():
    import sys
    use_full = "full" in sys.argv
    t0 = time.time()
    log(f"loading frame (mode={'FULL' if use_full else 'SUBSAMPLE'})", t0)
    D = pd.read_parquet(FRAME)

    rng = np.random.default_rng(SEED)
    pos = D[D["label"] == 1]
    neg = D[D["label"] == 0]
    log(f"full: {len(D):,} pos={len(pos)} neg={len(neg):,}", t0)
    if use_full:
        Ds = D.reset_index(drop=True)
        log(f"using full frame: {len(Ds):,} pos={len(pos)} neg={len(neg):,}", t0)
    else:
        neg_sub = neg.sample(n=min(N_NEG_SUB, len(neg)), random_state=SEED)
        Ds = pd.concat([pos, neg_sub], ignore_index=True)
        log(f"subsample: {len(Ds):,} pos={len(pos)} neg={len(neg_sub):,}", t0)

    setor_list = sorted(Ds[Ds["label"] == 1]["tag"].unique())
    log(f"setors: {setor_list}", t0)

    # Observed AUCs on subsample
    obs_pooled, obs_macro = loo(Ds, FEATS, setor_list)
    log(f"observed: pooled={obs_pooled:.4f}  macro={obs_macro:.4f}", t0)

    # Permutation null
    log(f"running {N_PERM} permutations", t0)
    null_pooled = np.zeros(N_PERM)
    null_macro = np.zeros(N_PERM)
    y_orig = Ds["label"].values.copy()
    tag_orig = Ds["tag"].values.copy()

    # Pre-compute the set of cartel tags for label shuffling
    cartel_tags_per_pos = tag_orig[y_orig == 1]

    for b in range(N_PERM):
        perm = rng.permutation(y_orig)
        new_tag = np.where(perm == 1,
                            rng.choice(cartel_tags_per_pos, size=len(perm)),
                            "_ctrl_")
        Dp = Ds.copy()
        Dp["label"] = perm
        Dp["tag"] = new_tag
        p, m = loo(Dp, FEATS, setor_list)
        null_pooled[b] = p
        null_macro[b] = m
        if (b + 1) % 100 == 0:
            log(f"  perm {b+1}/{N_PERM}", t0)

    p_pooled = float((null_pooled >= obs_pooled).mean())
    p_macro = float((null_macro >= obs_macro).mean())

    out_path = OUT_FULL if use_full else OUT_SUB
    with open(out_path, "w") as f:
        f.write("Permutation null test on main composite\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 60 + "\n\n")
        f.write(f"Subsample: {len(Ds):,} pairs ({len(pos)} pos, "
                f"{len(neg_sub):,} neg)\n")
        f.write(f"Permutations: {N_PERM}\n\n")
        f.write("OBSERVED\n")
        f.write(f"  pooled AUC: {obs_pooled:.4f}\n")
        f.write(f"  macro  AUC: {obs_macro:.4f}\n\n")
        f.write("NULL DISTRIBUTION\n")
        f.write(f"  pooled mean = {null_pooled.mean():.4f}  "
                f"95p = {np.percentile(null_pooled, 95):.4f}  "
                f"99p = {np.percentile(null_pooled, 99):.4f}\n")
        f.write(f"  macro  mean = {null_macro.mean():.4f}  "
                f"95p = {np.percentile(null_macro, 95):.4f}  "
                f"99p = {np.percentile(null_macro, 99):.4f}\n\n")
        f.write("EMPIRICAL P-VALUES\n")
        f.write(f"  p(pooled >= observed) = {p_pooled:.4f}\n")
        f.write(f"  p(macro  >= observed) = {p_macro:.4f}\n")

    log(f"report → {out_path}", t0)
    print("\n" + out_path.read_text())
    log(f"DONE ({time.time()-t0:.1f}s)", t0)


if __name__ == "__main__":
    main()
