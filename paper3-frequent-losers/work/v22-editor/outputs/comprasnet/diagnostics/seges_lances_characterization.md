# SEGES `tbl_lances` dump — characterization & overlap diagnostic

**Date:** 2026-06-06
**Source files:** `/home/darciogm1/projetos/comprasnet/data/raw/seges_lances/`
- `tbl_lances.csv.gz` (~2.50M rows)
- `tbl_lances_encerrados.csv.gz` (~1.34M rows)
- `tbl_lances_header.csv` (data dictionary; 241 columns)

**Read recipe:** `read_csv(f, delim='\t', header=false, quote='', strict_mode=false, ignore_errors=true)` → columns auto-named `column000…column240`. Latin-1, denormalized (each lance row carries the full join of tbl_Lances ⋈ tbl_PropostaItem ⋈ tbl_Proposta ⋈ tbl_pregaoitem ⋈ tbl_Pregao ⋈ tb_uasg ⋈ tb_orgao).

---

## 1. Verified column-position map (241 cols, 7 tables concatenated in header order)

Table block boundaries (verified): `tbl_Lances` 000–013 · `tbl_PropostaItem` 014–070 · `tbl_Proposta` 071–092 · `tbl_pregaoitem` 093–130 · `tbl_Pregao` 131–197 · `tb_uasg` 198–232 · `tb_orgao` 233–240.

Key fields, with 3 sample values (verified against data):

| pos | field | table | sample values |
|---|---|---|---|
| column000 | `lanCod` | tbl_Lances | 158211035, 158211054, 158247880 |
| column002 | `cliente_id` (bidder/FRN) | tbl_Lances | FRN000218532, FRN000218532, FRN000218532 |
| column003 | `lanData` (bid timestamp) | tbl_Lances | 2010-09-29 13:25:00, 2010-09-29 13:25:00, 2010-09-29 16:06:17 |
| column004 | `lanValor` (bid value) | tbl_Lances | 12000.00, 12000.00, 11997.99 |
| column016 | `ipgCod` (item id, PropostaItem) | tbl_PropostaItem | 6847575, 6847580, 6847580 |
| column075 | `prpCNPJ` (bidder CNPJ-14) | tbl_Proposta | 10723998000106 ×3 |
| column093 | `ipgCod` (item id, pregaoitem) | tbl_pregaoitem | 6847575, 6847580, 6847580 |
| column094 | `prgCod` (pregão id) | tbl_pregaoitem | 244818 ×3 |
| column095 | `ipgItem` (item number within pregão) | tbl_pregaoitem | 12, 17, 17 |
| column097 | `codmat` (CATMAT material code) | tbl_pregaoitem | 18035, 18364, 18364 |
| column099 | `codmun` | tbl_pregaoitem | 71072 ×3 |
| column100 | `coduf` | tbl_pregaoitem | SP ×3 |
| column131 | `prgCod` (pregão id, Pregao) | tbl_Pregao | 244818 ×3 |
| column132 | `coduasg` (**ComprasNet client id, NOT SIASG UG**) | tbl_Pregao | 925218 ×3 |
| column133 | `numprp` (seq‖year, no zero-pad) | tbl_Pregao | 2472010 ×3 (= seq 247 + year 2010) |
| column136 | `prgDataAbertura` | tbl_Pregao | 2010-09-29 13:00:00 ×3 |
| column193 | `prgModoDisputa` | tbl_Pregao | NULL ×3 (empty across this 2010-2021 window) |
| column198 | `coduasg` (tb_uasg key) | tb_uasg | 925218 ×3 |
| column199 | `nomuasg` (UASG name) | tb_uasg | "PMSP - SEGES - COORD GESTÃO BENS E SERVIÇOS", … |
| column212 | `uf` (UASG state) | tb_uasg | SP ×3 |
| column215 | `SiglaUasg` / operational UG code | tb_uasg | "925102","986001","925218" (RJ codes start 986) |
| column217 | `CodMunic` | tb_uasg | 71072 ×3 |
| column240 | `cnpj` (órgão CNPJ) | tb_orgao | — |

