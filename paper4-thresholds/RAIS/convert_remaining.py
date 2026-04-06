#!/usr/bin/env python3
"""
Convert remaining large RAIS TXT files (>4GB, latin1) to Parquet.

Strategy: iconv latin1→utf8 streaming → polars read_csv_batched → pyarrow ParquetWriter
This avoids loading the entire file into memory.

The iconv step is done in 64MB Python chunks (not via subprocess temp file)
to avoid doubling disk usage.
"""
import polars as pl
import pyarrow.parquet as pq
import os
import sys
import gc
import time
import subprocess
from pathlib import Path

BASE = Path("/home/darciogm1/projetos/bitter-pills/paper4-thresholds/RAIS")
OUT_VINCULOS = BASE / "parquet" / "vinculos"
TMP_DIR = Path("/tmp")

KEEP_TXT = "--keep-txt" in sys.argv
BATCH_SIZE = 500_000

# Files to process (remaining after v2 script)
REMAINING = [
    (BASE / "2015" / "RJ2015ID.txt",   {"type": "vinculos", "year": 2015, "uf": "RJ", "name": "RJ2015ID"}),
    (BASE / "2016" / "MG2016ID.txt",   {"type": "vinculos", "year": 2016, "uf": "MG", "name": "MG2016ID"}),
    (BASE / "2017" / "MG2017ID.txt",   {"type": "vinculos", "year": 2017, "uf": "MG", "name": "MG2017ID"}),
    (BASE / "2015" / "MG2015ID.txt",   {"type": "vinculos", "year": 2015, "uf": "MG", "name": "MG2015ID"}),
    (BASE / "2014" / "SP2014ID.txt",   {"type": "vinculos", "year": 2014, "uf": "SP", "name": "SP2014ID"}),
    (BASE / "2011" / "SP2011ID.txt",   {"type": "vinculos", "year": 2011, "uf": "SP", "name": "SP2011ID"}),
    (BASE / "2012" / "SP2012ID.txt",   {"type": "vinculos", "year": 2012, "uf": "SP", "name": "SP2012ID"}),
    (BASE / "2013" / "SP2013ID.txt",   {"type": "vinculos", "year": 2013, "uf": "SP", "name": "SP2013ID"}),
    (BASE / "2016" / "SP2016ID.txt",   {"type": "vinculos", "year": 2016, "uf": "SP", "name": "SP2016ID"}),
    (BASE / "2017" / "SP2017ID.txt",   {"type": "vinculos", "year": 2017, "uf": "SP", "name": "SP2017ID"}),
    (BASE / "2015" / "SP2015ID.txt",   {"type": "vinculos", "year": 2015, "uf": "SP", "name": "SP2015ID"}),
]


def convert_file(filepath: Path, info: dict) -> bool:
    """Convert a single large latin1 TXT file to parquet via iconv + batched read."""
    year = info["year"]
    uf = info["uf"]
    out_path = OUT_VINCULOS / f"{uf}_{year}.parquet"

    if out_path.exists():
        print(f"  SKIP (exists): {out_path.name}")
        return True

    file_size = filepath.stat().st_size
    tmp_utf8 = TMP_DIR / f"rais_{uf}_{year}_utf8.txt"

    try:
        # Step 1: Convert latin1 → utf8 using iconv (streaming, low memory)
        print(f"  Step 1: iconv latin1→utf8 ({file_size/1e9:.1f}GB)...", flush=True)
        t0 = time.time()

        proc = subprocess.run(
            ["iconv", "-f", "latin1", "-t", "utf-8", str(filepath)],
            stdout=open(tmp_utf8, "wb"),
            stderr=subprocess.PIPE,
            timeout=1800,  # 30 min max
        )
        if proc.returncode != 0:
            raise RuntimeError(f"iconv failed: {proc.stderr.decode()}")

        t1 = time.time()
        tmp_size = tmp_utf8.stat().st_size
        print(f"    iconv done: {tmp_size/1e9:.1f}GB in {t1-t0:.0f}s", flush=True)

        # Step 2: Batched read from utf8 file → streaming parquet write
        print(f"  Step 2: batched read + parquet write...", flush=True)

        reader = pl.read_csv_batched(
            tmp_utf8,
            separator=";",
            encoding="utf8-lossy",
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
                pl.lit(year).cast(pl.Int16).alias("ano"),
                pl.lit(uf).alias("uf_arquivo"),
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

            if batch_num % 20 == 0:
                print(f"    ... {total_rows:,} rows", flush=True)

            del df_batch, arrow_table, batches
            gc.collect()

        if writer:
            writer.close()

        t2 = time.time()
        dst_size = out_path.stat().st_size
        ratio = file_size / dst_size if dst_size > 0 else 0
        print(f"  OK: {file_size/1e6:.0f}MB → {dst_size/1e6:.0f}MB ({ratio:.1f}x) [{total_rows:,} rows] {t2-t0:.0f}s total", flush=True)

        return True

    except Exception as e:
        print(f"  ERROR: {e}", flush=True)
        if out_path.exists():
            out_path.unlink()
        return False

    finally:
        # Always clean up temp file
        if tmp_utf8.exists():
            tmp_utf8.unlink()
            print(f"  Cleaned up temp file", flush=True)
        gc.collect()


def main():
    OUT_VINCULOS.mkdir(parents=True, exist_ok=True)

    success = 0
    failed = 0

    for i, (filepath, info) in enumerate(REMAINING, 1):
        if not filepath.exists():
            print(f"[{i}/{len(REMAINING)}] MISSING: {filepath.name}")
            continue

        file_size = filepath.stat().st_size
        print(f"[{i}/{len(REMAINING)}] {file_size/1e9:.1f}GB  {info['year']} {info['uf']}  {filepath.name}", flush=True)

        ok = convert_file(filepath, info)

        if ok:
            success += 1
            if not KEEP_TXT:
                filepath.unlink()
                print(f"  Deleted original: {filepath.name}", flush=True)
                # Delete duplicate in subdirectory if exists
                for dup in filepath.parent.rglob(filepath.name):
                    if dup != filepath and dup.exists():
                        dup.unlink()
                        print(f"  Deleted duplicate: {dup}", flush=True)
                        try:
                            dup.parent.rmdir()
                        except OSError:
                            pass
        else:
            failed += 1

    print(f"\n{'='*60}")
    print(f"DONE: {success} converted, {failed} failed")
    total_pq = sum(f.stat().st_size for f in OUT_VINCULOS.glob("*.parquet"))
    print(f"Total vinculos parquet: {total_pq/1e9:.1f}GB")


if __name__ == "__main__":
    main()
