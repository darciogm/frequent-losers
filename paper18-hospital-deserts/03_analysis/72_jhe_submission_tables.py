from __future__ import annotations

import argparse
import datetime as dt
import math
import subprocess
import time
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from scipy import stats


ROOT = Path(__file__).resolve().parents[1]
PROC = ROOT / "02_data" / "processed"
INTER = ROOT / "02_data" / "intermediate"
TAB = ROOT / "01_manuscript" / "tables"
LOG = ROOT / "04_logs"
NOTES = ROOT / "notes"


def git_sha() -> str:
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=ROOT,
            text=True,
        ).strip()
    except Exception:
        return "unavailable"


def esc(x) -> str:
    s = "" if x is None else str(x)
    for a, b in [
        ("\\", r"\textbackslash{}"),
        ("&", r"\&"),
        ("%", r"\%"),
        ("$", r"\$"),
        ("#", r"\#"),
        ("_", r"\_"),
        ("{", r"\{"),
        ("}", r"\}"),
    ]:
        s = s.replace(a, b)
    return s


def fmt(x, digits=2, signed=False) -> str:
    if x is None or not np.isfinite(x):
        return "--"
    if signed:
        return f"{x:+.{digits}f}"
    return f"{x:.{digits}f}"


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def ttest_rows(df: pd.DataFrame, group: str, variables: list[tuple[str, str]]) -> list[dict]:
    rows = []
    for col, label in variables:
        d = df[[group, col]].replace([np.inf, -np.inf], np.nan).dropna()
        tr = d.loc[d[group], col].astype(float)
        co = d.loc[~d[group], col].astype(float)
        if len(tr) < 2 or len(co) < 2:
            continue
        mt, mc = tr.mean(), co.mean()
        sd = math.sqrt((tr.var(ddof=1) + co.var(ddof=1)) / 2)
        tt = stats.ttest_ind(tr, co, equal_var=False, nan_policy="omit")
        rows.append(
            {
                "covariate": label,
                "treated": mt,
                "control": mc,
                "std_diff": (mt - mc) / sd if sd > 0 else np.nan,
                "p_value": tt.pvalue,
                "n_treated": tr.size,
                "n_control": co.size,
            }
        )
    return rows


