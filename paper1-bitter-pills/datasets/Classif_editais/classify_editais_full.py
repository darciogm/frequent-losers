#!/usr/bin/env python3
"""
Full classification pipeline for ~2.4M editais from BEC/SP.

Classifies each purchase order (OC) as:
  - Judicial (court-mandated procurement)
  - Administrative (non-judicial urgent procurement)
  - Ordinary (default, neither judicial nor administrative)

Uses 4 classification strategies combined via weighted voting:
  1. Regex pattern matching on edital HTML text
  2. TF-IDF + LinearSVC trained on ground-truth labels
  3. Positional heuristics (delivery location, first 500 chars)
  4. JSON metadata (MUNICIPIO field)

Usage:
    python3 classify_editais_full.py [--phase N] [--skip-ml] [--test-only]

    --phase N    Run only phase N (0=setup, 1=train ML, 2=test 10K, 3=full, 4=output)
    --skip-ml    Skip ML training, use only regex/metadata/positional
    --test-only  Run phases 0-2 only (setup + train + test on 10K)
"""

import os
import sys
import re
import csv
import json
import gzip
import tarfile
import zipfile
import io
import time
import logging
import argparse
import pickle
import random
from pathlib import Path
from collections import defaultdict

# ---------------------------------------------------------------------------
# Lazy imports for ML / progress (installed in Phase 0 if missing)
# ---------------------------------------------------------------------------

def ensure_dependencies():
    """Install missing dependencies."""
    required = {'scikit-learn': 'sklearn', 'tqdm': 'tqdm', 'pyarrow': 'pyarrow'}
    missing = []
    for pkg, imp in required.items():
        try:
            __import__(imp)
        except ImportError:
            missing.append(pkg)
    if missing:
        import subprocess
        print(f"Installing missing packages: {', '.join(missing)}")
        cmd = [sys.executable, '-m', 'pip', 'install', '--quiet'] + missing
        try:
            subprocess.check_call(cmd)
        except subprocess.CalledProcessError:
            # Retry with --break-system-packages for PEP 668 environments
            subprocess.check_call(cmd[:4] + ['--break-system-packages'] + missing)


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

BASE_DIR = Path(__file__).resolve().parent
GROUND_TRUTH_CSV = BASE_DIR / 'VARS_JUD_COMPLETA.csv'
REGEX_CSV = BASE_DIR / 'regex_bec_editais_saude.csv'

ARCHIVE_SPECS = [
    (BASE_DIR / 'data01.gz',  'tar.gz', 'tar'),
    (BASE_DIR / 'data02.gz',  'tar.gz', 'tar'),
    (BASE_DIR / 'data03.gz',  'tar.gz', 'tar'),
    (BASE_DIR / 'data04.zip', 'zip',    'zip'),
    (BASE_DIR / 'data05.zip', 'zip',    'zip'),
    (BASE_DIR / 'data06.gz',  'tar.gz', 'tar'),
    (BASE_DIR / 'data07.gz',  'tar.gz', 'tar'),
]

OUTPUT_PARQUET = BASE_DIR / 'output_classificacao.parquet'
OUTPUT_REPORT  = BASE_DIR / 'classification_report.txt'
OUTPUT_SAMPLE  = BASE_DIR / 'sample_1000.csv'
OUTPUT_ERRORS  = BASE_DIR / 'errors.log'
ML_MODEL_PATH  = BASE_DIR / 'ml_model.pkl'

MAX_TEXT_LEN = 5000          # chars to read from edital HTML
ML_BATCH_SIZE = 50_000       # batch size for ML inference
TFIDF_MAX_FEATURES = 20_000

# Weighted voting
# ML is the primary classifier (trained on 170K labeled texts, F1>0.93).
# Regex is demoted to supplementary: it matches "AÇÕES JUDICIAIS" in admin
# delivery addresses, causing massive false positives on admin-only OCs.
# JSON metadata is highly precise when present (MUNICIPIO field).
W_ML       = 3  # primary signal (learned nuanced label distinctions)
W_JSON     = 3  # highly precise when present
W_REGEX    = 1  # supplementary (too many judicial FPs on admin OCs)
W_POSITION = 1  # supplementary (same issue as regex)
VOTE_THRESHOLD = 2  # minimum weighted sum to classify as positive


# ---------------------------------------------------------------------------
# Regex patterns (expanded from v3/classify_editais.py)
# ---------------------------------------------------------------------------

JUDICIAL_PATTERNS = [
    # Original v3 patterns
    r'a[çc][ãa]o\s+judicial',
    r'a[çc][õo]es\s+judicia',
    r'demanda[s]?\s+judicia',
    r'mandado\s+de\s+seguran[çc]a',
    r'determina[çc][ãa]o\s+judicial',
    r'ordem\s+judicial',
    r'atender.*judicial',
    r'judicial.*atender',
    r'[-\s]A\s+JUDICIAL\b',
    # Additional patterns
    r'tutela\s+(?:antecipada|de\s+urg[êe]ncia)',
    r'liminar',
    r'cumprimento\s+de\s+senten[çc]a',
    r'of[ií]cio\s+judicial',
    r'juizado\s+especial',
    r'decis[ãa]o\s+judicial',
    r'medida\s+(?:cautelar|judicial)',
    r'obriga[çc][ãa]o\s+de\s+fazer',
    r'cita[çc][ãa]o\s+judicial',
]

