#!/usr/bin/env python3
"""
46_conditional_hire.py — Conditional-on-hiring placebo
=======================================================

Implements the placebo specification proposed in strategy.tex §5.2
(equation 3): holds the firm's hiring decision fixed and identifies β
from variation in the *source* of the new worker.

Motivation. Script 42's headline effect treats "first ex-cartel worker
arrives at firm i" as a shock to i. But hiring is a choice: a firm that
wins more cartel-item contracts hires to deliver, and displaced cartel
workers are the natural labor pool. To separate "worker as vehicle of
cartel know-how" from "the firm was going to hire anyway," we restrict
the sample to firm-years in which firm i actively hired a worker in a
cartel-relevant occupation, and ask whether it mattered that the new
hire came from a cartel rather than a non-cartel source.

Design

    R        := {cbo2002 observed at cartel firms during conduct}
                 (the set of CBOs a cartel worker could plausibly carry)

    new_hires_{it} := distinct PIS observed at firm i in year t
                      but not at firm i in year t-1
    n_hire_R_{it}  := |new_hires_{it} ∩ {pis whose cbo at i is in R}|
    n_cartel_{it}  := |new_hires_{it} ∩ {pis observed at cartel firm c
                      during c's conduct period, y > T_c}|

    any_hire_R_{it}  := 1[n_hire_R_{it}  > 0]
    cartel_hire_{it} := 1[n_cartel_{it} > 0]

Spec 1 — Flow binary, restricted sample (primary):

    y_{ijt} = β · cartel_hire_{it}
              + α_i + γ_{jt} + ε_{ijt}                   (i,t | any_hire_R=1)

Spec 2 — Flow continuous, restricted sample:

    y_{ijt} = β · ln(1 + n_cartel_{it})
              + δ · ln(1 + n_hire_R_{it})
              + α_i + γ_{jt} + ε_{ijt}                   (i,t | any_hire_R=1)

Spec 3 — Cumulative stock, full panel (robustness):

    y_{ijt} = β · ln(1 + cum_cartel_{it})
              + δ · ln(1 + cum_hire_R_{it})
              + α_i + γ_{jt} + ε_{ijt}                   (all i,t)

The flow primary (spec 1) is the cleanest placebo: it identifies β
entirely from firm-years when i was already hiring into a relevant
occupation. A null β implies the headline effect in script 42 is
driven by the hiring decision, not by cartel-specific worker know-how.
A surviving positive β supports the worker-as-vehicle interpretation.

Outputs
    02_data/intermediate/conditional_hire.txt        — all three specs
    02_data/intermediate/firm_year_hire_panel.parquet — precomputed
        firm × year aggregates (reusable by other scripts)
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

BEC_FIRMS    = str(BASE / "02_data" / "bec_cnpj_list.parquet")
PAIRS_PREGAO = str(FINAL / "df_pregao_with_cartel_flags.parquet")
GROUND_TRUTH = str(FIRMS / "cade_ground_truth.parquet")

OUT_REPORT  = INTER / "conditional_hire.txt"
OUT_PANEL   = INTER / "firm_year_hire_panel.parquet"

PANEL_YEARS = list(range(2009, 2018))


# ── Helpers ──────────────────────────────────────────────────────────────────

def log(msg: str, t0: float) -> None:
    print(f"[{time.time() - t0:6.1f}s | RSS {rss_gb():4.1f} GB] {msg}",
          flush=True)


def two_way_demean(x: np.ndarray, fid: np.ndarray, iyid: np.ndarray,
                   sweeps: int = 6) -> np.ndarray:
    z = x.astype(float).copy()
    for _ in range(sweeps):
        z -= pd.Series(z, copy=False).groupby(fid).transform("mean").values
        z -= pd.Series(z, copy=False).groupby(iyid).transform("mean").values
    return z


def estimate(Y: np.ndarray, X: np.ndarray, fid: np.ndarray,
             label: str, t0: float) -> dict:
    """OLS with firm + item×year FE absorbed, cluster-robust SE on firm.

    X has shape (n, k) with columns already demeaned. Y is demeaned.
    """
    n, k = X.shape
    XtX = X.T @ X
    if np.linalg.matrix_rank(XtX) < k:
        log(f"[{label}] rank-deficient X — skip", t0)
        return {}
    XtX_inv = np.linalg.inv(XtX)
    beta = XtX_inv @ (X.T @ Y)
    e = Y - X @ beta

    # Cluster-robust sandwich (CR1)
    nc = len(np.unique(fid))
    meat = np.zeros((k, k))
    fid_series = pd.Series(np.arange(n))
    for g in fid_series.groupby(fid).groups.values():
        idx = np.asarray(list(g)) if not isinstance(g, np.ndarray) else g
        Xg = X[idx]
        eg = e[idx]
        score = Xg.T @ eg
        meat += np.outer(score, score)
    correction = (nc / max(nc - 1, 1)) * ((n - 1) / max(n - k, 1))
    V = correction * XtX_inv @ meat @ XtX_inv
    se = np.sqrt(np.diag(V))
    t_stat = beta / se

    return {
        "label": label,
        "n": n,
        "nc": nc,
        "beta": beta,
        "se": se,
        "t": t_stat,
    }


def fmt_result(res: dict, names: list[str]) -> str:
    if not res:
        return "  (estimation skipped)\n"
    lines = [f"  n = {res['n']:,}   clusters = {res['nc']:,}"]
    for i, name in enumerate(names):
        b = res["beta"][i]
        s = res["se"][i]
        t = res["t"][i]
        sig = ("***" if abs(t) > 2.576 else
               "**"  if abs(t) > 1.96  else
               "*"   if abs(t) > 1.645 else "")
        lines.append(f"  {name:<25s}  β = {b:+.4f}   SE = {s:.4f}   "
                     f"t = {t:+.2f} {sig}")
    return "\n".join(lines) + "\n"


# ── Main ─────────────────────────────────────────────────────────────────────

def main() -> None:
    t0 = time.time()
    INTER.mkdir(parents=True, exist_ok=True)

    log(f"hostname={os.uname().nodename}, threads=12, mem_limit=14GB", t0)

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
    n_cartels = con.sql("SELECT COUNT(DISTINCT setor) FROM cf").fetchone()[0]
    log(f"  cartels (setor): {n_cartels}", t0)

    # ── 2. Relevant CBO set R ───────────────────────────────────────────────
    log("Step 2: relevant CBO set R (cartel-firm CBOs during conduct)", t0)
    con.sql(f"""
        CREATE TABLE R_cbo AS
        SELECT DISTINCT r.cbo2002::VARCHAR AS cbo
        FROM read_parquet('{rais_glob}') r
        JOIN cf ON r.cnpj_raiz = cf.cnpj_raiz
        WHERE r.ano BETWEEN cf.s AND cf.e
          AND r.cbo2002 IS NOT NULL
    """)
    n_R = con.sql("SELECT COUNT(*) FROM R_cbo").fetchone()[0]
    log(f"  |R| = {n_R:,} distinct CBO2002 codes", t0)

    # ── 3. BEC-firm worker-year panel ───────────────────────────────────────
    log("Step 3: BEC worker-year panel (wy)", t0)
    con.sql(f"""
        CREATE TABLE wy AS
        SELECT DISTINCT pis,
                         cnpj_raiz           AS firm,
                         ano                 AS year,
                         cbo2002::VARCHAR    AS cbo
        FROM read_parquet('{rais_glob}') r
        WHERE cnpj_raiz IN (SELECT cnpj_raiz FROM read_parquet('{BEC_FIRMS}'))
          AND cnpj_raiz NOT IN (SELECT cnpj_raiz FROM cf)
          AND pis     IS NOT NULL
          AND cbo2002 IS NOT NULL
    """)
    n_wy = con.sql("SELECT COUNT(*) FROM wy").fetchone()[0]
    log(f"  wy rows: {n_wy:,}", t0)

    # ── 4. New hires (pis at firm in year t, not in year t-1) ───────────────
    log("Step 4: new hires via lag anti-join", t0)
    con.sql("""
        CREATE TABLE new_hires AS
        SELECT a.pis, a.firm, a.year, a.cbo
        FROM wy a
        LEFT JOIN wy b
          ON b.pis  = a.pis
         AND b.firm = a.firm
         AND b.year = a.year - 1
        WHERE b.pis IS NULL
    """)
    n_new = con.sql("SELECT COUNT(*) FROM new_hires").fetchone()[0]
    log(f"  new_hires rows: {n_new:,}", t0)

    # ── 5. Cartel-source hires ──────────────────────────────────────────────
    # wy excludes cartel firms (step 3), so cw is built directly from RAIS
    # filtered to cartel firms during each cartel's conduct period.
    log("Step 5: cartel-source hires", t0)
    con.sql(f"""
        CREATE TABLE cw AS
        SELECT DISTINCT r.pis, r.cnpj_raiz AS cc, cf.setor, cf.e
        FROM read_parquet('{rais_glob}') r
        JOIN cf ON r.cnpj_raiz = cf.cnpj_raiz
        WHERE r.ano BETWEEN cf.s AND cf.e
          AND r.pis IS NOT NULL
    """)
    n_cw = con.sql("SELECT COUNT(*) FROM cw").fetchone()[0]
    log(f"  cw rows (cartel worker × conduct): {n_cw:,}", t0)

    # A new hire is "cartel-sourced" if the same PIS was at a cartel firm
    # during that cartel's conduct period, and the hire year is post-conduct
    # for that source cartel.
    con.sql("""
        CREATE TABLE cartel_hires AS
        SELECT DISTINCT nh.firm, nh.year, nh.pis
        FROM new_hires nh
        JOIN cw ON cw.pis = nh.pis
        WHERE nh.year > cw.e
    """)
    n_ch = con.sql("SELECT COUNT(*) FROM cartel_hires").fetchone()[0]
    log(f"  cartel_hires rows: {n_ch:,}", t0)

    # ── 6. Firm × year aggregates ───────────────────────────────────────────
    log("Step 6: firm × year aggregates", t0)
    years_str = ",".join(f"({y})" for y in PANEL_YEARS)
    con.sql(f"""
        CREATE TABLE years_t AS SELECT * FROM (VALUES {years_str}) AS t(year)
    """)
    con.sql("""
        CREATE TABLE any_hire_fy AS
        SELECT firm, year, COUNT(DISTINCT pis) AS n_hire_R
        FROM new_hires
        WHERE cbo IN (SELECT cbo FROM R_cbo)
        GROUP BY firm, year
    """)
    con.sql("""
        CREATE TABLE cartel_hire_fy AS
        SELECT firm, year, COUNT(DISTINCT pis) AS n_cartel_hire
        FROM cartel_hires
        GROUP BY firm, year
    """)
    con.sql("""
        CREATE TABLE firm_year_hires AS
        SELECT s.firm,
               y.year,
               COALESCE(a.n_hire_R,      0) AS n_hire_R,
               COALESCE(c.n_cartel_hire, 0) AS n_cartel_hire
        FROM (SELECT DISTINCT firm FROM wy) s
        CROSS JOIN years_t y
        LEFT JOIN any_hire_fy    a ON a.firm = s.firm AND a.year = y.year
        LEFT JOIN cartel_hire_fy c ON c.firm = s.firm AND c.year = y.year
    """)

    # Cumulative versions for spec 3
    con.sql("""
        CREATE TABLE firm_year_hires_cum AS
        SELECT firm, year, n_hire_R, n_cartel_hire,
               SUM(n_hire_R)      OVER w AS cum_hire_R,
               SUM(n_cartel_hire) OVER w AS cum_cartel
        FROM firm_year_hires
        WINDOW w AS (PARTITION BY firm ORDER BY year
                     ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
    """)
    con.sql(f"""
        COPY (SELECT * FROM firm_year_hires_cum)
        TO '{OUT_PANEL}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    log(f"  firm_year_hires → {OUT_PANEL}", t0)

    # ── 7. Outcome panel ────────────────────────────────────────────────────
    log("Step 7: outcome panel", t0)
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

    # ── 8. Merge ─────────────────────────────────────────────────────────────
    log("Step 8: merging", t0)
    panel = con.sql("""
        SELECT o.firm,
               o.item,
               o.year,
               o.win_rate,
               COALESCE(fy.n_hire_R,      0) AS n_hire_R,
               COALESCE(fy.n_cartel_hire, 0) AS n_cartel_hire,
               COALESCE(fy.cum_hire_R,    0) AS cum_hire_R,
               COALESCE(fy.cum_cartel,    0) AS cum_cartel
        FROM outcome o
        LEFT JOIN firm_year_hires_cum fy
          ON fy.firm = o.firm AND fy.year = o.year
        WHERE o.win_rate IS NOT NULL
    """).fetchdf()
    con.close()

    panel["any_hire_R"]   = (panel["n_hire_R"]      > 0).astype(int)
    panel["cartel_hire"]  = (panel["n_cartel_hire"] > 0).astype(int)
    panel["ln_n_hire_R"]   = np.log1p(panel["n_hire_R"])
    panel["ln_n_cartel"]   = np.log1p(panel["n_cartel_hire"])
    panel["ln_cum_hire_R"] = np.log1p(panel["cum_hire_R"])
    panel["ln_cum_cartel"] = np.log1p(panel["cum_cartel"])

    log(f"  panel: {len(panel):,} rows, {panel['firm'].nunique():,} firms, "
        f"{panel['year'].nunique()} years", t0)
    log(f"  any_hire_R=1 firm-years: "
        f"{panel.groupby(['firm','year'])['any_hire_R'].max().sum():,} "
        f"of {panel.groupby(['firm','year']).ngroups:,}", t0)
    log(f"  cartel_hire=1 firm-years: "
        f"{panel.groupby(['firm','year'])['cartel_hire'].max().sum():,}", t0)

    # ── 9. Spec 1 — flow binary, restricted ──────────────────────────────────
    log("Step 9: Spec 1 (flow binary, restricted to any_hire_R=1)", t0)
    df1 = panel[panel["any_hire_R"] == 1].copy()
    if len(df1) == 0:
        log("  ⚠ Spec 1 sample empty — check relevant-CBO definition", t0)
        res1 = {}
    else:
        df1["fid"]  = df1["firm"].astype("category").cat.codes
        df1["iyid"] = (df1["item"].astype(str) + "_" + df1["year"].astype(str)) \
                      .astype("category").cat.codes
        fid1, iyid1 = df1["fid"].values, df1["iyid"].values
        Y1 = two_way_demean(df1["win_rate"].values.astype(float), fid1, iyid1)
        X1 = np.column_stack([
            two_way_demean(df1["cartel_hire"].values.astype(float), fid1, iyid1),
        ])
        res1 = estimate(Y1, X1, fid1, "Spec 1", t0)
        if res1:
            log(f"  Spec 1 β = {res1['beta'][0]:+.4f} "
                f"(SE {res1['se'][0]:.4f}, t {res1['t'][0]:+.2f})", t0)

    # ── 10. Spec 2 — flow continuous, restricted ────────────────────────────
    log("Step 10: Spec 2 (flow continuous, restricted)", t0)
    if len(df1) > 0:
        X2 = np.column_stack([
            two_way_demean(df1["ln_n_cartel"].values.astype(float), fid1, iyid1),
            two_way_demean(df1["ln_n_hire_R"].values.astype(float), fid1, iyid1),
        ])
        res2 = estimate(Y1, X2, fid1, "Spec 2", t0)
        if res2:
            log(f"  Spec 2 β(ln_n_cartel) = {res2['beta'][0]:+.4f} "
                f"(SE {res2['se'][0]:.4f}, t {res2['t'][0]:+.2f})", t0)
    else:
        res2 = {}

    # ── 11. Spec 3 — cumulative stock, full panel ───────────────────────────
    log("Step 11: Spec 3 (cumulative, full panel)", t0)
    df3 = panel.copy()
    df3["fid"]  = df3["firm"].astype("category").cat.codes
    df3["iyid"] = (df3["item"].astype(str) + "_" + df3["year"].astype(str)) \
                  .astype("category").cat.codes
    fid3, iyid3 = df3["fid"].values, df3["iyid"].values
    Y3 = two_way_demean(df3["win_rate"].values.astype(float), fid3, iyid3)
    X3 = np.column_stack([
        two_way_demean(df3["ln_cum_cartel"].values.astype(float), fid3, iyid3),
        two_way_demean(df3["ln_cum_hire_R"].values.astype(float), fid3, iyid3),
    ])
    res3 = estimate(Y3, X3, fid3, "Spec 3", t0)
    if res3:
        log(f"  Spec 3 β(ln_cum_cartel) = {res3['beta'][0]:+.4f} "
            f"(SE {res3['se'][0]:.4f}, t {res3['t'][0]:+.2f})", t0)

    # ── 12. Report ──────────────────────────────────────────────────────────
    with open(OUT_REPORT, "w") as f:
        f.write("Conditional-on-hiring placebo\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")

        f.write("DESIGN\n")
        f.write("-" * 50 + "\n")
        f.write("  R = CBO2002 codes observed at cartel firms during conduct\n")
        f.write(f"  |R| = {n_R:,}\n")
        f.write("  new_hires: PIS at firm in year t but not in year t-1\n")
        f.write("  cartel_hire: 1 if any new hire's PIS was at a cartel firm\n")
        f.write("               during that cartel's conduct period\n")
        f.write("  any_hire_R:  1 if any new hire's CBO at firm is in R\n\n")
        f.write("  Y = win_rate (firm × item × year)\n")
        f.write("  FE: firm + item × year\n")
        f.write("  SE: clustered at firm (CR1)\n\n")

        f.write("SAMPLE\n")
        f.write("-" * 50 + "\n")
        f.write(f"  Panel rows          : {len(panel):,}\n")
        f.write(f"  Firms               : {panel['firm'].nunique():,}\n")
        f.write(f"  Items               : {panel['item'].nunique():,}\n")
        f.write(f"  Years               : "
                f"{panel['year'].min()}–{panel['year'].max()}\n")
        f.write(f"  Restricted (any_hire_R=1) rows: {len(df1):,}\n\n")

        f.write("SPEC 1 — Flow binary, restricted sample (PRIMARY)\n")
        f.write("-" * 50 + "\n")
        f.write("  y_{ijt} = β · cartel_hire_{it} + α_i + γ_{jt} + ε\n")
        f.write("  Identification: source of new hire, holding hiring fixed.\n")
        f.write(fmt_result(res1, ["cartel_hire"]))
        f.write("\n")

        f.write("SPEC 2 — Flow continuous, restricted sample\n")
        f.write("-" * 50 + "\n")
        f.write("  y_{ijt} = β·ln(1+n_cartel) + δ·ln(1+n_hire_R) + FE\n")
        f.write(fmt_result(res2, ["ln(1+n_cartel)", "ln(1+n_hire_R)"]))
        f.write("\n")

        f.write("SPEC 3 — Cumulative stock, full panel\n")
        f.write("-" * 50 + "\n")
        f.write("  y_{ijt} = β·ln(1+cum_cartel) + δ·ln(1+cum_hire_R) + FE\n")
        f.write(fmt_result(res3, ["ln(1+cum_cartel)", "ln(1+cum_hire_R)"]))
        f.write("\n")

        f.write("INTERPRETATION\n")
        f.write("-" * 50 + "\n")
        f.write("  Spec 1 β ≈ 0  → headline effect is a hiring-decision artifact;\n")
        f.write("                  source of new hire does not matter.\n")
        f.write("  Spec 1 β > 0  → worker-as-vehicle survives within-hiring\n")
        f.write("                  placebo; cartel source carries information\n")
        f.write("                  or capacity beyond generic hires in R.\n")
        f.write("  Spec 2 confirms Spec 1 with dose-response.\n")
        f.write("  Spec 3 links to the cumulative-stock framing used in\n")
        f.write("  scripts 42 and 45 (Bartik IV).\n")

    log(f"report → {OUT_REPORT}", t0)
    log(f"DONE ({time.time() - t0:.1f}s)", t0)
    print("\n--- report ---")
    print(OUT_REPORT.read_text())


if __name__ == "__main__":
    main()


# ─────────────────────────────────────────────────────────────────────────────
# TODO — refinements to consider once the base specs have run
#
# 1. Tighten "relevant occupation" R: currently R is any CBO observed at
#    cartel firms during conduct. This is broad — cartel firms employ
#    receptionists, drivers, janitors. A tighter R would be the set of
#    CBOs that account for the top 90% of cartel-firm headcount, or
#    CBOs that are *overrepresented* at cartel firms relative to BEC
#    baseline (LQ > 1.5).
#
# 2. Split by mover type: re-estimate Spec 1 with two binary treatments —
#    cartel_hire_manager and cartel_hire_operational — to test whether
#    the conditional-on-hiring effect (if any) is concentrated in the
#    CBO groups that plausibly carry coordination know-how (1-2 vs 5-7).
#
# 3. Add a conditional-on-hiring exit placebo: cartel_hire replaced by
#    exit_hire (new hire from a non-cartel BEC firm that stopped bidding
#    in the same year). This is the conditional-on-hiring version of
#    script 39 (exit placebo) and would directly test "cartel-specific"
#    against "generic exit-firm source."
#
# 4. Lagged treatment: include cartel_hire_{i,t-1} and cartel_hire_{i,t-2}
#    to let the effect play out over multiple years, allowing comparison
#    to the event-study horizon in script 42.
# ─────────────────────────────────────────────────────────────────────────────
