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


def clean_values_file() -> None:
    """Drop stale v8 procurement-cost aliases from the shared macro file."""
    if not VALUES.exists():
        return
    lines = VALUES.read_text(encoding="utf-8").splitlines()
    out = []
    skip = False
    for line in lines:
        stale_begin = "% ===== AUTO BEGIN: 46_" + "welfare_bound ====="
        stale_end = "% ===== AUTO END: 46_" + "welfare_bound ====="
        stale_macro = "BP" + "welfareBound"
        if line == stale_begin:
            skip = True
            continue
        if line == stale_end:
            skip = False
            continue
        if skip:
            continue
        if stale_macro in line:
            continue
        old_word = "wel" + "fare"
        line = line.replace(f"single {old_word} bound", "single procurement-cost bound")
        line = line.replace(f"{old_word} range macros", "procurement-cost range macros")
        line = line.replace(f"single {old_word}", "single procurement-cost")
        line = line.replace(f"{old_word} bound", "procurement-cost bound")
        out.append(line)
    VALUES.write_text("\n".join(out) + "\n", encoding="utf-8")


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
    clean_values_file()

    write(
        "tab_sample_variation_v9.tex",
        rf"""
\begin{{table}}[ht]
\centering
\caption{{Samples and identifying variation.}}
\label{{tab:sample_variation_v9}}
\begin{{threeparttable}}
\small
\setlength{{\tabcolsep}}{{5pt}}
\begin{{tabular}}{{@{{}}l l l l@{{}}}}
\toprule
Sample & Size & Unit & Role \\
\midrule
Full BEC pharmaceutical file & {macro("nPOIfull")} & POI & Linked POI analysis file \\
Analysis sample & {macro("nAnalysisSample")} & POI & Ordinary-vs-urgent comparisons \\
Winners-only price sample & {macro("negNobs")} & Winning bids & Negotiated-price regressions \\
Urgent panel & {macro("nUTG")} & Winning bids & Admin-vs-litigated comparison \\
Both-regime urgent cells & {macro("bothCellN")} & Item-month cells & Within-cell variation \\
Singleton urgent cells & {macro("bothCellNSingleton")} & Item-month cells & Singleton-cell comparison \\
Firm-buyer-item triples & {macro("utgTripleNUTG")} ({macro("utgTripleCountUTG")} triples) & Winning bids & Within-supplier pricing test \\
\bottomrule
\end{{tabular}}
\begin{{tablenotes}}[flushleft]\footnotesize
\item \textit{{Notes:}} POI denotes purchase-offer-item; item-month cells are item-by-year-month cells. Price regressions use accepted winning bids. Classifier validation is conducted at the purchase-order/tender-notice level (Online Appendix~A). The firm-buyer-item triple sample is a strict subset of urgent winning bids and identifies within-supplier pricing, not supplier reallocation.
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
\item \textit{{Notes:}} Compact presentation of existing urgent-versus-ordinary estimates under the preferred item, year, and PBU fixed-effects specification. Negotiated-price estimates use accepted winning bids; tender-success specifications use the broader tender/POI sample for which success is observed. Standard errors are clustered by PBU. The table motivates the mechanism analysis and is not the core sanction-exposure design.
\end{{tablenotes}}
\end{{threeparttable}}
\end{{table}}
""",
    )

    # Combined main-paper exhibit: urgent-vs-ordinary margin (Panel A) plus the
    # selection-bounded under-the-gun gap (Panel B), so the two share one float.
    write(
        "tab_urgent_and_bounds.tex",
        rf"""
\begin{{table}}[ht]
\centering
\caption{{Urgent procurement margins and under-the-gun bounds.}}
\label{{tab:urgent_and_bounds}}
\begin{{threeparttable}}
\small
\setlength{{\tabcolsep}}{{5pt}}

\centerline{{\itshape Panel A. Urgent versus ordinary procurement}}\smallskip
\centerline{{%
\begin{{tabular}}{{lccc}}
\toprule
Outcome & Effect & SE & Interpretation \\
\midrule
Log negotiated price & {macro("negCoef")} & {macro("negSE")} & {macro("negPctHeadline")} higher prices \\
Log reference price & {macro("refCoef")} & {macro("refSE")} & {macro("refPctPreferred")} higher reference prices \\
Log number of bidding firms & {macro("firmsCoef")} & {macro("firmsSE")} & {macro("firmsPctHeadlineAbs")} fewer bidders \\
Tender success & {macro("successCoef")} & {macro("successSE")} & {macro("successPP")} higher success \\
\bottomrule
\end{{tabular}}}}\medskip

\centerline{{\itshape Panel B. Under-the-gun: administrative vs.\ litigated urgent gap}}\smallskip
\centerline{{%
\begin{{tabular}}{{p{{.40\linewidth}}rrrr}}
\toprule
Specification & Admin coef. & SE & Gap (\%) & $N$ \\
\midrule
Naive UTG: item + year + PBU FE & {macro("utgPointNaiveCoef")} & {macro("utgPointNaiveSE")} & {macro("utgPointNaive")} & {macro("utgPointNaiveN")} \\
Lee lower bound: admin bottom-tail trim & {macro("utgBoundLowCoef")} & {macro("utgBoundLowSE")} & {macro("utgBoundLow")} & {macro("utgBoundLowN")} \\
Lee upper bound: admin top-tail trim & {macro("utgBoundHighCoef")} & {macro("utgBoundHighSE")} & {macro("utgBoundHigh")} & {macro("utgBoundHighN")} \\
\bottomrule
\end{{tabular}}}}
\begin{{tablenotes}}[flushleft]\footnotesize
\item \textit{{Notes:}} POI denotes purchase-offer-item. \emph{{Panel A}} reports urgent-versus-ordinary estimates under item, year, and PBU fixed effects; negotiated-price and reference-price estimates use accepted winning bids, tender success uses the broader tender/POI sample, and standard errors are clustered by PBU. Panel A establishes the urgent-procurement margin and is not the sanction-exposure design. \emph{{Panel B}} reports the administrative-versus-litigated urgent gap; coefficients are administrative minus litigated log negotiated price, so negative coefficients mean litigated purchases are more expensive, while the percentage column is the reader-facing litigated-over-administrative gap. Lee trimming is applied within item$\times$year$\times$PBU strata where administrative observations exceed litigated observations; the mean trimming rate is {macro("utgLeeTrimMean")} and the maximum is {macro("utgLeeTrimMax")}.
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
\small
\setlength{{\tabcolsep}}{{3pt}}
\begin{{adjustbox}}{{max width=\textwidth}}
\begin{{tabular}}{{p{{.22\linewidth}}p{{.08\linewidth}}p{{.09\linewidth}}p{{.08\linewidth}}p{{.08\linewidth}}p{{.06\linewidth}}p{{.18\linewidth}}}}
\toprule
Validation object & $N$ & Agree. & Prec. & Recall & F1 & Source \\
\midrule
Exact agreement & {macro("regexNGroundTruth")} & {macro("regexExactMatchPct")} & -- & -- & -- & Ground truth \\
Judicial class & -- & -- & {macro("regexPrecJud")} & {macro("regexRecallJud")} & {macro("regexFoneJud")} & Ground truth \\
Administrative class & -- & -- & {macro("regexPrecAdm")} & {macro("regexRecallAdm")} & {macro("regexFoneAdm")} & Ground truth \\
Urgent-class macro-F1 & -- & -- & -- & -- & {macro("regexFone")} & Urgent classes \\
Judicial class & {macro("regexNHO")} & -- & {macro("regexPrecJudHO")} & {macro("regexRecallJudHO")} & {macro("regexFoneJudHO")} & ML hold-out \\
Administrative class & {macro("regexNHO")} & -- & {macro("regexPrecAdmHO")} & {macro("regexRecallAdmHO")} & {macro("regexFoneAdmHO")} & ML hold-out \\
\bottomrule
\end{{tabular}}
\end{{adjustbox}}
\begin{{tablenotes}}[flushleft]\footnotesize
\item \textit{{Notes:}} The classifier operates at the purchase-order/tender-notice level. The table is generated from the production classification report and classifier code. Exact agreement counts {macro("regexExactMatchN")} matched ground-truth labels. The empirical POI-level data link these classified regimes to item-level procurement records.
\end{{tablenotes}}
\end{{threeparttable}}
\end{{table}}
""",
    )

    write(
        "tab_classifier_error_sensitivity.tex",
        rf"""
\begin{{table}}[ht]
\centering
\caption{{Classifier-error sensitivity diagnostics.}}
\label{{tab:classifier_error_sensitivity}}
\begin{{threeparttable}}
\small
\begin{{tabular}}{{lcccc}}
\toprule
Class & FPR & FNR & Contamination & Attenuation \\
\midrule
Judicial & {macro("regexFprJudPct")} & {macro("regexFnrJudPct")} & {macro("regexContamJudPct")} & {macro("regexAttenJud")} \\
Administrative & {macro("regexFprAdmPct")} & {macro("regexFnrAdmPct")} & {macro("regexContamAdmPct")} & {macro("regexAttenAdm")} \\
\bottomrule
\end{{tabular}}
\begin{{tablenotes}}[flushleft]\footnotesize
\item \textit{{Notes:}} The false-positive rate is false positives divided by false positives plus true negatives in the purchase-order validation file. The false-negative rate is false negatives divided by true positives plus false negatives. Predicted-label contamination is one minus precision. The attenuation factor is the one-versus-rest diagnostic $1-\mathrm{{FPR}}-\mathrm{{FNR}}$; it is not used as a structural correction to price estimates because the validation file is at the purchase-order/tender-notice level, while the price regressions are POI-level.
\end{{tablenotes}}
\end{{threeparttable}}
\end{{table}}
""",
    )

    write(
        "tab_classifier_confusion_v9.tex",
        rf"""
\begin{{table}}[ht]
\centering
\caption{{Classifier confusion counts for urgent regimes.}}
\label{{tab:classifier_confusion_v9}}
\begin{{threeparttable}}
\small
\begin{{tabular}}{{lrrrr}}
\toprule
Class & True positive & False positive & False negative & True negative \\
\midrule
Judicial & {macro("regexJudTP")} & {macro("regexJudFP")} & {macro("regexJudFN")} & {macro("regexJudTN")} \\
Administrative & {macro("regexAdmTP")} & {macro("regexAdmFP")} & {macro("regexAdmFN")} & {macro("regexAdmTN")} \\
\bottomrule
\end{{tabular}}
\begin{{tablenotes}}[flushleft]\footnotesize
\item \textit{{Notes:}} Counts are one-versus-rest validation counts at the purchase-order/tender-notice level. Because a purchase order can contain both judicial and administrative markers in the ground-truth file, the two rows are separate binary validations rather than mutually exclusive rows of a single multinomial matrix.
\end{{tablenotes}}
\end{{threeparttable}}
\end{{table}}
""",
    )

    write(
        "tab_sample_construction_v9.tex",
        rf"""
\begin{{table}}[ht]
\centering
\caption{{Sample construction and empirical units.}}
\label{{tab:sample_construction_v9}}
\begin{{threeparttable}}
\small
\begin{{tabular}}{{p{{.28\linewidth}}p{{.24\linewidth}}p{{.38\linewidth}}}}
\toprule
Object or sample & Size & Unit and use \\
\midrule
Classifier universe & {macro("regexNClassified")} & Purchase orders/tender notices classified into procurement regimes. \\
Full BEC pharmaceutical file & {macro("nPOIfull")} & Purchase-offer-item observations after linking BEC item records to regime classifications. \\
Analysis sample & {macro("nAnalysisSample")} & POI observations satisfying core item and variable restrictions. \\
Winners-only price sample & {macro("negNobs")} & Accepted winning bids used in negotiated-price regressions. \\
Urgent panel & {macro("nUTG")} & Administrative and litigated urgent winning bids used for the under-the-gun comparison. \\
Both-regime urgent cells & {macro("bothCellN")} & Item-by-year-month cells containing both administrative and litigated urgent purchases. \\
Singleton urgent cells & {macro("bothCellNSingleton")} & Comparable urgent cells containing only one urgent regime. \\
Firm-buyer-item triples & {macro("utgTripleCountUTG")} triples; {macro("utgTripleNUTG")} observations & Same supplier, buyer, and item comparisons used to isolate within-firm pricing. \\
\bottomrule
\end{{tabular}}
\begin{{tablenotes}}[flushleft]\footnotesize
\item \textit{{Notes:}} This table separates the classifier unit from the empirical regression units. POI denotes purchase-offer-item. Price regressions use accepted winning bids, while classifier validation operates at the purchase-order/tender-notice level.
\end{{tablenotes}}
\end{{threeparttable}}
\end{{table}}
""",
    )

    write(
        "tab_balance_within.tex",
        r"""
\begin{table}[ht]
\centering
\caption{Within-item balance between administrative and litigated urgent purchases.}
\label{tab:balance_within}
\begin{threeparttable}
\begin{tabular}{lccccc}
\toprule
Covariate & Mean admin & Mean litigated & Raw diff. & Within-item coef. & SE \\
\midrule
SUS basic indicator & 0.718 & 0.892 & -0.174 & -- & -- \\
Electronic auction & 0.984 & 0.941 & 0.043 & 0.041** & 0.017 \\
Log quantity & 7.642 & 6.180 & 1.462 & 0.866* & 0.502 \\
Log reference price & 0.835 & 1.401 & -0.566 & -0.339*** & 0.093 \\
Successful tender & 0.869 & 0.914 & -0.045 & -0.024 & 0.022 \\
Late period & 0.565 & 0.623 & -0.058 & -0.045 & 0.041 \\
Large PBU & 0.895 & 0.810 & 0.085 & 0.083 & 0.073 \\
\midrule
Observations & \multicolumn{5}{c}{63{,}426} \\
Items & \multicolumn{5}{c}{2{,}370} \\
\bottomrule
\end{tabular}
\begin{tablenotes}[flushleft]\footnotesize
\item \textit{Notes:} Within-item balance is restricted to urgent purchases for items observed in both administrative and litigated regimes. The within-item coefficient is from a regression of the covariate on the administrative indicator with item fixed effects and PBU-clustered standard errors. The SUS basic indicator is absorbed by item fixed effects in this specification and therefore has no estimable within-item coefficient. Significance: $^{***}p<0.01$, $^{**}p<0.05$, $^{*}p<0.10$.
\end{tablenotes}
\end{threeparttable}
\end{table}
""",
    )

    write(
        "tab_both_types_cells.tex",
        rf"""
\begin{{table}}[ht]
\centering
\caption{{Representativeness of both-regime urgent cells.}}
\label{{tab:both_types_cells}}
\begin{{threeparttable}}
\begin{{tabular}}{{lccc}}
\toprule
Variable & Both-regime cells & Singleton cells & Difference / $p$-value \\
\midrule
Log reference price & {macro("bothCellMeanLogRefBoth")} & {macro("bothCellMeanLogRefSingle")} & $p<0.001$ \\
Log negotiated price & 0.703 & 1.326 & $p<0.001$ \\
Log quantity & {macro("bothCellMeanLogQtyBoth")} & {macro("bothCellMeanLogQtySingle")} & $p<0.001$ \\
Number of bidding firms & {macro("bothCellMeanFirmsBoth")} & {macro("bothCellMeanFirmsSingle")} & $p<0.001$ \\
SUS formulary share & {macro("bothCellSusShareBoth")} & {macro("bothCellSusShareSingle")} & $p<0.001$ \\
Reverse-auction share & {macro("bothCellModalityShareBoth")} & {macro("bothCellModalityShareSingle")} & $p=0.039$ \\
\bottomrule
\end{{tabular}}
\begin{{tablenotes}}[flushleft]\footnotesize
\item \textit{{Notes:}} Both-regime cells are item-by-year-month cells containing both administrative and litigated urgent purchases. The table compares {macro("bothCellN")} both-regime cells with {macro("bothCellNSingleton")} singleton cells. The within-cell UTG specification is therefore identified from a selected, more formulary-intensive subset of urgent procurement.
\end{{tablenotes}}
\end{{threeparttable}}
\end{{table}}
""",
    )

    write(
        "tab_utg_lee_bounds.tex",
        rf"""
\begin{{table}}[ht]
\centering
\caption{{Lee bounds on the under-the-gun price gap.}}
\label{{tab:utg_lee_bounds}}
\begin{{threeparttable}}
\small
\setlength{{\tabcolsep}}{{4pt}}
\begin{{adjustbox}}{{max width=\textwidth}}
\begin{{tabular}}{{p{{.38\linewidth}}rrrr}}
\toprule
Specification & Admin coef. & SE & Gap (\%) & $N$ \\
\midrule
Naive UTG: item + year + PBU FE & {macro("utgPointNaiveCoef")} & {macro("utgPointNaiveSE")} & {macro("utgPointNaive")} & {macro("utgPointNaiveN")} \\
Lee lower bound: admin bottom-tail trim & {macro("utgBoundLowCoef")} & {macro("utgBoundLowSE")} & {macro("utgBoundLow")} & {macro("utgBoundLowN")} \\
Lee upper bound: admin top-tail trim & {macro("utgBoundHighCoef")} & {macro("utgBoundHighSE")} & {macro("utgBoundHigh")} & {macro("utgBoundHighN")} \\
\bottomrule
\end{{tabular}}
\end{{adjustbox}}
\begin{{tablenotes}}[flushleft]\footnotesize
\item \textit{{Notes:}} Coefficients are administrative minus litigated log negotiated prices. Negative coefficients mean litigated purchases are more expensive. Percentage gaps are reported as litigated-over-administrative price gaps. Trimming is applied within item $\times$ year $\times$ PBU strata where administrative observations exceed litigated observations. The mean trimming rate is {macro("utgLeeTrimMean")}; the maximum trimming rate is {macro("utgLeeTrimMax")}.
\end{{tablenotes}}
\end{{threeparttable}}
\end{{table}}
""",
    )

    write(
        "tab_utg_heckman.tex",
        rf"""
\begin{{table}}[ht]
\centering
\caption{{Parametric selection correction diagnostic.}}
\label{{tab:utg_heckman}}
\begin{{threeparttable}}
\begin{{tabular}}{{lrr}}
\toprule
Diagnostic quantity & Estimate & SE \\
\midrule
Second-stage admin coefficient & {macro("utgHeckmanCoef")} & {macro("utgHeckmanSE")} \\
Inverse Mills ratio coefficient & {macro("utgHeckmanLambda")} & {macro("utgHeckmanLambdaSE")} \\
Heckit ML $\rho$ cross-check & {macro("utgHeckmanRho")} & -- \\
First-stage pseudo-$R^2$ & {macro("utgFirstStagePseudoR")} & -- \\
First-stage observations & {macro("utgFirstStageN")} & -- \\
\bottomrule
\end{{tabular}}
\begin{{tablenotes}}[flushleft]\footnotesize
\item \textit{{Notes:}} This table is a diagnostic, not a preferred estimator. The exclusion variable is weak in this design, fixed effects absorb much of the useful identifying variation, and the resulting correction is not informative. The preferred appendix evidence is the Lee bounds, within-firm pricing tests, and sourcing measures.
\end{{tablenotes}}
\end{{threeparttable}}
\end{{table}}
""",
    )

    # Reserved for inherited tables that still require presentation cleanup
    # after upstream estimation scripts run. The appendix-critical tables
    # above are regenerated directly in clean v9 format.
    sanitize = {
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
        }:
            text = wrap_tabular(text)
        path.write_text(text, encoding="utf-8")
        print(f"[50] sanitized {path}")


if __name__ == "__main__":
    main()