ADMIN_PATTERNS = [
    # Original v3 patterns
    r'demanda[s]?\s+administrat',
    r'solicita[çc][ãa]o\s+administrat',
    r'solicita[çc][õo]es\s+administrat',
    r'via\s+administrat',
    r'compra\s+administrat',
    # Additional patterns
    r'pedido\s+administrat',
    r'requerimento\s+administrat',
    r'aquisi[çc][ãa]o\s+administrat',
    r'fornecimento\s+administrat',
    r'provid[êe]ncia\s+administrat',
    r'atendimento\s+administrat',
    r'demanda\s+administrativa\s+n[ºo°]',
]

# Boilerplate exclusions (false positives for "administrativa")
BOILERPLATE_PATTERNS = [
    r'san[çc][õo]es\s+administrat',
    r'rescis[ãa]o\s+administrat',
    r'artigo',
    r'poder\s+judici',
    r'contencioso\s+administrat',
    r'processo\s+administrat',
    r'infra[çc][ãa]o\s+administrat',
    r'recurso\s+administrat',
    r'lei\s+(?:federal|estadual)',
    r'penalidade',
]

# Exclusion for judicial false positives
EXCLUDE_JUDICIAL_PATTERNS = [
    r'PROCUR\.?\s*JUDICIAL',
    r'assessoria\s+jur[ií]dica',
]

JUDICIAL_RE = re.compile('|'.join(JUDICIAL_PATTERNS), re.IGNORECASE)
ADMIN_RE = re.compile('|'.join(ADMIN_PATTERNS), re.IGNORECASE)
BOILERPLATE_RE = re.compile('|'.join(BOILERPLATE_PATTERNS), re.IGNORECASE)
EXCLUDE_JUDICIAL_RE = re.compile('|'.join(EXCLUDE_JUDICIAL_PATTERNS), re.IGNORECASE)

# JSON metadata patterns (for MUNICIPIO field)
JSON_JUDICIAL_RE = re.compile(
    r'(?:A[ÇC][ÃA]O|DEMANDA|MANDADO|DETERMINA[ÇC][ÃA]O|ORDEM)\s+JUDICIAL'
    r'|MANDADO\s+DE\s+SEGURAN[ÇC]A'
    r'|TUTELA\s+(?:ANTECIPADA|URG[ÊE]NCIA)'
    r'|LIMINAR'
    r'|JUDICIAL',
    re.IGNORECASE
)
JSON_ADMIN_RE = re.compile(
    r'(?:DEMANDA|SOLICITA[ÇC][ÃA]O|VIA|COMPRA|PEDIDO)\s+ADMINISTRAT',
    re.IGNORECASE
)


# ---------------------------------------------------------------------------
# Setup logging
# ---------------------------------------------------------------------------

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(str(OUTPUT_ERRORS), mode='w', encoding='utf-8'),
    ]
)
log = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Helper: decode bytes with fallback chain
# ---------------------------------------------------------------------------

def decode_bytes(data: bytes) -> str:
    """Decode bytes trying UTF-8, then latin-1, then cp1252."""
    for enc in ('utf-8', 'latin-1', 'cp1252'):
        try:
            return data.decode(enc)
        except (UnicodeDecodeError, ValueError):
            continue
    return data.decode('latin-1', errors='replace')


# ---------------------------------------------------------------------------
# Helper: extract OC from filename
# ---------------------------------------------------------------------------

def extract_oc(filename: str) -> str:
    """Extract purchase order code from filename like '257/180187000012014OC01377_edital.txt'."""
    base = os.path.basename(filename)
    return base.replace('_edital.txt', '').replace('.txt', '')


# ---------------------------------------------------------------------------
# Phase 0: Load ground truth
# ---------------------------------------------------------------------------

def load_ground_truth() -> dict:
    """Load VARS_JUD_COMPLETA.csv → {oc: (dummy_201, dummy_202)}."""
    labels = {}
    with open(GROUND_TRUTH_CSV, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f, delimiter=';')
        for row in reader:
            oc = row['oc'].strip()
            jud = int(row['dummy_201'])
            adm = int(row['dummy_202'])
            labels[oc] = (jud, adm)
    log.info(f"Ground truth loaded: {len(labels)} OCs "
             f"(judicial={sum(v[0] for v in labels.values())}, "
             f"admin={sum(v[1] for v in labels.values())})")
    return labels


# ---------------------------------------------------------------------------
# Archive streaming: yield (filename, bytes) from all archives
# ---------------------------------------------------------------------------

