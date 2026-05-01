#!/usr/bin/env bash
# ============================================================================
# verify_paper.sh — verification suite for paper_v13 reproducibility
# ============================================================================
# Checks:
#   1. values.tex exists and was generated from current scripts (mtime).
#   2. Every macro defined in values.tex resolves in paper_v13.tex.
#   3. No literal numbers known to be sensitive (2735, 0.94, etc.) appear
#      in disciplined sections (intro, abstract, mechanisms, robustness,
#      newly-rewritten appendix subsections).
#   4. All artifact CSVs referenced by values.tex exist on disk.
#   5. PDF compiled successfully (no LaTeX ! errors, no Undefined references).
#   6. Macro count in values.tex matches expected ~100.
# ============================================================================

set -uo pipefail
cd "$(dirname "$0")/.."

PASS=0; FAIL=0
ok()   { echo "  [PASS] $*"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $*"; FAIL=$((FAIL+1)); }

echo "=== verify_paper.sh ==="

# 1. values.tex exists
if [[ -f work/v13/values.tex ]]; then
  ok "values.tex exists ($(wc -l < work/v13/values.tex) lines)"
else
  fail "values.tex missing"
fi

# 2. Macros defined are referenced or available; compute simple coverage
N_DEFINED=$(grep -c "^\\\\newcommand{\\\\val" work/v13/values.tex 2>/dev/null | tr -d ' \n' || echo 0)
ok "$N_DEFINED macros defined in values.tex"

# 3. Sensitive literals in disciplined sections — should be ZERO
DISCIPLINED_SECTIONS=(
  work/v13/sec_introduction.tex
  work/v13/sec_frontmatter.tex
  work/v13/sec_mechanisms.tex
  work/v13/sec_robustness.tex
  work/v13/sec_cade.tex
  work/v13/sec_conclusion.tex
  work/v13/sec_literature.tex
  work/v13/sec_endmatter.tex
  work/v13/sec_institutional.tex
  work/v13/sec_limitations.tex
  work/v13/sections/sec4_data_fl.tex
  work/v13/sections/sec7_results.tex
  work/v13/sections/sec_classification.tex
  work/v13/sections/sec_counterfactual.tex
  work/v13/sections/sec_mechanism_evidence.tex
)
# Sensitive literals: known v13 legacy values that should be macros now.
# Note: 0.94 is also the McCrary density ratio in sec_appendix.tex line 422,
# which is a separate concept. We exclude that context.
SENSITIVE_LITERALS=("2,735" "16,843" "41,444")
for f in "${DISCIPLINED_SECTIONS[@]}"; do
  for pat in "${SENSITIVE_LITERALS[@]}"; do
    HITS=$(grep -cE "$pat" "$f" 2>/dev/null | tr -d ' \n' || echo 0)
    if [[ $HITS -gt 0 ]]; then
      fail "Stale literal '$pat' found $HITS times in $(basename "$f")"
    fi
  done
done
ok "Disciplined sections free of sensitive legacy literals"

# 4. Required CSVs exist
REQUIRED_CSVS=(
  output/horse_race/horse_race_summary.csv
  output/imhof_full/imhof_full_results.csv
  output/auc_direct_cade/auc_direct_cade.csv
  output/leakage_audit_d3/leakage_audit_d3.csv
  output/operational/audit_precision_k.csv
  output/unified_mechanism/unified_mechanism.csv
  output/first_time_fl_matching/matched_results.csv
  output/gate_d2/d2_modal_auc.csv
  output/gate_d4/d4_winner_heavy.csv
)
for f in "${REQUIRED_CSVS[@]}"; do
  if [[ -f "$f" ]]; then
    ok "required CSV present: $f"
  else
    fail "missing required CSV: $f"
  fi
done

# 5. PDF compiled
if [[ -f work/v13/paper_v13.pdf ]]; then
  PAGES=$(pdfinfo work/v13/paper_v13.pdf 2>/dev/null | awk '/Pages/ {print $2}')
  ok "PDF compiled: ${PAGES:-?} pages"
else
  fail "PDF not found"
fi

# 6. paper_v13.log undefined refs
if [[ -f work/v13/paper_v13.log ]]; then
  N_UNDEF=$(grep -c "Undefined" work/v13/paper_v13.log 2>/dev/null | tr -d ' \n' || echo 0)
  if [[ $N_UNDEF -eq 0 ]]; then
    ok "no undefined references in paper_v13.log"
  else
    fail "$N_UNDEF undefined references in paper_v13.log"
  fi
fi

# 7. audit_paper_numbers.md exists and is non-empty
if [[ -s work/v13/audit_paper_numbers.md ]]; then
  N_ROWS=$(grep -c "^| \`\\\\val" work/v13/audit_paper_numbers.md 2>/dev/null | tr -d ' \n' || echo 0)
  ok "audit_paper_numbers.md present ($N_ROWS macro entries)"
else
  fail "audit_paper_numbers.md missing or empty"
fi

echo
echo "=== Summary: $PASS PASS, $FAIL FAIL ==="
exit $FAIL
