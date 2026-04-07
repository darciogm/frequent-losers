# CADE cartel period audit (2026-04-07)

Hand-curated cartel periods in `12_build_cade_ground_truth.py` were audited
against public CADE sources for the 7 SP-relevant processes in Track A.
Three of the seven were over-broadcast by the original curation. The
corrections are listed below with the source citation used for each
period. Non-SP processes were not audited in this session and remain
at their original curated values.

## Summary of changes

| # | Processo | Sector | Old | New | Source |
|---|---|---|---|---|---|
| 1 | 08012.010022/2008-16 | merenda escolar SP | 2006-2010 | **2006-2013** | Agência Brasil 2021; CADE analyzed 2008-2013 docs |
| 2 | 08700.004617/2013-41 | trens/metrôs SP | 1998-2013 | **1999-2013** | CADE press release: "at least 10 years", 26 bids 1999-2013 |
| 3 | 08012.001273/2010-24 | aquecedores solares | 2009-2013 | **2009-2010** | CADE: two in-person auctions 2009 and 2010 |
| 4 | 08700.005876/2019-85 | transporte escolar Fernandópolis | 2017-2019 | **2019** | CADE: single 2019 Seduc-SP e-auction (IP coincidence evidence) |
| 5 | 08700.007278/2015-17 | cafeterias Infraero | 2010-2015 | **2014** | CADE: May-Nov 2014, six airports |
| 6 | 08700.005789/2015-02 | sacos de lixo SP MG PR MT MS | 2008-2014 | 2008-2014 ✓ | Op Colludium / MP Bauru |
| 7 | 08012.002222/2011-09 | medicamentos SP MG BA PE | 2007-2011 | 2007-2011 ✓ | CADE: hub-and-spoke, 2007-2011 |

Three cartels were corrected downward by a total of **10 cartel-years**
(aquecedores -3, cafeterias -5, transporte -2). One was corrected upward
by 3 years (merenda). Net: -7 cartel-years in the cleaner ground truth.

## Per-cartel detail

### 1. Merenda escolar SP (08012.010022/2008-16)

**Corrected period: 2006-2013 (was 2006-2010)**

The case originated from Pregão 73/2006 conducted by the Secretaria
Municipal de Gestão between 2006 and 2007. During the investigation,
CADE analyzed more than 40,000 procurement documents from **2008 to
2013**, confirming geographic market division. The cartel divided
tenders for school meal supply across Campinas, Sorocaba, and Greater
São Paulo. Companies: SP Alimentação, Sistal, Geraldo J. Coan, Convida,
Nutriplus, Terra Azul. Condemned 2021. Fines R$ 340.8M.

**Evidence of extension through 2013:** investigation period explicitly
covered 2008-2013 documents, suggesting the cartel conduct continued
through that window. Original curation truncated at 2010 without
documentary basis.

Sources:
- Agência Brasil (2021-04): "Cade condena empresas por cartel na merenda escolar de São Paulo"
- gov.br/cade: press release on cartel condemnation

### 2. Trens e metrôs SP (08700.004617/2013-41)

**Corrected period: 1999-2013 (was 1998-2013)**

CADE condemnation found that 11 companies "mounted a national scheme
that lasted **at least 10 years**" affecting **26 bidding procedures
during the years 1999 to 2013**. States: SP, DF, MG, RS. Companies
divided the market and coordinated prices; losers were subcontracted
by winners. Condemned 2019. Fines R$ 535.11M.

**Evidence of start year:** CADE press release explicitly cites
1999 as the earliest bid affected. Original curation used 1998,
which was one year earlier than any confirmed evidence.

Sources:
- gov.br/cade: "Cade multa em R$ 535,1 milhões cartel de trens e metrôs"
- antigo.cade.gov.br: earlier investigation announcement

### 3. Aquecedores solares (08012.001273/2010-24)

**Corrected period: 2009-2010 (was 2009-2013)**

CADE condemned six companies for collusion in **two in-person bidding
processes conducted in 2009 and 2010** by the Companhia de Desenvolvimento
Habitacional e Urbano (CDHU) for low-income housing solar heaters.
Companies: Astéria, Tuma, Sol Tecnologia, Bosch Termotecnologia,
Enalter, Transsen. Condemned 2015. Fines R$ 21.4M. Notable precedent
for conviction based exclusively on indirect evidence.

