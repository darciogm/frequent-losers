#!/usr/bin/env python3
# ============================================================================
# 22_consolidate_screens.py — Track A item C
#
# Purpose: assemble a unified multi-screen Table 1 for the Beneath the Surface
#   paper. Stitches together every cartel-detection screen already produced by
#   the Track A pipeline, plus computes the missing variance/CV screens on the
#   pair-matched (n=107) cartel-vs-cartel pregão subsample, into a single
#   long-format CSV with a stable schema.
#
# Schema (one row per screen × sample):
#   family       : variance | network | density | rdd
#   screen       : name (cv_bid, shared_workers, T_cjm, incumbent, etc.)
#   modality     : pregão | convite
#   sample       : full | cartel_active | cartel_listed | clean
#                  | pair_matched_active (both_cartel_active==1)
#                  | pair_matched_listed (both_cartel_firm==1)
#   n            : sample size used by the screen (auctions or pair rows)
#   stat_type    : t | auc | rd_jump | T_cjm | mean_diff
#   value        : the headline statistic
#   se           : standard error if available, else NaN
#   p_value      : NaN if not reported
#   note         : free-form provenance / caveat
#   source_file  : original artifact this row came from
#
# Inputs:
#   02_data/final/auction_screens_pregao.parquet
#   02_data/final/auction_screens_convite.parquet
#   02_data/final/df_pregao_with_cartel_flags.parquet
#   02_data/intermediate/density_test_results.csv
#   02_data/intermediate/table1_cartel_split.csv
#   02_data/intermediate/worker_flow_screen_results.txt   (parsed)
#   02_data/intermediate/rolling_robustness_results.txt   (parsed)
#
# Outputs:
#   02_data/intermediate/table1_multiscreen.csv
#   02_data/intermediate/table1_multiscreen_report.txt
# ============================================================================

import re
import sys
from datetime import datetime
from pathlib import Path

import duckdb
import numpy as np
import pandas as pd

BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds")
FINAL = BASE / "02_data/final"
INTER = BASE / "02_data/intermediate"

OUT_CSV = INTER / "table1_multiscreen.csv"
OUT_TXT = INTER / "table1_multiscreen_report.txt"

con = duckdb.connect()
con.sql("PRAGMA threads=12")
con.sql("PRAGMA memory_limit='14GB'")

log_lines: list[str] = []


def log(msg: str = "") -> None:
    print(msg)
    log_lines.append(msg)


def write_log() -> None:
    OUT_TXT.write_text("\n".join(log_lines) + "\n")


log("Multi-screen Table 1 consolidation — Track A item C")
log(f"Run at: {datetime.now():%Y-%m-%d %H:%M:%S}")
log("=" * 70)


# ─────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────
def auc_score(treat_vals: np.ndarray, control_vals: np.ndarray) -> float:
    """Mann-Whitney U / (n_t * n_c). Higher = treat scores systematically larger."""
    treat_vals = treat_vals[~np.isnan(treat_vals)]
    control_vals = control_vals[~np.isnan(control_vals)]
    n_t = len(treat_vals)
    n_c = len(control_vals)
    if n_t == 0 or n_c == 0:
        return float("nan")
    combined = np.concatenate([treat_vals, control_vals])
    ranks = pd.Series(combined).rank().to_numpy()
    rank_treat_sum = ranks[:n_t].sum()
    u = rank_treat_sum - n_t * (n_t + 1) / 2
    return u / (n_t * n_c)


def welch_t(treat_vals: np.ndarray, control_vals: np.ndarray) -> tuple[float, float, float]:
    """Welch's two-sample t. Returns (mean_diff, t_stat, p_value)."""
    from scipy import stats

    treat_vals = treat_vals[~np.isnan(treat_vals)]
    control_vals = control_vals[~np.isnan(control_vals)]
    if len(treat_vals) < 2 or len(control_vals) < 2:
        return float("nan"), float("nan"), float("nan")
    res = stats.ttest_ind(treat_vals, control_vals, equal_var=False)
    return float(treat_vals.mean() - control_vals.mean()), float(res.statistic), float(res.pvalue)


rows: list[dict] = []


def add(**kwargs) -> None:
    rows.append(kwargs)


# ─────────────────────────────────────────────────────────────────────
# 1. Variance / CV screens — RECOMPUTE on every cartel-flag subsample,
#    INCLUDING the pair-matched (n=107) which was never reported.
# ─────────────────────────────────────────────────────────────────────
log("\n[1] Variance/CV screens — recomputing on all subsamples")
log("-" * 70)


