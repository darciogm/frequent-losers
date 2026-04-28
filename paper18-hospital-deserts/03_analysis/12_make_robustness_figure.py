"""
12_make_robustness_figure.py

Gera figura de robustez para o apêndice do paper:
- Painel 1: Pearson(emb_dist) cross-seed (3 alternativas)
- Painel 2: Pearson(emb_dist) cross-walk-length
- Painel 3: ΔR² emb-over-km por pop_min restriction
- Painel 4: top-K overlap (SP + Manaus) cross-seed

Lê 04_logs/10_robustness.json. Output: 04_figures/fig_robustness.pdf+png.
"""

from __future__ import annotations

import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
LOG = ROOT / "04_logs"
FIG = ROOT / "04_figures"

plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "font.size": 9,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "savefig.dpi": 300,
    "savefig.bbox": "tight",
})

R = json.loads((LOG / "10_robustness.json").read_text())

fig, axes = plt.subplots(2, 2, figsize=(11, 8))

# ---- panel 1: pearson cross-seed ----------------------------------
ax = axes[0, 0]
seeds = ["1", "13", "100"]
ρ_seed = [R["seed_stability"][f"seed_{s}"]["pearson_emb_dist"] for s in seeds]
ax.bar(seeds, ρ_seed, color="C0", alpha=0.85, edgecolor="black", linewidth=0.5)
ax.axhline(1.0, color="0.6", ls=":", lw=0.8)
ax.set_ylim(0, 1.05)
ax.set_ylabel("Pearson ρ vs baseline (seed=42)")
ax.set_xlabel("Alternative seed")
ax.set_title("(a) Seed stability\n(pair-distance correlation, n=5000 pairs)", fontsize=9.5)
for i, v in enumerate(ρ_seed):
    ax.text(i, v + 0.02, f"{v:.3f}", ha="center", fontsize=8)

# ---- panel 2: pearson cross-walk-length ---------------------------
ax = axes[0, 1]
wlens = ["40", "80"]
ρ_wlen = [R["walk_length"][f"wlen_{w}"]["pearson_emb_dist"] for w in wlens]
ax.bar(wlens, ρ_wlen, color="C1", alpha=0.85, edgecolor="black", linewidth=0.5)
ax.axhline(1.0, color="0.6", ls=":", lw=0.8)
ax.set_ylim(0, 1.05)
ax.set_ylabel("Pearson ρ vs baseline (wlen=20)")
ax.set_xlabel("Alternative walk length")
ax.set_title("(b) Walk-length sensitivity", fontsize=9.5)
for i, v in enumerate(ρ_wlen):
    ax.text(i, v + 0.02, f"{v:.3f}", ha="center", fontsize=8)

# ---- panel 3: top-K overlap by seed -----------------------------
ax = axes[1, 0]
labels, sp, mn = [], [], []
for s in seeds:
    labels.append(f"seed {s}")
    sp.append(R["seed_stability"][f"seed_{s}"]["sp_top10_overlap"])
    mn.append(R["seed_stability"][f"seed_{s}"]["manaus_top10_overlap"])
for w in wlens:
    labels.append(f"wlen {w}")
    sp.append(R["walk_length"][f"wlen_{w}"]["sp_top10_overlap"])
    mn.append(R["walk_length"][f"wlen_{w}"]["manaus_top10_overlap"])

x = np.arange(len(labels))
ax.bar(x - 0.2, sp, width=0.4, label="São Paulo (355030)", color="C2", alpha=0.85)
ax.bar(x + 0.2, mn, width=0.4, label="Manaus (130260)", color="C3", alpha=0.85)
ax.set_xticks(x)
ax.set_xticklabels(labels, rotation=30, ha="right", fontsize=8)
ax.set_ylabel("Top-10 neighbor overlap with baseline")
ax.set_ylim(0, 10)
ax.set_yticks(range(0, 11, 2))
ax.legend(fontsize=8, frameon=False, loc="upper left")
ax.set_title("(c) Top-10 nearest-neighbor stability\n(out of 10 baseline neighbors)", fontsize=9.5)
ax.axhline(10, color="0.6", ls=":", lw=0.8)

# ---- panel 4: ΔR² by sample restriction ------------------------
ax = axes[1, 1]
labels = ["pop≥0\n(n=5565)", "pop≥10k\n(n=3112)", "pop≥50k\n(n=663)",
         "pop≥10k\n+amenable>0\nall years\n(n=3112)"]
keys = ["pop_min_0", "pop_min_10000", "pop_min_50000", "amenable_pos_all_years"]
deltas = [R["sample_restriction"][k]["delta_emb_over_km"] for k in keys]
colors = ["C0" if d >= 0 else "C3" for d in deltas]
ax.bar(range(len(deltas)), deltas, color=colors, alpha=0.85,
       edgecolor="black", linewidth=0.5)
ax.axhline(0, color="black", lw=0.5)
ax.axhline(0.005, color="C2", ls="--", lw=0.6, label="WEAK threshold")
ax.axhline(0.02, color="C1", ls="--", lw=0.6, label="MARGINAL threshold")
ax.set_xticks(range(len(labels)))
ax.set_xticklabels(labels, fontsize=7.5)
ax.set_ylabel("$\\Delta R^2$ (embedding over km-only)")
ax.set_title("(d) Sample restriction sensitivity\n(adding $\\mathrm{iso}^{emb}$ to model with $\\mathrm{iso}^{km}$)",
             fontsize=9.5)
ax.legend(fontsize=8, frameon=False, loc="upper right")
for i, d in enumerate(deltas):
    ax.text(i, d + 0.0005 if d >= 0 else d - 0.001, f"{d:+.4f}",
            ha="center", fontsize=7)
ax.set_ylim(min(deltas) - 0.003, max(deltas) + 0.005)

fig.tight_layout()
fig.savefig(FIG / "fig_robustness.pdf")
fig.savefig(FIG / "fig_robustness.png", dpi=200)
plt.close(fig)
print(f"wrote {FIG / 'fig_robustness.pdf'}")
