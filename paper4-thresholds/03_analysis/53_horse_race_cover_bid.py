#!/usr/bin/env python3
"""
53_horse_race_cover_bid.py — Horse race A: Cover-Bid Networks

Minimum-viable diagnostic for Idea A.

For each auction, identify winner (rank 1) and runner-up (rank 2) by bid.
Build the directed matrix Q with q_{ij} = P(j is runner-up | i is winner).

Three tests:
  (1) Entropy row-test: cartel winners should have lower H(q_{i·})
      than non-cartel winners (concentration on a few cover-bid partners).
  (2) Dyad concentration: q_{ij} for within-setor-cartel ordered pairs
      should rank higher than q_{ij} for non-cartel ordered pairs
      (classify as AUC of Mann-Whitney).
  (3) Asymmetry: |q_{ij} - q_{ji}| should be higher for within-setor
      cartel pairs (rotation creates directed structure).

Decision rule:
  STRONG  if entropy AUC ≥ 0.65 OR dyad AUC ≥ 0.70 OR asym AUC ≥ 0.65
  WEAK    if any AUC ≥ 0.55
  DEAD    otherwise
"""
from __future__ import annotations
import time
from pathlib import Path
import numpy as np
import pandas as pd
import duckdb
from scipy.stats import mannwhitneyu

BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")
FINAL = BASE / "02_data" / "final"
FIRMS = BASE / "02_data" / "firms"
INTER = BASE / "02_data" / "intermediate"

PAIRS_PREGAO = str(FINAL / "df_pregao_with_cartel_flags.parquet")
GROUND_TRUTH = str(FIRMS / "cade_ground_truth.parquet")

OUT = INTER / "horse_race_cover_bid.txt"
MIN_WINS = 20


def log(msg, t0):
    print(f"[{time.time()-t0:6.1f}s] {msg}", flush=True)


def mw_auc(pos, neg, alternative="greater"):
    if len(pos) == 0 or len(neg) == 0:
        return float("nan"), float("nan")
    stat, p = mannwhitneyu(pos, neg, alternative=alternative)
    auc = stat / (len(pos) * len(neg))
    return float(auc), float(p)


