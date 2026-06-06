# 99 — COMPRASNET EXTENSION EXECUTION PLAN
**Date:** 2026-06-05 · **Author:** Mr. Frequent Losers · **Status:** PLAN (awaiting GO)
**Objective:** convert the paper's biggest weakness (transferability asserted on one platform)
into its biggest strength by running the FULL audit protocol on a second, independent platform
(ComprasNet federal, 2009–2019) and adding a comparative cross-platform section. Directly
answers hostile-review M4/F2 (framework not demonstrated) and reinforces M1 (stakes).
**Either empirical outcome strengthens the paper:** deflation replicates → the portable
principle generalizes; residual survives federally → a positive result + institutional
explanation of the difference. Expected effect: P(desk) 0.30–0.40 → ~0.20; P(R&R | refereed)
→ 0.55–0.65.

---

## 0. Verified asset base (inventoried 2026-06-05 — NOT assumptions)

| Asset | Location | State |
|---|---|---|
| Federal firm_tender_map | `data/processed_comprasnet/firm_tender_map.parquet` | **51.0M rows, schema IDENTICAL to BEC** (`códigofornecedor/numerodaoc/códigoitem/n_bids/won` + `panel`) |
| Federal loss stats / FREQ | `firm_loss_stats.parquet`, `FREQ_PARTICIP_rebuilt.parquet` | BEC-mirror schema; FL threshold federal = 32 (IQR rule re-derived) |
| Federal bid level | `bid_level_full.parquet` (+`_year`) | 212 MB; bid-tier feasibility gate below |
| Item panel (prices) | `item_level_panel.parquet` | price-scope replication possible |
| CADE federal linkage v3 | `cade_link_v3/{direct_defendants_federal, cobidders_federal, anchored_tenders_federal}.parquet`, `cnpjs_enriched.csv` | built 05-23; anti-FP rule (fuzzy 0.92 + CNPJ-uniqueness); ~3,019 cobidders v1 (15× BEC) |
| Panel builder / linkage scripts | `scripts/00_build_eventlevel_comprasnet.py`, `scripts/65_cade_comprasnet_linkage.py` | reproducible source of the mirror |
| Calibration precedent | `work/v20-comprasnet/output/CONSOLIDATED_RESULTS.md` | v20 AN pipeline reproduced BEC paper numbers to FP precision before federal runs — same validation pattern reused here |
| Prior federal ANs | an001/004/004b/007 done; an006/014 were pending | superseded by this plan's full battery |

## 1. Phase 0 — Readiness gates (0.5 day) — ALL must pass before any adaptation

G1. **Key conventions**: verify federal `numerodaoc` encodes year at chars 12–15 and a
buyer/UASG prefix at chars 1–11 (BEC convention assumed by cells, timing, and the canonical
builder). If not, write the mapping in `source_config` (Phase 1) — never patch scripts inline.
G2. **`panel` column semantics** (pregão vs other modalities; coverage by year 2009–2019);
document federal modality landscape (no Convite federally — §comparative must address).
G3. **Linkage v3 audit**: defendant count, distinct CADE cases linked, overlap of federal
cases with the 12 BEC cases (CRITICAL for the "independent setting" claim — if the case
portfolios overlap heavily, independence is partial and must be stated); cobidder definition
in `cobidders_federal` vs our canonical broad rule (likely rebuild from scratch via the
canonical builder rather than trust v1 — DECISION D-i below).
G4. **Bid-tier feasibility**: does `bid_level_full` carry usable bid VALUES (not just
participation) for Imhof moments? → decides Tier-2 scope.
G5. **Always-loser universe sanity**: N AL federal, N FL32, heavy-tail check (an001 already
suggests yes: p75 tc 20 vs 8 BEC).
**Gate output:** `outputs/comprasnet/diagnostics/phase0_readiness.csv`. Any FAIL → stop, fix
upstream (possibly re-run linkage as v4 under canonical rules), re-gate.

## 2. Phase 1 — Source-abstraction layer + script adaptation (1.5–2 days)

