# 113 — Title / Subtitle Audit (final JLEO editorial pass)

**Date:** 2026-06-06
**Branch:** `rr_jleo_final_storytelling_compression_humanization`
**Decision:** **KEEP the title unchanged.** Recommend-only memo; no `.tex` edit made.

## Current title (verbatim, `sec_frontmatter_submission.tex:6`)

> **Cheap Signals, Costly Proof: The Reach and Limits of Award-Layer Screening in Cartel Enforcement**

## What the final story actually is

After the v22 hostile passes the paper resolved onto two load-bearing
contributions:

1. **Over-crediting characterization** — an award-layer signal that looks
   discriminating in-sample is over-credited; once opportunity exposure, frozen
   timing, and case composition are netted out, the honest reach is much
   narrower (label-blind E = 0.553; cobidders are EXPOSURE, target = 651 broad
   AL, never 193).
2. **Cost–recall governance** — the screen is governed not by a fixed cutoff
   but by a budget-dependent stopping rule; the operating point moves with the
   forensic budget. Cheap award-layer suspicion is decoupled from the costly,
   proof-producing bid layer.

The paper is explicitly **not** a cartel detector; it is an audit architecture
that disciplines a cheap signal before any costly recovery is triggered.

## Does the current title carry that story?

| Title element | Maps to story? | Verdict |
|---|---|---|
| "Cheap Signals, Costly Proof" | Cost–recall governance + the cheap/costly two-layer split | Strong. This is the spine of the final story and the Box 1 framing ("From Cheap Suspicion to Bid-Layer Follow-Up"). |
| "The Reach and Limits" | Over-crediting / honest-reach contribution; "Limits" front-pages the failures | Strong. Signals the deflationary, reach-bounded result rather than a performance claim. |
| "Award-Layer Screening" | The object: an award-layer signal, distinct from bid-layer proof | Accurate and specific. |
| "in Cartel Enforcement" | Domain | Fine. |

The title already encodes both pillars: the cheap/costly asymmetry (pillar 2)
and "Reach and Limits" (pillar 1). There is no missing concept.

## The "screening" vs "auditing" question

The concern: does "screening" read as too performance-driven (a tool that
*detects*), undercutting the deflationary, audit-architecture framing?

Assessment — **"screening" is fine and should stay:**

- "Screening" is the literature's term of art (Imhof et al.; Huber & Imhof;
  Wallimann et al.). Using it places the paper correctly in its lineage and is
  what a JLEO referee/editor in this area expects to see. Swapping to
  "auditing" would read as idiosyncratic relabeling.
- The performance-inflation worry is already neutralized inside the title by
  **"The Reach and Limits of …"** — that clause is the deflationary move. A
  reader sees "screening" immediately bounded by "reach and limits," not
  oversold.
- The word "Screening" is paired with "Award-Layer," which is descriptive of
  the *object*, not a claim about how well it performs. The performance claim is
  governed elsewhere by "Limits."
- "Auditing" is reserved, deliberately, for the *internal* device (Box 1 = the
  audit, "audit architecture," "audit of the audit"). Keeping "screening" in
  the title and "audit" in the body preserves a useful two-level vocabulary:
  the object is a screen; the contribution is the audit of that screen. Folding
  both into one word in the title would flatten that distinction.

## Continuity cost of changing

The title has been stable across v18→v20→v22, is wired into the site
(`/research/frequent-losers`), the submission package, the cover letter framing,
and the editorial-express materials. Changing the subtitle now buys no
conceptual gain (the story is already carried) and incurs cross-artifact
re-sync cost during the final gate. The default — keep for continuity — applies
with no counterweight.

## Recommendation

**KEEP** the title exactly as is. The gain from any subtitle change is not
clear; the current title already foregrounds both the cost–recall governance
("Cheap Signals, Costly Proof") and the over-crediting / honest-reach result
("The Reach and Limits"), and "screening" is correctly bounded by "Limits" so
it does not over-credit. No `.tex` change made.
