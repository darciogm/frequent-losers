#!/usr/bin/env Rscript
# D6_make_values.R
#
# Single source of truth for every computed number in the manuscript.
# Recomputes data-inventory figures (DuckDB) and all estimation results
# (fixest on the pop-backfilled *_ext panels), and writes
# 01_manuscript/values.tex as \newcommand macros, each with a % src: comment.
# Run after D1-D5. The manuscript \input{values.tex} and uses \val* macros;
# no number is hand-typed in the prose.

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest); library(duckdb); library(DBI)
})

ROOT  <- normalizePath(file.path(dirname(sub("--file=", "",
          commandArgs(FALSE)[grepl("--file=", commandArgs(FALSE))])), ".."))
INTER <- file.path(ROOT, "02_data", "intermediate")
OUT   <- file.path(ROOT, "01_manuscript", "values.tex")

LINES <- character(0)
v <- function(name, value, src) LINES[[length(LINES) + 1L]] <<-
  sprintf("\\newcommand{\\%s}{%s}%% src: %s", name, value, src)
sgn  <- function(x, d = 2) sprintf("%+.*f", d, x)          # signed, d decimals
num  <- function(x, d = 2) sprintf("%.*f", d, x)           # unsigned
comma <- function(x) gsub(",", "{,}", formatC(x, format = "d", big.mark = ","))  # math-safe thousands sep

# ============================ DATA INVENTORY (DuckDB) ============================
con <- dbConnect(duckdb()); dbExecute(con, "PRAGMA threads=10")
q <- function(s) dbGetQuery(con, s)
EDG <- sprintf("read_parquet('%s')", file.path(INTER, "bipartite_edges.parquet"))
MAS <- sprintf("read_parquet('%s')", file.path(INTER, "hospital_master.parquet"))
EXP <- sprintf("read_parquet('%s')", file.path(INTER, "exposure_panel.parquet"))
CLO <- sprintf("read_parquet('%s')", file.path(INTER, "hospital_closures_exogenous.parquet"))

adm <- q(sprintf("SELECT SUM(n_internacoes) t, COUNT(DISTINCT codmun_6) m, COUNT(DISTINCT CNES) h FROM %s", EDG))
v("valNadmissions", sprintf("%.1f", adm$t / 1e6), "D6: SUM(n_internacoes) bipartite_edges, millions")
v("valNmunisGraph", comma(adm$m), "D6: distinct residence munis in bipartite_edges")
v("valNhospGraph",  comma(adm$h), "D6: distinct hospitals in bipartite_edges")

