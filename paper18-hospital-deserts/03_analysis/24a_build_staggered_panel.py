"""
24a_build_staggered_panel.py

Constrói o painel município × ano pré-CS21, juntando:
- exposure_panel.parquet (S2): qual município foi exposto a qual fechamento,
  via E1 (embedding) ou E2 (km), em qual ano
- travel_burden_panel.parquet (S3): outcome principal
- icsap_panel.parquet (S4): outcome secundário
- alt_outcomes.parquet (17c): ami_inhosp_mort_pct (placebo apêndice)
- pop, pib (controles)

Convenção de tratamento (Callaway-Sant'Anna):
  Para cada município m:
    - g_emb_m = primeiro ano em que m foi exposto via E1 a algum fechamento
                (0 se nunca foi E1-exposto)
    - g_km_m  = primeiro ano em que m foi exposto via E2 a algum fechamento
                (0 se nunca foi E2-exposto)

  Estimação principal (CS21 via gname = g_emb):
    - tratados: g_emb > 0 (97 + 44 = 141 município-fechamento, mas únicos)
    - controles válidos: g_emb = 0 (incluindo munis que foram E2-only — viram
      controle E1 mas tratado em outro experimento)

  Estimação placebo (CS21 via gname = g_km):
    - tratados: g_km > 0 e g_emb = 0 (km-only, placebo)
    - controles: g_km = 0 e g_emb = 0 (jamais expostos)

Janela: 2010-2024 com 2020-2021 excluídos (pandemic gap, convertidos em NA).

Output: 02_data/intermediate/staggered_panel.parquet
  Schema: codmun_6, year, uf,
          travel_burden_km, icsap_per1k, ami_inhosp_mort_pct,
          pop, pib_corr, pop_log, pib_log,
          g_emb (int), g_km (int),
          n_treat_emb, n_treat_km (multiplicidade),
          treat_emb_yr (1/0), treat_km_yr (1/0),  # tratado AT year
          rel_t_emb, rel_t_km,  # tempo relativo ao gname (0 se nunca tratado)
          pandemic (bool)
"""

from __future__ import annotations

import argparse
import logging
import sys
import time
from pathlib import Path

import duckdb
import numpy as np
import polars as pl

ROOT = Path(__file__).resolve().parents[1]
INTER = ROOT / "02_data" / "intermediate"
LOG = ROOT / "04_logs"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "24a_build_staggered_panel.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("staggered")

EXP_IN = INTER / "exposure_panel.parquet"
TB_IN = INTER / "travel_burden_panel.parquet"
ICSAP_IN = INTER / "icsap_panel.parquet"
ALT_IN = INTER / "alt_outcomes.parquet"
POP_IN = INTER / "pop_municipal_2015_2025.parquet"
PIB_IN = INTER / "pib_municipal_2015_2023.parquet"
CENT_IN = INTER / "municipios_centroids.parquet"
OUT = INTER / "staggered_panel.parquet"

