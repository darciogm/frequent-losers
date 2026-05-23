# Path to Confirmed via ComprasNet federal replication

**Status:** planning document. Drafted 2026-05-22 in the wake of the
H1–H8 audit-completion exercise that brought 7 of 8 hypotheses to
**Partial (strongly supported)** but found every one of them bounded
below 🟢 (Confirmed) by the same constraint — *all evidence shares the
BEC × CADE data lake*. **Updated 2026-05-22 (later)** with concrete
acquisition estimates from a live smoke test of the
`bulk_acquire_comprasnet.py` pipeline (in
[github.com/darciogm/comprasnet](https://github.com/darciogm/comprasnet)).

This memo lays out the natural cross-validation target (ComprasNet
federal), the analyses that would replicate, the data-acquisition
roadmap, and an honest probability assessment of moving 1–3 hypotheses
to 🟢 within the JLEO R&R window.

## 0. Acquisition pipeline status (added 2026-05-22)

The Compras.gov.br open-data API was probed and characterized:

- **Old domain `compras.dados.gov.br`**: deprecated (404 on all paths).
- **New domain `dadosabertos.compras.gov.br`**: live, OpenAPI 3.1 spec
  at `/v3/api-docs`, no authentication needed for the read-only legacy
  endpoints.
- **Three endpoints used for paper-3 replication**:
  - `/modulo-legado/1_consultarLicitacao` — all procurement events by
    `data_publicacao_inicial/final`.
  - `/modulo-legado/3_consultarPregoes` — Pregão events by
    `dt_data_edital_inicial/final`.
  - `/modulo-legado/4_consultarItensPregoes` — Pregão items by
    `dt_hom_inicial/final` (homologation date).
- **Page-size constraint**: `[10, 500]`. Use 500 for bulk.

**Smoke-test result (1 week of 2019 data):**

| Endpoint | Rows | Pages (size 500) | Time |
|---|---:|---:|---:|
| Licitação | 273 | 1 | 0.5s |
| Pregão | 375 | 1 | 0.4s |
| Item_pregão | 5,704 | 12 | 8.2s |
| **Total** | **6,352** | — | **~12s wall, 0.7 MiB parquet** |

**Extrapolation for 2014–2019 (6 years, 312 weeks):**
- Total acquisition time: **~60 minutes wall time** (not weeks).
- Total parquet size: **~220 MiB** compressed.
- Total rows: ~1 M licitações + pregões + ~2 M item_pregão.

The pipeline (`bulk_acquire_comprasnet.py`) is production-ready: date-
windowed paginated acquisition, checkpoint-based resumability, DuckDB
consolidation to parquet, telemetry per CLAUDE.md, exponential-backoff
retries on transient 429/5xx.

**Federal modality composition (1 week of 2019 sample):** 272 PREGÃO +
1 CONCORRÊNCIA, **zero CONVITE**. ComprasNet federal is essentially
Pregão-only. Implication: the cross-modality test (AN-016 / D2 modal
AUC) cannot be replicated on the federal panel — the loser-side
framework can be tested on Pregão-only, which addresses the SAME-DGP
concern but not the cross-modality scope discipline. For modality
replication, an additional state-level panel (e.g., Bahia or Minas
Gerais e-procurement) would be needed.

---

## 1. The Confirmed bar by hypothesis

Replicating "frequent-loser concentrates cobidder risk" on a non-BEC
panel addresses the **same-DGP** and **CADE-selection-bias** obstacles
that hit H1, H3, H4, H6, H7, H8 identically. Each hypothesis would
graduate to 🟢 if the corresponding within-data result transfers:

| H | BEC-data finding (within-data ≥ Partial-strong) | Cross-data test for 🟢 |
|---|---|---|
| H1 | FL14 AUC 0.924 vs cobidders | Same AUC on ComprasNet cobidder set |
| H3 | Sham permutation rejects at 32σ | Same sham permutation rejects |
| H4 | Strict ex ante AUC 0.79–0.85 | Same timing discipline survives |
| H6 | Imhof + FL Δ +0.096, p=10⁻²⁶ | Same DeLong increment on ComprasNet |
| H7 | Sequential beats joint in temporal holdout | Same architecture trade-off |
| H8 | Sign reversal +0.064 → −0.097 under ATT | Same sign-flip pattern in another panel |

H2 (direct-defendant null) is already Confirmed — it is a structural
claim (loser-side rank cannot rank winners) that does not require
cross-data replication.

H5 (cobidder profile distinct) has its own boundary: the descriptive
distinctness is largely volume-confounded within FL stratum, so even
ComprasNet replication would not promote H5 without additional causal
identification of the bid-level signature.

**Realistic target:** ComprasNet replication promotes 4–6 hypotheses
to 🟢; H5 stays at Partial (strongly supported); H8 graduation
depends on whether the paper treats sign-reversal as causal (which it
currently does not — H8 is framed as scope information).

## 2. ComprasNet federal — institutional fit

ComprasNet is the Brazilian federal procurement platform managed by
the Ministério da Gestão e da Inovação em Serviços Públicos.
Comparable on the key dimensions:

| Dimension | BEC-SP | ComprasNet |
|---|---|---|
| Panel size | 4.5M tender-items | ~6M tender-items |
| Period | 2009–2019 | 2008–present, more granular post-2014 |
| Cartel anchor | CADE (state + federal) | CADE (federal-direct) |
| Modalities | Convite, Pregão | Pregão, RDC, Concorrência |
| Bid microdata | Recoverable via LANCES | Recoverable via dataset.ufmg.br/comprasnet or direct portal |
| Award records | Item × OC × firm | Item × UASG × firm |
| Legal frame | Lei 8.666/93 + Lei 10.520/02 | Same federal frame |

**Why ComprasNet is the right target:**

- *Same legal system, different operational implementation* — the
  federal procurement infrastructure shares the legal predicates
  (Convite minimum-bidder rule, Pregão e-auction format, antitrust
  jurisdiction at CADE) but uses different software (ComprasNet vs
  BEC), different recording conventions, and different administrative
  procurer pool (federal ministries + autarquias vs SP state agencies
  + PBUs). This is the cleanest non-BEC replication setting.
- *CADE adjudication shared* — the cartel-anchor authority is the
  same (Conselho Administrativo de Defesa Econômica), so the cobidder
  construction logic transfers without redefinition. The selection
  bias on which cases CADE chooses to adjudicate is preserved across
  the two panels, but the ComprasNet test still rules out
  BEC-specific data artifacts.
- *Imhof seven-feature pipeline portable* — the bid-distribution
  features can be computed from ComprasNet LANCES with the same code,
  so the H6 DeLong incremental test transfers directly.

## 3. Data acquisition roadmap

**Stage 1 — public award data (week 1–2)**

- *Source*: Portal de Compras do Governo Federal,
  `comprasgovernamentais.gov.br/transparencia` / Painel de Compras /
  Dados Abertos.
- *Granularity*: tender (UASG + numero do processo), item, firm
  (CNPJ), winner indicator, contract value, procurement modality.
- *Volume*: ~6M tender-items × 11 years ≈ 60M rows pre-clean; post-
  filter to procurement events with > 1 bidder ≈ 30M rows.
- *Time*: 2 weeks (acquisition + dedup + canonical CNPJ).

**Stage 2 — bid microdata (week 3–6)**

- *Source*: ComprasNet LANCES export via Portal SISG or direct API
  scrape. Some bid-level data is only available retroactively for
  specific UASGs.
- *Granularity*: bid value, bid rank, timing of bid submission, firm
  identity.
- *Risk*: bid microdata coverage may be incomplete pre-2014; the
  Imhof pipeline can only be computed where bid-level coverage exists.
- *Time*: 4 weeks (acquisition + cleaning + matching).

**Stage 3 — CADE cobidder construction (week 7)**

- *Source*: existing `cade_carteis_licitacoes_2009_2019.csv` (already
  used in BEC); filter to cases adjudicated against federal
  procurement; identify direct defendants and adjudication-anchored
  cobidders by joining with ComprasNet participants.
- *Expected output*: federal direct-defendant set + federal-anchored
  cobidder set, comparable in size to the BEC counterparts (47 / 193).
- *Time*: 1 week.

**Stage 4 — replication runs (week 8–10)**

- *Adapt existing scripts*: `02_analysis.R`, `12_build_item_value.R`,
  `25_sham_fl_permutation.R`, `27_strict_prospective_holdout.R`,
  `31_imhof_full_pipeline.R`, `33_auc_direct_cade.R`,
  `34_horse_race_fl_continuous.R`, `36_gate_d1_harmonized.R`,
  `37_gate_d2_modal_auc.R`, `39_gate_d4_cade_winner_heavy.R`,
  `40_leakage_audit_d3.R`, `42_operational_metrics.R`,
  `43_precision_at_k_audit.R`, `49_imhof_incremental_value.R`,
  `59_sign_reversal_decomp.R`.
- *Total adapt time*: 3 weeks if scripts parametrize over panel
  (BEC vs ComprasNet) cleanly; longer if BEC-specific logic is hard-
  coded.

**Stage 5 — manuscript update + R&R submission (week 11–12)**

- Add a "Cross-jurisdiction replication" appendix or §6.5.
- Update findings/index.md confidence tags from 🟡 to 🟢 for
  hypotheses that survive the ComprasNet replication.
- Update H1/H3/H4/H6/H7 hypothesis pages with "Confirmed" status.

**Total estimated time:** 12 weeks (3 months) with one full-time
researcher.

## 4. Cost-of-effort vs return assessment

**Cost:** ~3 months of researcher time + ComprasNet data-storage
overhead (~50 GB).

**Return:**

- *If replication succeeds*: 4–6 hypotheses move from "Partial
  (strongly supported)" to "Confirmed". The paper graduates from a
  single-jurisdiction study to a cross-jurisdiction one — much
  stronger contribution to the JLEO bar.
- *If replication partially fails*: H1, H3, H4 likely survive (the
  pattern is institutionally generic); H6, H7 may show different
  cost-of-evidence trade-offs (which is itself a finding); H8 sign
  reversal might differ (also a finding).
- *If replication mostly fails*: substantive update needed; would
  weaken the paper's external-validity claims rather than strengthen
  them. The risk is *informative*.

**Recommendation:** ComprasNet replication is the highest-value
follow-up after the JLEO submission. Recommend including a
**conditional commitment to replicate** in the cover letter, framed as
"we plan to extend the empirical strategy to ComprasNet federal in the
R&R revision if invited"; this signals openness to cross-validation
without delaying the submission timeline.

## 5. Adjacent / alternative targets (lower priority)

- *São Paulo municipal procurement*: smaller panel, less standardized
  recording.
- *Outro estado* (Bahia BEC-like or RJ): structural similarity to
  BEC-SP; partial cross-validation only.
- *Switzerland (Imhof's original data)*: would replicate H6
  specifically (Imhof feature pipeline); harder data access.
- *Italy (Conley-Decarolis)*: different cartel-detection regime;
  partial relevance.
- *Cross-country (e.g., OECD MAPS)*: out of scope for paper 3.

## 6. Action items if pursuit authorized

1. **Submit JLEO version first** (work/v18-editor/submission_clean/) —
   already at "Partial (strongly supported)" level for 7 of 8
   hypotheses + Confirmed for H2.
2. **Draft conditional R&R commitment** for cover letter (1 paragraph).
3. **Set up ComprasNet data pipeline** during the 6–12 week JLEO
   review window. If R&R arrives, replication results are ready.
4. **Estimate budget**: data-storage overhead is minimal; researcher
   time can be a small TA or RA project at Insper.

## 7. Open questions

- ~~Does the existing `scripts/00_build_bidlevel.py` parametrize over
  data source, or is BEC-specific? Audit needed.~~ **Audited
  2026-05-22 (mr-frequent, modo revisor): NO. BEC-specific in 7
  dimensions** — hardcoded absolute path to `bec-procurement/`
  (L40), single-file `.dta` reader (L43, L64-92), Portuguese BEC
  column schema in `COLS_NEEDED` (L45-53), BEC-specific "OC"
  collapse semantics (L122-125), no CLI / no env-var / no config
  injection point (entire `main()`), no `panel` column tagged on
  outputs, `winner` recoded in two places (L98 + L119) so any
  schema rename would need to be touched in both. The script also
  violates the CLAUDE.md `DuckDB-default-for-parquet` rule: it
  materializes the full 40M-row LANCES into a single pandas
  DataFrame via `pd.concat`, then does pandas `groupby` — RSS
  bomb risk on any growing panel. **Recommendation: do NOT
  parametrize the existing script. Write a sibling
  `00_build_eventlevel_comprasnet.py` that reads the three parquets
  from `bulk_acquire_comprasnet.py`, renames to a canonical
  vocabulary (`firm_id`, `tender_id`, `item_id`, `won`,
  `closing_date`, `modality`), adds `panel='comprasnet'`, and emits
  five outputs matching the BEC schema in
  `data/processed_comprasnet/`. Estimate: 1 engineering-day,
  DuckDB-native, executable in parallel with download completion.**
  Important constraint inherited from the API surface itself:
  the script can only produce a *participation-level*
  `bid_level_full` (one row per firm × item participation), NOT
  a literal bid-level table with one row per lance — the open API
  does not expose bid microdata. This bounds which hypotheses
  replicate (see below).
- Does CADE publish federal-procurement-specific cobidder mappings,
  or do we need to construct them from scratch? **Likely the latter:
  CADE adjudication records are case-by-case PDFs (acórdãos +
  pareceres); we need to extract defendant CNPJs case-by-case from
  the existing `cade_carteis_licitacoes_2009_2019.csv`, filter to
  cases targeting federal procurement (UASG-coded), and join to the
  ComprasNet participant set to construct the cobidder mapping. The
  current 47-direct-defendant / 193-cobidder split is BEC-state.
  Federal counterparts may be smaller; CADE prosecutes more state
  than federal cartels in our sample.**
- Bid microdata coverage post-2019 on ComprasNet: improving or
  declining? **Out-of-scope for this acquisition window.** The
  current bulk_acquire range matches BEC 2009-2019, ending in 2019.
  Post-2019 coverage matters only if we extend the panel — which
  the paper3 design does not require. Flag for paper-A spinoff or
  a longer-horizon follow-up.

## 8. Hypothesis-replication ceiling under the bounded acquisition
   (revised 2026-05-22 second pass, mr-frequent audit)

**Two consecutive audits in the same session. The first one
underestimated viability because it only looked at the open-data API
(`dadosabertos.compras.gov.br`); the second one found a better
source.**

### 8.1 First pass (API endpoints — superseded but instructive)

The `bulk_acquire_comprasnet.py` script consumes three open-data
endpoints (`licitacao`, `pregao`, `item_pregao`). Schema inspection
showed:

- `item_pregao` exposes one row per item with `fornecedorVencedor`
  (winner) — **NULL in 100% of the jan/2019 sample (0/5704 rows)**
  and no list of participants.
- 77 endpoints across `/v3/api-docs` searched for `lance`, `proposta`,
  `participante`, `fornecedor` — **none** return per-item participant
  lists.

The API is unsuitable for FL construction. Keep the bulk acquisition
running for auxiliary metadata (tender descriptions, dates, UASG
names), not for participation data.

### 8.2 Second pass (Portal da Transparência CGU bulk dumps — viable)

After the API gap was identified, web search located the right
source: **Portal da Transparência publishes monthly bulk ZIPs at**

```
https://dadosabertos-download.cgu.gov.br/PortalDaTransparencia/saida/licitacoes/{YYYYMM}_Licitacoes.zip
```

Each ZIP contains four CSVs. The decisive one is
`{YYYYMM}_ParticipantesLicitação.csv`, which holds **one row per
(firm × item × tender) participation** with these columns:

| Column | BEC equivalent | Role |
|---|---|---|
| Número Licitação | numerodaoc | tender ID |
| Código UG | códigounidadecompradora | procurement unit (UASG) |
| Código Modalidade Compra | (po_phase_code analog) | modality code |
| Modalidade Compra | (po_phase_code label) | modality label |
| Código Item Compra | códigoitem | item ID |
| **Código Participante** | **códigofornecedor** | **CNPJ 14-digit** |
| Nome Participante | (firm name) | string |
| **Flag Vencedor** | **flagvencedor** | **"SIM" / "NÃO"** |

Validated on jan/2019 (downloaded 6.27 MB ZIP, extracted 85 MB CSV):
- **336,521 participation rows** in one month
- 15,207 distinct firms
- 736 distinct tenders
- 57,755 winners (17.2%), 278,766 losers (82.8%) — clean SIM/NÃO split
- Sibling files `Licitação.csv` (event-level, with `Valor Licitação`),
  `ItemLicitação.csv` (item-level, with `Valor Item` and
  `Código Vencedor`), `EmpenhosRelacionados.csv` (post-award spending)

### 8.3 Modality scope discipline

Validated on jan/2019:

| Modality (code) | Participations | Winner rate |
|---|---:|---:|
| Pregão SRP (9999) | 291,841 | 14.7% |
| Pregão (5) | 26,178 | 12.8% |
| Dispensa (6) | 12,549 | 45.0% |
| Inexigibilidade (7) | 5,886 | 100% |
| Tomada de Preços (2) | 46 | 100% |
| Concorrência (3) | 10 | 100% |
| Concurso (20) | 6 | 100% |
| **Convite (1)** | **5** | **100%** |

Two findings:

1. **Federal Convite is effectively extinct.** Five participations in
   one month nationwide. The Convite minimum-bidder rule cannot be
   tested in federal data. **AN-016 / D2 modal-AUC reframe must be
   presented as a BEC-only test in the manuscript.** Cross-modality
   replication is structurally unavailable on the federal panel
   regardless of source.
2. **Useful FL scope = Pregão (5) + Pregão SRP (9999) only.**
   Inexigibilidade/TP/Concorrência/Convite are coded as 100%
   winners in the participants table (no real competition tracking
   for those modalities) — they cannot construct loser sets.
   SRP introduces a new sub-question (multi-winner per item;
   different price-formation dynamics) that doesn't exist in BEC.

### 8.4 Coverage

CGU bulk dumps start **2013-01-01**. The paper3 BEC panel is
2009-2019. **Federal cross-validation is restricted to the 7-year
overlap 2013-2019.** Pre-2013 federal data would require institutional
FOIA to MGI/SLTI — out of scope.

### 8.5 Revised hypothesis-replication matrix

| H | Within-BEC finding | Replicable on Portal Transp. (Pregão + SRP, 2013-2019)? |
|---|---|---|
| H1 | FL14 AUC 0.924 vs cobidders | **✅ Yes** — needs (firm, item, won), all present |
| H2 | Structural null on direct defendants | Already 🟢 |
| H3 | Sham permutation rejects at 32σ | **✅ Yes** — permutation works on participation patterns, no lance values needed |
| H4 | Strict ex ante AUC 0.79–0.85 | **✅ Yes** — timing discipline works |
| H5 | Cobidder profile distinct (volume-confounded) | Not promotable (within-data limit) |
| H6 | Imhof + FL Δ +0.096, p=10⁻²⁶ | **❌ No** — Imhof seven features need lance value distributions; participants CSV has no bid values |
| H7 | Sequential beats joint in temporal holdout | **✅ Yes** — architecture trade-off testable |
| H8 | Sign reversal +0.064 → −0.097 | **🟡 Partial** — `Valor Item` is in ItemLicitação.csv (price-side OK); bid-distribution channel still missing |
| AN-016 / D2 cross-modality | Convite vs Pregão AUC −0.136 (loser-side asymmetry) | **❌ No** — federal Convite extinct (5/month) |

**Realistic graduation under Portal-da-Transparência-only acquisition:
5 hypotheses promote to 🟢 (H1, H2, H3, H4, H7) + 1 partial (H8).
H5/H6 stay BEC-only. AN-016 / D2 explicitly marked BEC-only-by-design
in manuscript.**

### 8.6 Stage 2 (bid microdata scrape) — still relevant only for H6

Even with Portal da Transparência bulk, H6 (Imhof) is blocked because
lance values are not in the public files. The only way to lift H6 is
Stage 2: scrape per-UASG bid microdata from Portal SISG. Cost
estimate stands at 4-8 weeks of engineering with non-trivial
coverage risk pre-2014. **Recommendation (mr-frequent): submit JLEO
R&R with five 🟢 + one 🟡 from Portal da Transparência; mark H6
explicitly as BEC-only-by-bid-microdata-gap; do NOT promise Stage 2 in
the cover letter unless an editor specifically asks for Imhof
cross-validation.**

### 8.7 Engineering pivot

The original Stage 1 plan called for the open-data API. The
acquisition is now better structured as:

- **Stage 1a (API, in progress, lower priority):** keep
  `bulk_acquire_comprasnet.py` running; produces auxiliary metadata
  (tender descriptions, dates, UASG cross-walk, post-2021 marker).
  Output is complementary, not load-bearing.
- **Stage 1b (Portal da Transparência bulk, NEW, load-bearing):** new
  script `scripts/00_build_eventlevel_comprasnet.py` downloads 84
  monthly ZIPs (~525 MiB compressed, ~3-5 GiB raw CSV), validates
  schema, builds the 5 canonical paper3 outputs with `panel='comprasnet'`
  tag. DuckDB-native end-to-end. Drafted 2026-05-22.
- **Stage 1c (CADE federal cobidder linkage):** as previously planned
  (case-by-case PDF extraction from CADE × UASG join).
- **Stage 4 (replication runs):** existing v18 R scripts run with
  `--source=comprasnet` flag (to be wired in the scripts themselves).

Total revised effort: Stage 1b ~3 days, Stage 1c ~1 week, Stage 4 ~2
weeks. R&R window of 6-12 weeks comfortably absorbs this if started
in week 1 of revision.

This memo is a **planning artifact**, not a commitment. Decision to
pursue ComprasNet replication depends on (i) JLEO R&R reception, (ii)
researcher capacity, (iii) data access.
