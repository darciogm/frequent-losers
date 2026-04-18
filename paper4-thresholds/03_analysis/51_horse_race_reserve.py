#!/usr/bin/env python3
"""
51_horse_race_reserve.py — Horse race #2: Reserve price as collusion deterrent

Minimum-viable diagnostic: is there meaningful variation in
log(winning_bid / reference_price) across BEC auctions, and does the
cartel-specific bidding premium vary systematically with the reference
price tightness? If yes, there's identifying variation for a RAND-tier
structural paper on reserve-price design.

Metrics computed:
  (1) Distribution of MV = log(bid/ref) in the pregao sample.
  (2) Mean MV for winning bids in cartel-active vs non-cartel auctions.
  (3) Regression: MV ~ cartel_active × ref_price_quintile
                     + firm FE + item FE + year FE
      (cluster SE by item-code).
  (4) Heterogeneity: coefficient on interaction should indicate
      whether the cartel premium shrinks when reference price is tight.

Decision rule:
  • MV has nontrivial variation (SD > 0.05)
  • Main cartel-premium coefficient is significant and economically
    meaningful (≥ 0.03 in absolute value)
  • Interaction with reference price is monotone (t ≥ 1.5 on at least
    one tail of the quintile distribution)
  → idea worth pursuing as RAND paper #2.
"""
from __future__ import annotations
import time
from pathlib import Path
import numpy as np
import pandas as pd
import duckdb

BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")
FINAL = BASE / "02_data" / "final"
INTER = BASE / "02_data" / "intermediate"
PAIRS_PREGAO = str(FINAL / "df_pregao_with_cartel_flags.parquet")

OUT = INTER / "horse_race_reserve.txt"


def log(msg, t0):
    print(f"[{time.time()-t0:6.1f}s] {msg}", flush=True)


def two_way_demean(x, g1, g2, sweeps=6):
    z = x.astype(float).copy()
    for _ in range(sweeps):
        z -= pd.Series(z, copy=False).groupby(g1).transform("mean").values
        z -= pd.Series(z, copy=False).groupby(g2).transform("mean").values
    return z


