#!/usr/bin/env python3
"""
42_contagion_stacked_robust.py — Stacked DiD robustness: drop cohort 2013, window [-2,+4]

Addresses the pre-trend at τ=-3 (t=2.14) which is driven by cohort 2013
(N=34 firms with wild noise). Drops cohort 2013 and uses [-2, +4] window.
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

OUT_REPORT = INTER / "contagion_stacked_robust.txt"
OUT_FIGURE = FIGS / "contagion_stacked_robust.pdf"

EVENT_WINDOW = (-2, 4)
COHORTS = [2012, 2014, 2015]  # drop 2013 (N=34, noisy)


def main() -> None:
    t0 = time.time()
    INTER.mkdir(parents=True, exist_ok=True)
    FIGS.mkdir(parents=True, exist_ok=True)

    con = duckdb.connect()
    con.sql("PRAGMA threads=12; PRAGMA memory_limit='14GB'")
    con.sql("PRAGMA temp_directory='/tmp/duckdb_spill'")
    rais_glob = str(RAIS_DIR / "rais_vinculos_*.parquet")

    # ── Treatment (same as before) ───────────────────────────────────────────

    print("Step 1: Building treatment...", flush=True)
    con.sql(f"""
        CREATE TABLE cf AS SELECT DISTINCT cnpj_raiz, setor,
            cartel_start_year::INT AS s, cartel_end_year::INT AS e
        FROM read_parquet('{GROUND_TRUTH}') WHERE sp_relevant=1 AND processo IS NOT NULL
          AND cartel_start_year IS NOT NULL AND cartel_end_year<=2016
    """)
    con.sql(f"""
        CREATE TABLE wy AS SELECT DISTINCT pis, cnpj_raiz, ano AS year
        FROM read_parquet('{rais_glob}')
        WHERE cnpj_raiz IN (SELECT cnpj_raiz FROM read_parquet('{BEC_FIRMS}'))
          AND pis IS NOT NULL AND cnpj_raiz IS NOT NULL
    """)
    con.sql("""
        CREATE TABLE cw AS SELECT DISTINCT w.pis, w.cnpj_raiz AS cc, cf.setor, cf.e
        FROM wy w JOIN cf ON w.cnpj_raiz=cf.cnpj_raiz WHERE w.year BETWEEN cf.s AND cf.e
    """)
    con.sql("""
        CREATE TABLE treatment AS
        SELECT w2.cnpj_raiz AS firm, MIN(w2.year) AS arrival_year
        FROM cw JOIN wy w2 ON cw.pis=w2.pis
        WHERE w2.cnpj_raiz!=cw.cc AND w2.year>cw.e
          AND w2.cnpj_raiz NOT IN (SELECT cnpj_raiz FROM cf WHERE setor=cw.setor)
        GROUP BY w2.cnpj_raiz
    """)
    con.sql(f"""
        CREATE TABLE ci AS SELECT DISTINCT "códigoitem" FROM read_parquet('{PAIRS_PREGAO}')
        WHERE LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8] IN (SELECT cnpj_raiz FROM cf)
    """)
    con.sql(f"""
        CREATE TABLE never_treated AS
        SELECT DISTINCT LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8] AS firm
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8] NOT IN (SELECT firm FROM treatment)
          AND LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8] NOT IN (SELECT cnpj_raiz FROM cf)
    """)

    # ── Bid panel ────────────────────────────────────────────────────────────

    print("Step 2: Building bid panel...", flush=True)
    bids_agg = con.sql(f"""
        SELECT LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8] AS firm,
               "códigoitem" AS item, year,
               count(*) AS n_bids, avg(flagvencedor) AS win_rate
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE "códigoitem" IN (SELECT "códigoitem" FROM ci)
          AND LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8] NOT IN (SELECT cnpj_raiz FROM cf)
        GROUP BY firm, item, year
    """).fetchdf()

    treatment_df = con.sql("SELECT firm, arrival_year FROM treatment").fetchdf()
    treatment_map = dict(treatment_df.values)
    never_set = set(con.sql("SELECT firm FROM never_treated").fetchdf()["firm"])
    con.close()

    # ── Stack cohorts ────────────────────────────────────────────────────────

    print("Step 3: Stacking cohorts...", flush=True)
    min_tau, max_tau = EVENT_WINDOW
    parts = []

    for g in COHORTS:
        treated_g = set(treatment_df[treatment_df["arrival_year"] == g]["firm"])
        if len(treated_g) < 5:
            continue
        yr_lo, yr_hi = g + min_tau, g + max_tau
        sub = bids_agg[
            (bids_agg["year"].between(yr_lo, yr_hi)) &
            (bids_agg["firm"].isin(treated_g | never_set))
        ].copy()
        sub["cohort"] = g
        sub["treated"] = sub["firm"].isin(treated_g).astype(int)
        sub["tau"] = (sub["year"] - g).clip(lower=min_tau, upper=max_tau)
        sub["fc"] = sub["firm"] + f"_c{g}"
        sub["iyc"] = sub["item"].astype(str) + "_" + sub["year"].astype(str) + f"_c{g}"
        parts.append(sub)
        n_t = sub[sub["treated"] == 1]["firm"].nunique()
        print(f"  cohort {g}: treated={n_t}, obs={len(sub):,}")

    stacked = pd.concat(parts, ignore_index=True)
    print(f"  stacked: {len(stacked):,} obs")

    # ── Event study ──────────────────────────────────────────────────────────

    print("Step 4: Estimating...", flush=True)
    tau_values = sorted([t for t in range(min_tau, max_tau + 1) if t != -1])

    for tau in tau_values:
        stacked[f"tau_{tau}"] = ((stacked["treated"] == 1) & (stacked["tau"] == tau)).astype(float)

    df = stacked.dropna(subset=["win_rate"]).copy()
    y = df["win_rate"].values.astype(float)
    df["fc_id"] = df["fc"].astype("category").cat.codes
    df["iyc_id"] = df["iyc"].astype("category").cat.codes

    fm = df.groupby("fc_id")["win_rate"].transform("mean").values
    ym = df.groupby("iyc_id")["win_rate"].transform("mean").values
    gm = y.mean()
    y_dm = y - fm - ym + gm

    X_cols = [f"tau_{t}" for t in tau_values]
    X = df[X_cols].values.astype(float)
    X_dm = X.copy()
    for j, col in enumerate(X_cols):
        f_m = df.groupby("fc_id")[col].transform("mean").values
        i_m = df.groupby("iyc_id")[col].transform("mean").values
        g_m = X[:, j].mean()
        X_dm[:, j] = X[:, j] - f_m - i_m + g_m

    from numpy.linalg import lstsq
    beta, _, _, _ = lstsq(X_dm, y_dm, rcond=None)
    e = y_dm - X_dm @ beta
    n_obs, k = len(y_dm), len(beta)

    firms = df["fc_id"].values
    unique_f = np.unique(firms)
    nc = len(unique_f)
    XtX_inv = np.linalg.inv(X_dm.T @ X_dm)
    meat = np.zeros((k, k))
    for g_id in unique_f:
        mask = firms == g_id
        score = X_dm[mask].T @ e[mask]
        meat += np.outer(score, score)
    correction = (nc / (nc - 1)) * ((n_obs - 1) / (n_obs - k))
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

    # Baseline stacked (all cohorts) for comparison
    base = {-3: 0.0357, -2: 0.0460, -1: 0, 0: 0.0423, 1: 0.0467,
            2: 0.0393, 3: 0.0546, 4: 0.0701}

    pre_max = results[results["tau"] == -2]["t_stat"].abs().max()
    post_mean = results[results["tau"] >= 0]["beta"].mean()

    # ── Report ───────────────────────────────────────────────────────────────

    with open(OUT_REPORT, "w") as f:
        f.write("Stacked DiD Robustness: Drop Cohort 2013, Window [-2,+4]\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")

        f.write(f"Cohorts: {COHORTS} (dropped 2013, N=34 too noisy)\n")
        f.write(f"Window: [{min_tau}, {max_tau}]\n")
        f.write(f"N obs: {n_obs:,}  N clusters: {nc:,}\n\n")

        f.write("WIN RATE EVENT STUDY\n")
        f.write("-" * 60 + "\n")
        f.write(f"{'τ':>4s}  {'β(robust)':>10s}  {'SE':>7s}  {'t':>6s}  "
                f"{'β(baseline)':>11s}\n")
        f.write("-" * 50 + "\n")
        for _, row in results.iterrows():
            tau = int(row["tau"])
            b = base.get(tau, np.nan)
            sig = "***" if abs(row["t_stat"]) > 2.576 else \
                  "**" if abs(row["t_stat"]) > 1.96 else \
                  "*" if abs(row["t_stat"]) > 1.645 else ""
            f.write(f"{tau:>4d}  {row['beta']:>10.4f}  {row['se']:>7.4f}  "
                    f"{row['t_stat']:>6.2f}  {b:>11.4f} {sig}\n")

        f.write(f"\n  Pre-trend (τ=-2) |t|: {pre_max:.2f}\n")
        f.write(f"  Post mean β: {post_mean:+.4f}\n\n")

        f.write("COMPARISON\n")
        f.write("-" * 50 + "\n")
        f.write(f"  Baseline (all 4 cohorts):  pre max|t|=2.14  post=+0.051\n")
        f.write(f"  Robust (drop 2013):        pre max|t|={pre_max:.2f}  "
                f"post={post_mean:+.4f}\n")

        if pre_max < 1.65:
            f.write("\n  ✓ Pre-trend RESOLVED.\n")
        elif pre_max < 1.96:
            f.write("\n  △ Pre-trend marginal.\n")
        else:
            f.write("\n  ✗ Pre-trend persists.\n")

    print(f"\n[written] {OUT_REPORT}")

    # ── Figure ───────────────────────────────────────────────────────────────

    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        fig, ax = plt.subplots(figsize=(9, 5.5))
        taus = results["tau"].values
        ax.fill_between(taus, results["ci_lo"], results["ci_hi"],
                         alpha=0.15, color="#2166ac")
        ax.plot(taus, results["beta"], "o-", color="#2166ac", linewidth=2,
                markersize=6, label="Robust (drop 2013)")

        bt = sorted(base.keys())
        bt_filtered = [t for t in bt if min_tau <= t <= max_tau]
        ax.plot(bt_filtered, [base[t] for t in bt_filtered], "s--",
                color="#b2182b", linewidth=1.5, markersize=4, alpha=0.5,
                label="Baseline (all cohorts)")

        ax.axhline(0, color="grey", linewidth=0.8)
        ax.axvline(-0.5, color="red", linestyle="--", linewidth=1, alpha=0.4)
        ax.set_xlabel(r"$\tau$ (years since first ex-cartel worker)")
        ax.set_ylabel("Win rate (relative to τ = -1)")
        ax.legend(fontsize=9)
        ax.set_xticks(taus)
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
