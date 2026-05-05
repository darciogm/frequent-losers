# Bitter Pills — v8 Sourcing Reframe ROADMAP

**Trigger**: mr-bitter-pills referee report (REVISOR CRÍTICO mode, JPubE Short
calibration) on v7-r2round1, 2026-05-04.

**Active branch**: `v8-sourcing-reframe` (this directory)
**Frozen baselines**: `v6-jpub-short` (deeper audit anchor); `v7-r2round1`
(immediate-prior version, frozen as the cascade-era reference).
**Target**: Journal of Public Economics (Short Paper format).

---

## What v8 abandons (relative to v7-r2round1)

1. **Three-channel cascade (C1/C2/C3)** as a main-text decomposition.
   Empirically over-identified given Acharya, Blackwell & Sen (2016): the
   UTG cascade has C1 = 42.32 pp on a 29.44 pp total and a residual that
   flips to −14.54 pp once log quantity is conditioned on. The Panel B
   sign reversal (admin coef = +0.117 vs Panel A −0.262) is the textbook
   post-treatment-bias signature. v8 retires the cascade table from the
   main text and demotes its components to robustness exhibits.
2. **"30% UTG" headline** without selection bounds. v7 acknowledges
   admin-channel selection as "ambiguous in sign" but does not contain it.
   v8 replaces this with formally bounded estimates.
3. **`$16–88M` welfare range** that conflates the urgent-vs-ordinary
   premium with the litigated-vs-administrative premium across different
   spending bases. v8 reports a single defensible bound with explicit
   95% CI, computed off the bounded UTG.
4. **"First quantitative decomposition"** as a contribution claim. The
   decomposition itself is the locus of the post-treatment-bias problem.
5. **Wave 5 word compression to 5,965 words** as a binding constraint
   *during* the substantive revision. Compression returns at the end,
   after the empirical core lands.

## What v8 keeps

- BEC-SP institutional setting and data documentation (Sec 2–3).
- Never-litigated placebo (negative for both ref and neg prices, used as
  external validity check).
- Heterogeneity by market concentration — reinterpreted under the
  sourcing frame.
- BJS event study + dynamic quantity-drop story.
- Macro discipline (`values.tex`).
- DuckDB-default execution policy.
- Anti-hallucination ref protocol.

## What v8 introduces

### A. New empirical objects (must build before the manuscript can stand)

1. **Bounded UTG estimate.**
   - **Manski-Lee bounds** under monotone assumptions on committee
     rejection (admit cost-effective, reject expensive outliers).
   - **Heckman parametric selection model** on committee acceptance.
     First stage: probability of admin-channel acceptance given pre-period
     item characteristics (mean ref price prior to first court order, dose
     class, supplier-base depth, SUS-formulary status, modality). Second
     stage: UTG with inverse Mills ratio.
   - Output table `tab_utg_bounded`: panel rows for [naive UTG | Manski-Lee
     low | Manski-Lee high | Heckman corrected | preferred bounded].
   - Macros: `\BPutgBoundLow`, `\BPutgBoundHigh`, `\BPutgPointBounded`,
     `\BPutgHeckmanCoef`, `\BPutgHeckmanSE`, `\BPutgHeckmanRho`.

2. **Both-types-cell representativeness table.**
   - Compare 4,402 both-types item × month cells vs. 36,564 single-type
     cells along: mean log ref price, mean log neg price, modality split,
     SUS-formulary share, mean log quantity, mean firms, mean supplier-base
     depth.
   - Output table `tab_both_types_cells`. Macros under `\BPbothCell*` prefix.

3. **Rambachan-Roth (2023) HonestDiD sensitivity** on the BJS event study.
   - Maximum slope deviation `M̄` consistent with significant t=0
     coefficient.
   - Smoothness restriction `M` bounds.
   - Output figure `fig_event_study_honest_rr.pdf` with sensitivity
     bounds; macro `\BPrrSensitivityBound`.

4. **Wild cluster bootstrap** on the UTG specifications.
   - `boottest` (or its R/Python equivalent) on the preferred and
     item × year-month UTG specifications.
   - Macros: `\BPutgBoottestPval`, `\BPutgBoottestCIlow`,
     `\BPutgBoottestCIhigh`.

5. **Reconciliation of mechanical C1 vs observed UTG.**
   - Decomposition equation: observed UTG = mechanical C1 prediction +
     within-firm offset + supplier composition residual.
   - Within-firm-buyer-item triple coefficient as the offsetting force
     (negative −0.027 vs the +57.7% mechanical bulk-discount prediction).
   - Output table `tab_utg_reconciliation` with row-by-row decomposition.

6. **Single welfare bound.**
   - Selection-bias-corrected UTG point estimate × sanction-exposed share
     of litigated spending × `$300 M`.
   - Report 95% CI on the UTG point.
   - Macros: `\BPwelfareBound` (single number), `\BPwelfareBoundCIlow`,
     `\BPwelfareBoundCIhigh`. Drop `\BPwelfareBoundRange`.

### B. Manuscript reframe

