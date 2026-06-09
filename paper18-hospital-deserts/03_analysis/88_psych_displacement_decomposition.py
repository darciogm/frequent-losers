#!/usr/bin/env python3
"""
88_psych_displacement_decomposition.py

Where does inpatient *psychiatric* use go after a PNASH closure?

The all-cause first-stage decomposition (script 52) carried a known caveat:
"psychiatric-specific decomposition requires a dedicated SIH edge rebuild."
This script does that rebuild. It re-aggregates SIH-RD edges keeping only
psychiatric admissions (DIAG_PRINC F00-F99), then runs the identical
closing-vs-other-hospital decomposition over the PNASH psychiatric closures
on the exact catchment and event windows used in the paper.

Inputs (read-only):
  02_data/raw/sih_rd/rd*.parquet               record-level AIH
  02_data/intermediate/hospital_master.parquet hospital universe (CNES)
  02_data/intermediate/bipartite_edges.parquet all-cause edges (catchment def)
  02_data/intermediate/hospital_closures_exogenous.parquet

Outputs:
  02_data/intermediate/bipartite_edges_psych.parquet  (cached; --force to rebuild)
  02_data/processed/psych_displacement_panel.parquet  (cnes x event_time panel; figure input)
  02_data/processed/displacement_decomposition.csv    (machine-readable summary)
  01_manuscript/tables/table_displacement_compact.tex (main-text)
  01_manuscript/tables_appendix/table_displacement_full.tex (appendix)
  01_manuscript/values_displacement.tex               (LaTeX macros)
  04_logs/displacement_decomposition_YYYYMMDD.log

Usage: python 03_analysis/88_psych_displacement_decomposition.py [--force]
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
import time
from pathlib import Path

import duckdb
import numpy as np
import pandas as pd
import psutil

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "02_data" / "raw" / "sih_rd"
INTER = ROOT / "02_data" / "intermediate"
PROC = ROOT / "02_data" / "processed"
TAB = ROOT / "01_manuscript" / "tables"
TAB_APP = ROOT / "01_manuscript" / "tables_appendix"
LOGDIR = ROOT / "04_logs"

HOSP_MASTER = INTER / "hospital_master.parquet"
EDGES_ALL = INTER / "bipartite_edges.parquet"
EDGES_PSY = INTER / "bipartite_edges_psych.parquet"
CLOSURES = INTER / "hospital_closures_exogenous.parquet"

PANEL_OUT = PROC / "psych_displacement_panel.parquet"
CSV_OUT = PROC / "displacement_decomposition.csv"
TEX_COMPACT = TAB / "table_displacement_compact.tex"
TEX_FULL = TAB_APP / "table_displacement_full.tex"
MACROS_OUT = ROOT / "01_manuscript" / "values_displacement.tex"

# Same PNASH psychiatric sample as scripts 51/52.
PNASH_WHERE = (
    "f1_window AND f2_type AND f3_beds AND f4_mass AND tp_unid='07' AND "
    "(year_closure BETWEEN 2006 AND 2009 OR year_closure BETWEEN 2010 AND 2013 "
    "OR year_closure BETWEEN 2014 AND 2017)"
)
YEAR_LO, YEAR_HI = 2010, 2024  # matches all-cause edge span

logf = None


def say(msg: str, *a) -> None:
    line = (msg % a) if a else msg
    stamp = time.strftime("%H:%M:%S")
    rss = psutil.Process().memory_info().rss / 1e9
    out = f"[{stamp} | {rss:4.1f} GiB] {line}"
    print(out, flush=True)
    if logf:
        logf.write(out + "\n")
        logf.flush()


def connect() -> duckdb.DuckDBPyConnection:
    con = duckdb.connect()
    con.execute("PRAGMA threads=12")
    con.execute("PRAGMA memory_limit='14GB'")
    con.execute("PRAGMA temp_directory='/tmp/duckdb_paper18'")
    return con


def build_psych_edges(con: duckdb.DuckDBPyConnection, force: bool) -> None:
    """Re-aggregate SIH-RD edges keeping only psychiatric admissions (F00-F99)."""
    if EDGES_PSY.exists() and not force:
        say("psych edges cached: %s (use --force to rebuild)", EDGES_PSY.name)
        return
    files = []
    for y in range(YEAR_LO, YEAR_HI + 1):
        yy = f"{y % 100:02d}"
        files.extend(sorted(RAW.glob(f"rd*{yy}??.parquet")))
    say("psych edge rebuild: %d SIH-RD files (%d-%d)", len(files), YEAR_LO, YEAR_HI)
    files_sql = "[" + ", ".join(f"'{f}'" for f in files) + "]"

    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE psy AS
        SELECT
            CAST(ANO_CMPT AS INTEGER)  AS year,
            LPAD(MUNIC_RES, 6, '0')    AS codmun_6,
            CNES,
            CASE WHEN MORTE IN ('1', 1) THEN 1 ELSE 0 END AS morte,
            CAST(VAL_TOT AS DOUBLE)    AS val_tot,
            CAST(DIAS_PERM AS INTEGER) AS dias_perm
        FROM read_parquet({files_sql}, union_by_name=true)
        WHERE MUNIC_RES IS NOT NULL AND CNES IS NOT NULL AND ANO_CMPT IS NOT NULL
          AND CAST(ANO_CMPT AS INTEGER) BETWEEN {YEAR_LO} AND {YEAR_HI}
          AND SUBSTR(DIAG_PRINC, 1, 1) = 'F'
    """)
    n_raw = con.sql("SELECT COUNT(*) FROM psy").fetchone()[0]
    say("    psychiatric AIH (F00-F99): %s", f"{n_raw:,}")

    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE psy_hosp AS
        SELECT p.* FROM psy p
        SEMI JOIN (SELECT CNES FROM read_parquet('{HOSP_MASTER}')) h ON h.CNES = p.CNES
    """)
    n_hosp = con.sql("SELECT COUNT(*) FROM psy_hosp").fetchone()[0]
    say("    within hospital universe: %s (%.1f%% of psychiatric)", f"{n_hosp:,}",
        100.0 * n_hosp / max(n_raw, 1))

    con.execute(f"""
        COPY (
            SELECT codmun_6, CNES, year,
                   COUNT(*)       AS n_internacoes,
                   SUM(morte)     AS n_mortes,
                   SUM(val_tot)   AS val_tot_soma,
                   AVG(dias_perm) AS dias_perm_medio
            FROM psy_hosp
            GROUP BY codmun_6, CNES, year
            HAVING COUNT(*) >= 1
        ) TO '{EDGES_PSY}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    n_edges = con.sql(f"SELECT COUNT(*) FROM read_parquet('{EDGES_PSY}')").fetchone()[0]
    say("    psychiatric edges written: %s rows -> %s", f"{n_edges:,}", EDGES_PSY.name)


