"""
36_cross_section_null_figure.py

Major #5 do parecer S9: gera figura inline para §5.1 mostrando o
cross-section null em forest plot. 11 outcomes (1 amenable + 5
cause-specific + 5 SIH-based alternatives), cada um com Δ R² do
embedding sobre a baseline km, com banda de "null zone" [-0.01, +0.01].

Insumos: 04_logs/07_metrics.json (amenable), 04_logs/17b_cause_specific_metrics.json
(5 causas), 04_logs/17d_alt_outcomes_metrics.json (5 alt outcomes).

Output: 04_figures/fig_cross_section_null.pdf
"""

from __future__ import annotations

import json
import logging
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
LOG = ROOT / "04_logs"
FIG = ROOT / "04_figures"

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s",
                    handlers=[logging.StreamHandler(sys.stdout)])
log = logging.getLogger("xs_null")

plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "font.size": 9.5,
    "axes.titlesize": 10,
    "axes.labelsize": 9.5,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "savefig.dpi": 300,
    "savefig.bbox": "tight",
})


def load_metrics():
    rows = []

    # Amenable mortality from 07
    with open(LOG / "07_metrics.json") as f:
        d = json.load(f)
    rows.append({
        "label": "Amenable mortality (Nolte–McKee)",
        "group": "SIM aggregate",
        "delta_r2_emb_vs_km": d["delta_r2_emb_over_km"],
        "delta_r2_both_vs_km": d["delta_r2_both_over_km"],
        "se_emb": d["models"]["M_emb"]["r2_sd"],
    })

    # 5 cause-specific from 17b
    with open(LOG / "17b_cause_specific_metrics.json") as f:
        d = json.load(f)
    label_map = {
        "ami": "AMI mortality (I21)",
        "stroke": "Stroke mortality (I60-64)",
        "sepsis": "Sepsis mortality (A40-41)",
        "maternal": "Maternal mortality (O00-99)",
        "perinatal": "Perinatal mortality (P00-09)",
    }
    for k, lab in label_map.items():
        r = d["results"][k]
        rows.append({
            "label": lab,
            "group": "SIM cause-specific",
            "delta_r2_emb_vs_km": r["delta_r2_emb_vs_km"],
            "delta_r2_both_vs_km": r["delta_r2_both_vs_km"],
            "se_emb": r["M_emb"]["r2_sd"],
        })

    # 5 alt outcomes from 17d
    with open(LOG / "17d_alt_outcomes_metrics.json") as f:
        d = json.load(f)
    alt_map = {
        "hosp_per1k": "Hospitalization rate (per 1k)",
        "in_hosp_mort_pct": "In-hospital mortality (%)",
        "urg_ratio_pct": "Urgency-admission share (%)",
        "icsap_per1k": "ICSAP rate (per 1k)",
        "ami_inhosp_mort_pct": "AMI in-hosp mortality (%)",
    }
    for k, lab in alt_map.items():
        if k not in d["results"]: continue
        r = d["results"][k]
        rows.append({
            "label": lab,
            "group": "SIH-based alternatives",
            "delta_r2_emb_vs_km": r["delta_r2_emb_vs_km"],
            "delta_r2_both_vs_km": r["delta_r2_both_vs_km"],
            "se_emb": r["M_emb"]["r2_sd"],
        })

    return rows


def main():
    rows = load_metrics()
    log.info("loaded %d outcomes", len(rows))

    # ordenar por grupo + magnitude
    group_order = {"SIM aggregate": 0, "SIM cause-specific": 1,
                   "SIH-based alternatives": 2}
    rows.sort(key=lambda r: (group_order[r["group"]], r["delta_r2_both_vs_km"]))

    labels = [r["label"] for r in rows]
    delta_emb = [r["delta_r2_emb_vs_km"] for r in rows]
    delta_both = [r["delta_r2_both_vs_km"] for r in rows]
    groups = [r["group"] for r in rows]

    # cores por grupo
    color_map = {
        "SIM aggregate": "#d62728",
        "SIM cause-specific": "#1f77b4",
        "SIH-based alternatives": "#2ca02c",
    }
    colors = [color_map[g] for g in groups]

    fig, ax = plt.subplots(figsize=(7.5, 5))
    y_pos = np.arange(len(labels))[::-1]

    # null zone shading
    ax.axvspan(-0.01, 0.01, color="0.85", alpha=0.6, zorder=0,
                label="null zone (±0.01)")

    # zero line
    ax.axvline(0, color="0.4", linewidth=0.6, linestyle="--", zorder=1)

    # delta both (preferred — menos viesado por colinearidade)
    ax.scatter(delta_both, y_pos, c=colors, s=55, zorder=3,
                edgecolor="white", linewidth=0.5,
                label=r"$\Delta R^2$: $M_{\mathrm{both}} - M_{\mathrm{km}}$")

    # delta emb (apenas para reference, hollow)
    ax.scatter(delta_emb, y_pos, marker="o", facecolors="none",
                edgecolors=colors, s=40, linewidth=0.8, zorder=2,
                label=r"$\Delta R^2$: $M_{\mathrm{emb}} - M_{\mathrm{km}}$")

    # connectors
    for i, y in enumerate(y_pos):
        ax.plot([delta_both[i], delta_emb[i]], [y, y],
                color=colors[i], linewidth=0.6, alpha=0.5, zorder=1)

    ax.set_yticks(y_pos)
    ax.set_yticklabels(labels, fontsize=9)
    ax.set_xlabel(r"$\Delta R^2$ over haversine-kilometer baseline ($M_{km}$)")
    ax.set_xlim(-0.025, 0.020)
    ax.set_title("Cross-sectional null of the embedding across 11 outcomes",
                  loc="left", fontsize=10)
    ax.legend(loc="lower right", frameon=False, fontsize=8.5)

    # group separators (pequeno)
    last_group = None
    for i, g in enumerate(groups):
        if g != last_group:
            if last_group is not None:
                ax.axhline(y_pos[i] + 0.5, color="0.85", linewidth=0.5)
            last_group = g

    fig.tight_layout()
    out = FIG / "fig_cross_section_null.pdf"
    fig.savefig(out)
    log.info("wrote %s", out)


if __name__ == "__main__":
    main()
