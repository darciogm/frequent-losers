#!/usr/bin/env python3
"""
47_bjs_imputation.py — Borusyak-Jaravel-Spiess (2024) imputation estimator
==========================================================================

Implements the imputation estimator proposed in strategy.tex §5.2 as a
third robustness check against staggered-treatment bias, alongside the
stacked DiD (script 42) and the Bartik IV (script 45).

Design

    1. Partition observations into "untreated" (U) and "treated" (T):
           U = { (i,j,t) : firm i never absorbs ex-cartel workers, OR
                          firm i's arrival_year > t }
           T = { (i,j,t) : firm i treated and t >= arrival_year }

    2. Fit the two-way fixed-effects model ON U ONLY:
           y_{ijt} = α_i + γ_{jt} + ε_{ijt}            (for (i,j,t) ∈ U)
       by iterative alternating projections (firm means, then item×year
       means, repeated until convergence).

    3. Impute the counterfactual for each treated observation:
           Y^0_{ijt} = α̂_i + γ̂_{jt}                     (for (i,j,t) ∈ T)
       Treated obs whose (j,t) cell has no untreated observations cannot
       be imputed (γ̂_{jt} is undefined) and are dropped.

    4. Compute observation-level treatment effects:
           τ_{ijt} = y_{ijt} - Y^0_{ijt}

    5. Aggregate to event-time coefficients:
           τ_k = mean(τ_{ijt} : t - arrival_year_i = k)
       for k ∈ {-K, ..., -1, 0, ..., +K}. (The pre-period τ_k are the
       BJS placebo — a nonzero pre-period τ_k indicates that the
       imputation model fails and the identifying assumption is suspect.)

    6. Firm-clustered bootstrap SE: resample firms with replacement
       (N_FIRMS draws), refit α̂ and γ̂ on the resampled untreated
       subsample, recompute τ_k on the resampled treated subsample.
       Standard error of τ_k = SD of bootstrap distribution.

This is the classical BJS imputation. For this paper, the key contrast
is with the stacked DiD in script 42: if BJS τ_k are aligned with
stacked coefficients, the staggered-treatment-bias correction is
inconsequential; if they diverge, one of the two estimators is carrying
residual bias.

Outputs
    02_data/intermediate/bjs_imputation.txt       — event-time table
    04_figures/bjs_imputation_event_study.pdf     — side-by-side with 42
"""
from __future__ import annotations
import os
import time
from pathlib import Path

import numpy as np
import pandas as pd
import duckdb

try:
    import psutil
    _proc = psutil.Process()
    def rss_gb() -> float:
        return _proc.memory_info().rss / (1024 ** 3)
except ImportError:
    def rss_gb() -> float:
        return float("nan")


# ── Paths ────────────────────────────────────────────────────────────────────

BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")
RAIS_DIR = BASE / "RAIS" / "parquet" / "harmonized"
FINAL = BASE / "02_data" / "final"
FIRMS = BASE / "02_data" / "firms"
INTER = BASE / "02_data" / "intermediate"
FIGS  = BASE / "04_figures"

BEC_FIRMS    = str(BASE / "02_data" / "bec_cnpj_list.parquet")
PAIRS_PREGAO = str(FINAL / "df_pregao_with_cartel_flags.parquet")
GROUND_TRUTH = str(FIRMS / "cade_ground_truth.parquet")

OUT_REPORT = INTER / "bjs_imputation.txt"
OUT_FIGURE = FIGS  / "bjs_imputation_event_study.pdf"

PANEL_YEARS = list(range(2009, 2018))
EVENT_WINDOW = (-4, 4)   # wider than 42 to see τ=-3, τ=-4 placebos
MAX_SWEEPS = 25          # demean iterations; early-stop at tol
CONV_TOL   = 1e-7
N_BOOT     = 200
BOOT_SEED  = 42


# ── Helpers ──────────────────────────────────────────────────────────────────

def log(msg: str, t0: float) -> None:
    print(f"[{time.time() - t0:6.1f}s | RSS {rss_gb():4.1f} GB] {msg}",
          flush=True)


