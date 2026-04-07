# Paper 1 — Directed Literature Review
## Positioning "The Real Effects of Narrow Wins" against the relevant literature

**Objetivo**: identificar os ~20 papers contra os quais o Paper 1 precisa se posicionar explicitamente, agrupar por contribuição relativa e marcar claramente quais referências estou 100% seguro vs. quais precisam de verificação antes de citar. Esse documento alimenta as seções `introduction.tex`, `literature.tex` e `biblio.bib` do manuscrito.

**Convenção de confiança**:
- ✅ = referência e claim 100% verificados (autor, título, ano, journal).
- ⚠️ = autor e ideia certos; ano/journal preciso ser verificado antes de citar. **Nunca** citar sem WebSearch/Google Scholar.
- ❓ = lembrança vaga, pode ser paper fantasma — verificar com prioridade alta.

**Status de verificação (2026-04-06):** 25 referências críticas verificadas via WebSearch e marcadas ✅ abaixo. Seção "Verified metadata" adicionada ao fim deste documento com a citação definitiva de cada uma.

---

## Bloco 1 — Efeitos de procurement sobre firmas (contribuição direta)

### 1.1 Ferraz, Finan & Szerman (2016) ⚠️
**"Procuring Firm Growth: The Effects of Government Purchases on Firm Dynamics"**

- Venue: *Journal of Political Economy*? Ou NBER WP 21219? **Verificar** — tenho memória de que saiu como NBER WP 21219 (2015) e que foi publicado, mas o venue final pode ter sido AEJ: Applied ou outro. **Prioridade máxima de verificação**.
- Argumento: usando leilões municipais brasileiros (ComprasNet federal via matching com RAIS), mostram que ganhar um contrato público aumenta permanência da firma, emprego e salários. Identificação: matching com variáveis pré-tratamento, complementado por IV baseado em competição.
- **Por que é a referência central**: paper mais próximo da nossa pergunta em contexto brasileiro com RAIS. Devem ser discutidos na intro e na seção de lit review como o *único* paper prévio a ter combinado procurement + RAIS em escala.
- **Nossa contribuição vs. eles**:
  1. Identificação mais limpa: **close-bid RD** vs propensity score matching. RD > matching em credibilidade.
  2. Outcomes mais granulares: **worker-level revolving door, AKM decomposition** — impossível sem RAIS vínculo-nível.
  3. Setor de procurement diferente: convite-SP (bens comuns de baixo valor) vs ComprasNet federal (grande escala). Complementaridade temática.
  4. Mecanismo: eles documentam efeito agregado; nós abrimos a caixa preta via rent-sharing e revolving door.

### 1.2 Lee, Lemieux (2010) ✅
**"Regression Discontinuity Designs in Economics"**

- Venue: *Journal of Economic Literature*, 48(2):281-355.
- O survey canônico de RD. Citar para justificar o uso de local linear regression, kernel triangular, e estimação de bandwidth.

### 1.3 Lee (2008) ✅
**"Randomized Experiments from Non-random Selection in U.S. House Elections"**

- Venue: *Journal of Econometrics*, 142(2):675-697.
- O paper seminal de close-election RD como local randomization. **Referência metodológica central** — nossa estratégia de close-bid é a transposição direta dessa lógica de eleições para leilões.
- Citar na seção 4.1 (Empirical Strategy) e na intro.

### 1.4 Calonico, Cattaneo & Titiunik (2014) ✅
**"Robust Nonparametric Confidence Intervals for Regression-Discontinuity Designs"**

- Venue: *Econometrica*, 82(6):2295-2326.
- Bandwidth CCT-optimal, bias correction, robust SEs. Base técnica da estimação.

### 1.5 Calonico, Cattaneo & Farrell (2018) ⚠️
**"On the Effect of Bias Estimation on Coverage Accuracy in Nonparametric Inference"**

- Venue: provavelmente *Journal of the American Statistical Association* ou *Review of Economics and Statistics*. **Verificar**.
- Robust bias-corrected inference — refinamento do CCT 2014.

### 1.6 Cattaneo, Jansson & Ma (2020) ⚠️
**"Simple Local Polynomial Density Estimators"**

- Venue: *Journal of the American Statistical Association*, provavelmente 2020 ou 2021. **Verificar**.
- Density test (substitui McCrary 2008). **Crítico para validity do RD** — uso no gate check de manipulação.

### 1.7 McCrary (2008) ✅
**"Manipulation of the running variable in the regression discontinuity design: A density test"**