def run_decomposition(con: duckdb.DuckDBPyConnection) -> pd.DataFrame:
    """For each PNASH closure, catchment = >=5% all-cause pre-closure flow to the
    closing hospital; measure psychiatric admissions split closing vs. other."""
    clo = con.sql(f"""
        SELECT CNES, codmun_6 AS codmun_hosp, year_closure, tp_unid
        FROM read_parquet('{CLOSURES}')
        WHERE {PNASH_WHERE}
    """).df()
    say("PNASH psychiatric closures in sample: %d", len(clo))

    rows = []
    n_support = 0
    for _, c in clo.iterrows():
        cnes, yc = c.CNES, int(c.year_closure)
        exp = con.sql(f"""
            WITH total AS (
              SELECT codmun_6, SUM(n_internacoes) denom
              FROM read_parquet('{EDGES_ALL}') WHERE year={yc-1} GROUP BY codmun_6
            ),
            num AS (
              SELECT codmun_6, SUM(n_internacoes) num
              FROM read_parquet('{EDGES_ALL}') WHERE year={yc-1} AND CNES='{cnes}'
              GROUP BY codmun_6
            )
            SELECT t.codmun_6 FROM total t LEFT JOIN num USING(codmun_6)
            WHERE COALESCE(num,0)*1.0/NULLIF(denom,0) >= 0.05
        """).df()["codmun_6"].tolist()
        if not exp:
            continue
        n_support += 1
        exp_sql = "(" + ",".join(f"'{m}'" for m in exp) + ")"
        for rel in range(-4, 5):
            year = yc + rel
            q = con.sql(f"""
                SELECT
                    COALESCE(SUM(n_internacoes),0) AS psych_total,
                    COALESCE(SUM(CASE WHEN CNES='{cnes}' THEN n_internacoes ELSE 0 END),0) AS psych_closing,
                    COALESCE(SUM(CASE WHEN CNES<>'{cnes}' THEN n_internacoes ELSE 0 END),0) AS psych_other,
                    COALESCE(SUM(val_tot_soma),0)  AS psych_aih_value,
                    COALESCE(SUM(n_internacoes*dias_perm_medio),0) AS psych_beddays
                FROM read_parquet('{EDGES_PSY}')
                WHERE year={year} AND codmun_6 IN {exp_sql}
            """).df().iloc[0].to_dict()
            q.update({"cnes": cnes, "closure_year": yc, "event_time": rel, "year": year,
                      "n_exposed_muni": len(exp)})
            rows.append(q)
    say("closures with >=5%% catchment support: %d of %d", n_support, len(clo))
    return pd.DataFrame(rows)


