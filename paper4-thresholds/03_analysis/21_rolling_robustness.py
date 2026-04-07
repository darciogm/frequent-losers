#!/usr/bin/env python3
"""
21_rolling_robustness.py — Worker-flow robustness with rolling edges (M4)

Purpose
-------
Re-run the key robustness tests from 18_worker_flow_robustness.py using
the rolling-window edges from 20_build_rolling_edges.py instead of the
2009-2017 snapshot.

For each close-bid auction at year t, the edge weight between the
winner and runner-up firms is drawn from edges_y{t}.parquet (i.e.,
using only RAIS mobility in [max(2009, t-3), t-1]).

This eliminates look-ahead bias. Compared to script 18:
  - Baseline AUC: expected to attenuate slightly (less signal)
  - If rolling AUC is still ≥ 0.70 residualized, paper survives M4.

Engine: DuckDB. Tests: within-CNAE, co-bidding alternative, residual,
pair-matched.
"""
from __future__ import annotations

import os
import socket
import time
from pathlib import Path

import duckdb
import numpy as np
import polars as pl
import psutil

BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")
ROLL_DIR = BASE / "02_data" / "firms" / "rolling_edges"
EDGES_CB = BASE / "02_data" / "firms" / "firm_firm_cobidding_edges.parquet"
CNAE_LOOKUP = BASE / "02_data" / "firms" / "firm_cnae_lookup.parquet"
PREGAO  = BASE / "02_data" / "final" / "df_pregao_with_cartel_flags.parquet"
CONVITE = BASE / "02_data" / "final" / "df_convite_with_cartel_flags.parquet"
REPORT_OUT = BASE / "02_data" / "intermediate" / "rolling_robustness_results.txt"

_T0 = time.time()


def log_mem(label: str) -> None:
    rss = psutil.Process(os.getpid()).memory_info().rss / 1024**3
    free = psutil.virtual_memory().available / 1024**3
    print(f"  [mem {time.time()-_T0:6.1f}s] {label:45s} rss={rss:5.2f} GiB free={free:5.2f} GiB",
          flush=True)


def auc_mwu(treat: np.ndarray, control: np.ndarray) -> float:
    if len(treat) < 5 or len(control) < 5:
        return float("nan")
    all_s = np.concatenate([treat, control])
    labels = np.concatenate([np.ones(len(treat)), np.zeros(len(control))])
    order = np.argsort(all_s)
    ranks = np.empty_like(order, dtype=float)
    ranks[order] = np.arange(1, len(all_s) + 1)
    rank_sum = ranks[labels == 1].sum()
    return (rank_sum - len(treat) * (len(treat) + 1) / 2) / (len(treat) * len(control))


def build_augmented_pairs(con, pairs_path: Path, label: str):
    """Join pair file to year-specific rolling edges, co-bidding, and CNAE.
    Return a polars DataFrame ready for AUC tests."""
    print(f"\n[augment] {label} from {pairs_path.name}...")

    # Rolling edges: all years concatenated with auction_year as key
    df = con.sql(f"""
        WITH
          p AS (
            SELECT
              auction_item,
              CAST(year AS INTEGER) AS year,
              CAST(flagvencedor AS TINYINT) AS flagvencedor,
              CAST(MV AS DOUBLE) AS MV,
              cnpj_raiz,
              CAST(has_any_cartel_firm AS TINYINT) AS has_any_cartel_firm,
              CAST(has_active_cartel AS TINYINT) AS has_active_cartel,
              CAST(COALESCE({'both_cartel_active' if 'pregao' in label else 'both_cartel_firm'}, 0) AS TINYINT)
                AS pair_matched
            FROM read_parquet('{pairs_path}')
            WHERE ABS(MV) < 0.10
          ),
          winners AS (
            SELECT auction_item, cnpj_raiz AS winner_cnpj, year, MV,
                   has_any_cartel_firm, has_active_cartel, pair_matched
            FROM p WHERE flagvencedor = 1
          ),
          losers AS (
            SELECT auction_item, cnpj_raiz AS loser_cnpj
            FROM p WHERE flagvencedor = 0
          ),
          auctions AS (
            SELECT w.*, l.loser_cnpj,
                   CASE WHEN w.winner_cnpj < l.loser_cnpj THEN w.winner_cnpj
                        ELSE l.loser_cnpj END AS cnpj_a,
                   CASE WHEN w.winner_cnpj < l.loser_cnpj THEN l.loser_cnpj
                        ELSE w.winner_cnpj END AS cnpj_b
            FROM winners w JOIN losers l USING (auction_item)
          ),
          roll AS (
            SELECT cnpj_a, cnpj_b, shared_workers, jaccard, auction_year
            FROM read_parquet('{ROLL_DIR}/edges_y*.parquet')
          ),
          with_roll AS (
            SELECT a.*,
                   COALESCE(r.shared_workers, 0) AS shared_workers,
                   COALESCE(r.jaccard, 0.0) AS jaccard
            FROM auctions a
            LEFT JOIN roll r
              ON a.cnpj_a = r.cnpj_a AND a.cnpj_b = r.cnpj_b
             AND a.year = r.auction_year
          ),
          with_cb AS (
            SELECT w.*,
                   COALESCE(cb.n_cobids, 0) AS n_cobids
            FROM with_roll w
            LEFT JOIN read_parquet('{EDGES_CB}') cb
              ON w.cnpj_a = cb.cnpj_a AND w.cnpj_b = cb.cnpj_b
          ),
          with_cnae AS (
            SELECT w.*,
                   cnw.cnae2 AS cnae_w,
                   cnl.cnae2 AS cnae_l,
                   CASE WHEN cnw.cnae2 = cnl.cnae2 THEN 1 ELSE 0 END AS same_cnae
            FROM with_cb w
            LEFT JOIN read_parquet('{CNAE_LOOKUP}') cnw ON w.winner_cnpj = cnw.cnpj_raiz
            LEFT JOIN read_parquet('{CNAE_LOOKUP}') cnl ON w.loser_cnpj = cnl.cnpj_raiz
          )
        SELECT * FROM with_cnae
    """).pl()
    print(f"  rows: {df.height:,}  "
          f"cartel-active: {df.filter(df['has_active_cartel']==1).height:,}  "
          f"pair-matched: {df.filter(df['pair_matched']==1).height:,}")
    log_mem(f"{label} augmented")
    return df


