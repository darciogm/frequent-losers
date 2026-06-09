from __future__ import annotations

import datetime as dt
import shutil
import subprocess
import time
from pathlib import Path

import numpy as np
import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
PROC = ROOT / "02_data" / "processed"
TAB = ROOT / "01_manuscript" / "tables"
TABA = ROOT / "01_manuscript" / "tables_appendix"
FIG = ROOT / "04_figures"
LOG = ROOT / "04_logs"


UF_MACRO = {
    "11": "North", "12": "North", "13": "North", "14": "North", "15": "North", "16": "North", "17": "North",
    "21": "Northeast", "22": "Northeast", "23": "Northeast", "24": "Northeast", "25": "Northeast",
    "26": "Northeast", "27": "Northeast", "28": "Northeast", "29": "Northeast",
    "31": "Southeast", "32": "Southeast", "33": "Southeast", "35": "Southeast",
    "41": "South", "42": "South", "43": "South",
    "50": "Center-West", "51": "Center-West", "52": "Center-West", "53": "Center-West",
}


def git_sha() -> str:
    try:
        return subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, text=True).strip()
    except Exception:
        return "unavailable"


def esc(x: object) -> str:
    s = "" if pd.isna(x) else str(x)
    for a, b in [("\\", r"\textbackslash{}"), ("&", r"\&"), ("%", r"\%"), ("$", r"\$"),
                 ("#", r"\#"), ("_", r"\_"), ("{", r"\{"), ("}", r"\}")]:
        s = s.replace(a, b)
    return s


def fmt(x: object, digits: int = 2, signed: bool = False) -> str:
    try:
        v = float(x)
    except Exception:
        return "--"
    if not np.isfinite(v):
        return "--"
    return f"{v:+.{digits}f}" if signed else f"{v:.{digits}f}"


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def compact_sample_table() -> None:
    m = pd.read_csv(PROC / "master_closure_sample_table.csv")
    keep = [
        ("f5_economically_meaningful_closures", "F5 measurement sample"),
        ("pnash_psychiatric_closures", "PNASH psychiatric causal sample"),
        ("general_hospital_f5_closures", "General-hospital contrast"),
        ("hospital_day_f5_closures", "Hospital-day contrast"),
        ("failed_f5_predecline_closures", "Failed-F5 diagnostic sample"),
    ]
    roles = {
        "f5_economically_meaningful_closures": "Measurement: flow versus distance",
        "pnash_psychiatric_closures": "Causal mortality analysis",
        "general_hospital_f5_closures": "Contrast evidence",
        "hospital_day_f5_closures": "Contrast evidence",
        "failed_f5_predecline_closures": "Endogeneity/filter diagnostic",
    }
    defs = {
        "f5_economically_meaningful_closures": "Economically meaningful hospital closures passing F1--F5",
        "pnash_psychiatric_closures": "Psychiatric closures within \\(\\pm 1\\) year of PNASH cycles",
        "general_hospital_f5_closures": "F5 closures with general-hospital type",
        "hospital_day_f5_closures": "F5 closures with hospital-day type",
        "failed_f5_predecline_closures": "Pass F4 but fail F5 due to pre-closure volume decline",
    }
    rows = []
    for sid, label in keep:
        r = m[m.sample_id == sid].iloc[0]
        rows.append(
            f"{esc(label)} & {defs[sid]} & {int(r.number_of_closures)} & "
            f"{int(r.number_of_unique_flow_exposed_municipalities)} & {esc(roles[sid])} \\\\"
        )
    tex = "\n".join([
        r"\begin{table}[!htbp]\centering",
        r"\caption{Closure samples and their role in the paper}",
        r"\label{tab:sample-architecture-compact}",
        r"\small",
        r"\resizebox{\textwidth}{!}{%",
        r"\begin{tabular}{llrrl}",
        r"\toprule",
        r"Sample & Definition & Closures & Flow-exposed munis & Role \\",
        r"\midrule",
        *rows,
        r"\bottomrule",
        r"\multicolumn{5}{p{0.95\textwidth}}{\footnotesize Notes: F5 is the measurement-sample filter for economically meaningful hospital closures. The PNASH psychiatric causal sample prioritizes institutional anchoring to federal inspection cycles; stricter and broader psychiatric samples are reported as robustness checks.}\\",
        r"\end{tabular}",
        r"}%",
        r"\end{table}",
        "",
    ])
    write(TAB / "table_sample_architecture_compact.tex", tex)


