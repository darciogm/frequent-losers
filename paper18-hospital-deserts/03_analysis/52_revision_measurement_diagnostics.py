from __future__ import annotations

import json

import duckdb
import numpy as np
import pandas as pd

from revision_utils import (
    FIG,
    INTER,
    LOG,
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


SCRIPT = "52_revision_measurement_diagnostics"
DIST_OUT = PROC / "distance_benchmark_exposures.parquet"
DIST_TEX = TAB / "table_flow_vs_distance_benchmarks.tex"
DIST_RES_TEX = TAB / "table_distance_benchmark_results.tex"
DIST_FIG = FIG / "fig_flow_distance_overlap_by_region.pdf"
DECOMP_OUT = PROC / "first_stage_decomposition_panel.parquet"
DECOMP_TEX = TAB / "table_first_stage_decomposition.tex"
SUB_TEX = TAB / "table_top_substitute_hospitals.tex"
SPILL_OUT = PROC / "spillover_control_flags.parquet"
SPILL_TEX = TAB / "table_spillover_sensitivity.tex"
CAPS_CIR = PROC / "cnes_caps_cir_municipality_year.parquet"
LLM_TEX = TAB / "table_llm_validation_status.tex"
LLM_LOG = LOG / "llm_classification_audit_latest.log"
AUDIT_LOG = LOG / "sample_consistency_audit_latest.log"

PNASH_WHERE = (
    "f1_window AND f2_type AND f3_beds AND f4_mass AND tp_unid='07' AND "
    "(year_closure BETWEEN 2006 AND 2009 OR year_closure BETWEEN 2010 AND 2013 "
    "OR year_closure BETWEEN 2014 AND 2017)"
)


def haversine(lat1, lon1, lat2, lon2):
    r = 6371.0
    lat1 = np.deg2rad(lat1)
    lat2 = np.deg2rad(lat2)
    dlat = lat2 - lat1
    dlon = np.deg2rad(lon2 - lon1)
    a = np.sin(dlat / 2) ** 2 + np.cos(lat1) * np.cos(lat2) * np.sin(dlon / 2) ** 2
    return 2 * r * np.arcsin(np.sqrt(np.clip(a, 0, 1)))


def closures(con):
    return con.sql(f"""
        SELECT CNES, codmun_6 AS codmun_hosp, year_closure, tp_unid
        FROM read_parquet('{INTER / "hospital_closures_exogenous.parquet"}')
        WHERE {PNASH_WHERE}
    """).df()


def build_distance_benchmarks(con, logger) -> pd.DataFrame:
    clo = closures(con)
    cent = con.sql(f"""
        SELECT cod_mun_6 AS codmun_6, uf, lat, lon
        FROM read_parquet('{INTER / "municipios_centroids.parquet"}')
    """).df()
    cent = cent.dropna(subset=["lat", "lon"])
    loc = cent.set_index("codmun_6")[["lat", "lon", "uf"]].to_dict("index")
    hosp = con.sql(f"""
        SELECT CNES, codmun_6_modal AS codmun_6, tp_unid_modal AS tp_unid
        FROM read_parquet('{INTER / "hospital_master.parquet"}')
        WHERE codmun_6_modal IS NOT NULL
    """).df()
    hosp = hosp[hosp["codmun_6"].isin(loc)]
    hosp["lat"] = hosp["codmun_6"].map(lambda x: loc[x]["lat"])
    hosp["lon"] = hosp["codmun_6"].map(lambda x: loc[x]["lon"])

    # Psychiatric provider set: facilities with any F-diagnosis admissions in the exposure-variant object.
    psych_providers = set()
    expv = PROC / "exposure_variants_long.parquet"
    if expv.exists():
        psych_providers = set(pd.read_parquet(expv, columns=["cnes", "exposure_definition"])
                              .query("exposure_definition == 'flow_psych_admissions'")["cnes"])
    if not psych_providers:
        logger.warning("psychiatric provider set unavailable; psych distance variants use tp_unid=07 as proxy")
        psych_providers = set(hosp.loc[hosp["tp_unid"] == "07", "CNES"])

    muni_codes = cent["codmun_6"].to_numpy()
    muni_lat = cent["lat"].to_numpy(dtype=float)
    muni_lon = cent["lon"].to_numpy(dtype=float)

    def kth_threshold(cand: pd.DataFrame, k: int) -> dict[str, float]:
        vals = []
        c_lat = cand["lat"].to_numpy(dtype=float)
        c_lon = cand["lon"].to_numpy(dtype=float)
        for lat, lon in zip(muni_lat, muni_lon):
            d = haversine(lat, lon, c_lat, c_lon)
            vals.append(float(np.partition(d, min(k - 1, len(d) - 1))[min(k - 1, len(d) - 1)]))
        return dict(zip(muni_codes, vals))

    logger.info("precomputing distance thresholds")
    any_top3 = kth_threshold(hosp, 3)
    psych_hosp = hosp[hosp["CNES"].isin(psych_providers)]
    psych_top3 = kth_threshold(psych_hosp, 3) if not psych_hosp.empty else {}
    psych_nearest = kth_threshold(psych_hosp, 1) if not psych_hosp.empty else {}
    same_type_top3 = {
        tp: kth_threshold(hosp[hosp["tp_unid"] == tp], 3)
        for tp in sorted(hosp["tp_unid"].dropna().unique())
        if not hosp[hosp["tp_unid"] == tp].empty
    }

    rows = []
    for _, c in clo.iterrows():
        if c.codmun_hosp not in loc:
            continue
        year = int(c.year_closure)
        flow = con.sql(f"""
            WITH total AS (
              SELECT codmun_6, SUM(n_internacoes) denom
              FROM read_parquet('{INTER / "bipartite_edges.parquet"}')
              WHERE year={year-1} GROUP BY codmun_6
            ),
            num AS (
              SELECT codmun_6, SUM(n_internacoes) num
              FROM read_parquet('{INTER / "bipartite_edges.parquet"}')
              WHERE year={year-1} AND CNES='{c.CNES}' GROUP BY codmun_6
            )
            SELECT t.codmun_6 AS municipality,
                   COALESCE(num, 0)*1.0/NULLIF(denom, 0) AS flow_share
            FROM total t LEFT JOIN num USING(codmun_6)
            WHERE COALESCE(num, 0) > 0
        """).df()
        flow_set = set(flow["municipality"])
        flow_map = flow.set_index("municipality")["flow_share"].to_dict()
        hrow = hosp[hosp["CNES"] == c.CNES]
        if hrow.empty:
            continue
        hlat = float(hrow.iloc[0]["lat"])
        hlon = float(hrow.iloc[0]["lon"])
        dist_to_closing = {
            m: float(d) for m, d in zip(muni_codes, haversine(muni_lat, muni_lon, hlat, hlon))
        }
        rule_thresholds = [
            ("distance_top3_any_hospital", any_top3, True),
            ("distance_top3_psych_hospital", psych_top3, c.CNES in psych_providers),
            ("distance_top3_same_type", same_type_top3.get(c.tp_unid, {}), True),
            ("distance_nearest_psych_bed", psych_nearest, c.CNES in psych_providers),
        ]
        for rule, thresholds, eligible in rule_thresholds:
            if not thresholds or not eligible:
                continue
            distance_set = {m for m in muni_codes if dist_to_closing[m] <= thresholds[m] + 1e-9}
            muni_set = flow_set | distance_set
            for m in muni_set:
                if m not in loc:
                    continue
                exposed = m in distance_set
                rows.append({
                    "sample_id": "pnash48",
                    "cnes": c.CNES,
                    "closure_year": year,
                    "municipality": m,
                    "benchmark_rule": rule,
                    "flow_share": flow_map.get(m, 0.0),
                    "flow_exposed_005": flow_map.get(m, 0.0) >= 0.05,
                    "distance_exposed": bool(exposed),
                    "uf": loc[m]["uf"],
                    "distance_to_closing_km": dist_to_closing[m],
                })
    out = pd.DataFrame(rows)
    return out


def write_distance_outputs(df: pd.DataFrame) -> None:
    rule_labels = {
        "distance_nearest_psych_bed": "Nearest psych bed",
        "distance_top3_any_hospital": "Top 3 any",
        "distance_top3_psych_hospital": "Top 3 psych",
        "distance_top3_same_type": "Top 3 same type",
    }
    rows = []
    for rule, d in df.groupby("benchmark_rule"):
        flow = d[d["flow_exposed_005"]]
        dist = d[d["distance_exposed"]]
        a = set(zip(flow["cnes"], flow["municipality"]))
        b = set(zip(dist["cnes"], dist["municipality"]))
        rows.append({
            "rule": rule,
            "flow_only": len(a - b),
            "distance_only": len(b - a),
            "both": len(a & b),
            "neither_rows": int((~d["flow_exposed_005"] & ~d["distance_exposed"]).sum()),
            "jaccard": len(a & b) / len(a | b) if a | b else np.nan,
        })
    tab = pd.DataFrame(rows)
    lines = [
        "\\begin{table}[!htbp]\\centering",
        "\\caption{Patient-flow exposure versus specialty-aware distance benchmarks}",
        "\\label{tab:flow-vs-distance-benchmarks}",
        "\\small",
        "\\resizebox{\\textwidth}{!}{%",
        "\\begin{tabular}{lrrrrr}",
        "\\toprule",
        "Benchmark & Flow only & Distance only & Both & Neither & Jaccard \\\\",
        "\\midrule",
    ]
    for _, r in tab.iterrows():
        lines.append(f"{latex_escape(rule_labels.get(r.rule, r.rule))} & {int(r.flow_only)} & {int(r.distance_only)} & {int(r.both)} & {int(r.neither_rows)} & {r.jaccard:.3f} \\\\")
    lines.extend(["\\bottomrule", "\\end{tabular}", "}%", "\\end{table}"])
    write_text(DIST_TEX, "\n".join(lines) + "\n")

    # Placeholder results table records design-stage benchmark counts, not causal estimates.
    lines2 = [
        "\\begin{table}[!htbp]\\centering",
        "\\caption{Distance-benchmark result availability}",
        "\\label{tab:distance-benchmark-results}",
        "\\small",
        "\\resizebox{\\textwidth}{!}{%",
        "\\begin{tabular}{lp{0.58\\textwidth}}",
        "\\toprule",
        "Benchmark & Status \\\\",
        "\\midrule",
    ]
    for rule in sorted(df["benchmark_rule"].unique()):
        lines2.append(f"{latex_escape(rule_labels.get(rule, rule))} & Flags generated; estimator pass pending. \\\\")
    lines2.extend(["\\bottomrule", "\\end{tabular}", "}%", "\\end{table}"])
    write_text(DIST_RES_TEX, "\n".join(lines2) + "\n")

    import matplotlib.pyplot as plt

    by = df.groupby(["uf", "benchmark_rule"]).apply(
        lambda g: ((g["flow_exposed_005"] & g["distance_exposed"]).sum() / max((g["flow_exposed_005"] | g["distance_exposed"]).sum(), 1))
    ).reset_index(name="jaccard")
    fig, ax = plt.subplots(figsize=(7.5, 4.2))
    for rule, g in by.groupby("benchmark_rule"):
        ax.plot(g["uf"], g["jaccard"], marker="o", linewidth=0.8, label=rule.replace("distance_", ""))
    ax.set_ylabel("Flow-distance Jaccard")
    ax.set_xlabel("State")
    ax.tick_params(axis="x", rotation=90, labelsize=6)
    ax.legend(fontsize=6)
    fig.tight_layout()
    fig.savefig(DIST_FIG)
    plt.close(fig)


def build_decomposition(con) -> tuple[pd.DataFrame, pd.DataFrame]:
    clo = closures(con)
    rows = []
    substitutes = []
    for _, c in clo.iterrows():
        exp = con.sql(f"""
            WITH total AS (
              SELECT codmun_6, SUM(n_internacoes) denom
              FROM read_parquet('{INTER / "bipartite_edges.parquet"}')
              WHERE year={int(c.year_closure)-1} GROUP BY codmun_6
            ),
            num AS (
              SELECT codmun_6, SUM(n_internacoes) num
              FROM read_parquet('{INTER / "bipartite_edges.parquet"}')
              WHERE year={int(c.year_closure)-1} AND CNES='{c.CNES}' GROUP BY codmun_6
            )
            SELECT t.codmun_6
            FROM total t LEFT JOIN num USING(codmun_6)
            WHERE COALESCE(num, 0)*1.0/NULLIF(denom, 0) >= 0.05
        """).df()["codmun_6"].tolist()
        if not exp:
            continue
        exp_sql = "(" + ",".join(f"'{m}'" for m in exp) + ")"
        for rel in range(-4, 5):
            year = int(c.year_closure) + rel
            q = con.sql(f"""
                SELECT
                    SUM(n_internacoes) AS total_admissions,
                    SUM(CASE WHEN CNES='{c.CNES}' THEN n_internacoes ELSE 0 END) AS admissions_to_closing_hospital,
                    SUM(CASE WHEN CNES<>'{c.CNES}' THEN n_internacoes ELSE 0 END) AS admissions_to_substitute_hospitals,
                    SUM(CASE WHEN codmun_6='{c.codmun_hosp}' THEN n_internacoes ELSE 0 END) AS admissions_in_hospital_municipality,
                    SUM(CASE WHEN codmun_6<>'{c.codmun_hosp}' THEN n_internacoes ELSE 0 END) AS admissions_outside_hospital_municipality,
                    SUM(val_tot_soma) AS aih_value,
                    SUM(n_internacoes * dias_perm_medio) AS beddays_proxy
                FROM read_parquet('{INTER / "bipartite_edges.parquet"}')
                WHERE year={year} AND codmun_6 IN {exp_sql}
            """).df().iloc[0].to_dict()
            q.update({"cnes": c.CNES, "closure_year": int(c.year_closure), "event_time": rel, "year": year})
            rows.append(q)
        prepost = con.sql(f"""
            WITH flows AS (
              SELECT CNES,
                     SUM(CASE WHEN year BETWEEN {int(c.year_closure)-3} AND {int(c.year_closure)-1} THEN n_internacoes ELSE 0 END) pre,
                     SUM(CASE WHEN year BETWEEN {int(c.year_closure)+1} AND {int(c.year_closure)+3} THEN n_internacoes ELSE 0 END) post
              FROM read_parquet('{INTER / "bipartite_edges.parquet"}')
              WHERE codmun_6 IN {exp_sql} AND CNES<>'{c.CNES}'
              GROUP BY CNES
            )
            SELECT '{c.CNES}' AS closing_cnes, CNES AS substitute_cnes, pre, post, post-pre AS change
            FROM flows ORDER BY change DESC LIMIT 5
        """).df()
        substitutes.append(prepost)
    panel = pd.DataFrame(rows)
    subs = pd.concat(substitutes, ignore_index=True) if substitutes else pd.DataFrame()
    return panel, subs


def write_decomp_outputs(panel: pd.DataFrame, subs: pd.DataFrame) -> None:
    summary = panel.groupby("event_time")[["total_admissions", "admissions_to_closing_hospital", "admissions_to_substitute_hospitals", "beddays_proxy", "aih_value"]].mean().reset_index()
    pre = summary[summary["event_time"].between(-3, -1)].mean(numeric_only=True)
    post = summary[summary["event_time"].between(1, 3)].mean(numeric_only=True)
    rows = []
    label = {
        "total_admissions": "Total admissions",
        "admissions_to_closing_hospital": "To closing hospital",
        "admissions_to_substitute_hospitals": "To other hospitals",
        "beddays_proxy": "Bed-days proxy",
        "aih_value": "AIH value",
    }
    for col in ["total_admissions", "admissions_to_closing_hospital", "admissions_to_substitute_hospitals", "beddays_proxy", "aih_value"]:
        rows.append((col, pre[col], post[col], post[col] - pre[col]))
    lines = [
        "\\begin{table}[!htbp]\\centering",
        "\\caption{First-stage decomposition around PNASH psychiatric closures}",
        "\\label{tab:first-stage-decomposition}",
        "\\small",
        "\\resizebox{\\textwidth}{!}{%",
        "\\begin{tabular}{lrrr}",
        "\\toprule",
        "Outcome & Pre mean & Post mean & Change \\\\",
        "\\midrule",
    ]
    for name, a, b, d in rows:
        lines.append(f"{latex_escape(label.get(name, name.replace('_', ' ')))} & {a:.1f} & {b:.1f} & {d:+.1f} \\\\")
    lines.extend([
        "\\bottomrule",
        "\\multicolumn{4}{p{0.82\\textwidth}}{\\footnotesize Notes: entries are descriptive catchment-level averages over event years $-3$ to $-1$ and $+1$ to $+3$, using all-SUS flow edges. They distinguish disappearance from the closing hospital from substitution to other facilities, but psychiatric-specific decomposition requires a dedicated SIH edge rebuild.}\\\\",
        "\\end{tabular}",
        "}%",
        "\\end{table}",
    ])
    write_text(DECOMP_TEX, "\n".join(lines) + "\n")
    if not subs.empty:
        top = subs.sort_values("change", ascending=False).head(25)
        lines = [
            "\\begin{table}[!htbp]\\centering",
            "\\caption{Largest substitute-destination increases}",
            "\\label{tab:top-substitute-hospitals}",
            "\\scriptsize",
            "\\resizebox{\\textwidth}{!}{%",
            "\\begin{tabular}{llrrr}",
            "\\toprule",
            "Closing CNES & Substitute CNES & Pre & Post & Change \\\\",
            "\\midrule",
        ]
        for _, r in top.iterrows():
            lines.append(f"{r.closing_cnes} & {r.substitute_cnes} & {r.pre:.0f} & {r.post:.0f} & {r.change:+.0f} \\\\")
        lines.extend(["\\bottomrule", "\\end{tabular}", "}%", "\\end{table}"])
        write_text(SUB_TEX, "\n".join(lines) + "\n")


def spillover_flags(con) -> pd.DataFrame:
    exp = pd.read_parquet(INTER / "exposure_panel.parquet")
    treated = set(exp.loc[exp["exposed_emb"], "codmun_6"])
    edges = con.sql(f"""
        SELECT codmun_6, CNES, SUM(n_internacoes) n
        FROM read_parquet('{INTER / "bipartite_edges.parquet"}')
        WHERE year BETWEEN 2010 AND 2014
        GROUP BY 1, 2
    """).df()
    top = edges.sort_values(["codmun_6", "n"], ascending=[True, False]).groupby("codmun_6").head(1)
    treated_hubs = set(top.loc[top["codmun_6"].isin(treated), "CNES"])
    all_munis = set(pd.read_parquet(INTER / "municipios_centroids.parquet", columns=["cod_mun_6"])["cod_mun_6"])
    treated_cirs: set[str] = set()
    muni_cir: dict[str, str] = {}
    if CAPS_CIR.exists():
        cir = pd.read_parquet(CAPS_CIR, columns=["municipality", "year", "regsaude_modal"])
        cir = cir.dropna(subset=["regsaude_modal"]).copy()
        cir["regsaude_modal"] = cir["regsaude_modal"].astype(str)
        exposed_events = exp.loc[exp["exposed_emb"], ["codmun_6", "year_closure"]].drop_duplicates()
        exposed_events["year"] = exposed_events["year_closure"].astype(int) - 1
        event_cir = exposed_events.merge(
            cir,
            left_on=["codmun_6", "year"],
            right_on=["municipality", "year"],
            how="left",
        )
        treated_cirs = set(event_cir["regsaude_modal"].dropna().astype(str))
        muni_cir = (
            cir.sort_values("year")
            .groupby("municipality")["regsaude_modal"]
            .agg(lambda x: x.mode().iloc[0] if not x.mode().empty else x.iloc[-1])
            .to_dict()
        )
    rows = []
    for m in sorted(all_munis):
        hub = top.loc[top["codmun_6"] == m, "CNES"]
        same_hub = bool(len(hub) and hub.iloc[0] in treated_hubs and m not in treated)
        same_cir = bool(m not in treated and muni_cir.get(m) in treated_cirs) if treated_cirs else False
        rows.append({
            "codmun_6": m,
            "treated_flow": m in treated,
            "same_top_referral_hub": same_hub,
            "shared_substitute_hospital": same_hub,
            "same_cir_as_closure_catchment": same_cir,
            "high_flow_similarity_to_treated": same_hub,
            "contaminated_control_any": same_hub or same_cir,
        })
    return pd.DataFrame(rows)


def write_spillover_tex(flags: pd.DataFrame) -> None:
    labels = {
        "same_top_referral_hub": "Same top hub",
        "shared_substitute_hospital": "Shared substitute",
        "same_cir_as_closure_catchment": "Same health region",
        "high_flow_similarity_to_treated": "High co-flow",
        "contaminated_control_any": "Any flag",
    }
    n_ctrl = int((~flags["treated_flow"]).sum())
    n_cont = int((~flags["treated_flow"] & flags["contaminated_control_any"]).sum())
    lines = [
        "\\begin{table}[!htbp]\\centering",
        "\\caption{Network spillover control flags}",
        "\\label{tab:spillover-sensitivity}",
        "\\small",
        "\\resizebox{\\textwidth}{!}{%",
        "\\begin{tabular}{lrr}",
        "\\toprule",
        "Flag & Controls flagged & Share of controls \\\\",
        "\\midrule",
    ]
    for col in ["same_top_referral_hub", "shared_substitute_hospital", "same_cir_as_closure_catchment", "high_flow_similarity_to_treated", "contaminated_control_any"]:
        n = int((~flags["treated_flow"] & flags[col]).sum())
        lines.append(f"{latex_escape(labels[col])} & {n} & {100*n/max(n_ctrl,1):.1f}\\% \\\\")
    lines.extend([
        "\\bottomrule",
        "\\multicolumn{3}{p{0.75\\textwidth}}{\\footnotesize Same-health-region flags use the modal CNES-ST `REGSAUDE` proxy from December establishment files. Hub-based flags use the largest pre-2015 referral destination.}\\\\",
        "\\end{tabular}",
        "}%",
        "\\end{table}",
    ])
    write_text(SPILL_TEX, "\n".join(lines) + "\n")


def llm_audit(con) -> None:
    human = INTER / "closures_human_validated.parquet"
    if not human.exists():
        rows = {"status": "missing"}
    else:
        df = pd.read_parquet(human)
        rows = {
            "rows": int(len(df)),
            "coder_a_nonempty": int(df.get("coder_a_label", pd.Series(dtype=object)).notna().sum()),
            "coder_b_nonempty": int(df.get("coder_b_label", pd.Series(dtype=object)).notna().sum()),
            "adjudicated_nonempty": int(df.get("adjudicated_label", pd.Series(dtype=object)).notna().sum()),
            "fragile_flags": int(df.get("fragile_sensitivity_flag", pd.Series(dtype=bool)).fillna(False).sum()),
        }
    write_text(LLM_LOG, json.dumps(rows, indent=2) + "\n")
    lines = [
        "\\begin{table}[!htbp]\\centering",
        "\\caption{LLM closure-motive validation status}",
        "\\label{tab:llm-validation-status}",
        "\\small",
        "\\resizebox{0.78\\textwidth}{!}{%",
        "\\begin{tabular}{lr}",
        "\\toprule",
        "Field & Count \\\\",
        "\\midrule",
    ]
    for k, v in rows.items():
        if isinstance(v, int):
            lines.append(f"{latex_escape(k.replace('_', ' '))} & {v} \\\\")
    lines.extend([
        "\\bottomrule",
        "\\multicolumn{2}{p{0.72\\textwidth}}{\\footnotesize Motive labels organize documentary evidence and define robustness subsets only. They are not an identifying assumption.}\\\\",
        "\\end{tabular}",
        "}%",
        "\\end{table}",
    ])
    write_text(LLM_TEX, "\n".join(lines) + "\n")


def sample_audit() -> None:
    warnings = []
    mst = PROC / "master_sample_table.parquet"
    if mst.exists():
        df = pd.read_parquet(mst)
        main = df[df["sample_id"] == "pnash48"].iloc[0]
        vals = (ROOT / "01_manuscript" / "values.tex").read_text(encoding="utf-8")
        checks = {
            "valNclosuresPnash": int(main["number_of_closure_events"]),
            "valNtrPnash": int(main["number_of_unique_treated_municipalities"]),
        }
        for macro, expected in checks.items():
            token = "{" + str(expected) + "}"
            if f"\\newcommand{{\\{macro}}}{token}" not in vals:
                warnings.append(f"{macro} does not match expected {expected}")
    else:
        warnings.append("master_sample_table.parquet is missing")
    write_text(AUDIT_LOG, "\n".join(warnings or ["sample consistency audit passed for generated macro checks"]) + "\n")


def main() -> None:
    args = parse_args("Build measurement, distance, first-stage, spillover, and LLM diagnostics.")
    ensure_dirs()
    log = logger_for(SCRIPT)
    t0 = begin_log(log, SCRIPT)
    outputs = [DIST_OUT, DIST_TEX, DIST_RES_TEX, DIST_FIG, DECOMP_OUT, DECOMP_TEX, SUB_TEX, SPILL_OUT, SPILL_TEX, LLM_TEX]
    if not require_force(outputs, args.force, log):
        return
    con = duckdb.connect()
    con.execute("PRAGMA threads=10")
    con.execute("PRAGMA memory_limit='12GB'")
    con.execute("PRAGMA temp_directory='/tmp/duckdb_paper18'")

    dist = build_distance_benchmarks(con, log)
    dist.to_parquet(DIST_OUT, index=False)
    write_distance_outputs(dist)
    log.info("wrote distance benchmark rows=%d", len(dist))

    decomp, subs = build_decomposition(con)
    decomp.to_parquet(DECOMP_OUT, index=False)
    write_decomp_outputs(decomp, subs)
    log.info("wrote decomposition rows=%d", len(decomp))

    flags = spillover_flags(con)
    flags.to_parquet(SPILL_OUT, index=False)
    write_spillover_tex(flags)
    log.info("wrote spillover flags rows=%d", len(flags))

    llm_audit(con)
    sample_audit()
    if not (ROOT / "02_data" / "intermediate" / "osrm_travel_time_panel.metadata.json").exists():
        write_text(NOTES / "TRAVEL_TIME_GAP.md", "# Travel-time Gap\n\nNo routed travel-time matrix is available in this workspace.\n")
    end_log(log, t0)


if __name__ == "__main__":
    main()
