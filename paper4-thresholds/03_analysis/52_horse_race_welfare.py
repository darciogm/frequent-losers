#!/usr/bin/env python3
"""
52_horse_race_welfare.py — Horse race #3: Enforcement welfare effects

Minimum-viable diagnostic: at item × year level, does cartel enforcement
(conduct-end year) produce detectable changes in (a) winning bid
relative to reference price, (b) number of unique bidders, (c) HHI of
bidder shares, on cartel-contaminated items compared to non-cartel
items?

Design: DiD at item × year, never-treated controls = items the cartel
firms did NOT bid on. Treatment timing = conduct end year of the
cartel(s) that operated in that item.

Decision rule: at least one of the three outcomes shows a significant
(|t| ≥ 1.96) post-treatment effect in the expected direction
  • price: post-treatment β negative  (prices fall after enforcement)
  • bidders: post-treatment β positive (more entry after enforcement)
  • HHI:   post-treatment β negative  (concentration falls)
→ idea worth pursuing as RAND paper #3.
"""
from __future__ import annotations
import time
from pathlib import Path
import numpy as np
import pandas as pd
import duckdb

BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")
FINAL = BASE / "02_data" / "final"
FIRMS = BASE / "02_data" / "firms"
INTER = BASE / "02_data" / "intermediate"

PAIRS_PREGAO = str(FINAL / "df_pregao_with_cartel_flags.parquet")
GROUND_TRUTH = str(FIRMS / "cade_ground_truth.parquet")

OUT = INTER / "horse_race_welfare.txt"

PANEL_YEARS = list(range(2009, 2018))


def log(msg, t0):
    print(f"[{time.time()-t0:6.1f}s] {msg}", flush=True)


def two_way_demean(x, g1, g2, sweeps=6):
    z = x.astype(float).copy()
    for _ in range(sweeps):
        z -= pd.Series(z, copy=False).groupby(g1).transform("mean").values
        z -= pd.Series(z, copy=False).groupby(g2).transform("mean").values
    return z


def estimate_did(df, y_col, item_col, year_col, treat_col,
                 post_col, firm_cluster_col):
    """Simple DiD via two-way FE (item + year) with TWFE interaction.
    Treat = 1 if item is ever treated. Post = 1 if year ≥ treatment year.
    Interaction coefficient on Treat×Post is the DiD estimate.
    Cluster SE on item.
    """
    d = df.dropna(subset=[y_col]).copy()
    d["tp"] = d[treat_col] * d[post_col]
    d["iid"] = d[item_col].astype("category").cat.codes.values.astype(np.int64)
    d["yid"] = d[year_col].astype("category").cat.codes.values.astype(np.int64)
    iid = d["iid"].values
    yid = d["yid"].values
    Y = two_way_demean(d[y_col].values.astype(float), iid, yid)
    D = two_way_demean(d["tp"].values.astype(float), iid, yid)
    if (D @ D) <= 0:
        return float("nan"), float("nan"), float("nan"), len(d)
    beta = (D @ Y) / (D @ D)
    e = Y - beta * D
    cs = pd.Series(D * e, copy=False).groupby(iid).sum().values
    nc = int(d["iid"].nunique())
    corr = nc / max(nc - 1, 1)
    var = corr * (cs ** 2).sum() / ((D @ D) ** 2)
    se = float(np.sqrt(var))
    t_stat = beta / se if se > 0 else float("nan")
    return float(beta), se, float(t_stat), len(d)