cb <- q(sprintf("
  SELECT SUM(CASE WHEN e.codmun_6 <> m.codmun_6_modal THEN e.n_internacoes ELSE 0 END)*100.0/SUM(e.n_internacoes) pct
  FROM %s e JOIN %s m USING (CNES)", EDG, MAS))
v("valCrossBorderPct", num(cb$pct, 1), "D6: volume-weighted share admissions outside residence muni")

mis <- q(sprintf("SELECT
    SUM((exposed_emb AND exposed_km)::int) n_both,
    SUM((exposed_emb AND NOT exposed_km)::int) miss,
    SUM((NOT exposed_emb AND exposed_km)::int) fals,
    SUM((exposed_emb OR exposed_km)::int) uni FROM %s", EXP))
v("valNboth",       comma(mis$n_both), "D6: muni-closure pairs flagged by both rules")
v("valNmissed",     comma(mis$miss), "D6: flow-only pairs (distance misses)")
v("valNfalse",      comma(mis$fals), "D6: distance-only pairs (distance false-flags)")
v("valNunionPairs", comma(mis$uni),  "D6: pairs flagged by either rule")
v("valNmisclass",   comma(mis$miss + mis$fals), "D6: misclassified = missed + false")

clo <- q(sprintf("SELECT
    SUM(exogenous::int) exo,
    SUM((exogenous AND tp_unid='07')::int) spec,
    SUM((exogenous AND tp_unid='05')::int) genr FROM %s", CLO))
v("valNexoClosures",  comma(clo$exo),  "D6: exogenous closures (F1-F5)")
v("valNspecClosures", comma(clo$spec), "D6: specialized (tp_unid=07) exogenous closures")
v("valNgenClosures",  comma(clo$genr), "D6: general (tp_unid=05) exogenous closures")

pn <- ("(year_closure BETWEEN 2006 AND 2009 OR year_closure BETWEEN 2010 AND 2013 OR year_closure BETWEEN 2014 AND 2017)")
cs <- q(sprintf("SELECT
    SUM((f1_window AND f2_type AND f3_beds AND f4_mass AND tp_unid='07' AND %s)::int) pnash,
    SUM((f1_window AND f2_type AND f3_beds AND f4_mass AND tp_unid='07')::int) psymax FROM %s", pn, CLO))
v("valNclosuresPnash",  comma(cs$pnash),  "D6: PNASH-anchored psychiatric closures (primary sample)")
v("valNclosuresPsymax", comma(cs$psymax), "D6: all psychiatric closures, F5 relaxed (robustness)")

# ---- intro worked example (footnote): CNES 2082683, closed 2016 ----
eg <- q(sprintf("SELECT
    SUM(n_aih_pre) FILTER(WHERE exposed_emb) adm,
    COUNT(*) FILTER(WHERE exposed_emb) n,
    COUNT(*) FILTER(WHERE exposed_emb AND dist_km BETWEEN 36 AND 107) far,
    MAX(dist_km) FILTER(WHERE exposed_emb) khi,
    MEDIAN(dist_km) FILTER(WHERE exposed_emb) kmed FROM %s WHERE CNES='2082683'", EXP))
v("valEgAdm",   comma(eg$adm),        "D6: CNES 2082683 admissions from E1-exposed munis")
v("valEgMunis", comma(eg$n),          "D6: CNES 2082683 E1-exposed municipalities")
v("valEgFar",   comma(eg$far),        "D6: of which 36-107 km away")
v("valEgKmHi",  num(eg$khi, 0),       "D6: CNES 2082683 max E1 distance (km)")
v("valEgKmMed", num(eg$kmed, 0),      "D6: CNES 2082683 median E1 distance (km)")

# ---- closure filter cascade (App. A, Table tab:filter) ----
fc <- q(sprintf("SELECT COUNT(*) f0,
    SUM(f1_window::int) f1,
    SUM((f1_window AND f2_type)::int) f2,
    SUM((f1_window AND f2_type AND f3_beds)::int) f3,
    SUM((f1_window AND f2_type AND f3_beds AND f4_mass)::int) f4,
    SUM(exogenous::int) f5 FROM %s", CLO))
# LaTeX command names cannot contain digits -> spelled-out suffixes
fk <- c(f0 = "valFiltZero", f1 = "valFiltOne", f2 = "valFiltTwo",
        f3 = "valFiltThree", f4 = "valFiltFour", f5 = "valFiltFive")
for (k in names(fk)) v(fk[[k]], comma(fc[[k]]), sprintf("D6: filter cascade %s surviving", toupper(k)))
f6 <- q(sprintf("SELECT COUNT(*) n FROM read_parquet('%s') WHERE motivo_v2 IN ('administrativo','fiscal','falencia')",
                file.path(INTER, "closures_classified_v2.parquet")))
v("valFiltSix", comma(f6$n), "D6: F6 NLP-documented robustness sub-sample")

# ---- SIM deaths in window (Data, App.) ----
sim_files <- unlist(lapply(2010:2023, function(y) Sys.glob(file.path(INTER, "..", "raw", "sim", sprintf("do*%d.parquet", y)))))
sim_sql <- paste0("[", paste(sprintf("'%s'", sim_files), collapse = ", "), "]")
dd <- q(sprintf("SELECT COUNT(*) n FROM read_parquet(%s, union_by_name=true)
   WHERE CAUSABAS IS NOT NULL AND CODMUNRES IS NOT NULL AND DTOBITO IS NOT NULL
     AND LENGTH(DTOBITO)=8 AND CAST(SUBSTR(DTOBITO,5,4) AS INTEGER) BETWEEN 2010 AND 2023", sim_sql))
v("valNdeaths", sprintf("%.1f", dd$n / 1e6), "D6: SIM deaths 2010-2023, millions")

# ---- cross-section sample sizes (App. C) ----
nx <- q(sprintf("SELECT COUNT(DISTINCT codmun_6) n FROM read_parquet('%s')",
                file.path(INTER, "staggered_panel_F5_main.parquet")))
v("valNmunisDiverg", comma(nx$n), "D6: municipalities in panel / divergence map")
n10 <- q(sprintf("SELECT COUNT(*) n FROM (SELECT codmun_6, AVG(pop) mp FROM read_parquet('%s')
   WHERE pop IS NOT NULL GROUP BY codmun_6) WHERE mp >= 10000",
                 file.path(INTER, "staggered_panel_F5_main.parquet")))
v("valNmunisTenk", comma(n10$n), "D6: municipalities with mean pop >= 10k (cross-section subset)")
dbDisconnect(con, shutdown = TRUE)

# ============================ ESTIMATES (fixest) ============================
est <- function(panel, yn, wt = FALSE, caps_excl = FALSE, drop_pand = FALSE, twfe = FALSE) {
  d <- as.data.table(read_parquet(file.path(INTER, panel)))
  d <- d[is.finite(get(yn)) & (!wt | is.finite(pop))]
  d[, gn := ifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))]
  if (drop_pand) d <- d[!(year %in% c(2020, 2021))]
  if (caps_excl) {
    caps <- c("120040","270430","160030","130260","292740","230440","530010","320530",
              "520870","211130","510340","500270","310620","150140","250750","410690",
              "261160","221100","330455","240810","431490","110020","140010","420540",
              "355030","280030","172100")
    d <- d[!codmun_6 %in% caps]
  }
  w <- if (wt) d$pop else NULL
  if (twfe) {
    d[, post := as.integer(gn < 10000 & year >= gn)]
    m <- feols(as.formula(sprintf("%s ~ post | muni_id + year", yn)), d, cluster = "muni_id", weights = w)
    return(list(att = coef(m)["post"], se = se(m)["post"]))
  }
  m <- feols(as.formula(sprintf("%s ~ sunab(gn, year) | muni_id + year", yn)), d, cluster = "muni_id", weights = w)
  a <- summary(m, agg = "att"); att <- as.numeric(coef(a)[1]); se <- as.numeric(se(a)[1])
  base <- if (wt) weighted.mean(d[gn < 10000 & year < 2015][[yn]], d[gn < 10000 & year < 2015]$pop, na.rm = TRUE)
          else    mean(d[gn < 10000 & year < 2015][[yn]], na.rm = TRUE)
  cf <- coef(m); s <- se(m); mm <- regmatches(names(cf), regexec("^year::(-?[0-9]+)$", names(cf)))
  es <- rbindlist(lapply(seq_along(mm), function(i)
    if (length(mm[[i]]) == 2) data.table(e = as.integer(mm[[i]][2]), cf = cf[i], se = s[i]) else NULL))
  es <- es[is.finite(cf) & is.finite(se) & se > 0]
  pre <- es[e <= -2 & e >= -6]; W <- sum((pre$cf / pre$se)^2)
  list(att = att, se = se, lo = att - 1.96 * se, hi = att + 1.96 * se, base = base,
       ub = 100 * (att + 1.96 * se) / base, p = 1 - pchisq(W, nrow(pre)),
       ntr = d[gn < 10000, uniqueN(muni_id)], es = es)
}

P <- "staggered_panel_pnash48_ext.parquet"
emit <- function(pre, r, src, bound = TRUE) {
  v(paste0(pre, "Att"), sgn(r$att), src); v(paste0(pre, "Se"), num(r$se), src)
  v(paste0(pre, "Lo"), sgn(r$lo), src);   v(paste0(pre, "Hi"), sgn(r$hi), src)
  v(paste0(pre, "Ppre"), num(r$p), src)
  if (bound) v(paste0(pre, "BoundPct"), sprintf("%+.0f", r$ub), src)
}
su_w <- est(P, "suicide_per100k", TRUE);  emit("valSuicW", su_w, "D6: pnash48_ext suicide WLS")
v("valSuicBaseline", num(su_w$base), "D6: pnash48_ext suicide pre-period treated baseline (pop-wtd)")
su_o <- est(P, "suicide_per100k", FALSE); emit("valSuicO", su_o, "D6: pnash48_ext suicide OLS")
se_w <- est(P, "selfharm_per100k", TRUE); emit("valSelfW", se_w, "D6: pnash48_ext self-harm WLS")
tr   <- est(P, "travel_burden_km", FALSE); emit("valTrav", tr, "D6: pnash48_ext travel first stage", bound = FALSE)
v("valTravAbs", num(abs(tr$att), 1), "D6: |travel ATT| for 'falls X km' phrasing")
ic   <- est(P, "icsap_per1k", FALSE);      emit("valIcsap", ic, "D6: pnash48_ext ICSAP (non-identified)", bound = FALSE)
icpre <- ic$es[order(e)]
v("valIcsapPreFive",  sgn(icpre[e == -5]$cf), "D6: ICSAP pre-coef e=-5")
v("valIcsapPreFour",  sgn(icpre[e == -4]$cf), "D6: ICSAP pre-coef e=-4")
v("valIcsapPreThree", sgn(icpre[e == -3]$cf), "D6: ICSAP pre-coef e=-3")
v("valNtrPnash", as.character(su_w$ntr), "D6: pnash48 exposed munis")

# robustness
sp <- est("staggered_panel_spec07_ext.parquet",   "suicide_per100k", TRUE); emit("valSuicSpec",   sp, "D6: spec07_ext suicide WLS")
pm <- est("staggered_panel_psymax60_ext.parquet", "suicide_per100k", TRUE); emit("valSuicPsymax", pm, "D6: psymax60_ext suicide WLS")
v("valNtrSpec", as.character(sp$ntr), "D6: spec07 exposed munis")
v("valNtrPsymax", as.character(pm$ntr), "D6: psymax60 exposed munis")
dp <- est(P, "suicide_per100k", TRUE, drop_pand = TRUE)
v("valSuicDropPandAtt", sgn(dp$att), "D6: suicide WLS dropping 2020-21"); v("valSuicDropPandSe", num(dp$se), "D6")
nc <- est(P, "suicide_per100k", TRUE, caps_excl = TRUE)
v("valSuicNoCapAtt", sgn(nc$att), "D6: suicide WLS excl. 27 capitals"); v("valSuicNoCapSe", num(nc$se), "D6")
tw <- est(P, "suicide_per100k", TRUE, twfe = TRUE)
v("valSuicTwfeAtt", sgn(tw$att), "D6: suicide WLS naive TWFE"); v("valSuicTwfeSe", num(tw$se), "D6")

# ---- embedding vs km pair-distance correlation (App. embedding) ----
emb <- as.data.table(read_parquet(file.path(INTER, "embeddings_munmun_proj.parquet")))
cen <- as.data.table(read_parquet(file.path(INTER, "municipios_centroids.parquet")))[, .(cod_mun_6, lat, lon)]
emb <- merge(emb, cen, by = "cod_mun_6")
dim_cols <- grep("^dim_", names(emb), value = TRUE)
M <- as.matrix(emb[, ..dim_cols])
set.seed(42); N <- 5000
i <- sample(nrow(emb), N, replace = TRUE); j <- sample(nrow(emb), N, replace = TRUE)
ok <- i != j; i <- i[ok]; j <- j[ok]
d_emb <- sqrt(rowSums((M[i, ] - M[j, ])^2))
hav <- function(la1, lo1, la2, lo2) {
  R <- 6371; dla <- (la2 - la1) * pi / 180; dlo <- (lo2 - lo1) * pi / 180
  a <- sin(dla / 2)^2 + cos(la1 * pi / 180) * cos(la2 * pi / 180) * sin(dlo / 2)^2
  2 * R * asin(pmin(1, sqrt(a)))
}
d_km <- hav(emb$lat[i], emb$lon[i], emb$lat[j], emb$lon[j])
v("valEmbKmCorr", num(cor(d_emb, d_km), 2), "D6: Pearson corr embedding-dist vs km, 5000 pairs, seed 42")

writeLines(c("% Auto-generated by 03_analysis/D6_make_values.R — do not hand-edit.",
             "% Every manuscript number resolves here; rerun D6 to refresh.", "", LINES), OUT)
cat("wrote", OUT, "with", length(LINES), "macros\n")
