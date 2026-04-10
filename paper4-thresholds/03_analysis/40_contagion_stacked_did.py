#!/usr/bin/env python3
"""
40_contagion_stacked_did.py — Stacked DiD (Cengiz et al. 2019) for contagion

Addresses staggered-treatment bias in TWFE. For each cohort (arrival_year),
build a separate clean 2×2 DiD using only not-yet-treated controls, then
stack and estimate pooled event-study coefficients.

Cohorts: arrival_year ∈ {2012, 2013, 2014, 2015} (need ≥2 pre + ≥2 post years)
For cohort g:
  - Treated: firms with arrival_year = g
  - Clean control: firms NEVER treated (never absorbed ex-cartel workers)
  - Window: [g-3, g+4]

Outcomes: win_rate + log(price ratio)
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

OUT_REPORT = INTER / "contagion_stacked_did.txt"
OUT_FIGURE = FIGS / "contagion_stacked_did.pdf"

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

    # ── Step 1: Treatment assignment ─────────────────────────────────────────

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

    # Never-treated firms (bid on cartel items but never absorbed)
    con.sql(f"""
        CREATE TABLE cartel_items AS
        SELECT DISTINCT "códigoitem" FROM read_parquet('{PAIRS_PREGAO}')
        WHERE LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8]
              IN (SELECT cnpj_raiz FROM cartel_firms)
    """)
    con.sql(f"""
        CREATE TABLE never_treated AS
        SELECT DISTINCT LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8] AS firm
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE "códigoitem" IN (SELECT "códigoitem" FROM cartel_items)
          AND LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8]
              NOT IN (SELECT firm FROM treatment)
          AND LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8]
              NOT IN (SELECT cnpj_raiz FROM cartel_firms)
    """)

    n_never = con.sql("SELECT count(*) FROM never_treated").fetchone()[0]
    print(f"  never-treated control firms: {n_never:,}")

    # ── Step 2: Bid-level panel ──────────────────────────────────────────────

    print("Step 2: Building bid panel...", flush=True)

    con.sql(f"""
        CREATE TABLE all_bids AS
        SELECT
            LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8] AS firm,
            "códigoitem" AS item, year,
            flagvencedor AS won,
            CASE WHEN "valorunitárioreferência" > 0 AND "valorunitárioproposta" > 0
                THEN LN("valorunitárioproposta" / "valorunitárioreferência")
                ELSE NULL END AS log_pr
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE "códigoitem" IN (SELECT "códigoitem" FROM cartel_items)
          AND LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8]
              NOT IN (SELECT cnpj_raiz FROM cartel_firms)
    """)

    # Aggregate
    bids_agg = con.sql("""
        SELECT firm, item, year,
               count(*) AS n_bids, avg(won) AS win_rate, avg(log_pr) AS log_pr
        FROM all_bids GROUP BY firm, item, year
    """).fetchdf()

    treatment_df = con.sql("SELECT firm, arrival_year FROM treatment").fetchdf()
    treatment_map = dict(treatment_df.values)
    never_set = set(con.sql("SELECT firm FROM never_treated").fetchdf()["firm"])

    con.close()

    # ── Step 3: Stack cohorts ────────────────────────────────────────────────

    print("Step 3: Stacking cohorts...", flush=True)

    min_tau, max_tau = EVENT_WINDOW
    stacked_parts = []

    for g in COHORTS:
        # Treated in this cohort
        treated_g = set(treatment_df[treatment_df["arrival_year"] == g]["firm"])
        if len(treated_g) < 5:
            print(f"  cohort {g}: only {len(treated_g)} treated, skipping")
            continue

        # Clean controls: never treated
        # Window: [g + min_tau, g + max_tau]
        yr_lo, yr_hi = g + min_tau, g + max_tau

        # Filter bids to this window
        sub = bids_agg[
            (bids_agg["year"].between(yr_lo, yr_hi)) &
            (bids_agg["firm"].isin(treated_g | never_set))
        ].copy()

        sub["cohort"] = g
        sub["treated"] = sub["firm"].isin(treated_g).astype(int)
        sub["event_time"] = sub["year"] - g
        sub["tau"] = sub["event_time"].clip(lower=min_tau, upper=max_tau)
        # Unique firm ID per cohort (to avoid cross-cohort FE contamination)
        sub["firm_cohort"] = sub["firm"] + f"_c{g}"
        sub["item_year_cohort"] = sub["item"].astype(str) + "_" + \
            sub["year"].astype(str) + f"_c{g}"

        stacked_parts.append(sub)
        n_t = sub[sub["treated"] == 1]["firm"].nunique()
        n_c = sub[sub["treated"] == 0]["firm"].nunique()
        print(f"  cohort {g}: treated={n_t}, control={n_c}, obs={len(sub):,}")

    if not stacked_parts:
        print("  ⚠️ No viable cohorts!")
        return

    stacked = pd.concat(stacked_parts, ignore_index=True)
    print(f"  stacked total: {len(stacked):,} obs")

    # ── Step 4: Event study on stacked data ──────────────────────────────────

    print("Step 4: Estimating stacked event study...", flush=True)

    tau_values = sorted([t for t in range(min_tau, max_tau + 1) if t != -1])

    for tau in tau_values:
        stacked[f"tau_{tau}"] = ((stacked["treated"] == 1) &
                                  (stacked["tau"] == tau)).astype(float)

    results_dict = {}

    for outcome, label in [("win_rate", "Win rate"), ("log_pr", "log(price ratio)")]:
        df = stacked.dropna(subset=[outcome]).copy()
        if len(df) < 100:
            continue

        y = df[outcome].values.astype(float)
        df["fc_id"] = df["firm_cohort"].astype("category").cat.codes
        df["iyc_id"] = df["item_year_cohort"].astype("category").cat.codes

        # Demean by firm_cohort and item_year_cohort
        fm = df.groupby("fc_id")[outcome].transform("mean").values
        ym = df.groupby("iyc_id")[outcome].transform("mean").values
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

        # Cluster at firm_cohort level
        firms = df["fc_id"].values
        unique_firms = np.unique(firms)
        nc = len(unique_firms)
        XtX_inv = np.linalg.inv(X_dm.T @ X_dm)
        meat = np.zeros((k, k))
        for g in unique_firms:
            mask = firms == g
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
        results_dict[outcome] = (res, n_obs, nc)

    # ── Step 5: Report ───────────────────────────────────────────────────────

    # Hardcoded TWFE matched results for comparison
    twfe_wr = {-3: -0.0115, -2: 0.0175, -1: 0, 0: 0.0179, 1: 0.0479,
               2: 0.0134, 3: 0.0472, 4: 0.0309}
    twfe_pr = {-3: 0.1109, -2: 0.1059, -1: 0, 0: 0.1119, 1: 0.1915,
               2: 0.3632, 3: 0.2705, 4: 0.3719}

    with open(OUT_REPORT, "w") as f:
        f.write("Contagion: Stacked DiD (Cengiz et al. 2019)\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")

        f.write(f"Cohorts: {COHORTS}\n")
        f.write(f"Control: never-treated firms ({n_never:,})\n")
        f.write(f"Stacked obs: {len(stacked):,}\n\n")

        for outcome, label in [("win_rate", "WIN RATE"), ("log_pr", "LOG PRICE RATIO")]:
            if outcome not in results_dict:
                continue
            res, n_o, n_c = results_dict[outcome]
            twfe = twfe_wr if outcome == "win_rate" else twfe_pr

            f.write(f"{label}\n")
            f.write("-" * 60 + "\n")
            f.write(f"N obs: {n_o:,}  N clusters: {n_c:,}\n\n")
            f.write(f"{'τ':>4s}  {'β(stacked)':>10s}  {'SE':>7s}  {'t':>6s}  "
                    f"{'β(TWFE)':>8s}\n")
            f.write("-" * 45 + "\n")
            for _, row in res.iterrows():
                tau = int(row["tau"])
                tw = twfe.get(tau, np.nan)
                sig = "***" if abs(row["t_stat"]) > 2.576 else \
                      "**" if abs(row["t_stat"]) > 1.96 else \
                      "*" if abs(row["t_stat"]) > 1.645 else ""
                f.write(f"{tau:>4d}  {row['beta']:>10.4f}  {row['se']:>7.4f}  "
                        f"{row['t_stat']:>6.2f}  {tw:>8.4f} {sig}\n")

            pre_max = res[res["tau"].between(min_tau, -2)]["t_stat"].abs().max()
            post_mean = res[res["tau"] >= 0]["beta"].mean()
            twfe_post = np.mean([v for k, v in twfe.items() if k >= 0])
            f.write(f"\n  Pre-trend max |t|: {pre_max:.2f}\n")
            f.write(f"  Post mean β (stacked): {post_mean:+.4f}\n")
            f.write(f"  Post mean β (TWFE):    {twfe_post:+.4f}\n")
            if abs(post_mean) > 0 and abs(twfe_post) > 0:
                f.write(f"  Ratio stacked/TWFE:    {post_mean/twfe_post:.2f}\n")
            f.write("\n")

    print(f"\n[written] {OUT_REPORT}")

    # ── Figure ───────────────────────────────────────────────────────────────

    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        fig, axes = plt.subplots(1, 2, figsize=(13, 5))

        for idx, (outcome, label, twfe) in enumerate([
            ("win_rate", "A. Win rate", twfe_wr),
            ("log_pr", "B. log(price ratio)", twfe_pr),
        ]):
            ax = axes[idx]
            if outcome in results_dict:
                res, _, _ = results_dict[outcome]
                ax.fill_between(res["tau"], res["ci_lo"], res["ci_hi"],
                                alpha=0.12, color="#2166ac")
                ax.plot(res["tau"], res["beta"], "o-", color="#2166ac",
                        linewidth=2, markersize=5, label="Stacked DiD")

            ct = sorted(twfe.keys())
            ax.plot(ct, [twfe[t] for t in ct], "s--", color="#b2182b",
                    linewidth=1.5, markersize=4, alpha=0.6, label="TWFE (matched)")

            ax.axhline(0, color="grey", linewidth=0.8)
            ax.axvline(-0.5, color="black", linestyle="--", linewidth=0.8, alpha=0.4)
            ax.set_xlabel(r"$\tau$")
            ax.set_title(label)
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
