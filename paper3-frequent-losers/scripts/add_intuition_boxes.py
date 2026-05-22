#!/usr/bin/env python3
"""Insert plain-language "Intuition" admonition boxes at the top of each AN page
and each hypothesis page. Intent: give the reader who doesn't know the paper a
2–4 sentence economic summary of what the page is showing.

Idempotent — skips files that already contain an Intuition box.
"""
import re
from pathlib import Path

BASE = Path("/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers/docs")

INTUITIONS = {
    # ───────────────────────────── AN pages ─────────────────────────────
    "an-001-zero-win-rank": (
        "Among Brazilian procurement bidders, roughly 16,800 firms never won "
        "a single tender between 2009 and 2019. The screen ranks these "
        "always-losers by how often they show up. The top ~2,700 (the "
        "\"frequent losers\") are firms that bid abnormally often without "
        "ever winning — a plausible behavioral footprint of cartel cover "
        "bidders, who manufacture the appearance of competition without "
        "intending to take the contract."
    ),
    "an-002-iqr-threshold": (
        "How does one decide where \"a few losses\" ends and \"frequent loser\" "
        "begins? The paper uses a textbook quantile rule (median + 1.5 × IQR) "
        "rather than picking a number arbitrarily. This page asks: would the "
        "result change if we'd picked a different reasonable cutoff? It "
        "wouldn't — the signal sits on a wide plateau, not at a fragile peak. "
        "The choice is auditable, not cherry-picked."
    ),
    "an-003-cade-bec-linkage": (
        "To test whether the screen works, we need a \"truth label\" of which "
        "firms were actually involved in cartels. CADE (Brazil's antitrust "
        "authority) has formally adjudicated 47 firms as direct cartel "
        "defendants in procurement cases. The paper's validation target is "
        "the broader set of 193 always-loser firms that bid alongside those "
        "defendants — the loser-side footprint of the adjudicated cartels."
    ),
    "an-004-cobidder-baseline": (
        "Do firms flagged by the screen actually cluster around the loser side "
        "of CADE-adjudicated cartels? Yes — the screen achieves discrimination "
        "AUC 0.924 against the cobidder set (where 0.5 is random guessing and "
        "1.0 is perfect). This is the headline baseline; the rest of the "
        "validation chain disciplines this number against placebos, leakage, "
        "and timing."
    ),
    "an-005-sham-fl-permutation": (
        "Could the headline result come from raw bidding volume alone — "
        "i.e., the screen just spots high-volume bidders, and those firms "
        "happen to overlap with cartels by chance? A formal placebo (2,000 "
        "random reassignments preserving each firm's bid count) tests this. "
        "The placebo cannot reproduce the observed concentration: the real "
        "AUC is 32 standard deviations above the placebo null. Volume alone "
        "is dead as an alternative explanation."
    ),
    "an-006-strict-prospective-holdout": (
        "In a real enforcement environment, the screen would have to be built "
        "before the relevant adjudications close. We retrain the screen using "
        "only 2009–2016 data and test against later-adjudicated cobidders. "
        "Discrimination drops from in-sample 0.93 to 0.77 — informative but "
        "lower, as expected when the screen is held to a real-time information "
        "set. The signal survives strict timing discipline."
    ),
    "an-007-auc-direct-cade": (
        "The screen is built to detect *cover bidders* (the loser-side roles in "
        "a cartel), not cartel ringleaders. So testing it against the 47 direct "
        "CADE defendants should give a random result — and it does (AUC ≈ 0.49). "
        "This is not a failure: it is the empirical signature that the screen "
        "is doing what it claims (loser-side ranking) and not pretending to "
        "identify cartel masterminds."
    ),
    "an-008-pbu-characterization": (
        "Inside the frequent-loser group, are cobidders distinguishable from "
        "other frequent losers, or do they look the same? Cobidders bid in "
        "twice as many tenders, cross twice as many unique winners, and "
        "concentrate in tighter product portfolios. The profile is what one "
        "would expect if cobidders are *deployed* against many tenders "
        "deliberately, rather than just bidding broadly by chance."
    ),
    "an-009-network-hhi": (
        "Cobidders concentrate in tighter product portfolios than other "
        "frequent losers, but the MARKETS where they appear are MORE "
        "competitive on the winner side. The pattern fits cover bidding: "
        "cobidders are deployed against a few focal product verticals, "
        "specifically in markets where winning looks contested — which is "
        "where simulated competition is most useful for the cartel."
    ),
    "an-010-imhof-full-pipeline": (
        "The standard cartel-screening tool in the literature is the "
        "Imhof–Wallimann pipeline, which uses seven features from each "
        "tender's full bid history (requires expensive bid microdata). We "
        "compare it head-to-head with our cheap award-layer screen: each "
        "alone gives AUC ~0.89–0.90. Combined, they reach 0.96. The two "
        "layers carry complementary, non-redundant information — not the "
        "same signal twice."
    ),
    "an-011-horse-race-continuous": (
        "The screen has a binary version (a firm is flagged if its bid count "
        "exceeds the cutoff) and a continuous version (log of bid count). "
        "The continuous version statistically dominates. The paper's "
        "interpretation: the continuous score is the empirical primitive; "
        "the binary cutoff is the simpler, deployable rule a regulator "
        "would actually use in the field."
    ),
    "an-012-operational-metrics": (
        "How well does the screen perform if a regulator uses it to draw up a "
        "ranked enforcement priority list? Out of the top 500 flagged firms, "
        "13% are cobidders — 11× the baseline rate. The screen meaningfully "
        "concentrates investigative attention. Caveat: these are in-sample "
        "numbers and inflated; the next page disciplines them with temporal "
        "holdout."
    ),
    "an-013-precision-at-k-audit": (
        "The in-sample precision numbers are inflated because the screen has "
        "full hindsight on the data it was built with. Under a strict "
        "train/test split (2009–2016 → 2017–2019), precision@500 drops from "
        "0.13 to 0.07 — retention of 53%. The honest operational number is "
        "about half the in-sample headline. The paper reports both columns "
        "transparently."
    ),
    "an-014-leakage-audit-d3": (
        "When the screen is built and validated on the same data, performance "
        "can be artificially inflated by structural data reuse ('leakage'). "
        "We re-estimate AUC under three increasingly strict regimes: raw "
        "item-level (0.99), out-of-fold by firm (0.89), and temporal holdout "
        "(0.86). The drop is real but bounded; the operational discriminating "
        "signal sits in the 0.86–0.89 band, well above random."
    ),
    "an-015-gate-d1": (
        "D1 is the first of four \"gate\" diagnostics that decided the paper's "
        "strategic framing in 2026. It harmonizes the same-sample comparison "
        "between continuous and binary versions of the screen on a single, "
        "consistent firm set. The continuous version dominates decisively, "
        "confirming the locked rule: continuous is the empirical primitive, "
        "binary is the deployable simplification."
    ),
    "an-016-gate-d2": (
        "D2 asks: does the screen perform better in Convite (sealed-bid, "
        "with a minimum-bidder rule) or Pregão (electronic auction, no such "
        "rule)? An institutional theory predicted Convite > Pregão. The data "
        "show the OPPOSITE (Pregão 0.95, Convite 0.82). D2 disqualified an "
        "alternative framing of the paper; the current framing treats this "
        "as scope information, not as institutional identification."
    ),
    "an-017-gate-d3": (
        "D3 asks: does the substantive thesis still hold if we drop the "
        "specific FL14 binary cutoff and use only the continuous score? Yes "
        "— every continuous specification is statistically significant and "
        "the modal asymmetry from D2 survives. The paper's claim does not "
        "depend on a particular cutoff choice."
    ),
    "an-018-gate-d4": (
        "Why is the screen blind to direct CADE defendants? D4 confirms the "
        "mechanism: only ~15% of direct defendants are always-losers, and "
        "their median win rate is 0.26 (vs 0.09 for cobidders). Direct "
        "defendants are structurally winner-heavy — that is what makes them "
        "ringleaders. A loser-side screen literally cannot cover them, by "
        "construction."
    ),
    "an-019-rdd-cap-price": (
        "Brazilian procurement has cap thresholds that determine which "
        "tendering modality applies. We use the cap as a regression "
        "discontinuity to ask how prices and frequent-loser presence change "
        "at the threshold. The simple RDD coefficient is +4–6% (a "
        "damages-like reading); under overlap discipline it flips to −10%. "
        "The sign reversal is the load-bearing piece for the scope-not-damages "
        "interpretation of the price evidence."
    ),
    "an-020-did-decreto-2018": (
        "In 2018 the procurement cap was raised from R$80K to R$176K. We "
        "use this policy change as a difference-in-differences experiment "
        "for the price effect. Both Callaway-Sant'Anna and stacked DiD "
        "estimators return null — no detectable shift in price-FL dynamics. "
        "Consistent with the scope-not-damages reading: a true damages "
        "parameter would interact with the cap change; the FL-margin "
        "coefficient does not."
    ),
    "an-021-first-time-fl-matching": (
        "Does becoming a frequent loser for the first time predict cobidder "
        "status? Unconditionally yes (+0.10, statistically significant). But "
        "the effect collapses to +0.06 (not significant) once we match on "
        "participation history via propensity scores. The temporal "
        "'first-time' margin doesn't survive volume matching. Reported "
        "transparently; demoted to appendix, not load-bearing."
    ),
    "an-022-falsification-pregao": (
        "Does the FL-price coefficient hold up modality by modality? Pregão "
        "(electronic auctions) shows a +9.6% price coefficient; Convite "
        "(sealed-bid) shows +3.9%. The Pregão effect is 2.45× larger than "
        "Convite — same direction, very different magnitudes. The asymmetry "
        "is scope information about where the FL-price relationship is "
        "concentrated."
    ),
    "an-023-theory-operationalization-audit": (
        "How much does the result depend on the specific FL14 cutoff? We "
        "compare it against FL10, FL20, the Tukey alternative, and "
        "percentile-based ranks. The continuous score dominates every "
        "binary variant. The paper's FL14 choice is auditable but not "
        "ontologically privileged — it is the operational implementation of "
        "an underlying continuous primitive (loser-side concentration)."
    ),
    "an-024-unified-mechanism": (
        "Where in the data does the FL-price association concentrate? A "
        "two-way grid (market concentration × cobidder-pair density) shows "
        "the LOW-LOW cell carries the largest mass. The paper's stance: this "
        "is descriptive heterogeneity, not a mechanistic cartel signature. "
        "The locked rule drops the cartel-signature framing — the pattern "
        "is *consistent with* cover bidding, not proof of it."
    ),
    "an-025-cutoff-sweep-robustness": (
        "If we sweep the cutoff from k = 2 through k = 100, how does "
        "discrimination change? AUC rises monotonically to a peak at k = 13 "
        "(0.92), then declines smoothly as the cutoff starts to exclude the "
        "cobidders themselves. The FL10–FL15 plateau is uniformly above 0.90. "
        "The paper's FL14 choice sits on a wide high plateau, not at a "
        "fragile peak."
    ),
    "an-026-subsample-robustness": (
        "Does the screen work equally well in firms that have a lot of bid "
        "microdata vs firms that have very little? AUC stays in the 0.89–0.96 "
        "band across full / data-rich / low-bid / high-bid subsamples. The "
        "screen does not depend on bid-microdata availability — important "
        "because the alternative bid-distribution screen DOES require expensive "
        "microdata to operate."
    ),
    "an-027-universe-anchored-stratum-scope": (
        "A systematic 8-row matrix varies the universe of firms ranked "
        "(always-losers vs all BEC firms) and the positive class (cobidders "
        "vs direct defendants). Row 4 is the strong result: raw participation "
        "count against direct CADE defendants on the full panel returns "
        "AUC 0.383 — BELOW random. The loser-side score doesn't just fail to "
        "identify winner-heavy defendants; it actively *repels* them. "
        "Structural scope discipline."
    ),
    "an-028-exposure-stratum-balance": (
        "Within the frequent-loser group, are cobidders just the firms that "
        "bid the most, or are they qualitatively different? Across 7 "
        "dimensions (tender count, unique winners crossed, repeat-buyer "
        "share, portfolio concentration, etc.), cobidders are statistically "
        "distinct from other FL firms with effect sizes Cohen's d 0.19–1.00. "
        "The distinctness is multi-dimensional, not just volume."
    ),
    "an-029-three-classifier-timing-battery": (
        "How does the screen perform if we make it INCREASINGLY harder to "
        "use any post-window information? We train the screen on only "
        "2009–2015 data (or 2009–2017) and test it against cobidders linked "
        "to CADE cases adjudicated AFTER 2019 — strictly out-of-time. The "
        "screen still achieves AUC 0.79–0.89 against this disjoint target. "
        "Strong evidence of genuine prospective generalization."
    ),
    "an-030-market-persistence": (
        "Are the firms in the 2017–2019 test window the same firms as in the "
        "2009–2016 training window? Only 8.7% of firms persist. Markets (PBU "
        "× product group) persist at 12.4%. Procuring buyers persist at 83.5%. "
        "The institutional environment is stable; the firm and market "
        "populations are essentially fresh. The temporal holdout is a "
        "genuine out-of-sample test, not a same-firm reshuffle."
    ),
    "an-031-bid-level-behavioral-profile": (
        "Beyond participation patterns, do cobidders also BID differently? "
        "Cobidders place bids that are closer to the winning bid (median gap "
        "0.58 vs 0.81 for non-cobidder FLs; effect size d = −0.28). They "
        "also show higher within-firm bid dispersion. The bid-level signature "
        "is consistent with credible cover bidding — submitting "
        "plausible-looking losing bids that don't win."
    ),
    "an-032-matched-heterogeneity-audit": (
        "The honest negative finding: most of the within-FL quadrant "
        "heterogeneity in the screen does NOT survive matching on "
        "participation history. The largest cell drops from a significant "
        "+0.09 to a non-significant +0.07 once we control for volume. The "
        "implication: within-FL cobidder distinctness is largely a volume "
        "effect. What survives matching is the bid-level signature documented "
        "in AN-031."
    ),
    "an-033-imhof-incremental-delong": (
        "How much information does the award-layer screen contribute BEYOND "
        "what the bid-distribution screen already captures? A formal DeLong "
        "test (paired AUC comparison) gives ΔAUC = +0.096 with "
        "p = 1.2 × 10⁻²⁶. The two layers are statistically distinct signals. "
        "The award layer is not redundant with bid moments."
    ),
    "an-034-sequential-gatekeeping-envelope": (
        "Opening full bid-level microdata is expensive. Can the cheap "
        "award-layer screen act as a gatekeeper that selects which firms "
        "enter the expensive forensic stage? Yes: a sequential rule "
        "(FL screen → Imhof on top 2,000) captures 74% of the joint-scoring "
        "true positives while requiring only 17% of the bid-microdata cost. "
        "The architecture preserves most of the signal at a fraction of "
        "the cost of evidence."
    ),
    "an-035-architecture-cost-of-evidence-matrix": (
        "The full grid of operational architectures (award-only, bid-only, "
        "joint scoring, sequential at three Stage-1 cutoffs) × six recall "
        "levels × two evaluation regimes (in-sample, temporal holdout). The "
        "surprise: in the operationally honest temporal-holdout regime, the "
        "sequential architecture BEATS joint scoring (114 true positives vs "
        "111) while using less than a quarter of the bid-microdata footprint."
    ),
    "an-036-cv-precision-stability": (
        "Are the precision numbers we report stable across different random "
        "splits of the data, or do they depend on the particular train/test "
        "partition? Cross-validation gives precision standard deviations in "
        "the range [0.001, 0.011] across k = 50–2,000. Tight enough that "
        "the operational claim is not an artifact of one particular split."
    ),
    "an-037-sign-reversal-decomposition": (
        "The price coefficient on frequent-loser presence is +0.064 in the "
        "naive baseline but flips to −0.097 once we restrict comparisons to "
        "cells where both treated and control items exist and reweight "
        "toward those cells. The reversal is not a sample-selection artifact "
        "(less than 1% of items are dropped). It is a *weighting* result. "
        "This is the central evidence for the scope-not-damages reading of "
        "price evidence: a true damages parameter wouldn't flip sign under "
        "reweighting."
    ),
    "an-038-negative-cell-segment-audit": (
        "Where in the data does the sign reversal actually happen? At the "
        "item-group level, most groups flip from positive baseline to "
        "negative under matched comparison. Item group 37 stays strongly "
        "negative across every specification (the cleanest structural "
        "negative). Item group 10 stays positive (the boundary of the scope "
        "reading). The cell-level heterogeneity is predictably structured, "
        "not random."
    ),

    # ──────────────────────────── Hypothesis pages ──────────────────────────
    "cobidder-concentration": (
        "Among always-loser firms in Brazilian procurement, the ones that "
        "bid most often (frequent losers) concentrate disproportionately "
        "near cartels formally adjudicated by Brazil's antitrust authority. "
        "The hypothesis is the paper's headline empirical claim. Using only "
        "award records — no expensive bid-level data — the screen recovers "
        "131 of 193 adjudicated cobidders. The economic logic: cartels need "
        "cover bidders to manufacture the appearance of competition, and "
        "those cover bidders leave a persistent footprint of zero-win "
        "participation."
    ),
    "direct-defendants-null": (
        "Direct CADE defendants in procurement cartels are typically the "
        "*winners* of the rotation, not the systematic losers. A loser-side "
        "screen — built on persistent zero-win participation — cannot rank "
        "winners, and the data confirm this (AUC ≈ 0.49, indistinguishable "
        "from random). The null is the predicted finding under the "
        "loser-side scope. Far from being a failure, the null defines what "
        "the screen *claims* to do (rank cover-bidders) and what it "
        "*doesn't* claim to do (identify ringleaders). This is the "
        "anti-claim that disciplines the rest of the paper."
    ),
    "exposure-discipline": (
        "The headline result might be an artifact — perhaps the screen just "
        "identifies firms that bid a lot, and high-volume firms happen to "
        "cluster around CADE cases by mechanical overlap (same products, "
        "buyers, periods). Several audits discipline this: a formal sham "
        "permutation rejects the volume-only null at 32 standard deviations, "
        "a leakage audit preserves AUC above 0.85, a universe-scope matrix "
        "rules out generic-detector readings. The observed signal is not "
        "explained by any within-data artifact family we can test."
    ),
    "timing-discipline": (
        "Could the screen perform well only because we built it with "
        "hindsight, using post-period information that wouldn't be available "
        "to a regulator in real time? We test this with progressively "
        "stricter timing rules: train on 2009–2015 data only; test against "
        "cobidders linked to cartels adjudicated AFTER 2019. The screen "
        "still achieves AUC 0.79–0.89 against this strictly disjoint target. "
        "Combined with the structural fact that 91% of test-window firms "
        "are not in the training pool, the timing discipline is about as "
        "well-supported as within-data evidence allows."
    ),
    "cobidder-profile-distinct": (
        "Within the frequent-loser group, are cobidders qualitatively "
        "different from other firms in the same group, or are they just the "
        "highest-volume members? Descriptively, cobidders are distinct "
        "across seven dimensions with large effect sizes. Causally, most of "
        "the within-FL heterogeneity is driven by volume itself — it doesn't "
        "survive matching. What survives is the bid-level behavioral "
        "signature (cobidders bid closer to winners). Honest mixed reading: "
        "the descriptive distinctness is robust; the causal/mechanistic "
        "story is narrower and concentrated in bid-level conduct."
    ),
    "award-bid-complementarity": (
        "There are two layers of procurement data: cheap administrative "
        "award records (who participated, who won) and expensive bid-level "
        "microdata (every bid amount in every tender). The hypothesis: they "
        "carry complementary, non-redundant information for cartel "
        "detection. The data strongly support this — joint scoring (using "
        "both layers) gains +0.10 AUC over either layer alone with "
        "p = 10⁻²⁶. The two layers are not measuring the same thing, and "
        "this matters for the architecture of enforcement."
    ),
    "gatekeeping-cost-of-evidence": (
        "In real enforcement, opening bid-level microdata for forensic "
        "analysis is expensive. The hypothesis: a cheap award-layer screen "
        "can act as a gatekeeper that decides which firms enter the "
        "expensive forensic stage, while preserving most of the cartel "
        "signal. The architecture works — 83% reduction in the bid-microdata "
        "pool while still recovering 131 of 193 adjudicated cobidders. The "
        "sequential gatekeeper even beats joint scoring under temporal "
        "holdout, the operationally honest regime. The cost-of-evidence "
        "argument is the paper's most distinctive institutional contribution."
    ),
    "price-scope-sign-reversal": (
        "The presence of frequent losers in a tender is associated with "
        "higher negotiated prices on average (+6.4% — a damages-like "
        "reading that a careless reader might interpret as the size of the "
        "cartel overcharge). But once we restrict comparisons to comparable "
        "cells under matched ATT weighting, the sign FLIPS to negative "
        "(−9.7%). The hypothesis is that this sign reversal is informative "
        "and disciplining: the price evidence is *scope* information about "
        "WHERE the loser-side ranking applies, not a damages estimate. The "
        "paper deliberately treats price evidence as secondary corroboration, "
        "and the sign reversal is what justifies that disciplined reading."
    ),
}


