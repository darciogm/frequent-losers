#!/usr/bin/env python3
"""Maintain the economic-intuition admonition box at the top of each AN page
(and each hypothesis page).

Each box gives a reader who doesn't know the paper the *economic* reasoning
behind the page — the incentive/equilibrium logic, the screening trade-off,
the scope-vs-damages reading — not just a description of what the test does.

Source of truth: the INTUITIONS dict below. AN pages are rewritten in place
(overwrite); hypothesis pages are inserted only if missing (idempotent), so a
run scoped to the AN pages never disturbs the hypothesis prose.

Numbers in each box are anchored to that page's own frontmatter headline.
Locked language: flags / screens / prioritizes / concentrates risk. Never
'detects cartelists', 'proves', 'outperforms decisively', or 'cartel signature'.
"""
import os
import re
from pathlib import Path

# Default to the paper-repo docs mirror; override with P3_DOCS_BASE to target the
# live site copy (darciogm.github.io/docs/research/frequent-losers). Either tree
# must contain analyses/ and hypotheses/ subdirs.
BASE = Path(os.environ.get(
    "P3_DOCS_BASE",
    "/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers/docs",
))

INTUITIONS = {
    # ───────────────────────────── AN pages ─────────────────────────────
    "an-001-zero-win-rank": """
        A cartel that rigs a tender still has to make the auction look
        competitive, or the buyer rejects it for too few bidders. The cheapest
        way to manufacture that appearance is to field firms that bid but are
        never meant to win. Over a decade those designated losers accumulate a
        distinctive footprint: many appearances, zero awards. Of the ~16,800
        firms that never won between 2009 and 2019, the IQR rule isolates the
        2,735 that bid far more often than a genuine also-ran ever would. The
        hypothesis is simple: for a cover bidder, frequent losing is not bad
        luck — it is the job.
    """,
    "an-002-iqr-threshold": """
        Where does "a few losses" end and "frequent loser" begin? Drawing the
        line by hand invites cherry-picking, so the paper fixes it with a
        mechanical quantile rule (median + 1.5 × IQR → FL14, 2,735 firms). The
        economic question is whether the signal is fragile at that line. It is
        not: discrimination sits at AUC 0.924 on a wide plateau, and the
        tighter Tukey cutoff (1,981 firms) actually loses power (0.834). The
        rule is defensible precisely because the result does not hinge on the
        exact threshold — the underlying object is continuous loser-side
        concentration, not a magic number.
    """,
    "an-003-cade-bec-linkage": """
        To grade a screen you need ground truth about who actually colluded.
        CADE, Brazil's antitrust authority, has adjudicated procurement
        cartels; matching defendants to BEC by CNPJ root yields 47 *direct*
        defendants. But direct defendants are the cartel's winners — the wrong
        target for a loser-side screen. The honest validation target is the 193
        *cobidders*: always-loser firms that repeatedly bid alongside
        adjudicated cartelists. These are the cover-bidding roles the screen is
        built to rank, and the linkage fixes them before any performance number
        is computed.
    """,
    "an-004-cobidder-baseline": """
        Do the firms the screen flags actually cluster on the loser side of
        adjudicated cartels? Yes — FL14 separates cobidders from other
        always-losers at AUC 0.924, and the continuous score reaches 0.939
        (0.5 is a coin flip). Economically, this says the loser-side
        concentration a cartel needs in order to fake competition is visible in
        cheap award records alone, with no bid microdata. This is the headline;
        everything after it is an attempt to break it with placebos, leakage
        audits, and timing discipline.
    """,
    "an-005-sham-fl-permutation": """
        The skeptic's first move: the screen is just a high-volume detector —
        firms that bid a lot mechanically bump into cartels by sharing
        products, buyers, and years. To isolate loser-side concentration from
        raw volume, a placebo reshuffles cobidder labels 2,000 times while
        holding each firm's bid count fixed. The reshuffled null sits at AUC
        0.500; the real signal (0.911) is 32 standard deviations away. Volume
        alone cannot manufacture the concentration — the footprint is about
        *losing*, not just *bidding*.
    """,
    "an-006-strict-prospective-holdout": """
        A screen is only useful if it would have flagged firms *before* the
        cases closed. We rebuild it on 2009–2016 data and test it on cobidders
        adjudicated in 2017–2019. Discrimination falls from in-sample 0.924 to
        0.767 — the honest cost of using a real-time information set instead of
        hindsight. Lower, but well above random: the loser-side footprint forms
        early enough to carry operational value for a regulator, not merely
        retrospective fit.
    """,
    "an-007-auc-direct-cade": """
        The most important number in the paper is a near-coin-flip. The screen
        ranks loser-side roles, and a cartel's ringleaders are its *winners* —
        they capture the rents by taking the rotated contracts. So tested
        against the 47 direct CADE defendants the screen scores AUC 0.491,
        indistinguishable from random. This is not a failure to hide; it is the
        design made visible. A tool claiming to flag both cover bidders and
        ringleaders would be overclaiming, and this null is what disciplines
        every other claim in the paper.
    """,
    "an-008-pbu-characterization": """
        If cobidders are deployed as cartel cover, they should look
        operationally busier than ordinary frequent losers. They do: inside the
        FL14 stratum, cobidders bid in ~2× as many tenders (136.5 vs 76.7) and
        brush past ~2× as many distinct winners (24.8 vs 13.5), at large effect
        sizes (Cohen's d ≈ 0.7–1.0). The profile fits firms *assigned* to
        populate many auctions rather than firms that happen to bid broadly.
        Whether this survives once sheer volume is netted out is the question
        AN-041 confronts.
    """,
    "an-009-network-hhi": """
        Two facts that look contradictory until you think like a cartel:
        cobidders specialize in tighter product portfolios (HHI 0.380 vs
        0.288), yet the markets where they appear are *more* contestable on the
        winner side (HHI 0.178 vs 0.303). Cover bidding is most useful exactly
        where winning looks competitive — a lone-bidder auction fools no one.
        So a cartel concentrates its designated losers in a few focal verticals
        and deploys them where simulated rivalry buys the most cover.
    """,
    "an-010-imhof-full-pipeline": """
        The literature's workhorse screen (Imhof–Wallimann) reads seven moments
        off the full bid distribution — powerful, but it needs expensive bid
        microdata. The cheap award-layer FL screen uses only who participated
        and lost. Each alone lands near AUC 0.89–0.90; stacked, they reach
        0.955. The economically important word is *complementarity*, not
        dominance: the two layers observe collusion at different evidentiary
        stages, so combining them adds genuine information rather than counting
        the same signal twice.
    """,
    "an-011-horse-race-continuous": """
        The screen comes in two forms — a binary flag (bid count above the
        cutoff) and the continuous log of bid count. The continuous score
        carries strictly more information and statistically dominates the
        binary (0.939 vs 0.924; DeLong p ≈ 10⁻⁵). The reading: the empirical
        primitive is loss *intensity*, a continuous quantity; FL14 is just the
        auditable on/off rule a regulator can defend in the field. The binary
        is for deployment, the continuous is for the underlying truth.
    """,
    "an-012-operational-metrics": """
        Turn the screen into a regulator's priority list: of the top 500
        flagged firms, 13% are cobidders — an 11.5× lift over the base rate —
        and the FL14 cutoff alone shrinks the expensive bid-microdata pool by
        ~83%. That is real concentration of scarce investigative attention. But
        these are *in-sample* numbers with full hindsight, so they flatter the
        tool; AN-013 re-runs them under a real-time split before any
        operational claim is allowed to stand.
    """,
    "an-013-precision-at-k-audit": """
        In-sample precision is inflated because the screen has already seen the
        data it is graded on. Under an honest train-on-past, test-on-future
        split, precision@500 falls from 0.132 to 0.070 (53% retained) and lift
        from 11.5× to 6.1×. The honest operational number is about half the
        headline — and the paper reports both columns side by side, resting its
        claims on the lower one. Roughly half the in-sample ranking power came
        from cases already under investigation when the data were generated.
    """,
    "an-014-leakage-audit-d3": """
        When a screen is built and scored on the same items, structural reuse
        can inflate performance ("leakage"). We tighten the evaluation in three
        steps: raw item-level (0.995), out-of-fold by firm (0.891), temporal
        holdout (0.864). The drop is real but bounded — the honest
        discriminating signal lives in the 0.86–0.89 band, comfortably above
        random. The tell that it is genuine: against direct defendants the AUC
        stays ~0.51 under *every* regime, so the screen isn't memorizing
        identities, it is ranking loser-side behavior.
    """,
    "an-015-gate-d1": """
        D1 is the first of four 2026 "gate" diagnostics that decided the
        paper's framing. On a single harmonized firm set it pits the continuous
        score against the binary FL14 head to head. The continuous version
        dominates (0.939 vs 0.924; DeLong p ≈ 10⁻⁵) and the price coefficients
        agree in sign. The economic payoff: it confirms that loss intensity —
        not a particular cutoff — is the primitive, locking the rule that the
        binary is a deployable simplification of a continuous signal.
    """,
    "an-016-gate-d2": """
        D2 asks where the screen bites harder: Convite (sealed-bid, with a
        minimum-bidder rule) or Pregão (open electronic auction). A tempting
        institutional theory predicted Convite — the minimum-bidder rule should
        force cartels to field *more* cover bidders. The data say the opposite
        (continuous AUC Pregão 0.95 vs Convite 0.82), which killed an
        alternative framing of the paper. The disciplined reading: this is
        *scope* information about where the footprint is strongest, not evidence
        that an institutional rule identifies the mechanism.
    """,
    "an-017-gate-d3": """
        D3 stress-tests whether the thesis depends on the FL14 cutoff at all.
        Throw the binary away and use only the continuous score: every
        specification stays significant (p < 0.001) and the modality asymmetry
        from D2 survives. So loser-side concentration is a property of the data,
        not an artifact of one threshold. The eye-popping in-sample item-level
        AUC (0.995) is held back for the leakage audit (AN-014), which is where
        the honest 0.86–0.89 number lives.
    """,
    "an-018-gate-d4": """
        Why is the screen blind to ringleaders? D4 measures it directly: only
        ~15% of direct CADE defendants are always-losers, and their median win
        rate (0.261) is triple the cobidders' (0.086). Ringleaders are
        winner-heavy *by construction* — capturing contracts is the whole point
        of running the cartel. A screen built on persistent losing therefore
        cannot cover them, and shouldn't be asked to. This is the mechanism
        behind the AN-007 null.
    """,
    "an-019-rdd-cap-price": """
        Brazil's procurement caps decide which tendering modality applies, so a
        cap is a natural discontinuity for prices. Naively, prices jump +4–6%
        where frequent losers appear — which a careless reader takes as the
        cartel overcharge. But once comparisons are restricted to genuinely
        comparable cells (overlap ATT), the sign flips to −10%. A true damages
        parameter would not flip under reweighting; this reversal is the
        load-bearing reason the paper reads price evidence as *scope*, not
        damages.
    """,
    "an-020-did-decreto-2018": """
        If the FL-price gap were a damages estimate, a big shock to the caps
        should move it. In 2018 the Convite cap jumped from R$80K to R$176K.
        Two staggered-DiD estimators (Callaway–Sant'Anna and stacked) both
        return a precise null around the reform. The non-reaction is consistent
        with the scope reading: the price gap is not a structural overcharge
        that should respond to the cap — it is a composition feature of where
        frequent losers operate.
    """,
    "an-021-first-time-fl-matching": """
        Does *becoming* a frequent loser for the first time predict cobidder
        status — a quasi-dynamic signal? Unconditionally yes (+0.10). But the
        moment you match firms on participation history with propensity scores,
        the effect fades to +0.06 and loses significance (p = 0.31). Honest
        verdict: the "first-time" timing margin is mostly a volume story, not an
        independent signal. The paper reports it transparently and demotes it to
        the appendix rather than leaning on it.
    """,
    "an-022-falsification-pregao": """
        Does the FL-price relationship hold across modalities, and is it the
        same size? Same direction, very different magnitude: binary FL raises
        prices +9.6% in Pregão vs +3.9% in Convite (2.45× larger), and the
        joint specification flips the binary sign altogether. The magnitude
        asymmetry is again *scope* — it tells you where the FL-price
        association concentrates — not a clean modality-specific damages
        estimate you could bank.
    """,
    "an-023-theory-operationalization-audit": """
        This page audits the bridge between concept and code: "loser-side
        concentration" (the theory) is operationalized as FL14 (the rule). Is
        FL14 special? No — the continuous score beats every binary version
        (FL10, FL20, Tukey, percentile ranks; 0.939 vs 0.924 and below). The
        point is deliberately deflationary: FL14 is the auditable, deployable
        layer, but it is not ontologically privileged. The economic object is
        continuous concentration; the cutoff is an engineering choice you can
        defend without pretending it is a law of nature.
    """,
    "an-024-unified-mechanism": """
        Where does the FL-price association live across a market-concentration
        × pair-density grid? The biggest mass sits in the Low-HHI × Low-pairs
        cell (+9.98), and the sign even flips in a high-density cell (−7.92).
        The earlier temptation was to read this as a cartel signature. The
        locked stance refuses that: it is descriptive heterogeneity *consistent
        with* cover bidding, not proof of a mechanism. Calling a pattern a
        signature is exactly the overclaim the paper is built to avoid.
    """,
    "an-025-cutoff-sweep-robustness": """
        Sweep the cutoff from FL2 to FL100 and watch discrimination. It traces
        a clean inverted-U: rising to a peak around FL13 (0.924), then sliding
        as the cutoff gets so high it starts excluding the cobidders
        themselves. The FL10–FL15 band all clears 0.90. Economically this is
        the reassuring picture — the signal lives on a broad plateau, so FL14
        is a point on a hill, not a needle balanced on a spike.
    """,
    "an-026-subsample-robustness": """
        Does the result only work for firms with rich bid histories? If so it
        would inherit the data dependence of the expensive screens it claims to
        replace. It doesn't: FL14 AUC stays in a tight band (0.887–0.912)
        across data-rich, low-bid, and high-bid subsamples. That
        data-independence is the whole operational selling point — the
        award-layer screen runs on cheap administrative records whether or not
        bid microdata exists.
    """,
    "an-027-universe-anchored-stratum-scope": """
        An eight-cell matrix varies *who* gets ranked (always-losers vs all BEC
        firms) and *what* counts as a hit (cobidders vs direct defendants). The
        disciplining row: ranking by raw participation against direct
        defendants on the full panel gives AUC 0.383 — below random. The
        loser-side score doesn't merely miss winner-heavy ringleaders, it
        actively *repels* them. That is exactly the behavior a scope-honest
        screen should show, and it rules out a "generic detector" reading.
    """,
    "an-028-exposure-stratum-balance": """
        Are cobidders just the highest-volume frequent losers wearing a
        different label? Across seven dimensions — tenders, unique winners
        crossed, repeat-buyer share, pair density, CADE-facing share, portfolio
        HHI, number of item groups — they separate from other FLs at effect
        sizes Cohen's d 0.19–1.00. The distinctness is multi-dimensional, which
        matters: if it were one-dimensional (just volume) the screen would
        carry no information beyond a bid counter. AN-041 then asks which
        dimensions survive once volume is matched away.
    """,
    "an-029-three-classifier-timing-battery": """
        The toughest timing test in the paper. Train the screen on only
        2009–2015 (or 2009–2017) and grade it against cobidders whose cartels
        were adjudicated *after 2019* — a target the training data could not
        have peeked at. It still lands AUC 0.79–0.89 across all six (window ×
        target) combinations. Genuine prospective generalization: the
        loser-side footprint is informative about cartels the screen had no way
        of knowing about when it was built.
    """,
    "an-030-market-persistence": """
        Is the temporal holdout a real out-of-sample test or a same-firms
        reshuffle? Mostly fresh: only 8.7% of firms and 12.4% of markets carry
        over from the early to the late panel, while 83.5% of *buyers* persist.
        So the institutions are stable but the firms and markets being scored
        are largely new. That asymmetry is what makes the prospective AUC
        credible — the screen generalizes to new players inside a stable
        institutional environment rather than re-recognizing old ones.
    """,
    "an-031-bid-level-behavioral-profile": """
        Beyond *how often* they bid, do cobidders *bid differently*? Yes, in a
        way cover bidding predicts: their bids sit closer to the winning amount
        (median gap 0.58 vs 0.81; d = −0.28) with somewhat more dispersion. A
        credible cover bid has to look like a real attempt — close enough to be
        plausible, deliberately short of winning. The signal lives at the bid
        level, not just participation counts, though whether *this* survives
        volume matching is settled in AN-041/042.
    """,
    "an-032-matched-heterogeneity-audit": """
        An honest negative. The eye-catching cell-level heterogeneity in the
        cobidder profile (e.g. Low-HHI × Low-pairs +0.09) mostly evaporates once
        firms are matched on participation volume (→ +0.07, not significant).
        Translation: much of what looked like a structured "cartel geography"
        was really just volume showing up in different cells. What does survive
        matching is the bid-level conduct (AN-031), so the paper keeps the
        conduct claim and drops the cell-geography claim.
    """,
    "an-033-imhof-incremental-delong": """
        How much does the cheap award layer add *on top of* the expensive
        bid-distribution screen? A formal DeLong test answers: +0.096 AUC,
        p ≈ 10⁻²⁶ — the two are statistically distinct signals, not the same
        information measured twice. Strikingly, FL alone even beats Imhof alone
        on the same sample (+0.035, p = 0.014). The economic implication is an
        architecture one: spend on bid microdata only after a near-free award
        screen has already done its share of the work.
    """,
    "an-034-sequential-gatekeeping-envelope": """
        Opening full bid-level microdata is the expensive forensic step. Can a
        near-free award screen act as the gatekeeper that decides which firms
        are worth that cost? Yes: an FL → Imhof pipeline keeping the top 2,000
        firms recovers 74% of the true positives the full joint model finds,
        while pulling 83% fewer bid records into forensic analysis. This is the
        paper's core cost-of-evidence argument — most of the signal at a
        fraction of the evidentiary bill.
    """,
    "an-035-architecture-cost-of-evidence-matrix": """
        The full operations grid: four sequencing rules × six recall targets ×
        two evaluation regimes. The result that matters is in the *honest*
        temporal-holdout regime, where the cheap sequential gatekeeper actually
        edges out full joint scoring (114 vs 111 true positives) using under a
        quarter of the bid-microdata footprint. Where hindsight is removed,
        paying for less evidence is not just cheaper — it is at least as good.
        That inverts the usual "more data is better" instinct for exactly the
        reason that matters to a budget-constrained regulator.
    """,
    "an-036-cv-precision-stability": """
        Are the precision numbers a fluke of one lucky train/test split?
        Cross-validation says no: precision@k standard deviations are tight
        (0.004–0.011 across k = 50–2,000, coefficients of variation under 25%).
        The operational claim — that the ranked list concentrates investigative
        value — is stable across resamples, not an artifact of one partition. A
        regulator drawing a priority list would get materially the same list
        each time.
    """,
    "an-037-sign-reversal-decomposition": """
        The single most load-bearing decomposition. The FL-price coefficient is
        +0.064 in the naive baseline but flips to −0.097 once comparisons are
        confined to cells holding both treated and control items and reweighted
        toward them (ATT). Less than 1% of items are dropped, so this is a
        *weighting* result, not sample selection — and within those cells the
        negative holds across both modalities and three of four value quartiles.
        A genuine damages parameter cannot flip sign under reweighting; this is
        the empirical core of the scope-not-damages reading.
    """,
    "an-038-negative-cell-segment-audit": """
        Where exactly does the sign reversal happen? Group by group: most item
        groups flip from positive baseline to negative under ATT (e.g. group
        13: +0.255 → −0.129). One group (37) stays robustly negative; one (10)
        stays positive, marking the boundary of the scope reading. The
        heterogeneity is structured, not random noise — predominantly negative
        under proper comparison — which is what you'd expect if the positive
        baseline was a composition artifact rather than a price effect.
    """,
    "an-039-selection-mechanism-test": """
        First half of the explanation for the sign flip: *selection*. If
        cartels with cover bidders deliberately operate where the underlying
        product is structurally expensive (richer rents to capture), the naive
        positive coefficient is just sorting, not a price effect. The test looks
        only at NON-treated items: their prices climb monotonically with a
        cell's FL-share, and after full controls FL-share still predicts higher
        non-treated prices (+3.55). Cartels fish where the fish are expensive —
        that alone produces a positive raw correlation with no overcharge.
    """,
    "an-040-within-cell-mechanism-test": """
        Second half: the *mechanism*. Within a comparable cell, FL presence
        brings ~67% more bidders into the tender and pulls the winning bid ~5%
        closer to the reference price — and that price effect vanishes once you
        control for the number of bidders. So the channel is bidder inflation:
        cover bidding manufactures apparent competition, which mechanically
        tightens the winning bid. The two forces compete — selection dominates
        in sparse tenders (FL items look pricier), the mechanism dominates in
        dense ones (FL items look cheaper) — and together they explain why the
        raw sign and the within-cell sign disagree.
    """,
    "an-041-volume-matched-cobidder-audit": """
        The hardest skeptical test of the profile: pair each cobidder with a
        non-cobidder frequent loser that bids in the *same* number of tenders,
        then re-measure the gaps. Most distinctness survives and some grows —
        product specialization and bidding-close-to-winner strengthen once
        volume is equalized, meaning volume had been *masking* them. One signal
        dies honestly: the elevated bid dispersion of AN-031 turns out to be a
        pure volume artifact. The cobidder type is real, but it is about *what
        and how they bid*, not merely *how much*.
    """,
    "an-042-volume-matched-timing-audit": """
        AN-041 left the bid-conduct case resting on a single channel (closeness
        to the winner). A one-channel story is thin, so this page hunts for a
        second: do cobidders bid on a different *clock* — revising less, spacing
        bids out, finishing early? Holding volume fixed, the answer is no —
        every timing dimension is statistically indistinguishable, the two
        largest effects merely tail-driven. A documented null: the cobidder
        conduct signature is genuinely single-channel, and the paper says so
        rather than dressing a noisy timing difference up as a second one.
    """,

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

# Pages we rewrite in place vs only fill if missing.
AN_RE = re.compile(r"^an-\d+")
BOX_RE = re.compile(
    r'\n*!!! abstract "Intuition[^\n]*"\n(?:[ \t]+[^\n]*\n)+\n*',
    flags=re.MULTILINE,
)


def build_block(intuition: str) -> str:
    """One 4-space-indented paragraph admonition, whitespace normalized."""
    body = "    " + " ".join(intuition.split())
    return f'\n!!! abstract "Intuition (plain-language)"\n{body}\n'


def insert_intuition(file: Path, intuition: str, page_type: str, overwrite: bool) -> str:
    """Insert (or replace) an Intuition admonition. Returns 'inserted',
    'replaced', 'skipped', or 'no-anchor'."""
    text = file.read_text()
    had_box = 'abstract "Intuition' in text
    if had_box and not overwrite:
        return "skipped"
    if had_box:
        text = BOX_RE.sub("\n\n", text, count=1)

    block = build_block(intuition)
    if page_type == "an":
        # Insert AFTER "# AN-NNN: Title" line + blank line.
        pattern = re.compile(r'(\n# AN-\d+:[^\n]+\n)\n+', flags=re.MULTILINE)
        new_text, count = pattern.subn(r'\1' + block + '\n', text, count=1)
    else:  # hypothesis
        pattern = re.compile(r'(\n> \*\*Evidence strength)', flags=re.MULTILINE)
        new_text, count = pattern.subn(block + r'\n\1', text, count=1)

    if count == 0:
        print(f"  WARN no insertion point in {file.name}")
        return "no-anchor"

    # Never leave runs of 3+ blank lines behind.
    new_text = re.sub(r'\n{3,}', '\n\n', new_text)
    file.write_text(new_text)
    return "replaced" if had_box else "inserted"


def main():
    counts = {"inserted": 0, "replaced": 0, "skipped": 0, "no-anchor": 0, "no-def": 0}

    # AN pages — rewrite in place (the box is the maintained artifact here).
    for an_file in sorted((BASE / "analyses").glob("an-*.md")):
        key = an_file.stem
        if key in INTUITIONS:
            res = insert_intuition(an_file, INTUITIONS[key], "an", overwrite=True)
            counts[res] += 1
            print(f"  [{res:8}] {an_file.name}")
        else:
            counts["no-def"] += 1
            print(f"  [no-def  ] {an_file.name}")

    # Hypothesis pages — fill only if missing (preserve hand-tuned prose).
    for h_file in sorted((BASE / "hypotheses").glob("*.md")):
        if h_file.name == "index.md":
            continue
        key = h_file.stem
        if key in INTUITIONS:
            res = insert_intuition(h_file, INTUITIONS[key], "hypothesis", overwrite=False)
            counts[res] += 1
            print(f"  [{res:8}] {h_file.name}")
        else:
            counts["no-def"] += 1
            print(f"  [no-def  ] {h_file.name}")

    print(f"\n  Summary: {counts}")


if __name__ == "__main__":
    main()
