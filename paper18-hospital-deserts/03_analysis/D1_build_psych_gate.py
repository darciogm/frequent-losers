"""
D1_build_psych_gate.py  (DIAGNOSTIC — Stage-2 outcome viability gate)

Builds candidate psychiatric health outcomes at municipality x year and a
specialized-closure (tp_unid=07, predominantly psychiatric) staggered panel,
so the pre-trend gate (D2) can test whether ANY health-relevant outcome is
identified under the same E1 share-based exposure used in the paper.

Outcomes (residence municipality, MUNIC_RES / CODMUNRES):
  SIM (cause of death, CAUSABAS):
    suicide_per100k    : X60-X84               (intentional self-harm)
    selfharm_per100k   : X60-X84 + Y10-Y34     (+ undetermined intent)
    psychF_mort_per100k: F00-F99               (mental/behavioural disorder deaths)
  SIH (DIAG_PRINC):
    psych_adm_per1k    : F00-F99 admissions    (psychiatric inpatient utilization)

Denominator = pop_municipal_2015_2025.parquet (2015+ only -> rates NULL pre-2015,
mirroring the existing ICSAP/amenable panels; the SunAb pre-period is therefore
identified off recent cohorts exactly as in the paper).

Outputs:
  02_data/intermediate/psych_outcomes_panel.parquet   (codmun_6, year, 4 rates + counts)
  02_data/intermediate/staggered_panel_spec07.parquet (tp_unid=07 treatment + psych outcomes)
"""
from __future__ import annotations
import logging, sys, time
from pathlib import Path
import duckdb
import polars as pl

ROOT = Path(__file__).resolve().parents[1]
RAW_SIM = ROOT / "02_data" / "raw" / "sim"
RAW_SIH = ROOT / "02_data" / "raw" / "sih_rd"
INTER = ROOT / "02_data" / "intermediate"
LOG = ROOT / "04_logs"

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s",
                    handlers=[logging.FileHandler(LOG / "D1_build_psych_gate.log", mode="w"),
                              logging.StreamHandler(sys.stdout)])
log = logging.getLogger("psych_gate")

POP = INTER / "pop_municipal_2015_2025.parquet"
EXP = INTER / "exposure_panel.parquet"
CLO = INTER / "hospital_closures_exogenous.parquet"
CENT = INTER / "municipios_centroids.parquet"
TB = INTER / "travel_burden_panel.parquet"
ICSAP = INTER / "icsap_panel.parquet"
OUT_OUT = INTER / "psych_outcomes_panel.parquet"
OUT_PANEL = INTER / "staggered_panel_spec07.parquet"

YR_LO, YR_HI = 2010, 2024
PANDEMIC = {2020, 2021}


