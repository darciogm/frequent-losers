"""Build an auditable, closure-level event table for the 48 PNASH psychiatric closures.

One row per closure. Enriches the base event dataset with hospital identity (from the
human-validated CNPJ file), state abbreviation, F5 membership, network-flow exposure
(count of exposed municipalities + their pre-closure population), baseline catchment CAPS
capacity, formal de-accreditation status, and LLM-classified closure motive.

Outputs:
  02_data/processed/pnash_event_level_table.parquet
  01_manuscript/tables_appendix/table_pnash_event_level.tex  (replace; old one archived)
  04_logs/pnash_event_level_table_20260609.log

NA where genuinely unavailable; no fabricated values.
"""
from __future__ import annotations

import datetime as _dt
import logging
import os
import socket
from pathlib import Path

import duckdb
import psutil

ROOT = Path(__file__).resolve().parents[1]
PROC = ROOT / "02_data" / "processed"
INTER = ROOT / "02_data" / "intermediate"
APPDX = ROOT / "01_manuscript" / "tables_appendix"
LOG = ROOT / "04_logs"

EVENT = PROC / "pnash_event_level_dataset.parquet"
HV = INTER / "closures_human_validated.parquet"
EXO = INTER / "hospital_closures_exogenous.parquet"
EXP = PROC / "closure_sample_exposure_flags_long.parquet"
PANEL = PROC / "revision_pnash48_panel.parquet"
CAPS = PROC / "cnes_caps_cir_municipality_year.parquet"

OUT_PARQUET = PROC / "pnash_event_level_table.parquet"
OUT_TEX = APPDX / "table_pnash_event_level.tex"
LOG_FILE = LOG / "pnash_event_level_table_20260609.log"

PNASH_SAMPLE = "pnash_psychiatric_closures"

# IBGE 2-digit UF code -> abbreviation
UF_ABBR = {
    "11": "RO", "12": "AC", "13": "AM", "14": "RR", "15": "PA", "16": "AP", "17": "TO",
    "21": "MA", "22": "PI", "23": "CE", "24": "RN", "25": "PB", "26": "PE", "27": "AL",
    "28": "SE", "29": "BA", "31": "MG", "32": "ES", "33": "RJ", "35": "SP", "41": "PR",
    "42": "SC", "43": "RS", "50": "MS", "51": "MT", "52": "GO", "53": "DF",
}


def latex_escape(value: object) -> str:
    if value is None:
        return ""
    text = str(value)
    return (
        text.replace("\\", "\\textbackslash{}")
        .replace("&", "\\&")
        .replace("%", "\\%")
        .replace("$", "\\$")
        .replace("#", "\\#")
        .replace("_", "\\_")
    )


def setup_logger() -> logging.Logger:
    LOG.mkdir(parents=True, exist_ok=True)
    logger = logging.getLogger("82_enrich_pnash_event_level")
    logger.setLevel(logging.INFO)
    logger.handlers.clear()
    fmt = logging.Formatter("%(asctime)s %(levelname)s %(message)s")
    fh = logging.FileHandler(LOG_FILE, mode="w")
    fh.setFormatter(fmt)
    logger.addHandler(fh)
    ch = logging.StreamHandler()
    ch.setFormatter(fmt)
    logger.addHandler(ch)
    return logger


def telemetry_header(logger: logging.Logger) -> None:
    vm = psutil.virtual_memory()
    logger.info("=== telemetry ===")
    logger.info("hostname=%s", socket.gethostname())
    logger.info("nproc=%s threads_chosen=12", os.cpu_count())
    logger.info("ram_total=%.1f GiB ram_avail=%.1f GiB", vm.total / 2**30, vm.available / 2**30)
    logger.info("rss_start=%.0f MiB", psutil.Process().memory_info().rss / 2**20)
    logger.info("=================")


