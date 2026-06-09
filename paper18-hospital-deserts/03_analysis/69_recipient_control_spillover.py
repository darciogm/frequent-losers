#!/usr/bin/env python
"""
69_recipient_control_spillover.py — flow-construction helper for the
recipient-control spillover bias bound (referee #1 threat).

Builds, from the revealed post-closure admission flows, the set of
never-treated control municipalities that are "recipients" of redirected
psychiatric volume after the 48 PNASH closures. Emits an intermediate
parquet consumed by 69_recipient_control_spillover.R.

Logic (see header of the .R for the economics):
  For each PNASH closing hospital h closing at t*:
    1. flow-exposed munis of h = munis sending admissions to h in
       [t*-W, t*-1] (the patients about to be displaced).
    2. substitutes of h = hospitals (CNES != h) ranked by the increase in
       inflow FROM h's flow-exposed munis, post [t*+1,t*+W] minus pre
       [t*-W,t*-1]. Keep top-K by that delta with positive delta.
    3. for every municipality m, compute its OWN admission SHARE to the
       substitute set, pre vs post. A muni is a recipient (for this closure)
       if delta_share > THRESH.
  A control is recipient-exposed if it qualifies for ANY closure.

Cache-aware: skips if output exists unless --force.
DuckDB out-of-core, 4 threads (parallel job running).
"""
import argparse, os, sys, time, json
import duckdb

ROOT = "/home/darciogm1/projetos/bitter-pills/paper18-hospital-deserts"
EDGES = f"{ROOT}/02_data/intermediate/bipartite_edges.parquet"
PNASH = f"{ROOT}/02_data/processed/pnash_event_level_dataset.parquet"
OUT   = f"{ROOT}/02_data/intermediate/recipient_control_flow.parquet"
LOG   = f"{ROOT}/04_logs/69_recipient_control_spillover_py.log"


def log(msg, fh):
    line = f"[{time.strftime('%H:%M:%S')}] {msg}"
    print(line); fh.write(line + "\n"); fh.flush()


