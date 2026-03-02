"""Convert all .dta files in data/processed/ to Parquet format."""

import os
import time
from pathlib import Path

import pandas as pd
import pyarrow  # noqa: F401 — ensures pyarrow engine is available

DATA_DIR = Path(__file__).resolve().parent.parent / "data" / "processed"
SIZE_THRESHOLD_MB = 100


def convert_dta_to_parquet(data_dir: Path) -> None:
    dta_files = sorted(data_dir.glob("*.dta"))
    if not dta_files:
        print("No .dta files found.")
        return

    results = []
    for dta_path in dta_files:
        parquet_path = dta_path.with_suffix(".parquet")
        size_mb = dta_path.stat().st_size / (1024 * 1024)
        use_cat = size_mb <= SIZE_THRESHOLD_MB

        print(f"Converting {dta_path.name} ({size_mb:.1f} MB) ...")
        t0 = time.time()
        try:
            df = pd.read_stata(dta_path, convert_categoricals=use_cat)
            df.to_parquet(parquet_path, engine="pyarrow", index=False)
            elapsed = time.time() - t0
            pq_mb = parquet_path.stat().st_size / (1024 * 1024)
            results.append((dta_path.name, df.shape[0], df.shape[1], size_mb, pq_mb, elapsed))
            print(f"  -> {parquet_path.name} ({pq_mb:.1f} MB, {elapsed:.1f}s)")
        except Exception as e:
            print(f"  ERROR: {e}")
            results.append((dta_path.name, None, None, size_mb, None, None))

    print("\n" + "=" * 72)
    print(f"{'File':<30} {'Rows':>10} {'Cols':>6} {'DTA MB':>8} {'PQ MB':>8} {'Time':>6}")
    print("-" * 72)
    for name, rows, cols, dta_mb, pq_mb, elapsed in results:
        r = f"{rows:>10,}" if rows else "     ERROR"
        c = f"{cols:>6}" if cols else "     -"
        p = f"{pq_mb:>8.1f}" if pq_mb else "       -"
        t = f"{elapsed:>5.1f}s" if elapsed else "     -"
        print(f"{name:<30} {r} {c} {dta_mb:>8.1f} {p} {t}")
    print("=" * 72)


if __name__ == "__main__":
    convert_dta_to_parquet(DATA_DIR)
