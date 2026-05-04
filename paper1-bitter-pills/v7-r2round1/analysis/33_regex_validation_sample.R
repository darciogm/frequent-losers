#  33_regex_validation_sample.R --- Stratified sample of tender-notice subjects
#  for hand-labeling the regex-based purchase-type classifier.
#
#  Produces: v7-r2round1/output/validation/validation_sample.csv
#  Columns:
#    sample_id       sequential 1..500
#    po_subject      tender-notice text (the regex input)
#    predicted_class integer (0 = ordinary, 1 = administrative, 2 = litigated)
#    predicted_name  human-readable label
#    true_class      EMPTY --- fill with 0/1/2 by hand
#    notes           EMPTY --- optional free text (borderline, unclear, etc.)
#
#  After labeling, run 34_regex_validation_f1.R to compute precision, recall,
#  and F1 per class plus the confusion matrix, and to emit tab_regex_f1.tex
#  for Online Appendix A.8.


suppressPackageStartupMessages({
  library(data.table)
})
setDTthreads(12L)

.this_dir <- (function() {
  for (i in seq_len(sys.nframe())) {
    f <- tryCatch(sys.frame(i)$ofile, error = function(e) NULL)
    if (!is.null(f)) return(normalizePath(dirname(f)))
  }
  args <- commandArgs(trailingOnly = FALSE)
  fa <- grep("^--file=", args, value = TRUE)
  if (length(fa)) return(normalizePath(dirname(sub("^--file=", "", fa[1]))))
  getwd()
})()
source(file.path(.this_dir, "_macros.R"))

# Reproducibility
SEED <- 20260417L
set.seed(SEED)

# Target sample size
TARGET_PER_CLASS <- 167L   # 167 + 167 + 167 = 501, capped to 500 below
N_CAP            <- 500L

OUT <- "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/v7-r2round1/output/validation"
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

# Load & deduplicate at subject level
# The regex classifier operates on tender-notice text (po_subject). Multiple
# POIs share the same notice, so we sample unique (subject, predicted_class)
# pairs --- each row is one classification decision.
cat("Loading cache...\n")
dt <- readRDS("/tmp/v4_prepared.rds")
dt <- as.data.table(dt)

dt <- dt[!is.na(po_subject) & po_subject != "N/A" & nchar(po_subject) >= 10]
cat("Rows with usable po_subject:", nrow(dt), "\n")

# For each unique subject, take the modal predicted class (regex classifies at
# subject level; in theory no variation across POIs of the same subject, but
# a few edge cases exist with ambiguous free text).
subject_predictions <- dt[, .(
  predicted_class = as.integer(names(sort(table(purchase_type), decreasing = TRUE))[1]),
  n_pois          = .N
), by = po_subject]

cat("\nUnique subjects by predicted class:\n")
print(subject_predictions[, .N, keyby = predicted_class])

# Stratified sample
take_sample <- function(df, k) {
  if (nrow(df) <= k) return(df)
  df[sample(.N, k)]
}

sampled <- rbindlist(list(
  take_sample(subject_predictions[predicted_class == 0], TARGET_PER_CLASS),
  take_sample(subject_predictions[predicted_class == 1], TARGET_PER_CLASS),
  take_sample(subject_predictions[predicted_class == 2], TARGET_PER_CLASS)
))

# Cap at 500 and scramble order so labeler doesn't anchor on one class at a time
sampled <- sampled[sample(.N)][seq_len(min(.N, N_CAP))]
sampled[, sample_id := seq_len(.N)]

# Human-readable class labels + empty true_class
class_name <- c("0" = "ordinary", "1" = "administrative", "2" = "litigated")
sampled[, predicted_name := class_name[as.character(predicted_class)]]
sampled[, true_class     := NA_integer_]
sampled[, notes          := NA_character_]

setcolorder(sampled, c("sample_id", "po_subject", "predicted_class",
                       "predicted_name", "true_class", "notes", "n_pois"))

# Write -- but never clobber an existing file that already carries hand-labels
out_path <- file.path(OUT, "validation_sample.csv")
if (file.exists(out_path)) {
  existing <- tryCatch(fread(out_path), error = function(e) NULL)
  has_labels <- !is.null(existing) &&
                "true_class" %in% names(existing) &&
                any(!is.na(existing$true_class) &
                    nchar(as.character(existing$true_class)) > 0,
                    na.rm = TRUE)
  if (has_labels) {
    cat("\nExisting validation_sample.csv has hand-labels; refusing to overwrite.\n",
        "If you want to redraw, move the existing file aside first.\n",
        sep = "")
    quit(save = "no", status = 0)
  }
}
fwrite(sampled, out_path)
cat(sprintf("\nWrote %d rows to: %s\n", nrow(sampled), out_path))

cat("\nPredicted-class distribution in sample:\n")
print(sampled[, .N, keyby = predicted_class])

# Instructions for the human grader
cat("\nNext steps\n",
    "1. Open validation_sample.csv in a spreadsheet (Excel, LibreOffice, Numbers).\n",
    "2. For each row, read po_subject and fill true_class with:\n",
    "     0 = ordinary (ordinary procurement, no court order, no admin mechanism)\n",
    "     1 = administrative (urgent request via admin channel, no court)\n",
    "     2 = litigated (reference to court order, lawsuit, or judicial mandate)\n",
    "   Use notes column for borderline cases.\n",
    "3. Save the file back as validation_sample.csv (keep the column order).\n",
    "4. Run: Rscript v7-r2round1/analysis/34_regex_validation_f1.R\n",
    "   to compute F1 per class and emit tab_regex_f1.tex for OA A.8.\n",
    sep = "")


# Emit macros (sample-design constants; F1 itself comes from script 34)
bp_macros_emit("33_regex_validation_sample", list(
  regexNotices  = bp_fmt_int(min(nrow(sampled), N_CAP)),
  regexPerClass = bp_fmt_int(TARGET_PER_CLASS)
))

cat("\n33_regex_validation_sample.R complete\n")