def build_balance_tables() -> None:
    panel = pd.read_parquet(PROC / "revision_pnash48_panel.parquet")
    panel["codmun_6"] = panel["codmun_6"].astype(str)
    panel["treated"] = panel["gn"].astype(int) < 10000
    panel["log_population"] = np.log(panel["pop"].where(panel["pop"] > 0))

    variables = [
        ("log_population", "Log population"),
        ("travel_burden_km", "Travel burden (km)"),
        ("suicide_per100k", "Suicide mortality"),
        ("selfharm_per100k", "Self-harm mortality"),
        ("psych_adm_per1k", "Psychiatric admissions"),
        ("n_psych_adm", "Psychiatric admission episodes"),
        ("icsap_per1k", "Preventable hospitalizations"),
    ]

    pre = panel[(panel["treated"] & (panel["year"] < panel["gn"])) | (~panel["treated"])].copy()
    # Never-treated municipalities receive a comparable reference window: the
    # union of years that enter treated municipalities' true pre-periods.
    treated_pre_years = set(panel.loc[panel["treated"] & (panel["year"] < panel["gn"]), "year"].astype(int))
    pre = pre[pre["treated"] | pre["year"].astype(int).isin(treated_pre_years)]
    pre_muni = pre.groupby(["codmun_6", "treated"], as_index=False)[[v[0] for v in variables]].mean()

    common = panel[panel["year"].between(2010, 2011)].copy()
    common_muni = common.groupby(["codmun_6", "treated"], as_index=False)[[v[0] for v in variables]].mean()

    rows_pre = ttest_rows(pre_muni, "treated", variables)
    rows_common = ttest_rows(common_muni, "treated", variables)

    out = pd.DataFrame(rows_pre)
    out.insert(0, "baseline", "cohort-specific true pre-period")
    out_common = pd.DataFrame(rows_common)
    out_common.insert(0, "baseline", "common 2010--2011")
    pd.concat([out, out_common], ignore_index=True).to_csv(
        PROC / "balance_pnash_true_preperiod.csv", index=False
    )

    def table(rows, caption, label, note):
        lines = [
            r"\begin{table}[!htbp]\centering",
            rf"\caption{{{caption}}}",
            rf"\label{{{label}}}",
            r"\small",
            r"\resizebox{\textwidth}{!}{%",
            r"\begin{tabular}{lrrrrr}",
            r"\toprule",
            r"Covariate & Treated & Control & Std. diff. & $p$-value & Munis \\",
            r"\midrule",
        ]
        for r in rows:
            lines.append(
                f"{esc(r['covariate'])} & {fmt(r['treated'])} & {fmt(r['control'])} & "
                f"{fmt(r['std_diff'], 3, signed=True)} & {fmt(r['p_value'], 3)} & "
                f"{int(r['n_treated'])}/{int(r['n_control'])} \\\\"
            )
        lines.extend(
            [
                r"\bottomrule",
                rf"\multicolumn{{6}}{{p{{0.94\textwidth}}}}{{\footnotesize Notes: {note}}}\\",
                r"\end{tabular}",
                r"}%",
                r"\end{table}",
                "",
            ]
        )
        return "\n".join(lines)

    write(
        TAB / "table_balance_pnash_true_preperiod.tex",
        table(
            rows_pre,
            "Pre-treatment balance in the PNASH psychiatric causal sample",
            "tab:balance-pnash-true-preperiod",
            "The table uses only observations strictly before exposure for treated municipalities. "
            "Never-treated municipalities are measured over the same calendar years that enter the treated pre-period support. "
            "The unit is the municipality. P-values are Welch two-sample tests.",
        ),
    )
    write(
        TAB / "table_balance_common_2010_2011.tex",
        table(
            rows_common,
            "Common-baseline balance, 2010--2011",
            "tab:balance-common-2010-2011",
            "The table uses a common 2010--2011 baseline for the PNASH psychiatric causal sample. "
            "It is an appendix check; the main balance table uses cohort-specific true pre-period observations.",
        ),
    )


