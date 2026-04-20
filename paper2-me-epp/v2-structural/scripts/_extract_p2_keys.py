#!/usr/bin/env python3
"""
Stream-extract (numerodaoc, códigoitem, códigogrupo, data_oc_numb) from the
raw Paper-2 CSV and write a small parquet keyset filtered to the 18-month
analytical window [data_oc_numb in 680..715 = Sep 2016 .. Aug 2019].

Why: the raw CSV is 6.4 GB, UTF-8 encoded (despite README claiming Latin-1),
semicolon-separated, with 373 columns. DuckDB's read_csv sniffer trips on
the column-count mismatch when we request only 4 cols. Python's csv module
streams cleanly.

Output: /tmp/p2_keys.parquet  (~900k rows, ~3 MB)
Runtime: ~55s on the Paper-2 workstation.
"""
import csv
import sys
import time
import pyarrow as pa
import pyarrow.parquet as pq

csv.field_size_limit(sys.maxsize)

SRC = "/home/darciogm1/projetos/bitter-pills/paper2-me-epp/data/raw/Paper2_ME_EPP.csv"
DST = "/tmp/p2_keys.parquet"
WIN = (680, 715)  # 18-month window in Stata monthly

def main() -> None:
    t0 = time.time()
    with open(SRC, encoding="utf-8", newline="", errors="replace") as f:
        r = csv.reader(f, delimiter=";")
        header = next(r)
        i_oc = header.index("numerodaoc")
        i_it = header.index("códigoitem")
        i_gr = header.index("códigogrupo")
        i_dt = header.index("data_oc_numb")
        i_cl = header.index("códigoclasse") if "códigoclasse" in header else None
        print(f"Columns located: numerodaoc={i_oc}, codigoitem={i_it}, "
              f"codigogrupo={i_gr}, data_oc_numb={i_dt}, codigoclasse={i_cl}")

        oc_l, it_l, gr_l, dt_l, cl_l = [], [], [], [], []
        n = kept = 0
        for row in r:
            n += 1
            try:
                dt = int(row[i_dt])
            except (ValueError, IndexError):
                continue
            if not (WIN[0] <= dt <= WIN[1]):
                continue
            try:
                gr = int(row[i_gr])
            except (ValueError, IndexError):
                gr = None
            try:
                cl = int(row[i_cl]) if i_cl is not None else None
            except (ValueError, IndexError):
                cl = None
            oc_l.append(row[i_oc].strip())
            it_l.append(row[i_it].strip())
            gr_l.append(gr)
            dt_l.append(dt)
            cl_l.append(cl)
            kept += 1
            if n % 500_000 == 0:
                print(f"  scanned {n/1e6:.1f}M, kept {kept/1e6:.2f}M  "
                      f"[{time.time()-t0:.1f}s]")

    print(f"Total scanned: {n/1e6:.2f}M rows, kept {kept/1e6:.2f}M  "
          f"[{time.time()-t0:.1f}s]")

    tbl = pa.table({
        "numerodaoc":   oc_l,
        "codigoitem":   it_l,
        "codigogrupo":  gr_l,
        "codigoclasse": cl_l,
        "data_oc_numb": dt_l,
    })
    pq.write_table(tbl, DST, compression="snappy")
    print(f"Wrote {DST}: {len(oc_l):,} rows, {time.time()-t0:.1f}s total")

if __name__ == "__main__":
    main()
