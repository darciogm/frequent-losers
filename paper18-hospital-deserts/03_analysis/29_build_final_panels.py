"""
29_build_final_panels.py

Constrói os 5 painéis staggered finais para o S5 híbrido:

  P1: F5_main         — todos os 60 closures exógenos do filtro estatístico F5
  P2: F6_v2           — 51 closures com motivo_v2 ∈ {admin, fiscal, falencia}
  P3: F6_admin        — 30 closures motivo_v2 = administrativo (Reforma Psiq, descredencia)
  P4: F6_falencia     — 11 closures motivo_v2 = falencia (CNPJ BAIXADA, insolvência privada)
  P5: F6_fiscal       — 10 closures motivo_v2 = fiscal (CNPJ INAPTA, irregularidade)

Cada painel mantém o mesmo grupo de controle (nunca-tratado em E1 *naquele
sub-conjunto* de closures). Tratado = município E1-exposto a algum closure
desse subset.

Outputs:
  02_data/intermediate/staggered_panel_F5_main.parquet
  02_data/intermediate/staggered_panel_F6_v2.parquet
  02_data/intermediate/staggered_panel_F6_admin.parquet
  02_data/intermediate/staggered_panel_F6_falencia.parquet
  02_data/intermediate/staggered_panel_F6_fiscal.parquet

Cada parquet tem o schema do staggered_panel.parquet original (24a):
  muni_id, codmun_6, uf, year, g_emb, g_km, n_treat_emb, n_treat_km,
  rel_t_emb, rel_t_km, treat_emb_yr, treat_km_yr, pandemic,
  travel_burden_km, travel_burden_emb, share_outflow,
  icsap_per1k, icsap_share_pct, ami_inhosp_mort_pct,
  pop, pib_corr, pop_log, pib_log
"""

from __future__ import annotations

import argparse
import logging
import sys
import time
from pathlib import Path

import polars as pl

ROOT = Path(__file__).resolve().parents[1]
INTER = ROOT / "02_data" / "intermediate"
LOG = ROOT / "04_logs"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "29_build_final_panels.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("final_panels")

EXP_FILE = INTER / "exposure_panel.parquet"
CLO_FILE = INTER / "hospital_closures_exogenous.parquet"
CLASS_FILE = INTER / "closures_classified_v2.parquet"
HUMAN_FILE = INTER / "closures_human_validated.parquet"
TB_FILE = INTER / "travel_burden_panel.parquet"
ICSAP_FILE = INTER / "icsap_panel.parquet"
ALT_FILE = INTER / "alt_outcomes.parquet"
POP_FILE = INTER / "pop_municipal_2015_2025.parquet"
PIB_FILE = INTER / "pib_municipal_2015_2023.parquet"
CENT_FILE = INTER / "municipios_centroids.parquet"

YR_LO, YR_HI = 2010, 2024
PANDEMIC_YEARS = {2020, 2021}


