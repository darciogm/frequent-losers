#!/usr/bin/env Rscript
# HonestDiD sensitivity for mortality outcomes, with an explicit gap path when
# the optional HonestDiD package is unavailable.

suppressPackageStartupMessages({
  library(arrow)
  library(data.table)
  library(fixest)
})

args <- commandArgs(trailingOnly = FALSE)
trailing <- commandArgs(trailingOnly = TRUE)
force <- "--force" %in% trailing
script_arg <- sub("--file=", "", args[grepl("--file=", args)])
ROOT <- if (length(script_arg) > 0) normalizePath(file.path(dirname(script_arg), "..")) else normalizePath(getwd())
INTER <- file.path(ROOT, "02_data", "intermediate")
TAB <- file.path(ROOT, "01_manuscript", "tables")
FIG <- file.path(ROOT, "04_figures")
LOG <- file.path(ROOT, "04_logs")
NOTES <- file.path(ROOT, "notes")
dir.create(TAB, showWarnings = FALSE, recursive = TRUE)
dir.create(FIG, showWarnings = FALSE, recursive = TRUE)
dir.create(LOG, showWarnings = FALSE, recursive = TRUE)
dir.create(NOTES, showWarnings = FALSE, recursive = TRUE)

stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
log_file <- file.path(LOG, sprintf("58_honestdid_mortality_revision_%s.log", stamp))
sink(log_file, split = TRUE)
on.exit({ sink(); closeAllConnections() }, add = TRUE)
started <- Sys.time()

cat("script: 58_honestdid_mortality_revision.R\n")
cat("started:", format(started, "%Y-%m-%d %H:%M:%S %Z"), "\n")
cat("force:", force, "\n")
git_sha <- tryCatch(system("git rev-parse --short HEAD", intern = TRUE), error = function(e) NA_character_)
cat("git_sha:", paste(git_sha, collapse = " "), "\n")
cat("R:", R.version.string, "\n")
cat("packages:", paste(c(
  paste0("arrow=", as.character(packageVersion("arrow"))),
  paste0("data.table=", as.character(packageVersion("data.table"))),
  paste0("fixest=", as.character(packageVersion("fixest"))),
  paste0("HonestDiD=", if (requireNamespace("HonestDiD", quietly = TRUE)) {
    as.character(utils::packageVersion("HonestDiD"))
  } else {
    "not installed"
  })
), collapse = "; "), "\n")

gap_out <- file.path(NOTES, "HONESTDID_GAP.md")
tex_out <- file.path(TAB, "table_honestdid_mortality.tex")
fig_out <- c(
  suicide = file.path(FIG, "fig_honestdid_suicide.pdf"),
  selfharm = file.path(FIG, "fig_honestdid_selfharm.pdf")
)
managed_outputs <- c(gap_out, tex_out, unname(fig_out))
if (!force && any(file.exists(managed_outputs))) {
  stop("Refusing to overwrite existing outputs without --force: ",
       paste(managed_outputs[file.exists(managed_outputs)], collapse = ", "))
}

escape_tex <- function(x) {
  x <- gsub("\\\\", "\\\\textbackslash{}", x)
  x <- gsub("([&_#$%{}])", "\\\\\\1", x, perl = TRUE)
  x
}

write_status_table <- function(rows, caption, label) {
  body <- rows[, sprintf("%s & %s \\\\", escape_tex(item), escape_tex(detail))]
  tex <- c(
    "\\begin{table}[!htbp]\\centering",
    paste0("\\caption{", caption, "}"),
    paste0("\\label{", label, "}"),
    "\\small",
    "\\begin{tabular}{p{0.28\\linewidth}p{0.62\\linewidth}}",
    "\\toprule",
    "Item & Detail \\\\",
    "\\midrule",
    body,
    "\\bottomrule",
    "\\end{tabular}",
    "\\end{table}"
  )
  writeLines(tex, tex_out)
}

panel_path <- file.path(INTER, "staggered_panel_pnash48_ext.parquet")
if (!file.exists(panel_path)) {
  stop("Required panel not found: ", panel_path)
}
panel <- as.data.table(read_parquet(panel_path))
panel[, gn_use := fifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))]
cat("panel:", panel_path, "\n")
cat("rows:", nrow(panel), "\n")
cat("municipalities:", panel[, uniqueN(muni_id)], "\n")
cat("treated municipalities:", panel[gn_use < 10000, uniqueN(muni_id)], "\n")
cat("years:", paste(range(panel$year, na.rm = TRUE), collapse = "-"), "\n")

