# JHE Final Polish — Summary (2026-06-09)

Final submission-readiness pass. No new empirical analyses, no overhaul, no title
change, no result change. The goal was to remove easy referee objections, sharpen
bounded-null language, simplify the main benchmark table, and tighten prose.

## What was found already done (verified, not re-touched)

- **C (strict PNASH window):** method.tex already states 48 cycle-window vs 37 exact
  ±1-year closures, the 11-closure gap (2014 cohort), similar mortality bounds, and
  that the headline does not turn on the eleven distance-two closures. No change.
- **F (SDID/HonestDiD):** results.tex already describes SDID as a second design that
  "does not require never-treated parallel trends" returning an estimate "inside this
  interval," and states plainly that HonestDiD is too noisy to be informative for the
  mortality series ("the bounded-null reading rests on the classical interval and the
  synthetic design, not on trend extrapolation"). Measured, not oversold. No change.
- **H (base literature):** Buchmueller (2006), Avdic (2016), Petek (2022),
  Wennberg (1973)/Wang (2020) all in place from the prior positioning pass.

## Edits made (surgical, by hand)

- **A — Abstract:** "do not absorb the lost volume" → "do not **measurably absorb the
  lost inpatient volume**"; "suicide and self-harm mortality do not rise" → "**I find
  no evidence of large acute increases** in suicide or self-harm mortality"; "a quarter"
  → "roughly one-quarter"; "synthetic-control design" → "**synthetic difference-in-
  differences** design" (accuracy); "a null" → "a **bounded** null".
- **B — Timing (method.tex §4):** the four-ways preview "closure timing is not predicted
  by local pre-closure conditions" → "closure timing is **not strongly predicted** by
  the local pre-closure conditions I can measure, **though some pre-trend diagnostics are
  nonzero, so I do not treat these tests as proof of unconfoundedness**." (The detailed
  test already disclosed the two significant trend slopes; the preview now matches.)
- **D — Main benchmark table simplified:** the two support-failure rows (nearest /
  top-3 psychiatric provider, with ~3,000–6,500 distance-only counts) **moved out of
  the main table** `table_measurement_compact.tex`; main table now shows only F5 top-3
  any, PNASH top-3 any, PNASH top-3 same type. The "Status" column was dropped; the note
  explains the support failure and points to the full risk-set table already in the
  online appendix. Main Table 3 now readable in ~30 s.
- **E — Displacement precision:** "do not absorb" → "do not **measurably absorb**" in
  results §5.3, the online-appendix figure caption, and the appendix robustness-table
  caption (and its generator script 91, for reproducibility). §5.3 retains the explicit
  CAPS/outpatient limitation ("the SIH does not observe CAPS production").
- **I — Language polish (4 subagents, by file):**
  - intro: "the hospital down the road" → "the nearest facility"; "to evidence that" →
    "to recent evidence that"; "mortality barely moves" → "the mortality estimates
    remain close to zero and imprecise".
  - results/robustness: "back the measurement claim" → "support…"; "a quiet replacement"
    → "a substitute"; "leaves the suicide estimate near baseline" → "…close to the
    primary estimate".
  - discussion/conclusion: "disruption to care" → "disruption to inpatient psychiatric
    care"; "the two papers read" → "examine"; **removed a second convergence overclaim**
    ("Where the two designs meet they agree… more telling than either result alone") and
    replaced with the mandated "two margins of the reform" framing (Task G);
    "the hospital-closure side" → "hospital closures".
  - method/setting/data: "do the work" → "supply the data"; "come off it" → "derive from
    it"; "go dark" → "cease reporting"; "by hand" → "manually".

## Item-J audit (both PDFs)

- Undefined references / citations: **0**. Stale `??`: **0** (main and appendix).
- Duplicate bib keys: **0**. TODO/FIXME/tool leakage: **0**.
- No bald "mortality does not rise"; no "net loss of care"; no unqualified "do not
  absorb" displacement claims. Sample names (F5, PNASH cycle-window, PNASH exact ±1,
  spec/psymax) consistent. Abstract claims (293/337, 69%, bounded null, SDID,
  portability) all supported in tables/appendix.
- Main-text floats: support-failure benchmark rows demoted to appendix (Task D). No
  other main table flagged for demotion.

## Page counts / build

- Main: **30 pp**. Online appendix: **16 pp**. Both compile exit 0, clean.

## Remaining risks (honest)

1. **Bounded null, not zero** — stated explicitly throughout; a referee may still want
   more power, but the paper does not overclaim.
2. **Outpatient (CAPS) substitution unobserved** — disclosed as a limitation; the
   positive destination of the lost volume is only partly identifiable from inpatient
   data. Cannot be closed without CAPS production data or record linkage.
3. **Timing diagnostics partly nonzero** — now disclosed in both the preview and the
   detail; identification leans on the full package (PNASH calendar, flat event-study
   pre-periods, strict window, SDID, contamination checks), not on the timing tests alone.