def build(con: duckdb.DuckDBPyConnection, logger: logging.Logger):
    # Network-flow exposure (count exposed munis + summed pre-closure population) per CNES.
    # Population at closure_year-1 from the panel; CAPS facilities at closure_year-1 from the
    # CAPS-by-municipality-year file, both summed over the flow-exposed catchment.
    exposure = con.sql(f"""
        WITH ex AS (
            SELECT CNES, year_closure, municipality AS codmun
            FROM read_parquet('{EXP}')
            WHERE sample_id = '{PNASH_SAMPLE}' AND flow_exposed
        ),
        joined AS (
            SELECT ex.CNES, ex.codmun,
                   p.pop                AS muni_pop,
                   c.caps_facilities    AS muni_caps
            FROM ex
            LEFT JOIN read_parquet('{PANEL}') p
                   ON p.codmun_6 = ex.codmun AND p.year = ex.year_closure - 1
            LEFT JOIN read_parquet('{CAPS}') c
                   ON c.municipality = ex.codmun AND c.year = ex.year_closure - 1
        )
        SELECT CNES,
               COUNT(*)                       AS n_exposed_munis,
               SUM(muni_pop)                  AS exposed_population,
               SUM(muni_caps)                 AS caps_facilities_catchment,
               COUNT(muni_pop)                AS n_pop_found,
               COUNT(muni_caps)               AS n_caps_found
        FROM joined
        GROUP BY CNES
    """).df()

    # All 48 CNES are in the pnash exposure sample, but 18 have zero flow-exposed munis.
    # Those genuinely have n_exposed_munis = 0 (real, not NA): represent explicitly.
    all_cnes = con.sql(f"""
        SELECT DISTINCT CNES FROM read_parquet('{EXP}')
        WHERE sample_id = '{PNASH_SAMPLE}'
    """).df()
    logger.info("exposure: %d closures with >=1 flow-exposed muni; %d total pnash CNES",
                len(exposure), len(all_cnes))

    # Human-validated identity / motive (35 of 48 match).
    hv = con.sql(f"""
        SELECT CNES, razao_social, nome_fantasia, situacao_cadastral, motivo_v2, confidence_v2
        FROM read_parquet('{HV}')
    """).df()

    # F5 membership: 'exogenous' flag in the closures file.
    f5 = con.sql(f"""
        SELECT CNES, exogenous AS f5_exogenous FROM read_parquet('{EXO}')
    """).df()

    # Base event dataset (48 rows).
    ev = con.sql(f"""
        SELECT CNES, municipality, closure_year, nearest_pnash_cycle,
               years_from_nearest_pnash_cycle, within_pm1_year_of_pnash_cycle,
               pre_volume_decline_pct, qt_sus_pre,
               pre_closure_psychiatric_aih_value, pre_closure_psychiatric_beddays,
               pre_closure_caps_facilities_hospital_municipality,
               pre_closure_suicide_rate_exposed_catchment,
               pre_closure_selfharm_rate_exposed_catchment
        FROM read_parquet('{EVENT}')
    """).df()

    df = ev.merge(hv, on="CNES", how="left")
    df = df.merge(f5, on="CNES", how="left")
    df = df.merge(exposure, on="CNES", how="left")

    # n_exposed_munis: closures present in pnash sample but with no flow-exposed muni -> 0.
    df["n_exposed_munis"] = df["n_exposed_munis"].fillna(0).astype("int64")
    # exposed_population / caps_catchment: 0 munis -> NA (no catchment to sum, not a true 0 pop).
    # When n_exposed_munis>0 but pop/caps missing for a muni, the SUM already excludes nulls;
    # full coverage confirmed in QA so this branch is moot, but keep NA-safe.
    df.loc[df["n_exposed_munis"] == 0, ["exposed_population", "caps_facilities_catchment"]] = None

    # hospital_name: prefer nome_fantasia, fall back to razao_social, else NA.
    import math as _math

    def pick_name(row):
        for col in ("nome_fantasia", "razao_social"):
            v = row.get(col)
            if v is None:
                continue
            if isinstance(v, float) and _math.isnan(v):
                continue
            s = str(v).strip()
            if s and s.lower() != "nan":
                return s
        return None
    df["hospital_name"] = df.apply(pick_name, axis=1)

    # UF abbreviation from first 2 digits of hospital codmun_6.
    df["uf"] = df["municipality"].astype(str).str[:2].map(UF_ABBR)

    # F5 status as readable flag (NA if CNES absent from exo file -- none expected).
    df["f5_status"] = df["f5_exogenous"].map({True: "F5", False: "non-F5"})

    df["closure_year"] = df["closure_year"].astype("int64")
    df = df.sort_values(["closure_year", "nearest_pnash_cycle", "CNES"]).reset_index(drop=True)
    df["closure_id"] = range(1, len(df) + 1)

    out = df.rename(columns={
        "municipality": "hospital_municipality",
        "nearest_pnash_cycle": "nearest_pnash_cycle",
        "years_from_nearest_pnash_cycle": "dist_to_cycle",
        "within_pm1_year_of_pnash_cycle": "pnash_exact_pm1",
        "pre_volume_decline_pct": "pre_admission_decline_pct",
        "qt_sus_pre": "sus_beds_tm1",
        "pre_closure_psychiatric_aih_value": "psych_aih_tm1",
        "pre_closure_psychiatric_beddays": "psych_beddays_tm1",
        "pre_closure_caps_facilities_hospital_municipality": "caps_facilities_hosp_muni",
        "pre_closure_suicide_rate_exposed_catchment": "baseline_suicide_rate_catchment",
        "pre_closure_selfharm_rate_exposed_catchment": "baseline_selfharm_rate_catchment",
        "situacao_cadastral": "deaccreditation",
        "motivo_v2": "motive",
    })
    out["pnash_cycle_window"] = 1  # PNASH cycles are 2-year; the +-1 window is fixed at 1.

    cols = [
        "closure_id", "CNES", "hospital_name", "hospital_municipality", "uf",
        "closure_year", "nearest_pnash_cycle", "dist_to_cycle", "pnash_cycle_window",
        "pnash_exact_pm1", "f5_status", "pre_admission_decline_pct", "sus_beds_tm1",
        "psych_aih_tm1", "psych_beddays_tm1", "n_exposed_munis", "exposed_population",
        "baseline_suicide_rate_catchment", "baseline_selfharm_rate_catchment",
        "caps_facilities_hosp_muni", "caps_facilities_catchment",
        "deaccreditation", "motive",
    ]
    out = out[cols]
    return out