if (!requireNamespace("HonestDiD", quietly = TRUE)) {
  install_cmd <- "Rscript -e \"install.packages('remotes'); remotes::install_github('asheshrambachan/HonestDiD')\""
  rows <- data.table(
    item = c(
      "Status",
      "Package check",
      "Install command",
      "Input panel",
      "Estimator to rerun",
      "Objects required by HonestDiD",
      "Figures",
      "Next command"
    ),
    detail = c(
      "HonestDiD mortality sensitivity not estimated because the HonestDiD R package is unavailable in this environment.",
      "requireNamespace('HonestDiD', quietly = TRUE) returned FALSE.",
      install_cmd,
      "02_data/intermediate/staggered_panel_pnash48_ext.parquet.",
      "fixest::feols(outcome ~ sunab(gn_use, year) | muni_id + year, cluster = 'muni_id', weights = ~pop) for suicide_per100k and selfharm_per100k.",
      "Chronologically ordered event-study coefficient vector, matching covariance matrix, number of pre-period coefficients, number of post-period coefficients, and a uniform post-period l_vec.",
      "No sensitivity figures were generated, to avoid placeholder or fake HonestDiD plots.",
      "Rscript 03_analysis/58_honestdid_mortality_revision.R --force after installing HonestDiD."
    )
  )
  write_status_table(
    rows,
    "HonestDiD mortality sensitivity status. The optional HonestDiD package is not installed, so the script reports the exact reproducibility gap rather than fabricating sensitivity estimates.",
    "tab:honestdid-mortality"
  )
  writeLines(c(
    "# HonestDiD Mortality Sensitivity Gap",
    "",
    "The mortality sensitivity analysis could not be estimated in this environment because the optional R package `HonestDiD` is not installed.",
    "",
    "Package check:",
    "",
    "```r",
    "requireNamespace(\"HonestDiD\", quietly = TRUE)",
    "# FALSE",
    "```",
    "",
    "Install command:",
    "",
    "```sh",
    install_cmd,
    "```",
    "",
    "After installation, rerun:",
    "",
    "```sh",
    "Rscript 03_analysis/58_honestdid_mortality_revision.R --force",
    "```",
    "",
    "The script will use `02_data/intermediate/staggered_panel_pnash48_ext.parquet`, estimate population-weighted Sun--Abraham event studies for `suicide_per100k` and `selfharm_per100k`, extract the event-study coefficient vector and covariance matrix, and call `HonestDiD::createSensitivityResults_relativeMagnitudes()` over a grid of relative-magnitude restrictions.",
    "",
    "No `fig_honestdid_suicide.pdf` or `fig_honestdid_selfharm.pdf` was generated in the gap path. Producing placeholder figures would make the manuscript look more complete than the computation supports."
  ), gap_out)
  cat("wrote:", gap_out, "\n")
  cat("wrote:", tex_out, "\n")
  cat("HonestDiD unavailable; no figures generated.\n")
  cat("peak_memory_mb:", round(gc()[, "max used"][2] * 8 / 1024^2, 1), "\n")
  cat("runtime_seconds:", round(as.numeric(difftime(Sys.time(), started, units = "secs")), 2), "\n")
  quit(status = 0)
}

library(HonestDiD)

extract_event_study <- function(fit) {
  cf_all <- coef(fit)
  vc <- vcov(fit)
  matched <- regmatches(names(cf_all), regexec("^year::(-?[0-9]+)$", names(cf_all)))
  es <- rbindlist(lapply(seq_along(matched), function(i) {
    mi <- matched[[i]]
    if (length(mi) == 2) {
      data.table(idx = i, name = names(cf_all)[i], e = as.integer(mi[2]), cf = cf_all[i])
    } else {
      NULL
    }
  }))
  es <- es[order(e)]
  keep <- es[e != -1]
  ord <- order(keep$e)
  idx <- keep$idx[ord]
  betahat <- keep$cf[ord]
  sigma <- vc[idx, idx]
  list(
    e = keep$e[ord],
    betahat = betahat,
    sigma = sigma,
    num_pre = sum(keep$e < 0),
    num_post = sum(keep$e >= 0)
  )
}