def iter_archive(archive_path: Path, archive_type: str):
    """Yield (filename, raw_bytes) for each file in an archive."""
    if archive_type == 'tar':
        with tarfile.open(str(archive_path), 'r:gz') as tar:
            for member in tar:
                if not member.isfile():
                    continue
                try:
                    fobj = tar.extractfile(member)
                    if fobj is None:
                        continue
                    data = fobj.read()
                    yield (member.name, data)
                except Exception as e:
                    log.warning(f"Error reading {member.name} from {archive_path.name}: {e}")
    elif archive_type == 'zip':
        with zipfile.ZipFile(str(archive_path), 'r') as zf:
            for name in zf.namelist():
                info = zf.getinfo(name)
                if info.is_dir():
                    continue
                try:
                    data = zf.read(name)
                    yield (name, data)
                except Exception as e:
                    log.warning(f"Error reading {name} from {archive_path.name}: {e}")


def iter_all_archives():
    """Yield (filename, raw_bytes) from all 7 archives sequentially."""
    for archive_path, _, archive_type in ARCHIVE_SPECS:
        if not archive_path.exists():
            log.warning(f"Archive not found: {archive_path}")
            continue
        log.info(f"Processing archive: {archive_path.name}")
        yield from iter_archive(archive_path, archive_type)


# ---------------------------------------------------------------------------
# Group files into OC pairs: {oc: {'edital': bytes, 'json': bytes}}
# ---------------------------------------------------------------------------

def group_oc_files(file_iter, limit=None):
    """
    Consume (filename, bytes) iterator and group by OC.
    Returns dict: {oc: {'edital': text, 'json_text': text, 'json_data': dict}}.

    If limit is set, stop after processing that many _edital files.
    """
    oc_data = defaultdict(dict)
    edital_count = 0

    for filename, data in file_iter:
        if not filename.endswith('.txt'):
            continue
        oc = extract_oc(filename)
        text = decode_bytes(data)

        if '_edital.txt' in filename:
            oc_data[oc]['edital'] = text[:MAX_TEXT_LEN]
            edital_count += 1
            if limit and edital_count >= limit:
                break
        else:
            oc_data[oc]['json_text'] = text
            try:
                oc_data[oc]['json_data'] = json.loads(text)
            except (json.JSONDecodeError, ValueError):
                pass

    return dict(oc_data)


# ---------------------------------------------------------------------------
# Strategy 1: Regex classification
# ---------------------------------------------------------------------------

def classify_regex(text: str) -> tuple:
    """
    Apply regex patterns to edital text.
    Returns (judicial_score, admin_score) where each is 0 or 1.
    """
    if not text:
        return (0, 0)

    # Judicial
    judicial = 0
    for match in JUDICIAL_RE.finditer(text):
        start = max(0, match.start() - 80)
        end = min(len(text), match.end() + 80)
        context = text[start:end]
        if EXCLUDE_JUDICIAL_RE.search(context):
            continue
        judicial = 1
        break

    # Administrative
    admin = 0
    for line in text.split('\n'):
        if ADMIN_RE.search(line) and not BOILERPLATE_RE.search(line):
            admin = 1
            break

    return (judicial, admin)


# ---------------------------------------------------------------------------
# Strategy 2: JSON metadata classification
# ---------------------------------------------------------------------------

def classify_json_metadata(json_data: dict) -> tuple:
    """
    Check MUNICIPIO field and other metadata for classification signals.
    Returns (judicial_score, admin_score) where each is 0 or 1.
    """
    if not json_data or not isinstance(json_data, dict):
        return (0, 0)

    municipio = json_data.get('MUNICIPIO', '') or ''

    judicial = 1 if JSON_JUDICIAL_RE.search(municipio) else 0
    admin = 1 if JSON_ADMIN_RE.search(municipio) else 0

    return (judicial, admin)


# ---------------------------------------------------------------------------
# Strategy 3: Positional heuristics
# ---------------------------------------------------------------------------

def classify_positional(text: str, json_data: dict) -> tuple:
    """
    Check for classification signals in strategic positions:
    - First 500 chars of edital text (object description / header)
    - "Local de entrega" section
    - MUNICIPIO field from JSON metadata

    Returns (judicial_score, admin_score) where each is 0 or 1.
    """
    judicial = 0
    admin = 0

    if text:
        # Check first 500 chars (header/object area)
        header = text[:500]
        if JUDICIAL_RE.search(header):
            judicial = 1
        if ADMIN_RE.search(header) and not BOILERPLATE_RE.search(header):
            admin = 1

        # Check "Local de entrega" section (typically in first 3000 chars)
        local_match = re.search(
            r'local\s+de\s+entrega[:\s]*(.*?)(?:\n\n|\bg\)|h\))',
            text[:3000], re.IGNORECASE | re.DOTALL
        )
        if local_match:
            local_text = local_match.group(1)
            if JUDICIAL_RE.search(local_text):
                judicial = 1
            if ADMIN_RE.search(local_text) and not BOILERPLATE_RE.search(local_text):
                admin = 1

    # MUNICIPIO from JSON (very reliable)
    if json_data and isinstance(json_data, dict):
        municipio = json_data.get('MUNICIPIO', '') or ''
        if JSON_JUDICIAL_RE.search(municipio):
            judicial = 1
        if JSON_ADMIN_RE.search(municipio):
            admin = 1

    return (judicial, admin)


