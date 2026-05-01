% Cover letter — JLEO submission, Paper 3 v13-jle
% Date: [INSERT DATE OF SUBMISSION]
% Generated 2026-05-01 as part of Path A+ Pacote 2 (submission package).

[On INSPER letterhead]

[Date]

Editor
Journal of Law, Economics, and Organization
Editorial Office

Dear Editor,

We are pleased to submit our manuscript, **"Loser-Side Concentration as
a Low-Cost Bid-Rigging Risk Screen: Award-Record Evidence from
Brazilian Procurement,"** for consideration by *JLEO*.

## Why JLEO

The paper sits at the intersection of three areas where *JLEO*
publishes regularly:

1. **Empirical antitrust** in the procurement-screening tradition of
   Porter and Zona (1993), Bajari and Ye (2003), and Imhof (2019),
   where *JLEO* has published several recent contributions
   (Decarolis, Conley, Kawai, etc.).
2. **Institutional design of procurement law**, with explicit
   connection to Brazilian Lei~8.666/93 minimum-bidder rules
   (convite Article 22) and the analogous statutory framework in
   OECD jurisdictions.
3. **Administrative implementation** of detection screens in settings
   where bid microdata are unavailable but contract-award records
   are public — the binding constraint that Brazilian Tribunais de
   Contas, the Controladoria Geral da União, and CADE itself face.

## Three-sentence summary of the contribution

We document a participation-only construct, *loser-side concentration*,
and an operational implementation called *frequent losers*, that
discriminates environments enriched in adjudicated bid-rigging cartels
in São Paulo's electronic procurement platform (BEC, 2009–2019) at AUC
$0.91$ against $193$ CADE-defendant co-bidders, comparable to the full
Imhof–Wallimann bid-distribution pipeline (AUC $0.89$) at substantially
lower data cost. The screen runs on contract-award records alone:
winner identity, participant identity, item identifier — no bid
microdata, no enforcement labels, no structural assumptions. We are
explicit about scope: the construct does not flag the $47$ direct CADE
defendants in the universe of BEC firms above chance (AUC $0.49$),
because direct defendants are typically frequent winners, not losers,
and the construct is targeted at the loser-side of the bidding pool by
design.

## What we transparently disclose

The paper foregrounds, rather than hides, three findings that a
reasonable referee would otherwise raise:

- **Pre-registered gate diagnostics** (Section~\ref{sec:robustness}
  and Online Appendix Table~\ref{tab:gate_diagnostics}): we tested
  four diagnostics designed to support an alternative paper
  formulation (winner/loser-side institutional reading); three passed
  and one failed in the direction opposite to the institutional
  hypothesis. We disqualified that alternative formulation by our own
  pre-specified criterion and report the entire battery for
  transparency.
- **Anti-leakage audit of the item-level AUC** (Online Appendix
  Table~\ref{tab:leakage_audit}): the in-sample item-level AUC
  ($0.99$) is partially tautological by construction; under
  cross-validation at the cobidder-firm level the AUC drops to $0.89$,
  and under temporal holdout to $0.86$. We rely on the audited values
  in our claims.
- **Falsification on pregão-only subsample**
  (Table~\ref{tab:falsification_modal}): the construct discriminates
  more strongly in the modal regime *without* the minimum-bidder rule
  ($+9.6\%$ FL premium in pregão vs $+3.9\%$ in convite), confirming
  that the screen is not a regulatory artifact.

## Reproducibility

The full empirical pipeline runs end-to-end in approximately 14
minutes on a consumer-class machine via a single command (`bash
scripts/00_master_paper.sh`). Every numeric claim in the paper is
bound to a `\val<Macro>` LaTeX macro defined in `values.tex`, which
is auto-generated from canonical CSV outputs of the analysis scripts.
A provenance trail (`audit_paper_numbers.md`) maps each of the $406$
macros to its source script and CSV row. A verification suite
(`verify_paper.sh`) checks $15$ invariants on each compile. The
replication archive will be made public upon acceptance.

## Pre-registration of design choices

The four pre-registered gate diagnostics referenced above were
specified in writing before the diagnostics were run, and the verdict
logic ("$\gamma$++ alternative paper formulation activates only if 4/4
pass") was specified in advance. We treat this as design transparency,
not as inferential pre-registration in the AEA RCT registry sense.

## Authorship and conflicts

Both authors are at INSPER, São Paulo. Neither has financial,
professional, or personal interest in any party named in the paper or
in the CADE adjudications used as ground truth. The dataset is
derivative of Brazilian government open data (BEC contract awards) and
public CADE adjudication records.

## Suggested referees

We respectfully suggest the following potential referees, none of whom
have prior collaboration with the authors:

- **Francesco Decarolis** (Bocconi) — procurement, cartel detection
- **Ali Hortaçsu** (Chicago) — auction empirics, screening methods
- **David Imhof** (Fribourg) — bid-rigging detection methodology
- **Sylvain Chassang** (Princeton) — bid-rigging robustness, screens

We respectfully request that the following referees not be considered
due to ongoing collaboration or recent shared seminar engagement:

- (none)

The paper has not been previously submitted to any journal.

Thank you for your consideration.

Sincerely,

Darcio Genicolo-Martins (corresponding author)
INSPER, São Paulo
darciogm1@insper.edu.br

Paulo Furquim de Azevedo
INSPER, São Paulo
