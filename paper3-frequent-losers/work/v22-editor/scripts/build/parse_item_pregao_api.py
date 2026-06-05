#!/usr/bin/env python3
"""
parse_item_pregao_api.py

Stream 574 weekly ComprasNet item_pregao API JSON dumps (2009-2019, ~10GB)
into a single snappy parquet, memory-safe (file-by-file, chunked ParquetWriter).

INPUT : /home/darciogm1/projetos/comprasnet/data/raw/item_pregao/*.json
        (each file = top-level JSON list of item records)
OUTPUT: /home/darciogm1/projetos/bitter-pills/paper3-frequent-losers/
        data/processed_comprasnet/item_pregao_api.parquet

Notes (verified empirically before writing this script):
  - Top level is a JSON list (not _embedded wrapper).
  - Numeric value fields are dot-decimal strings ('11.15', '0'), NOT Brazilian
    commas. We still defensively strip thousands separators and convert any
    comma-decimal just in case a later file differs.
  - idCompra is 17 chars = codigo_ug(6) + "05"(modalidade pregão) + numerodaoc(9).
  - idCompraItem is 22 chars = idCompra(17) + item_seq(5) and equals the panel's
    `códigoitem` exactly -> that is the join key for linkability.
  - dtAlteracao is an ETL artifact (2025 timestamps); year is parsed from
    dtEncerramento, falling back to dtHom.
"""
import json
import os
import sys
import glob
import time
import psutil
import pyarrow as pa
import pyarrow.parquet as pq

RAW_DIR = "/home/darciogm1/projetos/comprasnet/data/raw/item_pregao"
OUT_PATH = ("/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers/"
            "data/processed_comprasnet/item_pregao_api.parquet")

# Fields kept (all ids, prices, dates + a couple of descriptive/situation cols)
STR_FIELDS = [
    "idCompra", "idCompraItem", "decreto7174", "situacaoItem",
    "descricaoItem", "descricaoDetalhadaItem", "unidadeFornecimento",
    "fornecedorVencedor", "noAdjudic", "noHom",
    "dtEncerramento", "dtAdjudic", "dtHom", "dtAlteracao",
    "margemPreferencial", "tratamentoDiferenciado",
]
NUM_FIELDS = [
    "quantidadeItem", "valorEstimadoItem", "menorLance",
    "valorNegociado", "valorHomologadoItem",
]

# Derived columns appended per row: source_file, year + decomposed keys
DERIVED_STR = ["source_file", "codigo_ug", "numerodaoc", "codigoitem"]
# codigoitem == idCompraItem, exposed under the panel's name for convenience.

PROGRESS_EVERY = 50
CHUNK_ROWS = 50_000  # rows per ParquetWriter.write_table flush


def to_float(v):
    """Parse a numeric value that may be a dot- or comma-decimal string."""
    if v is None:
        return None
    if isinstance(v, (int, float)):
        return float(v)
    s = str(v).strip()
    if s == "" or s.lower() in ("none", "null", "nan"):
        return None
    # Handle the (currently unseen) Brazilian "1.234,56" form, and plain commas.
    if "," in s:
        if "." in s and s.rfind(".") < s.rfind(","):
            s = s.replace(".", "").replace(",", ".")  # 1.234,56 -> 1234.56
        else:
            s = s.replace(",", ".")                    # 1234,56  -> 1234.56
    try:
        return float(s)
    except ValueError:
        return None


def clean_str(v):
    if v is None:
        return None
    if isinstance(v, str):
        s = v.strip()
        return s if s else None
    return str(v)


def parse_year(enc, hom):
    """Year from dtEncerramento (YYYY-...), fallback dtHom."""
    for d in (enc, hom):
        if d and isinstance(d, str) and len(d) >= 4 and d[:4].isdigit():
            y = int(d[:4])
            if 1990 <= y <= 2030:
                return y
    return None


# Arrow schema
schema = pa.schema(
    [(f, pa.string()) for f in STR_FIELDS] +
    [(f, pa.float64()) for f in NUM_FIELDS] +
    [("source_file", pa.string()),
     ("codigo_ug", pa.string()),
     ("numerodaoc", pa.string()),
     ("codigoitem", pa.string()),
     ("year", pa.int32())]
)
ALL_COLS = STR_FIELDS + NUM_FIELDS + ["source_file", "codigo_ug",
                                      "numerodaoc", "codigoitem", "year"]