run_outcome <- function(outcome, label, fig_file) {
  d <- panel[is.finite(get(outcome)) & is.finite(pop) & pop > 0]
  fit <- feols(as.formula(sprintf("%s ~ sunab(gn_use, year) | muni_id + year", outcome)),
               data = d, cluster = "muni_id", weights = ~pop, warn = FALSE, notes = FALSE)
  es <- extract_event_study(fit)
  if (es$num_pre < 1 || es$num_post < 1) {
    stop("Insufficient event-study periods for ", outcome)
  }
  l_vec <- rep(1 / es$num_post, es$num_post)
  post_idx <- (es$num_pre + 1):(es$num_pre + es$num_post)
  beta_target <- as.numeric(l_vec %*% es$betahat[post_idx])
  se_target <- as.numeric(sqrt(t(l_vec) %*% es$sigma[post_idx, post_idx] %*% l_vec))
  m_grid <- c(0, 0.05, 0.10, 0.15, 0.20, 0.30, 0.50, 1.00)
  sens <- rbindlist(lapply(m_grid, function(mbar) {
    ans <- tryCatch({
      out <- HonestDiD::createSensitivityResults_relativeMagnitudes(
        betahat = es$betahat,
        sigma = es$sigma,
        numPrePeriods = es$num_pre,
        numPostPeriods = es$num_post,
        l_vec = l_vec,
        Mbarvec = c(mbar),
        gridPoints = 200
      )
      data.table(Mbar = mbar, lb = out$lb[1], ub = out$ub[1], status = "ok")
    }, error = function(e) {
      data.table(Mbar = mbar, lb = NA_real_, ub = NA_real_, status = conditionMessage(e))
    })
    ans
  }))
  pdf(fig_file, width = 6.5, height = 4.2)
  ok <- sens[status == "ok" & is.finite(lb) & is.finite(ub)]
  plot(ok$Mbar, ok$lb, type = "b", ylim = range(c(ok$lb, ok$ub, 0), na.rm = TRUE),
       xlab = "Relative-magnitude restriction Mbar", ylab = "Robust 95% CI",
       main = label, pch = 16)
  lines(ok$Mbar, ok$ub, type = "b", pch = 16)
  abline(h = 0, lty = 2, col = "gray40")
  dev.off()
  data.table(
    outcome = label,
    att = beta_target,
    se = se_target,
    classical_lo = beta_target - 1.96 * se_target,
    classical_hi = beta_target + 1.96 * se_target,
    num_pre = es$num_pre,
    num_post = es$num_post,
    Mbar_0_lo = sens[Mbar == 0, lb],
    Mbar_0_hi = sens[Mbar == 0, ub],
    Mbar_1_lo = sens[Mbar == 1, lb],
    Mbar_1_hi = sens[Mbar == 1, ub],
    status = if (all(sens$status == "ok")) "ok" else paste(unique(sens$status[sens$status != "ok"]), collapse = "; ")
  )
}

results <- rbindlist(list(
  run_outcome("suicide_per100k", "Suicide mortality", fig_out[["suicide"]]),
  run_outcome("selfharm_per100k", "Self-harm mortality", fig_out[["selfharm"]])
), fill = TRUE)

fmt <- function(x) ifelse(is.finite(x), sprintf("%+.2f", x), "--")
fmt_ci <- function(lo, hi) ifelse(is.finite(lo) & is.finite(hi), sprintf("[%+.2f, %+.2f]", lo, hi), "--")
rows <- results[, sprintf("%s & %s & %s & %s & %s & %s \\\\",
                          outcome, fmt(att), fmt_ci(classical_lo, classical_hi),
                          fmt_ci(Mbar_0_lo, Mbar_0_hi), fmt_ci(Mbar_1_lo, Mbar_1_hi),
                          status)]
tex <- c(
  "\\begin{table}[!htbp]\\centering",
  "\\caption{HonestDiD sensitivity for mortality outcomes. The table reports population-weighted Sun--Abraham estimates on the PNASH psychiatric-closure panel and Rambachan--Roth relative-magnitude confidence intervals for the post-period average.}",
  "\\label{tab:honestdid-mortality}",
  "\\small",
  "\\begin{tabular}{lccccc}",
  "\\toprule",
  "Outcome & ATT & Classical 95\\% CI & Mbar 0 CI & Mbar 1 CI & Status \\\\",
  "\\midrule",
  rows,
  "\\bottomrule",
  "\\end{tabular}",
  "\\end{table}"
)
writeLines(tex, tex_out)
cat("wrote:", tex_out, "\n")
cat("wrote:", paste(unname(fig_out), collapse = ", "), "\n")
cat("peak_memory_mb:", round(gc()[, "max used"][2] * 8 / 1024^2, 1), "\n")
cat("runtime_seconds:", round(as.numeric(difftime(Sys.time(), started, units = "secs")), 2), "\n")