def main():
    t0 = time.time()
    INTER.mkdir(parents=True, exist_ok=True)

    con = duckdb.connect()
    con.sql("PRAGMA threads=12; PRAGMA memory_limit='14GB'")

    # 1. Cartel ground truth (firms, sectors, end years)
    log("Step 1: cartels", t0)
    con.sql(f"""
        CREATE TABLE cf AS
        SELECT DISTINCT cnpj_raiz, setor,
               cartel_end_year::INT AS e
        FROM read_parquet('{GROUND_TRUTH}')
        WHERE sp_relevant = 1
          AND processo IS NOT NULL
          AND cartel_start_year IS NOT NULL
          AND cartel_end_year IS NOT NULL
          AND cartel_end_year <= 2016
    """)

    # 2. For each item that a cartel firm bid on during conduct period,
    #    store (item, cartel_end_year) — if multiple cartels, take earliest
    log("Step 2: treated items with end year", t0)
    con.sql(f"""
        CREATE TABLE treated_items AS
        SELECT "códigoitem" AS item, MIN(cf.e) AS t_end
        FROM read_parquet('{PAIRS_PREGAO}') p
        JOIN cf ON p.cnpj_raiz = cf.cnpj_raiz
        WHERE p.cartel_in_period = 1
        GROUP BY "códigoitem"
    """)
    n_treated_items = con.sql("SELECT COUNT(*) FROM treated_items").fetchone()[0]
    log(f"  treated items: {n_treated_items:,}", t0)

    # 3. Item × year panel of outcomes (winning bid, n bidders, HHI)
    log("Step 3: building item × year outcomes panel", t0)
    years_str = ",".join(f"({y})" for y in PANEL_YEARS)
    con.sql(f"CREATE TABLE years_t AS SELECT * FROM (VALUES {years_str}) AS t(year)")

    # Winning bids (aggregate over all winning observations within item × year)
    # Filter MV to [-2, 2] to drop encoding artifacts
    con.sql(f"""
        CREATE TABLE item_year_win AS
        SELECT "códigoitem" AS item,
               year,
               AVG(MV) AS mv_mean
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE flagvencedor = 1 AND MV IS NOT NULL
          AND MV BETWEEN -2.0 AND 2.0
        GROUP BY item, year
    """)

    # Bidders count and HHI per item × year
    con.sql(f"""
        CREATE TABLE item_year_concentration AS
        WITH bid_shares AS (
            SELECT "códigoitem" AS item,
                   year,
                   cnpj_raiz AS firm,
                   COUNT(*) AS n_bids
            FROM read_parquet('{PAIRS_PREGAO}')
            WHERE cnpj_raiz IS NOT NULL
            GROUP BY item, year, firm
        ),
        totals AS (
            SELECT item, year, SUM(n_bids) AS total
            FROM bid_shares GROUP BY item, year
        )
        SELECT b.item,
               b.year,
               COUNT(DISTINCT b.firm) AS n_bidders,
               SUM(POWER(b.n_bids::DOUBLE / t.total::DOUBLE, 2)) AS hhi
        FROM bid_shares b
        JOIN totals t USING (item, year)
        GROUP BY b.item, b.year
    """)

    con.sql("""
        CREATE TABLE panel AS
        SELECT COALESCE(w.item, c.item) AS item,
               COALESCE(w.year, c.year) AS year,
               w.mv_mean,
               c.n_bidders,
               c.hhi
        FROM item_year_win w
        FULL OUTER JOIN item_year_concentration c
          ON w.item = c.item AND w.year = c.year
    """)

    con.sql("""
        CREATE TABLE panel2 AS
        SELECT p.item, p.year, p.mv_mean, p.n_bidders, p.hhi,
               CASE WHEN ti.t_end IS NOT NULL THEN 1 ELSE 0 END AS treated,
               ti.t_end
        FROM panel p
        LEFT JOIN treated_items ti USING (item)
        WHERE p.year IN (SELECT year FROM years_t)
    """)
    df = con.sql("SELECT * FROM panel2").fetchdf()
    con.close()

    df["post"] = ((df["t_end"].notna()) & (df["year"] > df["t_end"])).astype(int)
    df["treat"] = df["treated"].astype(int)

    # 4. Build outcome variables
    df["log_bidders"] = np.log1p(df["n_bidders"])
    # Cap HHI at 1 for numerical stability
    df["hhi_c"] = df["hhi"].clip(0, 1)

    n_items     = df["item"].nunique()
    n_treated   = df[df["treat"] == 1]["item"].nunique()
    n_control   = n_items - n_treated
    log(f"panel: {len(df):,} rows, {n_items:,} items "
        f"({n_treated:,} treated, {n_control:,} controls)", t0)

    # 5. Run DiD for each outcome
    log("Step 4: estimating DiDs", t0)
    results = {}
    for y_col, label in [
        ("mv_mean",     "log(win_bid / ref) — price"),
        ("log_bidders", "log(1 + n_bidders) — entry"),
        ("hhi_c",       "HHI — concentration"),
    ]:
        beta, se, tstat, n = estimate_did(
            df, y_col=y_col,
            item_col="item", year_col="year",
            treat_col="treat", post_col="post",
            firm_cluster_col="item",
        )
        results[label] = (beta, se, tstat, n)
        log(f"  {label}: β = {beta:+.4f}  SE = {se:.4f}  t = {tstat:+.2f}  n = {n:,}",
            t0)

    # 6. Report
    with open(OUT, "w") as f:
        f.write("Horse race #3: Enforcement welfare effects\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")

        f.write("DESIGN\n")
        f.write("-" * 50 + "\n")
        f.write("  Unit of analysis: item (código) × year\n")
        f.write("  Treated items: items bid on by a cartel firm during conduct period\n")
        f.write("  Post: year > cartel_end_year for that item\n")
        f.write("  Spec: two-way item + year FE, interaction Treat×Post\n")
        f.write("  Cluster: item\n\n")

        f.write("SAMPLE\n")
        f.write("-" * 50 + "\n")
        f.write(f"  Total items      : {n_items:,}\n")
        f.write(f"  Treated items    : {n_treated:,}\n")
        f.write(f"  Control items    : {n_control:,}\n")
        f.write(f"  Panel rows       : {len(df):,}\n")
        f.write(f"  Years            : "
                f"{int(df['year'].min())}–{int(df['year'].max())}\n\n")

        f.write("DiD COEFFICIENTS (Treat × Post)\n")
        f.write("-" * 60 + "\n")
        f.write(f"{'outcome':<40s} {'β':>10s} {'SE':>8s} {'t':>7s}\n")
        for label, (beta, se, t_stat, n) in results.items():
            f.write(f"  {label:<38s} {beta:>+10.4f} {se:>8.4f} {t_stat:>+7.2f}\n")
        f.write("\n")

        f.write("EXPECTED SIGNS (welfare-improving enforcement)\n")
        f.write("-" * 50 + "\n")
        f.write("  Price outcome    : β < 0 (prices fall after enforcement)\n")
        f.write("  Bidders outcome  : β > 0 (more entry after enforcement)\n")
        f.write("  HHI outcome      : β < 0 (concentration falls)\n\n")

        # Decision
        signs_ok = {
            "price":   (results["log(win_bid / ref) — price"][0] < 0 and
                        abs(results["log(win_bid / ref) — price"][2]) >= 1.96),
            "bidders": (results["log(1 + n_bidders) — entry"][0] > 0 and
                        abs(results["log(1 + n_bidders) — entry"][2]) >= 1.96),
            "hhi":     (results["HHI — concentration"][0] < 0 and
                        abs(results["HHI — concentration"][2]) >= 1.96),
        }
        n_pass = sum(signs_ok.values())

        f.write("DECISION CRITERIA\n")
        f.write("-" * 50 + "\n")
        f.write(f"  Outcomes with significant effect in expected direction: "
                f"{n_pass}/3\n")
        for name, ok in signs_ok.items():
            f.write(f"    {name:<10s}: {'✓' if ok else '✗'}\n")

        if n_pass >= 2:
            verdict = "✓ STRONG: ≥2 outcomes pass. RAND-tier potential."
        elif n_pass == 1:
            verdict = "△ PROMISING: 1 outcome passes. Worth deeper look."
        else:
            verdict = "✗ WEAK: no outcome passes. Needs redesign."
        f.write(f"\n  Verdict: {verdict}\n")

    log(f"report → {OUT}", t0)
    print("\n" + OUT.read_text())


if __name__ == "__main__":
    main()
