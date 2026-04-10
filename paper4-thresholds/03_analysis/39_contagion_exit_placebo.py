#!/usr/bin/env python3
"""
39_contagion_exit_placebo.py — Placebo: firms absorbing workers from non-cartel exits

If the win-rate and price effects are truly about cartel knowledge transfer,
they should NOT appear when firms absorb workers from non-cartel firms that
simply exit the BEC platform.

Design: same DiD as scripts 37-38, but treatment = absorbing workers from
non-cartel firms that stopped bidding (exit firms from script 33).

Outcomes: win_rate + log(bid_price / ref_price)
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

OUT_REPORT = INTER / "contagion_exit_placebo.txt"
OUT_FIGURE = FIGS / "contagion_exit_placebo.pdf"

EVENT_WINDOW = (-3, 4)


def run_event_study(panel_df, outcome_col, tau_values, min_tau):
    """Run weighted TWFE event study, return results DataFrame."""
    df = panel_df.dropna(subset=[outcome_col]).copy()
    if len(df) < 100:
        return None, 0, 0

    for tau in tau_values:
        df[f"tau_{tau}"] = ((df["treated"] == 1) & (df["tau"] == tau)).astype(float)

    df["firm_id"] = df["firm"].astype("category").cat.codes
    df["iy_id"] = df["item_year"].astype("category").cat.codes

    y = df[outcome_col].values.astype(float)
    w = df["weight"].values.astype(float)
    w_sqrt = np.sqrt(w)

    df["wy"] = y * w
    fm = (df.groupby("firm_id")["wy"].transform("sum") /
          df.groupby("firm_id")["weight"].transform("sum")).values
    ym = (df.groupby("iy_id")["wy"].transform("sum") /
          df.groupby("iy_id")["weight"].transform("sum")).values
    gm = (w * y).sum() / w.sum()
    y_dm = w_sqrt * (y - fm - ym + gm)

    X_cols = [f"tau_{t}" for t in tau_values]
    X = df[X_cols].values.astype(float)
    X_dm = np.zeros_like(X)
    for j, col in enumerate(X_cols):
        df[f"w{col}"] = X[:, j] * w
        f_m = (df.groupby("firm_id")[f"w{col}"].transform("sum") /
               df.groupby("firm_id")["weight"].transform("sum")).values
        i_m = (df.groupby("iy_id")[f"w{col}"].transform("sum") /
               df.groupby("iy_id")["weight"].transform("sum")).values
        g_m = (w * X[:, j]).sum() / w.sum()
        X_dm[:, j] = w_sqrt * (X[:, j] - f_m - i_m + g_m)

    from numpy.linalg import lstsq
    beta, _, _, _ = lstsq(X_dm, y_dm, rcond=None)
    e = y_dm - X_dm @ beta
    n_obs, k = len(y_dm), len(beta)

    firms = df["firm_id"].values
    unique_firms = np.unique(firms)
    n_clusters = len(unique_firms)
    XtX_inv = np.linalg.inv(X_dm.T @ X_dm)
    meat = np.zeros((k, k))
    for g in unique_firms:
        mask = firms == g
        score = X_dm[mask].T @ e[mask]
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
    return results, n_obs, n_clusters


def main() -> None:
    t0 = time.time()
    INTER.mkdir(parents=True, exist_ok=True)
    FIGS.mkdir(parents=True, exist_ok=True)

    con = duckdb.connect()
    con.sql("PRAGMA threads=12; PRAGMA memory_limit='14GB'")
    con.sql("PRAGMA temp_directory='/tmp/duckdb_spill'")
    rais_glob = str(RAIS_DIR / "rais_vinculos_*.parquet")

    # ── Step 1: Identify exit firms (non-cartel, stopped bidding 2011-2014) ──

    print("Step 1: Identifying exit firms...", flush=True)

    con.sql(f"""
        CREATE TABLE cartel_firms AS
        SELECT DISTINCT cnpj_raiz FROM read_parquet('{GROUND_TRUTH}')
        WHERE sp_relevant=1
    """)

    con.sql(f"""
        CREATE TABLE exit_firms AS
        WITH bids AS (
            SELECT LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8] AS cnpj_raiz, year
            FROM read_parquet('{PAIRS_PREGAO}')
        )
        SELECT cnpj_raiz, MAX(year) AS exit_year
        FROM bids
        WHERE cnpj_raiz NOT IN (SELECT cnpj_raiz FROM cartel_firms)
        GROUP BY cnpj_raiz
        HAVING MAX(year) BETWEEN 2011 AND 2014
           AND COUNT(DISTINCT year) >= 2
    """)
    n_exit = con.sql("SELECT count(*) FROM exit_firms").fetchone()[0]
    print(f"  exit firms: {n_exit:,}")

    # ── Step 2: Workers who move from exit firms to other BEC firms ──────────

    print("Step 2: Building placebo treatment...", flush=True)

    con.sql(f"""
        CREATE TABLE worker_year AS
        SELECT DISTINCT pis, cnpj_raiz, ano AS year
        FROM read_parquet('{rais_glob}')
        WHERE cnpj_raiz IN (SELECT cnpj_raiz FROM read_parquet('{BEC_FIRMS}'))
          AND pis IS NOT NULL AND cnpj_raiz IS NOT NULL
    """)

    # Workers at exit firms in the 2 years before exit
    con.sql("""
        CREATE TABLE exit_workers AS
        SELECT DISTINCT w.pis, w.cnpj_raiz AS exit_cnpj, ef.exit_year
        FROM worker_year w
        JOIN exit_firms ef ON w.cnpj_raiz = ef.cnpj_raiz
        WHERE w.year BETWEEN ef.exit_year - 1 AND ef.exit_year
    """)

    # Their first appearance at a different BEC firm after exit
    con.sql("""
        CREATE TABLE placebo_treatment AS
        SELECT w2.cnpj_raiz AS firm, MIN(w2.year) AS arrival_year
        FROM exit_workers ew
        JOIN worker_year w2 ON ew.pis = w2.pis
        WHERE w2.cnpj_raiz != ew.exit_cnpj
          AND w2.year > ew.exit_year
          AND w2.cnpj_raiz NOT IN (SELECT cnpj_raiz FROM exit_firms)
          AND w2.cnpj_raiz NOT IN (SELECT cnpj_raiz FROM cartel_firms)
        GROUP BY w2.cnpj_raiz
    """)
    n_placebo = con.sql("SELECT count(*) FROM placebo_treatment").fetchone()[0]
    print(f"  placebo treated firms: {n_placebo:,}")

    # ── Step 3: Item codes from exit firms ───────────────────────────────────

    con.sql(f"""
        CREATE TABLE exit_items AS
        SELECT DISTINCT "códigoitem"
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8]
              IN (SELECT cnpj_raiz FROM exit_firms)
    """)

    # ── Step 4: Build panels ─────────────────────────────────────────────────

    print("Step 4: Building panels...", flush=True)

    # All bids on exit-firm items (excl exit firms and cartel firms)
    con.sql(f"""
        CREATE TABLE all_bids AS
        SELECT
            LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8] AS firm,
            "códigoitem" AS item, year,
            flagvencedor AS won,
            CASE WHEN "valorunitárioreferência" > 0 AND "valorunitárioproposta" > 0
                THEN LN("valorunitárioproposta" / "valorunitárioreferência")
                ELSE NULL END AS log_price_ratio
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE "códigoitem" IN (SELECT "códigoitem" FROM exit_items)
          AND LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8]
              NOT IN (SELECT cnpj_raiz FROM exit_firms)
          AND LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8]
              NOT IN (SELECT cnpj_raiz FROM cartel_firms)
    """)

    # Aggregate to firm × item × year
    panel = con.sql("""
        SELECT firm, item, year,
               count(*) AS n_bids,
               avg(won) AS win_rate,
               avg(log_price_ratio) AS mean_log_price_ratio
        FROM all_bids
        GROUP BY firm, item, year
    """).fetchdf()

    # Add treatment
    treatment_map = dict(con.sql("SELECT firm, arrival_year FROM placebo_treatment").fetchdf().values)
    placebo_firms = set(treatment_map.keys())

    panel["treated"] = panel["firm"].isin(placebo_firms).astype(int)
    panel["arrival_year"] = panel["firm"].map(treatment_map)
    panel["event_time"] = np.where(
        panel["treated"] == 1, panel["year"] - panel["arrival_year"], np.nan
    )

    # Simple CEM on pre-period (terciles of n_bids and win_rate)
    PSEUDO = 2014
    pre = panel[panel["year"].between(
        panel["arrival_year"].fillna(PSEUDO) - 2,
        panel["arrival_year"].fillna(PSEUDO) - 1
    )].groupby("firm").agg(
        pre_n=("n_bids", "sum"),
        pre_wr=("win_rate", "mean"),
        treated=("treated", "first"),
    ).reset_index()
    pre = pre[pre["pre_n"] >= 2].copy()

    for v in ["pre_n", "pre_wr"]:
        pre[f"{v}_q"] = pd.qcut(pre[v], q=3, labels=False, duplicates="drop")

    pre["cell"] = pre["pre_n_q"].astype(str) + "_" + pre["pre_wr_q"].astype(str)
    cc = pre.groupby("cell")["treated"].agg(nt="sum", n="count").reset_index()
    cc["nc"] = cc["n"] - cc["nt"]
    valid = cc[(cc["nt"] > 0) & (cc["nc"] > 0)]["cell"]
    matched = pre[pre["cell"].isin(valid)].copy()

    cw = matched.groupby("cell")["treated"].agg(nt="sum", n="count").reset_index()
    cw["nc"] = cw["n"] - cw["nt"]
    cw["wc"] = cw["nt"] / cw["nc"]
    matched = matched.merge(cw[["cell", "wc"]], on="cell")
    matched["weight"] = np.where(matched["treated"] == 1, 1.0, matched["wc"])

    n_t_m = int(matched["treated"].sum())
    n_c_m = len(matched) - n_t_m
    print(f"  CEM matched: treated={n_t_m}, control={n_c_m}")

    matched_firms = set(matched["firm"])
    weight_map = dict(zip(matched["firm"], matched["weight"]))

    panel_m = panel[panel["firm"].isin(matched_firms)].copy()
    panel_m["weight"] = panel_m["firm"].map(weight_map).fillna(1.0)
    panel_m["item_year"] = panel_m["item"].astype(str) + "_" + panel_m["year"].astype(str)

    min_tau, max_tau = EVENT_WINDOW
    panel_m["tau"] = panel_m["event_time"].clip(lower=min_tau, upper=max_tau)
    tau_values = sorted([t for t in range(min_tau, max_tau + 1) if t != -1])

    # ── Step 5: Run event studies ────────────────────────────────────────────

    print("Step 5: Running event studies...", flush=True)

    wr_results, wr_n, wr_nc = run_event_study(panel_m, "win_rate", tau_values, min_tau)
    pr_results, pr_n, pr_nc = run_event_study(panel_m, "mean_log_price_ratio", tau_values, min_tau)

    con.close()

    # ── Step 6: Write report ─────────────────────────────────────────────────

    # Load cartel results for comparison (hardcoded from scripts 37-38)
    cartel_wr = {-3: -0.0115, -2: 0.0175, -1: 0, 0: 0.0179, 1: 0.0479,
                 2: 0.0134, 3: 0.0472, 4: 0.0309}
    cartel_pr = {-3: 0.1109, -2: 0.1059, -1: 0, 0: 0.1119, 1: 0.1915,
                 2: 0.3632, 3: 0.2705, 4: 0.3719}

    with open(OUT_REPORT, "w") as f:
        f.write("Contagion Exit Placebo\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")

        f.write("DESIGN\n")
        f.write("-" * 50 + "\n")
        f.write(f"Placebo treatment: absorbing workers from non-cartel\n")
        f.write(f"  exit firms (stopped bidding 2011-2014)\n")
        f.write(f"CEM matched: treated={n_t_m}, control={n_c_m}\n\n")

        # Win rate
        f.write("A. WIN RATE EVENT STUDY\n")
        f.write("-" * 65 + "\n")
        if wr_results is not None:
            f.write(f"N obs: {wr_n:,}  N firms: {wr_nc:,}\n\n")
            f.write(f"{'τ':>4s}  {'β(placebo)':>10s}  {'t':>7s}  {'β(cartel)':>10s}\n")
            f.write("-" * 45 + "\n")
            for _, row in wr_results.iterrows():
                tau = int(row["tau"])
                cb = cartel_wr.get(tau, np.nan)
                sig = "***" if abs(row["t_stat"]) > 2.576 else \
                      "**" if abs(row["t_stat"]) > 1.96 else \
                      "*" if abs(row["t_stat"]) > 1.645 else ""
                f.write(f"{tau:>4d}  {row['beta']:>10.4f}  {row['t_stat']:>7.2f}  "
                        f"{cb:>10.4f} {sig}\n")

            wr_post = wr_results[wr_results["tau"] >= 0]["beta"].mean()
            cartel_wr_post = np.mean([v for k, v in cartel_wr.items() if k >= 0])
            f.write(f"\n  Placebo post mean: {wr_post:+.4f}\n")
            f.write(f"  Cartel post mean:  {cartel_wr_post:+.4f}\n")
            if abs(wr_post) < abs(cartel_wr_post) * 0.5:
                f.write("  → Placebo effect is SMALLER → cartel effect is distinctive\n")
            elif abs(wr_post) > abs(cartel_wr_post) * 0.8:
                f.write("  → Placebo effect is SIMILAR → effect is generic\n")
            else:
                f.write("  → Placebo effect is intermediate\n")

        # Price
        f.write("\nB. PRICE EVENT STUDY\n")
        f.write("-" * 65 + "\n")
        if pr_results is not None:
            f.write(f"N obs: {pr_n:,}  N firms: {pr_nc:,}\n\n")
            f.write(f"{'τ':>4s}  {'β(placebo)':>10s}  {'t':>7s}  {'β(cartel)':>10s}\n")
            f.write("-" * 45 + "\n")
            for _, row in pr_results.iterrows():
                tau = int(row["tau"])
                cb = cartel_pr.get(tau, np.nan)
                sig = "***" if abs(row["t_stat"]) > 2.576 else \
                      "**" if abs(row["t_stat"]) > 1.96 else \
                      "*" if abs(row["t_stat"]) > 1.645 else ""
                f.write(f"{tau:>4d}  {row['beta']:>10.4f}  {row['t_stat']:>7.2f}  "
                        f"{cb:>10.4f} {sig}\n")

            pr_post = pr_results[pr_results["tau"] >= 0]["beta"].mean()
            cartel_pr_post = np.mean([v for k, v in cartel_pr.items() if k >= 0])
            f.write(f"\n  Placebo post mean: {pr_post:+.4f}\n")
            f.write(f"  Cartel post mean:  {cartel_pr_post:+.4f}\n")
            if abs(pr_post) < abs(cartel_pr_post) * 0.5:
                f.write("  → Placebo price effect is SMALLER → cartel effect is distinctive\n")
            elif abs(pr_post) > abs(cartel_pr_post) * 0.8:
                f.write("  → Placebo price effect is SIMILAR → effect is generic\n")
            else:
                f.write("  → Placebo price effect is intermediate\n")

    print(f"\n[written] {OUT_REPORT}")

    # ── Figure ───────────────────────────────────────────────────────────────

    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        fig, axes = plt.subplots(1, 2, figsize=(13, 5))

        for idx, (title, res, cartel_vals, ylabel) in enumerate([
            ("A. Win rate", wr_results, cartel_wr, "Win rate (rel. to τ=-1)"),
            ("B. log(price ratio)", pr_results, cartel_pr, "log(bid/ref price)"),
        ]):
            ax = axes[idx]
            if res is not None:
                ax.fill_between(res["tau"], res["ci_lo"], res["ci_hi"],
                                alpha=0.12, color="#4575b4")
                ax.plot(res["tau"], res["beta"], "o-", color="#4575b4",
                        linewidth=2, markersize=5, label="Exit-firm placebo")

            ct = sorted(cartel_vals.keys())
            ax.plot(ct, [cartel_vals[t] for t in ct], "s--", color="#d73027",
                    linewidth=1.5, markersize=5, alpha=0.7, label="Cartel (matched)")

            ax.axhline(0, color="grey", linewidth=0.8)
            ax.axvline(-0.5, color="black", linestyle="--", linewidth=0.8, alpha=0.4)
            ax.set_xlabel(r"$\tau$")
            ax.set_ylabel(ylabel)
            ax.set_title(title)
            ax.legend(fontsize=8)
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