def distance_risksets() -> pd.DataFrame:
    d = pd.read_parquet(PROC / "distance_benchmark_exposures.parquet")
    d["mun_uf"] = d["municipality"].astype(str).str[:2]
    d["mun_macro"] = d["mun_uf"].map(UF_MACRO)
    ev = pd.read_parquet(PROC / "pnash_event_level_dataset.parquet")
    ev = ev.rename(columns={"CNES": "cnes"})
    ev["cnes"] = ev["cnes"].astype(str).str.zfill(7)
    ev["hosp_uf"] = ev["municipality"].astype(str).str[:2]
    ev["hosp_macro"] = ev["hosp_uf"].map(UF_MACRO)
    d["cnes"] = d["cnes"].astype(str).str.zfill(7)
    d = d.merge(ev[["cnes", "closure_year", "hosp_uf", "hosp_macro"]], on=["cnes", "closure_year"], how="left")
    d["same_state"] = d["mun_uf"] == d["hosp_uf"]
    d["same_macroregion"] = d["mun_macro"] == d["hosp_macro"]
    d["within_150km"] = d["distance_to_closing_km"] <= 150
    risksets = {
        "same_state": "Same state",
        "same_macroregion": "Same macroregion",
        "within_150km": "Within 150 km",
    }
    rows = []
    for rule, dr in d.groupby("benchmark_rule"):
        for rcol, rlab in risksets.items():
            x = dr[dr[rcol].fillna(False)].copy()
            a = set(zip(x.loc[x.flow_exposed_005, "cnes"], x.loc[x.flow_exposed_005, "municipality"]))
            b = set(zip(x.loc[x.distance_exposed, "cnes"], x.loc[x.distance_exposed, "municipality"]))
            union = a | b
            rows.append({
                "sample_id": "pnash48",
                "benchmark_rule": rule,
                "riskset": rcol,
                "riskset_label": rlab,
                "flow_only": len(a - b),
                "distance_only": len(b - a),
                "both": len(a & b),
                "union": len(union),
                "jaccard": len(a & b) / len(union) if union else np.nan,
                "riskset_pairs_observed": len(set(zip(x["cnes"], x["municipality"]))),
                "support_status": "support failure" if len(b) > 0 and len(a | b) > 0 and len(b) / max(len(union), 1) > 0.98 else "ok",
            })
    out = pd.DataFrame(rows)
    out.to_parquet(PROC / "distance_benchmarks_risksets.parquet", index=False)
    return out


