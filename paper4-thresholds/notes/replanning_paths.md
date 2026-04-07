# Paper 4 — Replanning Paths

**Autor do parecer:** mr-beneath (modo /co)
**Data:** 2026-04-06
**Projeto:** `paper4-thresholds/paper_beneath`
**Contexto:** Insatisfação com o andamento do paper atual (KNOC-style close-bid RD sobre BEC-SP). Novos ativos: RAIS identificada linkável via CNPJ. Este documento lista caminhos promissores de reescrita/replanejamento que aproveitam o que já foi feito e exploram o potencial do match BEC × RAIS.

---

## Leitura estratégica

O problema não é que *não há paper aqui*. O problema é que o paper atual está escrito como **detecção** — arena lotada, dominada por KNOC e pela turma de Chassang, onde qualquer contribuição marginal é julgada contra uma fronteira metodológica muito alta.

BEC-SP + RAIS te dá algo que nem KNOC nem ninguém do cartel-detection canon tem: **microdados de empregador-empregado linkados ao universo de licitações de um estado de 46 milhões de pessoas, por 10 anos**. É ativo raro. Use-o para sair da arena de detecção e entrar em arenas onde você tem vantagem comparativa.

Os caminhos abaixo aproveitam o que já está no paper (RD no Δ=0, BEC-SP, ideia KNOC) e adicionam RAIS de formas genuinamente distintas. Estão ordenados do **mais promissor** (na minha leitura) para o mais especulativo.

---

## Caminho 1 — "The Real Effects of Narrow Wins"
### *O RD como quasi-experimento sobre firmas e trabalhadores*

### Inversão da lógica atual

Hoje o paper trata o jump em `incumbent` no Δ=0 como evidência de colusão. No parecer argumentei que esse jump provavelmente reflete **heterogeneidade persistente de custos** — o que *invalidaria* o desenho como teste de colusão. Mas essa mesma propriedade, lida de outro ângulo, é um **presente**: condicional a estar em um leilão disputadíssimo, ganhar vs. perder é *quase* aleatório. Isso é exatamente o pressuposto de **local randomization** do RD (Lee 2008; Cattaneo–Frandsen–Titiunik 2015).

Ou seja: o close-bid design não é bom para *detectar* colusão, mas é ótimo para **estimar o efeito causal de ganhar um contrato público sobre a firma e seus trabalhadores**.

### Pergunta de pesquisa

> *Quais são os efeitos causais de ganhar um contrato de procurement sobre emprego, salários, composição da força de trabalho, sobrevivência e participação futura em licitações das firmas vencedoras?*

### Por que isso é novo

- **Ferraz–Finan–Szerman (2016, JPE)** fizeram essa pergunta para o Brasil usando licitações municipais, mas **sem RAIS linkada no nível vínculo**, e com identificação mais fraca (matching/IV). O paper é influente justamente por ser o primeiro a atacar isso no Brasil.
- **Lee (2008, JoE)** e toda a literatura de close-election RD validam a identificação.
- Você teria: (i) identificação mais limpa (close-bid RD em vez de matching); (ii) granularidade de RAIS vínculo-nível (CBO, tenure, sexo, idade, salário, admissão, desligamento, motivo); (iii) horizonte de 10 anos; (iv) um estado inteiro; (v) heterogeneidade por porte/setor/formato.
- Literatura paralela: **Greenstone–Hornbeck–Moretti (2010, JPE)**, **Decarolis et al. (2020 JPubE)** sobre efeitos de ganhar contrato público, **Bertrand–Bombardini–Fisman–Trebbi (2020)** sobre conexões políticas e procurement.
- **Nenhum deles** tem RD × RAIS vínculo no mesmo paper. Essa é uma lacuna publicável.

### Pacote empírico concreto

1. **Construir painel firma × ano** a partir de RAIS (CNPJ raiz): headcount em 31/12, folha anual, salário médio, composição (sexo, idade, escolaridade, CBO), taxa de churn, admissões/desligamentos.
2. **Tratamento**: ganhar um leilão específico em `t` com `|Δ| < h`.
3. **Controle**: perder (runner-up) o mesmo leilão com `|Δ| < h`.
4. **Outcomes em `t, t+1, t+2, t+3`**:
   - Emprego (nível e log)
   - Folha salarial total
   - Salário médio (e decomposição: efeitos firma vs. composição)
   - Entrada/saída de trabalhadores
   - Probabilidade de sobrevivência (CNPJ ativo em RAIS)
   - Participação em leilões futuros (BEC)
   - Vitórias futuras (persistência — seu achado atual, reinterpretado como parte de um quadro maior)
