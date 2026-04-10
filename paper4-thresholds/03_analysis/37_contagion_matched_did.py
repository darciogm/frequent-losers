#!/usr/bin/env python3
"""
37_contagion_matched_did.py — Matched DiD for contagion paper

Resolves the pre-trend at τ=-3 by matching treated firms to controls on
pre-period characteristics measured in the 2 years before the first
ex-cartel worker arrives.

Matching variables (measured in [arrival_year-2, arrival_year-1]):
  - n_workers: firm size from RAIS
  - n_items: number of distinct item codes bid on
  - n_bids: total bids submitted
  - win_rate: wins / bids
  - n_years_active: years with ≥1 bid

Method: Coarsened Exact Matching (CEM) on quintiles of each variable.
        For controls (no arrival year), assign pseudo-arrival = modal
        arrival year of treated firms in the same item-code market.

Then re-run event study on matched sample.
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

OUT_REPORT = INTER / "contagion_matched_did.txt"
OUT_FIGURE = FIGS / "contagion_matched_event_study.pdf"

EVENT_WINDOW = (-3, 4)


def main() -> None:
    t0 = time.time()
    INTER.mkdir(parents=True, exist_ok=True)
    FIGS.mkdir(parents=True, exist_ok=True)

    con = duckdb.connect()
    con.sql("PRAGMA threads=12; PRAGMA memory_limit='14GB'")
    con.sql("PRAGMA temp_directory='/tmp/duckdb_spill'")

    rais_glob = str(RAIS_DIR / "rais_vinculos_*.parquet")

    # ── Step 1: Reproduce treatment assignment ───────────────────────────────

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
        SELECT DISTINCT pis, cnpj_raiz, ano AS year, LEFT(cbo2002,1) AS cbo
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
        SELECT w2.cnpj_raiz AS firm, MIN(w2.year) AS arrival_year,
               count(DISTINCT cw.pis) AS n_absorbed
        FROM cartel_workers cw
        JOIN worker_year w2 ON cw.pis=w2.pis
        WHERE w2.cnpj_raiz!=cw.ccnpj AND w2.year>cw.end_yr
          AND w2.cnpj_raiz NOT IN (SELECT cnpj_raiz FROM cartel_firms WHERE setor=cw.setor)
        GROUP BY w2.cnpj_raiz
    """)

    # ── Step 2: Pre-period characteristics for ALL firms ─────────────────────

    print("Step 2: Computing pre-period characteristics...", flush=True)

    # Cartel item codes
    con.sql(f"""
        CREATE TABLE cartel_items AS
        SELECT DISTINCT "códigoitem"
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8] IN
              (SELECT cnpj_raiz FROM cartel_firms)
    """)

    # All bids on cartel items (excl cartel firms)
    con.sql(f"""
        CREATE TABLE all_bids AS
        SELECT LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8] AS firm,
               "códigoitem" AS item, year, flagvencedor AS won
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE "códigoitem" IN (SELECT "códigoitem" FROM cartel_items)
          AND LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8]
              NOT IN (SELECT cnpj_raiz FROM cartel_firms)
    """)

    # For treated firms: use [arrival_year-2, arrival_year-1]
    # For controls: assign pseudo_arrival = 2014 (modal arrival year)
    PSEUDO_ARRIVAL = 2014

    con.sql(f"""
        CREATE TABLE firm_chars AS
        SELECT
            b.firm,
            COALESCE(t.arrival_year, {PSEUDO_ARRIVAL}) AS ref_year,
            CASE WHEN t.firm IS NOT NULL THEN 1 ELSE 0 END AS treated,
            count(*) AS pre_n_bids,
            count(DISTINCT b.item) AS pre_n_items,
            avg(b.won) AS pre_win_rate,
            count(DISTINCT b.year) AS pre_n_years
        FROM all_bids b
        LEFT JOIN treatment t ON b.firm = t.firm
        WHERE b.year BETWEEN COALESCE(t.arrival_year, {PSEUDO_ARRIVAL}) - 2
                          AND COALESCE(t.arrival_year, {PSEUDO_ARRIVAL}) - 1
        GROUP BY b.firm, t.arrival_year, t.firm
        HAVING count(*) >= 3  -- minimum bids in pre-period
    """)

    # Add RAIS firm size in pre-period
    con.sql(f"""
        CREATE TABLE firm_size_pre AS
        SELECT cnpj_raiz AS firm,
               avg(n_workers) AS pre_n_workers
        FROM (
            SELECT cnpj_raiz, year, count(DISTINCT pis) AS n_workers
            FROM worker_year
            GROUP BY cnpj_raiz, year
        )
        WHERE year BETWEEN {PSEUDO_ARRIVAL} - 2 AND {PSEUDO_ARRIVAL} - 1
        GROUP BY cnpj_raiz
    """)

    con.sql("""
        CREATE TABLE chars AS
        SELECT fc.*, COALESCE(fs.pre_n_workers, 0) AS pre_n_workers
        FROM firm_chars fc
        LEFT JOIN firm_size_pre fs ON fc.firm = fs.firm
    """)

    n_t = con.sql("SELECT count(*) FROM chars WHERE treated=1").fetchone()[0]
    n_c = con.sql("SELECT count(*) FROM chars WHERE treated=0").fetchone()[0]
    print(f"  firms with pre-period chars: treated={n_t:,}, control={n_c:,}")

    # ── Step 3: CEM matching on quintiles ────────────────────────────────────

    print("Step 3: CEM matching...", flush=True)

    chars_df = con.sql("SELECT * FROM chars").fetchdf()

    # Create quintile bins for matching variables
    for var in ["pre_n_bids", "pre_n_items", "pre_win_rate", "pre_n_workers"]:
        chars_df[f"{var}_q"] = pd.qcut(
            chars_df[var], q=5, labels=False, duplicates="drop"
        )

    # CEM: match on all quintile bins
    cem_cols = [f"{v}_q" for v in ["pre_n_bids", "pre_n_items", "pre_win_rate", "pre_n_workers"]]
    chars_df["cem_cell"] = chars_df[cem_cols].astype(str).agg("_".join, axis=1)

    # Keep only cells with both treated and control
    cell_counts = chars_df.groupby("cem_cell")["treated"].agg(["sum", "count"])
    cell_counts["n_control"] = cell_counts["count"] - cell_counts["sum"]
    valid_cells = cell_counts[(cell_counts["sum"] > 0) & (cell_counts["n_control"] > 0)].index

    matched = chars_df[chars_df["cem_cell"].isin(valid_cells)].copy()
    n_t_m = matched["treated"].sum()
    n_c_m = len(matched) - n_t_m
    n_cells = len(valid_cells)
    print(f"  matched: treated={int(n_t_m):,}, control={int(n_c_m):,}, cells={n_cells}")

    # CEM weights: within each cell, weight controls by n_treated/n_control
    cell_weights = matched.groupby("cem_cell")["treated"].agg(
        n_t_cell="sum", n_total="count"
    ).reset_index()
    cell_weights["n_c_cell"] = cell_weights["n_total"] - cell_weights["n_t_cell"]
    cell_weights["w_control"] = cell_weights["n_t_cell"] / cell_weights["n_c_cell"]
    matched = matched.merge(cell_weights[["cem_cell", "w_control"]], on="cem_cell")
    matched["weight"] = np.where(matched["treated"] == 1, 1.0,
                                  matched["w_control"])

    # Balance check
    print("\n  Balance check (pre-period means):")
    for var in ["pre_n_bids", "pre_n_items", "pre_win_rate", "pre_n_workers"]:
        t_mean = matched.loc[matched["treated"] == 1, var].mean()
        c_mean = (matched.loc[matched["treated"] == 0, var] *
                  matched.loc[matched["treated"] == 0, "weight"]).sum() / \
                 matched.loc[matched["treated"] == 0, "weight"].sum()
        print(f"    {var:20s}  treated={t_mean:.2f}  control={c_mean:.2f}")

    # ── Step 4: Build matched panel and re-run event study ───────────────────

    print("\nStep 4: Building matched panel...", flush=True)

    matched_firms = set(matched["firm"].values)
    matched_treated = set(matched.loc[matched["treated"] == 1, "firm"].values)

    # Reload all_bids for matched firms
    all_bids_df = con.sql("SELECT * FROM all_bids").fetchdf()
    panel = all_bids_df[all_bids_df["firm"].isin(matched_firms)].copy()

    # Aggregate to firm × item × year
    panel = panel.groupby(["firm", "item", "year"]).agg(
        n_bids=("won", "count"),
        n_wins=("won", "sum"),
    ).reset_index()
    panel["win_rate"] = panel["n_wins"] / panel["n_bids"]

    # Add treatment info
    treatment_df = con.sql("SELECT firm, arrival_year FROM treatment").fetchdf()
    treatment_map = dict(zip(treatment_df["firm"], treatment_df["arrival_year"]))

    panel["treated"] = panel["firm"].isin(matched_treated).astype(int)
    panel["arrival_year"] = panel["firm"].map(treatment_map)
    panel["event_time"] = np.where(
        panel["treated"] == 1,
        panel["year"] - panel["arrival_year"],
        np.nan
    )

    # Add CEM weights
    weight_map = dict(zip(matched["firm"], matched["weight"]))
    panel["weight"] = panel["firm"].map(weight_map).fillna(1.0)

    print(f"  matched panel: {len(panel):,} obs, "
          f"treated={panel['treated'].sum():,}")

    # ── Step 5: Weighted TWFE event study ────────────────────────────────────

    print("Step 5: Estimating weighted event study...", flush=True)

    min_tau, max_tau = EVENT_WINDOW
    panel["tau"] = panel["event_time"].clip(lower=min_tau, upper=max_tau)
    tau_values = sorted([t for t in range(min_tau, max_tau + 1) if t != -1])

    for tau in tau_values:
        panel[f"tau_{tau}"] = ((panel["treated"] == 1) &
                                (panel["tau"] == tau)).astype(float)

    # FE indices
    panel["firm_id"] = panel["firm"].astype("category").cat.codes
    panel["item_year"] = panel["item"].astype(str) + "_" + panel["year"].astype(str)
    panel["iy_id"] = panel["item_year"].astype("category").cat.codes

    y = panel["win_rate"].values.astype(float)
    w = panel["weight"].values.astype(float)
    w_sqrt = np.sqrt(w)

    # Weighted demeaning
    # Weighted mean by group: Σ(w·y) / Σ(w)
    panel["wy"] = y * w
    firm_wmean = (panel.groupby("firm_id")["wy"].transform("sum") /
                  panel.groupby("firm_id")["weight"].transform("sum")).values
    iy_wmean = (panel.groupby("iy_id")["wy"].transform("sum") /
                panel.groupby("iy_id")["weight"].transform("sum")).values
    grand_wmean = (w * y).sum() / w.sum()
    y_dm = w_sqrt * (y - firm_wmean - iy_wmean + grand_wmean)

    X_cols = [f"tau_{t}" for t in tau_values]
    X = panel[X_cols].values.astype(float)
    X_dm = np.zeros_like(X)
    for j, col in enumerate(X_cols):
        panel[f"w{col}"] = X[:, j] * w
        fm = (panel.groupby("firm_id")[f"w{col}"].transform("sum") /
              panel.groupby("firm_id")["weight"].transform("sum")).values
        ym = (panel.groupby("iy_id")[f"w{col}"].transform("sum") /
              panel.groupby("iy_id")["weight"].transform("sum")).values
        gm = (w * X[:, j]).sum() / w.sum()
        X_dm[:, j] = w_sqrt * (X[:, j] - fm - ym + gm)

    from numpy.linalg import lstsq
    beta, _, _, _ = lstsq(X_dm, y_dm, rcond=None)
    e = y_dm - X_dm @ beta
    n_obs, k = len(y_dm), len(beta)

    # Cluster SEs at firm level
    firms = panel["firm_id"].values
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

    control_mean = panel.loc[panel["treated"] == 0, "win_rate"].mean()

    # ── Step 6: Write report ─────────────────────────────────────────────────

    with open(OUT_REPORT, "w") as f:
        f.write("Contagion DiD — CEM Matched Sample\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")

        f.write("MATCHING\n")
        f.write("-" * 50 + "\n")
        f.write(f"Method: CEM on quintiles of pre_n_bids, pre_n_items,\n")
        f.write(f"        pre_win_rate, pre_n_workers\n")
        f.write(f"Pre-period: [arrival_year-2, arrival_year-1]\n")
        f.write(f"Pseudo-arrival for controls: {PSEUDO_ARRIVAL}\n")
        f.write(f"Matched treated: {int(n_t_m):,}\n")
        f.write(f"Matched controls: {int(n_c_m):,}\n")
        f.write(f"CEM cells: {n_cells}\n\n")

        f.write("MATCHED EVENT STUDY (weighted TWFE)\n")
        f.write("-" * 60 + "\n")
        f.write(f"N obs: {n_obs:,}  N firms: {n_clusters:,}\n")
        f.write(f"Control mean win rate: {control_mean:.4f}\n\n")

        f.write(f"{'τ':>4s}  {'β':>8s}  {'SE':>8s}  {'t':>7s}  "
                f"{'95% CI':>20s}\n")
        f.write("-" * 55 + "\n")
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

        f.write("COMPARISON: UNMATCHED vs MATCHED\n")
        f.write("-" * 50 + "\n")
        f.write("  Unmatched (script 36):\n")
        f.write("    Pre-trend max |t|: 2.04 ← PROBLEM\n")
        f.write("    Post mean β: +0.0411 (+9.4%)\n\n")
        f.write(f"  CEM Matched (this script):\n")
        f.write(f"    Pre-trend max |t|: {pre_max_t:.2f}\n")
        f.write(f"    Post mean β: {post_mean:+.4f} "
                f"({post_mean/control_mean*100:+.1f}%)\n")

        if pre_max_t < 1.65:
            f.write("\n  ✓ Pre-trend RESOLVED by matching.\n")
        elif pre_max_t < 1.96:
            f.write("\n  △ Pre-trend reduced but marginal.\n")
        else:
            f.write("\n  ✗ Pre-trend persists after matching.\n")

    print(f"\n[written] {OUT_REPORT}")

    # ── Figure ───────────────────────────────────────────────────────────────

    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        fig, ax = plt.subplots(figsize=(9, 5.5))
        taus = results["tau"].values
        betas = results["beta"].values

        ax.fill_between(taus, results["ci_lo"], results["ci_hi"],
                         alpha=0.15, color="#2166ac")
        ax.plot(taus, betas, "o-", color="#2166ac", linewidth=2, markersize=6,
                label="CEM matched")

        # Overlay unmatched from script 36 (hardcoded for comparison)
        unmatched_betas = {-3: 0.0323, -2: 0.0266, -1: 0, 0: 0.0275,
                           1: 0.0363, 2: 0.0355, 3: 0.0473, 4: 0.0586}
        ut = sorted(unmatched_betas.keys())
        ax.plot(ut, [unmatched_betas[t] for t in ut], "s--", color="#b2182b",
                linewidth=1.5, markersize=5, alpha=0.6, label="Unmatched")

        ax.axhline(0, color="grey", linewidth=0.8)
        ax.axvline(-0.5, color="red", linestyle="--", linewidth=1, alpha=0.4)
        ax.set_xlabel(r"$\tau$ (years since first ex-cartel worker arrival)")
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

    con.close()
    print(f"\nTotal time: {time.time() - t0:.1f}s")
    print("\n--- report ---")
    print(OUT_REPORT.read_text())


if __name__ == "__main__":
    main()