def build_event_predictor_tables() -> None:
    ev = pd.read_parquet(PROC / "pnash_event_level_dataset.parquet")
    ev["early_closure"] = ev["closure_year"] <= ev["closure_year"].median()
    ev["pre_volume_decline_pct"] = 100 * (1 - ev["ratio_pre"])
    ev.to_parquet(PROC / "pnash_event_level_dataset.parquet", index=False)

    timing = (
        ev.groupby(["nearest_pnash_cycle", "within_pm1_year_of_pnash_cycle"], dropna=False)
        .agg(
            closures=("CNES", "count"),
            exposed_munis=("number_flow_exposed_municipalities", "sum")
            if "number_flow_exposed_municipalities" in ev.columns
            else ("CNES", "count"),
            mean_sus_beds=("qt_sus_pre", "mean"),
            mean_psych_adm=("pre_closure_psychiatric_admissions", "mean"),
            mean_psych_beddays=("pre_closure_psychiatric_beddays", "mean"),
            mean_predecline=("pre_volume_decline_pct", "mean"),
        )
        .reset_index()
    )
    lines = [
        r"\begin{table}[!htbp]\centering",
        r"\caption{PNASH timing and pre-closure hospital characteristics}",
        r"\label{tab:pnash-event-timing}",
        r"\small",
        r"\begin{tabular}{llrrrrr}",
        r"\toprule",
        r"Nearest PNASH cycle & Within $\pm 1$ year & Closures & SUS beds & Psych. AIH & Psych. bed-days & Pre-decline (\%) \\",
        r"\midrule",
    ]
    for _, r in timing.iterrows():
        lines.append(
            f"{esc(r['nearest_pnash_cycle'])} & {str(bool(r['within_pm1_year_of_pnash_cycle']))} & "
            f"{int(r['closures'])} & {fmt(r['mean_sus_beds'],1)} & {fmt(r['mean_psych_adm'],1)} & "
            f"{fmt(r['mean_psych_beddays'],1)} & {fmt(r['mean_predecline'],1)} \\\\"
        )
    lines.extend(
        [
            r"\bottomrule",
            r"\multicolumn{7}{p{0.92\textwidth}}{\footnotesize Notes: One row is a PNASH-anchored psychiatric closure. Pre-closure quantities are measured in the year before closure unless otherwise stated. The pre-decline statistic is $100\times(1-\mathrm{AIH}_{t-1}/\overline{\mathrm{AIH}}_{t-3:t-1})$, so positive values indicate falling admission volume before exit.}\\",
            r"\end{tabular}",
            r"\end{table}",
            "",
        ]
    )
    write(TAB / "table_pnash_event_timing.tex", "\n".join(lines))

    predictors = [
        ("pre_volume_decline_pct", "Pre-closure admission decline"),
        ("pre_closure_psychiatric_admissions", "Psychiatric AIH in t-1"),
        ("pre_closure_psychiatric_beddays", "Psychiatric bed-days in t-1"),
        ("pre_closure_psychiatric_aih_value", "Psychiatric AIH value in t-1"),
        ("pre_closure_suicide_rate_exposed_catchment", "Catchment suicide rate"),
        ("pre_closure_selfharm_rate_exposed_catchment", "Catchment self-harm rate"),
        ("pre_closure_caps_facilities_hospital_municipality", "CAPS facilities in hospital municipality"),
        ("pre_closure_admissions_level", "Total AIH in t-1"),
    ]
    rows = []
    for col, label in predictors:
        if col not in ev.columns:
            continue
        d = ev[["closure_year", "early_closure", col]].replace([np.inf, -np.inf], np.nan).dropna()
        if len(d) < 12 or d[col].nunique() < 2:
            continue
        x = stats.zscore(d[col].astype(float), nan_policy="omit")
        X = np.column_stack([np.ones(len(d)), x])
        y = d["closure_year"].astype(float).to_numpy()
        beta = np.linalg.lstsq(X, y, rcond=None)[0]
        resid = y - X @ beta
        sigma2 = (resid @ resid) / max(len(y) - X.shape[1], 1)
        vcov = sigma2 * np.linalg.inv(X.T @ X)
        se = math.sqrt(vcov[1, 1])
        p = 2 * stats.t.sf(abs(beta[1] / se), df=max(len(y) - X.shape[1], 1))
        tt = stats.ttest_ind(
            d.loc[d["early_closure"], col].astype(float),
            d.loc[~d["early_closure"], col].astype(float),
            equal_var=False,
        )
        rows.append(
            {
                "predictor": label,
                "coef": beta[1],
                "se": se,
                "p": p,
                "early_late_p": tt.pvalue,
                "n": len(d),
            }
        )
    pd.DataFrame(rows).to_csv(PROC / "preclosure_predictor_tests.csv", index=False)
    lines = [
        r"\begin{table}[!htbp]\centering",
        r"\caption{Do observed pre-closure characteristics predict PNASH closure timing?}",
        r"\label{tab:preclosure-predictor-tests}",
        r"\small",
        r"\begin{tabular}{lrrrr}",
        r"\toprule",
        r"Predictor & Coef. on closure year & SE & $p$-value & $N$ \\",
        r"\midrule",
    ]
    for r in rows:
        lines.append(
            f"{esc(r['predictor'])} & {fmt(r['coef'],2, signed=True)} & {fmt(r['se'],2)} & {fmt(r['p'],3)} & {int(r['n'])} \\\\"
        )
    lines.extend(
        [
            r"\bottomrule",
            r"\multicolumn{5}{p{0.86\textwidth}}{\footnotesize Notes: Each row is a separate closure-level regression of closure year on a standardized pre-closure predictor and a constant. The table is supportive rather than dispositive: the PNASH sample has 48 closures, and some administrative variables are unavailable.}\\",
            r"\end{tabular}",
            r"\end{table}",
            "",
        ]
    )
    write(TAB / "table_preclosure_predictor_tests.tex", "\n".join(lines))