# ---------------------------------------------------------------------------
# Strategy 4: ML classification (TF-IDF + LinearSVC)
# ---------------------------------------------------------------------------

class MLClassifier:
    """TF-IDF + LinearSVC binary classifiers for judicial and admin."""

    def __init__(self):
        self.vectorizer = None
        self.clf_judicial = None
        self.clf_admin = None
        self.trained = False

    def train(self, texts: list, labels_jud: list, labels_adm: list):
        """Train on labeled texts."""
        from sklearn.feature_extraction.text import TfidfVectorizer
        from sklearn.svm import LinearSVC
        from sklearn.model_selection import train_test_split
        from sklearn.metrics import classification_report, confusion_matrix
        import numpy as np

        log.info(f"Training ML model on {len(texts)} texts...")

        # Stratify on combined label
        combined = [j * 2 + a for j, a in zip(labels_jud, labels_adm)]

        X_train, X_test, y_jud_train, y_jud_test, y_adm_train, y_adm_test = \
            train_test_split(texts, labels_jud, labels_adm,
                             test_size=0.2, random_state=42, stratify=combined)

        log.info(f"Train: {len(X_train)}, Test: {len(X_test)}")

        # TF-IDF
        self.vectorizer = TfidfVectorizer(
            max_features=TFIDF_MAX_FEATURES,
            ngram_range=(1, 2),
            sublinear_tf=True,
            strip_accents='unicode',
            min_df=3,
            max_df=0.95,
        )

        log.info("Fitting TF-IDF vectorizer...")
        X_train_tfidf = self.vectorizer.fit_transform(X_train)
        X_test_tfidf = self.vectorizer.transform(X_test)

        # Judicial classifier
        log.info("Training judicial classifier...")
        self.clf_judicial = LinearSVC(class_weight='balanced', C=1.0, max_iter=10000)
        self.clf_judicial.fit(X_train_tfidf, y_jud_train)

        y_jud_pred = self.clf_judicial.predict(X_test_tfidf)
        log.info("=== Judicial Classification Report ===")
        log.info("\n" + classification_report(y_jud_test, y_jud_pred,
                                               target_names=['Not Judicial', 'Judicial']))
        log.info(f"Confusion matrix:\n{confusion_matrix(y_jud_test, y_jud_pred)}")

        # Admin classifier
        log.info("Training admin classifier...")
        self.clf_admin = LinearSVC(class_weight='balanced', C=1.0, max_iter=10000)
        self.clf_admin.fit(X_train_tfidf, y_adm_train)

        y_adm_pred = self.clf_admin.predict(X_test_tfidf)
        log.info("=== Admin Classification Report ===")
        log.info("\n" + classification_report(y_adm_test, y_adm_pred,
                                               target_names=['Not Admin', 'Admin']))
        log.info(f"Confusion matrix:\n{confusion_matrix(y_adm_test, y_adm_pred)}")

        self.trained = True

        # Store metrics for report
        self.metrics = {
            'judicial': classification_report(y_jud_test, y_jud_pred, output_dict=True),
            'admin': classification_report(y_adm_test, y_adm_pred, output_dict=True),
            'n_train': len(X_train),
            'n_test': len(X_test),
        }

        log.info("ML training complete.")

    def predict_batch(self, texts: list) -> list:
        """
        Predict on a batch of texts.
        Returns list of (judicial_score, admin_score) where scores are from
        decision_function (positive = predicted class 1).
        """
        if not self.trained:
            return [(0.0, 0.0)] * len(texts)

        X = self.vectorizer.transform(texts)
        jud_scores = self.clf_judicial.decision_function(X)
        adm_scores = self.clf_admin.decision_function(X)

        return list(zip(jud_scores.tolist(), adm_scores.tolist()))

    def save(self, path):
        """Save trained model to disk."""
        with open(path, 'wb') as f:
            pickle.dump({
                'vectorizer': self.vectorizer,
                'clf_judicial': self.clf_judicial,
                'clf_admin': self.clf_admin,
                'metrics': self.metrics,
            }, f)
        log.info(f"Model saved to {path}")

    def load(self, path):
        """Load trained model from disk."""
        with open(path, 'rb') as f:
            data = pickle.load(f)
        self.vectorizer = data['vectorizer']
        self.clf_judicial = data['clf_judicial']
        self.clf_admin = data['clf_admin']
        self.metrics = data.get('metrics', {})
        self.trained = True
        log.info(f"Model loaded from {path}")


# ---------------------------------------------------------------------------
# Combined classification: weighted voting
# ---------------------------------------------------------------------------

