#!/usr/bin/env python
"""
87a_build_distinct_spillover_flags.py

Build GENUINELY DISTINCT network-contamination flags for the spillover /
SUTVA appendix, replacing the old aliased flags in
spillover_control_flags.parquet (where shared-hub, shared-substitute and
high-flow-similarity were all the SAME `same_top_referral_hub` column).

Universe: the 5,565 municipalities in the PNASH-48 ext panel.
Treated set: munis with g_emb>0 in staggered_panel_pnash48_ext.parquet (104).
Pre-closure flow window: 2010-2014 (matches the original flag builder and the
exposure construction).

Distinct definitions
--------------------
(a) same_cir_as_closure_catchment : control whose modal health region
    (regsaude_modal) equals the health region of ANY treated catchment muni
    (measured the year before closure). Pure geography/administrative proxy.

(b) shared_top_referral_hub : control whose modal pre-closure referral
    destination (top-1 hospital by admissions, 2010-2014) is also the top hub
    of a treated muni. Network-revealed but uses ONLY the top edge.

(c) shared_substitute_hospital : control revealed (post-closure admission
    flows) to be a RECIPIENT of redirected volume to the substitute hospitals
    that absorbed displaced patients (recipient_control_flow.parquet from
    69_recipient_control_spillover.py, share-rise threshold 0.01). This is the
    genuine "redirection" channel, distinct from any pre-closure hub.

(d) high_flow_similarity_to_treated : control whose FULL pre-closure
    muni->hospital flow-share vector has cosine similarity above the 90th
    percentile (within controls) to ANY treated muni's flow-share vector.
    Uses the whole flow distribution, not just the top edge -> a priori
    distinct from (b). We report below whether it actually diverges from (b).

We write spillover_control_flags_v2.parquet (do NOT overwrite the original)
and print overlap diagnostics so the .R driver can document distinctness.
"""
import os, sys, time, argparse
import duckdb
import numpy as np
import pandas as pd

ROOT = "/home/darciogm1/projetos/bitter-pills/paper18-hospital-deserts"
PANEL = f"{ROOT}/02_data/intermediate/staggered_panel_pnash48_ext.parquet"
EDGES = f"{ROOT}/02_data/intermediate/bipartite_edges.parquet"
CAPS_CIR = f"{ROOT}/02_data/processed/cnes_caps_cir_municipality_year.parquet"
EXPOSURE = f"{ROOT}/02_data/intermediate/exposure_panel.parquet"
RECIP = f"{ROOT}/02_data/intermediate/recipient_control_flow.parquet"
OUT = f"{ROOT}/02_data/processed/spillover_control_flags_v2.parquet"
LOG = f"{ROOT}/04_logs/spillover_distinct_flags_20260609.log"

PRE0, PRE1 = 2010, 2014
SUBSTITUTE_THRESH = 0.01     # matches recipient-control primary spec
SIM_PCTL = 90                # high-flow-similarity = top decile of max cosine