def build_variant_and_distance_tables() -> None:
    res = pd.read_csv(PROC / "exposure_distance_variant_eventstudies.csv")
    key_flow = [
        "flow_all_admissions__yminus1__theta005",
        "flow_psych_admissions__yminus1__theta005",
        "flow_psych_beddays__yminus1__theta005",
        "flow_psych_aih_value__yminus1__theta005",
        "flow_all_admissions__avg_yminus3_to_yminus1__theta005",
        "flow_all_admissions__avg_yminus4_to_yminus2__theta005",
    ]
    labels = {
        "flow_all_admissions__yminus1__theta005": "Main all-SUS share, $t-1$",
        "flow_psych_admissions__yminus1__theta005": "Psychiatric AIH share, $t-1$",
        "flow_psych_beddays__yminus1__theta005": "Psychiatric bed-days share, $t-1$",
        "flow_psych_aih_value__yminus1__theta005": "Psychiatric AIH-value share, $t-1$",
        "flow_all_admissions__avg_yminus3_to_yminus1__theta005": "All-SUS share, avg. $t-3$ to $t-1$",
        "flow_all_admissions__avg_yminus4_to_yminus2__theta005": "All-SUS share, avg. $t-4$ to $t-2$",
    }
    rows = []
    for vid in key_flow:
        d = res[(res["variant_id"] == vid) & (res["outcome"].isin(["suicide_per100k", "selfharm_per100k", "travel_burden_km"]))]
        if d.empty:
            continue
        rec = {"label": labels[vid], "n": int(d["n_treated_municipalities"].dropna().iloc[0])}
        for out in ["travel_burden_km", "suicide_per100k", "selfharm_per100k"]:
            rr = d[d["outcome"] == out].iloc[0]
            rec[out] = rr
        rows.append(rec)
    lines = [
        r"\begin{table}[!htbp]\centering",
        r"\caption{Mortality and first-stage estimates under alternative flow-exposure definitions}",
        r"\label{tab:exposure-variant-mortality}",
        r"\scriptsize",
        r"\resizebox{\textwidth}{!}{%",
        r"\begin{tabular}{lrrrrrrr}",
        r"\toprule",
        r"Exposure definition & Treated munis & Travel ATT & Suicide ATT & 95\% CI & Self-harm ATT & 95\% CI & Status \\",
        r"\midrule",
    ]
    for r in rows:
        su = r["suicide_per100k"]
        sh = r["selfharm_per100k"]
        tr = r["travel_burden_km"]
        status = "ok" if su["status"] == "ok" and sh["status"] == "ok" else "not estimated"
        lines.append(
            f"{esc(r['label'])} & {r['n']} & {fmt(tr['att'],2, signed=True)} & "
            f"{fmt(su['att'],2, signed=True)} & [{fmt(su['lo'],2, signed=True)}, {fmt(su['hi'],2, signed=True)}] & "
            f"{fmt(sh['att'],2, signed=True)} & [{fmt(sh['lo'],2, signed=True)}, {fmt(sh['hi'],2, signed=True)}] & {esc(status)} \\\\"
        )
    lines.extend(
        [
            r"\bottomrule",
            r"\multicolumn{8}{p{0.96\textwidth}}{\footnotesize Notes: Each row re-estimates the PNASH event study using the indicated exposure rule at the 5 percent cutoff. Mortality estimates are population weighted; travel-burden estimates are unweighted. Psychiatric-specific denominators identify broader catchments because psychiatric admissions are sparse.}\\",
            r"\end{tabular}",
            r"}%",
            r"\end{table}",
            "",
        ]
    )
    write(TAB / "table_exposure_variant_mortality.tex", "\n".join(lines))

    key_dist = [
        "distance_top3_any_hospital__distance_exposed",
        "distance_top3_same_type__distance_exposed",
        "distance_top3_psych_hospital__distance_exposed",
        "distance_nearest_psych_bed__distance_exposed",
    ]
    dist_labels = {
        "distance_top3_any_hospital__distance_exposed": "Top 3 nearest any hospital",
        "distance_top3_same_type__distance_exposed": "Top 3 nearest same type",
        "distance_top3_psych_hospital__distance_exposed": "Top 3 nearest psychiatric provider",
        "distance_nearest_psych_bed__distance_exposed": "Nearest psychiatric provider",
    }
    lines = [
        r"\begin{table}[!htbp]\centering",
        r"\caption{Event-study estimates under distance-based exposure benchmarks}",
        r"\label{tab:distance-benchmark-results}",
        r"\small",
        r"\resizebox{\textwidth}{!}{%",
        r"\begin{tabular}{lrrrrrl}",
        r"\toprule",
        r"Distance benchmark & Treated munis & Controls & Travel ATT & Suicide ATT & Self-harm ATT & Status \\",
        r"\midrule",
    ]
    for vid in key_dist:
        d = res[res["variant_id"] == vid]
        if d.empty:
            continue
        m = d.iloc[0]
        vals = {o: d[d["outcome"] == o].iloc[0] for o in d["outcome"].unique()}
        tr = vals.get("travel_burden_km", m)
        su = vals.get("suicide_per100k", m)
        sh = vals.get("selfharm_per100k", m)
        status = su["status"]
        if status == "too few never-treated controls (<20)":
            status = "too few controls"
        lines.append(
            f"{esc(dist_labels.get(vid, vid))} & {int(m['n_treated_municipalities'])} & "
            f"{int(m['n_never_treated_municipalities'])} & {fmt(tr['att'],2, signed=True)} & "
            f"{fmt(su['att'],2, signed=True)} & {fmt(sh['att'],2, signed=True)} & {esc(status)} \\\\"
        )
    lines.extend(
        [
            r"\bottomrule",
            r"\multicolumn{7}{p{0.94\textwidth}}{\footnotesize Notes: Distance rules are benchmark exposure classifications. Some specialty-specific rules classify nearly every municipality as exposed in this national panel, leaving too few never-treated controls for a separate event-study estimate. This is reported as a support problem rather than hidden by dropping the benchmark.}\\",
            r"\end{tabular}",
            r"}%",
            r"\end{table}",
            "",
        ]
    )
    write(TAB / "table_distance_benchmark_results.tex", "\n".join(lines))