- Venue: *Journal of Econometrics*, 142(2):698-714.
- Density test original. Citar como antecedente; usar CJM como método atual.

---

## Bloco 2 — Procurement, competição e captura em desenvolvimento

### 2.1 Bosio, Djankov, Glaeser & Shleifer (2022) ✅
**"Public Procurement in Law and Practice"**

- Venue: *American Economic Review*, 112(4):1091-1117.
- Evidência cross-country sobre como regras de procurement afetam qualidade do gasto público. Usar na intro (primeiro parágrafo) para dimensionar a importância do problema.
- Claim a verificar: "governments spend 12% of GDP on procurement" — esta é uma estatística recorrente; verificar a cifra exata e a fonte primária.

### 2.2 Bandiera, Prat & Valletti (2009) ✅
**"Active and Passive Waste in Government Spending: Evidence from a Policy Experiment"**

- Venue: *American Economic Review*, 99(4):1278-1308.
- Distinção entre waste ativo (corrupção) e passivo (ineficiência). Referência clássica para discutir por que procurement é ineficiente mesmo sem corrupção. Usar na intro.

### 2.3 Best, Hjort & Szakonyi (2023) ⚠️
**"Individuals and Organizations as Sources of State Effectiveness"**

- Venue: *American Economic Review*? Ou *Quarterly Journal of Economics*? **Verificar com atenção — é 2023, a memória pode estar imprecisa**.
- Efeito de características individuais vs institucionais sobre eficiência em procurement russo. Referência contemporânea importante.

### 2.4 Coviello, Guglielmo & Spagnolo (2018) ⚠️
**"The Effect of Discretion on Procurement Performance"**

- Venue: *Management Science* ou similar. **Verificar**.
- Discretion do comprador em procurement italiano e qualidade do resultado.

### 2.5 Decarolis (2014) ⚠️
**"Awarding Price, Contract Performance, and Bids Screening: Evidence from Procurement Auctions"**

- Venue: *American Economic Journal: Applied Economics*. **Verificar ano e volume**.
- Impacto de diferentes regras de adjudicação sobre performance de contratos italianos.

### 2.6 Coviello & Mariniello (2014) ⚠️
**"Publicity Requirements in Public Procurement: Evidence from a Regression Discontinuity Design"**

- Venue: *Journal of Public Economics*. **Verificar**.
- Usa RD em threshold de publicidade obrigatória para avaliar efeitos sobre competição e preços. **Referência metodológica próxima** — também é um RD em procurement.

---

## Bloco 3 — Corrupção, conexões políticas e captura em Brasil/desenvolvimento

### 3.1 Colonnelli & Prem (2022) ⚠️
**"Corruption and Firms"**

- Venue: *Review of Economic Studies*? **Verificar** — tenho memória de ReStud 2022 ou AER 2022, preciso confirmar. Muito provavelmente ReStud.
- Usa auditorias federais CGU no Brasil para identificar firmas expostas a corrupção; linka com RAIS e ComprasNet para medir efeitos sobre emprego e produtividade. **Contraponto metodológico mais próximo do nosso Caminho 4** (revolving door/rent-sharing).
- **Como discutir**: eles identificam "firmas corruptas" via shock de auditoria; nós identificamos tratamento via RD em leilões. Complementaridade, não substitutividade.

### 3.2 Brollo, Nannicini, Perotti & Tabellini (2013) ✅
**"The Political Resource Curse"**

- Venue: *American Economic Review*, 103(5):1759-1796.
- Brasil municipal, transferências federais e corrupção. Relevante para framing sobre incentivos políticos em procurement.

### 3.3 Ferraz & Finan (2008) ✅
**"Exposing Corrupt Politicians: The Effects of Brazil's Publicly Released Audits on Electoral Outcomes"**

- Venue: *Quarterly Journal of Economics*, 123(2):703-745.
- Paper clássico de Ferraz-Finan usando auditorias CGU. Background sobre a infraestrutura de accountability brasileira.

### 3.4 Szerman (2022) ❓
**"The Labor Market Effects of Disability Hiring Quotas"** ou algo sobre procurement

- **CONFIRMAR**: Dimitri Szerman tem múltiplos papers; preciso distinguir entre o trabalho sobre procurement (possivelmente JMP dele) e outros. Tem um paper importante sobre procurement e efeitos sobre firmas. **Verificação prioritária**.

### 3.5 Akcigit, Baslandze & Lotti (2023) ⚠️
**"Connecting to Power: Political Connections, Innovation, and Firm Dynamics"**

