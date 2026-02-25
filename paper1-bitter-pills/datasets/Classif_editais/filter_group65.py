#!/usr/bin/env python3
"""
Filter classified editais to Group 65 items only (all secretarias).

Streams all 7 archives to collect OCs with CD_CLASSE_ITEM starting with "65",
then joins with the full classification from output_classificacao.parquet.

Output: group65_classificacao.parquet at item level with classification columns
including a derived purchase_type (0=Normal, 1=Administrativo, 2=Judicial).

Usage:
    python3 filter_group65.py
"""

import os
import sys
import json
import tarfile
import zipfile
import time
import logging
from pathlib import Path
from collections import defaultdict

import pyarrow as pa
import pyarrow.parquet as pq

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
OUTPUT_PARQUET = BASE_DIR / 'group65_classificacao.parquet'

GROUP_65_PREFIX = '65'

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')
log = logging.getLogger(__name__)


def decode_bytes(data: bytes) -> str:
    for enc in ('utf-8', 'latin-1', 'cp1252'):
        try:
            return data.decode(enc)
        except (UnicodeDecodeError, ValueError):
            continue
    return data.decode('latin-1', errors='replace')


def extract_oc(filename: str) -> str:
    return os.path.basename(filename).replace('_edital.txt', '').replace('.txt', '')


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
                if zf.getinfo(name).is_dir():
                    continue
                try:
                    yield (name, zf.read(name))
                except Exception:
                    continue


def main():
    t0 = time.time()

    # Load full classification
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

    # Stream archives: collect group-65 items and metadata per OC
    oc_items = defaultdict(list)
    oc_meta = {}

    for archive_path, archive_type in ARCHIVE_SPECS:
        if not archive_path.exists():
            log.warning("Skipping missing archive: %s", archive_path)
            continue
        log.info("Processing %s...", archive_path.name)

        for filename, data in iter_archive(archive_path, archive_type):
            if not filename.endswith('.txt') or '_edital.txt' in filename:
                continue

            oc = extract_oc(filename)
            text = decode_bytes(data)
            try:
                jdata = json.loads(text)
            except (json.JSONDecodeError, ValueError):
                continue
            if not isinstance(jdata, dict):
                continue

            if oc not in oc_meta:
                oc_meta[oc] = {
                    'municipio': jdata.get('MUNICIPIO', ''),
                    'unidade_compradora': jdata.get('UNIDADE_COMPRADORA', ''),
                    'modalidade': jdata.get('MODALIDADE', ''),
                }

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

    log.info("OCs with group-65 items: %d", len(oc_items))

    # Build item-level output
    rows = {
        'purchase_order': [],
        'dummy_judicial': [],
        'dummy_admin': [],
        'purchase_type': [],   # 0=Normal, 1=Administrativo, 2=Judicial
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

    for oc in sorted(oc_items.keys()):
        jud, adm = classif.get(oc, (0, 0))
        # purchase_type: judicial takes priority
        if jud == 1:
            ptype = 2
        elif adm == 1:
            ptype = 1
        else:
            ptype = 0

        meta = oc_meta.get(oc, {})
        for item in oc_items[oc]:
            rows['purchase_order'].append(oc)
            rows['dummy_judicial'].append(jud)
            rows['dummy_admin'].append(adm)
            rows['purchase_type'].append(ptype)
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

    out_table = pa.table({
        'purchase_order': rows['purchase_order'],
        'dummy_judicial': pa.array(rows['dummy_judicial'], type=pa.int8()),
        'dummy_admin': pa.array(rows['dummy_admin'], type=pa.int8()),
        'purchase_type': pa.array(rows['purchase_type'], type=pa.int8()),
        'municipio': rows['municipio'],
        'unidade_compradora': rows['unidade_compradora'],
        'modalidade': rows['modalidade'],
        'nr_sequencia_item': rows['nr_sequencia_item'],
        'cd_item': rows['cd_item'],
        'cd_classe_item': rows['cd_classe_item'],
        'descricao_classe': rows['descricao_classe'],
        'descricao_item': rows['descricao_item'],
        'unidade_fornecimento': rows['unidade_fornecimento'],
        'quantidade': rows['quantidade'],
    })
    pq.write_table(out_table, str(OUTPUT_PARQUET))

    # Stats
    n_items = len(rows['purchase_order'])
    n_ocs = len(oc_items)
    from collections import Counter
    ptype_counts = Counter(rows['purchase_type'])
    oc_ptypes = {}
    for oc in oc_items:
        j, a = classif.get(oc, (0, 0))
        oc_ptypes[oc] = 2 if j == 1 else (1 if a == 1 else 0)
    oc_ptype_counts = Counter(oc_ptypes.values())

    elapsed = time.time() - t0
    log.info("=" * 60)
    log.info("OUTPUT: %s", OUTPUT_PARQUET)
    log.info("  OCs:   %d", n_ocs)
    log.info("  Items: %d (rows in parquet)", n_items)
    log.info("")
    log.info("  Nível item:")
    log.info("    Judicial (2):       %d (%.2f%%)", ptype_counts[2], 100 * ptype_counts[2] / n_items)
    log.info("    Administrativo (1): %d (%.2f%%)", ptype_counts[1], 100 * ptype_counts[1] / n_items)
    log.info("    Normal (0):         %d (%.2f%%)", ptype_counts[0], 100 * ptype_counts[0] / n_items)
    log.info("")
    log.info("  Nível OC:")
    log.info("    Judicial (2):       %d (%.2f%%)", oc_ptype_counts[2], 100 * oc_ptype_counts[2] / n_ocs)
    log.info("    Administrativo (1): %d (%.2f%%)", oc_ptype_counts[1], 100 * oc_ptype_counts[1] / n_ocs)
    log.info("    Normal (0):         %d (%.2f%%)", oc_ptype_counts[0], 100 * oc_ptype_counts[0] / n_ocs)
    log.info("")
    log.info("  Time: %.1f min", elapsed / 60)


if __name__ == '__main__':
    main()
