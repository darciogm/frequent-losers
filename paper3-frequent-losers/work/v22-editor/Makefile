# =============================================================================
# Makefile -- JLEO R&R (v22) orchestration for "Cheap Signals, Costly Proof".
# Root: paper3-frequent-losers/work/v22-editor/
# Safe by design: only clean_outputs removes files, and only inside
# outputs/cache and outputs/diagnostics. Substantive analysis scripts live in
# the SHARED pipeline ../../scripts (flat numbered convention); this Makefile
# orchestrates the v22 reproducibility/diagnostics layer + documents builds.
# =============================================================================
R        := Rscript
DIAG     := scripts/diagnostics
BUILD    := scripts/build
UTILS    := scripts/utils
MSDIR    := submission_clean
SHARED   := ../../scripts
OUTDIR   := outputs

.PHONY: all audit diagnostics tables figures manuscript clean_outputs jleo_rr_status help

help:
	@echo "Targets: audit | diagnostics | tables | figures | manuscript | clean_outputs | jleo_rr_status"

all: diagnostics audit

# ---- diagnostics: scanners + metrics toy test (lightweight) -----------------
diagnostics:
	@echo "== metrics toy test =="     ; $(R) $(DIAG)/test_metrics_triage.R
	@echo "== claims scanner =="        ; $(R) $(DIAG)/scan_claims.R
	@echo "== number scanner =="        ; $(R) $(DIAG)/scan_numbers.R
	@echo "== reference scanner =="     ; $(R) $(DIAG)/scan_refs.R
	@echo "== alt-text scanner =="      ; $(R) $(DIAG)/scan_alt_text.R
	@echo "diagnostics -> $(OUTDIR)/diagnostics/"

# ---- audit: regenerate registries + point at infra log ----------------------
audit:
	@$(R) $(BUILD)/make_registries.R
	@echo "infra log: docs/jleo_rr_revision/07_REPRODUCIBILITY_INFRASTRUCTURE_LOG.md"
	@echo "registries: $(OUTDIR)/output_registry.csv  $(OUTDIR)/dataset_registry.csv"

# ---- tables / figures: placeholders until section prompts wire scripts -------
# Substantive table/figure generation is per-section (Prompts 3-11) and calls
# the shared ../../scripts pipeline. Left as documented placeholders.
tables:
	@echo "PLACEHOLDER: per-section table builds (Prompts 3-11)."
	@echo "  e.g. (cd ../.. && Rscript scripts/79_label_funnel.R)  # Table A"
	@echo "  Generated CSVs live in ../../output/<module>/ ; LaTeX assembled into $(OUTDIR)/tables/."

figures:
	@echo "PLACEHOLDER: per-section figure builds (Prompts 3-11)."
	@echo "  e.g. (cd ../.. && Rscript scripts/56_regulatory_cost_frontier.R)  # cost-recall (NOT YET RUN)"

# ---- manuscript: known compile sequence (natbib/bibtex; appendix before paper
# for xr cross-refs). NOT run automatically; invoke manually when ready. --------
manuscript:
	@echo "Manuscript build (run manually in $(MSDIR)):"
	@echo "  cd $(MSDIR)"
	@echo "  pdflatex online_appendix_submission_clean && bibtex online_appendix_submission_clean && pdflatex online_appendix_submission_clean"
	@echo "  pdflatex paper_submission_clean && bibtex paper_submission_clean && pdflatex paper_submission_clean && pdflatex paper_submission_clean"
	@echo "  (appendix FIRST so paper xr refs resolve; uses natbib/bibtex, NOT biber)"

# ---- clean_outputs: ONLY cache + diagnostics (safe) -------------------------
clean_outputs:
	@echo "Removing regenerable diagnostics + cache (safe)..."
	@rm -f  $(OUTDIR)/diagnostics/*.csv $(OUTDIR)/diagnostics/*.txt
	@rm -rf $(OUTDIR)/cache/*
	@echo "Done. (Registries, tables/, figures/ preserved; analysis ../../output untouched.)"

# ---- status dashboard -------------------------------------------------------
jleo_rr_status:
	@echo "===== JLEO R&R STATUS (v22) ====="
	@printf "branch       : "; git -C ../.. rev-parse --abbrev-ref HEAD
	@printf "paper3 dirty : "; git -C ../.. status --short -- . | wc -l
	@echo   "--- planned/blocked outputs (output_registry) ---"
	@$(R) -e 'd<-read.csv("$(OUTDIR)/output_registry.csv"); x<-d[d$$status!="existing_current",c("output_id","notes")]; print(x,row.names=FALSE)' 2>/dev/null || echo "  (run make audit first)"
	@echo   "--- blockers ---"
	@echo   "  B1 cobidder-def inconsistency (U2 RESOLVED: disclose+robustness)"
	@echo   "  B3 cade_fl_cobidders.csv has NO builder on disk"
	@echo   "  56 regulatory_frontier EMPTY; 80 LOCO + 81 survival not written"
	@echo   "--- diagnostics ---"; ls -1 $(OUTDIR)/diagnostics/ 2>/dev/null | sed 's/^/  /'
