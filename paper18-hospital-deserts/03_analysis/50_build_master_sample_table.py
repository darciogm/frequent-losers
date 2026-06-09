from __future__ import annotations

import math
from pathlib import Path

import duckdb
import numpy as np
import pandas as pd

from revision_utils import (
    INTER,
    NOTES,
    PROC,
    ROOT,
    TAB,
    begin_log,
    end_log,
    ensure_dirs,
    latex_escape,
    logger_for,
    parse_args,
    require_force,
    write_text,
)


SCRIPT = "50_build_master_sample_table"
SAMPLE_OUT = PROC / "master_sample_table.parquet"
SAMPLE_CSV = TAB / "master_sample_table.csv"
SAMPLE_TEX = TAB / "master_sample_table.tex"
EVENT_OUT = PROC / "pnash_event_level_dataset.parquet"
EVENT_TEX = TAB / "table_event_level_pnash.tex"
PRED_TEX = TAB / "table_preclosure_predictors.tex"
BAL_TEX = TAB / "table_balance_true_preperiod.tex"
GAPS = NOTES / "VARIABLE_GAPS.md"

PNASH_EXPR = (
    "(year_closure BETWEEN 2006 AND 2009 OR year_closure BETWEEN 2010 AND 2013 "
    "OR year_closure BETWEEN 2014 AND 2017)"
)

SAMPLES = [
    {
        "sample_id": "pnash48",
        "sample_label": "PNASH psychiatric closures",
        "closure_filter_definition": "F1-F4 psychiatric specialized closures within one PNASH cycle window; F5 demand-decline filter relaxed.",
        "where": f"f1_window AND f2_type AND f3_beds AND f4_mass AND tp_unid='07' AND {PNASH_EXPR}",
        "years_used": "2010-2024 outcomes; PNASH windows 2006-2009, 2010-2013, 2014-2017",
        "facility_types": "CNES tp_unid=07 specialized hospitals",
        "pnash_anchored": "yes",
        "used_as_main_result_or_robustness": "main result",
        "output_file_names_where_sample_appears": "staggered_panel_pnash48_ext.parquet; tab_mortality_null.tex; fig_es_mortality.pdf",
        "panel": INTER / "staggered_panel_pnash48_ext.parquet",
    },
    {
        "sample_id": "spec07",
        "sample_label": "Specialized exogenous closures",
        "closure_filter_definition": "F1-F5 statistically filtered specialized closures.",
        "where": "exogenous AND tp_unid='07'",
        "years_used": "2010-2024 outcomes",
        "facility_types": "CNES tp_unid=07 specialized hospitals",
        "pnash_anchored": "no",
        "used_as_main_result_or_robustness": "robustness",
        "output_file_names_where_sample_appears": "staggered_panel_spec07_ext.parquet; tab_mortality_null.tex",
        "panel": INTER / "staggered_panel_spec07_ext.parquet",
    },
    {
        "sample_id": "psymax60",
        "sample_label": "All psychiatric closures",
        "closure_filter_definition": "F1-F4 psychiatric specialized closures; F5 demand-decline filter relaxed.",
        "where": "f1_window AND f2_type AND f3_beds AND f4_mass AND tp_unid='07'",
        "years_used": "2010-2024 outcomes",
        "facility_types": "CNES tp_unid=07 specialized hospitals",
        "pnash_anchored": "no",
        "used_as_main_result_or_robustness": "robustness",
        "output_file_names_where_sample_appears": "staggered_panel_psymax60_ext.parquet; tab_mortality_null.tex",
        "panel": INTER / "staggered_panel_psymax60_ext.parquet",
    },
    {
        "sample_id": "F5_main",
        "sample_label": "Broad exogenous closures",
        "closure_filter_definition": "F1-F5 full statistically filtered hospital-closure sample.",
        "where": "exogenous",
        "years_used": "2010-2024 outcomes",
        "facility_types": "General, specialized, day, and mixed hospitals passing F1-F5",
        "pnash_anchored": "no",
        "used_as_main_result_or_robustness": "legacy/secondary",
        "output_file_names_where_sample_appears": "staggered_panel_F5_main.parquet; legacy robustness tables",
        "panel": INTER / "staggered_panel_F5_main.parquet",
    },
]


def nearest_pnash(year: int) -> tuple[str, int, bool]:
    cycles = {
        "2002-2003": 2003,
        "2007-2008": 2008,
        "2011-2012": 2012,
        "2015-2016": 2016,
    }
    label, anchor = min(cycles.items(), key=lambda kv: abs(year - kv[1]))
    diff = year - anchor
    return label, diff, abs(diff) <= 1