5. **Dose–resposta**: usar o valor do contrato como tratamento intensivo (à la Cellini–Ferreira–Rothstein 2010).
6. **Heterogeneidade**: por porte inicial da firma (micro/pequena/média/grande via CNAE e RAIS), por setor, por mercado concentrado vs. competitivo, por formato (convite × pregão).
7. **Mecanismos**: os ganhos de emprego vêm de **mais trabalhadores novos** ou **menos desligamentos**? Os ganhos salariais são composição ou efeito firma? Isso diferencia "contrato público cria empregos" de "contrato público subsidia *rents*".

### Como reaproveitar o que já está escrito

- **Institutional background** (`background.tex`): praticamente intacto.
- **Data section**: reescrever descrevendo o match BEC × RAIS, reportando taxa de match, sumário das firmas matched vs. unmatched.
- **Methodology**: reescrita parcial — o RD permanece, mas agora com interpretação local-randomization e covariáveis pré-tratamento do RAIS como teste de balanço (os jumps que você já tem viram o *teste de validade* do design, com firm FE).
- **Results**: a tabela atual vira um apêndice ("manipulation checks"); o núcleo passa a ser a tabela de efeitos de emprego/salário.
- **RD plots** já feitos viram ferramenta.

### Contribuição a vender

> *"We provide the first worker-level estimates of the causal effect of public procurement contracts on firm employment and labor composition, exploiting a close-bid RD in 10 years of the universe of São Paulo state procurement linked to matched employer-employee data."*

### Target journals realistas

- **Primeiro alvo:** JPubE
- **Plausíveis:** REStat, AEJ: Applied
- **Com execução muito boa:** JPE ou AER não estão fora de cogitação — Ferraz-Finan-Szerman saiu na JPE e sua identificação + dados são melhores.

### Riscos

- **Match BEC × RAIS**: qualidade do CNPJ raiz precisa ser auditada. Mudanças de razão social, fusões, CNPJs de filial. Isso precisa ser a primeira coisa a checar.
- **External validity**: SP é atípica. Mas isso vale para qualquer paper com RAIS.
- **Manipulação do Δ**: se há manipulação do margin, a interpretação local-random quebra. Teste McCrary/CJM é pré-requisito.
- **Spillovers**: firmas do grupo de controle (runners-up) podem ser afetadas por perder → violam SUTVA. Tratar com SUTVA-aware designs ou foco em firmas marginalmente tratadas.

> **Avaliação:** este é o caminho com maior razão retorno/esforço, dados os ativos que você tem.

---

## Caminho 2 — "Cartels in the Labor Network"
### *Detecção de colusão via mobilidade de trabalhadores*

### Ideia central

Cartéis precisam de **comunicação**, ou pelo menos de **canais de coordenação tácita**. Um canal muito plausível (e até agora não explorado na literatura de bid rigging): **trabalhadores que circulam entre firmas concorrentes**. Se o gerente comercial da firma A trabalhou na firma B três anos atrás, há um canal de informação natural.

RAIS identificada dá *exatamente* o universo de worker flows entre CNPJs no Brasil.

### Pergunta

> *Firmas conectadas por fluxos de trabalhadores no passado exibem maior frequência de padrões close-bid KNOC-suspeitos quando competem entre si do que firmas desconectadas?*

### Por que isso é novo

- Literatura de detecção de cartel usa: variance screens, bid rotation patterns, price-setting anomalies, network analysis baseada em **co-bidding** (Wachs–Kertész 2019; Fazekas–Tóth 2016).
- **Nenhuma literatura usa worker mobility como proxy para canal cartelístico**. Esta seria a contribuição.
- Análogo mais próximo: literatura de **executive networks** e colusão (Shue 2013, HBS work on interlocking directorates), mas essa literatura usa elites; a sua usaria toda a força de trabalho via RAIS — muito mais rico.
- Recente e relevante: **Colonnelli–Prem (2022 AER)** sobre conexões políticas via RAIS em Brasil; abre a porta metodológica.

### Pacote empírico

1. **Construir rede bilateral de worker flows**: para cada par (A, B) de firmas que já competiram em algum leilão, medir número de trabalhadores que transitaram A→B ou B→A nos `k` anos anteriores. Normalizar (Jaccard, cosine, ou worker-flow-over-employment).
2. **Unidade de análise**: par de firmas × leilão em que ambas participaram.
3. **Outcome principal**: indicador de par estar em posição "narrow" (|Δ| < τ) no leilão.
4. **Regressão**:

   ```
   Narrow_{ij,t} = α + β · WorkerFlow_{ij,t-k:t-1}
                 + FE_market + FE_year + X_{ij,t} + ε
   ```