**Architecture rule: one config, zero forked logic.** New `scripts/utils/source_config.R`:
`get_source_config(source = c("bec","comprasnet"))` returning paths (DATA dir, crossmatch/
defendant objects, cache dir, OUT dir), constants (FL_CUT 14 vs 32; CONS_DATE; RANK_CUT),
and key-extraction lambdas (year(), buyer(), item_group()). Every audit script gains
`--source=` via `commandArgs`; **default `bec` (zero behavior change for the existing
pipeline — BEC outputs must be byte-identical after refactor: regression gate R1).**
Output isolation: `work/v22-editor/outputs/comprasnet/{targets,tables,diagnostics,cache,logs}/`.

| Script | Adaptation | Notes |
|---|---|---|
| `00_build_canonical_validation_targets.R` | config paths + defendant source = cade_link_v3 (or v4) | emits federal 651-analog; assertions T1–T10 unchanged; FL32 as score column |
| `01_label_funnel_reconciliation.R` | config; drop BEC-static-file comparison block for federal | funnel Table A-fed |
| `02_opportunity_adjusted_validation.R` (+`02b`) | config; cells COARSE/MEDIUM/STRICT identical construction | the core deflation test |
| `03_timing` / `04_case_dominance` | config; conservative window re-derived from federal case judgment dates | LOCO over federal cases |
| `05`/`06` profile+robustness | config; FL32 stratum | negative controls = the decisive battery, mandatory |
| `07–09` bid benchmark | **Tier 2 — conditional on G4** | if bids unusable: document as platform difference (award-only audit federally — itself informative) |
| `10` cost-recall frontier | Tier 2 (needs bid rows for denominators) | if G4 fails: firm/tender-item denominators only |
| `11` survival | config | optional Tier 3 |
| `12`/`12b` audit armor | config | **mandatory** — leakage tiers, falsifiability, power, label-frozen timing federal |
| `55` adversarial | skip (Tier 3) | gaming exercise is institutional, not per-platform |

**Run order (compute ~0.5 day):** Phase0 → 00 → 01 → 02(+02b) → {03,04} → {05,06} → 12/12b
→ [Tier 2: 07→08→09→10] → consolidation. Sequential (RAM caps); federal ftm is 3× BEC rows —
expect 02 to be the long pole (DuckDB self-join on 51M; budget 14GB/12 threads, spill on).

## 3. Phase 2 — Verification gates (0.5 day)

R1. BEC regression: re-run `00`+`02` with `--source=bec` post-refactor; diff key CSVs vs
current outputs (must be identical).
R2. Federal assertions T1–T10 pass; concordance table federal.
R3. `NEW_NUMBERS_MAP_COMPRASNET.md` — authoritative federal numbers + side-by-side delta
table vs BEC.
R4. Mini hostile read (1 agent): the federal audit's own leakage/falsifiability/power story.

## 4. Phase 3 — Comparative section + manuscript integration (1–1.5 days)

- **New §"The Audit on a Second Platform" (~3 pp main)**, placed after current §4 (becomes
  §5; current §5–§7 shift) OR as §4.5 — DECISION D-iii. Content: federal institutional
  contrast (single national platform, pregão-dominant, UASG buyers, FL cut 32); the
  side-by-side audit verdict table (raw AUC / label-blind / within-stratum / power-bounded
  residual / matched-perm p / label-frozen timing / case concentration / negative controls);
  interpretation under whichever outcome the data deliver.
- **One main table** (the side-by-side) + full federal battery in a new Appendix (letter G)
  — respect the float budget: main stays ≤7 tables only if Darcio accepts +1; otherwise the
  side-by-side REPLACES a demotable BEC-only table (candidate: none obvious — likely accept
  7 and argue necessity, or fold into Table 4 as panel B). DECISION D-iii.
- **Claims upgrade**: abstract/intro/conclusion C2 → "audit protocol demonstrated on two
  platforms"; the portable principle gains its first replication; cover letter updated.
- **Length compensation**: demote BEC-only App D profile detail + App F adaptation detail to
  the online supplement (−2–3 pp) to absorb the new section.
- Resurrect/replace the orphaned `sec_app07_comprasnet` with the new federal appendix
  (it already exists as a file — gut and rebuild under the canonical framing).

## 5. Phase 4 — Package re-validation (0.5 day)