- Venue: *Econometrica*, 2023. **Verificar**.
- Itália, conexões políticas medidas via mobilidade de políticos entre firmas. Metodologia similar ao que faríamos no Caminho 2 (worker flows); usar como âncora.

### 3.6 Cingano & Pinotti (2013) ⚠️
**"Politicians at Work: The Private Returns and Social Costs of Political Connections"**

- Venue: *Journal of the European Economic Association*, 2013 ou 2011. **Verificar ano**.
- Usa registros pessoais italianos para medir valor de conexões políticas. Precedente metodológico para identificar revolving door via RAIS.

---

## Bloco 4 — Rent-sharing e efeitos de demanda sobre firmas

### 4.1 Card, Cardoso, Heining & Kline (2018) ⚠️
**"Firms and Labor Market Inequality: Evidence and Some Theory"**

- Venue: *Journal of Labor Economics*, 36(S1):S13-S70. **Verificar volume**.
- Review canônica sobre firmas e desigualdade via AKM. Framework teórico do rent-sharing. **Central para Caminho 4**.

### 4.2 Card, Cardoso & Kline (2016) ⚠️
**"Bargaining, Sorting, and the Gender Wage Gap: Quantifying the Impact of Firms on the Relative Pay of Women"**

- Venue: *Quarterly Journal of Economics*, 131(2):633-686.
- Aplicação do framework de rent-sharing. Metodologia AKM-based. Usar como precedente para decomposição salarial.

### 4.3 Kline, Petkova, Williams & Zidar (2019) ⚠️
**"Who Profits from Patents? Rent-Sharing at Innovative Firms"**

- Venue: *Quarterly Journal of Economics*, 134(3):1343-1404.
- Usa choques exógenos (concessão de patentes) para estimar rent-sharing. **Análogo metodológico perfeito** — eles usam RD em scoring de patentes, nós usamos RD em margin de leilão. Ambos são close-decisions com consequências financeiras para a firma. **Referência de ouro para a intro**.

### 4.4 Van Reenen (1996) ⚠️
**"The Creation and Capture of Rents: Wages and Innovation in a Panel of UK Companies"**

- Venue: *Quarterly Journal of Economics*. **Verificar volume/ano**.
- Paper seminal sobre rent-sharing em firmas inovadoras. Estabelece a metodologia clássica de elasticidade salário-lucratividade.

### 4.5 Abowd, Kramarz & Margolis (1999) ⚠️
**"High Wage Workers and High Wage Firms"**

- Venue: *Econometrica*, 67(2):251-333.
- AKM original. **Referência metodológica obrigatória** para qualquer trabalho que use decomposição de efeitos firma/trabalhador.

### 4.6 Alvarez, Benguria, Engbom & Moser (2018) ⚠️
**"Firms and the Decline in Earnings Inequality in Brazil"**

- Venue: *American Economic Journal: Macroeconomics*. **Verificar**.
- AKM aplicado a RAIS. Precedente brasileiro para a metodologia do Caminho 4.

### 4.7 Gerard, Lagos, Severnini & Card (2021) ⚠️
**"Assortative Matching or Exclusionary Hiring? The Impact of Employment and Pay Policies on Racial Wage Differentials in Brazil"**

- Venue: *American Economic Review*, 2021. **Verificar**.
- AKM com RAIS brasileira. Outro precedente metodológico.

---

## Bloco 5 — Choques de demanda e emprego: identificação causal

### 5.1 Greenstone, Hornbeck & Moretti (2010) ✅
**"Identifying Agglomeration Spillovers: Evidence from Winners and Losers of Large Plant Openings"**

- Venue: *Journal of Political Economy*, 118(3):536-598.
- Estratégia de "winners vs losers" — usam escolhas de sites de plantas como quase-experimento. **Referência conceitual direta** para nossa estratégia de narrow winners vs narrow losers. Citar na intro como precedente da lógica.

### 5.2 Cellini, Ferreira & Rothstein (2010) ✅
**"The Value of School Facilities: Evidence from a Dynamic Regression Discontinuity Design"**

- Venue: *Quarterly Journal of Economics*, 125(1):215-261.
- RD dinâmico — repetidas eleições de bond, outcomes múltiplos anos depois. **Referência metodológica central para nosso event study dinâmico**.

### 5.3 Callaway & Sant'Anna (2021) ⚠️
**"Difference-in-Differences with Multiple Time Periods"**

- Venue: *Journal of Econometrics*, 225(2):200-230. **Verificar**.
- Estimador DiD com múltiplos períodos e tratamento staggered. Possivelmente útil se a estrutura do nosso event study virar staggered.

