#!/usr/bin/env Rscript
# scan_numbers.R -- locate key result numbers in the manuscript source so later
# reconciliation can check them against generated outputs / macros. Reports
# whether a number is hard-typed vs sits next to a \val... macro on the line.
# Output: outputs/diagnostics/number_scan.csv. Does NOT change numbers.

.dir <- function() { a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", grep("^--file=", a, value = TRUE))
  if (length(f)) dirname(normalizePath(f)) else getwd() }
ROOT  <- normalizePath(file.path(.dir(), "..", ".."))
MSDIR <- file.path(ROOT, "submission_clean")
OUT   <- file.path(ROOT, "outputs", "diagnostics"); dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
files <- list.files(MSDIR, pattern = "\\.tex$", full.names = TRUE)

# pattern -> (regex, likely table/claim). \\b and escaped dots; %% avoids comments.
patt <- list(
  list("193",  "\\b193\\b",       "cobidders (primary target)"),
  list("210",  "\\b210\\b",       "conservative AL cobidders"),
  list("2735", "\\b2[,.]?735\\b", "FL firms"),
  list("16.2", "\\b16\\.2\\b",    "FL rate among always-losers (%)"),
  list("16843","\\b16[,.]?843\\b","always-losers universe"),
  list("41444","\\b41[,.]?444\\b","all BEC firms"),
  list("47",   "\\b47\\b",        "direct CADE defendants"),
  list("65",   "\\b65\\b",        "CADE rows / cases"),
  list("12 cases","\\b12\\s+cases\\b","CADE cases"),
  list("4 cases", "\\b4\\s+cases\\b", "conservative cases"),
  list("30",   "\\b30\\b",        "conservative defendants (DROP->19)"),
  list("131",  "\\b131\\b",       "gatekeeper TP recovered"),
  list("83%",  "\\b83\\s*\\\\?%", "gatekeeper pool reduction"),
  list("0.924","\\b0\\.924\\b",   "FL14 firm-level AUC"),
  list("0.921","\\b0\\.921\\b",   "AUC (CV pool / Imhof+FL bin)"),
  list("0.888","\\b0\\.888\\b",   "Imhof full AUC"),
  list("0.962","\\b0\\.962\\b",   "Imhof+TC combo AUC"),
  list("0.748","\\b0\\.748\\b",   "pre/post AUC"),
  list("0.864","\\b0\\.864\\b",   "temporal-holdout AUC"),
  list("0.767","\\b0\\.767\\b",   "strict-train binary AUC"),
  list("0.750","\\b0\\.750\\b",   "strict-train continuous AUC"),
  list("0.064","\\b0\\.064\\b",   "OLS price coef (legacy)"),
  list("0.068","\\b0\\.068\\b",   "MDE / price coef"),
  list("-0.097","-?0\\.097\\b",   "price coef"),
  list("0.041","\\b0\\.041\\b",   "exposure increment-ish / SE"),
  list("11676","\\b11[,.]?676\\b","Imhof same-sample N"),
  list("2000", "\\b2[,.]?000\\b", "permutation B / k-grid"),
  list("1000", "\\b1[,.]?000\\b", "k / precision@1000"))

rows <- list()
for (f in files) {
  ln <- readLines(f, warn = FALSE)
  # strip full-line comments to avoid false hits; keep inline text
  for (p in patt) {
    id <- p[[1]]; rx <- p[[2]]; claim <- p[[3]]
    hits <- grep(rx, ln, perl = TRUE)
    for (i in hits) {
      txt <- ln[i]
      if (grepl("^\\s*%", txt)) next                     # skip comment lines
      has_macro <- grepl("\\\\val[A-Za-z]+", txt)
      rows[[length(rows)+1]] <- data.frame(
        file = basename(f), line_number = i, number_or_pattern = id,
        line_text = trimws(substr(txt, 1, 220)),
        likely_table_or_claim = claim,
        consistency_risk = if (has_macro) "low_macro_bound" else "check_hardcoded",
        notes = if (has_macro) "macro present on line" else "raw literal in prose/table",
        stringsAsFactors = FALSE)
    }
  }
}
res <- if (length(rows)) do.call(rbind, rows) else
  data.frame(file=character(), line_number=integer(), number_or_pattern=character(),
             line_text=character(), likely_table_or_claim=character(),
             consistency_risk=character(), notes=character())
res <- res[order(res$consistency_risk, res$number_or_pattern, res$file), ]
utils::write.csv(res, file.path(OUT, "number_scan.csv"), row.names = FALSE)
cat(sprintf("scan_numbers: %d hit(s) -> %s\n", nrow(res), file.path(OUT, "number_scan.csv")))
cat(sprintf("  hardcoded(check)=%d  macro_bound=%d\n",
            sum(res$consistency_risk=="check_hardcoded"),
            sum(res$consistency_risk=="low_macro_bound")))