YR_LO, YR_HI = 2010, 2024
PANDEMIC_YEARS = {2020, 2021}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    if OUT.exists() and not args.force:
        log.info("output já existe — usar --force para reprocessar")
        return

    t0 = time.time()
    log.info("==== begin staggered panel build ====")

    # ---- 1) gname por município (primeiro ano de exposição E1 e E2) ----
    log.info("[1/5] computando gname por município (primeiro ano de exposição)...")
    exp = pl.read_parquet(EXP_IN)
    log.info("    exposure_panel rows: %d", len(exp))

    g_emb = exp.filter(pl.col("exposed_emb")) \
               .group_by("codmun_6") \
               .agg([
                   pl.col("year_closure").min().alias("g_emb"),
                   pl.len().alias("n_treat_emb"),
               ])
    g_km = exp.filter(pl.col("exposed_km")) \
              .group_by("codmun_6") \
              .agg([
                  pl.col("year_closure").min().alias("g_km"),
                  pl.len().alias("n_treat_km"),
              ])
    log.info("    munis com algum E1: %d", len(g_emb))
    log.info("    munis com algum E2: %d", len(g_km))

    # ---- 2) universo de munis (todos, incluindo nunca-tratados) ----
    log.info("[2/5] construindo universo de munis...")
    cent = pl.read_parquet(CENT_IN).select(["cod_mun_6", "uf"]) \
              .rename({"cod_mun_6": "codmun_6"})
    munis = cent.unique(subset=["codmun_6"])
    log.info("    munis no universo: %d", len(munis))

    # ---- 3) painel mun × year ----
    log.info("[3/5] expandindo painel mun × year...")
    years = pl.DataFrame({"year": list(range(YR_LO, YR_HI + 1))})
    panel = munis.join(years, how="cross")
    log.info("    panel rows: %d", len(panel))

    panel = panel.join(g_emb, on="codmun_6", how="left") \
                 .join(g_km, on="codmun_6", how="left") \
                 .with_columns([
                     pl.col("g_emb").fill_null(0),
                     pl.col("g_km").fill_null(0),
                     pl.col("n_treat_emb").fill_null(0),
                     pl.col("n_treat_km").fill_null(0),
                 ])

    # ---- 4) outcomes ----
    log.info("[4/5] juntando outcomes (travel burden, ICSAP, AMI mort)...")
    tb = pl.read_parquet(TB_IN).select(["codmun_6", "year", "travel_burden_km",
                                         "travel_burden_emb", "share_outflow"])
    icsap = pl.read_parquet(ICSAP_IN).select(["codmun_6", "year", "icsap_per1k",
                                              "icsap_share_pct"])
    alt = pl.read_parquet(ALT_IN).select(["codmun_6", "year", "ami_inhosp_mort_pct"])

    panel = panel.join(tb, on=["codmun_6", "year"], how="left") \
                 .join(icsap, on=["codmun_6", "year"], how="left") \
                 .join(alt, on=["codmun_6", "year"], how="left")

    # ---- 5) controles: pop e pib ----
    log.info("[5/5] juntando controles (pop, pib)...")
    pop = pl.read_parquet(POP_IN).with_columns(
        codmun_6=pl.col("cod_mun").str.slice(0, 6)
    ).rename({"ano": "year"}).select(["codmun_6", "year", "pop"])

    pib = pl.read_parquet(PIB_IN).with_columns(
        codmun_6=pl.col("cod_mun").str.slice(0, 6)
    ).rename({"ano": "year"}).select(["codmun_6", "year", "pib_corr"])

    panel = panel.join(pop, on=["codmun_6", "year"], how="left") \
                 .join(pib, on=["codmun_6", "year"], how="left")

    # ---- adicionar variáveis derivadas ----
    panel = panel.with_columns([
        pl.col("pop").log().alias("pop_log"),
        pl.col("pib_corr").log().alias("pib_log"),
        pl.col("year").is_in(list(PANDEMIC_YEARS)).alias("pandemic"),
        # tempo relativo ao gname (CS21 usa este formato)
        pl.when(pl.col("g_emb") > 0)
          .then(pl.col("year") - pl.col("g_emb"))
          .otherwise(pl.lit(None, dtype=pl.Int32))
          .alias("rel_t_emb"),
        pl.when(pl.col("g_km") > 0)
          .then(pl.col("year") - pl.col("g_km"))
          .otherwise(pl.lit(None, dtype=pl.Int32))
          .alias("rel_t_km"),
        # treat at year flags
        ((pl.col("g_emb") > 0) & (pl.col("year") >= pl.col("g_emb"))).alias("treat_emb_yr"),
        ((pl.col("g_km")  > 0) & (pl.col("year") >= pl.col("g_km"))).alias("treat_km_yr"),
    ])

    # ---- ID numérico (CS21 exige) ----
    muni_to_id = {m: i + 1 for i, m in enumerate(sorted(panel["codmun_6"].unique().to_list()))}
    panel = panel.with_columns(
        muni_id=pl.col("codmun_6").map_elements(lambda m: muni_to_id[m], return_dtype=pl.Int32)
    )

    # selecionar e gravar
    out_cols = [
        "muni_id", "codmun_6", "uf", "year",
        "g_emb", "g_km", "n_treat_emb", "n_treat_km",
        "rel_t_emb", "rel_t_km", "treat_emb_yr", "treat_km_yr", "pandemic",
        "travel_burden_km", "travel_burden_emb", "share_outflow",
        "icsap_per1k", "icsap_share_pct", "ami_inhosp_mort_pct",
        "pop", "pib_corr", "pop_log", "pib_log",
    ]
    panel = panel.select(out_cols).sort(["muni_id", "year"])
    panel.write_parquet(OUT, compression="snappy")
    log.info("wrote %s (rows=%d)", OUT, len(panel))

    # ---- sumarios ----
    log.info("\n=== contagem de tratamento ===")
    log.info("\n%s", panel.group_by(["g_emb", "g_km"])
             .agg(pl.col("muni_id").n_unique().alias("n_munis"))
             .filter((pl.col("g_emb") > 0) | (pl.col("g_km") > 0))
             .sort(["g_emb", "g_km"]))

    log.info("\n=== resumo por status ===")
    status_summary = panel.unique(subset=["muni_id"]).select([
        ((pl.col("g_emb") == 0) & (pl.col("g_km") == 0)).sum().alias("pure_control"),
        ((pl.col("g_emb")  > 0) & (pl.col("g_km")  > 0)).sum().alias("both"),
        ((pl.col("g_emb")  > 0) & (pl.col("g_km") == 0)).sum().alias("emb_only"),
        ((pl.col("g_emb") == 0) & (pl.col("g_km")  > 0)).sum().alias("km_only_placebo"),
    ])
    log.info("\n%s", status_summary)

    log.info("\n=== outcomes disponíveis (não-NA por outcome) ===")
    avail = panel.select([
        pl.col("travel_burden_km").is_not_null().sum().alias("tb_km_n"),
        pl.col("icsap_per1k").is_not_null().sum().alias("icsap_n"),
        pl.col("ami_inhosp_mort_pct").is_not_null().sum().alias("ami_n"),
        pl.col("pop").is_not_null().sum().alias("pop_n"),
        pl.col("pib_corr").is_not_null().sum().alias("pib_n"),
    ])
    log.info("\n%s", avail)

    log.info("==== done ==== elapsed %.1fs", time.time() - t0)


if __name__ == "__main__":
    main()