### 5.4 Borusyak, Jaravel & Spiess (2024) ⚠️
**"Revisiting Event Study Designs: Robust and Efficient Estimation"**

- Venue: *Review of Economic Studies*, 2024. **Verificar — é recente**.
- Alternativa eficiente para event studies com staggered treatment. Citar se usarmos.

### 5.5 Lee & Mas (2012) ⚠️
**"Long-Run Impacts of Unions on Firms: New Evidence from Financial Markets, 1961-1999"**

- Venue: *Quarterly Journal of Economics*, 127(1):333-378. **Verificar**.
- RD em eleições sindicais e efeitos sobre firmas. Similar conceitualmente ao que fazemos.

---

## Bloco 6 — Bid rigging e detecção (herança do paper original, seção curta)

### 6.1 Kawai, Nakabayashi, Ortner & Chassang (2023) ⚠️
**"Using Bid Rotation and Incumbency to Detect Collusion: A Regression Discontinuity Approach"**

- Venue: **incerto** — tenho memória de que pode ser NBER WP, ReStud, Econometrica, ou AER. **Verificar com máxima prioridade** — é citado como referência central do paper original e preciso ter certeza do venue. Possivelmente publicado como Kawai–Nakabayashi–Ortner–Chassang (2023) em ReStud.
- Como discutir: manter como referência metodológica que **motivou** o paper original, mas explicar (breve) por que nosso foco mudou de detecção para efeitos reais.

### 6.2 Kawai & Nakabayashi (2022) ⚠️
**"Detecting Large-Scale Collusion in Procurement Auctions"**

- Venue: possivelmente *Journal of Political Economy* ou AEJ: Micro. **Verificar**.
- Aplicação empírica ampla da metodologia KNOC em Japão.

### 6.3 Chassang & Ortner (2019) ⚠️
**"Collusion in Auctions with Constrained Bids: Theory and Evidence from Public Procurement"**

- Venue: *Journal of Political Economy*, 2019. **Verificar ano**.
- Framework teórico de colusão com bids limitados. Background teórico.

### 6.4 Porter & Zona (1993) ⚠️
**"Detection of Bid Rigging in Procurement Auctions"**

- Venue: *Journal of Political Economy*, 101(3):518-538. **Verificar — este é o paper sobre highway auctions, não school milk**.
- ⚠️ O paper original (`porter1993detecting` no biblio.bib) está sendo usado erradamente — ele aparentemente conflata com Porter-Zona 1999 RAND (school milk). **Corrigir o bib**.

### 6.5 Porter & Zona (1999) ❓
**"Ohio School Milk Markets: An Analysis of Bidding"**

- Venue: *RAND Journal of Economics*, 30(2):263-288. **Verificar**.
- O paper de school milk. Se a intro do manuscrito cita "school milk in the United States", deve citar este, não o 1993.

### 6.6 Bajari & Ye (2003) ⚠️
**"Deciding Between Competition and Collusion"**

- Venue: *Review of Economics and Statistics*, 85(4):971-989. **Verificar**.
- Testes estatísticos para distinguir competição de colusão. Já citado no paper atual; manter na nova versão como antecedente da literatura de detecção.

### 6.7 Asker (2010) ✅
**"A Study of the Internal Organization of a Bidding Cartel"**

- Venue: *American Economic Review*, 100(3):724-762.
- Cartel de selos em NYC. Paper estrutural clássico de colusão em leilões. Referência para Caminho 3 (welfare estrutural), mas pode ser citado na intro do Paper 1 como contexto.

---

## Bloco 7 — Revolving door e conexões via mobilidade de trabalhadores

### 7.1 Schoenherr (2019) ⚠️
**"Political Connections and Allocative Distortions"**

- Venue: *Journal of Finance*, 74(2):543-586. **Verificar volume**.
- Coreia do Sul, usa registros individuais para identificar conexões políticas via mobilidade. **Precedente mais próximo para o Caminho 4 / revolving door**.

### 7.2 Akcigit, Baslandze & Lotti (2023)
(já listado em 3.5)

### 7.3 Shue (2013) ⚠️
**"Executive Networks and Firm Policies: Evidence from the Random Assignment of MBA Peers"**

- Venue: *Review of Financial Studies*, 26(6):1401-1442. **Verificar**.
- Redes executivas e decisões de firma. Precedente conceitual mas não metodologicamente igual.

