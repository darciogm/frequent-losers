"""
00_build_bidlevel.py — Extract firm-tender participation from LANCES data.

Paper 3: Frequent Losers in Public Procurement

Reads the complete LANCES_Final_Semester.dta (all 22 LANCES files appended,
~40M bid-level rows, Jan/2009–Dec/2019) and produces three outputs:

1. bid_level_full.parquet — Firm × item × OC participation table
   Columns: códigofornecedor, numerodaoc, códigoitem, flagvencedor,
            mêsanoencerramento, códigounidadecompradora, descriçãoprocedimentocompra

2. firm_loss_stats.parquet — Per-firm aggregated loss statistics
   Columns: códigofornecedor, total_participations, total_wins, total_losses,
            win_rate, always_loser

3. firm_tender_map.parquet — Firm × OC × item mapping for FL reclassification

4. FREQ_PARTICIP_rebuilt.parquet — Frequent participant firms (≥1,000 participations)
   Columns: códigofornecedor, tenders_count, frequent_particip

5. LOSERS_rebuilt.parquet — FL firm counts per (OC, item) using IQR threshold
   Columns: numerodaoc, códigoitem, losers_count

Usage:
    python3 scripts/00_build_bidlevel.py
"""

import sys
import time
from pathlib import Path

import pandas as pd
import pyarrow.parquet as pq

# ---- Paths -------------------------------------------------------------------
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_DIR = SCRIPT_DIR.parent
DATA_PROC = PROJECT_DIR / "data" / "processed"
BEC_RAW = Path("/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement")

# Complete LANCES file: all 22 semesters appended by Stata
LANCES_FULL = BEC_RAW / "ai-procurement/Discontinuity/LANCES_Final_Semester.dta"

COLS_NEEDED = [
    "mêsanoencerramento",
    "códigofornecedor",
    "flagvencedor",
    "numerodaoc",
    "códigoitem",
    "códigounidadecompradora",
    "descriçãoprocedimentocompra",
]

OUT_BIDLEVEL = DATA_PROC / "bid_level_full.parquet"
OUT_FIRMSTATS = DATA_PROC / "firm_loss_stats.parquet"
OUT_FIRM_TENDER = DATA_PROC / "firm_tender_map.parquet"
OUT_FREQ_PARTICIP = DATA_PROC / "FREQ_PARTICIP_rebuilt.parquet"
OUT_LOSERS = DATA_PROC / "LOSERS_rebuilt.parquet"

CHUNK_SIZE = 500_000


def read_lances_chunked(path: Path) -> pd.DataFrame:
    """Read the full LANCES .dta in chunks to manage memory."""
    size_gb = path.stat().st_size / 1e9
    print(f"  Reading {path.name} ({size_gb:.1f} GB)...", flush=True)

    reader = pd.read_stata(path, iterator=True, columns=COLS_NEEDED)
    chunks = []
    total_rows = 0

    try:
        while True:
            chunk = reader.read(CHUNK_SIZE)
            if chunk is None or len(chunk) == 0:
                break
            chunks.append(chunk)
            total_rows += len(chunk)
            if total_rows % 5_000_000 == 0:
                print(f"    {total_rows:>12,} rows read...", flush=True)
    except Exception as e:
        print(f"    Stopped at {total_rows:,} rows ({e})")

    if not chunks:
        print("    ERROR: No data read")
        return pd.DataFrame(columns=COLS_NEEDED)

    df = pd.concat(chunks, ignore_index=True)
    dates = sorted(df["mêsanoencerramento"].dropna().unique())
    print(f"    {len(df):,} rows, {dates[0]} – {dates[-1]}")
    return df


def build_firm_stats(df: pd.DataFrame) -> pd.DataFrame:
    """Compute per-firm loss statistics from bid-level data."""
    # Convert flagvencedor to numeric
    df["winner"] = pd.to_numeric(df["flagvencedor"], errors="coerce").fillna(0).astype(int)

    stats = df.groupby("códigofornecedor").agg(
        total_participations=("winner", "size"),
        total_wins=("winner", "sum"),
    ).reset_index()

    stats["total_losses"] = stats["total_participations"] - stats["total_wins"]
    stats["win_rate"] = stats["total_wins"] / stats["total_participations"]
    stats["always_loser"] = (stats["total_wins"] == 0).astype(int)

    return stats


def build_firm_tender_map(df: pd.DataFrame) -> pd.DataFrame:
    """Build a compact firm × tender-item mapping.

    For each (firm, OC, item), record whether the firm won.
    This enables FL reclassification: given a set of FL firms,
    find which tender-items they participated in.
    """
    df["winner"] = pd.to_numeric(df["flagvencedor"], errors="coerce").fillna(0).astype(int)

    # Collapse to firm × OC × item level (a firm may have multiple bids per item)
    ftm = df.groupby(["códigofornecedor", "numerodaoc", "códigoitem"]).agg(
        n_bids=("winner", "size"),
        won=("winner", "max"),
    ).reset_index()

    return ftm


def build_freq_particip(ftm: pd.DataFrame, min_participations: int = 1000) -> pd.DataFrame:
    """Identify frequent participant firms (≥ min_participations unique tender-items)."""
    firm_counts = ftm.groupby("códigofornecedor").size().reset_index(name="tenders_count")
    freq = firm_counts[firm_counts["tenders_count"] >= min_participations].copy()
    freq["frequent_particip"] = 1
    return freq


