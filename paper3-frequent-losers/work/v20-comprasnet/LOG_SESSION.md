# v20-comprasnet — session log

Rolling diary of work executed inside `work/v20-comprasnet/` or in
service of it (i.e., scripts and outputs in shared dirs that
support v20).

## 2026-05-22 — kickoff session

### Context restored

Picked up from the previous session that was terminated mid-
download. The bulk_acquire API process (PID 3504) was already
running in background via nohup and had completed `licitacao` and
`pregao` endpoints (574/574 weeks each) and was ~38% through
`item_pregao`. API output is auxiliary metadata only — does NOT
expose participant lists; load-bearing data path is Portal CGU
bulk dumps (per `COMPRASNET_PATH_TO_CONFIRMED.md` §8.2).

### Work executed

1. **Phase 0+1+2 ComprasNet build** — already completed via
   `scripts/00_build_eventlevel_comprasnet.py --skip-download --skip-validate`
   (4.4 min DuckDB-native). Outputs in
   `data/processed_comprasnet/`:
   - `bid_level_full.parquet` — 51,264,718 participation rows
   - `firm_loss_stats.parquet` — 92,600 distinct firms
   - `firm_tender_map.parquet` — 50,979,816 firm-item pairs
   - `FREQ_PARTICIP_rebuilt.parquet` — 35,943 always-losers
   - `LOSERS_rebuilt.parquet` — 582,812 (OC, item) FL pairs
   - **Federal IQR threshold = 32** (vs BEC 14)
   - **Federal FL firms (tenders_count > 32) = 6,303** (vs BEC 2,735)

2. **Stage 1c plan written** — `STAGE_1C_CADE_COMPRASNET_LINKAGE_PLAN.md`
   in paper root. 4 decisions resolved in modo revisor (D1: BEC
   reuse → RF base if needed; D2: inclusive with disclaimer;
   D3: v1 POC first, v2 if needed; D4: defer Imhof Stage 2).

3. **CADE × ComprasNet linkage v1** — `scripts/65_cade_comprasnet_linkage.py`
   written + executed. Output: `data/processed_comprasnet/cade_link_v1/`.

   **Headline result:**
   - 25 CADE rows with original CNPJ + 20 enriched via BEC reuse =
     **45 CADE raízes (45 distinct after dedupe)**
   - **14 raízes matched** to federal participation
   - **19 direct-defendant estabs** (vs 47 BEC)
   - **20,213 anchored (tender, item) pairs** (vs ~85K LOSERS BEC)
   - **3,019 cobidder firms** (vs 193 BEC — 15× larger)
   - **62 FL cobidders** (vs 193 BEC; FL share = 2.05% vs BEC 100%
     of cobidder set by construction)
   - **122 always-loser cobidders** (4.0% of cobidders, well below
     universe 38.8% — pattern consistent with BEC)

   **Anti-false-positive correction applied this session:**
   raised fuzzy threshold from 0.85 → 0.92 after detecting that
   Visaplas (sacos lixo SP) was incorrectly matched to OkPlast's
   CNPJ. Added CNPJ-uniqueness rule (no CNPJ assigned to multiple
   CADE rows via fuzzy match — keep highest-score, demote others).

4. **15 firms still unmatched after v1** (BEC reuse exhausted).
   Top candidates for D1 step 2 (RF base):
   - Convida (score 0.905, just below threshold)
   - Tejofran (0.889)
   - Siemens AG/Ltda (0.824) — multinational
   - CAF Brasil (0.75)
   - Drogafonte (0.515)
   - Frontal Group (0.452) — Nacional cartel
   - Dimaci (0.464)

### Decisions taken this session

- **D1 step 2 (Receita Federal base 5 GiB lookup) deferred** —
  cobidder set 3,019 is already 15× BEC. Power-of-test sufficient
  for Fase 1c.3 (replication ANs). Re-evaluate if any AN finds
  sub-power.
- **Re-run linkage with fuzzy 0.92** committed as the default
  (was 0.85 before Visaplas/OkPlast incident).
- **case_scope = inclusive (national + state)** as D2 resolution;
  state firms account for 14 of 19 estab rows, national 5.
