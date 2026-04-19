# Paper 14 — The Endogenous Choice of Corruption: A Double-Instrument Approach

**Status.** Semente top-5. Pré-calibração (2026-04-18) coloca probabilidade top-5 em **15-20% com co-autor estruturalista, 5-8% sem**. Venue alvo: **AER / JPE / Econometrica**.

**Tagline interna.** Primeira decomposição empírica de *demanda por corrupção* (oportunidade de rent) vs. *oferta de corrupção* (disposição a correr risco de detecção), usando duas variações exógenas independentes no mesmo painel firma × ano.

---

## Pergunta central

Quando uma firma escolhe corromper, ela o faz porque:
- (a) **Tem oportunidade** (acesso a rent via procurement), ou
- (b) **Tem pouco a perder** (baixa probabilidade de detecção/condenação)?

Esse é o problema não-resolvido da literatura de Rose-Ackerman (1978) → Shleifer-Vishny (QJE 1993) → Bó-Rossi (2007) → Olken-Pande (Annual Review 2012). Nunca houve decomposição empírica limpa porque **nenhum paper teve as duas variações exógenas na mesma amostra**.

Você tem.

---

## Reformulação estrutural (ângulo top-5)

Modelo de escolha discreta de ato corrupto por firma $i$ em período $t$:

$$\mathbb{P}(\text{corrupt}_{it}=1) = \Phi\left( \alpha + \beta_1 \log(\text{rent}_{it}) + \beta_2 \log(\text{Pr(convict)}_{it}) + \gamma X_{it} \right)$$

com:
- $\text{rent}_{it}$ = valor contratual potencial no leilão, instrumentado por **RD close-bid** (paper 4).
- $\text{Pr(convict)}_{it}$ = probabilidade esperada de condenação em caso de detecção, instrumentada por **judge stringency IV** (paper 9) no município/vara de assignment.
- $X_{it}$ = produtividade firma (RAIS AKM FE), outside option (CNAE × tamanho), liquidez.

**Identificação estrutural:**
- $\beta_1$ = elasticidade da corrupção ao rent → *demanda* por oportunidade.
- $\beta_2$ = elasticidade da corrupção à detecção → *oferta* (disposição a risco).
- Teste empírico do trade-off Shleifer-Vishny: se $|\beta_2| >> |\beta_1|$, deterrence é o leverage certo; se $|\beta_1| >> |\beta_2|$, reduzir oportunidade (transparência, redução de discricionariedade) é o leverage.

**Counterfactuals de policy:**
- Valor marginal de R$1 em MP/TJSP vs. R$1 em transparência (CGU portal, Audesp).
- Heterogeneidade por setor (saúde vs. construção vs. TI).
- Heterogeneidade por tamanho da firma (pequena vs. grande).

---

## Identificação dupla

### IV #1 — Close-bid RD (rent access)
- Firmas com MV ≈ 0 são observacionalmente idênticas; quem ganha é quasi-random.
- Rent contrafactual = valor do contrato × markup estrutural.
- Infra: `paper4-thresholds/02_data/final/df_{convite,pregao}_winner_looser.parquet`.

### IV #2 — Judge stringency (detection/conviction risk)
- Assignment de juiz a caso de improbidade é quasi-random dentro de vara × período.
- Leave-one-out stringency do juiz prediz probabilidade de condenação (Dahl-Kostøl-Mogstad QJE 2014).
- Infra: `paper6-procure/build/clean/court_case.parquet` + `court_party.parquet`.
- **Observação**: firma $i$ em ano $t$ enfrenta *risco esperado* de condenação dado distribuição de juízes ativos no comarca de sua operação principal — não necessidade de ser ré em caso real. Expectativa ex-ante.

### Ortogonalidade dos dois IVs
- Close-bid RD varia ao nível leilão × ano.
- Judge stringency varia ao nível comarca × ano.
- **Plausibilidade**: independência condicional a controles de comarca × setor × ano. Teste: correlação residual ≈ 0.
- **Caso crítico**: se juiz estringente é sistematicamente atribuído a comarcas com leilões mais valiosos, IVs correlacionam e decomposição falha. **Testar antes de tudo**.

---

## Dados já existentes no monorepo