def fmt_num(v, dec=1):
    if v is None:
        return "NA"
    try:
        import math
        if isinstance(v, float) and math.isnan(v):
            return "NA"
    except Exception:
        pass
    return f"{v:,.{dec}f}".replace(",", "\\,")


def fmt_int(v):
    if v is None:
        return "NA"
    try:
        import math
        if isinstance(v, float) and math.isnan(v):
            return "NA"
    except Exception:
        pass
    return f"{int(v):,}".replace(",", "\\,")


def fmt_str(v):
    import math
    if v is None or (isinstance(v, float) and math.isnan(v)):
        return "NA"
    s = str(v).strip()
    return latex_escape(s) if s else "NA"


def truncate_name(name, n=26):
    if name is None or str(name).strip() == "" or str(name) == "nan":
        return None
    s = str(name).strip()
    return s if len(s) <= n else s[: n - 1] + "."


def render_tex(df) -> str:
    import math
    L = []
    A = L.append
    A("% Auto-generated by 03_analysis/82_enrich_pnash_event_level.py -- do not edit by hand.")
    A("\\begin{sidewaystable}[p]")
    A("\\centering")
    A("\\caption{Closure-level audit table for the 48 PNASH psychiatric closure events}")
    A("\\label{tab:pnash-event-level}")
    A("\\scriptsize")
    A("\\setlength{\\tabcolsep}{2.4pt}")
    A("\\renewcommand{\\arraystretch}{0.92}")
    # Panel A: timing + capacity.  Panel B: exposure + governance.  Shared closure_id.
    A("\\begin{tabular}{rllclcclrrrr}")
    A("\\toprule")
    A("\\multicolumn{12}{l}{\\textit{Panel A. Timing and pre-closure capacity}}\\\\")
    A("\\midrule")
    A("ID & CNES & UF & Yr & Cycle & $\\Delta$cyc & $\\pm$1 & F5 & Decl.\\% & "
      "SUS beds & Psych.\\ AIH (R\\$) & Bed-days \\\\")
    A("\\midrule")
    for r in df.itertuples(index=False):
        A(
            f"{r.closure_id} & {r.CNES} & {fmt_str(r.uf)} & {r.closure_year} & "
            f"{fmt_str(r.nearest_pnash_cycle)} & {r.dist_to_cycle} & "
            f"{1 if r.pnash_exact_pm1 else 0} & {fmt_str(r.f5_status)} & "
            f"{fmt_num(r.pre_admission_decline_pct, 1)} & {fmt_num(r.sus_beds_tm1, 0)} & "
            f"{fmt_num(r.psych_aih_tm1, 0)} & {fmt_int(r.psych_beddays_tm1)} \\\\"
        )
    A("\\bottomrule")
    A("\\end{tabular}")
    A("")
    A("\\vspace{0.7em}")
    A("")
    A("\\begin{tabular}{rllrrrrll}")
    A("\\toprule")
    A("\\multicolumn{9}{l}{\\textit{Panel B. Exposed catchment and governance (linked by ID)}}\\\\")
    A("\\midrule")
    A("ID & CNES & Hospital name & Exp.\\ munis & Exp.\\ pop. & CAPS hosp.\\ & "
      "CAPS catch.\\ & De-accred.\\ & Motive \\\\")
    A("\\midrule")
    for r in df.itertuples(index=False):
        name = truncate_name(r.hospital_name)
        A(
            f"{r.closure_id} & {r.CNES} & {fmt_str(name)} & "
            f"{fmt_int(r.n_exposed_munis)} & {fmt_int(r.exposed_population)} & "
            f"{fmt_int(r.caps_facilities_hosp_muni)} & {fmt_int(r.caps_facilities_catchment)} & "
            f"{fmt_str(r.deaccreditation)} & {fmt_str(r.motive)} \\\\"
        )
    A("\\bottomrule")
    A("\\end{tabular}")
    A("")
    note = (
        "\\par\\vspace{0.4em}\\footnotesize\\textit{Notes.} "
        "One row per PNASH psychiatric closure ($N=48$); the two panels share the closure "
        "identifier (ID). \\textbf{Panel A:} \\emph{UF} is the state of the hospital "
        "municipality; \\emph{Cycle} is the nearest PNASH inspection cycle and $\\Delta$cyc "
        "its signed distance in years (negative = closure precedes cycle); $\\pm1$ flags "
        "closures within one year of a cycle; \\emph{F5} marks closures that also pass the "
        "main economically-meaningful (non-demand-driven) screen; \\emph{Decl.\\%} is the "
        "pre-closure admission decline; SUS beds, psychiatric AIH spending, and psychiatric "
        "bed-days are measured at $t-1$. \\textbf{Panel B:} exposed municipalities are those "
        "with a pre-closure patient-flow share to the closing hospital of at least 5\\%; "
        "\\emph{Exp.\\ pop.} sums their population at $t-1$; \\emph{CAPS hosp.} and "
        "\\emph{CAPS catch.} count community mental-health (CAPS) facilities at $t-1$ in the "
        "hospital municipality and across the exposed catchment, respectively; "
        "\\emph{De-accred.} is the firm's federal registry status (INAPTA $\\approx$ "
        "de-accredited/suspended, BAIXADA = dissolved, ATIVA = active) and \\emph{Motive} is "
        "the LLM-classified closure motive, both from the human-validated CNPJ linkage that "
        "covers 35 of the 48 events. \\emph{NA} denotes a field that is genuinely unavailable: "
        "hospital name, de-accreditation status, and motive are NA for the 13 closures without "
        "a confirmed CNPJ match; exposed population and catchment CAPS counts are NA for "
        "closures with no flow-exposed catchment ($\\geq5\\%$ share) municipality."
    )
    A(note)
    A("\\end{sidewaystable}")
    return "\n".join(L) + "\n"