def combine_votes(regex_result, json_result, positional_result, ml_result) -> tuple:
    """
    Combine 4 strategy results via weighted voting.

    regex_result:      (0/1, 0/1)
    json_result:       (0/1, 0/1)
    positional_result: (0/1, 0/1)
    ml_result:         (float, float) — decision function scores

    Returns: (judicial: 0/1, admin: 0/1)
    """
    # ML: convert continuous score to binary (positive = class 1)
    ml_jud = 1 if ml_result[0] > 0 else 0
    ml_adm = 1 if ml_result[1] > 0 else 0

    # Weighted sum
    jud_score = (W_JSON * json_result[0] +
                 W_REGEX * regex_result[0] +
                 W_POSITION * positional_result[0] +
                 W_ML * ml_jud)

    adm_score = (W_JSON * json_result[1] +
                 W_REGEX * regex_result[1] +
                 W_POSITION * positional_result[1] +
                 W_ML * ml_adm)

    judicial = 1 if jud_score >= VOTE_THRESHOLD else 0
    admin = 1 if adm_score >= VOTE_THRESHOLD else 0

    # No mutual exclusivity: ground truth has 4,151 OCs that are both
    # judicial AND admin (48.6% of admin OCs). Downstream Stata analysis
    # derives purchase_type and urgent from these independent dummies.

    return (judicial, admin)


# ---------------------------------------------------------------------------
# Phase 1: Train ML model
# ---------------------------------------------------------------------------

def phase1_train_ml(labels: dict, ml_classifier: MLClassifier):
    """Stream through archives, collect labeled texts, train ML."""
    from tqdm import tqdm

    log.info("=" * 60)
    log.info("PHASE 1: Training ML model")
    log.info("=" * 60)

    # Check for cached model
    if ML_MODEL_PATH.exists():
        log.info("Found cached model, loading...")
        ml_classifier.load(str(ML_MODEL_PATH))
        return

    # Collect texts for labeled OCs
    train_texts = {}  # oc -> text
    total_files = 0

    for archive_path, _, archive_type in ARCHIVE_SPECS:
        if not archive_path.exists():
            continue
        log.info(f"Scanning {archive_path.name} for labeled editais...")

        for filename, data in iter_archive(archive_path, archive_type):
            if not filename.endswith('_edital.txt'):
                continue
            total_files += 1
            oc = extract_oc(filename)
            if oc in labels and oc not in train_texts:
                text = decode_bytes(data)[:MAX_TEXT_LEN]
                if len(text.strip()) > 100:  # skip near-empty files
                    train_texts[oc] = text

        log.info(f"  Found {len(train_texts)} labeled editais so far "
                 f"(scanned {total_files} edital files)")

    log.info(f"Total labeled editais found: {len(train_texts)} / {len(labels)}")

    if len(train_texts) < 1000:
        log.error("Too few labeled editais found for ML training. Skipping ML.")
        return

    # Prepare training data
    ocs = list(train_texts.keys())
    texts = [train_texts[oc] for oc in ocs]
    labels_jud = [labels[oc][0] for oc in ocs]
    labels_adm = [labels[oc][1] for oc in ocs]

    log.info(f"Training set: {len(texts)} texts, "
             f"{sum(labels_jud)} judicial, {sum(labels_adm)} admin")

    ml_classifier.train(texts, labels_jud, labels_adm)
    ml_classifier.save(str(ML_MODEL_PATH))


# ---------------------------------------------------------------------------
# Phase 2: Test on 10K editais
# ---------------------------------------------------------------------------