Rebuild ×4; scans (target-consistency/claims/hygiene/PDF-text) extended with federal terms;
visual check of new section; update docs (NEW_NUMBERS_MAP, 97-series), site (changelog
v23/“two-platform” landing), commit/push/deploy.

## 6. Decisions required from Darcio BEFORE execution

- **D-i — Linkage trust**: rebuild federal cobidders from scratch via the canonical builder
  over `direct_defendants_federal` (recommended — same non-circularity guarantees as BEC) vs
  reuse `cobidders_federal` v3 as-is. *Recommendation: rebuild; reuse v3 only as set-comparison.*
- **D-ii — Tier 2 scope**: include bid benchmark + frontier federally (adds ~1 day + G4 risk)
  or ship award-layer audit only (the deflation core needs only Tier 1). *Recommendation:
  decide AFTER G4; default Tier 1 only — the comparative table does not require the bid tier.*
- **D-iii — Section placement & float budget** (above).
- **D-iv — Case-overlap framing**: if G3 shows heavy CADE-case overlap with BEC, the honest
  claim is "second platform, partially overlapping legal anchors" — acceptable but must be
  decided knowingly.

## 7. Effort & calendar

| Phase | Effort |
|---|---|
| 0 readiness gates | 0.5 d |
| 1 config + 11-script adaptation | 1.5–2 d |
| runs + 2 verification | 1 d |
| 3 comparative section + integration | 1–1.5 d |
| 4 re-validation + deploy | 0.5 d |
| **Total** | **4.5–5.5 working days** (~1.5 semanas calendário com folga) |

## 8. Risks

- **R-a (medium)**: federal key conventions differ → absorbed by config lambdas (G1 gates it).
- **R-b (medium)**: CADE federal linkage quality (fuzzy matches) → canonical rebuild + anti-FP
  rule + exact-CNPJ-only sensitivity, mirroring BEC discipline.
- **R-c (low/medium)**: case overlap with BEC undermines "independent" claim → D-iv framing.
- **R-d (low)**: bid values unusable federally → Tier 2 dropped; documented as an
  observability difference between platforms (on-thesis).