- **New title**: "Bitter Pills: Sourcing under Compressed Timelines and the
  Cost of Compliance in Brazilian Public Health Procurement"
  (working candidate; see Abstract draft for variants).
- **Abstract**: lead with the sourcing-vs-pricing dichotomy, not with the
  30% UTG. Magnitudes anchored against Bandiera-Prat-Valletti (2009),
  Best-Hjort-Szakonyi (2023), Bosio et al. (2022) explicitly.
- **Three contributions** reformulated:
  1. First within-item evidence on the price impact of court-mandated
     procurement.
  2. **Sourcing-vs-pricing dichotomy**: the price margin operates
     entirely through equilibrium supplier selection and demand
     fragmentation, not within-firm markup. This is the conceptual
     contribution.
  3. Timeline compression (this paper) vs. timeline extension
     (Coviello, Mariniello & Spagnolo 2018) as alternative mechanisms by
     which judicial intervention raises procurement costs.
- **Section 4 (Empirical Strategy)** rewritten around the bounds, not
  around the "ambiguous sign" hedge.
- **Section 5 (Results)** restructured: lead with within-firm-buyer-item
  triple coefficient (the sourcing-vs-pricing pivot), then bounded UTG,
  then C1 fragmentation, then composition heterogeneity, then placebo and
  event study.

### C. Bibliography work

Refs to verify under the anti-hallucination protocol before any v8 bib
commit:
- `coviello2018court`, `coviello2018bidding`, `carril2026competition`,
  `glaeser2003rise`, `szucs2024discretion`, `lewisfaupel2016can`,
  `baltrunaite2021discretion`, `prendergast2007bureaucrats`,
  `acharya2016explaining`.

Each requires WebSearch + WebFetch on (authors + year + venue) and a
content-match check (abstract minimum).

## DAG-optimized implementation plan

The original linear "Wave 1 → Wave 2 → ..." schedule serialized tasks
that are in fact independent. Below is a dependency DAG with explicit
parallelism. Tasks at the same layer run in parallel; arrows indicate
strict dependencies.

### Task inventory (with IDs used in the DAG)

| ID | Task | Output |
|----|------|--------|
| **A** | Anti-hallucination refs audit (9 refs) | verified `References.bib` |
| **N** | Section 2 (Inst Bg) light edit | `InstitutionalBackground.tex` |
| **O** | Section 3 (Data) light edit | `DataAndSample.tex` |
| **I0** | `values.tex` schema rebuild (drop cascade, add bounded/RR/boot/recon macros) | `values.tex` skeleton |
| **B** | Manski-Lee bounds on admin selection | `tab_utg_lee_bounds` |
| **C** | Heckman parametric selection model | `tab_utg_heckman` + Mills |
| **D** | Both-types-cell representativeness table | `tab_both_types_cells` |
| **E** | Rambachan-Roth (2023) HonestDiD sensitivity | `fig_event_study_honest_rr.pdf` |
| **F** | Wild cluster bootstrap on UTG SEs (`boottest`) | `tab_utg_boottest` |
| **G** | C1-mechanical vs observed UTG reconciliation table | `tab_utg_reconciliation` |
| **H** | Single welfare bound (selection-bias-corrected) | `\BPwelfareBound*` macros |
| **T** | Headline figure: sourcing-vs-pricing coefplot | `fig_sourcing_vs_pricing.pdf` |
| **J** | Section 4 (Empirical Strategy) rewrite | `EmpiricalStrategy.tex` |
| **K** | Section 5 (Results) rewrite (lead with within-firm) | `Results.tex` |
| **L** | Section 1 (Introduction) rewrite | `Introduction.tex` |
| **M** | Section 6 (Conclusion) rewrite | `Conclusion.tex` |
| **P** | Online Appendix curation (absorb retired cascade) | `Appendix.tex` |
| **S** | Title finalization | `main.tex` `\title{}` |
| **Q** | Cover letter rewrite + AE list refresh | `cover_letter.tex` |
| **R** | JPubE Short word compression to ≤6,000 words body | full body |
| **Z** | Final compile + numbers audit + commit | `main.pdf` |

### Dependency edges

```
A          → L, M, Z          (refs verified before any new bib citation lands)
N, O, I0   → J, K, L, M, P    (manuscript-side prereqs)
B, C       → H, J, K, L       (bounded UTG enters Strategy/Results/Intro/welfare)
D          → J, L             (both-types-cell goes into Strategy + Intro caveat)
E, F       → K, P             (RR + boot land in Results main + Appendix robustness)
G          → T, K, L          (within-firm reconciliation is the headline pivot)
H          → M, L             (welfare bound enters Conclusion + Intro implication)
T          → K, Z             (headline figure rendered, referenced in Results)
J, K, L, M → P, R, S          (manuscript locks before Appendix curation, compression, title)
P, R, S    → Q, Z             (submission package after manuscript stable)
Q          → Z
```

### Layered execution (each layer parallel internally)