def phase2_test(labels: dict, ml_classifier: MLClassifier):
    """Process first 10K editais from data01.gz as a test run."""
    from tqdm import tqdm

    log.info("=" * 60)
    log.info("PHASE 2: Test run on 10K editais")
    log.info("=" * 60)

    archive_path = ARCHIVE_SPECS[0][0]
    archive_type = ARCHIVE_SPECS[0][2]

    # Collect up to 10K OC pairs
    oc_data = defaultdict(dict)
    edital_count = 0

    for filename, data in iter_archive(archive_path, archive_type):
        if not filename.endswith('.txt'):
            continue
        oc = extract_oc(filename)
        text = decode_bytes(data)

        if '_edital.txt' in filename:
            oc_data[oc]['edital'] = text[:MAX_TEXT_LEN]
            edital_count += 1
            if edital_count >= 10_000:
                break
        else:
            oc_data[oc]['json_text'] = text
            try:
                oc_data[oc]['json_data'] = json.loads(text)
            except (json.JSONDecodeError, ValueError):
                pass

    log.info(f"Collected {len(oc_data)} OCs ({edital_count} editais)")

    # Classify in batch
    t0 = time.time()
    results = classify_batch(oc_data, ml_classifier)
    elapsed = time.time() - t0

    # Stats
    n_jud = sum(1 for r in results.values() if r[0] == 1)
    n_adm = sum(1 for r in results.values() if r[1] == 1)
    n_ord = len(results) - n_jud - n_adm

    log.info(f"Test results ({len(results)} OCs, {elapsed:.1f}s):")
    log.info(f"  Judicial: {n_jud} ({100*n_jud/len(results):.1f}%)")
    log.info(f"  Admin:    {n_adm} ({100*n_adm/len(results):.1f}%)")
    log.info(f"  Ordinary: {n_ord} ({100*n_ord/len(results):.1f}%)")
    log.info(f"  Speed:    {elapsed/len(results)*1000:.1f} ms/OC")

    # Validate against ground truth
    gt_match = gt_total = 0
    gt_jud_tp = gt_jud_fp = gt_jud_fn = 0
    gt_adm_tp = gt_adm_fp = gt_adm_fn = 0

    for oc, (pred_jud, pred_adm) in results.items():
        if oc in labels:
            gt_total += 1
            true_jud, true_adm = labels[oc]
            if pred_jud == true_jud and pred_adm == true_adm:
                gt_match += 1
            # Judicial
            if pred_jud == 1 and true_jud == 1: gt_jud_tp += 1
            if pred_jud == 1 and true_jud == 0: gt_jud_fp += 1
            if pred_jud == 0 and true_jud == 1: gt_jud_fn += 1
            # Admin
            if pred_adm == 1 and true_adm == 1: gt_adm_tp += 1
            if pred_adm == 1 and true_adm == 0: gt_adm_fp += 1
            if pred_adm == 0 and true_adm == 1: gt_adm_fn += 1

    if gt_total > 0:
        log.info(f"\nGround truth validation ({gt_total} labeled OCs in test set):")
        log.info(f"  Exact match: {gt_match}/{gt_total} ({100*gt_match/gt_total:.1f}%)")

        def safe_prf(tp, fp, fn):
            p = tp / (tp + fp) if (tp + fp) > 0 else 0
            r = tp / (tp + fn) if (tp + fn) > 0 else 0
            f1 = 2*p*r / (p + r) if (p + r) > 0 else 0
            return p, r, f1

        p, r, f1 = safe_prf(gt_jud_tp, gt_jud_fp, gt_jud_fn)
        log.info(f"  Judicial:  P={p:.3f} R={r:.3f} F1={f1:.3f} "
                 f"(TP={gt_jud_tp} FP={gt_jud_fp} FN={gt_jud_fn})")
        p, r, f1 = safe_prf(gt_adm_tp, gt_adm_fp, gt_adm_fn)
        log.info(f"  Admin:     P={p:.3f} R={r:.3f} F1={f1:.3f} "
                 f"(TP={gt_adm_tp} FP={gt_adm_fp} FN={gt_adm_fn})")

    # Estimate total time
    estimated_total = (elapsed / len(results)) * 1_200_000  # ~1.2M unique OCs
    log.info(f"\nEstimated time for full classification: {estimated_total/60:.0f} min")

    if estimated_total > 7200:
        log.warning("Estimated time exceeds 2 hours! Consider optimizations.")

    return results


# ---------------------------------------------------------------------------
# Batch classification helper
# ---------------------------------------------------------------------------

def classify_batch(oc_data: dict, ml_classifier: MLClassifier) -> dict:
    """
    Classify a batch of OCs using all 4 strategies + weighted voting.

    oc_data: {oc: {'edital': str, 'json_data': dict, ...}}
    Returns: {oc: (judicial, admin)}
    """
    ocs = list(oc_data.keys())
    results = {}

    # Step 1: Regex + JSON + Positional (non-ML strategies)
    regex_results = {}
    json_results = {}
    positional_results = {}

    for oc in ocs:
        info = oc_data[oc]
        edital_text = info.get('edital', '')
        json_data = info.get('json_data') or {}

        regex_results[oc] = classify_regex(edital_text)
        json_results[oc] = classify_json_metadata(json_data)
        positional_results[oc] = classify_positional(edital_text, json_data)

    # Step 2: ML in batches
    ml_results = {}
    if ml_classifier.trained:
        for i in range(0, len(ocs), ML_BATCH_SIZE):
            batch_ocs = ocs[i:i + ML_BATCH_SIZE]
            batch_texts = [oc_data[oc].get('edital', '') for oc in batch_ocs]
            batch_scores = ml_classifier.predict_batch(batch_texts)
            for oc, scores in zip(batch_ocs, batch_scores):
                ml_results[oc] = scores
    else:
        for oc in ocs:
            ml_results[oc] = (0.0, 0.0)

    # Step 3: Combine via weighted voting
    for oc in ocs:
        results[oc] = combine_votes(
            regex_results[oc],
            json_results[oc],
            positional_results[oc],
            ml_results[oc],
        )

    return results


# ---------------------------------------------------------------------------
# Phase 3: Full classification
# ---------------------------------------------------------------------------