def main() -> None:
    logger = setup_logger()
    telemetry_header(logger)
    t0 = _dt.datetime.now()

    con = duckdb.connect()
    con.sql("PRAGMA threads=12")
    con.sql("PRAGMA memory_limit='14GB'")

    df = build(con, logger)
    logger.info("built event table: %d rows x %d cols", len(df), df.shape[1])

    df.to_parquet(OUT_PARQUET, index=False)
    logger.info("wrote %s", OUT_PARQUET)

    APPDX.mkdir(parents=True, exist_ok=True)
    OUT_TEX.write_text(render_tex(df))
    logger.info("wrote %s", OUT_TEX)

    # ---- QA / summary stats to log ----
    logger.info("=== column population (non-NA out of 48) ===")
    for c in df.columns:
        nn = df[c].notna().sum()
        logger.info("  %-34s %2d/48 non-NA", c, nn)

    logger.info("=== summary stats ===")
    logger.info("f5_status: %s", df["f5_status"].value_counts(dropna=False).to_dict())
    logger.info("deaccreditation: %s", df["deaccreditation"].value_counts(dropna=False).to_dict())
    inapta = int((df["deaccreditation"] == "INAPTA").sum())
    logger.info("INAPTA de-accreditation count: %d", inapta)
    logger.info("motive: %s", df["motive"].value_counts(dropna=False).to_dict())
    logger.info("hospital_name present: %d/48", int(df["hospital_name"].notna().sum()))
    nem = df["n_exposed_munis"]
    logger.info("n_exposed_munis: min=%d max=%d mean=%.2f (zero-catchment closures=%d)",
                nem.min(), nem.max(), nem.mean(), int((nem == 0).sum()))
    ep = df["exposed_population"].dropna()
    logger.info("exposed_population (nonzero-catchment, n=%d): min=%s max=%s median=%s",
                len(ep), fmt_int(ep.min()), fmt_int(ep.max()), fmt_int(ep.median()))
    logger.info("baseline_suicide_rate_catchment non-NA: %d/48",
                int(df["baseline_suicide_rate_catchment"].notna().sum()))
    logger.info("baseline_selfharm_rate_catchment non-NA: %d/48",
                int(df["baseline_selfharm_rate_catchment"].notna().sum()))

    logger.info("=== full table dump ===")
    import pandas as pd
    with pd.option_context("display.max_rows", None, "display.max_columns", None,
                           "display.width", 240):
        logger.info("\n%s", df.to_string(index=False))

    rss = psutil.Process().memory_info().rss / 2**20
    logger.info("rss_end=%.0f MiB elapsed=%.1fs", rss, (_dt.datetime.now() - t0).total_seconds())


if __name__ == "__main__":
    main()