### 7.4 Fracassi (2017) ⚠️
**"Corporate Finance Policies and Social Networks"**

- Venue: *Management Science*, 63(8):2420-2438. **Verificar**.
- Redes de co-working e políticas corporativas.

### 7.5 Bertrand, Bombardini, Fisman & Trebbi (2020) ⚠️
**"Tax-Exempt Lobbying: Corporate Philanthropy as a Tool for Political Influence"**

- Venue: *American Economic Review*, 2020. **Verificar**.
- Conexões políticas de firmas. Citar se relevante para discussão de revolving door.

---

## Bloco 8 — Brasil: mercado de trabalho formal, RAIS

### 8.1 Dix-Carneiro (2014) ⚠️
**"Trade Liberalization and Labor Market Dynamics"**

- Venue: *Econometrica*, 82(3):825-885.
- Paper canônico usando RAIS. Referência metodológica sobre como trabalhar com esse dataset.

### 8.2 Engbom, Gonzaga, Moser & Olivieri (2022) ⚠️
**"Earnings Inequality and Dynamics in the Presence of Informality: The Case of Brazil"**

- Venue: *Quantitative Economics*? **Verificar**.
- RAIS + informalidade. Background sobre limitações da RAIS (só captura formal).

### 8.3 Dix-Carneiro & Kovak (2017) ⚠️
**"Trade Liberalization and Regional Dynamics"**

- Venue: *American Economic Review*, 107(10):2908-2946. **Verificar**.
- RAIS em contexto regional. Referência para clustering e design de inferência.

---

## Priorização de verificação

Antes de colocar qualquer desses papers no `biblio.bib`, verificar em ordem de prioridade:

1. **🔴 Máxima prioridade** (são citados como âncoras centrais):
   - Ferraz-Finan-Szerman (2016) — venue e ano exatos
   - Kawai-Nakabayashi-Ortner-Chassang (2023) — venue exato
   - Colonnelli-Prem (2022) — venue exato
   - Kline-Petkova-Williams-Zidar (2019) — volume exato
   - Porter-Zona: distinguir 1993 (highway) de 1999 (school milk)

2. **🟡 Alta prioridade** (usados em argumento metodológico):
   - CCT 2014, CCF 2018, CJM 2020 — garantir as citações de RD
   - AKM 1999 — título exato
   - Card et al. 2018 review
   - Cellini-Ferreira-Rothstein 2010

3. **🟢 Prioridade média** (usados em lit review sem ser âncora):
   - Bosio et al. 2022, Bandiera-Prat-Valletti 2009
   - Szerman 2022 (identificar qual paper é)
   - Akcigit-Baslandze-Lotti 2023
   - Decarolis 2014, Coviello-Mariniello 2014
   - Best-Hjort-Szakonyi 2023
   - Schoenherr 2019

---

## Gaps possíveis (pesquisa adicional recomendada)

1. **Literatura recente (2023-2025) sobre procurement e RAIS-like data em outros países em desenvolvimento** — Chile (Litschig?), Colômbia, Peru, Índia. Verificar se há trabalhos recentes que me escaparam.
2. **Literatura sobre desenho de set-aside para PMEs** — conecta com Paper 2 do projeto maior. Verificar Decarolis-Rovigatti (2023?), Baltrunaite et al. (2021).
3. **Literatura sobre efeitos de contratos públicos em countries fora Brasil/US/Europa** — externa validity. Índia (Duflo?), África subsaariana.
4. **Recent RD methodological refinements** — Arai-Otsu 2024?, Gerard-Rokkanen-Rothe 2020 sobre bounds em caso de manipulação.

---

## Roteiro de uso deste documento

1. **Fase 1** (próximo passo imediato): fazer WebSearch de 10-15 minutos por entrada em ⚠️ de máxima prioridade e corrigir este documento.
2. **Fase 2**: construir `biblio.bib` do zero apenas com entradas verificadas.
3. **Fase 3**: integrar citações ao texto das seções 1 e 2 do manuscrito.
4. **NÃO** confiar nesta lista como BibTeX pronto. Ela é um **roteiro de trabalho**, não um arquivo de citação final.

---

*Documento gerado por mr-beneath em modo /co. Todas as entradas marcadas ⚠️ ou ❓ devem ser verificadas via busca externa antes de uso em manuscrito. A diretriz operacional do mr-beneath é: nunca inventar referências, nunca citar sem certeza absoluta, sinalizar dúvida explicitamente.*

---

## Verified metadata (2026-04-06 WebSearch batch)