def build_outcomes(con):
    log.info("[1/3] SIM mortality outcomes (2010-2023, residence)...")
    sim_files = []
    for y in range(2010, 2024):
        sim_files.extend(sorted(RAW_SIM.glob(f"do*{y}.parquet")))
    sim_sql = "[" + ", ".join(f"'{f}'" for f in sim_files) + "]"
    log.info("    SIM files: %d", len(sim_files))

    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE sim_mort AS
        SELECT codmun_6, year,
               SUM(is_suicide) AS n_suicide,
               SUM(is_selfharm) AS n_selfharm,
               SUM(is_psychF) AS n_psychF
        FROM (
          SELECT CAST(SUBSTR(DTOBITO,5,4) AS INTEGER) AS year,
                 LPAD(CODMUNRES,6,'0') AS codmun_6,
                 SUBSTR(CAUSABAS,1,3) AS c3,
                 CASE WHEN SUBSTR(CAUSABAS,1,3) BETWEEN 'X60' AND 'X84' THEN 1 ELSE 0 END AS is_suicide,
                 CASE WHEN SUBSTR(CAUSABAS,1,3) BETWEEN 'X60' AND 'X84'
                        OR SUBSTR(CAUSABAS,1,3) BETWEEN 'Y10' AND 'Y34' THEN 1 ELSE 0 END AS is_selfharm,
                 CASE WHEN SUBSTR(CAUSABAS,1,1) = 'F' THEN 1 ELSE 0 END AS is_psychF
          FROM read_parquet({sim_sql}, union_by_name=true)
          WHERE CAUSABAS IS NOT NULL AND CODMUNRES IS NOT NULL
            AND DTOBITO IS NOT NULL AND LENGTH(DTOBITO)=8
            AND CAST(SUBSTR(DTOBITO,5,4) AS INTEGER) BETWEEN 2010 AND 2023
        ) GROUP BY codmun_6, year
    """)

    log.info("[2/3] SIH psychiatric admissions (2010-2024, residence)...")
    sih_files = []
    for y in range(2010, 2025):
        yy = f"{y % 100:02d}"
        sih_files.extend(sorted(RAW_SIH.glob(f"rd*{yy}??.parquet")))
    sih_sql = "[" + ", ".join(f"'{f}'" for f in sih_files) + "]"
    log.info("    SIH files: %d", len(sih_files))
    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE sih_psy AS
        SELECT LPAD(MUNIC_RES,6,'0') AS codmun_6,
               CAST(ANO_CMPT AS INTEGER) AS year,
               SUM(CASE WHEN SUBSTR(DIAG_PRINC,1,1)='F' THEN 1 ELSE 0 END) AS n_psych_adm
        FROM read_parquet({sih_sql}, union_by_name=true)
        WHERE MUNIC_RES IS NOT NULL AND ANO_CMPT IS NOT NULL
          AND CAST(ANO_CMPT AS INTEGER) BETWEEN 2010 AND 2024
        GROUP BY codmun_6, year
    """)

    log.info("[3/3] join pop + rates...")
    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE pop AS
        SELECT SUBSTR(cod_mun,1,6) AS codmun_6, ano AS year, pop
        FROM read_parquet('{POP}')
    """)
    con.execute(f"""
        COPY (
          SELECT
            COALESCE(m.codmun_6, s.codmun_6) AS codmun_6,
            COALESCE(m.year, s.year) AS year,
            m.n_suicide, m.n_selfharm, m.n_psychF, s.n_psych_adm, p.pop,
            CASE WHEN p.pop>0 THEN 1e5*m.n_suicide/p.pop  END AS suicide_per100k,
            CASE WHEN p.pop>0 THEN 1e5*m.n_selfharm/p.pop END AS selfharm_per100k,
            CASE WHEN p.pop>0 THEN 1e5*m.n_psychF/p.pop   END AS psychF_mort_per100k,
            CASE WHEN p.pop>0 THEN 1e3*s.n_psych_adm/p.pop END AS psych_adm_per1k
          FROM sim_mort m
          FULL OUTER JOIN sih_psy s USING (codmun_6, year)
          LEFT JOIN pop p ON p.codmun_6=COALESCE(m.codmun_6,s.codmun_6)
                          AND p.year=COALESCE(m.year,s.year)
          ORDER BY codmun_6, year
        ) TO '{OUT_OUT}' (FORMAT PARQUET, COMPRESSION 'snappy')
    """)
    n = con.sql(f"SELECT COUNT(*) FROM read_parquet('{OUT_OUT}')").fetchone()[0]
    log.info("    wrote %s rows=%d", OUT_OUT.name, n)
    summ = con.sql(f"""
        SELECT year, COUNT(*) n_mun, SUM(n_suicide) suic, SUM(n_psychF) psyF,
               SUM(n_psych_adm) padm, AVG(suicide_per100k) mean_suic
        FROM read_parquet('{OUT_OUT}') WHERE year BETWEEN 2014 AND 2023
        GROUP BY year ORDER BY year""").pl()
    log.info("\n%s", summ)


def build_spec07_panel():
    """Mirror script 29 build_panel, restricted to tp_unid=07 closures, joining psych outcomes."""
    log.info("=== build spec07 staggered panel (tp_unid=07) ===")
    clo = pl.read_parquet(CLO).filter(pl.col("exogenous") & (pl.col("tp_unid") == "07"))
    cnes = clo["CNES"].to_list()
    log.info("  specialized (07) exogenous closures: %d", len(cnes))

    exp = pl.read_parquet(EXP).filter(pl.col("CNES").is_in(cnes))
    g_emb = exp.filter(pl.col("exposed_emb")).group_by("codmun_6").agg(
        pl.col("year_closure").min().alias("g_emb"), pl.len().alias("n_treat_emb"))
    g_km = exp.filter(pl.col("exposed_km")).group_by("codmun_6").agg(
        pl.col("year_closure").min().alias("g_km"), pl.len().alias("n_treat_km"))
    log.info("  munis E1: %d  E2: %d", len(g_emb), len(g_km))

    cent = pl.read_parquet(CENT).select(["cod_mun_6", "uf"]).rename({"cod_mun_6": "codmun_6"})
    munis = cent.unique(subset=["codmun_6"])
    years = pl.DataFrame({"year": list(range(YR_LO, YR_HI + 1))})
    panel = munis.join(years, how="cross") \
        .join(g_emb, on="codmun_6", how="left").join(g_km, on="codmun_6", how="left") \
        .with_columns([pl.col("g_emb").fill_null(0), pl.col("g_km").fill_null(0),
                       pl.col("n_treat_emb").fill_null(0), pl.col("n_treat_km").fill_null(0)])

    tb = pl.read_parquet(TB).select(["codmun_6", "year", "travel_burden_km"])
    ic = pl.read_parquet(ICSAP).select(["codmun_6", "year", "icsap_per1k"])
    psy = pl.read_parquet(OUT_OUT).select(
        ["codmun_6", "year", "suicide_per100k", "selfharm_per100k",
         "psychF_mort_per100k", "psych_adm_per1k"])
    pop = pl.read_parquet(POP).with_columns(codmun_6=pl.col("cod_mun").str.slice(0, 6)) \
        .rename({"ano": "year"}).select(["codmun_6", "year", "pop"])

    panel = panel.join(tb, on=["codmun_6", "year"], how="left") \
        .join(ic, on=["codmun_6", "year"], how="left") \
        .join(psy, on=["codmun_6", "year"], how="left") \
        .join(pop, on=["codmun_6", "year"], how="left") \
        .with_columns([
            pl.when(pl.col("g_emb") > 0).then(pl.col("year") - pl.col("g_emb"))
              .otherwise(None).alias("rel_t_emb"),
            pl.col("year").is_in(list(PANDEMIC)).alias("pandemic")])

    muni_to_id = {m: i + 1 for i, m in enumerate(sorted(panel["codmun_6"].unique().to_list()))}
    panel = panel.with_columns(
        muni_id=pl.col("codmun_6").map_elements(lambda m: muni_to_id[m], return_dtype=pl.Int32)
    ).sort(["muni_id", "year"])
    panel.write_parquet(OUT_PANEL, compression="snappy")
    n_tr = panel.filter(pl.col("g_emb") > 0)["muni_id"].n_unique()
    log.info("  wrote %s rows=%d  E1-treated munis=%d  cohorts=%d",
             OUT_PANEL.name, len(panel), n_tr,
             panel.filter(pl.col("g_emb") > 0)["g_emb"].n_unique())


def main():
    t0 = time.time()
    con = duckdb.connect()
    con.execute("PRAGMA threads=12")
    con.execute("PRAGMA memory_limit='14GB'")
    con.execute("PRAGMA temp_directory='/tmp/duckdb_paper18'")
    if not OUT_OUT.exists():
        build_outcomes(con)
    else:
        log.info("psych_outcomes_panel.parquet exists; skip (delete to rebuild)")
    build_spec07_panel()
    log.info("==== done %.1fs ====", time.time() - t0)


if __name__ == "__main__":
    main()