5. **Alternativa**: cartel é um *grupo*, não um par. Usar community detection (Louvain/infomap) sobre a rede de worker flows → comunidades de firmas → testar se narrow auctions ocorrem desproporcionalmente *dentro* de comunidades.
6. **Placebo** crítico: worker flows **para outras firmas fora do mesmo mercado** não deveria predizer close-bids. Isso descarta "firmas com turnover alto" como confounder.
7. **Validação externa**: cruzar com casos conhecidos de cartel investigados pelo CADE em SP no período. Se a sua medida de worker-flow-proximity prevê ex ante os casos que o CADE depois flagrou, você tem uma ferramenta de screening operacional.

### Como reaproveitar o que já existe

- Mais reescrita do que o Caminho 1. A parte do RD close-bid sobrevive como **rotulagem** de leilões suspeitos; a pergunta central muda.
- Você mantém a motivação KNOC, mas entra em uma sub-literatura diferente (detecção baseada em redes).

### Contribuição a vender

> *"We introduce a novel collusion screen based on labor mobility between competing firms, and validate it against close-bid asymmetries in the universe of São Paulo public procurement. Our method can be applied wherever matched employer-employee data coexist with procurement microdata."*

### Target

**RAND Journal, JLEO, JIE, IJIO**. Tem cara de IO/antitrust policy tool. JPubE também possível pela policy angle.

### Riscos

- **Causalidade vs. correlação**: worker mobility pode refletir *firmas parecidas* (mesmo setor, mesma geografia) que competem muito, não coordenação. É preciso separar "proximidade tecnológica" de "canal de informação". Placebo com firmas de setores distintos + controles de similaridade (CNAE, localização) ajudam mas não resolvem.
- **Validação** depende de casos conhecidos de cartel, que são poucos. Pode ser insuficiente para uma seção de validação forte.
- **Ambicioso**: maior upside conceitual mas também maior dependência de que a correlação seja *grande*. Se for pequena, vira um paper "não funciona muito bem".

> **Avaliação:** maior upside conceitual, maior risco. Bom complemento — ou extensão de apêndice — para o Caminho 1, não necessariamente o paper inteiro.

---

## Caminho 3 — "The Welfare Cost of Incumbency Capture"
### *Quantificação via modelo estrutural de leilão*

### Ideia

Aceitar que há *alguma* distorção competitiva na BEC-SP (seja colusão, favoritismo, ou heterogeneidade persistente com efeito deterrence sobre entrantes). A pergunta deixa de ser "existe?" e passa a ser **"quanto custa ao Estado de SP?"**.

Estruturar um modelo de leilão de primeiro preço com firmas heterogêneas, recuperar distribuições de custos (Guerre–Perrigne–Vuong 2000), simular contrafactuais e agregar.

### Pergunta

> *Qual é o custo em welfare (para o contribuinte paulista) da captura por incumbentes nas licitações da BEC-SP, e como ele se distribui entre mercados, categorias de produto e tipos de órgão comprador?*

### Por que é interessante

- Conecta o achado empírico ao **valor de política pública**.
- Transforma um paper "de diagnóstico" em um paper "de mensuração de welfare".
- **Asker (2010, AER)** é o benchmark: cartel de selos, quantificação estrutural.
- **Decarolis (2018, AEJ:Applied)** quantifica o custo de regras sub-ótimas em procurement italiano.
- Brasil: **Szerman (2022)**, **Lichand–Fernandes (2019)**. Nenhum estrutural sobre procurement no nível de BEC.

### Pacote empírico

1. **Reduced-form**: mostrar que mercados com maior incumbency jump têm preços de fechamento mais altos relativos ao reserve price.
2. **Modelo estrutural**: first-price sealed-bid com `N` bidders heterogêneos; identificar distribuição de custos `F_c` via GPV.
3. **Contrafactual 1**: remover a vantagem de incumbency — simular distribuição de preços sob simetria.
4. **Contrafactual 2**: entrada de firmas marginais que hoje são desencorajadas (pode-se medir desencorajamento empiricamente via participação decrescente de runners-up narrow losers — conecta com Caminho 1).
5. **Agregação**: somar sobre todos os leilões do período → estimativa do *welfare cost*.
6. **RAIS entra onde?** Para calibrar heterogeneidade de custos. Firmas com maior folha/trabalhador, maior CBO de especialização, etc., como proxy para eficiência. É um detour mas dá legitimidade.

### Como reaproveitar o que já existe