def variance_screens(modality: str) -> None:
    """Run cv_bid / spread / mv / n_firms two-sample tests on all subsamples
    of one modality. Pulls cartel flags from df_*_with_cartel_flags via the
    auction key (numerodaoc, códigoitem)."""

    aucs_path = FINAL / f"auction_screens_{modality}.parquet"
    flags_path = FINAL / f"df_{modality}_with_cartel_flags.parquet"

    # Auction-level cartel flags. The pair file is row-level (winner+runner).
    # Collapse to one row per auction with the strongest available flag.
    if modality == "pregao":
        flag_cols_select = (
            "auction_item, "
            "MAX(CAST(both_cartel_active AS INTEGER)) AS both_active, "
            "MAX(CAST(winner_is_cartel_active AS INTEGER)) AS winner_active, "
            "MAX(CAST(runnerup_is_cartel_active AS INTEGER)) AS runnerup_active, "
            "MAX(CAST(has_active_cartel AS INTEGER)) AS has_active, "
            "MAX(CAST(has_any_cartel_firm AS INTEGER)) AS has_any"
        )
        # both_cartel_firm exists only for convite in our schema check; for
        # pregão we synthesise it from winner_is_cartel_firm × runnerup_is_cartel_firm.
        flag_cols_select += (
            ", MAX(CAST(winner_is_cartel_firm AS INTEGER) "
            "    * CAST(runnerup_is_cartel_firm AS INTEGER)) AS both_listed"
        )
    else:  # convite
        flag_cols_select = (
            "auction_item, "
            "MAX(CAST(both_cartel_firm AS INTEGER)) AS both_listed, "
            "0 AS both_active, "  # convite file has no both_cartel_active column
            "MAX(CAST(winner_is_cartel_firm AS INTEGER)) AS winner_active, "
            "MAX(CAST(runnerup_is_cartel_firm AS INTEGER)) AS runnerup_active, "
            "MAX(CAST(has_active_cartel AS INTEGER)) AS has_active, "
            "MAX(CAST(has_any_cartel_firm AS INTEGER)) AS has_any"
        )

    flags = con.sql(
        f"""
        SELECT {flag_cols_select}
        FROM read_parquet('{flags_path}')
        GROUP BY auction_item
        """
    ).df()

    # auction_screens uses (numerodaoc, códigoitem); df_*_with_cartel uses
    # auction_item. We need to derive auction_item on the screens side OR
    # join via numerodaoc+códigoitem from the flags file. Use auction_item
    # composition: it is "<numerodaoc>_<códigoitem>".
    screens = con.sql(
        f"""
        SELECT
            numerodaoc || '_' || "códigoitem" AS auction_item,
            cv_bid, spread, mv, n_firms
        FROM read_parquet('{aucs_path}')
        """
    ).df()

    df = screens.merge(flags, on="auction_item", how="left")
    df[["both_active", "both_listed", "has_active", "has_any"]] = (
        df[["both_active", "both_listed", "has_active", "has_any"]].fillna(0).astype(int)
    )

    log(f"\n  [{modality}] auctions matched: {len(df):,}")

    samples = {
        "full": df,
        "cartel_active": df[df.has_active == 1],
        "cartel_listed": df[df.has_any == 1],
        "pair_matched_active": df[df.both_active == 1],
        "pair_matched_listed": df[df.both_listed == 1],
        "clean": df[df.has_any == 0],
    }
    for k, v in samples.items():
        log(f"    sample {k:25s}: n={len(v):>10,}")

    control = samples["clean"]
    for screen in ["cv_bid", "spread", "mv", "n_firms"]:
        for sample_name, sub in samples.items():
            if sample_name == "clean":
                continue
            if len(sub) == 0:
                continue
            t_vals = sub[screen].to_numpy(dtype=float)
            c_vals = control[screen].to_numpy(dtype=float)
            mdiff, t_stat, p = welch_t(t_vals, c_vals)
            auc = auc_score(t_vals, c_vals)
            add(
                family="variance",
                screen=screen,
                modality=modality,
                sample=sample_name,
                n=int(np.isfinite(t_vals).sum()),
                stat_type="mean_diff",
                value=mdiff,
                se=float("nan"),
                p_value=p,
                t_stat=t_stat,
                auc=auc,
                note=f"vs clean control n={int(np.isfinite(c_vals).sum())}",
                source_file="22_consolidate_screens.py",
            )
            log(
                f"    {screen:10s} × {sample_name:22s}"
                f" n={int(np.isfinite(t_vals).sum()):>8,}"
                f"  Δ={mdiff:+.4f}  t={t_stat:+7.3f}  p={p:.4g}  AUC={auc:.3f}"
            )


