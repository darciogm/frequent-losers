# Shared helpers for emitting LaTeX macros into manuscript/paper/values.tex.
# Each analysis script declares its block by calling bp_macros_emit(script_id, ...)
# at the end of the run. Re-running a script overwrites only its own block.

# Locate values.tex via .this_dir; works from Rscript and source().
.bp_this_dir <- function() {
  for (i in seq_len(sys.nframe())) {
    f <- tryCatch(sys.frame(i)$ofile, error = function(e) NULL)
    if (!is.null(f)) return(normalizePath(dirname(f), mustWork = FALSE))
  }
  args <- commandArgs(trailingOnly = FALSE)
  fa <- grep("^--file=", args, value = TRUE)
  if (length(fa)) return(normalizePath(dirname(sub("^--file=", "", fa[1])), mustWork = FALSE))
  getwd()
}

.BP_DIR    <- .bp_this_dir()
BP_VALUES  <- normalizePath(file.path(.BP_DIR, "..", "manuscript", "paper", "values.tex"),
                            mustWork = FALSE)

bp_fmt        <- function(x, digits = 3) formatC(round(x, digits), format = "f", digits = digits)
bp_fmt_pct    <- function(x, digits = 1) paste0(formatC(round(x, digits), format = "f", digits = digits), "\\%")
bp_fmt_pct_n  <- function(x, digits = 1) formatC(round(x, digits), format = "f", digits = digits)  # no % sign
bp_fmt_int    <- function(x) formatC(as.integer(x), format = "d", big.mark = "{,}")
bp_fmt_pp     <- function(x, digits = 1) paste0(formatC(round(x, digits), format = "f", digits = digits), "~pp")
bp_pct_from_log <- function(b, digits = 1) bp_fmt_pct((exp(b) - 1) * 100, digits)

bp_macros_emit <- function(script_id, macros, file = BP_VALUES) {
  if (!is.list(macros) || is.null(names(macros)) || any(names(macros) == "")) {
    stop("bp_macros_emit: 'macros' must be a named list (e.g. list(nNeg = 196883)).")
  }
  begin <- sprintf("%% ===== AUTO BEGIN: %s =====", script_id)
  end   <- sprintf("%% ===== AUTO END: %s =====",   script_id)

  body <- vapply(seq_along(macros), function(i) {
    nm <- names(macros)[i]; val <- as.character(macros[[i]])
    sprintf("\\providecommand{\\BP%s}{}\n\\renewcommand{\\BP%s}{%s}", nm, nm, val)
  }, character(1))
  block <- paste(c(begin, body, end), collapse = "\n")

  if (!file.exists(file)) {
    dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
    writeLines("% values.tex --- generated, see analysis/_macros.R", file)
  }
  # Line-based marker replacement avoids sub()'s perl-mode backslash mangling,
  # which silently strips '\' from the replacement and turns \providecommand
  # into 'providecommand' (LaTeX then sees raw text and dies).
  lines    <- readLines(file, warn = FALSE)
  i_begin  <- which(lines == begin)
  i_end    <- which(lines == end)
  block_l  <- strsplit(block, "\n", fixed = TRUE)[[1]]
  if (length(i_begin) >= 1 && length(i_end) >= 1 && i_end[1] > i_begin[1]) {
    out <- c(lines[seq_len(i_begin[1] - 1)],
             block_l,
             if (i_end[1] < length(lines)) lines[(i_end[1] + 1):length(lines)] else character(0))
  } else {
    out <- c(lines, "", block_l)
  }
  writeLines(out, file)
  cat(sprintf("[bp_macros] wrote %d macros for %s -> %s\n",
              length(macros), script_id, file))
  invisible(file)
}

cat("_macros.R loaded. BP_VALUES =", BP_VALUES, "\n")
