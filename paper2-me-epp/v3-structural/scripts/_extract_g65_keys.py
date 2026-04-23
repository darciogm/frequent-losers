#!/usr/bin/env python3
# Varre o CSV cru do Paper 2 e grava um parquet só com o universo G65:
# chaves (numerodaoc, codigoitem), classe CADMAT, preço-ref, data numérica
# e os counts históricos de ME/EPP/outras firmas por fase. O parquet é
# consumido pelo 32_historical_sme.R para o cruzamento bid-level.
#
# CSV tem 6.4 GB, 373 colunas, separador ';', encoding UTF-8 mesmo que o
# README antigo diga Latin-1. Stream com csv para não estourar RAM.

import csv
import sys
import time
import pyarrow as pa
import pyarrow.parquet as pq

csv.field_size_limit(sys.maxsize)

SRC = "/home/darciogm1/projetos/bitter-pills/paper2-me-epp/data/raw/Paper2_ME_EPP.csv"
DST = "/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v3-structural/data/processed/g65_keys.parquet"

PHASE_TAGS = ("ph1", "ph3", "ph4", "ph6", "ph7")


def main() -> None:
    t0 = time.time()
    with open(SRC, encoding="utf-8", newline="", errors="replace") as f:
        r = csv.reader(f, delimiter=";")
        header = next(r)
        i = {name: header.index(col) for name, col in {
            "oc":      "numerodaoc",
            "item":    "códigoitem",
            "grupo":   "códigogrupo",
            "classe":  "códigoclasse",
            "ref":     "preco_ref",
            "dt":      "data_oc_numb",
        }.items()}
        phase_cols = {}
        for tag in PHASE_TAGS:
            phase_cols[f"me_{tag}"]  = header.index(f"numfornecs_type_me_{tag}")
            phase_cols[f"epp_{tag}"] = header.index(f"numfornecs_type_epp_{tag}")
            phase_cols[f"oth_{tag}"] = header.index(f"numfornecs_type_oth_{tag}")
            phase_cols[f"all_{tag}"] = header.index(f"numfornecs_{tag}")

        data = {k: [] for k in (
            "numerodaoc", "codigoitem", "codigoclasse", "preco_ref", "data_oc_numb"
        )}
        for k in phase_cols:
            data[f"n_{k}"] = []

        scanned = kept = 0
        for row in r:
            scanned += 1
            try:
                if int(row[i["grupo"]]) != 65:
                    continue
            except (ValueError, IndexError):
                continue
            try:
                classe = int(row[i["classe"]])
            except (ValueError, IndexError):
                classe = None
            try:
                ref = float(row[i["ref"]].replace(",", "."))
            except (ValueError, IndexError, AttributeError):
                ref = None
            try:
                dt = int(row[i["dt"]])
            except (ValueError, IndexError):
                dt = None

            data["numerodaoc"].append(row[i["oc"]].strip())
            data["codigoitem"].append(row[i["item"]].strip())
            data["codigoclasse"].append(classe)
            data["preco_ref"].append(ref)
            data["data_oc_numb"].append(dt)
            for k, idx in phase_cols.items():
                try:
                    data[f"n_{k}"].append(int(row[idx]) if row[idx] else 0)
                except (ValueError, IndexError):
                    data[f"n_{k}"].append(0)
            kept += 1

            if scanned % 500_000 == 0:
                print(f"  scanned {scanned/1e6:.1f}M, kept {kept/1e6:.2f}M  "
                      f"[{time.time()-t0:.1f}s]", flush=True)

    tbl = pa.table({k: pa.array(v) for k, v in data.items()})
    pq.write_table(tbl, DST, compression="snappy")
    print(f"Total scanned: {scanned/1e6:.2f}M, kept G65={kept/1e6:.2f}M")
    print(f"Wrote {DST}  [{time.time()-t0:.1f}s]")


if __name__ == "__main__":
    main()
