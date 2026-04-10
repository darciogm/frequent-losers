#!/usr/bin/env python3
"""
41_contagion_extensive_margin.py — Do firms ENTER new item codes after absorbing?

Tests whether firms that absorb ex-cartel workers start bidding on item codes
they never bid on before — specifically, item codes where the cartel firm
used to operate.

This tests capacity expansion: the ex-cartel workers bring operational
knowledge about specific products/markets, enabling the receiving firm
to enter those markets.

Outcome: n_new_items = count of item codes the firm bids on in year t
         that it NEVER bid on before year t.

Stacked DiD design (same as script 40).
"""
from __future__ import annotations
import time
from pathlib import Path
import numpy as np
import pandas as pd
import duckdb

BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")
RAIS_DIR = BASE / "RAIS" / "parquet" / "harmonized"
FINAL = BASE / "02_data" / "final"
FIRMS = BASE / "02_data" / "firms"
INTER = BASE / "02_data" / "intermediate"
FIGS  = BASE / "04_figures"

BEC_FIRMS    = str(BASE / "02_data" / "bec_cnpj_list.parquet")
PAIRS_PREGAO = str(FINAL / "df_pregao_with_cartel_flags.parquet")
GROUND_TRUTH = str(FIRMS / "cade_ground_truth.parquet")

OUT_REPORT = INTER / "contagion_extensive_margin.txt"
OUT_FIGURE = FIGS / "contagion_extensive_margin.pdf"

EVENT_WINDOW = (-3, 4)
COHORTS = [2012, 2013, 2014, 2015]


