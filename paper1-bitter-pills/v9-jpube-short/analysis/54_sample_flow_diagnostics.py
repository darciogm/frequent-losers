#!/usr/bin/env python3
"""Generate Appendix B sample-flow diagnostics from the macro layer.

The table reports retention rates only where the parent and child share the
same empirical unit. Classifier purchase-order records are intentionally not
used as the denominator for POI-level samples.
"""
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
VALUES = ROOT / "manuscript" / "paper" / "values.tex"
OUT = ROOT / "output" / "tables"
OUT.mkdir(parents=True, exist_ok=True)


def read_macro(name: str) -> str:
    prefix = rf"\renewcommand{{\BP{name}}}{{"
    hits = []
    for line in VALUES.read_text(encoding="utf-8").splitlines():
        if line.startswith(prefix) and line.endswith("}"):
            hits.append(line[len(prefix):-1])
    if not hits:
        raise SystemExit(f"[54] missing macro: BP{name}")
    return hits[-1]


def parse_int(s: str) -> int:
    clean = s.replace("{,}", "").replace(",", "").strip()
    clean = re.sub(r"\\[a-zA-Z]+", "", clean)
    return int(clean)


def fmt_int(n: int) -> str:
    return f"{n:,}".replace(",", "{,}")


def fmt_pct(child: int, parent: int) -> str:
    return f"{100.0 * child / parent:.1f}\\%"


def row(sample: str, unit: str, n: int, parent: str, share: str) -> str:
    return f"{sample} & {unit} & {fmt_int(n)} & {parent} & {share} \\\\"


def main() -> None:
    n_full = parse_int(read_macro("nPOIfull"))
    n_analysis = parse_int(read_macro("nAnalysisSample"))
    n_winners = parse_int(read_macro("negNobs"))
    n_urgent = parse_int(read_macro("nUTG"))
    n_triples = parse_int(read_macro("utgTripleNUTG"))
    n_triple_groups = parse_int(read_macro("utgTripleCountUTG"))
    n_both_cells = parse_int(read_macro("bothCellN"))
    n_singleton_cells = parse_int(read_macro("bothCellNSingleton"))

    lines = [
        row("Full BEC pharmaceutical file", "POI", n_full, "--", "--"),
        row(
            "Analysis sample",
            "POI",
            n_analysis,
            "Full BEC pharmaceutical file",
            fmt_pct(n_analysis, n_full),
        ),
        row(
            "Winners-only price sample",
            "Winning bid",
            n_winners,
            "Analysis sample",
            fmt_pct(n_winners, n_analysis),
        ),
        row(
            "Urgent panel",
            "Urgent winning bid",
            n_urgent,
            "Winners-only price sample",
            fmt_pct(n_urgent, n_winners),
        ),
        row(
            "Firm-buyer-item triple observations",
            "Urgent winning bid",
            n_triples,
            "Urgent panel",
            fmt_pct(n_triples, n_urgent),
        ),
        row("Firm-buyer-item triples", "Triple", n_triple_groups, "--", "--"),
        row("Both-regime urgent cells", "Item-year-month cell", n_both_cells, "--", "--"),
        row("Singleton urgent cells", "Item-year-month cell", n_singleton_cells, "--", "--"),
    ]

    tex = rf"""
\begin{{table}}[ht]
\centering
\caption{{Sample-flow diagnostics for POI-level analysis samples.}}
\label{{tab:sample_flow_diagnostics}}
\begin{{threeparttable}}
\small
\setlength{{\tabcolsep}}{{3pt}}
\begin{{adjustbox}}{{max width=\textwidth}}
\begin{{tabular}}{{@{{}}p{{.23\linewidth}}p{{.15\linewidth}}r p{{.20\linewidth}}r@{{}}}}
\toprule
Sample & Unit & Size & Parent sample & Share of parent \\
\midrule
{chr(10).join(lines)}
\bottomrule
\end{{tabular}}
\end{{adjustbox}}
\begin{{tablenotes}}[flushleft]\footnotesize
\item \textit{{Notes:}} Retention shares are reported only for nested samples with comparable units. The classifier universe is excluded from the denominator because it is a purchase-order/tender-notice file, whereas the rows shown here are POI-, winning-bid-, triple-, or cell-level empirical samples. POI denotes purchase-offer-item.
\end{{tablenotes}}
\end{{threeparttable}}
\end{{table}}
"""
    path = OUT / "tab_sample_flow_diagnostics.tex"
    path.write_text(tex.strip() + "\n", encoding="utf-8")
    print(f"[54] wrote {path}")


if __name__ == "__main__":
    main()