| Ativo | Localização | Status |
|---|---|---|
| `df_{convite,pregao}_winner_looser.parquet` | `paper4-thresholds/02_data/final/` | Pronto |
| `Firms_final.parquet` + `firm_year_panel.parquet` | `paper4-thresholds/02_data/firms/` | Pronto |
| `court_case.parquet`, `court_party.parquet`, `court_sentenca.parquet` | `paper6-procure/build/clean/` | Pronto |
| `link_court_procurement.csv` | `paper6-procure/build/analysis/` | Pronto |
| `firm_firm_worker_flow_edges.parquet` | `paper4-thresholds/02_data/firms/` | Pronto (mecanismo) |
| `firm_firm_cobidding_edges.parquet` | `paper4-thresholds/02_data/firms/` | Pronto (mecanismo) |
| Scheme classifier (Paper 12/15) | — | **Dependente** |
| Sanctions CEIS/CNEP/CEPIM | `paper6-procure` Dropbox | Pronto |
| RAIS AKM firm FE | externo | A estimar |

---

## Caminhos possíveis

### Caminho A — Power calculation e feasibility (blocking)
- Interseção: firmas que (i) estão em leilões close-bid + (ii) têm exposição a variação em stringency de juiz via comarca.
- Quantas firmas? ≥ 5k para 2SLS + heterogeneidade é mínimo aceitável.
- Variação efetiva: se stringency é absorvida por comarca FE, morre. Precisa varia tempo-within-comarca.
- **Gate crítico**: se amostra < 3k firmas com variação útil, paper morre.

### Caminho B — Independência dos IVs (blocking)
- Teste Cragg-Donald de rank condition para 2SLS com 2 IVs.
- Regressão auxiliar: $Z_1 \sim Z_2$ residualizado por FEs. Coeficiente deve ser ≈ 0.
- Sargan-Hansen J-test para over-identification restrictions.
- **Gate**: se J-test rejeita, IVs não são independentes, design falha.

### Caminho C — Baseline 2SLS com 2 IVs (AEJ:Applied level)
- First-stage: rent e convict-risk como função dos 2 IVs + controles.
- Second-stage: corrupção (proxy: envolvimento em caso TJSP improbidade pós-contrato) como função dos 2 shifters instrumentados.
- Heterogeneidade por setor.
- **Teto realista**: AEJ:Applied se power suficiente. ReStat se bem executado.

### Caminho D — Structural model (caminho top-5, exige co-autor IO)
- Estimar $\beta_1, \beta_2$ como parâmetros de preferência sobre risco+rent.
- Identificação: variação exógena em ambos os argumentos da função de utilidade.
- Estrutura: firma maximiza $E[\pi] - c \cdot \text{Pr(detect)} \cdot \text{Pr(convict)} \cdot \text{penalty}$.
- Welfare/policy: contrafactual de mudar enforcement (reduzindo $\text{Pr(convict)}$) vs. mudar thresholds (reduzindo rent).
- **Precedente**: Bó-Rossi (2007), Becker-Stigler (1974), Becker (1968) — framework teórico.
- **Precedente empírico**: Dobbie-Goldin-Yang (AER 2018), Angrist-Imbens-Rubin (1996) LATE, Imbens-Angrist IV framework.
- **Teto realista**: AER se co-autor estruturalista sênior.

### Caminho E — Mechanism: worker flow as coordination technology
- Firmas corruptas se coordenam via mobilidade de trabalhadores-chave.
- `firm_firm_worker_flow_edges` prediz probabilidade de ambas firmas estarem em processos judiciais correlatos.
- Rede dinâmica: quando enforcement aumenta, rede se fragmenta ou se densifica?
- **Novo**: primeira evidência de que worker flows são tecnologia de corrupção.
- **Teto realista**: adiciona a contribuição "novelty" ao AER pitch.

### Caminho F — Heterogeneidade estrutural
- Firmas grandes vs. pequenas: diferenças em $\beta_1, \beta_2$?
- Saúde (bitter-pills) vs. obras vs. serviços: diferenças?
- Firmas com político-conexão (TSE data) vs. sem: diferenças?
- Teste rich de predictões estruturais do modelo.

### Caminho G — External validation via CADE
- Modelo prediz: firmas com alto $\text{rent} \times \text{low risk}$ têm maior probabilidade de serem cartelistas.
- Ground truth: `cade_ground_truth.parquet`.
- Se modelo prediz out-of-sample status cartel (via CADE investigation), validação externa forte.

---

## Precedentes a bater