def rss_gb():
    return psutil.Process().memory_info().rss / 1e9


def flush(writer, buf):
    if not buf["idCompra"]:
        return
    arrays = []
    for c in ALL_COLS:
        if c in NUM_FIELDS:
            arrays.append(pa.array(buf[c], type=pa.float64()))
        elif c == "year":
            arrays.append(pa.array(buf[c], type=pa.int32()))
        else:
            arrays.append(pa.array(buf[c], type=pa.string()))
    writer.write_table(pa.Table.from_arrays(arrays, schema=schema))
    for c in ALL_COLS:
        buf[c].clear()


def main():
    files = sorted(glob.glob(os.path.join(RAW_DIR, "*.json")))
    if not files:
        print(f"No JSON files in {RAW_DIR}", file=sys.stderr)
        sys.exit(1)

    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    vm = psutil.virtual_memory()
    print(f"[init] host={os.uname().nodename} files={len(files)} "
          f"RAM_total={vm.total/1e9:.1f}GB RAM_free={vm.available/1e9:.1f}GB "
          f"rss={rss_gb():.2f}GB", flush=True)

    # In-process exact-duplicate dedup on idCompraItem (the natural unique key:
    # one row per item). Weekly windows overlap by a day or two, so the same
    # item can appear in adjacent files; we keep the first occurrence.
    seen = set()
    buf = {c: [] for c in ALL_COLS}

    t0 = time.time()
    total_in = 0
    total_out = 0
    dup_dropped = 0

    writer = pq.ParquetWriter(OUT_PATH, schema, compression="snappy")
    try:
        for i, fp in enumerate(files, 1):
            src = os.path.basename(fp)
            try:
                with open(fp) as fh:
                    recs = json.load(fh)
            except Exception as e:  # noqa: BLE001
                print(f"[warn] failed to parse {src}: {e}", file=sys.stderr,
                      flush=True)
                continue
            if not isinstance(recs, list):
                # Defensive: tolerate an _embedded-style wrapper if it appears.
                if isinstance(recs, dict):
                    recs = (recs.get("_embedded", {}) or {}).get("items") \
                        or recs.get("items") or recs.get("data") or []
                else:
                    recs = []

            for r in recs:
                total_in += 1
                ici = r.get("idCompraItem")
                key = ici if ici is not None else id(r)
                if ici is not None:
                    if ici in seen:
                        dup_dropped += 1
                        continue
                    seen.add(ici)

                ic = clean_str(r.get("idCompra"))
                ug = ic[:6] if ic and len(ic) == 17 else None
                oc = ic[8:] if ic and len(ic) == 17 else None

                for f in STR_FIELDS:
                    buf[f].append(clean_str(r.get(f)))
                for f in NUM_FIELDS:
                    buf[f].append(to_float(r.get(f)))
                buf["source_file"].append(src)
                buf["codigo_ug"].append(ug)
                buf["numerodaoc"].append(oc)
                buf["codigoitem"].append(clean_str(ici))
                buf["year"].append(
                    parse_year(r.get("dtEncerramento"), r.get("dtHom")))
                total_out += 1

                if len(buf["idCompra"]) >= CHUNK_ROWS:
                    flush(writer, buf)

            if i % PROGRESS_EVERY == 0 or i == len(files):
                flush(writer, buf)  # keep buffer bounded at progress points too
                el = time.time() - t0
                print(f"[{i:>3}/{len(files)}] {src}  in={total_in:,} "
                      f"out={total_out:,} dup={dup_dropped:,} "
                      f"seen={len(seen):,} rss={rss_gb():.2f}GB "
                      f"elapsed={el:.0f}s", flush=True)

        flush(writer, buf)
    finally:
        writer.close()

    el = time.time() - t0
    print(f"[done] read={total_in:,} written={total_out:,} "
          f"dup_dropped={dup_dropped:,} time={el:.0f}s "
          f"rss_peak~{rss_gb():.2f}GB", flush=True)
    print(f"[out]  {OUT_PATH}  size={os.path.getsize(OUT_PATH)/1e9:.2f}GB",
          flush=True)


if __name__ == "__main__":
    main()
