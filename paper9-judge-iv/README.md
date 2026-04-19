# Paper 9 — Judge Stringency IV: Deterrence vs. Displacement in Corruption Enforcement

**Status.** Semente. A pré-calibração (2026-04-18) coloca probabilidade top-5 em 3–7%; venue realista JPubE / JLEO / AEJ:Applied.

---

## Pergunta central

Condenações judiciais por improbidade administrativa *realmente* detêm corrupção futura — ou a deslocam para margens menos monitoradas (waterbed effect)? Quem responde ao enforcement: a firma ré, o município condenado, ou o ecossistema de firmas co-licitantes?

Reformulação estrutural: *qual é a elasticidade da corrupção à probabilidade esperada de condenação, e como essa elasticidade varia com características do scheme (fracionamento, direcionamento, cartel)?*

---

## Identificação base

**Leave-one-out judge stringency IV** (Dahl-Kostøl-Mogstad QJE 2014; Dobbie-Goldin-Yang AER 2018; Kling AER 2006).

- **First stage**: probabilidade de condenação em caso de improbidade é função (i) características observáveis do caso, (ii) *stringency* do juiz atribuído (leave-one-out rate de condenação em *outros* casos do mesmo juiz).
- **Exclusion restriction**: assignment do juiz é quase-aleatório dentro de vara × período (exige validação — balance test sobre observáveis).
- **Outcome**: comportamento pós-sentença da firma ré, do município, e de firmas na mesma rede (cobidding / worker flow).

---

## Dados já existentes no monorepo

| Ativo | Localização | Status |
|---|---|---|
| `court_case.parquet` (19.378 casos) | `paper6-procure/build/clean/` | Pronto |
| `court_party.parquet` | `paper6-procure/build/clean/` | Pronto |
| `court_sentenca.parquet` (14k sentenças) | `paper6-procure/build/clean/` | Pronto |
| Petições iniciais anonimizadas (10k) | `paper6-procure` via `$DATA_DIR/TJSP/improbidade_documentos/` | Pronto |
| `link_court_procurement.csv` | `paper6-procure/build/analysis/` | Pronto |
| TCE-SP Audesp licitação/contrato/empenho | `paper6-procure/build/clean/` | Pronto |
| BEC-SP bid-level | `paper4-thresholds/02_data/` | Pronto |
| CEIS/CNEP/CEPIM sanções | `paper6-procure` Dropbox `data/sanctions/` | Pronto |

Campos `juiz`, `vara`, `foro`, `comarca` já parseados em `court_case.parquet` e `court_sentenca.parquet`.

---

## Caminhos possíveis

### Caminho A — Validação da exogeneidade do assignment
**Pré-requisito absoluto.** Sem ele, o paper inteiro cai.

- Balance test: características da firma ré (idade, porte, CNAE) ortogonais a stringency do juiz atribuído dentro de vara × período.
- Teste F de instrumento: stringency prediz condenação com F ≥ 10 (rule of thumb).
- Simulação Monte Carlo de random assignment vs. observado.
- Subsample com comarcas ≥ 2 juízes ativos no período.

### Caminho B — Baseline deterrence firma-nível (JPubE)
- Outcome: para firma ré em caso improbidade, número de licitações participadas / ganhas em 1, 3, 5 anos pós-sentença.
- First-stage: stringency do juiz → condenação.
- Reduced form + 2SLS.
- Heterogeneidade por tipo de scheme, valor do contrato original, região.

### Caminho C — Waterbed effects (caminho mais ambicioso)
- **Hipótese**: enforcement em margem X desloca corrupção para margem Y (Becker 1968; Chassang-Ortner Ecta 2023).
- Testes:
  - Firma condenada por fracionamento → redução em fracionamento mas aumento em direcionamento?
  - Município condenado → redução em dispensa irregular mas aumento em dispensa "legítima" (thresholds novos)?
- Usa scheme classification do Paper 12 como outcome dimensional.
- **Contribuição teórica**: primeira decomposição empírica da substituição entre schemes.
- **Teto realista**: AER/QJE se executado limpo.

### Caminho D — Município-level peer effects
- Quando município M é condenado, prefeitos de municípios vizinhos mudam comportamento procurement?
- Usa Lee (JEctrics 2008) style spillover identification.
- Precedente: Avis-Ferraz-Finan (JPE 2018) CGU audit spillovers.
- Útil como mecanismo, difícil como paper stand-alone.

### Caminho E — Pre-sentença petições iniciais como early signal
- Petições iniciais (10k corpus) são filadas anos antes de sentença.
- Efeito do FILING (não da condenação) sobre comportamento firma — anticipatory deterrence.
- Usa data de distribuição como shock.
- **Novo**: ninguém na literatura separou efeito de *filing* vs. *conviction*.

### Caminho F — Structural decomposition
- Modelo estrutural: firma escolhe nível de corrupção dado $(\text{rent}, \text{Pr(detect)}, \text{Pr(convict)|detect})$.
- Usa Caminho B para identificar $\partial$corrupção/$\partial$Pr(convict).
- Combina com CGU audit rates para Pr(detect).
- Calibra e produz counterfactual: valor de aumentar recursos MP × recursos TJSP.
- **Conecta com Paper 12** (scheme census).

---

## Gargalo principal

**Amostra e first-stage.** 12.593 sentenças espalhadas em centenas de varas. Muitas varas têm só 1-2 juízes ativos por período — assignment não gera variação útil. Amostra efetiva pode cair para ~3-5k casos em subset de comarcas com múltiplos juízes.

**Nicho jurisdicional.** Referee do AER pensa: "improbidade brasileira é niche. Generaliza?" Antídoto: framing mais amplo (deterrence theory tests, não Brazilian law).

---

## Precedentes a bater

| Referência | Venue | Nosso diferencial |
|---|---|---|
| Dobbie-Goldin-Yang (2018) | AER | Civil/administrative ≠ criminal; corrupção específica |
| Aizer-Doyle (2015) | QJE | Corporate defendant (firma) ≠ individual |
| Avis-Ferraz-Finan (2018) | JPE | Judicial ≠ audit; deterrence pathway ≠ revelation |
| Colonnelli-Prem (2022) | JFE | Randomization ortogonal (juiz ≠ sorteio) |
| Kling (2006) | AER | Procurement-specific outcomes |

---

## Decisão inicial

**Passo 1 (blocking).** Rodar balance test do Caminho A. Se falhar, paper morre.
**Passo 2.** Se balance ok, construir first-stage do Caminho B e checar F-stat.
**Passo 3.** Se F ≥ 10, rodar Caminho B baseline.
**Passo 4.** Em paralelo, começar Caminho C se scheme classifier do Paper 12 maduro.
**Passo 5.** Decidir entre publicar Caminho B sozinho (JPubE) ou esperar C (estiramento AER).

**Gate check fundamental**: Passo 1 em 2-3 semanas. Morte precoce é feature, não bug.

---

## Memo honesto

Este paper é **dependente** do Paper 12 (scheme classifier) para o Caminho C — a parte que elevaria o teto. Sem isso, é um JPubE sólido. Decidir com orientador se vale subordinar o timing.

Alternativa radical: reenquadrar como paper de *anticipatory deterrence via filing* (Caminho E) — isso é genuinamente novo na literatura, não só aplicação. Menor amostra mas contribuição teórica mais clara.