All known anchors confirmed: 000=lanCod, 002=bidder, 003=lanData, 004=lanValor, CNPJ mid-row at 075, numprp `2472010`-style at 133, UASG fields near the end (198, 212, 217).

---

## 2. Selection characterization

| Quantity | Value |
|---|---:|
| Total lances (both files) | 3,840,465 |
| Distinct pregões (coduasg×numprp) | 22,104 |
| Distinct UASGs (coduasg) | 880 (864 with valid numprp) |
| Distinct items (coduasg×numprp×ipgCod) | 116,231 |
| Distinct bidder CNPJ-14 | 22,889 |
| Distinct bidder FRN codes | 22,932 |
| Lances per item | min 1 · q25 4 · median 14 · q75 37 · q90 80 · max 6,430 · mean 33.0 |

**Year distribution (by `lanData`):** 2010 (56k) → ramps up → 2018 (463k), 2019 (694k peak), 2020 (442k), 2021 (334k). Coverage 2010–2021. The `numprp` year-suffix confirms the seq‖year structure; year suffixes 2009–2021 carry essentially all pregões (singleton suffixes elsewhere are parse artifacts from a handful of column-shifted rows).

**`prgModoDisputa` (col193): entirely NULL** in this window — the field was only populated systematically in later platform versions; not usable here.

### THE SELECTION PATTERN — geographic, not federal

UF distribution (by UASG state, valid 2-char codes only):

| UF | pregões | lances |
|---|---:|---:|
| **SP** | 14,894 | 2,449,584 |
| **RJ** | 6,147 | 1,366,864 |

**Only two states: São Paulo and Rio de Janeiro.** Inspection of `nomuasg`/`SiglaUasg` shows the buyers are **municipal**: "PMSP - SEGES - COORD GESTÃO BENS E SERVIÇOS", "PMSP - SUBPREFEITURA LAPA", "PMSP - DIRETORIA REG. DE EDUCAÇÃO", "PMSP - COORDENADORIA REG. DE SAÚDE", and Rio counterparts (operational UG codes `925xxx` for SP-municipal, `986xxx` for RJ). `column132 coduasg` is a ComprasNet internal **client/registration id** (e.g. 925000, 619871, 247357), distinct from the operational UG code in `SiglaUasg` (e.g. 925218).

**Reading of the ~5% volume anomaly:** the dump is not a sample of federal ComprasNet at all. It is the **SP/RJ municipal-government slice** of a ComprasNet-family platform (PMSP "e-Negócios"/Bolsa Eletrônica-style adhesion + Rio municipal). The 3.84M lances are the full lance history of that municipal slice, 2010-2021 — which is why it is a small fraction of the federal universe.

---

## 3. Coverage vs our federal panel & decisive overlap

### Key construction & validation (Task 2)
Dump `numprp` → `numerodaoc`: strip last 4 chars as year, `LPAD(remainder, 5, '0') || year`. Validated on 20 examples, all correct (e.g. `2472010`→`002472010`, `132012`→`000132012`, `60022012`→`060022012`, `22014`→`000022014`).

### Pregão-level coverage vs `item_level_panel.parquet` (federal, 7.28M item-rows, 2,698 UGs, 2013-2019)

**ZERO match.**
- Dump distinct `coduasg` found in panel `codigo_ug`: **0 / 864.**
- Dump pregões (coduasg+numerodaoc) matched to panel (UG+numerodaoc): **0 / 22,100.**
- Shared-UASG subset for the numerodaoc test: **empty** (no UASG is shared).
- `numerodaoc`-only match ignoring UASG = 14,824/22,103 — **spurious**: small integer sequence numbers collide across totally different buyers; not real matches.

The panel's `codigo_ug` are federal SIASG UGs (`158273`, `120062`, `160403`, `153114`…); the dump's UGs are SP/RJ municipal (`925xxx`/`986xxx`). **The two are disjoint populations; per-year coverage share against the federal panel is 0% in every year.** Years 2010-2012 and 2020-2021 in the dump also fall outside the panel's 2013-2019 window entirely.

