# Path to Confirmed via ComprasNet federal replication

**Status:** planning document. Drafted 2026-05-22 in the wake of the
H1–H8 audit-completion exercise that brought 7 of 8 hypotheses to
**Partial (strongly supported)** but found every one of them bounded
below 🟢 (Confirmed) by the same constraint — *all evidence shares the
BEC × CADE data lake*.

This memo lays out the natural cross-validation target (ComprasNet
federal), the analyses that would replicate, the data-acquisition
roadmap, and an honest probability assessment of moving 1–3 hypotheses
to 🟢 within the JLEO R&R window.

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

- Does the existing `scripts/00_build_bidlevel.py` parametrize over
  data source, or is BEC-specific? Audit needed.
- Does CADE publish federal-procurement-specific cobidder mappings,
  or do we need to construct them from scratch?
- Bid microdata coverage post-2019 on ComprasNet: improving or
  declining?

This memo is a **planning artifact**, not a commitment. Decision to
pursue ComprasNet replication depends on (i) JLEO R&R reception, (ii)
researcher capacity, (iii) data access.
