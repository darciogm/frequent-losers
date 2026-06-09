from __future__ import annotations

import glob

import duckdb
import numpy as np
import pandas as pd

from revision_utils import (
    FIG,
    INTER,
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


SCRIPT = "51_build_exposure_variants"
OUT = PROC / "exposure_variants_long.parquet"
DIAG_TEX = TAB / "table_exposure_definition_diagnostics.tex"
DIST_FIG = FIG / "fig_exposure_share_distribution.pdf"
OVERLAP_FIG = FIG / "fig_exposure_definition_overlap.pdf"

PNASH_WHERE = (
    "f1_window AND f2_type AND f3_beds AND f4_mass AND tp_unid='07' AND "
    "(year_closure BETWEEN 2006 AND 2009 OR year_closure BETWEEN 2010 AND 2013 "
    "OR year_closure BETWEEN 2014 AND 2017)"
)
THRESHOLDS = [0.01, 0.025, 0.05, 0.10, 0.20]


def raw_sih_files(years: range) -> list[str]:
    files: list[str] = []
    for year in years:
        yy = f"{year % 100:02d}"
        files.extend(glob.glob(str(ROOT / "02_data" / "raw" / "sih_rd" / f"rd*{yy}??.parquet")))
    return sorted(files)


def list_sql(files: list[str]) -> str:
    return "[" + ", ".join(f"'{f}'" for f in files) + "]"


def build_psych_edges(con: duckdb.DuckDBPyConnection, files: list[str], logger) -> bool:
    if not files:
        logger.warning("no raw SIH files found; psychiatric-specific exposure variants will be unavailable")
        return False
    try:
        con.execute(f"""
            CREATE OR REPLACE TEMP TABLE psych_edges AS
            SELECT
                LPAD(MUNIC_RES, 6, '0') AS codmun_6,
                CNES,
                CAST(ANO_CMPT AS INTEGER) AS year,
                SUM(CASE WHEN SUBSTR(DIAG_PRINC, 1, 1) = 'F' THEN 1 ELSE 0 END) AS psych_admissions,
                SUM(CASE WHEN SUBSTR(DIAG_PRINC, 1, 1) = 'F' THEN COALESCE(DIAS_PERM, 0) ELSE 0 END) AS psych_beddays,
                SUM(CASE WHEN SUBSTR(DIAG_PRINC, 1, 1) = 'F' THEN COALESCE(VAL_TOT, 0) ELSE 0 END) AS psych_aih_value,
                SUM(CASE WHEN SUBSTR(DIAG_PRINC, 1, 1) = 'F' THEN 1 ELSE 0 END) AS psych_patient_count,
                SUM(CASE
                    WHEN SUBSTR(DIAG_PRINC, 1, 1) = 'F'
                      OR SUBSTR(DIAG_PRINC, 1, 3) BETWEEN 'X60' AND 'X84'
                      OR SUBSTR(DIAG_PRINC, 1, 4) = 'Y870'
                    THEN 1 ELSE 0 END) AS mental_health_admissions
            FROM read_parquet({list_sql(files)}, union_by_name=true)
            WHERE MUNIC_RES IS NOT NULL
              AND CNES IS NOT NULL
              AND ANO_CMPT IS NOT NULL
              AND CAST(ANO_CMPT AS INTEGER) BETWEEN 2010 AND 2024
              AND (
                  SUBSTR(DIAG_PRINC, 1, 1) = 'F'
                  OR SUBSTR(DIAG_PRINC, 1, 3) BETWEEN 'X60' AND 'X84'
                  OR SUBSTR(DIAG_PRINC, 1, 4) = 'Y870'
              )
            GROUP BY 1, 2, 3
        """)
        n = con.sql("SELECT COUNT(*) FROM psych_edges").fetchone()[0]
        logger.info("built psych_edges rows=%d", n)
        return n > 0
    except Exception as exc:
        logger.warning("could not build psych_edges from raw SIH: %s", exc)
        return False


def build_rows_for_metric(
    con: duckdb.DuckDBPyConnection,
    closures: pd.DataFrame,
    metric: str,
    definition: str,
    window_label: str,
    years_offset: list[int],
    source: str,
) -> pd.DataFrame:
    frames = []
    for _, c in closures.iterrows():
        years = [int(c.year_closure) + off for off in years_offset]
        year_list = ", ".join(str(y) for y in years)
        cnes = c.CNES
        if source == "all_edges":
            table = f"read_parquet('{INTER / 'bipartite_edges.parquet'}')"
            metric_expr = {
                "n_internacoes": "SUM(n_internacoes)",
                "val_tot_soma": "SUM(val_tot_soma)",
                "beddays_proxy": "SUM(n_internacoes * dias_perm_medio)",
            }[metric]
        else:
            table = "psych_edges"
            metric_expr = f"SUM({metric})"
        query = f"""
            WITH edge AS (
                SELECT codmun_6, CNES, {metric_expr} AS value
                FROM {table}
                WHERE year IN ({year_list})
                GROUP BY codmun_6, CNES
            ),
            denom AS (
                SELECT codmun_6, SUM(value) AS denominator
                FROM edge GROUP BY codmun_6
            ),
            num AS (
                SELECT codmun_6, SUM(value) AS numerator
                FROM edge WHERE CNES='{cnes}' GROUP BY codmun_6
            )
            SELECT 'pnash48' AS sample_id, '{cnes}' AS cnes,
                   {int(c.year_closure)} AS closure_year,
                   d.codmun_6 AS municipality,
                   '{definition}' AS exposure_definition,
                   '{window_label}' AS exposure_window,
                   COALESCE(n.numerator, 0) AS numerator,
                   d.denominator AS denominator,
                   COALESCE(n.numerator, 0) * 1.0 / NULLIF(d.denominator, 0) AS share
            FROM denom d LEFT JOIN num n USING (codmun_6)
            WHERE COALESCE(n.numerator, 0) > 0
        """
        frames.append(con.sql(query).df())
    if not frames:
        return pd.DataFrame()
    out = pd.concat(frames, ignore_index=True)
    for th in THRESHOLDS:
        suffix = {0.01: "001", 0.025: "0025", 0.05: "005", 0.10: "010", 0.20: "020"}[th]
        out[f"treated_{suffix}"] = out["share"] >= th
    return out


def build_exposures(con: duckdb.DuckDBPyConnection, logger) -> pd.DataFrame:
    closures = con.sql(f"""
        SELECT CNES, year_closure
        FROM read_parquet('{INTER / "hospital_closures_exogenous.parquet"}')
        WHERE {PNASH_WHERE}
    """).df()
    windows = {
        "yminus1": [-1],
        "avg_yminus3_to_yminus1": [-3, -2, -1],
        "avg_yminus4_to_yminus2": [-4, -3, -2],
    }
    frames = []
    for label, offsets in windows.items():
        frames.append(build_rows_for_metric(con, closures, "n_internacoes", "flow_all_admissions", label, offsets, "all_edges"))
        frames.append(build_rows_for_metric(con, closures, "val_tot_soma", "flow_all_aih_value", label, offsets, "all_edges"))
        frames.append(build_rows_for_metric(con, closures, "beddays_proxy", "flow_all_beddays_proxy", label, offsets, "all_edges"))
    files = raw_sih_files(range(2010, 2025))
    logger.info("raw SIH files for psychiatric exposure scan=%d", len(files))
    if build_psych_edges(con, files, logger):
        for label, offsets in windows.items():
            frames.append(build_rows_for_metric(con, closures, "psych_admissions", "flow_psych_admissions", label, offsets, "psych_edges"))
            frames.append(build_rows_for_metric(con, closures, "psych_beddays", "flow_psych_beddays", label, offsets, "psych_edges"))
            frames.append(build_rows_for_metric(con, closures, "psych_aih_value", "flow_psych_aih_value", label, offsets, "psych_edges"))
            frames.append(build_rows_for_metric(con, closures, "psych_patient_count", "flow_psych_patient_count", label, offsets, "psych_edges"))
            frames.append(build_rows_for_metric(con, closures, "mental_health_admissions", "flow_mental_health_admissions", label, offsets, "psych_edges"))
    out = pd.concat([f for f in frames if f is not None and not f.empty], ignore_index=True)
    return out


def diagnostics(df: pd.DataFrame) -> pd.DataFrame:
    rows = []
    main = df[(df["exposure_definition"] == "flow_all_admissions") & (df["exposure_window"] == "yminus1")]
    main_set = set(zip(main.loc[main["treated_005"], "cnes"], main.loc[main["treated_005"], "municipality"]))
    for (definition, window), d in df.groupby(["exposure_definition", "exposure_window"]):
        treated = d[d["treated_005"]]
        this_set = set(zip(treated["cnes"], treated["municipality"]))
        union = len(main_set | this_set)
        rows.append({
            "exposure_definition": definition,
            "exposure_window": window,
            "positive_pairs": int(len(d)),
            "treated_pairs_theta005": int(len(treated)),
            "treated_municipalities_theta005": int(treated["municipality"].nunique()),
            "median_share_positive": float(d["share"].median()) if len(d) else np.nan,
            "p90_share_positive": float(d["share"].quantile(0.9)) if len(d) else np.nan,
            "jaccard_vs_all_yminus1_theta005": float(len(main_set & this_set) / union) if union else np.nan,
            **{f"treated_pairs_theta{str(th).replace('.', '')}": int(d[f"treated_{ {0.01:'001',0.025:'0025',0.05:'005',0.10:'010',0.20:'020'}[th]}"].sum()) for th in THRESHOLDS},
        })
    return pd.DataFrame(rows)


def write_diag_tex(diag: pd.DataFrame) -> None:
    definition_labels = {
        "flow_all_admissions": "All adm.",
        "flow_all_aih_value": "All value",
        "flow_all_beddays_proxy": "All bed-days",
        "flow_psych_admissions": "Psych adm.",
        "flow_psych_beddays": "Psych bed-days",
        "flow_psych_aih_value": "Psych value",
        "flow_psych_patient_count": "Psych episodes",
        "flow_mental_health_admissions": "Mental-health adm.",
    }
    window_labels = {
        "yminus1": "$t-1$",
        "avg_yminus3_to_yminus1": "$t-3$--$t-1$",
        "avg_yminus4_to_yminus2": "$t-4$--$t-2$",
    }
    lines = [
        "\\begin{table}[!htbp]\\centering",
        "\\caption{Exposure-definition diagnostics for PNASH psychiatric closures}",
        "\\label{tab:exposure-definition-diagnostics}",
        "\\scriptsize",
        "\\resizebox{\\textwidth}{!}{%",
        "\\begin{tabular}{llrrrrr}",
        "\\toprule",
        "Definition & Window & Positive pairs & Treated pairs & Treated munis & Median share & Jaccard \\\\",
        "\\midrule",
    ]
    for _, r in diag.sort_values(["exposure_definition", "exposure_window"]).iterrows():
        lines.append(
            f"{latex_escape(definition_labels.get(r.exposure_definition, r.exposure_definition))} & "
            f"{window_labels.get(r.exposure_window, latex_escape(r.exposure_window))} & "
            f"{int(r.positive_pairs)} & {int(r.treated_pairs_theta005)} & "
            f"{int(r.treated_municipalities_theta005)} & {r.median_share_positive:.3f} & "
            f"{r.jaccard_vs_all_yminus1_theta005:.3f} \\\\"
        )
    lines.extend([
        "\\bottomrule",
        "\\multicolumn{7}{p{0.9\\textwidth}}{\\footnotesize Notes: treated pairs use $\\theta=0.05$. Jaccard overlap compares each definition to the existing all-SUS-admission share in year $-1$. Psychiatric patient count is an episode count because SIH does not provide a stable person identifier in these public files. Mental-health admissions include ICD-10 F diagnoses and self-harm diagnoses X60--X84/Y87.0.}\\\\",
        "\\end{tabular}",
        "}%",
        "\\end{table}",
    ])
    write_text(DIAG_TEX, "\n".join(lines) + "\n")


def make_figures(df: pd.DataFrame, diag: pd.DataFrame) -> None:
    import matplotlib.pyplot as plt

    plot_df = df[df["exposure_window"] == "yminus1"].copy()
    defs = list(plot_df["exposure_definition"].drop_duplicates())
    fig, axes = plt.subplots(len(defs), 1, figsize=(6.0, max(2.0, 1.25 * len(defs))), sharex=True)
    if len(defs) == 1:
        axes = [axes]
    for ax, definition in zip(axes, defs):
        vals = plot_df.loc[plot_df["exposure_definition"] == definition, "share"].clip(upper=1)
        ax.hist(vals, bins=30, color="#0072B2", alpha=0.8)
        ax.axvline(0.05, color="#666666", linestyle="--", linewidth=0.8)
        ax.set_ylabel(definition.replace("flow_", "").replace("_", " "), fontsize=7)
    axes[-1].set_xlabel("Positive pre-closure exposure share")
    fig.tight_layout()
    fig.savefig(DIST_FIG)
    plt.close(fig)

    overlap = diag[diag["exposure_window"] == "yminus1"].sort_values("jaccard_vs_all_yminus1_theta005")
    fig, ax = plt.subplots(figsize=(6.5, max(2.5, 0.32 * len(overlap))))
    labels = overlap["exposure_definition"].str.replace("flow_", "", regex=False).str.replace("_", " ", regex=False)
    ax.barh(labels, overlap["jaccard_vs_all_yminus1_theta005"], color="#009E73")
    ax.set_xlabel("Jaccard overlap with all-admission year -1 exposure")
    ax.set_xlim(0, 1)
    fig.tight_layout()
    fig.savefig(OVERLAP_FIG)
    plt.close(fig)


def main() -> None:
    args = parse_args("Build exposure-definition variants for the AEJ revision.")
    ensure_dirs()
    log = logger_for(SCRIPT)
    t0 = begin_log(log, SCRIPT)
    if not require_force([OUT, DIAG_TEX, DIST_FIG, OVERLAP_FIG], args.force, log):
        return

    con = duckdb.connect()
    con.execute("PRAGMA threads=10")
    con.execute("PRAGMA memory_limit='14GB'")
    con.execute("PRAGMA temp_directory='/tmp/duckdb_paper18'")
    df = build_exposures(con, log)
    df.to_parquet(OUT, index=False)
    diag = diagnostics(df)
    diag.to_csv(PROC / "exposure_definition_diagnostics.csv", index=False)
    write_diag_tex(diag)
    make_figures(df, diag)
    log.info("wrote exposure variants rows=%d definitions=%d", len(df), df["exposure_definition"].nunique())
    end_log(log, t0)


if __name__ == "__main__":
    main()