def measurement_tables() -> None:
    fd = pd.read_parquet(PROC / "flow_distance_disagreement_f5.parquet")
    if len(fd) == 1 and "flow_only" in fd.columns:
        summ = fd.iloc[0].to_dict()
    else:
        ccol = "cnes" if "cnes" in fd.columns else "CNES"
        flow = set(zip(fd.loc[fd.flow_exposed, ccol], fd.loc[fd.flow_exposed, "municipality"]))
        dist = set(zip(fd.loc[fd.distance_exposed, ccol], fd.loc[fd.distance_exposed, "municipality"]))
        summ = {
            "flow_only": len(flow - dist),
            "distance_only": len(dist - flow),
            "both": len(flow & dist),
            "union": len(flow | dist),
            "misclassified": len((flow - dist) | (dist - flow)),
            "jaccard": len(flow & dist) / len(flow | dist),
        }
    rs = distance_risksets()
    rule_order = [
        ("distance_top3_any_hospital", "Top 3 any hospital"),
        ("distance_top3_same_type", "Top 3 same type"),
        ("distance_top3_psych_hospital", "Top 3 psychiatric provider"),
        ("distance_nearest_psych_bed", "Nearest psychiatric provider"),
    ]
    compact = rs[(rs.riskset == "same_state") & (rs.benchmark_rule.isin([r for r, _ in rule_order]))].copy()
    compact["rule_label"] = compact["benchmark_rule"].map(dict(rule_order))
    compact.to_csv(PROC / "distance_benchmark_compact.csv", index=False)

    lines = [
        r"\begin{table}[!htbp]\centering",
        r"\caption{Patient-flow exposure versus distance-based exposure}",
        r"\label{tab:measurement-compact}",
        r"\small",
        r"\resizebox{\textwidth}{!}{%",
        r"\begin{tabular}{llrrrrrl}",
        r"\toprule",
        r"Sample / benchmark & Risk set & Flow only & Distance only & Both & Union & Jaccard & Status \\",
        r"\midrule",
        rf"F5 measurement sample: top 3 any hospital & National union & {int(summ['flow_only'])} & {int(summ['distance_only'])} & {int(summ['both'])} & {int(summ['union'])} & {float(summ['jaccard']):.3f} & ok \\",
        r"\midrule",
    ]
    for _, r in compact.sort_values(["benchmark_rule"]).iterrows():
        lines.append(
            f"PNASH: {esc(r.rule_label)} & {esc(r.riskset_label)} & {int(r.flow_only)} & "
            f"{int(r.distance_only)} & {int(r.both)} & {int(r.union)} & {fmt(r.jaccard, 3)} & {esc(r.support_status)} \\\\"
        )
    lines.extend([
        r"\bottomrule",
        r"\multicolumn{8}{p{0.95\textwidth}}{\footnotesize Notes: The first row reports the paper's full F5 measurement-sample result: distance misclassifies 293 of 337 municipality--closure pairs flagged by either rule. The PNASH panel restricts distance comparisons to same-state risk sets to avoid national support artifacts. Specialty-provider rules that classify nearly the full support are marked as support failures rather than used as central estimators. Full risk-set results are in the online appendix.}\\",
        r"\end{tabular}",
        r"}%",
        r"\end{table}",
        "",
    ])
    write(TAB / "table_measurement_compact.tex", "\n".join(lines))

    full = rs.sort_values(["benchmark_rule", "riskset"])
    lines = [
        r"\begin{table}[!htbp]\centering",
        r"\caption{Specialty-aware distance benchmarks by risk set}",
        r"\label{tab:distance-benchmark-full}",
        r"\scriptsize",
        r"\resizebox{\textwidth}{!}{%",
        r"\begin{tabular}{llrrrrrl}",
        r"\toprule",
        r"Benchmark & Risk set & Flow only & Distance only & Both & Union & Jaccard & Status \\",
        r"\midrule",
    ]
    for _, r in full.iterrows():
        lines.append(
            f"{esc(r.benchmark_rule)} & {esc(r.riskset_label)} & {int(r.flow_only)} & {int(r.distance_only)} & "
            f"{int(r.both)} & {int(r.union)} & {fmt(r.jaccard,3)} & {esc(r.support_status)} \\\\"
        )
    lines.extend([r"\bottomrule", r"\end{tabular}", r"}%", r"\end{table}", ""])
    write(TABA / "table_distance_benchmark_full.tex", "\n".join(lines))