**Evidence of narrower period:** CADE explicitly identifies the conduct
as affecting only the 2009 and 2010 auctions. Original curation extending
to 2013 lacked documentary basis.

Sources:
- gov.br/cade: "Cade condena cartel em licitações de aquecedores solares"
- Conjur (2022-11): "Justiça não vê provas de formação de cartel de aquecedores solares" (on subsequent judicial review)

### 4. Transporte escolar Fernandópolis (08700.005876/2019-85)

**Corrected period: 2019 (single year, was 2017-2019)**

CADE condemned Mayfran and New Hope for cartel formation in a
**single 2019 electronic tender** held by Seduc-SP for school
transportation services in the municipality of Fernandópolis, SP.
Evidence: coincidence of IP addresses between the two firms during
the bidding. Condemned February 2020.

**Evidence of single-year conduct:** CADE refers to one specific
2019 e-auction. Original curation of 2017-2019 had no basis.

Sources:
- gov.br/cade: "Empresas envolvidas em cartel em licitação de transporte escolar em município paulista são condenadas pelo Cade"
- Monitor Mercantil (2020): "Cade condena empresas envolvidas em licitação de transporte escolar"

### 5. Cafeterias Infraero (08700.007278/2015-17)

**Corrected period: 2014 (single year, was 2010-2015)**

CADE condemned five companies (Alimentare, Ventana, Confraria André,
Boa Viagem, Delícias da Vovó) and six individuals for cartel in
in-person Infraero tenders for cafeteria concessions. **The frauds
occurred between May and November 2014** at airports in Campo Grande,
São Paulo (Congonhas), Florianópolis, Maceió, Recife, and São José dos
Pinhais. Condemned 2022. Fines R$ 4.7M + five-year public-tender ban.

**Evidence of single-year conduct:** CADE explicitly dates the conduct
to May-November 2014. Original curation of 2010-2015 was five years
wider than evidence supports.

Sources:
- gov.br/cade: "Cade condena representado em processo de cartel em licitações de aeroportos"
- Conjur (2022-08): "Cade condena cafeterias por cartel em licitação da Infraero"
- CNN Brasil: "Cade condena empresas por formação de cartel de lanchonetes em 6 aeroportos"

### 6. Sacos de lixo — Op Colludium (08700.005789/2015-02) ✓

**Period confirmed: 2008-2014**

14 companies engaged in price-fixing, participation division, and cover
bidding from **2008 to 2014** across SP, MG, PR, MT, MS. Case originated
from Op Colludium by the Bauru MP. Condemned by CADE.

Sources:
- gov.br/cade: "Cade condena cartel em licitações públicas para aquisição de sacos de lixo"
- gov.br/cade (en): "CADE convicts cartel in procurements for bin bags"

### 7. Medicamentos SP MG BA PE (08012.002222/2011-09) ✓

**Period confirmed: 2007-2011**

Hub-and-spoke cartel in public drug procurement. Conduct "occurred at
least from **2007 to 2011**" in Minas Gerais, São Paulo, Bahia and
Pernambuco. Fines > R$ 45M (companies) + R$ 6M (individuals).

Sources:
- gov.br/cade: "Tribunal do Cade condena cartel no setor de medicamentos"
- Migalhas: "Cade condena cartel no setor de medicamentos em mais de R$ 50 milhões"

## Pending / not audited

The following six non-SP processes remain at their original curated
values and should be audited before the final paper version if Track A
is extended beyond SP:

- 08012.003931/2005-55 — ambulâncias SUS SES-SP (2004-2006)
- 08012.009732/2008-01 — unidades móveis saúde nacional (2005-2010)
- 08012.011853/2008-13 — coleta lixo RS Santa Rosa (2005-2009)
- 08012.008821/2008-22 — antirretrovirais nacional (2006-2008)
- 08012.005928/2003-12 — medicamentos genéricos / Merck (2000-2003)
- IT_DF — TI Brasília 4 empresas (2005-2008)
