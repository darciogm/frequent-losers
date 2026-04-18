#!/usr/bin/env python3
"""
45_bartik_iv.py — Shift-share IV for ex-cartel worker absorption
================================================================

Implements the Borusyak-Hull-Jaravel exposure design proposed in
strategy.tex §5.2 (Endogeneity of treatment timing). The instrument
predicts firm i's exposure to cartel-worker inflow using only
predetermined (2009) occupational-geographic structure interacted with
each cartel's end-of-conduct workforce in those same cells:

    Z_{it} = sum_c 1[t >= T_c] * sum_k W_{c,k} * s_{i,k}^{2009}

where
    * c indexes the seven CADE-convicted SP-relevant cartels
    * T_c is cartel c's end-of-conduct year (cartel_end_year in cf)
    * W_{c,k} is the cartel's end-of-conduct workforce in CBO-mun cell k
      (summed across CNPJ_raiz within the same cartel sector)
    * s_{i,k}^{2009} is firm i's 2009 share of total non-cartel BEC-firm
      employment in cell k (predetermined to all post-treatment outcomes)

Actual treatment D_{it} is the cumulative number of distinct ex-cartel
workers absorbed by firm i through year t (PIS observed at a cartel
firm during conduct, then at firm i in year t' <= t with t' > T_c).

Specification (continuous-treatment 2SLS, two-way FE):

    y_{ijt} = beta * D_hat_{it} + alpha_i + gamma_{jt} + eps         (2nd)
    D_{it}  = pi   * Z_{it}     + alpha_i + gamma_{jt} + u           (1st)

with D = ln(1 + workers_absorbed) and Z = ln(1 + predicted_exposure).
SE clustered at firm level.

Pre-period falsification: regress 2009-2011 win-rate on Z (year-by-year
demeaned). Should be null under exclusion.

Outputs:
    02_data/intermediate/bartik_iv.txt          — first-stage F, IV beta, OLS beta
    02_data/intermediate/bartik_exposure.parquet — Z_full panel (firm × year)
    04_figures/bartik_iv_first_stage.pdf        — first-stage scatter
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

OUT_REPORT   = INTER / "bartik_iv.txt"
OUT_FIGURE   = FIGS  / "bartik_iv_first_stage.pdf"
OUT_EXPOSURE = INTER / "bartik_exposure.parquet"

PRE_YEAR    = 2009
PANEL_YEARS = list(range(2009, 2018))


# ── Helpers ──────────────────────────────────────────────────────────────────

def log(msg: str, t0: float) -> None:
    print(f"[{time.time() - t0:6.1f}s | RSS {rss_gb():4.1f} GB] {msg}",
          flush=True)


def two_way_demean(x: np.ndarray, fid: np.ndarray, iyid: np.ndarray,
                   sweeps: int = 6) -> np.ndarray:
    """Alternating projections to absorb firm + item-by-year FE."""
    z = x.astype(float).copy()
    s_f = pd.Series(z, copy=False)
    for _ in range(sweeps):
        s_f = pd.Series(z, copy=False)
        z = (z - s_f.groupby(fid).transform("mean").values)
        s_i = pd.Series(z, copy=False)
        z = (z - s_i.groupby(iyid).transform("mean").values)
    return z


# ── Main ─────────────────────────────────────────────────────────────────────

def main() -> None:
    t0 = time.time()
    INTER.mkdir(parents=True, exist_ok=True)
    FIGS.mkdir(parents=True, exist_ok=True)

    log(f"hostname={os.uname().nodename}, threads=12, mem_limit=14GB", t0)
    log(f"PRE_YEAR={PRE_YEAR}, PANEL_YEARS=[{PANEL_YEARS[0]}..{PANEL_YEARS[-1]}]", t0)

    con = duckdb.connect()
    con.sql("PRAGMA threads=12; PRAGMA memory_limit='14GB'")
    con.sql("PRAGMA temp_directory='/tmp/duckdb_spill'")

    rais_glob = str(RAIS_DIR / "rais_vinculos_*.parquet")
    rais_pre  = str(RAIS_DIR / f"rais_vinculos_{PRE_YEAR}.parquet")

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
    n_cartels = con.sql("SELECT COUNT(DISTINCT setor) FROM cf").fetchone()[0]
    n_cf      = con.sql("SELECT COUNT(DISTINCT cnpj_raiz) FROM cf").fetchone()[0]
    log(f"  cartels (setor): {n_cartels}, cartel firms: {n_cf}", t0)

    # ── 2. Pre-period shares s_{i,k}^{2009} ─────────────────────────────────
    log(f"Step 2: pre-period shares from RAIS {PRE_YEAR}", t0)
    con.sql(f"""
        CREATE TABLE pre_emp AS
        SELECT cnpj_raiz                  AS firm,
               cbo2002::VARCHAR           AS cbo,
               mun_estab::VARCHAR         AS mun,
               COUNT(*)                   AS n_workers
        FROM read_parquet('{rais_pre}')
        WHERE cnpj_raiz IN (SELECT cnpj_raiz FROM read_parquet('{BEC_FIRMS}'))
          AND cnpj_raiz NOT IN (SELECT cnpj_raiz FROM cf)
          AND cbo2002  IS NOT NULL
          AND mun_estab IS NOT NULL
        GROUP BY firm, cbo, mun
    """)
    con.sql("""
        CREATE TABLE pre_cell_total AS
        SELECT cbo, mun, SUM(n_workers) AS total
        FROM pre_emp GROUP BY cbo, mun
    """)
    con.sql("""
        CREATE TABLE shares AS
        SELECT pe.firm, pe.cbo, pe.mun,
               pe.n_workers::DOUBLE / pct.total::DOUBLE AS share
        FROM pre_emp pe
        JOIN pre_cell_total pct USING (cbo, mun)
        WHERE pct.total > 0
    """)
    n_share_rows  = con.sql("SELECT COUNT(*) FROM shares").fetchone()[0]
    n_share_firms = con.sql("SELECT COUNT(DISTINCT firm) FROM shares").fetchone()[0]
    log(f"  shares rows: {n_share_rows:,}, firms with shares: {n_share_firms:,}", t0)

    # ── 3. Cartel workforce by cell at end of conduct ───────────────────────
    log("Step 3: cartel workforce by cell at end of conduct", t0)
    con.sql(f"""
        CREATE TABLE cartel_emp AS
        SELECT cf.setor,
               cf.e                       AS T_c,
               r.cbo2002::VARCHAR         AS cbo,
               r.mun_estab::VARCHAR       AS mun,
               COUNT(*)                   AS w_workers
        FROM read_parquet('{rais_glob}') r
        JOIN cf ON r.cnpj_raiz = cf.cnpj_raiz AND r.ano = cf.e
        WHERE r.cbo2002  IS NOT NULL
          AND r.mun_estab IS NOT NULL
        GROUP BY cf.setor, cf.e, cbo, mun
    """)
    con.sql("""
        CREATE TABLE cartel_cell AS
        SELECT setor, MIN(T_c) AS T_c, cbo, mun, SUM(w_workers) AS W_ck
        FROM cartel_emp GROUP BY setor, cbo, mun
    """)
    n_cartel_cells = con.sql("SELECT COUNT(*) FROM cartel_cell").fetchone()[0]
    log(f"  cartel × cell rows: {n_cartel_cells:,}", t0)

    # ── 4. Firm × cartel exposure → Z_{it} ──────────────────────────────────
    log("Step 4: shift-share exposure Z_{it}", t0)
    # Two-step to avoid blowing up the join: first aggregate over cells
    # within (firm, setor), then expand by year.
    con.sql("""
        CREATE TABLE firm_cartel_exposure AS
        SELECT s.firm, cc.setor,
               MIN(cc.T_c)              AS T_c,
               SUM(cc.W_ck * s.share)   AS exp_fc
        FROM shares s
        JOIN cartel_cell cc USING (cbo, mun)
        GROUP BY s.firm, cc.setor
    """)
    n_fce = con.sql("SELECT COUNT(*) FROM firm_cartel_exposure").fetchone()[0]
    log(f"  firm × cartel exposure rows: {n_fce:,}", t0)

    years_str = ",".join(f"({y})" for y in PANEL_YEARS)
    con.sql(f"""
        CREATE TABLE years_t AS SELECT * FROM (VALUES {years_str}) AS t(year)
    """)
    con.sql("""
        CREATE TABLE Z_full AS
        SELECT s.firm, y.year,
               COALESCE(SUM(CASE WHEN y.year >= fce.T_c THEN fce.exp_fc END), 0.0)
                 AS Z_raw
        FROM (SELECT DISTINCT firm FROM shares) s
        CROSS JOIN years_t y
        LEFT JOIN firm_cartel_exposure fce ON fce.firm = s.firm
        GROUP BY s.firm, y.year
    """)
    n_z = con.sql("SELECT COUNT(*) FROM Z_full").fetchone()[0]
    z_pos = con.sql("SELECT COUNT(*) FROM Z_full WHERE Z_raw > 0").fetchone()[0]
    log(f"  Z_{{it}} rows: {n_z:,} ({z_pos:,} strictly positive)", t0)

    # Persist exposure for downstream scripts
    con.sql(f"""
        COPY (SELECT * FROM Z_full)
        TO '{OUT_EXPOSURE}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    log(f"  exposure → {OUT_EXPOSURE}", t0)

    # ── 5. Actual cumulative cartel-worker absorption D_{it} ────────────────
    log("Step 5: actual cumulative absorption D_{it}", t0)
    con.sql(f"""
        CREATE TABLE wy AS
        SELECT DISTINCT pis, cnpj_raiz, ano AS year
        FROM read_parquet('{rais_glob}')
        WHERE cnpj_raiz IN (SELECT cnpj_raiz FROM read_parquet('{BEC_FIRMS}'))
          AND pis IS NOT NULL AND cnpj_raiz IS NOT NULL
    """)
    con.sql("""
        CREATE TABLE cw AS
        SELECT DISTINCT w.pis, w.cnpj_raiz AS cc, cf.setor, cf.e
        FROM wy w
        JOIN cf ON w.cnpj_raiz = cf.cnpj_raiz
        WHERE w.year BETWEEN cf.s AND cf.e
    """)
    con.sql("""
        CREATE TABLE absorb_events AS
        SELECT w2.cnpj_raiz AS firm,
               w2.pis       AS pis,
               MIN(w2.year) AS arrival_year
        FROM cw
        JOIN wy w2 ON cw.pis = w2.pis
        WHERE w2.cnpj_raiz != cw.cc
          AND w2.year > cw.e
          AND w2.cnpj_raiz NOT IN (SELECT cnpj_raiz FROM cf WHERE setor = cw.setor)
        GROUP BY w2.cnpj_raiz, w2.pis
    """)
    con.sql("""
        CREATE TABLE D_full AS
        SELECT s.firm, y.year,
               COUNT(CASE WHEN ae.arrival_year <= y.year THEN 1 END) AS d_workers
        FROM (SELECT DISTINCT firm FROM shares) s
        CROSS JOIN years_t y
        LEFT JOIN absorb_events ae ON ae.firm = s.firm
        GROUP BY s.firm, y.year
    """)
    n_d_pos = con.sql("SELECT COUNT(*) FROM D_full WHERE d_workers > 0").fetchone()[0]
    log(f"  D_{{it}} rows with d_workers>0: {n_d_pos:,}", t0)

    # ── 6. Outcome panel ────────────────────────────────────────────────────
    log("Step 6: outcome panel (firm × item × year)", t0)
    con.sql(f"""
        CREATE TABLE ci AS
        SELECT DISTINCT "códigoitem"
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8]
              IN (SELECT cnpj_raiz FROM cf)
    """)
    con.sql(f"""
        CREATE TABLE outcome AS
        SELECT LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8] AS firm,
               "códigoitem"           AS item,
               year,
               COUNT(*)               AS n_bids,
               AVG(flagvencedor)      AS win_rate
        FROM read_parquet('{PAIRS_PREGAO}')
        WHERE "códigoitem" IN (SELECT "códigoitem" FROM ci)
          AND LPAD(CAST("códigofornecedor" AS VARCHAR),14,'0')[1:8]
              NOT IN (SELECT cnpj_raiz FROM cf)
          AND year IN (SELECT year FROM years_t)
        GROUP BY firm, item, year
    """)
    n_panel = con.sql("SELECT COUNT(*) FROM outcome").fetchone()[0]
    log(f"  outcome rows: {n_panel:,}", t0)

    # ── 7. Merge into estimation panel ──────────────────────────────────────
    log("Step 7: merging panel + Z + D", t0)
    panel = con.sql("""
        SELECT o.firm,
               o.item,
               o.year,
               o.win_rate,
               LN(1 + COALESCE(z.Z_raw,    0.0)) AS Z,
               LN(1 + COALESCE(d.d_workers, 0))  AS D
        FROM outcome o
        LEFT JOIN Z_full z ON z.firm = o.firm AND z.year = o.year
        LEFT JOIN D_full d ON d.firm = o.firm AND d.year = o.year
        WHERE o.win_rate IS NOT NULL
    """).fetchdf()
    log(f"  merged: {len(panel):,} rows, {panel['firm'].nunique():,} firms, "
        f"{panel['item'].nunique():,} items, {panel['year'].nunique()} years", t0)
    con.close()

    if len(panel) == 0:
        raise SystemExit("Empty estimation panel — abort.")

    # ── 8. 2SLS estimation ──────────────────────────────────────────────────
    log("Step 8: 2SLS estimation", t0)
    df = panel.copy()
    df["fid"]  = df["firm"].astype("category").cat.codes
    df["iyid"] = (df["item"].astype(str) + "_" + df["year"].astype(str)) \
                 .astype("category").cat.codes

    fid  = df["fid"].values
    iyid = df["iyid"].values

    Y_dm = two_way_demean(df["win_rate"].values.astype(float), fid, iyid)
    D_dm = two_way_demean(df["D"].values.astype(float),        fid, iyid)
    Z_dm = two_way_demean(df["Z"].values.astype(float),        fid, iyid)

    n_obs = len(Y_dm)
    if (Z_dm @ Z_dm) <= 0 or (Z_dm @ D_dm) == 0:
        raise SystemExit(
            "Z or Z·D collapses to zero after demean — instrument has no variation "
            "within firm × item-year. Check shares and cartel_cell coverage."
        )

    # First stage: D_dm = pi * Z_dm + e
    pi_hat = (Z_dm @ D_dm) / (Z_dm @ Z_dm)
    fs_resid = D_dm - pi_hat * Z_dm
    fs_rss = (fs_resid ** 2).sum()
    fs_tss = (D_dm ** 2).sum()
    fs_r2  = 1.0 - fs_rss / fs_tss if fs_tss > 0 else float("nan")
    # Heuristic F (single instrument, single endogenous, demeaned)
    fs_F = (fs_r2 / max(1 - fs_r2, 1e-12)) * (n_obs - 2)
    log(f"  first-stage π̂ = {pi_hat:+.4f}  R² = {fs_r2:.4f}  F ≈ {fs_F:,.1f}", t0)

    # Second stage (Wald IV):
    beta_iv  = (Z_dm @ Y_dm) / (Z_dm @ D_dm)
    beta_ols = (D_dm @ Y_dm) / (D_dm @ D_dm)
    log(f"  IV  β = {beta_iv:+.4f}", t0)
    log(f"  OLS β = {beta_ols:+.4f}", t0)

    # Cluster-robust IV variance: V = (Z'D)^{-2} * sum_g (Z_g' e_g)^2
    e_iv = Y_dm - beta_iv * D_dm
    cluster_scores = pd.Series(Z_dm * e_iv, copy=False) \
                       .groupby(fid).sum().values
    meat = (cluster_scores ** 2).sum()
    nc   = int(df["fid"].nunique())
    correction = nc / max(nc - 1, 1)
    var_iv = correction * meat / ((Z_dm @ D_dm) ** 2)
    se_iv  = float(np.sqrt(var_iv))
    t_iv   = beta_iv / se_iv if se_iv > 0 else float("nan")
    log(f"  IV SE  = {se_iv:.4f}  t = {t_iv:+.2f}  (clusters = {nc:,})", t0)

    # Cluster-robust OLS SE for comparison
    e_ols = Y_dm - beta_ols * D_dm
    cs_ols = pd.Series(D_dm * e_ols, copy=False).groupby(fid).sum().values
    meat_ols = (cs_ols ** 2).sum()
    var_ols = correction * meat_ols / ((D_dm @ D_dm) ** 2)
    se_ols = float(np.sqrt(var_ols))
    t_ols = beta_ols / se_ols if se_ols > 0 else float("nan")

    # ── 9. Pre-period falsification ─────────────────────────────────────────
    log("Step 9: pre-period falsification (Z → Y on year ≤ 2011)", t0)
    pre = df[df["year"] <= 2011].copy()
    if len(pre) > 100:
        pre["fid_p"]  = pre["firm"].astype("category").cat.codes
        pre["iyid_p"] = (pre["item"].astype(str) + "_" + pre["year"].astype(str)) \
                        .astype("category").cat.codes
        Yp = two_way_demean(pre["win_rate"].values.astype(float),
                            pre["fid_p"].values, pre["iyid_p"].values)
        Zp = two_way_demean(pre["Z"].values.astype(float),
                            pre["fid_p"].values, pre["iyid_p"].values)
        if (Zp @ Zp) > 1e-12:
            beta_pre = (Zp @ Yp) / (Zp @ Zp)
            ep = Yp - beta_pre * Zp
            cs_p = pd.Series(Zp * ep, copy=False) \
                     .groupby(pre["fid_p"].values).sum().values
            mp = (cs_p ** 2).sum()
            ncp = int(pre["fid_p"].nunique())
            corr_p = ncp / max(ncp - 1, 1)
            var_pre = corr_p * mp / ((Zp @ Zp) ** 2)
            se_pre = float(np.sqrt(var_pre))
            t_pre = beta_pre / se_pre if se_pre > 0 else float("nan")
            log(f"  pre-period β(Z→Y) = {beta_pre:+.4f} "
                f"(SE {se_pre:.4f}, t {t_pre:+.2f}, n={len(pre):,})", t0)
        else:
            beta_pre = se_pre = t_pre = float("nan")
            log("  pre-period Z has zero variance after demean", t0)
    else:
        beta_pre = se_pre = t_pre = float("nan")
        log("  pre-period sample too small", t0)

    # ── 10. Report ──────────────────────────────────────────────────────────
    with open(OUT_REPORT, "w") as f:
        f.write("Bartik shift-share IV for ex-cartel worker absorption\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")

        f.write("DESIGN\n")
        f.write("-" * 50 + "\n")
        f.write("  Y = win_rate (firm × item × year)\n")
        f.write("  D = ln(1 + cumulative ex-cartel workers absorbed)\n")
        f.write("  Z = ln(1 + sum_c 1[t≥T_c] · sum_k W_{c,k} · s_{i,k}^{2009})\n")
        f.write("  FE: firm + item × year (two-way demeaned)\n")
        f.write("  SE: clustered at firm\n\n")

        f.write("SAMPLE\n")
        f.write("-" * 50 + "\n")
        f.write(f"  Estimation rows : {n_obs:,}\n")
        f.write(f"  Firms (clusters): {nc:,}\n")
        f.write(f"  Items           : {df['item'].nunique():,}\n")
        f.write(f"  Years           : {df['year'].min()}–{df['year'].max()}\n")
        f.write(f"  Cartels         : {n_cartels}\n")
        f.write(f"  Cartel cells    : {n_cartel_cells:,}\n")
        f.write(f"  Pre-shares rows : {n_share_rows:,}\n\n")

        f.write("FIRST STAGE\n")
        f.write("-" * 50 + "\n")
        f.write(f"  π̂            = {pi_hat:+.4f}\n")
        f.write(f"  R²            = {fs_r2:.4f}\n")
        f.write(f"  F (heuristic) ≈ {fs_F:,.1f}\n")
        if fs_F < 10:
            f.write("  ⚠ WEAK INSTRUMENT (F < 10).\n")
        elif fs_F < 23.1:
            f.write("  ⚠ Borderline (Stock-Yogo 5% threshold ≈ 23.1).\n")
        else:
            f.write("  ✓ Strong (F > Stock-Yogo 5% threshold).\n")
        f.write("\n")

        f.write("SECOND STAGE\n")
        f.write("-" * 50 + "\n")
        f.write(f"  IV  β = {beta_iv:+.4f}  (SE {se_iv:.4f}, t {t_iv:+.2f})\n")
        f.write(f"  OLS β = {beta_ols:+.4f}  (SE {se_ols:.4f}, t {t_ols:+.2f})\n\n")

        f.write("PRE-PERIOD FALSIFICATION (year ≤ 2011)\n")
        f.write("-" * 50 + "\n")
        f.write(f"  β(Z→Y) = {beta_pre:+.4f}  (SE {se_pre:.4f}, t {t_pre:+.2f})\n")
        if not np.isnan(t_pre):
            if abs(t_pre) < 1.65:
                f.write("  ✓ Z does not predict pre-period win rate "
                        "(exclusion supported).\n")
            else:
                f.write("  ✗ Z predicts pre-period win rate "
                        "— EXCLUSION RESTRICTION SUSPECT.\n")
        f.write("\n")

        f.write("INTERPRETATION GUIDE\n")
        f.write("-" * 50 + "\n")
        f.write("  IV β > OLS β → OLS downward-biased (capacity constraint?)\n")
        f.write("  IV β < OLS β → OLS upward-biased (reverse causality / selection)\n")
        f.write("  IV β ≈ OLS β → endogeneity bias modest\n")
        f.write(f"  Caveat: only {n_cartels} cartels — low end of shift-share\n")
        f.write("  asymptotics. Consider Borusyak-Hull-Jaravel (2022) inference\n")
        f.write("  with permutation across cartel-end-date assignments.\n")

    log(f"report → {OUT_REPORT}", t0)

    # ── 11. First-stage diagnostic figure ───────────────────────────────────
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        fig, ax = plt.subplots(figsize=(8, 5))
        df_plot = df[(df["Z"] > 0) | (df["D"] > 0)].copy()
        if len(df_plot) > 20000:
            df_plot = df_plot.sample(20000, random_state=1)
        ax.scatter(df_plot["Z"], df_plot["D"],
                   alpha=0.10, s=8, color="#2166ac")
        zg = np.linspace(df["Z"].min(), df["Z"].max(), 50)
        # Fit line through means + slope = pi_hat (visual aid only)
        ax.plot(zg, (zg - df["Z"].mean()) * pi_hat + df["D"].mean(),
                color="#b2182b", linewidth=2,
                label=f"π̂ = {pi_hat:+.3f}  (F ≈ {fs_F:,.0f})")
        ax.set_xlabel(r"$Z = \ln(1 + \mathrm{predicted\ exposure})$")
        ax.set_ylabel(r"$D = \ln(1 + \mathrm{workers\ absorbed})$")
        ax.set_title("First stage: shift-share predicts actual absorption")
        ax.legend(loc="upper left")
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
# TODO — event-study extension
#
# This first cut estimates a single continuous-treatment 2SLS coefficient.
# To produce IV event-study coefficients (analogous to script 42), bin Z
# relative to a "predicted treatment year" (e.g., the first year Z crosses
# its within-firm median) and run cohort-stacked 2SLS event by event.
# Two known complications:
#   (1) Z is monotone in calendar time once 1[t ≥ T_c] turns on; pre/post
#       binning needs to anchor on cartel-conviction time, not calendar.
#   (2) Staggered IV theory is thin; consider de Chaisemartin &
#       D'Haultfœuille (2024) for IV-DiD with continuous treatment, or the
#       Borusyak-Jaravel-Spiess (2024) imputation estimator with Z as the
#       imputation regressor.
#
# Diagnostics to add in a follow-up script:
#   - Dose response: nonparametric local-linear of Y on D̂ (binscatter)
#   - Permutation inference: reshuffle cartel end dates within calendar
#     range, recompute β_IV, build empirical p-value (cf. BHJ 2022 §V.B)
#   - Goldsmith-Pinkham-Sorkin-Swift Rotemberg weights to identify
#     which (cbo, mun) cells are driving identification
# ─────────────────────────────────────────────────────────────────────────────
