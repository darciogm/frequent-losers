# v7-r2round1 — Roadmap

## Context

Bifurcated from `v6-jpub-short` on 2026-05-04 after macroization of v6 closed
all drift bugs and the manuscript compiled clean (errors=0, TBDs=0, ??=0)
across main / submission / OnlineAppendix / cover_letter. The first JPubE
short-paper-style referee report on v6 (R2, internal) flagged **storytelling**
problems even though the empirical core reproduces. v7 implements the 13
revisions identified by R2 plus an **expansion of the empirical evidence
behind the central interpretive claim**: the 23–30% under-the-gun (UTG)
gap between litigated and administrative urgent purchases is **not a single
mechanism** — it operates through three distinct channels.

v6 stays frozen as the macroized baseline. v7 is the rewrite.

## Thesis (locked)

**Court orders generate procurement cost premiums through three distinct
channels, all under the under-the-gun umbrella but operating at different
levels and via different mechanisms.**

| Channel | What it is | Where it operates | Magnitude (current data) | Statistical strength |
|---|---|---|---|---|
| **C1 — Demand fragmentation** | Sanctions force order shrinkage; smaller orders forgo bulk discounts | Across-comparison (urgent-vs-ordinary) AND within-urgent (lit-vs-admin) | ~50% of 5.4% urgent premium AND ~100% of 30% UTG gap | Robust |
| **C2 — Demand-side per-unit residual** | Officials accept worse unit price under time pressure even at identical order size | Across-comparison only (urgent-vs-ordinary residual after qty control) | ~3.0% residual | $p < 0.10$, marginal |
| **C3 — Supply-side within-firm markup** | Same supplier charges the same buyer more for the same item under urgency | Across-comparison (within-firm urgency premium) | ~2.5% within-firm | n.s. globally; expected to survive in concentrated subsamples |

**Critical interpretive distinction R2 corrected:**
- The personal-sanction-risk effect *holding quantity constant*
  (litigated-vs-admin Panel B) is **statistically zero** with current data.
  The 23–30% UTG gap operates **entirely through the quantity channel**.
- What the paper calls "under the gun" is therefore an **umbrella concept**
  for three distinct channels, not a single per-unit-price effect.
- The paper's contribution is the **decomposition** of the UTG umbrella
  into C1 (dominant) + C2 (marginal, urgency-induced) + C3 (conditional,
  supplier-power-induced).

## What I refuse to do (and why)

- **No structural causal claim.** Identification is descriptive. We
  decompose a within-item gap between two procurement regimes that share
  planning constraints but differ in penalty exposure. We do not estimate
  a counterfactual price under hypothetical sanction removal — that
  object is unidentified in this setting.
- **No dose-response paragraph in the main text.** The 6.8% / 12.4% /
  10.5% bin pattern was post-hoc rationalization; mid and hi are not
  statistically distinguishable. Footnote in §sec:utg, full results in
  Online Appendix.
- **No title change from v6.** `\title{}` stays "Bitter Pills: Judicial
  Enforcement and the Cost of Public Procurement in Brazil".
- **No fabrication of regex F1.** Hand-labeling of validation_sample.csv
  is a separate workstream; A.7 stays with discreet placeholder until
  labels are produced. Macro `\BPregexValidationStatus` auto-promotes.

## Approved work package — minimum publishable bundle

Total estimated effort: **~18–20h** of work spread across 5 waves.
Critical path = max of parallel children at each wave + wave-4 prose.

