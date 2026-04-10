#!/usr/bin/env python3
"""
38_contagion_price_outcome.py — Price outcome for contagion DiD

Tests whether firms that absorb ex-cartel workers change their pricing:
  - If prices RISE (discount shrinks) → collusion contagion
  - If prices FALL (discount grows) → competitive capacity gain

Outcome: log(bid_price / ref_price) — the relative bid price.
         Lower = more competitive. Higher = closer to reference price.

Uses the same CEM-matched sample as script 37.
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
BID_LEVEL    = str(Path("/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers"
                        "/v3/data/processed/bid_level_with_prices.parquet"))

OUT_REPORT = INTER / "contagion_price_outcome.txt"
OUT_FIGURE = FIGS / "contagion_price_event_study.pdf"

EVENT_WINDOW = (-3, 4)
PSEUDO_ARRIVAL = 2014


def main() -> None:
    t0 = time.time()
    INTER.mkdir(parents=True, exist_ok=True)
    FIGS.mkdir(parents=True, exist_ok=True)

    con = duckdb.connect()
    con.sql("PRAGMA threads=12; PRAGMA memory_limit='14GB'")
    con.sql("PRAGMA temp_directory='/tmp/duckdb_spill'")

    rais_glob = str(RAIS_DIR / "rais_vinculos_*.parquet")

    # ── Step 1: Reproduce treatment + matching from scripts 36-37 ────────────

    print("Step 1: Building treatment + matching...", flush=True)

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

    # Cartel item codes
    con.sql(f"""
        CREATE TABLE cartel_items AS
        SELECT DISTINCT "códigoitem" FROM read_parquet('{PAIRS_PREGAO}')
        WHERE LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8]
              IN (SELECT cnpj_raiz FROM cartel_firms)
    """)

    # ── Step 2: Build price panel from bid-level data ────────────────────────

    print("Step 2: Building price panel...", flush=True)

    # Use pair file which has year + price columns
    con.sql(f"""
        CREATE TABLE bids_price AS
        SELECT
            LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8] AS firm,
            "códigoitem" AS item,
            year,
            "valorunitárioproposta" AS bid_price,
            "valorunitárioreferência" AS ref_price,
            CASE WHEN "valorunitárioreferência" > 0 AND "valorunitárioproposta" > 0
                THEN LN("valorunitárioproposta" / "valorunitárioreferência")
                ELSE NULL END AS log_price_ratio,
            CASE WHEN "valorunitárioreferência" > 0 AND "valorunitárioproposta" > 0
                THEN ("valorunitárioreferência" - "valorunitárioproposta")
                     / "valorunitárioreferência"
                ELSE NULL END AS discount
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE "códigoitem" IN (SELECT "códigoitem" FROM cartel_items)
          AND LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8]
              NOT IN (SELECT cnpj_raiz FROM cartel_firms)
          AND "valorunitárioproposta" > 0
    """)

    n_bids = con.sql("SELECT count(*) FROM bids_price WHERE log_price_ratio IS NOT NULL").fetchone()[0]
    print(f"  bids with valid price ratio: {n_bids:,}")

    # Aggregate to firm × item × year
    con.sql("""
        CREATE TABLE price_panel AS
        SELECT firm, item, year,
               count(*) AS n_bids,
               avg(log_price_ratio) AS mean_log_price_ratio,
               avg(discount) AS mean_discount
        FROM bids_price
        WHERE log_price_ratio IS NOT NULL
        GROUP BY firm, item, year
    """)

    # ── Step 3: CEM matching (reproduce from script 37 logic) ────────────────

    print("Step 3: CEM matching...", flush=True)

    # Pre-period chars for matching
    chars_df = con.sql(f"""
        SELECT p.firm,
               COALESCE(t.arrival_year, {PSEUDO_ARRIVAL}) AS ref_year,
               CASE WHEN t.firm IS NOT NULL THEN 1 ELSE 0 END AS treated,
               count(*) AS pre_n_bids,
               count(DISTINCT p.item) AS pre_n_items,
               avg(p.mean_discount) AS pre_discount
        FROM price_panel p
        LEFT JOIN treatment t ON p.firm = t.firm
        WHERE p.year BETWEEN COALESCE(t.arrival_year, {PSEUDO_ARRIVAL}) - 2
                          AND COALESCE(t.arrival_year, {PSEUDO_ARRIVAL}) - 1
        GROUP BY p.firm, t.arrival_year, t.firm
        HAVING count(*) >= 2
    """).fetchdf()

    # CEM on terciles (looser than quintiles to keep more matches with price data)
    for var in ["pre_n_bids", "pre_n_items", "pre_discount"]:
        chars_df[f"{var}_q"] = pd.qcut(
            chars_df[var], q=3, labels=False, duplicates="drop"
        )

    cem_cols = ["pre_n_bids_q", "pre_n_items_q", "pre_discount_q"]
    chars_df["cem_cell"] = (
        chars_df["pre_n_bids_q"].astype(str) + "_" +
        chars_df["pre_n_items_q"].astype(str) + "_" +
        chars_df["pre_discount_q"].astype(str)
    )

    cell_counts = chars_df.groupby("cem_cell")["treated"].agg(["sum", "count"])
    cell_counts["n_c"] = cell_counts["count"] - cell_counts["sum"]
    valid = cell_counts[(cell_counts["sum"] > 0) & (cell_counts["n_c"] > 0)].index

    matched = chars_df[chars_df["cem_cell"].isin(valid)].copy()
    n_t_m = int(matched["treated"].sum())
    n_c_m = len(matched) - n_t_m
    print(f"  matched: treated={n_t_m}, control={n_c_m}")

    # Weights
    cw = matched.groupby("cem_cell")["treated"].agg(nt="sum", ntot="count").reset_index()
    cw["nc"] = cw["ntot"] - cw["nt"]
    cw["w_c"] = cw["nt"] / cw["nc"]
    matched = matched.merge(cw[["cem_cell", "w_c"]], on="cem_cell")
    matched["weight"] = np.where(matched["treated"] == 1, 1.0, matched["w_c"])

    matched_firms = set(matched["firm"])
    matched_treated = set(matched.loc[matched["treated"] == 1, "firm"])

    # ── Step 4: Build matched price panel ────────────────────────────────────

    print("Step 4: Building matched panel...", flush=True)

    panel = con.sql("SELECT * FROM price_panel").fetchdf()
    panel = panel[panel["firm"].isin(matched_firms)].copy()

    treatment_map = dict(con.sql("SELECT firm, arrival_year FROM treatment").fetchdf().values)

    panel["treated"] = panel["firm"].isin(matched_treated).astype(int)
    panel["arrival_year"] = panel["firm"].map(treatment_map)
    panel["event_time"] = np.where(
        panel["treated"] == 1, panel["year"] - panel["arrival_year"], np.nan
    )
    weight_map = dict(zip(matched["firm"], matched["weight"]))
    panel["weight"] = panel["firm"].map(weight_map).fillna(1.0)

    # Drop NaN outcome
    panel = panel.dropna(subset=["mean_log_price_ratio"]).copy()
    print(f"  panel: {len(panel):,} obs")

    # ── Step 5: Weighted event study ─────────────────────────────────────────

    print("Step 5: Estimating price event study...", flush=True)

    min_tau, max_tau = EVENT_WINDOW
    panel["tau"] = panel["event_time"].clip(lower=min_tau, upper=max_tau)
    tau_values = sorted([t for t in range(min_tau, max_tau + 1) if t != -1])

    for tau in tau_values:
        panel[f"tau_{tau}"] = ((panel["treated"] == 1) &
                                (panel["tau"] == tau)).astype(float)

    panel["firm_id"] = panel["firm"].astype("category").cat.codes
    panel["item_year"] = panel["item"].astype(str) + "_" + panel["year"].astype(str)
    panel["iy_id"] = panel["item_year"].astype("category").cat.codes

    y = panel["mean_log_price_ratio"].values.astype(float)
    w = panel["weight"].values.astype(float)
    w_sqrt = np.sqrt(w)

    # Weighted demeaning
    panel["wy"] = y * w
    fm = (panel.groupby("firm_id")["wy"].transform("sum") /
          panel.groupby("firm_id")["weight"].transform("sum")).values
    ym = (panel.groupby("iy_id")["wy"].transform("sum") /
          panel.groupby("iy_id")["weight"].transform("sum")).values
    gm = (w * y).sum() / w.sum()
    y_dm = w_sqrt * (y - fm - ym + gm)

    X_cols = [f"tau_{t}" for t in tau_values]
    X = panel[X_cols].values.astype(float)
    X_dm = np.zeros_like(X)
    for j, col in enumerate(X_cols):
        panel[f"w{col}"] = X[:, j] * w
        f_m = (panel.groupby("firm_id")[f"w{col}"].transform("sum") /
               panel.groupby("firm_id")["weight"].transform("sum")).values
        i_m = (panel.groupby("iy_id")[f"w{col}"].transform("sum") /
               panel.groupby("iy_id")["weight"].transform("sum")).values
        g_m = (w * X[:, j]).sum() / w.sum()
        X_dm[:, j] = w_sqrt * (X[:, j] - f_m - i_m + g_m)

    from numpy.linalg import lstsq
    beta, _, _, _ = lstsq(X_dm, y_dm, rcond=None)
    e = y_dm - X_dm @ beta
    n_obs, k = len(y_dm), len(beta)

    firms_arr = panel["firm_id"].values
    unique_firms = np.unique(firms_arr)
    n_clusters = len(unique_firms)
    XtX_inv = np.linalg.inv(X_dm.T @ X_dm)
    meat = np.zeros((k, k))
    for g in unique_firms:
        mask = firms_arr == g
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

    control_mean_lr = panel.loc[panel["treated"] == 0, "mean_log_price_ratio"].mean()
    control_mean_disc = panel.loc[panel["treated"] == 0, "mean_discount"].mean()

    # ── Step 6: Write report ─────────────────────────────────────────────────

    pre_max_t = results[results["tau"].between(min_tau, -2)]["t_stat"].abs().max()
    post_mean = results[results["tau"] >= 0]["beta"].mean()

    with open(OUT_REPORT, "w") as f:
        f.write("Contagion: Price Outcome (CEM Matched)\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")

        f.write("OUTCOME: log(bid_price / ref_price)\n")
        f.write("  Interpretation:\n")
        f.write("    β > 0 → prices RISE (closer to reference) → CONTAGION\n")
        f.write("    β < 0 → prices FALL (more competitive) → CAPACITY GAIN\n\n")

        f.write(f"N obs: {n_obs:,}  N firms: {n_clusters:,}\n")
        f.write(f"Matched treated: {n_t_m}  Control: {n_c_m}\n")
        f.write(f"Control mean log(price ratio): {control_mean_lr:.4f}\n")
        f.write(f"Control mean discount: {control_mean_disc:.4f} "
                f"({control_mean_disc*100:.1f}%)\n\n")

        f.write("EVENT STUDY\n")
        f.write("-" * 60 + "\n")
        f.write(f"{'τ':>4s}  {'β':>8s}  {'SE':>8s}  {'t':>7s}  "
                f"{'95% CI':>20s}\n")
        f.write("-" * 60 + "\n")
        for _, row in results.iterrows():
            tau = int(row["tau"])
            sig = "***" if abs(row["t_stat"]) > 2.576 else \
                  "**" if abs(row["t_stat"]) > 1.96 else \
                  "*" if abs(row["t_stat"]) > 1.645 else ""
            f.write(f"{tau:>4d}  {row['beta']:>8.4f}  {row['se']:>8.4f}  "
                    f"{row['t_stat']:>7.2f}  "
                    f"[{row['ci_lo']:>8.4f}, {row['ci_hi']:>8.4f}] {sig}\n")

        f.write(f"\n  Pre-trend max |t|: {pre_max_t:.2f}\n")
        f.write(f"  Post-treatment mean β: {post_mean:+.4f}\n\n")

        f.write("INTERPRETATION\n")
        f.write("-" * 50 + "\n")
        if post_mean > 0.005:
            f.write("  → Prices RISE after absorbing ex-cartel workers.\n")
            f.write("  → Consistent with collusion contagion.\n")
        elif post_mean < -0.005:
            f.write("  → Prices FALL after absorbing ex-cartel workers.\n")
            f.write("  → Consistent with competitive capacity gain.\n")
        else:
            f.write("  → No detectable price effect.\n")
            f.write("  → Win-rate increase (script 37) without price change\n")
            f.write("    suggests capacity expansion (bidding on more items\n")
            f.write("    or winning more often) rather than price manipulation.\n")

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
        ax.plot(taus, betas, "o-", color="#2166ac", linewidth=2, markersize=6)
        ax.axhline(0, color="grey", linewidth=0.8)
        ax.axvline(-0.5, color="red", linestyle="--", linewidth=1, alpha=0.4)

        ax.set_xlabel(r"$\tau$ (years since first ex-cartel worker arrival)")
        ax.set_ylabel(r"log(bid price / reference price)")
        ax.set_title("Price effect of absorbing ex-cartel workers (CEM matched)")
        ax.set_xticks(taus)
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)

        # Annotate interpretation
        ax.annotate("← more competitive", xy=(0.02, 0.02), xycoords="axes fraction",
                    fontsize=8, color="green", alpha=0.6)
        ax.annotate("less competitive →", xy=(0.02, 0.95), xycoords="axes fraction",
                    fontsize=8, color="red", alpha=0.6)

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
