#!/usr/bin/env python3
"""
33_exit_placebo.py — Non-cartel firm exit placebo

Purpose
-------
Test whether the post-conduct worker outflow pattern is cartel-specific or
generic to any firm contraction. Identify BEC firms that "exit" (stop bidding)
for non-cartel reasons, and compare their outflow patterns to cartel firms.

Design
------
1. Define "exit" = firm's last BEC bid year ≤ 2014 (ensuring ≥3 years post-exit
   in RAIS 2009-2017) AND firm had ≥3 workers AND firm is not a cartel firm.
2. Run the same event-study specification as script 28:
   outflow_rate_it = α_i + γ_t + Σ β_τ D_iτ + ε_it
   where event = last_bid_year for exit firms.
3. Compare coefficient patterns: if exit firms show similar post-event spikes,
   the cartel pattern is generic. If not, it's cartel-specific.

Output
------
- 02_data/intermediate/exit_placebo.txt
- 04_figures/exit_placebo.pdf
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

OUT_REPORT = INTER / "exit_placebo.txt"
OUT_FIGURE = FIGS / "exit_placebo.pdf"

EVENT_WINDOW = (-4, 4)


def main() -> None:
    t0 = time.time()
    INTER.mkdir(parents=True, exist_ok=True)
    FIGS.mkdir(parents=True, exist_ok=True)

    con = duckdb.connect()
    con.sql("PRAGMA threads=12; PRAGMA memory_limit='14GB'")
    con.sql("PRAGMA temp_directory='/tmp/duckdb_spill'")

    rais_glob = str(RAIS_DIR / "rais_vinculos_*.parquet")

    # ── Step 1: Identify exit firms ──────────────────────────────────────────

    print("Step 1: Identifying exit firms...", flush=True)

    # Last bid year per firm in BEC pregão
    con.sql(f"""
        CREATE OR REPLACE TABLE firm_activity AS
        WITH bids AS (
            SELECT
                LPAD(CAST("códigofornecedor" AS VARCHAR), 14, '0')[1:8] AS cnpj_raiz,
                year
            FROM read_parquet('{PAIRS_PREGAO}')
        )
        SELECT
            cnpj_raiz,
            MIN(year) AS first_bid_year,
            MAX(year) AS last_bid_year,
            COUNT(DISTINCT year) AS n_active_years
        FROM bids
        GROUP BY cnpj_raiz
    """)

    # Cartel firms to exclude
    con.sql(f"""
        CREATE OR REPLACE TABLE cartel_cnpjs AS
        SELECT DISTINCT cnpj_raiz
        FROM read_parquet('{GROUND_TRUTH}')
        WHERE sp_relevant = 1
    """)

    # Exit firms: last bid ≤ 2014, not cartel, had ≥2 active years
    con.sql("""
        CREATE OR REPLACE TABLE exit_firms AS
        SELECT fa.cnpj_raiz, fa.last_bid_year AS exit_year
        FROM firm_activity fa
        LEFT JOIN cartel_cnpjs cc ON fa.cnpj_raiz = cc.cnpj_raiz
        WHERE fa.last_bid_year BETWEEN 2011 AND 2014
          AND fa.n_active_years >= 2
          AND cc.cnpj_raiz IS NULL
    """)
    n_exit = con.sql("SELECT count(*) FROM exit_firms").fetchone()[0]
    print(f"  exit firms (last bid 2011-2014, ≥2 active years): {n_exit:,}")

    # ── Step 2: Build worker-year panel ──────────────────────────────────────

    print("Step 2: Building worker-year panel...", flush=True)
    con.sql(f"""
        CREATE OR REPLACE TABLE worker_year AS
        SELECT DISTINCT pis, cnpj_raiz, ano AS year
        FROM read_parquet('{rais_glob}')
        WHERE cnpj_raiz IN (SELECT cnpj_raiz FROM read_parquet('{BEC_FIRMS}'))
          AND pis IS NOT NULL AND cnpj_raiz IS NOT NULL
    """)

    # ── Step 3: Worker transitions ───────────────────────────────────────────

    print("Step 3: Computing transitions...", flush=True)
    con.sql("""
        CREATE OR REPLACE TABLE transitions AS
        SELECT w1.cnpj_raiz AS firm_from, w2.cnpj_raiz AS firm_to,
               w1.year AS year_from, w1.pis
        FROM worker_year w1
        JOIN worker_year w2 ON w1.pis = w2.pis
            AND w2.year = w1.year + 1
            AND w2.cnpj_raiz != w1.cnpj_raiz
    """)

    con.sql("""
        CREATE OR REPLACE TABLE outflows AS
        SELECT firm_from AS cnpj_raiz, year_from + 1 AS year,
               count(DISTINCT pis) AS n_outflows
        FROM transitions GROUP BY firm_from, year_from
    """)

    con.sql("""
        CREATE OR REPLACE TABLE firm_size AS
        SELECT cnpj_raiz, year, count(DISTINCT pis) AS n_workers
        FROM worker_year GROUP BY cnpj_raiz, year
    """)

    # ── Step 4: Build event-study panel ──────────────────────────────────────

    print("Step 4: Building event-study panel...", flush=True)

    # Panel for exit firms
    con.sql("""
        CREATE OR REPLACE TABLE panel AS
        SELECT
            fs.cnpj_raiz, fs.year, fs.n_workers,
            COALESCE(o.n_outflows, 0) AS n_outflows,
            COALESCE(o.n_outflows, 0) * 1.0 / NULLIF(fs_lag.n_workers, 0)
                AS outflow_rate,
            CASE WHEN ef.cnpj_raiz IS NOT NULL THEN 1 ELSE 0 END AS treated,
            ef.exit_year,
            CASE WHEN ef.cnpj_raiz IS NOT NULL
                THEN fs.year - ef.exit_year ELSE NULL END AS event_time
        FROM firm_size fs
        LEFT JOIN firm_size fs_lag
            ON fs.cnpj_raiz = fs_lag.cnpj_raiz AND fs_lag.year = fs.year - 1
        LEFT JOIN outflows o ON fs.cnpj_raiz = o.cnpj_raiz AND fs.year = o.year
        LEFT JOIN exit_firms ef ON fs.cnpj_raiz = ef.cnpj_raiz
        WHERE fs.year BETWEEN 2010 AND 2017
          AND fs_lag.n_workers >= 3
    """)

    n_panel = con.sql("SELECT count(*) FROM panel").fetchone()[0]
    n_treated = con.sql("SELECT count(*) FROM panel WHERE treated = 1").fetchone()[0]
    print(f"  panel: {n_panel:,} obs, treated: {n_treated:,}")

    # ── Step 5: Event-study regression ───────────────────────────────────────

    print("Step 5: Running event study...", flush=True)

    df = con.sql("SELECT * FROM panel").fetchdf()
    df = df.dropna(subset=["outflow_rate"]).copy()

    min_tau, max_tau = EVENT_WINDOW
    df["tau"] = df["event_time"].clip(lower=min_tau, upper=max_tau)
    tau_values = sorted([t for t in range(min_tau, max_tau + 1) if t != -1])

    for tau in tau_values:
        df[f"tau_{tau}"] = ((df["treated"] == 1) & (df["tau"] == tau)).astype(int)

    y = df["outflow_rate"].values.astype(float)
    df["firm_id"] = df["cnpj_raiz"].astype("category").cat.codes
    df["year_id"] = df["year"].astype("category").cat.codes

    # Demean
    firm_means = df.groupby("firm_id")["outflow_rate"].transform("mean").values
    year_means = df.groupby("year_id")["outflow_rate"].transform("mean").values
    grand_mean = y.mean()
    y_dm = y - firm_means - year_means + grand_mean

    X_cols = [f"tau_{t}" for t in tau_values]
    X = df[X_cols].values.astype(float)
    X_dm = X.copy()
    for j in range(X.shape[1]):
        fm = df.groupby("firm_id")[X_cols[j]].transform("mean").values
        ym = df.groupby("year_id")[X_cols[j]].transform("mean").values
        gm = X[:, j].mean()
        X_dm[:, j] = X[:, j] - fm - ym + gm

    from numpy.linalg import lstsq
    beta, _, _, _ = lstsq(X_dm, y_dm, rcond=None)
    e = y_dm - X_dm @ beta
    n_obs, k = len(y_dm), len(beta)

    # Cluster SEs at firm level
    firms = df["firm_id"].values
    unique_firms = np.unique(firms)
    n_clusters = len(unique_firms)
    XtX_inv = np.linalg.inv(X_dm.T @ X_dm)
    meat = np.zeros((k, k))
    for g in unique_firms:
        mask = firms == g
        Xg = X_dm[mask]
        eg = e[mask]
        score = Xg.T @ eg
        meat += np.outer(score, score)
    correction = (n_clusters / (n_clusters - 1)) * ((n_obs - 1) / (n_obs - k))
    V = correction * XtX_inv @ meat @ XtX_inv
    se = np.sqrt(np.diag(V))

    results = pd.DataFrame({
        "tau": tau_values, "beta": beta, "se": se,
        "t_stat": beta / se,
        "ci_lo": beta - 1.96 * se, "ci_hi": beta + 1.96 * se,
    })
    ref = pd.DataFrame({"tau": [-1], "beta": [0.0], "se": [0.0],
                         "t_stat": [0.0], "ci_lo": [0.0], "ci_hi": [0.0]})
    results = pd.concat([results, ref]).sort_values("tau").reset_index(drop=True)

    control_mean = df[df["treated"] == 0]["outflow_rate"].mean()

    # ── Step 6: Load cartel event study for comparison ────────────────────────

    # Read cartel event study results from script 28 report
    cartel_report = INTER / "event_study_outflows.txt"
    cartel_betas = {}
    if cartel_report.exists():
        for line in cartel_report.read_text().split("\n"):
            parts = line.strip().split()
            if len(parts) >= 4 and parts[0].lstrip("-").isdigit():
                tau_val = int(parts[0])
                beta_val = float(parts[1])
                cartel_betas[tau_val] = beta_val

    # ── Step 7: Write report ─────────────────────────────────────────────────

    with open(OUT_REPORT, "w") as f:
        f.write("Exit Placebo: Non-Cartel Firm Exits\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")

        f.write("DESIGN\n")
        f.write("-" * 40 + "\n")
        f.write(f"Exit firms: BEC firms with last bid in 2011-2014, ≥2 active years, "
                f"not cartel\n")
        f.write(f"Event: τ = year − last_bid_year\n")
        f.write(f"Control: all other BEC firms\n")
        f.write(f"N exit firms: {n_exit:,}\n")
        f.write(f"N treated obs: {n_treated:,}\n")
        f.write(f"N total obs: {n_obs:,}\n")
        f.write(f"Control mean outflow: {control_mean:.4f}\n\n")

        f.write("EVENT-STUDY COEFFICIENTS\n")
        f.write("-" * 70 + "\n")
        f.write(f"{'τ':>4s}  {'β(exit)':>8s}  {'SE':>8s}  {'t':>7s}  "
                f"{'β(cartel)':>10s}  {'sig':>4s}\n")
        f.write("-" * 70 + "\n")
        for _, row in results.iterrows():
            tau = int(row["tau"])
            sig = "***" if abs(row["t_stat"]) > 2.576 else \
                  "**" if abs(row["t_stat"]) > 1.96 else \
                  "*" if abs(row["t_stat"]) > 1.645 else ""
            cartel_b = cartel_betas.get(tau, np.nan)
            f.write(f"{tau:>4d}  {row['beta']:>8.4f}  {row['se']:>8.4f}  "
                    f"{row['t_stat']:>7.2f}  {cartel_b:>10.4f}  {sig:>4s}\n")
        f.write("\n")

        # Summary comparison
        exit_post = results[results["tau"] >= 0]["beta"].mean()
        cartel_post = np.mean([v for k, v in cartel_betas.items() if k >= 0]) \
            if cartel_betas else np.nan

        f.write("COMPARISON: EXIT vs CARTEL\n")
        f.write("-" * 50 + "\n")
        f.write(f"  Mean post-event β (exit firms):    {exit_post:+.4f}\n")
        f.write(f"  Mean post-event β (cartel firms):  {cartel_post:+.4f}\n")
        f.write(f"  Ratio (cartel / exit):             "
                f"{cartel_post / exit_post:.2f}x\n\n") if exit_post != 0 else None

        if exit_post > 0.01 and cartel_post > 0.01:
            if cartel_post / exit_post > 1.5:
                f.write("  → Cartel firms show LARGER post-event outflows than\n")
                f.write("    generic exit firms. The cartel pattern has a\n")
                f.write("    cartel-specific component beyond generic contraction.\n")
            else:
                f.write("  → Exit and cartel outflow patterns are SIMILAR.\n")
                f.write("    The post-conduct pattern may be generic firm exit.\n")
        elif exit_post <= 0.005:
            f.write("  → Exit firms show NO post-event outflow increase.\n")
            f.write("    The cartel pattern is cartel-specific.\n")

    print(f"\n[written] {OUT_REPORT}")

    # ── Step 8: Figure ───────────────────────────────────────────────────────

    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        fig, ax = plt.subplots(figsize=(9, 5.5))

        taus = results["tau"].values
        betas_exit = results["beta"].values
        ci_lo = results["ci_lo"].values
        ci_hi = results["ci_hi"].values

        # Exit firms
        ax.fill_between(taus, ci_lo, ci_hi, alpha=0.12, color="#4575b4")
        ax.plot(taus, betas_exit, "o-", color="#4575b4", linewidth=2,
                markersize=6, label="Non-cartel exit firms")

        # Cartel firms (from script 28)
        if cartel_betas:
            cartel_taus = sorted(cartel_betas.keys())
            cartel_vals = [cartel_betas[t] for t in cartel_taus]
            # Only plot taus in our window
            ct = [(t, v) for t, v in zip(cartel_taus, cartel_vals)
                  if min_tau <= t <= max_tau]
            if ct:
                ax.plot([t for t, v in ct], [v for t, v in ct],
                        "s--", color="#d73027", linewidth=2, markersize=6,
                        label="Cartel firms (script 28)")

        ax.axhline(0, color="grey", linestyle="-", linewidth=0.8)
        ax.axvline(-0.5, color="black", linestyle="--", linewidth=1, alpha=0.4)

        ax.set_xlabel(r"Event time ($\tau$)", fontsize=11)
        ax.set_ylabel("Outflow rate (relative to $\\tau = -1$)", fontsize=11)
        ax.set_xticks(taus)
        ax.legend(loc="upper left", fontsize=9)
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)

        fig.tight_layout()
        fig.savefig(OUT_FIGURE, dpi=300, bbox_inches="tight")
        plt.close(fig)
        print(f"[written] {OUT_FIGURE}")
    except ImportError:
        print("  matplotlib not available")

    con.close()
    print(f"\nTotal time: {time.time() - t0:.1f}s")
    print("\n--- report ---")
    print(OUT_REPORT.read_text())


if __name__ == "__main__":
    main()
