#!/usr/bin/env python3
"""
Filter classified editais to SES (Secretaria da Saúde) + Group 65 items only.

Reads the full classification from output_classificacao.parquet, then streams
through all 7 archives to identify:
  1. SES editais: edital HTML contains "SECRETARIA DA SAUDE" in the ORGAO field
  2. Group 65 items: JSON metadata has ITENS with CD_CLASSE_ITEM starting with "65"

Outputs a Parquet at item level: one row per (OC, item) pair that satisfies both
filters, with the OC-level judicial/admin classification attached.

Usage:
    python3 filter_ses_group65.py
"""

import os
import sys
import re
import json
import tarfile
import zipfile
import time
import logging
from pathlib import Path
from collections import defaultdict

import pyarrow as pa
import pyarrow.parquet as pq

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

BASE_DIR = Path(__file__).resolve().parent

ARCHIVE_SPECS = [
    (BASE_DIR / 'data01.gz',  'tar'),
    (BASE_DIR / 'data02.gz',  'tar'),
    (BASE_DIR / 'data03.gz',  'tar'),
    (BASE_DIR / 'data04.zip', 'zip'),
    (BASE_DIR / 'data05.zip', 'zip'),
    (BASE_DIR / 'data06.gz',  'tar'),
    (BASE_DIR / 'data07.gz',  'tar'),
]

INPUT_PARQUET  = BASE_DIR / 'output_classificacao.parquet'
OUTPUT_PARQUET = BASE_DIR / 'ses_group65_classificacao.parquet'

SES_PATTERN = re.compile(r'SECRETARIA\s+DA\s+SA[UÚ]DE', re.IGNORECASE)
GROUP_65_PREFIX = '65'

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(message)s',
)
log = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def decode_bytes(data: bytes) -> str:
    for enc in ('utf-8', 'latin-1', 'cp1252'):
        try:
            return data.decode(enc)
        except (UnicodeDecodeError, ValueError):
            continue
    return data.decode('latin-1', errors='replace')


def extract_oc(filename: str) -> str:
    base = os.path.basename(filename)
    return base.replace('_edital.txt', '').replace('.txt', '')