- **R-e (low)**: 51M-row joins exceed RAM → DuckDB out-of-core + per-year chunking fallback.
- **R-f (strategic)**: federal results could be *less* deflationary in a messy way (e.g.
  marginal residual that is neither null nor robust) → report honestly; the comparative
  framing accommodates ("reach varies by institutional environment; the audit is what
  transfers").

---

## POST-SCRIPT (2026-06-06) — bid-microdata sweep upgrades G4's Tier-2 verdict

G4's **ABSENT** verdict (`phase0_readiness.csv`) was *correct for the audited sources*:
Portal CGU `ParticipantesLicitacao.csv` has zero value fields, and the legacy / new
open-data APIs expose winner / homologated records only (re-verified dead for lances on
2026-06-06; the new `dadosabertos` API never had a lances endpoint per Wayback). The
G4 conclusion "no usable bid VALUES for Imhof moments from the audited public sources"
stands as written.

**What the sweep found that G4 had not reached** (URLs verified live 2026-06-06):

1. **SEGES bulk lances dump** — `https://repositorio.dados.gov.br/seges/lances_pregao/`
   (`tbl_lances.csv.gz` 751 MB / 2.50M lances + `tbl_lances_encerrados.csv.gz` 366 MB /
   1.34M; true bid grain: `lanValor`, `lanData` timestamps, CNPJ unmasked,
   `numprp`/`coduasg` join keys; coverage 2010–2021; open data, no captcha). Downloaded
   to `~/projetos/comprasnet/data/raw/seges_lances/`. **BUT volume ≈ 5% of the ComprasNet
   universe → SELECTED extract**, characterization in progress
   (`outputs/comprasnet/diagnostics/seges_lances_characterization.md` when ready).
2. **`FornecedorResultado.asp` route** (no captcha) — final per-item proposals of all
   bidders incl. losers, with CNPJ; 2009–2019; ~2–4 weeks polite scrape seeded by our
   (UASG, numprp) keys; no timestamps / no intermediate bids.
3. **`AtaEletronico.asp`** full chronological lance map — captcha-gated, no bulk path;
   `andremenegatti/comprasnet_captcha_breaker` as a parser fallback.

**Tier-2 feasibility upgrade:** from **ABSENT** → **SELECTED-SUBSAMPLE PENDING
CHARACTERIZATION**. The full deflation core (Tier 1) still needs no bid tier, so D-ii's
default ("Tier 1 only") is unchanged for THIS revision. The change is the door, not the
plan: an Imhof federal benchmark is no longer structurally impossible — it is gated on
characterizing the SEGES ~5% extract (is it representative? which years/UASGs/categories?)
before any moment-based screen can be claimed to transfer. See
`COMPRASNET_PATH_TO_CONFIRMED.md` §8.7 for the full ranked findings and corrections.

**Manuscript-language audit (FLAG ONLY — manuscript NOT edited; lead decides):**

Grep of `submission_clean/*.tex` for "bid microdata" / "no recoverable bid" returns three
load-bearing sentences whose strength the SEGES discovery puts in question:

- `sec_comparative_submission.tex` L49–52:
  *"The public federal data expose participation and the winner flag, but no bid
  microdata---there is no federal analogue to the BEC `LANCES` bid ladder."*
- `sec_comparative_submission.tex` L250–252:
  *"...the full deflation battery re-run on a system with no bid microdata is itself the
  portability result..."*
- `sec01_introduction_submission.tex` L204–207:
  *"...the federal ComprasNet system..., with partially overlapping CADE anchors and no
  bid microdata, returns the same deflationary verdict..."*

**Verdict on survival:** these sentences DO survive on their *intended* meaning, which is
about the **public bulk release** the audit consumed (Portal CGU participants file) — that
release genuinely carries no bid values. But the unqualified absolute "no federal analogue
to the BEC LANCES bid ladder" and bare "no bid microdata" are now **too strong as written**,
because the SEGES dump is exactly a (partial) federal LANCES analogue. A hostile referee who
knows the SEGES repo could call this an overclaim.

**Suggested honest rewording (for the lead's decision, not applied):**
- L49–52 → "The public *bulk* federal release we audit exposes participation and the winner
  flag but no bid values; a separate SEGES export carries true lance microdata for a
  selected ~5% slice of the universe, not a population panel, so it cannot anchor a
  population-level bid-layer screen here."
- L250–252 → "...re-run on a *release* with no bid values..." (swap "system" → "release").
- L204–207 → "...with partially overlapping CADE anchors and no bid values in the public
  bulk release..." (replace "no bid microdata").

This is a precision fix, not a retraction — the comparative section's logic (cheap
award-layer audit is the screen one *can* build on the public bulk release) is intact.

### Post-script resolution (2026-06-06, post-characterization)
The SEGES `lances_pregao` dump was characterized (`outputs/comprasnet/diagnostics/seges_lances_characterization.md`):
it is the **SP+RJ MUNICIPAL slice** of the ComprasNet family (UGs 925xxx/986xxx; 22,104 pregões; 3.84M lances
2010–2021), with **zero overlap** with the federal SIASG universe (0/864 UASGs, 0/22,100 pregões, 0/32,148
anchored tender-items). **G4's ABSENT verdict therefore STANDS for the federal universe**, and the manuscript
sentences "no bid microdata / no federal analogue to the BEC LANCES ladder" are ACCURATE as written —
the phrasing flag raised in the earlier post-script is RESOLVED-MOOT; no manuscript edit needed.
What the sweep actually yielded:
1. A candidate THIRD SETTING for future work: municipal SP/RJ lance microdata where 15/27 CADE defendants,
   2,534/4,164 federal cobidders and 60/109 FL-federal cobidders also bid (CNPJ bridge only) — a bid-ladder
   environment for an Imhof-style third-jurisdiction leg. R&R ammunition / Paper-B-adjacent. NOT this revision.
2. Federal final-proposals route (FornecedorResultado.asp, no captcha, all bidders incl. losers w/ CNPJ,
   2009-2019, ~2-4 wks) — proposal-dispersion proxies, not the ladder.
3. Email leads: Szerman (LSE thesis bids 2001-2010+), Mourão (IPEA 2001-2015), World Bank PRWP 8828 team
   (112M item obs w/ bids 2015-2017, ministry-provided).
