# Federal Price-Signals (ComprasNet `item_pregao_api`) — Integrity & Linkability Diagnostics

Generated 2026-06-05. Source parquet:
`data/processed_comprasnet/item_pregao_api.parquet`
Built by `work/v22-editor/scripts/build/parse_item_pregao_api.py` from 574 weekly
ComprasNet item_pregao API JSON dumps (2009–2019). Parse log:
`/tmp/parse_item_pregao_rerun.log`.

All DuckDB probes run at `threads=6, memory_limit=6GB` (shared machine).

---

## 1. Integrity & coverage

### Parse stats (from log, exit 0)
- Records read: **13,200,265**; written: **12,427,818**; exact-duplicate
  `idCompraItem` drops: **772,447** (5.85%). Dedup keeps first occurrence;
  weekly windows overlap by 1–2 days so the same item recurs in adjacent files.
- Output size 1.12 GB snappy. Peak RSS 1.73 GB, 165 s wall.

### Parquet opens cleanly
- Rows: **12,427,818**. `codigoitem` distinct = 12,427,818 (one row per item —
  the dedup key is the grain, fully unique). Distinct `idCompra` (tenders):
  **426,021**.

### Year coverage (from `dtEncerramento`, fallback `dtHom`)
2009–2019 fully covered, ~1.0–1.36 M rows/year:

| year | rows | | year | rows |
|---|---|---|---|---|
| 2009 | 1,088,498 | | 2015 | 1,004,665 |
| 2010 | 1,178,640 | | 2016 | 1,072,345 |
| 2011 | 1,205,334 | | 2017 | 1,019,030 |
| 2012 | 1,214,882 | | 2018 | 1,026,417 |
| 2013 | 1,362,630 | | 2019 | 1,010,065 |
| 2014 | 1,193,735 | | | |

Minor out-of-range leakage from window overlap: 2003–2008 ≈ 17.7k rows total,
2020 = 31,072, 2021–2023 ≈ 2.8k. Filter `year BETWEEN 2009 AND 2019` for analysis.

### Price-field completeness (% of all 12.43M rows)

| field | % non-null | % > 0 |
|---|---|---|
| `valorEstimadoItem` (reference/estimated) | 100.00 | 99.95 |
| `menorLance` (lowest bid) | 94.78 | 94.70 |
| `valorNegociado` (negotiated) | 6.39 | 6.39 |
| `valorHomologadoItem` (awarded, **unit**) | 84.45 | 84.34 |

`valorNegociado` is too sparse (6%) to use. `valorEstimadoItem` and `menorLance`
are the dense, analysis-grade fields. `valorHomologadoItem` is present exactly
when the item was awarded (see situacao).

### `situacaoItem` (which states = awarded)

| situacaoItem | rows | % | hom-price>0 rate |
|---|---|---|---|
| **homologado** | 10,495,881 | 84.45 | 0.999 |
| cancelado no julgamento | 1,183,714 | 9.52 | 0.000 |
| cancelado | 648,811 | 5.22 | 0.000 |
| cancelado na adjudicação | 42,618 | 0.34 | 0.000 |
| adjudicado | 39,164 | 0.32 | 0.000 |
| encerrado | 11,462 | 0.09 | 0.000 |
| em análise | 6,168 | 0.05 | 0.000 |

**Awarded = `situacaoItem = 'homologado'`** (84.45%); it is the only state with a
populated award price. `adjudicado` is awarded-but-not-yet-homologated (no price
captured here). Cancelled states have no award. Use `situacaoItem='homologado'`
to define the awarded subset.

### Reference-vs-bid sanity
- Both `menorLance>0` and `valorEstimadoItem>0`: 11,764,249 rows. Of these,
  `menorLance ≤ valorEstimadoItem` (winning bid at or below reference) holds for
  **86.51%** — economically sensible (most awards undercut the reference price).
- Discount ratio `menorLance / valorEstimadoItem`:

| p1 | p25 | median | p75 | p99 | p99.9 | max |
|---|---|---|---|---|---|---|
| 0.034 | 0.483 | **0.750** | 0.991 | 12.22 | 800 | 4.5e10 |

Median 0.75 (25% discount off reference) is reasonable. **Fat right tail of
data-entry garbage**: ratio > 10 in **134,275 rows (1.14%)**, ratio > 100 in
**30,942 rows (0.26%)**, max 4.5e10. Recommend trimming ratio to a sane band
(e.g. (0.01, 5]) or winsorizing before any price regression.

---

## 2. Linkability to `item_level_panel.parquet` (Portal panel)

### Key decomposition — VERIFIED empirically
Every `idCompra` is **17 chars**, every `idCompraItem` is **22 chars** (100% of
rows, no exceptions). Layout confirmed on 30 sampled records:

```
idCompra (17) = codigo_ug(6) + "05"(modalidade=pregão) + numerodaoc(9)
idCompraItem (22) = idCompra(17) + item_seq(5)
```
- Chars 7–8 of `idCompra` = `"05"` for **100%** of rows (single modalidade,
  pregão eletrônico).
- The parser exposes `codigoitem = idCompraItem` and `codigoitem == idCompraItem`
  for **100%** of rows.
- The Portal panel's `códigoitem` is the **identical** 22-char composite
  (`codigo_ug(6)+"05"+numerodaoc(9)+item_seq(5)`); its first 6 chars are
  `codigo_ug`. Panel `po_phase_code` is 5 (pregão) for the matchable rows.

**=> The join key is item-level: `api.codigoitem == panel."códigoitem"`. No
derivation, padding, or fuzzy matching needed — it is a direct string equality.**