def phase3_full_classification(labels: dict, ml_classifier: MLClassifier) -> dict:
    """Process all archives, classify every OC."""
    from tqdm import tqdm

    log.info("=" * 60)
    log.info("PHASE 3: Full classification")
    log.info("=" * 60)

    all_results = {}
    batch_oc_data = defaultdict(dict)
    edital_count = 0
    total_files = 0
    batch_num = 0
    t0 = time.time()

    for archive_path, _, archive_type in ARCHIVE_SPECS:
        if not archive_path.exists():
            log.warning(f"Skipping missing archive: {archive_path}")
            continue

        log.info(f"Processing {archive_path.name}...")
        archive_edital_count = 0

        for filename, data in iter_archive(archive_path, archive_type):
            if not filename.endswith('.txt'):
                continue
            total_files += 1

            oc = extract_oc(filename)
            text = decode_bytes(data)

            if '_edital.txt' in filename:
                batch_oc_data[oc]['edital'] = text[:MAX_TEXT_LEN]
                edital_count += 1
                archive_edital_count += 1
            else:
                batch_oc_data[oc]['json_text'] = text
                try:
                    batch_oc_data[oc]['json_data'] = json.loads(text)
                except (json.JSONDecodeError, ValueError):
                    pass

            # Process batch when edital count crosses next ML_BATCH_SIZE threshold
            if '_edital.txt' in filename and edital_count % ML_BATCH_SIZE == 0 and len(batch_oc_data) > 0:
                batch_num += 1
                batch_results = classify_batch(dict(batch_oc_data), ml_classifier)
                all_results.update(batch_results)
                batch_oc_data.clear()

                elapsed = time.time() - t0
                speed = edital_count / elapsed if elapsed > 0 else 0
                log.info(f"  Batch {batch_num}: {edital_count} editais processed, "
                         f"{len(all_results)} OCs classified, "
                         f"{speed:.0f} editais/s")

        log.info(f"  {archive_path.name}: {archive_edital_count} editais")

    # Process remaining batch
    if batch_oc_data:
        batch_results = classify_batch(dict(batch_oc_data), ml_classifier)
        all_results.update(batch_results)
        batch_oc_data.clear()

    elapsed = time.time() - t0
    log.info(f"Full classification complete: {len(all_results)} OCs in {elapsed/60:.1f} min "
             f"({total_files} total files)")

    return all_results


# ---------------------------------------------------------------------------
# Phase 4: Generate outputs
# ---------------------------------------------------------------------------