variance_screens("pregao")
variance_screens("convite")


# ─────────────────────────────────────────────────────────────────────
# 2. Density (CJM) tests — read existing CSV
# ─────────────────────────────────────────────────────────────────────
log("\n[2] Density (CJM) tests — reading density_test_results.csv")
log("-" * 70)

dens = pd.read_csv(INTER / "density_test_results.csv")
density_map = {
    "PREGÃO full": ("pregao", "full"),
    "CONVITE full": ("convite", "full"),
    "Pregão: auctions w/ ≥1 cartel-active firm": ("pregao", "cartel_active"),
    "Pregão: auctions w/ cartel firm × outside period": ("pregao", "cartel_listed_outside"),
    "Pregão: clean control (no cartel firm)": ("pregao", "clean"),
    "Pregão: PAIR-MATCHED both cartel-active": ("pregao", "pair_matched_active"),
    "Pregão: winner is cartel-active firm": ("pregao", "winner_active"),
    "Pregão: runner-up is cartel-active firm": ("pregao", "runnerup_active"),
    "Convite: auctions w/ cartel-active firm": ("convite", "cartel_active"),
    "Convite: auctions w/ cartel firm outside period": ("convite", "cartel_listed_outside"),
    "Convite: clean control (no cartel firm)": ("convite", "clean"),
}
for _, r in dens.iterrows():
    if r["label"] not in density_map:
        continue
    modality, sample = density_map[r["label"]]
    add(
        family="density",
        screen="T_cjm",
        modality=modality,
        sample=sample,
        n=int(r["n"]) if pd.notna(r["n"]) else 0,
        stat_type="T_cjm",
        value=float(r["t_stat"]) if pd.notna(r["t_stat"]) else float("nan"),
        se=float("nan"),
        p_value=float(r["p_value"]) if pd.notna(r["p_value"]) else float("nan"),
        t_stat=float(r["t_stat"]) if pd.notna(r["t_stat"]) else float("nan"),
        auc=float("nan"),
        note=f"CJM (2020); h_L={r['h_left']:.4f}",
        source_file="density_test_results.csv",
    )
log(f"  rows added: {sum(1 for x in rows if x['family']=='density')}")


# ─────────────────────────────────────────────────────────────────────
# 3. RDD jumps (incumbency, last-bid) — read table1_cartel_split.csv
#    These exist for convite only.
# ─────────────────────────────────────────────────────────────────────
log("\n[3] RDD jumps — reading table1_cartel_split.csv (convite only)")
log("-" * 70)

rd = pd.read_csv(INTER / "table1_cartel_split.csv")
rd_map = {
    "convite full × incumbent": ("incumbent", "full"),
    "convite full × last bid": ("last_bid", "full"),
    "convite cartel-active × incumbent": ("incumbent", "cartel_active"),
    "convite cartel-active × last bid": ("last_bid", "cartel_active"),
    "convite cartel-firm outside × incumbent": ("incumbent", "cartel_listed_outside"),
    "convite cartel-firm outside × last bid": ("last_bid", "cartel_listed_outside"),
    "convite clean control × incumbent": ("incumbent", "clean"),
    "convite clean control × last bid": ("last_bid", "clean"),
}
for _, r in rd.iterrows():
    if r["label"] not in rd_map:
        continue
    screen, sample = rd_map[r["label"]]
    add(
        family="rdd",
        screen=screen,
        modality="convite",
        sample=sample,
        n=int(r["n"]),
        stat_type="rd_jump",
        value=float(r["coef"]),
        se=float(r["se"]),
        p_value=float(r["p"]),
        t_stat=float(r["coef"]) / float(r["se"]) if r["se"] else float("nan"),
        auc=float("nan"),
        note=f"rdrobust h={r['h']:.4f}; cluster=item_class",
        source_file="table1_cartel_split.csv",
    )
log(f"  rows added: {sum(1 for x in rows if x['family']=='rdd')}")


# ─────────────────────────────────────────────────────────────────────
# 4. Network screens — parse worker_flow_screen_results.txt
# ─────────────────────────────────────────────────────────────────────
log("\n[4] Network screens — parsing worker_flow_screen_results.txt")
log("-" * 70)

