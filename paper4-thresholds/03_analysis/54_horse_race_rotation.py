#!/usr/bin/env python3
"""
54_horse_race_rotation.py — Horse race C: Bid rotation autocorrelation

Minimum-viable diagnostic for Idea C.

Within the panel of repeated auctions of the same item code across years,
test whether convicted cartel members show:
  (a) higher SWAP rate   = P(winner_{t+1} = runner_up_t)
  (b) lower  PERSIST rate = P(winner_{t+1} = winner_t)
than competitive firms. Both are predictions of Porter-Zona bid rotation.

Design:
  • For each item × year, take the first auction (winner, runner-up).
  • Build within-item adjacent-year transitions with year_gap ≤ 3.
  • Classify each transition by whether the current winner is in a
    CADE-convicted setor matching the previous winner's or runner-up's
    setor — "cartel" transition.
  • Compare swap and persist rates cartel vs non-cartel.

Decision rule:
  STRONG  if swap test (p<0.05 AND ratio ≥ 1.5) AND persist test (p<0.05)
  PARTIAL if exactly one of the two tests passes
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

OUT = INTER / "horse_race_rotation.txt"


def log(msg, t0):
    print(f"[{time.time()-t0:6.1f}s] {msg}", flush=True)


def main():
    t0 = time.time()
    INTER.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect()
    con.sql("PRAGMA threads=12; PRAGMA memory_limit='14GB'")

    # 1. Cartels
    log("Step 1: cartels", t0)
    con.sql(f"""
        CREATE TABLE cf AS
        SELECT DISTINCT cnpj_raiz, setor
        FROM read_parquet('{GROUND_TRUTH}')
        WHERE sp_relevant = 1 AND processo IS NOT NULL
          AND cartel_start_year IS NOT NULL
          AND cartel_end_year <= 2016
    """)
    cf_df = con.sql("SELECT cnpj_raiz, setor FROM cf").fetchdf()
    firm_to_setor = dict(zip(cf_df["cnpj_raiz"], cf_df["setor"]))
    log(f"  cartel firms: {len(cf_df)}", t0)

    # 2. Rank bids per auction_item → winner + runner-up
    log("Step 2: ranking and extracting events", t0)
    con.sql(f"""
        CREATE TABLE ranked AS
        SELECT "códigoitem" AS item,
               auction_item,
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
        CREATE TABLE events AS
        SELECT item, auction_item, year,
               MAX(CASE WHEN rnk = 1 THEN firm END) AS winner,
               MAX(CASE WHEN rnk = 2 THEN firm END) AS runner_up
        FROM ranked
        GROUP BY item, auction_item, year
    """)
    ev = con.sql("""
        SELECT item, auction_item, year, winner, runner_up
        FROM events
        WHERE winner IS NOT NULL AND runner_up IS NOT NULL
    """).fetchdf()
    con.close()
    log(f"  events with W+RU: {len(ev):,}  items: {ev['item'].nunique():,}", t0)

    # 3. Collapse to one event per item × year (take first auction_item
    #    alphabetically). This defines the temporal sequence at item level.
    ev_sorted = ev.sort_values(["item", "year", "auction_item"])
    ev_item_year = ev_sorted.drop_duplicates(subset=["item", "year"], keep="first")
    log(f"  unique item × year events: {len(ev_item_year):,}", t0)

    # Count items with multi-year sequences
    counts = ev_item_year.groupby("item").size()
    multi = (counts >= 2).sum()
    log(f"  items with ≥2 years: {multi:,}", t0)

    # 4. Build within-item transitions
    ev_item_year = ev_item_year.sort_values(["item", "year"]).reset_index(drop=True)
    ev_item_year["prev_winner"] = ev_item_year.groupby("item")["winner"].shift(1)
    ev_item_year["prev_runner"] = ev_item_year.groupby("item")["runner_up"].shift(1)
    ev_item_year["prev_year"]   = ev_item_year.groupby("item")["year"].shift(1)
    trans = ev_item_year.dropna(subset=["prev_winner", "prev_runner"]).copy()
    trans["year_gap"] = trans["year"] - trans["prev_year"]
    trans = trans[trans["year_gap"].between(1, 3)]
    log(f"  transitions (year_gap ≤ 3): {len(trans):,}", t0)

    # 5. Define swap and persist
    trans["swap"]    = (trans["winner"] == trans["prev_runner"]).astype(int)
    trans["persist"] = (trans["winner"] == trans["prev_winner"]).astype(int)

    # 6. Classify transitions by cartel group
    def classify(row):
        curr_s = firm_to_setor.get(row["winner"])
        pw_s   = firm_to_setor.get(row["prev_winner"])
        pr_s   = firm_to_setor.get(row["prev_runner"])
        if curr_s is not None and (curr_s == pw_s or curr_s == pr_s):
            return "cartel"
        if curr_s is None and pw_s is None and pr_s is None:
            return "noncartel"
        return "mixed"

    trans["group"] = trans.apply(classify, axis=1)
    counts = trans["group"].value_counts()
    log(f"  group counts: {counts.to_dict()}", t0)

    # 7. Compute swap and persist rates by group
    swap_rates = trans.groupby("group")["swap"].agg(["mean", "count", "sum"])
    persist_rates = trans.groupby("group")["persist"].agg(["mean", "count", "sum"])
    log(f"  swap rates:\n{swap_rates}", t0)
    log(f"  persist rates:\n{persist_rates}", t0)

    # Tests: cartel vs noncartel
    def bin_test(x_pos, x_neg, alternative):
        if len(x_pos) == 0 or len(x_neg) == 0:
            return float("nan"), float("nan")
        stat, p = mannwhitneyu(x_pos, x_neg, alternative=alternative)
        return float(p), float(stat / (len(x_pos) * len(x_neg)))

    c_swap = trans[trans["group"] == "cartel"]["swap"].values
    n_swap = trans[trans["group"] == "noncartel"]["swap"].values
    p_swap, auc_swap = bin_test(c_swap, n_swap, "greater")
    ratio_swap = (c_swap.mean() / n_swap.mean()) if n_swap.mean() > 0 else float("nan")

    c_per = trans[trans["group"] == "cartel"]["persist"].values
    n_per = trans[trans["group"] == "noncartel"]["persist"].values
    p_per, auc_per = bin_test(c_per, n_per, "less")

    log(f"  swap:    cartel {c_swap.mean():.4f}  "
        f"noncartel {n_swap.mean():.4f}  ratio {ratio_swap:.2f}  "
        f"p {p_swap:.4f}", t0)
    log(f"  persist: cartel {c_per.mean():.4f}  "
        f"noncartel {n_per.mean():.4f}  p {p_per:.4f}", t0)

    # 8. Report
    with open(OUT, "w") as f:
        f.write("Horse race C: Bid rotation (swap + persist)\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")

        f.write("DESIGN\n")
        f.write("-" * 50 + "\n")
        f.write("  Event: first auction of each item × year, its (winner, runner-up).\n")
        f.write("  Transition: consecutive events (year_gap ≤ 3) within same item.\n")
        f.write("  Swap    = 1 if current winner = previous runner-up\n")
        f.write("  Persist = 1 if current winner = previous winner\n")
        f.write("  Group: cartel if current winner shares CADE-setor with previous\n")
        f.write("         winner or previous runner-up; noncartel otherwise.\n\n")

        f.write("SAMPLE\n")
        f.write("-" * 50 + "\n")
        f.write(f"  Auctions with W+RU:    {len(ev):,}\n")
        f.write(f"  Unique item-year events: {len(ev_item_year):,}\n")
        f.write(f"  Items with ≥2 years:   {multi:,}\n")
        f.write(f"  Transitions total:     {len(trans):,}\n")
        for g, n in counts.items():
            f.write(f"    {g:<10s}: {int(n):>10,}\n")
        f.write("\n")

        f.write("SWAP RATE (higher = bid rotation)\n")
        f.write("-" * 50 + "\n")
        for grp, row in swap_rates.iterrows():
            f.write(f"  {grp:<10s}: {row['mean']:.4f}  "
                    f"(n = {int(row['count']):>8,}, n_swaps = {int(row['sum']):>6,})\n")
        f.write(f"  Ratio cartel/noncartel: {ratio_swap:.2f}\n")
        f.write(f"  Mann-Whitney p (alt = greater): {p_swap:.4f}\n\n")

        f.write("PERSIST RATE (lower = bid rotation)\n")
        f.write("-" * 50 + "\n")
        for grp, row in persist_rates.iterrows():
            f.write(f"  {grp:<10s}: {row['mean']:.4f}  "
                    f"(n = {int(row['count']):>8,}, n_pers = {int(row['sum']):>6,})\n")
        f.write(f"  Mann-Whitney p (alt = less): {p_per:.4f}\n\n")

        # Decision
        swap_ok    = (p_swap < 0.05) and (ratio_swap >= 1.5)
        persist_ok = (p_per < 0.05)
        if swap_ok and persist_ok:
            verdict = "✓ STRONG: both tests pass"
        elif swap_ok or persist_ok:
            verdict = "△ PARTIAL: one test passes"
        else:
            verdict = "✗ DEAD: neither test passes"

        f.write("DECISION\n")
        f.write("-" * 50 + "\n")
        f.write(f"  swap criterion     (p<0.05 AND ratio≥1.5) : "
                f"{'✓' if swap_ok else '✗'}\n")
        f.write(f"  persist criterion  (p<0.05)               : "
                f"{'✓' if persist_ok else '✗'}\n")
        f.write(f"\n  Verdict: {verdict}\n")

    log(f"report → {OUT}", t0)
    print("\n" + OUT.read_text())


if __name__ == "__main__":
    main()