def insert_intuition(file: Path, intuition: str, page_type: str) -> bool:
    """Insert an Intuition admonition into the file.

    For AN pages, insert after the first H1 (# AN-NNN: Title).
    For hypothesis pages, insert before the > Evidence strength callout.
    Returns True if file was modified, False if skipped (already has one).
    """
    text = file.read_text()
    if 'abstract "Intuition' in text:
        return False  # already done

    # Format admonition with 4-space indentation per line
    indent = "    "
    body_lines = [indent + line.strip() for line in intuition.split("\n") if line.strip()]
    # Re-flow the single-paragraph intuition: keep as one paragraph
    body = indent + intuition.replace("\n", " ").strip()
    block = f'\n!!! abstract "Intuition (plain-language)"\n{body}\n'

    if page_type == "an":
        # Insert AFTER "# AN-NNN: Title" line + blank line
        pattern = re.compile(r'(\n# AN-\d+:[^\n]+\n)\n', flags=re.MULTILINE)
        new_text, count = pattern.subn(r'\1' + block + '\n', text, count=1)
    else:  # hypothesis
        # Insert BEFORE the "> **Evidence strength" callout
        pattern = re.compile(r'(\n> \*\*Evidence strength)', flags=re.MULTILINE)
        new_text, count = pattern.subn(block + r'\n\1', text, count=1)

    if count == 0:
        print(f"  WARN no insertion point in {file.name}")
        return False

    file.write_text(new_text)
    return True


def main():
    inserted = 0
    skipped = 0
    not_found = 0

    # AN pages
    for an_file in sorted((BASE / "analyses").glob("an-*.md")):
        key = an_file.stem  # e.g., "an-001-zero-win-rank"
        if key in INTUITIONS:
            if insert_intuition(an_file, INTUITIONS[key], "an"):
                print(f"  + {an_file.name}")
                inserted += 1
            else:
                print(f"  = {an_file.name} (skipped)")
                skipped += 1
        else:
            print(f"  ? {an_file.name} (no intuition defined)")
            not_found += 1

    # Hypothesis pages
    for h_file in sorted((BASE / "hypotheses").glob("*.md")):
        if h_file.name == "index.md":
            continue
        key = h_file.stem
        if key in INTUITIONS:
            if insert_intuition(h_file, INTUITIONS[key], "hypothesis"):
                print(f"  + {h_file.name}")
                inserted += 1
            else:
                print(f"  = {h_file.name} (skipped)")
                skipped += 1
        else:
            print(f"  ? {h_file.name} (no intuition defined)")
            not_found += 1

    print(f"\n  Summary: inserted={inserted}  skipped={skipped}  not_found={not_found}")


if __name__ == "__main__":
    main()