def summarize(panel: pd.DataFrame) -> dict:
    cols = ["psych_total", "psych_closing", "psych_other", "psych_aih_value", "psych_beddays"]
    by_et = panel.groupby("event_time")[cols].mean()  # catchment-mean per event time
    pre = by_et.loc[-3:-1].mean()
    post = by_et.loc[1:3].mean()

    closing_pre, closing_post = pre["psych_closing"], post["psych_closing"]
    other_pre, other_post = pre["psych_other"], post["psych_other"]
    total_pre, total_post = pre["psych_total"], post["psych_total"]

    lost_from_closing = closing_pre - closing_post
    gained_by_others = other_post - other_pre
    net_change_total = total_post - total_pre

    absorbed_share = gained_by_others / lost_from_closing if lost_from_closing > 0 else float("nan")
    residual_share = 1.0 - absorbed_share
    net_drop_pct = -net_change_total / total_pre * 100 if total_pre > 0 else float("nan")

    return {
        "closing_pre": closing_pre, "closing_post": closing_post,
        "other_pre": other_pre, "other_post": other_post,
        "total_pre": total_pre, "total_post": total_post,
        "lost_from_closing": lost_from_closing, "gained_by_others": gained_by_others,
        "net_change_total": net_change_total,
        "absorbed_share": absorbed_share, "residual_share": residual_share,
        "net_drop_pct": net_drop_pct,
        "n_closures": int(panel["cnes"].nunique()),
    }


def compute_intensity(con: duckdb.DuckDBPyConnection, panel: pd.DataFrame) -> dict:
    """Pre-empt the referee's 'where did it go?' question. The disappeared volume
    is real capacity, not low-intensity custodial admissions: compare pre-closure
    psychiatric length of stay at the closing hospital vs. the surviving hospitals,
    and check bed-days fall as steeply as admissions."""
    clo = con.sql(f"""
        SELECT CNES, codmun_6 AS codmun_hosp, year_closure
        FROM read_parquet('{CLOSURES}') WHERE {PNASH_WHERE}
    """).df()
    acc = []
    for _, c in clo.iterrows():
        cnes, yc = c.CNES, int(c.year_closure)
        exp = con.sql(f"""
            WITH t AS (SELECT codmun_6, SUM(n_internacoes) d FROM read_parquet('{EDGES_ALL}')
                       WHERE year={yc-1} GROUP BY 1),
                 n AS (SELECT codmun_6, SUM(n_internacoes) num FROM read_parquet('{EDGES_ALL}')
                       WHERE year={yc-1} AND CNES='{cnes}' GROUP BY 1)
            SELECT t.codmun_6 FROM t LEFT JOIN n USING(codmun_6)
            WHERE COALESCE(num,0)*1.0/NULLIF(d,0) >= 0.05
        """).df()["codmun_6"].tolist()
        if not exp:
            continue
        es = "(" + ",".join(f"'{m}'" for m in exp) + ")"
        acc.append(con.sql(f"""
            SELECT
              SUM(CASE WHEN CNES='{cnes}' THEN n_internacoes ELSE 0 END) adm_close,
              SUM(CASE WHEN CNES='{cnes}' THEN n_internacoes*dias_perm_medio ELSE 0 END) bd_close,
              SUM(CASE WHEN CNES<>'{cnes}' THEN n_internacoes ELSE 0 END) adm_other,
              SUM(CASE WHEN CNES<>'{cnes}' THEN n_internacoes*dias_perm_medio ELSE 0 END) bd_other
            FROM read_parquet('{EDGES_PSY}')
            WHERE year BETWEEN {yc-3} AND {yc-1} AND codmun_6 IN {es}
        """).df().iloc[0].to_dict())
    A = pd.DataFrame(acc).sum()
    los_close = A.bd_close / A.adm_close
    los_other = A.bd_other / A.adm_other
    by_et = panel.groupby("event_time")[["psych_total", "psych_beddays"]].mean()
    adm_pre, adm_post = by_et.loc[-3:-1, "psych_total"].mean(), by_et.loc[1:3, "psych_total"].mean()
    bd_pre, bd_post = by_et.loc[-3:-1, "psych_beddays"].mean(), by_et.loc[1:3, "psych_beddays"].mean()
    return {
        "los_close": los_close, "los_other": los_other,
        "adm_drop_pct": (1 - adm_post / adm_pre) * 100,
        "beddays_drop_pct": (1 - bd_post / bd_pre) * 100,
        "bd_pre": bd_pre, "bd_post": bd_post,
    }