```
LAYER 0 — PRE-FLIGHT (1 day, 4 tracks parallel)
  ├── A   : refs audit (9 refs, WebSearch + WebFetch)
  ├── N   : Section 2 light edit
  ├── O   : Section 3 light edit
  └── I0  : values.tex schema rebuild

LAYER 1 — EMPIRICAL CORE (5–8 days, 6 tracks parallel)
  ├── B   : Manski-Lee bounds          ┐
  ├── C   : Heckman selection model    │ all consume same parquet input;
  ├── D   : both-types-cell table      │ disjoint output tables;
  ├── E   : Rambachan-Roth sensitivity │ no inter-task dependencies
  ├── F   : wild cluster bootstrap     │
  └── G   : reconciliation table       ┘

LAYER 2 — BRIDGE (1 day, 2 tracks parallel)
  ├── H   : single welfare bound       (← B, C)
  └── T   : headline figure            (← G)

LAYER 3 — MANUSCRIPT REFRAME (7–10 days)
  Critical path within layer:
    G (already done) → K (Results lead) → L (Intro reflects K) → R (compress)
  Parallel branches inside layer:
    ├── J : Section 4 (← B, C, D, I0)
    ├── K : Section 5 (← G, B, C, E, F, T, I0) — CRITICAL
    ├── L : Section 1 (← K stable, A, B, C, G, H) — semi-critical
    └── M : Section 6 (← H, A) — independent of K once H lands

LAYER 4 — APPENDIX + COSMETIC (2–3 days, 2 tracks parallel)
  ├── P   : Online Appendix curation (← K, E, F, retired cascade)
  └── S   : Title finalization (← L narrative locks)

LAYER 5 — SUBMISSION PACKAGE (2–3 days)
  ├── Q   : Cover letter (← L, S)
  └── R   : Word compression to JPubE Short cap (← J, K, L, M)
       └── Z : final compile + numbers audit + commit (← all)
```

### Critical path

```
I0 → G → K → L → R → Z
```

The critical path has length ~12–15 working days (Layer 0 + G in Layer 1 +
K in Layer 3 + L in Layer 3 + R in Layer 5 + Z). Everything else can be
hidden behind it through parallelism. **Implication**: prioritize G
inside Layer 1 (it sits on the critical path) and start it first; B, C,
D, E, F can run alongside without blocking.

### Parallelization rules

1. **All Layer-1 scripts share input but write disjoint outputs**: no
   write contention; safe to run as 4–6 simultaneous R sessions on a
   12-thread box, each capped at `setFixest_nthreads(2)` to fit the
   `n_workers × peak_per_worker ≤ 16 GiB` rule.
2. **Refs audit (A) is I/O-bound (WebSearch / WebFetch)**: schedule it
   in Layer 0 alongside the empirical-script kickoff so it never blocks
   anything.
3. **K (Results) is the longest single-thread block in Layer 3** — start
   it the moment G lands; do not wait for B, C, E, F (they patch in as
   sub-paragraphs once available).
4. **L (Intro) waits for K to stabilize** because the Intro's headline
   findings are summaries of K's main results; rewriting L too early
   means rewriting it twice.
5. **M (Conclusion) is parallel to K** once H lands — assign it a
   different drafting session.
6. **R (compression) is the final critical-path step**; budget at least
   2 days because the JPubE Short cap (≤6,000 body words, ≤5 main-text
   exhibits) is binding and the v7-style compression will not survive
   the substantive rewrite.

### Estimated effort under the DAG

| Layer | Wall-clock days (parallel) | Sequential equivalent |
|-------|---------------------------:|----------------------:|
| 0     | 1                          | 2                     |
| 1     | 5–8 (parallel)             | 10–14 (serial)        |
| 2     | 1                          | 1                     |
| 3     | 7–10                       | 10–14                 |
| 4     | 2–3                        | 3                     |
| 5     | 2–3                        | 3                     |
| **Total** | **18–26 days (~4–5 wk)** | **29–37 days (~6–8 wk)** |

The DAG buys roughly 35–40% wall-clock vs. the linear v1 schedule
(6–10 weeks). The empirical Layer 1 is the largest source of speed-up.

### Hand-off discipline

Each Layer-1 task must, on completion, emit:
- The output table/figure file(s) under `output/tables/` or `output/figures/`.
- Its block of `\BPxxx` macros into `manuscript/paper/values.tex`
  (between `% ===== AUTO BEGIN: <script> =====` and `% ===== AUTO END: ===`).
- A telemetry log under `logs/<script>.log` (RSS, threads, runtime).

Layer-3 prose rewrites must reference numbers exclusively through the
macros emitted in Layers 1–2. No hardcoded numerals — the
`feedback_macro_bound_numbers` rule applies in v8 with the same force
as in v7.

## Files in this directory at v8 kickoff

- `ROADMAP.md` — this file.
- `manuscript/paper/Abstract_v8_draft.tex` — new abstract draft (Wave 0).
- `manuscript/paper/Introduction_v8_draft.tex` — Section 1 outline (Wave 0).
- `analysis/` — empty; new scripts land here (numbered 40–49 to avoid
  collision with v7's 30s).
- `output/` — empty; tables and figures land here.
- `logs/` — empty; per-script telemetry logs.
