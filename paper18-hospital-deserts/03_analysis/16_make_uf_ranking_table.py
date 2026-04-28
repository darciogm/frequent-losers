"""
16_make_uf_ranking_table.py

Gera tabela LaTeX de ranking estado-a-estado por |divergence| média
(sistema mais mal calibrado primeiro), com decomposição em pos/neg
e contagem de extremos.

Output: 01_manuscript/tables/tab_uf_ranking.tex
"""

from __future__ import annotations
import logging
import sys
from pathlib import Path
import polars as pl

ROOT = Path(__file__).resolve().parents[1]
INTER = ROOT / "02_data" / "intermediate"
LOG = ROOT / "04_logs"
TABLES = ROOT / "01_manuscript" / "tables"

REG = {
    "AC":"N","AM":"N","AP":"N","PA":"N","RO":"N","RR":"N","TO":"N",
    "AL":"NE","BA":"NE","CE":"NE","MA":"NE","PB":"NE","PE":"NE","PI":"NE","RN":"NE","SE":"NE",
    "ES":"SE","MG":"SE","RJ":"SE","SP":"SE",
    "PR":"S","RS":"S","SC":"S",
    "DF":"CO","GO":"CO","MS":"CO","MT":"CO",
}

UF_NAMES = {
    "AC":"Acre","AL":"Alagoas","AM":"Amazonas","AP":"Amap{\\'a}","BA":"Bahia",
    "CE":"Cear{\\'a}","DF":"Distrito Federal","ES":"Esp{\\'i}rito Santo",
    "GO":"Goi{\\'a}s","MA":"Maranh{\\~a}o","MG":"Minas Gerais",
    "MS":"Mato Grosso do Sul","MT":"Mato Grosso","PA":"Par{\\'a}","PB":"Para{\\'i}ba",
    "PE":"Pernambuco","PI":"Piau{\\'i}","PR":"Paran{\\'a}","RJ":"Rio de Janeiro",
    "RN":"Rio Grande do Norte","RO":"Rond{\\^o}nia","RR":"Roraima",
    "RS":"Rio Grande do Sul","SC":"Santa Catarina","SE":"Sergipe","SP":"S{\\~a}o Paulo",
    "TO":"Tocantins",
}

logging.basicConfig(level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[logging.FileHandler(LOG / "16_uf_ranking.log", mode="w"),
              logging.StreamHandler(sys.stdout)])
log = logging.getLogger("uf")


def main():
    div = pl.read_parquet(INTER / "divergence_panel.parquet")
    log.info("panel rows: %d  ufs: %d", len(div), div["uf"].n_unique())

    tab = div.group_by("uf").agg([
        pl.len().alias("n"),
        pl.col("divergence_z").abs().mean().alias("absdiv_mean"),
        pl.col("divergence_z").mean().alias("signed_mean"),
        pl.col("iso_km_hosp").median().alias("km_med"),
        (pl.col("divergence_z") > 1.0).sum().alias("ext_pos"),
        (pl.col("divergence_z") < -1.0).sum().alias("ext_neg"),
    ]).with_columns(
        regiao=pl.col("uf").replace_strict(REG, default="?"),
        ext_total=(pl.col("ext_pos") + pl.col("ext_neg")),
    ).with_columns(
        ext_pct=(pl.col("ext_total") / pl.col("n") * 100.0),
    ).sort("absdiv_mean", descending=True)

    log.info("top-5 |div|: %s", tab.head(5).select(["uf", "absdiv_mean", "signed_mean", "n"]))

    # ---- LaTeX --------------------------------------------------------
    rows = []
    for r in tab.iter_rows(named=True):
        nome = UF_NAMES.get(r["uf"], r["uf"])
        sign = "$+$" if r["signed_mean"] > 0 else "$-$"
        rows.append(
            f"  {r['uf']} & {nome} & {r['regiao']} & {r['n']:5d} & "
            f"{r['absdiv_mean']:.2f} & {sign}{abs(r['signed_mean']):.2f} & "
            f"{r['km_med']:.0f} & {r['ext_pos']:3d} & {r['ext_neg']:3d} & "
            f"{r['ext_pct']:.0f}\\% \\\\"
        )

    tex = (
        "\\begin{table}[ht]\n"
        "\\centering\n"
        "\\caption{State-level miscalibration of the SUS hospital network. "
        "States ordered by mean $|\\divz|$ (highest = least calibrated). "
        "Sign of mean $\\divz$ indicates whether the typical municipality in "
        "the state is more isolated than km suggests ($+$) or less ($-$). "
        "Last column reports the share of the state's municipalities with "
        "$|\\divz| > 1$.}\n"
        "\\label{tab:uf-ranking}\n"
        "\\small\n"
        "\\setlength{\\tabcolsep}{4pt}\n"
        "\\begin{tabular}{llcrrrrrrr}\n"
        "\\toprule\n"
        "UF & State & Reg & $n$ muns & $\\overline{|\\divz|}$ & "
        "$\\overline{\\divz}$ & km med & ext$+$ & ext$-$ & ext\\% \\\\\n"
        "\\midrule\n"
        + "\n".join(rows) + "\n"
        "\\bottomrule\n"
        "\\end{tabular}\n"
        "\\medskip\n\n"
        "\\footnotesize\n"
        "Notes: $\\overline{|\\divz|}$ is the mean of the unsigned divergence "
        "$z$-score; higher means the state's municipalities deviate more from "
        "geographic prediction in either direction. $\\overline{\\divz}$ is "
        "the signed mean; ext$+$ (resp. ext$-$) counts municipalities with "
        "$\\divz > 1$ (resp.\\ $< -1$). km med is the median geographic "
        "distance to the nearest high-complexity hospital, in kilometers.\n"
        "\\end{table}\n"
    )
    out = TABLES / "tab_uf_ranking.tex"
    out.write_text(tex)
    log.info("wrote %s (%d UFs)", out, len(tab))


if __name__ == "__main__":
    main()