def build_mortality_scaling() -> None:
    scale = pd.read_csv(PROC / "mortality_scaling_mde_revision.csv")
    ev = pd.read_parquet(PROC / "pnash_event_level_dataset.parquet")
    beddays = ev["pre_closure_psychiatric_beddays"].sum(skipna=True)
    psych_adm = scale["baseline_psych_admissions_year"].iloc[0]
    scale["upper_deaths_per_year"] = scale["implied_deaths_hi"]
    scale["upper_deaths_per_1000_psych_admissions"] = scale["implied_deaths_hi"] / psych_adm * 1000
    scale["upper_deaths_per_1000_psych_beddays"] = scale["implied_deaths_hi"] / beddays * 1000
    scale.to_csv(PROC / "mortality_bounds_scaled.csv", index=False)
    lines = [
        r"\begin{table}[!htbp]\centering",
        r"\caption{Substantive scale of mortality bounds in the PNASH psychiatric sample}",
        r"\label{tab:mortality-bounds-scaled}",
        r"\small",
        r"\resizebox{\textwidth}{!}{%",
        r"\begin{tabular}{lrrrrrr}",
        r"\toprule",
        r"Outcome & ATT per 100k & 95\% CI & Baseline rate & Upper bound \% baseline & Upper deaths/year & Upper deaths per 1,000 psych. AIH \\",
        r"\midrule",
    ]
    for _, r in scale.iterrows():
        lines.append(
            f"{esc(r['outcome'])} & {fmt(r['att_per100k'],2, signed=True)} & "
            f"[{fmt(r['lo_per100k'],2, signed=True)}, {fmt(r['hi_per100k'],2, signed=True)}] & "
            f"{fmt(r['baseline_rate_per100k'],2)} & {fmt(r['upper_ci_percent_of_baseline'],1)} & "
            f"{fmt(r['upper_deaths_per_year'],1)} & {fmt(r['upper_deaths_per_1000_psych_admissions'],2)} \\\\"
        )
    lines.extend(
        [
            r"\bottomrule",
            r"\multicolumn{7}{p{0.94\textwidth}}{\footnotesize Notes: Upper deaths per year translates the upper endpoint of the 95 percent confidence interval into annual deaths using the exposed baseline population. Psychiatric AIH counts are episodes, not unique people. The bed-day denominator is available in the machine-readable output.}\\",
            r"\end{tabular}",
            r"}%",
            r"\end{table}",
            "",
        ]
    )
    write(TAB / "table_mortality_bounds_scaled.tex", "\n".join(lines))