- **D1 passo 2 NÃO executado** — fica como condicional contingente
  ao resultado de Fase 1c.3.

### Files created / modified this session

| File | Operation | Where |
|---|---|---|
| `STAGE_1C_CADE_COMPRASNET_LINKAGE_PLAN.md` | created + §7 expanded | paper root |
| `scripts/65_cade_comprasnet_linkage.py` | created (504 lines) | shared scripts |
| `data/processed_comprasnet/cade_link_v1/` | created (6 files, ~310 KB) | shared data |
| `work/v20-comprasnet/README.md` | created | v20 dir |
| `work/v20-comprasnet/LOG_SESSION.md` | created (this file) | v20 dir |

### Where we stopped

- v18 (`work/v18-editor/submission_clean/`) — **unchanged**, still
  canonical JLEO submission.
- v20 — directory created, linkage v1 done. **Fase 1c.3 (replicate
  5 ANs on federal panel) NOT YET STARTED.**
- API legacy download (PID 3504) — still running in background;
  irrelevant to load-bearing path.

### Next concrete steps (need autor authorization)

1. **Adapt 5 R scripts** for `--source=comprasnet` flag (1-2 days):
   - `02_analysis.R` (regression panel)
   - `36_gate_d1_harmonized.R` (FL14 vs cobidder AUC, D1 gate)
   - `40_leakage_audit_d3.R` (CV out-of-fold + temporal holdout)
   - `42_operational_metrics.R` (precision@k)
   - `43_precision_at_k_audit.R` (temporal-holdout audit)

2. **Produce federal-vs-BEC comparison tables**:
   - Headline AUC table: FL federal vs FL BEC across 5 metrics.
   - Sub-table by case_scope (D2 robustness).
   - Leakage audit table per panel.

3. **Decide whether to run D1 step 2** based on Fase 1c.3
   intermediate results. Likely *not* needed.

4. **Draft Appendix C** (~6 pages) in
   `work/v20-comprasnet/manuscript/sec_app07_comprasnet.tex`.

---

## 2026-05-22 (continuation) — Fase 1c.3 first batch

Three of five ANs done. **Validation pass against BEC reproduces
paper values to ε** (FL14 firm-level AUC: paper 0.924 vs v20 0.9237).
Federal results documented in `output/CONSOLIDATED_RESULTS.md`.

### Headline numbers (all with BEC validation pass)

| AN | BEC | Federal | Verdict |
|---|---:|---:|---|
| AN-001 (distribution) | always-loser share 40.6%, FL share 16.2% | 38.8%, 18.1% | ✅ replicates |
| AN-004 binary AUC | 0.9237 [0.921, 0.926] | 0.6644 [0.620, 0.709] | ⚠️ direction yes, magnitude no |
| AN-004 continuous AUC | 0.9389 [0.932, 0.946] | 0.7507 [0.710, 0.792] | ⚠️ same |
| AN-004 DeLong | continuous wins p=1.2e-5 | continuous wins p=3.3e-8 | ✅ direction preserved |
| AN-007 binary vs directs | 0.4989 [0.464, 0.534] | 0.4649 [0.464, 0.466] | ✅ boundary confirmed |
| AN-007 continuous vs directs | 0.3826 [0.322, 0.443] | 0.3882 [0.298, 0.478] | ✅ winners are not ranked |

### Threshold sensitivity (federal-only sweep)

Federal AUC peaks at threshold **20** (AUC 0.7050), not at the
IQR-derived 32 (AUC 0.6644). Continuous classifier (log_tc, AUC
0.7507) dominates all binary thresholds federally. Implication: the
operational rule needs panel-specific calibration; IQR-rule is not
universal.

### Scripts written

- `work/v20-comprasnet/scripts/an004_cobidder_auc.R`
- `work/v20-comprasnet/scripts/an004b_threshold_sensitivity.R`
- `work/v20-comprasnet/scripts/an007_direct_defendant_auc.R`
- `work/v20-comprasnet/scripts/an001_zero_win_rank.R`