| Referência | Venue / Ano | Como decomponho mais |
|---|---|---|
| Colonnelli-Prem | JFE 2022 | Só detecção (CGU shock); nós decompomos em 2 |
| Ferraz-Finan (2008, 2011) | QJE, JPE | Audit ≠ rent allocation; nós separamos |
| Avis-Ferraz-Finan (2018) | JPE | Mesma crítica |
| Brollo-Nannicini-Perotti-Tabellini | AER 2013 | Só rent (transferências); nós adicionamos detection |
| Fisman-Miguel | JPE 2007 | Historical norms ≠ clean IV |
| Akcigit-Baslandze-Lotti | Ecta 2023 | Connection ≠ corruption; mecanismo distinto |
| Brollo-Troiano | ReStud 2016 | Close-election RD; nós close-bid |
| Olken (2007) | QJE | Monitoring intensity; nós fazemos supply-side |
| Di Tella-Schargrodsky | JLE 2003 | Rotation ≠ stringency; exogeneidade mais fraca |

---

## Gargalo principal

**Três obstáculos sequenciais, cada um matável:**

1. **Ortogonalidade dos 2 IVs.** Se juízes estringentes se concentram em comarcas com leilões grandes, IVs correlacionam. Testar primeiro.

2. **Amostra na interseção.** Firmas que são (i) próximas de MV = 0 em leilão BEC e (ii) expostas a variação cross-judge em comarca. Pode ser pequena; power calculation crítica.

3. **Estrutural exige co-autor.** Sem alguém com pedigree IO/Ecta (Decarolis, Ryan, Seim, Collard-Wexler, Asker), o modelo estrutural não convence referees AER. Sem modelo estrutural, teto cai para AEJ:Applied.

**Corolário**: este paper é *condicional em co-autoria*. A decisão de fazê-lo em formato top-5 exige compromisso de buscar e integrar um co-autor senior estruturalista *antes* de avançar muito.

---

## Decisão inicial

**Passo 1 (2-3 semanas).** Power calculation e teste de ortogonalidade dos IVs. Caminho A + B.
**Passo 2 (1 mês).** Se Passo 1 passa, rodar Caminho C reduced-form. Resultado baseline.
**Passo 3 (paralelo).** Iniciar busca de co-autor estruturalista. Apresentação seminal em 3 páginas + resultados reduced-form como *pitch deck*.
**Passo 4 (6+ meses).** Com co-autor, estruturar modelo + estimação. Caminho D.
**Passo 5.** Caminhos E, F, G como robustez.

**Gate kill**: Passo 1 em 3 semanas. Se ortogonalidade falha ou amostra é inadequada, paper morre cedo.

---

## Co-autoria estratégica — crítica

Top-5 viabilidade **depende** de co-autor. Candidatos razoáveis:
- **Francesco Decarolis** (Bocconi, procurement structural). Publicações em AER sobre procurement.
- **Nikhil Agarwal** ou **Parag Pathak** (MIT, mechanism design).
- **Philipp Schmidt-Dengler** (Vienna, IO empirical).
- **Paolo Buccirossi** ou **Ciliberto-Tamer** tipo (entry + antitrust).
- **Dimitri Szerman** (PUC-Rio) — Brazilian insider, RAIS expert. Menos estrutural mas credibilidade bridge.

**Recomendação**: abordar Decarolis ou Szerman primeiro.

---

## Memo honesto

Esta é a ideia **mais ambiciosa** do portfólio. Top-5 realista só com:
1. Co-autor estruturalista top.
2. Ortogonalidade dos IVs validada empiricamente.
3. Amostra suficiente na interseção.

Sem (1), teto é AEJ:Applied (ainda excelente, mas não top-5).

### Conexões cruzadas com outros papers do portfólio

- **Paper 8 (Narrow Wins)** — mesmo IV close-bid; resultados de lá feedback para cá.
- **Paper 9 (Judge IV)** — mesmo IV judge stringency; compartilha validação de quasi-aleatoriedade.
- **Paper 12/15 (Scheme Classifier / Census)** — scheme classification como outcome refinado (qual *tipo* de corrupção).
- **Paper 13 (Compelled Procurement)** — usa judge IV mas em outro ramo (cível/Fazenda). Dados e framework compartilhados.

Este paper é **o caminho mais estruturalmente ambicioso, mas também o mais dependente de fatores externos (co-autor)**. Tratar como projeto de médio-longo prazo, não quick-win.