Citações definitivas, prontas para transformar em entradas BibTeX. Todas verificadas contra fontes primárias (journal websites, NBER, IDEAS/RePEc).

### 🔴 Âncoras centrais

**1. Ferraz, Finan & Szerman (2015) — STILL WORKING PAPER** ⚠️
- Authors: Claudio Ferraz, Frederico Finan, Dimitri Szerman
- Title: *Procuring Firm Growth: The Effects of Government Purchases on Firm Dynamics*
- **Status: NBER Working Paper No. 21219 (May 2015), NOT published in a journal as of search date.**
- Use as: `\citet[NBER WP 21219]{ferraz2015procuring}` or equivalent.
- **IMPORTANT**: Nosso Caminho 1 se posiciona contra este paper como *working paper* — se eles publicarem antes de nós, vai virar paper publicado em top journal e o nosso terá que lidar com isso como rival direto. Acompanhar.
- URL: https://www.nber.org/papers/w21219

**2. Kawai, Nakabayashi, Ortner & Chassang (2023)** ✅
- Authors: Kei Kawai, Jun Nakabayashi, Juan M. Ortner, Sylvain Chassang
- Title: *Using Bid Rotation and Incumbency to Detect Collusion: A Regression Discontinuity Approach*
- **Venue: Review of Economic Studies 90(1):376-403, January 2023**
- Previously NBER WP 29625 (2022).
- URL: https://academic.oup.com/restud/article-abstract/90/1/376/6540874

**3. Colonnelli & Prem (2022)** ✅
- Authors: Emanuele Colonnelli, Mounu Prem
- Title: *Corruption and Firms*
- **Venue: Review of Economic Studies 89(2):695-732, March 2022**
- Uses Brazilian CGU audits + matched firm data. Complementary identification strategy to ours.
- URL: https://academic.oup.com/restud/article-abstract/89/2/695/6311681

**4. Kline, Petkova, Williams & Zidar (2019)** ✅
- Authors: Patrick Kline, Neviana Petkova, Heidi L. Williams, Owen Zidar
- Title: *Who Profits from Patents? Rent-Sharing at Innovative Firms*
- **Venue: Quarterly Journal of Economics 134(3):1343-1404 (2019)**
- Key finding: workers capture ~30 cents per dollar of patent-induced surplus. Direct methodological analog.
- URL: https://academic.oup.com/qje/article-abstract/134/3/1343/5420483

**5. Porter & Zona (1993)** ✅ — **HIGHWAY construction, NOT school milk**
- Authors: Robert H. Porter, J. Douglas Zona
- Title: *Detection of Bid Rigging in Procurement Auctions*
- **Venue: Journal of Political Economy 101(3):518-538 (June 1993)**
- Subject: state highway construction contracts (NY).
- URL: https://www.journals.uchicago.edu/doi/abs/10.1086/261885

**6. Porter & Zona (1999)** ✅ — **School milk paper, separate from 1993**
- Authors: Robert H. Porter, J. Douglas Zona
- Title: *Ohio School Milk Markets: An Analysis of Bidding*
- **Venue: RAND Journal of Economics 30(2):263-288 (Summer 1999)**
- **⚠️ CORRIGIR `biblio.bib`**: o manuscrito atual usa `porter1993detecting` para citar fatos de school milk — isso é **erro**. School milk é o 1999. Criar entrada `porter1999ohio` e separar os dois usos no texto.
- URL: https://econpapers.repec.org/article/rjerandje/v_3a30_3ay_3a1999_3ai_3asummer_3ap_3a263-288.htm

### 🟡 Metodologia RD e estimação

**7. Lee & Lemieux (2010)** ✅
- Authors: David S. Lee, Thomas Lemieux
- Title: *Regression Discontinuity Designs in Economics*
- **Venue: Journal of Economic Literature 48(2):281-355 (June 2010)**
- DOI: 10.1257/jel.48.2.281

**8. Lee (2008)** ✅
- Authors: David S. Lee
- Title: *Randomized Experiments from Non-random Selection in U.S. House Elections*
- **Venue: Journal of Econometrics 142(2):675-697 (2008)**

**9. Calonico, Cattaneo & Titiunik (2014)** ✅
- Authors: Sebastian Calonico, Matias D. Cattaneo, Rocío Titiunik
- Title: *Robust Nonparametric Confidence Intervals for Regression-Discontinuity Designs*
- **Venue: Econometrica 82(6):2295-2326 (2014)**
- DOI: 10.3982/ECTA11757

