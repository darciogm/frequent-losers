"""
89_fig_where_inpatient_use_goes.py

Produces: 04_figures/fig_where_inpatient_use_goes.pdf

Intended LaTeX caption (paste into manuscript):
-------------------------------------------------------------------------------
\\begin{figure}[!htbp]
  \\centering
  \\includegraphics[width=\\linewidth]{04_figures/fig_where_inpatient_use_goes.pdf}
  \\caption{Where inpatient psychiatric use goes after closure. \\textit{Notes:}
  Each series shows the catchment-level mean number of inpatient psychiatric
  admissions (ICD-10 F00--F99) across event years $-4$ to $+4$, estimated from
  the 30 PNASH psychiatric hospital closures that have sufficient flow support
  (municipalities sending $\\geq 5\\%$ of their pre-closure inpatient volume to
  the closing hospital). Admissions to the closing hospital collapse to zero at
  event time 0 by construction; admissions to other hospitals do not rise to
  compensate---they are flat and then slightly decline---so total inpatient
  psychiatric admissions fall and remain depressed. The design observes
  inpatient admissions (SIH-RD) only, not outpatient care (CAPS or ambulat\\'orio);
  the ``loss'' means the volume is not observed in inpatient psychiatric
  admissions, not that patients necessarily receive no care.}
  \\label{fig:where-inpatient-use-goes}
\\end{figure}
-------------------------------------------------------------------------------
"""
from __future__ import annotations

import argparse
import logging
import os
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "02_data" / "processed" / "psych_displacement_panel.parquet"
OUT  = ROOT / "04_figures" / "fig_where_inpatient_use_goes.pdf"

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s",
                    handlers=[logging.StreamHandler(sys.stdout)])
log = logging.getLogger("89_fig")

plt.rcParams.update({
    "font.family":        "DejaVu Sans",
    "font.size":          9.5,
    "axes.titlesize":     10,
    "axes.labelsize":     9.5,
    "axes.spines.top":    False,
    "axes.spines.right":  False,
    "savefig.dpi":        300,
    "savefig.bbox":       "tight",
})

# Okabe-Ito colorblind-safe palette
C_CLOSING = "#D55E00"   # vermillion  — closing hospital
C_OTHER   = "#0072B2"   # blue        — other hospitals
C_TOTAL   = "#000000"   # black       — total (any hospital)


def load_data():
    import duckdb
    con = duckdb.connect()
    con.execute("PRAGMA threads=12")
    con.execute("PRAGMA memory_limit='14GB'")
    df = con.sql(f"""
        SELECT event_time,
               AVG(psych_total)   AS total,
               AVG(psych_closing) AS closing,
               AVG(psych_other)   AS other
        FROM read_parquet('{DATA}')
        WHERE event_time BETWEEN -4 AND 4
        GROUP BY event_time
        ORDER BY event_time
    """).df()
    log.info("loaded %d event-time rows from %s", len(df), DATA.name)
    log.info("data:\n%s", df.to_string(index=False))
    return df


def make_figure(df) -> None:
    et     = df["event_time"].tolist()
    total  = df["total"].tolist()
    closing = df["closing"].tolist()
    other  = df["other"].tolist()

    fig, ax = plt.subplots(figsize=(7.0, 4.5))

    # Vertical closure marker
    ax.axvline(0, color="0.4", linewidth=0.9, linestyle="--", zorder=1)

    # Three lines
    ax.plot(et, closing, color=C_CLOSING, linewidth=1.8, marker="o",
            markersize=5, label="Closing hospital", zorder=3)
    ax.plot(et, other,   color=C_OTHER,   linewidth=1.8, marker="s",
            markersize=5, label="Other hospitals",   zorder=3)
    ax.plot(et, total,   color=C_TOTAL,   linewidth=2.0, marker="^",
            markersize=5, label="Total (any hospital)", zorder=3,
            linestyle="-")

    # Closure annotation
    ax.text(0.03, 0.97, "Closure",
            transform=ax.transAxes, va="top", ha="left",
            fontsize=8.5, color="0.4")

    ax.set_xlabel("Years since closure", fontsize=9.5)
    ax.set_ylabel("Inpatient psychiatric admissions (catchment mean)", fontsize=9.5)
    ax.set_title("Where inpatient psychiatric use goes after closure", loc="left")
    ax.set_xticks(et)
    ax.set_xlim(-4.4, 4.4)
    ax.set_ylim(bottom=0)
    ax.legend(frameon=False, fontsize=9)

    fig.tight_layout()
    fig.savefig(OUT)
    log.info("wrote %s (%.1f kB)", OUT, OUT.stat().st_size / 1024)


def main():
    import psutil
    vm = psutil.virtual_memory()
    log.info("host=%s cores=12/14 ram_total=%.1fGiB ram_free=%.1fGiB",
             os.uname().nodename, vm.total / 1e9, vm.available / 1e9)

    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true",
                    help="Regenerate even if output already exists")
    args = ap.parse_args()

    if OUT.exists() and not args.force:
        log.info("output already exists: %s — skipping (use --force to regenerate)", OUT)
        sys.exit(0)

    df = load_data()
    make_figure(df)


if __name__ == "__main__":
    main()
