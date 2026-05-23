#!/usr/bin/env python3
"""Generate v9-specific tables from the macro layer.

These tables intentionally print LaTeX macros rather than resolved numbers.
The upstream analysis scripts own the empirical values; this script owns only
the v9 presentation layer.
"""
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
OUT = ROOT / "output" / "tables"
VALUES = ROOT / "manuscript" / "paper" / "values.tex"
OUT.mkdir(parents=True, exist_ok=True)


def write(name: str, text: str) -> None:
    path = OUT / name
    path.write_text(text.strip() + "\n", encoding="utf-8")
    print(f"[50] wrote {path}")


def macro(name: str) -> str:
    return rf"\BP{name}{{}}"


def wrap_tabular(text: str) -> str:
    """Scale inherited kable tables whose generated notes exceed text width."""
    if "\\begin{adjustbox}{max width=\\textwidth}" in text:
        return text
    text = text.replace(
        "\\begin{tabular}",
        "\\begin{adjustbox}{max width=\\textwidth}\n\\begin{tabular}",
        1,
    )
    end = text.rfind("\\end{tabular}")
    if end >= 0:
        end += len("\\end{tabular}")
        text = text[:end] + "\n\\end{adjustbox}" + text[end:]
    return text


def main() -> None:
    if not VALUES.exists():
        raise SystemExit(f"Missing macro file: {VALUES}")

    write(
        "tab_sample_variation_v9.tex",
        rf"""
\begin{{table}}[ht]
\centering
\caption{{Samples and identifying variation.}}
\label{{tab:sample_variation_v9}}
\begin{{threeparttable}}
\begin{{tabular}}{{p{{.30\linewidth}}p{{.23\linewidth}}p{{.37\linewidth}}}}
\toprule
Sample & Size & Role in the paper \\
\midrule
Full BEC pharmaceutical sample & {macro("nPOIfull")} POI observations & Universe of classified pharmaceutical procurement records. \\
Analysis sample & {macro("nAnalysisSample")} observations & Core item and variable restrictions for ordinary-versus-urgent comparisons. \\
Winners-only price sample & {macro("negNobs")} winning bids & Negotiated-price regressions use accepted winning bids. \\
Urgent panel & {macro("nUTG")} winning bids & Administrative-versus-litigated urgent comparison. \\
Both-regime urgent cells & {macro("bothCellN")} cells & Cells with both administrative and litigated urgent purchases. \\
Both-types singleton cells & {macro("bothCellNSingleton")} cells & Urgent cells with only one observed regime; used for representativeness checks. \\
Firm-buyer-item triple sample & {macro("utgTripleNUTG")} observations; {macro("utgTripleCountUTG")} triples & Same firm, same buyer, same item pricing test. \\
\bottomrule
\end{{tabular}}
\begin{{tablenotes}}[flushleft]\footnotesize
\item \textit{{Notes:}} POI denotes purchase-offer-item. ``Cells'' follow the cell definition used by the corresponding generated representativeness and bounds scripts. The triple sample is a strict subset of urgent winning bids and identifies within-supplier pricing, not supplier reallocation.
\end{{tablenotes}}
\end{{threeparttable}}
\end{{table}}
""",
    )

    write(
        "tab_urgent_outcomes_v9.tex",
        rf"""
\begin{{table}}[ht]
\centering
\caption{{Urgent procurement and procurement outcomes.}}
\label{{tab:urgent_outcomes_v9}}
\begin{{threeparttable}}
\begin{{tabular}}{{lccc}}
\toprule
Outcome & Effect & SE & Interpretation \\
\midrule
Log negotiated price & {macro("negCoef")} & {macro("negSE")} & {macro("negPctHeadline")} higher prices \\
Log reference price & {macro("refCoef")} & {macro("refSE")} & {macro("refPctPreferred")} higher reference prices \\
Log number of bidding firms & {macro("firmsCoef")} & {macro("firmsSE")} & {macro("firmsPctHeadlineAbs")} fewer bidders \\
Tender success & {macro("successCoef")} & {macro("successSE")} & {macro("successPP")} higher success \\
\bottomrule
\end{{tabular}}
\begin{{tablenotes}}[flushleft]\footnotesize
\item \textit{{Notes:}} Compact presentation of existing urgent-versus-ordinary estimates under the preferred item, year, and PBU fixed-effects specification. Price estimates use winning bids. The table motivates the mechanism analysis and is not the core sanction-exposure design.
\end{{tablenotes}}
\end{{threeparttable}}
\end{{table}}
""",
    )

    write(
        "tab_classifier_validation_v9.tex",
        rf"""
\begin{{table}}[ht]
\centering
\caption{{Purchase-regime classifier validation.}}
\label{{tab:classifier_validation_v9}}
\begin{{threeparttable}}
\begin{{tabular}}{{lccc}}
\toprule
Validation object & Precision / agreement & Recall & F1 \\
\midrule
Exact three-class agreement & {macro("regexExactMatchPct")} & -- & -- \\
Judicial class, ground truth & 0.87 & 1.00 & {macro("regexFoneJud")} \\
Administrative class, ground truth & 0.92 & 0.99 & {macro("regexFoneAdm")} \\
Urgent-class macro-F1 & -- & -- & {macro("regexFone")} \\
Judicial class, ML hold-out & -- & -- & {macro("regexFoneJudHO")} \\
Administrative class, ML hold-out & -- & -- & {macro("regexFoneAdmHO")} \\
\bottomrule
\end{{tabular}}
\begin{{tablenotes}}[flushleft]\footnotesize
\item \textit{{Notes:}} Ground-truth validation uses {macro("regexNGroundTruth")} labeled purchase orders; exact agreement covers {macro("regexExactMatchN")} matches. The ML hold-out test set contains {macro("regexNHO")} observations. Precision and recall entries are rounded by the generator from the production classification report where reported.
\end{{tablenotes}}
\end{{threeparttable}}
\end{{table}}
""",
    )

    # Sanitize inherited kableExtra tables that are regenerated upstream with
    # LaTeX-unsafe plain text in notes or currency strings.
    sanitize = {
        "tab_both_types_cells.tex": [
            ("\\label{tab:tab:both_types_cells}", "\\label{tab:both_types_cells}"),
        ],
        "tab_utg_lee_bounds.tex": [
            ("\\label{tab:tab:utg_lee_bounds}", "\\label{tab:utg_lee_bounds}"),
        ],
        "tab_utg_heckman.tex": [
            ("\\label{tab:tab:utg_heckman}", "\\label{tab:utg_heckman}"),
            ("pre_n_orders", "pre\\_n\\_orders"),
            ("Heckit ML: rho", "Heckit ML: $\\rho$"),
        ],
        "tab_welfare_bound.tex": [
            ("\\label{tab:tab:welfare_bound}", "\\label{tab:welfare_bound}"),
            ("18.5%", "18.5\\%"),
            ("15.9%", "15.9\\%"),
            ("21.1%", "21.1\\%"),
            ("50%", "50\\%"),
            ("& $300 M / yr\\\\", "& \\$300~M / yr\\\\"),
            ("& $27.8 M / yr\\\\", "& \\$27.8~M / yr\\\\"),
            ("& $23.9 M / yr\\\\", "& \\$23.9~M / yr\\\\"),
            ("& $31.7 M / yr\\\\", "& \\$31.7~M / yr\\\\"),
            ("Table~ref{tab:utg_lee_bounds}", "Table~\\ref{tab:utg_lee_bounds}"),
            ("Table~ref{tab:utg_reconciliation}", "Table~\\ref{tab:utg_reconciliation}"),
            ("v8's reconciliation table", "the reconciliation table"),
            ("S~ao Paulo", "S\\~ao Paulo"),
        ],
        "tab_utg_reconciliation.tex": [
            ("95% cluster-bootstrap", "95\\% cluster-bootstrap"),
        ],
    }
    for filename, reps in sanitize.items():
        path = OUT / filename
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8")
        for old, new in reps:
            text = text.replace(old, new)
        if filename in {
            "tab_both_types_cells.tex",
            "tab_utg_lee_bounds.tex",
            "tab_utg_heckman.tex",
            "tab_utg_reconciliation.tex",
            "tab_welfare_bound.tex",
        }:
            text = wrap_tabular(text)
        path.write_text(text, encoding="utf-8")
        print(f"[50] sanitized {path}")


if __name__ == "__main__":
    main()
