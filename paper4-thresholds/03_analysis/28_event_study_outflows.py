#!/usr/bin/env python3
"""
28_event_study_outflows.py — Event study of worker outflows around cartel end

Purpose
-------
Formal event study testing whether worker outflows from cartel firms to BEC
rivals increase after the cartel conduct period ends.

Design
------
Unit: firm × year (BEC firms observed in RAIS, 2010-2017; 2009 is t-1 base)
Outcome: outflow_rate = (workers at firm i in year t-1, at a DIFFERENT BEC firm
         in year t) / (workers at firm i in year t-1)
Treatment: cartel firms, with event time τ = year - cartel_end_year
Specification:
    outflow_rate_it = α_i + γ_t + Σ_{τ≠-1} β_τ · D_iτ + ε_it

    where D_iτ = 1 if firm i is cartel and t = end_year_i + τ

Output
------
- 02_data/intermediate/event_study_outflows.txt
- 02_data/intermediate/event_study_panel.parquet  (firm-year panel for replication)
- 04_figures/event_study_outflows.pdf
"""
from __future__ import annotations

import time
from pathlib import Path

import numpy as np
import pandas as pd
import duckdb

BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")
RAIS_DIR = BASE / "RAIS" / "parquet" / "harmonized"
FIRMS = BASE / "02_data" / "firms"
INTER = BASE / "02_data" / "intermediate"
FIGS  = BASE / "04_figures"

BEC_FIRMS    = str(BASE / "02_data" / "bec_cnpj_list.parquet")
GROUND_TRUTH = str(FIRMS / "cade_ground_truth.parquet")

OUT_REPORT = INTER / "event_study_outflows.txt"
OUT_PANEL  = INTER / "event_study_panel.parquet"
OUT_FIGURE = FIGS / "event_study_outflows.pdf"

EVENT_WINDOW = (-4, 6)  # τ range relative to cartel_end_year


