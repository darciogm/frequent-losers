#!/usr/bin/env Rscript
# scan_claims.R -- flag overclaiming / legally dangerous language in the
# manuscript source. Negation-aware: a phrase inside a disclaimer ("not proof",
# "does not detect") is downgraded. Output: outputs/diagnostics/claims_scan.csv.
# Does NOT edit the manuscript.

.dir <- function() { a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", grep("^--file=", a, value = TRUE))
  if (length(f)) dirname(normalizePath(f)) else getwd() }
ROOT  <- normalizePath(file.path(.dir(), "..", ".."))         # work/v22-editor
MSDIR <- file.path(ROOT, "submission_clean")
OUT   <- file.path(ROOT, "outputs", "diagnostics"); dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

files <- list.files(MSDIR, pattern = "\\.tex$", full.names = TRUE)
if (!length(files)) { message("scan_claims: NO .tex in ", MSDIR); quit(status = 0L) }

# phrase -> (default risk, default action). Matched case-insensitively.
phrases <- list(
  c("detects cartels",           "critical","replace"),
  c("cartel detector",           "critical","replace"),
  c("cartel detection",          "high",    "qualify"),
  c("cartel members",            "high",    "qualify"),
  c("cartel firms",              "high",    "qualify"),
  c("cartel-adjacent",           "medium",  "okay_if_defined"),
  c("proves",                    "high",    "qualify"),
  c("proof from award records",  "critical","replace"),
  c("legal proof",               "medium",  "verify"),
  c("liability",                 "medium",  "verify"),
  c("guilty",                    "critical","replace"),
  c("damages",                   "high",    "qualify"),
  c("overcharge",                "high",    "qualify"),
  c("causal price effect",       "critical","replace"),
  c("causal effect",             "high",    "qualify"),
  c("cover-bidding theater",     "high",    "qualify"),     # script 78: not identified
  c("cover-bidding mechanism",   "high",    "qualify"),
  c("cover bidding",             "medium",  "qualify"),
  c("depresses prices",          "high",    "qualify"),
  c("collusive firms",           "high",    "qualify"),
  c("fraudulent",                "critical","replace"),
  c("fraud",                     "critical","replace"),
  c("predicts cartel membership","critical","replace"),
  c("algorithmic detection",     "medium",  "qualify"),
  c("machine learning classifier","low",    "okay_if_defined"))

neg <- "\\b(not|no|never|without|cannot|can't|does not|do not|doesn't|don't|rather than|neither|nor|stops short of|short of)\\b"

rows <- list()
for (f in files) {
  ln <- readLines(f, warn = FALSE)
  for (p in phrases) {
    ph <- p[1]; risk <- p[2]; act <- p[3]
    hits <- grep(ph, ln, ignore.case = TRUE, fixed = FALSE)
    for (i in hits) {
      txt <- ln[i]
      # negation window: same line, or the ~40 chars around the phrase
      negated <- grepl(neg, txt, ignore.case = TRUE)
      r <- risk; a <- act
      if (negated && risk %in% c("critical","high")) { r <- "low"; a <- "okay_if_defined" }
      if (negated && risk == "medium")               { r <- "low"; a <- "okay_if_defined" }
      rows[[length(rows)+1]] <- data.frame(
        file = basename(f), line_number = i, phrase = ph,
        line_text = trimws(substr(txt, 1, 220)),
        risk_level = r, suggested_action = a,
        negated = negated, stringsAsFactors = FALSE)
    }
  }
}
res <- if (length(rows)) do.call(rbind, rows) else
  data.frame(file=character(), line_number=integer(), phrase=character(),
             line_text=character(), risk_level=character(),
             suggested_action=character(), negated=logical())
res <- res[order(factor(res$risk_level, levels=c("critical","high","medium","low")),
                 res$file, res$line_number), ]
utils::write.csv(res, file.path(OUT, "claims_scan.csv"), row.names = FALSE)
cat(sprintf("scan_claims: %d hit(s) across %d file(s) -> %s\n",
            nrow(res), length(files), file.path(OUT, "claims_scan.csv")))
tab <- table(factor(res$risk_level, levels=c("critical","high","medium","low")))
cat("  by risk:", paste(names(tab), tab, sep="=", collapse="  "),
    sprintf(" | negated/disclaimer: %d\n", sum(res$negated)))