def build(window, top_k, thresh, fh):
    con = duckdb.connect()
    con.sql("PRAGMA threads=4")
    con.sql("PRAGMA memory_limit='12GB'")
    con.sql("PRAGMA temp_directory='/tmp/duckdb_spill'")

    pnash = con.sql(f"SELECT CNES, closure_year FROM read_parquet('{PNASH}')").df()
    log(f"PNASH closures: {len(pnash)} (years {sorted(pnash.closure_year.unique())})", fh)

    # whole-edges in memory view (2.7M rows -> fine)
    con.sql(f"CREATE TEMP VIEW E AS SELECT codmun_6, CNES, year, n_internacoes FROM read_parquet('{EDGES}')")

    all_recip = []          # rows: codmun_6, CNES_closed, delta_share
    subs_audit = []         # rows: CNES_closed, sub_CNES, delta_inflow, rank
    per_closure = []        # diagnostics

    for _, r in pnash.iterrows():
        h, t = r.CNES, int(r.closure_year)
        pre0, pre1 = t - window, t - 1
        post0, post1 = t + 1, t + window

        # 1. flow-exposed munis of h (pre window)
        exp = con.sql(f"""
            SELECT codmun_6, SUM(n_internacoes) v
            FROM E WHERE CNES='{h}' AND year BETWEEN {pre0} AND {pre1}
            GROUP BY codmun_6 HAVING SUM(n_internacoes) > 0
        """).df()
        n_exp = len(exp)
        if n_exp == 0:
            per_closure.append(dict(CNES=h, t=t, n_exposed=0, n_subs=0, n_recip=0))
            continue
        exp_list = "','".join(exp.codmun_6.tolist())

        # 2. substitutes: inflow FROM h's exposed munis, post minus pre, by hospital
        subs = con.sql(f"""
            WITH pre AS (
              SELECT CNES, SUM(n_internacoes) v FROM E
              WHERE codmun_6 IN ('{exp_list}') AND CNES != '{h}'
                AND year BETWEEN {pre0} AND {pre1} GROUP BY CNES),
            post AS (
              SELECT CNES, SUM(n_internacoes) v FROM E
              WHERE codmun_6 IN ('{exp_list}') AND CNES != '{h}'
                AND year BETWEEN {post0} AND {post1} GROUP BY CNES)
            SELECT COALESCE(post.CNES, pre.CNES) AS CNES,
                   COALESCE(post.v,0) - COALESCE(pre.v,0) AS delta
            FROM post FULL OUTER JOIN pre USING (CNES)
            WHERE COALESCE(post.v,0) - COALESCE(pre.v,0) > 0
            ORDER BY delta DESC LIMIT {top_k}
        """).df()
        n_subs = len(subs)
        if n_subs == 0:
            per_closure.append(dict(CNES=h, t=t, n_exposed=n_exp, n_subs=0, n_recip=0))
            continue
        sub_list = "','".join(subs.CNES.astype(str).tolist())
        for rk, (_, sr) in enumerate(subs.iterrows(), 1):
            subs_audit.append(dict(CNES_closed=h, sub_CNES=sr.CNES, delta_inflow=float(sr.delta), rank=rk))

        # 3. for EVERY muni, share to substitute set, pre vs post
        recip = con.sql(f"""
            WITH pre AS (
              SELECT codmun_6,
                     SUM(CASE WHEN CNES IN ('{sub_list}') THEN n_internacoes ELSE 0 END) AS s,
                     SUM(n_internacoes) AS tot
              FROM E WHERE year BETWEEN {pre0} AND {pre1} GROUP BY codmun_6),
            post AS (
              SELECT codmun_6,
                     SUM(CASE WHEN CNES IN ('{sub_list}') THEN n_internacoes ELSE 0 END) AS s,
                     SUM(n_internacoes) AS tot
              FROM E WHERE year BETWEEN {post0} AND {post1} GROUP BY codmun_6)
            SELECT COALESCE(post.codmun_6, pre.codmun_6) AS codmun_6,
                   (CASE WHEN COALESCE(post.tot,0)>0 THEN post.s/post.tot ELSE 0 END) -
                   (CASE WHEN COALESCE(pre.tot,0)>0  THEN pre.s/pre.tot  ELSE 0 END) AS delta_share
            FROM post FULL OUTER JOIN pre USING (codmun_6)
        """).df()
        recip = recip[recip.delta_share > thresh].copy()
        recip["CNES_closed"] = h
        all_recip.append(recip[["codmun_6", "CNES_closed", "delta_share"]])
        per_closure.append(dict(CNES=h, t=t, n_exposed=n_exp, n_subs=n_subs, n_recip=len(recip)))

    import pandas as pd
    recip_df = pd.concat(all_recip, ignore_index=True) if all_recip else \
        pd.DataFrame(columns=["codmun_6", "CNES_closed", "delta_share"])
    subs_df = pd.DataFrame(subs_audit)
    pc_df = pd.DataFrame(per_closure)

    # collapse to muni-level recipient flag (qualifies for ANY closure)
    muni = recip_df.groupby("codmun_6").agg(
        n_closures_recip=("CNES_closed", "nunique"),
        max_delta_share=("delta_share", "max")).reset_index()
    muni["recipient_exposed"] = True

    con.register("muni_df", muni)
    con.sql(f"COPY (SELECT * FROM muni_df) TO '{OUT}' (FORMAT PARQUET, COMPRESSION 'snappy')")
    subs_df.to_parquet(OUT.replace(".parquet", "_subs_audit.parquet"))
    pc_df.to_parquet(OUT.replace(".parquet", "_per_closure.parquet"))

    log(f"closures with >=1 substitute: {(pc_df.n_subs>0).sum()} / {len(pc_df)}", fh)
    log(f"unique recipient munis (any closure): {len(muni)}", fh)
    log(f"wrote {OUT}", fh)
    return len(muni)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--window", type=int, default=2)
    ap.add_argument("--top_k", type=int, default=3)
    ap.add_argument("--thresh", type=float, default=0.0)
    ap.add_argument("--force", action="store_true")
    a = ap.parse_args()
    os.makedirs(os.path.dirname(LOG), exist_ok=True)
    os.makedirs("/tmp/duckdb_spill", exist_ok=True)
    with open(LOG, "a") as fh:
        log(f"=== run window={a.window} top_k={a.top_k} thresh={a.thresh} force={a.force} ===", fh)
        if os.path.exists(OUT) and not a.force:
            log(f"cache hit {OUT}; skip (use --force)", fh)
            return
        t0 = time.time()
        n = build(a.window, a.top_k, a.thresh, fh)
        log(f"done in {time.time()-t0:.1f}s, {n} recipient munis", fh)


if __name__ == "__main__":
    main()