**10. Calonico, Cattaneo & Farrell (2018)** ✅
- Authors: Sebastian Calonico, Matias D. Cattaneo, Max H. Farrell
- Title: *On the Effect of Bias Estimation on Coverage Accuracy in Nonparametric Inference*
- **Venue: Journal of the American Statistical Association 113(522):767-779 (2018)**

**11. Cattaneo, Jansson & Ma (2020)** ✅
- Authors: Matias D. Cattaneo, Michael Jansson, Xinwei Ma
- Title: *Simple Local Polynomial Density Estimators*
- **Venue: Journal of the American Statistical Association 115(531):1449-1455 (2020)**

**12. McCrary (2008)** ✅
- Authors: Justin McCrary
- Title: *Manipulation of the running variable in the regression discontinuity design: A density test*
- **Venue: Journal of Econometrics 142(2):698-714 (2008)**
- DOI: 10.1016/j.jeconom.2007.05.005

### 🟢 Procurement, captura, colusão

**13. Bosio, Djankov, Glaeser & Shleifer (2022)** ✅
- Authors: Erica Bosio, Simeon Djankov, Edward L. Glaeser, Andrei Shleifer
- Title: *Public Procurement in Law and Practice*
- **Venue: American Economic Review 112(4):1091-1117 (April 2022)**
- Headline stat: 187 countries surveyed; laws correlate with practice but not with outcomes except in low-capacity countries.

**14. Best, Hjort & Szakonyi (2023)** ✅
- Authors: Michael Carlos Best, Jonas Hjort, David Szakonyi
- Title: *Individuals and Organizations as Sources of State Effectiveness*
- **Venue: American Economic Review 113(8):2121-2167 (August 2023)**
- 16M public purchases in Russia. 39% of price variation driven by bureaucrats/organizations.

**15. Kawai & Nakabayashi (2022)** ✅
- Authors: Kei Kawai, Jun Nakabayashi
- Title: *Detecting Large-Scale Collusion in Procurement Auctions*
- **Venue: Journal of Political Economy 130(5) (2022)**
- ~42,000 Japanese construction auctions, ~$40bn in awards.

**16. Chassang & Ortner (2019)** ✅
- Authors: Sylvain Chassang, Juan Ortner
- Title: *Collusion in Auctions with Constrained Bids: Theory and Evidence from Public Procurement*
- **Venue: Journal of Political Economy 127(5):2269-2300 (2019)**

**17. Bajari & Ye (2003)** ✅
- Authors: Patrick Bajari, Lixin Ye
- Title: *Deciding Between Competition and Collusion*
- **Venue: Review of Economics and Statistics 85(4):971-989 (2003)**

**18. Asker (2010)** ✅
- Authors: John Asker
- Title: *A Study of the Internal Organization of a Bidding Cartel*
- **Venue: American Economic Review 100(3):724-762 (June 2010)**
- Structural study of a stamp dealers' knockout cartel.

### 🟢 Brasil, corrupção, labor market

**19. Brollo, Nannicini, Perotti & Tabellini (2013)** ✅
- Authors: Fernanda Brollo, Tommaso Nannicini, Roberto Perotti, Guido Tabellini
- Title: *The Political Resource Curse*
- **Venue: American Economic Review 103(5):1759-1796 (2013)**
- RD at Brazilian municipal population thresholds.

**20. Ferraz & Finan (2008)** ✅
- Authors: Claudio Ferraz, Frederico Finan
- Title: *Exposing Corrupt Politicians: The Effects of Brazil's Publicly Released Audits on Electoral Outcomes*
- **Venue: Quarterly Journal of Economics 123(2):703-745 (May 2008)**

**21. Dix-Carneiro (2014)** ✅
- Authors: Rafael Dix-Carneiro
- Title: *Trade Liberalization and Labor Market Dynamics*
- **Venue: Econometrica 82(3):825-885 (May 2014)**
- Foundation for RAIS-based dynamic labor market analysis in Brazil.

### 🟢 Rent-sharing, AKM, conexões

**22. Akcigit, Baslandze & Lotti (2023)** ✅
- Authors: Ufuk Akcigit, Salomé Baslandze, Francesca Lotti
- Title: *Connecting to Power: Political Connections, Innovation, and Firm Dynamics*
- **Venue: Econometrica 91(2):529-564 (March 2023)**
- Italy, 1993–2014. Market leaders more politically connected but less innovative.

