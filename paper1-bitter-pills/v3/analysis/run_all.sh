#!/bin/bash
set -e

STATA="stata-se -b -q do"
BASEDIR="/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills"
cd "$BASEDIR"

echo "=== V3 Analysis Pipeline ==="
echo "Started: $(date)"
echo ""

# Phase 1: Data Preparation (must complete first)
echo "=== Phase 1: Data Preparation ==="
$STATA v3/analysis/00_prepare_data.do
if grep -q "^r(" 00_prepare_data.log 2>/dev/null; then
    echo "ERROR in data preparation! Aborting."
    cat 00_prepare_data.log | tail -20
    exit 1
fi
echo "Data preparation complete."
echo ""

# Phase 2: All analyses in parallel
echo "=== Phase 2: Running all analyses in parallel ==="

$STATA v3/analysis/01_desc_stats.do &
PID1=$!
echo "  01_desc_stats.do started (PID $PID1)"

$STATA v3/analysis/02_balance_table.do &
PID2=$!
echo "  02_balance_table.do started (PID $PID2)"

$STATA v3/analysis/03_main_regressions.do &
PID3=$!
echo "  03_main_regressions.do started (PID $PID3)"

$STATA v3/analysis/04_heterogeneity.do &
PID4=$!
echo "  04_heterogeneity.do started (PID $PID4)"

$STATA v3/analysis/05_fiscal_costs.do &
PID5=$!
echo "  05_fiscal_costs.do started (PID $PID5)"

$STATA v3/analysis/06_robustness.do &
PID6=$!
echo "  06_robustness.do started (PID $PID6)"

$STATA v3/analysis/07_graphs.do &
PID7=$!
echo "  07_graphs.do started (PID $PID7)"

echo ""
echo "Waiting for all analyses to complete..."
wait
echo "All analyses finished."
echo ""

# Phase 3: Check for errors
echo "=== Phase 3: Error Check ==="
ERRORS=0
for f in 00_prepare_data.log 01_desc_stats.log 02_balance_table.log \
         03_main_regressions.log 04_heterogeneity.log 05_fiscal_costs.log \
         06_robustness.log 07_graphs.log; do
    if [ -f "$f" ]; then
        if grep -q "^r(" "$f" 2>/dev/null; then
            echo "  ERROR in $f"
            grep "^r(" "$f"
            ERRORS=$((ERRORS + 1))
        else
            echo "  OK: $f"
        fi
    else
        echo "  MISSING: $f"
        ERRORS=$((ERRORS + 1))
    fi
done

echo ""
if [ $ERRORS -eq 0 ]; then
    echo "=== ALL SCRIPTS COMPLETED SUCCESSFULLY ==="
else
    echo "=== $ERRORS SCRIPT(S) HAD ERRORS ==="
fi

# Phase 4: Verify outputs
echo ""
echo "=== Output Verification ==="
echo "RTF files:"
ls -la v3/results/*.rtf 2>/dev/null | wc -l
echo " RTF files found"

echo "PDF graphs:"
ls -la v3/graphs/*.pdf 2>/dev/null | wc -l
echo " PDF files found"

echo "LaTeX tables:"
ls -la v3/manuscript/*.tex 2>/dev/null | wc -l
echo " TEX files found"

echo ""
echo "Finished: $(date)"