def phase4_outputs(all_results: dict, labels: dict, ml_classifier: MLClassifier):
    """Write Parquet, CSV sample, and classification report."""
    import pyarrow as pa
    import pyarrow.parquet as pq

    log.info("=" * 60)
    log.info("PHASE 4: Generating outputs")
    log.info("=" * 60)

    # --- Parquet output ---
    ocs = sorted(all_results.keys())
    jud_list = [all_results[oc][0] for oc in ocs]
    adm_list = [all_results[oc][1] for oc in ocs]

    table = pa.table({
        'purchase_order': ocs,
        'dummy_judicial': jud_list,
        'dummy_admin': adm_list,
    })
    pq.write_table(table, str(OUTPUT_PARQUET))
    log.info(f"Parquet written: {OUTPUT_PARQUET} ({len(ocs)} rows)")

    # --- CSV sample ---
    sample_size = min(1000, len(ocs))
    sample_ocs = random.sample(ocs, sample_size)
    with open(OUTPUT_SAMPLE, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(['purchase_order', 'dummy_judicial', 'dummy_admin'])
        for oc in sorted(sample_ocs):
            writer.writerow([oc, all_results[oc][0], all_results[oc][1]])
    log.info(f"Sample CSV written: {OUTPUT_SAMPLE} ({sample_size} rows)")

    # --- Classification report ---
    n_total = len(ocs)
    n_jud = sum(jud_list)
    n_adm = sum(adm_list)
    n_ord = n_total - n_jud - n_adm

    report_lines = [
        "=" * 60,
        "CLASSIFICATION REPORT",
        "=" * 60,
        "",
        f"Total OCs classified: {n_total:,}",
        f"  Judicial:    {n_jud:,} ({100*n_jud/n_total:.2f}%)",
        f"  Admin:       {n_adm:,} ({100*n_adm/n_total:.2f}%)",
        f"  Ordinary:    {n_ord:,} ({100*n_ord/n_total:.2f}%)",
        "",
    ]

    # Ground truth validation
    gt_match = gt_total = 0
    gt_jud_tp = gt_jud_fp = gt_jud_fn = gt_jud_tn = 0
    gt_adm_tp = gt_adm_fp = gt_adm_fn = gt_adm_tn = 0

    for oc in ocs:
        if oc in labels:
            gt_total += 1
            true_jud, true_adm = labels[oc]
            pred_jud, pred_adm = all_results[oc]
            if pred_jud == true_jud and pred_adm == true_adm:
                gt_match += 1
            if pred_jud == 1 and true_jud == 1: gt_jud_tp += 1
            if pred_jud == 1 and true_jud == 0: gt_jud_fp += 1
            if pred_jud == 0 and true_jud == 1: gt_jud_fn += 1
            if pred_jud == 0 and true_jud == 0: gt_jud_tn += 1
            if pred_adm == 1 and true_adm == 1: gt_adm_tp += 1
            if pred_adm == 1 and true_adm == 0: gt_adm_fp += 1
            if pred_adm == 0 and true_adm == 1: gt_adm_fn += 1
            if pred_adm == 0 and true_adm == 0: gt_adm_tn += 1

    if gt_total > 0:
        def prf(tp, fp, fn):
            p = tp / (tp + fp) if (tp + fp) > 0 else 0
            r = tp / (tp + fn) if (tp + fn) > 0 else 0
            f1 = 2*p*r / (p + r) if (p + r) > 0 else 0
            return p, r, f1

        report_lines += [
            "-" * 60,
            f"GROUND TRUTH VALIDATION ({gt_total:,} labeled OCs)",
            "-" * 60,
            f"Exact match: {gt_match:,}/{gt_total:,} ({100*gt_match/gt_total:.2f}%)",
            "",
        ]

        p, r, f1 = prf(gt_jud_tp, gt_jud_fp, gt_jud_fn)
        report_lines += [
            "Judicial:",
            f"  Precision: {p:.4f}",
            f"  Recall:    {r:.4f}",
            f"  F1:        {f1:.4f}",
            f"  TP={gt_jud_tp} FP={gt_jud_fp} FN={gt_jud_fn} TN={gt_jud_tn}",
            "",
        ]

        p, r, f1 = prf(gt_adm_tp, gt_adm_fp, gt_adm_fn)
        report_lines += [
            "Administrative:",
            f"  Precision: {p:.4f}",
            f"  Recall:    {r:.4f}",
            f"  F1:        {f1:.4f}",
            f"  TP={gt_adm_tp} FP={gt_adm_fp} FN={gt_adm_fn} TN={gt_adm_tn}",
            "",
        ]

    # ML metrics
    if ml_classifier.trained and hasattr(ml_classifier, 'metrics'):
        report_lines += [
            "-" * 60,
            "ML MODEL METRICS (hold-out test set)",
            "-" * 60,
        ]
        for label in ('judicial', 'admin'):
            m = ml_classifier.metrics.get(label, {})
            if m:
                pos = m.get('1', m.get('Judicial', m.get('Admin', {})))
                if isinstance(pos, dict):
                    report_lines.append(
                        f"{label.title()}: P={pos.get('precision',0):.4f} "
                        f"R={pos.get('recall',0):.4f} F1={pos.get('f1-score',0):.4f}"
                    )
        report_lines += [
            f"Train size: {ml_classifier.metrics.get('n_train', '?')}",
            f"Test size:  {ml_classifier.metrics.get('n_test', '?')}",
            "",
        ]

    # Mutual exclusivity check
    both = sum(1 for oc in ocs if all_results[oc][0] == 1 and all_results[oc][1] == 1)
    report_lines += [
        "-" * 60,
        "CONSISTENCY CHECKS",
        "-" * 60,
        f"OCs with both judicial=1 and admin=1: {both} (GT has ~4,151 overlapping OCs)",
        "",
    ]

    report_text = '\n'.join(report_lines)
    with open(OUTPUT_REPORT, 'w', encoding='utf-8') as f:
        f.write(report_text)
    log.info(f"Report written: {OUTPUT_REPORT}")
    print("\n" + report_text)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Full edital classification pipeline")
    parser.add_argument('--phase', type=int, default=None,
                        help='Run only specific phase (0-4)')
    parser.add_argument('--skip-ml', action='store_true',
                        help='Skip ML training, use regex/metadata/positional only')
    parser.add_argument('--test-only', action='store_true',
                        help='Run phases 0-2 only (setup + train + test)')
    args = parser.parse_args()

    t_start = time.time()

    # ---- Phase 0: Setup ----
    if args.phase is None or args.phase == 0:
        log.info("=" * 60)
        log.info("PHASE 0: Setup")
        log.info("=" * 60)

        ensure_dependencies()

        # System info
        ncpu = os.cpu_count()
        try:
            with open('/proc/meminfo') as f:
                for line in f:
                    if line.startswith('MemAvailable'):
                        mem_gb = int(line.split()[1]) / 1024 / 1024
                        log.info(f"Available RAM: {mem_gb:.1f} GB")
                        break
        except FileNotFoundError:
            mem_gb = 0
        log.info(f"CPU cores: {ncpu}")

        # Check archives
        for path, _, _ in ARCHIVE_SPECS:
            if path.exists():
                size_gb = path.stat().st_size / 1024**3
                log.info(f"  {path.name}: {size_gb:.1f} GB")
            else:
                log.warning(f"  {path.name}: NOT FOUND")

    # Load ground truth
    labels = load_ground_truth()

    # ---- Phase 1: Train ML ----
    ml_classifier = MLClassifier()
    if not args.skip_ml and (args.phase is None or args.phase == 1):
        phase1_train_ml(labels, ml_classifier)
    elif ML_MODEL_PATH.exists() and not args.skip_ml:
        ml_classifier.load(str(ML_MODEL_PATH))

    # ---- Phase 2: Test on 10K ----
    if args.phase is None or args.phase == 2:
        phase2_test(labels, ml_classifier)

    if args.test_only:
        log.info("Test-only mode: stopping after Phase 2.")
        return

    # ---- Phase 3: Full classification ----
    if args.phase is None or args.phase == 3:
        all_results = phase3_full_classification(labels, ml_classifier)
    else:
        all_results = None

    # ---- Phase 4: Outputs ----
    if all_results and (args.phase is None or args.phase == 4):
        phase4_outputs(all_results, labels, ml_classifier)

    elapsed = time.time() - t_start
    log.info(f"Total pipeline time: {elapsed/60:.1f} min")


if __name__ == '__main__':
    main()