- O RD atual vira um "motivating fact" na introdução, não a análise central.
- Toda a descrição institucional e de dados permanece.
- Seção de resultados é completamente nova.

### Contribuição a vender

> *"We provide the first structural estimate of the welfare cost of incumbency capture in a large developing-country procurement system, finding that [X]% of the R$[Y] billion procured through BEC-SP over 2009–2019 represents rents to entrenched incumbents."*

### Target

**AEJ: Applied, AEJ: Micro, Journal of Econometrics (if methodological), IJIO, Journal of Public Economics**.

### Riscos

- **Modelo estrutural é trabalho pesado**: GPV em first-price é canônico, mas você tem muitas idiossincrasias (pregão descending ≠ GPV canônico; heterogeneidade dentro de 7,581 mercados; categorias de produto com poucas obs).
- **Pregão é uma descending auction**: GPV clássico é first-price sealed. Para pregão você precisa de Athey–Haile ou modelagem dinâmica mais elaborada. Isso adiciona complexidade.
- **Validade externa da recuperação de custos**: se o ambiente é colusivo, os bids observados não refletem custos verdadeiros, e GPV retorna lixo. Você tem que tratar isso (seguir Asker 2010, que lidou exatamente com isso).
- É o caminho de maior **prazo até submissão**.

> **Avaliação:** melhor como paper companion ou extensão depois de um paper reduced-form bem sucedido (Caminho 1). Sozinho é viável mas demanda 12–18 meses.

---

## Caminho 4 (bônus) — "Labor Shadows of Procurement Capture"
### *Efeitos sobre os trabalhadores*

Variação do Caminho 1 com twist mais sociológico-econômico. Em vez de "como firmas vencedoras crescem", perguntar: *quem são os trabalhadores que capturam os rents?*

Usando RAIS:

- Incumbent firms pagam prêmio salarial? (Abowd-Kramarz-Margolis decomposição: efeito firma vs. efeito trabalhador)
- Incumbent firms contratam desproporcionalmente ex-servidores públicos? (RAIS identifica natureza jurídica anterior do vínculo — *revolving door* measurable no micro)
- Incumbent firms têm composição de gênero/raça distinta?
- Trabalhadores de firmas narrowly-losing onde vão parar? (Reemprego, downgrade setorial)

### Contribuição

Primeiro paper a documentar *efeitos sobre trabalhadores* de captura em procurement. Conecta-se à literatura de *rent sharing* (Card–Cardoso–Heining–Kline 2018 QJE) e *political connections → labor market* (Colonnelli–Prem 2022).

### Target

**JPubE, ILR Review, Journal of Labor Economics** ou, com sorte, **REStud**.

### Avaliação

Este caminho é **menos arriscado** que o 2, **menos ambicioso** que o 3, e pode ser **rodado em paralelo** ao Caminho 1 como extensão.

---

## Recomendação

Faça **Caminho 1 como paper principal**, com uma subseção curta no espírito do **Caminho 4** (revolving door / wage premium) como valor adicional. Mantenha o **Caminho 2** (worker-flow networks) como **segundo paper** — é ambicioso demais para ser apêndice e dependerá da qualidade da rede. **Caminho 3** fica como projeto de médio prazo depois que o Caminho 1 estiver submetido.

### Próximos passos práticos (assumindo Caminho 1)

1. **Auditoria do match BEC × RAIS**: de 19,007 firmas em BEC, quantas casam por CNPJ raiz em RAIS? Quantas têm trajetória completa 2009–2019? Isso é gate check — sem match bom, o paper não existe.
2. **Desenhar a amostra RD**: definir `τ` (ex.: 1% ou 2%), restringir a convite (evitar problema de mechanical last-bid no pregão), garantir paired structure claro.
3. **Sumário da firma-alvo**: montar uma Table 1 com características (RAIS) de narrow winners vs. narrow losers antes do leilão — é o teste de balanço que sustenta o RD.
4. **Resultados principais**: RD em `Δt ∈ {0, 1, 2, 3}` anos para os outcomes do Caminho 1.
5. **Reescrever intro e conclusão** do zero com a nova narrativa.

### Opções de entrega imediata

- **(a)** Proposta de estrutura completa para o paper reescrito no Caminho 1 (outline de seções com conteúdo esperado por seção).
- **(b)** Script preliminar em R para auditar o match BEC × RAIS e reportar estatísticas de cobertura.
- **(c)** Revisão de literatura direcionada para posicionar o Caminho 1 contra Ferraz-Finan-Szerman e correlatos.

---

*Documento gerado por mr-beneath em modo /co. Submetido como insumo para decisão editorial do projeto.*