def pnash_summary_tables() -> None:
    ev = pd.read_parquet(PROC / "pnash_event_level_dataset.parquet")
    bal = pd.read_csv(PROC / "balance_pnash_true_preperiod.csv")
    pred = pd.read_csv(PROC / "preclosure_predictor_tests.csv")
    within = int(ev["within_pm1_year_of_pnash_cycle"].sum())
    cycle_counts = ev.groupby("nearest_pnash_cycle").size().to_dict()
    key_bal = bal[(bal.baseline == "cohort-specific true pre-period") &
                  (bal.covariate.isin(["Log population", "Suicide mortality", "Self-harm mortality", "Psychiatric admission episodes"]))]
    pred_min_p = pred["p"].min()
    lines = [
        r"\begin{table}[!htbp]\centering",
        r"\caption{PNASH identification and pre-treatment balance summary}",
        r"\label{tab:pnash-identification-summary}",
        r"\small",
        r"\begin{tabular}{llr}",
        r"\toprule",
        r"Panel & Diagnostic & Value \\",
        r"\midrule",
        f"Timing & PNASH psychiatric closures & {len(ev)} \\\\",
        f"Timing & Within PNASH cycle windows & {len(ev)} \\\\",
        f"Timing & Within exact $\\pm 1$ calendar year of nearest cycle & {within} \\\\",
        f"Timing & Closures by cycle & {esc('; '.join(f'{k}: {v}' for k, v in cycle_counts.items()))} \\\\",
        f"Predictors & Smallest pre-closure predictor-test $p$-value & {fmt(pred_min_p, 3)} \\\\",
        r"\midrule",
    ]
    for _, r in key_bal.iterrows():
        lines.append(
            f"Balance & {esc(r.covariate)} std. diff. / $p$ & {fmt(r.std_diff,3, signed=True)} / {fmt(r.p_value,3)} \\\\"
        )
    lines.extend([
        r"\bottomrule",
        r"\multicolumn{3}{p{0.78\textwidth}}{\footnotesize Notes: Balance uses only observations strictly before exposure for treated municipalities. Predictor-test rows are closure-level regressions of closure year on standardized pre-closure predictors. Full closure-level timing and covariate tables are in the online appendix.}\\",
        r"\end{tabular}",
        r"\end{table}",
        "",
    ])
    write(TAB / "table_pnash_identification_summary.tex", "\n".join(lines))

    ev2 = ev.copy()
    ev2["uf"] = ev2["municipality"].astype(str).str[:2]
    cols = [
        ("CNES", "CNES"), ("municipality", "Hosp."), ("uf", "UF"),
        ("closure_year", "Year"), ("nearest_pnash_cycle", "Cycle"),
        ("years_from_nearest_pnash_cycle", "Dist."),
        ("within_pm1_year_of_pnash_cycle", "$\\pm$1"),
        ("pre_volume_decline_pct", r"Decl. \%"),
        ("qt_sus_pre", "Beds"),
        ("pre_closure_psychiatric_admissions", "Psych. AIH"),
        ("pre_closure_psychiatric_beddays", "Psych. bed-days"),
    ]
    if "number_flow_exposed_municipalities" in ev2.columns:
        cols.append(("number_flow_exposed_municipalities", "Exposed munis"))
    rows = []
    for _, r in ev2.sort_values(["closure_year", "CNES"]).iterrows():
        vals = []
        for c, _ in cols:
            v = r.get(c, np.nan)
            if isinstance(v, (int, np.integer)):
                vals.append(str(int(v)))
            elif isinstance(v, (float, np.floating)):
                vals.append(fmt(v, 1))
            elif isinstance(v, (bool, np.bool_)):
                vals.append("Yes" if v else "No")
            else:
                vals.append(esc(v))
        rows.append(" & ".join(vals) + r" \\")
    lines = [
        r"\begin{table}[p]",
        r"\centering",
        r"\caption{PNASH psychiatric closure events}",
        r"\label{tab:pnash-event-level}",
        r"\scriptsize",
        r"\setlength{\tabcolsep}{1.5pt}",
        r"\renewcommand{\arraystretch}{0.82}",
        r"\begin{tabular}{llllllrrrrr}",
        r"\toprule",
        " & ".join(h for _, h in cols) + r" \\",
        r"\midrule",
        *rows,
        r"\bottomrule",
        r"\end{tabular}",
        r"\par\medskip",
        r"\begin{minipage}{0.95\textwidth}\footnotesize Notes: PNASH score and formal de-accreditation micro-indicators are not available in the local data; timing is measured relative to published PNASH inspection cycles.\end{minipage}",
        r"\end{table}",
        "",
    ]
    write(TABA / "table_pnash_event_level.tex", "\n".join(lines))