def build_panel(label: str, treated_cnes: list[str]):
    """Constrói painel staggered com tratamento restrito ao subset treated_cnes."""
    log.info("\n=== BUILD %s (n_closures=%d) ===", label, len(treated_cnes))

    exp = pl.read_parquet(EXP_FILE)
    exp_subset = exp.filter(pl.col("CNES").is_in(treated_cnes))
    log.info("  exposure linhas no subset: %d", len(exp_subset))

    g_emb = exp_subset.filter(pl.col("exposed_emb")) \
                       .group_by("codmun_6") \
                       .agg([pl.col("year_closure").min().alias("g_emb"),
                             pl.len().alias("n_treat_emb")])
    g_km = exp_subset.filter(pl.col("exposed_km")) \
                      .group_by("codmun_6") \
                      .agg([pl.col("year_closure").min().alias("g_km"),
                            pl.len().alias("n_treat_km")])
    log.info("  munis E1: %d  munis E2: %d", len(g_emb), len(g_km))

    cent = pl.read_parquet(CENT_FILE).select(["cod_mun_6", "uf"]) \
                                       .rename({"cod_mun_6": "codmun_6"})
    munis = cent.unique(subset=["codmun_6"])
    years = pl.DataFrame({"year": list(range(YR_LO, YR_HI + 1))})
    panel = munis.join(years, how="cross")

    panel = panel.join(g_emb, on="codmun_6", how="left") \
                 .join(g_km, on="codmun_6", how="left") \
                 .with_columns([
                     pl.col("g_emb").fill_null(0),
                     pl.col("g_km").fill_null(0),
                     pl.col("n_treat_emb").fill_null(0),
                     pl.col("n_treat_km").fill_null(0),
                 ])

    tb = pl.read_parquet(TB_FILE).select(["codmun_6", "year",
                                           "travel_burden_km",
                                           "travel_burden_emb", "share_outflow"])
    icsap = pl.read_parquet(ICSAP_FILE).select(["codmun_6", "year",
                                                "icsap_per1k", "icsap_share_pct"])
    alt = pl.read_parquet(ALT_FILE).select(["codmun_6", "year",
                                             "ami_inhosp_mort_pct"])
    panel = panel.join(tb, on=["codmun_6", "year"], how="left") \
                 .join(icsap, on=["codmun_6", "year"], how="left") \
                 .join(alt, on=["codmun_6", "year"], how="left")

    pop = pl.read_parquet(POP_FILE).with_columns(
        codmun_6=pl.col("cod_mun").str.slice(0, 6)
    ).rename({"ano": "year"}).select(["codmun_6", "year", "pop"])
    pib = pl.read_parquet(PIB_FILE).with_columns(
        codmun_6=pl.col("cod_mun").str.slice(0, 6)
    ).rename({"ano": "year"}).select(["codmun_6", "year", "pib_corr"])
    panel = panel.join(pop, on=["codmun_6", "year"], how="left") \
                 .join(pib, on=["codmun_6", "year"], how="left") \
                 .with_columns([
                     pl.col("pop").log().alias("pop_log"),
                     pl.col("pib_corr").log().alias("pib_log"),
                     pl.col("year").is_in(list(PANDEMIC_YEARS)).alias("pandemic"),
                     pl.when(pl.col("g_emb") > 0)
                       .then(pl.col("year") - pl.col("g_emb"))
                       .otherwise(pl.lit(None, dtype=pl.Int32))
                       .alias("rel_t_emb"),
                     pl.when(pl.col("g_km") > 0)
                       .then(pl.col("year") - pl.col("g_km"))
                       .otherwise(pl.lit(None, dtype=pl.Int32))
                       .alias("rel_t_km"),
                     ((pl.col("g_emb") > 0) & (pl.col("year") >= pl.col("g_emb"))).alias("treat_emb_yr"),
                     ((pl.col("g_km")  > 0) & (pl.col("year") >= pl.col("g_km"))).alias("treat_km_yr"),
                 ])

    muni_to_id = {m: i + 1 for i, m in
                  enumerate(sorted(panel["codmun_6"].unique().to_list()))}
    panel = panel.with_columns(
        muni_id=pl.col("codmun_6").map_elements(lambda m: muni_to_id[m],
                                                  return_dtype=pl.Int32)
    )
    out_cols = [
        "muni_id", "codmun_6", "uf", "year",
        "g_emb", "g_km", "n_treat_emb", "n_treat_km",
        "rel_t_emb", "rel_t_km", "treat_emb_yr", "treat_km_yr", "pandemic",
        "travel_burden_km", "travel_burden_emb", "share_outflow",
        "icsap_per1k", "icsap_share_pct", "ami_inhosp_mort_pct",
        "pop", "pib_corr", "pop_log", "pib_log",
    ]
    panel = panel.select(out_cols).sort(["muni_id", "year"])

    out_path = INTER / f"staggered_panel_{label}.parquet"
    panel.write_parquet(out_path, compression="snappy")
    log.info("  wrote %s (rows=%d)", out_path, len(panel))

    n_treated_emb = panel.filter(pl.col("g_emb") > 0)["muni_id"].n_unique()
    n_treated_km = panel.filter(pl.col("g_km") > 0)["muni_id"].n_unique()
    n_pure_ctrl = panel.filter((pl.col("g_emb") == 0) & (pl.col("g_km") == 0))["muni_id"].n_unique()
    log.info("  munis E1 tratados: %d  E2 tratados: %d  controles puros: %d",
             n_treated_emb, n_treated_km, n_pure_ctrl)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    t0 = time.time()
    log.info("==== begin build final panels ====")

    closures = pl.read_parquet(CLO_FILE).filter(pl.col("exogenous"))
    clas = pl.read_parquet(CLASS_FILE)

    # P1: F5_main = todos os 60 F5_survivor
    f5_cnes = closures["CNES"].to_list()
    log.info("F5_main CNES: %d", len(f5_cnes))

    # P2-P5: filtros baseados em motivo_v2
    f6_v2 = clas.filter(
        pl.col("motivo_v2").is_in(["administrativo", "fiscal", "falencia"])
    )
    log.info("F6_v2 (todos motivos exógenos): %d closures", len(f6_v2))
    f6_v2_cnes = f6_v2["CNES"].to_list()

    f6_admin_cnes = clas.filter(pl.col("motivo_v2") == "administrativo")["CNES"].to_list()
    f6_falencia_cnes = clas.filter(pl.col("motivo_v2") == "falencia")["CNES"].to_list()
    f6_fiscal_cnes = clas.filter(pl.col("motivo_v2") == "fiscal")["CNES"].to_list()

    log.info("Subset sizes: admin=%d falencia=%d fiscal=%d",
             len(f6_admin_cnes), len(f6_falencia_cnes), len(f6_fiscal_cnes))

    build_panel("F5_main",     f5_cnes)
    build_panel("F6_v2",       f6_v2_cnes)
    build_panel("F6_admin",    f6_admin_cnes)
    build_panel("F6_falencia", f6_falencia_cnes)
    build_panel("F6_fiscal",   f6_fiscal_cnes)

    if HUMAN_FILE.exists():
        hv = pl.read_parquet(HUMAN_FILE)
        if "sensitivity_keep_human_validated" in hv.columns:
            f6_hv = hv.filter(
                pl.col("sensitivity_keep_human_validated")
            )
            f6_hv_cnes = f6_hv["CNES"].unique().to_list()
            log.info("F6_human_validated sensitivity subset: %d closures", len(f6_hv_cnes))
            build_panel("F6_human_validated", f6_hv_cnes)
        else:
            log.warning("closures_human_validated.parquet exists but lacks sensitivity_keep_human_validated")

    log.info("==== done ==== elapsed %.1fs", time.time() - t0)


if __name__ == "__main__":
    main()