wf_text = (INTER / "worker_flow_screen_results.txt").read_text()

# Extract pattern: "Screen: <name>"  ...  "AUC (cartel-active vs control...): <x>"
# and  "PAIR-MATCHED vs control: t=<t> p=<p> (n_paired=<n>)"
screen_blocks = re.split(r"\nScreen: ", wf_text)[1:]
for block in screen_blocks:
    name = block.split("\n", 1)[0].strip()
    n_paired = re.search(r"n_paired=(\d+)", block)
    n_paired = int(n_paired.group(1)) if n_paired else None

    # cartel-active vs control
    m = re.search(r"t-stat \(cartel-active vs control\):\s*([+\-\d\.]+)", block)
    t_active = float(m.group(1)) if m else float("nan")
    m = re.search(r"p-value:\s*([\d\.eE+\-]+)", block)
    p_active = float(m.group(1)) if m else float("nan")
    m = re.search(
        r"AUC \(cartel-active vs control[^\)]*\):\s*([\d\.]+)", block
    )
    auc_active = float(m.group(1)) if m else float("nan")

    add(
        family="network",
        screen=name,
        modality="pregao",
        sample="cartel_active",
        n=2351,  # from the file header
        stat_type="t",
        value=t_active,
        se=float("nan"),
        p_value=p_active,
        t_stat=t_active,
        auc=auc_active,
        note="vs clean control n=527,259; close-bid |MV|<0.10",
        source_file="worker_flow_screen_results.txt",
    )

    # pair-matched (active, n=10)
    m = re.search(r"PAIR-MATCHED vs control: t=([+\-\d\.]+)\s+p=([\d\.eE+\-]+)", block)
    if m:
        t_pm = float(m.group(1))
        p_pm = float(m.group(2))
    else:
        t_pm, p_pm = float("nan"), float("nan")
    m = re.search(r"AUC \(PAIR-MATCHED vs control[^\)]*\):\s*([\d\.]+)", block)
    auc_pm = float(m.group(1)) if m else float("nan")

    add(
        family="network",
        screen=name,
        modality="pregao",
        sample="pair_matched_active",
        n=n_paired or 10,
        stat_type="t",
        value=t_pm,
        se=float("nan"),
        p_value=p_pm,
        t_stat=t_pm,
        auc=auc_pm,
        note="strict head-to-head: both winner & runner cartel-active",
        source_file="worker_flow_screen_results.txt",
    )
    log(f"  network/{name}: cartel-active AUC={auc_active:.3f}; pair-matched (n={n_paired}) AUC={auc_pm:.3f}")


# ─────────────────────────────────────────────────────────────────────
# 5. Rolling-edge robustness — parse rolling_robustness_results.txt
#    This block is the look-ahead-bias-corrected version (M4 from referee
#    parecer). Numbers are AUCs only.
# ─────────────────────────────────────────────────────────────────────
log("\n[5] Rolling-edge screens — parsing rolling_robustness_results.txt")
log("-" * 70)

ro_text = (INTER / "rolling_robustness_results.txt").read_text()

# Pattern: lines like "  shared_workers         baseline AUC=0.7031  within-CNAE AUC=0.7005  N_t=150"
# but in the rolling section the format is:
#   "--- shared_workers (rolling) on shared_workers ---
#    baseline:          N_t=2,319 N_c=527,259  AUC=0.6721
#    within-CNAE:       N_t=2,294 N_c=427,381  AUC=0.6835
#    PAIR-MATCHED:      N_t=   10 N_c=527,259  AUC=0.3333"
rolling_blocks = re.findall(
    r"---\s*([\w_]+)\s*\(rolling\)\s*on\s*[\w_]+\s*---(.*?)(?=\n---|\n\n=)",
    ro_text,
    re.DOTALL,
)
# Track modality by detecting the section heading "[PREGÃO]" / "[CONVITE]"
# We'll re-scan the text in order to associate each block with a modality.
modality_segments = re.split(r"\n\[(PREGÃO|CONVITE)\]\n", ro_text)
# split returns: [pre, MOD1, body1, MOD2, body2, ...]
collected = []
for i in range(1, len(modality_segments) - 1, 2):
    mod = "pregao" if modality_segments[i] == "PREGÃO" else "convite"
    body = modality_segments[i + 1]
    blks = re.findall(
        r"---\s*([\w_]+)\s*\(rolling\)\s*on\s*[\w_]+\s*---(.*?)(?=\n---|\n=)",
        body,
        re.DOTALL,
    )
    for name, content in blks:
        baseline = re.search(r"baseline:\s+N_t=([\d,]+)\s+N_c=[\d,]+\s+AUC=([\d\.]+)", content)
        pm = re.search(r"PAIR-MATCHED:\s+N_t=\s*(\d+)\s+N_c=[\d,]+\s+AUC=([\d\.]+)", content)
        if baseline:
            collected.append(
                dict(
                    modality=mod,
                    name=name,
                    sample="cartel_active",
                    n=int(baseline.group(1).replace(",", "")),
                    auc=float(baseline.group(2)),
                )
            )
        if pm:
            collected.append(
                dict(
                    modality=mod,
                    name=name,
                    sample="pair_matched_active",
                    n=int(pm.group(1)),
                    auc=float(pm.group(2)),
                )
            )

