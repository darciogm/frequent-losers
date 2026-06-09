from __future__ import annotations

import argparse
import importlib.metadata as md
import json
import logging
import os
import platform
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

import psutil


ROOT = Path(__file__).resolve().parents[1]
INTER = ROOT / "02_data" / "intermediate"
PROC = ROOT / "02_data" / "processed"
TAB = ROOT / "01_manuscript" / "tables"
FIG = ROOT / "04_figures"
LOG = ROOT / "04_logs"
NOTES = ROOT / "notes"


def parse_args(description: str) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=description)
    parser.add_argument("--force", action="store_true", help="overwrite existing outputs")
    return parser.parse_args()


def git_sha() -> str:
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
        ).strip()
    except Exception:
        return "unknown"


def logger_for(script_name: str) -> logging.Logger:
    LOG.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    logger = logging.getLogger(script_name)
    logger.setLevel(logging.INFO)
    logger.handlers.clear()
    fmt = logging.Formatter("%(asctime)s %(levelname)s %(message)s")
    for handler in (
        logging.FileHandler(LOG / f"{script_name}_{stamp}.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ):
        handler.setFormatter(fmt)
        logger.addHandler(handler)
    return logger


def begin_log(logger: logging.Logger, script_name: str, seeds: list[int] | None = None) -> float:
    packages = {}
    for pkg in ("duckdb", "pandas", "pyarrow", "numpy", "matplotlib", "scipy"):
        try:
            packages[pkg] = md.version(pkg)
        except md.PackageNotFoundError:
            packages[pkg] = "not-installed"
    payload = {
        "script": script_name,
        "timestamp": datetime.now().isoformat(timespec="seconds"),
        "git_sha": git_sha(),
        "pid": os.getpid(),
        "platform": platform.platform(),
        "python": platform.python_version(),
        "ram_total_gb": round(psutil.virtual_memory().total / 1e9, 3),
        "seeds": seeds or [],
        "packages": packages,
    }
    logger.info("runtime_header=%s", json.dumps(payload, sort_keys=True))
    return time.perf_counter()


def end_log(logger: logging.Logger, t0: float) -> None:
    runtime = time.perf_counter() - t0
    rss = psutil.Process().memory_info().rss / 1e9
    logger.info("runtime_seconds=%.2f peak_rss_proxy_gb=%.3f", runtime, rss)


def ensure_dirs() -> None:
    for path in (PROC, TAB, FIG, LOG, NOTES):
        path.mkdir(parents=True, exist_ok=True)


def require_force(paths: list[Path], force: bool, logger: logging.Logger) -> bool:
    existing = [p for p in paths if p.exists()]
    if existing and not force:
        logger.info("outputs already exist; use --force to overwrite: %s", [str(p) for p in existing])
        return False
    return True


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def latex_escape(value: object) -> str:
    text = "" if value is None else str(value)
    return (
        text.replace("\\", "\\textbackslash{}")
        .replace("&", "\\&")
        .replace("%", "\\%")
        .replace("$", "\\$")
        .replace("#", "\\#")
        .replace("_", "\\_")
    )
