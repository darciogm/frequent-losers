#!/usr/bin/env python3
"""
18_worker_flow_robustness.py — Robustness for the worker-flow screen

Three checks for the AUC=0.83 finding from script 17:

  (1) Within-CNAE restriction
      Restrict comparison to firm pairs in the same CNAE 2-digit sector.
      If sectoral confounding drives the result, AUC drops sharply.

  (2) Convite application
      Apply the same firm-firm worker-flow network to convite close-bid
      pairs. Convite has fewer cartel obs but is a clean falsification:
      if AUC is also high in convite, the screen is genuinely capturing
      coordination, not pregão-specific noise.

  (3) Co-bidding network as alternative
      Build an alternative network where edge = count of times firms i
      and j BID IN THE SAME AUCTION. This is the "more obvious" screen.
      Compare worker-flow AUC vs co-bidding AUC. If worker-flow beats
      co-bidding by a wide margin, the contribution is genuine novelty,
      not just an obfuscated co-bidding signal.

Outputs
-------
  02_data/firms/firm_firm_cobidding_edges.parquet
  02_data/firms/firm_cnae_lookup.parquet
  02_data/intermediate/worker_flow_robustness_results.txt
"""
from __future__ import annotations

import gc
import os
import socket
import time
from pathlib import Path

# Cap threads BEFORE importing polars (machine ceiling: 12 of 14 cores)
os.environ.setdefault("POLARS_MAX_THREADS", "12")
os.environ.setdefault("RAYON_NUM_THREADS", "12")
os.environ.setdefault("OMP_NUM_THREADS", "12")

import numpy as np
import polars as pl
import psutil

_PROC = psutil.Process(os.getpid())
_T0 = time.time()
_RAM_BUDGET_GIB = 14.0  # abort threshold


def log_mem(label: str) -> None:
    rss_gib = _PROC.memory_info().rss / (1024 ** 3)
    vm = psutil.virtual_memory()
    free_gib = vm.available / (1024 ** 3)
    elapsed = time.time() - _T0
    print(f"  [mem {elapsed:6.1f}s] {label:42s} "
          f"rss={rss_gib:5.2f} GiB  free={free_gib:5.2f} GiB",
          flush=True)
    if rss_gib > _RAM_BUDGET_GIB:
        raise MemoryError(
            f"RSS {rss_gib:.2f} GiB exceeds budget {_RAM_BUDGET_GIB:.1f} GiB — abort"
        )

PAPER3 = Path("/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers")
BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")

EDGES_WF      = BASE / "02_data" / "firms" / "firm_firm_worker_flow_edges.parquet"
FIRM_PANEL    = BASE / "02_data" / "firms" / "firm_year_panel.parquet"
SOURCE        = PAPER3 / "v3/data/processed/bid_level_with_prices.parquet"
PREGAO_PAIRS  = BASE / "02_data" / "final" / "df_pregao_with_cartel_flags.parquet"
CONVITE_PAIRS = BASE / "02_data" / "final" / "df_convite_with_cartel_flags.parquet"

EDGES_CB      = BASE / "02_data" / "firms" / "firm_firm_cobidding_edges.parquet"
CNAE_OUT      = BASE / "02_data" / "firms" / "firm_cnae_lookup.parquet"
REPORT_OUT    = BASE / "02_data" / "intermediate" / "worker_flow_robustness_results.txt"


def auc_mwu(treat: np.ndarray, control: np.ndarray) -> float:
    """Mann-Whitney AUC. Higher score = more cartel-like."""
    if len(treat) < 10 or len(control) < 10:
        return float("nan")
    all_scores = np.concatenate([treat, control])
    labels = np.concatenate([np.ones(len(treat)), np.zeros(len(control))])
    order = np.argsort(all_scores)
    ranks = np.empty_like(order, dtype=float)
    ranks[order] = np.arange(1, len(all_scores) + 1)
    rank_sum = ranks[labels == 1].sum()
    n_t, n_c = len(treat), len(control)
    return (rank_sum - n_t * (n_t + 1) / 2) / (n_t * n_c)


