#!/usr/bin/env python3
"""
68_promote_rais_to_v2.py
========================

Promote the 7 RAIS-confirmed CADE matches to a v2 enriched CSV that
feeds linkage_v2. Manual review (cf. 67_rais_enrich.py output)
identified 7 of 15 unmatched CADE rows that have a defensible RAIS
match. The other 8 are either ambiguous (Frontal Group), confirmed
false positives (Astéria, Matrix, Visaplas, Rhamis, Delícias da Vovó SP,
Ventana BA, CAF MG), or impossible to pin (firms that left RAIS
before 2015).

Inputs
------
- data/processed_comprasnet/cade_link_v1/cnpjs_enriched.csv

Output
------
- data/processed_comprasnet/cade_link_v2/cnpjs_enriched.csv
  Same as v1 plus 7 new bec_reuse-or-rais rows with enrich_source
  set to 'rais_v2_manual' and enrich_score from the RAIS audit.

Promoted matches (hand-curated after running 67_rais_enrich.py):
  Tejofran                61288437 (UF SP, score 1.0)
  Plasticos Santa Clara   13708382 (UF SP, score 1.0)
  LSV                     96184858 (UF SP, score 1.0)
  Dimaci SP               05847630 (UF SP, score 0.943, name variant ok)
  Convida Alimentacao     48865828 (UF SP, score 0.905, also in BEC crossmatch)
  Drogafonte              08778201 (UF PE, operates national)
  Siemens                 44013159 (multi-UF, BR main entity)
"""

import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "data/processed_comprasnet/cade_link_v1/cnpjs_enriched.csv"
DST = ROOT / "data/processed_comprasnet/cade_link_v2/cnpjs_enriched.csv"

PROMOTIONS = {
    # cade_idx (from cnpjs_enriched.csv) -> (cnpj14, cnpj_raiz, source, score)
    "16": ("61288437000248", "61288437", "rais_v2_manual", 1.0),    # Tejofran
    "54": ("13708382000154", "13708382", "rais_v2_manual", 1.0),    # Plasticos Santa Clara
    "55": ("96184858000122", "96184858", "rais_v2_manual", 1.0),    # LSV
    "58": ("05847630000110", "05847630", "rais_v2_manual", 0.943),  # Dimaci SP
    "4":  ("48865828002506", "48865828", "rais_v2_manual", 0.905),  # Convida
    "59": ("08778201000100", "08778201", "rais_v2_manual_direct", 1.0),  # Drogafonte
    "19": ("44013159000123", "44013159", "rais_v2_manual_direct", 1.0),  # Siemens Ltda
}


def main() -> None:
    DST.parent.mkdir(parents=True, exist_ok=True)

    with SRC.open(encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    fields = list(rows[0].keys())

    promoted = 0
    for row in rows:
        idx = row.get("cade_idx", "")
        if idx in PROMOTIONS:
            cnpj14, raiz, src, score = PROMOTIONS[idx]
            row["cnpj14"] = cnpj14
            row["cnpj_raiz_enriched"] = raiz
            row["enrich_source"] = src
            row["enrich_score"] = score
            promoted += 1

    with DST.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)
    print(f"  promoted {promoted} rows; wrote {DST}")


if __name__ == "__main__":
    main()
