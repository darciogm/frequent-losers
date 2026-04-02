# ============================================================================
# 21_network_graph.R — Network Graph Visualization
# Paper 3 v4: Frequent Losers in Public Procurement
# ============================================================================
# Produces a node-link diagram showing how top FL firms orbit around
# specific winners. Uses igraph + ggraph.
# ============================================================================

cat("=== 21_network_graph.R: Network graph visualization ===\n")

if (!exists(".v4_dir")) .v4_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v4_dir, "code", "00_setup.R"), local = TRUE)

# Install graph packages if needed
for (pkg in c("igraph", "ggraph", "tidygraph")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat(sprintf("  Installing %s...\n", pkg))
    install.packages(pkg, repos = "https://cloud.r-project.org", quiet = TRUE)
  }
}

suppressPackageStartupMessages({
  library(igraph)
  library(ggraph)
  library(tidygraph)
})

# ---- Load data ---------------------------------------------------------------
cat("  Loading network data...\n")

if (!file.exists(NETWORK_CACHE_V4)) stop("Run 02_network_analysis.R first")
net_data <- readRDS(NETWORK_CACHE_V4)

# Load FTM for pair computation
ftm_file <- file.path(DATA_V1, "firm_tender_map.parquet")
ftm <- as.data.table(read_parquet(ftm_file))
ftm_col <- grep("fornecedor", names(ftm), value = TRUE, ignore.case = TRUE)
if (length(ftm_col) == 1) setnames(ftm, ftm_col, "firm_id")
setnames(ftm, "numerodaoc", "oc_code", skip_absent = TRUE)
setnames(ftm, "códigoitem", "item_code", skip_absent = TRUE)

# FL IDs
fp <- readRDS(DATA_CACHE_FP)
fp_col <- grep("fornecedor", names(fp), value = TRUE, ignore.case = TRUE)
if (length(fp_col) == 1 && fp_col != "firm_id") setnames(fp, fp_col, "firm_id")
q <- quantile(fp$tenders_count, c(0.25, 0.50, 0.75))
threshold <- q[2] + 1.5 * (q[3] - q[1])
fl_ids <- unique(fp[tenders_count > threshold, firm_id])

# ============================================================================
# Phase 1: Build edge list from top FL firms
# ============================================================================

cat("  Phase 1: Building edge list...\n")

TOP_N_FL <- 50L      # top 50 FL firms by tenders
MIN_COBID <- 5L      # minimum co-occurrences to draw edge

# Select top FL firms by participation count
fl_participation <- fp[firm_id %chin% fl_ids, .(firm_id, tenders_count)]
fl_participation <- fl_participation[order(-tenders_count)]
top_fl <- fl_participation[1:min(TOP_N_FL, .N), firm_id]

# Get tenders of top FL firms
fl_ftm <- ftm[firm_id %chin% top_fl]
fl_tenders <- unique(fl_ftm[, .(oc_code, item_code)])

# Find winners in those tenders
all_bidders <- merge(fl_tenders, ftm, by = c("oc_code", "item_code"))
winners <- all_bidders[won == 1L & !(firm_id %chin% fl_ids)]

# Build FL-winner pairs
pairs <- merge(
  fl_ftm[, .(fl_firm = firm_id, oc_code, item_code)],
  winners[, .(oc_code, item_code, winner = firm_id)],
  by = c("oc_code", "item_code"), allow.cartesian = TRUE
)
pair_counts <- pairs[, .N, by = .(fl_firm, winner)]
pair_counts <- pair_counts[N >= MIN_COBID]

cat(sprintf("  Edges (>=%d co-bids): %s\n", MIN_COBID, pfmt_int(nrow(pair_counts))))

if (nrow(pair_counts) == 0) {
  cat("  No edges above threshold. Skipping network graph.\n")
  saveRDS(list(note = "No edges above threshold"), NETWORK_GRAPH_CACHE_V4 %||% "/tmp/p3v4_network_graph.rds")
  cat("  Done.\n")
  quit("no")
}

# ============================================================================
# Phase 2: Build igraph and compute layout
# ============================================================================

cat("  Phase 2: Building graph...\n")

# Node list
fl_nodes <- data.table(id = unique(pair_counts$fl_firm), type = "FL")
winner_nodes <- data.table(id = unique(pair_counts$winner), type = "Winner")
nodes <- rbind(fl_nodes, winner_nodes)
nodes[, label := paste0(substr(id, 1, 4), "..")]

# Edge list
edges <- pair_counts[, .(from = fl_firm, to = winner, weight = N)]

# Create igraph
g <- graph_from_data_frame(edges, directed = FALSE, vertices = nodes)

# Extract largest connected component for cleaner visualization
components <- clusters(g)
largest_comp <- which.max(components$csize)
g_main <- induced_subgraph(g, which(components$membership == largest_comp))

n_nodes_main <- vcount(g_main)
n_edges_main <- ecount(g_main)
cat(sprintf("  Largest component: %d nodes, %d edges\n", n_nodes_main, n_edges_main))

# Convert to tidygraph
tg <- as_tbl_graph(g_main)

# ============================================================================
# Phase 3: Plot
# ============================================================================

cat("  Phase 3: Generating network graph...\n")

# Scale edge width
max_weight <- max(E(g_main)$weight)
min_weight <- min(E(g_main)$weight)

p_net <- ggraph(tg, layout = "fr") +
  geom_edge_link(aes(width = weight), alpha = 0.3, color = "gray60") +
  geom_node_point(aes(color = type, size = type)) +
  scale_edge_width(range = c(0.3, 2.5), name = "Co-bids") +
  scale_color_manual(values = c("FL" = "firebrick3", "Winner" = "steelblue4"),
                      labels = c("FL" = "Frequent Loser", "Winner" = "Winner")) +
  scale_size_manual(values = c("FL" = 2.5, "Winner" = 4),
                     labels = c("FL" = "Frequent Loser", "Winner" = "Winner")) +
  guides(size = "none") +
  theme_void(base_size = BASE_SIZE) +
  theme(
    legend.position = "bottom",
    legend.title = element_blank(),
    legend.margin = margin(t = -5)
  )

save_pub(p_net, "fig_network_graph.pdf")

# Also save a version with degree annotation
degree_data <- data.table(
  node = V(g_main)$name,
  type = V(g_main)$type,
  degree = degree(g_main)
)
top_winners <- degree_data[type == "Winner"][order(-degree)][1:min(5, .N)]
cat("  Top-5 most connected winners:\n")
print(top_winners)

# ============================================================================
# Save
# ============================================================================

net_graph_results <- list(
  graph = g_main,
  nodes = nodes,
  edges = edges,
  component_summary = list(
    n_components = components$no,
    largest_n_nodes = n_nodes_main,
    largest_n_edges = n_edges_main
  ),
  top_winners = top_winners
)

saveRDS(net_graph_results, "/tmp/p3v4_network_graph.rds")
cat("  Results saved: /tmp/p3v4_network_graph.rds\n")
cat("  Done.\n")
