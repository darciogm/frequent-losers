# Paper 13 — When Courts Buy Drugs: The Microeconomics of Compelled Public Procurement

**Status.** Semente top-5. Pré-calibração (2026-04-18) coloca probabilidade top-5 em **20-30%** — o mais alto do portfólio. Venue alvo: **QJE / AER (health economics)**.

**Tagline interna.** Reenquadrar S-CODES do ângulo de procurement (Paper 1, Bitter Pills) para o ângulo de health economics / forced-demand natural experiment. Mesmo dado — pergunta diferente, audiência diferente, teto diferente.

---

## Pergunta central

Qual é o valor marginal de forçar o estado a adquirir um medicamento específico para um paciente específico? Em particular:
- (i) Como a oferta responde a demanda judicial-induzida? (elasticidade de oferta sob dispensa forçada vs. pregão)
- (ii) Há spillovers para procurement "regular" (substituição intertemporal do mesmo comprador) e para outros compradores (via teto CMED)?
- (iii) Qual o retorno em mortalidade/morbidade por R$ compulsoriamente gasto?
- (iv) O pacote de policy de *cherry-picking* pelo judiciário é welfare-improving ou apenas redistributivo (beneficia litigantes às custas de não-litigantes)?

---

## Reformulação estrutural (ângulo top-5)

S-CODES gera, para cada par (município × princípio ativo × mês), um **shifter vertical exógeno da curva de demanda** igual à quantidade judicialmente imposta $Q^{judicial}_{mpt}$.

Sob identificação limpa, isso permite estimar:

$$\log P_{mpt} = \alpha_{mp} + \gamma_t + \beta \cdot \log(Q^{regular}_{mpt} + Q^{judicial}_{mpt}) + \varepsilon_{mpt}$$

onde $Q^{judicial}$ é instrumentado pela *judge stringency*, identificando a elasticidade $\beta$ da curva de oferta de medicamentos via licitação pública. Pass-through via teto CMED é identificado como efeito cross-municipal de shock em município-focal.

**Welfare** é calculado linkando a comarca a taxas de mortalidade (SIM/DATASUS) para coortes que recebem o medicamento, via framework à la Finkelstein-Hendren-Luttmer (QJE 2019) Value of Medicaid, Cabral-Geruso-Mahoney (AER 2018), Clemens-Gottlieb (AER 2014).

---

## Identificação

### First-stage — Judge stringency IV
- **Template**: Dahl-Kostøl-Mogstad (QJE 2014), Dobbie-Goldin-Yang (AER 2018).
- **Definição**: $Z_{jc}$ = leave-one-out taxa de deferimento de ações S-CODES do juiz $j$ na comarca $c$, residualizada por comarca × ano × tipo-de-ação dummies.
- **Exclusion restriction**: assignment de casos a juízes dentro de vara cível × período é quase-aleatório (via distribuição do CPJ/SP). Validação via balance test de características do paciente, diagnóstico, valor da demanda.
- **Variação útil**: comarcas com ≥ 2 juízes ativos em vara da Fazenda / cível no período; idealmente ≥ 3 para first-stage robusto.

### Second-stage — outcomes
- **Municipal procurement**: BEC-SP + TCE-SP Audesp bid-level linkagem via comarca → município → comprador. Outcome: preço pago, modalidade (dispensa vs. pregão), tempo até entrega, firma vencedora.
- **Pharmaceutical market**: entrada/saída de CNPJs farmacêuticos (RAIS CNAE 21* classes); firma vencedora como função de shock.
- **Health outcomes**: SIM (mortalidade) + SIH (internações SUS) por comarca × diagnóstico × mês para coorte afetada. SINASC para perinatais.
- **Fiscal**: total gasto em dispensa forçada; ratio CMED vs. preço pago.

### Natural experiment adicional — STF 2024
- Decisão STF em **setembro/2024** limitou dever do estado para medicamentos *não incorporados ao SUS* (não-ANVISA). Isso cria **pré/post shock** na taxa de deferimento em comarcas que historicamente deferiam demandas alto-custo não-padrão.
- DiD: comarcas com alta proporção de demandas pré-STF por medicamentos não-incorporados (treated) vs. baixa proporção (control).
- **Triple-DiD**: STF shock × judge stringency × município-level exposure.

---

## Dados já existentes no monorepo

