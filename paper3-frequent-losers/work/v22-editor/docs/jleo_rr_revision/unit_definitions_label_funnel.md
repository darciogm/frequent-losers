# Unit Definitions — Label-Construction Funnel (JLEO R&R v22, CP-1)

**Purpose.** Define and distinguish every counting unit used in the
adjudication-anchored exposure-label construction, and bind each reported count
to exactly one unit, one definition, and one traceable source. Written for the
referee record: every count here is reproducible from the listed file/script
line, or explicitly flagged as not reproducible.

**Terminology discipline (locked).** Cobidders are firms that *shared a
tender-item* with a BEC-active CADE direct defendant. They are an
**adjudication-anchored exposure label**, NOT cartel members. We never write
"cartel-adjacent." Direct defendants are the legally adjudicated cartel parties;
cobidders are the exposure population the screen is validated against.

Sources:
- `scripts/79_label_funnel.R` (funnel builder, DuckDB joins)
- `work/v22-editor/scripts/analysis/01_label_funnel_reconciliation.R` (reconciliation/deliverables)
- `output/label_funnel/funnel.csv`, `output/label_funnel/audit_log.txt`
- `work/v22-editor/outputs/diagnostics/label_count_reproduction.csv`
- `work/v22-editor/outputs/tables/main/table_A_label_funnel.csv`, `table_B_case_timing_and_benchmark_use.csv`
- `work/v22-editor/outputs/diagnostics/cobidder_set_comparison_summary.csv`, `label_funnel_assertions.csv`

---

## A. Firm-level unit

- **Definition.** A unique firm = the padded **14-digit CNPJ**, obtained from
  `códigofornecedor` (or `fornecedor` in the crossmatch) via the `pad14()`
  function (strip non-digits, left-pad with zeros to width 14).
  - `pad14`: `01_label_funnel_reconciliation.R` line 82; `79_label_funnel.R` line 74.
- **Defendant exclusion.** Direct defendants are **EXCLUDED** from the cobidder
  candidate pool (`f."códigofornecedor" NOT IN (SELECT cnpj FROM defend)`), and
  the `-1` sentinel is dropped. This guarantees the exposure label never
  contains an adjudicated defendant.
  - `01_..._reconciliation.R` lines 146–147; `79_label_funnel.R` lines 129–130.
  - Verified by assertion **A4** (0 defendants in cobidder sets — pass).
- **Always-loser status is GLOBAL, not benchmark-specific.** A firm is an
  always-loser iff `win_rate == 0` over the entire 2009–2019 BEC universe
  (`firm_loss_stats.always_loser == 1`). Status is a *property of the firm*,
  computed once, independent of which CADE case linked it.
  - `01_..._reconciliation.R` line 157.
- **Frequent-loser (FL14) status** is the always-loser subset with
  `tenders_count >= 14` (`FREQ_PARTICIP_rebuilt`). FL ⊆ AL by construction
  (assertion **A6**, pass).
  - `01_..._reconciliation.R` line 159; threshold = median + 1.5·IQR ≈ 14.

## B. Tender-item unit

- **Key.** `(numerodaoc, códigoitem)` — one tender-item is one auctioned item
  within one OC (tender).
- **Carries.** buyer/PBU (chars 1–11 of `numerodaoc`), **year** =
  `substr(numerodaoc, 12, 15)`, modality (Convite = phase 2, Pregão = phase 3),
  winner, and the participant (bidder) list.
- The co-bid relation is built by joining defendant tender-items back to
  `firm_tender_map` on this exact key.
  - `01_..._reconciliation.R` lines 132–145; `79_label_funnel.R` lines 116–130.

## C. Firm-tender-item unit

- **Definition.** One row per **firm × tender-item** in `firm_tender_map`
  (`firm_tender_map.parquet`, ~16.8M rows), each carrying the `won` flag.
- This is the atomic participation record. Defendant tender-items (Section E)
  and cobidder co-participation are both derived from it.
  - source parquet: `data/processed/firm_tender_map.parquet`.

## D. CADE-case unit

- **Key.** `numero_processo` (CADE administrative process number). **12 distinct
  cases** in the portfolio (`cade_carteis_licitacoes_2009_2019.csv`).
  - distinct count: `01_..._reconciliation.R` line 100; `funnel.csv` row `S0_cade_cases = 12`.
- **Only `data_julgamento` (judgment date) is available**, and only for **9 of
  12** cases (3 are NaT / undated: Cases J, K, L in Table B).
  - `audit_log.txt`: "cases with judgment date = 9 / 12 total".
  - **NO conduct-period dates and NO filing dates exist** in the data. Conduct
    dates are marked `NA — CASE_TIMING_MISSING` throughout Table B.
- **Main vs conservative inclusion flag.**
  - *Main target*: all 12 cases (`included_main_target = Y`).
  - *Conservative pre-2020*: the **4 cases** judged ≤ 2020-12-31
    (`included_conservative_pre2020 = Y`): procs `08700.004617/2013-41`,
    `08012.001273/2010-24`, `08012.009732/2008-01`, `08012.011853/2008-13`.
  - `01_..._reconciliation.R` lines 194–196, 429; `audit_log.txt` S6.

## E. Direct-defendant unit

- **Definition.** A **case × firm** pair: a legally adjudicated cartel party in a
  specific CADE case (`cade_bec_crossmatch.csv`, columns `fornecedor`, `processo`).