### Grain verdict: ITEM-LEVEL (not merely tender-level)
`idCompraItem` carries a 5-digit item sequence beyond the 17-char tender id, and
it equals the panel's item key exactly. Linkage is genuinely **per-item**, the
same grain the Portal panel uses (panel `códigoitem` is 99.45% unique:
7,241,428 distinct / 7,281,396 rows).

### Join rate (200k random API sample, 2009–2019)

Overall item-level match = **43.5%**, but this is dominated by a coverage window
mismatch, NOT a key failure:

| year | sample n | matched | match % |
|---|---|---|---|
| 2009 | 17,410 | 0 | 0.00 |
| 2010 | 18,857 | 0 | 0.00 |
| 2011 | 19,189 | 0 | 0.00 |
| 2012 | 19,632 | 40 | 0.20 |
| 2013 | 22,002 | 15,171 | **68.95** |
| 2014 | 19,064 | 14,072 | **73.81** |
| 2015 | 16,252 | 11,667 | **71.79** |
| 2016 | 17,426 | 12,298 | **70.57** |
| 2017 | 16,381 | 11,760 | **71.79** |
| 2018 | 16,578 | 10,961 | **66.12** |
| 2019 | 16,392 | 10,633 | **64.87** |

**The Portal panel only covers 2013–2019** (zero rows before 2013; confirmed:
panel rows/year start at 2013 = 1.20M). The zero match for 2009–2012 is the panel
having no rows there, not a broken key. **The API source therefore extends price
coverage backward to 2009–2012, which the Portal panel cannot provide.**

For the overlapping window 2013–2019 the item-level match rate is a steady
**65–74%**. Of the unmatched 2013–19 homologado items, **79% are because the UASG
itself is absent from the Portal panel** (3,423 ug-in-panel vs 13,131 ug-absent
on the unmatched residual) — i.e. unit-coverage differences between the two
extracts, not key corruption. The remaining ~21% are item-level gaps within a
covered UASG.

### Match validation on matched pairs (2013–2019, homologado)

1. **Winner CNPJ agreement — CANNOT be validated from this extract.**
   `fornecedorVencedor` is **100% null** across the whole parquet (0 non-null of
   12.43M). The field exists in the schema but the API dumps never populated it.
   Winner identity must come from elsewhere (the Portal panel's
   `codigo_vencedor`) if needed.

2. **Price agreement — VALIDATES once grain is reconciled.**
   `valorHomologadoItem` is a **UNIT price**; panel `valor_item` is the **TOTAL**
   (unit × quantity). `quantidadeItem` matches panel `quantidade_item` exactly
   (**99.83%**). After multiplying:

   | comparison | agreement |
   |---|---|
   | `valorHomologadoItem` (unit) ≈ `valor_item` | 4.8% |
   | **`valorHomologadoItem × quantidadeItem` ≈ `valor_item`** | **80.2% @1%, 84.1% @5%, 76.1% @0.1%** |
   | `menorLance × quantidadeItem` ≈ `valor_item` | 67.0% @1% |

   80% exact (1% tolerance) agreement on award totals, with quantity matching
   99.8%, confirms the join is correct and the price fields are real. The ~16%
   residual is consistent with rounding, partial-lot awards, and the known
   data-entry tail. `menorLance×qty` agrees with `valor_item` at 67% — expected,
   since `menorLance` (lowest bid) and `valorHomologadoItem` (homologated award)
   can differ after negotiation.

---

## 3. Recommendation

**Join rule (validated):** direct item-level string equality
`api.codigoitem = panel."códigoitem"`. Restrict API side to
`situacaoItem='homologado'` for awarded items and `year BETWEEN 2009 AND 2019`.
No key derivation needed; the 22-char composite is shared verbatim.

**Grain:** ITEM-level linkage, confirmed — not tender-only.

**Which price source for the federal price-scope replication:**

- **For 2013–2019 (overlap with Portal panel):** the new `menorLance` /
  `valorEstimadoItem` fields are the **value-add this source uniquely provides** —
  the Portal panel has only the awarded total (`valor_item`) and carries *no*
  reference price and *no* lowest-bid field. So for any analysis that needs the
  **discount-vs-reference signal** (menorLance/valorEstimadoItem), this API source
  is **required**; there is no Portal substitute. Use API `menorLance` and
  `valorEstimadoItem` (unit grain; multiply by `quantidadeItem` if a total is
  needed to align with the panel). Keep winner identity from the Portal panel
  (`codigo_vencedor`), since API `fornecedorVencedor` is unusable (100% null).

- **For 2009–2012:** the Portal panel does not exist; this API source is the
  **only** option for federal pregão price signals in those years.

- **Use `valor_item` from the Portal panel** only when you specifically need the
  awarded *total* with winner CNPJ and the panel's competition counts
  (`n_firms`, `n_winners`, `n_losers`) — those are not in the API extract.

**Net:** the federal price-scope replication should source `menorLance` and
`valorEstimadoItem` from `item_pregao_api.parquet` at the **item grain**, joined
to the Portal panel on `codigoitem`, because those two price signals are absent
from the Portal panel and this source also extends coverage to 2009–2012. Apply a
discount-ratio trim (drop ratio > ~5 or < ~0.01; ~1.1% of rows) before any
price regression to remove the data-entry tail.

### Caveats for the data appendix
- `fornecedorVencedor` 100% null — do not rely on it for winner identity.
- `valorHomologadoItem`/`menorLance` are **unit** prices; the Portal `valor_item`
  is a **total**. Always reconcile by `× quantidadeItem`.
- Item-level match in the overlap window is 65–74%, with the shortfall driven
  mostly (≈79%) by UASGs the Portal panel does not cover, not by key failure.
- `valorNegociado` (6.4%) too sparse to use.
