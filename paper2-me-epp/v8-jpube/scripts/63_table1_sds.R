# 63_table1_sds.R -----------------------------------------------------
# Cross-auction standard deviations of bidder counts per type/class/period
# for Table 1 (tab_first_stage_v8). The means in Table 1 come from
# bne_decomp (n_sme_pre etc., emitted by v6 script 98); this script
# computes the matching dispersion from the same auction-level source
# (entry_rates.parquet, one row per pregao auction) so the SDs can sit in
# parentheses below each mean. Audit follow-up (item 7a, 2026-06-07).
#
# Validation: the AVG() here must reproduce the Table 1 means exactly
# (NP SME 0.94/1.87, non-SME 2.68/1.50; PH 0.55/1.22, 2.61/1.66).
#
# Output: v8-jpube/output/values_table1_sds.tex
# ----------------------------------------------------------------------

suppressPackageStartupMessages({ library(duckdb); library(DBI) })

ROOT    <- "/home/darciogm1/projetos/bitter-pills/paper2-me-epp"
ENTRY   <- file.path(ROOT, "v6-jpube/data/processed/entry_rates.parquet")
V8_OUT  <- file.path(ROOT, "v8-jpube/output")
stopifnot(file.exists(ENTRY))

con <- dbConnect(duckdb::duckdb())
on.exit(dbDisconnect(con, shutdown = TRUE))
dbExecute(con, "PRAGMA threads=8")

q <- sprintf("
  SELECT period, pharma_narrow,
         ROUND(AVG(n_sme_bid),2)          AS avg_sme,
         ROUND(STDDEV_SAMP(n_sme_bid),2)  AS sd_sme,
         ROUND(AVG(n_nonsme_bid),2)       AS avg_ns,
         ROUND(STDDEV_SAMP(n_nonsme_bid),2) AS sd_ns
  FROM read_parquet('%s')
  WHERE mod='pregao' AND period IN ('Pre','Post')
  GROUP BY 1,2", ENTRY)
d <- dbGetQuery(con, q)

get <- function(per, ph, col) d[d$period == per & d$pharma_narrow == ph, col]

# Validate means against the canonical Table 1 macros before emitting SDs.
chk <- c(get("Pre",0,"avg_sme")==0.94, get("Post",0,"avg_sme")==1.87,
         get("Pre",0,"avg_ns")==2.68,  get("Post",0,"avg_ns")==1.50,
         get("Pre",1,"avg_sme")==0.55, get("Post",1,"avg_sme")==1.22,
         get("Pre",1,"avg_ns")==2.61,  get("Post",1,"avg_ns")==1.66)
if (!all(chk)) {
  print(d)
  stop("Means do not reproduce canonical Table 1 values; aborting SD emit.")
}
cat("Validation OK: AVG() reproduces all eight Table 1 means.\n")
print(d)

sd2 <- function(per, ph, col) sprintf("%.2f", get(per, ph, col))
lines <- c(
  "%% Table 1 cross-auction SDs of bidder counts (script",
  "%% v8-jpube/scripts/63_table1_sds.R 2026-06-07). Source: entry_rates.parquet",
  "%% (one row per pregao auction). Means validated against canonical macros.",
  sprintf("\\providecommand{\\bneNsmePreSdNp}{}\\renewcommand{\\bneNsmePreSdNp}{%s}",   sd2("Pre",0,"sd_sme")),
  sprintf("\\providecommand{\\bneNsmePostSdNp}{}\\renewcommand{\\bneNsmePostSdNp}{%s}", sd2("Post",0,"sd_sme")),
  sprintf("\\providecommand{\\bneNnsPreSdNp}{}\\renewcommand{\\bneNnsPreSdNp}{%s}",     sd2("Pre",0,"sd_ns")),
  sprintf("\\providecommand{\\bneNnsPostSdNp}{}\\renewcommand{\\bneNnsPostSdNp}{%s}",   sd2("Post",0,"sd_ns")),
  sprintf("\\providecommand{\\bneNsmePreSdPh}{}\\renewcommand{\\bneNsmePreSdPh}{%s}",   sd2("Pre",1,"sd_sme")),
  sprintf("\\providecommand{\\bneNsmePostSdPh}{}\\renewcommand{\\bneNsmePostSdPh}{%s}", sd2("Post",1,"sd_sme")),
  sprintf("\\providecommand{\\bneNnsPreSdPh}{}\\renewcommand{\\bneNnsPreSdPh}{%s}",     sd2("Pre",1,"sd_ns")),
  sprintf("\\providecommand{\\bneNnsPostSdPh}{}\\renewcommand{\\bneNnsPostSdPh}{%s}",   sd2("Post",1,"sd_ns"))
)
writeLines(lines, file.path(V8_OUT, "values_table1_sds.tex"))
cat("Wrote values_table1_sds.tex\n")