def fit_two_way_fe(
    y: np.ndarray,
    fid: np.ndarray,
    iyid: np.ndarray,
    n_firms: int,
    n_iy: int,
    max_sweeps: int = MAX_SWEEPS,
    tol: float = CONV_TOL,
) -> tuple[np.ndarray, np.ndarray, int]:
    """Iterative demean on the untreated subsample, returning the
    converged firm fixed effects α[·] and item×year fixed effects γ[·].

    Returns (alpha, gamma, n_sweeps_used). Uses alternating projections
    with early stopping when ||α_new - α_old||_∞ < tol.
    """
    alpha = np.zeros(n_firms, dtype=float)
    gamma = np.zeros(n_iy, dtype=float)
    y_res = y.astype(float).copy()

    for sw in range(1, max_sweeps + 1):
        # Firm update
        df_f = pd.DataFrame({"y": y_res, "g": fid})
        mu_f = df_f.groupby("g")["y"].mean()
        mu_f_full = np.zeros(n_firms, dtype=float)
        mu_f_full[mu_f.index.values] = mu_f.values
        alpha_new = alpha + mu_f_full
        y_res = y_res - mu_f_full[fid]

        # Item × year update
        df_iy = pd.DataFrame({"y": y_res, "g": iyid})
        mu_iy = df_iy.groupby("g")["y"].mean()
        mu_iy_full = np.zeros(n_iy, dtype=float)
        mu_iy_full[mu_iy.index.values] = mu_iy.values
        gamma_new = gamma + mu_iy_full
        y_res = y_res - mu_iy_full[iyid]

        delta = max(np.abs(alpha_new - alpha).max(),
                    np.abs(gamma_new - gamma).max())
        alpha, gamma = alpha_new, gamma_new
        if delta < tol:
            return alpha, gamma, sw

    return alpha, gamma, max_sweeps


def bjs_tau_by_event_time(
    df_treated: pd.DataFrame,
    alpha: np.ndarray,
    gamma: np.ndarray,
    event_window: tuple[int, int],
) -> pd.Series:
    """Given fitted α, γ and the treated subframe with columns
    fid, iyid, win_rate, event_time — compute τ_k = mean(y - α - γ)
    within each event time k in event_window.

    Treated rows whose γ[iyid] is exactly zero (no untreated info in
    that (j,t) cell, identified by a zero-index sentinel — see caller)
    are dropped with a warning.
    """
    lo, hi = event_window
    out = {}
    df = df_treated.copy()
    df["alpha"] = alpha[df["fid"].values]
    df["gamma"] = gamma[df["iyid"].values]
    df["y0_hat"] = df["alpha"] + df["gamma"]
    df["tau"] = df["win_rate"] - df["y0_hat"]
    df = df[df["has_support"] == 1]
    for k in range(lo, hi + 1):
        sub = df[df["event_time"] == k]["tau"]
        out[k] = float(sub.mean()) if len(sub) > 0 else float("nan")
    return pd.Series(out, name="tau")


# ── Main ─────────────────────────────────────────────────────────────────────