def build_first_stage_decomposition() -> None:
    path = PROC / "first_stage_decomposition_panel.parquet"
    if not path.exists():
        return
    df = pd.read_parquet(path)
    outcomes = [
        ("total_admissions", "Total admissions"),
        ("admissions_to_closing_hospital", "Admissions to closing hospital"),
        ("admissions_to_substitute_hospitals", "Admissions to other hospitals"),
        ("admissions_in_hospital_municipality", "Admissions in hospital municipality"),
        ("admissions_outside_hospital_municipality", "Admissions outside hospital municipality"),
        ("beddays_proxy", "Bed-days"),
        ("aih_value", "AIH value"),
    ]
    rows = []
    for col, label in outcomes:
        d = df[["cnes", "event_time", col]].replace([np.inf, -np.inf], np.nan).dropna()
        if d.empty:
            continue
        pre = d[d["event_time"].between(-3, -1)][col].mean()
        post = d[d["event_time"].between(1, 3)][col].mean()
        rows.append({"label": label, "pre": pre, "post": post, "change": post - pre})
    lines = [
        r"\begin{table}[!htbp]\centering",
        r"\caption{First-stage decomposition around PNASH psychiatric closures}",
        r"\label{tab:first-stage-decomposition}",
        r"\small",
        r"\resizebox{\textwidth}{!}{%",
        r"\begin{tabular}{lrrr}",
        r"\toprule",
        r"Outcome & Pre mean & Post mean & Change \\",
        r"\midrule",
    ]
    for r in rows:
        lines.append(f"{esc(r['label'])} & {fmt(r['pre'],1)} & {fmt(r['post'],1)} & {fmt(r['change'],1, signed=True)} \\\\")
    n_closures = df.loc[df[[c for c, _ in outcomes]].notna().any(axis=1), "cnes"].nunique()
    lines.extend(
        [
            r"\bottomrule",
            rf"\multicolumn{{4}}{{p{{0.86\textwidth}}}}{{\footnotesize Notes: Entries are descriptive catchment-level averages over event years $-3$ to $-1$ and $+1$ to $+3$ for the {n_closures} PNASH closures with sufficient SIH edge support in the decomposition panel. The table separates the disappearance of admissions to the closing provider from redirection to other facilities and changes in aggregate utilization. It is a utilization decomposition, not a welfare measure.}}\\",
            r"\end{tabular}",
            r"}%",
            r"\end{table}",
            "",
        ]
    )
    write(TAB / "table_first_stage_decomposition.tex", "\n".join(lines))

    plot_df = (
        df.groupby("event_time", as_index=False)[
            ["admissions_to_closing_hospital", "admissions_to_substitute_hospitals", "total_admissions"]
        ]
        .mean()
        .sort_values("event_time")
    )
    fig, ax = plt.subplots(figsize=(7.0, 4.2))
    for col, label in [
        ("admissions_to_closing_hospital", "Closing hospital"),
        ("admissions_to_substitute_hospitals", "Other hospitals"),
        ("total_admissions", "Total admissions"),
    ]:
        ax.plot(plot_df["event_time"], plot_df[col], marker="o", linewidth=1.7, label=label)
    ax.axvline(0, color="black", linewidth=0.8, linestyle="--")
    ax.set_xlabel("Years relative to closure")
    ax.set_ylabel("Mean admissions from exposed catchments")
    ax.legend(frameon=False, ncol=1)
    ax.spines[["top", "right"]].set_visible(False)
    fig.tight_layout()
    fig.savefig(ROOT / "04_figures" / "fig_first_stage_decomposition_eventstudy.pdf")
    plt.close(fig)