def exposure_pairs(con: duckdb.DuckDBPyConnection, where: str) -> pd.DataFrame:
    closures = con.sql(f"""
        SELECT CNES, year_closure
        FROM read_parquet('{INTER / "hospital_closures_exogenous.parquet"}')
        WHERE {where}
    """).df()
    rows = []
    edges = INTER / "bipartite_edges.parquet"
    for _, row in closures.iterrows():
        year_pre = int(row.year_closure) - 1
        cnes = row.CNES
        q = f"""
            WITH total AS (
                SELECT codmun_6, SUM(n_internacoes) AS denom
                FROM read_parquet('{edges}')
                WHERE year={year_pre}
                GROUP BY codmun_6
            ),
            to_h AS (
                SELECT codmun_6, SUM(n_internacoes) AS num
                FROM read_parquet('{edges}')
                WHERE year={year_pre} AND CNES='{cnes}'
                GROUP BY codmun_6
            )
            SELECT '{cnes}' AS CNES, {int(row.year_closure)} AS year_closure,
                   t.codmun_6, COALESCE(h.num, 0) AS numerator,
                   t.denom AS denominator,
                   COALESCE(h.num, 0) * 1.0 / NULLIF(t.denom, 0) AS share
            FROM total t LEFT JOIN to_h h USING (codmun_6)
            WHERE COALESCE(h.num, 0) > 0
        """
        rows.append(con.sql(q).df())
    if not rows:
        return pd.DataFrame(columns=["CNES", "year_closure", "codmun_6", "numerator", "denominator", "share"])
    return pd.concat(rows, ignore_index=True)


def panel_treated_munis(panel_path: Path) -> int | None:
    if not panel_path.exists():
        return None
    df = pd.read_parquet(panel_path, columns=["codmun_6", "g_emb"])
    return int(df.loc[df["g_emb"].fillna(0) > 0, "codmun_6"].nunique())


def build_sample_table(con: duckdb.DuckDBPyConnection) -> pd.DataFrame:
    rows = []
    for sample in SAMPLES:
        clo = con.sql(f"""
            SELECT CNES, codmun_6, year_closure, tp_unid
            FROM read_parquet('{INTER / "hospital_closures_exogenous.parquet"}')
            WHERE {sample['where']}
        """).df()
        exp = exposure_pairs(con, sample["where"])
        exp_treated = exp.loc[exp["share"] >= 0.05].copy()
        treated_panel = panel_treated_munis(sample["panel"])
        rows.append({
            "sample_id": sample["sample_id"],
            "sample_label": sample["sample_label"],
            "closure_filter_definition": sample["closure_filter_definition"],
            "number_of_closure_events": int(len(clo)),
            "number_of_unique_CNES_hospitals": int(clo["CNES"].nunique()),
            "number_of_municipality_closure_pairs": int(len(exp_treated)),
            "number_of_unique_treated_municipalities": int(
                treated_panel if treated_panel is not None else exp_treated["codmun_6"].nunique()
            ),
            "years_used": sample["years_used"],
            "facility_types": sample["facility_types"],
            "PNASH_anchored": sample["pnash_anchored"],
            "used_as_main_result_or_robustness": sample["used_as_main_result_or_robustness"],
            "output_file_names_where_sample_appears": sample["output_file_names_where_sample_appears"],
        })
    return pd.DataFrame(rows)


def write_sample_tex(df: pd.DataFrame) -> None:
    lines = [
        "\\begin{table}[!htbp]\\centering",
        "\\caption{Master sample definitions}",
        "\\label{tab:master-sample-table}",
        "\\scriptsize",
        "\\resizebox{\\textwidth}{!}{%",
        "\\begin{tabular}{p{0.15\\textwidth}p{0.25\\textwidth}rrrrp{0.16\\textwidth}p{0.12\\textwidth}}",
        "\\toprule",
        "Sample & Definition & Events & CNES & Pairs & Munis & Role & PNASH \\\\",
        "\\midrule",
    ]
    for _, r in df.iterrows():
        lines.append(
            f"{latex_escape(r.sample_label)} & {latex_escape(r.closure_filter_definition)} & "
            f"{int(r.number_of_closure_events)} & {int(r.number_of_unique_CNES_hospitals)} & "
            f"{int(r.number_of_municipality_closure_pairs)} & {int(r.number_of_unique_treated_municipalities)} & "
            f"{latex_escape(r.used_as_main_result_or_robustness)} & {latex_escape(r.PNASH_anchored)} \\\\"
        )
    lines.extend([
        "\\bottomrule",
        "\\multicolumn{8}{p{0.94\\textwidth}}{\\footnotesize Notes: municipality--closure pairs use the patient-flow exposure rule with threshold $\\theta=0.05$. The main sample is PNASH psychiatric closures; other rows are secondary robustness samples.}\\\\",
        "\\end{tabular}",
        "}%",
        "\\end{table}",
    ])
    write_text(SAMPLE_TEX, "\n".join(lines) + "\n")


