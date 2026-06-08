"""
D3_pnash_power.py  (DIAGNOSTIC — JHE power path: PNASH-anchored closure expansion)

Builds staggered panels for relaxed psychiatric-closure treatment sets to test
whether dropping the F5 demand-decline filter and anchoring exogeneity on the
PNASH inspection calendar buys enough power to detect a mortality effect.

Treatment sets (tp_unid=07, psychiatric):
  pnash48 : F1-F4 + PNASH window (+-1yr of 2007-08/2011-12/2015-16)  -> 48 closures
  psymax60: F1-F4 (drop F5 entirely, max psychiatric universe)        -> 60 closures

E1 exposure (share>=0.05) recomputed from bipartite_edges for the expanded set,
exactly as 21_define_exposure.py does. Outputs staggered panels with psych
outcomes joined, ready for the D2-style pre-trend / MDE gate.
"""
from __future__ import annotations
import logging, sys, time
from pathlib import Path
import duckdb
import polars as pl

ROOT = Path(__file__).resolve().parents[1]
INTER = ROOT / "02_data" / "intermediate"
LOG = ROOT / "04_logs"
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s",
                    handlers=[logging.FileHandler(LOG / "D3_pnash_power.log", mode="w"),
                              logging.StreamHandler(sys.stdout)])
log = logging.getLogger("pnash_power")

CLO = INTER / "hospital_closures_exogenous.parquet"
EDGES = INTER / "bipartite_edges.parquet"
CENT = INTER / "municipios_centroids.parquet"
TB = INTER / "travel_burden_panel.parquet"
ICSAP = INTER / "icsap_panel.parquet"
PSY = INTER / "psych_outcomes_panel.parquet"
POP = INTER / "pop_municipal_2015_2025.parquet"
YR_LO, YR_HI = 2010, 2024
PANDEMIC = {2020, 2021}
THETA = 0.05

PNASH = ("(year_closure BETWEEN 2006 AND 2009 OR year_closure BETWEEN 2010 AND 2013 "
         "OR year_closure BETWEEN 2014 AND 2017)")
SETS = {
    "pnash48":  f"f1_window AND f2_type AND f3_beds AND f4_mass AND tp_unid='07' AND {PNASH}",
    "psymax60": "f1_window AND f2_type AND f3_beds AND f4_mass AND tp_unid='07'",
}


def compute_exposure(con, cnes_years):
    """E1 share-based exposure for a list of (CNES, year_closure). Returns g_emb per muni."""
    rows = []
    for cnes, yc in cnes_years:
        yr_pre = yc - 1
        df = con.sql(f"""
            WITH tot AS (SELECT codmun_6, SUM(n_internacoes) t
                         FROM read_parquet('{EDGES}') WHERE year={yr_pre} GROUP BY codmun_6),
                 toh AS (SELECT codmun_6, n_internacoes n
                         FROM read_parquet('{EDGES}') WHERE year={yr_pre} AND CNES='{cnes}')
            SELECT t.codmun_6, 1.0*COALESCE(toh.n,0)/NULLIF(t.t,0) AS share
            FROM tot t LEFT JOIN toh USING (codmun_6)
            WHERE COALESCE(toh.n,0) > 0
        """).pl()
        exp = df.filter(pl.col("share") >= THETA)
        for m in exp["codmun_6"].to_list():
            rows.append({"codmun_6": m, "year_closure": yc})
    return pl.DataFrame(rows) if rows else pl.DataFrame({"codmun_6": [], "year_closure": []})


def build(con, label, where):
    clo = con.sql(f"SELECT CNES, year_closure FROM read_parquet('{CLO}') WHERE {where}").pl()
    cnes_years = list(zip(clo["CNES"].to_list(), clo["year_closure"].to_list()))
    log.info("[%s] closures=%d", label, len(cnes_years))
    exp = compute_exposure(con, cnes_years)
    g_emb = exp.group_by("codmun_6").agg(pl.col("year_closure").min().alias("g_emb"))
    log.info("[%s] E1-treated munis=%d  cohorts=%d", label, len(g_emb),
             g_emb["g_emb"].n_unique() if len(g_emb) else 0)

    cent = pl.read_parquet(CENT).select(["cod_mun_6", "uf"]).rename({"cod_mun_6": "codmun_6"}).unique("codmun_6")
    years = pl.DataFrame({"year": list(range(YR_LO, YR_HI + 1))})
    panel = cent.join(years, how="cross").join(g_emb, on="codmun_6", how="left") \
        .with_columns(pl.col("g_emb").fill_null(0))

    tb = pl.read_parquet(TB).select(["codmun_6", "year", "travel_burden_km"])
    ic = pl.read_parquet(ICSAP).select(["codmun_6", "year", "icsap_per1k"])
    psy = pl.read_parquet(PSY).select(["codmun_6", "year", "suicide_per100k",
                                       "selfharm_per100k", "psychF_mort_per100k"])
    pop = pl.read_parquet(POP).with_columns(codmun_6=pl.col("cod_mun").str.slice(0, 6)) \
        .rename({"ano": "year"}).select(["codmun_6", "year", "pop"])
    panel = panel.join(tb, on=["codmun_6", "year"], how="left") \
        .join(ic, on=["codmun_6", "year"], how="left") \
        .join(psy, on=["codmun_6", "year"], how="left") \
        .join(pop, on=["codmun_6", "year"], how="left") \
        .with_columns(pl.col("year").is_in(list(PANDEMIC)).alias("pandemic"))
    ids = {m: i + 1 for i, m in enumerate(sorted(panel["codmun_6"].unique().to_list()))}
    panel = panel.with_columns(
        muni_id=pl.col("codmun_6").replace_strict(ids, return_dtype=pl.Int32)).sort(["muni_id", "year"])
    out = INTER / f"staggered_panel_{label}.parquet"
    panel.write_parquet(out, compression="snappy")
    log.info("[%s] wrote %s rows=%d", label, out.name, len(panel))


def main():
    t0 = time.time()
    con = duckdb.connect()
    con.execute("PRAGMA threads=12")
    con.execute("PRAGMA memory_limit='14GB'")
    for label, where in SETS.items():
        build(con, label, where)
    log.info("==== done %.1fs ====", time.time() - t0)


if __name__ == "__main__":
    main()
