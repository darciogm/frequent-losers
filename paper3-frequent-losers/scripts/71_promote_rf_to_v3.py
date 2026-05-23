#!/usr/bin/env python3
"""
71_promote_rf_to_v3.py
======================

Promote 4 RF-confirmed CADE matches to a v3 enriched CSV.
Manual review of `cnpjs_rf_candidates.csv` identified 4 high-
confidence matches; 4 others rejected (Astéria, Matrix, Delícias
da Vovó SP, Frontal Group) due to ambiguity.

Inputs
------
- data/processed_comprasnet/cade_link_v2/cnpjs_enriched.csv

Output
------
- data/processed_comprasnet/cade_link_v3/cnpjs_enriched.csv
"""

import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "data/processed_comprasnet/cade_link_v2/cnpjs_enriched.csv"
DST = ROOT / "data/processed_comprasnet/cade_link_v3/cnpjs_enriched.csv"

# cade_idx -> (cnpj14, cnpj_raiz, source, score)
PROMOTIONS = {
    "56": ("08505363000110", "08505363", "rf_v3_manual", 1.0),    # Visaplas (literal name match)
    "62": ("07524484000100", "07524484", "rf_v3_manual", 1.0),    # Rhamis (literal name match)
    "10": ("14689798000100", "14689798", "rf_v3_manual_caution", 1.0),  # CAF (name without "Brasil"; marked caution)
    "29": ("05424351000110", "05424351", "rf_v3_manual_caution", 1.0),  # Ventana (BA per RAIS; Infraero multi-UF)
    "34": ("01140694000100", "01140694", "rf_v3_cade_pdf", 1.0),  # Frontal Group: 1 of 2 firms identified via CADE PDF search + RF -- "Frontal Ind e Com de Moveis Hospitalares Ltda" (cartel UMS/Sanguessuga)
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
