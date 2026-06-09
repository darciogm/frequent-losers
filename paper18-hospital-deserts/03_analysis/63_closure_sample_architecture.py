from __future__ import annotations

from datetime import datetime
from pathlib import Path

import duckdb
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from revision_utils import (
    FIG,
    INTER,
    PROC,
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


SCRIPT = "63_closure_sample_architecture"

MASTER_PARQUET = PROC / "master_closure_sample_table.parquet"
MASTER_CSV = PROC / "master_closure_sample_table.csv"
MASTER_TEX = TAB / "table_master_closure_samples.tex"
EXPOSURE_LONG = PROC / "closure_sample_exposure_flags_long.parquet"
DISAGREE_F5 = PROC / "flow_distance_disagreement_f5.parquet"
DISAGREE_TEX = TAB / "table_flow_distance_disagreement_f5.tex"
DISAGREE_BY_TEX = TAB / "table_flow_distance_by_type_region.tex"
DISAGREE_FIG = FIG / "fig_flow_distance_disagreement_f5.pdf"
FAILED_PARQUET = PROC / "failed_f5_predecline_closures.parquet"
FAILED_TEX = TAB / "table_f5_vs_failed_f5_diagnostics.tex"
FAILED_FIG = FIG / "fig_f5_filter_admission_trajectories.pdf"
FIRST_STAGE_PANEL = PROC / "first_stage_sample_panels.parquet"

PNASH_EXPR = (
    "(year_closure >= 2006 and year_closure <= 2009) or "
    "(year_closure >= 2010 and year_closure <= 2013) or "
    "(year_closure >= 2014 and year_closure <= 2017)"
)

TYPE_LABELS = {
    "05": "general hospital",
    "07": "specialized/psychiatric hospital",
    "15": "mixed unit",
    "62": "hospital day",
}

CAPITALS = {
    "110020", "120040", "130260", "140010", "150140", "160030", "172100",
    "211130", "221100", "230440", "240810", "250750", "261160", "270430",
    "280030", "292740", "310620", "320530", "330455", "355030", "410690",
    "420540", "431490", "500270", "510340", "520870", "530010",
}


def macroregion(codmun: str) -> str:
    first = str(codmun)[0]
    return {
        "1": "North",
        "2": "Northeast",
        "3": "Southeast",
        "4": "South",
        "5": "Center-West",
    }.get(first, "Unknown")


def haversine_km(lat1, lon1, lat2, lon2):
    lat1r = np.deg2rad(lat1)
    lat2r = np.deg2rad(lat2)
    dlat = lat2r - lat1r
    dlon = np.deg2rad(lon2 - lon1)
    a = np.sin(dlat / 2) ** 2 + np.cos(lat1r) * np.cos(lat2r) * np.sin(dlon / 2) ** 2
    return 2 * 6371.0 * np.arcsin(np.sqrt(np.clip(a, 0, 1)))


def sample_masks(closures: pd.DataFrame) -> dict[str, pd.Series]:
    f4 = closures["f1_window"] & closures["f2_type"] & closures["f3_beds"] & closures["f4_mass"]
    pnash = (
        closures["f1_window"]
        & closures["f2_type"]
        & closures["f3_beds"]
        & closures["f4_mass"]
        & (closures["tp_unid"] == "07")
        & (
            closures["year_closure"].between(2006, 2009)
            | closures["year_closure"].between(2010, 2013)
            | closures["year_closure"].between(2014, 2017)
        )
    )
    return {
        "raw_cnes_exit": closures["CNES"].notna(),
        "candidate_nonpandemic_closures": closures["f1_window"],
        "hospital_grade_closures": closures["f1_window"] & closures["f2_type"],
        "bed_and_volume_filtered": f4,
        "f5_economically_meaningful_closures": closures["exogenous"],
        "pnash_psychiatric_closures": pnash,
        "general_hospital_f5_closures": closures["exogenous"] & (closures["tp_unid"] == "05"),
        "hospital_day_f5_closures": closures["exogenous"] & (closures["tp_unid"] == "62"),
        "nonpsychiatric_f5_closures": closures["exogenous"] & (closures["tp_unid"] != "07"),
        "failed_f5_predecline_closures": f4 & (~closures["f5_not_demand_driven"]),
    }


SAMPLE_META = {
    "raw_cnes_exit": (
        "Raw CNES exits",
        "CNES establishments that cease reporting before the panel end.",
        "audit only",
        "secondary",
        "no",
    ),
    "candidate_nonpandemic_closures": (
        "Candidate non-pandemic closures",
        "Raw exits in non-pandemic closure windows used by the filter.",
        "sample-construction audit",
        "secondary",
        "no",
    ),
    "hospital_grade_closures": (
        "Hospital-grade closures",
        "Non-pandemic exits with hospital-grade establishment types.",
        "sample-construction audit",
        "secondary",
        "no",
    ),
    "bed_and_volume_filtered": (
        "Bed- and volume-filtered closures",
        "Hospital-grade closures with at least 30 SUS beds and 100 AIH in the pre-closure year.",
        "sample-construction audit",
        "secondary",
        "no",
    ),
    "f5_economically_meaningful_closures": (
        "F5 economically meaningful closures",
        "Bed- and volume-filtered closures without a greater-than-50 percent pre-closure admission decline.",
        "main measurement sample",
        "main measurement",
        "no",
    ),
    "pnash_psychiatric_closures": (
        "PNASH psychiatric closures",
        "Psychiatric/specialized closures in PNASH cycle windows; F5 demand-decline filter relaxed.",
        "main causal mortality sample",
        "main causal",
        "yes",
    ),
    "general_hospital_f5_closures": (
        "General-hospital F5 closures",
        "F5 closures with CNES establishment type 05.",
        "contrast evidence",
        "secondary",
        "no",
    ),
    "hospital_day_f5_closures": (
        "Hospital-day F5 closures",
        "F5 closures with CNES establishment type 62.",
        "contrast evidence",
        "secondary",
        "no",
    ),
    "nonpsychiatric_f5_closures": (
        "Nonpsychiatric F5 closures",
        "General-hospital plus hospital-day F5 closures.",
        "contrast evidence",
        "secondary",
        "no",
    ),
    "failed_f5_predecline_closures": (
        "Failed-F5 predecline closures",
        "Bed- and volume-filtered closures whose pre-closure admissions fell below 50 percent of the prior three-year average.",
        "endogeneity diagnostic",
        "diagnostic",
        "no",
    ),
}


def build_exposure_flags(closures: pd.DataFrame, logger) -> pd.DataFrame:
    edges = pd.read_parquet(INTER / "bipartite_edges.parquet", columns=["codmun_6", "CNES", "year", "n_internacoes"])
    totals = edges.groupby(["year", "codmun_6"], as_index=False)["n_internacoes"].sum().rename(columns={"n_internacoes": "denom"})
    to_h = edges.groupby(["year", "CNES", "codmun_6"], as_index=False)["n_internacoes"].sum().rename(columns={"n_internacoes": "num"})
    cent = pd.read_parquet(INTER / "municipios_centroids.parquet", columns=["cod_mun_6", "uf", "lat", "lon"])
    cent = cent.dropna(subset=["lat", "lon"]).rename(columns={"cod_mun_6": "codmun_6"})
    loc = cent.set_index("codmun_6")[["lat", "lon", "uf"]].to_dict("index")
    muni_codes = cent["codmun_6"].to_numpy()
    muni_lat = cent["lat"].to_numpy(dtype=float)
    muni_lon = cent["lon"].to_numpy(dtype=float)
    hosp_master = pd.read_parquet(INTER / "hospital_master.parquet", columns=["CNES", "codmun_6_modal"])
    hosp_loc = hosp_master.set_index("CNES")["codmun_6_modal"].to_dict()

    rows = []
    total_by_year = {year: frame for year, frame in totals.groupby("year")}
    edge_groups = {key: frame for key, frame in to_h.groupby(["year", "CNES"])}
    closures_work = closures[closures["year_closure"].notna()].copy()
    logger.info("building generic flow/distance exposure flags for %d closures", len(closures_work))
    for idx, c in closures_work.iterrows():
        cnes = c["CNES"]
        year = int(c["year_closure"])
        year_pre = year - 1
        total = total_by_year.get(year_pre)
        flow_set = set()
        flow_values: dict[str, tuple[float, float, float]] = {}
        if total is not None:
            num = edge_groups.get((year_pre, cnes))
            if num is not None and not num.empty:
                m = total.merge(num[["codmun_6", "num"]], on="codmun_6", how="left")
                m["num"] = m["num"].fillna(0)
                m["share"] = m["num"] / m["denom"].replace(0, np.nan)
                m = m[m["num"] > 0]
                for r in m.itertuples(index=False):
                    share = 0 if pd.isna(r.share) else float(r.share)
                    if share >= 0.05:
                        flow_set.add(r.codmun_6)
                    flow_values[r.codmun_6] = (float(r.num), float(r.denom), share)

        distance_set = set()
        cod_h = c.get("codmun_6") or hosp_loc.get(cnes)
        if cod_h in loc:
            h = loc[cod_h]
            d = haversine_km(h["lat"], h["lon"], muni_lat, muni_lon)
            order = np.argsort(d)[: min(4, len(d))]
            distance_set = set(muni_codes[order])

        for m in sorted(flow_set | distance_set):
            num, denom, share = flow_values.get(m, (0.0, np.nan, 0.0))
            rows.append(
                {
                    "CNES": cnes,
                    "year_closure": year,
                    "tp_unid": c["tp_unid"],
                    "codmun_hosp": c.get("codmun_6"),
                    "municipality": m,
                    "uf": loc.get(m, {}).get("uf", ""),
                    "macroregion": macroregion(m),
                    "is_capital": m in CAPITALS,
                    "flow_numerator": num,
                    "flow_denominator": denom,
                    "flow_share": share,
                    "flow_exposed": m in flow_set,
                    "distance_exposed": m in distance_set,
                }
            )
        if (idx + 1) % 500 == 0:
            logger.info("processed %d closures; exposure rows=%d", idx + 1, len(rows))
    return pd.DataFrame(rows)


def sample_membership(closures: pd.DataFrame, exposure: pd.DataFrame) -> pd.DataFrame:
    masks = sample_masks(closures)
    frames = []
    for sid, mask in masks.items():
        ids = set(closures.loc[mask, "CNES"])
        d = exposure[exposure["CNES"].isin(ids)].copy()
        d["sample_id"] = sid
        frames.append(d)
    return pd.concat(frames, ignore_index=True) if frames else pd.DataFrame()


def write_master_table(closures: pd.DataFrame, exposure_long: pd.DataFrame) -> pd.DataFrame:
    masks = sample_masks(closures)
    rows = []
    for sid, mask in masks.items():
        label, definition, used_for, role, pnash = SAMPLE_META[sid]
        c = closures.loc[mask].copy()
        e = exposure_long[exposure_long["sample_id"] == sid]
        flow = e[e["flow_exposed"]]
        dist = e[e["distance_exposed"]]
        types = ", ".join(
            f"{k} {TYPE_LABELS.get(k, '')}".strip()
            for k in sorted(c["tp_unid"].dropna().astype(str).unique())
        )
        years = ""
        if not c.empty:
            years = f"{int(c.year_closure.min())}-{int(c.year_closure.max())}"
        rows.append(
            {
                "sample_id": sid,
                "sample_label_for_paper": label,
                "definition": definition,
                "used_for": used_for,
                "number_of_closures": int(len(c)),
                "number_of_unique_cnes": int(c["CNES"].nunique()),
                "number_of_municipality_closure_pairs_flow": int(len(flow)),
                "number_of_unique_flow_exposed_municipalities": int(flow["municipality"].nunique()),
                "number_of_municipality_closure_pairs_distance": int(len(dist)),
                "facility_types_included": types,
                "years_included": years,
                "psychiatric_only": "yes" if (not c.empty and set(c["tp_unid"].dropna().astype(str)) == {"07"}) else "no",
                "PNASH_anchored": pnash,
                "main_or_secondary": role,
                "notes": "",
            }
        )
    out = pd.DataFrame(rows)
    out.to_parquet(MASTER_PARQUET, index=False)
    out.to_csv(MASTER_CSV, index=False)

    lines = [
        "\\begin{table}[!htbp]\\centering",
        "\\caption{Closure samples and their role in the paper}",
        "\\label{tab:master-closure-samples}",
        "\\scriptsize",
        "\\resizebox{\\textwidth}{!}{%",
        "\\begin{tabular}{p{0.18\\textwidth}p{0.32\\textwidth}p{0.19\\textwidth}rrrrp{0.12\\textwidth}p{0.08\\textwidth}}",
        "\\toprule",
        "Sample & Definition & Used for & Closures & CNES & Flow pairs & Flow munis & Role & PNASH \\\\",
        "\\midrule",
    ]
    for r in out.itertuples(index=False):
        lines.append(
            f"{latex_escape(r.sample_label_for_paper)} & {latex_escape(r.definition)} & "
            f"{latex_escape(r.used_for)} & {r.number_of_closures} & {r.number_of_unique_cnes} & "
            f"{r.number_of_municipality_closure_pairs_flow} & {r.number_of_unique_flow_exposed_municipalities} & "
            f"{latex_escape(r.main_or_secondary)} & {latex_escape(r.PNASH_anchored)} \\\\"
        )
    lines.extend(
        [
            "\\bottomrule",
            "\\multicolumn{9}{p{0.98\\textwidth}}{\\footnotesize Notes: Flow pairs use the pre-closure patient-flow threshold $\\theta=0.05$. Distance pairs use the top-three nearest-hospital benchmark, including the hospital municipality when applicable. The F5 sample is the measurement sample; PNASH psychiatric closures are the main causal mortality sample.}\\\\",
            "\\end{tabular}",
            "}%",
            "\\end{table}",
        ]
    )
    write_text(MASTER_TEX, "\n".join(lines) + "\n")
    return out


def write_disagreement_outputs(exposure_long: pd.DataFrame) -> None:
    f5 = exposure_long[exposure_long["sample_id"] == "f5_economically_meaningful_closures"].copy()
    f5["both"] = f5["flow_exposed"] & f5["distance_exposed"]
    f5["flow_only"] = f5["flow_exposed"] & ~f5["distance_exposed"]
    f5["distance_only"] = ~f5["flow_exposed"] & f5["distance_exposed"]
    f5["misclassified"] = f5["flow_only"] | f5["distance_only"]
    f5.to_parquet(DISAGREE_F5, index=False)

    total = int((f5["flow_exposed"] | f5["distance_exposed"]).sum())
    flow_only = int(f5["flow_only"].sum())
    distance_only = int(f5["distance_only"].sum())
    both = int(f5["both"].sum())
    mis = flow_only + distance_only
    lines = [
        "\\begin{table}[!htbp]\\centering",
        "\\caption{Flow versus distance exposure in the full F5 closure sample}",
        "\\label{tab:flow-distance-disagreement-f5}",
        "\\small",
        "\\begin{tabular}{lrr}",
        "\\toprule",
        "Classification & Pairs & Share of union \\\\",
        "\\midrule",
        f"Flow only & {flow_only} & {flow_only / total:.3f} \\\\",
        f"Distance only & {distance_only} & {distance_only / total:.3f} \\\\",
        f"Both & {both} & {both / total:.3f} \\\\",
        f"Misclassified by one rule relative to the other & {mis} & {mis / total:.3f} \\\\",
        f"Flagged by either rule & {total} & 1.000 \\\\",
        "\\bottomrule",
        "\\end{tabular}",
        "\\end{table}",
    ]
    write_text(DISAGREE_TEX, "\n".join(lines) + "\n")

    by = []
    for group, d in list(f5.groupby("tp_unid")) + list(f5.groupby("macroregion")):
        union = d["flow_exposed"] | d["distance_exposed"]
        if union.sum() == 0:
            continue
        by.append(
            {
                "group": TYPE_LABELS.get(str(group), str(group)),
                "closures": d["CNES"].nunique(),
                "flow_only": int(d["flow_only"].sum()),
                "distance_only": int(d["distance_only"].sum()),
                "both": int(d["both"].sum()),
                "union": int(union.sum()),
                "mis_share": float(d["misclassified"].sum() / union.sum()),
            }
        )
    bydf = pd.DataFrame(by)
    lines = [
        "\\begin{table}[!htbp]\\centering",
        "\\caption{Flow-distance disagreement by hospital type and macroregion}",
        "\\label{tab:flow-distance-by-type-region}",
        "\\small",
        "\\begin{tabular}{lrrrrr}",
        "\\toprule",
        "Group & Closures & Flow only & Distance only & Both & Misclassification share \\\\",
        "\\midrule",
    ]
    for r in bydf.itertuples(index=False):
        lines.append(f"{latex_escape(r.group)} & {r.closures} & {r.flow_only} & {r.distance_only} & {r.both} & {r.mis_share:.3f} \\\\")
    lines.extend(["\\bottomrule", "\\end{tabular}", "\\end{table}"])
    write_text(DISAGREE_BY_TEX, "\n".join(lines) + "\n")

    fig, ax = plt.subplots(figsize=(7.2, 4.2))
    plotdf = bydf.sort_values("mis_share", ascending=False)
    ax.bar(plotdf["group"], plotdf["mis_share"], color="#0072B2")
    ax.set_ylabel("Misclassification share")
    ax.set_ylim(0, 1)
    ax.tick_params(axis="x", rotation=35, labelsize=8)
    fig.tight_layout()
    fig.savefig(DISAGREE_FIG)
    plt.close(fig)


def write_failed_f5_outputs(closures: pd.DataFrame, logger) -> None:
    masks = sample_masks(closures)
    failed = closures.loc[masks["failed_f5_predecline_closures"]].copy()
    failed.to_parquet(FAILED_PARQUET, index=False)

    edges = pd.read_parquet(INTER / "bipartite_edges.parquet", columns=["CNES", "year", "n_internacoes"])
    annual = edges.groupby(["CNES", "year"], as_index=False)["n_internacoes"].sum()
    groups = {
        "retained F5": closures.loc[masks["f5_economically_meaningful_closures"], ["CNES", "year_closure"]],
        "failed F5 predecline": failed[["CNES", "year_closure"]],
    }
    traj = []
    for label, cdf in groups.items():
        merged = cdf.merge(annual, on="CNES", how="left")
        merged["rel_year"] = merged["year"] - merged["year_closure"]
        merged = merged[merged["rel_year"].between(-4, -1)]
        baseline = merged[merged["rel_year"].between(-4, -2)].groupby("CNES")["n_internacoes"].mean().rename("base")
        merged = merged.merge(baseline, on="CNES", how="left")
        merged["aih_index"] = merged["n_internacoes"] / merged["base"]
        merged["sample"] = label
        traj.append(merged)
    t = pd.concat(traj, ignore_index=True)
    agg = t.groupby(["sample", "rel_year"], as_index=False)["aih_index"].mean()
    fig, ax = plt.subplots(figsize=(6.2, 4))
    for label, d in agg.groupby("sample"):
        ax.plot(d["rel_year"], d["aih_index"], marker="o", label=label)
    ax.axhline(1, color="gray", linestyle="--", linewidth=0.8)
    ax.set_xlabel("Years relative to formal closure")
    ax.set_ylabel("Admissions index (mean years -4 to -2 = 1)")
    ax.legend()
    fig.tight_layout()
    fig.savefig(FAILED_FIG)
    plt.close(fig)

    diag = []
    for label, cdf in groups.items():
        d = closures[closures["CNES"].isin(cdf["CNES"])]
        diag.append(
            {
                "sample": label,
                "closures": len(d),
                "mean_ratio_pre": d["ratio_pre"].mean(),
                "median_ratio_pre": d["ratio_pre"].median(),
                "mean_pre_year_aih": d["n_int_t_minus_1"].mean(),
                "median_pre_year_aih": d["n_int_t_minus_1"].median(),
            }
        )
    diagdf = pd.DataFrame(diag)
    lines = [
        "\\begin{table}[!htbp]\\centering",
        "\\caption{Why the F5 pre-decline filter matters}",
        "\\label{tab:f5-vs-failed-f5-diagnostics}",
        "\\small",
        "\\begin{tabular}{lrrrrr}",
        "\\toprule",
        "Sample & Closures & Mean pre-ratio & Median pre-ratio & Mean AIH $t-1$ & Median AIH $t-1$ \\\\",
        "\\midrule",
    ]
    for r in diagdf.itertuples(index=False):
        lines.append(
            f"{latex_escape(r.sample)} & {r.closures} & {r.mean_ratio_pre:.2f} & {r.median_ratio_pre:.2f} & {r.mean_pre_year_aih:.1f} & {r.median_pre_year_aih:.1f} \\\\"
        )
    lines.extend(
        [
            "\\bottomrule",
            "\\multicolumn{6}{p{0.82\\textwidth}}{\\footnotesize Notes: The pre-ratio is admissions in year $t-1$ divided by the mean over years $t-4$ to $t-2$. Failed-F5 closures pass bed and volume screens but fail the no-large-predecline screen.}\\\\",
            "\\end{tabular}",
            "\\end{table}",
        ]
    )
    write_text(FAILED_TEX, "\n".join(lines) + "\n")
    logger.info("failed-F5 closures=%d", len(failed))


def build_first_stage_panel(exposure_long: pd.DataFrame) -> None:
    samples = [
        "f5_economically_meaningful_closures",
        "pnash_psychiatric_closures",
        "nonpsychiatric_f5_closures",
        "failed_f5_predecline_closures",
    ]
    travel = pd.read_parquet(INTER / "travel_burden_panel.parquet", columns=["codmun_6", "year", "travel_burden_km"])
    cent = pd.read_parquet(INTER / "municipios_centroids.parquet", columns=["cod_mun_6", "uf"]).rename(columns={"cod_mun_6": "codmun_6"})
    base = cent.merge(pd.DataFrame({"year": range(2010, 2025)}), how="cross")
    base = base.merge(travel, on=["codmun_6", "year"], how="left")
    muni_id = {m: i + 1 for i, m in enumerate(sorted(base["codmun_6"].unique()))}
    base["muni_id"] = base["codmun_6"].map(muni_id)
    frames = []
    for sid in samples:
        e = exposure_long[exposure_long["sample_id"] == sid]
        for rule, col in [("flow", "flow_exposed"), ("distance", "distance_exposed")]:
            g = e[e[col]].groupby("municipality", as_index=False)["year_closure"].min().rename(columns={"municipality": "codmun_6", "year_closure": "g"})
            p = base.merge(g, on="codmun_6", how="left")
            p["g"] = p["g"].fillna(10000).astype(int)
            p["sample_id"] = sid
            p["exposure_rule"] = rule
            p["rel_year"] = np.where(p["g"] < 10000, p["year"] - p["g"], np.nan)
            frames.append(p)
    pd.concat(frames, ignore_index=True).to_parquet(FIRST_STAGE_PANEL, index=False)


def main() -> None:
    args = parse_args("Build closure-sample architecture outputs")
    ensure_dirs()
    logger = logger_for(SCRIPT)
    outputs = [
        MASTER_PARQUET,
        MASTER_CSV,
        MASTER_TEX,
        EXPOSURE_LONG,
        DISAGREE_F5,
        DISAGREE_TEX,
        DISAGREE_BY_TEX,
        DISAGREE_FIG,
        FAILED_PARQUET,
        FAILED_TEX,
        FAILED_FIG,
        FIRST_STAGE_PANEL,
    ]
    if not require_force(outputs, args.force, logger):
        return
    t0 = begin_log(logger, SCRIPT, seeds=[])
    closures = pd.read_parquet(INTER / "hospital_closures_exogenous.parquet")
    exposure = build_exposure_flags(closures, logger)
    exposure_long = sample_membership(closures, exposure)
    exposure_long.to_parquet(EXPOSURE_LONG, index=False)
    master = write_master_table(closures, exposure_long)
    write_disagreement_outputs(exposure_long)
    write_failed_f5_outputs(closures, logger)
    build_first_stage_panel(exposure_long)
    logger.info("master_counts=%s", master[["sample_id", "number_of_closures", "number_of_unique_flow_exposed_municipalities"]].to_dict("records"))
    logger.info("outputs_date=%s", datetime.now().strftime("%Y%m%d"))
    end_log(logger, t0)


if __name__ == "__main__":
    main()