def log(msg, fh):
    line = f"[{time.strftime('%H:%M:%S')}] {msg}"
    print(line)
    fh.write(line + "\n")
    fh.flush()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    a = ap.parse_args()
    os.makedirs(os.path.dirname(LOG), exist_ok=True)
    fh = open(LOG, "a")
    log("=== 87a_build_distinct_spillover_flags.py ===", fh)
    log(f"host={os.uname().nodename} nproc={os.cpu_count()}", fh)
    if os.path.exists(OUT) and not a.force:
        log(f"cache hit {OUT}; skip (use --force)", fh)
        return

    con = duckdb.connect()
    con.sql("PRAGMA threads=8")
    con.sql("PRAGMA memory_limit='12GB'")
    con.sql("PRAGMA temp_directory='/tmp/duckdb_spill'")
    os.makedirs("/tmp/duckdb_spill", exist_ok=True)

    # --- universe + treated set (the headline panel) -------------------
    munis = con.sql(
        f"SELECT DISTINCT codmun_6 FROM read_parquet('{PANEL}')"
    ).df()["codmun_6"].astype(str).tolist()
    treated = set(con.sql(
        f"SELECT DISTINCT codmun_6 FROM read_parquet('{PANEL}') WHERE g_emb>0"
    ).df()["codmun_6"].astype(str))
    munis = sorted(munis)
    controls = set(munis) - treated
    log(f"universe munis={len(munis)} treated={len(treated)} controls={len(controls)}", fh)

    # --- pre-closure flow edges (muni -> hospital, 2010-2014) ----------
    edges = con.sql(f"""
        SELECT codmun_6, CNES, SUM(n_internacoes) AS n
        FROM read_parquet('{EDGES}')
        WHERE year BETWEEN {PRE0} AND {PRE1}
        GROUP BY 1, 2
    """).df()
    edges["codmun_6"] = edges["codmun_6"].astype(str)
    edges["CNES"] = edges["CNES"].astype(str)
    log(f"pre-window edges rows={len(edges)} munis_with_flow={edges.codmun_6.nunique()} "
        f"hospitals={edges.CNES.nunique()}", fh)

    # ============ (b) shared TOP referral hub =========================
    top = (edges.sort_values(["codmun_6", "n"], ascending=[True, False])
                .groupby("codmun_6").head(1)[["codmun_6", "CNES"]]
                .rename(columns={"CNES": "top_hub"}))
    top_hub = dict(zip(top.codmun_6, top.top_hub))
    treated_hubs = {top_hub[m] for m in treated if m in top_hub}
    flag_b = {m: (m in controls and top_hub.get(m) in treated_hubs) for m in munis}
    log(f"(b) shared_top_referral_hub: {sum(flag_b.values())} controls "
        f"(treated hubs={len(treated_hubs)})", fh)

    # ============ (a) same CIR health region ==========================
    flag_a = {m: False for m in munis}
    if os.path.exists(CAPS_CIR):
        cir = con.sql(
            f"SELECT municipality, year, regsaude_modal FROM read_parquet('{CAPS_CIR}') "
            f"WHERE regsaude_modal IS NOT NULL"
        ).df()
        cir["municipality"] = cir["municipality"].astype(str)
        cir["regsaude_modal"] = cir["regsaude_modal"].astype(str)
        # treated catchment health regions, measured year before closure
        exp = con.sql(
            f"SELECT codmun_6, year_closure FROM read_parquet('{EXPOSURE}') WHERE exposed_emb"
        ).df()
        exp["codmun_6"] = exp["codmun_6"].astype(str)
        exp["year"] = exp["year_closure"].astype(int) - 1
        ev = exp.merge(cir, left_on=["codmun_6", "year"],
                       right_on=["municipality", "year"], how="left")
        treated_cirs = set(ev["regsaude_modal"].dropna().astype(str))
        # modal region per muni across years
        muni_cir = (cir.sort_values("year").groupby("municipality")["regsaude_modal"]
                       .agg(lambda x: x.mode().iloc[0] if not x.mode().empty else x.iloc[-1])
                       .to_dict())
        flag_a = {m: (m in controls and muni_cir.get(m) in treated_cirs and treated_cirs != set())
                  for m in munis}
        log(f"(a) same_cir_as_closure_catchment: {sum(flag_a.values())} controls "
            f"(treated CIRs={len(treated_cirs)})", fh)
    else:
        log("(a) CIR file missing -> all False", fh)

    # ============ (c) shared SUBSTITUTE hospital (recipient flow) =====
    flag_c = {m: False for m in munis}
    if os.path.exists(RECIP):
        recip = con.sql(
            f"SELECT codmun_6, max_delta_share FROM read_parquet('{RECIP}')"
        ).df()
        recip["codmun_6"] = recip["codmun_6"].astype(str)
        recip_set = set(recip.loc[recip.max_delta_share > SUBSTITUTE_THRESH, "codmun_6"])
        flag_c = {m: (m in controls and m in recip_set) for m in munis}
        log(f"(c) shared_substitute_hospital (recipient flow, thresh>{SUBSTITUTE_THRESH}): "
            f"{sum(flag_c.values())} controls", fh)
    else:
        log("(c) recipient flow file missing -> all False", fh)

    # ============ (d) high FLOW SIMILARITY (cosine over full vector) ==
    # Build sparse-ish flow-share matrix: rows = munis, cols = hospitals.
    hosp = sorted(edges.CNES.unique())
    hidx = {h: i for i, h in enumerate(hosp)}
    midx = {m: i for i, m in enumerate(munis)}
    M = np.zeros((len(munis), len(hosp)), dtype=np.float64)
    for m, c, n in zip(edges.codmun_6, edges.CNES, edges.n):
        if m in midx:                 # some flow munis are outside panel
            M[midx[m], hidx[c]] = n
    rowsum = M.sum(axis=1, keepdims=True)
    rowsum[rowsum == 0] = 1.0
    S = M / rowsum                                   # flow-share vectors
    norms = np.linalg.norm(S, axis=1, keepdims=True)
    norms[norms == 0] = 1.0
    Sn = S / norms                                   # L2-normalized
    treat_rows = np.array([midx[m] for m in treated if m in midx])
    # max cosine of each muni to ANY treated muni
    cos = Sn @ Sn[treat_rows].T                       # (n_muni, n_treated)
    max_cos = cos.max(axis=1)
    ctrl_mask = np.array([m in controls for m in munis])
    # threshold at SIM_PCTL among controls that have any flow
    has_flow = (M.sum(axis=1) > 0)
    ctrl_flow = ctrl_mask & has_flow
    thr = np.percentile(max_cos[ctrl_flow], SIM_PCTL)
    flag_d = {munis[i]: bool(ctrl_mask[i] and has_flow[i] and max_cos[i] >= thr)
              for i in range(len(munis))}
    log(f"(d) high_flow_similarity_to_treated: cosine>=p{SIM_PCTL}={thr:.4f} -> "
        f"{sum(flag_d.values())} controls", fh)

    # --- overlap diagnostics (is (d) actually distinct from (b)?) -----
    def jacc(x, y):
        sx = {m for m in munis if x[m]}
        sy = {m for m in munis if y[m]}
        u = len(sx | sy)
        return (len(sx & sy) / u) if u else float("nan"), len(sx & sy), len(sx), len(sy)
    for name, (fx, fy) in {
        "b_hub vs d_sim": (flag_b, flag_d),
        "b_hub vs c_sub": (flag_b, flag_c),
        "c_sub vs d_sim": (flag_c, flag_d),
        "a_cir vs b_hub": (flag_a, flag_b),
    }.items():
        j, inter, nx, ny = jacc(fx, fy)
        log(f"  overlap {name}: jaccard={j:.3f} intersect={inter} (|x|={nx},|y|={ny})", fh)

    # --- assemble + write ---------------------------------------------
    df = pd.DataFrame({"codmun_6": munis})
    df["treated_flow"] = df.codmun_6.isin(treated)
    df["same_cir_as_closure_catchment"] = df.codmun_6.map(flag_a)
    df["shared_top_referral_hub"] = df.codmun_6.map(flag_b)
    df["shared_substitute_hospital"] = df.codmun_6.map(flag_c)
    df["high_flow_similarity_to_treated"] = df.codmun_6.map(flag_d)
    df["contaminated_control_any"] = (
        df.same_cir_as_closure_catchment
        | df.shared_top_referral_hub
        | df.shared_substitute_hospital
        | df.high_flow_similarity_to_treated
    ) & (~df.treated_flow)
    for c in df.columns[1:]:
        df[c] = df[c].fillna(False).astype(bool)
    df.to_parquet(OUT)
    n_any = int((df.contaminated_control_any).sum())
    log(f"contaminated_control_any (union of a,b,c,d): {n_any} controls", fh)
    log(f"wrote {OUT} rows={len(df)}", fh)
    fh.close()


if __name__ == "__main__":
    main()