All accept `bec|comprasnet` as 1st arg and replicate the pROC+arrow+
data.table stack from `scripts/36_gate_d1_harmonized.R`. FL convention
`tenders_count >= threshold` enforced throughout (commits bd504b5,
67aa4eb).

### What survives, what doesn't

**Survives federally** (with BEC validation):
- Loser-side concentration is real (AN-001 distribution tail).
- Classifier discriminates cobidders > random (AN-004, p<1e-5).
- Continuous dominates binary (DeLong, same direction both panels).
- Winners are not ranked by FL (AN-007, AUC near 0.5).

**Does NOT survive federally**:
- AUC ≈ 0.92 universally → federal is 0.66–0.75.
- IQR-rule gives correct threshold → federal peak is at 20, not 32.
- Plug-and-play across panels → needs panel tuning.

### R&R impact estimate (mr-frequent revised)

Federal directional validation + honest absolute-AUC drop ⇒ R&R
JLEO from ~65-70% to **~72-77%**. Below 75-80% in original Stage 1c
plan because federal AUC gap (0.26) is wider than expected.

---

## 2026-05-22 (continuation 2) — AN-006 + AN-014 done

Year-stamped panel built (`scripts/66_year_stamped_panel.py`, 40s,
51.3M rows split 31.4M/19.9M between 2013-16 and 2017-19).

### AN-006 (TWO ground-truth variants)

| Variant | AUC binary federal | AUC continuous federal | BEC paper |
|---|---:|---:|---:|
| GT-A BEC-style (all-period cobidders) | **0.6005** | **0.6852** | 0.79-0.85 |
| GT-B ultra-strict (test-period only) | 0.5069 | 0.5880 | — |

Drop pattern federal in-sample 0.66 → holdout 0.60 ≈ BEC drop pattern
0.92 → 0.79-0.85. Absolute level federal much lower.

### AN-014 (drop chain)

| Measure | Federal binary | Federal continuous |
|---|---:|---:|
| M1 in-sample | 0.6644 | 0.7507 |
| M2 5-fold CV mean | 0.6677 (SD 0.029) | 0.7486 (SD 0.027) |
| M3 temporal holdout | 0.6005 | 0.6852 |
| Drop M1→M2 | ~0 (no random-partition leakage) | ~0 |
| Drop M2→M3 | **+0.067** | **+0.063** |

5-fold CV firm-level partition ≈ in-sample in both panels (no
overfitting of trivial threshold classifier). Temporal split tira ~0.06
AUC in both panels — pattern preserved, level different.

### Scripts written

- `scripts/66_year_stamped_panel.py` (40s, builds bid_level_full_year.parquet)
- `work/v20-comprasnet/scripts/an006_strict_holdout.R` (2 GT variants)
- `work/v20-comprasnet/scripts/an014_leakage_audit.R` (M1+M2+M3 drop chain)

### Bottom line federal vs BEC (5 ANs complete)

| AN | BEC | Federal | Verdict |
|---|---:|---:|---|
| AN-001 distribution | AL share 40.6%, FL share 16.2% | 38.8%, 18.1% | ✅ replicates |
| AN-004 firm-level binary AUC | 0.9237 | 0.6644 | ⚠️ direction yes, magnitude no |
| AN-004 firm-level continuous AUC | 0.9389 | 0.7507 | ⚠️ same |
| AN-006 holdout BEC-style binary | 0.79-0.85 | 0.6005 | ⚠️ below BEC range |
| AN-006 holdout BEC-style continuous | 0.79-0.85 | 0.6852 | ⚠️ below BEC range |
| AN-006 holdout ultra-strict binary | — | 0.5069 | random when fully temporally constrained |
| AN-007 vs directs binary | 0.4989 | 0.4649 | ✅ boundary confirmed |
| AN-007 vs directs continuous | 0.3826 | 0.3882 | ✅ winners not ranked |
| AN-014 M2 5-fold CV | ≈ in-sample | ≈ in-sample | ✅ no overfitting detected |
| AN-014 M3 temporal drop | ~0.06-0.13 | 0.067 | ✅ similar magnitude |

**R&R impact, revised after AN-006 + AN-014 evidence:**