def iter_archive(archive_path: Path, archive_type: str):
    if archive_type == 'tar':
        with tarfile.open(str(archive_path), 'r:gz') as tar:
            for member in tar:
                if not member.isfile():
                    continue
                try:
                    fobj = tar.extractfile(member)
                    if fobj is None:
                        continue
                    yield (member.name, fobj.read())
                except Exception:
                    continue
    elif archive_type == 'zip':
        with zipfile.ZipFile(str(archive_path), 'r') as zf:
            for name in zf.namelist():
                info = zf.getinfo(name)
                if info.is_dir():
                    continue
                try:
                    yield (name, zf.read(name))
                except Exception:
                    continue


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    t0 = time.time()

    # Load existing classification
    log.info("Loading classification from %s", INPUT_PARQUET)
    table = pq.read_table(INPUT_PARQUET)
    classif = {}
    for oc, jud, adm in zip(
        table['purchase_order'].to_pylist(),
        table['dummy_judicial'].to_pylist(),
        table['dummy_admin'].to_pylist(),
    ):
        classif[oc] = (jud, adm)
    log.info("Loaded %d OC classifications", len(classif))

    # Stream archives: collect SES flag and group-65 items per OC
    ses_ocs = set()          # OCs identified as SES
    oc_items = defaultdict(list)  # OC -> list of group-65 item dicts
    oc_meta = {}             # OC -> {municipio, unidade_compradora, modalidade}

    total_files = 0
    total_editais = 0
    total_jsons = 0

    for archive_path, archive_type in ARCHIVE_SPECS:
        if not archive_path.exists():
            log.warning("Skipping missing archive: %s", archive_path)
            continue
        log.info("Processing %s...", archive_path.name)

        for filename, data in iter_archive(archive_path, archive_type):
            if not filename.endswith('.txt'):
                continue
            total_files += 1
            oc = extract_oc(filename)

            if '_edital.txt' in filename:
                total_editais += 1
                text = decode_bytes(data)[:5000]
                if SES_PATTERN.search(text):
                    ses_ocs.add(oc)
            else:
                total_jsons += 1
                text = decode_bytes(data)
                try:
                    jdata = json.loads(text)
                except (json.JSONDecodeError, ValueError):
                    continue
                if not isinstance(jdata, dict):
                    continue

                # Store metadata
                if oc not in oc_meta:
                    oc_meta[oc] = {
                        'municipio': jdata.get('MUNICIPIO', ''),
                        'unidade_compradora': jdata.get('UNIDADE_COMPRADORA', ''),
                        'modalidade': jdata.get('MODALIDADE', ''),
                    }

                # Collect group-65 items
                for item in jdata.get('ITENS', []):
                    cd_classe = item.get('CD_CLASSE_ITEM', '')
                    if cd_classe.startswith(GROUP_65_PREFIX):
                        oc_items[oc].append({
                            'nr_sequencia_item': item.get('NR_SEQUENCIA_ITEM', ''),
                            'cd_item': item.get('CD_ITEM', ''),
                            'cd_classe_item': cd_classe,
                            'descricao_classe': item.get('DESCRICAO_CLASSE', ''),
                            'descricao_item': item.get('DESCRICAO_ITEM', ''),
                            'unidade_fornecimento': item.get('UNIDADE_FORNECIMENTO', ''),
                            'quantidade': item.get('QUANTIDADE', ''),
                        })

    log.info("Scan complete: %d files (%d editais, %d JSONs)", total_files, total_editais, total_jsons)
    log.info("SES editais: %d OCs", len(ses_ocs))
    log.info("OCs with group-65 items: %d", len(oc_items))

    # Intersect: SES + group 65
    ses_g65_ocs = ses_ocs & set(oc_items.keys())
    log.info("SES + group 65: %d OCs", len(ses_g65_ocs))

    # Build item-level output
    rows = {
        'purchase_order': [],
        'dummy_judicial': [],
        'dummy_admin': [],
        'municipio': [],
        'unidade_compradora': [],
        'modalidade': [],
        'nr_sequencia_item': [],
        'cd_item': [],
        'cd_classe_item': [],
        'descricao_classe': [],
        'descricao_item': [],
        'unidade_fornecimento': [],
        'quantidade': [],
    }

    for oc in sorted(ses_g65_ocs):
        jud, adm = classif.get(oc, (0, 0))
        meta = oc_meta.get(oc, {})

        for item in oc_items[oc]:
            rows['purchase_order'].append(oc)
            rows['dummy_judicial'].append(jud)
            rows['dummy_admin'].append(adm)
            rows['municipio'].append(meta.get('municipio', ''))
            rows['unidade_compradora'].append(meta.get('unidade_compradora', ''))
            rows['modalidade'].append(meta.get('modalidade', ''))
            rows['nr_sequencia_item'].append(item['nr_sequencia_item'])
            rows['cd_item'].append(item['cd_item'])
            rows['cd_classe_item'].append(item['cd_classe_item'])
            rows['descricao_classe'].append(item['descricao_classe'])
            rows['descricao_item'].append(item['descricao_item'])
            rows['unidade_fornecimento'].append(item['unidade_fornecimento'])
            rows['quantidade'].append(item['quantidade'])

    out_table = pa.table(rows)
    pq.write_table(out_table, str(OUTPUT_PARQUET))

    n_items = len(rows['purchase_order'])
    n_ocs = len(ses_g65_ocs)
    n_jud = sum(1 for oc in ses_g65_ocs if classif.get(oc, (0,0))[0] == 1)
    n_adm = sum(1 for oc in ses_g65_ocs if classif.get(oc, (0,0))[1] == 1)

    elapsed = time.time() - t0
    log.info("=" * 60)
    log.info("OUTPUT: %s", OUTPUT_PARQUET)
    log.info("  OCs:      %d", n_ocs)
    log.info("  Items:    %d (rows in parquet)", n_items)
    log.info("  Judicial: %d OCs (%.2f%%)", n_jud, 100 * n_jud / n_ocs if n_ocs else 0)
    log.info("  Admin:    %d OCs (%.2f%%)", n_adm, 100 * n_adm / n_ocs if n_ocs else 0)
    log.info("  Time:     %.1f min", elapsed / 60)


if __name__ == '__main__':
    main()
