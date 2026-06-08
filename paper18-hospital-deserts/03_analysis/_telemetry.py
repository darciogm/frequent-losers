from __future__ import annotations

import json
import logging
import os
import platform
import socket
import subprocess
import time
from pathlib import Path

import psutil


def git_sha(root: Path) -> str:
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "HEAD"],
            cwd=root,
            text=True,
        ).strip()
    except Exception:
        return "unknown"


class StepTimer:
    def __init__(self, logger: logging.Logger):
        self.logger = logger
        self.t0 = time.perf_counter()
        self.t_prev = self.t0
        self.peak_rss_gb = rss_gb()

    def mark(self, label: str) -> dict:
        now = time.perf_counter()
        rss = rss_gb()
        self.peak_rss_gb = max(self.peak_rss_gb, rss)
        payload = {
            "step": label,
            "seconds": round(now - self.t_prev, 3),
            "elapsed_seconds": round(now - self.t0, 3),
            "rss_gb": round(rss, 3),
        }
        self.logger.info(
            "[%s] step=%.2fs elapsed=%.2fs rss=%.2fGB",
            label,
            payload["seconds"],
            payload["elapsed_seconds"],
            payload["rss_gb"],
        )
        self.t_prev = now
        return payload


def rss_gb() -> float:
    return psutil.Process().memory_info().rss / 1e9


def runtime_header(root: Path, seeds: list[int] | None = None) -> dict:
    vm = psutil.virtual_memory()
    return {
        "hostname": socket.gethostname(),
        "platform": platform.platform(),
        "git_sha": git_sha(root),
        "pid": os.getpid(),
        "cores_logical": psutil.cpu_count(logical=True),
        "cores_physical": psutil.cpu_count(logical=False),
        "ram_total_gb": round(vm.total / 1e9, 3),
        "ram_available_gb": round(vm.available / 1e9, 3),
        "seeds": seeds or [],
    }


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=True) + "\n")