def build_event_dataset(con: duckdb.DuckDBPyConnection) -> pd.DataFrame:
    main = next(s for s in SAMPLES if s["sample_id"] == "pnash48")
    clo = con.sql(f"""
        SELECT CNES, codmun_6 AS municipality, year_closure AS closure_year,
               tp_unid AS facility_type, qt_sus_pre, n_int_t_minus_1,
               n_int_avg_3y_pre, ratio_pre
        FROM read_parquet('{INTER / "hospital_closures_exogenous.parquet"}')
        WHERE {main['where']}
    """).df()
    for col in ["nearest_pnash_cycle", "years_from_nearest_pnash_cycle", "within_pm1_year_of_pnash_cycle"]:
        clo[col] = None
    for i, row in clo.iterrows():
        label, diff, pm1 = nearest_pnash(int(row.closure_year))
        clo.loc[i, "nearest_pnash_cycle"] = label
        clo.loc[i, "years_from_nearest_pnash_cycle"] = diff
        clo.loc[i, "within_pm1_year_of_pnash_cycle"] = bool(pm1)
    clo["pre_closure_admissions_level"] = clo["n_int_t_minus_1"]
    clo["pre_closure_total_admissions_3y_avg"] = clo["n_int_avg_3y_pre"]
    clo["pre_closure_psychiatric_admissions"] = np.nan
    clo["pre_closure_psychiatric_beddays"] = np.nan
    clo["pre_closure_caps_coverage_hospital_municipality"] = np.nan
    clo["pre_closure_fhs_primary_care_coverage"] = np.nan
    clo["pre_closure_private_insurance_penetration"] = np.nan
    clo["pre_closure_municipal_gdp"] = np.nan
    clo["pre_closure_population"] = np.nan
    clo["pre_closure_suicide_rate_exposed_catchment"] = np.nan
    clo["pre_closure_selfharm_rate_exposed_catchment"] = np.nan

    pop = INTER / "pop_municipal_2015_2025.parquet"
    pib = INTER / "pib_municipal_2015_2023.parquet"
    psych = INTER / "psych_outcomes_panel.parquet"
    if pop.exists() and pib.exists():
        cov = con.sql(f"""
            SELECT SUBSTR(p.cod_mun, 1, 6) AS municipality, p.ano AS year,
                   p.pop AS pop, b.pib_corr AS pib_corr
            FROM read_parquet('{pop}') p
            LEFT JOIN read_parquet('{pib}') b
              ON SUBSTR(p.cod_mun, 1, 6)=SUBSTR(b.cod_mun, 1, 6) AND p.ano=b.ano
        """).df()
        for i, row in clo.iterrows():
            pre = cov[(cov["municipality"] == row.municipality) & (cov["year"] < row.closure_year)]
            if not pre.empty:
                last = pre.sort_values("year").iloc[-1]
                clo.loc[i, "pre_closure_population"] = last["pop"]
                clo.loc[i, "pre_closure_municipal_gdp"] = last["pib_corr"]
    if psych.exists():
        exp = exposure_pairs(con, main["where"])
        exp = exp[exp["share"] >= 0.05]
        psy = pd.read_parquet(psych, columns=["codmun_6", "year", "suicide_per100k", "selfharm_per100k"])
        for i, row in clo.iterrows():
            catch = exp[(exp["CNES"] == row.CNES) & (exp["year_closure"] == row.closure_year)]["codmun_6"]
            pre = psy[(psy["codmun_6"].isin(catch)) & (psy["year"].between(row.closure_year - 5, row.closure_year - 1))]
            clo.loc[i, "pre_closure_suicide_rate_exposed_catchment"] = pre["suicide_per100k"].mean()
            clo.loc[i, "pre_closure_selfharm_rate_exposed_catchment"] = pre["selfharm_per100k"].mean()
    return clo