def fit_residual(df, score_col="shared_workers"):
    ctrl = df.filter(df["has_any_cartel_firm"] == 0)
    x = np.log1p(ctrl["n_cobids"].to_numpy())
    y = np.log1p(ctrl[score_col].to_numpy())
    slope, intercept = np.polyfit(x, y, 1)
    x_all = np.log1p(df["n_cobids"].to_numpy())
    y_all = np.log1p(df[score_col].to_numpy())
    return intercept, slope, y_all - (intercept + slope * x_all)


def eval_block(label, df, score_col, f, write_prefix=""):
    """Compute AUC for baseline, within-CNAE, pair-matched. Write to f."""
    def arr(filter_expr, col):
        if filter_expr is None:
            return df[col].drop_nulls().to_numpy()
        return df.filter(filter_expr)[col].drop_nulls().to_numpy()

    # Groups
    treat = arr(df["has_active_cartel"] == 1, score_col)
    control = arr(df["has_any_cartel_firm"] == 0, score_col)

    treat_s = arr((df["has_active_cartel"] == 1) & (df["same_cnae"] == 1), score_col)
    control_s = arr((df["has_any_cartel_firm"] == 0) & (df["same_cnae"] == 1), score_col)

    pair = arr(df["pair_matched"] == 1, score_col)

    f.write(f"\n{write_prefix}--- {label} on {score_col} ---\n")
    f.write(f"  baseline:          N_t={len(treat):>5,} N_c={len(control):>7,}  "
            f"AUC={auc_mwu(treat, control):.4f}\n")
    f.write(f"  within-CNAE:       N_t={len(treat_s):>5,} N_c={len(control_s):>7,}  "
            f"AUC={auc_mwu(treat_s, control_s):.4f}\n")
    if len(pair) >= 3:
        f.write(f"  PAIR-MATCHED:      N_t={len(pair):>5,} N_c={len(control):>7,}  "
                f"AUC={auc_mwu(pair, control):.4f}\n")