```
WAVE 0 — Thesis + scaffolding [3h, sequential-blocking]
  T0.1   Update THESIS.md with three-channel narrative (this file lives
         in v7 root; THESIS.md will be a separate lock file)
  T0.2   Add emit blocks for new macros to scripts:
           - 30_referee_analyses.R: welfare bounds (low + high), policy
             counterfactuals (admin expansion + framework agreements),
             calibration anchors (BPV, BHS within-buyer dispersion)
           - 03_main_regressions.R + 08_pub_tables.R: three-channel
             decomposition coefficients (C1 / C2 / C3 magnitudes)
  T0.3   values.tex schema additions; rerun 30 + 08

WAVE 1 — Per-channel positive evidence [parallel; max path 2h]
  T2.1   Reference price Panel B (30 min)
           Replicate Panel B mediation for bid_price_ref_log. Reference
           price is set BEFORE bidding so any residual urgency premium
           there isolates pure demand-side (cannot be supplier markup).
           Expected: residual >0, p<0.10. Confirms C2.

  T2.2   Firms Panel B (30 min)
           feols(ln_n_firms ~ urgent + bid_qty_log | ...). If urgency
           reduces firms even holding qty constant, C2 has a participation
           dimension on top of the price dimension.

  T2.4   Search-cost proxy (1h)
           Compute mean bids per participating firm per tender. Test
           whether urgency reduces this. Direct measure of officials'
           search behavior under pressure.

  T1.4   Item event study qty around first court order (2h)
           Extend 31_honest_did.R to outcome = bid_qty_log. Smoking gun
           of dynamic fragmentation: same item, qty drops after first
           court order arrives. Output: fig_event_study_qty.pdf.

  T3.3   Within firm-buyer-item triple regression (1h)
           Restrict to (firm × buyer × item) triples observed in both
           ordinary AND urgent. Tightest possible test of within-firm
           markup. C3 evidence at the cleanest level.

WAVE 2 — Heterogeneity tests [parallel; max path 3h]
  T2.3   Deadline intensity heterogeneity (3h)
           Extract delivery-deadline days from po_subject (NLP/regex).
           Test whether C2 demand-side residual is larger under shorter
           deadlines (1-3 days vs 7-10 days). Direct mechanism-by-
           variation evidence.

  T3.1   Market concentration heterogeneity for C3 (2h)
           Estimate within-firm urgency markup in subsamples by HHI or
           by number of active suppliers per item-year. Pulls C3 out of
           the n.s. global zone into significant-conditional zone.

WAVE 3 — Headline tabular and visual consolidation [parallel; max path 3h]
  T4.1   Three-channel decomposition table for urgent-vs-ord (1h)
           4-column table:
             (a) Total urgency effect
             (b) After log qty            -> C1 absorbed
             (c) After firm FE            -> C3 selection absorbed
             (d) After firm FE + log qty  -> residual = C2 + within-firm
           This is the new headline empirical exhibit.

  T4.2   Same decomposition for UTG (lit-vs-admin within urgent) (1h)
           Visually confronts the two levels: across-comparison has
           residual after controls; within-urgent does not.

  F.1    Three-channel decomposition figure (3h)
           Waterfall / cascade chart showing the 4-column decomposition
           visually. Top panel = urgent-vs-ord; bottom panel = UTG.
           Replaces fig_08_coefplot.pdf as the headline figure of the
           paper's empirical contribution.

  F.2    Distributional density (admin/lit qty ratio) (1h)
           Kernel density of (admin order qty / lit order qty) within
           item-month with both types present. Raw distributional
           evidence supporting C1. Becomes a Figure A.X in OnlineAppendix
           or sub-panel of F.1.

  T1.1   Distributional figure of qty fragmentation (1h)
           [Subsumed by F.2 if F.1 + F.2 cover it; otherwise independent
           density of qty by purchase-type]

WAVE 4 — Prose rewrite [4-6h, depends on Waves 0-3]
  Abstract: rewrite to lead with three-channel decomposition under UTG
            umbrella; mechanism-led with UTG as institutional vehicle.
  Intro:    rewrite contributions paragraph to declare descriptive
            decomposition once and explicitly. Drop hedges from later.
  §sec:institutional:  cut from 4 paragraphs to 2.
  §sec:utg:            expand identification defense (selection mechanism,
            committee bias direction = theoretically ambiguous, not
            "conservative"); promote within-item balance from appendix
            footnote to main-text test.
  §sec:main_results:   reframe Panel B mediation as C1 vs C2 split.
  §sec:supplier_fe:    add 1 sentence connecting to mediation
            decomposition (orthogonal-dimensions framing).
  §sec:utg dose-response: drop main-text paragraph, footnote.
  §sec:heterogeneity:  fold T2.3 (deadline) and T3.1 (concentration) in.
  Conclusion: replace point-estimate $16-18M back-of-envelope with
            welfare bounds $16-90M; add quantitative policy counter-
            factuals (admin expansion + framework agreements).
  References.bib: add 2-3 refs verified per anti-hallucination protocol
                  (Bandiera-Best-Khan-Prat 2021 QJE,
                   Carril-Gonzalez-Lira-Walker 2024 AEJ:Applied,
                   Acharya-Blackwell-Sen 2016 AJPS).
  Title:    NO change.

WAVE 5 — Compile + audit + commit + deploy [1h]
  - Compile main / submission / OnlineAppendix / cover_letter (full
    triple pass with bibtex + xr-hyper).
  - Forensic audit: 0 hardcodes, 0 dangling refs, 0 TBDs, all macros
    declared, all tables/figures linked to producing scripts.
  - Commit on bitter-pills (branch v13-jle).
  - Copy v7-r2round1/manuscript/paper/main.pdf -> hub repo.
  - Sync site .md (research/index.md, working-papers.md, paper.md,
    changelog.md new entry, storytelling_video.html if mechanism story
    changes the narration).
  - Push hub. CI deploys.
```

