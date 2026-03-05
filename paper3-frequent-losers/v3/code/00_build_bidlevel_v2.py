"""
00_build_bidlevel_v2.py — Rebuild bid-level data WITH individual bid prices.

Paper 3 v2: Frequent Losers as Cover Bidders in Public Procurement

Reads LANCES_Final_Semester.dta (~45GB) and extracts:
  - Original 7 identifier columns (same as v1)
  - 3 price columns: valorunitárioproposta, valorunitarionegociado, valorunitárioreferência

Output: v3/data/processed/bid_level_with_prices.parquet (~2-3GB, 40M rows × 10 cols)

This unblocks: Bajari-Ye tests (05), cover bid spread (04), mechanism tests (07).

Usage:
    python3 v2/code/00_build_bidlevel_v2.py
"""

import sys
import time
from pathlib import Path

import numpy as np
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq

# ---- Paths -------------------------------------------------------------------
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_DIR = SCRIPT_DIR.parent  # v2/
BASE_V1 = PROJECT_DIR.parent     # paper3-frequent-losers/
DATA_V2 = PROJECT_DIR / "data" / "processed"
BEC_RAW = Path("/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement")

LANCES_FULL = BEC_RAW / "ai-procurement/Discontinuity/LANCES_Final_Semester.dta"

# Columns needed for v2 (v1 columns + 3 price columns)
COLS_NEEDED = [
    "mêsanoencerramento",
    "códigofornecedor",
    "flagvencedor",
    "numerodaoc",
    "códigoitem",
    "códigounidadecompradora",
    "descriçãoprocedimentocompra",
    # NEW: price columns (stored as strings in .dta)
    "valorunitárioproposta",
    "valorunitarionegociado",
    "valorunitárioreferência",
]

OUT_BID_PRICES = DATA_V2 / "bid_level_with_prices.parquet"

CHUNK_SIZE = 500_000


def parse_brl_price(series: pd.Series) -> pd.Series:
    """Convert Brazilian price strings to float.

    Handles:
      - Comma as decimal separator ("1.234,56" -> 1234.56)
      - Period as thousands separator
      - Empty strings / whitespace -> NaN
    """
    s = series.astype(str).str.strip()
    s = s.replace({"": np.nan, "nan": np.nan, "None": np.nan, "none": np.nan})
    # Remove thousands separator (period), then replace comma with period
    s = s.str.replace(".", "", regex=False)
    s = s.str.replace(",", ".", regex=False)
    return pd.to_numeric(s, errors="coerce")


def read_lances_chunked(path: Path) -> pd.DataFrame:
    """Read the full LANCES .dta in chunks, selecting only needed columns."""
    size_gb = path.stat().st_size / 1e9
    print(f"  Reading {path.name} ({size_gb:.1f} GB)...", flush=True)

    # First check which columns exist
    reader = pd.read_stata(path, iterator=True, columns=None)
    sample = reader.read(1)
    available_cols = list(sample.columns)

    cols_to_read = [c for c in COLS_NEEDED if c in available_cols]
    missing_cols = [c for c in COLS_NEEDED if c not in available_cols]

    if missing_cols:
        print(f"  WARNING: Missing columns: {missing_cols}")
        print(f"  Available price-like columns: {[c for c in available_cols if 'valor' in c.lower()]}")

    print(f"  Reading {len(cols_to_read)} columns: {cols_to_read}", flush=True)
    del reader

    # Re-read with only needed columns
    reader = pd.read_stata(path, iterator=True, columns=cols_to_read)
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
        return pd.DataFrame()

    df = pd.concat(chunks, ignore_index=True)
    print(f"    {len(df):,} rows read total")
    return df


def main():
    t0 = time.time()
    print("=" * 72)
    print("00_build_bidlevel_v2.py: Extracting bid-level data WITH prices")
    print("=" * 72)

    if not LANCES_FULL.exists():
        print(f"ERROR: {LANCES_FULL} not found.")
        sys.exit(1)

    # ---- Phase 1: Read data ----
    print("\n--- Phase 1: Reading LANCES_Final_Semester.dta ---")
    df = read_lances_chunked(LANCES_FULL)

    if len(df) == 0:
        print("ERROR: No data extracted.")
        sys.exit(1)

    print(f"\nTotal rows: {len(df):,}")
    print(f"Columns: {list(df.columns)}")

    # ---- Phase 2: Parse price columns ----
    print("\n--- Phase 2: Parsing price columns ---")

    price_cols = {
        "valorunitárioproposta": "bid_price",
        "valorunitarionegociado": "negot_price",
        "valorunitárioreferência": "ref_price",
    }

    for orig_col, new_col in price_cols.items():
        if orig_col in df.columns:
            print(f"  Parsing {orig_col} -> {new_col}...")
            df[new_col] = parse_brl_price(df[orig_col])
            n_valid = df[new_col].notna().sum()
            n_pos = (df[new_col] > 0).sum()
            print(f"    Valid: {n_valid:,} ({100*n_valid/len(df):.1f}%), "
                  f"Positive: {n_pos:,}")
            if n_valid > 0:
                desc = df[new_col].describe()
                print(f"    Range: [{desc['min']:.2f}, {desc['max']:.2f}], "
                      f"Mean: {desc['mean']:.2f}, Median: {desc['50%']:.2f}")
            # Drop original string column
            df.drop(columns=[orig_col], inplace=True)
        else:
            print(f"  WARNING: {orig_col} not found, creating {new_col} as NaN")
            df[new_col] = np.nan

    # ---- Phase 3: Convert winner flag ----
    print("\n--- Phase 3: Converting winner flag ---")
    df["won"] = pd.to_numeric(df["flagvencedor"], errors="coerce").fillna(0).astype(int)

    # ---- Phase 4: Save ----
    print(f"\n--- Phase 4: Saving {OUT_BID_PRICES.name} ---")
    DATA_V2.mkdir(parents=True, exist_ok=True)

    # Keep clean column set
    keep_cols = [
        "mêsanoencerramento", "códigofornecedor", "numerodaoc",
        "códigoitem", "códigounidadecompradora", "descriçãoprocedimentocompra",
        "won", "bid_price", "negot_price", "ref_price",
    ]
    keep_cols = [c for c in keep_cols if c in df.columns]
    df = df[keep_cols]

    df.to_parquet(OUT_BID_PRICES, engine="pyarrow", index=False)
    size_mb = OUT_BID_PRICES.stat().st_size / (1024 * 1024)
    print(f"  Saved: {size_mb:.1f} MB ({len(df):,} rows × {len(df.columns)} cols)")

    # ---- Summary ----
    elapsed = time.time() - t0
    print(f"\n{'=' * 72}")
    print(f"Done in {elapsed:.0f}s ({elapsed/60:.1f} min)")
    print(f"Output: {OUT_BID_PRICES}")
    print(f"{'=' * 72}")


if __name__ == "__main__":
    main()