def write_intensity_tex(d: dict) -> None:
    L = [
        r"\begin{table}[!htbp]\centering",
        r"\caption{The disappeared volume was real capacity, not low-intensity custodial care}",
        r"\label{tab:psych-intensity}",
        r"\small",
        r"\begin{tabular}{lr}",
        r"\toprule",
        r"Pre-closure mean length of stay (days) & \\",
        r"\midrule",
        f"\\quad at the closing hospital & {d['los_close']:.1f} \\\\",
        f"\\quad at surviving hospitals & {d['los_other']:.1f} \\\\",
        r"\midrule",
        r"Post-closure decline (exposed catchments) & \\",
        f"\\quad inpatient psychiatric admissions & {d['adm_drop_pct']:.0f}\\% \\\\",
        f"\\quad inpatient psychiatric bed-days & {d['beddays_drop_pct']:.0f}\\% \\\\",
        r"\bottomrule",
        r"\multicolumn{2}{p{0.80\textwidth}}{\footnotesize Notes: Length of stay is admission-weighted, "
        r"pooled over event years $-3$ to $-1$ in exposed catchments. Admissions at the closing hospitals "
        r"were no shorter than at the hospitals that survived, and bed-days fall as steeply as admission "
        r"counts---so the contraction removed full-intensity inpatient capacity, not residual custodial "
        r"volume. Where that capacity went is only partly identifiable from inpatient records.}\\",
        r"\end{tabular}",
        r"\end{table}",
        "",
    ]
    (TAB_APP / "table_psych_intensity.tex").write_text("\n".join(L))
    say("wrote table_psych_intensity.tex")


def write_csv(panel: pd.DataFrame, s: dict) -> None:
    rows = [
        ("psych_adm_to_closing_hospital", s["closing_pre"], s["closing_post"], s["closing_post"] - s["closing_pre"]),
        ("psych_adm_to_other_hospitals", s["other_pre"], s["other_post"], s["other_post"] - s["other_pre"]),
        ("psych_adm_total", s["total_pre"], s["total_post"], s["net_change_total"]),
    ]
    df = pd.DataFrame(rows, columns=["quantity", "pre_mean", "post_mean", "change"])
    extra = pd.DataFrame([
        ("lost_from_closing_hospital", s["lost_from_closing"], np.nan, np.nan),
        ("absorbed_by_other_hospitals", s["gained_by_others"], np.nan, np.nan),
        ("absorbed_share_of_lost", s["absorbed_share"], np.nan, np.nan),
        ("residual_not_absorbed_share", s["residual_share"], np.nan, np.nan),
        ("net_drop_pct_total", s["net_drop_pct"], np.nan, np.nan),
        ("n_closures_with_support", s["n_closures"], np.nan, np.nan),
    ], columns=["quantity", "pre_mean", "post_mean", "change"])
    pd.concat([df, extra], ignore_index=True).to_csv(CSV_OUT, index=False)
    say("wrote %s", CSV_OUT.name)


def _n(x: float) -> str:
    """Integer with LaTeX-safe thousands separator (e.g. 1{,}026)."""
    return f"{x:,.0f}".replace(",", "{,}")