| Ativo | Localização | Status |
|---|---|---|
| S-CODES dataset | `paper1-bitter-pills/datasets/` | Pronto (base do Paper 1) |
| Juiz × vara × data das ações | `paper1-bitter-pills/datasets/judicial-scodes/` | Pronto |
| BEC-SP bid-level + firma | `paper4-thresholds/02_data/` | Pronto |
| CMED reference prices | `paper1-bitter-pills/datasets/` (verif) | Provavelmente pronto |
| TCE-SP Audesp municipal procurement | `paper6-procure/build/clean/` | Pronto |
| Comarca → município mapping | `paper6-procure/source/clean/` | Pronto (98.4% resolvido) |
| Shapefiles SP municípios | `bitter-pills/data/geocoding/shapefiles/` | Pronto |
| RAIS farmacêuticas (CNAE 21*) | via RAIS identificada | Parcial |
| DATASUS SIM/SIH/SINASC | IBGE/DATASUS aberto | A baixar |

### Dados a construir

| Dado | Fonte | Esforço |
|---|---|---|
| Mortalidade × comarca × mês × CID | DATASUS SIM (API aberta) | 2-3 semanas |
| Internações × comarca × mês × procedimento | DATASUS SIH | 2 semanas |
| Datas STF 2024 + decisões correlatas | STF portal | 1 semana |
| Lista medicamentos ANVISA-incorporados vs. não | CONITEC/ANVISA | 1 semana |
| Teto CMED histórico por princípio ativo | ANVISA CMED | 2 semanas |

---

## Caminhos possíveis

### Caminho A — Descritivo masterpiece (viability gate)
- Painel (comarca × princípio ativo × mês): volume de ordens, valor total, preço médio judicial, preço médio pregão, razão dispensa/pregão.
- Comparar preço pago em dispensa forçada vs. teto CMED vs. pregão competitivo.
- Mapa temporal: onde e quando S-CODES cresceu.
- **Gate**: se gap pago vs. CMED é < 5% em média, paper morre (sem rent, sem welfare relevante). Se > 15% (expectativa), seguir.

### Caminho B — First-stage e balance test (blocking)
- Validar quase-aleatoriedade: regressar $Z_{jc}$ (stringency residualizada) em características observáveis dos casos. Coeficientes ≈ 0 é condição necessária.
- F-stat do first-stage: stringency → deferimento deve ter F ≥ 10.
- **Gate**: se balance falha ou F < 10, re-escopo para sub-amostra onde aleatoriedade se sustenta; ou matar se amostra cai abaixo de ~3k casos.

### Caminho C — Reduced-form: municipal procurement response
- Outcome: log preço pago, share em dispensa, número de firmas, delay.
- Identificação: $Z_{jc}$ como IV para volume judicial.
- Heterogeneidade: por tipo de medicamento (baixo-custo essencial vs. alto-custo especializado), por tamanho do município.
- **Teto realista**: publicável sozinho em AEJ:Applied / JHE.

### Caminho D — Spillovers
- Spillover intertemporal: município absorvendo choque S-CODES reduz procurement regular no mês seguinte?
- Spillover espacial: município vizinho (mesmo teto CMED estadual) muda preço pago?
- Pass-through via CMED: shock em um município afeta preço-teto estadual? Teste Kim-Pyun.
- Precedente: Finkelstein-McKnight (2008 JPubE) Medicare roll-out spillovers.

### Caminho E — Welfare via mortalidade (coração do paper)
- Link comarca × mês → SIM mortalidade para diagnóstico principal.
- $Z_{jc}$ instrumenta "exposição da comarca a medicamento judicial".
- Outcome: mortalidade por diagnóstico relevante.
- Valor estatístico da vida × redução em mortes → welfare por R$ gasto.
- **Template**: Finkelstein-Hendren-Luttmer (QJE 2019) Value of Medicaid. Clemens-Gottlieb (AER 2014).
- **Risco**: mortality signal pode ser pequeno em window curto; considerar morbidade (internações SIH) como outcome complementar.

### Caminho F — Structural supply curve (caminho top-5)
- Modelar decisão do município: dispensa emergencial (preço alto, rápido) vs. pregão (preço baixo, lento) condicional em demanda judicial-induzida.
- Estimar função de custo de atraso (tempo → morbidade).
- Contrafactual: qual seria o welfare se judiciário não deferisse?
- **Precedente**: Gowrisankaran-Town (JHE) structural hospital models. Currie et al.
- **Teto realista**: QJE health econ.

### Caminho G — STF 2024 DiD (ativo em alta valorização)
- Pré/post Sep-2024 × comarca-exposure heterogeneity.
- Separar medicamentos ANVISA-incorporados vs. não.
- Triple-DiD: $Z_{jc}$ × STF shock × categoria de medicamento.
- **Ganho**: identificação *extra* independente do judge IV. Dois IVs somam credibilidade.
- **Teto realista**: adiciona 3-5 pontos percentuais em probabilidade top-5.

### Caminho H — Extension: outros estados
- S-CODES é SP-specific; outros estados têm sistemas análogos (JUDSAUDE MG, SAJUD PR, etc.).
- Replicação do desenho em 2 estados = external validity.
- Custo: 2 anos + co-autor/estado.
- **Valor**: bloqueia crítica de referee "Brazilian peculiarity."

