#!/usr/bin/env python3
"""
98_ans_private_moderator.py  [ans-moderator branch]

Build a municipality private-health-plan-penetration covariate from ANS open data
and test whether the SUS-only limitation binds: are the exposed (treated) catchments
low-penetration municipalities, where SUS administrative data capture essentially
all inpatient psychiatric care?

Source: ANS "Taxa de Cobertura de Planos de Saude" (PDA-047), public, downloaded to
02_data/raw/ans/pda-047-taxa_cobertura.csv (latin1, ';'-delimited, decimal comma).
The file is a current (2026) snapshot by municipality x sex x age. Private
penetration is a slow-moving structural feature of a municipality (income/employment),
so the cross-sectional ranking proxies the pre-closure structure; a psychiatric
closure does not plausibly change a municipality's overall plan penetration.

Outputs:
  02_data/intermediate/ans_private_penetration.parquet  (codmun_6, tx_cobert_med_pct)
  02_data/processed/ans_moderator_descriptive.csv
  04_logs/ans_private_moderator_<date>.log
"""
from __future__ import annotations
import time
from pathlib import Path
import pandas as pd, numpy as np, duckdb

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "02_data" / "raw" / "ans" / "pda-047-taxa_cobertura.csv"
INTER = ROOT / "02_data" / "intermediate"
PROC = ROOT / "02_data" / "processed"
PANEL = INTER / "staggered_panel_pnash48_ext.parquet"
OUT = INTER / "ans_private_penetration.parquet"
LOG = ROOT / "04_logs" / f"ans_private_moderator_{time.strftime('%Y%m%d')}.log"

logf = open(LOG, "w")
def say(m): print(m); logf.write(m + "\n"); logf.flush()
say(f"==== 98_ans_private_moderator {time.strftime('%Y-%m-%d %H:%M')} ====")

# ---- ANS gives beneficiary COUNTS only (POPULACAO column is empty); the
#      denominator is IBGE municipal population, which the project already holds. ----
df = pd.read_csv(RAW, sep=";", encoding="latin1",
                 usecols=["CD_MUNICIPIO", "BENEF_ASSISTENCIA_MEDICA"], dtype=str)
df["benef"] = pd.to_numeric(df.BENEF_ASSISTENCIA_MEDICA, errors="coerce").fillna(0)
m = df.groupby("CD_MUNICIPIO", as_index=False).benef.sum()
m["codmun_6"] = m.CD_MUNICIPIO.astype(str).str.zfill(6)

con = duckdb.connect()
# IBGE municipal population: latest year per municipality in the analysis panel
popm = con.sql(f"""
    SELECT codmun_6, pop FROM read_parquet('{PANEL}')
    QUALIFY row_number() OVER (PARTITION BY codmun_6 ORDER BY year DESC) = 1
""").df()
popm["codmun_6"] = popm.codmun_6.astype(str).str.zfill(6)
m = m.merge(popm, on="codmun_6", how="inner")
m["tx_cobert_med_pct"] = np.where(m["pop"] > 0, m.benef / m["pop"] * 100, np.nan)
pen = m[["codmun_6", "tx_cobert_med_pct", "benef", "pop"]].dropna(subset=["tx_cobert_med_pct"])
pen.to_parquet(OUT, index=False)
say(f"ANS beneficiaries (medical plan): {pen.benef.sum():,.0f} national | "
    f"penetration pop-weighted mean = {np.average(pen.tx_cobert_med_pct, weights=pen['pop']):.1f}% | "
    f"median = {pen.tx_cobert_med_pct.median():.1f}% | munis = {len(pen)}")

# ---- merge to panel: are exposed (treated) catchments low-penetration? ----
con = duckdb.connect()
P = con.sql(f"SELECT DISTINCT codmun_6, g_emb, pop AS panelpop FROM read_parquet('{PANEL}') WHERE year=2014").df()
P["codmun_6"] = P.codmun_6.astype(str).str.zfill(6)
d = P.merge(pen, on="codmun_6", how="left")
match = d.tx_cobert_med_pct.notna().mean() * 100
say(f"panel munis matched to ANS: {match:.0f}%")
d["treated"] = (d.g_emb.fillna(0) > 0)

rows = []
for grp, sub in [("treated (exposed)", d[d.treated]), ("never-treated", d[~d.treated]), ("all", d)]:
    p = sub.tx_cobert_med_pct.dropna()
    rows.append(dict(group=grp, n=len(p), mean_pct=round(p.mean(), 1), median_pct=round(p.median(), 1),
                     share_lt5=round((p < 5).mean() * 100, 0), share_lt10=round((p < 10).mean() * 100, 0),
                     share_lt20=round((p < 20).mean() * 100, 0)))
desc = pd.DataFrame(rows)
desc.to_csv(PROC / "ans_moderator_descriptive.csv", index=False)
say("\n=== private penetration by exposure group (current ANS snapshot) ===")
say(desc.to_string(index=False))

# high/low split flag for the event-study heterogeneity (median among treated)
med_tr = d[d.treated].tx_cobert_med_pct.median()
say(f"\nmedian penetration among treated = {med_tr:.1f}% (high/low split threshold)")
pen2 = pen.copy()
pen2["low_private"] = (pen2.tx_cobert_med_pct < med_tr).astype(int)
pen2[["codmun_6", "tx_cobert_med_pct", "low_private"]].to_parquet(INTER / "ans_private_penetration.parquet", index=False)
say("wrote ans_private_penetration.parquet (with low_private flag)")
say("done")
logf.close()