def main() -> None:
    t0 = time.time()
    INTER.mkdir(parents=True, exist_ok=True)
    FIGS.mkdir(parents=True, exist_ok=True)

    log(f"hostname={os.uname().nodename}, threads=12, mem_limit=14GB", t0)
    log(f"event window: {EVENT_WINDOW}, max sweeps: {MAX_SWEEPS}, "
        f"bootstrap B: {N_BOOT}", t0)

    con = duckdb.connect()
    con.sql("PRAGMA threads=12; PRAGMA memory_limit='14GB'")
    con.sql("PRAGMA temp_directory='/tmp/duckdb_spill'")

    rais_glob = str(RAIS_DIR / "rais_vinculos_*.parquet")

    # ── 1. Cartels ───────────────────────────────────────────────────────────
    log("Step 1: cartels", t0)
    con.sql(f"""
        CREATE TABLE cf AS
        SELECT DISTINCT cnpj_raiz, setor,
               cartel_start_year::INT AS s,
               cartel_end_year::INT   AS e
        FROM read_parquet('{GROUND_TRUTH}')
        WHERE sp_relevant = 1
          AND processo IS NOT NULL
          AND cartel_start_year IS NOT NULL
          AND cartel_end_year <= 2016
    """)

    # ── 2. Treatment (firm → arrival_year) ──────────────────────────────────
    log("Step 2: treatment (firm → arrival_year)", t0)
    con.sql(f"""
        CREATE TABLE wy AS SELECT DISTINCT pis, cnpj_raiz, ano AS year
        FROM read_parquet('{rais_glob}')
        WHERE cnpj_raiz IN (SELECT cnpj_raiz FROM read_parquet('{BEC_FIRMS}'))
          AND pis IS NOT NULL AND cnpj_raiz IS NOT NULL
    """)
    con.sql("""
        CREATE TABLE cw AS SELECT DISTINCT w.pis, w.cnpj_raiz AS cc, cf.setor, cf.e
        FROM wy w JOIN cf ON w.cnpj_raiz = cf.cnpj_raiz
        WHERE w.year BETWEEN cf.s AND cf.e
    """)
    con.sql("""
        CREATE TABLE treatment AS
        SELECT w2.cnpj_raiz AS firm, MIN(w2.year) AS arrival_year
        FROM cw JOIN wy w2 ON cw.pis = w2.pis
        WHERE w2.cnpj_raiz != cw.cc
          AND w2.year > cw.e
          AND w2.cnpj_raiz NOT IN (SELECT cnpj_raiz FROM cf WHERE setor = cw.setor)
        GROUP BY w2.cnpj_raiz
    """)
    n_treated = con.sql("SELECT COUNT(*) FROM treatment").fetchone()[0]
    log(f"  treated firms: {n_treated:,}", t0)

    # ── 3. Outcome panel ────────────────────────────────────────────────────
    log("Step 3: outcome panel", t0)
    years_str = ",".join(f"({y})" for y in PANEL_YEARS)
    con.sql(f"""
        CREATE TABLE years_t AS SELECT * FROM (VALUES {years_str}) AS t(year)
    """)
    con.sql(f"""
        CREATE TABLE ci AS SELECT DISTINCT "códigoitem"
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8]
              IN (SELECT cnpj_raiz FROM cf)
    """)
    con.sql(f"""
        CREATE TABLE outcome AS
        SELECT LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8] AS firm,
               "códigoitem"      AS item,
               year,
               AVG(flagvencedor) AS win_rate
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE "códigoitem" IN (SELECT "códigoitem" FROM ci)
          AND LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8]
              NOT IN (SELECT cnpj_raiz FROM cf)
          AND year IN (SELECT year FROM years_t)
        GROUP BY firm, item, year
    """)

    # ── 4. Merge treatment into panel ───────────────────────────────────────
    log("Step 4: merging", t0)
    panel = con.sql("""
        SELECT o.firm, o.item, o.year, o.win_rate,
               t.arrival_year,
               CASE WHEN t.arrival_year IS NULL THEN 1
                    WHEN o.year < t.arrival_year THEN 1
                    ELSE 0 END AS is_untreated
        FROM outcome o
        LEFT JOIN treatment t ON t.firm = o.firm
        WHERE o.win_rate IS NOT NULL
    """).fetchdf()
    con.close()

    panel["event_time"] = panel.apply(
        lambda r: int(r["year"] - r["arrival_year"])
                  if pd.notna(r["arrival_year"]) else np.nan,
        axis=1,
    )
    n_obs  = len(panel)
    n_u    = int((panel["is_untreated"] == 1).sum())
    n_t    = int((panel["is_untreated"] == 0).sum())
    log(f"  panel rows: {n_obs:,}  untreated: {n_u:,}  treated: {n_t:,}", t0)
    log(f"  unique firms: {panel['firm'].nunique():,}  "
        f"items: {panel['item'].nunique():,}  "
        f"years: {panel['year'].nunique()}", t0)

    # ── 5. Encode IDs ───────────────────────────────────────────────────────
    log("Step 5: encoding firm and item×year IDs", t0)
    panel["fid"] = panel["firm"].astype("category").cat.codes
    panel["iyid"] = (panel["item"].astype(str) + "_" + panel["year"].astype(str)) \
                    .astype("category").cat.codes
    n_firms = panel["fid"].max() + 1
    n_iy    = panel["iyid"].max() + 1
    log(f"  n_firms={n_firms:,}  n_iy={n_iy:,}", t0)

    # Identify which item×year cells have any untreated support. A treated
    # observation falling in a cell with zero untreated support cannot be
    # imputed (γ̂_{jt} undefined). Flag with has_support.
    support = (panel.loc[panel["is_untreated"] == 1]
                    .groupby("iyid").size().rename("n_u_cell"))
    panel = panel.merge(support, left_on="iyid", right_index=True, how="left")
    panel["n_u_cell"] = panel["n_u_cell"].fillna(0).astype(int)
    panel["has_support"] = (panel["n_u_cell"] > 0).astype(int)

    n_t_supported = int(((panel["is_untreated"] == 0) &
                         (panel["has_support"] == 1)).sum())
    n_t_dropped = n_t - n_t_supported
    log(f"  treated with support: {n_t_supported:,}  "
        f"dropped (no support): {n_t_dropped:,}", t0)
    if n_t_dropped / max(n_t, 1) > 0.20:
        log("  ⚠ >20% of treated obs lack support — BJS may be underpowered", t0)

    # ── 6. Point estimate ───────────────────────────────────────────────────
    log("Step 6: fitting two-way FE on untreated subsample", t0)
    u = panel[panel["is_untreated"] == 1]
    y_u = u["win_rate"].values.astype(float)
    fid_u = u["fid"].values.astype(np.int64)
    iyid_u = u["iyid"].values.astype(np.int64)
    alpha, gamma, sweeps_used = fit_two_way_fe(
        y_u, fid_u, iyid_u, int(n_firms), int(n_iy)
    )
    log(f"  converged in {sweeps_used} sweeps", t0)

    # Center: the α, γ decomposition is identified up to a constant.
    # Add back the untreated grand mean so imputations are on the scale of y.
    y_bar = float(y_u.mean())
    alpha = alpha - alpha.mean()
    gamma = gamma - gamma.mean() + y_bar

    tau_point = bjs_tau_by_event_time(
        panel[panel["is_untreated"] == 0],
        alpha, gamma, EVENT_WINDOW,
    )
    log("  τ_k (point estimate):", t0)
    for k, v in tau_point.items():
        log(f"    τ={k:+d}  {v:+.4f}", t0)

    # ── 7. Firm-clustered bootstrap ─────────────────────────────────────────
    log(f"Step 7: bootstrap SE (B={N_BOOT}, firm-clustered)", t0)
    rng = np.random.default_rng(BOOT_SEED)
    unique_firms = panel["fid"].unique()
    n_unique = len(unique_firms)

    # Pre-split panel rows by firm for fast resampling.
    by_firm = panel.groupby("fid").indices  # dict fid → row indices

    lo, hi = EVENT_WINDOW
    boot_taus = np.full((N_BOOT, hi - lo + 1), np.nan)

    for b in range(N_BOOT):
        draw = rng.choice(unique_firms, size=n_unique, replace=True)
        # Build resampled row index list
        row_idx_parts = [by_firm[f] for f in draw]
        row_idx = np.concatenate(row_idx_parts)
        sub = panel.iloc[row_idx].copy()

        # Re-encode fid within the bootstrap draw (clusters duplicate)
        # Pragmatic choice: keep original iyid (so γ̂ is comparable)
        # and re-label fid so α̂ is per bootstrap-unit.
        sub["fid_b"] = np.repeat(np.arange(len(draw)),
                                 [len(by_firm[f]) for f in draw])
        n_firms_b = int(sub["fid_b"].max() + 1)

        u_b = sub[sub["is_untreated"] == 1]
        if len(u_b) < 100 or u_b["iyid"].nunique() < 10:
            continue

        alpha_b, gamma_b, _ = fit_two_way_fe(
            u_b["win_rate"].values.astype(float),
            u_b["fid_b"].values.astype(np.int64),
            u_b["iyid"].values.astype(np.int64),
            n_firms_b, int(n_iy),
            max_sweeps=12, tol=1e-5,
        )
        # Recenter as in point estimate
        y_bar_b = float(u_b["win_rate"].mean())
        alpha_b = alpha_b - alpha_b.mean()
        gamma_b = gamma_b - gamma_b.mean() + y_bar_b

        # τ on resampled treated obs
        t_b = sub[sub["is_untreated"] == 0].copy()
        if len(t_b) == 0:
            continue
        t_b["alpha"] = alpha_b[t_b["fid_b"].values]
        t_b["gamma"] = gamma_b[t_b["iyid"].values]
        t_b["y0_hat"] = t_b["alpha"] + t_b["gamma"]
        t_b["tau"] = t_b["win_rate"] - t_b["y0_hat"]
        t_b = t_b[t_b["has_support"] == 1]

        for k_idx, k in enumerate(range(lo, hi + 1)):
            v = t_b.loc[t_b["event_time"] == k, "tau"]
            if len(v) > 0:
                boot_taus[b, k_idx] = v.mean()

        if (b + 1) % 20 == 0:
            log(f"  bootstrap {b + 1}/{N_BOOT}", t0)

    boot_se = np.nanstd(boot_taus, axis=0, ddof=1)
    log(f"  bootstrap SE: {boot_se}", t0)

    # Assemble output table
    ks = list(range(lo, hi + 1))
    table = pd.DataFrame({
        "tau": ks,
        "beta": [tau_point.get(k, np.nan) for k in ks],
        "se":   boot_se,
    })
    table["t_stat"] = table["beta"] / table["se"]
    table["ci_lo"] = table["beta"] - 1.96 * table["se"]
    table["ci_hi"] = table["beta"] + 1.96 * table["se"]

    post_mean = float(table.loc[table["tau"] >= 0, "beta"].mean())
    pre_max_t = float(np.nanmax(np.abs(
        table.loc[table["tau"] < 0, "t_stat"].values
    )))

    # Baseline (script 42 robust, for side-by-side)
    baseline_42 = {-2: 0.055, -1: 0.0, 0: 0.051, 1: 0.054,
                    2: 0.045, 3: 0.078, 4: 0.077}

    # ── 8. Report ──────────────────────────────────────────────────────────
    with open(OUT_REPORT, "w") as f:
        f.write("Borusyak-Jaravel-Spiess (2024) imputation estimator\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")

        f.write("DESIGN\n")
        f.write("-" * 50 + "\n")
        f.write("  Y = win_rate (firm × item × year)\n")
        f.write("  FE: α_i + γ_{jt}, fitted on untreated subsample\n")
        f.write("  Imputation: Y^0_{ijt} = α̂_i + γ̂_{jt} for treated obs\n")
        f.write("  τ_{ijt} = y_{ijt} - Y^0_{ijt}; aggregated by event time\n")
        f.write(f"  Event window: {EVENT_WINDOW}\n")
        f.write(f"  Bootstrap: B={N_BOOT}, firm-clustered\n\n")

        f.write("SAMPLE\n")
        f.write("-" * 50 + "\n")
        f.write(f"  Panel rows        : {n_obs:,}\n")
        f.write(f"  Firms             : {n_firms:,}  "
                f"(clusters for bootstrap)\n")
        f.write(f"  Items             : {panel['item'].nunique():,}\n")
        f.write(f"  Item × year cells : {n_iy:,}\n")
        f.write(f"  Untreated obs     : {n_u:,}\n")
        f.write(f"  Treated obs       : {n_t:,}  "
                f"({n_t_supported:,} with support, "
                f"{n_t_dropped:,} dropped)\n")
        f.write(f"  FE sweeps to converge: {sweeps_used}\n\n")

        f.write("EVENT-STUDY COEFFICIENTS\n")
        f.write("-" * 60 + "\n")
        f.write(f"{'τ':>4s}  {'β(BJS)':>10s}  {'SE':>7s}  {'t':>6s}  "
                f"{'95% CI':>19s}  {'β(42)':>8s}\n")
        f.write("-" * 60 + "\n")
        for _, row in table.iterrows():
            tau = int(row["tau"])
            b42 = baseline_42.get(tau, np.nan)
            sig = "***" if abs(row["t_stat"]) > 2.576 else \
                  "**"  if abs(row["t_stat"]) > 1.96  else \
                  "*"   if abs(row["t_stat"]) > 1.645 else ""
            f.write(f"{tau:>+4d}  {row['beta']:>+10.4f}  "
                    f"{row['se']:>7.4f}  {row['t_stat']:>+6.2f}  "
                    f"[{row['ci_lo']:+.3f}, {row['ci_hi']:+.3f}]  "
                    f"{b42:>+8.4f} {sig}\n")

        f.write(f"\n  Post mean β (BJS): {post_mean:+.4f}\n")
        f.write(f"  Post mean β (42) : +0.0610\n")
        f.write(f"  Pre-period max |t|: {pre_max_t:.2f}\n\n")

        f.write("INTERPRETATION\n")
        f.write("-" * 50 + "\n")
        f.write("  Pre-period τ_k ≈ 0 → imputation model fits pre-period;\n")
        f.write("                       parallel-trends assumption holds.\n")
        f.write("  Pre-period τ_k ≠ 0 → imputation model misfits; residual\n")
        f.write("                       trend bias in BOTH BJS and stacked.\n")
        f.write("  BJS β ≈ 42 β       → staggered-bias correction matters\n")
        f.write("                       little; results robust.\n")
        f.write("  BJS β ≠ 42 β       → one estimator carries residual bias;\n")
        f.write("                       reconcile before submission.\n")

    log(f"report → {OUT_REPORT}", t0)

    # ── 9. Figure ──────────────────────────────────────────────────────────
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        fig, ax = plt.subplots(figsize=(9, 5.5))
        taus = table["tau"].values
        ax.fill_between(taus, table["ci_lo"], table["ci_hi"],
                        alpha=0.15, color="#2166ac")
        ax.plot(taus, table["beta"], "o-", color="#2166ac",
                linewidth=2, markersize=6, label="BJS imputation")
        bt = [k for k in sorted(baseline_42.keys()) if lo <= k <= hi]
        ax.plot(bt, [baseline_42[k] for k in bt], "s--", color="#b2182b",
                linewidth=1.5, markersize=4, alpha=0.7,
                label="Stacked robust (42)")
        ax.axhline(0, color="grey", linewidth=0.8)
        ax.axvline(-0.5, color="red", linestyle="--", linewidth=1, alpha=0.4)
        ax.set_xlabel(r"$\tau$ (years since first ex-cartel worker)")
        ax.set_ylabel("Win rate (BJS-imputed)")
        ax.legend(fontsize=9, loc="best")
        ax.set_xticks(taus)
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)
        fig.tight_layout()
        fig.savefig(OUT_FIGURE, dpi=300, bbox_inches="tight")
        plt.close(fig)
        log(f"figure → {OUT_FIGURE}", t0)
    except ImportError:
        log("matplotlib unavailable; skipping figure", t0)

    log(f"DONE ({time.time() - t0:.1f}s)", t0)
    print("\n--- report ---")
    print(OUT_REPORT.read_text())


if __name__ == "__main__":
    main()


# ─────────────────────────────────────────────────────────────────────────────
# TODO — refinements
#
# 1. Analytical SE via BJS formula: the bootstrap is O(B × fit_time) and
#    dominates runtime. BJS (2024) provide closed-form variance that uses
#    the influence function of the imputation estimator. Implement if the
#    bootstrap takes >20 minutes in practice.
#
# 2. Pre-period placebo test: the BJS framework allows a formal joint
#    test of H0: τ_{-K}=…=τ_{-1}=0 using the bootstrap distribution. The
#    current report only lists individual pre-period τ_k.
#
# 3. Weighting: aggregate τ by cohort-size weights for a more
#    conservative post-mean, per BJS §3.2 (robust-and-efficient).
#
# 4. Imputation for the log-price outcome: re-run the script with
#    y = log(bid/ref) to produce a BJS check for the paper's price null.
#    This is the strongest test of the headline "+0.05 is informative"
#    claim from §6.2 of results.tex.
# ─────────────────────────────────────────────────────────────────────────────