## Implementation contract (rules of the game)

1. **Macros inviolable.** Every new number, sample size, table input,
   figure path that enters any v7 .tex resolves through values.tex via a
   \BPxxx macro. No hardcoded numerals in prose, captions, or table cells.
2. **No script fabrication.** No simulating or fabricating regex F1
   labels. No fitting heterogeneity bins to find a desired pattern. If
   T3.1 (market concentration) gives all-n.s. across splits, C3 stays
   n.s. and the paper says so.
3. **Hedge budget.** ONE declaration of "descriptive decomposition" in
   the intro. Drop the four others currently in §sec:main_results,
   §sec:utg, §sec:heterogeneity, conclusion.
4. **Three-channel framing is the spine.** Every empirical paragraph
   answers "which channel does this speak to?" If a result speaks to
   none, it goes to OnlineAppendix or gets dropped.
5. **Anti-hallucination protocol on bibliography (mr-bitter-pills rule).**
   WebFetch / WebSearch any new citation; verify (a) authors, (b) year +
   venue, (c) content. Mark [VERIFIED✓] in commit message before commit.
6. **No AI markers in commits or code (monorepo rule).** Authorship of
   commits is darciogm. No "Co-Authored-By: Claude" tags. No AI tags in
   script comments.
7. **Branch + path discipline.** All work in
   `paper1-bitter-pills/v7-r2round1/`. Scripts in `../v4/analysis/` are
   patched to emit to v7's values.tex (NOT v6's). v6 stays frozen.

## Decision log (to be appended as work proceeds)

(empty — entries added at each wave gate)

## Success criteria

A reviewer reading the v7 manuscript should be able to answer:

1. What is the paper's empirical contribution? → Three-channel
   decomposition of the procurement cost of judicial enforcement.
2. What identifies it? → Within-item × within-time × within-buyer
   variation; UTG comparison between admin and litigated urgent
   purchases as the institutional vehicle.
3. What does each channel contribute to the headline numbers? → C1
   accounts for ~half the 5.4% urgency premium and ~all of the 23–30%
   UTG gap. C2 is the residual ~3% per-unit demand-side. C3 is the
   ~2.5% within-firm supply-side, conditional on market concentration.
4. What are the policy implications, in dollars? → Per-unit-margin
   cost band $16–90M/yr; admin-expansion reform recovers up to UTG-pct
   of committee-eligible spending; framework agreements address C1
   directly.
5. What does the paper NOT claim? → No counterfactual structural
   estimate of sanction removal; no claim that personal sanction risk
   per-unit-price differential is positive (it's statistically zero
   in our data).