def build_closure_influence_table() -> None:
    loo = pd.read_csv(PROC / "leave_one_closure_out_revision.csv")
    loo = loo[loo["closure_id"] != "baseline"].copy()
    rows = []
    for outcome, d in loo.groupby("outcome_label"):
        d = d.sort_values("abs_delta_att", ascending=False).head(5)
        for _, r in d.iterrows():
            rows.append(r)
    lines = [
        r"\begin{table}[!htbp]\centering",
        r"\caption{Most influential leave-one-closure-out estimates}",
        r"\label{tab:closure-influence}",
        r"\small",
        r"\begin{tabular}{llrrrr}",
        r"\toprule",
        r"Outcome & Omitted closure & Omitted munis & ATT & Change in ATT & 95\% CI \\",
        r"\midrule",
    ]
    for r in rows:
        lines.append(
            f"{esc(r['outcome_label'])} & {esc(r['closure_id'])} & {int(r['omitted_exposed_municipalities'])} & "
            f"{fmt(r['att'],2, signed=True)} & {fmt(r['delta_att'],2, signed=True)} & "
            f"[{fmt(r['lo'],2, signed=True)}, {fmt(r['hi'],2, signed=True)}] \\\\"
        )
    lines.extend(
        [
            r"\bottomrule",
            r"\multicolumn{6}{p{0.88\textwidth}}{\footnotesize Notes: Each row drops all municipalities exposed to the listed PNASH closure and re-estimates the population-weighted Sun--Abraham mortality effect. The table reports the five largest absolute changes in ATT for each outcome.}\\",
            r"\end{tabular}",
            r"\end{table}",
            "",
        ]
    )
    write(TAB / "table_closure_influence.tex", "\n".join(lines))


def update_variable_gaps() -> None:
    NOTES.mkdir(exist_ok=True)
    path = NOTES / "VARIABLE_GAPS.md"
    existing = path.read_text(encoding="utf-8") if path.exists() else "# Variable gaps\n"
    additions = []
    if "PNASH score" not in existing:
        additions.append(
            "\n## PNASH score\n"
            "- **Why it matters:** facility inspection scores would directly measure the regulatory pressure behind closure timing.\n"
            "- **Paths searched:** `02_data/processed/pnash_event_level_dataset.parquet`, `02_data/intermediate/hospital_closures_exogenous.parquet`, manuscript tables, and PNASH-related processed outputs.\n"
            "- **Can it be obtained later?** Plausibly, from original PNASH inspection reports or Ministry of Health administrative files if digitized scores are available.\n"
            "- **Manuscript phrasing:** the paper should say closure timing is PNASH-anchored and supported by timing/pre-trend diagnostics, not that facility-level PNASH scores are observed.\n"
        )
    if "De-accreditation indicator" not in existing:
        additions.append(
            "\n## De-accreditation indicator\n"
            "- **Why it matters:** a direct de-accreditation flag would connect PNASH inspection outcomes to the formal loss of SUS contracting.\n"
            "- **Paths searched:** closure-event parquets, CNES-derived closure files, motive-classification outputs, and PNASH event tables.\n"
            "- **Can it be obtained later?** Possibly from DATASUS/CNES contracting histories or Ministry ordinances, but it is not present in the current replication data.\n"
            "- **Manuscript phrasing:** identify closures as PNASH-anchored by timing and facility type; do not claim a de-accreditation microrecord is observed.\n"
        )
    if additions:
        path.write_text(existing.rstrip() + "\n" + "\n".join(additions), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    LOG.mkdir(exist_ok=True)
    stamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    log = LOG / f"72_jhe_submission_tables_{stamp}.log"
    start = time.time()
    with log.open("w", encoding="utf-8") as fh:
        fh.write("script: 72_jhe_submission_tables.py\n")
        fh.write(f"started: {dt.datetime.now().isoformat()}\n")
        fh.write(f"git_sha: {git_sha()}\n")
        fh.write(f"python_packages: pandas={pd.__version__}; numpy={np.__version__}; scipy={stats.__version__ if hasattr(stats, '__version__') else 'unknown'}\n")
        fh.write(f"force: {args.force}\n")
        build_balance_tables()
        fh.write("built balance tables\n")
        build_event_predictor_tables()
        fh.write("built PNASH event and predictor tables\n")
        build_variant_and_distance_tables()
        fh.write("built exposure-variant and distance benchmark tables\n")
        build_mortality_scaling()
        fh.write("built mortality scaling table\n")
        build_first_stage_decomposition()
        fh.write("built first-stage decomposition table and figure\n")
        build_closure_influence_table()
        fh.write("built closure influence table\n")
        update_variable_gaps()
        fh.write("updated variable gaps\n")
        fh.write(f"runtime_seconds: {time.time() - start:.2f}\n")
    print(f"wrote {log.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
