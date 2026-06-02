#!/usr/bin/env Rscript
# scan_refs.R -- internal citation consistency (NO online verification here).
# Finds \cite keys in the manuscript, keys defined in .bib, and cross-checks:
#   used-but-missing, defined-but-uncited, duplicate keys, placeholder-looking.
# Outputs: outputs/diagnostics/reference_scan.csv + reference_scan_summary.txt

.dir <- function() { a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", grep("^--file=", a, value = TRUE))
  if (length(f)) dirname(normalizePath(f)) else getwd() }
ROOT  <- normalizePath(file.path(.dir(), "..", ".."))
MSDIR <- file.path(ROOT, "submission_clean")
OUT   <- file.path(ROOT, "outputs", "diagnostics"); dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

tex <- list.files(MSDIR, pattern = "\\.tex$", full.names = TRUE)
bib <- list.files(MSDIR, pattern = "\\.bib$", full.names = TRUE)

# --- citation keys used in .tex (\cite, \citep, \citet, \citealp, etc.) ------
used <- character()
cite_rx <- "\\\\(cite[a-zA-Z]*|footcite[a-zA-Z]*)\\s*(\\[[^]]*\\])?\\s*\\{([^}]*)\\}"
for (f in tex) {
  ln <- paste(readLines(f, warn = FALSE), collapse = "\n")
  m <- gregexpr(cite_rx, ln, perl = TRUE)
  rr <- regmatches(ln, m)[[1]]
  for (r in rr) {
    keys <- sub(cite_rx, "\\3", r, perl = TRUE)
    used <- c(used, trimws(unlist(strsplit(keys, ","))))
  }
}
used <- used[used != ""]
used <- used[!grepl("#", used, fixed = TRUE)]   # drop \newcommand params (e.g. #1)
used_unique <- sort(unique(used))

# --- keys defined in .bib ----------------------------------------------------
defined <- character()
for (b in bib) {
  ln <- readLines(b, warn = FALSE)
  hits <- regmatches(ln, regexpr("^\\s*@\\w+\\s*\\{\\s*([^,]+)", ln, perl = TRUE))
  for (h in hits) defined <- c(defined, trimws(sub("^\\s*@\\w+\\s*\\{\\s*", "", h)))
}
dup_keys <- names(which(table(defined) > 1))
defined_unique <- sort(unique(defined))

used_missing  <- setdiff(used_unique, defined_unique)        # cited, not in bib
defined_uncited <- setdiff(defined_unique, used_unique)      # in bib, never cited
placeholder <- grep("(TODO|XXX|PLACEHOLDER|FIXME|tbd|temp|^ref[0-9]+$)",
                    defined_unique, ignore.case = TRUE, value = TRUE)

mk <- function(keys, status) if (length(keys))
  data.frame(key = keys, status = status, stringsAsFactors = FALSE) else
  data.frame(key=character(), status=character())
res <- rbind(
  mk(used_missing,    "used_but_missing_from_bib"),
  mk(defined_uncited, "defined_but_uncited"),
  mk(dup_keys,        "duplicate_bib_key"),
  mk(placeholder,     "possible_placeholder"))
utils::write.csv(res, file.path(OUT, "reference_scan.csv"), row.names = FALSE)

summ <- c(
  sprintf("Reference scan (internal only) -- %s", format(Sys.time())),
  sprintf("  .tex files scanned     : %d", length(tex)),
  sprintf("  .bib files scanned     : %d (%s)", length(bib), paste(basename(bib), collapse=", ")),
  sprintf("  distinct cite keys used: %d", length(used_unique)),
  sprintf("  distinct bib entries   : %d", length(defined_unique)),
  sprintf("  USED but MISSING (FIX) : %d  %s", length(used_missing),
          if (length(used_missing)) paste0("[", paste(used_missing, collapse=", "), "]") else ""),
  sprintf("  defined but uncited    : %d", length(defined_uncited)),
  sprintf("  duplicate bib keys     : %d  %s", length(dup_keys),
          if (length(dup_keys)) paste0("[", paste(dup_keys, collapse=", "), "]") else ""),
  sprintf("  possible placeholders  : %d  %s", length(placeholder),
          if (length(placeholder)) paste0("[", paste(placeholder, collapse=", "), "]") else ""))
writeLines(summ, file.path(OUT, "reference_scan_summary.txt"))
cat(paste(summ, collapse = "\n"), "\n")
cat("-> ", file.path(OUT, "reference_scan.csv"), "\n")