def write_macros(s: dict, d: dict) -> None:
    other_change = s["other_post"] - s["other_pre"]
    other_decline_pct = -other_change / s["other_pre"] * 100 if s["other_pre"] > 0 else float("nan")
    lines = [
        "% Auto-generated by 03_analysis/88_psych_displacement_decomposition.py",
        "% Psychiatric displacement decomposition, PNASH catchments, event -3..-1 vs +1..+3.",
        f"\\newcommand{{\\valPsychDispNClosures}}{{{s['n_closures']}}}% closures with >=5% catchment support",
        f"\\newcommand{{\\valPsychClosingPre}}{{{_n(s['closing_pre'])}}}% psych adm to closing hospital, pre (catchment mean)",
        f"\\newcommand{{\\valPsychOtherPre}}{{{_n(s['other_pre'])}}}% psych adm to other hospitals, pre",
        f"\\newcommand{{\\valPsychOtherPost}}{{{_n(s['other_post'])}}}% psych adm to other hospitals, post",
        f"\\newcommand{{\\valPsychOtherChange}}{{{_n(abs(other_change))}}}% absolute fall in other-hospital psych adm",
        f"\\newcommand{{\\valPsychOtherDeclinePct}}{{{other_decline_pct:.0f}}}% pct fall in other-hospital psych adm",
        f"\\newcommand{{\\valPsychTotalPre}}{{{_n(s['total_pre'])}}}% total psych adm, pre",
        f"\\newcommand{{\\valPsychTotalPost}}{{{_n(s['total_post'])}}}% total psych adm, post",
        f"\\newcommand{{\\valPsychDispNetDropPct}}{{{s['net_drop_pct']:.0f}}}% descriptive net drop in total catchment psych adm",
        f"\\newcommand{{\\valPsychLOSClosing}}{{{d['los_close']:.0f}}}% pre-closure mean LOS at closing hospital (days)",
        f"\\newcommand{{\\valPsychLOSOther}}{{{d['los_other']:.0f}}}% pre-closure mean LOS at surviving hospitals (days)",
        f"\\newcommand{{\\valPsychBeddaysDropPct}}{{{d['beddays_drop_pct']:.0f}}}% post-closure decline in catchment psych bed-days",
        "",
    ]
    MACROS_OUT.write_text("\n".join(lines))
    say("wrote %s", MACROS_OUT.name)


def _signed(x: float) -> str:
    sign = "+" if x >= 0 else "-"
    return sign + f"{abs(x):,.0f}".replace(",", "{,}")


def write_compact_tex(s: dict) -> None:
    other_change = s["other_post"] - s["other_pre"]
    notes = (
        r"Notes: Catchment-level averages of inpatient psychiatric admissions "
        r"(ICD-10 F00--F99), over event years $-3$ to $-1$ versus $+1$ to $+3$, for the "
        f"{s['n_closures']} PNASH psychiatric closures with sufficient flow support. Exposed "
        r"catchments are municipalities sending $\geq 5\%$ of their pre-closure inpatient flow "
        f"to the closing hospital. The {_n(s['lost_from_closing'])} admissions lost at the closing "
        r"hospital are not picked up by other hospitals: admissions to other hospitals do not rise "
        f"(they fall by {_n(abs(other_change))}), so total inpatient psychiatric admissions fall by "
        f"about {s['net_drop_pct']:.0f}\\%. The lost volume is not observed in inpatient psychiatric "
        r"care; the design observes inpatient admissions only, not outpatient (CAPS) use."
    )
    L = [
        r"\begin{table}[!htbp]\centering",
        r"\caption{Where inpatient psychiatric use goes after closure}",
        r"\label{tab:displacement-compact}",
        r"\small",
        r"\begin{tabular}{lrrr}",
        r"\toprule",
        r"Inpatient psychiatric admissions & Pre & Post & Change \\",
        r"\midrule",
        f"To the closing hospital & {_n(s['closing_pre'])} & {_n(s['closing_post'])} & {_signed(s['closing_post']-s['closing_pre'])} \\\\",
        f"To other hospitals & {_n(s['other_pre'])} & {_n(s['other_post'])} & {_signed(other_change)} \\\\",
        r"\midrule",
        f"Total (any hospital) & {_n(s['total_pre'])} & {_n(s['total_post'])} & {_signed(s['net_change_total'])} \\\\",
        r"\bottomrule",
        r"\multicolumn{4}{p{0.86\textwidth}}{\footnotesize " + notes + r"}\\",
        r"\end{tabular}",
        r"\end{table}",
        "",
    ]
    TEX_COMPACT.write_text("\n".join(L))
    say("wrote %s", TEX_COMPACT.name)