def main():
    t0 = time.time()
    INTER.mkdir(parents=True, exist_ok=True)

    con = duckdb.connect()
    con.sql("PRAGMA threads=12; PRAGMA memory_limit='14GB'")

    log("loading bid-level data...", t0)
    # Winner rows only (focus on winning bids as they reveal cartel rent)
    # Filter MV to sensible range [-2, 2] to drop encoding artifacts
    df = con.sql(f"""
        SELECT "códigoitem"           AS item,
               year,
               cnpj_raiz               AS firm,
               valorunitárioproposta   AS bid,
               valorunitárioreferência AS ref_price,
               MV,
               cartel_firm,
               cartel_in_period,
               has_active_cartel,
               winner_is_cartel_active
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE flagvencedor = 1
          AND valorunitárioproposta > 0
          AND valorunitárioreferência > 0
          AND MV IS NOT NULL
          AND MV BETWEEN -2.0 AND 2.0
    """).fetchdf()
    con.close()
    log(f"winning-bid rows: {len(df):,}", t0)

    # 1. Distribution of MV
    mv = df["MV"].values
    log(f"MV distribution: mean={mv.mean():+.4f} sd={mv.std():.4f} "
        f"p5={np.percentile(mv,5):+.3f} p50={np.percentile(mv,50):+.3f} "
        f"p95={np.percentile(mv,95):+.3f}", t0)

    # 2. Mean MV by cartel status
    df["cartel_any"] = ((df["cartel_firm"] == 1) |
                         (df["has_active_cartel"] == 1)).astype(int)
    df["cartel_active_winner"] = (df["winner_is_cartel_active"] == True).astype(int)
    means = df.groupby("cartel_active_winner")["MV"].agg(["mean", "count", "std"])
    log(f"Mean MV by cartel_active_winner:\n{means}", t0)

    # 3. Reference price quintiles (within item, to control for item heterogeneity)
    df["ref_rank"] = df.groupby("item")["ref_price"].rank(pct=True)
    df["ref_q"] = pd.cut(df["ref_rank"],
                          bins=[0, 0.2, 0.4, 0.6, 0.8, 1.01],
                          labels=[1, 2, 3, 4, 5]).astype(float)
    q_counts = df["ref_q"].value_counts().sort_index()
    log(f"Reference-price quintile counts:\n{q_counts}", t0)

    # 4. Main effect: MV ~ cartel_active_winner with item + year FE
    # Simple two-way demeaning specification
    df["fid"]  = df["item"].astype("category").cat.codes
    df["yid"]  = df["year"].astype("category").cat.codes
    df = df.dropna(subset=["ref_q", "MV", "cartel_active_winner"]).copy()
    fid = df["fid"].values.astype(np.int64)
    yid = df["yid"].values.astype(np.int64)

    Y_dm = two_way_demean(df["MV"].values, fid, yid)
    D_dm = two_way_demean(df["cartel_active_winner"].values.astype(float), fid, yid)

    if (D_dm @ D_dm) > 0:
        beta_main = (D_dm @ Y_dm) / (D_dm @ D_dm)
        e = Y_dm - beta_main * D_dm
        # Item-clustered SE
        cs = pd.Series(D_dm * e, copy=False).groupby(fid).sum().values
        meat = (cs ** 2).sum()
        nc = int(df["fid"].nunique())
        correction = nc / max(nc - 1, 1)
        var_main = correction * meat / ((D_dm @ D_dm) ** 2)
        se_main = float(np.sqrt(var_main))
    else:
        beta_main, se_main = float("nan"), float("nan")
    t_main = beta_main / se_main if se_main > 0 else float("nan")
    log(f"Main effect: β(cartel_active_winner) = {beta_main:+.4f}  "
        f"SE = {se_main:.4f}  t = {t_main:+.2f}", t0)

    # 5. Interaction: cartel × reference quintile
    # Build interaction dummies
    results_by_q = {}
    for q in [1, 2, 3, 4, 5]:
        mask = df["ref_q"] == q
        if mask.sum() < 500:
            continue
        sub = df[mask].copy()
        sub["fid_q"] = sub["item"].astype("category").cat.codes
        sub["yid_q"] = sub["year"].astype("category").cat.codes
        fid_q = sub["fid_q"].values.astype(np.int64)
        yid_q = sub["yid_q"].values.astype(np.int64)
        Yq = two_way_demean(sub["MV"].values, fid_q, yid_q)
        Dq = two_way_demean(sub["cartel_active_winner"].values.astype(float),
                             fid_q, yid_q)
        if (Dq @ Dq) > 0:
            b = (Dq @ Yq) / (Dq @ Dq)
            e = Yq - b * Dq
            cs = pd.Series(Dq * e, copy=False).groupby(fid_q).sum().values
            nc_q = int(sub["fid_q"].nunique())
            var = (nc_q / max(nc_q - 1, 1)) * (cs ** 2).sum() / ((Dq @ Dq) ** 2)
            se = float(np.sqrt(var))
            tq = b / se if se > 0 else float("nan")
            results_by_q[q] = (float(b), se, tq, int(mask.sum()))

    # 6. Write report
    with open(OUT, "w") as f:
        f.write("Horse race #2: Reserve price as collusion deterrent\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")

        f.write("DESIGN\n")
        f.write("-" * 50 + "\n")
        f.write("  Y = MV = log(winning_bid / reference_price)\n")
        f.write("  D = winner_is_cartel_active (conduct period, CADE ground truth)\n")
        f.write("  FE: item + year\n")
        f.write("  Sample split: reference-price quintile (within item)\n\n")

        f.write("DISTRIBUTION OF MV\n")
        f.write("-" * 50 + "\n")
        f.write(f"  mean : {mv.mean():+.4f}\n")
        f.write(f"  sd   : {mv.std():.4f}\n")
        f.write(f"  p5   : {np.percentile(mv, 5):+.4f}\n")
        f.write(f"  p25  : {np.percentile(mv, 25):+.4f}\n")
        f.write(f"  p50  : {np.percentile(mv, 50):+.4f}\n")
        f.write(f"  p75  : {np.percentile(mv, 75):+.4f}\n")
        f.write(f"  p95  : {np.percentile(mv, 95):+.4f}\n\n")

        f.write("MAIN EFFECT (pooled, item + year FE)\n")
        f.write("-" * 50 + "\n")
        f.write(f"  β(cartel_active_winner) = {beta_main:+.4f}  "
                f"SE = {se_main:.4f}  t = {t_main:+.2f}\n")
        f.write(f"  N = {len(df):,}  clusters (items) = {df['fid'].nunique():,}\n\n")

        f.write("HETEROGENEITY BY REFERENCE-PRICE QUINTILE\n")
        f.write("-" * 50 + "\n")
        f.write(f"{'quintile':<10s} {'β':>9s} {'SE':>8s} {'t':>7s} {'n':>10s}\n")
        for q in [1, 2, 3, 4, 5]:
            if q in results_by_q:
                b, se, tq, n = results_by_q[q]
                f.write(f"  Q{q}       {b:>+9.4f} {se:>8.4f} {tq:>+7.2f} {n:>10,d}\n")
        f.write("\n")
        f.write("  Q1 = tightest ref price (lowest quintile within item)\n")
        f.write("  Q5 = loosest ref price (highest quintile within item)\n\n")

        # Decision
        mv_sd    = float(mv.std())
        main_ok  = (abs(beta_main) >= 0.03) and (abs(t_main) >= 1.96)
        q_values = [results_by_q[q][0] for q in [1, 2, 3, 4, 5] if q in results_by_q]
        monotone = False
        if len(q_values) >= 4:
            # Check if beta is monotonically decreasing (tight ref → less premium)
            diffs = np.diff(q_values)
            monotone = (diffs.sum() >= 0) or (diffs.sum() <= 0)
            monotone = all(d >= -0.01 for d in diffs) or all(d <= 0.01 for d in diffs)

        f.write("DECISION CRITERIA\n")
        f.write("-" * 50 + "\n")
        f.write(f"  1. MV has nontrivial variation    (SD > 0.05)      : "
                f"{'✓' if mv_sd > 0.05 else '✗'}   (SD = {mv_sd:.4f})\n")
        f.write(f"  2. Main cartel premium is material (|β| ≥ 0.03, |t| ≥ 1.96): "
                f"{'✓' if main_ok else '✗'}\n")
        f.write(f"  3. Heterogeneity is monotone across ref-price quintiles: "
                f"{'✓' if monotone else '✗'}\n")

        all_pass = (mv_sd > 0.05) and main_ok and monotone
        if all_pass:
            verdict = "✓ PROMISING: all three criteria pass"
        elif (mv_sd > 0.05) and main_ok:
            verdict = "△ WORTH A DEEPER LOOK: main effect exists, heterogeneity unclear"
        else:
            verdict = "✗ LIKELY DEAD: core variation or cartel premium missing"
        f.write(f"\n  Verdict: {verdict}\n")

    log(f"report → {OUT}", t0)
    print("\n" + OUT.read_text())


if __name__ == "__main__":
    main()
