#!/usr/bin/env bash
# =============================================================================
# run_all.sh — Master replication script
# Bitter Pills to Swallow: The Enforcement Costs of Health Litigation
# Genicolo-Martins & Azevedo (2026)
#
# This script replicates all tables, figures, and the manuscript PDF.
# Runtime: ~10-15 minutes on a 16-core machine with 16GB RAM.
#
# Usage:
#   cd replication/
#   bash code/run_all.sh
# =============================================================================

set -euo pipefail

# --- Configuration ----------------------------------------------------------
NCORES=$(nproc)
REPL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CODE_DIR="${REPL_DIR}/code"
DATA_DIR="${REPL_DIR}/data"
OUTPUT_DIR="${REPL_DIR}/output"
MANUSCRIPT_DIR="${REPL_DIR}/manuscript"
LOG_DIR="${REPL_DIR}/logs"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Functions --------------------------------------------------------------
log_info()  { echo -e "${BLUE}[INFO]${NC}  $(date '+%H:%M:%S') $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $(date '+%H:%M:%S') $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $(date '+%H:%M:%S') $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $(date '+%H:%M:%S') $*"; }

check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        log_error "$1 is required but not installed."
        return 1
    fi
}

run_r_script() {
    local script="$1"
    local name=$(basename "$script")
    local t_start=$(date +%s)
    log_info "Running: ${name}"
    if Rscript "$script" > "${LOG_DIR}/${name%.R}.log" 2>&1; then
        local t_end=$(date +%s)
        log_ok "${name} completed in $((t_end - t_start))s"
    else
        local t_end=$(date +%s)
        log_error "${name} FAILED after $((t_end - t_start))s — see ${LOG_DIR}/${name%.R}.log"
        return 1
    fi
}

# --- Banner -----------------------------------------------------------------
echo ""
echo "============================================================="
echo "  Bitter Pills to Swallow — Replication Package"
echo "  Genicolo-Martins & Azevedo (2026)"
echo "============================================================="
echo "  Machine: $(uname -n) | Cores: ${NCORES} | RAM: $(free -h | awk '/Mem:/{print $2}')"
echo "  Start time: $(date)"
echo "============================================================="
echo ""

T_GLOBAL_START=$(date +%s)

# --- Step 0: Check prerequisites --------------------------------------------
log_info "Checking prerequisites..."

DEPS_OK=true
for dep in Rscript pdflatex bibtex; do
    if check_dependency "$dep"; then
        log_ok "  Found: $dep ($(which $dep))"
    else
        DEPS_OK=false
    fi
done

if [ "$DEPS_OK" = false ]; then
    log_error "Missing dependencies. Please install them and retry."
    exit 1
fi

# Check R packages
log_info "Checking R packages..."
Rscript -e '
pkgs <- c("data.table", "fixest", "modelsummary", "ggplot2", "arrow",
          "knitr", "scales", "haven", "sf", "geobr", "sidrar")
missing <- pkgs[!sapply(pkgs, requireNamespace, quietly = TRUE)]
if (length(missing) > 0) {
  cat("Installing missing R packages:", paste(missing, collapse=", "), "\n")
  install.packages(missing, repos = "https://cloud.r-project.org", Ncpus = '"${NCORES}"')
}
cat("All R packages available.\n")
' > "${LOG_DIR}/00_check_packages.log" 2>&1
log_ok "R packages verified."

# --- Step 1: Verify data ----------------------------------------------------
log_info "Verifying input data..."

if [ ! -f "${DATA_DIR}/BEC-G65-WORK1.parquet" ]; then
    log_error "Input data not found: ${DATA_DIR}/BEC-G65-WORK1.parquet"
    log_error "Please place the dataset in the data/ directory."
    log_error "See README.md for data availability information."
    exit 1
fi

DATA_SIZE=$(du -sh "${DATA_DIR}/BEC-G65-WORK1.parquet" | cut -f1)
log_ok "Input data found (${DATA_SIZE})"

# --- Step 2: Create output directories --------------------------------------
mkdir -p "${OUTPUT_DIR}/tables" "${OUTPUT_DIR}/figures" "${LOG_DIR}"
log_ok "Output directories ready."

# --- Step 3: Run R analysis pipeline ----------------------------------------
log_info "===== PHASE 1: Data Preparation ====="

run_r_script "${CODE_DIR}/00_prepare_data.R"

log_info "===== PHASE 2: Analysis (sequential — fixest uses ${NCORES} OpenMP threads) ====="