def welch_t(treat: np.ndarray, control: np.ndarray) -> tuple[float, float]:
    from math import sqrt, erf
    if len(treat) < 30 or len(control) < 30:
        return (float("nan"), float("nan"))
    mt, mc = treat.mean(), control.mean()
    vt, vc = treat.var(ddof=1), control.var(ddof=1)
    se = sqrt(vt/len(treat) + vc/len(control))
    if se == 0:
        return (float("nan"), float("nan"))
    t = (mt - mc) / se
    p = 2 * (1 - 0.5 * (1 + erf(abs(t) / sqrt(2))))
    return (t, p)


# ─────────────────────────────────────────────────────────────────────
# Build firm CNAE lookup (most recent + most frequent CNAE per firm)
# ─────────────────────────────────────────────────────────────────────
def build_cnae_lookup() -> pl.DataFrame:
    if CNAE_OUT.exists():
        print(f"[cached] firm CNAE lookup: {CNAE_OUT}")
        return pl.read_parquet(CNAE_OUT)

    print("Building firm CNAE lookup from firm_year_panel...")
    panel = pl.read_parquet(FIRM_PANEL)
    cnae = (
        panel.filter(pl.col("firm_cnae20").is_not_null())
        .with_columns([
            (pl.col("firm_cnae20") // 100000).cast(pl.Int32).alias("cnae2"),
        ])
        .group_by("cnpj_raiz")
        .agg([
            pl.col("cnae2").mode().first().alias("cnae2"),
        ])
    )
    print(f"  firms with CNAE: {cnae.height:,}")
    cnae.write_parquet(CNAE_OUT, compression="snappy")
    return cnae


# ─────────────────────────────────────────────────────────────────────
# Build co-bidding network from bid-level data
# ─────────────────────────────────────────────────────────────────────
def build_cobidding_edges() -> pl.DataFrame:
    if EDGES_CB.exists():
        print(f"[cached] co-bidding edges: {EDGES_CB}")
        return pl.read_parquet(EDGES_CB)

    print("\nBuilding firm-firm co-bidding edges from BEC...")
    # Use the bid-level file restricted to BEC pregão+convite (where the
    # interesting cartels concentrate) to avoid mixing dispensas
    print("  loading firm-auction unique pairs...", flush=True)
    fa = (
        pl.scan_parquet(SOURCE)
        .filter(pl.col("descriçãoprocedimentocompra")
                .is_in(["PREGÃO ELETRÔNICO", "CONVITE"]))
        .filter(pl.col("bid_price") > 0)
        .with_columns(
            pl.col("códigofornecedor").cast(pl.Utf8).str.zfill(14)
                .str.slice(0, 8).alias("cnpj_raiz")
        )
        .select(["numerodaoc", "códigoitem", "cnpj_raiz"])
        .unique()
        .collect()
    )
    print(f"  unique (auction, firm) rows: {fa.height:,}")
    print(f"  unique auctions: "
          f"{fa.select(['numerodaoc', 'códigoitem']).unique().height:,}")

    # Self-join on auction to get all (cnpj_a, cnpj_b) co-bidding pairs
    print("  performing self-join on auctions...", flush=True)
    edges = (
        fa.join(
            fa.rename({"cnpj_raiz": "cnpj_b"}),
            on=["numerodaoc", "códigoitem"],
            how="inner",
        )
        .filter(pl.col("cnpj_raiz") < pl.col("cnpj_b"))   # de-dup pairs
        .group_by(["cnpj_raiz", "cnpj_b"])
        .agg(pl.len().alias("n_cobids"))
        .rename({"cnpj_raiz": "cnpj_a"})
    )
    print(f"  unique co-bidding edges: {edges.height:,}")

    EDGES_CB.parent.mkdir(parents=True, exist_ok=True)
    edges.write_parquet(EDGES_CB, compression="snappy")
    print(f"  [written] {EDGES_CB} ({EDGES_CB.stat().st_size/1e6:.1f} MB)")
    return edges


# ─────────────────────────────────────────────────────────────────────
# Build pair-level analysis sample
# ─────────────────────────────────────────────────────────────────────
def build_pairs(pairs_path: Path, cnae: pl.DataFrame,
                edges_wf: pl.DataFrame, edges_cb: pl.DataFrame) -> pl.DataFrame:
    pairs = pl.read_parquet(pairs_path)
    print(f"  loaded {pairs.height:,} rows from {pairs_path.name}")
    pairs = pairs.filter(pl.col("MV").abs() < 0.10)
    print(f"  |MV|<0.10: {pairs.height:,}")

    # cnpj_raiz já existe nos dois arquivos (criado por 13_flag_cartel_auctions.py).
    # Só recomputa se faltar (defesa contra schema drift).
    if "cnpj_raiz" not in pairs.columns:
        pairs = pairs.with_columns(
            pl.col("códigofornecedor").cast(pl.Utf8).str.zfill(14)
                .str.slice(0, 8).alias("cnpj_raiz")
        )

    # Harmonize pair-matched column. Pregão has both_cartel_active (year-aware);
    # convite has only both_cartel_firm. Map to a single column "pair_matched".
    if "both_cartel_active" in pairs.columns:
        pairs = pairs.with_columns(
            pl.col("both_cartel_active").cast(pl.Int8).alias("pair_matched")
        )
    elif "both_cartel_firm" in pairs.columns:
        pairs = pairs.with_columns(
            pl.col("both_cartel_firm").cast(pl.Int8).alias("pair_matched")
        )
    else:
        pairs = pairs.with_columns(
            pl.lit(0, dtype=pl.Int8).alias("pair_matched")
        )

    winners = pairs.filter(pl.col("flagvencedor") == 1).select([
        "auction_item",
        pl.col("cnpj_raiz").alias("winner_cnpj"),
        "year", "MV",
        pl.col("has_active_cartel"),
        pl.col("has_any_cartel_firm"),
        pl.col("pair_matched"),
    ])
    losers = pairs.filter(pl.col("flagvencedor") == 0).select([
        "auction_item",
        pl.col("cnpj_raiz").alias("loser_cnpj"),
    ])
    auctions = winners.join(losers, on="auction_item", how="inner")
    print(f"  auction-level pairs: {auctions.height:,}")

    auctions = auctions.with_columns([
        pl.when(pl.col("winner_cnpj") < pl.col("loser_cnpj"))
            .then(pl.col("winner_cnpj"))
            .otherwise(pl.col("loser_cnpj"))
            .alias("cnpj_a"),
        pl.when(pl.col("winner_cnpj") < pl.col("loser_cnpj"))
            .then(pl.col("loser_cnpj"))
            .otherwise(pl.col("winner_cnpj"))
            .alias("cnpj_b"),
    ])

    # Attach worker-flow edge
    auctions = auctions.join(
        edges_wf.select(["cnpj_a", "cnpj_b", "shared_workers", "jaccard"]),
        on=["cnpj_a", "cnpj_b"], how="left"
    ).with_columns([
        pl.col("shared_workers").fill_null(0),
        pl.col("jaccard").fill_null(0.0),
    ])

    # Attach co-bidding edge
    auctions = auctions.join(
        edges_cb.select(["cnpj_a", "cnpj_b", "n_cobids"]),
        on=["cnpj_a", "cnpj_b"], how="left"
    ).with_columns(pl.col("n_cobids").fill_null(0))

    # Attach CNAE for each firm
    auctions = (
        auctions
        .join(cnae.rename({"cnpj_raiz": "winner_cnpj", "cnae2": "cnae_w"}),
              on="winner_cnpj", how="left")
        .join(cnae.rename({"cnpj_raiz": "loser_cnpj", "cnae2": "cnae_l"}),
              on="loser_cnpj", how="left")
        .with_columns(
            (pl.col("cnae_w") == pl.col("cnae_l")).cast(pl.Int8).alias("same_cnae")
        )
    )

    return auctions


# ─────────────────────────────────────────────────────────────────────
# Evaluation functions
# ─────────────────────────────────────────────────────────────────────
def report_subsample(label, treat_arr, control_arr, f) -> None:
    if len(treat_arr) < 10 or len(control_arr) < 10:
        f.write(f"  {label:50s} [skip — n_t={len(treat_arr)}, "
                f"n_c={len(control_arr)}]\n")
        return
    auc = auc_mwu(treat_arr, control_arr)
    t, p = welch_t(treat_arr, control_arr)
    f.write(f"  {label:50s} N_t={len(treat_arr):>6,} "
            f"N_c={len(control_arr):>7,} "
            f"μ_t={treat_arr.mean():.3f} μ_c={control_arr.mean():.3f} "
            f"t={t:+.2f} AUC={auc:.4f}\n")


def report_distribution(label, treat, control, f) -> None:
    """Skew diagnostic — print percentiles by group. Detects when t-stat
    and AUC disagree (t inflated by tail outliers, AUC at chance)."""
    if len(treat) < 5 or len(control) < 5:
        return
    f.write(f"    skew diag — {label}:\n")
    for q in [50, 75, 90, 95, 99]:
        ct = float(np.quantile(control, q/100))
        tt = float(np.quantile(treat, q/100))
        f.write(f"      p{q:>2}: control={ct:>10.3f}  treat={tt:>10.3f}\n")
    f.write(f"      max: control={float(control.max()):>10.3f}  "
            f"treat={float(treat.max()):>10.3f}\n")


def evaluate_pair_matched(label, auctions, score_col, f,
                          n_bootstrap: int = 1000) -> None:
    """PAIR-MATCHED test: treatment = both winner AND runner-up are
    cartel-active. This is the gold-standard test (designated rotation).
    Bootstrap CI on AUC because n_treat is small."""
    f.write(f"\n--- {label} on {score_col} [PAIR-MATCHED] ---\n")
    treat = (auctions.filter(pl.col("pair_matched") == 1)[score_col]
             .drop_nulls().to_numpy())
    control = (auctions.filter(pl.col("has_any_cartel_firm") == 0)[score_col]
               .drop_nulls().to_numpy())

    if len(treat) < 3:
        f.write(f"  [skip — n_pair_matched={len(treat)} too small]\n")
        return

    f.write(f"  N_pair_matched={len(treat):,}  N_control={len(control):,}\n")
    if len(treat) >= 2:
        f.write(f"  μ_treat={float(treat.mean()):.4f}  "
                f"μ_control={float(control.mean()):.4f}\n")
        f.write(f"  median_treat={float(np.median(treat)):.4f}  "
                f"median_control={float(np.median(control)):.4f}\n")

    if len(treat) >= 5 and len(control) >= 100:
        auc = auc_mwu(treat, control)
        f.write(f"  point AUC: {auc:.4f}\n")

        # Bootstrap CI
        rng = np.random.default_rng(42)
        # Subsample control for speed (control is huge, AUC stable on 5k)
        if len(control) > 5000:
            control_sub = rng.choice(control, size=5000, replace=False)
        else:
            control_sub = control
        boot = np.empty(n_bootstrap)
        for b in range(n_bootstrap):
            t_b = rng.choice(treat, size=len(treat), replace=True)
            c_b = rng.choice(control_sub, size=len(control_sub), replace=True)
            boot[b] = auc_mwu(t_b, c_b)
        lo, hi = np.quantile(boot, [0.025, 0.975])
        f.write(f"  bootstrap 95% CI [B={n_bootstrap}, "
                f"control sub={len(control_sub):,}]: "
                f"[{lo:.4f}, {hi:.4f}]\n")

        # Within-CNAE pair-matched (when n permits)
        same = auctions.filter(pl.col("same_cnae") == 1)
        treat_s = (same.filter(pl.col("pair_matched") == 1)[score_col]
                   .drop_nulls().to_numpy())
        control_s = (same.filter(pl.col("has_any_cartel_firm") == 0)[score_col]
                     .drop_nulls().to_numpy())
        if len(treat_s) >= 5 and len(control_s) >= 100:
            auc_s = auc_mwu(treat_s, control_s)
            f.write(f"  within same CNAE-2dig: AUC={auc_s:.4f} "
                    f"(N_t={len(treat_s):,} N_c={len(control_s):,})\n")
        else:
            f.write(f"  within same CNAE-2dig: [skip — n_t={len(treat_s)}]\n")


def fit_residual(pairs: pl.DataFrame, score_col: str = "shared_workers"):
    """Fit log-log regression of shared_workers ~ n_cobids on the control
    pairs (no cartel firm) and return the residualized score for the full
    sample. Returns (intercept, slope, residual_array)."""
    ctrl = pairs.filter(pl.col("has_any_cartel_firm") == 0)
    x = np.log1p(ctrl["n_cobids"].to_numpy())
    y = np.log1p(ctrl[score_col].to_numpy())
    slope, intercept = np.polyfit(x, y, 1)
    x_all = np.log1p(pairs["n_cobids"].to_numpy())
    y_all = np.log1p(pairs[score_col].to_numpy())
    resid = y_all - (intercept + slope * x_all)
    return intercept, slope, resid


def evaluate_screen(label, auctions, score_col, f, with_skew: bool = False) -> None:
    f.write(f"\n--- {label} on {score_col} ---\n")
    treat = (auctions.filter(pl.col("has_active_cartel") == 1)[score_col]
             .drop_nulls().to_numpy())
    control = (auctions.filter(pl.col("has_any_cartel_firm") == 0)[score_col]
               .drop_nulls().to_numpy())
    report_subsample(f"baseline (any cartel-active)",
                     treat, control, f)
    if with_skew:
        report_distribution("baseline", treat, control, f)

    # Within same CNAE
    same = auctions.filter(pl.col("same_cnae") == 1)
    treat_s = (same.filter(pl.col("has_active_cartel") == 1)[score_col]
               .drop_nulls().to_numpy())
    control_s = (same.filter(pl.col("has_any_cartel_firm") == 0)[score_col]
                 .drop_nulls().to_numpy())
    report_subsample(f"WITHIN same CNAE-2dig", treat_s, control_s, f)
    if with_skew:
        report_distribution("within same CNAE", treat_s, control_s, f)

    # Different CNAE (placebo)
    diff = auctions.filter(pl.col("same_cnae") == 0)
    treat_d = (diff.filter(pl.col("has_active_cartel") == 1)[score_col]
               .drop_nulls().to_numpy())
    control_d = (diff.filter(pl.col("has_any_cartel_firm") == 0)[score_col]
                 .drop_nulls().to_numpy())
    report_subsample(f"DIFFERENT CNAE-2dig (placebo)",
                     treat_d, control_d, f)


def main() -> None:
    print("=" * 70)
    print("Worker-flow screen robustness checks — Track A.5")
    print(f"Run at: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Host: {socket.gethostname()}  PID: {os.getpid()}")
    vm = psutil.virtual_memory()
    print(f"Cores: {os.cpu_count()}  POLARS_MAX_THREADS={os.environ.get('POLARS_MAX_THREADS')}")
    print(f"RAM total: {vm.total/1024**3:.1f} GiB  free: {vm.available/1024**3:.1f} GiB")
    print(f"RAM budget for this job: {_RAM_BUDGET_GIB:.1f} GiB (will abort above)")
    print("=" * 70)
    log_mem("startup")

    # Load existing assets
    print("\n[load] worker-flow edges...")
    edges_wf = pl.read_parquet(EDGES_WF)
    print(f"  {edges_wf.height:,} edges")
    log_mem("after edges_wf")

    cnae = build_cnae_lookup()
    log_mem("after cnae lookup")

    edges_cb = build_cobidding_edges()
    log_mem("after co-bidding edges")
    gc.collect()

    # Build pair-level samples
    print("\n[load] pregão pairs...")
    pregao = build_pairs(PREGAO_PAIRS, cnae, edges_wf, edges_cb)
    log_mem("after pregão pairs")
    gc.collect()

    print("\n[load] convite pairs...")
    convite = build_pairs(CONVITE_PAIRS, cnae, edges_wf, edges_cb)
    log_mem("after convite pairs")
    gc.collect()

    # Coverage stats
    print("\n[stats] CNAE coverage:")
    print(f"  pregão: {pregao.filter(pl.col('cnae_w').is_not_null() & pl.col('cnae_l').is_not_null()).height:,} / {pregao.height:,} pairs with both CNAE")
    print(f"  same-CNAE share (pregão): "
          f"{pregao.filter(pl.col('same_cnae') == 1).height / pregao.height:.1%}")

    REPORT_OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(REPORT_OUT, "w") as f:
        f.write(f"Worker-flow robustness report — {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")
        f.write(f"Pregão pairs (|MV|<0.10): {pregao.height:,}\n")
        f.write(f"Convite pairs (|MV|<0.10): {convite.height:,}\n")
        f.write(f"Pregão same-CNAE share: "
                f"{pregao.filter(pl.col('same_cnae') == 1).height / pregao.height:.1%}\n")
        f.write(f"Convite same-CNAE share: "
                f"{convite.filter(pl.col('same_cnae') == 1).height / convite.height:.1%}\n")

        # ──────────────────────────────────────────────────
        # Robustness 1: Within-CNAE for worker-flow
        # ──────────────────────────────────────────────────
        f.write("\n" + "=" * 70 + "\n")
        f.write("ROBUSTNESS 1 — WORKER-FLOW within / across CNAE\n")
        f.write("=" * 70 + "\n")
        f.write("\n[PREGÃO]\n")
        evaluate_screen("worker-flow [shared_workers]", pregao,
                        "shared_workers", f)
        evaluate_screen("worker-flow [jaccard]", pregao,
                        "jaccard", f)
        f.write("\n[CONVITE]\n")
        evaluate_screen("worker-flow [shared_workers]", convite,
                        "shared_workers", f)
        evaluate_screen("worker-flow [jaccard]", convite,
                        "jaccard", f)

        # ──────────────────────────────────────────────────
        # Robustness 2: Co-bidding network as alternative
        # ──────────────────────────────────────────────────
        f.write("\n" + "=" * 70 + "\n")
        f.write("ROBUSTNESS 2 — CO-BIDDING network (alternative screen)\n")
        f.write("=" * 70 + "\n")
        f.write("\n[PREGÃO]\n")
        evaluate_screen("co-bidding [n_cobids]", pregao, "n_cobids", f)
        f.write("\n[CONVITE]\n")
        evaluate_screen("co-bidding [n_cobids]", convite, "n_cobids", f)

        # ──────────────────────────────────────────────────
        # Robustness 3: Worker-flow CONTROLLING for co-bidding
        # (residualize one against the other) — pregão AND convite
        # ──────────────────────────────────────────────────
        f.write("\n" + "=" * 70 + "\n")
        f.write("ROBUSTNESS 3 — Worker-flow excess over co-bidding norm\n")
        f.write("=" * 70 + "\n")
        f.write("\nFor each pair, compute residual:\n")
        f.write("  resid = log(1+shared_workers) - log(1+expected_workers_given_cobids)\n")
        f.write("where expected is from a global regression of\n")
        f.write("  log(1+shared_workers) ~ log(1+n_cobids)\n")
        f.write("fit on control sample only (no cartel firm) to avoid leakage.\n")

        f.write("\n[PREGÃO]\n")
        intc_p, slp_p, resid_p = fit_residual(pregao, "shared_workers")
        f.write(f"  Fit log-log: intercept={intc_p:.4f}, slope={slp_p:.4f}\n")
        pregao_with_resid = pregao.with_columns(pl.Series("wf_resid", resid_p))
        evaluate_screen("worker-flow RESIDUAL (over co-bidding)",
                        pregao_with_resid, "wf_resid", f)

        f.write("\n[CONVITE]\n")
        intc_c, slp_c, resid_c = fit_residual(convite, "shared_workers")
        f.write(f"  Fit log-log: intercept={intc_c:.4f}, slope={slp_c:.4f}\n")
        convite_with_resid = convite.with_columns(pl.Series("wf_resid", resid_c))
        evaluate_screen("worker-flow RESIDUAL (over co-bidding)",
                        convite_with_resid, "wf_resid", f)

        # ──────────────────────────────────────────────────
        # Robustness 4: PAIR-MATCHED test (gold standard)
        # Treatment = both winner AND runner-up are cartel firms
        # ──────────────────────────────────────────────────
        f.write("\n" + "=" * 70 + "\n")
        f.write("ROBUSTNESS 4 — PAIR-MATCHED gold standard\n")
        f.write("Treatment = BOTH winner and runner-up are cartel firms\n")
        f.write("(pregão uses both_cartel_active; convite uses both_cartel_firm)\n")
        f.write("=" * 70 + "\n")

        n_pm_pregao = pregao.filter(pl.col("pair_matched") == 1).height
        n_pm_convite = convite.filter(pl.col("pair_matched") == 1).height
        f.write(f"\nN pair-matched in close-bid window |MV|<0.10:\n")
        f.write(f"  pregão:  {n_pm_pregao}\n")
        f.write(f"  convite: {n_pm_convite}\n")

        f.write("\n[PREGÃO]\n")
        evaluate_pair_matched("worker-flow [shared_workers]", pregao,
                              "shared_workers", f)
        evaluate_pair_matched("worker-flow [jaccard]", pregao, "jaccard", f)
        evaluate_pair_matched("worker-flow RESIDUAL", pregao_with_resid,
                              "wf_resid", f)
        evaluate_pair_matched("co-bidding [n_cobids]", pregao, "n_cobids", f)

        f.write("\n[CONVITE]\n")
        evaluate_pair_matched("worker-flow [shared_workers]", convite,
                              "shared_workers", f)
        evaluate_pair_matched("worker-flow [jaccard]", convite, "jaccard", f)
        evaluate_pair_matched("worker-flow RESIDUAL", convite_with_resid,
                              "wf_resid", f)
        evaluate_pair_matched("co-bidding [n_cobids]", convite, "n_cobids", f)

        # ──────────────────────────────────────────────────
        # Robustness 5: Skew diagnostic for the disputed convite case
        # ──────────────────────────────────────────────────
        f.write("\n" + "=" * 70 + "\n")
        f.write("ROBUSTNESS 5 — SKEW DIAGNOSTIC (convite shared_workers)\n")
        f.write("Check why within-CNAE AUC=0.50 with t=+9.36 in convite.\n")
        f.write("If treat distribution has fat right tail and same median\n")
        f.write("as control, AUC=0.50 is correct and t-stat is misleading.\n")
        f.write("=" * 70 + "\n")
        evaluate_screen("worker-flow [shared_workers]", convite,
                        "shared_workers", f, with_skew=True)
        evaluate_screen("worker-flow [jaccard]", convite,
                        "jaccard", f, with_skew=True)

    # Print to stdout
    print("\n[written]", REPORT_OUT)
    with open(REPORT_OUT) as f:
        print(f.read())

    log_mem("end")
    print(f"\nTotal time: {time.time() - _T0:.1f}s")


if __name__ == "__main__":
    main()
