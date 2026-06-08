"""
D4_extend_pop_rebuild.py  (DIAGNOSTIC — backfill pop 2010-2014, give early cohorts real pre-periods)

The pop denominator (pop_municipal_2015_2025.parquet) starts in 2015, so all rate
outcomes (ICSAP, mortality) are NULL pre-2015 — which is why the PNASH-cohort
pre-trend test was empty/uninformative. The SIDRA t6579 source JSON already covers
2011-2021; the canonical consolidation just filtered ano>=2015. Here we backfill
2011-2014 (real) + 2010 (linear back-extrapolation per municipality), recompute the
rate outcomes from the EXISTING counts (no SIH/SIM rescan), and rebuild the three
psychiatric-closure staggered panels with extended pre-periods.

Writes *_ext.parquet (canonical paper panels untouched).
"""
from __future__ import annotations
import json, logging, sys, time
from pathlib import Path
import polars as pl

ROOT = Path(__file__).resolve().parents[1]
INTER = ROOT / "02_data" / "intermediate"
RAW_IBGE = ROOT / "02_data" / "raw" / "ibge"
LOG = ROOT / "04_logs"
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s",
                    handlers=[logging.FileHandler(LOG / "D4_extend_pop_rebuild.log", mode="w"),
                              logging.StreamHandler(sys.stdout)])
log = logging.getLogger("ext_pop")

SIDRA = RAW_IBGE / "populacao_estimada_6579_2010_2021.json"
ICSAP = INTER / "icsap_panel.parquet"
PSY = INTER / "psych_outcomes_panel.parquet"


def build_pop_ext() -> pl.DataFrame:
    raw = json.loads(Path(SIDRA).resolve().read_text())
    df = pl.DataFrame([{"codmun_6": r["D1C"][:6], "year": int(r["D3C"]),
                        "pop": int(r["V"]) if r["V"] not in ("...", "-", "X", "") else None}
                       for r in raw[1:]])
    df = df.filter(pl.col("year").is_between(2011, 2014))  # 2015+ already canonical; we only need pre-2015
    # 2010 back-extrapolation: pop_2010 = 2*pop_2011 - pop_2012, clamped >0
    w = df.filter(pl.col("year").is_in([2011, 2012])).pivot(values="pop", index="codmun_6", on="year")
    w = w.with_columns(
        pop=pl.max_horizontal(2 * pl.col("2011") - pl.col("2012"), pl.lit(1)).cast(pl.Int64),
        year=pl.lit(2010, dtype=pl.Int64)).select(["codmun_6", "year", "pop"]).drop_nulls("pop")
    pop_ext = pl.concat([df, w]).filter(pl.col("pop").is_not_null()) \
        .with_columns(pl.col("year").cast(pl.Int64), pl.col("pop").cast(pl.Int64))
    log.info("pop_ext (2010-2014): %d rows, anos=%s",
             len(pop_ext), sorted(pop_ext["year"].unique().to_list()))
    return pop_ext


def recompute_rates(pop_ext: pl.DataFrame):
    """Recompute pre-2015 rates from existing counts + pop_ext; keep 2015+ canonical rates."""
    ic = pl.read_parquet(ICSAP).select(["codmun_6", "year", "n_icsap", "icsap_per1k"])
    ic = ic.join(pop_ext, on=["codmun_6", "year"], how="left").with_columns(
        icsap_per1k=pl.when(pl.col("icsap_per1k").is_not_null()).then(pl.col("icsap_per1k"))
          .when((pl.col("pop") > 0)).then(1e3 * pl.col("n_icsap") / pl.col("pop"))
          .otherwise(None)).select(["codmun_6", "year", "icsap_per1k"])

    ps = pl.read_parquet(PSY).select(["codmun_6", "year", "n_suicide", "n_selfharm",
                                      "n_psychF", "suicide_per100k", "selfharm_per100k",
                                      "psychF_mort_per100k"])
    ps = ps.join(pop_ext, on=["codmun_6", "year"], how="left").with_columns([
        pl.when(pl.col("suicide_per100k").is_not_null()).then(pl.col("suicide_per100k"))
          .when(pl.col("pop") > 0).then(1e5 * pl.col("n_suicide") / pl.col("pop")).otherwise(None).alias("suicide_per100k"),
        pl.when(pl.col("selfharm_per100k").is_not_null()).then(pl.col("selfharm_per100k"))
          .when(pl.col("pop") > 0).then(1e5 * pl.col("n_selfharm") / pl.col("pop")).otherwise(None).alias("selfharm_per100k"),
        pl.when(pl.col("psychF_mort_per100k").is_not_null()).then(pl.col("psychF_mort_per100k"))
          .when(pl.col("pop") > 0).then(1e5 * pl.col("n_psychF") / pl.col("pop")).otherwise(None).alias("psychF_mort_per100k"),
    ]).select(["codmun_6", "year", "suicide_per100k", "selfharm_per100k", "psychF_mort_per100k"])
    return ic, ps


def rebuild_panel(label, ic, ps, pop_ext):
    src = INTER / f"staggered_panel_{label}.parquet"
    p = pl.read_parquet(src)
    # drop stale rate columns + pop, rejoin extended versions
    keep = [c for c in p.columns if c not in
            ("icsap_per1k", "suicide_per100k", "selfharm_per100k", "psychF_mort_per100k", "pop")]
    p = p.with_columns(pl.col("year").cast(pl.Int64))
    ic = ic.with_columns(pl.col("year").cast(pl.Int64))
    ps = ps.with_columns(pl.col("year").cast(pl.Int64))
    p = p.select(keep).join(ic, on=["codmun_6", "year"], how="left") \
                      .join(ps, on=["codmun_6", "year"], how="left")
    # refresh pop too (for WLS): canonical 2015+ pop + ext pre-2015
    pop_all = pl.read_parquet(INTER / "pop_municipal_2015_2025.parquet") \
        .with_columns(codmun_6=pl.col("cod_mun").str.slice(0, 6)).rename({"ano": "year"}) \
        .select(["codmun_6", "year", "pop"]) \
        .with_columns(pl.col("year").cast(pl.Int64), pl.col("pop").cast(pl.Int64))
    pop_all = pl.concat([pop_all, pop_ext.select(["codmun_6", "year", "pop"])])
    p = p.join(pop_all, on=["codmun_6", "year"], how="left")
    out = INTER / f"staggered_panel_{label}_ext.parquet"
    p.write_parquet(out, compression="snappy")
    nn = p.filter((pl.col("year") < 2015) & pl.col("icsap_per1k").is_not_null()).height
    log.info("[%s] wrote %s  pre-2015 icsap non-null rows now=%d", label, out.name, nn)


def main():
    t0 = time.time()
    pop_ext = build_pop_ext()
    ic, ps = recompute_rates(pop_ext)
    for label in ["spec07", "pnash48", "psymax60"]:
        rebuild_panel(label, ic, ps, pop_ext)
    log.info("==== done %.1fs ====", time.time() - t0)


if __name__ == "__main__":
    main()
