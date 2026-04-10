#!/usr/bin/env python3
"""
36_contagion_did.py — Core DiD: bidding behavior after absorbing ex-cartel workers

Design
------
Unit: firm × item code × year
Treated: BEC firms that absorbed ≥1 ex-cartel worker post-conduct
         AND bid on the same item codes pre & post arrival
Control: BEC firms that bid on same item codes, never absorbed ex-cartel workers
Event: arrival_year = year the first ex-cartel worker appeared at the firm

Specification:
  y_{ijt} = α_i + γ_{jt} + Σ_{τ≠-1} β_τ · D_{iτ} + ε_{ijt}

  α_i = firm FE, γ_{jt} = item×year FE, D_{iτ} = event-time indicator

Outcomes:
  - win_rate: wins / bids for this item code in this year
  - n_bids: number of bids submitted

Heterogeneity:
  - By worker type: firms absorbing ≥1 manager vs only operational

Output
------
- 02_data/intermediate/contagion_did.txt
- 04_figures/contagion_event_study.pdf
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

OUT_REPORT = INTER / "contagion_did.txt"
OUT_FIGURE = FIGS / "contagion_event_study.pdf"

EVENT_WINDOW = (-3, 4)


def main() -> None:
    t0 = time.time()
    INTER.mkdir(parents=True, exist_ok=True)
    FIGS.mkdir(parents=True, exist_ok=True)

    con = duckdb.connect()
    con.sql("PRAGMA threads=12; PRAGMA memory_limit='14GB'")
    con.sql("PRAGMA temp_directory='/tmp/duckdb_spill'")

    rais_glob = str(RAIS_DIR / "rais_vinculos_*.parquet")

    # ── Step 1: Build treatment — first ex-cartel worker arrival per firm ────

    print("Step 1: Building treatment assignment...", flush=True)

    con.sql(f"""
        CREATE OR REPLACE TABLE cartel_firms AS
        SELECT DISTINCT cnpj_raiz, setor,
               cartel_start_year::INT AS start_yr,
               cartel_end_year::INT AS end_yr
        FROM read_parquet('{GROUND_TRUTH}')
        WHERE sp_relevant = 1 AND processo IS NOT NULL
          AND cartel_start_year IS NOT NULL AND cartel_end_year <= 2016
    """)

    # Worker-year at BEC firms with occupation
    con.sql(f"""
        CREATE OR REPLACE TABLE worker_year AS
        SELECT DISTINCT pis, cnpj_raiz, ano AS year,
               LEFT(cbo2002, 1) AS cbo_major
        FROM read_parquet('{rais_glob}')
        WHERE cnpj_raiz IN (SELECT cnpj_raiz FROM read_parquet('{BEC_FIRMS}'))
          AND pis IS NOT NULL AND cnpj_raiz IS NOT NULL
    """)

    # Cartel workers during conduct
    con.sql("""
        CREATE OR REPLACE TABLE cartel_workers AS
        SELECT DISTINCT w.pis, w.cnpj_raiz AS cartel_cnpj, cf.setor, cf.end_yr,
               CASE WHEN w.cbo_major IN ('1','2') THEN 1 ELSE 0 END AS is_manager
        FROM worker_year w
        JOIN cartel_firms cf ON w.cnpj_raiz = cf.cnpj_raiz
        WHERE w.year BETWEEN cf.start_yr AND cf.end_yr
    """)

    # First arrival at receiving firm
    con.sql("""
        CREATE OR REPLACE TABLE treatment AS
        SELECT
            w2.cnpj_raiz AS firm,
            MIN(w2.year) AS arrival_year,
            count(DISTINCT cw.pis) AS n_absorbed,
            count(DISTINCT CASE WHEN cw.is_manager = 1 THEN cw.pis END) AS n_managers,
            CASE WHEN count(DISTINCT CASE WHEN cw.is_manager = 1
                THEN cw.pis END) > 0 THEN 1 ELSE 0 END AS absorbed_manager
        FROM cartel_workers cw
        JOIN worker_year w2 ON cw.pis = w2.pis
        WHERE w2.cnpj_raiz != cw.cartel_cnpj
          AND w2.year > cw.end_yr
          AND w2.cnpj_raiz NOT IN (
              SELECT cnpj_raiz FROM cartel_firms WHERE setor = cw.setor)
        GROUP BY w2.cnpj_raiz
    """)
    n_treated = con.sql("SELECT count(*) FROM treatment").fetchone()[0]
    print(f"  treated firms: {n_treated:,}")

    # ── Step 2: Build firm × item × year panel ───────────────────────────────

    print("Step 2: Building firm × item × year panel...", flush=True)

    # Item codes where cartel firms bid
    con.sql(f"""
        CREATE OR REPLACE TABLE cartel_item_codes AS
        SELECT DISTINCT "códigoitem"
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE LPAD(CAST("códigofornecedor" AS VARCHAR), 14, '0')[1:8] IN (
            SELECT cnpj_raiz FROM cartel_firms
        )
    """)

    # All bids on cartel items by BEC firms (excluding cartel firms themselves)
    con.sql(f"""
        CREATE OR REPLACE TABLE bids AS
        SELECT
            LPAD(CAST("códigofornecedor" AS VARCHAR), 14, '0')[1:8] AS firm,
            "códigoitem" AS item,
            year,
            flagvencedor AS won
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE "códigoitem" IN (SELECT "códigoitem" FROM cartel_item_codes)
          AND LPAD(CAST("códigofornecedor" AS VARCHAR), 14, '0')[1:8] NOT IN (
              SELECT cnpj_raiz FROM cartel_firms)
    """)

    # Aggregate to firm × item × year
    con.sql("""
        CREATE OR REPLACE TABLE panel AS
        SELECT
            b.firm, b.item, b.year,
            count(*) AS n_bids,
            sum(b.won) AS n_wins,
            avg(b.won) AS win_rate,
            CASE WHEN t.firm IS NOT NULL THEN 1 ELSE 0 END AS treated,
            t.arrival_year,
            t.n_absorbed,
            t.absorbed_manager,
            CASE WHEN t.firm IS NOT NULL THEN b.year - t.arrival_year
                 ELSE NULL END AS event_time
        FROM bids b
        LEFT JOIN treatment t ON b.firm = t.firm
        GROUP BY b.firm, b.item, b.year,
                 t.firm, t.arrival_year, t.n_absorbed, t.absorbed_manager
    """)

    stats = con.sql("""
        SELECT count(*) AS n_obs,
               count(DISTINCT firm) AS n_firms,
               count(DISTINCT item) AS n_items,
               sum(CASE WHEN treated = 1 THEN 1 ELSE 0 END) AS n_treated_obs,
               count(DISTINCT CASE WHEN treated = 1 THEN firm END) AS n_treated_firms
        FROM panel
    """).fetchdf()
    print(f"  panel:\n{stats.to_string()}")

    # ── Step 3: Event-study estimation ───────────────────────────────────────

    print("Step 3: Estimating event study...", flush=True)

    df = con.sql("SELECT * FROM panel").fetchdf()
    con.close()

    # Create item×year FE
    df["item_year"] = df["item"].astype(str) + "_" + df["year"].astype(str)
    df["firm_id"] = df["firm"].astype("category").cat.codes
    df["item_year_id"] = df["item_year"].astype("category").cat.codes

    # Clip event time
    min_tau, max_tau = EVENT_WINDOW
    df["tau"] = df["event_time"].clip(lower=min_tau, upper=max_tau)

    # Create event-time dummies (omit τ = -1)
    tau_values = sorted([t for t in range(min_tau, max_tau + 1) if t != -1])
    for tau in tau_values:
        df[f"tau_{tau}"] = ((df["treated"] == 1) & (df["tau"] == tau)).astype(float)

    # Outcome: win_rate
    y = df["win_rate"].values.astype(float)

    # Demean by firm and item×year (Frisch-Waugh for two-way FE)
    firm_means = df.groupby("firm_id")["win_rate"].transform("mean").values
    iy_means = df.groupby("item_year_id")["win_rate"].transform("mean").values
    grand_mean = y.mean()
    y_dm = y - firm_means - iy_means + grand_mean

    X_cols = [f"tau_{t}" for t in tau_values]
    X = df[X_cols].values.astype(float)
    X_dm = X.copy()
    for j in range(X.shape[1]):
        col = X_cols[j]
        fm = df.groupby("firm_id")[col].transform("mean").values
        ym = df.groupby("item_year_id")[col].transform("mean").values
        gm = X[:, j].mean()
        X_dm[:, j] = X[:, j] - fm - ym + gm

    # OLS on demeaned data
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

    # ── Step 4: Heterogeneity — absorbed manager vs only operational ────────

    print("Step 4: Heterogeneity by worker type...", flush=True)

    het_results = {}
    for label, sub_mask_val in [("absorbed_manager", 1), ("only_operational", 0)]:
        sub = df[(df["treated"] == 1) & (df["absorbed_manager"] == sub_mask_val)]
        # Need to re-run on full sample with interaction
        # Simpler: separate event study on treated subsample vs same controls
        sub_df = pd.concat([
            df[df["treated"] == 0],  # controls
            df[(df["treated"] == 1) & (df["absorbed_manager"] == sub_mask_val)]
        ]).copy()

        y_s = sub_df["win_rate"].values.astype(float)
        sub_df["firm_id_s"] = sub_df["firm"].astype("category").cat.codes
        sub_df["iy_id_s"] = sub_df["item_year"].astype("category").cat.codes

        fm_s = sub_df.groupby("firm_id_s")["win_rate"].transform("mean").values
        iy_s = sub_df.groupby("iy_id_s")["win_rate"].transform("mean").values
        gm_s = y_s.mean()
        y_s_dm = y_s - fm_s - iy_s + gm_s

        # Rebuild tau dummies for this subsample
        sub_df["tau_s"] = sub_df["event_time"].clip(lower=min_tau, upper=max_tau)
        X_s_cols = []
        for tau in tau_values:
            col = f"tau_s_{tau}"
            sub_df[col] = ((sub_df["treated"] == 1) & (sub_df["tau_s"] == tau)).astype(float)
            X_s_cols.append(col)

        X_s = sub_df[X_s_cols].values.astype(float)
        X_s_dm = X_s.copy()
        for j in range(X_s.shape[1]):
            col = X_s_cols[j]
            fm = sub_df.groupby("firm_id_s")[col].transform("mean").values
            ym = sub_df.groupby("iy_id_s")[col].transform("mean").values
            gm = X_s[:, j].mean()
            X_s_dm[:, j] = X_s[:, j] - fm - ym + gm

        beta_s, _, _, _ = lstsq(X_s_dm, y_s_dm, rcond=None)
        e_s = y_s_dm - X_s_dm @ beta_s
        n_s = len(y_s_dm)

        firms_s = sub_df["firm_id_s"].values
        unique_s = np.unique(firms_s)
        nc_s = len(unique_s)
        XtX_s = np.linalg.inv(X_s_dm.T @ X_s_dm)
        meat_s = np.zeros((len(beta_s), len(beta_s)))
        for g in unique_s:
            mask = firms_s == g
            meat_s += np.outer(X_s_dm[mask].T @ e_s[mask], X_s_dm[mask].T @ e_s[mask])
        corr_s = (nc_s / (nc_s - 1)) * ((n_s - 1) / (n_s - len(beta_s)))
        V_s = corr_s * XtX_s @ meat_s @ XtX_s
        se_s = np.sqrt(np.diag(V_s))

        het_results[label] = pd.DataFrame({
            "tau": tau_values, "beta": beta_s, "se": se_s,
            "t_stat": beta_s / se_s,
        })

    # ── Step 5: Write report ─────────────────────────────────────────────────

    print("Step 5: Writing report...", flush=True)

    control_mean = df[df["treated"] == 0]["win_rate"].mean()

    with open(OUT_REPORT, "w") as f:
        f.write("Collusion Contagion: DiD Estimation\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")

        f.write("DESIGN\n")
        f.write("-" * 50 + "\n")
        f.write(f"Outcome: win rate (firm × item × year)\n")
        f.write(f"FEs: firm + item×year\n")
        f.write(f"Clustering: firm\n")
        f.write(f"N obs: {n_obs:,}  N firms: {n_clusters:,}\n")
        f.write(f"N treated firms: {int(stats['n_treated_firms'].iloc[0]):,}\n")
        f.write(f"Control mean win rate: {control_mean:.4f}\n\n")

        f.write("A. MAIN EVENT STUDY (all treated firms)\n")
        f.write("-" * 60 + "\n")
        f.write(f"{'τ':>4s}  {'β':>8s}  {'SE':>8s}  {'t':>7s}  {'95% CI':>20s}\n")
        f.write("-" * 60 + "\n")
        for _, row in results.iterrows():
            tau = int(row["tau"])
            sig = "***" if abs(row["t_stat"]) > 2.576 else \
                  "**" if abs(row["t_stat"]) > 1.96 else \
                  "*" if abs(row["t_stat"]) > 1.645 else ""
            f.write(f"{tau:>4d}  {row['beta']:>8.4f}  {row['se']:>8.4f}  "
                    f"{row['t_stat']:>7.2f}  "
                    f"[{row['ci_lo']:>8.4f}, {row['ci_hi']:>8.4f}] {sig}\n")

        pre_max_t = results[results["tau"].between(min_tau, -2)]["t_stat"].abs().max()
        post_mean = results[results["tau"] >= 0]["beta"].mean()
        f.write(f"\n  Pre-trend max |t|: {pre_max_t:.2f}\n")
        f.write(f"  Post-treatment mean β: {post_mean:+.4f} "
                f"({post_mean/control_mean*100:+.1f}% of control mean)\n\n")

        f.write("B. HETEROGENEITY BY WORKER TYPE\n")
        f.write("-" * 60 + "\n")
        for label, hr in het_results.items():
            post_b = hr[hr["tau"] >= 0]["beta"].mean()
            f.write(f"\n  {label}:\n")
            f.write(f"    Post-treatment mean β: {post_b:+.4f}\n")
            f.write(f"    τ   β        SE       t\n")
            for _, row in hr.iterrows():
                sig = "***" if abs(row["t_stat"]) > 2.576 else \
                      "**" if abs(row["t_stat"]) > 1.96 else \
                      "*" if abs(row["t_stat"]) > 1.645 else ""
                f.write(f"    {int(row['tau']):>2d}  {row['beta']:>+8.4f}  "
                        f"{row['se']:>7.4f}  {row['t_stat']:>6.2f} {sig}\n")

        mgr_post = het_results["absorbed_manager"][
            het_results["absorbed_manager"]["tau"] >= 0]["beta"].mean()
        ops_post = het_results["only_operational"][
            het_results["only_operational"]["tau"] >= 0]["beta"].mean()

        f.write(f"\n  COMPARISON:\n")
        f.write(f"    Absorbed manager:    mean post β = {mgr_post:+.4f}\n")
        f.write(f"    Only operational:    mean post β = {ops_post:+.4f}\n")
        if abs(mgr_post) > abs(ops_post) * 1.5 and mgr_post > 0:
            f.write("    → Manager absorption drives a larger effect.\n")
            f.write("    → Consistent with knowledge-transfer mechanism.\n")
        elif abs(mgr_post) < abs(ops_post) * 0.5 or mgr_post <= 0:
            f.write("    → No evidence that managers drive the effect.\n")
            f.write("    → Inconsistent with knowledge-transfer mechanism.\n")
        else:
            f.write("    → Effects are similar across worker types.\n")

    print(f"\n[written] {OUT_REPORT}")

    # ── Step 6: Figure ───────────────────────────────────────────────────────

    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        fig, axes = plt.subplots(1, 2, figsize=(13, 5), sharey=True)

        # Panel A: Main event study
        ax = axes[0]
        taus = results["tau"].values
        betas = results["beta"].values
        ci_lo = results["ci_lo"].values
        ci_hi = results["ci_hi"].values

        ax.fill_between(taus, ci_lo, ci_hi, alpha=0.15, color="#2166ac")
        ax.plot(taus, betas, "o-", color="#2166ac", linewidth=2, markersize=6)
        ax.axhline(0, color="grey", linewidth=0.8)
        ax.axvline(-0.5, color="red", linestyle="--", linewidth=1, alpha=0.5)
        ax.set_xlabel(r"$\tau$ (years since first ex-cartel worker arrival)")
        ax.set_ylabel("Win rate (relative to τ = -1)")
        ax.set_title("A. All treated firms")
        ax.set_xticks(taus)
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)

        # Panel B: Heterogeneity
        ax = axes[1]
        for label, color, marker in [
            ("absorbed_manager", "#d73027", "s"),
            ("only_operational", "#4575b4", "o"),
        ]:
            hr = het_results[label]
            # Add reference point
            hr_full = pd.concat([hr, pd.DataFrame({"tau": [-1], "beta": [0.0]})]) \
                .sort_values("tau")
            ax.plot(hr_full["tau"], hr_full["beta"], f"{marker}-", color=color,
                    linewidth=2, markersize=5,
                    label=label.replace("_", " ").title())

        ax.axhline(0, color="grey", linewidth=0.8)
        ax.axvline(-0.5, color="red", linestyle="--", linewidth=1, alpha=0.5)
        ax.set_xlabel(r"$\tau$ (years since first ex-cartel worker arrival)")
        ax.set_title("B. By worker type absorbed")
        ax.legend(fontsize=8)
        ax.set_xticks(taus)
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)

        fig.tight_layout()
        fig.savefig(OUT_FIGURE, dpi=300, bbox_inches="tight")
        plt.close(fig)
        print(f"[written] {OUT_FIGURE}")
    except ImportError:
        print("  matplotlib not available")

    print(f"\nTotal time: {time.time() - t0:.1f}s")
    print("\n--- report ---")
    print(OUT_REPORT.read_text())


if __name__ == "__main__":
    main()
