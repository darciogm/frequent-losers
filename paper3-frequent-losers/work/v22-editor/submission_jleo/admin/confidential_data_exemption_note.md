# Request for the JLEO proprietary-data exemption — BEC microdata

*Cheap Signals, Costly Proof* — Genicolo-Martins & de Azevedo (INSPER).

JLEO's policy asks that data, programs, and logs be made public within three
years of publication unless a **proprietary-data exemption** is granted. We
respectfully request that exemption for the primary inputs of this study.

## Why an exemption is needed

The study's primary inputs are **administrative procurement records from the
State of São Paulo electronic procurement platform (BEC/SP)** — bid-level
records and a firm registry containing firm-identifying information (CNPJ).
These are **administrative, restricted data**, obtained under the terms
governing access to the BEC platform. They are not freely public and **cannot be
redistributed** in a public replication archive; the authors are not able to
re-license or redistribute the raw microdata.

(For completeness: the study's other source — CADE cartel adjudications — is
**public** (gov.br/cade), and the curated case file derived from those rulings
will be shared. This exemption request concerns the BEC microdata only.)

## What we WILL provide to support replication

To support replication-by-rerun consistent with the spirit of the policy:

1. **All analysis code** — the full Python ETL and R analysis/assembly pipeline.
2. **Derived / anonymized firm-level frames** — with anonymous `firm_id` and raw
   identifiers stripped — to the extent permitted by the data-provider terms.
3. **An output-to-script map** (`work/v22-editor/replication/OUTPUTS_MAP.csv`)
   plus the manifest and dependency-ordered run sequence, so every reported
   number is traceable to its generating script.
4. **All non-data artifacts** — diagnostic CSVs, tables, figures, logs, and
   manifests.
5. A **transparent label funnel** (`scripts/79_label_funnel.R`) as the
   reproducible alternative for the CADE-cobidder linkage (disclosed limitation
   B3).
6. **Author re-runs** for strict replication and good-faith assistance with
   legitimate replication requests, plus guidance on requesting supervised
   access to the BEC microdata from the data provider.

We do not request any exemption for code or for the public CADE-derived
material, and we do not claim the restricted BEC microdata will be made public.