def write_event_tex(df: pd.DataFrame) -> None:
    summary = df.groupby(["nearest_pnash_cycle", "within_pm1_year_of_pnash_cycle"], dropna=False).size().reset_index(name="events")
    lines = [
        "\\begin{table}[!htbp]\\centering",
        "\\caption{PNASH timing of main-sample psychiatric closures}",
        "\\label{tab:event-level-pnash}",
        "\\small",
        "\\begin{tabular}{lrr}",
        "\\toprule",
        "Nearest PNASH cycle & Within $\\pm 1$ year & Closure events \\\\",
        "\\midrule",
    ]
    for _, r in summary.iterrows():
        lines.append(f"{latex_escape(r.nearest_pnash_cycle)} & {latex_escape(r.within_pm1_year_of_pnash_cycle)} & {int(r.events)} \\\\")
    lines.extend([
        "\\bottomrule",
        "\\multicolumn{3}{p{0.76\\textwidth}}{\\footnotesize Notes: the event-level dataset also reports pre-closure admissions, population, GDP when available, and pre-closure suicide/self-harm rates in exposed catchments.}\\\\",
        "\\end{tabular}",
        "\\end{table}",
    ])
    write_text(EVENT_TEX, "\n".join(lines) + "\n")


def slope(y: pd.Series, x: pd.Series) -> float:
    good = y.notna() & x.notna()
    if good.sum() < 3:
        return np.nan
    xv = x[good].to_numpy(dtype=float)
    yv = y[good].to_numpy(dtype=float)
    xv = xv - xv.mean()
    den = float(np.dot(xv, xv))
    return float(np.dot(xv, yv - yv.mean()) / den) if den > 0 else np.nan


def predictor_tests() -> pd.DataFrame:
    panel = pd.read_parquet(INTER / "staggered_panel_pnash48_ext.parquet")
    outcomes = ["suicide_per100k", "selfharm_per100k", "travel_burden_km", "icsap_per1k"]
    rows = []
    treated = panel[panel["g_emb"].fillna(0) > 0].copy()
    for outcome in outcomes:
        by = []
        for muni, grp in treated.groupby("codmun_6"):
            g = int(grp["g_emb"].max())
            pre = grp[(grp["year"] >= g - 5) & (grp["year"] <= g - 1)]
            by.append({
                "codmun_6": muni,
                "closure_cohort": g,
                "baseline_level": pre[outcome].mean(),
                "pretrend_slope": slope(pre[outcome], pre["year"]),
            })
        d = pd.DataFrame(by).dropna()
        if len(d) >= 5 and d["pretrend_slope"].std() > 0:
            corr = float(np.corrcoef(d["closure_cohort"], d["pretrend_slope"])[0, 1])
            early = d["closure_cohort"] <= d["closure_cohort"].median()
            diff = float(d.loc[early, "pretrend_slope"].mean() - d.loc[~early, "pretrend_slope"].mean())
        else:
            corr, diff = np.nan, np.nan
        rows.append({
            "outcome": outcome,
            "n_municipalities": int(len(d)),
            "mean_pretrend_slope": d["pretrend_slope"].mean() if len(d) else np.nan,
            "corr_slope_with_closure_cohort": corr,
            "early_minus_late_slope": diff,
        })
    return pd.DataFrame(rows)


def write_predictor_tex(df: pd.DataFrame) -> None:
    labels = {
        "suicide_per100k": "Suicide mortality",
        "selfharm_per100k": "Self-harm mortality",
        "travel_burden_km": "Travel burden",
        "icsap_per1k": "ICSAP",
    }
    lines = [
        "\\begin{table}[!htbp]\\centering",
        "\\caption{Pre-closure trend predictors of closure cohort}",
        "\\label{tab:preclosure-predictors}",
        "\\small",
        "\\resizebox{\\textwidth}{!}{%",
        "\\begin{tabular}{lrrrr}",
        "\\toprule",
        "Outcome & Munis & Mean slope & Corr. with cohort & Early--late slope \\\\",
        "\\midrule",
    ]
    for _, r in df.iterrows():
        lines.append(
            f"{labels.get(r.outcome, r.outcome)} & {int(r.n_municipalities)} & "
            f"{r.mean_pretrend_slope:.3f} & {r.corr_slope_with_closure_cohort:.3f} & "
            f"{r.early_minus_late_slope:.3f} \\\\"
        )
    lines.extend([
        "\\bottomrule",
        "\\multicolumn{5}{p{0.86\\textwidth}}{\\footnotesize Notes: slopes are municipality-specific linear pre-trends over event years $-5$ to $-1$ when available. The table is a diagnostic for whether closure cohort is aligned with pre-existing outcome trends; it is not a proof of random timing.}\\\\",
        "\\end{tabular}",
        "}%",
        "\\end{table}",
    ])
    write_text(PRED_TEX, "\n".join(lines) + "\n")


