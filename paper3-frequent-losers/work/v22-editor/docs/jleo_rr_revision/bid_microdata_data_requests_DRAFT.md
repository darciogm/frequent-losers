# Bid-Microdata Data Requests — DRAFTS for Author Review

**Status:** DRAFTS. Do not send as-is. Darcio reviews, finalizes salutation/email, and sends.

**Purpose:** Acquire the all-bidder (loser) proposal distribution for federal ComprasNet
Pregão eletrônico, which we do **not** currently hold (we have participation + winner
data 2013–2019, but not the full classified-proposal distribution needed for an
Imhof-style screen comparison on federal data). The ~32,148 CADE-anchored tender-items
would suffice as a slice.

**This is the CLEAN (non-scraping) acquisition path** — R&R ammunition to strengthen the
JLEO revision, **not a submission blocker.** If none of these pan out, the paper stands on
BEC-SP + CADE.

**What we ideally need (any subset is useful):**
- Per-item final *classified proposals* of ALL bidders (proposal value + bidder CNPJ),
  federal Pregão eletrônico, any subset of 2009–2019.
- The ~32,148 CADE-anchored tender-items would be a sufficient slice.
- We reciprocate via co-citation, acknowledgement, and (where appropriate) shared cleaned outputs.

---

## Verification status (checked via web, 2026-06-06)

| Contact | Affiliation | Email | Status |
|---|---|---|---|
| **Dimitri Szerman** | Research Fellow, University of Mannheim (Dept. of Economics) | `szerman@uni-mannheim.de` | **CONFIRMED** — affiliation + email from his own Google Site / Google Scholar. (LinkedIn/secondary sources mention Amazon, PUC-Rio/CPI, UFF — treat as unconfirmed; Mannheim is the current verified academic line.) LSE PhD 2012 "Public Procurement Auctions in Brazil" CONFIRMED (etheses.lse.ac.uk/681). |
| **Rafael Mourão** | Author of GitHub `rafaelmourao/comprasnet`; scripts written for an IPEA project | **NOT FOUND** | Repo CONFIRMED: federal Pregão **2001–March 2015**; README explicitly offers data/access on request ("Feel free to contact me if you want more information or access to the data"). **No email in repo.** Reach via GitHub (open an issue / profile contact). IPEA affiliation is as-stated in the repo, not independently confirmed. |
| **PRWP 8828 team** | Alexandre Borges de Oliveira (World Bank); Abdoulaye Fabregas (World Bank); Mihály Fazekas (Central European University + Government Transparency Institute) | Corresponding: `aoliveira@worldbank.org` (from paper); Fazekas `FazekasM@ceu.edu` (CONFIRMED, CEU directory) | **CONFIRMED** — paper title page + SSRN 3376277. Note: third author is **Abdoulaye Fabregas**, not "a Fabregas"; no Fabregas email verified. Data was **provided by the Brazilian Ministry of Planning, Budget and Management** (Comprasnet transactional data 2015–2017, 112M item-obs). |

---

## DRAFT 1 — Dimitri Szerman (University of Mannheim) — EN

> **To:** szerman@uni-mannheim.de
> **Subject:** ComprasNet bid microdata (incl. losing proposals) — a data ask for a cartel-screening paper
>
> Dear Professor Szerman,
>
> I'm Darcio Genicolo-Martins (INSPER, with Paulo Furquim de Azevedo). We have a paper
> under review at JLEO that proposes "frequent losers" / loser-side concentration as a
> bid-rigging screen, validated on São Paulo state procurement (BEC) against CADE cartel
> convictions.
>
> For the revision we'd like to compare our screen against Imhof-style screens on *federal*
> Pregão eletrônico. We have federal participation and winner data (2013–2019), but not the
> all-bidder proposal distribution — i.e., the losing proposals — which your LSE thesis work
> ("Public Procurement Auctions in Brazil") collected directly from ComprasNet, including
> losing bids and timestamps.
>
> Would you be willing to share any documented sample of that scraped corpus, or the scraper
> code? Even a small slice of per-item classified proposals (value + bidder CNPJ) would let us
> run the comparison. We'd gladly co-cite and acknowledge your contribution.
>
> Happy to share our cleaned outputs in return. Thank you for considering this.
>
> Best regards,
> Darcio Genicolo-Martins
> INSPER, São Paulo

---

## DRAFT 2 — Rafael Mourão (GitHub `rafaelmourao/comprasnet`) — PT-BR

> **To:** [não verificado — contatar via GitHub: abrir issue em github.com/rafaelmourao/comprasnet ou pelo perfil]
> **Subject:** Pedido de dados do ComprasNet (propostas de todos os licitantes) — seu repositório
>
> Prezado Rafael,
>
> Sou Darcio Genicolo-Martins (INSPER, com Paulo Furquim de Azevedo). Temos um artigo em
> avaliação no JLEO que propõe os "frequent losers" / concentração no lado perdedor como um
> indicador (screen) para detecção de cartéis em licitações, validado na BEC-SP contra
> condenações do CADE.
>
> Vi no seu repositório `rafaelmourao/comprasnet` (Pregão eletrônico federal, 2001–mar/2015)
> que você se dispõe a compartilhar os dados mediante solicitação — por isso este contato.
>
> Para a revisão, precisamos da distribuição completa de propostas, isto é, das propostas dos
> licitantes *perdedores*, que faltam na nossa base federal (temos participação + vencedor,
> 2013–2019). O que nos interessa: por item, as propostas classificadas de todos os
> licitantes (valor + CNPJ). Qualquer subconjunto já ajuda — os ~32.148 itens ancorados em
> casos do CADE seriam suficientes.
>
> Você teria como compartilhar uma amostra documentada ou os dados tratados? Retribuímos com
> co-citação, agradecimento e nossos outputs limpos.
>
> Obrigado desde já,
> Darcio Genicolo-Martins — INSPER

---

## DRAFT 3 — PRWP 8828 team (World Bank / CEU) — EN

> **To:** aoliveira@worldbank.org
> **Cc:** FazekasM@ceu.edu
> **Subject:** Federal ComprasNet bid data (2015–2017) from PRWP 8828 — research access query
>
> Dear Dr. Oliveira, Dr. Fabregas, and Prof. Fazekas,
>
> I'm Darcio Genicolo-Martins (INSPER, with Paulo Furquim de Azevedo). We have a paper under
> review at JLEO proposing "frequent losers" / loser-side concentration as a bid-rigging
> screen, validated on São Paulo state procurement against CADE convictions.
>
> Your paper "Auction Length and Prices: Evidence from Random Auction Closing in Brazil"
> (PRWP 8828) uses the complete federal Pregão dataset for 2015–2017 (112M bids), with the
> full proposal distribution including losing bids — exactly the layer we lack for a federal
> Imhof-style screen comparison.
>
> We understand the data was provided by the Ministry of Planning, Budget and Management and
> may be access-restricted. We'd be grateful for any of: (a) whether a research subset can be
> shared, (b) a documented sample, or (c) a contact path to the same ministry source.
>
> A single per-item slice (classified proposals: value + bidder CNPJ) would suffice; the
> ~32,148 CADE-anchored items alone would do. Happy to co-cite and acknowledge.
>
> Best regards,
> Darcio Genicolo-Martins — INSPER, São Paulo

---

*Drafted by mr-frequent (Claude Code), 2026-06-06. All names/affiliations/titles/venues
web-verified; emails verified except where flagged NOT FOUND above.*