### CADE-anchored federal tender-item overlap (Task 3)
`anchored_tenders_federal.parquet` = 32,148 federal (numerodaoc, códigoitem) pairs, all keyed on federal UGs. Item key decode of the 22-char `códigoitem`: UG(6) + `05`(2) + seq(5) + year(4) + **item_seq(5, last 5 digits)**.

Because the anchored list lives entirely on federal UGs and the dump contains **zero federal UGs**, the structural overlap of anchored tender-items with a lance in the dump is **0**. (No CNPJ-matched item validation is possible — the item universes do not intersect.)

### CNPJ-level overlap — the one real bridge (firms bid across jurisdictions)
| Set | size | hit in dump (as bidder) |
|---|---:|---:|
| Direct CADE defendants (estabs, CNPJ-14) | 27 | **15** |
| Direct CADE defendant raízes (CNPJ-8) | 19 | **11** |
| All federal cobidders (CNPJ-14) | 4,164 | **2,534** |
| Always-loser cobidders | 222 | **90** |
| FL-federal cobidders (tenders_count ≥ 32) | 109 | **60** |

> **Note on "195 broad-AL cobidders":** the canonical ComprasNet linkage in `cade_link_v3/` has **222 always-loser cobidders** (109 of which are FL-federal), not 195; the 195 figure is the BEC/v22 broad-AL count and does not exist as a list in the ComprasNet v3 artifacts. The hit counts above use the actual v3 cobidder file. CADE-anchored firms clearly participate in this SP/RJ municipal data (15/27 defendants, 60/109 FL cobidders, 2,534/4,164 cobidders appear as bidders) — but in **different (municipal) tenders**, not the federal anchored ones.

---

## 4. VERDICT

**(c) A different population entirely — municipal SP/RJ procurement — with (b) standalone validation value, but NOT a Tier-2 base for the anchored federal Imhof analysis.**

Honest reading: this is not a selected sub-sample of the federal ComprasNet universe our panel and CADE anchoring are built on; it is the São-Paulo-and-Rio **municipal** lance history of a ComprasNet-family platform (PMSP SEGES "e-Negócios" + Rio), 2010-2021, ~3.84M lances over 22,104 pregões in 880 municipal UASGs. Its UASG namespace (`925xxx`/`986xxx` municipal) is disjoint from the federal SIASG UGs (`12xxxx`/`15xxxx`/`16xxxx`) that key both `item_level_panel` and the 32,148 CADE-anchored federal tender-items, so the anchored-tender overlap is structurally **zero** and per-year federal coverage is **0%**. The only thing that crosses over is firms: 15/27 CADE defendant estabs and 60/109 FL-federal cobidders show up as bidders here — meaning the dump is a genuine, lance-microdata-rich **out-of-jurisdiction validation set** where one could re-run Imhof screens on the *same firms* in a different procurement environment (a useful robustness/external-validity exercise), but it cannot extend or substitute the federal anchored sample, and it must not be merged into it on any tender/UG key. If a SELECTED-subsample Imhof analysis is wanted, it would be a *new* municipal-SP/RJ study (N ≈ 116k items, full lance dispersion available), not Tier-2 support for the existing federal one.

### Caveats / open items
- A handful of rows are column-shifted (ignore_errors drops/realigns them); they surface as singleton `numprp` year-suffixes and a 21-char `códigoitem` — immaterial at this scale.
- `prgModoDisputa` is NULL throughout, so disputa-mode selection cannot be tested from this field; if needed, infer from `prgDataAbertura` era + platform version.
- A UG crosswalk (municipal `925xxx` ↔ a federal-style UG) does **not** exist for these buyers — they are simply not in SIASG-federal. Cross-jurisdiction work must join on **CNPJ only**.
- CNPJ hits are existence-as-bidder; firm-level behavioral comparison (win rates, dispersion) in the municipal data is feasible but not yet computed.