- **BEC-match status** distinguishes four reported counts:
  | Count | Meaning | Source |
  |---|---|---|
  | **65** | legal-defendant roster (firms across all cases) | manuscript; **NOT reproducible** (empty CNPJ column in rulings CSV) |
  | **48** | distinct CNPJ in crossmatch file | `n_def_cross`, `01_...R` line 127 |
  | **47** | cited active direct defendants (`\valDirectCADE`) | manuscript; ≈ 48 (one extra/dup CNPJ) |
  | **41** | crossmatch defendants actually present in `firm_tender_map` (ftm-active) | `n_def_ftm`, `01_...R` line 126; `funnel.csv S1` |
- Reproduction: `label_count_reproduction.csv` rows
  `cade_firm_defendants` (65, not_found), `bec_active_direct_defendants_crossmatch`
  (48 vs 47, approx), `bec_active_direct_defendants_ftm` (41, match).

## F. Cobidder unit (FOUR distinct counting units — do not conflate)

A "cobidder" can be counted four different ways. **The reported headline counts
are UNIQUE FIRMS.** Conflating units is the original source of the 193-vs-210
confusion (assertion **A9**).

| Counting unit | Meaning | Example counts | Source |
|---|---|---|---|
| **Unique always-loser firm** | distinct CNPJ, AL stratum | **193 / 341 / 651 / 208 / 107** | `01_...R` lines 176–177, 207–208 |
| **Firm-case pair** | (firm, processo) — a firm linked to multiple cases counts once per case | **5,121** | `case_cobidder_map.csv` (5,121 rows); `audit_log.txt` |
| **Firm-case cobidder pairs (full portfolio)** | per Table A | **4,369** | `table_A_label_funnel.csv` `number_firm_case_cobidder_pairs` |
| **Defendant tender-item** | distinct `(numerodaoc, códigoitem)` shared with a defendant | **52,013** | `n_def_item_ti`, `01_...R` line 137 |

Assertion **A9** (pass) states it explicitly:
`4369 firms vs 5121 firm-case pairs vs 52013 tender-items` —
firm-case pairs > unique firms (expected). **Always state the counting unit.**

---

## Reported-count → unit → definition → source map

| Reported count | Unit | Definition | Source (file / script line) | Status |
|---|---|---|---|---|
| **193** | unique FL firm | static `cade_fl_cobidders.csv` row count; FL-only, **narrow cartel-tender** def; **builder ABSENT** (blocker B3) | `cade_fl_cobidders.csv`; `01_...R` line 96 (`n_cob_file`) | match (exact file row count) |
| **341** | unique FL firm | broad def: any shared tender-item w/ BEC-active defendant, FL14, full 12-case portfolio | `01_...R` line 177 (`n_FL`); `funnel.csv S5` | match |
| **651** | unique AL firm | broad def, always-loser stratum, full portfolio | `01_...R` line 176 (`n_AL`); `funnel.csv S4` | match |
| **210 → 208** | unique AL firm | broad-AL cobidders over 4 conservative cases (`\valConservativeCobidders` was 210) | `01_...R` line 207 (`n_cons_AL`); `funnel.csv S6_cons_AL_cobidders` | approx (data-grounded; 208 reproduces) |
| **108 → 107** | unique FL firm | broad-FL cobidders over 4 conservative cases | `01_...R` line 208 (`n_cons_FL`); `funnel.csv S6_cons_FL_cobidders` | approx (107 reproduces) |
| **30 → 19** | case×firm (defendant) | BEC-active direct defendants in 4 conservative cases (`\valConservativeFD` was 30 = **over-count, drop**) | `01_...R` line 200 (`n_cons_def`); `funnel.csv S6_cons_defendants` | mismatch (30 not reproducible; 19 correct) |
| **47** | case×firm (defendant) | cited active direct defendants (`\valDirectCADE`) | manuscript | ≈ 48 |
| **48** | unique defendant CNPJ | distinct CNPJ in crossmatch | `01_...R` line 127 (`n_def_cross`) | approx vs 47 |
| **41** | unique defendant firm | crossmatch defendants present in `firm_tender_map` | `01_...R` line 126 (`n_def_ftm`); `funnel.csv S1` | match |
| **16,843** | unique AL firm (universe) | `firm_loss_stats.always_loser == 1` | `01_...R` line 116 (`n_AL_univ`) | match |
| **41,444 → 41,443** | unique BEC firm (universe) | distinct `códigofornecedor` ≠ `-1` in `firm_tender_map` | `01_...R` line 115 (`n_all_BEC`) | approx (off-by-1, one sentinel/dup) |
| **2,735** | unique FL firm (universe) | AL & `tenders_count >= 14` | `01_...R` line 117 (`n_FL_univ`) | match |

### Counts NOT reproducible from label-funnel objects

| Count | Why not reproducible |
|---|---|
| **65** (legal defendants) | the rulings CSV `cade_carteis_licitacoes_2009_2019.csv` has an **empty CNPJ column**; the 65-firm legal roster cannot be rebuilt from data on disk. `label_count_reproduction.csv` row `cade_firm_defendants = not_found`. |
| **16,779** (common bid-feature pool) | this is the **Imhof horse-race common-support pool** from scripts 31/49, not a label-funnel object. `label_count_reproduction.csv` row `common_bid_feature_pool = not_found`. |
| **11,676** (gatekeeping pool) | the **same-sample gatekeeping pool** from scripts 63/64, not a label-funnel object. `label_count_reproduction.csv` row `gatekeeping_pool = not_found`. |

These three are flagged in Table A (rows "Common bid-feature pool",
"Gatekeeping pool", and the 65-defendant note) and must not be claimed as
label-funnel reproductions.
