# ============================================================================
# seeds.R — single source of truth for RNG seeds in v6-jpube
#
# All numbered scripts that draw random numbers MUST source this file and call
# set.seed(seed_for_script(NN)) at the top. Bootstrap loops should additionally
# use seed_for_iter(NN, b) inside each iteration so a single bs replicate is
# auditable on its own.
#
# Reproducibility contract:
#   - MASTER_SEED is the only externally-tunable knob.
#   - Per-script seed = MASTER_SEED + script_number  (collision-free: the
#     largest gap between two adjacent script numbers is 7, our scripts go
#     32..99, so the seed range is 20,260,455 .. 20,260,522 — well-spaced).
#   - Per-iteration seed = MASTER_SEED + script_number*1000 + iter
#     (gives each (script, iter) pair a globally unique seed).
#   - Reseeding does NOT advance the RNG counter unpredictably; it sets it
#     deterministically. Multiple set.seed() calls inside a script with the
#     same value are idempotent.
#
# To audit a specific Monte Carlo result:
#   1. Find the producing script (e.g., 45_bne_simulation.R).
#   2. Compute its seed: 20260423 + 45 = 20260468.
#   3. set.seed(20260468) in a fresh R session reproduces the simulation.
# ============================================================================

MASTER_SEED <- 20260423L

# Derive a per-script seed from a numeric id or a script filename.
seed_for_script <- function(script_id) {
  if (is.character(script_id)) {
    n <- suppressWarnings(as.integer(sub("^([0-9]+).*", "\\1", script_id)))
  } else {
    n <- suppressWarnings(as.integer(script_id))
  }
  if (is.na(n) || n < 0L) {
    stop("seeds.R: could not parse script id '", script_id,
         "' into a non-negative integer.", call. = FALSE)
  }
  MASTER_SEED + n
}

# Derive a per-iteration seed for bootstrap / cluster-resample loops.
# Use this inside `for (b in 1:B)` constructs:
#   set.seed(seed_for_iter(56, b))
# Each (script, iter) pair gets a globally unique seed so an individual bs
# replicate can be re-run in isolation without re-running the whole loop.
seed_for_iter <- function(script_id, iter) {
  base <- seed_for_script(script_id)
  base + as.integer(iter) * 1000L
}