# These must run sequentially because fixest uses all cores internally
for script in \
    "${CODE_DIR}/01_desc_stats.R" \
    "${CODE_DIR}/02_balance_table.R" \
    "${CODE_DIR}/03_main_regressions.R" \
    "${CODE_DIR}/04_heterogeneity.R" \
    "${CODE_DIR}/05_fiscal_costs.R" \
    "${CODE_DIR}/06_robustness.R"; do
    run_r_script "$script"
done

log_info "===== PHASE 3: Figures (sequential) ====="

for script in \
    "${CODE_DIR}/07_graphs.R" \
    "${CODE_DIR}/08_pub_tables.R" \
    "${CODE_DIR}/09_pub_figures.R" \
    "${CODE_DIR}/10_map_litigation.R" \
    "${CODE_DIR}/11_map_pbu.R" \
    "${CODE_DIR}/12_fig_purchase_types.R" \
    "${CODE_DIR}/13_map_litigation_total.R" \
    "${CODE_DIR}/14_map_litigation_ratio.R" \
    "${CODE_DIR}/15_admin_figures.R" \
    "${CODE_DIR}/16_v7_extensions.R"; do
    run_r_script "$script"
done

# --- Step 4: Verify outputs ------------------------------------------------
log_info "===== PHASE 4: Verifying Outputs ====="

N_TABLES=$(find "${OUTPUT_DIR}/tables" -name "*.tex" 2>/dev/null | wc -l)
N_FIGURES=$(find "${OUTPUT_DIR}/figures" -name "*.pdf" 2>/dev/null | wc -l)

log_info "Tables generated: ${N_TABLES} (expected: 26)"
log_info "Figures generated: ${N_FIGURES} (expected: 20)"

if [ "$N_TABLES" -lt 26 ]; then
    log_warn "Fewer tables than expected. Check logs for errors."
fi
if [ "$N_FIGURES" -lt 20 ]; then
    log_warn "Fewer figures than expected. Check logs for errors."
fi

# --- Step 5: Compile manuscript ---------------------------------------------
log_info "===== PHASE 5: Compiling Manuscript ====="

cd "${MANUSCRIPT_DIR}"
log_info "Running pdflatex (pass 1/3)..."
pdflatex -interaction=nonstopmode -jobname=Bitter-Pills_v7 main.tex > "${LOG_DIR}/pdflatex_1.log" 2>&1 || true
log_info "Running bibtex..."
bibtex Bitter-Pills_v7 > "${LOG_DIR}/bibtex.log" 2>&1 || true
log_info "Running pdflatex (pass 2/3)..."
pdflatex -interaction=nonstopmode -jobname=Bitter-Pills_v7 main.tex > "${LOG_DIR}/pdflatex_2.log" 2>&1 || true
log_info "Running pdflatex (pass 3/3)..."
pdflatex -interaction=nonstopmode -jobname=Bitter-Pills_v7 main.tex > "${LOG_DIR}/pdflatex_3.log" 2>&1 || true

if [ -f "Bitter-Pills_v7.pdf" ]; then
    PAGES=$(pdfinfo Bitter-Pills_v7.pdf 2>/dev/null | grep "Pages:" | awk '{print $2}' || echo "?")
    log_ok "Manuscript compiled: Bitter-Pills_v7.pdf (${PAGES} pages)"
else
    log_error "Manuscript compilation failed. Check ${LOG_DIR}/pdflatex_*.log"
fi

cd "${REPL_DIR}"

# --- Summary ----------------------------------------------------------------
T_GLOBAL_END=$(date +%s)
T_TOTAL=$((T_GLOBAL_END - T_GLOBAL_START))

echo ""
echo "============================================================="
echo "  REPLICATION COMPLETE"
echo "============================================================="
echo "  Total time: ${T_TOTAL}s ($((T_TOTAL / 60))m $((T_TOTAL % 60))s)"
echo "  Tables:     ${N_TABLES} .tex files in output/tables/"
echo "  Figures:    ${N_FIGURES} .pdf files in output/figures/"
echo "  Manuscript: manuscript/Bitter-Pills_v7.pdf"
echo "============================================================="
echo ""
echo "  To view the manuscript:"
echo "    wslview manuscript/Bitter-Pills_v7.pdf    # WSL"
echo "    open manuscript/Bitter-Pills_v7.pdf       # macOS"
echo "    xdg-open manuscript/Bitter-Pills_v7.pdf   # Linux"
echo ""