---

## Precedentes a bater

| Referência | Venue / Ano | Nosso diferencial |
|---|---|---|
| Finkelstein-Hendren-Luttmer | QJE 2019 | Forced demand (vs. lottery); drug-specific (vs. insurance) |
| Cabral-Geruso-Mahoney | AER 2018 | Compelled procurement ≠ Medicare-advantage bidding |
| Clemens-Gottlieb | AER 2014 | Brazilian universal system (vs. US Medicare); court-induced |
| Finkelstein-McKnight | JPubE 2008 | Judicial expansion ≠ age-based roll-out |
| Cohen-Dupas (2010) | QJE | RCT vs. natural experiment; distributional (poor litigants) |
| Biehl-Gloppen-Yamin | Law & Soc (qual) | Quantitative + causal (vs. narrative) |
| Wang et al. 2021 | Health Economics | Causal ID (vs. correlation) |
| Diniz-Machado | Pub Health | Structural welfare (vs. descriptive) |

---

## Gargalo principal

**Quasi-aleatoriedade do assignment.** TJSP distribui ações S-CODES por sorteio *digital* (CPJ/SP) dentro de vara cível / Fazenda. Em teoria, é random. Em prática: (i) rejection à força por juiz; (ii) redistribuição em casos conexos; (iii) plantão pode quebrar. Precisa validar via balance test + ideally obter documento institucional TJSP sobre regra atual de distribuição.

**Antídoto**: Paper 6 já tem infraestrutura para rodar balance test. Contatar CPJ/SP via Lei de Acesso à Informação para documento oficial sobre regra de distribuição. Validar *antes* de investir no paper.

---

## Decisão inicial

**Passo 1.** Rodar Caminho A (descritivo). 2-3 semanas. **Gate**: gap de preço ≥ 10%.
**Passo 2.** Construir `juiz × vara × data × outcome` painel a partir do S-CODES existente. 1-2 semanas.
**Passo 3.** Rodar Caminho B (balance + F-stat). **Gate crítico**: se falha, reescopo.
**Passo 4.** Em paralelo: negociar acesso DATASUS SIM/SIH (público mas API tem rate limit; pré-processar em duckdb).
**Passo 5.** Rodar Caminho C (reduced form procurement). Primeiros resultados mostráveis.
**Passo 6.** Em paralelo: Caminho G (STF 2024). Pode sair rápido.
**Passo 7.** Se Caminhos C + G positivos, investir em Caminho E (welfare via mortalidade). É o gancho top-5.
**Passo 8.** Caminho F (structural) só com co-autor estruturalista.

**Timeline agressivo**: 8-10 meses para v1 draft completo. Realista: 18-24 meses para submission AER/QJE.

---

## Co-autoria estratégica

Este paper se beneficia muito de:
- (a) Co-autor **health economist** com publicação em top-5 em econ da saúde (ex.: Finkelstein-pipeline, Dafny, Mahoney, Cabral, Duggan, Gupta).
- (b) Co-autor **judicial economics** (Dobbie, Doyle, Aizer) para legitimar judge IV em contexto brasileiro.
- (c) Possível co-autoria com **Ferraz** ou **Szerman** — já dominam Brazilian judicial data e trazem pedigree top-5.

Em ordem de valor marginal: (c) > (a) > (b). (c) é realista dado conexões INSPER.

---

## Memo honesto

Esta ideia é **o ativo top-5 mais subexplorado do seu portfólio**. Paper 1 (Bitter Pills) está tratando S-CODES como paper de procurement — ângulo errado para QJE. Paper 1 deve ser **terminado e submetido** a JPubE/AEJ:Applied como está (é um paper honesto de procurement). Mas imediatamente em seguida, iniciar este paper 13 como **re-framing health-economics** do mesmo corpus.

**Não é um follow-up do Paper 1 — é um *diferente* paper sobre o mesmo dado**. A pergunta, audiência, identificação, outcomes e welfare model são todos distintos.

### Conexões cruzadas com outros papers do portfólio

- **Paper 1 (Bitter Pills)** — fonte dos dados. Não canibaliza; re-enquadra.
- **Paper 9 (Judge IV)** — metodologia irmã (judge stringency). Lições aprendidas em um transferem para o outro. Validação de quasi-aleatoriedade pode ser executada conjuntamente.
- **Paper 11 (Threshold Reform)** — interação via Caminho F do Paper 11 (STF 2024 + Lei 14.133 simultaneous reforms).
- **Paper 14 (Endogenous Corruption)** — se firma vencedora da dispensa forçada está em rede cartel detectada, mecanismo adicional.

Este paper é **o único do portfólio que eu recomendaria tratar como prioridade absoluta** se o objetivo for maximizar probabilidade top-5.
