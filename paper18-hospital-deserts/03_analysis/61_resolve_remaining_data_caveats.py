from __future__ import annotations

import glob
from pathlib import Path

import duckdb
import numpy as np
import pandas as pd
import pyarrow as pa
import pyarrow.compute as pc
import pyarrow.parquet as pq

from revision_utils import (
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


SCRIPT = "61_resolve_remaining_data_caveats"
EVENT = PROC / "pnash_event_level_dataset.parquet"
COV_OUT = PROC / "preclosure_sih_covariates.parquet"
CAPS_CIR_OUT = PROC / "cnes_caps_cir_municipality_year.parquet"
CAVEAT_TEX = TAB / "table_remaining_data_caveats.tex"
SIH_TEX = TAB / "table_preclosure_sih_covariates.tex"
GAPS = NOTES / "VARIABLE_GAPS.md"


def raw_sih_files(year_min: int, year_max: int) -> list[str]:
    files: list[str] = []
    for year in range(year_min, year_max + 1):
        yy = f"{year % 100:02d}"
        files.extend(glob.glob(str(ROOT / "02_data" / "raw" / "sih_rd" / f"rd*{yy}??.parquet")))
    return sorted(files)


def raw_cnes_st_december_files(year_min: int, year_max: int) -> list[str]:
    files: list[str] = []
    raw = ROOT / "02_data" / "raw" / "cnes_st"
    for year in range(year_min, year_max + 1):
        yy = f"{year % 100:02d}"
        files.extend(glob.glob(str(raw / f"st*{yy}12.parquet")))
    return sorted(files)


def list_sql(files: list[str]) -> str:
    return "[" + ", ".join(f"'{f}'" for f in files) + "]"


def build_sih_covariates(con: duckdb.DuckDBPyConnection, event: pd.DataFrame, logger) -> pd.DataFrame:
    year_min = int(max(2010, event["closure_year"].min() - 5))
    year_max = int(event["closure_year"].max() - 1)
    files = raw_sih_files(year_min, year_max)
    if not files:
        raise FileNotFoundError(f"no SIH parquet files found for {year_min}-{year_max}")
    logger.info("raw SIH files used for pre-closure covariates=%d years=%d-%d", len(files), year_min, year_max)

    closures = event[["CNES", "closure_year"]].drop_duplicates().copy()
    closures["CNES"] = closures["CNES"].astype(str)
    closures["closure_year"] = closures["closure_year"].astype(int)
    con.register("closures_df", closures)

    # Public SIH rows are authorizations/episodes. N_AIH is not a stable person id.
    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE sih_pre AS
        SELECT
            s.CNES,
            CAST(s.ANO_CMPT AS INTEGER) AS year,
            SUM(CASE WHEN SUBSTR(s.DIAG_PRINC, 1, 1) = 'F' THEN 1 ELSE 0 END) AS psych_admissions,
            SUM(CASE WHEN SUBSTR(s.DIAG_PRINC, 1, 1) = 'F' THEN COALESCE(s.DIAS_PERM, 0) ELSE 0 END) AS psych_beddays,
            SUM(CASE WHEN SUBSTR(s.DIAG_PRINC, 1, 1) = 'F' THEN COALESCE(s.VAL_TOT, 0) ELSE 0 END) AS psych_aih_value,
            SUM(CASE WHEN SUBSTR(s.DIAG_PRINC, 1, 1) = 'F' THEN 1 ELSE 0 END) AS psych_episodes,
            SUM(CASE
                WHEN SUBSTR(s.DIAG_PRINC, 1, 1) = 'F'
                  OR SUBSTR(s.DIAG_PRINC, 1, 3) BETWEEN 'X60' AND 'X84'
                  OR SUBSTR(s.DIAG_PRINC, 1, 4) = 'Y870'
                THEN 1 ELSE 0 END) AS mental_health_admissions,
            SUM(CASE WHEN s.CAR_INT = '02' AND SUBSTR(s.DIAG_PRINC, 1, 1) = 'F' THEN 1 ELSE 0 END) AS emergency_psych_admissions
        FROM read_parquet({list_sql(files)}, union_by_name=true) s
        SEMI JOIN closures_df c ON c.CNES = s.CNES
        WHERE s.CNES IS NOT NULL
          AND s.ANO_CMPT IS NOT NULL
          AND CAST(s.ANO_CMPT AS INTEGER) BETWEEN {year_min} AND {year_max}
        GROUP BY 1, 2
    """)

    out = con.sql("""
        WITH y1 AS (
            SELECT
                c.CNES,
                c.closure_year,
                COALESCE(s.psych_admissions, 0) AS psych_admissions_yminus1,
                COALESCE(s.psych_beddays, 0) AS psych_beddays_yminus1,
                COALESCE(s.psych_aih_value, 0) AS psych_aih_value_yminus1,
                COALESCE(s.psych_episodes, 0) AS psych_episodes_yminus1,
                COALESCE(s.mental_health_admissions, 0) AS mental_health_admissions_yminus1,
                COALESCE(s.emergency_psych_admissions, 0) AS emergency_psych_admissions_yminus1
            FROM closures_df c
            LEFT JOIN sih_pre s
              ON s.CNES = c.CNES AND s.year = c.closure_year - 1
        ),
        avg_pre AS (
            SELECT
                c.CNES,
                c.closure_year,
                COUNT(s.year) AS available_pre_years_sih,
                AVG(s.psych_admissions) AS psych_admissions_avg_pre,
                AVG(s.psych_beddays) AS psych_beddays_avg_pre,
                AVG(s.psych_aih_value) AS psych_aih_value_avg_pre,
                AVG(s.mental_health_admissions) AS mental_health_admissions_avg_pre,
                AVG(s.emergency_psych_admissions) AS emergency_psych_admissions_avg_pre
            FROM closures_df c
            LEFT JOIN sih_pre s
              ON s.CNES = c.CNES
             AND s.year BETWEEN c.closure_year - 3 AND c.closure_year - 1
            GROUP BY 1, 2
        )
        SELECT y1.*, avg_pre.available_pre_years_sih,
               avg_pre.psych_admissions_avg_pre,
               avg_pre.psych_beddays_avg_pre,
               avg_pre.psych_aih_value_avg_pre,
               avg_pre.mental_health_admissions_avg_pre,
               avg_pre.emergency_psych_admissions_avg_pre
        FROM y1
        JOIN avg_pre USING (CNES, closure_year)
        ORDER BY closure_year, CNES
    """).df()
    return out


def build_caps_cir_panel(event: pd.DataFrame, logger) -> pd.DataFrame:
    year_min = int(max(2010, event["closure_year"].min() - 2))
    year_max = int(event["closure_year"].max() - 1)
    files = raw_cnes_st_december_files(year_min, year_max)
    if not files:
        logger.warning("no CNES-ST December files found for CAPS/CIR panel")
        return pd.DataFrame(columns=["municipality", "year", "caps_facilities", "regsaude_modal"])

    logger.info("CNES-ST December files used for CAPS/CIR panel=%d years=%d-%d", len(files), year_min, year_max)
    frames = []
    cols = ["CNES", "CODUFMUN", "COMPETEN", "TP_UNID", "REGSAUDE"]
    for path in files:
        try:
            tab = pq.read_table(path, columns=cols)
            reg_idx = tab.schema.get_field_index("REGSAUDE")
            if reg_idx >= 0:
                tab = tab.set_column(reg_idx, "REGSAUDE", pc.cast(tab["REGSAUDE"], pa.binary()))
            df = tab.to_pandas()
            frames.append(df)
        except Exception as exc:
            logger.warning("skipping unreadable CNES-ST file %s: %s", path, exc)
    if not frames:
        return pd.DataFrame(columns=["municipality", "year", "caps_facilities", "regsaude_modal"])

    st = pd.concat(frames, ignore_index=True)
    st["municipality"] = st["CODUFMUN"].astype(str).str[:6]
    st["year"] = pd.to_numeric(st["COMPETEN"].astype(str).str[:4], errors="coerce").astype("Int64")
    st["CNES"] = st["CNES"].astype(str)
    st["TP_UNID"] = st["TP_UNID"].astype(str).str.zfill(2)
    def clean_text(value: object) -> str | float:
        if value is None or pd.isna(value):
            return np.nan
        if isinstance(value, bytes):
            return value.decode("latin1", errors="ignore").strip()
        return str(value).encode("utf-8", errors="ignore").decode("utf-8", errors="ignore").strip()

    st["REGSAUDE"] = st["REGSAUDE"].astype("object").map(clean_text)
    st.loc[st["REGSAUDE"].isin(["", "nan", "None"]), "REGSAUDE"] = np.nan

    caps = (
        st.loc[st["TP_UNID"].eq("70")]
        .groupby(["municipality", "year"], observed=True)["CNES"]
        .nunique()
        .rename("caps_facilities")
        .reset_index()
    )
    reg = (
        st.dropna(subset=["REGSAUDE"])
        .groupby(["municipality", "year"], observed=True)["REGSAUDE"]
        .agg(lambda x: x.mode().iloc[0] if not x.mode().empty else np.nan)
        .rename("regsaude_modal")
        .reset_index()
    )
    base = st[["municipality", "year"]].drop_duplicates()
    out = base.merge(caps, on=["municipality", "year"], how="left").merge(reg, on=["municipality", "year"], how="left")
    out["caps_facilities"] = out["caps_facilities"].fillna(0).astype(int)
    out = out.dropna(subset=["year"]).copy()
    out["year"] = out["year"].astype(int)
    return out.sort_values(["municipality", "year"]).reset_index(drop=True)


def update_event_dataset(event: pd.DataFrame, cov: pd.DataFrame) -> pd.DataFrame:
    out = event.drop(
        columns=[
            c
            for c in [
                "pre_closure_psychiatric_aih_value",
                "pre_closure_psychiatric_episodes",
                "pre_closure_mental_health_admissions",
                "pre_closure_emergency_psychiatric_admissions",
                "pre_closure_psychiatric_admissions_3y_avg",
                "pre_closure_psychiatric_beddays_3y_avg",
                "pre_closure_psychiatric_aih_value_3y_avg",
                "pre_closure_mental_health_admissions_3y_avg",
                "pre_closure_available_pre_years_sih",
            ]
            if c in event.columns
        ]
    )
    merged = out.merge(cov, on=["CNES", "closure_year"], how="left")
    merged["pre_closure_psychiatric_admissions"] = merged["psych_admissions_yminus1"]
    merged["pre_closure_psychiatric_beddays"] = merged["psych_beddays_yminus1"]
    merged["pre_closure_psychiatric_aih_value"] = merged["psych_aih_value_yminus1"]
    merged["pre_closure_psychiatric_episodes"] = merged["psych_episodes_yminus1"]
    merged["pre_closure_mental_health_admissions"] = merged["mental_health_admissions_yminus1"]
    merged["pre_closure_emergency_psychiatric_admissions"] = merged["emergency_psych_admissions_yminus1"]
    merged["pre_closure_psychiatric_admissions_3y_avg"] = merged["psych_admissions_avg_pre"]
    merged["pre_closure_psychiatric_beddays_3y_avg"] = merged["psych_beddays_avg_pre"]
    merged["pre_closure_psychiatric_aih_value_3y_avg"] = merged["psych_aih_value_avg_pre"]
    merged["pre_closure_mental_health_admissions_3y_avg"] = merged["mental_health_admissions_avg_pre"]
    merged["pre_closure_available_pre_years_sih"] = merged["available_pre_years_sih"]
    return merged.drop(
        columns=[
            "psych_admissions_yminus1",
            "psych_beddays_yminus1",
            "psych_aih_value_yminus1",
            "psych_episodes_yminus1",
            "mental_health_admissions_yminus1",
            "emergency_psych_admissions_yminus1",
            "available_pre_years_sih",
            "psych_admissions_avg_pre",
            "psych_beddays_avg_pre",
            "psych_aih_value_avg_pre",
            "mental_health_admissions_avg_pre",
            "emergency_psych_admissions_avg_pre",
        ],
        errors="ignore",
    )


def add_caps_cir_to_event(event: pd.DataFrame, caps_cir: pd.DataFrame) -> pd.DataFrame:
    if caps_cir.empty:
        return event
    lookup = caps_cir.rename(
        columns={
            "municipality": "municipality",
            "year": "pre_year",
            "caps_facilities": "pre_closure_caps_facilities_hospital_municipality",
            "regsaude_modal": "pre_closure_regsaude_hospital_municipality",
        }
    )
    out = event.drop(
        columns=[
            "pre_closure_caps_facilities_hospital_municipality",
            "pre_closure_regsaude_hospital_municipality",
        ],
        errors="ignore",
    ).copy()
    out["pre_year"] = out["closure_year"].astype(int) - 1
    out = out.merge(
        lookup,
        on=["municipality", "pre_year"],
        how="left",
    )
    if "pre_closure_caps_coverage_hospital_municipality" in out.columns:
        out["pre_closure_caps_coverage_hospital_municipality"] = out[
            "pre_closure_caps_facilities_hospital_municipality"
        ]
    return out.drop(columns=["pre_year"], errors="ignore")


def write_sih_tex(cov: pd.DataFrame) -> None:
    rows = [
        ("Psychiatric admissions, year $-1$", "psych_admissions_yminus1"),
        ("Psychiatric bed-days, year $-1$", "psych_beddays_yminus1"),
        ("Psychiatric AIH value, year $-1$", "psych_aih_value_yminus1"),
        ("Mental-health admissions, year $-1$", "mental_health_admissions_yminus1"),
        ("Emergency psychiatric admissions, year $-1$", "emergency_psych_admissions_yminus1"),
        ("Available SIH pre-years", "available_pre_years_sih"),
    ]
    lines = [
        "\\begin{table}[!htbp]\\centering",
        "\\caption{Resolved SIH pre-closure covariates for PNASH psychiatric closures}",
        "\\label{tab:preclosure-sih-covariates}",
        "\\small",
        "\\begin{tabular}{lrrrr}",
        "\\toprule",
        "Variable & Events & Mean & Median & P75 \\\\",
        "\\midrule",
    ]
    for label, col in rows:
        s = cov[col].replace([np.inf, -np.inf], np.nan).dropna()
        lines.append(
            f"{label} & {int(s.shape[0])} & {s.mean():.1f} & {s.median():.1f} & {s.quantile(0.75):.1f} \\\\"
        )
    lines.extend(
        [
            "\\bottomrule",
            "\\multicolumn{5}{p{0.86\\textwidth}}{\\footnotesize Notes: statistics are by closing CNES in the main PNASH psychiatric-closure sample. Psychiatric admissions use ICD-10 F diagnoses. Mental-health admissions add self-harm diagnoses X60--X84/Y87.0. Counts are SIH AIH episodes, not unique persons.}\\\\",
            "\\end{tabular}",
            "\\end{table}",
        ]
    )
    write_text(SIH_TEX, "\n".join(lines) + "\n")


def caveat_rows(caps_cir: pd.DataFrame) -> pd.DataFrame:
    raw_cnes_st = ROOT / "02_data" / "raw" / "cnes_st"
    pf_files = list((ROOT / "02_data" / "raw" / "cnes_pf").glob("*.parquet"))
    osrm_meta = ROOT / "02_data" / "intermediate" / "osrm_travel_time_panel.metadata.json"
    rows = [
        {
            "item": "Closing-CNES psychiatric admissions and bed-days",
            "status": "resolved",
            "resolution": "`03_analysis/61_resolve_remaining_data_caveats.py` rebuilds them from SIH `DIAG_PRINC`, `DIAS_PERM`, and `VAL_TOT`.",
        },
        {
            "item": "Mental-health exposure denominator",
            "status": "resolved",
            "resolution": "`03_analysis/51_build_exposure_variants.py` now adds ICD-10 F plus X60--X84/Y87.0 admissions.",
        },
        {
            "item": "Unique psychiatric patients",
            "status": "not observable in public SIH",
            "resolution": "The public SIH files expose AIH episodes, not stable person identifiers; the paper reports episode-scaled bounds.",
        },
        {
            "item": "CAPS coverage",
            "status": "resolved as CNES-ST facility proxy",
            "resolution": f"`{CAPS_CIR_OUT.relative_to(ROOT)}` counts CNES-ST `TP_UNID=70` facilities by municipality-year using December files.",
        },
        {
            "item": "FHS/primary-care coverage",
            "status": "requires external e-Gestor/SISAB source",
            "resolution": f"CNES-PF local files exist ({len(pf_files)} files) but are partial from 2015 onward and do not provide a national 2010--2017 coverage series.",
        },
        {
            "item": "Private insurance penetration",
            "status": "requires external ANS source",
            "resolution": "No ANS municipal beneficiary panel is present locally.",
        },
        {
            "item": "Fiscal capacity / SICONFI",
            "status": "requires external SICONFI source",
            "resolution": "IBGE municipal GDP is present and used; municipal revenue/expenditure series are not local.",
        },
        {
            "item": "CIR / health-region mapping",
            "status": "resolved as CNES-ST modal proxy",
            "resolution": f"`{CAPS_CIR_OUT.relative_to(ROOT)}` reports modal CNES-ST `REGSAUDE` by municipality-year; an official relationship table remains preferable.",
        },
        {
            "item": "Routed road travel time",
            "status": "not resolved locally",
            "resolution": f"`{osrm_meta.relative_to(ROOT)}` documents a fallback proxy rather than a routed OSRM matrix.",
        },
    ]
    return pd.DataFrame(rows)


def write_caveat_tex(df: pd.DataFrame) -> None:
    lines = [
        "\\begin{table}[!htbp]\\centering",
        "\\caption{Resolution status of remaining data caveats}",
        "\\label{tab:remaining-data-caveats}",
        "\\scriptsize",
        "\\resizebox{\\textwidth}{!}{%",
        "\\begin{tabular}{p{0.25\\textwidth}p{0.2\\textwidth}p{0.5\\textwidth}}",
        "\\toprule",
        "Item & Status & Resolution \\\\",
        "\\midrule",
    ]
    for _, r in df.iterrows():
        lines.append(f"{latex_escape(r['item'])} & {latex_escape(r['status'])} & {latex_escape(r['resolution'])} \\\\")
    lines.extend(
        [
            "\\bottomrule",
            "\\end{tabular}",
            "}%",
            "\\end{table}",
        ]
    )
    write_text(CAVEAT_TEX, "\n".join(lines) + "\n")


def write_gaps_md(df: pd.DataFrame) -> None:
    lines = [
        "# Variable Gaps For AEJ: Policy Revision",
        "",
        "Generated by `03_analysis/61_resolve_remaining_data_caveats.py` after the master-sample script.",
        "",
        "| variable | status | resolution / source |",
        "|---|---|---|",
    ]
    for _, r in df.iterrows():
        lines.append(f"| {r['item']} | {r['status']} | {r['resolution']} |")
    lines.extend(
        [
            "",
            "The unresolved items are not filled with ad hoc proxies in the manuscript. They require new official data downloads or routing infrastructure and are therefore treated as scope limitations rather than silently imputed controls.",
        ]
    )
    write_text(GAPS, "\n".join(lines) + "\n")


def main() -> None:
    args = parse_args("Resolve remaining locally addressable data caveats.")
    ensure_dirs()
    log = logger_for(SCRIPT)
    t0 = begin_log(log, SCRIPT)
    outputs = [COV_OUT, CAPS_CIR_OUT, EVENT, CAVEAT_TEX, SIH_TEX, GAPS]
    if not require_force(outputs, args.force, log):
        return

    if not EVENT.exists():
        raise FileNotFoundError(f"missing {EVENT}; run 03_analysis/50_build_master_sample_table.py first")

    con = duckdb.connect()
    con.execute("PRAGMA threads=10")
    con.execute("PRAGMA memory_limit='14GB'")
    con.execute("PRAGMA temp_directory='/tmp/duckdb_paper18'")

    event = pd.read_parquet(EVENT)
    cov = build_sih_covariates(con, event, log)
    cov.to_parquet(COV_OUT, index=False)
    write_sih_tex(cov)

    event_updated = update_event_dataset(event, cov)
    caps_cir = build_caps_cir_panel(event_updated, log)
    caps_cir.to_parquet(CAPS_CIR_OUT, index=False)
    event_updated = add_caps_cir_to_event(event_updated, caps_cir)
    event_updated.to_parquet(EVENT, index=False)
    log.info("updated PNASH event-level dataset rows=%d cols=%d", len(event_updated), len(event_updated.columns))

    caveats = caveat_rows(caps_cir)
    write_caveat_tex(caveats)
    write_gaps_md(caveats)
    log.info("resolved locally addressable caveats; remaining_unresolved=%d", int((caveats["status"].str.contains("requires|not resolved|not observable")).sum()))
    end_log(log, t0)


if __name__ == "__main__":
    main()
