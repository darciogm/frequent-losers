#!/usr/bin/env python3
"""
95_build_disagreement_groups.py  [disagreement-placebo branch]

Exposure-validation placebo. Classify each municipality-closure pair by whether
the flow rule and the top-3 distance rule flag it, then build mutually exclusive
municipality-level treatment cohorts for an event study. The prediction: the
utilization first stage loads on flow-revealed reliance, not geographic proximity.

Source of flags: 02_data/processed/closure_sample_exposure_flags_long.parquet
(the paper's canonical exposure flags; flow_exposed uses theta=0.05, distance_exposed
uses the top-3 nearest rule). Samples: f5_economically_meaningful_closures (60) and
pnash_psychiatric_closures (48).

Outputs:
  02_data/processed/disagreement_groups_long.parquet     (pair level)
  02_data/processed/disagreement_groups_summary.csv      (counts by sample/group)
  02_data/processed/disagreement_event_panel.parquet     (muni-year, cohorts + outcomes)
  04_logs/disagreement_groups_<date>.log
"""
from __future__ import annotations
import time
from pathlib import Path
import duckdb, numpy as np, pandas as pd

ROOT = Path(__file__).resolve().parents[1]
INTER = ROOT / "02_data" / "intermediate"
PROC = ROOT / "02_data" / "processed"
FLAGS = PROC / "closure_sample_exposure_flags_long.parquet"
PANEL = INTER / "staggered_panel_pnash48_ext.parquet"   # national muni-year panel
PSYCH = INTER / "psych_outcomes_panel.parquet"
LOG = ROOT / "04_logs" / f"disagreement_groups_{time.strftime('%Y%m%d')}.log"

SAMPLES = {"f5_economically_meaningful_closures": "F5_measurement",
           "pnash_psychiatric_closures": "PNASH_psychiatric"}

logf = open(LOG, "w")
def say(m): print(m); logf.write(m + "\n"); logf.flush()

con = duckdb.connect(); con.execute("PRAGMA threads=12")
say(f"==== 95_build_disagreement_groups {time.strftime('%Y-%m-%d %H:%M')} ====")

# ---- A: pair-level classification ----
flags = con.sql(f"""
    SELECT sample_id, municipality AS codmun_6, CNES, year_closure,
           flow_exposed, distance_exposed
    FROM read_parquet('{FLAGS}')
    WHERE sample_id IN ('f5_economically_meaningful_closures','pnash_psychiatric_closures')
""").df()
flags["codmun_6"] = flags.codmun_6.astype(str).str.zfill(6)

def cat(r):
    if r.flow_exposed and not r.distance_exposed: return "flow_only"
    if r.distance_exposed and not r.flow_exposed: return "distance_only"
    if r.flow_exposed and r.distance_exposed: return "both"
    return "neither"
flags["category"] = flags.apply(cat, axis=1)
pairs = flags[flags.category != "neither"].copy()   # union (flagged by either rule)
pairs.to_parquet(PROC / "disagreement_groups_long.parquet", index=False)

# ---- summary + reproduce known F5 counts ----
say("\n=== pair-level counts by sample ===")
summ_rows = []
for sid, lab in SAMPLES.items():
    s = pairs[pairs.sample_id == sid]
    c = s.category.value_counts().to_dict()
    row = dict(sample_id=sid, label=lab, n_closures=s.CNES.nunique(),
               flow_only=c.get("flow_only", 0), distance_only=c.get("distance_only", 0),
               both=c.get("both", 0), union_pairs=len(s),
               muni_flow_only=s[s.category=="flow_only"].codmun_6.nunique(),
               muni_distance_only=s[s.category=="distance_only"].codmun_6.nunique(),
               muni_both=s[s.category=="both"].codmun_6.nunique())
    summ_rows.append(row)
    say(f"  {lab}: closures={row['n_closures']} | flow_only={row['flow_only']} "
        f"distance_only={row['distance_only']} both={row['both']} union={row['union_pairs']}")
pd.DataFrame(summ_rows).to_csv(PROC / "disagreement_groups_summary.csv", index=False)

f5 = next(r for r in summ_rows if r["sample_id"] == "f5_economically_meaningful_closures")
ok = (f5["flow_only"], f5["distance_only"], f5["both"], f5["union_pairs"]) == (97, 196, 44, 337)
say(f"\nF5 reproduces 97/196/44/337: {ok}" + ("" if ok else "  <-- MISMATCH, investigate"))

# ---- B: mutually exclusive municipality-level cohorts (earliest-event) ----
say("\n=== municipality-level cohorts (earliest flagged closure) ===")
panel_rows = []
for sid, lab in SAMPLES.items():
    s = pairs[pairs.sample_id == sid]
    # earliest flagged year per muni
    ymin = s.groupby("codmun_6").year_closure.min().rename("cohort_year")
    g = s.merge(ymin, on="codmun_6")
    at_earliest = g[g.year_closure == g.cohort_year]
    # category at earliest year; if >1 distinct category -> mixed
    catn = at_earliest.groupby("codmun_6").category.nunique()
    catv = at_earliest.groupby("codmun_6").category.agg(lambda x: x.iloc[0])
    muni_group = pd.DataFrame({"cohort_year": ymin})
    muni_group["group"] = np.where(catn.reindex(muni_group.index) > 1, "mixed",
                                   catv.reindex(muni_group.index))
    n_mixed = int((muni_group.group == "mixed").sum())
    vc = muni_group.group.value_counts().to_dict()
    say(f"  {lab}: flow_only={vc.get('flow_only',0)} distance_only={vc.get('distance_only',0)} "
        f"both={vc.get('both',0)} mixed={n_mixed} (munis flagged={len(muni_group)})")
    muni_group = muni_group.reset_index().rename(columns={"index": "codmun_6"})
    muni_group["codmun_6"] = muni_group.codmun_6.astype(str)
    muni_group["sample_id"] = lab
    panel_rows.append(muni_group)

grp = pd.concat(panel_rows, ignore_index=True)

# ---- merge to national muni-year panel + outcomes ----
P = con.sql(f"""SELECT codmun_6, year, muni_id, pop, travel_burden_km,
                       suicide_per100k, selfharm_per100k FROM read_parquet('{PANEL}')""").df()
P["codmun_6"] = P.codmun_6.astype(str).str.zfill(6)
po = con.sql(f"SELECT codmun_6, year, psych_adm_per1k FROM read_parquet('{PSYCH}')").df()
po["codmun_6"] = po.codmun_6.astype(str).str.zfill(6)
P = P.merge(po, on=["codmun_6", "year"], how="left")

# flagged munis (any sample) -> their group/cohort; everyone else -> never (per sample)
out = []
for lab in SAMPLES.values():
    gg = grp[grp.sample_id == lab][["codmun_6", "group", "cohort_year"]]
    d = P.merge(gg, on="codmun_6", how="left")
    d["group"] = d.group.fillna("never")
    d["sample_id"] = lab
    d["event_time"] = np.where(d.group == "never", np.nan, d.year - d.cohort_year)
    out.append(d)
panel = pd.concat(out, ignore_index=True)
panel.to_parquet(PROC / "disagreement_event_panel.parquet", index=False)
say(f"\nwrote disagreement_event_panel.parquet ({len(panel):,} rows, "
    f"{panel.codmun_6.nunique()} munis x 2 samples)")
say(f"travel_burden non-null: {panel.travel_burden_km.notna().mean()*100:.0f}% | "
    f"psych_adm non-null: {panel.psych_adm_per1k.notna().mean()*100:.0f}%")
say("done")
logf.close()
