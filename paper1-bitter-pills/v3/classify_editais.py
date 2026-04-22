#!/usr/bin/env python3
"""
Classify edital text files as judicial, administrative, or ordinary procurement.

Reads all edital .txt files from a directory and outputs a CSV with columns:
  - po: Purchase Order number (extracted from filename)
  - judicial: 1 if judicial procurement, 0 otherwise
  - administrativo: 1 if administrative procurement, 0 otherwise

Classification is based on keyword matching in the edital text content,
focusing on the delivery location (Local de entrega) and object description
sections, while excluding standard legal boilerplate.

Usage:
    python3 classify_editais.py [input_dir] [output_csv]

    Defaults:
        input_dir:  /tmp/editais
        output_csv: /home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/v3/results/editais_classificados.csv
"""

import os
import re
import csv
import sys
from pathlib import Path


# Judicial keywords
# These patterns indicate judicial procurement (ação judicial, mandado de segurança, etc.)
JUDICIAL_PATTERNS = [
    r'a[çc][ãa]o\s+judicial',          # ação judicial / acao judicial
    r'a[çc][õo]es\s+judicia',          # ações judiciais / acoes judiciais
    r'demanda[s]?\s+judicia',           # demanda judicial / demandas judiciais
    r'mandado\s+de\s+seguran[çc]a',    # mandado de segurança
    r'determina[çc][ãa]o\s+judicial',  # determinação judicial
    r'ordem\s+judicial',                # ordem judicial
    r'atender.*judicial',               # atender ... judicial
    r'judicial.*atender',               # judicial ... atender
    r'[-\s]A\s+JUDICIAL\b',            # abbreviated "A JUDICIAL" (= Ação Judicial)
]

# Compile combined judicial pattern (case-insensitive)
JUDICIAL_RE = re.compile('|'.join(JUDICIAL_PATTERNS), re.IGNORECASE)

# Administrative keywords
# These patterns indicate administrative (non-judicial, non-ordinary) procurement
ADMIN_PATTERNS = [
    r'demanda[s]?\s+administrat',       # demanda administrativa / demandas administrativas
    r'solicita[çc][ãa]o\s+administrat', # solicitação administrativa
    r'solicita[çc][õo]es\s+administrat',# solicitações administrativas
    r'via\s+administrat',               # via administrativa
    r'compra\s+administrat',            # compra administrativa
]

ADMIN_RE = re.compile('|'.join(ADMIN_PATTERNS), re.IGNORECASE)

# Boilerplate exclusion
# Lines containing these patterns are legal boilerplate and should be excluded
# from admin keyword matching (they contain "administrativa" in a non-procurement context)
BOILERPLATE_PATTERNS = [
    r'san[çc][õo]es\s+administrat',     # Sanções Administrativas
    r'rescis[ãa]o\s+administrat',       # rescisão administrativa
    r'artigo',                           # legal article references
    r'poder\s+judici',                   # Poder Judiciário (institutional name)
    r'contencioso\s+administrat',       # contencioso administrativo
    r'processo\s+administrat',          # processo administrativo (legal procedure)
]

BOILERPLATE_RE = re.compile('|'.join(BOILERPLATE_PATTERNS), re.IGNORECASE)


def extract_po_from_filename(filename: str) -> str:
    """Extract Purchase Order number from filename like '090139000012013OC00013_edital.txt'."""
    return filename.replace('_edital.txt', '').replace('.txt', '')


def classify_edital(filepath: str) -> tuple:
    """
    Classify an edital file as judicial, administrative, or ordinary.

    Returns:
        (judicial: int, administrativo: int, judicial_evidence: str, admin_evidence: str)
    """
    try:
        # Try multiple encodings
        content = None
        for encoding in ['utf-8', 'latin-1', 'cp1252']:
            try:
                with open(filepath, 'r', encoding=encoding) as f:
                    content = f.read()
                break
            except UnicodeDecodeError:
                continue

        if content is None:
            return (0, 0, '', '')

        # --- Judicial classification ---
        judicial = 0
        judicial_evidence = ''

        # Exclude institution names that contain "judicial" but are not judicial procurement
        EXCLUDE_JUDICIAL_RE = re.compile(r'PROCUR\.?\s*JUDICIAL', re.IGNORECASE)

        for match in JUDICIAL_RE.finditer(content):
            # Extract context around the match
            start = max(0, match.start() - 80)
            end = min(len(content), match.end() + 80)
            context = content[start:end].strip()
            context = re.sub(r'\s+', ' ', context)
            # Skip if the match is part of an institution name
            if EXCLUDE_JUDICIAL_RE.search(context):
                continue
            judicial = 1
            judicial_evidence = context[:200]
            break

        # --- Administrative classification ---
        administrativo = 0
        admin_evidence = ''

        # Split content into lines and check each for admin keywords,
        # excluding boilerplate lines
        for line in content.split('\n'):
            if ADMIN_RE.search(line) and not BOILERPLATE_RE.search(line):
                administrativo = 1
                admin_evidence = re.sub(r'\s+', ' ', line.strip())[:200]
                break

        return (judicial, administrativo, judicial_evidence, admin_evidence)

    except Exception as e:
        print(f"  Error reading {filepath}: {e}", file=sys.stderr)
        return (0, 0, '', f'ERROR: {e}')


def main():
    input_dir = sys.argv[1] if len(sys.argv) > 1 else '/tmp/editais'
    output_csv = sys.argv[2] if len(sys.argv) > 2 else \
        '/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/v3/results/editais_classificados.csv'

    # Ensure output directory exists
    os.makedirs(os.path.dirname(output_csv), exist_ok=True)

    # Get all edital files
    files = sorted([f for f in os.listdir(input_dir) if f.endswith('_edital.txt')])
    print(f"Found {len(files)} edital files in {input_dir}")

    results = []
    judicial_count = 0
    admin_count = 0

    for i, filename in enumerate(files):
        if (i + 1) % 1000 == 0:
            print(f"  Processing {i+1}/{len(files)}...")

        po = extract_po_from_filename(filename)
        filepath = os.path.join(input_dir, filename)
        judicial, administrativo, jud_evidence, adm_evidence = classify_edital(filepath)

        results.append({
            'po': po,
            'judicial': judicial,
            'administrativo': administrativo,
            'evidencia_judicial': jud_evidence,
            'evidencia_administrativo': adm_evidence,
        })

        judicial_count += judicial
        admin_count += administrativo

    # Write CSV
    with open(output_csv, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=['po', 'judicial', 'administrativo',
                                                'evidencia_judicial', 'evidencia_administrativo'])
        writer.writeheader()
        writer.writerows(results)

    print(f"\nClassification complete:")
    print(f"  Total editais: {len(results)}")
    print(f"  Judicial: {judicial_count} ({100*judicial_count/len(results):.1f}%)")
    print(f"  Administrativo: {admin_count} ({100*admin_count/len(results):.1f}%)")
    print(f"  Ordinário: {len(results) - judicial_count - admin_count}")
    print(f"\nOutput saved to: {output_csv}")

    # Print details of classified files
    if judicial_count > 0:
        print(f"\n--- Judicial files ({judicial_count}) ---")
        for r in results:
            if r['judicial'] == 1:
                print(f"  {r['po']}: {r['evidencia_judicial']}")

    if admin_count > 0:
        print(f"\n--- Administrativo files ({admin_count}) ---")
        for r in results:
            if r['administrativo'] == 1:
                print(f"  {r['po']}: {r['evidencia_administrativo']}")


if __name__ == '__main__':
    main()
