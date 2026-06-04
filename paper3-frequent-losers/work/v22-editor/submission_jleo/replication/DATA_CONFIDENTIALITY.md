# Data availability & confidentiality

*Cheap Signals, Costly Proof* — Genicolo-Martins & de Azevedo (INSPER), JLEO R&R v22.

This statement describes which inputs can be shared, which cannot, and how to
request access. **We do not claim the BEC procurement microdata are public.**

---

## 1. BEC procurement microdata — NOT freely public, NOT redistributable

The primary inputs are administrative records from the **State of São Paulo
electronic procurement platform (BEC/SP)**:

- `data/processed/bid_level_full.parquet` / `bid_level_full_v14.parquet`
  (~40M bid-level rows; the underlying raw `LANCES_Final_Semester.dta`),
- `data/processed/Firms_final.parquet` (firm registry; raw CNPJ, CNAE, porte,
  location),
- and the derived parquets built from them (`firm_tender_map.parquet`,
  `firm_loss_stats.parquet`, `FREQ_PARTICIP_rebuilt.parquet`,
  `BEC_collapse_final.parquet`, `item_value_panel.parquet`,
  `v3/data/processed/bid_level_with_prices.parquet`).

These are **administrative data, not freely public**. The raw `.dta`/parquet
files **cannot be posted** in a public replication archive. They are obtained
under the terms governing access to the BEC platform records and contain
firm-identifying information (CNPJ).

## 2. CADE adjudication data — public rulings

CADE (Conselho Administrativo de Defesa Econômica) cartel convictions are
**public administrative rulings** published at **gov.br/cade**. The curated case
file `data/processed/cade_carteis_licitacoes_2009_2019.csv` (and its README) is
**derived from those public rulings** and may be shared. Note it contains
**judgment dates only** (9/12 cases dated); conduct-onset / filing dates are not
recorded.

## 3. Label / linkage files — partially blocked (B3, disclosed)

- `data/processed/cade_fl_cobidders.csv` (193 FL firms co-bidding with CADE
  cartelists) and `data/processed/cade_bec_crossmatch.csv` **have no builder on
  disk** (blocker **B3**). We disclose this rather than present them as
  reproducible.
- The **reproducible alternative** is the transparent label funnel:
  `scripts/79_label_funnel.R` (+
  `work/v22-editor/scripts/analysis/01_label_funnel_reconciliation.R`), which
  rebuilds the cobidder set from the public CADE cases joined to BEC firm
  participation (12 cases → 41 → 341; reproduces the conservative 208≈210 /
  107≈108 sets, **not** the legacy 193). Cobidder→case linkage is materialized in
  `output/label_funnel/case_cobidder_map.csv`.

## 4. What CAN be posted (derived / anonymized)

Derived **firm-level frames with an anonymous `firm_id` and no raw CNPJ** can be
posted, e.g. anonymized versions of `firm_loss_stats` / `FREQ_PARTICIP_rebuilt`
(win-rate, always-loser flag, `tenders_count`) and the opportunity-adjusted
firm panel (`outputs/cache/firm_opportunity_adjusted_frame.csv` with identifiers
stripped). Note: in `firm_tender_map.parquet`, `códigofornecedor = -1` is an
anonymization sentinel and must be excluded.

All **non-data artifacts** in this package — scripts, the output/diagnostic CSVs
under `work/v22-editor/outputs/`, tables, figures, logs, and manifests — are
shareable.

## 5. How to request access

For supervised or replication access to the BEC microdata, or for anonymized
derived frames, contact **Darcio Genicolo-Martins, INSPER —
<darcio.g.martins@gmail.com>**. Access to the raw BEC records is subject to the
data provider's terms; the authors cannot re-license or redistribute the raw
microdata.

## 6. Cooperation pledge

The authors will **cooperate in good faith with legitimate replication
requests** — providing scripts, anonymized derived frames, intermediate
diagnostic outputs, and guidance — within the limits set by the BEC data
provider's confidentiality terms.