def main() -> None:
    t0 = time.time()
    INTER.mkdir(parents=True, exist_ok=True)
    FIGS.mkdir(parents=True, exist_ok=True)

    con = duckdb.connect()
    con.sql("PRAGMA threads=12")
    con.sql("PRAGMA memory_limit='14GB'")
    con.sql("PRAGMA temp_directory='/tmp/duckdb_spill'")

    rais_glob = str(RAIS_DIR / "rais_vinculos_*.parquet")

    # ── Step 1: Build worker-year panel (PIS, firm, year) ────────────────────

    print("Step 1: Building worker-year panel...", flush=True)
    con.sql(f"""
        CREATE OR REPLACE TABLE worker_year AS
        SELECT DISTINCT pis, cnpj_raiz, ano AS year
        FROM read_parquet('{rais_glob}')
        WHERE cnpj_raiz IN (SELECT cnpj_raiz FROM read_parquet('{BEC_FIRMS}'))
          AND pis IS NOT NULL AND cnpj_raiz IS NOT NULL
    """)
    n = con.sql("SELECT count(*) FROM worker_year").fetchone()[0]
    print(f"  worker-year observations: {n:,}")

    # ── Step 2: Identify worker transitions ──────────────────────────────────

    print("Step 2: Identifying worker transitions (year t → t+1)...", flush=True)

    # A transition: worker at firm A in year t, at firm B (B≠A) in year t+1
    con.sql("""
        CREATE OR REPLACE TABLE transitions AS
        SELECT
            w1.cnpj_raiz AS firm_from,
            w2.cnpj_raiz AS firm_to,
            w1.year AS year_from,
            w1.pis
        FROM worker_year w1
        JOIN worker_year w2
            ON w1.pis = w2.pis
            AND w2.year = w1.year + 1
            AND w2.cnpj_raiz != w1.cnpj_raiz
    """)
    n_trans = con.sql("SELECT count(*) FROM transitions").fetchone()[0]
    print(f"  transitions: {n_trans:,}")

    # ── Step 3: Count outflows per firm-year ─────────────────────────────────

    print("Step 3: Counting outflows per firm-year...", flush=True)

    # Outflows: workers leaving firm_from to any other BEC firm
    con.sql("""
        CREATE OR REPLACE TABLE outflows AS
        SELECT
            firm_from AS cnpj_raiz,
            year_from + 1 AS year,  -- the outflow materializes in year t+1
            count(DISTINCT pis) AS n_outflows
        FROM transitions
        GROUP BY firm_from, year_from
    """)

    # Firm size: workers at each firm in each year
    con.sql("""
        CREATE OR REPLACE TABLE firm_size AS
        SELECT cnpj_raiz, year, count(DISTINCT pis) AS n_workers
        FROM worker_year
        GROUP BY cnpj_raiz, year
    """)

    # ── Step 4: Build firm-year panel ────────────────────────────────────────

    print("Step 4: Building firm-year panel...", flush=True)

    # Cartel treatment
    con.sql(f"""
        CREATE OR REPLACE TABLE cartel_treatment AS
        SELECT DISTINCT
            cnpj_raiz,
            setor,
            cartel_start_year::INT AS start_yr,
            cartel_end_year::INT AS end_yr
        FROM read_parquet('{GROUND_TRUTH}')
        WHERE sp_relevant = 1 AND processo IS NOT NULL
          AND cartel_start_year IS NOT NULL
          AND cartel_end_year <= 2017  -- exclude transporte_escolar (end=2019)
    """)
    n_cartel = con.sql("SELECT count(DISTINCT cnpj_raiz) FROM cartel_treatment").fetchone()[0]
    print(f"  cartel firms (with end_yr ≤ 2017): {n_cartel}")

    # Panel: all BEC firms × years 2010-2017 (need t-1 for lagged size)
    con.sql("""
        CREATE OR REPLACE TABLE panel AS
        SELECT
            fs.cnpj_raiz,
            fs.year,
            fs.n_workers,
            COALESCE(o.n_outflows, 0) AS n_outflows,
            COALESCE(o.n_outflows, 0) * 1.0 / NULLIF(fs_lag.n_workers, 0)
                AS outflow_rate,
            CASE WHEN ct.cnpj_raiz IS NOT NULL THEN 1 ELSE 0 END AS treated,
            ct.setor,
            ct.end_yr,
            CASE WHEN ct.cnpj_raiz IS NOT NULL
                THEN fs.year - ct.end_yr
                ELSE NULL END AS event_time
        FROM firm_size fs
        LEFT JOIN firm_size fs_lag
            ON fs.cnpj_raiz = fs_lag.cnpj_raiz AND fs_lag.year = fs.year - 1
        LEFT JOIN outflows o
            ON fs.cnpj_raiz = o.cnpj_raiz AND fs.year = o.year
        LEFT JOIN cartel_treatment ct
            ON fs.cnpj_raiz = ct.cnpj_raiz
        WHERE fs.year BETWEEN 2010 AND 2017
          AND fs_lag.n_workers >= 3  -- minimum firm size for meaningful rate
    """)

    n_panel = con.sql("SELECT count(*) FROM panel").fetchone()[0]
    n_firms_panel = con.sql("SELECT count(DISTINCT cnpj_raiz) FROM panel").fetchone()[0]
    n_treated_obs = con.sql("SELECT count(*) FROM panel WHERE treated = 1").fetchone()[0]
    print(f"  panel: {n_panel:,} obs, {n_firms_panel:,} firms, "
          f"{n_treated_obs:,} treated obs")

    # ── Step 5: Event-study regression ───────────────────────────────────────

    print("Step 5: Running event-study regression...", flush=True)

    df = con.sql("SELECT * FROM panel").fetchdf()

    # Create event-time dummies for treated firms
    # Bin extreme event times
    min_tau, max_tau = EVENT_WINDOW
    df["tau"] = df["event_time"].clip(lower=min_tau, upper=max_tau)

    # Create dummies — omit τ = -1 as reference
    tau_values = sorted([t for t in range(min_tau, max_tau + 1) if t != -1])
    for tau in tau_values:
        df[f"tau_{tau}"] = ((df["treated"] == 1) & (df["tau"] == tau)).astype(int)

    # Also create a simple "never treated" indicator for controls
    # (controls have treated=0, so tau dummies are always 0 for them)

    # TWFE regression: outflow_rate ~ firm_FE + year_FE + Σ β_τ D_τ
    # Using within-transformation (demeaning) for efficiency

    # Drop NaN outflow_rate
    df = df.dropna(subset=["outflow_rate"]).copy()
    print(f"  regression sample: {len(df):,} obs")

    # Demean by firm and year (manual within transformation)
    df["firm_id"] = df["cnpj_raiz"].astype("category").cat.codes
    df["year_id"] = df["year"].astype("category").cat.codes

    # Use statsmodels for OLS with absorbed FEs via demeaning
    # For large panels, manual demeaning + OLS on demeaned data
    from scipy import sparse
    from numpy.linalg import lstsq

    y = df["outflow_rate"].values.astype(float)

    # Demean y by firm and year (Frisch-Waugh)
    firm_means = df.groupby("firm_id")["outflow_rate"].transform("mean").values
    year_means = df.groupby("year_id")["outflow_rate"].transform("mean").values
    grand_mean = y.mean()
    y_dm = y - firm_means - year_means + grand_mean

    # Build X matrix (event-time dummies, already demeaned)
    X_cols = [f"tau_{t}" for t in tau_values]
    X = df[X_cols].values.astype(float)

    # Demean X
    X_dm = X.copy()
    for j in range(X.shape[1]):
        fm = df.groupby("firm_id")[X_cols[j]].transform("mean").values
        ym = df.groupby("year_id")[X_cols[j]].transform("mean").values
        gm = X[:, j].mean()
        X_dm[:, j] = X[:, j] - fm - ym + gm

    # OLS on demeaned data
    beta, residuals, rank, sv = lstsq(X_dm, y_dm, rcond=None)

    # Residuals for SE computation
    e = y_dm - X_dm @ beta
    n_obs = len(y_dm)
    k = len(beta)

    # Cluster-robust SEs at firm level
    firms = df["firm_id"].values
    unique_firms = np.unique(firms)
    n_clusters = len(unique_firms)

    # Bread: (X'X)^{-1}
    XtX_inv = np.linalg.inv(X_dm.T @ X_dm)

    # Meat: Σ_g (X_g' e_g)(X_g' e_g)'
    meat = np.zeros((k, k))
    for g in unique_firms:
        mask = firms == g
        Xg = X_dm[mask]
        eg = e[mask]
        score = Xg.T @ eg  # k×1
        meat += np.outer(score, score)

    # Sandwich with small-sample correction
    correction = (n_clusters / (n_clusters - 1)) * ((n_obs - 1) / (n_obs - k))
    V = correction * XtX_inv @ meat @ XtX_inv
    se = np.sqrt(np.diag(V))

    # Results
    results = pd.DataFrame({
        "tau": tau_values,
        "beta": beta,
        "se": se,
        "t_stat": beta / se,
        "ci_lo": beta - 1.96 * se,
        "ci_hi": beta + 1.96 * se,
    })

    # Add τ = -1 as reference (beta=0, se=0)
    ref = pd.DataFrame({"tau": [-1], "beta": [0.0], "se": [0.0],
                         "t_stat": [0.0], "ci_lo": [0.0], "ci_hi": [0.0]})
    results = pd.concat([results, ref]).sort_values("tau").reset_index(drop=True)

    # ── Step 6: Descriptive statistics ───────────────────────────────────────

    print("Step 6: Computing descriptive statistics...", flush=True)

    # Mean outflow rate by event time for treated
    treated_means = (
        df[df["treated"] == 1]
        .groupby("tau")["outflow_rate"]
        .agg(["mean", "std", "count"])
        .reset_index()
    )

    # Control mean
    control_mean = df[df["treated"] == 0]["outflow_rate"].mean()

    # ── Step 7: Write report ─────────────────────────────────────────────────

    with open(OUT_REPORT, "w") as f:
        f.write("Event Study: Worker Outflows around Cartel Conduct End\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")

        f.write("DESIGN\n")
        f.write("-" * 40 + "\n")
        f.write(f"Unit: firm × year\n")
        f.write(f"Outcome: outflow_rate = workers leaving to other BEC firms / "
                f"lagged firm size\n")
        f.write(f"Treatment: cartel firms with conduct end ≤ 2017\n")
        f.write(f"Event: τ = year − cartel_end_year, reference τ = −1\n")
        f.write(f"FEs: firm + year\n")
        f.write(f"Clustering: firm level\n")
        f.write(f"Minimum firm size (lagged): 3 workers\n\n")

        f.write("SAMPLE\n")
        f.write("-" * 40 + "\n")
        f.write(f"Total obs:     {n_obs:,}\n")
        f.write(f"Total firms:   {n_firms_panel:,}\n")
        f.write(f"Treated firms: {n_cartel}\n")
        f.write(f"Treated obs:   {n_treated_obs:,}\n")
        f.write(f"Clusters:      {n_clusters:,}\n")
        f.write(f"Control mean:  {control_mean:.4f}\n\n")

        f.write("EVENT-STUDY COEFFICIENTS\n")
        f.write("-" * 60 + "\n")
        f.write(f"{'τ':>4s}  {'β':>8s}  {'SE':>8s}  {'t':>7s}  "
                f"{'95% CI':>20s}  {'sig':>4s}\n")
        f.write("-" * 60 + "\n")
        for _, row in results.iterrows():
            tau = int(row["tau"])
            sig = ""
            if abs(row["t_stat"]) > 2.576:
                sig = "***"
            elif abs(row["t_stat"]) > 1.96:
                sig = "**"
            elif abs(row["t_stat"]) > 1.645:
                sig = "*"
            f.write(f"{tau:>4d}  {row['beta']:>8.4f}  {row['se']:>8.4f}  "
                    f"{row['t_stat']:>7.2f}  "
                    f"[{row['ci_lo']:>8.4f}, {row['ci_hi']:>8.4f}]  {sig:>4s}\n")
        f.write("\n")

        f.write("RAW MEANS BY EVENT TIME (treated firms)\n")
        f.write("-" * 50 + "\n")
        for _, row in treated_means.iterrows():
            f.write(f"  τ={int(row['tau']):>3d}  "
                    f"mean={row['mean']:.4f}  sd={row['std']:.4f}  "
                    f"N={int(row['count']):>3d}\n")
        f.write(f"\n  Control mean (all years): {control_mean:.4f}\n")

        # Pre-trend test
        pre_betas = results[results["tau"].between(-4, -2)]["beta"].values
        pre_sig = results[results["tau"].between(-4, -2)]["t_stat"].abs().max()
        f.write(f"\nPRE-TREND TEST\n")
        f.write(f"  Max |t| for τ ∈ [-4, -2]: {pre_sig:.2f}\n")
        if pre_sig < 1.96:
            f.write("  → No evidence of pre-trends (good).\n")
        else:
            f.write("  → ⚠️ Pre-trend detected. Interpret with caution.\n")

        # Post-treatment average
        post_betas = results[results["tau"] >= 0]
        avg_post = post_betas["beta"].mean()
        f.write(f"\nPOST-TREATMENT AVERAGE\n")
        f.write(f"  Mean β for τ ≥ 0: {avg_post:.4f}\n")
        if avg_post > 0:
            f.write(f"  → Outflows increase by {avg_post:.4f} pp after conduct ends.\n")
            f.write(f"  → Relative to control mean ({control_mean:.4f}): "
                    f"+{avg_post / control_mean * 100:.1f}%\n")

    print(f"\n[written] {OUT_REPORT}")

    # Save panel for replication
    con.sql(f"""
        COPY (SELECT * FROM panel)
        TO '{OUT_PANEL}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    print(f"[written] {OUT_PANEL}")

    # ── Step 8: Figure ───────────────────────────────────────────────────────

    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        fig, ax = plt.subplots(figsize=(9, 5.5))

        taus = results["tau"].values
        betas = results["beta"].values
        ci_lo = results["ci_lo"].values
        ci_hi = results["ci_hi"].values

        # Confidence intervals
        ax.fill_between(taus, ci_lo, ci_hi, alpha=0.15, color="#2166ac")
        ax.plot(taus, betas, "o-", color="#2166ac", linewidth=2, markersize=6)

        # Reference lines
        ax.axhline(0, color="grey", linestyle="-", linewidth=0.8)
        ax.axvline(-0.5, color="red", linestyle="--", linewidth=1, alpha=0.5,
                   label="Conduct ends")

        # Shade pre-treatment
        ax.axvspan(min(taus) - 0.5, -0.5, alpha=0.05, color="green")
        ax.axvspan(-0.5, max(taus) + 0.5, alpha=0.05, color="red")

        ax.set_xlabel(r"Event time ($\tau$ = year $-$ conduct end year)", fontsize=11)
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
        print("  matplotlib not available; skipping figure")

    con.close()
    print(f"\nTotal time: {time.time() - t0:.1f}s")
    print("\n--- report preview ---")
    print(OUT_REPORT.read_text())


if __name__ == "__main__":
    main()
