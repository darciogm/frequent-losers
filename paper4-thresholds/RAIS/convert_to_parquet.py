#!/usr/bin/env python3
"""
Convert RAIS TXT files to Parquet format.
Processes one file at a time to manage memory.
Deletes TXT after successful conversion.

Usage: python3 convert_to_parquet.py [--keep-txt] [--dry-run]
"""
import polars as pl
import os
import sys
import gc
import time
from pathlib import Path

BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds/RAIS")
OUT_VINCULOS = BASE / "parquet" / "vinculos"
OUT_ESTB = BASE / "parquet" / "estb"
OUT_VINCULOS.mkdir(parents=True, exist_ok=True)
OUT_ESTB.mkdir(parents=True, exist_ok=True)

KEEP_TXT = "--keep-txt" in sys.argv
DRY_RUN = "--dry-run" in sys.argv

# Max rows to read at once for very large files (>2GB)
BATCH_THRESHOLD = 2_000_000_000  # 2GB


def detect_separator(filepath: Path) -> str:
    """Detect if file uses ; or | as separator."""
    with open(filepath, "r", encoding="latin1", errors="replace") as f:
        header = f.readline()
    if header.count("|") > header.count(";"):
        return "|"
    return ";"


def classify_file(filepath: Path):
    """Classify a RAIS TXT file as vinculos or estb, extract year and UF."""
    name = filepath.stem  # e.g., RR2009ID, Estb2010ID, SP2016ID
    parent = filepath.parent.name  # e.g., 2009, 2010

    try:
        year = int(parent)
    except ValueError:
        return None

    name_upper = name.upper()
    if "ESTB" in name_upper:
        return {"type": "estb", "year": year, "uf": "BR", "name": name}

    # Extract UF from filename: first 2 chars
    uf = name[:2].upper()
    # Handle edge cases like "SP2010ID1" -> uf=SP
    if uf.isalpha() and len(uf) == 2:
        return {"type": "vinculos", "year": year, "uf": uf, "name": name}

    return None


def convert_file(filepath: Path, info: dict) -> bool:
    """Convert a single TXT file to parquet. Returns True on success."""
    ftype = info["type"]
    year = info["year"]
    uf = info["uf"]
    name = info["name"]

    out_dir = OUT_ESTB if ftype == "estb" else OUT_VINCULOS

    # Detect split suffix (e.g., SP2009ID1 -> "1", SP2009ID2 -> "2")
    suffix = name.upper().replace(uf, "", 1).replace(str(year), "", 1)
    suffix = suffix.replace("ID", "").replace(".", "").strip()
    if suffix:
        out_path = out_dir / f"{uf}_{year}_{suffix}.parquet"
    else:
        out_path = out_dir / f"{uf}_{year}.parquet"

    if out_path.exists():
        print(f"  SKIP (exists): {out_path.name}")
        return True

    sep = detect_separator(filepath)
    file_size = filepath.stat().st_size

    try:
        df = pl.read_csv(
            filepath,
            separator=sep,
            encoding="latin1",
            infer_schema_length=10000,
            ignore_errors=True,
            truncate_ragged_lines=True,
            low_memory=file_size > BATCH_THRESHOLD,
            quote_char=None,
        )

        df = df.with_columns(
            pl.lit(year).cast(pl.Int16).alias("ano"),
            pl.lit(uf).alias("uf_arquivo"),
        )

        df.write_parquet(out_path, compression="snappy")

        src_mb = file_size / 1e6
        dst_mb = out_path.stat().st_size / 1e6
        ratio = src_mb / dst_mb if dst_mb > 0 else 0
        print(f"  OK: {src_mb:.0f}MB -> {dst_mb:.0f}MB ({ratio:.1f}x) [{df.shape[0]:,} rows]")

        del df
        gc.collect()
        return True

    except Exception as e:
        print(f"  ERROR: {e}")
        # Clean up partial file
        if out_path.exists():
            out_path.unlink()
        gc.collect()
        return False


def main():
    # Collect all TXT files
    txt_files = []
    for year_dir in sorted(BASE.iterdir()):
        if not year_dir.is_dir() or year_dir.name in ("parquet",):
            continue
        try:
            int(year_dir.name)
        except ValueError:
            continue

        for f in sorted(year_dir.iterdir()):
            if f.suffix.lower() == ".txt" and not f.name.lower().startswith(("layout", "rais_vinc", "file")):
                info = classify_file(f)
                if info:
                    txt_files.append((f, info))

    print(f"Found {len(txt_files)} TXT files to convert")
    if DRY_RUN:
        for f, info in txt_files:
            print(f"  {info['type']:8s} {info['year']} {info['uf']:2s}  {f.name} ({f.stat().st_size/1e6:.0f}MB)")
        return

    # Process files grouped by year
    success = 0
    failed = 0
    deleted = 0
    total_src_mb = 0
    total_dst_mb = 0

    for i, (filepath, info) in enumerate(txt_files, 1):
        print(f"[{i}/{len(txt_files)}] {info['type']:8s} {info['year']} {info['uf']:2s}  {filepath.name}")

        t0 = time.time()
        ok = convert_file(filepath, info)
        elapsed = time.time() - t0

        if ok:
            success += 1
            total_src_mb += filepath.stat().st_size / 1e6
            if not KEEP_TXT:
                filepath.unlink()
                deleted += 1
        else:
            failed += 1

        if elapsed > 5:
            print(f"  Time: {elapsed:.0f}s")

        # Force GC every 10 files
        if i % 10 == 0:
            gc.collect()

    # Summary
    print(f"\n{'='*60}")
    print(f"DONE: {success} converted, {failed} failed, {deleted} TXT deleted")
    total_dst_mb = sum(
        f.stat().st_size / 1e6
        for f in OUT_VINCULOS.glob("*.parquet")
    ) + sum(
        f.stat().st_size / 1e6
        for f in OUT_ESTB.glob("*.parquet")
    )
    print(f"Total: {total_src_mb/1e3:.1f}GB TXT -> {total_dst_mb/1e3:.1f}GB parquet")


if __name__ == "__main__":
    main()