def mortality_and_robustness_table() -> None:
    scale = pd.read_csv(PROC / "mortality_bounds_scaled.csv")
    spill = pd.read_csv(PROC / "spillover_sensitivity_estimates.csv")
    loo = pd.read_csv(PROC / "leave_one_closure_out_revision.csv")
    exp = pd.read_csv(PROC / "exposure_distance_variant_eventstudies.csv")
    rows = []
    for _, r in scale.iterrows():
        rows.append(
            f"{esc(r.outcome)} & {fmt(r.att_per100k,2,True)} & [{fmt(r.lo_per100k,2,True)}, {fmt(r.hi_per100k,2,True)}] & "
            f"{fmt(r.baseline_rate_per100k,2)} & {fmt(r.upper_ci_percent_of_baseline,1)} & "
            f"{fmt(r.upper_deaths_per_year,1)} & {fmt(r.upper_deaths_per_1000_psych_admissions,2)} \\\\"
        )
    rob_lines = []
    same_cir = spill[(spill.rule == "Exclude any network-contaminated controls") & (spill.outcome_label == "Suicide")].iloc[0]
    loo_s = loo[(loo.outcome_label == "Suicide") & (loo.closure_id != "baseline")]
    exp_s = exp[(exp.variant_family == "flow") & (exp.outcome == "suicide_per100k") & (exp.status == "ok")]
    rob_lines.extend([
        f"Network-contaminated controls excluded & Suicide ATT {fmt(same_cir.att,2,True)} [{fmt(same_cir.lo,2,True)}, {fmt(same_cir.hi,2,True)}] \\\\",
        f"Leave-one-closure-out range & Suicide ATT range {fmt(loo_s.att.min(),2,True)} to {fmt(loo_s.att.max(),2,True)} \\\\",
        f"Flow-exposure variants & Suicide ATT range {fmt(exp_s.att.min(),2,True)} to {fmt(exp_s.att.max(),2,True)} \\\\",
    ])
    tex = "\n".join([
        r"\begin{table}[!htbp]\centering",
        r"\caption{Mortality estimates, scaled bounds, and robustness summary}",
        r"\label{tab:main-mortality-scaled-bounds}",
        r"\small",
        r"\resizebox{\textwidth}{!}{%",
        r"\begin{tabular}{lrrrrrr}",
        r"\toprule",
        r"Outcome & ATT per 100k & 95\% CI & Baseline & Upper \% baseline & Upper deaths/year & Upper deaths per 1,000 psych. AIH \\",
        r"\midrule",
        *rows,
        r"\midrule",
        r"\multicolumn{7}{l}{\emph{Selected robustness diagnostics}}\\",
        *[rf"\multicolumn{{3}}{{l}}{{{line.split(' & ')[0]}}} & \multicolumn{{4}}{{l}}{{{line.split(' & ')[1][:-2]}}} \\" for line in rob_lines],
        r"\bottomrule",
        r"\multicolumn{7}{p{0.95\textwidth}}{\footnotesize Notes: The upper-bound columns translate the upper endpoint of the 95 percent confidence interval into substantive units. Psychiatric AIH counts are episodes, not unique people. Full robustness tables are in the online appendix.}\\",
        r"\end{tabular}",
        r"}%",
        r"\end{table}",
        "",
    ])
    write(TAB / "table_main_mortality_scaled_bounds.tex", tex)


def copy_appendix_tables() -> None:
    TABA.mkdir(parents=True, exist_ok=True)
    copies = {
        "table_balance_pnash_true_preperiod.tex": "table_balance_pnash_true_preperiod.tex",
        "table_exposure_variant_mortality.tex": "table_exposure_variant_mortality.tex",
        "table_first_stage_decomposition.tex": "table_first_stage_decomposition_full.tex",
        "table_top_substitute_hospitals.tex": "table_top_substitute_hospitals.tex",
        "table_spillover_sensitivity.tex": "table_spillover_sensitivity.tex",
        "table_closure_influence.tex": "table_closure_influence.tex",
        "table_honestdid_mortality.tex": "table_honestdid_mortality.tex",
        "table_remaining_data_caveats.tex": "table_remaining_data_caveats.tex",
    }
    for src, dst in copies.items():
        s = TAB / src
        if s.exists():
            shutil.copyfile(s, TABA / dst)
    # Publication-friendly alias requested by the revision plan.
    src_fig = FIG / "fig_first_stage_decomposition_eventstudy.pdf"
    dst_fig = FIG / "fig_first_stage_decomposition.pdf"
    if src_fig.exists():
        shutil.copyfile(src_fig, dst_fig)


def main() -> None:
    start = time.time()
    LOG.mkdir(exist_ok=True)
    stamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    log = LOG / f"74_jhe_compression_package_{stamp}.log"
    compact_sample_table()
    measurement_tables()
    pnash_summary_tables()
    mortality_and_robustness_table()
    copy_appendix_tables()
    write(log, "\n".join([
        "script: 74_jhe_compression_package.py",
        f"started: {dt.datetime.now().isoformat()}",
        f"git_sha: {git_sha()}",
        f"runtime_seconds: {time.time() - start:.2f}",
    ]) + "\n")
    print(f"wrote {log.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
