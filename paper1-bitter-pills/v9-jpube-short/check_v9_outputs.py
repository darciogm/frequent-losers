#!/usr/bin/env python3
"""Lightweight staleness/completeness check for v9 generated outputs."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent
required = [
    "manuscript/paper/values.tex",
    "output/tables/tab_sample_variation_v9.tex",
    "output/tables/tab_urgent_outcomes_v9.tex",
    "output/tables/tab_classifier_validation_v9.tex",
    "output/tables/tab_classifier_confusion_v9.tex",
    "output/tables/tab_classifier_error_sensitivity.tex",
    "output/tables/tab_sample_construction_v9.tex",
    "output/tables/tab_sample_flow_diagnostics.tex",
    "output/tables/tab_balance_within.tex",
    "output/tables/tab_both_types_cells.tex",
    "output/tables/tab_utg_lee_bounds.tex",
    "output/tables/tab_utg_lee_alt_strata.tex",
    "output/tables/tab_utg_heckman.tex",
    "output/tables/tab_utg_reconciliation.tex",
    "output/tables/tab_procurement_cost_bound.tex",
    "output/tables/tab_procurement_cost_sensitivity.tex",
    "output/tables/tab_procurement_cost_spending_sensitivity.tex",
    "output/tables/tab_within_firm_robustness.tex",
    "output/tables/tab_within_firm_alt_cluster.tex",
    "output/tables/tab_aggregation_cells.tex",
    "output/tables/tab_winner_switch.tex",
    "output/tables/tab_utg_boottest.tex",
    "output/tables/tab_sample_restriction_robustness.tex",
    "output/tables/tab_market_depth_heterogeneity.tex",
    "output/tables/tab_quantity_definition_robustness.tex",
    "output/tables/tab_dynamic_sensitivity_summary.tex",
    "output/tables/tab_placebo.tex",
    "output/tables/tab_procurement_cost_bound.tex",
    "output/figures/fig_sourcing_vs_pricing.pdf",
    "output/figures/fig_event_study_item.pdf",
    "output/figures/fig_event_study_honest_rr.pdf",
]

missing = [p for p in required if not (ROOT / p).exists()]
if missing:
    print("[v9-check] missing generated outputs:")
    for p in missing:
        print(f"  - {p}")
    sys.exit(1)

tex_files = [
    ROOT / "manuscript" / "paper" / "main.tex",
    ROOT / "manuscript" / "paper" / "Introduction.tex",
    ROOT / "manuscript" / "paper" / "InstitutionalBackground.tex",
    ROOT / "manuscript" / "paper" / "DataAndSample.tex",
    ROOT / "manuscript" / "paper" / "EmpiricalStrategy.tex",
    ROOT / "manuscript" / "paper" / "Results.tex",
    ROOT / "manuscript" / "paper" / "Conclusion.tex",
    ROOT / "manuscript" / "paper" / "OnlineAppendix.tex",
    ROOT / "manuscript" / "paper" / "Appendix.tex",
]
bad_terms = [
    "in " + "progress",
    "to be " + "added",
    "will be " + "reported",
    "place" + "holder",
    "item" + "times",
    "welfare " + "bound",
    "welfare " + "cost",
    "Chat" + "GPT",
    "Clau" + "de",
    "Co" + "dex",
    "LLM-" + "generated",
]
hits = []
for path in tex_files:
    text = path.read_text(encoding="utf-8", errors="replace")
    low = text.lower()
    for term in bad_terms:
        if term.lower() in low:
            hits.append((path.relative_to(ROOT), term))
    if "Na" + "N" in text:
        hits.append((path.relative_to(ROOT), "Na" + "N"))

for rel in required:
    path = ROOT / rel
    if path.suffix == ".tex":
        text = path.read_text(encoding="utf-8", errors="replace")
        low = text.lower()
        for term in bad_terms:
            if term.lower() in low:
                hits.append((path.relative_to(ROOT), term))
        if "Na" + "N" in text:
            hits.append((path.relative_to(ROOT), "Na" + "N"))

if hits:
    print("[v9-check] blocked terms found:")
    for path, term in hits:
        print(f"  - {path}: {term}")
    sys.exit(1)

print("[v9-check] all required outputs present; no blocked terms found")
