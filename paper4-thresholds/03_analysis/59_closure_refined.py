#!/usr/bin/env python3
"""
59_closure_refined.py — Refined closure metric for §6.4

Improves on script 54 by conditioning on BOTH members of year-t's
(winner, runner-up) pair remaining active bidders in year t+1. This
removes the confounder of "winner or runner-up dropped out" and gives
a cleaner reading of market-set closure as a cartel fingerprint.

Three closure rates reported:
  (1) Unconditional closure (as in 54)
  (2) Conditional on both t-pair members bidding in t+1
  (3) Conditional on both t-pair members bidding in the SAME ITEM in t+1
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

OUT = INTER / "closure_refined.txt"


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
    firm_to_setor = dict(
        con.sql("SELECT cnpj_raiz, setor FROM cf").fetchall()
    )

    # 2. Rank bids and extract events (same as 54)
    log("Step 2: events and participation", t0)
    con.sql(f"""
        CREATE TABLE ranked AS
        SELECT "códigoitem" AS item, auction_item, year,
               cnpj_raiz AS firm, valorunitárioproposta AS bid,
               ROW_NUMBER() OVER (PARTITION BY auction_item
                                   ORDER BY valorunitárioproposta ASC) AS rnk
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

    # Participation: firm × item × year set
    part = con.sql("""
        SELECT DISTINCT item, year, firm
        FROM ranked
    """).fetchdf()
    part_set = set(zip(part["item"].values, part["year"].values,
                        part["firm"].values))
    log(f"  firm × item × year participation rows: {len(part):,}", t0)

    # Firm × year participation (any item)
    firm_year = con.sql("""
        SELECT DISTINCT year, firm FROM ranked
    """).fetchdf()
    firm_year_set = set(zip(firm_year["year"].values, firm_year["firm"].values))

    # 3. Events frame, dedup to one per item-year
    ev = con.sql("""
        SELECT item, auction_item, year, winner, runner_up FROM events
        WHERE winner IS NOT NULL AND runner_up IS NOT NULL
    """).fetchdf()
    ev = ev.sort_values(["item", "year", "auction_item"])
    ev = ev.drop_duplicates(subset=["item", "year"], keep="first")
    ev = ev.sort_values(["item", "year"]).reset_index(drop=True)
    log(f"  unique item-year events: {len(ev):,}", t0)

    con.close()

    # 4. Build transitions
    ev["prev_winner"] = ev.groupby("item")["winner"].shift(1)
    ev["prev_runner"] = ev.groupby("item")["runner_up"].shift(1)
    ev["prev_year"]   = ev.groupby("item")["year"].shift(1)
    trans = ev.dropna(subset=["prev_winner", "prev_runner"]).copy()
    trans["year_gap"] = trans["year"] - trans["prev_year"]
    trans = trans[trans["year_gap"].between(1, 3)]
    log(f"  raw transitions: {len(trans):,}", t0)

    # 5. Closure indicators
    trans["swap"]    = (trans["winner"] == trans["prev_runner"]).astype(int)
    trans["persist"] = (trans["winner"] == trans["prev_winner"]).astype(int)
    trans["closure"] = ((trans["swap"] == 1) | (trans["persist"] == 1)).astype(int)

    # 6. Classify as cartel / noncartel / mixed
    def classify(row):
        c = firm_to_setor.get(row["winner"])
        p = firm_to_setor.get(row["prev_winner"])
        r = firm_to_setor.get(row["prev_runner"])
        if c is not None and (c == p or c == r):
            return "cartel"
        if c is None and p is None and r is None:
            return "noncartel"
        return "mixed"

    trans["group"] = trans.apply(classify, axis=1)
    log(f"  group counts: {trans['group'].value_counts().to_dict()}", t0)

    # 7. Conditional filters
    # (a) Both members of year-t pair (prev_winner, prev_runner) are active
    #     somewhere in year t
    def active_both_t1(row):
        return ((row["year"], row["prev_winner"]) in firm_year_set
                and (row["year"], row["prev_runner"]) in firm_year_set)

    # (b) Both members active in SAME item in year t
    def active_both_same_item(row):
        return ((row["item"], row["year"], row["prev_winner"]) in part_set
                and (row["item"], row["year"], row["prev_runner"]) in part_set)

    trans["cond_active"]    = trans.apply(active_both_t1, axis=1)
    trans["cond_same_item"] = trans.apply(active_both_same_item, axis=1)
    log(f"  cond_active pct: {trans['cond_active'].mean():.3f}", t0)
    log(f"  cond_same_item pct: {trans['cond_same_item'].mean():.3f}", t0)

    # 8. Compute closure rates by group under each filter
    def rates(df, group_col="group"):
        out = {}
        for g in df[group_col].unique():
            sub = df[df[group_col] == g]
            out[g] = {
                "n": len(sub),
                "closure": sub["closure"].mean(),
                "swap":    sub["swap"].mean(),
                "persist": sub["persist"].mean(),
            }
        return out

    r_unc = rates(trans)
    r_act = rates(trans[trans["cond_active"]])
    r_si  = rates(trans[trans["cond_same_item"]])

    log(f"  unconditional: cartel {r_unc.get('cartel',{}).get('closure',np.nan):.4f}  "
        f"non {r_unc.get('noncartel',{}).get('closure',np.nan):.4f}", t0)
    log(f"  cond_active:   cartel {r_act.get('cartel',{}).get('closure',np.nan):.4f}  "
        f"non {r_act.get('noncartel',{}).get('closure',np.nan):.4f}", t0)
    log(f"  cond_same_item: cartel {r_si.get('cartel',{}).get('closure',np.nan):.4f}  "
        f"non {r_si.get('noncartel',{}).get('closure',np.nan):.4f}", t0)

    # 9. Report
    with open(OUT, "w") as f:
        f.write("Refined closure metric with participation conditioning\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")

        f.write("DESIGN\n")
        f.write("-" * 50 + "\n")
        f.write("  Event: first auction of item × year → (winner, runner-up).\n")
        f.write("  Transition: consecutive events within item, year gap ≤ 3.\n")
        f.write("  Closure: winner_{t+1} ∈ {winner_t, runner_up_t}\n")
        f.write("  Conditioning filters:\n")
        f.write("    (a) cond_active   = both year-t pair members bid (any item)\n")
        f.write("                        somewhere in year t+1\n")
        f.write("    (b) cond_same_item = both year-t pair members bid in THE\n")
        f.write("                        SAME item in year t+1\n\n")

        f.write("SAMPLE\n")
        f.write("-" * 50 + "\n")
        f.write(f"  Raw transitions: {len(trans):,}\n")
        for col in ["cond_active", "cond_same_item"]:
            f.write(f"  {col} = True: {int(trans[col].sum()):,}\n")
        f.write("\n")

        def write_table(label, data):
            f.write(f"{label}\n")
            f.write("-" * 50 + "\n")
            f.write(f"  {'group':<12s} {'n':>10s} {'closure':>8s} "
                    f"{'swap':>8s} {'persist':>8s}\n")
            for g in ["cartel", "mixed", "noncartel"]:
                if g not in data:
                    continue
                d = data[g]
                f.write(f"  {g:<12s} {d['n']:>10,} "
                        f"{d['closure']:>8.4f} {d['swap']:>8.4f} "
                        f"{d['persist']:>8.4f}\n")
            c = data.get("cartel", {})
            n = data.get("noncartel", {})
            if c and n and n.get("closure", 0) > 0:
                ratio = c["closure"] / n["closure"]
                f.write(f"\n  Cartel/noncartel closure ratio: {ratio:.2f}\n")
            f.write("\n")

        write_table("UNCONDITIONAL (= table 5 in results.tex)", r_unc)
        write_table("CONDITIONAL ON BOTH MEMBERS BIDDING IN t+1 (any item)", r_act)
        write_table("CONDITIONAL ON BOTH MEMBERS BIDDING IN t+1 (same item)", r_si)

        f.write("INTERPRETATION\n")
        f.write("-" * 50 + "\n")
        f.write("  If the cartel closure rate stays near 1 under the tighter\n")
        f.write("  conditions, the signal is about pair-level coordination, not\n")
        f.write("  about firm churn. If it drops to the non-cartel level, the\n")
        f.write("  original closure result was driven by low base-rate mobility.\n")

    log(f"report → {OUT}", t0)
    print("\n" + OUT.read_text())
    log(f"DONE ({time.time()-t0:.1f}s)", t0)


if __name__ == "__main__":
    main()
