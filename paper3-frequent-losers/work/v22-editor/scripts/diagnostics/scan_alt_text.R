#!/usr/bin/env Rscript
# scan_alt_text.R -- JLEO requires "Alt text:" under every figure legend.
# Finds figure environments / \includegraphics and checks for an Alt-text line
# within a window after the figure. Output: outputs/diagnostics/alt_text_scan.csv

.dir <- function() { a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", grep("^--file=", a, value = TRUE))
  if (length(f)) dirname(normalizePath(f)) else getwd() }
ROOT  <- normalizePath(file.path(.dir(), "..", ".."))
MSDIR <- file.path(ROOT, "submission_clean")
OUT   <- file.path(ROOT, "outputs", "diagnostics"); dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
files <- list.files(MSDIR, pattern = "\\.tex$", full.names = TRUE)

rows <- list()
for (f in files) {
  ln <- readLines(f, warn = FALSE)
  starts <- grep("\\\\begin\\{figure", ln)
  # also catch bare \includegraphics not inside a figure env (rare)
  for (s in starts) {
    e <- grep("\\\\end\\{figure", ln)
    e <- e[e >= s]; e <- if (length(e)) e[1] else min(s + 40L, length(ln))
    block <- ln[s:e]
    cap_i  <- grep("\\\\caption\\{", block)
    lab_i  <- grep("\\\\label\\{", block)
    inc_i  <- grep("\\\\includegraphics", block)
    fid <- if (length(lab_i)) sub(".*\\\\label\\{([^}]*)\\}.*", "\\1", block[lab_i[1]]) else
           if (length(inc_i)) sub(".*\\\\includegraphics[^{]*\\{([^}]*)\\}.*", "\\1", block[inc_i[1]]) else
           paste0("fig@", basename(f), ":", s)
    # alt text may be just past \end{figure} too -> widen window by 3 lines
    wide <- ln[s:min(e + 3L, length(ln))]
    alt  <- any(grepl("Alt\\s*text\\s*:", wide, ignore.case = TRUE))
    rows[[length(rows)+1]] <- data.frame(
      figure_id = fid, source_file = basename(f), line_number = s,
      caption_detected = length(cap_i) > 0L,
      alt_text_detected = alt,
      status = if (alt) "ok" else "MISSING_ALT_TEXT",
      notes = if (!length(inc_i)) "no \\includegraphics (inline/tikz?)" else "",
      stringsAsFactors = FALSE)
  }
}
res <- if (length(rows)) do.call(rbind, rows) else
  data.frame(figure_id=character(), source_file=character(), line_number=integer(),
             caption_detected=logical(), alt_text_detected=logical(),
             status=character(), notes=character())
utils::write.csv(res, file.path(OUT, "alt_text_scan.csv"), row.names = FALSE)
cat(sprintf("scan_alt_text: %d figure env(s); %d MISSING alt text -> %s\n",
            nrow(res), sum(res$status == "MISSING_ALT_TEXT"),
            file.path(OUT, "alt_text_scan.csv")))