def true_preperiod_balance() -> pd.DataFrame:
    panel = pd.read_parquet(INTER / "staggered_panel_pnash48_ext.parquet")
    panel["treated"] = panel["g_emb"].fillna(0) > 0
    rows = []
    covs = ["pop", "suicide_per100k", "selfharm_per100k", "travel_burden_km", "icsap_per1k"]
    for mode, mask in {
        "fixed 2010-2011 baseline": panel["year"].between(2010, 2011),
        "cohort-specific pre-period": panel["g_emb"].fillna(0).eq(0) | (panel["year"] < panel["g_emb"]),
    }.items():
        d = panel[mask].groupby(["codmun_6", "treated"], as_index=False)[covs].mean()
        for cov in covs:
            t = d.loc[d["treated"], cov].dropna()
            c = d.loc[~d["treated"], cov].dropna()
            pooled = math.sqrt((t.var(ddof=1) + c.var(ddof=1)) / 2) if len(t) > 1 and len(c) > 1 else np.nan
            rows.append({
                "baseline_definition": mode,
                "covariate": cov,
                "treated_mean": t.mean(),
                "control_mean": c.mean(),
                "standardized_difference": (t.mean() - c.mean()) / pooled if pooled and pooled > 0 else np.nan,
                "n_treated": int(len(t)),
                "n_control": int(len(c)),
            })
    return pd.DataFrame(rows)


def write_balance_tex(df: pd.DataFrame) -> None:
    labels = {
        "pop": "Population",
        "suicide_per100k": "Suicide rate",
        "selfharm_per100k": "Self-harm rate",
        "travel_burden_km": "Travel burden",
        "icsap_per1k": "ICSAP",
    }
    lines = [
        "\\begin{table}[!htbp]\\centering",
        "\\caption{Balance using true pre-treatment observations}",
        "\\label{tab:balance-true-preperiod}",
        "\\small",
        "\\resizebox{\\textwidth}{!}{%",
        "\\begin{tabular}{llrrrr}",
        "\\toprule",
        "Baseline & Covariate & Treated & Control & Std. diff. & Munis \\\\",
        "\\midrule",
    ]
    for _, r in df.iterrows():
        lines.append(
            f"{latex_escape(r.baseline_definition)} & {labels.get(r.covariate, r.covariate)} & "
            f"{r.treated_mean:.2f} & {r.control_mean:.2f} & {r.standardized_difference:+.3f} & "
            f"{int(r.n_treated)}/{int(r.n_control)} \\\\"
        )
    lines.extend([
        "\\bottomrule",
        "\\multicolumn{6}{p{0.9\\textwidth}}{\\footnotesize Notes: unlike the older 2015--2017 balance table, this table never labels post-treatment observations as pre-treatment for early cohorts.}\\\\",
        "\\end{tabular}",
        "}%",
        "\\end{table}",
    ])
    write_text(BAL_TEX, "\n".join(lines) + "\n")


def write_gaps() -> None:
    content = """# Variable Gaps For AEJ: Policy Revision

Generated by `03_analysis/50_build_master_sample_table.py` as a preliminary gap note.
Run `03_analysis/61_resolve_remaining_data_caveats.py --force` after this step;
that script rebuilds the locally resolvable SIH/CNES-ST variables and rewrites
this note with final status.
"""
    write_text(GAPS, content)


def main() -> None:
    args = parse_args("Build master sample table and PNASH identification diagnostics.")
    ensure_dirs()
    log = logger_for(SCRIPT)
    t0 = begin_log(log, SCRIPT)
    outputs = [SAMPLE_OUT, SAMPLE_CSV, SAMPLE_TEX, EVENT_OUT, EVENT_TEX, PRED_TEX, BAL_TEX, GAPS]
    if not require_force(outputs, args.force, log):
        return

    con = duckdb.connect()
    con.execute("PRAGMA threads=10")
    con.execute("PRAGMA memory_limit='12GB'")

    sample = build_sample_table(con)
    sample.to_parquet(SAMPLE_OUT, index=False)
    sample.to_csv(SAMPLE_CSV, index=False)
    write_sample_tex(sample)
    log.info("wrote master sample outputs")

    event = build_event_dataset(con)
    event.to_parquet(EVENT_OUT, index=False)
    write_event_tex(event)
    log.info("wrote PNASH event dataset rows=%d", len(event))

    pred = predictor_tests()
    write_predictor_tex(pred)
    bal = true_preperiod_balance()
    write_balance_tex(bal)
    write_gaps()
    log.info("wrote predictor, balance, and variable-gap outputs")
    end_log(log, t0)


if __name__ == "__main__":
    main()