for entry in collected:
    add(
        family="network_rolling",
        screen=entry["name"],
        modality=entry["modality"],
        sample=entry["sample"],
        n=entry["n"],
        stat_type="auc",
        value=entry["auc"],
        se=float("nan"),
        p_value=float("nan"),
        t_stat=float("nan"),
        auc=entry["auc"],
        note="rolling window [max(2009,t-3), t-1]; bias-corrected per /rev",
        source_file="rolling_robustness_results.txt",
    )
log(f"  rows added: {sum(1 for x in rows if x['family']=='network_rolling')}")


# ─────────────────────────────────────────────────────────────────────
# 6. Persist
# ─────────────────────────────────────────────────────────────────────
log("\n[6] Writing consolidated table")
log("-" * 70)

df = pd.DataFrame(rows)
# Stable column order
cols = [
    "family", "screen", "modality", "sample", "n",
    "stat_type", "value", "se", "t_stat", "p_value", "auc",
    "note", "source_file",
]
df = df[cols]
df.to_csv(OUT_CSV, index=False)
log(f"  rows: {len(df)}")
log(f"  written: {OUT_CSV}")


# ─────────────────────────────────────────────────────────────────────
# 7. Headline summary block (the bit that goes into the paper draft)
# ─────────────────────────────────────────────────────────────────────
log("\n" + "=" * 70)
log("HEADLINE — money numbers for the Introduction")
log("=" * 70)

def show(filt: pd.DataFrame, label: str) -> None:
    if filt.empty:
        log(f"  {label}: [no data]")
        return
    for _, r in filt.iterrows():
        n = r["n"]
        if r["stat_type"] == "rd_jump":
            log(
                f"  {label:50s} n={n:>8,}"
                f"  jump={r['value']:+.4f} (SE={r['se']:.4f}) p={r['p_value']:.3f}"
            )
        elif r["stat_type"] in ("t", "mean_diff"):
            log(
                f"  {label:50s} n={n:>8,}"
                f"  Δ={r['value']:+.4f}  AUC={r['auc']:.3f}  p={r['p_value']:.3g}"
            )
        elif r["stat_type"] == "auc":
            log(f"  {label:50s} n={n:>8,}  AUC={r['auc']:.3f}")
        elif r["stat_type"] == "T_cjm":
            log(f"  {label:50s} n={n:>8,}  T={r['value']:+.4f}  p={r['p_value']:.3f}")


log("\n## Pregão — pair-matched LISTED (n=107 firms cartel any-time)")
show(df[(df.modality == "pregao") & (df["sample"] == "pair_matched_listed")],
     "variance×pair_matched_listed")

log("\n## Pregão — pair-matched ACTIVE (n=10 within-period)")
show(df[(df.modality == "pregao") & (df["sample"] == "pair_matched_active")],
     "all×pair_matched_active")

log("\n## Pregão — cartel-active broad sample (≥1 cartel firm in period)")
show(df[(df.modality == "pregao") & (df["sample"] == "cartel_active")],
     "all×cartel_active")

log("\n## Convite — cartel-active (RDD)")
show(df[(df.modality == "convite") & (df["sample"] == "cartel_active")
        & (df.family == "rdd")], "rdd×convite_cartel_active")
show(df[(df.modality == "convite") & (df["sample"] == "clean")
        & (df.family == "rdd")], "rdd×convite_clean")


log("\nDone.")
write_log()
print(f"\n[written] {OUT_CSV}")
print(f"[written] {OUT_TXT}")