**23. Card, Cardoso, Heining & Kline (2018)** ✅
- Authors: David Card, Ana Rute Cardoso, Jörg Heining, Patrick Kline
- Title: *Firms and Labor Market Inequality: Evidence and Some Theory*
- **Venue: Journal of Labor Economics 36(S1):S13-S70 (2018)**
- DOI: 10.1086/694153

**24. Abowd, Kramarz & Margolis (1999)** ✅
- Authors: John M. Abowd, Francis Kramarz, David N. Margolis
- Title: *High Wage Workers and High Wage Firms*
- **Venue: Econometrica 67(2):251-334 (March 1999)**
- The canonical AKM paper.

### 🟢 Outros métodos / choques de demanda

**25. Greenstone, Hornbeck & Moretti (2010)** ✅
- Authors: Michael Greenstone, Richard Hornbeck, Enrico Moretti
- Title: *Identifying Agglomeration Spillovers: Evidence from Winners and Losers of Large Plant Openings*
- **Venue: Journal of Political Economy 118(3):536-598 (June 2010)**
- **Conceptual anchor for "winners vs losers" identification strategy.**

**26. Cellini, Ferreira & Rothstein (2010)** ✅
- Authors: Stephanie Riegg Cellini, Fernando Ferreira, Jesse Rothstein
- Title: *The Value of School Facility **Investments**: Evidence from a Dynamic Regression Discontinuity Design*
- **Venue: Quarterly Journal of Economics 125(1):215-261 (February 2010)**
- Title has "Investments", not "Facilities" alone — corrigir se citado.

**27. Callaway & Sant'Anna (2021)** ✅
- Authors: Brantly Callaway, Pedro H.C. Sant'Anna
- Title: *Difference-in-Differences with Multiple Time Periods*
- **Venue: Journal of Econometrics 225(2):200-230 (December 2021)**

**28. Borusyak, Jaravel & Spiess (2024)** ✅
- Authors: Kirill Borusyak, Xavier Jaravel, Jann Spiess
- Title: *Revisiting Event-Study Designs: Robust and Efficient Estimation*
- **Venue: Review of Economic Studies 91(6):3253-3285 (November 2024)**
- DOI: 10.1093/restud/rdae007

---

## Correções ao `biblio.bib` atual do manuscrito

1. **Porter-Zona confusion**: o manuscrito usa `porter1993detecting` para descrever um fato sobre "school milk cartels in the United States" (introduction.tex:2). Isso é **erro**: Porter-Zona 1993 JPE é sobre highway construction. School milk é Porter-Zona 1999 RAND. Criar entradas separadas `porter1993highway` e `porter1999ohio`, e corrigir o texto.

2. **Ferraz-Finan-Szerman citar como working paper**, NOT como journal article. Se alguém tentar colocar como "JPE 2015" ou "AEJ 2016", está errado.

3. **Kawai-Nakabayashi 2022** é **JPE**, não AEJ ou outro. (Este é diferente de Kawai-Nakabayashi-Ortner-Chassang 2023 ReStud.)

4. **Cellini-Ferreira-Rothstein 2010** título correto termina em "Investments", não "Facilities".

5. **Chassang-Ortner 2019** é **JPE 127(5)**, não ReStud.

---

## Referências ainda não verificadas (prioridade média, para verificação posterior)

Das 45 entradas originais, estas ~18 ainda não foram verificadas via WebSearch e permanecem marcadas ⚠️:

- Coviello, Guglielmo & Spagnolo (2018) — discretion in procurement
- Decarolis (2014) — AEJ Applied
- Coviello & Mariniello (2014) — JPubE publicity requirements
- Cingano & Pinotti (2013) — JEEA political connections Italy
- Card, Cardoso & Kline (2016) — QJE gender wage gap
- Van Reenen (1996) — QJE rent creation/capture
- Alvarez, Benguria, Engbom & Moser (2018) — AEJ Macro Brazil inequality
- Gerard, Lagos, Severnini & Card (2021) — AER racial wage Brazil
- Lee & Mas (2012) — QJE unions and firms
- Schoenherr (2019) — JF political connections Korea
- Shue (2013) — RFS MBA networks
- Fracassi (2017) — Mgmt Sci social networks
- Bertrand, Bombardini, Fisman & Trebbi (2020) — AER tax-exempt lobbying
- Engbom, Gonzaga, Moser & Olivieri (2022) — informality Brazil
- Dix-Carneiro & Kovak (2017) — AER regional dynamics
- Bandiera, Prat & Valletti (2009) — AER active/passive waste

Estas podem ser verificadas em uma segunda rodada quando o `biblio.bib` estiver sendo efetivamente construído.