def main():
    t0 = time.time()
    INTER.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect()
    con.sql("PRAGMA threads=12; PRAGMA memory_limit='14GB'")

    # 1. Cartel ground truth
    log("Step 1: cartels", t0)
    con.sql(f"""
        CREATE TABLE cf AS
        SELECT DISTINCT cnpj_raiz, setor
        FROM read_parquet('{GROUND_TRUTH}')
        WHERE sp_relevant = 1
          AND processo IS NOT NULL
          AND cartel_start_year IS NOT NULL
          AND cartel_end_year <= 2016
    """)
    cf_df = con.sql("SELECT cnpj_raiz, setor FROM cf").fetchdf()
    cartel_set = set(cf_df["cnpj_raiz"])
    firm_to_setor = dict(zip(cf_df["cnpj_raiz"], cf_df["setor"]))
    log(f"  cartel firms: {len(cf_df)}, setores: {cf_df['setor'].nunique()}", t0)

    # 2. Rank bids within each auction_item; identify rank-1 (winner)
    #    and rank-2 (runner-up)
    log("Step 2: ranking bids", t0)
    con.sql(f"""
        CREATE TABLE ranked AS
        SELECT auction_item,
               year,
               cnpj_raiz AS firm,
               valorunitárioproposta AS bid,
               ROW_NUMBER() OVER (
                   PARTITION BY auction_item
                   ORDER BY valorunitárioproposta ASC
               ) AS rnk
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE cnpj_raiz IS NOT NULL
          AND valorunitárioproposta > 0
          AND valorunitárioproposta < 1e9
    """)
    con.sql("""
        CREATE TABLE wr AS
        SELECT a.auction_item, a.year,
               a.firm AS winner,
               b.firm AS runner_up
        FROM ranked a
        JOIN ranked b ON a.auction_item = b.auction_item
        WHERE a.rnk = 1 AND b.rnk = 2 AND a.firm != b.firm
    """)
    n_wr = con.sql("SELECT COUNT(*) FROM wr").fetchone()[0]
    log(f"  winner+runner-up events: {n_wr:,}", t0)

    # 3. Build Q = P(j runner-up | i winner)
    log("Step 3: building Q matrix", t0)
    con.sql("""
        CREATE TABLE wins_by_winner AS
        SELECT winner, COUNT(*) AS n_wins
        FROM wr GROUP BY winner
    """)
    con.sql("""
        CREATE TABLE pair_counts AS
        SELECT winner, runner_up, COUNT(*) AS n_pair
        FROM wr GROUP BY winner, runner_up
    """)
    con.sql("""
        CREATE TABLE Q AS
        SELECT p.winner, p.runner_up, p.n_pair, w.n_wins,
               p.n_pair::DOUBLE / w.n_wins::DOUBLE AS q
        FROM pair_counts p
        JOIN wins_by_winner w USING (winner)
    """)
    Q_df = con.sql(f"""
        SELECT winner, runner_up, n_pair, n_wins, q
        FROM Q WHERE n_wins >= {MIN_WINS}
    """).fetchdf()
    log(f"  Q rows (winners with ≥{MIN_WINS} wins): {len(Q_df):,}", t0)

    # 4. Entropy test
    log("Step 4: entropy row-test", t0)
    ent_df = (
        Q_df.assign(term=lambda d: -d["q"] * np.log(d["q"]))
        .groupby("winner")
        .agg(entropy=("term", "sum"),
             n_distinct_ru=("runner_up", "count"),
             n_wins=("n_wins", "first"))
        .reset_index()
    )
    ent_df["is_cartel"] = ent_df["winner"].isin(cartel_set).astype(int)
    cartel_ent = ent_df[ent_df["is_cartel"] == 1]["entropy"].values
    nonc_ent   = ent_df[ent_df["is_cartel"] == 0]["entropy"].values
    log(f"  cartel n={len(cartel_ent)}  mean={cartel_ent.mean():.3f}  "
        f"median={np.median(cartel_ent):.3f}", t0)
    log(f"  non-cartel n={len(nonc_ent):,}  mean={nonc_ent.mean():.3f}  "
        f"median={np.median(nonc_ent):.3f}", t0)

    # Cartel should have LOWER entropy → use alternative="less"
    auc_ent, p_ent = mw_auc(cartel_ent, nonc_ent, alternative="less")
    # For "lower is positive class" we use 1 - AUC convention
    # mannwhitneyu with alternative="less" gives U such that
    # stat / (n_pos n_neg) is the "probability cartel < non-cartel"
    # which is what we want to report as AUC for "low entropy classifier"
    log(f"  entropy AUC (cartel lower) = {auc_ent:.4f}  p = {p_ent:.4f}", t0)

    # 5. Dyad concentration test
    log("Step 5: dyad concentration", t0)
    Q_df["winner_in_cartel"] = Q_df["winner"].isin(cartel_set)
    Q_df["runner_in_cartel"] = Q_df["runner_up"].isin(cartel_set)
    Q_df["winner_setor"] = Q_df["winner"].map(firm_to_setor)
    Q_df["runner_setor"] = Q_df["runner_up"].map(firm_to_setor)
    Q_df["same_setor_cartel"] = (
        Q_df["winner_in_cartel"]
        & Q_df["runner_in_cartel"]
        & (Q_df["winner_setor"] == Q_df["runner_setor"])
    ).astype(int)
    Q_df["ctrl_ctrl"] = (
        (~Q_df["winner_in_cartel"]) & (~Q_df["runner_in_cartel"])
    ).astype(int)

    pos_pairs = Q_df[Q_df["same_setor_cartel"] == 1]
    neg_pairs = Q_df[Q_df["ctrl_ctrl"] == 1]
    log(f"  same-setor-cartel pairs: {len(pos_pairs):,}", t0)
    log(f"  ctrl-ctrl pairs:         {len(neg_pairs):,}", t0)

    auc_dyad, p_dyad = mw_auc(pos_pairs["q"].values, neg_pairs["q"].values,
                               alternative="greater")
    log(f"  dyad q AUC = {auc_dyad:.4f}  p = {p_dyad:.4f}", t0)

    # Also test n_pair (raw count) to check if it's q or the scale
    auc_npair, p_npair = mw_auc(pos_pairs["n_pair"].values,
                                 neg_pairs["n_pair"].values,
                                 alternative="greater")
    log(f"  dyad n_pair AUC = {auc_npair:.4f}  p = {p_npair:.4f}", t0)

    # 6. Asymmetry test: |q_{ij} - q_{ji}|
    log("Step 6: asymmetry", t0)
    Q_small = Q_df[["winner", "runner_up", "q"]].copy()
    Q_rev = Q_small.rename(columns={"winner": "runner_up", "runner_up": "winner",
                                      "q": "q_rev"})
    Q_sym = Q_df.merge(Q_rev, on=["winner", "runner_up"], how="left")
    Q_sym["q_rev"] = Q_sym["q_rev"].fillna(0)
    Q_sym["asym"] = (Q_sym["q"] - Q_sym["q_rev"]).abs()

    pos_a = Q_sym[Q_sym["same_setor_cartel"] == 1]["asym"].values
    neg_a = Q_sym[Q_sym["ctrl_ctrl"] == 1]["asym"].values
    auc_asym, p_asym = mw_auc(pos_a, neg_a, alternative="greater")
    log(f"  asym AUC = {auc_asym:.4f}  p = {p_asym:.4f}", t0)

    con.close()

    # 7. Report
    with open(OUT, "w") as f:
        f.write("Horse race A: Cover-Bid Networks\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")

        f.write("DESIGN\n")
        f.write("-" * 50 + "\n")
        f.write("  Winner = rank 1 bid (lowest) in each auction_item.\n")
        f.write("  Runner-up = rank 2 bid.\n")
        f.write("  Q[i,j] = P(j is runner-up | i wins).\n")
        f.write("  Positive class: ordered pair where both firms are in the\n")
        f.write("    same CADE-convicted setor.\n")
        f.write("  Negative class: ordered pair where neither firm is in any\n")
        f.write("    convicted cartel.\n\n")

        f.write("SAMPLE\n")
        f.write("-" * 50 + "\n")
        f.write(f"  Winner+runner-up events: {n_wr:,}\n")
        f.write(f"  Q rows (min {MIN_WINS} wins): {len(Q_df):,}\n")
        f.write(f"  Firms with ≥{MIN_WINS} wins: {len(ent_df):,}\n\n")

        f.write("TEST 1 — ENTROPY ROW-TEST (cartel winners have LOWER entropy)\n")
        f.write("-" * 50 + "\n")
        f.write(f"  Cartel winners:     n = {len(cartel_ent):>5,}  "
                f"mean H = {cartel_ent.mean():.4f}  "
                f"median = {np.median(cartel_ent):.4f}\n")
        f.write(f"  Non-cartel winners: n = {len(nonc_ent):>5,}  "
                f"mean H = {nonc_ent.mean():.4f}  "
                f"median = {np.median(nonc_ent):.4f}\n")
        f.write(f"  AUC (cartel lower) = {auc_ent:.4f}   p = {p_ent:.4f}\n\n")

        f.write("TEST 2 — DYAD CONCENTRATION (q higher for cartel pairs)\n")
        f.write("-" * 50 + "\n")
        f.write(f"  Positive pairs (same setor cartel):  n = {len(pos_pairs):>6,}\n")
        f.write(f"    mean q = {pos_pairs['q'].mean():.4f}\n")
        f.write(f"    mean n_pair = {pos_pairs['n_pair'].mean():.2f}\n")
        f.write(f"  Negative pairs (ctrl × ctrl):        n = {len(neg_pairs):>6,}\n")
        f.write(f"    mean q = {neg_pairs['q'].mean():.4f}\n")
        f.write(f"    mean n_pair = {neg_pairs['n_pair'].mean():.2f}\n")
        f.write(f"  AUC (q)      = {auc_dyad:.4f}  p = {p_dyad:.4f}\n")
        f.write(f"  AUC (n_pair) = {auc_npair:.4f}  p = {p_npair:.4f}\n\n")

        f.write("TEST 3 — ASYMMETRY |q_ij − q_ji| (cartel pairs higher)\n")
        f.write("-" * 50 + "\n")
        f.write(f"  Positive: mean |asym| = {pos_a.mean():.4f}\n")
        f.write(f"  Negative: mean |asym| = {neg_a.mean():.4f}\n")
        f.write(f"  AUC = {auc_asym:.4f}  p = {p_asym:.4f}\n\n")

        # Decision
        strong = (auc_ent >= 0.65) or (auc_dyad >= 0.70) or (auc_asym >= 0.65)
        weak   = (auc_ent >= 0.55) or (auc_dyad >= 0.60) or (auc_asym >= 0.55)
        verdict = ("✓ STRONG" if strong
                   else "△ WEAK" if weak
                   else "✗ DEAD")
        f.write("DECISION\n")
        f.write("-" * 50 + "\n")
        f.write(f"  entropy  AUC = {auc_ent:.4f}\n")
        f.write(f"  dyad q   AUC = {auc_dyad:.4f}\n")
        f.write(f"  asym     AUC = {auc_asym:.4f}\n")
        f.write(f"  Verdict: {verdict}\n")

    log(f"report → {OUT}", t0)
    print("\n" + OUT.read_text())


if __name__ == "__main__":
    main()
