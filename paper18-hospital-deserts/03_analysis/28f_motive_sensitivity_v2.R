#!/usr/bin/env Rscript
# 28f_motive_sensitivity_v2 — refit ATT no subset de fechamentos não-frágeis
# (35/60 após screening de motivos suspeitos), com SA, CS, did2s e didimputation
# já disponíveis no R local.

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest); library(jsonlite)
  library(did); library(did2s); library(didimputation)
})

ROOT  <- normalizePath(getwd())
INTER <- file.path(ROOT, "02_data", "intermediate")
LOG   <- file.path(ROOT, "04_logs")
TAB   <- file.path(ROOT, "01_manuscript", "tables")
set.seed(42)

# baseline F5_main e subset não-frágil F6_human_validated
panel_full <- as.data.table(read_parquet(file.path(INTER, "staggered_panel_F5_main.parquet")))
panel_v    <- as.data.table(read_parquet(file.path(INTER, "staggered_panel_F6_human_validated.parquet")))

run_estimators <- function(panel, yname) {
  d <- panel[is.finite(get(yname))]
  d[, gn := fifelse(g_emb > 0, as.integer(g_emb), 0L)]
  d[, gn_use := ifelse(gn == 0L, 10000L, gn)]
  d[, first_treat := gn]

  # Sun-Abraham
  m_sa <- feols(as.formula(sprintf("%s ~ sunab(gn_use, year) | muni_id + year", yname)),
                data = d, cluster = ~muni_id)
  agg <- summary(m_sa, agg = "att")
  sa <- list(att = as.numeric(coef(agg)[1]), se = as.numeric(se(agg)[1]))

  # Callaway-Sant'Anna
  cs <- tryCatch({
    res <- did::att_gt(yname=yname, tname="year", idname="muni_id",
                       gname="gn", data=d, xformla=~1,
                       control_group="notyettreated",
                       est_method=ifelse(yname=="travel_burden_km","ipw","reg"),
                       panel=TRUE, allow_unbalanced_panel=TRUE,
                       bstrap=FALSE, cband=FALSE, print_details=FALSE)
    a <- did::aggte(res, type="simple", na.rm=TRUE)
    list(att = a$overall.att, se = a$overall.se)
  }, error=function(e) list(att=NA_real_, se=NA_real_))

  # did2s with binary treatment spec (matching 35b)
  d[, treat_emb_yr := as.integer(treat_emb_yr)]
  d2s <- tryCatch({
    m <- did2s::did2s(data=d, yname=yname,
                     first_stage=~0|muni_id+year,
                     second_stage=~i(treat_emb_yr, ref=FALSE),
                     treatment="treat_emb_yr", cluster_var="muni_id", verbose=FALSE)
    list(att = as.numeric(coef(m)[1]), se = as.numeric(sqrt(diag(vcov(m)))[1]))
  }, error=function(e) list(att=NA_real_, se=NA_real_))

  # didimputation
  dimp <- tryCatch({
    m <- didimputation::did_imputation(data=d, yname=yname, gname="first_treat",
                                       tname="year", idname="muni_id")
    list(att = as.numeric(m$estimate), se = as.numeric(m$std.error))
  }, error=function(e) list(att=NA_real_, se=NA_real_))

  list(sa=sa, cs=cs, did2s=d2s, didimp=dimp,
       n_treated=length(unique(d[gn>0, muni_id])),
       n_obs=nrow(d))
}

cat("==== M1 sensitivity v2 (real estimators) ====\n")
out <- list()
for (lbl_panel in list(list(label="F5_main_full", panel=panel_full),
                       list(label="F6_human_validated", panel=panel_v))) {
  cat("PANEL:", lbl_panel$label, "rows=", nrow(lbl_panel$panel), "\n")
  for (yname in c("travel_burden_km", "icsap_per1k")) {
    cat(" outcome:", yname, "\n")
    r <- run_estimators(lbl_panel$panel, yname)
    out[[length(out)+1]] <- list(panel=lbl_panel$label, outcome=yname, results=r)
    cat(sprintf("   SA:%.3f(%.3f)  CS:%.3f(%.3f)  did2s:%.3f(%.3f)  didimp:%.3f(%.3f)  n_t=%d n=%d\n",
                r$sa$att, r$sa$se, r$cs$att, r$cs$se,
                r$did2s$att, r$did2s$se, r$didimp$att, r$didimp$se,
                r$n_treated, r$n_obs))
  }
}

write(toJSON(out, auto_unbox=TRUE, pretty=TRUE),
      file.path(LOG, "28f_motive_sensitivity_v2.json"))

# Tabela
tex <- c(
  "\\begin{table}[h!]\\centering",
  "\\caption{Closure-motive sensitivity: estimators on the full F5 main panel vs the F6 subset that drops the 25 fechamentos flagged as fragile (stale Receita status or only-web-snippet evidence). Standard errors clustered at municipality.}",
  "\\label{tab:motive_validation}",
  "\\small",
  "\\begin{tabular}{llcccc}",
  "\\toprule",
  "Sample & Outcome & SA & CS & did2s & did\\_imputation \\\\",
  "\\midrule"
)
fmt <- function(a, s) sprintf("$%+.3f$ (%.3f)", a, s)
for (r in out) {
  tex <- c(tex, sprintf("%s & %s & %s & %s & %s & %s \\\\",
                        gsub("_","\\\\_", r$panel),
                        ifelse(r$outcome=="travel_burden_km","Travel km","ICSAP per 1k"),
                        fmt(r$results$sa$att, r$results$sa$se),
                        fmt(r$results$cs$att, r$results$cs$se),
                        fmt(r$results$did2s$att, r$results$did2s$se),
                        fmt(r$results$didimp$att, r$results$didimp$se)))
}
tex <- c(tex, "\\bottomrule\\end{tabular}\\end{table}")
writeLines(tex, file.path(TAB, "tab_motive_validation.tex"))

cat("done\n")
