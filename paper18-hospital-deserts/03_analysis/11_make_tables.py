"""
11_make_tables.py

Gera tabelas LaTeX para o paper:
- tab_top15_div_pos.tex  — top-15 divergência positiva (hospital evitado)
- tab_top15_div_neg.tex  — top-15 divergência negativa (km mente)
- tab_tophosp.tex        — top-10 hospitais por |municípios servidos|

Output em 01_manuscript/tables/ pra inclusão direta via \input{}.
"""

from __future__ import annotations

import logging
import sys
import time
from pathlib import Path

import numpy as np
import polars as pl

ROOT = Path(__file__).resolve().parents[1]
INTER = ROOT / "02_data" / "intermediate"
LOG = ROOT / "04_logs"
TABLES = ROOT / "01_manuscript" / "tables"
TABLES.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "11_make_tables.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("tab")


def latex_escape(s: str) -> str:
    return s.replace("&", "\\&").replace("_", "\\_").replace("D'", "D'")


def main():
    t0 = time.perf_counter()
    div = pl.read_parquet(INTER / "divergence_panel.parquet")
    cent = pl.read_parquet(INTER / "municipios_centroids.parquet").select(
        pl.col("cod_mun_6").alias("codmun_6"),
        pl.col("nome_mun").alias("nome"),
    )
    div = div.join(cent, on="codmun_6", how="left")

    # ---- top-15 divergence positiva ---------------------------------
    pos = div.sort("divergence_z", descending=True).head(15)
    log.info("top-15 positiva escrita")

    rows = []
    for r in pos.iter_rows(named=True):
        nome = latex_escape(r["nome"])
        rows.append(
            f"  {r['codmun_6']} & {nome} & {r['uf']} & "
            f"{r['iso_km_hosp']:.0f} & {r['iso_emb_hosp']:.3f} & {r['divergence_z']:+.2f} \\\\"
        )

    pos_tex = (
        "\\begin{table}[ht]\n"
        "\\centering\n"
        "\\caption{Top-15 municipalities with highest positive divergence "
        "(network-revealed isolation exceeds geographic). The nominally "
        "nearest high-complexity hospital is bypassed.}\n"
        "\\label{tab:top15-pos}\n"
        "\\small\n"
        "\\begin{tabular}{llcrrr}\n"
        "\\toprule\n"
        "IBGE-6 & Municipality & UF & km to nearest & emb dist & $\\divz$ \\\\\n"
        "\\midrule\n"
        + "\n".join(rows) + "\n"
        "\\bottomrule\n"
        "\\end{tabular}\n"
        "\\medskip\n\n"
        "\\footnotesize\n"
        "Notes: \\textit{km to nearest} is the haversine distance to the "
        "nearest high-complexity hospital with an embedding vector. "
        "\\textit{emb dist} is $1 - \\cos$ to the same hospital under the "
        "embedding. $\\divz$ is the standardized difference (Equation "
        "\\ref{eq:divz}).\n"
        "\\end{table}\n"
    )
    (TABLES / "tab_top15_div_pos.tex").write_text(pos_tex)
    log.info("wrote tab_top15_div_pos.tex (%d rows)", len(pos))

    # ---- top-15 divergence negativa ---------------------------------
    neg = div.sort("divergence_z", descending=False).head(15)
    rows = []
    for r in neg.iter_rows(named=True):
        nome = latex_escape(r["nome"])
        rows.append(
            f"  {r['codmun_6']} & {nome} & {r['uf']} & "
            f"{r['iso_km_hosp']:.0f} & {r['iso_emb_hosp']:.3f} & {r['divergence_z']:+.2f} \\\\"
        )

    neg_tex = (
        "\\begin{table}[ht]\n"
        "\\centering\n"
        "\\caption{Top-15 municipalities with most negative divergence "
        "(network-revealed isolation lies below the geographic). "
        "Geography overstates isolation because patients reach distant "
        "hubs via channels that road geography ignores (river, air, "
        "informal cross-border referral).}\n"
        "\\label{tab:top15-neg}\n"
        "\\small\n"
        "\\begin{tabular}{llcrrr}\n"
        "\\toprule\n"
        "IBGE-6 & Municipality & UF & km to nearest & emb dist & $\\divz$ \\\\\n"
        "\\midrule\n"
        + "\n".join(rows) + "\n"
        "\\bottomrule\n"
        "\\end{tabular}\n"
        "\\medskip\n\n"
        "\\footnotesize\n"
        "Notes: see Table \\ref{tab:top15-pos}.\n"
        "\\end{table}\n"
    )
    (TABLES / "tab_top15_div_neg.tex").write_text(neg_tex)
    log.info("wrote tab_top15_div_neg.tex (%d rows)", len(neg))

    # ---- top-10 hospitais por catchment ------------------------------
    edges = pl.read_parquet(INTER / "bipartite_edges_pooled.parquet")
    by_hosp = edges.group_by("CNES").agg([
        pl.len().alias("n_munis_origem"),
        pl.col("n_internacoes").sum().alias("total_int"),
    ]).sort("total_int", descending=True).head(10)

    # cruzar com hospital_master para obter município modal e nome (via cent)
    master = pl.read_parquet(INTER / "hospital_master.parquet").select([
        "CNES", "codmun_6_modal",
    ])
    by_hosp = by_hosp.join(master, on="CNES", how="left").join(
        cent, left_on="codmun_6_modal", right_on="codmun_6", how="left"
    )

    rows = []
    for r in by_hosp.iter_rows(named=True):
        nome = latex_escape(r["nome"]) if r["nome"] else "—"
        cnes = r["CNES"].lstrip("0") or r["CNES"]
        rows.append(
            f"  {cnes} & {nome} & {r['total_int']:,d} & {r['n_munis_origem']:,d} \\\\"
        )

    tophosp_tex = (
        "\\begin{table}[ht]\n"
        "\\centering\n"
        "\\caption{Top-10 hospitals by total SUS admissions, $2010\\text{--}2024$. "
        "Each row reports the cumulative inpatient flow and the number of "
        "distinct municipalities sending at least one patient. The wide "
        "catchment of the top hospitals reflects the hub structure of the "
        "Brazilian SUS network.}\n"
        "\\label{tab:tophosp}\n"
        "\\small\n"
        "\\begin{tabular}{llrr}\n"
        "\\toprule\n"
        "CNES & Municipality of operation & Admissions & \\# munis. of origin \\\\\n"
        "\\midrule\n"
        + "\n".join(rows) + "\n"
        "\\bottomrule\n"
        "\\end{tabular}\n"
        "\\medskip\n\n"
        "\\footnotesize\n"
        "Notes: CNES are the official Cadastro Nacional de Estabelecimentos de Saúde codes.\n"
        "\\end{table}\n"
    )
    (TABLES / "tab_tophosp.tex").write_text(tophosp_tex)
    log.info("wrote tab_tophosp.tex (%d rows)", len(by_hosp))

    log.info("==== done ==== elapsed=%.1fs", time.perf_counter() - t0)


if __name__ == "__main__":
    main()
