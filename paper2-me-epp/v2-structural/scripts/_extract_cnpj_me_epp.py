#!/usr/bin/env python3
"""
Stream-extract (cnpj_fornecedor, me_epp) per POI from the raw Paper-2 CSV
and aggregate to firm-level canonical SME classification:
    sme_canonical = mean(me_epp) across all observations where firm was winner.

The BEC me_epp field is a self-declaration at bid time of whether the firm
is claiming ME (microempresa) or EPP (empresa de pequeno porte) status
under LC 123/2006. Because SME classification is effectively a firm-level
characteristic (based on annual revenue thresholds), the modal me_epp value
across a firm's appearances should be a very good proxy for the canonical
policy-relevant SME indicator.

Output: /tmp/p2_cnpj_me_epp.parquet
   Columns: cnpj, n_wins_observed, pct_sme_declared, sme_canonical
Runtime: ~55s on the workstation.
"""
import csv
import sys
import time
from collections import defaultdict
import pyarrow as pa
import pyarrow.parquet as pq

csv.field_size_limit(sys.maxsize)

SRC = "/home/darciogm1/projetos/bitter-pills/paper2-me-epp/data/raw/Paper2_ME_EPP.csv"
DST = "/tmp/p2_cnpj_me_epp.parquet"

def main() -> None:
    t0 = time.time()
    cnpj_totals = defaultdict(lambda: [0, 0])  # cnpj -> [n_obs, n_sme]

    with open(SRC, encoding="utf-8", newline="", errors="replace") as f:
        r = csv.reader(f, delimiter=";")
        header = next(r)
        # BEC supplier code: "códigofornecedor" (UTF-8 encoded). This is
        # the key that matches `códigofornecedor` in paper 3's bid-level
        # parquet — a 14-digit identifier populated from each supplier's
        # CNPJ for non-pessoa-física cases.
        i_cnpj  = header.index("códigofornecedor")
        i_me    = header.index("me_epp")
        print(f"Columns located: códigofornecedor={i_cnpj}, me_epp={i_me}")

        n = 0
        for row in r:
            n += 1
            cnpj = row[i_cnpj].strip() if len(row) > i_cnpj else ""
            me   = row[i_me].strip()   if len(row) > i_me   else ""
            if not cnpj:
                continue
            try:
                me_val = int(me) if me else None
            except ValueError:
                me_val = None
            if me_val is None:
                continue
            cnpj_totals[cnpj][0] += 1
            if me_val == 1:
                cnpj_totals[cnpj][1] += 1
            if n % 500_000 == 0:
                print(f"  scanned {n/1e6:.1f}M rows, {len(cnpj_totals):,} CNPJs  "
                      f"[{time.time()-t0:.1f}s]")

    print(f"Total scanned: {n/1e6:.2f}M rows, {len(cnpj_totals):,} CNPJs  "
          f"[{time.time()-t0:.1f}s]")

    cnpjs, n_obs_l, pct_sme_l, sme_canon_l = [], [], [], []
    for cnpj, (nobs, nsme) in cnpj_totals.items():
        cnpjs.append(cnpj)
        n_obs_l.append(nobs)
        pct = nsme / nobs if nobs else 0.0
        pct_sme_l.append(pct)
        sme_canon_l.append(1 if pct > 0.5 else 0)

    tbl = pa.table({
        "cnpj":              cnpjs,
        "n_wins_observed":   n_obs_l,
        "pct_sme_declared":  pct_sme_l,
        "sme_canonical":     sme_canon_l,
    })
    pq.write_table(tbl, DST, compression="snappy")
    print(f"Wrote {DST}: {len(cnpjs):,} unique CNPJs")

    # Quick diagnostics
    n_sme = sum(sme_canon_l)
    n_always_sme = sum(1 for p in pct_sme_l if p == 1.0)
    n_never_sme = sum(1 for p in pct_sme_l if p == 0.0)
    n_mixed = len(pct_sme_l) - n_always_sme - n_never_sme
    print(f"  Canonical SME = 1 (majority declared SME): {n_sme:,} "
          f"({100*n_sme/len(cnpjs):.1f}%)")
    print(f"  Always SME (pct=100%):  {n_always_sme:,}")
    print(f"  Never SME (pct=0%):     {n_never_sme:,}")
    print(f"  Mixed:                  {n_mixed:,}")

if __name__ == "__main__":
    main()
