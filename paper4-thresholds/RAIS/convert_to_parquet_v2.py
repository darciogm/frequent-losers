#!/usr/bin/env python3
"""
Convert RAIS TXT/CSV files to Parquet format — memory-safe streaming version.

Strategy:
  - Files < 4 GB: polars read_csv (low_memory=True) → write_parquet
  - Files >= 4 GB: polars read_csv_batched → pyarrow ParquetWriter (streaming,
    never loads full file into memory)

After successful conversion, deletes the original TXT file.

Usage:
    python3 convert_to_parquet_v2.py              # convert all
    python3 convert_to_parquet_v2.py --dry-run     # list files without converting
    python3 convert_to_parquet_v2.py --keep-txt    # don't delete originals
"""
import polars as pl
import pyarrow.parquet as pq
import os
import sys
import gc
import time
from pathlib import Path

# ── Config ──────────────────────────────────────────────────────────────
BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds/RAIS")
OUT_VINCULOS = BASE / "parquet" / "vinculos"
OUT_ESTB = BASE / "parquet" / "estb"

KEEP_TXT = "--keep-txt" in sys.argv
DRY_RUN = "--dry-run" in sys.argv

# Files >= this size use batched streaming (avoids OOM)
STREAM_THRESHOLD = 4_000_000_000  # 4 GB

# Batch size for streaming reads (rows per batch)
BATCH_SIZE = 500_000

# ── Helpers ─────────────────────────────────────────────────────────────

def detect_separator(filepath: Path) -> str:
    """Detect if file uses ; or | or , as separator by reading header."""
    with open(filepath, "r", encoding="latin1", errors="replace") as f:
        header = f.readline()
    counts = {"|": header.count("|"), ";": header.count(";"), ",": header.count(",")}
    return max(counts, key=counts.get)


def classify_file(filepath: Path):
    """Classify a RAIS file as vinculos or estb, extract year and UF."""
    name = filepath.stem  # e.g., RR2009ID, Estb2010ID, SP2016ID
    name_upper = name.upper()

    # Walk up to find the year directory
    year = None
    for parent in filepath.parents:
        try:
            year = int(parent.name)
            break
        except ValueError:
            continue
    if year is None:
        return None

    # Classify type
    if "ESTB" in name_upper:
        return {"type": "estb", "year": year, "uf": "BR", "name": name}

    # Extract UF: first 2 alpha chars
    uf = ""
    for ch in name:
        if ch.isalpha():
            uf += ch.upper()
        else:
            break
    if len(uf) == 2:
        return {"type": "vinculos", "year": year, "uf": uf, "name": name}

    return None


def get_output_path(info: dict) -> Path:
    """Determine the output parquet path."""
    ftype = info["type"]
    year = info["year"]
    uf = info["uf"]
    name = info["name"]

    out_dir = OUT_ESTB if ftype == "estb" else OUT_VINCULOS

    if ftype == "estb":
        return out_dir / f"{uf}_{year}_ESTB.parquet"

    # Detect split suffix (e.g., SP2009ID1 -> "1", SP2009ID2 -> "2")
    suffix = name.upper().replace(uf, "", 1).replace(str(year), "", 1)
    suffix = suffix.replace("ID", "").replace(".", "").strip()
    if suffix:
        return out_dir / f"{uf}_{year}_{suffix}.parquet"
    return out_dir / f"{uf}_{year}.parquet"


def convert_small(filepath: Path, out_path: Path, info: dict, sep: str) -> tuple:
    """Convert a file < 4GB using polars eager read. Returns (success, rows)."""
    file_size = filepath.stat().st_size

    df = pl.read_csv(
        filepath,
        separator=sep,
        encoding="latin1",
        infer_schema_length=10000,
        ignore_errors=True,
        truncate_ragged_lines=True,
        low_memory=True,
        quote_char=None,
    )

    df = df.with_columns(
        pl.lit(info["year"]).cast(pl.Int16).alias("ano"),
        pl.lit(info["uf"]).alias("uf_arquivo"),
    )

    df.write_parquet(out_path, compression="snappy")
    rows = df.shape[0]
    del df
    gc.collect()
    return True, rows


def convert_large_streaming(filepath: Path, out_path: Path, info: dict, sep: str) -> tuple:
    """Convert a file >= 4GB using batched reading + pyarrow streaming write.
    Peak memory ~ 1-2 GB regardless of file size."""
    reader = pl.read_csv_batched(
        filepath,
        separator=sep,
        encoding="latin1",
        infer_schema_length=10000,
        ignore_errors=True,
        truncate_ragged_lines=True,
        low_memory=True,
        quote_char=None,
        batch_size=BATCH_SIZE,
    )

    writer = None
    total_rows = 0
    batch_num = 0

    while True:
        batches = reader.next_batches(1)
        if not batches:
            break

        df_batch = batches[0]
        df_batch = df_batch.with_columns(
            pl.lit(info["year"]).cast(pl.Int16).alias("ano"),
            pl.lit(info["uf"]).alias("uf_arquivo"),
        )

        arrow_table = df_batch.to_arrow()

        if writer is None:
            writer = pq.ParquetWriter(
                str(out_path),
                arrow_table.schema,
                compression="snappy",
            )

        writer.write_table(arrow_table)
        total_rows += len(df_batch)
        batch_num += 1

        # Progress every 20 batches (~10M rows)
        if batch_num % 20 == 0:
            print(f"    ... {total_rows:,} rows processed", flush=True)

        del df_batch, arrow_table, batches
        gc.collect()

    if writer:
        writer.close()

    return True, total_rows