def build_losers(ftm: pd.DataFrame, freq_particip: pd.DataFrame) -> pd.DataFrame:
    """Build LOSERS table: count FL firms per (OC, item) using IQR threshold on FREQ_PARTICIP."""
    tc = freq_particip["tenders_count"]
    q1, q3 = tc.quantile(0.25), tc.quantile(0.75)
    iqr = q3 - q1
    threshold = q3 + 1.5 * iqr

    fl_ids = set(freq_particip.loc[freq_particip["tenders_count"] > threshold, "códigofornecedor"])
    print(f"  IQR threshold: Q3={q3:.0f}, IQR={iqr:.0f}, threshold={threshold:.0f}")
    print(f"  FL firms (above threshold): {len(fl_ids):,}")

    ftm_fl = ftm[ftm["códigofornecedor"].isin(fl_ids)]
    losers = ftm_fl.groupby(["numerodaoc", "códigoitem"]).size().reset_index(name="losers_count")
    return losers


def main():
    t0 = time.time()
    print("=" * 72)
    print("00_build_bidlevel.py: Extracting bid-level firm participation")
    print("=" * 72)

    if not LANCES_FULL.exists():
        print(f"ERROR: {LANCES_FULL} not found.")
        sys.exit(1)

    # Read the complete file
    print("\n--- Phase 1: Reading LANCES_Final_Semester.dta ---")
    bid_data = read_lances_chunked(LANCES_FULL)

    if len(bid_data) == 0:
        print("ERROR: No data extracted.")
        sys.exit(1)

    print(f"\nTotal bid-level rows: {len(bid_data):,}")
    print(f"Unique firms: {bid_data['códigofornecedor'].nunique():,}")
    print(f"Date range: {bid_data['mêsanoencerramento'].min()} – {bid_data['mêsanoencerramento'].max()}")

    # ---- Phase 2: Save bid-level data as parquet ----
    print(f"\n--- Phase 2: Saving {OUT_BIDLEVEL.name} ---")
    DATA_PROC.mkdir(parents=True, exist_ok=True)
    bid_data.to_parquet(OUT_BIDLEVEL, engine="pyarrow", index=False)
    size_mb = OUT_BIDLEVEL.stat().st_size / (1024 * 1024)
    print(f"  Saved: {size_mb:.1f} MB ({len(bid_data):,} rows)")

    # ---- Phase 3: Firm loss statistics ----
    print(f"\n--- Phase 3: Building {OUT_FIRMSTATS.name} ---")
    firm_stats = build_firm_stats(bid_data)
    firm_stats.to_parquet(OUT_FIRMSTATS, engine="pyarrow", index=False)
    size_mb = OUT_FIRMSTATS.stat().st_size / (1024 * 1024)
    n_always = firm_stats["always_loser"].sum()
    print(f"  {len(firm_stats):,} unique firms")
    print(f"  {n_always:,} always-loser firms (win_rate=0)")
    print(f"  Saved: {size_mb:.1f} MB")

    # ---- Phase 4: Firm-tender mapping ----
    print(f"\n--- Phase 4: Building {OUT_FIRM_TENDER.name} ---")
    ftm = build_firm_tender_map(bid_data)
    del bid_data  # Free memory
    ftm.to_parquet(OUT_FIRM_TENDER, engine="pyarrow", index=False)
    size_mb = OUT_FIRM_TENDER.stat().st_size / (1024 * 1024)
    print(f"  {len(ftm):,} firm-tender-item pairs")
    print(f"  Saved: {size_mb:.1f} MB")

    # ---- Phase 5: Frequent participants ----
    print(f"\n--- Phase 5: Building {OUT_FREQ_PARTICIP.name} ---")
    freq_particip = build_freq_particip(ftm, min_participations=1000)
    freq_particip.to_parquet(OUT_FREQ_PARTICIP, engine="pyarrow", index=False)
    size_mb = OUT_FREQ_PARTICIP.stat().st_size / (1024 * 1024)
    print(f"  {len(freq_particip):,} frequent participant firms (≥1,000 participations)")
    print(f"  tenders_count range: {freq_particip['tenders_count'].min():,} – {freq_particip['tenders_count'].max():,}")
    print(f"  Saved: {size_mb:.1f} MB")

    # ---- Phase 6: LOSERS (FL counts per OC × item) ----
    print(f"\n--- Phase 6: Building {OUT_LOSERS.name} ---")
    losers = build_losers(ftm, freq_particip)
    del ftm  # Free memory
    losers.to_parquet(OUT_LOSERS, engine="pyarrow", index=False)
    size_mb = OUT_LOSERS.stat().st_size / (1024 * 1024)
    print(f"  {len(losers):,} (OC, item) pairs with FL presence")
    print(f"  losers_count range: {losers['losers_count'].min()} – {losers['losers_count'].max()}")
    print(f"  Saved: {size_mb:.1f} MB")

    elapsed = time.time() - t0
    print(f"\n{'=' * 72}")
    print(f"Done in {elapsed:.0f}s")
    print(f"Outputs:")
    print(f"  {OUT_BIDLEVEL}")
    print(f"  {OUT_FIRMSTATS}")
    print(f"  {OUT_FIRM_TENDER}")
    print(f"  {OUT_FREQ_PARTICIP}")
    print(f"  {OUT_LOSERS}")
    print(f"{'=' * 72}")


if __name__ == "__main__":
    main()