Federal AN-006 BEC-style 0.60 vs BEC 0.79-0.85 is a wider gap than
expected from AN-004 alone. Two narrative options:

1. **"Federal panel reveals deployment-realistic floor."** Frame the
   federal numbers as the operational performance once temporal
   discipline is enforced. The BEC 0.92 is in-sample; the BEC
   holdout 0.79-0.85 is realistic; the federal 0.60 is even more
   realistic. Editor reads this as honesty.

2. **"Federal differences need panel-specific tuning."** Frame as
   evidence that the screen is institution-coupled rather than
   universal. Defensible if combined with the discipline already
   adopted in v18 ("FL is operational implementation; concept is
   loser-side concentration").

mr-frequent recommendation: **option 1 strongly**. Option 2 looks
like motivated reasoning to a tough referee.

R&R bump revised estimate: **70-74%** at JLEO (down from earlier
72-77% estimate). The AN-006 holdout gap is a real cost, but
falsifiable cross-panel honesty has its own credit.

### Pending (next session)

- **AN-039 / AN-040** federal (selection + mechanism decomposition).
  Requires enriching panel with `Valor Item` from ItemLicitação.csv.
  ~1 day.
- **D1 step 2** (RF base enrichment, +5-7 raízes). Marginal lift; low
  priority.
- **Update v20-editor main manuscript** with 1-paragraph reference to
  Appendix H and 1-sentence abstract addition (`sec01_introduction`).
- **Appendix H replication artifact pointers** could move to a
  separate `cade_link_v2/` directory if D1 step 2 runs.

---

## 2026-05-23 (continuation 3) -- Appendix H integrated

Wrote `sec_app07_comprasnet_submission.tex` (~6 pages) and wired it
as **Appendix H** into the v20-editor online appendix master.

### Files created/modified

| File | Action |
|---|---|
| `work/v20-editor/submission_clean/sec_app07_comprasnet_submission.tex` | created (~280 lines, Appendix H prose) |
| `work/v20-editor/submission_clean/online_appendix_submission_clean.tex` | edited (97-line block of federal macros + `\input{sec_app07...}`) |

### Build verification

- `pdflatex` exit code: 0, zero errors, zero warnings.
- Pages: 16 (original) -> 22 (with Appendix H).
- PDF: `online_appendix_submission_clean.pdf`.

### Bug encountered + lesson

Initial compilation failed with `Missing \begin{document}` errors
that bisecting eventually located in macro names containing digits.
LaTeX commands accept only letters (a-z A-Z); a macro named
`\valFedLeakageM1binary` is parsed as `\valFedLeakageM` followed by
literal `1binary`, which on `\newcommand{...}{...}` triggers
`#10`/`#11`-style parameter errors. Renamed all 18 digit-bearing
macros (`\valFedTcP50` -> `\valFedTcPFifty`, `\valFedLeakageM1binary`
-> `\valFedLeakageMOneBinary`, etc.) in both the master and the
appendix prose.

Two further compile-time annoyances were resolved along the way:
em-dash (U+2014) in comments inside a `.tex` file loaded via
`\input{}` in the preamble was being mis-parsed before `inputenc`
took effect; switching the file to ASCII-only fixed it (memo
update: keep ALL `.tex` files in the macro chain ASCII). Macros
embedding `^{-5}` or `\times` in their replacement text are fine
inside `$...$` at call site, but require the call site to be in
math mode -- safer to call them as `$\valFoo$`.

### Pending (next session)

- AN-039 / AN-040 federal (still ~1 day if pursued).
- D1 step 2 (RF base) still optional.

---

## 2026-05-23 (continuation 4) -- Main manuscript wired to Appendix H

Three surgical insertions in the main manuscript pointing to
Appendix H. Calibrated tone (modo revisor): qualitative survival
foregrounded; absolute-AUC drop reported as institution-coupled
calibration, not failure.

### Edits

| File | Insertion |
|---|---|
| `sec_frontmatter_submission.tex` | 1 sentence at the end of the abstract |
| `sec01_introduction_submission.tex` | 1 paragraph between "boundaries" and "broader lesson" |
| `sec08_conclusion_submission.tex` | 1 sentence inside the limits paragraph |

### Final wording (rendered)

Abstract: "The qualitative claims survive a cross-jurisdiction
replication on the federal ComprasNet panel (Appendix H);
absolute discrimination levels are substantially lower than on
BEC, consistent with an institution-coupled calibration rather
than a universal cut-off."

Introduction: "We additionally test the central claims on a
second procurement panel. Appendix H re-runs the headline
replications on the federal ComprasNet platform for 2013-2019,
using a CADE-anchored cobidder set built independently of BEC.
The qualitative results survive: loser-side concentration is a
meaningful concept on the federal panel, the firm-level
classifier discriminates cobidders above chance, the continuous
loss-intensity score dominates the binary threshold, and the
structural boundary against direct CADE defendants is preserved.
The absolute AUC levels are substantially lower than on BEC, and
the federal IQR-derived threshold is not where the cobidder
concentration peaks. We position the federal numbers as a
deployment-realistic floor and as evidence that the underlying
construct generalises while its calibration constants do not."

Conclusion: "...a cross-jurisdiction replication on the federal
ComprasNet panel (Appendix H) recovers the qualitative results
but degrades the absolute discrimination levels, consistent with
the screen's calibration being institution-coupled rather than
universal."

### Build status

- `paper_submission_clean.pdf` 43 pages (was 42; +1 page from intro
  paragraph) -- compiled clean both passes.
- `online_appendix_submission_clean.pdf` 22 pages -- compiled clean.
- `\ref{app:comprasnet_submission}` resolves to "Appendix H" via
  `xr` package cross-reference between the two compiles.
- Minor gotcha: `\ref{}` for an appendix label already includes the
  word "Appendix~H", so wrapping it as `Appendix~\ref{...}` would
  render "Appendix Appendix H". Fixed.

### Pending (next session)

- AN-039 / AN-040 federal (still ~1 day if pursued).
- Consider committing the v20 branch to git.

---

## 2026-05-23 (continuation 5) -- D1 step 2 via RAIS + linkage v2

### Discovery (modo revisor)

User suggested using RAIS instead of downloading Receita Federal
Empresas base (1.25 GB). Initial blocker:
`paper4-thresholds/02_data/rais_bec_linked.parquet` lacks razão
social (only aggregated firm-level stats). Found
`paper4-thresholds/RAIS/parquet/harmonized/rais_vinculos_{2009..2017}.parquet`
(55 GB) with the unified schema including razao_social, cnpj_raiz,
cnpj_cei, ano, uf_arquivo.

Caveat: 2009-2014 have razao_social as 100% NULL. Only 2015-2017
populated. Acceptable -- firms continue across years, so any
CADE-adjudicated firm that operated in 2015-2017 will show.

Casa dos Dados mirror tested (Cloudflare 404 on direct .zip), then
RF NextCloud share (Empresas hosted but download token complex).
RAIS local won.

### RAIS enrichment process

Scripts:
- `scripts/67_rais_enrich.py` -- fuzzy lookup against RAIS 2015-2017
  on 15 CADE rows still unmatched after D1 step 1.
- `scripts/68_promote_rais_to_v2.py` -- manual review and promotion
  of 7 high-confidence matches.
- `scripts/69_linkage_v2.py` -- re-run linkage step skipping fuzzy
  enrichment (reads pre-curated `cnpjs_enriched.csv` v2).

7 firms promoted to v2:
- Tejofran (61288437) -- trens, SP, score 1.0
- Plasticos Santa Clara SP (13708382) -- sacos, SP, score 1.0
- LSV (96184858) -- sacos, SP, score 1.0
- Dimaci SP (05847630) -- medicamentos, SP, score 0.943
- Convida Alimentacao (48865828) -- merenda, SP, score 0.905
- Drogafonte (08778201) -- medicamentos PE/nacional, direct match
- Siemens Ltda (44013159) -- trens multi-UF, direct match

8 NOT promoted (false positives or absent):
- Frontal Group (ambiguous - many "Frontal" firms in different UFs)
- Astéria (zero RAIS match)
- Matrix Artefatos Plásticos (only false positives in fuzzy)
- Visaplas (Visaplas is the one that triggered the original FP fix)
- Rhamis (only generic "DISTRIBUIDORA FARMACEUTICA" matches)
- Delícias da Vovó SP (only non-SP matches at score 1.0)
- Ventana BA (UF mismatch with cartel SP)
- CAF MG (likely a different CAF firm, not CAF Brasil trens)

### Uplift v1 -> v2

| Metric | v1 | v2 | delta |
|---|---:|---:|---:|
| CADE rows with CNPJ | 45 | 52 | +7 |
| Raizes matched federal | 14 | 19 | +5 |
| Direct-defendant estabs | 19 | 27 | +8 |
| Anchored (tender, item) pairs | 20,213 | 32,148 | +59% |
| Cobidder firms | 3,019 | 4,164 | +38% |
| Always-loser cobidders | 122 | 222 | +82% |
| FL cobidders (tc >= 32) | 62 | 109 | +76% |

### AN re-runs against v2 sets

| AN | v1 | v2 | Notes |
|---|---|---|---|
| AN-004 binary AUC | 0.6644 | 0.6562 | slight drop with more diverse cobidders |
| AN-004 cont AUC | 0.7507 | 0.7542 | slight up |
| AN-004 DeLong p | 3.3e-8 | 4.0e-18 | 10 orders stronger |
| AN-006 BEC-style binary | 0.6005 | 0.6039 | +0.003 |
| AN-006 ultra-strict binary | 0.5069 | 0.5312 | +0.024 |
| AN-014 drop M2->M3 binary | 0.067 | 0.055 | smaller (better generalization) |
| AN-007 vs directs binary | 0.4649 | 0.4649 | identical (boundary preserved) |

Qualitative conclusions unchanged; evidence weight increases.

### Manuscript updates

- `online_appendix_submission_clean.tex`: 18 macros updated to v2
  values (raizes, cobidders, AUCs, holdouts, leakage drops).
- `sec_app07_comprasnet_submission.tex`: paragraph on D1 step 2
  rewritten -- replaces "we defer that pass" with the explicit
  list of 7 promoted firms + 8 NOT promoted (with reasons).
- Both PDFs rebuilt clean: 43 pages main, 22 pages online appendix.

### Files written this continuation

| File | Action |
|---|---|
| `scripts/67_rais_enrich.py` | created (~230 lines) |
| `scripts/68_promote_rais_to_v2.py` | created (~70 lines) |
| `scripts/69_linkage_v2.py` | created (~210 lines) |
| `data/processed_comprasnet/cade_link_v2/` | created with 4 parquet outputs + cnpjs_enriched.csv + cnpjs_rais_candidates.csv + summary.md |
| `online_appendix_submission_clean.tex` | 18 macros updated |
| `sec_app07_comprasnet_submission.tex` | linkage narrative paragraph rewritten |

### Pending (next session)

- Git commit of v20 branch.

---

## 2026-05-23 (continuation 8) -- REVERT: Appendix H removed from submission

After completing AN-039 + AN-040 federal, autor reviewed the
cross-jurisdiction evidence and concluded:

> "Os testes com ComprasNet estão muito ruins para o paper."

mr-frequent agreed: AUC drop 0.92 -> 0.66 is large enough that an
"deployment-realistic floor" defense is shaky against a tough JLEO
referee. AN-040 winner-vs-ref sign flip adds another attack vector.
Net expected R&R impact of Appendix H: roughly -3 to +2 pp,
referee-draw-dependent. Tighter to submit BEC-only and hold v20
as contingency for R&R if requested.

### Reverted

| File | Action |
|---|---|
| `sec_frontmatter_submission.tex` | Abstract sentence on ComprasNet removed |
| `sec01_introduction_submission.tex` | Paragraph on Appendix H removed |
| `sec08_conclusion_submission.tex` | Sentence on cross-jurisdiction removed |
| `online_appendix_submission_clean.tex` | Federal macros block (lines 48-174) and `\input{sec_app07_comprasnet_submission}` removed |

### Build state final (back to BEC-only)

- `paper_submission_clean.pdf` 42 pages (was 43 with intro paragraph).
- `online_appendix_submission_clean.pdf` 16 pages (was 24 with
  Appendix H + macros block).
- Both PDFs compile clean, zero errors.

### v20-comprasnet ARTIFACTS PRESERVED (contingency)

All v20 work remains intact on the `v20` branch, ready for R&R:

| Path | Status |
|---|---|
| `work/v20-comprasnet/scripts/an{001,004,004b,006,007,014,039,040}_*.R` | preserved |
| `work/v20-comprasnet/output/` | preserved |
| `work/v20-comprasnet/{README,LOG_SESSION}.md` | preserved |
| `work/v20-editor/submission_clean/sec_app07_comprasnet_submission.tex` | preserved (un-linked from master) |
| `data/processed_comprasnet/` | preserved (panel + linkage v1/v2/v3 + item_level_panel) |
| `scripts/{00,65,66,67,68,69,70,71,72,73}_*.py/R` | preserved |
| `STAGE_1C_CADE_COMPRASNET_LINKAGE_PLAN.md` | preserved |
| `COMPRASNET_PATH_TO_CONFIRMED.md` | preserved |

If R&R requests cross-jurisdiction validation, re-linking the
appendix is a one-line change in
`online_appendix_submission_clean.tex` plus restoring the
federal macros block.

---

## 2026-05-23 (continuation 7) -- AN-039 + AN-040 federal

Built `data/processed_comprasnet/item_level_panel.parquet`
(7,281,396 rows, 1 row per tender x item x year) from the 84 CGU
ItemLicitacao CSVs. Joined to participation panel for n_firms per
item. Ran AN-039 and AN-040 federal.

### AN-039 -- selection mechanism (PASSES)

| Metric | BEC | Federal |
|---|---:|---:|
| Non-treated mean log_price low band | 1.35 | 7.41 |
| Non-treated mean log_price top band | 6.93 | 8.46 |
| Delta low->high | 5.58 | 1.05 |
| Full-FE coef on cell_FL_share | +3.55 (SE 0.23) | +1.26 (SE 0.064) |
| p-value | < 10^-55 | < 10^-86 |

Direction and significance preserved; magnitude smaller in federal
(compressed price distribution + finer cell heterogeneity).

### AN-040 -- within-cell mechanism (DOES NOT REPLICATE, M1 leg only)

BEC uses winner_vs_ref = log(winner/ceiling). Federal Portal CGU
does not expose ceiling/reference price. We substitute
log(valor_item) and log(valor_item/quantidade).

| Metric | BEC | Federal raw | Federal unit |
|---|---:|---:|---:|
| log_price ~ losers (no n_firms) | -0.048 | +0.81 | +0.50 |
| + log_n_firms control | +0.008 (n.s.) | +0.54 | +0.56 |
| log_n_firms ~ losers (M1) | +0.51 | +0.67 | +0.67 |
| Sparse band (1-3) | +0.092 | +0.35 | -- |
| Dense band (11+) | -0.015 | +0.61 | -- |

The within-cell direction flips and the BEC bidder-count-band
finding (sparse positive -> dense negative) does not replicate.
The bidder-count inflation leg (M1) generalises with larger
magnitude federal. Interpretation: without a reference price, the
federal coefficient on `losers` within a cell conflates within-cell
selection (FL participates in expensive items inside a cell) with
within-cell mechanism (cover bidding deflates winner price relative
to ceiling). The two are observationally separable only when a
ceiling is available; BEC has one, federal does not.

### Scripts added

- `scripts/73_build_item_level_panel.py` -- item-level panel build.
- `work/v20-comprasnet/scripts/an039_selection.R` -- selection test.
- `work/v20-comprasnet/scripts/an040_mechanism.R` -- mechanism test
  with raw + unit-price + bidder-count band specifications.

### Manuscript updates

- 22 new macros for AN-039/AN-040 numbers.
- New Appendix H subsection H.4 "Selection and within-cell
  mechanism decompositions" with two paragraphs: AN-039 (passes)
  and AN-040 (does not replicate -- measurement gap, not
  substantive contradiction).
- "Survives" / "Does not survive" lists in H.5 updated with the
  new findings.
- PDFs rebuild clean: 43 pages main, 24 pages online appendix
  (was 22; +2 from the AN-039/AN-040 paragraphs).

---

## 2026-05-23 (continuation 6) -- D1 step 2-bis: RF Empresas + CADE PDF scrape

User asked to also pursue RF Empresas (1.25 GB) after RAIS recovered
7 firms; we found the official Nextcloud share endpoint
(arquivos.receitafederal.gov.br/index.php/s/YggdBLfdninEJX9 via
WebDAV PROPFIND). Downloaded 10 ZIPs from the 2026-05 snapshot.

### Scripts added

- `scripts/70_rf_enrich.py` -- DuckDB-native fuzzy lookup over the
  10 Empresas CSVs against the 8 firms still unmatched after RAIS.
- `scripts/71_promote_rf_to_v3.py` -- manual promotion of
  4 RF-confirmed firms + 1 CADE-acórdão-search confirmed firm.
- `scripts/72_linkage_v3.py` -- re-run linkage on v3 enriched set.

### Promoted to v3

- **Visaplas** 08505363 -- literal name match in RF.
- **Rhamis** 07524484 -- literal name match in RF.
- **CAF** 14689798 -- close but not exact ("CAF Indústria e Comércio
  Ltda" vs CADE "CAF Brasil Indústria e Comércio Ltda"); marked
  `rf_v3_manual_caution`.
- **Ventana** 05424351 -- BA per RAIS, multi-airport via Infraero;
  marked `rf_v3_manual_caution`.
- **Frontal Ind e Com de Móveis Hospitalares Ltda** 01140694 --
  identified via web search of CADE acórdão for case
  08012.009732/2008-01 (Sanguessuga / Mobile Health Units); one of
  the two Frontal Group firms.

### NOT promoted (insufficient evidence)

- Astéria (zero in RF Empresas; firm baixada before snapshot).
- Matrix Artefatos Plásticos (fuzzy matches are different firms;
  the 14 Operação Colludium ME firms all baixadas).
- Delícias da Vovó SP (~50 candidates in RF, no way to disambiguate
  without Estabelecimentos table).
- Second Frontal Group firm (candidate "Frontal Indústria e
  Comércio S/A" 43108273 is Botucatu/SP cabines de caminhão, not
  obviously UMS-related; left unmatched).

### Coverage v3

- v1 (BEC only): 45 / 65 = 69.2 per cent.
- v2 (BEC + RAIS): 52 / 65 = 80.0 per cent.
- **v3 (BEC + RAIS + RF + CADE PDF): 57 / 65 = 87.7 per cent.**

### Federal headline numbers UNCHANGED at v3

| Metric | v2 | v3 |
|---|---:|---:|
| Raízes matched federal | 19 | **19** |
| Direct estabs | 27 | 27 |
| Anchored tenders | 32,148 | 32,148 |
| Cobidders | 4,164 | 4,164 |
| FL cobidders | 109 | 109 |

The 5 firms added at RF and CADE-PDF steps have zero ComprasNet
federal participation. **Structural finding**: CADE prosecutes
predominantly sub-national cartels (state or municipal). Only
medicamentos genéricos NACIONAL and a subset of trens/metrôs SP
firms have federal footprint. Cobidder set saturates at the
BEC+RAIS step.

### Bug encountered + fixed

First v3 promotion script used cade_idx="33" for Frontal Group,
which actually belongs to Planan Group; this silently overwrote
Planan's CNPJ (37517158000143 -> 01140694000100). Caught by
manual verification: re-promoted with cade_idx="34" for Frontal
and restored Planan correctly.

### Manuscript updates

- `online_appendix_submission_clean.tex`: 2 new macros
  (`\valFedCadeEnrichedRF`, `\valFedCadeCoverage`); 2 updated
  (`\valFedCadeEnrichedTotal` 52->57).
- `sec_app07_comprasnet_submission.tex`: linkage paragraph rewritten
  to describe three-pass pipeline and add the structural finding
  (CADE prosecution scope is predominantly sub-national).
- Both PDFs rebuild clean: 43 pages main, 22 pages online appendix.