def main():
    print("=" * 70)
    print("Rolling-window worker-flow robustness — Track A / M4")
    print(f"Run at: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Host: {socket.gethostname()}  PID: {os.getpid()}")
    print("=" * 70)
    log_mem("startup")

    con = duckdb.connect()
    con.sql("PRAGMA threads=12")
    con.sql("PRAGMA memory_limit='14GB'")

    pregao  = build_augmented_pairs(con, PREGAO,  "pregao")
    convite = build_augmented_pairs(con, CONVITE, "convite")

    REPORT_OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(REPORT_OUT, "w") as f:
        f.write(f"Rolling-window robustness — {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n")
        f.write("Edges = year-specific rolling window [max(2009,t-3), t-1]\n")
        f.write("Eliminates look-ahead bias (M4 from /rev parecer).\n")
        f.write(f"Pregão close-bid N: {pregao.height:,}\n")
        f.write(f"Convite close-bid N: {convite.height:,}\n\n")

        # ========== ROBUSTNESS 1: within-CNAE ==========
        f.write("=" * 70 + "\n")
        f.write("R1 — worker-flow with rolling edges\n")
        f.write("=" * 70 + "\n")
        f.write("\n[PREGÃO]\n")
        eval_block("shared_workers (rolling)", pregao, "shared_workers", f)
        eval_block("jaccard (rolling)", pregao, "jaccard", f)
        f.write("\n[CONVITE]\n")
        eval_block("shared_workers (rolling)", convite, "shared_workers", f)
        eval_block("jaccard (rolling)", convite, "jaccard", f)

        # ========== ROBUSTNESS 2: co-bidding (unchanged, for reference) ==========
        f.write("\n" + "=" * 70 + "\n")
        f.write("R2 — co-bidding network (same as script 18, for reference)\n")
        f.write("=" * 70 + "\n")
        f.write("\n[PREGÃO]\n")
        eval_block("n_cobids", pregao, "n_cobids", f)
        f.write("\n[CONVITE]\n")
        eval_block("n_cobids", convite, "n_cobids", f)

        # ========== ROBUSTNESS 3: residual ==========
        f.write("\n" + "=" * 70 + "\n")
        f.write("R3 — rolling worker-flow RESIDUAL over co-bidding\n")
        f.write("=" * 70 + "\n")

        f.write("\n[PREGÃO]\n")
        i_p, s_p, r_p = fit_residual(pregao)
        pregao = pregao.with_columns(pl.Series("wf_resid", r_p))
        f.write(f"  fit intercept={i_p:.4f} slope={s_p:.4f}\n")
        eval_block("RESIDUAL (rolling)", pregao, "wf_resid", f)

        f.write("\n[CONVITE]\n")
        i_c, s_c, r_c = fit_residual(convite)
        convite = convite.with_columns(pl.Series("wf_resid", r_c))
        f.write(f"  fit intercept={i_c:.4f} slope={s_c:.4f}\n")
        eval_block("RESIDUAL (rolling)", convite, "wf_resid", f)

        # ========== Restricted to adequate backward window ==========
        f.write("\n" + "=" * 70 + "\n")
        f.write("R4 — RESTRICTED to year >= 2012 (backward window >= 3y)\n")
        f.write("Years 2010-2011 have truncated history (1-2y window) and\n")
        f.write("contaminate the aggregate. The 'true' result should use\n")
        f.write("years where the rolling window has full depth.\n")
        f.write("=" * 70 + "\n")

        for lbl, df in [("PREGÃO", pregao), ("CONVITE", convite)]:
            sub = df.filter(df["year"] >= 2012)
            f.write(f"\n[{lbl}] N={sub.height:,}  "
                    f"cartel-active={sub.filter(sub['has_active_cartel']==1).height:,}\n")

            # Refit residual on this restricted subsample
            ctrl_sub = sub.filter(sub["has_any_cartel_firm"] == 0)
            if ctrl_sub.height > 1000:
                x = np.log1p(ctrl_sub["n_cobids"].to_numpy())
                y = np.log1p(ctrl_sub["shared_workers"].to_numpy())
                slope2, intc2 = np.polyfit(x, y, 1)
                x_a = np.log1p(sub["n_cobids"].to_numpy())
                y_a = np.log1p(sub["shared_workers"].to_numpy())
                r_sub = y_a - (intc2 + slope2 * x_a)
                sub = sub.with_columns(pl.Series("wf_resid_12p", r_sub))
                f.write(f"  refit residual: intercept={intc2:.4f} slope={slope2:.4f}\n")

            for col in ["shared_workers", "jaccard", "n_cobids", "wf_resid_12p"]:
                if col not in sub.columns:
                    continue
                t = sub.filter(sub["has_active_cartel"] == 1)[col].drop_nulls().to_numpy()
                c = sub.filter(sub["has_any_cartel_firm"] == 0)[col].drop_nulls().to_numpy()
                t_s = sub.filter((sub["has_active_cartel"] == 1) & (sub["same_cnae"] == 1))[col].drop_nulls().to_numpy()
                c_s = sub.filter((sub["has_any_cartel_firm"] == 0) & (sub["same_cnae"] == 1))[col].drop_nulls().to_numpy()
                f.write(f"  {col:22s} baseline AUC={auc_mwu(t,c):.4f}  "
                        f"within-CNAE AUC={auc_mwu(t_s, c_s):.4f}  N_t={len(t)}\n")

        # ========== Year-by-year breakdown ==========
        f.write("\n" + "=" * 70 + "\n")
        f.write("R5 — per-year AUC breakdown (residual, pregão)\n")
        f.write("=" * 70 + "\n")
        for yr in range(2010, 2018):
            sub = pregao.filter(pregao["year"] == yr)
            if sub.height < 500:
                f.write(f"  year {yr}: N={sub.height} [too small]\n")
                continue
            treat = sub.filter(sub["has_active_cartel"] == 1)["wf_resid"].drop_nulls().to_numpy()
            ctrl  = sub.filter(sub["has_any_cartel_firm"] == 0)["wf_resid"].drop_nulls().to_numpy()
            auc = auc_mwu(treat, ctrl) if len(treat) >= 5 else float("nan")
            f.write(f"  year {yr}: N={sub.height:,}  N_treat={len(treat):,}  "
                    f"AUC residual={auc:.4f}\n")

    log_mem("end")
    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)
    with open(REPORT_OUT) as f:
        print(f.read())
    print(f"Total time: {time.time()-_T0:.1f}s")


if __name__ == "__main__":
    main()