def collect_txt_files() -> list:
    """Find all TXT/CSV files to convert, recursively within year directories.
    Deduplicates files with the same name (prefers the one directly in the year dir)."""
    txt_files = []
    seen_output_paths = {}  # output_path -> (filepath, info)
    skip_prefixes = ("layout", "rais_vinc", "file", "diferenç", "downloading")

    for year_dir in sorted(BASE.iterdir()):
        if not year_dir.is_dir() or year_dir.name in ("parquet",):
            continue
        try:
            int(year_dir.name)
        except ValueError:
            continue

        # Recursively find txt/TXT files in year directory
        for f in sorted(year_dir.rglob("*")):
            if f.suffix.lower() not in (".txt", ".csv"):
                continue
            if f.name.lower().startswith(skip_prefixes):
                continue
            if ".Zone." in f.name:
                continue

            info = classify_file(f)
            if info:
                out_path = get_output_path(info)
                out_key = str(out_path)
                if out_key in seen_output_paths:
                    # Prefer file directly in year dir (shorter path)
                    existing_f, _ = seen_output_paths[out_key]
                    if len(f.parts) < len(existing_f.parts):
                        seen_output_paths[out_key] = (f, info)
                else:
                    seen_output_paths[out_key] = (f, info)

    txt_files = list(seen_output_paths.values())
    return txt_files


def _delete_duplicates(filepath: Path, info: dict):
    """Delete duplicate copies of the same file in subdirectories."""
    year = info["year"]
    year_dir = BASE / str(year)
    fname = filepath.name
    for dup in year_dir.rglob(fname):
        if dup != filepath and dup.exists():
            print(f"  Deleted duplicate: {dup.relative_to(BASE)}")
            dup.unlink()
            # Remove empty parent dir
            try:
                dup.parent.rmdir()
            except OSError:
                pass


# ── Main ────────────────────────────────────────────────────────────────

def main():
    OUT_VINCULOS.mkdir(parents=True, exist_ok=True)
    OUT_ESTB.mkdir(parents=True, exist_ok=True)

    txt_files = collect_txt_files()
    print(f"Found {len(txt_files)} TXT files to process")

    if DRY_RUN:
        for f, info in sorted(txt_files, key=lambda x: x[0].stat().st_size):
            sz = f.stat().st_size / 1e9
            out = get_output_path(info)
            exists = "SKIP" if out.exists() else "TODO"
            mode = "STREAM" if f.stat().st_size >= STREAM_THRESHOLD else "eager"
            print(f"  [{exists}] {mode:6s} {sz:5.1f}GB  {info['type']:8s} {info['year']} {info['uf']:2s}  {f.name}")
        return

    # Sort by file size (smallest first) to maximize early progress
    txt_files.sort(key=lambda x: x[0].stat().st_size)

    success = 0
    skipped = 0
    failed = 0
    deleted = 0
    total_src_bytes = 0
    total_dst_bytes = 0

    for i, (filepath, info) in enumerate(txt_files, 1):
        file_size = filepath.stat().st_size
        out_path = get_output_path(info)

        # Skip if already converted
        if out_path.exists():
            print(f"[{i}/{len(txt_files)}] SKIP {info['year']} {info['uf']:2s} {filepath.name} → {out_path.name} exists")
            skipped += 1
            # Still delete original if parquet exists and is non-empty
            if not KEEP_TXT and out_path.stat().st_size > 0:
                filepath.unlink()
                deleted += 1
                print(f"  Deleted original: {filepath.name}")
                _delete_duplicates(filepath, info)
            continue

        use_streaming = file_size >= STREAM_THRESHOLD
        mode_str = "STREAM" if use_streaming else "EAGER"
        print(f"[{i}/{len(txt_files)}] {mode_str} {file_size/1e9:.1f}GB  {info['year']} {info['uf']:2s}  {filepath.name}")

        sep = detect_separator(filepath)
        t0 = time.time()

        try:
            if use_streaming:
                ok, rows = convert_large_streaming(filepath, out_path, info, sep)
            else:
                ok, rows = convert_small(filepath, out_path, info, sep)

            elapsed = time.time() - t0
            dst_size = out_path.stat().st_size
            ratio = file_size / dst_size if dst_size > 0 else 0
            print(f"  OK: {file_size/1e6:.0f}MB → {dst_size/1e6:.0f}MB ({ratio:.1f}x) [{rows:,} rows] {elapsed:.0f}s")

            total_src_bytes += file_size
            total_dst_bytes += dst_size
            success += 1

            if not KEEP_TXT:
                filepath.unlink()
                deleted += 1
                # Also delete duplicate copies in subdirectories
                _delete_duplicates(filepath, info)

            gc.collect()

        except Exception as e:
            elapsed = time.time() - t0
            print(f"  ERROR ({elapsed:.0f}s): {e}")
            # Clean up partial output
            if out_path.exists():
                out_path.unlink()
            failed += 1
            gc.collect()

    # ── Summary ──
    print(f"\n{'='*60}")
    print(f"DONE: {success} converted, {skipped} skipped, {failed} failed, {deleted} originals deleted")
    if total_src_bytes > 0:
        print(f"This run: {total_src_bytes/1e9:.1f}GB TXT → {total_dst_bytes/1e9:.1f}GB parquet")

    # Total parquet on disk
    total_pq = sum(f.stat().st_size for f in OUT_VINCULOS.glob("*.parquet")) + \
               sum(f.stat().st_size for f in OUT_ESTB.glob("*.parquet"))
    print(f"Total parquet on disk: {total_pq/1e9:.1f}GB")


if __name__ == "__main__":
    main()
