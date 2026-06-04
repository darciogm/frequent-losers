# Data availability & replication statement — JLEO submission

*Cheap Signals, Costly Proof: The Reach and Limits of Award-Layer Screening in
Cartel Enforcement* — Genicolo-Martins & de Azevedo (INSPER).

This statement summarizes which inputs can be shared, which cannot, and how to
request access. **We do not claim that all data or code are publicly available.**
The authoritative source is `work/v22-editor/replication/DATA_CONFIDENTIALITY.md`
and the package `README.md`.

---

## 1. Data used

- **BEC procurement microdata** (State of São Paulo electronic procurement
  platform, "BEC/SP"), 2009–2019: bid-level records (raw
  `LANCES_Final_Semester.dta`, ~40M rows), a firm registry (CNPJ, CNAE, porte,
  location), and parquets derived from them. Analysis sample: \valSampleN
  tender-items.
- **CADE adjudications** (Conselho Administrativo de Defesa Econômica): cartel
  convictions used as legal anchors.

## 2. Public vs. confidential

- **Public (CADE rulings):** CADE cartel convictions are public administrative
  rulings (gov.br/cade). The curated case file
  `cade_carteis_licitacoes_2009_2019.csv` is derived from those public rulings
  and **may be shared**. Note it records **judgment dates only** (9 of 12 cases
  dated); conduct-onset / filing dates are not in the public record.
- **Confidential / restricted (BEC microdata):** the bid-level records and the
  firm registry are **administrative data and are NOT freely public**. They
  contain firm-identifying information (CNPJ) and are obtained under the terms
  governing access to the BEC platform. The raw `.dta`/parquet files **cannot
  be posted or redistributed** in a public archive, and the authors cannot
  re-license them.

## 3. What CAN be shared

- **Derived / anonymized firm-level frames** with an anonymous `firm_id` and no
  raw CNPJ — e.g. anonymized win-rate, always-loser flag, and `tenders_count`
  frames, and the opportunity-adjusted firm panel with identifiers stripped.
- **All analysis scripts** (Python ETL + R analysis + table/figure assembly).
- **All non-data artifacts:** output/diagnostic CSVs, tables, figures, logs, and
  manifests.

## 4. What CANNOT be shared

- Raw BEC bid-level microdata, the raw firm registry, and any frame carrying raw
  CNPJ or other direct firm identifiers.
- (Disclosed limitation **B3**) the legacy cobidder label files
  `cade_fl_cobidders.csv` and `cade_bec_crossmatch.csv` have **no builder on
  disk**. Rather than present them as reproducible, we disclose this and provide
  a transparent reproducible alternative: the **label funnel**
  `scripts/79_label_funnel.R` (with
  `work/v22-editor/scripts/analysis/01_label_funnel_reconciliation.R`), which
  rebuilds the cobidder set from the public CADE cases joined to BEC firm
  participation.

## 5. Anonymization / hashing

Shareable derived frames replace raw CNPJ with an anonymous `firm_id`; direct
identifiers are stripped before any frame leaves the access-controlled
environment. In `firm_tender_map`, `códigofornecedor = -1` is an anonymization
sentinel and is excluded from analysis.

## 6. How researchers request access

For supervised or replication access to the BEC microdata, or for anonymized
derived frames, contact **Darcio Genicolo-Martins, INSPER —
darcio.g.martins@gmail.com**. Access to the raw BEC records is subject to the
data provider's terms; the authors cannot redistribute the raw microdata.

## 7. Strict replication

The authors retain the full pipeline and **can re-run it end-to-end on the
access-controlled inputs** to reproduce every reported number for strict
replication. The output-to-script map is provided so that each manuscript object
can be traced to its generating script:

- **Outputs → scripts map:** `work/v22-editor/replication/OUTPUTS_MAP.csv`
- **Machine-readable manifest:** `work/v22-editor/replication/MANIFEST.csv`
- **Dependency-ordered run sequence:** `work/v22-editor/replication/SCRIPT_ORDER.md`
- **Package README:** `work/v22-editor/replication/README.md`
- **Confidentiality detail:** `work/v22-editor/replication/DATA_CONFIDENTIALITY.md`

## 8. JLEO 3-year data/code policy

JLEO asks that data, programs, and logs be public within three years of
publication unless a **proprietary-data exemption** is granted. Because the BEC
microdata are administrative and restricted, we **intend to request that
exemption** for the BEC inputs while making code, derived/anonymized frames, the
output map, and all non-data artifacts available (see
`admin/confidential_data_exemption_note.md`). We do **not** promise public
release of the restricted BEC microdata.

## 9. Cooperation pledge

The authors will cooperate in good faith with legitimate replication requests —
providing scripts, anonymized derived frames, intermediate diagnostic outputs,
and guidance — within the limits set by the BEC data provider's confidentiality
terms.
