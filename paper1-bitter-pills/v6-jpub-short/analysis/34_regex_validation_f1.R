#  =============================================================================
#  34_regex_validation_f1.R --- Compute precision, recall, F1 per class from
#  the hand-labeled validation_sample.csv.
#
#  Inputs  : v6-jpub-short/output/validation/validation_sample.csv
#            (must have column true_class populated with 0/1/2 for each row)
#
#  Outputs : v6-jpub-short/output/validation/tab_regex_f1.tex
#            (a compact LaTeX table with confusion matrix and per-class
#            precision, recall, F1)
#            Also prints a summary to stdout for quick copy into the body
#            footnote in DataAndSample.tex.
#  =============================================================================

cat("=== 34_regex_validation_f1.R ===\n")

suppressPackageStartupMessages({
  library(data.table)
})
setDTthreads(12L)

OUT <- "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/v6-jpub-short/output/validation"
csv <- file.path(OUT, "validation_sample.csv")

if (!file.exists(csv)) stop("Validation file not found: ", csv,
                            ". Run 33_regex_validation_sample.R first.")

d <- fread(csv)
n <- nrow(d)
n_labeled <- sum(!is.na(d$true_class))
cat(sprintf("Loaded %d rows; %d labeled (%.0f%%)\n",
            n, n_labeled, 100 * n_labeled / n))

if (n_labeled < n) {
  cat(sprintf("WARNING: %d rows still un-labeled (true_class is NA).\n",
              n - n_labeled),
      "         Proceeding on the labeled subset. Fill in the remaining\n",
      "         rows and re-run for the final table.\n", sep = "")
  d <- d[!is.na(true_class)]
}
if (nrow(d) == 0) stop("No labeled rows --- nothing to compute.")

# Force integer types
d[, predicted_class := as.integer(predicted_class)]
d[, true_class      := as.integer(true_class)]

valid <- d[predicted_class %in% 0:2 & true_class %in% 0:2]
if (nrow(valid) < nrow(d)) {
  cat(sprintf("Dropped %d rows with out-of-range class codes.\n",
              nrow(d) - nrow(valid)))
}
d <- valid

# ---------------------------------------------------------------------------
# Confusion matrix
# ---------------------------------------------------------------------------
class_name <- c("Ordinary", "Administrative", "Litigated")
cm <- table(predicted = factor(d$predicted_class, levels = 0:2, labels = class_name),
            truth     = factor(d$true_class,      levels = 0:2, labels = class_name))
cat("\nConfusion matrix (rows = predicted, cols = truth):\n")
print(cm)

# ---------------------------------------------------------------------------
# Per-class precision, recall, F1
# ---------------------------------------------------------------------------
metrics <- function(cm, k) {
  tp <- cm[k, k]
  fp <- sum(cm[k, ]) - tp   # predicted k, truth not k
  fn <- sum(cm[, k]) - tp   # truth k, predicted not k
  prec <- if (tp + fp > 0) tp / (tp + fp) else NA_real_
  rec  <- if (tp + fn > 0) tp / (tp + fn) else NA_real_
  f1   <- if (!is.na(prec) && !is.na(rec) && (prec + rec) > 0)
    2 * prec * rec / (prec + rec) else NA_real_
  list(tp = tp, fp = fp, fn = fn, precision = prec, recall = rec, f1 = f1)
}

results <- rbindlist(lapply(seq_along(class_name), function(k) {
  m <- metrics(cm, k)
  data.table(class = class_name[k], tp = m$tp, fp = m$fp, fn = m$fn,
             precision = m$precision, recall = m$recall, f1 = m$f1)
}))

# Macro-average and overall accuracy
macro_p  <- mean(results$precision, na.rm = TRUE)
macro_r  <- mean(results$recall,    na.rm = TRUE)
macro_f1 <- mean(results$f1,        na.rm = TRUE)
acc      <- sum(diag(cm)) / sum(cm)

cat("\nPer-class metrics:\n")
print(results[, .(class, precision = round(precision, 3),
                  recall = round(recall, 3), f1 = round(f1, 3))])
cat(sprintf("\nMacro-average F1: %.3f\n", macro_f1))
cat(sprintf("Overall accuracy: %.3f\n", acc))

# ---------------------------------------------------------------------------
# Emit LaTeX table
# ---------------------------------------------------------------------------
fmt <- function(x) formatC(x, format = "f", digits = 3)
tex <- c(
"\\begin{table}[ht]",
"  \\centering",
sprintf("  \\caption{Regex Classifier Validation on a Hand-Labeled Sample of %d Tender Notices}", sum(cm)),
"  \\label{tab:regex_f1}",
"  \\small",
"  \\begin{threeparttable}",
"  \\begin{tabular}{lcccccc}",
"    \\toprule",
"    & \\multicolumn{3}{c}{Confusion matrix} & & & \\\\",
"    \\cmidrule(lr){2-4}",
"    Class (truth) & Ord. & Admin. & Lit. & Precision & Recall & F1 \\\\",
"    \\midrule")
for (k in seq_len(nrow(results))) {
  cls <- results$class[k]
  row <- sprintf("    %s (%d) & %d & %d & %d & %s & %s & %s \\\\",
                 cls, sum(cm[, k]),
                 cm[k, 1], cm[k, 2], cm[k, 3],
                 fmt(results$precision[k]), fmt(results$recall[k]),
                 fmt(results$f1[k]))
  tex <- c(tex, row)
}
tex <- c(tex,
"    \\midrule",
sprintf("    \\multicolumn{6}{r}{Macro-average F1:} & %s \\\\", fmt(macro_f1)),
sprintf("    \\multicolumn{6}{r}{Overall accuracy:} & %s \\\\", fmt(acc)),
"    \\bottomrule",
"  \\end{tabular}",
"  \\begin{tablenotes}",
"    \\small",
"    \\item \\textit{Notes:} Stratified random sample of tender-notice",
"    subjects drawn from the BEC-G65 corpus, with equal representation",
"    across the three predicted classes. Rows of the confusion matrix",
"    show the predicted distribution for each true class. Precision,",
"    recall, and F1 are reported per class; the macro-average F1",
"    averages the per-class F1 with equal weight. Labels assigned by",
"    the authors.",
"  \\end{tablenotes}",
"  \\end{threeparttable}",
"\\end{table}",
"")

writeLines(tex, file.path(OUT, "tab_regex_f1.tex"))
cat("\nSaved: ", file.path(OUT, "tab_regex_f1.tex"), "\n", sep = "")

# ---------------------------------------------------------------------------
# Body-footnote one-liner for DataAndSample.tex
# ---------------------------------------------------------------------------
cat("\nFootnote text for DataAndSample.tex (copy into existing F1 footnote):\n")
cat(sprintf('"A hand-labeled validation sample of %d notices yields F1 = %s (ordinary), %s (administrative), %s (litigated); macro-average F1 = %s; overall accuracy = %s. Details in Online Appendix Table~\\ref{tab:regex_f1}."\n',
            sum(cm),
            fmt(results$f1[1]), fmt(results$f1[2]), fmt(results$f1[3]),
            fmt(macro_f1), fmt(acc)))

cat("\n=== 34_regex_validation_f1.R complete ===\n")