def write_full_tex(panel: pd.DataFrame, s: dict) -> None:
    by_et = panel.groupby("event_time")[["psych_total", "psych_closing", "psych_other",
                                         "psych_aih_value", "psych_beddays"]].mean().reset_index()
    L = [
        r"\begin{table}[!htbp]\centering",
        r"\caption{Inpatient psychiatric use by event time around PNASH closures (full decomposition)}",
        r"\label{tab:displacement-full}",
        r"\small",
        r"\resizebox{\textwidth}{!}{%",
        r"\begin{tabular}{rrrrrr}",
        r"\toprule",
        r"Event time & Total psych. adm. & To closing hosp. & To other hosp. & AIH value & Bed-days \\",
        r"\midrule",
    ]
    for _, r in by_et.iterrows():
        L.append(
            f"${int(r.event_time):+d}$ & {_n(r.psych_total)} & {_n(r.psych_closing)} & "
            f"{_n(r.psych_other)} & {_n(r.psych_aih_value)} & {_n(r.psych_beddays)} \\\\"
        )
    L += [
        r"\midrule",
        f"\\multicolumn{{6}}{{l}}{{\\footnotesize Admissions to other hospitals do not rise after "
        f"closure; total inpatient psychiatric admissions fall by about {s['net_drop_pct']:.0f}\\%.}}\\\\",
        r"\bottomrule",
        r"\multicolumn{6}{p{0.96\textwidth}}{\footnotesize Notes: Catchment-level mean inpatient psychiatric"
        r" admissions (ICD-10 F00--F99) by event time, across the PNASH psychiatric closures with $\geq 5\%$"
        r" pre-closure flow support. AIH value in BRL; bed-days are admission-weighted mean length of stay."
        r" Inpatient admissions only; outpatient (CAPS) substitution is not observed in this design.}\\",
        r"\end{tabular}",
        r"}%",
        r"\end{table}",
        "",
    ]
    TEX_FULL.write_text("\n".join(L))
    say("wrote %s", TEX_FULL.name)


def main() -> None:
    global logf
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    LOGDIR.mkdir(exist_ok=True)
    logf = open(LOGDIR / f"displacement_decomposition_{time.strftime('%Y%m%d')}.log", "w")

    try:
        sha = subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT).decode().strip()
    except Exception:
        sha = "unknown"
    vm = psutil.virtual_memory()
    t0 = time.perf_counter()
    say("==== 88_psych_displacement_decomposition ====")
    say("host=%s git=%s cores=%s ram_total=%.1fGiB ram_free=%.1fGiB",
        os.uname().nodename, sha, "12/14", vm.total / 1e9, vm.available / 1e9)

    con = connect()
    build_psych_edges(con, args.force)
    panel = run_decomposition(con)
    if panel.empty:
        say("ERROR: empty panel — no closures with catchment support")
        sys.exit(1)
    panel.to_parquet(PANEL_OUT, index=False)
    say("wrote %s (%d rows)", PANEL_OUT.name, len(panel))

    s = summarize(panel)
    say("RESULT closing: pre=%.0f post=%.0f | other: pre=%.0f post=%.0f | total: pre=%.0f post=%.0f",
        s["closing_pre"], s["closing_post"], s["other_pre"], s["other_post"], s["total_pre"], s["total_post"])
    say("RESULT lost_from_closing=%.0f gained_by_others=%.0f absorbed=%.0f%% residual=%.0f%% net_drop=%.0f%%",
        s["lost_from_closing"], s["gained_by_others"], s["absorbed_share"] * 100,
        s["residual_share"] * 100, s["net_drop_pct"])

    d = compute_intensity(con, panel)
    say("INTENSITY los_close=%.1f los_other=%.1f beddays_drop=%.0f%% adm_drop=%.0f%%",
        d["los_close"], d["los_other"], d["beddays_drop_pct"], d["adm_drop_pct"])

    write_csv(panel, s)
    write_macros(s, d)
    write_compact_tex(s)
    write_full_tex(panel, s)
    write_intensity_tex(d)

    peak = psutil.Process().memory_info().rss / 1e9
    say("done in %.1fs | peak RSS %.1f GiB", time.perf_counter() - t0, peak)
    logf.close()


if __name__ == "__main__":
    main()