def main() -> None:
    t0 = time.time()
    INTER.mkdir(parents=True, exist_ok=True)
    FIGS.mkdir(parents=True, exist_ok=True)

    con = duckdb.connect()
    con.sql("PRAGMA threads=12; PRAGMA memory_limit='14GB'")
    con.sql("PRAGMA temp_directory='/tmp/duckdb_spill'")
    rais_glob = str(RAIS_DIR / "rais_vinculos_*.parquet")

    # ── Step 1: Treatment (same as script 40) ────────────────────────────────

    print("Step 1: Building treatment...", flush=True)

    con.sql(f"""
        CREATE TABLE cartel_firms AS
        SELECT DISTINCT cnpj_raiz, setor,
               cartel_start_year::INT AS start_yr, cartel_end_year::INT AS end_yr
        FROM read_parquet('{GROUND_TRUTH}')
        WHERE sp_relevant=1 AND processo IS NOT NULL
          AND cartel_start_year IS NOT NULL AND cartel_end_year<=2016
    """)
    con.sql(f"""
        CREATE TABLE worker_year AS
        SELECT DISTINCT pis, cnpj_raiz, ano AS year
        FROM read_parquet('{rais_glob}')
        WHERE cnpj_raiz IN (SELECT cnpj_raiz FROM read_parquet('{BEC_FIRMS}'))
          AND pis IS NOT NULL AND cnpj_raiz IS NOT NULL
    """)
    con.sql("""
        CREATE TABLE cartel_workers AS
        SELECT DISTINCT w.pis, w.cnpj_raiz AS ccnpj, cf.setor, cf.end_yr
        FROM worker_year w JOIN cartel_firms cf ON w.cnpj_raiz=cf.cnpj_raiz
        WHERE w.year BETWEEN cf.start_yr AND cf.end_yr
    """)
    con.sql("""
        CREATE TABLE treatment AS
        SELECT w2.cnpj_raiz AS firm, MIN(w2.year) AS arrival_year
        FROM cartel_workers cw JOIN worker_year w2 ON cw.pis=w2.pis
        WHERE w2.cnpj_raiz!=cw.ccnpj AND w2.year>cw.end_yr
          AND w2.cnpj_raiz NOT IN (SELECT cnpj_raiz FROM cartel_firms WHERE setor=cw.setor)
        GROUP BY w2.cnpj_raiz
    """)
    con.sql(f"""
        CREATE TABLE never_treated AS
        SELECT DISTINCT LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8] AS firm
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8]
              NOT IN (SELECT firm FROM treatment)
          AND LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8]
              NOT IN (SELECT cnpj_raiz FROM cartel_firms)
    """)

    # ── Step 2: Build extensive margin panel ─────────────────────────────────

    print("Step 2: Building extensive margin panel...", flush=True)

    # All bids by non-cartel firms
    con.sql(f"""
        CREATE TABLE all_bids AS
        SELECT
            LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8] AS firm,
            "códigoitem" AS item, year
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8]
              NOT IN (SELECT cnpj_raiz FROM cartel_firms)
    """)

    # For each firm × year: count items bid on, and count NEW items
    # (items never bid on in prior years)
    con.sql("""
        CREATE TABLE firm_items_history AS
        SELECT firm, item, MIN(year) AS first_bid_year
        FROM all_bids
        GROUP BY firm, item
    """)

    con.sql("""
        CREATE TABLE firm_year_extensive AS
        SELECT
            b.firm, b.year,
            count(DISTINCT b.item) AS n_items,
            count(DISTINCT CASE WHEN fih.first_bid_year = b.year
                THEN b.item END) AS n_new_items
        FROM all_bids b
        JOIN firm_items_history fih ON b.firm = fih.firm AND b.item = fih.item
        GROUP BY b.firm, b.year
    """)

    panel = con.sql("SELECT * FROM firm_year_extensive").fetchdf()
    treatment_df = con.sql("SELECT firm, arrival_year FROM treatment").fetchdf()
    treatment_map = dict(treatment_df.values)
    never_set = set(con.sql("SELECT firm FROM never_treated").fetchdf()["firm"])

    con.close()

    print(f"  firm-year panel: {len(panel):,} obs")

    # ── Step 3: Stack cohorts ────────────────────────────────────────────────

    print("Step 3: Stacking cohorts...", flush=True)

    min_tau, max_tau = EVENT_WINDOW
    stacked_parts = []

    for g in COHORTS:
        treated_g = set(treatment_df[treatment_df["arrival_year"] == g]["firm"])
        if len(treated_g) < 5:
            continue

        yr_lo, yr_hi = g + min_tau, g + max_tau
        sub = panel[
            (panel["year"].between(yr_lo, yr_hi)) &
            (panel["firm"].isin(treated_g | never_set))
        ].copy()

        sub["cohort"] = g
        sub["treated"] = sub["firm"].isin(treated_g).astype(int)
        sub["event_time"] = sub["year"] - g
        sub["tau"] = sub["event_time"].clip(lower=min_tau, upper=max_tau)
        sub["firm_cohort"] = sub["firm"] + f"_c{g}"

        stacked_parts.append(sub)
        n_t = sub[sub["treated"] == 1]["firm"].nunique()
        print(f"  cohort {g}: treated={n_t}, obs={len(sub):,}")

    stacked = pd.concat(stacked_parts, ignore_index=True)
    print(f"  stacked total: {len(stacked):,} obs")

    # ── Step 4: Event study ──────────────────────────────────────────────────

    print("Step 4: Estimating stacked event study...", flush=True)

    tau_values = sorted([t for t in range(min_tau, max_tau + 1) if t != -1])
    for tau in tau_values:
        stacked[f"tau_{tau}"] = ((stacked["treated"] == 1) &
                                  (stacked["tau"] == tau)).astype(float)

    results_dict = {}

    for outcome, label in [("n_items", "Total items"), ("n_new_items", "New items")]:
        df = stacked.dropna(subset=[outcome]).copy()

        y = df[outcome].values.astype(float)
        df["fc_id"] = df["firm_cohort"].astype("category").cat.codes
        df["yr_id"] = (df["year"].astype(str) + "_c" + df["cohort"].astype(str)
                       ).astype("category").cat.codes

        fm = df.groupby("fc_id")[outcome].transform("mean").values
        ym = df.groupby("yr_id")[outcome].transform("mean").values
        gm = y.mean()
        y_dm = y - fm - ym + gm

        X_cols = [f"tau_{t}" for t in tau_values]
        X = df[X_cols].values.astype(float)
        X_dm = X.copy()
        for j, col in enumerate(X_cols):
            f_m = df.groupby("fc_id")[col].transform("mean").values
            i_m = df.groupby("yr_id")[col].transform("mean").values
            g_m = X[:, j].mean()
            X_dm[:, j] = X[:, j] - f_m - i_m + g_m

        from numpy.linalg import lstsq
        beta, _, _, _ = lstsq(X_dm, y_dm, rcond=None)
        e = y_dm - X_dm @ beta
        n_obs, k = len(y_dm), len(beta)

        firms = df["fc_id"].values
        unique_firms = np.unique(firms)
        nc = len(unique_firms)
        XtX_inv = np.linalg.inv(X_dm.T @ X_dm)
        meat = np.zeros((k, k))
        for g_id in unique_firms:
            mask = firms == g_id
            score = X_dm[mask].T @ e[mask]
            meat += np.outer(score, score)
        correction = (nc / (nc - 1)) * ((n_obs - 1) / (n_obs - k))
        V = correction * XtX_inv @ meat @ XtX_inv
        se = np.sqrt(np.diag(V))

        res = pd.DataFrame({
            "tau": tau_values, "beta": beta, "se": se,
            "t_stat": beta / se,
            "ci_lo": beta - 1.96 * se, "ci_hi": beta + 1.96 * se,
        })
        ref = pd.DataFrame({"tau": [-1], "beta": [0.0], "se": [0.0],
                             "t_stat": [0.0], "ci_lo": [0.0], "ci_hi": [0.0]})
        res = pd.concat([res, ref]).sort_values("tau").reset_index(drop=True)

        control_mean = df[df["treated"] == 0][outcome].mean()
        results_dict[outcome] = (res, n_obs, nc, control_mean)

    # ── Step 5: Report ───────────────────────────────────────────────────────

    with open(OUT_REPORT, "w") as f:
        f.write("Contagion: Extensive Margin (Stacked DiD)\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")

        for outcome, label in [("n_items", "TOTAL ITEMS BID ON"),
                                ("n_new_items", "NEW ITEMS (never bid before)")]:
            if outcome not in results_dict:
                continue
            res, n_o, n_c, ctrl_mean = results_dict[outcome]
            pre_max = res[res["tau"].between(min_tau, -2)]["t_stat"].abs().max()
            post_mean = res[res["tau"] >= 0]["beta"].mean()

            f.write(f"{label}\n")
            f.write("-" * 55 + "\n")
            f.write(f"N obs: {n_o:,}  Control mean: {ctrl_mean:.2f}\n\n")
            f.write(f"{'τ':>4s}  {'β':>8s}  {'SE':>7s}  {'t':>6s}\n")
            f.write("-" * 30 + "\n")
            for _, row in res.iterrows():
                sig = "***" if abs(row["t_stat"]) > 2.576 else \
                      "**" if abs(row["t_stat"]) > 1.96 else \
                      "*" if abs(row["t_stat"]) > 1.645 else ""
                f.write(f"{int(row['tau']):>4d}  {row['beta']:>8.3f}  "
                        f"{row['se']:>7.3f}  {row['t_stat']:>6.2f} {sig}\n")

            f.write(f"\n  Pre-trend max |t|: {pre_max:.2f}\n")
            f.write(f"  Post mean β: {post_mean:+.3f} "
                    f"({post_mean/ctrl_mean*100:+.1f}% of control mean)\n\n")

    print(f"\n[written] {OUT_REPORT}")

    # ── Figure ───────────────────────────────────────────────────────────────

    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        fig, axes = plt.subplots(1, 2, figsize=(13, 5))

        for idx, (outcome, title) in enumerate([
            ("n_items", "A. Total items bid on"),
            ("n_new_items", "B. New items (never bid before)"),
        ]):
            ax = axes[idx]
            if outcome in results_dict:
                res, _, _, _ = results_dict[outcome]
                ax.fill_between(res["tau"], res["ci_lo"], res["ci_hi"],
                                alpha=0.15, color="#2166ac")
                ax.plot(res["tau"], res["beta"], "o-", color="#2166ac",
                        linewidth=2, markersize=6)

            ax.axhline(0, color="grey", linewidth=0.8)
            ax.axvline(-0.5, color="red", linestyle="--", linewidth=1, alpha=0.4)
            ax.set_xlabel(r"$\tau$ (years since first ex-cartel worker)")
            ax.set_ylabel("Items (relative to τ = -1)")
            ax.set_title(title)
            ax.spines["top"].set_visible(False)
            ax.spines["right"].set_visible(False)

        fig.tight_layout()
        fig.savefig(OUT_FIGURE, dpi=300, bbox_inches="tight")
        plt.close(fig)
        print(f"[written] {OUT_FIGURE}")
    except ImportError:
        pass

    print(f"\nTotal time: {time.time() - t0:.1f}s")
    print("\n--- report ---")
    print(OUT_REPORT.read_text())


if __name__ == "__main__":
    main()
